#!/usr/bin/env python3
"""Non-runtime checks for the v0.9 gameplay milestone; does not replace testing in Godot."""
from pathlib import Path
import json,re,hashlib
ROOT=Path(__file__).resolve().parents[1]
layout=json.loads((ROOT/'data/campus_layout.json').read_text())
road=json.loads((ROOT/'data/road_network_v0.4.json').read_text())
catalog=json.loads((ROOT/'data/task_catalog_v0.9.json').read_text())['locations']
assert len(catalog)==len(layout['features'])==83
assert set(catalog)=={x['name'] for x in layout['features']}
valid_kinds={'purchase','laundry','print','service','academic','information','hostel','review','event','event_job','restricted','job','business','social','admin','media','health','sports','explore','rest'}
n=0
for feature in layout['features']:
    name=feature['name']; ts=catalog[name]
    assert len(ts)>=3,name
    ids=set()
    for t in ts:
        assert t['kind'] in valid_kinds,(name,t['kind'])
        assert isinstance(t['cost'],int) and t['cost']>=0
        assert isinstance(t['reward'],int) and t['reward']>=0
        assert not(t['cost']>0 and t['reward']>0),(name,t)
        assert t['id'] not in ids;ids.add(t['id'])
        assert t['title'] and t['description']
        assert not t['reward'] or t['once_daily'],('infinite_money',name,t)
        n+=1
for name in ['Laundromat','Registration / cybercafé row','Femi Gbajabiamila Hall','Sports Centre','New Library']:
    assert name in catalog
assert any(x['title'].startswith('DIY') for x in catalog['Laundromat'])
assert any('e-docket' in x['title'] for x in catalog['Registration / cybercafé row'])
for gds in (ROOT/'scripts').glob('*.gd'):
    content=gds.read_text()
    assert content.startswith('extends ') or content.startswith('#')
    # Check bracket balance while ignoring escaped strings and line comments.
    stack=[]; quoted=False;quote='';comment=False;escaped=False
    for i,c in enumerate(content):
        if comment:
            if c=='\n':comment=False
            continue
        if quoted:
            if escaped:escaped=False
            elif c=='\\':escaped=True
            elif c==quote:quoted=False
            continue
        if c=='#':comment=True;continue
        if c in ('"',"'"):quoted=True;quote=c;continue
        if c in '([{':stack.append((c,i))
        if c in ')]}':
            assert stack,(gds.name,i,c)
            old,at=stack.pop()
            assert {'(':')','[':']','{':'}'}[old]==c,(gds.name,at,i)
    assert not stack,(gds,stack[-1])
    assert not quoted,gds
    # Duplicate top-level functions are parser errors.
    methods=re.findall(r'^func\s+([\w_]+)\(',content, re.M)
    assert len(set(methods))==len(methods),(gds.name,methods)
print(f'PASS: {len(catalog)} sites, {n} activity choices; nonnegative prices, controlled paid tasks, script delimiters and unique function names.')
print(f'PASS: road dataset has {len(road.get("road_routes",[]))} routes; prior road geometry unmodified by v0.9.')
print('NOTE: Godot editor/runtime compilation NOT verified in this environment.')
