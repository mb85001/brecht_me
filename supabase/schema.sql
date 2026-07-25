-- ============================================================================
-- brecht.me — database schema + Row-Level Security
-- Run this ONCE in your Supabase project:
--   Supabase dashboard -> SQL Editor -> New query -> paste -> Run
--
-- Security model:
--   * `dives` are PRIVATE per user — each user sees only their own rows,
--     enforced by Row-Level Security. The publishable/anon key in the browser
--     cannot bypass these policies.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Dives  (private per user — mirrors the DiveScan app's DiveExportData)
-- ---------------------------------------------------------------------------
create table if not exists dives (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  dive_number          int,
  date                 date,
  entry_at             timestamptz,
  exit_at              timestamptz,
  site_name            text,
  location_detail      text,
  latitude             double precision,
  longitude            double precision,
  buddy                text,
  bottom_time_minutes  int,
  max_depth_meters     double precision,
  start_pressure_bar   double precision,
  end_pressure_bar     double precision,
  tank_size_liters     double precision,
  tank_type            text,
  oxygen_percent       int,
  weights_kg           double precision,
  exposure_suit        text,
  visibility_meters    double precision,
  water_temp_celsius   double precision,
  water_type           text,
  conditions           text,
  notes                text,
  -- Stable key clients upsert on. Defaulted here so rows created by any
  -- client (e.g. the website form) always carry one — the DiveScan app
  -- keys its sync on (user_id, external_id).
  external_id          text not null default gen_random_uuid()::text,
  -- Soft-delete tombstone. A delete sets this instead of removing the row, so
  -- other clients (the DiveScan app) learn about it on their next sync and
  -- remove their local copy. The website hides rows where this is set.
  deleted_at           timestamptz,
  -- Thumbnail references pushed by the app: an array of
  -- {external_id, path, caption}, where `path` points into the private
  -- `dive-photos` storage bucket. The website renders them via signed URLs.
  photos               jsonb not null default '[]'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Migrations for databases created before the columns above existed
-- ---------------------------------------------------------------------------
-- `create table if not exists` above does NOTHING when the table already
-- exists, so columns added later must be applied explicitly. Without this,
-- re-running the script on a live database silently skips them and clients
-- fail with "column dives.photos does not exist".
alter table dives add column if not exists external_id text not null default gen_random_uuid()::text;
alter table dives add column if not exists deleted_at timestamptz;
alter table dives add column if not exists photos jsonb not null default '[]'::jsonb;
-- How the dive is categorized ("wreck", "night", "drift") and what was seen.
-- Arrays of strings, stored as jsonb to match `photos`.
alter table dives add column if not exists tags jsonb not null default '[]'::jsonb;
alter table dives add column if not exists marine_life jsonb not null default '[]'::jsonb;

create index if not exists dives_user_date_idx on dives (user_id, date desc);
create index if not exists dives_user_updated_idx on dives (user_id, updated_at);
-- Upsert key. Dropped and recreated rather than `if not exists`, because an
-- earlier version of this file created it as a PARTIAL index
-- (`where external_id is not null`) and `if not exists` never rewrites an
-- existing index. Postgres cannot infer a partial index for
-- `on conflict (user_id, external_id)` unless the statement repeats the same
-- predicate, so the app's sync upsert fails with 42P10 against the old one.
drop index if exists dives_user_external_idx;
create unique index dives_user_external_idx on dives (user_id, external_id);

-- Keep updated_at honest for every client: bump it on any UPDATE so
-- last-write-wins sync in the app sees web edits as new.
create extension if not exists moddatetime;
drop trigger if exists dives_set_updated_at on dives;
create trigger dives_set_updated_at
  before update on dives
  for each row execute function moddatetime(updated_at);

-- ---------------------------------------------------------------------------
-- Table privileges
-- ---------------------------------------------------------------------------
-- RLS decides *which rows* a role may touch, but Postgres still needs a
-- table-level GRANT for the role to reach the table at all. Without this,
-- inserts fail with "permission denied for table dives" before RLS runs.
grant usage on schema public to authenticated;
grant select, insert, update, delete on table dives to authenticated;

-- ---------------------------------------------------------------------------
-- Row-Level Security
-- ---------------------------------------------------------------------------
alter table dives enable row level security;

-- Dives: full CRUD, but only your own rows.
-- auth.uid() is wrapped in (select ...) so Postgres evaluates it once per
-- query instead of once per row (Supabase linter: auth_rls_initplan).
drop policy if exists dives_all on dives;
create policy dives_all on dives
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Photo thumbnails (private storage bucket)
-- ---------------------------------------------------------------------------
-- The app uploads each dive photo's small thumbnail (~300px JPEG) to
--   dive-photos/{user_id}/{dive_external_id}/{photo_external_id}.jpg
-- and records it in dives.photos. The bucket is PRIVATE: the website reads
-- via short-lived signed URLs, and the folder-prefix policies below keep
-- each user inside their own {user_id}/ folder.
insert into storage.buckets (id, name, public)
values ('dive-photos', 'dive-photos', false)
on conflict (id) do nothing;

drop policy if exists "dive photos read own" on storage.objects;
create policy "dive photos read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'dive-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "dive photos insert own" on storage.objects;
create policy "dive photos insert own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'dive-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "dive photos update own" on storage.objects;
create policy "dive photos update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'dive-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "dive photos delete own" on storage.objects;
create policy "dive photos delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'dive-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- ===========================================================================
-- OPTIONAL — tombstone cleanup (keep this LAST)
-- ===========================================================================
-- Soft-deleted rows are only kept as markers so other clients can learn of the
-- deletion. Once every device has had a chance to sync they're dead weight, so
-- a daily pg_cron job hard-deletes tombstones older than 30 days.
--
-- ⚠️ This block is last on purpose: `create extension pg_cron` fails unless the
-- extension is enabled for the project, and a failing statement aborts the rest
-- of the script. Everything above must already have run. If it errors, enable
-- pg_cron via Database -> Extensions, then re-run just this block — or skip it
-- entirely; tombstones are tiny and sync works fine without the purge.
--
-- Trade-off: a device offline for more than 30 days may miss a tombstone and
-- could re-upload the dive. Raise the interval if a device might be dark longer.
create extension if not exists pg_cron;

-- cron.schedule upserts by job name, so re-running this is safe.
select cron.schedule(
  'purge-deleted-dives',
  '0 3 * * *', -- every day at 03:00 UTC
  $$ delete from dives where deleted_at is not null and deleted_at < now() - interval '30 days' $$
);
