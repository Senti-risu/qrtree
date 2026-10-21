begin;

create or replace function public.university_admin_set_inspection_interval(
  p_session_token text,
  p_interval_days integer
) returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
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
    jsonb_build_object(
      'recalculated_existing_plants', true,
      'reset_from_change_date', true
    )
  );

  return p_interval_days;
end;
$$;

update public.plant p
set inspection_interval_days = s.interval_days,
    next_inspection_due_on =
      (now() at time zone 'Asia/Manila')::date + s.interval_days
from public.inspection_schedule_settings s
where s.setting_id = true
  and p.archived_at is null
  and not public.is_dead_plant_status(p.health_status_id);

revoke all on function public.university_admin_set_inspection_interval(
  text, integer
) from public;
grant execute on function public.university_admin_set_inspection_interval(
  text, integer
) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
