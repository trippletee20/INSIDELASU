# INSIDE LASU v0.14 — PRE-LAUNCH TECHNICAL REVIEW & CODEX IMPLEMENTATION BRIEF

**Reviewed source:** `Inside_LASU_v0.13_Traffic_Horns_Private_Hostel_Rooms(2).zip`  
**Engine:** Godot 4 project, GDScript, compatibility renderer; `project.godot` declares `4.3` feature compatibility; included README recommends Godot 4.7. Pin and test the actual export engine version before packaging.  
**Review type:** Static code and data review; no in-engine, graphical or controller playtest has been completed.

## Executive recommendation

Codex can take on coding tasks, refactoring, testing and incremental implementation, but a single instruction to 'finish and launch the whole game' would be irresponsible. First stabilise the current project and ensure it plays correctly, then build a representative polished campus-life experience and progressively populate more locations. Treat a playable public beta and a content-complete launch as different milestones. Do not change the authoritative campus map without an explicit map correction.

## Evidence-based findings

1. **Five route-based shuttles already exist** in `data/transit_routes_v0.7.json`. `scripts/transit_manager.gd` contains a road-graph pathfinder, lane offsetting, horn logic, collision-overlap checks, a fixed priority rule and reversing capped at 38 world metres. It lacks guaranteed recovery for constrained deadlocks: the highest-priority vehicle cannot reverse for a lower-priority one, menu-held/passenger vehicles may not yield, and a yielding vehicle can reach its retreat limit while the path remains blocked. It has no junction-slot reservation, traffic-light control, dynamic priority aging or validated passing-bay escape plan.
2. **Road and lane geometry have different builders.** `scripts/main.gd::_create_roads()` varies asphalt widths by roadside feature clearance, while `scripts/transit_manager.gd::_safe_lane_offset_at()` independently estimates a lane offset using nearby protected-feature geometry. That does not explicitly prove a complete bus footprint remains within the rendered road across all curves and junctions. `prepare_destination()` begins from the lane-offset bus world position then connects to a road-graph path; visually inspect this transition for diagonal snaps or kerb cutting.
3. **Tests are not a launch sign-off.** `tools/validate_road_safety.py` passes on the current package, covering 336 segments and 64 protected footprints at the specified map-unit clearance. `tools/validate_v013.py` cannot complete from this archive alone because it expects `/mnt/data/Inside_LASU_v0.12_Wider_Roads_Interiors_Styled_UI_Godot.zip`; the v0.13 archived audit claims static success but cannot replace a live game playtest. `tools/validate_v011_traffic.py` fails against a hard-coded lane offset from an older release and should be retired or migrated. Godot parsing, frame-time, navigation and actual world interactions still require tests.
4. **UI data exists, presentation needs restructuring.** `scripts/main.gd::_create_hud()` contains status bars and time; `_create_wallet_panel()` uses a fixed origin `(850,15)` and minimum width 415 within a default 1280x720 view. Screen positioning is not robust to smaller windows. `_update_wallet_panel()` prints combined student information in one multi-line label. `total_earned`, `total_spent` and `last_daily_reward_amount` are persisted but do not appear as a proper searchable financial record. The economy should be separated from the player's full profile and compact on-screen HUD.
5. **Daily money may undermine progression.** `_roll_daily_reward()` gives randomized ₦5,000–₦2,000,000 daily rewards with high tail values independent of player activity, while player backgrounds may start with very different wallets. Rebalance this against shuttle costs, meals, study, jobs and future ₦525,000 hostel renewal. Decide whether occasional rare windfalls are part of the game's fantasy; present them as special events rather than everyday guaranteed randomness. Existing first-session hostel rent remains prepaid.
6. **Interiors are modular procedural shells.** `data/interior_catalog_v0.10.json` contains 56 locations, 45 multi-level. `scripts/interior_builder.gd` constructs box-mesh architecture, furniture and room labels, reuses a generic 29x25 shell, and instantiates only the active floor at `(900,0,0)` as a separate scene. The floor selector is a teleport-style transition, not continuous physical stairs. A more appealing result requires location-specific modular scene kits, floor finish materials, lighting, props and clear navigation. Avoid instancing dozens of full interior floors at once.
7. **An NPC system is not implemented.** No pedestrian/NPC navigation agents, schedules, staff/store roles, behaviour trees or corresponding 3D prefabs were found in the scripts. Design this as a new independent system rather than attaching NPC logic to `main.gd`.
8. **Architecture is concentrated in large scripts.** `scripts/main.gd` is over 100 KB and `scripts/transit_manager.gd` over 90 KB. Split systems into named managers with typed contracts, event signals and regression tests before layering in large new features. Preserve existing single-player save files with explicit migration tests.

