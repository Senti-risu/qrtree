-- Create a missing classification and register its first plant atomically.
begin;

create or replace function public.register_plant_with_new_classification(
  p_session_token text,
  p_plant_type text,
  p_common_name text,
  p_campus_id integer,
  p_college_id integer,
  p_town_id integer,
  p_barangay_id integer,
  p_growth_status_id integer,
  p_health_status_id integer,
  p_registered_by integer,
  p_location_type text,
  p_location_campus_id integer,
  p_variety text default null,
  p_date_planted date default null,
  p_tree_planter text default null,
  p_photo_url text default null,
  p_existing_qr_tag_id integer default null,
  p_scientific_name text default null
) returns table(plant_id integer, qr_tag_id integer, qr_code_string text)
language plpgsql security definer set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  classification public.plant_classification%rowtype;
  clean_type public.plant_classification.plant_type%type;
  type_label text;
  clean_common_name text;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is null or actor.role not in ('college_admin', 'inspection_team') then
    raise exception 'College Admin or Inspection Team access required';
  end if;
  if p_campus_id is distinct from actor.campus_id
      or p_college_id is distinct from actor.college_id
      or p_registered_by is distinct from actor.user_id then
    raise exception 'Registration is outside your assigned campus or college';
  end if;

  if p_plant_type is null
      or lower(p_plant_type) not in ('tree', 'shrub', 'herb', 'vine') then
    raise exception 'Select a valid plant type';
  end if;
  select coalesce(
    (
      select e.enumlabel
      from pg_attribute a
      join pg_type t on t.oid = a.atttypid
      join pg_enum e on e.enumtypid = t.oid
      where a.attrelid = 'public.plant_classification'::regclass
        and a.attname = 'plant_type'
        and lower(e.enumlabel) = lower(p_plant_type)
      limit 1
    ),
    p_plant_type
  ) into type_label;
  clean_type := type_label;
  clean_common_name := nullif(
    btrim(regexp_replace(coalesce(p_common_name, ''), '\s+', ' ', 'g')),
    ''
  );
  if clean_common_name is null
      or length(clean_common_name) > 100
      or clean_common_name ~ '[[:cntrl:]]' then
    raise exception 'Common name must contain 1 to 100 printable characters';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(clean_type::text),
    hashtext(lower(clean_common_name))
  );
  select c.* into classification
  from public.plant_classification c
  where lower(c.plant_type::text) = lower(clean_type::text)
    and lower(btrim(c.common_name)) = lower(clean_common_name)
  order by c.classification_id
  limit 1
  for update;

  if not found then
    insert into public.plant_classification (plant_type, common_name)
    values (clean_type, clean_common_name)
    returning * into classification;
    perform public.write_audit_event(
      actor.user_id,
      'classification.created',
      'plant_classification',
      classification.classification_id::text,
      actor.campus_id,
      actor.college_id,
      null,
      jsonb_build_object(
        'plant_type', classification.plant_type,
        'common_name', classification.common_name
      ),
      null
    );
  end if;

  return query select * from public.register_plant_with_scientific_name(
    p_session_token => p_session_token,
    p_classification_id => classification.classification_id,
    p_campus_id => p_campus_id,
    p_college_id => p_college_id,
    p_town_id => p_town_id,
    p_barangay_id => p_barangay_id,
    p_growth_status_id => p_growth_status_id,
    p_health_status_id => p_health_status_id,
    p_registered_by => p_registered_by,
    p_location_type => p_location_type,
    p_location_campus_id => p_location_campus_id,
    p_variety => p_variety,
    p_date_planted => p_date_planted,
    p_tree_planter => p_tree_planter,
    p_photo_url => p_photo_url,
    p_existing_qr_tag_id => p_existing_qr_tag_id,
    p_scientific_name => p_scientific_name
  );
end;
$$;

revoke all on function public.register_plant_with_new_classification(
  text, text, text, integer, integer, integer, integer, integer, integer,
  integer, text, integer, text, date, text, text, integer, text
) from public;
grant execute on function public.register_plant_with_new_classification(
  text, text, text, integer, integer, integer, integer, integer, integer,
  integer, text, integer, text, date, text, text, integer, text
) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
