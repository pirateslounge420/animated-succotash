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
## side, facing it; the two NPCs across the fire, turning toward the
## player when they're close. The fire's stones and logs and the two seat
## logs collide (PropCollision); the flat mat doesn't. The two people have
## hitbox parts and a blocker (CreatureHitboxes): the player can't walk
## through them, and an arrow glances off them (Arrow, Camps.shot_at()).
## When one of them speaks (talk(), with the opening lines' subtitles) a
## wordless murmur comes from them.

const CANDIDATES := 12
const MIN_SEPARATION_M := 20000.0
const SEARCH_M := 500.0
const CLEARING_M := 12.0
const PLAYER_M := 3.3
const NPC_M := 2.3
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


## camps.json first_camp (design 1 Oct §CB): the first camp's kind rolls
## too. kinds: a set of biome keys and a water rule each; the common
## gates (fuel, temperature, slope, elevation, never); the roll's weights.
static var FC: Dictionary = Tuning.section("camps", "first_camp")
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
	var id := map.get_instance_id()
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
		for k in kinds:
			if not (kind_biomes[k] as PackedInt32Array).has(bid):
				continue
			var rule: Dictionary = kinds[k]
			var within := float(rule.get("within_m", 1500.0))
			var wd := water_m(map, rivers, c, str(rule.get("near", "water")))
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
				if not ids.has(map.biome[cell]):
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
	clearings = [[p_site, CLEARING_M]]


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
	# (CloakedFigure), standing by the fire: the elder in ochre yellow, the
	# hunter in madder red (the designer's pick, every game).
	var names := ["Elder", "Hunter"]
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([site, "folk"])
	for i in 2:
		var pal := CloakedFigure.roll_palette(prng, OPENING_FAMILIES[i], true)
		var height := 1.66 if i == 0 else 1.74
		# An unscaled holder turns; the scaled body under it breathes.
		var holder := Node3D.new()
		holder.name = names[i]
		add_child(holder)
		var b := CloakedFigure.build(height, pal[0], pal[1])
		var body: Node3D = b.root
		body.name = "Body"
		holder.add_child(body)
		holder.set_meta("speaker", names[i])
		holder.set_meta("hitboxes", CloakedFigure.hitboxes(holder, b, true))
		BlobShadow.make(holder, 0.35, 0.35)
		var at := CreatureSpawner._offset(site, side + PI + (0.75 if i == 0 else -0.75), NPC_M)
		holder.global_position = world.to_scene(at, PlanetConst.RADIUS_M + chunks.ground_height(at))
		holder.set_meta("dir", at)
		holder.set_meta("size", height / CloakedFigure.PLAYER_H)
		_face(holder, at, site, 1.0)
		_npcs.append(holder)
		# A log seat behind each.
		var seat_at := CreatureSpawner._offset(site, side + PI + (0.75 if i == 0 else -0.75), NPC_M + 0.7)
		var seat := CreatureBodies.cone(self, 0.16, 0.16, 1.2, Vector3.ZERO, Color(0.36, 0.25, 0.16))
		seat.global_position = world.to_scene(seat_at, PlanetConst.RADIUS_M + chunks.ground_height(seat_at) + 0.14)
		seat.global_basis = Basis.looking_at(_tangent(seat_at, site), seat_at) * Basis(Vector3(0, 0, 1), PI * 0.5)
		PropCollision.capsule(PropCollision.body(seat), Transform3D(), 0.16, 1.2)
	_voice = Audio3D.make("camp_chatter", self, "Chatter")
	_voice.volume_db = -8.0
	for i in 2:
		SoundSynth.stream("murmur_one", i)


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


## Per frame: the fire flickers; the NPCs breathe and turn to face the
## player when they're near, else the fire.
func update_camp(delta: float, player_pos: Vector3) -> void:
	_store_t -= delta
	if _store_t <= 0.0 and CampSim.instance != null and woodpile != null:
		_store_t = 1.5
		var st := CampSim.instance.state_of("opening")
		if not st.is_empty():
			if absf(float(woodpile.get_meta("units", -1.0)) - float(st.wood)) >= 0.5:
				CampProps.refresh_woodpile(woodpile, float(st.wood))
			if absf(float(food_store.get_meta("units", -1.0)) - float(st.food)) >= 1.0:
				CampProps.refresh_food_store(food_store, float(st.food))
	_time += delta
	Campfire.flicker(_fire, _time)
	var player_dir: Vector3 = world.dir_of(player_pos)
	# Their hitboxes only while someone's near (Hitboxes.wanted_at()).
	var want := Hitboxes.wanted_at(_fire.global_position, player_pos)
	if want != _hitboxes_on:
		_hitboxes_on = want
		for n in _npcs:
			Hitboxes.set_active(n.get_meta("hitboxes", []), want)
	for i in _npcs.size():
		var n := _npcs[i]
		var at: Vector3 = n.get_meta("dir")
		var near := CubeSphere.surface_distance_m(at, player_dir) < 14.0
		_face(n, at, player_dir if near else site, delta * 2.0)
		var breathe := 1.0 + 0.012 * sin(_time * 1.6 + i * 1.3)
		var size: float = n.get_meta("size")
		(n.get_node("Body") as Node3D).scale = Vector3(size, size * breathe, size)


func _face(n: Node3D, at: Vector3, toward: Vector3, rate: float) -> void:
	var fwd := _tangent(at, toward)
	var target := Basis.looking_at(fwd, at)
	n.global_basis = n.global_basis.orthonormalized().slerp(target, clampf(rate, 0.0, 1.0))


static func _tangent(from: Vector3, to: Vector3) -> Vector3:
	var t := to - from * from.dot(to)
	return t.normalized() if t.length() > 1e-9 else CubeSphere.north(from)


## A hide sleeping mat where the player wakes.
func _mat(at: Vector3) -> void:
	var mat := CreatureBodies.box(self, Vector3(0.95, 0.05, 1.9), Vector3.ZERO, HIDE)
	mat.global_position = world.to_scene(at, PlanetConst.RADIUS_M + chunks.ground_height(at) + 0.03)
	mat.global_basis = Basis.looking_at(_tangent(at, site), at)
