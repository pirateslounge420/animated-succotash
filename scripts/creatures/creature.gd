class_name Creature
extends Node3D
## One living creature. It keeps its own spot on the planet as a surface
## direction (so the floating origin never disturbs it) and re-derives its
## scene position every frame, standing on the ground, floating on water,
## perching in a tree crown or flying.
##
## Behavior by habitat role (DESIGN.md "Creature Spawning"):
##   ground      wander near home, graze, now and then walk to nearby
##               water to drink; bolt away when you get close, then stay
##               wary (standing, watching you) until it calms down
##   canopy      perch in one tree's crown; hop or fly to another tree
##   water_edge  waders stand and step in the shallows, ducks paddle on open
##               water; both take off when startled
##   swarm       fireflies drifting over one spot
##   insect      beetles scurry out from under a log, then burrow away
##   pack        driven by CreatureSpawner: rest / patrol / close in / retreat
##   mythical    driven by CreatureSpawner's territory states; temperament
##               sets what "visible" means: hostile stalks at a distance and
##               freezes when looked at, neutral watches, friendly comes over
## How close is "close" depends on how loud you are (the player's
## noise_level: crouched and still, you can get within a third of a
## creature's shy_m; sprinting, it bolts from half again as far) and on its
## suspicion (1 after it's been startled). Suspicion fades while you keep
## still near it (a few seconds) or stay well away (slowly).
## No creature attacks; there is no combat.

signal finished(creature: Creature)

var species: CreatureSpecies
var world: Node
var chunks: ChunkManager
var spawner: Node

var dir := Vector3.UP # where on the planet
var heading := Vector3.FORWARD # tangent direction it faces
var lift := 0.0 # meters above the ground (or the water, when afloat)
var afloat := false
var home := Vector3.UP # tether point
var home_radius := 20.0
var host := {} # canopy: {"dir", "base", "height"}
var mode := "idle"
var goal := Vector3.ZERO
var goal_speed := 0.0
var keep_away_m := 0.0 # pack / mythical: stay this far from goal
var ring_offset := 0.0 # pack: slot angle around the player
var voice: AudioStreamPlayer3D
var voice_variant := 0
var leaving := false
var done := false
var fly_off := false
## 0-1: how wary it still is after being startled.
var suspicion := 0.0

var _parts := {}
var _body: Node3D
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _anim := 0.0
var _speed_now := 0.0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_lift := Vector2.ZERO
var _hop_t := 0.0
var _hop_len := 1.0
var _fade := 0.0
var _call_timer := 0.0
var _life := -1.0


func setup(sp: CreatureSpecies, p_world: Node, p_chunks: ChunkManager, p_spawner: Node, d: Vector3, seed_value: int) -> void:
	species = sp
	world = p_world
	chunks = p_chunks
	spawner = p_spawner
	dir = d
	home = d
	_rng.seed = seed_value
	name = sp.name.replace(" ", "_")
	heading = CubeSphere.north(d).rotated(d, _rng.randf() * TAU)
	_parts = CreatureBodies.build(sp)
	_body = _parts.root
	add_child(_body)
	home_radius = clampf(sp.one_per_radius_m * 0.6, 8.0, 60.0)
	if sp.sound != "none":
		voice = AudioStreamPlayer3D.new()
		voice_variant = _rng.randi_range(0, SoundSynth.VARIANTS - 1)
		voice.stream = SoundSynth.stream(sp.sound, voice_variant)
		voice.pitch_scale = clampf(0.9 / pow(maxf(sp.size_m, 0.05), 0.15), 0.6, 1.6) * _rng.randf_range(0.93, 1.07)
		voice.unit_size = 8.0 if sp.role != "mythical" and sp.role != "pack" else 40.0
		voice.max_distance = 180.0 if sp.role != "mythical" and sp.role != "pack" else 1400.0
		voice.volume_db = -6.0
		voice.position = Vector3(0, sp.size_m * 0.6, 0)
		add_child(voice)
	_call_timer = _rng.randf_range(2.0, 12.0)
	match sp.role:
		"canopy":
			mode = "perch"
		"water_edge":
			afloat = sp.needs.get("open_water", false)
			mode = "idle"
		"swarm":
			mode = "drift"
		"insect":
			mode = "scurry"
			_life = _rng.randf_range(12.0, 22.0)
		_:
			mode = "idle"
	_timer = _rng.randf_range(0.5, 4.0)


