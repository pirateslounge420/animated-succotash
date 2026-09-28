class_name Hits
## Hit parts and hit feedback (the designer's item 10, "PSO-style health
## and hit feedback"): where a hit lands on a creature, what that does to
## it, and what the player sees of it. Creature health is never drawn:
## the numbers and the animal's behaviour (limping, fleeing, going down)
## are the only readout.
##
## Parts. Every hitbox part (Hitboxes) carries its kind in the "hit_part"
## meta: "body", "head", "limb", or an eye: "eye_l" / "eye_r" (its side,
## the body facing -Z with +X its right) or "eye" (a single eye, the Pond
## Crawler's). They're marked where the hitboxes are built (mark():
## CreatureHitboxes for the ordinary creatures and the camp folk,
## GibbonHitboxes, NightRider, PondCrawler); eyes are small spheres over
## the drawn eyes (eye_radius()). A part left unmarked is "body".
##
## What a part does is the creature's data (creatures.json "hit_parts",
## CreatureSpecies.hit_table()): a damage multiplier per kind (head 2x,
## eye 4x), limb_slow (a limb hit slows it, Creature.lame) and eye_blinds
## (an eye hit blinds that side: it notices you there only at
## hits.blind_notice of its flight distance, Creature.sight_toward()).
## Critical parts (head and eye) are data/combat.json's
## hits.critical_parts.
##
## One way in for the weapons: strike() (Arrow, ThrownSpear, Spear's
## thrust). A creature's own hurt(amount, from_pos, part, at) applies the
## multiplier and the wound and reports the hit (report()). Camp folk
## have no hurt(): they complain (Camps.shot_at()) and the hit reads like
## any other (the folk's table, a number and the X), but no one is harmed.
##
## Reports: one event per target per moment (hits on one target within
## feedback.number.combine_s add up to one number), read by the HUD
## (since(), StatusHud): a number rising from the impact point and, on a
## critical or a kill, the crosshair's X. Like NoiseEvents: creatures
## write, the HUD reads; neither calls the other.
##
## Tunables: data/combat.json ("hits", "feedback", "healing"; data()).

const DATA_PATH := "res://data/combat.json"
## Events are kept this many physics frames, long past any reader.
const KEEP_FRAMES := 240
## Used for anything the file leaves out (and warned about once).
const FALLBACK := {
	"hits": {"critical_parts": ["head", "eye"], "eye_radius_scale": 2.5, "eye_min_radius_m": 0.02, "eyes_from_size_m": 0.3,
		"blind_notice": 0.3, "limp_roll_deg": 7.0},
	"feedback": {
		"number": {"rise_m": 0.7, "life_s": 1.0, "fade_s": 0.35, "size_px": 15, "ref_distance_m": 8.0, "distance_power": 0.5,
			"min_px": 11, "max_px": 19, "max_on_screen": 4, "combine_s": 0.017},
		"colors": {"normal": "#FFFFFF", "critical": "#FFD23A", "outline": "#0A1250"},
		"crit_x": {"hold_s": 0.12, "kill_hold_s": 0.4, "size_px": 10, "gap_px": 3, "width_px": 2.0, "color": "#FFFFFF", "kill_color": "#FFD23A"},
		"sound": {"volume_db": -8.0, "pitch": 1.0, "kill_pitch": 0.78},
		"meter": {"width_px": 150, "height_px": 5, "fill": "#4C7CFF", "track": "#0A14A0", "edge": "#7FB0FF", "low_share": 0.25, "numeral_px": 13}},
	"healing": {"rest_radius_m": 4.0, "rest_still_s": 2.0, "rest_hp_per_s": 1.5, "sources": {"cooked_food": 20, "camp_medicine": 45}},
}

static var _data := {}
## {id, target (Node3D), local (the impact point in the target's space),
## pos (scene position, if the target is gone), amount, crit, killed,
## frame (physics frame reported)}, oldest first.
static var _events: Array = []
static var _next_id := 1
## Stands in for the camp folk's species (the file's hit_parts block).
static var _folk: CreatureSpecies


