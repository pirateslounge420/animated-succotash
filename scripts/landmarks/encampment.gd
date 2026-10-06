class_name Encampment
extends Node3D
## The opening scene: you wake by a lit campfire in a small tribal camp,
## two people sitting up with you ("You're finally awake. Be careful at
## night, don't let it get you...").
##
## Where: candidates() scores every blueprint cell for a pleasant first
## camp (low, mild, green land a couple of km from the coast; the old
## spawn rule) and keeps the best few, spread at least MIN_SEPARATION_M
## apart (geographic meters, so the dev postage stamp spreads them the
## same way). World.pick_spawn_dir() picks one of them at random each new
## game, and site_near() finds a flat, dry spot there for the fire.
## set_active() clears the camp of trees and undergrowth (VegetationPlacer
## reads `clearings` on its worker threads, so it's set before any chunk is
## computed).
##
## Layout, around the fire: the player's sleeping mat a few meters to one
## side, facing it; the two NPCs sitting in the fire circle on the seats
## the place supplies, the spare seat on the player's side (design 3 Oct
## §CY.2–CY.3, FireCircle), their hoods turning to the player when they're
## close. The fire's stones and logs and the seats collide (PropCollision);
## the flat mat doesn't. The two people have
## hitbox parts and a blocker (CreatureHitboxes): the player can't walk
## through them, and an arrow glances off them (Arrow, Camps.shot_at()).
## When one of them speaks (talk(), with the opening lines' subtitles) a
## wordless murmur comes from them.

const CANDIDATES := 12
const MIN_SEPARATION_M := 20000.0
const SEARCH_M := 500.0
const CLEARING_M := 12.0
## The river camp's old walls (§ED.1 ruin): stubs on a ring this far out
## (m), round the fire.
const RUIN_R_M := [10.5, 13.5]
const PLAYER_M := 3.3
const HIDE := Color(0.55, 0.4, 0.26)

## [dir, radius_m] circles kept free of plants (the active camp).
static var clearings: Array = []

var world: Node
var chunks: ChunkManager
var site := Vector3.UP
## The way of life the opening camp lives (Peoples.pick), and its store
## props (CampSim state "opening").
var people_id := ""
var woodpile: Node3D
var food_store: Node3D
var _store_t := 0.0
## Where the player wakes (surface direction).
var player_spot := Vector3.UP
## Dev: which side of the fire the player wakes on (radians; NAN = a
## random side). tools/dev_view.gd fixes it so the frame is the same
## every time (the folk stand across the fire from the player).
static var fixed_side := NAN
## The opening camp's two folk: their cloak families (CloakedFigure.FAMILIES:
## 0 ochres for the elder, 1 madder reds for the hunter).
const OPENING_FAMILIES := [0, 1]
var _fire: Node3D


## The camp's fire.
func fire() -> Node3D:
	return _fire
var _npcs: Array[Node3D] = []
var _time := 0.0
var _hitboxes_on := true
## Their voice when they speak (talk()): a wordless murmur, 3D at the
## speaker (Audio3D "camp_chatter").
var _voice: AudioStreamPlayer3D
## The camp's dressing node (the frame its props, folk and workshop sit
## in: the fire at the origin, y up).
var dressing: Node3D
## The workshop (design 5 Oct §EL, Workshop), once the camp is at the
## storage rung; its hearth props; the folk's day plan.
var workshop: Node3D
var hearth_props: Node3D
var _plan: Array = []
var _plan_t := 0.0
var _ruin_walls := false
var _trades_stamp := ""
## The player's pack (Main): where the camp's gift goes (§EJ.4).
var player_inventory: Inventory


## camps.json first_camp (design 1 Oct §CB): the first camp's kind rolls
## too. kinds: a set of biome keys and a water rule each; the common
## gates (fuel, temperature, slope, elevation, never); the roll's weights.
static var FC: Dictionary = Tuning.section("camps", "first_camp")
## The river camp (design 4 Oct §ED.1, first_camp.river_camp): the opening
## in a temperate band of the summer hemisphere, beside a river that runs
## on both ways. Set off for one roll when no kind has such a site
## (World.pick_spawn_site falls back to the plain rules).
static var river_off := false
static var _kind_cache := {}
static var _rivers_cache := {}


## The planet's river network, built once per planet (the chunk manager
## shares it).
static func rivers_for(map: PlanetData) -> RiverNetwork:
	var id := map.get_instance_id()
	if not _rivers_cache.has(id):
		_rivers_cache.clear()
		_rivers_cache[id] = RiverNetwork.new(map)
		# The nests (design 1 Oct §CK) read the planet and its rivers.
		Nests.setup(map, _rivers_cache[id])
		# The delves under the barrows (design 1 Oct §CJ).
		Delves.setup_world(map, _rivers_cache[id])
		# The one-of-a-kind places (§CL): found once, before any chunk.
		Uniques.sacred_fig(map)
	return _rivers_cache[id]


