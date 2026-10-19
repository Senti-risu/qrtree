-- Damage is effective when reported; other problem types retain their review flow.
begin;

create or replace function public.apply_reported_qr_damage(p_report_id bigint)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare r public.qr_problem_report%rowtype; p public.plant%rowtype; q public.qr_tag%rowtype;
begin
  select * into r from public.qr_problem_report where report_id = p_report_id for update;
  if not found or r.problem <> 'damaged' or r.status not in ('pending', 'confirmed') then
    raise exception 'Active damage report required';
  end if;
  select * into p from public.plant where plant_id = r.plant_id for update;
  if not found or p.archived_at is not null or p.qr_tag_id is distinct from r.qr_tag_id then
    raise exception 'The plant label has changed or the plant is archived';
  end if;
  select * into q from public.qr_tag where qr_tag_id = r.qr_tag_id
    and campus_id = p.campus_id and college_id = p.college_id for update;
  if not found or q.lifecycle_status not in ('assigned', 'damaged')
      or (q.assigned_plant_id is not null and q.assigned_plant_id <> p.plant_id) then
    raise exception 'This QR is no longer the plant current active label';
  end if;
  if q.lifecycle_status <> 'damaged' then
    update public.qr_tag set
      status = (jsonb_populate_record(null::public.qr_tag, jsonb_build_object('status', 'damaged'))).status,
      lifecycle_status = 'damaged', damaged_at = now(), last_status_changed_at = now(),
      last_status_changed_by = r.reported_by, status_reason = r.description
      where qr_tag_id = r.qr_tag_id;
    perform public.write_qr_tag_event(r.qr_tag_id, r.reported_by, 'qr.status_changed',
      q.lifecycle_status, 'damaged', p.plant_id, 'Automatically marked damaged when reported.');
    perform public.write_audit_event(r.reported_by, 'qr.status_changed', 'qr_tag', r.qr_tag_id::text,
      p.campus_id, p.college_id, jsonb_build_object('status', q.lifecycle_status),
      jsonb_build_object('status', 'damaged'), jsonb_build_object('report_id', r.report_id, 'automatic', true));
  end if;
  update public.qr_problem_report set status = 'confirmed', reviewed_by = null,
    reviewed_at = now(), review_note = 'Automatically marked damaged; no approval required.'
    where report_id = r.report_id;
end;
$$;
-- Internal helper: never callable directly by app clients.
revoke all on function public.apply_reported_qr_damage(bigint) from public, anon, authenticated;

create or replace function public.report_qr_problem(
  p_session_token text, p_plant_id integer, p_problem text, p_description text
) returns bigint language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype; target public.plant%rowtype;
  new_id bigint; existing_id bigint;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is null or actor.role not in ('inspection_team', 'college_admin') then
    raise exception 'Inspection Team or College Admin access required';
  end if;
  select * into target from public.plant p where p.plant_id = p_plant_id
    and p.campus_id = actor.campus_id and p.college_id = actor.college_id
    and p.archived_at is null for update;
  if not found then raise exception 'Plant is outside your assigned college or is archived'; end if;
  if target.qr_tag_id is null then raise exception 'This plant has no assigned QR label'; end if;
  if p_problem is null or p_problem not in ('damaged','faded','missing','incorrect','other') then
    raise exception 'Choose a QR problem';
  end if;
  if p_description is null or length(trim(p_description)) not between 3 and 1000 then
    raise exception 'Describe the problem using 3 to 1000 characters';
  end if;
  if p_problem = 'damaged' then
    -- Reuse a retried report while this same label is still damaged.
    select r.report_id into existing_id from public.qr_problem_report r
      join public.qr_tag q on q.qr_tag_id = r.qr_tag_id
      where r.plant_id = target.plant_id and r.qr_tag_id = target.qr_tag_id
        and r.reported_by = actor.user_id and r.problem = 'damaged'
        and r.status = 'confirmed' and q.lifecycle_status = 'damaged'
      order by r.created_at desc, r.report_id desc limit 1;
    if existing_id is not null then return existing_id; end if;
    select r.report_id into existing_id from public.qr_problem_report r
      where r.qr_tag_id = target.qr_tag_id and r.reported_by = actor.user_id
        and r.status = 'pending' and r.problem = 'damaged' limit 1;
    if existing_id is not null then
      perform public.apply_reported_qr_damage(existing_id);
      return existing_id;
    end if;
    -- Insert confirmed first to avoid colliding with a separate pending issue.
    insert into public.qr_problem_report(plant_id, qr_tag_id, reported_by, problem, description, status)
      values(target.plant_id, target.qr_tag_id, actor.user_id, p_problem, trim(p_description), 'confirmed')
      returning report_id into new_id;
    perform public.apply_reported_qr_damage(new_id);
  else
    if exists (select 1 from public.qr_problem_report r where r.qr_tag_id = target.qr_tag_id
        and r.reported_by = actor.user_id and r.status = 'pending') then
      raise exception 'You already have a pending report for this QR label';
    end if;
    insert into public.qr_problem_report(plant_id, qr_tag_id, reported_by, problem, description)
      values(target.plant_id, target.qr_tag_id, actor.user_id, p_problem, trim(p_description))
      returning report_id into new_id;
  end if;
  perform public.write_audit_event(actor.user_id, 'qr.problem_reported', 'qr_problem_report',
    new_id::text, actor.campus_id, actor.college_id, null, null,
    jsonb_build_object('plant_id', target.plant_id, 'qr_tag_id', target.qr_tag_id,
      'problem', p_problem, 'automatic_damage', p_problem = 'damaged'));
  return new_id;
end;
$$;
revoke all on function public.report_qr_problem(text, integer, text, text) from public;
grant execute on function public.report_qr_problem(text, integer, text, text) to anon, authenticated;

-- Versioned entry point prevents new clients claiming damage was applied on an old database.
create or replace function public.report_qr_damage(
  p_session_token text, p_plant_id integer, p_description text
) returns bigint language sql security definer set search_path = public, extensions as $$
  select public.report_qr_problem(p_session_token, p_plant_id, 'damaged', p_description);
$$;
revoke all on function public.report_qr_damage(text, integer, text) from public;
grant execute on function public.report_qr_damage(text, integer, text) to anon, authenticated;

-- Existing pending damage reports take effect only for their still-current label.
do $$
declare r record;
begin
  for r in select report_id from public.qr_problem_report where problem = 'damaged' and status = 'pending'
    order by report_id
  loop
    if exists (select 1 from public.qr_problem_report d
      join public.plant p on p.plant_id = d.plant_id
      join public.qr_tag q on q.qr_tag_id = d.qr_tag_id
      where d.report_id = r.report_id and p.archived_at is null and p.qr_tag_id = d.qr_tag_id
        and q.campus_id = p.campus_id and q.college_id = p.college_id
        and q.lifecycle_status in ('assigned', 'damaged')
        and (q.assigned_plant_id is null or q.assigned_plant_id = p.plant_id)) then
      perform public.apply_reported_qr_damage(r.report_id);
    else
      update public.qr_problem_report set status = 'dismissed', reviewed_at = now(), reviewed_by = null,
        review_note = 'Not applied: the plant or QR assignment is no longer active.' where report_id = r.report_id;
    end if;
  end loop;
end;
$$;
notify pgrst, 'reload schema';
commit;
