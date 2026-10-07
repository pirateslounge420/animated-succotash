class_name TombKit
## The sarcophagus tombs' layout (design 6 Oct §ET.3, §ET.5; §CJ.8:
## "generated, never hand-placed: assembled from the seed out of a kit of
## rooms"; data/crawler.json kit, holders, airways). Pure: the seed in, a
## dictionary out (TombBuild draws it, CrawlerMain lights and fills it).
##
## The hearth room sits at the origin, its floor at y 0: the lit hearth in
## its middle, a smoke shaft over it (§ET.6), the bundle of unlit torches
## by it and the rescuer across it. From three or four of its walls
## (opening.exits_min..max) a branch goes out: a corridor (sometimes a
## flight of stairs down), a room, a corridor, a room... (kit.branch_rooms
## rooms), straight on or turning left or right at each room. Every piece
## is an axis-aligned straight lane (Delves.piece: `c` the middle of its
## start edge, `dir` along it, `len`, `half` wide each side, floor y0 to
## y1, `h` to the ceiling); walls stand outside the lanes, Delves.WALL
## thick, and two pieces meet at a door in the wall between them. Nothing
## overlaps: a piece that would is tried shorter, shifted or turned, and a
## branch that can't go on ends at its last room.
##
## Rooms are of the kit's kinds (crypt, catacomb, ossuary, collapsed); the
## deepest room of all is the heart (§CJ.3). Every room past the hearth
## room holds a cold fire-holder (delves.json fire_holders), every
## corridor longer than holders.sconce_first_m a wall sconce every
## sconce_every_m; stairs none (fire_holders.skip). The airways
## (airways.per_air by the theme's air): ordinary slots in corridor walls,
## strong marked mouths in room walls. The residents (design §FE,
## residents.json): the tomb's skeletons rest in the catacombs' wall
## niches and the crypts' coffins, more toward the heart, and the heart's
## own coffin holds one (Mike's frame 9); none in the hearth room, none by
## the way through the rooms.

static var K: Dictionary = Tuning.table("crawler").get("kit", {})
static var RESIDENTS: Dictionary = Tuning.table("residents")
static var HOLD: Dictionary = Tuning.table("crawler").get("holders", {})
static var AIR: Dictionary = Tuning.table("crawler").get("airways", {})
static var OPEN: Dictionary = Tuning.table("crawler").get("opening", {})
static var THEMES: Dictionary = Tuning.table("crawler").get("themes", {})

const WALL := Delves.WALL
## A door's half width (the corridors' lanes are a little wider).
const DOOR_HALF := 0.75
## Clearance kept between pieces' walls.
const GAP := 0.25
const SIDES := ["end", "left", "right", "start"]


static func _range(rng: RandomNumberGenerator, v, lo: float, hi: float) -> float:
	if v is Array and (v as Array).size() == 2:
		return rng.randf_range(float(v[0]), float(v[1]))
	return rng.randf_range(lo, hi)


static func _irange(rng: RandomNumberGenerator, v, lo: int, hi: int) -> int:
	if v is Array and (v as Array).size() == 2:
		return rng.randi_range(int(v[0]), int(v[1]))
	return rng.randi_range(lo, hi)


