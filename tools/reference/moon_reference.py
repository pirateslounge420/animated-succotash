#!/usr/bin/env python3
"""The moon's nights: how often the brightest come round, and what the first nights are.

Design: docs/design/RECONCILIATION_2026-09-30.md §DD (the moon sets how dark the night is;
the year joins the day count) and §DG (the werewolf only on the brightest nights), 3 Oct 2026.
Data it reads: data/sky/day_cycle.json (moon_cycle_days, day_length_min, year_days,
full_moon_illumination), scripts/core/world.gd (START_DAYS; §CY.1 then takes the clock to
dawn at the spawn, a few hours on), data/camps.json (wake_found.lost_days).

Run: python3 tools/reference/moon_reference.py
The numbers quoted in §DD and §DG come from here.

Conventions (match scripts/sky/astro.gd):
  - The moon's age is days mod the cycle; elongation = 2*pi*age/cycle; the lit share
    of the disc is (1 - cos(elongation)) / 2 (0 new, 1 full).
  - A night is counted by the lit share at its midnight at longitude 0 (world.days a
    whole number). Elsewhere the local midnight is up to half a day either side, which
    moves the lit share by at most about 0.03 near full.
"""
import json
import math
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def start_days():
    with open(os.path.join(ROOT, "scripts/core/world.gd"), encoding="utf-8") as f:
        m = re.search(r"const START_DAYS\s*:=\s*([0-9.]+)", f.read())
    return float(m.group(1)) if m else 13.62


def lit(days, cycle):
    e = 2.0 * math.pi * ((days % cycle) / cycle)
    return (1.0 - math.cos(e)) / 2.0


def days_at_or_above(threshold, cycle):
    """Length (game days) of the stretch round full where the lit share >= threshold."""
    half = math.pi - math.acos(1.0 - 2.0 * threshold)
    return cycle * (2.0 * half) / (2.0 * math.pi)


def main():
    sky = load("data/sky/day_cycle.json")
    cycle = float(sky.get("moon_cycle_days", 29.5))
    day_min = float(sky.get("day_length_min", 144.0))
    year = float(sky.get("year_days", 365.0))
    full_at = float(sky.get("full_moon_illumination", 0.97))
    day_h = day_min / 60.0
    camps = load("data/camps.json")
    lost = camps.get("wake_found", {}).get("lost_days", [1.0, 3.0])

    print(f"A game day is {day_min:g} real minutes ({day_h:g} h). The moon's month is {cycle:g} game days:")
    print(f"   {cycle * day_h:.1f} hours of play from one full moon to the next.")
    print(f"A year is {year:g} game days: {year * day_h:.0f} hours of play "
          f"({year * day_h / 24:.1f} days played round the clock), so Year 2 is a long way off.\n")

    print("1. How long 'full' lasts, by where the line is drawn")
    print("   lit share >=   game days per month   hours of play   share of all nights")
    for t in (0.85, 0.90, 0.95, full_at, 0.99):
        d = days_at_or_above(t, cycle)
        mark = "  <- §DG (day_cycle.json full_moon_illumination)" if abs(t - full_at) < 1e-9 else ""
        mark = "  <- the code's gate today (creature_species.gd)" if abs(t - 0.85) < 1e-9 else mark
        print(f"   {t:5.2f}          {d:5.2f}                 {d * day_h:5.1f}            {d / cycle * 100:4.1f} %{mark}")

    print("\n2. The first nights of a new world (lit share at each midnight; W = a werewolf night)")
    print("   (World.START_DAYS sets the calendar; §CY.1 then moves the hour to dawn at the spawn, which")
    print("   doesn't change which nights these are)")
    for label, s in (("as built (World.START_DAYS)", start_days()), ("two days earlier", start_days() - 2.0)):
        nights = []
        first_mid = math.floor(s) + 1.0
        for n in range(6):
            f = lit(first_mid + n, cycle)
            nights.append(f"{f:.3f}{' W' if f >= full_at else '  '}")
        print(f"   {label:28s} start {s:5.2f}: " + "  ".join(nights))

    print("\n3. What waking costs the moon (design §DE: one to three days pass)")
    for d in lost:
        print(f"   {float(d):.0f} day(s): the moon moves {float(d) / cycle * 100:4.1f} % of its month")

    print("\n4. For comparison only: a shorter month would break the 1/10 time rule for the moon")
    for m in (7.375, 14.75):
        print(f"   a {m:g}-day month: a full moon every {m * day_h:.1f} hours of play, "
              f"'full' for {days_at_or_above(full_at, m) * day_h:.1f} of them")


if __name__ == "__main__":
    main()
