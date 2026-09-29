class_name LitterField
extends Node3D
## Leaf litter on the ground (design §AI 2; numbers in data/litter.json
## "pile" and "fall"): where the trees near the player shed (LeafSeason),
## fallen leaf mass settles in cells of pile.merge_cell_m (4 m) and is
## drawn there as a patch of the dominant species' litter tile
## (assets/textures/plants/species/<key>_litter.png, shaders/litter.gdshader).
##
## Mass (kg per square meter) -> depth: pile.cm_per_kg_m2. A deciduous
## crown lets go LEAF_KG_M2 of leaves per square meter of crown over its
## fall (evergreens NEEDLE_KG_M2 of foliage, fall.evergreen_share_per_year
## of it a year), spread evenly within its crown radius x fall.spread,
## shifted downwind by the wind x fall.drift_s; so mixed woods make mixed
## litter and the leeward side of a wood piles deepest. The cells are
## fixed to the ground (a grid on the cube-sphere face), so a pile stays
## where it fell. A patch is ragged at its edge, thin litter a scatter of
## leaves over bare ground, deeper litter solid; past a few cm it rises
## as a low mound (up to pile.max_raise_m).
##
## You wade through it: above pile.rustle_cm each stride rustles
## (SoundSynth "rustle"); running through a cell kicks pile.kick_share of
## its top layer up into the air (LeafSeason.kick) once each time you
## enter it.
##
## Only the ground near the player gathers litter (the trees LeafSeason
## watches); a cell keeps its litter when you walk away.

static var PILE: Dictionary = Tuning.section("litter", "pile")
static var FALL: Dictionary = Tuning.section("litter", "fall")
## Leaves a deciduous crown drops over its fall, kg per m2 of crown
## (leaf area index ~5 x ~80 g/m2 dry leaf); evergreen foliage held, kg
## per m2 of crown.
const LEAF_KG_M2 := 0.4
const NEEDLE_KG_M2 := 1.0
## Patches drawn within this of the player; no more than MAX_DRAWN.
const DRAW_M := 70.0
const MAX_DRAWN := 1200
## A cell is drawn from this much litter (kg/m2: ~1 mm).
const MIN_KG_M2 := 0.015
## Texture layers for the region's litter tiles.
const MAX_LAYERS := 48
## How often the ground takes what fell (s).
const STEP_S := 0.25

var main: Node
var leaf_season: LeafSeason
## Cells by key (face, i, j).
var cells := {}

var _cell_m := 4.0
var _last_days := -1.0
var _step_t := 0.0
var _mmi: MultiMeshInstance3D
var _mat: ShaderMaterial
var _layers := {} # species index -> layer
var _layer_images: Array[Image] = []
var _layer_tile_m := PackedFloat32Array()
var _array_dirty := false
var _player_cell := Vector3i(-1, 0, 0)
var _stride := 0.0
var _rustle: AudioStreamPlayer3D
var _rustle_n := 0


class Cell:
	var dir: Vector3 # its center on the ground
	var ground := 0.0 # ground height there (m above the radius)
	var normal := Vector3.UP # the ground's slope there
	## Litter by decomposition stage (data/litter.json "stages"), kg/m2.
	var m := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	## What fell here, by species index (kg/m2 fed), for the dominant one.
	var fed := {}
	var dominant := -1

	func mass() -> float:
		return m[0] + m[1] + m[2] + m[3] + m[4]


