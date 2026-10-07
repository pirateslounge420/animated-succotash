extends SceneTree
## The crawler's visual check (design 6 Oct §ET.11; §CA's walkabout, for
## Torchfire 1): renders the first slice and saves frames, once, at the
## end of a pass (no screenshots between steps):
##   SEED=7 xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/crawler_frames.gd
## Frames go to OUT (default user://crawler_frames/<seed>/): waking by the
## hearth (noon and midnight), up the hearth's shaft, a fitted-stone wall
## by torchlight, the torch 1 m and 0.45 m from a wall (§EX.6); a sheet
## baked with FigureSprite (kept for creatures and bosses); circling the
## one who found you, live in 3D (§FH): from in front, its left, behind,
## its right and close; a corridor by torchlight, then with the torch
## smothered (F, §FC.3); a long view down a cold corridor with the torch
## smothered, in the old full dark (the half-dark off) and in the
## half-dark (§FC.4), and by torchlight with the half-dark off and on; the
## corridor with its sconce relit, 1 m from that sconce's wall and with
## the torch beside it; a room with its hearth ring relit; the red ring
## after one hit and after two (§FD, §FJ.3: its depth in pixels at 480
## lines, darker and deeper on two, the heart beating from hit 1).
## Checks: every cell of the sheet holds the figure (its pixels drawn),
## the rescuer's chest brighter and warmer from in front (past the fire)
## than from behind, its back navy, the waking frame shows the fire warm
## against the dark (warm pixels, and the frame's darkest share navy, not
## grey), the smothered corridor still dark, the half-dark (the wall
## pixels about 3 m off a readable step over the frame's black, about
## 15 m off at it, and blue), the torchlit frame the same with the
## half-dark on as off, and one firelight (§EX.6): the torchlit and
## sconce-lit stone the same amber, and the stone right at the torch kept
## amber by the grade.
## The crosshair (§EX.7, Reticle), in the frames as you see it: its arms'
## pixels round the frame's middle pixel, sized per hud.json, at the 480
## preset (waking in the hearth room) and the 270 one (01g); nothing else
## drawn over the graded frame anywhere (the grade's dither leaves every
## pixel of the picture on its 5-bit grid, so a pixel off it is the
## HUD's: no words, no meter, no glow); on the dark corridor's navy wall
## (07b) and none there with the Settings switch off (07c), the dark round
## it the same as without it; and readable (WCAG contrast): its arms
## against their dark edge wherever it sat (over the hearth's fire, down
## the dark corridor, on the dark wall, on amber stone by the torch), and
## against the navy by themselves. The scene's own
## numbers (the stats and patches) leave the crosshair's pixels out. The
## run sets the 480 preset and the switch on, and puts the player's
## settings back at the end.

var fails := 0
var out_dir := ""
## The firelit wall patches measured ({"torch", "sconce"}: _patch).
var firelit := {}
## The crosshair's readings ({"wake", "wake_270", "amber", "amber_close",
## "corridor", "navy", "navy_off"}: _reticle_read).
var cross := {}


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
	var hud := _hud_rect(img)
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			if hud.has_point(Vector2i(x, y)):
				continue
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
	var hud := _hud_rect(img)
	for y in range(int(y0 * h), int(y1 * h), 2):
		for x in range(int(x0 * w), int(x1 * w), 2):
			if hud.has_point(Vector2i(x, y)):
				continue
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
	var hud := _hud_rect(img)
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if hud.has_point(Vector2i(x, y)):
				continue
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


## The crosshair's box (its arms and their edge, Reticle.cells) in a
## frame `img`'s size: the scene's numbers leave it out.
func _hud_rect(img: Image) -> Rect2i:
	var cl := Reticle.cells(img.get_size())
	var box := Rect2i()
	for i in (cl.arms as Array).size():
		box = cl.arms[i] if i == 0 else box.merge(cl.arms[i])
	return box.grow(1)


## The preset of `lines` lines (look.json render.presets).
func _preset_of(lines: int) -> String:
	for nm in Display.presets():
		if int(Display.presets()[nm]) == lines:
			return str(nm)
	return "default"


## Every pixel of the graded picture is on the grade's grid (look.json
## retro: the dither at 1 floors each channel to 2^bits - 1 steps), so a
## pixel off it was drawn over the frame: the HUD's.
func _dither_full() -> bool:
	return float(Tuning.section("look", "retro").get("dither", 0.0)) >= 0.999


static var _levels := pow(2.0, float(Tuning.section("look", "retro").get("bits_per_channel", 5))) - 1.0


func _on_grid(v: float) -> bool:
	var s := v * _levels
	return absf(s - roundf(s)) * 255.0 / _levels <= 1.0


