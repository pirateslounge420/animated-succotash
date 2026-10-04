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
## The season on the trees: autumn colour, leaf fall, bare winter, spring.
var leaf_season: LeafSeason
## Fallen leaves on the ground: piles, rustle, rot.
var litter: LitterField
var fx: WeatherFX
var player: PlanetPlayer
var creatures: CreatureSpawner
## The Amorphophallus living their cycles round the player (AroidGarden).
var aroid_garden: AroidGarden
## Flowers, pollinators and fruit on the trees round the player (FruitCrop).
var fruit_crop: FruitCrop
var fuel_field: FuelField
var dread: Dread
var sound_bed: SoundBed
var water_sounds: WaterSounds
var road_props: RoadProps
var camp_sim: CampSim
var player_fires: PlayerFires
var travellers: Travellers
var mythics: Mythics
## Dev mode only (data/dev.json): the F7 rig spawner.
var dev_spawn: DevSpawn
var landmarks: Landmarks
var camps: Camps
var old_hearths: OldHearths
var overrun: Overrun
var delves: Delves
var post: PostGrade
var rain_overlay: RainOverlay
var night_accents: NightAccents
## The local ground mean (m above the planet radius) for the valley fog.
var _ground_mean := INF
var _ground_t := 0.0
var clouds: CloudLayers
var camp: Encampment
var sky_events: SkyEvents
var storm: StormFX
var ripples: RippleSim
var hud: Hud
var map_overlay: MapOverlay
var inventory_screen: InventoryScreen
var log_panel: LogPanel
var _last_biome := -1
var _last_sun_el := NAN
## The settings panel (O / F10): the HUD switches (design §L).
var settings_panel: SettingsPanel
## A short line in place of the prompt ("Your hands are full"), and how
## long it stays.
var _note := ""
var _note_t := 0.0
var _playing := false
## The dev key's "New world" confirmation window (seconds left).
var _new_world_armed := 0.0
## The latest local weather sample (a few times a second), and the eased
## copy everything on screen follows (WeatherSim.ease_toward), so a new
## sample or a weather step never makes the light or clouds jump.
var _local_weather := {}
var _weather_eased := {}
var _weather_timer := 0.0
## The mouse freed with Esc (PlanetPlayer) and not taken back since: with
## no screen open that wants it, the HUD's readouts can be pinned
## (Hud.set_pinning()). Not the mouse mode alone: the game also starts with
## the mouse free (until the first click), and a headless run's mouse is
## always free.
var _mouse_freed := false


## Quitting frees everything at once; detach the meshes first (see
## NodeRelease).
func _exit_tree() -> void:
	WorldSave.flush(0.0, true)
	NodeRelease.detach_all(self)
	Look.finish()
	SculptedBodies.finish()


func _ready() -> void:
	Controls.ensure()
	Display.install(get_window())
	HudText.install()
	# The volume sliders' saved levels (settings panel, Audio).
	AudioMix.apply()
	# The world's textures paint on a worker while the planet generates,
	# and the camp folk's sculpted bodies build.
	Look.prepare()
	SculptedBodies.prewarm_folk()
	world = get_node("/root/World")
	# A world's static state comes from its own save (design 1 Oct §CB):
	# nothing of the last world carries over a "New world".
	world.reset_world_state()
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
	# The world's save first: it remembers where this world's first camp is.
	WorldSave.open(world.world_seed)
	var spawn_dir := _opening_site()
	# A few hearths in every biome, no two alike (design 3 Oct §CU): the
	# sites pass, kept in the world's save; the opening road's people's
	# camp always stays one.
	var od: Vector3 = world.opening.get("ruin", Vector3.ZERO)
	Hearths.warm(world, [od] if od != Vector3.ZERO else [])
	Encampment.set_active(spawn_dir)
	open_clock(spawn_dir)
	world.center_on(spawn_dir, PlanetConst.RADIUS_M + world.surface_elevation(spawn_dir))

	chunks = ChunkManager.new()
	chunks.name = "Chunks"
	add_child(chunks)
	chunks.setup(world)
	chunks.load_blocking(spawn_dir)

	var shell := FarShell.new()
	shell.name = "FarShell"
	root.add_child(shell)
	leaf_season = LeafSeason.new()
	leaf_season.name = "LeafSeason"
	leaf_season.main = self
	root.add_child(leaf_season)
	litter = LitterField.new()
	litter.name = "LitterField"
	litter.main = self
	litter.leaf_season = leaf_season
	root.add_child(litter)
	shell.build(world)
	clouds = CloudLayers.new()
	clouds.name = "Clouds"
	root.add_child(clouds)
	clouds.build(world)

	sky = SkySystem.new()
	sky.name = "Sky"
	add_child(sky)
	sky.vis_chunks = chunks
	sky_events = SkyEvents.new()
	sky_events.name = "SkyEvents"
	add_child(sky_events)
	sky_events.setup(sky)

	player = PlanetPlayer.new()
	player.name = "Player"
	player.world = world
	player.chunks = chunks
	sky.vis_player = player
	add_child(player)
	camp_sim = CampSim.new()
	camp_sim.name = "CampSim"
	add_child(camp_sim)
	camp_sim.setup(world, chunks)
	Coppice.load_saved()
	player_fires = PlayerFires.new()
	player_fires.name = "PlayerFires"
	add_child(player_fires)
	player_fires.setup(world, chunks, player)
	camp = Encampment.new()
	root.add_child(camp)
	camp.build(world, chunks, spawn_dir)
	# The world's kept things (WorldSave: the hearth, the log), and the
	# first hearth: the opening camp (design 30 Sept §AY).
	Hearth.setup(camp.site)
	GameLog.load_saved()
	# What the game runs on, and whether its shaders built (§CG; Mike's
	# 22:52 play): the log's first line of each session, F3 and stdout.
	EngineReport.check_shaders()
	var engine_line := EngineReport.summary()
	if not (EngineReport.result.failed as Array).is_empty():
		engine_line += " · " + EngineReport.shaders_text()
	print("[engine] %s · %s" % [EngineReport.summary(), EngineReport.shaders_text()])
	GameLog.now_text = _now_text(spawn_dir)
	GameLog.add(engine_line, "engine")
	if GameLog.entries.size() <= 1:
		# The world's name is its seed (design 1 Oct §CB): the log opens
		# with it, and the kind of first camp when the roll says one.
		GameLog.now_text = _now_text(spawn_dir)
		var kind_text := " — a %s camp" % str(world.first_camp_kind).replace("_", " ") if world.first_camp_kind != "" else ""
		GameLog.add("World %d — day %d%s" % [world.world_seed, int(world.local_clock(spawn_dir).x), kind_text], "world")
	GameLog.add_once("people:opening", "The %s live here." % Peoples.name_of(Peoples.get_people(camp.people_id)).to_lower(), "camp_found")
	if Tuning.profile() == "ambient":
		Torch.lay_bundle(world, chunks, camp.fire())
	# Waking on the mat. On a rolled first camp (§BX) facing along the
	# opening road toward the people's camp it leads to; otherwise (the dev
	# frame's old list) facing the fire, the camera looking down over a
	# shoulder so the fire and the two by it are in view.
	var road_ahead := _opening_road_ahead(spawn_dir)
	if road_ahead != Vector3.ZERO:
		player.spawn_at(camp.player_spot, road_ahead)
		player.set_view(-0.12, 0.0)
	else:
		player.spawn_at(camp.player_spot, spawn_dir)
		player.set_view(-0.42, 0.42)
	_lay_gifts()

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
	# The aroids' lives: shoots, blooms, scent, pollinators, fruit
	# (docs/design/AROID_LIFE.md).
	aroid_garden = AroidGarden.new()
	aroid_garden.name = "AroidGarden"
	add_child(aroid_garden)
	aroid_garden.setup(world, chunks, player, creatures)
	aroid_garden.say = _say_note
	fruit_crop = FruitCrop.new()
	fruit_crop.name = "FruitCrop"
	add_child(fruit_crop)
	fuel_field = FuelField.new()
	fuel_field.name = "FuelField"
	add_child(fuel_field)
	fuel_field.setup(world, chunks, player)
	dread = Dread.new()
	dread.name = "Dread"
	add_child(dread)
	dread.setup(world, chunks, player, sky)
	sound_bed = SoundBed.new()
	sound_bed.name = "SoundBed"
	add_child(sound_bed)
	sound_bed.setup(world, chunks, player, sky)
	water_sounds = WaterSounds.new()
	water_sounds.name = "WaterSounds"
	add_child(water_sounds)
	water_sounds.setup(world, chunks, player)
	road_props = RoadProps.new()
	road_props.name = "RoadProps"
	add_child(road_props)
	road_props.setup(world, chunks, player)
	travellers = Travellers.new()
	travellers.name = "Travellers"
	add_child(travellers)
	travellers.setup(world, chunks, player)
	fruit_crop.setup(world, chunks, player)
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
	rain_overlay = RainOverlay.new()
	rain_overlay.name = "RainOverlay"
	add_child(rain_overlay)

	landmarks = Landmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.setup(world, chunks, player, sky, post)
	night_accents = NightAccents.new()
	night_accents.name = "NightAccents"
	add_child(night_accents)
	night_accents.setup(world, chunks, landmarks, sky, player)
	camps = Camps.new()
	camps.name = "Camps"
	add_child(camps)
	camps.setup(world, chunks, player, landmarks, hud)
	# The cold hearths at empty ruins and old camps' remains (Mike, 2 Oct).
	old_hearths = OldHearths.new()
	old_hearths.name = "OldHearths"
	add_child(old_hearths)
	old_hearths.setup(world, chunks, player, landmarks, camps)
	# Overrun ruins (design 2 Oct §CN): the dens, their tells, the clearing.
	overrun = Overrun.new()
	overrun.name = "Overrun"
	add_child(overrun)
	overrun.setup(world, chunks, player, landmarks, sky)
	# The delves under the barrows (design 1 Oct §CJ): who is in one, the
	# cairn doors, the finds.
	delves = Delves.new()
	delves.name = "Delves"
	add_child(delves)
	delves.setup(world, chunks, player, landmarks)
	player.spawner = creatures
	player.camps = camps
	player.died.connect(_on_player_died)
	player.hurt.connect(func(_amount: float) -> void: hud.flash_hurt())

	map_overlay = MapOverlay.new()
	add_child(map_overlay)
	map_overlay.setup(world)

	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	hud.add_child(settings_panel)
	inventory_screen = InventoryScreen.new()
	inventory_screen.name = "Inventory"
	inventory_screen.inventory = player.inventory
	hud.add_child(inventory_screen)
	log_panel = LogPanel.new()
	log_panel.name = "Log"
	hud.add_child(log_panel)

	hud.hide_loading()
	_playing = true
	# The opening lines, once, at the start of the game.
	hud.say("Elder", "You're finally awake.", 1.2, 3.2)
	hud.say("Hunter", "Be careful at night, don't let it get you...", 4.6, 4.8)
	camp.talk(0, 1.2)
	camp.talk(1, 4.6)


