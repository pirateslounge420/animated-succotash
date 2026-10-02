#!/usr/bin/env python3
"""Kindling check (design 30 Sept doc §CN): the gate for fuel.json -> kindling.

A cold fire (a hearth or brazier that is fully out) needs kindling laid before
the torch's swing will light it, and kindling is whatever is fine and dry where
you are, real for each biome. This script checks the data that says so:

  python3 tools/kindling_check.py                 # the merged block in data/fuel.json
  python3 tools/kindling_check.py --fragment F    # one fill agent's fragment (its own biomes only)
  python3 tools/kindling_check.py --strict        # warnings count as errors

What it checks
- every kind: a snake_case id; name, from, gather, catch_dry, catch_wet, wet_ok,
  burn_s, carry_items and at least one source; catch values in 0..1 with
  catch_wet <= catch_dry; wet_ok is true exactly when catch_wet >= the block's
  wet_threshold; plant and fungus kinds name their genera.
- a kind whose id is also a fuel kind (grass_bundle, reeds) is that same item:
  the fuel kind must exist.
- every biome list: real fuel.json biome keys, known kind ids, no repeats; empty
  only where the biome offers no fuel at all (fuel.json -> biomes is {}).
- the species gate (§CA): a kind tied to genera may only be listed in a biome
  whose plant file (data/biomes/*.json) holds at least one of those genera.
  Missing genus = warning (error with --strict). Litter kinds tied to genera
  (conifer needles) follow the same rule.
- merged mode: every fuel.json biome has a kindling list.

Plain Python 3, no packages. Exit code 1 on any error.
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUEL = os.path.join(ROOT, "data", "fuel.json")
BIOMES_DIR = os.path.join(ROOT, "data", "biomes")

GATHER = {"litter", "plant", "fungus", "lichen", "ground", "animal"}
NEEDS_GENERA = {"plant", "fungus", "lichen"}
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def biome_genera():
    """Biome key -> set of genera in that biome's plant file."""
    out = {}
    for f in sorted(glob.glob(os.path.join(BIOMES_DIR, "*.json"))):
        d = load(f)
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


