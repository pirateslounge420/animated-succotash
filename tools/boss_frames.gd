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
## count it; one of its tunnels' holes by torchlight.
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
