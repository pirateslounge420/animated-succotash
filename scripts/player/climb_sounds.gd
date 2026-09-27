class_name ClimbSounds
## The sounds of the player's effort on a tree (spec Phase 1 (ii): effort
## by rhythm and breath, no stamina meter), synthesized like SoundSynth's
## placeholders (no audio files; seeded variants, cached) but kept here,
## self-contained. TreeContact plays them from AudioStreamPlayer3Ds at the
## hands and the head, so they come from where they happen and fade with
## distance (spec D5).
##
##   scrape      a hand taking a new hold: the bark rasps under the palm (a
##               grainy crackle of high noise) over a soft knock of weight
##               coming onto the wood
##   release     a hand leaving the bark: a short, lighter brush
##   breath_out  the effort of a pull: a voiced, throaty "hhuh" through the
##               nose and mouth
##   breath_in   the quick breath taken in the beat between reaches

const RATE := 22050
const VARIANTS := 4

static var _cache := {}


static func stream(kind: String, variant: int = 0) -> AudioStreamWAV:
	var key := "%s_%d" % [kind, variant % VARIANTS]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("climb_" + key)
	var samples: PackedFloat32Array
	match kind:
		"scrape":
			samples = _scrape(rng, 1.0)
		"release":
			samples = _scrape(rng, 0.45)
		"breath_out":
			samples = _breath(rng, true)
		"breath_in":
			samples = _breath(rng, false)
		_:
			return null
	var wav := _to_wav(samples)
	_cache[key] = wav
	return wav


## Bark under a palm: sparse crackles and a band of rasping noise that
## swell and fade over ~0.2 s, and (a full grip) a dull knock at the start.
static func _scrape(rng: RandomNumberGenerator, weight: float) -> PackedFloat32Array:
	var n := int(RATE * rng.randf_range(0.16, 0.26) * (0.7 + 0.3 * weight))
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp_prev := 0.0
	var lp2 := 0.0
	var knock_f := rng.randf_range(95.0, 140.0)
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		var env := minf(u / 0.08, 1.0) * pow(1.0 - u, 1.6)
		# Rasp: white noise, high-passed then softened (~1.5-5 kHz).
		var w := rng.randf_range(-1.0, 1.0)
		var hp := w - hp_prev
		hp_prev = w
		lp += (hp - lp) * 0.55
		lp2 += (lp - lp2) * 0.7
		var rasp := lp2 * (0.55 + 0.45 * sin(t * TAU * rng.randf_range(28.0, 40.0)))
		# Crackle: sparse bark flakes.
		var crack := 0.0
		if rng.randf() < 0.004 * (1.0 - u):
			crack = rng.randf_range(-1.0, 1.0) * 1.6
		var s := (rasp + crack) * env * 0.7
		# The weight coming onto the wood.
		s += sin(t * TAU * knock_f) * exp(-t * 38.0) * 0.55 * weight
		out[i] = s * (0.55 + 0.45 * weight)
	return out


## A breath: noise shaped by two mouth resonances; the pull's exhale is
## voiced a little (a throaty buzz) and ends quickly, the inhale is higher,
## thinner and quieter.
static func _breath(rng: RandomNumberGenerator, out_breath: bool) -> PackedFloat32Array:
	var dur := rng.randf_range(0.34, 0.46) if out_breath else rng.randf_range(0.28, 0.38)
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var f1 := rng.randf_range(520.0, 700.0) if out_breath else rng.randf_range(900.0, 1200.0)
	var f2 := rng.randf_range(1300.0, 1700.0) if out_breath else rng.randf_range(2200.0, 2700.0)
	var voice_f := rng.randf_range(105.0, 135.0)
	# Two resonant band-pass filters (state variable).
	var b1 := [0.0, 0.0]
	var b2 := [0.0, 0.0]
	var q := 0.35
	var k1 := 2.0 * sin(PI * f1 / RATE)
	var k2 := 2.0 * sin(PI * f2 / RATE)
	var phase := 0.0
	for i in n:
		var u := float(i) / n
		var env: float
		if out_breath:
			env = minf(u / 0.12, 1.0) * pow(1.0 - u, 2.2)
		else:
			env = sin(PI * pow(u, 0.7)) * 0.55
		var w := rng.randf_range(-1.0, 1.0)
		if out_breath:
			phase += voice_f * (1.0 - 0.15 * u) / RATE
			# A little voice: a pulse train under the breath.
			w += 0.9 * (fmod(phase, 1.0) - 0.5) * (1.0 - u)
		b1[0] += k1 * b1[1]
		b1[1] += k1 * (w - b1[0] - q * b1[1])
		b2[0] += k2 * b2[1]
		b2[1] += k2 * (w - b2[0] - q * b2[1])
		out[i] = (b1[1] * 0.6 + b2[1] * 0.4) * env * 0.5
	return out


static func _to_wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
