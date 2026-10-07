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
##   meteor   a rising hiss as it streaks over, then a far rumble (sky events)
##   rustle   leaves shaken: a crackling burst of high filtered noise
##   step_grass / _dirt / _sand / _stone / _snow / _wood / _water
##            footsteps (Footsteps): a soft swish, a dull thud, a hiss, a
##            sharp knock, a crunch, a hollow knock, a splash
##   rain_loop    steady rain, seamless 4 s loop (WeatherFX)
##   thunder_near a crack and a heavy rumble; thunder_far a long low roll
##   bow_draw     a creak of wood and string as the bow bends
##   bow_release  the string's twang and the arrow's whoosh
##   arrow_hit    a dull thunk of an arrow biting into wood or earth
##   scuff        a sole scraping hard across bark, rock or grit: a wall
##                jump's kick, or the skid of a sharp turn (Footsteps)
##   crack        dry wood snapping: a sharp splintering burst (a handhold
##                breaking under you)
##   whip         a green stem springing back: a quick rising swish
##   hurt         a blunt thump and a gasp of breath (the player hit)
##   hitmarker    a short sharp tick: the crosshair's X on a critical or
##                a kill (StatusHud; a UI sound, not placed in the world)
##   murmur       camp talk from a little way off: three or four soft
##                voices overlapping, no words (Camps); murmur_one, one
##                voice alone (Encampment: one of the two speaking)
##   fire_hiss_loop  a fire's steady soft hiss, seamless 4 s loop, no pops
##                (Campfire; the bed under the pops below)
##   fire_snap    a sharp snap: a noise burst gone in a few ms and a short
##                ring (Campfire, on its own random clock)
##   fire_crackle a softer crackle: a cluster of small pops with a low
##                thump under the first (Campfire, the same clock)
##   smother_hiss a torch smothered under the hand (design 6 Oct §FC.3,
##                stealth.json douse.sound): a soft press, then a hiss
##                that darkens and dies as the air is cut off, a few
##                embers crushed in it (half a second)
##
##   owl          two or three soft low hoots, the last held (a ruin's window
##                at night, design 3 Oct §DI.3)
##   bats         a stream of bats leaving a vault: wing flutter and thin
##                high squeaks for a second or two (§DI.3)
##   scrabble     something small in the dark: claw ticks and a dry scuffle
##   drip         one drop into still water: a plink and its ring
##   lizard       a quick dry skitter over warm stone
##   stone_wind_loop  wind in the stones: a hollow moan with a breathy edge,
##                swelling and easing, 6 s loop (the ruin's bed, §DI.3)
##   drips_loop   slow drips in a wet hall, no rumble, 7 s loop
##   snake_hiss   the giant snake's strike tell (design §FA.2): a sharp,
##                dry breath of a hiss, up fast and held through the
##                wind-up (CreatureStrike stops it as the strike goes)
##   snake_warn   the giant snake holding off at your flame (§EY.2's torch
##                delay): a low, slow, rasping warning hiss, swelling and
##                easing, nothing like its strike's sharp one (§FA.2)
##
## Every one of them plays on a 3D player tuned by the falloff table,
## data/audio.json (Audio3D), except the hitmarker, a UI sound.

const RATE := 22050
const VARIANTS := 5

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
		"dire_howl":
			samples = _dire_howl(rng)
		"hare_scream":
			samples = _hare_scream(rng)
		"drone":
			samples = _drone(rng)
		"whisper":
			samples = _whisper(rng)
		"meteor":
			samples = _meteor(rng)
		"rustle":
			samples = _rustle(rng)
		"step_grass", "step_dirt", "step_sand", "step_stone", "step_snow", "step_wood", "step_water":
			samples = _step(kind.substr(5), rng)
		"rain_loop":
			samples = _rain_loop(rng)
		"thunder_near", "thunder_far":
			samples = _thunder(kind == "thunder_near", rng)
		"boom":
			samples = _boom(rng)
		"heartbeat":
			samples = _heartbeat(rng)
		"thud_breath":
			samples = _thud_breath(rng)
		"bow_draw":
			samples = _bow_draw(rng)
		"bow_release":
			samples = _bow_release(rng)
		"arrow_hit":
			samples = _arrow_hit(rng)
		"hurt":
			samples = _hurt(rng)
		"scuff":
			samples = _scuff(rng)
		"crack":
			samples = _crack(rng)
		"whip":
			samples = _whip(rng)
		"hitmarker":
			samples = _hitmarker(rng)
		"murmur", "murmur_one":
			samples = _murmur(rng, rng.randi_range(3, 4) if kind == "murmur" else 1)
		"wind_loop":
			samples = _wind_loop(rng)
		"crown_hush_loop", "crown_rustle_loop", "crown_clatter_loop", "crown_rattle_loop":
			samples = _crown_loop(rng, kind.trim_prefix("crown_").trim_suffix("_loop"))
		"scrape_loop", "cord_twist_loop", "needle_through_hide_loop", "tap_tap_loop", "grind_loop", "drill_whirr_loop":
			samples = _bench_loop(rng, kind.trim_suffix("_loop"))
		"insects_loop":
			samples = _insects_loop(rng)
		"frogs_loop":
			samples = _frogs_loop(rng)
		"birds_far_loop":
			samples = _birds_far_loop(rng)
		"water_loop":
			samples = _water_loop(rng, false)
		"waterfall_loop":
			samples = _water_loop(rng, true)
		"fire_hiss_loop":
			samples = _fire_hiss_loop(rng)
		"delve_loop":
			samples = _delve_loop(rng)
		"cicadas_loop":
			samples = _cicadas_loop(rng)
		"fire_snap":
			samples = _fire_snap(rng)
		"fire_crackle":
			samples = _fire_crackle(rng)
		"smother_hiss":
			samples = _smother_hiss(rng)
		"owl":
			samples = _owl(rng)
		"bats":
			samples = _bats(rng)
		"scrabble":
			samples = _scrabble(rng)
		"drip":
			samples = _drip(rng)
		"lizard":
			samples = _lizard(rng)
		"stone_wind_loop":
			samples = _stone_wind_loop(rng)
		"drips_loop":
			samples = _drips_loop(rng)
		"snake_hiss":
			samples = _snake_hiss(rng)
		"bone_grind":
			samples = _bone_grind(rng)
		"jaw_creak":
			samples = _jaw_creak(rng)
		"bone_step":
			samples = _bone_step(rng)
		"snake_warn":
			samples = _snake_warn(rng)
		_:
			return null
	var wav := _to_wav(samples)
	if kind.ends_with("_loop"):
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
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


