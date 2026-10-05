class_name CampProps
## What a camp looks like (design 30 Sept §BO): a people's shelter form
## and its aesthetic.props, dressed by the biome's palette, built from a
## few shapes matched on the words the people files use (a rack, poles,
## a midden, an upturned boat, pans, a fence, a kiln, jars, a trap frame,
## a lined spring, a cache, a hut). Also the store (§BL): a woodpile and
## a food store that scale with what is banked, no HUD.

const WOOD := Color(0.4, 0.3, 0.19)
const POLE := Color(0.55, 0.42, 0.26)
const STONE := Color(0.46, 0.46, 0.48)
const ROPE := Color(0.62, 0.55, 0.38)


static func _has(s: String, words: Array) -> bool:
	for w in words:
		if s.find(w) >= 0:
			return true
	return false


## One prop from its phrase, at the origin of a new node under `parent`
## (the caller places it). `pal`: the people's palette colours.
static func prop(parent: Node3D, phrase: String, pal: Array, rng: RandomNumberGenerator, _body: StaticBody3D) -> Node3D:
	var s := phrase.to_lower()
	var n := Node3D.new()
	n.name = "Prop"
	parent.add_child(n)
	# Its own collision cb: the shapes ride with the prop wherever the
	# caller puts it (on the camp's cb they sat at the camp's origin,
	# the fire).
	var cb := PropCollision.body(n)
	var c0: Color = pal[0] if not pal.is_empty() else STONE
	var c1: Color = pal[1 % pal.size()] if not pal.is_empty() else POLE
	if _has(s, ["rack", "racks", "loom", "hide stretched", "cheeses", "corn under", "dung cakes", "potatoes spread", "salt cakes"]):
		_rack(n, rng, c1, cb)
	elif _has(s, ["boat", "canoe", "kayak", "dugout"]):
		_hull(n, rng, c0, cb)
	elif _has(s, ["midden", "mound", "heap", "pile", "stack", "peat stack"]):
		var col := Color(0.82, 0.78, 0.66) if s.find("shell") >= 0 or s.find("midden") >= 0 else (Color(0.16, 0.14, 0.12) if _has(s, ["charcoal", "peat", "soot"]) else Color(0.4, 0.32, 0.2))
		_mound(n, rng.randf_range(1.2, 2.2), rng.randf_range(0.4, 0.9), col, cb)
	elif _has(s, ["pans", "floor", "griddle", "slab", "grinding", "mortar", "chuño ground"]):
		_flats(n, rng, cb)
	elif _has(s, ["fence", "wall", "corral", "fold", "ring", "hurdle", "terrace"]):
		_ring(n, rng, STONE if _has(s, ["stone", "wall", "corral", "terrace"]) else POLE, s.find("stone") >= 0 or s.find("wall") >= 0, cb)
	elif _has(s, ["kiln", "chimney", "cistern", "tar pit", "tar pot", "parching"]):
		_hump(n, rng, Color(0.55, 0.4, 0.3), cb)
	elif _has(s, ["jars", "pots", "gourds", "baskets", "boxes", "cache", "granary", "storehouse", "store on a post"]):
		_jars(n, rng, c0, cb)
	elif _has(s, ["trap", "hive", "press", "net poles", "eel"]):
		_frame(n, rng, POLE, cb)
	elif _has(s, ["spring", "waterhole", "channel", "pond", "pit", "cenote"]):
		_spring(n, rng, cb)
	elif _has(s, ["stone figure", "cairn"]):
		_cairn(n, rng, cb)
	elif _has(s, ["travois", "tent poles", "poles", "stakes", "climbing pole", "torch pole", "post"]):
		_poles(n, rng, POLE, cb)
	elif _has(s, ["lamp"]):
		_lamp(n)
	elif _has(s, ["ladder", "bridge", "hearth box", "blowpipe"]):
		_poles(n, rng, ROPE, cb)
	else:
		_bundle(n, rng, c1)
	return n


