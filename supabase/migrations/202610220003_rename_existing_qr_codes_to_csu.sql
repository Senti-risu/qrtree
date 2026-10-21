-- Rename issued QR codes to CSU while retaining old printed codes as
-- private aliases for guest and staff scans.
begin;

create table if not exists public.qr_tag_code_alias (
  alias_code text primary key,
  qr_tag_id integer not null unique
    references public.qr_tag(qr_tag_id) on delete cascade,
  created_at timestamptz not null default clock_timestamp()
);

revoke all on table public.qr_tag_code_alias from public, anon, authenticated;

do $$
begin
  if exists (
    select 1
    from public.qr_tag old_tag
    join public.qr_tag new_tag
      on new_tag.qr_code_string::text =
        regexp_replace(old_tag.qr_code_string::text, '^ECOTAG-', 'CSU-')
    where old_tag.qr_code_string::text like 'ECOTAG-%'
      and old_tag.qr_tag_id <> new_tag.qr_tag_id
  ) then
    raise exception 'A CSU QR code already conflicts with an existing EcoTag code';
  end if;

  if exists (
    select 1
    from public.qr_tag old_tag
    join public.qr_tag_code_alias alias
      on alias.alias_code = old_tag.qr_code_string::text
    where old_tag.qr_code_string::text like 'ECOTAG-%'
      and alias.qr_tag_id <> old_tag.qr_tag_id
  ) then
    raise exception 'An old QR code is already assigned to a different tag alias';
  end if;
end;
$$;

insert into public.qr_tag_code_alias (alias_code, qr_tag_id)
select q.qr_code_string::text, q.qr_tag_id
from public.qr_tag q
where q.qr_code_string::text like 'ECOTAG-%'
on conflict (alias_code) do nothing;

update public.qr_tag q
set qr_code_string = regexp_replace(q.qr_code_string::text, '^ECOTAG-', 'CSU-')
where q.qr_code_string::text like 'ECOTAG-%';

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
    'CSU-%s-%s',
    to_char(p_created_at at time zone 'Asia/Manila', 'YYYYMM'),
    lpad(code_digits, greatest(6, length(code_digits)), '0')
  );
end;
$$;

revoke all on function public.next_ecotag_qr_code(timestamptz)
  from public, anon, authenticated;

