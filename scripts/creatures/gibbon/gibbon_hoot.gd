class_name GibbonHoot
## The gibbon's calls (spec Phase 1 (iii)), synthesized the way SoundSynth
## makes the other placeholder creature sounds (no audio files; seeded
## variants, cached, the same 16-bit mono WAV through SoundSynth._to_wav),
## kept here so SoundSynth itself is untouched. Gibbon plays them from an
## AudioStreamPlayer3D, so they pan and fade with distance (spec D5).
##
##   hoot   a contact call: one to three soft rising "hoo-wup" notes
##   song   the lar gibbon's great call: hoots that climb in pitch and
##          quicken, peak in a fast warbling trill, and fall away
##
## A note is a clear, flute-like tone (the fundamental, a little second
## and third harmonic) that glides up and sags at the end, with a slight
## vibrato and a breathy onset.

const VARIANTS := 4

static var _cache := {}


static func stream(kind: String, variant: int = 0) -> AudioStreamWAV:
	var key := "%s_%d" % [kind, variant % VARIANTS]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gibbon_" + key)
	var samples: PackedFloat32Array
	match kind:
		"hoot":
			samples = _hoot(rng)
		"song":
			samples = _song(rng)
		_:
			return null
	var wav := SoundSynth._to_wav(samples)
	_cache[key] = wav
	return wav


## A few "hoo-wup" notes, evenly spaced.
static func _hoot(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var notes := rng.randi_range(1, 3)
	var base := rng.randf_range(520.0, 640.0)
	var out := PackedFloat32Array()
	for k in notes:
		var len := rng.randf_range(0.26, 0.36)
		_note(out, len, base * rng.randf_range(0.97, 1.03), rng.randf_range(1.55, 1.8), 0.8, rng)
		_rest(out, rng.randf_range(0.14, 0.24))
	_rest(out, 0.1)
	return out


## The great call: 7-10 notes rising from ~500 Hz toward ~1.3 kHz while
## the gaps shrink, a trill at the top, then two falling notes.
static func _song(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var notes := rng.randi_range(7, 10)
	var f0 := rng.randf_range(480.0, 560.0)
	for k in notes:
		var t := float(k) / (notes - 1)
		var len := lerpf(0.42, 0.2, t)
		var f := f0 * lerpf(1.0, 1.55, t)
		_note(out, len, f, lerpf(1.35, 1.75, t), lerpf(0.55, 1.0, t), rng)
		_rest(out, lerpf(0.26, 0.05, t))
	# Trill: fast alternating notes at the peak.
	var top := f0 * 1.6
	for k in rng.randi_range(6, 9):
		_note(out, 0.075, top * (1.0 if k % 2 == 0 else 1.18), 1.08, 0.9, rng)
	_rest(out, 0.12)
	for k in 2:
		_note(out, 0.3, top * (0.85 - 0.12 * k), 0.8, 0.7 - 0.2 * k, rng)
		_rest(out, 0.1)
	_rest(out, 0.15)
	return out


## One note appended to `out`: `len` s long from `f` Hz, gliding up to
## `f * rise` (sagging back a little at the end), at `amp`.
static func _note(out: PackedFloat32Array, len: float, f: float, rise: float, amp: float, rng: RandomNumberGenerator) -> void:
	var n := int(len * SoundSynth.RATE)
	var start := out.size()
	out.resize(start + n)
	var phase := 0.0
	var breath := 0.0
	var vib_hz := rng.randf_range(5.0, 7.0)
	for i in n:
		var t := float(i) / n
		# Glide: up over the first two thirds, a small sag at the end.
		var glide := smoothstep(0.0, 0.65, t) - 0.12 * smoothstep(0.75, 1.0, t)
		var fi := f * lerpf(1.0, rise, glide) * (1.0 + 0.012 * sin(TAU * vib_hz * float(i) / SoundSynth.RATE))
		phase += TAU * fi / SoundSynth.RATE
		var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.7, 1.0, t))
		breath = lerpf(breath, rng.randf_range(-1.0, 1.0), 0.3)
		var tone := sin(phase) + 0.22 * sin(2.0 * phase) + 0.08 * sin(3.0 * phase)
		out[start + i] = amp * env * (tone + breath * 0.18 * (1.0 - smoothstep(0.0, 0.3, t)))


static func _rest(out: PackedFloat32Array, seconds: float) -> void:
	out.resize(out.size() + int(seconds * SoundSynth.RATE))
