extends SceneTree
## The tomb's surface (design 9 Oct §FM.7; §EW.1, §EW.7 step 2; §FK.3;
## queue 71; Surface, SurfaceGround, SurfaceBuild, SurfacePlants,
## SurfaceLife; data/worlds.json surface), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/surface_check.gd
## SURFACE_SEEDS (env) sets how many seeds the builds run over beyond 1, 7
## and 42 (default 17: twenty in all, drawn from a fixed seed); WALK_DIRS
## (default 16) how many ways the 2000 m walks go.
## Asserts:
##  1. up (the scene, SEED): some holders relit on both floors, your body
##     walks into the way out's opening and comes out on the surface at the
##     ruin over the stair (the stair's foot straight over the opening, the
##     yard round you, the stairhead's portal and steps there, you on its
##     floor at the surface level above the opening, facing out along the
##     way out), the torch you carried lit or not as it was and nothing else
##     changed, the log's line; the dungeon's nodes out of the tree, the
##     surface's in; the dungeon's environment out and the sky's drawing;
##  2. the look (§ES): the sky on the one clock; the sun the one light by day
##     (its directional light, the moon's off; no other light on the
##     surface), the shade navy (the ambient's blue), the distance lighter
##     and bluer (the haze's colour); the land in the world's biome
##     (worlds.json surface.world: its biome's ground colour, its
##     associations grown, every plant of a species its biome lists);
##  3. the one clock (§FK.3): DayCycle's phases start where 60/18/48/18 of
##     144 minutes put them; at the start of dawn, at noon, at the start of
##     dusk and at the start of night the sun up here stands at -10, 90,
##     +10 and -10 degrees, the same as the shafts' clock below
##     (Vents.sun_deg) at the same moment, both read off World.days (the
##     surface keeps no clock of its own: moved on, both move together);
##  4. ambience only: at noon and at midnight alike you go up and come down
##     (nothing gated by the hour); the hearth's stack smokes by day and
##     glows faintly at night; the creatures keep their hours;
##  5. the vents' stacks (§EV.4): every vent's top has its stack (a shaft:
##     outlets.by_ruin's form, the tomb's mound vent) or its slot (a flue) on
##     the ground straight over it;
##  6. life and finds (§EW.1, §FG): the ecology's ground creatures whose
##     climate fits the biome, on the ground inside the pocket; ruin
##     remains, old camp marks and litter clear of the stairhead, nothing of
##     them in your way out of the yard or needed;
##  7. down: your body walks back down the stairhead's steps and comes out
##     in the same dungeon (the same stone, the same layout, the same place
##     in the game) on the landing at the top of its flight, facing in, with
##     the same holders lit and no others; the log's line; everything the
##     surface changed back (the environment, the grade's night and firelit
##     whites, the look's haze, the half-dark, the camera's reach, the drone
##     and drips); and up again, the same surface as you left it, at once;
##  8. the edge (§DM, worlds.json size): the pocket within size.across_m;
##     walking 2000 m from the stair (your own body's capsule, slope and
##     step, in the surface's own collision) in WALK_DIRS ways, then again
##     sprinting and jumping, never leaves the pocket's edge into void: never
##     past the escarpment's foot, never off the ground, never falling; the
##     escarpment steeper than you can walk all the way round; no collision
##     but the land, the stone and the trunks (no invisible wall);
##  9. no map, no fast travel, no edges to other worlds (§FM.8, §EW.7): the
##     stair down the surface's only way off;
## 10. over twenty seeds the surface builds: the stair over each tomb's
##     opening, the arrival on its yard on walkable ground, your body from
##     there down into the stair's mouth, every vent's top its stack or slot,
##     each zone grown, finds and creatures there, the same land twice from
##     the same seed;
## 11. exit.stand_in stays for any dungeon with no surface (surface.on off,
##     or a theme not over_themes): Surface.covers says no.

var fails := 0
const DT := 1.0 / 60.0
const MORE_SEEDS := 17


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
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	_covers()
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked:
		await process_frame
	# The snake held still (it is the dungeon's; this is about the stair).
	if main.boss != null:
		main.boss.auto = false
	await _frames(10)
	var before := await _up(main)
	if main.on_surface:
		_look(main)
		await _clock(main)
		_stacks(main)
		await _life_and_finds(main)
		await _down(main, before)
		await _again(main)
		await _hours(main)
		_no_way_off(main)
		await _edge(main.surface, main.lay)
	main.queue_free()
	await process_frame
	await _seeds()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


# --- 11. Which dungeons have it -------------------------------------------------

func _covers() -> void:
	var S: Dictionary = Surface.S
	ok(bool(S.get("on", false)) and Surface.covers({"theme": "tomb"}), "the tomb has its surface above it (worlds.json surface.on, over_themes %s)" % str(S.get("over_themes", [])))
	ok(not Surface.covers({"theme": "snow_ruins"}), "a dungeon with no surface yet (snow_ruins) keeps exit.stand_in")
	S["on"] = false
	ok(not Surface.covers({"theme": "tomb"}), "with surface.on off the tomb keeps exit.stand_in too")
	S["on"] = true
	var w := Surface.world_entry()
	ok(str(S.get("world", "")) == "desert" and Surface.biome_key() == str(w.get("biome", "")).to_upper() and not Surface.biome_doc().is_empty(), "the surface is worlds.json worlds.%s's (biome %s, its data/biomes file read)" % [S.get("world", ""), Surface.biome_key()])


# --- 1. Up ------------------------------------------------------------------------

