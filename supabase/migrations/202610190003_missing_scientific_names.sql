begin;

create or replace function public.app_save_missing_scientific_name(
  p_session_token text, p_classification_id integer, p_scientific_name text
)
returns text language plpgsql security definer
set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  target public.plant_classification%rowtype;
  clean_name text;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in ('college_admin', 'inspection_team') then
    raise exception 'College Admin or Inspection Team access required';
  end if;
  clean_name := btrim(regexp_replace(coalesce(p_scientific_name, ''), '\s+', ' ', 'g'));
  if length(clean_name) not between 1 and 200 or clean_name ~ '[[:cntrl:]]' then
    raise exception 'Scientific name must contain 1 to 200 printable characters';
  end if;
  select c.* into target from public.plant_classification c
    where c.classification_id = p_classification_id for update;
  if not found then raise exception 'Plant classification not found'; end if;
  -- A concurrent submission must reuse the saved name, never overwrite it.
  if nullif(btrim(target.scientific_name), '') is not null then
    return target.scientific_name;
  end if;
  update public.plant_classification set scientific_name = clean_name
    where classification_id = p_classification_id;
  perform public.write_audit_event(actor.user_id, 'classification.scientific_name_added',
    'plant_classification', p_classification_id::text, actor.campus_id, actor.college_id,
    jsonb_build_object('scientific_name', target.scientific_name),
    jsonb_build_object('scientific_name', clean_name), null);
  return clean_name;
end;
$$;
revoke all on function public.app_save_missing_scientific_name(text, integer, text) from public;
grant execute on function public.app_save_missing_scientific_name(text, integer, text) to anon, authenticated;
commit;
