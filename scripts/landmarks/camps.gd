class_name Camps
extends Node
## Living camps: a fire burning and a few folk sitting round it, talking,
## looking about, turning to watch you come up, and a line of chatter
## when you step into the firelight. They're found:
##   * in inhabited ruins (Ruins.inhabited(): about half), at the spot the
##     ruin's builder left for a fire (RuinBuilder: the survivors' fire
##     ring, a castle courtyard, a tower's foot, under an arch, among the
##     igloos, beneath the treehouses, where the boardwalk starts);
##   * in the wild: flat, dry ground beside a river or lake, one in a few
##     grid cells;
##   * in rock shelters: at the foot of a cliff (TerrainField escarpments),
##     under a great slab of rock jutting out overhead;
##   * at nests (design 1 Oct §CK, Nests): the cave mouths, grottos,
##     cenote rims, waterfalls, ravines, escarpments and glowing bays whose
##     camp loop holds a living camp, at the nest's hearth spot, the nest's
##     own people (Peoples.pick reads the nest first).
## Who sits there depends on the place (Ruins.camp_folk(), country()):
## tribal folk in most land, fur-clad northerners in snow, hooded marsh
## folk, small folk squatting round the fire with their lanterns (some rock
## shelters and stone ruins), and at some stone ruins the restless dead,
## skeletons and a hooded one keeping them company.
##
## Built when the player comes within BUILD_M, freed past DROP_M. The
## folk are placeholder bodies (CreatureBodies), seated by bending the
## leg and arm pivots. Each has hitbox parts (torso, head, limbs, riding
## the pivots) and a blocker (CreatureHitboxes), so the player can't walk
## through them and an arrow glances off the part it meets (Arrow,
## shot_at()). The props collide (PropCollision): capsules along
## the seat logs, seat stones and leaning spears (arrows stick in them),
## hulls round the rock shelter's slab and boulders.
##
## Chatter is heard as well as read: whenever a line comes up (stepping
## into the firelight, an arrow in one of them) the folk murmur, a soft
## synthesized babble of several voices with no words (SoundSynth
## "murmur") on a 3D player among them (Audio3D "camp_chatter", heard to
## ~25 m), while the subtitle shows.

## data/camps.json: camps only at ruins, and the random wake (design 29
## Sept 2026: the fires are in the rare ruins, a different one each time
## you wake).
static var RULES := Tuning.table("camps")
## Deaths so far: with the world's seed, it picks a different ruin each
## time you wake.
var deaths := 0
const BUILD_M := 220.0
const DROP_M := 280.0
const WILD_CELL_M := 1800.0
const WILD_CHANCE := 0.3
const WILD_SALT := 777
const CLIFF_CELL_M := 1500.0
const CLIFF_CHANCE := 0.6
const CLIFF_SALT := 778
const SEAT_R := 2.0
const NOTICE_M := 12.0
const TALK_M := 5.0
## Murmur variants (SoundSynth "murmur" 0..n-1), made while the planet
## loads (setup()).
const MURMURS := 3

const FOLK := {
	"tribal": {"names": ["Hunter", "Elder", "Gatherer", "Scout"],
		"lines": ["Sit. The fire's warm.", "The rivers run high this season.", "Stay near the light after dark.",
			"We saw something moving on the ridge last night.", "Eat, if you're hungry. There's enough."]},
	"north": {"names": ["Northerner", "Trapper", "Old one"],
		"lines": ["Cold tonight. Colder tomorrow.", "Keep your hands near the flame.",
			"The ice sings when the moon is full.", "Don't wander past the drifts after dark."]},
	"marsh": {"names": ["Marsh-dweller", "Reed-cutter", "Hooded one"],
		"lines": ["Mind the planks. Some are rotten.", "Things drift up out of the water at night.",
			"The frogs go quiet before it comes.", "Stay on the boards, stranger."]},
	"small_folk": {"names": ["Small one", "Lantern-keeper", "Old small one"],
		"lines": ["Shinies? You got shinies?", "Hehe. The big one's back.", "Don't touch the pot!",
			"We saw you coming. We always see.", "Sit, sit. Nobody bites. Much."]},
	"dead": {"names": ["Skeleton", "Hooded one", "Old bones"],
		"lines": ["...we were kings here, once.", "Sit, wanderer. We have all the time there is.",
			"The fire remembers us.", "Don't mind us. We're only resting.", "Is it night again? It's always night."]},
}

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var landmarks: Landmarks
var hud: Hud
var map: PlanetData

var _root: Node3D
var _camps := {} # key -> Node3D
var _timer := 0.0
var _time := 0.0
var _wild := {} # Vector3i -> site dict or {}
var _cliff := {} # Vector3i -> site dict or {}
## The tribe's cloth family of the camp being built (CloakedFigure).
var _family := 0
## The sim's folk entry for the sitter being built ({} when none): sex,
## stage, role.
var _sitter_info := {}
## The people of the camp being built (design 30 Sept §BO): its palette
## colours and the folk kind's rig scale (Peoples).
## Canopy camps rebuilt waiting on their giants, by key (§BT).
var _canopy_tries := {}
var _people_pal: Array = []
var _folk_scale := 1.0
## Fires placed for a wake-up where no camp was near (wanderers()):
## key -> site dict.
var _wanderers := {}


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_landmarks: Landmarks, p_hud: Hud) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	landmarks = p_landmarks
	hud = p_hud
	map = world.planet
	_root = Node3D.new()
	_root.name = "Camps"
	world.world_root.add_child(_root)
	for i in MURMURS:
		SoundSynth.stream("murmur", i)


## A wild camp in grid cell `c`, or {}: {"dir", "folk", "seed"}.
static func wild_site(map: PlanetData, c: Vector3i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c, WILD_SALT])
	if rng.randf() > WILD_CHANCE:
		return {}
	var n := CreatureSpawner._cells_per_face(WILD_CELL_M)
	var center := CreatureSpawner._cell_point(c, n, WILD_SALT)
	for i in 14:
		var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * WILD_CELL_M * 0.4)
		var cell := map.cell_at(p)
		if map.water[cell] != PlanetData.Water.NONE:
			continue
		# Next to a river or lake (the blueprint measures in whole cells,
		# ~1.04 km on the full planet: one cell width is the cell beside one).
		if map.water_dist_km[cell] > map.cell_km() * 1.06:
			continue
		var e := map.terrain.elevation(p, true)
		if e < 2.0:
			continue
		var slope := absf(map.terrain.elevation(CreatureSpawner._offset(p, 0.0, 6.0), true) - map.terrain.elevation(CreatureSpawner._offset(p, PI, 6.0), true)) / 12.0
		if slope > 0.12:
			continue
		var land := Ruins.country(map, p)
		var folk := "north" if land == "snow" else ("marsh" if land == "marsh" else "tribal")
		return {"dir": p, "folk": folk, "seed": hash([c, "wild"])}
	return {}


