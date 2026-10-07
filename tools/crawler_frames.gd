extends SceneTree
## The crawler's visual check (design 6 Oct §ET.11; §CA's walkabout, for
## Torchfire 1): renders the first slice and saves frames, once, at the
## end of a pass (no screenshots between steps):
##   SEED=7 xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/crawler_frames.gd
## ONLY=skeleton renders just the skeletons' sheet and frames; ONLY=cleared
## just the last light's (26-26d). The snake (queue 49) is held still for
## the whole tour; boss_frames pictures it.
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
## the torch beside it; a crypt from its doorway with its old hearth ring
## (built for the frame, then taken away) and with its own wall sconces
## relit (§EX.4); the heart by torchlight and with its four sconces relit;
## a crypt by torchlight and its doorway from inside, the one stone of
## §EX.1 and §EX.3 (10c, 10d);
## the red ring after one hit and after two (§FD, §FJ.3: its depth in
## pixels at 480 lines, darker and deeper on two, the heart beating from
## hit 1); the two hands (§FB): the torch in the right, a fire pot in the
## left, Tab held (the strip low left, then the right hand's low right),
## and Settings' Controls and Settings pages; and the tomb's skeletons
## (design §FE, queue 58; 21-21c): their sheet, one at rest in its wall
## niche (else its grave), climbing out of it in your torchlight, and out;
## the pitch torch (§EZ.2): the bundle's unlit heads by the hearth (01h),
## and the torch in hand in the dark corridor standing and at a sprint's
## lean, at 480 lines and at 270 (22a-22d); the plan and the way out (§EX.2,
## §EX.5; 23-25): down the spine from the hearth room's door, into the
## heart toward the dead and the flight past them, and from the foot of
## the way out's flight looking up it, at noon and at midnight with the
## torch out, and by torchlight.
## Last, the floor cleared by light (design §FF.2, queue 59; 26-26d): every
## other light relit, you before a skeleton at rest in its niche (else its
## grave) with its room's light still cold, then that last light caught
## and the skeleton sinking back into the stone (its first moment, then a
## third of the way), and the niche empty (checks: it is in view on screen
## as the light catches, its bone lit amber; then gone for good, and the
## log's line).
## Checks: every cell of the sheets holds the figure (its pixels drawn),
## the skeleton caught halfway out of its place with its bone lit amber
## on screen,
## the rescuer's chest brighter and warmer from in front (past the fire)
## than from behind, its back navy, the waking frame shows the fire warm
## against the dark (warm pixels, and the frame's darkest share navy, not
## grey), the smothered corridor still dark, the half-dark (the wall
## pixels about 3 m off a readable step over the frame's black, about
## 15 m off at it, and blue), the torchlit frame the same with the
## half-dark on as off, the crypt with its sconces relit at least as lit
## on screen as with its old ring, and one firelight (§EX.6): the torchlit
## and sconce-lit stone the same amber, and the stone right at the torch
## kept amber by the grade; the torch's flame reads as a flame at the
## bottom right (its size on screen measured, in pixels, at both presets); and
## the way out's opening, seen from the foot of its flight with the torch
## out, cool blue and a readable step (READABLE) brighter than the stone
## round it at the top of the flight, by day and at night.
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
## settings back at the end. The hands' strip is drawn where its layout
## says, inside the frame. The player's controls file is
## user://controls_frames.cfg here, removed after.
## Atmosphere (§FG): waking at sunrise (01a: the shaft's daylight dimmer
## than noon's); a damp corridor with glow-moss ahead, in the dark, by
## torchlight from about 4 m and walked up to about 1.5 m (19a-19c;
## checks: its blue-green texels show in the dark and by the far torch,
## and fade once the torch is near); a beetle close by torchlight (20, a
## harness frame: its scatter held off for the picture).

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


## The brightest `share` of the pixels in the box `half` (fractions of the
## frame) round `at` (a fraction of the frame): their mean, as _patch's.
func _brightest(img: Image, at: Vector2, half: Vector2, share: float) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var px: Array = []
	for y in range(int(clampf(at.y - half.y, 0.0, 1.0) * h), int(clampf(at.y + half.y, 0.0, 1.0) * h)):
		for x in range(int(clampf(at.x - half.x, 0.0, 1.0) * w), int(clampf(at.x + half.x, 0.0, 1.0) * w)):
			var c := img.get_pixel(x, y)
			px.append([c.r * 0.3 + c.g * 0.59 + c.b * 0.11, c])
	px.sort_custom(func(a, b): return a[0] > b[0])
	var n := maxi(int(px.size() * share), 1)
	var sum := Color(0, 0, 0)
	for i in mini(n, px.size()):
		sum += px[i][1]
	var c := sum / float(maxi(mini(n, px.size()), 1))
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
## looking along it, with 13.5-30 m clear ahead, walls about 15 m off in
## view (_walls_at: the band the half-dark's check reads; until §EX.4 an
## old hearth ring's stones in the room beyond could be all there was of
## it) and the hearth over 14 m away: [feet, yaw], or [] if none.
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
			if clear >= 13.5 and clear <= 30.0 and eye.distance_to(hp) > 14.0 and _walls_at(space, eye, face, 13.5, 16.5, q.exclude) >= 4:
				return [Vector3(at2.x, fy, at2.y), atan2(-face.x, -face.y)]
	return []


## How many of a fan of rays from `eye` round `face` (60 degrees across,
## 40 up and down) meet a wall (a level normal) `lo` to `hi` m off.
func _walls_at(space: PhysicsDirectSpaceState3D, eye: Vector3, face: Vector2, lo: float, hi: float, ex: Array) -> int:
	var n := 0
	var f3 := Vector3(face.x, 0.0, face.y).normalized()
	for yi in range(-10, 11):
		for ti in range(-5, 6):
			var d := f3.rotated(Vector3.UP, deg_to_rad(yi * 3.0))
			d = d.rotated(d.cross(Vector3.UP).normalized(), deg_to_rad(ti * 4.0))
			var q := PhysicsRayQueryParameters3D.create(eye, eye + d * (hi + 2.0), PropCollision.WORLD_LAYER)
			q.exclude = ex
			var h := space.intersect_ray(q)
			if h.is_empty() or absf((h.normal as Vector3).y) > 0.3:
				continue
			var dist := eye.distance_to(h.position)
			if dist >= lo and dist <= hi:
				n += 1
	return n


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
	ok(not v.is_empty(), "a long view down a cold corridor (13.5-30 m clear ahead, walls about 15 m off in view, the hearth over 14 m off)")
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
## A stretch of room `room`'s side wall with no sconce, door or airway
## within 1.6 m: [along, side (1 its left, -1 its right)], the nearest its
## middle (the middle of its left wall if none).
func _bare_wall(main: CrawlerMain, room: Dictionary) -> Array:
	var length := float(room.len)
	for k in 40:
		var along := length * 0.5 + 0.25 * ceili(k * 0.5) * (1.0 if k % 2 == 1 else -1.0)
		if along < 1.2 or along > length - 1.2:
			continue
		for sd: float in [1.0, -1.0]:
			var bare := true
			for thing in main.lay.holders + main.lay.airways:
				if int(thing.piece) != int(room.id):
					continue
				var aa := Delves.along_across(room, Vector2((thing.pos as Vector3).x, (thing.pos as Vector3).z))
				if absf(absf(aa.y) - float(room.half)) < 0.05 and signf(aa.y) == sd and absf(aa.x - along) < 1.6:
					bare = false
			for di in room.doors:
				var ds: Array = TombKit.door_side(room, main.lay.doors[di])
				if str(ds[0]) == ("left" if sd > 0.0 else "right") and absf(float(ds[1]) + length * 0.5 - along) < 1.6:
					bare = false
			if bare:
				return [along, sd]
	return [length * 0.5, 1.0]


