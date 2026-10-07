class_name PotFire
extends Node3D
## A fire a pot makes (design 6 Oct night §FA.3; data/fire_pots.json),
## one of four kinds:
##   flash   the burst: a fireball (one flame card swelling and collapsing),
##           a spike of light and a throw of sparks; big for light oil, small
##           for tar (look.flash_*), and the clay breaking with a whoomp
##   patch   tar on the floor (oils.tar floor_patch_s, patch_radius_m): a few
##           flames across the patch that burn on, then gutter and go out (a
##           light that goes out), leaving a char mark on the stone; it burns
##           what stands in it (burn_dps) and catches what spreads
##   stuck   tar stuck to a creature, burning on it for burn_s at burn_dps
##   spread  a thing that burns (spreads_to: a web, dry wood, rushes, cloth)
##           alight for spread.burn_s, then charred
## Every one lights in the hearth's amber (§EX.6, Torch.fire_color),
## reddening as it dies (Torch.gutter_color), glows (the flame card's bands,
## §BZ) and smokes by its size (Smoke.tick_flame, §CV). None is a fire a
## torch catches from or a holder is lit by (relights_holders null): they
## are not campfires (Campfire.GROUP), so FireStore, the torch's swing and
## Torch.flame_near never see them.

var kind := "flash"
var oil := "tar"
var pots: FirePots
## How long it burns (s), and how long it has.
var life_s := 1.0
var t := 0.0
## Its reach on the floor (patch, spread) (m).
var radius := 0.0
## Fire damage a second to what stands in it or what it is stuck to
## (residents.json fire_hp units, before the creature's oil_scale).
var dps := 0.0
## stuck: what it burns on. spread: the thing alight (FirePots.burnables).
var target: Node3D = null
var burnable: Dictionary = {}
## The flames' size against a campfire's (the smoke's and the light's
## scale).
var size := 1.0
## Where it stands (scene): the floor under a patch, the burst's point.
var foot := Vector3.ZERO
## Burnt out (its light gone, freed this frame).
var done := false

var _flames: Array[Node3D] = []
var _light: OmniLight3D
var _energy := 1.0
var _range := 4.0
var _seed := 0.0
var _hiss: AudioStreamPlayer3D
var _pops: AudioStreamPlayer3D
var _pop_at := 0.0

static var _sounds := {}


static func _look() -> Dictionary:
	return FirePots.D.get("look", {})


static func _per_oil(key: String, which: String, fallback: float) -> float:
	var v: Variant = _look().get(key, {})
	if v is Dictionary:
		return float((v as Dictionary).get(which, fallback))
	return float(v) if v != null else fallback


## The burst at `at` (scene): the fireball, the light's spike, the sparks,
## and (`sound`) the clay breaking with its whoomp.
static func flash(p_pots: FirePots, at: Vector3, p_oil: String, scale := 1.0, sound := true) -> PotFire:
	var f := PotFire.new()
	f.kind = "flash"
	f.oil = p_oil
	f.pots = p_pots
	f.foot = at
	f.life_s = _per_oil("flash_s", p_oil, 0.5) * clampf(scale, 0.4, 1.0)
	f.size = _per_oil("flash_flame_scale", p_oil, 1.0) * scale
	f._energy = _per_oil("flash_energy", p_oil, 6.0) * scale
	f._range = maxf(float((FirePots.oil(p_oil)).get("splash_m", 1.5)) * 3.0, 4.0) * maxf(scale, 0.5)
	p_pots.add_child(f)
	f.global_position = at
	f._build(1, 0.0, 3)
	f._light_on(true)
	if sound:
		var v := Audio3D.make("fire", f, "Burst")
		v.stream = burst_stream(p_oil, randi())
		v.volume_db = 0.0 if p_oil == "light_oil" else -3.0
		v.pitch_scale = randf_range(0.92, 1.08) / clampf(scale, 0.6, 1.0)
		Audio3D.play(v)
	return f


