begin;

create or replace function public.university_admin_update_plant_type(
  p_session_token text,
  p_current_plant_type text,
  p_plant_type text
) returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_id bigint;
  old_type text;
  clean_type text;
  affected_classifications integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;

  old_type := nullif(
    btrim(regexp_replace(coalesce(p_current_plant_type, ''), '\s+', ' ', 'g')),
    ''
  );
  clean_type := nullif(
    btrim(regexp_replace(coalesce(p_plant_type, ''), '\s+', ' ', 'g')),
    ''
  );
  if old_type is null then
    raise exception 'Select a plant type to edit';
  end if;
  if clean_type is null or length(clean_type) > 80
      or clean_type ~ '[[:cntrl:]]' then
    raise exception 'Plant type must contain 1 to 80 printable characters';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('plant-type:' || lower(clean_type), 0)
  );

  select p.plant_type_id, p.plant_type
  into target_id, old_type
  from public.plant_type_catalog p
  where lower(btrim(regexp_replace(p.plant_type, '\s+', ' ', 'g')))
    = lower(btrim(regexp_replace(p_current_plant_type, '\s+', ' ', 'g')))
  order by p.plant_type_id
  limit 1
  for update;
  if target_id is null then
    raise exception 'Plant type not found';
  end if;

  if exists (
    select 1
    from public.plant_type_catalog p
    where p.plant_type_id <> target_id
      and lower(btrim(regexp_replace(p.plant_type, '\s+', ' ', 'g')))
        = lower(clean_type)
  ) then
    raise exception 'A plant type with this name already exists';
  end if;

  update public.plant_type_catalog
  set plant_type = clean_type
  where plant_type_id = target_id;

  update public.plant_classification
  set plant_type = clean_type
  where lower(btrim(regexp_replace(plant_type, '\s+', ' ', 'g')))
    = lower(btrim(regexp_replace(old_type, '\s+', ' ', 'g')));
  get diagnostics affected_classifications = row_count;

  perform public.write_audit_event(
    actor.user_id,
    'plant_type.updated',
    'plant_type_catalog',
    target_id::text,
    actor.campus_id,
    actor.college_id,
    jsonb_build_object(
      'plant_type', old_type,
      'affected_classifications', affected_classifications
    ),
    jsonb_build_object(
      'plant_type', clean_type,
      'affected_classifications', affected_classifications
    ),
    null
  );

  return clean_type;
end;
$$;

revoke all on function public.university_admin_update_plant_type(
  text, text, text
) from public;
grant execute on function public.university_admin_update_plant_type(
  text, text, text
) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
