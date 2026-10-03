#!/usr/bin/env python3
"""World scale reference (design 3 Oct §CR): the numbers behind the move to 1/100 Earth.

Prints, for the 1/100 planet (400 km around) beside the 1/10 planet (4,000 km) and Earth:
- how far the horizon is from eye height and from a height, and how far a tall thing shows;
- how much the ground drops away over a distance (the curve);
- the uphill pace factor (Tobler's hiking function, scaled to the flat walk) by slope;
- the time to climb a summit by a route of a given grade, in real minutes and game hours;
- the time to cross open flat ground.

The engine's own check should agree with these numbers (WORKING_AGREEMENT: verification is
cross-agent). Plain Python 3, no packages.

  python3 tools/reference/world_scale_reference.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WS = os.path.join(ROOT, "data", "world_scale.json")

EARTH_CIRC_M = 40_075_000.0
EYE_M = 1.6
GAME_H_PER_REAL_H = 10.0  # the 144-minute day


def radius(circ_m):
    return circ_m / (2 * math.pi)


def horizon_m(r, h):
    """Distance to the horizon from height h above a sphere of radius r (no refraction)."""
    return math.sqrt(2 * r * h + h * h)


def drop_m(r, d):
    """How far the ground falls below a level line after distance d."""
    return r - math.sqrt(max(r * r - d * d, 0.0))


def tobler_factor(slope_rise_over_run, a=3.5, b=0.05, cap=1.0):
    """Tobler's hiking function, normalised so flat ground is 1.0, capped at `cap`."""
    f = math.exp(-a * abs(slope_rise_over_run + b)) / math.exp(-a * b)
    return min(f, cap)


def climb(height_m, grade_deg, v_flat, pace):
    s = math.tan(math.radians(grade_deg))
    path = height_m / math.sin(math.radians(grade_deg))
    v = v_flat * tobler_factor(s, pace["a"], pace["b"], pace["max_factor"])
    secs = path / v
    return path, v, secs / 60.0, secs / 3600.0 * GAME_H_PER_REAL_H


def main():
    ws = json.load(open(WS, encoding="utf-8"))
    pace = ws["pace"]["tobler"]
    v_flat = float(ws["pace"]["flat_walk_mps"])
    circ_100 = float(ws["planet"]["circumference_m"])
    planets = [("1/100 (design §CR)", circ_100), ("1/10 (built now)", 4_000_000.0), ("Earth", EARTH_CIRC_M)]

    print("Horizon from eye height (1.6 m), and how far a thing of height H shows above it:")
    print(f"  {'planet':20} {'radius':>9} {'eye':>8} {'30 m':>8} {'100 m':>8} {'885 m':>8}   from an 885 m summit")
    for name, c in planets:
        r = radius(c)
        cells = [horizon_m(r, EYE_M)] + [horizon_m(r, EYE_M) + horizon_m(r, h) for h in (30, 100, 885)]
        print(f"  {name:20} {r / 1000:8.1f}k " + " ".join(f"{x / 1000:7.2f}k" for x in cells)
              + f"   {horizon_m(r, 885) / 1000:6.1f} km")

    print("\nHow far the ground drops away from a level line:")
    for name, c in planets[:2]:
        r = radius(c)
        print(f"  {name:20} " + "  ".join(f"{d} km: {drop_m(r, d * 1000):6.1f} m" for d in (1, 2, 5, 10)))

    print(f"\nUphill pace (Tobler, a={pace['a']}, b={pace['b']}, cap {pace['max_factor']}), at a flat walk of {v_flat} m/s:")
    for deg in (0, 5, 10, 15, 20, 25, 30, 35, 45):
        f = tobler_factor(math.tan(math.radians(deg)), pace["a"], pace["b"], pace["max_factor"])
        print(f"  {deg:2d}° up: {f * 100:5.1f}% of flat, {v_flat * f:4.2f} m/s")

    print("\nClimbing a summit by a route of a given grade (heights at 1/10, as now):")
    for h in (200, 500, 885):
        for g in (15, 20, 25):
            path, v, mins, gh = climb(h, g, v_flat, pace)
            print(f"  {h:4d} m by {g}°: route {path / 1000:4.2f} km at {v:4.2f} m/s = {mins:5.1f} real min = {gh:4.1f} game h")

    print("\nOpen flat ground at the flat walk:")
    for km in (1, 5, 10, 50, 200, circ_100 / 1000):
        mins = km * 1000 / v_flat / 60
        print(f"  {km:6.0f} km: {mins:6.1f} real min = {mins / 60 * GAME_H_PER_REAL_H:6.1f} game h")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
