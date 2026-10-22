# Browser beta release

The selected release target is a desktop web browser with keyboard and mouse.
This milestone produces a hosted-game artifact, not another source-only ZIP.

## Implemented

- Pinned, single-thread Godot 4.6.3 web export. It does not require special
  cross-origin-isolation headers or a service worker, so standard GitHub Pages works.
- A public landing page with a clear play link, controls, local-save/privacy notes,
  beta limitations, issue reporting and engine/font licence notices.
- Compact student/location/objective HUD and expandable profile, wallet and help.
  Menus remain usable at 800×600, 1280×720 and 1920×1080. Adaptive layout replaces
  the former fixed-position wallet. Native-pixel UI avoids letterboxing tiny text.
- Timestamped, searchable transaction receipts for daily support, fares, activities,
  earnings and room furniture. Current balance and recorded daily income/spending
  are separate from full student statistics. The most recent 500 receipts are kept;
  all-time earned/spent totals continue to persist.
- Future daily support is bounded to NGN 500–1,500 once per real-world date. Existing
  balances, previously claimed rewards and starting-background values are retained.
- Save schema 2 migration, atomic writes, last-valid backup recovery, preservation
  of unreadable originals and refusal to overwrite newer-version files. Old profiles,
  wallet totals, hostel rooms, furniture, skills, privacy and rest cooldowns are retained.
  Legacy receipts are not invented. Unknown save fields survive resaving.
- Browser pointer capture waits for a player gesture; a click captures the mouse
  after returning to an existing save. Noto Sans supplies a readable naira glyph.
- Browser drawing uses a shorter walking-camera range and no dynamic sun shadows.
  Traffic clearance reuses only exact positions within one physics tick; no geometric
  quantisation, changed lane width or road data is involved.
- A GitHub Actions pipeline verifies the toolchain, runs acceptance checks, exports,
  browser-tests, retains evidence and publishes the ready-to-host artifact to Pages.

The existing campus/road/interior data and remaining builders are still checked
against the original baseline. Main UI, player pointer-capture/camera code and the
project's UI stretch setting are intentionally changed and now have gameplay/browser
acceptance tests rather than an inappropriate whole-file immutability assertion.

## Executed acceptance

- **139 engine checks passed:** 50 gameplay/save/UI checks plus the previous 89
  traffic/reservation/long-run checks.
- Headless editor import, 336-segment road audit, normal/diagnostic scene startup,
  and all-five-shuttle telemetry passed with no unexpected errors or warnings.
- Chromium loaded the actual exported WebAssembly game, created a student through
  the UI, claimed daily support, displayed receipts, navigated menus, reloaded the
  same IndexedDB profile/wallet/receipts and resized to 800×600. No runtime errors.
- Screenshots cover landing, new profile, wallet, help, student profile, returning
  player and small-window layout. Test data is fictional and browser-isolated.
- Official engine and template archives were verified against Godot's published
  SHA512 checksums. The installer pins those checksums and retains TLS verification.

Logs/results/screenshots for this milestone are under `docs/validation/browser/`.
Fresh validation writes ignored `test-results/`; `.gdignore` prevents generated
screenshots/builds from being imported back into the game.

The browser test uses software WebGL in Chromium. It validates functionality, not
hardware performance on every player's device. Firefox, Safari, touch controls,
Windows native export, controller-only use and public-server execution are not
represented as tested by these local checks.

## Reproduce the web build

The cloud base already supplies Godot; matching web templates are installed under
`/workspace/.inside-lasu/data/godot/export_templates/4.6.3.stable/`.

For a fresh Linux machine, set `XDG_DATA_HOME` to a writable persistent directory,
then run:

```sh
python3 tools/install_web_toolchain.py --downloads /tmp/inside-lasu-downloads --bin /tmp/inside-lasu-bin
export PATH="/tmp/inside-lasu-bin:$PATH"
python3 tools/check_environment.py
python3 tools/build_web.py
```

The toolchain download includes Godot's complete template archive (about 1.3 GB);
only the required web templates are installed. The resulting site is roughly 40 MB.
The build output is `build/web/`, with its game at `play/index.html`. It must be
served over HTTP(S), not opened as a local file.

For browser acceptance, install Playwright 1.58.0 and its Chromium browser, then
run `python3 tools/test_web.py`. This starts and stops its own internal test server.

## Publication and remaining work

The intended public address is `https://trippletee20.github.io/INSIDELASU/`.
It was returning HTTP 404 before deployment. The cloud's GitHub settings API
returns Forbidden, so it cannot enable Pages on the owner's behalf. The owner must
choose **GitHub Actions** at the repository's **Settings → Pages → Source** once.
The workflow can then publish without an additional secret or real-money service.

A successful source push, saved cloud draft or exported site is not publication.
Verify the public landing, game HTML, WASM and pack responses and a real hosted
session after the Pages deployment succeeds. Rerun the workflow if it failed before
Pages was enabled. Do not expose a private repository merely to work around hosting.

This beta is not the entire content-complete launch described in the design brief.
NPC roles/schedules/navigation, expanded archetype interiors, continuous stairs,
broader content/progression balance and device performance acceptance remain later
milestones. Existing simplified activities and current interiors are described as
such on the public page. There is no multiplayer, account service or cloud save.

For future cloud sessions, review/save the updated environment configuration and
publish the prepared environment snapshot. That is separate from publishing the
game on GitHub Pages.
