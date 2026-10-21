#!/usr/bin/env python3
"""Static integrity and economic guard tests. No Godot runtime compilation claimed."""
from pathlib import Path
import json,re,hashlib,zipfile
from shapely.geometry import Point, LineString, box
from shapely.ops import unary_union
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'data'
read=lambda f:json.loads((D/f).read_text(encoding='utf8'))
l=read('campus_layout.json');road=read('road_network_v0.4.json');t=read('task_catalog_v0.9.json');a=read('amenities_v0.6.json');tr=read('transit_routes_v0.7.json');m=read('market_prices_v0.10.json');interiors=read('interior_catalog_v0.10.json')['locations']
assert len(l['features'])==83
assert len(t['locations'])==83
assert set(t['locations'])=={x['name'] for x in l['features']}
assert len(tr['lines'])==5 and len({x['id'] for x in tr['lines']})==5
assert len(a['billboards'])==100 and len({x['id'] for x in a['billboards']})==100
assert len(interiors)>=9
stops={s['id'] for s in a['shelters']}
assert all(len(x['stop_ids'])==2 and set(x['stop_ids']).issubset(stops) for x in tr['lines'])
assert all(x['speed_metres_per_second']>0 for x in tr['lines'])
ids=[]
for s,entries in t['locations'].items():
 assert len(entries)>=3,(s,len(entries))
 seen=set()
 for e in entries:
  assert e['cost']>=0 and e['reward']>=0
  assert not(e['cost'] and e['reward'])
  assert e['title'].strip() and e['description'].strip()
  assert e['id'] not in seen,(s,e['id'])
  assert not e['reward'] or e['once_daily'],('infinite reward',s,e)
  seen.add(e['id']);ids.append(e['id'])
assert sum(map(len,t['locations'].values()))>=700
assert not any('rice' in e['title'].lower() or 'stew' in e['title'].lower() for s in t['locations'] if s.startswith('Science Shops') for e in t['locations'][s])
for site in ['Science Shops (west)','Science Shops (east)','AJ Market']:
 gala=[e for e in t['locations'][site] if 'gala' in e['title'].lower()]
 assert len(gala)==1 and gala[0]['cost']==200,(site,gala)
items={e['id']:e for e in m['items']}
assert items['gala']['cost']==200 and items['biscuits']['cost']==100 and items['biro']['cost']==100
for packs in (1,2,3):
 for eggs in (0,1,2):assert items[f'noodles_{packs}_{eggs}']['cost']==600*packs+eggs*300
assert not any('egg' in x['id'] and x['category']=='egg' for x in m['items'])
assert items['bread_600_1']['cost']==900
assert items['noodles_1_1']['cost']==900 and items['noodles_2_1']['cost']==1500
assert all(s in interiors for s in ['Arcade','LASU Radio','New Library','Senate Building'])
# Structural GDScript checks for typos/missing local methods and unbalanced delimiters.
for f in (ROOT/'scripts').glob('*.gd'):
 txt=f.read_text(encoding='utf8')
 stack=[];quote=None;escape=False;comment=False
 for i,c in enumerate(txt):
  if comment:
   if c=='\n': comment=False
   continue
  if quote:
   if escape: escape=False
   elif c=='\\':escape=True
   elif c==quote:quote=None
   continue
  if c=='#':comment=True;continue
  if c in '"\'':quote=c;continue
  if c in '([{':stack.append((c,i))
  if c in ')]}':
   assert stack,(f.name,i,c)
   previous,at=stack.pop()
   assert {'(':')','[':']','{':'}'}[previous]==c,(f.name,at,i)
 assert not stack and quote is None,(f.name,stack[-1:] if stack else quote)
 names=re.findall(r'^func\s+([A-Za-z0-9_]+)\s*\(',txt,flags=re.M)
 assert len(names)==len(set(names)),('duplicate_methods',f)
 # Disallow past bug: local underscored calls without a matching function.
 methods=set(names)
 builtin={'_init','_ready','_process','_physics_process','_input','_unhandled_input','_notification','_enter_tree','_exit_tree','_draw','_to_string','_get','_set'}
 calls=set(re.findall(r'(?<![\w.])(_[A-Za-z][A-Za-z0-9_]*)\s*\(',txt))
 missing=calls-methods-builtin
 assert not missing,(f.name,missing)
 print('CHECK GDScript structure',f.name,len(names),'methods')
# Billboard sites generated with AABB road/feature safety.
features=[]
for f in l['features']:
 if f['kind']=='unverified':continue
 x,y=f['position'];w,h=f['size'];features.append(box(x-w/2-1,y-h/2-1,x+w/2+1,y+h/2+1))
roads=[LineString(r['points']) for r in road['road_routes'] if len(r['points'])>=2]
all_obstacles=unary_union(features+[line.buffer(1.7) for line in roads])
extra=a['billboards'][16:]
for b in extra:
 x,y=b['position']
 width={'small':3.5,'medium':6.4,'large':9.5}[b['size']]/2.6
 assert Point(x,y).buffer(width*0.68+0.68).disjoint(all_obstacles), b['id']
# Confirm source protected layout and roads didn't silently mutate.
expected={'campus_layout.json':'fe4467702650ba124221a4b7dfaa650e820515db084195ef511bbce97cc63257', 'road_network_v0.4.json':'f7587e7ea37bfa320dad4c56d1acfbe00a837bb5766be3f4e36bdc4034a52cb1'}
for file,digest in expected.items(): assert hashlib.sha256((D/file).read_bytes()).hexdigest()==digest
print(f'PASS: {len(t["locations"])} sites; {sum(map(len,t["locations"].values()))} tasks; {len(tr["lines"])} services; {len(a["billboards"])} billboards; {len(interiors)} pilot interiors.')
print('PASS: product prices, Science Market food constraints, layout protection, GDScript structural checks, saved-source integrity.')
print('NOTE: These are static checks. Godot 4.7 runtime compilation and live collision playtests are NOT verified here.')