## The best first-camp cells per kind (first_camp.kinds): kind ->
## directions, best first, at least min_separation_m apart, at most
## candidates_per_kind. A cell qualifies for a kind when its biome is in
## the kind's biomes and it lies within within_m of the kind's water
## (river / sea / lake / water: any), and it passes the common gates:
## the biome offers fuel (fuel.json), a mean inside temp_c, slope under
## slope_max, elevation inside elevation_m, no water on the cell, not in
## never. Within a kind the score is the old one minus the latitude term:
## closeness to its water, moisture, a mild mean, level ground.
static func candidates_by_kind(map: PlanetData) -> Dictionary:
	var id := [map.get_instance_id(), river_rule().is_empty()]
	if _kind_cache.has(id):
		return _kind_cache[id]
	_kind_cache.clear()
	var kinds: Dictionary = FC.get("kinds", {})
	var never := PackedStringArray(FC.get("never", []))
	var temp: Array = FC.get("temp_c", [-4, 31])
	var elev: Array = FC.get("elevation_m", [5, 400])
	var slope_max := float(FC.get("slope_max", 0.15))
	var needs_fuel := bool(FC.get("needs_fuel", true))
	var fuel: Dictionary = Tuning.section("fuel", "biomes")
	var rivers := rivers_for(map)
	var per := int(FC.get("candidates_per_kind", 6))
	var sep := float(FC.get("min_separation_m", MIN_SEPARATION_M))
	var kind_biomes := {}
	var scored := {}
	var rc := river_rule()
	for k in kinds:
		var ids := PackedInt32Array()
		for key in (kinds[k] as Dictionary).get("biomes", []):
			var bid := BiomeTemplates.id_of_key(str(key))
			if bid >= 0:
				ids.append(bid)
		kind_biomes[k] = ids
		scored[k] = []
	for c in map.cell_count:
		if map.water[c] != PlanetData.Water.NONE:
			continue
		var bid: int = map.biome[c]
		var key: String = BiomeTemplates.KEYS[bid] if bid >= 0 and bid < BiomeTemplates.KEYS.size() else ""
		if never.has(key):
			continue
		var e := map.elevation[c]
		if e < float(elev[0]) * PlanetConst.HEIGHT_SCALE or e > float(elev[1]) * PlanetConst.HEIGHT_SCALE:
			continue
		if map.temp_c[c] < float(temp[0]) or map.temp_c[c] > float(temp[1]):
			continue
		if map.slope[c] > slope_max:
			continue
		if needs_fuel and not _offers_fuel(fuel, key):
			continue
		if not rc.is_empty() and not in_river_band(map.dir[c], rc):
			continue
		for k in kinds:
			if not (kind_biomes[k] as PackedInt32Array).has(bid):
				continue
			var rule: Dictionary = kinds[k]
			var within := float(rule.get("within_m", 1500.0))
			var near_k := str(rule.get("near", "water"))
			if not rc.is_empty():
				# The river camp (§ED.1): every kind by a river.
				near_k = "river"
				within = float(rc.get("within_m", 140.0))
			var wd := water_m(map, rivers, c, near_k)
			if wd > within:
				continue
			var score := -wd / within * 2.0 + map.moisture[c] * 3.0 - absf(map.temp_c[c] - 19.0) * 0.25 - map.slope[c] * 20.0
			(scored[k] as Array).append([score, c])
	var out := {}
	for k in kinds:
		var list: Array = scored[k]
		list.sort_custom(func(a, b): return a[0] > b[0])
		var cells := PackedVector3Array()
		for sc in list:
			var d: Vector3 = map.dir[sc[1]]
			var ok := true
			for o in cells:
				if CubeSphere.geo_distance_m(o, d) < sep:
					ok = false
					break
			if ok:
				cells.append(d)
				if cells.size() >= per:
					break
		out[k] = cells
	_kind_cache[id] = out
	return out


## The river camp's rule (first_camp.river_camp, §ED.1), {} when it is off.
static func river_rule() -> Dictionary:
	var rc: Dictionary = FC.get("river_camp", {})
	return rc if bool(rc.get("on", false)) and not river_off else {}


## +1 when the northern hemisphere is in spring or summer on day one (the
## sun over the north side of the equator, World.START_DAYS), -1 for the
## southern; at an equinox, the side the sun is moving into.
static func summer_sign() -> float:
	var days: float = load("res://scripts/core/world.gd").START_DAYS
	var dec := Astro.declination(days)
	if absf(dec) < 0.002:
		dec = Astro.declination(days + 5.0) - dec
	return 1.0 if dec >= 0.0 else -1.0


## Is `d` in the river camp's temperate band of the summer hemisphere?
static func in_river_band(d: Vector3, rc: Dictionary) -> bool:
	var lat := rad_to_deg(CubeSphere.latitude(d))
	var band: Array = rc.get("lat_deg", [28.0, 52.0])
	return lat * summer_sign() >= float(band[0]) and lat * summer_sign() <= float(band[1])


## How far the river runs on from segment `s`, upstream and downstream
## (m, each capped at `cap`).
static func river_runs(rivers: RiverNetwork, s: int, cap: float) -> Vector2:
	var down := float(rivers.to_end_m[s])
	var up := 0.0
	var k := rivers.up_seg[s]
	var guard := 0
	while k >= 0 and up < cap and guard < 400:
		up += CubeSphere.surface_distance_m(rivers.a[k], rivers.b[k])
		k = rivers.up_seg[k]
		guard += 1
	return Vector2(minf(up, cap), minf(down, cap))


