#!/usr/bin/env python3
"""Validate data/landforms.json, the nests (design 1 Oct §CK; nest plants §CM).

Usage:
  python3 tools/landforms_check.py [--strict]
  python3 tools/landforms_check.py --fragment FILE [--strict]

A fragment is {"landforms": {...}} checked against the main file's vocab, the
way the parallel fill agents check their work before it is merged.
Exit 1 on any error. --strict also fails on warnings.
"""
import glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
args = sys.argv[1:]
strict = '--strict' in args
fragment = None
if '--fragment' in args:
    i = args.index('--fragment')
    if i + 1 >= len(args):
        sys.exit("--fragment needs a file")
    fragment = args[i + 1]

errors, warnings = [], []
def err(k, m): errors.append(f"{k}: {m}")
def warn(k, m): warnings.append(f"{k}: {m}")

main = json.load(open('data/landforms.json'))
vocab = main['vocab']
families = set(main['families'].keys())
biome_keys = {json.load(open(p))['key'] for p in glob.glob('data/biomes/*.json')}
bmap = json.load(open('data/peoples/biome_map.json'))
lives = set(bmap['lives'])
signatures = {}  # people id -> signature ids
for p in glob.glob('data/peoples/*.json'):
    if os.path.basename(p) in ('biome_map.json', 'folk_kinds.json'):
        continue
    d = json.load(open(p))
    signatures[d['id']] = {s['id'] for s in d.get('ruin', {}).get('signatures', [])}
all_sigs = set().union(*signatures.values())
binomials = set()  # every "Genus species" in the plant data (biome lists and catalogues)
for p in glob.glob('data/biomes/*.json') + glob.glob('data/plants/*.json'):
    doc = json.load(open(p))
    pl = doc.get('plants', {})
    for lst in (pl.values() if isinstance(pl, dict) else [pl]):
        for e in lst:
            if isinstance(e, dict) and e.get('genus') and e.get('species'):
                binomials.add(f"{e['genus']} {e['species']}")
SOILS = {'granite', 'basalt', 'karst', 'sandstone', 'alluvium', 'sand', 'clay_peat', 'till'}
RANGE_KEYS = {'temp_c', 'moisture', 'elevation_m', 'abs_lat_deg', 'slope', 'relief_m', 'coast_km', 'river_km', 'depth_m'}
LIST_KEYS = {'water': {'ocean', 'lake', 'river', 'none'}, 'salinity': {'fresh', 'brackish', 'salt'}}
ENUM_KEYS = {'discharge': {'big', 'any'}, 'hotspot': {'core', 'flank', 'old', 'sea'}, 'wind': {'steady'}, 'ice': {'present', 'past'}}
REQUIRED = ['name', 'family', 'scale', 'build', 'status', 'tier', 'rarity', 'when', 'cause', 'biomes',
            'shape', 'gives', 'hearth_spot', 'people', 'remains', 'real_world']
LINK_KEYS = {'roads', 'rooms', 'threshold', 'gate', 'magic', 'audio'}


def check_range(k, field, v):
    if not (isinstance(v, list) and len(v) == 2):
        err(k, f"cause.{field} must be [min, max] (null for open)")
        return
    lo, hi = v
    for x in v:
        if x is not None and not isinstance(x, (int, float)):
            err(k, f"cause.{field} values must be numbers or null")
            return
    if lo is not None and hi is not None and lo > hi:
        err(k, f"cause.{field} min {lo} > max {hi}")


def check_cause(k, cause):
    if not isinstance(cause, dict):
        err(k, "cause must be an object")
        return
    allowed = set(vocab['cause_keys'].keys())
    for field, v in cause.items():
        if field not in allowed:
            err(k, f"cause.{field} is not in vocab.cause_keys")
        elif field == 'rock':
            for r in v:
                if r not in SOILS:
                    err(k, f"cause.rock '{r}' is not a soil name {sorted(SOILS)}")
        elif field in RANGE_KEYS:
            check_range(k, field, v)
        elif field in LIST_KEYS:
            for x in v:
                if x not in LIST_KEYS[field]:
                    err(k, f"cause.{field} '{x}' not in {sorted(LIST_KEYS[field])}")
        elif field in ENUM_KEYS:
            if v not in ENUM_KEYS[field]:
                err(k, f"cause.{field} '{v}' not in {sorted(ENUM_KEYS[field])}")
        elif field == 'near':
            if not (isinstance(v, list) and all(isinstance(x, str) for x in v)):
                err(k, "cause.near must be a list of strings")
        elif field == 'other':
            if not isinstance(v, str):
                err(k, "cause.other must be a string")


def check_biomes(k, lst, where='biomes'):
    if not lst:
        err(k, f"{where} is empty")
    for b in lst:
        if b not in biome_keys:
            err(k, f"{where}: unknown biome key '{b}'")