## Relight some holders on each floor, then walk your own body into the
## opening: you come out at the ruin over the stair. Returns what was lit,
## the stone, the layout, the place.
func _up(main: CrawlerMain) -> Dictionary:
	var p := main.player
	var t := p.torch
	var lay := main.lay
	var fires := main.fires
	var pick: Array[int] = []
	for f in TombFloors.floors_of(lay):
		var on_f := TombFloors.holders_on(lay, f)
		for k in range(0, on_f.size(), 3):
			pick.append(int(on_f[k]))
	pick.sort()
	for i in pick:
		FireStore.swing_light(fires.holders[i], float(main.world.get("days")))
		for s in 600:
			FireStore.tick(self, DT, fires.holders[i].global_position)
			if FireStore.is_lit(fires.holders[i]):
				break
	await _frames(3)
	var lit := CrawlerSave.relit_now(fires)
	var floors_lit := {}
	for i in lit:
		floors_lit[TombFloors.holder_floor(lay, lay.holders[i])] = true
	ok(lit == pick and floors_lit.size() == TombFloors.floors_of(lay).size(), "%d holders relit on %d floors before going up (%s...)" % [lit.size(), floors_lit.size(), str(lit.slice(0, 6))])
	var before := {"lit": lit, "tomb": main.tomb, "lay": lay, "place": CrawlerSave.place, "seed": main.seed_value, "fires": fires}
	# The torch in hand, lit, as you go.
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	if not t.lit():
		t.light()
	var pack := _pack(p)
	var ex: Dictionary = lay.exits[0]
	var n: Vector3 = ex.n
	p.spawn_flat((ex.p as Vector3) - n * 1.3, atan2(-n.x, -n.z), 0.0)
	await _frames(5)
	var t0 := Time.get_ticks_msec()
	Input.action_press("move_forward")
	var began := false
	for i in 240:
		await physics_frame
		if main.leaving:
			began = true
			break
	Input.action_release("move_forward")
	ok(began, "walking into the way out's opening begins the way up")
	if not began:
		return before
	var line := str(GameLog.entries[-1].get("text", ""))
	for i in 6000:
		await process_frame
		if main.on_surface and not main.leaving:
			break
	var took := Time.get_ticks_msec() - t0
	ok(main.on_surface and not main.leaving and main.went_up == 1, "you come out on the surface (%d ms, the surface built in %d ms: ground %d, stone %d, plants %d)" % [took, int(main.surface.ms.get("all", 0)) if main.surface != null else -1, int(main.surface.ms.get("ground", 0)) + int(main.surface.ms.get("ground_mesh", 0)) if main.surface != null else -1, int(main.surface.ms.get("stone", 0)) if main.surface != null else -1, int(main.surface.ms.get("plants", 0)) if main.surface != null else -1])
	if not main.on_surface:
		return before
	await _frames(20)
	var s := main.surface
	var st: Dictionary = s.stair
	var pos := p.global_position
	var opening := Vector2((ex.p as Vector3).x, (ex.p as Vector3).z)
	var yard: Rect2 = st.yard
	ok((st.bottom as Vector2).distance_to(opening) < 0.01 and (st.n as Vector2).distance_to(Vector2(n.x, n.z)) < 0.01, "the stairhead's stair climbs from straight over the opening (%s) along the way out (%s)" % [str(opening), str(st.n)])
	ok(yard.has_point(Vector2(pos.x, pos.z)) and Vector2(pos.x, pos.z).distance_to(opening) < float(st.run) + 4.0, "you stand in the ruin's yard, %.1f m from straight over the opening (%s)" % [Vector2(pos.x, pos.z).distance_to(opening), str(pos.snapped(Vector3.ONE * 0.01))])
	ok(p.is_on_floor() and absf(pos.y - Surface.level()) < 0.2 and pos.y > float(ex.y) + 2.0, "on the yard's floor at the surface level (%.2f m), above the opening (%.2f m)" % [pos.y, float(ex.y)])
	var look := -p.global_basis.z
	ok(Vector2(look.x, look.z).normalized().dot(Vector2(n.x, n.z)) > 0.99, "facing out along the way out")
	var doors: int = (s.stone.get_child_count())
	ok(doors > 0 and int(s.stone.get_meta("stones", 0)) > 100, "the ruin over the stair: its fitted stone (%d stones, %d triangles)" % [int(s.stone.get_meta("stones", 0)), int(s.stone.get_meta("triangles", 0))])
	# The portal and the stair down: a ray across the mouth meets the jambs,
	# a ray down the stair's line meets its steps.
	var space := p.get_world_3d().direct_space_state
	var mouth: Vector2 = st.mouth
	var side: Vector2 = st.side
	var y := float(st.y)
	var jamb_hits := 0
	for sd: float in [-1.0, 1.0]:
		var a := Vector3(mouth.x, y + 1.0, mouth.y)
		var b := a + Vector3(side.x, 0.0, side.y) * sd * (float(st.half) + 1.0)
		var q := PhysicsRayQueryParameters3D.create(a, b)
		q.exclude = [p.get_rid()]
		if not space.intersect_ray(q).is_empty():
			jamb_hits += 1
	var mid := (st.bottom as Vector2).lerp(mouth, 0.5)
	var dq := PhysicsRayQueryParameters3D.create(Vector3(mid.x, y + 0.5, mid.y), Vector3(mid.x, y - float(st.drop) - 1.0, mid.y))
	dq.exclude = [p.get_rid()]
	var step_hit := space.intersect_ray(dq)
	ok(jamb_hits == 2 and not step_hit.is_empty() and (step_hit.position as Vector3).y < y - float(st.drop) * 0.3, "its portal's jambs either side of the stair's mouth, its steps going down between them (halfway down at %.2f m)" % ((step_hit.position as Vector3).y if not step_hit.is_empty() else NAN))
	ok(t.in_hand() and t.lit() and _pack(p) == pack, "the torch you carried, lit as it was, and nothing else changed (%s)" % pack)
	ok(line == str((Surface.S.get("arrive", {}) as Dictionary).get("log_up", "")) and line != "", "the log says so: \"%s\"" % line)
	var out_of_tree := true
	for node in [before.tomb, main.fires, main.vents, main.airways, main.way_out, main.residents, main.boss, main.fork, main.rescuer, main.cauldron, main.floor_fog]:
		if node != null and is_instance_valid(node) and (node as Node).is_inside_tree():
			out_of_tree = false
	ok(out_of_tree and s.is_inside_tree(), "the dungeon kept out of the tree as you left it (its stone, fires, residents, boss, fork, shaman, floor two's fog), the surface in it")
	var env := p.get_world_3d().environment
	ok(env == s.sky.environment and env.background_mode == Environment.BG_SKY, "the sky's environment draws (the dungeon's put aside)")
	return before


