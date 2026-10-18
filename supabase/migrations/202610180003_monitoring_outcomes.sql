begin;

alter table public.inspection add column if not exists client_request_id text;
alter table public.inspection add column if not exists observed_at timestamptz;
create unique index if not exists inspection_client_request_idx on public.inspection(client_request_id)
  where client_request_id is not null;

create or replace function public.check_inspection_draft(p_session_token text, p_user_id integer, p_plant_id integer)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.user_id <> p_user_id or actor.role <> 'inspection_team' then
    raise exception 'Sign in with the Inspection Team account that owns this draft';
  end if;
  if not exists (select 1 from public.plant p where p.plant_id = p_plant_id
    and p.campus_id = actor.campus_id and p.college_id = actor.college_id) then
    raise exception 'Plant is outside your assigned college';
  end if;
end;
$$;

create or replace function public.submit_inspection_draft(
  p_session_token text, p_user_id integer, p_request_id text, p_plant_id integer,
  p_health_status_id integer, p_growth_status_id integer, p_observation text,
  p_photo_url text, p_observed_at timestamptz
) returns void language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype; target public.plant%rowtype; next_due date;
begin
  perform public.check_inspection_draft(p_session_token, p_user_id, p_plant_id);
  actor := public.require_app_session(p_session_token);
  if p_request_id is null or p_request_id !~ '^[a-f0-9]{48}$' then raise exception 'Invalid request ID'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id, 0));
  if exists(select 1 from public.inspection i where i.client_request_id = p_request_id) then
    if not exists(select 1 from public.inspection i where i.client_request_id = p_request_id
      and i.inspected_by = actor.user_id and i.plant_id = p_plant_id) then
      raise exception 'Request ID belongs to another inspection';
    end if;
    return;
  end if;
  if p_observed_at is null or p_observed_at > now() + interval '5 minutes' then
    raise exception 'Observation date cannot be in the future';
  end if;
  select * into target from public.plant p where p.plant_id = p_plant_id
    and p.campus_id = actor.campus_id and p.college_id = actor.college_id for update;
  if not found then raise exception 'Plant is outside your assigned college'; end if;
  if p_observed_at < target.created_at - interval '5 minutes' then
    raise exception 'Observation date cannot precede plant registration';
  end if;
  if target.archived_at is not null or public.is_dead_plant_status(target.health_status_id) then
    raise exception 'Plant is archived or Dead; inspection remains saved for review';
  end if;
  if not exists(select 1 from public.health_status h where h.health_status_id = p_health_status_id)
    or not exists(select 1 from public.growth_status g where g.growth_status_id = p_growth_status_id) then
    raise exception 'Select valid health and growth statuses';
  end if;
  -- Do not let an old offline observation overwrite newer monitoring results.
  if exists(select 1 from public.inspection i where i.plant_id = p_plant_id
    and coalesce(i.observed_at, i.inspected_at) > p_observed_at) then
    raise exception 'A newer inspection exists. Review this draft before submitting';
  end if;
  next_due := case when public.is_dead_plant_status(p_health_status_id) then null
    else (p_observed_at at time zone 'Asia/Manila')::date + target.inspection_interval_days end;
  insert into public.inspection(plant_id, inspected_by, health_status_id, growth_status_id,
    observation, photo_url, last_inspection_date, inspected_at, observed_at, client_request_id)
  values(p_plant_id, actor.user_id, p_health_status_id, p_growth_status_id,
    nullif(trim(p_observation), ''), nullif(trim(p_photo_url), ''),
    (p_observed_at at time zone 'Asia/Manila')::date, now(), p_observed_at, p_request_id);
  update public.plant set health_status_id = p_health_status_id, growth_status_id = p_growth_status_id,
    photo_url = coalesce(nullif(trim(p_photo_url), ''), photo_url),
    last_inspected_on = (p_observed_at at time zone 'Asia/Manila')::date,
    next_inspection_due_on = next_due where plant_id = p_plant_id;
  perform public.write_audit_event(actor.user_id, 'inspection.submitted', 'plant', p_plant_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object('health_status_id', target.health_status_id),
    jsonb_build_object('health_status_id', p_health_status_id, 'observed_at', p_observed_at),
    jsonb_build_object('request_id', p_request_id));
