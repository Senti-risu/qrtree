-- Allow University Admins to edit centrally managed plant classifications.
begin;

create or replace function public.university_admin_update_plant_classification(
  p_session_token text,
  p_classification_id integer,
  p_plant_type text,
  p_common_name text,
  p_scientific_name text
) returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target public.plant_classification%rowtype;
  type_label text;
  clean_common_name text;
  clean_scientific_name text;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;
  if p_classification_id is null then
    raise exception 'Select a plant classification to edit';
  end if;

  clean_common_name := nullif(
    btrim(regexp_replace(coalesce(p_common_name, ''), '\s+', ' ', 'g')),
    ''
  );
  clean_scientific_name := nullif(
    btrim(regexp_replace(coalesce(p_scientific_name, ''), '\s+', ' ', 'g')),
    ''
  );
  if clean_common_name is null or length(clean_common_name) > 100
      or clean_common_name ~ '[[:cntrl:]]' then
    raise exception 'Common name must contain 1 to 100 printable characters';
  end if;
  if clean_scientific_name is null or length(clean_scientific_name) > 200
      or clean_scientific_name ~ '[[:cntrl:]]' then
    raise exception 'Scientific name must contain 1 to 200 printable characters';
  end if;

  select p.plant_type into type_label
  from public.plant_type_catalog p
  where lower(btrim(regexp_replace(p.plant_type, '\s+', ' ', 'g')))
    = lower(btrim(regexp_replace(coalesce(p_plant_type, ''), '\s+', ' ', 'g')))
  order by p.plant_type_id
  limit 1;
  if type_label is null then
    raise exception 'Select a plant type from the university catalog';
  end if;

  select c.* into target
  from public.plant_classification c
  where c.classification_id = p_classification_id
  for update;
  if not found then
    raise exception 'Plant classification not found';
  end if;

  if exists (
    select 1
    from public.plant_classification c
    where c.classification_id <> p_classification_id
      and lower(btrim(regexp_replace(c.plant_type, '\s+', ' ', 'g')))
        = lower(type_label)
      and lower(btrim(regexp_replace(c.common_name, '\s+', ' ', 'g')))
        = lower(clean_common_name)
  ) then
    raise exception 'A classification with this plant type and common name already exists';
  end if;

  update public.plant_classification
  set plant_type = type_label,
      common_name = clean_common_name,
      scientific_name = clean_scientific_name
  where classification_id = p_classification_id;

  perform public.write_audit_event(
    actor.user_id,
    'classification.updated',
    'plant_classification',
    p_classification_id::text,
    actor.campus_id,
    actor.college_id,
    jsonb_build_object(
      'plant_type', target.plant_type,
      'common_name', target.common_name,
      'scientific_name', target.scientific_name
    ),
    jsonb_build_object(
      'plant_type', type_label,
      'common_name', clean_common_name,
      'scientific_name', clean_scientific_name
    ),
    null
  );
end;
$$;

revoke all on function public.university_admin_update_plant_classification(
  text, integer, text, text, text
) from public;
grant execute on function public.university_admin_update_plant_classification(
  text, integer, text, text, text
) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