## The dire wolf's voice (design 4 Oct §ED.5, rungs.json): a howl an
## octave down and twice as long, rough in the throat, the sag at its end
## breaking into a growl.
static func _dire_howl(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(5.0, 6.2))
	var lo := rng.randf_range(150.0, 185.0)
	var hi := lo * rng.randf_range(1.7, 1.95)
	var phase := 0.0
	var rough := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		var glide := smoothstep(0.0, 0.3, t) - 0.5 * smoothstep(0.65, 1.0, t)
		var f := lerpf(lo, hi, glide) * (1.0 + 0.02 * sin(TAU * 4.0 * t * s.size() / RATE))
		phase += TAU * f / RATE
		rough = lerpf(rough, rng.randf_range(-1, 1), 0.2)
		var growl := smoothstep(0.75, 1.0, t)
		s[i] = _env(i, s.size(), 0.5, 1.0) * (sin(phase) + 0.35 * sin(2.0 * phase) + 0.2 * sin(3.0 * phase) + (0.12 + 0.4 * growl) * rough)
	return s


## The jackalope's voice (§ED.5): a hare's scream, high and short, pitched
## stranger, with a chattering stutter.
static func _hare_scream(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(0.7, 1.0))
	var f0 := rng.randf_range(1500.0, 1900.0)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		var f := f0 * (1.0 - 0.25 * t) * (1.0 + 0.08 * sin(TAU * 31.0 * t))
		phase += TAU * f / RATE
		var stutter: float = 0.55 + 0.45 * signf(sin(TAU * 11.0 * t))
		s[i] = _env(i, s.size(), 0.02, 0.2) * stutter * (sin(phase) + 0.4 * sin(1.5 * phase) + 0.15 * rng.randf_range(-1, 1))
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


