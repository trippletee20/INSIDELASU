#!/usr/bin/env python3
"""Exercise first-mount permissions, restart persistence and dropped privileges."""
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
import uuid

suffix = uuid.uuid4().hex[:10]
container, volume = 'inside-lasu-check-' + suffix, 'inside-lasu-check-' + suffix
env = os.environ.copy()
env.setdefault('DOCKER_CONFIG', str(Path(__file__).resolve().parents[1] / 'test-results/docker-config'))

def docker(*args):
    return subprocess.check_output(['docker', *args], env=env, text=True).strip()

try:
    docker('volume', 'create', volume)
    docker('run', '-d', '--name', container, '-p', '127.0.0.1::8080', '-v', volume + ':/data', 'inside-lasu-social:beta')
    port = docker('port', container, '8080/tcp').rsplit(':', 1)[1]
    base = 'http://127.0.0.1:' + port
    def ready():
        for _ in range(30):
            try:
                with urllib.request.urlopen(base + '/health', timeout=2) as response:
                    if json.load(response)['status'] == 'ok': return
            except (OSError, ValueError):
                time.sleep(.25)
        print(docker('logs', container))
        raise AssertionError('Container did not become healthy')
    def api(path, body, token=''):
        request = urllib.request.Request(base + path, data=json.dumps(body).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token})
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.load(response)
    ready()
    alice = api('/register', {'username': 'container_alice', 'password': 'container-test-password'})
    bob = api('/register', {'username': 'container_bob', 'password': 'container-test-password'})
    assert api('/messages', {'to': 'container_bob', 'body': 'Persistent reading group'}, alice['token'])['ok']
    process = docker('exec', container, 'cat', '/proc/1/status')
    assert any(line.startswith('Uid:') and line.split()[1] != '0' for line in process.splitlines()), 'Server did not drop root privileges'
    docker('restart', container)
    port = docker('port', container, '8080/tcp').rsplit(':', 1)[1]
    base = 'http://127.0.0.1:' + port
    ready()
    bob = api('/login', {'username': 'container_bob', 'password': 'container-test-password'})
    request = urllib.request.Request(base + '/messages?to=container_alice', headers={'Authorization': 'Bearer ' + bob['token']})
    with urllib.request.urlopen(request, timeout=10) as response:
        assert json.load(response)['messages'][0]['body'] == 'Persistent reading group'
    print('SOCIAL CONTAINER PASSED: clean persistent-volume mount, non-root server, accounts/messages survive restart')
finally:
    subprocess.run(['docker', 'rm', '-f', container], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['docker', 'volume', 'rm', volume], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
