#!/usr/bin/env python3
"""Real WASM cold/warm starts, compressed transfer and public runtime cache."""
from pathlib import Path
import functools,http.server,json,os,re,shutil,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];requests=[]
class Quiet(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):requests.append(self.path.split('?')[0]);super().do_GET()
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Quiet,directory=str(ROOT/'build/web')))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path=os.environ.get('PLAYWRIGHT_CHROMIUM_EXECUTABLE') or (None if os.environ.get('GITHUB_ACTIONS') else shutil.which('chromium')),args=['--no-sandbox','--disable-dev-shm-usage','--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  page=browser.new_page(viewport={'width':393,'height':873},is_mobile=True,has_touch=True,device_scale_factor=3)
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)));page.on('console',lambda msg:errors.append(msg.text) if msg.type=='error' else None)
  page.goto(f'http://127.0.0.1:{server.server_port}/play/index.html',wait_until='networkidle',timeout=120000)
  page.wait_for_function("window.lasuBootMetrics?.worldReadyAt && document.querySelector('#boot').hidden",timeout=120000)
  cold=page.evaluate('window.lasuBootMetrics')
  page.wait_for_function('window.lasuBootMetrics.architectureReadyAt',timeout=120000)
  assert any(path.endswith('.wasm.gz') for path in requests),'Compressed engine was not used'
  assert not any(path.endswith('.wasm') for path in requests),'Cold start downloaded the large raw engine'
  cache_name=re.search(r"const CACHE='([^']+)'",(ROOT/'build/web/runtime-cache.js').read_text()).group(1)
  cached=page.evaluate("async name=>{const c=await caches.open(name);return (await c.keys()).map(r=>r.url)}",cache_name)
  assert any(url.endswith('.wasm') for url in cached) and any(url.endswith('.pck') for url in cached)
  assert any(path.endswith('.pck.gz') for path in requests),'Compressed game pack was not used'
  assert not any(path.endswith('.pck') for path in requests),'Cold start downloaded the raw game pack'
  asset_suffixes=('.wasm','.wasm.gz','.pck','.pck.gz')
  before=sum(r.endswith(asset_suffixes) for r in requests)
  page.reload(wait_until='networkidle',timeout=120000)
  page.wait_for_function("window.lasuBootMetrics?.worldReadyAt && document.querySelector('#boot').hidden",timeout=120000)
  warm=page.evaluate('window.lasuBootMetrics')
  after=sum(r.endswith(asset_suffixes) for r in requests)
  assert before==after,'Warm visit re-downloaded engine or game pack'
  assert not errors,errors
  result={'cold':cold,'warm':warm,'compressed_engine_bytes':next((ROOT/'build/web/play').glob('engine-*.wasm.gz')).stat().st_size,'raw_engine_bytes':(ROOT/'build/web/play/index.wasm').stat().st_size,'warm_asset_network_requests':after-before,'errors':errors,'target':'local Chromium software-rendered mobile emulation, not physical Android or mobile-network timing'}
  (ROOT/'test-results/modern-loading.json').write_text(json.dumps(result,indent=2)+'\n')
  print('LOADING WEB PASSED: compressed engine, true cold/warm WASM startup, no repeated pack/engine transfer, no browser errors')
  browser.close()
finally:server.shutdown();server.server_close()
