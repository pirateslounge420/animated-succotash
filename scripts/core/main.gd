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

	var spawn_dir: Vector3 = world.pick_spawn_dir()
	# Start mid-afternoon wherever that is, so the first session soon sees
	# sunset and then the night.
	var local_start_h := 15.0
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

	sky = SkySystem.new()
	sky.name = "Sky"
	add_child(sky)

	player = PlanetPlayer.new()
	player.name = "Player"
	player.world = world
	player.chunks = chunks
	add_child(player)
	player.spawn_at(spawn_dir)

	fx = WeatherFX.new()
	fx.name = "WeatherFX"
	add_child(fx)

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
	landmarks.update_landmarks(delta, sky.daylight)
	var fog: float = world.planet.sample(world.planet.fog, d)
	var sky_days := Astro.apparent_days(world.days, CubeSphere.longitude(d))
	sky.update_sky(d, CubeSphere.east(d), CubeSphere.north(d), sky_days, _local_weather, fog, delta)
	var cam := player.camera()
	fx.update_fx(cam.global_position, d, _local_weather)
	TerrainChunk.terrain_material().set_shader_parameter("wetness", 1.0 - sky.daylight)
	post.set_night(1.0 - sky.daylight)
	creatures.update_creatures(delta, sky.daylight)
	hud.set_prompt(creatures.prompt if creatures.prompt != "" else landmarks.nearby)
	hud.update_readout(world, d, elevation, _local_weather, world.time_scale, player.swimming, delta)
	map_overlay.update_map(d, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_action_pressed("toggle_map"):
		map_overlay.toggle(player.surface_dir)
	elif event.is_action_pressed("toggle_hud"):
		hud.toggle()
	elif event.is_action_pressed("time_faster"):
		world.time_scale = minf(world.time_scale * 4.0, 256.0)
	elif event.is_action_pressed("time_slower"):
		world.time_scale = maxf(world.time_scale / 4.0, 1.0)
	elif event.is_action_pressed("interact"):
		creatures.interact(player.global_position)
