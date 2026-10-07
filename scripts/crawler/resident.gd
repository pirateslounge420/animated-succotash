class_name Resident
extends Node3D
## One of the things that live in a ruin's dark (design 6 Oct §FE;
## residents.json creatures, Residents runs them): its own algorithm from
## its creature's row. The first is the tomb's skeleton, a waker (Mike:
## "if you get too close to them they come out of the wall or out of the
## graves"):
##
##   rest      lying still in its niche or grave: set dressing, until you
##             come within wakes_m of its head with a clear line to it;
##   rising    over rise_s, climbing out to the floor before its resting
##             place, its near tell (bone grinding on stone) heard as it
##             starts; from now it hunts you (its Pursuit, prompt 56: Harm
##             counts it as pursuing you, §FD);
##   hunt      walking (walk_mps, by TombNav) to where it last sensed you:
##             seen (notice.sees_you_m, a clear line from its eyes to your
##             head: cover hides you, §FC.2), your lit torch's flame or the
##             stone it lights seen (sees_flame_m), or heard (hears_step_m
##             by your noise: your steps, a swing that lands); in reach of
##             you, sensing you there, it strikes;
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
##             back to its place (sensing you again on the way, it hunts
##             again);
##   lying     climbing back in over rise_s, then rest.
##
## It is a sprite (ResidentSprite) with no body: nothing walks into it, it
## walks through nothing (its path keeps it to the floor).
##
## Fire pots (§FA.3; FirePots' fire-target socket, queue 60): a pot's
## burst within its splash, the tar stuck on it and a burning patch it
## stands in burn its fire_hp down (times its oil_scale); burnt while it
## lies at rest, it wakes and climbs out burning; at 0 it burns out and
## is gone for good, the chase with it. Awake, it sees a pot's lit wick as
## your flame out to gives_away.flare_seen_m, and hears a burst within
## burst_heard_m (Residents.sense).

enum { REST, RISING, HUNT, STRIKING, RETURN, LYING }
const STATE_NAMES := ["rest", "rising", "hunt", "striking", "return", "lying"]
## How often it senses you (s), and how often it looks for a new way.
const SENSE_S := 0.15
const REPATH_S := 0.5
## How far each walking frame carries it (m), and between its steps.
const STRIDE_M := 0.32
const STEP_M := 0.7
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
var _strike_was := ""
## The last tell it sounded (tools): "near", "swing" or "staggered" (the
## wind-up's own sound is its strike's, CreatureStrike).
var last_sound := ""
## Where it began climbing back in (LYING).
var _lie_from := Vector3.INF


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


## Where its eyes are now: at rest its head in its niche or grave, else
## eye_m over its feet.
func eye() -> Vector3:
	if state == REST:
		return place.eye
	if state == RISING or state == LYING:
		return global_position + Vector3(0.0, lerpf(0.7, float(def.get("eye_m", 1.5)), clampf(t / maxf(float(def.get("rise_s", 1.6)), 0.01), 0.0, 1.0)), 0.0)
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
	queue_free()


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


## Hunting you (rising, hunting, striking: not resting, not going home)?
func hunting() -> bool:
	return state in [RISING, HUNT, STRIKING]


## Winding up its strike now (the window a lit torch's swing staggers it
## in, §FA.1)?
func winding_up() -> bool:
	return state == STRIKING and strike != null and strike.winding_up()


func _physics_process(delta: float) -> void:
	if residents == null or residents.paused():
		return
	t += delta
	match state:
		REST:
			_sense_t -= delta
			if _sense_t <= 0.0:
				_sense_t = SENSE_S
				if residents.can_wake(self):
					wake()
		RISING:
			_rise(false)
		HUNT:
			_hunt(delta)
		STRIKING:
			_striking(delta)
		RETURN:
			_return(delta)
		LYING:
			_rise(true)
	_show_pose()


func _enter(s: int) -> void:
	state = s
	t = 0.0


## Wake (you came within wakes_m): climb out, the near tell heard, its
## strike ready, and hunt you from now (Pursuit, §FD).
func wake() -> void:
	if state != REST:
		return
	_enter(RISING)
	last_known = residents.player.global_position
	_sound("near")
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


## Its strike's end: landed, the chase has its teeth in you (Pursuit.hit,
## §FD).
func _struck(landed: bool) -> void:
	if landed:
		pursuit.hit(residents.torch_lit())


