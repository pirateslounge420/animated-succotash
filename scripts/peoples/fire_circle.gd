class_name FireCircle
## The fire circle (design 3 Oct §CY.2–CY.3, data/camps.json →
## sim.fire_circle): what a camp does when it isn't working. Its folk sit
## in a ring round the fire on seats the place supplies, one seat each and
## a spare, and pass the time in small loops, each with one prop, never
## standing and breathing. Used by the people's camps (Camps) and the
## opening camp (Encampment).
##
## Seats (lay_seats): the kinds come from seats.by_biome (commonest first),
## with at_site on top (a fallen block at a ruin camp, a ledge under a
## cliff) and by_people instead for a people whose fire isn't on the
## ground; at most kinds_per_circle at one fire. A ring ring_m out, the
## seats at least min_gap_m apart, all facing the fire; a log, driftwood or
## a limb takes two sitters. Wooden seats take the bark of the stand's
## dominant tree (the commonest tree round the fire), stone seats the
## place's own rock (CreatureSpawner.den_stones), a hummock the ground's
## colour, a mat the people's cloth, driftwood bleached, a ruin block the
## ruin's stone.
##
## The loops (animate): one seated pose for every cloaked figure (the
## CloakedFigure rig, seated; the cloak hides the legs), with the arms and
## the hood doing the rest: watch the fire, warm hands, poke the fire
## (the fire flares and throws specks, Campfire.stir), feed the fire (when
## the fire is below the store's feed_fire_below_units; adults), eat from a
## bowl (when the food store isn't empty), hearth work (adults), doze.
## Each sitter picks one by the phase of the day's weights (idles.*.weight)
## and holds it hold_s; children play only the resting ones. No new rig and
## no per-species animation: small folk and big folk play the same loops at
## their own scale.
##
## The pipe (§CY.4, idles.pipe): an adult's, one at a fire at a time
## (max_at_once). Pack the bowl, lean in and light it with a brand from the
## fire (a stick with a glowing end; nobody strikes a spark, §BP), puff
## three to six times with rests between, tap it out. Each draw shows the
## bowl's ember, one glowing pixel that casts no light; each breath out
## leaves a few square puffs of the hearth smoke's pale blue-grey
## (smoke.json hearth.look; never glowing) that rise and drift with the
## weather's wind.
##
## They notice you (notice): inside watch_m the hood, and only the hood,
## turns to follow you (head_max_deg at most); when you leave it holds
## hold_s and goes back to the fire, and doesn't notice you again for
## again_after_s. A dozer doesn't notice.
## Nothing here changes a sim tick.

## CIRCLE=0 in the environment holds the loops still (A/B, frame times).
static var ON := OS.get_environment("CIRCLE") != "0"
static var D: Dictionary = (Tuning.section("camps", "sim").get("fire_circle", {}) as Dictionary)
static var SEATS: Dictionary = D.get("seats", {})
static var IDLES: Dictionary = D.get("idles", {})
static var NOTICE: Dictionary = D.get("notice", {})

## The loops the circle plays (the pipe waits on §CY.4).
const BUILT := ["watch_fire", "warm_hands", "poke_fire", "feed_fire", "pipe", "eat_bowl", "sit_work", "doze"]
## The ones a child plays (§CY.2: never the pipe, never a job).
const CHILD := ["watch_fire", "warm_hands", "poke_fire", "eat_bowl", "doze"]
const WOOD := ["log", "stump", "root", "limb"]
const STONE := ["rock", "flat_stone"]


## The seat kinds at a fire: by_people's for a people whose fire isn't on
## the ground, else at_site's (a ruin, a cliff) on top of by_biome's, at
## most kinds_per_circle; a mat where the place offers nothing.
static func kinds_for(biome_key: String, people_id: String, site: String) -> Array:
	var by_people: Dictionary = SEATS.get("by_people", {})
	var out: Array = []
	if by_people.has(people_id):
		out = (by_people[people_id] as Array).duplicate()
	else:
		var at_site: Dictionary = SEATS.get("at_site", {})
		if at_site.has(site):
			out.append_array(at_site[site])
		for k in (SEATS.get("by_biome", {}) as Dictionary).get(biome_key, []):
			if not out.has(k):
				out.append(k)
	out = out.slice(0, int(SEATS.get("kinds_per_circle", 2)))
	if out.is_empty():
		out = ["mat"]
	return out


