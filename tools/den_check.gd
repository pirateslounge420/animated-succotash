extends SceneTree
## Dens (Mike's 3 Oct 14:34 play: "a little opening to a shrine ... I
## wasn't able to go inside": a spotted hyena's den in a jungle, drawn as
## the wolf's 3 m stone doorway), headless, full planet:
##   SEED=7731 godot --headless --path . --script tools/den_check.gd
## Asserts:
##  - over many cells of the planet, every den a pack species finds sits
##    where both its heat and its wet suit the species (temp_c and
##    moisture), so no hyena den in a jungle;
##  - a burrow (the hyena's) is a burrow: a spoil heap and dark holes, no
##    stone frame, nothing to bump into;
##  - a cave den (the wolf's) is framed by the place's own rock, and has
##    its snow slab only in snow country;
##  - every den's dark hole is animal-sized: under 1 m wide and under 1 m
##    above the ground, never a doorway.

var main
var world
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
	main.player.set_physics_process(false)
	var cs: CreatureSpawner = main.creatures
	var map: PlanetData = cs.map
	# The climate gate.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for sp in cs._species:
		if sp.pack.is_empty():
			continue
		var found := 0
		var bad := 0
		var wettest := 0.0
		var i := cs._species.find(sp)
		for k in 6000:
			var c := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var den: Dictionary = cs._find_den(sp, c, Vector4i(i, k, 0, 7))
			if den.is_empty():
				continue
			found += 1
			var d: Vector3 = den.dir
			var e := map.terrain.elevation(d, true)
			var t := cs._temp_at(d, e)
			var m := map.sample(map.moisture, d)
			wettest = maxf(wettest, m)
			if t < sp.temp_c.x or t > sp.temp_c.y or m < sp.moisture.x or m > sp.moisture.y:
				bad += 1
		print("[den] %s: %d dens in 6000 cells, the wettest at moisture %.2f (range %.2f-%.2f)" % [sp.name, found, wettest, sp.moisture.x, sp.moisture.y])
		ok(found > 0 and bad == 0, "%s: every den is in its heat and wet (%d of %d not)" % [sp.name, bad, found])
	# The props, built at the player's feet.
	var here: Vector3 = world.dir_of(main.player.global_position)
	for burrow in [true, false]:
		for snow in [false, true]:
			if burrow and snow:
				continue
			for rock in [PlanetData.Rock.GRANITE, PlanetData.Rock.SANDSTONE]:
				var den := {"dir": here, "facing": CubeSphere.east(here), "seed": 11, "burrow": burrow, "snow": snow, "rock": rock}
				var prop: Node3D = cs._den_prop(den)
				_check_prop(prop, burrow, snow, rock)
				prop.free()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _check_prop(prop: Node3D, burrow: bool, snow: bool, rock: int) -> void:
	var tag := "%s%s, %s" % ["burrow" if burrow else "cave den", " in snow" if snow else "", "sandstone" if rock == PlanetData.Rock.SANDSTONE else "granite"]
	var bed := 0.05 if burrow else 0.2
	var widest := 0.0
	var tallest := 0.0
	for n in prop.find_children("Hole*", "", false, false):
		var mi := n as MeshInstance3D
		widest = maxf(widest, mi.scale.x)
		tallest = maxf(tallest, mi.position.y + mi.scale.y * 0.5 - bed)
	ok(widest > 0.3 and widest < 1.0 and tallest > 0.2 and tallest < 1.0, "%s: the dark hole is animal-sized, %.2f m wide and %.2f m above the ground" % [tag, widest, tallest])
	var rocks := 0
	var big_rock := 0.0
	var colours := []
	for n in prop.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).material_override == RuinBuilder.material():
			rocks += 1
			var aabb := (n as MeshInstance3D).get_aabb()
			big_rock = maxf(big_rock, aabb.size.y)
			if n.has_meta("stone"):
				colours.append(n.get_meta("stone"))
	var collides := prop.find_children("*", "StaticBody3D", true, false).size() > 0
	if burrow:
		ok(not collides and big_rock < 0.5 and prop.get_node_or_null("Snow") == null, "%s: a spoil heap with holes, no stone frame (biggest stone %.2f m), nothing to bump into" % [tag, big_rock])
	else:
		ok(collides and rocks == 3, "%s: framed by stones you bump into" % tag)
		ok((prop.get_node_or_null("Snow") != null) == snow, "%s: the snow slab only in snow country" % tag)
	# The stones are the place's rock.
	var pal: Array = CreatureSpawner.den_stones(rock)
	var near := 0
	for c in colours:
		var best := 9.0
		for p in pal:
			best = minf(best, Vector3((c as Color).r - (p as Color).r, (c as Color).g - (p as Color).g, (c as Color).b - (p as Color).b).length())
		if best < 0.12:
			near += 1
	ok(colours.size() > 0 and near == colours.size(), "%s: its stones are the place's own rock (%d of %d)" % [tag, near, colours.size()])
