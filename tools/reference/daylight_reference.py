#!/usr/bin/env python3
"""Reference implementation for the derived day/night cycle with axial tilt.

Design: docs/design/RECONCILIATION_2026-09-27.md, addendum §F (seasons, derived
day/night) and §F2 (how the 18-minute twilights survive real geometry).

Claude Code: astro.gd / day_cycle.gd should reproduce the numbers in
tools/reference/daylight_table.csv (regenerate with `python3 daylight_reference.py`).
Tolerance: 0.05 game hours on any duration, 0.5 degrees on declination.

Conventions (match the repo):
  - Time is in game days as a float; the fraction is time of day at longitude 0.
  - A game day is 144 real minutes, so 1 game hour = 6 real minutes exactly.
  - Year = 365 game days.  Day 0 of the year is the NORTHERN SPRING EQUINOX.
    Northern seasons: spring [0, 91.25), summer [91.25, 182.5),
    autumn [182.5, 273.75), winter [273.75, 365).  Southern are shifted by half.
  - Axial tilt 23.44 degrees.  Declination d(t) = tilt * sin(2*pi*t/365).
  - Sunrise/sunset use PlanetConst.SUNRISE_ELEVATION_DEG (-3.6): the sun "rises"
    when its centre crosses that elevation (the game's convention, not 0).
  - Twilight band: DayCycle.twilight_deg (10): from sunrise elevation down to
    sunrise_elev - twilight_deg.

Two layers, both reported:
  GEOMETRIC  - what the sky actually does: sunrise/sunset hour angles, daylight
               hours, natural twilight length, polar night / midnight sun.
  STYLISED   - the durations the clock actually runs, after the day_cycle warp
               (design §F2): each twilight is stretched to at least
               TWILIGHT_MIN_REAL_MIN (18 real min = 3 game h, the equator/equinox
               reference) and never shortened below its natural length; the
               remaining time is split between day and night in the geometric
               ratio biased by DAY_BIAS (1.25 = 60:48), so the equator at an
               equinox lands exactly on 60/18/48/18 real minutes.
"""
import csv
import math
import os

TILT_DEG = 23.44
YEAR_DAYS = 365.0
DAY_REAL_MIN = 144.0
GAME_H_PER_REAL_MIN = 24.0 / DAY_REAL_MIN  # 1/6
SUNRISE_ELEV_DEG = -3.6          # PlanetConst.SUNRISE_ELEVATION_DEG
TWILIGHT_DEG = 10.0              # DayCycle.twilight_deg
TWILIGHT_MIN_REAL_MIN = 18.0     # design §F: the equator/equinox reference dusk/dawn
REF_DAY_REAL_MIN = 60.0          # design §F: the equator/equinox reference is 60/18/48/18
REF_NIGHT_REAL_MIN = 48.0
SEASON_DAYS = YEAR_DAYS / 4.0
TRANSITION_DAYS = 20.0           # design §F: ~20 game days straddling each boundary
NORTH_SEASONS = ["spring", "summer", "autumn", "winter"]


def declination_deg(day_of_year: float) -> float:
    return TILT_DEG * math.sin(2.0 * math.pi * day_of_year / YEAR_DAYS)


def hour_angle_deg(lat_deg: float, dec_deg: float, elev_deg: float):
    """Hour angle (degrees, 0..180) at which the sun's centre is at elev_deg.
    Returns None when the sun never reaches that elevation this day (above: 'up'
    all day / below: 'down' all day, distinguished by the caller)."""
    lat, dec, el = map(math.radians, (lat_deg, dec_deg, elev_deg))
    c = (math.sin(el) - math.sin(lat) * math.sin(dec)) / (math.cos(lat) * math.cos(dec))
    if c > 1.0 or c < -1.0:
        return None
    return math.degrees(math.acos(c))


