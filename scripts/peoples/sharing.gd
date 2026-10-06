class_name Sharing
## Food passed round, and the gift (design 5 Oct §EJ; camps.json →
## sim.sharing). Mute throughout; a line in the log, never a speech (§BL).
##
## The meal (§EJ.1): the food store shows PIECES, one piece a day's eating
## for the camp (CampSim.eat_per_day). The sim eats every tick as before
## (no accounting change); what is eaten is made visible once a day: at the
## meal (dusk_form's end, gather end + dusk_form.over_game_h) the store's
## shown pieces fall by piece_off_store_per_meal, and by nothing at other
## times. What comes in (gathering, a hunt, the player) adds a piece for
## each day's eating of it. In the camp, an adult (never the one who
## hunted that day, §EJ.2) stands, walks to the store, takes the piece
## off, carries it to the fire and sits; then every seated folk eats from
## a bowl (the circle's eat_bowl). The player standing in the circle gets
## a bowl in hand for as long (player_gets_bowl), and the log says so once
## per camp (player_log_once). Nothing changes a stat.
##
## One store per camp (private_stores false): food and wood are the camp's,
## never a folk's (CampSim.one_store). Nobody commands another
## (no_folk_commands_another): no idle has one folk standing over another.
##
## The gift (§EJ.4, gift_back): CampSim counts the units the player puts on
## a camp's store; past after_player_brings_units the gift is due, and at
## the next dusk_form with the player near, the record-keeper (§EN, when
## the camp has one) or an adult walks up, holds out one thing the camp
## could make, and it goes in the pack; once per camp.

static var S: Dictionary = (Tuning.section("camps", "sim").get("sharing", {}) as Dictionary)
static var DUSK: Dictionary = (((Tuning.section("camps", "sim").get("fire_circle", {}) as Dictionary).get("dusk_form", {})) as Dictionary)
## The most pieces a food store shows (the rack's eight, eight below).
const MAX_PIECES := 16
## The player's camera (Main sets it): the bowl in hand hangs from it.
static var player_cam: Camera3D = null
## The checks: walks happen at once.
static var instant := false


# --- The sim ------------------------------------------------------------------

static func gather_end() -> float:
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	return float(gh[1])


## The local hour of the meal: dusk_form's end, after the last load is in.
static func meal_h() -> float:
	return gather_end() + float(DUSK.get("over_game_h", 1.5))


## What the camp ate this tick (CampSim._tick): kept until the meal shows it.
static func ate(st: Dictionary, eat: float) -> void:
	st["eaten_since_meal"] = float(st.get("eaten_since_meal", 0.0)) + eat


## The camp's one store's shown pieces now.
static func pieces(st: Dictionary) -> int:
	return int(st.get("food_pieces", 0))


## The folk who hunted on local `day` (-1: none).
static func hunter_today(st: Dictionary, day: int) -> int:
	var hs: Dictionary = st.get("hunt", {})
	if int(hs.get("day", -999)) == day and hs.has("hunter"):
		return int(hs.hunter)
	return -1


## Who carries the meal on local `day`: an adult, never that day's hunter,
## turn by turn (a seeded pick).
static func carrier_of(st: Dictionary, day: int) -> int:
	var folk: Array = st.get("folk", [])
	var hunter := hunter_today(st, day)
	var ok: Array = []
	for i in folk.size():
		if CampSim.is_adult(folk[i]) and i != hunter:
			ok.append(i)
	if ok.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st.get("seed", 0)), day, "meal"])
	return int(ok[rng.randi() % ok.size()])


