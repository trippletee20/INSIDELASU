# Inside LASU v0.14: first traffic milestone

Implemented the brief's **first implementation task only**: diagnostics, deterministic
engine scenarios, and reproduced traffic fixes. Later UI/economy, interior, NPC,
save-schema migration, full lane-graph/reservation, and release work remains pending.
The attached brief is retained alongside this report as project guidance.

## Baseline and scope

- Unmodified ZIP contents committed as `85d852b021bc0ef5f81fa40c755292b574705b3e`,
  tagged `v0.13-baseline`. No push was made.
- Original archive retained outside the checkout at `/workspace/baselines/`.
  SHA256: `4b1236f7dd8f2f1a26eaf7d8eceaaf667e49c63f9de76cfef3f9039a9c81f19a`.
- Godot **4.6.3.stable.official.7d41c59c4**, Linux headless, compatibility renderer.
  `.godot-version` pins the tested engine; historical 4.7 README advice was not used.
- All data files, the scene, project settings, `main.gd`, interiors, player and other
  builders are byte-identical to the archive. `tools/baseline_hashes.json` enforces
  those invariants. Fare, prepaid hostel, curfew, faculty access and save code remain
  unchanged. Existing-player save migration and graphical interaction were not tested.

## Architecture and diagnosis before editing

`main.gd` constructs the world, HUD, economy, save/profile and interactions, then
initialises `transit_manager.gd` from the route, amenity, road and campus JSON data.
Transit owns dictionaries for service state, an intersection-split road graph,
shortest paths, destination dispatch, SAT bus collision checks, parking and recovery.
The interiors builder creates only the current floor/private room.

Five original traffic risks, using **baseline** line references:

1. `_must_yield_to_higher_priority`, 458–474: only a larger service index can back
   away; a held/highest-priority bus can leave no guaranteed escape.
2. `_safe_to_advance`, 514–528: crossing priority is a distance heuristic, without
   junction reservations, exit protection or fairness aging.
3. `_bay_position_is_clear`, 413–420: building clearance tests only the bus centre,
   ignoring the full length. A narrow wall at the nose passes incorrectly.
4. `_safe_to_advance`, 476–509, and waiting branches, 225–237 / 273–286: endpoint
   poses alone miss swept collisions; terminal lane shifts and body turns bypass
   those checks entirely.
5. `_attempt_traffic_advance`, 345–366: retreat is checked against the budget before
   adding a full step, so it can overshoot 38 metres; exhaustion has no guaranteed
   escape. A warning existed, but no signal for other systems.

Engine inspection also found `CENTRAL_LINK` was silently absent after a startup
warning. The Arcade shelter is 7.632 map units from the connected road, beyond the
five-unit start-route guard. Its pedestrian shelter position is not a drivable origin.

## Annotated changes

| File / function | Change and reason |
| --- | --- |
| `transit_manager.gd::initialise` | Project initial shelter origins onto the existing connected road graph; all five services now initialise, with no invented road or off-road connector. |
| `_bay_position_is_clear` | Conservative expanded longitudinal segment protects nose/tail and corners against campus footprints. |
| `_update_parking_bay` | Check intermediate parking poses; let an unavailable outward bay's dwell expire while holding unsafe inward merges. Previously a partly parked bus could stop its own dwell timer forever. |
| `_swept_pose_is_clear` / `_safe_to_advance` | Check intermediate route/lane/parking poses against rendered bus orientations, at at most 0.25 m / 5 degree steps. This is sampled collision checking, not a mathematical continuous-collision proof. |
| `_physics_process` / `_place_service` | Guard waiting lane changes and rendered heading changes; fixes an actual GATE_EXPRESS/CENTRAL_LINK turnaround overlap observed in the campus simulation. |
| `_attempt_traffic_advance` | Clamp retreat to remaining 38 m budget; emit `traffic_safe_wait` when the existing 25-second warning fires. Occupied rides are retained. |
| `traffic_debug.gd` | Separate opt-in observer, F8 drawing toggle, fixed-tick JSONL telemetry, per-service state/blocker/stuck/retreat/passenger data, route/lane and footprint previews. Reports reservation as null because reservations do not yet exist. |
| `tools/traffic_regression.gd` | Seed 14014, fixed 60 Hz, production transit code with controlled fixtures plus actual campus data. No static matching substituted for simulation. |
| `tools/check_environment.py` | Pinned engine check, protected-data hashes, engine import, road audit, regression suite, normal and diagnostic startup, telemetry checks. Fails on engine errors even with exit code zero. Uses isolated user data so tests do not touch player saves. |

Use `git diff v0.13-baseline -- scripts tools .gitignore .godot-version` to review
the implementation. No NPC or unrelated system refactoring was introduced.