## Version 0.14 target (in order)

### P0: Make existing gameplay reliably playable

- Commit v0.13 unchanged to source control and archive an immutable backup.
- Pin a Godot version and run `--headless --editor --path <project> --quit` import/parse tests, then start the scene and inspect runtime errors.
- Add deterministic traffic-debug mode: draw lane centre lines, chosen driving path, swept footprint, active reservation, blockers, stop state, retreat direction and stuck duration.
- Unify visible road segments and drivable edges into one validated road/lane graph; preserve existing source map roads. Consider lane-graph edges with vehicle-width clearance and bounded curve radius, not just centreline offsets.
- Replace static priority with junction entry reservations, fairness/aging, protected crossing exits and explicit exception handling for blocked stop bays.
- Define a recovery state machine: `DRIVING -> FOLLOWING -> YIELDING -> PARKING -> REVERSING_TO_BAY -> REROUTING -> DRIVING`, plus an observable safe fail state. Never teleport occupied buses or silently reset passenger rides.
- Introduce deterministic integration scenarios and traffic telemetry.
- Add an explicit save schema version and migration for old wallet/hostel/skills state.

### P1: UI/UX and economy

- Create reusable Godot `Control` scenes with Theme resources and anchors/containers instead of absolute positions; test at 1280x720 and smaller/larger resolutions.
- **Always visible:** small student name, mini location, in-game time, wallet balance, active objective, energy/stamina. Hide nonurgent information behind expandable panels.
- **Student profile screen:** name, department, faculty, level, CGPA, background, hostel, room, skills and progress.
- **Wallet/activity screen:** current balance, earned today, spent today, last reward amount, historical transactions with timestamps, source, description and +/- amounts.
- **Notifications:** money earned/spent toast, daily reward card, travel confirmation, curfew timer and NPC conversation prompts. Provide keyboard/controller-friendly focus/close states.
- Economy balance must constrain awards, define repeatable income sources and avoid relying on huge arbitrary daily giveaways.

### P2: Visual interior upgrade

- Create 6–8 distinct reusable archetypes: faculty/classroom, library, administration, hostel, retail/market, food service, clinic and event/sport facilities.
- For each archetype build a small modular library of floors, walls, doors, windows, ceiling lights, stairs/elevator connection points, furnishing, signage and interactables.
- Floors: add tiled/terrazzo/polished-concrete finishes, scale-correct texturing and a single optimised floor collision surface; change style by building type rather than using identical checkered tiling everywhere.
- Multilevel buildings should offer an accessible stair/elevator portal and correct named levels. Keep only active/adjacent floors resident on low-end devices.
- Pilot the Faculty of Education, New Library, Arcade, one hostel and Senate Building. Validate collisions, prop readability and interaction first, then roll archetypes out to the other eligible buildings.
- Retain the unique private hostel room, ₦525,000 initial prepaid hostel rule, 11 PM curfew and permitted night faculty access.

### P3: NPC-driven campus life

