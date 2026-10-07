extends SceneTree
## The dungeon's boss (design 6 Oct §EY.1, §EY.2; queue 49; Mike's note of
## 7 Oct; Boss, BossGround, LightField, bosses.json), headless, over seeds
## 1, 7 and 42 (BOSS_SEEDS="1,7,42" to change; BOSS_ONLY="speed,edge" for
## some parts only):
##   godot --headless --path . --fixed-fps 60 --script tools/boss_check.gd
## Asserts, for each seed:
##  1. its ground (BossGround): the dark node count never rises as the
##     holders are relit (in the layout's order, outward from the hearth,
##     and shuffled) and reaches nothing at the last holder, never before;
##     the hearth room is never its ground;
##  2. the lair: placed, in a room off the main way (BossGround.main_path:
##     the spine, or hearth room to heart), clear of that room's doors, the
##     line between them, its walls and (in a crypt, where it takes one
##     coffin's place) its other coffins, no skeleton resting in that one;
##     over 30 more layouts too; and in the built tomb nothing solid stands
##     round its rim;
##  3. its own tunnels (Mike's note of 7 Oct; bosses.json desert.tunnels):
##     tunnels.holes of them, one in its lair room, none in the hearth room,
##     on the spine, the way out or a stair, each at the foot of its wall,
##     apart_m apart, all joined, every tunnel longer than the straight line
##     between its holes and under every floor it crosses (30 more layouts
##     too); in the built tomb each hole is cut out of the wall's stone
##     (nothing of the face across it), dark inside, the wall's collision
##     whole across it (you can't fit), the floor before it open;
##  4. contact: you standing still in the dark beside it with your torch
##     lit: it holds at the torch's edge (torch_delay), then strikes; the
##     hits land no closer together than harm.json's invuln_s; the third is
##     "Good night", and you wake on the mat by the hearth with the holders
##     you lit still lit, your hands empty; it lets you go where it is (no
##     reappearing far off) and goes on with its rounds; then with your
##     torch out it comes straight in (no hold); and a lit swing at half
##     its wind-up staggers it (queue 57's CreatureStrike), struck at from
##     its coil and come at you through its dark: it reels reel_m back and
##     no hit counts;
##  5. its speed (Mike's note of 7 Oct): hunt_mps faster than your walk and
##     slower than your sprint; on a long dark run with it 5 m behind you,
##     walking it catches you and its strike lands (it keeps coming through
##     its wind-up), sprinting the gap only grows and nothing reaches you;
##  6. the light's edge (Mike's note of 7 Oct, amending §FD): hunting you,
##     its delay spent, while you stand by the hearth and then deep in a
##     relit room: it never stands where the light passes the chase's cap,
##     it comes to the edge (the light at its feet near the cap), rears its
##     head forward into the glow (brighter at its head than at its feet),
##     no strike reaches you, you don't heal while it watches, and it gives
##     you up after watch_s; then you at the light's dim edge, within its
##     reach of where it may stand: its strike lands;
##  7. its tunnels in use: sent through one, it goes in at one hole, is
##     hidden inside for at least the tunnel's length over its speed (its
##     tell muffled), and comes out of the other; its whole side way relit
##     round it, it leaves under the light through a tunnel, not through
##     the hearth room;
##  8. the dimmest way: its room and the way out of it relit, it crosses
##     the light to the dark by a way measurably dimmer than the shortest
##     (the light along each, LightField.along);
##  9. a fire pot (§FA.4, Mike's note of 7 Oct): a burst at its head stuns
##     it (no strike, no chase) for stun_s, then it travels to its lair's
##     hole and down it, out of every pot's reach, stays there
##     fire_pots.json vs_boss.drives_off_s, breathing, and comes up out of
##     the hole onto its rounds, never burnt or killed;
## 10. a scripted run relighting every holder in the layout's order, the
##     snake free between relights (you in the hearth room): it never walks
##     into a lit node of its own accord, it leaves one lit round it at once
##     and gets to the dark, through the hearth room only when there was no
##     other way, and after the last light it travels to its lair and goes
##     down the hole for good, breathing (heard within
##     lair.breathing_heard_m), the log has release.log_line and the tomb's
##     small sounds come back; its tell plays as it prowls, quieter coiled;
## 11. the walk to the way out (queue 46's check) with it loose: you, your
##     torch lit, from the wake spot through the spine's doors into the
##     opening, the snake on its own clock, from where it starts and again
##     lying coiled in the heart, across your way; you walk, and once it is
##     after you, you sprint (sprinting is how you escape it now): you get
##     out (CrawlerMain.walk_out), never taken; the hits it lands are
##     reported.
## And over every run where it moves on its own (5 to 11): nothing teleports
## (Mike's note of 7 Oct): no frame moves its head's line further than its
## top speed (Boss.max_mps) allows, its body never jumps, and it is never
## hidden while any of it is above the floor.

var fails := 0
var DT := 1.0 / 30.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	# The tomb's skeletons sleep through this check (design §FE; queue 58).
	Residents.stay_asleep = true
	Bow.need_capture = false
	var seeds: Array = [1, 7, 42]
	var env := OS.get_environment("BOSS_SEEDS")
	if env != "":
		seeds = []
		for s in env.split(","):
			if s.strip_edges().is_valid_int():
				seeds.append(int(s))
	# BOSS_ONLY="speed,edge" runs only those parts (a quicker look while
	# working on one): layouts, contact, speed, edge, tunnels, dimmest, pot,
	# relight, walkout.
	var only := OS.get_environment("BOSS_ONLY").split(",", false)
	var want := func(part: String) -> bool: return only.is_empty() or only.has(part)
	if want.call("layouts"):
		_lairs()
		_tunnel_layouts()
	for sv in seeds:
		print("== seed %d" % sv)
		var lay := TombKit.layout(sv)
		var main: CrawlerMain
		if want.call("layouts"):
			_ground(lay)
			var why := _tunnel_ok(lay)
			ok(why == "", "its tunnels: %d holes (%s), %d tunnels %s" % [(lay.tunnels.holes as Array).size(), _hole_names(lay), (lay.tunnels.links as Array).size(), why])
		if want.call("contact"):
			main = await _boot(sv)
			_lair_of(main)
			_tunnels_built(main)
			await _contact(main)
			await _stagger(main)
			await _done(main)
		if want.call("speed"):
			main = await _boot(sv)
			await _speed(main)
			await _done(main)
		if want.call("edge"):
			main = await _boot(sv)
			await _edge(main)
			await _done(main)
		if want.call("tunnels"):
			main = await _boot(sv)
			await _tunnel_run(main)
			await _bypass(main)
			await _done(main)
		if want.call("dimmest"):
			main = await _boot(sv)
			await _dimmest(main)
			await _done(main)
		if want.call("pot"):
			main = await _boot(sv)
			await _pot(main)
			await _done(main)
		if want.call("relight"):
			main = await _boot(sv)
			await _relight_run(main)
			await _done(main)
		if want.call("walkout"):
			for in_heart in [false, true]:
				main = await _boot(sv)
				await _walk_out_run(main, in_heart)
				await _done(main)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _boot(sv: int) -> CrawlerMain:
	OS.set_environment("SEED", str(sv))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked or not main.boss.started:
		await process_frame
	main.boss.auto = false
	return main


func _done(main: CrawlerMain) -> void:
	main.queue_free()
	await process_frame


# --- Nothing teleports (Mike's note of 7 Oct) -----------------------------------

## What the tracker saw of its motion since _mo_reset: frames, its fastest
## step (m/s) of its head's line (base), of its head and of its tail's end,
## the steps past its top speed, and frames it was hidden with any of it
## above the floor.
var _mo := {}


func _mo_reset(b: Boss) -> void:
	_mo = {"frames": 0, "worst": 0.0, "worst_head": 0.0, "worst_tail": 0.0, "over": 0, "vanished": 0,
		"base": b.base, "head": b.trail[0] if not b.trail.is_empty() else b.head, "tail": _tail_of(b)}


## Where its tail's end is drawn (Boss._pose: its last length of body, laid
## along the trail its head left, straight on back past the trail's end).
func _tail_of(b: Boss) -> Vector3:
	var want := b.body.head_len * 0.45 + float(b.body.segs.size() - 1) * b.body.spacing
	var acc := 0.0
	var last_dir := -b.dir
	for k in range(b.trail.size() - 1):
		var a: Vector3 = b.trail[k]
		var c: Vector3 = b.trail[k + 1]
		var l := a.distance_to(c)
		var dv := Vector3(a.x - c.x, 0.0, a.z - c.z)
		if dv.length() > 1e-4:
			last_dir = -dv.normalized()
		if acc + l >= want:
			return a.lerp(c, (want - acc) / maxf(l, 1e-4))
		acc += l
	var end: Vector3 = b.trail[-1] if not b.trail.is_empty() else b.head
	return end + last_dir * (want - acc)


## One frame's motion (`dt` long): its head's line moves no more than
## max_mps * dt (and a hair), its head with the slither's sway no more than
## half again, its tail's end as drawn no more than that and a trail step;
## and it is drawn whenever any of it is above the floor.
func _mo_step(b: Boss, dt: float) -> void:
	_mo.frames = int(_mo.frames) + 1
	var bound := b.max_mps() * dt + 0.02
	var d := (b.base as Vector3).distance_to(_mo.base)
	var h: Vector3 = b.trail[0] if not b.trail.is_empty() else b.head
	var tl := _tail_of(b)
	var dh := h.distance_to(_mo.head)
	var dtl := tl.distance_to(_mo.tail)
	_mo.worst = maxf(float(_mo.worst), d / dt)
	_mo.worst_head = maxf(float(_mo.worst_head), dh / dt)
	_mo.worst_tail = maxf(float(_mo.worst_tail), dtl / dt)
	if d > bound or dh > bound * 1.6 + 0.02 or dtl > bound * 1.6 + Boss.TRAIL_STEP * 2.0:
		_mo.over = int(_mo.over) + 1
		if int(_mo.over) <= 3:
			print("  a step too far (%s): its line %.3f m, its head %.3f m, its tail %.3f m in %.3f s (bound %.3f m)" % [b.state, d, dh, dtl, dt, bound])
	if not b.body.visible and b.body.baked and not b._all_below():
		_mo.vanished = int(_mo.vanished) + 1
	_mo.base = b.base
	_mo.head = h
	_mo.tail = tl