## A lit torch broke its wind-up (§FA.1): the crack of it as it reels.
func _staggered(_from: Vector3) -> void:
	_sound("staggered")


## Climbing out (or back in, `back`): over rise_s from its resting place
## over the niche's lip or the coffin's rim to the floor before it.
func _rise(back: bool) -> void:
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
			_enter(REST)
		else:
			_enter(HUNT)


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
	if state == REST or state == LYING:
		return
	if state == RISING:
		# Not out yet: back in.
		t = maxf(float(def.get("rise_s", 1.6)) - t, 0.0)
		state = LYING
		_lie_from = Vector3.INF
		return
	_enter(RETURN)
	path = PackedVector3Array()
	_path_to = Vector3.INF


func _hunt(delta: float) -> void:
	_sense(delta)
	if _chase(delta):
		return
	var p := residents.player
	var reach := strike.reach_m if strike != null else float(strike_def().get("reach_m", 1.6))
	var flat := _flat_to(p.global_position)
	var close := flat <= reach * 0.9 and absf(p.global_position.y - global_position.y) < 1.2
	if close and sensed_by in ["sight", "touch", "flame", "glow"] and residents.clear_line(eye(), p.eye_position()) and strike != null and strike.begin():
		_enter(STRIKING)
		return
	# On toward where it last sensed you; when it can see you, only up to
	# its reach.
	var target := last_known if last_known != Vector3.INF else global_position
	var stop := reach * 0.75 if sensed_by != "" else 0.3
	if _flat_to(target) > stop:
		_walk_to(target, delta)
	elif sensed_by != "":
		_face(p.global_position, delta, 120.0)


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
			_face(p.global_position, delta, 140.0)
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
			_enter(HUNT)


## The stagger's push back (CreatureStrike.take_reel), along the floor:
## where stone is behind it, less or none.
func _reel() -> void:
	var push := strike.take_reel()
	if push.length() < 0.0001:
		return
	var nav := residents.nav
	for k: float in [1.0, 0.5]:
		var to := global_position + push * k
		if nav == null or not nav.inside(nav.cell_of(to)) or nav.is_open(nav.cell_of(to)):
			_place_on_floor(to)
			return


func _return(delta: float) -> void:
	_sense(delta)
	if sensed_by != "":
		# It has you again.
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
	_walk_to(to, delta)


func _flat_to(at: Vector3) -> float:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length()


## Walk toward `target` at walk_mps along the tomb's floor (TombNav),
## finding a new way every REPATH_S or when the target has moved.
func _walk_to(target: Vector3, delta: float) -> void:
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
			return
		while path_i < path.size() - 1 and _flat_to(path[path_i]) < 0.15:
			path_i += 1
		goal = path[mini(path_i, path.size() - 1)]
	var to := Vector2(goal.x - global_position.x, goal.z - global_position.z)
	var d := to.length()
	if d < 0.01:
		return
	var step := minf(float(def.get("walk_mps", 2.2)) * delta, d)
	var move := to / d * step
	_place_on_floor(global_position + Vector3(move.x, 0.0, move.y))
	_face_dir(to, delta, 240.0)
	_walked += step
	_step_d += step
	if _step_d >= STEP_M:
		_step_d = 0.0
		feet.stream = SoundSynth.stream("bone_step", randi())
		feet.play()


## Stand at `p`, on the floor there.
func _place_on_floor(p: Vector3) -> void:
	var fy := residents.nav.floor_at(p) if residents.nav != null else NAN
	global_position = Vector3(p.x, fy if not is_nan(fy) else p.y, p.z)


func _face(at: Vector3, delta: float, deg_s: float) -> void:
	_face_dir(Vector2(at.x - global_position.x, at.z - global_position.z), delta, deg_s)


func _face_dir(f: Vector2, delta: float, deg_s: float) -> void:
	if f.length() < 0.01:
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
		HUNT, RETURN:
			pname = "walk_%d" % (int(_walked / STRIDE_M) % 4)
		STRIKING:
			pname = str(STRIKE_POSES.get(strike.pose() if strike != null else "", "walk_0"))
	sprite.pose = SkeletonRig.POSES.find(pname)
	sprite.yaw = yaw
	sprite.eye_m = float(SkeletonRig.EYE.get(pname, 1.5))
