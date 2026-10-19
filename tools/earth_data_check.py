#!/usr/bin/env python3
"""Validate the real-Earth data (design 18 Oct §FX): data/earth/*.json and, once Claude Code's
build script has made them, the rasters.

Usage:
    python3 tools/earth_data_check.py                        # the rules files and the headers
    python3 tools/earth_data_check.py --relief               # + relief.bin against the known places
    python3 tools/earth_data_check.py --climate              # + the climate rasters against the known places
    python3 tools/earth_data_check.py --ecoregions TABLE     # resolve every ecoregion to one game realm
    python3 tools/earth_data_check.py --ecoregions TABLE --write   # ... and write ecoregion_realms.json

TABLE is data/earth/ecoregions.json (ECO_ID → {ECO_NAME, BIOME_NUM, BIOME_NAME, REALM}, the
export queue 105 makes) or a CSV with those columns (the attribute table of the RESOLVE
shapefile). The realm resolution prints the counts per game realm, the ecoregions each
override caught, and the overrides that caught nothing, for Claude (chat) to review.

Always checked (no files needed): every realm named is in the vocabulary; every template named
in biome_map.json is a real biome key (data/biomes); every RESOLVE biome 1–14 and N/A has a
list; the headers' sizes agree with their resolutions; the known places are inside the map.
Exit code 1 on any error. Plain Python 3, no packages.
"""
import csv
import glob
import json
import math
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EARTH = os.path.join(ROOT, "data", "earth")

errors = []
warnings = []


def err(msg):
    errors.append(msg)
    print("ERROR", msg)


def warn(msg):
    warnings.append(msg)
    print("warn ", msg)


def load(name):
    with open(os.path.join(EARTH, name), encoding="utf-8") as f:
        return json.load(f)


def biome_keys():
    keys = set()
    for path in glob.glob(os.path.join(ROOT, "data", "biomes", "*.json")):
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        k = d.get("key")
        if k:
            keys.add(k)
    return keys


# ---------------------------------------------------------------- rules files

def check_rules(earth, realms, biome_map):
    vocab = set(realms["vocabulary"])
    for rr, game in realms["by_resolve_realm"].items():
        if game not in vocab:
            err(f"realms.json by_resolve_realm {rr!r} -> {game!r} is not in the vocabulary")
    seen_patterns = {}
    for i, rule in enumerate(realms["overrides"]):
        if rule["realm"] not in vocab:
            err(f"realms.json override {i} realm {rule['realm']!r} is not in the vocabulary")
        if rule["realm"] == "any":
            err("realms.json: no ecoregion may resolve to 'any'")
        for pat in rule["name_contains"]:
            low = pat.lower()
            if low in seen_patterns and seen_patterns[low] != rule["realm"]:
                err(f"realms.json pattern {pat!r} appears under {seen_patterns[low]} and {rule['realm']}")
            seen_patterns[low] = rule["realm"]
    keys = biome_keys()
    if not keys:
        err("no biome keys found under data/biomes")
    for num in [str(n) for n in range(1, 15)] + ["N/A"]:
        if num not in biome_map["by_resolve_biome"]:
            err(f"biome_map.json has no entry for RESOLVE biome {num}")
    for num, entry in biome_map["by_resolve_biome"].items():
        if not entry.get("templates"):
            err(f"biome_map.json biome {num} names no templates")
        for t in entry.get("templates", []):
            if t not in keys:
                err(f"biome_map.json biome {num} names unknown template {t!r}")
    for group, lst in biome_map["from_other_passes"].items():
        for t in lst:
            if t not in keys:
                err(f"biome_map.json from_other_passes.{group} names unknown template {t!r}")
    # Headers: sizes against resolutions.
    rel = earth["relief"]
    want_w = round(360 * 60 / rel["arc_minutes"])
    want_h = round(180 * 60 / rel["arc_minutes"])
    if (rel["width"], rel["height"]) != (want_w, want_h):
        err(f"relief header {rel['width']}x{rel['height']} does not match {rel['arc_minutes']}' ({want_w}x{want_h})")
    cl = earth["climate"]
    if (cl["width"], cl["height"]) != (round(360 / cl["degrees"]), round(180 / cl["degrees"])):
        err("climate header size does not match its degrees")
    ec = earth["ecoregions"]
    if (ec["width"], ec["height"]) != (round(360 / ec["degrees"]), round(180 / ec["degrees"])):
        err("ecoregions header size does not match its degrees")
    if earth["ranges"]["stretch_max"] < 1.0:
        err("ranges.stretch_max under 1.0 would squeeze the great ranges; 1.0 is honest")
    for p in earth["checks"]["places"] + earth["peaks"]["list"]:
        if not (-90 <= p["lat"] <= 90 and -180 <= p["lon"] <= 180):
            err(f"place {p['name']!r} is off the map")
        for key in ("biome", "biome_any"):
            if key in p:
                for t in ([p[key]] if isinstance(p[key], str) else p[key]):
                    if t not in keys:
                        err(f"checks place {p['name']!r} expects unknown template {t!r}")
        if "realm" in p and p["realm"] not in vocab:
            err(f"checks place {p['name']!r} expects unknown realm {p['realm']!r}")
    for name in ("ETOPO", "CHELSA", "RESOLVE"):
        if not any(name in line for line in earth["credits"]):
            err(f"credits lack a {name} line")
    print(f"rules: {len(realms['overrides'])} override rules, {len(seen_patterns)} patterns, "
          f"{len(biome_map['by_resolve_biome'])} RESOLVE biomes mapped onto {len(keys)} templates")


