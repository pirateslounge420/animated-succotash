class_name LeafSeason
extends Node3D
## The season on the trees (design §AI 1; numbers in data/litter.json
## "fall"): deciduous crowns (tint.drop) turn their autumn colour, shed,
## stand bare through winter and leaf out again in spring; evergreens shed
## a little all year. Worked out at the player's latitude (the region
## around you shares one season) from the season clock (Seasons), so it
## is the same whenever you look:
##
##   * colour: over the summer -> autumn transition each deciduous species'
##     crown blends leaf -> leaf_autumn (the foliage shader's sp_autumn,
##     which recolours the foliage mass by the same share);
##   * fall: from fall.start_at through that transition the crown sheds
##     fall.per_day_share of what it still holds per game-day over
##     fall.deciduous_days, the last of it going as the time runs out, so
##     it is bare in winter; a gust above fall.gust_mps drops fall.gust_share
##     of what is left at once (the whole tree lets go in a wind). What is
##     left is the foliage shader's leaf_season: crowns thin in leaf-sized
##     cells, branchy trees' clusters shrink and go;
##   * spring: over the winter -> spring transition the leaves come back,
##     green (buds: small clusters first, then full);
##   * falling leaves: the trees within NEAR_M shed billboards of their own
##     leaf card (a MultiMesh per species, shaders/leaf_fall.gdshader), at
##     the rate their crowns are losing leaves (VIS_LEAVES_PER_M2 of crown),
##     from inside the crown down to the ground within crown radius x
##     fall.spread, drifted downwind by the wind x fall.drift_s, at
##     fall.leaf_fall_speed_mps, fluttering (fall.leaf_flutter).
## Where they land and pile up is LitterField's (it reads shed_rate()).
## A child of the world root, so the floating origin carries the leaves.

static var FALL: Dictionary = Tuning.section("litter", "fall")
## Leaves on a square meter of crown (seen from above), for the falling
## billboards (a real crown holds more; each billboard stands for itself).
const VIS_LEAVES_PER_M2 := 400.0
## Trees shed billboards within this of the player.
const NEAR_M := 45.0
## Falling billboards per species at most.
const POOL := 240
## A crown's radius against the tree's height (as the canopy shade).
const CROWN_K := 0.3

var main: Node
## Now, for deciduous crowns: how far into the autumn colour (0-1) and
## how much leaf is left (0-1).
var autumn := 0.0
var leaf_left := 1.0
## The share of a full deciduous crown falling per game-day now (0 outside
## the fall), and the extra share a gust dropped this frame.
var shed_per_day := 0.0
var gust_drop := 0.0

## Trees placed by hand (tools): [scene root, height, species index];
## only_extra sheds from them alone.
var extra: Array = []
var only_extra := false

var _gust_mult := 1.0
var _gusting := false
var _scan_t := 0.0
var _apply_t := 0.0
var _trees: Array = [] # [local root, up, height, species index]
var _spawn_debt := {} # tree (its root, to the decimeter) -> leaves owed (fractional, and gust bursts)
var _falling := {} # species index -> _Fall
var _rng := RandomNumberGenerator.new()


class _Fall:
	var mmi: MultiMeshInstance3D
	var start := PackedVector3Array()
	var land := PackedVector3Array()
	var side := PackedVector3Array()
	var age := PackedFloat32Array()
	var dur := PackedFloat32Array()
	var phase := PackedFloat32Array()
	var size := 0.1


## The deciduous crown at year position `p` (Seasons.year_position), `h`
## half a transition: {"autumn", "leaf", "rate"} - the colour blend, the
## leaf left (before gusts) and the share of a full crown falling per day.
static func crown_at(p: float, h: float) -> Dictionary:
	var quarter := DayCycle.year_days() / 4.0
	# From the start of the winter -> spring transition.
	var q := fposmod(p - (3.5 - h), 4.0)
	if q < 2.0 * h:
		return {"autumn": 0.0, "leaf": q / (2.0 * h), "rate": 0.0}
	# The summer -> autumn transition starts at q = 2.
	var a := clampf((q - 2.0) / (2.0 * h), 0.0, 1.0)
	var start := 2.0 + float(FALL.get("start_at", 0.35)) * 2.0 * h
	if q < start:
		return {"autumn": a, "leaf": 1.0, "rate": 0.0}
	var d := (q - start) * quarter
	var leaf := _left_after(d)
	return {"autumn": a, "leaf": leaf, "rate": maxf(leaf - _left_after(d + 1.0), 0.0)}


