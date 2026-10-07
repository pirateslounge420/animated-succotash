class_name CreatureStrike
extends Node3D
## A creature's strike, and the torch that staggers it (design 6 Oct
## §FA.1, §FA.2; data/torch.json stagger and the creature's own `strike`
## block in bosses.json or residents.json). General: any creature with a
## strike block carries one of these as a child, placed where a swing has
## to reach (its head), and its own algorithm says when to strike
## (begin(), or `armed` with a `target` in reach). A strike has two parts
## (§FA.1), then a draw back:
##
##   wind_up  strike.wind_up_s: its own tell (§FA.2), never a shared cue:
##            a pose its sprite shows (pose() "wind_up") and its own
##            positional sound (strike.sound, a SoundSynth voice) from the
##            wind-up's first frame, so an ambush is heard before it is
##            seen. A swing of a lit torch (stagger.lit_only) that reaches
##            it now staggers it: the strike is broken, it reels back
##            strike.reel_m over stagger.reel_s, and it can't be staggered
##            again for stagger.cooldown_s. No damage, ever (stagger.damage
##            0): nothing dies to a torch.
##   strike   strike.strike_s, committed: its active frames. A swing does
##            nothing to it now (stagger.committed_strike_goes_through).
##            At its end the hit lands, one hit through the player's
##            take_hit (Harm counts it, i-frames and all, §EA, §EC), if you
##            are still within strike.reach_m of where it struck from
##            (`origin`, its body, not its lunging head) with nothing solid
##            between; stepped out of reach in time, it misses.
##   recover  strike.recover_s: it draws back before it can strike again.
##
## Any swing that lands on a creature, staggering it or not, is as loud as
## a sprint for anything that hears (stagger.noise, §DF). The torch asks
## swing_lands() at the top of its swing (Torch).

static var D: Dictionary = Tuning.table("torch").get("stagger", {})
## Every strike in play (the torch's swing looks through them).
static var all: Array = []

## What a strike block may leave out (residents.json lists only reach_m
## and wind_up_s): the committed strike, the draw back after it, how far a
## stagger throws it back, and how big a target its head is for a swing.
const DEFAULTS := {"reach_m": 1.6, "wind_up_s": 0.7, "strike_s": 0.2, "recover_s": 0.8, "reel_m": 1.0, "body_r": 0.4}
## A swing meets a creature in front of you: within this angle of where
## you look (flat), or from any side closer than CLOSE_M.
const SWING_CONE_DEG := 70.0
const CLOSE_M := 0.8

signal wound_up
signal struck(landed: bool)
signal staggered(from_pos: Vector3)

## Its name for the log's cause of death ("creature:<who>").
var who := "something"
var reach_m := 1.6
var wind_up_s := 0.7
var strike_s := 0.2
var recover_s := 0.8
var reel_m := 1.0
var body_r := 0.4
## Its wind-up's sound (a SoundSynth voice; "" for none).
var sound := ""
## What it strikes at (the player), and whether its algorithm wants it to
## strike whenever that is in reach: the creature sets both.
var target: Node3D
var armed := false
## Where its reach is measured from (scene; flat): its body where it
## strikes from, for a creature whose head (this node) lunges out of it, as
## the snake's does. Unset (INF), this node's own place.
var origin := Vector3.INF
## What a landed strike does, Callable(target) (unset: one hit through the
## player's take_hit).
var on_hit := Callable()
## ready, wind_up, strike, recover or reel; seconds into it.
var state := "ready"
var t := 0.0
## Seconds before it can be staggered again.
var cooldown_left := 0.0
## Where the swing that staggered it came from, and how much of its reel
## the creature has taken (take_reel; -1 when there is none to take).
var reel_from := Vector3.ZERO
var _reel_taken := -1.0
var _tell: AudioStreamPlayer3D
## Tallies and stamps (tools): wind-ups begun, strikes committed, strikes
## that reached you, staggers, swings that met it; the physics frame the
## last wind-up began, the frame its sound started, and its wind-up's
## share when the last swing met it.
var wind_ups := 0
var strikes := 0
var landed := 0
var staggers := 0
var swings_met := 0
var wind_up_frame := -1
var tell_frame := -1
var met_at_share := -1.0
## The physics frames of the last stagger and of the end of its reel.
var stagger_frame := -1
var reel_end_frame := -1


