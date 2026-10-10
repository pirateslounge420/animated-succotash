class_name Brew
extends Node
## Harvest and brew (design 9 Oct §FM.7; queue 72; data/brew.json), in
## Torchfire 1's crawler, for the tomb's world (the Aztec world: its plant,
## ololiuhqui, SacredVine). One per session, beside the fire pots
## (CrawlerMain makes it). It routes the interact button (right click):
##
##   up on the surface, at the vine (SacredVine): the first time, the
##     shaman's lesson first (he takes a length himself, the plant left
##     standing, and you see how); then a cutting of it into your pack, one
##     carried thing (carry.max), the plant standing and regrowing on the
##     game clock; nothing to take, a soft rustle. Nothing else answers the
##     button up there.
##   below, at the hearth (within rite.hand_reach_m of its middle: the
##     usual spot by the guard), carrying a cutting: the hand-over and the
##     brew (the rite, below); while he holds the ladle out to you, the
##     button drinks it. Otherwise the button is the bundle's, as built.
##
## The rite: the shaman (the one who found you, HearthFolk, the node
## "Rescuer") rises from his stone, walks round the hearth to stand beside
## you on the kerb, reaches and takes the cutting from you, turns to the
## cauldron (HearthCauldron) and drops it in, stirs with his ladle, lifts a
## ladleful, turns and holds it out; you drink; he lowers it, walks back and
## sits. The rig's own animations only (FolkMotion: the seat and the
## crouch, the walk, the turn, the arms' reach), and no words (§ED, §FM.3).
## His way round is checked clear of the stone (the walls, the pillars, his
## own seat), the torch bundle and the tripod's feet before he starts, else
## he doesn't (and the button is the bundle's).
##
## You drink: a placeholder vision (BrewVision, plants.<id>.vision) eases in
## at once, holds for last_s (a first guess of 120 seconds) and fades. It
## gates nothing and changes no rule (§FM.3: no timer on anything else, no
## torch drain, no hallucinations): it only draws. Nothing about it reaches
## the secret layer (§FM.4: not decided): nothing is saved of a brew.
##
## The cutting shows low in your left hand in view while you carry it and
## that hand holds no fire pot (carry.view). The rite waits while you are up
## on the surface and goes on when you come back down.

const FILE := "res://data/brew.json"
static var _data := {}

## The rite's steps, in order ("" idle).
const STEPS := ["rise", "go", "face_you", "take", "face_pot", "drop", "stir", "fill", "face_you2", "offer", "lower", "home", "face_seat", "sit"]

var main: CrawlerMain
var vision: BrewVision
## The cutting in your left hand, in view.
var view: Node3D
var _view_plant := ""

## The rite: its step and that step's clock; the shaman it drives and how
## he moves; the plant being brewed.
var rite := ""
var _rt := 0.0
var shaman: HearthFolk
var motion: FolkMotion
var plant := ""
## His seat (its floor point and turn), the point a step off it he rises
## to, where he stands beside you on the kerb, and his way between.
var seat_at := Vector3.ZERO
var seat_yaw := 0.0
var seat_front := Vector3.ZERO
var stand := Vector3.ZERO
var way := PackedVector3Array()
## Props: the cutting in his hand (and in its fall into the pot), the brew
## in the pot, the ladleful in his ladle; the ladle's rest (local), and
## whether the ladle is his own way or turned for the work.
var cutting: Node3D
var _cutting_len := 0.3
var _fall := -1.0
var _fall_from := Vector3.ZERO
var pot_brew: MeshInstance3D
var fill: MeshInstance3D
var _ladle_rest := Transform3D.IDENTITY
var _ladle_mode := ""
var _ladle_w := 0.0
var _ladle_at := Vector3.ZERO
var _ladle_q := Quaternion.IDENTITY
var _ladle_eased := false
var _voice: AudioStreamPlayer3D
## You were up on the surface last step (the teacher goes once you come
## down from his lesson).
var _was_up := false
## Counts (the checks): cuttings taken, handed over, brews drunk; the
## rite's steps seen this session, in order.
var harvested := 0
var handed := 0
var drinks := 0
var steps_seen: Array = []


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		if not parsed is Dictionary:
			push_warning("Brew: %s is missing or not valid JSON" % FILE)
			parsed = {}
		_data = parsed
	return _data


static func R() -> Dictionary:
	return data().get("rite", {})


