-- Inspection Team QR reports and College Admin review. Apply after existing migrations.
begin;

create table if not exists public.qr_problem_report (
  report_id bigint generated always as identity primary key,
  plant_id integer not null references public.plant(plant_id),
  qr_tag_id integer not null references public.qr_tag(qr_tag_id),
  reported_by integer not null references public.users(user_id),
  problem text not null check (problem in ('damaged', 'faded', 'missing', 'incorrect', 'other')),
  description text not null check (length(trim(description)) between 3 and 1000),
  created_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'dismissed')),
  reviewed_by integer references public.users(user_id),
  reviewed_at timestamptz,
  review_note text
);
create unique index if not exists qr_problem_pending_unique
  on public.qr_problem_report(qr_tag_id, reported_by) where status = 'pending';
alter table public.qr_problem_report enable row level security;
revoke all on public.qr_problem_report from anon, authenticated;
revoke all on sequence public.qr_problem_report_report_id_seq from anon, authenticated;

create or replace function public.report_qr_problem(
  p_session_token text, p_plant_id integer, p_problem text, p_description text
) returns bigint language plpgsql security definer set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  target public.plant%rowtype;
  new_id bigint;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in ('inspection_team', 'college_admin') then
    raise exception 'Inspection Team or College Admin access required';
  end if;
  select * into target from public.plant p where p.plant_id = p_plant_id
    and p.campus_id = actor.campus_id and p.college_id = actor.college_id
    and p.archived_at is null for update;
  if not found then raise exception 'Plant is outside your assigned college or is archived'; end if;
  if target.qr_tag_id is null then raise exception 'This plant has no assigned QR label'; end if;
  if p_problem is null or p_problem not in ('damaged', 'faded', 'missing', 'incorrect', 'other') then
    raise exception 'Choose a QR problem';
  end if;
  if p_description is null or length(trim(p_description)) not between 3 and 1000 then
    raise exception 'Describe the problem using 3 to 1000 characters';
  end if;
  if exists (select 1 from public.qr_problem_report r where r.qr_tag_id = target.qr_tag_id
    and r.reported_by = actor.user_id and r.status = 'pending') then
    raise exception 'You already have a pending report for this QR label';
  end if;
  insert into public.qr_problem_report(plant_id, qr_tag_id, reported_by, problem, description)
    values(target.plant_id, target.qr_tag_id, actor.user_id, p_problem, trim(p_description))
    returning report_id into new_id;
  perform public.write_audit_event(actor.user_id, 'qr.problem_reported', 'qr_problem_report',
    new_id::text, actor.campus_id, actor.college_id, null, null,
    jsonb_build_object('plant_id', target.plant_id, 'qr_tag_id', target.qr_tag_id, 'problem', p_problem));
  return new_id;
end;
$$;

create or replace function public.list_qr_problem_reports(p_session_token text)
returns table(report_id bigint, plant_id integer, qr_tag_id integer, qr_code_string text,
  common_name text, reported_by text, problem text, description text, created_at timestamptz,
  status text, review_note text)
language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in ('inspection_team', 'college_admin') then raise exception 'Access denied'; end if;
  return query select r.report_id, r.plant_id, r.qr_tag_id, q.qr_code_string::text,
    pc.common_name::text, u.username::text, r.problem, r.description, r.created_at, r.status, r.review_note
  from public.qr_problem_report r join public.plant p on p.plant_id = r.plant_id
  join public.qr_tag q on q.qr_tag_id = r.qr_tag_id
  join public.users u on u.user_id = r.reported_by
  left join public.plant_classification pc on pc.classification_id = p.classification_id
  where p.campus_id = actor.campus_id and p.college_id = actor.college_id
    and (actor.role = 'college_admin' or r.reported_by = actor.user_id)
  order by (r.status = 'pending') desc, r.created_at desc limit 500;
end;
$$;

create or replace function public.review_qr_problem_report(
  p_session_token text, p_report_id bigint, p_confirm boolean, p_note text
) returns void language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype; target public.qr_problem_report%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if p_confirm is null or p_note is null or length(trim(p_note)) not between 3 and 1000 then
    raise exception 'Enter a review note using 3 to 1000 characters';
  end if;
  select r.* into target from public.qr_problem_report r join public.plant p on p.plant_id = r.plant_id
    where r.report_id = p_report_id and p.campus_id = actor.campus_id
    and p.college_id = actor.college_id for update of r;
  if not found then raise exception 'Report not found in your college'; end if;
  if target.status <> 'pending' then raise exception 'This report has already been reviewed'; end if;
  if p_confirm then
    perform 1 from public.plant p where p.plant_id = target.plant_id
      and p.qr_tag_id = target.qr_tag_id and p.archived_at is null for update;
    if not found then raise exception 'The plant label has changed or the plant is archived; dismiss this report'; end if;
    perform public.college_admin_mark_qr_damaged(p_session_token, target.qr_tag_id, trim(p_note));
  end if;
  update public.qr_problem_report set status = case when p_confirm then 'confirmed' else 'dismissed' end,
    reviewed_by = actor.user_id, reviewed_at = now(), review_note = trim(p_note)
    where qr_problem_report.report_id = p_report_id;
  perform public.write_audit_event(actor.user_id, 'qr.problem_reviewed', 'qr_problem_report',
    p_report_id::text, actor.campus_id, actor.college_id, null, null,
    jsonb_build_object('confirmed', p_confirm, 'note', trim(p_note)));
end;
$$;

revoke all on function public.report_qr_problem(text, integer, text, text) from public;
revoke all on function public.list_qr_problem_reports(text) from public;
revoke all on function public.review_qr_problem_report(text, bigint, boolean, text) from public;
grant execute on function public.report_qr_problem(text, integer, text, text) to anon, authenticated;
grant execute on function public.list_qr_problem_reports(text) to anon, authenticated;
grant execute on function public.review_qr_problem_report(text, bigint, boolean, text) to anon, authenticated;
commit;
