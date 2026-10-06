class_name Hunt
## The whole animal (design 5 Oct §EK; camps.json → sim.hunt, sim.jobs
## kinds.hunt, data/animal_use.json). A camp with a workshop (the storage
## rung, §EL; the opening camp has none) hunts hunts_per_game_week times a
## week, in the gather hours:
##   1. one adult (never the keeper, never a teen or child) takes the spear
##      and walks out to a point game.trip_m away (past gather reach, inside
##      hunt.reach_m) where GameCounts has a huntable class above its floor
##      (marine_mammal only for game.marine_peoples), stands there a while
##      out of sight (the kill is never shown), and walks back carrying it
##      (hunt.carry by class: over the shoulders, in hand, on a line, or
##      dragged on a pole);
##   2. the carcass goes in at the workshop's back door (the "BackDoor"
##      spot behind the hut, out of the fire's sight) and is not seen again;
##   3. after process_game_h the animal's parts come out as pieces on their
##      benches (animal_use classes[class].parts: bench and piece), up to
##      things_shown, the hide and the meat first; the food store gains
##      food_units[class]; fat, oil or blubber keeps the hearth's lamp lit
##      game.lamp_nights nights (fire carried from the hearth, never made);
##      the soft and food pieces are used up after pieces_decay_game_days,
##      quietly, the bone tools, horn and antler stay;
##   4. the log, once per species, when the player is within 120 m as the
##      hunter comes home (hunt.log_once_per_species).
## never (animal_use.never): no trophy, no head, no cutting shown, nothing
## for a weapon against what lurks in the dark; the hunter's kill is the
## camp's (§EJ.2, the sharing waits on §EJ). Mute.

static var H: Dictionary = (Tuning.section("camps", "sim").get("hunt", {}) as Dictionary)
static var A: Dictionary = Tuning.table("animal_use")
const LOG_M := 120.0


static func game() -> Dictionary:
	return H.get("game", {})


## A camp that hunts: living, with a workshop (not the opening camp).
static func hunts(st: Dictionary) -> bool:
	return Workshop.wanted(st) and str(st.get("key", "")) != "opening"


## Who goes: an adult who is not the keeper, the first in a seeded turn.
static func hunter_of(st: Dictionary, salt: int) -> int:
	var folk: Array = st.get("folk", [])
	var keeper := Workshop.keeper_of(st)
	var can: Array = []
	for i in folk.size():
		if i != keeper and CampSim.is_adult(folk[i]):
			can.append(i)
	if can.is_empty():
		return -1
	return int(can[absi(salt) % can.size()])


## Real seconds a game hour lasts.
static func game_h_s() -> float:
	return DayCycle.day_length_min() * 60.0 / 24.0


## One sim tick of camp `st` (CampSim._tick): the hunt under way moves on;
## a new one starts at its scheduled hour. `player_dir` the player's
## direction (the log), Vector3.ZERO if none.
static func tick(cs: CampSim, st: Dictionary, days: float, h: float, th: float, map: PlanetData, player_dir: Vector3) -> void:
	_decay(st, days)
	var hs: Dictionary = st.get("hunt", {})
	var d := cs._dir(st)
	if str(hs.get("state", "")) == "out" and days >= float(hs.back_day):
		hs.state = "processing"
		if player_dir != Vector3.ZERO and CubeSphere.surface_distance_m(player_dir, d) <= LOG_M:
			var txt := str(H.get("log_once_per_species", "The hunters brought back a {creature}.")).replace("{creature}", str(hs.species).to_lower())
			GameLog.add_once("hunt_species:" + str(hs.species), txt, "camp")
	if str(hs.get("state", "")) == "processing" and days >= float(hs.done_day):
		_finish(st, hs, days)
		hs.state = "done"
	st["hunt"] = hs
	if not hunts(st) or str(hs.get("state", "")) in ["out", "processing"]:
		return
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	var day := int(floor(days + CubeSphere.longitude(d) / TAU))
	if int(hs.get("day", -999)) == day:
		return
	var at := start_hour(st, day)
	if at < 0.0 or h < at or h >= at + th:
		return
	start(st, days, day, map, d)