## The bark of the stand round `d` (scene `center`): the commonest tree
## within 40 m in the loaded chunks, its wood colour; a neutral wood where
## there are no trees.
static func stand_bark(chunks: ChunkManager, center: Vector3) -> Color:
	var counts := {}
	var all := SpeciesDB.all()
	if chunks != null:
		for key in chunks.chunks:
			var ch: TerrainChunk = chunks.chunks[key]
			if ch.global_position.distance_to(center) > 450.0:
				continue
			for i in ch.trees.size():
				if ch.tree_base(i).distance_to(center) <= 40.0:
					var idx := int(ch.trees[i][2])
					counts[idx] = int(counts.get(idx, 0)) + 1
	var best := -1
	var n := 0
	for idx in counts:
		if int(counts[idx]) > n:
			n = int(counts[idx])
			best = idx
	if best < 0:
		return Color(0.36, 0.25, 0.16)
	return (all[best] as PlantSpecies).accent


## Lay a circle's seats under `root` (its origin the fire, its up the
## ground's) for `count` sitters, plus spare_seats empty: returns one
## {pos, face, height} per sitter, in `root`'s frame. `ctx`: biome, people,
## site ("ruin", "cliff" or ""), bark, stones (an Array of Color), ground,
## cloth (Colors); spare_at (optional) the angle the spare seat faces. The
## seats collide (`body`).
static func lay_seats(root: Node3D, count: int, rng: RandomNumberGenerator, ctx: Dictionary, body: StaticBody3D) -> Array:
	var kinds := kinds_for(str(ctx.get("biome", "")), str(ctx.get("people", "")), str(ctx.get("site", "")))
	var K: Dictionary = SEATS.get("kinds", {})
	var ring: Array = SEATS.get("ring_m", [1.6, 2.4])
	var gap := float(SEATS.get("min_gap_m", 0.9))
	var slots := count + int(SEATS.get("spare_seats", 1))
	# Wide enough that no two seats are nearer than min_gap_m.
	var r := clampf(maxf(rng.randf_range(float(ring[0]), float(ring[1])), slots * (gap + 0.25) / TAU), float(ring[0]), float(ring[1]) + 1.0)
	var a0 := rng.randf() * TAU
	if ctx.has("spare_at"):
		# The spare seat (the last slot) toward `spare_at` (an angle in
		# root's frame): the gap in the ring you step into.
		a0 = float(ctx.spare_at) - TAU * (slots - 1) / slots
	var out: Array = []
	var s := 0
	var seat_i := 0
	while s < slots:
		var kind: String = kinds[seat_i % kinds.size()]
		seat_i += 1
		var kd: Dictionary = K.get(kind, {})
		var two := int(kd.get("seats", 1)) >= 2 and s + 1 < slots
		var span := 2 if two else 1
		var a := a0 + TAU * (s + 0.5 * (span - 1)) / slots + rng.randf_range(-0.08, 0.08)
		var at := Vector3(cos(a), 0, sin(a)) * r
		var h := float(kd.get("height_m", 0.35))
		_seat_mesh(root, kind, at, a, h, span, rng, ctx, body)
		for j in span:
			var aj := a0 + TAU * (s + j) / slots
			if two:
				# Along the log: the two sit at its ends.
				aj = a + (float(j) - 0.5) * (TAU / slots) * 0.85
			var p := Vector3(cos(aj), 0, sin(aj)) * r
			# The spare seat is the last slot: left empty.
			if s + j < count:
				out.append({"pos": p, "face": -p.normalized(), "height": h, "kind": kind})
		s += span
	return out


