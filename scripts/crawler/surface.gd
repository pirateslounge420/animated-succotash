class_name Surface
extends Node3D
## The surface above the tomb (design 9 Oct §FM.7; §EW.1 and §EW.7 step 2;
## §FK.1 and §FK.3; data/worlds.json surface): take the stair up out of the
## dungeon and you come out at the ruin over it, on a bounded pocket of the
## dungeon's own world, its biome's land under the sky (worlds.json
## worlds.<surface.world>: the desert sandstone, biome hot_desert, the
## tomb's boss's world), day, dusk or night on the one clock. Ambience only:
## nothing up here is gated by the time of day, nothing is needed, and
## nothing hunts you.
##
##   the land     SurfaceGround: the basin, the wash, the escarpment that
##                closes it (the land itself, never an invisible wall, §DM),
##                the landmark butte, the far ranges (§EW.5's near, mid and
##                far, no other world's landmark yet)
##   the stone    SurfaceBuild: the ruin over the stair (the old way in, up
##                from the dungeon's way out, §EX.5), the vents' stacks and
##                slots (§EV.4), the finds (§FG: ruin remains, litter, old
##                camp marks), all in the tomb's one stone (§EX.1)
##   the plants   SurfacePlants: the biome's associations, by their real
##                silhouettes (§EW.1, §CS)
##   the vine     SacredVine: the world's sacred plant, one, hung from one of
##                those trees, to harvest (§FM.7, queue 72; Brew)
##   the life     SurfaceLife: the ecology's ground archetypes that fit the
##                biome, seen in passing (§EW.1)
##   the sky      the open world's SkySystem (the look's sky, sun, moon,
##                stars, ambient and haze, §ES), on the one clock
##                (SkySystem.one_clock, §FK.3): the same World.days the
##                shafts below read (Vents.sun_deg), never a copy; the sun
##                the one light, shade navy, distance lighter and bluer
##                (sky.fog_day / fog_night, no far edge: the land closes the
##                view)
##   the smoke    the hearth's column out of its stack, from the hearth's own
##                state below; at night a faint glow in the stack's mouth
##                (smoke.json outlets.night_mouth)
##   the sound    the wind; cicadas by day, crickets by night (sound)
##
## No map, no fast travel, no passage to another world (§EW.7 steps 3 and 4,
## §FM.8); the interact button answers only the vine up here (Brew). CrawlerMain carries you up and down (go_up, go_down): the
## dungeon kept as you left it below, this kept as you left it above.
## Built the first time you go up, from the dungeon's own seed (§FK.2: the
## same land every time for this game).

static var W: Dictionary = _json("res://data/worlds.json")
static var S: Dictionary = W.get("surface", {})


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

var world: Node
var lay: Dictionary
var seed_value := 0
var land: SurfaceGround
## SurfaceBuild's stairhead ({"bottom", "mouth", "arrive", "n", "side",
## "y", "drop", "run", "half", "yard", ...}) and what it built.
var stair: Dictionary = {}
var stacks: Array = []
var slots: Array = []
var finds: Array = []
var stone: Node3D
var ground_node: Node3D
var plants: SurfacePlants
## The world's sacred plant, one, to harvest (design §FM.7, queue 72;
## SacredVine; null if it can't be drawn or has no tree).
var vine: SacredVine
var life: SurfaceLife
var sky: SkySystem
## The hearth below (its state drives the smoke; read only).
var hearth: Node3D
## [{"col", "foot", "glow" (MeshInstance3D), "mat"}].
var _smokes: Array = []
var _sounds := {}
## What going up changed, put back going down (enter / leave).
var _kept := {}
var _main: Node
## Build times (ms), for the log and the checks.
var ms := {}
## The weather up here: fair, a little cloud, a breeze (sky.cloud,
## wind_mps). Not simulated (§EW.6).
var weather := {}


## Does dungeon `lay` have this surface above it? (surface.on, and its
## theme one of over_themes; any other keeps exit.stand_in, §EX.5.)
static func covers(p_lay: Dictionary) -> bool:
	return bool(S.get("on", true)) and (S.get("over_themes", ["tomb"]) as Array).has(str(p_lay.get("theme", "tomb")))


## The world the surface is (worlds.json worlds.<surface.world>).
static func world_entry() -> Dictionary:
	return (W.get("worlds", {}) as Dictionary).get(str(S.get("world", "desert")), {})


## Its biome's key (data/biomes): the world's biome, upper case.
static func biome_key() -> String:
	return str(world_entry().get("biome", "hot_desert")).to_upper()


