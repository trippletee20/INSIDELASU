#!/usr/bin/env python3
"""Connect the game to an already deployed HTTPS service; contains no credentials."""
import argparse
import json
from pathlib import Path
import urllib.parse
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('url', help='Public HTTPS URL from the hosting dashboard')
args = parser.parse_args()
url = args.url.rstrip('/')
parsed = urllib.parse.urlparse(url)
if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path:
    parser.error('Use the HTTPS service origin, without credentials, path, query or fragment')
with urllib.request.urlopen(url + '/health', timeout=20) as response:
    health = json.load(response)
if health.get('status') != 'ok' or health.get('service') != 'Inside LASU social beta':
    raise SystemExit('This endpoint is not the Inside LASU social service')
path = Path(__file__).resolve().parents[1] / 'data/social_config.json'
path.write_text(json.dumps({'server_url': url}, indent=2) + '\n')
print('Service verified. Rebuild and publish the game to enable social accounts.')
