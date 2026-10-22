# Modern HUD, lightweight accounts and loading repair

The supplied screenshots show a concrete visual difference: Inside LASU had two large top panels and six outlined touch controls. The reference uses isolated status pills, quiet controls and a location sheet near bottom navigation. This update applies those layout ideas with original Inside LASU styling.

## Interface

- Warm light surfaces, rounded controls, consistent focus states and a shared theme replace the old default dark/grey engine widgets.
- Separate clock and wallet pills leave the top centre open. A small dashboard toggle opens/minimises the location sheet; the bottom dock contains Explore, Map and Phone.
- The location strip opens a sheet with the current site, objective, activities and meters. The game pauses movement while that sheet is open. Short landscape layouts hide extra details.
- The joystick is smaller and translucent. Interact is the primary action, Up jumps and the ellipsis reveals sit/run. Dock touches are excluded from the look gesture.
- Phone/menu controls use the same light theme. Colours and UI are original; no reference-game branding or assets are copied.

## Loading

The official engine is 37,700,666 bytes, before HTTP transport compression. Export now includes a deterministic 9,382,282-byte gzip engine. A narrowly scoped service worker uses the compressed stream on supporting browsers, decompresses it natively and stores the public content-addressed engine and pack. It never caches account requests, tokens or HTML pages. Browsers without this feature fall back to the raw engine.

The loader shows download progress, campus preparation, a slow-connection explanation and retry instructions instead of leaving players staring at an unexplained splash. Engine and game URLs are fingerprinted. The previous published game pack is retained when available so cached launch HTML does not immediately reference a removed asset after an update.

Architecture visuals are constructed one building per web frame, nearest the player first. Existing site metadata/collision bodies are created immediately. This removes the all-buildings-at-once architecture pass from startup; it does not claim lower total scene complexity or a guaranteed physical-phone frame rate.

Local Chromium mobile emulation tests record cold/warm readiness timings and verify zero repeated engine/pack network transfers on the warm visit. These are local software-rendered measurements, not Android device/network guarantees. Do not describe byte reduction as an equivalent reduction in total load time.

## Accounts and confirmations

`auth.html` is an independent lightweight account page. It loads without the game engine. Google/email authentication comes first; an authenticated new user chooses a public username afterward. A taken/invalid username can be retried without creating another Auth account.

`auth/callback.html` handles Google PKCE exchanges, implicit email confirmations and explicit errors. It strips codes/tokens from the URL before network work and validates returned access tokens with Auth. Cancelled, expired or malformed links display recovery instructions rather than a blank callback. Old confirmation links targeting the landing page are forwarded to this handler. New signup/resend requests explicitly request the callback URL.

Tokens live in per-tab sessionStorage and runtime memory, not URLs, localStorage or the local Godot save. Game startup validates/resumes the same-tab account and refreshes sessions through Supabase. Explicit sign-out/deletion clears the handoff. These changes do not synchronise local game saves across devices.

The actual domain/path of the user's failing confirmation page was requested for diagnosis. Without that URL or owner-only Auth settings, the precise cause of the earlier 404/forbidden response is not established. A wrong Site URL, missing allowed redirect, or expired link needs distinct handling; do not claim a local fixture validates the owner's email service.

## Required owner settings

No new SQL migration is required. Keep the existing social schema.

1. Supabase → Authentication → URL Configuration: Site URL `https://trippletee20.github.io/INSIDELASU/`; add exact Redirect URL `https://trippletee20.github.io/INSIDELASU/auth/callback.html`.
2. Google requires a web OAuth client in the owner's Google Cloud project and its client ID/secret stored privately in Supabase's Google provider settings. The provider callback is `https://mwuagoxsbsayftvmyitb.supabase.co/auth/v1/callback`.
3. Google's audience/test-user/publishing settings must allow intended players. The game checks provider availability and explains missing setup instead of pretending Google is live.

The guided owner page is [setup-google.html](https://trippletee20.github.io/INSIDELASU/setup-google.html). No provider secret belongs in the game, repository or chat. The public publishable key cannot change provider settings or redirect allowlists.

## Verification

- Existing engine, mobile, room, economy and server acceptance checks.
- `tools/test_auth_web.py`: real browser with Auth protocol fixtures; Google PKCE verification, username-after-auth, disabled-provider behaviour, signup/resend redirects, callback error handling, forged-token rejection and old landing-link recovery. Does not claim a live Google account test.
- `tools/test_loading_web.py`: actual exported WASM cold/warm starts, compressed network path, cached public engine/pack, working audio worklets and no browser errors.
- Desktop/mobile exported game tests: existing save/economy behaviour, actual touch movement, phone/wallet/map transitions and responsive layouts. Canvas view labels provide accessible context and allow those transitions to be asserted explicitly.
- A live two-account/email/Google test remains necessary after the owner configures the provider and callback allowlist.
