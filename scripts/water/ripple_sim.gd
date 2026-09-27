class_name RippleSim
extends Node
## The ripple system (owner of World.ripples; Ripples is how everything
## else talks to it): a ripple height buffer over the water near the
## camera, simulated on the GPU every frame, which the water shader reads
## for the surface's swing and slopes and paints as soft light and dark
## bands, one of each per ring.
##
## One buffer, `buffer_texels` (256) a side at `texel_m` (0.25 m), so 64 m
## of water round the camera; beyond `view_fade_m` (22-40 m) the ripples
## fade into the static water shader (data/water/ripples.json). The
## designer's brief sized it as ~256 x 256 per nearby water chunk; one
## camera-centred buffer of that size (agreed at Go, spec Phase 1) is the
## same idea without the chunk borders: a ring spreading from a splash
## never has to cross from one chunk's buffer into the next (per-chunk
## buffers would each stop or bounce it at their edge, or need stitching,
## worst across a cube-face edge), it's one simulation instead of four to
## nine, and it can afford fine texels where you look (a quarter meter
## instead of one), so a footstep's ring is several texels across.
##
## * The window follows the camera (centered a little ahead of it) in
##   whole-texel steps: the simulation moves its content back by the same
##   texels, so ripples stay put on the water, and its grid axes are
##   carried along the planet with it, so the grid never turns. It lives
##   in planet directions, not scene positions, so the floating origin
##   never smears it.
## * Only runs while there's water in the chunks under the window; far
##   water (and everything while it's idle) is the static water shader.
## * Each frame one step (shaders/ripple_step.gdshader, two SubViewports
##   taking turns, each reading the other's last state): waves spread,
##   are damped and fade, contacts kick the surface, rain drops land.
##   Then shaders/ripple_view.gdshader turns the last state into what the
##   water samples (where each ring is in its swing, its slope and how big
##   it is), one frame behind.
## * Contacts (Ripples.splash / wake) are sized by mass and speed (the
##   table's "splash" and "wake" blocks), batched into one list of stamps
##   per step: a splash is a point, a wake the line its body moved along
##   since the last step (a continuous furrow, not a string of splashes).
## * Readers on the CPU (height_at, disturbance_at: fish fleeing, later)
##   get the recent disturbances (where, how big, how long ago) summed as
##   rings with the simulation's wave speed and damping (agreed at Go),
##   not a GPU readback: Godot 4.3 can only read a texture back
##   synchronously, which stalls the renderer. The buffer itself stays on
##   the GPU (`texture`, and the window it covers, for GPU readers).
## * Headless (no renderer) the simulation doesn't run; contacts and the
##   CPU readers still work.
## * Dropped items and falling leaves don't exist in the game yet; when
##   they do, each calls Ripples.splash() where it meets the water (with
##   its own mass in "contacts"), like an arrow.

