# Traffic reservations and shared-terminal recovery

This follow-up replaces the first milestone's static junction priority with queued
reservations and fixes the naturally reproduced shared-terminal blockage. The first
milestone report remains a historical record; use this report for the current behavior.

## Reproduction and changes

The previous implementation, commit `487cf3f`, freezes `GATE_EXPRESS` and `CENTRAL_LINK`
at their shared Arcade road terminal. A new engine test runs all five real routes
and measures actual position changes each physics tick, rather than relying on the
manager's blocked timer. At 120 simulated seconds, those buses had been stationary
for **60.78** and **56.27** seconds. It also detected a movement step above 0.6 metres.
The original failing output is retained in `validation/reservation-long-before.log`.

Two problems interacted: parking offsets were swept across both lanes during a
turnaround, and another shuttle could occupy the same turning/exit space. Parking,
merging and turning now happen in sequence. A separate `traffic_reservations.gd`
coordinator manages terminal and junction conflict areas without editing any road
or campus map data.

- Requests are collected before movement, refreshed every 0.1 simulated seconds,
  and retain FIFO tickets while waiting. A younger service cannot take an occupied
  lease merely because it has a lower index.
- Approaching buses request zones along their existing route, up to 28 metres ahead.
  Junction entry uses a 14-metre radial stop line; terminals use 22 metres so queued
  buses leave room for the owner to turn and clear its exit. Nearby parallel roads
  that do not request the conflict area are not stopped by proximity alone.
- A new lease checks sampled bus poses through the crossing and one bus length
  beyond the core. A blocked exit prevents the grant. Existing occupants retain
  clearance to leave, subject to the normal collision checks.
- Ownership lasts through terminal arrival, dwell, merge, turn and departure.
  Occupied leases are released on clearance, never on a timeout that would reset
  a passenger or teleport a bus.
- Recovery uses reservation ownership/request age instead of numerical service
  priority. Waiting for a reservation alone does not trigger reversing. The existing
  checked 38-metre retreat limit and logged safe-wait behavior remain.
- Blocked turns and bay merges now expose their reason and blocker and emit the
  same safe-wait event after 25 seconds. Debug overlays draw reservation cores
  (magenta for owner, orange for queued) and telemetry reports owner/ticket/age.

A passenger regression also reproduced a sideways jump when selecting a destination
from a parked bus: the temporary route already began at the actual parked position,
but the old parking offset was applied again. Trip setup now removes that duplicate
offset and retains the original parking/lane state for exact restoration on return
or quick travel. The same state is preserved through summoned pickup loop restoration.

## Validation

Run from `/workspace/INSIDELASU`:

```sh
python3 tools/check_environment.py
```

The runner uses the pinned official Godot 4.6.3 engine, isolates player saves,
checks exit status and rejects engine errors or unexpected warnings. It runs:

1. Protected baseline hashes, headless editor import and the 336-segment road audit.
2. The original 37 engine traffic checks.
3. 25 reservation/passenger checks: three-way contention, older high-index request
   priority, a held bus blocking the exit, occupancy retained for 30 seconds without
   expiry, eventual departure after release, and exact parked/partly-turned trip poses.
4. A five-minute five-shuttle campus simulation at 60 Hz, seed 14014.
5. Another five-minute campus simulation with a passenger-held `GATE_EXPRESS` for
   the first 20 seconds, then released without clearing its passenger flag.
6. Normal and diagnostic game startup plus telemetry for all five services.

Each long simulation checks every tick for bus footprint overlaps and movement
steps of 0.6 metres or more. Every service must complete at least two one-way trips
and must never remain stationary for 45 seconds. That watchdog includes planned
dwells; it is independent of internal traffic state. Reports include each service's
trip count, distance and maximum stationary interval. Detailed results and exact
engine output are stored in `docs/validation/` and fresh `test-results/` logs.

## Visual acceptance still required

These are Linux headless engine tests. A graphical Windows playtest and Windows
performance/export checks have not been performed in this cloud environment.

- Observe the Arcade shared terminal and Central Faculty terminal for repeated
  trips; inspect body turns, lane placement, stop queues and departure clearance.
- Enable `--traffic-debug`; confirm active ownership/queue overlays agree with
  behavior. Verify a blocked exit stops an approaching bus before the crossing.
- Hold a destination menu, board a parked bus, ride, disembark and use quick travel.
  Check continuity, fare and passenger state throughout each transition.
- Check actual visible road boundaries and protected buildings at tight curves.
  The road audit is centreline clearance; sampled bus collision checks are not a
  proof of full swept-footprint containment on every rendered road.
- Run with diagnostics off/on and profile the intended Windows device. Reservations
  are intentionally conservative; the tests cover specified configurations rather
  than proving deadlock freedom for all possible traffic arrangements.

Campus data, save/profile logic, N150 fare, prepaid hostel rules, curfew, faculty night
access, interiors and UI remain unchanged. UI/economy work is a subsequent milestone.
No remote push or environment publication is performed by this implementation.

## Final executed results

All **89 engine checks passed**, together with editor import, protected hashes,
road audit, normal startup and diagnostic startup. No unexpected engine errors
or warnings were reported. The exact aggregate log is
[validation/reservation-environment.log](validation/reservation-environment.log).

| Scenario | Shuttle | Completed one-way trips | Longest stationary interval |
| --- | --- | ---: | ---: |
| 300 s normal | WEST | 11 | 16.87 s |
| 300 s normal | SCIENCE | 6 | 16.47 s |
| 300 s normal | GATE_EXPRESS | 5 | 19.67 s |
| 300 s normal | HOSTEL_LINK | 6 | 28.68 s |
| 300 s normal | CENTRAL_LINK | 9 | 15.05 s |
| 300 s passenger-held | WEST | 10 | 16.87 s |
| 300 s passenger-held | SCIENCE | 7 | 16.47 s |
| 300 s passenger-held | GATE_EXPRESS | 5 | 21.62 s |
| 300 s passenger-held | HOSTEL_LINK | 6 | 28.68 s |
| 300 s passenger-held | CENTRAL_LINK | 8 | 15.05 s |
