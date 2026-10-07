class_name Resident
extends Node3D
## One of the things that live in a ruin's dark (design 6 Oct §FE;
## residents.json creatures, Residents runs them): its own algorithm from
## its creature's row. The first is the tomb's skeleton. It was a waker
## (Mike, 6 Oct: "if you get too close to them they come out of the wall or
## out of the graves"); since Mike's note of 7 Oct it is a creeper, Mario's
## Boos ("they might not activate until you pass them once and only move
## toward you slowly when your back is turned so you never see them moving
## unless they get right up on you"; its creature's creep block):
##
##   rest      lying still in its niche or grave: set dressing. Your head
##             within creep.arms_m of its head, with a clear line to it,
##             arms it, silently: nothing you can see or hear changes.
##             Armed, it climbs out the first moment you can't see it (you
##             turned away, or walked on past). A waker (no creep block)
##             wakes as you come within its wakes_m;
##   rising    over rise_s, climbing out to the floor before its resting
##             place, its near tell (bone grinding on stone) heard as it
##             starts to move, so you hear it behind you; from now it hunts
##             you (its Pursuit, prompt 56: Harm counts it as pursuing you,
##             §FD);
##   hunt      creeping (creep.creep_mps, slow; a waker walks, walk_mps; by
##             TombNav) to where it last sensed you, its bone steps heard as
##             it goes: seen (notice.sees_you_m, a clear line from its eyes
##             to your head: cover hides you, §FC.2), your lit torch's flame
##             or the stone it lights seen (sees_flame_m), or heard
##             (hears_step_m by your noise: your steps, a swing that lands);
##             in reach of you, sensing you there, it strikes;
##   striking  its strike (prompt 57's CreatureStrike, a child at its head
##             while it is up): the wind-up, wind_up_s, the jaw dropping
##             open on its sprite and the jaw's creak and knock its own
##             sound (§FA.2's tell; strike.sound); a lit torch swung into it
##             now staggers it (§FA.1: it reels back strike.reel_m, no
##             damage, ever). Then the committed strike, strike_s, and the
##             hit lands at its end if you are still in reach with nothing
##             solid between (one hit, Harm); then recover_s;
##   return    it has given you up by its own gives_up (Pursuit:
##             distance_m, out_of_sight_s, hide, torch_doused): it walks
##             (walk_mps) back to its place (sensing you again on the way,
##             it hunts again);
##   lying     climbing back in over rise_s, then rest (to be armed again
##             by your passing).
##
## Unseen only (Mike's 7 Oct note; Residents.watched): a creeper you can see
## holds dead still: no step, no turn, no change of pose, and its clock
## stopped, so a climb or a creep goes on from where it froze. You see it
## when any of its view points (its feet, middle and head as it lies,
## climbs or stands, and its middle creep.side_m to either side) is in your
## frame or within creep.view_margin of its edge, within creep.seen_m, with
## nothing of the stone between; the dark doesn't hide it. A step that
## would leave it where you can see it is undone, so it stops just short of
## your sight. Watched, its mind goes on: it senses you and keeps its chase
## (stare at it within its sight and it keeps you, §FD), and the light's
## rules still say where it may go; it goes only once you look away. In
## plain view all the same: its strike (the wind-up, the committed strike,
## the recovery, a stagger's reel, a dark pocket's lunge: §FA.1, §FF.2);
## up and about, anything within strike.reach_m of you (it got right up on
## you); and the floor's last light, when the ones you can see hurry back
## into the stone (§FF.2's reveal, the one exception).
##
## Cleared by light (design §FF.2; Residents keeps the light, 49's graph):
##
##   the light   it keeps to the dark unless it is chasing you (§FD: its
##               strike has landed): hunting you, it stops at the edge of
##               its dark and watches you in the light for
##               rules.edge_watch_s (watched or not), then gives you up; no
##               strike reaches you in the light until it has hit you.
##               Given up, it goes home only by a way through the dark to a
##               resting place still dark, else it hangs back in the dark;
##   leave       the node it rests or stands in relit (or it gave you up in
##               the light): it climbs out if it was resting (its near tell)
##               and goes for the nearest dark (BossGround.nearest_dark),
##               fast enough to be out of the light within
##               rules.back_to_dark_s (Pursuit.back_to_dark_mps) of your
##               not watching it: watched, a creeper stands where it is,
##               even in the light;
##   below       cut off from any dark it could walk to (the lit hearth room
##               between the branches), it goes into the stone through the
##               nearest hole as it would at the last light (seen going if
##               you can see it; a creeper you can see stands where it is
##               until you look away, then is into the stone at once), and
##               rules.below_s later comes up in the dark nearest it, out of
##               your sight, to hang back there: the floor's residents end
##               up in what dark is left;
##   lurk        hanging back in a dark pocket (Residents.pocket_spot),
##               facing the way the light comes in, no one's pursuer; come
##               within rules.pocket_counterattack_m where it can sense you
##               and it strikes, a normal strike with its wind-up (so a
##               stagger works), lunging in at rules.pocket_lunge_mps to
##               bring you into its reach; then it hunts you;
##   retreat     the floor's last light caught (retreat_to): seen, it
##               hurries (rules.retreat_mps) to its niche or the nearest
##               hole, climbs in and sinks back into the stone
##               (rules.withdraw_s); unseen, or out of your sight, or past
##               crawler.json cleared.retreat_seen_s, it is gone at once;
##   gone        for good: off the roll and freed.
##
## It is a sprite (ResidentSprite) with no body: nothing walks into it, it
## walks through nothing (its path keeps it to the floor).
##
## Fire pots (§FA.3; FirePots' fire-target socket, queue 60): a pot's
## burst within its splash, the tar stuck on it and a burning patch it
## stands in burn its fire_hp down (times its oil_scale); burnt while it
## lies at rest, it wakes and climbs out burning (a creeper you are
## watching lies there burning until you look away); at 0 it burns out and
## is gone for good, the chase with it. Awake, it sees a pot's lit wick as
## your flame out to gives_away.flare_seen_m, and hears a burst within
## burst_heard_m (Residents.sense).

