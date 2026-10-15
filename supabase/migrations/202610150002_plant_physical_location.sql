-- Ownership stays in plant.campus_id / college_id. Planting location is separate.
begin;
alter table public.plant add column if not exists planting_location_type text not null default 'unknown';
alter table public.plant add column if not exists planting_campus_id integer references public.campus(campus_id);
alter table public.plant drop constraint if exists plant_planting_location_check;
alter table public.plant add constraint plant_planting_location_check check (
  (planting_location_type = 'inside' and planting_campus_id is not null)
  or (planting_location_type in ('outside', 'unknown') and planting_campus_id is null)
);

create or replace function public.update_plant_physical_location(
  p_session_token text, p_plant_id integer, p_location_type text,
  p_location_campus_id integer, p_town_id integer, p_barangay_id integer
) returns void language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype; target public.plant%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in ('college_admin', 'inspection_team') then raise exception 'College Admin or Inspection Team access required'; end if;
  select * into target from public.plant p where p.plant_id = p_plant_id
    and p.campus_id = actor.campus_id and p.college_id = actor.college_id
    and p.archived_at is null for update;
  if not found then raise exception 'Plant is outside your assigned college or is archived'; end if;
  if p_location_type is null or p_location_type not in ('inside', 'outside') then raise exception 'Select where the plant is planted'; end if;
  if p_location_type = 'inside' and (p_location_campus_id is null or not exists (
    select 1 from public.campus c where c.campus_id = p_location_campus_id
  )) then raise exception 'Select a valid planting campus'; end if;
  if p_location_type = 'outside' and p_location_campus_id is not null then raise exception 'Outside-campus plants cannot have a planting campus'; end if;
  if not exists (select 1 from public.town t where t.town_id = p_town_id) then raise exception 'Select a valid town'; end if;
  if not exists (select 1 from public.barangay b where b.barangay_id = p_barangay_id and b.town_id = p_town_id) then raise exception 'Barangay must belong to the selected town'; end if;
  update public.plant set planting_location_type = p_location_type, planting_campus_id = p_location_campus_id,
    town_id = p_town_id, barangay_id = p_barangay_id where plant.plant_id = p_plant_id;
  perform public.write_audit_event(actor.user_id, 'plant.location_updated', 'plant', p_plant_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object('location_type', target.planting_location_type, 'location_campus_id', target.planting_campus_id, 'town_id', target.town_id, 'barangay_id', target.barangay_id),
    jsonb_build_object('location_type', p_location_type, 'location_campus_id', p_location_campus_id, 'town_id', p_town_id, 'barangay_id', p_barangay_id));
end;
$$;

create or replace function public.get_plant_physical_location(p_session_token text, p_plant_id integer)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare actor public.users%rowtype; result jsonb;
begin
  actor := public.require_app_session(p_session_token);
  select jsonb_build_object('planting_location_type', p.planting_location_type,
    'planting_campus_id', p.planting_campus_id, 'planting_campus_name', c.campus_name,
    'town_id', p.town_id, 'barangay_id', p.barangay_id) into result
  from public.plant p left join public.campus c on c.campus_id = p.planting_campus_id
  where p.plant_id = p_plant_id and (
    actor.role in ('super_admin', 'university_admin')
    or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
    or (actor.role in ('college_admin', 'inspection_team') and p.campus_id = actor.campus_id and p.college_id = actor.college_id));
  if result is null then raise exception 'Plant not found in your assigned scope'; end if;
  return result;
end;
$$;

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
    p_growth_status_id, p_health_status_id, 90,
    coalesce(p_date_planted, current_date) + 90
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
      'inspection_interval_days', 90,
      'next_inspection_due_on',
        coalesce(p_date_planted, current_date) + 90
    )
  );

  return query
  select new_plant_id, selected_qr.qr_tag_id,
    selected_qr.qr_code_string::text;
end;
$$;

