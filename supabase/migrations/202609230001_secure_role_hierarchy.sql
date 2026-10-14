-- Secure EcoTag custom sessions and role-scoped write operations.
-- Run this migration after all earlier EcoTag migrations.
create extension if not exists pgcrypto;

create table if not exists public.app_sessions (
  session_id bigserial primary key,
  user_id integer not null references public.users(user_id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz
);

create index if not exists app_sessions_user_id_idx
  on public.app_sessions(user_id);
create index if not exists app_sessions_active_token_idx
  on public.app_sessions(token_hash) where revoked_at is null;

alter table public.app_sessions enable row level security;
revoke all on table public.app_sessions from anon, authenticated;
revoke all on sequence public.app_sessions_session_id_seq from anon, authenticated;

create or replace function public.require_app_session(p_session_token text)
returns public.users
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
begin
  if p_session_token is null or length(p_session_token) < 32 then
    raise exception 'A valid EcoTag session is required';
  end if;

  select u.* into actor
  from public.app_sessions s
  join public.users u on u.user_id = s.user_id
  where s.token_hash = encode(digest(p_session_token, 'sha256'), 'hex')
    and s.revoked_at is null
    and s.expires_at > now()
    and u.is_active = true;

  if not found then
    raise exception 'Your session has expired. Please sign in again.';
  end if;

  update public.app_sessions
  set last_seen_at = now()
  where token_hash = encode(digest(p_session_token, 'sha256'), 'hex');
  return actor;
end;
$$;
revoke all on function public.require_app_session(text) from public;

drop function if exists public.login_user(text, text);
create function public.login_user(p_username text, p_password text)
returns table(
  user_id integer, username text, role text, campus_id integer,
  college_id integer, is_active boolean, session_token text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  found_user public.users%rowtype;
  password_ok boolean;
  raw_token text;
begin
  select * into found_user
  from public.users u
  where lower(u.username) = lower(trim(p_username));
  if not found then return; end if;

  if found_user.password_hash like '$2%' then
    password_ok := found_user.password_hash = crypt(p_password, found_user.password_hash);
  else
    password_ok := found_user.password_hash = p_password;
  end if;
  if not password_ok then return; end if;

  if found_user.password_hash = p_password then
    update public.users
    set password_hash = crypt(p_password, gen_salt('bf'))
    where users.user_id = found_user.user_id;
  end if;

  if found_user.is_active then
    raw_token := encode(gen_random_bytes(32), 'hex');
    insert into public.app_sessions(user_id, token_hash, expires_at)
    values (
      found_user.user_id,
      encode(digest(raw_token, 'sha256'), 'hex'),
      now() + interval '12 hours'
    );
  end if;

  return query select
    found_user.user_id, found_user.username::text, found_user.role::text,
    found_user.campus_id, found_user.college_id, found_user.is_active, raw_token;
end;
$$;

drop function if exists public.super_admin_list_users(integer);
drop function if exists public.super_admin_create_user(integer, text, text, text, integer, integer);
drop function if exists public.super_admin_set_user_active(integer, integer, boolean);

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
  p_session_token text, p_username text, p_password text, p_role text,
  p_campus_id integer default null, p_college_id integer default null
)
returns integer language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype; new_user_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_password is null or length(p_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;
  if p_role not in ('university_admin', 'campus_admin', 'college_admin') then raise exception 'Invalid admin role'; end if;
  if p_role = 'university_admin' and (p_campus_id is not null or p_college_id is not null) then raise exception 'University Admin must be university-wide'; end if;
  if p_role = 'campus_admin' and (p_campus_id is null or p_college_id is not null) then raise exception 'Campus Admin requires one campus'; end if;
  if p_role = 'college_admin' and (p_campus_id is null or p_college_id is null) then raise exception 'College Admin requires one campus and college'; end if;
  if p_campus_id is not null and not exists(select 1 from public.campus c where c.campus_id = p_campus_id) then raise exception 'Campus not found'; end if;
  if p_college_id is not null and not exists(select 1 from public.college c where c.college_id = p_college_id and c.campus_id = p_campus_id) then raise exception 'College does not belong to selected campus'; end if;

  insert into public.users(username, password_hash, role, campus_id, college_id, is_active, created_by)
  values(trim(p_username), crypt(p_password, gen_salt('bf')), p_role::public.user_role,
    p_campus_id, p_college_id, true, actor.user_id)
  returning users.user_id into new_user_id;
  return new_user_id;
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
  where users.user_id = p_target_user_id
    and users.role in ('university_admin', 'campus_admin', 'college_admin');
  if not found then raise exception 'Managed admin account not found'; end if;
  if not p_is_active then
    update public.app_sessions set revoked_at = now()
    where user_id = p_target_user_id and revoked_at is null;
  end if;
end;
$$;

drop function if exists public.college_admin_list_inspection_users(integer);
drop function if exists public.college_admin_create_inspection_user(integer, text, text);
drop function if exists public.college_admin_set_inspection_user_active(integer, integer, boolean);

create or replace function public.college_admin_list_inspection_users(p_session_token text)
returns table(user_id integer, username text, is_active boolean, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  return query select u.user_id, u.username::text, u.is_active, u.created_at
  from public.users u
  where u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
  order by u.username;
end;
$$;

create or replace function public.college_admin_create_inspection_user(
  p_session_token text, p_username text, p_password text
)
returns integer language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype; new_user_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if actor.campus_id is null or actor.college_id is null then raise exception 'College Admin scope is incomplete'; end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_password is null or length(p_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;
  insert into public.users(username, password_hash, role, campus_id, college_id, is_active, created_by)
  values(trim(p_username), crypt(p_password, gen_salt('bf')), 'inspection_team'::public.user_role,
    actor.campus_id, actor.college_id, true, actor.user_id)
  returning users.user_id into new_user_id;
  return new_user_id;
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
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;
  if not p_is_active then
    update public.app_sessions set revoked_at = now()
    where user_id = p_target_user_id and revoked_at is null;
  end if;
end;
$$;

create or replace function public.college_admin_create_qr_tags(
  p_session_token text, p_codes text[]
)
returns table(qr_tag_id integer, qr_code_string text, status text, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if coalesce(array_length(p_codes, 1), 0) not between 1 and 500 then raise exception 'Amount must be between 1 and 500'; end if;
  return query
    insert into public.qr_tag(qr_code_string, status)
    select trim(code), 'available' from unnest(p_codes) code
    returning qr_tag.qr_tag_id, qr_tag.qr_code_string::text, qr_tag.status::text, qr_tag.created_at;
end;
$$;

-- Remove any earlier registration overload so no unauthenticated version remains.
do $$
declare old_function record;
begin
  for old_function in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'register_plant_with_qr'
  loop
    execute format('drop function %s', old_function.signature);
  end loop;
end;
$$;

create function public.register_plant_with_qr(
  p_session_token text,
  p_classification_id integer, p_campus_id integer, p_college_id integer,
  p_town_id integer, p_barangay_id integer, p_growth_status_id integer,
  p_health_status_id integer, p_registered_by integer,
  p_variety text default null, p_date_planted date default null,
  p_tree_planter text default null, p_photo_url text default null,
  p_existing_qr_tag_id integer default null, p_new_qr_code text default null
)
returns table(plant_id integer, qr_tag_id integer, qr_code_string text)
language plpgsql security definer set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  selected_qr public.qr_tag%rowtype;
  new_plant_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if actor.campus_id is distinct from p_campus_id or actor.college_id is distinct from p_college_id then
    raise exception 'Plant registration is outside your assigned college';
  end if;
  if p_registered_by is distinct from actor.user_id then raise exception 'Invalid registering user'; end if;
  if not exists(select 1 from public.college c where c.college_id = p_college_id and c.campus_id = p_campus_id) then raise exception 'College does not belong to campus'; end if;
  if not exists(select 1 from public.barangay b where b.barangay_id = p_barangay_id and b.town_id = p_town_id) then raise exception 'Barangay does not belong to town'; end if;

  if p_existing_qr_tag_id is not null then
    select * into selected_qr from public.qr_tag q
    where q.qr_tag_id = p_existing_qr_tag_id and lower(q.status::text) = 'available'
    for update;
    if not found then raise exception 'Selected QR tag is not available'; end if;
  else
    if p_new_qr_code is null or trim(p_new_qr_code) = '' then raise exception 'A new QR code is required'; end if;
    insert into public.qr_tag(qr_code_string, status)
    values(trim(p_new_qr_code), 'available') returning * into selected_qr;
  end if;

  insert into public.plant(
    classification_id, campus_id, college_id, town_id, barangay_id, qr_tag_id,
    variety, date_planted, tree_planter, photo_url, registered_by,
    growth_status_id, health_status_id
  ) values (
    p_classification_id, p_campus_id, p_college_id, p_town_id, p_barangay_id,
    selected_qr.qr_tag_id, nullif(trim(p_variety), ''), p_date_planted,
    nullif(trim(p_tree_planter), ''), nullif(trim(p_photo_url), ''), actor.user_id,
    p_growth_status_id, p_health_status_id
  ) returning plant.plant_id into new_plant_id;

  update public.qr_tag set status = 'assigned' where qr_tag.qr_tag_id = selected_qr.qr_tag_id;
  return query select new_plant_id, selected_qr.qr_tag_id, selected_qr.qr_code_string::text;
end;
$$;

create or replace function public.inspection_team_submit_inspection(
  p_session_token text, p_plant_id integer, p_health_status_id integer,
  p_growth_status_id integer, p_observation text default null, p_photo_url text default null
)
returns void language plpgsql security definer set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'inspection_team' then raise exception 'Inspection Team access required'; end if;
  if not exists(select 1 from public.plant p where p.plant_id = p_plant_id and p.campus_id = actor.campus_id and p.college_id = actor.college_id) then
    raise exception 'Plant is outside your assigned college';
  end if;
  insert into public.inspection(
    plant_id, inspected_by, health_status_id, growth_status_id,
    observation, photo_url, last_inspection_date, inspected_at
  ) values (
    p_plant_id, actor.user_id, p_health_status_id, p_growth_status_id,
    nullif(trim(p_observation), ''), nullif(trim(p_photo_url), ''), current_date, now()
  );
  update public.plant set health_status_id = p_health_status_id,
    growth_status_id = p_growth_status_id,
    photo_url = coalesce(nullif(trim(p_photo_url), ''), photo_url)
  where plant_id = p_plant_id;
end;
$$;

drop policy if exists "plant inspections insertable" on public.inspection;

revoke all on function public.login_user(text, text) from public;
revoke all on function public.super_admin_list_users(text) from public;
revoke all on function public.super_admin_create_user(text, text, text, text, integer, integer) from public;
revoke all on function public.super_admin_set_user_active(text, integer, boolean) from public;
revoke all on function public.college_admin_list_inspection_users(text) from public;
revoke all on function public.college_admin_create_inspection_user(text, text, text) from public;
revoke all on function public.college_admin_set_inspection_user_active(text, integer, boolean) from public;
revoke all on function public.college_admin_create_qr_tags(text, text[]) from public;
revoke all on function public.register_plant_with_qr(text, integer, integer, integer, integer, integer, integer, integer, integer, text, date, text, text, integer, text) from public;
revoke all on function public.inspection_team_submit_inspection(text, integer, integer, integer, text, text) from public;

grant execute on function public.login_user(text, text) to anon, authenticated;
grant execute on function public.super_admin_list_users(text) to anon, authenticated;
grant execute on function public.super_admin_create_user(text, text, text, text, integer, integer) to anon, authenticated;
grant execute on function public.super_admin_set_user_active(text, integer, boolean) to anon, authenticated;
grant execute on function public.college_admin_list_inspection_users(text) to anon, authenticated;
grant execute on function public.college_admin_create_inspection_user(text, text, text) to anon, authenticated;
grant execute on function public.college_admin_set_inspection_user_active(text, integer, boolean) to anon, authenticated;
grant execute on function public.college_admin_create_qr_tags(text, text[]) to anon, authenticated;
grant execute on function public.register_plant_with_qr(text, integer, integer, integer, integer, integer, integer, integer, integer, text, date, text, text, integer, text) to anon, authenticated;
grant execute on function public.inspection_team_submit_inspection(text, integer, integer, integer, text, text) to anon, authenticated;

notify pgrst, 'reload schema';
