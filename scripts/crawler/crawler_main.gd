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
##      hearth, the one who found you sitting across it, a bundle of
##      unlit torches beside it, three or four ways out; the tomb beyond
##      generated from the seed out of the tomb kit (TombKit, TombBuild).
##   3. relighting (§ET.4, §EX.4): cold wall sconces down the tomb (on the
##      walls of every room past the hearth room, whose hearth is the
##      tomb's only one, and along the corridors), lit with the torch's
##      swing (§CN), staying lit, and a torch relights at any of them;
##      between them the dark (§BA, §CJ.5: no sun, no sky, only a faint
##      navy so nothing is grey), half readable near you when no flame is
##      (§FC.4, HalfDark).
##   4. the torch's snuff rules (§ET.7 as amended by §EZ.1 and §EZ.5:
##      only deep water puts it out; the airways lean it; TorchSnuff,
##      Airways), and F to smother it yourself (§FC.3, Torch.douse).
##   5. the one who found you, sitting at the hearth: the shared rig live
##      in 3D (§FH, HearthFolk; amends §ET.8 for folk, whose baked sprites,
##      FigureSprite, stay for creatures and bosses).
##   6. atmosphere, never a puzzle (§FG): glow-moss on damp stone that
##      dims when a flame comes near (GlowMoss), beetles and scarabs on
##      the walls that scatter from the light into the joints (WallLife),
##      and the world's clock running, so the daylight down the shafts
##      follows the sun (Vents).
##
## And the dungeon's boss (design §EY, Boss; bosses.json): the snake,
## prowling only the rooms and stretches not yet relit, driven into its
## hole by the last light. Its strikes are hits (Harm, §EA, with §FD's
## ring in the crawler): three and "Good night", and you wake on the mat
## by the hearth with every light you lit still burning.
##
## Then what lives in its dark below the boss (design §FE, queue 58;
## Residents): the tomb's skeletons, resting in its niches and coffins
## until you come too close, and hiding from them (§FC.2). Their strikes
## are hits too, and you heal only once nothing is after you (§FD); taken,
## every one after you gives you up and goes home.
##
## And always a way out (§EX.5, crawler.json exit): at the top of the long
## flight past the heart the old way in glows with faint daylight
## (WayOut). Stepping into it is the stand-in (exit.stand_in) until
## §EW.3's seam or §EW.7's surface is built: the screen fades out over
## fade_s, the next tomb is built from a new seed (next_seed: the same
## after a pinned SEED), and you arrive in its hearth room by its lit
## hearth, carrying what you carried, the torch lit or not as it was.
##
## Wordless (§ET.3: no tooltips): no prompts, no HUD lines. The one thing
## on screen is the open world's crosshair (§EX.7, Reticle, crawler.json
## hud), closing into a dim ring while you sneak (§FC.1), off with the
## Settings switch Crosshair dot and while the log or the settings cover
## the middle of the frame. The log keeps its lines (Enter), O the
## settings (with their Controls page, §FB), F11 the pixel size, F2 the
## frame time. Right click takes a torch from the bundle; left click
## swings the torch (lit, into a creature's wind-up, it staggers it:
## §FA.1, CreatureStrike); the mouse wheel puts it away or takes it out, and
## with Tab held the wheel steps the left hand through its strip of fire
## pots, shown while Tab is held (§FB: Hands, HandStrip; FirePots); F
## smothers the torch. When you are hurt, Harm's ring and, on the third
## hit, "Good night" (CrawlerHarmView). No dread meter (the dark is the
## absence of light, and the boss is the dark's body).

static var LOOKD: Dictionary = Tuning.table("crawler").get("look", {})
static var RES: Dictionary = Tuning.table("crawler").get("rescuer", {})
static var HUD: Dictionary = Tuning.table("crawler").get("hud", {})
static var EXIT: Dictionary = Tuning.table("crawler").get("exit", {})

