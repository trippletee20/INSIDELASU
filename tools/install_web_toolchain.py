#!/usr/bin/env python3
"""Install official Godot web tools, verifying the published SHA512 checksums."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("--downloads", type=Path, required=True)
parser.add_argument("--bin", type=Path, required=True)
args = parser.parse_args()
args.downloads.mkdir(parents=True, exist_ok=True)
args.bin.mkdir(parents=True, exist_ok=True)
ASSETS = {
    "Godot_v4.6.3-stable_linux.x86_64.zip": "a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c",
    "Godot_v4.6.3-stable_export_templates.tpz": "da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68",
}
def digest(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha512").hexdigest()

for name, expected in ASSETS.items():
    path = args.downloads / name
    if not path.exists():
        partial = path.with_suffix(path.suffix + ".partial")
        print("Downloading official", name, flush=True)
        with urllib.request.urlopen("https://github.com/godotengine/godot/releases/download/4.6.3-stable/" + name, timeout=180) as response, partial.open("wb") as file:
            shutil.copyfileobj(response, file)
        if digest(partial) != expected:
            raise SystemExit("Official SHA512 verification failed: " + name)
        partial.rename(path)
    if digest(path) != expected:
        raise SystemExit("Cached archive failed SHA512 verification: " + name)
    with zipfile.ZipFile(path) as archive:
        if name.endswith(".tpz"):
            target = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/export_templates/4.6.3.stable"
            target.mkdir(parents=True, exist_ok=True)
            for member in ["web_nothreads_release.zip", "web_nothreads_debug.zip"]:
                (target / member).write_bytes(archive.read("templates/" + member))
        else:
            executable = args.bin / "godot"
            executable.write_bytes(archive.read("Godot_v4.6.3-stable_linux.x86_64"))
            executable.chmod(0o755)
    print("Verified and installed", name, flush=True)