## The room to show with its sconces relit (design §EX.4): a crypt with two
## on its long side walls if there is one, else a crypt with two, a crypt,
## or any room past the hearth room.
func _pick_room(main: CrawlerMain) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for pc in main.lay.pieces:
		if str(pc.kind) != "room" or str(pc.get("room_kind", "")) in ["hearth", "heart", ""]:
			continue
		var n := 0
		var on_sides := true
		for h in main.lay.holders:
			if int(h.piece) == int(pc.id):
				n += 1
				on_sides = on_sides and str(h.get("side", "")) in ["left", "right"]
		var score := (4 if str(pc.room_kind) == "crypt" else 0) + (2 if n == 2 else 0) + (1 if on_sides else 0)
		if score > best_score:
			best_score = score
			best = pc
	return best


## Where to look into room `pc` from: just inside the door in its start
## wall (its way in), facing down the room. [position, yaw].
func _door_view(main: CrawlerMain, pc: Dictionary) -> Array:
	var d: Vector2 = pc.dir
	var across := 0.0
	for di in pc.doors:
		var ds: Array = TombKit.door_side(pc, main.lay.doors[di])
		if str(ds[0]) == "start":
			across = clampf(float(ds[1]), -float(pc.half) + 0.6, float(pc.half) - 0.6)
	var at: Vector2 = (pc.c as Vector2) + d * 0.6 + Delves.perp(d) * across
	return [Vector3(at.x, float(pc.y0), at.y), atan2(-d.x, -d.y)]


## Relight every sconce in room `pc` with the swing (a step out from each,
## the torch lit), then put the torch away: how many caught.
func _relight_room(p: CrawlerPlayer, main: CrawlerMain, pc: Dictionary) -> int:
	var t := p.torch
	_torch_in_hand(p)
	t.light()
	var mine: Array = []
	for h in main.fires.holders:
		if int(h.get_meta("piece")) == int(pc.id):
			mine.append(h)
			var nrm := h.global_basis.z
			var at := h.global_position - Vector3(0.0, float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), 0.0) + nrm * 0.8
			var to := h.global_position - at
			p.spawn_flat(at, atan2(-to.x, -to.z), 0.0)
			t.pass_flame()
	for i in 240:
		FireStore.tick(self, 1.0 / 60.0, p.global_position)
	await _frames(2)
	t.put_out("stowed")
	var n := 0
	for h in mine:
		if FireStore.is_lit(h):
			n += 1
	return n


## Blue-green pixels (the glow-moss's colour: green well over red, as green
## as blue, not dark) within `half` px of `c` (the frame's pixels).
func _teal(img: Image, c: Vector2, half: int) -> int:
	var n := 0
	for y in range(maxi(int(c.y) - half, 0), mini(int(c.y) + half, img.get_height())):
		for x in range(maxi(int(c.x) - half, 0), mini(int(c.x) + half, img.get_width())):
			var px := img.get_pixel(x, y)
			if px.g > 0.1 and px.g > px.r * 1.4 and px.g >= px.b * 0.85:
				n += 1
	return n


## Where `pos` lands in a shot (the frame's pixels, which may be the
## window's size rather than the viewport's).
func _on_shot(main: CrawlerMain, img: Image, pos: Vector3) -> Vector2:
	var cam := main.player.camera()
	var vs := get_root().get_visible_rect().size
	return cam.unproject_position(pos) * Vector2(img.get_width() / vs.x, img.get_height() / vs.y)


## Stand at `at` looking at `target` (the eye about 1.55 m up).
func _look_at_from(p: CrawlerPlayer, at: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z), atan2(target.y - (at.y + 1.55), maxf(flat.length(), 0.01)))


## A spot on the floor of a corridor or room (not the hearth room), or
## Vector3.INF.
func _floor_at(main: CrawlerMain, at: Vector3) -> Vector3:
	var pid := TombKit.piece_at(main.lay, at)
	if pid < 0 or str(main.lay.pieces[pid].kind) not in ["corridor", "room"] or str(main.lay.pieces[pid].get("room_kind", "")) == "hearth":
		return Vector3.INF
	var pc: Dictionary = main.lay.pieces[pid]
	return Vector3(at.x, Delves.floor_of(pc, Delves.along_across(pc, Vector2(at.x, at.z)).x), at.z)


