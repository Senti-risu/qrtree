-- Use CSU as the prefix for newly generated QR tag codes. Existing codes
-- remain unchanged so already printed labels continue to resolve.
begin;

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
      'format', 'CSU-YYYYMM-NNNNNN',
      'number_scope', 'global'
    )
  );
end;
$$;

commit;
