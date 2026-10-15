-- Apply after 202610150002_plant_physical_location.sql.
-- Keep dead plants and their QR/history; stop routine work on them.
begin;

create or replace function public.is_dead_plant_status(p_health_status_id integer)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.health_status h
    where h.health_status_id = p_health_status_id
      and lower(trim(h.status_name::text)) in ('dead', 'deceased'));
$$;
revoke all on function public.is_dead_plant_status(integer) from public;

update public.plant p set next_inspection_due_on = null
where public.is_dead_plant_status(p.health_status_id)
  and p.next_inspection_due_on is not null;

create or replace function public.enforce_dead_plant_lock()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare
  actor_account public.users%rowtype;
  reopen_token text;
  reopen_reason text;
  permitted_columns text[] := array[
    'qr_tag_id', 'archived_at', 'archived_by', 'archive_reason', 'updated_at'
  ];
begin
  if tg_op <> 'INSERT' and public.is_dead_plant_status(old.health_status_id) then
    if tg_op = 'DELETE' then
      raise exception 'Dead plant is locked; preserve its record and history';
    end if;
    -- Registration initializes physical location in the same transaction as
    -- insertion. Permit only that one scoped initialization, never a later edit.
    if current_setting('ecotag.dead_registration_plant', true) = old.plant_id::text
        and old.planting_location_type = 'unknown'
        and old.created_at >= transaction_timestamp()
        and (to_jsonb(new) - (permitted_columns || array[
          'planting_location_type', 'planting_campus_id', 'town_id', 'barangay_id']))
          is not distinct from
          (to_jsonb(old) - (permitted_columns || array[
          'planting_location_type', 'planting_campus_id', 'town_id', 'barangay_id'])) then
      actor_account := public.require_app_session(
        current_setting('ecotag.dead_registration_token', true));
      if actor_account.role in ('college_admin', 'inspection_team')
          and actor_account.campus_id = old.campus_id
          and actor_account.college_id = old.college_id
          and actor_account.user_id = old.registered_by then
        new.next_inspection_due_on := null;
        return new;
      end if;
    end if;
    if (to_jsonb(new) - permitted_columns)
        is distinct from (to_jsonb(old) - permitted_columns) then
      reopen_token := nullif(current_setting('ecotag.dead_reopen_token', true), '');
      reopen_reason := nullif(trim(current_setting('ecotag.dead_reopen_reason', true)), '');
      if reopen_token is null or reopen_reason is null
          or length(reopen_reason) not between 3 and 250
          or old.archived_at is not null
          or new.health_status_id is null
          or public.is_dead_plant_status(new.health_status_id)
          or new.health_status_id is not distinct from old.health_status_id
          or (to_jsonb(new) - (permitted_columns || array['health_status_id', 'next_inspection_due_on']))
             is distinct from
             (to_jsonb(old) - (permitted_columns || array['health_status_id', 'next_inspection_due_on'])) then
        raise exception 'Dead plant is locked; College Admin must reopen it with a reason';
      end if;
      actor_account := public.require_app_session(reopen_token);
      if actor_account.role <> 'college_admin'
          or actor_account.campus_id is distinct from old.campus_id
          or actor_account.college_id is distinct from old.college_id then
        raise exception 'Dead plant is locked; assigned College Admin access required';
      end if;
      perform public.write_audit_event(
        actor_account.user_id, 'plant.dead_record_reopened', 'plant', old.plant_id::text,
        old.campus_id, old.college_id,
        jsonb_build_object('health_status_id', old.health_status_id,
          'next_inspection_due_on', old.next_inspection_due_on),
        jsonb_build_object('health_status_id', new.health_status_id,
          'next_inspection_due_on', new.next_inspection_due_on, 'reason', reopen_reason),
        jsonb_build_object('reason', reopen_reason));
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  if public.is_dead_plant_status(new.health_status_id) then
    new.next_inspection_due_on := null;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_dead_plant_lock() from public;
