-- Export only inspection rows inside the signed-in staff member's assignment.
begin;
create or replace function public.report_validate_plants(
  p_session_token text, p_plant_ids integer[]
) returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is null or actor.role not in
    ('super_admin','university_admin','campus_admin','college_admin','inspection_team') then
    raise exception 'Staff report access required';
  end if;
  if coalesce(cardinality(p_plant_ids), 0) > 200 then
    raise exception 'Request at most 200 plants per batch';
  end if;
  return not exists (
    select 1 from unnest(coalesce(p_plant_ids, array[]::integer[])) requested(plant_id)
    where not exists (
      select 1 from public.plant p where p.plant_id = requested.plant_id
        and p.archived_at is null
        and (actor.role in ('super_admin','university_admin')
          or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
          or (actor.role in ('college_admin','inspection_team')
            and p.campus_id = actor.campus_id and p.college_id = actor.college_id))
    )
  );
end;
$$;
revoke all on function public.report_validate_plants(text, integer[]) from public;
grant execute on function public.report_validate_plants(text, integer[]) to anon, authenticated;

create or replace function public.report_inspection_history(
  p_session_token text,
  p_plant_ids integer[],
  p_start_on date default null,
  p_end_on date default null,
  p_offset integer default 0,
  p_limit integer default 500
)
returns jsonb
language plpgsql security definer
set search_path = public, extensions
as $$
declare actor public.users%rowtype; result jsonb;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is null or actor.role not in
    ('super_admin','university_admin','campus_admin','college_admin','inspection_team') then
    raise exception 'Staff report access required';
  end if;
  if coalesce(cardinality(p_plant_ids), 0) > 200 then
    raise exception 'Request at most 200 plants per batch';
  end if;
  if p_start_on > p_end_on then raise exception 'Invalid report dates'; end if;
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb) into result from (
    select coalesce(to_jsonb(i)->>'inspection_id', to_jsonb(i)->>'id') as inspection_id, i.plant_id,
      coalesce(i.observed_at, i.inspected_at) as observed_at,
      i.inspected_at, i.observation,
      u.username as inspector,
      h.status_name as health, g.growth_stage as growth_stage
    from public.inspection i
    join public.plant p on p.plant_id = i.plant_id
    left join public.users u on u.user_id = i.inspected_by
    left join public.health_status h on h.health_status_id = i.health_status_id
    left join public.growth_status g on g.growth_status_id = i.growth_status_id
    where p.plant_id = any(coalesce(p_plant_ids, array[]::integer[]))
      and (actor.role in ('super_admin','university_admin')
        or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
        or (actor.role in ('college_admin','inspection_team')
          and p.campus_id = actor.campus_id and p.college_id = actor.college_id))
      and (p_start_on is null or
        (coalesce(i.observed_at, i.inspected_at) at time zone 'Asia/Manila')::date >= p_start_on)
      and (p_end_on is null or
        (coalesce(i.observed_at, i.inspected_at) at time zone 'Asia/Manila')::date <= p_end_on)
    order by coalesce(i.observed_at, i.inspected_at) desc nulls last,
      coalesce(to_jsonb(i)->>'inspection_id', to_jsonb(i)->>'id'), i.ctid
    offset greatest(coalesce(p_offset, 0), 0)
    limit least(greatest(coalesce(p_limit, 500), 1), 500)
  ) r;
  return result;
end;
$$;
revoke all on function public.report_inspection_history(text, integer[], date, date, integer, integer) from public;
grant execute on function public.report_inspection_history(text, integer[], date, date, integer, integer) to anon, authenticated;
notify pgrst, 'reload schema';
commit;
