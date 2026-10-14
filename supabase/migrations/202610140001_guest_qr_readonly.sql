-- Read-only QR lookup for public EcoTag guests.
--
-- Apply after 202610130002_public_guest_and_qr_numbering.sql. This function
-- deliberately returns a curated public projection and does not grant guests
-- direct access to qr_tag, plant, inspection, or user tables.

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
    raise exception 'Enter a valid EcoTag code';
  end if;

  select q.*
    into target_tag
  from public.qr_tag q
  -- Valid EcoTag codes are generated in uppercase. Exact matching keeps the
  -- lookup deterministic and allows the authoritative unique index from the
  -- QR-numbering migration to be used.
  where q.qr_code_string::text = normalized_code
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
      'message', 'This is not a recognized EcoTag. Check the label and try again.'
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
      when 'available' then
        'This EcoTag has not been assigned to a plant yet.'
      when 'damaged' then
        'This EcoTag was reported damaged. Please scan the replacement label.'
      when 'replaced' then
        'This EcoTag was replaced. Please scan the newer label on the plant.'
      when 'retired' then
        'This EcoTag is retired and no longer opens a plant profile.'
      else
        'This EcoTag is currently unavailable.'
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
      'message', 'The plant profile linked to this EcoTag is unavailable.'
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

revoke all on function public.guest_view_plant_by_qr(bigint, text)
  from public;
grant execute on function public.guest_view_plant_by_qr(bigint, text)
  to anon, authenticated;

comment on function public.guest_view_plant_by_qr(bigint, text) is
  'Validates a guest visit and returns a curated read-only plant profile for an assigned EcoTag code.';

notify pgrst, 'reload schema';
