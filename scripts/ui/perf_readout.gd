class_name PerfReadout
extends Label
## The dev frame-time readout (design §W; F2 in dev mode): so every
## performance change is measured, not guessed. One line at the top
## centre, refreshed twice a second:
##   frame ms (fps) · cpu ms · gpu ms · shadows ≈ ms, draws, primitives
## frame: the real time between frames; cpu / gpu: the root viewport's
## measured render time (RenderingServer viewport_get_measured_render_time_*);
## draws / primitives: what the shadow pass drew this frame
## (VIEWPORT_RENDER_INFO_TYPE_SHADOW).
## Godot 4.3 gives scripts no per-pass GPU timing, so the shadow pass's ms
## is sampled: every SAMPLE_S the sun's shadows go off for OFF_FRAMES
## frames and the GPU time's drop is the pass's cost (shadows blink
## briefly while the readout is on; it's a dev tool).

const SAMPLE_S := 4.0
const SETTLE_FRAMES := 2
const OFF_FRAMES := 4

var sun: DirectionalLight3D
## Smoothed, for tests and the line: ms per frame, cpu, gpu, shadow.
var frame_ms := 0.0
var cpu_ms := 0.0
var gpu_ms := 0.0
var shadow_ms := -1.0
var shadow_draws := 0
var shadow_prims := 0

var _vp: RID
var _t := 0.0
var _show_t := 0.0
var _sample_t := 0.0
var _off_f := -1
var _gpu_on := 0.0
var _gpu_off := 0.0
var _n_off := 0


func _ready() -> void:
	name = "Perf"
	visible = false
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 4)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_theme_color_override("font_color", Color(1.0, 0.93, 0.6))
	add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.15))
	add_theme_constant_override("outline_size", 3)
	_vp = get_viewport().get_viewport_rid()


func toggle() -> void:
	visible = not visible
	RenderingServer.viewport_set_measure_render_time(_vp, visible)
	_sample_t = 1.0
	_restore()


func _process(delta: float) -> void:
	if not visible:
		return
	var k := clampf(delta * 4.0, 0.0, 1.0)
	frame_ms = lerpf(frame_ms, delta * 1000.0, k)
	cpu_ms = lerpf(cpu_ms, RenderingServer.viewport_get_measured_render_time_cpu(_vp), k)
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_vp)
	gpu_ms = lerpf(gpu_ms, gpu, k)
	_sample(delta, gpu)
	_show_t -= delta
	if _show_t <= 0.0:
		_show_t = 0.5
		text = line()


func line() -> String:
	var sh := ("%.1f ms" % shadow_ms) if shadow_ms >= 0.0 else "…"
	return "%.1f ms (%d fps) · cpu %.1f · gpu %.1f · shadows ≈%s, %d draws, %dk tris" % [
		frame_ms, int(round(1000.0 / maxf(frame_ms, 0.01))), cpu_ms, gpu_ms, sh, shadow_draws, shadow_prims / 1000]


## The shadow pass: its draws and primitives every frame it's on; its ms
## by switching the sun's shadows off for a few frames now and then.
func _sample(delta: float, gpu: float) -> void:
	if sun == null or not is_instance_valid(sun):
		return
	if _off_f < 0:
		if sun.shadow_enabled:
			shadow_draws = RenderingServer.viewport_get_render_info(_vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			shadow_prims = RenderingServer.viewport_get_render_info(_vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			_gpu_on = lerpf(_gpu_on, gpu, 0.2) if _gpu_on > 0.0 else gpu
		_sample_t -= delta
		if _sample_t <= 0.0 and sun.shadow_enabled:
			sun.shadow_enabled = false
			_off_f = 0
			_gpu_off = 0.0
			_n_off = 0
		return
	_off_f += 1
	if _off_f > SETTLE_FRAMES:
		_gpu_off += gpu
		_n_off += 1
	if _off_f >= SETTLE_FRAMES + OFF_FRAMES:
		var off := _gpu_off / maxi(_n_off, 1)
		var est := maxf(_gpu_on - off, 0.0)
		shadow_ms = est if shadow_ms < 0.0 else lerpf(shadow_ms, est, 0.5)
		_restore()


func _restore() -> void:
	if _off_f >= 0 and sun != null and is_instance_valid(sun):
		sun.shadow_enabled = SkySystem.day_shadows() and bool(Tuning.num("look", "light", "shadows"))
	_off_f = -1
	_sample_t = SAMPLE_S
