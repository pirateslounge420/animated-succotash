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
## of the hearth's light, never past the chase's cap; its tunnel's hole is
## dark inside against the torchlit stone beside it.

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
	else:
		b._lie_along(outside)
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


## One of its tunnels' holes (Mike's note of 7 Oct: "they may have their
## own tunnels"), by torchlight from 1.8 m before it, looking a little
## down: the hole dark against the lit stone beside it.
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
	var mid := (h.pos as Vector3) + Vector3.UP * float(h.h) * 0.4 - n * 0.05
	var side := (h.pos as Vector3) + u * (float(h.w) * 0.5 + 0.3) + Vector3.UP * 0.25
	var in_hole := _around(img, _px(img, mid), 3)
	var by_it := _around(img, _px(img, side), 3)
	print("  the hole (%s, %.2f x %.2f m): inside #%s, the stone beside it #%s" % [str(h.get("piece", "?")), float(h.w), float(h.h), in_hole.to_html(false), by_it.to_html(false)])
	ok(_luma(in_hole) < _luma(by_it) * 0.5, "its hole reads as a way into the black: dark inside against the torchlit stone beside it")


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