## Nothing solid between the eye at `from` and `to`?
func _clear(main: CrawlerMain, from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = PropCollision.WORLD_LAYER
	q.exclude = [main.player.get_rid()]
	return get_root().get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Atmosphere (design §FG): glow-moss ahead in a damp corridor, in the dark,
## by torchlight from about 4 m (too far to dim it) and walked up to about
## 1.5 m
## (dimmed); then a beetle close by torchlight.
func _atmosphere(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var gm := main.glow_moss
	var G: Dictionary = GlowMoss.G
	# At midnight (no shaft's daylight near), the torch in hand; all put
	# back after.
	var keep_days: float = main.world.days
	var keep_pos := p.global_position
	var keep_yaw := p._yaw
	var keep_pitch := p._pitch
	var keep_lit := t.lit()
	var keep_weapon := p.weapon
	main.world.days = 13.0
	_torch_in_hand(p)
	# The snake held still (queue 49): it would come for the torch.
	var boss: Variant = main.get("boss")
	var keep_auto := true
	if boss is Boss:
		keep_auto = (boss as Boss).auto
		(boss as Boss).auto = false
	var flames := main.fires.flame_points()
	var pick: Dictionary = {}
	var far := Vector3.INF
	var near := Vector3.INF
	for want_corridor in [true, false]:
		for pp in gm.patches:
			var pos: Vector3 = pp.pos
			var n: Vector3 = pp.n
			var pid := TombKit.piece_at(main.lay, pos + n * 0.5)
			if pid < 0 or (str(main.lay.pieces[pid].kind) == "corridor") != want_corridor:
				continue
			# Nothing burning near it (a relit holder would keep it dim).
			var lit_by := false
			for f in flames:
				if f.distance_to(pos) < 6.0:
					lit_by = true
			if lit_by:
				continue
			# Ahead down its wall from across the way, about 4 m off, and
			# then walked up to about 1.5 m.
			var u: Vector3 = Vector3.UP.cross(n).normalized()
			for sd: float in [1.0, -1.0]:
				var a := _floor_at(main, pos + n * 1.6 + u * sd * 3.6)
				var b := _floor_at(main, pos + n * 1.2 + u * sd * 0.9)
				if a != Vector3.INF and b != Vector3.INF and _clear(main, a + Vector3.UP * 1.55, pos + n * 0.1) and _clear(main, b + Vector3.UP * 1.55, pos + n * 0.1):
					pick = pp
					far = a
					near = b
					break
			if not pick.is_empty():
				break
		if not pick.is_empty():
			break
	if pick.is_empty():
		print("  no glow-moss patch with a view along its wall; no atmosphere frames")
	else:
		var target: Vector3 = (pick.pos as Vector3) + (pick.n as Vector3) * 0.04
		pick.level = 1.0
		t.put_out("stowed")
		_look_at_from(p, far, target)
		await _frames(10)
		var img_a := await _shot("19a_glow_moss_dark")
		var teal_a := _teal(img_a, _on_shot(main, img_a, target), int(img_a.get_height() * 0.08))
		t.light()
		await _frames(10)
		var lvl_b := float(pick.level)
		var img_b := await _shot("19b_glow_moss_torch_far")
		var teal_b := _teal(img_b, _on_shot(main, img_b, target), int(img_b.get_height() * 0.08))
		_look_at_from(p, near, target)
		await _frames(int((float(G.get("dims_s", 0.6)) + 0.4) * 60.0))
		var lvl_c := float(pick.level)
		var img_c := await _shot("19c_glow_moss_walked_up")
		var teal_c := _teal(img_c, _on_shot(main, img_c, target), int(img_c.get_height() * 0.16))
		print("  glow-moss (r %.2f m, at %s): blue-green pixels %d in the dark, %d by torchlight from %.1f m (glow %.2f of rest), %d walked up to %.1f m (glow %.2f)" % [float(pick.r), str(pick.pos), teal_a, teal_b, (far + Vector3.UP * 1.55).distance_to(target), lvl_b, teal_c, (near + Vector3.UP * 1.55).distance_to(target), lvl_c])
		ok(teal_a >= 6 and teal_b >= 6, "the glow-moss shows blue-green in the dark (%d px) and by torchlight from afar (%d px)" % [teal_a, teal_b])
		ok(lvl_b > 0.999 and absf(lvl_c - float(G.get("dim_to", 0.1))) < 1e-3 and teal_c < teal_a / 2, "walked up to it with the torch it has dimmed (%d px, glow %.2f of rest)" % [teal_c, lvl_c])
	# A beetle close by torchlight: a harness frame (in play it would be
	# gone into a joint; its scatter held off for the picture).
	var wl := main.wall_life
	for b in wl.bugs:
		if not (b.node as Node3D).visible:
			continue
		var f: Dictionary = main.walls[int(b.face)]
		var bp := wl.world_pos(b)
		var at := _floor_at(main, bp + (f.n as Vector3) * 0.75)
		if at == Vector3.INF or not _clear(main, at + Vector3.UP * 1.55, bp + (f.n as Vector3) * 0.05):
			continue
		var keep_fires := wl.fires
		wl.fires = null
		b.state = "rest"
		b.t = 60.0
		if not t.lit():
			t.light()
		_look_at_from(p, at, bp)
		await _frames(8)
		await _shot("20_%s_close_harness" % str(b.kind))
		wl.fires = keep_fires
		break
	# As it was for what comes next.
	if t.lit() and not keep_lit:
		t.put_out("stowed")
	p.weapon = keep_weapon
	if keep_lit and not t.lit():
		t.light()
	# (spawn_flat stands you 5 cm up; the physics are off here.)
	p.spawn_flat(keep_pos - Vector3(0.0, 0.05, 0.0), keep_yaw, keep_pitch)
	main.world.days = keep_days
	if boss is Boss:
		(boss as Boss).auto = keep_auto
	await _frames(4)


## The pixels that differ between two frames of the same view (one with
## the torch's flame card, one without) inside `win` (frame pixels; other
## fires down the corridor flicker between the two): their box {"x0",
## "y0", "x1", "y1", "n"} in frame pixels, n of them.
func _diff_box(a: Image, b: Image, win: Rect2i) -> Dictionary:
	var w := a.get_width()
	var h := a.get_height()
	var box := {"x0": w, "y0": h, "x1": -1, "y1": -1, "n": 0}
	win = win.intersection(Rect2i(0, 0, w, h))
	for y in range(win.position.y, win.end.y):
		for x in range(win.position.x, win.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.12:
				box.x0 = mini(box.x0, x)
				box.y0 = mini(box.y0, y)
				box.x1 = maxi(box.x1, x)
				box.y1 = maxi(box.y1, y)
				box.n += 1
	return box


## Where the flame card can be on screen (frame pixels): its foot and top
## (the card turns to face the camera about its up axis only, so those
## stay put) and its width either side, leaning, with half again round it.
func _card_window(cam: Camera3D, card: Node3D, w: int, h: int) -> Rect2i:
	var xf := card.global_transform
	var foot := xf.origin
	var top := xf * Vector3(0.0, 1.0, 0.0)
	var a := cam.unproject_position(foot)
	var b := cam.unproject_position(top)
	# The viewport's own pixels to the frame's (the same at the internal size).
	var vs := Vector2(cam.get_viewport().get_visible_rect().size)
	var k := Vector2(w, h) / vs
	a *= k
	b *= k
	var tall := maxf((b - a).length(), 4.0)
	var half_w := tall * xf.basis.x.length() / maxf(xf.basis.y.length(), 1e-4) * 0.5
	var lo := Vector2(minf(a.x, b.x) - half_w, minf(a.y, b.y))
	var hi := Vector2(maxf(a.x, b.x) + half_w, maxf(a.y, b.y))
	var pad := (hi - lo) * 0.5
	return Rect2i(Vector2i(lo - pad), Vector2i(hi - lo + pad * 2.0))


## The pitch torch in hand where nothing else is lit (design 6 Oct §EZ.2):
## standing, then at a sprint's lean (the frames run with physics off, so
## the player's velocity is set and the torch stepped), at 480 lines and
## at 270. The flame's size on screen is measured by drawing the same view
## with and without its card (the coal, the sparks and the smoke hidden
## for that pair, so only the card differs) and boxing the pixels that
## change.
func _pitch_frames(main: CrawlerMain, p: CrawlerPlayer, t: Torch) -> void:
	var keep := str(Settings.get_value("display.preset", ""))
	# The snake held still (queue 49), as for the glow-moss: it would come
	# for the torch.
	var boss: Variant = main.get("boss")
	var keep_auto := true
	if boss is Boss:
		keep_auto = (boss as Boss).auto
		(boss as Boss).auto = false
	t.light()
	var head: Node3D = t._view_flame
	var card := head.get_node("Flame/Card") as Node3D
	var quiet: Array[Node3D] = [head.get_node("Coal") as Node3D, head.get_node("Flame/Embers") as Node3D]
	var shot := 0
	var stood := Vector2.ZERO
	for lines_want in [480, 270]:
		Settings.set_value("display.preset", _preset_of(lines_want))
		Display.apply()
		await _frames(6)
		var lines := Display.lines()
		for pose in ["stand", "sprint"]:
			p.velocity = Vector3.ZERO if pose == "stand" else -p.global_basis.z * PlanetPlayer.SPRINT_SPEED
			p.sprinting = pose == "sprint"
			for i in 90:
				t.update_torch(1.0 / 60.0)
				await process_frame
			await _shot("22%s_torch_dark_%s_%d" % ["abcd"[shot], pose, lines])
			shot += 1
			# The measuring pair: everything that moves on its own hidden but
			# the card.
			var hidden: Array[Node3D] = quiet.duplicate()
			if head.has_meta("smoke_col"):
				hidden.append(head.get_meta("smoke_col"))
			var was: Array[bool] = []
			for q in hidden:
				was.append(q.visible)
				q.visible = false
			await _frames(2)
			await RenderingServer.frame_post_draw
			var with_card := get_root().get_texture().get_image()
			card.visible = false
			await _frames(1)
			await RenderingServer.frame_post_draw
			var without := get_root().get_texture().get_image()
			card.visible = true
			for i in hidden.size():
				hidden[i].visible = was[i]
			var w := with_card.get_width()
			var h := with_card.get_height()
			var bx := _diff_box(with_card, without, _card_window(p.camera(), card, w, h))
			var fh := int(bx.y1) - int(bx.y0) + 1
			var fw := int(bx.x1) - int(bx.x0) + 1
			var rows := PitchTorch.flame_texels().y
			print("  the flame in hand, %s at %d lines: %d px tall, %d px wide (x %d-%d, y %d-%d of %dx%d), %d px drawn; about %.1f px a texel; lean %.1f deg" % [pose, lines, fh, fw, bx.x0, bx.x1, bx.y0, bx.y1, w, h, bx.n, float(fh) / (rows * 0.85), t.lean.deg()])
			if pose == "stand":
				var cx := (float(bx.x0) + float(bx.x1)) * 0.5 / w
				ok(int(bx.n) > 0 and cx > 0.6 and float(bx.y1) / h > 0.5 and float(fh) / h > 0.1 and float(fh) / h < 0.35 and float(bx.n) > 0.3 * fh * fw, "at %d lines the flame reads at the bottom right: %d px tall (%.0f%% of the frame), %d wide, its foot at %.0f%% down, solid (%.0f%% of its box drawn)" % [lines, fh, 100.0 * fh / h, fw, 100.0 * float(bx.y1) / h, 100.0 * float(bx.n) / maxf(fh * fw, 1.0)])
				stood = Vector2(fw, fh)
			else:
				ok(int(bx.n) > 0 and float(fw) > stood.x * 1.2 and float(fh) > stood.y * 0.9 and float(bx.n) > 0.2 * fh * fw, "at %d lines the flame streams back at a sprint: %d px wide against %d standing, %d tall, still solid (%.0f%% of its box drawn)" % [lines, fw, int(stood.x), fh, 100.0 * float(bx.n) / maxf(fh * fw, 1.0)])
	p.velocity = Vector3.ZERO
	p.sprinting = false
	for i in 60:
		t.update_torch(1.0 / 60.0)
	Settings.set_value("display.preset", keep)
	Display.apply()
	if boss is Boss:
		(boss as Boss).auto = keep_auto
	await _frames(6)


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
	Controls.path = "user://controls_frames.cfg"
	# The skeletons sleep through the tour (design §FE); one is woken at
	# the end for its frames.
	Residents.stay_asleep = true
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
	# The snake held still for the whole tour (queue 49), as _pitch_frames
	# and _atmosphere hold it for theirs: it comes for a lit torch in the
	# dark, and since queue 56 a chase follows you into the light. Free, on
	# seed 7 it lay coiled beside you through the heart's frames (10, 10b),
	# or its strikes took you back to the hearth mid-tour.
	var boss: Variant = main.get("boss")
	if boss is Boss:
		(boss as Boss).auto = false
	if OS.get_environment("ONLY") == "skeleton":
		# Just the skeletons' sheet and frames (a quick look; also for a
		# machine with no GPU, where every frame takes seconds).
		await _frames(30)
		main.player.set_physics_process(false)
		await _skeleton(main)
		_finish(keep)
		return
	if OS.get_environment("ONLY") == "cleared":
		# Just the last light's frames (design §FF.2).
		await _frames(30)
		main.player.set_physics_process(false)
		await _cleared(main)
		_finish(keep)
		return
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
	# At sunrise: the shaft's daylight follows the sun (§FG), dimmer than
	# noon's.
	world.days = Vents.days_at_solar_hour(13.0, 6.0)
	await _frames(6)
	await _shot("01a_wake_sunrise")
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
	# The bundle by the hearth, close: unlit pitch heads (§EZ.2).
	var bp: Vector3 = main.fires.bundle.global_position
	var hp0: Vector3 = main.fires.hearth.global_position
	var from_b := Vector3(bp.x - hp0.x, 0.0, bp.z - hp0.z).normalized() * 0.9
	p.spawn_flat(Vector3(bp.x, 0.0, bp.z) + from_b, atan2(from_b.x, from_b.z), -0.95)
	await _frames(6)
	await _shot("01h_bundle_pitch_heads")
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
		# A bare stretch of a side wall (no sconce, door or airway near).
		var bw := _bare_wall(main, room)
		var along_w := float(bw[0])
		var pv := Delves.perp(rd) * float(bw[1])
		var spot: Vector2 = (room.c as Vector2) + rd * along_w + pv * (float(room.half) - 1.4)
		p.spawn_flat(Vector3(spot.x, float(room.y0), spot.y), atan2(-pv.x, -pv.y), -0.1)
		await _frames(8)
		await _shot("01d_fitted_stone_%s" % FittedStone.preset_name())
		# The torch's light on the stone (§EX.6): 1 m from the wall, at
		# night, nothing else lit near.
		world.days = 13.0
		var spot1: Vector2 = (room.c as Vector2) + rd * along_w + pv * (float(room.half) - 1.0)
		p.spawn_flat(Vector3(spot1.x, float(room.y0), spot1.y), atan2(-pv.x, -pv.y), -0.05)
		await _frames(8)
		var img_e := await _shot("01e_torch_at_wall")
		var tw := _patch(img_e, 0.3, 0.2, 0.62, 0.6)
		firelit["torch"] = tw
		cross["amber"] = _reticle_read(img_e)
		_say_cross("on the torchlit wall, 1 m", cross.amber)
		print("  torchlit wall: hue %.1f, chroma %.3f, luma %.3f (#%s)" % [tw.hue, tw.chroma, tw.luma, (tw.color as Color).to_html(false)])
		# Closer, where the stone at the torch blows brightest.
		var spot2: Vector2 = (room.c as Vector2) + rd * along_w + pv * (float(room.half) - 0.45)
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
		if str(h.get_meta("fire_holder")) == "sconce" and str((main.lay.pieces[int(h.get_meta("piece"))] as Dictionary).kind) == "corridor":
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
		# The pitch torch in hand in this dark corridor (§EZ.2), then the
		# view and the smothered torch as they were.
		if t.pitch:
			var back_pos := p.global_position - Vector3(0.0, 0.05, 0.0)
			var back_yaw := p._yaw
			var back_pitch := p._pitch
			p.spawn_flat(stand, atan2(-along.x, -along.z), -0.05)
			await _pitch_frames(main, p, t)
			t.douse()
			p.spawn_flat(back_pos, back_yaw, back_pitch)
			await _frames(6)
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
	# A crypt with its wall sconces relit (design §EX.4), against the
	# hearth ring it had before (built for the frame where TombKit put it,
	# then taken away): the same view from its doorway, at night, the
	# torch away.
	var crypt := _pick_room(main)
	if not crypt.is_empty():
		var keep_days3: float = world.days
		world.days = 13.0
		var view := _door_view(main, crypt)
		t.put_out("stowed")
		var ring_at: Vector2 = (crypt.c as Vector2) + (crypt.dir as Vector2) * float(crypt.len) * 0.5
		var ring: Node3D = main.fires._holder({"kind": "hearth_ring", "pos": Vector3(ring_at.x, float(crypt.y0), ring_at.y), "normal": Vector3.UP, "piece": int(crypt.id)})
		FireStore.swing_light(ring, world.days)
		for i in 240:
			FireStore.tick(self, 1.0 / 60.0, p.global_position)
		p.spawn_flat(view[0], float(view[1]), -0.12)
		await _frames(20)
		var old_img := await _shot("09a_%s_old_hearth_ring" % str(crypt.room_kind))
		ring.queue_free()
		await _frames(2)
		var n_lit := await _relight_room(p, main, crypt)
		p.spawn_flat(view[0], float(view[1]), -0.12)
		await _frames(20)
		var new_img := await _shot("09_%s_sconces_relit" % str(crypt.room_kind))
		var so := _stats(old_img)
		var sn := _stats(new_img)
		print("  the %s from its door, at night: old hearth ring mean %.3f (warm %.3f); its %d sconces relit mean %.3f (warm %.3f)" % [crypt.room_kind, so.mean_l, so.warm, n_lit, sn.mean_l, sn.warm])
		ok(float(sn.mean_l) >= float(so.mean_l), "the %s with its %d wall sconces relit is at least as lit on screen as with its old hearth ring (mean %.3f against %.3f)" % [crypt.room_kind, n_lit, sn.mean_l, so.mean_l])
		world.days = keep_days3
	# The heart: by torchlight, then its four sconces relit, flanking the
	# dead.
	if main.lay.has("heart"):
		var hpc: Dictionary = main.lay.pieces[int(main.lay.heart)]
		var hd: Vector2 = hpc.dir
		var hc: Vector2 = (hpc.c as Vector2) + hd * float(hpc.len) * 0.3
		t.light()
		p.spawn_flat(Vector3(hc.x, float(hpc.y0), hc.y), atan2(-hd.x, -hd.y), -0.2)
		await _frames(20)
		await _shot("10_heart_by_torch")
		var n_h := await _relight_room(p, main, hpc)
		p.spawn_flat(Vector3(hc.x, float(hpc.y0), hc.y), atan2(-hd.x, -hd.y), -0.12)
		await _frames(20)
		await _shot("10b_heart_relit")
		print("  the heart: %d sconces relit" % n_h)
	# One ruin, one stone (§EX.1, §EX.3): a crypt by torchlight, looking down
	# it (the fitted flags, the corbel course and the slabs, its pillars
	# where it has them, the coffins), and its doorway from inside (the
	# trapezoid, the jamb stones, the lintel, the threshold).
	for pc in main.lay.pieces:
		if str(pc.get("room_kind", "")) != "crypt":
			continue
		var cd: Vector2 = pc.dir
		var cc: Vector2 = (pc.c as Vector2) + cd * 0.9
		p.spawn_flat(Vector3(cc.x, float(pc.y0), cc.y), atan2(-cd.x, -cd.y), -0.1)
		await _frames(20)
		await _shot("10c_crypt_by_torch")
		var door: Dictionary = main.lay.doors[int(pc.doors[0])]
		var into: Vector2 = (door.n as Vector2) if int(door.b) == int(pc.id) else -(door.n as Vector2)
		var at: Vector2 = (door.p as Vector2) + into * 3.2
		p.spawn_flat(Vector3(at.x, float(pc.y0), at.y), atan2(into.x, into.y), 0.05)
		await _frames(20)
		await _shot("10d_doorway_from_the_crypt")
		break
	# The plan and the way out (§EX.2, §EX.5), the torch away: down the
	# spine from the hearth room's door; into the heart from its way in,
	# toward the dead and the flight past them; from the foot of the flight,
	# looking up at the opening, by day and at night.
	t.put_out("stowed")
	var lay: Dictionary = main.lay
	if not (lay.spine as Array).is_empty():
		var d0: Dictionary = lay.doors[int((lay.pieces[0].doors as Array).filter(func(di): return bool(lay.doors[di].get("spine", false)))[0])]
		var dn: Vector2 = d0.n
		var at0: Vector2 = (d0.p as Vector2) - dn * 1.6
		p.spawn_flat(Vector3(at0.x, 0.0, at0.y), atan2(-dn.x, -dn.y), -0.02)
		await _frames(12)
		await _shot("23_down_the_spine")
	if (lay.exits as Array).size() > 0 and lay.has("heart"):
		var ex: Dictionary = lay.exits[0]
		var hpc2: Dictionary = lay.pieces[int(lay.heart)]
		var hd2: Vector2 = hpc2.dir
		var hin: Vector2 = (hpc2.c as Vector2) + hd2 * 0.6
		t.light()
		p.spawn_flat(Vector3(hin.x, float(hpc2.y0), hin.y), atan2(-hd2.x, -hd2.y), 0.08)
		await _frames(12)
		await _shot("24_heart_to_the_way_out")
		t.put_out("stowed")
		var stair: Dictionary = lay.pieces[int(ex.stair)]
		var sd: Vector2 = stair.dir
		var stair_foot: Vector2 = (stair.c as Vector2) + sd * 0.3
		var eye_y := float(stair.y0) + CrawlerPlayer.EYE_Y
		# Up the flight at the opening's sill (behind the top step from
		# here), so the opening shows over the crosshair, not under it.
		var op: Vector3 = ex.p
		var pitch := atan2(op.y - eye_y, Vector2(op.x - stair_foot.x, op.z - stair_foot.y).length())
		var vs := Vector2(get_root().get_visible_rect().size)
		var side := Vector3.UP.cross(ex.n as Vector3).normalized()
		var oh := float(ex.h)
		var ohalf := float(ex.half)
		# The patch of the screen over the opening's plane from s0 to s1
		# across (m from its middle) and h0 to h1 up (shares of its height).
		var on_screen := func(s0: float, s1: float, h0: float, h1: float) -> Rect2:
			var a := cam.unproject_position(op + side * s0 + Vector3.UP * oh * h0) / vs
			var b := cam.unproject_position(op + side * s1 + Vector3.UP * oh * h1) / vs
			return Rect2(a, Vector2.ZERO).expand(b)
		# Noon and midnight by the sun (the clock is warped: Vents).
		var noon := Vents.days_at_solar_hour(13.0, 12.0)
		for when in [[noon, "25_way_out_from_below_day", "day"], [Vents.days_at_solar_hour(13.0, 0.0), "25b_way_out_from_below_night", "night"]]:
			world.days = float(when[0])
			p.spawn_flat(Vector3(stair_foot.x, float(stair.y0), stair_foot.y), atan2(-sd.x, -sd.y), pitch)
			# (The half-dark settled, §FC.4: as you'd see it.)
			await _settle(main)
			var img := await _shot(str(when[1]))
			# The opening on screen: the middle of its width, the upper part
			# of its height (from here the top step hides the lower part),
			# against the stone round it at the top of the flight, as far
			# off: either side of it and over it. (The steps by you are the
			# half-dark's, readable by design, §FC.4: not the dark the
			# opening has to show against.)
			var ro: Rect2 = on_screen.call(-ohalf * 0.6, ohalf * 0.6, 0.8, 0.9)
			var glow := _patch(img, ro.position.x, ro.position.y, ro.end.x, ro.end.y)
			var round_l := 0.0
			for q: Rect2 in [on_screen.call(-ohalf - 0.7, -ohalf - 0.3, 0.8, 0.9), on_screen.call(ohalf + 0.3, ohalf + 0.7, 0.8, 0.9), on_screen.call(-ohalf * 0.6, ohalf * 0.6, 1.1, 1.2)]:
				round_l = maxf(round_l, float(_patch(img, q.position.x, q.position.y, q.end.x, q.end.y).luma))
			var near := _patch(img, 0.25, 0.8, 0.75, 0.95)
			var gc: Color = glow.color
			print("  the way out from below (%s): the opening #%s (luma %.3f) at %s; the stone round it at the top, luma %.3f at most; the steps by you %.3f" % [when[1], gc.to_html(false), glow.luma, str(ro.get_center().snapped(Vector2.ONE * 0.01)), round_l, near.luma])
			ok(gc.b > gc.r and float(glow.luma) >= round_l + READABLE, "from the foot of the flight (%s), the opening at its top is a cool blue, readable against the stone round it (%.2f luma or more over it)" % [str(when[2]), READABLE])
		# The same by day with the torch in hand: the flight itself.
		world.days = noon
		t.light()
		p.spawn_flat(Vector3(stair_foot.x, float(stair.y0), stair_foot.y), atan2(-sd.x, -sd.y), pitch)
		await _frames(12)
		await _shot("25c_way_out_from_below_torch")
		t.put_out("stowed")
	await _pots(main)
	await _atmosphere(main)
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
	await _hands(main, p)
	await _skeleton(main)
	# Last: clearing the floor sends every skeleton away for good.
	await _cleared(main)
	_finish(keep)


## The player's own settings back and the run's controls file gone; the
## result; quit.
func _finish(keep: Dictionary) -> void:
	if FileAccess.file_exists(Controls.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Controls.path))
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
	# What the pots left burning goes out first (a tar patch lasts 12 s):
	# the corridor is dark, and its flicker past the ring's edge would
	# differ from shot to shot.
	for f in main.fire_pots.fires.duplicate():
		if f is PotFire and is_instance_valid(f):
			(f as PotFire)._end()
	# A cold corridor: 3.5 m along from a sconce nobody has lit.
	var cold: Node3D = null
	for h in main.fires.holders:
		if str(h.get_meta("fire_holder")) == "sconce" and not FireStore.is_lit(h) and str((main.lay.pieces[int(h.get_meta("piece"))] as Dictionary).kind) == "corridor":
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


## The mean difference of two frames over `r` (image pixels), 0..1.
func _diff(a: Image, b: Image, r: Rect2) -> float:
	var s := 0.0
	var n := 0
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			s += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
			n += 1
	return s / maxf(n, 1.0)


## The two hands (design §FB, prompt 55): on the mat at night, the torch
## lit in the right hand and a fire pot in the left, the strip holding
## pots of both oils; Tab held, the
## strip low on the left of the frame; with the wheel on the left hand, the
## right hand's choices low right; then Settings' Controls page and the
## Settings page with its tabs. (The player's physics is off here, so Tab
## is pressed and its time set by hand.)
func _hands(main: CrawlerMain, p: CrawlerPlayer) -> void:
	var hands := p.hands
	var world: Node = main.world
	var keep_days: float = world.days
	world.days = 13.0
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.3)
	_torch_in_hand(p)
	p.torch.light()
	# Fire pots of both oils on the strip (FirePots' F9), the first in hand
	# (the strip cleared first, so it holds just these).
	for it in main.fire_pots.pots_carried():
		main.fire_pots._remove(it)
	main.fire_pots.give_dev()
	hands.hold_left(main.fire_pots.pots_carried()[0])
	hands.update(0.0)
	await _frames(8)
	var plain := await _shot("17a_hands_both")
	Input.action_press("other_hand")
	hands.tab_s = 1.0
	await _frames(4)
	var held := await _shot("17b_hands_strip")
	var lay: Dictionary = main.hand_strip.layout()
	var pr: Rect2 = lay.panel
	var k := float(held.get_width()) / main.hand_strip.size.x
	var d_in := _diff(plain, held, Rect2(pr.position * k, pr.size * k))
	var opposite := Rect2(Vector2(main.hand_strip.size.x - pr.end.x, pr.position.y) * k, pr.size * k)
	var d_out := _diff(plain, held, opposite)
	ok(main.hand_strip.visible and Rect2(Vector2.ZERO, main.hand_strip.size).encloses(pr) and d_in > d_out * 4.0 + 0.02, "Tab held: the strip is drawn low left, inside the frame (%s; the frame changed %.3f there, %.3f at the opposite corner)" % [str(pr), d_in, d_out])
	Controls.set_wheel_drives("left")
	await _frames(4)
	await _shot("17c_hands_strip_right")
	Controls.set_wheel_drives("right")
	Input.action_release("other_hand")
	hands.tab_s = 0.0
	await _frames(4)
	main._toggle_settings(true)
	main.settings_panel.page = "controls"
	main.settings_panel.queue_redraw()
	await _frames(4)
	await _shot("18_controls_page")
	main.settings_panel.page = "settings"
	main.settings_panel.queue_redraw()
	await _frames(4)
	await _shot("18b_settings_page")
	main._toggle_settings(false)
	p.torch.put_out("stowed")
	world.days = keep_days


## The skeletons (design §FE, queue 58): their sheet, every cell drawn;
## then one climbing out of its niche (else its grave) in your torchlight,
## caught halfway out, and its bone lit amber on screen.
func _skeleton(main: CrawlerMain) -> void:
	var res := main.residents
	if res.all.is_empty():
		ok(false, "the tomb has skeletons")
		return
	var r: Resident = res.all[0]
	for q in res.all:
		if str(q.place.rests_in) == "wall_niche":
			r = q
			break
	if r.sprite == null:
		ok(false, "the skeleton's sheet is baked")
		return
	var sheet := r.sprite.atlas.get_image()
	sheet.save_png(out_dir.path_join("21_skeleton_sheet.png"))
	var spr := r.sprite
	var cols := spr.around
	var rows := spr.rows_deg.size() * spr.poses
	var cw := sheet.get_width() / cols
	var ch := sheet.get_height() / rows
	var empty := 0
	var least := 1 << 30
	for row in rows:
		for col in cols:
			var n := 0
			for y in range(0, ch, 2):
				for x in range(0, cw, 2):
					if sheet.get_pixel(col * cw + x, row * ch + y).a > 0.5:
						n += 1
			least = mini(least, n)
			if n < 25:
				empty += 1
	ok(empty == 0, "every one of the skeleton sheet's %d cells (%d poses x %d heights x %d around) holds it (fewest drawn: %d px at half size)" % [cols * rows, spr.poses, spr.rows_deg.size(), cols, least])
	# In torchlight, from in front of its place, as it climbs out.
	var p := main.player
	var world: Node = main.world
	world.days = 13.0
	var e: Vector3 = r.place.eye
	var out: Vector3 = r.place.out
	var inward := Vector3(out.x - (r.place.pos as Vector3).x, 0.0, out.z - (r.place.pos as Vector3).z).normalized()
	var side := inward.cross(Vector3.UP).normalized()
	var stand := Vector3(e.x, out.y, e.z) + inward * 2.7 + side * 0.6
	var to := Vector3(e.x, stand.y, e.z) - stand
	_torch_in_hand(p)
	p.torch.light()
	# Nothing in the left hand (the hands' frames leave a pot there).
	p.hands.hold_left({})
	p.spawn_flat(stand, atan2(-to.x, -to.z), -0.12)
	await _frames(10)
	await _shot("21a_skeleton_at_rest_%s" % str(r.place.rests_in))
	r.wake()
	var rise := float(r.def.get("rise_s", 1.6))
	while r.state == Resident.RISING and r.t < rise * 0.6:
		await process_frame
	var img := await _shot("21b_skeleton_climbing_out_%s" % str(r.place.rests_in))
	# Its bone on screen: the brightest pixels round where it is (the lit
	# bone, not the wall behind its ribs), against the frame's size.
	var cam := p.camera()
	var mid := r.global_position + Vector3(0.0, 0.7, 0.0)
	var at := cam.unproject_position(mid) / cam.get_viewport().get_visible_rect().size
	var bone := _brightest(img, at, Vector2(0.07, 0.16), 0.15)
	print("  the skeleton climbing out (%s, pose %s) at %s of the frame: its brightest pixels luma %.3f, hue %.1f, chroma %.3f (#%s)" % [r.state_name(), SkeletonRig.POSES[r.sprite.pose], str(at), bone.luma, bone.hue, bone.chroma, (bone.color as Color).to_html(false)])
	ok(r.state == Resident.RISING and SkeletonRig.POSES[r.sprite.pose] in ["rise_a", "rise_b", "rise_c"], "caught halfway out of its %s (%s)" % [r.place.rests_in, SkeletonRig.POSES[r.sprite.pose]])
	ok(float(bone.luma) > 0.25 and float(bone.hue) >= -20.0 and float(bone.hue) <= 62.0, "its bone shows in your torchlight, amber (luma %.3f, hue %.1f)" % [bone.luma, bone.hue])
	# Out on the floor, held there for its frame (on a slow renderer the
	# game runs on between frames, and it would be on you already).
	var n := 0
	while r.state == Resident.RISING and n < 600:
		await process_frame
		n += 1
	r.set_physics_process(false)
	await _frames(4)
	await _shot("21c_skeleton_out")
	r.set_physics_process(true)
	p.torch.put_out("stowed")



## The floor cleared by light (design §FF.2; queue 59): every light but the
## last relit (the skeletons asleep through it, as the tour keeps them),
## you before a skeleton at rest in its wall niche (else its grave), its
## room's light still cold (26a); then that last light caught and the
## floor cleared: the skeleton, in view, sinks back into the stone (26b,
## the moment it catches; 26c a third of the way, held for the frame: on a slow
## renderer the game runs on between frames, so it is posed there, a
## harness frame); then the niche empty and the room lit (26d).
func _cleared(main: CrawlerMain) -> void:
	var res := main.residents
	var fires := main.fires
	var p := main.player
	var boss: Variant = main.get("boss")
	var keep_auto := true
	if boss is Boss:
		keep_auto = (boss as Boss).auto
		(boss as Boss).auto = false
	# Everyone at rest in its place (the skeleton frames woke one).
	for q in res.all:
		q._disarm()
		q.pursuit.give_up()
		q.state = Resident.REST
		q.t = 0.0
		q.global_position = q.place.pos
		q.yaw = float(q.place.yaw)
		q.set_physics_process(true)
		q._show_pose()
	# A skeleton at rest in a wall niche (else a grave) whose room has a
	# light of its own, and floor before it to stand on, close (it sleeps on
	# through the setup: the tour keeps them asleep, and it is held once the
	# last light is lit).
	var r: Resident = null
	var stand := Vector3.INF
	for kind in ["wall_niche", "grave"]:
		for q in res.all:
			if str(q.place.rests_in) != kind or not fires.holders.any(func(h) -> bool: return int(h.get_meta("piece")) == int(q.place.piece)):
				continue
			var out: Vector3 = q.place.out
			var inward := Vector3(out.x - (q.place.pos as Vector3).x, 0.0, out.z - (q.place.pos as Vector3).z).normalized()
			for m: float in [1.6, 2.1, 1.2, 2.7]:
				var at := _floor_at(main, out + inward * m)
				if at != Vector3.INF and main.residents.nav.is_open(main.residents.nav.cell_of(at)):
					r = q
					stand = at
					break
			if r != null:
				break
		if r != null:
			break
	if r == null:
		ok(false, "the last light: a skeleton at rest in a room with its own light, with room to stand before it")
		return
	# Every light but its room's (one of them left for last).
	var last: Node3D = null
	for h in fires.holders:
		if int(h.get_meta("piece")) == int(r.place.piece) and last == null:
			last = h
			continue
		if not FireStore.is_lit(h):
			FireStore.swing_light(h, float(main.world.get("days")))
			for i in 600:
				FireStore.tick(self, 1.0 / 60.0, h.global_position)
				if FireStore.is_lit(h):
					break
	await _frames(4)
	ok(fires.lit_count() == fires.holders.size() - 1 and not res.cleared, "the last light: every other light relit (%d of %d), the floor not yet cleared" % [fires.lit_count(), fires.holders.size()])
	# You before it by torchlight, the last light in view too.
	var world: Node = main.world
	world.days = 13.0
	_torch_in_hand(p)
	p.torch.light()
	p.hands.hold_left({})
	var look := (r.place.eye as Vector3).lerp(last.global_position + Vector3(0.0, 0.4, 0.0), 0.3)
	_look_at_from(p, stand, look)
	await _frames(10)
	await _shot("26a_last_light_cold_%s" % str(r.place.rests_in))
	# The last light: it catches, the floor is cleared, and the skeleton in
	# view goes (held at each moment for its frame).
	Residents.stay_asleep = false
	r.set_physics_process(false)
	FireStore.swing_light(last, float(world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, last.global_position)
		if FireStore.is_lit(last):
			break
	var n := 0
	while not res.cleared and n < 60:
		await physics_frame
		n += 1
	var seen := r.state == Resident.RETREAT and r.seen_going
	var wd := maxf(Residents.rule("withdraw_s", 1.2), 0.05)
	var into := Resident._into_stone(r.hole if not r.hole.is_empty() else r.place)
	var from: Vector3 = (r.hole.get("pos", r.place.pos) as Vector3)
	r.global_position = from + into * smoothstep(0.0, 1.0, 0.08)
	r._show_pose()
	await _frames(4)
	var img := await _shot("26b_last_light_catches")
	var cam := p.camera()
	var mid := r.global_position + Vector3(0.0, 0.5, 0.0)
	var on := cam.is_position_in_frustum(mid)
	var at := cam.unproject_position(mid) / cam.get_viewport().get_visible_rect().size
	var bone := _brightest(img, at, Vector2(0.06, 0.12), 0.15)
	print("  the last light caught: the floor cleared %s, the skeleton (%s, %s) at %s of the frame, its brightest pixels luma %.3f, hue %.1f" % [str(res.cleared), r.state_name(), r._rphase, str(at), bone.luma, bone.hue])
	ok(res.cleared and seen and on and at.x > 0.0 and at.x < 1.0 and at.y > 0.0 and at.y < 1.0, "the last light caught, the floor cleared, and the skeleton in view goes: it sinks back into the stone where you see it (%s)" % r._rphase)
	ok(float(bone.luma) > 0.2 and float(bone.hue) >= -20.0 and float(bone.hue) <= 62.0, "its bone lit amber as it goes (luma %.3f, hue %.1f)" % [bone.luma, bone.hue])
	# A third of the way: deep in its niche (or down in its grave), the
	# stone about to take it.
	r.global_position = from + into * smoothstep(0.0, 1.0, 0.33)
	r._show_pose()
	await _frames(4)
	await _shot("26c_into_the_stone_harness")
	# On it goes; then the place is empty.
	r.set_physics_process(true)
	var w := 0
	while is_instance_valid(r) and r.state != Resident.GONE and w < 600:
		await physics_frame
		w += 1
	await _frames(10)
	await _shot("26d_gone")
	var line := str(Residents.CLEARED.get("log_line", ""))
	var logged := GameLog.entries.any(func(e) -> bool: return str(e.get("text", "")) == line)
	ok((not is_instance_valid(r) or r.state == Resident.GONE) and res.all.is_empty() and logged, "then it is gone for good, every one of them, and the log says \"%s\"" % line)
	Residents.stay_asleep = true
	if boss is Boss:
		(boss as Boss).auto = keep_auto
	p.torch.put_out("stowed")
