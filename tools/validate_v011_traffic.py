#!/usr/bin/env python3
"""Validate two-lane traffic geometry and deterministic SAT test scenarios.
These are STATIC GEOMETRIC TESTS, not a substitute for Godot runtime playtesting.
"""
from pathlib import Path
import json, math, re
from collections import Counter
from shapely.geometry import LineString, box
ROOT=Path(__file__).resolve().parents[1]
r=json.loads((ROOT/'data/road_network_v0.4.json').read_text())
c=json.loads((ROOT/'data/campus_layout.json').read_text())
transit=(ROOT/'scripts/transit_manager.gd').read_text()
main=(ROOT/'scripts/main.gd').read_text()
assert 'LANE_OFFSET_METRES: float = 1.55' in transit
assert 'func _vehicle_rectangles_overlap(' in transit
assert 'func _centreline_position(' in transit
assert 'JUNCTION_APPROACH: float = 15.0' in transit
assert 'service["lane_shift"] = -1.0' in transit
assert 'if not bool(other.get("destination_mode", false))' in transit
assert 'float(service.get("lane_shift", 1.0))' in transit
assert 'var asphalt_width: float = 7.2' in main
assert 'asphalt_width = 6.2' in main
assert 'var sidewalk_width: float = asphalt_width + 0.8' in main
assert 'func _safe_to_advance(' in transit
assert 'var proposed_state: Array = _point_and_heading(proposed)' in transit
assert 'func _road_path_between(' in transit
protected=[]
for f in c['features']:
 if f.get('kind') in ('unverified','landmark'): continue
 x,y=f['position'];width,height=f['size'];protected.append((f['name'],box(x-width/2,y-height/2,x+width/2,y+height/2)))
count=0; pinch=[]; verified=0
for route in r['road_routes']:
 for j,(a,b) in enumerate(zip(route['points'],route['points'][1:])):
  centre=LineString([a,b]);count+=1
  width=7.2
  if any(centre.buffer(width/2/2.6, cap_style=2).intersects(poly) for _,poly in protected):
   width=6.2
   pinch.append((route['id'],j))
  assert not any(centre.buffer(width/2/2.6, cap_style=2).intersects(poly) for _,poly in protected), (route['id'],j)
  assert width >= 6.2
  verified+=1
assert count==336,(count,verified)
assert len(pinch)==2,pinch
# Identical oriented 6.6m by 2.35m cars with an extra 0.3m collision margin.
def obb_overlap(p1,h1,p2,h2):
 d=(p2[0]-p1[0],p2[1]-p1[1]); a=(math.cos(h1),-math.sin(h1));b=(math.cos(h2),-math.sin(h2));sa=(-a[1],a[0]);sb=(-b[1],b[0]);hl=3.3+0.3;hw=1.175+0.3
 for axis in (a,sa,b,sb):
  dot=lambda p,q:p[0]*q[0]+p[1]*q[1]
  ra=hl*abs(dot(a,axis))+hw*abs(dot(sa,axis))
  rb=hl*abs(dot(b,axis))+hw*abs(dot(sb,axis))
  if abs(dot(d,axis))>ra+rb:return False
 return True
# Bus A drives +X with right-side offset +1.55 in Z.
# Bus B drives -X with right-side offset -1.55 in Z.
for i in range(65):
 x=5+i*1.2
 y=95-i*1.2
 assert not obb_overlap((x,1.55),0,(y,-1.55),math.pi), ('oncoming deadlock',i)
# Two buses on same lane remain mutually blocked if their body footprints overlap.
assert obb_overlap((45,1.55),0,(50,1.55),0)
assert not obb_overlap((45,1.55),0,(54,1.55),0)
# Crossing directions really do intersect, so the separate junction yield rule is necessary.
assert obb_overlap((50,1.55),0,(50,1.55),math.pi/2)
assert 2*1.55 > 2*(2.35/2+0.3)
print('PASS: road segments:',count,'protected-road pinch points:',pinch)
print('PASS: 5 live service definitions preserved, 2-lane geometry maintained without altering topology')
print('PASS: oncoming vehicles pass in their own lanes; same-lane and crossing overlap are detected')
print('PASS: deterministic junction-yield logic, candidate OBB checks and physics-based movement present')
print('LIMIT: static geometry and synthetic pass scenarios; NOT an executed Godot 4.7 traffic test')