## Perch in a tree crown (canopy dwellers).
func set_host(h: Dictionary) -> void:
	host = h
	dir = _perch_dir(h)
	lift = _perch_lift(h)


## Fade out and free itself (walked out of range, or its time of day ended).
func leave() -> void:
	leaving = true


## Show or hide the body (mythical creatures are heard before they're seen).
func set_visible_body(v: bool) -> void:
	_body.visible = v


func say() -> void:
	if voice and voice.stream and not voice.playing:
		voice.play()


func distance_to(d: Vector3) -> float:
	return CubeSphere.surface_distance_m(dir, d)


func tick(delta: float, ctx: Dictionary) -> void:
	if done:
		return
	_timer -= delta
	var player_dir: Vector3 = ctx.player_dir
	var to_player := distance_to(player_dir)

	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			leave()

	var shy := _shy_m(ctx)
	_calm(delta, ctx, to_player, shy)
	match species.role:
		"ground":
			_ground(delta, player_dir, to_player, shy)
		"canopy":
			_canopy(delta, player_dir, to_player, shy)
		"water_edge":
			_water_edge(delta, player_dir, to_player, shy)
		"swarm":
			_drift(delta)
		"insect":
			_scurry(delta)
		"pack", "mythical":
			_driven(delta, ctx)

	# Occasional calls while active and not fleeing.
	if voice and species.role != "pack" and species.role != "mythical":
		_call_timer -= delta
		if _call_timer <= 0.0:
			_call_timer = _call_interval()
			if mode != "flee" and not leaving:
				say()

	_fade = move_toward(_fade, 0.0 if leaving else 1.0, delta * 1.5)
	if leaving and _fade <= 0.0:
		done = true
		finished.emit(self)
		return
	_place(delta)


func _call_interval() -> float:
	match species.sound:
		"croak":
			return _rng.randf_range(2.5, 8.0)
		"chirp":
			return _rng.randf_range(5.0, 18.0)
	return _rng.randf_range(10.0, 30.0)


# --- Roles ---------------------------------------------------------------------

## Flight distance now: shy_m scaled by the player's noise, widened by
## suspicion.
func _shy_m(ctx: Dictionary) -> float:
	var noise: float = ctx.get("player_noise", 0.4)
	return species.shy_m * (0.35 + 1.25 * noise) * (1.0 + suspicion)


## Suspicion fades while the player keeps still nearby (it's watching you
## and nothing happens), slowly when you're far off.
func _calm(delta: float, ctx: Dictionary, to_player: float, shy: float) -> void:
	if suspicion <= 0.0:
		return
	var still: float = ctx.get("player_still", 0.0)
	if still > 1.5 and to_player < shy * 4.0 + 10.0:
		suspicion -= delta / 6.0
	elif to_player > shy * 3.0:
		suspicion -= delta / 25.0
	suspicion = maxf(suspicion, 0.0)


