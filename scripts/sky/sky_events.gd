class_name SkyEvents
extends Node
## Night sky events, in two tiers.
##
##   shooting stars  common: small pale streaks lasting under a second, a
##                   simple chance per second (shooting_stars_per_minute
##                   on a dark night); purely atmospheric.
##   meteors         rare: bigger, slower, longer streaks with a glowing
##                   head in one of several colors (the colors real
##                   meteors take from what burns: sodium orange, magnesium
##                   blue-green, nickel green, calcium violet, iron
##                   yellow), a faint flash that lights the land, and a
##                   hiss and far rumble. Every meteor_roll_interval_s of
##                   darkness the I Ching is cast (IChing): only an
##                   all-changing hexagram, 1 in 4,096, brings one.
##
## Both are in the atmosphere, so they're drawn in the viewer's local sky
## (sky shader: up to MAX_STREAKS at once) and hidden by cloud layers.

const MAX_STREAKS := 3

## Tuning. At the defaults, a dark night shows about two shooting stars a
## minute, and a meteor comes about once every 5.7 hours of darkness
## (4,096 casts x 5 s), about once in 8-9 nights.
@export var shooting_stars_per_minute := 2.0
@export var meteor_roll_interval_s := 5.0

const METEOR_COLORS := [
	Color(1.0, 0.62, 0.22), # sodium: orange
	Color(0.45, 1.0, 0.72), # magnesium: blue-green
	Color(0.35, 1.0, 0.35), # nickel: green
	Color(0.72, 0.45, 1.0), # calcium: violet
	Color(1.0, 0.93, 0.45), # iron: yellow
	Color(0.55, 0.75, 1.0), # blue-white
]

var sky: SkySystem
var rng := RandomNumberGenerator.new()
## 0-1 light cast on the land by a meteor now, and its color (SkySystem
## adds it to the ambient).
var flash := 0.0
var flash_color := Color.WHITE
## Set by the game for testing: the next roll brings a meteor.
var force_meteor := false

var _streaks: Array = [] # {start, end, t, duration, trail, width, bright, color, meteor}
var _roll_timer := 0.0
var _voice: AudioStreamPlayer


func setup(p_sky: SkySystem) -> void:
	sky = p_sky
	rng.randomize()
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = -6.0
	add_child(_voice)


## Per frame: `up`, `north` the viewer's local frame; `darkness` 0 by day,
## 1 on a dark night; `clear` 0-1 how clear the sky is.
func update_events(delta: float, up: Vector3, north: Vector3, darkness: float, clear: float) -> void:
	var visible := darkness * clear
	if visible > 0.05 and rng.randf() < shooting_stars_per_minute / 60.0 * delta * visible:
		_spawn(up, north, false)
	if darkness > 0.5:
		_roll_timer -= delta
		if _roll_timer <= 0.0:
			_roll_timer = meteor_roll_interval_s
			if force_meteor or IChing.all_changing(rng):
				force_meteor = false
				_spawn(up, north, true)
	flash = 0.0
	var alive: Array = []
	for s in _streaks:
		s.t += delta
		if s.t < s.duration:
			alive.append(s)
			if s.meteor:
				var p: float = s.t / s.duration
				flash = maxf(flash, sin(PI * p) * 0.6)
				flash_color = s.color
	_streaks = alive
	_push()


func _spawn(up: Vector3, north: Vector3, meteor: bool) -> void:
	if _streaks.size() >= MAX_STREAKS:
		return
	var east := north.cross(up).normalized()
	# Start somewhere in the upper sky, head off at a downward slant.
	var az := rng.randf() * TAU
	var el := deg_to_rad(rng.randf_range(30.0, 75.0) if meteor else rng.randf_range(20.0, 80.0))
	var horiz := north * cos(az) + east * sin(az)
	var start := (horiz * cos(el) + up * sin(el)).normalized()
	var heading := rng.randf() * TAU
	var tangent := (north * cos(heading) + east * sin(heading))
	tangent = (tangent - start * tangent.dot(start) - up * 0.35).normalized()
	var travel := deg_to_rad(rng.randf_range(25.0, 45.0) if meteor else rng.randf_range(6.0, 14.0))
	var end := (start * cos(travel) + tangent * sin(travel)).normalized()
	var s := {
		"start": start, "end": end, "t": 0.0,
		"duration": rng.randf_range(2.6, 4.0) if meteor else rng.randf_range(0.35, 0.8),
		"trail": 0.45 if meteor else 0.35,
		"width": 0.006 if meteor else 0.0018,
		"bright": 3.5 if meteor else 1.4,
		"color": METEOR_COLORS[rng.randi() % METEOR_COLORS.size()] if meteor else Color(0.88, 0.92, 1.0),
		"meteor": meteor,
	}
	_streaks.append(s)
	if meteor and _voice:
		_voice.stream = SoundSynth.stream("meteor", rng.randi())
		_voice.play()


func _push() -> void:
	var heads := PackedVector3Array()
	var tails := PackedVector3Array()
	var colors := PackedColorArray()
	heads.resize(MAX_STREAKS)
	tails.resize(MAX_STREAKS)
	colors.resize(MAX_STREAKS)
	for i in _streaks.size():
		var s: Dictionary = _streaks[i]
		var p: float = s.t / s.duration
		var start: Vector3 = s.start
		heads[i] = start.slerp(s.end, p)
		tails[i] = start.slerp(s.end, maxf(p - s.trail, 0.0))
		# Fades in fast, out at the end; the head flares near the end
		# for meteors (breaking up).
		var fade := smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.75, 1.0, p))
		var flare := 1.0 + (1.2 * smoothstep(0.55, 0.8, p) if s.meteor else 0.0)
		var c: Color = s.color
		colors[i] = Color(c.r, c.g, c.b, s.bright * fade * flare) # alpha: brightness
	sky.sky_material.set_shader_parameter("streak_count", _streaks.size())
	sky.sky_material.set_shader_parameter("streak_head", heads)
	sky.sky_material.set_shader_parameter("streak_tail", tails)
	sky.sky_material.set_shader_parameter("streak_color", colors)
	var widths := PackedFloat32Array()
	widths.resize(MAX_STREAKS)
	for i in _streaks.size():
		widths[i] = _streaks[i].width
	sky.sky_material.set_shader_parameter("streak_width", widths)