drop trigger if exists enforce_dead_plant_lock on public.plant;
create trigger enforce_dead_plant_lock before insert or update or delete on public.plant
for each row execute function public.enforce_dead_plant_lock();

create or replace function public.prevent_dead_plant_inspection()
returns trigger language plpgsql security definer set search_path = public as $$
declare target_plant public.plant%rowtype;
begin
  -- Serialize with status changes/reopening, including requests from old apps.
  select * into target_plant from public.plant p
    where p.plant_id = new.plant_id for update;
  if public.is_dead_plant_status(target_plant.health_status_id) then
    raise exception 'Dead plant is locked; new inspections are disabled';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_dead_plant_inspection() from public;
drop trigger if exists prevent_dead_plant_inspection on public.inspection;
create trigger prevent_dead_plant_inspection before insert on public.inspection
for each row execute function public.prevent_dead_plant_inspection();

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
    next_inspection_due_on = current_date + coalesce(p.inspection_interval_days, 90)
    where p.plant_id = p_plant_id;
  perform set_config('ecotag.dead_reopen_token', '', true);
  perform set_config('ecotag.dead_reopen_reason', '', true);
end;
$$;
revoke all on function public.college_admin_reopen_dead_plant(text, integer, integer, text) from public;
grant execute on function public.college_admin_reopen_dead_plant(text, integer, integer, text) to anon, authenticated;

create or replace function public.register_plant_at_location(
  p_session_token text, p_classification_id integer, p_campus_id integer, p_college_id integer,
  p_town_id integer, p_barangay_id integer, p_growth_status_id integer, p_health_status_id integer,
  p_registered_by integer, p_location_type text, p_location_campus_id integer,
  p_variety text default null, p_date_planted date default null, p_tree_planter text default null,
  p_photo_url text default null, p_existing_qr_tag_id integer default null
) returns table(plant_id integer, qr_tag_id integer, qr_code_string text)
language plpgsql security definer set search_path = public, extensions as $$
declare created_plant record;
begin
  select * into created_plant from public.register_plant_with_qr(
    p_session_token => p_session_token, p_classification_id => p_classification_id,
    p_campus_id => p_campus_id, p_college_id => p_college_id,
    p_town_id => p_town_id, p_barangay_id => p_barangay_id,
    p_growth_status_id => p_growth_status_id, p_health_status_id => p_health_status_id,
    p_registered_by => p_registered_by, p_variety => p_variety, p_date_planted => p_date_planted,
    p_tree_planter => p_tree_planter, p_photo_url => p_photo_url, p_existing_qr_tag_id => p_existing_qr_tag_id);
  perform set_config('ecotag.dead_registration_plant', created_plant.plant_id::text, true);
  perform set_config('ecotag.dead_registration_token', p_session_token, true);
  perform public.update_plant_physical_location(p_session_token, created_plant.plant_id,
    p_location_type, p_location_campus_id, p_town_id, p_barangay_id);
  perform set_config('ecotag.dead_registration_plant', '', true);
  perform set_config('ecotag.dead_registration_token', '', true);
  return query select created_plant.plant_id::integer, created_plant.qr_tag_id::integer,
    created_plant.qr_code_string::text;
end;
$$;