## Once a tick, after the eating and the hunt (CampSim._tick): the store's
## shown pieces, and the meal at its hour once a local day.
static func tick(cs: CampSim, st: Dictionary, days: float, h: float) -> void:
	var epd := maxf(cs.eat_per_day(st), 0.25)
	var m: Dictionary = st.get("meal", {})
	if m.is_empty():
		m = {"day": -999, "pieces": clampi(roundi(float(st.food) / epd), 0, MAX_PIECES), "v0": float(st.food), "n": 0}
		st["eaten_since_meal"] = 0.0
	# What came in since the meal adds pieces; what was eaten waits for it.
	var v := float(st.food) + float(st.get("eaten_since_meal", 0.0))
	var p := clampi(int(m.pieces) + int(floor(maxf(v - float(m.v0), 0.0) / epd)), 0, MAX_PIECES)
	# A store that holds far more than it shows (food set by a move, a
	# reroll): it shows it.
	var real := int(ceil(float(st.food) / epd))
	if p < real - 3:
		m.pieces = mini(real, MAX_PIECES)
		m.v0 = v
		p = int(m.pieces)
	var lon := CubeSphere.longitude(cs._dir(st)) / TAU
	var day := int(floor(days + lon))
	if bool(S.get("meal_at_dusk_form", true)) and int(m.day) != day and h >= meal_h():
		var before := p
		var after := maxi(before - int(S.get("piece_off_store_per_meal", 1)), 0)
		# A store that holds less than it shows (the camp went short): the
		# meal shows that too.
		if after > real + 1:
			after = clampi(real, 0, after)
		m = {"day": day, "pieces": after, "v0": float(st.food), "n": int(m.n) + 1, "at": days, "before": before,
			"carrier": carrier_of(st, day) if before > 0 else -1, "hunter": hunter_today(st, day), "empty": before == 0}
		st["eaten_since_meal"] = 0.0
		p = after
		var log: Array = st.get("meal_log", [])
		log.append({"day": day, "at": days, "before": before, "after": after, "carrier": m.carrier, "hunter": m.hunter})
		while log.size() > 30:
			log.pop_front()
		st["meal_log"] = log
		WorldSave.mark_dirty()
	st["meal"] = m
	if p != pieces(st):
		st["food_pieces"] = p
		WorldSave.mark_dirty()


## The player put `units` on this camp's store (Main): counted toward the
## gift.
static func brought(st: Dictionary, units: float) -> void:
	st["player_brought"] = float(st.get("player_brought", 0.0)) + units
	var g: Dictionary = S.get("gift_back", {})
	if bool(g.get("on", true)) and not bool(st.get("gift_given", false)) and float(st.player_brought) >= float(g.get("after_player_brings_units", 6)):
		st["gift_due"] = true
	WorldSave.mark_dirty()


## The gifts the camp could make now (gift_back.gifts): a torch from any
## fire; a bowl of stew while the store has food; a pot with pottery; a
## cord hank or a basket with cordage and basketry.
static func gifts_for(st: Dictionary) -> Array:
	var tr: Array = st.get("trades", [])
	var out: Array = []
	for g in (S.get("gift_back", {}) as Dictionary).get("gifts", []):
		match str(g):
			"torch":
				out.append(g)
			"bowl_of_stew":
				if float(st.get("food", 0.0)) > 0.0:
					out.append(g)
			"pot":
				if tr.has("pottery"):
					out.append(g)
			"cord_hank", "basket":
				if tr.has("cordage_basketry"):
					out.append(g)
	return out


## The one gift this camp gives (seeded by the camp).
static func gift_of(st: Dictionary) -> String:
	var all := gifts_for(st)
	if all.is_empty():
		return "torch"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(st.get("key", "")), "gift"])
	return str(all[rng.randi() % all.size()])


## Give camp `st`'s gift into `inv` now: false when it isn't due or was
## given. Logged (gift_back.log); the flag set, never again.
static func give(st: Dictionary, inv: Inventory) -> bool:
	if not bool(st.get("gift_due", false)) or bool(st.get("gift_given", false)):
		return false
	var kind := gift_of(st)
	var name := str(Inventory.kind_info(kind).get("name", kind.replace("_", " ")))
	var it := Inventory.make(kind, {"title": name})
	if kind == "torch":
		it = Inventory.make("torch")
	if inv != null and not inv.add(it):
		return false
	st["gift_given"] = true
	st["gift_due"] = false
	st["gift_kind"] = kind
	st["gift_count"] = int(st.get("gift_count", 0)) + 1
	var who := str(Peoples.get_people(str(st.get("people", ""))).get("name", "The")).trim_suffix(" folk")
	var line := str((S.get("gift_back", {}) as Dictionary).get("log", "{people} folk gave you a {gift}.")).replace("{people}", who).replace("{gift}", name.to_lower())
	GameLog.add_once("gift:" + str(st.get("key", "")), line, "camp")
	WorldSave.mark_dirty()
	return true


