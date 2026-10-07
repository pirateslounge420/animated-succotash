extends SceneTree
## The crawler's visual check (design 6 Oct §ET.11; §CA's walkabout, for
## Torchfire 1): renders the first slice and saves frames, once, at the
## end of a pass (no screenshots between steps):
##   SEED=7 xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/crawler_frames.gd
## Frames go to OUT (default user://crawler_frames/<seed>/): waking by the
## hearth (noon and midnight), up the hearth's shaft, a fitted-stone wall
## by torchlight, the torch 1 m and 0.45 m from a wall (§EX.6); the
## rescuer's sheet; the rescuer from in front, its side and above; a
## corridor in full dark by torchlight; the same with its sconce relit, 1 m
## from that sconce's wall and with the torch beside it; a room with its
## hearth ring relit. Checks: every cell of the
## sheet holds the figure (its pixels drawn), the waking frame shows the
## fire warm against the dark (warm pixels, and the frame's darkest share
## navy, not grey), the corridor's dark is dark, and one firelight
## (§EX.6): the torchlit and sconce-lit stone the same amber, and the
## stone right at the torch kept amber by the grade.

var fails := 0
var out_dir := ""
## The firelit wall patches measured ({"torch", "sconce"}: _patch).
var firelit := {}


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


## Shares of the frame: warm (red well over blue), and the darkest 10%'s
## mean colour.
func _stats(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var warm := 0
	var lum: Array = []
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			if c.r > c.b * 1.6 and c.r > 0.25:
				warm += 1
			lum.append([c.r * 0.3 + c.g * 0.59 + c.b * 0.11, c])
	lum.sort_custom(func(a, b): return a[0] < b[0])
	var n := maxi(lum.size() / 10, 1)
	var dark := Color(0, 0, 0)
	for i in n:
		dark += lum[i][1]
	dark = dark / float(n)
	return {"warm": float(warm) / float(lum.size()), "dark": dark, "mean_l": _mean(lum)}


func _mean(lum: Array) -> float:
	var s := 0.0
	for e in lum:
		s += float(e[0])
	return s / maxf(lum.size(), 1.0)


## The mean colour of the frame's patch (fractions of its width and
## height): {"hue" degrees (red 0, -180..180), "chroma" (brightest minus
## darkest channel), "luma", "color"}.
func _patch(img: Image, x0: float, y0: float, x1: float, y1: float) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var sum := Color(0, 0, 0)
	var n := 0
	for y in range(int(y0 * h), int(y1 * h), 2):
		for x in range(int(x0 * w), int(x1 * w), 2):
			sum += img.get_pixel(x, y)
			n += 1
	var c := sum / float(maxi(n, 1))
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var hue := 0.0
	if mx - mn > 1e-5:
		if mx == c.r:
			hue = 60.0 * fposmod((c.g - c.b) / (mx - mn), 6.0)
		elif mx == c.g:
			hue = 60.0 * ((c.b - c.r) / (mx - mn) + 2.0)
		else:
			hue = 60.0 * ((c.r - c.g) / (mx - mn) + 4.0)
	if hue > 180.0:
		hue -= 360.0
	return {"hue": hue, "chroma": mx - mn, "luma": c.r * 0.3 + c.g * 0.59 + c.b * 0.11, "color": c}


## The frame's brightest 5% (luma): {"outside" share of them outside the
## grade's protected orange (look.json grade.protect_hue_deg, chroma under
## protect_chroma's floor), "blue" share bluer than red}.
func _hottest(img: Image) -> Dictionary:
	var g: Dictionary = Tuning.table("look").get("grade", {})
	var band: Array = g.get("protect_hue_deg", [-20.0, 62.0])
	var cmin := float((g.get("protect_chroma", [0.12, 0.25]) as Array)[0])
	var px: Array = []
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			px.append([c.r * 0.3 + c.g * 0.59 + c.b * 0.11, c])
	px.sort_custom(func(a, b): return a[0] > b[0])
	var n := maxi(px.size() / 20, 1)
	var outside := 0
	var blue := 0
	for i in n:
		var c: Color = px[i][1]
		var h := c.h * 360.0
		if h > 180.0:
			h -= 360.0
		if h < float(band[0]) or h > float(band[1]) or maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < cmin:
			outside += 1
		if c.b > c.r:
			blue += 1
	return {"outside": float(outside) / n, "blue": float(blue) / n}


## A torch in hand (from the pack, wherever you stand).
func _torch_in_hand(p: CrawlerPlayer) -> void:
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"


func _run() -> void:
	WorldSave.read_only = true
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	out_dir = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "user://crawler_frames/%d" % seed_v
	out_dir = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked:
		await process_frame
	await _frames(200)
	var p := main.player
	p.set_physics_process(false)
	# Waking, at midday: the hearth's flue lets the day down beside it.
	var world: Node = main.world
	world.days = 13.5
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(10)
	var wake := await _shot("01_wake")
	var st := _stats(wake)
	var d: Color = st.dark
	print("  waking: warm %.3f of the frame, darkest tenth #%s, mean %.3f" % [st.warm, d.to_html(false), st.mean_l])
	ok(float(st.warm) > 0.002, "waking: the hearth is the warm accent in view")
	ok(d.b >= d.r and d.b >= d.g * 0.9, "waking: the dark is navy, not grey (darkest tenth #%s)" % d.to_html(false))
	# The same at midnight: the moonlit shaft dim, the fire the light.
	world.days = 13.0
	await _frames(6)
	await _shot("01b_wake_night")
	world.days = 13.5
	# Looking up the hearth's flue by day.
	var hv: Dictionary = main.lay.vents[0]
	var hm: Vector3 = hv.mouth
	p.spawn_flat(Vector3(hm.x + 1.6, 0.0, hm.z), PI * 0.5, 0.9)
	await _frames(6)
	await _shot("01c_up_the_flue")
	# The fitted stone close (a room wall by torchlight).
	_torch_in_hand(p)
	p.torch.light()
	var room: Dictionary = {}
	for pc in main.lay.pieces:
		if str(pc.kind) == "room" and str(pc.get("room_kind", "")) not in ["hearth", ""]:
			room = pc
			break
	if not room.is_empty():
		var rd: Vector2 = room.dir
		var pv := Delves.perp(rd)
		var spot: Vector2 = (room.c as Vector2) + rd * float(room.len) * 0.5 + pv * (float(room.half) - 1.4)
		p.spawn_flat(Vector3(spot.x, float(room.y0), spot.y), atan2(-pv.x, -pv.y), -0.1)
		await _frames(8)
		await _shot("01d_fitted_stone_%s" % FittedStone.preset_name())
		# The torch's light on the stone (§EX.6): 1 m from the wall, at
		# night (no daylight down the room's shaft), nothing else lit near.
		world.days = 13.0
		var spot1: Vector2 = (room.c as Vector2) + rd * float(room.len) * 0.5 + pv * (float(room.half) - 1.0)
		p.spawn_flat(Vector3(spot1.x, float(room.y0), spot1.y), atan2(-pv.x, -pv.y), -0.05)
		await _frames(8)
		var tw := _patch(await _shot("01e_torch_at_wall"), 0.3, 0.2, 0.62, 0.6)
		firelit["torch"] = tw
		print("  torchlit wall: hue %.1f, chroma %.3f, luma %.3f (#%s)" % [tw.hue, tw.chroma, tw.luma, (tw.color as Color).to_html(false)])
		# Closer, where the stone at the torch blows brightest.
		var spot2: Vector2 = (room.c as Vector2) + rd * float(room.len) * 0.5 + pv * (float(room.half) - 0.45)
		p.spawn_flat(Vector3(spot2.x, float(room.y0), spot2.y), atan2(-pv.x, -pv.y), -0.05)
		await _frames(8)
		var hot := _hottest(await _shot("01f_torch_close"))
		print("  torch close: brightest 5%%: %.3f outside the protected orange, %.3f bluer than red" % [hot.outside, hot.blue])
		ok(float(hot.outside) < 0.02 and float(hot.blue) == 0.0, "the stone right at the torch stays amber: its brightest pixels inside the grade's protected orange (%.1f%% outside), none blue" % (float(hot.outside) * 100.0))
		world.days = 13.5
	p.torch.put_out("stowed")
	# The sheet.
	var r := main.rescuer
	var sheet := r.atlas.get_image()
	sheet.save_png(out_dir.path_join("02_sheet.png"))
	var around := r.around
	var rows := r.rows_deg.size()
	var cw := sheet.get_width() / (around * r.frames)
	var ch := sheet.get_height() / rows
	var empty := 0
	var least := 1 << 30
	for row in rows:
		for col in around * r.frames:
			var n := 0
			for y in range(0, ch, 2):
				for x in range(0, cw, 2):
					if sheet.get_pixel(col * cw + x, row * ch + y).a > 0.5:
						n += 1
			least = mini(least, n)
			if n < 40:
				empty += 1
	ok(empty == 0, "every one of the sheet's %d cells holds the figure (fewest drawn: %d px at half size)" % [around * r.frames * rows, least])
	# The rescuer close: in front, at its side, from above.
	var foot := r.global_position
	var front := Vector3(-sin(r.yaw), 0.0, -cos(r.yaw))
	var side := front.cross(Vector3.UP)
	for v in [["03_rescuer_front", front * 2.6, -0.12], ["04_rescuer_side", side * 2.6, -0.12], ["05_rescuer_above", front * 1.6, -0.75]]:
		var at: Vector3 = foot + (v[1] as Vector3)
		var to: Vector3 = foot - at
		p.spawn_flat(Vector3(at.x, 0.0, at.z), atan2(-to.x, -to.z), float(v[2]))
		await _frames(6)
		await _shot(str(v[0]))
	# A corridor with a sconce, in full dark by torchlight, then relit.
	var t := p.torch
	_torch_in_hand(p)
	t.light()
	var sconce: Node3D = null
	for h in main.fires.holders:
		if str(h.get_meta("fire_holder")) == "sconce":
			sconce = h
			break
	if sconce != null:
		var nrm := sconce.global_basis.z
		var along := nrm.cross(Vector3.UP).normalized()
		var stand := sconce.global_position - Vector3(0.0, float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), 0.0) + nrm * 0.7 - along * 3.5
		p.spawn_flat(stand, atan2(-along.x, -along.z), -0.05)
		await _frames(10)
		await _shot("06_corridor_by_torch")
		# Full dark (§BA, §CJ.5): the torch out, nothing lit near, at
		# midday (a sconce's flue lets in no light, §EV.2).
		t.put_out("stowed")
		await _frames(10)
		var dark_img := await _shot("07_corridor_dark")
		var ds := _stats(dark_img)
		ok(float(ds.mean_l) < 0.06, "with the torch out, the corridor between the lights is full dark (mean %.3f)" % ds.mean_l)
		# Relight its sconce, then put the torch away again.
		var keep_pos := p.global_position
		var keep_yaw := p._yaw
		var swing_at := sconce.global_position - Vector3(0.0, 1.7, 0.0) + nrm * 0.8
		var to_s := sconce.global_position - swing_at
		t.light()
		p.spawn_flat(swing_at, atan2(-to_s.x, -to_s.z), 0.0)
		t.pass_flame()
		for i in 240:
			FireStore.tick(self, 1.0 / 60.0, p.global_position)
		print("  the sconce: %s, %s" % [FireStore.state_of(sconce), t.last_pass])
		t.put_out("stowed")
		p.spawn_flat(keep_pos, keep_yaw, -0.05)
		await _frames(20)
		var lit_img := await _shot("08_corridor_sconce_relit")
		# The relit sconce's light on the stone (§EX.6): 1 m out from the
		# wall, facing it beside the sconce (the flame itself off the
		# patch), the torch away, at night.
		var keep_days2: float = world.days
		world.days = 13.0
		var beside := sconce.global_position - Vector3(0.0, 1.7, 0.0) + nrm * 1.0 + along * 0.9
		var to_w := -nrm
		p.spawn_flat(beside, atan2(-to_w.x, -to_w.z), 0.05)
		await _frames(10)
		var sw := _patch(await _shot("08b_at_relit_sconce"), 0.3, 0.2, 0.62, 0.6)
		firelit["sconce"] = sw
		print("  sconce-lit wall: hue %.1f, chroma %.3f, luma %.3f (#%s)" % [sw.hue, sw.chroma, sw.luma, (sw.color as Color).to_html(false)])
		# And with the torch in hand beside it: one amber, two fires.
		t.light()
		p.spawn_flat(beside - along * 0.9 + nrm * 0.6 + along * 1.6, atan2(along.x, along.z), -0.05)
		await _frames(10)
		await _shot("08c_torch_beside_sconce")
		t.put_out("stowed")
		world.days = keep_days2
		p.spawn_flat(keep_pos, keep_yaw, -0.05)
		await _frames(4)
		var ls := _stats(lit_img)
		ok(FireStore.is_lit(sconce) and float(ls.mean_l) > float(ds.mean_l) + 0.02, "relit, its sconce lights the corridor (mean %.3f against %.3f dark)" % [ls.mean_l, ds.mean_l])
		t.light()
	# A room with its hearth ring relit.
	var ring: Node3D = null
	for h in main.fires.holders:
		if str(h.get_meta("fire_holder")) != "sconce":
			ring = h
			break
	if ring != null:
		var piece: Dictionary = main.lay.pieces[int(ring.get_meta("piece"))]
		var dv: Vector2 = piece.dir
		var stand2 := ring.global_position - Vector3(dv.x, 0.0, dv.y) * 1.0
		var to2 := ring.global_position - stand2
		p.spawn_flat(stand2, atan2(-to2.x, -to2.z), 0.0)
		t.pass_flame()
		for i in 240:
			FireStore.tick(self, 1.0 / 60.0, p.global_position)
		var back := ring.global_position - Vector3(dv.x, 0.0, dv.y) * (float(piece.len) * 0.45)
		var to3 := ring.global_position - back
		p.spawn_flat(Vector3(back.x, float(piece.y0), back.z), atan2(-to3.x, -to3.z), -0.15)
		await _frames(20)
		await _shot("09_room_relit_%s" % str(piece.room_kind))
	# The heart.
	if main.lay.has("heart"):
		var hpc: Dictionary = main.lay.pieces[int(main.lay.heart)]
		var hd: Vector2 = hpc.dir
		var hc: Vector2 = (hpc.c as Vector2) + hd * float(hpc.len) * 0.3
		p.spawn_flat(Vector3(hc.x, float(hpc.y0), hc.y), atan2(-hd.x, -hd.y), -0.2)
		await _frames(20)
		await _shot("10_heart_by_torch")
	# One firelight (§EX.6): the torchlit and the sconce-lit stone the same
	# amber, both inside the grade's orange band.
	if firelit.has("torch") and firelit.has("sconce"):
		var ht := float(firelit.torch.hue)
		var hs := float(firelit.sconce.hue)
		ok(absf(ht - hs) <= 8.0 and ht >= -20.0 and ht <= 62.0 and hs >= -20.0 and hs <= 62.0, "one firelight: the torchlit wall (hue %.1f) and the sconce-lit wall (hue %.1f) are the same amber, inside -20..62" % [ht, hs])
	print("[crawler_frames] %s" % out_dir)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
