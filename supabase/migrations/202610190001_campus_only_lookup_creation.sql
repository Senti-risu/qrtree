-- Follow 202610180004_creatable_location_lookups.sql.
-- Keep the existing client signature, but remove Town/Barangay creation.
-- Existing lookup and plant records are not changed.
begin;

create or replace function public.app_add_lookup(
  p_session_token text,
  p_kind text,
  p_name text,
  p_town_id integer default null,
  p_zip_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  clean_name text;
  result_row jsonb;
  new_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'super_admin' then
    raise exception 'Super Admin access required';
  end if;
  if p_kind is distinct from 'campus' then
    raise exception 'Only Campus creation is supported';
  end if;

  clean_name := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  if length(clean_name) < 1 or length(clean_name) > 100
      or clean_name ~ '[[:cntrl:]]' then
    raise exception 'Name must contain 1 to 100 printable characters';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('campus::' || lower(clean_name), 0));
  select to_jsonb(c) into result_row from public.campus c
  where lower(btrim(regexp_replace(c.campus_name, '\s+', ' ', 'g'))) = lower(clean_name)
  order by c.campus_id limit 1;
  if result_row is not null then return result_row; end if;

  insert into public.campus(campus_name) values (clean_name)
  returning campus_id into new_id;
  select to_jsonb(c) into result_row from public.campus c where c.campus_id = new_id;
  perform public.write_audit_event(actor.user_id, 'lookup.created', 'campus',
    new_id::text, actor.campus_id, actor.college_id, null, result_row, null);
  return result_row;
end;
$$;

revoke all on function public.app_add_lookup(text, text, text, integer, text) from public;
grant execute on function public.app_add_lookup(text, text, text, integer, text) to anon, authenticated;

commit;
