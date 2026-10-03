#!/usr/bin/env python3
"""Torch kinds check (design 3 Oct §CQ): the gate for torch.json -> kinds.

Every torch is from somewhere. A camp's bundle is its people's light, made only where its
plant grows; else a torch tree that grows there (fatwood, birch bark); else a plain brand.
Each kind trades its circle against its burn, and the kinds made of §CN's damp-burners
shrug off rain. This script checks the data that says so and reports where each kind can
be made:

  python3 tools/torch_kinds_check.py            # check and report
  python3 tools/torch_kinds_check.py --strict   # warnings count as errors

What it checks
- torch.json kinds.list: every kind has a name, a technique (or null), genera (a list),
  circle_scale, burn_scale and energy_scale above 0, rain_immune and dip as booleans;
  storm_burn_scale, where set, in (0, 1]. A kind whose numbers live in another block
  (numbers_in: the resin dip) needs only its circle_scale.
- kinds.bundle: its tree_kinds and its fallback (else) are kinds; tree kinds name genera.
- the rain rule (§CN, §CO): a kind tied to genera is rain_immune exactly when every one of
  its genera gives a wet_ok kindling kind in fuel.json; a kind with no genera may be
  rain_immune only with a rain_why. where_no_genus, where set, is a kind.
- the technique links: a kind's technique is a techniques.json id. Every people's light
  (data/peoples/*.json -> light) is either a kind's technique or a lamp (lamps are set
  down, not carried: they are not kinds).
- techniques.json params.kind names a kind, and params.genera match that kind's genera.
- the plant gate (§CA): where each kind's genera grow (data/biomes/*.json, read the way
  tools/kindling_check.py reads them). A kind whose genera grow nowhere = warning.
- torch.json ember_relight: the keys §CQ names; needs_technique is a technique the player
  performs (player_can).
- dread.json torch_circle: reference_range_m equals torch.json light.range_m.

The report lists every kind's circle and burn in metres and real minutes, and, for each
people in peoples/biome_map.json by_biome, what its camps leave by the fire in each biome.

Plain Python 3, no packages. Exit code 1 on any error.
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
LAMPS = {"fat_lamp", "clay_lamp"}


def load(*parts):
    with open(os.path.join(DATA, *parts), encoding="utf-8") as f:
        return json.load(f)


def biome_genera():
    """Biome key -> set of genera in that biome's plant file (as kindling_check.py)."""
    out = {}
    for f in sorted(glob.glob(os.path.join(DATA, "biomes", "*.json"))):
        with open(f, encoding="utf-8") as fh:
            d = json.load(fh)
        key = d.get("key")
        if not key:
            continue
        found = set()

        def walk(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k == "genus" and isinstance(v, str):
                        found.add(v.strip())
                    walk(v)
            elif isinstance(o, list):
                for x in o:
                    walk(x)

        walk(d)
        out[key] = found
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--strict", action="store_true", help="warnings count as errors")
    args = ap.parse_args()
    errs, warns = [], []

    torch = load("torch.json")
    fuel = load("fuel.json")
    tech = {t["id"]: t for t in load("techniques.json")["techniques"]}
    dread = load("dread.json")
    bmap = load("peoples", "biome_map.json")
    peoples = {}
    for f in sorted(glob.glob(os.path.join(DATA, "peoples", "*.json"))):
        pid = os.path.basename(f)[:-5]
        with open(f, encoding="utf-8") as fh:
            d = json.load(fh)
        if isinstance(d, dict) and "light" in d:
            peoples[pid] = d.get("light") or []
    bg = biome_genera()

    kinds_block = torch.get("kinds")
    if not isinstance(kinds_block, dict) or not isinstance(kinds_block.get("list"), dict):
        print("ERROR: torch.json has no kinds.list (design §CQ)")
        return 1
    kinds = kinds_block["list"]

    # The genera that give a damp-burning kindling (§CN, §CO).
    wet_genera = set()
    for kid, k in fuel.get("kindling", {}).get("kinds", {}).items():
        if k.get("wet_ok"):
            wet_genera.update(k.get("genera", []))

    by_technique = {}
    for kid, k in kinds.items():
        where = f"kinds.list.{kid}"
        if not isinstance(k, dict):
            errs.append(f"{where}: not an object")
            continue
        if not isinstance(k.get("name"), str) or not k["name"]:
            errs.append(f"{where}: needs a name")
        t = k.get("technique")
        if t is not None:
            if t not in tech:
                errs.append(f"{where}: technique '{t}' is not in techniques.json")
            elif t in by_technique:
                errs.append(f"{where}: technique '{t}' already belongs to kind '{by_technique[t]}'")
            else:
                by_technique[t] = kid
        genera = k.get("genera", [])
        if not isinstance(genera, list):
            errs.append(f"{where}: genera must be a list")
            genera = []
        cs = k.get("circle_scale")
        if not isinstance(cs, (int, float)) or cs <= 0:
            errs.append(f"{where}: circle_scale must be a number above 0")
        if k.get("numbers_in"):
            if k["numbers_in"] not in torch:
                errs.append(f"{where}: numbers_in '{k['numbers_in']}' is not a torch.json block")
            continue
        for key in ("burn_scale", "energy_scale"):
            v = k.get(key)
            if not isinstance(v, (int, float)) or v <= 0:
                errs.append(f"{where}: {key} must be a number above 0")
        for key in ("rain_immune", "dip"):
            if not isinstance(k.get(key), bool):
                errs.append(f"{where}: {key} must be true or false")
        if "storm_burn_scale" in k:
            v = k["storm_burn_scale"]
            if not isinstance(v, (int, float)) or not 0 < v <= 1:
                errs.append(f"{where}: storm_burn_scale must be in (0, 1]")
        if "where_no_genus" in k and k["where_no_genus"] not in kinds:
            errs.append(f"{where}: where_no_genus '{k['where_no_genus']}' is not a kind")
        # The rain rule.
        immune = bool(k.get("rain_immune"))
        if genera:
            should = all(g in wet_genera for g in genera)
            if immune != should:
                errs.append(
                    f"{where}: rain_immune is {str(immune).lower()} but its genera "
                    f"{'all' if should else 'do not all'} give a wet_ok kindling (§CN)"
                )
        elif immune and not k.get("rain_why"):
            errs.append(f"{where}: rain_immune with no genera needs a rain_why")
        # The plant gate.
        if genera and not any(set(genera) & gs for gs in bg.values()):
            warns.append(f"{where}: none of {genera} grows in any biome, so it is made nowhere")

    bundle = kinds_block.get("bundle", {})
    for kid in bundle.get("tree_kinds", []):
        if kid not in kinds:
            errs.append(f"kinds.bundle.tree_kinds: '{kid}' is not a kind")
        elif not kinds[kid].get("genera"):
            errs.append(f"kinds.bundle.tree_kinds: '{kid}' names no genera")
    fallback = bundle.get("else")
    if fallback not in kinds:
        errs.append(f"kinds.bundle.else: '{fallback}' is not a kind")

    # Every people's light is a kind or a lamp.
    for pid, lights in peoples.items():
        for lid in lights:
            if lid in LAMPS:
                continue
            if lid not in by_technique:
                errs.append(f"peoples/{pid}.json light '{lid}': no torch.json kind has it as its technique")

    # Techniques that name a kind.
    for tid, t in tech.items():
        p = t.get("params") or {}
        if "kind" not in p:
            continue
        if p["kind"] not in kinds:
            errs.append(f"techniques.json {tid}: params.kind '{p['kind']}' is not a kind")
            continue
        if "genera" in p and sorted(p["genera"]) != sorted(kinds[p["kind"]].get("genera", [])):
            errs.append(f"techniques.json {tid}: params.genera differ from kinds.list.{p['kind']}.genera")

    # The coal brings a dead torch back.
    er = torch.get("ember_relight")
    if not isinstance(er, dict):
        errs.append("torch.json: no ember_relight block (design §CQ)")
    else:
        for key in ("needs_technique", "button", "takes_s", "spends_coal", "relights", "not", "log"):
            if key not in er:
                errs.append(f"ember_relight: missing '{key}'")
        nt = er.get("needs_technique")
        if nt not in tech or not tech[nt].get("player_can"):
            errs.append(f"ember_relight.needs_technique '{nt}' is not a technique the player performs")
        if not isinstance(er.get("takes_s"), (int, float)) or er.get("takes_s", 0) <= 0:
            errs.append("ember_relight.takes_s must be above 0")

    # The dark keeps back to the circle.
    tc = dread.get("torch_circle")
    base_range = float(torch.get("light", {}).get("range_m", 0.0))
    base_burn = float(torch.get("burn_min", 0.0))
    if not isinstance(tc, dict):
        errs.append("dread.json: no torch_circle block (design §CQ)")
    elif abs(float(tc.get("reference_range_m", -1.0)) - base_range) > 1e-6:
        warns.append(f"dread.json torch_circle.reference_range_m {tc.get('reference_range_m')} != torch.json light.range_m {base_range}")

    # Report.
    print(f"Torch kinds (torch.json kinds.list; the brand is {base_range:g} m and {base_burn:g} min):")
    for kid, k in kinds.items():
        circle = base_range * float(k.get("circle_scale", 1.0))
        if k.get("numbers_in"):
            blk = torch.get(k["numbers_in"], {})
            burn = base_burn * float(blk.get("burn_scale", 1.0))
            rain = "unchanged" if blk.get("rain_immune") else "shorter"
        else:
            burn = base_burn * float(k.get("burn_scale", 1.0))
            rain = "unchanged" if k.get("rain_immune") else "shorter"
        genera = k.get("genera", [])
        grows = sorted(b for b, gs in bg.items() if set(genera) & gs) if genera else None
        where = "anywhere" if grows is None else (f"{len(grows)} biomes" if grows else "nowhere yet")
        print(f"  {kid:12} circle {circle:5.1f} m  burn {burn:5.1f} min  rain {rain:9}  grows: {where}")

    print("\nWhat each people's camps leave by the fire (peoples/biome_map.json by_biome):")
    tree_kinds = bundle.get("tree_kinds", [])
    for pid in sorted(set(v for v in bmap.get("by_biome", {}).values() if v)):
        biomes = sorted(b for b, v in bmap["by_biome"].items() if v == pid)
        lights = [by_technique[l] for l in peoples.get(pid, []) if l in by_technique and not kinds[by_technique[l]].get("numbers_in")]
        out = {}
        for b in biomes:
            gs = bg.get(b, set())
            pick = None
            for kid in lights:
                g = kinds[kid].get("genera", [])
                if not g or set(g) & gs:
                    pick = kid
                    break
                alt = kinds[kid].get("where_no_genus")
                if alt:
                    pick = alt
                    break
            if pick is None:
                for kid in tree_kinds:
                    if set(kinds[kid].get("genera", [])) & gs:
                        pick = kid
                        break
            out.setdefault(pick or fallback, []).append(b)
        print(f"  {pid:16} " + "; ".join(f"{k}: {', '.join(v)}" for k, v in out.items()))
    site_only = sorted(p for p in peoples if p not in set(bmap.get("by_biome", {}).values()))
    if site_only:
        print("  (by site rule, any biome: " + ", ".join(site_only) + ")")

    for w in warns:
        print("WARNING:", w)
    for e in errs:
        print("ERROR:", e)
    n_err = len(errs) + (len(warns) if args.strict else 0)
    plural = lambda n, word: f"{n} {word}{'' if n == 1 else 's'}"
    print(f"\n{plural(len(kinds), 'kind')}, {plural(len(errs), 'error')}, {plural(len(warns), 'warning')}")
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