## The mean WCAG luminance of `img`'s pixels in `at` (a set of Vector2i).
func _mean_lum(img: Image, at: Dictionary) -> float:
	var s := 0.0
	for p: Vector2i in at:
		var c := img.get_pixel(p.x, p.y).srgb_to_linear()
		s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return s / maxf(at.size(), 1.0)


## The crosshair in a frame (design §EX.7; Reticle.cells for its size and
## the preset now): {"want": its arms' pixels, "found": pixels of its
## colour anywhere, "at": of them, on its arms, "drawn": pixels off the
## grade's grid (drawn over the frame) anywhere, "stray": of them, outside
## the crosshair, "l_arm", "l_edge", "l_out": the mean WCAG luminance of
## its arms, their dark edge and the two pixels round that (the frame it
## sits on), "edge_cr", "out_cr", "edge_out_cr": the contrasts between
## them, "out_luma": that frame's mean luma}.
func _reticle_read(img: Image) -> Dictionary:
	var f := img.get_size()
	var cl := Reticle.cells(f)
	var col := Reticle.color()
	var arm := {}
	for r: Rect2i in cl.arms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				arm[Vector2i(x, y)] = true
	var edge := {}
	for r: Rect2i in cl.edge:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				edge[Vector2i(x, y)] = true
	var out := {}
	var front: Array = edge.keys()
	for ring in 2:
		var next: Array = []
		for p: Vector2i in front:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := p + Vector2i(dx, dy)
					if not arm.has(q) and not edge.has(q) and not out.has(q):
						out[q] = true
						next.append(q)
		front = next
	var grid := _dither_full()
	var tol := 1.5 / 255.0
	var found := 0
	var at := 0
	var drawn := 0
	var stray := 0
	for y in f.y:
		for x in f.x:
			var c := img.get_pixel(x, y)
			var p := Vector2i(x, y)
			if absf(c.r - col.r) <= tol and absf(c.g - col.g) <= tol and absf(c.b - col.b) <= tol:
				found += 1
				if arm.has(p):
					at += 1
			if grid and not (_on_grid(c.r) and _on_grid(c.g) and _on_grid(c.b)):
				drawn += 1
				if not arm.has(p) and not edge.has(p):
					stray += 1
	var la := _mean_lum(img, arm)
	var le := _mean_lum(img, edge)
	var lo := _mean_lum(img, out)
	var luma := 0.0
	for p: Vector2i in out:
		var c := img.get_pixel(p.x, p.y)
		luma += c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	var cr := func(a: float, b: float) -> float: return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
	return {"size": f, "grid": grid, "want": arm.size(), "found": found, "at": at, "drawn": drawn, "stray": stray, "l_arm": la, "l_edge": le, "l_out": lo, "edge_cr": cr.call(la, le), "out_cr": cr.call(la, lo), "edge_out_cr": cr.call(le, lo), "out_luma": luma / maxf(out.size(), 1.0)}


func _say_cross(what: String, r: Dictionary) -> void:
	var f: Vector2i = r.size
	print("  crosshair, %s (%dx%d): %d of its %d arm pixels in its colour, where they belong (%d of its colour in the frame); %d pixels drawn over the grade, %d outside it; luminance arms %.3f, edge %.3f, round it %.3f: arms against edge %.1f:1, against the frame %.1f:1, edge against the frame %.1f:1" % [what, f.x, f.y, r.at, r.want, r.found, r.drawn, r.stray, r.l_arm, r.l_edge, r.l_out, r.edge_cr, r.out_cr, r.edge_out_cr])


## The frame's wall pixels from `lo` to `hi` m off (the half-dark, §FC.4):
## a ray from the eye through the middle of each 2x2 block of the frame
## (so the dither's 4x4 pattern averages out); a wall (its normal within
## 0.3 of level) that far adds the block's four pixels. The crosshair's
## box is left out. {"n" pixels, "luma", "hue" (0-360, blue about 240),
## "color"}.
func _wall_band(img: Image, cam: Camera3D, lo: float, hi: float, exclude: Array) -> Dictionary:
	var vs := cam.get_viewport().get_visible_rect().size
	var sx := vs.x / img.get_width()
	var sy := vs.y / img.get_height()
	var space := cam.get_world_3d().direct_space_state
	var hud := _hud_rect(img).grow(1)
	var sum := Color(0, 0, 0)
	var n := 0
	for y in range(0, img.get_height() - 1, 2):
		for x in range(0, img.get_width() - 1, 2):
			if hud.has_point(Vector2i(x, y)) or hud.has_point(Vector2i(x + 1, y + 1)):
				continue
			var sp := Vector2((x + 1.0) * sx, (y + 1.0) * sy)
			var from := cam.project_ray_origin(sp)
			var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(sp) * (hi + 2.0), PropCollision.WORLD_LAYER)
			q.exclude = exclude
			var h := space.intersect_ray(q)
			if h.is_empty() or absf((h.normal as Vector3).y) > 0.3:
				continue
			var d := from.distance_to(h.position)
			if d < lo or d > hi:
				continue
			for k in 4:
				sum += img.get_pixel(x + (k & 1), y + (k >> 1))
			n += 4
	var c := sum / float(maxi(n, 1))
	return {"n": n, "luma": c.r * 0.3 + c.g * 0.59 + c.b * 0.11, "hue": c.h * 360.0, "color": c}


