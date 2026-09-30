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
## (dread.json hunters, `first`); everywhere else the dark itself, a
## cloaked shape with no species. Never inside a fire's radius. Ignores
## the travellers. No bestiary, no HUD. Ambient profile only.

static var D := Tuning.table("dread")
static var M: Dictionary = D.get("meter", {})
static var STAGES: Array = D.get("stages", [])
static var RULES: Dictionary = D.get("rules", {})
## 1 normally; falls to 0 at stage 1 (Creature: the calls stop).
static var bed_gain := 1.0
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


func light_on_you() -> bool:
	return not force_dark and Torch.light_at(player.global_position) > 0.05


func is_night() -> bool:
	return force_dark or sky.daylight < 0.2


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
	elif light_on_you():
		rate = float(M.get("fill_per_min_torch", 0.07))
	elif sky.moonlight > 0.3 and not force_dark:
		rate = float(M.get("fill_per_min_moon", 0.14))
	else:
		rate = float(M.get("fill_per_min_dark", 0.2))
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
				_voice.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d) + 1.0)
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
				var d := CreatureSpawner._offset(player.surface_dir, _facing_angle() + side * deg_to_rad(_rng.randf_range(50.0, 110.0)), dist)
				if not Campfire.lit_near(get_tree(), world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d)), float(RULES.get("never_within_fire_m", 14.0))):
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
	var speed := float(_hunter_entry.get("speed_mps", 5.8))
	if sky.moonlight > 0.9:
		speed *= float(_hunter_entry.get("full_moon_speed_scale", 1.0))
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
		# Parallel, off to one side, at keep_m: slowly re-picked.
		if _rng.randf() < delta * 0.05:
			_side = -_side
		if _rng.randf() < delta * 0.1:
			_keep_m = _rand_range(_rng, pattern.get("keep_m"), Vector2(20, 40))
		target = CreatureSpawner._offset(pd, _facing_angle() + _side * PI * 0.5, _keep_m)
	# Never inside a lit fire's radius: hold where it is.
	var tp: Vector3 = world.to_scene(target, PlanetConst.RADIUS_M + chunks.ground_height(target))
	if Campfire.lit_near(get_tree(), tp, float(RULES.get("never_within_fire_m", 14.0))):
		return
	var here: Vector3 = world.to_scene(_hunter_dir, PlanetConst.RADIUS_M + chunks.ground_height(_hunter_dir))
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


## The hunter for this biome (dread.json hunters): the werewolf in its
## forests (built, `first`), else the dark itself, a cloaked shape.
func _ensure_hunter() -> void:
	if _hunter != null:
		return
	_hunter_entry = _entry_for(FireStore.biome_key(world, player.surface_dir))
	_hunter = Node3D.new()
	_hunter.name = "Dread"
	world.world_root.add_child(_hunter)
	var body: Node3D = null
	var sp := CreatureSpecies.find("Werewolf") if str(_hunter_entry.get("creature", "")) == "Werewolf" else null
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


func _entry_for(biome: String) -> Dictionary:
	var fallback := {}
	for h in D.get("hunters", []):
		if not h is Dictionary:
			continue
		var biomes: Array = h.get("biomes", [])
		if biomes.has("*"):
			fallback = h
		elif biomes.has(biome) and str(h.get("creature", "")) == "Werewolf":
			return h
	return fallback


func _place_hunter(d: Vector3, face_player: bool, along := Vector3.ZERO) -> void:
	_hunter_dir = d
	var pos: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
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
