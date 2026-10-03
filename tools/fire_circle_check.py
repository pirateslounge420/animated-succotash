#!/usr/bin/env python3
"""Fire circle check (design 3 Oct §CY, §CZ): the gate for the dawn start, the fire circle
and the fire's coals and specks.

You wake at dawn in a ring of folk sitting round the fire, and the road reaches the next
hearth before dusk (§CY). The fire they sit round breathes: a bed of coals that pulses, and
specks thrown up at random (§CZ). This script checks the data that says so and prints the
opening day's timetable:

  python3 tools/fire_circle_check.py            # check and report
  python3 tools/fire_circle_check.py --strict   # warnings count as errors

What it checks
- roads.json opening_road.dawn_start: spawn.phase is dawn; the walk speed is the ambient
  walk (movement.json profiles.ambient.speed.walk_mps); length_km_hint is the walk on flat
  ground (walk_real_min x 60 x walk_speed_mps, within 3 %); the road is measured in
  walking minutes (the slope pace is built); first_landmark matches §BX's.
- the day fits (sky/day_cycle.json, the reference day): a straight walk arrives at least
  slack_before_dusk_min before dusk begins, and a walk that takes twice as long still
  arrives before full dark.
- the day fits everywhere (tools/reference/daylight_reference.py, the game's own clock):
  on the world's first day (World.START_DAYS in scripts/core/world.gd), at every latitude
  from 66 S to 66 N, the same two tests. A latitude where the road would have to be
  shortened is a warning, with the length it would get.
- camps.json sim.fire_circle.seats: every biome in data/biomes has a seat list; a biome
  with a people (peoples/biome_map.json by_biome) has at least one seat and a biome with
  none has an empty list; every seat named is a kind; a wood seat (log, stump, root)
  needs wood in that biome and a driftwood seat needs driftwood (fuel.json biomes), so
  nobody sits on a log on a treeless steppe; at_site and by_people name kinds, and
  by_people names people files.
- sim.fire_circle.idles: every idle says what it is and who does it (anyone / adult);
  props are a list; a weighted idle has a weight for dawn, day, dusk and night and a
  hold_s range; a job idle names a job in sim.jobs.kinds; the pipe is adults only, has
  its steps in order (pack, light_from_fire, puff, tap_out), smoke that doesn't glow and
  takes the hearth smoke's look (smoke.json hearth.look, §CV), and an ember that casts no
  light; at least one idle can be picked in every phase.
- notice matches travellers.json head_look where they share a key (hood_only,
  head_max_deg, rate), so folk and travellers turn their hoods the same way.
- dawn_break and dusk_form fit inside the hours outside loop.gather_hours.
- look.json fire (§CZ): the one flame card stays (flame.cards 1); coals take their colours
  from the flame's bands, breathe and pulse by shares between 0 and 1, and have an
  at_embers block; light.breath follows the coals; specks run on a random clock, their
  spark and ash shares add up to 1, ash doesn't glow and is a blue-grey, never a neutral
  grey (LOOK_REFERENCE R3), every range is [low, high], and on_pop has pops to follow
  (audio.json fire.pops).

Plain Python 3, no packages. Exit code 1 on any error.
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
sys.path.insert(0, os.path.join(ROOT, "tools", "reference"))

WOOD_SEATS = {"log", "stump", "root", "limb"}
WOOD_FUELS = {"hardwood_log", "softwood_log", "branch", "palm_frond", "bamboo"}
PHASES = ("dawn", "day", "dusk", "night")
PIPE_STEPS = ["pack", "light_from_fire", "puff", "tap_out"]


def load(*parts):
    with open(os.path.join(DATA, *parts), encoding="utf-8") as f:
        return json.load(f)


def start_day_of_year(year_days):
    """World.START_DAYS (scripts/core/world.gd): the clock a fresh world starts at."""
    with open(os.path.join(ROOT, "scripts", "core", "world.gd"), encoding="utf-8") as f:
        m = re.search(r"const\s+START_DAYS\s*:=\s*([0-9.]+)", f.read())
    if not m:
        return None
    return float(m.group(1)) % year_days


def is_range(v):
    return isinstance(v, list) and len(v) == 2 and all(isinstance(x, (int, float)) for x in v) and v[0] <= v[1]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--strict", action="store_true", help="warnings count as errors")
    args = ap.parse_args()
    errs, warns = [], []

    roads = load("roads.json")
    camps = load("camps.json")
    cycle = load("sky", "day_cycle.json")
    move = load("movement.json")
    fuel = load("fuel.json")
    bmap = load("peoples", "biome_map.json")
    trav = load("travellers.json")

    # ------------------------------------------------------------ the dawn start
    orr = roads.get("opening_road", {})
    ds = orr.get("dawn_start")
    if not isinstance(ds, dict):
        print("ERROR: roads.json has no opening_road.dawn_start (design §CY)")
        return 1
    spawn = ds.get("spawn", {})
    if spawn.get("phase") != "dawn":
        errs.append("dawn_start.spawn.phase must be 'dawn' (§CY)")
    after = spawn.get("real_min_after_dawn_begins")
    if not isinstance(after, (int, float)) or after < 0:
        errs.append("dawn_start.spawn.real_min_after_dawn_begins must be a number, 0 or more")
        after = 0.0
    walk = ds.get("walk_real_min")
    speed = ds.get("walk_speed_mps")
    slack = ds.get("slack_before_dusk_min")
    for name, v in (("walk_real_min", walk), ("walk_speed_mps", speed), ("slack_before_dusk_min", slack)):
        if not isinstance(v, (int, float)) or v <= 0:
            errs.append(f"dawn_start.{name} must be a number above 0")
    if errs:
        for e in errs:
            print("ERROR:", e)
        return 1
    ambient = move.get("profiles", {}).get("ambient", {}).get("speed", {}).get("walk_mps")
    if ambient != speed:
        errs.append(f"dawn_start.walk_speed_mps {speed} is not the ambient walk ({ambient}, movement.json)")
    flat_km = walk * 60.0 * speed / 1000.0
    hint = ds.get("length_km_hint")
    if not isinstance(hint, (int, float)) or abs(hint - flat_km) / flat_km > 0.03:
        errs.append(f"dawn_start.length_km_hint {hint} is not the walk on flat ground ({flat_km:.2f} km)")
    if ds.get("measure") != "walking_minutes":
        errs.append("dawn_start.measure must be 'walking_minutes' (the slope pace is built, §CR.5)")
    pace = ds.get("pace_share_typical")
    if not isinstance(pace, (int, float)) or not 0 < pace <= 1:
        errs.append("dawn_start.pace_share_typical must be a share above 0 and at most 1")
        pace = 1.0
    if ds.get("first_landmark") != orr.get("first_landmark"):
        errs.append("dawn_start.first_landmark differs from opening_road.first_landmark (§BX stands)")
    if after > cycle["phase_min"]["dawn"]:
        errs.append("dawn_start.spawn.real_min_after_dawn_begins is longer than dawn itself")

    def fit(dawn_min, day_min, dusk_min):
        """(minutes from waking to dusk, straight walk's slack, minutes a double walk has left
        before full dark, the walk the road would get under the fit rule)."""
        to_dusk = dawn_min - after + day_min
        fitted = min(walk, max(0.0, to_dusk - slack))
        return to_dusk, to_dusk - walk, to_dusk + dusk_min - 2.0 * walk, fitted

    pm = cycle["phase_min"]
    to_dusk, straight, double, fitted = fit(pm["dawn"], pm["day"], pm["dusk"])
    if straight < slack:
        errs.append(f"the reference day: a straight walk arrives {straight:.0f} min before dusk, under the slack of {slack:.0f}")
    if double < 0:
        errs.append(f"the reference day: a walk that takes twice as long arrives {-double:.0f} min after full dark")

    gh = cycle["day_length_min"] / 24.0  # real minutes in a game hour
    arrive_h = None
    rows = []
    try:
        import daylight_reference as dl
        doy = start_day_of_year(cycle.get("year_days", 365))
        if doy is None:
            warns.append("World.START_DAYS not found in scripts/core/world.gd: the latitude test ran at the spring equinox")
            doy = 0.0
        worst = None
        for lat in range(-66, 67, 2):
            st = dl.stylised(dl.geometric(float(lat), doy))
            t, s, d, f = fit(st["dawn_real_min"], st["day_real_min"], st["dusk_real_min"])
            rows.append((lat, t, s, d, f))
            if worst is None or t < worst[1]:
                worst = (lat, t, s, d, f)
            if f < walk - 1e-6:
                warns.append(f"at {lat:+d} deg on the world's first day the road is shortened to {f:.0f} min ({t:.0f} min from waking to dusk)")
            if d < 0:
                errs.append(f"at {lat:+d} deg on the world's first day a double-length walk arrives {-d:.0f} min after full dark")
    except ImportError:
        warns.append("tools/reference/daylight_reference.py not importable: the latitude test did not run")
        worst, doy = None, None

    # the reference timetable, on the game clock (dawn begins at 04:00 at the reference)
    dawn_begin_h = 12.0 - (pm["day"] / gh) / 2.0 - pm["dawn"] / gh
    wake_h = dawn_begin_h + after / gh
    arrive_h = wake_h + walk / gh
    dusk_begin_h = 12.0 + (pm["day"] / gh) / 2.0
    dark_h = dusk_begin_h + pm["dusk"] / gh

    # ------------------------------------------------------------ the seats
    sim = camps.get("sim", {})
    fc = sim.get("fire_circle")
    if not isinstance(fc, dict):
        errs.append("camps.json has no sim.fire_circle (design §CY)")
        fc = {}
    seats = fc.get("seats", {})
    kinds = seats.get("kinds", {})
    for kid, k in kinds.items():
        if not isinstance(k.get("what"), str) or not k["what"]:
            errs.append(f"seats.kinds.{kid}: needs a 'what'")
        if not isinstance(k.get("height_m"), (int, float)) or not 0 < k["height_m"] <= 0.6:
            errs.append(f"seats.kinds.{kid}: height_m must be above 0 and at most 0.6 (a seat, not a table)")
        if not isinstance(k.get("seats"), int) or k["seats"] < 1:
            errs.append(f"seats.kinds.{kid}: seats must be 1 or more")
        if not isinstance(k.get("tint"), str):
            errs.append(f"seats.kinds.{kid}: needs a tint rule")
    if not is_range(seats.get("ring_m")):
        errs.append("seats.ring_m must be [near, far] in metres")
    biome_keys = []
    for f in sorted(glob.glob(os.path.join(DATA, "biomes", "*.json"))):
        with open(f, encoding="utf-8") as fh:
            key = json.load(fh).get("key")
        if key:
            biome_keys.append(key)
    by_biome = seats.get("by_biome", {})
    people_of = bmap.get("by_biome", {})
    fuel_of = fuel.get("biomes", {})
    seated_biomes = 0
    for key in biome_keys:
        if key not in by_biome:
            errs.append(f"seats.by_biome has no entry for {key}")
            continue
        lst = by_biome[key]
        if not isinstance(lst, list):
            errs.append(f"seats.by_biome.{key} must be a list")
            continue
        has_people = people_of.get(key) is not None
        if has_people and not lst:
            errs.append(f"seats.by_biome.{key} is empty, but {people_of[key]} folk camp there")
        if not has_people and lst:
            errs.append(f"seats.by_biome.{key} lists seats, but no people camps there")
        if lst:
            seated_biomes += 1
        if len(set(lst)) != len(lst):
            errs.append(f"seats.by_biome.{key} repeats a seat")
        fuels = set(fuel_of.get(key, {}))
        for s in lst:
            if s not in kinds:
                errs.append(f"seats.by_biome.{key}: '{s}' is not a seat kind")
            elif s in WOOD_SEATS and not (fuels & WOOD_FUELS):
                errs.append(f"seats.by_biome.{key}: a {s} needs wood, and fuel.json offers none there")
            elif s == "driftwood" and "driftwood" not in fuels:
                errs.append(f"seats.by_biome.{key}: driftwood seat, but fuel.json has no driftwood there")
    for key in by_biome:
        if key not in biome_keys:
            errs.append(f"seats.by_biome.{key} is not a biome in data/biomes")
    for site, lst in seats.get("at_site", {}).items():
        for s in lst:
            if s not in kinds:
                errs.append(f"seats.at_site.{site}: '{s}' is not a seat kind")
    people_files = {os.path.basename(p)[:-5] for p in glob.glob(os.path.join(DATA, "peoples", "*.json"))}
    for pid, lst in seats.get("by_people", {}).items():
        if pid not in people_files:
            errs.append(f"seats.by_people.{pid} is not a people file")
        for s in lst:
            if s not in kinds:
                errs.append(f"seats.by_people.{pid}: '{s}' is not a seat kind")
    used = {s for lst in by_biome.values() for s in lst}
    used |= {s for lst in seats.get("at_site", {}).values() for s in lst}
    used |= {s for lst in seats.get("by_people", {}).values() for s in lst}
    for kid in kinds:
        if kid not in used:
            warns.append(f"seats.kinds.{kid} is never offered anywhere")

    # ------------------------------------------------------------ the idles
    idles = fc.get("idles", {})
    jobs = sim.get("jobs", {}).get("kinds", {})
    pickable = {p: [] for p in PHASES}
    for iid, i in idles.items():
        where = f"idles.{iid}"
        if not isinstance(i.get("what"), str) or not i["what"]:
            errs.append(f"{where}: needs a 'what'")
        if i.get("who") not in ("anyone", "adult"):
            errs.append(f"{where}: who must be 'anyone' or 'adult'")
        if not isinstance(i.get("props"), list):
            errs.append(f"{where}: props must be a list")
        if "job" in i and i["job"] not in jobs:
            errs.append(f"{where}: job '{i['job']}' is not in sim.jobs.kinds")
        if "weight" in i:
            w = i["weight"]
            for p in PHASES:
                if not isinstance(w.get(p), (int, float)) or w[p] < 0:
                    errs.append(f"{where}: weight.{p} must be a number, 0 or more")
                elif w[p] > 0:
                    pickable[p].append(iid)
            if "steps" not in i and not is_range(i.get("hold_s")):
                errs.append(f"{where}: a weighted idle needs hold_s [min, max]")
        elif "needs" not in i:
            errs.append(f"{where}: needs a weight (picked) or a 'needs' (triggered)")
    for p in PHASES:
        if not pickable[p]:
            errs.append(f"no idle can be picked in the {p}")
    pipe = idles.get("pipe")
    if not isinstance(pipe, dict):
        errs.append("idles.pipe is missing (Mike: packing a pipe and smoking)")
    else:
        if pipe.get("who") != "adult":
            errs.append("idles.pipe: adults only")
        if [s.get("do") for s in pipe.get("steps", [])] != PIPE_STEPS:
            errs.append(f"idles.pipe.steps must be {PIPE_STEPS} in order (lit from the fire, never a spark: §BP)")
        if pipe.get("smoke", {}).get("glows") is not False:
            errs.append("idles.pipe.smoke.glows must be false (only things that give off light glow)")
        if pipe.get("smoke", {}).get("look_from") != "smoke.json hearth.look" or not isinstance(load("smoke.json").get("hearth", {}).get("look"), dict):
            errs.append("idles.pipe.smoke.look_from must be 'smoke.json hearth.look', and that block must exist (§CV)")
        if pipe.get("bowl_ember", {}).get("casts_light") is not False:
            errs.append("idles.pipe.bowl_ember.casts_light must be false")
        if not isinstance(pipe.get("max_at_once"), int) or pipe["max_at_once"] < 1:
            errs.append("idles.pipe.max_at_once must be 1 or more")

    # ------------------------------------------------------------ noticing, and the hours
    notice = fc.get("notice", {})
    look = trav.get("head_look", {})
    for key in ("hood_only", "head_max_deg", "rate"):
        if key in notice and key in look and notice[key] != look[key]:
            warns.append(f"notice.{key} {notice[key]} differs from travellers.json head_look.{key} {look[key]}")
    hours = sim.get("loop", {}).get("gather_hours", [7, 17])
    rest_h = 24.0 - (hours[1] - hours[0])
    db = fc.get("dawn_break", {})
    df = fc.get("dusk_form", {})
    rise = db.get("begins_game_h_before_gather")
    settle = df.get("over_game_h")
    if not isinstance(rise, (int, float)) or rise <= 0:
        errs.append("dawn_break.begins_game_h_before_gather must be a number above 0")
        rise = 0.0
    if not isinstance(settle, (int, float)) or settle <= 0:
        errs.append("dusk_form.over_game_h must be a number above 0")
        settle = 0.0
    if rise + settle > rest_h:
        errs.append(f"dawn_break and dusk_form together ({rise + settle} game h) are longer than the rest hours ({rest_h})")
    rise_begin_h = hours[0] - rise
    if rise_begin_h < wake_h - 1e-6:
        warns.append(f"the circle starts to break at {rise_begin_h:.2f} h, before you wake at {wake_h:.2f} h at the reference")
    if db.get("stays_min", 0) < 1:
        errs.append("dawn_break.stays_min must be at least 1 (someone keeps the hearth)")
    night = fc.get("night", {})
    if night.get("keeper_awake", 0) < 1:
        errs.append("night.keeper_awake must be at least 1 (the fire is fed all night, §AX)")
    if not 0 <= night.get("doze_share", -1) <= 1:
        errs.append("night.doze_share must be between 0 and 1")

    # ------------------------------------------------------------ the fire itself (§CZ)
    look = load("look.json").get("fire", {})
    audio = load("audio.json").get("fire", {})
    hexre = re.compile(r"^#[0-9A-Fa-f]{6}$")
    coals = look.get("coals")
    specks = look.get("specks")
    per_min = None
    if not isinstance(coals, dict) or not isinstance(specks, dict):
        errs.append("look.json fire has no coals / specks block (design §CZ)")
    else:
        if look.get("flame", {}).get("cards") != 1:
            errs.append("look.json fire.flame.cards must stay 1 (§CZ adds to §BZ's one flame card)")
        if coals.get("bands_from") != "flame.bands" or not look.get("flame", {}).get("bands"):
            errs.append("fire.coals.bands_from must be 'flame.bands', and the flame must have bands")
        if not hexre.match(str(coals.get("char", ""))):
            errs.append("fire.coals.char must be a #RRGGBB colour")
        for key in ("breath_amount", "patch_amount", "air_brighten"):
            v = coals.get(key)
            if not isinstance(v, (int, float)) or not 0 < v < 1:
                errs.append(f"fire.coals.{key} must be a share between 0 and 1")
        if not isinstance(coals.get("breath_hz"), (int, float)) or coals["breath_hz"] <= 0:
            errs.append("fire.coals.breath_hz must be above 0")
        if not is_range(coals.get("patch_hz")):
            errs.append("fire.coals.patch_hz must be [low, high]")
        elif coals["patch_hz"][0] <= coals.get("breath_hz", 0):
            warns.append("fire.coals.patch_hz starts at or under breath_hz: the patches won't read against the slow breath")
        ae = coals.get("at_embers", {})
        if not isinstance(ae.get("breath_hz"), (int, float)) or not isinstance(ae.get("breath_amount"), (int, float)):
            errs.append("fire.coals.at_embers needs breath_hz and breath_amount")
        br = look.get("light", {}).get("breath", {})
        if br.get("follows") != "coals" or not isinstance(br.get("amount"), (int, float)) or not 0 < br["amount"] <= 0.5:
            errs.append("fire.light.breath must follow 'coals' with an amount above 0 and at most 0.5")
        if specks.get("random_clock") is not True:
            errs.append("fire.specks.random_clock must be true (Mike: fly out randomly)")
        for key in ("burst", "big_burst", "speed_mps", "life_s"):
            if not is_range(specks.get(key)):
                errs.append(f"fire.specks.{key} must be [low, high]")
        spark, ash = specks.get("spark", {}), specks.get("ash", {})
        share = spark.get("share", 0) + ash.get("share", 0)
        if abs(share - 1.0) > 1e-6:
            errs.append(f"fire.specks: spark.share + ash.share is {share}, not 1")
        if ash.get("glows") is not False:
            errs.append("fire.specks.ash.glows must be false (only things that give off light glow)")
        for name, blk, keys in (("spark", spark, ("color", "cools_to")), ("ash", ash, ("color",))):
            for key in keys:
                if not hexre.match(str(blk.get(key, ""))):
                    errs.append(f"fire.specks.{name}.{key} must be a #RRGGBB colour")
        ac = str(ash.get("color", ""))
        if hexre.match(ac):
            r, g, b = (int(ac[i:i + 2], 16) for i in (1, 3, 5))
            if b - r < 16:
                errs.append(f"fire.specks.ash.color {ac} is a neutral or warm grey; it must be a blue-grey (LOOK_REFERENCE R3)")
        if specks.get("on_pop") and not is_range(audio.get("pops", {}).get("every_s")):
            errs.append("fire.specks.on_pop is true, but audio.json fire.pops.every_s is missing")
        if is_range(specks.get("big_burst")) and specks.get("max_alive", 0) < specks["big_burst"][1]:
            errs.append("fire.specks.max_alive is smaller than the biggest burst")
        gap = specks.get("mean_gap_s")
        if not isinstance(gap, (int, float)) or gap <= 0:
            errs.append("fire.specks.mean_gap_s must be above 0")
        elif is_range(specks.get("burst")) and is_range(specks.get("big_burst")):
            c = specks.get("big_burst_chance", 0.0)
            mean_burst = (1 - c) * sum(specks["burst"]) / 2.0 + c * sum(specks["big_burst"]) / 2.0
            per_min = 60.0 / gap * mean_burst
            if specks.get("on_pop") and is_range(audio.get("pops", {}).get("every_s")):
                # every pop of the fire's sound throws an ordinary burst of its own
                per_min += 60.0 / (sum(audio["pops"]["every_s"]) / 2.0) * sum(specks["burst"]) / 2.0
            mean_life = sum(specks["life_s"]) / 2.0 * (spark.get("share", 1) + ash.get("share", 0) * ash.get("life_scale", 1.0))
            alive = per_min / 60.0 * mean_life
            if alive > specks.get("max_alive", 0):
                warns.append(f"fire.specks: about {alive:.0f} alive on average, over max_alive {specks.get('max_alive')}")

    # ------------------------------------------------------------ the report
    def clock(h):
        h = h % 24.0
        return f"{int(h):02d}:{int(round((h - int(h)) * 60)) % 60:02d}"

    print("Fire circle check (design §CY, §CZ)")
    print(f"  the opening day at the reference (equator, equinox; a game hour is {gh:.0f} real min):")
    print(f"    wake           {clock(wake_h)}   {after:.0f} min after dawn begins")
    print(f"    circle breaks  {clock(rise_begin_h)}-{clock(hours[0])}   {(rise_begin_h - wake_h) * gh:.0f} min after you wake, over {rise * gh:.0f} min")
    print(f"    straight walk  arrives {clock(arrive_h)}   {walk:.0f} min of walking ({flat_km:.1f} km if dead flat, about {flat_km * pace:.1f} km on ordinary land); {straight:.0f} min before dusk")
    print(f"    dusk begins    {clock(dusk_begin_h)}   {to_dusk:.0f} min after you wake")
    print(f"    circle forms   {clock(hours[1])}-{clock(hours[1] + settle)}   over {settle * gh:.0f} min")
    print(f"    full dark      {clock(dark_h)}   a walk that took twice as long has {double:.0f} min to spare")
    if rows:
        print(f"  the world's first day (day of year {doy:.2f}), 66 S to 66 N:")
        print(f"    shortest day: {worst[1]:.0f} min from waking to dusk at {worst[0]:+d} deg; a straight walk has {worst[2]:.0f} min in hand there")
        longest = max(rows, key=lambda r: r[1])
        print(f"    longest day:  {longest[1]:.0f} min at {longest[0]:+d} deg")
    print(f"  seats: {len(kinds)} kinds over {seated_biomes} of {len(biome_keys)} biomes")
    print(f"  idles: {len(idles)} ({', '.join(idles)})")
    for p in PHASES:
        print(f"    {p:5s} picks from: {', '.join(pickable[p])}")
    if per_min is not None:
        print(f"  the fire (§CZ): the bed breathes every {1.0 / coals['breath_hz']:.1f} s; about {per_min:.0f} specks a minute "
              f"from the random clock and the pops ({alive:.0f} in the air on average), {spark.get('share', 0) * 100:.0f} % sparks, {ash.get('share', 0) * 100:.0f} % ash")
    for w in warns:
        print("WARNING:", w)
    for e in errs:
        print("ERROR:", e)
    print(f"{len(errs)} errors, {len(warns)} warnings")
    return 1 if errs or (args.strict and warns) else 0


if __name__ == "__main__":
    sys.exit(main())
