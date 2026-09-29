#!/usr/bin/env python3
"""Validate plant entries against docs/design/PLANT_SCHEMA.md.

Usage:
    python3 tools/plant_schema_check.py                # every file in data/plants and data/biomes
    python3 tools/plant_schema_check.py data/plants/pine.json [more files]
    python3 tools/plant_schema_check.py --strict ...   # also require every entry to carry the new blocks

Checks the optional new blocks (`leaf`, `bark`, `canopy`, `tint`, `photoperiod`, `soil`) on
every plant entry: allowed values, types and ranges, exactly as the schema lists them.
Entries without a block pass unless --strict (the fill is incremental). Exit code 1 on
any error. Data-fill agents run this before they finish a file.
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LEAF_TYPE = {"simple", "compound", "needle", "scale", "strap", "frond", "none"}
OUTLINE = {"ovate", "elliptic", "oblong", "obovate", "orbicular", "cordate", "sagittate", "hastate",
           "reniform", "peltate", "deltoid", "palmate_lobed", "pinnate_lobed", "linear"}
BASE = {"cuneate", "rounded", "truncate", "cordate", "oblique", "attenuate"}
APEX = {"acute", "acuminate", "obtuse", "rounded", "emarginate", "mucronate", "truncate"}
MARGIN = {"entire", "serrate", "dentate", "crenate", "undulate", "spinose", "ciliate", "lobed"}
VENATION = {"pinnate", "palmate", "parallel", "arcuate", "dichotomous", "none"}
ARRANGEMENT = {"alternate", "opposite", "whorled", "basal", "fascicled", "distichous", "spiral"}
TEXTURE = {"matte", "glossy", "velvety", "waxy_glaucous", "hairy_tomentose", "succulent"}
COMPOUND_FORM = {"pinnate", "bipinnate", "tripinnate", "palmate", "trifoliate", "pedate", "dissected"}
CANOPY_FORM = {"columnar", "conical", "pyramidal", "rounded", "spreading", "vase", "weeping", "umbrella",
               "irregular", "fastigiate", "layered", "palmate_crown", "rosette", "tussock", "mat",
               "climbing", "mound"}
LAYERING = {"clumped", "even", "tiered", "sparse"}
PHOTO_MODE = {"short_day", "long_day", "neutral"}
PHOTO_RESPONSE = {"flower", "bolt", "bud_set", "leaf_drop", "dormancy"}
SOIL_CLASS = {"basalt", "sand", "alluvium", "clay_peat", "till", "karst", "sandstone", "granite"}
DRAINAGE = {"poor", "moderate", "sharp"}
PH = {"acid", "neutral", "alkaline", "any"}
SALINITY = {"none", "tolerant", "needs"}
CONFIDENCE = {"documented", "estimated"}
BLADE_TYPES = {"simple", "compound", "strap", "frond"}
BARK_PATTERN = {"smooth", "fissured", "furrowed", "plated", "scaly", "flaky", "papery", "stringy", "ringed",
                "spiny", "warty", "green_stem", "none"}
BARK_ORIENT = {"vertical", "diamond", "horizontal", "none"}
LENTICELS = {"none", "dots", "horizontal_bands"}
ARCH_MODEL = {"rauh", "massart", "attims", "roux", "aubreville", "scarrone", "leeuwenberg", "koriba", "troll",
              "champagnat", "mangenot", "corner", "holttum", "schoute", "tomlinson"}
ARCH_HABIT = {"excurrent", "decurrent", "multi_stem", "columnar", "palm", "tree_fern", "weeping", "umbrella",
              "candelabra", "shrub"}
BUTTRESS = {"none", "low", "high"}


class Report:
    def __init__(self):
        self.errors = []
        self.entries = 0
        self.with_leaf = 0
        self.with_bark = 0

    def err(self, where, msg):
        self.errors.append("%s: %s" % (where, msg))


def _enum(rep, where, d, key, allowed, required=True):
    if key not in d:
        if required:
            rep.err(where, "missing '%s'" % key)
        return
    if d[key] not in allowed:
        rep.err(where, "'%s' = %r not in %s" % (key, d[key], sorted(allowed)))


def _num(rep, where, d, key, lo, hi, required=True):
    if key not in d:
        if required:
            rep.err(where, "missing '%s'" % key)
        return
    v = d[key]
    if not isinstance(v, (int, float)) or isinstance(v, bool):
        rep.err(where, "'%s' must be a number" % key)
    elif not (lo <= v <= hi):
        rep.err(where, "'%s' = %r outside [%s, %s]" % (key, v, lo, hi))


def _range(rep, where, d, key, lo, hi, required=True):
    if key not in d:
        if required:
            rep.err(where, "missing '%s'" % key)
        return
    v = d[key]
    if not (isinstance(v, list) and len(v) == 2 and all(isinstance(x, (int, float)) for x in v)):
        rep.err(where, "'%s' must be [min, max]" % key)
    elif not (lo <= v[0] <= v[1] <= hi):
        rep.err(where, "'%s' = %r not an ordered range within [%s, %s]" % (key, v, lo, hi))


def check_leaf(rep, where, leaf):
    if not isinstance(leaf, dict):
        rep.err(where, "'leaf' must be an object"); return
    _enum(rep, where, leaf, "type", LEAF_TYPE)
    t = leaf.get("type")
    if t in BLADE_TYPES:
        if t == "compound" or t == "frond":
            comp = leaf.get("compound")
            if not isinstance(comp, dict):
                rep.err(where, "'%s' leaves need a 'compound' block" % t)
            else:
                w = where + ".compound"
                _enum(rep, w, comp, "form", COMPOUND_FORM)
                _range(rep, w, comp, "leaflets", 1, 2000)
                _enum(rep, w, comp, "leaflet_outline", OUTLINE)
                _num(rep, w, comp, "leaflet_aspect", 0.5, 40)
                _enum(rep, w, comp, "leaflet_margin", MARGIN)
        else:
            _enum(rep, where, leaf, "outline", OUTLINE)
            _num(rep, where, leaf, "aspect", 0.5, 60)
            _enum(rep, where, leaf, "base", BASE)
            _enum(rep, where, leaf, "apex", APEX)
            _enum(rep, where, leaf, "margin", MARGIN)
            if leaf.get("outline", "").endswith("_lobed"):
                _num(rep, where, leaf, "lobes", 2, 15)
                if leaf.get("margin") != "lobed":
                    rep.err(where, "a *_lobed outline needs margin 'lobed'")
            elif leaf.get("margin") == "lobed":
                rep.err(where, "margin 'lobed' needs a *_lobed outline")
        _enum(rep, where, leaf, "venation", VENATION)
        _enum(rep, where, leaf, "arrangement", ARRANGEMENT)
        _range(rep, where, leaf, "size_cm", 0.05, 1500)
        _enum(rep, where, leaf, "texture", TEXTURE)
    elif t in {"needle", "scale"}:
        _enum(rep, where, leaf, "arrangement", ARRANGEMENT)
        _range(rep, where, leaf, "size_cm", 0.05, 60)
        _enum(rep, where, leaf, "texture", TEXTURE, required=False)
        if leaf.get("venation", "none") != "none":
            rep.err(where, "needles/scales have venation 'none'")
    if leaf.get("arrangement") == "fascicled":
        _num(rep, where, leaf, "fascicle", 1, 8)
    _enum(rep, where, leaf, "confidence", CONFIDENCE, required=False)


def check_canopy(rep, where, c):
    if not isinstance(c, dict):
        rep.err(where, "'canopy' must be an object"); return
    _enum(rep, where, c, "form", CANOPY_FORM)
    _num(rep, where, c, "gap", 0.05, 0.95)
    _enum(rep, where, c, "layering", LAYERING)
    _num(rep, where, c, "droop", 0.0, 1.0)


def check_tint(rep, where, t):
    if not isinstance(t, dict):
        rep.err(where, "'tint' must be an object"); return
    _num(rep, where, t, "hue_shift", -40, 40)
    _num(rep, where, t, "sat", 0.3, 1.6)
    _num(rep, where, t, "val", 0.4, 1.4)
    _num(rep, where, t, "underside", 0.0, 1.0, required=False)
    if "autumn" in t and not (isinstance(t["autumn"], str) and t["autumn"].startswith("#") and len(t["autumn"]) == 7):
        rep.err(where, "'autumn' must be a #rrggbb hex")
    if "drop" in t and not isinstance(t["drop"], bool):
        rep.err(where, "'drop' must be true/false")


def _hex(rep, where, d, key, required=True):
    v = d.get(key)
    if v is None:
        if required:
            rep.err(where, "missing '%s'" % key)
        return
    if not (isinstance(v, str) and v.startswith("#") and len(v) == 7):
        rep.err(where, "'%s' must be a #rrggbb hex" % key)


def check_bark(rep, where, b):
    if not isinstance(b, dict):
        rep.err(where, "'bark' must be an object"); return
    _enum(rep, where, b, "pattern", BARK_PATTERN)
    if b.get("pattern") == "none":
        return
    _enum(rep, where, b, "orientation", BARK_ORIENT)
    if b.get("orientation") != "none" and b.get("pattern") not in ("fissured", "furrowed", "plated", "flaky"):
        rep.err(where, "'orientation' is only for fissured/furrowed/plated/flaky (use 'none')")
    _num(rep, where, b, "depth", 0.0, 1.0)
    _num(rep, where, b, "scale_cm", 0.2, 200)
    _hex(rep, where, b, "color")
    _hex(rep, where, b, "color_2")
    _enum(rep, where, b, "lenticels", LENTICELS)
    _enum(rep, where, b, "confidence", CONFIDENCE, required=False)


def check_architecture(rep, where, b):
    """docs/design/TREE_ARCHITECTURE.md §5 (woody species only; optional)."""
    if not isinstance(b, dict):
        rep.err(where, "'architecture' must be an object"); return
    _enum(rep, where, b, "model", ARCH_MODEL)
    _enum(rep, where, b, "habit", ARCH_HABIT)
    _num(rep, where, b, "orders", 0, 9)
    _range(rep, where, b, "branch_angle_deg", 0, 120)
    _num(rep, where, b, "taper_exponent", 0.8, 3.0)
    _num(rep, where, b, "sinuosity", 0.0, 1.0)
    if b.get("fork_height_frac") is not None:
        _range(rep, where, b, "fork_height_frac", 0.0, 1.0)
    _enum(rep, where, b, "buttress", BUTTRESS)
    _num(rep, where, b, "lean_max_deg", 0, 60)
    v = b.get("live_crown_ratio")
    if not (isinstance(v, list) and len(v) == 2 and all(isinstance(x, (int, float)) and 0.05 <= x <= 1.0 for x in v)):
        rep.err(where, "'live_crown_ratio' must be [open_grown, forest_grown] in 0.05-1")
    for k in ("self_prune", "root_flare"):
        if k in b and not isinstance(b[k], bool):
            rep.err(where, "'%s' must be true/false" % k)
    _num(rep, where, b, "dead_limbs", 0.0, 1.0)
    _num(rep, where, b, "spacing_m", 0.02, 6.0)
    _enum(rep, where, b, "confidence", CONFIDENCE, required=False)


def check_photoperiod(rep, where, p):
    if not isinstance(p, dict):
        rep.err(where, "'photoperiod' must be an object"); return
    _enum(rep, where, p, "mode", PHOTO_MODE)
    if p.get("mode") != "neutral":
        _num(rep, where, p, "threshold_h", 6, 20)
        _enum(rep, where, p, "response", PHOTO_RESPONSE)


def check_soil(rep, where, s):
    if isinstance(s, str):
        return  # the old single-word form ('rich', 'poor'...) is still read by species_db
    if not isinstance(s, dict):
        rep.err(where, "'soil' must be an object (or the old string)"); return
    cl = s.get("classes")
    if not (isinstance(cl, list) and cl and all(x in SOIL_CLASS for x in cl)):
        rep.err(where, "'soil.classes' must be a non-empty list from %s" % sorted(SOIL_CLASS))
    _enum(rep, where, s, "drainage", DRAINAGE)
    _enum(rep, where, s, "ph", PH)
    _num(rep, where, s, "fertility_min", 0.0, 1.0)
    _enum(rep, where, s, "salinity", SALINITY)


def check_entry(rep, where, e, strict):
    rep.entries += 1
    if "leaf" in e:
        rep.with_leaf += 1
        check_leaf(rep, where + ".leaf", e["leaf"])
    elif strict:
        rep.err(where, "missing 'leaf'")
    for key, fn in (("canopy", check_canopy), ("tint", check_tint), ("photoperiod", check_photoperiod)):
        if key in e:
            fn(rep, where + "." + key, e[key])
        elif strict and "leaf" in e:
            rep.err(where, "missing '%s'" % key)
    if "architecture" in e:
        check_architecture(rep, where + ".architecture", e["architecture"])
    if "bark" in e:
        rep.with_bark += 1
        check_bark(rep, where + ".bark", e["bark"])
    elif strict:
        rep.err(where, "missing 'bark'")
    if "soil" in e:
        check_soil(rep, where + ".soil", e["soil"])
    elif strict:
        rep.err(where, "missing 'soil'")


def iter_entries(doc):
    """Both layouts: {'plants': {tier: [entries]}} (biomes, catalogues) or {'plants': [entries]}."""
    plants = doc.get("plants")
    if isinstance(plants, dict):
        for tier, lst in plants.items():
            if isinstance(lst, list):
                for i, e in enumerate(lst):
                    if isinstance(e, dict):
                        yield "%s[%d] %s" % (tier, i, e.get("name", "?")), e
    elif isinstance(plants, list):
        for i, e in enumerate(plants):
            if isinstance(e, dict):
                yield "[%d] %s" % (i, e.get("name", "?")), e


def check_file(path, rep, strict):
    try:
        doc = json.load(open(path))
    except Exception as ex:
        rep.err(path, "not valid JSON: %s" % ex); return
    for where, e in iter_entries(doc):
        check_entry(rep, "%s :: %s" % (os.path.relpath(path, ROOT), where), e, strict)


def main(argv):
    strict = "--strict" in argv
    files = [a for a in argv if not a.startswith("--")]
    if not files:
        files = sorted(glob.glob(os.path.join(ROOT, "data", "plants", "*.json")) +
                       glob.glob(os.path.join(ROOT, "data", "biomes", "*.json")))
    rep = Report()
    for f in files:
        check_file(f, rep, strict)
    for e in rep.errors:
        print("ERROR", e)
    print("%d entries checked, %d with a leaf block, %d with a bark block, %d errors" % (rep.entries, rep.with_leaf, rep.with_bark, len(rep.errors)))
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
