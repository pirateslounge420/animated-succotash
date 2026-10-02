class_name RuinMarks
## Ruins remember (design 30 Sept §BQ): the part of the craft that does
## not rot. At every ruin the people file's ruin.signatures stand as
## props, starting as a heap (an ambiguous mound under the overgrowth);
## when a camp squats there, legibility advances with its ladder (cleared
## at the food rung, restored at storage) and the shape comes back: the
## kiln hump, the weir line, the terrace. The camp inherits the
## signature's head start (CampSim.inherits, read by the sim). Black
## earth and middens mark the ground (SoilMarks): plants differ there.

const STONE := Color(0.46, 0.46, 0.48)
const OVERGROWN := Color(0.3, 0.4, 0.22)


static func legibility(level_word: String) -> int:
	match level_word:
		"cleared":
			return 1
		"restored":
			return 2
	return 0


## Dress a ruin node with its people's signatures. `rung` is the squatting
## camp's ladder rung (-1: no camp): heap under 1, cleared at 1, restored
## at 2 and up.
static func dress(ruin: Node3D, site: Dictionary, world: Node, chunks: ChunkManager, people: Dictionary, rung: int, spread := 10.0) -> void:
	var sigs: Array = (people.get("ruin", {}) as Dictionary).get("signatures", [])
	if sigs.is_empty():
		return
	var d: Vector3 = site.dir
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "marks"])
	var marks := Node3D.new()
	marks.name = "Marks"
	ruin.add_child(marks)
	marks.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(d), d), world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d)))
	var body := PropCollision.body(marks)
	var level := 0 if rung < 1 else (1 if rung < 2 else 2)
	var foot := float(site.get("footprint_m", 12.0))
	for i in mini(sigs.size(), 4):
		var sig: Dictionary = sigs[i]
		var n := Node3D.new()
		n.name = "Sig_" + str(sig.get("id", i))
		marks.add_child(n)
		var a := rng.randf() * TAU
		var r := rng.randf_range(foot * 0.5, foot * 0.5 + spread)
		n.position = Vector3(cos(a), 0, sin(a)) * r
		n.basis = Basis.looking_at(-n.position.normalized(), Vector3.UP)
		_signature(n, sig, level, rng, body)
		# The ground remembers: middens and black earth grow things
		# differently (SoilMarks).
		var what := str(sig.get("what", "")).to_lower() + " " + str(sig.get("id", ""))
		if what.find("midden") >= 0 or what.find("black earth") >= 0 or what.find("terra") >= 0:
			var md: Vector3 = world.dir_of(n.global_position)
			SoilMarks.add(md, 7.0, 1.6)


