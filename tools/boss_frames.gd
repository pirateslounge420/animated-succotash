extends SceneTree
## The boss's visual check (design 6 Oct §EY; queue 49): renders the snake
## once, at the end of the pass (no screenshots between steps):
##   SEED=7 xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/boss_frames.gd
## Frames go to OUT (default user://boss_frames/<seed>/): its three baked
## sheets (head shut, head open, a length of body); the snake come out of
## its dead end to the edge of your torch's light in a corridor, reared and
## hissing (the torch's delay); the same frame with it hidden, to count its
## pixels; mid-strike, jaws open; lying coiled in its room, seen from the
## door; the lair from its room's door and from its edge, looking down,
## once it has gone down its hole for good; and (Mike's note of 7 Oct) the
## snake at the edge of the hearth's light, its head forward into the glow,
## seen from by the fire through the hearth room's door, with it hidden to
## count it; one of its tunnels' holes by torchlight. ONLY=freeze renders
## the freeze alone (design 9 Oct §FM.2, queue 66; _freeze_frame): the
## snake frozen about 20 m off in a corridor lit by one of its sconces, its
## camouflage on (17), with it hidden (17b) and with its camouflage off, as
## painted (17c), counting how much of it shows in each.
## Checks: every cell of every sheet holds the body; the snake shows at
## the torch's edge (pixels that change when it is hidden, warm-lit); the
## hole's mouth is the darkest thing round it; the snake shows at the edge
## of the hearth's light, never past the chase's cap, and its whole body
## behind it in the dark, along the floor it came by; through its tunnel's
## hole every sight in to its back is the black, against the torchlit
## stone beside it.

var fails := 0
var out_dir := ""


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("  frame %s" % name)
	return img


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Where scene point `p` falls in image `img` (pixels), or (-1, -1) behind
## the camera.
func _px(img: Image, p: Vector3) -> Vector2:
	var cam := get_root().get_camera_3d()
	if cam.is_position_behind(p):
		return Vector2(-1, -1)
	var v := cam.unproject_position(p)
	var vs := get_root().get_visible_rect().size
	return Vector2(v.x / vs.x * img.get_width(), v.y / vs.y * img.get_height())


