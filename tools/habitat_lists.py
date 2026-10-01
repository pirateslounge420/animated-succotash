#!/usr/bin/env python3
"""The biome gate's listings (design 1 Oct §CA, data/habitat.json), for the
tools: which species each biome lists, from the data alone, the same way
SpeciesDB reads it: a biome file's plants tiers, its associations' lists
named in habitat.json association_lists_count, and a catalogue entry's own
`biomes`. The union over files per species; a catalogue-only entry with no
list is "unlisted" (grows nowhere) when catalogue_needs_biomes is true.
"""
import glob
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIERS = ("emergent", "canopy", "shrub", "ground", "epiphyte")


def biome_keys():
    keys = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "biomes", "*.json"))):
        try:
            keys.append(json.load(open(f)).get("key", ""))
        except Exception:
            pass
    return [k for k in keys if k]


def habitat():
    try:
        return json.load(open(os.path.join(ROOT, "data", "habitat.json")))
    except Exception:
        return {}


def listings():
    """name -> {"tier": tier, "files": [basenames], "biomes": set(keys), "catalogue": bool}
    and a list of unlisted catalogue-only species names."""
    hab = habitat()
    roles = hab.get("association_lists_count", ["dominant", "companion", "ground", "catalogue"])
    needs = bool(hab.get("catalogue_needs_biomes", True))
    species = {}
    assoc = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "biomes", "*.json"))):
        d = json.load(open(f))
        key = d.get("key", "")
        base = os.path.basename(f)
        for tier, lst in (d.get("plants") or {}).items():
            if not isinstance(lst, list):
                continue
            for e in lst:
                name = e.get("name") if isinstance(e, dict) else e
                if not name:
                    continue
                sp = species.setdefault(name, {"tier": tier, "files": [], "biomes": set(), "catalogue": False})
                sp["files"].append(base)
                sp["biomes"].add(key)
        for a in d.get("associations", []) or []:
            if not isinstance(a, dict):
                continue
            for role in roles:
                for n in a.get(role, []) or []:
                    assoc.setdefault(str(n), set()).add(key)
    unlisted = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "plants", "*.json"))):
        d = json.load(open(f))
        base = os.path.basename(f)
        for tier, lst in (d.get("plants") or {}).items():
            if not isinstance(lst, list):
                continue
            for e in lst:
                if not isinstance(e, dict) or "name" not in e:
                    continue
                name = e["name"]
                had = name in species
                sp = species.setdefault(name, {"tier": tier, "files": [], "biomes": set(), "catalogue": True})
                sp["files"].append(base)
                sp["catalogue"] = True
                listed = e.get("biomes") if isinstance(e.get("biomes"), list) else []
                sp["biomes"].update(str(b) for b in listed)
                if not listed and not had and needs:
                    unlisted.append(name)
    for n, keys in assoc.items():
        if n in species:
            species[n]["biomes"].update(keys)
    # An association listing clears "unlisted".
    unlisted = [n for n in unlisted if not species[n]["biomes"]]
    return species, unlisted


def allowed_by_biome():
    """key -> list of (name, tier, "file1+file2") the gate allows there."""
    species, _ = listings()
    out = {k: [] for k in biome_keys()}
    for name, sp in species.items():
        for k in sp["biomes"]:
            if k in out:
                out[k].append((name, sp["tier"], "+".join(sp["files"])))
    for k in out:
        out[k].sort(key=lambda t: (TIERS.index(t[1]) if t[1] in TIERS else 9, t[0]))
    return out
