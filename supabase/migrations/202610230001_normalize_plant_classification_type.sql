begin;

alter table public.plant_classification
  add column if not exists plant_type_id bigint;

update public.plant_classification c
set plant_type_id = t.plant_type_id
from public.plant_type_catalog t
where lower(btrim(regexp_replace(c.plant_type, '\s+', ' ', 'g')))
    = lower(btrim(regexp_replace(t.plant_type, '\s+', ' ', 'g')))
  and c.plant_type_id is null;

do $$
begin
  if exists (
    select 1
    from public.plant_classification
    where plant_type_id is null
  ) then
    raise exception
      'Cannot normalize plant types: some classifications have no matching catalog entry';
  end if;
end;
$$;

alter table public.plant_classification
  alter column plant_type_id set not null;

alter table public.plant_classification
  add constraint plant_classification_plant_type_id_fkey
  foreign key (plant_type_id)
  references public.plant_type_catalog (plant_type_id);

create or replace function public.sync_plant_classification_type()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  resolved_id bigint;
  resolved_name text;
begin
  if tg_op = 'UPDATE'
      and new.plant_type_id is distinct from old.plant_type_id
      and new.plant_type is not distinct from old.plant_type then
    select p.plant_type
    into resolved_name
    from public.plant_type_catalog p
    where p.plant_type_id = new.plant_type_id;

    if not found then
      raise exception 'Select a valid plant type from the catalog';
    end if;

    new.plant_type := resolved_name;
    return new;
  end if;

  select p.plant_type_id, p.plant_type
  into resolved_id, resolved_name
  from public.plant_type_catalog p
  where lower(btrim(regexp_replace(p.plant_type, '\s+', ' ', 'g')))
    = lower(btrim(regexp_replace(coalesce(new.plant_type, ''), '\s+', ' ', 'g')))
  order by p.plant_type_id
  limit 1;

  if resolved_id is null then
    raise exception 'Select a valid plant type from the catalog';
  end if;
  if new.plant_type_id is not null and new.plant_type_id <> resolved_id then
    raise exception 'Plant type ID and name do not match';
  end if;

  new.plant_type_id := resolved_id;
  new.plant_type := resolved_name;
  return new;
end;
$$;

revoke all on function public.sync_plant_classification_type() from public;

drop trigger if exists plant_classification_type_sync_trigger
  on public.plant_classification;
create trigger plant_classification_type_sync_trigger
before insert or update of plant_type, plant_type_id
on public.plant_classification
for each row execute function public.sync_plant_classification_type();

notify pgrst, 'reload schema';
commit;