static func _seat_mesh(root: Node3D, kind: String, at: Vector3, a: float, h: float, span: int, rng: RandomNumberGenerator, ctx: Dictionary, body: StaticBody3D) -> void:
	var bark: Color = ctx.get("bark", Color(0.36, 0.25, 0.16))
	var stones: Array = ctx.get("stones", RuinBuilder.STONES)
	var len_m := 1.1 if span == 2 else 0.5
	match kind:
		"log", "limb", "driftwood":
			var col := Color(0.78, 0.74, 0.66) if kind == "driftwood" else bark
			var rad := h * 0.5
			var lg := CreatureBodies.cone(root, rad, rad * 0.92, len_m * 1.6, at + Vector3(0, rad, 0), col)
			lg.rotation = Vector3(0, -a, PI * 0.5)
			PropCollision.capsule(body, lg.transform, rad, len_m * 1.6)
		"stump", "root":
			var rad2 := 0.22 if kind == "stump" else 0.14
			var st := CreatureBodies.cone(root, rad2, rad2 * 0.85, h, at + Vector3(0, h * 0.5, 0), bark.darkened(0.05))
			if kind == "root":
				st.rotation = Vector3(0.0, -a, 0.25)
			PropCollision.capsule(body, Transform3D(Basis(), at + Vector3(0, h * 0.5, 0)), rad2, h)
		"rock", "flat_stone", "ruin_block":
			var col2: Color = (RuinBuilder.STONES if kind == "ruin_block" else stones)[rng.randi() % (RuinBuilder.STONES if kind == "ruin_block" else stones).size()]
			var size := Vector3(0.6, h * 1.6, 0.55) if kind == "rock" else (Vector3(0.75, h * 1.4, 0.55) if kind == "flat_stone" else Vector3(0.7, h * 1.4, 0.5))
			var mi := MeshInstance3D.new()
			mi.mesh = RuinBuilder.rock_mesh(size, rng.randi(), col2, kind != "rock")
			mi.material_override = RuinBuilder.material()
			mi.position = at + Vector3(0, size.y * 0.5 - size.y * 0.35, 0)
			mi.rotation = Vector3(0, -a, 0)
			mi.set_meta("stone", col2)
			root.add_child(mi)
			PropCollision.box(body, mi.transform, size * Vector3(0.9, 0.65, 0.9))
		"hummock":
			var g: Color = ctx.get("ground", Color(0.35, 0.42, 0.22))
			CreatureBodies.ball(root, Vector3(0.32, h, 0.3), at + Vector3(0, h * 0.2, 0), g.darkened(0.08))
		"mat":
			var cloth: Color = ctx.get("cloth", Color(0.45, 0.3, 0.2))
			var m := CreatureBodies.box(root, Vector3(0.7, 0.03, 0.9), at + Vector3(0, 0.015, 0), cloth)
			m.rotation.y = -a
	root.get_child(root.get_child_count() - 1).set_meta("seat", kind)


## Sit `holder` (a sitter's holder, its body a seated CloakedFigure) on
## `seat` (lay_seats), facing the fire. The seated rig is built for a seat
## about SEAT_H high; a lower seat sits it lower, as far as the cloak hides.
const SEAT_H := 0.34

static func sit(holder: Node3D, seat: Dictionary) -> void:
	var p: Vector3 = seat.pos
	holder.position = p + Vector3(0, clampf(float(seat.height) - SEAT_H, -0.14, 0.08), 0)
	holder.basis = Basis.looking_at(seat.face, Vector3.UP)
	holder.set_meta("base_yaw", holder.rotation.y)
	holder.set_meta("seat_kind", str(seat.kind))