## What you carry, kind by kind.
func _pack(p: CrawlerPlayer) -> String:
	var kinds: Array = []
	for it in p.inventory.carried:
		kinds.append(str((it as Dictionary).get("kind", "")) if it is Dictionary else "-")
	return ",".join(kinds)


# --- 2. The look ------------------------------------------------------------------

func _look(main: CrawlerMain) -> void:
	var s := main.surface
	var world: Node = main.world
	var keep := float(world.get("days"))
	world.days = Vents.days_at_solar_hour(keep, 12.0)
	s._update(0.0)
	var sky := s.sky
	ok(sky.one_clock, "the sky runs on the one clock (SkySystem.one_clock)")
	var lights: Array = []
	_collect(s, func(n): return n is Light3D, lights)
	var others := lights.filter(func(l): return l != sky.sun and l != sky.moon)
	ok(sky.sun.visible and sky.sun.light_energy > 0.5 and not sky.moon.visible and others.is_empty(), "at noon the sun is the one light (energy %.2f), the moon's off, no other light up here (%d others)" % [sky.sun.light_energy, others.size()])
	var amb := sky.environment.ambient_light_color
	var fog: Color = Look._params.get("look_fog_color", Color.BLACK)
	ok(amb.b > amb.r and amb.b > amb.g, "the shade navy: the ambient #%s" % amb.to_html(false))
	ok(fog.b > fog.r and fog.b >= fog.g and fog.get_luminance() > amb.get_luminance(), "distance lighter and bluer: the haze #%s over the ambient #%s" % [fog.to_html(false), amb.to_html(false)])
	world.days = Vents.days_at_solar_hour(keep, 0.0)
	s._update(0.0)
	var amb_n := sky.environment.ambient_light_color
	ok(not sky.sun.visible and amb_n.b > amb_n.r and amb_n.b > amb_n.g, "at midnight no sun, the shade still navy (#%s), the moon's light %s" % [amb_n.to_html(false), "on" if sky.moon.visible else "off (new moon or down)"])
	world.days = keep
	s._update(0.0)
	# The world's biome: its ground colour, its associations.
	var bid := BiomeTemplates.id_of_key(Surface.biome_key())
	var col := BiomeTemplates.color_of(bid)
	var lv := s.land
	var mid := lv.count / 2
	var c := lv._color(mid + 30, mid + 30, 0.0, col)
	ok(bid >= 0 and c.r > c.b and c.get_luminance() > 0.4, "the ground in %s's colours (its sand #%s)" % [BiomeTemplates.name_of(bid), c.to_html(false)])
	var plants := s.plants
	var gate := true
	var wrong: Array = []
	for name in plants.counts:
		var sp := SpeciesDB.find(str(name))
		if sp == null or not sp.biomes.has(bid):
			gate = false
			wrong.append(name)
	ok(plants.grown.size() == 3 and plants.placed > 2000 and gate, "its plants: %d of them, from %s (%s), every species one its biome lists%s" % [plants.placed, ", ".join(plants.grown.values()), _top(plants.counts, 6), "" if gate else " (not: %s)" % str(wrong)])
	# A stand mostly one species (§CS): in each zone the dominants lead its
	# companions.
	var lead := true
	var shares: Array = []
	for z in plants.picks:
		var pk: Dictionary = plants.picks[z]
		var zc: Dictionary = plants.zone_counts.get(z, {})
		var dn := 0
		var cn := 0
		for nm in pk.dominant:
			dn += int(zc.get(nm, 0))
		for nm in pk.companion:
			if not (pk.dominant as Array).has(nm):
				cn += int(zc.get(nm, 0))
		shares.append("%s: %s %d against %d" % [z, ", ".join(pk.dominant), dn, cn])
		if dn <= cn:
			lead = false
	ok(lead, "each stand mostly its dominant species (§CS): %s" % "; ".join(shares))


func _collect(n: Node, test: Callable, out: Array) -> void:
	if test.call(n):
		out.append(n)
	for c in n.get_children():
		_collect(c, test, out)


func _top(counts: Dictionary, k: int) -> String:
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	var parts: Array = []
	for i in mini(k, keys.size()):
		parts.append("%s %d" % [keys[i], int(counts[keys[i]])])
	return ", ".join(parts)


# --- 3. The one clock -------------------------------------------------------------

