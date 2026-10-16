-- Cancel cross-college registration if its migration was already applied.
-- Restores the three previous RPC definitions; does not delete or reassign data.
-- Safe to run even if the cross-college migration was never applied.
begin;

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

create or replace function public.find_possible_duplicate_plants(
  p_session_token text,
  p_classification_id integer,
  p_campus_id integer,
  p_college_id integer,
  p_town_id integer,
  p_barangay_id integer,
  p_variety text,
  p_date_planted date,
  p_limit integer
)
returns table(
  plant_id integer,
  common_name text,
  variety text,
  date_planted date,
  tree_planter text,
  campus_name text,
  college_name text,
  town_name text,
  barangay_name text,
  qr_code_string text,
  match_score integer,
  match_reasons text[],
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  safe_limit integer;
begin
  actor := public.require_app_session(p_session_token);
  safe_limit := least(greatest(coalesce(p_limit, 10), 1), 50);

  if actor.role not in ('super_admin', 'university_admin', 'campus_admin', 'college_admin', 'inspection_team') then
    raise exception 'EcoTag account access required';
  end if;
  if actor.role = 'campus_admin' and p_campus_id is distinct from actor.campus_id then
    raise exception 'Location is outside your assigned campus';
  end if;
  if actor.role in ('college_admin', 'inspection_team') and (
    p_campus_id is distinct from actor.campus_id
    or p_college_id is distinct from actor.college_id
  ) then
    raise exception 'Location is outside your assigned college';
  end if;

  return query
  with candidates as (
    select p.plant_id,
      pc.common_name::text as common_name,
      p.variety::text as variety,
      p.date_planted,
      p.tree_planter::text as tree_planter,
      c.campus_name::text as campus_name,
      co.college_name::text as college_name,
      t.town_name::text as town_name,
      b.barangay_name::text as barangay_name,
      q.qr_code_string::text as qr_code_string,
      (
        case when p.classification_id = p_classification_id then 4 else 0 end
        + case when nullif(trim(p_variety), '') is not null
                    and lower(trim(coalesce(p.variety, ''))) = lower(trim(p_variety))
               then 3 else 0 end
        + case when p.barangay_id = p_barangay_id then 2 else 0 end
        + case when p.town_id = p_town_id then 1 else 0 end
        + case when p_date_planted is not null and p.date_planted = p_date_planted
               then 1 else 0 end
      )::integer as match_score,
      array_remove(array[
        case when p.classification_id = p_classification_id then 'same classification' end,
        case when nullif(trim(p_variety), '') is not null
                  and lower(trim(coalesce(p.variety, ''))) = lower(trim(p_variety))
             then 'same variety' end,
        case when p.barangay_id = p_barangay_id then 'same barangay' end,
        case when p.town_id = p_town_id then 'same town' end,
        case when p_date_planted is not null and p.date_planted = p_date_planted
             then 'same planting date' end
      ]::text[], null) as match_reasons,
      p.created_at
    from public.plant p
    join public.plant_classification pc on pc.classification_id = p.classification_id
    join public.campus c on c.campus_id = p.campus_id
    join public.college co on co.college_id = p.college_id
    join public.town t on t.town_id = p.town_id
    join public.barangay b on b.barangay_id = p.barangay_id
    left join public.qr_tag q on q.qr_tag_id = p.qr_tag_id
    where p.archived_at is null
      and p.campus_id = p_campus_id
      and p.college_id = p_college_id
      and p.classification_id = p_classification_id
      and (
        p.barangay_id = p_barangay_id
        or (nullif(trim(p_variety), '') is not null
            and lower(trim(coalesce(p.variety, ''))) = lower(trim(p_variety)))
        or (p_date_planted is not null and p.date_planted = p_date_planted)
      )
  )
  select c.plant_id, c.common_name, c.variety, c.date_planted,
    c.tree_planter, c.campus_name, c.college_name, c.town_name,
    c.barangay_name, c.qr_code_string, c.match_score,
    c.match_reasons, c.created_at
  from candidates c
  order by c.match_score desc, c.created_at desc
  limit safe_limit;
end;
$$;

notify pgrst, 'reload schema';
commit;

