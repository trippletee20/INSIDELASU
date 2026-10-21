#!/usr/bin/env bash
set -euo pipefail
cd /workspace/INSIDELASU
export XDG_CONFIG_HOME=/workspace/.inside-lasu/config
export XDG_CACHE_HOME=/workspace/.inside-lasu/cache
export XDG_DATA_HOME=/workspace/.inside-lasu/data
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
# The cloud base image already supplies the official engine. No plugins or
# third-party packages are required. Keep the tested engine version explicit.
python3 - <<'PY'
from pathlib import Path
import re, subprocess
pin = Path('.godot-version').read_text().strip()
version = subprocess.check_output(['godot', '--version'], text=True).strip()
if not version.startswith(pin + '.stable.'):
    raise SystemExit(f'Requires Godot {pin} stable from the cloud base image; found {version}')
result = subprocess.run(['godot', '--headless', '--editor', '--path', '.', '--quit'],
                        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
print(result.stdout, end='')
if result.returncode:
    raise SystemExit(result.returncode)
if re.search(r'(?m)^(SCRIPT ERROR:|ERROR:)', result.stdout):
    raise SystemExit('Godot import failed; inspect engine output above')
PY
