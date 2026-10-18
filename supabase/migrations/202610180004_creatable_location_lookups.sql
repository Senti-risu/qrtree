-- Staff may add missing registration locations; only Super Admin may add campuses.
-- Existing lookup rows are reused, never renamed or overwritten.
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
  if p_kind = 'campus' then
    if actor.role is distinct from 'super_admin' then
      raise exception 'Super Admin access required to add a campus';
    end if;
  elsif p_kind in ('town', 'barangay') then
    if actor.role not in ('super_admin', 'university_admin', 'campus_admin', 'college_admin', 'inspection_team')
        or actor.role is null then
      raise exception 'Staff access required to add a location';
    end if;
  else
    raise exception 'Unsupported lookup type';
  end if;

  clean_name := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  if length(clean_name) < 1 or length(clean_name) > 100
      or clean_name ~ '[[:cntrl:]]' then
    raise exception 'Name must contain 1 to 100 printable characters';
  end if;
  if p_kind = 'barangay' and not exists (
    select 1 from public.town t where t.town_id = p_town_id
  ) then
    raise exception 'Select a valid town before adding a barangay';
  end if;

  -- Serialize matching additions so concurrent clients reuse the same row.
  perform pg_advisory_xact_lock(hashtextextended(
    p_kind || ':' || case when p_kind = 'barangay' then p_town_id::text else '' end
      || ':' || lower(clean_name), 0));

  if p_kind = 'campus' then
    select to_jsonb(c) into result_row from public.campus c
    where lower(btrim(regexp_replace(c.campus_name, '\s+', ' ', 'g'))) = lower(clean_name)
    order by c.campus_id limit 1;
    if result_row is not null then return result_row; end if;
    insert into public.campus(campus_name) values (clean_name)
    returning campus_id into new_id;
    select to_jsonb(c) into result_row from public.campus c where c.campus_id = new_id;
  elsif p_kind = 'town' then
    select to_jsonb(t) into result_row from public.town t
    where lower(btrim(regexp_replace(t.town_name, '\s+', ' ', 'g'))) = lower(clean_name)
    order by t.town_id limit 1;
    if result_row is not null then return result_row; end if;
    if coalesce(p_zip_code, '') !~ '^\d{4}$' then
      raise exception 'Enter a 4-digit zip code';
    end if;
    -- Populate using the table's actual ZIP type (text or numeric).
    insert into public.town(town_name, zip_code)
    select clean_name, typed.zip_code
    from jsonb_populate_record(null::public.town,
      jsonb_build_object('zip_code', p_zip_code)) typed
    returning town_id into new_id;
    select to_jsonb(t) into result_row from public.town t where t.town_id = new_id;
  else
    select to_jsonb(b) into result_row from public.barangay b
    where b.town_id = p_town_id
      and lower(btrim(regexp_replace(b.barangay_name, '\s+', ' ', 'g'))) = lower(clean_name)
    order by b.barangay_id limit 1;
    if result_row is not null then return result_row; end if;
    insert into public.barangay(barangay_name, town_id) values (clean_name, p_town_id)
    returning barangay_id into new_id;
    select to_jsonb(b) into result_row from public.barangay b where b.barangay_id = new_id;
  end if;

  perform public.write_audit_event(actor.user_id, 'lookup.created', p_kind,
    new_id::text, actor.campus_id, actor.college_id, null, result_row, null);
  return result_row;
end;
$$;

revoke all on function public.app_add_lookup(text, text, text, integer, text) from public;
grant execute on function public.app_add_lookup(text, text, text, integer, text) to anon, authenticated;

commit;