enum { REST, RISING, HUNT, STRIKING, RETURN, LYING, LEAVE, LURK, RETREAT, GONE, BELOW }
const STATE_NAMES := ["rest", "rising", "hunt", "striking", "return", "lying", "leave", "lurk", "retreat", "gone", "below"]
## Leaving the light, never faster than this (m/s), however far the dark.
const LEAVE_MAX_MPS := 6.0
## How far off it can still be seen going (m), in a lit floor.
const SEEN_M := 30.0
## Climbing back into a hole takes this share of its rise_s (it hurries).
const CLIMB_IN_K := 0.75
## How often it senses you (s), and how often it looks for a new way.
const SENSE_S := 0.15
const REPATH_S := 0.5
## How far each walking frame carries it (m), and between its steps.
const STRIDE_M := 0.32
const STEP_M := 0.7
## Its view points standing (m over its feet; Residents.watched): its feet,
## and its head (the top of its 1.68 m frame).
const VIEW_FEET_M := 0.1
const VIEW_HEAD_M := 1.6
## Its sprite's pose for each part of a strike (CreatureStrike.pose()).
const STRIKE_POSES := {"wind_up": "wind_up", "strike": "strike", "recover": "rise_c", "reel": "reel"}

var residents: Residents
var kind := "skeleton"
var def: Dictionary
## Its resting place (TombKit.rest_place).
var place: Dictionary
var state := REST
var t := 0.0
var yaw := 0.0
var sprite: ResidentSprite
var voice: AudioStreamPlayer3D
var feet: AudioStreamPlayer3D
## Its strike (CreatureStrike), only while it is up: at rest it is set
## dressing, and no swing meets it.
var strike: CreatureStrike
## Its chase (Pursuit): on from when it wakes until it gives you up.
var pursuit: Pursuit
## What fire it has left (residents.json fire_hp; FirePots burns it down).
var fire_hp := 0.0
## Its residents.json key, for the fire pots' oil_scale (FirePots).
var fire_creature: String:
	get:
		return kind
## The last fire pot burst it listened for (FirePots.bursts_since).
var burst_id := 0
## Where it last sensed you, and by what ("sight", "flame", "glow",
## "hearing", "touch" or ""); whether you are out of its sight only
## because of low cover (Residents.hidden_from).
var last_known := Vector3.INF
var sensed_by := ""
var hidden := false
## Why it last gave you up (tools): Pursuit's reasons, or "taken".
var gave_up_why := ""
var path := PackedVector3Array()
var path_i := 0
var _repath_t := 0.0
var _path_to := Vector3.INF
var _sense_t := 0.0
var _walked := 0.0
var _step_d := 0.0
## A bone step to be heard once this frame's step stands.
var _step_due := false
var _strike_was := ""
## The last tell it sounded (tools): "near", "swing" or "staggered" (the
## wind-up's own sound is its strike's, CreatureStrike).
var last_sound := ""
## Where it began climbing back in (LYING).
var _lie_from := Vector3.INF
## The light (§FF.2): its rise is a fall back out of the light, not a
## waking; the dark node it is making for or hangs back in, and its spot
## there; how fast it is leaving the light; how long it has watched you
## from the edge of its dark; this strike is a pocket's counterattack (it
## lunges in as it winds up); a strike of its reached you where it may.
var _falling_back := false
var pocket_node := -1
var pocket := Vector3.INF
## Where it looks while it hangs back: the way the light comes in.
var _face_to := Vector3.ZERO
var _leave_mps := 0.0
var _edge_t := 0.0
var lunging := false
var _reached := false
## The retreat (§FF.2): the hole it goes into, its part ("walk", "climb",
## "withdraw"), how long it has been going and into its part; whether you
## saw it go.
var hole: Dictionary = {}
var _rphase := ""
var _retreat_t := 0.0
var _rt := 0.0
var seen_going := false
## Into the stone for good (the floor cleared) or only for a while (cut
## off: below); how long before it comes up; how often it has.
var _for_good := true
var _below_left := 0.0
var came_up := 0
## Passed (Mike's 7 Oct note): your head came within creep.arms_m of it at
## rest, with a clear line; it climbs out the first moment you can't see
## it. (Not its strike: _arm() makes that as it climbs out.)
var armed := false
## This step it holds still because you can see it (holds_still); the
## steps it has undone, stopping short of your sight (tools).
var still := false
var stopped_short := 0
## Its bone steps heard so far (tools).
var steps_heard := 0
## Its near tell has sounded for this climb (it plays as it starts to
## move, not before).
var _told := false


func setup(p_residents: Residents, p_place: Dictionary) -> void:
	residents = p_residents
	place = p_place
	kind = str(place.get("kind", "skeleton"))
	def = residents.creature(kind)
	fire_hp = float(def.get("fire_hp", 0.0))
	pursuit = Pursuit.new(self, gives_up())
	# A fire pot's burst can reach it (FirePots' fire-target socket).
	add_to_group(FirePots.TARGET_GROUP)
	name = "%s_%d_%d" % [kind.capitalize(), int(place.piece), int(place.spot) + 1]
	global_position = place.pos
	yaw = float(place.yaw)
	voice = Audio3D.make("resident", self, "Voice")
	voice.position = Vector3(0.0, 1.2, 0.0)
	feet = Audio3D.make("resident", self, "Feet")
	feet.volume_db = -10.0


## Its sheet is baked (Residents.bake): the sprite shows it.
func show_sheet(sheet: Image, height_m: float, n_poses: int, aspect: float) -> void:
	if sprite != null:
		sprite.queue_free()
	sprite = ResidentSprite.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.setup_poses(sheet, height_m, n_poses, aspect, 0.6, yaw)
	_show_pose()


## Its state's name; in a strike, the strike's part ("wind_up", "strike",
## "recover", "reel").
func state_name() -> String:
	if state == STRIKING and strike != null and strike.busy():
		return strike.state
	return STATE_NAMES[state]


func strike_def() -> Dictionary:
	return def.get("strike", {})


func gives_up() -> Dictionary:
	return def.get("gives_up", {})


func notice() -> Dictionary:
	return def.get("notice", {})


## Its creature's creep block (Mike's 7 Oct note): {} for one that moves in
## plain view (a waker).
func creep() -> Dictionary:
	return def.get("creep", {})


## Does it move only unseen (a creeper)?
func creeps() -> bool:
	return not creep().is_empty()