## The world's clock at the opening camp `spawn_dir` (main's boot; also
## tools/day_check.gd). The sky keeps World.START_DAYS (a near-full moon the
## first night, design §CG); the hour is §CY's dawn there; Day 1 is the
## world's first local day there, kept in its save.
func open_clock(spawn_dir: Vector3) -> void:
	world.days = World.START_DAYS
	# Wake at dawn (design 3 Oct §CY.1, roads.json opening_road.dawn_start;
	# supersedes §BX's afternoon): real_min_after_dawn_begins real minutes
	# after dawn begins here, the world still blue and the fire the one warm
	# thing, with the day ahead to reach the next hearth. (Dawn's hour
	# depends on the latitude and the day of the year.)
	var spawn_lat := CubeSphere.latitude(spawn_dir)
	var local_start_h := World.dawn_start_hour(spawn_lat, Astro.declination(world.days), world.day_length_s)
	world.days = Astro.days_at_solar_hour(world.days, local_start_h, CubeSphere.longitude(spawn_dir), spawn_lat)
	# Day 1 (design 1 Oct §CG): the world's first local day, at its opening
	# camp, kept in its save. A save from before has none: the clock starts
	# over at START_DAYS on every boot (it isn't saved), so the day it wakes
	# on is the only first day it has had.
	var kept_first = WorldSave.data.get("first_local_day", null)
	world.first_local_day = float(kept_first) if kept_first != null else Astro.local_clock(world.days, CubeSphere.longitude(spawn_dir), spawn_lat).x
	if kept_first == null:
		WorldSave.data["first_local_day"] = world.first_local_day
		WorldSave.mark_dirty()


## The log's clock stamp at `d` ("Day 3 · 03:40", World.clock_text).
func _now_text(d: Vector3) -> String:
	return world.clock_text(d)


## Start a new world (design 1 Oct §CB; the settings panel's "New world"
## and the dev key, after their confirmation line): this one is saved and
## stays; the next boot of the scene rolls a fresh seed and first camp.
## "Continue" is just booting.
func start_new_world() -> void:
	WorldSave.flush(0.0, true)
	world.new_world_requested = true
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
	else:
		# A tool holds the scene itself (new_world_check): it rebuilds one.
		queue_free()