func _clock(main: CrawlerMain) -> void:
	var world: Node = main.world
	var keep := float(world.get("days"))
	var starts := DayCycle.phase_starts(0.0, 0.0)
	var mins := DayCycle.day_length_min()
	var pm := DayCycle.phase_minutes()
	var dawn_m := starts[0] * mins
	var day_m := starts[1] * mins
	var dusk_m := starts[2] * mins
	var night_m := starts[3] * mins
	var split_ok := absf(fposmod(day_m - dawn_m, mins) - float(pm.dawn)) < 0.2 and absf(fposmod(dusk_m - day_m, mins) - float(pm.day)) < 0.2 and absf(fposmod(night_m - dusk_m, mins) - float(pm.dusk)) < 0.2 and absf(fposmod(dawn_m - night_m, mins) - float(pm.night)) < 0.2
	ok(split_ok and int(round(mins)) == 144, "the one clock's phases: dawn at %.1f, day at %.1f, dusk at %.1f, night at %.1f of %d minutes: %.0f / %.0f / %.0f / %.0f (dawn, day, dusk, night)" % [dawn_m, day_m, dusk_m, night_m, int(mins), fposmod(day_m - dawn_m, mins), fposmod(dusk_m - day_m, mins), fposmod(night_m - dusk_m, mins), fposmod(dawn_m - night_m, mins)])
	var base := floorf(keep) + 1.0
	var tw := DayCycle.twilight_deg()
	var moments := [["the start of dawn", starts[0], -tw], ["noon", DayCycle.unwarp(0.5, 0.0, 0.0), 90.0], ["the start of dusk", starts[2], tw], ["the start of night", starts[3], -tw]]
	var all_ok := true
	var said: Array = []
	for m in moments:
		world.days = base + float(m[1])
		await process_frame
		await process_frame
		var up := main.surface.sky.sun_elevation_deg
		var below := Vents.sun_deg(float(world.get("days")))
		var want := float(m[2])
		said.append("%s %.3f up, %.3f below (want %.1f)" % [m[0], up, below, want])
		if absf(up - below) > 0.01 or absf(up - want) > 0.05 or absf(Surface.sun_deg_at(float(world.get("days"))) - up) > 0.01:
			all_ok = false
	ok(all_ok, "the sun up here at the start of dawn, noon, dusk and night as the 60/18/48/18 split puts it, the same as the shafts' clock below at each moment: %s" % "; ".join(said))
	# One clock, not a copy: moved on, both move together; the surface keeps
	# no time of its own.
	world.days = base + 0.37
	await process_frame
	var a1 := main.surface.sky.sun_elevation_deg
	world.days = base + 0.41
	await process_frame
	var a2 := main.surface.sky.sun_elevation_deg
	ok(absf(a1 - Vents.sun_deg(base + 0.37)) < 0.01 and absf(a2 - Vents.sun_deg(base + 0.41)) < 0.01 and absf(a2 - a1) > 1.0 and main.surface.get("days") == null, "World.days moved on, the sun up here moves with the shafts' clock (%.2f to %.2f degrees); the surface keeps no clock of its own" % [a1, a2])
	# The crawler turns the one clock up here too.
	var d0 := float(world.get("days"))
	await _frames(60)
	ok(float(world.get("days")) > d0, "the clock runs while you are up here (World.days %.5f to %.5f)" % [d0, float(world.get("days"))])
	world.days = keep


# --- 5. The vents' stacks ---------------------------------------------------------

func _stacks(main: CrawlerMain) -> void:
	var s := main.surface
	var lay := main.lay
	var vents: Array = lay.vents
	var shafts := 0
	var flues := 0
	var by_top := {}
	for st in s.stacks:
		by_top[int(st.vent)] = st
	for sl in s.slots:
		by_top[int(sl.vent)] = sl
	var placed_ok := true
	var bad: Array = []
	for i in vents.size():
		var v: Dictionary = vents[i]
		var top: Vector3 = v.top
		var it: Dictionary = by_top.get(i, {})
		if it.is_empty():
			placed_ok = false
			bad.append("vent %d has nothing" % i)
			continue
		var at: Vector3 = it.foot if it.has("foot") else it.at
		var gy := s.land.height_at(top.x, top.z)
		if Vector2(at.x - top.x, at.z - top.z).length() > 0.01 or absf(at.y - gy) > 0.3:
			placed_ok = false
			bad.append("vent %d off its top" % i)
		if bool(v.sky):
			shafts += 1
			if not it.has("form"):
				placed_ok = false
		else:
			flues += 1
	var form := Smoke.stack_form("tomb")
	ok(placed_ok and shafts == s.stacks.size() and flues == s.slots.size() and shafts >= 1, "every vent's top on the ground straight over it: %d shafts' stacks (%s, outlets.by_ruin's for the tomb: %s), %d flues' sooted slots%s" % [shafts, ", ".join(s.stacks.map(func(x): return str(x.form))), form, flues, "" if placed_ok else " (%s)" % str(bad.slice(0, 4))])
	ok(not s.stacks.is_empty() and str(s.stacks[0].form) == form, "the hearth's stack is the tomb's own form (%s)" % form)


# --- 6. Life and finds ------------------------------------------------------------