func _ground(delta: float, player_dir: Vector3, to_player: float, shy: float) -> void:
	if species.shy_m > 0.0 and to_player < shy and mode != "flee":
		mode = "flee"
		suspicion = 1.0
		_body.rotation.x = 0.0
		_timer = _rng.randf_range(3.0, 6.0)
	match mode:
		"flee":
			var away := -_tangent_to(player_dir)
			_walk(dir + away * 0.001, species.speed_mps, delta)
			if _timer <= 0.0 or to_player > shy * 2.5:
				mode = "wary"
				home = dir
				_timer = _rng.randf_range(2.0, 6.0)
		"wary":
			# Stands and watches you until its suspicion has faded.
			_speed_now = 0.0
			var t := _tangent_to(player_dir)
			heading = heading.slerp(t, clampf(delta * 3.0, 0.0, 1.0)).normalized()
			if suspicion <= 0.0:
				mode = "idle"
				_timer = _rng.randf_range(1.0, 3.0)
		"idle":
			_speed_now = 0.0
			if _timer <= 0.0:
				if _rng.randf() < DRINK_CHANCE and _go_drink():
					return
				goal = _random_near(home, home_radius)
				mode = "walk" if _is_dry(goal) else "idle"
				_timer = _rng.randf_range(1.0, 3.0)
		"walk":
			var left := _walk(goal, species.speed_mps * 0.35, delta)
			if left < 0.5 or _timer < -20.0:
				mode = "idle"
				_timer = _rng.randf_range(2.0, 8.0)
		"to_water":
			var left := _walk(goal, species.speed_mps * 0.35, delta)
			if left < 0.5:
				mode = "drink"
				_timer = _rng.randf_range(5.0, 9.0)
			elif _timer < -25.0:
				mode = "idle"
				_timer = _rng.randf_range(2.0, 5.0)
		"drink":
			# Head down at the water's edge, then back to its usual ground.
			_speed_now = 0.0
			_body.rotation.x = lerpf(_body.rotation.x, -0.3, clampf(delta * 4.0, 0.0, 1.0))
			if _timer <= 0.0:
				_body.rotation.x = 0.0
				goal = _random_near(home, home_radius * 0.5)
				mode = "walk" if _is_dry(goal) else "idle"
				_timer = _rng.randf_range(1.0, 3.0)


## Now and then a grazer wanders off to drink (flavor, not a needs
## simulation): open water within DRINK_REACH_M, walking to the last dry
## ground before it.
const DRINK_CHANCE := 0.08
const DRINK_REACH_M := 45.0


func _go_drink() -> bool:
	var a0 := _rng.randf() * TAU
	for k in 12:
		var a := a0 + k * TAU / 12.0
		var prev := dir
		for step in range(1, 7):
			var p := CreatureSpawner._offset(dir, a, DRINK_REACH_M * step / 6.0)
			if not _is_dry(p):
				if step == 1:
					break
				goal = prev
				mode = "to_water"
				_timer = 0.0
				return true
			prev = p
	return false


func _canopy(delta: float, player_dir: Vector3, to_player: float, shy: float) -> void:
	match mode:
		"perch":
			_speed_now = 0.0
			var startled := species.shy_m > 0.0 and to_player < shy
			if startled:
				suspicion = 1.0
			if startled or _timer <= 0.0:
				var next: Dictionary = spawner.host_near(dir, 12.0 if not startled else 25.0, host, player_dir if startled else Vector3.ZERO)
				if next.is_empty():
					_timer = _rng.randf_range(4.0, 12.0)
				else:
					_hop(_perch_dir(next), _perch_lift(next))
					host = next
		"hop":
			_hop_step(delta)
			if _hop_t >= 1.0:
				mode = "perch"
				_timer = _rng.randf_range(6.0, 25.0)


func _water_edge(delta: float, player_dir: Vector3, to_player: float, shy: float) -> void:
	if fly_off:
		# Took off: climb away and vanish.
		lift += delta * 2.5
		dir = (dir + heading * species.speed_mps * 6.0 * delta / PlanetConst.RADIUS_M).normalized()
		_speed_now = 6.0
		if lift > 25.0:
			leave()
		return
	if species.shy_m > 0.0 and to_player < shy:
		suspicion = 1.0
		if afloat and to_player > shy * 0.45:
			mode = "flee"
		else:
			fly_off = true
			heading = -_tangent_to(player_dir)
			spawner.cooldown(self)
			return
	match mode:
		"flee":
			_walk(dir - _tangent_to(player_dir) * 0.001, species.speed_mps * 2.0, delta, true)
			if to_player > shy * 1.5:
				mode = "idle"
		"idle":
			_speed_now = 0.0
			if _timer <= 0.0:
				var g := _random_near(home, 15.0)
				if _water_ok(g):
					goal = g
					mode = "walk"
				_timer = _rng.randf_range(3.0, 10.0)
		"walk":
			if _walk(goal, species.speed_mps, delta, true) < 0.4 or _timer < -15.0:
				mode = "idle"
				_timer = _rng.randf_range(4.0, 14.0)


