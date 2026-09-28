extends Node
## Game entry point (scenes/main.tscn). Generates the planet behind a
## loading screen, then runs the walkable world:
##
##   World (autoload)  planet blueprint, clock, live weather, floating origin
##   ChunkManager      terrain, water and plants streamed around the player
##   FarShell          distant mountains and sea
##   SkySystem         sun, moon, sky, ambient, fog
##   WeatherFX         rain/snow and wind on plants
##   RippleSim         ripples on the water near the camera (Ripples)
##   CreatureSpawner   ambient wildlife, packs, mythical creatures
##   Mythics           mythics not yet in play: biome cues
##   DevSpawn          dev mode only: F7 spawns the next Phase 1 rig
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
var mythics: Mythics
## Dev mode only (data/dev.json): the F7 rig spawner.
var dev_spawn: DevSpawn
var landmarks: Landmarks
var camps: Camps
var post: PostGrade
var clouds: CloudLayers
var camp: Encampment
var sky_events: SkyEvents
var storm: StormFX
var ripples: RippleSim
var hud: Hud
var map_overlay: MapOverlay
var inventory_screen: InventoryScreen
## A short line in place of the prompt ("Your hands are full"), and how
## long it stays.
var _note := ""
var _note_t := 0.0
var _playing := false
## The latest local weather sample (a few times a second), and the eased
## copy everything on screen follows (WeatherSim.ease_toward), so a new
## sample or a weather step never makes the light or clouds jump.
var _local_weather := {}
var _weather_eased := {}
var _weather_timer := 0.0


## Quitting frees everything at once; detach the meshes first (see
## NodeRelease).
func _exit_tree() -> void:
	NodeRelease.detach_all(self)
	Look.finish()
	SculptedBodies.finish()