static func _meteor(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(5.0)
	var hiss_lp := 0.0
	var rumble_lp := 0.0
	var rumble_lp2 := 0.0
	var boom_at := rng.randf_range(2.6, 3.2)
	for i in s.size():
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		# Hiss: noise swelling as it passes, brightening then dulling.
		var cutoff := lerpf(0.08, 0.35, smoothstep(0.0, 1.4, t)) * (1.0 - smoothstep(1.6, 2.6, t) * 0.8)
		hiss_lp = lerpf(hiss_lp, x, cutoff)
		var hiss := hiss_lp * smoothstep(0.0, 0.9, t) * (1.0 - smoothstep(1.6, 2.6, t))
		# Rumble: very low filtered noise, a soft thump and a long tail.
		rumble_lp = lerpf(rumble_lp, x, 0.01)
		rumble_lp2 = lerpf(rumble_lp2, rumble_lp, 0.02)
		var rt := t - boom_at
		var rumble := 0.0
		if rt > 0.0:
			rumble = rumble_lp2 * 30.0 * minf(rt / 0.05, 1.0) * exp(-rt * 1.6)
		s[i] = hiss * 0.8 + rumble
	return s


static func _rustle(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(0.7, 1.1))
	var hp := 0.0
	var lp := 0.0
	var prev := 0.0
	# Leaf clicks: sparse crackle whose density swells and fades.
	for i in s.size():
		var t := float(i) / s.size()
		var swell := sin(PI * t) * (0.7 + 0.3 * sin(t * 23.0 + rng.randf()))
		var x := rng.randf_range(-1, 1)
		# High-passed noise (leafy hiss) ...
		hp = x - prev + 0.97 * hp
		prev = x
		lp = lerpf(lp, hp, 0.55)
		# ... with clicks.
		var click := (rng.randf_range(-1, 1) * 3.0) if rng.randf() < 0.004 * swell else 0.0
		s[i] = (lp * 0.6 + click) * swell
	return s


## One footstep on `ground`: a thump (the heel) plus the surface's own
## texture, each shaped by a few numbers.
## Dry wood snapping: a few sharp clicks splintering into a short burst,
## with a woody knock under it.
static func _crack(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.35)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var burst := rng.randf_range(-1, 1) * exp(-t * 18.0)
		var splinter := rng.randf_range(-1, 1) * 1.6 if rng.randf() < 0.03 * exp(-t * 6.0) else 0.0
		phase += TAU * 180.0 / RATE
		s[i] = burst * 0.8 + splinter + sin(phase) * exp(-t * 25.0) * 0.7
	return s


## A green stem springing back: a band of noise sweeping up fast.
static func _whip(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.28)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := clampf(t / 0.28, 0.0, 1.0)
		lp = lerpf(lp, rng.randf_range(-1, 1), lerpf(0.05, 0.7, k))
		s[i] = lp * sin(PI * k) * 1.2
	return s


## A sole dragged hard across a rough face: a gritty scrape that brightens
## and fades, with a knock where the foot bites.
static func _scuff(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.2 * rng.randf_range(0.85, 1.15))
	var lp := 0.0
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var bright := lerpf(0.25, 0.6, clampf(t / 0.08, 0.0, 1.0))
		lp = lerpf(lp, rng.randf_range(-1, 1), bright)
		var grit := rng.randf_range(-1, 1) * 1.2 if rng.randf() < 0.02 else 0.0
		var scrape := (lp + grit) * minf(t / 0.01, 1.0) * exp(-t * 14.0)
		phase += TAU * 120.0 / RATE
		s[i] = scrape + sin(phase) * exp(-t * 40.0) * 0.6
	return s


static func _step(ground: String, rng: RandomNumberGenerator) -> PackedFloat32Array:
	# [length s, thump Hz, thump level, noise level, noise brightness (0-1
	# one-pole cutoff), noise decay /s, click rate, resonance Hz]
	var p: Array = {
		"grass": [0.22, 70.0, 0.5, 0.7, 0.35, 16.0, 0.0, 0.0],
		"dirt": [0.16, 85.0, 1.0, 0.45, 0.22, 22.0, 0.002, 0.0],
		"sand": [0.24, 60.0, 0.35, 0.8, 0.12, 11.0, 0.0, 0.0],
		"stone": [0.12, 140.0, 0.6, 0.35, 0.8, 45.0, 0.0, 950.0],
		"snow": [0.24, 65.0, 0.4, 0.7, 0.3, 12.0, 0.03, 0.0],
		"wood": [0.16, 180.0, 0.9, 0.2, 0.4, 30.0, 0.0, 260.0],
		"water": [0.32, 55.0, 0.3, 0.9, 0.18, 8.0, 0.0, 0.0],
	}[ground]
	var length: float = p[0]
	var thump_hz: float = p[1]
	var thump_amp: float = p[2]
	var noise_amp: float = p[3]
	var bright: float = p[4]
	var decay: float = p[5]
	var clicks: float = p[6]
	var res_hz: float = p[7]
	var s := _buffer(length * rng.randf_range(0.9, 1.1))
	var lp := 0.0
	var phase := 0.0
	var res_phase := 0.0
	var bubble := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * thump_hz * (1.0 - t * 2.0) / RATE
		var thump := sin(phase) * exp(-t * 30.0) * thump_amp
		lp = lerpf(lp, rng.randf_range(-1, 1), bright)
		var attack := minf(t / 0.008, 1.0) if ground != "sand" and ground != "water" else minf(t / 0.03, 1.0)
		var tex := lp * exp(-t * decay) * attack * noise_amp
		if clicks > 0.0 and rng.randf() < clicks:
			tex += rng.randf_range(-1, 1) * 1.5 * exp(-t * 8.0)
		var knock := 0.0
		if res_hz > 0.0:
			res_phase += TAU * res_hz / RATE
			knock = sin(res_phase) * exp(-t * 55.0) * 0.8
		if ground == "water":
			# A bubbly chirp rising under the splash.
			bubble += TAU * (300.0 + 1400.0 * t) / RATE
			tex += sin(bubble) * 0.25 * exp(-t * 14.0)
		s[i] = thump + tex + knock
	return s


## Rain: a bed of soft filtered noise with pattering drops, cross-faded end
## to start so it loops without a seam.
static func _rain_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(4.0 * RATE)
	var fade := int(0.3 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp1 := 0.0
	var lp2 := 0.0
	var drop := 0.0
	for i in raw.size():
		var x := rng.randf_range(-1, 1)
		lp1 = lerpf(lp1, x, 0.35)
		lp2 = lerpf(lp2, x, 0.06)
		if rng.randf() < 0.012:
			drop = rng.randf_range(0.4, 1.0)
		drop *= 0.93
		raw[i] = lp1 * 0.5 + lp2 * 0.9 + drop * rng.randf_range(-1, 1) * 0.8
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		s[i] = lerpf(raw[n + i], raw[i], w)
	return s


## A seamless loop out of `raw` (n samples plus a `fade` tail that is
## crossfaded over the start).
static func _loopify(raw: PackedFloat32Array, n: int, fade: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		s[i] = lerpf(raw[n + i], raw[i], w)
	return s


# --- The bed (design 30 Sept §BG): loops with no position ------------------

## Wind: low, band-passed noise with slow gusts (6 s loop).
static func _wind_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(6.0 * RATE)
	var fade := int(0.6 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	var gust := 0.5
	var gust_t := 0.0
	var gp := rng.randf() * TAU
	for i in raw.size():
		var x := rng.randf_range(-1, 1)
		lp = lerpf(lp, x, 0.02)
		lp2 = lerpf(lp2, lp, 0.08)
		gust_t += 1.0 / RATE
		gust = 0.55 + 0.45 * sin(gp + gust_t * 0.9) * sin(gp * 0.7 + gust_t * 0.37)
		raw[i] = (lp - lp2) * 6.0 * (0.4 + gust) + lp2 * 0.8 * gust
	return _loopify(raw, n, fade)


## A crown in the gusts (design §DA, WindCrowns: a source at the tree):
## `voice` hush (needles: soft high hiss, no clicks), rustle (broad
## leaves: a leafy hiss with a scatter of clicks), clatter (palm fronds:
## dry knocks and slaps over a low hiss) or rattle (dry autumn leaves: a
## dense crackle). The gusts swell and ease through the 4 s loop.
static func _crown_loop(rng: RandomNumberGenerator, voice: String) -> PackedFloat32Array:
	var n := int(4.0 * RATE)
	var fade := int(0.4 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var hp := 0.0
	var prev := 0.0
	var lp := 0.0
	var knock := 0.0
	var gp := rng.randf() * TAU
	var hiss: float = {"hush": 0.9, "rustle": 0.6, "clatter": 0.25, "rattle": 0.35}.get(voice, 0.6)
	var clicks: float = {"hush": 0.0, "rustle": 0.004, "clatter": 0.0012, "rattle": 0.02}.get(voice, 0.004)
	var smooth: float = {"hush": 0.25, "rustle": 0.55, "clatter": 0.4, "rattle": 0.75}.get(voice, 0.55)
	for i in raw.size():
		var t := float(i) / RATE
		var swell := 0.45 + 0.55 * absf(sin(gp + t * 1.3) * sin(gp * 0.6 + t * 0.47))
		var x := rng.randf_range(-1, 1)
		hp = x - prev + 0.97 * hp
		prev = x
		lp = lerpf(lp, hp, smooth)
		var c := 0.0
		if rng.randf() < clicks * swell:
			c = rng.randf_range(-1, 1) * (3.0 if voice != "clatter" else 1.0)
			if voice == "clatter":
				knock = 1.0
		# A palm frond's knock: a short low thump that dies fast.
		knock *= 0.9985
		var k := sin(t * TAU * 180.0) * knock * 0.8 if voice == "clatter" else 0.0
		raw[i] = (lp * hiss + c + k) * swell
	return _loopify(raw, n, fade)


## A workshop bench at work (design 5 Oct §EL, Workshop; audio.json
## bench_kinds), a 3 s loop, quiet and close: `voice` scrape (long rasping
## strokes of a scraper over hide), cord_twist (a soft rub and creak as
## fibre rolls on a thigh), needle_through_hide (a small pop through the
## skin, then the thread drawn after it), tap_tap (the knapper's hammer:
## sharp ringing ticks, irregular), grind (a gritty push and pull of stone
## on stone) or drill_whirr (the bow drill's whirr, reversing each stroke).
static func _bench_loop(rng: RandomNumberGenerator, voice: String) -> PackedFloat32Array:
	var n := int(3.0 * RATE)
	var fade := int(0.3 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var hp := 0.0
	var prev := 0.0
	var lp := 0.0
	var ring := 0.0
	var ring_f := 2600.0
	var next_tap := 0.15
	for i in raw.size():
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		hp = x - prev + 0.95 * hp
		prev = x
		var v := 0.0
		match voice:
			"scrape":
				# Strokes at ~1.1 Hz: a rasp that swells and lifts off.
				var ph := fmod(t * 1.1, 1.0)
				var env := sin(clampf(ph / 0.7, 0.0, 1.0) * PI)
				lp = lerpf(lp, hp, 0.35)
				v = lp * env * (0.7 + 0.3 * sin(t * TAU * 37.0))
			"cord_twist":
				# A slow roll and pull: a soft rub, a creak at the turn.
				var ph := fmod(t * 0.7, 1.0)
				lp = lerpf(lp, x, 0.04)
				v = lp * 2.5 * (0.4 + 0.6 * sin(ph * PI)) + (sin(t * TAU * 140.0) * 0.25 * exp(-fmod(t * 0.7, 1.0) * 30.0))
			"needle_through_hide":
				# Every ~1.4 s a pop through the skin, then the thread drawn.
				var ph := fmod(t / 1.4, 1.0) * 1.4
				var pop := exp(-ph * 120.0) * rng.randf_range(-1, 1) * 1.5
				lp = lerpf(lp, hp, 0.5)
				var draw := lp * 0.5 * smoothstep(0.05, 0.15, ph) * (1.0 - smoothstep(0.5, 0.9, ph))
				v = pop + draw
			"tap_tap":
				# The hammerstone on the core: sharp ticks that ring a little.
				if t >= next_tap:
					ring = 1.0
					ring_f = rng.randf_range(1900.0, 3200.0)
					next_tap = t + rng.randf_range(0.35, 0.9)
				ring *= 0.9975
				v = sin(t * TAU * ring_f) * ring * 0.8 + hp * ring * 0.6
			"grind":
				# Stone on stone, pushed and pulled at ~0.8 Hz: gritty, low.
				var stroke := absf(sin(t * PI * 0.8))
				lp = lerpf(lp, x, 0.12)
				var grit := (1.0 if rng.randf() < 0.02 * stroke else 0.0) * rng.randf_range(-1, 1)
				v = (lp * 1.6 + grit) * stroke
			"drill_whirr":
				# The spindle spinning one way, then back: a whirr that
				# rises and falls twice a second.
				var sp := absf(sin(t * TAU * 1.0))
				lp = lerpf(lp, hp, 0.2)
				v = sin(t * TAU * (90.0 + 70.0 * sp)) * 0.4 * sp + lp * 0.5 * sp
		raw[i] = v
	return _loopify(raw, n, fade)


## Insects: a chorus of high, dry chirrs at a few rates (5 s loop).
static func _insects_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(5.0 * RATE)
	var fade := int(0.4 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var voices := []
	for v in 4:
		voices.append([rng.randf_range(2600.0, 5200.0), rng.randf_range(9.0, 26.0), rng.randf() * TAU, rng.randf_range(0.5, 1.0)])
	for i in raw.size():
		var t := float(i) / RATE
		var acc := 0.0
		for v in voices:
			var tr := 0.5 + 0.5 * sin(TAU * float(v[1]) * t + float(v[2]))
			tr = pow(tr, 6.0)
			acc += sin(TAU * float(v[0]) * t) * tr * float(v[3]) * (0.7 + 0.3 * sin(t * 0.8 + float(v[2])))
		raw[i] = acc * 0.25 + rng.randf_range(-1, 1) * 0.02
	return _loopify(raw, n, fade)


## Cicadas in the heat of the day (design 1 Oct §CH): a few singers, each
## a fast tymbal buzz (clicks a hundred-odd times a second on a high
## ringing band) that swells and falls over a few seconds, out of step
## with the others (8 s loop).
static func _cicadas_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(8.0 * RATE)
	var fade := int(0.6 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var singers := []
	for k in 4:
		singers.append([rng.randf_range(4200.0, 6800.0), rng.randf_range(110.0, 190.0), rng.randf_range(2.5, 5.0), rng.randf() * TAU, rng.randf_range(0.5, 1.0)])
	for i in raw.size():
		var t := float(i) / RATE
		var acc := 0.0
		for sg in singers:
			var swell := 0.5 + 0.5 * sin(TAU * t / float(sg[2]) + float(sg[3]))
			swell = pow(swell, 2.0)
			var click := pow(0.5 + 0.5 * sin(TAU * float(sg[1]) * t), 8.0)
			acc += sin(TAU * float(sg[0]) * t + 2.0 * sin(TAU * 37.0 * t)) * click * swell * float(sg[4])
		raw[i] = acc * 0.35 + rng.randf_range(-1, 1) * 0.015
	return _loopify(raw, n, fade)


## Down in a delve (design 1 Oct §CJ): the earth's own low rumble, a
## draught breathing in the passages, and water dripping somewhere off in
## the dark, now near, now far (9 s loop).
static func _delve_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(9.0 * RATE)
	var fade := int(0.6 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var drips := []
	for k in 7:
		drips.append([rng.randf_range(0.0, 9.0), rng.randf_range(1400.0, 2600.0), rng.randf_range(0.25, 1.0)])
	var lo := 0.0
	var lo2 := 0.0
	var air := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		# A rumble: brown noise filtered twice, very low.
		lo = lerpf(lo, rng.randf_range(-1, 1), 0.004)
		lo2 = lerpf(lo2, lo, 0.01)
		air = lerpf(air, rng.randf_range(-1, 1), 0.03)
		var breath := 0.5 + 0.5 * sin(TAU * t / 9.0 * 2.0 + 1.3)
		var acc := lo2 * 9.0 + air * 0.08 * breath
		for dp in drips:
			var dt := fposmod(t - float(dp[0]), 9.0)
			if dt < 0.25:
				var f := float(dp[1]) * (1.0 + 0.6 * exp(-dt * 40.0))
				acc += sin(TAU * f * dt) * exp(-dt * 26.0) * float(dp[2]) * 0.5
		raw[i] = acc
	return _loopify(raw, n, fade)


## Frogs: a slow chorus of croaks at two or three pitches (6 s loop).
static func _frogs_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(6.0 * RATE)
	var fade := int(0.5 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var croaks := []
	for c in 9:
		croaks.append([rng.randf_range(0.0, 6.0), rng.randf_range(90.0, 220.0), rng.randf_range(0.12, 0.3)])
	for i in raw.size():
		var t := float(i) / RATE
		var acc := 0.0
		for c in croaks:
			var dt := fposmod(t - float(c[0]), 6.0)
			if dt < float(c[2]):
				var e := sin(PI * dt / float(c[2]))
				acc += sin(TAU * float(c[1]) * dt) * (0.5 + 0.5 * sin(TAU * 28.0 * dt)) * e
		raw[i] = acc * 0.6
	return _loopify(raw, n, fade)


## Distant birds: sparse, soft two-note calls far off (8 s loop).
static func _birds_far_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(8.0 * RATE)
	var fade := int(0.5 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var calls := []
	for c in 6:
		calls.append([rng.randf_range(0.0, 8.0), rng.randf_range(1400.0, 3000.0), rng.randf_range(0.9, 1.25), rng.randf_range(0.18, 0.4)])
	var lp := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		var acc := 0.0
		for c in calls:
			var dt := fposmod(t - float(c[0]), 8.0)
			var len := float(c[3])
			if dt < len * 2.2:
				var k := 0 if dt < len else 1
				var d2 := dt - k * len * 1.2
				if d2 >= 0.0 and d2 < len:
					var f := float(c[1]) * (float(c[2]) if k == 1 else 1.0) * (1.0 + 0.15 * d2 / len)
					acc += sin(TAU * f * d2) * sin(PI * d2 / len)
		lp = lerpf(lp, acc, 0.5)
		raw[i] = lp * 0.5
	return _loopify(raw, n, fade)


# --- Sources ---------------------------------------------------------------

## Running water: brown noise with a bubbling top; a waterfall is
## heavier and steadier (4 s loop).
static func _water_loop(rng: RandomNumberGenerator, fall: bool) -> PackedFloat32Array:
	var n := int(4.0 * RATE)
	var fade := int(0.4 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	var bub := 0.0
	var bf := 600.0
	var bp := 0.0
	for i in raw.size():
		var x := rng.randf_range(-1, 1)
		lp = lerpf(lp, x, 0.12 if fall else 0.3)
		lp2 = lerpf(lp2, x, 0.03)
		if rng.randf() < (0.004 if fall else 0.01):
			bub = rng.randf_range(0.3, 1.0)
			bf = rng.randf_range(500.0, 1600.0)
		bub *= 0.985
		bp += TAU * bf / RATE
		raw[i] = lp2 * (1.4 if fall else 0.7) + lp * 0.5 + sin(bp) * bub * (0.15 if fall else 0.35)
	return _loopify(raw, n, fade)


## data/audio.json -> fire (the hiss cutoff; the campfire reads the rest).
static func _fire_data() -> Dictionary:
	return Tuning.section("audio", "fire")


## A fire's hiss bed: white noise through a one-pole low-pass (the cutoff
## is fire.hiss.cutoff_hz), breathing slowly by a few sines so it is not a
## flat tone, with a faint low rumble under it. No pops at all: those are
## fire_snap and fire_crackle, one-shots the campfire fires on its own
## clock (4 s loop).
static func _fire_hiss_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(4.0 * RATE)
	var fade := int(0.4 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var fire := _fire_data()
	var hiss_data: Dictionary = fire.get("hiss") if fire.get("hiss") is Dictionary else {}
	var cutoff: float = float(hiss_data.get("cutoff_hz", 2600.0))
	var k: float = 1.0 - exp(-TAU * cutoff / RATE)
	# Breathing: two slow sines whose periods divide the 4 s loop, so the
	# swell comes round with it.
	var r1: float = rng.randi_range(1, 2) * 0.25
	var r2: float = rng.randi_range(3, 5) * 0.25
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var hiss := 0.0
	var lp := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		hiss = lerpf(hiss, x, k)
		lp = lerpf(lp, x, 0.015)
		var breath := 1.0 + 0.15 * (0.6 * sin(TAU * r1 * t + p1) + 0.4 * sin(TAU * r2 * t + p2))
		raw[i] = hiss * 0.6 * breath + lp * 1.2
	return _loopify(raw, n, fade)


## A sharp snap: a burst of noise dying in a few milliseconds and a short
## ring at a pitch picked per variant, with an attack under a millisecond
## so it clicks (20-45 ms).
static func _fire_snap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(0.02, 0.045))
	var burst_tau := rng.randf_range(0.003, 0.008)
	var ring_hz := rng.randf_range(1500.0, 4000.0)
	var ring_tau := rng.randf_range(0.01, 0.025)
	var ring_amp := rng.randf_range(0.3, 0.6)
	for i in s.size():
		var t := float(i) / RATE
		var burst := rng.randf_range(-1, 1) * exp(-t / burst_tau)
		var ring := sin(TAU * ring_hz * t) * exp(-t / ring_tau) * ring_amp
		s[i] = (burst + ring) * _env(i, s.size(), 0.0006, 0.004)
	return s


## A softer crackle: two to five small pops at random spacing, each a
## short noise burst with its own decay, level and mild low-pass, with a
## soft low thump under the first (80-220 ms).
static func _fire_crackle(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := rng.randf_range(0.08, 0.22)
	var s := _buffer(length)
	var count := rng.randi_range(2, 5)
	# [start s, length s, level, low-pass coefficient, decay s, filter state]
	var pops := []
	var at := 0.003
	for p in count:
		var cutoff := rng.randf_range(3000.0, 6000.0)
		pops.append([at, rng.randf_range(0.005, 0.015), rng.randf_range(0.4, 1.0), 1.0 - exp(-TAU * cutoff / RATE), rng.randf_range(0.002, 0.005), 0.0])
		at += rng.randf_range(0.012, maxf(0.012, (length - 0.03) / count))
	var thump_hz := rng.randf_range(60.0, 120.0)
	for i in s.size():
		var t := float(i) / RATE
		var acc := 0.0
		for p in pops:
			var dt: float = t - float(p[0])
			if dt < 0.0 or dt > float(p[1]):
				continue
			var x := rng.randf_range(-1, 1) * exp(-dt / float(p[4])) * minf(dt / 0.001, 1.0)
			p[5] = lerpf(float(p[5]), x, float(p[3]))
			acc += float(p[5]) * float(p[2])
		var thump := sin(TAU * thump_hz * t) * exp(-t / 0.03) * 0.3
		s[i] = (acc + thump) * _env(i, s.size(), 0.001, 0.01)
	return s


## A torch smothered under the hand (design 6 Oct §FC.3): a soft low
## press as the hand closes on the head, then a hiss that starts bright
## and darkens as the air is cut off, dying within half a second, with a
## few crushed embers ticking in its first part (0.45-0.6 s).
static func _smother_hiss(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(0.45, 0.6))
	var press_hz := rng.randf_range(70.0, 110.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var u := float(i) / s.size()
		var x := rng.randf_range(-1, 1)
		# The air cut off: the hiss's one-pole closes from bright to dark.
		lp = lerpf(lp, x, lerpf(0.55, 0.04, sqrt(u)))
		lp2 = lerpf(lp2, lp, 0.35)
		var hiss := lp2 * minf(t / 0.012, 1.0) * exp(-t * 6.5)
		var press := sin(TAU * press_hz * t) * exp(-t / 0.05) * 0.45
		var tick := rng.randf_range(-1, 1) * 1.4 if t < 0.2 and rng.randf() < 0.004 else 0.0
		s[i] = (hiss * 1.6 + press + tick * exp(-t * 9.0)) * _env(i, s.size(), 0.002, 0.06)
	return s


## Thunder: near, a sharp crack then a heavy rolling rumble; far, only
## the long low roll.
static func _thunder(near: bool, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(4.0, 6.0))
	var lp := 0.0
	var lp2 := 0.0
	var hp_prev := 0.0
	var hp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		lp = lerpf(lp, x, 0.02 if near else 0.008)
		lp2 = lerpf(lp2, lp, 0.05)
		# Rolling: slow swells as echoes arrive.
		var roll := 0.6 + 0.4 * sin(t * 2.3 + sin(t * 0.9) * 2.0)
		var env := minf(t / (0.05 if near else 0.6), 1.0) * exp(-t * (0.55 if near else 0.45))
		var v := lp2 * 40.0 * roll * env
		if near and t < 0.25:
			hp = x - hp_prev + 0.9 * hp
			hp_prev = x
			v += hp * 1.6 * exp(-t * 14.0)
		s[i] = v
	return s


## The swell striking the back of a sea cave (design 3 Oct §DX, §BG): a
## deep hollow thump that rings in the rock, then the wash of the water
## running back out.
static func _boom(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(3.2, 4.2))
	var f0 := rng.randf_range(34.0, 46.0)
	var ph := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		ph += TAU * f0 * (1.0 - 0.18 * minf(t, 1.0)) / RATE
		var thump := sin(ph) * minf(t / 0.03, 1.0) * exp(-t * 2.2)
		# The rock's ring: a second, higher hollow tone, fading sooner.
		var ring := sin(ph * 2.7) * 0.25 * exp(-t * 4.0)
		var x := rng.randf_range(-1, 1)
		lp = lerpf(lp, x, 0.03)
		lp2 = lerpf(lp2, lp, 0.08)
		var wash := lp2 * 9.0 * smoothstep(0.3, 1.2, t) * exp(-maxf(t - 1.2, 0.0) * 1.3)
		s[i] = (thump + ring) * 0.9 + wash
	return s


## A hit landing (design 4 Oct §EC): a dull body thud, then a sharp
## breath knocked out.
static func _thud_breath(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.55)
	var f0 := rng.randf_range(70.0, 90.0)
	var lp := 0.0
	var hp_prev := 0.0
	var hp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var thud := sin(TAU * f0 * t * (1.0 - 0.4 * minf(t * 8.0, 1.0))) * minf(t / 0.004, 1.0) * exp(-t * 22.0)
		var x := rng.randf_range(-1, 1)
		lp = lerpf(lp, x, 0.35)
		hp = lp - hp_prev + 0.6 * hp
		hp_prev = lp
		var bt := t - 0.07
		var breath := hp * 0.35 * (smoothstep(0.0, 0.03, bt) * exp(-maxf(bt, 0.0) * 9.0) if bt > 0.0 else 0.0)
		s[i] = thud * 0.9 + breath
	return s


## One heartbeat heard from inside (design 4 Oct §EA): lub-dub, two low
## soft thuds a fifth of a second apart, the second fainter.
static func _heartbeat(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.42)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for b: Array in [[0.0, 52.0, 1.0], [0.19, 46.0, 0.7]]:
			var tt := t - float(b[0])
			if tt >= 0.0:
				v += sin(TAU * float(b[1]) * tt) * float(b[2]) * minf(tt / 0.008, 1.0) * exp(-tt * 28.0)
		s[i] = v * 0.95
	return s


## Creaking wood: slow irregular clicks under a low tension hum.
static func _bow_draw(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.7)
	var ph := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.55, 0.7, t))
		ph += TAU * (70.0 + 40.0 * t) / RATE
		var click := rng.randf_range(-1, 1) * 2.0 if rng.randf() < 0.002 else 0.0
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.08)
		s[i] = (sin(ph) * 0.25 + lp * 0.6 + click) * env * 0.5
	return s


## A plucked string (decaying harmonics) and a short airy whoosh.
static func _bow_release(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.45)
	var f := rng.randf_range(150.0, 185.0)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var twang := 0.0
		for h in 4:
			twang += sin(TAU * f * (h + 1) * t) * exp(-t * (14.0 + h * 9.0)) / (h + 1)
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.3)
		var whoosh := lp * exp(-pow((t - 0.08) / 0.05, 2.0)) * 0.8
		s[i] = twang * 0.8 + whoosh
	return s


## A thunk: a low knock that dies fast, with a little splinter noise.
static func _arrow_hit(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.22)
	var f := rng.randf_range(120.0, 170.0)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = sin(TAU * f * t) * exp(-t * 30.0) + rng.randf_range(-1, 1) * exp(-t * 60.0) * 0.4
	return s


## Camp talk heard from a little way off: `voices` voices (three or four
## round a camp fire), each a few phrases of syllables (a buzzy voiced tone whose pitch rises and
## falls over the phrase, through two vowel resonances that glide from
## syllable to syllable), overlapping, then low-passed so that no word
## comes through.
static func _murmur(rng: RandomNumberGenerator, voices: int) -> PackedFloat32Array:
	var s := _buffer(4.0)
	var n := s.size()
	var r := 0.97
	for v in voices:
		var f0 := rng.randf_range(95.0, 230.0)
		var gain := rng.randf_range(0.5, 1.0)
		var i := int(rng.randf_range(0.0, 0.9) * RATE)
		var phase := 0.0
		# Resonator coefficients (2r cos w), gliding toward each
		# syllable's vowel, and their states.
		var c1 := 2.0 * r * cos(TAU * 500.0 / RATE)
		var c2 := 2.0 * r * cos(TAU * 1500.0 / RATE)
		var a1 := 0.0
		var a2 := 0.0
		var b1 := 0.0
		var b2 := 0.0
		while i < n:
			var syllables := rng.randi_range(3, 7)
			for k in syllables:
				var length := int(rng.randf_range(0.11, 0.24) * RATE)
				var t1 := 2.0 * r * cos(TAU * rng.randf_range(300.0, 800.0) / RATE)
				var t2 := 2.0 * r * cos(TAU * rng.randf_range(900.0, 2300.0) / RATE)
				var accent := rng.randf_range(0.6, 1.0)
				for j in length:
					if i >= n:
						break
					var x := float(j) / length
					var through := (float(k) + x) / syllables
					phase = fposmod(phase + f0 * (1.0 + 0.15 * sin(PI * through) - 0.1 * through) / RATE, 1.0)
					var src := phase * 2.0 - 1.0 + rng.randf_range(-0.15, 0.15)
					c1 = lerpf(c1, t1, 0.003)
					c2 = lerpf(c2, t2, 0.003)
					var y1 := src + c1 * a1 - r * r * a2
					a2 = a1
					a1 = y1
					var y2 := src + c2 * b1 - r * r * b2
					b2 = b1
					b1 = y2
					s[i] += (y1 + 0.6 * y2) * gain * accent * sqrt(sin(PI * x))
					i += 1
			# A breath between phrases.
			i += int(rng.randf_range(0.25, 0.8) * RATE)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		lp = lerpf(lp, s[i], 0.35)
		lp2 = lerpf(lp2, lp, 0.45)
		s[i] = lp2 * _env(i, n, 0.3, 0.6)
	return s


## The player hit: a blunt body thump and a short gasp.
static func _hurt(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.4)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var thump := sin(TAU * (90.0 - 60.0 * t) * t) * exp(-t * 18.0)
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.25)
		var gasp := lp * smoothstep(0.03, 0.08, t) * exp(-t * 9.0) * 0.7
		s[i] = thump + gasp
	return s


## The hit marker (StatusHud's X on a critical or a kill): a short, sharp
## tick, a bright ping over a click that's gone in a few hundredths of a
## second.
static func _hitmarker(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.07)
	var f := rng.randf_range(2300.0, 2500.0)
	for i in s.size():
		var t := float(i) / RATE
		var ping := sin(TAU * f * t) * exp(-t * 70.0) + sin(TAU * f * 1.5 * t) * exp(-t * 110.0) * 0.4
		var click := rng.randf_range(-1, 1) * exp(-t * 400.0) * 0.6
		s[i] = ping + click
	return s


## An owl: two or three soft hoots, low and round (a sine with a little
## breath), the last one held longer.
static func _owl(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(2.2)
	var f := rng.randf_range(330.0, 420.0)
	var hoots := rng.randi_range(2, 3)
	var start := int(0.05 * RATE)
	var phase := 0.0
	for k in hoots:
		var last := k == hoots - 1
		var n := int((rng.randf_range(0.5, 0.75) if last else rng.randf_range(0.18, 0.28)) * RATE)
		var fk := f * (0.94 if last else 1.0)
		for i in n:
			if start + i >= s.size():
				break
			var t := float(i) / n
			phase += TAU * fk * (1.0 + 0.04 * sin(PI * t)) / RATE
			var e := sin(PI * minf(t * 3.0, 1.0) * 0.5) * (1.0 - smoothstep(0.6, 1.0, t))
			s[start + i] += e * (sin(phase) + 0.15 * sin(2.0 * phase) + 0.06 * rng.randf_range(-1, 1))
		start += n + int(rng.randf_range(0.12, 0.2) * RATE)
	return s


## Bats leaving a vault: a fast flutter (amplitude-modulated low noise)
## swelling and fading, with a scatter of thin high squeaks.
static func _bats(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(1.4, 2.0))
	var lp := 0.0
	var flap := rng.randf_range(14.0, 20.0)
	for i in s.size():
		var t := float(i) / RATE
		var u := float(i) / s.size()
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.25)
		var wing := 0.5 + 0.5 * sin(TAU * flap * t + 2.0 * sin(TAU * 3.1 * t))
		s[i] = lp * wing * sin(PI * u) * 0.8
	for k in rng.randi_range(6, 12):
		var at := int(rng.randf_range(0.05, 0.9) * s.size())
		var n := int(rng.randf_range(0.015, 0.035) * RATE)
		var f0 := rng.randf_range(6500.0, 9000.0)
		var phase := 0.0
		for i in n:
			if at + i >= s.size():
				break
			var t := float(i) / n
			phase += TAU * f0 * (1.0 - 0.3 * t) / RATE
			s[at + i] += sin(phase) * sin(PI * t) * 0.5
	return s


## Something small in the dark: sharp claw ticks in quick runs over a
## faint dry scuffle.
static func _scrabble(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(0.6, 1.0))
	var hp := 0.0
	var prev := 0.0
	var runs := rng.randi_range(2, 3)
	for r in runs:
		var at := rng.randf_range(0.0, 0.6)
		var ticks := rng.randi_range(4, 9)
		for k in ticks:
			var i0 := int((at + k * rng.randf_range(0.03, 0.06)) * RATE)
			var n := int(0.006 * RATE)
			for i in n:
				if i0 + i < s.size():
					s[i0 + i] += rng.randf_range(-1, 1) * (1.0 - float(i) / n)
	for i in s.size():
		var x := rng.randf_range(-1, 1)
		hp = x - prev + 0.9 * hp
		prev = x
		s[i] += hp * 0.08 * sin(PI * float(i) / s.size())
	return s


## One drop into still water: a falling plink and a short ring.
static func _drip(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.5)
	var f := rng.randf_range(1300.0, 2400.0)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * f * (1.0 + 0.7 * exp(-t * 45.0)) / RATE
		s[i] = sin(phase) * exp(-t * 18.0) + (rng.randf_range(-1, 1) * exp(-t * 300.0) * 0.3)
	return s


## A lizard: a quick dry skitter (a short burst of crackle).
static func _lizard(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(0.25, 0.4))
	var hp := 0.0
	var prev := 0.0
	for i in s.size():
		var u := float(i) / s.size()
		var x := rng.randf_range(-1, 1)
		hp = x - prev + 0.95 * hp
		prev = x
		var click := rng.randf_range(-1, 1) * 2.5 if rng.randf() < 0.02 else 0.0
		s[i] = (hp * 0.5 + click) * sin(PI * u)
	return s


## Wind in the stones: noise through two narrow resonances (the gap's
## hollow note and its fifth), a breathy edge, swelling and easing.
static func _stone_wind_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(6.0 * RATE)
	var fade := int(0.6 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var f1 := rng.randf_range(150.0, 210.0)
	var f2 := f1 * 1.5
	# Two resonators (2-pole band-pass).
	var r := 0.996
	var c1 := 2.0 * r * cos(TAU * f1 / RATE)
	var c2 := 2.0 * r * cos(TAU * f2 / RATE)
	var y1a := 0.0
	var y1b := 0.0
	var y2a := 0.0
	var y2b := 0.0
	var air := 0.0
	var gp := rng.randf() * TAU
	for i in raw.size():
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		var swell := 0.45 + 0.55 * pow(maxf(0.0, sin(gp + TAU * t / 6.0)), 1.5)
		var y1 := c1 * y1a - r * r * y1b + x * 0.02
		y1b = y1a
		y1a = y1
		var y2 := c2 * y2a - r * r * y2b + x * 0.012
		y2b = y2a
		y2a = y2
		air = lerpf(air, x, 0.05)
		raw[i] = (y1 + 0.6 * y2) * swell + air * 0.25 * swell
	return _loopify(raw, n, fade)


## Slow drips in a wet hall: drops at three or four pitches, nothing else.
static func _drips_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(7.0 * RATE)
	var fade := int(0.4 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var drops := []
	for k in 9:
		drops.append([rng.randf_range(0.0, 7.0), rng.randf_range(1200.0, 2600.0), rng.randf_range(0.3, 1.0)])
	for i in raw.size():
		var t := float(i) / RATE
		var acc := 0.0
		for dp in drops:
			var dt := fposmod(t - float(dp[0]), 7.0)
			if dt < 0.3:
				var f := float(dp[1]) * (1.0 + 0.7 * exp(-dt * 45.0))
				acc += sin(TAU * f * dt) * exp(-dt * 18.0) * float(dp[2])
		raw[i] = acc
	return _loopify(raw, n, fade)


## The giant snake drawing back to strike (design 6 Oct §FA.2): a breath
## of a hiss, dry and bright (noise high-passed near 2 kHz with the very
## top softened), up in a few hundredths of a second with a little puff at
## its start, wavering as the breath is forced out, held long enough for
## any wind-up the data asks (CreatureStrike cuts it as the strike goes),
## then let go.
static func _snake_hiss(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(1.4, 1.6))
	var hp_k := 1.0 - TAU * rng.randf_range(1800.0, 2400.0) / RATE
	var lp_k := 1.0 - exp(-TAU * rng.randf_range(6000.0, 7500.0) / RATE)
	var wob_hz := rng.randf_range(5.0, 8.0)
	var ph := rng.randf() * TAU
	var hp := 0.0
	var prev := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		hp = x - prev + hp_k * hp
		prev = x
		lp = lerpf(lp, hp, lp_k)
		var puff := 1.0 + 0.6 * exp(-t / 0.05)
		var breath := 1.0 + 0.15 * sin(TAU * wob_hz * t + ph)
		s[i] = lp * puff * breath * _env(i, s.size(), 0.03, 0.3)
	return s


## Bone grinding on stone as a skeleton climbs out of its niche or its
## grave (design §FE.2's near tell): a low gritty drag that swells and lets
## off two or three times, a groan in it, dry knocks of bone on stone.
static func _bone_grind(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(1.2, 1.5))
	var n := s.size()
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	var drags := rng.randf_range(2.0, 3.0)
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.08)
		lp2 = lerpf(lp2, lp, 0.3)
		var drag := absf(sin(k * PI * drags + 0.4)) * sin(k * PI)
		var grit := (rng.randf_range(-1, 1) if rng.randf() < 0.03 * drag else 0.0) * 0.8
		phase += TAU * (55.0 + 25.0 * sin(t * 7.0)) / RATE
		s[i] = (lp2 * 2.2 + grit) * drag + sin(phase) * 0.25 * drag
	for kn in rng.randi_range(5, 8):
		var i0 := int(rng.randf_range(0.05, 0.95) * n)
		var f := rng.randf_range(300.0, 700.0)
		for j in int(0.04 * RATE):
			if i0 + j < n:
				var tt := float(j) / RATE
				s[i0 + j] += sin(TAU * f * tt) * exp(-tt * 90.0) * 0.9 + rng.randf_range(-1, 1) * exp(-tt * 250.0) * 0.5
	return s


## The jaw dropping open (design §FE.2's wind-up tell, §FA.2): a dry creak
## of the hinge sliding down in pitch, then a hollow knock as it falls
## open.
static func _jaw_creak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.5)
	var n := s.size()
	var phase := 0.0
	var lp := 0.0
	var clack := int(rng.randf_range(0.3, 0.34) * RATE)
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(420.0, 260.0, clampf(t / 0.32, 0.0, 1.0))
		phase += TAU * f / RATE
		var slip := 1.0 if fmod(t * 38.0, 1.0) < 0.35 else 0.3
		var creak := (sin(phase) + 0.5 * sin(phase * 2.03)) * slip * (1.0 - smoothstep(0.26, 0.34, t)) * smoothstep(0.0, 0.03, t)
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.5)
		var v := creak * 0.6 + lp * 0.1 * creak
		if i >= clack:
			var tt := float(i - clack) / RATE
			v += sin(TAU * 230.0 * tt) * exp(-tt * 60.0) * 0.9 + rng.randf_range(-1, 1) * exp(-tt * 300.0) * 0.6
		s[i] = v
	return s


## A bare bone foot on stone: a dry, light knock with a rattle in it.
static func _bone_step(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(0.16)
	var f := rng.randf_range(500.0, 800.0)
	for i in s.size():
		var t := float(i) / RATE
		var rattle := rng.randf_range(-1, 1) * (exp(-t * 60.0) * 0.4 + (0.3 if rng.randf() < 0.02 else 0.0) * exp(-t * 20.0))
		s[i] = sin(TAU * f * t) * exp(-t * 70.0) * 0.7 + rattle
	return s


## The giant snake holding off at the edge of your light (design 6 Oct
## §EY.2's torch delay): a warning, not a strike, so nothing like its
## strike's hiss (§FA.2: that one must always mean the strike). Dark (noise
## high-passed near 450 Hz and low-passed twice near 2 kHz, so its top
## falls away steeply), slow to swell and slow to ease, rasping (a fast
## flutter on the breath) and wavering slowly as the breath is let out.
static func _snake_warn(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var s := _buffer(rng.randf_range(1.3, 1.7))
	var hp_k := 1.0 - TAU * rng.randf_range(380.0, 520.0) / RATE
	var lp_k := 1.0 - exp(-TAU * rng.randf_range(1800.0, 2300.0) / RATE)
	var rasp_hz := rng.randf_range(26.0, 34.0)
	var wob_hz := rng.randf_range(2.0, 3.0)
	var ph := rng.randf() * TAU
	var hp := 0.0
	var prev := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var x := rng.randf_range(-1, 1)
		hp = x - prev + hp_k * hp
		prev = x
		lp = lerpf(lp, hp, lp_k)
		lp2 = lerpf(lp2, lp, lp_k)
		var rasp := 1.0 + 0.35 * sin(TAU * rasp_hz * t)
		var breath := 1.0 + 0.25 * sin(TAU * wob_hz * t + ph)
		s[i] = lp2 * rasp * breath * _env(i, s.size(), 0.3, 0.6)
	return s