## The whole frame's mean luma (every pixel but the crosshair's box).
func _mean_luma(img: Image) -> float:
	var hud := _hud_rect(img)
	var s := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if hud.has_point(Vector2i(x, y)):
				continue
			var c := img.get_pixel(x, y)
			s += c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			n += 1
	return s / float(maxi(n, 1))


## A long view down a cold corridor (§FC.4's frames): a corridor's end,
## looking along it, with 16-30 m clear ahead (a far wall about 15 m off
## and more) and the hearth over 14 m away: [feet, yaw], or [] if none.
func _long_view(main: CrawlerMain) -> Array:
	var p := main.player
	var space := p.get_world_3d().direct_space_state
	var hp: Vector3 = main.fires.hearth.global_position
	for pc in main.lay.pieces:
		if str(pc.kind) != "corridor":
			continue
		for end in 2:
			var dv: Vector2 = pc.dir
			var along := 0.4 if end == 0 else float(pc.len) - 0.4
			var at2: Vector2 = (pc.c as Vector2) + dv * along
			var face := dv if end == 0 else -dv
			var fy := Delves.floor_of(pc, along)
			var eye := Vector3(at2.x, fy + 1.6, at2.y)
			var q := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(face.x, 0.0, face.y) * 40.0, PropCollision.WORLD_LAYER)
			q.exclude = [p.get_rid()]
			var h := space.intersect_ray(q)
			var clear := 40.0 if h.is_empty() else eye.distance_to(h.position)
			if clear >= 16.0 and clear <= 30.0 and eye.distance_to(hp) > 14.0:
				return [Vector3(at2.x, fy, at2.y), atan2(-face.x, -face.y)]
	return []


## Wait until the half-dark has settled where it's going (off with the
## torch lit or a flame near, else fully on; at most 600 frames), then a
## few frames more.
func _settle(main: CrawlerMain) -> void:
	var hd := main.half_dark
	for i in 600:
		var want := 0.0 if not hd.enabled or main.player.torch.lit() or hd.flame_near() else 1.0
		if hd.strength == want:
			break
		await process_frame
	await _frames(6)


## The readable floor (§FC.4's check; picked by Claude Code): the wall
## pixels about 3 m off at least this much luma over the frame's black
## (the grade's navy floor, look.json retro.colors.shadow_floor, which the
## old full dark sits at): about two of the frame's 5-bit steps of green,
## a wall you can make out.
const READABLE := 0.02


