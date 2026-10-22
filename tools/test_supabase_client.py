#!/usr/bin/env python3
"""Protocol fixture for real Godot HTTP; real SQL permissions tested separately."""
import json, os, subprocess, tempfile, threading
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
ROOT=Path(__file__).resolve().parents[1]
CALLS=[]
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_POST(self):
  assert self.headers.get('apikey')=='sb_publishable_test'
  payload=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  CALLS.append((self.path,payload))
  result={};code=200
  if self.path.startswith('/missing/'):
   code=404;result={'message':'Function not found'}
  elif self.path=='/rest/v1/rpc/lasu_health': result={'service':'Inside LASU Supabase social','version':1}
  elif self.path=='/auth/v1/signup': result={'user':{'id':'confirmation-required'}}
  elif self.path.startswith('/auth/v1/token?'):
   refresh='refresh_token' in self.path
   if refresh: assert payload['refresh_token']=='refresh-fixture'
   else: assert payload['email']=='student@example.test' and payload['password']=='new-test-password'
   result={'access_token':'refreshed-token' if refresh else 'session-token','refresh_token':'refresh-fixture','expires_in':3600,'user':{'user_metadata':{'username':'student'}}}
  elif self.path=='/rest/v1/rpc/lasu_api':
   assert self.headers['Authorization'] in ('Bearer session-token','Bearer refreshed-token')
   route=payload['route'];data=payload['payload']
   if route=='/profile': result={'username':'student'}
   elif route=='/users':
    assert data=={'q':'study'};result={'users':[{'username':'study_partner'}]}
   elif route=='/messages/send':
    assert data['body']=='Hello from Godot';result={'ok':True}
   elif route=='/messages/read':
    assert data=={'to':'study_partner'};result={'messages':[{'sender':'student','body':'Hello from Godot','created':1}]}
   elif route=='/relationship':
    assert data['kind']=='BFFs';result={'ok':True}
   elif route=='/presence':
    assert data['location'].startswith('private:');result={'peers':[]}
   else: raise AssertionError(route)
  elif self.path=='/auth/v1/logout': result={'ok':True}
  else: raise AssertionError(self.path)
  body=json.dumps(result).encode();self.send_response(code);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with tempfile.TemporaryDirectory(prefix='lasu-supabase-client-') as temp:
  env=os.environ.copy();env['INSIDE_LASU_TEST']='1';env['INSIDE_LASU_SUPABASE_TEST_URL']=f'http://127.0.0.1:{server.server_port}'
  for key,suffix in [('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('XDG_DATA_HOME','data')]: env[key]=str(Path(temp)/suffix)
  result=subprocess.run(['godot','--headless','--path',str(ROOT),'--script','tools/supabase_client_regression.gd'],env=env,cwd=ROOT,text=True,capture_output=True,timeout=90)
  print(result.stdout+result.stderr)
  assert result.returncode==0 and 'SCRIPT ERROR:' not in result.stdout+result.stderr and 'SUPABASE CLIENT: 12 checks, 0 failures' in result.stdout
  assert sum(path=='/auth/v1/signup' for path,_ in CALLS)==1,'missing migration must not create Auth users'
  print('SUPABASE HTTP PROTOCOL PASSED')
finally:
 server.shutdown();server.server_close()