end;
$$;

create or replace function public.plant_monitoring_timeline(p_session_token text, p_plant_id integer)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype; result jsonb;
begin
  actor := public.require_app_session(p_session_token);
  if not exists(select 1 from public.plant p where p.plant_id = p_plant_id and (
    actor.role in ('super_admin','university_admin')
    or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
    or (actor.role in ('college_admin','inspection_team') and p.campus_id = actor.campus_id and p.college_id = actor.college_id))) then
    raise exception 'Plant is outside your assigned scope';
  end if;
  select coalesce(jsonb_agg(to_jsonb(events) order by events.occurred_at desc), '[]'::jsonb) into result from (
    select p.created_at as occurred_at, 'Plant registered'::text as title,
      'Registration record'::text as description, null::text as photo_url
    from public.plant p where p.plant_id = p_plant_id
    union all
    select coalesce(i.observed_at, i.inspected_at), 'Inspection: ' || coalesce(h.status_name::text, 'Unknown'),
      concat_ws(E'\n', g.growth_stage::text, i.observation, 'Inspector: ' || u.username::text), i.photo_url::text
    from public.inspection i left join public.health_status h using(health_status_id)
      left join public.growth_status g using(growth_status_id) left join public.users u on u.user_id = i.inspected_by
    where i.plant_id = p_plant_id
    union all
    select e.created_at, case e.action
      when 'plant.details_updated' then 'Plant details updated'
      when 'plant.dead_record_reopened' then 'Dead plant record reopened'
      when 'plant.archived' then 'Plant archived'
      when 'plant.restored' then 'Plant restored'
      when 'plant.inspection_schedule_updated' then 'Inspection schedule updated'
      else 'Plant record updated' end,
      concat_ws(E'\n', 'Updated by ' || e.actor_username,
        coalesce(e.metadata->>'reason', e.new_values->>'archive_reason'),
        case when e.action = 'plant.inspection_schedule_updated' then
          'Next inspection: ' || coalesce(e.new_values->>'next_inspection_due_on', 'Not scheduled') end), null::text
    from public.audit_event e where e.entity_type = 'plant' and e.entity_id = p_plant_id::text
      and e.action not in ('plant.registered', 'inspection.submitted')
  ) events;
  return result;
end;
$$;

