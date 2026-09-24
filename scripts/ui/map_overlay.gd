class_name MapOverlay
extends CanvasLayer
## Planet map (M): a globe of the planet blueprint in its own little 3D
## world, lit by the real sun so the day/night line sweeps across it. Keys
## 1-5 switch what it shows. Drag to turn it, wheel to zoom.
##   1 Biome   2 Elevation   3 Temperature (°C)   4 Rainfall (mm/yr)
##   5 Live weather: cloud cover and storms from the running simulation

enum Mode { BIOME, ELEVATION, TEMPERATURE, RAINFALL, WEATHER }

const RES := 72
const RELIEF := 1.0 # vertical scale of the globe relief (1 = true scale)

var world: Node
var mode := Mode.BIOME
var _viewport: SubViewport
var _globe: MeshInstance3D
var _marker: MeshInstance3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _legend: Label
var _dirs := PackedVector3Array()
var _yaw := 0.0
var _pitch := 0.3
var _dist := 3.2
var _dragging := false
var _refresh := 0.0


func setup(p_world: Node) -> void:
	world = p_world
	layer = 20
	visible = false
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	container.add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.6)
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	_sun = DirectionalLight3D.new()
	_viewport.add_child(_sun)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_viewport.add_child(_camera)

	_globe = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	_globe.material_override = mat
	_viewport.add_child(_globe)
	_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	_marker.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.25, 0.2)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.3, 0.2)
	_marker.material_override = mm
	_viewport.add_child(_marker)

	_legend = Label.new()
	_legend.position = Vector2(16, 12)
	_legend.add_theme_font_size_override("font_size", 16)
	add_child(_legend)
	_build_mesh()


func toggle(player_dir: Vector3) -> void:
	visible = not visible
	if visible:
		# Face the player's side of the planet.
		_yaw = atan2(player_dir.x, player_dir.z)
		_pitch = asin(clampf(player_dir.y, -0.99, 0.99))
		_recolor()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keys := {KEY_1: Mode.BIOME, KEY_2: Mode.ELEVATION, KEY_3: Mode.TEMPERATURE, KEY_4: Mode.RAINFALL, KEY_5: Mode.WEATHER}
		if keys.has(event.physical_keycode):
			mode = keys[event.physical_keycode]
			_recolor()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(1.6, _dist * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(8.0, _dist * 1.1)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.006, -1.4, 1.4)


func update_map(player_dir: Vector3, delta: float) -> void:
	if not visible:
		return
	var eye := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_camera.look_at_from_position(eye, Vector3.ZERO, Vector3.UP)
	var sun := Astro.sun_dir(world.days)
	_sun.look_at_from_position(sun * 10.0, Vector3.ZERO, Vector3.UP if absf(sun.y) < 0.99 else Vector3.RIGHT)
	_marker.position = player_dir * 1.03
	if mode == Mode.WEATHER:
		_refresh -= delta
		if _refresh <= 0.0:
			_refresh = 1.0
			_recolor()


func _build_mesh() -> void:
	var map: PlanetData = world.planet
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var n := RES + 1
	for f in 6:
		var base := verts.size()
		for j in n:
			for i in n:
				var d := CubeSphere.to_dir(f, -1.0 + 2.0 * i / RES, -1.0 + 2.0 * j / RES)
				var e := maxf(map.terrain.elevation(d, false), 0.0)
				_dirs.append(d)
				verts.append(d * (1.0 + e / PlanetConst.RADIUS_M * RELIEF))
		for j in RES:
			for i in RES:
				var a := base + j * n + i
				indices.append_array([a, a + n + 1, a + 1, a, a + n, a + n + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _dirs
	arrays[Mesh.ARRAY_INDEX] = indices
	var colors := PackedColorArray()
	colors.resize(verts.size())
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_globe.mesh = mesh


func _recolor() -> void:
	var map: PlanetData = world.planet
	var weather: WeatherSim = world.weather
	var colors := PackedColorArray()
	colors.resize(_dirs.size())
	for i in _dirs.size():
		var d := _dirs[i]
		var c := map.cell_at(d)
		var ocean := map.water[c] == PlanetData.Water.OCEAN
		match mode:
			Mode.BIOME:
				colors[i] = BiomeTemplates.color_of(map.biome[c])
			Mode.ELEVATION:
				var e := map.elevation[c]
				if ocean:
					colors[i] = Color(0.05, 0.12, 0.3).lerp(Color(0.2, 0.45, 0.7), clampf(1.0 + e / 3000.0, 0.0, 1.0))
				else:
					colors[i] = _ramp([Color(0.25, 0.5, 0.25), Color(0.7, 0.65, 0.4), Color(0.55, 0.42, 0.32), Color(0.95, 0.95, 0.97)], e / 4500.0)
			Mode.TEMPERATURE:
				colors[i] = _ramp([Color(0.2, 0.3, 0.85), Color(0.6, 0.8, 1.0), Color(0.95, 0.95, 0.85), Color(1.0, 0.65, 0.2), Color(0.85, 0.15, 0.1)], (map.temp_c[c] + 25.0) / 57.0)
			Mode.RAINFALL:
				colors[i] = _ramp([Color(0.75, 0.6, 0.35), Color(0.55, 0.7, 0.3), Color(0.2, 0.55, 0.4), Color(0.15, 0.3, 0.75)], map.precip_mm[c] / 3000.0)
			Mode.WEATHER:
				var base := BiomeTemplates.color_of(map.biome[c]).darkened(0.35)
				var cloud := smoothstep(0.55, 0.95, weather.sample(weather.rel_humidity, d))
				var w := weather.cell_at(d)
				colors[i] = base.lerp(Color(0.95, 0.96, 1.0), cloud * 0.8)
				if weather.storm[w] == 1:
					colors[i] = colors[i].lerp(Color(0.35, 0.2, 0.55), 0.6)
	var arrays := _globe.mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_globe.mesh = mesh
	_legend.text = [
		"Map: biome   (1 Biome  2 Elevation  3 Temperature  4 Rainfall  5 Live weather · drag to turn · M to close)",
		"Map: elevation   green lowland → brown mountain → white peaks; blues are ocean depth",
		"Map: mean temperature, °C   blue −25 · pale 0 · cream 12 · orange 20 · red 32",
		"Map: rainfall   tan 0 mm · green 1000 mm · teal 2000 mm · blue 3000+ mm a year",
		"Map: live weather   white = cloud, purple = storm (updates every second)",
	][mode]


static func _ramp(stops: Array, t: float) -> Color:
	t = clampf(t, 0.0, 1.0) * (stops.size() - 1)
	var i := mini(int(t), stops.size() - 2)
	return (stops[i] as Color).lerp(stops[i + 1], t - i)