const DATA_PATH := "res://data/water/ripples.json"
const STEP_SHADER := preload("res://shaders/ripple_step.gdshader")
const VIEW_SHADER := preload("res://shaders/ripple_view.gdshader")
## Stamps per step (ripple_step.gdshader's MAX_STAMPS).
const MAX_STAMPS := 32
## How often the window checks for water under it (s).
const WATER_CHECK_S := 0.5
## A wake key not heard from for this long starts afresh (no line back to
## where it was).
const WAKE_GAP_S := 0.4
## A wake leaves a CPU-side ring source this often (s).
const WAKE_SOURCE_S := 0.25
## Defaults for anything missing from the data file.
const DEFAULTS := {
	"enabled": true,
	"buffer_texels": 256,
	"texel_m": 0.25,
	"lead_m": 10.0,
	"wave_speed_mps": 1.1,
	"damping_per_s": 0.45,
	"flatten_per_s2": 0.4,
	"smoothing_per_s": 0.15,
	"edge_texels": 20.0,
	"view_fade_m": [22.0, 40.0],
	"look": {"height_m": 0.012, "slope": 0.05, "band_wavelength_m": 1.5, "band_edge": 0.0,
		"band_softness": 0.25, "light_band": 0.7, "dark_band": 0.35, "light_side": 0.35,
		"show_from_m": 0.001, "full_at_m": 0.004, "calm": 0.85, "foam": 0.7, "foam_from_m": 0.035,
		"brush": 1.2, "brush_m": 2.5},
	"splash": {"radius_m_per_cuberoot_kg": 0.2, "radius_min_m": 0.4, "radius_max_m": 1.5,
		"push_scale": 0.07, "mass_exponent": 0.3, "speed_exponent": 0.5, "push_max_mps": 0.6},
	"wake": {"radius_m_per_cuberoot_kg": 0.07, "radius_min_m": 0.5, "radius_max_m": 1.2,
		"push_per_mps": 0.07, "push_max_mps": 0.25},
	"rain": {"full_at_mm_h": 4.0, "drops_per_m2_s": 0.05, "push_mps": 0.15, "radius_m": 0.35, "cell_m": 1.0},
	"contacts": {"player_kg": 65.0, "player_foot_kg": 6.0, "player_hand_kg": 3.0,
		"player_stroke_s": 0.7, "player_drop_mps": 1.5, "arrow_kg": 0.05, "creature_kg_per_size_m3": 25.0},
	"readers": {"max_sources": 256, "source_life_s": 6.0, "ring_gain": 0.12, "ring_speed": 0.91},
}

static var _table := {}

var world: Node
var chunks: ChunkManager
var cfg := {}
## Buffer texels a side, and meters per texel.
var size := 256
var texel_m := 0.5
## True while the simulation runs (water near the camera): contacts
## elsewhere, or while it's idle, are ignored.
var running := false
## The window: the planet direction under its center and its texel axes
## (unit vectors, the same in planet and scene frames: the floating origin
## only translates). `center_ij` is the center's absolute texel index,
## the sum of every move, so plane coordinates kept from earlier frames
## stay valid as the window moves.
var center_dir := Vector3.ZERO
var axis_u := Vector3.ZERO
var axis_v := Vector3.ZERO
var center_ij := Vector2i.ZERO
## What the water shows now (one frame behind the simulation;
## ripple_view.gdshader): R where each ring is in its swing (1 crest, 0
## trough), G B slope along axis_u, axis_v, A how big the ripples are
## (eased); height is (2R - 1) times that. Null headless. For GPU
## readers; the window it covers is shown_window.
var texture: Texture2D
## [center_dir, axis_u, axis_v] of the window `texture` covers.
var shown_window: Array = []
## Rain falling on the water now, 0-1.
var rain := 0.0
## Stamps sent to the GPU in the last step, and the time update_ripples
## took (for tools and the notes' performance figures).
var last_stamps := 0
var last_update_us := 0

var _gpu := false
var _vps: Array[SubViewport] = []
var _step_mats: Array[ShaderMaterial] = []
var _view_vp: SubViewport
var _view_mat: ShaderMaterial
var _center_scene := Vector3.ZERO
var _center_r := 0.0
var _shift := Vector2i.ZERO
var _reset := true
var _quiet := 2
var _frame := 0
var _time := 0.0
var _water_timer := 0.0
var _water_near := false
var _stamp_a := PackedVector4Array()
var _stamp_b := PackedVector4Array()
var _key_light := Vector3.ZERO
## The window of the last step (shown by the view next frame).
var _stepped_window: Array = []
## What each step material and the global uniforms were last sent.
var _sent: Array[Dictionary] = [{}, {}]
var _globals := {}
## Contacts since the last step: splashes [plane xy, radius m, push m/s];
## wakes key -> [plane xy, mass, speed].
var _splashes: Array = []
var _wake_now := {}
## Wake keys' last stamped point: key -> [plane xy, time, push since the
## last CPU source, time of that source].
var _wake_last := {}
## Recent ring sources for the CPU readers: [plane xy, time, push, radius].
var _sources: Array = []


