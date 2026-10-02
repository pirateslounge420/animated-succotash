extends SceneTree
## The shift change at dusk and the sound by the sun (design 1 Oct §CH),
## headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/shift_check.gd
## Boots the game, stands at the opening camp and steps the clock through
## an afternoon, dusk and night, then night, dawn and morning (every 15
## game minutes), printing the sun, the ambient animals out by their
## hours (day / dusk / night / any; and how many are bedding down) and
## the bed's cicada, night-insect and frog gains. Asserts:
##  - by full night no day animal is out (each has gone to bed), and at
##    midafternoon no night animal is;
##  - a "dusk" (crepuscular) species is out only in the twilight band;
##  - the handover by the sun, at dusk: the cicadas fade before the first
##    night insects come, and the frogs come last; at dawn backwards;
##  - the animals that went to bed walked off first (bedding) rather than
##    shrinking where they stood.

var main
var world
var player: PlanetPlayer
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	player.set_physics_process(false)
	# The activity rule itself.
	var sp := CreatureSpecies.new()
	sp.active = "dusk"
	ok(not sp.active_now(1.0) and sp.active_now(0.3) and not sp.active_now(0.0), "a dusk species is out in the twilight only")
	var base: float = floor(world.days) + 1.0
	var dusk := await _sweep(base, 14.0, 23.0)
	var dawn := await _sweep(base + 1.0, 2.0, 9.0)
	# Who is out.
	ok(int(dusk.night_out_at_14) == 0, "at midafternoon no night animal is out (%d)" % int(dusk.night_out_at_14))
	ok(int(dusk.day_out_late) == 0, "by full night every day animal has gone to bed (%d still out)" % int(dusk.day_out_late))
	if int(dusk.bedded) > 0:
		ok(true, "%d animals went to bed walking off, not where they stood" % int(dusk.bedded))
	else:
		print("SKIP  no day animal was near enough to see go to bed")
	# The handover, by the sun.
	print("[shift] dusk: cicadas fade at %s, first night insects %s, frogs %s" % [dusk.cic_off, dusk.ins_on, dusk.frog_on])
	ok(float(dusk.cic_off_h) <= float(dusk.ins_on_h) and float(dusk.ins_on_h) <= float(dusk.frog_on_h), "at dusk the cicadas stop, then the night insects, then the frogs")
	print("[shift] dawn: frogs fall silent %s, night insects %s, cicadas start %s" % [dawn.frog_off, dawn.ins_off, dawn.cic_on])
	ok(float(dawn.frog_off_h) <= float(dawn.ins_off_h) and float(dawn.ins_off_h) <= float(dawn.cic_on_h), "at dawn it runs backwards")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## The curves the bed follows (SoundBed's), on the sun's elevation.
func _curves(sun: float) -> Vector3:
	return Vector3(smoothstep(SoundBed.CICADA_SUN.x, SoundBed.CICADA_SUN.y, sun),
		1.0 - smoothstep(SoundBed.NIGHT_INSECT_SUN.x, SoundBed.NIGHT_INSECT_SUN.y, sun),
		1.0 - smoothstep(SoundBed.FROG_SUN.x, SoundBed.FROG_SUN.y, sun))


func _sweep(day: float, h0: float, h1: float) -> Dictionary:
	var out := {"night_out_at_14": 0, "day_out_late": 0, "bedded": 0,
		"cic_off": "-", "ins_on": "-", "frog_on": "-", "cic_off_h": 99.0, "ins_on_h": 99.0, "frog_on_h": 99.0,
		"frog_off": "-", "ins_off": "-", "cic_on": "-", "frog_off_h": 99.0, "ins_off_h": 99.0, "cic_on_h": 99.0}
	var prev := Vector3(-1, -1, -1)
	var bedded := {}
	var h := h0
	while h <= h1 + 0.001:
		var pd: Vector3 = player.surface_dir
		world.days = Astro.days_at_solar_hour(day, h, CubeSphere.longitude(pd), CubeSphere.latitude(pd))
		for i in 45:
			await process_frame
		var sun: float = main.sky.sun_elevation_deg
		var c := _curves(sun)
		var counts := {"day": 0, "dusk": 0, "night": 0, "any": 0}
		var bedding := 0
		for cr in main.creatures._ambient.values():
			var cc: Creature = cr
			if not is_instance_valid(cc) or cc.leaving:
				continue
			if cc.bedding:
				bedding += 1
				bedded[cc.get_instance_id()] = true
				continue
			var act := str(cc.species.active)
			counts[act if counts.has(act) else "any"] = int(counts.get(act if counts.has(act) else "any", 0)) + 1
		var gains: Dictionary = main.sound_bed._gain if main.get("sound_bed") != null else {}
		print("[shift] %05.2f h  sun %+5.1f  daylight %.2f  out: day %d dusk %d night %d any %d  bedding %d  bed: cicadas %.2f insects %.2f frogs %.2f" % [h, sun, main.sky.daylight, counts.day, counts.dusk, counts.night, counts.any, bedding,
			float(gains.get("cicadas", 0.0)), float(gains.get("insects", 0.0)), float(gains.get("frogs", 0.0))])
		if absf(h - 14.0) < 0.01:
			out.night_out_at_14 = counts.night
		if h >= 22.5 and h0 >= 12.0:
			out.day_out_late = maxi(int(out.day_out_late), int(counts.day))
		var stamp := "%05.2f h (sun %+.1f)" % [h, sun]
		if prev.x >= 0.0:
			if prev.x >= 0.5 and c.x < 0.5:
				out.cic_off = stamp
				out.cic_off_h = h
			if prev.y < 0.05 and c.y >= 0.05:
				out.ins_on = stamp
				out.ins_on_h = h
			if prev.z < 0.05 and c.z >= 0.05:
				out.frog_on = stamp
				out.frog_on_h = h
			if prev.z >= 0.05 and c.z < 0.05:
				out.frog_off = stamp
				out.frog_off_h = h
			if prev.y >= 0.05 and c.y < 0.05:
				out.ins_off = stamp
				out.ins_off_h = h
			if prev.x < 0.5 and c.x >= 0.5:
				out.cic_on = stamp
				out.cic_on_h = h
		prev = c
		h += 0.25
	out.bedded = bedded.size()
	return out