## Where you wake after dying (the folk who found you carried you to
## their fire): the nearest camp fire to `d` within `search_m`, wild or
## rock shelter (the opening camp's fire, `opening`, counts too), as its
## planet direction. None in range: a small wandering group's fire is put
## down on dry, level ground `place_m` off, and that's it.
func wake_fire(d: Vector3, search_m: float, place_m: float, opening: Vector3) -> Vector3:
	deaths += 1
	if bool(RULES.get("only_at_ruins", true)):
		return _ruin_wake_fire(d, opening)
	var best := Vector3.ZERO
	var best_d := search_m
	if opening != Vector3.ZERO and CubeSphere.surface_distance_m(opening, d) < best_d:
		best_d = CubeSphere.surface_distance_m(opening, d)
		best = opening
	for c in CreatureSpawner._cells_around(d, search_m, WILD_CELL_M):
		if not _wild.has(c):
			_wild[c] = wild_site(map, c)
		var ws: Dictionary = _wild[c]
		if not ws.is_empty() and CubeSphere.surface_distance_m(ws.dir, d) < best_d:
			best_d = CubeSphere.surface_distance_m(ws.dir, d)
			best = ws.dir
	for c in CreatureSpawner._cells_around(d, search_m, CLIFF_CELL_M):
		if not _cliff.has(c):
			_cliff[c] = cliff_site(map, c)
		var cs: Dictionary = _cliff[c]
		if not cs.is_empty() and CubeSphere.surface_distance_m(cs.dir, d) < best_d:
			best_d = CubeSphere.surface_distance_m(cs.dir, d)
			best = cs.dir
	for key in _wanderers:
		var wd: Vector3 = _wanderers[key].dir
		if CubeSphere.surface_distance_m(wd, d) < best_d:
			best_d = CubeSphere.surface_distance_m(wd, d)
			best = wd
	if best != Vector3.ZERO:
		return best
	# Nobody near: wanderers found you and made camp close by.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([d, "wanderers"])
	var spot := d
	for i in 24:
		var p := CreatureSpawner._offset(d, rng.randf() * TAU, place_m * rng.randf_range(0.6, 1.2))
		var cell := map.cell_at(p)
		if map.water[cell] != PlanetData.Water.NONE or map.terrain.elevation(p, true) < 1.0:
			continue
		var slope := absf(map.terrain.elevation(CreatureSpawner._offset(p, 0.0, 6.0), true) - map.terrain.elevation(CreatureSpawner._offset(p, PI, 6.0), true)) / 12.0
		if slope <= 0.15:
			spot = p
			break
	var land := Ruins.country(map, spot)
	var folk := "north" if land == "snow" else ("marsh" if land == "marsh" else "tribal")
	_wanderers["wander:%d" % _wanderers.size()] = {"dir": spot, "folk": folk, "seed": hash([spot, "wanderers"])}
	return spot


## Waking found by folk (design 3 Oct §DE, camps.json wake_found).
## The camp whose fire stands within `within_m` of `fd`: {"key" (its
## CampSim key), "dir" (the fire), "site" (the ruin, or {})}, or {}.
## `opening` is the opening camp's fire.
func camp_at(fd: Vector3, opening: Vector3, within_m := 30.0) -> Dictionary:
	if opening != Vector3.ZERO and CubeSphere.surface_distance_m(opening, fd) <= within_m:
		return {"key": "opening", "dir": opening, "site": {}}
	for r in Ruins.near(map, fd, 400.0):
		var rf := ruin_fire_dir(map, r)
		if CubeSphere.surface_distance_m(rf, fd) <= within_m:
			return {"key": Overrun.camp_key(map, r), "dir": rf, "site": r}
	for n in Nests.near(fd, within_m + 60.0):
		if CubeSphere.surface_distance_m(n.hearth, fd) <= within_m:
			return {"key": str(n.key), "dir": n.hearth, "site": {}, "nest": n}
	return {}


## Why the camp `c` (camp_at's) is no fire to wake at, or "": "overrun"
## (§CN; the dark holds its ruin), "abandoned" (nobody lives there: its
## folk walked, were taken or never came) or "dark" (its fire is not lit:
## embers or out). A camp you never came upon has been living all along
## (CampSim), so only what is known counts against it.
func found_fault(c: Dictionary) -> String:
	if c.is_empty():
		return "abandoned"
	var site: Dictionary = c.get("site", {})
	if not site.is_empty():
		if Overrun.is_overrun(site):
			return "overrun"
		if not Ruins.inhabited(site) and not Overrun.settled(site):
			return "abandoned"
	if c.has("nest") and str((c.nest as Dictionary).get("state", "")) != "lived":
		return "abandoned"
	var fk := FireStore.key_of(c.dir)
	if CampSim.instance != null:
		var st := CampSim.instance.state_of(str(c.key))
		if not st.is_empty():
			if str(st.get("state", "living")) != "living" or (st.get("folk", []) as Array).is_empty():
				return "abandoned"
			fk = str(st.get("fire_key", fk))
	var fst: Dictionary = FireStore.stores.get(fk, {})
	if not fst.is_empty() and not (str(fst.get("state", "flames")) in ["flames", "low"]):
		return "dark"
	return ""


## The nearest camp fire lit with folk at it, measured from `d` (where you
## fell): the opening camp, the people's camps at ruins (never an overrun
## one) and the lived nests, the search widening from wake_radius_m as
## _ruin_wake_fire's does. {"key", "dir", "site"}, or {} if none.
func found_fire(d: Vector3, opening: Vector3) -> Dictionary:
	var radius := float(RULES.get("wake_radius_m", 12000.0))
	for step in int(RULES.get("widen_steps", 3)) + 1:
		var cands: Array = []
		if opening != Vector3.ZERO and CubeSphere.surface_distance_m(opening, d) <= radius:
			cands.append({"key": "opening", "dir": opening, "site": {}, "m": CubeSphere.surface_distance_m(opening, d)})
		for r in Ruins.near(map, d, radius):
			if Ruins.inhabited(r) or Overrun.settled(r):
				cands.append({"site": r, "m": CubeSphere.surface_distance_m(r.dir, d)})
		for n in Nests.near(d, radius):
			if str(n.state) == "lived":
				cands.append({"key": str(n.key), "dir": n.hearth, "site": {}, "nest": n, "m": CubeSphere.surface_distance_m(n.hearth, d)})
		cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.m) < float(b.m))
		for c in cands:
			if not c.has("dir"):
				var r: Dictionary = c.site
				c["dir"] = ruin_fire_dir(map, r)
				c["key"] = Overrun.camp_key(map, r)
			if found_fault(c) == "":
				c.erase("m")
				return c
		radius *= 2.0
	return {}


## The fire you wake at when camps are only at ruins (data/camps.json): a
## random inhabited ruin within wake_radius_m of where you died (the
## nearest, if wake_random is off), the search widening if there's none;
## the opening camp as the last resort.
## Does a camp's fire stand at `d` (within `within_m`): a people's camp at
## a ruin (its fire, ruin_fire_dir), a wild or cliff camp, or a wandering
## group's? (Main: never wake at a hearth whose fire is gone.)
func fire_at(d: Vector3, within_m := 30.0) -> bool:
	for r in Ruins.near(map, d, 400.0):
		if Ruins.inhabited(r) and CubeSphere.surface_distance_m(ruin_fire_dir(map, r), d) <= within_m:
			return true
	for n in Nests.near(d, within_m + 60.0):
		if str(n.state) == "lived" and CubeSphere.surface_distance_m(n.hearth, d) <= within_m:
			return true
	for c in CreatureSpawner._cells_around(d, within_m, WILD_CELL_M):
		if not _wild.has(c):
			_wild[c] = wild_site(map, c)
		var ws: Dictionary = _wild[c]
		if not ws.is_empty() and CubeSphere.surface_distance_m(ws.dir, d) <= within_m:
			return true
	for c in CreatureSpawner._cells_around(d, within_m, CLIFF_CELL_M):
		if not _cliff.has(c):
			_cliff[c] = cliff_site(map, c)
		var cs: Dictionary = _cliff[c]
		if not cs.is_empty() and CubeSphere.surface_distance_m(cs.dir, d) <= within_m:
			return true
	for key in _wanderers:
		if CubeSphere.surface_distance_m(_wanderers[key].dir, d) <= within_m:
			return true
	return false


func _ruin_wake_fire(d: Vector3, opening: Vector3) -> Vector3:
	var radius := float(RULES.get("wake_radius_m", 12000.0))
	var sites: Array = []
	for step in int(RULES.get("widen_steps", 3)) + 1:
		sites.clear()
		for r in Ruins.near(map, d, radius):
			if Ruins.inhabited(r):
				sites.append(r)
		if not sites.is_empty():
			break
		radius *= 2.0
	if sites.is_empty():
		return opening if opening != Vector3.ZERO else d
	var site: Dictionary
	if bool(RULES.get("wake_random", true)):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([map.terrain.world_seed if map.terrain else 0, deaths, Time.get_ticks_msec()])
		site = sites[rng.randi_range(0, sites.size() - 1)]
	else:
		site = sites[0]
		for r in sites:
			if CubeSphere.surface_distance_m(r.dir, d) < CubeSphere.surface_distance_m(site.dir, d):
				site = r
	return ruin_fire_dir(map, site)