## The phase of the day at a place: "dawn", "day", "dusk" or "night"
## (DayCycle), from the local hour `h` (0-24).
static func phase_name(h: float, lat: float, days: float) -> String:
	# Remembered per place and five game minutes: DayCycle keeps one
	# latitude's table, and asking it for several places a frame (the
	# camps, the sky, Main) rebuilds it each time.
	var key := Vector3i(roundi(lat * 200.0), int(days), int(h * 12.0))
	if _phase_cache.has(key):
		return _phase_cache[key]
	if _phase_cache.size() > 256:
		_phase_cache.clear()
	var name := str(DayCycle.phase_at(h / 24.0, lat, Astro.declination(days)).get("name", "day"))
	_phase_cache[key] = name
	return name


static var _phase_cache := {}


## Pick a loop for `holder` by `phase`'s weights (idles.*.weight), among
## the ones it can play: a child only CHILD; the jobs only for adults; a
## loop whose `needs` the camp doesn't meet (`ctx` food_ok, fire_low) is
## passed over.
static func pick(holder: Node3D, phase: String, ctx: Dictionary, rng: RandomNumberGenerator) -> String:
	var child := str(holder.get_meta("stage", "adult")) == "child"
	var names: Array[String] = []
	var w: Array[float] = []
	for n in BUILT:
		var e: Dictionary = IDLES.get(n, {})
		if child and not CHILD.has(n):
			continue
		# An adult's loop (the jobs, the pipe) isn't a teen's either.
		if str(e.get("who", "anyone")) == "adult" and str(holder.get_meta("stage", "adult")) != "adult":
			continue
		if n == "pipe" and int(ctx.get("pipes", 0)) >= int(e.get("max_at_once", 1)):
			continue
		match str(e.get("needs", "")):
			"food_store_not_empty":
				if not bool(ctx.get("food_ok", true)):
					continue
			"fire_below_feed_units":
				if not bool(ctx.get("fire_low", false)):
					continue
		var wt := float((e.get("weight", {}) as Dictionary).get(phase, 1.0)) if e.has("weight") else 2.0
		if wt <= 0.0:
			continue
		names.append(n)
		w.append(wt)
	if names.is_empty():
		return "watch_fire"
	var total := 0.0
	for x in w:
		total += x
	var r := rng.randf() * total
	for i in names.size():
		r -= w[i]
		if r <= 0.0:
			return names[i]
	return names[names.size() - 1]


## How long a loop holds (idles.*.hold_s), in seconds.
static func hold_s(idle: String, rng: RandomNumberGenerator) -> float:
	var hs: Array = (IDLES.get(idle, {}) as Dictionary).get("hold_s", [6, 12])
	return rng.randf_range(float(hs[0]), float(hs[1]))