static func C() -> Dictionary:
	return data().get("carry", {})


func setup(p_main: CrawlerMain) -> void:
	main = p_main
	name = "Brew"
	vision = BrewVision.new()
	vision.name = "BrewVision"
	if main.ui != null:
		main.ui.add_child(vision)
		# Under the crosshair, the panels and the harm view.
		main.ui.move_child(vision, 0)
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "BrewVoice"
	_voice.unit_size = 3.0
	add_child(_voice)
	var cam := main.player.camera() if main.player != null else null
	if cam != null:
		view = Node3D.new()
		view.name = "CuttingView"
		var v: Array = C().get("view", [-0.28, -0.34, -0.5])
		view.position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		# Held out low in the left hand, its strands toward the frame's foot.
		view.rotation = Vector3(deg_to_rad(65.0), 0.0, deg_to_rad(18.0))
		view.visible = false
		cam.add_child(view)


# --- What you carry --------------------------------------------------------------

## The cutting in your pack, or {}.
func carrying() -> Dictionary:
	if main == null or main.player == null:
		return {}
	for it in main.player.inventory.carried:
		if it is Dictionary and str((it as Dictionary).get("sacred", "")) != "":
			return it
	return {}


func _carried_count() -> int:
	var n := 0
	for it in main.player.inventory.carried:
		if it is Dictionary and str((it as Dictionary).get("sacred", "")) != "":
			n += 1
	return n


## A cutting of `vine`'s plant as a carried thing (Inventory's plant
## sample: part cutting, its species the entry's, never a catalogue index).
static func cutting_item(vine: SacredVine) -> Dictionary:
	var s := vine.sp
	return Inventory.make("plant_sample", {"species": -1, "sacred": vine.plant, "binomial": s.binomial() if s != null else vine.plant, "part": "cutting", "shape": "LIANA", "color": s.color.to_html(false) if s != null else "4e9a3c", "accent": s.accent.to_html(false) if s != null else "7a6e5e", "length_m": snappedf(vine.length_m * vine.take_share(), 0.01)})


# --- The button --------------------------------------------------------------------

## The interact button (CrawlerMain): true if harvest or brew took it.
func interact() -> bool:
	if main == null or main.leaving or main.player == null or main.player.dead:
		return false
	if main.on_surface:
		_harvest()
		# Nothing else answers the button up there (the bundle is below).
		return true
	if rite == "offer" and shaman != null and is_instance_valid(shaman) and _flat(main.player.global_position, shaman.global_position) <= float(R().get("drink_reach_m", 2.0)):
		drink()
		return true
	if rite != "":
		return false
	if carrying().is_empty():
		return false
	return begin_rite()


## Your hand to the vine, up on the surface.
func _harvest() -> String:
	var s := main.surface
	var vine: SacredVine = s.vine if s != null else null
	if vine == null or not vine.in_reach(main.player.eye_position()):
		return "far"
	if vine.lesson == "wait":
		# He shows you first (seen once).
		vine.begin_lesson()
		return "lesson"
	if vine.lesson_running():
		return "lesson"
	if _carried_count() >= maxi(int(C().get("max", 1)), 1) or not vine.can_take():
		vine.refuse()
		return "refused"
	var it := cutting_item(vine)
	if not main.player.inventory.add(it):
		vine.refuse()
		return "refused"
	vine.take()
	vine.takes += 1
	harvested += 1
	GameLog.add(str(C().get("log_take", "Took a cutting of the vine. It stands, and will grow back.")), "world")
	return "taken"


# --- The rite ------------------------------------------------------------------------

## Begin the hand-over and the brew (you at the hearth with a cutting): true
## if he can come to you (his way clear), and he rises.
func begin_rite() -> bool:
	if not main.baked or main.rescuer == null or not is_instance_valid(main.rescuer) or main.cauldron == null or not is_instance_valid(main.cauldron):
		return false
	var f := main.rescuer
	if not f.body.seated or rite != "":
		return false
	var H: Vector3 = main.lay.hearth
	if _flat(main.player.global_position, H) > float(R().get("hand_reach_m", 1.75)):
		return false
	if not plan(main.player.global_position):
		return false
	shaman = f
	motion = FolkMotion.new(f)
	motion.floor_y = H.y
	plant = str(carrying().get("sacred", SacredVine.plant_id()))
	_ladle_rest = f.ladle.transform if f.ladle != null else Transform3D.IDENTITY
	_go_to("rise")
	motion.rise_from_seat(seat_at)
	return true


