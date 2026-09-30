class_name SoundBed
extends Node
## The ambient bed (design 30 Sept §BG, data/audio.json "bed"): sounds
## with no position, which never resolve to a source: the wind, insects,
## distant birds, frogs near water. Four loops (SoundSynth *_loop) on a
## bus of their own, each mixed by the biome's group, the hour, the
## season, the weather and the cold, and the wind by the wind itself.
## Wind pressure changes under canopy: the wind loop drops and closes
## (a low-pass on the bus) by how much sky the place sees (SkySystem's
## enclosure and the dapple stamp). It is what thins at dread stage 1
## (Dread.bed_gain). Everything else in the world is a source you can
## walk to (Audio3D).

const BUS := "Bed"
const LAYERS := ["wind", "insects", "birds_far", "frogs"]

static var D: Dictionary = Audio3D.table().get("bed", {})

var world: Node
var chunks: ChunkManager
var player: Node3D
var sky: SkySystem
var _players := {}
var _gain := {}
var _bus := -1
var _lpf: AudioEffectLowPassFilter
var _timer := 0.0
var _canopy := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D, p_sky: SkySystem) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	sky = p_sky
	_bus = AudioServer.get_bus_index(BUS)
	if _bus < 0:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS)
		AudioServer.set_bus_send(_bus, "Master")
		_lpf = AudioEffectLowPassFilter.new()
		_lpf.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(_bus, _lpf)
	else:
		_lpf = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
	for layer in LAYERS:
		var p := AudioStreamPlayer.new()
		p.name = layer.capitalize()
		p.bus = BUS
		p.stream = SoundSynth.stream(layer + "_loop", 0)
		p.volume_db = -60.0
		p.autoplay = false
		add_child(p)
		p.play(randf() * 3.0)
		_players[layer] = p
		_gain[layer] = 0.0


static func _group_of(biome_key: String) -> String:
	var groups: Dictionary = D.get("biome_groups", {})
	for g in groups:
		if (groups[g] as Array).has(biome_key):
			return str(g)
	return "open"


static func _hour_word(clock_h: float) -> String:
	if clock_h >= 4.5 and clock_h < 7.5:
		return "dawn"
	if clock_h >= 7.5 and clock_h < 17.5:
		return "day"
	if clock_h >= 17.5 and clock_h < 20.5:
		return "dusk"
	return "night"


## Each frame (main): the target mix from where you are and when.
func update_bed(delta: float, weather: Dictionary, clock_h: float) -> void:
	if world == null or player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_retarget(weather, clock_h)
	# Canopy pressure: the wind closes under the trees.
	var canopy: Dictionary = D.get("canopy", {})
	var open := 1.0
	if chunks != null:
		open = chunks.sky_visibility_at(player.global_position)
	if sky != null:
		open *= 1.0 - sky.enclosure()
	_canopy = lerpf(_canopy, 1.0 - open, minf(delta * 2.0, 1.0))
	if _lpf != null:
		_lpf.cutoff_hz = lerpf(float(canopy.get("cutoff_hz_open", 20000.0)), float(canopy.get("cutoff_hz_canopy", 1800.0)), _canopy)
	for layer in LAYERS:
		var p: AudioStreamPlayer = _players[layer]
		var g: float = _gain[layer] * Dread.bed_gain
		if layer == "wind":
			g *= lerpf(1.0, float(canopy.get("wind_gain", 0.45)), _canopy)
		var want_db := linear_to_db(maxf(g, 0.0005)) + float((D.get("layers", {}) as Dictionary).get(layer, {}).get("db", 0.0))
		p.volume_db = lerpf(p.volume_db, want_db, minf(delta * 1.5, 1.0))


func _retarget(weather: Dictionary, clock_h: float) -> void:
	var map: PlanetData = world.get("planet")
	var pd: Vector3 = world.dir_of(player.global_position)
	var biome := FireStore.biome_key(world, pd)
	var group := _group_of(biome)
	var by_group: Dictionary = (D.get("by_group", {}) as Dictionary).get(group, {})
	var by_hour: Dictionary = D.get("by_hour", {})
	var by_season: Dictionary = D.get("by_season", {})
	var hour := _hour_word(clock_h)
	var lat := CubeSphere.latitude(pd)
	var season := str(Seasons.at(world.days, lat).get("name", "summer"))
	var temp := float(weather.get("temp_c", 15.0))
	var rain := float(weather.get("rain_mm_h", 0.0))
	var wind_v: Vector3 = weather.get("wind", Vector3.ZERO)
	var water_km := 99.0
	if map != null and not map.water_dist_km.is_empty():
		water_km = map.water_dist_km[map.cell_at(pd)]
	for layer in LAYERS:
		var g := float(by_group.get(layer, 0.0))
		if by_hour.has(layer):
			g *= float((by_hour[layer] as Dictionary).get(hour, 1.0))
		if by_season.has(layer):
			g *= float((by_season[layer] as Dictionary).get(season, 1.0))
		match layer:
			"wind":
				var w: Dictionary = D.get("wind", {})
				g = clampf(g * 0.3 + wind_v.length() * float(w.get("gain_per_mps", 0.08)), 0.0, float(w.get("max_gain", 1.0)))
			"insects", "frogs":
				g *= smoothstep(float(D.get("cold_c_silence", 4.0)), float(D.get("cold_c_silence", 4.0)) + 8.0, temp)
				g *= 1.0 - 0.7 * smoothstep(0.5, 4.0, rain)
			"birds_far":
				g *= 1.0 - 0.8 * smoothstep(0.5, 4.0, rain)
		if layer == "frogs":
			g *= 1.0 - smoothstep(0.0, float(D.get("frogs_near_water_km", 0.06)), water_km)
		_gain[layer] = g