static func _rack(n: Node3D, rng: RandomNumberGenerator, col: Color, body: StaticBody3D) -> void:
	for x in [-0.9, 0.9]:
		var p := CreatureBodies.cone(n, 0.05, 0.04, 1.7, Vector3(x, 0.85, 0), POLE, 0.0, 6)
		PropCollision.capsule(body, p.transform, 0.05, 1.7)
	for y in [1.1, 1.55]:
		var bar := CreatureBodies.cone(n, 0.03, 0.03, 1.9, Vector3(0, y, 0), POLE, 0.0, 5)
		bar.rotation.z = PI * 0.5
	for i in 5:
		var strip := CreatureBodies.box(n, Vector3(0.14, rng.randf_range(0.25, 0.4), 0.03), Vector3(-0.7 + i * 0.35, 1.35, 0), col.darkened(rng.randf() * 0.2))
		strip.rotation.y = rng.randf_range(-0.3, 0.3)


static func _hull(n: Node3D, rng: RandomNumberGenerator, col: Color, body: StaticBody3D) -> void:
	var hull := CreatureBodies.ball(n, Vector3(0.55, 0.35, 1.9), Vector3(0, 0.28, 0), col.darkened(0.2))
	hull.rotation.y = rng.randf() * TAU
	PropCollision.capsule(body, Transform3D(hull.basis * Basis(Vector3(1, 0, 0), PI * 0.5), hull.position), 0.5, 3.4)


static func _mound(n: Node3D, r: float, h: float, col: Color, body: StaticBody3D) -> void:
	CreatureBodies.ball(n, Vector3(r, h, r * 0.85), Vector3(0, h * 0.25, 0), col)
	PropCollision.capsule(body, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.3, 0)), r * 0.7, h * 0.6)


static func _flats(n: Node3D, rng: RandomNumberGenerator, body: StaticBody3D) -> void:
	for i in 3:
		var s := Vector3(rng.randf_range(0.7, 1.1), 0.14, rng.randf_range(0.6, 0.9))
		var b := CreatureBodies.box(n, s, Vector3(rng.randf_range(-1.0, 1.0), 0.07, rng.randf_range(-0.8, 0.8)), STONE.lightened(rng.randf() * 0.15))
		b.rotation.y = rng.randf() * TAU
		PropCollision.capsule(body, Transform3D(Basis.IDENTITY, b.position), 0.45, 0.2)


static func _ring(n: Node3D, rng: RandomNumberGenerator, col: Color, stone: bool, body: StaticBody3D) -> void:
	var r := rng.randf_range(1.8, 2.6)
	var count := 12
	for i in count:
		var a := i * TAU / count
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		if i == 0:
			continue # the gap
		if stone:
			var b := CreatureBodies.box(n, Vector3(0.9, rng.randf_range(0.5, 0.8), 0.35), pos + Vector3(0, 0.3, 0), col.darkened(rng.randf() * 0.15))
			b.rotation.y = -a + PI * 0.5
			PropCollision.capsule(body, Transform3D(b.basis * Basis(Vector3(0, 0, 1), PI * 0.5), b.position), 0.25, 0.9)
		else:
			var p := CreatureBodies.cone(n, 0.05, 0.03, 1.3, pos + Vector3(0, 0.6, 0), col, 0.0, 5)
			p.rotation = Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
			PropCollision.capsule(body, p.transform, 0.05, 1.3)


static func _hump(n: Node3D, rng: RandomNumberGenerator, col: Color, body: StaticBody3D) -> void:
	var r := rng.randf_range(0.9, 1.3)
	CreatureBodies.ball(n, Vector3(r, r * 0.9, r), Vector3(0, r * 0.3, 0), col)
	var mouth := CreatureBodies.box(n, Vector3(0.5, 0.5, 0.3), Vector3(0, 0.3, r * 0.85), Color(0.1, 0.08, 0.07))
	mouth.rotation.y = 0.0
	PropCollision.capsule(body, Transform3D(Basis.IDENTITY, Vector3(0, r * 0.4, 0)), r * 0.8, r * 0.8)


