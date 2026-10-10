extends SceneTree
## Floor two's fog (design 9 Oct §FM.6; queue 69; FloorFog; data/descent.json
## floor_two.fog), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/fog_check.gd
## FOG_SEEDS (env) sets how many layouts beyond 1, 7 and 42 the fog is
## mapped over (default 17: twenty in all, drawn from a fixed seed).
## Asserts:
##  1. the data and the colour: floor_two.fog.density and ease_m read; the
##     fog's colour the look's shade navy (color_from look_shade_navy:
##     look.json retro.targets.colours.shade, LOOK_REFERENCE R3), blue above
##     red and not grey (red, green and blue all within 0.02 of each other
##     fails), lighter and bluer than the tomb's own dark (crawler.json look
##     fog_color) so floor two's distance goes lighter and bluer, never
##     darker; the look's haze on floor two (floor one's with the fog in it)
##     the same;
##  2. where it is (twenty layouts): 0 at every piece of floor one, 1 at
##     every piece of floor two (the whole floor, uniform); down the flight
##     from its mouth to its foot every 5 cm: none above its last ease_m
##     metres, then rising, never back, to full at its foot, no 5 cm step
##     steeper than the ease's own; held in a doorway's thickness; none in a
##     tomb of one floor;
##  3. in the scene (SEED, as shipped): waking on floor one the environment's
##     fog off and the look's haze floor one's own (crawler.json look, as
##     before); on floor two the environment's fog on at floor_two.fog.density
##     (exponential) in the shade navy, and the look's haze floor one's with
##     it added; the frame at the default 480 lines (854 x 480) and the
##     grade's 5-bit dither as before, on both floors;
##  4. down the stair and back (the way down open): your body walks from the
##     room the stair leaves onto floor two and back: the fog's density, read
##     every frame, none until the stair's last ease_m metres, full at its
##     foot, out over the same metres going up; never more than a twentieth
##     of it in one frame (no pop);
##  5. only fog: pinned off and on at the same place in the same frame
##     (floor two, the torch in hand lit, the snake and the skeletons where
##     they are), the light field's number on every square, what a skeleton
##     would count as seen at points round you, whether the snake is in
##     view, the torch's light and the half-dark's, the grade, and every
##     other value of the environment and the look are the same: only the
##     fog's own values differ;
##  6. back on the mat by the hearth (as waking after "Good night") the fog
##     is off again at once.

