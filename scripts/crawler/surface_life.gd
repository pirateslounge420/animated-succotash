class_name SurfaceLife
extends Node3D
## A little ambient life on the surface (design 9 Oct §FM.7; §EW.1: the
## ecology's archetypes, seen in passing, no population sim; worlds.json
## surface.life, data/creatures/creatures.json): the creatures whose climate
## overlaps the world's biome (its climate block, Surface.climate) and who
## live on the ground near you all the time (spawn ambient, role ground;
## never a pack hunter or a mythical: the dark is the only enemy, §ET), in
## their placeholder bodies (CreatureBodies), going about their lives:
##
##   walk    to a spot a little way off at an amble, rest, walk on
##   flee    you come within shy_m: off at speed_mps, away from you (a slow
##           one, the tortoise, just stops and waits)
##   rest    out of its hours (active day, night or any; by the world's
##           daylight, the one clock) it is in its burrow: not seen
##
## count of them, kept within_m of you: one fallen further behind than
## gone_past_m comes back somewhere ahead within_m. Nothing here is hunted,
## hurts or is needed.

var land: SurfaceGround
var player: Node3D
## [{"sp", "root", "legs", "tail", "pos", "yaw", "goal", "state", "t", "phase", "speed"}].
var animals: Array = []
## The species that fit (checks).
var kinds: Array[CreatureSpecies] = []
## 0-1, the day now (Surface sets it from the sky).
var daylight := 1.0
var _rng := RandomNumberGenerator.new()
var _within := Vector2(35.0, 200.0)
var _gone_m := 320.0


## The ground creatures whose climate overlaps the biome's `cl`
## ({"temp_c": Vector2, "moisture": Vector2}).
static func kinds_for(cl: Dictionary) -> Array[CreatureSpecies]:
	var out: Array[CreatureSpecies] = []
	var t: Vector2 = cl.get("temp_c", Vector2(18.0, 35.0))
	var m: Vector2 = cl.get("moisture", Vector2(0.0, 0.2))
	for sp in CreatureSpecies.all():
		if sp.spawn != "ambient" or sp.role != "ground" or sp.temperament == "hostile" or sp.bite > 0.0:
			continue
		if sp.temp_c.y < t.x or sp.temp_c.x > t.y or sp.moisture.y < m.x or sp.moisture.x > m.y:
			continue
		if not sp.needs.is_empty() and (sp.needs.has("shore") or sp.needs.has("open_water") or sp.needs.has("water_within_m")):
			continue
		out.append(sp)
	return out


func setup(p_land: SurfaceGround, p: Dictionary, cl: Dictionary, seed_value: int, p_player: Node3D) -> void:
	name = "Life"
	land = p_land
	player = p_player
	var L: Dictionary = p.get("life", {})
	var c: Array = L.get("count", [5, 9])
	var w: Array = L.get("within_m", [35.0, 200.0])
	_within = Vector2(float(w[0]), float(w[1]))
	_gone_m = float(L.get("gone_past_m", 320.0))
	_rng.seed = hash([seed_value, "surface life"])
	kinds = kinds_for(cl)
	if kinds.is_empty():
		return
	var n := _rng.randi_range(int(c[0]), int(c[1]))
	for i in n:
		var sp: CreatureSpecies = kinds[i % kinds.size()]
		var b := CreatureBodies.build(sp)
		var root: Node3D = b.root
		root.name = "%s_%d" % [sp.name.replace(" ", "_"), i]
		add_child(root)
		var a := {"sp": sp, "root": root, "legs": b.get("legs", []), "tail": b.get("tail"), "pos": Vector3.ZERO, "yaw": 0.0,
			"goal": Vector3.ZERO, "state": "rest", "t": 0.0, "phase": _rng.randf() * TAU, "speed": 0.0}
		animals.append(a)
		_place(a, land.center, true)


## Put `a` somewhere within_m of `from` (x/z, the stairhead or you), on open
## walkable ground; `anywhere` round about, else ahead of where you look.
func _place(a: Dictionary, from: Vector2, anywhere := false) -> void:
	var fwd := Vector2(0.0, -1.0)
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		var f := -player.global_basis.z
		fwd = Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else fwd
	for t in 20:
		var ang := _rng.randf() * TAU if anywhere else atan2(fwd.y, fwd.x) + _rng.randf_range(-1.2, 1.2)
		var d := _rng.randf_range(_within.x, _within.y)
		var q := from + Vector2(cos(ang), sin(ang)) * d
		if land.inside(q, 40.0) and land.slope_at(q.x, q.y) < 0.35:
			a.pos = Vector3(q.x, land.height_at(q.x, q.y), q.y)
			a.goal = a.pos
			a.state = "rest"
			a.t = _rng.randf_range(0.5, 4.0)
			return
	a.pos = Vector3(from.x, land.height_at(from.x, from.y), from.y)