## The hour a hunt starts on local `day`, or -1 (not a hunting day): the
## week's days drawn from hunts_per_game_week, the hour so that the trip
## ends inside the gather hours.
static func start_hour(st: Dictionary, day: int) -> float:
	var week := int(floor(day / 7.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st.get("seed", 0)), week, "hunt_week"])
	var per: Array = H.get("hunts_per_game_week", [1, 3])
	var n := rng.randi_range(int(per[0]), int(per[1]))
	var days_of: Array = [0, 1, 2, 3, 4, 5, 6]
	for i in 7:
		var j := rng.randi_range(i, 6)
		var t = days_of[i]
		days_of[i] = days_of[j]
		days_of[j] = t
	if not days_of.slice(0, n).has(posmod(day, 7)):
		return -1.0
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	var r2 := RandomNumberGenerator.new()
	r2.seed = hash([int(st.get("seed", 0)), day, "hunt_hour"])
	return float(gh[0]) + r2.randf() * maxf(float(gh[1]) - float(gh[0]) - 4.5, 0.5)


## Start a hunt now: the hunter, the place, the class (GameCounts takes one).
static func start(st: Dictionary, days: float, day: int, map: PlanetData, d: Vector3, force_class := "", force_angle := NAN) -> bool:
	var hs: Dictionary = {"day": day, "state": "none"}
	st["hunt"] = hs
	var hunter := hunter_of(st, hash([int(st.get("seed", 0)), day]))
	if hunter < 0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st.get("seed", 0)), day, "hunt_where"])
	var tm: Array = game().get("trip_m", [400, 800])
	var people := str(st.get("people", ""))
	var marine_ok := (game().get("marine_peoples", ["tundra", "coast"]) as Array).has(people)
	var best := {}
	var a0 := rng.randf() * TAU
	for k in 8:
		var ang := a0 + TAU * k / 8.0 if is_nan(force_angle) else force_angle
		var dist := rng.randf_range(float(tm[0]), minf(float(tm[1]), float(H.get("reach_m", 900.0))))
		var p := CreatureSpawner._offset(d, ang, dist)
		var cell := map.cell_at(p)
		var cls := GameCounts.classes_at(map, p)
		var pick: Array = []
		for c in cls:
			if c == "marine_mammal" and not marine_ok:
				continue
			if force_class != "" and c != force_class:
				continue
			if GameCounts.count(cell, str(c), days) > GameCounts.floor_n():
				pick.append(c)
		if pick.is_empty():
			continue
		pick.sort()
		var c0 := str(pick[rng.randi() % pick.size()])
		var names: Array = cls[c0]
		best = {"cell": cell, "class": c0, "species": str(names[rng.randi() % names.size()]), "angle": ang, "dist": dist}
		break
	if best.is_empty() or not GameCounts.take(int(best.cell), str(best["class"]), days):
		return false
	var walk_h := float(best.dist) / float((CampSim.SIM.get("jobs", {}) as Dictionary).get("walk_mps", 1.3)) / game_h_s()
	var pause_h := float(game().get("pause_game_h", 0.3))
	hs.merge({"state": "out", "hunter": hunter, "class": best["class"], "species": best.species, "angle": best.angle, "dist": best.dist, "cell": best.cell,
		"out_day": days, "turn_day": days + walk_h / 24.0, "lift_day": days + (walk_h + pause_h) / 24.0,
		"back_day": days + (2.0 * walk_h + pause_h) / 24.0, "done_day": days + (2.0 * walk_h + pause_h + float(H.get("process_game_h", 6.0))) / 24.0}, true)
	st["hunt"] = hs
	st["hunt_count"] = int(st.get("hunt_count", 0)) + 1
	var log: Array = st.get("hunt_log", [])
	log.append({"day": days, "class": best["class"], "species": best.species, "hunter": hunter, "cell": best.cell})
	while log.size() > 40:
		log.pop_front()
	st["hunt_log"] = log
	WorldSave.mark_dirty()
	return true


## The parts that come out of the hut: up to things_shown, the hide (or
## fur, or skin) and the meat first, then the rest in the class's order.
static func parts_shown(cls: String) -> Array:
	var c: Dictionary = (A.get("classes", {}) as Dictionary).get(cls, {})
	var parts: Dictionary = c.get("parts", {})
	var order: Array = []
	for first in ["hide", "fur", "skin", "meat"]:
		if parts.has(first) and not order.has(first):
			order.append(first)
	for p in parts:
		if not order.has(p):
			order.append(p)
	var out: Array = []
	for p in order.slice(0, int(c.get("things_shown", 3))):
		out.append({"part": p, "bench": str(parts[p].bench), "piece": str(parts[p].piece)})
	return out


