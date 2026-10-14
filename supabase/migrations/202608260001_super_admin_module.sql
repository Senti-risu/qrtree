-- EcoTag Super Admin support for the existing integer-key users/campus/college schema.
create extension if not exists pgcrypto;

alter table public.users
  add column if not exists is_active boolean not null default true;

create unique index if not exists users_username_lower_unique
  on public.users (lower(username));

create or replace function public.login_user(p_username text, p_password text)
returns table(user_id integer, username text, role text, campus_id integer, college_id integer, is_active boolean)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  found_user public.users%rowtype;
  password_ok boolean;
begin
  select * into found_user from public.users u
  where lower(u.username) = lower(trim(p_username));

  if not found then return; end if;
  if found_user.password_hash like '$2%' then
    password_ok := found_user.password_hash = crypt(p_password, found_user.password_hash);
  else
    password_ok := found_user.password_hash = p_password; -- legacy account
  end if;
  if not password_ok then return; end if;

  if found_user.password_hash = p_password then
    update public.users set password_hash = crypt(p_password, gen_salt('bf'))
    where users.user_id = found_user.user_id;
  end if;

  return query select found_user.user_id, found_user.username::text, found_user.role::text,
    found_user.campus_id, found_user.college_id, found_user.is_active;
end;
$$;

create or replace function public.super_admin_list_users(p_actor_user_id integer)
returns table(
  user_id integer, username text, role text, campus_id integer,
  campus_name text, college_id integer, college_name text, is_active boolean
)
language plpgsql security definer set search_path = public
as $$
begin
  if not exists(select 1 from public.users where users.user_id = p_actor_user_id and users.role = 'super_admin' and users.is_active) then
    raise exception 'Super Admin access required';
  end if;
  return query
    select u.user_id, u.username::text, u.role::text, u.campus_id,
      c.campus_name::text, u.college_id, co.college_name::text, u.is_active
    from public.users u
    left join public.campus c on c.campus_id = u.campus_id
    left join public.college co on co.college_id = u.college_id
    where u.role in ('university_admin', 'campus_admin', 'college_admin')
    order by u.username;
end;
$$;

create or replace function public.super_admin_create_user(
  p_actor_user_id integer, p_username text, p_password text, p_role text,
  p_campus_id integer default null, p_college_id integer default null
)
returns integer language plpgsql security definer set search_path = public, extensions
as $$
declare new_user_id integer;
begin
  if not exists(select 1 from public.users where users.user_id = p_actor_user_id and users.role = 'super_admin' and users.is_active) then
    raise exception 'Super Admin access required';
  end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_password is null or length(p_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;
  if p_role not in ('university_admin', 'campus_admin', 'college_admin') then raise exception 'Invalid admin role'; end if;
  if p_role = 'university_admin' and (p_campus_id is not null or p_college_id is not null) then raise exception 'University Admin must be university-wide'; end if;
  if p_role = 'campus_admin' and (p_campus_id is null or p_college_id is not null) then raise exception 'Campus Admin requires one campus'; end if;
  if p_role = 'college_admin' and (p_campus_id is null or p_college_id is null) then raise exception 'College Admin requires one campus and college'; end if;
  if p_campus_id is not null and not exists(select 1 from public.campus where campus.campus_id = p_campus_id) then raise exception 'Campus not found'; end if;
  if p_college_id is not null and not exists(select 1 from public.college where college.college_id = p_college_id and college.campus_id = p_campus_id) then raise exception 'College does not belong to selected campus'; end if;

  insert into public.users(username, password_hash, role, campus_id, college_id, is_active, created_by)
  values(trim(p_username), crypt(p_password, gen_salt('bf')), p_role::public.user_role, p_campus_id, p_college_id, true, p_actor_user_id)
  returning users.user_id into new_user_id;
  return new_user_id;
end;
$$;

create or replace function public.super_admin_set_user_active(p_actor_user_id integer, p_target_user_id integer, p_is_active boolean)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not exists(select 1 from public.users where users.user_id = p_actor_user_id and users.role = 'super_admin' and users.is_active) then
    raise exception 'Super Admin access required';
  end if;
  update public.users set is_active = p_is_active
  where users.user_id = p_target_user_id and users.role in ('university_admin', 'campus_admin', 'college_admin');
  if not found then raise exception 'Managed admin account not found'; end if;
end;
$$;

revoke all on function public.login_user(text, text) from public;
revoke all on function public.super_admin_list_users(integer) from public;
revoke all on function public.super_admin_create_user(integer, text, text, text, integer, integer) from public;
revoke all on function public.super_admin_set_user_active(integer, integer, boolean) from public;
grant execute on function public.login_user(text, text) to anon, authenticated;
grant execute on function public.super_admin_list_users(integer) to anon, authenticated;
grant execute on function public.super_admin_create_user(integer, text, text, text, integer, integer) to anon, authenticated;
grant execute on function public.super_admin_set_user_active(integer, integer, boolean) to anon, authenticated;
