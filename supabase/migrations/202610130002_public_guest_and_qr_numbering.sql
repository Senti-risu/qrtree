-- Public guest entry and authoritative EcoTag QR numbering.
--
-- Apply this after 202610130001_production_readiness.sql. Guest names are
-- intentionally kept only in the Flutter process and are never accepted or
-- persisted by these database functions.

-- ---------------------------------------------------------------------------
-- Anonymous guest visits and aggregate-only public dashboard data
-- ---------------------------------------------------------------------------

create table if not exists public.guest_visit (
  visit_id bigserial primary key,
  age smallint not null check (age between 1 and 120),
  created_at timestamptz not null default clock_timestamp()
);

create index if not exists guest_visit_created_at_idx
  on public.guest_visit (created_at desc);
create index if not exists guest_visit_age_idx
  on public.guest_visit (age);

alter table public.guest_visit enable row level security;
revoke all on table public.guest_visit from public, anon, authenticated;
revoke all on sequence public.guest_visit_visit_id_seq
  from public, anon, authenticated;

drop trigger if exists guest_visit_immutable_trigger on public.guest_visit;
create trigger guest_visit_immutable_trigger
before update or delete on public.guest_visit
for each row execute function public.prevent_immutable_event_change();

create or replace function public.start_guest_visit(p_age integer)
returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  new_visit_id bigint;
  age_band text;
begin
  if p_age is null or p_age not between 1 and 120 then
    raise exception 'Age must be between 1 and 120';
  end if;

  insert into public.guest_visit (age)
  values (p_age)
  returning visit_id into new_visit_id;

  age_band := case
    when p_age < 18 then 'under_18'
    when p_age < 25 then '18_24'
    when p_age < 35 then '25_34'
    when p_age < 45 then '35_44'
    when p_age < 60 then '45_59'
    else '60_plus'
  end;

  -- Store only an age band in the general activity history. The exact age is
  -- available solely in the protected statistics table, and a guest name is
  -- never sent to or stored by the database.
  perform public.write_audit_event(
    null, 'guest.visit_started', 'guest_visit', new_visit_id::text,
    null, null, null, null,
    jsonb_build_object('age_band', age_band)
  );

  return new_visit_id;
end;
$$;

drop function if exists public.guest_dashboard_summary();

