#!/usr/bin/env python3
"""Export a single-thread browser build that needs no special hosting headers."""
from pathlib import Path
import os
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/web"
OUT.mkdir(parents=True, exist_ok=True)
(ROOT / "build/.gdignore").touch()
for generated_import in OUT.glob("*.import"):
    generated_import.unlink()
(OUT / "play").mkdir(exist_ok=True)
env = os.environ.copy()
for key, directory in [("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"), ("XDG_DATA_HOME", "data")]:
    env.setdefault(key, f"/workspace/.inside-lasu/{directory}")
    Path(env[key]).mkdir(parents=True, exist_ok=True)
version = subprocess.check_output(["godot", "--version"], env=env, text=True).strip()
if not version.startswith("4.6.3.stable."):
    raise SystemExit("Godot 4.6.3 stable and matching web templates are required")
for args in [["--headless", "--editor", "--path", str(ROOT), "--quit"],
             ["--headless", "--path", str(ROOT), "--export-release", "Web", str(OUT / "play/index.html")]]:
    result = subprocess.run(["godot", *args], env=env, cwd=ROOT, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    print(result.stdout, end="")
    if result.returncode or re.search(r"(?m)^(SCRIPT ERROR:|ERROR:)", result.stdout):
        raise SystemExit(result.returncode or 1)
# A changed game pack gets a new URL, so returning phones do not reuse an old
# cached keyboard-only pack. Keep index.pck for existing cached launch pages.
pack = OUT / "play/index.pck"
pack_name = "campus-" + hashlib.sha256(pack.read_bytes()).hexdigest()[:16] + ".pck"
for old_pack in (OUT / "play").glob("campus-*.pck"):
    old_pack.unlink()
shutil.copy2(pack, OUT / "play" / pack_name)
html_path = OUT / "play/index.html"
html = html_path.read_text()
match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
assert match, "Exported engine config was not found"
config = json.loads(match.group(1))
config["mainPack"] = pack_name
config["fileSizes"][pack_name] = pack.stat().st_size
html = html[:match.start(1)] + json.dumps(config, separators=(",", ":")) + html[match.end(1):]
html_path.write_text(html)
for path in (ROOT / "web").iterdir():
    if path.is_file() and path.suffix in {".html", ".css", ".svg", ".txt", ".js", ".png", ".json"}:
        shutil.copy2(path, OUT / path.name)
shutil.copy2(ROOT / "assets/map_reference/Inside_LASU_Master_Map_Vector_Trace_v0.2.png", OUT / "campus.png")
(OUT / ".nojekyll").write_text("")
for name in ["index.html", "index.js", "index.wasm", "index.pck"]:
    assert (OUT / "play" / name).stat().st_size > 0, name
print("WEB BUILD READY:", OUT)
