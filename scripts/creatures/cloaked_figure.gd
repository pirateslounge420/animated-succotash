class_name CloakedFigure
## Every "higher" intelligent creature is a cloaked figure (design
## reconciliation, the Falcon/Ganondorf rule): the player's own body
## (PlayerBody: the same rig, hood, cloak and cloth sim) at another scale
## and in another palette. Tribal, marsh and northern folk (~1.7 m), the
## small folk (~1.0 m, with their lanterns), the Forest troll (3.2 m, a big
## cloaked figure) and the Marsh witch. One rig, one set of movements;
## scale sets the stride (bigger: longer, slower steps), palette the look.
## Beasts stay beasts.
##
## Palettes: the player's indigo cloak with the rust hem is theirs alone.
## Folk roll their cloak at random from the palette in data/cloaks.json
## (red, orange, yellow, green, blue, indigo, violet, magenta, pink,
## black, white, grey) and their fringe from it too, a different color,
## so camps keep looking fresh; seeded from the camp, so the same camp
## has the same people on every visit. The tunic and trousers follow the
## cloak (the shader keeps their shading). Only the opening camp's pair
## draws from the old dyed-cloth families (FAMILIES: ochres, madder
## reds, ...; roll_palette strict), the designer's pick.

const PLAYER_H := 1.57

## [warm?, colors (sRGB)] per dyed-cloth family.
const FAMILIES := [
	[true, ["a8792e", "b98a3c", "8f6a2a", "c49a4a"]], # ochres
	[true, ["8a2f24", "9c3b2c", "6e2620", "a8473a"]], # madder reds
	[true, ["5a4128", "6b4a2e", "4a3620", "7a5836"]], # bog browns
	[false, ["3d5a7a", "2f4f6e", "4a6a86", "36607a"]], # woad blues
	[false, ["4f5e2c", "5d6b36", "3f4f28", "6a7a3e"]], # moss greens
	[false, ["7d776a", "8f887a", "6a655c", "a39c8c"]], # undyed greys
]
const PLAYER_CLOAK := Color("222a6c")
const PLAYER_TRIM := Color("a4492b")


## A camp's tribe: which family its folk mostly wear, from its seed.
static func tribe_family(seed_value: int) -> int:
	return absi(hash([seed_value, "tribe"])) % FAMILIES.size()


static var _cloaks := {}


## data/cloaks.json.
static func cloaks() -> Dictionary:
	if _cloaks.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/cloaks.json")) if FileAccess.file_exists("res://data/cloaks.json") else null
		_cloaks = parsed if parsed is Dictionary else {"colors": {}}
	return _cloaks


## One person's [main, trim] (sRGB). Anyone: a random cloak from the
## palette (data/cloaks.json) and a random different fringe. `strict`
## (the opening camp): from the dyed-cloth family `family`, with a
## contrasting trim.
static func roll_palette(rng: RandomNumberGenerator, family: int, strict := false) -> Array:
	if not strict:
		var cols: Dictionary = cloaks().get("colors", {})
		var names: Array = cols.keys()
		if names.size() >= 2:
			var avoid: Array = cloaks().get("avoid", [])
			for attempt in 8:
				var a: String = names[rng.randi_range(0, names.size() - 1)]
				var b: String = names[rng.randi_range(0, names.size() - 1)]
				if a == b or avoid.has([a, b]):
					continue
				return [Color(str(cols[a])), Color(str(cols[b]))]
	var fam := family
	var main := _pick(rng, fam)
	# A contrasting edge: warm on cool, cool on warm.
	var warm: bool = FAMILIES[fam][0]
	var pool: Array = []
	for i in FAMILIES.size():
		if FAMILIES[i][0] != warm:
			pool.append(i)
	var trim := _pick(rng, pool[rng.randi_range(0, pool.size() - 1)])
	trim = trim.lightened(0.15)
	# Never the player's indigo, and never the player's rust on it.
	if _near(main, PLAYER_CLOAK) or (_near(main, PLAYER_CLOAK, 0.25) and _near(trim, PLAYER_TRIM)):
		main = Color(FAMILIES[0][1][0])
	return [main, trim]


