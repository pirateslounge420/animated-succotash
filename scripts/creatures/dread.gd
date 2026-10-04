class_name Dread
extends Node
## The dark closes in (design 30 Sept §BA, data/dread.json). Between
## camps at night exposure fills a hidden meter: nothing on the HUD, you
## read it in the world. Light holds it off: inside a lit fire's radius
## it drains (FireStore: embers and a dead fire don't count); a lit torch
## in hand or planted within its range slows it; full dark fills it
## fastest, moonlight a little slower; dawn empties it. Stages, each heard
## before it is seen: 1 the bed thins (the creatures' calls stop,
## `bed_gain`); 2 a sound behind you that stops when you stop; 3 a shape
## at the edge of the light, gone when you look; 4 it follows in the open,
## keeping its distance, faster than you; 5 it closes, and takes you if
## no light is on you or you are far from any fire ("Taken by the dark").
## Never a fight: a chase you lose by being in the dark too long.
##
## One hunter is built: the werewolf as a pacer in temperate forest
## (dread.json hunters, `first`), only on the brightest nights (design 3
## Oct §DG, dread.json full_moon: the moon at least
## DayCycle.full_moon_illumination lit); its forests' other nights and
## everywhere else, the dark itself, a cloaked shape with no species. The
## werewolf hunts by scent (senses.json watchers.werewolf: light_sight_m
## 0): a torch neither draws it nor hides you, and it comes from downwind
## of you. Light still holds every beast off. Never inside a fire's
## radius. Ignores the travellers. No bestiary, no HUD. Ambient profile
## only.

static var D := Tuning.table("dread")
static var M: Dictionary = D.get("meter", {})
static var STAGES: Array = D.get("stages", [])
static var RULES: Dictionary = D.get("rules", {})
## 1 normally; falls to 0 at stage 1 (Creature: the calls stop).
static var bed_gain := 1.0
## Inside an overrun delve (design 2 Oct §CN, Overrun): what holds it, the
## hunter this dread brings ({} elsewhere).
static var den_entry := {}
static var instance: Dread = null

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var sky: SkySystem
var enabled := Tuning.profile() == "ambient"

var meter := 0.0
var stage := 0
## Real minutes since dusk (INF by day).
var _since_dusk_min := INF
var _hunter: Node3D = null
var _hunter_body: Node3D = null
var _hunter_entry := {}
var _hunter_dir := Vector3.ZERO
var _side := 1.0
var _keep_m := 30.0
var _cue_t := 6.0
var _glimpse_t := 0.0
var _glimpse_up := 0.0
var _looked_s := 0.0
var _voice: AudioStreamPlayer3D
var _close_voice: AudioStreamPlayer3D
var _closing := false
var _rng := RandomNumberGenerator.new()
## Tests: force night and no light (dread_check).
var force_dark := false
## Tools: a wind (scene vector, m/s) to smell by instead of the gust field.
static var wind_pin := Vector3.INF
## The bearing (radians from north, east positive) a scent hunter keeps
## from you: downwind, re-picked slowly (§DG). NAN until first picked.
var scent_bearing := NAN


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_sky: SkySystem) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	sky = p_sky
	instance = self
	_rng.randomize()
	_voice = Audio3D.make("dread_follow", self, "Follow")
	_close_voice = Audio3D.make("dread_close", self, "Close")


func _exit_tree() -> void:
	if instance == self:
		instance = null
	bed_gain = 1.0


static func _rand_range(rng: RandomNumberGenerator, v, fallback: Vector2) -> float:
	if v is Array and (v as Array).size() == 2:
		return rng.randf_range(float(v[0]), float(v[1]))
	return rng.randf_range(fallback.x, fallback.y)


static func stage_row(level: int) -> Dictionary:
	for s in STAGES:
		if int(s.get("level", -1)) == level:
			return s
	return {}


## Is a lit fire within `r` m of the player?
func fire_near(r: float) -> bool:
	return Campfire.lit_near(get_tree(), player.global_position, r)