def check_kind(kid, k, fuel_kinds, wet_threshold, errs, warns):
    where = f"kinds.{kid}"
    if not ID_RE.match(kid):
        errs.append(f"{where}: id must be snake_case")
    if not isinstance(k, dict):
        errs.append(f"{where}: must be an object")
        return
    for field in ("name", "from"):
        if not isinstance(k.get(field), str) or not k.get(field).strip():
            errs.append(f"{where}: '{field}' must be a non-empty string")
    g = k.get("gather")
    if g not in GATHER:
        errs.append(f"{where}: gather must be one of {sorted(GATHER)}")
    gen = k.get("genera", [])
    if not isinstance(gen, list) or not all(isinstance(x, str) and x[:1].isupper() for x in gen):
        errs.append(f"{where}: genera must be a list of capitalised genus names")
        gen = []
    if g in NEEDS_GENERA and not gen:
        errs.append(f"{where}: a {g} kind must name its genera")
    cd, cw = k.get("catch_dry"), k.get("catch_wet")
    for name, v in (("catch_dry", cd), ("catch_wet", cw)):
        if not isinstance(v, (int, float)) or not 0.0 <= v <= 1.0:
            errs.append(f"{where}: {name} must be a number in 0..1")
    if isinstance(cd, (int, float)) and isinstance(cw, (int, float)) and cw > cd:
        errs.append(f"{where}: catch_wet ({cw}) cannot be above catch_dry ({cd})")
    if isinstance(cd, (int, float)) and cd < 0.5:
        warns.append(f"{where}: catch_dry {cd} is below 0.5 — is it really kindling?")
    wo = k.get("wet_ok")
    if not isinstance(wo, bool):
        errs.append(f"{where}: wet_ok must be true or false")
    elif isinstance(cw, (int, float)) and wo != (cw >= wet_threshold):
        errs.append(f"{where}: wet_ok must be {cw >= wet_threshold} when catch_wet is {cw} (threshold {wet_threshold})")
    bs = k.get("burn_s")
    if not isinstance(bs, (int, float)) or not 1 <= bs <= 600:
        errs.append(f"{where}: burn_s must be 1..600 seconds")
    ci = k.get("carry_items")
    if not isinstance(ci, int) or ci < 1:
        errs.append(f"{where}: carry_items must be a whole number >= 1")
    src = k.get("sources")
    if not isinstance(src, list) or not src or not all(isinstance(s, str) and len(s.strip()) > 8 for s in src):
        errs.append(f"{where}: needs at least one real source (a URL or a named book/manual)")
    for opt in ("notes", "season"):
        if opt in k and not isinstance(k[opt], str):
            errs.append(f"{where}: {opt} must be a string")
    if kid in fuel_kinds and k.get("fuel_kind") is not True:
        warns.append(f"{where}: shares its id with a fuel kind — set fuel_kind: true (it is the same carried item)")
    if k.get("fuel_kind") is True and kid not in fuel_kinds:
        errs.append(f"{where}: fuel_kind is true but fuel.json kinds has no '{kid}'")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--fragment", help="a fill agent's fragment JSON (kinds + biomes for its family)")
    ap.add_argument("--strict", action="store_true", help="warnings count as errors")
    a = ap.parse_args()

    fuel = load(FUEL)
    block = fuel.get("kindling")
    errs, warns = [], []
    if not isinstance(block, dict):
        print("kindling_check: data/fuel.json has no 'kindling' block")
        return 1
    fuel_kinds = set(k for k in fuel.get("kinds", {}) if not k.startswith("_"))
    fuel_biomes = {k: v for k, v in fuel.get("biomes", {}).items() if not k.startswith("_")}
    wet_threshold = float(block.get("catch", {}).get("wet_threshold", 0.5))

    kinds = {k: v for k, v in block.get("kinds", {}).items() if not k.startswith("_")}
    biomes = {k: v for k, v in block.get("biomes", {}).items() if not k.startswith("_")}
    frag_kinds = {}
    if a.fragment:
        frag = load(a.fragment)
        frag_kinds = {k: v for k, v in frag.get("kinds", {}).items() if not k.startswith("_")}
        clash = sorted(set(frag_kinds) & set(kinds))
        for kid in clash:
            errs.append(f"kinds.{kid}: already a core kind in fuel.json — reuse it by id, don't redefine it")
        kinds = {**kinds, **frag_kinds}
        biomes = {k: v for k, v in frag.get("biomes", {}).items() if not k.startswith("_")}
        if not biomes:
            errs.append("fragment: 'biomes' is empty")

    for kid, k in sorted(kinds.items()):
        if a.fragment and kid not in frag_kinds:
            continue  # core kinds are checked in merged mode
        check_kind(kid, k, fuel_kinds, wet_threshold, errs, warns)

    genera_in = biome_genera()
    used = set()
    for bkey, lst in sorted(biomes.items()):
        where = f"biomes.{bkey}"
        if bkey not in fuel_biomes:
            errs.append(f"{where}: not a fuel.json biome key")
            continue
        if not isinstance(lst, list) or not all(isinstance(x, str) for x in lst):
            errs.append(f"{where}: must be a list of kind ids")
            continue
        if len(set(lst)) != len(lst):
            errs.append(f"{where}: repeats a kind")
        offers_fuel = bool(fuel_biomes[bkey])
        if not lst and offers_fuel:
            errs.append(f"{where}: empty, but the biome offers fuel — a laid fire there needs some kindling")
        if lst and not offers_fuel:
            warns.append(f"{where}: lists kindling but fuel.json offers no fuel here")
        if len(lst) > 6:
            warns.append(f"{where}: {len(lst)} kinds — keep it to the few that matter (2–5)")
        for kid in lst:
            used.add(kid)
            if kid not in kinds:
                errs.append(f"{where}: unknown kind '{kid}'")
                continue
            gen = kinds[kid].get("genera") or []
            if gen and bkey in genera_in and not (set(gen) & genera_in[bkey]):
                warns.append(f"{where}: '{kid}' comes from {', '.join(gen)}, none of which grows in this biome's plant file (§CA species gate)")

    if not a.fragment:
        for bkey in sorted(fuel_biomes):
            if bkey not in biomes:
                errs.append(f"biomes.{bkey}: missing — every fuel.json biome needs a kindling list (empty only where it offers no fuel)")
        for kid in sorted(set(kinds) - used):
            warns.append(f"kinds.{kid}: defined but listed in no biome")

    if a.strict:
        errs, warns = errs + warns, []
    for e in errs:
        print("ERROR  " + e)
    for w in warns:
        print("warn   " + w)
    scope = os.path.basename(a.fragment) if a.fragment else "data/fuel.json"
    print(f"kindling_check ({scope}): {len(frag_kinds) if a.fragment else len(kinds)} kinds, {len(biomes)} biomes, {len(errs)} errors, {len(warns)} warnings")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
