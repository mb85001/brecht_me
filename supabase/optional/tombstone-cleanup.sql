-- Run by hand in the SQL Editor if you want the daily purge.
-- Deliberately NOT a migration: `create extension pg_cron` fails unless the
-- extension is enabled for the project, and a failing statement aborts an
-- entire migration run.

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
