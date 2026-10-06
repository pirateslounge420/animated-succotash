class_name BeastLineup
## The silhouette test (design 6 Oct §EQ.1; data/dev.json beast_lineup):
## all twelve zodiac folk standing in a row on a dark ledge in front of
## where you wake, raised so their heads stand against the sky, side-on
## (each faces along the row: a profile names a species best), in pure
## black or in their colours. A dev tool: dev mode only, or BEAST_LINEUP=1
## (BEAST_LINEUP=colour for colour) in the environment.

## dev.json beast_lineup, with the environment's say.
static func settings(world: Node) -> Dictionary:
	var L: Dictionary = (world.dev.get("beast_lineup", {}) as Dictionary).duplicate() if world.dev_mode else {}
	var env := OS.get_environment("BEAST_LINEUP")
	if env != "" and env != "0":
		L["on"] = true
		L["black"] = env != "colour"
	return L


## Stand the lineup `L` in front of `player` (under `parent`), the row
## across their view. Returns its node.
static func build(parent: Node3D, world: Node, chunks: ChunkManager, player: PlanetPlayer, L: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BeastLineup"
	parent.add_child(root)
	var up: Vector3 = player.up
	var fwd := -player.camera().global_basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var right := fwd.cross(up).normalized()
	var at: Vector3 = player.global_position + fwd * float(L.get("distance_m", 6.0))
	var d: Vector3 = world.dir_of(at)
	var ground: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	root.global_transform = Transform3D(Basis(right, up, -fwd), ground)
	var raise := float(L.get("raise_m", 1.4))
	var gap := float(L.get("spacing_m", 0.9))
	var black := bool(L.get("black", true))
	var animals := BeastHeads.animals()
	var n := animals.size()
	var dark := Color(0.02, 0.02, 0.03)
	# The ledge.
	var ledge := MeshInstance3D.new()
	ledge.name = "Ledge"
	var bm := BoxMesh.new()
	bm.size = Vector3(gap * (n + 1), raise, 0.6)
	ledge.mesh = bm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = dark
	ledge.material_override = lm
	ledge.position = Vector3(0, raise * 0.5 - 0.3, 0)
	root.add_child(ledge)
	var blk := StandardMaterial3D.new()
	blk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blk.albedo_color = Color.BLACK
	for i in n:
		var a := str(animals[i])
		var cb := CloakedFigure.build(1.72, Color(0.45, 0.3, 0.22), Color(0.8, 0.7, 0.5))
		var b: PlayerBody = cb.root
		b.name = "Lineup_" + a
		root.add_child(b)
		b.position = Vector3((i - (n - 1) * 0.5) * gap, raise - 0.3, 0)
		# Side-on: facing along the row (its -Z to +X).
		b.rotation.y = -PI * 0.5
		b.look_still = true
		b.set_beast(a)
		b.set_meta("animal", a)
		if black:
			b.set_palette(Color.BLACK, Color.BLACK)
			for mi in b.find_children("*", "MeshInstance3D", true, false):
				if not str(mi.name).begins_with("Cloak"):
					(mi as MeshInstance3D).material_override = blk
	print("[lineup] %d zodiac folk %.1f m out, %.1f m up, %s" % [n, float(L.get("distance_m", 6.0)), raise, "black" if black else "in colour"])
	return root
