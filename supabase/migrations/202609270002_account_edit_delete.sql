-- Account editing and safe deletion. Apply after 202609230001_secure_role_hierarchy.sql.
alter table public.users add column if not exists deleted_at timestamptz;
create index if not exists users_not_deleted_idx on public.users(user_id) where deleted_at is null;

create or replace function public.login_user(p_username text, p_password text)
returns table(
  user_id integer, username text, role text, campus_id integer,
  college_id integer, is_active boolean, session_token text
)
language plpgsql security definer set search_path = public, extensions
as $$
declare found_user public.users%rowtype; password_ok boolean; raw_token text;
begin
  select * into found_user from public.users u
  where lower(u.username) = lower(trim(p_username)) and u.deleted_at is null;
  if not found then return; end if;
  if found_user.password_hash like '$2%' then
    password_ok := found_user.password_hash = crypt(p_password, found_user.password_hash);
  else
    password_ok := found_user.password_hash = p_password;
  end if;
  if not password_ok then return; end if;
  if found_user.password_hash = p_password then
    update public.users set password_hash = crypt(p_password, gen_salt('bf'))
    where users.user_id = found_user.user_id;
  end if;
  if found_user.is_active then
    raw_token := encode(gen_random_bytes(32), 'hex');
    insert into public.app_sessions(user_id, token_hash, expires_at)
    values(found_user.user_id, encode(digest(raw_token, 'sha256'), 'hex'), now() + interval '12 hours');
  end if;
  return query select found_user.user_id, found_user.username::text,
    found_user.role::text, found_user.campus_id, found_user.college_id,
    found_user.is_active, raw_token;
end;
$$;

create or replace function public.super_admin_list_users(p_session_token text)
returns table(
  user_id integer, username text, role text, campus_id integer,
  campus_name text, college_id integer, college_name text, is_active boolean
)
language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;
  return query select u.user_id, u.username::text, u.role::text, u.campus_id,
    c.campus_name::text, u.college_id, co.college_name::text, u.is_active
  from public.users u
  left join public.campus c on c.campus_id = u.campus_id
  left join public.college co on co.college_id = u.college_id
  where u.role in ('university_admin', 'campus_admin', 'college_admin')
    and u.deleted_at is null
  order by u.username;
end;
$$;

create or replace function public.super_admin_update_user(
  p_session_token text, p_target_user_id integer, p_username text, p_role text,
  p_campus_id integer default null, p_college_id integer default null,
  p_new_password text default null
)
returns void language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;
  if not exists(select 1 from public.users u where u.user_id = p_target_user_id
    and u.role in ('university_admin', 'campus_admin', 'college_admin') and u.deleted_at is null)
  then raise exception 'Managed admin account not found'; end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_role not in ('university_admin', 'campus_admin', 'college_admin') then raise exception 'Invalid admin role'; end if;
  if p_new_password is not null and p_new_password <> '' and length(p_new_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;
  if p_role = 'university_admin' and (p_campus_id is not null or p_college_id is not null) then raise exception 'University Admin must be university-wide'; end if;
  if p_role = 'campus_admin' and (p_campus_id is null or p_college_id is not null) then raise exception 'Campus Admin requires one campus'; end if;
  if p_role = 'college_admin' and (p_campus_id is null or p_college_id is null) then raise exception 'College Admin requires one campus and college'; end if;
  if p_campus_id is not null and not exists(select 1 from public.campus c where c.campus_id = p_campus_id) then raise exception 'Campus not found'; end if;
  if p_college_id is not null and not exists(select 1 from public.college c where c.college_id = p_college_id and c.campus_id = p_campus_id) then raise exception 'College does not belong to selected campus'; end if;

  update public.users set username = trim(p_username), role = p_role::public.user_role,
    campus_id = p_campus_id, college_id = p_college_id,
    password_hash = case when p_new_password is null or p_new_password = ''
      then password_hash else crypt(p_new_password, gen_salt('bf')) end
  where user_id = p_target_user_id;
  update public.app_sessions set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;
end;
$$;

create or replace function public.super_admin_set_user_active(
  p_session_token text, p_target_user_id integer, p_is_active boolean
)
returns void language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;
  update public.users set is_active = p_is_active
  where user_id = p_target_user_id
    and role in ('university_admin', 'campus_admin', 'college_admin')
    and deleted_at is null;
  if not found then raise exception 'Managed admin account not found'; end if;
  if not p_is_active then
    update public.app_sessions set revoked_at = now()
    where user_id = p_target_user_id and revoked_at is null;
  end if;
end;
$$;

create or replace function public.super_admin_delete_user(
  p_session_token text, p_target_user_id integer
)
returns void language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;
  update public.users set is_active = false, deleted_at = now()
  where user_id = p_target_user_id
    and role in ('university_admin', 'campus_admin', 'college_admin')
    and deleted_at is null;
  if not found then raise exception 'Managed admin account not found'; end if;
  update public.app_sessions set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;
end;
$$;

create or replace function public.college_admin_list_inspection_users(p_session_token text)
returns table(user_id integer, username text, is_active boolean, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  return query select u.user_id, u.username::text, u.is_active, u.created_at
  from public.users u where u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
    and u.deleted_at is null order by u.username;
end;
$$;

create or replace function public.college_admin_update_inspection_user(
  p_session_token text, p_target_user_id integer, p_username text,
  p_new_password text default null
)
returns void language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_new_password is not null and p_new_password <> '' and length(p_new_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;
  update public.users u set username = trim(p_username),
    password_hash = case when p_new_password is null or p_new_password = ''
      then password_hash else crypt(p_new_password, gen_salt('bf')) end
  where u.user_id = p_target_user_id and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
    and u.deleted_at is null;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;
  update public.app_sessions set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;
end;
$$;

create or replace function public.college_admin_set_inspection_user_active(
  p_session_token text, p_target_user_id integer, p_is_active boolean
)
returns void language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  update public.users u set is_active = p_is_active
  where u.user_id = p_target_user_id and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
    and u.deleted_at is null;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;
  if not p_is_active then
    update public.app_sessions set revoked_at = now()
    where user_id = p_target_user_id and revoked_at is null;
  end if;
end;
$$;

create or replace function public.college_admin_delete_inspection_user(
  p_session_token text, p_target_user_id integer
)
returns void language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  update public.users u set is_active = false, deleted_at = now()
  where u.user_id = p_target_user_id and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
    and u.deleted_at is null;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;
  update public.app_sessions set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;
end;
$$;

revoke all on function public.super_admin_update_user(text, integer, text, text, integer, integer, text) from public;
revoke all on function public.super_admin_delete_user(text, integer) from public;
revoke all on function public.college_admin_update_inspection_user(text, integer, text, text) from public;
revoke all on function public.college_admin_delete_inspection_user(text, integer) from public;
grant execute on function public.super_admin_update_user(text, integer, text, text, integer, integer, text) to anon, authenticated;
grant execute on function public.super_admin_delete_user(text, integer) to anon, authenticated;
grant execute on function public.college_admin_update_inspection_user(text, integer, text, text) to anon, authenticated;
grant execute on function public.college_admin_delete_inspection_user(text, integer) to anon, authenticated;
notify pgrst, 'reload schema';
