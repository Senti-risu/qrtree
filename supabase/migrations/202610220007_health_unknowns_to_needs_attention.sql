begin;

create or replace function public.monitoring_outcomes(p_session_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  result jsonb;
begin
  actor := public.require_app_session(p_session_token);

  with scoped as (
    select
      p.*,
      h.status_name::text as health,
      c.college_name::text as college_name,
      public.is_dead_plant_status(p.health_status_id) as dead
    from public.plant p
    left join public.health_status h using (health_status_id)
    left join public.college c using (college_id)
    where actor.role in ('super_admin', 'university_admin')
      or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
      or (
        actor.role in ('college_admin', 'inspection_team')
        and p.campus_id = actor.campus_id
        and p.college_id = actor.college_id
      )
  ),
  batches as (
    select
      to_char(date_planted, 'YYYY-MM') as batch,
      count(*) as total,
      count(*) filter (
        where lower(health) in (
          'alive', 'healthy', 'dying', 'at risk', 'needs attention'
        )
      ) as alive,
      count(*) filter (
        where health is null
          or lower(health) not in (
            'alive', 'healthy', 'dying', 'at risk', 'needs attention',
            'dead', 'deceased'
          )
          or lower(health) in ('dying', 'at risk', 'needs attention')
      ) as needs_attention
    from scoped
    group by to_char(date_planted, 'YYYY-MM')
  ),
  colleges as (
    select
      college_id,
      college_name,
      count(*) as total,
      count(*) filter (
        where last_inspected_on >= (now() at time zone 'Asia/Manila')::date - 29
      ) as completed
    from scoped
    where archived_at is null and not dead
    group by college_id, college_name
  ),
  changes as (
    select
      to_char(
        coalesce(i.observed_at, i.inspected_at) at time zone 'Asia/Manila',
        'YYYY-MM'
      ) as month,
      case
        when lower(h.status_name::text) in ('alive', 'healthy') then 'Healthy'
        when lower(h.status_name::text) in ('dead', 'deceased') then 'Dead'
        else 'Needs Attention'
      end as health,
      count(*) as observations
    from public.inspection i
    join scoped s using (plant_id)
    left join public.health_status h
      on h.health_status_id = i.health_status_id
    group by 1, 2
  )
  select jsonb_build_object(
    'batches',
    coalesce(
      (select jsonb_agg(to_jsonb(b) order by b.batch desc) from batches b),
      '[]'::jsonb
    ),
    'colleges',
    coalesce(
      (select jsonb_agg(to_jsonb(c) order by c.college_name) from colleges c),
      '[]'::jsonb
    ),
    'health',
    coalesce(
      (select jsonb_agg(to_jsonb(h) order by h.month desc, h.health) from changes h),
      '[]'::jsonb
    ),
    'generated_on',
    (now() at time zone 'Asia/Manila')::date
  ) into result;

  return result;
end;
$$;

revoke all on function public.monitoring_outcomes(text) from public;
grant execute on function public.monitoring_outcomes(text) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