## A deciduous crown's leaf left `d` game-days into its fall.
static func _left_after(d: float) -> float:
	var n := float(FALL.get("deciduous_days", 18.0))
	return pow(1.0 - float(FALL.get("per_day_share", 0.08)), d) * (1.0 - smoothstep(0.75 * n, n, d))


## The share of a full crown of species `sp` falling per game-day now
## (evergreens: their yearly share, spread over the year).
func shed_rate(sp: PlantSpecies) -> float:
	if sp.deciduous:
		return shed_per_day
	return float(FALL.get("evergreen_share_per_year", 0.3)) / DayCycle.year_days()


func update_season(delta: float, d: Vector3, days: float, wind: Vector3) -> void:
	var p := Seasons.year_position(days, CubeSphere.latitude(d))
	var c := crown_at(p, Seasons.half_transition())
	var falling: bool = c.rate > 0.0 or (c.leaf < 1.0 and c.autumn > 0.0 and c.leaf > 0.0)
	if c.autumn <= 0.0 and c.leaf < 1.0:
		_gust_mult = 1.0 # spring: leafing out again
	# A gust in the fall drops a share of what is left, once per gust.
	gust_drop = 0.0
	var speed := wind.length()
	var gust_mps := float(FALL.get("gust_mps", 6.0))
	# (A wind already up when the fall begins lets go at once.)
	if speed > gust_mps and not _gusting and falling:
		_gusting = true
		if c.leaf * _gust_mult > 0.01:
			var share := float(FALL.get("gust_share", 0.25))
			gust_drop = c.leaf * _gust_mult * share
			_gust_mult *= 1.0 - share
	elif speed < gust_mps * 0.8:
		_gusting = false
	autumn = c.autumn
	leaf_left = c.leaf * _gust_mult
	shed_per_day = c.rate * _gust_mult
	_apply_t -= delta
	if _apply_t <= 0.0 or gust_drop > 0.0:
		_apply_t = 0.25
		_apply()
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_scan()
	_shed(delta, wind)
	_fly(delta)


## The species materials take the season (deciduous only; evergreens stay
## green and full).
func _apply() -> void:
	var all := SpeciesDB.all()
	var mats := PlantMeshes.species_materials()
	for idx in mats:
		var sp: PlantSpecies = all[idx]
		if not sp.deciduous:
			continue
		var m: ShaderMaterial = mats[idx]
		m.set_shader_parameter("sp_autumn", autumn)
		m.set_shader_parameter("leaf_season", leaf_left)
	for idx in _falling:
		(_falling[idx] as _Fall).mmi.material_override.set_shader_parameter("sp_autumn", autumn if all[idx].deciduous else 0.0)


## The trees near the player that can shed (their species has a leaf tile).
func _scan() -> void:
	_trees.clear()
	if _spawn_debt.size() > 4000:
		_spawn_debt.clear()
	if main == null:
		return
	var eye: Vector3 = main.player.global_position
	var all := SpeciesDB.all()
	for t in extra:
		_trees.append([to_local(t[0]), main.world.dir_of(t[0]), float(t[1]), int(t[2])])
	if only_extra:
		return
	for key in main.chunks.chunks:
		var ch: TerrainChunk = main.chunks.chunks[key]
		if ch.global_position.distance_to(eye) > NEAR_M + TerrainChunk.CHUNK_M:
			continue
		for t in ch.trees:
			var sp: PlantSpecies = all[int(t[2])]
			if not sp.tiles.has("leaf") or (t.size() > 8 and float(t[8]) >= 1.0):
				continue
			var root := ch.to_global(t[0])
			if root.distance_to(eye) > NEAR_M:
				continue
			_trees.append([to_local(root), main.world.dir_of(root), float(t[1]), int(t[2])])


## Leaves leave the crowns at the rate the crowns are losing them.
func _shed(delta: float, wind: Vector3) -> void:
	var day_s := DayCycle.day_length_min() * 60.0
	var all := SpeciesDB.all()
	var drift := float(FALL.get("drift_s", 1.5))
	var spread := float(FALL.get("spread", 1.3))
	for t in _trees:
		var sp: PlantSpecies = all[t[3]]
		var r: float = t[2] * CROWN_K
		var leaves := VIS_LEAVES_PER_M2 * PI * r * r
		var key := Vector3i((t[0] as Vector3) * 10.0)
		var owed: float = _spawn_debt.get(key, 0.0) + leaves * shed_rate(sp) / day_s * delta
		if sp.deciduous and gust_drop > 0.0:
			owed += minf(leaves * gust_drop, 40.0)
		var n := int(owed)
		_spawn_debt[key] = owed - n
		for k in mini(n, 6):
			_spawn(t, sp, r, spread, wind * drift)
		if n > 6:
			_spawn_debt[key] += n - 6 # a burst goes out over the next frames