## Read `strike_block` (bosses.json / residents.json) for the creature
## `creature`.
func setup(strike_block: Dictionary, creature: String) -> void:
	who = creature
	reach_m = float(strike_block.get("reach_m", DEFAULTS.reach_m))
	wind_up_s = maxf(float(strike_block.get("wind_up_s", DEFAULTS.wind_up_s)), 0.05)
	strike_s = maxf(float(strike_block.get("strike_s", DEFAULTS.strike_s)), 0.0)
	recover_s = maxf(float(strike_block.get("recover_s", DEFAULTS.recover_s)), 0.0)
	reel_m = float(strike_block.get("reel_m", DEFAULTS.reel_m))
	body_r = float(strike_block.get("body_r", DEFAULTS.body_r))
	sound = str(strike_block.get("sound", ""))
	if _tell == null:
		_tell = Audio3D.make("strike_tell", self, "Tell")


func _enter_tree() -> void:
	if not all.has(self):
		all.append(self)


func _exit_tree() -> void:
	all.erase(self)


static func reel_s() -> float:
	return float(D.get("reel_s", 0.8))


## Its algorithm holds still while one is under way.
func busy() -> bool:
	return state != "ready"


func winding_up() -> bool:
	return state == "wind_up"


func committed() -> bool:
	return state == "strike"


func reeling() -> bool:
	return state == "reel"


## What its sprite shows: "" (as it is), "wind_up" (its tell), "strike"
## (the committed strike), "recover" or "reel".
func pose() -> String:
	return "" if state == "ready" else state


## How far into that pose, 0-1.
func pose_k() -> float:
	match state:
		"wind_up":
			return clampf(t / wind_up_s, 0.0, 1.0)
		"strike":
			return clampf(t / maxf(strike_s, 0.001), 0.0, 1.0)
		"recover":
			return clampf(t / maxf(recover_s, 0.001), 0.0, 1.0)
		"reel":
			return clampf(t / maxf(reel_s(), 0.001), 0.0, 1.0)
	return 0.0


## Where its reach is measured from: `origin`, else this node.
func reach_from() -> Vector3:
	return origin if origin.is_finite() else global_position


## `pos` within its reach (flat; the crawler's up is +y).
func reaches(pos: Vector3) -> bool:
	var d := pos - reach_from()
	return Vector2(d.x, d.z).length() <= reach_m


## Start a strike: the wind-up, with its sound from this frame. False
## unless it is ready.
func begin() -> bool:
	if state != "ready" or not is_inside_tree():
		return false
	state = "wind_up"
	t = 0.0
	wind_ups += 1
	wind_up_frame = Engine.get_physics_frames()
	if sound != "" and _tell != null:
		_tell.stream = SoundSynth.stream(sound, randi())
		Audio3D.play(_tell)
		tell_frame = Engine.get_physics_frames()
	wound_up.emit()
	return true


## A swing met it (swing_lands()). A lit torch (stagger.lit_only) in its
## wind-up, outside the cooldown, staggers it: true when it did. In the
## committed strike, or at any other time, it does nothing.
func stagger(from_pos: Vector3, lit: bool) -> bool:
	swings_met += 1
	met_at_share = t / wind_up_s if state == "wind_up" else -1.0
	if str(D.get("on", "wind_up")) != state:
		return false
	if bool(D.get("lit_only", true)) and not lit:
		return false
	if cooldown_left > 0.0:
		return false
	state = "reel"
	t = 0.0
	cooldown_left = float(D.get("cooldown_s", 3.0))
	staggers += 1
	stagger_frame = Engine.get_physics_frames()
	reel_from = from_pos
	_reel_taken = 0.0
	# Its tell broken off with its strike.
	if _tell != null:
		_tell.stop()
	staggered.emit(from_pos)
	return true


## Break off whatever is under way (it leaves, it is driven home).
func cancel() -> void:
	state = "ready"
	t = 0.0
	_reel_taken = -1.0
	if _tell != null:
		_tell.stop()