## Is `sp` about now (its active hours by the daylight)?
func awake(sp: CreatureSpecies) -> bool:
	match sp.active:
		"day":
			return daylight > 0.3
		"night", "full_moon":
			return daylight < 0.5
	return true


func _process(delta: float) -> void:
	if land == null:
		return
	var you := Vector3.INF
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		you = player.global_position
	for a in animals:
		var sp: CreatureSpecies = a.sp
		var root: Node3D = a.root
		var up := awake(sp)
		root.visible = up
		if not up:
			continue
		var pos: Vector3 = a.pos
		if you != Vector3.INF and Vector2(pos.x - you.x, pos.z - you.z).length() > _gone_m:
			_place(a, Vector2(you.x, you.z))
			pos = a.pos
		a.t = float(a.t) - delta
		var away := Vector3.ZERO
		if you != Vector3.INF:
			away = Vector3(pos.x - you.x, 0.0, pos.z - you.z)
		var near := sp.shy_m > 0.0 and away != Vector3.ZERO and away.length() < sp.shy_m
		match str(a.state):
			"rest":
				a.speed = 0.0
				if near:
					_flee(a, away)
				elif float(a.t) <= 0.0:
					_wander(a)
			"walk":
				if near:
					_flee(a, away)
				elif Vector2(pos.x - (a.goal as Vector3).x, pos.z - (a.goal as Vector3).z).length() < 0.4 or float(a.t) <= 0.0:
					a.state = "rest"
					a.t = _rng.randf_range(2.0, 8.0)
			"flee":
				if float(a.t) <= 0.0 and not near:
					a.state = "rest"
					a.t = _rng.randf_range(1.0, 4.0)
			"hide":
				# A slow one, withdrawn: still until you've gone.
				a.speed = 0.0
				if float(a.t) <= 0.0 and not near:
					a.state = "rest"
					a.t = _rng.randf_range(2.0, 5.0)
		var goal: Vector3 = a.goal
		var to := Vector3(goal.x - pos.x, 0.0, goal.z - pos.z)
		var sp_now := float(a.speed)
		if sp_now > 0.0 and to.length() > 0.05:
			var step := to.normalized() * minf(sp_now * delta, to.length())
			var nxt := Vector2(pos.x + step.x, pos.z + step.z)
			if land.inside(nxt, 30.0) and land.slope_at(nxt.x, nxt.y) < 0.6:
				pos = Vector3(nxt.x, land.height_at(nxt.x, nxt.y), nxt.y)
				a.yaw = lerp_angle(float(a.yaw), atan2(-step.x, -step.z), clampf(delta * 8.0, 0.0, 1.0))
			else:
				a.state = "rest"
				a.t = _rng.randf_range(1.0, 3.0)
		a.pos = pos
		root.position = pos
		root.rotation = Vector3(0.0, float(a.yaw), 0.0)
		# The legs swing while it moves (CreatureBodies' pivots).
		a.phase = float(a.phase) + delta * sp_now * 9.0 / maxf(sp.size_m, 0.1)
		var legs: Array = a.legs
		for k in legs.size():
			var leg := legs[k] as Node3D
			if leg != null:
				leg.rotation.x = sin(float(a.phase) + (PI if k % 2 == 1 else 0.0) + (PI * 0.5 if k >= 2 else 0.0)) * minf(sp_now, 1.0) * 0.6


func _wander(a: Dictionary) -> void:
	var sp: CreatureSpecies = a.sp
	var pos: Vector3 = a.pos
	var ang := _rng.randf() * TAU
	var d := _rng.randf_range(6.0, 30.0)
	var q := Vector2(pos.x, pos.z) + Vector2(cos(ang), sin(ang)) * d
	if not land.inside(q, 40.0):
		q = Vector2(pos.x, pos.z) + (land.center - Vector2(pos.x, pos.z)).normalized() * d
	a.goal = Vector3(q.x, land.height_at(q.x, q.y), q.y)
	a.state = "walk"
	a.speed = maxf(sp.speed_mps * 0.25, 0.15)
	a.t = d / maxf(float(a.speed), 0.05) + 2.0


func _flee(a: Dictionary, away: Vector3) -> void:
	var sp: CreatureSpecies = a.sp
	if sp.speed_mps < 1.0:
		a.state = "hide"
		a.speed = 0.0
		a.t = _rng.randf_range(6.0, 12.0)
		return
	var pos: Vector3 = a.pos
	var dir := away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	var q := Vector2(pos.x, pos.z) + Vector2(dir.x, dir.z) * _rng.randf_range(14.0, 28.0)
	a.goal = Vector3(q.x, land.height_at(q.x, q.y), q.y)
	a.state = "flee"
	a.speed = sp.speed_mps
	a.t = _rng.randf_range(1.5, 3.0)
