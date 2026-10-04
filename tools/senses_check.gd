extends SceneTree
## Your light gives you away (design 3 Oct §DF, data/senses.json, Senses),
## headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/senses_check.gd
##  - a lurker 400 m off at night with a clear line sees your lit torch and
##    not you dark; with a hill between, neither;
##  - a day animal 60 m off at night: not at new moon, yes at full moon;
##  - a werewolf 300 m downwind smells you, 300 m upwind does not;
##  - the decoy: plant a torch, walk 50 m into the dark: the hunter's
##    target is the torch, and it ends at the torch's circle, not at you;
##  - a sprint heard at hearing_m, sneaking only at a fifth of it;
##  - goblin_band and stranger still built false.

var fails := 0
var main: Node
var world: Node


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
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var player: PlanetPlayer = main.player
	main.dread.enabled = false
	Senses.override = {"daylight": 0.0, "moonlight": 0.0, "noise": 0.0, "wind": Vector3.ZERO}
	ok(not Senses.built("goblin_band") and not Senses.built("stranger"), "goblin_band and stranger still built false (§DH, §DF open)")
	ok(not str((Senses.D.get("_help", {}) as Dictionary).get("about", "")).contains("NOT WIRED"), "senses.json is wired (no NOT WIRED prefix)")

	# --- A lit torch at 400 m, and a hill. ---
	var eye: Vector3 = player.eye_position()
	var pd: Vector3 = player.surface_dir
	var clear := _watcher_at(pd, 400.0, true)
	var hill := _watcher_at(pd, 400.0, false)
	print("   at the camp: a clear 400 m line on bearing %s, a hill in the way on %s" % [str(clear.get("bearing", "none")), str(hill.get("bearing", "none"))])
	ok(not clear.is_empty() and not hill.is_empty(), "a clear line and a blocked one, 400 m out")
	_give_torch(player, false)
	if not clear.is_empty():
		var dark := Senses.can_sense("lurker", clear.eye, player)
		_give_torch(player, true)
		await process_frame
		var lit := Senses.can_sense("lurker", clear.eye, player)
		ok(lit == "light" and dark == "", "a lurker 400 m off, clear line, at night: torch lit -> '%s', dark -> '%s'" % [lit, dark])
	if not hill.is_empty():
		_give_torch(player, true)
		await process_frame
		var lit := Senses.can_sense("lurker", hill.eye, player)
		_give_torch(player, false)
		var dark := Senses.can_sense("lurker", hill.eye, player)
		ok(lit == "" and dark == "", "with a hill between: torch lit -> '%s', dark -> '%s'" % [lit, dark])
	_give_torch(player, false)

	# --- A day animal at 60 m by the moon. ---
	var near := _watcher_at(pd, 60.0, true)
	ok(not near.is_empty(), "a clear 60 m line")
	if not near.is_empty():
		Senses.override.moonlight = 0.0
		var new_moon := Senses.can_sense("day_animal", near.eye, player)
		Senses.override.moonlight = 1.0
		var full_moon := Senses.can_sense("day_animal", near.eye, player)
		print("   day animal sight: %.0f m at new moon, %.0f m at full" % [_sight_at("day_animal", 0.0), _sight_at("day_animal", 1.0)])
		ok(new_moon == "" and full_moon == "sight", "a day animal 60 m off at night, you dark: new moon '%s', full moon '%s'" % [new_moon, full_moon])
		Senses.override.moonlight = 0.0

	# --- The werewolf's nose, 300 m downwind and upwind. ---
	var up := pd
	var east := CubeSphere.east(pd)
	var body := player.global_position
	var down_eye: Vector3 = body + east * 300.0
	var up_eye: Vector3 = body - east * 300.0
	Senses.override.wind = east * 4.0
	var downwind := Senses.can_sense("werewolf", down_eye, player)
	var upwind := Senses.can_sense("werewolf", up_eye, player)
	ok(downwind == "scent" and upwind == "", "a werewolf 300 m downwind: '%s'; 300 m upwind: '%s'" % [downwind, upwind])
	Senses.override.wind = Vector3.ZERO

	# --- Hearing. ---
	var hm := float(Senses.row("lurker").get("hearing_m", 60.0))
	var far_ear := player.eye_position() + east * (hm - 1.0)
	var fifth_ear := player.eye_position() + east * (hm * 0.2 - 1.0)
	var sprint := Senses.can_sense("lurker", far_ear, player, 1.0)
	var sneak_far := Senses.can_sense("lurker", far_ear, player, 0.12)
	var sneak_near := Senses.can_sense("lurker", fifth_ear, player, 0.12)
	var walk_half := Senses.can_sense("lurker", player.eye_position() + east * (hm * 0.5 - 1.0), player, 0.4)
	ok(sprint == "hearing" and sneak_far == "" and sneak_near == "hearing" and walk_half == "hearing", "heard: sprinting at %.0f m '%s'; sneaking there '%s', at %.0f m '%s'; walking at %.0f m '%s'" % [hm - 1.0, sprint, sneak_far, hm * 0.2 - 1.0, sneak_near, hm * 0.5 - 1.0, walk_half])

	# --- The decoy (§DF.3). ---
	var dread: Dread = main.dread
	var start := player.surface_dir
	# Plant a lit torch where you stand.
	var tit := Inventory.make("torch", {"lit": true, "burn_left_min": 50.0})
	var tpos: Vector3 = world.to_scene(start, PlanetConst.RADIUS_M + main.chunks.ground_height(start))
	var planted := PlantedTorch.plant(tit, world, tpos, start)
	# Walk 50 m into the dark, the way with a clear line back to it.
	var walk := _watcher_at(start, 50.0, true)
	var away: Vector3 = CreatureSpawner._offset(start, float(walk.get("bearing", 0.0)), 50.0)
	player.spawn_at(away, start)
	for i in 10:
		await process_frame
	# The hunter, 60 m off the torch on the far side from you.
	dread.enabled = true
	dread.force_dark = true
	dread.meter = 0.85
	await process_frame
	await process_frame
	dread.meter = 0.85
	# (A spot 60 m off that sees the torch head, as far round from you as
	# can be found.)
	var head: Vector3 = planted.global_position + planted.up * 0.9
	var hunter_at: Vector3 = CreatureSpawner._offset(start, float(walk.get("bearing", 0.0)) + PI, 60.0)
	for k in 36:
		var b := float(walk.get("bearing", 0.0)) + PI + (1.0 if k % 2 == 0 else -1.0) * TAU * (k / 2) / 36.0
		var hd := CreatureSpawner._offset(start, b, 60.0)
		var he: Vector3 = world.to_scene(hd, PlanetConst.RADIUS_M + main.chunks.ground_height(hd) + 1.6)
		if Senses.clear_line(he, head, [player.get_rid()]):
			hunter_at = hd
			break
	dread._place_hunter(hunter_at, true)
	dread._sense_t = 0.0
	var q := dread.quarry(1.0)
	var to_torch := (q.get("pos", Vector3.INF) as Vector3).distance_to(planted.global_position + planted.up * 0.9) if not q.is_empty() else INF
	print("   the hunter (%s, 60 m off the torch, you 50 m the other side): goes to %s by '%s'" % [dread.watcher_kind(), str(q.get("what", "nothing")), str(q.get("by", ""))])
	ok(str(q.get("what", "")) == "torch" and to_torch < 1.5, "the decoy: the hunter's target is the torch (%.1f m from it)" % to_torch)
	# Let it go for 25 s: it ends at the torch's circle, not at you.
	var keep_meter := 0.85
	for i in 1500:
		dread.meter = keep_meter
		await process_frame
	var at_torch := CubeSphere.surface_distance_m(dread._hunter_dir, start)
	var at_you := CubeSphere.surface_distance_m(dread._hunter_dir, player.surface_dir)
	var circle := float(Torch.L.get("range_m", 14.0))
	ok(not player.dead and at_torch <= circle + 3.0 and at_you > 30.0, "after 25 s it stands %.1f m from the torch (circle %.0f m), %.1f m from you; you %s" % [at_torch, circle, at_you, "dead" if player.dead else "alive"])
	dread.force_dark = false
	dread.meter = 0.0
	Senses.override = {}
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _sight_at(kind: String, moon: float) -> float:
	var was: Dictionary = Senses.override.duplicate()
	Senses.override.moonlight = moon
	var m := Senses.sight_m(kind)
	Senses.override = was
	return m