## Tar on the floor at `at` (the floor's point, scene).
static func patch(p_pots: FirePots, at: Vector3, p_oil: String) -> PotFire:
	var o := FirePots.oil(p_oil)
	var f := PotFire.new()
	f.kind = "patch"
	f.oil = p_oil
	f.pots = p_pots
	f.foot = at
	f.radius = float(o.get("patch_radius_m", 1.2))
	f.life_s = float(o.get("floor_patch_s", 12.0))
	f.dps = float(o.get("burn_dps", 0.5))
	f.size = float(_look().get("patch_flame_scale", 0.5))
	f._energy = float(_look().get("patch_energy", 2.4))
	f._range = float(_look().get("patch_range_m", 6.0))
	p_pots.add_child(f)
	f.global_position = at
	f._build(int(_look().get("patch_flames", 4)), f.radius * 0.6, 2)
	f._light_on(true)
	f._voice()
	return f


## Tar stuck to `on` (a fire target), burning on it.
static func stuck(p_pots: FirePots, on: Node3D, p_oil: String) -> PotFire:
	var o := FirePots.oil(p_oil)
	var f := PotFire.new()
	f.kind = "stuck"
	f.oil = p_oil
	f.pots = p_pots
	f.target = on
	f.life_s = float(o.get("burn_s", 8.0))
	f.dps = float(o.get("burn_dps", 0.5))
	f.size = float(_look().get("stuck_flame_scale", 0.45))
	f._energy = float(_look().get("stuck_energy", 1.6))
	f._range = float(_look().get("stuck_range_m", 5.0))
	on.add_child(f)
	f.global_position = FirePots.center_of(on) - Vector3.UP * 0.35
	f._build(2, FirePots.radius_of(on) * 0.6, 1)
	f._light_on(false)
	f._voice()
	return f


## A thing that burns (FirePots.burnables entry `b`) alight.
static func spread(p_pots: FirePots, b: Dictionary) -> PotFire:
	var S: Dictionary = FirePots.D.get("spread", {})
	var tag := str(b.get("tag", "dry_wood"))
	var f := PotFire.new()
	f.kind = "spread"
	f.oil = "spread"
	f.pots = p_pots
	f.burnable = b
	f.foot = b.pos
	f.radius = float(b.get("radius", 0.5))
	f.life_s = float((S.get("burn_s", {}) as Dictionary).get(tag, 12.0))
	f.dps = float(S.get("burn_dps", 0.5))
	f.size = clampf(f.radius * 0.6, 0.3, 0.8)
	f._energy = float(_look().get("patch_energy", 2.4)) * clampf(f.radius, 0.5, 1.2)
	f._range = float(_look().get("patch_range_m", 6.0))
	p_pots.add_child(f)
	f.global_position = f.foot
	f._build(clampi(int(round(f.radius * 3.0)), 2, 5), f.radius * 0.7, 2)
	f._light_on(true)
	f._voice()
	return f


## `n` flame cards at `size`, scattered within `spread_m` of the middle
## (the first in the middle), `embers` sparks each.
func _build(n: int, spread_m: float, embers: int) -> void:
	_seed = randf() * 100.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seed * 1000.0)
	for i in n:
		var s := size * (1.0 if i == 0 else rng.randf_range(0.6, 0.9))
		var fl := Campfire.flame_node(s, 1.0, embers, _seed + i * 7.3)
		fl.name = "Flame%d" % i
		var off := Vector2.ZERO
		if i > 0:
			off = Vector2.RIGHT.rotated(TAU * i / maxf(n - 1, 1) + rng.randf_range(-0.4, 0.4)) * spread_m * rng.randf_range(0.55, 1.0)
		fl.position = Vector3(off.x, 0.0, off.y)
		fl.set_meta("flame_size", s)
		fl.set_meta("height", s)
		add_child(fl)
		_flames.append(fl)
	if kind != "stuck":
		# Sparks and ash off the fire (Campfire's specks, §CZ), on the
		# pots' clock.
		add_child(Campfire.speck_node(_seed))
	if kind == "flash":
		# The fireball stands on the burst, not on the floor, and throws
		# its sparks at once.
		_flames[0].position = Vector3(0.0, -size * float(Campfire.FL.get("height_m", 1.0)) * 0.35, 0.0)
		Campfire.throw(self, pots.clock, Campfire.burst_size(true) * (2 if oil == "light_oil" else 1))


