class_name DayAccents
extends Node3D
## Life in the air by day (design 3 Oct §DC, data/day_accents.json): a few
## butterflies dancing round the flowers near you in warm sun. The day's
## counterpart of NightAccents (whose blue butterflies at the ruins stay
## as they are), except that nothing here glows: their material is lit by
## the scene like the leaves, with no emission, and they cast no light
## (look R8).
##
## Every half second (refresh()): while it is day (the sky's daylight at
## or over night_accents' shows_below_daylight), not over snow and inside
## temp_c, the herbs and shrubs within range_m that stand where the sun
## reaches (sky visibility over min_visibility, never under closed crowns)
## are the flowers (no species has a bloom state yet, PlantGrowth; any herb
## or shrub by day stands in). With at least one, count of them (more
## where there are more flowers, within `count`) fly: each circles its
## flower at height_m, flapping a two-frame pixel card, drifting a little
## downwind. When the wind at them reaches calm_below_mps they land in the
## grass and stay still until it eases. Colours by the land's family
## (palette_by_family). At dusk, at night and when the gate fails they are
## freed, as NightAccents frees its props by day.

static var D: Dictionary = {}
const REFRESH_S := 0.5

var main: Node
## Tools: keys replace gather()'s readings (temp_c, wind_mps, snow,
## daylight, visibility: one sky visibility for every flower).
var override := {}
## The last gate (tools): {"ok", "why", "flowers", "family"}.
var gate_state := {}
## The butterflies now: [{"flower" (this node's frame), "phase", "radius",
## "color", "landed", "pos", "speed"}].
var flies: Array = []
var _mmi: MultiMeshInstance3D = null
var _mat: StandardMaterial3D
var _t := 0.0
var _time := 0.0
var _center := Vector3.INF
var _rng := RandomNumberGenerator.new()


static func data() -> Dictionary:
	if D.is_empty():
		var f := FileAccess.open("res://data/day_accents.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			D = parsed if parsed is Dictionary else {}
	return D


static func B() -> Dictionary:
	return data().get("butterflies", {})


func setup(p_main: Node) -> void:
	main = p_main
	_rng.seed = 23
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.roughness = 1.0
	_mat.metallic_specular = 0.0
	_mat.emission_enabled = false
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


## The land's family for the palette: tropical, dry, cold or temperate,
## by the biome's name (a first sort until the species fill).
static func family_of(biome_key: String) -> String:
	var k := biome_key.to_upper()
	for w in ["TROPICAL", "JUNGLE", "MANGROVE", "SAVANNA", "MONSOON", "CLOUD_FOREST"]:
		if k.contains(w):
			return "tropical"
	for w in ["DESERT", "SCRUB", "SAGEBRUSH", "BADLANDS", "CANYON", "SALT", "STEPPE", "CHAPARRAL", "XERIC"]:
		if k.contains(w):
			return "dry"
	for w in ["TAIGA", "TUNDRA", "ALPINE", "BOREAL", "KRUMMHOLZ", "GLACIER", "ICE", "PARAMO", "PUNA"]:
		if k.contains(w):
			return "cold"
	return "temperate"


## The readings at the player.
func gather() -> Dictionary:
	var player: Node3D = main.player
	var w: Dictionary = main.get("_local_weather") if main.get("_local_weather") is Dictionary else {}
	var up: Vector3 = player.global_basis.y.normalized()
	var r := {
		"daylight": float(main.sky.daylight),
		"temp_c": float(w.get("temp_c", 18.0)),
		"snow": bool(w.get("snow", false)) or Footsteps.material_under(player) == "snow",
		"wind_mps": Wind.gust_vec(player.global_position, up).length(),
		"wind_dir": Wind.gust_vec(player.global_position, up),
		"biome": FireStore.biome_key(main.world, player.surface_dir),
	}
	for k in override:
		r[k] = override[k]
	return r


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	_time += delta
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH_S
		refresh(gather())
	_fly(delta)


## The gate and the swarm from the readings `r`.
func refresh(r: Dictionary) -> void:
	var b := B()
	var tc: Array = b.get("temp_c", [14.0, 40.0])
	var day_from := float(NightAccents.data().get("shows_below_daylight", 0.35))
	gate_state = {"ok": false, "why": "", "flowers": 0, "family": family_of(str(r.get("biome", "")))}
	if float(r.daylight) < day_from:
		gate_state.why = "night"
	elif bool(r.snow):
		gate_state.why = "snow"
	elif float(r.temp_c) < float(tc[0]) or float(r.temp_c) > float(tc[1]):
		gate_state.why = "temperature"
	if gate_state.why != "":
		clear()
		return
	var player: Node3D = main.player
	var pp := player.global_position
	# Re-find the flowers when you have walked off from where they were.
	if _center == Vector3.INF or to_global(_center).distance_to(pp) > float(b.get("range_m", 30.0)) * 0.5 or flies.is_empty():
		var flowers := _flowers(pp, r)
		gate_state.flowers = flowers.size()
		if flowers.is_empty():
			gate_state.why = "no flowers in the sun"
			clear()
			return
		_build(flowers, r)
		_center = to_local(pp)
	gate_state.ok = true
	gate_state.flowers = maxi(int(gate_state.flowers), flies.size())
	var calm := float(b.get("calm_below_mps", 5.5))
	var windy := float(r.wind_mps) >= calm
	for f in flies:
		f.landed = windy
	gate_state["windy"] = windy
	_wind_dir = (r.get("wind_dir", Vector3.ZERO) as Vector3)


var _wind_dir := Vector3.ZERO


func clear() -> void:
	if _mmi != null and is_instance_valid(_mmi):
		NodeRelease.free_later(_mmi)
	_mmi = null
	flies.clear()
	_center = Vector3.INF


## The herbs and shrubs within range_m in the sun: their bases (scene).
func _flowers(pp: Vector3, r: Dictionary) -> Array:
	var b := B()
	var range_m := float(b.get("range_m", 30.0))
	var min_vis := float(b.get("min_visibility", 0.4))
	var all := SpeciesDB.all()
	var out: Array = []
	var chunks: ChunkManager = main.chunks
	for key in chunks.chunks:
		var chunk: TerrainChunk = chunks.chunks[key]
		if chunk.detail_node == null or chunk.global_position.distance_to(pp) > range_m + 400.0:
			continue
		for n in chunk.detail_node.get_children():
			var mmi := n as MultiMeshInstance3D
			if mmi == null or not mmi.has_meta("species") or mmi.multimesh == null:
				continue
			var sp: PlantSpecies = all[int(mmi.get_meta("species"))]
			if not (sp.tier in [PlantSpecies.Tier.SHRUB, PlantSpecies.Tier.GROUND]) or sp.shape in [PlantSpecies.Shape.MOSS, PlantSpecies.Shape.HANGING_MOSS]:
				continue
			var buf := mmi.multimesh.buffer
			var count := mmi.multimesh.instance_count if mmi.multimesh.visible_instance_count < 0 else mmi.multimesh.visible_instance_count
			for k in range(0, count, 3):
				var j := k * 20
				if j + 11 >= buf.size():
					break
				var base := mmi.global_transform * Vector3(buf[j + 3], buf[j + 7], buf[j + 11])
				if base.distance_to(pp) > range_m:
					continue
				var vis := float(r.visibility) if r.has("visibility") else chunks.sky_visibility_at(base)
				if vis < min_vis:
					continue
				out.append(base)
				if out.size() >= 64:
					return out
	return out


func _build(flowers: Array, r: Dictionary) -> void:
	clear()
	var b := B()
	var cr: Array = b.get("count", [2, 6])
	var n := clampi(int(cr[0]) + flowers.size() / 10, int(cr[0]), int(cr[1]))
	var pal: Array = (b.get("palette_by_family", {}) as Dictionary).get(str(gate_state.family), ["#F2F0E6"])
	var size := float(b.get("size_m", 0.08))
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * 0.8)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = n
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Butterflies"
	_mmi.multimesh = mm
	_mmi.material_override = _mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)
	for i in n:
		var fl: Vector3 = flowers[_rng.randi() % flowers.size()]
		var col := Color.from_string(str(pal[_rng.randi() % pal.size()]), Color.WHITE)
		mm.set_instance_color(i, col)
		var lp := to_local(fl)
		flies.append({"flower": lp, "phase": _rng.randf() * TAU, "radius": _rng.randf_range(0.4, 1.4), "color": col, "landed": false, "pos": lp, "speed": 0.0, "rate": _rng.randf_range(0.7, 1.3)})


