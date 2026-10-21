#!/usr/bin/env python3
"""Static road-safety audit for Inside LASU Godot project.
Checks road centreline segments against protected campus feature footprints with a configurable clearance.
Run from project root: python tools/validate_road_safety.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = json.loads((ROOT / "data/campus_layout.json").read_text(encoding="utf-8"))
ROADS = json.loads((ROOT / "data/road_network_v0.4.json").read_text(encoding="utf-8"))
CLEARANCE = 1.2
FEATURES = [f for f in LAYOUT.get("features", []) if f.get("kind") not in ("landmark", "unverified")]

def segment_hits_rect(a, b, centre, size, margin):
    min_x, max_x = centre[0] - size[0] / 2 - margin, centre[0] + size[0] / 2 + margin
    min_y, max_y = centre[1] - size[1] / 2 - margin, centre[1] + size[1] / 2 + margin
    dx, dy = b[0] - a[0], b[1] - a[1]
    t_min, t_max = 0.0, 1.0
    for p, q in ((-dx, a[0] - min_x), (dx, max_x - a[0]), (-dy, a[1] - min_y), (dy, max_y - a[1])):
        if abs(p) < 1e-9:
            if q < 0:
                return False
        else:
            ratio = q / p
            if p < 0:
                if ratio > t_max:
                    return False
                t_min = max(t_min, ratio)
            else:
                if ratio < t_min:
                    return False
                t_max = min(t_max, ratio)
            if t_min > t_max:
                return False
    return t_min <= t_max

conflicts = []
segments_checked = 0
for route in ROADS.get("road_routes", []):
    points = route.get("points", [])
    for index, (a, b) in enumerate(zip(points, points[1:])):
        segments_checked += 1
        for feature in FEATURES:
            if segment_hits_rect(a, b, feature["position"], feature["size"], CLEARANCE):
                conflicts.append((route.get("id"), index, feature.get("name")))
if conflicts:
    print(f"FAIL: {len(conflicts)} unsafe route/feature intersections:")
    for route_id, index, name in conflicts:
        print(f"  route {route_id}, segment {index}: intersects {name}")
    raise SystemExit(1)
print(f"PASS: checked {segments_checked} road segments against {len(FEATURES)} protected campus footprints; no conflicts at {CLEARANCE} map-unit clearance.")
