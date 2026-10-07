class_name BossSounds
## The boss's voices (design 6 Oct §EY; bosses.json tell, release, lair),
## made like every other sound in the game (SoundSynth: no samples, a few
## seeded variants each). The snake (bosses.desert) first:
##
##   scales_loop   its tell (§EY.3, "scales dragging on stone"): a dry,
##                 gritty rasp of scale edges catching on the floor, in
##                 swells as each wave of the body pushes on, a soft weight
##                 under each swell; 4 s loop. Coiled it is the same loop,
##                 quieter and slower (Boss).
##   breath_loop   in its hole (§EY.2 lair): a slow, deep breath from below,
##                 in and out, muffled by the rock; 6 s loop.
##   retreat       the release (§EY.2): a long rush of scales going away and
##                 down, darkening and falling in pitch to a low rumble.
##
## Each plays on a 3D player tuned by data/audio.json (boss_tell,
## boss_breath, boss_cry; Audio3D). Its hiss is its strike's voice
## (SoundSynth snake_hiss, bosses.json strike.sound; CreatureStrike).

const RATE := SoundSynth.RATE
const VARIANTS := 3

static var _cache := {}


static func stream(kind: String, variant: int = 0) -> AudioStreamWAV:
	var key := "%s_%d" % [kind, variant % VARIANTS]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["boss", key])
	var s: PackedFloat32Array
	match kind:
		"scales_loop":
			s = _scales_loop(rng)
		"breath_loop":
			s = _breath_loop(rng)
		"retreat":
			s = _retreat(rng)
		_:
			return null
	var wav := SoundSynth._to_wav(s)
	if kind.ends_with("_loop"):
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = s.size()
	_cache[key] = wav
	return wav


## A 2-pole band-pass's step: state [y1, y2], centre `f` Hz, sharpness `r`
## (0.9 broad .. 0.995 narrow), its output scaled to about 1 at the centre
## whatever the frequency (a resonator's gain there grows as 1/sin(w), so
## a low one would drown a high one at equal weights).
static func _bp(st: Array, x: float, f: float, r: float) -> float:
	var w := TAU * f / RATE
	var c := 2.0 * r * cos(w)
	var y: float = c * float(st[0]) - r * r * float(st[1]) + x * (1.0 - r)
	st[1] = st[0]
	st[0] = y
	return y * 2.0 * sin(w)


## Scales dragging on stone, in swells.
static func _scales_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(4.0 * RATE)
	var fade := int(0.5 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	# The body's waves: a swell every ~0.8 s (five in the loop, so it loops
	# on a swell's own rhythm).
	var waves := 5.0
	var bands: Array = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
	var f_lo := rng.randf_range(900.0, 1300.0)
	var f_hi := rng.randf_range(2400.0, 3400.0)
	var weight := [0.0, 0.0]
	var grain := 0.0
	var phase := rng.randf() * TAU
	for i in raw.size():
		var t := float(i) / RATE
		var u := t / 4.0
		var swell := pow(0.5 + 0.5 * sin(phase + TAU * waves * u), 1.6)
		var x := rng.randf_range(-1.0, 1.0)
		# Scale edges catching: sparse crackle grains, thicker in a swell.
		if rng.randf() < 0.004 + 0.03 * swell:
			grain = rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		grain *= 0.86
		var rasp: float = _bp(bands[0], x, f_lo, 0.93) * 1.0 + _bp(bands[1], x, f_hi, 0.9) * 0.8
		var grit: float = _bp(bands[2], grain, 4200.0, 0.8) * 1.6
		# The weight under it: a soft low push with each swell.
		var w: float = _bp(weight, x, 90.0, 0.985) * 0.5
		raw[i] = rasp * (0.25 + 0.75 * swell) + grit * (0.3 + 0.7 * swell) + w * swell
	return SoundSynth._loopify(raw, n, fade)


## A slow deep breath from below the floor: in (a low rising draw), a held
## beat, out (a long rough exhale over a low rumble), a pause; muffled.
static func _breath_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(6.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var b1: Array = [0.0, 0.0]
	var b2: Array = [0.0, 0.0]
	var rum: Array = [0.0, 0.0]
	var lp := 0.0
	var f_in := rng.randf_range(380.0, 520.0)
	var f_out := rng.randf_range(260.0, 360.0)
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		var inhale := smoothstep(0.2, 1.3, t) * (1.0 - smoothstep(1.5, 2.0, t))
		var exhale := smoothstep(2.4, 2.8, t) * (1.0 - smoothstep(3.6, 5.2, t))
		var draw: float = _bp(b1, x, f_in * (1.0 + 0.25 * inhale), 0.95) * inhale * 0.7
		var out: float = _bp(b2, x, f_out, 0.93) * exhale
		var low: float = _bp(rum, x, 55.0, 0.99) * 0.6 * exhale
		# The rock between: everything low-passed (still breath, not rumble).
		lp = lerpf(lp, draw + out + low, 0.3)
		s[i] = lp
	return s


## The release: a long rush going away and down.
static func _retreat(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := SoundSynth._buffer(5.5)
	var b1: Array = [0.0, 0.0]
	var b2: Array = [0.0, 0.0]
	var rum: Array = [0.0, 0.0]
	var lp := 0.0
	var grain := 0.0
	for i in s.size():
		var u := float(i) / s.size()
		var x := rng.randf_range(-1.0, 1.0)
		# Away: the rasp darkens and falls; down: a rumble comes up under it
		# and everything closes in.
		var f := lerpf(2600.0, 420.0, pow(u, 0.7))
		if rng.randf() < 0.03 * (1.0 - u):
			grain = rng.randf_range(0.5, 1.0)
		grain *= 0.85
		var rasp: float = _bp(b1, x + grain, f, 0.9) * (1.0 - u * 0.7)
		var hiss: float = _bp(b2, x, f * 2.2, 0.88) * pow(1.0 - u, 2.0) * 0.6
		var low: float = _bp(rum, x, lerpf(80.0, 45.0, u), 0.99) * 0.8 * smoothstep(0.25, 0.7, u)
		lp = lerpf(lp, rasp + hiss + low, lerpf(0.9, 0.08, u))
		var env := minf(u / 0.03, 1.0) * pow(1.0 - u, 1.3)
		s[i] = lp * env
	return s