## Where an inhabited ruin's fire is, as a surface direction: the camp
## spot its builder leaves (RuinBuilder.compute: local x/z in the ruin's
## frame), run once here without building the meshes into the scene.
static func ruin_fire_dir(p_map: PlanetData, site: Dictionary) -> Vector3:
	var data := RuinBuilder.compute(p_map, site)
	var cs: Vector3 = data.get("camp_spot", Vector3.ZERO)
	var a: float = site.heading + PI * 0.5
	var ex := CubeSphere.north(site.dir) * cos(a) + CubeSphere.east(site.dir) * sin(a)
	var ez := ex.cross(site.dir).normalized()
	return (site.dir + (ex * cs.x + ez * cs.z) / PlanetConst.RADIUS_M).normalized()


## A rock-shelter camp in grid cell `c`, or {}: {"dir" (the fire),
## "cliff" (bearing toward the cliff), "height" (m), "folk", "seed"}.
static func cliff_site(map: PlanetData, c: Vector3i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c, CLIFF_SALT])
	if rng.randf() > CLIFF_CHANCE:
		return {}
	var n := CreatureSpawner._cells_per_face(CLIFF_CELL_M)
	var center := CreatureSpawner._cell_point(c, n, CLIFF_SALT)
	for i in 40:
		var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * CLIFF_CELL_M * 0.45)
		if map.water[map.cell_at(p)] != PlanetData.Water.NONE:
			continue
		var e := map.terrain.elevation(p, true)
		if e < 3.0:
			continue
		for k in 8:
			var a := k * TAU / 8.0
			var wall := map.terrain.elevation(CreatureSpawner._offset(p, a, 7.0), true) - e
			if wall < 8.0:
				continue
			# Open, flat ground on the other side for the fire and seats.
			var fire := CreatureSpawner._offset(p, a + PI, 3.5)
			var ef := map.terrain.elevation(fire, true)
			var flat := absf(map.terrain.elevation(CreatureSpawner._offset(fire, a + PI, 3.0), true) - ef) + absf(map.terrain.elevation(CreatureSpawner._offset(fire, a + PI * 0.5, 3.0), true) - ef)
			if flat > 1.2:
				continue
			var land := Ruins.country(map, fire)
			var folk := "north" if land == "snow" else ("marsh" if land == "marsh" else "tribal")
			# Small folk hole up under rocks in milder country.
			if land == "" and map.sample(map.temp_c, fire) > 8.0 and rng.randf() < 0.45:
				folk = "small_folk"
			return {"dir": fire, "cliff": a, "height": wall, "folk": folk, "seed": hash([c, "cliff"])}
	return {}


## Per frame.
func update_camps(delta: float) -> void:
	_time += delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_refresh()
	var pp := player.global_position
	for key in _camps:
		_animate(_camps[key], delta, pp)
		_live(_camps[key], delta, pp)
		# Found (design 30 Sept §AZ): the first time you come to its fire.
		if (_camps[key] as Node3D).global_position.distance_to(pp) < 30.0:
			var people := Peoples.get_people(str((_camps[key] as Node3D).get_meta("people", "")))
			GameLog.add_once("camp:" + str(key), "Found a camp: the %s live here." % Peoples.name_of(people).to_lower(), "camp_found")
			if (_camps[key] as Node3D).has_meta("canopy"):
				GameLog.add_once("canopy:" + str(key), "They live up in the giants. No ladder comes down for a stranger.", "camp_found")


## Build the camps in reach now, not at the next half-second refresh
## (after waking by a fire).
func refresh_now() -> void:
	_timer = 0.5
	_refresh()


func _refresh() -> void:
	var pp := player.global_position
	var pd: Vector3 = world.dir_of(pp)
	var want := {}
	# Inhabited ruins, from the ruins Landmarks has built.
	var ruins := landmarks.built_ruins()
	for c in ruins:
		var node: Node3D = ruins[c]
		var site: Dictionary = node.get_meta("site")
		# (A cleared ruin folk have come back to is lived in: §CN.)
		if not Ruins.inhabited(site) and not Overrun.settled(site):
			continue
		var spot: Vector3 = node.global_transform * (node.get_meta("camp_spot") as Vector3)
		if spot.distance_to(pp) < BUILD_M:
			want["ruin:%s" % str(c)] = [spot, Ruins.camp_folk(site), site.seed]
	# Living camps at nests (design 1 Oct §CK camp_loop).
	for n in Nests.near(pd, BUILD_M):
		if str(n.state) != "lived":
			continue
		var hd: Vector3 = n.hearth
		var nspot: Vector3 = world.to_scene(hd, PlanetConst.RADIUS_M + chunks.ground_height(hd))
		if nspot.distance_to(pp) < BUILD_M:
			var nland := Ruins.country(map, hd)
			want[str(n.key)] = [nspot, "north" if nland == "snow" else ("marsh" if nland == "marsh" else "tribal"), int(n.seed)]
	# The earth homes' camps (design 3 Oct §DJ, HiddenPlaces): their hearth
	# in front of the doors, a hearth like any other.
	for hp in HiddenPlaces.camps_near(pd, BUILD_M):
		var hd2: Vector3 = hp.hearth
		var hspot: Vector3 = world.to_scene(hd2, PlanetConst.RADIUS_M + chunks.ground_height(hd2))
		if hspot.distance_to(pp) < BUILD_M:
			var hland := Ruins.country(map, hd2)
			want[str(hp.key)] = [hspot, "north" if hland == "snow" else ("marsh" if hland == "marsh" else "tribal"), int(hp.seed)]
	var only_ruins := bool(RULES.get("only_at_ruins", true))
	# Wild camps near water.
	for c in CreatureSpawner._cells_around(pd, BUILD_M, WILD_CELL_M) if not only_ruins else []:
		if not _wild.has(c):
			_wild[c] = wild_site(map, c)
		var ws: Dictionary = _wild[c]
		if ws.is_empty():
			continue
		var spot: Vector3 = world.to_scene(ws.dir, PlanetConst.RADIUS_M + chunks.ground_height(ws.dir))
		if spot.distance_to(pp) < BUILD_M:
			want["wild:%s" % str(c)] = [spot, ws.folk, ws.seed]
	# Rock shelters under cliffs.
	for c in CreatureSpawner._cells_around(pd, BUILD_M, CLIFF_CELL_M) if not only_ruins else []:
		if not _cliff.has(c):
			_cliff[c] = cliff_site(map, c)
		var cs: Dictionary = _cliff[c]
		if cs.is_empty():
			continue
		var spot: Vector3 = world.to_scene(cs.dir, PlanetConst.RADIUS_M + chunks.ground_height(cs.dir))
		if spot.distance_to(pp) < BUILD_M:
			want["cliff:%s" % str(c)] = [spot, cs.folk, cs.seed, cs]
	# Wanderers' fires placed for a wake-up.
	for key in _wanderers:
		var wsd: Dictionary = _wanderers[key]
		var spot: Vector3 = world.to_scene(wsd.dir, PlanetConst.RADIUS_M + chunks.ground_height(wsd.dir))
		if spot.distance_to(pp) < BUILD_M:
			want[key] = [spot, wsd.folk, wsd.seed]
	# Camps that walked away from a fire and rebuilt a valley over (§BL
	# wildfire): the sim's "moved:" states, built where they went.
	if CampSim.instance != null:
		for mk in CampSim.instance.states:
			if not str(mk).begins_with("moved:"):
				continue
			var ms: Dictionary = CampSim.instance.states[mk]
			var md: Vector3 = CampSim.instance._dir(ms)
			var spot: Vector3 = world.to_scene(md, PlanetConst.RADIUS_M + chunks.ground_height(md))
			if spot.distance_to(pp) < BUILD_M:
				want[str(mk)] = [spot, "tribal", int(ms.seed)]
	for key in want:
		if not _camps.has(key):
			var w: Array = want[key]
			_camps[key] = _build(w[0], w[1], w[2], str(key))
			if w.size() > 3:
				_overhang(_camps[key], w[3])
	for key in _camps.keys():
		var node: Node3D = _camps[key]
		if node.global_position.distance_to(pp) > DROP_M:
			NodeRelease.free_later(node)
			_camps.erase(key)