func _light_on(shadows: bool) -> void:
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = Torch.fire_color()
	_light.light_energy = _energy
	_light.omni_range = _range
	_light.omni_attenuation = Campfire.ATTENUATION
	_light.position = Vector3(0.0, 0.5 if kind != "flash" else 0.0, 0.0)
	add_child(_light)
	# A real fire in the room: it may cast when it's among the nearest
	# (FireShadows, §ER.1).
	if shadows:
		FireShadows.enlist(_light)
	else:
		_light.shadow_enabled = false


## The hiss bed and the pops (Campfire's voice, smaller).
func _voice() -> void:
	_hiss = Audio3D.make("fire", self, "Hiss")
	_hiss.stream = SoundSynth.stream("fire_hiss_loop", randi() % SoundSynth.VARIANTS)
	_hiss.volume_db = float((Campfire.A.get("hiss", {}) as Dictionary).get("volume_db", -14.0)) - (2.0 if kind == "patch" else 6.0)
	_hiss.position = Vector3(0.0, 0.3, 0.0)
	_pops = Audio3D.make("fire", self, "Pops")
	_pops.position = Vector3(0.0, 0.3, 0.0)
	_pop_at = randf_range(0.2, 0.9)


func _ready() -> void:
	if _hiss != null:
		Audio3D.play(_hiss, randf() * 2.0)


## 0 burning steady .. 1 out: how far it has guttered (the last
## look.gutter_share of its life; a flash collapses all the way).
func gutter() -> float:
	if kind == "flash":
		return clampf(t / maxf(life_s, 0.01), 0.0, 1.0)
	var share := clampf(float(_look().get("gutter_share", 0.3)), 0.01, 1.0)
	return clampf((t - life_s * (1.0 - share)) / (life_s * share), 0.0, 1.0)


## Is it burning (its light on)?
func burning() -> bool:
	return not done and t < life_s


## Its light now (checks): energy, colour.
func light() -> OmniLight3D:
	return _light


func _physics_process(delta: float) -> void:
	if done:
		return
	t += delta
	if kind == "stuck":
		if target == null or not is_instance_valid(target) or target.get_meta("burnt_out", false):
			_end()
			return
		pots.burn(target, dps * delta, oil, FirePots.center_of(target))
	elif kind == "patch" or kind == "spread":
		pots.burn_what_stands_in(foot, radius, dps * delta, oil, self)
		pots.ignite_near(foot, radius)
	if t >= life_s:
		_end()


func _process(_delta: float) -> void:
	if done:
		return
	var g := gutter()
	var now := pots.clock if pots != null else t
	# The light: the fire's noise flicker (Campfire.flicker's two layers),
	# dimming and reddening as it gutters (§EX.6: redder, never cooler).
	var fk: Dictionary = Campfire.L.get("flicker", {})
	var hz := float(fk.get("hz", 9.0))
	var amount := float(fk.get("amount", 0.18))
	var k := 1.0 + amount * (0.7 * (Campfire._vnoise(now * hz, _seed) * 2.0 - 1.0) + 0.3 * (Campfire._vnoise(now * hz * 2.7, _seed + 11.0) * 2.0 - 1.0))
	if _light != null:
		var fall := (1.0 - g) * (1.0 - g) if kind == "flash" else 1.0 - g
		_light.light_energy = _energy * k * fall
		_light.light_color = Torch.gutter_color(g)
	# The flames: a flash swells fast and collapses; the rest burn on and
	# sink toward the low bands as they gutter (fire.flame.low).
	var low: Dictionary = Campfire.FL.get("low", {})
	for fl in _flames:
		var hs := 1.0
		if kind == "flash":
			hs = smoothstep(0.0, 0.18, g) * (1.0 - smoothstep(0.45, 1.0, g)) * 1.2 + 0.05
			fl.scale = Vector3(hs, hs, hs)
		else:
			hs = lerpf(1.0, float(low.get("height_scale", 0.45)), g)
			fl.scale = Vector3(1.0, hs, 1.0)
		var card := fl.get_node_or_null("Card") as MeshInstance3D
		if card != null and card.material_override is ShaderMaterial:
			(card.material_override as ShaderMaterial).set_shader_parameter("low", g * (0.4 if kind == "flash" else 1.0))
	var sp := get_node_or_null("Specks") as MultiMeshInstance3D
	if sp != null:
		(sp.material_override as ShaderMaterial).set_shader_parameter("now", now)
	# Its smoke, by its size (§CV): a patch's foot on the floor; on a
	# creature, at its middle. (A flash is over before a column could
	# rise.)
	if kind != "flash" and not _flames.is_empty():
		var smoke_foot := foot if kind != "stuck" else global_position
		Smoke.tick_flame(self, smoke_foot + Vector3.UP * size * 0.4, Vector3.UP, size * (1.0 - 0.6 * g), "flames" if g < 0.7 else "low")
	_pop(now, g)