## The tomb for `seed_value`: {"seed", "theme", "pieces" [piece...],
## "doors" [door...], "hearth" (Vector3), "wake" ([Vector3, yaw]),
## "bundle" (Vector3), "rescuer" ([Vector3, yaw]), "holders"
## [{"kind": "hearth_ring"/"sconce", "pos", "normal", "piece"}...],
## "airways" [{"strong", "pos", "normal", "piece"}...], "heart" (piece
## id), "exits" (the hearth room's corridors), "residents" (_place_residents)}.
## A door is {"p" (Vector2,
## on the wall's middle line), "n" (Vector2, through the wall from `a`
## to `b`), "half", "y" (its floor), "h" (its opening), "a", "b" (piece
## ids)}.
static func layout(seed_value: int, theme := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var th := theme if theme != "" else str(OPEN.get("first_theme", "tomb"))
	var lay := {"seed": seed_value, "theme": th, "pieces": [], "doors": [], "holders": [], "airways": [], "exits": 0}
	var hr: Dictionary = K.get("hearth_room", {})
	var hl := float(hr.get("len_m", 9.0))
	var hw := float(hr.get("width_m", 9.0)) * 0.5
	var hearth_room := _add(lay, Delves.piece("room", Vector2(0.0, -hl * 0.5), Vector2(0, 1), hl, hw, 0.0, 0.0, float(hr.get("h_m", 3.6))))
	hearth_room["room_kind"] = "hearth"
	hearth_room["depth"] = 0
	lay["hearth"] = Vector3.ZERO
	# The exits: three or four walls, in a seeded order.
	var want := _irange(rng, [int(OPEN.get("exits_min", 3)), int(OPEN.get("exits_max", 4))], 3, 4)
	var sides: Array = SIDES.duplicate()
	_shuffle(rng, sides)
	for side in sides:
		if int(lay.exits) >= want:
			break
		if _branch(lay, rng, hearth_room, str(side)):
			lay.exits = int(lay.exits) + 1
	_mark_heart(lay)
	_wake_and_bundle(lay, rng, hearth_room)
	_place_holders(lay, rng)
	_place_vents(lay)
	_place_airways(lay, rng)
	# The boss's lair (design §EY.1; BossGround.place_lair, its own dice):
	# a hole in the floor of a side room off the main way.
	lay["lair"] = BossGround.place_lair(lay)
	# What lives in its dark (design §FE): where the residents rest (its
	# own dice too).
	_place_residents(lay)
	return lay


static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func _add(lay: Dictionary, pc: Dictionary) -> Dictionary:
	pc["id"] = (lay.pieces as Array).size()
	pc["doors"] = []
	(lay.pieces as Array).append(pc)
	return pc


## The point on wall `side` of piece `pc`, `off` along that wall from its
## middle, on the wall's middle line, and the way out through it.
static func wall_point(pc: Dictionary, side: String, off: float) -> Array:
	var c: Vector2 = pc.c
	var d: Vector2 = pc.dir
	var p := Delves.perp(d)
	var length := float(pc.len)
	var half := float(pc.half)
	match side:
		"end":
			return [c + d * (length + WALL * 0.5) + p * off, d]
		"start":
			return [c - d * (WALL * 0.5) + p * off, -d]
		"left":
			return [c + d * (length * 0.5 + off) + p * (half + WALL * 0.5), p]
	return [c + d * (length * 0.5 + off) - p * (half + WALL * 0.5), -p]


## How far a door may sit from the middle of wall `side`.
static func wall_slack(pc: Dictionary, side: String) -> float:
	var span := float(pc.half) if side in ["start", "end"] else float(pc.len) * 0.5
	return maxf(span - DOOR_HALF - 0.45, 0.0)


## A piece's footprint with its walls and the gap kept round them.
static func outer(pc: Dictionary) -> Rect2:
	return Delves.rect_of(pc, WALL + GAP)


static func _free(lay: Dictionary, r: Rect2, skip: Array) -> bool:
	for q in lay.pieces:
		if (q.id as int) in skip:
			continue
		if outer(q).grow(-0.01).intersects(r.grow(-0.01)):
			return false
	return true


## One branch out of `from` through its wall `side`: corridor, room,
## corridor, room... Returns whether the first corridor and room fitted.
static func _branch(lay: Dictionary, rng: RandomNumberGenerator, from: Dictionary, side: String) -> bool:
	var rooms := _irange(rng, K.get("branch_rooms", [2, 3]), 2, 3)
	var cur := from
	var cur_side := side
	var first := true
	for k in rooms:
		var placed := false
		for attempt in 14:
			var slack := wall_slack(cur, cur_side)
			var off := rng.randf_range(-slack, slack) * (0.5 if attempt < 7 else 1.0)
			var wp := wall_point(cur, cur_side, off)
			var n: Vector2 = wp[1]
			var start: Vector2 = (wp[0] as Vector2) + n * (WALL * 0.5)
			var y := float(cur.y1)
			var stair := rng.randf() < float(K.get("stair_chance", 0.3)) and not first
			var clen := _range(rng, K.get("corridor_m", [5.0, 11.0]), 5.0, 11.0) * (1.0 - 0.06 * attempt)
			var drop := 0.0
			if stair:
				drop = float(K.get("stair_drop_m", 2.4))
				clen = maxf(clen, drop / maxf(float(K.get("stair_slope", 0.6)), 0.1))
			var ch := float(K.get("corridor_h_m", 2.6))
			var cor := Delves.piece("stair" if stair else "corridor", start, n, clen, float(K.get("corridor_half_m", 1.0)), y, y - drop, ch)
			var rl := _range(rng, K.get("room_m", [6.0, 11.0]), 6.0, 11.0) * (1.0 - 0.04 * attempt)
			var rw := _range(rng, K.get("room_m", [6.0, 11.0]), 6.0, 11.0) * 0.5 * (1.0 - 0.04 * attempt)
			rw = maxf(rw, 3.0)
			var shift := rng.randf_range(-1.0, 1.0) * maxf(rw - DOOR_HALF - 0.6, 0.0)
			var rc: Vector2 = start + n * (clen + WALL) - Delves.perp(n) * shift
			var room := Delves.piece("room", rc, n, rl, rw, y - drop, y - drop, float(K.get("room_h_m", 3.2)))
			if not _free(lay, outer(cor), [cur.id]):
				continue
			# The room touches only its corridor (not added yet): not even
			# the room the corridor leaves.
			if not _free(lay, outer(room), []):
				continue
			_add(lay, cor)
			_add(lay, room)
			cor["depth"] = int(cur.get("depth", 0))
			room["depth"] = int(cur.get("depth", 0)) + 1
			room["room_kind"] = _room_kind(rng)
			room["branch_of"] = int(from.id)
			_door(lay, wp[0], n, float(cor.half) - 0.1, y, minf(ch, float(cur.h)) - 0.2, cur, cor)
			_door(lay, start + n * (clen + WALL * 0.5), n, float(cor.half) - 0.1, y - drop, ch - 0.2, cor, room)
			cur = room
			placed = true
			break
		if not placed:
			return not first
		first = false
		# On: straight ahead, or turning.
		if rng.randf() < float(K.get("turn_chance", 0.45)):
			cur_side = "left" if rng.randf() < 0.5 else "right"
		else:
			cur_side = "end"
	return true


static func _door(lay: Dictionary, p: Vector2, n: Vector2, half: float, y: float, h: float, a: Dictionary, b: Dictionary) -> void:
	var d := {"p": p, "n": n, "half": minf(half, DOOR_HALF + 0.15), "y": y, "h": h, "a": int(a.id), "b": int(b.id)}
	d["id"] = (lay.doors as Array).size()
	(lay.doors as Array).append(d)
	(a.doors as Array).append(d.id)
	(b.doors as Array).append(d.id)


static func _room_kind(rng: RandomNumberGenerator) -> String:
	var kinds: Dictionary = K.get("kinds", {"crypt": 1})
	var total := 0.0
	for k in kinds:
		total += float(kinds[k])
	var r := rng.randf() * total
	for k in kinds:
		r -= float(kinds[k])
		if r <= 0.0:
			return str(k)
	return str(kinds.keys()[0])


## The heart: the deepest room (the lowest floor breaks a tie).
static func _mark_heart(lay: Dictionary) -> void:
	var best: Dictionary = {}
	for pc in lay.pieces:
		if str(pc.kind) != "room" or str(pc.get("room_kind", "")) == "hearth":
			continue
		if best.is_empty() or int(pc.depth) > int(best.depth) or (int(pc.depth) == int(best.depth) and float(pc.y0) < float(best.y0)):
			best = pc
	if not best.is_empty():
		best["room_kind"] = "heart"
		lay["heart"] = int(best.id)


## Which of piece `pc`'s walls (side, offset along it) door `d` is on.
static func door_side(pc: Dictionary, d: Dictionary) -> Array:
	var aa := Delves.along_across(pc, d.p)
	var length := float(pc.len)
	if aa.x <= 0.0:
		return ["start", aa.y]
	if aa.x >= length:
		return ["end", aa.y]
	return ["left" if aa.y > 0.0 else "right", aa.x - length * 0.5]


## Where you wake (a mat by the hearth, facing it), the bundle, the
## rescuer (across the hearth, facing it and you): clear of the room's
## doors.
static func _wake_and_bundle(lay: Dictionary, rng: RandomNumberGenerator, room: Dictionary) -> void:
	var res: Dictionary = Tuning.table("crawler").get("rescuer", {})
	var stand := float(res.get("stand_m", 2.1))
	# The way from the hearth with the most room: away from the doors.
	var best_a := 0.0
	var best_score := -INF
	for k in 16:
		var a := TAU * k / 16.0
		var v := Vector2(cos(a), sin(a))
		var score := 0.0
		for di in room.doors:
			var d: Dictionary = lay.doors[di]
			score += (d.p as Vector2).normalized().dot(v) * -1.0
		score += rng.randf() * 0.1
		if score > best_score:
			best_score = score
			best_a = a
	var v := Vector2(cos(best_a), sin(best_a))
	var wake := v * 2.4
	lay["wake"] = [Vector3(wake.x, 0.0, wake.y), atan2(wake.x, wake.y)]
	var side := Vector2(-v.y, v.x)
	var b := v * 0.9 + side * 0.85
	lay["bundle"] = Vector3(b.x, 0.0, b.y)
	# Across the hearth, a little way round it (rescuer.round_deg, §FH: it
	# sits, lower than the flame, so not straight across), on whichever
	# side keeps it and its things behind it farther from the doors.
	var ra := deg_to_rad(float(res.get("round_deg", 30.0)))
	var r := Vector2.ZERO
	var best_clear := -INF
	for sgn: float in [1.0, -1.0]:
		var rr := (-v * cos(ra) + side * (sin(ra) * sgn)) * stand
		var clear := INF
		for di in room.doors:
			var dp: Vector2 = (lay.doors[di] as Dictionary).p
			clear = minf(clear, minf(dp.distance_to(rr), dp.distance_to(rr * (1.0 + 1.3 / maxf(stand, 0.1)))))
		if clear > best_clear:
			best_clear = clear
			r = rr
	# Facing the hearth (a yaw of 0 faces -z): its front is -r.
	lay["rescuer"] = [Vector3(r.x, 0.0, r.y), atan2(r.x, r.y)]


## Cold fire-holders: one per room past the hearth room (delves.json
## fire_holders), sconces down the corridors.
static func _place_holders(lay: Dictionary, rng: RandomNumberGenerator) -> void:
	var fh: Dictionary = Tuning.table("delves").get("fire_holders", {})
	var kind := str((fh.get("by_ruin", {}) as Dictionary).get(str((THEMES.get(lay.theme, {}) as Dictionary).get("ruin_kind", "tomb")), fh.get("by_ruin", {}).get("default", "hearth_ring")))
	var skip: Array = fh.get("skip", ["stair"])
	for pc in lay.pieces:
		match str(pc.kind):
			"room":
				if str(pc.room_kind) == "hearth":
					continue
				# Near the room's far end in the heart (the dead lie before
				# it), else its middle a little off the line between doors.
				var along := float(pc.len) * (0.62 if str(pc.room_kind) == "heart" else 0.5)
				var across := rng.randf_range(-0.6, 0.6) if float(pc.half) > 3.2 else 0.0
				var p := Delves.perp(pc.dir)
				var at: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along + p * across
				(lay.holders as Array).append({"kind": kind, "pos": Vector3(at.x, float(pc.y0), at.y), "normal": Vector3.UP, "piece": int(pc.id)})
			"corridor", "stair":
				if str(pc.kind) in skip:
					continue
				var first := float(HOLD.get("sconce_first_m", 4.0))
				var every := maxf(float(HOLD.get("sconce_every_m", 7.0)), 1.0)
				var a := first
				var sd := 1.0 if rng.randf() < 0.5 else -1.0
				while a < float(pc.len) - 1.0:
					var p := Delves.perp(pc.dir)
					var wall: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + p * sd * float(pc.half)
					var nrm := -Vector3(p.x, 0.0, p.y) * sd
					(lay.holders as Array).append({"kind": "sconce", "pos": Vector3(wall.x, Delves.floor_of(pc, a) + float(HOLD.get("sconce_h_m", 1.7)), wall.y), "normal": nrm, "piece": int(pc.id)})
					sd = -sd
					a += every


## The vents (design §EV; smoke.json vents): every permanent fire the
## generator built (the hearth, each hearth ring and sconce; carried
## torches are exempt) gets its own vent from its piece's ceiling up to the
## surface, kinked where another piece of the tomb stands over it: a shaft
## for a hearth, ring or altar, a narrow flue for a sconce or brazier
## (§EV.1). Each is {"kind", "type" ("shaft" / "flue"), "fire" (the fire's
## place), "fire_index" (-1 the hearth, else its holder's index), "piece",
## "mouth" (the vent's mouth in the ceiling's underside), "d" (its width,
## narrowing with depth), "depth" (the vent's length up to the surface),
## "sky" (a shaft with daylight left at that depth, §EV.2), "share" (the
## daylight left), "legs" ([[from, to]...], the runs, up and any sideways
## step), "top" (its opening at the surface), "outlet" (what it becomes on
## the surface once there is one, §EV.4 with §EW: smoke.json
## vents.surface)}.
static func _place_vents(lay: Dictionary) -> void:
	var V: Dictionary = vents_table()
	var fires: Array = [{"kind": "hearth", "pos": lay.hearth, "normal": Vector3.UP, "piece": 0, "index": -1}]
	for i in (lay.holders as Array).size():
		var h: Dictionary = lay.holders[i]
		fires.append({"kind": h.kind, "pos": h.pos, "normal": h.normal, "piece": h.piece, "index": i})
	var surface := float(V.get("surface_y_m", 9.0))
	var dl: Dictionary = V.get("daylight", {})
	var fade: Array = dl.get("fade_depth_m", [3.0, 25.0])
	var narrow := bool(dl.get("narrow_with_depth", true))
	var vents: Array = []
	for f in fires:
		var pc: Dictionary = lay.pieces[int(f.piece)]
		var fp: Vector3 = f.pos
		var vtype := vent_type(str(f.kind))
		var wr: Array = (V.get(vtype, {}) as Dictionary).get("width_m", [0.6, 1.2] if vtype == "shaft" else [0.15, 0.3])
		# The mouth: beside a fire on the floor for a shaft, straight over it
		# for a flue; over a sconce, just off its wall. Kept inside the
		# piece's ceiling.
		var m := Vector2(fp.x, fp.z)
		var d0 := float(wr[1])
		if str(f.kind) == "sconce":
			var nv: Vector3 = f.normal
			m += Vector2(nv.x, nv.z) * (d0 * 0.5 + 0.08)
		elif vtype == "shaft":
			var off: Array = V.get("mouth_offset_m", [0.7, 1.1])
			var orng := RandomNumberGenerator.new()
			orng.seed = hash([int(lay.seed), fp, "vent"])
			m += Vector2.RIGHT.rotated(orng.randf() * TAU) * orng.randf_range(float(off[0]), float(off[1]))
		var aa := Delves.along_across(pc, m)
		var ceil_y := Delves.floor_of(pc, clampf(aa.x, 0.0, float(pc.len))) + float(pc.h)
		var depth := maxf(surface - ceil_y, 0.0)
		# Narrower the deeper (§EV.2): the full width at the surface, the
		# least at the depth where the daylight is gone.
		var k := clampf(depth / maxf(float(fade[1]), 0.1), 0.0, 1.0) if narrow else 0.0
		var d := maxf(lerpf(float(wr[1]), float(wr[0]), k), 0.08)
		aa.x = clampf(aa.x, d * 0.5 + 0.05, float(pc.len) - d * 0.5 - 0.05)
		aa.y = clampf(aa.y, -float(pc.half) + d * 0.5 + 0.05, float(pc.half) - d * 0.5 - 0.05)
		m = (pc.c as Vector2) + (pc.dir as Vector2) * aa.x + Delves.perp(pc.dir) * aa.y
		ceil_y = Delves.floor_of(pc, aa.x) + float(pc.h)
		var mouth := Vector3(m.x, ceil_y, m.y)
		var kink: Dictionary = V.get("kink", {})
		var legs := _flue_legs(lay, int(pc.id), mouth, d, surface, kink, int((V.get("shaft", {}) as Dictionary).get("kinks", 2)))
		var top: Vector3 = (legs[-1] as Array)[1]
		var share := daylight_share(depth) if vtype == "shaft" or not bool(dl.get("shafts_only", true)) else 0.0
		vents.append({"kind": f.kind, "type": vtype, "fire": fp, "fire_index": int(f.index), "piece": int(pc.id), "mouth": mouth, "d": d,
			"depth": depth, "sky": share > 0.0, "share": share, "legs": legs, "top": top,
			"outlet": str((V.get("surface", {}) as Dictionary).get(vtype, ""))})
	lay["vents"] = vents


## smoke.json vents (design §EV).
static func vents_table() -> Dictionary:
	return Tuning.table("smoke").get("vents", {})


## "shaft" or "flue": which vent a fire of `kind` gets (smoke.json
## vents.shaft.for; design §EV.1). Anything else gets a flue.
static func vent_type(kind: String) -> String:
	var sh: Array = (vents_table().get("shaft", {}) as Dictionary).get("for", ["hearth", "old_hearth", "hearth_ring", "altar"])
	return "shaft" if kind in sh else "flue"


## The share of daylight left down a shaft `depth` m long (smoke.json
## vents.daylight.fade_depth_m: full to the first, none past the second,
## a straight line between).
static func daylight_share(depth: float) -> float:
	var fade: Array = (vents_table().get("daylight", {}) as Dictionary).get("fade_depth_m", [3.0, 25.0])
	var a := float(fade[0])
	var b := maxf(float(fade[1]), a + 0.01)
	return clampf(1.0 - (depth - a) / (b - a), 0.0, 1.0)


## The vent's runs from `mouth` up to the surface: straight up if no other
## piece of the tomb stands over it; else up kink.clear_m, a step sideways
## (up to kink.step_m) to clear rock, and on up (two bends; `kinks` under
## 2 keeps it straight, the rock taking it).
static func _flue_legs(lay: Dictionary, own: int, mouth: Vector3, d: float, surface: float, kink: Dictionary, kinks := 2) -> Array:
	var top := Vector3(mouth.x, surface, mouth.z)
	if kinks < 2 or _column_clear(lay, own, Vector2(mouth.x, mouth.z), d, mouth.y):
		return [[mouth, top]]
	var rise := mouth.y + float(kink.get("clear_m", 1.2))
	var step := float(kink.get("step_m", 2.5))
	for r in [step * 0.5, step]:
		for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var at := Vector2(mouth.x, mouth.z) + (dv as Vector2) * float(r)
			if _column_clear(lay, own, at, d, rise):
				var a := Vector3(mouth.x, rise, mouth.z)
				var b := Vector3(at.x, rise, at.y)
				return [[mouth, a], [a, b], [b, Vector3(at.x, surface, at.y)]]
	# Nowhere clear: straight up regardless (the rock keeps it).
	return [[mouth, top]]


## Does a flue `d` wide at (x/z) `p`, rising from `from_y`, keep clear of
## every other piece above that height?
static func _column_clear(lay: Dictionary, own: int, p: Vector2, d: float, from_y: float) -> bool:
	var r := Rect2(p - Vector2(d, d) * 0.5, Vector2(d, d))
	for pc in lay.pieces:
		if int(pc.id) == own:
			continue
		var top := maxf(float(pc.y0), float(pc.y1)) + float(pc.h) + Delves.SLAB
		if top <= from_y:
			continue
		if outer(pc).intersects(r):
			return false
	return true


## The airways (§ET.6): ordinary slots in corridor walls, strong marked
## mouths in room side walls, away from doors and sconces.
static func _place_airways(lay: Dictionary, rng: RandomNumberGenerator) -> void:
	var air := str((THEMES.get(lay.theme, {}) as Dictionary).get("air", "still"))
	var counts: Dictionary = (AIR.get("per_air", {}) as Dictionary).get(air, {"ordinary": 2, "strong": 1})
	var corridors: Array = []
	var rooms: Array = []
	for pc in lay.pieces:
		if str(pc.kind) == "corridor" and float(pc.len) >= 4.0:
			corridors.append(pc)
		elif str(pc.kind) == "room" and str(pc.room_kind) != "hearth":
			rooms.append(pc)
	_shuffle(rng, corridors)
	_shuffle(rng, rooms)
	for i in mini(int(counts.get("ordinary", 2)), corridors.size()):
		var pc: Dictionary = corridors[i]
		var a := float(pc.len) * rng.randf_range(0.3, 0.7)
		var sd := 1.0 if rng.randf() < 0.5 else -1.0
		_airway(lay, pc, a, sd, false)
	var n_strong := int(counts.get("strong", 1))
	var made := 0
	for pc in rooms:
		if made >= n_strong:
			break
		# A side wall with no door on it.
		for sd: float in [1.0, -1.0]:
			var side := "left" if sd > 0.0 else "right"
			var used := false
			for di in pc.doors:
				if str(door_side(pc, lay.doors[di])[0]) == side:
					used = true
			if used:
				continue
			_airway(lay, pc, float(pc.len) * rng.randf_range(0.35, 0.65), sd, true)
			made += 1
			break


static func _airway(lay: Dictionary, pc: Dictionary, along: float, sd: float, strong: bool) -> void:
	var p := Delves.perp(pc.dir)
	var at: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along + p * sd * float(pc.half)
	var y := Delves.floor_of(pc, along) + (1.2 if strong else 2.0)
	(lay.airways as Array).append({"strong": strong, "pos": Vector3(at.x, y, at.y), "normal": -Vector3(p.x, 0.0, p.y) * sd, "piece": int(pc.id)})


## Every piece's id that `pos` (scene, the tomb at the origin) stands in.
static func piece_at(lay: Dictionary, pos: Vector3) -> int:
	for pc in lay.pieces:
		var aa := Delves.along_across(pc, Vector2(pos.x, pos.z))
		if aa.x >= -0.05 and aa.x <= float(pc.len) + 0.05 and absf(aa.y) <= float(pc.half) + 0.05:
			var fy := Delves.floor_of(pc, aa.x)
			if pos.y > fy - 1.0 and pos.y < fy + float(pc.h) + 0.5:
				return int(pc.id)
	return -1


# --- The residents' resting places (design §FE, residents.json) ---------------

## Is (along) on wall `side` of `pc` within `within` of one of its doors?
static func near_door(lay: Dictionary, pc: Dictionary, side: String, along: float, within: float) -> bool:
	for di in pc.doors:
		var s: Array = door_side(pc, lay.doors[di])
		if str(s[0]) == side and absf(float(s[1]) + float(pc.len) * 0.5 - along) < within:
			return true
	return false


## Is (along) within `within` of an airway on side `sd` of `pc`?
static func near_airway(lay: Dictionary, pc: Dictionary, sd: float, along: float, within: float) -> bool:
	for a in lay.airways:
		if int(a.piece) != int(pc.id):
			continue
		var aa := Delves.along_across(pc, Vector2((a.pos as Vector3).x, (a.pos as Vector3).z))
		if signf(aa.y) == sd and absf(aa.x - along) < within:
			return true
	return false


## A crypt's stone coffins (TombBuild draws them): rows down both long
## walls every 2.4 m, clear of the doors and airways, each 2.2 m long
## across the room from its wall (COFFIN_IN its middle's distance in from
## the wall): [{"along", "sd" (the wall's side, +1 left), "i"}...] in the
## order they are drawn. None in a room under 4.8 m wide.
const COFFIN_IN := 1.25
const COFFIN_SIZE := Vector3(0.95, 0.9, 2.2)


static func coffin_spots(lay: Dictionary, pc: Dictionary) -> Array:
	var out: Array = []
	if float(pc.half) < 2.4:
		return out
	for sd: float in [-1.0, 1.0]:
		var side := "left" if sd > 0.0 else "right"
		var a := 1.6
		while a < float(pc.len) - 1.4:
			if not near_door(lay, pc, side, a, 1.9) and not near_airway(lay, pc, sd, a, 1.4):
				out.append({"along": a, "sd": sd, "i": out.size()})
			a += 2.4
	return out


## A catacomb's niche stacks (three shelves each, down both long walls
## every 1.4 m, clear of the doors and airways): [{"along", "sd", "i"}...].
static func niche_spots(lay: Dictionary, pc: Dictionary) -> Array:
	var out: Array = []
	for sd: float in [-1.0, 1.0]:
		var side := "left" if sd > 0.0 else "right"
		var a := 1.0
		while a < float(pc.len) - 0.8:
			if not near_door(lay, pc, side, a, 1.5) and not near_airway(lay, pc, sd, a, 1.2):
				out.append({"along": a, "sd": sd, "i": out.size()})
			a += 1.4
	return out


## The heart's coffin (Mike's frame 9): its middle on the floor, its yaw
## (long across the room at its far end), and the way it opens toward the
## room's way in.
const HEART_BOX := Vector3(1.05, 1.0, 2.3)
## A grave's rim over what its skeleton kneels on: the inside is filled to
## its height less this (bones and dust), so the head and an arm clear the
## rim (SkeletonRig rest_grave).
const GRAVE_RIM_OVER := 0.58


## The height inside a coffin `box_h` tall that a skeleton kneels on.
static func grave_floor(box_h: float) -> float:
	return maxf(box_h - GRAVE_RIM_OVER, 0.12)


static func heart_box(pc: Dictionary) -> Dictionary:
	var length := float(pc.len)
	var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * (length - 1.6)
	return {"pos": Vector3(q.x, Delves.floor_of(pc, length - 1.6), q.y), "yaw": atan2((pc.dir as Vector2).x, (pc.dir as Vector2).y) + PI * 0.5}


## The yaw that faces a figure (its front -z at yaw 0) along x/z `f`.
static func yaw_facing(f: Vector2) -> float:
	return atan2(-f.x, -f.y)


## The way through the rooms (design §EX.5 until the spine is built,
## §EX.2): in every piece, from each of its doors to its middle:
## [[Vector2, Vector2]...]. What a resting place keeps off (off_line_m).
static func walk_lines(lay: Dictionary) -> Array:
	var out: Array = []
	for pc in lay.pieces:
		var mid: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5
		for di in pc.doors:
			var d: Dictionary = lay.doors[di]
			var into: Vector2 = (d.n as Vector2) * (1.0 if int(d.b) == int(pc.id) else -1.0)
			out.append([(d.p as Vector2) + into * (WALL * 0.5 + 0.3), mid])
	return out


## How far x/z `p` is from the nearest of `lines` (walk_lines).
static func line_distance(lines: Array, p: Vector2) -> float:
	var best := INF
	for l in lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## A resting place in piece `pc` (TombBuild draws it, Residents wakes it):
## {"kind" (the creature), "rests_in" ("wall_niche" / "grave"), "piece",
## "spot" (its coffin_spots / niche_spots index; -1 the heart's coffin),
## "pos" (where it rests: the shelf's top in a niche, the coffin's floor
## in a grave), "yaw" (it faces into the room), "out" (the floor where it
## stands once it has climbed out), "eye" (its head as it rests: what it
## wakes to), "depth"}.
static func rest_place(lay: Dictionary, pc: Dictionary, kind: String, rests_in: String, spot: Dictionary) -> Dictionary:
	var half := float(pc.half)
	var pv := Delves.perp(pc.dir)
	var fy := Delves.floor_of(pc, float(spot.get("along", 0.0)))
	var r := {"kind": kind, "rests_in": rests_in, "piece": int(pc.id), "spot": int(spot.get("i", -1)), "depth": int(pc.get("depth", 0))}
	if int(spot.get("i", -1)) < 0:
		# The heart's coffin: it kneels inside, slumped over the side that
		# faces the way in.
		var hb := heart_box(pc)
		var hp: Vector3 = hb.pos
		var toward := -(pc.dir as Vector2)
		var t3 := Vector3(toward.x, 0.0, toward.y)
		r["pos"] = Vector3(hp.x, hp.y + grave_floor(HEART_BOX.y), hp.z) + t3 * 0.12
		r["out"] = Vector3(hp.x, hp.y, hp.z) + t3 * (HEART_BOX.x * 0.5 + 0.65)
		r["yaw"] = yaw_facing(toward)
		r["eye"] = (r.pos as Vector3) + Vector3(0.0, 0.86, 0.0) + t3 * 0.45
		return r
	var a := float(spot.along)
	var sd := float(spot.sd)
	var inward := -pv * sd
	if rests_in == "grave":
		# A crypt coffin: kneeling inside near its inner end, slumped over it.
		var c: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + pv * sd * (half - COFFIN_IN)
		var p := c + inward * (COFFIN_SIZE.z * 0.5 - 0.5)
		var o := c + inward * (COFFIN_SIZE.z * 0.5 + 0.6)
		r["pos"] = Vector3(p.x, fy + grave_floor(COFFIN_SIZE.y), p.y)
		r["out"] = Vector3(o.x, fy, o.y)
		r["eye"] = (r.pos as Vector3) + Vector3(0.0, 0.86, 0.0) + Vector3(inward.x, 0.0, inward.y) * 0.45
	else:
		# A niche: sitting hunched on the bottom shelf, facing the room.
		var p2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + pv * sd * (half - 0.32)
		var o2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + pv * sd * (half - 1.15)
		r["pos"] = Vector3(p2.x, fy + 0.5, p2.y)
		r["out"] = Vector3(o2.x, fy, o2.y)
		r["eye"] = Vector3(p2.x, fy + 0.5 + 0.62, p2.y) + Vector3(inward.x, 0.0, inward.y) * 0.24
	r["yaw"] = yaw_facing(inward)
	return r


## The residents' resting places (design §FE.1-2, residents.json): for the
## tomb, its skeletons (rests_in wall_niche and grave): per_dungeon of them
## when there are places enough, the heart's coffin holding one
## (heart_holds_one), the rest drawn room by room weighted by depth to the
## toward_heart power, none in the hearth room, none within off_line_m of
## the way through (walk_lines), none within apart_m of another. Its own
## seed, so the rest of the tomb is as it was. lay.residents [rest_place...].
static func _place_residents(lay: Dictionary) -> void:
	lay["residents"] = []
	var kind := "skeleton"
	var cr: Dictionary = (RESIDENTS.get("creatures", {}) as Dictionary).get(kind, {})
	if cr.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "residents"])
	var lines := walk_lines(lay)
	var off := float(cr.get("off_line_m", 1.0))
	var apart := float(cr.get("apart_m", 2.0))
	var rests: Array = cr.get("rests_in", ["wall_niche", "grave"])
	var power := float(cr.get("toward_heart", 1.5))
	var heart: Dictionary = {}
	var cands: Array = []
	for pc in lay.pieces:
		if str(pc.kind) != "room":
			continue
		var places: Array = []
		match str(pc.get("room_kind", "")):
			"crypt":
				if "grave" in rests:
					for s in coffin_spots(lay, pc):
						places.append(rest_place(lay, pc, kind, "grave", s))
			"catacomb":
				if "wall_niche" in rests:
					for s in niche_spots(lay, pc):
						places.append(rest_place(lay, pc, kind, "wall_niche", s))
			"heart":
				if "grave" in rests and bool(cr.get("heart_holds_one", true)):
					heart = rest_place(lay, pc, kind, "grave", {"i": -1})
		for p in places:
			var at: Vector3 = p.pos
			if line_distance(lines, Vector2(at.x, at.z)) >= off:
				cands.append(p)
	var span: Array = cr.get("per_dungeon", [3, 6])
	var want := rng.randi_range(int(span[0]), int(span[1]))
	var picked: Array = []
	if not heart.is_empty():
		var hp: Vector3 = heart.pos
		if line_distance(lines, Vector2(hp.x, hp.z)) >= off:
			picked.append(heart)
	while picked.size() < want and not cands.is_empty():
		var total := 0.0
		for c in cands:
			total += pow(maxf(float(c.depth), 1.0), power)
		var roll := rng.randf() * total
		var pick := 0
		for i in cands.size():
			roll -= pow(maxf(float(cands[i].depth), 1.0), power)
			if roll <= 0.0:
				pick = i
				break
		var chosen: Dictionary = cands[pick]
		cands.remove_at(pick)
		var ok := true
		for q in picked:
			if (q.pos as Vector3).distance_to(chosen.pos) < apart:
				ok = false
				break
		if ok:
			picked.append(chosen)
	lay["residents"] = picked


## The resting place in piece `piece` at spot `spot` (-1 the heart's
## coffin), or {} if nothing rests there (TombBuild).
static func resting_at(lay: Dictionary, piece: int, spot: int) -> Dictionary:
	for r in lay.get("residents", []):
		if int(r.piece) == piece and int(r.spot) == spot:
			return r
	return {}
