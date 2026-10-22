# Modern interface/auth/loading evidence

Local exported WASM passed desktop and DPR3 mobile touch/save checks. A separate native UI test checks 36 layout/modal assertions across narrow mobile, portrait, landscape and desktop. The mobile test explicitly checks canvas view changes for dashboard, phone, wallet and map, rather than relying only on screenshots.

The loading test runs the real engine with a fresh browser context, verifies the gzip engine path and then reloads the same origin. The warm visit makes zero engine/pack network transfers. Read loading-results.json for measured local timings; these are software-rendered Chromium results, not physical Android or mobile-network guarantees. The engine gzip is about 9 MB versus 36 MB raw; do not equate that with a 75% reduction in every user's total load time.

Auth browser tests use controlled protocol fixtures, including a SHA-256 PKCE verifier/challenge check, username selection after authentication, signup/resend callback URLs, disabled Google provider, cancellation/error recovery, forged token rejection and forwarding older landing-page confirmation links. They do not claim a live Google account or email-delivery test.

Google provider setup and an allowed callback URL require owner access in Google/Supabase. The public publishable key cannot configure them. The exact old failing email URL was requested but has not been supplied; its cause is not asserted. No new database migration is required.

Screenshots illustrate the redesigned account page and expanded location sheet in browser emulation. The final HUD uses SVG chevrons in place of the intermediate text-arrow shown in the captured dashboard image.