# ---------------------------------------------------------------- rasters

class Raster:
    """An equirectangular int16/uint16 grid: row 0 north, column 0 at -180, centres at the half-step."""

    def __init__(self, path, width, height, fmt):
        self.w, self.h = width, height
        with open(path, "rb") as f:
            raw = f.read()
        code = {"int16_le_raw": "<%dh", "uint16_le_raw": "<%dH"}[fmt]
        if len(raw) != width * height * 2:
            raise ValueError(f"{path}: {len(raw)} bytes, expected {width * height * 2}")
        self.v = struct.unpack(code % (width * height), raw)

    def at(self, lat, lon):
        x = int((lon + 180.0) / 360.0 * self.w) % self.w
        y = min(self.h - 1, max(0, int((90.0 - lat) / 180.0 * self.h)))
        return self.v[y * self.w + x]

    def land_fraction(self, sea_level):
        """Area-weighted share of samples above sea level (rows weighted by cos latitude)."""
        land = total = 0.0
        for y in range(self.h):
            lat = 90.0 - (y + 0.5) * 180.0 / self.h
            wgt = math.cos(math.radians(lat))
            row = self.v[y * self.w:(y + 1) * self.w]
            total += wgt * self.w
            land += wgt * sum(1 for e in row if e > sea_level)
        return land / total


def check_relief(earth):
    rel = earth["relief"]
    path = os.path.join(EARTH, rel["file"])
    if not os.path.exists(path):
        warn(f"relief: {rel['file']} is not built yet (queue 103)")
        return
    if rel["format"] not in ("int16_le_raw",):
        warn(f"relief format {rel['format']!r}: this check reads only int16_le_raw; skipping the numbers")
        return
    r = Raster(path, rel["width"], rel["height"], rel["format"])
    frac = r.land_fraction(earth["sea_level_m"])
    lo, hi = earth["checks"]["land_fraction"]
    print(f"relief: land {frac:.3f} of the sphere (want {lo}-{hi})")
    if not lo <= frac <= hi:
        err("relief: land fraction out of band")
    scale = 0.1
    try:
        with open(os.path.join(ROOT, "data", "world_scale.json"), encoding="utf-8") as f:
            scale = json.load(f)["heights"]["height_scale"]
    except Exception:
        pass
    top = max(r.v)
    print(f"relief: highest sample {top} m Earth = {top * scale:.0f} m here; lowest {min(r.v)} m")
    for p in earth["peaks"]["list"]:
        e = r.at(p["lat"], p["lon"])
        print(f"  {p['name']:<14} cell {e:>6} m of {p['height_m']} ({100 * e / p['height_m']:.0f}%)")
    for p in earth["checks"]["places"]:
        e = r.at(p["lat"], p["lon"])
        if "relief_m_max" in p and e > p["relief_m_max"]:
            err(f"relief: {p['name']} reads {e} m, want at most {p['relief_m_max']}")
        if p.get("land") and e <= earth["sea_level_m"]:
            err(f"relief: {p['name']} reads sea ({e} m), want land")


