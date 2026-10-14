-- College Admins may manage Inspection Team accounts only inside their own scope.

create or replace function public.college_admin_list_inspection_users(p_actor_user_id integer)
returns table(user_id integer, username text, is_active boolean, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  actor public.users%rowtype;
begin
  select * into actor from public.users where users.user_id = p_actor_user_id;
  if not found or actor.role <> 'college_admin' or not actor.is_active then
    raise exception 'Active College Admin access required';
  end if;
  if actor.campus_id is null or actor.college_id is null then
    raise exception 'College Admin has no assigned campus or college';
  end if;

  return query
    select u.user_id, u.username::text, u.is_active, u.created_at
    from public.users u
    where u.role = 'inspection_team'
      and u.campus_id = actor.campus_id
      and u.college_id = actor.college_id
    order by u.username;
end;
$$;

create or replace function public.college_admin_create_inspection_user(
  p_actor_user_id integer,
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
  select * into actor from public.users where users.user_id = p_actor_user_id;
  if not found or actor.role <> 'college_admin' or not actor.is_active then
    raise exception 'Active College Admin access required';
  end if;
  if actor.campus_id is null or actor.college_id is null then
    raise exception 'College Admin has no assigned campus or college';
  end if;
  if p_username is null or trim(p_username) !~ '^[A-Za-z0-9._-]{3,40}$' then
    raise exception 'Invalid username';
  end if;
  if p_password is null or length(p_password) < 8 then
    raise exception 'Password must contain at least 8 characters';
  end if;

  insert into public.users(
    username, password_hash, role, campus_id, college_id,
    is_active, created_by
  ) values (
    trim(p_username), crypt(p_password, gen_salt('bf')),
    'inspection_team'::public.user_role,
    actor.campus_id, actor.college_id, true, actor.user_id
  ) returning users.user_id into new_user_id;

  return new_user_id;
end;
$$;

create or replace function public.college_admin_set_inspection_user_active(
  p_actor_user_id integer,
  p_target_user_id integer,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor public.users%rowtype;
begin
  select * into actor from public.users where users.user_id = p_actor_user_id;
  if not found or actor.role <> 'college_admin' or not actor.is_active then
    raise exception 'Active College Admin access required';
  end if;

  update public.users u set is_active = p_is_active
  where u.user_id = p_target_user_id
    and u.role = 'inspection_team'
    and u.campus_id = actor.campus_id
    and u.college_id = actor.college_id;
  if not found then raise exception 'Inspection Team account not found in your college'; end if;
end;
$$;

revoke all on function public.college_admin_list_inspection_users(integer) from public;
revoke all on function public.college_admin_create_inspection_user(integer, text, text) from public;
revoke all on function public.college_admin_set_inspection_user_active(integer, integer, boolean) from public;
grant execute on function public.college_admin_list_inspection_users(integer) to anon, authenticated;
grant execute on function public.college_admin_create_inspection_user(integer, text, text) to anon, authenticated;
grant execute on function public.college_admin_set_inspection_user_active(integer, integer, boolean) to anon, authenticated;
notify pgrst, 'reload schema';
