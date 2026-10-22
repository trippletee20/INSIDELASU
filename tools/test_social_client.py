#!/usr/bin/env python3
"""Run real Godot HTTP clients against the temporary social service."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import threading
from http.server import ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('campus_client_service', ROOT / 'server/app.py')
service = importlib.util.module_from_spec(spec)
spec.loader.exec_module(service)
with tempfile.TemporaryDirectory(prefix='inside-lasu-social-client-') as state:
    service.DB = str(Path(state) / 'social.sqlite3')
    service.init()
    server = ThreadingHTTPServer(('127.0.0.1', 0), service.Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    env = os.environ.copy()
    env['INSIDE_LASU_TEST'] = '1'
    env['INSIDE_LASU_SOCIAL_TEST_URL'] = f'http://127.0.0.1:{server.server_port}'
    for key, suffix in [('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'), ('XDG_DATA_HOME', 'data')]:
        env[key] = str(Path(state) / suffix)
    try:
        result = subprocess.run(['godot', '--headless', '--path', str(ROOT), '--script', 'tools/social_client_regression.gd'], cwd=ROOT, env=env, capture_output=True, text=True, timeout=90)
        print(result.stdout + result.stderr)
        if result.returncode or 'SCRIPT ERROR:' in result.stdout + result.stderr or 'SOCIAL CLIENT: 15 checks, 0 failures' not in result.stdout:
            raise SystemExit(result.returncode or 1)
    finally:
        server.shutdown()
        server.server_close()
