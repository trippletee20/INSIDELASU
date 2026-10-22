# Inside LASU

A single-player campus-life game, now prepared as a **desktop browser beta**.
Players use a keyboard and mouse; they do not need Godot or a source ZIP.

**Browser address after deployment:** https://trippletee20.github.io/INSIDELASU/

This is a playable beta, not a content-complete release. Campus activities are
simplified and NPC campus life and richer interior content remain in development.
The game is independent and is not an official university service.

## Publish the browser game

The `Build and publish browser beta` workflow tests the game, builds the site,
uploads a ready-to-host artifact, and deploys it to GitHub Pages.

The repository owner must enable Pages once:

1. Open [Settings → Pages](https://github.com/trippletee20/INSIDELASU/settings/pages).
2. Under **Build and deployment → Source**, choose **GitHub Actions**.
3. If a deployment ran before Pages was enabled, rerun the workflow from the
   [Actions tab](https://github.com/trippletee20/INSIDELASU/actions).

The configured address is not live until deployment succeeds. Do not treat a
successful source push or local export as proof the public game is available.

## Play and save

Create a student, check into the assigned hostel, and press **E** near buildings or
shuttle stands to find activities. **H** opens help, **P** the student profile,
**B** the wallet and receipts, and **M** the map. Click the game for mouse look;
**Esc** releases the mouse or closes a menu.

Progress is stored on the current browser/device. There is no account or cloud
save. Clearing site data removes local progress. All money is fictional.

## Develop

Use official **Godot 4.6.3 stable** and Python 3.11+. The full setup, release
evidence and limitations are in [docs/BROWSER_RELEASE.md](docs/BROWSER_RELEASE.md).

```sh
python3 tools/check_environment.py
python3 tools/build_web.py
python3 tools/test_web.py
```

Export requires the matching single-thread web templates. Browser tests require
Playwright/Chromium. The CI workflow installs and verifies the official toolchain.

The original v0.13 project is tagged `v0.13-baseline`. The campus layout and road
data remain unchanged. See the historical traffic reports under `docs/` for the
earlier fixes and exact regression logs.