func _process(delta: float) -> void:
	if _new_world_armed > 0.0:
		_new_world_armed -= delta
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
	# The eye, for the shaders that spend detail by distance from it
	# (foliage: leaves cast shadows only near it, design §W).
	var eye_cam := get_viewport().get_camera_3d()
	if eye_cam:
		RenderingServer.global_shader_parameter_set("look_eye", eye_cam.global_position)

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
	# What falls is the rain's rate gated by the eased cover overhead
	# (design 3 Oct §CX): the cloud builds before the rain, the rain stops
	# before the cloud clears.
	_weather_eased["rain_mm_h"] = float(_weather_eased.get("rain_rate", 0.0)) * WeatherSim.rain_gate(float(_weather_eased.get("cloud", 0.0)))
	var weather := _weather_eased
	landmarks.update_landmarks(delta, sky.daylight)
	camps.update_camps(delta)
	camp.update_camp(delta, player.global_position)
	var fog: float = world.planet.sample(world.planet.fog, d)
	Look.apply({"look_planet_center": world.planet_center(), "look_planet_radius": PlanetConst.RADIUS_M})
	# The local ground mean (valley fog pools below it, §AG): 16 points
	# on a 250 m ring and the spot itself, twice a second, eased.
	_ground_t -= delta
	if _ground_t <= 0.0:
		_ground_t = 0.5
		var sum := chunks.ground_height(d)
		for k in 16:
			sum += chunks.ground_height(CreatureSpawner._offset(d, TAU * k / 16.0, 250.0))
		var mean := sum / 17.0
		_ground_mean = mean if _ground_mean == INF else lerpf(_ground_mean, mean, 0.3)
		Look.apply({"look_ground_m": _ground_mean})
	var sky_days := Astro.apparent_days(world.days, CubeSphere.longitude(d), CubeSphere.latitude(d))
	sky.update_sky(d, CubeSphere.east(d), CubeSphere.north(d), sky_days, weather, fog, delta)
	leaf_season.update_season(delta, d, world.days, WeatherFX.plant_wind)
	litter.update_litter(delta, d, world.days, weather)
	var cam := player.camera()
	var clear := 1.0 - float(weather.get("cloud", 0.0))
	sky_events.update_events(delta, d, CubeSphere.north(d), 1.0 - smoothstep(0.0, 0.25, sky.daylight), clear)
	sky.event_flash(sky_events.flash, sky_events.flash_color)
	storm.update_storm(delta, d, weather)
	var cloud_light := sky.cloud_light.lerp(Color(0.95, 0.97, 1.0), storm.flash)
	# Lit from the sun, turning to the moon as the sun sets (a crossfade).
	clouds.update_clouds(delta, d, world.radius_of(cam.global_position) - PlanetConst.RADIUS_M, weather, cloud_light, sky.cloud_shade, sky.cloud_light_dir)
	# Sheltered from the rain: under a tree's crown or in a camp shelter.
	var sheltered := player.trees.under_canopy or landmarks.sheltered_at(player.global_position) or Delves.inside
	# Rain on what you carry: the pouch keeps kindling dry (§CO; rain_on
	# does nothing unless fuel.json kindling.pouch_keeps_dry is false).
	if float(_local_weather.get("rain_mm_h", 0.0)) > 0.1 and not _under_roof():
		Kindling.rain_on(player.inventory, world.days)
	fx.update_fx(cam.global_position, d, weather, sheltered)
	# The gust field rides on the wind just set (design §DA, Wind).
	Wind.tick(delta, world, player)
	rain_overlay.update_rain(weather, sheltered, cam.global_basis.x)
	post.set_night(1.0 - sky.daylight)
	post.set_floor(sky.post_floor, sky.night_pull, float((SkySystem.FLOOR.get("night", {}) as Dictionary).get("pull_below_luma", 0.35)))
	Campfire.night = 1.0 - sky.daylight
	# The weather the hearths' smoke reads (§CV, Smoke): the wind and rain
	# here, and whether it is a still dawn (the smoke pools flat).
	Smoke.wind = WeatherFX.plant_wind
	Smoke.rain_mm_h = float(weather.get("rain_mm_h", 0.0))
	Smoke.calm_dawn = FireCircle.phase_name(world.local_clock(d).y, CubeSphere.latitude(d), world.days) == "dawn" and WeatherFX.plant_wind.length() <= float((Smoke.H.get("wind", {}) as Dictionary).get("calm_below_mps", 1.0))
	Smoke.sun_deg = sky.sun_elevation_deg
	Smoke.morning = world.local_clock(d).y < 12.0
	Smoke.days = world.days
	Smoke.far_columns(self, d, delta)
	Smoke.plumes(self, d)
	creatures.update_creatures(delta, sky.daylight)
	fruit_crop.daylight = sky.daylight
	fruit_crop.rain_mm_h = float(weather.get("rain_mm_h", 0.0))
	Torch.weather = weather
	Torch.remake_bundles(world, chunks, world.days)
	FireStore.tick(get_tree(), delta, player.global_position)
	VegetationPlacer.NOW_DAYS = world.days
	WorldSave.flush(delta)
	player.typing = log_panel.visible
	dread.update_dread(delta)
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
		prompt = "%s: take the arrow back" % Controls.interact_word()
	elif PlayerCorpse.in_reach(player.global_position, Tuning.num("combat", "death", "corpse_pick_m")) != null:
		prompt = "%s: take your things back" % Controls.interact_word()
	elif _headman_in_reach() != null:
		prompt = "%s: the headman" % Controls.interact_word()
	elif not _ladder_in_reach().is_empty():
		prompt = "%s: %s the rope ladder" % [Controls.interact_word(), "climb" if bool(_ladder_in_reach()[1]) else "climb down"]
	elif _ember_lay_ok():
		prompt = "%s: lay a fire from the ember" % Controls.interact_word()
	elif _lamp_place_ok():
		prompt = "%s: set the lamp down" % Controls.interact_word()
	elif _stool_in_reach() != null and Coppice.ready(_stool_in_reach()):
		prompt = "%s: cut the stool's poles" % Controls.interact_word()
	elif _coppice_tree_ok():
		prompt = "%s: cut it to the stool" % Controls.interact_word()
	elif _resin_tree_ok():
		prompt = "%s: dip the torch in the pitch" % Controls.interact_word()
	elif _pole_make_ok():
		prompt = "%s: cut a pole and twist a line" % Controls.interact_word()
	elif _ember_take_ok():
		prompt = "%s: take an ember" % Controls.interact_word()
	elif _lamp_take_ok():
		prompt = "%s: take a fat lamp" % Controls.interact_word()
	elif delves != null and delves.door_in_reach(player.global_position) != null and delves.inside_of(delves.door_in_reach(player.global_position), player.global_position):
		prompt = "%s: push the slab" % Controls.interact_word()
	elif not _store_in_reach().is_empty() and _store_item() >= 0:
		var sn: Node3D = _store_in_reach()[0]
		prompt = "%s: put the %s %s" % [Controls.interact_word(), Inventory.title(player.inventory.carried[_store_item()]).to_lower(), "on the woodpile" if sn.name == "Woodpile" else "in the store"]
	elif _fire_in_reach() != null and FireStore.wants_kindling(_fire_in_reach()) and Kindling.best_slot(player.inventory, world.days) >= 0:
		prompt = "%s: lay the %s in the cold %s" % [Controls.interact_word(), Inventory.title(player.inventory.carried[Kindling.best_slot(player.inventory, world.days)]).to_lower(), "hearth" if _fire_in_reach().has_meta("old_hearth") else "fire"]
	elif _fire_in_reach() != null and player.inventory.has_kind("fuel"):
		prompt = "%s: put the %s on the fire" % [Controls.interact_word(), Inventory.title(player.inventory.carried[player.inventory.slot_of("fuel")]).to_lower()]
	elif not player.torch.swing_target().is_empty():
		# The swing passes the flame (§CN): left click, not right.
		prompt = "%s: %s" % [Controls.shoot_word(), _swing_words(player.torch.swing_target())]
	elif Hearth.can_set(_fire_in_reach()):
		prompt = "%s: make this your hearth" % Controls.interact_word()
	elif WorldItem.in_reach(player.reach_from(), WorldItem.PICK_M) != null:
		var near_item := WorldItem.in_reach(player.reach_from(), WorldItem.PICK_M)
		var count := int(near_item.item.get("count", 1))
		prompt = "%s: take a torch" % Controls.interact_word() if str(near_item.item.get("kind", "")) == "torch" and count > 1 else "%s: take the %s%s" % [Controls.interact_word(), Inventory.title(near_item.item).to_lower(), "" if near_item.gift else " back"]
	elif PlantedTorch.in_reach(player.reach_from(), float(Tuning.section("torch", "planted").get("pickup_reach_m", 2.0))) != null:
		prompt = "%s: take the torch back" % Controls.interact_word()
	elif not _fruit_in_reach().is_empty():
		prompt = FruitCrop.prompt_for(_fruit_in_reach())
	elif _plant_kindling() != "":
		prompt = "%s: take %s" % [Controls.interact_word(), Kindling.name_of(_plant_kindling()).to_lower()]
	elif _sample_in_reach() >= 0:
		var sp_in_reach := _sample_in_reach()
		prompt = "%s: take %s" % [Controls.interact_word(), _sample_words(Inventory.plant_sample(sp_in_reach, aroid_garden.sample_extra(sp_in_reach, player.look.point) if aroid_garden else {}))]
	if prompt == "" and _ground_kindling() != "":
		prompt = "%s: gather %s" % [Controls.interact_word(), Kindling.name_of(_ground_kindling()).to_lower()]
	if prompt == "" and player.torch.can_plant():
		prompt = "%s: plant the torch" % Controls.interact_word()
	if player.torch.note != "":
		_say_note(player.torch.note)
		player.torch.note = ""
	if _note_t > 0.0:
		_note_t -= delta
		prompt = _note
	if prompt == "":
		prompt = player.prompt if player.prompt != "" else landmarks.nearby
	hud.set_prompt(prompt)
	hud.update_readout(world, d, elevation, weather, player.swimming, delta)
	hud.update_status(player)
	# Pinning the readouts: while the mouse is free after Esc and no screen
	# that wants it is open (the inventory, the settings panel, the map).
	hud.set_pinning(_mouse_freed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not player.ui_open and not map_overlay.visible)
	# The speedometer and the clock face (design §L, §AQ): speed, meter and
	# the local clock.
	# One clock (design §CG): the face, the log's stamps and the HUD line
	# read the sky's time here.
	var clock_h: float = world.local_clock(d).y
	GameLog.now_text = world.clock_text(d)
	sound_bed.update_bed(delta, weather, clock_h)
	_log_events()
	hud.readouts.feed(player.velocity.length(), player.meter.value, clock_h, world.dev_mode, delta)
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
	w["rain_rate"] = float(w.get("rain_rate", 0.0)) * storm
	w["above_clouds"] = true