## The reel's push not yet taken (scene metres, flat, away from the swing):
## the creature moves itself by it each frame it reels, by its own rules
## (along its corridor, through its ground). The push eases out over
## stagger.reel_s; with no reel under way or left to take, nothing.
func take_reel() -> Vector3:
	if _reel_taken < 0.0:
		return Vector3.ZERO
	var u := clampf(t / maxf(reel_s(), 0.001), 0.0, 1.0) if state == "reel" else 1.0
	var want := reel_m * (1.0 - (1.0 - u) * (1.0 - u))
	var step := maxf(want - _reel_taken, 0.0)
	# All of it taken: nothing more until the next stagger.
	_reel_taken = want if u < 1.0 else -1.0
	var away := global_position - reel_from
	away.y = 0.0
	if away.length() < 0.01:
		away = global_basis.z
		away.y = 0.0
	return away.normalized() * step


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	match state:
		"ready":
			if armed and target != null and is_instance_valid(target) and reaches(target.global_position):
				begin()
		"wind_up":
			t += delta
			if t >= wind_up_s:
				# Committed (§FA.1): its tell stops as it goes.
				state = "strike"
				t -= wind_up_s
				strikes += 1
				if _tell != null:
					_tell.stop()
				_strike_end_check()
		"strike":
			t += delta
			_strike_end_check()
		"recover":
			t += delta
			if t >= recover_s:
				state = "ready"
				t = 0.0
		"reel":
			t += delta
			if t >= reel_s():
				state = "ready"
				t = 0.0
				reel_end_frame = Engine.get_physics_frames()


## The committed strike's end: the hit lands if you are still in reach
## with nothing solid between.
func _strike_end_check() -> void:
	if state != "strike" or t < strike_s:
		return
	state = "recover"
	t -= strike_s
	var hit := target != null and is_instance_valid(target) and reaches(target.global_position) \
		and _clear(global_position, _chest(target), [_rid(target)])
	if hit:
		landed += 1
		if on_hit.is_valid():
			on_hit.call(target)
		elif target is PlanetPlayer:
			var p := target as PlanetPlayer
			p.death_cause = "creature:" + who
			p.take_hit(1.0, global_position)
	struck.emit(hit)


static func _chest(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * 1.0


static func _rid(n: Node3D) -> RID:
	return (n as CollisionObject3D).get_rid() if n is CollisionObject3D else RID()


## Nothing of the world (PropCollision.WORLD_LAYER: the tomb's stone)
## between `a` and `b`.
func _clear(a: Vector3, b: Vector3, exclude: Array) -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(a, b, PropCollision.WORLD_LAYER)
	var ex: Array[RID] = []
	for r in exclude:
		if r is RID and (r as RID).is_valid():
			ex.append(r)
	q.exclude = ex
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return h.is_empty()


## How loud a swing that lands is (stagger.noise): "as_sprint" is the
## sprint's own level, 1 (CrawlerPlayer.moving_state); a number is itself.
static func noise_level() -> float:
	var n: Variant = D.get("noise", "as_sprint")
	return float(n) if n is float or n is int else 1.0


## The torch's swing meets what it reaches (Torch, at the top of the
## swing): the nearest strike within `reach` of the swing's point `at`,
## in front of `player` and with nothing solid between. That swing is as
## loud as a sprint (stagger.noise), and with a lit torch (`lit`) in the
## creature's wind-up it staggers it. Returns "staggered", "landed" (it met
## a creature and did nothing to it) or "" (it met none).
static func swing_lands(player: PlanetPlayer, at: Vector3, reach: float, lit: bool) -> String:
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD
	var best: CreatureStrike = null
	var best_d := INF
	for s in all:
		if not is_instance_valid(s) or not (s as CreatureStrike).is_inside_tree():
			continue
		var cs := s as CreatureStrike
		var d := at.distance_to(cs.global_position) - cs.body_r
		if d > reach or d >= best_d:
			continue
		var to := cs.global_position - player.global_position
		to.y = 0.0
		if to.length() > CLOSE_M and rad_to_deg(fwd.angle_to(to.normalized())) > SWING_CONE_DEG:
			continue
		# Nothing solid between you and the near side of its head (a head
		# drawn back against stone is still there to hit).
		var from := player.reach_from()
		var near := cs.global_position + (from - cs.global_position).normalized() * minf(cs.body_r, from.distance_to(cs.global_position) * 0.5)
		if not cs._clear(from, near, [player.get_rid()]):
			continue
		best = cs
		best_d = d
	if best == null:
		return ""
	player.make_noise(noise_level())
	return "staggered" if best.stagger(player.global_position, lit) else "landed"
