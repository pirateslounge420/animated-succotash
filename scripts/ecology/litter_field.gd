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
## It rots (§AI 3-4, data/litter.json "stages" and "timing"): each stage
## passes its litter on to the next at a first-order rate, the stage's
## days_at_reference at 15 °C and moisture 0.6, faster by Q10 per 10 °C
## (below 0 °C only freeze_rate as fast), by the moisture_curve (the
## place's moisture, soaked by recent rain) and by the dominant species'
## leaf (species_multiplier: needles 0.25x, glossy 0.5x, big leaves
## slower...). Dry litter turns wet-dark only after rain. What leaves the
## humus stage goes into the soil: flora_litter_kg (the flora.litter
## ledger; per cell, humus_at()), which soil fertility will read (Phase 7).
## Litter fungi (any species whose `fungus.substrate` is "litter") fruit
## on cells in the wet-dark and skeleton stages fungus.fruit_after_rain_days
## after rain, in their season and temperature band, for a few days.
##
## Only the ground near the player gathers litter (the trees LeafSeason
## watches); a cell keeps its litter, and goes on rotting, when you walk
## away.

static var PILE: Dictionary = Tuning.section("litter", "pile")
static var FALL: Dictionary = Tuning.section("litter", "fall")
static var TIMING: Dictionary = Tuning.section("litter", "timing")
static var STAGES: Array = Tuning.table("litter").get("stages", [])
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
	## Humus passed into the soil here, kg/m2.
	var humus := 0.0
	## Fungi fruiting here: [species index, until (days)], or empty.
	var fruit: Array = []

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


## The humus passed into the soil so far, kg (flora.litter).
var flora_litter_kg := 0.0
var _wet := 0.0 # recent rain, 1 just rained, fading over a couple of days
var _dry_days := 99.0 # game-days since it last rained
var _fruit_mmis := {} # fungus species index -> MultiMeshInstance3D
var _days := 0.0


## The humus a cell has given the soil, kg/m2.
func humus_at(d: Vector3) -> float:
	var c: Cell = cells.get(key_of(d))
	return c.humus if c else 0.0


## How much faster than at the reference a species' litter rots
## (timing.species_multiplier, by leaf type, else by surface texture;
## big leaves slower).
static func rot_multiplier(sp: PlantSpecies) -> float:
	var t: Dictionary = TIMING.get("species_multiplier", {})
	var k := 1.0
	if t.has(sp.leaf_type):
		k = float(t[sp.leaf_type])
	elif t.has(sp.leaf_texture):
		k = float(t[sp.leaf_texture])
	if sp.leaf_m * 100.0 > float(t.get("large_leaf_over_cm", 40.0)):
		k *= float(t.get("large_leaf_factor", 0.8))
	return k


## How fast litter rots here and now against the reference (15 °C,
## moisture 0.6): Q10 per 10 °C, freeze_rate below 0 °C, times the
## moisture curve.
static func climate_rate(temp_c: float, moisture: float) -> float:
	var q10 := float(TIMING.get("q10", 2.0))
	var t_ref := float(TIMING.get("reference_temp_c", 15.0))
	var r := pow(q10, (temp_c - t_ref) / 10.0) if temp_c > 0.0 else float(TIMING.get("freeze_rate", 0.02))
	return r * _curve(TIMING.get("moisture_curve", [[0.0, 0.1], [0.6, 1.0], [1.0, 1.6]]), moisture)


static func _curve(pts: Array, x: float) -> float:
	if pts.is_empty():
		return 1.0
	if x <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		if x <= float(pts[i][0]):
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6))
	return float(pts[pts.size() - 1][1])


## Litter rots over `dd` game-days (§AI 3-4).
func age(dd: float, weather: Dictionary) -> void:
	if dd <= 0.0:
		return
	_days += dd
	var rain := float(weather.get("rain_mm_h", 0.0))
	if rain > 0.1:
		_wet = 1.0
		_dry_days = 0.0
	else:
		_wet *= exp(-dd / 2.0)
		_dry_days += dd
	var moist := 0.6
	if main and main.world and main.world.planet:
		moist = main.world.planet.sample(main.world.planet.moisture, main.player.surface_dir)
	moist = clampf(maxf(moist, _wet), 0.0, 1.0)
	var rate := climate_rate(float(weather.get("temp_c", 15.0)), moist)
	var all := SpeciesDB.all()
	var days_ref := PackedFloat32Array()
	for i in 5:
		days_ref.append(float(STAGES[mini(i, STAGES.size() - 1)].get("days_at_reference", 30.0)) if not STAGES.is_empty() else 30.0)
	var fungi := _litter_fungi() if _dry_days >= 2.0 and _dry_days <= 5.0 else []
	for k in cells:
		var c: Cell = cells[k]
		if c.mass() <= 0.0:
			continue
		var r := rate * (rot_multiplier(all[c.dominant]) if c.dominant >= 0 else 1.0)
		for s in range(4, -1, -1):
			if c.m[s] <= 0.0:
				continue
			var kr := r
			if s == 1:
				# Dry leaves turn wet-dark after rain.
				kr *= 0.3 + 0.7 * _wet
			var out := c.m[s] * (1.0 - exp(-dd * kr / days_ref[s]))
			c.m[s] -= out
			if s < 4:
				c.m[s + 1] += out
			else:
				c.humus += out
				flora_litter_kg += out * _cell_m * _cell_m
		_fruit(c, k, fungi)
	_draw_fruit()