func _luma(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


## The mean colour of a box `r` pixels round `at`.
func _around(img: Image, at: Vector2, r: int) -> Color:
	var sum := Color(0, 0, 0)
	var n := 0
	for y in range(int(at.y) - r, int(at.y) + r + 1):
		for x in range(int(at.x) - r, int(at.x) + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				sum += img.get_pixel(x, y)
				n += 1
	return sum / float(maxi(n, 1))


func _run() -> void:
	WorldSave.read_only = true
	# The snake on its built rounds (queue 49's behaviour, its pool's
	# 'rounds'), as these checks test it: its pool's own states (design
	# §FM.2, queue 66) are tools/boss_snake_check.gd's.
	Boss.pool_off = true
	# The tomb's skeletons sleep through this check (design §FE; queue 58).
	Residents.stay_asleep = true
	# Pictures, not a burn test: the torch never burns out mid-run (§FJ.4).
	Torch.burn_down = false
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	out_dir = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "user://boss_frames/%d" % seed_v
	out_dir = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked or not main.boss.started:
		await process_frame
	await _frames(120)
	var b := main.boss
	b.auto = false
	var p := main.player
	p.set_physics_process(false)
	main.world.days = 13.0
	# Nothing in these frames may take you.
	p._invulnerable = 1.0e6
	if OS.get_environment("ONLY").split(",", false).has("freeze"):
		# Only the freeze (design §FM.2, queue 66).
		await _freeze_frame(main)
		print("RESULT fails: %d (frames in %s)" % [fails, out_dir])
		quit(1 if fails > 0 else 0)
		return
	_sheets(b)
	# Out to the edge of the light: you in the corridor outside its dead end,
	# your torch lit, facing its door; it has seen you.
	var room: Dictionary = b.ground.nodes[b.node]
	var door_link: Dictionary = {}
	for l in room.links:
		if int(l.door) >= 0:
			door_link = l
	var corridor: Dictionary = b.ground.nodes[int(door_link.to)]
	var pc: Dictionary = main.lay.pieces[int(corridor.piece)]
	var via: Vector3 = door_link.via
	var aa := Delves.along_across(pc, Vector2(via.x, via.z))
	var into := 1.0 if aa.x < float(pc.len) * 0.5 else -1.0
	var a_stand := clampf(aa.x + into * 7.0, 0.6, float(pc.len) - 0.6)
	var stand := BossGround.point(pc, a_stand, 0.0)
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	p.torch.light()
	var to := via - stand
	p.spawn_flat(stand, atan2(-to.x, -to.z), -0.08)
	await _frames(4)
	b.noticed = true
	b.state = "hunt"
	b._replan_t = 0.0
	var t := 0.0
	while t < 20.0 and b.state != "hang":
		b.tick(1.0 / 30.0)
		t += 1.0 / 30.0
	# A breath into the hold: reared, facing you.
	for i in 30:
		b.tick(1.0 / 30.0)
		if b.state != "hang":
			break
	print("  it came %.1f s, now %s, %.2f m from you (hang_m %.1f)" % [t, b.state, Vector3(b.base.x - stand.x, 0.0, b.base.z - stand.z).length(), float(b.sub("torch_delay").get("hang_m", 4.5))])
	await _frames(6)
	var edge := await _shot("10_snake_at_torch_edge")
	var head_px := _px(edge, b.head + Vector3(0.0, b.lift + 0.2, 0.0))
	b.body.visible = false
	await _frames(3)
	var bare := await _shot("10b_same_without_it")
	b.body.visible = true
	# Its pixels: where the frame changes when it is hidden, inside the box
	# round its head and body on screen.
	var box := Rect2(head_px, Vector2.ZERO)
	for sp in b.body.segs:
		var q := _px(edge, sp.global_position + Vector3(0.0, 0.2, 0.0))
		if q.x >= 0.0:
			box = box.expand(q)
	box = box.grow(30.0)
	var changed := 0
	var warm := 0
	for y in range(maxi(int(box.position.y), 0), mini(int(box.end.y), edge.get_height())):
		for x in range(maxi(int(box.position.x), 0), mini(int(box.end.x), edge.get_width())):
			var c1 := edge.get_pixel(x, y)
			var c0 := bare.get_pixel(x, y)
			if absf(_luma(c1) - _luma(c0)) > 0.03:
				changed += 1
				if c1.r > c1.b * 1.2 and _luma(c1) > 0.04:
					warm += 1
	var hc := _around(edge, head_px, 4)
	print("  the snake: %d pixels change when it is hidden (in %s), %d of them warm-lit; at its head #%s" % [changed, str(box), warm, hc.to_html(false)])
	ok(changed > 300 and warm > 60, "the snake shows at the edge of your light, lit by your torch (%d pixels, %d warm)" % [changed, warm])
	# The strike: jaws open.
	b.hang_t = 99.0
	b.state = "hunt"
	t = 0.0
	while t < 8.0 and not (b.state == "strike" and b.strike.state == "strike"):
		b.tick(1.0 / 30.0)
		t += 1.0 / 30.0
	await _frames(3)
	await _shot("11_snake_strikes")
	ok(b.mouth_open, "mid-strike, its jaws open")
	# Coiled in its room, from its door (laid there: a frames' placing).
	b._let_go("frames")
	b._calm()
	b._start_far()
	b.tick(1.0 / 30.0)
	await _frames(2)
	var cr: Dictionary = b.ground.nodes[b.node]
	var cpc: Dictionary = main.lay.pieces[int(cr.piece)]
	var entry := b._room_entry(b.node)
	# Close enough for the torch to reach it: 2.8 m off, toward its door.
	var see := b.base + Vector3(entry.x - b.base.x, 0.0, entry.z - b.base.z).normalized() * 2.8
	var to2 := b.base - see
	p.spawn_flat(Vector3(see.x, b._floor_y(see), see.z), atan2(-to2.x, -to2.z), -0.45)
	await _frames(6)
	await _shot("12_snake_coiled")
	print("  coiled in node %d (a %s, %s)" % [b.node, cr.kind, cpc.get("room_kind", "")])
	# At the edge of the hearth's light (Mike's note of 7 Oct: "they may
	# show just enough of their face/body near the fire"): it in the dark
	# outside a door of the hearth room, you by the fire 2.5 m in from that
	# door, facing it, your torch lit.
	await _peek(main)
	# One of its tunnels' holes, by torchlight.
	await _hole_frame(main)
	# The lair: from its room's door, and at its edge looking down.
	var l: Dictionary = main.lay.lair
	if not l.is_empty():
		var ln := b.lair_node
		var le := b._room_entry(ln)
		var lc: Vector3 = l.pos
		var to3 := lc - le
		p.spawn_flat(le, atan2(-to3.x, -to3.z), -0.3)
		# It is home (the last light): it travels there and goes down its
		# hole, breathing.
		b.release()
		var home_t := 0.0
		while home_t < 120.0 and b.state == "release":
			b.tick(1.0 / 30.0)
			home_t += 1.0 / 30.0
		print("  it went home in %.1f s (%s)" % [home_t, b.state])
		await _frames(6)
		await _shot("13_lair_from_door")
		var e := lc + (le - lc).normalized() * (float(l.r) + 0.55)
		var to4 := lc - e
		p.spawn_flat(Vector3(e.x, b._floor_y(e), e.z), atan2(-to4.x, -to4.z), -0.9)
		await _frames(6)
		var down := await _shot("14_lair_edge")
		var mouth := _around(down, _px(down, lc + Vector3(0.0, 0.07, 0.0)), 3)
		var rim := _around(down, _px(down, lc + (le - lc).normalized() * (float(l.r) + 0.4)), 3)
		print("  the hole: mouth #%s, the floor at its edge #%s" % [mouth.to_html(false), rim.to_html(false)])
		# The darkest the frame goes is the dark's navy (never grey, never
		# quite black): the mouth is that, against the firelit edge.
		ok(_luma(mouth) < _luma(rim) * 0.3 and mouth.b > mouth.r, "the hole's mouth is the dark's navy against its firelit edge")
	print("RESULT fails: %d (frames in %s)" % [fails, out_dir])
	quit(1 if fails > 0 else 0)


## The freeze (design 9 Oct §FM.2, queue 66; ONLY=freeze): the snake frozen
## about 20 m down a corridor lit by one of its sconces (its own stretch
## still its dark: the stretch's other end cold), the sconce on your side of
## it where one is and as much of its length in view as can be, seen from
## where you stand in a corridor with your torch lit, looking just over it
## (so the reticle is clear of it), all of it farther than from_m[0]
## (17_snake_frozen); the same with it hidden (17b), and the same with its
## camouflage off, its colours as painted (17c). Then you walk up to about
## 8.5 m of it, still frozen (close_m is 7): 17e frozen, 17f hidden, 17g as
## painted. Time stands still for each three (Engine.time_scale 0: the
## fires' flicker held), so only the snake differs: over the pixels it
## covers, how far it stands out from the stone behind it (RGB),
## camouflaged and as painted. 17d and 17h: each pair side by side, cropped
## round it and blown up, to look at.
func _freeze_frame(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var def: Dictionary = ((BossPool.DATA.get("pools", {}) as Dictionary).get("desert", {}) as Dictionary).get("freeze_watched", {})
	var lo := float((def.get("from_m", [12.0, 60.0]) as Array)[0])
	var close_m := float(def.get("close_m", 7.0))
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	p.torch.light()
	# Candidates: a stretch of corridor with a sconce at one end and its other
	# end dark, the snake laid along it, the sconce's light on its head; and
	# a spot about 20 m off its head on open floor, in a corridor (else a
	# room, never the hearth room), all of it at least from_m[0] + 1 off,
	# nothing between.
	var cands: Array = []
	for id in range(b.ground.nodes.size()):
		var n: Dictionary = b.ground.nodes[id]
		if str(n.kind) != "stretch" or not b.ground.is_ground(id) or (n.ends as Array).size() < 2:
			continue
		var ends: Array = n.ends
		for ei in ends.size():
			var e: Dictionary = ends[ei]
			if str(e.type) != "sconce":
				continue
			var other: Dictionary = ends[1 - ei] if ends.size() == 2 else {}
			if other.is_empty() or str(other.type) == "open":
				continue
			if str(other.type) == "door" and not b.ground.is_ground(int(other.node)):
				continue
			if str(other.type) == "sconce" and FireStore.is_lit(main.fires.holders[int(other.holder)]):
				continue
			b._lie_along(id)
			b._pose()
			var hp := b.head + Vector3(0.0, 0.25, 0.0)
			var h: Node3D = main.fires.holders[int(e.holder)]
			var fl := LightField.fire_light(h)
			var dl := (fl.pos as Vector3).distance_to(hp)
			if dl >= float(fl.range) or b._blocked(fl.pos, hp, false):
				continue
			var w := 1.0 - pow(dl / float(fl.range), 4.0)
			var lv := float(fl.energy) * w * w / pow(maxf(dl, 1.0), float(fl.att))
			if lv < 0.03:
				continue
			var body: Array = b._body_pts(0.5)
			for k in 72:
				var a := TAU * k / 72.0
				for r: float in [20.0, 19.5, 20.5, 19.0, 21.0]:
					var q := hp + Vector3(cos(a), 0.0, sin(a)) * r
					var c := b.nav.nearest_open(b.nav.cell_of(q), 2)
					if c.x < 0:
						continue
					q = b.nav.point_of(c)
					var dq := Vector2(q.x - hp.x, q.z - hp.z).length()
					if dq < 18.5 or dq > 21.5 or absf(q.y - b.head.y) > 1.5:
						continue
					var qn := b.ground.node_at(q)
					if qn < 0 or bool(b.ground.nodes[qn].hearth) or b.on_way_out(q):
						continue
					var near := INF
					var a_min := INF
					var a_max := -INF
					var fwd := Vector2(hp.x - q.x, hp.z - q.z).normalized()
					for bp: Vector3 in body:
						var rel := Vector2(bp.x - q.x, bp.z - q.z)
						near = minf(near, rel.length())
						var ang := rad_to_deg(fwd.angle_to(rel))
						a_min = minf(a_min, ang)
						a_max = maxf(a_max, ang)
					if near < lo + 1.0:
						continue
					if b._blocked(q + Vector3(0.0, p.eye_height(), 0.0), hp, false):
						continue
					var corridor := str(b.ground.nodes[qn].kind) == "stretch"
					# Lit from your side: the sconce on your side of its head, so
					# its light falls on the side of it you see (a sprite lit
					# from behind is a dark shape whatever its colours).
					var to_l := (fl.pos as Vector3) - hp
					var to_q := q - hp
					var front := to_l.x * to_q.x + to_l.z * to_q.z > 0.0
					cands.append({"node": id, "holder": int(e.holder), "spot": q, "light": lv, "corridor": corridor, "front": front,
						"ext": a_max - a_min, "off": absf(dq - 20.0), "near": near})
	cands.sort_custom(_freeze_order)
	# The first that holds in the game: its sconce lit, the snake laid, you
	# there looking at it, and it watched (BossStalk.watched).
	var pick := {}
	var tried := 0
	for cd in cands.slice(0, 24):
		tried += 1
		var h2: Node3D = main.fires.holders[int(cd.holder)]
		if not FireStore.is_lit(h2):
			FireStore.swing_light(h2, float(main.world.get("days")))
			for i in 600:
				FireStore.tick(self, 1.0 / 60.0, h2.global_position)
				if FireStore.is_lit(h2):
					break
		b._lie_along(int(cd.node))
		b.tick(1.0 / 30.0)
		if b.node != int(cd.node) or not b.ground.is_ground(b.node):
			continue
		_look_over(p, cd.spot, b)
		await _frames(2)
		if BossStalk.watched(b, def):
			pick = cd
			break
	var at_d := Vector2((pick.get("spot", Vector3.ZERO) as Vector3).x - b.head.x, (pick.get("spot", Vector3.ZERO) as Vector3).z - b.head.z).length() if not pick.is_empty() else -1.0
	ok(not pick.is_empty(), "a corridor to freeze it in: stretch %d, its sconce %d lit (%.3f on its head, lit from %s), you %.1f m off its head in %s, all of it at least %.1f m off, %.0f degrees of your view across (%d of %d places tried)" % [int(pick.get("node", -1)), int(pick.get("holder", -1)), float(pick.get("light", 0.0)), "your side" if bool(pick.get("front", false)) else "beyond it", at_d, "a corridor" if bool(pick.get("corridor", false)) else "a room", float(pick.get("near", 0.0)), float(pick.get("ext", 0.0)), tried, cands.size()])
	if pick.is_empty():
		return
	# Its rounds don't take you up meanwhile (a frames' placing).
	b.let_go_t = 1.0e6
	b.set_pool(BossPool.from_dict({"freeze_watched": def}, BossPool.RULE, "frames"))
	var t := 0.0
	while t < 2.0 and b.behaviour != "freeze_watched":
		b.tick(1.0 / 30.0)
		t += 1.0 / 30.0
	var froze := b.behaviour == "freeze_watched"
	for i in 60:
		b.tick(1.0 / 30.0)
	ok(froze and b.node == int(pick.node) and b.ground.is_ground(b.node) and b.camo > 0.25, "frozen %.1f m off its head (its nearest %.1f m) in its dark stretch, its camouflage %.2f" % [BossStalk.to_you(b), BossStalk.nearest_part_m(b), b.camo])
	await _frames(6)
	var far := await _freeze_shots(main, ["17_snake_frozen", "17b_same_without_it", "17c_same_unfrozen", "17d_crop_frozen_and_painted"])
	ok(int(far.shown) > 10 and float(far.mean) > 0.03, "at 20 m, frozen, it still shows: readable on a second look (%d pixels, standing out %.3f from the stone behind; as painted %.3f: %.0f%% as much)" % [int(far.shown), float(far.mean), float(far.mean_plain), float(far.share) * 100.0])
	# You walk up to about 8.5 m of it (outside close_m), looking at it: still
	# frozen, camouflaged.
	var head0 := b.head
	var spot: Vector3 = pick.spot
	var dv := Vector3(spot.x - head0.x, 0.0, spot.z - head0.z).normalized()
	var near_spot := Vector3.INF
	for k in 40:
		var r := 6.0 + 0.25 * k
		var q := head0 + dv * r
		var c := b.nav.nearest_open(b.nav.cell_of(q), 2)
		if c.x < 0:
			continue
		q = b.nav.point_of(c)
		var m := INF
		for bp: Vector3 in BossStalk.look_points(b):
			m = minf(m, Vector2(bp.x - q.x, bp.z - q.z).length())
		if m >= close_m + 1.3 and not b._blocked(q + Vector3(0.0, p.eye_height(), 0.0), b.head + Vector3(0.0, 0.25, 0.0), false):
			near_spot = q
			break
	ok(near_spot.is_finite(), "a spot about 8.5 m off it on the way you came (%s)" % str(near_spot))
	if not near_spot.is_finite():
		return
	_look_over(p, near_spot, b)
	for i in 15:
		b.tick(1.0 / 30.0)
	ok(b.behaviour == "freeze_watched" and b.camo > 0.25, "walked up to %.1f m of it (close_m %.0f), it is still frozen, its camouflage %.2f" % [BossStalk.nearest_part_m(b), close_m, b.camo])
	await _frames(6)
	var near := await _freeze_shots(main, ["17e_frozen_8m", "17f_without_it_8m", "17g_unfrozen_8m", "17h_crop_8m"])
	ok(int(near.shown) > 10 and float(near.share) < 0.97, "at 8.5 m, frozen, it stands out less than as painted, and still shows (%.0f%% as much: %.3f against %.3f, %d pixels)" % [float(near.share) * 100.0, float(near.mean), float(near.mean_plain), int(near.shown)])


## You at `at`, looking at the snake's head from just above it (so the
## reticle is clear of it, and the snake well inside look_deg).
func _look_over(p: CrawlerPlayer, at: Vector3, b: Boss) -> void:
	var hp := b.head + Vector3(0.0, 0.25, 0.0)
	var eye := at + Vector3(0.0, p.eye_height(), 0.0)
	var d := Vector2(hp.x - eye.x, hp.z - eye.z).length()
	var aim := hp + Vector3(0.0, tan(deg_to_rad(5.0)) * d, 0.0)
	var v := aim - eye
	p.spawn_flat(at, atan2(-v.x, -v.z), atan2(v.y, Vector2(v.x, v.z).length()))


## Three shots with time held still (the fires' flicker held): the snake as
## it is, hidden, and with its camouflage off (as painted); then its pixels
## (where it shows, either way, against the stone behind it) measured, and
## the pair cropped round it and blown up (names[3]). {"shown" (its pixels
## showing as it is), "mean", "mean_plain" (how far it stands out, RGB),
## "share" (as it is against as painted)}.
func _freeze_shots(main: CrawlerMain, names: Array) -> Dictionary:
	var b := main.boss
	Engine.time_scale = 0.0
	await _frames(3)
	var img := await _shot(str(names[0]))
	b.body.visible = false
	await _frames(3)
	var bare := await _shot(str(names[1]))
	b.body.visible = true
	var th := str(main.lay.get("theme", ""))
	b.body.set_camouflage(0.0, RuinStyle.tint(th), RuinStyle.spread(th))
	await _frames(3)
	var plain := await _shot(str(names[2]))
	b.body.set_camouflage(b.camo, RuinStyle.tint(th), RuinStyle.spread(th))
	Engine.time_scale = 1.0
	var box := Rect2(_px(img, b.head + Vector3(0.0, 0.25, 0.0)), Vector2.ZERO)
	for sp in b.body.all_sprites():
		var q2 := _px(img, sp.global_position + Vector3(0.0, 0.2, 0.0))
		if q2.x >= 0.0:
			box = box.expand(q2)
	box = box.grow(16.0)
	var shown := 0
	var sums := [0.0, 0.0]
	var mask := 0
	for y in range(maxi(int(box.position.y), 0), mini(int(box.end.y), img.get_height())):
		for x in range(maxi(int(box.position.x), 0), mini(int(box.end.x), img.get_width())):
			var cb := bare.get_pixel(x, y)
			var dz := _rgb_d(img.get_pixel(x, y), cb)
			var dp := _rgb_d(plain.get_pixel(x, y), cb)
			if dz <= 0.03 and dp <= 0.03:
				continue
			mask += 1
			sums[0] = float(sums[0]) + dz
			sums[1] = float(sums[1]) + dp
			if dz > 0.03:
				shown += 1
	var out := {"shown": shown, "mean": float(sums[0]) / maxf(mask, 1), "mean_plain": float(sums[1]) / maxf(mask, 1),
		"share": float(sums[0]) / maxf(float(sums[1]), 1e-6)}
	print("  %s: over its %d pixels it stands out %.3f (RGB, mean) from the stone behind, %d of them showing; as painted %.3f: %.0f%% as much" % [str(names[0]), mask, float(out.mean), shown, float(out.mean_plain), float(out.share) * 100.0])
	var cr := box.intersection(Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height())))
	if cr.size.x >= 4.0 and cr.size.y >= 4.0:
		var ri := Rect2i(cr)
		var a1 := img.get_region(ri)
		var a2 := plain.get_region(ri)
		var both := Image.create(ri.size.x * 2 + 4, ri.size.y, false, a1.get_format())
		both.fill(Color.BLACK)
		both.blit_rect(a1, Rect2i(Vector2i.ZERO, ri.size), Vector2i.ZERO)
		both.blit_rect(a2, Rect2i(Vector2i.ZERO, ri.size), Vector2i(ri.size.x + 4, 0))
		var scale := clampi(int(480.0 / maxf(ri.size.y, 1.0)), 1, 4)
		both.resize(both.get_width() * scale, both.get_height() * scale, Image.INTERPOLATE_NEAREST)
		both.save_png(out_dir.path_join(str(names[3]) + ".png"))
		print("  frame %s (frozen left, as painted right)" % str(names[3]))
	return out


## The freeze frame's places, the likeliest first: lit from your side, then
## in a corridor, then as much of its length across your view as can be,
## then nearest 20 m off its head.
func _freeze_order(x: Dictionary, y: Dictionary) -> bool:
	if bool(x.front) != bool(y.front):
		return bool(x.front)
	if bool(x.corridor) != bool(y.corridor):
		return bool(x.corridor)
	if absf(float(x.ext) - float(y.ext)) > 2.0:
		return float(x.ext) > float(y.ext)
	return float(x.off) < float(y.off)


## RGB distance between two colours.
func _rgb_d(a: Color, c: Color) -> float:
	return Vector3(a.r - c.r, a.g - c.g, a.b - c.b).length()


## The snake at the edge of the hearth's light, its head forward into the
## glow (peek_m), from by the fire; the same with it hidden, to count it.
func _peek(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var g := b.ground
	var lf := main.residents.light
	var hearth := g.node_at(main.lay.wake[0])
	var outside := -1
	var via := Vector3.ZERO
	for l in g.nodes[hearth].links:
		if g.is_ground(int(l.to)) and not l.has("tunnel"):
			outside = int(l.to)
			via = l.via
			break
	if outside < 0:
		ok(false, "a stretch of its dark at the hearth room's door")
		return
	b._let_go("frames")
	b._calm()
	if str(g.nodes[outside].kind) == "room":
		b._lie_coiled(outside)
	elif not _lie_facing(b, outside, via):
		ok(false, "its whole body laid out in the dark beyond the hearth room's door")
		return
	var c: Vector3 = g.nodes[hearth].center
	var into := Vector3(c.x - via.x, 0.0, c.z - via.z).normalized()
	var by_fire := via + into * 2.5
	by_fire.y = b._floor_y(by_fire)
	p.spawn_flat(by_fire, atan2(into.x, into.z), -0.05)
	if not p.torch.lit():
		p.torch.light()
	await _frames(4)
	b.noticed = true
	b.pursuit.notice(true)
	b.hang_t = 99.0
	b.struck = false
	b.state = "hunt"
	b._replan_t = 0.0
	b._hunt_to = Vector3.INF
	var peak := 0.0
	var t := 0.0
	while t < 20.0 and not (b.state == "watch" and b.lunge >= b.num("peek_m", 0.7) - 0.05):
		b.tick(1.0 / 30.0)
		t += 1.0 / 30.0
		peak = maxf(peak, lf.at(b.base))
	var head := b.head + b.dir * b.lunge
	print("  at the hearth's light: %s after %.1f s, %.2f m from you, its head %.2f m forward (the light %.3f at its head, %.3f at its feet; the cap %.3f)" % [b.state, t, Vector3(b.base.x - by_fire.x, 0.0, b.base.z - by_fire.z).length(), b.lunge, lf.at(head), lf.at(b.base), lf.cap])
	await _frames(6)
	var shot := await _shot("15_snake_peeks_at_the_hearth_light")
	var head_px := _px(shot, head + Vector3(0.0, b.lift + 0.2, 0.0))
	# Its body as drawn behind it: along the trail its head left (none of it
	# run on straight past the trail's end, BossBody's fallback), and all of
	# it in the dark.
	var length := float(b.sub("body").get("length_m", 9.0))
	var along: Array = b._body_pts(0.25)
	var body_most := 0.0
	for q: Vector3 in along:
		body_most = maxf(body_most, lf.at(q))
	var laid := float(along.size() - 1) * 0.25
	print("  its body: %.1f m of it along the way it came (length_m %.1f), the light on it %.3f at most" % [laid, length, body_most])
	ok(laid >= length - 0.25 - 1e-3 and body_most <= lf.cap + 1e-4, "its whole body behind it in the dark, along the floor it came by (%.1f of %.1f m; the light on it %.3f at most, the cap %.3f)" % [laid, length, body_most, lf.cap])
	b.body.visible = false
	await _frames(3)
	var bare := await _shot("15b_same_without_it")
	b.body.visible = true
	var box := Rect2(head_px, Vector2.ZERO)
	for sp in b.body.segs:
		var q := _px(shot, sp.global_position + Vector3(0.0, 0.2, 0.0))
		if q.x >= 0.0:
			box = box.expand(q)
	box = box.grow(30.0)
	var changed := 0
	for y in range(maxi(int(box.position.y), 0), mini(int(box.end.y), shot.get_height())):
		for x in range(maxi(int(box.position.x), 0), mini(int(box.end.x), shot.get_width())):
			if absf(_luma(shot.get_pixel(x, y)) - _luma(bare.get_pixel(x, y))) > 0.03:
				changed += 1
	ok(b.state == "watch" and peak <= lf.cap + 1e-4 and changed > 150, "the snake at the edge of the hearth's light, its head forward into the glow, never past the cap (the light at its feet %.3f at most): %d pixels of it from by the fire" % [peak, changed])
	b._let_go("frames")
	b._calm()


## Laid out in the dark beyond the hearth room's door `door` (a frames'
## placing; in play it gets anywhere only by going there, and its body
## lies along the way it went): its head 0.3 m in from the far end of
## corridor stretch `id`, facing the door, and its whole body behind it
## along the chase's own way out from there (TombNav's capped grid, so
## none of it in the light), the longest such way to any of its dark.
## False if no way out is as long as its body.
func _lie_facing(b: Boss, id: int, door: Vector3) -> bool:
	var g := b.ground
	var n: Dictionary = g.nodes[id]
	var pc: Dictionary = b.lay.pieces[int(n.piece)]
	var p0 := BossGround.point(pc, float(n.a0), 0.0)
	var p1 := BossGround.point(pc, float(n.a1), 0.0)
	var a0_near := Vector2(p0.x - door.x, p0.z - door.z).length() < Vector2(p1.x - door.x, p1.z - door.z).length()
	var at := BossGround.point(pc, float(n.a1) - 0.3 if a0_near else float(n.a0) + 0.3, 0.0)
	var length := float(b.sub("body").get("length_m", 9.0))
	var best := PackedVector3Array()
	for k in g.nodes.size():
		if k == id or not g.is_ground(k):
			continue
		var way := b.nav.path(at, g.nodes[k].center, true, TombNav.CAP)
		if TombNav.length_of(way) > TombNav.length_of(best):
			best = way
	if TombNav.length_of(best) < length + 0.5:
		return false
	# Oldest first: from the far end of that way back to where its head is.
	var tail_first: Array = []
	for i in range(best.size() - 1, -1, -1):
		tail_first.append(best[i])
	b._trail_from(tail_first)
	b.base = best[0]
	b.head = b.base
	var to_door := Vector3(door.x - b.base.x, 0.0, door.z - b.base.z)
	b.dir = to_door.normalized() if to_door.length() > 0.01 else Vector3.FORWARD
	b.node = g.node_at(b.base)
	b.target = id
	b.state = "coil"
	b.coiling = false
	b.coil_left = 5.0
	b._set_route(PackedVector3Array())
	return true


## One of its tunnels' holes (Mike's note of 7 Oct: "they may have their
## own tunnels"), by torchlight from 1.8 m before it, looking a little
## down. Through its mouth you see its sill (the floor going in, torchlit
## like any floor) and, over that, its back: the black. Every pixel whose
## sight passes in through the mouth to the back (worked out from the
## camera, a few cm clear of every edge) must be the dark's navy, dark
## against the torchlit stone beside it.
func _hole_frame(main: CrawlerMain) -> void:
	var b := main.boss
	var p := main.player
	var holes: Array = (main.lay.get("tunnels", {}) as Dictionary).get("holes", [])
	if holes.is_empty():
		ok(false, "the tomb has the snake's holes")
		return
	# Its body out of the way, coiled in its far dead end.
	b._let_go("frames")
	b._calm()
	b._start_far()
	var h: Dictionary = holes[0]
	for q in holes:
		if not bool(q.get("lair", false)):
			h = q
			break
	var n: Vector3 = h.n
	var u: Vector3 = h.u
	var at: Vector3 = (h.pos as Vector3) + n * 1.8
	at.y = b._floor_y(at)
	p.spawn_flat(at, atan2(n.x, n.z), -0.35)
	if not p.torch.lit():
		p.torch.light()
	await _frames(8)
	var img := await _shot("16_tunnel_hole")
	var hp: Vector3 = h.pos
	var w := float(h.w)
	var hh := float(h.h)
	var side := hp + u * (w * 0.5 + 0.3) + Vector3.UP * 0.25
	var by_it := _around(img, _px(img, side), 3)
	# Its mouth on the frame (the arch on the wall's face), its back where
	# the boss hangs the black (Boss._hole_mouths), and each a few cm in
	# from its edges (MARGIN): a sight in through the one and on to the
	# other sees the black.
	const MARGIN := 0.03
	var mouth := TombBuild._arch(0.0, w, 0.0, hh)
	var clear := TombBuild._arch(0.0, w - MARGIN * 2.0, MARGIN, hh - MARGIN)
	var back := float(h.depth) - 0.04
	var outline := PackedVector2Array()
	for v: Vector2 in mouth:
		var q := _px(img, hp + u * v.x + Vector3.UP * v.y)
		if q.x < 0.0:
			ok(false, "its hole in view")
			return
		outline.append(q)
	var box := Rect2(outline[0], Vector2.ZERO)
	for q in outline:
		box = box.expand(q)
	var cam := get_root().get_camera_3d()
	var vs := get_root().get_visible_rect().size
	var in_mouth := 0
	var black_in_mouth := 0
	var sees_back := 0
	var black := 0
	var black_sum := Color(0, 0, 0)
	var not_black := Color(0, 0, 0)
	for y in range(maxi(int(box.position.y), 0), mini(int(ceil(box.end.y)) + 1, img.get_height())):
		for x in range(maxi(int(box.position.x), 0), mini(int(ceil(box.end.x)) + 1, img.get_width())):
			var c := img.get_pixel(x, y)
			var is_black := _luma(c) < _luma(by_it) * 0.5 and c.b > c.r
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), outline):
				in_mouth += 1
				if is_black:
					black_in_mouth += 1
			# The sight through this pixel: where it crosses the face, and
			# where it reaches the back's depth.
			var sp := Vector2((x + 0.5) / img.get_width() * vs.x, (y + 0.5) / img.get_height() * vs.y)
			var o := cam.project_ray_origin(sp)
			var dv := cam.project_ray_normal(sp)
			if dv.dot(n) > -1e-4:
				continue
			var at_face := o + dv * ((hp - o).dot(n) / dv.dot(n))
			var at_back := o + dv * ((hp - n * back - o).dot(n) / dv.dot(n))
			if not Geometry2D.is_point_in_polygon(Vector2((at_face - hp).dot(u), at_face.y - hp.y), clear):
				continue
			if not Geometry2D.is_point_in_polygon(Vector2((at_back - hp).dot(u), at_back.y - hp.y), clear):
				continue
			sees_back += 1
			if is_black:
				black += 1
				black_sum += c
			else:
				not_black += c
	var share := float(black) / float(maxi(sees_back, 1))
	print("  the hole (%s, %.2f x %.2f m) from %.1f m: %d pixels of its mouth, %.0f%% of them the black (the rest its sill, torchlit going in); %d see in to its back, %d of them the black (#%s)%s; the stone beside it #%s" % [str(h.get("piece", "?")), w, hh, Vector3(at.x - hp.x, 0.0, at.z - hp.z).length(), in_mouth, 100.0 * black_in_mouth / float(maxi(in_mouth, 1)), sees_back, black, (black_sum / float(maxi(black, 1))).to_html(false), "" if black == sees_back else ", the others #%s" % (not_black / float(sees_back - black)).to_html(false), by_it.to_html(false)])
	ok(sees_back >= 150 and share >= 0.95, "its hole reads as a way into the black: every sight in through its mouth to its back is the dark's navy (%d of %d), dark against the torchlit stone beside it" % [black, sees_back])


## Its sheets, saved, and every cell holding the body.
func _sheets(b: Boss) -> void:
	var names := ["shut", "open", "segment", "banded"]
	var sprites: Array = [b.body.head_shut, b.body.head_open, b.body.segs[0], b.body.segs[BossBody.BAND_EVERY - 1]]
	for k in 4:
		var s: FigureSprite = sprites[k]
		var sheet := s.atlas.get_image()
		sheet.save_png(out_dir.path_join("0%d_sheet_%s.png" % [k + 1, names[k]]))
		var cw := sheet.get_width() / s.around
		var ch := sheet.get_height() / s.rows_deg.size()
		var least := 1 << 30
		for row in s.rows_deg.size():
			for col in s.around:
				var n := 0
				for y in ch:
					for x in cw:
						if sheet.get_pixel(col * cw + x, row * ch + y).a > 0.5:
							n += 1
				least = mini(least, n)
		ok(least > 12, "its %s sheet: every one of %d cells holds it (fewest %d px)" % [names[k], s.around * s.rows_deg.size(), least])
