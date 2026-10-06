class_name CrawlerMain
extends Node
## Torchfire 1 (design 6 Oct §ET; scenes/crawler.tscn, opened by the boot
## scene when data/game.json says torchfire1): the ambient first-person
## dungeon crawler, first slice (§ET.11):
##
##   1. the switch: the open world (planet, roads, ecology, weather, the
##      camp sim) is not built here at all; it stays in scenes/main.tscn,
##      compiling and checked (GameMode).
##   2. the hearth room (§ET.3): you wake underground on a mat by a lit
##      hearth, the one who found you standing across it, a bundle of
##      unlit torches beside it, three or four ways out; the tomb beyond
##      generated from the seed out of the tomb kit (TombKit, TombBuild).
##   3. relighting (§ET.4): cold fire-holders down the tomb, lit with the
##      torch's swing (§CN), staying lit, and a torch relights at any of
##      them; between them full dark (§BA, §CJ.5: no sun, no sky, only a
##      faint navy so nothing is grey).
##   4. the torch's snuff rules (§ET.7, TorchSnuff, Airways).
##   5. the rescuer as a baked sprite (§ET.8, FigureSprite).
##
## Wordless (§ET.3: no tooltips): no prompts, no HUD lines. The log keeps
## its lines (Enter), O the settings, F11 the pixel size, F2 the frame
## time. Right click takes a torch from the bundle; left click swings the
## torch; Q puts it away or takes it out. No combat, no harm, no dread
## meter yet (the dark is the absence of light in this slice).

static var LOOKD: Dictionary = Tuning.table("crawler").get("look", {})
static var RES: Dictionary = Tuning.table("crawler").get("rescuer", {})

var world: Node
var lay: Dictionary
var tomb: Node3D
var fires: CrawlerFires
var airways: Airways
var vents: Vents
var player: CrawlerPlayer
var rescuer: FigureSprite
var post: PostGrade
var fire_shadows: FireShadows
var environment: Environment
var ui: CanvasLayer
var perf: PerfReadout
var log_panel: LogPanel
var settings_panel: SettingsPanel
var _fade: ColorRect
var _lit_logged := 0
## The rescuer's sheet is baked (tests wait on it).
var baked := false


func _ready() -> void:
	GameMode.crawler_running = true
	Controls.ensure()
	Display.install(get_window())
	HudText.install()
	AudioMix.apply()
	Look.prepare()
	world = get_node("/root/World")
	GameLog.entries.clear()
	var seed_value := _seed()
	lay = TombKit.layout(seed_value)
	_environment()
	_build_tomb()
	fires = CrawlerFires.new()
	fires.name = "Fires"
	add_child(fires)
	fires.build(world, lay)
	# Every permanent fire's vent (the vents rule): its daylight, soot and
	# draft.
	vents = Vents.new()
	vents.name = "Vents"
	add_child(vents)
	vents.build(world, lay, fires)
	airways = Airways.new()
	airways.name = "Airways"
	add_child(airways)
	airways.build(lay)
	TorchSnuff.drafts = airways
	Torch.weather = {}
	Campfire.night = 1.0
	player = CrawlerPlayer.new()
	player.name = "Player"
	player.world = world
	add_child(player)
	var w: Array = lay.wake
	player.spawn_flat(w[0], float(w[1]), -0.32)
	airways.exclude = [player.get_rid()]
	FireShadows.mode = str(LOOKD.get("fire_shadow_mode", "cube"))
	fire_shadows = FireShadows.new()
	fire_shadows.name = "FireShadows"
	add_child(fire_shadows)
	fire_shadows.setup(func(): return get_viewport().get_camera_3d())
	post = PostGrade.new()
	add_child(post)
	post.set_night(1.0)
	_sound()
	_ui()
	EngineReport.check_shaders()
	print("[engine] %s · %s" % [EngineReport.summary(), EngineReport.shaders_text()])
	GameLog.add("Tomb %d — %d ways out of the hearth room, %d cold lights below." % [seed_value, int(lay.exits), fires.holders.size()], "world")
	print("[crawler] seed %d: %d pieces, %d exits, %d holders, %d airways, %d vents (%d with daylight); %s masonry: %d stones on %d wall faces, %d triangles" % [seed_value, (lay.pieces as Array).size(), int(lay.exits), fires.holders.size(), (lay.airways as Array).size(), (lay.vents as Array).size(), vents.shafts.size(), FittedStone.preset_name(), int(tomb.get_meta("stones")), int(tomb.get_meta("faces")), int(tomb.get_meta("triangles"))])
	_bake_rescuer.call_deferred()


func _exit_tree() -> void:
	GameMode.crawler_running = false
	FireShadows.mode = ""
	TorchSnuff.drafts = null
	NodeRelease.detach_all(self)
	Look.finish()
	SculptedBodies.finish()


