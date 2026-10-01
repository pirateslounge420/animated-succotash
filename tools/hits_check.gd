extends SceneTree
## Hit parts and hit feedback check (the designer's item 10, "PSO-style
## health and hit feedback"). Starts the game on the dev stamp
## (scenes/main.tscn, data/dev.json), then measures, headless:
##   1. deer, one arrow each (a fresh deer for each, in the opening camp's clearing,
##      the arrow launched 2.5 m from the part at full speed, so the bow's
##      own damage curve is out of it): into the torso, the head, the right
##      eye and a hind shin. Prints the damage the arrow carried, the
##      damage dealt and its multiplier, critical or not, the deer's hit
##      points, and what the wound did: the eye blinds the right side (how
##      close you get on each side before it bolts), the shin lames it (its
##      flight speed against the torso-shot deer's);
##   2. a kill: the X holds longer than a critical's (seconds shown);
##   3. two hits on one deer in the same physics frame: one number;
##   4. camp folk: an arrow into the opening camp's elder's head: a
##      critical number, their complaint, no harm;
##   5. the player: 60 s idle away from any fire at 50 health (no
##      regeneration), 20 s standing by the opening camp's fire (resting
##      heals at the table's rate), and the Phase 10 hook heal().
## With --shots (and a display) it saves three stills to $OUT_DIR instead
## of 1-5's numbers: a deer 8 m ahead in first person, an arrow into its
## head: the crit X and the number just risen (hits_crit_x.png), the
## number half a second on with the health meter at 64 (hits_number.png),
## and an ordinary body hit's white number (hits_body.png).
##
## Run from the project folder:
##   numbers:  ~/bin/godot --headless --fixed-fps 60 -s tools/hits_check.gd
##   stills:   xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --path . --rendering-method forward_plus --resolution 960x540 --fixed-fps 30 -s tools/hits_check.gd -- --shots
## Writes to $OUT_DIR (default /tmp/shots). Exit code 1 if a check fails.

const WATCHDOG_S := 1800.0

var out_dir := "/tmp/shots"
var main
var world
var player: PlanetPlayer
var fails: Array[String] = []
var _started_ms := 0


