#!/usr/bin/env python3
"""A hearth's smoke column seen from far: the horizon, the pixel floor, the haze, the wind.

Design: docs/design/RECONCILIATION_2026-09-30.md §CV (smoke from every hearth, locked 3 Oct
afternoon: the column, its lean and how far it is drawn) and §DA (the wind you can see, the
voice session of 3 Oct: what the gusts and the shelter under the crowns do to it). It gives
Claude Code the numbers behind smoke.json far.seen_to_m and far.min_px.
Data it reads: data/world_scale.json (planet.circumference_m), data/smoke.json (hearth.by_state,
hearth.wind, hearth.far), data/look.json (retro.fov_deg, render.internal_lines,
retro.fog.day_density, retro.fog.start_m).

Run: python3 tools/reference/beacon_reference.py
The numbers quoted in §DA come from here.

Conventions:
  - The planet is 1/100 Earth (§CR): 400 km around, radius about 63.7 km, read from the data.
  - Eye height 1.6 m, as tools/reference/world_scale_reference.py uses (§CR's 451 m horizon).
  - No atmospheric refraction (it would add about 7 % to every sighting distance).
  - A pixel is the angle one row of the internal frame covers at the screen's centre:
    2 * tan(fov / 2) / lines (Godot's fov is vertical).
  - A real plume's edge spreads at about 0.12 of the height risen (Morton, Taylor & Turner
    1956), so a column is about a quarter as wide as it is tall; smoke.json gives its own base
    width, and the wider of the two is used.
"""
import json
import math
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
EYE_M = 1.6
PLUME_WIDTH_PER_M = 0.24


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def horizon_m(r, h):
    """Distance to the horizon from height h above a smooth sphere of radius r."""
    return math.sqrt(2.0 * r * h + h * h)


def main():
    scale = load("data/world_scale.json")
    circ = float(scale["planet"]["circumference_m"])
    r = circ / (2.0 * math.pi)
    look = load("data/look.json")
    retro = look["retro"]
    fov = float(retro.get("fov_deg", 78.0))
    lines = int(look["render"].get("internal_lines", 480))
    fog = retro["fog"]
    day_density = float(fog.get("day_density", 0.0032))
    fog_start = float(fog.get("start_m", 200.0))
    px = 2.0 * math.tan(math.radians(fov) / 2.0) / lines

    smoke = load("data/smoke.json")["hearth"]
    states = smoke["by_state"]
    wind = smoke["wind"]
    far = smoke["far"]
    seen_to = float(far["seen_to_m"])
    min_px = float(far["min_px"])

    print(f"Planet {circ / 1000:.0f} km around, radius {r / 1000:.1f} km; eye {EYE_M} m; fov {fov:g} deg; {lines} lines")
    print(f"One pixel at screen centre: {px * 1000:.2f} mrad; smoke.json far.min_px {min_px:g} px = {min_px * px * 1000:.2f} mrad\n")

    print("1. The horizon (level ground or sea, no refraction)")
    for h in (EYE_M, 20.0, 50.0, 100.0):
        print(f"   from {h:6.1f} m up: {horizon_m(r, h):6.0f} m")

    print("\n2. How far a column's top shows above the horizon (m), by the fire's state (smoke.json)")
    cols = [(name, float(states[name]["top_m"])) for name in ("flames", "low", "embers") if float(states[name]["top_m"]) > 0]
    print("   seen from     " + "".join(f"{name + ' ' + str(int(top)) + ' m':>16}" for name, top in cols))
    for h in (EYE_M, 20.0, 50.0, 100.0):
        row = "".join(f"{horizon_m(r, h) + horizon_m(r, top):16.0f}" for _, top in cols)
        print(f"   {h:6.1f} m   {row}")
    print(f"   (smoke.json draws a column out to far.seen_to_m = {seen_to:.0f} m)")

    print("\n3. The column's width on screen, and where it drops under the pixel floor")
    for name, top in cols:
        base = float(states[name]["width_m"])
        w = max(PLUME_WIDTH_PER_M * top, base)
        d_floor = w / (min_px * px)
        d_one = w / px
        print(f"   {name:7s} top {int(top):3d} m: about {w:4.1f} m wide at the top; under {min_px:g} px past {d_floor / 1000:4.2f} km, "
              f"under 1 px past {d_one / 1000:4.2f} km")

    print("\n4. The day haze (look.json retro.fog, at the default render distance)")
    for d in (500, 1000, 2000, seen_to):
        left = math.exp(-day_density * max(d - fog_start, 0.0))
        print(f"   {d / 1000:4.1f} km: {left * 100:5.1f} % of the contrast left")

    print("\n5. The column in the wind (smoke.json hearth.wind; the land signs are wind.json beaufort)")
    lean_per = float(wind["lean_deg_per_mps"])
    lean_max = float(wind["max_lean_deg"])
    calm = float(wind["calm_below_mps"])
    top_full = float(states["flames"]["top_m"])
    print("   wind m/s   lean from upright   top above the fire m (flames)")
    for u in (0.0, 0.5, 1.0, 2.0, 3.4, 5.5, 8.0):
        lean = 0.0 if u < calm else min(lean_per * u, lean_max)
        print(f"   {u:6.1f}     {lean:6.0f} deg           {top_full * math.cos(math.radians(lean)):6.0f}")

    print("\nRead (§DA): on this planet the horizon is a few hundred metres on flat ground, so a column")
    print("is seen from a rise or across a valley; past about 1 km the haze has taken its contrast and it")
    print("reads as a pale mark against the darker sky (look R5); past about 2 km a full column is under")
    print("two pixels, so smoke.json's min_px carries it to seen_to_m. Under the crowns it rises straight")
    print("and takes the wind only above them (wind.json smoke.shelter_under_crowns).")


if __name__ == "__main__":
    main()