func _drift(delta: float) -> void:
	if _timer <= 0.0:
		goal = _random_near(home, 6.0)
		_timer = _rng.randf_range(4.0, 10.0)
	_walk(goal, species.speed_mps, delta, false, false)
	lift = 0.0


func _scurry(delta: float) -> void:
	if _timer <= 0.0:
		heading = heading.rotated(dir, _rng.randf_range(-1.2, 1.2))
		_timer = _rng.randf_range(0.3, 1.2)
	_walk(dir + heading * 0.001, species.speed_mps, delta)


## Pack and mythical creatures: CreatureSpawner sets `mode` and `goal`.
##   rest      stand still near goal
##   go        walk to goal
##   ring      hold `keep_away_m` from goal (the player), slot `ring_offset`
##   stalk     hold keep_away_m, freeze while the player looks at it
##   watch     stand and face the player
func _driven(delta: float, ctx: Dictionary) -> void:
	var player_dir: Vector3 = ctx.player_dir
	var bob := 0.0
	match mode:
		"rest":
			_speed_now = 0.0
			if _timer <= 0.0 and distance_to(goal) > 3.0:
				_walk(goal, species.speed_mps * 0.3, delta)
		"go":
			if _walk(goal, goal_speed if goal_speed > 0.0 else species.speed_mps * 0.4, delta) < 1.0:
				# Arrived: turn to look at the player.
				_speed_now = 0.0
				var t := _tangent_to(player_dir)
				if distance_to(player_dir) < 80.0 and t.length() > 0.5:
					heading = heading.slerp(t, clampf(delta * 3.0, 0.0, 1.0)).normalized()
		"ring", "stalk":
			var looked_at: bool = mode == "stalk" and ctx.get("looking_at", {}).has(self)
			var d := distance_to(player_dir)
			var to_p := _tangent_to(player_dir)
			var side := to_p.cross(dir).normalized()
			var want := Vector3.ZERO
			if d > keep_away_m + 2.0:
				want += to_p
			elif d < keep_away_m - 2.0:
				want -= to_p
			if mode == "ring":
				want += side * sin(ring_offset + Time.get_ticks_msec() * 0.0002) * 0.6
			if looked_at:
				_speed_now = 0.0
			elif want.length() > 0.1:
				var sp := species.speed_mps * (0.8 if mode == "ring" else 0.6)
				_walk(dir + want.normalized() * 0.001, sp, delta)
			else:
				_speed_now = 0.0
			heading = to_p if to_p.length() > 0.5 else heading
		"watch":
			_speed_now = 0.0
			var t := _tangent_to(player_dir)
			if t.length() > 0.5:
				heading = heading.slerp(t, clampf(delta * 2.0, 0.0, 1.0)).normalized()
	if species.shape == "wisp":
		bob = sin(Time.get_ticks_msec() * 0.0015 + ring_offset) * 0.4
		lift = 0.6 + bob


# --- Movement ------------------------------------------------------------------

## Unit tangent from here toward a surface direction.
func _tangent_to(d: Vector3) -> Vector3:
	var t := d - dir * dir.dot(d)
	if t.length_squared() < 1e-14:
		return heading
	return t.normalized()


## Step toward a surface direction; returns the remaining distance in m.
## Land walkers refuse to step into water; swimmers refuse to leave it.
func _walk(target: Vector3, speed: float, delta: float, in_water := false, turn := true) -> float:
	var left := distance_to(target)
	if left < 0.05:
		_speed_now = 0.0
		return left
	var t := _tangent_to(target)
	var step := minf(speed * delta, left)
	var next := (dir + t * step / PlanetConst.RADIUS_M).normalized()
	var flies := species.role == "swarm" or species.shape == "wisp"
	var ok := _water_ok(next) if in_water else (flies or _is_dry(next))
	if not ok:
		heading = heading.rotated(dir, PI * 0.6)
		_speed_now = 0.0
		_timer = minf(_timer, 0.5)
		if mode == "walk":
			mode = "idle"
		return left
	dir = next
	if turn:
		heading = heading.slerp(t, clampf(delta * 8.0, 0.0, 1.0)).normalized()
	_speed_now = speed
	return left - step