func _ready() -> void:
	_cell_m = float(PILE.get("merge_cell_m", 4.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	mm.mesh = plane
	mm.instance_count = MAX_DRAWN
	mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "LitterPatches"
	_mmi.multimesh = mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.custom_aabb = AABB(Vector3.ONE * -DRAW_M * 3.0, Vector3.ONE * DRAW_M * 6.0)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/litter.gdshader")
	Look.register(_mat)
	_mat.set_shader_parameter("max_raise_m", float(PILE.get("max_raise_m", 0.25)))
	_mat.set_shader_parameter("cm_per_kg_m2", float(PILE.get("cm_per_kg_m2", 6.0)))
	# The rotting stages' colour transforms (data/litter.json "stages").
	var stages: Array = Tuning.table("litter").get("stages", [])
	var to := PackedVector4Array()
	var sv := PackedVector4Array()
	for i in 5:
		var st: Dictionary = stages[mini(i, stages.size() - 1)] if not stages.is_empty() else {}
		var cl: Dictionary = st.get("color_lerp", {})
		var col := Color.from_string(str(cl.get("to", "#000000")), Color.BLACK)
		to.append(Vector4(col.r, col.g, col.b, float(cl.get("amount", 0.0))))
		sv.append(Vector4(float(st.get("sat", 1.0)), float(st.get("val", 1.0)), float(st.get("holes", 0.0)), float(st.get("height", 1.0))))
	_mat.set_shader_parameter("stage_to", to)
	_mat.set_shader_parameter("stage_svhh", sv)
	_mat.set_shader_parameter("holes_tex", PlantMeshes.tile(SpeciesDB.ATLAS_PATH.get_base_dir() + "/litter_holes.png"))
	_mmi.material_override = _mat
	add_child(_mmi)
	_rustle = AudioStreamPlayer3D.new()
	_rustle.name = "LitterRustle"
	Audio3D.apply(_rustle, "rustle")
	add_child(_rustle)


## The cell key of a ground direction: the cube face and its grid there.
func key_of(d: Vector3) -> Vector3i:
	var face := CubeSphere.face_of(d)
	var uv := CubeSphere.face_uv(face, d) * PlanetConst.RADIUS_M / _cell_m
	return Vector3i(face, int(floor(uv.x)), int(floor(uv.y)))


func _center_of(k: Vector3i) -> Vector3:
	var s := _cell_m / PlanetConst.RADIUS_M
	return CubeSphere.to_dir(k.x, (k.y + 0.5) * s, (k.z + 0.5) * s)


func _cell(k: Vector3i) -> Cell:
	if cells.has(k):
		return cells[k]
	var c := Cell.new()
	c.dir = _center_of(k)
	c.ground = main.chunks.ground_height(c.dir)
	# The ground's slope: heights 2 m east and north.
	var e := CubeSphere.east(c.dir)
	var n := CubeSphere.north(c.dir)
	var he: float = main.chunks.ground_height((c.dir + e * 2.0 / PlanetConst.RADIUS_M).normalized())
	var hn: float = main.chunks.ground_height((c.dir + n * 2.0 / PlanetConst.RADIUS_M).normalized())
	c.normal = (c.dir - e * (he - c.ground) / 2.0 - n * (hn - c.ground) / 2.0).normalized()
	cells[k] = c
	return c


## Litter depth under ground direction `d`, cm.
func depth_cm_at(d: Vector3) -> float:
	var c: Cell = cells.get(key_of(d))
	return c.mass() * float(PILE.get("cm_per_kg_m2", 6.0)) if c else 0.0


func update_litter(delta: float, d: Vector3, days: float, weather: Dictionary) -> void:
	_player_step(delta)
	_step_t -= delta
	if _step_t > 0.0:
		return
	_step_t = STEP_S
	if _last_days < 0.0:
		_last_days = days
		return
	var dd := days - _last_days
	_last_days = days
	# (The clock jumped: nothing fell in between that we saw.)
	if dd < 0.0 or dd > 3.0:
		_redraw()
		return
	_deposit(d, days - dd, days, weather)
	age(dd, weather)
	_redraw()


## What the trees near the player let go of between two moments.
func _deposit(d: Vector3, days0: float, days1: float, weather: Dictionary) -> void:
	if leaf_season == null:
		return
	var lat := CubeSphere.latitude(d)
	var h := Seasons.half_transition()
	var c0 := LeafSeason.crown_at(Seasons.year_position(days0, lat), h)
	var c1 := LeafSeason.crown_at(Seasons.year_position(days1, lat), h)
	# The deciduous crowns' loss (a share of a full crown), gusts included.
	var dec := maxf(float(c0.leaf) - float(c1.leaf), 0.0) * leaf_season.gust_mult() + leaf_season.take_gust()
	var ever := float(FALL.get("evergreen_share_per_year", 0.3)) / DayCycle.year_days() * (days1 - days0)
	var spread := float(FALL.get("spread", 1.3))
	var wind: Vector3 = WeatherFX.plant_wind * float(FALL.get("drift_s", 1.5))
	var all := SpeciesDB.all()
	for t in leaf_season.tree_list():
		var sp: PlantSpecies = all[t[3]]
		var share := dec if sp.deciduous else ever
		if share <= 0.0:
			continue
		var r: float = float(t[2]) * LeafSeason.CROWN_K
		var kg: float = PI * r * r * (LEAF_KG_M2 if sp.deciduous else NEEDLE_KG_M2) * share
		var up: Vector3 = t[1]
		var drift := wind - up * wind.dot(up)
		var center := (up + drift / PlanetConst.RADIUS_M).normalized()
		_spread(center, r * spread, kg, t[3])


## Lay `kg` of leaves of species `sp_idx` evenly on the ground within
## `radius` m of `center`.
func _spread(center: Vector3, radius: float, kg: float, sp_idx: int) -> void:
	var per_m2 := kg / (PI * radius * radius)
	var k0 := key_of(center)
	var reach := int(ceil(radius / _cell_m)) + 1
	var hit := []
	for i in range(-reach, reach + 1):
		for j in range(-reach, reach + 1):
			var k := Vector3i(k0.x, k0.y + i, k0.z + j)
			if CubeSphere.surface_distance_m(_center_of(k), center) <= radius:
				hit.append(k)
	if hit.is_empty():
		hit.append(k0)
		per_m2 = kg / (_cell_m * _cell_m)
	for k in hit:
		var c := _cell(k)
		c.m[0] += per_m2
		c.fed[sp_idx] = float(c.fed.get(sp_idx, 0.0)) + per_m2
		if c.dominant < 0 or float(c.fed[sp_idx]) > float(c.fed.get(c.dominant, 0.0)):
			c.dominant = sp_idx
		if not _layers.has(sp_idx):
			_add_layer(sp_idx)


## Litter rots over `dd` game-days (§AI 3-4; LitterField.age is extended
## by the decomposition step).
func age(_dd: float, _weather: Dictionary) -> void:
	pass


func _add_layer(sp_idx: int) -> void:
	if _layer_images.size() >= MAX_LAYERS:
		_layers[sp_idx] = 0
		return
	var sp: PlantSpecies = SpeciesDB.all()[sp_idx]
	var tex := PlantMeshes.tile(sp.tiles.get("litter", ""))
	if tex == null:
		_layers[sp_idx] = 0 if not _layer_images.is_empty() else -1
		if _layer_images.is_empty():
			_layers.erase(sp_idx)
		return
	var img := tex.get_image()
	img.decompress()
	if img.get_size() != Vector2i(32, 32):
		img.clear_mipmaps()
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		img.generate_mipmaps()
	_layers[sp_idx] = _layer_images.size()
	_layer_images.append(img)
	# A tile holds a few fallen leaves across.
	_layer_tile_m.append(clampf(sp.leaf_m * 3.0, 0.3, 2.5))
	_array_dirty = true


func _redraw() -> void:
	if _array_dirty and not _layer_images.is_empty():
		_array_dirty = false
		var arr := Texture2DArray.new()
		arr.create_from_images(_layer_images)
		_mat.set_shader_parameter("litter_tiles", arr)
		var tm := PackedFloat32Array(_layer_tile_m)
		tm.resize(MAX_LAYERS)
		_mat.set_shader_parameter("layer_tile_m", tm)
	var eye: Vector3 = main.player.global_position
	var mm := _mmi.multimesh
	var n := 0
	var patch := _cell_m * 1.35
	for k in cells:
		var c: Cell = cells[k]
		var mass := c.mass()
		if mass < MIN_KG_M2 or c.dominant < 0 or not _layers.has(c.dominant):
			continue
		var at: Vector3 = main.world.to_scene(c.dir, PlanetConst.RADIUS_M + c.ground + 0.02)
		if at.distance_to(eye) > DRAW_M:
			continue
		var up := c.normal
		var x := up.cross(CubeSphere.north(c.dir)).normalized()
		var z := x.cross(up)
		var seed := float(absi(hash(k)) % 1000) / 1000.0
		mm.set_instance_transform(n, Transform3D(Basis(x * patch, up, z * patch), to_local(at)))
		mm.set_instance_custom_data(n, Color(mass, stage_of(c), float(_layers[c.dominant]), seed))
		n += 1
		if n >= MAX_DRAWN:
			break
	mm.visible_instance_count = n


## Where a cell's litter is in its rotting, 0-4 (stages, mass-weighted).
func stage_of(c: Cell) -> float:
	var mass := c.mass()
	if mass <= 0.0:
		return 0.0
	return (c.m[1] + 2.0 * c.m[2] + 3.0 * c.m[3] + 4.0 * c.m[4]) / mass


## Wading: a rustle per stride in deep litter, a kick when running into
## a cell.
func _player_step(delta: float) -> void:
	if main == null or main.player == null:
		return
	var p: PlanetPlayer = main.player
	if not p.is_on_floor():
		return
	var k := key_of(p.surface_dir)
	var c: Cell = cells.get(k)
	var cm := c.mass() * float(PILE.get("cm_per_kg_m2", 6.0)) if c else 0.0
	var speed := p.velocity.length()
	if cm > float(PILE.get("rustle_cm", 3.0)) and speed > 0.4:
		_stride += speed * delta
		if _stride > 0.8:
			_stride = 0.0
			_rustle.global_position = p.global_position
			_rustle.stream = SoundSynth.stream("rustle", _rustle_n)
			_rustle.volume_db = lerpf(-18.0, -4.0, clampf(speed / PlanetPlayer.SPRINT_SPEED, 0.0, 1.0))
			_rustle_n += 1
			_rustle.play()
	if k != _player_cell:
		_player_cell = k
		# Running into a cell kicks its top layer (the fresh and dry
		# leaves) up.
		if c and speed > PlanetPlayer.WALK_SPEED * 1.4 and cm > float(PILE.get("rustle_cm", 3.0)):
			var share := float(PILE.get("kick_share", 0.15))
			var kicked := (c.m[0] + c.m[1]) * share
			c.m[0] *= 1.0 - share
			c.m[1] *= 1.0 - share
			if leaf_season and c.dominant >= 0:
				leaf_season.kick(p.global_position, p.up, c.dominant, int(clampf(kicked * 200.0, 4.0, 30.0)))
			_redraw()