create or replace function public.guest_dashboard_summary(p_visit_id bigint)
returns table(
  total_plants integer,
  healthy_plants integer,
  at_risk_plants integer,
  dead_plants integer,
  campus_count integer
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_visit_id is null or not exists (
    select 1 from public.guest_visit v where v.visit_id = p_visit_id
  ) then
    raise exception 'A valid guest visit is required';
  end if;

  perform public.write_audit_event(
    null, 'guest.dashboard_viewed', 'guest_dashboard', p_visit_id::text
  );

  return query
  select
    count(p.plant_id)::integer as total_plants,
    count(p.plant_id) filter (
      where lower(coalesce(h.status_name::text, '')) in ('alive', 'healthy')
    )::integer as healthy_plants,
    count(p.plant_id) filter (
      where lower(coalesce(h.status_name::text, '')) in
        ('dying', 'at risk', 'at_risk')
    )::integer as at_risk_plants,
    count(p.plant_id) filter (
      where lower(coalesce(h.status_name::text, '')) = 'dead'
    )::integer as dead_plants,
    (select count(*)::integer from public.campus) as campus_count
  from public.plant p
  left join public.health_status h
    on h.health_status_id = p.health_status_id
  where p.archived_at is null;
end;
$$;

-- Exact ages are available only to university-wide administrators and only as
-- aggregates. This keeps the collected statistic useful without exposing the
-- underlying guest rows.
create or replace function public.admin_guest_visit_statistics(
  p_session_token text
)
returns table(
  total_visits bigint,
  average_age numeric,
  under_18 bigint,
  age_18_24 bigint,
  age_25_34 bigint,
  age_35_44 bigint,
  age_45_59 bigint,
  age_60_plus bigint,
  visits_last_30_days bigint
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor_account public.users%rowtype;
begin
  actor_account := public.require_app_session(p_session_token);
  if actor_account.role not in ('super_admin', 'university_admin') then
    raise exception 'University administrator access required';
  end if;

  perform public.write_audit_event(
    actor_account.user_id, 'guest.statistics_viewed', 'guest_visit_statistics',
    null, actor_account.campus_id, actor_account.college_id
  );

  return query
  select
    count(*)::bigint,
    round(avg(v.age)::numeric, 1),
    count(*) filter (where v.age < 18)::bigint,
    count(*) filter (where v.age between 18 and 24)::bigint,
    count(*) filter (where v.age between 25 and 34)::bigint,
    count(*) filter (where v.age between 35 and 44)::bigint,
    count(*) filter (where v.age between 45 and 59)::bigint,
    count(*) filter (where v.age >= 60)::bigint,
    count(*) filter (
      where v.created_at >= clock_timestamp() - interval '30 days'
    )::bigint
  from public.guest_visit v;
end;
$$;

revoke all on function public.start_guest_visit(integer) from public;
revoke all on function public.guest_dashboard_summary(bigint) from public;
revoke all on function public.admin_guest_visit_statistics(text) from public;

grant execute on function public.start_guest_visit(integer)
  to anon, authenticated;
grant execute on function public.guest_dashboard_summary(bigint)
  to anon, authenticated;
grant execute on function public.admin_guest_visit_statistics(text)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Global, concurrency-safe QR numbers
-- ---------------------------------------------------------------------------

create sequence if not exists public.ecotag_qr_number_seq
  as bigint
  start with 1
  increment by 1
  no minvalue
  no maxvalue
  no cycle;

revoke all on sequence public.ecotag_qr_number_seq
  from public, anon, authenticated;

-- If this migration is restored into a database that already contains codes
-- in the new format, advance the sequence to the largest existing suffix. It
-- is never moved backwards, which keeps this block safe to rerun.
do $$
declare
  largest_existing bigint := 0;
  sequence_last bigint;
  sequence_called boolean;
  effective_last bigint;
begin
  select coalesce(max(
    substring(
      q.qr_code_string::text
      from '^ECOTAG-[0-9]{6}-([0-9]+)$'
    )::bigint
  ), 0)
  into largest_existing
  from public.qr_tag q
  where q.qr_code_string::text ~ '^ECOTAG-[0-9]{6}-[0-9]+$';

  select last_value, is_called
  into sequence_last, sequence_called
  from public.ecotag_qr_number_seq;

  effective_last := case
    when sequence_called then sequence_last
    else sequence_last - 1
  end;

  if largest_existing > effective_last then
    perform setval(
      'public.ecotag_qr_number_seq'::regclass,
      largest_existing,
      true
    );
  end if;
end;
$$;

-- Refuse to hide a pre-existing data problem. Existing printed codes must not
-- be rewritten because doing so would invalidate their labels.
do $$
begin
  if exists (
    select 1
    from public.qr_tag q
    where q.qr_code_string is not null
    group by q.qr_code_string
    having count(*) > 1
  ) then
    raise exception 'Duplicate QR code strings must be resolved before enabling authoritative numbering';
  end if;
end;
$$;

create unique index if not exists qr_tag_qr_code_string_unique_idx
  on public.qr_tag (qr_code_string)
  where qr_code_string is not null;

create or replace function public.next_ecotag_qr_code(
  p_created_at timestamptz default clock_timestamp()
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  code_number bigint;
  code_digits text;
begin
  code_number := nextval('public.ecotag_qr_number_seq'::regclass);
  code_digits := code_number::text;

  return format(
    'ECOTAG-%s-%s',
    to_char(p_created_at at time zone 'Asia/Manila', 'YYYYMM'),
    lpad(code_digits, greatest(6, length(code_digits)), '0')
  );
end;
$$;

revoke all on function public.next_ecotag_qr_code(timestamptz)
  from public, anon, authenticated;

-- The current Flutter app calls this amount-based overload. The sequence is
-- the sole code authority, so concurrent administrators cannot create the same
-- value and a device clock cannot change the identifier.
create or replace function public.college_admin_create_qr_tags(
  p_session_token text,
  p_amount integer
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
  actor_account public.users%rowtype;
  tag_index integer;
  tag_created_at timestamptz;
  generated_code text;
  new_tag public.qr_tag%rowtype;
begin
  actor_account := public.require_app_session(p_session_token);
  if actor_account.role <> 'college_admin' then
    raise exception 'College Admin access required';
  end if;
  if actor_account.campus_id is null or actor_account.college_id is null then
    raise exception 'College Admin scope is incomplete';
  end if;
  if p_amount is null or p_amount not between 1 and 500 then
    raise exception 'Amount must be between 1 and 500';
  end if;

  for tag_index in 1..p_amount loop
    tag_created_at := clock_timestamp();
    generated_code := public.next_ecotag_qr_code(tag_created_at);

    insert into public.qr_tag (
      qr_code_string, status, lifecycle_status, campus_id, college_id,
      created_by, created_at, last_status_changed_at,
      last_status_changed_by
    ) values (
      generated_code, 'available', 'available', actor_account.campus_id,
      actor_account.college_id, actor_account.user_id, tag_created_at,
      tag_created_at, actor_account.user_id
    )
    returning * into new_tag;

    perform public.write_qr_tag_event(
      new_tag.qr_tag_id, actor_account.user_id,
      'qr.created', null, 'available'
    );

    qr_tag_id := new_tag.qr_tag_id;
    qr_code_string := new_tag.qr_code_string::text;
    status := new_tag.status::text;
    created_at := new_tag.created_at;
    return next;
  end loop;

  perform public.write_audit_event(
    actor_account.user_id, 'qr.batch_created', 'qr_tag_batch', null,
    actor_account.campus_id, actor_account.college_id, null, null,
    jsonb_build_object(
      'count', p_amount,
      'format', 'ECOTAG-YYYYMM-NNNNNN',
      'number_scope', 'global'
    )
  );
end;
$$;

-- Compatibility for an older deployed app that still sends a text array. The
-- submitted strings are intentionally ignored; only their count is used.
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
language sql
security definer
set search_path = public, extensions
as $$
  select *
  from public.college_admin_create_qr_tags(
    p_session_token,
    coalesce(array_length(p_codes, 1), 0)
  );
$$;

revoke all on function public.college_admin_create_qr_tags(text, integer)
  from public;
revoke all on function public.college_admin_create_qr_tags(text, text[])
  from public;
grant execute on function public.college_admin_create_qr_tags(text, integer)
  to anon, authenticated;
grant execute on function public.college_admin_create_qr_tags(text, text[])
  to anon, authenticated;

-- Preserve the established signature so older app versions and cached
-- PostgREST clients remain compatible. p_new_qr_code is intentionally ignored
-- when a new tag is needed; the server sequence is authoritative.
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
  actor_account public.users%rowtype;
  selected_qr public.qr_tag%rowtype;
  new_plant_id integer;
  tag_created_at timestamptz;
  generated_code text;
begin
  actor_account := public.require_app_session(p_session_token);
  if actor_account.role <> 'college_admin' then
    raise exception 'College Admin access required';
  end if;
  if actor_account.campus_id is distinct from p_campus_id
      or actor_account.college_id is distinct from p_college_id then
    raise exception 'Plant registration is outside your assigned college';
  end if;
  if p_registered_by is distinct from actor_account.user_id then
    raise exception 'Invalid registering user';
  end if;
  if p_date_planted is not null and p_date_planted > current_date then
    raise exception 'Date planted cannot be in the future';
  end if;
  if not exists (
    select 1 from public.plant_classification c
    where c.classification_id = p_classification_id
  ) then
    raise exception 'Plant classification not found';
  end if;
  if not exists (
    select 1 from public.college c
    where c.college_id = p_college_id and c.campus_id = p_campus_id
  ) then
    raise exception 'College does not belong to campus';
  end if;
  if not exists (
    select 1 from public.barangay b
    where b.barangay_id = p_barangay_id and b.town_id = p_town_id
  ) then
    raise exception 'Barangay does not belong to town';
  end if;
  if not exists (
    select 1 from public.growth_status g
    where g.growth_status_id = p_growth_status_id
  ) then
    raise exception 'Growth status not found';
  end if;
  if not exists (
    select 1 from public.health_status h
    where h.health_status_id = p_health_status_id
  ) then
    raise exception 'Health status not found';
  end if;

  if p_existing_qr_tag_id is not null then
    select * into selected_qr
    from public.qr_tag q
    where q.qr_tag_id = p_existing_qr_tag_id
      and lower(q.status::text) = 'available'
      and q.lifecycle_status = 'available'
      and (
        (q.campus_id = actor_account.campus_id
          and q.college_id = actor_account.college_id)
        or (q.campus_id is null and q.college_id is null)
      )
    for update;
    if not found then
      raise exception 'Selected QR tag is not available in your college';
    end if;
  else
    tag_created_at := clock_timestamp();
    generated_code := public.next_ecotag_qr_code(tag_created_at);

    insert into public.qr_tag (
      qr_code_string, status, lifecycle_status, campus_id, college_id,
      created_by, created_at, last_status_changed_at,
      last_status_changed_by
    ) values (
      generated_code, 'available', 'available', actor_account.campus_id,
      actor_account.college_id, actor_account.user_id, tag_created_at,
      tag_created_at, actor_account.user_id
    )
    returning * into selected_qr;

    perform public.write_qr_tag_event(
      selected_qr.qr_tag_id, actor_account.user_id,
      'qr.created', null, 'available'
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
    nullif(trim(p_photo_url), ''), actor_account.user_id,
    p_growth_status_id, p_health_status_id, 90,
    coalesce(p_date_planted, current_date) + 90
  )
  returning public.plant.plant_id into new_plant_id;

  update public.qr_tag q
  set status = (
        jsonb_populate_record(
          null::public.qr_tag,
          jsonb_build_object('status', 'assigned')
        )
      ).status,
      lifecycle_status = 'assigned',
      campus_id = actor_account.campus_id,
      college_id = actor_account.college_id,
      created_by = coalesce(q.created_by, actor_account.user_id),
      assigned_plant_id = new_plant_id,
      last_status_changed_at = clock_timestamp(),
      last_status_changed_by = actor_account.user_id,
      status_reason = 'Assigned during plant registration'
  where q.qr_tag_id = selected_qr.qr_tag_id;

  perform public.write_qr_tag_event(
    selected_qr.qr_tag_id, actor_account.user_id, 'qr.assigned',
    selected_qr.lifecycle_status, 'assigned', new_plant_id,
    'Assigned during plant registration'
  );
  perform public.write_audit_event(
    actor_account.user_id, 'plant.registered', 'plant',
    new_plant_id::text, actor_account.campus_id,
    actor_account.college_id, null,
    jsonb_build_object(
      'classification_id', p_classification_id,
      'variety', nullif(trim(p_variety), ''),
      'date_planted', p_date_planted,
      'town_id', p_town_id,
      'barangay_id', p_barangay_id,
      'qr_tag_id', selected_qr.qr_tag_id,
      'inspection_interval_days', 90,
      'next_inspection_due_on',
        coalesce(p_date_planted, current_date) + 90
    )
  );

  return query
  select new_plant_id, selected_qr.qr_tag_id,
    selected_qr.qr_code_string::text;
end;
$$;

revoke all on function public.register_plant_with_qr(
  text, integer, integer, integer, integer, integer, integer, integer,
  integer, text, date, text, text, integer, text
) from public;
grant execute on function public.register_plant_with_qr(
  text, integer, integer, integer, integer, integer, integer, integer,
  integer, text, date, text, text, integer, text
) to anon, authenticated;
