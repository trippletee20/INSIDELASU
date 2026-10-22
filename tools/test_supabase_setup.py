#!/usr/bin/env python3
"""Owner setup UI: exact tested SQL, safe copy, connection states and phone fit."""
from pathlib import Path
import functools,http.server,json,os,shutil,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(ROOT/'build/web')))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path=os.environ.get('PLAYWRIGHT_CHROMIUM_EXECUTABLE') or (None if os.environ.get('GITHUB_ACTIONS') else shutil.which('chromium')),args=['--no-sandbox','--disable-dev-shm-usage'])
  page=browser.new_page(viewport={'width':393,'height':873})
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  page.add_init_script("Object.defineProperty(navigator,'clipboard',{value:{writeText:async value=>{window.copiedSQL=value}}})")
  page.route('https://mwuagoxsbsayftvmyitb.supabase.co/**',lambda route:route.fulfill(status=404,json={'message':'Not installed'}))
  page.goto(f'http://127.0.0.1:{server.server_port}/setup-social.html')
  page.get_by_role('button',name='1. Copy setup SQL').click()
  assert page.evaluate('window.copiedSQL')==(ROOT/'supabase/migrations/001_campus_social.sql').read_text()
  page.get_by_role('button',name='Check connection').click()
  page.get_by_role('status').filter(has_text='not ready yet').wait_for()
  page.unroute('https://mwuagoxsbsayftvmyitb.supabase.co/**')
  page.route('https://mwuagoxsbsayftvmyitb.supabase.co/**',lambda route:route.fulfill(status=200,json={'service':'Inside LASU Supabase social','version':1}))
  page.get_by_role('button',name='Check connection').click()
  page.get_by_role('status').filter(has_text='Database setup found').wait_for()
  assert page.locator('a[href*="/sql/new"]').get_attribute('href').endswith('mwuagoxsbsayftvmyitb/sql/new')
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),'Setup page overflows phone width'
  assert not errors,errors
  print('SUPABASE SETUP PAGE PASSED: exact SQL copied, correct project link, missing/installed states, phone fit, no browser errors')
  browser.close()
finally: server.shutdown();server.server_close()
