# Supabase setup validation

- 58 checks against real disposable PostgreSQL validate the authoritative migration, repeatable installation, denied raw table access, message isolation, mutual relationship consent, block/unblock, private presence, message limits and deletion.
- 12 assertions use actual Godot HTTP requests against a Supabase protocol fixture. They cover email confirmation, username resolution, access-token refresh, RPC mapping and fail-closed behaviour before schema installation. This does not claim live Supabase Auth sign-up/sign-in testing.
- The setup page copies the exact tested migration, opens the correct new project, handles missing/installed health responses and fits a phone viewport without browser errors.
- Existing gameplay and legacy social checks still pass. The release workflow additionally verifies the configured public project/key from GitHub; local workspace egress returned a proxy tunnel 403 for the Supabase domain.

The owner must install the migration in the new INSIDE LASU project and configure the Auth Site URL. The public publishable key cannot do either administrative action. No real player accounts were created by these tests. Run a live two-account test after installation; do not claim messaging is enabled merely because the key is configured.
