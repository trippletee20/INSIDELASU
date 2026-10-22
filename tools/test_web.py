#!/usr/bin/env python3
"""Exercise the exported game in a real browser, including IndexedDB save/reload."""
from pathlib import Path
import functools
import http.server
import json
import os
import shutil
import threading
import time
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results"
OUT.mkdir(exist_ok=True)

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=str(ROOT / "build/web")))
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_port}"
SAVE = """async () => {
 const databases = await indexedDB.databases();
 for (const info of databases) {
   const db = await new Promise((resolve,reject) => {const r=indexedDB.open(info.name);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
   if (!db.objectStoreNames.contains('FILE_DATA')) {db.close();continue;}
   const entries=await new Promise((resolve,reject)=>{const r=db.transaction('FILE_DATA','readonly').objectStore('FILE_DATA').getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
   db.close();
   for(const item of entries) {if(!item.contents)continue;try {const v=JSON.parse(new TextDecoder().decode(item.contents));if(v.profile?.student_name==='Browser Beta Player')return v;}catch(e){}}
 } return null;
}"""

def saved(page):
    deadline = time.monotonic() + 40
    while time.monotonic() < deadline:
        value = page.evaluate(SAVE)
        if value:
            return value
        page.wait_for_timeout(1000)
    raise AssertionError("Browser profile was not persisted in IndexedDB")

try:
    with sync_playwright() as p:
        executable = os.environ.get("PLAYWRIGHT_CHROMIUM_EXECUTABLE")
        if not executable and not os.environ.get("GITHUB_ACTIONS"):
            executable = shutil.which("chromium")
        browser = p.chromium.launch(executable_path=executable, headless=True,
            args=["--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        page = browser.new_page(viewport={"width": 1280, "height": 720})
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
        page.goto(base, wait_until="networkidle")
        assert page.get_by_role("link", name="Enter campus").count() == 1
        page.screenshot(path=str(OUT / "browser-landing.png"), full_page=True)
        page.get_by_role("link", name="Enter campus").click()
        page.wait_for_load_state("networkidle", timeout=120000)
        page.wait_for_timeout(14000)
        page.screenshot(path=str(OUT / "browser-profile.png"))
        page.keyboard.type("Browser Beta Player", delay=80)
        for _ in range(6):
            page.keyboard.press("Tab")
        page.keyboard.press("Enter")
        profile = saved(page)
        assert profile["profile"]["first_session_rent_paid"] is True
        assert profile["wallet_balance"] == profile["profile"]["starting_balance"]
        page.wait_for_timeout(1500)
        page.keyboard.press("b", delay=150)
        page.wait_for_timeout(1500)
        page.screenshot(path=str(OUT / "browser-wallet-open.png"))
        page.keyboard.press("Enter", delay=150)
        page.wait_for_timeout(3500)
        page.screenshot(path=str(OUT / "browser-wallet-claim.png"))
        reward = saved(page)
        deadline = time.monotonic() + 20
        while reward["wallet_balance"] == profile["wallet_balance"] and time.monotonic() < deadline:
            page.wait_for_timeout(1000)
            reward = saved(page)
        award = reward["wallet_balance"] - profile["wallet_balance"]
        assert 500 <= award <= 1500, f"Daily support not credited exactly once: {award}"
        assert reward["transactions"][-1]["source"] == "Daily support"
        page.screenshot(path=str(OUT / "browser-wallet.png"))
        page.keyboard.press("Escape")
        page.keyboard.down("w")
        page.wait_for_timeout(1200)
        page.keyboard.up("w")
        page.keyboard.press("h")
        page.wait_for_timeout(500)
        page.screenshot(path=str(OUT / "browser-help.png"))
        page.keyboard.press("Escape")
        page.reload(wait_until="networkidle", timeout=120000)
        page.wait_for_timeout(12000)
        page.screenshot(path=str(OUT / "browser-reloaded.png"))
        reloaded = saved(page)
        assert reloaded["profile"] == reward["profile"]
        assert reloaded["wallet_balance"] == reward["wallet_balance"]
        assert reloaded["transactions"] == reward["transactions"]
        page.keyboard.press("p")
        page.wait_for_timeout(700)
        page.screenshot(path=str(OUT / "browser-student.png"))
        page.keyboard.press("Escape")
        page.set_viewport_size({"width": 800, "height": 600})
        page.keyboard.press("b")
        page.wait_for_timeout(1200)
        page.screenshot(path=str(OUT / "browser-800.png"))
        assert not errors, "Browser runtime errors: " + json.dumps(errors)
        result = {"result": "passed", "engine": "Godot 4.6.3 single-thread web", "profile_created": True,
                  "daily_support": award, "browser_save_reloaded": True, "viewports": ["1280x720", "800x600"], "errors": errors}
        (OUT / "browser-results.json").write_text(json.dumps(result, indent=2) + "\n")
        print("BROWSER CHECKS PASSED: landing, profile creation, daily support, receipts, save/reload, keyboard menus, resize")
        browser.close()
finally:
    server.shutdown()
