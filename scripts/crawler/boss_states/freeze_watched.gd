extends BossState
## 'freeze_watched' (design 9 Oct §FM.2, Mike's first: "it goes still when
## you look at it from far away", made "a little bit more camouflaged than
## it is now", never invisible, which is saved for another boss; queue 66;
## data/boss_pool.json pools.desert.freeze_watched, camouflage):
##
##   its needs   you look at it from far off (BossStalk.watched: all of it,
##               its head and every length of its body, at least from_m[0]
##               from you; its head or a length of its body inside look_deg
##               of your view axis within from_m[1], seen in your torch's
##               light, a fire's light where it lies, or your half-dark
##               sight), in its own dark (never in a room or stretch you
##               have lit, never on the way out, never in its tunnels). It
##               may cut in the moment you first catch sight of it
##               (BossState.cuts_in): weighed against the state in charge
##               by their weights, so sometimes it freezes and sometimes it
##               doesn't.
##   frozen      it stops dead where it is and lies still, its head sinking
##               to the stone, silent; its sprites' colours ease toward the
##               stone it lies on (Boss.camo_want, its blend or
##               camouflage.blend, never above camouflage.max_blend): their
##               texture and value only, never their alpha, so it is hard
##               to spot and never gone.
##   it ends     when you close inside close_m (of any of it, as from_m
##               counts: its nearest part, BossStalk.nearest_part_m), when
##               you have looked away for look_away_s, or when its dwell
##               runs out: then the pool draws the next state, with no tell
##               (no sound, nothing shown): it simply does whatever comes
##               next.

## Why it ended itself ("close", "look_away"; "" not yet), how long you
## have looked away, where it stopped dead (tools).
var ended_by := ""
var away_t := 0.0
var held_at := Vector3.ZERO
## Tools: the point you saw it by when it froze, and times it froze.
var seen_by: Variant = null
var entered := 0


func cuts_in() -> bool:
	return true


func can_enter(boss: Boss) -> bool:
	if boss._in_tunnel() or boss.node < 0 or not boss.ground.is_ground(boss.node):
		return false
	if boss.on_way_out(boss.base):
		return false
	return BossStalk.watched(boss, def)


func enter(boss: Boss, _from: String) -> void:
	entered += 1
	ended_by = ""
	away_t = 0.0
	seen_by = BossStalk.watched_point(boss, def)
	held_at = boss.base
	boss.state = "freeze"
	boss.coiling = false
	boss.speed = 0.0
	# Where it was going, forgotten: it stops dead.
	boss._set_route(PackedVector3Array())
	boss.camo_want = blend()


## Its camouflage: its own blend, else camouflage.blend; never above
## camouflage.max_blend (Boss keeps that too).
func blend() -> float:
	var camo: Dictionary = BossPool.DATA.get("camouflage", {})
	var k := float(def.get("blend", camo.get("blend", 0.3)))
	return clampf(k, 0.0, float(camo.get("max_blend", 0.5)))


func tick(boss: Boss, delta: float) -> void:
	boss.speed = 0.0
	boss.coiling = false
	boss._sway = move_toward(boss._sway, 0.0, delta * 3.0)
	boss.lift = move_toward(boss.lift, 0.03, delta * 0.5)
	boss.lunge = move_toward(boss.lunge, 0.0, delta)
	boss.mouth_open = false
	if done:
		return
	if BossStalk.nearest_part_m(boss) < float(def.get("close_m", 7.0)):
		ended_by = "close"
		boss.end_state()
		return
	if BossStalk.watched(boss, def):
		away_t = 0.0
	else:
		away_t += delta
		if away_t >= float(def.get("look_away_s", 3.0)):
			ended_by = "look_away"
			boss.end_state()


func exit(boss: Boss) -> void:
	boss.camo_want = 0.0


## Frozen: silent.
func tell_db(_boss: Boss) -> float:
	return -INF