## One signature: at level 0 a heap (a mound in the overgrowth, the real
## shape only hinted), at 1 cleared (the shape, dull), at 2 restored (the
## shape, whole).
static func _signature(n: Node3D, sig: Dictionary, level: int, rng: RandomNumberGenerator, _body: StaticBody3D) -> void:
	# Its own collision body, so the shapes sit where the mark is.
	var cb := PropCollision.body(n)
	var s := (str(sig.get("id", "")) + " " + str(sig.get("what", ""))).to_lower()
	if level == 0:
		# The heap: a long low mound, brambles on it, a hint of the stone.
		var r := rng.randf_range(1.6, 2.8)
		CreatureBodies.ball(n, Vector3(r, r * 0.35, r * 0.7), Vector3(0, r * 0.1, 0), OVERGROWN.darkened(rng.randf() * 0.15))
		for k in 3:
			var b := CreatureBodies.box(n, Vector3(0.5, 0.25, 0.4), Vector3(rng.randf_range(-r * 0.6, r * 0.6), r * 0.25, rng.randf_range(-r * 0.4, r * 0.4)), STONE.darkened(0.2))
			b.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, Vector3(0, r * 0.15, 0)), r * 0.6, r * 0.4)
		return
	var col := STONE.darkened(0.15) if level == 1 else STONE
	if s.find("midden") >= 0 or s.find("mound") >= 0 or s.find("black earth") >= 0 or s.find("slag") >= 0 or s.find("kraal") >= 0:
		var r := rng.randf_range(2.0, 3.2)
		var mc := Color(0.82, 0.78, 0.66) if s.find("shell") >= 0 else (Color(0.12, 0.1, 0.08) if s.find("black") >= 0 or s.find("slag") >= 0 or s.find("charcoal") >= 0 else Color(0.4, 0.33, 0.22))
		CreatureBodies.ball(n, Vector3(r, r * 0.45, r * 0.8), Vector3(0, r * 0.12, 0), mc)
		PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, Vector3(0, r * 0.2, 0)), r * 0.7, r * 0.4)
	elif s.find("stake") >= 0 or s.find("weir") >= 0 or s.find("post") >= 0 or s.find("fence") >= 0 or s.find("pile") >= 0 or s.find("stump") >= 0:
		for k in 9:
			var x := (k - 4) * 0.8
			var h := 0.5 if level == 1 else 1.3
			var p := CreatureBodies.cone(n, 0.06, 0.04, h, Vector3(x, h * 0.5, absf(x) * 0.5), CampProps.POLE.darkened(0.3 if level == 1 else 0.0), 0.0, 5)
			p.rotation = Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
			PropCollision.capsule(cb, p.transform, 0.06, h)
	elif s.find("pan") >= 0 or s.find("floor") >= 0 or s.find("platform") >= 0 or s.find("circle") >= 0 or s.find("mortar") >= 0 or s.find("grinding") >= 0 or s.find("ground") >= 0 or s.find("line") >= 0:
		var disc := CreatureBodies.ball(n, Vector3(2.4, 0.08, 2.0), Vector3(0, 0.03, 0), (Color(0.1, 0.09, 0.08) if s.find("charcoal") >= 0 or s.find("scorch") >= 0 or s.find("burn") >= 0 else col.lightened(0.1)))
		disc.scale.y = 1.0
	elif s.find("pit") >= 0 or s.find("pond") >= 0 or s.find("hollow") >= 0 or s.find("cutting") >= 0 or s.find("spring") >= 0 or s.find("waterhole") >= 0 or s.find("cistern") >= 0 or s.find("cenote") >= 0 or s.find("soak") >= 0:
		for k in 8:
			var a := k * TAU / 8.0
			var b := CreatureBodies.box(n, Vector3(0.6, 0.3, 0.4), Vector3(cos(a) * 1.6, 0.15, sin(a) * 1.6), col)
			b.rotation.y = -a
			PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, b.position), 0.3, 0.4)
		var pool := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.3
		pm.bottom_radius = 1.3
		pm.height = 0.05
		pool.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.28, 0.35, 0.85) if level == 2 else Color(0.25, 0.3, 0.2, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pool.material_override = mat
		pool.position = Vector3(0, 0.02, 0)
		n.add_child(pool)
	elif s.find("kiln") >= 0 or s.find("bloomery") >= 0 or s.find("hump") >= 0 or s.find("hut") >= 0 or s.find("house") >= 0 or s.find("dwelling") >= 0 or s.find("pueblo") >= 0 or s.find("stub") >= 0:
		if s.find("kiln") >= 0 or s.find("bloomery") >= 0 or s.find("hump") >= 0:
			var r := rng.randf_range(1.0, 1.4)
			CreatureBodies.ball(n, Vector3(r, r * (0.6 if level == 1 else 0.95), r), Vector3(0, r * 0.3, 0), Color(0.5, 0.36, 0.28) if level == 2 else col)
			PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, Vector3(0, r * 0.4, 0)), r * 0.8, r * 0.8)
		else:
			# Wall stubs or house floors: a rectangle of low wall.
			for k in 4:
				var a := k * TAU / 4.0 + PI * 0.25
				var w := CreatureBodies.box(n, Vector3(3.2, 0.45 if level == 1 else 0.9, 0.4), Vector3(cos(a) * 2.2, 0.3, sin(a) * 2.2), col)
				w.rotation.y = -a + PI * 0.5
				PropCollision.capsule(cb, Transform3D(w.basis * Basis(Vector3(0, 0, 1), PI * 0.5), w.position), 0.25, 3.2)
	elif s.find("wall") >= 0 or s.find("terrace") >= 0 or s.find("ring") >= 0 or s.find("corral") >= 0 or s.find("fold") >= 0 or s.find("fence") >= 0:
		for k in 10:
			var x := (k - 4.5) * 0.9
			var w := CreatureBodies.box(n, Vector3(0.9, 0.4 if level == 1 else 0.8, 0.4), Vector3(x, 0.25, sin(k * 0.9) * 0.3), col.darkened(rng.randf() * 0.15))
			PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, w.position), 0.3, 0.5)
	elif s.find("inuksuk") >= 0 or s.find("cache") >= 0 or s.find("stone figure") >= 0 or s.find("cairn") >= 0:
		var y := 0.0
		for k in (3 if level == 1 else 6):
			var sz := Vector3(0.5, 0.25, 0.4) * (1.0 - k * 0.1)
			var b := CreatureBodies.box(n, sz, Vector3(0, y + sz.y * 0.5, 0), col)
			y += sz.y * 0.9
		PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), 0.35, 1.0)
	elif s.find("scar") >= 0 or s.find("art") >= 0 or s.find("ochre") >= 0 or s.find("hands") >= 0 or s.find("bark") >= 0 or s.find("bridge") >= 0 or s.find("cable") >= 0 or s.find("grove") >= 0 or s.find("stools") >= 0:
		# Marks on trees, a fallen line, a grove: a few leaning poles and
		# a coloured patch stand in for what the chunk's own trees carry.
		for k in 3:
			var p := CreatureBodies.cone(n, 0.05, 0.03, 2.4, Vector3(k * 0.9 - 0.9, 0.6, 0), CampProps.POLE.darkened(0.35), 0.0, 5)
			p.rotation = Vector3(rng.randf_range(1.0, 1.4), rng.randf() * TAU, 0)
	else:
		var r := rng.randf_range(1.2, 2.0)
		CreatureBodies.ball(n, Vector3(r, r * 0.4, r * 0.8), Vector3(0, r * 0.1, 0), col)
		PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, Vector3(0, r * 0.2, 0)), r * 0.7, r * 0.4)
	n.set_meta("level", level)
	n.set_meta("sig", sig)