## The nearest lit fire's distance (INF if none in the scene).
func fire_distance() -> float:
	var best := INF
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var fire := f as Node3D
		if fire and fire.is_inside_tree() and bool(fire.get_meta("lit", true)):
			best = minf(best, fire.global_position.distance_to(player.global_position))
	return best


## The meter's fill per minute at night away from a fire: a torch on you
## slows it, unless what hunts here hunts by scent (§DG: the torch neither
## draws it nor hides you), else fill_rate by the moonlight.
static func dark_rate(moonlight: float, torch_on: bool, hunter: Dictionary) -> float:
	if torch_on and not by_scent(hunter):
		return float(M.get("fill_per_min_torch", 0.07))
	return fill_rate(moonlight)


## Does the hunter `entry` (a dread.json hunters row) hunt by scent: its
## senses.json watchers row has no light sight (the werewolf, §DG)?
static func by_scent(entry: Dictionary) -> bool:
	var c = entry.get("creature")
	if c == null:
		return false
	var row: Dictionary = (Tuning.table("senses").get("watchers", {}) as Dictionary).get(str(c).to_lower(), {})
	return not row.is_empty() and float(row.get("light_sight_m", 1.0)) <= 0.0 and float(row.get("scent_m", 0.0)) > 0.0


## What hunts where you stand tonight (den_entry in an overrun delve).
func hunter_here() -> Dictionary:
	if not den_entry.is_empty():
		return den_entry
	if _hunter != null:
		return _hunter_entry
	return entry_for(FireStore.biome_key(world, player.surface_dir), Astro.moon_illumination(world.days))


## The meter's fill per minute in the dark, by the moonlight on you (0-1,
## SkySystem.moonlight: the phase and whether the moon is up): from
## fill_per_min_dark under no moon to fill_per_min_moon under a full one
## high (design 3 Oct §DD, dread.json full_moon.moon_fill_by_light).
static func fill_rate(moonlight: float) -> float:
	var dark := float(M.get("fill_per_min_dark", 0.2))
	var moon := float(M.get("fill_per_min_moon", 0.14))
	if not bool((D.get("full_moon", {}) as Dictionary).get("moon_fill_by_light", true)):
		return moon if moonlight > 0.3 else dark
	return lerpf(dark, moon, clampf(moonlight, 0.0, 1.0))


func light_on_you() -> bool:
	return not force_dark and Torch.light_at(player.global_position) > 0.05


func is_night() -> bool:
	# Down in a delve it is night whatever the hour (design 1 Oct §CJ: "full
	# dark; dread accumulates as at night").
	return force_dark or sky.daylight < 0.2 or Delves.underground > 0.6


## Where something of the dark's stands at surface direction `d`: on the
## ground, or in a delve on its nearest floor (Delves.floor_near), never
## on the ground over your head.
func _ground_pos(d: Vector3) -> Vector3:
	if Delves.inside and Delves.instance != null:
		var p := Delves.instance.floor_near(world.to_scene(d, world.radius_of(player.global_position)))
		if p != Vector3.INF:
			return p
	return world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))