## How near your head brings it out (m): a creeper's creep.arms_m arms it,
## a waker's wakes_m wakes it.
func waking_m() -> float:
	var wakes := float(def.get("wakes_m", 3.0))
	return float(creep().get("arms_m", wakes)) if creeps() else wakes


## Its pace hunting you (m/s): a creeper's creep.creep_mps (slow: it moves
## only unseen), a waker's walk_mps.
func hunt_mps() -> float:
	var walk := float(def.get("walk_mps", 2.2))
	return float(creep().get("creep_mps", walk)) if creeps() else walk


## Where its eyes are now: at rest its head in its niche or grave, else
## eye_m over its feet.
func eye() -> Vector3:
	if state == REST:
		return place.eye
	if state == RISING or state == LYING:
		return global_position + Vector3(0.0, lerpf(0.7, float(def.get("eye_m", 1.5)), clampf(t / maxf(float(def.get("rise_s", 1.6)), 0.01), 0.0, 1.0)), 0.0)
	if state == RETREAT and _rphase != "walk":
		return global_position + Vector3(0.0, 0.7, 0.0)
	return global_position + Vector3(0.0, float(def.get("eye_m", 1.5)), 0.0)


## Where a fire pot meets it (FirePots): its middle, lying in its rest
## (from its niche's or grave's floor to its head) or standing.
func fire_center() -> Vector3:
	if state == REST:
		return ((place.pos as Vector3) + (place.eye as Vector3)) * 0.5
	return global_position + Vector3(0.0, float(def.get("eye_m", 1.5)) * 0.6, 0.0)


## A pot's fire reached it and it still stands (FirePots): lying at rest,
## it wakes and climbs out, burning.
func fire_hit(_amount: float, _from: Vector3) -> void:
	if state == REST:
		wake()


## Burnt down to nothing by a fire pot (§FA.3: a resident at 0 fire_hp
## burns out and is gone): the chase off (Harm no longer counts it), out
## of the tomb for good.
func burn_out() -> void:
	gave_up_why = "burnt"
	pursuit.give_up("burnt")
	if strike != null:
		strike.cancel()
	_disarm()
	if residents != null:
		residents.all.erase(self)
	# Its meshes let go of first (NodeRelease), as the tomb's are.
	NodeRelease.free_later(self)


## A fire pot's burst within its burst_heard_m since it last listened
## (FirePots.bursts_since; §FA.3: the burst gives you away).
func hears_burst() -> bool:
	var out := false
	var e := eye()
	for b in FirePots.bursts_since(burst_id):
		burst_id = int(b.id)
		if e.distance_to(b.pos) <= float(b.heard_m):
			out = true
	return out


## Is it out of its rest (awake, up or on its way)?
func awake() -> bool:
	return state != REST


## Hunting you (rising to, hunting, striking: not resting, not going home,
## not falling back out of the light)?
func hunting() -> bool:
	return state in [HUNT, STRIKING] or (state == RISING and not _falling_back)


## Its chase has its teeth in you (§FD): its strike has landed this chase,
## so it may follow you into the light (Pursuit.may_enter,
## rules.chase_enters_light). Nothing else lets it stand in the light.
func chasing() -> bool:
	return pursuit.may_enter(true)


## Winding up its strike now (the window a lit torch's swing staggers it
## in, §FA.1)?
func winding_up() -> bool:
	return state == STRIKING and strike != null and strike.winding_up()


func _physics_process(delta: float) -> void:
	if residents == null or residents.paused():
		return
	# Unseen only (Mike's 7 Oct note): watched, it holds still this step,
	# its clock stopped; its senses, its chase and the light's rules go on.
	still = holds_still()
	var was_state := state
	var was_pos := global_position
	var was_yaw := yaw
	var was_t := t
	var was_walked := _walked
	var was_step_d := _step_d
	if not still:
		t += delta
	match state:
		REST:
			_rest(delta)
		RISING:
			if not still and not _told:
				# Its near tell as it starts to move: heard behind you.
				_told = true
				_sound("near")
			_rise(false)
		HUNT:
			_hunt(delta)
		STRIKING:
			_striking(delta)
		RETURN:
			_return(delta)
		LYING:
			_rise(true)
		LEAVE:
			_leave(delta)
		LURK:
			_lurk(delta)
		RETREAT:
			_retreat(delta)
		BELOW:
			_below(delta)
			return
		GONE:
			return
	var changed := state != was_state
	if still and not changed:
		return
	if (changed or global_position != was_pos) and holds_still():
		# Where this step left it you would see it: the step undone (it
		# stops just short of your sight), unheard, its pose kept.
		if not changed:
			global_position = was_pos
			yaw = was_yaw
			t = was_t
			_walked = was_walked
			_step_d = was_step_d
			_step_due = false
			stopped_short += 1
		_bone_step()
		return
	_bone_step()
	_show_pose()


## Its bone step, heard for a step that stood (_walk_to).
func _bone_step() -> void:
	if not _step_due:
		return
	_step_due = false
	steps_heard += 1
	feet.stream = SoundSynth.stream("bone_step", randi())
	feet.play()


func _enter(s: int) -> void:
	state = s
	t = 0.0


## Does it hold still this step (Mike's 7 Oct note): a creeper you can see
## (Residents.watched), unless it is in its strike (which runs in plain
## view, §FA.1), up and about within strike.reach_m of you (it got right
## up on you), or going at the floor's last light (§FF.2's reveal). At rest
## there is nothing to hold (armed, it waits there until you look away);
## below in the stone, or gone, it can't be seen.
func holds_still() -> bool:
	if not creeps():
		return false
	match state:
		REST, STRIKING, BELOW, GONE:
			return false
		RETREAT:
			if _for_good:
				return false
		HUNT, RETURN, LEAVE, LURK:
			if within_reach():
				return false
	return residents.watched(self)


## You within its strike's reach (strike.reach_m, flat, and not a storey
## off): near enough that, up and about, it may move in plain view.
func within_reach() -> bool:
	var p := residents.player.global_position
	var reach := strike.reach_m if strike != null else float(strike_def().get("reach_m", 1.6))
	return _flat_to(p) <= reach and absf(p.y - global_position.y) < 1.2


