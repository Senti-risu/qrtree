-- Apply after physical location and dead-plant-lock migrations.
-- One transaction updates the plant's own fields and physical location.
begin;
create or replace function public.update_plant_details(
  p_session_token text, p_plant_id integer, p_classification_id integer,
  p_variety text, p_tree_planter text, p_date_planted date, p_photo_url text,
  p_location_type text, p_location_campus_id integer,
  p_town_id integer, p_barangay_id integer
) returns void language plpgsql security definer
set search_path = public, extensions as $$
declare
  actor_account public.users%rowtype;
  target_plant public.plant%rowtype;
  changed_plant public.plant%rowtype;
begin
  actor_account := public.require_app_session(p_session_token);
  if actor_account.role not in ('college_admin', 'inspection_team') then
    raise exception 'College Admin or Inspection Team access required';
  end if;
  select * into target_plant from public.plant p
    where p.plant_id = p_plant_id
      and p.campus_id = actor_account.campus_id
      and p.college_id = actor_account.college_id
      and p.archived_at is null for update;
  if not found then raise exception 'Plant is outside your assigned college or is archived'; end if;
  if public.is_dead_plant_status(target_plant.health_status_id) then
    raise exception 'Dead plant is locked; reopen it before editing';
  end if;
  if not exists (select 1 from public.plant_classification c where c.classification_id = p_classification_id) then
    raise exception 'Plant classification not found';
  end if;
  if p_date_planted > current_date then raise exception 'Date planted cannot be in the future'; end if;
  if length(coalesce(p_variety, '')) > 200 or length(coalesce(p_tree_planter, '')) > 200 then
    raise exception 'Variety and tree planter must be 200 characters or fewer';
  end if;
  -- Reuse scoped campus/town/barangay validation and location audit logging.
  -- If any step fails, PostgreSQL rolls back every field change together.
  perform public.update_plant_physical_location(p_session_token, p_plant_id,
    p_location_type, p_location_campus_id, p_town_id, p_barangay_id);
  update public.plant p set classification_id = p_classification_id,
    variety = nullif(trim(p_variety), ''),
    tree_planter = nullif(trim(p_tree_planter), ''),
    date_planted = p_date_planted,
    photo_url = nullif(trim(p_photo_url), '')
    where p.plant_id = p_plant_id returning p.* into changed_plant;
  perform public.write_audit_event(actor_account.user_id, 'plant.details_updated', 'plant',
    p_plant_id::text, actor_account.campus_id, actor_account.college_id,
    jsonb_build_object('classification_id', target_plant.classification_id, 'variety', target_plant.variety,
      'tree_planter', target_plant.tree_planter, 'date_planted', target_plant.date_planted, 'photo_url', target_plant.photo_url),
    jsonb_build_object('classification_id', changed_plant.classification_id, 'variety', changed_plant.variety,
      'tree_planter', changed_plant.tree_planter, 'date_planted', changed_plant.date_planted, 'photo_url', changed_plant.photo_url));
end;
$$;
revoke all on function public.update_plant_details(text, integer, integer, text, text, date, text, text, integer, integer, integer) from public;
grant execute on function public.update_plant_details(text, integer, integer, text, text, date, text, text, integer, integer, integer) to anon, authenticated;
notify pgrst, 'reload schema';
commit;