## The half-dark (design 6 Oct §FC.4; HalfDark, crawler.json dark): a long
## view down a cold corridor at midnight with the torch smothered, first
## with the half-dark off (the old full dark: the frame's black), then on;
## the wall pixels by how far off they are. Then the torch lit, the
## half-dark off and on: the same frame. Leaves you where you stood, the
## torch out.
func _half_dark(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var hd := main.half_dark
	var v := _long_view(main)
	ok(not v.is_empty(), "a long view down a cold corridor (16-30 m clear ahead, the hearth over 14 m off)")
	if v.is_empty():
		return
	var keep_pos := p.global_position
	var keep_yaw := p._yaw
	var keep_days: float = main.world.days
	main.world.days = 13.0
	p.spawn_flat(v[0], float(v[1]), -0.05)
	var cam := p.get_viewport().get_camera_3d()
	var ex: Array = [p.get_rid()]
	# The old full dark: the frame's black.
	t.douse()
	hd.enabled = false
	await _settle(main)
	var off_img := await _shot("07d_long_full_dark")
	var black := float(_wall_band(off_img, cam, 1.0, 30.0, ex).luma)
	# The half-dark.
	hd.enabled = true
	await _settle(main)
	var img := await _shot("07e_long_half_dark")
	var got: Array = []
	var line := "  the half-dark (fill_energy %.1f, falloff %.2f, readable_m %.0f, black_m %.0f; the frame's black %.3f):" % [float(HalfDark.DARK.get("fill_energy", 0.0)), float(HalfDark.DARK.get("falloff", 0.0)), HalfDark.readable_m(), HalfDark.black_m(), black]
	for b in [[2.5, 3.5], [4.5, 5.5], [7.5, 8.5], [13.5, 16.5]]:
		var r := _wall_band(img, cam, b[0], b[1], ex)
		got.append(r)
		line += "  %.0f m: luma %.3f #%s hue %.0f (%d px)" % [(float(b[0]) + float(b[1])) * 0.5, r.luma, (r.color as Color).to_html(false), r.hue, r.n]
	print(line)
	var near: Dictionary = got[0]
	var far: Dictionary = got[3]
	var nc: Color = near.color
	ok(int(near.n) > 0 and float(near.luma) >= black + READABLE, "smothered in a cold corridor, the walls about 3 m off read: luma %.3f, %.3f over the frame's black %.3f (readable floor %.2f)" % [near.luma, float(near.luma) - black, black, READABLE])
	ok(int(far.n) > 0 and float(far.luma) <= black + 0.005, "the walls about 15 m off are at the black (luma %.3f)" % far.luma)
	ok(float(near.hue) >= 200.0 and float(near.hue) <= 260.0 and nc.b > nc.g * 2.0, "the near walls are navy, never grey (hue %.0f, #%s)" % [near.hue, nc.to_html(false)])
	# The torch lit: the half-dark adds nothing, so the frame is the one
	# before it.
	t.light()
	hd.enabled = false
	await _settle(main)
	var lit_off := await _shot("07f_long_by_torch_no_half_dark")
	hd.enabled = true
	await _settle(main)
	var lit_on := await _shot("07g_long_by_torch")
	var worst := absf(_mean_luma(lit_on) - _mean_luma(lit_off))
	for b in [[2.5, 3.5], [7.5, 8.5], [13.5, 16.5]]:
		worst = maxf(worst, absf(float(_wall_band(lit_on, cam, b[0], b[1], ex).luma) - float(_wall_band(lit_off, cam, b[0], b[1], ex).luma)))
	ok(worst < 0.003 and hd.strength == 0.0, "by torchlight the frame is as it was without the half-dark (mean %.4f against %.4f; worst difference %.4f)" % [_mean_luma(lit_on), _mean_luma(lit_off), worst])
	t.douse()
	main.world.days = keep_days
	p.spawn_flat(keep_pos, keep_yaw, -0.05)
	await _settle(main)


## A torch in hand (from the pack, wherever you stand).
func _torch_in_hand(p: CrawlerPlayer) -> void:
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"


## Real seconds (the fires burn on the physics clock, which keeps to it).
func _wait_s(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## Fire pots (design §FA.3, prompt 60), at night with the torch away: a tar
## patch burning on a dark corridor's floor, a light-oil burst in a dark
## room at its height, and a pot lit in the left hand with the aim's arc.
## Checks: the patch and the burst light the dark, in the hearth's amber
## (the grade's orange band).
func _pots(main: CrawlerMain) -> void:
	var p := main.player
	var fp := main.fire_pots
	var world: Node = main.world
	var keep_days: float = world.days
	world.days = 13.0
	p.torch.put_out("stowed")
	var lit_in := {}
	for h in main.fires.holders:
		if FireStore.is_lit(h):
			lit_in[int(h.get_meta("piece"))] = true
	var cor: Dictionary = {}
	var room: Dictionary = {}
	for pc in main.lay.pieces:
		if lit_in.has(int(pc.id)):
			continue
		if cor.is_empty() and str(pc.kind) == "corridor" and float(pc.len) >= 7.0:
			cor = pc
		elif room.is_empty() and str(pc.kind) == "room" and not str(pc.get("room_kind", "")) in ["hearth", "heart"] and float(pc.len) >= 7.0:
			room = pc
	if not cor.is_empty():
		var d: Vector2 = cor.dir
		var s2: Vector2 = (cor.c as Vector2) + d * 0.8
		p.spawn_flat(Vector3(s2.x, Delves.floor_of(cor, 0.8), s2.y), atan2(-d.x, -d.y), -0.2)
		# (The half-dark settled first, §FC.4, so before and after are like
		# for like.)
		await _settle(main)
		var before := _stats(await _shot("14a_corridor_before_the_pot"))
		var f2: Vector2 = (cor.c as Vector2) + d * 4.0
		fp.burst(Vector3(f2.x, Delves.floor_of(cor, 4.0) + 0.25, f2.y), "tar", null, Vector3.UP)
		await _wait_s(1.5)
		var img := await _shot("14_tar_patch")
		var st := _stats(img)
		var pt := _patch(img, 0.3, 0.45, 0.7, 0.85)
		print("  tar patch: warm %.3f of the frame (%.3f before), mean %.3f (%.3f before); its stretch of floor hue %.1f, chroma %.3f" % [st.warm, before.warm, st.mean_l, before.mean_l, pt.hue, pt.chroma])
		ok(float(st.warm) > float(before.warm) + 0.01 and float(st.mean_l) > float(before.mean_l) + 0.01 and float(pt.hue) >= -20.0 and float(pt.hue) <= 62.0, "a tar patch burns on the dark corridor's floor and lights it in the hearth's amber (hue %.1f)" % pt.hue)
	if not room.is_empty():
		var d3: Vector2 = room.dir
		var s3: Vector2 = (room.c as Vector2) + d3 * 1.0
		p.spawn_flat(Vector3(s3.x, float(room.y0), s3.y), atan2(-d3.x, -d3.y), 0.0)
		await _settle(main)
		var before3 := _stats(await _shot("15a_room_before_the_burst"))
		var b3: Vector2 = (room.c as Vector2) + d3 * minf(5.0, float(room.len) - 1.0)
		fp.burst(Vector3(b3.x, float(room.y0) + 1.3, b3.y), "light_oil", null, Vector3.UP)
		await _wait_s(0.2)
		var img3 := await _shot("15_pot_burst")
		var st3 := _stats(img3)
		var mid := _patch(img3, 0.35, 0.25, 0.65, 0.75)
		print("  light-oil burst: warm %.3f of the frame (%.3f before), mean %.3f (%.3f before); its middle hue %.1f, luma %.3f" % [st3.warm, before3.warm, st3.mean_l, before3.mean_l, mid.hue, mid.luma])
		ok(float(st3.warm) > float(before3.warm) + 0.05 and float(mid.hue) >= -20.0 and float(mid.hue) <= 62.0, "a light-oil burst fills the dark room with amber fire (hue %.1f, warm %.3f)" % [mid.hue, st3.warm])
		await _wait_s(1.0)
	# A pot lit in the left hand, charged halfway: the hands, the wick, the
	# arc of the lob.
	_torch_in_hand(p)
	p.torch.light()
	if not cor.is_empty():
		var d4: Vector2 = cor.dir
		var s4: Vector2 = (cor.c as Vector2) + d4 * 0.8
		p.spawn_flat(Vector3(s4.x, Delves.floor_of(cor, 0.8), s4.y), atan2(-d4.x, -d4.y), -0.1)
	fp.give("tar")
	var pot: Dictionary = fp.pots_carried()[-1]
	fp.left = pot
	# Held (no mouse to capture here): let go and it would be thrown.
	Bow.need_capture = false
	Input.action_press("shoot")
	fp._catch(pot)
	await _wait_s(0.4)
	fp.charge = 0.5
	await _shot("16_pot_lit_in_hand")
	fp._set_state("idle")
	fp.left = {}
	Input.action_release("shoot")
	Bow.need_capture = true
	fp._remove(pot)
	p.torch.put_out("stowed")
	world.days = keep_days


## Is `p` (scene) inside room piece `pc`, `margin` m clear of its walls?
func _in_room(pc: Dictionary, p: Vector3, margin: float) -> bool:
	var aa := Delves.along_across(pc, Vector2(p.x, p.z))
	return aa.x >= margin and aa.x <= float(pc.len) - margin and absf(aa.y) <= float(pc.half) - margin


func _run() -> void:
	WorldSave.read_only = true
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	out_dir = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "user://crawler_frames/%d" % seed_v
	out_dir = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# The 480 preset and the crosshair on for the run; the player's own
	# settings go back at the end.
	var keep := {}
	for key in ["display.preset", "hud.reticle"]:
		keep[key] = Settings.get_value(key) if Settings.has(key) else null
	Settings.set_value("display.preset", _preset_of(480))
	Settings.set_bool("hud.reticle", true)
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
	# The crosshair (§EX.7) in the hearth room at 480 lines, then the same
	# view at 270 (the painted preset).
	cross["wake"] = _reticle_read(wake)
	_say_cross("waking, 480 lines", cross.wake)
	Settings.set_value("display.preset", _preset_of(270))
	Display.apply()
	await _frames(8)
	cross["wake_270"] = _reticle_read(await _shot("01g_wake_270_lines"))
	_say_cross("waking, 270 lines", cross.wake_270)
	Settings.set_value("display.preset", _preset_of(480))
	Display.apply()
	await _frames(8)
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
		var img_e := await _shot("01e_torch_at_wall")
		var tw := _patch(img_e, 0.3, 0.2, 0.62, 0.6)
		firelit["torch"] = tw
		cross["amber"] = _reticle_read(img_e)
		_say_cross("on the torchlit wall, 1 m", cross.amber)
		print("  torchlit wall: hue %.1f, chroma %.3f, luma %.3f (#%s)" % [tw.hue, tw.chroma, tw.luma, (tw.color as Color).to_html(false)])
		# Closer, where the stone at the torch blows brightest.
		var spot2: Vector2 = (room.c as Vector2) + rd * float(room.len) * 0.5 + pv * (float(room.half) - 0.45)
		p.spawn_flat(Vector3(spot2.x, float(room.y0), spot2.y), atan2(-pv.x, -pv.y), -0.05)
		await _frames(8)
		var img_f := await _shot("01f_torch_close")
		var hot := _hottest(img_f)
		cross["amber_close"] = _reticle_read(img_f)
		_say_cross("on the torchlit wall, 0.45 m", cross.amber_close)
		print("  torch close: brightest 5%%: %.3f outside the protected orange, %.3f bluer than red" % [hot.outside, hot.blue])
		ok(float(hot.outside) < 0.02 and float(hot.blue) == 0.0, "the stone right at the torch stays amber: its brightest pixels inside the grade's protected orange (%.1f%% outside), none blue" % (float(hot.outside) * 100.0))
		world.days = 13.5
	p.torch.put_out("stowed")
	# FigureSprite's bake, kept for creatures and bosses (§ET.8,
	# folk_3d.sprites_stay_for): the shared rig with the rescuer's head,
	# standing, baked to a sheet (one idle frame) as the rescuer once was.
	var r := main.rescuer
	var fig := CloakedFigure.build(1.62, Color("4f5e2c"), Color("a8792e"))
	var fbody: PlayerBody = fig.root
	var holder := Node3D.new()
	holder.add_child(fbody)
	fbody.ready.connect(func(): fbody.set_beast(r.beast), CONNECT_ONE_SHOT)
	var sheet := await FigureSprite.bake(main, holder, 1.62, 96, 1, Callable())
	sheet.save_png(out_dir.path_join("02_sheet.png"))
	var around := int(FigureSprite.SP.get("around", 8))
	var rows := (FigureSprite.SP.get("rows_deg", [-25, 0, 30]) as Array).size()
	var cw := sheet.get_width() / around
	var ch := sheet.get_height() / rows
	var empty := 0
	var least := 1 << 30
	for row in rows:
		for col in around:
			var n := 0
			for y in range(0, ch, 2):
				for x in range(0, cw, 2):
					if sheet.get_pixel(col * cw + x, row * ch + y).a > 0.5:
						n += 1
			least = mini(least, n)
			if n < 40:
				empty += 1
	ok(empty == 0, "FigureSprite's bake still works: every one of a sheet's %d cells holds the figure (fewest drawn: %d px at half size)" % [around * rows, least])
	# Circling the hearth at 480 (§FH): the one who found you, live in 3D,
	# from in front of it (past the fire), its left, behind it and its right,
	# then close in front; each a beat for its hood to turn (it looks to you
	# while you're in front of it). On its chest: amber from the fire's side,
	# navy, never grey, from behind.
	var hr: Dictionary = main.lay.pieces[0]
	var foot := r.global_position
	var front := r.front()
	var right := front.cross(Vector3.UP)
	var cam := get_root().get_camera_3d()
	var chests := {}
	for v in [["03a_rescuer_front", 0.45, 2.6, -0.28], ["03b_rescuer_left", -PI * 0.5, 2.2, -0.3], ["03c_rescuer_back", PI, 2.0, -0.32], ["03d_rescuer_right", PI * 0.5, 2.2, -0.3], ["03e_rescuer_close", 0.2, 1.35, -0.5]]:
		var a := float(v[1])
		var dir := front * cos(a) + right * sin(a)
		var dist := float(v[2])
		# Inside the room, clear of its walls.
		while dist > 1.0 and not _in_room(hr, foot + dir * dist, 0.6):
			dist -= 0.1
		var at: Vector3 = foot + dir * dist
		p.spawn_flat(Vector3(at.x, 0.0, at.z), atan2(dir.x, dir.z), float(v[3]))
		await _frames(12)
		var img := await _shot(str(v[0]))
		var c2 := cam.unproject_position(foot + Vector3(0.0, 0.78, 0.0)) / get_root().get_visible_rect().size
		var chest := _patch(img, c2.x - 0.012, c2.y - 0.03, c2.x + 0.012, c2.y + 0.03)
		var col: Color = chest.color
		print("  %s (%.1f m): its chest #%s (hue %.0f, luma %.3f)" % [v[0], dist, col.to_html(false), chest.hue, chest.luma])
		chests[str(v[0])] = chest
	# Lit by the fire on the side that faces it, its cloak's own colour in
	# the amber (an indigo cloak goes maroon, a yellow one gold); its back
	# in the dark's navy.
	var fc: Color = chests["03a_rescuer_front"].color
	var bc: Color = chests["03c_rescuer_back"].color
	ok(float(chests["03a_rescuer_front"].luma) > float(chests["03c_rescuer_back"].luma) * 1.8 and fc.r / maxf(fc.b, 0.01) > bc.r / maxf(bc.b, 0.01) + 0.5, "the hearth lights it from in front: brighter and warmer than its back (front #%s, back #%s)" % [fc.to_html(false), bc.to_html(false)])
	ok(bc.b >= bc.r and bc.b >= bc.g, "from behind, its back to the fire: in shade, navy, never grey (#%s)" % bc.to_html(false))
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
		# The torch smothered (F, §FC.3), nothing lit near, at midday (a
		# sconce's flue lets in no light, §EV.2): still dark between the
		# lights (§BA, §CJ.5), no longer blind near you (§FC.4).
		t.douse()
		await _settle(main)
		var dark_img := await _shot("07_corridor_doused")
		var ds := _stats(dark_img)
		ok(not t.lit() and t.in_hand() and float(ds.mean_l) < 0.12, "smothered, the torch is out and still in hand, and the corridor between the lights is still dark (mean %.3f)" % ds.mean_l)
		# The crosshair down the dark corridor (on the far hearth's lit
		# doorway), then on the corridor's own dark wall a step from the
		# cold sconce: navy, with the Settings switch on and off.
		cross["corridor"] = _reticle_read(dark_img)
		_say_cross("down the dark corridor", cross.corridor)
		var at_wall := sconce.global_position - Vector3(0.0, float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), 0.0) + nrm * 1.0 - along * 2.0
		p.spawn_flat(at_wall, atan2(nrm.x, nrm.z), 0.0)
		await _frames(10)
		cross["navy"] = _reticle_read(await _shot("07b_dark_wall"))
		_say_cross("on the dark corridor's wall", cross.navy)
		Settings.set_bool("hud.reticle", false)
		await _frames(6)
		cross["navy_off"] = _reticle_read(await _shot("07c_dark_wall_switch_off"))
		_say_cross("on the dark wall, the switch off", cross.navy_off)
		Settings.set_bool("hud.reticle", true)
		p.spawn_flat(stand, atan2(-along.x, -along.z), -0.05)
		await _frames(6)
		await _half_dark(main)
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
	await _pots(main)
	# One firelight (§EX.6): the torchlit and the sconce-lit stone the same
	# amber, both inside the grade's orange band.
	if firelit.has("torch") and firelit.has("sconce"):
		var ht := float(firelit.torch.hue)
		var hs := float(firelit.sconce.hue)
		ok(absf(ht - hs) <= 8.0 and ht >= -20.0 and ht <= 62.0 and hs >= -20.0 and hs <= 62.0, "one firelight: the torchlit wall (hue %.1f) and the sconce-lit wall (hue %.1f) are the same amber, inside -20..62" % [ht, hs])
	# The crosshair (§EX.7): where and how big, nothing else drawn, off
	# with the switch, no light of its own, readable.
	for key in ["wake", "wake_270"]:
		if not cross.has(key):
			continue
		var rc: Dictionary = cross[key]
		var fs: Vector2i = rc.size
		ok(int(rc.want) > 0 and int(rc.at) == int(rc.want) and (not bool(rc.grid) or int(rc.found) == int(rc.want)), "%d lines (%dx%d): the crosshair's %d arm pixels in its colour round the frame's middle pixel, sized per hud.json, and none of its colour anywhere else (%d found)" % [fs.y, fs.x, fs.y, rc.want, rc.found])
		if bool(rc.grid):
			ok(int(rc.stray) == 0, "%d lines: nothing else is drawn over the graded frame: no words, no meter, no glow round the crosshair (%d pixels off the grade's grid outside it)" % [fs.y, rc.stray])
	if cross.has("navy") and cross.has("navy_off"):
		var on: Dictionary = cross.navy
		var off: Dictionary = cross.navy_off
		ok(int(off.found) == 0 and (not bool(off.grid) or int(off.drawn) == 0), "with the Settings switch off, no crosshair, and nothing at all drawn over the frame (%d of its colour, %d pixels off the grid)" % [off.found, off.drawn])
		ok(absf(float(on.out_luma) - float(off.out_luma)) < 0.01, "it gives off no light: the dark wall round it is the same with it as without it (luma %.4f against %.4f)" % [on.out_luma, off.out_luma])
		ok(float(on.out_cr) >= 3.0, "readable on the dark's navy: its arms %.1f:1 against the dark wall by themselves (WCAG's 3:1 for a mark)" % float(on.out_cr))
	# Readable wherever it sat: its arms against their dark edge (WCAG's
	# 3:1), over the brightest things in the crawler too.
	var where := {"wake": "over the hearth's fire", "corridor": "down the dark corridor, on the far hearth's doorway", "navy": "on the dark corridor's wall", "amber": "on amber stone 1 m from the torch", "amber_close": "on amber stone 0.45 m from the torch"}
	for key in where:
		if not cross.has(key):
			continue
		var rc: Dictionary = cross[key]
		ok(float(rc.edge_cr) >= 3.0, "readable %s: its arms %.1f:1 against their dark edge, the edge %.1f:1 against what's behind it (the arms alone against that: %.1f:1)" % [where[key], rc.edge_cr, rc.edge_out_cr, rc.out_cr])
	await _harm_ring(main, p)
	for key in keep:
		if keep[key] == null:
			Settings.erase(key)
		else:
			Settings.set_value(key, keep[key])
	print("[crawler_frames] %s" % out_dir)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Harm's ring (design §FD, §FJ.3; queue 56), after one hit and after two:
## measured in a cold corridor in full dark (the torch out, so no flicker
## changes the frame but the ring), where it reaches in from the middle of
## the left and top edges (the frame against the unhurt one) and its rim
## colour (darker on two); and seen in the hearth room by torchlight. The
## heartbeat plays from hit 1.
func _harm_ring(main: CrawlerMain, p: CrawlerPlayer) -> void:
	var harm := main.get("harm") as Harm
	var made := false
	if harm == null:
		# Until the boss's pass (queue 49) puts Harm in the crawler.
		harm = Harm.new()
		harm.name = "Harm"
		main.add_child(harm)
		harm.setup(p, main.post, null)
		made = true
	harm.set_process(false)
	harm.reset()
	# A cold corridor: 3.5 m along from a sconce nobody has lit.
	var cold: Node3D = null
	for h in main.fires.holders:
		if str(h.get_meta("fire_holder")) == "sconce" and not FireStore.is_lit(h):
			cold = h
			break
	if cold == null:
		ok(false, "harm's ring: a cold corridor to measure it in")
		return
	var nrm := cold.global_basis.z
	var along := nrm.cross(Vector3.UP).normalized()
	var dark_at := cold.global_position - Vector3(0.0, float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), 0.0) + nrm * 0.7 - along * 3.5
	_torch_in_hand(p)
	var w: Array = main.lay.wake
	var shots := {}
	p.torch.put_out("stowed")
	p.spawn_flat(dark_at, atan2(-along.x, -along.z), -0.05)
	# (The half-dark settled before each dark shot, §FC.4, so the hit
	# frames and the unhurt one differ only by the ring.)
	await _settle(main)
	var none := await _shot("11_harm_none_dark")
	for n in [1, 2]:
		harm.hit("creature:giant snake")
		Engine.time_scale = 1.0
		for i in 12:
			harm.tick(0.1)
		p.torch.put_out("stowed")
		p.spawn_flat(dark_at, atan2(-along.x, -along.z), -0.05)
		await _settle(main)
		shots[n] = await _shot("1%d_harm_hit_%d_dark" % [n + 1, n])
		print("  hit %d: the heart %s at %.0f bpm (%d beats so far), the ring at level %.2f" % [n, "beating" if harm.heart else "still", harm.heart_bpm, harm.beats, harm.ring])
		if n == 1:
			ok(harm.heart and harm.beats > 0, "the heartbeat plays from hit 1 (%d beats in its first 1.2 s)" % harm.beats)
		# The same by torchlight, at the hearth.
		p.torch.light()
		p.spawn_flat(w[0], float(w[1]), -0.25)
		await _frames(8)
		await _shot("1%db_harm_hit_%d_at_the_hearth" % [n + 1, n])
	var scale := 480.0 / float(none.get_height())
	var rim := {}
	var depth := {}
	for n in [1, 2]:
		var img: Image = shots[n]
		var dl := _ring_depth(img, none, true) * scale
		var dt := _ring_depth(img, none, false) * scale
		depth[n] = dl
		rim[n] = _patch(img, 0.0, 0.45, 0.012, 0.55)
		var rc: Color = rim[n].color
		print("  hit %d's ring: %.0f px deep at the left edge, %.0f px at the top (at 480 lines; the frame %dx%d), rim #%s (luma %.3f)" % [n, dl, dt, none.get_width(), none.get_height(), rc.to_html(false), rim[n].luma])
		ok(dl > 4.0 and rc.r > rc.g * 1.5 and rc.r > rc.b * 1.5, "hit %d: the red ring is on the frame's edge (%.0f px deep)" % [n, dl])
	ok(float(depth[2]) > float(depth[1]) and float(rim[2].luma) < float(rim[1].luma), "hit 2: the ring darker (rim luma %.3f against %.3f) and deeper (%.0f px against %.0f)" % [rim[2].luma, rim[1].luma, depth[2], depth[1]])
	harm.reset()
	await _frames(2)
	if made:
		harm.queue_free()


## How far in (frame px) the ring reaches from the middle of the left edge
## (`left`) or the top edge: scanning in from the edge, the first pixel of
## three in a row that match the unhurt frame (averaged over 9 lines
## across the middle, so the grain doesn't count; past the ring's inner
## edge only the scene's own flicker could differ, and it is never
## reached).
func _ring_depth(img: Image, none: Image, left: bool) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var reach := (w if left else h) / 2
	var same := 0
	for i in reach:
		var d := 0.0
		for k in range(-4, 5):
			var x := i if left else w / 2 + k
			var y := h / 2 + k if left else i
			var a := img.get_pixel(x, y)
			var b := none.get_pixel(x, y)
			d += maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
		if d / 9.0 <= 0.03:
			same += 1
			if same == 3:
				return float(i - 2)
		else:
			same = 0
	return float(reach)