## Does the fuel table give this biome anything to burn?
static func _offers_fuel(fuel: Dictionary, key: String) -> bool:
	var b = fuel.get(key, {})
	if not b is Dictionary:
		return false
	for kind in b:
		if float(b[kind]) > 0.0:
			return true
	return false


## Real metres from cell `c` to the kind's water: "river" (the river
## network's segments round the cell), "sea" (the coast distance), "lake"
## (the nearest lake cell, to its edge), "water" (the nearest of them).
##
## Judged from the cell's NEAREST point, not its centre (design 1 Oct, the
## roads pass): on the full planet a cell is ~10 km across, so a centre
## 4 km from a river may still hold a fire 300 m from it. The fire itself
## is placed within within_m of real water by fire_site() afterwards.
static func water_m(map: PlanetData, rivers: RiverNetwork, c: int, near: String) -> float:
	var d: Vector3 = map.dir[c]
	var half := half_diag_m(map)
	var best := INF
	if near == "river" or near == "water":
		for s in rivers.segments_near(map, c):
			best = minf(best, maxf(0.0, rivers.closest_dt(s, d).x - half))
	if near == "sea" or near == "water":
		best = minf(best, maxf(0.0, map.coast_dist_km[c] * 1000.0 * PlanetConst.GEO_SCALE - half))
	if near == "lake" or near == "water":
		var cell_m := PlanetConst.CIRCUMFERENCE_M / (4.0 * map.res)
		var ring := [c]
		var seen := {c: true}
		for depth in 2:
			var next := []
			for cc in ring:
				for k in 8:
					var n := map.neighbors[cc * 8 + k]
					if n < 0 or seen.has(n):
						continue
					seen[n] = true
					next.append(n)
					if map.water[n] == PlanetData.Water.LAKE:
						best = minf(best, maxf(0.0, CubeSphere.surface_distance_m(d, map.dir[n]) - 0.5 * cell_m - half))
			ring = next
	return best


## Half a blueprint cell's diagonal (real m): how far a cell's nearest
## point can lie from its centre.
static func half_diag_m(map: PlanetData) -> float:
	return map.cell_m() * 0.7072


## Where the fire goes for a first camp of `kind` near cell direction `d`
## (design 1 Oct, the roads pass): a level, dry spot inside one of the
## kind's biomes, within within_m of the kind's real water — a point on a
## river near the cell (its polyline), or the shore of the sea or a lake
## found by walking the terrain out from the cell — never in the water.
## Vector3.ZERO when the cell has no such spot (the kind tries its next
## candidate, then the roll another kind).
static func fire_site(map: PlanetData, rivers: RiverNetwork, d: Vector3, kind: String) -> Vector3:
	var rule: Dictionary = (FC.get("kinds", {}) as Dictionary).get(kind, {})
	var near := str(rule.get("near", "water"))
	var within := float(rule.get("within_m", 1500.0))
	var rc := river_rule()
	var flow := 0.0
	if not rc.is_empty():
		# The river camp (§ED.1): by a river that runs on both ways.
		near = "river"
		within = float(rc.get("within_m", 140.0))
		flow = float(rc.get("flow_m", 2500.0))
	var ids := PackedInt32Array()
	for key in rule.get("biomes", []):
		var bid := BiomeTemplates.id_of_key(str(key))
		if bid >= 0:
			ids.append(bid)
	var reach := half_diag_m(map) + within
	# The water points: [dir, keep-off m] (a river's half width; a shore 0).
	var wet: Array = []
	var c0 := map.cell_at(d)
	if near == "river" or near == "water":
		for s in rivers.segments_near(map, c0):
			if flow > 0.0:
				var runs := river_runs(rivers, s, flow)
				if runs.x < flow or runs.y < flow:
					continue
			var a: Vector3 = rivers.a[s]
			var b: Vector3 = rivers.b[s]
			var seg_m := CubeSphere.surface_distance_m(a, b)
			var steps := maxi(1, int(seg_m / 250.0))
			for k in steps + 1:
				var w := a.slerp(b, float(k) / steps)
				if CubeSphere.surface_distance_m(w, d) <= reach:
					wet.append([w, rivers.width[s] * 0.5])
	if near == "sea" or near == "lake" or near == "water":
		var step := maxf(60.0, reach / 60.0)
		for k in 24:
			var a := k * TAU / 24.0
			var prev := d
			var m := step
			while m <= reach:
				var q := CreatureSpawner._offset(d, a, m)
				if _standing_water(map, q, near):
					wet.append([prev, 0.0])
					break
				prev = q
				m += step
	if wet.is_empty():
		return Vector3.ZERO
	# Thin the water points to a few dozen, evenly.
	var stride := maxi(1, wet.size() / 40)
	var best := Vector3.ZERO
	var best_score := INF
	var tried := 0
	for i in range(0, wet.size(), stride):
		var w: Vector3 = wet[i][0]
		var keep_off: float = wet[i][1] + 25.0
		for ring in [0.15, 0.4, 0.75]:
			var r := maxf(keep_off, within * ring)
			for j in 6:
				var p := CreatureSpawner._offset(w, j * TAU / 6.0 + i * 0.7, r)
				tried += 1
				var cell := map.cell_at(p)
				if map.water[cell] != PlanetData.Water.NONE or map.biome[cell] in TerrainChunk.WETLANDS:
					continue
				# The river camp (§ED.1) stands on any usable land by its river
				# (the bank's own biome, not the cell's kind), never in a biome
				# first_camp.never bars.
				if flow > 0.0:
					var bk: String = BiomeTemplates.KEYS[map.biome[cell]] if map.biome[cell] >= 0 and map.biome[cell] < BiomeTemplates.KEYS.size() else ""
					if (FC.get("never", []) as Array).has(bk):
						continue
				elif not ids.has(map.biome[cell]):
					continue
				if _standing_water(map, p, "water"):
					continue
				var e := map.terrain.elevation(p, true)
				if e < 2.5:
					continue
				if near == "river" or near == "water":
					var too_close := false
					for s in rivers.segments_near(map, cell):
						if rivers.closest_dt(s, p).x < rivers.width[s] * 0.5 + 20.0:
							too_close = true
							break
					if too_close:
						continue
				var bump := 0.0
				for jj in 8:
					var q := CreatureSpawner._offset(p, jj * TAU / 8.0, PLAYER_M + 1.5)
					bump = maxf(bump, absf(map.terrain.elevation(q, true) - e))
				# Level first; then nearer the water's comfortable middle.
				var score := bump + absf(r - within * 0.4) / within * 0.3
				if score < best_score:
					best_score = score
					best = p
	return best if best_score < 1.5 else Vector3.ZERO


