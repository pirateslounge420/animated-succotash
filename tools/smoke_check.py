#!/usr/bin/env python3
"""Smoke check (design 3 Oct §CV): the gate for data/smoke.json.

Every lit hearth sends up a column; the ruins' underground hearths breathe through a stack
above each one; a cold stack is a place swifts roost; a wildfire has its own plume. This
script checks the data that says so and prints how far off each column can be seen over
the curve of the planet:

  python3 tools/smoke_check.py            # check and report
  python3 tools/smoke_check.py --strict   # warnings count as errors

What it checks
- hearth.by_state has exactly the fire states FireStore uses (flames, flare, low, embers,
  out); the column shrinks flames > low > embers > out, and "out" is nothing.
- hearth.sources and hearth.never don't overlap; the wind, rain, night, look and far
  blocks carry the keys §CV names; colours are #RRGGBB and none is a neutral grey
  (LOOK_REFERENCE R3: shade takes the scene's colour, never grey).
- outlets.by_ruin has the same ruin kinds as delves.json fire_holders.by_ruin, and every
  outlet named anywhere is a form in outlets.forms.
- outlets.mouth names real nests (landforms.json ids); outlets.passable is false (§CJ.4).
- outlets.per_delve.share_nearest are fire-holders delves.json uses.
- swifts: forms are real forms at least min_width_m wide; stay_away_states are fire
  states; the species carries a source.
- wildfire_plume is taller, wider and seen from farther than a hearth's column.
- hearth.far.seen_to_m is not beyond what the curve of the 400 km planet allows for the
  full column's top (world_scale.json planet.circumference_m), so the data never promises
  a sight the planet hides.

Plain Python 3, no packages. Exit code 1 on any error.
"""
import argparse
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
STATES = ["flames", "flare", "low", "embers", "out"]
EYE_M = 1.6
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


def load(*parts):
    with open(os.path.join(DATA, *parts), encoding="utf-8") as f:
        return json.load(f)


def seen_from_m(radius_m, top_m, eye_m=EYE_M):
    """Farthest distance over level ground at which the top of a column top_m high
    still shows above the horizon to an eye eye_m up."""
    return math.sqrt(2.0 * radius_m * eye_m) + math.sqrt(2.0 * radius_m * max(top_m, 0.0))