## The ripple table (data/water/ripples.json over DEFAULTS), loaded once.
static func table() -> Dictionary:
	if _table.is_empty():
		_table = DEFAULTS.duplicate(true)
		if FileAccess.file_exists(DATA_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
			if parsed is Dictionary:
				for k in parsed:
					if _table.get(k) is Dictionary and parsed[k] is Dictionary:
						(_table[k] as Dictionary).merge(parsed[k], true)
					else:
						_table[k] = parsed[k]
			else:
				push_warning("RippleSim: %s is not valid JSON, using defaults" % DATA_PATH)
	return _table


## A contact's mass, speed or rhythm from the table's "contacts" block
## (player_kg, player_foot_kg, player_hand_kg, player_stroke_s,
## player_drop_mps, arrow_kg).
static func contact(what: String) -> float:
	return float((table().contacts as Dictionary).get(what, 1.0))


## A creature's mass for its ripples, from its body size (the table's
## creature_kg_per_size_m3 times size cubed: a 1.4 m deer ~70 kg).
static func creature_mass(size_m: float) -> float:
	return contact("creature_kg_per_size_m3") * size_m * size_m * size_m


func setup(p_world: Node, p_chunks: ChunkManager) -> void:
	world = p_world
	chunks = p_chunks
	cfg = table()
	size = clampi(int(cfg.buffer_texels), 32, 1024)
	texel_m = maxf(float(cfg.texel_m), 0.05)
	_gpu = bool(cfg.enabled) and DisplayServer.get_name() != "headless"
	world.origin_shifted.connect(_on_origin_shifted)
	if _gpu:
		_build()
	_stamp_a.resize(MAX_STAMPS)
	_stamp_b.resize(MAX_STAMPS)
	var look: Dictionary = cfg.look
	var ref := maxf(float(look.height_m), 1e-5)
	RenderingServer.global_shader_parameter_set("ripple_band", Vector4(
		float(look.band_edge), float(look.band_softness), float(look.light_band), float(look.dark_band)))
	RenderingServer.global_shader_parameter_set("ripple_ring", Vector4(
		float(look.show_from_m) / ref, float(look.full_at_m) / ref, float(look.calm), float(look.foam_from_m) / ref))
	RenderingServer.global_shader_parameter_set("ripple_brush", Vector2(
		float(look.brush), 1.0 / maxf(float(look.brush_m), 0.1)))
	_publish(0.0, Vector3.ZERO)
	world.ripples = self
	Ripples.attach(self)


func _exit_tree() -> void:
	Ripples.detach(self)
	if world and world.ripples == self:
		world.ripples = null
	RenderingServer.global_shader_parameter_set("ripple_window", Vector4.ZERO)


func _build() -> void:
	for i in 2:
		var vp := SubViewport.new()
		vp.name = "RippleState%d" % i
		vp.size = Vector2i(size, size)
		vp.disable_3d = true
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var mat := ShaderMaterial.new()
		mat.shader = STEP_SHADER
		mat.set_shader_parameter("size", size)
		mat.set_shader_parameter("edge_texels", float(cfg.edge_texels))
		var rect := ColorRect.new()
		rect.size = Vector2(size, size)
		rect.material = mat
		vp.add_child(rect)
		add_child(vp)
		_vps.append(vp)
		_step_mats.append(mat)
	# Each reads the other's last state.
	_step_mats[0].set_shader_parameter("state", _vps[1].get_texture())
	_step_mats[1].set_shader_parameter("state", _vps[0].get_texture())
	_view_vp = SubViewport.new()
	_view_vp.name = "RippleView"
	_view_vp.size = Vector2i(size, size)
	_view_vp.disable_3d = true
	_view_vp.transparent_bg = true
	_view_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view_mat = ShaderMaterial.new()
	_view_mat.shader = VIEW_SHADER
	var look: Dictionary = cfg.look
	_view_mat.set_shader_parameter("size", size)
	_view_mat.set_shader_parameter("texel_m", texel_m)
	_view_mat.set_shader_parameter("height_ref", float(look.height_m))
	_view_mat.set_shader_parameter("slope_ref", float(look.slope))
	# The swing of a ring of the bands' own wavelength, rad/s.
	_view_mat.set_shader_parameter("omega", TAU * float(cfg.wave_speed_mps) / maxf(float(look.band_wavelength_m), 0.1))
	var rect := ColorRect.new()
	rect.size = Vector2(size, size)
	rect.material = _view_mat
	_view_vp.add_child(rect)
	add_child(_view_vp)
	texture = _view_vp.get_texture()
	RenderingServer.global_shader_parameter_set("ripple_tex", texture)


func _on_origin_shifted(offset: Vector3) -> void:
	_center_scene -= offset


# --- Contacts (through Ripples) ----------------------------------------------

## Would a contact at this scene position make ripples (the simulation is
## running and it's inside the window)? Lets callers skip the work.
func near(pos: Vector3) -> bool:
	if not running:
		return false
	var rel := pos - _center_scene
	var half := (size * 0.5 - 2.0) * texel_m
	return absf(rel.dot(axis_u)) < half and absf(rel.dot(axis_v)) < half


func add_splash(pos: Vector3, mass_kg: float, speed_mps: float) -> void:
	if not near(pos) or mass_kg <= 0.0:
		return
	var t: Dictionary = cfg.splash
	var r := _radius(t, mass_kg)
	# Heavier and faster both push harder, speed more than mass: an arrow
	# rings the water about as clearly as a wading step, a leaf barely.
	var push := minf(float(t.push_scale) * pow(mass_kg, float(t.mass_exponent))
		* pow(maxf(speed_mps, 0.0), float(t.speed_exponent)), float(t.push_max_mps))
	if push <= 0.0:
		return
	var xy := _plane(pos)
	_splashes.append([xy, r, push])
	_add_source(xy, push, r)


func add_wake(key: int, pos: Vector3, mass_kg: float, speed_mps: float) -> void:
	if not near(pos) or mass_kg <= 0.0:
		return
	_wake_now[key] = [_plane(pos), mass_kg, maxf(speed_mps, 0.0)]


## Ripple height (m, + up) at a scene position: the recent contacts'
## rings, summed analytically (see the class notes); 0 outside the window
## or while it's idle. Rain's chop isn't included (disturbance_at is).
func height_at(pos: Vector3) -> float:
	return _rings(pos, false)


## How disturbed the water is at a scene position (m, >= 0): the height
## envelope of the rings passing there, plus rain's chop. For readers that
## care how rough the water is (fish fleeing), not which way it moves.
func disturbance_at(pos: Vector3) -> float:
	if not near(pos):
		return 0.0
	return _rings(pos, true) + rain * float((cfg.rain as Dictionary).push_mps) * 0.1


func _rings(pos: Vector3, envelope: bool) -> float:
	if not near(pos) or _sources.is_empty():
		return 0.0
	var x := _plane(pos)
	var readers: Dictionary = cfg.readers
	# Each contact's ring, as the simulation draws it: a trough running out
	# at ring_speed times the wave speed, a low crest ahead of it and a
	# higher one behind (a "Mexican hat" about 1.1 footprints wide),
	# spreading as 1 / sqrt(radius) and damped as the simulation damps.
	# ring_speed and ring_gain are fitted to the simulated buffer
	# (tools/ripple_demo.gd prints the two side by side).
	var c := float(cfg.wave_speed_mps) * float(readers.ring_speed)
	var fade := float(cfg.damping_per_s) * 0.5
	var gain := float(readers.ring_gain)
	var h := 0.0
	for s in _sources:
		var tau: float = _time - s[1]
		var r0: float = s[3]
		var front := maxf(c * tau - 0.3 * r0, 0.0)
		var w := maxf(1.1 * r0, 2.0 * texel_m)
		var u := (x.distance_to(s[0]) - front) / w
		if absf(u) > 3.0:
			continue
		var amp: float = gain * s[2] * r0 * sqrt(r0 / (r0 + front)) * exp(-fade * tau)
		if envelope:
			h += amp * exp(-0.4 * u * u)
		else:
			h -= amp * (1.0 - 2.0 * u * u) * exp(-u * u)
	return h


func _radius(t: Dictionary, mass_kg: float) -> float:
	return clampf(float(t.radius_m_per_cuberoot_kg) * pow(mass_kg, 1.0 / 3.0),
		maxf(float(t.radius_min_m), texel_m), maxf(float(t.radius_max_m), texel_m))


## Plane coordinates (m) of a scene position: along the window's axes,
## counted from the absolute texel origin (see center_ij).
func _plane(pos: Vector3) -> Vector2:
	var rel := pos - _center_scene
	return Vector2(rel.dot(axis_u), rel.dot(axis_v)) + Vector2(center_ij) * texel_m


## Plane coordinates -> texel coordinates in the current window (texel i's
## center is at i).
func _texel(xy: Vector2) -> Vector2:
	return xy / texel_m - Vector2(center_ij) + Vector2(size, size) * 0.5 - Vector2(0.5, 0.5)


func _add_source(xy: Vector2, push: float, radius: float) -> void:
	_sources.append([xy, _time, push, radius])
	var cap := int((cfg.readers as Dictionary).max_sources)
	if _sources.size() > cap:
		_sources = _sources.slice(_sources.size() - cap)


# --- Per frame ---------------------------------------------------------------

## Per frame, after everything that makes contacts has moved (main). The
## window follows the camera (`cam_pos`, looking along `cam_forward`);
## `weather` is the eased local weather (rain); `key_light` the sky's key
## light direction (SkySystem.cloud_light_dir: the moon at night, the sun
## by day), whose side of each ring is painted lighter.
func update_ripples(delta: float, cam_pos: Vector3, cam_forward: Vector3, weather: Dictionary, key_light: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	var dt := clampf(delta, 1.0 / 240.0, 1.0 / 20.0)
	_time += dt
	_key_light = key_light
	var up: Vector3 = world.dir_of(cam_pos)
	var ahead := cam_forward - up * cam_forward.dot(up)
	ahead = ahead.normalized() * float(cfg.lead_m) if ahead.length_squared() > 1e-8 else Vector3.ZERO
	_follow(cam_pos + ahead, world.radius_of(cam_pos))

	_water_timer -= delta
	if _water_timer <= 0.0:
		_water_timer = WATER_CHECK_S
		_water_near = _water_in_window()
	var was := running
	running = bool(cfg.enabled) and _water_near
	if running and not was:
		_reset = true

	rain = 0.0
	if not weather.get("snow", false):
		rain = clampf(float(weather.get("rain_mm_h", 0.0)) / maxf(float((cfg.rain as Dictionary).full_at_mm_h), 0.01), 0.0, 1.0)

	var n := _gather_stamps()
	var life := float((cfg.readers as Dictionary).source_life_s)
	while not _sources.is_empty() and _time - float(_sources[0][1]) > life:
		_sources.pop_front()

	if _gpu and running:
		_step(dt, n)
	else:
		_publish(0.0, key_light)
	last_update_us = Time.get_ticks_usec() - t0


## Move the window toward `want` (a scene point) in whole texels, carrying
## its axes along; a jump farther than half the window starts it afresh.
func _follow(want: Vector3, r: float) -> void:
	_center_r = r
	if center_dir == Vector3.ZERO:
		_start_window(world.dir_of(want))
		return
	_center_scene = world.to_scene(center_dir, _center_r)
	var rel := want - _center_scene
	var step := Vector2i(roundi(rel.dot(axis_u) / texel_m), roundi(rel.dot(axis_v) / texel_m))
	if absi(step.x) > size / 2 or absi(step.y) > size / 2:
		_start_window(world.dir_of(want))
		return
	if step == Vector2i.ZERO:
		return
	var nd: Vector3 = world.dir_of(_center_scene + (axis_u * step.x + axis_v * step.y) * texel_m)
	var q := Quaternion(center_dir, nd)
	var u := q * axis_u
	var v := q * axis_v
	axis_u = (u - nd * u.dot(nd)).normalized()
	axis_v = (v - nd * v.dot(nd) - axis_u * v.dot(axis_u)).normalized()
	center_dir = nd
	center_ij += step
	_shift += step
	_center_scene = world.to_scene(center_dir, _center_r)


func _start_window(d: Vector3) -> void:
	center_dir = d
	axis_u = CubeSphere.east(d)
	axis_v = -CubeSphere.north(d) # texel rows run south, so a dump reads north-up
	center_ij = Vector2i.ZERO
	_center_scene = world.to_scene(center_dir, _center_r)
	_shift = Vector2i.ZERO
	_splashes.clear()
	_wake_now.clear()
	_wake_last.clear()
	_sources.clear()
	_stepped_window = []
	_reset = true


## Any water (sea, lake, wetland pool or river) in the chunks under the
## window (its center, corners and edge middles)?
func _water_in_window() -> bool:
	if chunks == null:
		return true
	var half := size * texel_m * 0.5
	for a in [-1.0, 0.0, 1.0]:
		for b in [-1.0, 0.0, 1.0]:
			var c := chunks.chunk_at(world.dir_of(_center_scene + (axis_u * a + axis_v * b) * half))
			if c and not c.data.is_empty() and (not (c.data.get("water", []) as Array).is_empty() or not (c.data.get("rivers", []) as Array).is_empty()):
				return true
	return false


## This step's stamps from the contacts since the last one; returns how
## many. Splashes first, then each wake key's line from where it was last
## stamped.
func _gather_stamps() -> int:
	var n := 0
	for s in _splashes:
		if n >= MAX_STAMPS:
			break
		var p := _texel(s[0])
		_stamp_a[n] = Vector4(p.x, p.y, p.x, p.y)
		_stamp_b[n] = Vector4(float(s[1]) / texel_m, s[2], 0.0, 0.0)
		n += 1
	_splashes.clear()
	var t: Dictionary = cfg.wake
	for key in _wake_now:
		var w: Array = _wake_now[key]
		var xy: Vector2 = w[0]
		var last: Array = _wake_last.get(key, [])
		if last.is_empty() or _time - float(last[1]) > WAKE_GAP_S:
			_wake_last[key] = [xy, _time, 0.0, _time]
			continue
		var from: Vector2 = last[0]
		var length := from.distance_to(xy)
		var mass: float = w[1]
		var r := _radius(t, mass)
		# Each point along the path gets the whole kick once as the body
		# passes (a line longer than the body), or its share of it (a short
		# step): the same furrow whatever the frame rate.
		var pass_push := minf(float(t.push_per_mps) * float(w[2]) * pow(mass / contact("player_kg"), 1.0 / 3.0), float(t.push_max_mps))
		var push := pass_push * length / (length + 2.0 * r)
		if length > 8.0:
			push = 0.0 # a jump, not a swim
		if push > 1e-5 and n < MAX_STAMPS:
			var a := _texel(from)
			var b := _texel(xy)
			_stamp_a[n] = Vector4(a.x, a.y, b.x, b.y)
			_stamp_b[n] = Vector4(r / texel_m, push, length / (length + r), 0.0)
			n += 1
		var acc: float = float(last[2]) + push
		var src_t: float = last[3]
		if _time - src_t >= WAKE_SOURCE_S:
			if acc > 1e-5:
				_add_source(xy, acc, r)
			acc = 0.0
			src_t = _time
		_wake_last[key] = [xy, _time, acc, src_t]
	_wake_now.clear()
	for key in _wake_last.keys():
		if _time - float(_wake_last[key][1]) > WAKE_GAP_S:
			_wake_last.erase(key)
	for i in range(n, MAX_STAMPS):
		_stamp_b[i] = Vector4.ZERO
	last_stamps = n
	return n


## One simulation step on the GPU: writes one buffer from the other, and
## has the view show the other (last frame's) state.
func _step(dt: float, n: int) -> void:
	var target := _frame % 2
	var source := 1 - target
	var m := _step_mats[target]
	var sent: Dictionary = _sent[target]
	if sent.get("dt", -1.0) != dt:
		# What only changes with the frame time (constant at a steady rate).
		var c := float(cfg.wave_speed_mps) / texel_m
		var r: Dictionary = cfg.rain
		var cell := maxi(1, roundi(float(r.cell_m) / texel_m))
		sent.dt = dt
		sent.drop_p = float(r.drops_per_m2_s) * cell * cell * texel_m * texel_m * dt
		m.set_shader_parameter("dt", dt)
		m.set_shader_parameter("c2_dt", dt * c * c)
		m.set_shader_parameter("damping", exp(-float(cfg.damping_per_s) * dt))
		m.set_shader_parameter("flatten_dt", float(cfg.flatten_per_s2) * dt)
		m.set_shader_parameter("smoothing", 1.0 - exp(-float(cfg.smoothing_per_s) * dt))
		m.set_shader_parameter("rain_push", float(r.push_mps))
		m.set_shader_parameter("rain_cell", cell)
		m.set_shader_parameter("rain_radius", maxf(float(r.radius_m) / texel_m, 1.0))
	_send(m, sent, "reset", _reset)
	_send(m, sent, "shift", _shift)
	_send(m, sent, "stamp_count", n)
	if n > 0:
		m.set_shader_parameter("stamp_a", _stamp_a)
		m.set_shader_parameter("stamp_b", _stamp_b)
	_send(m, sent, "rain_p", float(sent.drop_p) * rain)
	if rain > 0.0:
		m.set_shader_parameter("seed", _frame & 0x3fffffff)
		m.set_shader_parameter("origin", center_ij - Vector2i(size / 2, size / 2))
	_vps[target].render_target_update_mode = SubViewport.UPDATE_ONCE
	_view_mat.set_shader_parameter("state", _vps[source].get_texture())
	_view_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _reset:
		_quiet = 2
	_reset = false
	_shift = Vector2i.ZERO
	_frame += 1
	# The view shows the state the last step wrote, in the window as it was
	# then.
	shown_window = _stepped_window
	_stepped_window = [center_dir, axis_u, axis_v]
	if _quiet > 0 or shown_window.is_empty():
		_quiet -= 1
		_publish(0.0, Vector3.ZERO)
		return
	_publish(1.0, _key_light_across(shown_window[0]), shown_window)


## The key light across the water at `d`, scaled by how much the side
## facing it is painted lighter.
func _key_light_across(d: Vector3) -> Vector3:
	var l := _key_light - d * _key_light.dot(d)
	return l * float((cfg.look as Dictionary).light_side)


## Set a step material's parameter only when it changed since it was
## last sent to that material.
static func _send(m: ShaderMaterial, sent: Dictionary, param: String, value: Variant) -> void:
	if sent.get(param) != value:
		sent[param] = value
		m.set_shader_parameter(param, value)


## The water shader's view of the ripples (global shader uniforms, each
## sent only when it changed): `strength` 0 hides them.
func _publish(strength: float, light_across: Vector3, window: Array = []) -> void:
	var fade: Array = cfg.view_fade_m
	_global("ripple_window", Vector4(1.0 / (size * texel_m), strength, float(fade[0]), float(fade[1])))
	_global("ripple_light", Vector4(light_across.x, light_across.y, light_across.z, float((cfg.look as Dictionary).foam)))
	if strength <= 0.0 or window.is_empty():
		return
	_global("ripple_center", world.to_scene(window[0], _center_r))
	_global("ripple_axis_u", window[1])
	_global("ripple_axis_v", window[2])


func _global(param: String, value: Variant) -> void:
	if _globals.get(param) != value:
		_globals[param] = value
		RenderingServer.global_shader_parameter_set(param, value)