## Its biome's file (data/biomes, by key), {} if none.
static func biome_doc() -> Dictionary:
	var key := biome_key()
	var dir := DirAccess.open("res://data/biomes")
	if dir == null:
		return {}
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes/" + f))
		if doc is Dictionary and str(doc.get("key", "")) == key:
			return doc
	return {}


static var _climate := {}


## Its biome's climate: {"temp_c": Vector2, "moisture": Vector2}.
static func climate() -> Dictionary:
	if not _climate.is_empty():
		return _climate
	var cl: Dictionary = biome_doc().get("climate", {})
	var t: Array = cl.get("temp_c", [18.0, 35.0])
	var m: Array = cl.get("moisture", [0.0, 0.2])
	_climate = {"temp_c": Vector2(float(t[0]), float(t[1])), "moisture": Vector2(float(m[0]), float(m[1]))}
	return _climate


## The surface level (smoke.json vents.surface_y_m: where every vent's top
## already ends, metres over the hearth room's floor).
static func level() -> float:
	return float((Tuning.table("smoke").get("vents", {}) as Dictionary).get("surface_y_m", 9.0))


## The sun's height (degrees) up here at world time `days`: the one clock's
## (SkySystem.one_clock_sun over flat ground).
static func sun_deg_at(days: float) -> float:
	return rad_to_deg(asin(clampf(SkySystem.one_clock_sun(days, Vector3.UP, Vector3.RIGHT).y, -1.0, 1.0)))


## The surface over dungeon `p_lay`, its seed drawn from the dungeon's
## (§FK.2); `p_hearth` the hearth below. Builds everything but what needs
## the tree (the sky's own setup runs when it first enters).
func build(p_world: Node, p_lay: Dictionary, p_hearth: Node3D) -> void:
	name = "Surface"
	world = p_world
	lay = p_lay
	hearth = p_hearth
	seed_value = hash([int(lay.get("seed", 0)), "surface"])
	var t0 := Time.get_ticks_msec()
	var frame := SurfaceBuild.stair_frame(lay, S, level())
	land = SurfaceGround.new()
	land.setup(S, seed_value, frame.mouth, frame.n, level())
	land.carve_stair(frame)
	var t1 := Time.get_ticks_msec()
	ms["ground"] = t1 - t0
	_ground()
	var t2 := Time.get_ticks_msec()
	ms["ground_mesh"] = t2 - t1
	var data := SurfaceBuild.make(land, lay, S, seed_value)
	stair = data.stair
	stacks = data.stacks
	slots = data.slots
	finds = data.finds
	_stone(data)
	var t3 := Time.get_ticks_msec()
	ms["stone"] = t3 - t2
	# The plants, clear of the yard, the stacks and the finds.
	var keep_out: Array = [(stair.yard as Rect2).grow(2.0)]
	var cut := SurfaceBuild._rect(stair.bottom, stair.mouth, float(stair.half) + 2.0)
	keep_out.append(cut)
	for s in stacks:
		var f: Vector3 = s.foot
		keep_out.append(Rect2(Vector2(f.x, f.z) - Vector2(2.0, 2.0), Vector2(4.0, 4.0)))
	for s in slots:
		var a: Vector3 = s.at
		keep_out.append(Rect2(Vector2(a.x, a.z) - Vector2(0.8, 0.8), Vector2(1.6, 1.6)))
	for f in finds:
		var a: Vector3 = f.at
		var r := 8.0 if str(f.kind) != "litter" else 2.5
		keep_out.append(Rect2(Vector2(a.x, a.z) - Vector2(r, r), Vector2(2.0 * r, 2.0 * r)))
	plants = SurfacePlants.new()
	plants.name = "Plants"
	add_child(plants)
	plants.build(land, S, biome_doc(), seed_value, keep_out)
	# The world's sacred plant, hung from one of those trees (queue 72).
	vine = SacredVine.make(world, land, stair, plants.trees_placed, seed_value)
	if vine != null:
		add_child(vine)
	var t4 := Time.get_ticks_msec()
	ms["plants"] = t4 - t3
	life = SurfaceLife.new()
	add_child(life)
	life.setup(land, S, climate(), seed_value, null)
	# The sky on the one clock (§FK.3).
	sky = SkySystem.new()
	sky.name = "Sky"
	sky.one_clock = true
	sky.mist_place = float((S.get("sky", {}) as Dictionary).get("mist_place", 0.15))
	add_child(sky)
	_smoke()
	_sound()
	var K: Dictionary = S.get("sky", {})
	var wind_mps := float(K.get("wind_mps", 2.2))
	weather = {"cloud": float(K.get("cloud", 0.15)), "storm": 0.0, "rain_mm_h": 0.0, "wind": Vector3(0.8, 0.0, 0.6).normalized() * wind_mps, "clear": 1.0 - float(K.get("cloud", 0.15))}
	ms["all"] = Time.get_ticks_msec() - t0
	print("[surface] seed %d over tomb %d: %s, %d x %d ground at %.0f m (%d ms), the stairhead at %s, %d stacks and %d slots, %d finds, %d plants (%s), %d creatures (%s); built in %d ms" % [seed_value, int(lay.get("seed", 0)), biome_key(), land.count, land.count, land.cell, int(ms.ground) + int(ms.ground_mesh), str((stair.mouth as Vector2).snapped(Vector2.ONE * 0.1)), stacks.size(), slots.size(), finds.size(), plants.placed, ", ".join(plants.grown.values()), life.animals.size(), ", ".join(life.kinds.map(func(k): return k.name)), int(ms.all)])