## His way to you (you at `p`): where he stands beside you on the kerb, the
## side away from the torch bundle, and his way round the hearth there from
## a step off his stone (plan_way); false if no way is clear.
func plan(p: Vector3) -> bool:
	var space := main.player.get_world_3d().direct_space_state if main.player.is_inside_tree() else null
	var pl := plan_way(main.lay, main.cauldron, space, p, [main.player.get_rid()])
	if pl.is_empty():
		return false
	seat_at = pl.seat_at
	seat_yaw = float(pl.seat_yaw)
	seat_front = pl.seat_front
	stand = pl.stand
	way = pl.way
	return true


## The shaman's way to you at `p` in `lay`'s hearth room (its `cauldron`,
## the physics `space` it stands in, `exclude` the bodies a cast passes
## through: you): {"seat_at" (his seat's floor point), "seat_yaw",
## "seat_front" (a step off it), "stand" (beside you on the kerb,
## rite.beside_deg round from you at rite.stand_r_m, the side away from the
## torch bundle first, wider if need be), "way" (from seat_front round the
## hearth to stand)}; {} if no way is clear (_spot_clear).
static func plan_way(lay: Dictionary, cauldron: HearthCauldron, space: PhysicsDirectSpaceState3D, p: Vector3, exclude: Array) -> Dictionary:
	var H: Vector3 = lay.hearth
	var r: Array = lay.rescuer
	var seat := Vector3((r[0] as Vector3).x, H.y, (r[0] as Vector3).z)
	var yaw := float(r[1])
	var front := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var off_seat := seat + front * float(R().get("rise_step_m", 0.45))
	var tp := atan2(p.z - H.z, p.x - H.x)
	var bp: Vector3 = lay.get("bundle", H)
	var tb := atan2(bp.z - H.z, bp.x - H.x)
	var beside := deg_to_rad(float(R().get("beside_deg", 50.0)))
	var sr := float(R().get("stand_r_m", 1.15))
	# The side away from the bundle first, then the other; wider if need be.
	var signs: Array = [1.0, -1.0]
	if absf(wrapf(tp + beside - tb, -PI, PI)) < absf(wrapf(tp - beside - tb, -PI, PI)):
		signs = [-1.0, 1.0]
	for extra: float in [0.0, 15.0, 30.0]:
		for sg: float in signs:
			var ta := tp + sg * (beside + deg_to_rad(extra))
			var st := H + Vector3(cos(ta), 0.0, sin(ta)) * sr
			if not _spot_clear(lay, cauldron, space, exclude, st, p, 0.8):
				continue
			var w := _ring_way(lay, cauldron, space, exclude, off_seat, st, tp, p)
			if w.is_empty():
				continue
			return {"seat_at": seat, "seat_yaw": yaw, "seat_front": off_seat, "stand": st, "way": w}
	return {}


## A way from `a` to `b` round the hearth: out to the walking ring
## (rite.walk_r_m, else a little in or out), round it the way that never
## passes `avoid` (your angle round the hearth), in to `b`; every point of
## it clear (_way_clear). [] if none.
static func _ring_way(lay: Dictionary, cauldron: HearthCauldron, space: PhysicsDirectSpaceState3D, exclude: Array, a: Vector3, b: Vector3, avoid: float, p: Vector3) -> PackedVector3Array:
	var H: Vector3 = lay.hearth
	var wr := float(R().get("walk_r_m", 1.8))
	var ta := atan2(a.z - H.z, a.x - H.x)
	var tb := atan2(b.z - H.z, b.x - H.x)
	var d := wrapf(tb - ta, -PI, PI)
	var da := wrapf(avoid - ta, -PI, PI)
	if (d > 0.0 and da > 0.0 and da < d) or (d < 0.0 and da < 0.0 and da > d):
		d -= TAU * signf(d)
	for rr: float in [wr, wr - 0.15, wr + 0.2, wr + 0.4]:
		var pts := PackedVector3Array([a])
		var steps := maxi(int(ceil(absf(d) * rr / 0.3)), 1)
		for i in steps + 1:
			var t := ta + d * float(i) / steps
			pts.append(H + Vector3(cos(t), 0.0, sin(t)) * rr)
		pts.append(b)
		if _way_clear(lay, cauldron, space, exclude, pts, p):
			return pts
	return PackedVector3Array()


