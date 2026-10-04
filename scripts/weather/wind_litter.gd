class_name WindLitter
extends Node3D
## Loose things on the ground in the wind (design 3 Oct §DA point 4,
## data/wind.json litter; Wind II). Round the player (litter.radius_m)
## the gusted wind at each spot, after the shelter of the crowns over it
## (Wind.shelter by the spot's sky visibility), lifts what lies there:
##
## - leaves and needles come only from the real litter field
##   (LitterField: a cell's own pile and its dominant species), never
##   conjured where nothing fell. Each one lifted is that species' own
##   leaf card in its season's colour (LeafSeason's falling-leaf cards and
##   shaders/leaf_fall.gdshader's spin and flip), skating downwind,
##   skipping along the ground and lying down again after settle_s;
##   needles (conifers) need a much stronger gust (kinds.needles.from_mps);
## - sand, snow and dust are low streaming skins: ground-level cards
##   (shaders/wind_skin.gdshader) scrolling downwind where the ground is
##   that kind (sand on dunes, beaches and hot desert; spindrift on snow
##   cover; dust off dry bare ground and roads in dry country), shown as
##   the gust there passes the kind's from_mps.
##
## At most litter.count_max pieces in the air at once. Under a closed
## wood the shelter keeps the gust below every threshold, so this happens
## on roads, clearings and edges.

static var L: Dictionary = Tuning.section("wind", "litter")
const TICK_S := 0.1
const TRIES := 8
## A skin patch's side (m) and the patches across (a grid round you).
const SKIN_M := 8.0
const SKIN_N := 5

var main: Node
var _t := 0.0
var _rng := RandomNumberGenerator.new()
## Pieces in the air: [real time it settles].
var _alive: Array = []
var _skins: Array[MeshInstance3D] = []
var _skin_mats := {}
var _skin_t := 0.0
## The last lift (tools): [kind, species index, from scene pos, to scene pos, settle s].
var last_lift: Array = []
var lifted := 0


func setup(p_main: Node) -> void:
	main = p_main
	_rng.randomize()
	var quad := QuadMesh.new()
	quad.size = Vector2(SKIN_M, SKIN_M)
	quad.orientation = PlaneMesh.FACE_Y
	for i in SKIN_N * SKIN_N:
		var mi := MeshInstance3D.new()
		mi.name = "Skin%d" % i
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		_skins.append(mi)


static func kind_from(kind: String) -> float:
	return float(((L.get("kinds", {}) as Dictionary).get(kind, {}) as Dictionary).get("from_mps", 99.0))


static func settle_range() -> Vector2:
	var s: Array = L.get("settle_s", [2.0, 6.0])
	return Vector2(float(s[0]), float(s[1]))


## Needles (conifers and their kin) or leaves, for a species' litter.
static func litter_kind(sp: PlantSpecies) -> String:
	var S := PlantSpecies.Shape
	return "needles" if sp.shape in [S.CONIFER, S.CYPRESS] else "leaves"


## The wind (m/s) loose litter feels at scene point `p`: the gusted 10 m
## wind there times the shelter of the crowns over it (§BD's sky
## visibility); the Beaufort thresholds are written against this.
func ground_wind(p: Vector3, up: Vector3) -> Vector3:
	var sky := 1.0
	if main != null and main.chunks != null:
		sky = main.chunks.sky_visibility_at(p)
	return Wind.gust_vec(p, up) * Wind.shelter(sky, Delves.inside)


func in_air() -> int:
	return _alive.size()


func update_litter(delta: float) -> void:
	if main == null or main.player == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var keep: Array = []
	for t in _alive:
		if float(t) > now:
			keep.append(t)
	_alive = keep
	_t -= delta
	if _t <= 0.0:
		_t = TICK_S
		for i in TRIES:
			if _alive.size() >= int(L.get("count_max", 40)):
				break
			try_lift(_random_spot())
	_skin_t -= delta
	if _skin_t <= 0.0:
		_skin_t = 0.5
		_place_skins()


func _random_spot() -> Vector3:
	var pl: Node3D = main.player
	var up: Vector3 = main.world.dir_of(pl.global_position)
	var e := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var n := up.cross(e)
	var a := _rng.randf() * TAU
	var r := float(L.get("radius_m", 25.0)) * sqrt(_rng.randf())
	return pl.global_position + (e * cos(a) + n * sin(a)) * r