## The ground's blocks (the terrain material), its collision and the far
## band.
func _ground() -> void:
	ground_node = Node3D.new()
	ground_node.name = "Ground"
	add_child(ground_node)
	var mat := TerrainChunk.terrain_material()
	var col := BiomeTemplates.color_of(BiomeTemplates.id_of_key(biome_key())) if BiomeTemplates.id_of_key(biome_key()) >= 0 else TerrainChunk.SAND
	var k := 0
	for b in land.block_arrays(col):
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b[0], [], {}, TerrainChunk.GROUND_FORMAT)
		var mi := MeshInstance3D.new()
		mi.name = "Block%d" % k
		mi.mesh = mesh
		mi.material_override = mat
		ground_node.add_child(mi)
		k += 1
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = PropCollision.WORLD_LAYER
	var c := land.collision()
	var cs := CollisionShape3D.new()
	cs.shape = c[0]
	cs.transform = c[1]
	body.add_child(cs)
	ground_node.add_child(body)
	var far := ArrayMesh.new()
	far.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, land.far_band_arrays(S, seed_value), [], {}, TerrainChunk.GROUND_FORMAT)
	var fmi := MeshInstance3D.new()
	fmi.name = "FarBand"
	fmi.mesh = far
	fmi.material_override = mat
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_node.add_child(fmi)


## The stone (SurfaceBuild's arrays): one mesh in blocks (CrawlerMain's
## chunks), the ruins' vertex-lit stone, and its collision.
func _stone(data: Dictionary) -> void:
	stone = Node3D.new()
	stone.name = "Stone"
	add_child(stone)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.v
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_COLOR] = data.c
	arrays[Mesh.ARRAY_TEX_UV] = data.m
	RuinBuilder._flip_winding(arrays)
	for part in CrawlerMain._chunks(arrays):
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = RuinBuilder.material()
		stone.add_child(mi)
	stone.add_child(CrawlerMain.collision_body(data))
	stone.set_meta("triangles", (data.v as PackedVector3Array).size() / 3)
	stone.set_meta("stones", int(data.get("stones", 0)))


## The hearth's smoke out of its stack, and the glow in each stack's mouth.
func _smoke() -> void:
	var lit_c := Torch.fire_color()
	for s in stacks:
		var col := Smoke.column(self, "Smoke%d" % int(s.vent))
		var mouth: Vector3 = s.mouth
		var disc := MeshInstance3D.new()
		disc.name = "MouthGlow"
		var q := QuadMesh.new()
		q.size = Vector2.ONE * maxf(float(s.d) * 0.85, 0.4)
		disc.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.01, 0.01, 0.02)
		disc.material_override = m
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc)
		disc.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), mouth - Vector3(0.0, 0.1, 0.0))
		_smokes.append({"col": col, "foot": mouth + Vector3(0.0, 0.1, 0.0), "glow": disc, "mat": m, "fire": int(lay.vents[int(s.vent)].fire_index), "lit_c": lit_c})


func _sound() -> void:
	for pair in [["wind", "wind_loop"], ["day", "cicadas_loop"], ["night", "insects_loop"]]:
		var a := AudioStreamPlayer.new()
		a.name = "Sound_" + str(pair[0])
		a.stream = SoundSynth.stream(str(pair[1]), 1)
		a.bus = AudioMix.bus("ambience")
		a.volume_db = -80.0
		a.autoplay = false
		add_child(a)
		_sounds[pair[0]] = a


# --- Up and down ----------------------------------------------------------------

## Where you come out (the yard, out_m past the portal, facing out along
## the way out): {"pos", "yaw"}.
func arrival() -> Dictionary:
	var a: Vector2 = stair.arrive
	var n: Vector2 = stair.n
	return {"pos": Vector3(a.x, float(stair.y) + 0.02, a.y), "yaw": atan2(-n.x, -n.y)}