func _ready() -> void:
	Controls.ensure()
	# The world's textures paint on a worker while the planet generates,
	# and the camp folk's sculpted bodies build.
	Look.prepare()
	SculptedBodies.prewarm_folk()
	world = get_node("/root/World")
	hud = Hud.new()
	add_child(hud)
	hud.show_loading("Starting", 0.0)
	world.generation_progress.connect(func(step: String, f: float) -> void:
		hud.show_loading(step, f * 0.85))
	world.generation_finished.connect(_on_planet_ready)
	# data/dev.json's seed wins in dev mode (World).
	world.generate(world.startup_seed(world_seed))


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
	# Start at the very beginning of dusk wherever that is (the designer:
	# "the spawn in time is right at the beginning of dusk"), so the first
	# session opens on sunset and then the night.
	var local_start_h := DayCycle.phase_start_hour("dusk")
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
	ripples = RippleSim.new()
	ripples.name = "Ripples"
	add_child(ripples)
	ripples.setup(world, chunks)

	creatures = CreatureSpawner.new()
	creatures.name = "Creatures"
	add_child(creatures)
	creatures.setup(world, chunks, player)
	# Mythic creatures before they spawn: biome cues.
	mythics = Mythics.new()
	mythics.name = "Mythics"
	add_child(mythics)
	mythics.setup(world, chunks, player, sky, creatures)
	# F7 spawns the Phase 1 rigs in turn (dev mode only: nothing spawns in
	# normal play).
	if world.dev_mode:
		dev_spawn = DevSpawn.new()
		dev_spawn.name = "DevSpawn"
		add_child(dev_spawn)
		dev_spawn.setup(world, chunks, player, mythics, creatures)

	post = PostGrade.new()
	add_child(post)

	landmarks = Landmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.setup(world, chunks, player, sky, post)
	camps = Camps.new()
	camps.name = "Camps"
	add_child(camps)
	camps.setup(world, chunks, player, landmarks, hud)
	player.spawner = creatures
	player.camps = camps
	player.died.connect(_on_player_died)
	player.hurt.connect(func(_amount: float) -> void: hud.flash_hurt())

	map_overlay = MapOverlay.new()
	add_child(map_overlay)
	map_overlay.setup(world)

	inventory_screen = InventoryScreen.new()
	inventory_screen.name = "Inventory"
	inventory_screen.inventory = player.inventory
	hud.add_child(inventory_screen)

	hud.hide_loading()
	_playing = true
	# The opening lines, once, at the start of the game.
	hud.say("Elder", "You're finally awake.", 1.2, 3.2)
	hud.say("Hunter", "Be careful at night, don't let it get you...", 4.6, 4.8)
	camp.talk(0, 1.2)
	camp.talk(1, 4.6)


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
		# Rain soaks the ground: slidier underfoot (movement table traction).
		var rain := float(_local_weather.get("rain_mm_h", 0.0))
		var wet_t := Tuning.section("movement", "wet_ground")
		if rain > 0.1:
			player.ground_wet = clampf(rain / float(wet_t.get("soaked_rain_mm_h", 4.0)), player.ground_wet, 1.0)
		else:
			player.ground_wet = maxf(player.ground_wet - 0.25 / float(wet_t.get("dry_s", 90.0)), 0.0)
		if clouds.above_low(elevation):
			_above_clouds(_local_weather)
	WeatherSim.ease_toward(_weather_eased, _local_weather, delta, DayCycle.weather_smoothing_s())
	var weather := _weather_eased
	landmarks.update_landmarks(delta, sky.daylight)
	camps.update_camps(delta)
	camp.update_camp(delta, player.global_position)
	var fog: float = world.planet.sample(world.planet.fog, d)
	Look.apply({"look_planet_center": world.planet_center(), "look_planet_radius": PlanetConst.RADIUS_M})
	var sky_days := Astro.apparent_days(world.days, CubeSphere.longitude(d))
	sky.update_sky(d, CubeSphere.east(d), CubeSphere.north(d), sky_days, weather, fog, delta)
	var cam := player.camera()
	var clear := 1.0 - float(weather.get("cloud", 0.0))
	sky_events.update_events(delta, d, CubeSphere.north(d), 1.0 - smoothstep(0.0, 0.25, sky.daylight), clear)
	sky.event_flash(sky_events.flash, sky_events.flash_color)
	storm.update_storm(delta, d, weather)
	var cloud_light := sky.cloud_light.lerp(Color(0.95, 0.97, 1.0), storm.flash)
	# Lit from the sun, turning to the moon as the sun sets (a crossfade).
	clouds.update_clouds(delta, d, world.radius_of(cam.global_position) - PlanetConst.RADIUS_M, weather, cloud_light, sky.cloud_shade, sky.cloud_light_dir)
	# Sheltered from the rain: under a tree's crown or in a camp shelter.
	var sheltered := player.trees.under_canopy or landmarks.sheltered_at(player.global_position)
	fx.update_fx(cam.global_position, d, weather, sheltered)
	post.set_night(1.0 - sky.daylight)
	Campfire.night = 1.0 - sky.daylight
	creatures.update_creatures(delta, sky.daylight)
	# After everything that touches the water this frame has moved; round
	# whichever camera is drawing.
	var view := get_viewport().get_camera_3d()
	if view == null:
		view = cam
	ripples.update_ripples(delta, view.global_position, -view.global_basis.z, weather, sky.cloud_light_dir)
	var prompt: String = creatures.prompt
	# What's in reach (the thrown spear, a stuck arrow) comes before a log
	# or the climb prompt, as E does, climbing too.
	if player.spear.prompt != "":
		prompt = player.spear.prompt
	elif Arrow.stuck_in_reach(player.reach_from(), Arrow.PICK_M) != null:
		prompt = "E: take the arrow back"
	elif PlayerCorpse.in_reach(player.global_position, Tuning.num("combat", "death", "corpse_pick_m")) != null:
		prompt = "E: take your things back"
	elif WorldItem.in_reach(player.reach_from(), WorldItem.PICK_M) != null:
		prompt = "E: take the %s back" % Inventory.title(WorldItem.in_reach(player.reach_from(), WorldItem.PICK_M).item).to_lower()
	elif _sample_in_reach() >= 0:
		prompt = "E: take %s" % _sample_words(Inventory.plant_sample(_sample_in_reach()))
	if _note_t > 0.0:
		_note_t -= delta
		prompt = _note
	if prompt == "":
		prompt = player.prompt if player.prompt != "" else landmarks.nearby
	hud.set_prompt(prompt)
	hud.update_readout(world, d, elevation, weather, player.swimming, delta)
	hud.update_status(player)
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