## At rest. A creeper is armed by your passing (your head within
## creep.arms_m of its head with a clear line, Residents.can_wake, sensed
## every SENSE_S), silently, and climbs out the first moment you can't see
## it; a waker wakes as you come within its wakes_m.
func _rest(delta: float) -> void:
	if not armed:
		_sense_t -= delta
		if _sense_t > 0.0:
			return
		_sense_t = SENSE_S
		if not residents.can_wake(self):
			return
		if not creeps():
			wake()
			return
		armed = true
	if not residents.watched(self):
		wake()


## Wake: armed and out of your sight (a waker: you came within wakes_m), or
## burnt where it lies (a fire pot). It climbs out, its near tell heard as
## it starts to move (a creeper you are watching lies there until you look
## away), its strike ready, and hunts you from now (Pursuit, §FD).
func wake() -> void:
	if state != REST:
		return
	armed = false
	_enter(RISING)
	_told = false
	last_known = residents.player.global_position
	_arm()
	pursuit.notice(residents.torch_lit())


## Its strike (CreatureStrike, residents.json strike), at its head: a
## swing has to reach that (§FA.1).
func _arm() -> void:
	if strike != null:
		return
	strike = CreatureStrike.new()
	strike.name = "Strike"
	add_child(strike)
	strike.position = Vector3(0.0, float(def.get("eye_m", 1.5)), 0.0)
	strike.setup(strike_def(), kind)
	strike.target = residents.player
	strike.on_hit = _on_hit
	strike.struck.connect(_struck)
	strike.staggered.connect(_staggered)
	_strike_was = ""


## Lying down again: its strike goes (nothing at rest is met by a swing).
func _disarm() -> void:
	if strike == null:
		return
	remove_child(strike)
	strike.queue_free()
	strike = null


func _sound(which: String) -> void:
	var kinds := {"near": "bone_grind", "swing": "whip", "staggered": "crack"}
	var k := str(kinds.get(which, which))
	last_sound = which
	voice.stream = SoundSynth.stream(k, randi())
	voice.pitch_scale = {"swing": 0.55, "staggered": 1.4}.get(which, 1.0)
	voice.play()


## Its strike reached you (CreatureStrike.on_hit): one hit, as
## CreatureStrike's own (take_hit, Harm counts it), unless you stand in the
## light and it hasn't hit you yet (§FF.2, Residents.may_strike).
func _on_hit(target: Node3D) -> void:
	if not residents.may_strike(self) or not target is PlanetPlayer:
		return
	var p := target as PlanetPlayer
	p.death_cause = "creature:" + kind
	p.take_hit(1.0, strike.global_position)
	_reached = true


## Its strike's end: landed, the chase has its teeth in you (Pursuit.hit,
## §FD).
func _struck(landed: bool) -> void:
	if landed and _reached:
		pursuit.hit(residents.torch_lit())
	_reached = false


## A lit torch broke its wind-up (§FA.1): the crack of it as it reels.
func _staggered(_from: Vector3) -> void:
	_sound("staggered")


## Climbing out (or back in, `back`): over rise_s from its resting place
## over the niche's lip or the coffin's rim to the floor before it.
## Watched, a creeper holds, half out or half in (the Boos' moment).
func _rise(back: bool) -> void:
	if still:
		return
	var rise_s := maxf(float(def.get("rise_s", 1.6)), 0.05)
	var k := clampf(t / rise_s, 0.0, 1.0)
	var from: Vector3 = place.pos
	# Climbing back in, from where it stands.
	var to: Vector3 = _lie_from if back and _lie_from != Vector3.INF else place.out
	var lift := 0.85 if str(place.rests_in) == "grave" else 0.12
	var mid := from.lerp(to, 0.5) + Vector3(0.0, maxf(from.y, to.y) - from.lerp(to, 0.5).y + lift, 0.0)
	var u := (1.0 - k) if back else k
	# A smoothed arc: up over the edge, then down to the floor.
	var e := smoothstep(0.15, 0.95, u)
	global_position = from.lerp(mid, e).lerp(mid.lerp(to, e), e)
	yaw = float(place.yaw)
	if k >= 1.0:
		if back:
			global_position = from
			_lie_from = Vector3.INF
			_disarm()
			# At rest again: only your passing arms it now.
			armed = false
			_enter(REST)
		elif _falling_back:
			# Out of its relit place: on for the dark (§FF.2).
			_falling_back = false
			_start_leave()
		else:
			_enter(HUNT)
			if not chasing() and not residents.dark_at(global_position):
				# Woken where the light has come since: it won't hunt you in it.
				give_up("light")


## Sense you (every SENSE_S): what it senses, and where you were.
func _sense(delta: float) -> void:
	_sense_t -= delta
	if _sense_t > 0.0:
		return
	_sense_t = SENSE_S
	sensed_by = residents.sense(self)
	hidden = residents.hidden_from(self)
	if sensed_by != "":
		last_known = residents.player.global_position


## One step of its chase by its own gives_up (Pursuit): true if it gave
## you up now.
func _chase(delta: float) -> bool:
	var p := residents.player
	if pursuit.step(delta, sensed_by != "", _flat_to(p.global_position), residents.torch_lit(), hidden):
		give_up(pursuit.why)
		return true
	return false


## It has given you up (`why`): no longer your pursuer; home to its rest.
func give_up(why: String) -> void:
	gave_up_why = why
	pursuit.give_up(why)
	# What it sensed before is forgotten; it looks afresh.
	sensed_by = ""
	hidden = false
	_sense_t = 0.0
	if strike != null:
		strike.cancel()
	lunging = false
	_edge_t = 0.0
	if state in [REST, LYING, LEAVE, LURK, RETREAT, GONE]:
		return
	if state == RISING:
		if _falling_back or not residents.dark_at(place.pos):
			# Its place is in the light: out it comes, and away (§FF.2).
			_falling_back = true
			return
		# Not out yet: back in.
		t = maxf(float(def.get("rise_s", 1.6)) - t, 0.0)
		state = LYING
		_lie_from = Vector3.INF
		return
	_after_give_up()


