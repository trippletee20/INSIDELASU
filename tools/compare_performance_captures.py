#!/usr/bin/env python3
"""Compare three-run browser performance captures made on the same CI runner."""
import argparse
import json
import statistics
from pathlib import Path

STAGES = ("campus_idle", "campus_walk", "phone", "interior")

def summarise(capture):
    if capture.get("status") != "captured" or len(capture.get("runs", [])) != 3:
        raise ValueError("Each build must have exactly three complete runs")
    runs = capture["runs"]
    stages = {}
    for stage in STAGES:
        samples = [run["stages"][stage] for run in runs]
        stages[stage] = {
            "fps_median": statistics.median(item["fps_median"] for item in samples),
            "draw_calls_peak": max(item["draw_calls_peak"] for item in samples),
            "video_memory_peak_bytes": max(item["video_memory_peak_bytes"] for item in samples),
            "max_frame_ms": max(item["max_frame_ms"] for item in samples),
        }
    pss = [run["browser_pss_peak_bytes"] for run in runs]
    if any(value is None for value in pss):
        raise ValueError("Browser process memory could not be measured in every run")
    # Compare the median of three per-run peaks. A single transient OS/browser
    # allocation can inflate one peak without representing a repeatable game cost.
    return {
        "stages": stages,
        "cold_world_ready_ms": statistics.median(run["cold_world_ready_ms"] for run in runs),
        "cold_architecture_ready_ms": statistics.median(run["cold_boot"]["architectureReadyAt"] for run in runs),
        "warm_world_ready_ms": statistics.median(run["warm_boot"]["worldReadyAt"] for run in runs),
        "browser_pss_peak_bytes": statistics.median(pss),
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--web-root", type=Path, default=Path("build/web/play"))
    parser.add_argument("--budget", type=Path, default=Path("docs/performance_budget.json"))
    args = parser.parse_args()
    baseline_data = json.loads(args.baseline.read_text())
    candidate_data = json.loads(args.candidate.read_text())
    if baseline_data.get("profile") != candidate_data.get("profile"):
        raise SystemExit("Baseline and NPC captures used different phone/network profiles")
    if baseline_data.get("environment") != candidate_data.get("environment"):
        raise SystemExit("Baseline and NPC captures must use the same browser, host and renderer")
    baseline = summarise(baseline_data)
    candidate = summarise(candidate_data)
    errors = []
    for stage in STAGES:
        old, new = baseline["stages"][stage], candidate["stages"][stage]
        if new["fps_median"] < old["fps_median"] * 0.95:
            errors.append(f"{stage}: median FPS dropped by more than 5%")
        for metric in ("draw_calls_peak", "video_memory_peak_bytes", "max_frame_ms"):
            if new[metric] > old[metric] * 1.05:
                errors.append(f"{stage}: {metric} increased by more than 5%")
    for metric in ("cold_world_ready_ms", "cold_architecture_ready_ms", "warm_world_ready_ms", "browser_pss_peak_bytes"):
        if candidate[metric] > baseline[metric] * 1.05:
            errors.append(f"{metric} increased by more than 5%")
    npc_counts = [
        sample.get("npc_count", 0)
        for run in candidate_data["runs"]
        for sample in run.get("samples", [])
        if sample.get("stage") in ("campus_idle", "campus_walk")
    ]
    if not npc_counts or max(npc_counts) > 16 or max(npc_counts) <= 0:
        errors.append("Medium-quality campus NPC count is missing or exceeds the 16-character cap")
    budget = json.loads(args.budget.read_text())
    for name, limit in budget["exported_byte_caps"].items():
        if name == "index.pck.gz":
            import gzip
            size = len(gzip.compress((args.web_root / "index.pck").read_bytes(), compresslevel=9, mtime=0))
        else:
            size = (args.web_root / name).stat().st_size
        if size > limit:
            errors.append(f"{name} exceeds the recorded download-size cap")
    if errors:
        raise SystemExit("\n".join(errors))
    print("SAME-RUN NPC PERFORMANCE PASSED: three baseline runs, three NPC runs, 16-NPC medium cap, no regression beyond 5%, download caps respected")

if __name__ == "__main__":
    main()
