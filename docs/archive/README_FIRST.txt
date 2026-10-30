INSIDE LASU v0.11 — TWO-WAY ROAD / SHUTTLE CONGESTION FIX
========================================================
PLEASE READ RELEASE_NOTES_v0.11.txt FIRST.

INSIDE LASU v0.10 — CAMPUS ECONOMY / INTERIORS / FIVE SHUTTLES
=============================================================
A PLAYABLE DEVELOPMENT BUILD — NOT A VERIFIED PUBLIC RELEASE.

HOW TO RUN ON WINDOWS
1. Extract this complete ZIP into a NEW folder. Keep your working v0.9 safe.
2. Godot 4.x -> Import -> select THIS folder's project.godot.
3. Import & Edit, then F5. Your saved player profile is reused automatically.
4. Walk: WASD; sprint: Shift; jump: Space; look: Mouse.
5. Press E near a building to open activities. Where offered, choose ENTER INTERIOR.
6. When indoors, press E for activities, floor navigation and EXIT BUILDING.
7. F sits/stands at registered bench seats. M toggles the overhead map.
8. At a shuttle stand, press E to request a shuttle and select a campus destination.

MAJOR CHANGES
- FIVE programmed moving shuttle services rather than two: WEST, SCIENCE,
  GATE_EXPRESS, HOSTEL_LINK and CENTRAL_LINK. Vehicle centreline movement is
  distance-checked each physics tick. Vehicles stop/yield when the projected
  gap would be under 8.5 m. Initial shuttles spawn on separated road points.
  NOTE: conservative yielding could lead to a rare traffic standstill if vehicles
  meet nose-to-nose; true intersection scheduling and signal priority are pending.
- 100 static ad signboards total, with tiered sizes, stable ad slot IDs and
  distance-based visual culling. NO active network advertising is enabled.
- 782 task choices across 83 mapped campus sites. The task catalogue is
  data/task_catalog_v0.9.json (filename retained for compatibility).
- AJ and other general markets sell Lagos-style everyday snacks, beverages and
  stationery at configured in-game prices. Science Shops do NOT sell rice/stew;
  they offer snacks, noodles, bread-and-egg combos and suya.
- One cooked Indomie = N600; each cooked egg adds N300. One Indomie+one egg=N900;
  two Indomie+one egg=N1,500. Fried eggs are never sold alone.
- Arcade: budget football/fighting match N200 per player with grid power or
  N300 on generator; AC lounge N300/N500 respectively. NPC challenger match
  outcomes are simulated; the split-bill and loser-pays options are supported.
  Original, non-licensed solo gaming prototypes replace branded commercial games.
- Pool N1,000 TOTAL per round; table tennis N500 TOTAL per round (the request
  described conflicting loser-pays figures; this build uses one clear rule).
- LASU Radio studio restricted to students in media-related courses, or to
  students who receive a temporary in-game interview invitation.
- 10 ON-DEMAND MODULAR INTERIORS with ground/upper floor selection, chairs,
  furniture and room signage. Arcade is still ONLY TWO STOREYS overall:
  ground level has games/retail/Hallowed Chamber and upper level Student Union
  offices. Floor switching is temporarily menu-based, not 3D stair walking.
- Player energy, stamina and stress run from 0–100, and 8 skills run 1–10.
  Newly generated skills start between 1 and 7. Skills gain XP at most once
  per distinct task per real-world day, with fatigue reducing gains.
- Existing wallet, N150 shuttle fare, hostel allocation/first session prepaid,
  random backgrounds, daily reward, approved roads/gates and saved profiles remain.

TECHNICAL VALIDATION
Run from project folder:
  python tools/validate_v010_release.py
  python tools/validate_road_safety.py
These test prices, eligibility data, protected layout hashes, 100 ad placements,
5 service configurations, task integrity and GDScript structural consistency.
They DO NOT compile or execute Godot. Live Godot 4.7 testing is still required.

KNOWN DEVELOPMENT LIMITATIONS
- Interiors are ORIGINAL STYLISED PILOT ROOMS, not verified LASU floor plans.
- The 'arcade games' are NPC outcome simulations, not GTA, FIFA or COD inside
  this game; a standalone original arcade minigame system comes later.
- Vehicle proximity checks prioritise not clipping. Advanced intersection
  reservation/traffic control is needed for guaranteed deadlock-free movement.
- Task menus record outcomes and wallet transactions; detailed simulations,
  animated services, NPC dialogue, student-union elections and multiplayer
  remain separate development milestones.
- To prevent accidental map changes, all 83 feature positions and approved
  road network source files are unchanged from the working v0.9 baseline.

LATEST TRAFFIC CHANGE (v0.11)
- All roads provide opposing lanes; 5 shuttles use right-hand traffic.
- Actual bus-size collision handling and junction yielding replace centre-to-centre 8.5m stopping.
- Terminus turnaround is gradual. See RELEASE_NOTES_v0.11.txt for test cases and limitations.