## Has `pos` (feet, scene) gone down the stair (down_at_m past its mouth,
## between its walls, below the yard)?
func stepped_in(pos: Vector3) -> bool:
	if stair.is_empty():
		return false
	var n: Vector2 = stair.n
	var rel := Vector2(pos.x, pos.z) - (stair.mouth as Vector2)
	var down := -rel.dot(n)
	var lateral := absf(rel.dot(stair.side as Vector2))
	var at := float((S.get("stairhead", {}) as Dictionary).get("down_at_m", 3.0))
	return down > at and down < float(stair.run) + 1.5 and lateral < float(stair.half) + 0.3 and pos.y < float(stair.y) - 0.4


## Is `pos` (scene) on the pocket's walkable land (short of the cliff's foot)?
func inside(pos: Vector3, margin := 0.0) -> bool:
	return land != null and land.inside(Vector2(pos.x, pos.z), margin)


## Going up (CrawlerMain.go_up, the frame black): what the dungeon set put
## aside (its environment, the grade's night and floor and the firelight's
## pale whites, the look's haze, the half-dark, the camera's reach, its
## drone and drips), this world's put in.
func enter(main: Node) -> void:
	_main = main
	var player: CrawlerPlayer = main.player
	_kept = {"look": Look._params.duplicate(), "touched": {}, "campfire_night": Campfire.night, "half_dark": (main.half_dark as HalfDark).enabled,
		"far": player.camera().far if player.camera() != null else 400.0, "paused": [], "env": null, "wind": WeatherFX.plant_wind,
		"snuff": TorchSnuff.drafts}
	var pm := (main.post as PostGrade)._rect.material as ShaderMaterial
	var post := {}
	for k in ["night", "shadow_floor", "night_pull", "pull_luma", "fire_whites", "fire_white_tint", "fire_white_chroma"]:
		post[k] = pm.get_shader_parameter(k)
	_kept["post"] = post
	# The dungeon's environment out of the tree while the sky's is in it.
	for c in main.get_children():
		if c is WorldEnvironment:
			_kept["env"] = c
			main.remove_child(c)
			break
	for c in main.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing and not (c as AudioStreamPlayer).stream_paused:
			(c as AudioStreamPlayer).stream_paused = true
			(_kept.paused as Array).append(c)
	(main.half_dark as HalfDark).enabled = false
	if player.camera() != null:
		player.camera().far = float((S.get("sky", {}) as Dictionary).get("camera_far_m", 6000.0))
	# One firelight's pale whites are for firelit stone underground (§EX.6):
	# not for sunlit sand.
	(main.post as PostGrade).set_fire_whites(0.0, Torch.fire_color())
	TorchSnuff.drafts = null
	sky.vis_player = player
	life.player = player
	Footsteps.flat_ground = step_ground
	for k in _sounds:
		(_sounds[k] as AudioStreamPlayer).play()
	_update(0.0)


## What your steps sound on up here (Footsteps.flat_ground): the stone of
## the ruin and the finds, else the ground's own (sand on the basin's floor
## and in the wash, dirt on the talus, stone on rock).
func step_ground(player: PlanetPlayer) -> String:
	var from := player.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 0.8)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider is Node and (hit.collider as Node).get_parent() == stone:
		return "stone"
	var p := Vector2(player.global_position.x, player.global_position.z)
	if land.slope_at(p.x, p.y) > 0.8:
		return "stone"
	if land.zone_at(p, 0.0) == "edge" or not land.on_floor(p, -float(land.E.get("talus_width_m", 90.0)) * 0.6):
		return "dirt"
	return "sand"


## Going down (CrawlerMain.go_down, the frame black): everything enter()
## put aside, back as it was.
func leave(main: Node) -> void:
	for k in _sounds:
		(_sounds[k] as AudioStreamPlayer).stop()
	_restore_look()
	var pm := (main.post as PostGrade)._rect.material as ShaderMaterial
	var post: Dictionary = _kept.get("post", {})
	for k in post:
		pm.set_shader_parameter(k, post[k])
	Campfire.night = float(_kept.get("campfire_night", 1.0))
	(main.half_dark as HalfDark).enabled = bool(_kept.get("half_dark", true))
	var player: CrawlerPlayer = main.player
	if player.camera() != null:
		player.camera().far = float(_kept.get("far", 400.0))
	var env = _kept.get("env")
	if env != null and is_instance_valid(env) and not (env as Node).is_inside_tree():
		main.add_child(env)
	for c in _kept.get("paused", []):
		if is_instance_valid(c):
			(c as AudioStreamPlayer).stream_paused = false
	# The plants' wind as it was (WeatherFX keeps the shared value's copy;
	# reading the global back from the renderer is for the editor only).
	var wind = _kept.get("wind")
	RenderingServer.global_shader_parameter_set("plant_wind", wind if wind is Vector3 else Vector3.ZERO)
	TorchSnuff.drafts = _kept.get("snuff")
	Footsteps.flat_ground = Callable()
	sky.vis_player = null
	life.player = null
	_kept = {}
	_main = null