static func _finish(st: Dictionary, hs: Dictionary, days: float) -> void:
	var cls := str(hs["class"])
	st.food = float(st.get("food", 0.0)) + float((H.get("food_units", {}) as Dictionary).get(cls, 1.0))
	var pieces: Array = st.get("hunt_pieces", [])
	var shown := parts_shown(cls)
	for p in shown:
		pieces.append({"piece": p.piece, "bench": p.bench, "day": days})
		if str(p.part) in ["fat", "oil", "blubber"]:
			st["fat_until"] = days + float(game().get("lamp_nights", 3))
	# The fat comes out even when it isn't one of the things shown.
	var parts: Dictionary = (((A.get("classes", {}) as Dictionary).get(cls, {}) as Dictionary).get("parts", {}) as Dictionary)
	for fp in ["fat", "oil", "blubber"]:
		if parts.has(fp):
			st["fat_until"] = days + float(game().get("lamp_nights", 3))
	st["hunt_pieces"] = pieces
	st["hunts"] = int(st.get("hunts", 0)) + 1
	st["fat_pieces"] = int(st.get("fat_pieces", 0)) + (1 if st.has("fat_until") else 0)
	hs["pieces_added"] = shown.size()
	WorldSave.mark_dirty()


## The soft and food pieces are used up after pieces_decay_game_days; the
## tools stay (at most 6 a bench shown).
static func _decay(st: Dictionary, days: float) -> void:
	var pieces: Array = st.get("hunt_pieces", [])
	if pieces.is_empty():
		return
	var stay: Array = game().get("pieces_stay", [])
	var keep: Array = []
	for p in pieces:
		if stay.has(str(p.piece)) or days - float(p.day) < float(game().get("pieces_decay_game_days", 7)):
			keep.append(p)
	var per := {}
	var out: Array = []
	for i in range(keep.size() - 1, -1, -1):
		var b := str(keep[i].bench)
		per[b] = int(per.get(b, 0)) + 1
		if int(per[b]) <= 6:
			out.push_front(keep[i])
	if out.size() != pieces.size():
		st["hunt_pieces"] = out


## The hunt's pieces for `bench` as phrases ("hide_on_frame" -> "hide on frame").
static func pieces_for(st: Dictionary, bench: String) -> Array:
	var out: Array = []
	for p in st.get("hunt_pieces", []):
		if str(p.bench) == bench:
			out.append(str(p.piece).replace("_", " "))
	return out


## Is the hearth's lamp fed tonight (a hunt's fat, or the lighting trade)?
static func lamp_fed(st: Dictionary, days: float) -> bool:
	return float(st.get("fat_until", -1.0)) >= days or (st.get("trades", []) as Array).has("lighting")


# --- The hunter, seen (a built camp near the player) -------------------------

## The hunter's figure at camp node `camp` (frame: the fire at the origin)
## for hunt `hs` at game time `days`: walking out with the spear, standing
## out there, walking back carrying the animal, gone in at the back door.
## `ws` the workshop; `d` the fire's direction; `ground` local ground;
## `pal` the people's palette.
static func show(camp: Node3D, hs: Dictionary, days: float, ws: Node3D, world: Node, chunks: ChunkManager, ground: Callable, pal: Array) -> void:
	var hn: Node3D = camp.get_node_or_null("HuntCarrier")
	var live := str(hs.get("state", "")) == "out" and days < float(hs.get("back_day", 0.0)) and ws != null and is_instance_valid(ws)
	if not live:
		if hn != null:
			hn.queue_free()
		return
	var d: Vector3 = world.dir_of(camp.global_position)
	var far_d := CreatureSpawner._offset(d, float(hs.angle), float(hs.dist))
	var far: Vector3 = camp.to_local(world.to_scene(far_d, PlanetConst.RADIUS_M + chunks.ground_height(far_d)))
	var bd: Node3D = ws.get_node_or_null("BackDoor")
	var door: Vector3 = camp.to_local(bd.global_position) if bd != null else ws.position
	if hn == null:
		hn = _figure(camp, hs, pal)
	var t := days
	var p: Vector3
	var carrying := false
	var moving := true
	if t < float(hs.turn_day):
		p = door.lerp(far, clampf((t - float(hs.out_day)) / maxf(float(hs.turn_day) - float(hs.out_day), 1e-6), 0.0, 1.0))
	elif t < float(hs.lift_day):
		p = far
		moving = false
	else:
		carrying = true
		p = far.lerp(door, clampf((t - float(hs.lift_day)) / maxf(float(hs.back_day) - float(hs.lift_day), 1e-6), 0.0, 1.0))
	if ground.is_valid():
		p.y = float(ground.call(p))
	var to := (door - far) if carrying else (far - door)
	to.y = 0.0
	hn.position = p
	if to.length() > 0.01:
		hn.basis = Basis.looking_at(to.normalized(), Vector3.UP)
	(hn.get_node("Spear") as Node3D).visible = not carrying
	(hn.get_node("Carry") as Node3D).visible = carrying
	var body := hn.get_node_or_null("Body")
	if body != null and body is PlayerBody:
		var v := to.normalized() * float((CampSim.SIM.get("jobs", {}) as Dictionary).get("walk_mps", 1.3)) if moving else Vector3.ZERO
		(body as PlayerBody).set_velocity(camp.global_basis * v)
		(body as PlayerBody).set_motion(0.35 if moving else 0.0, 0.016)
		# Dragging a pole: leaning into it.
		(body as Node3D).rotation.x = -0.18 if carrying and str((H.get("carry", {}) as Dictionary).get(str(hs["class"]), "")) == "dragged_on_pole" else 0.0


