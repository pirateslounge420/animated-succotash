#!/usr/bin/env python3
"""Mechanical check: does every species in a biome file actually fit that biome?

For each data/biomes/*.json:
  - each plant's temp_c / moisture band must OVERLAP the biome's climate band
    (a species whose whole band lies outside the biome can never spawn there);
  - flag species whose band only barely overlaps (< 20% of the biome's range);
  - flag catalogue duplicates whose bands differ from the same binomial elsewhere;
  - association members must resolve to a plant in the same file;
  - deciduous species (tint.drop) in biomes with no cold or dry season (tropical
    rainforest, cloud forest, mangrove, coral...) are flagged for a botanical look.
Prints a report; exit 1 on hard mismatches.
"""
import glob, json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASEASONAL = {"TROPICAL_RAINFOREST", "CLOUD_FOREST", "MANGROVE", "CORAL_REEF", "KELP_FOREST", "JUNGLE"}

def overlap(a, b):
    """Overlap length; a point band inside the other counts as full overlap."""
    lo, hi = max(a[0], b[0]), min(a[1], b[1])
    if a[0] == a[1] or b[0] == b[1]:
        return 1e9 if hi >= lo else 0.0
    return max(0.0, hi - lo)

def entries(doc):
    p = doc.get("plants", {})
    if isinstance(p, dict):
        for tier, lst in p.items():
            for e in lst or []:
                yield tier, e
    else:
        for e in p or []:
            yield "?", e

hard, soft = [], []
seen = {}
for f in sorted(glob.glob(os.path.join(ROOT, "data", "biomes", "*.json"))):
    d = json.load(open(f)); base = os.path.basename(f)
    clim = d.get("climate", {})
    bt, bm = clim.get("temp_c"), clim.get("moisture")
    names = set()
    for tier, e in entries(d):
        names.add(e.get("name"))
        t, m = e.get("temp_c"), e.get("moisture")
        if bt and t:
            o = overlap(bt, t)
            if o <= 0:
                hard.append("%s: %s (%s) temp %s never overlaps biome %s" % (base, e["name"], tier, t, bt))
            elif o < 0.2 * (bt[1] - bt[0]):
                soft.append("%s: %s temp %s barely overlaps biome %s" % (base, e["name"], t, bt))
        water_need = any(n in ("standing_water", "river_bank", "salt_water") for n in e.get("needs", []))
        if bm and m and not water_need:
            o = overlap(bm, m)
            if o <= 0:
                hard.append("%s: %s (%s) moisture %s never overlaps biome %s" % (base, e["name"], tier, m, bm))
            elif o < 0.2 * (bm[1] - bm[0]):
                soft.append("%s: %s moisture %s barely overlaps biome %s" % (base, e["name"], m, bm))
        bn = "%s %s" % (e.get("genus"), e.get("species"))
        if bn in seen and seen[bn] != (t, m):
            soft.append("%s: %s has bands %s/%s here but %s elsewhere" % (base, bn, t, m, seen[bn]))
        seen.setdefault(bn, (t, m))
        if d.get("key") in ASEASONAL and isinstance(e.get("tint"), dict) and e["tint"].get("drop"):
            soft.append("%s: %s is marked deciduous (drop) in an aseasonal biome — check" % (base, e["name"]))
    for a in d.get("associations", []):
        for role in ("dominant", "companion", "ground"):
            for n in a.get(role, []):
                if n not in names:
                    hard.append("%s: association '%s' names '%s' which is not a plant in this file" % (base, a.get("name"), n))

print("HARD (%d):" % len(hard)); [print("  " + h) for h in hard]
print("SOFT (%d):" % len(soft)); [print("  " + s) for s in soft[:80]]
if len(soft) > 80: print("  ... %d more" % (len(soft) - 80))
sys.exit(1 if hard else 0)