## The game closing while you are up here (CrawlerMain._exit_tree): the
## dungeon's own environment, kept out of the tree, goes with it.
func drop_kept() -> void:
	var env = _kept.get("env")
	if env != null and is_instance_valid(env) and not (env as Node).is_inside_tree():
		(env as Node).free()
	_kept = {}
	_main = null
	Footsteps.flat_ground = Callable()


## The look's shared values as they were before the surface touched them:
## the ones Look held then, and the shader globals' own defaults for the
## ones it never set (project.godot shader_globals).
func _restore_look() -> void:
	var before: Dictionary = _kept.get("look", {})
	var put := {}
	for k in Look._params:
		if before.has(k):
			put[k] = before[k]
		else:
			var def = ProjectSettings.get_setting("shader_globals/" + str(k))
			if def is Dictionary and def.has("value"):
				RenderingServer.global_shader_parameter_set(str(k), def.value)
	Look.apply(put)
	for k in Look._params.keys():
		if not before.has(k):
			Look._params.erase(k)


func _process(delta: float) -> void:
	if _main == null:
		return
	_update(delta)


## This frame's sky (the one clock, World.days: the same clock the dungeon
## below reads), haze, grade, smoke and sound.
func _update(delta: float) -> void:
	var days := float(world.get("days"))
	var K: Dictionary = S.get("sky", {})
	sky.update_sky(Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, days, weather, 0.0, delta)
	var night := 1.0 - sky.daylight
	# The pocket's own haze: from the eye, lighter and bluer with distance,
	# no far edge (the land closes the view); the surface level the mist's.
	var density := lerpf(float(K.get("fog_day", 0.0016)), float(K.get("fog_night", 0.0013)), night)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	Look.apply({"look_draw_m": 0.0, "look_fog_density": density, "look_fog_start_m": float(K.get("fog_start_m", 180.0)), "look_ground_m": land.base_y,
		"look_planet_center": Vector3(0.0, -1.0e6, 0.0), "look_planet_radius": 1.0e6,
		# The eye (the plants' leaves cast only near it, the open world's way).
		"look_eye": cam.global_position if cam != null else Vector3(stair.arrive.x, land.base_y, stair.arrive.y)})
	sky.environment.fog_density = density
	if _main != null:
		var post := _main.post as PostGrade
		post.set_night(night)
		post.set_floor(sky.post_floor, sky.night_pull, float((SkySystem.FLOOR.get("night", {}) as Dictionary).get("pull_below_luma", 0.35)))
	Campfire.night = night
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("plant_wind", wind)
	Smoke.wind = wind
	Smoke.sun_deg = sky.sun_elevation_deg
	Smoke.days = days
	Smoke.rain_mm_h = 0.0
	Smoke.calm_dawn = false
	# The hearth's smoke from its stack (only hearths smoke, §CV.1), and the
	# glow of the fire below in each stack's mouth at night.
	var scale := float((S.get("stacks", {}) as Dictionary).get("smoke_scale", 1.0)) * float(Smoke.H.get("stack_scale", 0.7))
	for s in _smokes:
		var fire: Node3D = hearth if int(s.fire) < 0 else null
		var state := FireStore.state_of(fire) if fire != null and fire.has_meta("fuel_key") else "flames"
		Smoke.update(s.col, s.foot, Vector3.UP, state, wind, 0.0, night, false, scale)
		var lit := state in ["flames", "low", "flare"]
		var want := Color(0.01, 0.01, 0.02).lerp((s.lit_c as Color) * 0.55, night * (1.0 if lit else 0.0))
		(s.mat as StandardMaterial3D).albedo_color = want
	life.daylight = sky.daylight
	var S2: Dictionary = S.get("sound", {})
	_volume("wind", float(S2.get("wind_db", -19.0)), 1.0)
	_volume("day", float(S2.get("day_db", -26.0)), sky.daylight)
	_volume("night", float(S2.get("night_db", -23.0)), night)


func _volume(key: String, db: float, share: float) -> void:
	var a: AudioStreamPlayer = _sounds.get(key)
	if a != null:
		a.volume_db = db + linear_to_db(maxf(share, 0.001))