def check_entry(k, d):
    for f in REQUIRED:
        if f not in d:
            err(k, f"missing '{f}'")
    if any(e.startswith(k + ':') and 'missing' in e for e in errors):
        return
    if d['family'] not in families:
        err(k, f"family '{d['family']}' not in {sorted(families)}")
    if d['scale'] not in vocab['scale']:
        err(k, f"scale '{d['scale']}' not in {vocab['scale']}")
    if not d['build']:
        err(k, "build is empty")
    for b in d['build']:
        if b not in vocab['build']:
            err(k, f"build '{b}' not in {vocab['build']}")
    if d['status'] not in vocab['status']:
        err(k, f"status '{d['status']}' not in {vocab['status']}")
    if d['tier'] not in (1, 2, 3):
        err(k, "tier must be 1, 2 or 3")
    if d['rarity'] not in vocab['rarity']:
        err(k, f"rarity '{d['rarity']}' not in {vocab['rarity']}")
    if 'seasonal' in d and d['seasonal'] not in vocab['seasonal']:
        err(k, f"seasonal '{d['seasonal']}' not in {vocab['seasonal']}")
    for f in ('when', 'shape', 'hearth_spot', 'name'):
        if not isinstance(d[f], str) or len(d[f].strip()) < 3:
            err(k, f"'{f}' must be a non-empty string")
    check_cause(k, d['cause'])
    check_biomes(k, d['biomes'])
    for g in d['gives']:
        if g not in vocab['gives']:
            err(k, f"gives '{g}' not in vocab.gives")
    if not d['gives']:
        warn(k, "gives is empty")
    for p in d['people']:
        if p not in lives:
            err(k, f"people '{p}' is not a data/peoples life")
    if not d['people']:
        warn(k, "people is empty (a landmark only)")
    listed = set().union(*(signatures.get(p, set()) for p in d['people'])) if d['people'] else set()
    for s in d['remains']:
        if s not in all_sigs:
            err(k, f"remains '{s}' is not a signature id in any data/peoples file")
        elif listed and s not in listed:
            warn(k, f"remains '{s}' belongs to none of this nest's people {d['people']}")
    for f in ('size_m', 'depth_m'):
        if f in d:
            v = d[f]
            if not (isinstance(v, list) and len(v) == 2 and all(isinstance(x, (int, float)) for x in v) and v[0] <= v[1]):
                err(k, f"{f} must be [min, max] numbers")
    for i, var in enumerate(d.get('variants', [])):
        vk = f"{k}.variants[{i}]"
        for f in ('id', 'name', 'when', 'biomes'):
            if f not in var:
                err(vk, f"missing '{f}'")
        if 'biomes' in var:
            check_biomes(vk, var['biomes'])
        if 'cause' in var:
            check_cause(vk, var['cause'])
    for lk in d.get('links', {}):
        if lk not in LINK_KEYS:
            err(k, f"links.{lk} not in {sorted(LINK_KEYS)}")
    if 'plants' in d:
        pl = d['plants']
        if not (isinstance(pl, dict) and isinstance(pl.get('add'), list) and pl['add'] and isinstance(pl.get('where'), str)):
            err(k, "plants must be {add: [binomials], where: text}")
        else:
            for b in pl['add']:
                if len(b.split()) != 2 or not b.split()[0][:1].isupper():
                    err(k, f"plants.add '{b}' is not a 'Genus species' binomial")
                elif b not in binomials:
                    warn(k, f"plants.add '{b}' is not in the plant data yet (needs an entry)")
    rw = d['real_world']
    if not rw:
        warn(k, "real_world is empty")
    for i, r in enumerate(rw):
        for f in ('analogue', 'region', 'note', 'source'):
            if not r.get(f):
                (err if f != 'source' else warn)(k, f"real_world[{i}] missing '{f}'")
        src = r.get('source', '')
        if src and not src.startswith('http'):
            err(k, f"real_world[{i}].source must be a URL")
    known = set(REQUIRED) | {'variants', 'size_m', 'depth_m', 'hazard', 'seasonal', 'links', 'notes', 'plants'}
    for f in d:
        if f not in known:
            err(k, f"unknown field '{f}'")


if fragment:
    frag = json.load(open(fragment))
    lf = frag.get('landforms')
    if not isinstance(lf, dict) or not lf:
        sys.exit(f"{fragment}: needs a non-empty 'landforms' object")
    entries = lf
    clash = set(lf) & set(main['landforms'])
    for k in clash:
        err(k, "id already in data/landforms.json")
else:
    for f in ('_help', 'camp_loop', 'families', 'vocab', 'landforms'):
        if f not in main:
            err('data/landforms.json', f"missing top-level '{f}'")
    entries = main['landforms']

for k, d in entries.items():
    if not k.replace('_', '').isalnum() or k != k.lower():
        err(k, "id must be lower_snake_case")
    check_entry(k, d)

for w in warnings:
    print("warn  " + w)
for e in errors:
    print("ERROR " + e)
n = len(entries)
print(f"{n} landform(s), {len(errors)} error(s), {len(warnings)} warning(s)")
sys.exit(1 if errors or (strict and warnings) else 0)