## Every 15 cm of `pts` clear (_spot_clear), you at `p` kept at least 0.6 m
## off.
static func _way_clear(lay: Dictionary, cauldron: HearthCauldron, space: PhysicsDirectSpaceState3D, exclude: Array, pts: PackedVector3Array, p: Vector3) -> bool:
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var b := pts[k]
		var n := maxi(int(ceil(a.distance_to(b) / 0.15)), 1)
		for i in n + 1:
			if not _spot_clear(lay, cauldron, space, exclude, a.lerp(b, float(i) / n), p, 0.6):
				return false
	return true


## Can he stand at `q` (the floor): his body (rite.clear_m round, from his
## shins to his shoulders) in none of the stone (the walls, the pillars, his
## own seat), rite.bundle_m off the torch bundle, rite.feet_m off the
## tripod's feet, `keep` m off you at `p`.
static func _spot_clear(lay: Dictionary, cauldron: HearthCauldron, space: PhysicsDirectSpaceState3D, exclude: Array, q: Vector3, p: Vector3, keep: float) -> bool:
	if _flat(q, p) < keep:
		return false
	var bp: Vector3 = lay.get("bundle", Vector3(INF, 0.0, INF))
	if _flat(q, bp) < float(R().get("bundle_m", 0.45)):
		return false
	if cauldron != null and is_instance_valid(cauldron):
		for ft in cauldron.feet:
			if _flat(q, cauldron.to_global(ft)) < float(R().get("feet_m", 0.3)):
				return false
	if space == null:
		return true
	var shape := CapsuleShape3D.new()
	shape.radius = float(R().get("clear_m", 0.24))
	shape.height = 1.4
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.shape = shape
	qp.collision_mask = PropCollision.WORLD_LAYER
	var ex: Array[RID] = []
	for x in exclude:
		ex.append(x)
	qp.exclude = ex
	qp.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, (lay.hearth as Vector3).y + 0.15 + 0.7, q.z))
	return space.intersect_shape(qp, 1).is_empty()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _go_to(step: String) -> void:
	rite = step
	_rt = 0.0
	if step != "":
		steps_seen.append(step)


## Drink the ladleful he holds out: the vision begins (its plant's).
func drink() -> void:
	if rite != "offer":
		return
	if fill != null and is_instance_valid(fill):
		fill.queue_free()
	fill = null
	drinks += 1
	vision.start(plant, (SacredVine.plant_data(plant)).get("vision", {}))
	_say(main.player.eye_position(), 1.25, -10.0)
	GameLog.add(str(R().get("log_drink", "Drank the shaman's brew.")), "world")
	_go_to("lower")


func _physics_process(delta: float) -> void:
	if main == null:
		return
	_surface_step(delta)
	if main.on_surface:
		return
	if rite == "":
		return
	if shaman == null or not is_instance_valid(shaman) or shaman != main.rescuer or not shaman.is_inside_tree():
		# A new tomb (the stand-in): the rite is gone with the old one.
		reset()
		return
	_rt += delta
	_rite_step(delta)
	if motion != null:
		motion.update(delta)


## The surface's lesson: the shaman by the vine the first time you come up
## (unless this game's save has it seen), his lesson while you're there, and
## gone once you come down from it.
func _surface_step(delta: float) -> void:
	var up := main.on_surface
	var s := main.surface
	var vine: SacredVine = s.vine if s != null and is_instance_valid(s) else null
	if up and vine != null:
		var T: Dictionary = data().get("teach", {})
		if not vine.taught and (not bool(T.get("on", true)) or (bool(T.get("kept", true)) and bool(CrawlerSave.kept_value(CrawlerSave.place, "harvest_taught", false)))):
			vine.taught = true
			vine.lesson = "done"
		if not vine.taught and vine.teacher == null and main.rescuer != null and is_instance_valid(main.rescuer):
			vine.add_teacher({"height_m": main.rescuer.height, "pal": main.rescuer.palette, "beast": main.rescuer.beast})
		var was := vine.taught
		vine.lesson_step(delta, main.player)
		if vine.taught and not was and bool(T.get("kept", true)):
			CrawlerSave.keep(CrawlerSave.place, "harvest_taught", true)
	elif _was_up and vine != null:
		vine.left_surface()
	_was_up = up


