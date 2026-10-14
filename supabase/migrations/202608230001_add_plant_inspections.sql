-- The existing backend table is public.inspection.
alter table public.inspection
  add column if not exists observation text;

create index if not exists inspection_plant_date_idx
  on public.inspection (plant_id, inspected_at desc);

insert into storage.buckets (id, name, public)
values ('plant-images', 'plant-images', true)
on conflict (id) do update set public = true;

alter table public.inspection enable row level security;
drop policy if exists "plant inspections readable" on public.inspection;
create policy "plant inspections readable" on public.inspection for select using (true);
drop policy if exists "plant inspections insertable" on public.inspection;
create policy "plant inspections insertable" on public.inspection for insert with check (true);

drop policy if exists "plant images readable" on storage.objects;
create policy "plant images readable" on storage.objects for select using (bucket_id = 'plant-images');
drop policy if exists "plant images uploadable" on storage.objects;
create policy "plant images uploadable" on storage.objects for insert with check (bucket_id = 'plant-images');