## Play the circle one frame: each sitter's loop (its arms and hood),
## picking a new one when it runs out, and the hood following the player
## inside notice.watch_m. `sitters` are holders (meta "arms", "head");
## `fire` the camp's fire (a poke or a feed stirs it); `pp` the player's
## scene position; `phase` the day's; `ctx` food_ok, fire_low.
static func animate(sitters: Array, fire: Node3D, time: float, delta: float, pp: Vector3, phase: String, ctx: Dictionary) -> void:
	if not ON:
		return
	var rng := RandomNumberGenerator.new()
	var watch := float(NOTICE.get("watch_m", 7.0))
	var max_turn := deg_to_rad(float(NOTICE.get("head_max_deg", 70.0)))
	var hold := float(NOTICE.get("hold_s", 2.0))
	var again := float(NOTICE.get("again_after_s", 40.0))
	var rate := float(NOTICE.get("rate", 6.0))
	# One pipe at a fire at a time.
	var pipes := 0
	for s0 in sitters:
		if is_instance_valid(s0) and str((s0 as Node3D).get_meta("idle", "")) == "pipe":
			pipes += 1
	for i in sitters.size():
		var s: Node3D = sitters[i]
		if not is_instance_valid(s):
			continue
		ctx["pipes"] = pipes
		rng.seed = hash([i, int(time * 10.0), s.name])
		var ph := float(s.get_meta("phase", 0.0))
		# The loop: pick one when the last runs out.
		var idle := str(s.get_meta("idle", ""))
		var until := float(s.get_meta("idle_until", -1.0))
		if idle == "" or time >= until:
			if idle == "pipe":
				pipes -= 1
			idle = pick(s, phase, ctx, rng)
			s.set_meta("idle", idle)
			s.set_meta("idle_from", time)
			s.set_meta("idle_until", time + hold_s(idle, rng))
			s.set_meta("stirred", false)
			if idle == "pipe":
				pipes += 1
				var plan := pipe_plan(rng)
				s.set_meta("pipe_plan", plan)
				s.set_meta("idle_until", time + float(plan.total))
			_props(s, idle)
		var t := time - float(s.get_meta("idle_from", time))
		s.set_meta("idle_t", t)
		var plan: Dictionary = s.get_meta("pipe_plan", {}) if idle == "pipe" else {}
		var pose := _pose(idle, t, ph, plan)
		if idle == "pipe":
			_pipe_props(s, t, plan)
		_puffs(s, time, delta, plan if idle == "pipe" else {}, t)
		# A poke or a piece laid on stirs the fire once, at the reach.
		if (idle == "poke_fire" or idle == "feed_fire") and t > 1.2 and not bool(s.get_meta("stirred", false)):
			s.set_meta("stirred", true)
			Campfire.stir(fire, "poke" if idle == "poke_fire" else "feed")
		# The arms: their seated rest plus the loop's.
		var arms: Array = s.get_meta("arms", [])
		if not s.has_meta("arm_rest") and arms.size() >= 2:
			s.set_meta("arm_rest", [(arms[0] as Node3D).rotation, (arms[1] as Node3D).rotation])
		if s.has_meta("arm_rest"):
			var rest: Array = s.get_meta("arm_rest")
			for k in mini(arms.size(), 2):
				var want: Vector3 = (rest[k] as Vector3) + (pose.l if k == 0 else pose.r)
				var arm: Node3D = arms[k]
				arm.rotation = arm.rotation.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
		# The hood: the loop's tilt, or the player inside watch_m.
		var head: Node3D = s.get_meta("head") if s.has_meta("head") else null
		if head == null:
			continue
		var look_yaw := 0.0
		var dozing := idle == "doze"
		var near := s.global_position.distance_to(pp) < watch
		var tracking := bool(s.get_meta("tracking", false))
		var last_end := float(s.get_meta("look_end", -1000.0))
		if near and not dozing and (tracking or time - last_end > again):
			# Following you while you're inside watch_m.
			s.set_meta("tracking", true)
			var to := s.global_transform.affine_inverse() * pp
			look_yaw = clampf(atan2(-to.x, -to.z), -max_turn, max_turn)
		else:
			if tracking:
				# You left (or it nodded off): the look holds, then goes
				# back to the fire, and not again for again_after_s.
				s.set_meta("tracking", false)
				s.set_meta("look_end", time + hold)
				last_end = time + hold
			if time < last_end:
				look_yaw = float(s.get_meta("look_yaw", 0.0))
		s.set_meta("look_yaw", look_yaw)
		head.rotation.y = lerp_angle(head.rotation.y, look_yaw, clampf(delta * rate * 0.5, 0.0, 1.0))
		head.rotation.x = lerpf(head.rotation.x, pose.hood, clampf(delta * 4.0, 0.0, 1.0))


## A pipe's steps (idles.pipe.steps): when each starts, `t` seconds into
## the loop: pack, light, the draws (each draw_s long, rests between),
## tap out; total.
static func pipe_plan(rng: RandomNumberGenerator) -> Dictionary:
	var e: Dictionary = IDLES.get("pipe", {})
	var pack := 4.0
	var light := 3.0
	var tap := 2.0
	var draws: Array[float] = []
	var draw_s := 1.5
	var t := 0.0
	for step in e.get("steps", []):
		var sd: Dictionary = step
		match str(sd.get("do", "")):
			"pack":
				pack = float(sd.get("s", 4.0))
			"light_from_fire":
				light = float(sd.get("s", 3.0))
			"tap_out":
				tap = float(sd.get("s", 2.0))
	t = pack + light
	for step in e.get("steps", []):
		var sd: Dictionary = step
		if str(sd.get("do", "")) == "puff":
			draw_s = float(sd.get("draw_s", 1.5))
			var times: Array = sd.get("times", [3, 6])
			var rest: Array = sd.get("rest_s", [4, 9])
			for k in rng.randi_range(int(times[0]), int(times[1])):
				draws.append(t)
				t += draw_s + rng.randf_range(float(rest[0]), float(rest[1]))
	return {"pack": pack, "light": light, "draws": draws, "draw_s": draw_s, "tap_at": t, "total": t + tap}