func _rite_step(delta: float) -> void:
	var f := shaman
	var H: Vector3 = main.lay.hearth
	var p := main.player.global_position
	var to_you := Vector3(p.x - f.global_position.x, 0.0, p.z - f.global_position.z)
	var to_pot := Vector3(H.x - f.global_position.x, 0.0, H.z - f.global_position.z)
	var k := motion.scale()
	match rite:
		"rise":
			var rs := maxf(float(R().get("rise_s", 0.8)), 0.1)
			var t := smoothstep(0.0, rs, _rt)
			f.global_position = seat_at.lerp(seat_front, t)
			if _rt >= rs * 0.4:
				motion.stand_up()
			if _rt >= rs:
				motion.walk_to(way)
				_go_to("go")
		"go":
			if motion.walk(delta, float(R().get("walk_mps", 0.85)), float(R().get("turn_dps", 200.0))):
				_go_to("face_you")
		"face_you":
			# Turned to you; and if you've stepped away, he waits for you.
			motion.turn_toward(to_you.normalized() if to_you.length() > 0.05 else motion.front(), delta, float(R().get("turn_dps", 200.0)))
			if (motion.faces(to_you) or _rt > 1.5) and to_you.length() <= float(R().get("drink_reach_m", 2.0)):
				_go_to("take")
		"take":
			var ts := maxf(float(R().get("take_s", 1.4)), 0.2)
			var hand := p.lerp(f.global_position, 0.45) + Vector3.UP * 1.05 * k
			if _rt <= delta * 1.5:
				motion.reach(0, hand)
			else:
				motion.reach_point(0, hand)
			if _rt >= ts * 0.55 and cutting == null:
				_take_cutting()
			if _rt >= ts * 0.6:
				motion.release(0)
			if _rt >= ts:
				_go_to("face_pot")
		"face_pot":
			motion.turn_toward(to_pot.normalized() if to_pot.length() > 0.05 else motion.front(), delta, float(R().get("turn_dps", 200.0)))
			if motion.faces(to_pot) or _rt > 1.5:
				_go_to("drop")
		"drop":
			var ds := maxf(float(R().get("drop_s", 1.3)), 0.2)
			var mouth := main.cauldron.mouth()
			if _rt <= delta * 1.5:
				motion.reach(0, mouth + Vector3.UP * 0.1)
			if _rt >= ds * 0.45 and _fall < 0.0 and cutting != null:
				_fall = 0.0
				_fall_from = motion.fist(0)
			if _rt >= ds * 0.6:
				motion.release(0)
			if _rt >= ds and _fall < 0.0:
				_go_to("stir")
		"stir":
			var ss := maxf(float(R().get("stir_s", 6.0)), 0.5)
			var hz := float(R().get("stir_hz", 0.5))
			var sr := float(R().get("stir_r_m", 0.07))
			var a := TAU * hz * _rt
			var into := main.cauldron.mouth() + Vector3(cos(a), 0.0, sin(a)) * sr - Vector3.UP * 0.08
			_ladle_mode = "stir"
			_ladle_at = into
			var fist_want := _ladle_fist_for(into, "stir")
			if _rt <= delta * 1.5:
				motion.reach(1, fist_want)
			else:
				motion.reach_point(1, fist_want)
			if _rt >= ss:
				_go_to("fill")
		"fill":
			var fs := maxf(float(R().get("fill_s", 1.0)), 0.2)
			var t2 := smoothstep(0.0, fs, _rt)
			var up_to := main.cauldron.mouth() + Vector3.UP * lerpf(-0.04, 0.32, t2) - to_pot.normalized() * 0.1
			_ladle_mode = "hold"
			_ladle_at = up_to
			motion.reach_point(1, _ladle_fist_for(up_to, "hold"))
			if _rt >= fs * 0.5 and fill == null:
				_fill_ladle()
			if _rt >= fs:
				_go_to("face_you2")
		"face_you2":
			var up_to2 := main.cauldron.mouth() + Vector3.UP * 0.32 - to_pot.normalized() * 0.1
			_ladle_at = up_to2
			motion.reach_point(1, _ladle_fist_for(up_to2, "hold"))
			motion.turn_toward(to_you.normalized() if to_you.length() > 0.05 else motion.front(), delta, float(R().get("turn_dps", 200.0)))
			if motion.faces(to_you) or _rt > 1.5:
				_go_to("offer")
		"offer":
			# The ladleful held out in front of your eyes, waiting.
			var eye := main.player.eye_position()
			var toward := Vector3(f.global_position.x - eye.x, 0.0, f.global_position.z - eye.z)
			toward = toward.normalized() if toward.length() > 0.05 else -motion.front()
			var cup := eye + toward * 0.42 - Vector3.UP * 0.12
			_ladle_at = cup
			motion.reach_point(1, _ladle_fist_for(cup, "hold"))
			motion.turn_toward(to_you.normalized() if to_you.length() > 0.05 else motion.front(), delta, 90.0)
		"lower":
			motion.release(1)
			if _rt >= maxf(float(R().get("lower_s", 0.6)), 0.1):
				_ladle_mode = ""
				if f.ladle != null:
					f.ladle.transform = _ladle_rest
				motion.walk_to(_reversed(way))
				_go_to("home")
		"home":
			if motion.walk(delta, float(R().get("walk_mps", 0.85)), float(R().get("turn_dps", 200.0))):
				_go_to("face_seat")
		"face_seat":
			var fr := Vector3(-sin(seat_yaw), 0.0, -cos(seat_yaw))
			motion.turn_toward(fr, delta, float(R().get("turn_dps", 200.0)))
			if motion.faces(fr, 2.0) or _rt > 1.5:
				motion.crouch(1.0)
				_go_to("sit")
		"sit":
			var sts := maxf(float(R().get("sit_s", 0.9)), 0.1)
			f.global_position = seat_front.lerp(seat_at, smoothstep(0.0, sts, _rt))
			if _rt >= sts:
				motion.sit_at(seat_at, seat_yaw)
				_go_to("")
				shaman = null
				motion = null