## Executed validation

From `/workspace/INSIDELASU`:

```sh
bash tools/setup_cloud.sh
python3 tools/check_environment.py
```

Exact engine output is in `docs/validation/` (also fresh logs in ignored
`test-results/`). The initial failing regression log is retained as
`docs/validation/traffic-before.log`; it includes an eight-second junction deadline
that was too strict, not a confirmed junction defect. Both buses clear in ten seconds.

Final results:

```text
TRAFFIC REGRESSION: 37 checks, 0 failures (seed 14014, 60 Hz)
PASS: traffic (exit 0)
PASS: runtime (exit 0)
PASS: debug-runtime (exit 0)
PASS: debug telemetry (3 timestamped samples, all five services)
ENVIRONMENT CHECKS PASSED
```

The road audit passes **336 segments / 64 protected footprints** at 1.2 map-unit
centreline clearance. This is not validation of the entire rendered bus footprint
against every curve and road edge.

Scenarios exercise two-way passing, two-way junction contention, a blocked bay,
safe backing and shoulder entry with budget exhaustion, summoned pickup and boarding,
onboard arrival/disembark and return to the service loop, long-tick swept collision,
and a 60-second simulation of all five real campus shuttles. The deliberately exhausted
retreat emits one expected warning/event; it is not an unexplained test failure.
Junction test completion is bounded at ten seconds. These fixtures and duration do
not prove repeated trips under every congestion pattern.

Legacy validators are preserved: `validate_v013.py` requires an absent v0.12 archive
and `validate_v011_traffic.py` checks an obsolete lane constant. They are not acceptance
gates here, and were not represented as passing. The new engine suite is the traffic
gate. No Windows export/templates or graphical/controller tests were run.

## Starting development

Use the existing checkout; cloud tasks are already isolated and need no worktree.
Run `bash tools/setup_cloud.sh`, then `python3 tools/check_environment.py`.
The base image provides Godot 4.6.3 and Python 3; no extra packages, credentials or
runtime network services are needed. Generated imports stay in ignored `.godot/`.

For a headless game session:

```sh
export XDG_CONFIG_HOME=/workspace/.inside-lasu/config
export XDG_CACHE_HOME=/workspace/.inside-lasu/cache
export XDG_DATA_HOME=/workspace/.inside-lasu/data
godot --headless --path /workspace/INSIDELASU -- \
  --traffic-debug --traffic-log=/workspace/test-results/startup-traffic.jsonl
```

Startup is healthy when no parser/runtime errors appear and telemetry includes all
five IDs. No localhost preview applies to this desktop game. On a graphical machine,
open the project in Godot 4.6.3 and run it; add `--traffic-debug` as a user argument
for diagnostic overlays. Press F8 to hide/show them. Traffic initialisation has no
random calls; scenario seed 14014 controls the deterministic regression fixtures.
Profile/economy randomness is intentionally unchanged.

## Manual playtest checklist / remaining release gates

- [ ] Back up an existing player save, load it and check wallet, profile, skills,
      assigned hostel/room, visitor setting and furniture. Verify first-session
      prepaid rent, N150 fare, 11 PM curfew and permitted faculty night access.
- [ ] Observe all five shuttles in normal and map view for repeated complete trips;
      inspect intersections, terminal turns, kerbs, stop access and body clearance.
- [ ] Stage head-on narrow sections, three-way contention, a menu-held bus and a
      passenger bus at a blocked stop. Observe safe waiting rather than collision
      or teleport, and record telemetry for unresolved waits beyond 25 seconds.
- [ ] Verify horns, F8 overlays and readability of blocker/retreat labels; compare
      footprint previews with actual bus bodies through turns.
- [ ] Summon a shuttle, board, ride, alight and wait for loop restoration; check
      continuity at boarding, pickup timeout, disembark and route restoration.
- [ ] Enter a multi-floor hostel and private room, purchase/reload furniture and
      return to the shared lobby/outdoors without losing player state.
- [ ] Profile actual Windows frame time with diagnostics off and on, validate
      controls/audio and export with the matching engine templates; review licences.

Static priority, lack of reservations/aging and guaranteed escape paths remain
known constraints. No claim of universal deadlock resolution, complete road-footprint
validation, release readiness or Windows performance is made.

## Persistence

Setup and startup instructions are saved to the cloud configuration draft separately
from execution. Review/save settings and publish the environment to snapshot prepared
files; saving the draft does not publish. GitHub still has no remote commits. The
baseline and implementation are local only; fresh-task restoration of local-only
commits is not established. Keep the delivered source ZIP until source is pushed
through a separately authorised repository operation.
