#!/usr/bin/env python3
"""Preview-only advertiser journey: no uploads, checkout or payment requests."""
from pathlib import Path
import functools
import http.server
import os
import shutil
import struct
import zlib
import threading
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results'
OUT.mkdir(exist_ok=True)
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=str(ROOT / 'build/web')))
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=None if os.environ.get('GITHUB_ACTIONS') else shutil.which('chromium'), args=['--no-sandbox'])
        page = browser.new_page(viewport={'width':393, 'height':873}, is_mobile=True, has_touch=True)
        errors, mutations = [], []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('request', lambda request: mutations.append(request.url) if request.method not in ('GET', 'HEAD') else None)
        page.goto(f'http://127.0.0.1:{server.server_port}/advertise.html?slot=AD-050')
        page.wait_for_function("() => document.querySelector('#slot').options.length===100")
        assert page.locator('#slot').input_value() == 'AD-050'
        page.get_by_label('Business name').fill('<img src=x onerror=alert(1)>')
        assert page.locator('#caption').inner_text().startswith('<img src=x onerror=alert(1)>')
        assert page.locator('#caption img').count() == 0
        page.get_by_label('Business name').fill('Campus Creative Studio')
        page.get_by_label('Flutterwave').check()
        page.get_by_label('Campaign length').select_option('14')
        assert 'Flutterwave' in page.locator('#summary').inner_text()
        assert '14-day' in page.locator('#summary').inner_text()
        def chunk(kind, value):
            return struct.pack('>I', len(value)) + kind + value + struct.pack('>I', zlib.crc32(kind + value))
        image = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 840, 400, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress((b'\0' + bytes((36, 122, 112)) * 840) * 400)) + chunk(b'IEND', b'')
        page.locator('#artwork').set_input_files({'name':'business.png', 'mimeType':'image/png', 'buffer':image})
        page.wait_for_function("() => !document.querySelector('#preview').hidden")
        assert page.get_by_role('button', name='Bookings open after launch').is_disabled()
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(OUT / 'advertising-mobile-preview.png'), full_page=True)
        page.locator('#artwork').set_input_files({'name':'unsafe.svg', 'mimeType':'image/svg+xml', 'buffer':b'<svg xmlns="http://www.w3.org/2000/svg"></svg>'})
        assert 'JPG, PNG or WebP' in page.locator('#error').inner_text()
        page.locator('#artwork').set_input_files({'name':'invalid.png', 'mimeType':'image/png', 'buffer':b'not actually an image'})
        page.wait_for_function("() => document.querySelector('#error').textContent.includes('readable image')")
        assert not mutations, f'Preview sent unexpected mutation requests: {mutations}'
        assert not errors, errors
        browser.close()
    print('ADVERTISING PREVIEW PASSED: slot selection, local artwork, provider choice, invalid files, safe captions, mobile fit, no payment/upload requests')
finally:
    server.shutdown()