## A camp at scene position `at`: the fire, seats, and folk facing it.
## `key` names the camp (ruin:<cell>, cliff:<cell>, ...): it picks the
## people who live here (design 30 Sept §BO, Peoples.pick: the site's
## rules, then the biome) and the sim's state (CampSim).
func _build(at: Vector3, folk: String, seed_value: int, key := "") -> Node3D:
	# The camp's tribe: which dyed-cloth family its folk mostly wear.
	_family = CloakedFigure.tribe_family(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var d: Vector3 = world.dir_of(at)
	# The people (§BO): the way of life the site lives, dressed by the
	# biome: palette, shelter, props, the folk kind's build.
	var nest := Nests.by_key(key)
	var people_id := str(nest.get("people", "")) if not nest.is_empty() else Peoples.pick(map, chunks.rivers, d, "cliff" if key.begins_with("cliff") else "ruin")
	# Folk who came to a cleared ruin (§CN) are who they are.
	if CampSim.instance != null and CampSim.instance.states.has(key) and str(CampSim.instance.states[key].get("people", "")) != "":
		people_id = str(CampSim.instance.states[key].people)
	if people_id == "":
		people_id = Peoples.pick(map, chunks.rivers, d, "nest", nest)
	var people := Peoples.get_people(people_id)
	var biome_key := FireStore.biome_key(world, d)
	_people_pal = Peoples.palette(people, biome_key)
	# A camp at a temple city wears ochre (design 3 Oct §DR.6, ruins.json
	# styles.temple_city.camp.robes; §CL's colour).
	if key.begins_with("ruin:"):
		for rs in Ruins.near(map, d, 40.0):
			if int(rs.kind) == Ruins.Kind.TEMPLE_CITY:
				var robes := Color(str((Monuments.entry("temple_city").get("camp", {}) as Dictionary).get("robes", "#CC7722")))
				_people_pal = [robes, robes.darkened(0.18), robes.lightened(0.1), robes.darkened(0.3)]
	var kind := Peoples.folk_kind(people, seed_value)
	_folk_scale = Peoples.folk_scale(kind)
	var root := Node3D.new()
	root.name = "Camp"
	_root.add_child(root)
	root.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(d), d), at)
	root.set_meta("people", people_id)
	root.set_meta("kind", kind)
	root.set_meta("biome", biome_key)
	root.set_meta("key", key)
	var body := PropCollision.body(root)
	# The canopy folk (§BT, CanopyVillage): the village up in the stand's
	# giants, the fire in a hearth box on the first deck. With no three
	# giants in the loaded chunks yet the camp waits on the ground and is
	# built again when they are (canopy_wait, _live).
	var canopy := {}
	if people_id == "canopy":
		canopy = CanopyVillage.build(root, world, chunks, at, _people_pal, rng, biome_key, body)
		if canopy.is_empty():
			root.set_meta("canopy_wait", true)
		else:
			root.set_meta("canopy", true)
			root.set_meta("ladder", canopy.ladder)
	var fire := Campfire.build(root, world, chunks, d, false)
	fire.global_position = at
	if not canopy.is_empty():
		fire.global_position = root.to_global(canopy.fire_pos)
	root.set_meta("fire", fire)
	# A camp's fire can be made your hearth (design 30 Sept §AY).
	fire.set_meta("hearth_ok", true)
	# Its smoke goes up (design 3 Oct §CV, Smoke): open to the sky, or out
	# of a nest's mouth.
	fire.set_meta("smoke", 1.0)
	# What a camp has (design 30 Sept §AW): a bundle of unlit torches by
	# the fire, in the ambient profile.
	if Tuning.profile() == "ambient" and canopy.is_empty():
		Torch.lay_bundle(world, chunks, fire)
	root.set_meta("folk", folk)
	root.set_meta("talked", false)
	# Who sits here: the sim's folk (design 30 Sept §BM: men and women,
	# children by the fire, the headman, the plantkeeper and the maker
	# marked) when the camp has a state, else the old roll.
	var st_folk: Array = []
	if CampSim.instance != null and key != "":
		var pre := CampSim.instance.ensure(key, d, people_id, biome_key, seed_value)
		CampSim.instance.inherit(pre, people)
		st_folk = pre.folk
		root.set_meta("folk_stamp", _folk_stamp(pre))
		if str(pre.get("state", "living")) != "living":
			# An empty camp (§BL): no folk; the needful things left by the
			# fire, blood where the dark took them, the forest taking it.
			_empty_camp(root, pre, d, body)
			root.set_meta("sitters", [] as Array[Node3D])
			root.set_meta("guards", [] as Array[Node3D])
			return root
	var count := rng.randi_range(2, 4) if st_folk.is_empty() else mini(st_folk.size(), 8)
	if not canopy.is_empty():
		count = mini(count, (canopy.seats as Array).size())
	var a0 := rng.randf() * TAU
	var sitters: Array[Node3D] = []
	# The fire circle (design 3 Oct §CY.2–CY.3, FireCircle): seats the
	# place supplies, one a sitter and a spare, round the fire.
	var circle: Array = []
	if folk != "small_folk" and folk != "dead" and canopy.is_empty():
		var ch := chunks.chunk_at(d)
		circle = FireCircle.lay_seats(root, count, rng, {"biome": biome_key, "people": people_id,
			"site": "ruin" if key.begins_with("ruin") else ("cliff" if key.begins_with("cliff") else ""),
			"bark": FireCircle.stand_bark(chunks, at), "stones": CreatureSpawner.den_stones(map.rock[map.cell_at(d)]),
			"ground": ch.ground_color_at(d) if ch != null else Color(0.35, 0.42, 0.22),
			"cloth": _people_pal[0] if not _people_pal.is_empty() else Color(0.45, 0.3, 0.2)}, body)
	for i in count:
		_sitter_info = st_folk[i] if i < st_folk.size() else {}
		var a := a0 + TAU * i / count + rng.randf_range(-0.25, 0.25)
		var seat_pos := Vector3(cos(a), 0, sin(a)) * SEAT_R
		var face := -seat_pos.normalized()
		if not canopy.is_empty():
			# Up on the decks: round the hearth box, the rest at the back
			# of their own platforms, turned to it.
			seat_pos = (canopy.seats[i] as Dictionary).pos
			face = (canopy.seats[i] as Dictionary).face
		# Seat: a log across, a flat stone among the dead; small folk squat;
		# the canopy folk sit on the deck.
		if folk == "small_folk" or not canopy.is_empty() or not circle.is_empty():
			pass
		elif folk == "dead":
			var stone := CreatureBodies.box(root, Vector3(0.6, 0.4, 0.5), seat_pos + Vector3(0, 0.2, 0), Color(0.42, 0.42, 0.44))
			stone.rotation.y = -a
			# Along the stone's length (its x).
			PropCollision.capsule(body, Transform3D(stone.basis * Basis(Vector3(0, 0, 1), -PI * 0.5), stone.position), 0.2, 0.6)
		else:
			var log_seat := CreatureBodies.cone(root, 0.17, 0.17, 1.1, seat_pos + Vector3(0, 0.17, 0), Color(0.36, 0.25, 0.16))
			log_seat.rotation = Vector3(0, -a, PI * 0.5)
			PropCollision.capsule(body, log_seat.transform, 0.17, 1.1)
		var holder := _sitter(root, folk, i, rng)
		holder.position = seat_pos
		# Face the fire.
		holder.basis = Basis.looking_at(face, Vector3.UP)
		holder.set_meta("base_yaw", holder.rotation.y)
		if i < circle.size():
			FireCircle.sit(holder, circle[i])
			seat_pos = (circle[i] as Dictionary).pos
			a = atan2(seat_pos.z, seat_pos.x)
		holder.set_meta("phase", rng.randf() * TAU)
		sitters.append(holder)
		# Tribal and northern folk keep their weapons at hand: a spear
		# leaning on the log, or a bow laid by it.
		if (folk == "tribal" or folk == "north") and canopy.is_empty():
			var side := Vector3(-sin(a), 0, cos(a)) * 0.75
			if i % 3 == 2:
				var bow := BowMesh.build(1.2)
				root.add_child(bow)
				bow.position = seat_pos * 1.25 + side + Vector3(0, 0.05, 0)
				bow.rotation = Vector3(PI * 0.5, -a, 0.0)
			else:
				_spear(root, seat_pos * 1.3 + side, Vector3(cos(a), 0, sin(a)), 1.9, body)
	root.set_meta("sitters", sitters)
	# Guards: tribal and northern camps post one or two on their feet at
	# the edge of the firelight, spear or bow in hand, watching the dark.
	var guards: Array[Node3D] = []
	if (folk == "tribal" or folk == "north") and canopy.is_empty():
		for g in rng.randi_range(1, 2):
			var a := a0 + TAU * (g + 0.5) / count + PI / count
			var at_pos := Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.5, 5.5)
			var guard := _guard(root, folk, g, rng)
			guard.position = at_pos
			# Facing outward, away from the fire.
			guard.basis = Basis.looking_at(at_pos.normalized(), Vector3.UP)
			guard.set_meta("base_yaw", guard.rotation.y)
			guard.set_meta("phase", rng.randf() * TAU)
			guards.append(guard)
	root.set_meta("guards", guards)
	_dress(root, people, rng, a0, body)
	# The camp's life (design 30 Sept §BL, CampSim): its state, made now
	# if new and caught up; the store as props that scale with contents.
	if CampSim.instance != null and key != "":
		var st := CampSim.instance.ensure(key, d, people_id, biome_key, seed_value)
		var wa := a0 + 1.1
		var wp := CampProps.woodpile(root, float(st.wood), body)
		wp.position = Vector3(cos(wa), 0, sin(wa)) * 3.6
		wp.basis = Basis.looking_at(-wp.position.normalized(), Vector3.UP)
		var fa := a0 - 1.1
		var fs := CampProps.food_store(root, float(st.food), _people_pal, body)
		fs.position = Vector3(cos(fa), 0, sin(fa)) * 3.8
		fs.basis = Basis.looking_at(-fs.position.normalized(), Vector3.UP)
		if not canopy.is_empty():
			# A bundle under the eaves: the store on the hearth deck, small.
			wp.position = canopy.store_pos
			wp.scale = Vector3.ONE * 0.6
			wp.basis = Basis.looking_at(((canopy.hearth as Vector3) - (canopy.store_pos as Vector3)).slide(Vector3.UP).normalized(), Vector3.UP)
			fs.position = canopy.food_pos
			fs.scale = Vector3.ONE * 0.6
			fs.basis = Basis.looking_at(((canopy.hearth as Vector3) - (canopy.food_pos as Vector3)).slide(Vector3.UP).normalized(), Vector3.UP)
		root.set_meta("woodpile", wp)
		root.set_meta("food_store", fs)
		root.set_meta("store_t", 0.0)
		root.set_meta("walk_t", rng.randf_range(4.0, 12.0))
	# Their talk: among the seated folk, at head height.
	var chatter := Audio3D.make("camp_chatter", root, "Chatter")
	chatter.position = Vector3(0, 0.9, 0)
	chatter.volume_db = -8.0
	root.set_meta("chatter", chatter)
	return root


