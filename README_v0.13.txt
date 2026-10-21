INSIDE LASU v0.13 — TRAFFIC JAM RECOVERY + PRIVATE HOSTEL ROOM
==============================================================

HOW TO INSTALL (WINDOWS / GODOT 4.7)
1. Keep the last working v0.12 folder as a backup.
2. Extract this ZIP into a NEW folder.
3. Launch Godot > Import > select the NEW project.godot file.
4. Press F5 and open your existing student profile.

TRAFFIC CORRECTIONS
- CRITICAL FIX: the movement loop used to overwrite traffic recovery state after a
  blocked update. This is now corrected in all three movement branches.
- An obsolete 11-metre exclusion bubble around stopped buses was removed. Two
  buses are now compared using their actual oriented bus footprints.
- Shuttle parking attempts a gradual 3.55m pull-off beside the main carriageway,
  only when the entire candidate bus footprint avoids protected campus areas
  and other buses. The modelled terminal bay pavement is only placed where
  the same safety check passes. If a clear bay is unavailable, the dwell is
  shortened rather than allowing a bus to sit there indefinitely.
- Behind a blocked shuttle, a double-beep horn sounds after 2.5s and a bus ahead
  is asked to clear its stop early if not occupied by a passenger or an open menu.
- Yielding can now use up to 38m of safe backing along the EXISTING route.
- No new roads or fictional shortcuts, and no intentional bus teleportation.
- Junction right-of-way and boarded rides are retained.

PERSONAL ROOM
- All completed hostels retain their shared interior and their original floors.
- Enter YOUR assigned hostel and choose ENTER MY PRIVATE ROOM from the E menu,
  or walk to the residents' door at the back of the ground-floor corridor and E.
- Your unique room number comes from your saved student profile. Room scene
  features a bed, wardrobe, folded clothes, study desk, laptop, rug, window,
  framed campus picture, door, ceiling light and suitcase.
- In your room press E for room actions: Rest; Visitor Permission (defaults OFF),
  and furniture purchase (bookcase, lamp, plant, game setup, poster).
- Purchases deduct in-game naira and persist, as do the visitor setting and
  45-minute real-time rest cooldown. Existing wallet/profile saves load normally.
- Press RETURN TO HOSTEL RECEPTION to re-enter the shared hostel.
- PRIVATE INSTANCE NOTE: this is a single-player room scene. Other student/NPC
  visitors cannot enter through gameplay yet. The visitor permission toggle is
  an access-control setting for the later NPC/multiplayer implementation.

PRECISE TEST ORDER
1. Watch two buses approach each other or one bus wait at a terminal.
2. On an obstruction, listen for the horn; watch the bus ahead clear the route.
3. Watch again at the same junction for 2–3 minutes: no prolonged standstill.
4. Go to YOUR assigned hostel. From its tasks, ENTER INTERIOR.
5. Walk to the residents' room door or use the E menu -> YOUR PRIVATE ROOM.
6. Press E in the room; rest, buy a furnishing, and set visitor permissions.
7. Exit and re-enter to verify that furnishings stay and your wallet is preserved.

HONEST LIMITATION
This package passed static syntax-shape / file-integrity / save-state tests but
COULD NOT be launched in Godot 4.7 from this environment; a live traffic test on
Windows is still necessary. The traffic logic includes conflict checks and
recovery, but no finite automated check can guarantee every possible junction
configuration will run forever without a deadlock. The hostel room is a polished
modular game scene, not a surveyed replica of an actual LASU dorm.