## Dead: a moment on the ground, then you wake again by the camp fire
## where the game began.
## Death (design reconciliation): your body stays where you fell with
## everything you carried and wore (PlayerCorpse; no marker). You wake by
## the nearest camp fire to where you died, the folk who found you
## having carried you there (Camps.wake_fire(): a wild or rock-shelter
## camp, the opening camp, or a wandering group's fire put down near by),
## lying by it a moment, full health and nothing on you (bare hands: a
## punch or a shove is all you have till you find your body).
func _on_player_died() -> void:
	hud.show_death()
	GameLog.add(_death_line(player.death_cause), "death_cause")
	player.death_cause = ""
	var death_dir: Vector3 = player.surface_dir
	PlayerCorpse.drop(world, player.global_position, player.global_basis, player.inventory)
	await get_tree().create_timer(3.5).timeout
	hud.show_loading("", 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var dt := Tuning.section("combat", "death")
	var fire: Vector3 = camps.wake_fire(death_dir, float(dt.get("wake_search_m", 4000.0)), float(dt.get("wake_place_m", 150.0)), camp.site)
	# The ambient profile wakes you at your hearth (design 30 Sept §AY,
	# camps.json wake_at_home), wherever you died.
	if Tuning.profile() == "ambient" and bool(Tuning.table("camps").get("wake_at_home", true)) and Hearth.dir != Vector3.ZERO:
		fire = Hearth.dir
		# Never wake at no fire: a hearth that is neither the opening
		# camp's nor a ruin camp's (a camp that moved, a fire long gone)
		# wakes you at the opening camp.
		if CubeSphere.surface_distance_m(fire, camp.site) > 30.0 and not camps.fire_at(fire) and not OldHearths.lit_at(world, fire):
			fire = camp.site
			Hearth.set_home(camp.site, false)
			GameLog.add("Your hearth was gone; you woke at the camp.", "hearth_gone")
	# Lying a couple of metres from the fire, feet to it.
	var d: Vector3 = CreatureSpawner._offset(fire, CubeSphere.longitude(death_dir) * 7.0, 2.4)
	if fire == camp.site:
		d = camp.player_spot
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(offset)
	player.global_position -= offset
	chunks.load_blocking(d)
	# The ruin whose fire it is, and its camp, are there when you wake
	# (they'd otherwise come in over the next seconds, a ruin a frame).
	landmarks.build_ruin_at(fire)
	player.spawn_at(d, fire)
	_lay_gifts()
	camps.refresh_now()
	old_hearths.refresh_now()
	player.set_view(-0.3, 0.0)
	player.weapon = "hands"
	player.revive()
	player.wake(float(dt.get("wake_s", 2.5)))
	hud.hide_death()
	hud.hide_loading()
	await get_tree().create_timer(1.2).timeout
	hud.say("Camp folk", "We found you out there, cold as stone, and carried you to the fire.", 0.0, 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	# A click that gets here takes the mouse back (PlanetPlayer), so
	# pinning ends. A click on a readout while pinning never gets here: the
	# HUD stops it as GUI input (Hud.PinCatcher).
	if event is InputEventMouseButton and event.pressed and not player.ui_open:
		_mouse_freed = false
	if event.is_action_pressed("toggle_map"):
		map_overlay.toggle(player.surface_dir)
	elif event.is_action_pressed("toggle_hud"):
		hud.toggle()
	elif event.is_action_pressed("toggle_debug"):
		hud.toggle_debug()
	elif event.is_action_pressed("dev_pixel"):
		var pname := Display.cycle_preset()
		_say_note("Pixel size: %s" % Display.preset_label())
		print("[display] preset %s" % pname)
	elif event.is_action_pressed("dev_perf") and world.dev_mode:
		hud.perf.sun = sky.sun
		hud.perf.toggle()
	elif event.is_action_pressed("toggle_branch_view") and world.dev_mode:
		BranchGraphView.toggle(self, player)
	elif event.is_action_pressed("toggle_collision_view") and world.dev_mode:
		CollisionView.toggle_for(self, player)
	elif event.is_action_pressed("dev_howl") and world.dev_mode:
		creatures.dev_howl()
	elif event.is_action_pressed("settings") or (event.is_action_pressed("release_mouse") and settings_panel.visible):
		_toggle_settings(not settings_panel.visible)
	elif settings_panel.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		settings_panel.click(event.position)
	elif settings_panel.visible and event is InputEventMouseMotion:
		# Dragging a volume slider.
		settings_panel.drag(event.position)
	elif event.is_action_pressed("log") and not log_panel.visible and not inventory_screen.visible and not settings_panel.visible:
		log_panel.open()
	elif event.is_action_pressed("inventory"):
		_toggle_inventory(not inventory_screen.visible)
	elif event.is_action_pressed("release_mouse") and inventory_screen.visible:
		_toggle_inventory(false)
	elif event.is_action_pressed("release_mouse"):
		# Esc freed the mouse (PlanetPlayer): the readouts can be pinned.
		_mouse_freed = true
	elif event.is_action_pressed("inventory_drop") and inventory_screen.visible:
		_drop_chosen()
	elif inventory_screen.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		inventory_screen.click(event.position)
	elif event.is_action_pressed("dev_new_world") and world.dev_mode:
		# Dev: a new world, asked once (design 1 Oct §CB).
		if _new_world_armed > 0.0:
			_new_world_armed = 0.0
			start_new_world()
		else:
			_new_world_armed = 5.0
			hud.say("", "Start a new world? Press F12 again. This one stays saved.", 0.0, 5.0)
	elif event.is_action_pressed("dev_items") and world.dev_mode:
		# Dev: one of each carried kind, for looking at the screen.
		for kind in ["herb_bundle", "fish", "mushroom", "cactus_column"]:
			player.inventory.add(Inventory.make(kind))
	elif event.is_action_pressed("interact"):
		# Interact (right click; Mike, 29 Sept 2026: it was E) works from
		# any state (climbing, swimming, crouched). What's in reach comes
		# first: the thrown spear (Spear), then a stuck arrow; climbing, one
		# hand keeps the wood and the other takes it. Else let go of a tree
		# or a perch; else a log within reach. What's left is the player's
		# own (PlanetPlayer: climb the tree in front of you, cling to a wall
		# or trunk, catch a branch or vine), so a press spent here is marked.
		if inventory_screen.visible:
			_wear_chosen()
			return
		var arrow := Arrow.stuck_in_reach(player.reach_from(), Arrow.PICK_M)
		var lying := WorldItem.in_reach(player.reach_from(), WorldItem.PICK_M)
		var body := PlayerCorpse.in_reach(player.global_position, Tuning.num("combat", "death", "corpse_pick_m"))
		var plant := _sample_in_reach()
		var spent := true
		var planted := PlantedTorch.in_reach(player.reach_from(), float(Tuning.section("torch", "planted").get("pickup_reach_m", 2.0)))
		var fire := _fire_in_reach()
		var store := _store_in_reach()
		var headman := _headman_in_reach()
		var ladder := _ladder_in_reach()
		if headman != null:
			_meet_headman(headman)
		elif not ladder.is_empty():
			_climb_ladder(ladder[0], bool(ladder[1]))
		elif _ember_lay_ok():
			_lay_from_ember()
		elif _lamp_place_ok():
			_place_lamp()
		elif _stool_in_reach() != null and Coppice.ready(_stool_in_reach()):
			Coppice.harvest(_stool_in_reach(), world, world.days)
			_say_note("You cut the poles.")
		elif _coppice_tree_ok():
			var ta := player.tree_ahead(player.global_basis.z * -1.0)
			Coppice.cut(ta[0], ta[1], world, world.days)
			_say_note("You cut it to the stool.")
		elif _resin_tree_ok():
			player.torch.item()["resin"] = true
			GameLog.add("Dipped the torch in pine pitch.", "technique")
			_say_note("You dip the torch in the pitch.")
		elif _pole_make_ok():
			_make_pole()
		elif _ember_take_ok():
			_take_ember(fire)
		elif _lamp_take_ok():
			_take_lamp()
		elif delves.door_in_reach(player.global_position) != null:
			# A cairn's slab (§CJ): it moves only from inside.
			_say_note(delves.push(delves.door_in_reach(player.global_position), player.global_position))
		elif not store.is_empty() and _store_item() >= 0:
			# The player's gathering goes into the camp's store (§BL).
			_give_to_store(store)
		elif fire != null and FireStore.wants_kindling(fire) and Kindling.best_slot(player.inventory, world.days) >= 0:
			# Lay a cold fire (§CN): the kindling first, then fuel.
			var ki := Kindling.best_slot(player.inventory, world.days)
			var kit: Dictionary = player.inventory.carried[ki]
			if FireStore.lay_kindling(fire, kit, world.days) == "laid":
				player.inventory.take(ki)
				var need_fuel := not FireStore.is_laid(fire)
				_say_note("You lay the %s%s.%s" % [Inventory.title(kit).to_lower(), ", wet" if Kindling.is_wet(kit, world.days) else "", " It needs fuel on it." if need_fuel else " Now a flame."])
		elif fire != null and player.inventory.has_kind("fuel"):
			# Fuel onto the fire (§AX): the first piece in the pack.
			var fi := player.inventory.slot_of("fuel")
			var fuel: Dictionary = player.inventory.carried[fi]
			match FireStore.add_fuel(fire, fuel, world.days):
				"full":
					_say_note("The fire is stacked full.")
				"hiss":
					player.inventory.take(fi)
					_say_note("The wet %s hisses on the embers and won't catch." % Inventory.title(fuel).to_lower())
				"cold":
					player.inventory.take(fi)
					_say_note("You lay the %s on the dead fire. %s" % [Inventory.title(fuel).to_lower(), "It needs kindling, and a flame." if FireStore.wants_kindling(fire) else "Now a flame."])
				_:
					player.inventory.take(fi)
					_say_note("You put the %s on the fire." % Inventory.title(fuel).to_lower())
		elif Hearth.can_set(fire):
			# This fire is home now: you wake here when you die (§AY).
			Hearth.set_home(world.dir_of(fire.global_position))
			_say_note("This fire is your hearth now.")
		elif player.spear.in_reach():
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
			_take_lying(lying)
		elif planted != null:
			# A planted torch, taken back as it is (still burning, or a stick).
			if player.inventory.count() >= Inventory.carry_slots():
				_say_note("Your hands are full.")
			else:
				player.grab_toward(planted.global_position)
				var back := planted.take()
				player.inventory.add(back)
				if player.in_hand() == "hands":
					player.weapon = "torch"
				_say_note("You take the torch back.")
		elif not _fruit_in_reach().is_empty():
			var fi := _fruit_in_reach()
			player.grab_toward(fi.at)
			if player.inventory.add(FruitCrop.item_for(fi)):
				fruit_crop.take(fi)
				_say_note("You pick the %s." % str(FruitCrop.item_for(fi).title).to_lower())
			else:
				_say_note("Your hands are full.")
		elif _plant_kindling() != "":
			# Kindling from a plant of its genus (§CN): a birch's bark.
			_gather_kindling(_plant_kindling(), player.look.point)
		elif plant >= 0:
			# A cutting, a seed head, a leaf, a cut column or a bundle: it
			# carries the species (Inventory.plant_sample).
			player.grab_toward(player.look.point)
			var it := Inventory.plant_sample(plant, aroid_garden.sample_extra(plant, player.look.point) if aroid_garden else {})
			if player.inventory.add(it):
				_say_note("You take %s." % _sample_words(it))
			else:
				_say_note("Your hands are full.")
		elif player.climbing:
			player.stop_climb()
		elif player.perched:
			player.stop_perch()
		elif creatures.log_in_reach(player.global_position):
			creatures.interact(player.global_position)
		elif _ground_kindling() != "":
			# Kindling from the ground at your feet (§CN).
			_gather_kindling(_ground_kindling(), player.global_position)
		elif player.torch.can_plant():
			# Right click the ground with a lit torch: stand it there.
			player.torch.plant()
			_say_note("You plant the torch.")
		else:
			spent = false
		if spent:
			player.interact_spent_ms = Time.get_ticks_msec()


## Under a roof (a ruin's shelter, a delve): kindling stays dry (§CN).
func _under_roof() -> bool:
	return landmarks.sheltered_at(player.global_position) or Delves.inside


## The kindling the plant or tree under the crosshair gives (§CN): one
## of the biome's kinds whose genera hold its genus; "" none, or you
## carry Kindling.KEEP already (then right click takes a sample again).
func _plant_kindling() -> String:
	var l := player.look
	if l == null or not l.kind in ["plant", "tree"] or l.species_index < 0 or l.point == Vector3.INF:
		return ""
	if l.point.distance_to(player.reach_from()) > float(Inventory.data().get("sample_reach_m", 2.2)) + (1.0 if l.kind == "tree" else 0.0):
		return ""
	if Kindling.count(player.inventory) >= Kindling.KEEP:
		return ""
	var sp: PlantSpecies = SpeciesDB.all()[l.species_index]
	return Kindling.plant_kind(world, player.surface_dir, sp.genus, world.days)


## The kindling at your feet (§CN): the biome's likeliest litter kind,
## when nothing else wants the right click: on the ground (not climbing,
## swimming or in a delve), no climb or cling in reach (the player's own
## prompt), and with a lit torch in hand only crouched (standing, the
## right click plants it).
func _ground_kindling() -> String:
	if player.climbing or player.swimming or player.perched or Delves.inside or not player.is_on_floor():
		return ""
	if player.prompt != "" or Kindling.count(player.inventory) >= Kindling.KEEP:
		return ""
	if player.torch.lit() and not player.crouching:
		return ""
	if chunks.ground_height(player.surface_dir) <= chunks.water_level_at(player.surface_dir) + 0.05:
		return ""
	return Kindling.ground_kind(world, player.surface_dir, world.days)


## Gather one of `kind` (§CN): damp if it rains on you outside a roof
## (§CO).
func _gather_kindling(kind: String, at: Vector3) -> void:
	var it := Kindling.make(kind)
	var wet := Kindling.gathered(it, float(_local_weather.get("rain_mm_h", 0.0)) > 0.1, _under_roof(), world.days)
	if player.inventory.add(it):
		player.grab_toward(at)
		_say_note("You gather %s%s." % [Kindling.name_of(kind).to_lower(), ", wet through" if wet else ""])
	else:
		_say_note("Your hands are full.")


## What a swing of the torch would do (Torch.swing_target), for the prompt.
func _swing_words(t: Array) -> String:
	match str(t[0]):
		"torch":
			return "swing the torch through the flame"
		"planted":
			return "swing the torch to light the planted one"
	var fire: Node3D = t[1]
	return "swing the torch to rekindle the old hearth" if fire.has_meta("old_hearth") else "swing the torch to light the fire"


## The tools a WorldItem of this kind puts in hand.
const TOOL_OF := {"bow": "bow", "spear": "spear"}


## The folk's gifts where you wake (Mike, 29 Sept 2026: you wake empty-
## handed, a new game or after a death, "there is a bow, spear... on the
## ground next to you as a gift from those who saved you"; the fishing
## pole was shelved the same evening, the spear fishes):
## the starting kit (items.json) laid at your side. A set left untaken at
## the last fire is gone.
var _gifts: Array = []


## A point OPENING_LOOK_M along the opening road from the camp, toward
## the people's camp it leads to (RoadNetwork.opening), or Vector3.ZERO
## when this world has none (the dev frame) or the road would not route.
const OPENING_LOOK_M := 60.0

## Where this world's opening camp stands (design 1 Oct, Mike's Mac): a
## kept world rebuilds it where it first was (WorldSave "opening_site");
## only a brand-new world picks one (World.pick_spawn_site), and keeps it.
## A save from before 1 Oct has no opening_site: its saved hearth, when it
## is not a ruin camp's fire, was the opening camp, and is kept as it.
## The dev frame (spawn_choice >= 0) and the checks always pick, and never
## keep.
func _opening_site() -> Vector3:
	# The dev frame and the checks (which never write a save) pick fresh:
	# a check is the same on every machine, whatever worlds it has played.
	if world.spawn_choice >= 0 or WorldSave.read_only:
		return world.pick_spawn_site()
	var kept := _vec(WorldSave.data.get("opening_site", null))
	if kept == Vector3.ZERO:
		var hearth := _vec(WorldSave.data.get("hearth", null))
		if hearth != Vector3.ZERO and not _at_ruin_camp(hearth):
			kept = hearth
			print("[world] an older save: its hearth is the opening camp (%s)" % str(hearth))
	if kept != Vector3.ZERO:
		var site: Vector3 = world.restore_spawn_site(kept, str(WorldSave.data.get("first_camp_kind", "")))
		_keep_opening(site)
		return site
	var site: Vector3 = world.pick_spawn_site()
	_keep_opening(site)
	return site


func _keep_opening(site: Vector3) -> void:
	WorldSave.data["opening_site"] = [site.x, site.y, site.z]
	WorldSave.data["first_camp_kind"] = world.first_camp_kind
	WorldSave.mark_dirty()


## A saved [x, y, z] as a direction (ZERO when absent).
static func _vec(v) -> Vector3:
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2])).normalized()
	return Vector3.ZERO