func update_dread(delta: float) -> void:
	if not enabled or player == null or player.dead:
		return
	# Dusk and its grace.
	if is_night():
		_since_dusk_min = 0.0 if _since_dusk_min == INF else _since_dusk_min + delta / 60.0
		if force_dark:
			_since_dusk_min = maxf(_since_dusk_min, float(M.get("dusk_grace_min", 6.0)))
	else:
		_since_dusk_min = INF
	# The meter.
	var rate := 0.0
	var by_fire := fire_near(float(M.get("fire_radius_m", 14.0)))
	if not is_night():
		rate = -3.0 if bool(M.get("drain_at_dawn", true)) else 0.0
	elif by_fire:
		rate = -float(M.get("drain_per_min_fire", 1.0))
	elif _since_dusk_min < float(M.get("dusk_grace_min", 6.0)):
		rate = 0.0
	else:
		rate = dark_rate(0.0 if force_dark else sky.moonlight, light_on_you(), hunter_here())
	# Near an overrun ruin at night, outside a fire, it fills faster (§CN).
	if rate > 0.0:
		rate *= Overrun.dread_scale(player.global_position)
	meter = clampf(meter + rate * delta / 60.0, 0.0, 1.0)
	# The stage: the highest whose level the meter has reached.
	var want := 0
	for s in STAGES:
		if meter >= float(s.get("at", 0.0)) - 0.00001 and int(s.get("level", 0)) > want:
			want = int(s.get("level", 0))
	if want != stage:
		_enter_stage(want)
	# The bed thins from stage 1, comes back at 0.
	var fade := float(stage_row(1).get("bed_fade_s", 20.0))
	bed_gain = move_toward(bed_gain, 0.0 if stage >= 1 else 1.0, delta / maxf(fade, 0.1))
	_cues(delta, by_fire)


func _enter_stage(level: int) -> void:
	var was := stage
	stage = level
	if level >= 2 and was < 2:
		_cue_t = _rand_range(_rng, stage_row(2).get("every_s"), Vector2(15, 40)) * 0.4
	if level >= 3 and was < 3:
		_glimpse_t = _rand_range(_rng, stage_row(3).get("every_s"), Vector2(20, 50)) * 0.3
	if level < 3 and _hunter != null:
		_free_hunter()
	if level >= 4 and was < 4:
		_ensure_hunter()
		_hunter.visible = true
		_hunter_dir = CreatureSpawner._offset(player.surface_dir, _rng.randf() * TAU, _keep_m)
	_closing = false


## The sounds and the shapes of each stage.
func _cues(delta: float, by_fire: bool) -> void:
	if stage >= 2 and stage <= 3:
		# A sound behind you, only while you move (it stops when you stop).
		_cue_t -= delta
		if _cue_t <= 0.0:
			var row := stage_row(2)
			_cue_t = _rand_range(_rng, row.get("every_s"), Vector2(15, 40))
			if player.velocity.length() > 0.5 or not bool(row.get("stops_when_you_stop", true)):
				var bearing := deg_to_rad(_rand_range(_rng, row.get("bearing_deg"), Vector2(140, 220)))
				var dist := _rand_range(_rng, row.get("distance_m"), Vector2(12, 25))
				var d := CreatureSpawner._offset(player.surface_dir, _facing_angle() + bearing, dist)
				_voice.global_position = _ground_pos(d) + d * 1.0
				_voice.stream = SoundSynth.stream(["scuff", "crack", "rustle"][_rng.randi() % 3], _rng.randi())
				Audio3D.play(_voice)
	if stage == 3:
		# A shape at the edge of the light, gone when you look at it.
		var row := stage_row(3)
		if _hunter != null and _hunter.visible:
			_glimpse_up += delta
			var to := (_hunter.global_position - player.global_position)
			var look := -player.get_viewport().get_camera_3d().global_basis.z if player.get_viewport().get_camera_3d() else -player.global_basis.z
			if to.normalized().dot(look.normalized()) > cos(deg_to_rad(14.0)):
				_looked_s += delta
			if _looked_s >= float(row.get("vanish_on_look_s", 0.4)) or _glimpse_up > 9.0:
				_hunter.visible = false
		else:
			_glimpse_t -= delta
			if _glimpse_t <= 0.0:
				_glimpse_t = _rand_range(_rng, row.get("every_s"), Vector2(20, 50))
				_ensure_hunter()
				var dist := _rand_range(_rng, row.get("distance_m"), Vector2(10, 16))
				var side := 1.0 if _rng.randf() < 0.5 else -1.0
				var bearing := _facing_angle() + side * deg_to_rad(_rng.randf_range(50.0, 110.0))
				if by_scent(_hunter_entry):
					bearing = pick_scent_bearing(1.0)
				var d := CreatureSpawner._offset(player.surface_dir, bearing, dist)
				if not Campfire.lit_near(get_tree(), _ground_pos(d), float(RULES.get("never_within_fire_m", 14.0))):
					_place_hunter(d, true)
					_hunter.visible = true
					_glimpse_up = 0.0
					_looked_s = 0.0
	if stage >= 4 and _hunter != null:
		_follow(delta, by_fire)