## Dead: a moment on the ground, then you wake again by the camp fire
## where the game began.
## Death (design reconciliation): your body stays where you fell with
## everything you carried and wore (PlayerCorpse; no marker). You wake by
## the nearest camp fire to where you died, the folk who found you
## having carried you there (Camps.wake_fire(): a wild or rock-shelter
## camp, the opening camp, or a wandering group's fire put down near by),
## lying by it a moment, full health and nothing on you.
func _on_player_died() -> void:
	hud.show_death()
	var death_dir: Vector3 = player.surface_dir
	PlayerCorpse.drop(world, player.global_position, player.global_basis, player.inventory)
	await get_tree().create_timer(3.5).timeout
	hud.show_loading("", 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var dt := Tuning.section("combat", "death")
	var fire: Vector3 = camps.wake_fire(death_dir, float(dt.get("wake_search_m", 4000.0)), float(dt.get("wake_place_m", 150.0)), camp.site)
	# Lying a couple of metres from the fire, feet to it.
	var d: Vector3 = CreatureSpawner._offset(fire, CubeSphere.longitude(death_dir) * 7.0, 2.4)
	if fire == camp.site:
		d = camp.player_spot
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(offset)
	player.global_position -= offset
	chunks.load_blocking(d)
	player.spawn_at(d, fire)
	player.set_view(-0.3, 0.0)
	player.revive()
	player.wake(float(dt.get("wake_s", 2.5)))
	hud.hide_death()
	hud.hide_loading()
	await get_tree().create_timer(1.2).timeout
	hud.say("Camp folk", "We found you out there, cold as stone, and carried you to the fire.", 0.0, 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event.is_action_pressed("toggle_map"):
		map_overlay.toggle(player.surface_dir)
	elif event.is_action_pressed("toggle_hud"):
		hud.toggle()
	elif event.is_action_pressed("toggle_debug"):
		hud.toggle_debug()
	elif event.is_action_pressed("toggle_branch_view") and world.dev_mode:
		BranchGraphView.toggle(self, player)
	elif event.is_action_pressed("toggle_collision_view") and world.dev_mode:
		CollisionView.toggle_for(self, player)
	elif event.is_action_pressed("dev_howl") and world.dev_mode:
		creatures.dev_howl()
	elif event.is_action_pressed("inventory"):
		_toggle_inventory(not inventory_screen.visible)
	elif event.is_action_pressed("release_mouse") and inventory_screen.visible:
		_toggle_inventory(false)
	elif event.is_action_pressed("inventory_drop") and inventory_screen.visible:
		_drop_chosen()
	elif inventory_screen.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		inventory_screen.click(event.position)
	elif event.is_action_pressed("dev_items") and world.dev_mode:
		# Dev: one of each carried kind, for looking at the screen.
		for kind in ["herb_bundle", "fish", "mushroom", "stone_tool"]:
			player.inventory.add(Inventory.make(kind))
	elif event.is_action_pressed("interact"):
		# E works from any state (climbing, swimming, crouched). What's in
		# reach comes first: the thrown spear (Spear), then a stuck arrow;
		# climbing, one hand keeps the wood and the other takes it. Else let
		# go of a tree; else a log within reach; else climb the tree in
		# front of you.
		if inventory_screen.visible:
			_wear_chosen()
			return
		var arrow := Arrow.stuck_in_reach(player.reach_from(), Arrow.PICK_M)
		var lying := WorldItem.in_reach(player.reach_from(), WorldItem.PICK_M)
		var body := PlayerCorpse.in_reach(player.global_position, Tuning.num("combat", "death", "corpse_pick_m"))
		var plant := _sample_in_reach()
		if player.spear.in_reach():
			player.grab_toward(player.spear.thrown.global_position)
			player.spear.pick_up()
		elif arrow != null:
			player.grab_toward(arrow.global_position)
			arrow.pick_up()
		elif body != null:
			if body.recover(player.inventory):
				_say_note("You take your things back.")
			else:
				_say_note("Your hands are full.")
		elif lying != null:
			player.grab_toward(lying.global_position)
			if player.inventory.add(lying.item):
				lying.pick_up()
			else:
				_say_note("Your hands are full.")
		elif plant >= 0:
			# A cutting, a seed head, a leaf, a cut column or a bundle: it
			# carries the species (Inventory.plant_sample).
			player.grab_toward(player.look.point)
			var it := Inventory.plant_sample(plant)
			if player.inventory.add(it):
				_say_note("You take %s." % _sample_words(it))
			else:
				_say_note("Your hands are full.")
		elif player.climbing:
			player.stop_climb()
		elif creatures.log_in_reach(player.global_position):
			creatures.interact(player.global_position)
		else:
			player.try_climb()


## The plant (SpeciesDB index) under the crosshair near enough to take a
## sample of (items.json sample_reach_m), or -1. Not a tree (E climbs
## those).
func _sample_in_reach() -> int:
	var l := player.look
	if l == null or l.kind != "plant" or l.species_index < 0 or l.point == Vector3.INF:
		return -1
	var reach := float(Inventory.data().get("sample_reach_m", 2.2))
	return l.species_index if l.point.distance_to(player.reach_from()) <= reach else -1


## "a cutting of Quercus robur", "a bundle of Cannabis sativa", ...
func _sample_words(it: Dictionary) -> String:
	var what: String = {"cutting": "a cutting", "seed": "a seed head", "leaf": "a leaf", "column": "a cut column", "bundle": "a bundle"}.get(str(it.get("part", "")), "a sample")
	return "%s of %s" % [what, it.get("binomial", "it")]


func _say_note(text: String) -> void:
	_note = text
	_note_t = 2.5


## Open or close the inventory screen (I). The world goes on; the mouse is
## freed for the screen while it's open.
func _toggle_inventory(on: bool) -> void:
	if on:
		inventory_screen.open()
		player.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		inventory_screen.close()
		player.ui_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.bow.block_until_release()


## G on a carried thing: set it down on the ground in front of you.
func _drop_chosen() -> void:
	var c: Array = inventory_screen.chosen
	if c.is_empty() or c[0] != "carried":
		return
	var it = player.inventory.take(c[1])
	if it == null:
		return
	var at := player.global_position + player.global_basis.z * -0.7
	var d: Vector3 = world.dir_of(at)
	WorldItem.drop(it, world, d, chunks.ground_height(d))


## E on a spare in the inventory: wear it (what was worn becomes the spare).
func _wear_chosen() -> void:
	var c: Array = inventory_screen.chosen
	if c.is_empty() or c[0] != "worn":
		return
	player.inventory.wear_spare(c[1], c[2])