var world: Node
## The tomb now: its seed and layout (TombKit), and what's built of it.
var seed_value := 0
var lay: Dictionary
var tomb: Node3D
var fires: CrawlerFires
## Fire pots (design §FA.3): lit off the torch, thrown (FirePots).
var fire_pots: FirePots
var airways: Airways
var vents: Vents
## Atmosphere (§FG): the glow-moss and the life on the walls, on the
## tomb's dressed wall faces (TombBuild wall_faces).
var glow_moss: GlowMoss
var wall_life: WallLife
var walls: Array = []
var way_out: WayOut
var player: CrawlerPlayer
## The dark you can half see in (§FC.4).
var half_dark: HalfDark
var rescuer: HearthFolk
## What lives in the dark below the boss (§FE): the tomb's skeletons.
var residents: Residents
var post: PostGrade
var fire_shadows: FireShadows
var environment: Environment
var ui: CanvasLayer
## The crosshair (§EX.7), or null when crawler.json hud.reticle is off.
var reticle: Reticle
var perf: PerfReadout
var log_panel: LogPanel
var settings_panel: SettingsPanel
## The strip Tab shows (§FB).
var hand_strip: HandStrip
## Three hits, "Good night" (§EA, §EC) and its view; the dungeon's boss
## (§EY); the tomb's small sounds (the drips), which the boss hushes.
var harm: Harm
var harm_view: CrawlerHarmView
var boss: Boss
var drips: AudioStreamPlayer
var _fade: ColorRect
var _lit_logged := 0
## The one who found you is at the hearth and the dark lifting (tests
## wait on it; the name is from when the rescuer was baked to a sprite).
var baked := false
## Walking out: the fade to the next tomb has begun (tests wait on it
## ending).
var leaving := false
## Tombs walked out of this session.
var walked_out := 0


func _ready() -> void:
	GameMode.crawler_running = true
	Controls.ensure()
	Display.install(get_window())
	HudText.install()
	AudioMix.apply()
	Look.prepare()
	world = get_node("/root/World")
	GameLog.entries.clear()
	_environment()
	Torch.weather = {}
	Campfire.night = 1.0
	player = CrawlerPlayer.new()
	player.name = "Player"
	player.world = world
	add_child(player)
	half_dark = HalfDark.new()
	half_dark.name = "HalfDark"
	add_child(half_dark)
	half_dark.setup(player)
	FireShadows.mode = str(LOOKD.get("fire_shadow_mode", "cube"))
	fire_shadows = FireShadows.new()
	fire_shadows.name = "FireShadows"
	add_child(fire_shadows)
	fire_shadows.setup(func(): return get_viewport().get_camera_3d())
	post = PostGrade.new()
	add_child(post)
	post.set_night(1.0)
	# One firelight (§EX.6, crawler.json firelight): stone the fire blows
	# pale or white goes back to the fire's amber before the grade.
	var fl: Dictionary = Tuning.table("crawler").get("firelight", {})
	var pc: Array = fl.get("pale_chroma", [0.3, 0.6])
	post.set_fire_whites(float(fl.get("pale_to_amber", 1.0)), Torch.fire_color().lerp(Color.WHITE, float(fl.get("lift", 0.15))), Vector2(float(pc[0]), float(pc[1])))
	_sound()
	_ui()
	harm = Harm.new()
	harm.name = "Harm"
	add_child(harm)
	harm.setup(player, post, null)
	player.died.connect(_on_taken)
	EngineReport.check_shaders()
	print("[engine] %s · %s" % [EngineReport.summary(), EngineReport.shaders_text()])
	_load_tomb(_seed())
	_rescuer()


## One tomb, all of it (TombKit's layout from `s`, its stone, fires,
## vents, airways and way out, the life on its walls, its residents, its
## fire pots' found pot and its boss), you standing on the mat by its
## hearth. The session's own (you and what you carry and
## hold, the grade, the HUD, the log) stays.
func _load_tomb(s: int) -> void:
	seed_value = s
	lay = TombKit.layout(s)
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
	airways.exclude = [player.get_rid()]
	TorchSnuff.drafts = airways
	way_out = WayOut.new()
	way_out.name = "WayOut"
	add_child(way_out)
	way_out.build(world, lay)
	fires.ray_exclude = [player.get_rid()]
	# Atmosphere, never a puzzle (§FG).
	glow_moss = GlowMoss.new()
	glow_moss.name = "GlowMoss"
	add_child(glow_moss)
	glow_moss.build(lay, walls, fires)
	wall_life = WallLife.new()
	wall_life.name = "WallLife"
	add_child(wall_life)
	wall_life.build(lay, walls, fires)
	# What lives in the dark (§FE): asleep in their places; kept to the dark
	# by the holders' light, and gone when the last one catches (§FF.2).
	residents = Residents.new()
	residents.name = "Residents"
	add_child(residents)
	residents.build(lay, player, fires)
	var w: Array = lay.wake
	player.spawn_flat(w[0], float(w[1]), -0.32)
	if fire_pots == null:
		fire_pots = FirePots.new()
		fire_pots.name = "FirePots"
		add_child(fire_pots)
		fire_pots.build(world, lay, player)
	else:
		fire_pots.retomb(lay)
	# The dungeon's boss (§EY): its ground, its lair, this tomb's.
	boss = Boss.new()
	add_child(boss)
	boss.build(lay, fires, player, drips)
	_lit_logged = 0
	GameLog.add("Tomb %d — %d ways out of the hearth room, %d cold lights below." % [s, int(lay.hearth_ways), fires.holders.size()], "world")
	print("[crawler] seed %d: %d pieces, %d ways from the hearth room, %d way out, %d holders, %d airways, %d vents (%d with daylight), %d residents; %s masonry: %d stones on %d wall faces, %d triangles; %d glow-moss patches, %d beetles and scarabs" % [s, (lay.pieces as Array).size(), int(lay.hearth_ways), (lay.exits as Array).size(), fires.holders.size(), (lay.airways as Array).size(), (lay.vents as Array).size(), vents.shafts.size(), residents.all.size(), FittedStone.preset_name(), int(tomb.get_meta("stones")), int(tomb.get_meta("faces")), int(tomb.get_meta("triangles")), glow_moss.patches.size(), wall_life.bugs.size()])