func _life_and_finds(main: CrawlerMain) -> void:
	var s := main.surface
	var life := s.life
	var cl := Surface.climate()
	var fit := true
	for k in life.kinds:
		var sp: CreatureSpecies = k
		if sp.spawn != "ambient" or sp.role != "ground" or sp.temp_c.y < (cl.temp_c as Vector2).x or sp.temp_c.x > (cl.temp_c as Vector2).y or sp.moisture.y < (cl.moisture as Vector2).x or sp.moisture.x > (cl.moisture as Vector2).y:
			fit = false
	var L: Dictionary = Surface.S.get("life", {})
	var cr: Array = L.get("count", [5, 9])
	ok(not life.kinds.is_empty() and fit and life.animals.size() >= int(cr[0]) and life.animals.size() <= int(cr[1]), "a little ambient life from the ecology's archetypes: %d of %s (data/creatures, their climate the biome's, ground and ambient, never a hunter)" % [life.animals.size(), ", ".join(life.kinds.map(func(k): return k.name))])
	await _frames(30)
	var on_ground := true
	for a in life.animals:
		var pos: Vector3 = a.pos
		if not s.land.inside(Vector2(pos.x, pos.z), 0.0) or absf(pos.y - s.land.height_at(pos.x, pos.z)) > 0.05:
			on_ground = false
	ok(on_ground, "every creature on the ground inside the pocket")
	var F: Dictionary = Surface.S.get("finds", {})
	var kinds := {}
	var clear := true
	var arrive: Vector2 = s.stair.arrive
	for f in s.finds:
		kinds[str(f.kind)] = int(kinds.get(str(f.kind), 0)) + 1
		var at: Vector3 = f.at
		if Vector2(at.x, at.z).distance_to(arrive) < float(F.get("clear_of_stair_m", 24.0)) - 0.01 or not s.land.on_floor(Vector2(at.x, at.z), 0.0):
			clear = false
	var rr: Array = F.get("remains", [3, 5])
	var cc: Array = F.get("camps", [1, 2])
	ok(int(kinds.get("remains", 0)) >= int(rr[0]) and int(kinds.get("camp", 0)) >= int(cc[0]) and int(kinds.get("litter", 0)) >= 1 and clear, "things to find, never required (§FG): %s, clear of the stairhead and on the basin's floor" % str(kinds))
	# Nothing of them is a trigger or a thing to use: plain stone in the
	# surface's one mesh; no Area3D anywhere up here.
	var areas: Array = []
	_collect(s, func(n): return n is Area3D, areas)
	ok(areas.is_empty(), "no trigger or pickup among them (no Area3D on the surface)")


# --- 7. Down ----------------------------------------------------------------------

func _down(main: CrawlerMain, before: Dictionary) -> void:
	var p := main.player
	var s := main.surface
	var st: Dictionary = s.stair
	var n: Vector2 = st.n
	# From where you came out, turned round and walking down the steps.
	var at := s.arrival()
	p.spawn_flat(at.pos, atan2(n.x, n.y), 0.0)
	await _frames(5)
	Input.action_press("move_forward")
	var began := false
	for i in 600:
		await physics_frame
		if main.leaving:
			began = true
			break
	Input.action_release("move_forward")
	ok(began, "walking back down the stairhead's steps begins the way down")
	if not began:
		return
	var line := str(GameLog.entries[-1].get("text", ""))
	for i in 6000:
		await process_frame
		if not main.on_surface and not main.leaving:
			break
	await _frames(10)
	var lay := main.lay
	var ex: Dictionary = lay.exits[0]
	var pos := p.global_position
	ok(not main.on_surface and main.came_down == 1 and main.tomb == before.tomb and main.lay == before.lay and main.seed_value == int(before.seed) and CrawlerSave.place == int(before.place) and main.fires == before.fires, "the same dungeon: the same stone, layout, fires and place in the game (tomb %d, place %d)" % [main.seed_value, CrawlerSave.place])
	var lit := CrawlerSave.relit_now(main.fires)
	ok(lit == before.lit, "the same holders lit and no others (%d: %s...)" % [lit.size(), str(lit.slice(0, 6))])
	var in_tree := true
	for node in [main.tomb, main.fires, main.vents, main.residents, main.boss, main.fork, main.rescuer, main.cauldron, main.way_out, main.floor_fog]:
		if node == null or not is_instance_valid(node) or not (node as Node).is_inside_tree():
			in_tree = false
	ok(in_tree and not s.is_inside_tree() and is_instance_valid(s), "the dungeon back in the tree, the surface kept out of it")
	var n3: Vector3 = ex.n
	var look := -p.global_basis.z
	ok(TombKit.piece_at(lay, pos) == int(ex.landing) and absf(pos.y - float(ex.y)) < 0.2 and p.is_on_floor() and Vector2(look.x, look.z).normalized().dot(Vector2(-n3.x, -n3.z)) > 0.99, "you stand on the landing at the top of the flight, facing in (%s)" % str(pos.snapped(Vector3.ONE * 0.01)))
	ok(line == str((Surface.S.get("arrive", {}) as Dictionary).get("log_down", "")) and line != "", "the log says so: \"%s\"" % line)
	var env := p.get_world_3d().environment
	var pm := main.post._rect.material as ShaderMaterial
	var fog: Color = Look._params.get("look_fog_color", Color.BLACK)
	var want_fog := Color(str(CrawlerMain.LOOKD.get("fog_color", "#05081c")))
	ok(env == main.environment and is_equal_approx(float(pm.get_shader_parameter("night")), 1.0) and float(pm.get_shader_parameter("fire_whites")) > 0.0 and fog.is_equal_approx(want_fog) and is_equal_approx(Campfire.night, 1.0) and main.half_dark.enabled and is_equal_approx(p.camera().far, 400.0), "everything the surface changed is back: the dungeon's environment, the grade's night and firelit whites, the haze (#%s), the half-dark, the camera's reach (%.0f m)" % [fog.to_html(false), p.camera().far])
	var playing := true
	for c in main.get_children():
		if c is AudioStreamPlayer and str(c.name) in ["DelveLoop", "DripsLoop"] and ((c as AudioStreamPlayer).stream_paused or not (c as AudioStreamPlayer).playing):
			playing = false
	ok(playing and Footsteps.material_under(p) == "stone", "the drone and the drips again, and stone underfoot")


func _again(main: CrawlerMain) -> void:
	var p := main.player
	var s := main.surface
	var ex: Dictionary = main.lay.exits[0]
	var n: Vector3 = ex.n
	p.spawn_flat((ex.p as Vector3) - n * 1.3, atan2(-n.x, -n.z), 0.0)
	await _frames(3)
	main.walk_out()
	var t0 := Time.get_ticks_msec()
	for i in 6000:
		await process_frame
		if main.on_surface and not main.leaving:
			break
	ok(main.on_surface and main.surface == s and main.went_up == 2, "up the same stair again: the same surface as you left it, no new build (%d ms, the fades)" % (Time.get_ticks_msec() - t0))
	await _frames(5)
	ok(Footsteps.material_under(p) == "stone", "on the yard's flags your steps are on stone")
	var arrive: Vector2 = s.stair.arrive
	var away := arrive + (s.stair.n as Vector2) * 30.0
	p.spawn_flat(Vector3(away.x, s.land.height_at(away.x, away.y) + 0.1, away.y), 0.0, 0.0)
	await _frames(10)
	ok(Footsteps.material_under(p) in ["sand", "dirt"], "out on the basin your steps are on %s" % Footsteps.material_under(p))


