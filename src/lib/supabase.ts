import { createClient } from '@supabase/supabase-js';

// These are injected at build time from your `.env` (see .env.example).
// Both values are PUBLIC by design — the anon key is meant to be shipped to
// the browser. Actual access control is enforced server-side by Row-Level
// Security policies (see supabase/schema.sql).
const url = import.meta.env.PUBLIC_SUPABASE_URL;
const anonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  // Helpful during local setup — fails loudly instead of a cryptic 401 later.
  console.warn(
    '[supabase] Missing PUBLIC_SUPABASE_URL / PUBLIC_SUPABASE_ANON_KEY. ' +
      'Copy .env.example to .env and fill them in.'
  );
}

// Fall back to a syntactically valid placeholder when unconfigured, so the
// client constructs without throwing. Any call then fails/returns no session
// and the route guard sends the visitor to /login — a graceful degrade instead
// of a hard crash that would leave the page stuck on its loading spinner.
export const supabase = createClient(
  url || 'https://placeholder.supabase.co',
  anonKey || 'placeholder-anon-key',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  }
);

/**
 * Client-side route guard. Redirects to /login if there's no session.
 * NOTE: this is UX only — it hides the page from a logged-out visitor.
 * The real protection is RLS in the database; even if someone forced their
 * way onto this page, they could not read another user's rows.
 */
export async function requireSession() {
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session) {
    const next = encodeURIComponent(location.pathname);
    location.replace(`/login?next=${next}`);
    return null;
  }
  return session;
}
