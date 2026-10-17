-- Apply after the physical-location and Dead-plant-lock migrations.
-- New registrations use a weekly inspection schedule.
begin;

alter table public.plant alter column inspection_interval_days set default 7;

-- Convert only the former default on active, non-Dead records. Do not move the
-- reference date to today: a plant already due for inspection remains due.
update public.plant p
set inspection_interval_days = 7,
    next_inspection_due_on =
      coalesce(p.last_inspected_on, p.date_planted, p.created_at::date, current_date) + 7
where p.inspection_interval_days = 90
  and p.archived_at is null
  and not public.is_dead_plant_status(p.health_status_id);

-- Preserve registration authorization, QR assignment, audit and location flow.
create or replace function public.register_plant_with_qr(
  p_session_token text,
  p_classification_id integer,
  p_campus_id integer,
  p_college_id integer,
  p_town_id integer,
  p_barangay_id integer,
  p_growth_status_id integer,
  p_health_status_id integer,
  p_registered_by integer,
  p_variety text default null,
  p_date_planted date default null,
  p_tree_planter text default null,
  p_photo_url text default null,
  p_existing_qr_tag_id integer default null,
  p_new_qr_code text default null
)
returns table(plant_id integer, qr_tag_id integer, qr_code_string text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor_account public.users%rowtype;
  selected_qr public.qr_tag%rowtype;
  new_plant_id integer;
  tag_created_at timestamptz;
  generated_code text;
begin
  actor_account := public.require_app_session(p_session_token);
  if actor_account.role not in ('college_admin', 'inspection_team') then
    raise exception 'College Admin or Inspection Team access required';
  end if;
  if actor_account.campus_id is distinct from p_campus_id
      or actor_account.college_id is distinct from p_college_id then
    raise exception 'Plant registration is outside your assigned college';
  end if;
  if p_registered_by is distinct from actor_account.user_id then
    raise exception 'Invalid registering user';
  end if;
  if p_date_planted is not null and p_date_planted > current_date then
    raise exception 'Date planted cannot be in the future';
  end if;
  if not exists (
    select 1 from public.plant_classification c
    where c.classification_id = p_classification_id
  ) then
    raise exception 'Plant classification not found';
  end if;
  if not exists (
    select 1 from public.college c
    where c.college_id = p_college_id and c.campus_id = p_campus_id
  ) then
    raise exception 'College does not belong to campus';
  end if;
  if not exists (
    select 1 from public.barangay b
    where b.barangay_id = p_barangay_id and b.town_id = p_town_id
  ) then
    raise exception 'Barangay does not belong to town';
  end if;
  if not exists (
    select 1 from public.growth_status g
    where g.growth_status_id = p_growth_status_id
  ) then
    raise exception 'Growth status not found';
  end if;
  if not exists (
    select 1 from public.health_status h
    where h.health_status_id = p_health_status_id
  ) then
    raise exception 'Health status not found';
  end if;

  if p_existing_qr_tag_id is not null then
    select * into selected_qr
    from public.qr_tag q
    where q.qr_tag_id = p_existing_qr_tag_id
      and lower(q.status::text) = 'available'
      and q.lifecycle_status = 'available'
      and (
        (q.campus_id = actor_account.campus_id
          and q.college_id = actor_account.college_id)
        or (q.campus_id is null and q.college_id is null)
      )
    for update;
    if not found then
      raise exception 'Selected QR tag is not available in your college';
    end if;
  else
    tag_created_at := clock_timestamp();
    generated_code := public.next_ecotag_qr_code(tag_created_at);

    insert into public.qr_tag (
      qr_code_string, status, lifecycle_status, campus_id, college_id,
      created_by, created_at, last_status_changed_at,
      last_status_changed_by
    ) values (
      generated_code, 'available', 'available', actor_account.campus_id,
      actor_account.college_id, actor_account.user_id, tag_created_at,
      tag_created_at, actor_account.user_id
    )
    returning * into selected_qr;

    perform public.write_qr_tag_event(
      selected_qr.qr_tag_id, actor_account.user_id,
      'qr.created', null, 'available'
    );
  end if;

  insert into public.plant (
    classification_id, campus_id, college_id, town_id, barangay_id,
    qr_tag_id, variety, date_planted, tree_planter, photo_url,
    registered_by, growth_status_id, health_status_id,
    inspection_interval_days, next_inspection_due_on
  ) values (
    p_classification_id, p_campus_id, p_college_id, p_town_id,
    p_barangay_id, selected_qr.qr_tag_id, nullif(trim(p_variety), ''),
    p_date_planted, nullif(trim(p_tree_planter), ''),
    nullif(trim(p_photo_url), ''), actor_account.user_id,
    p_growth_status_id, p_health_status_id, 7,
    coalesce(p_date_planted, current_date) + 7
  )
  returning public.plant.plant_id into new_plant_id;

  update public.qr_tag q
  set status = (
        jsonb_populate_record(
          null::public.qr_tag,
          jsonb_build_object('status', 'assigned')
        )
      ).status,
      lifecycle_status = 'assigned',
      campus_id = actor_account.campus_id,
      college_id = actor_account.college_id,
      created_by = coalesce(q.created_by, actor_account.user_id),
      assigned_plant_id = new_plant_id,
      last_status_changed_at = clock_timestamp(),
      last_status_changed_by = actor_account.user_id,
      status_reason = 'Assigned during plant registration'
  where q.qr_tag_id = selected_qr.qr_tag_id;

  perform public.write_qr_tag_event(
    selected_qr.qr_tag_id, actor_account.user_id, 'qr.assigned',
    selected_qr.lifecycle_status, 'assigned', new_plant_id,
    'Assigned during plant registration'
  );
  perform public.write_audit_event(
    actor_account.user_id, 'plant.registered', 'plant',
    new_plant_id::text, actor_account.campus_id,
    actor_account.college_id, null,
    jsonb_build_object(
      'classification_id', p_classification_id,
      'variety', nullif(trim(p_variety), ''),
      'date_planted', p_date_planted,
      'town_id', p_town_id,
      'barangay_id', p_barangay_id,
      'qr_tag_id', selected_qr.qr_tag_id,
      'inspection_interval_days', 7,
      'next_inspection_due_on',
        coalesce(p_date_planted, current_date) + 7
    )
  );

  return query
  select new_plant_id, selected_qr.qr_tag_id,
    selected_qr.qr_code_string::text;
end;
$$;

revoke all on function public.register_plant_with_qr(
  text, integer, integer, integer, integer, integer, integer, integer, integer,
  text, date, text, text, integer, text
) from public;
grant execute on function public.register_plant_with_qr(
  text, integer, integer, integer, integer, integer, integer, integer, integer,
  text, date, text, text, integer, text
) to anon, authenticated;

create or replace function public.college_admin_reopen_dead_plant(
  p_session_token text, p_plant_id integer, p_health_status_id integer, p_reason text
) returns void language plpgsql security definer set search_path = public, extensions as $$
declare actor_account public.users%rowtype; target_plant public.plant%rowtype;
begin
  actor_account := public.require_app_session(p_session_token);
  if actor_account.role <> 'college_admin' then
    raise exception 'Assigned College Admin access required';
  end if;
  if p_reason is null or length(trim(p_reason)) not between 3 and 250 then
    raise exception 'Provide a reopening reason from 3 to 250 characters';
  end if;
  select * into target_plant from public.plant p where p.plant_id = p_plant_id
    and p.campus_id = actor_account.campus_id and p.college_id = actor_account.college_id
    and p.archived_at is null for update;
  if not found then raise exception 'Active plant not found in your assigned college'; end if;
  if not public.is_dead_plant_status(target_plant.health_status_id) then
    raise exception 'Only a Dead plant record can be reopened';
  end if;
  if not exists (select 1 from public.health_status h
      where h.health_status_id = p_health_status_id)
      or public.is_dead_plant_status(p_health_status_id) then
    raise exception 'Select a valid non-Dead health status';
  end if;
  perform set_config('ecotag.dead_reopen_token', p_session_token, true);
  perform set_config('ecotag.dead_reopen_reason', trim(p_reason), true);
  update public.plant p set health_status_id = p_health_status_id,
    next_inspection_due_on = current_date + coalesce(p.inspection_interval_days, 7)
    where p.plant_id = p_plant_id;
  perform set_config('ecotag.dead_reopen_token', '', true);
  perform set_config('ecotag.dead_reopen_reason', '', true);
end;
$$;

revoke all on function public.college_admin_reopen_dead_plant(text, integer, integer, text) from public;
grant execute on function public.college_admin_reopen_dead_plant(text, integer, integer, text) to anon, authenticated;

commit;

