-- EcoTag production-readiness foundation.
--
-- This migration is intentionally additive. It preserves the RPC signatures
-- used by the current Flutter application and does not revoke legacy direct
-- table reads yet. A later enforcement migration can close those reads after
-- every screen has moved to the scoped RPCs introduced here.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Account security, archive metadata, and session maintenance
-- ---------------------------------------------------------------------------

alter table public.users
  add column if not exists failed_login_count integer not null default 0,
  add column if not exists last_failed_login_at timestamptz,
  add column if not exists locked_until timestamptz,
  add column if not exists last_login_at timestamptz,
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by integer,
  add column if not exists archive_reason text,
  add column if not exists restored_at timestamptz,
  add column if not exists restored_by integer;

-- Keep the legacy deleted_at column and the new archive terminology aligned
-- for rows archived by the previous migration.
update public.users
set archived_at = deleted_at
where archived_at is null and deleted_at is not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'users_failed_login_count_nonnegative'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_failed_login_count_nonnegative
      check (failed_login_count >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'users_archived_by_fkey'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_archived_by_fkey
      foreign key (archived_by) references public.users(user_id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'users_restored_by_fkey'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_restored_by_fkey
      foreign key (restored_by) references public.users(user_id)
      on delete set null;
  end if;
end;
$$;

create index if not exists users_locked_until_idx
  on public.users (locked_until)
  where locked_until is not null;
create index if not exists users_archived_at_idx
  on public.users (archived_at)
  where archived_at is not null;
create index if not exists app_sessions_expires_at_idx
  on public.app_sessions (expires_at);

-- ---------------------------------------------------------------------------
-- Immutable activity history
-- ---------------------------------------------------------------------------

create table if not exists public.audit_event (
  event_id bigserial primary key,
  actor_user_id integer references public.users(user_id) on delete set null,
  actor_username text,
  actor_role text,
  action text not null,
  entity_type text not null,
  entity_id text,
  campus_id integer,
  college_id integer,
  old_values jsonb,
  new_values jsonb,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_event_created_at_idx
  on public.audit_event (created_at desc);
create index if not exists audit_event_actor_idx
  on public.audit_event (actor_user_id, created_at desc);
create index if not exists audit_event_scope_idx
  on public.audit_event (campus_id, college_id, created_at desc);
create index if not exists audit_event_entity_idx
  on public.audit_event (entity_type, entity_id, created_at desc);
create index if not exists audit_event_action_idx
  on public.audit_event (action, created_at desc);

alter table public.audit_event enable row level security;
revoke all on table public.audit_event from anon, authenticated;
revoke all on sequence public.audit_event_event_id_seq from anon, authenticated;

create or replace function public.prevent_immutable_event_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'Activity history is immutable';
end;
$$;

drop trigger if exists audit_event_immutable_trigger on public.audit_event;
create trigger audit_event_immutable_trigger
before update or delete on public.audit_event
for each row execute function public.prevent_immutable_event_change();

create or replace function public.write_audit_event(
  p_actor_user_id integer,
  p_action text,
  p_entity_type text,
  p_entity_id text default null,
  p_campus_id integer default null,
  p_college_id integer default null,
  p_old_values jsonb default null,
  p_new_values jsonb default null,
  p_metadata jsonb default null
)
returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor_username_snapshot text;
  actor_role_snapshot text;
  new_event_id bigint;
begin
  if p_action is null or trim(p_action) = '' then
    raise exception 'An audit action is required';
  end if;
  if p_entity_type is null or trim(p_entity_type) = '' then
    raise exception 'An audit entity type is required';
  end if;

  if p_actor_user_id is not null then
    select u.username::text, u.role::text
      into actor_username_snapshot, actor_role_snapshot
    from public.users u
    where u.user_id = p_actor_user_id;
  end if;

  insert into public.audit_event (
    actor_user_id, actor_username, actor_role, action, entity_type,
    entity_id, campus_id, college_id, old_values, new_values, metadata
  ) values (
    p_actor_user_id, actor_username_snapshot, actor_role_snapshot,
    trim(p_action), trim(p_entity_type), nullif(trim(p_entity_id), ''),
    p_campus_id, p_college_id, p_old_values, p_new_values, p_metadata
  ) returning event_id into new_event_id;

  return new_event_id;
end;
$$;

revoke all on function public.prevent_immutable_event_change() from public;
revoke all on function public.write_audit_event(integer, text, text, text, integer, integer, jsonb, jsonb, jsonb) from public;

-- Require an active, unarchived account and an unexpired, unrevoked session.
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
    and u.is_active = true
    and u.deleted_at is null
    and u.archived_at is null;

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

-- Same arguments and result shape as the current application expects.
-- Existing accounts are locked for 15 minutes after five consecutive failures.
create or replace function public.login_user(p_username text, p_password text)
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
  password_ok boolean := false;
  raw_token text;
  next_failed_count integer;
  new_locked_until timestamptz;
begin
  select * into found_user
  from public.users u
  where lower(u.username) = lower(trim(p_username))
    and u.deleted_at is null
    and u.archived_at is null
  for update;

  -- Deliberately return the same empty result for an unknown account, a locked
  -- account, and an incorrect password to avoid account enumeration.
  if not found then
    return;
  end if;

  if found_user.locked_until is not null and found_user.locked_until > now() then
    perform public.write_audit_event(
      found_user.user_id, 'auth.login_blocked', 'user', found_user.user_id::text,
      found_user.campus_id, found_user.college_id, null, null,
      jsonb_build_object('locked_until', found_user.locked_until)
    );
    return;
  end if;

  -- An expired lock starts a fresh attempt window.
  if found_user.locked_until is not null and found_user.locked_until <= now() then
    update public.users
    set failed_login_count = 0, locked_until = null
    where users.user_id = found_user.user_id;
    found_user.failed_login_count := 0;
    found_user.locked_until := null;
  end if;

  if found_user.password_hash like '$2%' then
    password_ok := found_user.password_hash = crypt(p_password, found_user.password_hash);
  else
    password_ok := found_user.password_hash = p_password;
  end if;

  if not password_ok then
    next_failed_count := coalesce(found_user.failed_login_count, 0) + 1;
    new_locked_until := case
      when next_failed_count >= 5 then now() + interval '15 minutes'
      else null
    end;

    update public.users
    set failed_login_count = next_failed_count,
        last_failed_login_at = now(),
        locked_until = new_locked_until
    where users.user_id = found_user.user_id;

    perform public.write_audit_event(
      found_user.user_id,
      case when new_locked_until is null then 'auth.login_failed' else 'auth.account_locked' end,
      'user', found_user.user_id::text, found_user.campus_id, found_user.college_id,
      null, null,
      jsonb_build_object(
        'failed_login_count', next_failed_count,
        'locked_until', new_locked_until
      )
    );
    return;
  end if;

  -- Transparently upgrade legacy plaintext passwords on successful login.
  if found_user.password_hash = p_password then
    update public.users
    set password_hash = crypt(p_password, gen_salt('bf'))
    where users.user_id = found_user.user_id;
  end if;

  update public.users
  set failed_login_count = 0,
      last_failed_login_at = null,
      locked_until = null,
      last_login_at = case when found_user.is_active then now() else last_login_at end
  where users.user_id = found_user.user_id;

  if found_user.is_active then
    raw_token := encode(gen_random_bytes(32), 'hex');
    insert into public.app_sessions(user_id, token_hash, expires_at)
    values (
      found_user.user_id,
      encode(digest(raw_token, 'sha256'), 'hex'),
      now() + interval '12 hours'
    );

    perform public.write_audit_event(
      found_user.user_id, 'auth.login_succeeded', 'user', found_user.user_id::text,
      found_user.campus_id, found_user.college_id, null, null,
      jsonb_build_object('session_duration_hours', 12)
    );
  end if;

  return query select
    found_user.user_id, found_user.username::text, found_user.role::text,
    found_user.campus_id, found_user.college_id, found_user.is_active, raw_token;
end;
$$;

create or replace function public.logout_user(p_session_token text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  logout_actor public.users%rowtype;
  did_revoke boolean := false;
begin
  if p_session_token is null or length(p_session_token) < 32 then
    return false;
  end if;

  select u.* into logout_actor
  from public.app_sessions s
  join public.users u on u.user_id = s.user_id
  where s.token_hash = encode(digest(p_session_token, 'sha256'), 'hex')
    and s.revoked_at is null
  for update of s;

  if not found then
    return false;
  end if;

  update public.app_sessions
  set revoked_at = now(), last_seen_at = now()
  where token_hash = encode(digest(p_session_token, 'sha256'), 'hex')
    and revoked_at is null;
  did_revoke := found;

  if did_revoke then
    perform public.write_audit_event(
      logout_actor.user_id, 'auth.logout', 'user', logout_actor.user_id::text,
      logout_actor.campus_id, logout_actor.college_id
    );
  end if;

  return did_revoke;
end;
$$;

create or replace function public.app_session_status(p_session_token text)
returns table(
  user_id integer, username text, role text, campus_id integer,
  college_id integer, is_active boolean, expires_at timestamptz,
  last_seen_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);

  return query
  select actor.user_id, actor.username::text, actor.role::text,
    actor.campus_id, actor.college_id, actor.is_active,
    s.expires_at, s.last_seen_at
  from public.app_sessions s
  where s.token_hash = encode(digest(p_session_token, 'sha256'), 'hex')
    and s.revoked_at is null;
end;
$$;

create or replace function public.list_activity_log(
  p_session_token text,
  p_action text default null,
  p_entity_type text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table(
  event_id bigint,
  actor_username text,
  actor_role text,
  action text,
  entity_type text,
  entity_id text,
  campus_id integer,
  college_id integer,
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  safe_limit integer;
  safe_offset integer;
begin
  actor := public.require_app_session(p_session_token);
  safe_limit := least(greatest(coalesce(p_limit, 100), 1), 500);
  safe_offset := greatest(coalesce(p_offset, 0), 0);

  return query
  select e.event_id, e.actor_username, e.actor_role, e.action,
    e.entity_type, e.entity_id, e.campus_id, e.college_id,
    e.old_values, e.new_values, e.created_at
  from public.audit_event e
  where (
      p_action is null or trim(p_action) = '' or e.action = p_action
      or (lower(trim(p_action)) = 'create'
          and (e.action like '%.created' or e.action = 'plant.registered'))
      or (lower(trim(p_action)) = 'update'
          and (e.action like '%.updated'
               or e.action in ('account.activated', 'account.deactivated',
                               'plant.inspection_schedule_updated',
                               'qr.status_changed')))
      or (lower(trim(p_action)) = 'archive' and e.action like '%.archived')
      or (lower(trim(p_action)) = 'restore' and e.action like '%.restored')
      or (lower(trim(p_action)) = 'inspect' and e.action like 'inspection.%')
      or (lower(trim(p_action)) = 'replace' and e.action = 'qr.replaced')
      or (lower(trim(p_action)) = 'login' and e.action like 'auth.login%')
      or (lower(trim(p_action)) = 'logout' and e.action = 'auth.logout')
    )
    and (
      p_entity_type is null or trim(p_entity_type) = ''
      or e.entity_type = p_entity_type
    )
    and (
      actor.role in ('super_admin', 'university_admin')
      or (actor.role = 'campus_admin' and e.campus_id = actor.campus_id)
      or (actor.role = 'college_admin'
          and e.campus_id = actor.campus_id
          and e.college_id = actor.college_id)
      or e.actor_user_id = actor.user_id
    )
  order by e.created_at desc, e.event_id desc
  limit safe_limit offset safe_offset;
end;
$$;

revoke all on function public.login_user(text, text) from public;
revoke all on function public.logout_user(text) from public;
revoke all on function public.app_session_status(text) from public;
revoke all on function public.list_activity_log(text, text, text, integer, integer) from public;
grant execute on function public.login_user(text, text) to anon, authenticated;
grant execute on function public.logout_user(text) to anon, authenticated;
grant execute on function public.app_session_status(text) to anon, authenticated;
grant execute on function public.list_activity_log(text, text, text, integer, integer) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Audited, recoverable account administration
-- ---------------------------------------------------------------------------

create or replace function public.super_admin_list_users(p_session_token text)
returns table(
  user_id integer, username text, role text, campus_id integer,
  campus_name text, college_id integer, college_name text, is_active boolean
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then
    raise exception 'Super Admin access required';
  end if;

  return query
  select u.user_id, u.username::text, u.role::text, u.campus_id,
    c.campus_name::text, u.college_id, co.college_name::text, u.is_active
  from public.users u
  left join public.campus c on c.campus_id = u.campus_id
  left join public.college co on co.college_id = u.college_id
  where u.role in ('university_admin', 'campus_admin', 'college_admin')
    and u.deleted_at is null
    and u.archived_at is null
  order by u.username;
end;
$$;

create or replace function public.super_admin_create_user(
  p_session_token text,
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
  actor public.users%rowtype;
  new_user_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_password is null or length(p_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;
  if p_role not in ('university_admin', 'campus_admin', 'college_admin') then raise exception 'Invalid admin role'; end if;
  if p_role = 'university_admin' and (p_campus_id is not null or p_college_id is not null) then raise exception 'University Admin must be university-wide'; end if;
  if p_role = 'campus_admin' and (p_campus_id is null or p_college_id is not null) then raise exception 'Campus Admin requires one campus'; end if;
  if p_role = 'college_admin' and (p_campus_id is null or p_college_id is null) then raise exception 'College Admin requires one campus and college'; end if;
  if p_campus_id is not null and not exists (
    select 1 from public.campus c where c.campus_id = p_campus_id
  ) then raise exception 'Campus not found'; end if;
  if p_college_id is not null and not exists (
    select 1 from public.college c
    where c.college_id = p_college_id and c.campus_id = p_campus_id
  ) then raise exception 'College does not belong to selected campus'; end if;

  insert into public.users (
    username, password_hash, role, campus_id, college_id, is_active, created_by
  ) values (
    trim(p_username), crypt(p_password, gen_salt('bf')),
    p_role::public.user_role, p_campus_id, p_college_id, true, actor.user_id
  ) returning users.user_id into new_user_id;

  perform public.write_audit_event(
    actor.user_id, 'account.created', 'user', new_user_id::text,
    p_campus_id, p_college_id, null,
    jsonb_build_object(
      'username', trim(p_username), 'role', p_role, 'is_active', true,
      'campus_id', p_campus_id, 'college_id', p_college_id
    )
  );

  return new_user_id;
end;
$$;

create or replace function public.super_admin_update_user(
  p_session_token text,
  p_target_user_id integer,
  p_username text,
  p_role text,
  p_campus_id integer default null,
  p_college_id integer default null,
  p_new_password text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id
    and u.role in ('university_admin', 'campus_admin', 'college_admin')
    and u.deleted_at is null and u.archived_at is null
  for update;
  if not found then raise exception 'Managed admin account not found'; end if;

  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_role not in ('university_admin', 'campus_admin', 'college_admin') then raise exception 'Invalid admin role'; end if;
  if p_new_password is not null and p_new_password <> '' and length(p_new_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;
  if p_role = 'university_admin' and (p_campus_id is not null or p_college_id is not null) then raise exception 'University Admin must be university-wide'; end if;
  if p_role = 'campus_admin' and (p_campus_id is null or p_college_id is not null) then raise exception 'Campus Admin requires one campus'; end if;
  if p_role = 'college_admin' and (p_campus_id is null or p_college_id is null) then raise exception 'College Admin requires one campus and college'; end if;
  if p_campus_id is not null and not exists (
    select 1 from public.campus c where c.campus_id = p_campus_id
  ) then raise exception 'Campus not found'; end if;
  if p_college_id is not null and not exists (
    select 1 from public.college c
    where c.college_id = p_college_id and c.campus_id = p_campus_id
  ) then raise exception 'College does not belong to selected campus'; end if;

  update public.users
  set username = trim(p_username),
      role = p_role::public.user_role,
      campus_id = p_campus_id,
      college_id = p_college_id,
      password_hash = case
        when p_new_password is null or p_new_password = '' then password_hash
        else crypt(p_new_password, gen_salt('bf'))
      end
  where users.user_id = p_target_user_id;

  update public.app_sessions
  set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;

  perform public.write_audit_event(
    actor.user_id, 'account.updated', 'user', p_target_user_id::text,
    p_campus_id, p_college_id,
    jsonb_build_object(
      'username', target_user.username, 'role', target_user.role::text,
      'campus_id', target_user.campus_id, 'college_id', target_user.college_id,
      'is_active', target_user.is_active
    ),
    jsonb_build_object(
      'username', trim(p_username), 'role', p_role,
      'campus_id', p_campus_id, 'college_id', p_college_id,
      'is_active', target_user.is_active
    ),
    jsonb_build_object('password_changed', coalesce(p_new_password, '') <> '')
  );
end;
$$;

create or replace function public.super_admin_set_user_active(
  p_session_token text,
  p_target_user_id integer,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id
    and u.role in ('university_admin', 'campus_admin', 'college_admin')
    and u.deleted_at is null and u.archived_at is null
  for update;
  if not found then raise exception 'Managed admin account not found'; end if;

  update public.users set is_active = p_is_active
  where users.user_id = p_target_user_id;

  if not p_is_active then
    update public.app_sessions set revoked_at = now()
    where user_id = p_target_user_id and revoked_at is null;
  end if;

  perform public.write_audit_event(
    actor.user_id,
    case when p_is_active then 'account.activated' else 'account.deactivated' end,
    'user', p_target_user_id::text, target_user.campus_id, target_user.college_id,
    jsonb_build_object('is_active', target_user.is_active),
    jsonb_build_object('is_active', p_is_active)
  );
end;
$$;

create or replace function public.super_admin_archive_user(
  p_session_token text,
  p_target_user_id integer,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id
    and u.role in ('university_admin', 'campus_admin', 'college_admin')
    and u.deleted_at is null and u.archived_at is null
  for update;
  if not found then raise exception 'Managed admin account not found'; end if;

  update public.users
  set is_active = false,
      deleted_at = now(),
      archived_at = now(),
      archived_by = actor.user_id,
      archive_reason = nullif(trim(p_reason), ''),
      restored_at = null,
      restored_by = null
  where users.user_id = p_target_user_id;

  update public.app_sessions set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;

  perform public.write_audit_event(
    actor.user_id, 'account.archived', 'user', p_target_user_id::text,
    target_user.campus_id, target_user.college_id,
    jsonb_build_object(
      'username', target_user.username, 'role', target_user.role::text,
      'is_active', target_user.is_active
    ),
    jsonb_build_object(
      'username', target_user.username, 'role', target_user.role::text,
      'is_active', false, 'archived', true
    ),
    jsonb_build_object('reason', nullif(trim(p_reason), ''))
  );
end;
$$;

-- Legacy wrapper: existing app calls still perform a recoverable archive.
create or replace function public.super_admin_delete_user(
  p_session_token text,
  p_target_user_id integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform public.super_admin_archive_user(
    p_session_token, p_target_user_id, 'Archived from account management'
  );
end;
$$;

create or replace function public.super_admin_restore_user(
  p_session_token text,
  p_target_user_id integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id
    and u.role in ('university_admin', 'campus_admin', 'college_admin')
    and (u.deleted_at is not null or u.archived_at is not null)
  for update;
  if not found then raise exception 'Archived admin account not found'; end if;

  -- Restores are inactive by design so active-admin uniqueness rules are not
  -- unexpectedly displaced. Activation remains a separate explicit action.
  update public.users
  set is_active = false,
      deleted_at = null,
      archived_at = null,
      restored_at = now(),
      restored_by = actor.user_id,
      failed_login_count = 0,
      last_failed_login_at = null,
      locked_until = null
  where users.user_id = p_target_user_id;

  perform public.write_audit_event(
    actor.user_id, 'account.restored', 'user', p_target_user_id::text,
    target_user.campus_id, target_user.college_id,
    jsonb_build_object('archived', true, 'is_active', false),
    jsonb_build_object('archived', false, 'is_active', false)
  );
end;
$$;

create or replace function public.super_admin_list_archived_users(
  p_session_token text
)
returns table(
  user_id integer, username text, role text, campus_id integer,
  campus_name text, college_id integer, college_name text,
  archived_at timestamptz, archive_reason text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'super_admin' then raise exception 'Super Admin access required'; end if;

  return query
  select u.user_id, u.username::text, u.role::text, u.campus_id,
    c.campus_name::text, u.college_id, co.college_name::text,
    coalesce(u.archived_at, u.deleted_at), u.archive_reason
  from public.users u
  left join public.campus c on c.campus_id = u.campus_id
  left join public.college co on co.college_id = u.college_id
  where u.role in ('university_admin', 'campus_admin', 'college_admin')
    and (u.deleted_at is not null or u.archived_at is not null)
  order by coalesce(u.archived_at, u.deleted_at) desc, u.username;
end;
$$;

create or replace function public.college_admin_list_inspection_users(
  p_session_token text
)
returns table(user_id integer, username text, is_active boolean, created_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;

  return query
  select u.user_id, u.username::text, u.is_active, u.created_at
  from public.users u
  where u.role = 'inspection_team'
    and u.campus_id = actor.campus_id
    and u.college_id = actor.college_id
    and u.deleted_at is null and u.archived_at is null
  order by u.username;
end;
$$;

create or replace function public.college_admin_create_inspection_user(
  p_session_token text,
  p_username text,
  p_password text
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  new_user_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if actor.campus_id is null or actor.college_id is null then raise exception 'College Admin scope is incomplete'; end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_password is null or length(p_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;

  insert into public.users (
    username, password_hash, role, campus_id, college_id, is_active, created_by
  ) values (
    trim(p_username), crypt(p_password, gen_salt('bf')),
    'inspection_team'::public.user_role,
    actor.campus_id, actor.college_id, true, actor.user_id
  ) returning users.user_id into new_user_id;

  perform public.write_audit_event(
    actor.user_id, 'account.created', 'user', new_user_id::text,
    actor.campus_id, actor.college_id, null,
    jsonb_build_object(
      'username', trim(p_username), 'role', 'inspection_team',
      'is_active', true, 'campus_id', actor.campus_id,
      'college_id', actor.college_id
    )
  );

  return new_user_id;
end;
$$;

create or replace function public.college_admin_update_inspection_user(
  p_session_token text,
  p_target_user_id integer,
  p_username text,
  p_new_password text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then raise exception 'Invalid username'; end if;
  if p_new_password is not null and p_new_password <> '' and length(p_new_password) < 8 then raise exception 'Password must contain at least 8 characters'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id
    and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id
    and u.college_id = actor.college_id
    and u.deleted_at is null and u.archived_at is null
  for update;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;

  update public.users u
  set username = trim(p_username),
      password_hash = case
        when p_new_password is null or p_new_password = '' then password_hash
        else crypt(p_new_password, gen_salt('bf'))
      end
  where u.user_id = p_target_user_id;

  update public.app_sessions set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;

  perform public.write_audit_event(
    actor.user_id, 'account.updated', 'user', p_target_user_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object('username', target_user.username, 'role', 'inspection_team'),
    jsonb_build_object('username', trim(p_username), 'role', 'inspection_team'),
    jsonb_build_object('password_changed', coalesce(p_new_password, '') <> '')
  );
end;
$$;

create or replace function public.college_admin_set_inspection_user_active(
  p_session_token text,
  p_target_user_id integer,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
    and u.deleted_at is null and u.archived_at is null
  for update;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;

  update public.users u set is_active = p_is_active
  where u.user_id = p_target_user_id;

  if not p_is_active then
    update public.app_sessions set revoked_at = now()
    where user_id = p_target_user_id and revoked_at is null;
  end if;

  perform public.write_audit_event(
    actor.user_id,
    case when p_is_active then 'account.activated' else 'account.deactivated' end,
    'user', p_target_user_id::text, actor.campus_id, actor.college_id,
    jsonb_build_object('is_active', target_user.is_active),
    jsonb_build_object('is_active', p_is_active)
  );
end;
$$;

create or replace function public.college_admin_archive_inspection_user(
  p_session_token text,
  p_target_user_id integer,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
    and u.deleted_at is null and u.archived_at is null
  for update;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;

  update public.users u
  set is_active = false,
      deleted_at = now(),
      archived_at = now(),
      archived_by = actor.user_id,
      archive_reason = nullif(trim(p_reason), ''),
      restored_at = null,
      restored_by = null
  where u.user_id = p_target_user_id;

  update public.app_sessions set revoked_at = now()
  where user_id = p_target_user_id and revoked_at is null;

  perform public.write_audit_event(
    actor.user_id, 'account.archived', 'user', p_target_user_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object(
      'username', target_user.username, 'role', 'inspection_team',
      'is_active', target_user.is_active
    ),
    jsonb_build_object(
      'username', target_user.username, 'role', 'inspection_team',
      'is_active', false, 'archived', true
    ),
    jsonb_build_object('reason', nullif(trim(p_reason), ''))
  );
end;
$$;

create or replace function public.college_admin_delete_inspection_user(
  p_session_token text,
  p_target_user_id integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform public.college_admin_archive_inspection_user(
    p_session_token, p_target_user_id, 'Archived from account management'
  );
end;
$$;

create or replace function public.college_admin_restore_inspection_user(
  p_session_token text,
  p_target_user_id integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_user public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;

  select * into target_user from public.users u
  where u.user_id = p_target_user_id and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id and u.college_id = actor.college_id
    and (u.deleted_at is not null or u.archived_at is not null)
  for update;
  if not found then raise exception 'Archived Inspection Team account not found in your college'; end if;

  update public.users u
  set is_active = false,
      deleted_at = null,
      archived_at = null,
      restored_at = now(),
      restored_by = actor.user_id,
      failed_login_count = 0,
      last_failed_login_at = null,
      locked_until = null
  where u.user_id = p_target_user_id;

  perform public.write_audit_event(
    actor.user_id, 'account.restored', 'user', p_target_user_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object('archived', true, 'is_active', false),
    jsonb_build_object('archived', false, 'is_active', false)
  );
end;
$$;

create or replace function public.college_admin_list_archived_inspection_users(
  p_session_token text
)
returns table(
  user_id integer, username text, created_at timestamptz,
  archived_at timestamptz, archive_reason text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;

  return query
  select u.user_id, u.username::text, u.created_at,
    coalesce(u.archived_at, u.deleted_at), u.archive_reason
  from public.users u
  where u.role = 'inspection_team'
    and u.campus_id = actor.campus_id
    and u.college_id = actor.college_id
    and (u.deleted_at is not null or u.archived_at is not null)
  order by coalesce(u.archived_at, u.deleted_at) desc, u.username;
end;
$$;

revoke all on function public.super_admin_list_users(text) from public;
revoke all on function public.super_admin_create_user(text, text, text, text, integer, integer) from public;
revoke all on function public.super_admin_update_user(text, integer, text, text, integer, integer, text) from public;
revoke all on function public.super_admin_set_user_active(text, integer, boolean) from public;
revoke all on function public.super_admin_archive_user(text, integer, text) from public;
revoke all on function public.super_admin_delete_user(text, integer) from public;
revoke all on function public.super_admin_restore_user(text, integer) from public;
revoke all on function public.super_admin_list_archived_users(text) from public;
revoke all on function public.college_admin_list_inspection_users(text) from public;
revoke all on function public.college_admin_create_inspection_user(text, text, text) from public;
revoke all on function public.college_admin_update_inspection_user(text, integer, text, text) from public;
revoke all on function public.college_admin_set_inspection_user_active(text, integer, boolean) from public;
revoke all on function public.college_admin_archive_inspection_user(text, integer, text) from public;
revoke all on function public.college_admin_delete_inspection_user(text, integer) from public;
revoke all on function public.college_admin_restore_inspection_user(text, integer) from public;
revoke all on function public.college_admin_list_archived_inspection_users(text) from public;

grant execute on function public.super_admin_list_users(text) to anon, authenticated;
grant execute on function public.super_admin_create_user(text, text, text, text, integer, integer) to anon, authenticated;
grant execute on function public.super_admin_update_user(text, integer, text, text, integer, integer, text) to anon, authenticated;
grant execute on function public.super_admin_set_user_active(text, integer, boolean) to anon, authenticated;
grant execute on function public.super_admin_archive_user(text, integer, text) to anon, authenticated;
grant execute on function public.super_admin_delete_user(text, integer) to anon, authenticated;
grant execute on function public.super_admin_restore_user(text, integer) to anon, authenticated;
grant execute on function public.super_admin_list_archived_users(text) to anon, authenticated;
grant execute on function public.college_admin_list_inspection_users(text) to anon, authenticated;
grant execute on function public.college_admin_create_inspection_user(text, text, text) to anon, authenticated;
grant execute on function public.college_admin_update_inspection_user(text, integer, text, text) to anon, authenticated;
grant execute on function public.college_admin_set_inspection_user_active(text, integer, boolean) to anon, authenticated;
grant execute on function public.college_admin_archive_inspection_user(text, integer, text) to anon, authenticated;
grant execute on function public.college_admin_delete_inspection_user(text, integer) to anon, authenticated;
grant execute on function public.college_admin_restore_inspection_user(text, integer) to anon, authenticated;
grant execute on function public.college_admin_list_archived_inspection_users(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Recoverable plants, inspection schedules, and duplicate candidates
-- ---------------------------------------------------------------------------

alter table public.plant
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by integer,
  add column if not exists archive_reason text,
  add column if not exists inspection_interval_days integer not null default 90,
  add column if not exists last_inspected_on date,
  add column if not exists next_inspection_due_on date;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'plant_archived_by_fkey'
      and conrelid = 'public.plant'::regclass
  ) then
    alter table public.plant
      add constraint plant_archived_by_fkey
      foreign key (archived_by) references public.users(user_id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'plant_inspection_interval_days_range'
      and conrelid = 'public.plant'::regclass
  ) then
    alter table public.plant
      add constraint plant_inspection_interval_days_range
      check (inspection_interval_days between 1 and 3650);
  end if;
end;
$$;

-- Backfill the latest completed inspection and a deterministic next due date.
update public.plant p
set last_inspected_on = latest.last_inspected_on
from (
  select i.plant_id,
    max(coalesce(i.inspected_at::date, i.last_inspection_date)) as last_inspected_on
  from public.inspection i
  group by i.plant_id
) latest
where latest.plant_id = p.plant_id
  and (p.last_inspected_on is null or p.last_inspected_on < latest.last_inspected_on);

update public.plant p
set next_inspection_due_on =
  coalesce(p.last_inspected_on, p.date_planted, p.created_at::date, current_date)
  + p.inspection_interval_days
where p.next_inspection_due_on is null;

create index if not exists plant_active_college_due_idx
  on public.plant (college_id, next_inspection_due_on, plant_id)
  where archived_at is null;
create index if not exists plant_active_campus_due_idx
  on public.plant (campus_id, next_inspection_due_on, plant_id)
  where archived_at is null;
create index if not exists plant_archived_at_idx
  on public.plant (archived_at desc)
  where archived_at is not null;
create index if not exists plant_duplicate_candidate_idx
  on public.plant (
    college_id, classification_id, barangay_id, date_planted,
    lower(coalesce(variety, ''))
  )
  where archived_at is null;

create or replace function public.archive_plant(
  p_session_token text,
  p_plant_id integer,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_plant public.plant%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in ('super_admin', 'university_admin', 'campus_admin', 'college_admin') then
    raise exception 'Administrator access required';
  end if;

  select * into target_plant from public.plant p
  where p.plant_id = p_plant_id and p.archived_at is null
  for update;
  if not found then raise exception 'Active plant record not found'; end if;

  if actor.role = 'campus_admin' and target_plant.campus_id is distinct from actor.campus_id then
    raise exception 'Plant is outside your assigned campus';
  end if;
  if actor.role = 'college_admin' and (
    target_plant.campus_id is distinct from actor.campus_id
    or target_plant.college_id is distinct from actor.college_id
  ) then
    raise exception 'Plant is outside your assigned college';
  end if;

  update public.plant p
  set archived_at = now(),
      archived_by = actor.user_id,
      archive_reason = nullif(trim(p_reason), '')
  where p.plant_id = p_plant_id;

  perform public.write_audit_event(
    actor.user_id, 'plant.archived', 'plant', p_plant_id::text,
    target_plant.campus_id, target_plant.college_id,
    jsonb_build_object('archived', false),
    jsonb_build_object('archived', true),
    jsonb_build_object('reason', nullif(trim(p_reason), ''))
  );
end;
$$;

create or replace function public.restore_plant(
  p_session_token text,
  p_plant_id integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_plant public.plant%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in ('super_admin', 'university_admin', 'campus_admin', 'college_admin') then
    raise exception 'Administrator access required';
  end if;

  select * into target_plant from public.plant p
  where p.plant_id = p_plant_id and p.archived_at is not null
  for update;
  if not found then raise exception 'Archived plant record not found'; end if;

  if actor.role = 'campus_admin' and target_plant.campus_id is distinct from actor.campus_id then
    raise exception 'Plant is outside your assigned campus';
  end if;
  if actor.role = 'college_admin' and (
    target_plant.campus_id is distinct from actor.campus_id
    or target_plant.college_id is distinct from actor.college_id
  ) then
    raise exception 'Plant is outside your assigned college';
  end if;

  update public.plant p
  set archived_at = null, archived_by = null, archive_reason = null
  where p.plant_id = p_plant_id;

  perform public.write_audit_event(
    actor.user_id, 'plant.restored', 'plant', p_plant_id::text,
    target_plant.campus_id, target_plant.college_id,
    jsonb_build_object('archived', true),
    jsonb_build_object('archived', false)
  );
end;
$$;

create or replace function public.update_plant_inspection_schedule(
  p_session_token text,
  p_plant_id integer,
  p_inspection_interval_days integer,
  p_next_inspection_due_on date default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_plant public.plant%rowtype;
  calculated_due_on date;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in ('super_admin', 'university_admin', 'campus_admin', 'college_admin') then
    raise exception 'Administrator access required';
  end if;
  if p_inspection_interval_days not between 1 and 3650 then
    raise exception 'Inspection interval must be between 1 and 3650 days';
  end if;

  select * into target_plant from public.plant p
  where p.plant_id = p_plant_id and p.archived_at is null
  for update;
  if not found then raise exception 'Active plant record not found'; end if;

  if actor.role = 'campus_admin' and target_plant.campus_id is distinct from actor.campus_id then
    raise exception 'Plant is outside your assigned campus';
  end if;
  if actor.role = 'college_admin' and (
    target_plant.campus_id is distinct from actor.campus_id
    or target_plant.college_id is distinct from actor.college_id
  ) then
    raise exception 'Plant is outside your assigned college';
  end if;

  calculated_due_on := coalesce(
    p_next_inspection_due_on,
    target_plant.last_inspected_on
      + p_inspection_interval_days,
    current_date + p_inspection_interval_days
  );

  update public.plant p
  set inspection_interval_days = p_inspection_interval_days,
      next_inspection_due_on = calculated_due_on
  where p.plant_id = p_plant_id;

  perform public.write_audit_event(
    actor.user_id, 'plant.inspection_schedule_updated', 'plant', p_plant_id::text,
    target_plant.campus_id, target_plant.college_id,
    jsonb_build_object(
      'inspection_interval_days', target_plant.inspection_interval_days,
      'next_inspection_due_on', target_plant.next_inspection_due_on
    ),
    jsonb_build_object(
      'inspection_interval_days', p_inspection_interval_days,
      'next_inspection_due_on', calculated_due_on
    )
  );
end;
$$;

-- Role-specific wrappers keep the mobile service contract explicit while the
-- underlying functions remain reusable by higher-level administrators.
create or replace function public.college_admin_archive_plant(
  p_session_token text,
  p_plant_id integer,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  perform public.archive_plant(p_session_token, p_plant_id, p_reason);
end;
$$;

create or replace function public.college_admin_restore_plant(
  p_session_token text,
  p_plant_id integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  perform public.restore_plant(p_session_token, p_plant_id);
end;
$$;

create or replace function public.college_admin_update_inspection_schedule(
  p_session_token text,
  p_plant_id integer,
  p_next_due_on date,
  p_interval_days integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare actor public.users%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  perform public.update_plant_inspection_schedule(
    p_session_token, p_plant_id, p_interval_days, p_next_due_on
  );
end;
$$;

create or replace function public.find_possible_duplicate_plants(
  p_session_token text,
  p_classification_id integer,
  p_campus_id integer,
  p_college_id integer,
  p_town_id integer,
  p_barangay_id integer,
  p_variety text,
  p_date_planted date,
  p_limit integer
)
returns table(
  plant_id integer,
  common_name text,
  variety text,
  date_planted date,
  tree_planter text,
  campus_name text,
  college_name text,
  town_name text,
  barangay_name text,
  qr_code_string text,
  match_score integer,
  match_reasons text[],
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  safe_limit integer;
begin
  actor := public.require_app_session(p_session_token);
  safe_limit := least(greatest(coalesce(p_limit, 10), 1), 50);

  if actor.role not in ('super_admin', 'university_admin', 'campus_admin', 'college_admin', 'inspection_team') then
    raise exception 'EcoTag account access required';
  end if;
  if actor.role = 'campus_admin' and p_campus_id is distinct from actor.campus_id then
    raise exception 'Location is outside your assigned campus';
  end if;
  if actor.role in ('college_admin', 'inspection_team') and (
    p_campus_id is distinct from actor.campus_id
    or p_college_id is distinct from actor.college_id
  ) then
    raise exception 'Location is outside your assigned college';
  end if;

  return query
  with candidates as (
    select p.plant_id,
      pc.common_name::text as common_name,
      p.variety::text as variety,
      p.date_planted,
      p.tree_planter::text as tree_planter,
      c.campus_name::text as campus_name,
      co.college_name::text as college_name,
      t.town_name::text as town_name,
      b.barangay_name::text as barangay_name,
      q.qr_code_string::text as qr_code_string,
      (
        case when p.classification_id = p_classification_id then 4 else 0 end
        + case when nullif(trim(p_variety), '') is not null
                    and lower(trim(coalesce(p.variety, ''))) = lower(trim(p_variety))
               then 3 else 0 end
        + case when p.barangay_id = p_barangay_id then 2 else 0 end
        + case when p.town_id = p_town_id then 1 else 0 end
        + case when p_date_planted is not null and p.date_planted = p_date_planted
               then 1 else 0 end
      )::integer as match_score,
      array_remove(array[
        case when p.classification_id = p_classification_id then 'same classification' end,
        case when nullif(trim(p_variety), '') is not null
                  and lower(trim(coalesce(p.variety, ''))) = lower(trim(p_variety))
             then 'same variety' end,
        case when p.barangay_id = p_barangay_id then 'same barangay' end,
        case when p.town_id = p_town_id then 'same town' end,
        case when p_date_planted is not null and p.date_planted = p_date_planted
             then 'same planting date' end
      ]::text[], null) as match_reasons,
      p.created_at
    from public.plant p
    join public.plant_classification pc on pc.classification_id = p.classification_id
    join public.campus c on c.campus_id = p.campus_id
    join public.college co on co.college_id = p.college_id
    join public.town t on t.town_id = p.town_id
    join public.barangay b on b.barangay_id = p.barangay_id
    left join public.qr_tag q on q.qr_tag_id = p.qr_tag_id
    where p.archived_at is null
      and p.campus_id = p_campus_id
      and p.college_id = p_college_id
      and p.classification_id = p_classification_id
      and (
        p.barangay_id = p_barangay_id
        or (nullif(trim(p_variety), '') is not null
            and lower(trim(coalesce(p.variety, ''))) = lower(trim(p_variety)))
        or (p_date_planted is not null and p.date_planted = p_date_planted)
      )
  )
  select c.plant_id, c.common_name, c.variety, c.date_planted,
    c.tree_planter, c.campus_name, c.college_name, c.town_name,
    c.barangay_name, c.qr_code_string, c.match_score,
    c.match_reasons, c.created_at
  from candidates c
  order by c.match_score desc, c.created_at desc
  limit safe_limit;
end;
$$;

revoke all on function public.archive_plant(text, integer, text) from public;
revoke all on function public.restore_plant(text, integer) from public;
revoke all on function public.update_plant_inspection_schedule(text, integer, integer, date) from public;
revoke all on function public.college_admin_archive_plant(text, integer, text) from public;
revoke all on function public.college_admin_restore_plant(text, integer) from public;
revoke all on function public.college_admin_update_inspection_schedule(text, integer, date, integer) from public;
revoke all on function public.find_possible_duplicate_plants(text, integer, integer, integer, integer, integer, text, date, integer) from public;
grant execute on function public.archive_plant(text, integer, text) to anon, authenticated;
grant execute on function public.restore_plant(text, integer) to anon, authenticated;
grant execute on function public.update_plant_inspection_schedule(text, integer, integer, date) to anon, authenticated;
grant execute on function public.college_admin_archive_plant(text, integer, text) to anon, authenticated;
grant execute on function public.college_admin_restore_plant(text, integer) to anon, authenticated;
grant execute on function public.college_admin_update_inspection_schedule(text, integer, date, integer) to anon, authenticated;
grant execute on function public.find_possible_duplicate_plants(text, integer, integer, integer, integer, integer, text, date, integer) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Canonical QR lifecycle and immutable QR history
-- ---------------------------------------------------------------------------

alter table public.qr_tag
  add column if not exists lifecycle_status text not null default 'available',
  add column if not exists campus_id integer,
  add column if not exists college_id integer,
  add column if not exists created_by integer,
  add column if not exists assigned_plant_id integer,
  add column if not exists last_status_changed_at timestamptz not null default now(),
  add column if not exists last_status_changed_by integer,
  add column if not exists status_reason text,
  add column if not exists damaged_at timestamptz,
  add column if not exists retired_at timestamptz,
  add column if not exists replacement_qr_tag_id integer,
  add column if not exists replaces_qr_tag_id integer;

-- Normalize the canonical text status from the legacy status column without
-- changing the legacy column's data type or enum definition.
update public.qr_tag q
set lifecycle_status = case lower(q.status::text)
  when 'available' then 'available'
  when 'assigned' then 'assigned'
  when 'damaged' then 'damaged'
  when 'lost' then 'retired'
  when 'retired' then 'retired'
  else 'available'
end
where q.last_status_changed_by is null;

-- Backfill ownership and current assignment from the plant relation. Available
-- legacy tags that have never been assigned remain unscoped and can later be
-- adopted by a College Admin during registration.
update public.qr_tag q
set campus_id = coalesce(q.campus_id, (
      select p.campus_id from public.plant p
      where p.qr_tag_id = q.qr_tag_id order by p.plant_id limit 1
    )),
    college_id = coalesce(q.college_id, (
      select p.college_id from public.plant p
      where p.qr_tag_id = q.qr_tag_id order by p.plant_id limit 1
    )),
    created_by = coalesce(q.created_by, (
      select p.registered_by from public.plant p
      where p.qr_tag_id = q.qr_tag_id order by p.plant_id limit 1
    )),
    assigned_plant_id = coalesce(q.assigned_plant_id, (
      select p.plant_id from public.plant p
      where p.qr_tag_id = q.qr_tag_id and p.archived_at is null
      order by p.plant_id limit 1
    )),
    lifecycle_status = case
      when exists (
        select 1 from public.plant p
        where p.qr_tag_id = q.qr_tag_id and p.archived_at is null
      ) and q.lifecycle_status = 'available' then 'assigned'
      else q.lifecycle_status
    end;

alter table public.qr_tag
  drop constraint if exists qr_tag_lifecycle_status_check;
alter table public.qr_tag
  add constraint qr_tag_lifecycle_status_check
  check (lifecycle_status in ('available', 'assigned', 'damaged', 'replaced', 'retired'));

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'qr_tag_campus_id_fkey'
      and conrelid = 'public.qr_tag'::regclass
  ) then
    alter table public.qr_tag
      add constraint qr_tag_campus_id_fkey
      foreign key (campus_id) references public.campus(campus_id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'qr_tag_college_id_fkey'
      and conrelid = 'public.qr_tag'::regclass
  ) then
    alter table public.qr_tag
      add constraint qr_tag_college_id_fkey
      foreign key (college_id) references public.college(college_id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'qr_tag_created_by_fkey'
      and conrelid = 'public.qr_tag'::regclass
  ) then
    alter table public.qr_tag
      add constraint qr_tag_created_by_fkey
      foreign key (created_by) references public.users(user_id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'qr_tag_assigned_plant_id_fkey'
      and conrelid = 'public.qr_tag'::regclass
  ) then
    alter table public.qr_tag
      add constraint qr_tag_assigned_plant_id_fkey
      foreign key (assigned_plant_id) references public.plant(plant_id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'qr_tag_last_status_changed_by_fkey'
      and conrelid = 'public.qr_tag'::regclass
  ) then
    alter table public.qr_tag
      add constraint qr_tag_last_status_changed_by_fkey
      foreign key (last_status_changed_by) references public.users(user_id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'qr_tag_replacement_qr_tag_id_fkey'
      and conrelid = 'public.qr_tag'::regclass
  ) then
    alter table public.qr_tag
      add constraint qr_tag_replacement_qr_tag_id_fkey
      foreign key (replacement_qr_tag_id) references public.qr_tag(qr_tag_id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'qr_tag_replaces_qr_tag_id_fkey'
      and conrelid = 'public.qr_tag'::regclass
  ) then
    alter table public.qr_tag
      add constraint qr_tag_replaces_qr_tag_id_fkey
      foreign key (replaces_qr_tag_id) references public.qr_tag(qr_tag_id)
      on delete set null;
  end if;
end;
$$;

create index if not exists qr_tag_scope_status_idx
  on public.qr_tag (campus_id, college_id, lifecycle_status, qr_tag_id desc);
create index if not exists qr_tag_assigned_plant_idx
  on public.qr_tag (assigned_plant_id)
  where assigned_plant_id is not null;
create index if not exists qr_tag_replacement_idx
  on public.qr_tag (replacement_qr_tag_id)
  where replacement_qr_tag_id is not null;

create table if not exists public.qr_tag_event (
  event_id bigserial primary key,
  qr_tag_id integer not null references public.qr_tag(qr_tag_id),
  actor_user_id integer references public.users(user_id) on delete set null,
  action text not null,
  from_status text,
  to_status text,
  plant_id integer references public.plant(plant_id) on delete set null,
  reason text,
  replacement_qr_tag_id integer references public.qr_tag(qr_tag_id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists qr_tag_event_tag_created_idx
  on public.qr_tag_event (qr_tag_id, created_at desc, event_id desc);
create index if not exists qr_tag_event_actor_created_idx
  on public.qr_tag_event (actor_user_id, created_at desc);

alter table public.qr_tag_event enable row level security;
revoke all on table public.qr_tag_event from anon, authenticated;
revoke all on sequence public.qr_tag_event_event_id_seq from anon, authenticated;

drop trigger if exists qr_tag_event_immutable_trigger on public.qr_tag_event;
create trigger qr_tag_event_immutable_trigger
before update or delete on public.qr_tag_event
for each row execute function public.prevent_immutable_event_change();

create or replace function public.write_qr_tag_event(
  p_qr_tag_id integer,
  p_actor_user_id integer,
  p_action text,
  p_from_status text default null,
  p_to_status text default null,
  p_plant_id integer default null,
  p_reason text default null,
  p_replacement_qr_tag_id integer default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare new_event_id bigint;
begin
  insert into public.qr_tag_event (
    qr_tag_id, actor_user_id, action, from_status, to_status,
    plant_id, reason, replacement_qr_tag_id
  ) values (
    p_qr_tag_id, p_actor_user_id, trim(p_action), p_from_status, p_to_status,
    p_plant_id, nullif(trim(p_reason), ''), p_replacement_qr_tag_id
  ) returning event_id into new_event_id;
  return new_event_id;
end;
$$;

revoke all on function public.write_qr_tag_event(integer, integer, text, text, text, integer, text, integer) from public;

-- Establish a baseline event for legacy tags without manufacturing actors.
insert into public.qr_tag_event (
  qr_tag_id, action, to_status, plant_id, reason, created_at
)
select q.qr_tag_id, 'qr.imported', q.lifecycle_status,
  q.assigned_plant_id, 'Lifecycle history initialized', now()
from public.qr_tag q
where not exists (
  select 1 from public.qr_tag_event e where e.qr_tag_id = q.qr_tag_id
);

-- Same signature and result shape used by the current QR service.
create or replace function public.college_admin_create_qr_tags(
  p_session_token text,
  p_codes text[]
)
returns table(
  qr_tag_id integer,
  qr_code_string text,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  raw_code text;
  new_tag public.qr_tag%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if actor.campus_id is null or actor.college_id is null then raise exception 'College Admin scope is incomplete'; end if;
  if coalesce(array_length(p_codes, 1), 0) not between 1 and 500 then
    raise exception 'Amount must be between 1 and 500';
  end if;

  foreach raw_code in array p_codes loop
    if raw_code is null or trim(raw_code) = '' then
      raise exception 'QR codes cannot be empty';
    end if;

    insert into public.qr_tag (
      qr_code_string, status, lifecycle_status, campus_id, college_id,
      created_by, last_status_changed_at, last_status_changed_by
    ) values (
      trim(raw_code), 'available', 'available', actor.campus_id,
      actor.college_id, actor.user_id, now(), actor.user_id
    ) returning * into new_tag;

    perform public.write_qr_tag_event(
      new_tag.qr_tag_id, actor.user_id, 'qr.created', null, 'available'
    );

    qr_tag_id := new_tag.qr_tag_id;
    qr_code_string := new_tag.qr_code_string::text;
    status := new_tag.status::text;
    created_at := new_tag.created_at;
    return next;
  end loop;

  perform public.write_audit_event(
    actor.user_id, 'qr.batch_created', 'qr_tag_batch', null,
    actor.campus_id, actor.college_id, null, null,
    jsonb_build_object('count', array_length(p_codes, 1))
  );
end;
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
      normalized_search is null
      or q.qr_code_string ilike '%' || normalized_search || '%'
      or q.qr_tag_id::text = normalized_search
      or p.plant_id::text = normalized_search
      or pc.common_name ilike '%' || normalized_search || '%'
    )
  order by q.qr_tag_id desc
  limit safe_limit offset safe_offset;
end;
$$;

create or replace function public.college_admin_set_qr_status(
  p_session_token text,
  p_qr_tag_id integer,
  p_status text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_tag public.qr_tag%rowtype;
  normalized_status text;
  related_plant_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  normalized_status := lower(trim(p_status));
  if normalized_status not in ('available', 'assigned', 'damaged', 'retired') then
    raise exception 'Invalid QR status';
  end if;

  select * into target_tag from public.qr_tag q
  where q.qr_tag_id = p_qr_tag_id
    and q.campus_id = actor.campus_id
    and q.college_id = actor.college_id
  for update;
  if not found then raise exception 'QR tag not found in your college'; end if;

  related_plant_id := coalesce(target_tag.assigned_plant_id, (
    select p.plant_id from public.plant p
    where p.qr_tag_id = target_tag.qr_tag_id and p.archived_at is null
    order by p.plant_id limit 1
  ));

  if normalized_status = 'available' and related_plant_id is not null then
    raise exception 'An assigned QR tag cannot be made available';
  end if;
  if normalized_status = 'assigned' and related_plant_id is null then
    raise exception 'A QR tag can only be assigned through plant registration or replacement';
  end if;
  if normalized_status = 'retired' and related_plant_id is not null then
    raise exception 'Replace an assigned QR tag before retiring it';
  end if;

  update public.qr_tag q
  set status = (
        jsonb_populate_record(null::public.qr_tag, jsonb_build_object('status', normalized_status))
      ).status,
      lifecycle_status = normalized_status,
      last_status_changed_at = now(),
      last_status_changed_by = actor.user_id,
      status_reason = nullif(trim(p_reason), ''),
      damaged_at = case when normalized_status = 'damaged' then now() else q.damaged_at end,
      retired_at = case when normalized_status = 'retired' then now() else q.retired_at end
  where q.qr_tag_id = p_qr_tag_id;

  perform public.write_qr_tag_event(
    target_tag.qr_tag_id, actor.user_id, 'qr.status_changed',
    target_tag.lifecycle_status, normalized_status, related_plant_id,
    p_reason
  );
  perform public.write_audit_event(
    actor.user_id, 'qr.status_changed', 'qr_tag', target_tag.qr_tag_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object('status', target_tag.lifecycle_status),
    jsonb_build_object('status', normalized_status),
    jsonb_build_object('reason', nullif(trim(p_reason), ''))
  );
end;
$$;

create or replace function public.college_admin_mark_qr_damaged(
  p_session_token text,
  p_qr_tag_id integer,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_reason is null or trim(p_reason) = '' then
    raise exception 'A damage reason is required';
  end if;
  perform public.college_admin_set_qr_status(
    p_session_token, p_qr_tag_id, 'damaged', p_reason
  );
end;
$$;

create or replace function public.college_admin_retire_qr(
  p_session_token text,
  p_qr_tag_id integer,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_reason is null or trim(p_reason) = '' then
    raise exception 'A retirement reason is required';
  end if;
  perform public.college_admin_set_qr_status(
    p_session_token, p_qr_tag_id, 'retired', p_reason
  );
end;
$$;

create or replace function public.college_admin_replace_qr(
  p_session_token text,
  p_old_qr_tag_id integer,
  p_replacement_qr_tag_id integer,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  old_tag public.qr_tag%rowtype;
  replacement_tag public.qr_tag%rowtype;
  related_plant public.plant%rowtype;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if p_old_qr_tag_id = p_replacement_qr_tag_id then raise exception 'Choose a different replacement QR tag'; end if;
  if p_reason is null or trim(p_reason) = '' then raise exception 'A replacement reason is required'; end if;

  select * into old_tag from public.qr_tag q
  where q.qr_tag_id = p_old_qr_tag_id
    and q.campus_id = actor.campus_id
    and q.college_id = actor.college_id
  for update;
  if not found then raise exception 'Original QR tag not found in your college'; end if;

  select * into replacement_tag from public.qr_tag q
  where q.qr_tag_id = p_replacement_qr_tag_id
    and q.campus_id = actor.campus_id
    and q.college_id = actor.college_id
    and q.lifecycle_status = 'available'
  for update;
  if not found then raise exception 'Replacement QR tag is not available in your college'; end if;

  select * into related_plant from public.plant p
  where p.archived_at is null
    and (p.plant_id = old_tag.assigned_plant_id or p.qr_tag_id = old_tag.qr_tag_id)
  order by case when p.plant_id = old_tag.assigned_plant_id then 0 else 1 end
  limit 1
  for update;
  if not found then raise exception 'Original QR tag is not assigned to an active plant'; end if;

  update public.plant p
  set qr_tag_id = replacement_tag.qr_tag_id
  where p.plant_id = related_plant.plant_id;

  update public.qr_tag q
  set status = (
        jsonb_populate_record(null::public.qr_tag, jsonb_build_object('status', 'retired'))
      ).status,
      lifecycle_status = 'replaced',
      assigned_plant_id = null,
      replacement_qr_tag_id = replacement_tag.qr_tag_id,
      last_status_changed_at = now(),
      last_status_changed_by = actor.user_id,
      status_reason = trim(p_reason),
      retired_at = now()
  where q.qr_tag_id = old_tag.qr_tag_id;

  update public.qr_tag q
  set status = (
        jsonb_populate_record(null::public.qr_tag, jsonb_build_object('status', 'assigned'))
      ).status,
      lifecycle_status = 'assigned',
      assigned_plant_id = related_plant.plant_id,
      replaces_qr_tag_id = old_tag.qr_tag_id,
      last_status_changed_at = now(),
      last_status_changed_by = actor.user_id,
      status_reason = trim(p_reason)
  where q.qr_tag_id = replacement_tag.qr_tag_id;

  perform public.write_qr_tag_event(
    old_tag.qr_tag_id, actor.user_id, 'qr.replaced',
    old_tag.lifecycle_status, 'replaced', related_plant.plant_id,
    p_reason, replacement_tag.qr_tag_id
  );
  perform public.write_qr_tag_event(
    replacement_tag.qr_tag_id, actor.user_id, 'qr.assigned_as_replacement',
    replacement_tag.lifecycle_status, 'assigned', related_plant.plant_id,
    p_reason, old_tag.qr_tag_id
  );
  perform public.write_audit_event(
    actor.user_id, 'qr.replaced', 'qr_tag', old_tag.qr_tag_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object(
      'status', old_tag.lifecycle_status,
      'plant_id', related_plant.plant_id
    ),
    jsonb_build_object(
      'status', 'replaced',
      'replacement_qr_tag_id', replacement_tag.qr_tag_id,
      'plant_id', related_plant.plant_id
    ),
    jsonb_build_object('reason', trim(p_reason))
  );
end;
$$;

revoke all on function public.college_admin_create_qr_tags(text, text[]) from public;
revoke all on function public.college_admin_list_qr_tags(text, text, text, integer, integer) from public;
revoke all on function public.college_admin_set_qr_status(text, integer, text, text) from public;
revoke all on function public.college_admin_mark_qr_damaged(text, integer, text) from public;
revoke all on function public.college_admin_retire_qr(text, integer, text) from public;
revoke all on function public.college_admin_replace_qr(text, integer, integer, text) from public;
grant execute on function public.college_admin_create_qr_tags(text, text[]) to anon, authenticated;
grant execute on function public.college_admin_list_qr_tags(text, text, text, integer, integer) to anon, authenticated;
grant execute on function public.college_admin_set_qr_status(text, integer, text, text) to anon, authenticated;
grant execute on function public.college_admin_mark_qr_damaged(text, integer, text) to anon, authenticated;
grant execute on function public.college_admin_retire_qr(text, integer, text) to anon, authenticated;
grant execute on function public.college_admin_replace_qr(text, integer, integer, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Registration and inspection RPC enhancements (existing signatures retained)
-- ---------------------------------------------------------------------------

create or replace function public.register_plant_with_qr(
  p_session_token text,
  p_classification_id integer,
  p_campus_id integer,
  p_college_id integer,
  p_town_id integer,
  p_barangay_id integer,
  p_growth_status_id integer,
  p_health_status_id integer,
  p_registered_by integer,
  p_variety text default null,
  p_date_planted date default null,
  p_tree_planter text default null,
  p_photo_url text default null,
  p_existing_qr_tag_id integer default null,
  p_new_qr_code text default null
)
returns table(plant_id integer, qr_tag_id integer, qr_code_string text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  selected_qr public.qr_tag%rowtype;
  new_plant_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then raise exception 'College Admin access required'; end if;
  if actor.campus_id is distinct from p_campus_id
      or actor.college_id is distinct from p_college_id then
    raise exception 'Plant registration is outside your assigned college';
  end if;
  if p_registered_by is distinct from actor.user_id then
    raise exception 'Invalid registering user';
  end if;
  if p_date_planted is not null and p_date_planted > current_date then
    raise exception 'Date planted cannot be in the future';
  end if;
  if not exists (
    select 1 from public.plant_classification c
    where c.classification_id = p_classification_id
  ) then raise exception 'Plant classification not found'; end if;
  if not exists (
    select 1 from public.college c
    where c.college_id = p_college_id and c.campus_id = p_campus_id
  ) then raise exception 'College does not belong to campus'; end if;
  if not exists (
    select 1 from public.barangay b
    where b.barangay_id = p_barangay_id and b.town_id = p_town_id
  ) then raise exception 'Barangay does not belong to town'; end if;
  if not exists (
    select 1 from public.growth_status g
    where g.growth_status_id = p_growth_status_id
  ) then raise exception 'Growth status not found'; end if;
  if not exists (
    select 1 from public.health_status h
    where h.health_status_id = p_health_status_id
  ) then raise exception 'Health status not found'; end if;

  if p_existing_qr_tag_id is not null then
    select * into selected_qr from public.qr_tag q
    where q.qr_tag_id = p_existing_qr_tag_id
      and lower(q.status::text) = 'available'
      and q.lifecycle_status = 'available'
      and (
        (q.campus_id = actor.campus_id and q.college_id = actor.college_id)
        or (q.campus_id is null and q.college_id is null)
      )
    for update;
    if not found then raise exception 'Selected QR tag is not available in your college'; end if;
  else
    if p_new_qr_code is null or trim(p_new_qr_code) = '' then
      raise exception 'A new QR code is required';
    end if;
    insert into public.qr_tag (
      qr_code_string, status, lifecycle_status, campus_id, college_id,
      created_by, last_status_changed_at, last_status_changed_by
    ) values (
      trim(p_new_qr_code), 'available', 'available', actor.campus_id,
      actor.college_id, actor.user_id, now(), actor.user_id
    ) returning * into selected_qr;

    perform public.write_qr_tag_event(
      selected_qr.qr_tag_id, actor.user_id, 'qr.created', null, 'available'
    );
  end if;

  insert into public.plant (
    classification_id, campus_id, college_id, town_id, barangay_id,
    qr_tag_id, variety, date_planted, tree_planter, photo_url,
    registered_by, growth_status_id, health_status_id,
    inspection_interval_days, next_inspection_due_on
  ) values (
    p_classification_id, p_campus_id, p_college_id, p_town_id,
    p_barangay_id, selected_qr.qr_tag_id, nullif(trim(p_variety), ''),
    p_date_planted, nullif(trim(p_tree_planter), ''),
    nullif(trim(p_photo_url), ''), actor.user_id, p_growth_status_id,
    p_health_status_id, 90,
    coalesce(p_date_planted, current_date) + 90
  ) returning public.plant.plant_id into new_plant_id;

  update public.qr_tag q
  set status = (
        jsonb_populate_record(null::public.qr_tag, jsonb_build_object('status', 'assigned'))
      ).status,
      lifecycle_status = 'assigned',
      campus_id = actor.campus_id,
      college_id = actor.college_id,
      created_by = coalesce(q.created_by, actor.user_id),
      assigned_plant_id = new_plant_id,
      last_status_changed_at = now(),
      last_status_changed_by = actor.user_id,
      status_reason = 'Assigned during plant registration'
  where q.qr_tag_id = selected_qr.qr_tag_id;

  perform public.write_qr_tag_event(
    selected_qr.qr_tag_id, actor.user_id, 'qr.assigned',
    selected_qr.lifecycle_status, 'assigned', new_plant_id,
    'Assigned during plant registration'
  );
  perform public.write_audit_event(
    actor.user_id, 'plant.registered', 'plant', new_plant_id::text,
    actor.campus_id, actor.college_id, null,
    jsonb_build_object(
      'classification_id', p_classification_id,
      'variety', nullif(trim(p_variety), ''),
      'date_planted', p_date_planted,
      'town_id', p_town_id,
      'barangay_id', p_barangay_id,
      'qr_tag_id', selected_qr.qr_tag_id,
      'inspection_interval_days', 90,
      'next_inspection_due_on', coalesce(p_date_planted, current_date) + 90
    )
  );

  return query
  select new_plant_id, selected_qr.qr_tag_id, selected_qr.qr_code_string::text;
end;
$$;

create or replace function public.inspection_team_submit_inspection(
  p_session_token text,
  p_plant_id integer,
  p_health_status_id integer,
  p_growth_status_id integer,
  p_observation text default null,
  p_photo_url text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target_plant public.plant%rowtype;
  previous_health_status_id integer;
  previous_growth_status_id integer;
  next_due_on date;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'inspection_team' then raise exception 'Inspection Team access required'; end if;

  select * into target_plant from public.plant p
  where p.plant_id = p_plant_id
    and p.campus_id = actor.campus_id
    and p.college_id = actor.college_id
    and p.archived_at is null
  for update;
  if not found then raise exception 'Plant is outside your assigned college or is archived'; end if;
  if not exists (
    select 1 from public.health_status h
    where h.health_status_id = p_health_status_id
  ) then raise exception 'Health status not found'; end if;
  if not exists (
    select 1 from public.growth_status g
    where g.growth_status_id = p_growth_status_id
  ) then raise exception 'Growth status not found'; end if;

  previous_health_status_id := target_plant.health_status_id;
  previous_growth_status_id := target_plant.growth_status_id;
  next_due_on := current_date + target_plant.inspection_interval_days;

  insert into public.inspection (
    plant_id, inspected_by, health_status_id, growth_status_id,
    observation, photo_url, last_inspection_date, inspected_at
  ) values (
    p_plant_id, actor.user_id, p_health_status_id, p_growth_status_id,
    nullif(trim(p_observation), ''), nullif(trim(p_photo_url), ''),
    current_date, now()
  );

  update public.plant p
  set health_status_id = p_health_status_id,
      growth_status_id = p_growth_status_id,
      photo_url = coalesce(nullif(trim(p_photo_url), ''), p.photo_url),
      last_inspected_on = current_date,
      next_inspection_due_on = next_due_on
  where p.plant_id = p_plant_id;

  perform public.write_audit_event(
    actor.user_id, 'inspection.submitted', 'plant', p_plant_id::text,
    actor.campus_id, actor.college_id,
    jsonb_build_object(
      'health_status_id', previous_health_status_id,
      'growth_status_id', previous_growth_status_id,
      'last_inspected_on', target_plant.last_inspected_on,
      'next_inspection_due_on', target_plant.next_inspection_due_on
    ),
    jsonb_build_object(
      'health_status_id', p_health_status_id,
      'growth_status_id', p_growth_status_id,
      'last_inspected_on', current_date,
      'next_inspection_due_on', next_due_on
    ),
    jsonb_build_object(
      'has_observation', nullif(trim(p_observation), '') is not null,
      'has_photo', nullif(trim(p_photo_url), '') is not null
    )
  );
end;
$$;

create or replace function public.list_inspection_queue(
  p_session_token text,
  p_due_filter text default 'all',
  p_limit integer default 100,
  p_offset integer default 0
)
returns table(
  plant_id integer,
  common_name text,
  variety text,
  campus_id integer,
  campus_name text,
  college_id integer,
  college_name text,
  last_inspected_on date,
  next_inspection_due_on date,
  inspection_interval_days integer,
  health_status text,
  growth_stage text,
  photo_url text,
  due_state text,
  days_overdue integer
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  normalized_filter text;
  safe_limit integer;
  safe_offset integer;
begin
  actor := public.require_app_session(p_session_token);
  normalized_filter := coalesce(nullif(lower(trim(p_due_filter)), ''), 'all');
  safe_limit := least(greatest(coalesce(p_limit, 100), 1), 500);
  safe_offset := greatest(coalesce(p_offset, 0), 0);

  if normalized_filter not in ('all', 'due', 'overdue', 'due_today', 'due_soon', 'upcoming') then
    raise exception 'Invalid inspection queue filter';
  end if;

  return query
  select p.plant_id, pc.common_name::text, p.variety::text,
    p.campus_id, c.campus_name::text, p.college_id, co.college_name::text,
    p.last_inspected_on, p.next_inspection_due_on,
    p.inspection_interval_days, hs.status_name::text,
    gs.growth_stage::text, p.photo_url::text,
    case
      when p.next_inspection_due_on < current_date then 'overdue'
      when p.next_inspection_due_on = current_date then 'due_today'
      when p.next_inspection_due_on <= current_date + 7 then 'due_soon'
      else 'upcoming'
    end::text as due_state,
    greatest(current_date - p.next_inspection_due_on, 0)::integer as days_overdue
  from public.plant p
  join public.plant_classification pc on pc.classification_id = p.classification_id
  join public.campus c on c.campus_id = p.campus_id
  join public.college co on co.college_id = p.college_id
  left join public.health_status hs on hs.health_status_id = p.health_status_id
  left join public.growth_status gs on gs.growth_status_id = p.growth_status_id
  where p.archived_at is null
    and (
      actor.role in ('super_admin', 'university_admin')
      or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
      or (actor.role in ('college_admin', 'inspection_team')
          and p.campus_id = actor.campus_id
          and p.college_id = actor.college_id)
    )
    and (
      normalized_filter = 'all'
      or (normalized_filter = 'due' and p.next_inspection_due_on <= current_date)
      or (normalized_filter = 'overdue' and p.next_inspection_due_on < current_date)
      or (normalized_filter = 'due_today' and p.next_inspection_due_on = current_date)
      or (normalized_filter = 'due_soon'
          and p.next_inspection_due_on > current_date
          and p.next_inspection_due_on <= current_date + 7)
      or (normalized_filter = 'upcoming' and p.next_inspection_due_on > current_date + 7)
    )
  order by p.next_inspection_due_on, p.plant_id
  limit safe_limit offset safe_offset;
end;
$$;

-- Replace the draft paginated overload with the exact mobile queue contract.
drop function if exists public.list_inspection_queue(text, text, integer, integer);
create or replace function public.list_inspection_queue(
  p_session_token text,
  p_filter text,
  p_completed_since date
)
returns table(
  plant_id integer,
  common_name text,
  variety text,
  campus_id integer,
  campus_name text,
  college_id integer,
  college_name text,
  last_inspected_on date,
  next_inspection_due_on date,
  inspection_interval_days integer,
  health_status text,
  growth_stage text,
  photo_url text,
  schedule_status text,
  days_overdue integer
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  normalized_filter text;
  completed_cutoff date;
begin
  actor := public.require_app_session(p_session_token);
  normalized_filter := coalesce(nullif(lower(trim(p_filter)), ''), 'action');
  completed_cutoff := coalesce(p_completed_since, current_date - 30);

  if normalized_filter not in (
    'action', 'due_today', 'overdue', 'upcoming', 'completed', 'all'
  ) then
    raise exception 'Invalid inspection queue filter';
  end if;

  return query
  select p.plant_id, pc.common_name::text, p.variety::text,
    p.campus_id, c.campus_name::text, p.college_id, co.college_name::text,
    p.last_inspected_on, p.next_inspection_due_on,
    p.inspection_interval_days, hs.status_name::text,
    gs.growth_stage::text, p.photo_url::text,
    case
      when normalized_filter = 'completed' then 'completed'
      when p.next_inspection_due_on < current_date then 'overdue'
      when p.next_inspection_due_on = current_date then 'due_today'
      when p.next_inspection_due_on > current_date then 'upcoming'
      else 'unscheduled'
    end::text as schedule_status,
    case
      when p.next_inspection_due_on is null then 0
      else greatest(current_date - p.next_inspection_due_on, 0)::integer
    end as days_overdue
  from public.plant p
  join public.plant_classification pc on pc.classification_id = p.classification_id
  join public.campus c on c.campus_id = p.campus_id
  join public.college co on co.college_id = p.college_id
  left join public.health_status hs on hs.health_status_id = p.health_status_id
  left join public.growth_status gs on gs.growth_status_id = p.growth_status_id
  where p.archived_at is null
    and (
      actor.role in ('super_admin', 'university_admin')
      or (actor.role = 'campus_admin' and p.campus_id = actor.campus_id)
      or (actor.role in ('college_admin', 'inspection_team')
          and p.campus_id = actor.campus_id
          and p.college_id = actor.college_id)
    )
    and (
      normalized_filter = 'all'
      or (normalized_filter = 'action'
          and p.next_inspection_due_on <= current_date)
      or (normalized_filter = 'overdue'
          and p.next_inspection_due_on < current_date)
      or (normalized_filter = 'due_today'
          and p.next_inspection_due_on = current_date)
      or (normalized_filter = 'upcoming'
          and p.next_inspection_due_on > current_date)
      or (normalized_filter = 'completed'
          and p.last_inspected_on >= completed_cutoff)
    )
  order by
    case when normalized_filter = 'completed' then p.last_inspected_on end desc,
    p.next_inspection_due_on,
    p.plant_id;
end;
$$;

revoke all on function public.register_plant_with_qr(text, integer, integer, integer, integer, integer, integer, integer, integer, text, date, text, text, integer, text) from public;
revoke all on function public.inspection_team_submit_inspection(text, integer, integer, integer, text, text) from public;
revoke all on function public.list_inspection_queue(text, text, date) from public;
grant execute on function public.register_plant_with_qr(text, integer, integer, integer, integer, integer, integer, integer, integer, text, date, text, text, integer, text) to anon, authenticated;
grant execute on function public.inspection_team_submit_inspection(text, integer, integer, integer, text, text) to anon, authenticated;
grant execute on function public.list_inspection_queue(text, text, date) to anon, authenticated;

notify pgrst, 'reload schema';