func _mo_ok(how: String) -> void:
	ok(int(_mo.over) == 0 and int(_mo.vanished) == 0 and int(_mo.frames) > 0, "%s: nothing teleports: over %d frames its fastest step %.2f m/s (its head %.2f, its tail %.2f; top speed %.1f), %d steps too far, %d frames hidden above the floor" % [how, int(_mo.frames), float(_mo.worst), float(_mo.worst_head), float(_mo.worst_tail), _b_max(), int(_mo.over), int(_mo.vanished)])


var _last_max := 6.0


func _b_max() -> float:
	return _last_max


## Step the snake (and Harm) one `dt`, tracking its motion.
func _tick(main: CrawlerMain, dt: float) -> void:
	main.boss.tick(dt)
	main.harm.tick(dt)
	_last_max = main.boss.max_mps()
	_mo_step(main.boss, dt)


# --- 1. The ground -------------------------------------------------------------

func _ground(lay: Dictionary) -> void:
	var g := BossGround.build(lay)
	var n := (lay.holders as Array).size()
	var hearth_ok := true
	for nd in g.nodes:
		if bool(nd.hearth) and g.is_ground(int(nd.id)):
			hearth_ok = false
	ok(hearth_ok and g.ground_count() > 0, "its ground at the start: %d of %d nodes dark (%d rooms, the rest corridor stretches), the hearth room not among them" % [g.ground_count(), g.nodes.size(), _rooms(g)])
	# Three orders: the layout's, outward from the hearth room, shuffled.
	var orders := {"layout": range(n), "outward": _outward(lay, g), "shuffled": _shuffled(n, int(lay.seed))}
	for name in orders:
		var order: Array = orders[name]
		var lit: Array = []
		lit.resize(n)
		lit.fill(false)
		g.update(lit)
		var counts: Array = [g.ground_count()]
		var rises := 0
		var early := -1
		for k in order.size():
			lit[order[k]] = true
			g.update(lit)
			var c := g.ground_count()
			if c > int(counts[-1]):
				rises += 1
			if c == 0 and k < order.size() - 1 and early < 0:
				early = k
			counts.append(c)
		ok(rises == 0 and early < 0 and int(counts[-1]) == 0, "relit %s: the dark never grows and is gone only at the last of %d holders (%s)" % [name, n, _short(counts)])


func _rooms(g: BossGround) -> int:
	var k := 0
	for nd in g.nodes:
		if str(nd.kind) == "room":
			k += 1
	return k


func _short(a: Array) -> String:
	var parts: Array = []
	for v in a:
		parts.append(str(v))
	return " ".join(parts)


## The holders by their distance from the hearth room.
func _outward(lay: Dictionary, g: BossGround) -> Array:
	var dist: Dictionary = g._dijkstra(0, false, 0.0).dist
	var hs: Array = []
	for i in (lay.holders as Array).size():
		var h: Dictionary = lay.holders[i]
		var id := g.node_at(h.pos)
		hs.append([float(dist.get(id, 999.0)), i])
	hs.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: Array = []
	for x in hs:
		out.append(int(x[1]))
	return out


func _shuffled(n: int, s: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31 + 5
	var a: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


# --- 2. The lair ----------------------------------------------------------------

func _lair_ok(lay: Dictionary) -> String:
	var l: Dictionary = lay.get("lair", {})
	if l.is_empty():
		return "no lair"
	var pc: Dictionary = lay.pieces[int(l.piece)]
	if str(pc.kind) != "room" or str(pc.get("room_kind", "")) in ["hearth", "heart"]:
		return "in a %s %s" % [pc.get("room_kind", ""), pc.kind]
	if int(l.piece) in BossGround.main_path(lay):
		return "on the main way"
	var c := Vector2((l.pos as Vector3).x, (l.pos as Vector3).z)
	for di in pc.doors:
		var d: Dictionary = lay.doors[di]
		if c.distance_to(d.p) < float(l.r) + 1.9:
			return "%.2f m from a door" % c.distance_to(d.p)
	for i in (pc.doors as Array).size():
		for j in range(i + 1, (pc.doors as Array).size()):
			var a: Vector2 = lay.doors[pc.doors[i]].p
			var b: Vector2 = lay.doors[pc.doors[j]].p
			if c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)) < float(l.r) + 1.1:
				return "in the way between its doors"
	# Off the walls, and off a crypt's coffins but the one whose place it
	# took (it fell through with the floor), no one resting in that one.
	var aa := Delves.along_across(pc, c)
	var wall := minf(minf(aa.x, float(pc.len) - aa.x), float(pc.half) - absf(aa.y)) - float(l.r)
	if wall < 0.5:
		return "%.2f m from a wall" % wall
	if str(pc.get("room_kind", "")) == "crypt":
		var coffins := TombKit.coffin_spots(lay, pc)
		if not coffins.is_empty() and not l.has("coffin"):
			return "on a crypt's floor, not where a coffin stood"
		for s in coffins:
			if TombKit.lair_took(lay, int(pc.id), int(s.i)):
				continue
			var mid := float(s.sd) * (float(pc.half) - TombKit.COFFIN_IN)
			var dx := maxf(absf(aa.x - float(s.along)) - TombKit.COFFIN_SIZE.x * 0.5, 0.0)
			var dy := maxf(absf(aa.y - mid) - TombKit.COFFIN_SIZE.z * 0.5, 0.0)
			var gap := Vector2(dx, dy).length() - float(l.r)
			if gap < 0.5:
				return "%.2f m from coffin %d" % [gap, int(s.i)]
	# Never a skeleton's grave, nor beside one (its lid lies on the floor
	# beside it, either way along the row: TombBuild._open_coffin).
	if l.has("coffin"):
		var coffins := TombKit.coffin_spots(lay, pc)
		var mine: Dictionary = coffins[int(l.coffin)]
		for rp in lay.get("residents", []):
			if int(rp.piece) != int(l.piece) or str(rp.rests_in) != "grave" or int(rp.spot) < 0:
				continue
			if int(rp.spot) == int(l.coffin):
				return "a skeleton rests where it is"
			var g: Dictionary = coffins[int(rp.spot)]
			if float(g.sd) == float(mine.sd) and absf(float(mine.along) - float(g.along)) < float(l.r) + 1.5 + 0.3:
				return "beside an open grave (%.2f m along)" % absf(float(mine.along) - float(g.along))
	return ""


func _lairs() -> void:
	var bad := 0
	var dead_ends := 0
	var kinds := {}
	var in_coffins := 0
	for s in 30:
		var lay := TombKit.layout(5000 + s * 7919)
		var why := _lair_ok(lay)
		if why != "":
			bad += 1
			print("  seed %d: lair %s" % [lay.seed, why])
			continue
		if (lay.pieces[int(lay.lair.piece)].doors as Array).size() == 1:
			dead_ends += 1
		var k := str(lay.pieces[int(lay.lair.piece)].get("room_kind", ""))
		kinds[k] = int(kinds.get(k, 0)) + 1
		if lay.lair.has("coffin"):
			in_coffins += 1
	ok(bad == 0, "30 layouts: a lair in a side room off the main way every time, clear of its doors, its walls and the coffins (%d in dead ends; rooms %s; %d where a coffin stood)" % [dead_ends, str(kinds), in_coffins])


func _lair_of(main: CrawlerMain) -> void:
	var why := _lair_ok(main.lay)
	var l: Dictionary = main.lay.get("lair", {})
	ok(why == "", "the lair: room %s (%s), off the main way %s, the hole %.1f m across %s" % [l.get("piece", "-"), main.lay.pieces[int(l.get("piece", 0))].get("room_kind", ""), str(BossGround.main_path(main.lay)), float(l.get("r", 0.0)) * 2.0, why])
	# Not a way down: the ring keeps you at its edge.
	if not l.is_empty():
		var c: Vector3 = l.pos
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(float(l.r) + 1.0, 0.8, 0.0), c + Vector3(0.0, 0.8, 0.0))
		q.exclude = [main.player.get_rid()]
		var hit := get_root().get_world_3d().direct_space_state.intersect_ray(q)
		ok(not hit.is_empty() and (hit.position as Vector3).distance_to(c) > float(l.r) - 0.05, "you can stand at the hole's edge but not step in (enterable false)")
		# Nothing stands round its rim (a coffin or its lid, a slab, a pile
		# of bones): the floor there is bare but for its own broken flags and
		# stones. Straight down from 2 m (the stone's collision is faces,
		# which a point inside them never meets).
		var space := get_root().get_world_3d().direct_space_state
		var solid := 0
		var probes := 0
		for out: float in [0.2, 0.45]:
			for k in 16:
				var a := TAU * k / 16.0
				var p := c + Vector3(cos(a), 0.0, sin(a)) * (float(l.r) + out)
				var rq := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, 0.08, 0.0))
				rq.collision_mask = PropCollision.WORLD_LAYER
				probes += 1
				if not space.intersect_ray(rq).is_empty():
					solid += 1
		var took := " (where coffin %d stood)" % int(l.coffin) if l.has("coffin") else ""
		ok(solid == 0, "nothing stands round its rim%s: %d of %d spots within 0.45 m of it have anything on them" % [took, solid, probes])