## Is `d` a ruin camp's fire (an inhabited ruin within RUIN_FIRE_M)?
const RUIN_FIRE_M := 250.0

func _at_ruin_camp(d: Vector3) -> bool:
	for r in Ruins.near(world.planet, d, RUIN_FIRE_M):
		if Ruins.inhabited(r):
			return true
	return false


func _opening_road_ahead(site: Vector3) -> Vector3:
	if world.opening.is_empty() or chunks.roads == null:
		return Vector3.ZERO
	var roads: RoadNetwork = chunks.roads
	for link in roads.links_near(site, 400.0):
		if not bool(link.get("opening", false)):
			continue
		var pts: PackedVector3Array = link.pts
		if str(roads.nodes[link.a].key) != "opening":
			pts = pts.duplicate()
			pts.reverse()
		return RoadNetwork.point_at(pts, minf(OPENING_LOOK_M, RoadNetwork.length_m(pts)))
	return Vector3.ZERO


func _lay_gifts() -> void:
	for g in _gifts:
		if is_instance_valid(g):
			(g as WorldItem).pick_up()
	_gifts = []
	# The ambient profile (design 30 Sept §AW): you wake with nothing and
	# nothing is laid beside you; the camp keeps a bundle of unlit torches
	# by its fire (Torch.lay_bundle, at every camp's fire).
	if Tuning.profile() == "ambient":
		return
	var p: Vector3 = player.global_position
	var side: Vector3 = player.global_basis.x
	var fwd: Vector3 = -player.global_basis.z
	var spots := [side * 0.7 + fwd * 0.3, side * 0.8 - fwd * 0.3]
	var k := 0
	for w in Inventory.data().get("starting_kit", {}).get("worn", []):
		if not w is Dictionary or k >= spots.size():
			continue
		var d: Vector3 = world.dir_of(p + spots[k])
		var gi := WorldItem.drop(Inventory.make(str(w.kind)), world, d, chunks.ground_height(d))
		gi.gift = true
		# Laid side by side, pointing the way you face.
		gi.look_at(gi.global_position + fwd.rotated(d, 0.3 * (k - 1)), d)
		_gifts.append(gi)
		k += 1


