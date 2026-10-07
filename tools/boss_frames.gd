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
## door; the lair from its room's door and from its edge, looking down.
## Checks: every cell of every sheet holds the body; the snake shows at
## the torch's edge (pixels that change when it is hidden, warm-lit); the
## hole's mouth is the darkest thing round it.

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
	# Coiled in its room, from its door.
	b.after_wake()
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
	# The lair: from its room's door, and at its edge looking down.
	var l: Dictionary = main.lay.lair
	if not l.is_empty():
		var ln := b.lair_node
		var le := b._room_entry(ln)
		var lc: Vector3 = l.pos
		var to3 := lc - le
		p.spawn_flat(le, atan2(-to3.x, -to3.z), -0.3)
		# It is home (the last light), breathing.
		b.release()
		b._home()
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