static func _jars(n: Node3D, rng: RandomNumberGenerator, col: Color, body: StaticBody3D) -> void:
	for i in rng.randi_range(3, 5):
		var h := rng.randf_range(0.4, 0.7)
		var j := CreatureBodies.cone(n, rng.randf_range(0.18, 0.26), 0.14, h, Vector3(rng.randf_range(-0.6, 0.6), h * 0.5, rng.randf_range(-0.5, 0.5)), col.lightened(0.1).darkened(rng.randf() * 0.2), 0.0, 10)
		PropCollision.capsule(body, j.transform, 0.22, h)


static func _frame(n: Node3D, rng: RandomNumberGenerator, col: Color, body: StaticBody3D) -> void:
	var p := CreatureBodies.cone(n, 0.06, 0.05, 2.2, Vector3(0, 1.1, 0), col, 0.0, 6)
	PropCollision.capsule(body, p.transform, 0.06, 2.2)
	var arm := CreatureBodies.cone(n, 0.03, 0.03, 1.2, Vector3(0.6, 2.0, 0), col, 0.0, 5)
	arm.rotation.z = PI * 0.5
	for i in 2:
		var cage := CreatureBodies.cone(n, 0.16, 0.05, 0.8, Vector3(0.35 + i * 0.5, 1.45, 0), ROPE.darkened(0.2), 0.0, 8)
		cage.rotation.x = rng.randf_range(-0.2, 0.2)


static func _spring(n: Node3D, rng: RandomNumberGenerator, body: StaticBody3D) -> void:
	for i in 8:
		var a := i * TAU / 8.0
		var b := CreatureBodies.box(n, Vector3(0.5, 0.28, 0.4), Vector3(cos(a) * 1.3, 0.14, sin(a) * 1.3), STONE)
		b.rotation.y = -a
		PropCollision.capsule(body, Transform3D(Basis.IDENTITY, b.position), 0.25, 0.4)
	var pool := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 1.1
	pm.bottom_radius = 1.1
	pm.height = 0.05
	pm.radial_segments = 16
	pool.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.33, 0.48, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	pool.material_override = mat
	pool.position = Vector3(0, 0.06, 0)
	n.add_child(pool)


static func _cairn(n: Node3D, rng: RandomNumberGenerator, body: StaticBody3D) -> void:
	var y := 0.0
	for i in 6:
		var s := Vector3(rng.randf_range(0.35, 0.6), 0.24, rng.randf_range(0.3, 0.5)) * (1.0 - i * 0.1)
		var b := CreatureBodies.box(n, s, Vector3(0, y + s.y * 0.5, 0), STONE.darkened(rng.randf() * 0.2))
		b.rotation.y = rng.randf() * TAU
		y += s.y * 0.92
	PropCollision.capsule(body, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), 0.35, 1.0)


static func _poles(n: Node3D, rng: RandomNumberGenerator, col: Color, body: StaticBody3D) -> void:
	for i in rng.randi_range(3, 6):
		var p := CreatureBodies.cone(n, 0.04, 0.03, rng.randf_range(2.0, 3.0), Vector3.ZERO, col, 0.0, 5)
		var lean := rng.randf_range(0.15, 0.3)
		var a := i * TAU / 6.0 + rng.randf() * 0.4
		p.position = Vector3(cos(a) * 0.3, 1.2, sin(a) * 0.3)
		p.rotation = Vector3(lean * cos(a), 0, -lean * sin(a))
		PropCollision.capsule(body, p.transform, 0.04, 2.4)


