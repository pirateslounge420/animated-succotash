extends BossState
## 'observe_then_behind' (design 9 Oct §FM.2, Mike's third: "it studies
## you for a while before it attacks from behind"; queue 66;
## data/boss_pool.json pools.desert.observe_then_behind):
##
##   finding     it comes toward you through its own dark (and its
##               tunnels: uses_tunnels) at up to hunt_mps until you are
##               within observe_m. Its tell, scales dragging on stone, is
##               heard as it moves.
##   observing   for observe_s it follows you at observe_m, outside your
##               torch's circle (BossStalk.torch_circle_m, with your torch
##               lit), along the corridors and through its tunnels, never
##               into a room or stretch you have lit (where you go into the
##               light it waits at the edge of its dark nearest you). It
##               keeps to the middle of observe_m: it slows as you stop,
##               comes on as you go, and backs away through its dark if you
##               come at it. Come inside observe_m and stay there
##               (FOUND_S), and it has been found out: it strikes if you
##               are within its reach, else the state is over. Out of its
##               senses (your flame, a sprint, you close by) for
##               gives_up.out_of_sight_s, it has lost you: over (that
##               clock waits while it is in its tunnels).
##   behind you  then (observe_s gone, or its dwell nearly out) it goes
##               round behind you (then: circle_to_behind), coming on only
##               while it is behind you and holding still while you look
##               its way, for at most behind_s; at its strike's distance it
##               strikes with the strike as built (Boss.begin_strike: tell,
##               wind-up and recovery unchanged). The time it spent lying
##               back beyond your torch's bright circle (torch_delay.hang_m)
##               with your torch lit is your flame's delay already spent
##               (begin_strike's held_s): watched that long, it holds off no
##               more.
##   and         it comes only with you on its own floor and not while it
##               has let you go (BossStalk.may_stalk); a light that catches
##               across its way, it holds and finds another
##               (lights_changed).

## Found out: inside observe_m this long (s).
const FOUND_S := 1.5

var phase := "find"
var observe_left := 0.0
var held := 0.0
var unseen := 0.0
var close_t := 0.0
var replan_t := 0.0
var _plan_at := Vector3.INF
var _away := false
var _you_was := Vector3.INF
var you_speed := 0.0
var rng := RandomNumberGenerator.new()
## Tools: seconds spent observing, the nearest and farthest it was from you
## then (flat), the nearest it was to your torch's circle then; how it
## ended ("lost", "found"; "" when the strike or its dwell did); the flat
## angle from where you looked to it when it struck (-1 none yet).
var observed := 0.0
var d_min := INF
var d_max := -INF
var strike_angle := -1.0
var ended_by := ""


## Only after you on its own floor (BossStalk.your_node: not down the stair
## to floor two, design §FM.6), and not while it has let you go
## (Boss.let_go_t, coil_ambush walked away from).
func can_enter(boss: Boss) -> bool:
	return BossStalk.may_stalk(boss)


func enter(boss: Boss, _from: String) -> void:
	rng.randomize()
	phase = "find"
	boss.state = "observe"
	boss.coiling = false
	observe_left = _range(def.get("observe_s", [10.0, 30.0]), 10.0, 30.0)
	held = 0.0
	unseen = 0.0
	close_t = 0.0
	replan_t = 0.0
	_plan_at = Vector3.INF
	_away = false
	_you_was = boss.player.global_position
	you_speed = 0.0
	observed = 0.0
	d_min = INF
	d_max = -INF
	strike_angle = -1.0
	ended_by = ""


func _range(v: Variant, lo: float, hi: float) -> float:
	if v is Array and (v as Array).size() == 2:
		return rng.randf_range(minf(float(v[0]), float(v[1])), maxf(float(v[0]), float(v[1])))
	if v is float or v is int:
		return float(v)
	return rng.randf_range(lo, hi)


## observe_m as it keeps it now: never inside your torch's circle while
## your torch is lit.
func band(boss: Boss) -> Vector2:
	var v: Variant = def.get("observe_m", [10.0, 18.0])
	var lo := 10.0
	var hi := 18.0
	if v is Array and (v as Array).size() == 2:
		lo = float(v[0])
		hi = float(v[1])
	if boss._torch_lit():
		lo = maxf(lo, BossStalk.torch_circle_m() + 0.5)
	return Vector2(lo, maxf(hi, lo + 2.0))


