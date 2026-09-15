# Flowbit

A Scratch-like, wire-based visual programming tool. Single-page frontend, backed by
a real database and real user accounts via Supabase — no server for you to run.

## Files

```
index.html    The entire app (frontend) — upload this to GitHub Pages as before.
schema.sql    One-time database setup — paste into Supabase's SQL Editor and run it once.
README.md     This file.
```

That's it. There is no separate "backend folder" — the backend is Supabase itself
(a hosted Postgres database + auth service), and `index.html` talks to it directly
over HTTPS using Supabase's JavaScript client, loaded from a CDN at the top of the
file. This is why there's no server for you to deploy, restart, or pay to keep alive.

## One-time setup (about 5 minutes)

1. Go to [supabase.com](https://supabase.com), sign up free, and create a new project.
2. In your new project, open **SQL Editor → New query**, paste the entire contents
   of `schema.sql`, and click **Run**. This creates the `projects` table and its
   security rules. You will not need to touch SQL again after this.
3. In your project's **Settings → API** page, copy two values:
   - **Project URL**
   - **anon public key** (NOT the `service_role` key — that one is secret and must
     never appear in a file you upload publicly)
4. Open `index.html`, find this block near the top of the `<script>` section:
   ```js
   const SUPABASE_URL = 'PASTE_YOUR_SUPABASE_URL_HERE';
   const SUPABASE_ANON_KEY = 'PASTE_YOUR_SUPABASE_ANON_KEY_HERE';
   ```
   and paste your two values in.
5. Upload `index.html` to GitHub Pages exactly as you have been. Done — accounts,
   cloud save, and sharing are now live.

If you skip this setup, the app still works fully offline (local browser save/load/
export/import, same as before) — it just shows a message that accounts aren't
configured yet, instead of crashing.

## Plain-language architecture

```
Browser (your GitHub Pages site)
   │
   │  HTTPS, via the Supabase JS client
   ▼
Supabase (hosted for you)
   ├── Postgres database  → your "projects" table
   └── Auth service       → signup / login / sessions / password-reset emails
```

There is no code of yours running on a server. When someone clicks "Sign Up," the
browser calls Supabase's Auth API directly; Supabase hashes and stores the password
and manages the session. When someone clicks "Cloud Save," the browser sends the
project JSON straight to your `projects` table. **Row Level Security** — rules
attached to the database table itself (see `schema.sql`) — is what stops one user
from reading or overwriting another user's projects. This is why it's safe to call
the database directly from client-side JavaScript: the enforcement lives in the
database, not in trust-the-client-side-code.

Sharing works through two narrow database functions (also in `schema.sql`) rather
than a general "anyone can read" rule — a stranger with a share link can fetch
*that one project*, and only if its owner has explicitly marked it shareable.
Nothing else in the table is exposed to them.

## What changed this pass (block editor)

- Division/modulo by zero, and invalid Math Function results (e.g. `sqrt` of a
  negative number), now log a clear error and flag the node instead of silently
  producing a wrong number.
- List operations report a specific "index out of range" error instead of quietly
  doing nothing.
- Loop safety-limit messages now explain what condition never became true.
- Any node with a required field left blank (a variable/list/message/key name, or
  a "Set `<result>`" field) shows a small red indicator and tooltip, checked live
  and swept again right before Run.
- Dragging a wire now snaps to the nearest input port within ~30px.

## Checklist before this is genuinely safe for real users

- [ ] **Custom domain.** GitHub Pages supports one for free (repo Settings → Pages
      → Custom domain) — HTTPS is issued automatically once it's set.
- [ ] **Confirm Supabase auth email settings.** The free tier's built-in email
      sender is rate-limited and best for early traffic, not high volume — if you
      grow, connect your own SMTP provider under Supabase's Auth settings.
- [ ] **Backups.** Supabase's free tier does not include automatic point-in-time
      backups — if that matters to you, either upgrade your Supabase plan or
      periodically export your `projects` table yourself.
- [ ] **Rate limiting / abuse protection.** Supabase applies some default limits,
      but review Auth → Rate Limits before opening this up publicly, especially
      sign-ups and the share-link functions.
- [ ] **Terms/Privacy pages**, since you're now storing real user emails and data
      (you mentioned this as a launch requirement previously — still applies).
- [ ] **Monitoring.** At minimum, check Supabase's dashboard logs periodically;
      there's no alerting configured here.
- [ ] **Real-device test pass** for the mobile/touch work from the previous round —
      still hasn't been verified on an actual phone.