static func _lamp(n: Node3D) -> void:
	CreatureBodies.cone(n, 0.12, 0.1, 0.9, Vector3(0, 0.45, 0), STONE, 0.0, 8)
	CreatureBodies.ball(n, Vector3(0.16, 0.06, 0.16), Vector3(0, 0.95, 0), STONE.darkened(0.2))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 0.9
	l.omni_range = 5.0
	l.shadow_enabled = false
	l.position = Vector3(0, 1.05, 0)
	n.add_child(l)


static func _bundle(n: Node3D, rng: RandomNumberGenerator, col: Color) -> void:
	for i in 3:
		var b := CreatureBodies.cone(n, 0.08, 0.06, 0.9, Vector3(rng.randf_range(-0.2, 0.2), 0.08, rng.randf_range(-0.2, 0.2)), col, 0.0, 6)
		b.rotation = Vector3(PI * 0.5, rng.randf() * 0.6, 0)


## The shelter's wall and roof colours (the people's shelter.materials over
## their palette): [wall, roof]. The workshop (§EL) wears the same.
static func tints(people: Dictionary, pal: Array) -> Array:
	var sh: Dictionary = people.get("shelter", {})
	var mats := " ".join(PackedStringArray(sh.get("materials", []))).to_lower()
	var wall: Color = pal[0] if not pal.is_empty() else Color(0.5, 0.42, 0.3)
	var roof := Color(0.7, 0.58, 0.32)
	if _has(mats, ["snow"]):
		wall = Color(0.9, 0.92, 0.96)
		roof = wall
	elif _has(mats, ["stone", "limestone", "adobe", "daub"]):
		wall = wall.lerp(STONE if not _has(mats, ["adobe"]) else Color(0.7, 0.5, 0.32), 0.6)
	elif _has(mats, ["hide"]):
		wall = wall.lerp(Color(0.55, 0.42, 0.28), 0.6)
	elif _has(mats, ["bark", "plank", "pole"]):
		wall = wall.lerp(WOOD, 0.5)
	if _has(mats, ["turf", "sod"]):
		roof = Color(0.35, 0.45, 0.22)
	elif _has(mats, ["thatch", "reed", "grass", "frond", "leaf"]):
		roof = Color(0.72, 0.6, 0.32)
	elif _has(mats, ["hide"]):
		roof = Color(0.5, 0.38, 0.25)
	elif _has(mats, ["bark"]):
		roof = Color(0.35, 0.28, 0.2)
	return [wall, roof]