func _spawn(t: Array, sp: PlantSpecies, r: float, spread: float, drift: Vector3) -> void:
	var f := _fall_of(t[3], sp)
	if f.start.size() >= POOL:
		return
	var up: Vector3 = t[1]
	var e := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var n := up.cross(e)
	var a := _rng.randf() * TAU
	var from: Vector3 = t[0] + up * t[2] * _rng.randf_range(0.5, 0.95) + (e * cos(a) + n * sin(a)) * r * sqrt(_rng.randf()) * 0.85
	var b := _rng.randf() * TAU
	var drift_t := drift - up * drift.dot(up)
	var to: Vector3 = t[0] + (e * cos(b) + n * sin(b)) * r * spread * sqrt(_rng.randf()) + drift_t + up * 0.03
	f.start.append(from)
	f.land.append(to)
	f.side.append((e * cos(b + 1.3) + n * sin(b + 1.3)))
	f.age.append(0.0)
	f.dur.append(maxf((from - to).dot(up), 0.5) / float(FALL.get("leaf_fall_speed_mps", 0.6)))
	f.phase.append(_rng.randf() * TAU)


func _fall_of(idx: int, sp: PlantSpecies) -> _Fall:
	if _falling.has(idx):
		return _falling[idx]
	var f := _Fall.new()
	# Twice the leaf: a falling card must read at 480 lines.
	f.size = clampf(sp.leaf_m * 2.0, 0.12, 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = POOL
	mm.visible_instance_count = 0
	f.mmi = MultiMeshInstance3D.new()
	f.mmi.name = "Falling_" + sp.name
	f.mmi.multimesh = mm
	f.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (Its instances move every frame: bounds wide enough never to cull.)
	f.mmi.custom_aabb = AABB(Vector3.ONE * -NEAR_M * 3.0, Vector3.ONE * NEAR_M * 6.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/leaf_fall.gdshader")
	var leaf := PlantMeshes.tile(sp.tiles.get("leaf", ""))
	m.set_shader_parameter("sp_leaf", leaf)
	m.set_shader_parameter("sp_leaf_autumn", PlantMeshes.tile(sp.tiles.get("leaf_autumn", "")) if sp.tiles.has("leaf_autumn") else leaf)
	m.set_shader_parameter("sp_autumn", autumn if sp.deciduous else 0.0)
	m.set_shader_parameter("flutter", float(FALL.get("leaf_flutter", 0.8)))
	f.mmi.material_override = m
	add_child(f.mmi)
	_falling[idx] = f
	return f


## Down they come: from the crown to the ground on a straight line, with
## a sideways swing (the flutter), then gone (LitterField keeps the pile).
func _fly(delta: float) -> void:
	var flutter := float(FALL.get("leaf_flutter", 0.8))
	for idx in _falling:
		var f: _Fall = _falling[idx]
		var i := 0
		while i < f.start.size():
			f.age[i] += delta
			if f.age[i] >= f.dur[i]:
				# Landed: the last one takes its place (packed arrays are
				# values, so each is written back by name).
				var last := f.start.size() - 1
				f.start[i] = f.start[last]
				f.land[i] = f.land[last]
				f.side[i] = f.side[last]
				f.age[i] = f.age[last]
				f.dur[i] = f.dur[last]
				f.phase[i] = f.phase[last]
				f.start.resize(last)
				f.land.resize(last)
				f.side.resize(last)
				f.age.resize(last)
				f.dur.resize(last)
				f.phase.resize(last)
				continue
			i += 1
		var mm := f.mmi.multimesh
		var n := f.start.size()
		for k in n:
			var u := f.age[k] / f.dur[k]
			var swing := sin(f.age[k] * 1.9 + f.phase[k]) * flutter * 0.6 * minf(u * 4.0, 1.0)
			var p := f.start[k].lerp(f.land[k], u) + f.side[k] * swing
			mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * f.size), p))
			mm.set_instance_custom_data(k, Color(f.phase[k], 0.0, 0.0, 0.0))
		mm.visible_instance_count = n


## How many leaves are in the air (tools).
func falling_count() -> int:
	var n := 0
	for idx in _falling:
		n += (_falling[idx] as _Fall).start.size()
	return n
