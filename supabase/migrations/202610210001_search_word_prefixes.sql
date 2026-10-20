-- Match literal word prefixes before pagination, keeping QR search and printing aligned.
create or replace function public.matches_search_word_prefixes(value text, query text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select not exists (
    select 1
    from regexp_split_to_table(lower(trim(coalesce(query, ''))), '[[:space:][:punct:]]+') as terms(term)
    where term <> '' and not exists (
      select 1
      from regexp_split_to_table(lower(coalesce(value, '')), '[[:space:][:punct:]]+') as words(word)
      where left(word, length(term)) = term
    )
  );
$$;

create or replace function public.college_admin_list_qr_tags(
  p_session_token text,
  p_status text default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table(
  qr_tag_id integer,
  qr_code_string text,
  status text,
  lifecycle_status text,
  created_at timestamptz,
  replacement_qr_tag_id integer,
  replacement_qr_code text,
  plant_id integer,
  common_name text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  safe_limit integer;
  safe_offset integer;
  normalized_status text;
  normalized_search text;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;

  safe_limit := least(greatest(coalesce(p_limit, 100), 1), 500);
  safe_offset := greatest(coalesce(p_offset, 0), 0);
  normalized_status := nullif(lower(trim(p_status)), '');
  normalized_search := nullif(trim(p_search), '');

  return query
  select q.qr_tag_id, q.qr_code_string::text, q.status::text,
    q.lifecycle_status, q.created_at, q.replacement_qr_tag_id,
    replacement.qr_code_string::text,
    coalesce(q.assigned_plant_id, p.plant_id), pc.common_name::text
  from public.qr_tag q
  left join public.qr_tag replacement
    on replacement.qr_tag_id = q.replacement_qr_tag_id
  left join public.plant p
    on p.plant_id = q.assigned_plant_id
      or (q.assigned_plant_id is null and p.qr_tag_id = q.qr_tag_id)
  left join public.plant_classification pc
    on pc.classification_id = p.classification_id
  where q.campus_id = actor.campus_id
    and q.college_id = actor.college_id
    and (
      normalized_status is null
      or q.lifecycle_status = normalized_status
      or lower(q.status::text) = normalized_status
    )
    and (
      public.matches_search_word_prefixes(
        concat_ws(' ', q.qr_code_string, q.qr_tag_id::text,
          p.plant_id::text, pc.common_name), normalized_search
      )
    )
  order by q.qr_tag_id desc
  limit safe_limit offset safe_offset;
end;
$$;