# --- 3. Its own tunnels (Mike's note of 7 Oct) ----------------------------------------

func _hole_names(lay: Dictionary) -> String:
	var parts: Array = []
	for h in (lay.get("tunnels", {}) as Dictionary).get("holes", []):
		var pc: Dictionary = lay.pieces[int(h.piece)]
		parts.append("%s %s%s" % [str(pc.get("room_kind", pc.kind)), str(h.side), " (its lair's room)" if bool(h.lair) else ""])
	return ", ".join(parts)


## The tunnels as laid: "" if they keep every rule, else why not.
func _tunnel_ok(lay: Dictionary) -> String:
	var t: Dictionary = lay.get("tunnels", {})
	var td := BossGround.tunnels_def()
	if td.is_empty():
		return "no tunnels block"
	var holes: Array = t.get("holes", [])
	var links: Array = t.get("links", [])
	var span: Array = td.get("holes", [3, 5])
	if holes.size() < int(span[0]) or holes.size() > int(span[1]):
		return "%d holes (want %s)" % [holes.size(), str(span)]
	var main := BossGround.main_path(lay)
	var in_lair := 0
	var apart := float(td.get("apart_m", 6.0))
	for i in holes.size():
		var h: Dictionary = holes[i]
		var pc: Dictionary = lay.pieces[int(h.piece)]
		if not str(pc.kind) in ["room", "corridor"]:
			return "a hole in a %s" % pc.kind
		if str(pc.get("room_kind", "")) in ["hearth", "heart"] or int(pc.id) in main or bool(pc.get("spine", false)):
			return "a hole on the way (piece %d, %s)" % [int(pc.id), pc.get("room_kind", pc.kind)]
		var ws := BossGround._wall_of(pc, Vector2((h.pos as Vector3).x, (h.pos as Vector3).z))
		if str(ws[0]) != str(h.side):
			return "hole %d not on its wall (%s, %s)" % [i, str(ws[0]), str(h.side)]
		var fy := Delves.floor_of(pc, clampf(Delves.along_across(pc, Vector2((h.pos as Vector3).x, (h.pos as Vector3).z)).x, 0.0, float(pc.len)))
		if absf((h.pos as Vector3).y - fy) > 0.01:
			return "hole %d not at the floor's foot" % i
		if bool(h.lair):
			in_lair += 1
			if int(h.piece) != int((lay.lair as Dictionary).get("piece", -1)):
				return "the lair's hole not in its room"
		for j in range(i + 1, holes.size()):
			if Vector2((h.pos as Vector3).x - (holes[j].pos as Vector3).x, (h.pos as Vector3).z - (holes[j].pos as Vector3).z).length() < apart - 1e-3:
				return "holes %d and %d closer than apart_m" % [i, j]
	if not (lay.get("lair", {}) as Dictionary).is_empty() and in_lair != 1:
		return "%d holes in the lair's room" % in_lair
	# All joined.
	var seen := {0: true}
	var grew := true
	while grew:
		grew = false
		for l in links:
			if seen.has(int(l.a)) != seen.has(int(l.b)):
				seen[int(l.a)] = true
				seen[int(l.b)] = true
				grew = true
	if seen.size() != holes.size():
		return "not all joined (%d of %d)" % [seen.size(), holes.size()]
	# Each tunnel longer than the straight line, and under every floor it
	# crosses.
	for l in links:
		var a: Vector3 = holes[int(l.a)].pos
		var b: Vector3 = holes[int(l.b)].pos
		if float(l.len) < a.distance_to(b) - 1e-3:
			return "a tunnel %.1f m between holes %.1f m apart" % [float(l.len), a.distance_to(b)]
		var pts: PackedVector3Array = l.pts
		var deep := pts[3].y
		var a2 := Vector2(pts[3].x, pts[3].z)
		var b2 := Vector2(pts[4].x, pts[4].z)
		var steps := maxi(int(a2.distance_to(b2) / 0.5), 1)
		for k in steps + 1:
			var q := a2.lerp(b2, float(k) / steps)
			for pc in lay.pieces:
				if Delves.rect_of(pc, Delves.WALL).has_point(q) and deep > minf(float(pc.y0), float(pc.y1)) - 0.5:
					return "a tunnel %.2f m under piece %d's floor" % [minf(float(pc.y0), float(pc.y1)) - deep, int(pc.id)]
	return ""


func _tunnel_layouts() -> void:
	var bad := 0
	var counts := {}
	var lens: Array = []
	for s in 30:
		var lay := TombKit.layout(7000 + s * 6151)
		var why := _tunnel_ok(lay)
		if why != "":
			bad += 1
			print("  seed %d: tunnels %s" % [lay.seed, why])
			continue
		var n := (lay.tunnels.holes as Array).size()
		counts[n] = int(counts.get(n, 0)) + 1
		for l in lay.tunnels.links:
			lens.append(float(l.len))
	lens.sort()
	ok(bad == 0, "30 layouts: its own tunnels every time by the rules (holes %s a tomb; tunnels %.0f-%.0f m long)" % [str(counts), float(lens[0]) if not lens.is_empty() else 0.0, float(lens[-1]) if not lens.is_empty() else 0.0])


