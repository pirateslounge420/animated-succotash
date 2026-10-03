class_name Communities
## Plants live in communities, and every community has one home (design
## 3 Oct §CS, data/habitat.json communities).
##
## A community is one of a biome file's associations: its dominant,
## companion, ground and catalogue lists (data/biomes/*.json). Before the
## player plants anything (§CT), each is native to one land, a RealmMap
## province, and grows nowhere else:
##   - the lands' stretches of each biome (a province's cells of that biome)
##     are dealt the biome's communities, biggest stretch first, each
##     stretch the community whose niche fits it best (deal_by niche: the
##     mean fit of its dominants, else of all its members, to the stretch's
##     temperature, moisture, height and soil, PlantSpecies.suitability),
##     with a bonus where the community's realm is the land's own here
##     (keep_lands_coherent: a land's communities come from one part of
##     Earth where they fit, RealmMap.realm) and a little seeded jitter, so
##     each world deals its own;
##   - no community is dealt twice (home one_land);
##   - a stretch left without one (the biome is in more lands than it has
##     communities, short_biome nearest_land_spreads) takes the community of
##     the nearest land that has one, as if it spread across the border;
##   - a biome with no communities at all keeps today's placement (the
##     biome gate) until a fill adds them; the check lists it.
## VegetationPlacer asks for_site(): a species grows at a site only as a
## member of the community there (its own bands, soil, needs and nest
## still decide where it stands within it), or, for a catalogue species no
## association lists yet (unattached_catalogue keep_current_until_fill), by
## its current rules. A member's realm doesn't gate it: the community's
## home was dealt by niche (§CS.3), so a member grows wherever its
## community lives.
## Pure functions of the planet after warm(): thread-safe for the placer.

const ROLES := ["dominant", "companion", "ground", "catalogue"]

static var HAB: Dictionary = Tuning.table("habitat")
static var CFG: Dictionary = HAB.get("communities", {})
## COMMUNITIES=0 in the environment turns it off (dev: today's placement,
## to compare).
static var ON: bool = bool(CFG.get("spawn_as_community", true)) and str(CFG.get("home", "one_land")) == "one_land" and OS.get_environment("COMMUNITIES") != "0"

## Every community: {"id", "biome" (BiomeTemplates id), "name", "realms"
## (PackedStringArray), "dominant" / "companion" / "ground" / "catalogue"
## (names), "members" ({PlantSpecies: role}), "doms" ([PlantSpecies])}.
static var all: Array = []
## Biome id -> [community index].
static var by_biome := {}
## Catalogue species some association lists (they grow only through it).
static var attached := {}
## Every species some association lists, anywhere.
static var listed := {}
## After warm(): "province:biome" -> {"community": index, "own": bool
## (false: spread from the nearest land), "cells": n}.
static var dealt := {}
static var _seed := -1
static var _loaded := false


## Read the communities from the biome files (once, after SpeciesDB).
static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var by_name := {}
	for sp in SpeciesDB.all():
		by_name[sp.name] = sp
	var dir := DirAccess.open(SpeciesDB.DATA_DIR)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(SpeciesDB.DATA_DIR + "/" + f))
		if not doc is Dictionary:
			continue
		var bid := BiomeTemplates.id_of_key(str(doc.get("key", "")))
		if bid < 0:
			continue
		var k := 0
		for a in doc.get("associations", []):
			if not a is Dictionary:
				continue
			var c := {"id": "%s#%d" % [str(doc.key), k], "biome": bid, "name": str(a.get("name", "")),
				"realms": SpeciesDB._realm_list(a.get("realm", "")), "members": {}, "doms": []}
			k += 1
			for role in ROLES:
				c[role] = []
				for n in a.get(role, []):
					(c[role] as Array).append(str(n))
					var sp: PlantSpecies = by_name.get(str(n))
					if sp == null:
						continue
					if not (c.members as Dictionary).has(sp):
						c.members[sp] = role
					listed[sp] = true
					if sp.from_catalogue:
						attached[sp] = true
					if role == "dominant":
						(c.doms as Array).append(sp)
			by_biome.get_or_add(bid, []).append(all.size())
			all.append(c)