## No folk owns food or wood (private_stores false): true when every folk
## record is free of a store of its own.
static func one_store(st: Dictionary) -> bool:
	for f in st.get("folk", []):
		for k in (f as Dictionary).keys():
			if str(k) in ["food", "wood", "store", "stash"]:
				return false
	return true


# --- In the camp ------------------------------------------------------------------

## The pieces the store at camp node `camp` shows now: the sim's, and one
## more while the meal's piece is still on it.
static func shown(camp: Node3D, st: Dictionary) -> int:
	var anim: Dictionary = camp.get_meta("meal_anim", {})
	if not anim.is_empty() and not bool(anim.get("taken", false)):
		return mini(pieces(st) + int(S.get("piece_off_store_per_meal", 1)), MAX_PIECES)
	return pieces(st)


## One frame of the meal and the gift at camp node `camp` (its origin the
## fire; `holders` its cloaked folk, meta folk_i and home; `fs` its food
## store; `days` game time; `h` the local hour; `pp` the player; `inv` the
## player's pack). The folk walking for it are marked "sharing" (left out
## of the circle). Returns the holders still sitting for the circle.
static func live(camp: Node3D, st: Dictionary, holders: Array, fs: Node3D, days: float, h: float, time: float, delta: float, pp: Vector3, inv: Inventory) -> Array:
	if st.is_empty() or fs == null or not is_instance_valid(fs):
		return holders
	var m: Dictionary = st.get("meal", {})
	var seen := int(camp.get_meta("meal_seen", -1))
	if seen < 0:
		camp.set_meta("meal_seen", int(m.get("n", 0)))
	elif int(m.get("n", 0)) > seen:
		camp.set_meta("meal_seen", int(m.get("n", 0)))
		# A meal now (not one caught up from long ago): play it.
		if not bool(m.get("empty", true)) and days - float(m.get("at", -1e9)) < 3.0 / 24.0 and camp.get_meta("meal_anim", {}).is_empty():
			_start_meal(camp, st, holders, fs, int(m.get("carrier", -1)))
	var anim: Dictionary = camp.get_meta("meal_anim", {})
	if not anim.is_empty():
		_meal(camp, anim, fs, time, delta, holders, pp)
	_gift(camp, st, holders, h, time, delta, pp, inv)
	_bowl_in_hand(camp, time, delta)
	var out: Array = []
	for hv in holders:
		if is_instance_valid(hv) and not bool((hv as Node3D).get_meta("sharing", false)):
			out.append(hv)
	return out


static func _holder_of(holders: Array, i: int) -> Node3D:
	for hv in holders:
		if is_instance_valid(hv) and int((hv as Node3D).get_meta("folk_i", -1)) == i:
			return hv
	return null


static func _at_fire(h: Node3D) -> bool:
	return str(h.get_meta("going", "")) == "" and str(h.get_meta("station", "fire")) == "fire" and h.visible


static func _start_meal(camp: Node3D, st: Dictionary, holders: Array, fs: Node3D, carrier: int) -> void:
	var h := _holder_of(holders, carrier)
	if h == null or not _at_fire(h) or str(h.get_meta("stage", "adult")) != "adult":
		# The one whose turn it is isn't here: any adult at the fire who
		# didn't hunt today.
		h = null
		var hunter := int((st.get("meal", {}) as Dictionary).get("hunter", -1))
		for hv in holders:
			var n: Node3D = hv
			if is_instance_valid(n) and _at_fire(n) and str(n.get_meta("stage", "adult")) == "adult" and int(n.get_meta("folk_i", -1)) >= 0 and int(n.get_meta("folk_i", -1)) != hunter:
				h = n
				break
	var anim := {"leg": 0, "t": 0.0, "taken": false}
	if h == null or camp.has_meta("canopy"):
		# Nobody to walk it (or the canopy deck): the piece leaves the
		# store and the bowls go round.
		anim.taken = true
		anim.leg = 3
	else:
		var par := h.get_parent() as Node3D
		var sp: Vector3 = par.to_local(fs.global_position)
		var toward := Vector3(-sp.x, 0, -sp.z).normalized()
		var stand := sp + toward * 0.75
		stand.y = (h.transform.origin as Vector3).y
		anim.holder = h
		anim.seat = h.transform
		anim.stand = Transform3D(Basis.looking_at(-toward, Vector3.UP), stand)
		h.set_meta("sharing", true)
		h.set_meta("carried_meal", true)
		FireCircle._props(h, "")
		h.set_meta("idle", "")
		Workshop._stand(h, true)
	camp.set_meta("meal_anim", anim)