var fails := 0
const DT := 1.0 / 60.0
## Layouts mapped beyond 1, 7 and 42 (env FOG_SEEDS overrides).
const MORE_SEEDS := 17
## Not grey: red, green and blue within this of each other is grey.
const GREY_WITHIN := 0.02


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	Residents.stay_asleep = true
	Torch.burn_down = false
	_colour()
	_layouts(_seeds())
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	await _scene()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seeds() -> Array:
	var n := MORE_SEEDS
	if OS.get_environment("FOG_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("FOG_SEEDS")), 0)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 69
	while out.size() < 3 + n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


## Grey: red, green and blue all within GREY_WITHIN of each other.
static func _grey(c: Color) -> bool:
	return absf(c.r - c.g) <= GREY_WITHIN and absf(c.g - c.b) <= GREY_WITHIN and absf(c.r - c.b) <= GREY_WITHIN


static func _luma(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


# --- 1. The data and the colour ---------------------------------------------------

func _colour() -> void:
	var fog: Dictionary = FloorFog.FOG
	var dens := FloorFog.density()
	print("  floor_two.fog: %s" % str(fog))
	ok(fog.has("density") and is_equal_approx(dens, float(fog.density)) and dens > 0.0, "descent.json floor_two.fog.density read: %.3f a metre, Godot's exponential fog (%.0f%% of what is 10 m off hidden, half at %.1f m)" % [dens, 100.0 * (1.0 - exp(-10.0 * dens)), log(2.0) / maxf(dens, 1e-4)])
	ok(fog.has("ease_m") and is_equal_approx(FloorFog.ease_m(), float(fog.ease_m)), "floor_two.fog.ease_m read: eased over the stair's last %.1f m" % FloorFog.ease_m())
	var shade := Color(str(((Tuning.section("look", "retro").get("targets", {}) as Dictionary).get("colours", {}) as Dictionary).get("shade", "")))
	var c := FloorFog.color()
	ok(str(fog.get("color_from", "")) == "look_shade_navy" and c.is_equal_approx(shade), "its colour from the look's shade navy (color_from %s: look.json retro.targets.colours.shade #%s, LOOK_REFERENCE R3)" % [str(fog.get("color_from", "")), c.to_html(false)])
	ok(c.b > c.r and not _grey(c), "the fog's colour has blue above red and is not grey (#%s: r %.3f, g %.3f, b %.3f)" % [c.to_html(false), c.r, c.g, c.b])
	var dark := FloorFog.haze_color()
	ok(_luma(c) > _luma(dark) and c.b - c.r > dark.b - dark.r, "lighter and bluer than the tomb's own dark (#%s against crawler.json look fog_color #%s): distance on floor two goes lighter and bluer, never darker" % [c.to_html(false), dark.to_html(false)])
	var h1 := FloorFog.look_haze(1.0)
	var hc: Color = h1.color
	var h0 := FloorFog.look_haze(0.0)
	ok(is_equal_approx(float(h0.density), FloorFog.haze_density()) and (h0.color as Color).is_equal_approx(dark), "the look's haze with none of it: floor one's own, as built (%.3f a metre, #%s)" % [float(h0.density), (h0.color as Color).to_html(false)])
	ok(is_equal_approx(float(h1.density), FloorFog.haze_density() + dens) and hc.b > hc.r and not _grey(hc) and _luma(hc) > _luma(dark), "the look's haze on floor two: floor one's %.3f and the fog's %.3f a metre, their colours mixed by them (#%s): blue above red, not grey, lighter than floor one's" % [FloorFog.haze_density(), dens, hc.to_html(false)])


# --- 2. Where it is ---------------------------------------------------------------

func _layouts(seeds: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var one_ok := true
	var two_ok := true
	var n1 := 0
	var n2 := 0
	var none_above := true
	var full_at_foot := true
	var rises := true
	var smooth := true
	var where_ok := true
	var held_ok := true
	var held_n := 0
	var e := FloorFog.ease_m()
	var max_step := 0.0
	var allowed := 1.5 * 0.05 / maxf(e, 0.05) + 1e-4
	var seen_layouts := 0
	for s in seeds:
		var lay := TombKit.layout(int(s))
		if not lay.has("descent"):
			ok(false, "seed %d has a stair down (floor two)" % s)
			continue
		seen_layouts += 1
		var dsc: Dictionary = lay.descent
		var stair_id := int(dsc.stair)
		for pc in lay.pieces:
			if int(pc.id) == stair_id:
				continue
			var c2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5
			var at := Vector3(c2.x, Delves.floor_of(pc, float(pc.len) * 0.5) + PlanetPlayer.EYE_Y, c2.y)
			var sh := FloorFog.share_at(lay, at, 0.5)
			if int(pc.get("floor", 0)) == 0:
				n1 += 1
				if sh != 0.0:
					one_ok = false
					print("  seed %d: floor one's %s %d at %s has %.2f of the fog" % [s, pc.kind, pc.id, str(at), sh])
			else:
				n2 += 1
				if sh != 1.0:
					two_ok = false
					print("  seed %d: floor two's %s %d at %s has %.2f of the fog" % [s, pc.kind, pc.id, str(at), sh])
		# Down the flight, every 5 cm from just inside the room it leaves to
		# just past its foot.
		var top: Vector3 = dsc.top
		var bottom: Vector3 = dsc.bottom
		var down: Vector3 = dsc.down
		var run := (bottom - top).dot(down)
		var drop := top.y - bottom.y
		var last := -1.0
		var k := -0.5
		while k <= run + 0.5 + 1e-6:
			var t := clampf(k / maxf(run, 0.01), 0.0, 1.0)
			var pos := top + down * k + Vector3(0.0, -drop * t + PlanetPlayer.EYE_Y, 0.0)
			var sh := FloorFog.share_at(lay, pos, 0.5)
			if k <= run - e - 0.01 and sh != 0.0:
				none_above = false
			if k >= run - 1e-4 and sh < 0.9999:
				full_at_foot = false
			if last >= 0.0:
				if sh < last - 1e-6:
					rises = false
				max_step = maxf(max_step, sh - last)
				if sh - last > allowed:
					smooth = false
			last = sh
			k += 0.05
		# And off to the side of the flight, it is the floors' own.
		var foot := _foot_target(lay)
		if FloorFog.share_at(lay, foot + Vector3(0.0, PlanetPlayer.EYE_Y, 0.0), 0.5) != 1.0:
			where_ok = false
		# Held in a doorway's thickness (between two pieces, the stair's own
		# two doors aside).
		for d in lay.doors:
			if int(d.a) == stair_id or int(d.b) == stair_id:
				continue
			var p2: Vector2 = d.p
			var at := Vector3(p2.x, float(d.y) + PlanetPlayer.EYE_Y, p2.y)
			if TombKit.piece_at(lay, at) >= 0:
				continue
			held_n += 1
			if not is_equal_approx(FloorFog.share_at(lay, at, 0.37), 0.37):
				held_ok = false
			break
	ok(one_ok and n1 > 0, "%d layouts: none of the fog at every piece of floor one (%d pieces)" % [seen_layouts, n1])
	ok(two_ok and n2 > 0 and where_ok, "all of it at every piece of floor two (%d pieces): one fog across the whole floor, uniform" % n2)
	ok(none_above and full_at_foot, "down the flight: none above its last %.1f m, all of it at its foot" % e)
	ok(rises and smooth, "between, rising and never back, no 5 cm step steeper than the ease's own (the steepest %.4f, at most %.4f): no pop" % [max_step, allowed])
	ok(held_ok and held_n > 0, "in a doorway's thickness (on no piece) it holds what it was (%d doorways)" % held_n)
	var keep: Variant = TombFloors.FLOORS.get("count", 2)
	TombFloors.FLOORS["count"] = 1
	var single := TombKit.layout(7)
	TombFloors.FLOORS["count"] = keep
	var hr: Dictionary = single.pieces[0]
	var hc: Vector2 = hr.c
	ok(not single.has("descent") and FloorFog.share_at(single, Vector3(hc.x, float(hr.y0) + 1.4, hc.y), 1.0) == 0.0, "a tomb of one floor (floors.count 1): no fog anywhere")
	print("  (layouts in %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))


## The point 1.5 m into floor two's first room past the flight's foot.
static func _foot_target(lay: Dictionary) -> Vector3:
	var dsc: Dictionary = lay.descent
	var b: Vector3 = dsc.bottom
	var dn: Vector3 = dsc.down
	return b + dn * (Delves.WALL + 1.5)


## A point just inside piece `pid` through door `d`, `m` in, on its floor.
static func _inside(lay: Dictionary, pid: int, d: Dictionary, m: float) -> Vector3:
	var pc: Dictionary = lay.pieces[pid]
	var p2: Vector2 = d.p
	var n2: Vector2 = d.n
	var into := n2 if int(d.b) == pid else -n2
	var q := p2 + into * m
	return Vector3(q.x, Delves.floor_of(pc, Delves.along_across(pc, q).x), q.y)


# --- 3-6. In the scene ---------------------------------------------------------------

func _scene() -> void:
	var keep := {}
	for key in ["display.preset"]:
		keep[key] = Settings.get_value(key) if Settings.has(key) else null
	Settings.set_value("display.preset", "default")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	await _frames(3)
	var lay := main.lay
	var p := main.player
	p._invulnerable = 1.0e9
	main.boss.auto = false
	var ff := main.floor_fog
	var env := main.environment
	if ff == null or not lay.has("descent"):
		ok(false, "the floor fog is in the crawler and the tomb has a floor two (%s, %s)" % [str(ff), str(lay.has("descent"))])
		_restore(keep)
		return
	# Waking on floor one.
	var ld: float = Look._params.get("look_fog_density", -1.0)
	var lc: Color = Look._params.get("look_fog_color", Color.BLACK)
	ok(ff.share == 0.0 and not env.fog_enabled and is_equal_approx(ld, FloorFog.haze_density()) and lc.is_equal_approx(FloorFog.haze_color()),
		"waking on floor one: the environment's fog off, the look's haze floor one's own, as before (%.3f a metre, #%s)" % [ld, lc.to_html(false)])
	var grade0 := _grade(main)
	ok(Display.lines() == 480 and get_root().content_scale_size == Vector2i(854, 480), "the frame at the default 480 lines on floor one (%dx%d)" % [get_root().content_scale_size.x, get_root().content_scale_size.y])
	# On floor two.
	var dsc: Dictionary = lay.descent
	var foot := _foot_target(lay)
	p.spawn_flat(foot, atan2(-(dsc.down as Vector3).x, -(dsc.down as Vector3).z), 0.0)
	await _frames(4)
	var fc := env.fog_light_color
	ld = Look._params.get("look_fog_density", -1.0)
	lc = Look._params.get("look_fog_color", Color.BLACK)
	ok(ff.share == 1.0 and env.fog_enabled and env.fog_mode == Environment.FOG_MODE_EXPONENTIAL and is_equal_approx(env.fog_density, FloorFog.density()) and fc.is_equal_approx(FloorFog.color()) and is_equal_approx(env.fog_light_energy, 1.0),
		"on floor two the environment's fog on at the data's density (%.3f a metre, exponential) in the shade navy (#%s)" % [env.fog_density, fc.to_html(false)])
	ok(fc.b > fc.r and not _grey(fc) and lc.b > lc.r and not _grey(lc), "the fog's colour on screen's way: blue above red, not grey (the environment's #%s, the look's haze #%s)" % [fc.to_html(false), lc.to_html(false)])
	ok(is_equal_approx(ld, FloorFog.haze_density() + FloorFog.density()), "and the look's haze, which the stone, the sprites and the folk draw, floor one's %.3f with it added (%.3f a metre)" % [FloorFog.haze_density(), ld])
	var grade1 := _grade(main)
	ok(Display.lines() == 480 and get_root().content_scale_size == Vector2i(854, 480) and grade1 == grade0 and is_equal_approx(float(grade1.dither), float(Tuning.section("look", "retro").get("dither", 1.0))) and is_equal_approx(float(grade1.levels), 31.0),
		"the frame on floor two still the default 480 lines (%dx%d), nearest-neighbour, the grade's dither as before (dither %.2f, %d levels a channel)" % [get_root().content_scale_size.x, get_root().content_scale_size.y, float(grade1.dither), int(grade1.levels)])
	await _only_fog(main)
	await _down_and_up(main)
	# Back on the mat by the hearth (as waking after "Good night").
	var w: Array = lay.wake
	p.spawn_flat(foot, 0.0, 0.0)
	await _frames(3)
	var was_on := ff.share == 1.0 and env.fog_enabled
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(2)
	ld = Look._params.get("look_fog_density", -1.0)
	ok(was_on and ff.share == 0.0 and not env.fog_enabled and is_equal_approx(ld, FloorFog.haze_density()), "from floor two back on the mat by the hearth (as waking after \"Good night\"): the fog off again at once, the haze floor one's")
	_restore(keep)
	main.queue_free()
	await process_frame
	await process_frame


func _restore(keep: Dictionary) -> void:
	for key in keep:
		if keep[key] == null:
			Settings.erase(key)
		else:
			Settings.set_value(key, keep[key])


## The grade's dither and levels (PostGrade's material).
func _grade(main: CrawlerMain) -> Dictionary:
	var mat := main.post._rect.material as ShaderMaterial
	return {"dither": mat.get_shader_parameter("dither"), "levels": mat.get_shader_parameter("levels"), "bleed": mat.get_shader_parameter("bleed"), "grain": mat.get_shader_parameter("grain")}


## Only fog (5): pinned off, then on, in one frame at one place.
func _only_fog(main: CrawlerMain) -> void:
	var p := main.player
	var ff := main.floor_fog
	_torch_in_hand(p)
	p.torch.light()
	await _frames(6)
	ff.force_share = 0.0
	ff.update_now()
	var off := _snapshot(main)
	ff.force_share = 1.0
	ff.update_now()
	var on := _snapshot(main)
	ff.force_share = -1.0
	ff.update_now()
	var differ: Array = []
	for k in off:
		if k in ["fog", "look_fog"]:
			continue
		if str(off[k]) != str(on[k]):
			differ.append(k)
	ok(off.light_n > 0 and off.light == on.light, "only fog: the light field's number on every square the same with it on and off (%d squares, %.1f in all)" % [int(off.light_n), float(off.light_sum)])
	ok(off.seen == on.seen and off.seen.size() > 0, "what a skeleton would count as seen at %d points round you the same (%d seen)" % [off.seen.size(), off.seen.count(true)])
	ok(off.boss_view == on.boss_view and off.noise == on.noise, "whether the snake is in view, and how loud you are to what listens, the same (%s, %.2f)" % [str(off.boss_view), float(off.noise)])
	ok(off.torch == on.torch and off.half_dark == on.half_dark and off.fires == on.fires, "the torch's light, the half-dark's and every fire's light the same (the torch's reach %.1f m, its strength %.2f)" % [float((off.torch as Array)[1]), float((off.torch as Array)[0])])
	ok(differ.is_empty(), "and the grade, the environment and every other value of the look the same%s" % ("" if differ.is_empty() else ": %s differ" % str(differ)))
	ok(str(off.fog) != str(on.fog) and str(off.look_fog) != str(on.look_fog), "only the fog's own values differ (the environment's fog on %s at %.3f a metre against off, the look's haze %.3f against %.3f)" % [str(on.fog.fog_enabled), float(on.fog.fog_density), float(on.look_fog.look_fog_density), float(off.look_fog.look_fog_density)])


## Everything a fog must not touch, now: {"light" (every square), "seen",
## "boss_view", "noise", "torch", "half_dark", "fires", "grade", "env",
## "look", and the fog's own "fog" and "look_fog"}.
func _snapshot(main: CrawlerMain) -> Dictionary:
	var res := main.residents
	var lf: LightField = res.light
	var lv := PackedFloat32Array() if lf == null else lf.level.duplicate()
	var sum := 0.0
	for v in lv:
		sum += v
	var seen: Array = []
	var p := main.player
	var at := p.global_position
	for r in [2.0, 5.0, 9.0, 14.0]:
		for i in 8:
			var a := TAU * i / 8.0
			seen.append(res.seen_at(at + Vector3(sin(a) * r, 0.0, cos(a) * r)))
	var tl: OmniLight3D = p.torch._light
	var hd: OmniLight3D = main.half_dark.light
	var fires: Array = []
	for n in main.get_tree().get_nodes_in_group(Campfire.GROUP):
		for l in (n as Node).find_children("*", "Light3D", true, false):
			var L := l as Light3D
			fires.append([L.light_energy, L.light_color, L.visible])
	var env := main.environment
	var env_rest := {}
	var env_fog := {}
	for prop in env.get_property_list():
		var nm := str(prop.name)
		if int(prop.usage) & PROPERTY_USAGE_STORAGE == 0:
			continue
		if nm.begins_with("fog_"):
			env_fog[nm] = env.get(nm)
		else:
			env_rest[nm] = env.get(nm)
	var look := Look._params.duplicate()
	var look_fog := {"look_fog_density": look.get("look_fog_density"), "look_fog_color": look.get("look_fog_color")}
	look.erase("look_fog_density")
	look.erase("look_fog_color")
	return {"light": lv, "light_n": lv.size(), "light_sum": sum, "seen": seen, "boss_view": main.boss._in_view(), "noise": p.noise_level,
		"torch": [tl.light_energy if tl != null else 0.0, tl.omni_range if tl != null else 0.0, tl.light_color if tl != null else Color.BLACK, tl.visible if tl != null else false],
		"half_dark": [hd.light_energy if hd != null else 0.0, hd.omni_range if hd != null else 0.0, hd.visible if hd != null else false],
		"fires": fires, "grade": _grade(main), "env": env_rest, "look": look, "fog": env_fog, "look_fog": look_fog}


## Down the stair onto floor two and back up (4), the way down open, the
## fog read every frame.
func _down_and_up(main: CrawlerMain) -> void:
	var lay := main.lay
	var dsc: Dictionary = lay.descent
	var dd: Dictionary = lay.doors[int(dsc.door)]
	var p := main.player
	var ff := main.floor_fog
	var env := main.environment
	main.fork.open_now(true)
	await _frames(3)
	p.typing = false
	p.ui_open = false
	var top := _inside(lay, int(dsc.host), dd, 1.5)
	var bottom := _foot_target(lay)
	var run := ((dsc.bottom as Vector3) - (dsc.top as Vector3)).dot(dsc.down as Vector3)
	var e := FloorFog.ease_m()
	var dens := FloorFog.density()
	var down_rec: Array = []
	var r1 := await _walk_leg(p, top, bottom, func() -> void: down_rec.append([_along(main), env.fog_density if env.fog_enabled else 0.0, ff.share]))
	var up_rec: Array = []
	var r2 := await _walk_leg(p, bottom, top, func() -> void: up_rec.append([_along(main), env.fog_density if env.fog_enabled else 0.0, ff.share]))
	for leg in [["down", down_rec, r1], ["up", up_rec, r2]]:
		var rec: Array = leg[1]
		var first_on := INF
		var full_at := INF
		var last_off := -INF
		var jump := 0.0
		var prev := -1.0
		var start_d := float((rec[0] as Array)[1]) if not rec.is_empty() else -1.0
		var end_d := float((rec[-1] as Array)[1]) if not rec.is_empty() else -1.0
		for r in rec:
			var al := float(r[0])
			var dn := float(r[1])
			if dn > 1e-6:
				first_on = minf(first_on, al)
			else:
				last_off = maxf(last_off, al)
			if dn >= dens * 0.999:
				full_at = minf(full_at, al)
			if prev >= 0.0:
				jump = maxf(jump, absf(dn - prev))
			prev = dn
		var going_down := str(leg[0]) == "down"
		print("  %s the stair (%d frames, walked %s): the fog first in at %.2f m down the flight (its last %.1f m begin at %.2f), full from %.2f m (its foot at %.2f); the largest change in a frame %.5f of %.3f" % [leg[0], rec.size(), str((leg[2] as Dictionary).ok), first_on, e, run - e, full_at, run, jump, dens])
		var bounds_ok := first_on >= run - e - 0.35 and full_at <= run + 0.35 and full_at >= run - 0.35
		var ends_ok := (is_equal_approx(start_d, 0.0) and is_equal_approx(end_d, dens)) if going_down else (is_equal_approx(start_d, dens) and is_equal_approx(end_d, 0.0))
		ok(bool((leg[2] as Dictionary).ok) and ends_ok and bounds_ok and jump <= dens / 20.0 + 1e-6,
			"%s: %s over the stair's last %.1f m (from %.2f m down it to its foot at %.2f), never more than a twentieth of it in a frame (%.5f): no pop" % ["your body walks down the stair onto floor two, the fog easing in" if going_down else "and back up, the fog easing out", "none to full" if going_down else "full to none", e, first_on, run, jump])
	ok(not env.fog_enabled and ff.share == 0.0, "back up in the room the stair leaves: the environment's fog off, none of it (floor one has none)")


## How far down the flight your eye is, from its mouth (m).
func _along(main: CrawlerMain) -> float:
	var dsc: Dictionary = main.lay.descent
	var cam := main.get_viewport().get_camera_3d()
	var at: Vector3 = cam.global_position if cam != null else main.player.global_position
	return (at - (dsc.top as Vector3)).dot(dsc.down as Vector3)


func _torch_in_hand(p: CrawlerPlayer) -> void:
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"


## Walk the body from `from` to `to` like a player would (fork_check's
## _walk_leg), `each` called every frame: {"ok", "m", "at"}.
func _walk_leg(p: CrawlerPlayer, from: Vector3, to: Vector3, each: Callable, max_s := 20.0) -> Dictionary:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	p.spawn_flat(from, atan2(-flat.x, -flat.y), 0.0)
	await _frames(3)
	Input.action_press("move_forward")
	var best := INF
	var since := 0
	var dodge := 0
	var side := 1.0
	var ok_ := false
	var start := p.global_position
	for i in int(max_s * 60.0):
		var here := p.global_position
		var go := Vector2(to.x - here.x, to.z - here.z)
		if go.length() < 0.45 and absf(here.y - to.y) < 0.7:
			ok_ = true
			break
		p._yaw = atan2(-go.x, -go.y)
		if dodge > 0:
			dodge -= 1
			if dodge == 0:
				Input.action_release("move_left")
				Input.action_release("move_right")
		elif since > 30:
			side = -side
			dodge = 26
			since = 0
			Input.action_press("move_left" if side < 0.0 else "move_right")
		await physics_frame
		await process_frame
		each.call()
		var dd := Vector2(to.x - p.global_position.x, to.z - p.global_position.z).length()
		if dd < best - 0.05:
			best = dd
			since = 0
		else:
			since += 1
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	# A few frames standing, so the last of it is read.
	for i in 3:
		await process_frame
		each.call()
	return {"ok": ok_, "m": start.distance_to(p.global_position), "at": p.global_position.snapped(Vector3.ONE * 0.01)}