def geometric(lat_deg: float, day_of_year: float) -> dict:
    dec = declination_deg(day_of_year)
    h_rise = hour_angle_deg(lat_deg, dec, SUNRISE_ELEV_DEG)
    h_twi = hour_angle_deg(lat_deg, dec, SUNRISE_ELEV_DEG - TWILIGHT_DEG)
    # Noon elevation tells us which side of a 'never' case we are on.
    noon_elev = 90.0 - abs(lat_deg - dec)
    midnight_elev = -90.0 + abs(lat_deg + dec)
    if h_rise is None:
        if noon_elev >= SUNRISE_ELEV_DEG:
            daylight_h, state = 24.0, "midnight_sun"
        else:
            daylight_h, state = 0.0, "polar_night"
    else:
        daylight_h, state = 2.0 * h_rise / 15.0, "normal"
    # Natural twilight: time between the sunrise elevation and the bottom of the band.
    if state == "midnight_sun":
        twilight_h = 0.0
    elif state == "polar_night":
        # Sun below the rise line all day: is it ever inside the band?
        if midnight_elev <= SUNRISE_ELEV_DEG - TWILIGHT_DEG and noon_elev <= SUNRISE_ELEV_DEG - TWILIGHT_DEG:
            twilight_h = 0.0  # deep polar night: never in the band
        elif h_twi is None:
            twilight_h = 12.0  # in the band all day: all twilight, split as two 12 h halves
        else:
            twilight_h = (24.0 - 2.0 * h_twi / 15.0) / 2.0
    else:
        if h_twi is None:
            # Sun sets but never drops out of the band: the whole night is twilight.
            twilight_h = (24.0 - daylight_h) / 2.0
        else:
            twilight_h = (h_twi - h_rise) / 15.0
    night_h = max(0.0, 24.0 - daylight_h - 2.0 * twilight_h)
    sunrise_local = None if h_rise is None else 12.0 - h_rise / 15.0
    sunset_local = None if h_rise is None else 12.0 + h_rise / 15.0
    return dict(declination_deg=dec, state=state, daylight_h=daylight_h,
                twilight_each_h=twilight_h, night_h=night_h,
                sunrise_local_h=sunrise_local, sunset_local_h=sunset_local,
                noon_elev_deg=noon_elev)


_DAY_BIAS = None


def day_bias() -> float:
    """The day:night bias that makes the equator at the spring equinox land exactly
    on the 60/48 reference, given the game's sunrise elevation. Solved once from the
    geometry, so a change to SUNRISE_ELEV_DEG re-calibrates it."""
    global _DAY_BIAS
    if _DAY_BIAS is None:
        g = geometric(0.0, 0.0)
        w = REF_DAY_REAL_MIN / (REF_DAY_REAL_MIN + REF_NIGHT_REAL_MIN)
        _DAY_BIAS = (w * g["night_h"]) / ((1.0 - w) * g["daylight_h"])
    return _DAY_BIAS


def stylised(geo: dict) -> dict:
    """The clock the game runs (design §F2): twilights stretched to the reference
    minimum, day/night split in the geometric ratio biased so the equator equinox
    is exactly 60/18/48/18."""
    twi_nat_real = geo["twilight_each_h"] / GAME_H_PER_REAL_MIN
    if geo["state"] == "normal":
        # The 18-minute floor is for days that have a sunrise and a sunset.
        twi_real = max(TWILIGHT_MIN_REAL_MIN, twi_nat_real)
    else:
        # Midnight sun: no dusk, no dawn. Polar night: only the natural twilight
        # (none in deep polar night; a long glow when the sun skims the band).
        twi_real = twi_nat_real
    twi_real = min(twi_real, DAY_REAL_MIN / 2.0)  # two twilights can't exceed the day
    rest = DAY_REAL_MIN - 2.0 * twi_real
    d, n = geo["daylight_h"], geo["night_h"]
    if d + n <= 1e-9:
        w = 0.5
    else:
        w = (day_bias() * d) / (day_bias() * d + n)
    day_real = rest * w
    night_real = rest - day_real
    return dict(day_real_min=day_real, dusk_real_min=twi_real,
                night_real_min=night_real, dawn_real_min=twi_real,
                day_game_h=day_real * GAME_H_PER_REAL_MIN,
                night_game_h=night_real * GAME_H_PER_REAL_MIN)


