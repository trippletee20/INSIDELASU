#!/usr/bin/env python3
"""Touch browser acceptance. Chromium emulation is not physical Android certification."""
from pathlib import Path
import functools
import http.server
import json
import os
import shutil
import threading
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get('INSIDE_LASU_TEST_OUTPUT', str(ROOT / 'test-results/mobile')))
OUT.mkdir(parents=True, exist_ok=True)
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=str(ROOT / 'build/web')))
threading.Thread(target=server.serve_forever, daemon=True).start()
base = os.environ.get('INSIDE_LASU_TEST_URL', f'http://127.0.0.1:{server.server_port}').rstrip('/')
SAVE = """async () => {
 for (const info of await indexedDB.databases()) {
  const db=await new Promise((resolve,reject)=>{const r=indexedDB.open(info.name);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
  if (!db.objectStoreNames.contains('FILE_DATA')) {db.close();continue;}
  const entries=await new Promise((resolve,reject)=>{const r=db.transaction('FILE_DATA','readonly').objectStore('FILE_DATA').getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
  db.close();
  for (const item of entries) {if(!item.contents)continue;try {const v=JSON.parse(new TextDecoder().decode(item.contents));if(v.profile?.student_name==='Mobile Beta Player')return v;}catch(e){}}
 } return null;
}"""
def saved(page, predicate=lambda value: True):
    for _ in range(50):
        value = page.evaluate(SAVE)
        if value and predicate(value):
            return value
        page.wait_for_timeout(500)
    raise AssertionError('Expected mobile profile state was not persisted')

try:
    with sync_playwright() as p:
        executable = os.environ.get('PLAYWRIGHT_CHROMIUM_EXECUTABLE')
        if not executable and not os.environ.get('GITHUB_ACTIONS'):
            executable = shutil.which('chromium')
        browser = p.chromium.launch(executable_path=executable, args=['--no-sandbox','--disable-dev-shm-usage','--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
        page = browser.new_page(viewport={'width':393,'height':873}, is_mobile=True, has_touch=True, device_scale_factor=3)
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
        page.goto(base + '/play/index.html', wait_until='networkidle', timeout=120000)
        page.wait_for_timeout(14000)
        assert page.locator('canvas').evaluate('(x)=>x.width === 393 && x.height === 873'), 'High-DPI display changed logical control size'
        page.screenshot(path=str(OUT / 'profile-portrait.png'))
        page.touchscreen.tap(160,300)
        page.wait_for_timeout(500)
        assert page.locator('input').evaluate('(x)=>document.activeElement===x'), 'Phone text input did not focus'
        # Text insertion represents the phone software keyboard; gameplay below uses touch only.
        page.keyboard.insert_text('Mobile Beta Player')
        page.touchscreen.tap(100,350)
        cdp = page.context.new_cdp_session(page)
        def fingers(kind, points):
            cdp.send('Input.dispatchTouchEvent', {'type':kind, 'touchPoints':[{'id':i,'x':x,'y':y} for i,x,y in points]})
        fingers('touchStart', [(0,300,680)])
        for y in range(650,210,-25):
            fingers('touchMove', [(0,300,y)])
            page.wait_for_timeout(25)
        fingers('touchEnd', [])
        page.wait_for_timeout(1000)
        page.screenshot(path=str(OUT / 'profile-scrolled.png'))
        page.touchscreen.tap(180,662)
        page.wait_for_timeout(2000)
        before = saved(page)
        assert before['profile']['first_session_rent_paid']
        assert before['wallet_balance'] == before['profile']['starting_balance']
        page.screenshot(path=str(OUT / 'game-portrait.png'))
        fingers('touchStart', [(0,88,738)])
        fingers('touchMove', [(0,88,684)])
        fingers('touchStart', [(0,88,684),(1,220,440)])
        for x in range(225,290,5):
            fingers('touchMove', [(0,88,684),(1,x,440)])
            page.wait_for_timeout(30)
        # A third finger can press Jump while movement and looking remain held.
        fingers('touchStart', [(0,88,684),(1,285,440),(2,313,808)])
        page.wait_for_timeout(100)
        fingers('touchEnd', [(0,88,684),(1,285,440)])
        fingers('touchEnd', [(0,88,684)])
        page.wait_for_timeout(5000)
        fingers('touchEnd', [])
        page.wait_for_timeout(500)
        assert not page.evaluate('!!document.pointerLockElement'), 'Phone requested mouse lock'
        page.screenshot(path=str(OUT / 'game-after-touch-movement.png'))
        page.touchscreen.tap(215,47)  # Wallet in the fixed touch toolbar.
        page.wait_for_timeout(1000)
        page.screenshot(path=str(OUT / 'wallet-portrait.png'))
        page.touchscreen.tap(330,185)  # Close; commits current stats to IndexedDB.
        after = saved(page, lambda value: value['energy'] < before['energy'] - 0.01)
        assert after['wallet_balance'] == before['wallet_balance']
        page.touchscreen.tap(332,50)  # Map.
        page.wait_for_timeout(600)
        page.screenshot(path=str(OUT / 'map-portrait.png'))
        page.touchscreen.tap(332,50)
        page.set_viewport_size({'width':873,'height':393})
        page.wait_for_timeout(1000)
        page.screenshot(path=str(OUT / 'game-landscape.png'))
        page.touchscreen.tap(824,50)
        page.wait_for_timeout(500)
        page.touchscreen.tap(824,50)
        page.reload(wait_until='networkidle')
        page.wait_for_timeout(14000)
        reloaded = saved(page)
        assert reloaded['profile'] == after['profile']
        assert reloaded['wallet_balance'] == after['wallet_balance']
        assert not page.evaluate('!!document.pointerLockElement')
        page.screenshot(path=str(OUT / 'reloaded-landscape.png'))
        assert not errors, errors
        result = {'target':'Chromium mobile touch emulation; physical Android testing still required', 'device_pixel_ratio':3, 'viewports':['393x873','873x393'], 'profile_created_with_software_text_input':True, 'simultaneous_move_look_and_action':True, 'movement_energy_before':before['energy'], 'movement_energy_after':after['energy'], 'save_reloaded':True, 'pointer_lock':False, 'errors':errors}
        (OUT / 'results.json').write_text(json.dumps(result, indent=2))
        print('MOBILE BROWSER PASSED: profile form, touch scroll, multi-finger gameplay, movement stats, menus, map, rotation, save/reload, no mouse lock')
        browser.close()
finally:
    server.shutdown()
