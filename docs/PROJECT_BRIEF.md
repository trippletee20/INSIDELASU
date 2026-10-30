# Inside LASU — project brief

Inside LASU is an independent, single-player campus-life browser beta for Lagos State University students, with an optional social layer. It targets mobile and desktop browsers, including mid-range Android phones on limited data. It is not an official university service or a content-complete simulation.

## Architecture

- `project.godot` starts `scenes/main.tscn`. `scripts/main.gd` coordinates world construction, student progression, interaction, UI and save state. Builder scripts create campus geometry from JSON; campus layout and road data are protected inputs.
- `player_controller.gd` and `mobile_controls.gd` handle desktop and touch input. Godot uses the GL Compatibility renderer, CSS-pixel web canvas sizing and a single-thread export pinned to 4.6.3 stable.
- `interior_builder.gd`, `interior_identity.gd` and `campus_rooms.gd` provide themed interiors and named rooms. Only the active interior is instantiated. Building experiences and task catalogues supply short decision activities.
- `transit_manager.gd` manages five shuttle services and passenger views. Arcade traffic is the default: vehicles may overlap instead of blocking each other. Historical blocking/reservation logic remains tested separately.
- `save_store.gd` manages schema-2 local saves at `user://inside_lasu_save.json`, with migration, atomic replacement, backup recovery and newer-version overwrite protection. Browser storage is device/origin-local; account sign-in does not synchronise saves.
- Student UI and phone scripts expose notes, planner, profile, wallet, activities and social entry points. All wallet money is fictional and never withdrawable.
- `supabase_social.gd` and `campus_social.gd` provide optional account/social access using `data/social_config.json`. Supabase Auth and SQL rules support identity, messaging, relationships, blocking/reporting and polled presence. The Python server is an alternative implementation and local regression target, not a required paid host.
- `web/` contains the landing page, lightweight account/callback pages, loading shell, public runtime cache and advertising preview. Auth tokens use per-tab sessionStorage/runtime memory; they are separate from game saves. Google authentication requires owner configuration.
- `tools/build_web.py` exports to `build/web/`, fingerprints engine/pack URLs, creates a gzip engine, copies static pages and optionally retains the previous hosted pack. Supported browsers cache public runtime assets; fallback loading remains available.
- `.github/workflows/browser-release.yml` installs the pinned tools, runs engine/backend/browser acceptance, uploads evidence and deploys the tested site to GitHub Pages.

The shared interface uses `ui/campus_theme.tres`, populated by `scripts/ui_theme.gd`. Additive local-save preferences drive appearance and device Settings; `world_labels.gd` renders distance-limited rounded sign cards. See [UI theme and Settings](UI_THEME_AND_SETTINGS.md).

## Folder map

| Path | Purpose |
| --- | --- |
| `README.md` | Main entry point, play links and quick development commands |
| `project.godot`, `export_presets.cfg`, `.godot-version` | Engine, export and version configuration |
| `scenes/` | Godot scene entry point |
| `scripts/` | Gameplay, builders, controls, UI, persistence and social clients |
| `data/` | Campus/road topology, content catalogues and public social configuration |
| `assets/` | Fonts, phone icons and campus map references |
| `ui/` | Shared Godot Theme resource |
| `web/` | Static browser site, auth, loading/cache and preview assets |
| `supabase/migrations/` | Social database schema, functions and access rules |
| `server/` | Alternative Python social service, container and tests |
| `tools/` | Toolchain installer, exporter, validators and acceptance tests |
| `.github/workflows/` | Build/test and Pages deployment workflow |
| `docs/` | Current guides, design notes and historical validation evidence |
| `docs/archive/` | Unedited historical root audits, release notes, changelogs, locks and READMEs |
| `build/`, `test-results/`, `.godot/` | Generated output/cache; ignored by Git |

`ECONOMY_AND_HOSTEL_RULES_v0.8.txt` remains at the root; it is a rules document, outside the requested archive categories. Evidence READMEs under `docs/validation/` remain with their evidence. The root has one README.

## Build and test

Run from the repository root on Linux with Python 3.11+, official Godot 4.6.3 stable and matching web templates. Docker is required for the database/container CI checks. These commands install the same pinned browser dependency used by CI:

