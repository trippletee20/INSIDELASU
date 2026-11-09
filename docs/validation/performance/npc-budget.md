# Campus NPC release check

Release is on hold. The first NPC capture below predates the pooling update in this commit. The Medium active-NPC cap is now 16 (Low 12, High 25), and repeated per-frame MultiMesh colour writes are cached by pooled actor and pose. A fresh three-run capture is still required before release. The capture uses three cold starts and three cache-warm reloads of the Medium preset in Chromium 145, at 393 × 873, 3× DPR, 4× CPU slowdown, 4 Mbps downlink and 150 ms latency. All campus idle and walk samples had 20 active NPCs. Measurements come from desktop mobile emulation with SwiftShader.

| Metric | Published Phase 2 measurement | NPC build | Phase 2 gate |
|---|---:|---:|---:|
| Campus idle, median FPS | 4.59 | 8.26 | 5.73 |
| Campus walk, median FPS | 8.50 | 9.51 | 8.50 |
| In-game phone, median FPS | 6.13 | 11.81 | 6.13 |
| Interior, median FPS | 15.94 | 17.67 | 15.97 |
| Campus idle, peak draw calls | 554 | 555 | 554 |
| Campus walk, peak draw calls | 554 | 550 | 554 |
| In-game phone, peak draw calls | 339 | 327 | 339 |
| Interior, peak draw calls | 502 | 503 | 502 |
| Peak browser process PSS, MiB | 862.15 | 868.21 | 827.93 |
| Cold world ready, seconds | 31.84 | 33.16 | 31.84 |
| Cold architecture ready, seconds | 48.17 | 44.14 | 48.17 |
| Warm world ready, seconds | 8.39 | 10.46 | 8.39 |

The checker allows 5% variation for frame, draw and loading measures, and zero growth for process memory or exported file sizes. The NPC pack occupies 1,215,420 bytes raw and 521,781 bytes gzipped, within the 1,240,756 and 694,115 byte limits. JavaScript and WASM sizes match their limits.

In the pre-optimisation capture, peak process memory and warm world-ready time exceeded the allowed values. The checker also requires the recorded environment. This capture used Linux 6.18.57 while Phase 2 used 6.18.55. Cross-host differences cannot isolate the cost of adding NPCs. A passing capture on the baseline environment is required to release. Physical Android performance remains unmeasured.

[Three complete runs, including memory and frame samples](npc-browser.json) · [Phase 2 budget](../../performance_budget.json)
