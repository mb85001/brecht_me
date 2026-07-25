# brecht.me

Personal site for **brecht.me** — a public landing page plus a private,
login-protected dive logbook.

- **Frontend:** [Astro](https://astro.build) (static) → **GitHub Pages** (free)
- **Auth + data:** [Supabase](https://supabase.com) (free tier) with Row-Level
  Security
- **App sync:** the `dives` table mirrors the DiveScan iOS app so both can
  share one logbook

## How it fits together

```
Public landing (/)          →  static, no login
Private area (/app/*)       →  client-side gated, redirects to /login
   └─ Dive logs             →  Supabase `dives`  (private per user)
```

GitHub Pages can only serve static files, so there is **no server** here. Login
and data live in Supabase. The Supabase *publishable/anon* key ships to the
browser on purpose — security is enforced by **Row-Level Security** in the
database, not by hiding the key. Never put the `service_role` (secret) key in
this project.

---

## Local development

```bash
npm install
cp .env.example .env      # then fill in your Supabase URL + anon key
npm run dev               # http://localhost:4321
```

---

## One-time setup

### 1. Create the Supabase project
1. Sign up at [supabase.com](https://supabase.com) and create a new project (free tier).
2. In **Project Settings → API**, copy the **Project URL** and the **anon public** key.
3. Put both in your local `.env` (see `.env.example`).

### 2. Create the tables + security policies

The schema lives in `supabase/migrations/` and is applied with the Supabase
CLI, so the database's state is versioned rather than depending on remembering
which script was run.

```bash
brew install supabase/tap/supabase   # once
supabase login                       # once, opens a browser
supabase link --project-ref YOUR-PROJECT-REF
supabase db push                     # applies any unapplied migrations
```

Your project ref is the subdomain of the project URL —
`https://<ref>.supabase.co`.

To change the schema, add a new file to `supabase/migrations/` (name it
`<YYYYMMDDHHMMSS>_what_changed.sql`) and run `supabase db push` again. Migrations
are written idempotently (`if not exists`, `drop … if exists`) so re-running is
harmless.

`supabase/optional/tombstone-cleanup.sql` is deliberately *not* a migration: it
needs the `pg_cron` extension enabled for the project, and a failing statement
would abort an entire migration run. Run it by hand in the SQL Editor if you
want the daily purge of soft-deleted rows.

### 3. Auth settings — invite only

This site is **sign-in only**. There is no sign-up form, and accounts are
created by hand. Two things make that real:

1. **Disable sign-ups server-side (required).** Removing the UI button is not
   enough — anyone holding the publishable key could still call the sign-up
   endpoint directly. In Supabase go to
   **Authentication → Sign In / Providers → Email** and turn **off**
   *Allow new users to sign up*.
2. **Turn off email confirmation** (optional, convenient) under the same Email
   provider settings, so accounts you create can log in immediately.

### Creating an account for someone

When you get a request (the login page has a "Request an account" mail link):

1. Supabase dashboard → **Authentication → Users** → **Add user**.
2. Choose **Create new user**, enter their email and a password, and tick
   *Auto Confirm User* so they can sign in right away.
3. Send them the password and ask them to change it later.

This cannot be done from the website itself: creating users requires the
`service_role` secret key, which must never be shipped to a browser.

### 4. GitHub repo + Pages
1. Create a GitHub repo and push this folder to `main`.
2. In the repo: **Settings → Secrets and variables → Actions → New repository secret**, add:
   - `PUBLIC_SUPABASE_URL`
   - `PUBLIC_SUPABASE_ANON_KEY`
3. **Settings → Pages → Build and deployment → Source: GitHub Actions**.
4. Push to `main` — the workflow in `.github/workflows/deploy.yml` builds and deploys automatically.

### 5. Custom domain (brecht.me)
1. The `public/CNAME` file already pins the site to `brecht.me`.
2. At your DNS/registrar, add for the apex domain:
   - Four `A` records → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - (optional `www`) a `CNAME` → `<your-github-username>.github.io`
3. In **Settings → Pages**, set the custom domain to `brecht.me` and enable **Enforce HTTPS**.

---

## The DiveScan app

The iOS app syncs against this same `dives` table, upserting on
`(user_id, external_id)`. Dives, edits and deletions flow both ways; photo
thumbnails go app → website into the private `dive-photos` bucket and are shown
here via signed URLs.

## Project structure

```
src/
  layouts/   BaseLayout (theme + reveal), AppLayout (auth-gated shell)
  pages/
    index.astro        public landing one-pager
    login.astro        email + password sign in
    app/               private area (auth required)
      index.astro      overview
      dives.astro      dive logbook
  lib/supabase.ts      client + requireSession() route guard
  styles/global.css    design tokens
supabase/migrations/   schema, applied with `supabase db push`
```