## Deal the communities to the lands (§CS.2-4) for this planet. Call on the
## main thread before the placer runs (ChunkManager does, and the check).
static func warm(map: PlanetData) -> void:
	load_all()
	RealmMap.warm(map.terrain.world_seed)
	if _seed == map.terrain.world_seed and not dealt.is_empty():
		return
	_seed = map.terrain.world_seed
	dealt.clear()
	if not ON:
		return
	# The stretches: each province's cells of each land biome that has
	# communities, with their mean climate.
	var acc := {}
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.OCEAN:
			continue
		var b := map.biome[c]
		if not by_biome.has(b):
			continue
		var p := RealmMap.province_at(map.dir[c])
		var key := "%d:%d" % [p, b]
		var s: Dictionary = acc.get_or_add(key, {"p": p, "b": b, "n": 0, "t": 0.0, "m": 0.0, "h": 0.0, "rock": {}, "dir": Vector3.ZERO})
		s.n = int(s.n) + 1
		s.t = float(s.t) + map.temp_c[c]
		s.m = float(s.m) + map.moisture[c]
		s.h = float(s.h) + map.elevation[c]
		s.dir = (s.dir as Vector3) + map.dir[c]
		var rk: Dictionary = s.rock
		rk[map.rock[c]] = int(rk.get(map.rock[c], 0)) + 1
	var stretches: Array = acc.values()
	for s in stretches:
		var n := float(s.n)
		s.t = float(s.t) / n
		s.m = float(s.m) / n
		s.h = float(s.h) / n
		s.dir = (s.dir as Vector3).normalized()
		var best_rock := 0
		var best_n := -1
		for r in s.rock:
			if int(s.rock[r]) > best_n:
				best_n = int(s.rock[r])
				best_rock = int(r)
		s.rock = best_rock
	stretches.sort_custom(func(a, b): return int(a.n) > int(b.n) or (int(a.n) == int(b.n) and str(a.p) < str(b.p)))
	var used := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.terrain.world_seed, "communities"])
	var short: Array = []
	for s in stretches:
		var world := RealmMap.world_of(int(s.p))
		var realm := RealmMap.realm(world, s.dir, float(s.t), float(s.m), float(s.h) / PlanetConst.HEIGHT_SCALE)
		var best := -1
		var best_score := -INF
		for ci in by_biome[int(s.b)]:
			if used.has(ci):
				continue
			var score := niche_fit(all[ci], float(s.t), float(s.m), float(s.h), int(s.rock))
			if bool(CFG.get("keep_lands_coherent", true)):
				var rs: PackedStringArray = all[ci].realms
				if rs.has(realm) or rs.has("any"):
					score += 0.5
			score += rng.randf() * 0.15
			if score > best_score:
				best_score = score
				best = ci
		var key := "%d:%d" % [int(s.p), int(s.b)]
		if best >= 0:
			used[best] = true
			dealt[key] = {"community": best, "own": true, "cells": int(s.n)}
		else:
			short.append(s)
	# Short biomes: the nearest land that has one of the biome's own.
	for s in short:
		var key := "%d:%d" % [int(s.p), int(s.b)]
		var best := -1
		var best_dot := -2.0
		for other in stretches:
			var ok := "%d:%d" % [int(other.p), int(other.b)]
			if int(other.b) != int(s.b) or not dealt.has(ok) or not bool(dealt[ok].own):
				continue
			var dd := RealmMap.province_center(int(s.p)).dot(RealmMap.province_center(int(other.p)))
			if dd > best_dot:
				best_dot = dd
				best = int(dealt[ok].community)
		if best >= 0:
			dealt[key] = {"community": best, "own": false, "cells": int(s.n)}


## How well community `c`'s niche fits a stretch: the mean fit of its
## dominants (else of all its members), PlantSpecies.suitability.
static func niche_fit(c: Dictionary, t: float, m: float, h: float, rock: int) -> float:
	var list: Array = c.doms if not (c.doms as Array).is_empty() else (c.members as Dictionary).keys()
	if list.is_empty():
		return 0.0
	var sum := 0.0
	for sp in list:
		sum += (sp as PlantSpecies).suitability(t, m, h, rock) / maxf((sp as PlantSpecies).density, 1e-3)
	return sum / list.size()


## The community at direction `d` in biome `biome` (its index into all),
## -1 where the biome has none dealt (no communities: today's placement).
static func at(d: Vector3, biome: int) -> int:
	if not ON or dealt.is_empty():
		return -1
	var e = dealt.get("%d:%d" % [RealmMap.province_at(d), biome])
	return int(e.community) if e != null else -1


## May `sp` grow in community `ci` (-1: the biome has none, today's rules)?
## Members yes; a catalogue species no association lists keeps its current
## placement until the fill attaches it; anything else no.
static func admits(ci: int, sp: PlantSpecies) -> bool:
	if ci < 0:
		return true
	if (all[ci].members as Dictionary).has(sp):
		return true
	return sp.from_catalogue and not attached.has(sp) and str(CFG.get("unattached_catalogue", "keep_current_until_fill")) == "keep_current_until_fill"


## Is `sp` a member of community `ci` (it skips the realm gate there: the
## community's home was dealt by niche)?
static func member(ci: int, sp: PlantSpecies) -> bool:
	return ci >= 0 and (all[ci].members as Dictionary).has(sp)