## Try to lift a piece of what lies at scene point `p` (the litter field's
## cell there): true if one went.
func try_lift(p: Vector3) -> bool:
	var lf: LitterField = main.get("litter") if main.get("litter") is LitterField else null
	var ls: LeafSeason = main.get("leaf_season") if main.get("leaf_season") is LeafSeason else null
	if lf == null or ls == null:
		return false
	var d: Vector3 = main.world.dir_of(p)
	var c = lf.cells.get(lf.key_of(d))
	if c == null or (c as LitterField.Cell).mass() < LitterField.MIN_KG_M2 or (c as LitterField.Cell).dominant < 0:
		return false
	var cell := c as LitterField.Cell
	var sp: PlantSpecies = SpeciesDB.all()[cell.dominant]
	var kind := litter_kind(sp)
	var up := d
	var w := ground_wind(p, up)
	var speed := w.length()
	var from := kind_from(kind)
	if speed < from:
		return false
	# More goes the harder it blows over the threshold, and the deeper the
	# pile (fresh leaves first: the top stage).
	var chance := clampf((speed - from) / from * 1.5 + 0.15, 0.0, 1.0) * clampf(cell.m[0] / 0.05 + 0.2, 0.2, 1.0)
	if _rng.randf() > chance:
		return false
	var at: Vector3 = main.world.to_scene(d, PlanetConst.RADIUS_M + cell.ground + 0.04)
	var sr := settle_range()
	var dur := _rng.randf_range(sr.x, sr.y)
	var flat := w - up * w.dot(up)
	# A skating leaf runs at a share of the gust and slows as it goes.
	var to := at + flat * dur * _rng.randf_range(0.25, 0.4)
	ls.skate(at, to, up, cell.dominant, dur, _rng.randf_range(0.15, 0.5))
	_alive.append(Time.get_ticks_msec() / 1000.0 + dur)
	last_lift = [kind, cell.dominant, at, to, dur]
	lifted += 1
	return true


## The ground kind a skin can stream over at `d` ("" none): sand, snow or
## dust (litter.kinds where).
func skin_kind_at(d: Vector3) -> String:
	var world = main.world
	var map: PlanetData = world.planet
	var chunks: ChunkManager = main.chunks
	var cell := map.cell_at(d)
	var bkey := BiomeTemplates.KEYS[map.biome[cell]]
	var h := chunks.ground_height(d)
	if chunks.water_level_at(d) > h + 0.05:
		return ""
	if bkey in ["DUNES", "BEACH", "HOT_DESERT"] or TerrainChunk.sand_amount(map, d, h) > 0.5:
		return "sand"
	var chunk := chunks.chunk_at(d)
	if chunk == null:
		return ""
	var col := chunk.ground_color_at(d)
	var hi := maxf(col.r, maxf(col.g, col.b))
	var sat := hi - minf(col.r, minf(col.g, col.b))
	if sat < 0.06 and hi > 0.8:
		return "snow"
	var green := col.g - maxf(col.r, col.b) * 0.92 > 0.03
	if not green and sat >= 0.06 and map.moisture[cell] < 0.35:
		return "dust"
	return ""


func _skin_mat(kind: String) -> ShaderMaterial:
	if _skin_mats.has(kind):
		return _skin_mats[kind]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/wind_skin.gdshader")
	var col: Color = {"sand": Color(0.86, 0.78, 0.58), "snow": Color(0.9, 0.94, 1.0), "dust": Color(0.78, 0.72, 0.62)}.get(kind, Color.WHITE)
	m.set_shader_parameter("skin_color", col)
	m.set_shader_parameter("streak", 0.55 if kind == "sand" else (0.75 if kind == "snow" else 0.35))
	Look.register(m)
	_skin_mats[kind] = m
	return m


## The skins: a grid of ground-level cards round you, each showing its
## ground's kind as the gust there passes that kind's from_mps.
func _place_skins() -> void:
	var pl: Node3D = main.player
	var up: Vector3 = main.world.dir_of(pl.global_position)
	var e := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var n := up.cross(e)
	var half := (SKIN_N - 1) * 0.5
	for i in SKIN_N:
		for j in SKIN_N:
			var mi := _skins[i * SKIN_N + j]
			var p: Vector3 = pl.global_position + e * (i - half) * SKIN_M + n * (j - half) * SKIN_M
			var d: Vector3 = main.world.dir_of(p)
			var kind := skin_kind_at(d)
			if kind == "":
				mi.visible = false
				continue
			var at: Vector3 = main.world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 0.06)
			var w := ground_wind(at, d)
			var from := kind_from(kind)
			var show := smoothstep(from, from * 1.6, w.length())
			mi.visible = show > 0.02
			if not mi.visible:
				continue
			mi.material_override = _skin_mat(kind)
			mi.set_instance_shader_parameter("skin_alpha", show)
			mi.set_instance_shader_parameter("skin_wind", w)
			mi.global_transform = Transform3D(Basis(e, d, -n).orthonormalized(), at)


## How many skin cards show now, by kind (tools).
func skins_shown() -> Dictionary:
	var out := {}
	for mi in _skins:
		if mi.visible and mi.material_override != null:
			for k in _skin_mats:
				if _skin_mats[k] == mi.material_override:
					out[k] = int(out.get(k, 0)) + 1
	return out
