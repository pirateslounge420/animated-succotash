#!/usr/bin/env python3
"""Validate data/peoples/*.json against the README schema (design 30 Sept §BO–§BQ).

Usage: python3 tools/peoples_check.py [--strict]
Exit 1 on any error. --strict also fails on warnings (missing sources, short files).
"""
import glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
strict = '--strict' in sys.argv

errors, warnings = [], []
def err(f, m): errors.append(f"{f}: {m}")
def warn(f, m): warnings.append(f"{f}: {m}")

biome_keys = {json.load(open(p))['key'] for p in glob.glob('data/biomes/*.json')}
fuel_kinds = set(json.load(open('data/fuel.json'))['kinds'].keys())
tech = json.load(open('data/techniques.json'))['techniques']
tech_ids = {t['id'] for t in tech}
bmap = json.load(open('data/peoples/biome_map.json'))
site_rules = {r['id'] for r in bmap['site_rules']}
lives = set(bmap['lives'])
folk_kinds = set(json.load(open('data/peoples/folk_kinds.json'))['kinds'].keys())
FUND = {'crop', 'fish_run', 'herd', 'managed_burn', 'forage'}
LEGIBLE = {'heap', 'cleared', 'restored'}
CATS = {'light', 'fire', 'fuel', 'food', 'water', 'materials', 'shelter', 'marks', 'travel'}
REQUIRED = ['id', 'name', 'one_line', 'where', 'fundamental', 'food', 'fuel', 'shelter', 'light',
            'dressing', 'specialists', 'techniques', 'materials', 'growth', 'ruin', 'aesthetic',
            'folk_kinds', 'real_world', 'sources']

seen_ids, seen_local_tech = set(), {}
files = sorted(p for p in glob.glob('data/peoples/*.json') if os.path.basename(p) not in ('biome_map.json', 'folk_kinds.json'))
for path in files:
    f = os.path.basename(path)
    try:
        d = json.load(open(path))
    except Exception as e:
        err(f, f"invalid JSON: {e}"); continue
    for k in REQUIRED:
        if k not in d: err(f, f"missing key '{k}'")
    if errors and any(e.startswith(f) for e in errors):
        continue
    pid = d['id']
    if f != pid + '.json': err(f, f"id '{pid}' must match the file name")
    if pid not in lives: err(f, f"id '{pid}' is not in biome_map.json lives")
    if pid in seen_ids: err(f, "duplicate id")
    seen_ids.add(pid)
    w = d['where']
    if w.get('site_rule') not in site_rules: err(f, f"where.site_rule '{w.get('site_rule')}' not in biome_map site_rules")
    for b in w.get('biomes', []):
        if b not in biome_keys: err(f, f"where.biomes: unknown biome key '{b}'")
    if not w.get('biomes'): err(f, "where.biomes is empty")
    if d['fundamental'] not in FUND: err(f, f"fundamental '{d['fundamental']}' not in {sorted(FUND)}")
    for k in d['fuel'].get('kinds', []):
        if k not in fuel_kinds: err(f, f"fuel.kinds: unknown fuel kind '{k}' (data/fuel.json)")
    if not d['fuel'].get('kinds') and pid not in ('tundra',):
        warn(f, "fuel.kinds is empty")
    local = {t['id'] for t in d['techniques']}
    for t in d['techniques']:
        for k in ('id', 'name', 'verb', 'teaches', 'unlocks', 'player_can', 'category'):
            if k not in t: err(f, f"technique '{t.get('id')}' missing '{k}'")
        if t.get('category') not in CATS: err(f, f"technique '{t.get('id')}' category '{t.get('category')}' not in {sorted(CATS)}")
        if t['id'] not in tech_ids:
            if t['id'] in seen_local_tech and seen_local_tech[t['id']] != pid:
                err(f, f"new technique id '{t['id']}' also defined by {seen_local_tech[t['id']]}")
            seen_local_tech[t['id']] = pid
            warn(f, f"technique '{t['id']}' is new (not in data/techniques.json) — fine if unique")
        elif pid not in next(x for x in tech if x['id'] == t['id'])['taught_by'] and '*' not in next(x for x in tech if x['id'] == t['id'])['taught_by']:
            warn(f, f"technique '{t['id']}' lists this people but techniques.json taught_by does not")
    for lid in d['light']:
        if lid not in tech_ids and lid not in local: err(f, f"light '{lid}' is not a technique id")
    sp = d['specialists']
    ht = sp.get('headman_teaches')
    if ht not in tech_ids and ht not in local: err(f, f"specialists.headman_teaches '{ht}' is not a technique id")
    if 'plantkeeper' not in sp or 'maker' not in sp: err(f, "specialists needs plantkeeper and maker")
    for k in ('knows', 'teaches_flavour', 'teaches_practical'):
        if k not in sp.get('plantkeeper', {}): err(f, f"specialists.plantkeeper missing '{k}'")
    for k in ('craft', 'works', 'makes', 'wants_from_player'):
        if k not in sp.get('maker', {}): err(f, f"specialists.maker missing '{k}'")
    if d['ruin'].get('signatures') is None or len(d['ruin']['signatures']) < 2:
        err(f, "ruin.signatures needs at least 2")
    for s in d['ruin'].get('signatures', []):
        for k in ('id', 'what', 'legible', 'restore'):
            if k not in s: err(f, f"ruin signature '{s.get('id')}' missing '{k}'")
        if s.get('legible') not in LEGIBLE: err(f, f"ruin signature '{s.get('id')}' legible '{s.get('legible')}' not in {sorted(LEGIBLE)}")
    for k in ('ladder', 'restraint', 'ceiling_hint'):
        if k not in d['growth']: err(f, f"growth missing '{k}'")
    for k in ('silhouette', 'palette', 'sounds', 'props'):
        if k not in d['aesthetic']: err(f, f"aesthetic missing '{k}'")
    for k in d['folk_kinds']:
        if k not in folk_kinds: err(f, f"folk_kinds: unknown kind '{k}'")
    if 'by_biome' not in d['dressing']: err(f, "dressing.by_biome missing")
    else:
        for b in d['dressing']['by_biome']:
            if b not in biome_keys: err(f, f"dressing.by_biome: unknown biome key '{b}'")
    if len(d['real_world']) < 2: err(f, "real_world needs at least 2 analogues")
    for r in d['real_world']:
        for k in ('analogue', 'region', 'note', 'source'):
            if k not in r: err(f, f"real_world entry missing '{k}'")
    if len(d['sources']) < 3: warn(f, f"only {len(d['sources'])} sources (README asks 3–8)")
    lines = open(path).read().count('\n')
    if lines < 100: warn(f, f"{lines} lines — thinner than the coast example")
    if lines > 320: warn(f, f"{lines} lines — longer than the README asks")

missing = lives - seen_ids
for m in sorted(missing): warn('peoples', f"no file yet for life '{m}'")

for w in warnings: print('warn:', w)
for e in errors: print('ERROR:', e)
print(f"{len(files)} people files checked, {len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors or (strict and warnings) else 0)
