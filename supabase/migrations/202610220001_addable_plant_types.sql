begin;

create table if not exists public.plant_type_catalog (
  plant_type_id bigserial primary key,
  plant_type text not null,
  created_by integer references public.users(user_id),
  created_at timestamptz not null default now(),
  constraint plant_type_catalog_name_length
    check (length(btrim(plant_type)) between 1 and 80)
);

create unique index if not exists plant_type_catalog_name_unique
  on public.plant_type_catalog (
    lower(btrim(regexp_replace(plant_type, '\s+', ' ', 'g')))
  );

insert into public.plant_type_catalog (plant_type)
select distinct e.enumlabel
from pg_attribute a
join pg_type t on t.oid = a.atttypid
join pg_enum e on e.enumtypid = t.oid
where a.attrelid = 'public.plant_classification'::regclass
  and a.attname = 'plant_type'
on conflict do nothing;

insert into public.plant_type_catalog (plant_type)
select distinct btrim(c.plant_type::text)
from public.plant_classification c
where nullif(btrim(c.plant_type::text), '') is not null
on conflict do nothing;

alter table public.plant_classification
  alter column plant_type type text using plant_type::text;

alter table public.plant_type_catalog enable row level security;
drop policy if exists "plant types readable" on public.plant_type_catalog;
create policy "plant types readable"
  on public.plant_type_catalog for select using (true);
revoke all on table public.plant_type_catalog from public, anon, authenticated;
grant select on table public.plant_type_catalog to anon, authenticated;
revoke all on sequence public.plant_type_catalog_plant_type_id_seq
  from public, anon, authenticated;
revoke insert, update, delete on table public.plant_classification
  from public, anon, authenticated;

create or replace function public.university_admin_add_plant_type(
  p_session_token text,
  p_plant_type text
) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  clean_type text;
  saved_type text;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;
  clean_type := nullif(
    btrim(regexp_replace(coalesce(p_plant_type, ''), '\s+', ' ', 'g')),
    ''
  );
  if clean_type is null or length(clean_type) > 80
      or clean_type ~ '[[:cntrl:]]' then
    raise exception 'Plant type must contain 1 to 80 printable characters';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('plant-type:' || lower(clean_type), 0));
  select p.plant_type into saved_type
  from public.plant_type_catalog p
  where lower(btrim(regexp_replace(p.plant_type, '\s+', ' ', 'g')))
    = lower(clean_type)
  order by p.plant_type_id
  limit 1;
  if saved_type is not null then
    return saved_type;
  end if;

  insert into public.plant_type_catalog (plant_type, created_by)
  values (clean_type, actor.user_id)
  returning plant_type into saved_type;
  perform public.write_audit_event(
    actor.user_id, 'plant_type.created', 'plant_type_catalog',
    saved_type, actor.campus_id, actor.college_id, null,
    jsonb_build_object('plant_type', saved_type), null
  );
  return saved_type;
end;
$$;