## Given you up (§FF.2): out of the light first if it stands in it (it goes
## home from the dark, if it can, _leave); else home by a way through the
## dark to its place, if its place is still dark (returns_to_rest); else it
## hangs back in the dark where it is.
func _after_give_up() -> void:
	path = PackedVector3Array()
	_path_to = Vector3.INF
	if not residents.dark_at(global_position):
		_start_leave()
	elif residents.can_go_home(self):
		_enter(RETURN)
	else:
		_start_lurk(residents.node_of(global_position))


func _hunt(delta: float) -> void:
	_sense(delta)
	if _chase(delta):
		return
	var p := residents.player
	var reach := strike.reach_m if strike != null else float(strike_def().get("reach_m", 1.6))
	var flat := _flat_to(p.global_position)
	var close := flat <= reach * 0.9 and absf(p.global_position.y - global_position.y) < 1.2
	if close and sensed_by in ["sight", "touch", "flame", "glow"] and residents.may_strike(self) and residents.clear_line(eye(), p.eye_position()) and strike != null and strike.begin():
		_edge_t = 0.0
		_enter(STRIKING)
		return
	# On toward where it last sensed you (a creeper creeping, creep_mps);
	# when it can see you, only up to its reach.
	var target := last_known if last_known != Vector3.INF else global_position
	var stop := reach * 0.75 if sensed_by != "" else 0.3
	var held := false
	if _flat_to(target) > stop:
		held = _walk_to(target, delta, true, hunt_mps())
	elif sensed_by != "":
		_face(p.global_position, delta, 120.0)
		held = not residents.may_strike(self)
	# The light between you (§FF.2): it watches you from the edge of its
	# dark, then gives you up.
	if held:
		_face(p.global_position, delta, 120.0)
		_edge_t += delta
		if _edge_t >= Residents.rule("edge_watch_s", 6.0):
			give_up("light")
	else:
		_edge_t = 0.0


## Its strike under way (CreatureStrike runs the clock): it turns to you
## in the wind-up, holds through the committed strike, senses and may
## give you up as it draws back, and is pushed back as it reels.
func _striking(delta: float) -> void:
	var p := residents.player
	var s := strike.state if strike != null else "ready"
	if s != _strike_was:
		if s == "strike":
			# The committed swing.
			_sound("swing")
		_strike_was = s
	match s:
		"wind_up":
			if not residents.may_strike(self):
				# You stepped into the light in its wind-up: it breaks off
				# (§FF.2, as the snake does).
				strike.cancel()
				lunging = false
				_strike_was = ""
				_enter(HUNT)
				return
			_face(p.global_position, delta, 140.0)
			if lunging:
				_lunge(delta)
		"recover":
			_sense(delta)
			if _chase(delta):
				return
			_face(p.global_position, delta, 90.0)
		"reel":
			_sense(delta)
			if _chase(delta):
				return
			_reel()
		"ready":
			_strike_was = ""
			lunging = false
			_enter(HUNT)


## A dark pocket's counterattack (§FF.2): in at rules.pocket_lunge_mps as
## it winds up, until you are well inside its reach, over open floor and
## never into the light.
func _lunge(delta: float) -> void:
	var p := residents.player
	var to := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
	var d := to.length()
	var want := (strike.reach_m if strike != null else 1.6) * 0.6
	if d <= want:
		return
	var step := minf(Residents.rule("pocket_lunge_mps", 3.5) * delta, d - want)
	var nxt := global_position + Vector3(to.x, 0.0, to.y) / d * step
	var nav := residents.nav
	if not residents.may_be_at(self, nxt) or (nav != null and nav.inside(nav.cell_of(nxt)) and not nav.is_open(nav.cell_of(nxt))):
		return
	_place_on_floor(nxt)
	_walked += step


## The stagger's push back (CreatureStrike.take_reel), along the floor:
## where stone is behind it, less or none; never into the light (§FF.2).
func _reel() -> void:
	var push := strike.take_reel()
	if push.length() < 0.0001:
		return
	var nav := residents.nav
	for k: float in [1.0, 0.5]:
		var to := global_position + push * k
		if not residents.may_be_at(self, to):
			continue
		if nav == null or not nav.inside(nav.cell_of(to)) or nav.is_open(nav.cell_of(to)):
			_place_on_floor(to)
			return


func _return(delta: float) -> void:
	_sense(delta)
	if sensed_by != "" and residents.may_strike(self):
		# It has you again (in the dark: in the light it lets you be, §FF.2).
		gave_up_why = ""
		pursuit.notice(residents.torch_lit())
		_enter(HUNT)
		return
	var to: Vector3 = place.out
	var left := _flat_to(to)
	# Home: at its way out, or as near it as the floor goes.
	if left <= 0.25 or (left <= 1.0 and not path.is_empty() and path_i >= path.size() - 1 and _flat_to(path[-1]) <= 0.1):
		_lie_from = global_position
		_enter(LYING)
		return
	if _walk_to(to, delta):
		# The light has come between it and home: it hangs back here.
		_start_lurk(residents.node_of(global_position))


# --- The light, the pockets, the retreat (design §FF.2) ---------------------------

## A holder has caught and the floor is not yet cleared (Residents): it
## keeps to the dark unless it is chasing you.
func light_changed() -> void:
	match state:
		REST:
			if not residents.dark_at(place.pos):
				_fall_back()
		LYING:
			if not residents.dark_at(place.pos):
				# Its place lit as it climbs in: out again, and away (no tell:
				# it is already moving).
				t = maxf(float(def.get("rise_s", 1.6)) - t, 0.0)
				state = RISING
				_falling_back = true
				_told = true
		RISING:
			if not _falling_back and not chasing() and not residents.dark_at(place.pos):
				# Waking as its place is relit: it gives you up, and once out
				# it goes for the dark.
				gave_up_why = "light"
				pursuit.give_up("light")
				_falling_back = true
		HUNT, STRIKING:
			if not chasing() and not residents.dark_at(global_position):
				give_up("light")
		RETURN:
			if not residents.dark_at(global_position) or not residents.can_go_home(self):
				_after_give_up()
		LEAVE:
			if pocket_node >= 0 and not residents.ground.is_ground(pocket_node):
				_start_leave()
		LURK:
			if not residents.dark_at(global_position) or (pocket_node >= 0 and not residents.ground.is_ground(pocket_node)):
				_start_leave()
			elif pocket_node >= 0:
				# The light came nearer: a spot deeper in its pocket.
				pocket = residents.pocket_spot(pocket_node, self)
				_face_to = residents.light_way(pocket_node, pocket)


