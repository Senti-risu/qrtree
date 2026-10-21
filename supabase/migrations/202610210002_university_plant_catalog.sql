begin;

create table if not exists public.plant_classification_variety (
  variety_id bigserial primary key,
  classification_id integer not null
    references public.plant_classification(classification_id) on delete cascade,
  variety_name text not null,
  created_by integer references public.users(user_id),
  created_at timestamptz not null default now(),
  constraint plant_classification_variety_name_length
    check (length(btrim(variety_name)) between 1 and 100)
);

create unique index if not exists plant_classification_variety_name_unique
  on public.plant_classification_variety (
    classification_id,
    lower(btrim(regexp_replace(variety_name, '\s+', ' ', 'g')))
  );

alter table public.plant_classification_variety enable row level security;
drop policy if exists "plant classification varieties readable"
  on public.plant_classification_variety;
create policy "plant classification varieties readable"
  on public.plant_classification_variety for select using (true);

revoke all on table public.plant_classification_variety
  from public, anon, authenticated;
grant select on table public.plant_classification_variety to anon, authenticated;
revoke all on sequence public.plant_classification_variety_variety_id_seq
  from public, anon, authenticated;
revoke insert, update, delete on table public.plant_classification
  from public, anon, authenticated;

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
  clean_type public.plant_classification.plant_type%type;
  type_label text;
  clean_common_name text;
  clean_scientific_name text;
  clean_variety text;
  variety_id bigint;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role is distinct from 'university_admin' then
    raise exception 'University Admin access required';
  end if;

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

  select e.enumlabel into type_label
  from pg_attribute a
  join pg_type t on t.oid = a.atttypid
  join pg_enum e on e.enumtypid = t.oid
  where a.attrelid = 'public.plant_classification'::regclass
    and a.attname = 'plant_type'
    and lower(e.enumlabel) = lower(btrim(coalesce(p_plant_type, '')))
  limit 1;
  if type_label is null then
    raise exception 'Select a valid plant type';
  end if;
  clean_type := type_label;

  perform pg_advisory_xact_lock(hashtextextended(
    lower(clean_type::text) || ':' || lower(clean_common_name), 0
  ));
  select c.* into classification
  from public.plant_classification c
  where lower(c.plant_type::text) = lower(clean_type::text)
    and lower(btrim(regexp_replace(c.common_name, '\s+', ' ', 'g')))
      = lower(clean_common_name)
  order by c.classification_id
  limit 1
  for update;

  if not found then
    insert into public.plant_classification (
      plant_type, common_name, scientific_name
    ) values (
      clean_type, clean_common_name, clean_scientific_name
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

revoke all on function public.university_admin_create_plant_classification(
  text, text, text, text, text
) from public;
grant execute on function public.university_admin_create_plant_classification(
  text, text, text, text, text
) to anon, authenticated;

create or replace function public.validate_plant_catalog_variety()
returns trigger
language plpgsql set search_path = public as $$
begin
  if nullif(btrim(new.variety), '') is not null
      and not exists (
        select 1
        from public.plant_classification_variety v
        where v.classification_id = new.classification_id
          and lower(btrim(v.variety_name)) = lower(btrim(new.variety))
      ) then
    if tg_op = 'UPDATE'
        and new.classification_id is not distinct from old.classification_id
        and new.variety is not distinct from old.variety then
      return new;
    end if;
    raise exception 'Select a variety from the university plant catalog';
  end if;
  return new;
end;
$$;

drop trigger if exists plant_catalog_variety_validation on public.plant;
create trigger plant_catalog_variety_validation
  before insert or update of classification_id, variety on public.plant
  for each row execute function public.validate_plant_catalog_variety();

revoke all on function public.register_plant_with_new_classification(
  text, text, text, integer, integer, integer, integer, integer, integer,
  integer, text, integer, text, date, text, text, integer, text
) from anon, authenticated;
revoke all on function public.register_plant_with_scientific_name(
  text, integer, integer, integer, integer, integer, integer, integer,
  integer, text, integer, text, date, text, text, integer, text
) from anon, authenticated;
revoke all on function public.app_save_missing_scientific_name(
  text, integer, text
) from anon, authenticated;

notify pgrst, 'reload schema';
commit;