create or replace function public.university_admin_create_plant_classification(
  p_session_token text,
  p_plant_type text,
  p_common_name text,
  p_scientific_name text,
  p_variety text default null
) returns integer
language plpgsql security definer set search_path = public, extensions as $$
declare
  actor public.users%rowtype;
  classification public.plant_classification%rowtype;
  type_label text;
  clean_type text;
  clean_common_name text;
  clean_scientific_name text;
  clean_variety text;
  variety_id bigint;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;

  clean_type := nullif(
    btrim(regexp_replace(coalesce(p_plant_type, ''), '\s+', ' ', 'g')),
    ''
  );
  clean_common_name := nullif(
    btrim(regexp_replace(coalesce(p_common_name, ''), '\s+', ' ', 'g')),
    ''
  );
  clean_scientific_name := nullif(
    btrim(regexp_replace(coalesce(p_scientific_name, ''), '\s+', ' ', 'g')),
    ''
  );
  clean_variety := nullif(
    btrim(regexp_replace(coalesce(p_variety, ''), '\s+', ' ', 'g')),
    ''
  );
  if clean_type is null or length(clean_type) > 80
      or clean_type ~ '[[:cntrl:]]' then
    raise exception 'Plant type must contain 1 to 80 printable characters';
  end if;
  if clean_common_name is null or length(clean_common_name) > 100
      or clean_common_name ~ '[[:cntrl:]]' then
    raise exception 'Common name must contain 1 to 100 printable characters';
  end if;
  if clean_scientific_name is null or length(clean_scientific_name) > 200
      or clean_scientific_name ~ '[[:cntrl:]]' then
    raise exception 'Scientific name must contain 1 to 200 printable characters';
  end if;
  if clean_variety is not null and (length(clean_variety) > 100
      or clean_variety ~ '[[:cntrl:]]') then
    raise exception 'Variety must contain at most 100 printable characters';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('plant-type:' || lower(clean_type), 0));
  select p.plant_type into type_label
  from public.plant_type_catalog p
  where lower(btrim(regexp_replace(p.plant_type, '\s+', ' ', 'g')))
    = lower(clean_type)
  order by p.plant_type_id
  limit 1
  for update;
  if type_label is null then
    raise exception 'Add this plant type to the university catalog first';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    lower(type_label) || ':' || lower(clean_common_name), 0
  ));
  select c.* into classification
  from public.plant_classification c
  where lower(c.plant_type) = lower(type_label)
    and lower(btrim(regexp_replace(c.common_name, '\s+', ' ', 'g')))
      = lower(clean_common_name)
  order by c.classification_id
  limit 1
  for update;

  if not found then
    insert into public.plant_classification (
      plant_type, common_name, scientific_name
    ) values (
      type_label, clean_common_name, clean_scientific_name
    )
    returning * into classification;
    perform public.write_audit_event(
      actor.user_id, 'classification.created', 'plant_classification',
      classification.classification_id::text, actor.campus_id,
      actor.college_id, null,
      jsonb_build_object(
        'plant_type', classification.plant_type,
        'common_name', classification.common_name,
        'scientific_name', classification.scientific_name
      ),
      null
    );
  elsif nullif(btrim(classification.scientific_name), '') is null then
    update public.plant_classification
    set scientific_name = clean_scientific_name
    where classification_id = classification.classification_id;
    perform public.write_audit_event(
      actor.user_id, 'classification.scientific_name_added',
      'plant_classification', classification.classification_id::text,
      actor.campus_id, actor.college_id,
      jsonb_build_object('scientific_name', classification.scientific_name),
      jsonb_build_object('scientific_name', clean_scientific_name), null
    );
  elsif classification.scientific_name is distinct from clean_scientific_name then
    raise exception 'Scientific name conflicts with the saved classification';
  end if;

  if clean_variety is not null then
    perform pg_advisory_xact_lock(hashtextextended(
      'variety:' || classification.classification_id::text || ':'
        || lower(clean_variety),
      0
    ));
    select v.variety_id into variety_id
    from public.plant_classification_variety v
    where v.classification_id = classification.classification_id
      and lower(btrim(regexp_replace(v.variety_name, '\s+', ' ', 'g')))
        = lower(clean_variety)
    limit 1;
    if variety_id is null then
      insert into public.plant_classification_variety (
        classification_id, variety_name, created_by
      ) values (
        classification.classification_id, clean_variety, actor.user_id
      )
      returning plant_classification_variety.variety_id into variety_id;
      perform public.write_audit_event(
        actor.user_id, 'classification.variety_created',
        'plant_classification_variety', variety_id::text,
        actor.campus_id, actor.college_id, null,
        jsonb_build_object(
          'classification_id', classification.classification_id,
          'variety_name', clean_variety
        ),
        null
      );
    end if;
  end if;

  return classification.classification_id;
end;
$$;

revoke all on function public.university_admin_add_plant_type(text, text)
  from public;
grant execute on function public.university_admin_add_plant_type(text, text)
  to anon, authenticated;
revoke all on function public.university_admin_create_plant_classification(
  text, text, text, text, text
) from public;
grant execute on function public.university_admin_create_plant_classification(
  text, text, text, text, text
) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