func _initialize() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		out_dir = env_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = get_root().get_node("World")
	world.pin(42, 0)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started_ms > WATCHDOG_S * 1000.0:
		push_error("[hits] watchdog: still running after %d s, quitting" % int(WATCHDOG_S))
		quit(2)
	return false


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	print("[hits] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails.append(what)


func _run() -> void:
	while not main._playing:
		await process_frame
	player = main.player
	# Clear, still weather, midday.
	main._weather_timer = 1e9
	main._local_weather = {"wind": Vector3(0.3, 0, 0.2), "rain_mm_h": 0.0, "snow": false, "temp_c": 16.0, "storm": 0.0, "clear": 1.0, "cloud": 0.1}
	world.days = Astro.days_at_solar_hour(world.days, 12.5, CubeSphere.longitude(player.surface_dir), CubeSphere.latitude(player.surface_dir))
	await frames(10)
	if "--shots" in OS.get_cmdline_user_args():
		await _shots()
	else:
		await _deer_parts()
		await _kill_and_x()
		await _same_frame()
		await _folk()
		await _player_health()
		print("[hits] %s" % ("all checks passed" if fails.is_empty() else "FAILED: " + ", ".join(fails)))
	quit(0 if fails.is_empty() else 1)


# --- Deer ---------------------------------------------------------------------------

## A deer in the opening camp's clearing (no trees), `m` meters from the
## fire at bearing `bearing` (radians from north), facing out of the
## clearing, faded in, its hitboxes on. The player stands well off
## (away()), so it doesn't bolt before it's shot.
func deer(m: float, bearing: float) -> Creature:
	var sp := CreatureSpecies.find("Deer")
	SculptedBodies.wait_ready(sp)
	var cr := Creature.new()
	main.creatures.adopt(cr)
	var site: Vector3 = main.camp.site
	var d := CreatureSpawner._offset(site, bearing, m)
	cr.setup(sp, world, main.chunks, main.creatures, d, 1234)
	cr._fade = 1.0
	cr.heading = cr._tangent_to(CreatureSpawner._offset(site, bearing, m + 5.0))
	# Standing still until it's shot (idle, not wandering off mid-flight).
	cr.mode = "idle"
	cr._timer = 1e6
	# Deaf to the last shot's thud (NoiseEvents): it would bolt from it.
	NoiseEvents.clear()
	await frames(3)
	return cr


## The player 40 m from the fire, out of the way, looking at the camp.
func away() -> void:
	var site: Vector3 = main.camp.site
	player.spawn_at(CreatureSpawner._offset(site, 0.3, 40.0), site)
	await frames(20)


func part(cr: Creature, n: String) -> Node3D:
	for b in cr.hitboxes:
		if (b as Node).name == n:
			return b
	return null


## The center of a part's shape (scene position).
func center(p: Node3D) -> Vector3:
	return (p.get_child(0) as Node3D).global_position


## Loose an arrow carrying `damage` at full speed at `target` from
## `from_dir` (a unit vector from the target out to where it's loosed,
## 2.5 m off); waits for it to land.
func loose(target: Vector3, from_dir: Vector3, damage: float) -> void:
	var a := Arrow.new()
	a.world = world
	a.chunks = main.chunks
	a.camps = main.camps
	a.exclude = [player.get_rid()]
	a.damage = damage
	world.world_root.add_child(a)
	var from := target + from_dir * 2.5
	# What lies on the line (printed, so a miss says what it met instead).
	var q := PhysicsRayQueryParameters3D.create(from, target + (target - from).normalized() * 0.5)
	q.exclude = a.exclude
	q.collision_mask |= Hitboxes.LAYER
	var ray := player.get_world_3d().direct_space_state.intersect_ray(q)
	a.launch(from, (target - from).normalized() * Bow.MAX_SPEED)
	# Physics frames: the event is final one frame after it's reported.
	for i in 8:
		await physics_frame
	if Hits.last().is_empty():
		print("[hits]   (missed: the line to it meets %s; the arrow is in %s)" % [
			"nothing" if ray.is_empty() else str(ray.collider.name, " of ", Hitboxes.creature_of(ray.collider)),
			a.get_parent().name if is_instance_valid(a) and a.get_parent() else "nothing"])
		if is_instance_valid(a):
			print("[hits]   arrow %.2f m from the target, stuck %s, life %.2f" % [a.global_position.distance_to(target), a._stuck, a._life])


func _deer_parts() -> void:
	var dmg := 10.0
	await away()
	print("[hits] --- deer (hp %.1f), one arrow each carrying %.0f ---" % [CreatureSpecies.find("Deer").hp_max(), dmg])
	var rows := [["torso", "Torso", "left", dmg], ["head", "Head", "front", dmg], ["right eye", "EyeR", "right", 5.0], ["hind shin", "ShinHindL", "left", dmg]]
	var flee_speed := {}
	for r in rows:
		var cr: Creature = await deer(7.0, 0.4)
		var p := part(cr, r[1])
		if p == null:
			check(false, "deer has a %s part" % r[1])
			continue
		var right: Vector3 = cr.global_basis.x
		var fwd: Vector3 = -cr.global_basis.z
		var from_dir: Vector3 = {"left": -right, "right": right, "front": fwd}[r[2]]
		var hp0 := cr.hp
		Hits.clear()
		await loose(center(p), from_dir, r[3])
		var e := Hits.last()
		if e.is_empty():
			check(false, "%s: the arrow's hit was reported" % r[0])
			cr.leave()
			continue
		var mult := float(e.amount) / float(r[3])
		print("[hits] %-9s part %-6s carried %4.1f  dealt %4.1f (x%.1f)  critical %-5s  deer hp %.1f -> %.1f  lame %.2f  blind %s" % [
			r[0], Hits.part_of(p, 0), r[3], e.amount, mult, e.crit, hp0, cr.hp, cr.lame, cr.blind.keys()])
		match r[0]:
			"torso":
				check(is_equal_approx(mult, 1.0) and not e.crit, "torso: 1x, not critical")
			"head":
				check(is_equal_approx(mult, 2.0) and e.crit, "head: 2x and critical")
			"right eye":
				check(is_equal_approx(mult, 4.0) and e.crit and cr.blind.has("r") and not cr.blind.has("l"), "right eye: 4x, critical, blind on the right only")
				# How near you get on each side before it bolts (quiet, still).
				var probe_r: Vector3 = (cr.dir + cr.heading.cross(cr.dir) * 1e-4).normalized()
				var probe_l: Vector3 = (cr.dir - cr.heading.cross(cr.dir) * 1e-4).normalized()
				cr.suspicion = 0.0
				var ctx_r := {"player_dir": probe_r, "player_noise": 0.08}
				var ctx_l := {"player_dir": probe_l, "player_noise": 0.08}
				print("[hits]   blinded right: it bolts from you at %.1f m on its right, %.1f m on its left (unhurt: %.1f m)" % [cr._shy_m(ctx_r), cr._shy_m(ctx_l), cr.species.shy_m * (0.35 + 1.25 * 0.08)])
				check(cr._shy_m(ctx_r) < cr._shy_m(ctx_l) * 0.5, "blind side notices you much later")
			"hind shin":
				check(is_equal_approx(mult, 1.0) and not e.crit and cr.lame < 1.0, "shin: 1x, not critical, lamed")
		if r[0] in ["torso", "hind shin"]:
			# It bolts: its speed while fleeing, over a second and a half.
			var top := 0.0
			var moved := 0.0
			var d0 := cr.dir
			for i in 90:
				await physics_frame
				await process_frame
				if cr.mode == "flee":
					top = maxf(top, cr._speed_now)
			moved = CubeSphere.surface_distance_m(d0, cr.dir)
			flee_speed[r[0]] = top
			print("[hits]   %s: flees at %.2f m/s (species %.1f), %.1f m in 1.5 s" % [r[0], top, cr.species.speed_mps, moved])
		cr.leave()
	if flee_speed.has("torso") and flee_speed.has("hind shin"):
		var k: float = flee_speed["hind shin"] / maxf(flee_speed["torso"], 0.01)
		check(absf(k - float(CreatureSpecies.find("Deer").hit_table().limb_slow)) < 0.05, "shin-shot deer flees at limb_slow of the torso-shot one's speed (x%.2f)" % k)


func _kill_and_x() -> void:
	print("[hits] --- the X: critical against kill ---")
	var status: StatusHud = main.hud._status
	var cx: Dictionary = Hits.feedback().crit_x
	for kill in [false, true]:
		var cr: Creature = await deer(7.0, -0.5)
		var p := part(cr, "Head")
		status.x_left = 0.0
		Hits.clear()
		await loose(center(p), -cr.global_basis.z, 20.0 if kill else 5.0)
		# Count the frames the X shows from here.
		var shown := 0.0
		var saw_kill := false
		var waited := 0
		while status.x_left <= 0.0 and waited < 10:
			await process_frame
			waited += 1
		while status.x_left > 0.0:
			saw_kill = saw_kill or status.x_kill
			await process_frame
			shown += 1.0 / Engine.physics_ticks_per_second
		var e := Hits.last()
		print("[hits] head %s: dealt %.1f, killed %s, dead %s -> X shown %.2f s (kill color %s)" % ["kill" if kill else "hit ", e.get("amount", 0.0), e.get("killed", false), cr.dead, shown, saw_kill])
		var want := float(cx.kill_hold_s) if kill else float(cx.hold_s)
		check(absf(shown - want) < 0.05 and saw_kill == kill and cr.dead == kill, "%s X holds %.2f s" % ["kill's" if kill else "critical's", want])
		if not kill:
			cr.leave()


func _same_frame() -> void:
	print("[hits] --- two hits on one deer in one physics frame ---")
	var cr: Creature = await deer(7.0, 1.2)
	var status: StatusHud = main.hud._status
	var before: int = status.numbers.size()
	Hits.clear()
	var at := center(part(cr, "Torso"))
	cr.hurt(4.0, player.global_position, "body", at)
	cr.hurt(6.0, player.global_position, "head", at)
	await physics_frame
	await physics_frame
	await process_frame
	var n: int = status.numbers.size() - before
	var e := Hits.last()
	print("[hits] one event: %.1f (4 + 6x2), critical %s; numbers added on screen: %d" % [e.amount, e.crit, n])
	check(is_equal_approx(float(e.amount), 16.0) and e.crit and n == 1, "one combined number")
	cr.leave()


func _folk() -> void:
	print("[hits] --- camp folk: the elder's head ---")
	var elder: Node3D = main.camp._npcs[0]
	var head: Node3D = null
	for b in elder.get_meta("hitboxes"):
		if (b as Node).name == "Head":
			head = b
	if head == null:
		check(false, "the elder has a head part")
		return
	Hits.clear()
	var toward: Vector3 = (player.global_position - center(head))
	toward = (toward - world.dir_of(center(head)) * toward.dot(world.dir_of(center(head)))).normalized()
	await loose(center(head), toward, 10.0)
	var e := Hits.last()
	print("[hits] elder: part %s, number %.1f, critical %s (folk have no health: no harm)" % [Hits.part_of(head, 0), e.get("amount", 0.0), e.get("crit", false)])
	check(not e.is_empty() and e.crit and is_equal_approx(float(e.amount), 20.0), "folk head hit reads 2x critical")


# --- The player ----------------------------------------------------------------------

func _player_health() -> void:
	print("[hits] --- the player's health ---")
	var rules := Hits.healing()
	# Away from every fire: 60 m off the camp.
	var away := CreatureSpawner._offset(main.camp.site, 1.0, 60.0)
	player.spawn_at(away)
	await frames(30)
	player.hp = 50.0
	var t := 0.0
	while t < 60.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	print("[hits] 60 s idle 60 m from the fire: health 50.0 -> %.1f (near a fire: %s)" % [player.hp, player.near_fire])
	check(is_equal_approx(player.hp, 50.0), "no regeneration")
	# By the opening camp's fire, where you wake.
	player.spawn_at(main.camp.player_spot, main.camp.site)
	await frames(30)
	player.hp = 50.0
	player.healed_by.clear()
	t = 0.0
	var resting_s := 0.0
	var why := {}
	while t < 20.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if player.resting:
			resting_s += 1.0 / Engine.physics_ticks_per_second
		else:
			why["near_fire"] = int(why.get("near_fire", 0)) + int(not player.near_fire)
			why["off_floor"] = int(why.get("off_floor", 0)) + int(not player.is_on_floor())
			why["not_still"] = int(why.get("not_still", 0)) + int(player.still_time < float(rules.rest_still_s))
	if not why.is_empty():
		print("[hits]   frames not resting, by reason: %s" % why)
	var gain := player.hp - 50.0
	var fire_m: float = player.global_position.distance_to(main.camp._fire.global_position)
	print("[hits] 20 s standing %.1f m from the camp fire: health 50.0 -> %.1f, resting %.1f s, %.2f health/s (table %.2f; starts after %.1f s still)" % [
		fire_m, player.hp, resting_s, gain / maxf(resting_s, 0.01), float(rules.rest_hp_per_s), float(rules.rest_still_s)])
	check(absf(gain / maxf(resting_s, 0.01) - float(rules.rest_hp_per_s)) < 0.05 and resting_s > 20.0 - float(rules.rest_still_s) - 1.0, "rest at the fire heals at the table's rate")
	var hp0 := player.hp
	var food := player.heal(PlanetPlayer.heal_for("cooked_food"), "cooked_food")
	print("[hits] heal(cooked_food): +%.1f (%.1f -> %.1f); camp_medicine would give %.0f" % [food, hp0, player.hp, PlanetPlayer.heal_for("camp_medicine")])
	check(is_equal_approx(food, minf(float(rules.sources.cooked_food), PlanetPlayer.MAX_HP - hp0)), "heal() hook")


# --- Stills --------------------------------------------------------------------------

func shot(file: String) -> void:
	var path := out_dir.path_join(file)
	get_root().get_texture().get_image().save_png(path)
	print("[hits] saved ", path)


func _shots() -> void:
	# In the open near the camp, looking at a deer 8 m ahead.
	var here := CreatureSpawner._offset(main.camp.site, 2.2, 14.0)
	var ahead := CreatureSpawner._offset(here, 2.2, 8.0)
	player.spawn_at(here, ahead)
	player.set_view(-0.08, 0.0)
	player.hp = 64.0
	await frames(20)
	var sp := CreatureSpecies.find("Deer")
	SculptedBodies.wait_ready(sp)
	var cr := Creature.new()
	main.creatures.adopt(cr)
	cr.setup(sp, world, main.chunks, main.creatures, ahead, 99)
	cr._fade = 1.0
	cr.species = sp
	# Broadside, and not bolting while we look.
	cr.heading = CubeSphere.east(ahead)
	cr.suspicion = 0.0
	await frames(6)
	# A head shot from the camera.
	var cam := player.camera()
	var head := center(part(cr, "Head"))
	var a := Arrow.new()
	a.world = world
	a.chunks = main.chunks
	a.camps = main.camps
	a.exclude = [player.get_rid()]
	a.damage = 9.0
	world.world_root.add_child(a)
	var from := cam.global_position + (head - cam.global_position).normalized() * 1.0
	a.launch(from, (head - from).normalized() * Bow.MAX_SPEED)
	var status: StatusHud = main.hud._status
	var waited := 0
	while status.x_left <= 0.0 and waited < 30:
		await process_frame
		waited += 1
	await frames(1)
	print("[hits] hit: %s" % [Hits.last()])
	await RenderingServer.frame_post_draw
	shot("hits_crit_x.png")
	await frames(14)
	await RenderingServer.frame_post_draw
	shot("hits_number.png")
	# An ordinary hit on the body: a white number.
	await frames(30)
	cr.hurt(7.0, player.global_position, "body", center(part(cr, "Torso")))
	await frames(9)
	await RenderingServer.frame_post_draw
	shot("hits_body.png")