## data/combat.json over FALLBACK, loaded once.
static func data() -> Dictionary:
	if _data.is_empty():
		_data = FALLBACK.duplicate(true)
		if FileAccess.file_exists(DATA_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
			if parsed is Dictionary:
				_merge(_data, parsed)
			else:
				push_warning("Hits: %s is not valid JSON, using defaults" % DATA_PATH)
		else:
			push_warning("Hits: no %s, using defaults" % DATA_PATH)
	return _data


static func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if into.get(k) is Dictionary and from[k] is Dictionary:
			_merge(into[k], from[k])
		else:
			into[k] = from[k]


static func hits() -> Dictionary:
	return data().hits


static func feedback() -> Dictionary:
	return data().feedback


static func healing() -> Dictionary:
	return data().healing


# --- Parts ---------------------------------------------------------------------

## Mark a part (a Hitboxes body, or one shape of a body carrying several)
## with its kind: "body", "head", "limb", "eye_l", "eye_r" or "eye".
static func mark(part: Node, kind: String) -> Node:
	part.set_meta("hit_part", kind)
	return part


## The part a physics query met (`collider` and its `shape` index), or
## "body" if it isn't marked.
static func part_of(collider: Object, shape: int) -> String:
	if collider == null:
		return "body"
	var node := Arrow._shape_node(collider, shape)
	if node != null and node.has_meta("hit_part"):
		return str(node.get_meta("hit_part"))
	return str(collider.get_meta("hit_part", "body"))


## "eye_l" -> "eye".
static func kind_of(part: String) -> String:
	return part.get_slice("_", 0)


## "eye_l" -> "l", "eye" -> "".
static func side_of(part: String) -> String:
	return part.get_slice("_", 1) if part.contains("_") else ""


static func critical(part: String) -> bool:
	return force_critical or kind_of(part) in (hits().critical_parts as Array)


## A super shot's hits are all critical (design §S): set around its
## strike().
static var force_critical := false
## Called with (critical: bool) whenever a strike lands on a creature (all
## strikes are the player's weapons): the player's super meter.
static var on_hit := Callable()


## What `amount` becomes on `part` of a creature with hit table `table`
## (CreatureSpecies.hit_table()).
static func dealt(table: Dictionary, part: String, amount: float) -> float:
	return amount * float(table.get(kind_of(part), 1.0))


## An eye's hit sphere radius, in its parent's units, for a drawn eye of
## radius `drawn` there on a body scaled `scale_m` (meters per unit).
static func eye_radius(drawn: float, scale_m: float) -> float:
	var h := hits()
	return maxf(drawn * float(h.eye_radius_scale), float(h.eye_min_radius_m) / maxf(scale_m, 1e-3))


# --- The one way in --------------------------------------------------------------

## A weapon met `collider` (its `shape`) at scene position `at`, fired
## or swung from `from_pos`, for `amount`: a creature is hurt there (its
## hurt(), with the part), a camp person complains (`camps`). Returns who
## was hit (null: nobody's part).
static func strike(collider: Object, shape: int, amount: float, from_pos: Vector3, at: Vector3, camps: Camps) -> Node:
	var who := Hitboxes.creature_of(collider)
	if who == null:
		return null
	var part := part_of(collider, shape)
	if who.has_method("hurt"):
		who.hurt(amount, from_pos, part, at)
		if on_hit.is_valid():
			on_hit.call(critical(part))
	else:
		if _folk == null:
			_folk = CreatureSpecies.new()
		report(who as Node3D, at, dealt(_folk.hit_table(), part, amount), critical(part), false)
		if camps:
			camps.shot_at(who)
	return who


# --- Reports -----------------------------------------------------------------------

## A hit on `target` at scene position `at` (INF: its middle) for
## `amount`, critical or not, and whether it killed. Hits on the same
## target within combine_s add up into one.
static func report(target: Node3D, at: Vector3, amount: float, crit: bool, killed: bool) -> void:
	var now := Engine.get_physics_frames()
	_prune(now)
	if at == Vector3.INF:
		at = target.global_position if target else Vector3.ZERO
	var tid := target.get_instance_id() if target else 0
	for e in _events:
		if int(e.tid) == tid and now - int(e.frame) < _combine_frames():
			e.amount += amount
			e.crit = e.crit or crit
			e.killed = e.killed or killed
			return
	_events.append({"id": _next_id, "tid": tid, "ref": weakref(target) if target else null,
		"local": target.to_local(at) if target else at, "pos": at,
		"amount": amount, "crit": crit, "killed": killed, "frame": now})
	_next_id += 1


## Where an event's impact point is now (scene position): on its target
## as it moves (and as the floating origin shifts), or where it was if
## the target is gone.
static func where(e: Dictionary) -> Vector3:
	var t: Node3D = e.ref.get_ref() if e.ref != null else null
	if t != null and t.is_inside_tree():
		return t.to_global(e.local)
	return e.pos


## The events newer than `last_id` whose combining window has closed
## (so each is final): [{id, tid, ref (a WeakRef to the target), local,
## pos, amount, crit, killed, frame}], oldest first.
static func since(last_id: int) -> Array:
	var now := Engine.get_physics_frames()
	var out: Array = []
	for e in _events:
		if int(e.id) > last_id and now - int(e.frame) >= _combine_frames():
			out.append(e)
	return out


## The last event reported (open or closed), or {} (tests).
static func last() -> Dictionary:
	return _events.back() if not _events.is_empty() else {}


static func clear() -> void:
	_events.clear()


static func _combine_frames() -> int:
	var s := float((feedback().number as Dictionary).combine_s)
	return maxi(1, roundi(s * Engine.physics_ticks_per_second))


static func _prune(now: int) -> void:
	while not _events.is_empty() and now - int(_events[0].frame) > KEEP_FRAMES:
		_events.pop_front()