-- Preserve the existing RPC signature and history/audit format.
create or replace function public.inspection_team_submit_inspection(
  p_session_token text, p_plant_id integer, p_health_status_id integer,
  p_growth_status_id integer, p_observation text default null, p_photo_url text default null
) returns void language plpgsql security definer set search_path = public, extensions as $$
declare actor_account public.users%rowtype; target_plant public.plant%rowtype; next_due_on date;
begin
  actor_account := public.require_app_session(p_session_token);
  if actor_account.role <> 'inspection_team' then raise exception 'Inspection Team access required'; end if;
  select * into target_plant from public.plant p where p.plant_id = p_plant_id
    and p.campus_id = actor_account.campus_id and p.college_id = actor_account.college_id
    and p.archived_at is null for update;
  if not found then raise exception 'Plant is outside your assigned college or is archived'; end if;
  if public.is_dead_plant_status(target_plant.health_status_id) then
    raise exception 'Dead plant is locked; new inspections are disabled';
  end if;
  if not exists (select 1 from public.health_status h where h.health_status_id = p_health_status_id)
    then raise exception 'Health status not found'; end if;
  if not exists (select 1 from public.growth_status g where g.growth_status_id = p_growth_status_id)
    then raise exception 'Growth status not found'; end if;
  next_due_on := case when public.is_dead_plant_status(p_health_status_id) then null
    else current_date + target_plant.inspection_interval_days end;
  insert into public.inspection (
    plant_id, inspected_by, health_status_id, growth_status_id,
    observation, photo_url, last_inspection_date, inspected_at
  ) values (p_plant_id, actor_account.user_id, p_health_status_id, p_growth_status_id,
    nullif(trim(p_observation), ''), nullif(trim(p_photo_url), ''), current_date, now());
  update public.plant p set health_status_id = p_health_status_id,
    growth_status_id = p_growth_status_id,
    photo_url = coalesce(nullif(trim(p_photo_url), ''), p.photo_url),
    last_inspected_on = current_date, next_inspection_due_on = next_due_on
    where p.plant_id = p_plant_id;
  perform public.write_audit_event(actor_account.user_id, 'inspection.submitted', 'plant',
    p_plant_id::text, actor_account.campus_id, actor_account.college_id,
    jsonb_build_object('health_status_id', target_plant.health_status_id,
      'growth_status_id', target_plant.growth_status_id,
      'last_inspected_on', target_plant.last_inspected_on,
      'next_inspection_due_on', target_plant.next_inspection_due_on),
    jsonb_build_object('health_status_id', p_health_status_id, 'growth_status_id', p_growth_status_id,
      'last_inspected_on', current_date, 'next_inspection_due_on', next_due_on),
    jsonb_build_object('has_observation', nullif(trim(p_observation), '') is not null,
      'has_photo', nullif(trim(p_photo_url), '') is not null));
end;
$$;

-- Dead plants remain in completed history, not inspection work queues.
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
  completed_cutoff := coalesce(p_completed_since, current_date - 30);
  if normalized_filter not in ('action', 'due_today', 'overdue', 'upcoming', 'completed', 'all') then
    raise exception 'Invalid inspection queue filter';
  end if;
  return query select p.plant_id, pc.common_name::text, p.variety::text,
    p.campus_id, c.campus_name::text, p.college_id, co.college_name::text,
    p.last_inspected_on, p.next_inspection_due_on, p.inspection_interval_days,
    hs.status_name::text, gs.growth_stage::text, p.photo_url::text,
    case when normalized_filter = 'completed' then 'completed'
      when p.next_inspection_due_on < current_date then 'overdue'
      when p.next_inspection_due_on = current_date then 'due_today'
      when p.next_inspection_due_on > current_date then 'upcoming' else 'unscheduled' end::text,
    case when p.next_inspection_due_on is null then 0
      else greatest(current_date - p.next_inspection_due_on, 0)::integer end
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
      or (normalized_filter = 'action' and p.next_inspection_due_on <= current_date)
      or (normalized_filter = 'overdue' and p.next_inspection_due_on < current_date)
      or (normalized_filter = 'due_today' and p.next_inspection_due_on = current_date)
      or (normalized_filter = 'upcoming' and p.next_inspection_due_on > current_date)
      or (normalized_filter = 'completed' and p.last_inspected_on >= completed_cutoff))
  order by case when normalized_filter = 'completed' then p.last_inspected_on end desc,
    p.next_inspection_due_on, p.plant_id;
end;
$$;
notify pgrst, 'reload schema';
commit;