## All the gifts taken at once (tools and tests: what picking each up does).
func take_gifts() -> void:
	for g in _gifts:
		if is_instance_valid(g):
			_take_lying(g as WorldItem, false)
	_gifts = []
	player.weapon = "bow" if player.wears("ranged", "bow") else player.weapon


## Take a thing lying on the ground: a tool into its slot (and into your
## hand if it was empty), anything else into a free carry slot.
func _take_lying(lying: WorldItem, say := true) -> void:
	var it: Dictionary = lying.item
	var kind := str(it.get("kind", ""))
	if kind == "torch":
		# One torch from the bundle (or the one torch lying there); into
		# your hand if it was empty (§AW).
		if player.inventory.count() >= Inventory.carry_slots():
			if say:
				_say_note("Your hands are full.")
			return
		var one := Torch.take_from_bundle(lying, world.days) if int(it.get("count", 1)) > 1 or Torch.bundles.any(func(b): return b[0] == lying) else lying.pick_up()
		player.inventory.add(one)
		if player.in_hand() == "hands":
			player.weapon = "torch"
		if say:
			_say_note("You take a torch." if not bool(one.get("lit", false)) else "You take the torch.")
		return
	if kind == "fuel":
		if player.inventory.add(it):
			lying.pick_up()
			var wet := float(_local_weather.get("rain_mm_h", 0.0)) > 0.1 or player.ground_wet > 0.5
			# Dry grass and reeds are kindling too: for them only the rain
			# counts, and not under a roof (§CO).
			if Kindling.kind_of(it) != "":
				wet = float(_local_weather.get("rain_mm_h", 0.0)) > 0.1 and not _under_roof()
			FuelField.gathered(it, wet, world.days)
			if say:
				_say_note("You pick up the %s%s." % [Inventory.title(it).to_lower(), ", wet through" if wet else ""])
		elif say:
			_say_note("Your hands are full.")
		return
	if TOOL_OF.has(kind):
		var slot := str(Inventory.kind_info(kind).get("slot", ""))
		var worn = player.inventory.worn_in(slot)
		if worn != null and str(worn.get("kind", "")) == kind:
			if say:
				_say_note("You have a %s already." % Inventory.title(it).to_lower())
			return
		if player.inventory.wear(it):
			# A delve's find (§CJ) is kept as taken.
			Delves.took(lying)
			lying.pick_up()
			if player.in_hand() == "hands":
				player.weapon = TOOL_OF[kind]
			if say:
				_say_note("You take the %s." % Inventory.title(it).to_lower())
			return
	if player.inventory.add(it):
		lying.pick_up()
	elif say:
		_say_note("Your hands are full.")