## The tomb's nodes gone (out of the tree at once, so nothing that walks
## the fire or light groups meets them again), for the next; their meshes
## let go of first (NodeRelease).
func _clear_tomb() -> void:
	# The drips back as they were before its prowl hushed them.
	if boss != null and is_instance_valid(boss) and drips != null:
		drips.volume_db = boss.bed_db
	for n in [tomb, fires, vents, airways, way_out, glow_moss, wall_life, residents, rescuer, boss]:
		var node := n as Node
		if node == null or not is_instance_valid(node):
			continue
		remove_child(node)
		NodeRelease.free_later(node)
	rescuer = null
	boss = null
	baked = false
	TorchSnuff.drafts = null


## The tomb after `s` (the stand-in's new seed, exit.stand_in): a seeded
## step, so a pinned SEED walks the same tombs every time.
static func next_seed(s: int) -> int:
	var n := posmod(hash([s, "the next tomb"]), 999999) + 1
	return n if n != s else posmod(n, 999999) + 1


func _exit_tree() -> void:
	GameMode.crawler_running = false
	PlayerBody.watch_point = Vector3(INF, INF, INF)
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
	tomb.add_child(collision_body(data))
	tomb.set_meta("triangles", (data.v as PackedVector3Array).size() / 3)
	tomb.set_meta("stones", int(data.get("stones", 0)))
	tomb.set_meta("faces", int(data.get("faces", 0)))
	walls = data.get("walls", [])


## The tomb's collision (TombBuild.build's "cv" faces and "ch" hulls) as
## one static body on the world's layer (the checks' walks use it too).
static func collision_body(data: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = PropCollision.WORLD_LAYER
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
	return body


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
		if str(pair[0]) == "drips_loop":
			drips = a


func _ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	# The crosshair (§EX.7): first, so the panels and the waking dark are
	# drawn over it.
	if bool(HUD.get("reticle", true)):
		reticle = Reticle.new()
		reticle.name = "Reticle"
		ui.add_child(reticle)
	perf = PerfReadout.new()
	ui.add_child(perf)
	log_panel = LogPanel.new()
	log_panel.name = "Log"
	ui.add_child(log_panel)
	# The hands' strip (§FB), under the panels.
	hand_strip = HandStrip.new()
	hand_strip.name = "HandStrip"
	hand_strip.hands = player.hands
	ui.add_child(hand_strip)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	ui.add_child(settings_panel)
	harm_view = CrawlerHarmView.new()
	ui.add_child(harm_view)
	# Waking: the dark lifts once the hearth room is ready (_rescuer).
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.01)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)


## The one who found you (§ET.3), sitting across the hearth on a low
## stone, facing it: the shared rig live in the scene (§FH, HearthFolk),
## its cloak rolled and its head picked from the seed as the sprite's were
## (rescuer.beast "seed"), so a seed keeps its rescuer; then the dark
## lifts over `fade_in_s`.
func _rescuer(fade_in_s := 2.5) -> void:
	var r: Array = lay.rescuer
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "rescuer"])
	var height := float(RES.get("height_m", 1.62))
	var pal := CloakedFigure.roll_palette(rng, CloakedFigure.tribe_family(int(lay.seed)))
	var beast := str(RES.get("beast", "seed"))
	if beast == "seed":
		var all := BeastHeads.animals()
		beast = str(all[rng.randi_range(0, all.size() - 1)]) if not all.is_empty() else ""
	rescuer = HearthFolk.make(self, "Rescuer", r[0], float(r[1]), height, pal, beast)
	# The boss's sprites before the dark lifts (FigureSprite.bake has the
	# view to itself).
	if boss != null:
		await boss.body.bake(self)
	# The residents: the floor they walk (the stone is in the physics world
	# by now) and their sheets (ResidentSprite), before the dark lifts too.
	await get_tree().physics_frame
	residents.build_nav()
	await residents.bake(self)
	baked = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, fade_in_s)
	tw.tween_callback(func(): _fade.visible = false)


