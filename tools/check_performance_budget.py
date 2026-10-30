#!/usr/bin/env python3
"""Reject incomplete/mismatched profiles; compare captured regression budgets."""
import argparse,json,statistics
from pathlib import Path

def summary(data):
    if data.get('status')!='captured' or len(data.get('runs',[]))<3:
        raise ValueError('Three complete runs are required')
    runs=data['runs']
    stages={}
    for stage in ['campus_idle','campus_walk','phone','interior']:
        values=[r['stages'][stage] for r in runs]
        stages[stage]={'fps_median':statistics.median(v['fps_median'] for v in values),'draw_calls_peak':max(v['draw_calls_peak'] for v in values),'video_memory_peak_bytes':max(v['video_memory_peak_bytes'] for v in values),'max_frame_ms':max(v['max_frame_ms'] for v in values)}
    memory=[r['browser_pss_peak_bytes'] for r in runs]
    return {'stages':stages,'cold_world_ready_ms':statistics.median(r['cold_world_ready_ms'] for r in runs),'cold_architecture_ready_ms':statistics.median(r['cold_boot']['architectureReadyAt'] for r in runs),'warm_world_ready_ms':statistics.median(r['warm_boot']['worldReadyAt'] for r in runs),'browser_pss_peak_bytes':max(memory) if all(m is not None for m in memory) else None}

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('capture',type=Path)
    p.add_argument('--budget',type=Path,default=Path(__file__).resolve().parents[1]/'docs/performance_budget.json')
    p.add_argument('--web-root',type=Path,default=Path(__file__).resolve().parents[1]/'build/web/play')
    args=p.parse_args()
    data=json.loads(args.capture.read_text());budget=json.loads(args.budget.read_text())
    if budget['status']!='emulation_baseline_recorded':raise SystemExit('No valid measured baseline; cannot certify budget')
    if data['profile']!=budget['profile'] or data['environment']!=budget['environment']:
        raise SystemExit('Profile/host/renderer differs; benchmark on the recorded environment or review a new baseline')
    current=summary(data);base=budget['gates'];errors=[]
    for stage,values in base['stages'].items():
        observed=current['stages'][stage]
        if observed['fps_median'] < values['fps_median']*0.95: errors.append(stage+': FPS regression >5%')
        for metric in ['draw_calls_peak','video_memory_peak_bytes','max_frame_ms']:
            if observed[metric]>values[metric]*1.05:errors.append(stage+': '+metric+' regression >5%')
    for metric in ['cold_world_ready_ms','cold_architecture_ready_ms','warm_world_ready_ms','browser_pss_peak_bytes']:
        if base[metric] is None or current[metric] is None:errors.append(metric+': unavailable; requires review')
        elif current[metric]>base[metric]*(1.0 if metric=='browser_pss_peak_bytes' else 1.05):errors.append(metric+': exceeds recorded gate')
    for name,limit in budget['exported_byte_caps'].items():
        file=args.web_root/name
        if name=='index.pck.gz':
            import gzip
            size=len(gzip.compress((args.web_root/'index.pck').read_bytes(),compresslevel=9,mtime=0))
        else:size=file.stat().st_size
        if size>limit:errors.append(name+': download growth requires approval')
    if errors:raise SystemExit('\n'.join(errors))
    print('EMULATION BUDGET PASSED; physical Android certification remains separate')