# --- Techniques (design 30 Sept §BN, §BP) ---------------------------------------------

## The headman within reach (a camp's marked figure), or null.
func _headman_in_reach() -> Node3D:
	var pos := player.reach_from()
	for key in camps._camps:
		var cn: Node3D = camps._camps[key]
		for s in cn.get_meta("sitters", []):
			if (s as Node3D).get_meta("role", "") == "headman" and (s as Node3D).global_position.distance_to(pos) < 2.6:
				return s
	return null


## A canopy camp's rope ladder (§BT), shown once the headman has met you,
## with the player at one end: [ladder, going_up] or [].
func _ladder_in_reach() -> Array:
	if player.on_ladder():
		return []
	var pos := player.reach_from()
	for key in camps._camps:
		var cn: Node3D = camps._camps[key]
		if not cn.has_meta("ladder"):
			continue
		var lad: Node3D = cn.get_meta("ladder")
		if not is_instance_valid(lad) or not lad.visible:
			continue
		var foot: Vector3 = lad.to_global(lad.get_meta("foot_local", Vector3.ZERO))
		var top: Vector3 = lad.to_global(lad.get_meta("top_local", Vector3.ZERO))
		if pos.distance_to(foot) < 2.4:
			return [lad, true]
		if pos.distance_to(top) < 2.4:
			return [lad, false]
	return []


func _climb_ladder(lad: Node3D, going_up: bool) -> void:
	var foot: Vector3 = lad.to_global(lad.get_meta("foot_local", Vector3.ZERO))
	var top: Vector3 = lad.to_global(lad.get_meta("top_local", Vector3.ZERO))
	var up: Vector3 = world.dir_of(top)
	player.start_ladder(player.global_position, (top + up * 0.15) if going_up else (foot + up * 0.1))


## The headman bestows the people's technique (§BN): a flag kept per
## world and a line in the log; mute. Met: the canopy folk's ladders
## come down (§BT).
func _meet_headman(h: Node3D) -> void:
	var cn := h.get_parent() as Node3D
	var key := str(cn.get_meta("key", ""))
	var people := Peoples.get_people(str(cn.get_meta("people", "")))
	var st := camp_sim.state_of(key)
	if not st.is_empty():
		st.met_headman = true
		WorldSave.mark_dirty()
	var tid := str((people.get("specialists", {}) as Dictionary).get("headman_teaches", ""))
	if Techniques.learn(tid, people):
		_say_note("The headman shows you %s." % Techniques.name_of(tid).to_lower())
	else:
		_say_note("The headman nods.")


func _item_slot(kind: String) -> int:
	return player.inventory.slot_of(kind)


## An ember in hand (live), ground to lay a fire on.
func _ember_lay_ok() -> bool:
	var i := _item_slot("ember")
	if i < 0 or player.in_hand() != "hands" or player.torch.can_plant():
		return false
	var it: Dictionary = player.inventory.carried[i]
	return world.days < float(it.get("until", 0.0)) and not player.torch.plant_spot().is_empty() and _fire_in_reach() == null


func _lay_from_ember() -> void:
	var i := _item_slot("ember")
	var it: Dictionary = player.inventory.take(i)
	var spot := player.torch.plant_spot()
	var d: Vector3 = world.dir_of(spot.pos)
	player_fires.lay_fire(d, int(Techniques.params("ember_carrier").get("fire_units", 2)))
	GameLog.add("Laid a fire from the ember.", "fire_lit")
	_say_note("You lay a fire from the coal.")


## Take a live coal from a lit fire (the technique known, hands empty).
func _ember_take_ok() -> bool:
	var fire := _fire_in_reach()
	return fire != null and FireStore.is_lit(fire) and Techniques.knows("ember_carrier") and player.in_hand() == "hands" and _item_slot("ember") < 0 and not player.inventory.has_kind("fuel")


func _take_ember(fire: Node3D) -> void:
	var hours := float(Techniques.params("ember_carrier").get("ember_game_h", 26.0))
	var it := Inventory.make("ember", {"until": world.days + hours / 24.0, "title": "Ember carrier"})
	if player.inventory.add(it):
		GameLog.add("Wrapped a coal in bark to carry.", "technique")
		_say_note("You wrap a live coal in bark.")
	else:
		_say_note("Your hands are full.")


## A fat lamp from a camp's food store (the technique known): a food
## unit of fat.
func _lamp_take_ok() -> bool:
	var found := _store_in_reach()
	return Techniques.knows("fat_lamp") and not found.is_empty() and (found[0] as Node3D).name == "FoodStore" and _store_item() < 0 and _item_slot("fat_lamp") < 0


func _take_lamp() -> void:
	var found := _store_in_reach()
	var camp_node: Node = found[1]
	var key := "opening" if camp_node == camp else str((camp_node as Node3D).get_meta("key", ""))
	var st := camp_sim.state_of(key)
	var cost := float(Techniques.params("fat_lamp").get("costs_food_units", 1.0))
	if st.is_empty() or float(st.food) < cost:
		_say_note("There is no fat to spare.")
		return
	if player.inventory.add(Inventory.make("fat_lamp", {"title": "Fat lamp"})):
		st.food = float(st.food) - cost
		WorldSave.mark_dirty()
		_say_note("You fill a stone bowl with their fat and set a moss wick.")
	else:
		_say_note("Your hands are full.")


func _lamp_place_ok() -> bool:
	return _item_slot("fat_lamp") >= 0 and player.in_hand() == "hands" and not player.torch.plant_spot().is_empty() and _fire_in_reach() == null and _store_in_reach().is_empty()


func _place_lamp() -> void:
	player.inventory.take(_item_slot("fat_lamp"))
	var spot := player.torch.plant_spot()
	player_fires.place_lamp(world.dir_of(spot.pos), float(Techniques.params("fat_lamp").get("burn_game_h", 8.0)))
	GameLog.add("Set the fat lamp down, lit.", "technique")
	_say_note("You set the lamp down.")


## A pole and line from a branch and a twist of grass or reed, at the
## water (the technique known).
func _pole_make_ok() -> bool:
	if not Techniques.knows("fishing_line") or player.inventory.has_kind("pole"):
		return false
	var branch := false
	var fibre := false
	for it in player.inventory.carried:
		if it is Dictionary and str(it.get("kind", "")) == "fuel":
			if str(it.get("fuel", "")) == "branch":
				branch = true
			elif str(it.get("fuel", "")) in ["grass_bundle", "reeds"]:
				fibre = true
	return branch and fibre and player.fishing_line.cast_point() != Vector3.ZERO