- Build a pedestrian navigation graph that excludes vehicle lanes except designated crossings.
- Create a base `NPC` prefab with distinct roles: student, lecturer, administrative staff, cleaner/security, shop attendant and shuttle-area commuter.
- Behaviour states: idle, walk-route, queue, use-service, sit, shop, converse, attend-class, work, return-home and react-to-blockage.
- Spawn based on location, daypart, role and local population budgets; pool and despawn outside camera/interest zones; keep strategic persistent identity for important characters.
- Starter activity schedule: students morning/evening classes; shops with opening hours; security at entrances; lecturers near faculty/office buildings; dorm residents at night.
- Build a small number of meaningful interactions (greeting, purchase, directions, request help, short quests); avoid generating thousands of inert NPCs.
- Profile device performance before raising active NPC population; target stable frame rate on the actual intended Windows test machine.

### P4: Release acceptance and QA

- Player can create a profile and load the same player without loss of existing saved state.
- All five shuttles stay on visible roads and complete repeated trips in deterministic test configurations, including head-on meeting, three-way junction, waiting stop, parking bay, summoned pickup and onboard passenger.
- A traffic blockage never remains unresolved silently: it either resolves within a documented threshold in test scenarios or enters a logged, player-safe recovery state. No collision or building penetration.
- At least five representative interior archetypes have distinct furnishings, finished floors, working collisions and floor navigation.
- NPCs navigate sidewalks, enter intended locations, and do not park permanently at doors or bus stops.
- UI stays readable and navigable across tested screen sizes; wallet changes show exact sources and amounts.
- Existing save files load; multi-floor and private-room return flows work; curfew and faculty-night-access rules remain intact.
- Test build is packaged for its intended OS with correct Godot export templates, licence/attribution review and gameplay smoke test; no critical parser/runtime failures.

## Codex suggested setup

1. On Windows, extract v0.13, use Git for version control and create a private repository. Commit the original archive's contents to a `v0.13-baseline` tag/commit.
2. Open that folder in the Codex desktop app or Codex CLI; alternatively connect the repository to an eligible Codex Cloud environment configured with the exact Godot engine and headless test dependencies.
3. Work in short separate branches/tasks: `traffic-diagnostics`, `traffic-state-machine`, `hud-economy`, `interior-pilot`, `npc-foundation`, `release-qa`.
4. Review a diff, read test logs, and playtest in Godot before merging each task. Avoid simultaneous edits to `main.gd` without branches or modular refactoring.

## Ready-to-paste first Codex task

> You are the lead Godot 4 gameplay engineer for Inside LASU. Read the entire repository and this `Inside_LASU_v014_Prelaunch_Review_and_Codex_Brief.md`. Before editing, summarize the relevant architecture, current tests and top five traffic root causes supported by specific code references. Preserve every approved campus building position, road data file, existing student save value, ₦150 shuttle fare, ₦525,000 prepaid first-session hostel rule, 11 PM hostel curfew and night faculty access. In the first implementation task ONLY: (1) add deterministic traffic diagnostics for all five shuttles, (2) write Godot runnable regression scenarios covering two-way passing, junction contention, blocked bay, backing to a safe bay, summoned pickup and passenger trip, (3) correct bugs verified by these tests with minimal safe code changes, (4) run Godot headless parser/test checks and provide their exact output, (5) provide an annotated diff and a manual playtest checklist. Do not modify the master campus map, invent new roads, introduce NPCs yet, refactor unrelated systems or claim Godot was run unless you actually ran it. If any tests cannot run, state the environment blocker. Do not mark the task complete unless acceptance tests pass or list exactly what remains failing.

## What not to do

- Do not generate all interiors in one giant procedure or use the same tiled texture blindly in every room.
- Do not spawn all NPCs everywhere; use schedules, pooling, navigation and level-of-detail.
- Do not treat a horn, reversing animation or timeout as proof that deadlock is solved.
- Do not dump all player statistics on the always-visible HUD.
- Do not treat static pattern matching as an actual engine simulation.
- Do not launch a broad unfinished experience merely because the scripts parse.

**Status:** Technical design and static audit prepared; no game source changes made in this review.