## A new tomb each game (§ET.10 call 3, Claude's reading): SEED in the
## environment pins one.
func _seed() -> int:
	var env := OS.get_environment("SEED")
	if env.is_valid_int():
		return int(env)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 999999)


## Underground (crawler.json look): no sun, no sky; a faint navy ambient
## so the unlit is navy, never grey; the haze the depth's own dark.
func _environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(str(LOOKD.get("fog_color", "#05081c")))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(str(LOOKD.get("ambient_color", "#141c5c")))
	environment.ambient_light_energy = float(LOOKD.get("ambient_energy", 0.05))
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = SkySystem.tonemapper()
	environment.tonemap_exposure = SkySystem.tonemap_exposure()
	environment.adjustment_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.ssr_enabled = false
	environment.sdfgi_enabled = false
	var b: Variant = Look.RETRO.get("bloom", {})
	var bloom: Dictionary = b if b is Dictionary else {"enabled": bool(b)}
	environment.glow_enabled = bool(bloom.get("enabled", false))
	environment.glow_hdr_threshold = float(bloom.get("hdr_threshold", 1.0))
	environment.glow_intensity = float(bloom.get("intensity", 0.25))
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	# The look's shared values for a flat world under the ground: "up" is
	# +y and the planet is far below (so heights are just y), no mist, no
	# far edge, no sites glowing, the night palette.
	Look.apply({
		"look_up": Vector3.UP,
		"look_planet_center": Vector3(0.0, -1.0e6, 0.0),
		"look_planet_radius": 1.0e6,
		"look_ground_m": -50.0,
		"look_fog_color": Color(str(LOOKD.get("fog_color", "#05081c"))),
		"look_fog_density": float(LOOKD.get("fog_density", 0.025)),
		"look_fog_start_m": 2.0,
		"look_draw_m": 0.0,
		"look_mist_density": 0.0,
		"look_night": 1.0,
		"look_glow": 0.0,
		"look_shadow_reach_m": 0.0,
	})


## The tomb's stone: one mesh lit per pixel (the delves' material: only
## fire lights it) and its collision.
func _build_tomb() -> void:
	var data := TombBuild.build(lay)
	tomb = Node3D.new()
	tomb.name = "Tomb"
	add_child(tomb)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.v
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_COLOR] = data.c
	arrays[Mesh.ARRAY_TEX_UV] = data.m
	RuinBuilder._flip_winding(arrays)
	# In blocks of CHUNK_M, so what's out of view isn't drawn (the fitted
	# stones are real geometry, masonry.json).
	for part in _chunks(arrays):
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part)
		var mi := MeshInstance3D.new()
		mi.name = "Stone"
		mi.mesh = mesh
		mi.material_override = RuinBuilder.material_lit()
		tomb.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = PropCollision.WORLD_LAYER
	tomb.add_child(body)
	var faces: PackedVector3Array = data.cv
	var step := RuinBuilder.COLLISION_PIECE * 3
	for from in range(0, faces.size(), step):
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces.slice(from, mini(from + step, faces.size())))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	for h in data.ch:
		PropCollision.hull(body, h)
	tomb.set_meta("triangles", (data.v as PackedVector3Array).size() / 3)
	tomb.set_meta("stones", int(data.get("stones", 0)))
	tomb.set_meta("faces", int(data.get("faces", 0)))


## The tomb's triangles sorted into CHUNK_M blocks by their middles:
## [arrays...].
const CHUNK_M := 10.0


static func _chunks(arrays: Array) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var m: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	# Triangle indices per block first (Arrays are shared; packed arrays
	# are copied on write, so they're filled once per block after).
	var buckets := {}
	for t in range(0, v.size() - 2, 3):
		var mid := (v[t] + v[t + 1] + v[t + 2]) / 3.0
		var key := Vector3i(floori(mid.x / CHUNK_M), floori(mid.y / CHUNK_M), floori(mid.z / CHUNK_M))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(t)
	var out: Array = []
	for key in buckets:
		var tris: Array = buckets[key]
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var pc := PackedColorArray()
		var pm := PackedVector2Array()
		pv.resize(tris.size() * 3)
		pn.resize(tris.size() * 3)
		pc.resize(tris.size() * 3)
		pm.resize(tris.size() * 3)
		var i := 0
		for t in tris:
			for k in 3:
				pv[i] = v[t + k]
				pn[i] = n[t + k]
				pc[i] = c[t + k]
				pm[i] = m[t + k]
				i += 1
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pv
		a[Mesh.ARRAY_NORMAL] = pn
		a[Mesh.ARRAY_COLOR] = pc
		a[Mesh.ARRAY_TEX_UV] = pm
		out.append(a)
	return out