func _process(delta: float) -> void:
	# The world's clock, the 144-minute day (DayCycle; World.day_length_s):
	# World turns it only once a planet is generated and the crawler builds
	# none, so the crawler turns it (design §FG: the daylight down the
	# shafts follows it).
	world.days = float(world.get("days")) + delta / maxf(float(world.get("day_length_s")), 1.0)
	# The folk at the hearth look to you while you're near and in front of
	# them (the rig's head-look watches the player's head; here, your eyes).
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		PlayerBody.watch_point = cam.global_position
	# (Taken, the keys let go while "Good night" plays: Harm; walking out,
	# you stand still in the opening while the dark comes.)
	player.typing = log_panel.visible or (harm != null and harm.taking) or leaving
	player.ui_open = settings_panel.visible or log_panel.visible
	if reticle != null:
		# In first person, and not over a panel: both cover the middle.
		reticle.shown = player.first_person and not player.ui_open
		# Sneaking (§FC.1): the arms close into the dim ring.
		reticle.sneak = player.crouching
	if player.torch.note != "":
		# Wordless (§ET.3): the torch's lines go to the log only.
		player.torch.note = ""
	if leaving:
		return
	if baked and way_out.stepped_in(player.global_position) >= 0:
		walk_out()


## The count of lights relit, in the log as each catches: in the physics
## step, ahead of what a light sets off there (the residents' clearing,
## §FF.2, and the boss's release, §EY.2), so the log reads in that order.
func _physics_process(_delta: float) -> void:
	if leaving:
		return
	var lit := fires.lit_count()
	if lit > _lit_logged:
		_lit_logged = lit
		GameLog.add("%d of %d lights burn again." % [lit, fires.holders.size()], "relit")


## Into the opening at the top of the way out (§EX.5): the stand-in until
## §EW.3's seam or §EW.7's surface is built (exit.stand_in). The dark
## comes over fade_s, the next tomb is built from a new seed, and you
## arrive in its hearth room by its lit hearth (§EX.9 call 3's stand-in
## answer), carrying what you carried, the torch lit or not as it was.
func walk_out() -> void:
	if leaving:
		return
	leaving = true
	var si: Dictionary = EXIT.get("stand_in", {})
	var fade_s := maxf(float(si.get("fade_s", 2.0)), 0.05)
	GameLog.add(str(si.get("log", "Up the old stair and out. Another tomb, another hearth.")), "world")
	_fade.visible = true
	_fade.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_s)
	await tw.finished
	_clear_tomb()
	_load_tomb(next_seed(seed_value))
	walked_out += 1
	# (Still in the black while the new boss's sprites bake.)
	await _rescuer(fade_s)
	leaving = false


func _unhandled_input(event: InputEvent) -> void:
	# The open panel's clicks first, so no key rebound to a mouse button
	# shuts it under the pointer (the Controls page, §FB).
	if settings_panel.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		settings_panel.click(event.position)
	elif event.is_action_pressed("settings") or (event.is_action_pressed("release_mouse") and settings_panel.visible):
		_toggle_settings(not settings_panel.visible)
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


## Taken by the third hit (Harm, §EA): "Good night" has played and the
## frame is black. You wake on the mat by the hearth (bosses.json
## contact.wake, §ET.3), every light you lit still burning
## (contact.relit_kept: nothing here touches them); the torch went out when
## you fell and is in your pack, both hands empty (a fire pot back on its
## strip), as when you first woke;
## a breath before anything can touch you again (PlanetPlayer.revive); the
## boss goes back to its rounds, far off, and the skeletons home.
func _on_taken() -> void:
	_fade.visible = true
	_fade.color.a = 1.0
	if player.torch.lit():
		player.torch.put_out("taken")
	player.weapon = "hands"
	if player.hands != null and not Hands.left_busy():
		player.hands.hold_left({})
	player.death_cause = ""
	player.revive()
	var w: Array = lay.wake
	player.spawn_flat(w[0], float(w[1]), -0.32)
	harm.reset()
	boss.after_wake()
	# Every skeleton after you gives you up and goes home (§FD).
	residents.player_woke()
	GameLog.add("Taken in the dark. You wake by the hearth, and every light you lit still burns.", "death_cause")
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 2.5)
	tw.tween_callback(func(): _fade.visible = false)


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