def check_climate(earth):
    cl = earth["climate"]
    rasters = {}
    for key, fname in cl["files"].items():
        path = os.path.join(EARTH, fname)
        if not os.path.exists(path):
            warn(f"climate: {fname} is not built yet (queue 104)")
            return
        rasters[key] = Raster(path, cl["width"], cl["height"], cl["format"])
    for p in earth["checks"]["places"]:
        t = rasters["bio1"].at(p["lat"], p["lon"]) / 10.0
        pr = rasters["bio12"].at(p["lat"], p["lon"])
        if "bio1_c" in p and abs(t - p["bio1_c"]) > 2:
            err(f"climate: {p['name']} bio1 {t:.1f} C, want {p['bio1_c']} +-2")
        if "bio1_c_max" in p and t > p["bio1_c_max"]:
            err(f"climate: {p['name']} bio1 {t:.1f} C, want at most {p['bio1_c_max']}")
        if "bio1_c_min" in p and t < p["bio1_c_min"]:
            err(f"climate: {p['name']} bio1 {t:.1f} C, want at least {p['bio1_c_min']}")
        if "bio12_mm" in p and abs(pr - p["bio12_mm"]) > 0.25 * p["bio12_mm"]:
            err(f"climate: {p['name']} bio12 {pr} mm, want {p['bio12_mm']} +-25%")
        if "bio12_mm_min" in p and pr < p["bio12_mm_min"]:
            err(f"climate: {p['name']} bio12 {pr} mm, want at least {p['bio12_mm_min']}")
        if "bio12_mm_max" in p and pr > p["bio12_mm_max"]:
            err(f"climate: {p['name']} bio12 {pr} mm, want at most {p['bio12_mm_max']}")
        print(f"  {p['name']:<18} {t:6.1f} C {pr:6d} mm")


# ---------------------------------------------------------------- ecoregions → realms

def read_table(path):
    """ECO_ID -> {ECO_NAME, BIOME_NUM, BIOME_NAME, REALM} from the JSON export or a CSV."""
    rows = {}
    if path.lower().endswith(".json"):
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        items = d.items() if isinstance(d, dict) else ((r["ECO_ID"], r) for r in d)
        for k, r in items:
            if str(k).startswith("_"):
                continue
            rows[int(k)] = r
    else:
        with open(path, encoding="utf-8", newline="") as f:
            for r in csv.DictReader(f):
                rows[int(float(r["ECO_ID"]))] = r
    return rows


def resolve(realms, rows):
    out = {}
    caught = {i: [] for i in range(len(realms["overrides"]))}
    for eco_id, r in sorted(rows.items()):
        name = str(r.get("ECO_NAME", ""))
        low = name.lower()
        realm = None
        for i, rule in enumerate(realms["overrides"]):
            if any(pat.lower() in low for pat in rule["name_contains"]):
                realm = rule["realm"]
                caught[i].append(name)
                break
        if realm is None:
            rr = str(r.get("REALM", "N/A")) or "N/A"
            realm = realms["by_resolve_realm"].get(rr)
            if realm is None:
                err(f"ecoregion {eco_id} {name!r}: RESOLVE realm {rr!r} has no default")
                continue
        out[eco_id] = {"name": name, "realm": realm, "biome": str(r.get("BIOME_NUM", "")),
                       "resolve_realm": str(r.get("REALM", ""))}
    return out, caught


def check_ecoregions(earth, realms, table_path, write):
    rows = read_table(table_path)
    if not rows:
        err(f"no ecoregions read from {table_path}")
        return
    out, caught = resolve(realms, rows)
    counts = {}
    for v in out.values():
        counts[v["realm"]] = counts.get(v["realm"], 0) + 1
    print(f"ecoregions: {len(out)} resolved")
    for realm in realms["vocabulary"]:
        if realm in counts:
            print(f"  {realm:<20} {counts[realm]:>4}")
    missing = [r for r in realms["vocabulary"] if r not in counts and r != "any"]
    if missing:
        warn(f"no ecoregion resolves to: {', '.join(missing)}")
    for i, rule in enumerate(realms["overrides"]):
        names = caught[i]
        print(f"override {rule['realm']}: {len(names)} ecoregions")
        for n in names:
            print(f"    {n}")
        if not names:
            warn(f"override {rule['realm']} caught nothing")
    if write:
        path = os.path.join(EARTH, earth["ecoregions"]["resolved_realms"])
        doc = {"_help": "Written by tools/earth_data_check.py --ecoregions --write from realms.json "
                        "(design §FX.5). ECO_ID -> the game realm RealmMap returns there, the "
                        "ecoregion's name, its RESOLVE biome number and realm. Regenerate, don't edit.",
               "by_eco_id": {str(k): v for k, v in out.items()}}
        with open(path, "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=1, ensure_ascii=False)
            f.write("\n")
        print(f"wrote {os.path.relpath(path, ROOT)}")


# ---------------------------------------------------------------- main

def main(argv):
    earth = load("earth.json")
    realms = load("realms.json")
    biome_map = load("biome_map.json")
    check_rules(earth, realms, biome_map)
    if "--relief" in argv:
        check_relief(earth)
    if "--climate" in argv:
        check_climate(earth)
    if "--ecoregions" in argv:
        table = argv[argv.index("--ecoregions") + 1]
        check_ecoregions(earth, realms, table, "--write" in argv)
    print(f"{len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
