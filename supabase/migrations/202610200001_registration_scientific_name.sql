-- Scientific name and registration commit together; failed registration rolls both back.
begin;
create or replace function public.register_plant_with_scientific_name(
  p_session_token text, p_classification_id integer, p_campus_id integer, p_college_id integer,
  p_town_id integer, p_barangay_id integer, p_growth_status_id integer, p_health_status_id integer,
  p_registered_by integer, p_location_type text, p_location_campus_id integer,
  p_variety text default null, p_date_planted date default null, p_tree_planter text default null,
  p_photo_url text default null, p_existing_qr_tag_id integer default null,
  p_scientific_name text default null
) returns table(plant_id integer, qr_tag_id integer, qr_code_string text)
language plpgsql security definer set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  classification public.plant_classification%rowtype;
  clean_name text;
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

  clean_name := nullif(btrim(regexp_replace(coalesce(p_scientific_name, ''), '\s+', ' ', 'g')), '');
  if clean_name is not null then
    if length(clean_name) > 200 or clean_name ~ '[[:cntrl:]]' then
      raise exception 'Scientific name must contain 1 to 200 printable characters';
    end if;
    select c.* into classification from public.plant_classification c
      where c.classification_id = p_classification_id for update;
    if not found then raise exception 'Plant classification not found'; end if;
    if nullif(btrim(classification.scientific_name), '') is null then
      update public.plant_classification set scientific_name = clean_name
        where classification_id = p_classification_id;
      perform public.write_audit_event(actor.user_id, 'classification.scientific_name_added',
        'plant_classification', p_classification_id::text, actor.campus_id, actor.college_id,
        jsonb_build_object('scientific_name', classification.scientific_name),
        jsonb_build_object('scientific_name', clean_name), null);
    elsif classification.scientific_name is distinct from clean_name then
      raise exception 'Scientific name changed. Reload registration and review the saved name';
    end if;
  end if;

  return query select * from public.register_plant_at_location(
    p_session_token => p_session_token, p_classification_id => p_classification_id,
    p_campus_id => p_campus_id, p_college_id => p_college_id,
    p_town_id => p_town_id, p_barangay_id => p_barangay_id,
    p_growth_status_id => p_growth_status_id, p_health_status_id => p_health_status_id,
    p_registered_by => p_registered_by, p_location_type => p_location_type,
    p_location_campus_id => p_location_campus_id, p_variety => p_variety,
    p_date_planted => p_date_planted, p_tree_planter => p_tree_planter,
    p_photo_url => p_photo_url, p_existing_qr_tag_id => p_existing_qr_tag_id
  );
end;
$$;
revoke all on function public.register_plant_with_scientific_name(text, integer, integer, integer, integer, integer, integer, integer, integer, text, integer, text, date, text, text, integer, text) from public;
grant execute on function public.register_plant_with_scientific_name(text, integer, integer, integer, integer, integer, integer, integer, integer, text, integer, text, date, text, text, integer, text) to anon, authenticated;
notify pgrst, 'reload schema';
commit;