## Its resting place is in the light now: it climbs out, its near tell
## heard as it starts to move (a creeper you are watching waits until you
## look away), and goes for the dark (§FF.2). No one's pursuer as it goes.
func _fall_back() -> void:
	armed = false
	_falling_back = true
	_enter(RISING)
	_told = false
	_arm()


## Out of the light (rules.back_to_dark_s, §FD): for the nearest dark by the
## way with least light in it (Residents.nearest_dark), fast enough to be
## out of the light within back_to_dark_s (Pursuit.back_to_dark_mps). Cut
## off from any dark it can walk to, into the stone through the nearest
## hole, to come up in the dark elsewhere (retreat, below).
func _start_leave() -> void:
	if strike != null:
		strike.cancel()
	lunging = false
	_edge_t = 0.0
	var at := residents.node_of(global_position)
	var to := residents.nearest_dark(at)
	if to < 0:
		if at < 0:
			# Off the tomb's floor (a test floor): no light there to leave.
			_start_lurk(-1)
		else:
			retreat(false)
		return
	pocket_node = to
	pocket = residents.pocket_spot(to, self)
	_face_to = residents.light_way(to, pocket)
	path = PackedVector3Array()
	_path_to = Vector3.INF
	var walk := float(def.get("walk_mps", 2.2))
	_leave_mps = clampf(Pursuit.back_to_dark_mps(_light_m(pocket), walk), walk, LEAVE_MAX_MPS)
	_enter(LEAVE)


## How far it walks through the light on its way to `to` (m, along its
## path over the floor, in quarter-metre steps).
func _light_m(to: Vector3) -> float:
	var nav := residents.nav
	if nav == null:
		return global_position.distance_to(to)
	var pts := nav.path(global_position, to)
	var m := 0.0
	var prev := global_position
	for q in pts:
		var seg := prev.distance_to(q)
		var n := maxi(int(ceil(seg / 0.25)), 1)
		for i in n:
			if residents.dark_at(prev.lerp(q, float(i + 1) / n)):
				return m + seg * float(i + 1) / n
		m += seg
		prev = q
	return m


func _leave(delta: float) -> void:
	if residents.dark_at(global_position):
		# Out of the light: home, if a way through the dark leads there; else
		# it hangs back in this dark.
		if residents.can_go_home(self):
			path = PackedVector3Array()
			_path_to = Vector3.INF
			_enter(RETURN)
		else:
			_start_lurk(residents.node_of(global_position))
		return
	_walk_to(pocket, delta, false, _leave_mps)
	# No way out over the floor: it goes into the stone where it is.
	if t > Residents.rule("back_to_dark_s", 4.0) * 2.0 + 2.0:
		retreat(false)


## Hang back in dark node `id` (§FF.2: the dark pockets): to its spot there
## (Residents.pocket_spot), up and armed, no one's pursuer.
func _start_lurk(id: int) -> void:
	lunging = false
	_edge_t = 0.0
	pocket_node = id
	pocket = residents.pocket_spot(id, self) if id >= 0 else global_position
	_face_to = residents.light_way(id, pocket) if id >= 0 else global_position - Vector3(sin(yaw), 0.0, cos(yaw))
	path = PackedVector3Array()
	_path_to = Vector3.INF
	_arm()
	_enter(LURK)


func _lurk(delta: float) -> void:
	_sense(delta)
	var p := residents.player
	# You came within its counterattack, where it senses you, in the dark:
	# it strikes, lunging in as it winds up (§FF.2), and hunts you after.
	var near := _flat_to(p.global_position) <= Residents.rule("pocket_counterattack_m", 3.0) and absf(p.global_position.y - global_position.y) < 1.5
	var bites := bool(Residents.CLEARED.get("half_lit_pockets_bite", true))
	if near and bites and sensed_by != "" and residents.may_strike(self) and strike != null and strike.begin():
		lunging = true
		_edge_t = 0.0
		last_known = p.global_position
		gave_up_why = ""
		pursuit.notice(residents.torch_lit())
		_enter(STRIKING)
		return
	if pocket != Vector3.INF and _flat_to(pocket) > 0.3:
		if _walk_to(pocket, delta):
			# The light took the way to its spot: it stands where it is.
			pocket = global_position
		return
	# Hanging back: facing you if it senses you, else the way the light
	# comes in.
	_face(p.global_position if sensed_by != "" else _face_to, delta, 90.0)


## The floor's last light has caught (§FF.2; its retreat_to, the skeleton's
## back_into_its_niche): seen, it goes back into its niche or the nearest
## hole and sinks into the stone; unseen, it is gone now. For good
## (`for_good`), or, cut off from every dark it could walk to
## (_start_leave), only into the stone for a while (below): a creeper cut
## off where you can see it stands where it is ("held") until you look
## away, then is into the stone at once (Mike's 7 Oct note; only the last
## light's going is seen).
func retreat(for_good := true) -> void:
	if state == GONE:
		return
	if state == RETREAT:
		# On its way into the stone already (or held there, cut off, until
		# you look away): for good now, if so.
		_for_good = _for_good or for_good
		return
	if state == BELOW:
		# In the stone already: for good now, unseen.
		if for_good:
			_for_good = true
			seen_going = false
			_gone()
		return
	_for_good = for_good
	seen_going = false
	if strike != null:
		strike.cancel()
	lunging = false
	gave_up_why = "cleared" if for_good else "cut_off"
	pursuit.give_up(gave_up_why)
	_retreat_t = 0.0
	_rt = 0.0
	if not for_good and creeps():
		# Cut off, a creeper still goes only unseen: watched, it is held
		# where it stands; unwatched, into the stone now.
		if residents.watched(self):
			_rphase = "held"
			_enter(RETREAT)
		else:
			_done_retreat()
		return
	if not bool(Residents.CLEARED.get("retreat_seen", true)) or not in_view():
		_done_retreat()
		return
	_go_seen()


