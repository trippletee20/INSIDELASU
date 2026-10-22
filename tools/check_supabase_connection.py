#!/usr/bin/env python3
"""Read-only check of public Supabase configuration. Never creates live users."""
import json
from pathlib import Path
import urllib.error
import urllib.request
config=json.loads((Path(__file__).resolve().parents[1]/'data/social_config.json').read_text())
headers={'apikey':config['publishable_key'],'Content-Type':'application/json'}
request=urllib.request.Request(config['supabase_url']+'/auth/v1/settings',headers=headers)
with urllib.request.urlopen(request,timeout=30) as response:
 settings=json.load(response)
 assert settings.get('external',{}).get('email'), 'Email authentication is disabled'
print('SUPABASE PUBLIC CONNECTION PASSED: project URL and publishable key accepted; email authentication enabled')
request=urllib.request.Request(config['supabase_url']+'/rest/v1/rpc/lasu_health',data=b'{}',headers=headers)
try:
 with urllib.request.urlopen(request,timeout=30) as response:
  health=json.load(response)
  assert health.get('service')=='Inside LASU Supabase social' and health.get('version')==1
  print('SUPABASE DATABASE: setup installed; live two-account verification remains required')
except urllib.error.HTTPError as error:
 if error.code==404:
  print('SUPABASE DATABASE: owner SQL installation pending; game requests stay gated')
 else: raise