## The meal's walk: to the store (leg 0), the piece taken off (leg 1),
## back to the seat carrying it (leg 2), the bowls round (leg 3).
static func _meal(camp: Node3D, anim: Dictionary, fs: Node3D, time: float, delta: float, holders: Array, pp: Vector3) -> void:
	var speed := float((CampSim.SIM.get("jobs", {}) as Dictionary).get("walk_mps", 1.3))
	var h: Node3D = anim.get("holder") if anim.has("holder") else null
	if h != null and not is_instance_valid(h):
		h = null
		anim.leg = 3
		anim.taken = true
	anim.t = float(anim.t) + (1.0e6 if instant else delta)
	match int(anim.leg):
		0:
			if _move(h, anim.seat, anim.stand, float(anim.t), speed, delta):
				anim.leg = 1
				anim.t = 0.0
		1:
			if float(anim.t) > 1.4:
				# Off the store and into the hands.
				anim.taken = true
				_carry_prop(h, fs, true)
				anim.leg = 2
				anim.t = 0.0
		2:
			var back := Transform3D((anim.seat as Transform3D).basis, (anim.seat as Transform3D).origin)
			var from := Transform3D(Basis.looking_at(((anim.seat as Transform3D).origin - (anim.stand as Transform3D).origin).slide(Vector3.UP).normalized(), Vector3.UP), (anim.stand as Transform3D).origin)
			if _move(h, from, back, float(anim.t), speed, delta):
				h.transform = anim.seat
				h.set_meta("base_yaw", h.rotation.y)
				Workshop._stand(h, false)
				_carry_prop(h, fs, false)
				h.set_meta("sharing", false)
				anim.leg = 3
				anim.t = 0.0
		3:
			_bowls(camp, holders, time, pp)
			camp.set_meta("meal_anim", {})


## Walk `h` from `from` to `to` (parent frame), `t` seconds in: true when
## there.
static func _move(h: Node3D, from: Transform3D, to: Transform3D, t: float, speed: float, delta: float) -> bool:
	if h == null:
		return true
	var len_m := maxf(from.origin.distance_to(to.origin), 0.01)
	var k := clampf(t * speed / len_m, 0.0, 1.0)
	var dir := to.origin - from.origin
	dir.y = 0.0
	var b := Basis.looking_at(dir.normalized(), Vector3.UP) if dir.length() > 0.01 else to.basis
	h.transform = Transform3D(b if k < 1.0 else to.basis, from.origin.lerp(to.origin, k))
	var body := h.get_node_or_null("Body")
	if body != null and body is PlayerBody:
		var par := h.get_parent() as Node3D
		var v := dir.normalized() * speed if k < 1.0 else Vector3.ZERO
		(body as PlayerBody).set_velocity(par.global_basis * v if par != null else v)
		(body as PlayerBody).set_motion(0.35 if k < 1.0 else 0.0, delta)
	return k >= 1.0


## The piece in hand, the arms brought forward to carry it (the store's
## own colour), or put down.
static func _carry_prop(h: Node3D, fs: Node3D, on: bool) -> void:
	if h == null:
		return
	var old = h.get_meta("meal_piece") if h.has_meta("meal_piece") else null
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	h.remove_meta("meal_piece")
	_arms_forward(h, on)
	if not on:
		return
	var arms: Array = h.get_meta("arms", [])
	if arms.size() < 2:
		return
	var pal: Array = fs.get_meta("pal", [])
	var col: Color = pal[0] if not pal.is_empty() else Color(0.6, 0.45, 0.3)
	var p := CreatureBodies.box(arms[1], Vector3(0.26, 0.14, 0.2), Vector3(-0.1, -PlayerBody.ARM_M - 0.04, 0.06), col.darkened(0.1))
	p.name = "MealPiece"
	h.set_meta("meal_piece", p)


## Both arms out in front (carrying, holding out), or back to rest.
static func _arms_forward(h: Node3D, on: bool) -> void:
	var arms: Array = h.get_meta("arms", [])
	if not h.has_meta("arm_rest") and arms.size() >= 2:
		h.set_meta("arm_rest", [(arms[0] as Node3D).rotation, (arms[1] as Node3D).rotation])
	if not h.has_meta("arm_rest"):
		return
	var rest: Array = h.get_meta("arm_rest")
	for k in mini(arms.size(), 2):
		(arms[k] as Node3D).rotation = (rest[k] as Vector3) + (Vector3(1.0, 0, 0.18 * (1.0 if k == 0 else -1.0)) if on else Vector3.ZERO)


