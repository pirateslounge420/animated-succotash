class_name SoundSynth
## Procedural placeholder creature sounds (no audio files needed). Each
## kind has a few seeded variants so a forest of songbirds doesn't repeat
## one clip. Replace with recorded sounds later by pointing a species'
## player at a real AudioStream.
##
##   chirp    quick upward whistles (small birds, goblins)
##   call     two-note honk/whistle (waterbirds, toucans)
##   croak    pulsed low rasp (frogs)
##   howl     long rising-falling glide with vibrato (wolves, yeti)
##   drone    low beating rumble with breath noise (trolls, skinwalker)
##   whisper  breathy formant noise (wisps, witches)

const RATE := 22050
const VARIANTS := 3

static var _cache := {}


static func stream(kind: String, variant: int = 0) -> AudioStreamWAV:
	if kind == "none" or kind == "":
		return null
	var key := "%s_%d" % [kind, variant % VARIANTS]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var samples: PackedFloat32Array
	match kind:
		"chirp":
			samples = _chirp(rng)
		"call":
			samples = _call(rng)
		"croak":
			samples = _croak(rng)
		"howl":
			samples = _howl(rng)
		"drone":
			samples = _drone(rng)
		"whisper":
			samples = _whisper(rng)
		_:
			return null
	var wav := _to_wav(samples)
	_cache[key] = wav
	return wav


static func _to_wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in s:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


static func _buffer(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(seconds * RATE))
	return s


## Attack/release envelope over a note of `n` samples.
static func _env(i: int, n: int, attack: float, release: float) -> float:
	var t := float(i) / RATE
	var left := float(n - i) / RATE
	return minf(clampf(t / attack, 0.0, 1.0), clampf(left / release, 0.0, 1.0))


static func _chirp(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.9)
	var notes := rng.randi_range(2, 4)
	var start := 0
	for k in notes:
		var n := int(rng.randf_range(0.06, 0.12) * RATE)
		var f0 := rng.randf_range(2600.0, 3600.0)
		var f1 := f0 * rng.randf_range(1.25, 1.6)
		var phase := 0.0
		for i in n:
			if start + i >= s.size():
				break
			var t := float(i) / n
			phase += TAU * lerpf(f0, f1, t * t) / RATE
			s[start + i] += sin(phase) * sin(PI * t)
		start += n + int(rng.randf_range(0.03, 0.09) * RATE)
	return s


static func _call(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.9)
	var base := rng.randf_range(420.0, 760.0)
	var half := s.size() / 2
	var phase := 0.0
	for i in s.size():
		var note := 0 if i < half else 1
		var f := base * (1.0 if note == 0 else rng.randf_range(0.78, 0.8))
		phase += TAU * f / RATE
		var j := i - note * half
		var e := _env(j, half, 0.02, 0.08)
		# Nasal honk: fundamental plus strong odd harmonics.
		s[i] = e * (sin(phase) + 0.5 * sin(3.0 * phase) + 0.25 * sin(5.0 * phase))
	return s


static func _croak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.6)
	var pulse_hz := rng.randf_range(22.0, 32.0)
	var tone := rng.randf_range(300.0, 520.0)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * tone / RATE
		var p := fposmod(t * pulse_hz, 1.0)
		var gate := exp(-p * 9.0)
		s[i] = _env(i, s.size(), 0.02, 0.1) * gate * (sin(phase) + 0.4 * sin(2.0 * phase) + rng.randf_range(-0.2, 0.2))
	return s


static func _howl(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(2.6, 3.4))
	var lo := rng.randf_range(330.0, 400.0)
	var hi := lo * rng.randf_range(1.6, 1.9)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		# Rise quickly, hold, sag at the end.
		var glide := smoothstep(0.0, 0.25, t) - 0.35 * smoothstep(0.7, 1.0, t)
		var f := lerpf(lo, hi, glide) * (1.0 + 0.012 * sin(TAU * 5.5 * t * s.size() / RATE))
		phase += TAU * f / RATE
		s[i] = _env(i, s.size(), 0.35, 0.6) * (sin(phase) + 0.18 * sin(2.0 * phase) + 0.05 * rng.randf_range(-1, 1))
	return s


static func _drone(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(3.5)
	var f := rng.randf_range(52.0, 72.0)
	var beat := rng.randf_range(0.7, 1.6)
	var p1 := 0.0
	var p2 := 0.0
	var noise := 0.0
	for i in s.size():
		p1 += TAU * f / RATE
		p2 += TAU * (f + beat) / RATE
		noise = lerpf(noise, rng.randf_range(-1, 1), 0.05)
		s[i] = _env(i, s.size(), 0.8, 1.2) * (sin(p1) + sin(p2) + 0.5 * sin(2.0 * p1) + 0.6 * noise)
	return s


static func _whisper(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(2.4)
	# Noise through two resonant band-passes (rough vowel formants), with a
	# syllable-rate tremble.
	var bands := [[rng.randf_range(600, 900), 0.0, 0.0], [rng.randf_range(1800, 2600), 0.0, 0.0]]
	var syl := rng.randf_range(3.0, 5.0)
	for i in s.size():
		var x := rng.randf_range(-1, 1)
		var y := 0.0
		for b in bands:
			var w: float = TAU * b[0] / RATE
			var r := 0.985
			var v: float = x + 2.0 * r * cos(w) * b[1] - r * r * b[2]
			b[2] = b[1]
			b[1] = v
			y += v * 0.02
		var t := float(i) / RATE
		s[i] = _env(i, s.size(), 0.3, 0.6) * y * (0.55 + 0.45 * sin(TAU * syl * t))
	return s
