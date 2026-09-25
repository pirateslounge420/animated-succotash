class_name StormFX
extends Node3D
## Storms, driven by the live weather's storm level (WeatherSim, 0-1) and
## rain rate at the player:
##   * lightning while the storm is strong: a brief flicker of a third
##     DirectionalLight3D from a random bearing, flashing the sky, the
##     clouds and the ambient light; the stronger the storm, the more often;
##   * thunder after it, delayed ~3 s per km of (made-up) distance: a
##     sharp crack and rumble close by, a long low rumble far off; a close
##     strike shakes the camera;
##   * the water answers heavy rain: rivers and waves run faster, drops
##     pock the surface, and fresh water (rivers, lakes, wetland pools)
##     rises a little, filling over a couple of minutes and draining
##     slower. Visual only: swimming depth and the terrain don't change.

const STORM_MIN := 0.55
const FLASH_COLOR := Color(0.82, 0.88, 1.0)
const MAX_RISE_M := 0.3

## 0-1 lightning flash right now (SkySystem, CloudLayers read it).
var flash := 0.0
## 0-1 how soaked the land is (fills with rain, drains after).
var wetness := 0.0

var sky: SkySystem
var player: PlanetPlayer
var _light: DirectionalLight3D
var _thunder: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _strike_t := -1.0 # seconds since the current strike, -1 = none
var _strike_energy := 1.0
var _pending: Array = [] # [seconds left, distance km]
var _next := 10.0


func setup(p_sky: SkySystem, p_player: PlanetPlayer) -> void:
	sky = p_sky
	player = p_player
	_rng.randomize()
	_light = DirectionalLight3D.new()
	_light.name = "Lightning"
	_light.light_color = FLASH_COLOR
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_thunder = AudioStreamPlayer.new()
	add_child(_thunder)


## Per frame, after SkySystem.update_sky(). `up` is the player's local up.
func update_storm(delta: float, up: Vector3, weather: Dictionary) -> void:
	var storm := float(weather.get("storm", 0.0))
	var rain := float(weather.get("rain_mm_h", 0.0))
	var snow: bool = weather.get("snow", false)

	# Lightning: a strike every ~40 s at the threshold, every ~7 s in the
	# worst of it.
	if storm > STORM_MIN and not snow:
		_next -= delta
		if _next <= 0.0:
			var s := clampf((storm - STORM_MIN) / (1.0 - STORM_MIN), 0.0, 1.0)
			_next = _rng.randf_range(0.5, 1.5) * lerpf(40.0, 7.0, s)
			_strike(up)
	_flicker(delta)
	for p in _pending:
		p[0] -= delta
		if p[0] <= 0.0:
			_boom(p[1])
	_pending = _pending.filter(func(p): return p[0] > 0.0)

	# The land soaks up rain and drains slowly.
	var target := clampf(rain / 4.0 + storm * 0.4, 0.0, 1.0) if not snow else 0.0
	wetness = move_toward(wetness, target, delta / (120.0 if target > wetness else 300.0))
	var mats := TerrainChunk.water_materials()
	for m in mats:
		m.set_shader_parameter("storm_flow", wetness)
		m.set_shader_parameter("rain_drops", 0.0 if snow else clampf(rain / 3.0, 0.0, 1.0))
	mats[1].set_shader_parameter("water_rise", wetness * MAX_RISE_M)


func _strike(up: Vector3) -> void:
	# Close strikes are rarer than far ones.
	var dist_km := 0.25 + 5.75 * pow(_rng.randf(), 0.7)
	var az := _rng.randf() * TAU
	var el := deg_to_rad(_rng.randf_range(25.0, 70.0))
	var north := CubeSphere.north(up)
	var east := CubeSphere.east(up)
	var from := ((north * cos(az) + east * sin(az)) * cos(el) + up * sin(el)).normalized()
	var hint := up if absf(from.dot(up)) < 0.99 else north
	_light.global_transform = Transform3D(Basis.looking_at(-from, hint), Vector3.ZERO)
	_strike_energy = clampf(2.2 / (0.6 + dist_km * 0.5), 0.35, 2.4)
	_strike_t = 0.0
	_pending.append([dist_km * 3.0, dist_km])


## A strike flickers: a bright stroke, a dip, a return stroke, a fade.
func _flicker(delta: float) -> void:
	if _strike_t < 0.0:
		flash = 0.0
		_light.visible = false
		return
	_strike_t += delta
	var t := _strike_t
	var k := 0.0
	if t < 0.07:
		k = 1.0
	elif t < 0.13:
		k = 0.15
	elif t < 0.22:
		k = 0.8
	elif t < 0.55:
		k = 0.8 * (1.0 - (t - 0.22) / 0.33)
	else:
		_strike_t = -1.0
	flash = k * clampf(_strike_energy / 2.4, 0.2, 1.0)
	_light.visible = k > 0.0
	_light.light_energy = k * _strike_energy
	if k > 0.0:
		sky.event_flash(flash * 0.9, FLASH_COLOR)
		sky.sky_material.set_shader_parameter("lightning", flash)
	else:
		sky.sky_material.set_shader_parameter("lightning", 0.0)


func _boom(dist_km: float) -> void:
	var near := dist_km < 1.2
	_thunder.stream = SoundSynth.stream("thunder_near" if near else "thunder_far", _rng.randi())
	_thunder.volume_db = lerpf(0.0, -18.0, clampf(dist_km / 6.0, 0.0, 1.0))
	_thunder.pitch_scale = _rng.randf_range(0.9, 1.05)
	_thunder.play()
	if dist_km < 0.8 and player:
		player.shake(lerpf(1.0, 0.35, dist_km / 0.8))