```sh
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
python3 tools/install_web_toolchain.py --downloads /tmp/inside-lasu-downloads --bin /tmp/inside-lasu-bin
export PATH="/tmp/inside-lasu-bin:$PATH"
python3 -m venv /tmp/inside-lasu-browser-venv
. /tmp/inside-lasu-browser-venv/bin/activate
python -m pip install playwright==1.58.0
python -m playwright install --with-deps chromium
python tools/check_environment.py
python tools/test_supabase_database.py
python tools/check_supabase_connection.py
docker build -t inside-lasu-social:beta server
python tools/test_social_container.py
python tools/build_web.py
python tools/test_auth_web.py
python tools/test_loading_web.py
python tools/test_web.py
python tools/test_mobile_web.py
python tools/test_supabase_setup.py
python tools/test_advertising_preview.py
```

The installer verifies pinned SHA512 checksums. The complete upstream template archive is large (about 1.3 GB); only the needed web templates are installed. Serve `build/web/` over HTTP, for example `python -m http.server 8000 --directory build/web`, then visit `/play/index.html`. Do not open the exported HTML with `file://`.

Both `tools/test_web.py` and `tools/test_mobile_web.py` are mandatory for every change. They start their own local servers and test the exported WASM, including local-save reload. `INSIDE_LASU_TEST_URL` can target a hosted site, but testing the old deployment does not validate a changed local build. Fresh test output goes into ignored `test-results/`.

Push to `main` or use workflow dispatch to run GitHub Actions. Pages must use GitHub Actions as its source. A local pass does not prove a new remote workflow/deployment passed; inspect the run for the exact pushed commit. Networked Supabase checks also depend on the configured service and schema.

## Constraints and known limitations

- Preserve campus layout and road data. Preserve saves and migrate future schema changes forward. The documentation reorganisation did not change gameplay. The later UI/Settings update adds preferences to existing schema-2 saves and leaves campus/road data, assets and export settings unchanged.
- Use free-tier hosting/services only; any future payment gateway fees are the sole permitted exception. Never put secret/service-role keys in the client.
- Target 30+ FPS on a mid-range Android phone. Chromium software-WebGL/mobile emulation tests do not certify physical-device FPS, memory usage or mobile-data loading time.
- Do not increase first-load download size without approval. Documentation is excluded by the existing export configuration and is not copied into the static site by the build script. Measure exported bytes when runtime assets change; historical size/timing figures are not current guarantees.
- Clearing browser site data removes local progress. There is no cross-device cloud save.
- Interiors are stylised, reused kits; activities are short decisions, not full classes/jobs. Service NPCs are scripted. Rich autonomous campus life remains partial.
- Social presence is polling-based, client-reported and may jump between samples. There is no authoritative shared physics, synchronised economy or group quest state. Private-room presence is excluded; messages are not end-to-end encrypted.
- Live social availability, email delivery and Google login depend on owner-managed schema/provider/redirect settings. Local fixtures do not prove these services work live. Production load testing, moderation operations and account recovery/support still need operational verification.
- Advertising provides a local artwork preview only. Bookings and Paystack/Flutterwave payments are disabled.
- `tools/validate_v013.py` is a legacy static validator requiring an external v0.12 ZIP at `/mnt/data/Inside_LASU_v0.12_Wider_Roads_Interiors_Styled_UI_Godot.zip`. It is not the current CI acceptance runner; its report now writes into `docs/archive/`.

## Reading order and evidence

Read [README](../README.md), [campus ecosystem](CAMPUS_ECOSYSTEM.md), [mobile expansion](MOBILE_EXPANSION.md), [browser release](BROWSER_RELEASE.md), then [modern UI and auth](MODERN_UI_AND_AUTH.md) and [social hosting](SOCIAL_HOSTING.md). Older browser-release statements about absent accounts/service workers describe an earlier milestone; the modern UI/auth guide describes the later implementation.

The newest file named `RELEASE_AUDIT` in the supplied ZIP is [v0.13](archive/RELEASE_AUDIT_v0.13.txt); it explicitly records static checks only. Existing `docs/validation/` logs are historical evidence, not proof that this revision passes. Use fresh test output and the matching GitHub Actions run for release acceptance.

## Performance

See [performance measurement and optimisation](PERFORMANCE.md) for the repeatable mobile browser profile, compression, batching/LOD, automatic quality and the distinction between emulated and physical-device budgets.