# --- 4. Ambience only -------------------------------------------------------------

func _hours(main: CrawlerMain) -> void:
	var world: Node = main.world
	var keep := float(world.get("days"))
	var s := main.surface
	var p := main.player
	# Noon: the smoke stands over the stack; midnight: the mouth glows.
	world.days = Vents.days_at_solar_hour(keep, 12.0)
	await _frames(3)
	var sm: Dictionary = s._smokes[0] if not s._smokes.is_empty() else {}
	var col: Node3D = sm.get("col")
	var day_smoke := col != null and col.visible and float(col.get_meta("top_m", 0.0)) > 1.0
	var day_glow: Color = (sm.mat as StandardMaterial3D).albedo_color if not sm.is_empty() else Color.WHITE
	world.days = Vents.days_at_solar_hour(keep, 0.0) + 1.0
	await _frames(3)
	var night_glow: Color = (sm.mat as StandardMaterial3D).albedo_color if not sm.is_empty() else Color.BLACK
	ok(day_smoke and day_glow.get_luminance() < 0.05 and night_glow.r > night_glow.b * 2.0 and night_glow.get_luminance() > day_glow.get_luminance() * 3.0, "the hearth's stack smokes by day (its column %.0f m) and glows faintly in the fire's amber at night (#%s)" % [float(col.get_meta("top_m", 0.0)) if col != null else 0.0, night_glow.to_html(false)])
	# The creatures keep their hours.
	var day_ok := true
	var night_ok := true
	for a in s.life.animals:
		var sp: CreatureSpecies = a.sp
		if sp.active == "day" and (a.root as Node3D).visible:
			night_ok = false
	world.days = Vents.days_at_solar_hour(keep, 12.0) + 2.0
	await _frames(3)
	for a in s.life.animals:
		var sp: CreatureSpecies = a.sp
		if sp.active in ["day", "any"] and not (a.root as Node3D).visible:
			day_ok = false
	ok(day_ok and night_ok, "the creatures keep their hours (the tortoise by day only, the hare any time)")
	# Down and up at midnight as at noon: nothing gated by the hour.
	world.days = Vents.days_at_solar_hour(keep, 0.0) + 3.0
	main.go_down()
	for i in 6000:
		await process_frame
		if not main.on_surface and not main.leaving:
			break
	var down_ok := not main.on_surface
	main.go_up()
	for i in 6000:
		await process_frame
		if main.on_surface and not main.leaving:
			break
	var at := s.arrival()
	ok(down_ok and main.on_surface and p.global_position.distance_to(at.pos) < 0.3, "at midnight you go down and come up again just as at noon (nothing gated by the hour)")
	world.days = keep


# --- 9. No way off but the stair ----------------------------------------------------

func _no_way_off(main: CrawlerMain) -> void:
	var s := main.surface
	var maps: Array = []
	_collect(main, func(n): return str(n.name).to_lower().contains("map") or n is MapOverlay, maps)
	ok(maps.is_empty() and not s.has_method("travel") and not s.has_method("fast_travel"), "no map and no fast travel up here (§FM.8)")
	var bodies: Array = []
	_collect(s, func(n): return n is CollisionObject3D, bodies)
	var names := bodies.map(func(b): return str(b.name))
	var only := true
	for b in bodies:
		# (Since queue 72 the shaman stands by the sacred vine the first time
		# you come up, and you bump into him as at the hearth: a figure's
		# blocker on his rig, not a wall.)
		var shaman_s := str(b.name) == "Blocker" and b.get_parent() is PlayerBody and b.get_parent().get_parent() is HearthFolk
		if not (b is StaticBody3D) or not (str(b.name) in ["Collision", "Trunks"] or shaman_s):
			only = false
	ok(only, "no collision up here but the land, the stone, the trees' trunks and the shaman by the vine (no invisible wall): %s" % str(names))


# --- 8. The edge -------------------------------------------------------------------