## Every folk seated at the fire eats from a bowl (bowls_to_everyone_
## seated); the player in the circle gets one too.
static func _bowls(camp: Node3D, holders: Array, time: float, pp: Vector3) -> void:
	if not bool(S.get("bowls_to_everyone_seated", true)):
		return
	var e: Dictionary = (FireCircle.IDLES.get("eat_bowl", {}) as Dictionary)
	var hs: Array = e.get("hold_s", [12, 25])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([camp.name, int(time)])
	var n := 0
	for hv in holders:
		var s: Node3D = hv
		if not is_instance_valid(s) or not _at_fire(s) or bool(s.get_meta("sharing", false)) or not s.has_meta("stage"):
			continue
		s.set_meta("idle", "eat_bowl")
		s.set_meta("idle_from", time)
		s.set_meta("idle_until", time + rng.randf_range(float(hs[0]), float(hs[1])))
		FireCircle._props(s, "eat_bowl")
		n += 1
	camp.set_meta("bowls_at", time)
	camp.set_meta("bowls_n", n)
	# The player, standing in the circle (there is no sitting down; the
	# spare seat is where you stand).
	if bool(S.get("player_gets_bowl", true)) and Vector2(camp.to_local(pp).x, camp.to_local(pp).z).length() <= float(S.get("player_in_circle_m", 3.6)):
		camp.set_meta("player_bowl_until", time + rng.randf_range(float(hs[0]), float(hs[1])))
		var key := str(camp.get_meta("key", camp.name))
		GameLog.add_once("meal:" + key, str(S.get("player_log_once", "They shared their food with you.")), "camp")
		camp.set_meta("player_bowl_n", int(camp.get_meta("player_bowl_n", 0)) + 1)


## The bowl in the player's hands while it lasts: lifted now and then.
static func _bowl_in_hand(camp: Node3D, time: float, _delta: float) -> void:
	var until := float(camp.get_meta("player_bowl_until", -1.0))
	if player_cam == null or not is_instance_valid(player_cam):
		return
	var b := player_cam.get_node_or_null("MealBowl") as Node3D
	if time >= until:
		if b != null and str(b.get_meta("camp", "")) == camp.name:
			b.queue_free()
		return
	if b == null:
		b = Node3D.new()
		b.name = "MealBowl"
		b.set_meta("camp", camp.name)
		player_cam.add_child(b)
		CreatureBodies.cone(b, 0.11, 0.07, 0.07, Vector3.ZERO, Color(0.42, 0.3, 0.2), 0.0, 10)
		CreatureBodies.cone(b, 0.095, 0.095, 0.01, Vector3(0, 0.032, 0), Color(0.55, 0.36, 0.2), 0.0, 10)
	var lift := maxf(sin(time * 0.9), 0.0)
	b.position = Vector3(0.02, -0.34 + 0.16 * lift * lift, -0.42 + 0.08 * lift)
	b.rotation = Vector3(0.35 * lift, 0, 0)


# --- The gift -----------------------------------------------------------------

