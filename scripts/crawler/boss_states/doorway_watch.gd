extends BossState
## 'doorway_watch' (design 9 Oct §FM.2, Mike's second: "it sits in
## doorways and watches you"; queue 66; data/boss_pool.json
## pools.desert.doorway_watch):
##
##   where       the nearest doorway of an unlit room on its rounds that
##               you are not in (BossStalk.pick_doorway): a door of a dark
##               room it can reach through its dark, never onto the way out
##               or into the hearth room. It goes there through its dark
##               (and its tunnels) at its rounds' pace, into the room and
##               up to the doorway from deep inside it, so its body lies
##               back into the room behind its head.
##   watching    it lies still just inside the room with its head in the
##               gap (head_m: how far its front reaches from the room's
##               side of the wall, its head's middle kept in the wall's
##               thickness), for its dwell, its head turned toward you
##               while you are out in front of it.
##   it ends     when that room is lit it leaves for the dark, as the boss
##               rule says (Boss: a room lit round a state ends it; a light
##               that catches across its way there sends it round by
##               another dark way, or ends the watch); if you come into
##               that room the watch is over; if you come within its
##               strike's reach, on its way there or at its doorway, it
##               strikes, with the strike as built (your lit torch holds it
##               off first, then its tell and its wind-up:
##               Boss.begin_strike).

## Its head turns toward you at most this far either way of straight out
## through the doorway (deg), so it stays in the gap.
const LOOK_DEG := 35.0

var spot: Dictionary = {}
var arrived := false
## Tools: times it lay in a doorway, and the doorways it chose.
var settled := 0
var doors: Array = []


func can_enter(boss: Boss) -> bool:
	if boss._in_tunnel():
		return false
	return not BossStalk.pick_doorway(boss, def, false).is_empty()


func enter(boss: Boss, _from: String) -> void:
	arrived = false
	spot = BossStalk.pick_doorway(boss, def)
	if spot.is_empty() or not _plan(boss):
		spot = {}
		boss.end_state()
		return
	doors.append(int(spot.door))
	boss.state = "doorway"
	boss.coiling = false


## Its way to the doorway, set as its route: through its dark (and its
## tunnels) deep into the room, then on to the floor straight in from the
## doorway and up to it, so its body lies back into the room. False when
## there is none.
func _plan(boss: Boss) -> bool:
	if not BossStalk.go_to(boss, {"node": int(spot.node), "pos": spot.deep}):
		return false
	var pts := boss.route
	var hid := boss.route_hidden
	boss._floor_leg(pts, hid, spot.deep, spot.inner)
	boss._floor_leg(pts, hid, spot.inner, spot.stand)
	boss._set_route(pts, hid)
	return true


## A light caught on its way there, its room still dark (its own node lit,
## the boss leaves as built): where the rest of its way now runs into the
## light, it finds another through its dark, or the watch is over and it
## holds where it is (never on into the light).
func lights_changed(boss: Boss) -> void:
	if spot.is_empty() or arrived or done or not boss.ground.is_ground(int(spot.node)):
		return
	if BossStalk.route_dark(boss):
		return
	if not _plan(boss):
		BossStalk.hold(boss)
		boss.end_state()


func tick(boss: Boss, delta: float) -> void:
	if spot.is_empty() or done:
		# (In one of its tunnels, on through it till the pool takes over.)
		BossStalk.through_tunnel(boss, delta)
		return
	if not boss.ground.is_ground(int(spot.node)) or BossStalk.your_node(boss) == int(spot.node):
		# Its room lit before it got there (it leaves for the dark as the
		# boss rule says, once it is in it: Boss), or you went into it.
		boss.end_state()
		return
	if BossStalk.in_reach(boss):
		# You came within its reach (on its way there, or at its doorway):
		# the strike as built.
		boss.begin_strike()
		return
	if not arrived:
		# Its slither eases out over its last steps, so it lies straight.
		var settling := boss._route_left() < 1.5 and not boss._in_tunnel()
		boss._sway = move_toward(boss._sway, 0.0 if settling else 1.0, delta * (2.5 if settling else 1.0))
		boss.lift = move_toward(boss.lift, 0.0 if boss._in_tunnel() else 0.08, delta)
		if boss._advance(boss.num("speed_mps", 2.0), delta):
			arrived = true
			settled += 1
			boss.head = boss.base
			boss._push_trail(boss.head)
		return
	# Lying in the doorway, watching: its head turned toward you while you
	# are out in front of it (LOOK_DEG either way of straight out), reached
	# into the gap.
	boss.speed = 0.0
	boss._sway = 0.0
	boss.lift = move_toward(boss.lift, 0.18, delta * 0.6)
	var out: Vector3 = spot.out
	var look := out
	var to := boss.player.global_position - boss.base
	to.y = 0.0
	if to.length() > 0.5:
		var a := out.signed_angle_to(to.normalized(), Vector3.UP)
		if absf(a) < deg_to_rad(80.0):
			look = out.rotated(Vector3.UP, clampf(a, -deg_to_rad(LOOK_DEG), deg_to_rad(LOOK_DEG)))
	boss.dir = Boss._turn(boss.dir, look, clampf(delta * 3.0, 0.0, 1.0))
	boss.lunge = move_toward(boss.lunge, float(spot.lunge), delta * 1.5)


## Where its head lies as drawn, flat on its floor (tools).
func head_point(boss: Boss) -> Vector3:
	return boss.head + boss.dir * boss.lunge


## Is it lying in its doorway with its head in the gap (tools)?
func in_doorway(boss: Boss) -> bool:
	return arrived and not spot.is_empty() and BossStalk.in_gap(spot, head_point(boss))


func tell_db(boss: Boss) -> float:
	return 0.0 if boss.speed > 0.1 else -14.0