static func _pick(rng: RandomNumberGenerator, fam: int) -> Color:
	var cols: Array = FAMILIES[fam][1]
	var c := Color(str(cols[rng.randi_range(0, cols.size() - 1)]))
	return c.lightened(rng.randf_range(0.0, 0.08)) if rng.randf() < 0.5 else c.darkened(rng.randf_range(0.0, 0.1))


static func _near(a: Color, b: Color, within := 0.12) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < within


## A cloaked figure `height_m` tall in `main` / `trim` (sRGB): the parts
## dictionary creatures and camps use ({root, legs, wings, tail, light,
## cloaked}); `seated` sits it down. Its legs stride by its own velocity
## (PlayerBody.set_velocity()), so `legs` is empty; `wings` are its arms.
## Every cloaked figure's height against the one it's built with
## (data/movement.json body.folk_scale: from play, a step shorter, like
## the player).
static var FOLK_K := float(Tuning.section("movement", "body").get("folk_scale", 1.0))


static func build(height_m: float, main: Color, trim: Color, seated := false) -> Dictionary:
	var body := PlayerBody.new()
	body.is_player = false
	body.seated = seated
	var k := height_m * FOLK_K / PLAYER_H
	body.scale = Vector3.ONE * k
	body.stride_scale = k
	body.set_palette(main, trim)
	return {"root": body, "legs": [], "wings": body.arms.duplicate(), "tail": null, "light": null, "cloaked": true}


## A small folk's lantern in the right hand: a warm glow, and its light.
static func add_lantern(b: Dictionary, color := Color(1.0, 0.6, 0.25)) -> void:
	var body: PlayerBody = b.root
	var arm: Node3D = body.arms[1]
	var lantern := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.09, 0.12, 0.09)
	lantern.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	lantern.material_override = mat
	lantern.position = Vector3(0, -PlayerBody.ARM_M - 0.08, 0)
	arm.add_child(lantern)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 4.0
	light.light_energy = 1.2
	light.position = lantern.position
	arm.add_child(light)
	b.light = light


## Its hit parts (Hits: head, body, limbs) on the rig's pivots, and a
## blocker in the torso if `block`: capsules in the player-body's own
## units (the root's scale carries them to size).
static func hitboxes(owner: Node, b: Dictionary, block: bool) -> Array:
	var body: PlayerBody = b.root
	var out: Array = []
	var torso := body.torso()
	var t := Hitboxes.capsule(owner, torso, Vector3(0, 0.02, 0), Vector3(0, 0.5, 0), 0.19)
	t.name = "Torso"
	Hits.mark(t, "body")
	out.append(t)
	var h := Hitboxes.sphere(owner, body.head, Vector3(0, 0.12, 0.0), 0.13)
	h.name = "Head"
	Hits.mark(h, "head")
	out.append(h)
	for s in 2:
		var leg: Node3D = body.legs()[s]
		var l := Hitboxes.capsule(owner, leg, Vector3(0, -0.02, 0), Vector3(0, -PlayerBody.THIGH_M - PlayerBody.SHIN_M + 0.05, 0), 0.07)
		l.name = "Leg" + ("L" if s == 0 else "R")
		Hits.mark(l, "limb")
		out.append(l)
		var arm: Node3D = body.arms[s]
		var a := Hitboxes.capsule(owner, arm, Vector3(0, -0.03, 0), Vector3(0, -PlayerBody.ARM_M + 0.05, 0), 0.06)
		a.name = "Arm" + ("L" if s == 0 else "R")
		Hits.mark(a, "limb")
		out.append(a)
	if block:
		out.append(Hitboxes.blocker(owner, body, Vector3(0, 0.35, 0), Vector3(0, 1.25, 0), 0.25))
	return out
