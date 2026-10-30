"""Offline regression checks for Inside LASU 0.13; no claim of live Godot testing."""
from pathlib import Path
import json, re, zipfile, hashlib

root=Path(__file__).resolve().parents[1]
audit=[]
def must(cond,msg):
    assert cond,msg
    audit.append('PASS: '+msg)

def read(rel): return (root/rel).read_text(encoding='utf-8')

scripts={p.name:p.read_text(encoding='utf-8') for p in (root/'scripts').glob('*.gd')}
for name, src in scripts.items():
    defs=re.findall(r'^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(',src,re.M)
    must(len(defs)==len(set(defs)),f'{name}: unique method names ({len(defs)})')
    # Balanced parentheses / delimiters excluding quoted text, escaped chars and line comments
    bal=[]; stack=[]
    for line_no,line in enumerate(src.splitlines(),1):
        q='';esc=False
        for char in line:
            if q:
                if esc: esc=False
                elif char=='\\':esc=True
                elif char==q:q=''
                continue
            if char in ('"',"'"):q=char;continue
            if char=='#':break
            if char in '([{':stack.append((char,line_no))
            if char in ')]}':
                must(bool(stack),f'{name}: close delimiter matched on line {line_no}') if not stack else None
                old,oldline=stack.pop()
                must('([{'.index(old)==')]}'.index(char),f'{name}: delimiter matches from line {oldline}') if '([{'.index(old)!=')]}'.index(char) else None
    must(not stack,f'{name}: balanced braces/parentheses')

main=scripts['main.gd']; transit=scripts['transit_manager.gd']; interior=scripts['interior_builder.gd']
for helper in ['_update_parking_bay','_bay_position_is_clear','_find_traffic_blocker','_sound_horn']:
    must(f'func {helper}(' in transit,f'traffic helper {helper} exists')
for call in ['_enter_private_room','_return_to_hostel_lobby','_rest_in_room','_toggle_room_visitors','_buy_room_furniture']:
    must(f'func {call}(' in main,f'hostel room interaction {call} exists')
must('func show_private_room(' in interior,'distinct private room builder exists')
must('room_furniture = save_data.get(' in main,'existing saved room furniture restored')
must('"room_furniture": room_furniture' in main,'room furniture saved')
must('"room_visitors_allowed": room_visitors_allowed' in main,'visitor privacy persisted')
must('"last_room_rest_unix": last_room_rest_unix' in main,'rest cooldown persisted')
# Key regression: previously wrote stale state back after yield/horn intervention.
must(not re.search(r'if not _attempt_traffic_advance\([^\n]+\):\n\s+_services\[index\] = service',transit), 'blocked traffic results are not overwritten')
must('candidate_xz.distance_to(other_xz) < 11.0' not in transit,'stale 11m exclusion bubble removed')
must('if other_index == index:' in transit, 'own shuttle ignored in overlap checks')
must('if _bay_position_is_clear(index, test):' in transit,'parking bays tested before use')
must('PARK_BAY_EXTRA_METRES' in transit,'roadside parking offset exists')
must('func _segment_clear_of_campus_features(' in transit,'bay / road obstacle validator retained')
must('"menu_hold"' in transit,'passenger boarding state retained')
must('"passenger"' in transit,'passenger transit state retained')
must('_find_service(' in transit,'destination shuttle controls retained')

for j in (root/'data').glob('*.json'):
    json.loads(j.read_text(encoding='utf-8'))
    audit.append('PASS: JSON '+j.name)
rides=json.loads((root/'data/transit_routes_v0.7.json').read_text())
must(len(rides['lines'])==5,'five shuttle services preserved')
interiors=json.loads((root/'data/interior_catalog_v0.10.json').read_text())
must(all(x in interiors['locations'] for x in ['Hostel 1','Hostel 2','Hostel 3','Hostel 4','Hostel 5','Girls-only Hostel']), 'completed hostels retain interiors')
# Do not alter authoritative topology or design data from 0.12.
import zipfile
baseline=Path('/mnt/data/Inside_LASU_v0.12_Wider_Roads_Interiors_Styled_UI_Godot.zip')
with zipfile.ZipFile(baseline) as z:
    for name in ['data/campus_layout.json','data/road_network_v0.4.json','data/landscape_v0.5.json','data/amenities_v0.6.json','scenes/main.tscn']:
        current=(root/name).read_bytes()
        must(current==z.read(name),f'protected asset unchanged: {name}')

(root/'docs/archive/RELEASE_AUDIT_v0.13.txt').write_text('\n'.join(audit)+'\n\nNOTE: These are static tests only; no Godot executable was available.\n')
print('STATIC RELEASE CHECKS:',len(audit),'passed')