func _pop(now: float, g: float) -> void:
	if _pops == null or g > 0.85:
		return
	_pop_at -= get_process_delta_time()
	if _pop_at > 0.0:
		return
	var P: Dictionary = Campfire.A.get("pops", {})
	_pops.stream = SoundSynth.stream("fire_snap" if randf() < 0.35 else "fire_crackle", randi() % SoundSynth.VARIANTS)
	_pops.pitch_scale = randf_range(0.9, 1.5)
	var vr: Array = P.get("volume_db", [-10.0, -3.0])
	_pops.volume_db = randf_range(float(vr[0]), float(vr[1])) - 4.0
	Audio3D.play(_pops)
	_pop_at = randf_range(0.25, 1.6) * (1.0 + 2.0 * g)
	if kind != "stuck":
		var sp := get_node_or_null("Specks")
		if sp != null:
			Campfire.throw(self, now, Campfire.burst_size())


## Out: the light goes, the smoke thins away, a patch leaves its char.
func _end() -> void:
	if done:
		return
	done = true
	if _light != null:
		_light.visible = false
		_light.light_energy = 0.0
	if kind == "patch" or kind == "spread":
		var r := radius if kind == "patch" else maxf(radius, 0.3)
		pots.char_mark(foot, r, burnable)
	if kind == "spread" and not burnable.is_empty():
		burnable["state"] = "burnt"
	pots.fire_ended(self)
	queue_free()


## The pot's burst (design §FA.3): the clay cracking, the oil catching at
## once in a low whoomp, a roar of flame dying away; light oil the bigger
## and longer. Synthesised like the rest of the game's placeholder sounds
## (SoundSynth), a few seeded variants each.
static func burst_stream(p_oil: String, variant: int) -> AudioStreamWAV:
	var key := "%s_%d" % [p_oil, posmod(variant, 3)]
	if _sounds.has(key):
		return _sounds[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["pot_burst", key])
	var big := p_oil == "light_oil"
	var s := SoundSynth._buffer(1.7 if big else 1.2)
	var ph := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var f0 := rng.randf_range(55.0, 75.0)
	var shard_hz := rng.randf_range(1050.0, 1350.0)
	for i in s.size():
		var tt := float(i) / SoundSynth.RATE
		# The clay cracking: a sharp bright burst, the shards ringing.
		var crack := rng.randf_range(-1.0, 1.0) * exp(-tt * 60.0) * 1.2
		var shard := sin(TAU * shard_hz * tt + sin(TAU * 37.0 * tt)) * exp(-tt * 30.0) * 0.25
		# The oil catching all at once: a low thump.
		ph += TAU * f0 * (1.0 - 0.3 * minf(tt, 1.0)) / SoundSynth.RATE
		var whoomp := sin(ph) * smoothstep(0.0, 0.02, tt) * exp(-tt * (4.0 if big else 6.5)) * (1.4 if big else 0.9)
		# The flame's roar: low noise swelling, then dying.
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.12)
		lp2 = lerpf(lp2, lp, 0.25)
		var roar := lp2 * 3.0 * smoothstep(0.01, 0.12, tt) * exp(-tt * (2.2 if big else 3.5))
		s[i] = crack + shard + whoomp + roar
	var w := SoundSynth._to_wav(s)
	_sounds[key] = w
	return w
