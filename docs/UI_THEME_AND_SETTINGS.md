# Shared UI theme and Settings

## Player access

Open **Settings** from the expanded campus dashboard or the phone home screen. On desktop, press **F2**. Escape or the phone Close button returns to play. A student profile must exist before Settings opens. Menus release movement, touch fingers and mouse capture.

Appearance offers **System (device)**, **Light** and **Dark**. System is the default for new and old saves. In web exports it reads `prefers-color-scheme`; native builds use the display server preference, with light as the unsupported-platform fallback. System preference changes are checked once per second. Explicit light/dark selections override the device.

| Platform | Controls |
| --- | --- |
| Desktop | Theme; Low/Medium/High quality; 50–100% 3D resolution scale; 25–200% mouse sensitivity; 0–100% master volume; keybinding display |
| Mobile/touch | Theme; Low/Medium/High quality; 85–120% control size; left/right stick with mirrored action buttons; 25–200% look sensitivity; master volume |

Changes apply immediately and save with the existing student profile. Reset restores device-theme/default preferences. Keybindings are displayed, not remappable. Resolution scaling changes the 3D viewport only, keeping the UI at its existing logical resolution.

## Shared design system

`ui/campus_theme.tres` is the single Theme resource. `scripts/ui_theme.gd` populates its two semantic palettes and named style variations, then mutates that same resource when appearance changes. Controls share it instead of copying styles. New top-level Controls are bound automatically, including panels created after startup.

- Existing Noto Sans font and existing white-stroke SVG icons are reused; no font/image assets are added.
- Surface, field, hover, text, muted, accent, border and error colours live in the theme helper.
- Eight-pixel container spacing, rounded panel/button styles and shared focus states unify the interface.
- Named styles cover the dock, compact HUD pills, phone tiles, meters, error text, message bubbles, toasts and world-label cards.
- Phone apps retain their existing order and functions. The grid uses two columns below 350 logical pixels of panel width, otherwise three, with equal-height tiles. Settings is a separate utility entry below the app grid.
- Touch controls preserve a minimum 44-pixel action target, mirror for a right-hand stick and move secondary actions into a separate row on short landscape screens.

## Settings and save compatibility

`game_settings.gd` validates an additive `settings` dictionary inside the existing schema-2 save. No save version bump, reset or replacement storage system is introduced. Old saves without the dictionary receive defaults. Existing fields and unknown future settings survive resaving; invalid enum/types and numeric ranges fall back or clamp safely. The existing `save_store.gd` migration, backup and newer-version overwrite protections remain unchanged.

`main.gd` loads preferences before constructing the UI, applies them after player/control creation, saves changes and handles F2. The phone supplies the scrollable Settings screen.

Quality changes real rendering settings:

| Quality | Walking camera far plane | MSAA | Mobile 3D scale |
| --- | ---: | --- | ---: |
| Low | 140 m | Off | 65% |
| Medium | 220 m | Off | 85% |
| High | 300 m | 2× | 100% |

Desktop resolution scale remains independently adjustable. Quality does not change campus geometry, roads, traffic, collision, activities or save content. These presets are not a physical-device FPS guarantee.

## World labels

`world_labels.gd` projects existing campus/building/entrance/interior sign anchors into shared-theme rounded cards. It leaves geometry, source positions and layout data untouched. Player identity and online-player labels are excluded.

The original 3D sign text is hidden to avoid double rendering. Cards use 16-pixel text, wrap long names within a 240-pixel width and allow up to three lines. They shrink gradually to 85% scale with distance and hide beyond 55 metres, behind the camera or outside the usable screen area. Nearest cards take priority, overlapping cards are suppressed, and at most 12 appear at a time. Updates run at 20 Hz; there are no per-label render textures, viewports, images or network requests. Interior teardown removes cards for freed anchors.

The cards do not raycast against walls. They are wayfinding overlays, and dense/long sign text may be suppressed or ellipsised. Full location names remain available through Places & tasks. Overview-camera height can place world signs beyond their distance limit.

## Validation and remaining release gates

`tools/check_environment.py` now includes `tools/theme_settings_regression.gd`. It checks theme contrast/inheritance, invalid-settings recovery, persistence/reload, old data preservation, actual rendering/audio changes, F2/Escape, responsive phone layout, both stick positions, touch-target bounds/overlap and label distance/lifecycle behaviour. It uses isolated fictional saves.

Run the complete acceptance sequence described in [PROJECT_BRIEF.md](PROJECT_BRIEF.md), including:

```sh
python3 tools/check_environment.py
python3 tools/build_web.py
python3 tools/test_web.py
python3 tools/test_mobile_web.py
```

Both mandatory browser tests must pass before release. Headless engine checks are not a substitute for a rendered browser review. Physical Android FPS, visual acceptance, device theme detection in a real browser, audio output and live network loading require browser/device verification. The delivery report records this session's exact results and measured export-byte difference; any first-load increase needs owner approval before release. No paid service or real-money feature is introduced.