## The pocket's size and its edge: never past the escarpment's foot, never
## off the ground, walking 2000 m (then sprinting and jumping 2000 m) from
## the stair every way, in the surface's own collision.
func _edge(s: Surface, lay: Dictionary) -> void:
	var land := s.land
	var size: Array = (Surface.W.get("size", {}) as Dictionary).get("across_m", [1000, 2000])
	var across := float(Surface.S.get("across_m", 1400.0))
	ok(across >= float(size[0]) and across <= float(size[1]) and str((Surface.W.get("size", {}) as Dictionary).get("edge", "")) == "the_land" and not bool((Surface.W.get("size", {}) as Dictionary).get("invisible_walls", true)), "the pocket %.0f m across, within worlds.json size.across_m %s; its edge the land, no invisible walls" % [across, str(size)])
	# Steeper than you can walk, all the way round: the face's every
	# triangle through the middle of its height (the grid's own triangles,
	# 4 m across: none of them reaches the foot or the lip).
	var lim := tan(deg_to_rad(CrawlerPlayer.WALK_MAX_DEG))
	var worst := INF
	var cw := float(land.E.get("cliff_width_m", 16.0))
	for k in 720:
		var th := TAU * k / 720.0
		var dir := Vector2(cos(th), sin(th))
		var re := land.edge_r(th)
		var r := re + 0.3 * cw
		while r < re + 0.7 * cw:
			var q := land.center + dir * r
			var g := (land.height_at(q.x + dir.x * 0.5, q.y + dir.y * 0.5) - land.height_at(q.x - dir.x * 0.5, q.y - dir.y * 0.5))
			worst = minf(worst, g)
			r += 0.5
	ok(worst > lim, "the escarpment steeper than you can walk all the way round (its gentlest step %.2f over 1 m against %.2f, %.0f degrees)" % [worst, lim, CrawlerPlayer.WALK_MAX_DEG])
	var dirs := int(OS.get_environment("WALK_DIRS")) if OS.get_environment("WALK_DIRS").is_valid_int() else 16
	var r1 := await _walks(s, dirs, false)
	ok(bool(r1.ok), "walking 2000 m from the stair %d ways never leaves the pocket's edge into void: never past the escarpment's foot (at most %.1f m past it), never off the ground, never falling (furthest %.0f m out; %d steps)" % [dirs, float(r1.past), float(r1.far), int(r1.steps)] + ("" if bool(r1.ok) else " (%s)" % r1.why))
	var r2 := await _walks(s, dirs, true)
	ok(bool(r2.ok), "sprinting and jumping 2000 m every way, the same: at most %.1f m past the foot, furthest %.0f m out" % [float(r2.past), float(r2.far)] + ("" if bool(r2.ok) else " (%s)" % r2.why))


## Your body (CrawlerPlayer's capsule and floor rules) in a world of its
## own holding the surface's collision, walked `dirs` ways from the
## arrival 2000 m each. {"ok", "past", "far", "steps", "why"}.
func _walks(s: Surface, dirs: int, sprint: bool) -> Dictionary:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(4, 4)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_root().add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	# The land's collision, the stone's and the trunks'.
	var c := s.land.collision()
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = c[0]
	cs.transform = c[1]
	ground.add_child(cs)
	root.add_child(ground)
	for b in [s.stone.get_node_or_null("Collision"), s.plants.get_node_or_null("Trunks")]:
		if b != null:
			root.add_child((b as Node).duplicate())
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	var bs := CollisionShape3D.new()
	bs.shape = CrawlerPlayer.body_shape()
	bs.position = Vector3(0.0, CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0)
	body.add_child(bs)
	CrawlerPlayer.floor_rules(body)
	root.add_child(body)
	await physics_frame
	await physics_frame
	var land := s.land
	var at := s.arrival()
	# Past the foot no further than a jump up the face's first step: a body
	# that could climb it would go on to its lip, cliff_width_m out.
	var limit := 0.4 * float(land.E.get("cliff_width_m", 16.0))
	var speed := CrawlerPlayer.SPRINT_SPEED if sprint else CrawlerPlayer.WALK_SPEED
	var steps := int(2000.0 / maxf(speed, 0.5) / DT)
	var out := {"ok": true, "past": -INF, "far": 0.0, "steps": 0, "why": ""}
	for k in dirs:
		var th := TAU * k / dirs
		var wish := Vector3(cos(th), 0.0, sin(th))
		body.global_position = (at.pos as Vector3) + Vector3(0.0, 0.05, 0.0)
		body.velocity = Vector3.ZERO
		# Falling: coming down faster than a jump lands, for longer than a
		# jump lasts.
		var fall := 0
		for i in steps:
			CrawlerPlayer.step_body(body, wish, speed, DT, sprint and body.is_on_floor())
			out.steps = int(out.steps) + 1
			var p := body.global_position
			var q := Vector2(p.x, p.z)
			var d := q - land.center
			var past := d.length() - land.edge_r(atan2(d.y, d.x))
			out.past = maxf(float(out.past), past)
			out.far = maxf(float(out.far), d.length())
			var gy := land.height_at(p.x, p.z)
			fall = fall + 1 if body.velocity.y < -CrawlerPlayer.JUMP_SPEED * 1.5 else 0
			# Under the ground only where no stone stands over a dip (the
			# stairwell's cut, its yard's flags: SurfaceGround.carve_stair).
			var under := p.y < gy - 0.5 and not (s.stair.yard as Rect2).grow(1.0).has_point(q)
			if past > limit or under or p.y < Surface.level() - float(s.stair.drop) - 1.0 or absf(d.x) > land.half_m() - 1.0 or absf(d.y) > land.half_m() - 1.0 or fall > 90:
				out.ok = false
				out.why = "way %d (%.0f degrees): at %s, %.1f m past the foot, %.2f m off the ground, falling %d steps" % [k, rad_to_deg(th), str(p.snapped(Vector3.ONE * 0.1)), past, p.y - gy, fall]
				break
		if not bool(out.ok):
			break
	NodeRelease.free_later(vp)
	return out


# --- 10. Over twenty seeds ----------------------------------------------------------

