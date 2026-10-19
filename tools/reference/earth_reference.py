#!/usr/bin/env python3
"""Earth reference (design 18 Oct §FX): the numbers behind the real Earth at 1/100.

Prints, from data/world_scale.json and data/earth/earth.json:
- the scale table: real distances and heights against the game's (1/100 sideways, 1/10 up),
  with walking times at the ambient walk;
- the slope table: a slope on Earth against the slope the game shows for it (ten times), with
  Tobler's pace factor at the game's slope (§CR.5);
- the map budgets: for each candidate resolution, samples, bytes, Earth km per sample and game
  metres per sample, against the blueprint cell and the terrain chunk;
- the named peaks at the game's height scale;
- the horizon, as §CR.7 gave it (unchanged by the real map).

The engine's own checks (queue 103, 106) should agree with these numbers (WORKING_AGREEMENT:
verification is cross-agent). Plain Python 3, no packages.

  python3 tools/reference/earth_reference.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WS = os.path.join(ROOT, "data", "world_scale.json")
EARTH = os.path.join(ROOT, "data", "earth", "earth.json")

EARTH_CIRC_M = 40_075_000.0
EARTH_RADIUS_M = 6_371_000.0
EYE_M = 1.6
GAME_H_PER_REAL_H = 10.0  # the 144-minute day
BLUEPRINT_CELLS_PER_FACE = 96
CHUNK_M = 260.0


def tobler(slope, a=3.5, b=0.05):
    """Tobler's hiking function scaled to the flat walk (§CR.5), no downhill boost."""
    return min(1.0, math.exp(-a * abs(slope + b)) / math.exp(-a * b))


def main():
    with open(WS, encoding="utf-8") as f:
        ws = json.load(f)
    with open(EARTH, encoding="utf-8") as f:
        earth = json.load(f)
    circ = ws["planet"]["circumference_m"]
    hscale = ws["heights"]["height_scale"]
    dscale = circ / EARTH_CIRC_M
    walk = ws["pace"].get("flat_walk_mps", 4.3)
    a = ws["pace"]["tobler"]["a"]
    b = ws["pace"]["tobler"]["b"]

    print(f"planet {circ / 1000:.0f} km around = 1/{1 / dscale:.0f} Earth sideways; heights x{hscale}; "
          f"day {24 / GAME_H_PER_REAL_H * 60:.0f} real minutes\n")

    print("SCALE  (Earth -> here; walk at %.1f m/s)" % walk)
    rows = [("around the planet", EARTH_CIRC_M), ("USA coast to coast", 4_500_000), ("Amazon basin across", 3_000_000),
            ("Sahara across", 4_800_000), ("Britain top to bottom", 1_000_000), ("Mediterranean, long axis", 3_800_000),
            ("Madagascar, long axis", 1_600_000), ("one blueprint cell", circ / dscale / (4 * BLUEPRINT_CELLS_PER_FACE)),
            ("one terrain chunk", CHUNK_M / dscale)]
    for name, m in rows:
        here = m * dscale
        hrs = here / walk / 3600
        print(f"  {name:<26} {m / 1000:>9,.0f} km -> {here / 1000:>7,.1f} km   {hrs:6.1f} real h = {hrs * GAME_H_PER_REAL_H / 24:5.1f} game days")
    print()

    print("HEIGHTS (x%.1f): the named peaks" % hscale)
    for p in earth["peaks"]["list"]:
        print(f"  {p['name']:<14} {p['height_m']:>5} m -> {p['height_m'] * hscale:5.0f} m here")
    print("  (the 10' average shaves these; queue 103 reports the averaged cells)\n")

    mult = hscale / dscale
    print(f"SLOPES: a slope on Earth reads x{mult:.0f} here (heights x{hscale} over distances x{dscale:.3f})")
    print("  Earth    here     walkable?   pace (Tobler, share of flat)")
    for deg in (0.5, 1, 2, 3, 5, 8, 10, 15, 20):
        s_earth = math.tan(math.radians(deg))
        s_here = s_earth * mult
        here_deg = math.degrees(math.atan(s_here))
        walkable = "yes" if here_deg <= ws["mountains"]["walk_max_deg"] else "no (>%g deg)" % ws["mountains"]["walk_max_deg"]
        route = " route-grade" if here_deg <= ws["mountains"]["route_max_deg"] else ""
        print(f"  {deg:5.1f}  {here_deg:6.1f}    {walkable:<12} {tobler(s_here, a, b):5.2f}{route}")
    print(f"  routes need <= {ws['mountains']['route_max_deg']} deg here = {math.degrees(math.atan(math.tan(math.radians(ws['mountains']['route_max_deg'])) / mult)):.1f} deg on Earth\n")

    print("MAP BUDGETS (equirectangular, 2 bytes a sample)")
    print("  grid        samples      bytes    Earth km/sample   here m/sample   vs chunk %.0f m   vs blueprint cell" % CHUNK_M)
    cell_here = circ / (4 * BLUEPRINT_CELLS_PER_FACE)
    for label, deg in (("60\"", 1 / 60), ("5'", 5 / 60), ("10'", 10 / 60), ("15'", 15 / 60), ("0.1 deg", 0.1), ("0.25 deg", 0.25), ("0.5 deg", 0.5)):
        w = round(360 / deg)
        h = round(180 / deg)
        km = EARTH_CIRC_M / 1000 / w
        here = km * 1000 * dscale
        print(f"  {label:<10} {w * h:>12,} {w * h * 2:>10,}   {km:9.1f}         {here:8.0f}        {here / CHUNK_M:5.2f}x          {here / cell_here:5.2f}x")
    print(f"  (blueprint cell here {cell_here:.0f} m; islands narrower than one sample vanish)\n")

    r = circ / (2 * math.pi)
    print("HORIZON (§CR.7, unchanged by the real map)")
    print(f"  from eye height {EYE_M} m: {math.sqrt(2 * r * EYE_M + EYE_M ** 2):.0f} m here, {math.sqrt(2 * EARTH_RADIUS_M * EYE_M + EYE_M ** 2) / 1000:.1f} km on Earth")
    for hm in (30, 100, 885):
        print(f"  a {hm} m thing shows from {math.sqrt(2 * r * hm + hm ** 2) + math.sqrt(2 * r * EYE_M + EYE_M ** 2):,.0f} m")


if __name__ == "__main__":
    main()
