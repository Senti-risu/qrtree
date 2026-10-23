begin;

create or replace function public.prevent_inactive_plant_classification_assignment()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  classification_active boolean;
begin
  if tg_op = 'INSERT'
      or new.classification_id is distinct from old.classification_id then
    select c.is_active
    into classification_active
    from public.plant_classification c
    where c.classification_id = new.classification_id
    for share;

    if not found or not classification_active then
      raise exception 'This plant classification is no longer available for new plants';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.university_admin_delete_plant_classification(
  p_session_token text,
  p_classification_id integer
) returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target public.plant_classification%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;
  if p_classification_id is null then
    raise exception 'Select a plant classification to remove';
  end if;

  select c.* into target
  from public.plant_classification c
  where c.classification_id = p_classification_id
  for update;
  if not found then
    raise exception 'Plant classification not found';
  end if;
  if not target.is_active then
    return;
  end if;

  if exists (
    select 1
    from public.plant p
    where p.classification_id = p_classification_id
  ) then
    raise exception 'This plant classification cannot be removed because existing plants use it';
  end if;

  update public.plant_classification
  set is_active = false
  where classification_id = p_classification_id;

  perform public.write_audit_event(
    actor.user_id,
    'classification.removed_from_catalog',
    'plant_classification',
    p_classification_id::text,
    actor.campus_id,
    actor.college_id,
    jsonb_build_object(
      'plant_type', target.plant_type,
      'common_name', target.common_name,
      'scientific_name', target.scientific_name,
      'is_active', true
    ),
    jsonb_build_object('is_active', false),
    null
  );
end;
$$;

revoke all on function public.university_admin_delete_plant_classification(
  text, integer
) from public;
grant execute on function public.university_admin_delete_plant_classification(
  text, integer
) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