## Is the pipe being drawn at `t` (a draw under way)?
static func drawing(plan: Dictionary, t: float) -> bool:
	for d0 in plan.get("draws", []):
		if t >= float(d0) and t < float(d0) + float(plan.get("draw_s", 1.5)):
			return true
	return false


## A loop's arms (left, right: added to the seated rest) and the hood's
## tilt (+ down) at `t` seconds in.
static func _pose(idle: String, t: float, ph: float, plan := {}) -> Dictionary:
	var l := Vector3.ZERO
	var r := Vector3.ZERO
	var hood := 0.18
	var breath := 0.03 * sin(t * 1.4 + ph)
	match idle:
		"watch_fire":
			hood = 0.28 + 0.06 * sin(t * 0.3 + ph)
			l = Vector3(breath, 0, 0)
			r = Vector3(breath, 0, 0)
		"warm_hands":
			var rub := 0.12 * sin(t * 6.0 + ph)
			l = Vector3(0.95, 0, -0.18 + rub)
			r = Vector3(0.95, 0, 0.18 + rub)
			hood = 0.22
		"poke_fire":
			var stir := 0.25 * sin(t * 3.2 + ph)
			r = Vector3(1.05 + stir * 0.5, 0, 0.1 + stir * 0.4)
			l = Vector3(0.2, 0, 0)
			hood = 0.4
		"feed_fire":
			var reach := smoothstep(0.0, 1.2, t) * (1.0 - smoothstep(2.2, 3.2, t))
			l = Vector3(1.25 * reach, 0, -0.1)
			r = Vector3(1.25 * reach, 0, 0.1)
			hood = 0.2 + 0.25 * reach
		"eat_bowl":
			var lift := maxf(sin(t * 0.9 + ph), 0.0)
			l = Vector3(0.75, 0, -0.25)
			r = Vector3(0.75 + 1.1 * lift * lift, 0, 0.25 * lift)
			hood = 0.15 - 0.1 * lift
		"sit_work":
			var w := 0.15 * sin(t * 2.4 + ph)
			l = Vector3(0.6 + w, 0, -0.2)
			r = Vector3(0.6 - w, 0, 0.2)
			hood = 0.5
		"pipe":
			var pack := float(plan.get("pack", 4.0))
			var light_end := pack + float(plan.get("light", 3.0))
			if t < pack:
				# Packing the bowl in the lap.
				var w2 := 0.1 * sin(t * 5.0 + ph)
				l = Vector3(0.6, 0, -0.15)
				r = Vector3(0.65 + w2, 0, 0.15)
				hood = 0.45
			elif t < light_end:
				# Leaning in: the brand to the bowl.
				l = Vector3(1.05, 0, -0.05)
				r = Vector3(1.2, 0, 0.05)
				hood = 0.35
			elif t < float(plan.get("tap_at", 20.0)):
				# The pipe to the hood on a draw, down on the knee between.
				var up_k := 1.0 if drawing(plan, t) else 0.0
				l = Vector3(0.3, 0, 0)
				r = Vector3(0.55 + 1.05 * up_k, 0, 0.2 * up_k)
				hood = 0.12 - 0.1 * up_k
			else:
				# Tapping it out on the seat.
				r = Vector3(0.4 + 0.15 * absf(sin(t * 9.0)), 0, 0.35)
				l = Vector3(0.3, 0, 0)
				hood = 0.4
		"doze":
			# The hood sinks, nods, starts, settles again.
			var cycle := fposmod(t + ph * 3.0, 9.0)
			hood = 0.55 + 0.25 * smoothstep(0.0, 6.0, cycle) - 0.5 * smoothstep(6.0, 6.4, cycle) * (1.0 - smoothstep(6.4, 7.5, cycle))
			l = Vector3(0.25, 0, 0)
			r = Vector3(0.25, 0, 0)
	return {"l": l, "r": r, "hood": hood}