## Litter fungi fruit on wet-dark and skeleton litter a few days after
## rain, in their season and temperature band, then go.
func _fruit(c: Cell, k: Vector3i, fungi: Array) -> void:
	if not c.fruit.is_empty():
		if _days > float(c.fruit[1]):
			c.fruit = []
		return
	if c.m[2] + c.m[3] < 0.03 or fungi.is_empty():
		return
	# One try per cell per rain: a third of the cells fruit.
	var h := absi(hash([k, int(_days - _dry_days)]))
	if h % 3 != 0:
		return
	var sp_idx: int = fungi[h % fungi.size()]
	var sp: PlantSpecies = SpeciesDB.all()[sp_idx]
	var f: Dictionary = _fungus_block(sp)
	var window: Array = f.get("fruit_after_rain_days", [2, 5])
	if _dry_days < float(window[0]) or _dry_days > float(window[1]):
		return
	c.fruit = [sp_idx, _days + 5.0]


## The litter fungi that can fruit now (their season, their temperature;
## by default the season and temperature where the player is).
func _litter_fungi(season := "", temp := INF) -> Array:
	var out := []
	if main and season == "":
		var d: Vector3 = main.player.surface_dir
		season = str(Seasons.at(main.world.days, CubeSphere.latitude(d)).name)
	if main and temp == INF:
		temp = float(main._weather_eased.get("temp_c", 15.0))
	season = "any" if season == "" else season
	temp = 15.0 if temp == INF else temp
	for i in _litter_species():
		var sp: PlantSpecies = SpeciesDB.all()[i]
		var fs := str(_fungus_block(sp).get("fruit_season", "any"))
		if (fs == "any" or fs == season) and temp >= sp.temp_c.x - 3.0 and temp <= sp.temp_c.y + 3.0:
			out.append(i)
	return out


static var _litter_sp: Array = []
static var _fungus := {}


## The fungi with fungus.substrate "litter", from every loaded file (the
## biome files carry them since the §CC trim archived the fungi catalogue).
static func _litter_species() -> Array:
	if not _litter_sp.is_empty():
		return _litter_sp
	var all := SpeciesDB.all()
	for i in all.size():
		var sp: PlantSpecies = all[i]
		if str(sp.fungus.get("substrate", "")) == "litter":
			_fungus[i] = sp.fungus
			_litter_sp.append(i)
	return _litter_sp


static func _fungus_block(sp: PlantSpecies) -> Dictionary:
	return _fungus.get(SpeciesDB.index_of(sp), {})


## The fruiting bodies: a few of the species' mesh on each fruiting cell.
func _draw_fruit() -> void:
	if main == null:
		return
	var per := {}
	for k in cells:
		var c: Cell = cells[k]
		if not c.fruit.is_empty():
			if not per.has(c.fruit[0]):
				per[c.fruit[0]] = []
			per[c.fruit[0]].append(k)
	for idx in _fruit_mmis:
		if not per.has(idx):
			(_fruit_mmis[idx] as MultiMeshInstance3D).multimesh.visible_instance_count = 0
	for idx in per:
		var sp: PlantSpecies = SpeciesDB.all()[idx]
		if not _fruit_mmis.has(idx):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.use_colors = true
			mm.mesh = PlantMeshes.mesh_for(sp, PlantMeshes.LOD_NEAR)
			mm.instance_count = 400
			var mi := MultiMeshInstance3D.new()
			mi.name = "Fruiting_" + sp.name
			mi.multimesh = mm
			mi.material_override = PlantMeshes.material_for(sp)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.custom_aabb = AABB(Vector3.ONE * -DRAW_M * 3.0, Vector3.ONE * DRAW_M * 6.0)
			add_child(mi)
			_fruit_mmis[idx] = mi
		var mmi: MultiMeshInstance3D = _fruit_mmis[idx]
		var n := 0
		var rng := RandomNumberGenerator.new()
		for k in per[idx]:
			var c: Cell = cells[k]
			rng.seed = hash(k)
			for j in 4:
				if n >= 400:
					break
				var e := CubeSphere.east(c.dir)
				var nn := CubeSphere.north(c.dir)
				var d := (c.dir + (e * rng.randf_range(-1.6, 1.6) + nn * rng.randf_range(-1.6, 1.6)) / PlanetConst.RADIUS_M).normalized()
				var at: Vector3 = main.world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
				var hgt := rng.randf_range(sp.height_m.x, sp.height_m.y)
				var b := Basis(e, d, e.cross(d)).orthonormalized().rotated(d, rng.randf() * TAU).scaled(Vector3.ONE * hgt)
				mmi.multimesh.set_instance_transform(n, Transform3D(b, to_local(at)))
				mmi.multimesh.set_instance_color(n, Color.WHITE)
				mmi.multimesh.set_instance_custom_data(n, Color(0, 0, 0, 0))
				n += 1
		mmi.multimesh.visible_instance_count = n


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