## Standing water at `p`: the sea (below sea level on an ocean cell or the
## coast) or a lake (below its level); `near` "sea", "lake" or "water".
static func _standing_water(map: PlanetData, p: Vector3, near: String) -> bool:
	var cell := map.cell_at(p)
	var e := map.terrain.elevation(p, false)
	if (near == "sea" or near == "water") and (map.water[cell] == PlanetData.Water.OCEAN or e < PlanetConst.SEA_LEVEL_M + 0.5):
		return true
	if (near == "lake" or near == "water") and map.water[cell] == PlanetData.Water.LAKE and e < map.water_level[cell] + 0.5:
		return true
	return false


## The best first-camp cells of the planet, spread apart (directions): the
## old single list (the dev frame's seed 42 / spawn 0, and spawn_choice).
static func candidates(map: PlanetData) -> PackedVector3Array:
	var scored: Array = []
	for c in map.cell_count:
		if map.water[c] != PlanetData.Water.NONE:
			continue
		var e := map.elevation[c]
		if e < 5.0 * PlanetConst.HEIGHT_SCALE or e > 400.0 * PlanetConst.HEIGHT_SCALE:
			continue
		if map.biome[c] in TerrainChunk.WETLANDS:
			continue
		var score := -absf(map.coast_dist_km[c] - 2.0) - absf(rad_to_deg(map.lat[c]) - 20.0) * 0.1
		score += map.moisture[c] * 3.0
		# Mild and green: where the most day-active wildlife lives.
		score -= absf(map.temp_c[c] - 19.0) * 0.25
		if map.slope[c] > 0.15:
			score -= 5.0
		scored.append([score, c])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out := PackedVector3Array()
	for s in scored:
		var d: Vector3 = map.dir[s[1]]
		var ok := true
		for o in out:
			if CubeSphere.geo_distance_m(o, d) < MIN_SEPARATION_M:
				ok = false
				break
		if ok:
			out.append(d)
			if out.size() >= CANDIDATES:
				break
	return out


## A flat, dry spot for the fire near `d`: away from water, rivers and
## wetland pools, on ground that's level across the camp.
static func site_near(map: PlanetData, d: Vector3) -> Vector3:
	var best := d
	var best_score := INF
	var home: int = map.biome[map.cell_at(d)]
	for k in 160:
		var p := d if k == 0 else CreatureSpawner._offset(d, k * 2.399963, sqrt(float(k) / 160.0) * SEARCH_M)
		var cell := map.cell_at(p)
		if map.water[cell] != PlanetData.Water.NONE or map.biome[cell] in TerrainChunk.WETLANDS:
			continue
		# The camp stays in the biome its kind rolled (design §CB).
		if map.biome[cell] != home:
			continue
		if map.sample(map.water_dist_km, p) < 0.3 * map.cell_scale():
			continue
		var e := map.terrain.elevation(p, true)
		if e < 2.5:
			continue
		var bump := 0.0
		for j in 8:
			var q := CreatureSpawner._offset(p, j * TAU / 8.0, PLAYER_M + 1.5)
			bump = maxf(bump, absf(map.terrain.elevation(q, true) - e))
		if bump < best_score:
			best_score = bump
			best = p
			if bump < 0.25:
				break
	return best


