// @ts-check
import { defineConfig } from 'astro/config';

// brecht.me is served from the apex domain, so no `base` path is needed.
// Output is fully static — perfect for GitHub Pages. All private/auth logic
// runs client-side against Supabase, with security enforced by Row-Level
// Security in the database (never trust the browser).
export default defineConfig({
  site: 'https://brecht.me',
  output: 'static',
  trailingSlash: 'ignore',
});
