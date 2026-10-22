## Campus ecosystem update

[Play the browser beta](https://trippletee20.github.io/INSIDELASU/play/index.html?v=campus-phone-v016) · [Phone, rooms and NPC features](docs/CAMPUS_ECOSYSTEM.md) · [Enable real-player messaging](docs/SOCIAL_HOSTING.md)

The Phone button opens 16 campus apps. Expand/Hide controls the HUD. Nearby location actions expose entrances, rooms and tasks. Social server code and a persistent hosting Blueprint are included; messaging stays explicitly offline until a server URL is connected.

# Inside LASU

A single-player campus-life game, now live as a **mobile and desktop browser beta**.
Phones use a thumbstick, swipe look and touch buttons. Desktop players can use a keyboard and mouse. No Godot installation or source ZIP is needed.

**[Play Inside LASU in your browser](https://trippletee20.github.io/INSIDELASU/)**

This is a playable beta, not a content-complete release. Campus activities are
simplified and NPC campus life and richer interior content remain in development.
The game is independent and is not an official university service.

## Release updates

The `Build and publish browser beta` workflow tests the game, builds the site,
uploads a ready-to-host artifact, and deploys it to GitHub Pages.

Pages is configured and the first deployment succeeded. For a new repository or fork, the owner enables hosting once:

1. Open [Settings → Pages](https://github.com/trippletee20/INSIDELASU/settings/pages).
2. Under **Build and deployment → Source**, choose **GitHub Actions**.
3. If a deployment ran before Pages was enabled, rerun the workflow from the
   [Actions tab](https://github.com/trippletee20/INSIDELASU/actions).

The public landing and game files return HTTP 200, and the hosted game has passed
player creation, wallet receipts, save/reload, keyboard-menu and resize checks.
Future game updates run the same build/test/deployment pipeline.

## Play and save

On phones, move with the left stick, swipe on the right to look and tap **Interact** near buildings or shuttle stands. **Map** opens the campus overview.

On desktop, create a student, check into the assigned hostel, and press **E** near buildings or
shuttle stands to find activities. **H** opens help, **P** the student profile,
**B** the wallet and receipts, and **M** the map. Click the game for mouse look;
**Esc** releases the mouse or closes a menu.

Progress is stored on the current browser/device. There is no account or cloud
save. Clearing site data removes local progress. The game wallet uses fictional money.

The [mobile expansion](docs/MOBILE_EXPANSION.md) adds 24 interior themes, 168 building challenges, nonblocking shuttle traffic and passenger cabin views. [Billboard advertising](docs/BILLBOARD_ADVERTISING.md) has a local artwork preview; real bookings through Paystack and Flutterwave are planned for after launch and are not enabled.

## Develop

Use official **Godot 4.6.3 stable** and Python 3.11+. The full setup, release
evidence and limitations are in [docs/BROWSER_RELEASE.md](docs/BROWSER_RELEASE.md).

```sh
python3 tools/check_environment.py
python3 tools/build_web.py
python3 tools/test_web.py
python3 tools/test_mobile_web.py
python3 tools/test_advertising_preview.py
```

Export requires the matching single-thread web templates. Browser tests require
Playwright/Chromium. The CI workflow installs and verifies the official toolchain.

The original v0.13 project is tagged `v0.13-baseline`. The campus layout and road
data remain unchanged. See the historical traffic reports under `docs/` for the
earlier fixes and exact regression logs.
