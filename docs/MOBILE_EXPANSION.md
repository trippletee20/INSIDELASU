# Mobile controls and campus expansion

This update addresses the reported Android-browser failure: profile creation worked, but the character had no touch movement controls. The game remains a single-player browser beta, with local device/browser saves.

## Player controls

On touch devices a left thumbstick moves the player, right-side dragging turns the camera, and separate touch buttons handle Interact, Jump, Sit/stand, Run and Map. Run is a toggle. Each finger has independent ownership; movement, looking and an action can be held together. Touch controls reset when a modal opens, the viewport changes or the application loses focus. The map's Back button returns to the walking camera.

Browser touch detection also checks `navigator.maxTouchPoints` and coarse-pointer media support, because the engine's display-server flag alone was false in a touch-capable web browser. Touch devices never request mouse capture. The web canvas uses CSS-pixel resolution rather than multiplying both dimensions by device pixel ratio, keeping controls the same usable size on dense phone screens and avoiding a ninefold pixel workload at DPR 3. Native browser text input is enabled for the profile name; the portrait form scrolls and option labels clip rather than forcing a wider panel. Menus adapt to portrait and landscape, and the shuttle menu scrolls on short screens.

Desktop keyboard/mouse controls remain available. Mobile-first changes are separate from the fictional student wallet and retain existing saves.

## Traffic and passenger view

`TransitManager.vehicle_blocking` now defaults to `false`. Vehicle peers do not block advancement, parking/merging, turns or junction passage; reservation arbitration is skipped in this mode. Road paths and campus feature checks remain. Explicit pickup/menu/arrival holds still behave as holds. Overlapping vehicles are an accepted visible limitation of this reliability-first arcade mode. The old blocking mode is retained and explicitly enabled in its historical regression fixtures.

The previous onboard camera was a chase camera. Shuttles now have open cabin geometry, transparent windows, seats, aisle, rails and dashboard, and a seated passenger camera. Inside/outside switches between that camera and the original chase view. Swipe to look inside on mobile; on desktop press V to switch views and hold the right mouse button to look. Free walking around a moving cabin is not implemented.

## Buildings and activities

All 56 existing enterable sites have an identity in `data/building_experiences.json`, with 24 themes: library, law, science, studio, clinic, sports, hostel, auditorium, chapel, laundry, food, market, arcade, bank, innovation, computing, arts, education, social sciences, management, civic services and lecture spaces, transport planning and the staff-club lounge. The exact unique theme set is derived from the data; related buildings share a kit with stable site-specific colour variants. Open halls replace the universal corridor where appropriate. Examples include a moot courtroom, shelving and reading tables, teaching laboratories, production desks and microphones, laundry machines and a marked indoor sports court.

Only the active interior floor is instantiated. Major furniture has collision, circulation space remains at the entrance, and seats register with the existing sitting system. These layouts are illustrative game designs, not surveyed university interiors.

Three new activities at each site add **168** two-stage decision challenges. Activities are assigned to valid floors. Wrong answers and partial completion do not award money. Completion records an activity, skill practice and any fictional payment receipt, with once-per-day limits. Existing catalogue tasks remain available. These are short decision-based activities, not fully simulated jobs or NPC conversations.

## Advertising

All 100 billboard slot IDs are registered for interaction. Clicking a billboard face, or approaching and choosing Interact, opens advertising information and a linked preview page. Business artwork can be previewed locally with a slot, duration and the selected providers, Paystack and Flutterwave. Bookings and real payments are disabled. See [the post-launch advertising plan](BILLBOARD_ADVERTISING.md) for the backend, review, payment verification and merchant-account requirements.

## Validation

Local acceptance passed **467 engine checks** plus the desktop, touch-browser and advertising-preview flows. Logs and selected screenshots are under [validation/mobile](validation/mobile/).

- `python3 tools/check_environment.py`: previous gameplay/save and blocking-traffic regressions, touch gameplay and five viewport layouts, all-building identity/activity coverage, challenge reward checks, and a 300-second nonblocking traffic run.
- `python3 tools/build_web.py`: desktop/mobile texture support, native web text input, single-thread export and content-fingerprinted game pack URLs to avoid reusing an old cached pack.
- `python3 tools/test_web.py`: actual exported desktop browser profile, wallet, receipt, saving and UI checks.
- `python3 tools/test_mobile_web.py`: 393×873 and 873×393 touch Chromium at device pixel ratio 3, profile typing/scrolling, simultaneous movement/look/action, movement-related stat change, touch menus/map, orientation changes, save/reload and no pointer lock.
- `python3 tools/test_advertising_preview.py`: mobile preview, slot selection, artwork validation, both provider choices, safe text handling and no upload/payment requests.

The engine checks additionally exercise menu bounds at 393×873, 873×393, 360×640, 640×360 and 320×568. Chromium tests use software WebGL and mobile emulation; they do not establish physical Android performance or compatibility with every phone/browser. Real-device acceptance remains necessary.

The requested reference, `https://lagoslife.app`, returned 403 Forbidden from the execution environment (including the www host and activity path). No activity or visual design in this update is represented as an observed or copied feature of that site.

## Published release

The game source `5760467` passed [GitHub's build and deployment](https://github.com/trippletee20/INSIDELASU/actions/runs/39770349957). The actual public game then passed the high-density touch-browser, desktop-browser and advertising-preview checks. [Hosted evidence](validation/mobile/hosted/) records the results.

[Open the updated game](https://trippletee20.github.io/INSIDELASU/play/index.html?v=5760467). This versioned link fetches the current launcher while retaining the same browser/device save.