## In the built tomb: each hole cut out of the wall's stone, its dark hung
## in it, the wall's collision whole across it, the floor before it open.
func _tunnels_built(main: CrawlerMain) -> void:
	var holes: Array = (main.lay.get("tunnels", {}) as Dictionary).get("holes", [])
	if holes.is_empty():
		ok(false, "the built tomb has its tunnels' holes")
		return
	# The stone's vertices (every chunk of the tomb's mesh).
	var verts := PackedVector3Array()
	for c in main.tomb.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
			var m := (c as MeshInstance3D).mesh as ArrayMesh
			for si in m.get_surface_count():
				verts.append_array(m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
	var covered := 0
	var blocked := 0
	var open_floor := 0
	var space := main.get_viewport().world_3d.direct_space_state
	for h in holes:
		var pos: Vector3 = h.pos
		var n: Vector3 = h.n
		var u: Vector3 = h.u
		var w := float(h.w)
		var hh := float(h.h)
		# Anything of the face across the opening (its middle, inside the
		# arch, a hand either side of the face's plane)?
		for v in verts:
			var r := v - pos
			var off := r.dot(n)
			if off < -0.15 or off > 0.2:
				continue
			var x := r.dot(u)
			var y := r.y
			if absf(x) > w * 0.5 - 0.06 or y < 0.06 or y > hh - 0.06:
				continue
			# Inside the arch's round top.
			var spring := hh - w * 0.5
			if y > spring and Vector2(x, y - spring).length() > w * 0.5 - 0.06:
				continue
			if off > -0.02:
				covered += 1
		# Your body can't get in: a ray at knee height into it stops at the
		# wall's face.
		var q := PhysicsRayQueryParameters3D.create(pos + n * 0.6 + Vector3.UP * 0.2, pos - n * 0.4 + Vector3.UP * 0.2)
		q.collision_mask = PropCollision.WORLD_LAYER
		q.exclude = [main.player.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf(((hit.position as Vector3) - pos).dot(n)) < 0.08:
			blocked += 1
		var nav := main.residents.nav
		if nav.is_open(nav.cell_of(h.out)):
			open_floor += 1
	var mouths := 0
	for c in main.boss.get_children():
		if c is MeshInstance3D and str(c.name).begins_with("TunnelMouth"):
			mouths += 1
	ok(covered == 0 and mouths == holes.size(), "every hole (%d) is cut out of its wall's fitted stone (%d vertices of the face across them) and dark inside (%d dark mouths)" % [holes.size(), covered, mouths])
	ok(blocked == holes.size() and open_floor == holes.size(), "you can't fit: the wall's collision is whole across every hole (%d of %d), and the floor before each is open (%d of %d)" % [blocked, holes.size(), open_floor, holes.size()])


# --- 4. Contact ------------------------------------------------------------------

## Step the boss and the harm together `secs` seconds (the player stands
## as placed: no physics runs).
func _sim(main: CrawlerMain, secs: float, stop: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		main.boss.tick(DT)
		main.harm.tick(DT)
		t += DT
		if stop.is_valid() and bool(stop.call()):
			break
	return t


func _place(p: CrawlerPlayer, at: Vector3, look: Vector3) -> void:
	var flat := Vector3(look.x - at.x, 0.0, look.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z), 0.0)


func _light_holder(main: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, h.global_position)
		if FireStore.is_lit(h):
			return


func _contact(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var t := p.torch
	var fires := main.fires
	# Two holders lit first (they must still be lit when you wake): the
	# hearth room's own corridor sconces, if any, else the first two.
	var lit_first: Array = []
	for i in mini(2, fires.holders.size()):
		_light_holder(main, fires.holders[i])
		lit_first.append(i)
	b._refresh(false)
	# Beside it in the dark: 3 m in front of its head, in its own node.
	var spot := _beside(b, 3.0)
	ok(spot != Vector3.INF, "a spot in its dark 3 m from it (it lies coiled in node %d, a %s)" % [b.node, b.ground.nodes[b.node].kind])
	if spot == Vector3.INF:
		return
	p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	t.light()
	_place(p, spot, b.head)
	await physics_frame
	var hits_at: Array = []
	var landed0 := main.harm.landed
	var noticed_at := -1.0
	var hold_from := -1.0
	var hold_until := -1.0
	var clock := 0.0
	var invuln := float(Harm.D.get("invuln_s", 0.6))
	while clock < 40.0 and not main.harm.taking:
		_sim(main, DT)
		clock += DT
		if b.noticed and noticed_at < 0.0:
			noticed_at = clock
		if b.state == "hang" and hold_from < 0.0:
			hold_from = clock
		if hold_from >= 0.0 and hold_until < 0.0 and b.state in ["hunt", "strike"]:
			hold_until = clock
		if main.harm.landed > landed0 + hits_at.size():
			hits_at.append(clock)
	# One more beat: it sees you are taken.
	_sim(main, DT)
	var at_taken := b.base
	var gaps: Array = []
	for k in range(1, hits_at.size()):
		gaps.append(float(hits_at[k]) - float(hits_at[k - 1]))
	var min_gap: float = gaps.min() if not gaps.is_empty() else 0.0
	var delay := b.sub("torch_delay")
	print("  noticed at %.2f s, held %.2f..%.2f s, hits at %s" % [noticed_at, hold_from, hold_until, str(hits_at)])
	ok(noticed_at >= 0.0 and noticed_at < 1.0, "your lit torch in its sight: it notices you (%.2f s)" % noticed_at)
	ok(hold_from >= 0.0 and hold_until - hold_from >= float(delay.get("hang_s", 4.0)) - 0.1, "your torch is a delay: it holds at the torch's edge %.1f s before it closes (torch_delay.hang_s %.1f)" % [hold_until - hold_from, float(delay.get("hang_s", 4.0))])
	ok(hits_at.size() == 3 and min_gap >= invuln - 0.01, "standing still in the dark beside it: three hits (%d), never closer than invuln_s %.2f (closest %.2f s apart)" % [hits_at.size(), invuln, min_gap])
	ok(main.harm.taking and b.state == "held", "the third hit takes you: \"Good night\" (Harm), and it holds off")
	# The taken sequence plays out; you wake at the hearth.
	_sim(main, Harm.taken_s() + 0.5, func(): return not main.harm.taking)
	await process_frame
	var w: Array = main.lay.wake
	var at_hearth := p.global_position.distance_to(w[0]) < 0.3
	var still_lit := true
	for i in lit_first:
		if not FireStore.is_lit(fires.holders[i]):
			still_lit = false
	ok(at_hearth and not p.dead and not main.harm.taking and main.harm.hits.is_empty(), "you wake on the mat by the hearth (%.2f m from it), whole" % p.global_position.distance_to(w[0]))
	ok(still_lit and fires.lit_count() == lit_first.size(), "every light you lit is still lit (%d of %d)" % [fires.lit_count(), lit_first.size()])
	ok(p.weapon == "hands" and not t.lit() and p.inventory.has_kind("torch"), "your torch went out as you fell; it is in your pack, your hands empty")
	var moved := b.base.distance_to(at_taken)
	ok(b.state in ["coil", "prowl"] and not b.noticed and b.ground.is_ground(b.node) and moved < 1.0, "it lets you go where it is and goes on with its rounds (%s, node %d, %.2f m from where it took you: never reappearing far off, Mike's note of 7 Oct)" % [b.state, b.node, moved])
	ok(GameLog.entries.size() > 0 and str(GameLog.entries[-1].text).contains("wake by the hearth"), "the log: \"%s\"" % str(GameLog.entries[-1].text))
	# Torch out: it comes straight in (once the breath after waking,
	# PlanetPlayer.revive's few seconds, has run out). It is laid coiled in
	# its far dead end again for this (a harness's placing: on its rounds it
	# may be anywhere, a tunnel's run included).
	for i in 200:
		await physics_frame
	b._let_go("check")
	b._calm()
	b._start_far()
	_sim(main, 1.0)
	var spot2 := _beside(b, 1.2)
	if spot2 != Vector3.INF:
		p.weapon = "hands"
		_place(p, spot2, b.head)
		await physics_frame
		var landed1 := main.harm.landed
		var first := -1.0
		var held := false
		var c2 := 0.0
		while c2 < 8.0 and first < 0.0:
			_sim(main, DT)
			c2 += DT
			if b.state == "hang":
				held = true
			if main.harm.landed > landed1:
				first = c2
		ok(first > 0.0 and first < 2.5 and not held, "your torch out, it comes straight in: no hold, the first strike lands at %.2f s" % first)
	else:
		ok(false, "a spot 1.2 m from it for the torch-out strike")
	# Let Harm settle (its hitstop and its clock run on real frames).
	main.harm.reset()
	for i in 4:
		await process_frame


## One physics frame, the snake stepped with it (the torch's swing and Harm
## run on real frames).
func _step(main: CrawlerMain) -> void:
	await physics_frame
	main.boss.tick(1.0 / 60.0)


## 4b. The torch's stagger on the snake itself (§FA.1, queue 57's
## CreatureStrike), twice: struck at from its coil (you 2.2-2.6 m off),
## then come at you through its dark (you 4-5 m off), each spot out of the
## swing's reach of any unlit holder. It is laid coiled in the far dead end
## of its dark for each (a harness's placing). Your torch lit, it closes
## after its delay and winds up; a swing whose arc tops out at half the
## wind-up breaks the strike, it reels reel_m away from you (back along its
## body when that leads away, else straight back, its body following),
## and no hit counts.
func _stagger(main: CrawlerMain) -> void:
	var p := main.player
	main.harm.reset()
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	p.torch.light()
	main.boss._let_go("check")
	main.boss._start_far()
	await _swing_into(main, [2.6, 2.4, 2.2], "struck at from its coil")
	main.boss._let_go("check")
	main.boss._calm()
	main.boss._start_far()
	await _swing_into(main, [5.0, 4.5, 4.0], "come at you through its dark")
	p.torch.put_out("check")
	p.weapon = "hands"
	main.harm.reset()
	for i in 4:
		await process_frame


func _swing_into(main: CrawlerMain, dists: Array, how: String) -> void:
	var b := main.boss
	var p := main.player
	var t := p.torch
	var spot := Vector3.INF
	# Out of the swing's reach of any unlit holder: a swing passes the
	# flame (§CN), and a holder relit beside it would send it off (§EY.1).
	for d in dists:
		spot = _beside(b, float(d), Torch.reach_m() + 0.6)
		if spot != Vector3.INF:
			break
	ok(spot != Vector3.INF, "%s: a spot in its dark %.1f m from it, for the swing" % [how, float(dists[0])])
	if spot == Vector3.INF:
		return
	main.harm.reset()
	p._invulnerable = 0.0
	b.strike.cooldown_left = 0.0
	_place(p, spot, b.head)
	await physics_frame
	var c := 0.0
	var went: Array = []
	while c < 15.0 and b.strike.state != "wind_up" and not main.harm.taking:
		_sim(main, DT)
		c += DT
		if went.is_empty() or went[-1] != b.state:
			went.append(b.state)
	if b.strike.state != "wind_up":
		ok(false, "%s: with your torch lit it closes and winds up (%s after %.1f s; it went %s, %.1f m from you)" % [how, b.strike.state, c, " ".join(went), _flat_d(b.base, p.global_position)])
		return
	var landed0 := main.harm.landed
	var stag0 := b.strike.staggers
	# Face its head, then swing so the arc's top meets half its wind-up.
	_place(p, p.global_position, b.strike.global_position)
	var lead := Fists.STRIKE_S * (1.0 - Torch.SWING_TOP) + 1.0 / 60.0
	var guard := 0
	while b.strike.state == "wind_up" and b.strike.t < 0.5 * b.strike.wind_up_s - lead and guard < 120:
		await _step(main)
		guard += 1
	# It holds still in its wind-up: where its head is now is where the
	# reel starts (measured flat: in its coil the head sits a little up).
	var h0 := b.head
	var last := h0
	var moved := 0.0
	t.swing()
	guard = 0
	while t._swing > Torch.SWING_TOP and guard < 30:
		await _step(main)
		moved += _flat_d(b.head, last)
		last = b.head
		guard += 1
	await _step(main)
	moved += _flat_d(b.head, last)
	last = b.head
	var share := b.strike.met_at_share
	ok(t.last_contact == "staggered" and b.strike.staggers == stag0 + 1 and b.strike.state == "reel",
		"%s: your lit swing at %.0f%% of its wind-up staggers it (%s, %s)" % [how, share * 100.0, t.last_contact, b.strike.state])
	guard = 0
	while b.strike.state == "reel" and guard < 120:
		await _step(main)
		moved += _flat_d(b.head, last)
		last = b.head
		guard += 1
	var d0 := _flat_d(h0, p.global_position)
	var d1 := _flat_d(b.head, p.global_position)
	# The whole reel_m, or straight back until the wall stops it, still on
	# its floor its girth off the stone (queue 57: Boss._on_floor; before
	# that it slipped into the wall).
	var pc: Dictionary = b.lay.pieces[int(b.ground.nodes[b.node].piece)]
	var aa := Delves.along_across(pc, Vector2(b.base.x, b.base.z))
	var edge := minf(minf(aa.x, float(pc.len) - aa.x), float(pc.half) - absf(aa.y))
	var margin := float(b.sub("body").get("girth_m", 0.38)) * 0.5 + 0.1
	var at_wall := not b._reel_back and moved > 0.5 and edge >= margin - 0.01 and edge <= margin + 0.08
	ok((absf(moved - b.strike.reel_m) < 0.1 or at_wall) and edge >= margin - 0.01 and d1 > d0 + 0.5,
		"%s: it reels %.2f m %s (reel_m %.2f)%s, %.2f -> %.2f m from you, %.2f m off the nearest wall" % [how, moved, "back along its body" if b._reel_back else "straight back, its body following", b.strike.reel_m, ", until the wall stops it" if at_wall else "", d0, d1, edge])
	ok(main.harm.landed == landed0, "%s: no hit counts from the broken strike (%d)" % [how, main.harm.landed - landed0])


func _near_unlit(b: Boss, q: Vector3, r: float) -> bool:
	for h in b.fires.holders:
		if not FireStore.is_lit(h) and (h as Node3D).global_position.distance_to(q) < r:
			return true
	return false


func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The snake laid in node `id` for a test (a harness's placing): coiled in a
## room; in a corridor's stretch, its head at the stretch's middle and its
## body straight back along the corridor, away from `away_from` (where you
## will be). Its chase called off, quiet.
func _lie_in(main: CrawlerMain, id: int, away_from: Vector3) -> void:
	var b := main.boss
	b._let_go("check")
	b._calm()
	var g := b.ground
	if str(g.nodes[id].kind) == "room":
		b._lie_coiled(id)
		b._pose()
		return
	var pc: Dictionary = main.lay.pieces[int(g.nodes[id].piece)]
	var axis := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y).normalized()
	var c: Vector3 = g.nodes[id].center
	var back := axis if _flat_d(c + axis, away_from) > _flat_d(c - axis, away_from) else -axis
	var poly: Array = []
	var length := float(b.sub("body").get("length_m", 9.0)) + 1.5
	var s := length
	while s > 0.0:
		var q := c + back * s
		q.y = b._floor_y(q)
		poly.append(q)
		s -= 0.5
	poly.append(c)
	b._trail_from(poly)
	b.base = c
	b.head = c
	b.dir = -back
	b.node = id
	b.target = id
	b.state = "coil"
	b.coiling = false
	b.coil_left = 999.0
	b._set_route(PackedVector3Array())
	b._pose()


## A spot in the snake's own dark `d` m in front of its head (Vector3.INF if
## none): in the node it lies in, on its floor; with `clear_m`, that far
## from any unlit holder (a swing there passes the flame to nothing).
func _beside(b: Boss, d: float, clear_m := 0.0) -> Vector3:
	for k in 16:
		var a := TAU * k / 16.0
		var q := b.head + Vector3(cos(a), 0.0, sin(a)) * d
		q.y = b._floor_y(q)
		if clear_m > 0.0 and _near_unlit(b, q, clear_m):
			continue
		# Clear of its hole: the hole's ring of collision stands as tall as
		# you (TombBuild._lair_hole) and would come between you and it, its
		# eye and your flame (on queue 46's layouts it can lie by the coil).
		var l: Dictionary = b.lay.get("lair", {})
		if not l.is_empty() and Vector2(q.x - (l.pos as Vector3).x, q.z - (l.pos as Vector3).z).length() < float(l.r) + 0.6:
			continue
		if b._blocked(b._eye(), q + Vector3(0, 1.3, 0), false):
			continue
		var id := b.ground.node_at(q)
		if id >= 0 and b.ground.is_ground(id) and (id == b.node or not b.ground.link(id, b.node).is_empty()) and not b._blocked(b.head + Vector3(0, 0.6, 0), q + Vector3(0, 0.6, 0), false):
			var pc: Dictionary = b.lay.pieces[int(b.ground.nodes[id].piece)]
			var aa := Delves.along_across(pc, Vector2(q.x, q.z))
			if aa.x > 0.4 and aa.x < float(pc.len) - 0.4 and absf(aa.y) < float(pc.half) - 0.45:
				return q
	return Vector3.INF


# --- 5. Its speed: walking it catches you, sprinting you get away ---------------------

## A long dark run along the floor: from the spine's first room on to the
## way out's landing (every holder cold), as TombNav walks it.
func _long_run(main: CrawlerMain) -> PackedVector3Array:
	var lay := main.lay
	var spine: Array = lay.get("spine", [])
	var first := -1
	for pid in spine:
		if str(lay.pieces[int(pid)].kind) == "room":
			first = int(pid)
			break
	if first < 0 or spine.is_empty():
		return PackedVector3Array()
	var a: Vector3 = main.boss.ground.nodes[(main.boss.ground.by_piece[first] as Array)[0]].center
	var last: Dictionary = lay.pieces[int(spine[-1])]
	var bb := BossGround.point(last, float(last.len) * 0.5, 0.0)
	return main.residents.nav.path(a, bb, true)


## The point `s` m along polyline `pts`, and the way it goes there.
func _along(pts: PackedVector3Array, s: float) -> Array:
	var left := s
	for k in range(1, pts.size()):
		var l := pts[k - 1].distance_to(pts[k])
		if l >= left:
			return [pts[k - 1].lerp(pts[k], left / maxf(l, 1e-4)), (pts[k] - pts[k - 1]).normalized()]
		left -= l
	return [pts[pts.size() - 1], (pts[pts.size() - 1] - pts[maxi(pts.size() - 2, 0)]).normalized()]


func _speed(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var hunt := b.num("hunt_mps", 0.0)
	var walk := CrawlerPlayer.WALK_SPEED
	var sprint := CrawlerPlayer.SPRINT_SPEED
	ok(absf(hunt - 4.6) < 1e-4 and hunt >= walk and hunt < sprint, "it hunts at %.1f m/s (Mike's note of 7 Oct: as fast as your walk, %.1f, or faster; your sprint, %.1f, outruns it)" % [hunt, walk, sprint])
	var run := _long_run(main)
	var length := TombNav.length_of(run)
	if length < 50.0:
		ok(false, "a long dark run to be chased along (%.0f m)" % length)
		return
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	p.torch.light()
	var reach := b.strike.reach_m
	for mode in ["walk", "sprint"]:
		main.harm.reset()
		p._invulnerable = 0.0
		var v := walk if mode == "walk" else sprint
		# It 5 m behind you on the run, its body along the run behind it,
		# after you, its torch's delay spent (its hold at the edge of your
		# torchlight is tested above).
		var s0 := float(b.sub("body").get("length_m", 9.0)) + 2.0
		var at: Array = _along(run, s0)
		b._calm()
		var poly: Array = []
		var q := 0.0
		while q < s0:
			poly.append(_along(run, q)[0])
			q += 0.25
		poly.append(at[0])
		b._trail_from(poly)
		b.base = at[0]
		b.head = b.base
		b.dir = at[1]
		b._set_route(PackedVector3Array())
		b.node = b.ground.node_at(b.base)
		b.noticed = true
		b.pursuit.notice(true)
		b.hang_t = 99.0
		b.struck = false
		b.state = "hunt"
		b._replan_t = 0.0
		b._hunt_to = Vector3.INF
		var gap0 := 5.0
		var s := s0 + gap0
		var landed0 := main.harm.landed
		var closest := INF
		var wound := false
		var hit_at := -1.0
		var last_gap := 0.0
		var t := 0.0
		var parts: Array = []
		var was_part := ""
		_mo_reset(b)
		while t < 20.0 and s < length - 1.0:
			s += v / 60.0
			var me: Array = _along(run, s)
			var fl: Vector3 = me[1]
			p.global_position = me[0]
			p.velocity = Vector3.ZERO
			p.set_view(0.0, atan2(-fl.x, -fl.z))
			await physics_frame
			t += 1.0 / 60.0
			main.boss.tick(1.0 / 60.0)
			_last_max = b.max_mps()
			_mo_step(b, 1.0 / 60.0)
			last_gap = _flat_d(b.base, p.global_position)
			var part := "%s/%s" % [b.state, b.strike.state]
			if part != was_part:
				was_part = part
				if parts.size() < 24:
					parts.append("%s %.2fs %.2fm" % [part, t, last_gap])
			if t > 0.5:
				closest = minf(closest, last_gap)
			if b.strike.winding_up() and last_gap <= reach:
				wound = true
			if main.harm.landed > landed0 and hit_at < 0.0:
				hit_at = t
				break
		if mode == "walk":
			ok(closest <= reach and wound and hit_at > 0.0, "walking away along the run (%.1f m/s): it catches you, closing from %.0f m to %.2f m (its reach %.1f), rearing as it comes, and its strike lands %.1f s on" % [v, gap0, closest, reach, hit_at])
			if hit_at < 0.0:
				print("  its parts: %s" % ", ".join(parts))
		else:
			ok(hit_at < 0.0 and closest > reach and last_gap > gap0 + 2.0, "sprinting away along the run (%.1f m/s): the gap only grows, %.0f m to %.1f m over %.1f s (%.0f m), never within its reach (closest %.2f m), and no strike lands" % [v, gap0, last_gap, t, s, closest])
		_mo_ok("chased along the run (%s)" % mode)
	p.torch.put_out("check")
	main.harm.reset()


# --- 6. The light's edge (Mike's note of 7 Oct) --------------------------------------

## A room with torches of its own (not the hearth room) beside a stretch
## or room of the dark once they are relit: {"room", "dark", "via"}, its
## torches lit; {} if none.
func _room_by_dark(main: CrawlerMain) -> Dictionary:
	var g := main.boss.ground
	for n in g.nodes:
		if str(n.kind) != "room" or bool(n.hearth) or (n.holders as Array).is_empty():
			continue
		for l in n.links:
			var other: Dictionary = g.nodes[int(l.to)]
			if bool(other.hearth) or l.has("tunnel"):
				continue
			for i in n.holders:
				_light_holder(main, main.fires.holders[int(i)])
			main.boss._refresh(false)
			main.residents.light.refresh()
			if not g.is_ground(int(n.id)) and g.is_ground(int(l.to)):
				return {"room": int(n.id), "dark": int(l.to), "via": l.via}
	return {}


## The open floor in node `id` furthest (by the light) from anywhere a
## chase may stand: where the light is brightest and no floor under the
## cap is within `reach`; Vector3.INF if none.
func _by_the_fire(main: CrawlerMain, id: int, reach: float) -> Vector3:
	var g := main.boss.ground
	var nav := main.residents.nav
	var lf := main.residents.light
	var pc: Dictionary = main.lay.pieces[int(g.nodes[id].piece)]
	var best := Vector3.INF
	var best_l := -INF
	var al := 0.5
	while al < float(pc.len) - 0.5:
		var ac := -float(pc.half) + 0.5
		while ac < float(pc.half) - 0.5:
			var q := BossGround.point(pc, al, ac)
			if nav.is_open(nav.cell_of(q)) and g.node_at(q) == id and not lf.edge_within(q, reach + 0.5):
				var lv := lf.at(q)
				if lv > best_l:
					best_l = lv
					best = q
			ac += 0.25
		al += 0.25
	return best


## Open floor in a lit node past the light's cap where the chase's own way
## (TombNav, CAP) from a stretch or room of the dark next to it ends within
## 0.8 of `reach` of it, nothing of the stone between: the light's dim
## edge, where its strike can find you. {"at", "dark"}, or {} if none.
## `only`: that lit node only, else any lit node beside the dark.
func _dim_edge(main: CrawlerMain, reach: float, only := -1) -> Dictionary:
	var b := main.boss
	var g := b.ground
	var nav := main.residents.nav
	var lf := main.residents.light
	for n in g.nodes:
		var id := int(n.id)
		if (only >= 0 and id != only) or g.is_ground(id) or bool(n.hearth):
			continue
		var darks: Array = []
		for l in n.links:
			if g.is_ground(int(l.to)) and not l.has("tunnel"):
				darks.append(int(l.to))
		if darks.is_empty():
			continue
		var pc: Dictionary = main.lay.pieces[int(n.piece)]
		var al := 0.5
		while al < float(pc.len) - 0.5:
			var ac := -float(pc.half) + 0.5
			while ac < float(pc.half) - 0.5:
				var q := BossGround.point(pc, al, ac)
				if nav.is_open(nav.cell_of(q)) and g.node_at(q) == id and lf.at(q) > lf.cap * 1.3 and lf.edge_within(q, reach * 0.6) and not lf.edge_within(q, 0.5):
					for dk in darks:
						var pts := nav.path(g.nodes[dk].center, q, true, TombNav.CAP)
						if pts.is_empty():
							continue
						var e := pts[pts.size() - 1]
						if _flat_d(e, q) <= reach * 0.8 and not b._blocked(e + Vector3(0, 0.6, 0), q + Vector3(0, 0.6, 0), false):
							return {"at": q, "dark": dk}
				ac += 0.25
			al += 0.25
	return {}


## It hunting you, its delay spent, you standing at `you` (your torch lit)
## for `secs`: what it did. {"peak" (the brightest light at its feet),
## "edge" (the light at its feet where it stood nearest you), "closest",
## "peek" (its head furthest forward into the glow), "glow" (the light at
## its drawn head then, against its feet's), "hits", "gave" (s, or -1),
## "healed" (a hit healed while it watched), "watch" (s watching)}.
func _hunt_you(main: CrawlerMain, you: Vector3, secs: float) -> Dictionary:
	var b := main.boss
	var p := main.player
	var lf := main.residents.light
	_place(p, you, b.head)
	await physics_frame
	b.noticed = true
	b.pursuit.notice(true)
	b.hang_t = 99.0
	b.struck = false
	b.state = "hunt"
	b._replan_t = 0.0
	b._hunt_to = Vector3.INF
	var out := {"peak": 0.0, "edge": 0.0, "closest": INF, "peek": 0.0, "glow": 0.0, "feet": 0.0, "hits": 0, "gave": -1.0, "watch": 0.0, "went": []}
	var landed0 := main.harm.landed
	var t := 0.0
	var was := ""
	_mo_reset(b)
	while t < secs:
		_tick(main, DT)
		t += DT
		var part := "%s/%s" % [b.state, b.strike.state]
		if part != was and (out.went as Array).size() < 16:
			was = part
			(out.went as Array).append("%s %.1fs %.1fm" % [part, t, _flat_d(b.base, you)])
		if not b.noticed and float(out.gave) < 0.0:
			out.gave = t
			break
		var lv := lf.at(b.base)
		out.peak = maxf(float(out.peak), lv)
		var d := _flat_d(b.base, you)
		if d < float(out.closest):
			out.closest = d
			out.edge = lv
		if b.state == "watch":
			out.watch = float(out.watch) + DT
			if b.lunge > float(out.peek):
				out.peek = b.lunge
				var hp := b.head + b.dir * b.lunge
				out.glow = lf.at(hp)
				out.feet = lv
	out.hits = main.harm.landed - landed0
	return out


func _edge(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var g := b.ground
	var lf := main.residents.light
	var cap := lf.cap
	var reach := b.strike.reach_m
	var watch_s := b.num("watch_s", 10.0)
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	p.torch.light()
	# By the hearth: it in the dark outside one of the hearth room's doors.
	var hearth := g.node_at(main.lay.wake[0])
	var outside := -1
	for l in g.nodes[hearth].links:
		if g.is_ground(int(l.to)) and not l.has("tunnel"):
			outside = int(l.to)
			break
	if outside >= 0:
		main.harm.reset()
		var by_fire := _by_the_fire(main, hearth, reach)
		_lie_in(main, outside, by_fire)
		var r: Dictionary = await _hunt_you(main, by_fire, watch_s + 8.0)
		ok(float(r.peak) <= cap + 1e-4 and float(r.edge) >= cap * 0.25 and int(r.hits) == 0, "you by the hearth (the light %.2f where you stand): it comes to the edge of the light and no further, the light at its feet at most %.3f (the cap %.3f; %.3f where it stood nearest you, %.1f m off), and no strike reaches you" % [lf.at(by_fire), float(r.peak), cap, float(r.edge), float(r.closest)])
		ok(float(r.peek) >= b.num("peek_m", 0.7) - 0.05 and float(r.glow) > float(r.feet), "there it rears its head forward into the glow (%.2f m; the light %.3f at its head, %.3f at its feet)" % [float(r.peek), float(r.glow), float(r.feet)])
		ok(float(r.gave) > 0.0 and absf(float(r.watch) - watch_s) < 1.0, "it watches you from there %.1f s, then gives you up (watch_s %.0f; gave up at %.1f s)" % [float(r.watch), watch_s, float(r.gave)])
		_mo_ok("the chase to the hearth's light")
	else:
		ok(false, "a stretch of its dark at the hearth room's door")
	# A relit room: it beside the room in its dark, you deep in the light,
	# then at its dim edge.
	var pair := _room_by_dark(main)
	if pair.is_empty():
		ok(false, "a room to relight beside a stretch of its dark")
		return
	var room := int(pair.room)
	var dark := int(pair.dark)
	main.harm.reset()
	p._invulnerable = 0.0
	var deep := _by_the_fire(main, room, reach)
	if deep == Vector3.INF:
		ok(false, "a spot in the relit room out of reach of its dark edge")
	else:
		_lie_in(main, dark, deep)
		var r2: Dictionary = await _hunt_you(main, deep, watch_s + 8.0)
		ok(float(r2.peak) <= cap + 1e-4 and int(r2.hits) == 0 and float(r2.closest) > reach, "you deep in a relit %s (the light %.2f where you stand): it never stands where the light passes the cap (%.3f at most), comes to %.1f m and no strike reaches you" % [main.lay.pieces[int(g.nodes[room].piece)].get("room_kind", "room"), lf.at(deep), float(r2.peak), float(r2.closest)])
		ok(float(r2.gave) > 0.0, "it watches from the light's edge (%.1f s), then gives you up" % float(r2.watch))
		_mo_ok("the chase to a relit room")
	# At the light's dim edge: within its reach of where it may stand.
	var de := _dim_edge(main, reach, room)
	if de.is_empty():
		print("  (no floor in that room past the cap within its reach of the edge: the dim-edge strike is tried by another lit room)")
		de = _dim_edge(main, reach)
	if de.is_empty():
		ok(false, "floor at the light's dim edge to stand on")
		return
	main.harm.reset()
	p._invulnerable = 0.0
	var dim: Vector3 = de.at
	_lie_in(main, int(de.dark), dim)
	var r3: Dictionary = await _hunt_you(main, dim, 15.0)
	ok(int(r3.hits) >= 1 and float(r3.peak) <= cap + 1e-4, "you at the light's dim edge (the light %.3f where you stand, past the cap): it strikes you from where it may stand (%d hit, the light at its feet %.3f at most)" % [lf.at(dim), int(r3.hits), float(r3.peak)])
	if int(r3.hits) < 1:
		print("  it went: %s" % ", ".join(r3.went))
	_mo_ok("the chase to the light's dim edge")
	p.torch.put_out("check")
	main.harm.reset()


# --- 7. Its tunnels in use ------------------------------------------------------------

## Sent through tunnel 0 (from its hole a to its hole b): in, hidden at its
## speed, out.
func _tunnel_run(main: CrawlerMain) -> void:
	var b := main.boss
	var t: Dictionary = main.lay.get("tunnels", {})
	var links: Array = t.get("links", [])
	if links.is_empty():
		ok(false, "a tunnel to send it through")
		return
	var l0: Dictionary = links[0]
	var ha: Dictionary = t.holes[int(l0.a)]
	var hb: Dictionary = t.holes[int(l0.b)]
	var na := b.ground.node_at(ha.out)
	var nb := b.ground.node_at(hb.out)
	# It on the floor before hole a, heading in, its body behind it.
	b._calm()
	b._let_go("check")
	var n: Vector3 = ha.n
	var start: Vector3 = (ha.out as Vector3) + n * 0.6
	start.y = b._floor_y(start)
	b._trail_from([start + n * 4.0, start])
	b.base = start
	b.head = start
	b.dir = -n
	b.node = na
	b.target = nb
	var tl: Dictionary = {}
	for l in b.ground.nodes[na].links:
		if l.has("tunnel") and int(l.tunnel) == 0:
			tl = l
	if tl.is_empty():
		ok(false, "tunnel 0 is a way in its ground (BossGround)")
		return
	b._set_planned({"pos": b.base, "node": na, "pts": PackedVector3Array(), "hidden": PackedByteArray()}, [na, nb], hb.out)
	b.state = "prowl"
	var tun := b.sub("tunnels")
	var muffled := true
	var quieter := true
	var inside_frames := 0
	var transits0 := b.transits
	var speed := b.num("speed_mps", 2.0)
	var sec := 0.0
	_mo_reset(b)
	while sec < 90.0 and b.transits == transits0:
		_tick(main, DT)
		sec += DT
		if b._in_tunnel_run():
			inside_frames += 1
			if not is_equal_approx(b._tell.attenuation_filter_cutoff_hz, float(tun.get("muffle_hz", 700.0))):
				muffled = false
			if inside_frames > 30 and b._tell.volume_db > float(tun.get("muffle_db", -14.0)) + 1.0:
				quieter = false
	var lt := b.last_transit
	var out_d := _flat_d(b.base, hb.pos)
	ok(b.transits == transits0 + 1 and float(lt.get("s", 0.0)) >= float(lt.get("m", 0.0)) / speed - 0.05 and float(lt.get("m", 0.0)) >= float(lt.get("straight", 0.0)) - 0.01 and out_d < 2.5, "sent through its tunnel from the %s to the %s: in at one hole, hidden %.1f s for %.1f m inside (at its %.1f m/s at least %.1f s; %.1f m between where it went in and came out), and out of the other (%.1f m from it)" % [main.lay.pieces[int(ha.piece)].get("room_kind", "corridor"), main.lay.pieces[int(hb.piece)].get("room_kind", "corridor"), float(lt.get("s", 0.0)), float(lt.get("m", 0.0)), speed, float(lt.get("m", 0.0)) / speed, float(lt.get("straight", 0.0)), out_d])
	ok(inside_frames > 0 and muffled and quieter, "inside, its tell is muffled: nothing over %.0f Hz and %.0f dB quieter (%d frames)" % [float(tun.get("muffle_hz", 700.0)), -float(tun.get("muffle_db", -14.0)), inside_frames])
	_mo_ok("through its tunnel")


## Its whole side way relit round it: it leaves under the light by a
## tunnel, never through the hearth room.
func _bypass(main: CrawlerMain) -> void:
	var b := main.boss
	var g := b.ground
	var lay := main.lay
	var holes: Array = (lay.get("tunnels", {}) as Dictionary).get("holes", [])
	# A side way with one of its holes and dark left elsewhere.
	var pick := -1
	var branch: Array = []
	for bi in range(1, (lay.branches as Array).size()):
		for h in holes:
			if int(h.piece) in lay.branches[bi]:
				pick = int(h.piece)
				branch = lay.branches[bi]
				break
		if pick >= 0:
			break
	if pick < 0:
		ok(false, "a side way with one of its holes")
		return
	# It coiled in the room of that way furthest from the hearth room.
	var far := -1
	for pid in branch:
		if str(lay.pieces[int(pid)].kind) == "room":
			far = int(pid)
	var nid := int((g.by_piece[far] as Array)[0])
	b._let_go("check")
	b._lie_coiled(nid)
	b._pose()
	# Every holder of that way relit.
	for h in main.fires.holders:
		if int(h.get_meta("piece")) in branch:
			_light_holder(main, h)
	var transits0 := b.transits
	var hearth0 := b.hearth_steps
	var sec := 0.0
	_mo_reset(b)
	var left := false
	while sec < 120.0:
		_tick(main, DT)
		sec += DT
		if b.state in ["prowl", "coil"] and b.node >= 0 and g.is_ground(b.node) and not b._in_tunnel():
			left = true
			break
	var in_way := b.node >= 0 and int(g.nodes[b.node].piece) in branch
	ok(left and b.transits > transits0 and b.hearth_steps == hearth0 and not in_way, "its whole side way relit round it, it leaves under the light by its tunnel (%d through) and is back in its dark elsewhere %.1f s later, never through the hearth room (%d steps there)" % [b.transits - transits0, sec, b.hearth_steps - hearth0])
	_mo_ok("out under the light")


# --- 8. The dimmest way ---------------------------------------------------------------

## Its room and the corridor out of it relit: it crosses the light to the
## dark by a way dimmer than the shortest.
func _dimmest(main: CrawlerMain) -> void:
	var b := main.boss
	var g := b.ground
	var lf := main.residents.light
	var nav := main.residents.nav
	# A plain grid (no light on it: every square alike) for the shortest way.
	var plain := TombNav.build(main.lay, main.get_viewport().world_3d.direct_space_state, Residents.NAV_RADIUS, [main.player.get_rid()])
	var tried := 0
	for n in g.nodes:
		if str(n.kind) != "room" or bool(n.hearth) or (n.holders as Array).is_empty() or not g.is_ground(int(n.id)):
			continue
		if int(n.id) == b.lair_node:
			continue
		tried += 1
		if tried > 6:
			break
		# It coiled there; its torches relit round it.
		b._let_go("check")
		b._lie_coiled(int(n.id))
		b._pose()
		for i in n.holders:
			_light_holder(main, main.fires.holders[int(i)])
		lf.refresh()
		b._refresh(false)
		if b.state != "leave":
			continue
		var start := b.base
		var walked := PackedVector3Array([start])
		var sec := 0.0
		_mo_reset(b)
		while sec < 60.0 and b.state == "leave":
			_tick(main, DT)
			sec += DT
			if walked[walked.size() - 1].distance_to(b.base) > 0.1:
				walked.append(b.base)
		var end := b.base
		var mine := lf.along(walked)
		var short := plain.path(start, end, true)
		var theirs := lf.along(short)
		if float(theirs.max) <= lf.cap:
			# The shortest way never met the light: nothing to keep off. Another room.
			continue
		ok(float(mine.mean) < float(theirs.mean) and b.node >= 0 and g.is_ground(b.node), "its room relit round it (a %s), it crosses the light to the dark by the dimmest way: the light along its way %.3f a metre on average (at most %.2f, %.1f m), against %.3f (at most %.2f, %.1f m) along the shortest" % [main.lay.pieces[int(n.piece)].get("room_kind", "room"), float(mine.mean), float(mine.max), float(mine.m), float(theirs.mean), float(theirs.max), float(theirs.m)])
		_mo_ok("across the light")
		return
	ok(false, "a room to relight round it where the shortest way out meets the light (%d tried)" % tried)


# --- 9. A fire pot (§FA.4, Mike's note of 7 Oct) -----------------------------------

func _pot(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var fp := main.fire_pots
	# You away, off the tomb (nothing to notice).
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await physics_frame
	var s := float((FirePots.D.get("vs_boss", {}) as Dictionary).get("drives_off_s", 30.0))
	var stun_s := b.num("stun_s", 1.5)
	b._hears_burst()
	b.pursuit.notice(false)
	b.noticed = true
	fp.burst(b.fire_center(), "tar", b, Vector3.UP)
	ok(b.state == "stunned" and not b.pursuit.on and b.driven == 1, "a fire pot's burst at its head stuns it (%s), the chase off, never burnt (fire_pots.json vs_boss: driven off)" % b.state)
	var sec := 0.0
	var stunned := 0.0
	var wind := b.strike.wind_ups
	var moved := 0.0
	var at := b.base
	_mo_reset(b)
	while sec < 10.0 and b.state == "stunned":
		_tick(main, DT)
		sec += DT
		stunned += DT
		moved = maxf(moved, _flat_d(b.base, at))
	ok(absf(stunned - stun_s) < 0.1 and b.strike.wind_ups == wind and moved < 0.05, "it lies dazed %.2f s (stun_s %.1f): no strike, no chase, not a step" % [stunned, stun_s])
	# To its hole, physically, and down it.
	var fled := 0.0
	while sec < 200.0 and b.state == "flee":
		_tick(main, DT)
		sec += DT
		fled += DT
	var l: Dictionary = main.lay.lair
	var under := _flat_d(b.base, l.pos) <= Boss.DEN_R_M + 0.1 and b.base.y < float((l.pos as Vector3).y) - 1.0
	ok(b.state == "den" and b._all_below() and under, "then it goes to its lair's hole, %.1f s through the tomb at flee_mps %.1f, and down it: all of it under the floor (its head %.1f m down under the hole's mouth)" % [fled, b.num("flee_mps", 5.0), float((l.pos as Vector3).y) - b.base.y])
	_mo_ok("fled to its hole")
	# Down there: out of reach, breathing, drives_off_s.
	var down := 0.0
	var reachable := false
	while sec < 300.0 and b.state == "den":
		b.tick(DT)
		main.harm.tick(DT)
		sec += DT
		down += DT
		if b.state == "den" and FirePots.distance_to(b, b.fire_center()) < INF:
			reachable = true
	ok(absf(down - s) <= DT * 2.0 and not reachable, "down its hole it stays %.1f s (vs_boss.drives_off_s %.0f), out of every pot's reach" % [down, s])
	# Up out of the hole, and on.
	var up_s := 0.0
	var through := false
	_mo_reset(b)
	while sec < 400.0 and b.state == "rise":
		_tick(main, DT)
		sec += DT
		up_s += DT
		if _flat_d(b.base, l.pos) < 0.3 and absf(b.base.y - float((l.pos as Vector3).y)) < 0.1:
			through = true
	ok(through and b.state in ["prowl", "coil", "leave"] and is_instance_valid(b) and not b.state in ["lair", "gone"], "then it comes up out of the hole (%.1f s) onto its rounds (%s), never dead" % [up_s, b.state])
	_mo_ok("up out of its hole")


# --- 10. The relight run ------------------------------------------------------

func _relight_run(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var fires := main.fires
	# You in the hearth room, out of its way.
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), 0.0)
	await physics_frame
	# Its tell while it goes its rounds, and coiled.
	var db_move := -INF
	var db_coil := INF
	var played := false
	var seen_states := {}
	_mo_reset(b)
	for i in int(60.0 / DT):
		_tick(main, DT)
		seen_states[b.state] = true
		if b._tell.playing:
			played = true
		if b.state in ["prowl"] and b.speed > 0.5 and not b._in_tunnel():
			db_move = maxf(db_move, b._tell.volume_db)
		if b.state == "coil" and not b.coiling and b.coil_left > 0.0:
			db_coil = minf(db_coil, b._tell.volume_db)
	ok(played and db_move > db_coil + 8.0, "its tell, scales on stone: %.0f dB on the move, %.0f dB coiled (states %s)" % [db_move, db_coil, str(seen_states.keys())])
	var hush_db := float(Boss.RELEASE.get("bed_hush_db", -18.0))
	ok(main.drips != null and absf(main.drips.volume_db - (b.bed_db + hush_db)) < 0.5, "the tomb's small sounds hushed while it prowls (drips %.0f dB, their own %.0f)" % [main.drips.volume_db if main.drips else 0.0, b.bed_db])
	# Every holder in the layout's order, a while of the snake between.
	var n := fires.holders.size()
	var counts: Array = [b.ground.ground_count()]
	var in_light := 0.0
	var worst_leave := 0.0
	var lit_entries0 := b.lit_entries
	var leaves := 0
	var stuck := 0
	var hearth_prowl := 0
	var hearth_cross := 0
	var transits0 := b.transits
	for k in n:
		_light_holder(main, fires.holders[k])
		var left := -1.0
		var steps := int((14.0 if k < n - 1 else 1.0) / DT)
		for i in steps:
			_tick(main, DT)
			if b.state in ["lair", "gone", "release"]:
				break
			if b.node >= 0 and bool(b.ground.nodes[b.node].hearth) and not b._in_tunnel():
				if b.state in ["leave", "flee", "release", "rise"]:
					hearth_cross += 1
				else:
					hearth_prowl += 1
			if b._in_tunnel():
				continue
			var dark := b.node >= 0 and b.ground.is_ground(b.node)
			if not dark:
				if b.state == "leave":
					if left < 0.0:
						left = 0.0
						leaves += 1
					left += DT
				elif not b.state in ["hunt", "hang", "strike", "watch", "stunned", "flee", "rise", "held"]:
					in_light += DT
			elif left >= 0.0:
				worst_leave = maxf(worst_leave, left)
				left = -1.0
		if left >= 0.0 and b.state == "leave":
			stuck += 1
		counts.append(b.ground.ground_count())
	print("  dark nodes as each holder caught: %s" % _short(counts))
	ok(b.lit_entries == lit_entries0 and in_light < 0.05, "over the whole run it never went into the light of its own accord (%d entries, %.2f s in light outside leaving it)" % [b.lit_entries - lit_entries0, in_light])
	ok(leaves > 0 and stuck == 0, "lit round it, it left for the dark every time (%d times, the longest %.1f s through the light), under it through its tunnels %d times; it never went into the stone (there is no such thing now)" % [leaves, worst_leave, b.transits - transits0])
	ok(hearth_prowl == 0, "it never set foot in the hearth room of its own accord (prowling or chasing: %d steps); crossing it with no other way to the dark, %d steps" % [hearth_prowl, hearth_cross])
	_mo_ok("the relight run")
	# The release: home physically.
	var rel_state := b.state
	var line := str(Boss.RELEASE.get("log_line", "")).format({"boss": b.name_text})
	var logged := false
	for e in GameLog.entries:
		if str(e.text).begins_with(line):
			logged = true
	var sec := 0.0
	var seen_down := false
	_mo_reset(b)
	while sec < 180.0 and b.state == "release":
		_tick(main, DT)
		sec += DT
		if b._in_tunnel() and b.base.y < float((main.lay.lair.pos as Vector3).y) - 0.5 and _flat_d(b.base, main.lay.lair.pos) < 1.0:
			seen_down = true
	ok(rel_state in ["release", "lair"] and b.released, "the last light: it goes home (%s)" % rel_state)
	ok(b.state == "lair" and seen_down and b._all_below() and not b.body.visible, "it travelled to its lair (%.1f s) and went down the hole for good: all of it under the floor, drawn no more" % sec)
	_mo_ok("the release")
	ok(logged, "the log: \"%s.\"" % line)
	var heard := float(Boss.LAIR.get("breathing_heard_m", 12.0))
	ok(b._breath.playing and is_equal_approx(b._breath.max_distance, heard) and b._breath.global_position.y < float(main.lay.lair.pos.y) - 0.5, "its breathing from below the hole, heard within %.0f m" % heard)
	_sim_boss(b, float(Boss.RELEASE.get("bed_return_s", 4.0)) + 0.5)
	ok(absf(main.drips.volume_db - b.bed_db) < 0.5 and not b._tell.playing, "the tomb's small sounds come back (drips %.0f dB), and the scales are gone" % main.drips.volume_db)


func _sim_boss(b: Boss, secs: float) -> void:
	var t := 0.0
	while t < secs:
		b.tick(DT)
		t += DT


# --- 11. The way out with it loose (queue 46) -------------------------------------

## The walk to the way out (design §EX.5; queue 46's check walks your body
## there in 203 tombs, the hole's ring of collision and all) with the snake
## loose: its body has no collision and its hole is off the spine, so it
## can never stand in your way. This walks you there, your torch lit, from
## the wake spot through the middle of each of the spine's doors (round
## the heart's dead) and into the opening, set down frame by frame, the
## snake and Harm on their own clocks; at a walk (WALK_SPEED) until the
## snake is after you, then at a sprint (SPRINT_SPEED: Mike's note of 7
## Oct, the sprint outruns it), and reports what it does. `in_heart`: the
## snake lies coiled in the heart first, across your way.
func _walk_out_run(main: CrawlerMain, in_heart := false) -> void:
	var b := main.boss
	var p := main.player
	var lay := main.lay
	var how := "from where it starts"
	if in_heart:
		var hc: Vector3 = BossGround.point(lay.pieces[int(lay.heart)], float(lay.pieces[int(lay.heart)].len) * 0.5, 0.0)
		b._lie_coiled(b.ground.node_at(hc))
		b._pose()
		how = "lying coiled in the heart, across your way"
	if (lay.get("exits", []) as Array).is_empty() or (lay.get("spine", []) as Array).is_empty():
		ok(false, "the walk out with it loose: no spine or way out to walk")
		return
	var ex: Dictionary = lay.exits[0]
	var chain: Array = (lay.spine as Array).duplicate()
	if int(chain[0]) != 0:
		chain.push_front(0)
	var pts: Array = [(lay.wake[0] as Vector3)]
	for k in range(chain.size() - 1):
		var pa := int(chain[k])
		var pb := int(chain[k + 1])
		if pa == int(lay.get("heart", -1)):
			# Round the heart's dead (TombKit.heart_box), on the roomier side.
			var pc: Dictionary = lay.pieces[pa]
			var hb := TombKit.heart_box(pc)
			var aa := Delves.along_across(pc, Vector2((hb.pos as Vector3).x, (hb.pos as Vector3).z))
			var side := 1.8 if aa.y <= 0.0 else -1.8
			pts.append(BossGround.point(pc, aa.x - 1.6, side))
			pts.append(BossGround.point(pc, aa.x + 1.6, side))
		for d in lay.doors:
			if (int(d.a) == pa and int(d.b) == pb) or (int(d.a) == pb and int(d.b) == pa):
				pts.append(Vector3((d.p as Vector2).x, float(d.y), (d.p as Vector2).y))
				break
	var op: Vector3 = ex.p
	pts.append(op + (ex.n as Vector3) * 0.4)
	var t := p.torch
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	t.light()
	var landed0 := main.harm.landed
	var noticed_at := -1.0
	var taken := false
	var clock := 0.0
	var walked := 0.0
	var at: Vector3 = pts[0]
	var i := 1
	var sprinted := 0.0
	_mo_reset(b)
	while i < pts.size() and clock < 120.0 and main.walked_out == 0:
		var to: Vector3 = pts[i]
		var v := CrawlerPlayer.SPRINT_SPEED if b.noticed else CrawlerPlayer.WALK_SPEED
		var left := v / 60.0
		while left > 0.0 and i < pts.size():
			to = pts[i]
			var dd := at.distance_to(to)
			if dd <= left:
				at = to
				left -= dd
				walked += dd
				i += 1
			else:
				at += (to - at) / dd * left
				walked += left
				left = 0.0
		var fl := Vector3(to.x - at.x, 0.0, to.z - at.z)
		if fl.length() > 0.01:
			p.set_view(0.0, atan2(-fl.x, -fl.z))
		p.global_position = at
		p.velocity = Vector3.ZERO
		await physics_frame
		clock += 1.0 / 60.0
		if b.noticed:
			sprinted += 1.0 / 60.0
		b.tick(1.0 / 60.0)
		_last_max = b.max_mps()
		_mo_step(b, 1.0 / 60.0)
		if b.noticed and noticed_at < 0.0:
			noticed_at = clock
		if main.harm.taking:
			taken = true
			break
	# Held in the opening until CrawlerMain walks you out, then its next
	# tomb's build.
	var guard := 0
	while not taken and main.walked_out == 0 and not main.leaving and guard < 120:
		p.global_position = at
		p.velocity = Vector3.ZERO
		await physics_frame
		guard += 1
	guard = 0
	while main.leaving and guard < 1200:
		await physics_frame
		guard += 1
	var hits := main.harm.landed - landed0
	var seen := "it never noticed you" if noticed_at < 0.0 else "it noticed you at %.1f s and you sprinted %.1f s" % [noticed_at, sprinted]
	ok(not taken and main.walked_out == 1, "the walk out with it loose (%s): your torch lit, from the wake spot along the spine (%.0f m, %.1f s), walking until it is after you, then sprinting: you get out (%s, %d hit%s landed)" % [how, walked, clock, seen, hits, "" if hits == 1 else "s"])
	main.harm.reset()
	for k in 4:
		await process_frame