create or replace function public.monitoring_outcomes(p_session_token text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype; result jsonb;
begin
  actor := public.require_app_session(p_session_token);
  with scoped as (
    select p.*, h.status_name::text as health, c.college_name::text as college_name,
      public.is_dead_plant_status(p.health_status_id) as dead
    from public.plant p left join public.health_status h using(health_status_id)
      left join public.college c using(college_id)
    where actor.role in ('super_admin','university_admin')
      or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
      or (actor.role in ('college_admin','inspection_team') and p.campus_id = actor.campus_id and p.college_id = actor.college_id)
  ), batches as (
    select to_char(date_planted, 'YYYY-MM') as batch, count(*) as total,
      count(*) filter(where not dead and health is not null) as alive,
      count(*) filter(where health is null) as unknown
    from scoped group by to_char(date_planted, 'YYYY-MM')
  ), colleges as (
    select college_id, college_name, count(*) as total,
      count(*) filter(where last_inspected_on >= (now() at time zone 'Asia/Manila')::date - 29) as completed
    from scoped where archived_at is null and not dead group by college_id, college_name
  ), changes as (
    select to_char(coalesce(i.observed_at, i.inspected_at) at time zone 'Asia/Manila', 'YYYY-MM') as month,
      h.status_name::text as health, count(*) as observations
    from public.inspection i join scoped s using(plant_id) left join public.health_status h on h.health_status_id = i.health_status_id
    group by 1, 2
  )
  select jsonb_build_object(
    'batches', coalesce((select jsonb_agg(to_jsonb(b) order by b.batch desc) from batches b), '[]'::jsonb),
    'colleges', coalesce((select jsonb_agg(to_jsonb(c) order by c.college_name) from colleges c), '[]'::jsonb),
    'health', coalesce((select jsonb_agg(to_jsonb(h) order by h.month desc, h.health) from changes h), '[]'::jsonb),
    'generated_on', (now() at time zone 'Asia/Manila')::date) into result;
  return result;
end;
$$;

revoke all on function public.check_inspection_draft(text, integer, integer) from public;
revoke all on function public.submit_inspection_draft(text, integer, text, integer, integer, integer, text, text, timestamptz) from public;
revoke all on function public.plant_monitoring_timeline(text, integer) from public;
revoke all on function public.monitoring_outcomes(text) from public;
grant execute on function public.check_inspection_draft(text, integer, integer) to anon, authenticated;
grant execute on function public.submit_inspection_draft(text, integer, text, integer, integer, integer, text, text, timestamptz) to anon, authenticated;
grant execute on function public.plant_monitoring_timeline(text, integer) to anon, authenticated;
grant execute on function public.monitoring_outcomes(text) to anon, authenticated;
create or replace function public.list_inspection_queue(
  p_session_token text, p_filter text, p_completed_since date
) returns table(
  plant_id integer, common_name text, variety text, campus_id integer, campus_name text,
  college_id integer, college_name text, last_inspected_on date, next_inspection_due_on date,
  inspection_interval_days integer, health_status text, growth_stage text, photo_url text,
  schedule_status text, days_overdue integer
) language plpgsql security definer set search_path = public, extensions as $$
declare actor_account public.users%rowtype; normalized_filter text; completed_cutoff date;
begin
  actor_account := public.require_app_session(p_session_token);
  normalized_filter := coalesce(nullif(lower(trim(p_filter)), ''), 'action');
  completed_cutoff := coalesce(p_completed_since, (now() at time zone 'Asia/Manila')::date - 30);
  if normalized_filter not in ('action', 'due_today', 'overdue', 'upcoming', 'completed', 'all') then
    raise exception 'Invalid inspection queue filter';
  end if;
  return query select p.plant_id, pc.common_name::text, p.variety::text,
    p.campus_id, c.campus_name::text, p.college_id, co.college_name::text,
    p.last_inspected_on, p.next_inspection_due_on, p.inspection_interval_days,
    hs.status_name::text, gs.growth_stage::text, p.photo_url::text,
    case when normalized_filter = 'completed' then 'completed'
      when p.next_inspection_due_on < (now() at time zone 'Asia/Manila')::date then 'overdue'
      when p.next_inspection_due_on = (now() at time zone 'Asia/Manila')::date then 'due_today'
      when p.next_inspection_due_on > (now() at time zone 'Asia/Manila')::date then 'upcoming' else 'unscheduled' end::text,
    case when p.next_inspection_due_on is null then 0
      else greatest((now() at time zone 'Asia/Manila')::date - p.next_inspection_due_on, 0)::integer end
  from public.plant p
  join public.plant_classification pc on pc.classification_id = p.classification_id
  join public.campus c on c.campus_id = p.campus_id
  join public.college co on co.college_id = p.college_id
  left join public.health_status hs on hs.health_status_id = p.health_status_id
  left join public.growth_status gs on gs.growth_status_id = p.growth_status_id
  where p.archived_at is null
    and (normalized_filter = 'completed' or not public.is_dead_plant_status(p.health_status_id))
    and (actor_account.role in ('super_admin', 'university_admin')
      or (actor_account.role = 'campus_admin' and p.campus_id = actor_account.campus_id)
      or (actor_account.role in ('college_admin', 'inspection_team')
        and p.campus_id = actor_account.campus_id and p.college_id = actor_account.college_id))
    and (normalized_filter = 'all'
      or (normalized_filter = 'action' and p.next_inspection_due_on <= (now() at time zone 'Asia/Manila')::date)
      or (normalized_filter = 'overdue' and p.next_inspection_due_on < (now() at time zone 'Asia/Manila')::date)
      or (normalized_filter = 'due_today' and p.next_inspection_due_on = (now() at time zone 'Asia/Manila')::date)
      or (normalized_filter = 'upcoming' and p.next_inspection_due_on > (now() at time zone 'Asia/Manila')::date)
      or (normalized_filter = 'completed' and p.last_inspected_on >= completed_cutoff))
  order by case when normalized_filter = 'completed' then p.last_inspected_on end desc,
    p.next_inspection_due_on, p.plant_id;
end;
$$;

notify pgrst, 'reload schema';
commit;
