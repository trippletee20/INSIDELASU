> Updated account flow: [modern UI and account changes](MODERN_UI_AND_AUTH.md). New users sign in on `auth.html`, then choose their username. Add `https://trippletee20.github.io/INSIDELASU/auth/callback.html` to Supabase Redirect URLs. [Google provider setup](https://trippletee20.github.io/INSIDELASU/setup-google.html) requires the owner's private provider configuration. No new database migration is needed.

# Free social hosting with Supabase

The selected deployment is now the owner's new **INSIDE LASU** Supabase Free project. The older Base44 project is unrelated and must not be modified. The game stays on GitHub Pages; no Render service, card or separate Python hosting is needed for this path.

## Owner setup

Open [the guided setup page](https://trippletee20.github.io/INSIDELASU/setup-social.html). Copy the SQL, open the linked **INSIDE LASU** SQL Editor, paste and Run. The authoritative migration is `supabase/migrations/001_campus_social.sql`. It is repeatable and creates a dedicated `inside_lasu` schema plus `public.lasu_api` and `public.lasu_health`; it does not reset the project or touch other apps' tables.

Then open Authentication → URL Configuration and set Site URL to `https://trippletee20.github.io/INSIDELASU/`. Leave email confirmation enabled. This prevents confirmation emails redirecting to localhost. Keep the project on Free. If the dashboard asks for a paid upgrade, stop and check the selected plan/project.

The supplied `sb_publishable_…` key is intentionally public in the browser. It cannot install schemas or act as an administrator. Never supply the database password, secret API key, service_role key or management access token in the chat or game. The project owner must run the SQL through the dashboard because the public key cannot do that.

## Player sign-in

Players create a social account with a real email, a new password (at least 10 characters) and a unique public username. They confirm their email, then sign in with email/password. Existing usernames cannot be reassigned by changing the login field. Other players search public usernames; emails never appear in the game directory or presence feed.

Supabase Auth handles credentials and email confirmation. Access and refresh tokens stay only in memory; the game refreshes expiring sessions and signs out on page reload. Local game money/profile/room progress stays in the existing device save, separately from the shared social account. Password recovery UI is not implemented in this beta; do not promise cross-device game-save syncing or recovery through the phone yet.

The client checks the schema-version health RPC before creating an account or signing in. Missing setup produces a clear pending-setup message while local gameplay remains available. The setup page's Check connection verifies only installation/version, not a full two-player test.

## Database access and moderation

All six social tables have row-level security enabled with no public/client table policies, and raw schema/table/sequence privileges are revoked from `anon` and `authenticated`. The only social data API is an explicitly granted SECURITY DEFINER RPC with an empty search path. It checks the caller's Supabase identity, derives senders from that identity, limits data to relevant participants, validates payloads, enforces rate limits and relationship consent, and excludes blocked users/private-room presence. No privileged key is shipped.

Account deletion removes the caller's Auth user and cascades through only their dedicated social rows. Sign-out deletes visible presence. Polling removes old presence rows. Messages are stored in the database and are not end-to-end encrypted. Operators can inspect `inside_lasu.reports` in the owner's SQL Editor and moderate as needed; do not grant browser clients access to reports.

Example owner-only report query:

```sql
select r.id, reporter.username as reporter, reported.username as reported, r.reason, r.created
from inside_lasu.reports r
join inside_lasu.profiles reporter on reporter.id=r.owner
join inside_lasu.profiles reported on reported.id=r.target
order by r.id desc limit 100;
```

Free has changing storage, Auth email and API/egress quotas, and inactive projects may pause. Review current limits in the dashboard and maintain backups. No automatic upgrades are configured here. Before a broad launch, complete two-account live testing, establish moderation/privacy support, configure adequate Auth email delivery and assess load. Presence remains a polling beta with client-reported positions and simple avatars; shared physics, game-economy authority and full multiplayer simulation are not implemented.

## Validation

- `python3 tools/test_supabase_database.py`: real disposable PostgreSQL; repeatable migration, revoked direct access, private conversations, relationship consent, blocks, private presence, limits and account deletion.
- `python3 tools/test_supabase_client.py`: actual Godot HTTP client against a protocol fixture; confirmation flow, login/profile, refresh, RPC mapping, logout and absent-schema gate. This fixture does not claim to test the live Supabase Auth service.
- `python3 tools/check_supabase_connection.py`: read-only live public-key/project check; never creates users. CI can run this when workspace egress cannot reach the project.
- Existing engine, legacy server and desktop/mobile browser checks remain in the release workflow.

The previous `server/` Python implementation and `render.yaml` are retained for compatibility/tests and are optional paid-hosting alternatives, not the selected setup. Their credentials/accounts are not migrated into Supabase.
