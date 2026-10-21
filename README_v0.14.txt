INSIDE LASU v0.14 — TRAFFIC RESERVATIONS DEVELOPMENT BUILD
========================================================

Use Godot 4.6.3 stable (the tested version), import project.godot and run F5.
Read docs/TRAFFIC_RESERVATIONS.md for changes, validation and manual acceptance.
Older README/release files are retained as historical project documentation.

This update adds queued terminal/junction reservations, checks for blocked exits,
separates parking from terminal turns, and fixes parked passenger trip continuity.
No campus road or building data, fare, save, hostel, curfew or faculty access
rules were changed. Windows graphical/performance acceptance remains pending.

Optional diagnostics: run with --traffic-debug as a Godot user argument. F8 toggles
the overlay. Magenta reservation cores belong to the service; orange cores indicate
queued requests. JSONL logging accepts --traffic-log=/absolute/path.jsonl.

Cloud validation from /workspace/INSIDELASU:
  bash tools/setup_cloud.sh
  python3 tools/check_environment.py

The full validation includes two five-minute simulated campus runs and may take
several minutes of real time. Test logs go to test-results; reviewed validation
outputs are preserved under docs/validation. Tests use separate player-save data.

Keep a backup of existing player saves before manual playtesting. This is a
development milestone, not a public release or a claim of universal deadlock freedom.