## The hunter: a cloaked figure, the spear in hand, and what they carry
## back by its class (hunt.carry), hidden until the lift.
static func _figure(camp: Node3D, hs: Dictionary, pal: Array) -> Node3D:
	var c0: Color = pal[0] if not pal.is_empty() else Color(0.5, 0.35, 0.25)
	var c1: Color = pal[1 % maxi(pal.size(), 1)] if not pal.is_empty() else Color(0.8, 0.7, 0.5)
	var b := CloakedFigure.build(1.72, c0, c1)
	var hn := Node3D.new()
	hn.name = "HuntCarrier"
	camp.add_child(hn)
	var body: Node3D = b.root
	body.name = "Body"
	hn.add_child(body)
	var spear := Node3D.new()
	spear.name = "Spear"
	hn.add_child(spear)
	var shaft := CreatureBodies.box(spear, Vector3(0.03, 1.9, 0.03), Vector3(0.28, 1.05, 0.1), Color(0.42, 0.3, 0.18))
	shaft.rotation.x = 0.15
	CreatureBodies.box(spear, Vector3(0.05, 0.16, 0.03), Vector3(0.28, 2.05, 0.25), Color(0.36, 0.36, 0.38))
	var carry := Node3D.new()
	carry.name = "Carry"
	hn.add_child(carry)
	var cls := str(hs.get("class", "small_game"))
	var col := Color(0.5, 0.38, 0.26)
	var sp := CreatureSpecies.find(str(hs.get("species", "")))
	if sp != null:
		col = sp.color
	match str((H.get("carry", {}) as Dictionary).get(cls, "over_shoulders")):
		"over_shoulders":
			var big := cls == "small_hoofed"
			CreatureBodies.box(carry, Vector3(0.9 if big else 0.6, 0.3 if big else 0.2, 0.3 if big else 0.2), Vector3(0, 1.45, -0.05), col)
		"in_hand":
			CreatureBodies.box(carry, Vector3(0.18, 0.4, 0.22), Vector3(0.3, 0.75, 0.05), col)
		"on_a_line":
			CreatureBodies.box(carry, Vector3(0.02, 0.02, 0.9), Vector3(0.3, 1.1, 0.3), Color(0.42, 0.3, 0.18))
			for k in 3:
				CreatureBodies.box(carry, Vector3(0.06, 0.35, 0.1), Vector3(0.3, 0.85, 0.05 + k * 0.25), col)
		"dragged_on_pole":
			# Two poles from the shoulders to the ground behind (+z: the
			# figure faces -z, home), the animal lying on them.
			for s in [-0.25, 0.25]:
				var pole := CreatureBodies.box(carry, Vector3(0.05, 0.05, 2.6), Vector3(s, 0.7, 1.2), Color(0.45, 0.34, 0.22))
				pole.rotation.x = 0.42
			var beast := CreatureBodies.box(carry, Vector3(0.55, 0.45, 1.4), Vector3(0, 0.72, 1.55), col)
			beast.rotation.x = 0.42
	carry.visible = false
	return hn
