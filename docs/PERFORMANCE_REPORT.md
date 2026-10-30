# Inside LASU — performance phase

**Optimisations implemented; performance acceptance remains incomplete.** Engine acceptance, web export, desktop browser acceptance and mobile touch acceptance passed. No push or deployment was performed. The current build does not pass the newly recorded regression budget, and physical Android 30+ FPS is unverified.

## Measurements

Three runs per build, sequential on the same recorded host. Chromium 145, 393 × 873 mobile viewport, DPR 3/CSS-pixel canvas, Medium quality, 4× CPU slowdown, 4 Mbps aggregate server-shaped download and 150 ms request latency. SwiftShader software rendering is used: these figures are **not mid-range Android hardware measurements**. Browser context is isolated per run; caches are reused only for that run's warm navigation. See PERFORMANCE.md for instrumentation, route and memory definitions.

FPS is the median of each run's median one-second samples, across three runs. Draw calls are the maximum sampled in each phase across the three runs. This is not 1% low FPS.

| Phase | Before FPS | After FPS | Before peak draw calls | After peak draw calls |
|---|---:|---:|---:|---:|
| Campus idle | 5.73 | 4.59 | 691 | 554 |
| Walking/turning | 6.21 | 8.50 | 686 | 554 |
| Phone menu | 5.75 | 6.13 | 454 | 339 |
| Interior | 15.97 | 15.94 | 642 | 502 |

| Metric | Before | After |
|---|---:|---:|
| Peak sampled Chrome process PSS | 827.93 MiB | 862.15 MiB |
| Cold world-ready time (median) | 35.15 s | 31.84 s |
| Cold architecture-complete time (median) | 52.21 s | 48.17 s |
| Warm world-ready time (median) | 10.75 s | 8.39 s |

PSS includes Chrome renderer/WASM/software-GPU process memory on Linux and is sampled every two seconds. It is not Android RAM consumption or a sum of JS heap and GPU counters. Peak render-memory counters are recorded separately in the raw JSON. Small peaks between samples may be missed.

Results are mixed: walking FPS and draw calls improve, as do cold/warm load times. Idle median FPS falls; interior median FPS is nearly unchanged; peak process memory rises. Worst sampled phone/interior frame intervals also worsen. We cannot attribute these differences solely to code: software-GPU contention and host load are uncontrolled. Nevertheless, they are reported as regressions, not hidden or converted into relaxed limits.

## Download budget

| Asset | Previous delivered build | Optimised build |
|---|---:|---:|
| Raw game pack | 2,239,216 bytes | 1,240,756 bytes |
| Actual game-pack payload on compression-capable browser | 2,239,216 bytes | 694,115 bytes |
| Raw engine WASM | 37,700,666 bytes | 37,700,666 bytes |
| Compressed engine payload | 9,382,282 bytes | 9,382,282 bytes |
| Runtime JS | 315,759 bytes | 315,759 bytes |

The instrumented before build used for timing has a 2,242,660-byte pack; both measured builds include the same observer/scenario. Raw and compressed first-load sizes shrink, so there is no download-budget increase. Asset byte totals exclude unchanged HTML/CSS/worklets and HTTP headers. First-load time is measured independently above.

## Exact file changes

`performance.patch` provides line-level before/after changes against the delivered theme ZIP. Binary font hashes and sizes are recorded in `file_changes.json`; the original variable font is retained outside the game project under verification for reproducibility.

| Path | Before | After |
|---|---|---|
| `assets/fonts/NotoSans.ttf` | Variable weight/width data | Static default weight/width; all 4,515 glyphs and metrics retained |
| `assets/fonts/BUILD_NOTE.txt`, `tools/optimise_font.py` | Absent | Reproducible font optimisation and licence note |
| `scripts/render_budget.gd` | Absent | Per-building material batches and 32 m road-render chunks; detail distance limits |
| `scripts/main.gd` | Individual road/dash meshes and unbatched eligible architectural boxes | Equivalent visual transforms in batches; opt-in observer attached |
| `scripts/interior_builder.gd` | Only active floor instantiated, but metadata loaded eagerly and materials duplicated | Active-floor model retained; metadata lazy-loaded; materials shared; caches released on exit |
| `scripts/game_settings.gd` | Manual Low/Medium/High | Auto capability heuristic plus preserved explicit choices; detail LOD applied |
| `scripts/player_controller.gd` | Instant acceleration/look; per-physics-frame proximity scan | Acceleration/look smoothing and 10 Hz proximity scan |
| `scripts/ui_motion.gd` | Absent | Cancellable 120 ms opening fades; reduced-motion preference respected |
| `scripts/campus_phone.gd`, `scripts/student_ui.gd` | Immediate opening | Shared opening fade; phone Settings offers Auto |
| `scripts/performance_probe.gd` | Absent | Opt-in wall-clock frame telemetry and isolated benchmark route |
| `web/runtime-cache.js`, `tools/build_web.py` | Engine gzip only | Game-pack gzip with uncompressed fallback |
| `tools/check_environment.py` | Existing engine checks | Adds performance regression |
| `tools/mobile_gameplay_regression.gd` | Expects complete camera rotation after one frame | Verifies smoothed rotation within 200 ms |
| `tools/performance_regression.gd` | Absent | 45 checks for batching, lazy interior lifecycle and presets |
| `tools/profile_mobile.py`, `tools/check_performance_budget.py` | Absent | Three-run captures and budget enforcement |
| `docs/PERFORMANCE.md`, `docs/performance_budget.json`, `docs/PERFORMANCE_REPORT.md`, `docs/PROJECT_BRIEF.md` | No recorded performance contract | Procedure, honest results, gates and architecture link |

No campus/road JSON, save-store logic, backend/social code or CI workflow was changed. Existing saves keep explicit settings; missing quality preference defaults to Auto.

## Tests and budget

- Full engine suite: PASS, including 1,254 theme/settings checks and 45 performance checks.
- Godot 4.6.3 single-thread web export: PASS.
- `tools/test_web.py`: PASS.
- `tools/test_mobile_web.py`: PASS.
- Before/after browser profiling: three completed runs each; raw JSON included.
- Current performance-budget check: FAIL for idle FPS, phone/interior worst-frame intervals and Chrome PSS. These are deliberately retained as unmet gates.
- Remote GitHub Actions, physical Android, Safari/Firefox, sustained thermal performance and audible/subjective smoothness: not verified.

The budget uses the better before/after measured value per metric; timing/render-counter checks allow 5% noise, memory/bytes allow no growth. This locks improvements without accepting regressions. The 30 FPS physical-phone target remains separate and pending, with draw-call, RAM and load-time limits unset until real-device measurements exist.

## Reproduce

From the extracted repository, using prerequisites in docs/PROJECT_BRIEF.md:

```sh
python3 tools/check_environment.py
python3 tools/build_web.py
python3 tools/test_web.py
python3 tools/test_mobile_web.py
python3 tools/profile_mobile.py --output test-results/performance/current.json --runs 3
python3 tools/check_performance_budget.py test-results/performance/current.json
```

Profile after the other processes finish. The budget checker rejects a different host/browser/renderer instead of presenting incomparable results as a pass. Physical Android procedure is in docs/PERFORMANCE.md.

Lazy floor instantiation was already present; it has not been relabelled as new asynchronous streaming. Room construction remains synchronous. LOD hides small details at 65/100/150 m; it is not mesh simplification. Auto quality is a conservative capability heuristic, not real-time adaptive scaling. Menu closing stays immediate. These limits are intentional and disclosed.