## The camp's dressing (design 30 Sept §BO, CampProps): the people's
## shelter across the fire from the seats' gap, and a few of its props
## round the firelight, each turned to the fire.
func _dress(root: Node3D, people: Dictionary, rng: RandomNumberGenerator, a0: float, body: StaticBody3D) -> void:
	var shelter := CampProps.shelter(root, people, _people_pal, rng, body)
	var sa := a0 + PI + rng.randf_range(-0.4, 0.4)
	shelter.position = Vector3(cos(sa), 0, sin(sa)) * rng.randf_range(7.5, 9.0)
	shelter.basis = Basis.looking_at(-shelter.position.normalized(), Vector3.UP)
	var props: Array = (people.get("aesthetic", {}) as Dictionary).get("props", [])
	var picked: Array = []
	for pr in props:
		var s := str(pr).to_lower()
		if s.find("ladder") >= 0 or s.find("bridge") >= 0 or s.find("hearth box") >= 0 or s.find("ceiling") >= 0:
			continue
		picked.append(str(pr))
	picked.shuffle()
	var count := mini(picked.size(), rng.randi_range(3, 4))
	var placed: Array = []
	for i in count:
		var n := CampProps.prop(root, picked[i], _people_pal, rng, body)
		n.set_meta("what", picked[i])
		var a := a0 + TAU * (i + 0.5) / count + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(4.2, 6.5)
		var pos := Vector3(cos(a), 0, sin(a)) * r
		# Not on the shelter.
		if pos.distance_to(shelter.position) < 4.0:
			pos = Vector3(cos(a), 0, sin(a)) * 3.6
		n.position = pos
		n.basis = Basis.looking_at(-pos.normalized(), Vector3.UP)
		placed.append(n)
	root.set_meta("props", placed)


## The folk of `camp` murmur (a line of chatter is up), from `at` (scene
## position; default among them).
func _murmur(camp: Node3D, at = null, who: Node3D = null) -> void:
	var v: AudioStreamPlayer3D = camp.get_meta("chatter", null)
	if v == null:
		return
	if at is Vector3:
		v.global_position = at
	else:
		v.position = Vector3(0, 0.9, 0)
	v.stream = SoundSynth.stream("murmur", randi() % MURMURS)
	v.pitch_scale = randf_range(0.95, 1.05) * _voice_pitch(camp, who)
	Audio3D.play(v)


## The voice reads the speaker at silhouette distance (§BM): a woman's
## higher, a child's and a teen's higher still, the folk kind's build
## (an orc low, the small folk and goblins high).
func _voice_pitch(camp: Node3D, who: Node3D) -> float:
	var p := 1.0
	if who != null:
		if str(who.get_meta("sex", "m")) == "f":
			p *= 1.12
		match str(who.get_meta("stage", "adult")):
			"child":
				p *= 1.3
			"teen":
				p *= 1.15
	match str(camp.get_meta("kind", "human")):
		"orc":
			p *= 0.85
		"goblin":
			p *= 1.1
		"fae":
			p *= 1.08
		"small_folk":
			p *= 1.25
	return p


## A spear leaning out from `base` (camp space) along `lean`, `length` m,
## with a thin capsule from butt to tip on `body` (so arrows stick).
func _spear(parent: Node3D, base: Vector3, lean: Vector3, length: float, body: StaticBody3D) -> void:
	var shaft := CreatureBodies.cone(parent, 0.018, 0.015, length, Vector3.ZERO, Color(0.42, 0.3, 0.18), 0.0, 5)
	var dirv := (Vector3.UP + lean * 0.35).normalized()
	var x := dirv.cross(Vector3.FORWARD if absf(dirv.z) < 0.9 else Vector3.RIGHT).normalized()
	shaft.transform = Transform3D(Basis(x, dirv, x.cross(dirv)), base + dirv * length * 0.5)
	var head := CreatureBodies.cone(parent, 0.035, 0.0, 0.16, Vector3.ZERO, Color(0.34, 0.35, 0.38), 0.0, 4)
	head.transform = Transform3D(Basis(x, dirv, x.cross(dirv)), base + dirv * (length + 0.08))
	PropCollision.capsule_between(body, base, base + dirv * (length + 0.16), 0.03)


## A standing guard: a hunter with a spear or an archer with a bow.
func _guard(parent: Node3D, folk: String, i: int, rng: RandomNumberGenerator) -> Node3D:
	# A cloaked figure standing watch, a bow on the back of every other.
	var pal := _folk_palette(rng, i)
	var b := CloakedFigure.build(rng.randf_range(1.66, 1.8) * _folk_scale, pal[0], pal[1])
	var holder := Node3D.new()
	holder.name = "Guard"
	parent.add_child(holder)
	var body: Node3D = b.root
	body.name = "Body"
	holder.add_child(body)
	if i % 2 == 1 or rng.randf() < 0.4:
		var bow := BowMesh.build(1.1)
		body.add_child(bow)
		bow.position = Vector3(0.05, 1.05, 0.16)
		bow.rotation = Vector3(0.0, 0.0, 0.5)
	holder.set_meta("hitboxes", CloakedFigure.hitboxes(holder, b, true))
	holder.set_meta("arms", b.wings)
	holder.set_meta("head", (body as PlayerBody).head)
	holder.set_meta("speaker", "Guard")
	holder.set_meta("standing", true)
	BlobShadow.make(holder, 0.35, 0.35)
	return holder