func tick(boss: Boss, delta: float) -> void:
	if done:
		# (In one of its tunnels, on through it till the pool takes over.)
		BossStalk.through_tunnel(boss, delta)
		return
	var pp := boss.player.global_position
	you_speed = lerpf(you_speed, BossStalk.flat_d(pp, _you_was) / maxf(delta, 1e-4), 0.3)
	_you_was = pp
	var d := BossStalk.to_you(boss)
	var bd := band(boss)
	var delay := boss.sub("torch_delay")
	var hang_m := float(delay.get("hang_m", 3.5))
	if boss._torch_lit() and d >= hang_m:
		held += delta
	if BossStalk.senses_you(boss):
		unseen = 0.0
	elif not boss._in_tunnel():
		# (In its tunnels it senses nothing, but knows where it is going.)
		unseen += delta
		if unseen >= float(boss.sub("gives_up").get("out_of_sight_s", 6.0)):
			ended_by = "lost"
			boss.end_state()
			return
	match phase:
		"find":
			_follow(boss, delta, (bd.x + bd.y) * 0.5)
			if d <= bd.y:
				phase = "observe"
		"observe":
			observed += delta
			d_min = minf(d_min, d)
			d_max = maxf(d_max, d)
			observe_left -= delta
			if d < bd.x - 0.5:
				close_t += delta
				if close_t >= FOUND_S:
					if BossStalk.in_reach(boss):
						boss.begin_strike(held)
					else:
						ended_by = "found"
						boss.end_state()
					return
			else:
				close_t = 0.0
			if d < bd.x:
				_back_off(boss, delta)
			else:
				_follow(boss, delta, (bd.x + bd.y) * 0.5)
			if observe_left <= 0.0 or boss._dwell_left <= delta * 1.5:
				phase = "behind"
				boss.state = "behind"
				boss.renew_dwell(float(def.get("behind_s", 12.0)))
				replan_t = 0.0
		"behind":
			var holding := boss._torch_lit() and not boss.struck and held < float(delay.get("hang_s", 4.0))
			var stop := hang_m if holding else boss.strike.reach_m * 0.8
			var at_back := BossStalk.behind(boss, boss.head)
			if at_back and d <= stop + 0.15 and absf(pp.y - boss.base.y) < 1.5 and boss._clear_to(pp):
				strike_angle = BossStalk.angle_from_look(boss, boss.head)
				boss.begin_strike(held)
				return
			if at_back:
				_follow(boss, delta, stop, true)
			else:
				# You look its way: it holds still where it is.
				boss.speed = 0.0
				boss._face(pp, delta)


## On after you through its dark, keeping `keep` m from you (flat): faster
## as you draw away, slower as you stop, at most hunt_mps. `close`: all the
## way in (going round behind you), its way found again more often.
func _follow(boss: Boss, delta: float, keep: float, close := false) -> void:
	var pp := boss.player.global_position
	replan_t -= delta
	if _away or replan_t <= 0.0 or BossStalk.flat_d(pp, _plan_at) > BossStalk.REPLAN_MOVE_M or boss.route_i >= boss.route.size():
		_away = false
		replan_t = BossStalk.REPLAN_S * (0.5 if close else 1.0)
		_plan_at = pp
		if not BossStalk.go_to(boss, BossStalk.dark_toward(boss, pp)):
			BossStalk.hold(boss)
	var d := BossStalk.to_you(boss)
	var spd := clampf(you_speed + (d - keep) * 1.5, 0.0, boss.num("hunt_mps", 4.6))
	if BossStalk.through_tunnel(boss, delta, spd):
		return
	if spd < 0.05 or boss.route_i >= boss.route.size():
		boss.speed = 0.0
		boss._sway = move_toward(boss._sway, 0.3, delta)
		boss._face(pp, delta)
		return
	boss._sway = move_toward(boss._sway, 1.0, delta)
	boss.lift = move_toward(boss.lift, 0.0 if boss._in_tunnel() else 0.1, delta)
	boss._advance(spd, delta)


## Away from you through its dark (you came at it), at up to hunt_mps; held
## where it is when it is cornered.
func _back_off(boss: Boss, delta: float) -> void:
	replan_t -= delta
	if not _away or replan_t <= 0.0 or boss.route_i >= boss.route.size():
		_away = true
		replan_t = BossStalk.REPLAN_S
		if not BossStalk.go_to(boss, BossStalk.away_from_you(boss)):
			BossStalk.hold(boss)
	if BossStalk.through_tunnel(boss, delta, boss.num("hunt_mps", 4.6)):
		return
	if boss.route_i >= boss.route.size():
		boss.speed = 0.0
		boss._face(boss.player.global_position, delta)
		return
	boss._sway = move_toward(boss._sway, 1.0, delta)
	boss._advance(boss.num("hunt_mps", 4.6), delta)


## A light caught somewhere, its own node still dark: its way is found
## again at once, and where the rest of it now runs into the light it holds
## where it is meanwhile (never on into the light).
func lights_changed(boss: Boss) -> void:
	replan_t = 0.0
	if not BossStalk.route_dark(boss):
		BossStalk.hold(boss)


func tell_db(boss: Boss) -> float:
	return 0.0 if boss.speed > 0.1 else -14.0
