class_name NightRiderSounds
## The Night Riders' sounds, synthesized like SoundSynth's (no audio
## files; a few seeded variants each):
##
##   hoof           one soft footfall on the forest floor: a dull low
##                  thump and a short hush of needles and moss, no clop,
##                  nothing thrown up (played 3D at the hoof that lands)
##   hoofbeats_far  the biome cue: the pair walking somewhere off in the
##                  forest, ~12 s. Two four-beat walks, the second out of
##                  step, heard from a few hundred meters: muffled, a
##                  little echo off the trees, swelling as they pass and
##                  fading away. Played 3D, far off (Mythics).

const VARIANTS := 6
## The long cue has one version (it takes a moment to make: prewarm()).
const FAR_VARIANTS := 1

static var _cache := {}
static var _mutex := Mutex.new()
static var _tasks := {}


## The sound (made on first use, then kept). Safe from any thread.
static func stream(kind: String, variant := 0) -> AudioStreamWAV:
	var key := "%s_%d" % [kind, posmod(variant, FAR_VARIANTS if kind == "hoofbeats_far" else VARIANTS)]
	_mutex.lock()
	var wav: AudioStreamWAV = _cache.get(key)
	var task: int = _tasks.get(key, -1)
	_tasks.erase(key)
	_mutex.unlock()
	if task >= 0:
		# Made (or being made) on a worker: collect it.
		WorkerThreadPool.wait_for_task_completion(task)
		_mutex.lock()
		wav = _cache.get(key)
		_mutex.unlock()
	if wav:
		return wav
	return _make(kind, key)


static func _make(kind: String, key: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var samples: PackedFloat32Array
	match kind:
		"hoof":
			samples = _hoof(rng, 1.0)
		"hoofbeats_far":
			samples = _far(rng)
		_:
			return null
	var wav := SoundSynth._to_wav(samples)
	_mutex.lock()
	_cache[key] = wav
	_mutex.unlock()
	return wav


## Make a sound on a worker thread now, so its first use doesn't stall a
## frame (the far cue is a few seconds of work).
static func prewarm(kind: String, variant := 0) -> void:
	var key := "%s_%d" % [kind, posmod(variant, FAR_VARIANTS if kind == "hoofbeats_far" else VARIANTS)]
	_mutex.lock()
	if not _cache.has(key) and not _tasks.has(key):
		_tasks[key] = WorkerThreadPool.add_task(func() -> void: _make(kind, key))
	_mutex.unlock()


## Wait for any sound still being made (at shutdown).
static func finish() -> void:
	_mutex.lock()
	var ids: Array = _tasks.values()
	_tasks.clear()
	_mutex.unlock()
	for id in ids:
		WorkerThreadPool.wait_for_task_completion(id)


## One soft footfall. `dull` < 1 darkens it further (distance).
static func _hoof(rng: RandomNumberGenerator, dull: float) -> PackedFloat32Array:
	var s := SoundSynth._buffer(0.32)
	var f0 := rng.randf_range(78.0, 96.0)
	var phase := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var hush := 0.0
	for i in s.size():
		var t := float(i) / SoundSynth.RATE
		# The weight coming down: a low thump falling in pitch.
		phase += TAU * f0 * (1.0 - 0.45 * minf(t / 0.12, 1.0)) / SoundSynth.RATE
		var thump := sin(phase) * exp(-t * 20.0)
		# The hoof pressing in: dark filtered noise, a soft attack.
		var x := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, x, 0.05 * dull)
		lp2 = lerpf(lp2, lp, 0.3)
		var body := lp2 * 7.0 * minf(t / 0.012, 1.0) * exp(-t * 26.0)
		# Needles and moss giving: a brief, soft hush (no crunch).
		hush = lerpf(hush, x, 0.22 * dull)
		var needles := hush * 0.35 * minf(t / 0.02, 1.0) * exp(-t * 45.0)
		s[i] = thump * 0.9 + body + needles
	return s


## The distant pair: two four-beat walks (the second trailing, out of
## step), each footfall darkened by distance and echoed off the trees,
## under a swell as they pass.
static func _far(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var seconds := 12.0
	var s := SoundSynth._buffer(seconds)
	var hooves: Array[PackedFloat32Array] = []
	for k in 4:
		hooves.append(_hoof(rng, 0.45))
	var cycle := 1.05
	var echoes := [[0.0, 1.0], [0.13, 0.32], [0.29, 0.18], [0.47, 0.1]]
	for rider in 2:
		var offset := 0.4 * cycle * rider + 0.6
		var t0 := offset
		var beat := 0
		while t0 < seconds - 0.8:
			var h: PackedFloat32Array = hooves[(beat + rider) % hooves.size()]
			var amp := rng.randf_range(0.75, 1.15) * (0.85 if rider == 1 else 1.0)
			for e in echoes:
				var start := int((t0 + float(e[0]) + rng.randf_range(-0.012, 0.012)) * SoundSynth.RATE)
				var g: float = amp * float(e[1])
				for i in h.size():
					var j := start + i
					if j >= s.size():
						break
					s[j] += h[i] * g
			beat += 1
			t0 += cycle * 0.25 * rng.randf_range(0.96, 1.04)
	# They come into hearing, pass, and fade into the forest; a last low
	# pass so nothing is bright at this distance.
	var lp := 0.0
	for i in s.size():
		var t := float(i) / SoundSynth.RATE
		var swell := smoothstep(0.0, 3.5, t) * (1.0 - smoothstep(seconds - 4.5, seconds, t))
		lp = lerpf(lp, s[i], 0.35)
		s[i] = lp * (0.2 + 0.8 * swell)
	return s