## A rock shelter over a cliff camp: a great slab jutting out from the
## cliff above the fire, and boulders either side. Each collides as the
## hull of its own stone (RuinBuilder.rock_hull()).
func _overhang(camp: Node3D, cs: Dictionary) -> void:
	var d: Vector3 = cs.dir
	var up: Vector3 = d
	var at := camp.global_position
	var toward_d := CreatureSpawner._offset(d, cs.cliff, 5.0)
	var toward: Vector3 = world.to_scene(toward_d, PlanetConst.RADIUS_M + chunks.ground_height(d)) - at
	toward = (toward - up * toward.dot(up)).normalized()
	var along := up.cross(toward).normalized()
	var h: float = cs.height
	var rng := RandomNumberGenerator.new()
	rng.seed = cs.seed
	var col := Color(0.44, 0.43, 0.42)
	var slab := MeshInstance3D.new()
	var slab_size := Vector3(7.5, 1.8, 6.0)
	slab.mesh = RuinBuilder.rock_mesh(slab_size, cs.seed, col)
	slab.material_override = RuinBuilder.material()
	camp.add_child(slab)
	# The slab spans 1.5 m outward of the fire to 4.5 m in: the fire sits a
	# pace and a half in from the drip line, dry in rain (design 1 Oct §CK;
	# it sat at the drip line).
	slab.global_transform = Transform3D(Basis(along, up, -toward).rotated(along, 0.12), at + toward * 1.5 + up * (h * 0.8))
	PropCollision.hull(PropCollision.body(slab), RuinBuilder.rock_hull(slab_size, cs.seed))
	for s in [-1.0, 1.0]:
		var rock := MeshInstance3D.new()
		var size := Vector3(rng.randf_range(1.6, 2.4), rng.randf_range(1.8, 2.8), rng.randf_range(1.6, 2.2))
		rock.mesh = RuinBuilder.rock_mesh(size, cs.seed + int(s * 7.0), col.darkened(0.05))
		rock.material_override = RuinBuilder.material()
		camp.add_child(rock)
		rock.global_transform = Transform3D(Basis(along, up, -toward).rotated(up, rng.randf() * TAU), at + along * s * 3.6 + toward * 1.8 + up * size.y * 0.35)
		PropCollision.hull(PropCollision.body(rock), RuinBuilder.rock_hull(size, cs.seed + int(s * 7.0)))


## One seated figure (an unscaled holder, the body under it). The living
## are cloaked figures on the player's rig in their tribe's colors (the
## small folk half the height, squatting, a lantern each); the dead at
## some ruins keep their bones.
func _sitter(parent: Node3D, folk: String, i: int, rng: RandomNumberGenerator) -> Node3D:
	var names: Array = FOLK[folk].names
	var sname: String = names[i % names.size()]
	var holder := Node3D.new()
	holder.name = sname
	parent.add_child(holder)
	if folk == "dead":
		var sp := CreatureSpecies.new()
		sp.name = sname
		sp.size_m = rng.randf_range(1.62, 1.8)
		if i == 0:
			sp.body = "robed"
			sp.color = Color(0.12, 0.2, 0.62) # deep blue robe
			sp.accent = Color(0.86, 0.82, 0.68)
			sp.name = "Hooded one"
		else:
			sp.body = "skeleton"
			sp.color = Color(0.86, 0.82, 0.68).darkened(rng.randf_range(0.0, 0.12))
			sp.name = "Skeleton"
		holder.name = sp.name
		var bd := CreatureBodies.build(sp)
		var dbody: Node3D = bd.root
		dbody.name = "Body"
		holder.add_child(dbody)
		dbody.position.y = 0.4 - 0.5 * sp.size_m
		for leg in bd.legs:
			(leg as Node3D).rotation.x = 1.05
		for arm in bd.wings:
			(arm as Node3D).rotation.x = 0.55
		holder.set_meta("hitboxes", CreatureHitboxes.build(holder, bd, sp, true))
		holder.set_meta("arms", bd.wings)
		holder.set_meta("head", dbody.get_node_or_null("Head"))
		holder.set_meta("speaker", sp.name)
		BlobShadow.make(holder, 0.3 * sp.size_m, 0.4 * sp.size_m).position.z = -0.12 * sp.size_m
		return holder
	var small := folk == "small_folk"
	var pal := _folk_palette(rng, i)
	var info := _sitter_info
	var sex := str(info.get("sex", "m" if i % 2 == 0 else "f"))
	var stage := CampSim.stage_of(info) if not info.is_empty() else "adult"
	var role := str(info.get("role", ""))
	# Men and women read at silhouette distance: build and height; the
	# stages (§BM: child, teen, adult) at sim.births.stages rig_scale.
	var h := rng.randf_range(0.9, 1.08) if small else rng.randf_range(1.6, 1.78) * _folk_scale * (0.94 if sex == "f" else 1.0)
	h *= float((CampSim.stages().get(stage, {}) as Dictionary).get("rig_scale", 1.0))
	match role:
		"headman":
			pal[0] = (pal[0] as Color).darkened(0.25)
			pal[1] = Color(0.92, 0.9, 0.8)
		"plantkeeper":
			pal[0] = (pal[0] as Color).lerp(Color(0.3, 0.45, 0.25), 0.5)
		"maker":
			pal[0] = (pal[0] as Color).lerp(Color(0.5, 0.3, 0.2), 0.4)
	var b := CloakedFigure.build(h, pal[0], pal[1], true)
	var body: PlayerBody = b.root
	body.name = "Body"
	holder.add_child(body)
	holder.set_meta("sex", sex)
	holder.set_meta("role", role)
	holder.set_meta("stage", stage)
	if role == "headman":
		# The staff: the headman's mark.
		var staff := CreatureBodies.cone(holder, 0.03, 0.025, 1.9 * _folk_scale, Vector3(0.32, 0.95 * _folk_scale, 0.1), Color(0.45, 0.32, 0.2), 0.0, 6)
		staff.rotation.z = -0.08
		holder.name = "Headman"
	elif role == "plantkeeper":
		CreatureBodies.box(holder, Vector3(0.18, 0.14, 0.1), Vector3(-0.3, 0.5 * _folk_scale, 0.12), Color(0.5, 0.42, 0.25))
		holder.name = "Plantkeeper"
	elif role == "maker":
		holder.name = "Maker"
	if small:
		# Squatting on the ground, knees up, with a lantern.
		body.position.y = -PlayerBody.SHIN_M * body.scale.y * 0.9
		CloakedFigure.add_lantern(b)
	holder.set_meta("hitboxes", CloakedFigure.hitboxes(holder, b, true))
	holder.set_meta("arms", b.wings)
	holder.set_meta("head", body.head)
	holder.set_meta("speaker", sname)
	var blob := BlobShadow.make(holder, 0.3 * h, 0.4 * h)
	blob.position.z = -0.12 * h
	return holder


## A folk's cloak: the tribe's roll, pulled toward the people's palette
## (design §BO: the biome dresses the life).
func _folk_palette(rng: RandomNumberGenerator, i: int) -> Array:
	var pal := CloakedFigure.roll_palette(rng, _family)
	if not _people_pal.is_empty():
		var pc: Color = _people_pal[i % _people_pal.size()]
		pal[0] = (pal[0] as Color).lerp(pc, 0.45)
	return pal