create or replace function public.staff_find_qr_tag_by_code(
  p_session_token text,
  p_qr_code text
)
returns table(
  qr_tag_id integer,
  qr_code_string text,
  status text,
  lifecycle_status text,
  created_at timestamptz,
  replacement_qr_tag_id integer,
  status_reason text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  normalized_code text;
  numeric_id integer;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role not in (
    'super_admin', 'university_admin', 'campus_admin',
    'college_admin', 'inspection_team'
  ) then
    raise exception 'Staff QR scanning access required';
  end if;

  normalized_code := upper(trim(coalesce(p_qr_code, '')));
  if normalized_code = '' or length(normalized_code) > 160 then
    raise exception 'Enter a valid CSU QR code';
  end if;
  if normalized_code ~ '^[0-9]+$'
      and normalized_code::numeric <= 2147483647 then
    numeric_id := normalized_code::integer;
  end if;

  return query
  select
    q.qr_tag_id,
    q.qr_code_string::text,
    q.status::text,
    q.lifecycle_status::text,
    q.created_at,
    q.replacement_qr_tag_id,
    q.status_reason::text
  from public.qr_tag q
  where (
    (numeric_id is not null and q.qr_tag_id = numeric_id)
    or q.qr_code_string::text = normalized_code
    or exists (
      select 1
      from public.qr_tag_code_alias alias
      where alias.qr_tag_id = q.qr_tag_id
        and alias.alias_code = normalized_code
    )
  )
  and (
    actor.role in ('super_admin', 'university_admin')
    or (actor.role = 'campus_admin' and q.campus_id = actor.campus_id)
    or (
      actor.role in ('college_admin', 'inspection_team')
      and q.campus_id = actor.campus_id
      and q.college_id = actor.college_id
    )
  )
  limit 1;
end;
$$;

revoke all on function public.staff_find_qr_tag_by_code(text, text)
  from public;
grant execute on function public.staff_find_qr_tag_by_code(text, text)
  to anon, authenticated;

create or replace function public.guest_view_plant_by_qr(
  p_visit_id bigint,
  p_qr_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  normalized_code text;
  target_tag public.qr_tag%rowtype;
  tag_status text;
  outcome_message text;
  plant_payload jsonb;
  target_plant_id integer;
  target_campus_id integer;
  target_college_id integer;
begin
  if p_visit_id is null or not exists (
    select 1
    from public.guest_visit v
    where v.visit_id = p_visit_id
  ) then
    raise exception 'A valid guest visit is required';
  end if;

  normalized_code := upper(trim(coalesce(p_qr_code, '')));
  if normalized_code = '' or length(normalized_code) > 160 then
    raise exception 'Enter a valid CSU code';
  end if;

  select q.*
    into target_tag
  from public.qr_tag q
  where q.qr_code_string::text = normalized_code
    or exists (
      select 1
      from public.qr_tag_code_alias alias
      where alias.qr_tag_id = q.qr_tag_id
        and alias.alias_code = normalized_code
    )
  limit 1;

  if not found then
    perform public.write_audit_event(
      null,
      'guest.qr_scanned',
      'guest_visit',
      p_visit_id::text,
      null,
      null,
      null,
      null,
      jsonb_build_object('outcome', 'not_found')
    );
    return jsonb_build_object(
      'result_status', 'not_found',
      'message', 'This is not a recognized CSU code. Check the label and try again.'
    );
  end if;

  tag_status := coalesce(
    nullif(lower(trim(target_tag.lifecycle_status)), ''),
    nullif(lower(trim(target_tag.status::text)), ''),
    'unknown'
  );
  if tag_status = 'lost' then tag_status := 'retired'; end if;

  if tag_status <> 'assigned' then
    outcome_message := case tag_status
      when 'available' then 'This CSU QR has not been assigned to a plant yet.'
      when 'damaged' then 'This CSU QR was reported damaged. Please scan the replacement label.'
      when 'replaced' then 'This CSU QR was replaced. Please scan the newer label on the plant.'
      when 'retired' then 'This CSU QR is retired and no longer opens a plant profile.'
      else 'This CSU QR is currently unavailable.'
    end;

    perform public.write_audit_event(
      null,
      'guest.qr_scanned',
      'qr_tag',
      target_tag.qr_tag_id::text,
      target_tag.campus_id,
      target_tag.college_id,
      null,
      null,
      jsonb_build_object(
        'visit_id', p_visit_id,
        'outcome', tag_status
      )
    );
    return jsonb_build_object(
      'result_status', tag_status,
      'message', outcome_message
    );
  end if;

  select
    jsonb_build_object(
      'plant_id', p.plant_id,
      'qr_code', target_tag.qr_code_string::text,
      'common_name', pc.common_name::text,
      'scientific_name', pc.scientific_name::text,
      'plant_type', pc.plant_type::text,
      'variety', p.variety::text,
      'photo_url', p.photo_url::text,
      'date_planted', p.date_planted,
      'tree_planter', p.tree_planter::text,
      'campus_name', c.campus_name::text,
      'planting_location_type', p.planting_location_type,
      'planting_campus_name', planting_campus.campus_name::text,
      'college_name', co.college_name::text,
      'town_name', t.town_name::text,
      'barangay_name', b.barangay_name::text,
      'growth_stage', gs.growth_stage::text,
      'health_status', hs.status_name::text
    ),
    p.plant_id,
    p.campus_id,
    p.college_id
  into plant_payload, target_plant_id, target_campus_id, target_college_id
  from public.plant p
  join public.plant_classification pc
    on pc.classification_id = p.classification_id
  left join public.campus c on c.campus_id = p.campus_id
  left join public.campus planting_campus
    on planting_campus.campus_id = p.planting_campus_id
  left join public.college co on co.college_id = p.college_id
  left join public.town t on t.town_id = p.town_id
  left join public.barangay b on b.barangay_id = p.barangay_id
  left join public.growth_status gs
    on gs.growth_status_id = p.growth_status_id
  left join public.health_status hs
    on hs.health_status_id = p.health_status_id
  where p.archived_at is null
    and (
      p.plant_id = target_tag.assigned_plant_id
      or p.qr_tag_id = target_tag.qr_tag_id
    )
  order by case
    when p.plant_id = target_tag.assigned_plant_id then 0
    else 1
  end
  limit 1;

  if plant_payload is null then
    perform public.write_audit_event(
      null,
      'guest.qr_scanned',
      'qr_tag',
      target_tag.qr_tag_id::text,
      target_tag.campus_id,
      target_tag.college_id,
      null,
      null,
      jsonb_build_object(
        'visit_id', p_visit_id,
        'outcome', 'plant_unavailable'
      )
    );
    return jsonb_build_object(
      'result_status', 'unavailable',
      'message', 'The plant profile linked to this CSU QR is unavailable.'
    );
  end if;

  perform public.write_audit_event(
    null,
    'guest.qr_viewed',
    'plant',
    target_plant_id::text,
    target_campus_id,
    target_college_id,
    null,
    null,
    jsonb_build_object(
      'visit_id', p_visit_id,
      'qr_tag_id', target_tag.qr_tag_id,
      'access', 'read_only'
    )
  );

  return jsonb_build_object(
    'result_status', 'assigned',
    'message', 'Plant profile found.',
    'plant', plant_payload
  );
end;
$$;

notify pgrst, 'reload schema';
commit;