## Make `site` the camp: plants keep clear of it.
static func set_active(p_site: Vector3) -> void:
	# The river camp's broken walls (§ED.1) stand a little further out.
	clearings = [[p_site, CLEARING_M + (RUIN_R_M[1] + 2.0 - CLEARING_M if bool(river_rule().get("ruin", false)) else 0.0)]]


## Clearings within `radius` m of `d`.
static func clearings_near(d: Vector3, radius: float) -> Array:
	var out: Array = []
	for c in clearings:
		if CubeSphere.surface_distance_m(c[0], d) < radius + c[1]:
			out.append(c)
	return out


## Build the camp at `p_site` (chunks around it must be loaded).
func build(p_world: Node, p_chunks: ChunkManager, p_site: Vector3) -> void:
	world = p_world
	chunks = p_chunks
	site = p_site
	name = "Encampment"
	_fire = Campfire.build(self, world, chunks, site, false)
	_fire.set_meta("hearth_ok", true)
	# Its smoke goes up (design 3 Oct §CV, Smoke).
	_fire.set_meta("smoke", 1.0)
	# The people who found you (design 30 Sept §BO): the life this site
	# lives, its shelter and props round the fire (CampProps).
	people_id = Peoples.pick(world.planet, chunks.rivers, site, "opening")
	var people := Peoples.get_people(people_id)
	var biome_key := FireStore.biome_key(world, site)
	var ppal := Peoples.palette(people, biome_key)
	var drng := RandomNumberGenerator.new()
	drng.seed = hash([site, "dress"])
	var dress := Node3D.new()
	dress.name = "Dressing"
	add_child(dress)
	dressing = dress
	dress.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(site), site), _fire.global_position)
	var dbody := PropCollision.body(dress)
	var shelter := CampProps.shelter(dress, people, ppal, drng, dbody)
	var sa := drng.randf() * TAU
	shelter.position = Vector3(cos(sa), 0, sin(sa)) * 9.0
	shelter.basis = Basis.looking_at(-shelter.position.normalized(), Vector3.UP)
	if CampSim.instance != null:
		var st := CampSim.instance.ensure("opening", site, people_id, biome_key, hash([site, "opening"]))
		var wp := CampProps.woodpile(dress, float(st.wood), dbody)
		wp.position = Vector3(cos(sa + 1.3), 0, sin(sa + 1.3)) * 4.0
		wp.basis = Basis.looking_at(-wp.position.normalized(), Vector3.UP)
		var fs := CampProps.food_store(dress, float(st.food), ppal, dbody)
		fs.position = Vector3(cos(sa - 1.3), 0, sin(sa - 1.3)) * 4.2
		fs.basis = Basis.looking_at(-fs.position.normalized(), Vector3.UP)
		woodpile = wp
		food_store = fs
	# The camp book by the hearth (design 4 Oct §ED.3).
	var brng := RandomNumberGenerator.new()
	brng.seed = hash([site, "camp_book"])
	CampBook.place(dress, world, chunks, "opening", brng, 4.4)
	var props: Array = (people.get("aesthetic", {}) as Dictionary).get("props", [])
	for i in mini(3, props.size()):
		var s := str(props[i]).to_lower()
		if s.find("ladder") >= 0 or s.find("bridge") >= 0 or s.find("hearth box") >= 0:
			continue
		var n := CampProps.prop(dress, str(props[i]), ppal, drng, dbody)
		var a := sa + TAU * (i + 1) / 4.0
		n.position = Vector3(cos(a), 0, sin(a)) * drng.randf_range(5.0, 6.5)
		n.basis = Basis.looking_at(-n.position.normalized(), Vector3.UP)
	# The player's side of the fire, and the two NPCs across it.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var side := rng.randf() * TAU
	if not is_nan(fixed_side):
		side = fixed_side
	player_spot = CreatureSpawner._offset(site, side, PLAYER_M)
	_mat(player_spot)
	# The elder and the hunter: cloaked figures on the player's own rig
	# (CloakedFigure), the elder in ochre yellow, the hunter in madder red
	# (the designer's pick, every game), sitting in the fire circle (design
	# 3 Oct §CY.2–CY.3, FireCircle) on the seats the place supplies, the
	# spare seat on the player's side.
	# The river camp (§ED.1) sits 4-5 at its hearth: the elder and the
	# hunter, then others of the camp.
	var rc := river_rule()
	var folk_n := 2
	if not rc.is_empty():
		var fr: Array = rc.get("folk", [4, 5])
		var frng := RandomNumberGenerator.new()
		frng.seed = hash([site, "folk_n"])
		folk_n = frng.randi_range(int(fr[0]), int(fr[1]))
		if bool(rc.get("ruin", false)):
			_old_walls(dress, dbody, frng)
			_ruin_walls = true
	var names := ["Elder", "Hunter", "Gatherer", "Mender", "Youngster"]
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([site, "folk"])
	var to_player := dress.to_local(world.to_scene(player_spot, PlanetConst.RADIUS_M + chunks.ground_height(player_spot)))
	var ch := chunks.chunk_at(site)
	var seats := FireCircle.lay_seats(dress, folk_n, prng, {"biome": biome_key, "people": people_id, "site": "",
		"bark": FireCircle.stand_bark(chunks, _fire.global_position), "stones": CreatureSpawner.den_stones(world.planet.rock[world.planet.cell_at(site)]),
		"ground": ch.ground_color_at(site) if ch != null else Color(0.35, 0.42, 0.22),
		"cloth": ppal[0] if not ppal.is_empty() else HIDE, "spare_at": atan2(to_player.z, to_player.x)}, dbody)
	for i in mini(folk_n, seats.size()):
		var fam: int = OPENING_FAMILIES[i] if i < OPENING_FAMILIES.size() else prng.randi() % CloakedFigure.FAMILIES.size()
		var pal := CloakedFigure.roll_palette(prng, fam, i < OPENING_FAMILIES.size())
		var height := 1.66 if i == 0 else (1.74 if i == 1 else (1.38 if i == 4 else prng.randf_range(1.58, 1.76)))
		var holder := Node3D.new()
		holder.name = names[i]
		dress.add_child(holder)
		var b := CloakedFigure.build(height, pal[0], pal[1], true)
		var body: Node3D = b.root
		body.name = "Body"
		holder.add_child(body)
		holder.set_meta("speaker", names[i])
		holder.set_meta("hitboxes", CloakedFigure.hitboxes(holder, b, true))
		holder.set_meta("arms", b.wings)
		holder.set_meta("head", (body as PlayerBody).head)
		holder.set_meta("stage", "child" if i == 4 else "adult")
		holder.set_meta("phase", prng.randf() * TAU)
		BlobShadow.make(holder, 0.35, 0.35)
		FireCircle.sit(holder, seats[i])
		holder.set_meta("dir", world.dir_of(holder.global_position))
		# Its place in the circle, and whose day it lives (§EL): the
		# camp's folk in order; the youngster stays by the fire.
		holder.set_meta("folk_i", -1 if i == 4 else i)
		Workshop.remember_home(holder)
		_npcs.append(holder)
	_voice = Audio3D.make("camp_chatter", self, "Chatter")
	_voice.volume_db = -8.0
	for i in 2:
		SoundSynth.stream("murmur_one", i)