## Idle life: the fire flickers; the folk look round at each other and the
## fire, now and then lift an arm as they talk, and turn toward the player
## when close; stepping into the firelight gets a line of chatter.
func _animate(camp: Node3D, delta: float, pp: Vector3) -> void:
	Campfire.flicker(camp.get_meta("fire"), _time)
	var sitters: Array = camp.get_meta("sitters")
	var near := camp.global_position.distance_to(pp)
	_hitboxes(camp, Hitboxes.wanted_at(camp.global_position, pp))
	# The fire circle's loops and the hood's notice (§CY.2, FireCircle)
	# for the cloaked folk; the dead keep their old idle.
	var cloaked: Array = []
	for s in sitters:
		if (s as Node3D).has_meta("stage"):
			cloaked.append(s)
	if not cloaked.is_empty():
		FireCircle.animate(cloaked, camp.get_meta("fire"), _time, delta, pp, _circle_phase(camp), _circle_ctx(camp))
	for i in sitters.size():
		var s: Node3D = sitters[i]
		if s.has_meta("stage"):
			continue
		var ph: float = s.get_meta("phase")
		var yaw: float = s.get_meta("base_yaw")
		var target := yaw + 0.35 * sin(_time * 0.3 + ph)
		if near < NOTICE_M:
			# Turn toward the player, but no further than over a shoulder.
			var to := s.global_transform.affine_inverse() * pp
			var want := s.rotation.y + atan2(-to.x, -to.z)
			target = yaw + clampf(angle_difference(yaw, want), -1.2, 1.2)
		s.rotation.y = lerp_angle(s.rotation.y, target, clampf(delta * 1.5, 0.0, 1.0))
		# Talking hands.
		var arms: Array = s.get_meta("arms")
		var talk := maxf(sin(_time * 0.7 + ph * 3.0), 0.0)
		if not arms.is_empty():
			(arms[0] as Node3D).rotation.x = 0.55 + 0.6 * talk * talk
		var head: Node3D = s.get_meta("head")
		if head:
			head.rotation.y = 0.4 * sin(_time * 0.45 + ph)
	for g in camp.get_meta("guards", []):
		var gn: Node3D = g
		var ph: float = gn.get_meta("phase")
		var yaw: float = gn.get_meta("base_yaw")
		var target := yaw + 0.7 * sin(_time * 0.2 + ph)
		var to := gn.global_transform.affine_inverse() * pp
		if gn.global_position.distance_to(pp) < 20.0:
			target = gn.rotation.y + atan2(-to.x, -to.z)
		gn.rotation.y = lerp_angle(gn.rotation.y, target, clampf(delta * 1.2, 0.0, 1.0))
	if near < TALK_M and not camp.get_meta("talked"):
		camp.set_meta("talked", true)
		var folk: String = camp.get_meta("folk")
		var lines: Array = FOLK[folk].lines
		var s0: Node3D = sitters[0]
		hud.say(s0.get_meta("speaker"), lines[randi() % lines.size()], 0.2, 4.0)
		_murmur(camp, null, s0)


## The phase of the day at `camp` (dawn, day, dusk, night) for the fire
## circle's loops.
func _circle_phase(camp: Node3D) -> String:
	var d: Vector3 = world.dir_of(camp.global_position)
	var h: float = world.local_clock(d).y
	return FireCircle.phase_name(h, CubeSphere.latitude(d), world.days)


## What the camp has for the circle's loops: food in the store (the bowls
## come out), the fire below the store's feed line (feed_fire).
func _circle_ctx(camp: Node3D) -> Dictionary:
	var out := {"food_ok": true, "fire_low": false}
	var key := str(camp.get_meta("key", ""))
	if CampSim.instance != null and key != "":
		var st := CampSim.instance.state_of(key)
		if not st.is_empty():
			out.food_ok = float(st.get("food", 0.0)) > 0.0
	var fire: Node3D = camp.get_meta("fire")
	var fst := FireStore.store_of(fire)
	if not fst.is_empty():
		out.fire_low = FireStore.units_now(fst) < float((CampSim.SIM.get("store", {}) as Dictionary).get("feed_fire_below_units", 3.0))
	return out


## The camp's living (§BL): the store props follow the sim's state, and
## by day one of the folk now and then walks out to the woods or the
## water and back to the store with what they gathered (a figure that
## goes and comes; the seated folk keep the fire).
func _live(camp: Node3D, delta: float, pp: Vector3) -> void:
	if CampSim.instance == null or not camp.has_meta("woodpile"):
		return
	var st := CampSim.instance.state_of(str(camp.get_meta("key", "")))
	if st.is_empty():
		return
	var t: float = camp.get_meta("store_t", 0.0) - delta
	if t <= 0.0:
		t = 1.5
		# Folk born, grown, gone, given a role: the camp is built again
		# with them (out of the player's sight, at the next refresh).
		if str(camp.get_meta("folk_stamp", "")) != _folk_stamp(st) and camp.global_position.distance_to(pp) > 40.0:
			var key := str(camp.get_meta("key", ""))
			NodeRelease.free_later(camp)
			_camps.erase(key)
			return
		# The canopy folk waiting on their giants (§BT): once the chunk's
		# trees are in, the village goes up (a few tries, out of sight).
		if bool(camp.get_meta("canopy_wait", false)) and camp.global_position.distance_to(pp) > 40.0:
			var key := str(camp.get_meta("key", ""))
			var tries := int(_canopy_tries.get(key, 0))
			if tries < 3 and CanopyVillage.giants_near(chunks, camp.global_position, CanopyVillage.SEARCH_M).size() >= CanopyVillage.MIN_GIANTS:
				_canopy_tries[key] = tries + 1
				NodeRelease.free_later(camp)
				_camps.erase(key)
				return
		# Their rope ladder comes down once the headman has met you.
		if camp.has_meta("ladder"):
			var lad: Node3D = camp.get_meta("ladder")
			if is_instance_valid(lad):
				lad.visible = bool(st.get("met_headman", false))
		# The fundamentals' props: the plot and the weir (§BM).
		if bool(st.get("plot", false)) and not camp.has_meta("plot"):
			camp.set_meta("plot", _plot(camp, st))
		if bool(st.get("weir", false)) and not camp.has_meta("weir"):
			camp.set_meta("weir", _weir(camp, st))
		var wp: Node3D = camp.get_meta("woodpile")
		if absf(float(wp.get_meta("units", -1.0)) - float(st.wood)) >= 0.5:
			CampProps.refresh_woodpile(wp, float(st.wood))
		var fs: Node3D = camp.get_meta("food_store")
		if absf(float(fs.get_meta("units", -1.0)) - float(st.food)) >= 1.0:
			CampProps.refresh_food_store(fs, float(st.food))
	camp.set_meta("store_t", t)
	# The loop's walker.
	# (get_meta with a null default still errors when the key is missing.)
	var walker = camp.get_meta("walker") if camp.has_meta("walker") else null
	if walker != null and is_instance_valid(walker):
		_walk(camp, walker, delta)
		return
	if str(st.state) != "living" or camp.has_meta("canopy"):
		return # the canopy folk never come down (§BT): no walker
	var wt: float = camp.get_meta("walk_t", 8.0) - delta
	camp.set_meta("walk_t", wt)
	if wt > 0.0 or camp.global_position.distance_to(pp) > 120.0:
		return
	var loop: Dictionary = CampSim.SIM.get("loop", {})
	var gh = loop.get("gather_hours", [7, 17])
	var h := CampSim.instance.clock_h(st, world.days)
	if h < float(gh[0]) or h >= float(gh[1]) or CampSim.instance.gatherers(st) <= 0:
		camp.set_meta("walk_t", 10.0)
		return
	# Out to a point walk_out_m away, then back to the store.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wo = loop.get("walk_out_m", [15, 35])
	var d0: Vector3 = world.dir_of(camp.global_position)
	var out := CreatureSpawner._offset(d0, rng.randf() * TAU, rng.randf_range(float(wo[0]), float(wo[1])))
	var pal := _folk_palette(rng, rng.randi() % 4)
	var b := CloakedFigure.build(rng.randf_range(1.62, 1.78) * Peoples.folk_scale(str(camp.get_meta("kind", "human"))), pal[0], pal[1])
	var holder := Node3D.new()
	holder.name = "Walker"
	camp.add_child(holder)
	holder.add_child(b.root)
	holder.set_meta("body", b.root)
	holder.set_meta("from", d0)
	holder.set_meta("to", out)
	holder.set_meta("t", 0.0)
	holder.set_meta("leg", 0) # 0 out, 1 pause, 2 back
	holder.global_position = camp.global_position
	camp.set_meta("walker", holder)
	camp.set_meta("walk_t", rng.randf_range(25.0, 60.0))