static func _reversed(pts: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(pts[i])
	return out


## He takes the cutting from you: out of your pack, into his left hand.
func _take_cutting() -> void:
	var inv := main.player.inventory
	var len_m := 0.3
	for i in inv.carried.size():
		var it = inv.carried[i]
		if it is Dictionary and str((it as Dictionary).get("sacred", "")) != "":
			len_m = float((it as Dictionary).get("length_m", 0.3))
			inv.take(i)
			break
	handed += 1
	_cutting_len = clampf(len_m, 0.15, 0.6)
	cutting = SacredVine.cutting_node(SacredVine.species_of(plant), _cutting_len)
	add_child(cutting)


## The ladleful: his ladle's bowl full of the brew; the pot's served out.
func _fill_ladle() -> void:
	var f := shaman
	if f.ladle == null:
		return
	fill = _disc(_brew_color(), maxf(float((HearthFolk.RES.get("ladle", {}) as Dictionary).get("bowl_r_m", 0.05)) - 0.008, 0.01), 0.004)
	fill.name = "BrewFill"
	f.ladle.add_child(fill)
	var o: Vector3 = f.ladle.get_meta("opens", Vector3.UP)
	fill.transform = Transform3D(_axis_to(o), _bowl_local() - o.normalized() * 0.012)
	if pot_brew != null and is_instance_valid(pot_brew):
		pot_brew.queue_free()
	pot_brew = null


## The brew in the pot (when the cutting falls in): a dark round of it under
## the pot's lip, on the cauldron's own layer (lit by its fire from below,
## never by the hearth's light over the mouth: HearthCauldron.LAYER).
func _pour_pot() -> void:
	var c := main.cauldron
	if c == null or not is_instance_valid(c):
		return
	if pot_brew != null and is_instance_valid(pot_brew):
		pot_brew.queue_free()
	pot_brew = _disc(_brew_color(), c.mouth_r() * 0.96, 0.01)
	pot_brew.name = "Brew"
	pot_brew.layers = HearthCauldron.LAYER
	c.add_child(pot_brew)
	pot_brew.position = Vector3(0.0, c.mouth_y - 0.1, 0.0)
	_say(c.mouth(), 0.9, -8.0)


func _brew_color() -> Color:
	return Color(str(SacredVine.plant_data(plant).get("brew_color", "#3b2f22")))


## A flat round of the brew (diffuse only, §ES), `r` across its half and
## `h` thick, its face up its local +y.
static func _disc(col: Color, r: float, h: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = _disc_mesh(r, h)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The drums made so far, by size (kept for the session: the brew's rounds
## come and go, their meshes stay).
static var _disc_meshes := {}


## A low drum `r` round and `h` high, its middle at its origin: its top and
## bottom fans and its side, 12 round.
static func _disc_mesh(r: float, h: float) -> ArrayMesh:
	var key := "%.4f:%.4f" % [r, h]
	if _disc_meshes.has(key):
		return _disc_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var top := h * 0.5
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		for tri: Array in [[Vector3(0.0, top, 0.0), p1 + Vector3.UP * top, p0 + Vector3.UP * top, Vector3.UP], [Vector3(0.0, -top, 0.0), p0 - Vector3.UP * top, p1 - Vector3.UP * top, Vector3.DOWN]]:
			st.set_normal(tri[3])
			for k in 3:
				st.add_vertex(tri[k])
		var out := ((p0 + p1) * 0.5).normalized()
		for v: Vector3 in [p0 + Vector3.UP * top, p1 + Vector3.UP * top, p1 - Vector3.UP * top, p0 + Vector3.UP * top, p1 - Vector3.UP * top, p0 - Vector3.UP * top]:
			st.set_normal(out)
			st.add_vertex(v)
	var cm := st.commit()
	_disc_meshes[key] = cm
	return cm


## A turn that takes +y to `dir`.
static func _axis_to(dir: Vector3) -> Basis:
	var y := dir.normalized() if dir.length() > 1e-4 else Vector3.UP
	var x := Vector3.RIGHT - y * y.dot(Vector3.RIGHT)
	x = x.normalized() if x.length() > 0.1 else y.cross(Vector3.BACK).normalized()
	return Basis(x, y, x.cross(y))


## The middle of the ladle's bowl at its rim, in the ladle's own frame
## (HearthFolk.ladle_mesh: the handle up +y to its top, the rim's middle
## off it across the bowl).
func _bowl_local() -> Vector3:
	var ld: Dictionary = HearthFolk.RES.get("ladle", {})
	var length := maxf(float(ld.get("handle_m", 0.82)), 0.2)
	var below := clampf(float(ld.get("below_fist_m", 0.1)), 0.0, length * 0.5)
	var br := maxf(float(ld.get("bowl_r_m", 0.05)), 0.02)
	var y1 := length - below
	var o: Vector3 = Vector3.UP
	if shaman != null and shaman.ladle != null:
		o = shaman.ladle.get_meta("opens", Vector3.UP)
	var ob := o.normalized()
	var across := Vector3.UP - ob * Vector3.UP.dot(ob)
	across = across.normalized() if across.length() > 1e-4 else Vector3.RIGHT
	return Vector3(0.0, y1, 0.0) + across * br


## The ladle's turn for the work (scene, unscaled): "stir", its handle from
## his fist into the pot toward `at`; "hold", its bowl's opening up and its
## handle leaning back from the bowl toward him (so the bowl sits ahead of
## his fist, toward `at`).
func _ladle_basis(mode: String, at: Vector3, fist_now: Vector3) -> Basis:
	if mode == "stir":
		return _axis_to(at - fist_now)
	var o: Vector3 = shaman.ladle.get_meta("opens", Vector3.UP) if shaman.ladle != null else Vector3.UP
	var e1 := o.normalized()
	var e2 := Vector3.UP - e1 * e1.dot(Vector3.UP)
	e2 = e2.normalized() if e2.length() > 1e-3 else e1.cross(Vector3.RIGHT).normalized()
	var e3 := e1.cross(e2)
	var lean := Vector3(at.x - shaman.global_position.x, 0.0, at.z - shaman.global_position.z)
	lean = lean.normalized() if lean.length() > 1e-3 else motion.front()
	var f1 := Vector3.UP
	var f2 := lean
	var f3 := f1.cross(f2)
	return Basis(f1, f2, f3) * Basis(e1, e2, e3).transposed()


## Where his right fist goes so the ladle (turned for `mode`) has its bowl
## at `at` (scene).
func _ladle_fist_for(at: Vector3, mode: String) -> Vector3:
	var k := motion.scale()
	if mode == "stir":
		# Into the pot from a little short of it, along the way from his
		# shoulder.
		var sh := (shaman.body.arms[1] as Node3D).global_position
		var dir := (at - sh).normalized()
		var length := maxf(float((HearthFolk.RES.get("ladle", {}) as Dictionary).get("handle_m", 0.82)), 0.2) - float((HearthFolk.RES.get("ladle", {}) as Dictionary).get("below_fist_m", 0.1))
		return at - dir * length * k
	var b := _ladle_basis("hold", at, at)
	return at - b * (_bowl_local() * k)


func _process(_delta: float) -> void:
	if main == null:
		return
	_place_props()
	_update_view()


## The props each frame, where his hands are now: the cutting in his left
## fist (or falling into the pot), the ladle turned for the work.
func _place_props() -> void:
	# (Up on the surface the dungeon, and he, are out of the tree: the rite
	# waits.)
	if main.on_surface or shaman == null or not is_instance_valid(shaman) or not shaman.is_inside_tree():
		return
	if cutting != null and is_instance_valid(cutting) and motion != null:
		if _fall >= 0.0:
			_fall += get_process_delta_time()
			var s := clampf(_fall / 0.35, 0.0, 1.0)
			var mouth := main.cauldron.mouth()
			cutting.global_transform = Transform3D(Basis.IDENTITY, _fall_from.lerp(mouth, s) + Vector3.UP * 0.22 * sin(PI * s))
			if s >= 1.0:
				cutting.queue_free()
				cutting = null
				_fall = -1.0
				_pour_pot()
		else:
			cutting.global_transform = Transform3D(Basis.IDENTITY, motion.fist(0))
	if shaman.ladle == null or motion == null:
		return
	var w := motion.reached(1) if _ladle_mode != "" else 0.0
	_ladle_w = w
	var e := motion.elbow(1)
	if e == null:
		return
	if w <= 0.0:
		_ladle_eased = false
		if _ladle_mode == "" and rite != "":
			shaman.ladle.transform = _ladle_rest
		return
	var fist_now := e.global_transform * HearthFolk.FIST
	var k := motion.scale()
	var rest := (e.global_transform * _ladle_rest).basis.orthonormalized()
	var want := _ladle_basis(_ladle_mode, _ladle_at, fist_now).orthonormalized()
	var q := Quaternion(rest).slerp(Quaternion(want), w)
	# Eased, so a change of work (the stir to the lift) turns it, never
	# snaps it.
	if _ladle_eased:
		q = _ladle_q.slerp(q, clampf(1.0 - exp(-14.0 * get_process_delta_time()), 0.0, 1.0))
	_ladle_q = q
	_ladle_eased = true
	shaman.ladle.global_transform = Transform3D(Basis(q).scaled(Vector3.ONE * k), fist_now)


## The cutting low in your left hand, in view, while you carry it and that
## hand holds no fire pot.
func _update_view() -> void:
	if view == null:
		return
	var it := carrying()
	var pot := main.fire_pots.in_left() if main.fire_pots != null else {}
	var show := not it.is_empty() and pot.is_empty() and main.player.first_person and not main.player.dead
	view.visible = show
	if show and _view_plant != str(it.get("sacred", "")):
		for c in view.get_children():
			c.queue_free()
		_view_plant = str(it.get("sacred", ""))
		var cn := SacredVine.cutting_node(SacredVine.species_of(_view_plant), float(C().get("view_len_m", 0.3)), 0.35)
		view.add_child(cn)


## The rite gone (a new tomb, or the game starting over): its props freed,
## the one at the hearth (if he is still there) back on his stone.
func reset() -> void:
	if cutting != null and is_instance_valid(cutting):
		cutting.queue_free()
	cutting = null
	_fall = -1.0
	if pot_brew != null and is_instance_valid(pot_brew):
		pot_brew.queue_free()
	pot_brew = null
	if fill != null and is_instance_valid(fill):
		fill.queue_free()
	fill = null
	if shaman != null and is_instance_valid(shaman):
		if shaman.ladle != null:
			shaman.ladle.transform = _ladle_rest
		if motion != null:
			motion.release(0)
			motion.release(1)
			motion.sit_at(seat_at, seat_yaw)
			for s in 2:
				(shaman.body.arms[s] as Node3D).rotation = Vector3(PlayerBody.ARM_REST.x, 0.0, PlayerBody.ARM_REST.z * (-1.0 if s == 0 else 1.0))
	_ladle_mode = ""
	shaman = null
	motion = null
	rite = ""
	_rt = 0.0


func _say(at: Vector3, pitch: float, db: float) -> void:
	if _voice == null or not _voice.is_inside_tree():
		return
	_voice.global_position = at
	_voice.stream = SoundSynth.stream("drip", drinks + handed)
	_voice.pitch_scale = pitch
	_voice.volume_db = db
	Audio3D.play(_voice)
