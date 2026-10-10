extends BossState
## 'coil_ambush' (design 9 Oct §FM.2, Mike's fourth: "if you hear it and
## turn around, it may already be coiled and striking: the jump scare";
## queue 66; data/boss_pool.json pools.desert.coil_ambush):
##
##   going round it goes round through its own dark (and its tunnels) to a
##               spot lies_coiled_behind_m behind you (BossStalk.behind_spot:
##               behind where you look, open floor in its dark, nothing
##               between it and you), never by a way that passes you.
##   lying       there it curls into a coil and waits. As you move on it
##               keeps that far behind you, sliding after you and curling
##               again when you stop, and its tell sounds (TELL_ON_DB); stand
##               still and it is silent.
##   the turn    once it has lain behind you with your back to it, turning
##               toward it (its head coming within turn_deg of where you
##               look) begins its wind-up on that very tick
##               (wind_up_begun_on_turn): the strike as built, its tell (the
##               hiss, the head drawn back) and its wind-up, the lunge, the
##               recovery (Boss.begin_strike), so the jump scare is real. A
##               lunge that reaches you is one hit of three (§FD, is_hit
##               hit_1_of_three; harm.json's breath between hits holds),
##               never more. Your lit torch is a delay (torch_delay): the time
##               it has spent beyond your torch's bright circle
##               (torch_delay.hang_m) stalking you, your torch lit, counts
##               toward hang_s, in all, as the hold does (begin_strike's
##               held_s), so turn on it sooner than that and your flame
##               holds it first (reared at the edge of your light, hissing
##               its warning), then it strikes; with your torch out nothing
##               holds it.
##   let go      keep walking and it lets you go when its dwell runs out
##               (its dwell counted from when it first lay behind you): the
##               next state takes over, and for let_go_s its rounds don't
##               take you up by sight or hearing and neither it nor
##               observe_then_behind may come back for you (Boss.let_go,
##               BossStalk.may_stalk).
##   and         walk back into it (within its strike's reach) and it
##               strikes as built. It comes only with you on its own floor;
##               a light that catches across its way, it holds and finds
##               another (lights_changed).

## Its tell as you move on, and lying still with you still (dB; -INF:
## silent).
const TELL_ON_DB := -3.0
const TELL_STILL_DB := -INF
## Lying: once you are this much past lies_coiled_behind_m away (m) it
## slides after you; it lies down within this of it (m).
const SLACK_M := 1.5
const LIE_TOL_M := 1.25
## Going round: a way that comes within this of you (m) passes you.
const PASS_M := 2.5
## The coil it curls into where it lies: this far round, this wide (m).
const CURL_TURNS := 1.2
const CURL_R := 0.55

var phase := "round"
var lie_m := 7.0
var held := 0.0
var armed := false
var replan_t := 0.0
var _plan_at := Vector3.INF
var _you_was := Vector3.INF
var you_speed := 0.0
var curling := false
var rng := RandomNumberGenerator.new()
## Tools: times it lay behind you; the flat distance and angle from where
## you looked when it first lay there; the tick its wind-up began on the
## turn (Boss.clock, -1 none); whether the strike began on the turn (not
## held at your flame first); how it ended ("let_go" walked away from).
var lay_count := 0
var lay_d := -1.0
var lay_angle := -1.0
var turned_at := -1.0
var struck_on_turn := false
var ended_by := ""


## Only after you on its own floor (BossStalk.your_node: not down the stair
## to floor two, design §FM.6), and not while it has let you go
## (Boss.let_go_t: what lets you go doesn't come straight back for you).
func can_enter(boss: Boss) -> bool:
	return BossStalk.may_stalk(boss)


func enter(boss: Boss, _from: String) -> void:
	rng.randomize()
	var lies: Variant = def.get("lies_coiled_behind_m", [5.0, 9.0])
	if lies is Array and (lies as Array).size() == 2:
		lie_m = rng.randf_range(minf(float(lies[0]), float(lies[1])), maxf(float(lies[0]), float(lies[1])))
	elif lies is float or lies is int:
		lie_m = float(lies)
	phase = "round"
	boss.state = "ambush"
	boss.coiling = false
	held = 0.0
	armed = false
	replan_t = 0.0
	_plan_at = Vector3.INF
	_you_was = boss.player.global_position
	you_speed = 0.0
	curling = false
	lay_d = -1.0
	lay_angle = -1.0
	turned_at = -1.0
	struck_on_turn = false
	ended_by = ""