## The loop's one prop in hand (a stick, a piece of wood, a bowl, the
## work in the lap), the last one put away.
static func _props(s: Node3D, idle: String) -> void:
	var old = s.get_meta("prop") if s.has_meta("prop") else null
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	s.remove_meta("prop")
	var ob = s.get_meta("brand") if s.has_meta("brand") else null
	if ob != null and is_instance_valid(ob):
		(ob as Node).queue_free()
	s.remove_meta("brand")
	var arms: Array = s.get_meta("arms", [])
	if arms.size() < 2:
		return
	var hand: Node3D = arms[1]
	var p: Node3D = null
	match idle:
		"poke_fire":
			p = CreatureBodies.cone(hand, 0.012, 0.01, 0.9, Vector3(0, -PlayerBody.ARM_M, 0), Color(0.3, 0.22, 0.14))
			p.rotation.x = -PI * 0.5
		"feed_fire":
			p = CreatureBodies.cone(hand, 0.05, 0.05, 0.5, Vector3(0, -PlayerBody.ARM_M, 0), Color(0.36, 0.25, 0.16))
			p.rotation.z = PI * 0.5
		"eat_bowl":
			p = CreatureBodies.cone(arms[0], 0.09, 0.06, 0.06, Vector3(0, -PlayerBody.ARM_M, 0), Color(0.42, 0.3, 0.2))
		"sit_work":
			p = CreatureBodies.box(hand, Vector3(0.18, 0.08, 0.14), Vector3(0, -PlayerBody.ARM_M, 0.02), Color(0.55, 0.45, 0.32))
		"pipe":
			# The pipe: a stem and a bowl; the bowl's ember (one glowing
			# pixel, on the draw; it casts no light); and the brand, a stick
			# with its end glowing, in the other hand while it's lit.
			p = Node3D.new()
			hand.add_child(p)
			p.position = Vector3(0, -PlayerBody.ARM_M, 0.03)
			var stem := CreatureBodies.cone(p, 0.008, 0.008, 0.16, Vector3(0, 0, 0.06), Color(0.3, 0.22, 0.15))
			stem.rotation.x = PI * 0.5
			CreatureBodies.cone(p, 0.022, 0.026, 0.045, Vector3(0, 0.02, 0.14), Color(0.25, 0.18, 0.12))
			var ember := CreatureBodies.box(p, Vector3(0.018, 0.01, 0.018), Vector3(0, 0.045, 0.14), Color(1.0, 0.45, 0.1), 3.0)
			ember.name = "Ember"
			ember.visible = false
			var brand := CreatureBodies.cone(arms[0], 0.015, 0.012, 0.6, Vector3(0, -PlayerBody.ARM_M, 0.25), Color(0.26, 0.18, 0.12))
			brand.rotation.x = -PI * 0.5
			brand.name = "Brand"
			var tip := CreatureBodies.box(brand, Vector3(0.03, 0.04, 0.03), Vector3(0, 0.3, 0), Color(1.0, 0.4, 0.08), 3.0)
			tip.name = "Tip"
			brand.visible = false
			s.set_meta("brand", brand)
	if p != null:
		p.name = "Prop"
		s.set_meta("prop", p)


