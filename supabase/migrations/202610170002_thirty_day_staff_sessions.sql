-- Apply after the secure-session and production-readiness migrations.
-- New staff sign-ins last 30 days. Existing tokens are not extended or revived.
begin;

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
      now() + interval '30 days'
    );

    perform public.write_audit_event(
      found_user.user_id, 'auth.login_succeeded', 'user', found_user.user_id::text,
      found_user.campus_id, found_user.college_id, null, null,
      jsonb_build_object('session_duration_hours', 720, 'session_duration_days', 30)
    );
  end if;

  return query select
    found_user.user_id, found_user.username::text, found_user.role::text,
    found_user.campus_id, found_user.college_id, found_user.is_active, raw_token;
end;
$$;

revoke all on function public.login_user(text, text) from public;
grant execute on function public.login_user(text, text) to anon, authenticated;
notify pgrst, 'reload schema';
commit;
