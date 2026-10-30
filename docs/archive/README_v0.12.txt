INSIDE LASU v0.12 — TRAFFIC, INTERIORS, VISUAL HUD
==================================================

INSTALL / TEST ON WINDOWS
1. Keep the previous working v0.11 project folder.
2. Extract THIS ZIP to a NEW folder.
3. Open Godot 4.7: Import > this folder's project.godot > Import & Edit.
4. Press F5.
5. Test shuttles at the bus-stop junctions, then use E to access hostel,
   faculty, Arcade, health, library and market activities.
6. Select ENTER BUILDING within its activity panel. Switch floors in that panel.
7. F sits or stands at registered seats. M toggles overhead map.

IN THIS BUILD
- Wider visibly two-lane roads: 334 of 336 centreline segments have 10.0 m
  asphalt width. Two schematic bottlenecks remain at 6.2 m to avoid clipping
  protected structures and Love Garden / hostel site boundaries.
- Opposing lane centres are increased where geometry allows; narrowed safely
  at the two bottlenecks.
- Lower priority shuttle can yield by slowly reversing along its existing
  road path; it is not allowed to pass through another bus.
- Five configured shuttles, plus all existing destination stops, fares and
  quick travel options preserved.
- All 56 eligible completed indoor site names now have selectable floors and
  procedurally decorated themed rooms. Hostel rooms contain sleeping areas,
  wardrobes, desks and common seating. Academic, service, medical and other
  indoor spaces use different furnishings.
- Stylised dark teal HUD with segmented visual statistics for energy,
  stamina, stress, and the current clock; improved activity buttons.
- Repaired seat detection for newly created indoor chairs and benches.
- Original campus site geometry, road centreline topology, Franklas Gate,
  economy, task catalogue and saved-profile rules unchanged.

HONEST LIMITATIONS
- These are stylised MODULAR interiors, not verified LASU floor plans.
- Vertical floor access currently uses an activity-panel selector, not real
  staircase traversal. Not all tasks have animations/minigames yet.
- Detailed road construction is still schematic; two very narrow passages
  cannot be widened without moving approved site boundaries.
- Godot 4.7 is NOT installed in the build environment; static tests passed,
  but the binary was not executed here. Traffic recovery is an improvement,
  not a proven zero-deadlock guarantee.

WHAT TO TEST FIRST
A. Watch five shuttles at central junctions for at least a few minutes.
B. Board a bus, choose Ride & Watch, then Quick Travel and alight.
C. Enter Hostel 1 and use floor selector; F to sit by a chair.
D. Enter the Library, Arcade and Senate; inspect their different rooms.
E. Verify HUD energy/stamina/stress bars, wallet and tasks work together.

NO SAVE RESET NEEDED
Profile persists in Godot user:// data; project import should not reset it.
