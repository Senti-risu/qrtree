-- The existing users.role column uses the user_role enum. The RPC accepts text
-- from Flutter, validates it, and must explicitly cast it before insertion.
create or replace function public.super_admin_create_user(
  p_actor_user_id integer,
  p_username text,
  p_password text,
  p_role text,
  p_campus_id integer default null,
  p_college_id integer default null
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  new_user_id integer;
begin
  if not exists (
    select 1 from public.users
    where users.user_id = p_actor_user_id
      and users.role = 'super_admin'
      and users.is_active
  ) then
    raise exception 'Super Admin access required';
  end if;

  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then
    raise exception 'Invalid username';
  end if;
  if p_password is null or length(p_password) < 8 then
    raise exception 'Password must contain at least 8 characters';
  end if;
  if p_role not in ('university_admin', 'campus_admin', 'college_admin') then
    raise exception 'Invalid admin role';
  end if;
  if p_role = 'university_admin' and (p_campus_id is not null or p_college_id is not null) then
    raise exception 'University Admin must be university-wide';
  end if;
  if p_role = 'campus_admin' and (p_campus_id is null or p_college_id is not null) then
    raise exception 'Campus Admin requires one campus';
  end if;
  if p_role = 'college_admin' and (p_campus_id is null or p_college_id is null) then
    raise exception 'College Admin requires one campus and college';
  end if;
  if p_campus_id is not null and not exists (
    select 1 from public.campus where campus.campus_id = p_campus_id
  ) then
    raise exception 'Campus not found';
  end if;
  if p_college_id is not null and not exists (
    select 1 from public.college
    where college.college_id = p_college_id
      and college.campus_id = p_campus_id
  ) then
    raise exception 'College does not belong to selected campus';
  end if;

  insert into public.users (
    username, password_hash, role, campus_id, college_id, is_active, created_by
  ) values (
    trim(p_username),
    crypt(p_password, gen_salt('bf')),
    p_role::public.user_role,
    p_campus_id,
    p_college_id,
    true,
    p_actor_user_id
  )
  returning users.user_id into new_user_id;

  return new_user_id;
end;
$$;

revoke all on function public.super_admin_create_user(integer, text, text, text, integer, integer) from public;
grant execute on function public.super_admin_create_user(integer, text, text, text, integer, integer) to anon, authenticated;
notify pgrst, 'reload schema';
