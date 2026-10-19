begin;

-- Restore the existing QR only after the admin confirms the physical label.
create or replace function public.college_admin_confirm_qr_reprinted(
  p_session_token text,
  p_qr_tag_id integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  actor public.users%rowtype;
  target public.qr_tag%rowtype;
  restored_status text;
begin
  actor := public.require_app_session(p_session_token);
  if actor.role <> 'college_admin' then
    raise exception 'College Admin access required';
  end if;

  select q.* into target from public.qr_tag q
  where q.qr_tag_id = p_qr_tag_id
    and q.campus_id = actor.campus_id
    and q.college_id = actor.college_id
  for update;
  if not found then raise exception 'QR tag not found in your college'; end if;
  if target.lifecycle_status <> 'damaged' then
    raise exception 'Only a damaged QR label can be restored after reprinting';
  end if;

  restored_status := case when target.assigned_plant_id is not null or exists (
    select 1 from public.plant p
    where p.qr_tag_id = p_qr_tag_id and p.archived_at is null
  ) then 'assigned' else 'available' end;

  perform public.college_admin_set_qr_status(
    p_session_token, p_qr_tag_id, restored_status,
    'Same QR code reprinted; admin confirmed the label is ready and attached.'
  );
end;
$$;

revoke all on function public.college_admin_confirm_qr_reprinted(text, integer) from public;
grant execute on function public.college_admin_confirm_qr_reprinted(text, integer) to anon, authenticated;

commit;