def season(day_of_year: float, lat_deg: float) -> dict:
    t = day_of_year % YEAR_DAYS
    idx = int(t // SEASON_DAYS) % 4
    north = NORTH_SEASONS[idx]
    south = NORTH_SEASONS[(idx + 2) % 4]
    into = t - idx * SEASON_DAYS
    # Transition: the TRANSITION_DAYS window straddling each boundary.
    half = TRANSITION_DAYS / 2.0
    in_transition = into < half or into > SEASON_DAYS - half
    name = north if lat_deg >= 0 else south
    # Blend factor 0..1 across a transition (0 = previous season, 1 = this one).
    if into < half:
        blend = 0.5 + into / TRANSITION_DAYS
    elif into > SEASON_DAYS - half:
        blend = (into - (SEASON_DAYS - half)) / TRANSITION_DAYS
    else:
        blend = 1.0
    return dict(season=name, season_north=north, season_south=south,
                in_transition=in_transition, transition_blend=blend)


def photoperiod_trigger(daylight_h: float, mode: str, threshold_h: float) -> bool:
    """docs/design/PLANT_SCHEMA.md §4."""
    if mode == "short_day":
        return daylight_h < threshold_h
    if mode == "long_day":
        return daylight_h > threshold_h
    return False


LATITUDES = [0, 23.5, -23.5, 35, -35, 50, -50, 66.5, -66.5, 80, -80]
DAYS = [0, 30, 61, 91.25, 121, 152, 182.5, 213, 243, 273.75, 304, 334]


def write_table(path: str) -> None:
    fields = ["lat_deg", "day_of_year", "declination_deg", "state", "season", "in_transition",
              "daylight_h", "twilight_each_h", "night_h", "sunrise_local_h", "sunset_local_h",
              "noon_elev_deg", "day_real_min", "dusk_real_min", "night_real_min", "dawn_real_min",
              "cannabis_short_day_13h_flowers"]
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(fields)
        for lat in LATITUDES:
            for d in DAYS:
                g = geometric(lat, d)
                s = stylised(g)
                se = season(d, lat)
                w.writerow([lat, d, round(g["declination_deg"], 2), g["state"], se["season"],
                            int(se["in_transition"]), round(g["daylight_h"], 3),
                            round(g["twilight_each_h"], 3), round(g["night_h"], 3),
                            "" if g["sunrise_local_h"] is None else round(g["sunrise_local_h"], 3),
                            "" if g["sunset_local_h"] is None else round(g["sunset_local_h"], 3),
                            round(g["noon_elev_deg"], 2), round(s["day_real_min"], 2),
                            round(s["dusk_real_min"], 2), round(s["night_real_min"], 2),
                            round(s["dawn_real_min"], 2),
                            int(photoperiod_trigger(g["daylight_h"], "short_day", 13.0))])


def self_check() -> None:
    g = geometric(0.0, 0.0)
    s = stylised(g)
    # Equator at the equinox: the 60/18/48/18 reference (sunrise at -3.6 deg makes the
    # geometric day a touch over 12 h, which the bias is calibrated against below).
    assert abs(s["dusk_real_min"] - 18.0) < 1e-9, s
    assert abs(s["day_real_min"] - 60.0) < 1e-6 and abs(s["night_real_min"] - 48.0) < 1e-6, s
    assert abs(s["day_real_min"] + s["night_real_min"] + 36.0 - 144.0) < 1e-9
    print("day bias (calibrated) = %.4f" % day_bias())
    # Polar night and midnight sun exist.
    assert geometric(80.0, 273.75)["state"] == "polar_night"
    assert geometric(80.0, 91.25)["state"] == "midnight_sun"
    # Southern hemisphere is the mirror.
    assert abs(geometric(50.0, 91.25)["daylight_h"] - geometric(-50.0, 273.75)["daylight_h"]) < 1e-6
    ms = stylised(geometric(80.0, 91.25))
    assert ms["dusk_real_min"] == 0.0 and abs(ms["day_real_min"] - 144.0) < 1e-6, ms
    print("self-check ok")
    print("equator equinox (real min): day %.1f dusk %.1f night %.1f dawn %.1f" % (
        s["day_real_min"], s["dusk_real_min"], s["night_real_min"], s["dawn_real_min"]))
    for lat in (35.0, 50.0, 66.5):
        for d, name in ((91.25, "summer solstice"), (273.75, "winter solstice")):
            g = geometric(lat, d); s = stylised(g)
            print("lat %5.1f %-16s daylight %5.2f h  twilight %4.2f h each  -> real min day %5.1f / dusk %4.1f / night %5.1f / dawn %4.1f  [%s]" % (
                lat, name, g["daylight_h"], g["twilight_each_h"], s["day_real_min"],
                s["dusk_real_min"], s["night_real_min"], s["dawn_real_min"], g["state"]))


if __name__ == "__main__":
    self_check()
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "daylight_table.csv")
    write_table(out)
    print("wrote", out)
