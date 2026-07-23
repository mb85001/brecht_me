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
  -- stable key the DiveScan app can use to upsert without duplicating:
  external_id          text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists dives_user_date_idx on dives (user_id, date desc);
create unique index if not exists dives_user_external_idx
  on dives (user_id, external_id) where external_id is not null;

-- ---------------------------------------------------------------------------
-- Row-Level Security
-- ---------------------------------------------------------------------------
alter table dives enable row level security;

-- Dives: full CRUD, but only your own rows.
drop policy if exists dives_all on dives;
create policy dives_all on dives
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