## The river camp's ruin (§ED.1): the hearth restored inside what is left
## of an old building's walls, stubs of dressed stone on a ring round the
## fire with gaps between (the way in, the way to the water), a few blocks
## fallen beside them. Each stub sits on its own ground.
func _old_walls(dress: Node3D, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var stone := Color(0.46, 0.45, 0.42)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := rng.randf() * TAU
	var placed := 0.0
	while placed < TAU - 0.4:
		var r := rng.randf_range(float(RUIN_R_M[0]), float(RUIN_R_M[1]))
		var len_m := rng.randf_range(2.0, 5.5)
		var arc := len_m / r
		var gap := rng.randf_range(0.25, 0.8)
		var mid := start + placed + arc * 0.5
		placed += arc + gap
		if placed > TAU - 0.2:
			break
		var d := CreatureSpawner._offset(site, mid, r)
		var at := dress.to_local(world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d)))
		var d2 := CreatureSpawner._offset(site, mid + 0.02, r)
		var along := dress.to_local(world.to_scene(d2, PlanetConst.RADIUS_M + chunks.ground_height(d2))) - at
		var yaw := atan2(-along.z, along.x) + rng.randf_range(-0.08, 0.08)
		var h := rng.randf_range(0.5, 2.3)
		var t := rng.randf_range(0.6, 0.8)
		# Sunk 0.4 m, so the stub stands on the slope with no gap under it.
		var xf := Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, h * 0.5 - 0.2, 0))
		var size := Vector3(len_m, h + 0.4, t)
		RoadProps.stone_box(st, xf, size, stone.darkened(rng.randf() * 0.18), rng.randf_range(0.15, 0.5))
		PropCollision.box(body, xf, size)
		# A capstone on the taller ones, and a block fallen at its foot.
		if h > 1.4:
			RoadProps.stone_box(st, xf * Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.3, 0.3), size.y * 0.5 + 0.11, 0)), Vector3(len_m * 0.6, 0.22, t + 0.12), stone.lightened(0.05), 0.5)
		if rng.randf() < 0.6:
			var fd := CreatureSpawner._offset(d, mid + rng.randf_range(-0.2, 0.2), rng.randf_range(1.2, 2.2))
			var fat := dress.to_local(world.to_scene(fd, PlanetConst.RADIUS_M + chunks.ground_height(fd)))
			var bxf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))), fat + Vector3(0, 0.15, 0))
			RoadProps.stone_box(st, bxf, Vector3(0.9, 0.45, 0.6), stone.darkened(0.12), 0.4)
			PropCollision.box(body, bxf, Vector3(0.9, 0.45, 0.6))
	var mi := MeshInstance3D.new()
	mi.name = "OldWalls"
	mi.mesh = st.commit()
	mi.material_override = RuinBuilder.material()
	dress.add_child(mi)