## The compass angle (from north, east positive) the player faces.
func _facing_angle() -> float:
	var f := -player.global_basis.z
	var d := player.surface_dir
	f = (f - d * f.dot(d)).normalized()
	return atan2(f.dot(CubeSphere.east(d)), f.dot(CubeSphere.north(d)))


## Stage 4: it follows in the open, parallel at a distance (pacer). Stage
## 5: it closes if there is no light on you or you are far from a fire;
## else it holds off, waiting for the torch to gutter.
func _follow(delta: float, by_fire: bool) -> void:
	var pattern: Dictionary = (D.get("patterns", {}) as Dictionary).get(str(_hunter_entry.get("pattern", "pacer")), {})
	var speed := speed_for(_hunter_entry, Astro.moon_illumination(world.days))
	var row5 := stage_row(5)
	var far := fire_distance() > float(row5.get("far_from_fire_m", 120.0))
	var can_take := stage >= 5 and (not light_on_you() or far) and not by_fire
	if can_take and not _closing:
		_closing = true
		_close_voice.global_position = _hunter.global_position
		_close_voice.stream = SoundSynth.stream("howl" if str(_hunter_entry.get("creature", "")) == "Werewolf" else "whisper", _rng.randi())
		Audio3D.play(_close_voice)
	elif not can_take:
		_closing = false
	var pd := player.surface_dir
	var target: Vector3
	if _closing:
		target = pd
		speed *= 1.15
	else:
		# Parallel, off to one side, at keep_m: slowly re-picked. A scent
		# hunter keeps to your downwind side instead (§DG).
		if _rng.randf() < delta * 0.05:
			_side = -_side
		if _rng.randf() < delta * 0.1:
			_keep_m = _rand_range(_rng, pattern.get("keep_m"), Vector2(20, 40))
		var bearing := _facing_angle() + _side * PI * 0.5
		if by_scent(_hunter_entry):
			bearing = pick_scent_bearing(delta)
		target = CreatureSpawner._offset(pd, bearing, _keep_m)
	# Never inside a lit fire's radius: hold where it is.
	var tp: Vector3 = _ground_pos(target)
	if Campfire.lit_near(get_tree(), tp, float(RULES.get("never_within_fire_m", 14.0))):
		return
	var here: Vector3 = _ground_pos(_hunter_dir)
	var gap: Vector3 = tp - here
	var step := minf(speed * delta, gap.length())
	if gap.length() > 0.05:
		var nd: Vector3 = world.dir_of(here + gap.normalized() * step)
		_place_hunter(nd, false, gap.normalized())
	if _closing and _hunter.global_position.distance_to(player.global_position) < 1.9:
		_take()


## Taken by the dark (design §BA): the log's line, the death.
func _take() -> void:
	player.death_cause = "dark"
	player.take_hit(9999.0, _hunter.global_position)
	meter = 0.0
	_enter_stage(0)


## The bearing (from north, east positive) the wind blows toward where you
## stand: the gust field's (Wind I), or wind_pin. NAN in a calm.
func downwind_bearing() -> float:
	var up := player.surface_dir
	var w: Vector3 = wind_pin if wind_pin != Vector3.INF else Wind.gust_vec(player.global_position, player.global_basis.y)
	var e := w.dot(CubeSphere.east(up))
	var n := w.dot(CubeSphere.north(up))
	if Vector2(e, n).length() < 0.2:
		return NAN
	return atan2(e, n)