## The tomb's own sound: the delve's low drone and its drips (SoundBed's
## delve layer, §CJ), everywhere at once; the fires and the airways are
## sources you walk to.
func _sound() -> void:
	for pair in [["delve_loop", -14.0], ["drips_loop", -20.0]]:
		var a := AudioStreamPlayer.new()
		a.name = str(pair[0]).capitalize().replace(" ", "")
		a.stream = SoundSynth.stream(str(pair[0]), 0)
		a.volume_db = float(pair[1])
		a.bus = AudioMix.bus("ambience")
		add_child(a)
		a.play()


func _ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	perf = PerfReadout.new()
	ui.add_child(perf)
	log_panel = LogPanel.new()
	log_panel.name = "Log"
	ui.add_child(log_panel)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	ui.add_child(settings_panel)
	# Waking: the dark lifts once the rescuer is ready (FigureSprite's bake).
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.01)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)


## The one who found you (§ET.3), standing across the hearth: built on the
## shared rig, baked to its sheet (§ET.8), then shown as the sprite.
func _bake_rescuer() -> void:
	var r: Array = lay.rescuer
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "rescuer"])
	var height := float(RES.get("height_m", 1.62))
	var pal := CloakedFigure.roll_palette(rng, CloakedFigure.tribe_family(int(lay.seed)))
	var b := CloakedFigure.build(height, pal[0], pal[1])
	var body: PlayerBody = b.root
	var beast := str(RES.get("beast", "seed"))
	if beast == "seed":
		var all := BeastHeads.animals()
		beast = str(all[rng.randi_range(0, all.size() - 1)]) if not all.is_empty() else ""
	var n_frames := maxi(int(RES.get("idle_frames", 4)), 1)
	var px := int(RES.get("px", 96))
	var base := body.scale
	var pose := func(n: Node3D, f: int, n_all: int) -> void:
		# The idle: a slow breath, the shoulders rising a little.
		var k := sin(TAU * f / maxf(n_all, 1.0))
		n.scale = Vector3(base.x, base.y * (1.0 + 0.014 * k), base.z)
	var sheet: Image
	if DisplayServer.get_name() == "headless":
		# No renderer: an empty sheet of the right size (the checks).
		var cols := int(FigureSprite.SP.get("around", 8)) * n_frames
		var rows := (FigureSprite.SP.get("rows_deg", [-25, 0, 30]) as Array).size()
		sheet = Image.create(int(round(px * 0.75)) * cols, px * rows, false, Image.FORMAT_RGBA8)
		body.queue_free()
	else:
		# The head goes on once the body is in its little world.
		var holder := Node3D.new()
		holder.add_child(body)
		body.ready.connect(func(): body.set_beast(beast), CONNECT_ONE_SHOT)
		sheet = await FigureSprite.bake(self, holder, height, px, n_frames, pose)
	rescuer = FigureSprite.new()
	rescuer.name = "Rescuer"
	add_child(rescuer)
	rescuer.global_position = r[0]
	rescuer.setup(sheet, height, n_frames, height * 0.93, float(r[1]))
	rescuer.set_meta("beast", beast)
	baked = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.5)
	tw.tween_callback(func(): _fade.visible = false)


func _process(_delta: float) -> void:
	player.typing = log_panel.visible
	player.ui_open = settings_panel.visible or log_panel.visible
	if player.torch.note != "":
		# Wordless (§ET.3): the torch's lines go to the log only.
		player.torch.note = ""
	var lit := fires.lit_count()
	if lit > _lit_logged:
		_lit_logged = lit
		GameLog.add("%d of %d lights burn again." % [lit, fires.holders.size()], "relit")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("settings") or (event.is_action_pressed("release_mouse") and settings_panel.visible):
		_toggle_settings(not settings_panel.visible)
	elif settings_panel.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		settings_panel.click(event.position)
	elif settings_panel.visible and event is InputEventMouseMotion:
		settings_panel.drag(event.position)
	elif event.is_action_pressed("log") and not log_panel.visible and not settings_panel.visible:
		log_panel.open()
	elif event.is_action_pressed("dev_pixel"):
		var pname := Display.cycle_preset()
		print("[display] preset %s" % pname)
	elif event.is_action_pressed("dev_perf"):
		perf.toggle()
	elif event.is_action_pressed("interact"):
		take_torch()


## Right click by the bundle: one unlit torch into your hand (§AW); a
## second while you hold one goes into your pack as a spare.
func take_torch() -> bool:
	if not fires.bundle_in_reach(player.global_position, CrawlerPlayer.REACH_M + 0.4):
		return false
	var it := fires.take_torch()
	if it.is_empty() or not player.inventory.add(it):
		return false
	if player.weapon != "torch":
		player.weapon = "torch"
		player.torch.block_until_release()
	GameLog.add("Took a torch from the bundle.", "torch")
	return true


## A new tomb (the settings panel's "New world").
func start_new_world() -> void:
	get_tree().reload_current_scene()


func _toggle_settings(on: bool) -> void:
	if on:
		settings_panel.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		settings_panel.close()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.torch.block_until_release()
