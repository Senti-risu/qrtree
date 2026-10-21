begin;

create or replace function public.prevent_dead_status_on_plant_registration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_dead_plant_status(new.health_status_id) then
    raise exception 'Dead status can only be set during plant inspection';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_dead_status_on_plant_registration()
  from public, anon, authenticated;

drop trigger if exists prevent_dead_status_on_plant_registration
  on public.plant;
create trigger prevent_dead_status_on_plant_registration
before insert on public.plant
for each row
execute function public.prevent_dead_status_on_plant_registration();

commit;