## Seen going (§FF.2's reveal): sinking back into its niche or grave if it
## lies in it, climbing back in if it is on its way out or in, else
## hurrying to the nearest hole; its near tell heard as it goes.
func _go_seen() -> void:
	seen_going = true
	var climb := maxf(float(def.get("rise_s", 1.6)), 0.05) * CLIMB_IN_K
	var k := clampf(t / maxf(float(def.get("rise_s", 1.6)), 0.05), 0.0, 1.0)
	match state:
		REST:
			# In its niche or grave already: it sinks back into the stone.
			hole = place
			_rphase = "withdraw"
		LYING:
			# Climbing in already: on in.
			hole = place
			_rphase = "climb"
			_rt = k * climb
		RISING:
			# Climbing out: back in.
			hole = place
			_rphase = "climb"
			_lie_from = place.out
			_rt = (1.0 - k) * climb
		_:
			hole = residents.nearest_hole(self)
			_rphase = "walk"
			path = PackedVector3Array()
			_path_to = Vector3.INF
	if _rphase == "climb" and _lie_from == Vector3.INF:
		_lie_from = place.out
	_sound("near")
	_enter(RETREAT)


func _retreat(delta: float) -> void:
	if _rphase == "held":
		# Cut off where you could see it: while you still can, it stands;
		# once you can't, it is into the stone at once. Or the floor's last
		# light has caught since (for good): it goes as any other does then.
		if still:
			return
		if _for_good and bool(Residents.CLEARED.get("retreat_seen", true)) and in_view():
			_go_seen()
		else:
			_done_retreat()
		return
	_retreat_t += delta
	_rt += delta
	if _retreat_t >= float(Residents.CLEARED.get("retreat_seen_s", 6.0)) or not in_view():
		_done_retreat()
		return
	var climb := maxf(float(def.get("rise_s", 1.6)), 0.05) * CLIMB_IN_K
	match _rphase:
		"walk":
			var to: Vector3 = hole.out
			if _flat_to(to) <= 0.3 or (not path.is_empty() and path_i >= path.size() - 1 and _flat_to(path[-1]) <= 0.15 and _flat_to(to) <= 1.0):
				_lie_from = global_position
				_rphase = "climb"
				_rt = 0.0
				_sound("near")
			else:
				_walk_to(to, delta, false, Residents.rule("retreat_mps", 3.2))
		"climb":
			var k := clampf(_rt / climb, 0.0, 1.0)
			global_position = _arc(hole, _lie_from, 1.0 - k)
			yaw = float(hole.yaw)
			if k >= 1.0:
				_rphase = "withdraw"
				_rt = 0.0
		"withdraw":
			var k2 := clampf(_rt / maxf(Residents.rule("withdraw_s", 1.2), 0.05), 0.0, 1.0)
			global_position = (hole.pos as Vector3) + _into_stone(hole) * smoothstep(0.0, 1.0, k2)
			yaw = float(hole.yaw)
			if k2 >= 1.0:
				_done_retreat()


## Into the stone: gone for good, or below for a while (cut off).
func _done_retreat() -> void:
	if _for_good:
		_gone()
	else:
		_go_below()


## In the stone under the tomb for rules.below_s, unseen and inert: no one's
## pursuer, nothing to swing at, nothing a fire pot can reach.
func _go_below() -> void:
	if strike != null:
		strike.cancel()
	_disarm()
	pursuit.give_up("below")
	if sprite != null:
		sprite.visible = false
	feet.stop()
	remove_from_group(FirePots.TARGET_GROUP)
	var b: Array = Residents.RULES.get("below_s", [6.0, 12.0])
	_below_left = randf_range(float(b[0]), float(b[1]))
	_enter(BELOW)


## Up again in the dark nearest it, out of your sight (Residents.come_up_spot),
## to hang back there; with nowhere like that just now, a while more.
func _below(delta: float) -> void:
	_below_left -= delta
	if _below_left > 0.0:
		return
	var up := residents.come_up_spot(self)
	if up.is_empty():
		_below_left = 2.0
		return
	global_position = up.pos
	if sprite != null:
		sprite.visible = true
	add_to_group(FirePots.TARGET_GROUP)
	came_up += 1
	_start_lurk(int(up.node))


## A point on the climb between resting in `pl` (u 0) and standing on the
## floor at `floor_pt` (u 1): up over the niche's lip or the coffin's rim,
## then down (the arc _rise climbs).
func _arc(pl: Dictionary, floor_pt: Vector3, u: float) -> Vector3:
	var from: Vector3 = pl.pos
	var lift := 0.85 if str(pl.rests_in) == "grave" else 0.12
	var half_way := from.lerp(floor_pt, 0.5)
	var mid := half_way + Vector3(0.0, maxf(from.y, floor_pt.y) - half_way.y + lift, 0.0)
	var e := smoothstep(0.15, 0.95, u)
	return from.lerp(mid, e).lerp(mid.lerp(floor_pt, e), e)


## The way it sinks into the stone from resting in `pl`: back into the wall
## behind a niche, down into a grave.
static func _into_stone(pl: Dictionary) -> Vector3:
	if str(pl.rests_in) == "grave":
		return Vector3(0.0, -1.05, 0.0)
	var back := (pl.pos as Vector3) - (pl.out as Vector3)
	back.y = 0.0
	return back.normalized() * 0.9 + Vector3(0.0, -0.1, 0.0)


## Gone for good (§FF.2: relit stays lit, so it never comes back): its
## strike and chase given up, off the roll, freed once its last sound ends.
func _gone() -> void:
	if state == GONE:
		return
	state = GONE
	if strike != null:
		strike.cancel()
	_disarm()
	pursuit.give_up("cleared")
	if sprite != null:
		sprite.visible = false
	feet.stop()
	remove_from_group(FirePots.TARGET_GROUP)
	residents.went(self, seen_going)
	set_physics_process(false)
	# Its meshes let go of first (NodeRelease), as the tomb's are.
	if voice.playing:
		voice.finished.connect(func() -> void: NodeRelease.free_later(self), CONNECT_ONE_SHOT)
	else:
		NodeRelease.free_later(self)