func _fly(delta: float) -> void:
	if _mmi == null or not is_instance_valid(_mmi) or flies.is_empty():
		return
	var b := B()
	var hr: Array = b.get("height_m", [0.3, 2.5])
	var sp := float(b.get("speed_mps", 0.8))
	var mm := _mmi.multimesh
	var up: Vector3 = global_basis.inverse() * (main.player.global_basis.y.normalized() as Vector3)
	var e := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var n := up.cross(e).normalized()
	var wl := global_basis.inverse() * _wind_dir
	wl -= up * wl.dot(up)
	var drift := wl.normalized() * minf(wl.length() * 0.15, 1.0) if wl.length() > 0.01 else Vector3.ZERO
	for i in flies.size():
		var f: Dictionary = flies[i]
		var fl: Vector3 = f.flower
		var want: Vector3
		var flap := 1.0
		if bool(f.landed):
			# Sat in the grass at its flower, wings closed, still.
			want = fl + up * 0.03
			flap = 0.3
		else:
			var t := _time * sp / maxf(float(f.radius), 0.2) * float(f.rate) + float(f.phase)
			var h := lerpf(float(hr[0]), float(hr[1]), 0.5 + 0.5 * sin(t * 0.53 + float(f.phase)))
			want = fl + (e * cos(t) + n * sin(t * 1.3)) * float(f.radius) + up * h + drift
			# A two-frame flap: open, closed.
			flap = 1.0 if int(_time * 9.0 + float(f.phase) * 3.0) % 2 == 0 else 0.25
		var before: Vector3 = f.pos
		var now: Vector3 = before.move_toward(want, sp * (4.0 if bool(f.landed) else 2.5) * delta)
		f.pos = now
		f.speed = before.distance_to(now) / maxf(delta, 1e-4)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(flap, 1.0, 1.0)), now))