## The pipe's props this frame: the brand in hand only while it's lit from
## the fire, the bowl's ember only on a draw.
static func _pipe_props(s: Node3D, t: float, plan: Dictionary) -> void:
	var pack := float(plan.get("pack", 4.0))
	var brand = s.get_meta("brand") if s.has_meta("brand") else null
	if brand != null and is_instance_valid(brand):
		(brand as Node3D).visible = t >= pack and t < pack + float(plan.get("light", 3.0))
	var prop = s.get_meta("prop") if s.has_meta("prop") else null
	if prop != null and is_instance_valid(prop):
		var ember := (prop as Node3D).get_node_or_null("Ember") as Node3D
		if ember:
			ember.visible = drawing(plan, t)


## The pipe's smoke (idles.pipe.smoke): at the end of each draw a few
## square puffs (puffs_per_breath) leave the hood, rise at rise_mps, drift
## with the weather's wind (wind_share), grow and fade in two flat bands of
## the hearth smoke's colours over life_s; never glowing. One MultiMesh per
## sitter, made on its first pipe.
const PUFFS_MAX := 16
static var _puff_quad: QuadMesh

static func _puffs(s: Node3D, time: float, delta: float, plan: Dictionary, t: float) -> void:
	var sm: Dictionary = (IDLES.get("pipe", {}) as Dictionary).get("smoke", {})
	var mmi = s.get_meta("puffs") if s.has_meta("puffs") else null
	if mmi == null and plan.is_empty():
		return
	if mmi == null or not is_instance_valid(mmi):
		if _puff_quad == null:
			_puff_quad = QuadMesh.new()
			_puff_quad.size = Vector2(1, 1)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _puff_quad
		mm.instance_count = PUFFS_MAX
		mmi = MultiMeshInstance3D.new()
		mmi.name = "Puffs"
		mmi.multimesh = mm
		mmi.top_level = true
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		(mmi as MultiMeshInstance3D).material_override = m
		(mmi as MultiMeshInstance3D).extra_cull_margin = 4.0
		s.add_child(mmi)
		s.set_meta("puffs", mmi)
		s.set_meta("puff_list", [])
	var list: Array = s.get_meta("puff_list")
	# A breath out at the end of each draw.
	if not plan.is_empty():
		var was := bool(s.get_meta("was_drawing", false))
		var now := drawing(plan, t)
		if was and not now:
			var head: Node3D = s.get_meta("head")
			var at := head.global_position + s.global_basis.z * -0.18 if head else s.global_position + Vector3.UP * 1.0
			var pp: Array = sm.get("puffs_per_breath", [2, 4])
			for k in randi_range(int(pp[0]), int(pp[1])):
				list.append([time + k * 0.15, at + Vector3(randf_range(-0.04, 0.04), randf_range(-0.03, 0.03), randf_range(-0.04, 0.04))])
		s.set_meta("was_drawing", now)
	var life := float(sm.get("life_s", 3.5))
	var rise := float(sm.get("rise_mps", 0.35))
	var share := float(sm.get("wind_share", 1.0))
	var look: Dictionary = (Smoke.H.get("look", {}) as Dictionary)
	var c_near := Color(str(look.get("colour_near", "#8FA0C8")))
	var c_far := Color(str(look.get("colour_far", "#B4C2E8")))
	var mm2 := (mmi as MultiMeshInstance3D).multimesh
	var keep: Array = []
	for e in list:
		if time - float(e[0]) < life:
			keep.append(e)
	list = keep.slice(maxi(0, keep.size() - PUFFS_MAX))
	s.set_meta("puff_list", list)
	var up := s.global_basis.y.normalized()
	for i in PUFFS_MAX:
		if i >= list.size() or time < float(list[i][0]):
			mm2.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), s.global_position))
			continue
		var age := time - float(list[i][0])
		var k2 := age / life
		var p: Vector3 = (list[i][1] as Vector3) + up * rise * age + Smoke.wind * share * age * 0.3
		var size := lerpf(0.05, 0.22, k2)
		mm2.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), p))
		mm2.set_instance_color(i, c_near if k2 < 0.55 else c_far)
	(mmi as MultiMeshInstance3D).visible = not list.is_empty()
