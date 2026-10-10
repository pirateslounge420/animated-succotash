extends SceneTree
## The feathered serpent (design 10 Oct §FN.2, queue 78; BossBody, Boss,
## SoundSynth snake_rattle, bosses.json bosses.desert body.plumes and
## rattle):
##   godot --headless --path . --fixed-fps 60 --script tools/feathered_serpent_check.gd
## and, for the baked pixels, rendered (a software Vulkan is enough):
##   xvfb-run -a godot --path . --fixed-fps 60 --script tools/feathered_serpent_check.gd
## Asserts:
##  1. the paint: the body length's model carries the plumes' green and
##     turquoise, the head's the red too, the tail's the rattle's rings and
##     no plume; on false bakes none of them;
##  2. the sheets: every sheet's pixel size is px_seg's or px_head's as
##     before (the plumes fit in the frame they had); rendered, the plume
##     colours are in the body's and the shut head's pixels, the red in the
##     head's, and the rattle's pale rings in the tail's;
##  3. the body keeps its lengths; the camouflage still reaches every
##     sprite and max_blend is still under 1;
##  4. snake_rattle: SoundSynth makes it, non-silent, a fast train of
##     clicks (50-70 a second);
##  5. when: forced into each moment (hold, wind_up, move, none) under each
##     'when' list Mike may write ([], the first guess ["hold"], ["move"],
##     ["wind_up"], all three), it rattles in exactly the moments listed,
##     never in another, never with [], and stops on the tick it leaves one;
##     loose for 60 s with the file's list, every shiver began in a moment
##     the file names.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	Residents.stay_asleep = true
	Bow.need_capture = false
	Torch.burn_down = false
	var headless := DisplayServer.get_name() == "headless"
	OS.set_environment("SEED", "7")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked or not main.boss.started or not main.boss.body.baked:
		await process_frame
	var boss: Boss = main.boss
	boss.auto = false
	var body: BossBody = boss.body
	_paint(body)
	_sheets(body, headless)
	_wear(boss)
	_sound()
	_when(boss)
	await _loose(main)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Is `c` near the plume colour `want` (hue within 0.06 and saturated)?
static func _near(c: Color, want: Color) -> bool:
	var dh := absf(c.h - want.h)
	dh = minf(dh, 1.0 - dh)
	return dh < 0.06 and c.s > 0.3 and c.a > 0.5


func _cols(mesh_root: Node) -> PackedColorArray:
	var out := PackedColorArray()
	var nodes: Array = [mesh_root]
	nodes.append_array(mesh_root.find_children("*", "MeshInstance3D", true, false))
	for n in nodes:
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
			var m := (n as MeshInstance3D).mesh
			for sfc in m.get_surface_count():
				var arr := m.surface_get_arrays(sfc)
				if arr[Mesh.ARRAY_COLOR] != null:
					out.append_array(arr[Mesh.ARRAY_COLOR])
	return out


func _count(cols: PackedColorArray, want: Color) -> int:
	var n := 0
	for c in cols:
		if _near(c, want):
			n += 1
	return n


func _paint(body: BossBody) -> void:
	var pl := body.plumes
	var green := Color(str(pl.get("green")))
	var turq := Color(str(pl.get("turquoise")))
	var red := Color(str(pl.get("red")))
	var pale := Color(str(body.rattle.get("ring_color")))
	ok(not pl.is_empty() and not body.rattle.is_empty(), "the snake has plumes and a rattle in the file (body.plumes, rattle)")
	var seg := body._segment_mesh(false)
	var band := body._segment_mesh(true)
	var tail := body._segment_mesh(false, true)
	var head := body._head_mesh(false)
	var sc := _cols(seg)
	var tc := _cols(tail)
	var hc := _cols(head)
	print("  plume vertices: body %d green %d turquoise, band %d, head %d green %d turquoise %d red; tail %d plume %d ring" % [_count(sc, green), _count(sc, turq), _count(_cols(band), green) + _count(_cols(band), turq), _count(hc, green), _count(hc, turq), _count(hc, red), _count(tc, green) + _count(tc, turq), _count(tc, pale)])
	ok(_count(sc, green) > 0 and _count(sc, turq) > 0, "a body length is painted with the plumes' green and turquoise")
	ok(_count(_cols(band), green) + _count(_cols(band), turq) > 0, "a banded length wears the plumes too")
	ok(_count(hc, green) > 0 and _count(hc, turq) > 0 and _count(hc, red) > 0, "the head's ruff is green and turquoise with red at the throat")
	ok(_count(tc, green) + _count(tc, turq) == 0 and _count(tc, pale) > 0, "the tail's length carries the rattle's pale rings and no plume")
	# Plumes off: the plain snake.
	var keep := body.plumes
	body.plumes = {}
	var plain := _cols(body._segment_mesh(false))
	ok(_count(plain, green) + _count(plain, turq) == 0, "plumes.on false bakes no plume")
	body.plumes = keep
	for n in [seg, band, tail, head]:
		n.free()


