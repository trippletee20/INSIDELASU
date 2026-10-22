#!/usr/bin/env python3
"""Browser auth protocol checks; fixtures never create live player accounts."""
from pathlib import Path
import base64,functools,hashlib,http.server,json,os,shutil,threading,urllib.parse
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(ROOT/'build/web')))
threading.Thread(target=server.serve_forever,daemon=True).start()
base=f'http://127.0.0.1:{server.server_port}'
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path=os.environ.get('PLAYWRIGHT_CHROMIUM_EXECUTABLE') or (None if os.environ.get('GITHUB_ACTIONS') else shutil.which('chromium')),args=['--no-sandbox','--disable-dev-shm-usage'])
  state={'username':'','google':True,'challenge':''};calls=[];errors=[]
  def mock(route):
   url=urllib.parse.urlparse(route.request.url);query=urllib.parse.parse_qs(url.query);payload=route.request.post_data_json or {};calls.append((url.path,payload))
   path=url.path;result={};code=200
   if path=='/auth/v1/settings':result={'external':{'google':state['google']}}
   elif path=='/auth/v1/authorize':
    assert query['redirect_to']==[base+'/auth/callback.html'] and query['code_challenge_method']==['s256']
    state['challenge']=query['code_challenge'][0]
    route.fulfill(status=302,headers={'location':base+'/auth/callback.html?code=fixture-code'});return
   elif path=='/auth/v1/token':
    if query['grant_type']==['pkce']:
     assert payload['auth_code']=='fixture-code'
     digest=base64.urlsafe_b64encode(hashlib.sha256(payload['code_verifier'].encode()).digest()).decode().rstrip('=')
     assert digest==state['challenge'],'PKCE verifier must match original challenge'
    else:assert query['grant_type']==['password']
    result={'access_token':'valid-fixture','refresh_token':'refresh-fixture','expires_in':3600}
   elif path=='/auth/v1/user':
    if route.request.headers.get('authorization')!='Bearer valid-fixture':code=401;result={'msg':'Invalid session'}
    else:result={'id':'fixture-id','email':'private@example.test'}
   elif path=='/rest/v1/rpc/lasu_api':
    assert payload['route']=='/profile'
    if payload['payload'].get('username'):state['username']=payload['payload']['username']
    result={'username':state['username']} if state['username'] else {'error':'Choose a username: 3–24 letters'}
   elif path=='/auth/v1/signup':
    assert query['redirect_to']==[base+'/auth/callback.html']
    assert 'data' not in payload,'username is chosen after authentication'
    result={'user':{'id':'email-pending'}}
   elif path=='/auth/v1/resend':
    assert query['redirect_to']==[base+'/auth/callback.html'] and payload['type']=='signup'
   else:raise AssertionError(path)
   route.fulfill(status=code,json=result)
  def fresh():
   page=browser.new_page(viewport={'width':393,'height':873});page.on('pageerror',lambda error:errors.append(str(error)))
   page.route('https://mwuagoxsbsayftvmyitb.supabase.co/**',mock)
   page.route('**/play/index.html*',lambda route:route.fulfill(body='<h1>Campus reached</h1>',content_type='text/html'))
   return page
  page=fresh();resources=[];page.on('request',lambda r:resources.append(r.url));page.goto(base+'/auth.html')
  assert not any('.wasm' in u or '.pck' in u for u in resources),'Sign-in must not download the engine'
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  page.screenshot(path=str(ROOT/'test-results/modern-auth-mobile.png'),full_page=True)
  page.get_by_role('button',name='Continue with Google').click()
  page.get_by_label('Username',exact=True).wait_for();page.get_by_label('Username',exact=True).fill('campus_star')
  page.get_by_role('button',name='Save username & enter campus').click();page.get_by_role('heading',name='Campus reached').wait_for()
  saved=page.evaluate("JSON.parse(sessionStorage.getItem('lasu.social.session'))")
  assert saved['username']=='campus_star' and saved['access_token']=='valid-fixture'
  assert 'token' not in page.url and 'fixture-code' not in page.url
  page.close()
  page=fresh();page.goto(base+'/auth/callback.html?error=access_denied&error_description=Consent+declined')
  page.get_by_role('status').filter(has_text='Consent declined').wait_for();assert '?' not in page.url
  page.close()
  page=fresh();page.goto(base+'/auth/callback.html#access_token=forged&refresh_token=invalid')
  page.get_by_role('status').filter(has_text='Invalid session').wait_for();assert '#' not in page.url
  assert page.evaluate("sessionStorage.getItem('lasu.social.session')") is None
  page.close()
  page=fresh();page.goto(base+'/#access_token=valid-fixture&refresh_token=refresh-fixture')
  page.get_by_role('heading',name='Campus reached').wait_for();assert '#' not in page.url
  page.close()
  state['google']=False
  page=fresh();page.goto(base+'/auth.html');page.get_by_role('button',name='Continue with Google').click()
  page.get_by_role('status').filter(has_text='not been enabled').wait_for()
  page.get_by_role('button',name='New here? Create an account').click()
  page.get_by_label('Email address').fill('new@example.test');page.get_by_label('Password',exact=True).fill('fresh-fixture-password')
  page.get_by_role('button',name='Create account',exact=True).click();page.get_by_role('status').filter(has_text='Check your email').wait_for()
  page.get_by_role('button',name='Resend confirmation email').click();page.get_by_role('status').filter(has_text='Confirmation requested').wait_for()
  assert not errors,errors
  print('AUTH WEB PASSED: lightweight mobile page; Google PKCE; username after sign-in; callback errors/forged tokens; old email-link recovery; signup/resend redirects; disabled-provider guidance')
  browser.close()
finally:server.shutdown();server.server_close()