func _hop(to_dir: Vector3, to_lift: float) -> void:
	_hop_from = dir
	_hop_to = to_dir
	_hop_lift = Vector2(lift, to_lift)
	_hop_t = 0.0
	_hop_len = maxf(CubeSphere.surface_distance_m(dir, to_dir) / species.speed_mps, 0.4)
	heading = _tangent_to(to_dir)
	mode = "hop"


func _hop_step(delta: float) -> void:
	_hop_t = minf(_hop_t + delta / _hop_len, 1.0)
	dir = _hop_from.slerp(_hop_to, _hop_t).normalized()
	lift = lerpf(_hop_lift.x, _hop_lift.y, _hop_t) + sin(_hop_t * PI) * minf(2.0 + _hop_len, 6.0)
	_speed_now = species.speed_mps


## Birds and climbers sit on top of the crown, where you can spot them
## against the sky; tree frogs cling to the trunk lower down.
func _perch_dir(h: Dictionary) -> Vector3:
	var d: Vector3 = h.dir
	var off := CubeSphere.north(d).rotated(d, _rng.randf() * TAU)
	var r: float = h.height * (0.06 if species.body != "frog" else 0.05)
	return (d + off * r / PlanetConst.RADIUS_M).normalized()


func _perch_lift(h: Dictionary) -> float:
	var frac := 0.97 if species.body != "frog" else _rng.randf_range(0.25, 0.45)
	return h.base - PlanetConst.RADIUS_M - chunks.ground_height(h.dir) + h.height * frac


func _random_near(center: Vector3, radius: float) -> Vector3:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * radius
	var t := CubeSphere.north(center).rotated(center, a)
	return (center + t * r / PlanetConst.RADIUS_M).normalized()


func _is_dry(d: Vector3) -> bool:
	return chunks.water_level_at(d) < chunks.ground_height(d) + 0.08


## Water creatures: waders need 5-60 cm of water, swimmers at least 40 cm.
func _water_ok(d: Vector3) -> bool:
	var depth := chunks.water_level_at(d) - chunks.ground_height(d)
	if afloat:
		return depth > 0.4
	return depth > 0.03 and depth < 0.6


func _place(delta: float) -> void:
	var ground := chunks.ground_height(dir)
	var base := ground
	if afloat:
		base = maxf(ground, chunks.water_level_at(dir))
	global_position = world.to_scene(dir, PlanetConst.RADIUS_M + base + lift)
	var fwd := heading - dir * heading.dot(dir)
	if fwd.length_squared() < 1e-6:
		fwd = CubeSphere.north(dir)
	global_basis = Basis.looking_at(fwd.normalized(), dir)
	var size := 1.0 if species.role == "swarm" else species.size_m
	_body.scale = Vector3.ONE * size * maxf(_fade, 0.001)
	_animate(delta)


func _animate(delta: float) -> void:
	var moving := _speed_now > 0.05
	_anim += delta * (4.0 + _speed_now * 3.0 / maxf(species.size_m, 0.2))
	var swing := sin(_anim) * (0.6 if moving else 0.0)
	var legs: Array = _parts.legs
	for i in legs.size():
		var leg: Node3D = legs[i]
		var target := swing * (1.0 if i % 2 == 0 else -1.0)
		leg.rotation.x = lerpf(leg.rotation.x, target, clampf(delta * 10.0, 0.0, 1.0))
	var flying := mode == "hop" and species.body in ["bird", "wader", "duck"] or fly_off
	var wings: Array = _parts.wings
	for i in wings.size():
		var w: Node3D = wings[i]
		var s := 1.0 if i % 2 == 0 else -1.0
		if species.role == "mythical":
			# Arms: hang and sway.
			w.rotation.x = sin(_anim * 0.5 + i) * (0.3 if moving else 0.06)
		elif flying:
			w.rotation.z = sin(_anim * 3.0) * 0.9 * s
		else:
			w.rotation.z = lerpf(w.rotation.z, -1.2 * s if species.body != "bird" else -1.35 * s, clampf(delta * 6.0, 0.0, 1.0))
	if _parts.tail:
		(_parts.tail as Node3D).rotation.y = sin(_anim * 0.7) * 0.25