## A watcher's eye `dist_m` off surface direction `d` (1.6 m up), on the
## first of 72 bearings whose line to the player's eye is clear (`want`
## true) or blocked by the ground (`want` false). {"eye", "bearing"} or {}.
func _watcher_at(d: Vector3, dist_m: float, want: bool) -> Dictionary:
	var player: PlanetPlayer = main.player
	var their: Vector3 = player.eye_position()
	for j in 72:
		var b := TAU * j / 72.0
		var wd := CreatureSpawner._offset(d, b, dist_m)
		var e: Vector3 = world.to_scene(wd, PlanetConst.RADIUS_M + main.chunks.ground_height(wd) + 1.6)
		if main.chunks.water_level_at(wd) > main.chunks.ground_height(wd):
			continue
		var c := Senses.clear_line(e, their, [player.get_rid()])
		if c == want:
			if not want:
				# Blocked by the ground, not just a trunk: the ground march.
				if not _ground_blocks(e, their):
					continue
			return {"eye": e, "bearing": b}
	return {}


func _ground_blocks(a: Vector3, b: Vector3) -> bool:
	var n := 128
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		var dp: Vector3 = world.dir_of(p)
		if world.radius_of(p) < PlanetConst.RADIUS_M + main.chunks.ground_height(dp) - 0.2:
			return true
	return false


## A torch in hand, lit or not.
func _give_torch(player: PlanetPlayer, lit: bool) -> void:
	var it: Dictionary = player.torch.item()
	if it.is_empty():
		it = Inventory.make("torch")
		player.inventory.carried.append(it)
	player.weapon = "torch"
	if lit and not bool(it.get("lit", false)):
		player.torch.light()
	elif not lit:
		it["lit"] = false
		player.torch._apply(false)
