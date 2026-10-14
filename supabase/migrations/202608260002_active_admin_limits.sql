-- One active University Admin overall, one active Campus Admin per campus,
-- and one active College Admin per college. Inactive historical accounts
-- remain stored and do not occupy a slot.

create unique index if not exists one_active_university_admin
  on public.users ((role))
  where role = 'university_admin' and is_active = true;

create unique index if not exists one_active_campus_admin_per_campus
  on public.users (campus_id)
  where role = 'campus_admin' and is_active = true;

create unique index if not exists one_active_college_admin_per_college
  on public.users (college_id)
  where role = 'college_admin' and is_active = true;

create or replace function public.enforce_active_admin_limit()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.is_active is not true then return new; end if;

  if new.role = 'university_admin' and exists (
    select 1 from public.users u
    where u.role = 'university_admin' and u.is_active
      and u.user_id is distinct from new.user_id
  ) then
    raise exception 'Only one active University Admin is allowed';
  end if;

  if new.role = 'campus_admin' and exists (
    select 1 from public.users u
    where u.role = 'campus_admin' and u.is_active
      and u.campus_id = new.campus_id
      and u.user_id is distinct from new.user_id
  ) then
    raise exception 'This campus already has an active Campus Admin';
  end if;

  if new.role = 'college_admin' and exists (
    select 1 from public.users u
    where u.role = 'college_admin' and u.is_active
      and u.college_id = new.college_id
      and u.user_id is distinct from new.user_id
  ) then
    raise exception 'This college already has an active College Admin';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_active_admin_limit_trigger on public.users;
create trigger enforce_active_admin_limit_trigger
before insert or update of role, campus_id, college_id, is_active on public.users
for each row execute function public.enforce_active_admin_limit();

notify pgrst, 'reload schema';
