-- ============================================================================
-- Migration: fix RLS initplan re-evaluation on `dives_all`.
-- Run ONCE in the Supabase SQL Editor. Idempotent — running it twice is
-- harmless (drop-then-recreate).
--
-- The Supabase performance linter (auth_rls_initplan) flagged that
-- `dives_all` calls auth.uid() directly, so Postgres re-evaluates it for
-- every row scanned instead of once per query. Wrapping the call as
-- `(select auth.uid())` lets Postgres treat it as a stable subquery and
-- evaluate it once. Behavior is unchanged — only the query plan improves.
-- See: https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan
-- ============================================================================

drop policy if exists dives_all on dives;
create policy dives_all on dives
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
