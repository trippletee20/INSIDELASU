#!/usr/bin/env python3
"""Export a single-thread browser build that needs no special hosting headers."""
from pathlib import Path
import os
import hashlib
import gzip
import urllib.request
import time
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
previous_pack = None
try:
    with urllib.request.urlopen("https://trippletee20.github.io/INSIDELASU/play/index.html?build=" + str(int(time.time())), timeout=15) as response:
        previous_html = response.read().decode()
    previous_config = json.loads(re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", previous_html).group(1))
    previous_name = previous_config.get("mainPack", "")
    if re.fullmatch(r"campus-[a-f0-9]{16}\.pck", previous_name):
        with urllib.request.urlopen("https://trippletee20.github.io/INSIDELASU/play/" + previous_name, timeout=30) as response:
            previous_bytes = response.read()
        if hashlib.sha256(previous_bytes).hexdigest()[:16] == previous_name[7:23]:
            previous_pack = (previous_name, previous_bytes)
except Exception as error:
    print("Previous published pack unavailable; proceeding with current build:", type(error).__name__)
for old_pack in (OUT / "play").glob("campus-*.pck"):
    old_pack.unlink()
shutil.copy2(pack, OUT / "play" / pack_name)
(OUT / "play" / (pack_name + ".gz")).write_bytes(gzip.compress(pack.read_bytes(), compresslevel=9, mtime=0))
if previous_pack is not None and previous_pack[0] != pack_name:
    (OUT / "play" / previous_pack[0]).write_bytes(previous_pack[1])
html_path = OUT / "play/index.html"
html = html_path.read_text()
match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
assert match, "Exported engine config was not found"
config = json.loads(match.group(1))
config["mainPack"] = pack_name
config["fileSizes"][pack_name] = pack.stat().st_size
# Fingerprint the engine as well as the game pack. These immutable URLs can
# safely persist across visits and game releases without stale launcher caching.
wasm = OUT / "play/index.wasm"
engine_stem = "engine-" + hashlib.sha256(wasm.read_bytes()).hexdigest()[:16]
shutil.copy2(wasm, OUT / "play" / (engine_stem + ".wasm"))
compressed = gzip.compress(wasm.read_bytes(), compresslevel=9, mtime=0)
(OUT / "play" / (engine_stem + ".wasm.gz")).write_bytes(compressed)
print("ENGINE DOWNLOAD:", len(compressed), "compressed bytes /", wasm.stat().st_size, "original bytes")
for worklet in (OUT / "play").glob("index.audio*.js"):
    shutil.copy2(worklet, OUT / "play" / (engine_stem + worklet.name[len("index"):]))
js = OUT / "play/index.js"
js_name = "runtime-" + hashlib.sha256(js.read_bytes()).hexdigest()[:16] + ".js"
shutil.copy2(js, OUT / "play" / js_name)
config["executable"] = engine_stem
config["fileSizes"][engine_stem + ".wasm"] = wasm.stat().st_size
shell = (ROOT / "web/play-shell.html").read_text()
html_path.write_text(shell.replace("__RUNTIME_JS__", js_name).replace("__GODOT_CONFIG__", json.dumps(config, separators=(",", ":"))))
shutil.copytree(ROOT / "web/auth", OUT / "auth", dirs_exist_ok=True)
for path in (ROOT / "web").iterdir():
    if path.name != "play-shell.html" and path.is_file() and path.suffix in {".html", ".css", ".svg", ".txt", ".js", ".png", ".json"}:
        shutil.copy2(path, OUT / path.name)
(OUT / "play-shell.html").unlink(missing_ok=True)
shutil.copy2(ROOT / "supabase/migrations/001_campus_social.sql", OUT / "setup-social.sql")
shutil.copy2(ROOT / "assets/map_reference/Inside_LASU_Master_Map_Vector_Trace_v0.2.png", OUT / "campus.png")
(OUT / ".nojekyll").write_text("")
for name in ["index.html", "index.js", "index.wasm", "index.pck"]:
    assert (OUT / "play" / name).stat().st_size > 0, name
print("WEB BUILD READY:", OUT)