func _make_pole() -> void:
	var bi := -1
	var fi := -1
	for i in player.inventory.carried.size():
		var it = player.inventory.carried[i]
		if it is Dictionary and str(it.get("kind", "")) == "fuel":
			if bi < 0 and str(it.get("fuel", "")) == "branch":
				bi = i
			elif fi < 0 and str(it.get("fuel", "")) in ["grass_bundle", "reeds"]:
				fi = i
	player.inventory.take(maxi(bi, fi))
	player.inventory.take(mini(bi, fi))
	player.inventory.add(Inventory.make("pole", {"title": "Pole and line"}))
	if player.in_hand() == "hands":
		player.weapon = "pole"
	GameLog.add("Cut a pole and twisted a line.", "technique")
	_say_note("You cut a pole and twist a line.")


## The tree ahead can be coppiced (the technique known, hands empty).
func _coppice_tree_ok() -> bool:
	if not Techniques.knows("coppice") or player.in_hand() != "hands" or player.climbing:
		return false
	var ta := player.tree_ahead(player.global_basis.z * -1.0)
	return not ta.is_empty() and Coppice.coppiceable((ta[0] as TerrainChunk).tree_species(ta[1]))


func _stool_in_reach() -> Node3D:
	return Coppice.in_reach(player.reach_from(), 2.4) if Techniques.knows("coppice") else null


## An unlit torch in hand against a conifer (the technique known).
func _resin_tree_ok() -> bool:
	if not Techniques.knows("resin_torch") or not player.torch.in_hand() or player.torch.lit() or bool(player.torch.item().get("resin", false)):
		return false
	var ta := player.tree_ahead(player.global_basis.z * -1.0)
	if ta.is_empty():
		return false
	var sp := (ta[0] as TerrainChunk).tree_species(ta[1])
	var p := Techniques.params("resin_torch")
	for g in p.get("conifer_genera", []):
		if sp.genus == str(g):
			return true
	return bool(p.get("needle_leaf", true)) and sp.leaf_type.find("needle") >= 0


## A camp's woodpile or food store within reach: [store node, camp node]
## (the opening camp's too), or [].
func _store_in_reach() -> Array:
	var r := float(Tuning.table("torch").get("lighting_reach_m", 2.2)) + 0.8
	var found := camps.store_in_reach(player.reach_from(), r)
	if not found.is_empty():
		return found
	for n in [camp.woodpile, camp.food_store]:
		if n != null and is_instance_valid(n) and (n as Node3D).global_position.distance_to(player.reach_from()) < r:
			return [n, camp]
	return []


## The carry slot of the first thing the store would take (fuel on the
## woodpile; fruit, fish, a mushroom, herbs or seeds in the store), or -1.
func _store_item() -> int:
	var found := _store_in_reach()
	if found.is_empty():
		return -1
	var wood: bool = (found[0] as Node3D).name == "Woodpile"
	for i in player.inventory.carried.size():
		var it = player.inventory.carried[i]
		if not it is Dictionary:
			continue
		if wood and CampSim.wood_units(it) > 0.0:
			return i
		if not wood and (CampSim.food_units(it) > 0.0 or CampSim.is_seed(it)):
			return i
	return -1


func _give_to_store(found: Array) -> void:
	var i := _store_item()
	if i < 0:
		return
	var it: Dictionary = player.inventory.take(i)
	var camp_node: Node = found[1]
	var key := "opening" if camp_node == camp else str((camp_node as Node3D).get_meta("key", ""))
	var st := camp_sim.state_of(key)
	if st.is_empty():
		return
	var title := Inventory.title(it).to_lower()
	if (found[0] as Node3D).name == "Woodpile":
		camp_sim.add_wood(st, CampSim.wood_units(it))
		_say_note("You put the %s on their woodpile." % title)
	elif CampSim.is_seed(it):
		camp_sim.add_seeds(st, int(it.get("species", -1)))
		_say_note("You put the %s in their store." % title)
	else:
		camp_sim.add_food(st, CampSim.food_units(it))
		_say_note("You put the %s in their store." % title)


## The campfire within reach of the hands (lit or not), or null.
func _fire_in_reach() -> Node3D:
	return FireStore.nearest(get_tree(), player.reach_from(), float(Tuning.table("torch").get("lighting_reach_m", 2.2)) + 0.6)


## The fruit under the crosshair within reach of the hands (FruitCrop), or {}.
func _fruit_in_reach() -> Dictionary:
	if fruit_crop == null:
		return {}
	var cam := player.camera()
	if cam == null:
		return {}
	return fruit_crop.fruit_at(cam.global_position, -cam.global_basis.z, player.reach_from())


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
	var what: String = {"cutting": "a cutting", "seed": "a seed head", "leaf": "a leaf", "column": "a cut column", "bundle": "a bundle", "berries": "berries"}.get(str(it.get("part", "")), "a sample")
	if it.has("sport") and str(it.sport) != "":
		what += " (%s sport)" % str(it.sport)
	if it.has("seed"):
		return "%s of %s: %s seed" % [what, it.get("binomial", "it"), str(it.seed)]
	return "%s of %s" % [what, it.get("binomial", "it")]


## What killed you, as the log says it (hud.json log.death_lines):
## "Fell", "Drowned", "Killed by a wolf", "Taken by the dark", "Froze".
static func _death_line(cause: String) -> String:
	var lines: Dictionary = Tuning.section("hud", "log").get("death_lines", {})
	if cause.begins_with("creature:"):
		return str(lines.get("creature", "Killed by a {creature}")).replace("{creature}", cause.substr(9).to_lower())
	return str(lines.get(cause, "Died" if cause == "" else cause.capitalize()))


## The world's own lines in the log (design 30 Sept §AZ, hud.json log
## events): a biome first entered, dawn and dusk.
func _log_events() -> void:
	var map: PlanetData = world.planet
	if map != null and not map.biome.is_empty():
		var b: int = map.biome[map.cell_at(player.surface_dir)]
		if b != _last_biome:
			_last_biome = b
			var name := BiomeTemplates.name_of(b)
			GameLog.add_once("biome:" + name, "Came into the %s." % name.to_lower(), "biome_entered")
	var el := sky.sun_elevation_deg
	if not is_nan(_last_sun_el):
		if _last_sun_el < -1.0 and el >= -1.0:
			GameLog.add("Dawn.", "dawn")
		elif _last_sun_el >= -1.0 and el < -1.0:
			GameLog.add("Dusk.", "dusk")
	_last_sun_el = el


func _say_note(text: String) -> void:
	_note = text
	_note_t = 2.5


## Open or close the settings panel (O / F10); the mouse is freed while
## it's open, like the inventory's.
func _toggle_settings(on: bool) -> void:
	if on:
		settings_panel.open()
		player.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		settings_panel.close()
		player.ui_open = inventory_screen.visible
		if not inventory_screen.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_mouse_freed = false
			player.bow.block_until_release()


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
		_mouse_freed = false
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
	if str(it.get("kind", "")) == "torch" and bool(it.get("lit", false)):
		# A lit torch dropped lies there burning (§AW).
		PlantedTorch.plant(it, world, world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d) + 0.06), d, true)
		if player.weapon == "torch" and not player.inventory.has_kind("torch"):
			player.weapon = "hands"
		return
	WorldItem.drop(it, world, d, chunks.ground_height(d))


## E on a spare in the inventory: wear it (what was worn becomes the spare).
func _wear_chosen() -> void:
	var c: Array = inventory_screen.chosen
	if c.is_empty() or c[0] != "worn":
		return
	player.inventory.wear_spare(c[1], c[2])