## A scent hunter's side (§DG): your downwind side, with a little play,
## re-picked about every ten seconds (`delta` the time since the last
## call; 1 forces a pick). In a calm it keeps the bearing it had.
func pick_scent_bearing(delta: float) -> float:
	if is_nan(scent_bearing) or _rng.randf() < delta * 0.1:
		var dw := downwind_bearing()
		if not is_nan(dw):
			scent_bearing = dw + deg_to_rad(_rng.randf_range(-25.0, 25.0))
		elif is_nan(scent_bearing):
			scent_bearing = _facing_angle() + _side * PI * 0.5
	return scent_bearing


## The hunter's speed (m/s): its row's, times full_moon_speed_scale on a
## full-moon night (the lit share at or above full_moon_illumination).
static func speed_for(entry: Dictionary, illumination: float) -> float:
	var speed := float(entry.get("speed_mps", 5.8))
	if illumination >= DayCycle.full_moon_illumination():
		speed *= float(entry.get("full_moon_speed_scale", 1.0))
	return speed


## The hunter for this biome (dread.json hunters): the werewolf in its
## forests on the brightest nights (built, `first`), else the dark
## itself, a cloaked shape.
func _ensure_hunter() -> void:
	if _hunter != null:
		return
	_hunter_entry = den_entry if not den_entry.is_empty() else entry_for(FireStore.biome_key(world, player.surface_dir), Astro.moon_illumination(world.days))
	_hunter = Node3D.new()
	_hunter.name = "Dread"
	world.world_root.add_child(_hunter)
	var body: Node3D = null
	# The werewolf, or in an overrun delve whatever holds it (§CN).
	var cname := str(_hunter_entry.get("creature", "")) if _hunter_entry.get("creature") != null else ""
	var sp := CreatureSpecies.find(cname) if cname == "Werewolf" or (not den_entry.is_empty() and cname != "") else null
	if sp != null:
		var b := CreatureBodies.build(sp)
		body = b.root
	if body == null:
		var cb := CloakedFigure.build(2.3, Color(0.015, 0.015, 0.03), Color(0.03, 0.03, 0.05))
		body = cb.root
	_hunter.add_child(body)
	_hunter_body = body
	_hunter.visible = false
	_hunter_dir = player.surface_dir


## The dread.json hunter for `biome` with the moon `illumination` lit:
## the werewolf in its forests (built, `first`), but a hunter named in
## full_moon.only only on a full-moon night (DayCycle
## .full_moon_illumination, §DG); else the fallback (the dark itself, the
## lurker with no species, §CU), as the grasslands meet every night.
static func entry_for(biome: String, illumination := 1.0) -> Dictionary:
	var fallback := {}
	var fm: Dictionary = D.get("full_moon", {})
	var only: Array = fm.get("only", [])
	var bright := illumination >= DayCycle.full_moon_illumination()
	var found := {}
	for h in D.get("hunters", []):
		if not h is Dictionary:
			continue
		var biomes: Array = h.get("biomes", [])
		if biomes.has("*"):
			fallback = h
		elif found.is_empty() and biomes.has(biome) and str(h.get("creature", "")) == "Werewolf":
			if str(h.get("creature", "")) in only and not bright and str(fm.get("other_nights", "fallback")) == "fallback":
				continue
			found = h
	return found if not found.is_empty() else fallback


func _place_hunter(d: Vector3, face_player: bool, along := Vector3.ZERO) -> void:
	_hunter_dir = d
	var pos: Vector3 = _ground_pos(d)
	var fwd := along
	if face_player or fwd.length() < 0.01:
		fwd = player.global_position - pos
	fwd = (fwd - d * fwd.dot(d)).normalized()
	if fwd.length() < 0.01:
		fwd = CubeSphere.north(d)
	_hunter.global_transform = Transform3D(Basis.looking_at(fwd, d), pos)
	if _hunter_body != null and _hunter_body.has_method("set_motion"):
		_hunter_body.call("set_motion", 0.0 if face_player else 0.8, 1.0 / 60.0)


func _free_hunter() -> void:
	if _hunter != null:
		_hunter.queue_free()
		_hunter = null
		_hunter_body = null
	_closing = false