## Where you might see it (Residents.watched, Mike's 7 Oct note): its feet,
## its middle and its head as it is now (lying in its place, climbing out
## or in, standing); none while it is below in the stone or gone, when
## nothing of it is drawn.
func view_points() -> Array:
	if state in [BELOW, GONE] or (sprite != null and not sprite.visible):
		return []
	var up := Vector3(0.0, VIEW_HEAD_M, 0.0)
	var head := global_position + up
	var rise_s := maxf(float(def.get("rise_s", 1.6)), 0.05)
	match state:
		REST:
			head = place.eye
		RISING, LYING:
			# From its head as it lies (k 0) to standing (k 1).
			var k := clampf(t / rise_s, 0.0, 1.0)
			if state == LYING:
				k = 1.0 - k
			head = global_position + ((place.eye as Vector3) - (place.pos as Vector3)).lerp(up, k)
		RETREAT:
			if not hole.is_empty() and _rphase in ["climb", "withdraw"]:
				var k2 := 0.0 if _rphase == "withdraw" else 1.0 - clampf(_rt / (rise_s * CLIMB_IN_K), 0.0, 1.0)
				head = global_position + ((hole.eye as Vector3) - (hole.pos as Vector3)).lerp(up, k2)
	var feet := global_position + Vector3(0.0, VIEW_FEET_M, 0.0)
	return [feet, feet.lerp(head, 0.5), head]


## A body standing at `p` (its feet, middle and head; Residents.seen_at).
static func standing_points(p: Vector3) -> Array:
	var feet := p + Vector3(0.0, VIEW_FEET_M, 0.0)
	var head := p + Vector3(0.0, VIEW_HEAD_M, 0.0)
	return [feet, feet.lerp(head, 0.5), head]


## Can you see it: in the frame, near enough, nothing of the stone between
## your eye and its head or its middle (the floor's last light: seen, it is
## seen going).
func in_view() -> bool:
	if not is_inside_tree() or sprite == null or not sprite.visible:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var c := cam.global_position
	for p: Vector3 in [eye(), global_position + Vector3(0.0, 0.5, 0.0)]:
		if c.distance_to(p) <= SEEN_M and cam.is_position_in_frustum(p) and residents.clear_line(c, p):
			return true
	return false


func _flat_to(at: Vector3) -> float:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length()


## Walk toward `target` at walk_mps (or `mps`) along the tomb's floor
## (TombNav), finding a new way every REPATH_S or when the target has
## moved. keep_dark: never a step into the light unless it is chasing you
## (§FF.2, Residents.may_be_at); returns true when the light held it back
## (held still, it still knows that). Held still (watched), no step.
func _walk_to(target: Vector3, delta: float, keep_dark := true, mps := -1.0) -> bool:
	var nav := residents.nav
	_repath_t -= delta
	if nav != null and (_repath_t <= 0.0 or _path_to.distance_to(target) > 0.75 or path_i >= path.size()):
		_repath_t = REPATH_S
		_path_to = target
		path = nav.path(global_position, target)
		path_i = 1 if path.size() > 1 else 0
	var goal := target
	if nav != null:
		if path.is_empty():
			return false
		while path_i < path.size() - 1 and _flat_to(path[path_i]) < 0.15:
			path_i += 1
		goal = path[mini(path_i, path.size() - 1)]
	var to := Vector2(goal.x - global_position.x, goal.z - global_position.z)
	var d := to.length()
	if d < 0.01:
		return false
	var step := minf((mps if mps > 0.0 else float(def.get("walk_mps", 2.2))) * delta, d)
	var move := to / d * step
	var nxt := global_position + Vector3(move.x, 0.0, move.y)
	if keep_dark and not residents.may_be_at(self, nxt):
		_face_dir(to, delta, 240.0)
		return true
	if still:
		return false
	_place_on_floor(nxt)
	_face_dir(to, delta, 240.0)
	_walked += step
	_step_d += step
	if _step_d >= STEP_M:
		_step_d = 0.0
		# Heard once the step stands (_physics_process: a step undone,
		# stopping short of your sight, makes no sound).
		_step_due = true
	return false


## Stand at `p`, on the floor there.
func _place_on_floor(p: Vector3) -> void:
	var fy := residents.nav.floor_at(p) if residents.nav != null else NAN
	global_position = Vector3(p.x, fy if not is_nan(fy) else p.y, p.z)


func _face(at: Vector3, delta: float, deg_s: float) -> void:
	_face_dir(Vector2(at.x - global_position.x, at.z - global_position.z), delta, deg_s)


## Turn toward `f` (x/z) at up to `deg_s`; held still (watched), no turn.
func _face_dir(f: Vector2, delta: float, deg_s: float) -> void:
	if still or f.length() < 0.01:
		return
	var turn := wrapf(TombKit.yaw_facing(f) - yaw, -PI, PI)
	var most := deg_to_rad(deg_s) * delta
	yaw = wrapf(yaw + clampf(turn, -most, most), -PI, PI)


## Its face's way (x/z).
func facing() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


## The sprite's pose and facing now (SkeletonRig.POSES).
func _show_pose() -> void:
	if sprite == null:
		return
	var pname := "walk_0"
	var rise_s := maxf(float(def.get("rise_s", 1.6)), 0.05)
	match state:
		REST:
			pname = "rest_grave" if str(place.rests_in) == "grave" else "rest_niche"
		RISING, LYING:
			var k := clampf(t / rise_s, 0.0, 1.0)
			if state == LYING:
				k = 1.0 - k
			var rest := "rest_grave" if str(place.rests_in) == "grave" else "rest_niche"
			pname = [rest, "rise_a", "rise_b", "rise_c"][mini(int(k * 4.0), 3)]
		HUNT, RETURN, LEAVE, LURK:
			pname = "walk_%d" % (int(_walked / STRIDE_M) % 4)
		STRIKING:
			pname = str(STRIKE_POSES.get(strike.pose() if strike != null else "", "walk_0"))
		RETREAT:
			var into := "rest_grave" if str(hole.get("rests_in", "")) == "grave" else "rest_niche"
			match _rphase:
				"climb":
					var k2 := clampf(_rt / (rise_s * CLIMB_IN_K), 0.0, 1.0)
					pname = [into, "rise_a", "rise_b", "rise_c"][mini(int((1.0 - k2) * 4.0), 3)]
				"withdraw":
					pname = into
				_:
					pname = "walk_%d" % (int(_walked / STRIDE_M) % 4)
	sprite.pose = SkeletonRig.POSES.find(pname)
	sprite.yaw = yaw
	sprite.eye_m = float(SkeletonRig.EYE.get(pname, 1.5))
