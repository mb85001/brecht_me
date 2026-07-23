-- ============================================================================
-- Migration: prepare the live `dives` table for DiveScan app sync.
-- Run ONCE in the Supabase SQL Editor if you created the table before this
-- date. Idempotent — running it twice is harmless.
--
-- 1. Every row gets a stable external_id (the app's upsert key).
-- 2. updated_at is bumped automatically on UPDATE, so edits made on the
--    website are seen as "newer" by the app's last-write-wins merge.
-- ============================================================================

-- Backfill rows created before external_id had a default.
update dives set external_id = gen_random_uuid()::text where external_id is null;

alter table dives alter column external_id set default gen_random_uuid()::text;
alter table dives alter column external_id set not null;

-- Rebuild the unique index without the now-unnecessary null filter.
drop index if exists dives_user_external_idx;
create unique index if not exists dives_user_external_idx
  on dives (user_id, external_id);

-- Auto-bump updated_at on any UPDATE.
create extension if not exists moddatetime;
drop trigger if exists dives_set_updated_at on dives;
create trigger dives_set_updated_at
  before update on dives
  for each row execute function moddatetime(updated_at);