func _sheets(body: BossBody, headless: bool) -> void:
	var px_seg := int(body.D.get("px_seg", 28))
	var px_head := int(body.D.get("px_head", 40))
	var rows := (FigureSprite.SP.get("rows_deg", [-25, 0, 30]) as Array).size()
	var cols := int(FigureSprite.SP.get("around", 8))
	var want := [px_seg, px_head, px_head, px_seg, px_seg]
	var sizes_ok := body.sheets.size() == 5
	for i in mini(body.sheets.size(), 5):
		var img: Image = body.sheets[i][0]
		var px: int = want[i]
		sizes_ok = sizes_ok and img.get_height() == px * rows and img.get_width() == int(round(px * 0.75)) * cols
	ok(sizes_ok, "five sheets (body, head shut, head open, band, tail), each the pixel size of px_seg or px_head as before")
	if headless:
		print("  (headless: the sheets are blank; run under xvfb-run for their pixels)")
		return
	var pl := body.plumes
	var pix := func(img: Image, want_c: Color) -> int:
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				if _near(img.get_pixel(x, y), want_c):
					n += 1
		return n
	var green := Color(str(pl.get("green")))
	var turq := Color(str(pl.get("turquoise")))
	var red := Color(str(pl.get("red")))
	var seg_img: Image = body.sheets[0][0]
	var head_img: Image = body.sheets[1][0]
	var tail_img: Image = body.sheets[4][0]
	var sg: int = pix.call(seg_img, green) + pix.call(seg_img, turq)
	var hg: int = pix.call(head_img, green) + pix.call(head_img, turq)
	var hr: int = pix.call(head_img, red)
	var tg: int = pix.call(tail_img, green) + pix.call(tail_img, turq)
	print("  plume pixels: body sheet %d, head sheet %d (+%d red), tail sheet %d" % [sg, hg, hr, tg])
	ok(sg >= 24, "the plumes show in the body sheet's pixels (%d, at 24 at least: 1 a view)" % sg)
	ok(hg >= 24 and hr > 0, "the ruff shows in the head sheet's pixels, the red too")
	ok(tg == 0, "no plume on the tail's sheet")


func _wear(boss: Boss) -> void:
	var body := boss.body
	var n := body.segs.size()
	ok(n > 4, "the body has its %d lengths, as before" % n)
	# Every sprite takes the blend (the plumes are in the paint).
	body.set_camouflage(0.3, Color(0.5, 0.45, 0.4), 0.1)
	ok(is_equal_approx(body.camo, 0.3), "the camouflage still reaches every sprite, plumes and rattle with them")
	body.set_camouflage(0.0, Color(0.5, 0.45, 0.4), 0.1)
	var mb := float((BossPool.DATA.get("camouflage", {}) as Dictionary).get("max_blend", 0.6))
	ok(mb < 1.0, "camouflage.max_blend is still under 1 (%.2f): never gone" % mb)