func _seeds() -> void:
	var n := MORE_SEEDS
	if OS.get_environment("SURFACE_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("SURFACE_SEEDS")), 0)
	var seeds: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	while seeds.size() < 3 + n:
		var s := rng.randi_range(1, 999999)
		if not seeds.has(s):
			seeds.append(s)
	var world_node: Node = get_root().get_node("World")
	var built := 0
	var stair_ok := true
	var arrive_ok := true
	var walk_ok := true
	var vents_ok := true
	var zones_ok := true
	var finds_ok := true
	var life_ok := true
	var notes: Array = []
	var times: Array = []
	for sv in seeds:
		var lay := TombKit.layout(int(sv))
		var t0 := Time.get_ticks_msec()
		var s := Surface.new()
		s.build(world_node, lay, null)
		times.append(Time.get_ticks_msec() - t0)
		built += 1
		var ex: Dictionary = lay.exits[0]
		var st: Dictionary = s.stair
		if (st.bottom as Vector2).distance_to(Vector2((ex.p as Vector3).x, (ex.p as Vector3).z)) > 0.01:
			stair_ok = false
			notes.append("seed %d: the stair off the opening" % sv)
		var a: Vector2 = st.arrive
		if not (st.yard as Rect2).has_point(a):
			arrive_ok = false
			notes.append("seed %d: the arrival outside the yard" % sv)
		if s.stacks.size() + s.slots.size() != (lay.vents as Array).size() or s.stacks.is_empty():
			vents_ok = false
			notes.append("seed %d: %d stacks + %d slots for %d vents" % [sv, s.stacks.size(), s.slots.size(), (lay.vents as Array).size()])
		if s.plants.grown.size() < 3 or s.plants.placed < 2000:
			zones_ok = false
			notes.append("seed %d: %d zones grown, %d plants" % [sv, s.plants.grown.size(), s.plants.placed])
		var kinds := {}
		for f in s.finds:
			kinds[str(f.kind)] = true
		if not (kinds.has("remains") and kinds.has("camp") and kinds.has("litter")):
			finds_ok = false
			notes.append("seed %d: finds %s" % [sv, str(kinds.keys())])
		if s.life.animals.is_empty():
			life_ok = false
		# Your body from the arrival down into the stair's mouth (its own
		# world: the land, the stone), standing first on the yard's level
		# floor at the surface level.
		var w := await _walk_down(s)
		if not bool(w.ok):
			walk_ok = false
			notes.append("seed %d: %s" % [sv, w.why])
		if absf(float(w.floor_y) - Surface.level()) > 0.05 or not bool(w.level):
			arrive_ok = false
			notes.append("seed %d: the arrival's floor at %.2f m%s" % [sv, float(w.floor_y), "" if bool(w.level) else ", not level"])
		NodeRelease.detach_all(s)
		s.free()
	ok(built == seeds.size(), "the surface builds over %d tombs (seeds %s...; %d to %d ms each)" % [built, str(seeds.slice(0, 5)), times.min(), times.max()])
	ok(stair_ok and arrive_ok, "on every one the stair climbs from straight over the opening and you arrive on its yard's level ground" + ("" if stair_ok and arrive_ok else " (%s)" % str(notes.slice(0, 4))))
	ok(walk_ok, "on every one your body walks from the arrival down the stairhead's steps to where the way down begins" + ("" if walk_ok else " (%s)" % str(notes.slice(0, 4))))
	ok(vents_ok and zones_ok and finds_ok and life_ok, "on every one every vent's top has its stack or slot, all three stands grow, there are remains, a camp and litter to find, and creatures" + ("" if vents_ok and zones_ok and finds_ok and life_ok else " (%s)" % str(notes.slice(0, 6))))
	# The same land twice from the same seed (§FK.2).
	var la := TombKit.layout(int(seeds[3]))
	var s1 := Surface.new()
	s1.build(world_node, la, null)
	var s2 := Surface.new()
	s2.build(world_node, la, null)
	var same: bool = s1.land.heights == s2.land.heights and s1.plants.counts == s2.plants.counts and str(s1.finds) == str(s2.finds) and s1.stone.get_meta("triangles") == s2.stone.get_meta("triangles")
	var other := Surface.new()
	other.build(world_node, TombKit.layout(int(seeds[4])), null)
	var differs: bool = other.land.heights != s1.land.heights
	ok(same and differs, "the same land from the same seed (its ground, plants, finds and stone), another from another")
	for x in [s1, s2, other]:
		NodeRelease.detach_all(x)
		x.free()


## Your body from the arrival, turned round, down the stairhead's steps
## until Surface.stepped_in says the way down has begun.
func _walk_down(s: Surface) -> Dictionary:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(4, 4)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_root().add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var c := s.land.collision()
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = c[0]
	cs.transform = c[1]
	ground.add_child(cs)
	root.add_child(ground)
	var col := s.stone.get_node_or_null("Collision")
	if col != null:
		root.add_child(col.duplicate())
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	var bs := CollisionShape3D.new()
	bs.shape = CrawlerPlayer.body_shape()
	bs.position = Vector3(0.0, CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0)
	body.add_child(bs)
	CrawlerPlayer.floor_rules(body)
	root.add_child(body)
	await physics_frame
	await physics_frame
	var at := s.arrival()
	# The floor where you come out: a ray down there and a step to either
	# side and ahead (level: the yard's flags).
	var space := vp.find_world_3d().direct_space_state
	var floor_y := NAN
	var level := true
	var n: Vector2 = s.stair.n
	var sd: Vector2 = s.stair.side
	for off: Vector2 in [Vector2.ZERO, sd * 1.0, -sd * 1.0, n * 1.0]:
		var o := (at.pos as Vector3) + Vector3(off.x, 0.0, off.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3.UP * 1.0, o - Vector3.UP * 3.0))
		var hy: float = (hit.position as Vector3).y if not hit.is_empty() else NAN
		if off == Vector2.ZERO:
			floor_y = hy
		elif is_nan(hy) or absf(hy - floor_y) > 0.06:
			level = false
	body.global_position = (at.pos as Vector3) + Vector3(0.0, 0.05, 0.0)
	var wish := Vector3(-n.x, 0.0, -n.y)
	var out := {"ok": false, "why": "never reached the way down", "floor_y": floor_y, "level": level}
	for i in 900:
		CrawlerPlayer.step_body(body, wish, CrawlerPlayer.WALK_SPEED, DT)
		if s.stepped_in(body.global_position):
			out.ok = true
			out.why = ""
			break
	if not bool(out.ok):
		out.why = "stopped at %s" % str(body.global_position.snapped(Vector3.ONE * 0.01))
	NodeRelease.free_later(vp)
	return out