func tick(boss: Boss, delta: float) -> void:
	if done:
		# (In one of its tunnels, on through it till the pool takes over.)
		BossStalk.through_tunnel(boss, delta)
		return
	var pp := boss.player.global_position
	you_speed = lerpf(you_speed, BossStalk.flat_d(pp, _you_was) / maxf(delta, 1e-4), 0.3)
	_you_was = pp
	var d := BossStalk.to_you(boss)
	var delay := boss.sub("torch_delay")
	if boss._torch_lit() and d >= float(delay.get("hang_m", 3.5)):
		held += delta
	if BossStalk.in_reach(boss):
		# You walked back into it.
		boss.begin_strike(held)
		return
	match phase:
		"round":
			_go_round(boss, delta)
		"lie":
			if _turned(boss):
				turned_at = boss.clock
				struck_on_turn = boss.begin_strike(held)
				return
			if d > lie_m + SLACK_M:
				# You moved on: after you, to lie that far behind you again.
				curling = false
				_go_round(boss, delta, true)
			elif curling:
				boss.lift = move_toward(boss.lift, 0.22, delta)
				if boss._advance(boss.num("speed_mps", 2.0), delta):
					curling = false
			else:
				boss.speed = 0.0
				boss._sway = move_toward(boss._sway, 0.0, delta * 2.0)
				boss.lift = move_toward(boss.lift, 0.22, delta * 0.5)
				boss._face(pp, delta)


## Has it lain behind you with your back to it, and you now turned toward
## it (its head within turn_deg of where you look, nothing between)?
func _turned(boss: Boss) -> bool:
	var a := BossStalk.angle_from_look(boss, boss.head)
	if a > BossStalk.BEHIND_DEG:
		armed = true
		return false
	return armed and a <= float(def.get("turn_deg", 50.0)) and boss._clear_to(boss.player.global_position)


## To a spot lie_m behind you through its dark, never past you; there, it
## curls up and lies (`after`: it slid after you as you moved on).
func _go_round(boss: Boss, delta: float, after := false) -> void:
	var pp := boss.player.global_position
	replan_t -= delta
	var there := boss.route_i >= boss.route.size() and not boss._in_tunnel()
	if there and absf(BossStalk.to_you(boss) - lie_m) <= LIE_TOL_M and BossStalk.behind(boss, boss.head):
		boss.speed = 0.0
		_lie(boss, after)
		return
	if replan_t <= 0.0 or BossStalk.flat_d(pp, _plan_at) > BossStalk.REPLAN_MOVE_M or there:
		replan_t = BossStalk.REPLAN_S
		_plan_at = pp
		var goal := BossStalk.behind_spot(boss, lie_m)
		if not BossStalk.go_to(boss, goal) or BossStalk.route_passes_you(boss, PASS_M):
			BossStalk.hold(boss)
	var spd := boss.num("hunt_mps", 4.6) if not after else clampf(you_speed + 1.0, 0.0, boss.num("hunt_mps", 4.6))
	if BossStalk.through_tunnel(boss, delta, spd):
		return
	if boss.route_i >= boss.route.size():
		# Nowhere better to go now: it waits where it is.
		boss.speed = 0.0
		return
	boss._sway = move_toward(boss._sway, 1.0, delta)
	boss.lift = move_toward(boss.lift, 0.08, delta)
	boss._advance(spd, delta)


## Lying behind you: it curls where it is (a turn of a coil, its head on
## top), its dwell counted from the first time it lies here.
func _lie(boss: Boss, after: bool) -> void:
	if phase != "lie":
		phase = "lie"
		lay_count += 1
		lay_d = BossStalk.to_you(boss)
		lay_angle = BossStalk.angle_from_look(boss, boss.head)
		# It lay down behind you, your back to it: turning toward it now is
		# the turn.
		armed = lay_angle > BossStalk.BEHIND_DEG
		boss.renew_dwell(boss.pool.dwell(id) if boss.pool != null else 8.0)
	elif after:
		pass
	# The curl: once round, its head ending on top, facing you.
	var c := boss.base + Vector3(-boss.dir.z, 0.0, boss.dir.x) * CURL_R
	var pts := PackedVector3Array()
	var a0 := atan2(boss.base.z - c.z, boss.base.x - c.x)
	var steps := 10
	for k in range(1, steps + 1):
		var u := float(k) / steps
		var a := a0 - u * CURL_TURNS * TAU
		var r := lerpf(CURL_R, CURL_R * 0.6, u)
		var q := c + Vector3(cos(a), 0.0, sin(a)) * r
		q.y = boss._floor_at(q)
		pts.append(q)
	if boss.nav != null:
		for q in pts:
			if not boss.nav.is_open(boss.nav.cell_of(q)):
				# No room to curl: it lies as it is.
				pts = PackedVector3Array()
				break
	boss._set_route(pts)
	curling = not pts.is_empty()


func exit(boss: Boss) -> void:
	if why == "dwell" and phase == "lie":
		# You kept walking: it lets you go.
		ended_by = "let_go"
		boss.let_go(float(def.get("let_go_s", 8.0)))


## A light caught somewhere, its own node still dark: its way is found
## again at once, and where the rest of it now runs into the light it holds
## where it is meanwhile (never on into the light).
func lights_changed(boss: Boss) -> void:
	replan_t = 0.0
	if not BossStalk.route_dark(boss):
		BossStalk.hold(boss)
		curling = false


## Going round and sliding after you its tell is heard as it moves; lying
## behind you, it sounds as you move on and is silent while you stand.
func tell_db(boss: Boss) -> float:
	if boss.speed > 0.1:
		return 0.0
	if phase == "lie":
		return TELL_ON_DB if you_speed > 0.6 else TELL_STILL_DB
	return -14.0