## The shelter (a people's shelter.form and materials): a hut in the
## form the words name, coloured by the materials, its door to the fire.
static func shelter(parent: Node3D, people: Dictionary, pal: Array, rng: RandomNumberGenerator, _body: StaticBody3D) -> Node3D:
	var sh: Dictionary = people.get("shelter", {})
	var form := str(sh.get("form", "")).to_lower()
	var t := tints(people, pal)
	var wall: Color = t[0]
	var roof: Color = t[1]
	var n := Node3D.new()
	n.name = "Shelter"
	parent.add_child(n)
	# Its own collision cb: the shapes ride with the prop wherever the
	# caller puts it (on the camp's cb they sat at the camp's origin,
	# the fire).
	var cb := PropCollision.body(n)
	if _has(form, ["platform lashed", "never come"]):
		return n # the canopy folk build up in the giants (CanopyVillage)
	if _has(form, ["nothing built", "overhang is the roof"]):
		# A hide screen or a low stacked wall along the drip line.
		for i in 5:
			var b := CreatureBodies.box(n, Vector3(0.8, 0.6, 0.3), Vector3(-1.6 + i * 0.8, 0.3, 0), STONE.darkened(rng.randf() * 0.1))
			PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, b.position), 0.3, 0.6)
		return n
	if _has(form, ["cone of poles", "pole tent", "tent"]):
		var tent := CreatureBodies.cone(n, 2.1, 0.05, 3.4, Vector3(0, 1.7, 0), roof.darkened(0.1), 0.0, 10)
		PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0)), 1.6, 2.4)
		for i in 5:
			var p := CreatureBodies.cone(n, 0.04, 0.03, 4.0, Vector3(0, 2.0, 0), POLE, 0.0, 5)
			var a := i * TAU / 5.0
			p.rotation = Vector3(0.55 * cos(a), 0, 0.55 * sin(a))
		return n
	if _has(form, ["dome of snow", "snow block", "beehive", "corbelled", "round"]):
		var dome := CreatureBodies.ball(n, Vector3(2.2, 1.9, 2.2), Vector3(0, 0.2, 0), wall)
		PropCollision.capsule(cb, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)), 1.9, 1.6)
		CreatureBodies.box(n, Vector3(0.9, 1.1, 0.6), Vector3(0, 0.55, 2.0), Color(0.1, 0.09, 0.08))
		return n
	if _has(form, ["on legs", "on poles", "stilt", "over the shallows", "above the highest tide"]):
		for x in [-1.4, 1.4]:
			for z in [-1.2, 1.2]:
				var p := CreatureBodies.cone(n, 0.09, 0.08, 2.4, Vector3(x, 1.2, z), POLE, 0.0, 6)
				PropCollision.capsule(cb, p.transform, 0.09, 2.4)
		var deck := CreatureBodies.box(n, Vector3(3.6, 0.18, 3.0), Vector3(0, 2.3, 0), WOOD)
		PropCollision.capsule(cb, Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), deck.position), 1.5, 3.6)
		CreatureBodies.box(n, Vector3(3.2, 1.6, 2.6), Vector3(0, 3.2, 0), wall)
		var r := CreatureBodies.cone(n, 2.6, 0.1, 1.4, Vector3(0, 4.7, 0), roof, 0.0, 4)
		r.rotation.y = PI * 0.25
		return n
	if _has(form, ["longhouse", "one roof for several"]):
		var w := 4.0
		var l := 9.0
		var box := CreatureBodies.box(n, Vector3(w, 1.9, l), Vector3(0, 0.95, 0), wall)
		PropCollision.capsule(cb, Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(0, 1.0, 0)), w * 0.5, l)
		var r := CreatureBodies.box(n, Vector3(w * 0.75, 1.6, l + 0.4), Vector3(0, 2.6, 0), roof)
		r.rotation.z = PI * 0.25
		CreatureBodies.box(n, Vector3(1.0, 1.5, 0.3), Vector3(0, 0.75, l * 0.5 + 0.05), Color(0.1, 0.09, 0.08))
		return n
	if _has(form, ["flat-roofed", "mud-and-stone", "rooms", "block"]):
		for i in 2:
			var s := Vector3(rng.randf_range(3.0, 4.0), rng.randf_range(2.2, 2.8), rng.randf_range(2.6, 3.4))
			var b := CreatureBodies.box(n, s, Vector3(i * 3.6 - 1.8, s.y * 0.5, 0), wall)
			PropCollision.capsule(cb, Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), b.position), s.x * 0.5, s.z)
			var ladder := CreatureBodies.cone(n, 0.04, 0.04, s.y + 0.6, Vector3(i * 3.6 - 1.8 + s.x * 0.5 + 0.3, s.y * 0.5 + 0.2, 0.6), POLE, 0.0, 5)
			ladder.rotation.x = 0.25
		return n
	if _has(form, ["arched reed", "reed house", "reed island"]):
		var barrel := CreatureBodies.ball(n, Vector3(2.0, 1.8, 3.4), Vector3(0, 0.3, 0), roof)
		PropCollision.capsule(cb, Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(0, 0.9, 0)), 1.6, 5.0)
		CreatureBodies.box(n, Vector3(1.0, 1.3, 0.3), Vector3(0, 0.65, 3.2), Color(0.1, 0.09, 0.08))
		return n
	# Low houses of stone, turf, wattle, driftwood: a box under a roof.
	var s := Vector3(rng.randf_range(3.2, 4.2), rng.randf_range(1.4, 1.8), rng.randf_range(2.6, 3.4))
	var b := CreatureBodies.box(n, s, Vector3(0, s.y * 0.5, 0), wall)
	PropCollision.capsule(cb, Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), b.position), s.x * 0.5, s.z)
	var r := CreatureBodies.box(n, Vector3(s.x * 0.72, 1.2, s.z + 0.4), Vector3(0, s.y + 0.55, 0), roof)
	r.rotation.z = PI * 0.25
	CreatureBodies.box(n, Vector3(0.9, 1.2, 0.3), Vector3(0, 0.6, s.z * 0.5 + 0.05), Color(0.1, 0.09, 0.08))
	return n


