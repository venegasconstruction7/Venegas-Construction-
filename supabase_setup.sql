-- Venegas Construction Cloud Time Clock
-- Run once in Supabase SQL Editor.
-- IMPORTANT: replace OWNER_EMAIL_HERE at the bottom before running the final INSERT.

create extension if not exists pgcrypto;

create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  worker_name text not null check (char_length(worker_name) between 1 and 100),
  clock_in timestamptz not null default now(),
  clock_out timestamptz,
  created_at timestamptz not null default now(),
  constraint valid_clock_order check (clock_out is null or clock_out >= clock_in)
);

create table if not exists public.job_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  time_entry_id uuid not null references public.time_entries(id) on delete cascade,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.owners (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create unique index if not exists one_open_shift_per_user
on public.time_entries(user_id)
where clock_out is null;

create index if not exists idx_time_entries_worker_name on public.time_entries(worker_name);
create index if not exists idx_time_entries_user_id on public.time_entries(user_id);
create index if not exists idx_job_photos_entry on public.job_photos(time_entry_id);

alter table public.time_entries enable row level security;
alter table public.job_photos enable row level security;
alter table public.owners enable row level security;

-- Owner helper: an owner is a user whose uid exists in public.owners.
-- Owners can only read their own owner row.
drop policy if exists "owners_read_self" on public.owners;
create policy "owners_read_self"
on public.owners for select
to authenticated
using ((select auth.uid()) = user_id);

-- Workers: can insert/read/update only their own time entries.
drop policy if exists "time_read_own_or_owner" on public.time_entries;
create policy "time_read_own_or_owner"
on public.time_entries for select
to authenticated
using (
  (select auth.uid()) = user_id
  or exists (select 1 from public.owners o where o.user_id = (select auth.uid()))
);

drop policy if exists "time_insert_own" on public.time_entries;
create policy "time_insert_own"
on public.time_entries for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "time_update_own" on public.time_entries;
create policy "time_update_own"
on public.time_entries for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- Photo metadata: worker can insert their own row; only owner can read photo metadata.
drop policy if exists "photos_insert_own" on public.job_photos;
create policy "photos_insert_own"
on public.job_photos for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "photos_owner_read" on public.job_photos;
create policy "photos_owner_read"
on public.job_photos for select
to authenticated
using (exists (select 1 from public.owners o where o.user_id = (select auth.uid())));

-- Private storage bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'jobsite-photos',
  'jobsite-photos',
  false,
  10485760,
  array['image/jpeg','image/png','image/webp','image/heic','image/heif']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Worker may upload only inside a folder beginning with their own uid.
drop policy if exists "storage_worker_upload_own_folder" on storage.objects;
create policy "storage_worker_upload_own_folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'jobsite-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Only owners can read/download jobsite photos.
drop policy if exists "storage_owner_read_all" on storage.objects;
create policy "storage_owner_read_all"
on storage.objects for select
to authenticated
using (
  bucket_id = 'jobsite-photos'
  and exists (select 1 from public.owners o where o.user_id = (select auth.uid()))
);

grant usage on schema public to authenticated;
grant select, insert, update on public.time_entries to authenticated;
grant select, insert on public.job_photos to authenticated;
grant select on public.owners to authenticated;

-- After you create the owner's email/password account in Supabase Auth,
-- replace OWNER_EMAIL_HERE and run this one statement separately:
--
-- insert into public.owners(user_id)
-- select id from auth.users where email = 'OWNER_EMAIL_HERE'
-- on conflict (user_id) do nothing;