func _walk(camp: Node3D, holder: Node3D, delta: float) -> void:
	var leg: int = holder.get_meta("leg")
	var t: float = holder.get_meta("t") + delta
	var from: Vector3 = holder.get_meta("from")
	var to: Vector3 = holder.get_meta("to")
	var len_m := CubeSphere.surface_distance_m(from, to)
	var speed := 1.3
	var body: Node3D = holder.get_meta("body")
	if leg == 1:
		if t > 4.0:
			holder.set_meta("leg", 2)
			holder.set_meta("t", 0.0)
		else:
			holder.set_meta("t", t)
			if body.has_method("set_motion"):
				body.call("set_motion", 0.0, delta)
		return
	var k := clampf(t * speed / maxf(len_m, 0.1), 0.0, 1.0)
	var a := from if leg == 0 else to
	var b := to if leg == 0 else from
	var at := a.slerp(b, k)
	var ahead := a.slerp(b, minf(k + 0.02, 1.0))
	holder.global_position = world.to_scene(at, PlanetConst.RADIUS_M + chunks.ground_height(at))
	var fwd := ahead - at
	fwd = (fwd - at * fwd.dot(at))
	if fwd.length() > 1e-9:
		holder.global_basis = Basis.looking_at(fwd.normalized(), at)
	if body.has_method("set_motion"):
		body.call("set_motion", 0.7, delta)
	holder.set_meta("t", t)
	if k >= 1.0:
		if leg == 0:
			holder.set_meta("leg", 1)
			holder.set_meta("t", 0.0)
		else:
			# Home: what they carried is on the store (the sim did the
			# accounting); the figure is done.
			holder.queue_free()
			if camp.has_meta("walker"):
				camp.remove_meta("walker")


## An empty camp (§BL abandon): the fire as it is (embers or out), the
## needful things left (a fuel pile, a torch bundle; the pot waits on the
## potter), a dark stain by the fire where the dark took them, the props
## sinking as the forest takes it back.
func _empty_camp(root: Node3D, st: Dictionary, d: Vector3, body: StaticBody3D) -> void:
	var reclaim := CampSim.instance.reclaim(st)
	root.set_meta("empty", true)
	for it in (CampSim.SIM.get("abandon", {}) as Dictionary).get("needful_things_left", []):
		match str(it):
			"fuel_pile":
				if reclaim < 0.8:
					var off := CreatureSpawner._offset(d, 1.0, 2.6)
					WorldItem.drop(Inventory.make("fuel", {"fuel": "branch", "title": "Branch", "carry_items": 1}), world, off, chunks.ground_height(off))
			"torch_bundle":
				if reclaim < 0.6 and Tuning.profile() == "ambient":
					Torch.lay_bundle(world, chunks, root.get_meta("fire"))
	if bool(st.get("blood", false)) and reclaim < 0.5:
		var stain := CreatureBodies.ball(root, Vector3(1.2, 0.03, 0.9), Vector3(1.6, 0.02, 0.4), Color(0.25, 0.05, 0.04))
		stain.rotation.y = 0.6
	for n in root.get_meta("props", []):
		(n as Node3D).position.y -= 0.5 * reclaim
		(n as Node3D).rotation.z += 0.25 * reclaim


## The sim's folk as a stamp (count, children, roles): a change rebuilds.
static func _folk_stamp(st: Dictionary) -> String:
	var s := ""
	for f in st.get("folk", []):
		s += "%s%s%s," % [str(f.get("sex", "")), CampSim.stage_of(f), str(f.get("role", ""))]
	return s


## A garden plot near the fire (§BM crop): rows of the crop in a hurdle
## fence, the seeds' own species where one took.
func _plot(camp: Node3D, st: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Plot"
	camp.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(st.key), "plot"])
	var a := rng.randf() * TAU
	n.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(11.0, 14.0)
	n.basis = Basis.looking_at(-n.position.normalized(), Vector3.UP)
	var col := Color(0.35, 0.55, 0.25)
	var sp_idx := int(st.get("plot_species", -1))
	if sp_idx >= 0 and sp_idx < SpeciesDB.all().size():
		col = (SpeciesDB.all()[sp_idx] as PlantSpecies).color
	for r in 3:
		for c in 5:
			var h := rng.randf_range(0.3, 0.6)
			CreatureBodies.cone(n, 0.16, 0.02, h, Vector3(-1.6 + c * 0.8, h * 0.5, -1.2 + r * 1.2), col.darkened(rng.randf() * 0.15), 0.0, 6)
	for i in 12:
		var ang := i * TAU / 12.0
		var p := CreatureBodies.cone(n, 0.035, 0.025, 0.9, Vector3(cos(ang) * 2.8, 0.45, sin(ang) * 2.4), CampProps.POLE, 0.0, 5)
		p.rotation.x = rng.randf_range(-0.1, 0.1)
	return n


## The weir (§BM fish_run): a V of stakes at the nearest water within
## reach of the camp (the shore, the river bank), or nothing yet if no
## water is loaded near.
func _weir(camp: Node3D, st: Dictionary) -> Node3D:
	var d0: Vector3 = world.dir_of(camp.global_position)
	var best := Vector3.ZERO
	var best_m := INF
	for k in 16:
		for r in [40.0, 80.0, 140.0, 220.0, 300.0]:
			var p := CreatureSpawner._offset(d0, k * TAU / 16.0, r)
			if chunks.water_level_at(p) > chunks.ground_height(p) + 0.3 and r < best_m:
				best_m = r
				best = p
	if best == Vector3.ZERO:
		return null
	var n := Node3D.new()
	n.name = "Weir"
	camp.add_child(n)
	n.global_position = world.to_scene(best, PlanetConst.RADIUS_M + chunks.water_level_at(best))
	n.global_basis = Basis.looking_at(CubeSphere.north(best), best)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(st.key), "weir"])
	for side in [-1.0, 1.0]:
		for i in 7:
			var x: float = float(side) * i * 0.9
			var z: float = -i * 1.1
			var stake := CreatureBodies.cone(n, 0.05, 0.03, 1.4, Vector3(x, 0.3, z), CampProps.POLE.darkened(0.2), 0.0, 5)
			stake.rotation = Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
	return n


## The camp's store node within reach of `pos` (the woodpile or the food
## store), and its camp: [store, camp] or [].
func store_in_reach(pos: Vector3, radius: float) -> Array:
	for key in _camps:
		var camp: Node3D = _camps[key]
		for m in ["woodpile", "food_store"]:
			var n: Node3D = camp.get_meta(m, null)
			if n != null and is_instance_valid(n) and n.global_position.distance_to(pos) < radius:
				return [n, camp]
	return []


## The folk's hitboxes (CreatureHitboxes) in the physics space only while
## the camp is near the player or an arrow (Hitboxes.wanted_at()).
func _hitboxes(camp: Node3D, on: bool) -> void:
	if camp.get_meta("hitboxes_on", true) == on:
		return
	camp.set_meta("hitboxes_on", on)
	for f in camp.get_meta("sitters") + camp.get_meta("guards", []):
		Hitboxes.set_active((f as Node).get_meta("hitboxes", []), on)


const SHOT_LINES := ["Hey! Watch where you shoot!", "Oi! Put that bow down!", "Are you trying to get yourself killed?", "Aim at the deer, not at us!"]
const SHOT_LINES_DEAD := ["...that tickles.", "You can't kill what's already dead, wanderer.", "Rude."]
var _shot_cd := 0.0


## An arrow struck one of the camp folk: they don't take kindly to it.
func shot_at(folk: Node3D) -> void:
	if _time < _shot_cd:
		return
	_shot_cd = _time + 3.0
	var dead := String(folk.get_meta("speaker", "")) in ["Skeleton", "Hooded one"]
	var lines := SHOT_LINES_DEAD if dead else SHOT_LINES
	hud.say(folk.get_meta("speaker", "?"), lines[randi() % lines.size()], 0.0, 3.0)
	var camp := folk.get_parent() as Node3D
	if camp and camp.has_meta("chatter"):
		_murmur(camp, folk.global_position + world.dir_of(folk.global_position) * 0.9, folk)
