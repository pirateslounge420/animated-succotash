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
## Where the player wakes (surface direction).
var player_spot := Vector3.UP
var _fire: Node3D
var _npcs: Array[Node3D] = []
var _time := 0.0
var _hitboxes_on := true
## Their voice when they speak (talk()): a wordless murmur, 3D at the
## speaker (Audio3D "camp_chatter").
var _voice: AudioStreamPlayer3D


## The best first-camp cells of the planet, spread apart (directions).
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
	for k in 160:
		var p := d if k == 0 else CreatureSpawner._offset(d, k * 2.399963, sqrt(float(k) / 160.0) * SEARCH_M)
		var cell := map.cell_at(p)
		if map.water[cell] != PlanetData.Water.NONE or map.biome[cell] in TerrainChunk.WETLANDS:
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
	# The player's side of the fire, and the two NPCs across it.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var side := rng.randf() * TAU
	player_spot = CreatureSpawner._offset(site, side, PLAYER_M)
	_mat(player_spot)
	# The elder and the hunter: cloaked figures on the player's own rig
	# (CloakedFigure), in their tribe's colors, standing by the fire.
	var names := ["Elder", "Hunter"]
	var family := CloakedFigure.tribe_family(hash(site))
	var prng := RandomNumberGenerator.new()
	prng.seed = hash([site, "folk"])
	for i in 2:
		var pal := CloakedFigure.roll_palette(prng, family)
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
