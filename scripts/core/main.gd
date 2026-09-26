extends Node
## Game entry point (scenes/main.tscn). Generates the planet behind a
## loading screen, then runs the walkable world:
##
##   World (autoload)  planet blueprint, clock, live weather, floating origin
##   ChunkManager      terrain, water and plants streamed around the player
##   FarShell          distant mountains and sea
##   SkySystem         sun, moon, sky, ambient, fog
##   WeatherFX         rain/snow and wind on plants
##   CreatureSpawner   ambient wildlife, packs, mythical creatures
##   Landmarks         ruins, glowing places (the bioluminescent night)
##   PostGrade, Hud, MapOverlay
##
## Nothing is built for the planet as a whole except its coarse ~1 km
## blueprint (the weather and rivers need the whole planet). Everything you
## can walk on, see up close or meet is spawned around the player and
## dropped again as they move on.

@export var world_seed := 42

var world: Node
var chunks: ChunkManager
var sky: SkySystem
var fx: WeatherFX
var player: PlanetPlayer
var creatures: CreatureSpawner
var landmarks: Landmarks
var post: PostGrade
var clouds: CloudLayers
var camp: Encampment
var sky_events: SkyEvents
var storm: StormFX
var hud: Hud
var map_overlay: MapOverlay
var _playing := false
var _local_weather := {}
var _weather_timer := 0.0


## Quitting frees everything at once; detach the meshes first (see
## NodeRelease).
func _exit_tree() -> void:
	NodeRelease.detach_all(self)


func _ready() -> void:
	Controls.ensure()
	world = get_node("/root/World")
	hud = Hud.new()
	add_child(hud)
	hud.show_loading("Starting", 0.0)
	world.generation_progress.connect(func(step: String, f: float) -> void:
		hud.show_loading(step, f * 0.85))
	world.generation_finished.connect(_on_planet_ready)
	world.generate(world_seed)


func _on_planet_ready() -> void:
	hud.show_loading("Growing the land around you", 0.9)
	await get_tree().process_frame
	await get_tree().process_frame

	var root := Node3D.new()
	root.name = "WorldRoot"
	add_child(root)
	world.world_root = root

	# The opening encampment: a campfire at one of the planet's best first
	# camps (a different one each game); plants keep clear of it.
	var spawn_dir := Encampment.site_near(world.planet, world.pick_spawn_dir())
	Encampment.set_active(spawn_dir)
	# Start late afternoon wherever that is, the sun low and dusk a minute
	# or two off, so the first session opens on sunset and then the night.
	var local_start_h := 17.0
	world.days = Astro.days_at_solar_hour(world.days, local_start_h, CubeSphere.longitude(spawn_dir))
	world.center_on(spawn_dir, PlanetConst.RADIUS_M + world.surface_elevation(spawn_dir))

	chunks = ChunkManager.new()
	chunks.name = "Chunks"
	add_child(chunks)
	chunks.setup(world)
	chunks.load_blocking(spawn_dir)

	var shell := FarShell.new()
	shell.name = "FarShell"
	root.add_child(shell)
	shell.build(world)
	clouds = CloudLayers.new()
	clouds.name = "Clouds"
	root.add_child(clouds)
	clouds.build(world)

	sky = SkySystem.new()
	sky.name = "Sky"
	add_child(sky)
	sky_events = SkyEvents.new()
	sky_events.name = "SkyEvents"
	add_child(sky_events)
	sky_events.setup(sky)

	player = PlanetPlayer.new()
	player.name = "Player"
	player.world = world
	player.chunks = chunks
	add_child(player)
	camp = Encampment.new()
	root.add_child(camp)
	camp.build(world, chunks, spawn_dir)
	# Waking on the mat, facing the fire; the camera looks down over a
	# shoulder so the fire and the two by it are in view.
	player.spawn_at(camp.player_spot, spawn_dir)
	player.set_view(-0.42, 0.42)

	fx = WeatherFX.new()
	fx.name = "WeatherFX"
	add_child(fx)
	storm = StormFX.new()
	storm.name = "Storms"
	add_child(storm)
	storm.setup(sky, player)

	creatures = CreatureSpawner.new()
	creatures.name = "Creatures"
	add_child(creatures)
	creatures.setup(world, chunks, player)

	post = PostGrade.new()
	add_child(post)

	landmarks = Landmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.setup(world, chunks, player, sky, post)

	map_overlay = MapOverlay.new()
	add_child(map_overlay)
	map_overlay.setup(world)

	hud.hide_loading()
	_playing = true
	# The opening lines, once, at the start of the game.
	hud.say("Elder", "You're finally awake.", 1.2, 3.2)
	hud.say("Hunter", "Be careful at night, don't let it get you...", 4.6, 4.8)