## One of the two (0 the elder, 1 the hunter) speaks `delay` seconds from
## now: a murmur from them while the caller's subtitle shows.
func talk(who: int, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(_voice) or who >= _npcs.size():
			return
		var n := _npcs[who]
		_voice.global_position = n.global_position + (n.get_meta("dir") as Vector3) * 1.4
		_voice.stream = SoundSynth.stream("murmur_one", who)
		Audio3D.play(_voice))


## Per frame: the fire flickers; the two sit in the fire circle, passing
## the time in its loops, their hoods turning to the player close by
## (FireCircle).
func update_camp(delta: float, player_pos: Vector3) -> void:
	_store_t -= delta
	if _store_t <= 0.0 and CampSim.instance != null and woodpile != null:
		_store_t = 1.5
		var st := CampSim.instance.state_of("opening")
		if not st.is_empty():
			if absf(float(woodpile.get_meta("units", -1.0)) - float(st.wood)) >= 0.5:
				CampProps.refresh_woodpile(woodpile, float(st.wood))
	_time += delta
	Campfire.flicker(_fire, _time)
	# The opening camp has no workshop in play (Mike, 5 Oct); the
	# harness builds one for its frames (ensure_workshop). What every camp
	# does every day (§EI.1, CampNeeds).
	if _store_t >= 1.49 and CampSim.instance != null:
		var stw := CampSim.instance.state_of("opening")
		CampNeeds.live(dressing, stw, _needs_ctx(player_pos))
	if dressing != null:
		CampNeeds.tick(dressing, delta, dressing.get_node_or_null("Shelter"), _ground_fn(), _shelter_material(), Peoples.palette(Peoples.get_people(people_id), FireStore.biome_key(world, site)))
	# Their hitboxes only while someone's near (Hitboxes.wanted_at()).
	var want := Hitboxes.wanted_at(_fire.global_position, player_pos)
	if want != _hitboxes_on:
		_hitboxes_on = want
		for n in _npcs:
			Hitboxes.set_active(n.get_meta("hitboxes", []), want)
	# The fire circle's loops and the hood's notice (§CY.2, FireCircle).
	var ctx := {"food_ok": true, "fire_low": false}
	if CampSim.instance != null:
		var st2 := CampSim.instance.state_of("opening")
		if not st2.is_empty():
			ctx.food_ok = float(st2.get("food", 0.0)) > 0.0
	var fst := FireStore.store_of(_fire)
	if not fst.is_empty():
		ctx.fire_low = FireStore.units_now(fst) < float((CampSim.SIM.get("store", {}) as Dictionary).get("feed_fire_below_units", 3.0))
		ctx["fire_out"] = str(fst.get("state", "")) in ["out", "embers"]
	var phase := FireCircle.phase_name(world.local_clock(site).y, CubeSphere.latitude(site), world.days)
	var circle: Array = _npcs
	if workshop != null and is_instance_valid(workshop) and CampSim.instance != null:
		# By day the benches and the porch, at dusk the circle (§EL.2).
		var st3 := CampSim.instance.state_of("opening")
		_plan_t -= delta
		if _plan_t <= 0.0 or _plan.is_empty():
			_plan_t = 1.0
			_plan = Workshop.plan_now(st3, world.days)
		Workshop.drive(_npcs, workshop, _plan, delta, _time, player_pos, player_pos.distance_to(_fire.global_position) > float((CampSim.SIM.get("jobs", {}) as Dictionary).get("near_player_m", 120.0)))
		circle = Workshop.fire_sitters(_npcs)
		Workshop.tick(workshop, hearth_props, phase == "dusk" or phase == "night", Workshop.potter_working(st3, _plan))
	# The meal and the gift (§EJ, Sharing): the store's pieces, the
	# carrier, the bowls, the gift walked up to you.
	if CampSim.instance != null and food_store != null and dressing != null:
		var st4 := CampSim.instance.state_of("opening")
		if not st4.is_empty():
			dressing.set_meta("key", "opening")
			circle = Sharing.live(dressing, st4, circle, food_store, world.days, CampSim.instance.clock_h(st4, world.days), _time, delta, player_pos, player_inventory)
			var shown := Sharing.shown(dressing, st4)
			if int(food_store.get_meta("pieces", -1)) != shown:
				CampProps.show_food_pieces(food_store, shown)
	FireCircle.animate(circle, _fire, _time, delta, player_pos, phase, ctx)


## Free the workshop (its kiln, its hearth props) to be built again with
## the camp's trades (§EI); the folk walk back to the fire first.
func rebuild_workshop() -> void:
	for n in _npcs:
		if is_instance_valid(n) and n.has_meta("home"):
			n.transform = n.get_meta("home")
			n.visible = true
			n.set_meta("station", "fire")
			n.set_meta("going", "")
			n.set_meta("seat_key", "")
			Workshop._stand(n, false)
	if workshop != null and workshop.has_meta("kiln") and is_instance_valid(workshop.get_meta("kiln")):
		(workshop.get_meta("kiln") as Node).queue_free()
	if workshop != null:
		workshop.queue_free()
	if hearth_props != null:
		hearth_props.queue_free()
	workshop = null
	hearth_props = null


