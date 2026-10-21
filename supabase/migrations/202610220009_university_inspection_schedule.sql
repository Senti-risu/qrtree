begin;

create table if not exists public.inspection_schedule_settings (
  setting_id boolean primary key default true check (setting_id),
  interval_days integer not null check (interval_days between 1 and 3650),
  updated_at timestamptz not null default now(),
  updated_by integer references public.users(user_id)
);

insert into public.inspection_schedule_settings (
  setting_id, interval_days
)
values (true, 7)
on conflict (setting_id) do nothing;

alter table public.inspection_schedule_settings enable row level security;
revoke all on table public.inspection_schedule_settings
  from public, anon, authenticated;

create or replace function public.university_admin_get_inspection_interval(
  p_session_token text
) returns integer
language plpgsql security definer set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  interval_value integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;

  select s.interval_days into interval_value
  from public.inspection_schedule_settings s
  where s.setting_id = true;

  if interval_value is null then
    raise exception 'Inspection schedule setting is missing';
  end if;
  return interval_value;
end;
$$;

create or replace function public.university_admin_set_inspection_interval(
  p_session_token text,
  p_interval_days integer
) returns integer
language plpgsql security definer set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  previous_interval integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;
  if p_interval_days is null or p_interval_days not between 1 and 3650 then
    raise exception 'Inspection interval must be from 1 to 3650 days';
  end if;

  select s.interval_days into previous_interval
  from public.inspection_schedule_settings s
  where s.setting_id = true
  for update;

  if previous_interval is null then
    raise exception 'Inspection schedule setting is missing';
  end if;

  update public.inspection_schedule_settings
  set interval_days = p_interval_days,
      updated_at = now(),
      updated_by = actor.user_id
  where setting_id = true;

  update public.plant p
  set inspection_interval_days = p_interval_days,
      next_inspection_due_on =
        (now() at time zone 'Asia/Manila')::date + p_interval_days
  where p.archived_at is null
    and not public.is_dead_plant_status(p.health_status_id);

  perform public.write_audit_event(
    actor.user_id,
    'inspection_schedule.updated',
    'inspection_schedule_settings',
    'university',
    null,
    null,
    jsonb_build_object('interval_days', previous_interval),
    jsonb_build_object('interval_days', p_interval_days),
    jsonb_build_object('recalculated_existing_plants', true)
  );

  return p_interval_days;
end;
$$;

revoke all on function public.university_admin_get_inspection_interval(text)
  from public;
grant execute on function public.university_admin_get_inspection_interval(text)
  to anon, authenticated;
revoke all on function public.university_admin_set_inspection_interval(text, integer)
  from public;
grant execute on function public.university_admin_set_inspection_interval(text, integer)
  to anon, authenticated;

create or replace function public.apply_university_inspection_interval()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  configured_interval integer;
begin
  select s.interval_days into configured_interval
  from public.inspection_schedule_settings s
  where s.setting_id = true;

  if configured_interval is null then
    raise exception 'Inspection schedule setting is missing';
  end if;

  new.inspection_interval_days := configured_interval;
  new.next_inspection_due_on := coalesce(
    new.date_planted,
    current_date
  ) + configured_interval;
  return new;
end;
$$;

revoke all on function public.apply_university_inspection_interval()
  from public, anon, authenticated;
drop trigger if exists apply_university_inspection_interval
  on public.plant;
create trigger apply_university_inspection_interval
before insert on public.plant
for each row
execute function public.apply_university_inspection_interval();

notify pgrst, 'reload schema';
commit;