def is_grey(hexcol, tol=10):
    r, g, b = (int(hexcol[i:i + 2], 16) for i in (1, 3, 5))
    return max(r, g, b) - min(r, g, b) <= tol


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()
    errors, warnings = [], []
    err, warn = errors.append, warnings.append

    s = load("smoke.json")
    delves = load("delves.json")
    landforms = load("landforms.json")["landforms"]
    nest_ids = set(landforms.keys()) if isinstance(landforms, dict) else {x.get("id") for x in landforms}
    try:
        circ = float(load("world_scale.json")["planet"]["circumference_m"])
    except Exception:
        circ = 400000.0
        warn("world_scale.json planet.circumference_m not found; using 400 km")
    radius = circ / (2.0 * math.pi)

    # --- hearth ---
    h = s.get("hearth", {})
    by = h.get("by_state", {})
    if sorted(by.keys()) != sorted(STATES):
        err("hearth.by_state must have exactly %s (has %s)" % (STATES, sorted(by.keys())))
    for st, row in by.items():
        for k in ("top_m", "width_m", "density"):
            if not isinstance(row.get(k), (int, float)) or row[k] < 0:
                err("hearth.by_state.%s.%s must be a number >= 0" % (st, k))
        if isinstance(row.get("density"), (int, float)) and row["density"] > 1:
            err("hearth.by_state.%s.density must be 0-1" % st)
    if all(st in by for st in STATES):
        tops = [by[st]["top_m"] for st in ("flames", "low", "embers", "out")]
        if not (tops[0] > tops[1] > tops[2] > tops[3]):
            err("the column must shrink flames > low > embers > out (tops %s)" % tops)
        if by["out"]["top_m"] != 0 or by["out"]["density"] != 0:
            err("a fire that is out sends up nothing")
        if by["embers"]["top_m"] <= 0:
            err("embers must keep a wisp (§BL: the tell that a fire can still be saved)")
    src, nev = set(h.get("sources", [])), set(h.get("never", []))
    if src & nev:
        err("hearth.sources and hearth.never overlap: %s" % sorted(src & nev))
    for block, keys in (("wind", ["lean_deg_per_mps", "max_lean_deg", "calm_below_mps", "shear"]),
                        ("calm_pool", ["when", "at_m", "spread_m"]),
                        ("rain", ["from_mm_h", "top_scale", "density_scale"]),
                        ("night", ["draw_column", "fire_lit_m", "canopy_glow"]),
                        ("look", ["cards", "billboard", "texels", "bands", "cutout", "colour_near", "colour_far", "colour_shade"]),
                        ("far", ["from_sim_state", "seen_to_m", "min_px"])):
        for k in keys:
            if k not in h.get(block, {}):
                err("hearth.%s.%s is missing" % (block, k))
    if h.get("night", {}).get("draw_column") is not False:
        err("hearth.night.draw_column must be false: smoke gives off no light (§CV 1)")
    if not 0 < float(h.get("stack_scale", 0)) <= 1:
        err("hearth.stack_scale must be in (0, 1]")

    colours = {"hearth.look." + k: v for k, v in h.get("look", {}).items() if k.startswith("colour")}
    colours["outlets.soot.colour"] = s.get("outlets", {}).get("soot", {}).get("colour", "")
    for k in ("colour_near", "colour_far"):
        colours["wildfire_plume." + k] = s.get("wildfire_plume", {}).get(k, "")
    for name, col in colours.items():
        if not isinstance(col, str) or not HEX.match(col):
            err("%s must be #RRGGBB (is %r)" % (name, col))
        elif is_grey(col):
            err("%s %s is a neutral grey (LOOK_REFERENCE R3: never grey)" % (name, col))

    # --- outlets ---
    o = s.get("outlets", {})
    forms = o.get("forms", {})
    want = set(delves.get("fire_holders", {}).get("by_ruin", {}).keys())
    have = set(o.get("by_ruin", {}).keys())
    if want != have:
        err("outlets.by_ruin kinds differ from delves.json fire_holders.by_ruin: missing %s, extra %s"
            % (sorted(want - have), sorted(have - want)))
    for where in ("by_ruin", "surface_old_hearth"):
        for kind, form in o.get(where, {}).items():
            if form not in forms:
                err("outlets.%s.%s names %r, which is not in outlets.forms" % (where, kind, form))
    for form, row in forms.items():
        hm = row.get("height_m")
        if not (isinstance(hm, list) and len(hm) == 2 and 0 <= hm[0] <= hm[1]):
            err("outlets.forms.%s.height_m must be [min, max]" % form)
        if not isinstance(row.get("width_m"), (int, float)):
            err("outlets.forms.%s.width_m must be a number" % form)
    for nest in o.get("mouth", []):
        if nest not in nest_ids:
            err("outlets.mouth names %r, which is not a landforms.json nest" % nest)
    if o.get("passable") is not False:
        err("outlets.passable must be false: a flue is never a way in or out (§CJ.4)")
    holders = set(delves.get("fire_holders", {}).get("by_ruin", {}).values())
    holders.add(delves.get("fire_holders", {}).get("heart", ""))
    for fh in o.get("per_delve", {}).get("share_nearest", []):
        if fh not in holders:
            err("outlets.per_delve.share_nearest names %r, not a delves.json fire-holder" % fh)
    for own in o.get("per_delve", {}).get("own_stack", []):
        if own not in ("first_room", "heart"):
            err("outlets.per_delve.own_stack: %r is not first_room or heart" % own)

    # --- swifts ---
    sw = s.get("swifts", {})
    minw = float(sw.get("min_width_m", 0))
    for form in sw.get("forms", []):
        if form not in forms:
            err("swifts.forms names %r, which is not in outlets.forms" % form)
        elif float(forms[form].get("width_m", 0)) < minw:
            err("swifts.forms: %s is %.1f m wide, under min_width_m %.1f" % (form, forms[form]["width_m"], minw))
    for st in sw.get("lit_below", {}).get("stay_away_states", []):
        if st not in STATES:
            err("swifts.lit_below.stay_away_states: %r is not a fire state" % st)
    if "out" in sw.get("lit_below", {}).get("stay_away_states", []):
        err("swifts must be able to come back to a hearth that is out")
    if not 0 <= float(sw.get("share_of_stacks", -1)) <= 1:
        err("swifts.share_of_stacks must be 0-1")
    fl = sw.get("flock", [])
    if not (isinstance(fl, list) and len(fl) == 2 and 0 < fl[0] <= fl[1]):
        err("swifts.flock must be [min, max]")
    sd = sw.get("dusk", {}).get("sun_deg", [])
    if not (isinstance(sd, list) and len(sd) == 2 and sd[0] > sd[1]):
        err("swifts.dusk.sun_deg must be [from, to] with the sun going down")
    if not sw.get("species", {}).get("source"):
        err("swifts.species needs a source")
    if not isinstance(sw.get("overrun", {}).get("roost"), bool):
        err("swifts.overrun.roost must be true or false")

    # --- wildfire plume ---
    p = s.get("wildfire_plume", {})
    full = by.get("flames", {})
    for k in ("top_m", "width_m"):
        if not float(p.get(k, 0)) > float(full.get(k, 0)):
            err("wildfire_plume.%s must be larger than a hearth's full column" % k)
    if not float(p.get("seen_to_m", 0)) > float(h.get("far", {}).get("seen_to_m", 0)):
        err("wildfire_plume.seen_to_m must be farther than hearth.far.seen_to_m")

    # --- the curve of the planet ---
    full_top = float(full.get("top_m", 0))
    limit = seen_from_m(radius, full_top)
    if float(h.get("far", {}).get("seen_to_m", 0)) > limit + 1.0:
        err("hearth.far.seen_to_m %.0f is past the %.0f m the planet's curve allows for a %.0f m column"
            % (h["far"]["seen_to_m"], limit, full_top))
    plimit = seen_from_m(radius, float(p.get("top_m", 0)))
    if float(p.get("seen_to_m", 0)) > plimit + 1.0:
        err("wildfire_plume.seen_to_m %.0f is past the %.0f m the planet's curve allows"
            % (p["seen_to_m"], plimit))

    # --- report ---
    print("Smoke check (design §CV)")
    print("planet %.0f km around (radius %.1f km); eye %.1f m; ground horizon %.0f m"
          % (circ / 1000.0, radius / 1000.0, EYE_M, math.sqrt(2 * radius * EYE_M)))
    print("how far off the TOP of each column shows over level ground:")
    stack_scale = float(h.get("stack_scale", 1.0))
    for st in ("flames", "low", "flare", "embers"):
        if st in by:
            top = float(by[st]["top_m"])
            print("  %-7s open fire %5.0f m tall: %5.0f m   from a stack %5.0f m tall: %5.0f m"
                  % (st, top, seen_from_m(radius, top), top * stack_scale, seen_from_m(radius, top * stack_scale)))
    print("  wildfire plume    %5.0f m tall: %5.0f m" % (float(p.get("top_m", 0)), plimit))
    print("  the same full column on a 4,000 km planet: %.0f m" % seen_from_m(4000000.0 / (2 * math.pi), full_top))
    print("stacks by ruin: " + ", ".join("%s -> %s" % kv for kv in sorted(o.get("by_ruin", {}).items())))
    print("nests that clear through the mouth: " + ", ".join(o.get("mouth", [])))
    print("swift stacks: " + ", ".join(sw.get("forms", [])))

    for w in warnings:
        print("WARNING: " + w)
    for e in errors:
        print("ERROR: " + e)
    print("%d errors, %d warnings" % (len(errors), len(warnings)))
    if errors or (args.strict and warnings):
        sys.exit(1)


if __name__ == "__main__":
    main()