create or replace function public.guest_view_plant_by_qr(
  p_visit_id bigint,
  p_qr_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  normalized_code text;
  target_tag public.qr_tag%rowtype;
  tag_status text;
  outcome_message text;
  plant_payload jsonb;
  target_plant_id integer;
  target_campus_id integer;
  target_college_id integer;
begin
  if p_visit_id is null or not exists (
    select 1
    from public.guest_visit v
    where v.visit_id = p_visit_id
  ) then
    raise exception 'A valid guest visit is required';
  end if;

  normalized_code := upper(trim(coalesce(p_qr_code, '')));
  if normalized_code = '' or length(normalized_code) > 160 then
    raise exception 'Enter a valid EcoTag code';
  end if;

  select q.*
    into target_tag
  from public.qr_tag q
  -- Valid EcoTag codes are generated in uppercase. Exact matching keeps the
  -- lookup deterministic and allows the authoritative unique index from the
  -- QR-numbering migration to be used.
  where q.qr_code_string::text = normalized_code
  limit 1;

  if not found then
    perform public.write_audit_event(
      null,
      'guest.qr_scanned',
      'guest_visit',
      p_visit_id::text,
      null,
      null,
      null,
      null,
      jsonb_build_object('outcome', 'not_found')
    );
    return jsonb_build_object(
      'result_status', 'not_found',
      'message', 'This is not a recognized EcoTag. Check the label and try again.'
    );
  end if;

  tag_status := coalesce(
    nullif(lower(trim(target_tag.lifecycle_status)), ''),
    nullif(lower(trim(target_tag.status::text)), ''),
    'unknown'
  );
  if tag_status = 'lost' then tag_status := 'retired'; end if;

  if tag_status <> 'assigned' then
    outcome_message := case tag_status
      when 'available' then
        'This EcoTag has not been assigned to a plant yet.'
      when 'damaged' then
        'This EcoTag was reported damaged. Please scan the replacement label.'
      when 'replaced' then
        'This EcoTag was replaced. Please scan the newer label on the plant.'
      when 'retired' then
        'This EcoTag is retired and no longer opens a plant profile.'
      else
        'This EcoTag is currently unavailable.'
    end;

    perform public.write_audit_event(
      null,
      'guest.qr_scanned',
      'qr_tag',
      target_tag.qr_tag_id::text,
      target_tag.campus_id,
      target_tag.college_id,
      null,
      null,
      jsonb_build_object(
        'visit_id', p_visit_id,
        'outcome', tag_status
      )
    );
    return jsonb_build_object(
      'result_status', tag_status,
      'message', outcome_message
    );
  end if;

  select
    jsonb_build_object(
      'plant_id', p.plant_id,
      'qr_code', target_tag.qr_code_string::text,
      'common_name', pc.common_name::text,
      'scientific_name', pc.scientific_name::text,
      'plant_type', pc.plant_type::text,
      'variety', p.variety::text,
      'photo_url', p.photo_url::text,
      'date_planted', p.date_planted,
      'tree_planter', p.tree_planter::text,
      'campus_name', c.campus_name::text,
      'planting_location_type', p.planting_location_type,
      'planting_campus_name', planting_campus.campus_name::text,
      'college_name', co.college_name::text,
      'town_name', t.town_name::text,
      'barangay_name', b.barangay_name::text,
      'growth_stage', gs.growth_stage::text,
      'health_status', hs.status_name::text
    ),
    p.plant_id,
    p.campus_id,
    p.college_id
  into plant_payload, target_plant_id, target_campus_id, target_college_id
  from public.plant p
  join public.plant_classification pc
    on pc.classification_id = p.classification_id
  left join public.campus c on c.campus_id = p.campus_id
  left join public.campus planting_campus on planting_campus.campus_id = p.planting_campus_id
  left join public.college co on co.college_id = p.college_id
  left join public.town t on t.town_id = p.town_id
  left join public.barangay b on b.barangay_id = p.barangay_id
  left join public.growth_status gs
    on gs.growth_status_id = p.growth_status_id
  left join public.health_status hs
    on hs.health_status_id = p.health_status_id
  where p.archived_at is null
    and (
      p.plant_id = target_tag.assigned_plant_id
      or p.qr_tag_id = target_tag.qr_tag_id
    )
  order by case
    when p.plant_id = target_tag.assigned_plant_id then 0
    else 1
  end
  limit 1;

  if plant_payload is null then
    perform public.write_audit_event(
      null,
      'guest.qr_scanned',
      'qr_tag',
      target_tag.qr_tag_id::text,
      target_tag.campus_id,
      target_tag.college_id,
      null,
      null,
      jsonb_build_object(
        'visit_id', p_visit_id,
        'outcome', 'plant_unavailable'
      )
    );
    return jsonb_build_object(
      'result_status', 'unavailable',
      'message', 'The plant profile linked to this EcoTag is unavailable.'
    );
  end if;

  perform public.write_audit_event(
    null,
    'guest.qr_viewed',
    'plant',
    target_plant_id::text,
    target_campus_id,
    target_college_id,
    null,
    null,
    jsonb_build_object(
      'visit_id', p_visit_id,
      'qr_tag_id', target_tag.qr_tag_id,
      'access', 'read_only'
    )
  );

  return jsonb_build_object(
    'result_status', 'assigned',
    'message', 'Plant profile found.',
    'plant', plant_payload
  );
end;
$$;

create or replace function public.register_plant_at_location(
  p_session_token text, p_classification_id integer, p_campus_id integer, p_college_id integer,
  p_town_id integer, p_barangay_id integer, p_growth_status_id integer, p_health_status_id integer,
  p_registered_by integer, p_location_type text, p_location_campus_id integer,
  p_variety text default null, p_date_planted date default null, p_tree_planter text default null,
  p_photo_url text default null, p_existing_qr_tag_id integer default null
) returns table(plant_id integer, qr_tag_id integer, qr_code_string text)
language plpgsql security definer set search_path = public, extensions as $$
declare created record;
begin
  -- Both calls share a transaction: invalid location rolls back the plant and QR.
  select * into created from public.register_plant_with_qr(
    p_session_token => p_session_token, p_classification_id => p_classification_id,
    p_campus_id => p_campus_id, p_college_id => p_college_id,
    p_town_id => p_town_id, p_barangay_id => p_barangay_id,
    p_growth_status_id => p_growth_status_id, p_health_status_id => p_health_status_id,
    p_registered_by => p_registered_by, p_variety => p_variety, p_date_planted => p_date_planted,
    p_tree_planter => p_tree_planter, p_photo_url => p_photo_url, p_existing_qr_tag_id => p_existing_qr_tag_id);
  perform public.update_plant_physical_location(p_session_token, created.plant_id,
    p_location_type, p_location_campus_id, p_town_id, p_barangay_id);
  return query select created.plant_id::integer, created.qr_tag_id::integer, created.qr_code_string::text;
end;
$$;

revoke all on function public.update_plant_physical_location(text, integer, text, integer, integer, integer) from public;
revoke all on function public.get_plant_physical_location(text, integer) from public;
revoke all on function public.register_plant_at_location(text, integer, integer, integer, integer, integer, integer, integer, integer, text, integer, text, date, text, text, integer) from public;
grant execute on function public.update_plant_physical_location(text, integer, text, integer, integer, integer) to anon, authenticated;
grant execute on function public.get_plant_physical_location(text, integer) to anon, authenticated;
grant execute on function public.register_plant_at_location(text, integer, integer, integer, integer, integer, integer, integer, integer, text, integer, text, date, text, text, integer) to anon, authenticated;
commit;