func _process(delta: float) -> void:
	if not _playing:
		return
	var d := player.surface_dir
	var elevation: float = world.radius_of(player.global_position) - PlanetConst.RADIUS_M

	# Floating origin: keep the player near the scene origin.
	if player.global_position.length() > world.REBASE_DISTANCE_M:
		var offset := player.global_position
		world.rebase(offset)
		player.global_position -= offset

	chunks.update_around(d)

	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_weather_timer = 0.25
		_local_weather = world.weather.local_weather(d, elevation)
		if clouds.above_low(elevation):
			_above_clouds(_local_weather)
	landmarks.update_landmarks(delta, sky.daylight)
	camp.update_camp(delta, player.global_position)
	var fog: float = world.planet.sample(world.planet.fog, d)
	Look.apply({"look_planet_center": world.planet_center(), "look_planet_radius": PlanetConst.RADIUS_M})
	var sky_days := Astro.apparent_days(world.days, CubeSphere.longitude(d))
	sky.update_sky(d, CubeSphere.east(d), CubeSphere.north(d), sky_days, _local_weather, fog, delta)
	var cam := player.camera()
	var clear := 1.0 - float(_local_weather.get("cloud", 0.0))
	sky_events.update_events(delta, d, CubeSphere.north(d), 1.0 - smoothstep(0.0, 0.25, sky.daylight), clear)
	sky.event_flash(sky_events.flash, sky_events.flash_color)
	storm.update_storm(delta, d, _local_weather)
	var cloud_light := sky.cloud_light.lerp(Color(0.95, 0.97, 1.0), storm.flash)
	clouds.update_clouds(delta, d, world.radius_of(cam.global_position) - PlanetConst.RADIUS_M, _local_weather, cloud_light, sky.cloud_shade)
	# Sheltered from the rain: under a tree's crown or in a camp shelter.
	var sheltered := player.trees.under_canopy or landmarks.sheltered_at(player.global_position)
	fx.update_fx(cam.global_position, d, _local_weather, sheltered)
	TerrainChunk.terrain_material().set_shader_parameter("wetness", 1.0 - sky.daylight)
	post.set_night(1.0 - sky.daylight)
	creatures.update_creatures(delta, sky.daylight)
	var prompt: String = creatures.prompt
	if prompt == "":
		prompt = player.prompt if player.prompt != "" else landmarks.nearby
	hud.set_prompt(prompt)
	hud.update_readout(world, d, elevation, _local_weather, player.swimming, delta)
	map_overlay.update_map(d, delta)


## Standing above the low cloud layer: the harsh alpine / puna conditions
## (the temperature already falls with height). The air is exposed, so the
## wind is stronger and gustier; the low clouds and their rain are below,
## so it's clearer and drier unless a storm towers through; the HUD says
## so (thin, cold air).
func _above_clouds(w: Dictionary) -> void:
	var storm := float(w.get("storm", 0.0))
	w["wind"] = (w.get("wind", Vector3.ZERO) as Vector3) * 1.7
	w["cloud"] = float(w.get("cloud", 0.0)) * 0.35
	w["rain_mm_h"] = float(w.get("rain_mm_h", 0.0)) * storm
	w["above_clouds"] = true


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_action_pressed("toggle_map"):
		map_overlay.toggle(player.surface_dir)
	elif event.is_action_pressed("toggle_hud"):
		hud.toggle()
	elif event.is_action_pressed("interact"):
		# Let go of a tree; else a log within reach; else climb the tree
		# in front of you.
		if player.climbing:
			player.stop_climb()
		elif creatures.log_in_reach(player.global_position):
			creatures.interact(player.global_position)
		else:
			player.try_climb()
