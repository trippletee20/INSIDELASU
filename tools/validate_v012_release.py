#!/usr/bin/env python3
"""Static v0.12 build checks. Does not execute Godot or certify runtime."""
from pathlib import Path
from collections import Counter
import json,zipfile,re,hashlib,math
from shapely.geometry import LineString,box
root=Path(__file__).resolve().parents[1]
expected_layout_sha256='fe4467702650ba124221a4b7dfaa650e820515db084195ef511bbce97cc63257'
expected_road_sha256='f7587e7ea37bfa320dad4c56d1acfbe00a837bb5766be3f4e36bdc4034a52cb1'
expected_transit_sha256='5ac8021fdd7c030a79d56ccc65a199504ff21434fc4dc8196138da1b327d3b10'
load=lambda file:json.loads((root/'data'/file).read_text())
layout=load('campus_layout.json');roads=load('road_network_v0.4.json');transit=load('transit_routes_v0.7.json');amen=load('amenities_v0.6.json');catalog=load('interior_catalog_v0.10.json');tasks=load('task_catalog_v0.9.json')
assert len(layout['features'])==83
assert hashlib.sha256((root/'data/campus_layout.json').read_bytes()).hexdigest()==expected_layout_sha256,'Approved layout moved!'
assert hashlib.sha256((root/'data/road_network_v0.4.json').read_bytes()).hexdigest()==expected_road_sha256,'Road centerline topology moved!'
assert hashlib.sha256((root/'data/transit_routes_v0.7.json').read_bytes()).hexdigest()==expected_transit_sha256,'Changed shuttle routes!'
assert len(transit['lines'])==5
assert len(catalog['locations'])>=55
for f in layout['features']:
 if f['kind'] in ('academic','commercial','religious','residential') and not any(x in f['name'].lower() for x in ('incomplete','almost complete')):
  assert f['name'] in catalog['locations'],f['name']
for h in ('Hostel 1','Hostel 2','Hostel 3','Hostel 4','Hostel 5','Girls-only Hostel'):
 assert len(catalog['locations'][h])>=3,h
for name in catalog['locations']:
 assert name in tasks['locations'],name
assert sum(len(v) for v in tasks['locations'].values())>=780
main=(root/'scripts/main.gd').read_text()
tr=(root/'scripts/transit_manager.gd').read_text()
ib=(root/'scripts/interior_builder.gd').read_text()
assert all(s in main for s in ('hud_energy_meter','hud_stamina_meter','hud_stress_meter','_hud_meter','10.0','8.0','7.2','6.2'))
assert all(s in tr for s in ('_attempt_traffic_advance','_must_yield_to_higher_priority','_safe_lane_offset_at','_vehicle_rectangles_overlap'))
assert all(s in ib for s in ('_hostel_rooms','_study_rooms','_service_rooms','_special_rooms','sit_interactable'))
assert 'or lowered_name.ends_with("seat")' in main
assert all('func ' in (root/'scripts'/f).read_text() for f in ['main.gd','transit_manager.gd','interior_builder.gd'])
protected=[]
for f in layout['features']:
 if f['kind'] in ('unverified','landmark'):continue
 x,y=f['position'];w,h=f['size']; protected.append(box(x-w/2,y-h/2,x+w/2,y+h/2))
width_hist=Counter();segments=0
for route in roads['road_routes']:
 for a,b in zip(route['points'],route['points'][1:]):
  centre=LineString([a,b]);segments+=1
  for width in (10.0,8.0,7.2,6.2):
   if not any(centre.buffer(width/2/2.6,cap_style=2).intersects(p) for p in protected):
    width_hist[width]+=1;break
  else:raise AssertionError(f'No safe asphalt width at {route["id"]}, {a}, {b}')
assert segments==336
print(f'PASS: {segments} road segments, safe widths {dict(width_hist)}')
print(f'PASS: {len(catalog["locations"])} eligible sites with floor-specific interior catalogue')
print(f'PASS: {len(transit["lines"])} configured shuttle services; 83 protected map features unchanged')
print('PASS: five-service traffic/yield logic and dashboard/bar code present')
print('LIMIT: NO GODOT RUNTIME ENGINE TEST; deadlock recovery and in-engine UI still need an executable validation')
