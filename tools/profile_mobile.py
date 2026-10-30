#!/usr/bin/env python3
"""Repeatable mobile-emulation capture; never claim this is physical Android."""
import argparse, functools, http.server, json, statistics, threading, os, time, platform
from pathlib import Path
from playwright.sync_api import sync_playwright

def browser_pss(session):
    """Linux proportional memory of all Chrome processes, including renderer/WASM.
    Resolve namespace PIDs for container hosts. None means unavailable, never zero.
    """
    try:
        ids={p['id'] for p in session.send('SystemInfo.getProcessInfo')['processInfo']}
        namespace=os.readlink('/proc/self/ns/pid')
        found={}
        for proc in Path('/proc').iterdir():
            if not proc.name.isdecimal(): continue
            try:
                if os.readlink(proc/'ns/pid') != namespace: continue
                lines=(proc/'status').read_text().splitlines()
                nsids=next((line.split()[1:] for line in lines if line.startswith('NSpid:')), [])
                pid=int(nsids[-1]) if nsids else int(proc.name)
                if pid in ids:
                    row=next(line for line in (proc/'smaps_rollup').read_text().splitlines() if line.startswith('Pss:'))
                    found[pid]=int(row.split()[1])*1024
            except (OSError, ValueError, StopIteration): pass
        return sum(found.values()) if found.keys() == ids else None
    except Exception:
        return None

parser = argparse.ArgumentParser()
parser.add_argument('--web-root', type=Path, default=Path(__file__).resolve().parents[1] / 'build/web')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--runs', type=int, default=3)
args = parser.parse_args()
args.output.parent.mkdir(parents=True,exist_ok=True)
class Quiet(http.server.SimpleHTTPRequestHandler):
    # Server-side shaping also covers service-worker fetches, which page-target
    # CDP throttling does not reliably cover. One shared downlink, not per file.
    link_lock=threading.Lock()
    next_slot=0.0
    def log_message(self, *args): pass
    def do_GET(self):
        time.sleep(0.150)
        super().do_GET()
    def copyfile(self, source, outputfile):
        while chunk:=source.read(32768):
            with type(self).link_lock:
                start=max(time.monotonic(),type(self).next_slot)
                type(self).next_slot=start+len(chunk)/500000
                due=type(self).next_slot
            time.sleep(max(0,due-time.monotonic()))
            outputfile.write(chunk)

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=str(args.web_root)))
threading.Thread(target=server.serve_forever, daemon=True).start()
result = {'status': 'incomplete', 'profile': {'kind': 'desktop Chromium emulation; NOT Android certification', 'viewport': [393,873], 'cpu_slowdown': 4, 'download_bps': 4000000, 'latency_ms': 150, 'network_shaping': 'aggregate HTTP-server downlink; includes service-worker fetches; local upload unthrottled', 'memory_note': 'Chrome process PSS is sampled every 2s on Linux and includes renderer/WASM and software GPU. JS heap and renderer video counters are also reported separately; do not add them to PSS.'}, 'runs': []}
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(args=['--no-sandbox','--disable-dev-shm-usage','--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
        browser_session=browser.new_browser_cdp_session()
        result['environment']={'browser':browser.version,'host':platform.platform(),'gpu':browser_session.send('SystemInfo.getInfo')['gpu']['devices']}
        for run in range(args.runs):
            context = browser.new_context(viewport={'width':393,'height':873}, is_mobile=True, has_touch=True, device_scale_factor=3)
            page = context.new_page()
            cdp = context.new_cdp_session(page)
            cdp.send('Network.enable')
            if True:
                cdp.send('Emulation.setCPUThrottlingRate', {'rate':4})
                page.add_init_script("Object.defineProperty(navigator,'deviceMemory',{get:()=>4});Object.defineProperty(navigator,'hardwareConcurrency',{get:()=>8});")
            errors=[]
            page.on('pageerror',lambda e: errors.append(str(e)))
            page.on('console',lambda m: errors.append(m.text) if m.type == 'error' else None)
            url=f'http://127.0.0.1:{server.server_port}/play/index.html?profile=1&benchmark=1'
            print('Profile URL:',url,flush=True)
            page.goto(url,wait_until='domcontentloaded',timeout=240000)
            memory=[]
            deadline=time.monotonic()+300
            while not page.evaluate('window.lasuBenchmarkDone === true'):
                if time.monotonic()>deadline: raise TimeoutError('Benchmark exceeded 300 seconds')
                memory.append({'pss_bytes':browser_pss(browser_session),'at':page.evaluate('performance.now()')})
                page.wait_for_timeout(2000)
            samples=page.evaluate('window.lasuPerfSamples || []')
            assert samples and not errors, errors or 'No engine samples'
            assert {'campus_idle','campus_walk','phone','interior'} <= {s['stage'] for s in samples}, 'Incomplete scenario'
            print('Scenario complete',run+1,flush=True)
            stages={}
            for stage in sorted({s['stage'] for s in samples}):
                values=[s for s in samples if s['stage']==stage]
                stages[stage]={'fps_median':statistics.median(s['fps'] for s in values),'fps_min_1s':min(s['fps'] for s in values),'draw_calls_peak':max(s['draw_calls'] for s in values),'video_memory_peak_bytes':max(s['video_memory_bytes'] for s in values),'max_frame_ms':max(s['max_frame_ms'] for s in values)}
            metrics=page.evaluate('window.lasuBootMetrics')
            heap=cdp.send('Runtime.getHeapUsage')
            result['runs'].append({'cold_boot':metrics,'cold_world_ready_ms':metrics['worldReadyAt'],'stages':stages,'js_heap':heap,'samples':samples,'browser_pss_samples':memory,'browser_pss_peak_bytes':max((m['pss_bytes'] for m in memory if m['pss_bytes'] is not None),default=None)})
            page.goto(url.replace('&benchmark=1',''),wait_until='domcontentloaded',timeout=240000)
            page.wait_for_function('window.lasuBootMetrics?.architectureReadyAt',timeout=240000)
            result['runs'][-1]['warm_boot']=page.evaluate('window.lasuBootMetrics')
            page.screenshot(path=str(args.output.with_suffix(f'.run{run+1}.png')))
            context.close()
            print('Cold/warm run complete',run+1,flush=True)
        browser.close()
        result['status']='captured'
except Exception as error:
    result['status']='blocked'
    result['error']=str(error)
finally:
    server.shutdown()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2))
    print(result['status'],args.output)
if result['status']!='captured': raise SystemExit(1)
