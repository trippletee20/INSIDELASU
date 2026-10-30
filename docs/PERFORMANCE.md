# Performance measurement and optimisation

This phase adds no campus content. Campus/road JSON and save-store code are unchanged.

## Repeatable browser profile

Install Godot 4.6.3, matching web templates, Python and Playwright 1.58.0 as described in PROJECT_BRIEF.md. Use an otherwise idle host. Builds and acceptance tests must finish before timing runs; never benchmark two builds concurrently.

```sh
python3 tools/check_environment.py
python3 tools/build_web.py
python3 tools/test_web.py
python3 tools/test_mobile_web.py
python3 tools/profile_mobile.py --output test-results/performance/current.json --runs 3
```

The default profile is Chromium 145 mobile emulation at 393 × 873 CSS pixels, DPR 3 (the game retains CSS-pixel canvas resolution), 4× CPU slowdown, 4 GB reported device memory, 8 reported logical processors, 4 Mbps aggregate download and 150 ms request latency (local upload is unthrottled). Network shaping runs in the HTTP server so it also covers service-worker fetches. Rendering uses SwiftShader on the host CPU. This is a repeatable regression profile, **not equivalent to an Android GPU or proof of 30 FPS on a phone**. Report the recorded host/browser/GPU alongside figures.

Each run creates an isolated browser context and fictional profile. Medium quality is fixed for fair comparison. After architecture construction finishes, the scripted route spends 10 seconds on campus, 15 walking/turning, 10 in the phone menu and 15 in the first alphabetically named interior. It then reloads the same context for the warm-cache measurement. The instrumented before build uses the identical observer/scenario; no optimisations are applied to it. Never use `benchmark=1` in a real save context. The scenario refuses an existing profile.

The `?profile=1` observer is opt-in. It publishes up to 600 one-second samples in `window.lasuPerfSamples`, without changing game state. Frame intervals come from monotonic wall-clock ticks, rather than Godot's potentially capped frame delta. Draw calls and render-memory counters come from Godot Performance. Release-build static memory is unavailable and is represented as null. Per-stage FPS is the median of one-second measured frame rates, with the minimum one-second sample and worst observed frame interval also recorded. These are not 1% low FPS measurements.

The Python runner samples Linux Chrome-process proportional set size (PSS) every two seconds, covering the renderer/WASM and software GPU process. This includes shared process memory proportionately and is separate from JS heap and Godot video-memory counters; do not add those counters together. Unsupported/inaccessible PSS is null. A sampled peak can miss short spikes. The profiler reports page/script errors as failures.

Cold world-ready time is navigation-to-world-ready in milliseconds. Also retain architecture-ready and engine-started times: a first visible frame is not the same as completion of deferred campus construction. Warm time comes from a second navigation with the existing runtime cache. Download byte comparisons use exported files; HTTP/cache/network timings are separate measurements.

## Changes

- `assets/fonts/NotoSans.ttf`: unused variation axes frozen at default weight 400/width 100. All 4,515 glyphs, Unicode mappings and horizontal metrics retained. Existing OFL licence retained; `tools/optimise_font.py` reproduces the change from the original variable font. No language subset.
- `tools/build_web.py`, `web/runtime-cache.js`: deterministic gzip game packs, fingerprinted with the existing source-pack hash. Service-worker decompression with uncompressed fallback, just as for the engine. Public files only; auth/save data never cached.
- `scripts/render_budget.gd`, `scripts/main.gd`: static architecture boxes grouped by material and size tier per building. Source nodes remain hidden for seat/geometry metadata consumers. Road surfaces and dashes become spatially chunked MultiMeshes; positions, dimensions, rotations, colours and route data are unchanged. 32-metre cells avoid one campus-wide render batch.
- Small batched architecture uses distance detail culling: 65/100/150 metres for Low/Medium/High, with 8-metre hysteresis. Large structure silhouettes remain. This is simple detail LOD, not mesh decimation or streaming of whole buildings.
- `scripts/interior_builder.gd`: retains the existing active-floor-only creation; metadata is now loaded on first entry, materials shared by colour/emission, and caches released on exit. First-entry construction is still synchronous; this does not claim asynchronous room streaming.
- `scripts/game_settings.gd`, `scripts/campus_phone.gd`: Auto/Low/Medium/High. Auto selects Low on <=2 GB/<=2 cores or data saver, Medium on touch devices or fewer than 8 GB/8 cores, otherwise High. Missing browser information falls back conservatively. Existing explicit choices survive. This is a capability heuristic, not continuous adaptive resolution.
- `scripts/player_controller.gd`: 125 ms maximum-speed acceleration, existing stopping behaviour, exponential look smoothing (35/s), proximity refresh at 10 Hz with immediate interaction lookup retained.
- `scripts/ui_motion.gd`, phone/student UI: 120 ms opening fade with cancellation and reduced-motion support. Closing remains immediate, preventing stale input capture.
- `scripts/performance_probe.gd`, `tools/profile_mobile.py`: opt-in measurements and reproducible scenario. `tools/performance_regression.gd` verifies lazy loading, batching, retained source metadata, presets and cache release.

## Physical Android confirmation

Use the same release on a named mid-range Android phone; record model/SoC, RAM, Android/Chrome version, battery/thermal state, viewport and network. Run unplugged from charging, close other apps, use Medium first, and repeat the campus/walking/menu/interior route three times with cold and warm cache. Open `?profile=1` and collect `window.lasuPerfSamples` plus `window.lasuBootMetrics` using Chrome remote debugging. Use Android memory tools for physical process memory; desktop PSS numbers are not transferable. Check Low/Auto under sustained play, touch responsiveness and device rotation. Do not finalise a physical-phone budget until that evidence exists.

## Budget policy

`performance_budget.json` distinguishes measured host-profile gates from pending physical-device gates. Match the profile and browser/renderer before comparing values. No new first-load bytes without approval. Physical Android target remains at least 30 FPS; no headless or emulated result proves it. A failed or incomplete browser run must not silently update the budget. Keep raw samples and an exact source patch with each baseline.

## Recorded result and outstanding gates

The measurements are in `PERFORMANCE_REPORT.md` and `performance_budget.json`. The budget takes the better before/after value per metric, allowing 5% timing/render-counter noise and no memory or download growth. Current results fail idle-FPS, menu/interior worst-frame-time and browser-PSS gates. Do not treat this phase as performance-signed-off or add content against a relaxed budget. The software renderer and uncontrolled host load limit diagnosis; physical Android evidence is still required. No claim is made that reduced draw calls necessarily improve every view.

Run the budget check against a new three-run capture:

```sh
python3 tools/check_performance_budget.py test-results/performance/current.json
```

The included after capture intentionally reports unmet gates; the checker must not claim it passes.
