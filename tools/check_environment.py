#!/usr/bin/env python3
"""Run actual Godot checks, preserving exit status and rejecting script-error logs."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results"
OUT.mkdir(exist_ok=True)
(OUT / ".gdignore").touch()
build_directory = ROOT / "build"
if build_directory.exists():
    (build_directory / ".gdignore").touch()
ENV = os.environ.copy()
ENV["INSIDE_LASU_TEST"] = "1"
# Isolate smoke tests from the real player's user:// save and writable editor state.
STATE = tempfile.TemporaryDirectory(prefix="inside-lasu-check-")
for name, suffix in (("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"), ("XDG_DATA_HOME", "data")):
    path = Path(STATE.name) / suffix
    path.mkdir()
    ENV[name] = str(path)


def run(name, command, marker=None, allow_safe_wait=False, timeout=180, fresh_save=False):
    test_env = ENV.copy()
    if fresh_save:
        data_path = Path(STATE.name) / (name + "-data")
        data_path.mkdir()
        test_env["XDG_DATA_HOME"] = str(data_path)
    result = subprocess.run(command, cwd=ROOT, env=test_env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    (OUT / f"{name}.log").write_text(result.stdout)
    print(result.stdout, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    if re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:|FAIL:)", result.stdout):
        raise SystemExit(f"{name}: error in engine output despite zero exit code")
    warnings = re.findall(r"(?m)^WARNING: (.*)", result.stdout)
    if any(not (allow_safe_wait and w.startswith("Shuttle still waiting at bottleneck: yield.")) for w in warnings):
        raise SystemExit(f"{name}: unexpected warning; see test-results/{name}.log")
    if marker and marker not in result.stdout:
        raise SystemExit(f"{name}: missing completion marker {marker!r}")
    print(f"PASS: {name} (exit {result.returncode})", flush=True)


version = subprocess.check_output(["godot", "--version"], env=ENV, text=True).strip()
pin = (ROOT / ".godot-version").read_text().strip()
if not version.startswith(pin + ".stable."):
    raise SystemExit(f"Expected Godot {pin} stable, found {version}")
print(f"ENGINE: {version}", flush=True)
manifest = json.loads((ROOT / "tools/baseline_hashes.json").read_text())
# Main UI, pointer capture and UI stretch are intentionally changed for the browser release.
# Their save/gameplay compatibility is exercised below; immutable campus files stay pinned.
protected = {p: h for p, h in manifest.items() if p not in {"scripts/main.gd", "scripts/player_controller.gd", "project.godot", "scripts/interior_builder.gd"}}
for relative, expected in protected.items():
    actual = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"Protected baseline file changed: {relative}")
print(f"PASS: {len(protected)} protected baseline files unchanged", flush=True)
run("import", ["godot", "--headless", "--editor", "--path", str(ROOT), "--quit"])
run("road-safety", [sys.executable, "tools/validate_road_safety.py"], "PASS: checked 336 road segments")
run("gameplay", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/gameplay_regression.gd"], "GAMEPLAY REGRESSION:")
run("traffic", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/traffic_regression.gd"],
    "0 failures (seed 14014, 60 Hz)", allow_safe_wait=True)
run("reservations", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/traffic_reservation_regression.gd"],
    "25 checks, 0 failures")
run("long-traffic", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/traffic_long_run.gd", "--", "--seconds=300"],
    "13 checks, 0 failures (300s, seed 14014, 60 Hz)", timeout=300)
run("occupied-traffic", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/traffic_long_run.gd", "--", "--seconds=300", "--held-passenger"],
    "14 checks, 0 failures (300s, seed 14014, 60 Hz)", timeout=300)
run("mobile-gameplay", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/mobile_gameplay_regression.gd"], "MOBILE GAMEPLAY:", fresh_save=True)
run("ecosystem", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/ecosystem_regression.gd"], "ECOSYSTEM:", fresh_save=True)
run("social-service", [sys.executable, "server/test_app.py"], "OK")
run("social-client", [sys.executable, "tools/test_social_client.py"], "SOCIAL CLIENT: 15 checks, 0 failures")
run("arcade-traffic", ["godot", "--headless", "--path", str(ROOT), "--script", "tools/arcade_traffic_regression.gd"], "ARCADE TRAFFIC:", timeout=300)
run("runtime", ["godot", "--headless", "--path", str(ROOT), "--fixed-fps", "60", "--quit-after", "180"])
telemetry = OUT / "traffic.jsonl"
telemetry.unlink(missing_ok=True)
run("debug-runtime", ["godot", "--headless", "--path", str(ROOT), "--fixed-fps", "60", "--quit-after", "180",
                      "--", "--traffic-debug", f"--traffic-log={telemetry}"])
records = [json.loads(line) for line in telemetry.read_text().splitlines()]
assert len(records) >= 2, "Debug runtime did not emit two complete telemetry samples"
expected_ids = {"WEST", "SCIENCE", "GATE_EXPRESS", "HOSTEL_LINK", "CENTRAL_LINK"}
assert all({s["id"] for s in row["services"]} == expected_ids for row in records)
assert all(row["tick"] > records[i - 1]["tick"] for i, row in enumerate(records) if i)
print(f"PASS: debug telemetry ({len(records)} timestamped samples, all five services)")
print("ENVIRONMENT CHECKS PASSED")