# --- The store (§BL) ---------------------------------------------------------------

## A woodpile that shows what is banked: rows of logs, more as `units`
## grow (refresh_woodpile).
static func woodpile(parent: Node3D, units: float, _body: StaticBody3D) -> Node3D:
	var n := Node3D.new()
	n.name = "Woodpile"
	parent.add_child(n)
	# Its own collision cb: the shapes ride with the prop wherever the
	# caller puts it (on the camp's cb they sat at the camp's origin,
	# the fire).
	var cb := PropCollision.body(n)
	PropCollision.capsule(cb, Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0, 0.3, 0)), 0.35, 1.6)
	refresh_woodpile(n, units)
	return n


static func refresh_woodpile(n: Node3D, units: float) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	var count := clampi(int(ceil(units)), 0, 24)
	n.set_meta("units", units)
	for i in count:
		var row := i / 6
		var col := i % 6
		var l := CreatureBodies.cone(n, 0.09, 0.08, 1.1, Vector3(-0.45 + col * 0.18, 0.09 + row * 0.17, 0), CampProps.WOOD.darkened(float(i % 3) * 0.08), 0.0, 6)
		l.rotation.x = PI * 0.5


## A food store: a rack with strips hanging, baskets under it, more as
## `units` grow.
static func food_store(parent: Node3D, units: float, pal: Array, _body: StaticBody3D) -> Node3D:
	var n := Node3D.new()
	n.name = "FoodStore"
	parent.add_child(n)
	# Its own collision cb: the shapes ride with the prop wherever the
	# caller puts it (on the camp's cb they sat at the camp's origin,
	# the fire).
	var cb := PropCollision.body(n)
	for x in [-0.7, 0.7]:
		var p := CreatureBodies.cone(n, 0.05, 0.04, 1.8, Vector3(x, 0.9, 0), POLE, 0.0, 6)
		PropCollision.capsule(cb, p.transform, 0.05, 1.8)
	var bar := CreatureBodies.cone(n, 0.03, 0.03, 1.5, Vector3(0, 1.6, 0), POLE, 0.0, 5)
	bar.rotation.z = PI * 0.5
	var stock := Node3D.new()
	stock.name = "Stock"
	n.add_child(stock)
	n.set_meta("pal", pal)
	refresh_food_store(n, units)
	return n


static func refresh_food_store(n: Node3D, units: float) -> void:
	var stock: Node3D = n.get_node("Stock")
	for c in stock.get_children():
		c.queue_free()
	n.set_meta("units", units)
	var pal: Array = n.get_meta("pal", [])
	var col: Color = pal[0] if not pal.is_empty() else Color(0.6, 0.45, 0.3)
	var strips := clampi(int(units / 2.0), 0, 7)
	for i in strips:
		var strip := CreatureBodies.box(stock, Vector3(0.12, 0.35, 0.03), Vector3(-0.55 + i * 0.18, 1.4, 0), col.darkened(0.1 + 0.05 * (i % 3)))
		strip.rotation.y = 0.2 * (i % 2)
	var baskets := clampi(int(units / 6.0), 0, 5)
	for i in baskets:
		var h := 0.35
		CreatureBodies.cone(stock, 0.2, 0.16, h, Vector3(-0.5 + i * 0.28, h * 0.5, 0.35), Color(0.6, 0.5, 0.3), 0.0, 8)