## At dusk_form, with the gift due and the player near: the giver walks up,
## holds it out, it goes in the pack, the giver goes back and sits.
static func _gift(camp: Node3D, st: Dictionary, holders: Array, h: float, time: float, delta: float, pp: Vector3, inv: Inventory) -> void:
	var g: Dictionary = camp.get_meta("gift_anim", {})
	var reach := float((S.get("gift_back", {}) as Dictionary).get("reach_m", 30.0))
	var lp := camp.to_local(pp)
	var near := Vector2(lp.x, lp.z).length() <= reach
	if g.is_empty():
		if not bool(st.get("gift_due", false)) or bool(st.get("gift_given", false)) or not near:
			return
		if h < gather_end() or h > meal_h() + 1.0 or not camp.get_meta("meal_anim", {}).is_empty():
			return
		var giver := _giver(st, holders)
		if giver == null:
			return
		var to := Vector3(lp.x, giver.position.y, lp.z)
		var away := (giver.position - to)
		away.y = 0.0
		var stand := to + away.normalized() * 1.1 if away.length() > 1.2 else giver.position
		var face := (to - stand).slide(Vector3.UP)
		g = {"holder": giver, "seat": giver.transform, "stand": Transform3D(Basis.looking_at(face.normalized() if face.length() > 0.01 else -giver.basis.z, Vector3.UP), stand), "leg": 0, "t": 0.0}
		giver.set_meta("sharing", true)
		FireCircle._props(giver, "")
		giver.set_meta("idle", "")
		Workshop._stand(giver, true)
		camp.set_meta("gift_anim", g)
	var gh: Node3D = g.holder if is_instance_valid(g.holder) else null
	if gh == null:
		camp.set_meta("gift_anim", {})
		return
	var speed := float((CampSim.SIM.get("jobs", {}) as Dictionary).get("walk_mps", 1.3))
	g.t = float(g.t) + (1.0e6 if instant else delta)
	match int(g.leg):
		0:
			if not near:
				g.leg = 2
				g.t = 0.0
			elif _move(gh, g.seat, g.stand, float(g.t), speed, delta):
				g.leg = 1
				g.t = 0.0
				_gift_prop(gh, gift_of(st), true)
		1:
			# Held out in both hands (_gift_prop).
			if float(g.t) > float((S.get("gift_back", {}) as Dictionary).get("hold_out_s", 2.5)):
				give(st, inv)
				_gift_prop(gh, "", false)
				g.leg = 2
				g.t = 0.0
		2:
			if not g.has("from"):
				g["from"] = gh.transform
			if _move(gh, g.from, g.seat, float(g.t), speed, delta):
				gh.transform = g.seat
				gh.set_meta("base_yaw", gh.rotation.y)
				Workshop._stand(gh, false)
				gh.set_meta("sharing", false)
				_gift_prop(gh, "", false)
				camp.set_meta("gift_anim", {})


## The record-keeper at the fire (§EN), else an adult at the fire.
static func _giver(st: Dictionary, holders: Array) -> Node3D:
	var folk: Array = st.get("folk", [])
	var from := str((S.get("gift_back", {}) as Dictionary).get("from", "record_keeper_else_any_adult"))
	if from.begins_with("record_keeper"):
		for hv in holders:
			var n: Node3D = hv
			var i := int(n.get_meta("folk_i", -1)) if is_instance_valid(n) else -1
			if i >= 0 and i < folk.size() and str((folk[i] as Dictionary).get("role", "")) == "record_keeper" and _at_fire(n):
				return n
	for hv in holders:
		var n: Node3D = hv
		if is_instance_valid(n) and _at_fire(n) and str(n.get_meta("stage", "adult")) == "adult" and int(n.get_meta("folk_i", -1)) >= 0:
			return n
	return null


## The gift in the giver's hands: a small thing of its kind, held out.
static func _gift_prop(h: Node3D, kind: String, on: bool) -> void:
	var old = h.get_meta("gift_thing") if h.has_meta("gift_thing") else null
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	h.remove_meta("gift_thing")
	_arms_forward(h, on)
	var arms: Array = h.get_meta("arms", [])
	if not on or arms.size() < 2:
		return
	var hand: Node3D = arms[1]
	var at := Vector3(-0.1, -PlayerBody.ARM_M - 0.05, 0.06)
	var p: Node3D
	match kind:
		"pot":
			p = CreatureBodies.cone(hand, 0.12, 0.08, 0.2, at, Color(0.62, 0.36, 0.22), 0.0, 10)
		"torch":
			p = CreatureBodies.cone(hand, 0.025, 0.02, 0.6, at, Color(0.36, 0.25, 0.16), 0.0, 6)
			p.rotation.x = 1.2
		"bowl_of_stew":
			p = CreatureBodies.cone(hand, 0.11, 0.07, 0.07, at, Color(0.42, 0.3, 0.2), 0.0, 10)
		"cord_hank":
			p = CreatureBodies.cone(hand, 0.08, 0.08, 0.06, at, Color(0.66, 0.56, 0.36), 0.0, 8)
		_:
			p = CreatureBodies.cone(hand, 0.14, 0.11, 0.18, at, Color(0.6, 0.5, 0.3), 0.0, 8)
	p.name = "GiftThing"
	h.set_meta("gift_thing", p)