func _needs_ctx(player_pos: Vector3) -> Dictionary:
	var avoid: Array = [[Vector3.ZERO, 2.4]]
	for c in dressing.get_children():
		if c is Node3D:
			var p: Vector3 = (c as Node3D).position
			if Vector2(p.x, p.z).length() > 2.6 and Vector2(p.x, p.z).length() < 6.0:
				avoid.append([Vector3(p.x, 0, p.z), 1.0])
	var pm: Vector3 = dressing.to_local(world.to_scene(player_spot, PlanetConst.RADIUS_M + chunks.ground_height(player_spot)))
	avoid.append([Vector3(pm.x, 0, pm.z), 1.2])
	return {"d": site, "world": world, "chunks": chunks, "shelter": dressing.get_node_or_null("Shelter"), "ground": _ground_fn(),
		"near": player_pos.distance_to(_fire.global_position) < float((CampSim.SIM.get("jobs", {}) as Dictionary).get("near_player_m", 120.0)),
		"pal": Peoples.palette(Peoples.get_people(people_id), FireStore.biome_key(world, site)), "height": 1.7, "avoid": avoid, "material": _shelter_material()}


func _ground_fn() -> Callable:
	var dn := dressing
	return func(p: Vector3) -> float:
		var g: Vector3 = world.dir_of(dn.to_global(p))
		return dn.to_local(world.to_scene(g, PlanetConst.RADIUS_M + chunks.ground_height(g))).y


func _shelter_material() -> String:
	var mats: Array = (Peoples.get_people(people_id).get("shelter", {}) as Dictionary).get("materials", [])
	return str(mats[0]) if not mats.is_empty() else "thatch"


## The workshop at the opening camp (§EL), for the harness only (the
## walkabout's frames, the checks): the opening camp has none in play
## (Mike, 5 Oct). Its state must be at the storage rung; `ok` false waits. Inside the old
## walls' ring where the camp is a ruin (§ED.1).
func ensure_workshop(ok: bool) -> void:
	if workshop != null or not ok or CampSim.instance == null or dressing == null:
		return
	var st := CampSim.instance.state_of("opening")
	if not Workshop.wanted(st):
		return
	var people := Peoples.get_people(people_id)
	var ppal := Peoples.palette(people, FireStore.biome_key(world, site))
	var wrng := RandomNumberGenerator.new()
	wrng.seed = hash([site, "workshop"])
	var avoid: Array = [[Vector3.ZERO, 2.9]]
	for c in dressing.get_children():
		if not c is Node3D:
			continue
		var p: Vector3 = (c as Node3D).position
		var r := Vector2(p.x, p.z).length()
		if r < 3.0 or r > 18.0:
			continue
		avoid.append([Vector3(p.x, 0, p.z), 3.4 if str(c.name).begins_with("Shelter") else 1.0])
	# The player's mat.
	var pm: Vector3 = dressing.to_local(world.to_scene(player_spot, PlanetConst.RADIUS_M + chunks.ground_height(player_spot)))
	avoid.append([Vector3(pm.x, 0, pm.z), 1.2])
	var dn := dressing
	var ctx := {"avoid": avoid, "wind": dressing.global_basis.inverse() * world.planet.wind_avg[world.planet.cell_at(site)], "key": "opening", "st": st,
		"r": [6.0, 8.0] if _ruin_walls else [6.0, 10.0], "kiln_r_max": 9.5 if _ruin_walls else 1.0e9,
		"ground": func(p: Vector3) -> float:
			var g: Vector3 = world.dir_of(dn.to_global(p))
			return dn.to_local(world.to_scene(g, PlanetConst.RADIUS_M + chunks.ground_height(g))).y}
	workshop = Workshop.build(dressing, people, ppal, wrng, ctx)
	Workshop.restore(workshop, st)
	var hav: Array = avoid.duplicate()
	hav.append([Vector3(workshop.position.x, 0, workshop.position.z), Workshop.HUT_HALF + 0.5])
	if workshop.has_meta("kiln"):
		var kp: Vector3 = (workshop.get_meta("kiln") as Node3D).position
		hav.append([Vector3(kp.x, 0, kp.z), 1.8])
	hearth_props = Workshop.hearth_props(dressing, people, ppal, wrng, hav, 3.2, Trades.visible_for(st, "hearth"))
	if hearth_props.has_meta("seat"):
		(workshop.get_meta("seats") as Dictionary)["hearth"] = [hearth_props.get_meta("seat")]
	_trades_stamp = ",".join(PackedStringArray(st.get("trades", [])))


static func _tangent(from: Vector3, to: Vector3) -> Vector3:
	var t := to - from * from.dot(to)
	return t.normalized() if t.length() > 1e-9 else CubeSphere.north(from)


## A hide sleeping mat where the player wakes.
func _mat(at: Vector3) -> void:
	var mat := CreatureBodies.box(self, Vector3(0.95, 0.05, 1.9), Vector3.ZERO, HIDE)
	mat.global_position = world.to_scene(at, PlanetConst.RADIUS_M + chunks.ground_height(at) + 0.03)
	mat.global_basis = Basis.looking_at(_tangent(at, site), at)