func _sound() -> void:
	var w := SoundSynth.stream("snake_rattle", 0)
	ok(w != null, "SoundSynth makes snake_rattle")
	if w == null:
		return
	var data := w.data
	var n := data.size() / 2
	var peak := 0
	var clicks := 0
	var above := false
	var last_click := -1000
	for i in n:
		var v := absi(data.decode_s16(i * 2))
		peak = maxi(peak, v)
	# Clicks: rising edges of the rectified signal's quick envelope.
	var e2 := 0.0
	for i in n:
		var v := float(absi(data.decode_s16(i * 2)))
		e2 = maxf(e2 * 0.9, v)
		if not above and e2 > peak * 0.35 and i - last_click > int(SoundSynth.RATE / 120.0):
			above = true
			clicks += 1
			last_click = i
		elif above and e2 < peak * 0.15:
			above = false
	var secs := float(n) / SoundSynth.RATE
	var rate := clicks / secs
	print("  snake_rattle: %.2f s, peak %d, %d clicks (%.0f a second)" % [secs, peak, clicks, rate])
	ok(peak > 8000, "snake_rattle is not silent")
	ok(rate > 35.0 and rate < 85.0, "a fast train of clicks, a rattlesnake's 50-70 a second (%.0f)" % rate)


## Force the moment `m` on it (its state, its strike's).
func _force(boss: Boss, m: String) -> void:
	boss.strike.state = "ready"
	boss.speed = 0.0
	match m:
		"hold":
			boss.state = "hang"
		"wind_up":
			boss.state = "strike"
			boss.strike.state = "wind_up"
		"move":
			boss.state = "hunt"
			boss.speed = 3.0
		_:
			boss.state = "coil"


func _when(boss: Boss) -> void:
	var rt: Dictionary = boss.def["rattle"]
	var keep: Array = rt["when"]
	ok(keep == ["hold"], "the file's first guess: it rattles while it holds off at your flame (%s)" % str(keep))
	var player := boss.get_node_or_null("Rattle") as AudioStreamPlayer3D
	ok(player != null, "its rattle has its own player, tuned as the hiss is (strike_tell)")
	var all_ok := true
	for lst: Array in [[], ["hold"], ["move"], ["wind_up"], ["hold", "move", "wind_up"]]:
		rt["when"] = lst
		for m in ["hold", "wind_up", "move", "none"]:
			_force(boss, m)
			if lst.is_empty():
				ok(boss.rattle_moment() == ("" if m == "none" else m), "forced into %s, its moment reads '%s'" % [m, boss.rattle_moment()])
			var before := boss.rattles
			for i in 90:
				boss._rattle_tick(1.0 / 30.0)
			var shook := boss.rattles > before
			var want: bool = m in lst
			if shook != want:
				all_ok = false
				print("  FAIL detail: when %s, moment %s: rattled %s" % [str(lst), m, str(shook)])
			# Leave it: stopped on that tick.
			_force(boss, "none")
			boss._rattle_tick(1.0 / 30.0)
			if player != null and player.playing:
				all_ok = false
				print("  FAIL detail: when %s, still playing after %s ended" % [str(lst), m])
	ok(all_ok, "under every list it rattles in exactly the moments listed, never with [], and stops on the tick it leaves them")
	rt["when"] = keep
	boss.rattles = 0
	boss.rattle_moments.clear()


func _loose(main: CrawlerMain) -> void:
	var boss: Boss = main.boss
	var rt: Dictionary = boss.def["rattle"]
	var keep: Array = rt["when"]
	boss.auto = true
	# Loose on its rounds, rattling while it moves (a list Mike may write),
	# then with the file's own list.
	for lst: Array in [["move"], keep]:
		rt["when"] = lst
		boss.rattles = 0
		boss.rattle_moments.clear()
		var t := 0.0
		while t < 40.0:
			await physics_frame
			t += 1.0 / 60.0
		var bad := 0
		for m in boss.rattle_moments:
			if not (m in lst):
				bad += 1
		print("  loose 40 s, when %s: %d shivers, moments %s" % [str(lst), boss.rattles, str(boss.rattle_moments.slice(0, 6))])
		ok(bad == 0, "loose with when %s, every shiver began in a moment it names (%d of %d outside)" % [str(lst), bad, boss.rattles])
		if lst == ["move"]:
			ok(boss.rattles > 0, "loose on its rounds with when [\"move\"], it rattles as it goes (%d)" % boss.rattles)
	rt["when"] = keep
