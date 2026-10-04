class_name RuinBuilder
## Builds a ruin (Ruins.find() site) as one low-poly mesh plus collision,
## with a plain-box far LOD past LOD_M.
##
## Everything is stacked stone blocks, bevelled, worn and irregular, so
## collapse comes for free: each
## column of a wall or tower stops at its own jagged height, breaches drop
## whole stretches to stumps, window and door gaps are missing blocks, and
## fallen blocks lie in rubble at the foot. Moss creeps over every upward
## face and the lowest courses, ivy hangs in strands from broken tops, and
## vertex alpha marks moss for the night glow (shaders/ruin.gdshader).
##
## Silhouettes carry: castles ring a hilltop with a tall keep, towers stand
## 14-22 m, aqueducts stride level across the ground on tall piers.
## Other countries have their own (Ruins): igloo clusters in snow, a
## treehouse village of platforms and rope bridges on giant jungle trees,
## a boardwalk on stilts out to a cabin in the marsh; and now and then a
## pyramid (sandstone and cased in the desert, a stepped temple elsewhere).
## Ruins
## are built up to ~2.6 km out, beyond the terrain chunks, so their bases
## run down into a buried mound or deep footings and never float over the
## coarser far terrain.

const COURSE_M := 0.85
# Weathered blue-grey stone (the references' castles; R1a #6F7A8A on
# screen by day, cooled toward #3E4C8C at night by the ruin shader),
# darker than bare rock so walls hold their shape in full sun. Five tones
# so walls stay mottled.
const STONES := [Color(0.44, 0.46, 0.49), Color(0.39, 0.41, 0.45), Color(0.48, 0.5, 0.52), Color(0.35, 0.37, 0.41), Color(0.43, 0.45, 0.5)]
const MOSS := Color(0.2, 0.44, 0.14)
## Lamp-gold tomb light: R1a lantern #FFC040.
const LAMP := Color("#ffc040")
const IVY := Color(0.1, 0.32, 0.12)
const IVY_LIGHT := Color(0.2, 0.46, 0.16)
const EARTH := Color(0.36, 0.3, 0.22)
const GRASS := Color(0.3, 0.52, 0.2)

## Share of ruins where survivors of the old civilization have camped:
## tepees and lean-tos of poles and woven vines, and a cold fire ring.
const CAMP_CHANCE := 0.35
const WOOD := Color(0.4, 0.3, 0.2)
const HIDE := Color(0.55, 0.42, 0.3)
const OLD_WOOD := Color(0.36, 0.32, 0.26) # weathered grey-brown planks
const BARK := Color(0.34, 0.3, 0.24)
const JUNGLE_LEAF := Color(0.16, 0.42, 0.16)
const THATCH := Color(0.55, 0.47, 0.28)
const SNOW := Color(0.7, 0.77, 0.86) # packed snow blocks, cooler than a snowfield so they read
const ROPE := Color(0.42, 0.36, 0.24)
# Desert pyramids: warm sandstone; jungle temples: pale limestone.
const SANDSTONE := [Color(0.64, 0.54, 0.38), Color(0.59, 0.49, 0.34), Color(0.67, 0.58, 0.41), Color(0.62, 0.52, 0.38), Color(0.56, 0.47, 0.33)]
const BONE := Color(0.82, 0.78, 0.66)
const CLAY := Color(0.52, 0.32, 0.2)
const GOLD := Color(0.95, 0.75, 0.25)
const LIMESTONE := [Color(0.62, 0.6, 0.52), Color(0.56, 0.55, 0.49), Color(0.66, 0.63, 0.55), Color(0.52, 0.52, 0.47), Color(0.6, 0.57, 0.5)]

## Distance where the drawn blocks give way to the plain-box LOD, and the
## hysteresis round it.
const LOD_M := 150.0
const LOD_MARGIN_M := 15.0

## Surface materials (vertex UV.x; shaders/ruin.gdshader picks the
## texture): set `mat` before adding a part.
const STONE_M := 0
const WOOD_M := 1
const SNOW_M := 2
const THATCH_M := 3
const LEAF_M := 4
const HIDE_M := 5

static var _material: ShaderMaterial

var map: PlanetData
var site: Dictionary
var rng := RandomNumberGenerator.new()
var up: Vector3
var ex: Vector3 # local +x
var ez: Vector3 # local +z (right-handed with ex, up)
var base_e := 0.0
## 0-1 how damp the site is (blueprint moisture): dry ruins are bare
## stone, wet ones are thick with moss and draped in ivy.
var wet := 0.5

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _m := PackedVector2Array() # material per vertex (x)
## The material new geometry gets.
var mat := STONE_M
## Stone colors for block() and rubble().
var palette: Array = STONES
## Off: box() and boulder() add no collision (stair steps, which a ramp
## stands in for; grave mounds and tepee poles, which get their own; leaf
## crowns; grave goods too small to trip on).
var solid := true
## Boxes drawn plain (box()): set for a big build's insides.
var plain := false
## Where the near mesh gives way to the far LOD (a big build reaches
## further: its middle is far from the walls you stand by).
var _lod_m := LOD_M
## Draw the near mesh lit per pixel (big walls: one vertex's shade would
## darken metres of wall).
var _lit_per_pixel := false
## 0-1 darkening for stone that's only ever seen from inside (a barrow's
## passage, the pyramid's corridor and chamber): the flat ambient light
## reaches in regardless, so the shade is baked into the stone.
var shade := 0.0
## Contact shade, baked into the vertex colours where things meet (look
## pass, 1 Oct; data/look.json cavity, CAVITY): `foot_y` is the ground
## under the part being added (local y; NAN: not standing on the ground),
## and box() and boulder() darken each corner by how near it is, so walls,
## piers, rubble and rocks are dark at their feet. Faces looking toward
## `inside_at` (local, y ignored) are inside a tower or keep and darkened
## by `inside`; `jamb` darkens a block's end faces (local x), the sides of
## a doorway. Every box's underside (local -y: the joint under each block,
## lintels, arch soffits, deck and plank undersides, the inside of an
## igloo's dome) and any face looking down are darkened by ruin_under.
var foot_y := NAN
var inside_at := Vector3.INF
var inside := 0.0
var jamb := 0.0
static var CAVITY := Tuning.section("look", "cavity")
static var FOOT := float(CAVITY.get("ruin_foot", 0.5))
static var FOOT_M := maxf(float(CAVITY.get("ruin_foot_m", 1.2)), 0.05)
static var UNDER := float(CAVITY.get("ruin_under", 0.5))
static var INSIDE := float(CAVITY.get("ruin_inside", 0.35))
static var JAMB := float(CAVITY.get("ruin_jamb", 0.4))
## Lights inside tombs: [local position, color, range m, energy]
## (make_node() adds an OmniLight3D for each).
var _lights: Array = []
## The tomb's lamps (Mike, 2 Oct): stone lamps that stand dark until the
## ruin's hearth burns (OldHearths.update_lamps): [flame position (local),
## range m, energy].
var _lamps: Array = []
## The delve under a barrow (Delves.layout) and the height between its
## frame and this one (base_e - the layout's base_e), for make_node.
var _delve: Dictionary = {}
var _delve_off := 0.0
## The delve's inside, vertices [_delve_from, _delve_to): drawn per pixel.
var _delve_from := -1
var _delve_to := -1
## Ivy strand tops [top, out, length] (local), for the vine species' cards.
var _vine_anchors: Array = []
## The ruin's overgrowth (design 3 Oct §DI, Overgrowth.for_site): set by
## compute() before the build; empty for anything else built with these
## parts (nests, lone rocks), which keep their old moss.
var og: Dictionary = {}
var _og_on := false
## og's moss column over the builder's moss pattern (Overgrowth.PATTERN_MEAN).
var _og_k := 1.0
## The shade side (away from the sun), local and horizontal.
var _og_shade := Vector3.ZERO
var _og_ss := 1.6
## Lichen in the stone's tile (UV.y on stone, the ruin shader).
var lichen := 0.0
## Stone boxes for the plants' spots (_og_spots): [xf, half size, foot_y].
var _og_boxes: Array = []
## The hanging places (ivy() calls) and those kept by the vine column.
var _ivy_places := 0
var _ivy_kept := 0
## Boulder tops [top, out, length] (local), the same for surfaces.boulder.
var _boulder_anchors: Array = []
## Collision triangles: plain boxes and thin slabs behind covers, much
## cheaper than the drawn blocks.
var _cv := PackedVector3Array()
## Collision for the round parts: point sets whose convex hulls stand in
## for boulders, giant trunks and grave mounds (make_node() turns each
## into a ConvexPolygonShape3D).
var _ch: Array[PackedVector3Array] = []
## Far LOD (past LOD_M): plain boxes too, in the blocks' face colors, and
## the mound as is; no ivy.
var _lv := PackedVector3Array()
var _ln := PackedVector3Array()
var _lc := PackedColorArray()
var _lm := PackedVector2Array()
## Camp shelters, [local center (on the ground), radius, height]: standing
## inside one keeps the rain off (Landmarks.sheltered_at).
var _shelters: Array = []
var _tower_r := 0.0
var _stub_angle := 0.0
## Where a living camp's fire goes (local, on the ground or floor), if the
## ruin is inhabited (Ruins.inhabited()); Camps builds it.
var _camp_spot := Vector3.ZERO


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/ruin.gdshader")
		Look.register(_material)
	return _material


## The same stone lit per pixel, for a delve's insides (design 1 Oct §CJ):
## lit only by your torch and a hearth, its big slabs would get the light
## only at their corners with the ruins' vertex lighting.
static var _material_lit: ShaderMaterial = null


static func material_lit() -> ShaderMaterial:
	if _material_lit == null:
		var sh := Shader.new()
		sh.code = (preload("res://shaders/ruin.gdshader") as Shader).code.replace("vertex_lighting, ", "")
		_material_lit = ShaderMaterial.new()
		_material_lit.shader = sh
		Look.register(_material_lit)
	return _material_lit


## Build a ruin's geometry. Pure and thread-safe (reads the planet data
## only), so Landmarks runs it on a worker thread; make_node() turns the
## result into nodes on the main thread.
static func compute(p_map: PlanetData, p_site: Dictionary) -> Dictionary:
	var b := RuinBuilder.new()
	b.map = p_map
	b.site = p_site
	b.rng.seed = p_site.seed
	b.up = p_site.dir
	var a: float = p_site.heading + PI * 0.5
	b.ex = CubeSphere.north(b.up) * cos(a) + CubeSphere.east(b.up) * sin(a)
	b.ez = b.ex.cross(b.up).normalized()
	b.base_e = p_map.terrain.elevation(b.up, true)
	b.wet = smoothstep(0.2, 0.8, p_map.sample(p_map.moisture, b.up))
	b._og_setup()
	match p_site.kind:
		Ruins.Kind.CASTLE:
			b._castle()
		Ruins.Kind.TOWER:
			b._lone_tower()
		Ruins.Kind.AQUEDUCT:
			b._aqueduct()
		Ruins.Kind.IGLOO:
			b._igloos()
		Ruins.Kind.TREEHOUSE:
			b._treehouse()
		Ruins.Kind.BOARDWALK:
			b._boardwalk()
		Ruins.Kind.PYRAMID:
			b._pyramid()
		Ruins.Kind.GRAVEYARD:
			b._graveyard()
		Ruins.Kind.BARROW:
			b._barrow()
		Ruins.Kind.CRAG_FORTRESS:
			b._crag_fortress()
		Ruins.Kind.TEMPLE_CITY:
			b._temple_city()
		Ruins.Kind.CARVED_CLIFFS:
			b._carved_cliffs()
		Ruins.Kind.CLIFF_DWELLING:
			b._cliff_dwelling()
		Ruins.Kind.BRICK_CITY:
			b._brick_city()
		Ruins.Kind.STONE_HEADS:
			b._stone_heads()
		Ruins.Kind.TERRACED_PUEBLO:
			b._terraced_pueblo()
		Ruins.Kind.STONE_CIRCLE:
			b._stone_circle()
		Ruins.Kind.HEWN_TEMPLE:
			b._hewn_temple()
		Ruins.Kind.HANGING_GARDENS:
			b._hanging_gardens()
		Ruins.Kind.ABBEY:
			b._abbey()
		Ruins.Kind.LONG_WALL:
			if p_site.has("piece"):
				b._long_wall_piece()
			else:
				b._long_wall_gate()
	# Root-trees on old monuments in the wet tropics (§DR.2).
	b._root_trees_elsewhere()
	# Its own roll, so a camp never changes the ruin itself. (Only the stone
	# ruins: the others are dwellings already.)
	var camp_rng := RandomNumberGenerator.new()
	camp_rng.seed = hash([p_site.seed, "camp"])
	var survivors: bool = p_site.kind <= Ruins.Kind.AQUEDUCT and camp_rng.randf() < CAMP_CHANCE
	if survivors:
		b.rng = camp_rng
		b._camp(p_site.kind)
	elif p_site.kind <= Ruins.Kind.AQUEDUCT:
		b._stone_camp_spot()
	# The plants it wears (§DI): ferns at its feet and in its gaps, grass
	# and herbs along its tops.
	var og_plants := Overgrowth.plants(p_map, p_site, b.og, b._og_spots(), b._og_shade)
	return {"og": b.og, "og_plants": og_plants, "og_shade": b._og_shade, "ivy_places": b._ivy_places, "ivy_kept": b._ivy_kept, "site": p_site, "v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch,
		"lv": b._lv, "ln": b._ln, "lc": b._lc, "lm": b._lm, "up": b.up, "ex": b.ex, "ez": b.ez, "base_e": b.base_e,
		"shelters": b._shelters, "camp_spot": b._camp_spot, "lights": b._lights, "lamps": b._lamps, "delve": b._delve, "delve_off": b._delve_off, "delve_from": b._delve_from, "delve_to": b._delve_to, "vine_anchors": b._vine_anchors, "boulder_anchors": b._boulder_anchors, "lod_m": b._lod_m, "lit_per_pixel": b._lit_per_pixel, "root_trees": b._root_trees,
		"water": {"v": b._wv, "uv": b._wuv, "uv2": b._wuv2}, "falls": {"v": b._fv, "n": b._fn, "uv": b._fuv, "uv2": b._fuv2}, "garden": b._garden}


## A lone rock mesh (den stones and the like): a boulder, or a bevelled
## block when `block` is set. Drawn with the ruin material.
static func rock_mesh(size: Vector3, p_seed: int, col: Color, block := false) -> ArrayMesh:
	var b := RuinBuilder.new()
	b.rng.seed = p_seed
	if block:
		b.box(Transform3D(), size, col, 0.2, 0.14, 0.08)
	else:
		# Callers set a stone about a third of its height into the ground
		# (Camps, CreatureSpawner's dens): its foot shade starts there.
		b.foot_y = -size.y * 0.35
		b.boulder(Vector3.ZERO, size * 0.5, Basis(), col, 0.35)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b._v
	arrays[Mesh.ARRAY_NORMAL] = b._n
	arrays[Mesh.ARRAY_COLOR] = b._c
	arrays[Mesh.ARRAY_TEX_UV] = b._m
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Collision for rock_mesh(size, p_seed, ...) as a boulder (not a block):
## points in the rock's own space whose convex hull is the stone
## (boulder_hull()), for a ConvexPolygonShape3D.
static func rock_hull(size: Vector3, p_seed: int) -> PackedVector3Array:
	var r := RandomNumberGenerator.new()
	r.seed = p_seed
	return boulder_hull(Vector3.ZERO, size * 0.5, Basis(), _bump_phase(r))


## Reverse every triangle's winding in mesh arrays (vertex, normal, colour,
## UV), normals unchanged. The builder winds its faces counter-clockwise
## seen from the side their normal points to; Godot calls clockwise the
## front, and lit per pixel with cull_disabled it turns a "back" face's
## normal round, so every face you look at would face away from your torch
## (the vertex-lit ruins never take that turn). For the delve's own mesh.
static func _flip_winding(arrays: Array) -> void:
	for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
		var p = arrays[a]
		for k in range(0, p.size() - 2, 3):
			var t = p[k + 1]
			p[k + 1] = p[k + 2]
			p[k + 2] = t
		arrays[a] = p


## Main thread: mesh and collision (see placement()).
static func make_node(data: Dictionary, world: Node) -> Node3D:
	var site: Dictionary = data.site
	var root := Node3D.new()
	root.name = Ruins.site_name(site).replace(" ", "")
	root.set_meta("site", site)
	root.set_meta("shelters", data.get("shelters", []))
	root.set_meta("camp_spot", data.get("camp_spot", Vector3.ZERO))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.v
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_COLOR] = data.c
	arrays[Mesh.ARRAY_TEX_UV] = data.m
	# A delve's inside (§CJ) goes into a mesh of its own, lit per pixel.
	var d0 := int(data.get("delve_from", -1))
	var d1 := int(data.get("delve_to", -1))
	if d0 >= 0 and d1 > d0:
		var sub := []
		sub.resize(Mesh.ARRAY_MAX)
		sub[Mesh.ARRAY_VERTEX] = (data.v as PackedVector3Array).slice(d0, d1)
		sub[Mesh.ARRAY_NORMAL] = (data.n as PackedVector3Array).slice(d0, d1)
		sub[Mesh.ARRAY_COLOR] = (data.c as PackedColorArray).slice(d0, d1)
		sub[Mesh.ARRAY_TEX_UV] = (data.m as PackedVector2Array).slice(d0, d1)
		_flip_winding(sub)
		var dm := ArrayMesh.new()
		dm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub)
		var dmi := MeshInstance3D.new()
		dmi.name = "Delve"
		dmi.mesh = dm
		dmi.material_override = material_lit()
		dmi.visibility_range_end = float(data.get("lod_m", LOD_M))
		dmi.visibility_range_end_margin = LOD_MARGIN_M
		root.add_child(dmi)
		var v2 := (data.v as PackedVector3Array).slice(0, d0)
		v2.append_array((data.v as PackedVector3Array).slice(d1))
		var n2 := (data.n as PackedVector3Array).slice(0, d0)
		n2.append_array((data.n as PackedVector3Array).slice(d1))
		var c2 := (data.c as PackedColorArray).slice(0, d0)
		c2.append_array((data.c as PackedColorArray).slice(d1))
		var m2 := (data.m as PackedVector2Array).slice(0, d0)
		m2.append_array((data.m as PackedVector2Array).slice(d1))
		arrays[Mesh.ARRAY_VERTEX] = v2
		arrays[Mesh.ARRAY_NORMAL] = n2
		arrays[Mesh.ARRAY_COLOR] = c2
		arrays[Mesh.ARRAY_TEX_UV] = m2
	# (A nest with nothing to build, a waterfall or a bay, has no mesh.)
	if not (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material_lit() if bool(data.get("lit_per_pixel", false)) else material()
		mi.visibility_range_end = float(data.get("lod_m", LOD_M))
		mi.visibility_range_end_margin = LOD_MARGIN_M
		root.add_child(mi)
	if not (data.lv as PackedVector3Array).is_empty():
		arrays[Mesh.ARRAY_VERTEX] = data.lv
		arrays[Mesh.ARRAY_NORMAL] = data.ln
		arrays[Mesh.ARRAY_COLOR] = data.lc
		arrays[Mesh.ARRAY_TEX_UV] = data.lm
		var far_mesh := ArrayMesh.new()
		far_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var far := MeshInstance3D.new()
		far.name = "FarLOD"
		far.mesh = far_mesh
		far.material_override = material()
		far.visibility_range_begin = float(data.get("lod_m", LOD_M))
		far.visibility_range_begin_margin = LOD_MARGIN_M
		root.add_child(far)
	for l in data.get("lights", []):
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.omni_range = l[2]
		o.light_energy = l[3]
		o.omni_attenuation = 1.4
		o.distance_fade_enabled = true
		o.distance_fade_begin = 50.0
		o.distance_fade_length = 20.0
		root.add_child(o)
	# The lamps: a flame and a light each, dark until the hearth burns.
	var lamps: Array = []
	for l in data.get("lamps", []):
		var o := OmniLight3D.new()
		o.name = "TombLamp"
		o.position = (l[0] as Vector3) + Vector3(0.0, 0.35, 0.0)
		o.light_color = LAMP
		o.omni_range = l[1]
		o.light_energy = 0.0
		o.omni_attenuation = 1.4
		o.visible = false
		o.distance_fade_enabled = true
		o.distance_fade_begin = 50.0
		o.distance_fade_length = 20.0
		root.add_child(o)
		var flame := Torch.flame_node(0.14)
		flame.position = l[0]
		flame.visible = false
		root.add_child(flame)
		lamps.append([o, flame, float(l[2])])
	if not lamps.is_empty():
		root.set_meta("lamps", lamps)
		root.set_meta("lamps_on", 0.0)
	# Root-trees standing on the stone (§DR.2): one hero tree each.
	for rtr in data.get("root_trees", []):
		var rsp: PlantSpecies = SpeciesDB.all()[int(rtr[1])]
		var rh := float(rtr[2])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = PlantMeshes.mesh_for(rsp, PlantMeshes.LOD_HERO, 0)
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, float(hash(rtr[0]) % 628) / 100.0).scaled(Vector3(rh, rh, rh)), rtr[0]))
		mm.set_instance_color(0, Color(1, 1, 1, 1))
		mm.set_instance_custom_data(0, Color(0.2, 0.0, 0.0, 0.0))
		var rmi := MultiMeshInstance3D.new()
		rmi.name = "RootTree"
		rmi.multimesh = mm
		rmi.material_override = PlantMeshes.material_for(rsp)
		root.add_child(rmi)
	# Running water on it (§DT: the channel down the gardens' terraces):
	# the place's fresh water (WaterLook), and its falls.
	var wd: Dictionary = data.get("water", {})
	if not (wd.get("v", PackedVector3Array()) as PackedVector3Array).is_empty():
		TerrainChunk.materials()
		var wn := PackedVector3Array()
		wn.resize((wd.v as PackedVector3Array).size())
		wn.fill(Vector3.UP)
		var warr := []
		warr.resize(Mesh.ARRAY_MAX)
		warr[Mesh.ARRAY_VERTEX] = wd.v
		warr[Mesh.ARRAY_NORMAL] = wn
		warr[Mesh.ARRAY_TEX_UV] = wd.uv
		warr[Mesh.ARRAY_TEX_UV2] = wd.uv2
		var wmesh := ArrayMesh.new()
		wmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, warr)
		var wmi := MeshInstance3D.new()
		wmi.name = "Water"
		wmi.mesh = wmesh
		wmi.material_override = WaterLook.material(FireStore.biome_key(world, (data.site as Dictionary).dir), false)
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wmi)
	var fd: Dictionary = data.get("falls", {})
	if not (fd.get("v", PackedVector3Array()) as PackedVector3Array).is_empty():
		TerrainChunk.materials()
		var farr := []
		farr.resize(Mesh.ARRAY_MAX)
		farr[Mesh.ARRAY_VERTEX] = fd.v
		farr[Mesh.ARRAY_NORMAL] = fd.n
		farr[Mesh.ARRAY_TEX_UV] = fd.uv
		farr[Mesh.ARRAY_TEX_UV2] = fd.uv2
		var fmesh := ArrayMesh.new()
		fmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, farr)
		var fmi := MeshInstance3D.new()
		fmi.name = "Falls"
		fmi.mesh = fmesh
		fmi.material_override = TerrainChunk._fall_mat
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fmi)
	# A garden gone wild on it (§DT): one multimesh a species.
	var by_sp := {}
	for gt in data.get("garden", []):
		if not by_sp.has(int(gt[1])):
			by_sp[int(gt[1])] = []
		(by_sp[int(gt[1])] as Array).append(gt)
	for spi in by_sp:
		var gsp: PlantSpecies = SpeciesDB.all()[int(spi)]
		var list: Array = by_sp[spi]
		var gmm := MultiMesh.new()
		gmm.transform_format = MultiMesh.TRANSFORM_3D
		gmm.use_custom_data = true
		gmm.use_colors = true
		gmm.mesh = PlantMeshes.mesh_for(gsp, PlantMeshes.LOD_NEAR, 0)
		gmm.instance_count = list.size()
		for gi in list.size():
			var gt: Array = list[gi]
			var gh := float(gt[2])
			gmm.set_instance_transform(gi, Transform3D(Basis(Vector3.UP, float(hash(gt[0]) % 628) / 100.0).scaled(Vector3(gh, gh, gh)), gt[0]))
			gmm.set_instance_color(gi, Color(1, 1, 1, 1))
			gmm.set_instance_custom_data(gi, Color(0.2, 0.0, 0.0, 0.0))
		var gmi := MultiMeshInstance3D.new()
		gmi.name = "Garden"
		gmi.multimesh = gmm
		gmi.material_override = PlantMeshes.material_for(gsp)
		root.add_child(gmi)
	if not (data.get("delve", {}) as Dictionary).is_empty():
		root.set_meta("delve", data.delve)
		root.set_meta("delve_off", data.get("delve_off", 0.0))
	# Collision comes later, in pieces, once the player is near
	# (build_collision_part): a castle's ~18k faces take a trimesh BVH far
	# too slow to build in one frame, and ruins are built kilometers out.
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = PropCollision.WORLD_LAYER
	root.add_child(body)
	root.set_meta("collision_faces", data.cv)
	root.set_meta("collision_next", 0)
	root.set_meta("collision_hulls", data.get("ch", []))
	root.set_meta("hull_next", 0)
	return root


## Faces per collision piece: ~1.5 ms of BVH each.
const COLLISION_PIECE := 2500
## Convex hulls per collision piece (Godot works each hull out as it's
## made).
const HULL_PIECE := 32


## Does this ruin node still lack some of its collision?
static func wants_collision(node: Node3D) -> bool:
	return int(node.get_meta("collision_next", 0)) < (node.get_meta("collision_faces", PackedVector3Array()) as PackedVector3Array).size() \
		or int(node.get_meta("hull_next", 0)) < (node.get_meta("collision_hulls", []) as Array).size()


## Add the next piece of a ruin node's collision (make_node leaves it out):
## the triangles first, then the hulls.
static func build_collision_part(node: Node3D) -> void:
	var faces: PackedVector3Array = node.get_meta("collision_faces")
	var from: int = node.get_meta("collision_next")
	if from < faces.size():
		var to := mini(from + COLLISION_PIECE * 3, faces.size())
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces.slice(from, to))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		node.get_node("Collision").add_child(cs)
		node.set_meta("collision_next", to)
		if to >= faces.size():
			node.set_meta("collision_faces", PackedVector3Array())
			node.set_meta("collision_next", 0)
		return
	var hulls: Array = node.get_meta("collision_hulls", [])
	var h0: int = node.get_meta("hull_next", 0)
	var h1 := mini(h0 + HULL_PIECE, hulls.size())
	var body: StaticBody3D = node.get_node("Collision")
	for i in range(h0, h1):
		PropCollision.hull(body, hulls[i])
	node.set_meta("hull_next", h1)
	if h1 >= hulls.size():
		node.set_meta("collision_hulls", [])
		node.set_meta("hull_next", 0)


## Where the node goes, in scene space (set it after adding the node to
## the tree: its parent may have been shifted by the floating origin).
static func placement(data: Dictionary, world: Node) -> Transform3D:
	return Transform3D(Basis(data.ex, data.up, data.ez), world.to_scene(data.up, PlanetConst.RADIUS_M + data.base_e))


## Ground height at local (x, z), relative to the ruin's origin.
func ground(x: float, z: float) -> float:
	var d := (up + (ex * x + ez * z) / PlanetConst.RADIUS_M).normalized()
	return map.terrain.elevation(d, true) - base_e


## The higher of the ground and any standing water (marsh pools, lakes)
## at local (x, z), relative to the ruin's origin.
func surface(x: float, z: float) -> float:
	var d := (up + (ex * x + ez * z) / PlanetConst.RADIUS_M).normalized()
	var w := TerrainChunk._standing_water(map, d).x - base_e
	return maxf(map.terrain.elevation(d, true) - base_e, w)


# --- Primitives ----------------------------------------------------------------

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	_v.append_array([a, b, c])
	_n.append_array([nrm, nrm, nrm])
	_c.append_array([col, col, col])
	_add_mat()


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(a, b, c, col)
	_tri(a, c, d, col)


## A quad whose normal points away from `inside` (winding fixed to match).
func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot((a + c) * 0.5 - inside) < 0.0:
		_quad(a, d, c, b, col)
	else:
		_quad(a, b, c, d, col)


## A box. `moss` (0-1) greens the top face fully and the sides partly;
## the same value goes to vertex alpha for the glow. Edges are bevelled
## by `bevel` m, and each chamfer's two sides keep their faces' normals,
## so shading rolls smoothly over the edge like worn stone. Corners are
## jittered by up to `wear` m.
func box(xf: Transform3D, size: Vector3, col: Color, moss: float, bevel := 0.09, wear := 0.05) -> void:
	col = col.darkened(shade)
	# A stone block standing on the ground, outside: the overgrowth's
	# plants may grow at its foot and on its top (§DI, _og_spots).
	if _og_on and mat == STONE_M and not plain and not is_nan(foot_y) and not (_delve_from >= 0 and _delve_to < 0):
		_og_boxes.append([xf, size * 0.5, foot_y])
	if plain:
		# Plain boxes (12 triangles, no bevels): a big build's insides (the
		# crag fortress's climb, §DO) within a castle's budget.
		var pm := clampf(moss * _og_k, 0.0, 1.0) if _og_on else moss
		var pc := col.lerp(MOSS, pm * 0.5)
		pc.a = pm * 0.4
		_tri_box(xf, size, pc)
		if solid:
			_collision_box(xf, size * 0.5)
		_lod_box(xf, size * 0.5, pc, pc, pc.darkened(UNDER))
		return
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.45)
	var ns := PackedVector3Array()
	ns.resize(6)
	for a in 3:
		for sgn in 2:
			var nv := Vector3.ZERO
			nv[a] = 1.0 if sgn == 1 else -1.0
			ns[a * 2 + sgn] = (xf.basis * nv).normalized()
	# Moss (§DI with the overgrowth): the top face fully, the sides partly,
	# the shade side more.
	var top_m := _og_top(moss) if _og_on else moss
	var top := col.lerp(MOSS, top_m)
	top.a = top_m
	var sides := PackedColorArray()
	sides.resize(6)
	var side := Color(0, 0, 0, 0)
	for a: int in [0, 2]:
		for sgn in 2:
			var sm := _og_side(moss, ns[a * 2 + sgn]) if _og_on else moss * 0.4
			var sc := col.lerp(MOSS, sm * 0.75)
			sc.a = sm
			sides[a * 2 + sgn] = sc
			side += sc * 0.25
	var bottom := col.darkened(UNDER)
	bottom.a = 0.0
	var o := xf.origin
	var jit: Array[Vector3] = []
	for i in 8:
		jit.append(Vector3(rng.randf_range(-wear, wear), rng.randf_range(-wear, wear), rng.randf_range(-wear, wear)))
	# Worked out once per box (it's built of many quads that share them):
	# vertex (corner i, face axis a) at vs[i * 3 + a], the corner pulled in
	# by b along the other two axes; the face normal of axis a, side s
	# (0 minus, 1 plus) at ns[a * 2 + s]; the color of (i, a) at cs[...].
	var vs := PackedVector3Array()
	vs.resize(24)
	var cs := PackedColorArray()
	cs.resize(24)
	for i in 8:
		var sg := Vector3(1.0 if i & 1 else -1.0, 1.0 if i & 2 else -1.0, 1.0 if i & 4 else -1.0)
		for a in 3:
			var p := sg * h + jit[i]
			for k in 3:
				if k != a:
					p[k] -= sg[k] * b
			vs[i * 3 + a] = xf * p
			cs[i * 3 + a] = (top if i & 2 else bottom) if a == 1 else sides[a * 2 + ((i >> a) & 1)]
	var lod_k := _contact(vs, cs, ns, o)
	# Faces: each face's 4 corners, in order round it.
	for a in 3:
		var u := (a + 1) % 3
		var w := (a + 2) % 3
		for sgn in 2:
			var i0 := (sgn << a)
			var i1 := (sgn << a) | (1 << u)
			var i2 := (sgn << a) | (1 << u) | (1 << w)
			var i3 := (sgn << a) | (1 << w)
			var n := ns[a * 2 + sgn]
			_quad_i(vs[i0 * 3 + a], vs[i1 * 3 + a], vs[i2 * 3 + a], vs[i3 * 3 + a], n, n, n, n,
				cs[i0 * 3 + a], cs[i1 * 3 + a], cs[i2 * 3 + a], cs[i3 * 3 + a], o)
	# Edge chamfers: between face (a, sa) and face (c, sc), along axis k.
	for a in 3:
		for c in range(a + 1, 3):
			var k := 3 - a - c
			for sa in 2:
				for sc in 2:
					var i0: int = (sa << a) | (sc << c)
					var i1: int = i0 | (1 << k)
					var na := ns[a * 2 + sa]
					var nc := ns[c * 2 + sc]
					_quad_i(vs[i0 * 3 + a], vs[i1 * 3 + a], vs[i1 * 3 + c], vs[i0 * 3 + c], na, na, nc, nc,
						cs[i0 * 3 + a], cs[i1 * 3 + a], cs[i1 * 3 + c], cs[i0 * 3 + c], o)
	# Corner triangles.
	for i in 8:
		_tri_n(vs[i * 3], vs[i * 3 + 1], vs[i * 3 + 2],
			ns[(i & 1)], ns[2 + ((i >> 1) & 1)], ns[4 + ((i >> 2) & 1)],
			cs[i * 3], cs[i * 3 + 1], cs[i * 3 + 2], o)
	if solid:
		_collision_box(xf, h)
	if lod_k > 0.0:
		_lod_box(xf, h, top.darkened(lod_k), side.darkened(lod_k), bottom.darkened(lod_k))
	else:
		_lod_box(xf, h, top, side, bottom)


## The contact shade for one box's corners (vertex (corner i, face axis a)
## at vs[i * 3 + a], its color cs[...], face normals ns[a * 2 + side]),
## darkened in place: the foot (foot_y), faces inside (inside_at), the
## doorway's jambs (jamb) and faces looking down. Returns the foot's
## darkening at the box's middle, for its far-LOD box.
func _contact(vs: PackedVector3Array, cs: PackedColorArray, ns: PackedVector3Array, o: Vector3) -> float:
	var grounded := not is_nan(foot_y) and FOOT > 0.0
	var inward := Vector3.ZERO
	if inside > 0.0 and inside_at != Vector3.INF:
		inward = Vector3(inside_at.x - o.x, 0.0, inside_at.z - o.z).normalized()
	for i in 8:
		for a in 3:
			var sgn := (i >> a) & 1
			var n := ns[a * 2 + sgn]
			var keep := 1.0
			if grounded:
				keep *= 1.0 - FOOT * exp(-maxf(vs[i * 3 + a].y - foot_y, 0.0) / FOOT_M)
			if inward != Vector3.ZERO and n.dot(inward) > 0.6:
				keep *= 1.0 - inside
			if jamb > 0.0 and a == 0:
				keep *= 1.0 - jamb
			if not (a == 1 and sgn == 0):
				keep *= 1.0 - UNDER * smoothstep(0.3, 0.8, -n.y)
			if keep < 1.0:
				cs[i * 3 + a] = cs[i * 3 + a].darkened(1.0 - keep)
	return FOOT * exp(-maxf(o.y - foot_y, 0.0) / FOOT_M) if grounded else 0.0


## _quad_n without the arrays: corners p0..p3 in order round the quad.
func _quad_i(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n0: Vector3, n1: Vector3, n2: Vector3, n3: Vector3,
		c0: Color, c1: Color, c2: Color, c3: Color, inside: Vector3) -> void:
	_tri_n(p0, p1, p2, n0, n1, n2, c0, c1, c2, inside)
	_tri_n(p0, p2, p3, n0, n2, n3, c0, c2, c3, inside)


## A quad (4 corners in order round it) with per-vertex normals and
## colors, wound to face away from `inside`.
func _quad_n(ps: Array[Vector3], ns: Array[Vector3], cs: Array[Color], inside: Vector3) -> void:
	_tri_n(ps[0], ps[1], ps[2], ns[0], ns[1], ns[2], cs[0], cs[1], cs[2], inside)
	_tri_n(ps[0], ps[2], ps[3], ns[0], ns[2], ns[3], cs[0], cs[2], cs[3], inside)


func _tri_n(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color, inside: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - inside) < 0.0:
		_v.append(a)
		_v.append(c)
		_v.append(b)
		_n.append(na)
		_n.append(nc)
		_n.append(nb)
		_c.append(ca)
		_c.append(cc)
		_c.append(cb)
	else:
		_v.append(a)
		_v.append(b)
		_v.append(c)
		_n.append(na)
		_n.append(nb)
		_n.append(nc)
		_c.append(ca)
		_c.append(cb)
		_c.append(cc)
	_add_mat()


func _add_mat() -> void:
	var m := Vector2(mat, lichen if mat == STONE_M else 0.0)
	_m.append(m)
	_m.append(m)
	_m.append(m)


## Smooth shading for everything added since `start`: vertices at the
## same spot share the average of their faces' normals.
func _smooth_from(start: int) -> void:
	var acc := {}
	for t in range(start, _v.size(), 3):
		var fn := (_v[t + 1] - _v[t]).cross(_v[t + 2] - _v[t])
		for k in 3:
			var key := Vector3i(_v[t + k] * 100.0)
			acc[key] = acc.get(key, Vector3.ZERO) + fn
	for i in range(start, _v.size()):
		var sum: Vector3 = acc[Vector3i(_v[i] * 100.0)]
		if sum.length_squared() > 1e-10:
			_n[i] = sum.normalized()


## Collision for the drawn triangles added since `start` (mounds, the
## cased pyramid, the barrow). Godot takes clockwise triangles as facing
## front, the reverse of the drawn winding, and concave collision is one
## sided, so each goes in reversed: solid from outside, as boxes are.
func _collide_since(start: int) -> void:
	for t in range(start, _v.size(), 3):
		_cv.append_array([_v[t], _v[t + 2], _v[t + 1]])


func _collision_box(xf: Transform3D, h: Vector3) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_cv.append_array([p[f[0]], p[f[1]], p[f[2]], p[f[0]], p[f[2]], p[f[3]]])


## One collision triangle, solid on the side away from `inside` (wound
## as _collide_since() explains).
func _ctri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - inside) > 0.0:
		_cv.append_array([a, c, b])
	else:
		_cv.append_array([a, b, c])


## Collision for a thin cover (a tepee panel, a lean-to roof): a slab
## `thick` m deep whose outer face is the drawn polygon `pts` (convex, in
## order round it) and whose inner face lies behind it toward `inside`,
## closed round the edges, so it's solid from either side and you touch
## the cover itself from outside.
func _collision_slab(pts: PackedVector3Array, thick: float, inside: Vector3) -> void:
	var n := pts.size()
	if n < 3:
		return
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= n
	var nrm := Vector3.ZERO
	for i in n:
		nrm += (pts[i] - c).cross(pts[(i + 1) % n] - c)
	nrm = nrm.normalized()
	if nrm.dot(c - inside) < 0.0:
		nrm = -nrm
	var back := PackedVector3Array()
	for p in pts:
		back.append(p - nrm * thick)
	var mid := c - nrm * thick * 0.5
	for i in range(1, n - 1):
		_ctri(pts[0], pts[i], pts[i + 1], mid)
		_ctri(back[0], back[i], back[i + 1], mid)
	for i in n:
		var j := (i + 1) % n
		_ctri(pts[i], pts[j], back[j], mid)
		_ctri(pts[i], back[j], back[i], mid)


## The part of convex polygon `pts` on the side of the plane through `o`
## that normal `n` points to.
static func _clip(pts: PackedVector3Array, o: Vector3, n: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		var dp := (p - o).dot(n)
		var dq := (q - o).dot(n)
		if dp >= 0.0:
			out.append(p)
		if (dp >= 0.0) != (dq >= 0.0):
			out.append(p.lerp(q, dp / (dp - dq)))
	return out


## A far-LOD box: 12 flat-shaded triangles, top/side/bottom colored.
func _lod_box(xf: Transform3D, h: Vector3, top: Color, side: Color, bottom: Color) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	# Faces -z, +z, -y, +y, -x, +x.
	var axes := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for k in 6:
		var f: Array = faces[k]
		var nrm: Vector3 = (xf.basis * axes[k]).normalized()
		var col := top if k == 3 else (bottom if k == 2 else side)
		for t in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector3 = p[f[t[0]]]
			var b: Vector3 = p[f[t[1]]]
			var c: Vector3 = p[f[t[2]]]
			if (b - a).cross(c - a).dot(nrm) < 0.0:
				_lv.append_array([a, c, b])
			else:
				_lv.append_array([a, b, c])
			_ln.append_array([nrm, nrm, nrm])
			_lc.append_array([col, col, col])
			var lm := Vector2(mat, lichen if mat == STONE_M else 0.0)
			_lm.append_array([lm, lm, lm])


## A rough stone: a noise-displaced icosphere (320 triangles, so its
## outline is round, not faceted), smooth shaded, mossy on top. Its
## collision is boulder_hull().
func boulder(center: Vector3, radii: Vector3, basis: Basis, col: Color, moss: float) -> void:
	# A vine species may drape it (§CE, surfaces.boulder): from its top
	# down its side, recorded only (no roll, so the ruin builds the same).
	var top_y := absf(basis.y.y) * radii.y + absf(basis.x.y) * radii.x + absf(basis.z.y) * radii.z
	var drape := Vector3(basis.x.x, 0.0, basis.x.z)
	drape = drape.normalized() if drape.length() > 0.01 else Vector3.RIGHT
	_boulder_anchors.append([center + Vector3(0.0, top_y * 0.9, 0.0) + drape * maxf(radii.x, radii.z) * 0.3, drape, top_y * 1.6])
	var sphere: Array = PlantMeshes.icosphere(2)
	var verts: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var ph := _bump_phase(rng)
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	for u in verts:
		pos.append(center + basis * (u * radii * (1.0 + _bump(u, ph))))
	for f in range(0, faces.size(), 3):
		var fn := (pos[faces[f + 1]] - pos[faces[f]]).cross(pos[faces[f + 2]] - pos[faces[f]])
		for k in 3:
			nrm[faces[f + k]] += fn
	var cols := PackedColorArray()
	for i in verts.size():
		nrm[i] = nrm[i].normalized()
		var m := moss * smoothstep(0.1, 0.7, nrm[i].y)
		if _og_on:
			m = _og_side(m, nrm[i])
		var c := col.lerp(MOSS, m)
		# Contact shade (_contact()): dark at its foot and underneath.
		var keep := 1.0 - UNDER * smoothstep(0.3, 0.8, -nrm[i].y)
		if not is_nan(foot_y):
			keep *= 1.0 - FOOT * exp(-maxf(pos[i].y - foot_y, 0.0) / FOOT_M)
		c = c.darkened(1.0 - keep)
		c.a = m
		cols.append(c)
	for f in range(0, faces.size(), 3):
		var a := faces[f]
		var b2 := faces[f + 1]
		var d := faces[f + 2]
		_tri_n(pos[a], pos[b2], pos[d], nrm[a], nrm[b2], nrm[d], cols[a], cols[b2], cols[d], center)
	if solid:
		_ch.append(boulder_hull(center, radii, basis, ph))
	var bm := _og_top(moss) if _og_on else moss
	var top := col.lerp(MOSS, bm)
	top.a = bm
	var side := col.lerp(MOSS, bm * 0.2)
	side.a = bm * 0.2
	_lod_box(Transform3D(basis, center), radii * 0.85, top, side, col)


## Radius, m, past which a boulder's hull takes every corner of the drawn
## stone: on a big one (a den's stones, a rock shelter's slab) the drawn
## bulges between the 42 coarse corners stand up to 0.4 m proud of their
## hull, enough to put your head into the overhang. Ruin rubble stays under
## it.
const FINE_HULL_M := 0.9


## A boulder's collision: the convex hull of the same bumpy stone sampled
## at the 42 corners of a once-divided icosphere (each of them a corner of
## the drawn stone too), or at all 162 drawn corners past FINE_HULL_M, so
## it's as round as the stone with no corners sticking out, and only
## bridges its shallow dips.
static func boulder_hull(center: Vector3, radii: Vector3, basis: Basis, ph: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var level := 2 if maxf(radii.x, maxf(radii.y, radii.z)) > FINE_HULL_M else 1
	for u in (PlantMeshes.icosphere(level)[0] as PackedVector3Array):
		pts.append(center + basis * (u * radii * (1.0 + _bump(u, ph))))
	return pts


## A boulder's bumps: a share of its radius at unit direction `u`, for
## phases `ph` (_bump_phase()).
static func _bump(u: Vector3, ph: Vector3) -> float:
	return 0.16 * sin(u.x * 2.3 + ph.x) * sin(u.z * 2.9 + ph.y) + 0.08 * sin(u.y * 5.1 + ph.z)


static func _bump_phase(r: RandomNumberGenerator) -> Vector3:
	return Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU)


## A block at a position, its length (size.x) running along `dir`
## (horizontal), with a little crumble. `above` (m above the ground) bakes
## ambient occlusion into the lowest courses.
func block(center: Vector3, dir: Vector3, size: Vector3, moss: float, wobble := 0.04, above := 99.0) -> void:
	var x := dir.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var basis := Basis(x, Vector3.UP, z)
	basis = basis.rotated(Vector3.UP, rng.randf_range(-wobble, wobble)).rotated(x, rng.randf_range(-wobble, wobble) * 0.5)
	var col: Color = palette[rng.randi() % palette.size()]
	col = col.lightened(rng.randf_range(-0.06, 0.06))
	# Its foot's shade per corner (box(), foot_y), from the ground under it.
	var was := foot_y
	if above < 50.0:
		foot_y = center.y - size.y * 0.5 - above
	# Irregular masonry: blocks a little longer or shorter, shallower or
	# lower than the course, and nudged along it, so joints don't line up.
	var sz := size * Vector3(rng.randf_range(0.82, 1.1), rng.randf_range(0.9, 1.0), rng.randf_range(0.92, 1.04))
	var c := center + x * rng.randf_range(-0.12, 0.12) * size.x
	box(Transform3D(basis, c), sz, col, _growth(moss), rng.randf_range(0.06, 0.13), rng.randf_range(0.02, 0.07))
	foot_y = was


## Moss amount for this site: sparse where it's dry, thick where it's wet.
## With the overgrowth (§DI) box() and boulder() scale it by the moss
## column instead, so this is the pattern alone.
func _growth(moss: float) -> float:
	if _og_on:
		return clampf(moss, 0.0, 1.0)
	return clampf(moss * (0.3 + 1.1 * wet), 0.0, 1.0)


## The overgrowth for this site (§DI): the moss scale, the shade side in
## the ruin's frame, the lichen.
func _og_setup() -> void:
	og = Overgrowth.for_site(map, site)
	_og_on = true
	_og_k = float(og.moss) / Overgrowth.PATTERN_MEAN
	var sh: Vector3 = og.shade
	_og_shade = Vector3(sh.dot(ex), 0.0, sh.dot(ez)).normalized()
	_og_ss = float(og.shade_scale)
	lichen = float(og.lichen)


## A top face's moss (alpha) from the pattern value `moss`.
const OG_TOP_K := 1.3


func _og_top(moss: float) -> float:
	return clampf(moss * _og_k * OG_TOP_K, 0.0, 1.0)


## A side face's moss (alpha), facing `n`: thicker on the shade side.
func _og_side(moss: float, n: Vector3) -> float:
	var hn := Vector3(n.x, 0.0, n.z)
	var dot := hn.normalized().dot(_og_shade) if hn.length() > 0.05 else 0.0
	return clampf(moss * _og_k * Overgrowth.side_factor(dot, _og_ss), 0.0, 1.0)


## The plants' spots from the stone boxes (§DI): "feet" [ground point
## beside a block's long face at the foot, its outward normal], "gaps"
## [the exposed top of a low stump], "tops" [the exposed top of a wall,
## over 1 m up]. A top is exposed when no box sits on it; a foot is clear
## when no box stands on the spot.
func _og_spots() -> Dictionary:
	var out := {"feet": [], "gaps": [], "tops": []}
	if _og_boxes.is_empty():
		return out
	# Boxes by 1 m column: their bottoms (y) and their tops.
	var grid := {}
	for k in _og_boxes.size():
		var b: Array = _og_boxes[k]
		var c: Vector3 = (b[0] as Transform3D).origin
		var key := Vector2i(floori(c.x), floori(c.z))
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(k)
	for k in _og_boxes.size():
		var b: Array = _og_boxes[k]
		var xf: Transform3D = b[0]
		var h: Vector3 = b[1]
		var foot := float(b[2])
		var up_n := xf.basis.y.normalized()
		if up_n.y < 0.9:
			continue
		var top := xf.origin + xf.basis.y * h.y
		var bottom_y := xf.origin.y - absf(xf.basis.y.y) * h.y
		# Covered: another box's bottom within 0.35 m above this top, its
		# middle within this one's footprint.
		var covered := false
		var reach := maxf(h.x, h.z)
		for gx in range(floori(top.x - reach) - 1, floori(top.x + reach) + 2):
			for gz in range(floori(top.z - reach) - 1, floori(top.z + reach) + 2):
				for j in grid.get(Vector2i(gx, gz), []):
					if j == k:
						continue
					var o: Array = _og_boxes[j]
					var oxf: Transform3D = o[0]
					var oh: Vector3 = o[1]
					var ob := oxf.origin.y - absf(oxf.basis.y.y) * oh.y
					if ob > top.y - 0.2 and ob < top.y + 0.35 and Vector2(oxf.origin.x - top.x, oxf.origin.z - top.z).length() < reach:
						covered = true
						break
				if covered:
					break
			if covered:
				break
		var above := top.y - foot
		if not covered:
			if above > 1.0:
				(out.tops as Array).append([top])
			elif above > 0.2:
				(out.gaps as Array).append([top])
		# The foot: a block at the ground (its bottom within 0.7 m of it)
		# puts a spot on each side of its long faces.
		if bottom_y - foot < 0.7 and top.y > foot + 0.1 and h.y < 1.5:
			var nz := xf.basis.z.normalized() if h.z < h.x else xf.basis.x.normalized()
			var half := minf(h.z, h.x)
			for sg: float in [-1.0, 1.0]:
				var n := Vector3(nz.x, 0.0, nz.z).normalized() * sg
				var p := Vector3(xf.origin.x, foot, xf.origin.z) + n * (half + 0.35)
				var blocked := false
				for gx in range(floori(p.x) - 1, floori(p.x) + 2):
					for gz in range(floori(p.z) - 1, floori(p.z) + 2):
						for j in grid.get(Vector2i(gx, gz), []):
							var o: Array = _og_boxes[j]
							var oxf: Transform3D = o[0]
							var local := oxf.affine_inverse() * Vector3(p.x, oxf.origin.y, p.z)
							var oh: Vector3 = o[1]
							if absf(local.x) < oh.x + 0.15 and absf(local.z) < oh.z + 0.15:
								blocked = true
				if not blocked:
					(out.feet as Array).append([p, n])
	return out


## Ivy hanging from `top` down a face with outward normal `out`: often
## missing on dry ruins, longer and doubled into curtains on wet ones.
## With the overgrowth (§DI) each call is a hanging place, and the vine
## column is the share of them that hang a strand (by the place's own
## hash); the builder's rolls are drawn as before either way, so the ruin
## itself never changes with it.
func ivy(top: Vector3, out: Vector3, length: float) -> void:
	var place := _ivy_places
	_ivy_places += 1
	var keep := true
	if _og_on:
		# A low-discrepancy draw from the ruin's own offset: about the
		# column's share of the places, spread evenly over the ruin.
		var off := float(hash([int(site.seed), "ivy"]) & 0xFFFF) / 65535.0
		keep = fposmod(off + place * 0.6180339887, 1.0) < float(og.get("vine", 0.0))
	if keep:
		_ivy_kept += 1
	if rng.randf() > 0.3 + 0.7 * wet:
		if keep and _og_on:
			# A place the old roll left bare: its own roll, not the ruin's.
			var own := RandomNumberGenerator.new()
			own.seed = hash([int(site.seed), place, "ivy_own"])
			_ivy_strand(top, out, length * (0.7 + 0.6 * wet), true, own)
		return
	length *= 0.7 + 0.6 * wet
	_ivy_strand(top, out, length, keep)
	var along := Vector3.UP.cross(out).normalized()
	for k in 2:
		if rng.randf() < wet * 0.6:
			_ivy_strand(top + along * rng.randf_range(-1.2, 1.2), out, length * rng.randf_range(0.5, 1.0), keep)


## One strand. Not `draw`n, its rolls are still drawn (from `r`, else the
## ruin's own), so nothing after it moves.
func _ivy_strand(top: Vector3, out: Vector3, length: float, draw := true, r: RandomNumberGenerator = null) -> void:
	var g := r if r != null else rng
	# Where a vine species climbs too (§CE): VineCover hangs its leaf
	# cards from the same tops near the player. Recorded only, so the
	# ruin's own rolls (and its geometry) never change.
	if draw:
		_vine_anchors.append([top, out, length])
	var side := Vector3.UP.cross(out).normalized() * g.randf_range(0.25, 0.45)
	var o := out.normalized() * 0.08
	var steps := maxi(1, int(length / 0.8))
	var prev_l := top + o - side
	var prev_r := top + o + side
	for i in steps:
		var y := -length * float(i + 1) / steps
		var sway := side * g.randf_range(-0.4, 0.4)
		var taper := 1.0 - 0.6 * float(i + 1) / steps
		var l := top + o + Vector3(0, y, 0) - side * taper + sway
		var rr := top + o + Vector3(0, y, 0) + side * taper + sway
		var col := IVY.lerp(IVY_LIGHT, g.randf())
		col.a = 1.0
		if draw:
			_quad(prev_l, prev_r, rr, l, col)
		# A leaf sticking out.
		if g.randf() < 0.6:
			var c := (prev_l + rr) * 0.5 + o
			var s := g.randf_range(0.18, 0.3)
			if draw:
				_tri(c, c + out.normalized() * s + Vector3(0, s, 0), c + side.normalized() * s, col.lightened(0.1))
		prev_l = l
		prev_r = rr


## Fallen blocks strewn around a point.
func rubble(center: Vector3, spread: float, count: int) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		var x := center.x + cos(a) * r
		var z := center.z + sin(a) * r
		var size := Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.2))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		var col: Color = palette[rng.randi() % palette.size()]
		var p := Vector3(x, ground(x, z) + size.y * 0.3, z)
		var was := foot_y
		foot_y = p.y - size.y * 0.3
		if rng.randf() < 0.55:
			# A tumbled block, edges knocked round.
			box(Transform3D(basis, p), size, col, _growth(rng.randf_range(0.3, 0.9)), 0.16, 0.1)
		else:
			boulder(p, size * 0.55, basis, col.darkened(0.05), _growth(rng.randf_range(0.3, 0.9)))
		foot_y = was


# --- Walls and towers ------------------------------------------------------------

## A straight wall of stacked blocks from a to b (local xz), `height` tall.
## Breaches: [[t0, t1], ...] stretches (0-1 along the wall) collapsed to
## stumps. Returns the number of fallen courses (for rubble).
func wall(a: Vector2, b: Vector2, height: float, thick: float, breaches: Array, ivy_chance := 0.3) -> int:
	var along := b - a
	var length := along.length()
	var dir3 := Vector3(along.x, 0, along.y) / length
	var out := Vector3(dir3.z, 0, -dir3.x)
	var cols := maxi(1, int(ceil(length / 1.5)))
	var bw := length / cols
	var fallen := 0
	for i in cols:
		var t := (i + 0.5) / cols
		var p := a + along * t
		var g := ground(p.x, p.y)
		var h := height - rng.randf_range(0.0, 2.2) * COURSE_M
		for br in breaches:
			if t > br[0] and t < br[1]:
				# V-shaped gap: full height at its edges, stumps in the middle.
				var depth := minf(t - br[0], br[1] - t) / maxf(br[1] - br[0], 0.01) * 2.0
				h = minf(h, lerpf(height, rng.randf_range(0.0, 1.2), smoothstep(0.0, 0.6, depth)))
		h = maxf(h, 0.0)
		fallen += int((height - h) / COURSE_M)
		# Footing down into the ground, then courses.
		block(Vector3(p.x, g - 1.2, p.y), dir3, Vector3(bw, 1.6, thick * 1.1), 0.0, 0.0)
		var y := g - 0.4
		var k := 0
		while y + COURSE_M * 0.5 < g + h:
			if y > g + 1.0 and rng.randf() < 0.04:
				y += COURSE_M
				k += 1
				continue
			var moss := 0.15 + 0.5 * exp(-(y - g) / 1.5) + rng.randf_range(0.0, 0.2)
			block(Vector3(p.x, y + COURSE_M * 0.5, p.y), dir3, Vector3(bw * 0.97, COURSE_M * 0.96, thick), moss, 0.04, y - g)
			y += COURSE_M
			k += 1
		if h > 1.0 and rng.randf() < ivy_chance:
			var top := Vector3(p.x, g + h, p.y)
			ivy(top + out * thick * 0.5, out, rng.randf_range(1.2, minf(5.0, h)))
			if rng.randf() < 0.5:
				ivy(top - out * thick * 0.5, -out, rng.randf_range(1.0, minf(4.0, h)))
	return fallen


## A round tower of block rings, `height` tall, with one side slumped.
func round_tower(center: Vector2, radius: float, height: float, door_angle: float) -> void:
	var segs := maxi(8, int(TAU * radius / 1.4))
	var slump_a := rng.randf() * TAU
	var slump := rng.randf_range(0.2, 0.5)
	var fallen := 0
	# Inside the tower is in shade, the doorway's sides too (_contact()).
	inside_at = Vector3(center.x, 0.0, center.y)
	inside = INSIDE
	for i in segs:
		var a := TAU * i / segs
		var p := center + Vector2(cos(a), sin(a)) * radius
		var tangent := Vector3(-sin(a), 0, cos(a))
		var out := Vector3(cos(a), 0, sin(a))
		var g := ground(p.x, p.y)
		var closeness := (cos(a - slump_a) + 1.0) * 0.5
		var h := height * (1.0 - slump * smoothstep(0.4, 1.0, closeness)) - rng.randf_range(0.0, 2.5)
		fallen += int((height - h) / COURSE_M)
		var bw := TAU * radius / segs
		block(Vector3(p.x, g - 1.2, p.y), tangent, Vector3(bw * 1.05, 1.6, 1.5), 0.0, 0.0)
		var y := g - 0.4
		var door := absf(angle_difference(a, door_angle)) < 0.35
		# Beside the doorway: this column's blocks frame it.
		var beside := not door and (absf(angle_difference(a - TAU / segs, door_angle)) < 0.35 or absf(angle_difference(a + TAU / segs, door_angle)) < 0.35)
		var window_row := rng.randi_range(6, 10)
		while y + COURSE_M * 0.5 < g + h:
			var course := int((y - g) / COURSE_M)
			var gap := (door and y < g + 2.4) or (course % window_row == 0 and course > 3 and rng.randf() < 0.35)
			if not gap:
				var moss := 0.12 + 0.5 * exp(-(y - g) / 1.5) + rng.randf_range(0.0, 0.2)
				jamb = JAMB if beside and y < g + 2.4 else 0.0
				block(Vector3(p.x, y + COURSE_M * 0.5, p.y), tangent, Vector3(bw * 1.02, COURSE_M * 0.96, 1.3), moss, 0.04, y - g)
			y += COURSE_M
		jamb = 0.0
		if h > 2.0 and rng.randf() < 0.35:
			ivy(Vector3(p.x, g + h, p.y) + out * 0.65, out, rng.randf_range(2.0, minf(7.0, h)))
	inside = 0.0
	inside_at = Vector3.INF
	rubble(Vector3(center.x + cos(slump_a) * (radius + 2.0), 0, center.y + sin(slump_a) * (radius + 2.0)), 3.5, mini(fallen / 6, 16))


## A buried earth mound (motte) under a structure: keeps it from floating
## over the coarse far terrain and gives castles their raised hilltop.
func mound(radius_top: float, radius_bottom: float, depth: float, rise: float) -> void:
	var sides := 12
	var top_pts: Array = []
	var bot_pts: Array = []
	for i in sides:
		var a := TAU * i / sides + rng.randf_range(-0.08, 0.08)
		var rt := radius_top * rng.randf_range(0.92, 1.05)
		top_pts.append(Vector3(cos(a) * rt, rise + rng.randf_range(-0.3, 0.2), sin(a) * rt))
		bot_pts.append(Vector3(cos(a) * radius_bottom, -depth, sin(a) * radius_bottom))
	# Match the local ground so the motte reads as part of the hill.
	var grass := TerrainChunk._biome_blend(map, up).lerp(GRASS, 0.15)
	grass.a = 0.05 # hardly any glowing moss on the grassy motte
	var earth := grass.darkened(0.3).lerp(EARTH, 0.4)
	earth.a = 0.0
	var c := Vector3(0, rise, 0)
	var inside := Vector3(0, -depth * 0.5, 0)
	var start := _v.size()
	for i in sides:
		var j := (i + 1) % sides
		_face(c, top_pts[j], top_pts[i], top_pts[i], grass, inside)
		_face(top_pts[i], top_pts[j], bot_pts[j], bot_pts[i], earth.lerp(grass, 0.25), inside)
	_smooth_from(start)
	_collide_since(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))


# --- Structures -------------------------------------------------------------------

func _castle() -> void:
	if str(site.get("style", "")) == "tower_house":
		_tower_house()
		return
	mound(24.0, 36.0, 32.0, 0.35)
	# Curtain wall: an octagon with two breaches and a gate gap.
	var r := 17.0
	var pts: Array = []
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	var breach_sides := [rng.randi() % 8, rng.randi() % 8]
	var gate := rng.randi() % 8
	var fallen := 0
	for i in 8:
		var breaches: Array = []
		if i in breach_sides:
			var s := rng.randf_range(0.15, 0.55)
			breaches.append([s, s + rng.randf_range(0.25, 0.4)])
		if i == gate:
			breaches.append([0.4, 0.6])
		fallen += wall(pts[i], pts[(i + 1) % 8], rng.randf_range(6.0, 7.5), 1.6, breaches)
		if i in breach_sides:
			var mid: Vector2 = (pts[i] + pts[(i + 1) % 8]) * 0.5
			rubble(Vector3(mid.x * 1.12, 0, mid.y * 1.12), 4.0, 12)
	# Corner towers on alternate corners.
	for i in range(0, 8, 2):
		round_tower(pts[i], 2.8, rng.randf_range(8.5, 11.5), rng.randf() * TAU)
	# The keep: a tall square tower, one corner fallen in.
	var k := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
	var hs := 4.5
	var keep_h := rng.randf_range(15.0, 19.0)
	var corners := [k + Vector2(-hs, -hs), k + Vector2(hs, -hs), k + Vector2(hs, hs), k + Vector2(-hs, hs)]
	var broken := rng.randi() % 4
	# The keep's inside is in shade (_contact()).
	inside_at = Vector3(k.x, 0.0, k.y)
	inside = INSIDE
	for i in 4:
		var br: Array = []
		if i == broken:
			br = [[0.55, 1.05]]
		elif i == (broken + 3) % 4:
			br = [[-0.05, 0.35]]
		wall(corners[i], corners[(i + 1) % 4], keep_h, 1.3, br, 0.45)
	inside = 0.0
	inside_at = Vector3.INF
	var fall_corner: Vector2 = corners[(broken + 1) % 4]
	rubble(Vector3(fall_corner.x * 1.3, 0, fall_corner.y * 1.3), 5.0, 22)
	rubble(Vector3.ZERO, 14.0, mini(fallen / 4, 30))


func _lone_tower() -> void:
	if str(site.get("style", "")) == "broch":
		_broch()
		return
	mound(6.0, 10.0, 14.0, 0.0)
	_tower_r = rng.randf_range(3.2, 4.2)
	round_tower(Vector2.ZERO, _tower_r, rng.randf_range(14.0, 22.0), rng.randf() * TAU)
	# A stump of an old wall running off from it.
	var a := rng.randf() * TAU
	_stub_angle = a
	var end := Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 16.0)
	wall(Vector2(cos(a), sin(a)) * 3.8, end, rng.randf_range(2.0, 4.0), 1.2, [[0.5, 1.1]], 0.4)


## Arches striding level across the ground on piers; some spans fallen.
func _aqueduct() -> void:
	var length: float = site.length_m
	var spacing := 7.5
	var piers := int(length / spacing) + 1
	var x0 := -spacing * (piers - 1) * 0.5
	var top := -INF
	for i in piers:
		top = maxf(top, ground(x0 + i * spacing, 0.0))
	top += rng.randf_range(9.0, 12.0)
	var spring := top - 3.6
	var fallen_span := []
	for i in piers - 1:
		fallen_span.append(rng.randf() < 0.22 or i == 0 and rng.randf() < 0.5 or i == piers - 2 and rng.randf() < 0.5)
	var along := Vector3(1, 0, 0)
	for i in piers:
		var x := x0 + i * spacing
		var g := ground(x, 0.0)
		# Deep footing (hidden underground next to the chunks; keeps the
		# silhouette grounded against the coarser far terrain).
		box(Transform3D(Basis.IDENTITY, Vector3(x, g - 18.0, 0)), Vector3(2.0, 34.0, 2.4), STONES[1], 0.0)
		var both_fallen: bool = (i == 0 or fallen_span[i - 1]) and (i == piers - 1 or fallen_span[mini(i, piers - 2)])
		var h := spring - g + 0.4
		if both_fallen:
			h *= rng.randf_range(0.2, 0.7)
		var y := g - 0.4
		while y < g + h:
			var moss := 0.1 + 0.5 * exp(-(y - g) / 2.0) + rng.randf_range(0.0, 0.25)
			block(Vector3(x, y + COURSE_M * 0.5, 0), along, Vector3(1.8, COURSE_M * 0.96, 2.2), moss, 0.03, y - g)
			y += COURSE_M
		if both_fallen:
			rubble(Vector3(x + rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), 3.0, 8)
	# Arches, spandrels and the channel on top.
	for i in piers - 1:
		var xa := x0 + i * spacing + 0.9
		var xb := x0 + (i + 1) * spacing - 0.9
		if fallen_span[i]:
			# Broken arch stubs on both sides.
			for s in [0, 1]:
				var xs: float = xa if s == 0 else xb
				var dirx := 1.0 if s == 0 else -1.0
				for k in rng.randi_range(1, 2):
					var ang := PI * 0.5 * (k + 0.5) / 4.0
					var rr := (xb - xa) * 0.5
					var cx := xs + dirx * (rr - cos(ang) * rr)
					block(Vector3(cx, spring + sin(ang) * rr, 0), along, Vector3(0.9, 0.7, 2.1), 0.5)
			continue
		var cx := (xa + xb) * 0.5
		var rr := (xb - xa) * 0.5
		var stones := 9
		for k in stones:
			var ang := PI * (k + 0.5) / stones
			var p := Vector3(cx - cos(ang) * rr, spring + sin(ang) * rr, 0)
			var tangent := Vector3(sin(ang), cos(ang), 0)
			var basis := Basis(tangent, tangent.cross(Vector3(0, 0, 1)).normalized() * -1.0, Vector3(0, 0, 1)).orthonormalized()
			var col: Color = STONES[rng.randi() % STONES.size()]
			box(Transform3D(basis, p), Vector3(rr * PI / stones * 1.05, 0.7, 2.1), col, 0.35)
		# Spandrel courses from the arch crown up to the deck.
		var y := spring + rr * 0.55
		while y < top - 0.5:
			for part in [xa + (xb - xa) * 0.18, xb - (xb - xa) * 0.18, cx]:
				if part == cx and y < spring + rr + 0.2:
					continue
				block(Vector3(part, y + COURSE_M * 0.5, 0), along, Vector3((xb - xa) * 0.36, COURSE_M * 0.96, 2.2), 0.3)
			y += COURSE_M
		# Channel: floor and two low side walls, mossy and ivy-draped.
		block(Vector3(cx, top, 0), along, Vector3(spacing, 0.5, 2.4), 0.8, 0.02)
		for sz in [-1.0, 1.0]:
			if rng.randf() < 0.85:
				block(Vector3(cx, top + 0.55, sz * 1.0), along, Vector3(spacing * rng.randf_range(0.6, 1.0), 0.6, 0.4), 0.9, 0.05)
			if rng.randf() < 0.55:
				ivy(Vector3(cx + rng.randf_range(-2.5, 2.5), top + 0.2, sz * 1.25), Vector3(0, 0, sz), rng.randf_range(2.0, 6.0))


# --- Camps ----------------------------------------------------------------------

## Where a living camp would sit in a stone ruin without a survivors'
## camp: in a castle's courtyard, at a tower's foot away from its wall
## stub, under one of an aqueduct's arches.
func _stone_camp_spot() -> void:
	var p := Vector2.ZERO
	var floor_y := 0.0
	match site.kind:
		Ruins.Kind.CASTLE:
			var a := rng.randf() * TAU
			p = Vector2(cos(a), sin(a)) * 10.5
			# (A tower house stands on the ground, no motte: §DS.)
			floor_y = 0.0 if _northern() else 0.35
		Ruins.Kind.TOWER:
			var a := _stub_angle + PI + rng.randf_range(-0.8, 0.8)
			p = Vector2(cos(a), sin(a)) * (_tower_r + 4.5)
			# The broch's hearth: the middle of its court, under the open
			# roof (§DS).
			if _northern():
				p = Vector2.ZERO
		Ruins.Kind.AQUEDUCT:
			var length: float = site.length_m
			var spacing := 7.5
			var piers := int(length / spacing) + 1
			var x0 := -spacing * (piers - 1) * 0.5
			p = Vector2(x0 + (rng.randi() % (piers - 1) + 0.5) * spacing, 0.0)
	_camp_spot = Vector3(p.x, maxf(ground(p.x, p.y), floor_y), p.y)


## Survivors' camp in the ruin: one to three shelters (tepees or lean-tos)
## in a castle's courtyard, at a tower's foot (away from its wall stub) or
## under an aqueduct's arches, and a cold fire ring.
func _camp(kind: int) -> void:
	var spots: Array[Vector2] = []
	var count := rng.randi_range(1, 3)
	match kind:
		Ruins.Kind.CASTLE:
			var a0 := rng.randf() * TAU
			for i in count:
				var a := a0 + i * rng.randf_range(0.7, 1.1)
				spots.append(Vector2(cos(a), sin(a)) * rng.randf_range(11.5, 12.5))
		Ruins.Kind.TOWER:
			count = mini(count, 2)
			for i in count:
				var a := _stub_angle + PI + (i - 0.5 * (count - 1)) * 0.9
				spots.append(Vector2(cos(a), sin(a)) * (_tower_r + 3.6))
		Ruins.Kind.AQUEDUCT:
			var length: float = site.length_m
			var spacing := 7.5
			var piers := int(length / spacing) + 1
			var x0 := -spacing * (piers - 1) * 0.5
			for i in mini(count, piers - 1):
				var span := rng.randi() % (piers - 1)
				spots.append(Vector2(x0 + (span + 0.5) * spacing, rng.randf_range(-1.0, 1.0)))
	var floor_y := 0.35 if kind == Ruins.Kind.CASTLE and not _northern() else 0.0
	for i in spots.size():
		var p := spots[i]
		if kind == Ruins.Kind.AQUEDUCT or rng.randf() < 0.65:
			tepee(p, rng.randf_range(1.4, 1.8), rng.randf_range(2.8, 3.5), floor_y)
		else:
			lean_to(p, rng.randf() * TAU, floor_y)
	# The cold fire ring beside the first shelter: along the courtyard or
	# round the tower (clear of keep and walls), across the aqueduct's line
	# (clear of the piers).
	var s0 := spots[0]
	var beside := Vector2(0.0, 2.8 * (1.0 if s0.y <= 0.0 else -1.0)) if kind == Ruins.Kind.AQUEDUCT else Vector2(-s0.y, s0.x).normalized() * 3.0
	var fire := s0 + beside
	_camp_spot = Vector3(fire.x, maxf(ground(fire.x, fire.y), floor_y), fire.y)
	# An inhabited ruin gets a burning fire there (Camps); otherwise an
	# old hearth, a ring of stones round cold ash you can rekindle
	# (OldHearths builds it at the camp spot).


## Half the width a tepee's collision leaves open at its door, m: the
## player's capsule (0.35 m) and a little room. The drawn doorway narrows
## toward the top, so without this a standing player's shoulders would
## catch on it in the smaller tepees; the body is slimmer than the
## capsule, so it still doesn't pass through the cover.
const DOOR_HALF_M := 0.45
## Thickness of the collision behind thin covers (tepee panels, a lean-to
## roof), m.
const COVER_M := 0.06


## A tepee: poles leaning in to a crossing at the top, covered in woven
## vines and hide panels, with a door gap. Collision follows it: the poles
## (bar the two framing the door) and a thin shell behind each panel, so
## you can walk in at the door and stand inside.
func tepee(center: Vector2, r: float, h: float, floor_y := 0.0) -> void:
	var g := maxf(ground(center.x, center.y), floor_y)
	var apex := Vector3(center.x, g + h, center.y)
	var poles := 7
	var a0 := rng.randf() * TAU
	var feet: Array[Vector3] = []
	var tips: Array[Vector3] = []
	# The poles' collision goes in once the door is known (below).
	solid = false
	for i in poles:
		var a := a0 + TAU * i / poles + rng.randf_range(-0.08, 0.08)
		var foot := Vector3(center.x + cos(a) * r, 0.0, center.y + sin(a) * r)
		foot.y = maxf(ground(foot.x, foot.z), floor_y) - 0.1
		feet.append(foot)
		var along := (apex - foot).normalized()
		tips.append(apex + along * rng.randf_range(0.35, 0.6))
		_pole(foot, tips[i], 0.09)
	solid = true
	# Cover: panels between neighboring poles up to near the top; one gap
	# is the door.
	var inside := Vector3(center.x, g + h * 0.4, center.y)
	var start := _v.size()
	var door := rng.randi() % poles
	for i in poles:
		if i == door:
			continue
		var a := feet[i]
		var b := feet[(i + 1) % poles]
		var ta := a.lerp(apex, 0.86)
		var tb := b.lerp(apex, 0.86)
		var vine := rng.randf() < 0.6
		var col := IVY.lerp(IVY_LIGHT, rng.randf()) if vine else HIDE.lightened(rng.randf_range(-0.08, 0.08))
		col.a = 0.75 if vine else 0.1
		mat = LEAF_M if vine else HIDE_M
		_face(a, b, tb, ta, col, inside)
	mat = STONE_M
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	# Collision. The door's poles are left out, and the panels either side
	# are trimmed back to DOOR_HALF_M from the door's middle line (only
	# where the drawn doorway is narrower than that, near head height).
	var door_mid := (feet[door] + feet[(door + 1) % poles]) * 0.5
	var out := Vector3(door_mid.x - center.x, 0.0, door_mid.z - center.y).normalized()
	var across := Vector3.UP.cross(out)
	var c3 := Vector3(center.x, g, center.y)
	for i in poles:
		if i != door and i != (door + 1) % poles:
			_pole_collision(feet[i], tips[i], 0.09)
		if i == door:
			continue
		var a := feet[i]
		var b := feet[(i + 1) % poles]
		var panel := PackedVector3Array([a, b, b.lerp(apex, 0.86), a.lerp(apex, 0.86)])
		if i == (door + poles - 1) % poles or i == (door + 1) % poles:
			var s := signf((a + b - c3 * 2.0).dot(across))
			panel = _clip(panel, c3 + across * s * DOOR_HALF_M, across * s)
		_collision_slab(panel, COVER_M, inside)
	_shelters.append([Vector3(center.x, g, center.y), r, h])


## A lean-to: two forked uprights and a ridge pole, a roof of vine thatch
## sloping down to the ground behind. Collision: the poles, and a thin
## slab under the roof, so you can shelter beneath it (or climb it).
func lean_to(center: Vector2, heading: float, floor_y := 0.0) -> void:
	var fwd := Vector3(cos(heading), 0.0, sin(heading))
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var w := rng.randf_range(2.4, 3.2)
	var hh := rng.randf_range(1.7, 2.1)
	var depth := rng.randf_range(2.0, 2.6)
	var c := Vector3(center.x, 0.0, center.y)
	var tops: Array[Vector3] = []
	for s: float in [-0.5, 0.5]:
		var foot: Vector3 = c + side * w * s
		foot.y = maxf(ground(foot.x, foot.z), floor_y) - 0.1
		var top: Vector3 = foot + Vector3(0, hh + 0.1, 0)
		_pole(foot, top + Vector3(0, 0.25, 0), 0.1)
		tops.append(top)
	_pole(tops[0] - side * 0.3, tops[1] + side * 0.3, 0.08)
	var backs: Array[Vector3] = []
	for t in tops:
		var back := t - fwd * depth
		back.y = maxf(ground(back.x, back.z), floor_y) - 0.05
		backs.append(back)
		_pole(t, back, 0.07)
	var start := _v.size()
	var col := IVY.lerp(IVY_LIGHT, rng.randf())
	col.a = 0.75
	mat = LEAF_M
	var under := c + Vector3(0, -3.0, 0) - fwd * depth * 0.5
	_face(tops[0], tops[1], backs[1], backs[0], col, under)
	mat = STONE_M
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	_collision_slab(PackedVector3Array([tops[0], tops[1], backs[1], backs[0]]), COVER_M, under)
	var floor_c := c - fwd * depth * 0.5
	floor_c.y = maxf(ground(floor_c.x, floor_c.z), floor_y)
	_shelters.append([floor_c, maxf(w, depth) * 0.5, hh])


## A straight pole (a thin, barely bevelled wooden block).
func _pole(a: Vector3, b: Vector3, thick: float) -> void:
	var basis := _along(b - a)
	var col := WOOD.lightened(rng.randf_range(-0.08, 0.08))
	var was := mat
	mat = WOOD_M
	box(Transform3D(basis, (a + b) * 0.5), Vector3(thick, a.distance_to(b), thick), col, 0.1, 0.02, 0.01)
	mat = was


## The collision _pole() adds, on its own (for poles drawn with `solid`
## off).
func _pole_collision(a: Vector3, b: Vector3, thick: float) -> void:
	_collision_box(Transform3D(_along(b - a), (a + b) * 0.5), Vector3(thick, a.distance_to(b), thick) * 0.5)


## A basis whose Y runs along `axis`.
static func _along(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## A ring of stones around old ash.
func fire_ring(center: Vector2, floor_y := 0.0) -> void:
	var g := maxf(ground(center.x, center.y), floor_y)
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf_range(-0.15, 0.15)
		var p := Vector3(center.x + cos(a) * 0.55, g + 0.08, center.y + sin(a) * 0.55)
		boulder(p, Vector3(0.16, 0.11, 0.14), Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)), STONES[rng.randi() % STONES.size()], 0.1)
	var ash := Color(0.16, 0.15, 0.14)
	ash.a = 0.0
	box(Transform3D(Basis.IDENTITY, Vector3(center.x, g + 0.01, center.y)), Vector3(0.8, 0.04, 0.8), ash, 0.0, 0.01, 0.0)


# --- Snow country: igloos ---------------------------------------------------------

## One to three igloos, some fallen in, a windbreak of snow blocks and a
## drying rack of poles and hides.
func _igloos() -> void:
	var spots: Array[Vector2] = [Vector2.ZERO]
	for i in rng.randi_range(0, 2):
		var a := rng.randf() * TAU
		spots.append(Vector2(cos(a), sin(a)) * rng.randf_range(6.5, 8.0))
	var doors: Array[float] = []
	for p in spots:
		doors.append(rng.randf() * TAU)
		igloo(p, rng.randf_range(2.1, 2.7), doors[-1], rng.randf() < 0.45)
	# The camp fire: 4.8 m out from the middle igloo, as far as can be from
	# the others and clear of its entrance tunnel.
	var best_a := 0.0
	var best_clear := -INF
	for k in 12:
		var a := TAU * k / 12.0
		if absf(angle_difference(a, doors[0])) < 0.6:
			continue
		var q := Vector2(cos(a), sin(a)) * 4.8
		var clear := INF
		for p in spots.slice(1):
			clear = minf(clear, q.distance_to(p))
		if clear > best_clear:
			best_clear = clear
			best_a = a
	var fire := Vector2(cos(best_a), sin(best_a)) * 4.8
	_camp_spot = Vector3(fire.x, ground(fire.x, fire.y), fire.y)
	# Windbreak: a low curved wall on one side.
	var wa := rng.randf() * TAU
	mat = SNOW_M
	for k in 9:
		var a := wa + (k - 4) * 0.15
		var p := Vector2(cos(a), sin(a)) * 10.0
		var g := ground(p.x, p.y)
		var tangent := Vector3(-sin(a), 0, cos(a))
		for j in rng.randi_range(1, 3):
			var basis := Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP)).rotated(Vector3.UP, rng.randf_range(-0.08, 0.08))
			box(Transform3D(basis, Vector3(p.x, g + 0.2 + j * 0.42, p.y)), Vector3(1.4, 0.42, 0.5), SNOW.darkened(rng.randf_range(0.0, 0.08)), 0.0, 0.05, 0.04)
	mat = STONE_M
	# Drying rack: two posts and a bar, hides hung over it.
	var ra := best_a + PI * 0.5 + rng.randf_range(-0.3, 0.3)
	var rc := Vector2(cos(ra), sin(ra)) * 7.5
	var side := Vector2(-sin(ra), cos(ra))
	var ends: Array[Vector3] = []
	for s in [-1.0, 1.0]:
		var q: Vector2 = rc + side * 1.1 * s
		var g := ground(q.x, q.y)
		_pole(Vector3(q.x, g - 0.3, q.y), Vector3(q.x, g + 1.7, q.y), 0.1)
		ends.append(Vector3(q.x, g + 1.6, q.y))
	_pole(ends[0], ends[1], 0.07)
	mat = HIDE_M
	for k in 2:
		var t := 0.3 + 0.4 * k
		var top := ends[0].lerp(ends[1], t)
		var col := HIDE.lightened(rng.randf_range(-0.1, 0.1))
		col.a = 0.0
		var w := Vector3(side.x, 0, side.y) * 0.35
		var drop := Vector3(0, -rng.randf_range(0.9, 1.3), 0)
		var fwd := Vector3(cos(ra), 0, sin(ra)) * 0.12
		_face(top - w, top + w, top + w + drop + fwd, top - w + drop + fwd, col, top - fwd * 4.0)
		_face(top - w, top + w, top + w + drop - fwd, top - w + drop - fwd, col, top + fwd * 4.0)
	mat = STONE_M


## A dome of snow-block rings leaning in, with a door and an entrance
## tunnel (crouch height). `fallen`: the cap has caved in.
func igloo(center: Vector2, r: float, door_a: float, fallen: bool) -> void:
	mat = SNOW_M
	var g := ground(center.x, center.y) - 0.15
	var c3 := Vector3(center.x, g, center.y)
	# The dome and tunnel darken at their foot (_contact()); the dome's
	# inside is its blocks' undersides.
	foot_y = g + 0.15
	var rings := 6
	var arc := r * PI * 0.5 / rings
	var cap_a := rng.randf() * TAU
	var tumbled := 0
	for k in rings:
		var phi := (k + 0.5) * PI * 0.5 / (rings + 0.3)
		var rr := r * cos(phi)
		var y := r * sin(phi)
		var n := maxi(4, int(TAU * rr / 0.75))
		var off := rng.randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			if absf(angle_difference(a, door_a)) < 0.42 and y < 1.35:
				continue
			if fallen and k >= rings - 3 and absf(angle_difference(a, cap_a)) < 1.0 + 0.35 * (k - rings + 3):
				tumbled += 1
				continue
			var out := Vector3(cos(a), 0, sin(a))
			var tangent := Vector3(-sin(a), 0, cos(a))
			var normal := (out * cos(phi) + Vector3.UP * sin(phi)).normalized()
			var basis := Basis(tangent, normal, tangent.cross(normal)).orthonormalized()
			var col := SNOW.darkened(rng.randf_range(0.0, 0.07))
			col.a = 0.0
			box(Transform3D(basis, c3 + out * rr + Vector3(0, y, 0)), Vector3(TAU * rr / n * 0.96, 0.38, arc * 0.95), col, 0.0, 0.05, 0.03)
	if not fallen:
		box(Transform3D(Basis.IDENTITY, c3 + Vector3(0, r * 0.98, 0)), Vector3(0.9, 0.3, 0.9), SNOW, 0.0, 0.08, 0.02)
	# Entrance tunnel: arches of blocks out from the door.
	var outd := Vector3(cos(door_a), 0, sin(door_a))
	var side := Vector3(-sin(door_a), 0, cos(door_a))
	for t in 3:
		var dist := r + 0.25 + t * 0.52
		for j in 7:
			var ang := PI * j / 6.0
			var radial := side * cos(ang) + Vector3.UP * sin(ang)
			var p := c3 + outd * dist + radial * 1.1 + Vector3(0, 0.15, 0)
			var basis := Basis(outd, radial, outd.cross(radial)).orthonormalized()
			box(Transform3D(basis, p), Vector3(0.5, 0.3, 0.5), SNOW.darkened(rng.randf_range(0.0, 0.06)), 0.0, 0.05, 0.03)
	foot_y = NAN
	# Fallen blocks inside and round the foot.
	for i in mini(tumbled, 10):
		var a := cap_a + rng.randf_range(-1.0, 1.0)
		var d := rng.randf_range(0.0, r + 1.2)
		var p := Vector3(center.x + cos(a) * d, 0, center.y + sin(a) * d)
		p.y = ground(p.x, p.z) + 0.1
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6)))
		box(Transform3D(basis, p), Vector3(0.7, 0.36, 0.5), SNOW.darkened(0.05), 0.0, 0.07, 0.05)
	mat = STONE_M
	if not fallen:
		_shelters.append([Vector3(center.x, g + 0.15, center.y), r, r])


# --- Jungle: treehouses -----------------------------------------------------------

## Three or four giant trees in a ring, each with a plank platform high up
## (two with huts), joined by sagging rope bridges (one sometimes snapped),
## and a ramp spiralling up round the first from the ground.
func _treehouse() -> void:
	var n := rng.randi_range(3, 4)
	var trees: Array = [] # [pos 2D, trunk r, deck y, deck r, ground y]
	var a0 := rng.randf() * TAU
	for i in n:
		var a := a0 + TAU * i / n + rng.randf_range(-0.2, 0.2)
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(8.0, 10.0)
		var tr := rng.randf_range(1.0, 1.35)
		var g := ground(p.x, p.y)
		giant_tree(Vector3(p.x, g, p.y), tr, rng.randf_range(26.0, 34.0))
		trees.append([p, tr, g + rng.randf_range(8.0, 11.0), tr + rng.randf_range(2.2, 2.7), g])
	# Where bridges and the ramp meet each deck (angles, for the railings).
	var openings: Array = []
	for i in n:
		openings.append([])
	var broken := rng.randi() % n if rng.randf() < 0.5 else -1
	for i in n:
		var j := (i + 1) % n
		if n == 3 and i == 2 and rng.randf() < 0.5:
			continue
		var pa: Vector2 = trees[i][0]
		var pb: Vector2 = trees[j][0]
		var d := (pb - pa).normalized()
		openings[i].append(d.angle())
		openings[j].append((-d).angle())
		var sa: Vector2 = pa + d * float(trees[i][3])
		var sb: Vector2 = pb - d * float(trees[j][3])
		rope_bridge(Vector3(sa.x, trees[i][2], sa.y), Vector3(sb.x, trees[j][2], sb.y), i == broken)
	# The ramp arrives on the first deck's outer side.
	var p0: Vector2 = trees[0][0]
	var out_a := p0.angle()
	# The camp fire on the ground in the middle, a little away from the
	# ramp's tree.
	var fire := -p0.normalized() * 2.0
	_camp_spot = Vector3(fire.x, ground(fire.x, fire.y), fire.y)
	openings[0].append(out_a)
	spiral_ramp(p0, float(trees[0][3]) + 0.75, float(trees[0][2]), float(trees[0][4]), out_a)
	for i in n:
		var t: Array = trees[i]
		platform(t[0], t[1], t[2], t[3], openings[i])
		if i == 1 or (i == 2 and rng.randf() < 0.6):
			# A hut on the deck, away from the bridges.
			var ha := (t[0] as Vector2).angle() + PI + rng.randf_range(-0.5, 0.5)
			hut(t[0], t[1], t[2], ha)


## A huge buttressed trunk with limbs, a leafy crown and hanging vines.
## The trunk collides as drawn (round, flaring at the foot), and so do the
## buttresses and limbs; the leaves and vines don't.
func giant_tree(base: Vector3, r: float, h: float) -> void:
	mat = WOOD_M
	var sides := 12
	var rings: Array = [] # [y, radius]
	for k in 9:
		var t := float(k) / 8.0
		var y := h * 0.78 * t
		var rad := r * (1.0 - 0.45 * t) * (1.0 + 0.7 * exp(-y / 1.2))
		rings.append([y, rad])
	var col := BARK.lightened(rng.randf_range(-0.05, 0.05))
	col.a = 0.1 # a hint of moss
	var start := _v.size()
	var tw := rng.randf() * TAU
	for k in rings.size() - 1:
		var y0: float = rings[k][0]
		var y1: float = rings[k + 1][0]
		var r0: float = rings[k][1]
		var r1: float = rings[k + 1][1]
		for i in sides:
			var a := TAU * i / sides + tw
			var b := TAU * (i + 1) / sides + tw
			var ps: Array[Vector3] = [base + Vector3(cos(a) * r0, y0, sin(a) * r0), base + Vector3(cos(b) * r0, y0, sin(b) * r0),
				base + Vector3(cos(b) * r1, y1, sin(b) * r1), base + Vector3(cos(a) * r1, y1, sin(a) * r1)]
			_face(ps[0], ps[1], ps[2], ps[3], col, base + Vector3(0, (y0 + y1) * 0.5, 0))
	_smooth_from(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	# Collision: a hull round each pair of rings, the drawn trunk exactly.
	for k in rings.size() - 1:
		var pts := PackedVector3Array()
		for ring in [rings[k], rings[k + 1]]:
			for i in sides:
				var a := TAU * i / sides + tw
				pts.append(base + Vector3(cos(a) * ring[1], ring[0], sin(a) * ring[1]))
		_ch.append(pts)
	# Buttress roots.
	for k in rng.randi_range(4, 5):
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		box(Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), base + out * (r + 0.9) + Vector3(0, 0.6, 0)), Vector3(2.2, 1.4, 0.3), col, 0.4, 0.1, 0.05)
	# Limbs and the crown.
	var top := base + Vector3(0, h * 0.78, 0)
	for k in rng.randi_range(3, 4):
		var a := rng.randf() * TAU
		var from := base + Vector3(0, h * rng.randf_range(0.6, 0.75), 0)
		var to := from + Vector3(cos(a) * h * 0.22, h * 0.14, sin(a) * h * 0.22)
		_limb(from, to, r * 0.32)
		_crown_blob(to + Vector3(0, 1.5, 0), rng.randf_range(4.0, 5.5))
	_crown_blob(top + Vector3(0, 2.5, 0), rng.randf_range(6.0, 7.5))
	mat = STONE_M
	# Vines hanging from the limbs.
	for k in 4:
		var a := rng.randf() * TAU
		var p := base + Vector3(cos(a) * r * 2.5, h * rng.randf_range(0.55, 0.7), sin(a) * r * 2.5)
		_ivy_strand(p, Vector3(cos(a), 0, sin(a)), rng.randf_range(5.0, 11.0))


func _limb(a: Vector3, b: Vector3, thick: float) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var col := BARK.darkened(0.05)
	col.a = 0.1
	box(Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), Vector3(thick, a.distance_to(b), thick), col, 0.3, 0.12, 0.05)


## A leafy crown (no collision: leaves, like the forest's crowns).
func _crown_blob(c: Vector3, radius: float) -> void:
	var was := mat
	mat = LEAF_M
	var col := JUNGLE_LEAF.lightened(rng.randf_range(-0.06, 0.08))
	solid = false
	boulder(c, Vector3(radius, radius * 0.6, radius), Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)), col, 0.0)
	solid = true
	mat = was


## A round deck of planks round a trunk at height y, with knee braces
## below and a post-and-rope railing, open at `openings` (angles).
func platform(p: Vector2, tr: float, y: float, pr: float, openings: Array) -> void:
	mat = WOOD_M
	var rot := rng.randf() * PI
	var ax := Vector3(cos(rot), 0, sin(rot))
	var az := Vector3(-sin(rot), 0, cos(rot))
	var c := Vector3(p.x, y, p.y)
	var o := -pr + 0.18
	while o < pr:
		var half := sqrt(maxf(pr * pr - o * o, 0.0))
		var hole := sqrt(maxf((tr + 0.05) * (tr + 0.05) - o * o, 0.0))
		var spans: Array = [[-half, half]] if hole <= 0.0 else [[-half, -hole], [hole, half]]
		for sp in spans:
			var l: float = sp[1] - sp[0]
			if l < 0.3 or rng.randf() < 0.05:
				continue
			var mid: float = (sp[0] + sp[1]) * 0.5
			var col := OLD_WOOD.lightened(rng.randf_range(-0.08, 0.06))
			box(Transform3D(Basis(ax, Vector3.UP, ax.cross(Vector3.UP)), c + ax * mid + az * o), Vector3(l, 0.08, 0.32), col, 0.15, 0.02, 0.01)
		o += 0.36
	# Knee braces from the trunk to the rim.
	for k in 4:
		var a := rot + TAU * k / 4.0 + PI * 0.25
		var dirv := Vector3(cos(a), 0, sin(a))
		_pole(c + dirv * tr + Vector3(0, -2.6, 0), c + dirv * (pr - 0.3) + Vector3(0, -0.1, 0), 0.16)
	# Railing.
	var posts := maxi(6, int(TAU * pr / 1.5))
	var prev := Vector3.ZERO
	var prev_ok := false
	for k in posts + 1:
		var a := TAU * k / posts
		var open := false
		for oa in openings:
			if absf(angle_difference(a, float(oa))) < 0.45:
				open = true
		var q := c + Vector3(cos(a), 0, sin(a)) * (pr - 0.1)
		if open:
			prev_ok = false
			continue
		if k < posts:
			_pole(q, q + Vector3(0, 1.05, 0), 0.08)
		var top := q + Vector3(0, 0.95, 0)
		if prev_ok:
			_rail(prev, top)
		prev = top
		prev_ok = true
	mat = STONE_M
	_shelters.append([c, pr, 0.0]) # a place, not a roof (height 0: no shelter)


## A thatched hut on a deck, against the trunk.
func hut(p: Vector2, tr: float, y: float, a: float) -> void:
	mat = WOOD_M
	var out := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-sin(a), 0, cos(a))
	var c := Vector3(p.x, y, p.y) + out * (tr + 1.3)
	var hw := 1.1
	var hd := 0.9
	var wall_h := 1.9
	# Board walls on three sides, the door side (outward) half open.
	for s in [-1.0, 1.0]:
		var n := 6
		for k in n:
			var t := (k + 0.5) / n * 2.0 - 1.0
			var bpos: Vector3 = c + side * hw * s + out * hd * t + Vector3(0, wall_h * 0.5, 0)
			if rng.randf() < 0.1:
				continue
			box(Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), bpos), Vector3(0.28, wall_h, 0.06), OLD_WOOD.lightened(rng.randf_range(-0.08, 0.05)), 0.1, 0.01, 0.01)
	for k in 7:
		var t := (k + 0.5) / 7.0 * 2.0 - 1.0
		if absf(t) < 0.35:
			continue # the doorway
		var bpos: Vector3 = c + out * hd + side * hw * t + Vector3(0, wall_h * 0.5, 0)
		box(Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)), bpos), Vector3(0.28, wall_h, 0.06), OLD_WOOD.lightened(rng.randf_range(-0.08, 0.05)), 0.1, 0.01, 0.01)
	# Thatched roof: two slopes meeting over the middle.
	mat = THATCH_M
	var ridge := c + Vector3(0, wall_h + 0.8, 0)
	var tc := THATCH.lightened(rng.randf_range(-0.06, 0.06))
	tc.a = 0.2
	for s in [-1.0, 1.0]:
		var eave: Vector3 = c + side * (hw + 0.35) * s + Vector3(0, wall_h - 0.1, 0)
		var mid: Vector3 = (ridge + eave) * 0.5
		var slope_dir: Vector3 = (eave - ridge).normalized()
		var basis := Basis(out, slope_dir.cross(out).normalized() * (-1.0 if s < 0.0 else 1.0), slope_dir).orthonormalized()
		box(Transform3D(Basis(out, slope_dir.cross(out).normalized(), slope_dir), mid), Vector3((hd + 0.4) * 2.0, 0.14, ridge.distance_to(eave) + 0.2), tc, 0.0, 0.05, 0.04)
	mat = STONE_M
	_shelters.append([c, hw, wall_h])


## A sagging rope bridge from deck edge `a` to deck edge `b`: planks on
## two ropes, a rope rail each side. `snapped`: it has broken in the
## middle and the halves hang down.
func rope_bridge(a: Vector3, b: Vector3, snapped: bool) -> void:
	mat = WOOD_M
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := flat.length()
	var dir := flat / length
	var side := Vector3(-dir.z, 0, dir.x)
	var sag := 0.08 * length
	var n := int(length / 0.42)
	var deck := func(t: float) -> Vector3:
		return a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
	var prev_rail: Array = []
	for k in n + 1:
		var t := float(k) / n
		var p: Vector3 = deck.call(t)
		if snapped and absf(t - 0.5) < 0.12:
			continue
		if snapped:
			# Each half hangs from its own deck, swinging down.
			var h := clampf((0.5 - absf(t - 0.5)) / 0.38, 0.0, 1.0)
			var anchor := a if t < 0.5 else b
			var reach := absf(t - (0.0 if t < 0.5 else 1.0)) * length
			p = anchor + dir * (reach * (1.0 - h) * (1.0 if t < 0.5 else -1.0)) + Vector3(0, -reach * h, 0)
		var next: Vector3 = deck.call(minf(t + 0.01, 1.0))
		var along := (next - p).normalized() if not snapped else dir
		if rng.randf() > 0.06:
			var col := OLD_WOOD.lightened(rng.randf_range(-0.08, 0.06))
			box(Transform3D(Basis(side, along.cross(side).normalized() * -1.0, along).orthonormalized(), p), Vector3(1.2, 0.07, 0.26), col, 0.1, 0.02, 0.01)
		# Rope rails: posts of rope every few planks.
		var rails: Array = [p + side * 0.62 + Vector3(0, 0.95, 0), p - side * 0.62 + Vector3(0, 0.95, 0)]
		if not prev_rail.is_empty() and not snapped:
			_rail(prev_rail[0], rails[0])
			_rail(prev_rail[1], rails[1])
			if k % 3 == 0:
				_rope(p + side * 0.6, rails[0])
				_rope(p - side * 0.6, rails[1])
		prev_rail = rails
	mat = STONE_M


## A ramp of planks spiralling round a deck from the ground up to it,
## arriving at angle `end_a` (radius `ramp_r` from the trunk), on posts.
func spiral_ramp(p: Vector2, ramp_r: float, deck_y: float, g: float, end_a: float) -> void:
	mat = WOOD_M
	var slope := 0.42
	var length := (deck_y - g) / slope
	var step := 0.55
	var n := int(length / step)
	var c := Vector3(p.x, 0, p.y)
	for k in n:
		var d0 := length - k * step
		var d1 := length - (k + 1) * step
		var a0 := end_a - d0 / ramp_r
		var a1 := end_a - d1 / ramp_r
		var q0 := c + Vector3(cos(a0) * ramp_r, deck_y - d0 * slope, sin(a0) * ramp_r)
		var q1 := c + Vector3(cos(a1) * ramp_r, deck_y - d1 * slope, sin(a1) * ramp_r)
		var along := (q1 - q0).normalized()
		var out := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var up2 := along.cross(out).normalized()
		if up2.y < 0.0:
			up2 = -up2
		var col := OLD_WOOD.lightened(rng.randf_range(-0.08, 0.06))
		box(Transform3D(Basis(out, up2, out.cross(up2)).orthonormalized(), (q0 + q1) * 0.5), Vector3(1.2, 0.08, step * 1.08), col, 0.1, 0.02, 0.01)
		if k % 4 == 2:
			var foot := (q0 + q1) * 0.5 + out * 0.5
			var fg := ground(foot.x, foot.z)
			if foot.y - fg > 0.8:
				_pole(Vector3(foot.x, fg - 0.3, foot.z), foot + Vector3(0, -0.05, 0), 0.12)
	mat = STONE_M


## A rope rail (a deck's or a bridge's handrail): a rope with a thin box
## of collision along it, so it keeps you on. Other ropes don't collide.
func _rail(a: Vector3, b: Vector3) -> void:
	_rope(a, b)
	_collision_box(Transform3D(_along(b - a), (a + b) * 0.5), Vector3(0.03, a.distance_to(b) * 0.5, 0.03))


## A thin rope segment (no collision).
func _rope(a: Vector3, b: Vector3) -> void:
	var was := mat
	mat = WOOD_M
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var col := ROPE
	col.a = 0.0
	_tri_box(Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), Vector3(0.04, a.distance_to(b), 0.04), col)
	mat = was


## A plain box with no bevel, collision or LOD (ropes and the like).
func _tri_box(xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_face(p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, xf.origin)


# --- Marsh: boardwalk and cabin ---------------------------------------------------

## A plank walk on posts wandering across the marsh, planks missing and one
## stretch sunk under the water, dead snags beside it, and a stilt cabin
## at the far end.
func _boardwalk() -> void:
	var length: float = site.length_m
	var n := int(length / 1.6)
	var pts: Array[Vector2] = []
	var z := 0.0
	var dz := 0.0
	for i in n + 1:
		dz = clampf(dz + rng.randf_range(-0.2, 0.2), -0.35, 0.35)
		z = clampf(z + dz, -2.2, 2.2)
		if absf(z) >= 2.2:
			dz = -dz * 0.5
		pts.append(Vector2(-length * 0.5 + i * length / n, z))
	# Level just above the ground or the water, whichever is higher.
	var deck_y := -INF
	for q in pts:
		deck_y = maxf(deck_y, surface(q.x, q.y))
	deck_y += 0.45
	# The camp fire where the walk begins: on the ground if it's dry, else
	# on a plank landing.
	var fire := pts[0] + Vector2(-4.0, 0.0)
	var fg := ground(fire.x, fire.y)
	if surface(fire.x, fire.y) > fg + 0.05:
		fg = deck_y
		mat = WOOD_M
		var o := -2.4
		while o < 2.4:
			box(Transform3D(Basis.IDENTITY, Vector3(fire.x + o, deck_y, fire.y)), Vector3(0.32, 0.08, 5.0), OLD_WOOD.lightened(rng.randf_range(-0.08, 0.05)), 0.2, 0.02, 0.01)
			o += 0.36
		for sx in [-2.0, 2.0]:
			for sz in [-2.0, 2.0]:
				var q := Vector3(fire.x + sx, deck_y, fire.y + sz)
				_pole(Vector3(q.x, ground(q.x, q.z) - 0.8, q.z), q, 0.17)
		mat = STONE_M
	_camp_spot = Vector3(fire.x, fg, fire.y)
	var sunk0 := rng.randi_range(int(n * 0.3), int(n * 0.6))
	var sunk1 := sunk0 + rng.randi_range(2, 4)
	mat = WOOD_M
	for i in n:
		var a := pts[i]
		var b := pts[i + 1]
		var sa := surface(a.x, a.y)
		var sb := surface(b.x, b.y)
		# Up from the ground at the start, level after, dipping just under
		# the water where it's sunk.
		var ya := minf(deck_y, sa + 0.1 + i * 0.25)
		var yb := minf(deck_y, sb + 0.1 + (i + 1) * 0.25)
		if i >= sunk0 and i < sunk1:
			ya = minf(ya, sa - 0.12)
			yb = minf(yb, sb - 0.12)
		var a3 := Vector3(a.x, ya, a.y)
		var b3 := Vector3(b.x, yb, b.y)
		var along := (b3 - a3).normalized()
		var flat := Vector3(along.x, 0, along.z).normalized()
		var side := Vector3(-flat.z, 0, flat.x)
		var up2 := along.cross(side).normalized() * -1.0
		if up2.y < 0.0:
			up2 = -up2
		var planks := int(a3.distance_to(b3) / 0.34)
		for k in planks:
			if rng.randf() < 0.08:
				continue
			var t := (k + 0.5) / planks
			var col := OLD_WOOD.lightened(rng.randf_range(-0.1, 0.06))
			col.a = 0.25
			var basis := Basis(side, up2, side.cross(up2)).rotated(up2, rng.randf_range(-0.05, 0.05))
			box(Transform3D(basis, a3.lerp(b3, t)), Vector3(1.5, 0.07, 0.28), col, 0.25, 0.02, 0.015)
		# Stringers under the planks.
		for s in [-0.5, 0.5]:
			var off: Vector3 = side * s + Vector3(0, -0.1, 0)
			box(Transform3D(Basis(side, up2, side.cross(up2)), (a3 + b3) * 0.5 + off), Vector3(0.14, 0.12, a3.distance_to(b3)), OLD_WOOD.darkened(0.15), 0.3, 0.02, 0.01)
		# Posts every other point, a few standing proud of the deck.
		if i % 2 == 0:
			for s in [-0.72, 0.72]:
				var q: Vector3 = a3 + side * s
				var extra := rng.randf_range(0.2, 0.9) if rng.randf() < 0.4 else 0.1
				_pole(Vector3(q.x, ground(q.x, q.z) - 0.8, q.z), q + Vector3(0, extra, 0), 0.17)
	mat = STONE_M
	# Dead snags standing in the marsh.
	for k in rng.randi_range(3, 6):
		var t := rng.randf()
		var q: Vector2 = pts[int(t * n)] + Vector2(0, rng.randf_range(3.0, 6.0) * (1.0 if rng.randf() < 0.5 else -1.0))
		var g := ground(q.x, q.y)
		var col := OLD_WOOD.darkened(0.25)
		_limb(Vector3(q.x, g - 0.5, q.y), Vector3(q.x + rng.randf_range(-0.4, 0.4), g + rng.randf_range(2.5, 6.0), q.y + rng.randf_range(-0.4, 0.4)), rng.randf_range(0.25, 0.4))
	# The cabin at the end.
	var e := pts[n]
	var d := (pts[n] - pts[n - 1]).normalized()
	cabin(e + d * 2.6, d.angle(), deck_y + 0.1)


## A plank cabin on stilts, the door facing back along `heading`, a
## window, boards missing and part of the thatch fallen in.
func cabin(center: Vector2, heading: float, floor_y: float) -> void:
	mat = WOOD_M
	var fwd := Vector3(cos(heading), 0, sin(heading))
	var side := Vector3(-fwd.z, 0, fwd.x)
	var c := Vector3(center.x, floor_y, center.y)
	var hl := 2.2 # half length (along fwd)
	var hw := 1.7
	var wall_h := 2.2
	# Stilts and floor.
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q: Vector3 = c + fwd * hl * 0.9 * sx + side * hw * 0.9 * sz
			_pole(Vector3(q.x, ground(q.x, q.z) - 0.8, q.z), q + Vector3(0, -0.05, 0), 0.2)
	var o := -hw + 0.17
	while o < hw:
		box(Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)), c + side * o), Vector3(hl * 2.0, 0.08, 0.32), OLD_WOOD.lightened(rng.randf_range(-0.08, 0.05)), 0.2, 0.02, 0.01)
		o += 0.34
	# Walls: vertical boards; the doorway faces back along the walk, a
	# window in one side, some boards gone.
	var slump := rng.randi() % 4
	for w in 4:
		var normal := [-fwd, fwd, side, -side][w] as Vector3
		var tangent := normal.cross(Vector3.UP)
		var half := hw if w < 2 else hl
		var reach := hl if w < 2 else hw
		var boards := int(half * 2.0 / 0.3)
		for k in boards:
			var t := ((k + 0.5) / boards * 2.0 - 1.0) * half
			if w == 0 and absf(t) < 0.45:
				continue # doorway
			if rng.randf() < 0.08:
				continue
			var h := wall_h * (0.55 if w == slump and t > 0.0 else 1.0) * rng.randf_range(0.92, 1.0)
			var base := c + normal * reach + tangent * t
			var col := OLD_WOOD.lightened(rng.randf_range(-0.1, 0.05))
			col.a = 0.2
			if w == 2 and absf(t) < 0.5:
				# Window: a gap between a low and a high board.
				box(Transform3D(Basis(tangent, Vector3.UP, normal), base + Vector3(0, 0.5, 0)), Vector3(0.28, 1.0, 0.06), col, 0.2, 0.01, 0.01)
				box(Transform3D(Basis(tangent, Vector3.UP, normal), base + Vector3(0, 1.9, 0)), Vector3(0.28, 0.6, 0.06), col, 0.2, 0.01, 0.01)
				continue
			box(Transform3D(Basis(tangent, Vector3.UP, normal), base + Vector3(0, h * 0.5, 0)), Vector3(0.28, h, 0.06), col, 0.2, 0.01, 0.01)
	# Roof: two thatch slopes along the length, one fallen in at one end.
	mat = THATCH_M
	var ridge := c + Vector3(0, wall_h + 1.1, 0)
	for s in [-1.0, 1.0]:
		var eave: Vector3 = c + side * (hw + 0.4) * s + Vector3(0, wall_h - 0.05, 0)
		var slope_dir: Vector3 = (eave - ridge).normalized()
		var basis := Basis(fwd, slope_dir.cross(fwd).normalized(), slope_dir).orthonormalized()
		var tc := THATCH.darkened(rng.randf_range(0.0, 0.15))
		tc.a = 0.35
		for part in 3:
			if s > 0.0 and part == 2 and rng.randf() < 0.7:
				continue # caved in
			var t := (part - 1.0) * (hl + 0.4) * 2.0 / 3.0
			box(Transform3D(basis, (ridge + eave) * 0.5 + fwd * t), Vector3((hl + 0.4) * 2.0 / 3.0, 0.14, ridge.distance_to(eave) + 0.25), tc, 0.0, 0.05, 0.04)
	mat = STONE_M
	_shelters.append([c, minf(hl, hw), wall_h])


# --- Pyramids ---------------------------------------------------------------------

## A pyramid, to the measurements Ruins._pyramid_site() chose: cased in
## sandstone in the desert, stepped everywhere else. A living camp's fire
## goes at the foot on the +x side.
func _pyramid() -> void:
	var style: String = site.style
	var hs: float = site.base_m * 0.5
	match style:
		"desert":
			palette = SANDSTONE
			_desert_pyramid(hs)
		"jungle", "marsh":
			palette = LIMESTONE
			_step_pyramid(hs, style)
		_:
			_step_pyramid(hs, style)
	var cx := hs + 6.0
	_camp_spot = Vector3(cx, ground(cx, 0.0), 0.0)


## Lowest (x) and highest (y) ground under a square of half-side `hs`.
func _ground_range(c: Vector2, hs: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in 5:
		for j in 5:
			var g := ground(c.x - hs + hs * 0.5 * i, c.y - hs + hs * 0.5 * j)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return Vector2(lo, hi)


## The great desert pyramid: sand drifted round its foot, a few broken
## capstone blocks on its flat top, an entrance up one face, fallen casing
## stones at the base and a small queen's pyramid beside it.
func _desert_pyramid(hs: float) -> void:
	var h: float = site.height_m
	mound(hs + 2.0, hs + 44.0, 26.0, 0.3)
	# The way in, a little up the -z face (floor at y_f).
	var y_f := -0.3 + h * 0.13 - 0.3
	var yt := _cased_pyramid(Vector2.ZERO, hs, h, -0.3, 0.93, Vector3(1.6, y_f + 0.1, y_f + 2.6))
	var st := hs * 0.07
	for i in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		block(Vector3(rng.randf_range(-st, st) * 0.6, yt + 0.5, rng.randf_range(-st, st) * 0.6), Vector3(cos(a), 0.0, sin(a)), Vector3(2.2, 1.0, 1.6), 0.0)
	_pyramid_entrance(hs, h, -0.3)
	_pyramid_chamber(hs, h, -0.3)
	var q: float = site.queen_hs
	var qc := Vector2(-(hs + q + 8.0), 0.0)
	var qg := _ground_range(qc, q)
	_cased_pyramid(qc, q, q * 2.0 * 0.62, qg.x - 0.6, 0.97)
	for k in 4:
		var a := rng.randf() * TAU
		rubble(Vector3(cos(a) * hs * 1.03, 0.0, sin(a) * hs * 1.03), 5.0, 7)


## A smooth-sided pyramid of side 2 * `hs` and full height `h` from `y0`,
## cut off at `cut` of its height (the capstone gone). The casing is
## weathered into rough courses: each one leans in a little steeper than
## the whole and steps back at a ledge. A skirt runs down below the base so
## it never floats over coarser far terrain. `door` (half width, from y,
## to y), if set, leaves a gap in the -z face's courses there for a way
## in. Returns the top's height.
func _cased_pyramid(c: Vector2, hs: float, h: float, y0: float, cut: float, door := Vector3.ZERO) -> float:
	var start := _v.size()
	var rows := maxi(6, int(h * cut / 1.7))
	var corner := func(i: int, s: float, y: float) -> Vector3:
		var q: Vector2 = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)][i % 4]
		return Vector3(c.x + q.x * s, y, c.y + q.y * s)
	var skirt: Color = (palette[4] as Color).darkened(0.1)
	skirt.a = 0.0
	for f in 4:
		_face(corner.call(f, hs, y0 - 8.0), corner.call(f + 1, hs, y0 - 8.0), corner.call(f + 1, hs, y0), corner.call(f, hs, y0), skirt, Vector3(c.x, y0 - 4.0, c.y))
	for r in rows:
		var t0 := cut * r / rows
		var t1 := cut * (r + 1) / rows
		var s0 := hs * (1.0 - t0)
		var s1 := hs * (1.0 - t1)
		var ya := y0 + h * t0
		var yb := y0 + h * t1
		# Weathered further back toward the top.
		var ledge := rng.randf_range(0.1, 0.3) + 0.5 * t1 * rng.randf()
		var col: Color = (palette[rng.randi() % palette.size()] as Color).lightened(rng.randf_range(-0.04, 0.04))
		col.a = 0.0
		var ledge_col := col.lightened(0.1)
		ledge_col.a = 0.0
		var gap := door.x > 0.0 and yb > door.y and ya < door.z
		for f in 4:
			var a0: Vector3 = corner.call(f, s0, ya)
			var b0: Vector3 = corner.call(f + 1, s0, ya)
			var a1: Vector3 = corner.call(f, s1 + ledge, yb)
			var b1: Vector3 = corner.call(f + 1, s1 + ledge, yb)
			var a2: Vector3 = corner.call(f, s1, yb)
			var b2: Vector3 = corner.call(f + 1, s1, yb)
			if f == 0 and gap:
				# Two pieces either side of the doorway (the -z face runs
				# along x at constant z).
				var inside_a := Vector3(c.x, ya, c.y)
				var inside_b := Vector3(c.x, yb - 4.0, c.y)
				for piece in [[a0, a1, a2, -1.0], [b0, b1, b2, 1.0]]:
					var p0: Vector3 = piece[0]
					var p1: Vector3 = piece[1]
					var p2: Vector3 = piece[2]
					var gx: float = c.x + float(piece[3]) * door.x
					_face(p0, Vector3(gx, p0.y, p0.z), Vector3(gx, p1.y, p1.z), p1, col, inside_a)
					_face(p1, Vector3(gx, p1.y, p1.z), Vector3(gx, p2.y, p2.z), p2, ledge_col, inside_b)
				continue
			_face(a0, b0, b1, a1, col, Vector3(c.x, ya, c.y))
			_face(a1, b1, b2, a2, ledge_col, Vector3(c.x, yb - 4.0, c.y))
	var st := hs * (1.0 - cut)
	var yt := y0 + h * cut
	var top: Color = palette[0]
	top.a = 0.0
	_face(corner.call(0, st, yt), corner.call(1, st, yt), corner.call(2, st, yt), corner.call(3, st, yt), top, Vector3(c.x, yt - 4.0, c.y))
	_collide_since(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	return yt


## The way in, a little up the -z face (floor y_f): a portal of casing
## stone standing proud of the face, its doorway open, two great slabs
## leaning together over it, and a stair up the face to its sill.
func _pyramid_entrance(hs: float, h: float, y0: float) -> void:
	var t := 0.13
	var y_f := y0 + h * t - 0.3
	var z := -hs * (1.0 - t)
	var zc := z + 0.6
	for sx: float in [-1.0, 1.0]:
		box(Transform3D(Basis.IDENTITY, Vector3(sx * 1.55, y_f + 1.1, zc)), Vector3(1.1, 6.6, 3.0), palette[1], 0.0, 0.12, 0.04)
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, y_f + 3.45, zc)), Vector3(2.0, 1.9, 3.0), palette[1], 0.0, 0.1, 0.03)
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, y_f - 1.1, zc)), Vector3(2.0, 2.2, 3.0), palette[1], 0.0, 0.05, 0.02)
	for sx: float in [-1.0, 1.0]:
		box(Transform3D(Basis(Vector3(0, 0, 1), -sx * 0.75), Vector3(sx * 1.1, y_f + 4.9, z + 0.2)), Vector3(3.0, 0.8, 3.2), palette[2], 0.0)
	_stairs(3.0, zc - 1.5, y_f, -(hs + 8.0), 38.0, func(y: float) -> float:
		return -hs * (1.0 - (y - y0) / h) + 0.5)


## Inside the desert pyramid: a corridor from the portal straight in to a
## burial chamber at the heart, 5 by 7 m and 4 m high, a granite
## sarcophagus and grave goods within, a lamp-gold glow there and a dim
## one along the way.
func _pyramid_chamber(hs: float, h: float, y0: float) -> void:
	var t := 0.13
	var y_f := y0 + h * t - 0.3
	var z_in := -hs * (1.0 - t) + 2.1 # the portal's back
	shade = 0.45
	var chx := 3.4
	var chz := 4.3
	var z_out := -chz
	var length := z_out - z_in
	var n := maxi(1, int(ceil(length / 3.0)))
	var sl := length / n
	for i in n:
		var zm := z_in + (i + 0.5) * sl
		var col: Color = palette[rng.randi() % palette.size()]
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, y_f - 0.25, zm)), Vector3(3.2, 0.5, sl), col.darkened(0.1), 0.0, 0.04, 0.02)
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, y_f + 2.75, zm)), Vector3(3.2, 0.5, sl), col.darkened(0.15), 0.0, 0.04, 0.02)
		for sx: float in [-1.0, 1.0]:
			box(Transform3D(Basis.IDENTITY, Vector3(sx * 1.3, y_f + 1.25, zm)), Vector3(0.6, 2.5, sl), palette[rng.randi() % palette.size()], 0.0, 0.05, 0.02)
	# The chamber: a floor, walls with a door to the corridor, a flat roof.
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, y_f - 0.25, 0.0)), Vector3(chx * 2.0, 0.5, chz * 2.0), palette[2], 0.0, 0.05, 0.02)
	var courses := 4
	var ch := 1.05
	_house_walls(Vector3(0.0, y_f, 0.0), chx, chz, courses, ch, 0.8, 0.9, 2, 1.0, 0.0)
	for i in 3:
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, y_f + courses * ch + 0.3, -chz + (i + 0.5) * chz * 2.0 / 3.0)), Vector3(chx * 2.0, 0.6, chz * 2.0 / 3.0), palette[rng.randi() % palette.size()], 0.0, 0.06, 0.02)
	_sarcophagus(Vector3(0.0, y_f, 1.4), 0.0, Color(0.36, 0.3, 0.3))
	_grave_goods(Vector3(0.0, y_f, -1.2), 1.6, 6)
	for sx: float in [-1.0, 1.0]:
		_lamp(Vector3(sx * (chx - 0.9), y_f, chz - 0.9), 8.0, 0.2)
	_glow(Vector3(0.0, y_f + 2.0, (z_in + z_out) * 0.5), Color(0.45, 0.85, 0.8), 7.0, 0.12)
	_shelters.append([Vector3(0.0, y_f, 0.0), 3.0, courses * ch])
	var zs := z_in
	while zs < z_out:
		_shelters.append([Vector3(0.0, y_f, zs), 1.3, 2.5])
		zs += 2.0
	shade = 0.0


## A stepped pyramid: `tiers` tiers of big blocks narrowing to the top
## platform, a stair up the -z face, and on top a shrine (jungle), a
## fallen shrine (marsh, where the pyramid's sunk to its second tier) or
## an obelisk (stone and snow; snow lies on every ledge).
func _step_pyramid(hs: float, style: String) -> void:
	var n: int = site.tiers
	var th: float = site.tier_m
	var top_hs: float = site.top_hs
	var inset := (hs - top_hs) / (n - 1)
	var gr := _ground_range(Vector2.ZERO, hs)
	mound(hs + 1.0, hs + 30.0, 26.0, -0.2)
	var y0 := gr.y - th * (1.6 if style == "marsh" else 0.5)
	var lush := style == "jungle" or style == "marsh"
	var stair_w := clampf(hs * 0.28, 5.0, 8.0)
	for k in n:
		var s := hs - k * inset
		var top := y0 + (k + 1) * th
		var bottom := gr.x - 3.0 if k == 0 else top - th - 0.3
		_tier(s, bottom, top, inset + 0.6, k, stair_w, lush, th)
	var y_top := y0 + n * th
	var reach: float = hs + site.stair_out + 1.0
	_stairs(stair_w, -top_hs, y_top, -reach, Ruins.STAIR_DEG, func(y: float) -> float:
		var k := clampi(int(floor((y - y0) / th)), 0, n - 1)
		return -(hs - k * inset) + 0.6)
	var floor_y := y_top - 0.12
	if style == "snow":
		for k in n - 1:
			_snow_ledge(hs - k * inset, inset, y0 + (k + 1) * th)
		mat = SNOW_M
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, floor_y + 0.1, 0.0)), Vector3(2.0 * top_hs - 1.4, 0.2, 2.0 * top_hs - 1.4), SNOW, 0.0, 0.1, 0.06)
		mat = STONE_M
	match style:
		"jungle":
			_shrine(floor_y, 0.8, false)
		"marsh":
			_shrine(floor_y, 0.8, true)
		_:
			_obelisk(floor_y, top_hs)
	for k in rng.randi_range(2, 4):
		var a := rng.randf_range(0.3, PI - 0.3) # clear of the stair's foot
		rubble(Vector3(cos(a) * hs * 1.08, 0.0, sin(a) * hs * 1.08), 4.0, 6)


## One tier: a ring of big blocks, `depth` deep, round a core set back a
## little behind them (the core shows where a block has fallen out, and
## its top is the platform's paving on the top tier). Blocks behind the
## stair are left out. Mossy on top, heavily so and hung with ivy on
## `lush` pyramids.
func _tier(s: float, bottom: float, top: float, depth: float, k: int, stair_w: float, lush: bool, th: float) -> void:
	var core_col: Color = (palette[3] as Color).darkened(0.2)
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, (bottom + top) * 0.5 - 0.06, 0.0)), Vector3(2.0 * s - 1.0, top - bottom - 0.12, 2.0 * s - 1.0), core_col, _growth(0.5 if lush else 0.2), 0.1, 0.0)
	var courses := maxi(1, int(round((top - bottom) / 1.5)))
	var ch := (top - bottom) / courses
	for f in 4:
		# -z, +x, +z, -x. The two along x run corner to corner, the other
		# two fit between them.
		var along_x := f % 2 == 0
		var sgn := -1.0 if f == 0 or f == 3 else 1.0
		var length := 2.0 * s if along_x else 2.0 * (s - depth)
		var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var out := Vector3(0, 0, sgn) if along_x else Vector3(sgn, 0, 0)
		var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		var blocks := maxi(1, int(ceil(length / 3.2)))
		var bw := length / blocks
		for i in blocks:
			var u := -length * 0.5 + (i + 0.5) * bw
			if f == 0 and absf(u) < stair_w * 0.5 - 0.4:
				continue
			var c := dir * u + out * (s - depth * 0.5)
			for j in courses:
				var last := j == courses - 1
				if k > 0 and last and rng.randf() < 0.06:
					continue # fallen out
				var moss := (0.2 + (0.5 if last else 0.0)) * (1.0 if lush else 0.5) + rng.randf_range(0.0, 0.15)
				var col: Color = (palette[rng.randi() % palette.size()] as Color).lightened(rng.randf_range(-0.05, 0.05))
				box(Transform3D(basis, c + Vector3(0.0, bottom + (j + 0.5) * ch, 0.0)), Vector3(bw, ch * 0.98, depth), col, _growth(moss), rng.randf_range(0.08, 0.14), 0.05)
		if lush:
			for m in 2:
				var u := rng.randf_range(-length * 0.4, length * 0.4)
				if f == 0 and absf(u) < stair_w:
					continue
				ivy(dir * u + out * s + Vector3(0.0, top, 0.0), out, rng.randf_range(1.0, th * 1.4))


## Snow lying on a tier's ledge (the band `width` wide inside its edge).
func _snow_ledge(s: float, width: float, y: float) -> void:
	mat = SNOW_M
	for f in 4:
		var along_x := f % 2 == 0
		var sgn := -1.0 if f == 0 or f == 3 else 1.0
		var length := 2.0 * s if along_x else 2.0 * (s - width)
		var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var out := Vector3(0, 0, sgn) if along_x else Vector3(sgn, 0, 0)
		var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		box(Transform3D(basis, out * (s - width * 0.5) + Vector3(0.0, y + 0.12, 0.0)), Vector3(length, 0.24, width + 0.05), SNOW, 0.0, 0.1, 0.06)
	mat = STONE_M


## A flight of steps climbing toward +z at `deg` degrees to (z_end,
## y_top): from where that line meets the ground (but no further out
## than reach_z), each step a slab reaching back to back.call(y) (the
## face it's built against), `w` wide, between two sloping balustrades.
## A smooth ramp stands in for the steps underfoot (the player can't
## climb stairs step by step).
func _stairs(w: float, z_end: float, y_top: float, reach_z: float, deg: float, back: Callable) -> void:
	var tanv := tan(deg_to_rad(deg))
	var z_start := z_end
	for i in 400:
		z_start -= 0.25
		if y_top - (z_end - z_start) * tanv <= ground(0.0, z_start) or z_start < reach_z:
			break
	var y_start := ground(0.0, z_start)
	var rise := y_top - y_start
	var run := z_end - z_start
	var steps := maxi(4, int(round(rise / 0.5)))
	var r := rise / steps
	var t := run / steps
	solid = false
	for i in steps:
		var y_i := y_start + (i + 1) * r
		var z_i := z_start + i * t
		var bk := maxf(float(back.call(y_i - r * 0.5)), z_i + 0.6)
		var bottom := y_i - r if i > 0 else ground(0.0, z_i) - 1.5
		var col: Color = (palette[rng.randi() % palette.size()] as Color).lightened(rng.randf_range(-0.04, 0.04))
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, (y_i + bottom) * 0.5, (z_i + bk) * 0.5)), Vector3(w + 2.0, y_i - bottom, bk - z_i), col, _growth(0.25), 0.06, 0.03)
	solid = true
	var dirv := Vector3(0.0, rise, run).normalized()
	var nrm := dirv.cross(Vector3.RIGHT)
	var basis := Basis(Vector3.RIGHT, nrm, dirv)
	var mid := Vector3(0.0, (y_start + y_top) * 0.5, (z_start + z_end) * 0.5)
	var length := Vector2(rise, run).length()
	for sx: float in [-1.0, 1.0]:
		box(Transform3D(basis, mid + Vector3(sx * (w * 0.5 + 0.5), 0.0, 0.0) + nrm * 0.35), Vector3(1.0, 1.1, length + 0.6), palette[0], _growth(0.4), 0.12, 0.04)
	_ramp(Vector3(0.0, y_start, z_start), Vector3(0.0, y_top, z_end), w, r * 0.8)


## A walkable slope (collision only) from `a` up to `b` (both in one
## x = const plane), `w` wide, its surface `sink` m below the line at the
## foot and meeting `b` exactly at the top (so there's no lip onto the
## floor there). It runs on a little past the foot, into the ground.
func _ramp(a: Vector3, b: Vector3, w: float, sink: float) -> void:
	a -= Vector3(0.0, sink, 0.0)
	var dirv := (b - a).normalized()
	var x := Vector3.RIGHT
	var nrm := dirv.cross(x)
	if nrm.y < 0.0:
		nrm = -nrm
		x = -x
	var foot := a - dirv * 0.6
	var length := foot.distance_to(b)
	_collision_box(Transform3D(Basis(x, nrm, dirv), (foot + b) * 0.5 - nrm * 0.5), Vector3(w * 0.5, 0.5, length * 0.5))


## Steps up to a raised floor at `floor_y` from the ground in front of a
## door on the -z side at z_door, `w` wide, over a ramp.
func _door_steps(x: float, z_door: float, floor_y: float, w: float) -> void:
	var g := ground(x, z_door - 1.2)
	var rise := floor_y - g
	if rise < 0.12:
		return
	var n := clampi(int(ceil(rise / 0.3)), 1, 4)
	solid = false
	for k in n:
		var top := floor_y - rise * (k + 1) / (n + 1)
		var z1 := z_door - 0.45 * k
		var z0 := z1 - 0.45
		box(Transform3D(Basis.IDENTITY, Vector3(x, (top + g - 0.5) * 0.5, (z0 + z1) * 0.5 + 0.2)), Vector3(w, top - g + 0.5, z1 - z0 + 0.4), palette[k % palette.size()], _growth(0.3), 0.05, 0.03)
	solid = true
	# Up just past the floor's front edge, so there's no lip to catch on.
	_ramp(Vector3(x, g, z_door - 0.45 * n - 0.6), Vector3(x, floor_y + 0.04, z_door + 0.05), w, 0.0)


## Four walls of block courses round a room (floor at c.y, centered on c),
## `hx` by `hz` outside and `thick` thick, the door on the -z wall
## `door_half` either side of c.x and `door_courses` courses tall. Each
## column stands whole with chance `keep`, else broken down to a stump.
func _house_walls(c: Vector3, hx: float, hz: float, courses: int, ch: float, thick: float, door_half: float, door_courses: int, keep := 1.0, ivy_chance := 0.5) -> void:
	for f in 4:
		var along_x := f % 2 == 0
		var sgn := -1.0 if f == 0 or f == 3 else 1.0
		var length := hx * 2.0 if along_x else hz * 2.0 - thick * 2.0
		var dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var out := Vector3(0, 0, sgn) if along_x else Vector3(sgn, 0, 0)
		var half := hz if along_x else hx
		var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		var blocks := maxi(1, int(ceil(length / 1.3)))
		var bw := length / blocks
		for i in blocks:
			var u := -length * 0.5 + (i + 0.5) * bw
			var h := courses if rng.randf() < keep else rng.randi_range(0, courses - 1)
			for j in h:
				if f == 0 and absf(u) < door_half + bw * 0.4 and j < door_courses:
					continue # the door
				var col: Color = palette[rng.randi() % palette.size()]
				box(Transform3D(basis, c + Vector3(0.0, (j + 0.5) * ch, 0.0) + dir * u + out * (half - thick * 0.5)), Vector3(bw, ch * 0.97, thick), col, _growth(0.25 + 0.15 * j), 0.07, 0.04)
		if rng.randf() < ivy_chance:
			ivy(c + Vector3(0.0, courses * ch, 0.0) + dir * rng.randf_range(-length * 0.3, length * 0.3) + out * (half + 0.1), out, rng.randf_range(1.5, 3.0))


## A light in a tomb (the moss-glow teal; always on).
func _glow(p: Vector3, col: Color, range_m: float, energy: float) -> void:
	_lights.append([p, col, range_m, energy])


## A stone lamp standing on the floor at `p` (local): a squat stand and a
## dish of fat on it. Its flame and lamp-gold light come on only while the
## ruin's hearth burns (Mike, 2 Oct: "light in the mausoleum, pyramid,
## barrow that activates after the main hearth is rekindled").
func _lamp(p: Vector3, range_m: float, energy: float) -> void:
	var was := solid
	solid = false
	box(Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.32, 0.0)), Vector3(0.26, 0.64, 0.26), palette[1], 0.0, 0.05, 0.02)
	box(Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.69, 0.0)), Vector3(0.44, 0.1, 0.44), palette[0].darkened(0.2), 0.0, 0.03, 0.01)
	solid = was
	_lamps.append([p + Vector3(0.0, 0.76, 0.0), range_m, energy])


## Things left with the dead round `c` (on the floor at c.y): clay urns,
## bones and a skull, and a glint of gold. Only the things over ~30 cm
## collide (the urns, round like boulders, and the long bones); the skull
## and the gold don't.
func _grave_goods(c: Vector3, spread: float, count: int) -> void:
	var was_shade := shade
	shade = 0.0 # the gold should still glint
	for i in count:
		var p := c + Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
		match rng.randi() % 4:
			0:
				# Urns 60 and 40 cm tall.
				boulder(p + Vector3(0.0, 0.28, 0.0), Vector3(0.2, 0.3, 0.2), Basis.IDENTITY, CLAY, 0.0)
				if rng.randf() < 0.5:
					boulder(p + Vector3(0.45, 0.2, 0.1), Vector3(0.14, 0.2, 0.14), Basis.IDENTITY, CLAY.darkened(0.1), 0.0)
			1:
				# Bones 45 cm long (thin enough to step over).
				for k in 3:
					box(Transform3D(Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), p + Vector3(rng.randf_range(-0.3, 0.3), 0.04, rng.randf_range(-0.3, 0.3))), Vector3(0.45, 0.06, 0.06), BONE, 0.0, 0.02, 0.01)
			2:
				solid = false
				boulder(p + Vector3(0.0, 0.1, 0.0), Vector3(0.11, 0.1, 0.13), Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), BONE, 0.0)
				solid = true
			_:
				solid = false
				for k in 4:
					box(Transform3D(Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), p + Vector3(rng.randf_range(-0.2, 0.2), 0.02 + k * 0.03, rng.randf_range(-0.2, 0.2))), Vector3(0.12, 0.025, 0.12), GOLD, 0.0, 0.01, 0.005)
				solid = true
	shade = was_shade


## A stone coffin at `p` (on the floor), long along `yaw`, its lid
## pushed askew.
func _sarcophagus(p: Vector3, yaw: float, col: Color) -> void:
	box(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0.0, 0.45, 0.0)), Vector3(0.95, 0.9, 2.2), col.darkened(0.05), _growth(0.15), 0.08, 0.02)
	var lid := Basis(Vector3.UP, yaw + rng.randf_range(-0.25, 0.25))
	box(Transform3D(lid, p + Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.2, 0.2))), Vector3(1.05, 0.2, 2.3), col.lightened(0.05), _growth(0.2), 0.06, 0.02)


## A temple house on the top platform (floor at `y`), centered `zc` back
## from the stair, its door toward it, a roof comb above; `fallen` leaves
## broken walls and the roof in pieces on the floor.
func _shrine(y: float, zc: float, fallen: bool) -> void:
	var hx := 3.4
	var hz := 2.4
	var courses := 4
	var ch := 0.8
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, y + 0.25, zc)), Vector3(hx * 2.0 + 1.2, 0.5, hz * 2.0 + 1.2), palette[0], _growth(0.6))
	var yb := y + 0.5
	_house_walls(Vector3(0.0, yb, zc), hx, hz, courses, ch, 0.7, 0.75, 3, 0.0 if fallen else 1.0, 0.0 if fallen else 0.7)
	var roof_y := yb + courses * ch
	if not fallen:
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, roof_y + 0.25, zc)), Vector3(hx * 2.0 + 0.6, 0.5, hz * 2.0 + 0.6), palette[1], _growth(0.8))
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, roof_y + 1.6, zc + 0.3)), Vector3(hx * 1.5, 2.2, 0.5), palette[2], _growth(0.5))
		ivy(Vector3(rng.randf_range(-1.5, 1.5), roof_y + 2.7, zc + 0.05), Vector3(0, 0, -1), rng.randf_range(1.5, 3.5))
		# An altar within, offerings round it, and a glow.
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, yb + 0.45, zc + 0.9)), Vector3(1.6, 0.9, 0.8), palette[3], _growth(0.4))
		_grave_goods(Vector3(0.0, yb, zc + 0.2), 1.3, 3)
		_glow(Vector3(0.0, yb + 2.0, zc), Color(0.45, 0.9, 0.75), 6.0, 0.24)
		_shelters.append([Vector3(0.0, yb, zc), 2.0, courses * ch])
	else:
		for i in rng.randi_range(3, 5):
			var p := Vector3(rng.randf_range(-hx, hx), yb + 0.3, zc + rng.randf_range(-hz, hz))
			box(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))), p), Vector3(rng.randf_range(1.2, 2.4), 0.5, rng.randf_range(0.8, 1.6)), palette[rng.randi() % palette.size()], _growth(0.8), 0.14, 0.08)


## A broken obelisk on the top platform (floor at `y`), an altar before
## it and broken pillars at the corners, the obelisk's tip lying fallen.
func _obelisk(y: float, top_hs: float) -> void:
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, y + 0.5, -1.6)), Vector3(2.4, 1.0, 1.4), palette[0], _growth(0.4))
	var w := 1.5
	var yy := y
	var parts := rng.randi_range(3, 5)
	for i in parts:
		var basis := Basis.IDENTITY
		if i == parts - 1:
			basis = Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)))
		box(Transform3D(basis, Vector3(0.0, yy + 0.95, 1.8)), Vector3(w, 1.9, w), palette[rng.randi() % palette.size()], _growth(0.3), 0.1, 0.05)
		yy += 1.9
		w *= 0.86
	box(Transform3D(Basis.from_euler(Vector3(0.0, rng.randf() * TAU, PI * 0.5)), Vector3(-top_hs * 0.45, y + w * 0.5, top_hs * 0.3)), Vector3(w, 2.4, w), palette[1], _growth(0.5), 0.12, 0.06)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var p := Vector2(cx, cz) * (top_hs - 1.3)
			for d in rng.randi_range(1, 3):
				box(Transform3D(Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), Vector3(p.x, y + 0.6 + d * 1.2, p.y)), Vector3(0.9, 1.15, 0.9), palette[rng.randi() % palette.size()], _growth(0.35), 0.1, 0.05)


# --- Graveyards and tombs -----------------------------------------------------

## A graveyard: a low stone wall round a square with a gate on -z (posts
## and capstones) and a breach or two, rows of graves facing the gate
## either side of a path up the middle,
## dead trees, and a mausoleum at the back. Headstones lean more in the
## marsh; the camp (if any) sits just inside the gate.
func _graveyard() -> void:
	var hm: float = site.half_m
	var style: String = site.style
	if style == "desert":
		palette = SANDSTONE
	var c := [Vector2(-hm, -hm), Vector2(hm, -hm), Vector2(hm, hm), Vector2(-hm, hm)]
	var wall_h := rng.randf_range(1.1, 1.5)
	wall(c[0], Vector2(-1.8, -hm), wall_h, 0.6, [], 0.3)
	wall(Vector2(1.8, -hm), c[1], wall_h, 0.6, [], 0.3)
	for i in range(1, 4):
		var br: Array = []
		if rng.randf() < 0.6:
			var s0 := rng.randf_range(0.1, 0.6)
			br.append([s0, s0 + rng.randf_range(0.15, 0.3)])
		wall(c[i], c[(i + 1) % 4], wall_h, 0.6, br, 0.35)
	for sx: float in [-1.0, 1.0]:
		var gp := Vector2(sx * 2.1, -hm)
		var g := ground(gp.x, gp.y)
		box(Transform3D(Basis.IDENTITY, Vector3(gp.x, g + 0.9, gp.y)), Vector3(0.8, 2.6, 0.8), palette[1], _growth(0.4))
		box(Transform3D(Basis.IDENTITY, Vector3(gp.x, g + 2.3, gp.y)), Vector3(1.0, 0.25, 1.0), palette[2], _growth(0.7))
	var tilt := 0.35 if style == "marsh" else 0.12
	var z := -hm + 8.0
	while z < hm - 9.0:
		var x := -hm + 2.2
		while x < hm - 2.0:
			# A path up the middle from the gate to the mausoleum.
			if absf(x) > 1.4 and rng.randf() < 0.78:
				_grave(Vector2(x + rng.randf_range(-0.2, 0.2), z), tilt, style == "snow")
			x += rng.randf_range(1.7, 2.1)
		z += 2.5
	for i in rng.randi_range(1, 3):
		# Along the side walls, clear of the gate, the camp and the mausoleum.
		var a := (0.0 if rng.randf() < 0.5 else PI) + rng.randf_range(-0.8, 0.8)
		_dead_tree(Vector2(cos(a) * hm * rng.randf_range(0.72, 0.85), sin(a) * hm * 0.5 - hm * 0.1))
	_mausoleum(Vector2(0.0, hm - 4.5), rng.randf_range(2.4, 3.0), rng.randf_range(2.8, 3.4))
	_camp_spot = Vector3(0.0, ground(0.0, -hm + 4.5), -hm + 4.5)


## One grave at `p`: a headstone at its head (+z) facing the gate, a slab,
## a shouldered slab, a cross or a little obelisk, leaning up to `tilt`,
## or fallen flat; and usually a low mound (snowed over in snow country).
func _grave(p: Vector2, tilt: float, snowy: bool) -> void:
	var g := ground(p.x, p.y)
	var col: Color = (palette[rng.randi() % palette.size()] as Color).lightened(rng.randf_range(-0.05, 0.08))
	var lean := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf_range(-0.08, 0.08), rng.randf_range(-tilt, tilt) * 0.6))
	var stone := Vector3(p.x, g - 0.15, p.y + 0.9)
	var moss := _growth(0.45)
	match rng.randi() % 6:
		0, 1:
			box(Transform3D(lean, stone + lean * Vector3(0.0, 0.55, 0.0)), Vector3(0.7, 1.1, 0.16), col, moss, 0.05, 0.03)
		2:
			box(Transform3D(lean, stone + lean * Vector3(0.0, 0.5, 0.0)), Vector3(0.72, 0.95, 0.17), col, moss, 0.05, 0.03)
			box(Transform3D(lean, stone + lean * Vector3(0.0, 1.05, 0.0)), Vector3(0.44, 0.2, 0.17), col, moss, 0.05, 0.02)
		3:
			box(Transform3D(lean, stone + lean * Vector3(0.0, 0.7, 0.0)), Vector3(0.18, 1.4, 0.16), col, moss, 0.04, 0.02)
			box(Transform3D(lean, stone + lean * Vector3(0.0, 1.0, 0.0)), Vector3(0.7, 0.18, 0.16), col, moss, 0.04, 0.02)
		4:
			box(Transform3D(Basis.IDENTITY, stone + Vector3(0.0, 0.3, 0.0)), Vector3(0.6, 0.4, 0.6), col, moss, 0.05, 0.02)
			box(Transform3D(lean, stone + Vector3(0.0, 0.5, 0.0) + lean * Vector3(0.0, 0.75, 0.0)), Vector3(0.28, 1.5, 0.28), col, moss, 0.05, 0.02)
		_:
			box(Transform3D(Basis.from_euler(Vector3(PI * 0.5 + rng.randf_range(-0.1, 0.1), rng.randf_range(-0.3, 0.3), 0.0)), stone + Vector3(rng.randf_range(-0.2, 0.2), 0.23, -0.4)), Vector3(0.7, 1.1, 0.16), col, moss, 0.05, 0.03)
	if rng.randf() < 0.7:
		var earth := EARTH.lerp(TerrainChunk._biome_blend(map, up), 0.5)
		if snowy:
			earth = SNOW
			mat = SNOW_M
		solid = false
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)), Vector3(p.x, g + 0.02, p.y - 0.1))
		box(xf, Vector3(0.9, 0.34, 1.8), earth, 0.0 if snowy else _growth(0.6), 0.16, 0.06)
		solid = true
		mat = STONE_M
		_mound_hull(xf)


## Collision for a grave mound (a 0.9 x 0.34 x 1.8 m box placed by `xf`,
## half sunk): a low hull whose sides slope at 40 degrees from a top a
## little inside the drawn one, so it sits within a few cm of the mound
## and you walk over it (a straight 19 cm step would stop you) instead of
## through it.
func _mound_hull(xf: Transform3D) -> void:
	var slope := 1.0 / tan(deg_to_rad(40.0))
	var pts := PackedVector3Array()
	for y: float in [0.17, -0.17]:
		var grow := (0.17 - y) * slope
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				pts.append(xf * Vector3(sx * (0.3 + grow), y, sz * (0.75 + grow)))
	_ch.append(pts)


## A bare, twisted dead tree: a leaning trunk and a few crooked limbs.
func _dead_tree(p: Vector2) -> void:
	mat = WOOD_M
	var g := ground(p.x, p.y)
	var base := Vector3(p.x, g - 0.4, p.y)
	var top := base + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(3.5, 5.5), rng.randf_range(-0.6, 0.6))
	_limb(base, top, 0.42)
	for i in rng.randi_range(3, 5):
		var from := base.lerp(top, rng.randf_range(0.55, 1.0))
		var a := rng.randf() * TAU
		var end := from + Vector3(cos(a), rng.randf_range(0.3, 0.9), sin(a)).normalized() * rng.randf_range(1.4, 2.6)
		_limb(from, end, 0.18)
		for j in 2:
			var a2 := a + rng.randf_range(-0.9, 0.9)
			_limb(end, end + Vector3(cos(a2), rng.randf_range(0.2, 0.8), sin(a2)).normalized() * rng.randf_range(0.6, 1.2), 0.08)
	mat = STONE_M


## A mausoleum centered at `c`, `hx` by `hz` (half, outside): a stone
## house of the dead on a plinth, its door to the gate (-z) with steps up,
## a gabled roof of two slabs over pediments, a sarcophagus within, the
## dead's goods about it and a faint glow.
func _mausoleum(c: Vector2, hx: float, hz: float) -> void:
	var gr := _ground_range(c, maxf(hx, hz))
	var floor_y := gr.y + 0.25
	var base_y := gr.x - 0.6
	box(Transform3D(Basis.IDENTITY, Vector3(c.x, (floor_y + base_y) * 0.5, c.y)), Vector3(hx * 2.0 + 0.8, floor_y - base_y, hz * 2.0 + 0.8), palette[0], _growth(0.3), 0.1, 0.03)
	_door_steps(c.x, c.y - hz - 0.4, floor_y, 1.8)
	var courses := 4
	var ch := 0.8
	_house_walls(Vector3(c.x, floor_y, c.y), hx, hz, courses, ch, 0.6, 0.75, 3, 0.92)
	# The roof: two slabs pitched from a ridge along z, over pediments.
	var wt := floor_y + courses * ch
	var pitch := 0.45
	var span := hx + 0.5
	for sx: float in [-1.0, 1.0]:
		var b := Basis(Vector3(0, 0, 1), -sx * pitch)
		box(Transform3D(b, Vector3(c.x + sx * span * 0.5, wt + tan(pitch) * span * 0.5 + 0.12, c.y)), Vector3(span / cos(pitch) + 0.1, 0.28, hz * 2.0 + 0.6), palette[1], _growth(0.7), 0.06, 0.03)
	var start := _v.size()
	var peak := wt + tan(pitch) * hx
	var gable: Color = palette[2]
	gable.a = _growth(0.2)
	for sz: float in [-1.0, 1.0]:
		var zz := c.y + sz * (hz - 0.05)
		var t0 := Vector3(c.x - hx, wt, zz)
		var t1 := Vector3(c.x + hx, wt, zz)
		var t2 := Vector3(c.x, peak, zz)
		if (t1 - t0).cross(t2 - t0).z * sz > 0.0:
			_tri(t0, t1, t2, gable)
		else:
			_tri(t0, t2, t1, gable)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	_sarcophagus(Vector3(c.x, floor_y, c.y + hz * 0.2), 0.0, palette[3])
	_grave_goods(Vector3(c.x, floor_y, c.y - hz * 0.3), maxf(hx - 1.2, 0.5), 3)
	_glow(Vector3(c.x, floor_y + 2.0, c.y), Color(0.45, 0.85, 0.8), 6.0, 0.21)
	for sx: float in [-1.0, 1.0]:
		_lamp(Vector3(c.x + sx * (hx - 1.0), floor_y, c.y + hz - 1.0), 6.0, 0.18)
	_shelters.append([Vector3(c.x, floor_y, c.y), minf(hx, hz), courses * ch])


## A barrow: a long earth mound, highest at its front (-z) where a
## dry-stone facade stands with a portal of two uprights and a lintel and
## standing stones before it. Inside, a passage of upright slabs roofed
## with capstones runs in past two pairs of side cells to an end chamber,
## the dead's goods in each and a glow at the end. In the desert, a
## mastaba instead.
func _barrow() -> void:
	var style: String = site.style
	if style == "desert":
		palette = SANDSTONE
		_mastaba()
		return
	var w: float = site.half_w
	var l: float = site.half_l
	var h: float = site.height_m
	var snowy := style == "snow"
	var ph := rng.randf() * TAU
	var hf := func(x: float, z: float) -> float:
		var prof := pow(maxf(0.0, 1.0 - (x / w) * (x / w)), 0.6)
		var along := lerpf(1.0, 0.7, (z + l) / (2.0 * l)) * sqrt(clampf((l - z) / 3.0, 0.0, 1.0))
		return ground(x, z) - 1.0 + ((h + 1.0) + 0.2 * sin(x * 1.3 + ph) * sin(z * 0.8 + ph)) * prof * along
	# The mound: turf (the grass texture), earthier toward the foot.
	var turf := TerrainChunk._biome_blend(map, up).lerp(GRASS, 0.2)
	if snowy:
		turf = SNOW
	var soil := turf.darkened(0.25).lerp(EARTH, 0.35)
	turf.a = 0.0 if snowy else 0.1
	soil.a = 0.0
	mat = SNOW_M if snowy else THATCH_M
	var nx := 12
	var nz := 16
	var pts: Array[Vector3] = []
	for j in nz + 1:
		var z := -l + 2.0 * l * j / nz
		for i in nx + 1:
			var x := -w + 2.0 * w * i / nx
			pts.append(Vector3(x, hf.call(x, z), z))
	var start := _v.size()
	for j in nz:
		for i in nx:
			var a := pts[j * (nx + 1) + i]
			var b := pts[j * (nx + 1) + i + 1]
			var c := pts[(j + 1) * (nx + 1) + i + 1]
			var d := pts[(j + 1) * (nx + 1) + i]
			var mid := (a + b + c + d) * 0.25
			var prof := pow(maxf(0.0, 1.0 - (mid.x / w) * (mid.x / w)), 0.6)
			_face(a, b, c, d, soil.lerp(turf, smoothstep(0.0, 0.5, prof)), mid - Vector3(0.0, 3.0, 0.0))
	_smooth_from(start)
	_collide_since(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	mat = STONE_M
	# The facade across the mound's open front, up to its outline.
	var z0 := -l
	var gd := ground(0.0, z0)
	var cols := int(ceil(2.0 * w / 1.1))
	var cw := 2.0 * w / cols
	for i in cols:
		var x := -w + (i + 0.5) * cw
		var g := ground(x, z0)
		var top: float = hf.call(x, z0) + 0.25
		var y := g - 0.6
		while y < top - 0.15:
			var chh := minf(0.55, top - y)
			if not (absf(x) < 1.25 and y + chh * 0.5 < gd + 2.3):
				var col: Color = (palette[rng.randi() % palette.size()] as Color).lightened(rng.randf_range(-0.05, 0.05))
				box(Transform3D(Basis.IDENTITY, Vector3(x, y + chh * 0.5, z0 - 0.35)), Vector3(cw, chh * 0.97, 0.9), col, _growth(0.3 + (0.4 if y + chh >= top - 0.3 else 0.0)), 0.07, 0.04)
			y += chh
	# The portal: two uprights and a lintel.
	for sx: float in [-1.0, 1.0]:
		box(Transform3D(Basis.IDENTITY, Vector3(sx * 1.25, gd + 1.0, z0 - 0.45)), Vector3(0.9, 2.9, 1.2), palette[1], _growth(0.4), 0.12, 0.05)
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, gd + 2.7, z0 - 0.4)), Vector3(3.6, 0.6, 1.3), palette[2], _growth(0.6), 0.12, 0.05)
	# Standing stones before it.
	for sx: float in [-1.0, 1.0]:
		for k in 2:
			if rng.randf() < 0.3:
				continue
			var x := sx * (2.6 + k * 1.8 + rng.randf_range(-0.3, 0.3))
			var zz := z0 - 1.4 - k * 0.8
			var hh := rng.randf_range(2.2, 3.6) * (1.0 - 0.25 * k)
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.1)))
			box(Transform3D(tilt, Vector3(x, ground(x, zz) + hh * 0.5 - 0.5, zz)), Vector3(rng.randf_range(0.9, 1.3), hh, rng.randf_range(0.5, 0.8)), palette[rng.randi() % palette.size()], _growth(0.5), 0.2, 0.12)
	if Delves.has_delve(site):
		_delve_build()
	else:
		_barrow_passage(l)
	_camp_spot = Vector3(w + 5.0, ground(w + 5.0, -l + 3.0), -l + 3.0)


## The barrow's inside: a passage 1.6 m wide from the portal along +z,
## side cells opening off it left and right twice, an end chamber, all
## upright slabs under capstones on the natural floor.
func _barrow_passage(l: float) -> void:
	shade = 0.45
	var z0 := -l
	var z1 := -l + 2.0 * l * 0.28
	var z2 := -l + 2.0 * l * 0.45
	var ze := -l + 2.0 * l * 0.62
	var t := 0.55 # slab thickness
	var wx := 0.8 + t * 0.5 # passage wall line
	for sx: float in [-1.0, 1.0]:
		for seg in [[z0, z1 - 0.8], [z1 + 0.8, z2 - 0.8], [z2 + 0.8, ze]]:
			_slabs(Vector2(sx * wx, seg[0]), Vector2(sx * wx, seg[1]))
		for zc: float in [z1, z2]:
			var bx := sx * (2.8 + t * 0.5)
			_slabs(Vector2(bx, zc - 0.8 - t), Vector2(bx, zc + 0.8 + t))
			for sz: float in [-1.0, 1.0]:
				_slabs(Vector2(sx * (0.8 + t), zc + sz * (0.8 + t * 0.5)), Vector2(bx, zc + sz * (0.8 + t * 0.5)))
			_capstone(Vector2(sx * 1.8, zc), Vector2(2.9, 2.5))
			_grave_goods(Vector3(sx * 1.9, ground(sx * 1.9, zc), zc), 0.5, 2)
		# The end chamber's side and the front walls beside the passage.
		_slabs(Vector2(sx * (1.8 + t * 0.5), ze), Vector2(sx * (1.8 + t * 0.5), ze + 3.2))
		_slabs(Vector2(sx * (0.8 + t), ze - t * 0.5), Vector2(sx * (1.8 + t), ze - t * 0.5))
	_slabs(Vector2(-1.8 - t, ze + 3.2 + t * 0.5), Vector2(1.8 + t, ze + 3.2 + t * 0.5))
	var z := z0 + 0.3
	while z < ze:
		_capstone(Vector2(0.0, z + 0.65), Vector2(2.9, 1.4))
		z += 1.3
	_capstone(Vector2(0.0, ze + 0.8), Vector2(4.6, 1.8))
	_capstone(Vector2(0.0, ze + 2.4), Vector2(4.6, 1.8))
	var gc := ground(0.0, ze + 1.6)
	_sarcophagus(Vector3(0.0, gc - 0.1, ze + 1.9), PI * 0.5, palette[3])
	_grave_goods(Vector3(0.0, gc, ze + 0.8), 1.2, 4)
	for sx: float in [-1.0, 1.0]:
		_lamp(Vector3(sx * 1.35, ground(sx * 1.35, ze + 2.8), ze + 2.8), 6.5, 0.17)
	_glow(Vector3(0.0, ground(0.0, (z0 + ze) * 0.5) + 1.8, (z0 + ze) * 0.5), Color(0.45, 0.85, 0.8), 5.0, 0.12)
	var zs := z0 + 1.0
	while zs < ze + 3.0:
		_shelters.append([Vector3(0.0, ground(0.0, zs), zs), 1.2, 2.2])
		zs += 1.6
	shade = 0.0



# --- Delves (design 1 Oct §CJ; Delves) ---------------------------------------------

## The inside of a barrow with a delve under it (Delves.layout): the
## portal's slab passage with one pair of side cells, the end chamber as
## the stairhead, and below, the stair, the first room, the second stair,
## the heart, the way up and the cairn it comes out in. Every floor paved.
func _delve_build() -> void:
	var lay: Dictionary = Delves.layout(map, site)
	_delve = lay
	_delve_off = base_e - float(lay.base_e)
	var off := _delve_off
	var l: float = site.half_l
	var t := 0.55
	var zc: float = lay.zc
	var zb := zc + 3.4
	var z_s1: float = lay.z_s1
	var zs := -l + 2.6
	var z0 := -l
	shade = 0.45
	for sx: float in [-1.0, 1.0]:
		var wx := 0.8 + t * 0.5
		_slabs(Vector2(sx * wx, z0), Vector2(sx * wx, zs - 0.8))
		_slabs(Vector2(sx * wx, zs + 0.8), Vector2(sx * wx, zc - t * 0.5))
		var bx := sx * (2.8 + t * 0.5)
		_slabs(Vector2(bx, zs - 0.8 - t), Vector2(bx, zs + 0.8 + t))
		for sz: float in [-1.0, 1.0]:
			_slabs(Vector2(sx * (0.8 + t), zs + sz * (0.8 + t * 0.5)), Vector2(bx, zs + sz * (0.8 + t * 0.5)))
		_capstone(Vector2(sx * 1.8, zs), Vector2(2.9, 2.5))
		_grave_goods(Vector3(sx * 1.9, ground(sx * 1.9, zs) + 0.03, zs), 0.5, 2)
		# The chamber's sides, its front walls beside the passage, its back
		# wall beside the stair.
		_slabs(Vector2(sx * (1.9 + t * 0.5), zc), Vector2(sx * (1.9 + t * 0.5), zb))
		_slabs(Vector2(sx * (0.8 + t), zc - t * 0.5), Vector2(sx * (1.9 + t), zc - t * 0.5))
		_slabs(Vector2(sx * 1.25, zb + t * 0.5), Vector2(sx * (1.9 + t), zb + t * 0.5))
		_grave_goods(Vector3(sx * 1.4, ground(sx * 1.4, zc + 0.7) + 0.03, zc + 0.7), 0.4, 2)
		# The lamps (lit while the barrow's hearth burns).
		_lamp(Vector3(sx * 1.35, ground(sx * 1.35, zb - 0.6) + 0.03, zb - 0.6), 6.5, 0.17)
	var z := z0 + 0.3
	while z < zc - 0.6:
		_capstone(Vector2(0.0, z + 0.65), Vector2(2.9, 1.4))
		z += 1.3
	_capstone(Vector2(0.0, zc + 0.85), Vector2(4.8, 1.8))
	_capstone(Vector2(0.0, zc + 2.55), Vector2(4.8, 1.8))
	# The back wall's lintel over the stair.
	var stair1: Dictionary = lay.pieces[0]
	var a_back := zb + t - z_s1
	var lint_bot: float = Delves.floor_of(stair1, a_back) + Delves.H_STAIR - off
	var lint_top := ground(0.0, zb) + 2.2
	if lint_top > lint_bot + 0.2:
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, (lint_bot + lint_top) * 0.5, zb + t * 0.5)), Vector3(2.6, lint_top - lint_bot, t), palette[2], 0.0, 0.08, 0.03)
	# The floors: the passage, the cells, the chamber round the stairwell.
	_pave(Rect2(-0.8, z0 + 0.1, 1.6, zc - z0 - 0.1), NAN)
	for sx: float in [-1.0, 1.0]:
		_pave(Rect2(minf(sx * 0.8, sx * 2.8), zs - 0.8, 2.0, 1.6), NAN)
		_pave(Rect2(minf(sx * 0.85, sx * 1.9), zc, 1.05, zb - zc), NAN)
	_pave(Rect2(-0.85, zc, 1.7, z_s1 - zc), NAN)
	var zz := z0 + 1.0
	while zz < zb:
		_shelters.append([Vector3(0.0, ground(0.0, zz), zz), 1.2, 2.2])
		zz += 1.6
	# Below: no baked shade (the dark is the light's absence there; the
	# torch should find the stone, not a stone painted dark).
	shade = 0.0
	_delve_from = _v.size()
	var pieces: Array = lay.pieces
	var s2: float = lay.s2
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		var nxt: Dictionary = pieces[i + 1] if i + 1 < pieces.size() else {}
		match str(pc.kind):
			"stair":
				_delve_stair(pc, off, i == 0, a_back, float(lay.y_t))
			"exit":
				_delve_stair(pc, off, false, 0.0, 0.0)
			"room", "heart", "cairn":
				var opens: Array = []
				# Where the piece before it comes in, and the next goes out.
				var prev: Dictionary = pieces[i - 1]
				opens.append(_opening(pc, Delves.rect_of(prev).get_center() if str(prev.kind) != "stair" else (prev.c as Vector2) + (prev.dir as Vector2) * float(prev.len), float(prev.half)))
				if not nxt.is_empty():
					opens.append(_opening(pc, nxt.c, float(nxt.half)))
				_delve_room(pc, off, opens)
	_delve_dress(lay, off)
	_delve_to = _v.size()
	if not (lay.cairn as Dictionary).is_empty():
		_cairn(lay, off)
	shade = 0.0


## Which wall of room `pc` the point `p` (where a joining piece meets it)
## is on, as [side ("start", "end", "left", "right"), offset along the
## wall, half width of the gap].
func _opening(pc: Dictionary, p: Vector2, half: float) -> Array:
	var aa := Delves.along_across(pc, p)
	var length := float(pc.len)
	if aa.x <= 0.2:
		return ["start", aa.y, half]
	if aa.x >= length - 0.2:
		return ["end", aa.y, half]
	return ["left" if aa.y > 0.0 else "right", aa.x, half]


## A point of piece `pc` (along, across) in this frame's x/z.
static func _pp(pc: Dictionary, along: float, across: float) -> Vector2:
	return (pc.c as Vector2) + (pc.dir as Vector2) * along + Delves.perp(pc.dir) * across


## A run of wall (dry-stone blocks, collision) from a to b (x/z), from
## y_bot to y_top, `thick` thick.
func _dwall(a: Vector2, b: Vector2, y_bot: float, y_top: float, thick: float = 0.6) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.15 or y_top <= y_bot + 0.05:
		return
	var n := maxi(1, int(ceil(length / 1.3)))
	var dir := Vector3(along.x, 0.0, along.y) / length
	var bs := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	for i in n:
		var p := a + along * (i + 0.5) / n
		var col: Color = (palette[rng.randi() % palette.size()] as Color).darkened(rng.randf_range(0.0, 0.1))
		box(Transform3D(bs, Vector3(p.x, (y_bot + y_top) * 0.5, p.y)), Vector3(length / n + 0.04, y_top - y_bot, thick), col, _growth(0.1), 0.07, 0.04)


## A wall with gaps: from along a0 to a1 on a line, leaving [centre,
## half] gaps (gaps as offsets along the same line).
func _dwall_gaps(pc: Dictionary, side_across: float, a0: float, a1: float, gaps: Array, y_bot: float, y_top: float, along_axis: bool) -> void:
	var cuts: Array = [[a0, a1]]
	for g in gaps:
		var out: Array = []
		for c in cuts:
			var lo: float = c[0]
			var hi: float = c[1]
			var g0: float = float(g[0]) - float(g[1])
			var g1: float = float(g[0]) + float(g[1])
			if g1 <= lo or g0 >= hi:
				out.append(c)
				continue
			if g0 > lo:
				out.append([lo, g0])
			if g1 < hi:
				out.append([g1, hi])
		cuts = out
	for c in cuts:
		var p0: Vector2
		var p1: Vector2
		if along_axis:
			p0 = _pp(pc, c[0], side_across)
			p1 = _pp(pc, c[1], side_across)
		else:
			p0 = _pp(pc, side_across, c[0])
			p1 = _pp(pc, side_across, c[1])
		_dwall(p0, p1, y_bot, y_top)


## A room (the first room, the heart, the cairn's chamber): paved floor,
## four walls with the gaps in `opens`, a ceiling of slabs.
func _delve_room(pc: Dictionary, off: float, opens: Array, skip := Rect2()) -> void:
	var y := float(pc.y0) - off
	var h := float(pc.h)
	var half := float(pc.half)
	var length := float(pc.len)
	var hw := half + Delves.WALL * 0.5
	var gaps := {"start": [], "end": [], "left": [], "right": []}
	for o in opens:
		(gaps[o[0]] as Array).append([o[1], float(o[2]) + 0.05])
	var top := y + h + Delves.SLAB
	_dwall_gaps(pc, hw, -Delves.WALL, length + Delves.WALL, gaps.left, y - 0.6, top, true)
	_dwall_gaps(pc, -hw, -Delves.WALL, length + Delves.WALL, gaps.right, y - 0.6, top, true)
	_dwall_gaps(pc, -Delves.WALL * 0.5, -half, half, gaps.start, y - 0.6, top, false)
	_dwall_gaps(pc, length + Delves.WALL * 0.5, -half, half, gaps.end, y - 0.6, top, false)
	# Lintels over the gaps.
	for side in gaps:
		for g in gaps[side]:
			var c := float(g[0])
			var gh := float(g[1])
			var p0: Vector2
			var p1: Vector2
			match side:
				"start":
					p0 = _pp(pc, -Delves.WALL * 0.5, c - gh)
					p1 = _pp(pc, -Delves.WALL * 0.5, c + gh)
				"end":
					p0 = _pp(pc, length + Delves.WALL * 0.5, c - gh)
					p1 = _pp(pc, length + Delves.WALL * 0.5, c + gh)
				_:
					var sa := hw if side == "left" else -hw
					p0 = _pp(pc, c - gh, sa)
					p1 = _pp(pc, c + gh, sa)
			_dwall(p0, p1, y + Delves.H_STAIR + 0.1, top)
	# The ceiling (ochre in the heart, §BQ: "ochre on the ceiling").
	var ochre := str(pc.kind) == "heart"
	var n := maxi(1, int(ceil(length / 1.5)))
	for i in n:
		var a0 := length * i / n
		var a1 := length * (i + 1) / n
		var mid := _pp(pc, (a0 + a1) * 0.5, 0.0)
		var col: Color = palette[rng.randi() % palette.size()]
		if ochre:
			col = col.lerp(Color(0.62, 0.3, 0.14), 0.55)
		var d3 := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y)
		var bs := Basis(Delves.perp(pc.dir).x * Vector3.RIGHT + Delves.perp(pc.dir).y * Vector3.BACK, Vector3.UP, d3)
		box(Transform3D(bs.orthonormalized(), Vector3(mid.x, y + h + Delves.SLAB * 0.5, mid.y)), Vector3(2.0 * (half + Delves.WALL) + 0.1, Delves.SLAB, a1 - a0 + 0.05), col.darkened(0.1), 0.0, 0.08, 0.03)
	_pave_piece(pc, off, skip)


## The paving of a flat piece.
func _pave_piece(pc: Dictionary, off: float, skip := Rect2()) -> void:
	var r := Delves.rect_of(pc, 0.05)
	_pave(r, float(pc.y0) - off, skip)


## Flagstones over `r` (x/z), their tops at `y` (NAN: on the ground at
## each), with collision.
func _pave(r: Rect2, y: float, skip := Rect2()) -> void:
	var nx := maxi(1, int(ceil(r.size.x / 1.1)))
	var nz := maxi(1, int(ceil(r.size.y / 1.1)))
	var sx := r.size.x / nx
	var sz := r.size.y / nz
	var was := shade
	shade = maxf(shade, 0.1)
	for j in nz:
		for i in nx:
			var cx := r.position.x + (i + 0.5) * sx
			var cz := r.position.y + (j + 0.5) * sz
			# A stairwell left open (the crag's last flight, §DO).
			if skip.has_area() and skip.has_point(Vector2(cx, cz)):
				continue
			var top := y
			var depth := 0.3
			if is_nan(y):
				# On the ground: the flag's top at its patch's highest point,
				# deep enough to meet its lowest (the ground never shows
				# through, nor a gap under it).
				var hi := -INF
				var lo := INF
				for dx: float in [-0.5, 0.0, 0.5]:
					for dz: float in [-0.5, 0.0, 0.5]:
						var g := ground(cx + dx * sx, cz + dz * sz)
						hi = maxf(hi, g)
						lo = minf(lo, g)
				top = hi + 0.04
				depth = top - lo + 0.25
			var col: Color = (palette[rng.randi() % palette.size()] as Color).darkened(rng.randf_range(0.0, 0.12))
			box(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.02, 0.02)), Vector3(cx, top - depth * 0.5, cz)), Vector3(sx + 0.02, depth, sz + 0.02), col, _growth(0.05), 0.04, 0.02)
	shade = was


## A stair (down into the delve, or the way up): steps over a ramp, walls
## each side and a stepped ceiling. `first`: the barrow's stairhead, open
## (no ceiling, low walls) until `open_to` along it where it passes under
## the chamber's back wall (`floor_top`: the chamber's floor).
func _delve_stair(pc: Dictionary, off: float, first: bool, open_to: float, floor_top: float) -> void:
	var length := float(pc.len)
	var half := float(pc.half)
	var h := float(pc.h)
	var y0 := float(pc.y0) - off
	var y1 := float(pc.y1) - off
	var hw := half + Delves.WALL * 0.5
	var seg := 1.2
	var a := 0.0
	while a < length - 0.01:
		var b := minf(a + seg, length)
		var fa := lerpf(y0, y1, a / length)
		var fb := lerpf(y0, y1, b / length)
		var lo := minf(fa, fb)
		var hi := maxf(fa, fb)
		var top := hi + h + Delves.SLAB + absf(fb - fa) + 0.3
		var open := first and b <= open_to
		if first and a < open_to:
			top = minf(top, floor_top - off + 0.04)
		for sd: float in [-1.0, 1.0]:
			_dwall(_pp(pc, a, sd * hw), _pp(pc, b, sd * hw), lo - 0.6, top)
		if not open and not (first and a < open_to):
			var mid := _pp(pc, (a + b) * 0.5, 0.0)
			var d3 := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y)
			var pv := Delves.perp(pc.dir)
			var bs := Basis(Vector3(pv.x, 0.0, pv.y), Vector3.UP, d3).orthonormalized()
			# Thick enough to overlap the next step's slab (no slit to the
			# void between them).
			var thick := Delves.SLAB + absf(fb - fa) + 0.3
			box(Transform3D(bs, Vector3(mid.x, hi + h + thick * 0.5, mid.y)), Vector3(2.0 * (half + Delves.WALL) + 0.1, thick, b - a + 0.06), (palette[rng.randi() % palette.size()] as Color).darkened(0.1), 0.0, 0.08, 0.03)
		a = b
	# The steps (drawn) and the ramp under them (walked on).
	var rise := absf(y1 - y0)
	var steps := maxi(3, int(round(rise / 0.3)))
	solid = false
	for k in steps:
		var a0 := length * k / steps
		var a1 := length * (k + 1) / steps
		var ytop := lerpf(y0, y1, (k + (0.0 if y1 < y0 else 1.0)) / steps)
		var mid := _pp(pc, (a0 + a1) * 0.5, 0.0)
		var d3 := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y)
		var pv := Delves.perp(pc.dir)
		var bs := Basis(Vector3(pv.x, 0.0, pv.y), Vector3.UP, d3).orthonormalized()
		var col: Color = (palette[rng.randi() % palette.size()] as Color).darkened(rng.randf_range(0.05, 0.2))
		box(Transform3D(bs, Vector3(mid.x, ytop - 0.25, mid.y)), Vector3(2.0 * half + 0.1, 0.5, a1 - a0 + 0.04), col, _growth(0.05), 0.04, 0.02)
	solid = true
	var lo_p := _pp(pc, length if y1 < y0 else 0.0, 0.0)
	var hi_p := _pp(pc, 0.0 if y1 < y0 else length, 0.0)
	_dramp(Vector3(lo_p.x, minf(y0, y1), lo_p.y), Vector3(hi_p.x, maxf(y0, y1), hi_p.y), 2.0 * half)


## A walkable slope (collision only) from `lo` up to `hi`, `w` wide, in
## any direction (RuinBuilder._ramp runs only along z).
func _dramp(lo: Vector3, hi: Vector3, w: float) -> void:
	var foot := lo - (hi - lo).normalized() * 0.6 - Vector3(0.0, 0.05, 0.0)
	var dirv := (hi - foot).normalized()
	var flat := Vector3(dirv.x, 0.0, dirv.z).normalized()
	var x := flat.cross(Vector3.UP).normalized()
	var nrm := dirv.cross(x)
	if nrm.y < 0.0:
		nrm = -nrm
		x = -x
	var length := foot.distance_to(hi)
	_collision_box(Transform3D(Basis(x, nrm, dirv), (foot + hi) * 0.5 - nrm * 0.5), Vector3(w * 0.5, 0.5, length * 0.5))


## What lies in the delve: the first room's feature, the heart's dead and
## their glow. (The find and the first room's hearth are laid in play:
## Delves, OldHearths.)
func _delve_dress(lay: Dictionary, off: float) -> void:
	var room: Dictionary = lay.pieces[1]
	var y := float(room.y0) - off
	var length := float(room.len)
	if str(lay.feature) == "niches":
		# Bone niches: shelves in both side walls, the dead's things on them.
		for sd: float in [-1.0, 1.0]:
			for k in 2:
				var a := length * (0.3 + 0.4 * k)
				var p := _pp(room, a, sd * (float(room.half) - 0.2))
				box(Transform3D(Basis.IDENTITY, Vector3(p.x, y + 1.05, p.y)), Vector3(0.6, 0.12, 1.1), palette[1], 0.0, 0.03, 0.01)
				_grave_goods(Vector3(p.x, y + 1.11, p.y), 0.25, 2)
	else:
		# A fallen slab and its rubble in a corner (the ceiling above holds).
		var sd := -float(lay.s2)
		var p := _pp(room, length * 0.8, sd * (float(room.half) - 0.9))
		box(Transform3D(Basis.from_euler(Vector3(0.5, 0.3, 0.2)), Vector3(p.x, y + 0.7, p.y)), Vector3(2.2, 0.4, 1.4), palette[2], 0.0, 0.1, 0.06)
		solid = false
		for k in 5:
			boulder(Vector3(p.x + rng.randf_range(-0.8, 0.8), y + 0.15, p.y + rng.randf_range(-0.8, 0.8)), Vector3(0.3, 0.2, 0.25), Basis(Vector3.UP, rng.randf() * TAU), palette[rng.randi() % palette.size()], 0.0)
		solid = true
	var heart: Dictionary = lay.pieces[3]
	var yh := float(heart.y0) - off
	var lh := float(heart.len)
	var sc := _pp(heart, lh * 0.62, 0.0)
	_sarcophagus(Vector3(sc.x, yh, sc.y), PI * 0.5, palette[3])
	var front := _pp(heart, lh * 0.3, 0.0)
	_grave_goods(Vector3(front.x, yh, front.y), 1.6, 6)
	_glow(Vector3(sc.x, yh + 2.6, sc.y - 1.0), Color(0.45, 0.85, 0.8), 7.0, 0.16)


## The cairn the way out comes up in: a small long cairn of turf and
## stone over the chamber and the holes round it, its dry-stone facade
## with the doorway (the slab is Delves'), and a paved forecourt over the
## ground's open quads before the door.
func _cairn(lay: Dictionary, off: float) -> void:
	var cairn: Dictionary = lay.cairn
	var o: Vector2 = cairn.o
	var dir: Vector2 = cairn.dir
	var pv := Delves.perp(dir)
	var back := float(cairn.back)
	var half := float(cairn.half)
	var h := float(cairn.h)
	var floor_y := float(cairn.floor) - off
	var ph := rng.randf() * TAU
	var at := func(u: float, v: float) -> Vector2:
		return o - dir * u + pv * v
	var hf := func(u: float, v: float) -> float:
		var p: Vector2 = at.call(u, v)
		var prof := pow(maxf(0.0, 1.0 - (v / half) * (v / half)), 0.6)
		var along := lerpf(1.0, 0.75, u / back) * sqrt(clampf((back - u) / 3.0, 0.0, 1.0))
		return ground(p.x, p.y) - 1.0 + ((h + 1.0) + 0.2 * sin(v * 1.3 + ph) * sin(u * 0.8 + ph)) * prof * along
	var turf := TerrainChunk._biome_blend(map, up).lerp(GRASS, 0.2)
	if str(site.get("style", "")) == "snow":
		turf = SNOW
	var soil := turf.darkened(0.25).lerp(EARTH, 0.35)
	turf.a = 0.1
	soil.a = 0.0
	var was_mat := mat
	mat = SNOW_M if str(site.get("style", "")) == "snow" else THATCH_M
	shade = 0.0
	var nu := 12
	var nv := 10
	var pts: Array[Vector3] = []
	for j in nu + 1:
		var u := back * j / nu
		for i in nv + 1:
			var v := -half + 2.0 * half * i / nv
			var p2: Vector2 = at.call(u, v)
			pts.append(Vector3(p2.x, hf.call(u, v), p2.y))
	var start := _v.size()
	for j in nu:
		for i in nv:
			var a := pts[j * (nv + 1) + i]
			var b := pts[j * (nv + 1) + i + 1]
			var c := pts[(j + 1) * (nv + 1) + i + 1]
			var d := pts[(j + 1) * (nv + 1) + i]
			var mid := (a + b + c + d) * 0.25
			_face(a, b, c, d, soil.lerp(turf, 0.7), mid - Vector3(0.0, 3.0, 0.0))
	_smooth_from(start)
	_collide_since(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	mat = was_mat
	# The facade across the cairn's open end, the doorway in it.
	var cols := int(ceil(2.0 * half / 1.1))
	var cw := 2.0 * half / cols
	var fbs := Basis(Vector3(pv.x, 0.0, pv.y), Vector3.UP, Vector3(dir.x, 0.0, dir.y)).orthonormalized()
	for i in cols:
		var v := -half + (i + 0.5) * cw
		var fp: Vector2 = at.call(-0.35, v)
		var g := ground(fp.x, fp.y)
		var top: float = hf.call(0.0, v) + 0.25
		var yy := minf(g, floor_y) - 0.6
		while yy < top - 0.15:
			var chh := minf(0.55, top - yy)
			if not (absf(v) < 1.1 and yy + chh * 0.5 < floor_y + 2.35):
				var col: Color = (palette[rng.randi() % palette.size()] as Color).lightened(rng.randf_range(-0.05, 0.05))
				box(Transform3D(fbs, Vector3(fp.x, yy + chh * 0.5, fp.y)), Vector3(cw, chh * 0.97, 0.9), col, _growth(0.3), 0.07, 0.04)
			yy += chh
	# Uprights and a lintel at the door.
	for sv: float in [-1.0, 1.0]:
		var up_p: Vector2 = at.call(-0.45, sv * 1.25)
		box(Transform3D(fbs, Vector3(up_p.x, floor_y + 1.0, up_p.y)), Vector3(0.9, 2.9, 1.2), palette[1], _growth(0.4), 0.12, 0.05)
	var lp: Vector2 = at.call(-0.4, 0.0)
	box(Transform3D(fbs, Vector3(lp.x, floor_y + 2.7, lp.y)), Vector3(3.6, 0.6, 1.3), palette[2], _growth(0.6), 0.12, 0.05)
	# The forecourt.
	shade = 0.0
	var fu0 := 0.6 # under the facade's foot, no seam
	var fu1 := Delves.QUAD_PAD + 1.0
	var c0: Vector2 = at.call(-fu0, -half + 1.0)
	var c1: Vector2 = at.call(-fu1, half - 1.0)
	_pave(Rect2(c0, Vector2.ZERO).expand(c1), NAN)
	_shelters.append([Vector3(o.x - dir.x * 1.8, floor_y, o.y - dir.y * 1.8), 1.6, 2.4])


## Upright slabs from a to b (local xz), up to 2.2 m above the ground
## (and down into it), each at most 1.4 m long.
func _slabs(a: Vector2, b: Vector2) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.2:
		return
	var n := maxi(1, int(ceil(length / 1.4)))
	var dir := Vector3(along.x, 0.0, along.y) / length
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	for i in n:
		var p := a + along * (i + 0.5) / n
		var g := ground(p.x, p.y)
		var col: Color = (palette[rng.randi() % palette.size()] as Color).darkened(rng.randf_range(0.0, 0.12))
		box(Transform3D(basis.rotated(Vector3.UP, rng.randf_range(-0.04, 0.04)), Vector3(p.x, g + 0.9, p.y)), Vector3(length / n + 0.05, 2.6, 0.55), col, _growth(0.2), 0.1, 0.05)


## A capstone roofing the barrow at `p`, `size` (x, z), on the walls'
## tops 2.2 m above the ground there.
func _capstone(p: Vector2, size: Vector2) -> void:
	var g := ground(p.x, p.y)
	box(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.03, 0.03))), Vector3(p.x, g + 2.42, p.y)), Vector3(size.x, 0.45, size.y), palette[rng.randi() % palette.size()], _growth(0.3), 0.14, 0.06)


## A mastaba (a desert tomb): a flat-roofed sandstone house of the dead
## on a drift of sand, its door on -z with steps up. One roof slab has
## often fallen in, letting a shaft of sun down onto a false-door stele
## on the back wall, a sarcophagus and the dead's goods.
func _mastaba() -> void:
	var hx: float = site.half_w
	var hz: float = site.half_l
	var h: float = site.height_m
	mound(maxf(hx, hz) + 1.5, maxf(hx, hz) + 30.0, 22.0, 0.25)
	# Its walls are seen from inside as well as out, so a moderate shade for
	# the whole house (it stands in the desert glare anyway).
	shade = 0.3
	var gr := _ground_range(Vector2.ZERO, maxf(hx, hz))
	var floor_y := maxf(gr.y, 0.25) + 0.2
	var base_y := gr.x - 1.0
	var thick := 1.2
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, (floor_y + base_y) * 0.5, 0.0)), Vector3(hx * 2.0 + 0.6, floor_y - base_y, hz * 2.0 + 0.6), palette[0], 0.0, 0.1, 0.03)
	_door_steps(0.0, -hz - 0.3, floor_y, 2.0)
	var courses := maxi(3, int(round(h)))
	var ch := h / courses
	_house_walls(Vector3(0.0, floor_y, 0.0), hx, hz, courses, ch, thick, 0.8, 3, 0.97, 0.0)
	var n := int(ceil(hz * 2.0 / 1.6))
	var sw := hz * 2.0 / n
	var missing := rng.randi_range(1, n - 2) if rng.randf() < 0.7 else -1
	for i in n:
		if i == missing:
			continue
		box(Transform3D(Basis.IDENTITY, Vector3(0.0, floor_y + h + 0.25, -hz + (i + 0.5) * sw)), Vector3(hx * 2.0 + 0.3, 0.5, sw * 0.99), palette[rng.randi() % palette.size()], 0.0, 0.1, 0.04)
	if missing >= 0:
		# The fallen slab, broken, its piece leaning against a side wall
		# (clear of the way from the door).
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		box(Transform3D(Basis.from_euler(Vector3(0.0, 0.15, sx * 0.9)), Vector3(sx * (hx - thick - 0.7), floor_y + 0.9, -hz + (missing + 0.5) * sw)), Vector3(2.0, 0.45, sw * 0.9), palette[1], 0.0, 0.12, 0.06)
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, floor_y + 1.4, hz - thick - 0.12)), Vector3(1.6, 2.8, 0.25), palette[3], 0.0, 0.05, 0.01)
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, floor_y + 1.1, hz - thick - 0.2)), Vector3(0.7, 1.9, 0.12), Color(0.2, 0.16, 0.12), 0.0, 0.03, 0.01)
	_sarcophagus(Vector3(0.0, floor_y, hz * 0.25), PI * 0.5, palette[3])
	for sx: float in [-1.0, 1.0]:
		_grave_goods(Vector3(sx * (hx - thick) * 0.55, floor_y, -hz * 0.2), 1.2, 3)
	for sx: float in [-1.0, 1.0]:
		_lamp(Vector3(sx * (hx - thick - 0.6), floor_y, hz - thick - 0.7), 7.0, 0.16)
	_shelters.append([Vector3(0.0, floor_y, 0.0), minf(hx, hz) - thick, h])
	shade = 0.0
	for k in 3:
		var a := rng.randf_range(0.3, PI - 0.3)
		rubble(Vector3(cos(a) * (hx + 2.0), 0.0, sin(a) * (hz + 2.0)), 2.0, 4)
	_camp_spot = Vector3(hx + 6.0, ground(hx + 6.0, 0.0), 0.0)


# --- The crag fortress (design 3 Oct §DO) ----------------------------------------

const CRAG_ROCK := [Color(0.36, 0.33, 0.3), Color(0.4, 0.36, 0.32), Color(0.33, 0.31, 0.29), Color(0.38, 0.35, 0.33)]
## (Alpha is the ruin shader's moss: 0, these are bare.)
const LIMEWASH := Color(0.86, 0.85, 0.8, 0.0)
const LICHEN := Color(0.55, 0.58, 0.38, 0.0)
const ROOF_EARTH := Color(0.42, 0.38, 0.33, 0.0)
const WINDOW_DARK := Color(0.035, 0.03, 0.045, 0.0)
const FRAME_DARK := Color(0.09, 0.07, 0.08, 0.0)
## The outside stair climbs at this angle (under the steepest walkable).
const CRAG_STAIR_DEG := 44.0
const CRAG_STAIR_X := 6.0


## A fortress-monastery climbing a rock rise in tiers (ruins.json
## styles.crag_fortress; CragFortress.plan): the rock itself in rough
## tiers, the climb's face built over with limewashed battered walls (each
## leaning in by batter_deg, small dark windows in trapezoid frames, the
## matte red-brown band under its roofline, a flat roof), the top chapel
## over the delve's shaft with one matte gilt finial, the one long stair up
## the front from the foot to the top terrace, and the lesser buildings at
## the foot round a plaza where a camp may live (§CK). Lichen and a little
## moss on the rock's shaded (poleward) faces only; no cloth. The delve
## inside climbs (CragFortress.layout).
func _crag_fortress() -> void:
	var E: Dictionary = CragFortress.E
	var lay := Delves.layout(map, site)
	var p: Dictionary = lay.plan
	_lod_m = LOD_M + float(site.get("base_hs", 30.0)) * 2.0 + float(site.get("rise_m", 60.0))
	_delve = lay
	_delve_off = base_e - float(lay.base_e)
	var off := _delve_off
	var tiers: Array = p.tiers
	var n := tiers.size()
	var g_f := float(p.g_f) - off
	var top_y := float(p.top_y) - off
	var zs0 := float(p.zs0)
	var zs1 := float(p.zs1)
	var br: Array = E.get("batter_deg", [5, 8])
	var batter := deg_to_rad(rng.randf_range(float(br[0]), float(br[1])))
	var band := Color(str((E.get("band", {}) as Dictionary).get("colour", "#5A2420")))
	var gilt := Color(str((E.get("finial", {}) as Dictionary).get("colour", "#B08A2E")))
	band.a = 0.0
	gilt.a = 0.0
	# The poleward side is in shade (lichen there, §DO.5).
	var north := CubeSphere.north(up)
	var pole := Vector2(north.dot(ex), north.dot(ez)) * (1.0 if CubeSphere.latitude(up) >= 0.0 else -1.0)
	pole = pole.normalized()
	palette = CRAG_ROCK
	# The rock, tier by tier, round the shaft the delve climbs in.
	for k in n:
		var t: Dictionary = tiers[k]
		var y0 := float(t.y0) - off
		var y1 := float(t.y1) - off
		_crag_tier(t, y0, y1, zs0, zs1, k == 0, g_f, pole)
	# The faces built over: from tier 1 up, a battered limewashed wall in
	# front of each tier's rock (and round the front of its sides), on the
	# terrace of the tier below.
	for k in range(1, n):
		var t: Dictionary = tiers[k]
		var below: Dictionary = tiers[k - 1]
		_crag_facade(t, float(below.y1) - off, float(t.y1) - off, batter, band, k, n)
	# The top chapel over the shaft, its finial.
	_crag_chapel(zs0, zs1, top_y, batter, band, gilt)
	# The outside stair, the foot's buildings and the plaza.
	var top: Dictionary = tiers[n - 1]
	_crag_stair(CRAG_STAIR_X, float(top.zc) - float(top.sz) + 0.4, top_y, tiers, off)
	_crag_foot(float(p.front_z), g_f, batter, band)
	# Inside: the climb.
	shade = 0.0
	_delve_from = _v.size()
	plain = true
	_crag_delve(lay, off)
	plain = false
	_delve_to = _v.size()
	palette = STONES


## One tier of rock: four masses round the shaft (left and right whole,
## front and back across it), the front one on the bottom tier split round
## the delve's way in; each broken into a few rough blocks so the outline
## is crag, not box. Shaded faces take lichen.
func _crag_tier(t: Dictionary, y0: float, y1: float, zs0: float, zs1: float, bottom: bool, g_f: float, pole: Vector2) -> void:
	var sx := float(t.sx)
	var sz := float(t.sz)
	var zc := float(t.zc)
	var xc := float(t.get("xc", 0.0))
	var hx := CragFortress.SHAFT_HX
	var zf := zc - sz
	var zb := zc + sz
	var masses: Array = []
	# [x0, x1, z0, z1, y0, y1, outward]
	masses.append([xc - sx, -hx, zf, zb, y0, y1, Vector2(-1, 0)])
	masses.append([hx, xc + sx, zf, zb, y0, y1, Vector2(1, 0)])
	masses.append([-hx, hx, zs1, zb, y0, y1, Vector2(0, 1)])
	if bottom:
		# Round the way in: a doorway 1.9 m wide, the rock over it.
		var door_top := g_f + Delves.H_STAIR + Delves.SLAB + 0.2
		masses.append([-hx, -1.55, zf, zs0, y0, y1, Vector2(0, -1)])
		masses.append([1.55, hx, zf, zs0, y0, y1, Vector2(0, -1)])
		masses.append([-1.55, 1.55, zf, zs0, door_top, y1, Vector2(0, -1)])
		masses.append([-1.55, 1.55, zf, zs0, y0, g_f - 0.4, Vector2(0, -1)])
	else:
		masses.append([-hx, hx, zf, zs0, y0, y1, Vector2(0, -1)])
	for m in masses:
		var shaded: bool = (m[6] as Vector2).dot(pole) > 0.4
		var x0: float = m[0]
		var x1: float = m[1]
		var z0: float = m[2]
		var z1: float = m[3]
		var ya: float = m[4]
		var yb: float = m[5]
		if x1 - x0 < 0.2 or z1 - z0 < 0.2 or yb - ya < 0.2:
			continue
		var col: Color = (CRAG_ROCK[rng.randi() % CRAG_ROCK.size()] as Color)
		if shaded:
			col = col.lerp(LICHEN, 0.22)
		box(Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, (ya + yb) * 0.5, (z0 + z1) * 0.5)), Vector3(x1 - x0, yb - ya, z1 - z0), col, 0.08 if shaded else 0.0, 0.6, 0.25)
	# Rough blocks on the outer faces (no two tiers alike), never over the
	# front's middle (the stair and the way in climb there).
	solid = false
	for i in 6:
		var side := rng.randi() % 3
		var w := rng.randf_range(3.0, 7.0)
		var h := rng.randf_range(0.4, 0.8) * (y1 - y0)
		var c: Vector3
		var outv: Vector2
		match side:
			0:
				c = Vector3(xc - sx - 0.4, y0 + h * 0.5 + rng.randf_range(0.0, y1 - y0 - h), rng.randf_range(zf + w * 0.5, zb - w * 0.5))
				outv = Vector2(-1, 0)
			1:
				c = Vector3(xc + sx + 0.4, y0 + h * 0.5 + rng.randf_range(0.0, y1 - y0 - h), rng.randf_range(zf + w * 0.5, zb - w * 0.5))
				outv = Vector2(1, 0)
			_:
				c = Vector3(xc + rng.randf_range(-sx + w * 0.5, sx - w * 0.5), y0 + h * 0.5 + rng.randf_range(0.0, y1 - y0 - h), zb + 0.4)
				outv = Vector2(0, 1)
		var shaded2 := outv.dot(pole) > 0.4
		var col2: Color = (CRAG_ROCK[rng.randi() % CRAG_ROCK.size()] as Color).darkened(rng.randf_range(0.0, 0.08))
		if shaded2:
			col2 = col2.lerp(LICHEN, 0.3)
		var bs := Basis(Vector3.UP, rng.randf_range(-0.25, 0.25)).rotated(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
		box(Transform3D(bs, c), Vector3(w, h, rng.randf_range(1.6, 3.0)), col2, 0.06 if shaded2 else 0.0, 0.5, 0.3)
	solid = true


## A battered prism: its foot the rectangle (x0..x1, z0..z1) at y0, its
## top at y1 pulled in by `lean` on the sides in `lean_sides` ("front":
## -z, "back", "left", "right"), drawn in `col`, solid.
func _battered(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, lean: float, lean_sides: Array, col: Color) -> void:
	col.a = 0.0
	var tx0 := x0 + (lean if lean_sides.has("left") else 0.0)
	var tx1 := x1 - (lean if lean_sides.has("right") else 0.0)
	var tz0 := z0 + (lean if lean_sides.has("front") else 0.0)
	var tz1 := z1 - (lean if lean_sides.has("back") else 0.0)
	var b := [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)]
	var t := [Vector3(tx0, y1, tz0), Vector3(tx1, y1, tz0), Vector3(tx1, y1, tz1), Vector3(tx0, y1, tz1)]
	var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	for i in 4:
		var j := (i + 1) % 4
		# In cells about 3 m across: the ruins are lit per vertex, and one
		# big quad's four corners all sit in contact shade (the band over
		# it, the terrace under it), which would darken the whole wall.
		var nu := maxi(1, int(ceil(b[i].distance_to(b[j]) / 3.0)))
		var nv := maxi(1, int(ceil(absf(y1 - y0) / 3.0)))
		for u in nu:
			for w in nv:
				var u0 := float(u) / nu
				var u1 := float(u + 1) / nu
				var v0 := float(w) / nv
				var v1 := float(w + 1) / nv
				var p00: Vector3 = (b[i] as Vector3).lerp(b[j], u0).lerp((t[i] as Vector3).lerp(t[j], u0), v0)
				var p10: Vector3 = (b[i] as Vector3).lerp(b[j], u1).lerp((t[i] as Vector3).lerp(t[j], u1), v0)
				var p11: Vector3 = (b[i] as Vector3).lerp(b[j], u1).lerp((t[i] as Vector3).lerp(t[j], u1), v1)
				var p01: Vector3 = (b[i] as Vector3).lerp(b[j], u0).lerp((t[i] as Vector3).lerp(t[j], u0), v1)
				_face(p00, p10, p11, p01, col, mid)
	_face(t[0], t[1], t[2], t[3], col.lerp(ROOF_EARTH, 0.4), mid)
	var h := Vector3((tx1 - tx0) * 0.5 + (x1 - x0 - (tx1 - tx0)) * 0.25, (y1 - y0) * 0.5, (tz1 - tz0) * 0.5 + (z1 - z0 - (tz1 - tz0)) * 0.25)
	var cmid := Vector3((x0 + x1 + tx0 + tx1) * 0.25, mid.y, (z0 + z1 + tz0 + tz1) * 0.25)
	_collision_box(Transform3D(Basis.IDENTITY, cmid), h)
	_lod_box(Transform3D(Basis.IDENTITY, cmid), h, col.lerp(ROOF_EARTH, 0.4), col, col.darkened(UNDER))


## The red band under a roofline and the flat roof over it: round the
## top of a battered block (its top rectangle at y_top), 0.9 m deep.
func _band_and_roof(x0: float, x1: float, z0: float, z1: float, y_top: float, band: Color, sides: Array) -> void:
	var bh := 1.3
	var o := 0.12
	var bx0 := x0 - (o if sides.has("left") else 0.0)
	var bx1 := x1 + (o if sides.has("right") else 0.0)
	var bz0 := z0 - (o if sides.has("front") else 0.0)
	var bz1 := z1 + (o if sides.has("back") else 0.0)
	_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3((bx0 + bx1) * 0.5, y_top - bh * 0.5 - 0.25, (bz0 + bz1) * 0.5)), Vector3(bx1 - bx0, bh, bz1 - bz0), band)
	_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3((bx0 + bx1) * 0.5, y_top + 0.05, (bz0 + bz1) * 0.5)), Vector3(bx1 - bx0 + 0.3, 0.3, bz1 - bz0 + 0.3), ROOF_EARTH)


## A small dark window in a trapezoid frame on a face: centre `c`, the
## face's outward normal `out` (local, horizontal), `w` x `h`.
func _crag_window(c: Vector3, out: Vector3, w: float, h: float) -> void:
	var along := Vector3.UP.cross(out).normalized()
	var f := c + out * 0.05
	var fb := w * 0.8
	var ft := w * 0.6
	_face(f - along * fb - Vector3.UP * h * 0.65, f + along * fb - Vector3.UP * h * 0.65, f + along * ft + Vector3.UP * h * 0.65, f - along * ft + Vector3.UP * h * 0.65, FRAME_DARK, c - out)
	var g := c + out * 0.08
	_face(g - along * w * 0.5 - Vector3.UP * h * 0.5, g + along * w * 0.5 - Vector3.UP * h * 0.5, g + along * w * 0.5 + Vector3.UP * h * 0.5, g - along * w * 0.5 + Vector3.UP * h * 0.5, WINDOW_DARK, c - out)
	# Seen from across the valley too (the far LOD keeps them).
	var xf := Transform3D(Basis(along, Vector3.UP, out), c + out * 0.05)
	_lod_box(xf, Vector3(w * 0.7, h * 0.6, 0.06), FRAME_DARK, FRAME_DARK, FRAME_DARK)


## The limewashed buildings over tier `t`'s rock (tier `k` of `n`): along
## its front, separate battered blocks of their own widths and heights
## with the rock showing between them (few low down, close together near
## the top: the monastery crowns the crag), some taller than the tier and
## roofed above the terrace behind; a few wrap round onto the sides.
## Windows in rows, the band and the roof's edge at each top.
func _crag_facade(t: Dictionary, y0: float, y1: float, batter: float, band: Color, k: int = 1, n: int = 4) -> void:
	var sx := float(t.sx)
	var sz := float(t.sz)
	var zc := float(t.zc)
	var xc := float(t.get("xc", 0.0))
	var th := y1 - y0
	var zf := zc - sz
	var built := lerpf(0.4, 0.95, float(k) / maxf(n - 1, 1))
	var x := xc - sx - 1.0
	while x < xc + sx:
		var w := rng.randf_range(5.0, 13.0)
		var x0 := x
		var x1 := minf(x + w, xc + sx + 1.0)
		x = x1 + rng.randf_range(1.5, 5.0)
		# Never over the stair's band.
		if x1 > CRAG_STAIR_X - 2.4 and x0 < CRAG_STAIR_X + 2.4:
			if x0 < CRAG_STAIR_X - 2.4 - 3.0:
				x1 = CRAG_STAIR_X - 2.4
			else:
				continue
		if rng.randf() > built or x1 - x0 < 3.0:
			continue
		var h := th * rng.randf_range(0.55, 1.2)
		var lean := h * tan(batter)
		var thick := 1.2 + lean + rng.randf_range(0.0, 2.0)
		var col := LIMEWASH.darkened(rng.randf_range(0.0, 0.07))
		_battered(x0, x1, zf - thick, zf + 0.5, y0, y0 + h, lean, ["front", "left", "right"], col)
		_band_and_roof(x0 + lean, x1 - lean, zf - thick + lean, zf + 0.5, y0 + h, band, ["front", "left", "right"])
		var cols := maxi(1, int((x1 - x0) / 3.4))
		var rows := maxi(1, int((h - 2.4) / 3.2))
		for i in cols:
			for j in rows:
				if rng.randf() < 0.3:
					continue
				var yy := y0 + 2.2 + j * 3.2
				if yy > y0 + h - 2.0:
					continue
				var lz := zf - thick + lean * (yy - y0) / h
				_crag_window(Vector3(x0 + (i + 0.5) * (x1 - x0) / cols, yy, lz), Vector3(0, 0, -1), 0.7, 1.0)
	# Now and then a block round a side.
	for sgn: float in [-1.0, 1.0]:
		if rng.randf() > built * 0.7:
			continue
		var h := th * rng.randf_range(0.6, 1.1)
		var lean := h * tan(batter)
		var thick := 1.2 + lean
		var xa := xc + sgn * sx
		var xo := xa + sgn * thick
		var z0 := zf + rng.randf_range(0.0, sz * 0.3)
		var z1 := z0 + rng.randf_range(6.0, 12.0)
		var side := "left" if sgn < 0.0 else "right"
		_battered(minf(xa, xo), maxf(xa, xo), z0, z1, y0, y0 + h, lean, [side, "front", "back"], LIMEWASH.darkened(rng.randf_range(0.02, 0.08)))
		_band_and_roof(minf(xa, xo) + (lean if sgn < 0.0 else 0.0), maxf(xa, xo) - (0.0 if sgn < 0.0 else lean), z0 + lean, z1 - lean, y0 + h, band, [side, "front", "back"])
		var yy := y0 + 2.2
		if yy < y0 + h - 2.0:
			_crag_window(Vector3(xo - sgn * lean * 2.2 / h, yy, (z0 + z1) * 0.5), Vector3(sgn, 0, 0), 0.7, 1.0)


## The top chapel: a battered limewashed shell round the delve's heart (the
## room is CragFortress.layout's), its door on the front, the band, the
## flat roof, and the one gilt finial (matte, never a light: R7, R8).
func _crag_chapel(zs0: float, zs1: float, top_y: float, batter: float, band: Color, gilt: Color) -> void:
	var hx := CragFortress.SHAFT_HX + 0.7
	var z0 := zs0 - 0.9
	var z1 := zs1 + 0.9
	var h := Delves.H_HEART + Delves.SLAB + 3.6
	var lean := h * tan(batter) * 0.5
	var y0 := top_y - 0.3
	var y1 := top_y + h
	var t := 0.7
	var col := LIMEWASH
	# Four walls (the front split round the door), each a battered slab.
	_battered(-hx, -hx + t + lean, z0, z1, y0, y1, lean, ["left"], col)
	_battered(hx - t - lean, hx, z0, z1, y0, y1, lean, ["right"], col)
	_battered(-hx + t, hx - t, z1 - t - lean, z1, y0, y1, lean, ["back"], col)
	_battered(-hx + t, -1.0, z0, z0 + t + lean, y0, y1, lean, ["front"], col)
	_battered(1.0, hx - t, z0, z0 + t + lean, y0, y1, lean, ["front"], col)
	_battered(-1.0, 1.0, z0, z0 + t + lean, top_y + Delves.H_STAIR + 0.2, y1, lean, ["front"], col)
	_band_and_roof(-hx + lean, hx - lean, z0 + lean, z1 - lean, y1, band, ["front", "back", "left", "right"])
	for sx: float in [-1.0, 1.0]:
		_crag_window(Vector3(sx * 3.0, top_y + 2.6, z0 + lean * 0.5), Vector3(0, 0, -1), 0.6, 0.9)
	# The finial: a stepped base, a bell, a spire, on the roof's middle.
	var cz := (z0 + z1) * 0.5
	var fy := y1 + 0.2
	_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3(0.0, fy + 0.35, cz)), Vector3(2.4, 0.7, 2.4), gilt.darkened(0.1))
	_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3(0.0, fy + 1.3, cz)), Vector3(1.8, 1.2, 1.8), gilt)
	_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3(0.0, fy + 2.5, cz)), Vector3(1.1, 1.2, 1.1), gilt)
	_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3(0.0, fy + 3.7, cz)), Vector3(0.5, 1.3, 0.5), gilt.lightened(0.05))
	_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3(0.0, fy + 4.6, cz)), Vector3(0.24, 0.6, 0.24), gilt)


## The rock's top at local (x, z): the highest tier whose top covers it,
## else the ground.
func _crag_surface(x: float, z: float, tiers: Array, off: float) -> float:
	var best := ground(x, z)
	for t in tiers:
		var sx := float(t.sx)
		var zc := float(t.zc)
		var sz := float(t.sz)
		if absf(x - float(t.get("xc", 0.0))) <= sx and z >= zc - sz and z <= zc + sz:
			best = maxf(best, float(t.y1) - off)
	return best


## The one long stair up the front at x, climbing toward +z at
## CRAG_STAIR_DEG to the top terrace's front edge (z_top, y_top), from
## where it meets the ground: each step a block down to the rock or ground
## under it, a walkable ramp under them all.
func _crag_stair(x: float, z_top: float, y_top: float, tiers: Array, off: float) -> void:
	var tanv := tan(deg_to_rad(CRAG_STAIR_DEG))
	var z := z_top
	for i in 2000:
		z -= 0.25
		if y_top - (z_top - z) * tanv <= ground(x, z):
			break
	var z_start := z
	var y_start := ground(x, z_start)
	var rise := y_top - y_start
	var steps := maxi(4, int(round(rise / 0.5)))
	var r := rise / steps
	var run := (z_top - z_start) / steps
	var w := 2.8
	solid = false
	for i in steps:
		var y_i := y_start + (i + 1) * r
		var z_i := z_start + i * run
		var under := _crag_surface(x, z_i + run * 0.5, tiers, off)
		var bottom := minf(under, y_i - r) - 0.3
		var col: Color = (CRAG_ROCK[rng.randi() % CRAG_ROCK.size()] as Color).lightened(0.12)
		_tri_box_lod(Transform3D(Basis.IDENTITY, Vector3(x, (y_i + bottom) * 0.5, z_i + run * 0.5)), Vector3(w, y_i - bottom, run + 0.02), col)
	solid = true
	# Low limewashed parapets each side, in long runs.
	var seg := 8
	for k in seg:
		var a := float(k) / seg
		var b := float(k + 1) / seg
		for sd: float in [-1.0, 1.0]:
			var pa := Vector3(x + sd * (w * 0.5 + 0.2), y_start + rise * a + 0.45, z_start + (z_top - z_start) * a)
			var pb := Vector3(x + sd * (w * 0.5 + 0.2), y_start + rise * b + 0.45, z_start + (z_top - z_start) * b)
			var dirv := (pb - pa).normalized()
			var nrm := dirv.cross(Vector3.RIGHT)
			_tri_box(Transform3D(Basis(Vector3.RIGHT, nrm, dirv), (pa + pb) * 0.5), Vector3(0.4, 0.9, pa.distance_to(pb) + 0.05), LIMEWASH.darkened(0.08))
	_dramp(Vector3(x, y_start, z_start), Vector3(x, y_top, z_top), w)


## The lesser buildings at the foot, round a plaza before the way in where
## a camp may live (§CK): flat-roofed battered houses with their bands.
func _crag_foot(front_z: float, g_f: float, batter: float, band: Color) -> void:
	var count := rng.randi_range(3, 5)
	var placed: Array = []
	var hs := float(site.get("base_hs", 30.0))
	for i in 40:
		if placed.size() >= count:
			break
		var hx := rng.randf_range(2.6, 4.5)
		var hz := rng.randf_range(2.4, 3.6)
		var cx := rng.randf_range(-hs * 0.8, hs * 0.8)
		var cz := front_z - rng.randf_range(9.0, 24.0)
		# Clear of the stair, the way to the door and the plaza's middle.
		if absf(cx - CRAG_STAIR_X) < hx + 3.0 or absf(cx) < hx + 2.0:
			continue
		if Vector2(cx + 7.0, cz - (front_z - 13.0)).length() < hx + 5.0:
			continue
		var clash := false
		for q in placed:
			if absf(cx - float(q[0])) < hx + float(q[2]) + 2.0 and absf(cz - float(q[1])) < hz + float(q[3]) + 2.0:
				clash = true
		if clash:
			continue
		placed.append([cx, cz, hx, hz])
		var lo := INF
		for dx: float in [-hx, hx]:
			for dz: float in [-hz, hz]:
				lo = minf(lo, ground(cx + dx, cz + dz))
		var h := rng.randf_range(4.0, 6.5)
		var lean := h * tan(batter)
		var y0 := lo - 0.6
		var y1 := lo + h
		_battered(cx - hx, cx + hx, cz - hz, cz + hz, y0, y1, lean, ["front", "back", "left", "right"], LIMEWASH.darkened(rng.randf_range(0.0, 0.1)))
		_band_and_roof(cx - hx + lean, cx + hx - lean, cz - hz + lean, cz + hz - lean, y1, band, ["front", "back", "left", "right"])
		_crag_window(Vector3(cx + rng.randf_range(-hx * 0.4, hx * 0.4), lo + h * 0.6, cz + hz - lean * 0.6), Vector3(0, 0, 1), 0.6, 0.9)
		_crag_window(Vector3(cx, lo + 1.0, cz - hz + lean * 0.15), Vector3(0, 0, -1), 0.9, 1.9)
	# The plaza's camp spot (Camps builds the fire if folk live here).
	_camp_spot = Vector3(-7.0, ground(-7.0, front_z - 13.0), front_z - 13.0)


## The climb inside (CragFortress.layout): the passage, the landings
## (stores, the cistern, braziers), the flights, the chapel with its
## stairwell, the way out onto the terrace.
func _crag_delve(lay: Dictionary, off: float) -> void:
	var pieces: Array = lay.pieces
	var well: Dictionary = lay.well
	var heart_i := int(lay.heart_i)
	palette = STONES
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		var prev: Dictionary = pieces[i - 1] if i > 0 else {}
		var nxt: Dictionary = pieces[i + 1] if i + 1 < pieces.size() else {}
		match str(pc.kind):
			"passage":
				_delve_room(pc, off, [["start", 0.0, 0.95], ["end", 0.0, 0.95]])
			"room":
				var opens: Array = []
				var pend: Vector2 = (prev.c as Vector2) + (prev.dir as Vector2) * float(prev.len)
				opens.append(_opening(pc, pend, float(prev.half)))
				if not nxt.is_empty() and str(nxt.kind) == "stair":
					opens.append(_opening(pc, nxt.c, float(nxt.half)))
				_delve_room(pc, off, opens)
				_crag_landing_dress(pc, off)
			"stair":
				if i == int(well.piece):
					_delve_stair_open_top(pc, off, float(well.from), float(pieces[heart_i].y0) - off)
				else:
					_delve_stair(pc, off, false, 0.0, 0.0)
			"heart":
				var last: Dictionary = pieces[int(well.piece)]
				var hole := Delves.rect_of(last, 0.15, float(well.from), float(last.len))
				_delve_room(pc, off, [["start", 0.0, 0.95]], hole)
				# A low wall round the stairwell (no falling back down it).
				var yh := float(pc.y0) - off
				var r := hole.grow(0.25)
				var sdz := 1.0 if ((last.dir as Vector2).y < 0.0) else -1.0
				var zf := r.position.y if sdz < 0.0 else r.position.y + r.size.y
				_dwall(Vector2(r.position.x, zf), Vector2(r.position.x + r.size.x, zf), yh, yh + 0.9, 0.3)
				_crag_heart_dress(pc, off)
			"exit":
				_delve_stair(pc, off, false, 0.0, 0.0)
	# The landings' braziers (the fire-holders sit in their bowls).
	for b: Vector3 in lay.get("braziers", []):
		var p := b - Vector3(0.0, off, 0.0)
		box(Transform3D(Basis.IDENTITY, p - Vector3(0.0, 0.55, 0.0)), Vector3(0.45, 0.7, 0.45), palette[1], 0.0, 0.06, 0.02)
		box(Transform3D(Basis.IDENTITY, p - Vector3(0.0, 0.12, 0.0)), Vector3(0.95, 0.24, 0.95), Color(0.12, 0.1, 0.09), 0.0, 0.05, 0.02)


## The same stair as _delve_stair, but from `open_from` along it its ceiling
## is gone and its walls stop at `open_top` (it comes up through a floor).
func _delve_stair_open_top(pc: Dictionary, off: float, open_from: float, open_top: float) -> void:
	var lower := pc.duplicate()
	lower.len = maxf(open_from, 0.5)
	lower.y1 = Delves.floor_of(pc, lower.len)
	_delve_stair(lower, off, false, 0.0, 0.0)
	var upper := pc.duplicate()
	upper.c = (pc.c as Vector2) + (pc.dir as Vector2) * lower.len
	upper.len = float(pc.len) - lower.len
	upper.y0 = lower.y1
	if upper.len > 0.3:
		# The walls up to the floor above; steps and the ramp as ever.
		_delve_stair(upper, off, true, upper.len + 1.0, open_top + off)


## A landing's dressing: the stores (clay jars), or the cistern (a sunk
## basin of dark water), or bare.
func _crag_landing_dress(pc: Dictionary, off: float) -> void:
	var y := float(pc.y0) - off
	var feature := str(pc.get("feature", "landing"))
	var length := float(pc.len)
	match feature:
		"stores":
			for k in rng.randi_range(4, 7):
				var a := rng.randf_range(0.6, length * 0.3) if rng.randf() < 0.5 else rng.randf_range(length * 0.7, length - 0.6)
				var p := _pp(pc, a, rng.randf_range(-0.6, 0.6))
				var hj := rng.randf_range(0.5, 0.8)
				box(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y + hj * 0.5, p.y)), Vector3(0.45, hj, 0.45), CLAY.darkened(rng.randf_range(0.0, 0.2)), 0.0, 0.12, 0.03)
		"cistern":
			var p := _pp(pc, length * 0.25, 0.0)
			solid = true
			for sd: float in [-1.0, 1.0]:
				box(Transform3D(Basis.IDENTITY, Vector3(p.x + sd * 0.95, y + 0.3, p.y)), Vector3(0.25, 0.6, 1.9), palette[2], 0.0, 0.05, 0.02)
				box(Transform3D(Basis.IDENTITY, Vector3(p.x, y + 0.3, p.y + sd * 0.95)), Vector3(1.9, 0.6, 0.25), palette[2], 0.0, 0.05, 0.02)
			_tri_box(Transform3D(Basis.IDENTITY, Vector3(p.x, y + 0.42, p.y)), Vector3(1.7, 0.02, 1.7), Color(0.07, 0.11, 0.24, 0.0))


## The chapel inside: an altar at the far end, offerings before it.
func _crag_heart_dress(pc: Dictionary, off: float) -> void:
	var y := float(pc.y0) - off
	var length := float(pc.len)
	var a := _pp(pc, length - 1.2, 0.0)
	box(Transform3D(Basis.IDENTITY, Vector3(a.x, y + 0.55, a.y)), Vector3(2.6, 1.1, 1.0), palette[3], 0.0, 0.06, 0.02)
	_grave_goods(Vector3(a.x, y + 1.1, a.y), 0.9, 4)


## A plain box (12 triangles) that the far LOD keeps too.
func _tri_box_lod(xf: Transform3D, size: Vector3, col: Color) -> void:
	col.a = 0.0
	_tri_box(xf, size, col)
	_lod_box(xf, size * 0.5, col, col, col.darkened(UNDER))


# --- The shrine (design 3 Oct §DK, Shrines) --------------------------------------------

## The shrine behind a hidden place (Shrines.layout `lay`, its delve-frame
## `p_site`): the same data as compute() for make_node.
static func compute_shrine(p_map: PlanetData, p_site: Dictionary, lay: Dictionary) -> Dictionary:
	var b := RuinBuilder.new()
	b.map = p_map
	b.site = p_site
	b.rng.seed = int(p_site.seed)
	b.up = p_site.dir
	var a: float = float(p_site.heading) + PI * 0.5
	b.ex = CubeSphere.north(b.up) * cos(a) + CubeSphere.east(b.up) * sin(a)
	b.ez = b.ex.cross(b.up).normalized()
	b.base_e = p_map.terrain.elevation(b.up, true)
	b.wet = smoothstep(0.2, 0.8, p_map.sample(p_map.moisture, b.up))
	b._og_setup()
	b._shrine_hall(lay)
	return {"og": b.og, "og_plants": [], "og_shade": b._og_shade, "ivy_places": 0, "ivy_kept": 0, "site": p_site, "v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch,
		"lv": b._lv, "ln": b._ln, "lc": b._lc, "lm": b._lm, "up": b.up, "ex": b.ex, "ez": b.ez, "base_e": b.base_e,
		"shelters": b._shelters, "camp_spot": Vector3.ZERO, "lights": [], "lamps": [], "delve": lay, "delve_off": b._delve_off, "delve_from": b._delve_from, "delve_to": b._delve_to, "vine_anchors": [], "boulder_anchors": [], "lod_m": b._lod_m, "lit_per_pixel": false}


## The court, the hall going down, the altar room, and behind it the stair
## and the room below (Shrines). +z runs into the hill, the mouth at z 0.
func _shrine_hall(lay: Dictionary) -> void:
	_delve = lay
	_delve_off = base_e - float(lay.base_e)
	var off := _delve_off
	var pieces: Array = lay.pieces
	var hall: Dictionary = pieces[0]
	var open_to: float = lay.open_to
	var hw := float(hall.half) + Delves.WALL * 0.5
	var outer := hw + Delves.WALL * 0.5
	var z_open := 0.5 + open_to
	# The court: flagstones on the ground over the hole and round it, the
	# way down left open between its parapets.
	shade = 0.25
	var court: Rect2 = (lay.holes[0] as Rect2).grow(Delves.QUAD_PAD + 1.0)
	_pave(court, NAN, Rect2(-outer, 0.5, 2.0 * outer, open_to + 0.05))
	# The parapets each side of the open stair, a little over the court;
	# the facade across where its roof begins.
	var a0 := 0.0
	while a0 < open_to - 0.01:
		var a1 := minf(a0 + 1.2, open_to)
		for sd: float in [-1.0, 1.0]:
			var g := -INF
			for q in [a0, a1]:
				for xx in [sd * hw, sd * (outer + 0.4)]:
					g = maxf(g, ground(xx, 0.5 + q))
			var lo := minf(Delves.floor_of(hall, a0), Delves.floor_of(hall, a1)) - off - 0.6
			_dwall(Vector2(sd * hw, 0.5 + a0), Vector2(sd * hw, 0.5 + a1), lo, g + 0.45)
		a0 = a1
	var gf := maxf(ground(-outer, z_open), ground(outer, z_open))
	var lint := Delves.floor_of(hall, open_to) - off + float(hall.h)
	_dwall(Vector2(-outer, z_open + Delves.WALL * 0.5), Vector2(outer, z_open + Delves.WALL * 0.5), lint, gf + 0.6)
	# Below: the hall, the rooms (lit per pixel, as a delve's inside).
	shade = 0.0
	_delve_from = _v.size()
	# The open stretch: steps only (its parapets above); then walls and roof.
	var cut := clampf(open_to, 0.5, float(hall.len) - 0.5)
	var open_pc := hall.duplicate()
	open_pc.len = cut
	open_pc.y1 = Delves.floor_of(hall, cut)
	_delve_stair(open_pc, off, true, cut + 1.0, -1.0e6)
	var cov_pc := hall.duplicate()
	cov_pc.c = (hall.c as Vector2) + (hall.dir as Vector2) * cut
	cov_pc.len = float(hall.len) - cut
	cov_pc.y0 = open_pc.y1
	_delve_stair(cov_pc, off, false, 0.0, 0.0)
	var room: Dictionary = pieces[1]
	var stair: Dictionary = pieces[2]
	var heart: Dictionary = pieces[3]
	_delve_room(room, off, [_opening(room, (hall.c as Vector2) + (hall.dir as Vector2) * float(hall.len), float(hall.half)), _opening(room, stair.c, float(stair.half))])
	_delve_stair(stair, off, false, 0.0, 0.0)
	_delve_room(heart, off, [_opening(heart, (stair.c as Vector2) + (stair.dir as Vector2) * float(stair.len), float(stair.half))])
	_delve_to = _v.size()


# --- The temple city (design 3 Oct §DR, ruins.json styles.temple_city) ---------------

const TEMPLE_STONES := [Color(0.42, 0.45, 0.4), Color(0.38, 0.41, 0.36), Color(0.46, 0.47, 0.42), Color(0.36, 0.38, 0.33), Color(0.44, 0.43, 0.38)]
const LATERITE := Color(0.47, 0.36, 0.28)
const FACE_STONE := Color(0.58, 0.58, 0.52)
const ROOT_BARK := Color(0.66, 0.62, 0.54)
const MOAT := Color(0.34, 0.58, 0.82)

## Root-trees standing on the stone (§DR.2, ruins.json root_trees): [local
## foot (on the roof), species index, height_m], drawn by make_node.
var _root_trees: Array = []
## Running water (§DT): {"v", "uv", "uv2"} (local, drawn as the place's
## fresh water) and its falls {"v", "n", "uv", "uv2"} (the waterfall sheet);
## a garden gone wild: [[local foot, species index, height]...].
var _wv := PackedVector3Array()
var _wuv := PackedVector2Array()
var _wuv2 := PackedVector2Array()
var _fv := PackedVector3Array()
var _fn := PackedVector3Array()
var _fuv := PackedVector2Array()
var _fuv2 := PackedVector2Array()
var _garden: Array = []


## A plain block (12 triangles, collision) at `c` (its middle), turned
## `rot` round up: the temple city's repeated parts, within a castle's
## budget.
func _pblock(c: Vector3, size: Vector3, col: Color, moss: float, rot := 0.0) -> void:
	var was := plain
	plain = true
	var ft := foot_y
	foot_y = c.y - size.y * 0.5
	box(Transform3D(Basis(Vector3.UP, rot), c), size, col, _growth(moss))
	foot_y = ft
	plain = was


## The temple city: a moat, a causeway of guardians to the face-towered
## gate, an outer wall with a gate on each side, one or two rings of
## galleries (square columns, a back wall, a mossy roof, a gopura in the
## middle of each side, some bays fallen), courtyards of tumbled blocks,
## and at the middle a sanctum under five towers of diminishing tiers,
## its delve going down inside it. Root-trees stand on every third gopura
## and gallery side.
func _temple_city() -> void:
	palette = TEMPLE_STONES
	var across: float = site.across_m
	# Its near detail out to its own edge and LOD_M past it (the node's
	# middle is the city's).
	_lod_m = across * 0.5 + LOD_M
	var ro := across * 0.5 - 14.0
	var rings: Array = [ro * 0.56] if int(site.enclosures) <= 2 else [ro * 0.62, ro * 0.36]
	var gopuras: Array = []
	# The moat, a band of water outside the wall, kerbed both sides.
	var m0 := ro + 4.0
	var m1 := ro + 10.0
	for side in 4:
		var rot := side * PI * 0.5
		var n := 10
		for i in n:
			var t0 := lerpf(-m1, m1, float(i) / n)
			var t1 := lerpf(-m1, m1, float(i + 1) / n)
			# The causeway crosses the front band.
			if side == 0 and t1 > -4.0 and t0 < 4.0:
				continue
			var pts: Array = []
			for q in [[t0, m0], [t1, m0], [t1, m1], [t0, m1]]:
				var v := Vector2(q[0], -q[1]).rotated(-rot)
				pts.append(Vector3(v.x, 0.0, v.y))
			var y := -INF
			for u in 3:
				for v in 3:
					var pa: Vector3 = (pts[0] as Vector3).lerp(pts[1], u * 0.5)
					var pb: Vector3 = (pts[3] as Vector3).lerp(pts[2], u * 0.5)
					var pq := pa.lerp(pb, v * 0.5)
					y = maxf(y, ground(pq.x, pq.z))
			var w: Array = pts.map(func(p): return Vector3(p.x, y + 0.25, p.z))
			var mid3: Vector3 = ((w[0] as Vector3) + (w[2] as Vector3)) * 0.5
			_face(w[0], w[1], w[2], w[3], MOAT, mid3 - Vector3(0.0, 1.0, 0.0))
			for edge in [m0 - 0.4, m1 + 0.4]:
				var mid := Vector2((t0 + t1) * 0.5, -edge).rotated(-rot)
				_pblock(Vector3(mid.x, ground(mid.x, mid.y) + 0.2, mid.y), Vector3(t1 - t0 + 0.1, 0.7, 0.8), LATERITE, 0.3, -rot)
	# The causeway over the front moat and its guardians with the serpent.
	var cz0 := -(m1 + 2.0)
	var cz1 := -(ro - 1.0)
	_pave(Rect2(-3.0, cz0, 6.0, cz1 - cz0), NAN)
	for sx: float in [-1.0, 1.0]:
		var k := 0
		var z := cz0 + 1.0
		while z < cz1 - 1.0:
			var g := ground(sx * 3.7, z)
			var was := foot_y
			foot_y = g
			box(Transform3D(Basis(), Vector3(sx * 3.7, g + 0.45, z)), Vector3(0.6, 0.9, 0.7), TEMPLE_STONES[k % 5], _growth(0.4), 0.12, 0.05)
			# Half scowling, half serene (§DR.7): the heads tilt down and go
			# dark, or stay level and pale.
			var scowl := (k + (1 if sx > 0.0 else 0)) % 2 == 0
			box(Transform3D(Basis(Vector3.RIGHT, 0.35 if scowl else 0.0), Vector3(sx * 3.7, g + 1.15, z - 0.05)), Vector3(0.48, 0.5, 0.46), FACE_STONE.darkened(0.3 if scowl else 0.0), _growth(0.3), 0.12, 0.04)
			foot_y = was
			z += 2.2
			k += 1
		# The serpent's body they hold, its hood raised at the far end.
		var gz := ground(sx * 3.7, (cz0 + cz1) * 0.5)
		_pblock(Vector3(sx * 3.95, gz + 0.85, (cz0 + cz1) * 0.5), Vector3(0.3, 0.3, cz1 - cz0 - 1.0), TEMPLE_STONES[2], 0.5)
		for h in 5:
			var a := (h - 2) * 0.32
			var hood := Vector3(sx * 3.95 + sin(a) * 0.6, ground(sx * 3.95, cz0) + 1.2 + cos(a) * 0.6, cz0 + 0.4)
			_pblock(hood, Vector3(0.35, 0.9, 0.25), TEMPLE_STONES[2], 0.4, a)
	# The outer wall, a gate on each side.
	for side in 4:
		var rot := side * PI * 0.5
		var n := 12
		for i in n:
			var t0 := lerpf(-ro, ro, float(i) / n)
			var t1 := lerpf(-ro, ro, float(i + 1) / n)
			if t1 > -5.0 and t0 < 5.0:
				continue
			var mid := Vector2((t0 + t1) * 0.5, -ro).rotated(-rot)
			var g := ground(mid.x, mid.y)
			var h := 3.6 if rng.randf() > 0.15 else rng.randf_range(1.0, 2.4)
			_pblock(Vector3(mid.x, g + h * 0.5 - 0.3, mid.y), Vector3(t1 - t0 + 0.05, h, 1.0), TEMPLE_STONES[i % 5], 0.6, -rot)
		var gp := Vector2(0.0, -ro).rotated(-rot)
		_face_gate(Vector3(gp.x, 0.0, gp.y), rot, side == 0)
		gopuras.append([Vector3(gp.x, 0.0, gp.y), rot, 9.0])
	# The gallery rings.
	for ri in rings.size():
		var r: float = rings[ri]
		for side in 4:
			var rot := side * PI * 0.5
			var bays := 12
			for i in bays:
				var t0 := lerpf(-r, r, float(i) / bays)
				var t1 := lerpf(-r, r, float(i + 1) / bays)
				if t1 > -3.5 and t0 < 3.5:
					continue
				var mid_out := Vector2((t0 + t1) * 0.5, -r - 1.6).rotated(-rot)
				var mid_col := Vector2((t0 + t1) * 0.5, -r + 1.6).rotated(-rot)
				var mid := Vector2((t0 + t1) * 0.5, -r).rotated(-rot)
				var g := ground(mid.x, mid.y)
				var fallen := rng.randf() < 0.2
				# The back wall (outer side), with a relief on some bays.
				_pblock(Vector3(mid_out.x, g + 1.7, mid_out.y), Vector3(t1 - t0 + 0.05, 3.4, 0.7), TEMPLE_STONES[(i + side) % 5], 0.5, -rot)
				if i % 3 == 1:
					_relief(Vector2((t0 + t1) * 0.5, -r - 1.2), rot, g, (i + side) % 2 == 0)
				if fallen:
					var rc := Vector2((t0 + t1) * 0.5, -r + 3.5).rotated(-rot)
					rubble(Vector3(rc.x, 0.0, rc.y), 2.4, 5)
					continue
				# The square column and the roof over the bay.
				_pblock(Vector3(mid_col.x, g + 1.6, mid_col.y), Vector3(0.7, 3.2, 0.7), TEMPLE_STONES[(i + 2) % 5], 0.4, -rot)
				_pblock(Vector3(mid.x, g + 3.55, mid.y), Vector3(t1 - t0 + 0.1, 0.7, 4.2), TEMPLE_STONES[(i + 1) % 5].darkened(0.05), 0.9, -rot)
			# The side's gopura.
			var gp2 := Vector2(0.0, -r).rotated(-rot)
			_gopura(Vector3(gp2.x, 0.0, gp2.y), rot, 1.0 - ri * 0.2)
			gopuras.append([Vector3(gp2.x, 0.0, gp2.y), rot, 6.0])
			# Root-trees on every third gallery side (on its roof).
			if (side + ri) % 3 == 0:
				var at := Vector2(r * 0.45 * (1.0 if side % 2 == 0 else -1.0), -r).rotated(-rot)
				_root_tree_at(Vector3(at.x, ground(at.x, at.y) + 3.9, at.y), rot, 4.0)
	# The courtyards, knee-deep in tumbled blocks (§CJ.6).
	for k in 8:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(16.0, ro - 6.0)
		rubble(Vector3(cos(a) * rr, 0.0, sin(a) * rr), rng.randf_range(2.5, 4.5), 7)
	# The sanctum under the towers, its doorway on the front, the delve's
	# passage inside.
	_sanctum()
	# Root-trees on every third gopura.
	for i in gopuras.size():
		if i % 3 == 1:
			var gpi: Array = gopuras[i]
			var c: Vector3 = gpi[0]
			_root_tree_at(Vector3(c.x, ground(c.x, c.z) + float(gpi[2]), c.z), float(gpi[1]), float(gpi[2]))
	_camp_spot = Vector3(-ro * 0.5, ground(-ro * 0.5, -ro + 8.0), -ro + 8.0)


## A gate tower in the outer wall at `c` (local, y ignored), facing out
## along `rot`: piers and a lintel round a dark doorway, tiers diminishing
## upward, and on top a great serene face on each of its four sides
## (§DR.7); the front gate's corners a three-headed elephant.
func _face_gate(c: Vector3, rot: float, front: bool) -> void:
	var g := ground(c.x, c.z)
	var bs := Basis(Vector3.UP, -rot)
	var at := func(x: float, y: float, z: float) -> Vector3: return c + bs * Vector3(x, 0.0, z) + Vector3(0.0, g + y, 0.0)
	for sx: float in [-1.0, 1.0]:
		_pblock(at.call(sx * 3.4, 2.6, 0.0), Vector3(3.2, 5.2, 4.0), LATERITE.lerp(TEMPLE_STONES[0], 0.5), 0.5, -rot)
	_pblock(at.call(0.0, 5.7, 0.0), Vector3(10.0, 1.0, 4.4), TEMPLE_STONES[1], 0.7, -rot)
	var y := 6.2
	var w := 8.4
	for t in 3:
		var h := 1.8 - t * 0.3
		_pblock(at.call(0.0, y + h * 0.5, 0.0), Vector3(w, h, w * 0.5), TEMPLE_STONES[t % 5], 0.8, -rot)
		y += h
		w *= 0.72
	# The face tier: a block, a face on each side.
	var fs := 3.6
	_pblock(at.call(0.0, y + fs * 0.5, 0.0), Vector3(fs, fs, fs), FACE_STONE.darkened(0.15), 0.4, -rot)
	for k in 4:
		var fb := Basis(Vector3.UP, -rot + k * PI * 0.5)
		var fc := c + Vector3(0.0, g + y + fs * 0.5, 0.0) + fb * Vector3(0.0, 0.0, -fs * 0.5 - 0.12)
		box(Transform3D(fb, fc), Vector3(2.4, 2.9, 0.3), FACE_STONE, _growth(0.2), 0.35, 0.05)
		for ex in [-0.5, 0.5]:
			box(Transform3D(fb, fc + fb * Vector3(ex, 0.45, -0.16)), Vector3(0.55, 0.14, 0.1), FACE_STONE.darkened(0.45), 0.0, 0.03, 0.0)
		box(Transform3D(fb, fc + fb * Vector3(0.0, -0.05, -0.2)), Vector3(0.32, 0.7, 0.18), FACE_STONE.lightened(0.05), 0.0, 0.06, 0.0)
		box(Transform3D(fb, fc + fb * Vector3(0.0, -0.75, -0.16)), Vector3(0.9, 0.16, 0.12), FACE_STONE.darkened(0.3), 0.0, 0.04, 0.0)
	_pblock(at.call(0.0, y + fs + 0.9, 0.0), Vector3(1.4, 1.8, 1.4), TEMPLE_STONES[2], 0.6, -rot)
	if front:
		# The three-headed elephants at the gate's corners, pulling lotus
		# trunks from the wall.
		for sx: float in [-1.0, 1.0]:
			var e: Vector3 = at.call(sx * 5.6, 0.0, -2.4)
			var eb := Basis(Vector3.UP, -rot)
			box(Transform3D(eb, e + Vector3(0.0, 1.0, 0.0)), Vector3(1.6, 1.6, 2.2), TEMPLE_STONES[3], _growth(0.4), 0.3, 0.06)
			for hx in [-0.55, 0.0, 0.55]:
				var hp: Vector3 = e + eb * Vector3(hx, 1.55, -1.2)
				box(Transform3D(eb, hp), Vector3(0.55, 0.7, 0.55), TEMPLE_STONES[3].lightened(0.04), _growth(0.3), 0.15, 0.04)
				var tw := Basis(eb.x, 0.25) * eb
				box(Transform3D(tw, hp + eb * Vector3(0.0, -0.75, -0.25)), Vector3(0.22, 1.2, 0.22), TEMPLE_STONES[3], _growth(0.4), 0.06, 0.02)


## A gallery's gopura at `c` facing out along `rot`, scaled `s`: piers, a
## lintel over the dark doorway, two tiers.
func _gopura(c: Vector3, rot: float, s: float) -> void:
	var g := ground(c.x, c.z)
	var bs := Basis(Vector3.UP, -rot)
	for sx: float in [-1.0, 1.0]:
		_pblock(c + bs * Vector3(sx * 2.4 * s, 0.0, 0.0) + Vector3(0.0, g + 2.0 * s, 0.0), Vector3(2.0 * s, 4.0 * s, 5.0), TEMPLE_STONES[1], 0.5, -rot)
	_pblock(c + Vector3(0.0, g + 4.4 * s, 0.0), Vector3(6.8 * s, 0.9, 5.4), TEMPLE_STONES[2], 0.8, -rot)
	_pblock(c + Vector3(0.0, g + 5.4 * s, 0.0), Vector3(4.6 * s, 1.2, 3.6), TEMPLE_STONES[0], 0.9, -rot)
	_pblock(c + Vector3(0.0, g + 6.5 * s, 0.0), Vector3(2.6 * s, 1.0, 2.0), TEMPLE_STONES[3], 0.9, -rot)


## A relief on a gallery wall: a panel and a figure on it, a dancer (arms
## out) or a guardian (a staff), nobody's god by name (§BO).
func _relief(at: Vector2, rot: float, g: float, dancer: bool) -> void:
	var bs := Basis(Vector3.UP, -rot)
	var r2 := at.rotated(-rot)
	var c := Vector3(r2.x, 0.0, r2.y)
	var base := c + Vector3(0.0, g + 1.8, 0.0)
	box(Transform3D(bs, base), Vector3(1.4, 2.0, 0.12), TEMPLE_STONES[2].lightened(0.05), _growth(0.3), 0.03, 0.01)
	box(Transform3D(bs, base + bs * Vector3(0.0, -0.1, -0.1)), Vector3(0.3, 1.0, 0.08), TEMPLE_STONES[4].darkened(0.2), 0.0, 0.02, 0.0)
	box(Transform3D(bs, base + bs * Vector3(0.0, 0.55, -0.1)), Vector3(0.22, 0.24, 0.08), TEMPLE_STONES[4].darkened(0.2), 0.0, 0.02, 0.0)
	if dancer:
		box(Transform3D(bs, base + bs * Vector3(0.0, 0.25, -0.1)), Vector3(0.9, 0.1, 0.08), TEMPLE_STONES[4].darkened(0.2), 0.0, 0.02, 0.0)
	else:
		box(Transform3D(bs, base + bs * Vector3(0.3, 0.0, -0.1)), Vector3(0.08, 1.5, 0.08), TEMPLE_STONES[4].darkened(0.25), 0.0, 0.02, 0.0)


## The sanctum at the middle: four walls round the delve's way in (the
## barrow kit's passage and chamber, §CJ), a doorway on the front, the
## floor paved over the ground's hole, a roof, the central tower's tiers
## over it and four lesser towers at its corners.
func _sanctum() -> void:
	var hs := 7.0
	var h := 5.4
	var g0 := ground(0.0, 0.0)
	for side in 4:
		var rot := side * PI * 0.5
		var bs := Basis(Vector3.UP, -rot)
		if side == 0:
			for sx: float in [-1.0, 1.0]:
				_pblock(bs * Vector3(sx * (hs + 1.0) * 0.5 + sx * 0.6, 0.0, -hs) + Vector3(0.0, g0 + h * 0.5 - 0.4, 0.0), Vector3(hs - 1.2, h, 0.9), TEMPLE_STONES[1], 0.5, -rot)
			_pblock(bs * Vector3(0.0, 0.0, -hs) + Vector3(0.0, g0 + h - 0.6, 0.0), Vector3(2.4, 1.2, 0.9), TEMPLE_STONES[2], 0.6, -rot)
		else:
			_pblock(bs * Vector3(0.0, 0.0, -hs) + Vector3(0.0, g0 + h * 0.5 - 0.4, 0.0), Vector3(2.0 * hs + 0.9, h, 0.9), TEMPLE_STONES[side % 5], 0.5, -rot)
	_pblock(Vector3(0.0, g0 + h + 0.1, 0.0), Vector3(2.0 * hs + 1.6, 0.8, 2.0 * hs + 1.6), TEMPLE_STONES[0], 1.0)
	# The floor over the hole (the passage's own flags lie on it).
	_pave(Rect2(-hs, -hs, 2.0 * hs, 2.0 * hs), NAN, Rect2(-1.2, -hs, 2.4, 2.0 * hs))
	# The central tower's tiers, and four lesser towers.
	var y := g0 + h + 0.5
	var w := 11.0
	for t in 5:
		var th := 2.2 - t * 0.2
		_pblock(Vector3(0.0, y + th * 0.5, 0.0), Vector3(w, th, w), TEMPLE_STONES[t % 5], 0.9)
		y += th
		w *= 0.76
	_pblock(Vector3(0.0, y + 1.0, 0.0), Vector3(1.2, 2.0, 1.2), TEMPLE_STONES[2], 0.6)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var tc := Vector2(cos(a), sin(a)) * (hs + 9.0)
		var tg := ground(tc.x, tc.y)
		var ty := tg
		var tw := 5.2
		for t in 4:
			var th := 2.4 - t * 0.3
			_pblock(Vector3(tc.x, ty + th * 0.5, tc.y), Vector3(tw, th, tw), TEMPLE_STONES[(t + k) % 5], 0.8)
			ty += th
			tw *= 0.74
	# The delve's way in (Delves.layout: the barrow kit under it).
	if Delves.has_delve(site):
		_delve_build()


## A root-tree standing on the stone at local `foot` (§DR.2): kept for
## make_node to draw (the place's own fig, else nothing), and its roots
## poured down both sides of the wall to the ground, pale over the dark
## stone: a few thick tubes tapering as they go.
func _root_tree_at(foot: Vector3, rot: float, drop: float) -> void:
	var sp := root_species(map, site.dir)
	if sp == null:
		return
	_root_trees.append([foot, SpeciesDB.index_of(sp), clampf(sp.height_m.y * 0.75, 14.0, 30.0)])
	var bs := Basis(Vector3.UP, -rot)
	var was := solid
	solid = false
	for k in 7:
		var side := -1.0 if k % 2 == 0 else 1.0
		var spread := rng.randf_range(0.4, 2.6)
		var p0 := foot + bs * Vector3(rng.randf_range(-0.6, 0.6), 0.0, side * 0.5)
		var p1 := foot + bs * Vector3(rng.randf_range(-1.5, 1.5), -0.2, side * 2.5)
		var g := ground(p1.x, p1.z)
		var p2 := Vector3(p1.x, lerpf(p1.y, g, 0.55), p1.z) + bs * Vector3(rng.randf_range(-spread, spread), 0.0, side * 0.25)
		var p3 := Vector3(p2.x, ground(p2.x, p2.z) - 0.2, p2.z) + bs * Vector3(rng.randf_range(-0.8, 0.8), 0.0, side * rng.randf_range(0.5, 1.5))
		_root_tube([p0, p1, p2, p3], rng.randf_range(0.18, 0.32), 0.06, ROOT_BARK.darkened(rng.randf_range(0.0, 0.12)))
	solid = was


## A tapered tube along `pts` (local), five sided, from radius r0 to r1.
func _root_tube(pts: Array, r0: float, r1: float, col: Color) -> void:
	var n := pts.size()
	var rings: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var dirv: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := dirv.cross(Vector3.UP)
		if side.length() < 0.1:
			side = dirv.cross(Vector3.RIGHT)
		side = side.normalized()
		var up2 := side.cross(dirv).normalized()
		var r := lerpf(r0, r1, float(i) / maxf(n - 1, 1))
		var ring: Array = []
		for k in 5:
			var a := TAU * k / 5.0
			ring.append(p + (side * cos(a) + up2 * sin(a)) * r)
		rings.append(ring)
	for i in n - 1:
		for k in 5:
			var a0: Vector3 = rings[i][k]
			var a1: Vector3 = rings[i][(k + 1) % 5]
			var b0: Vector3 = rings[i + 1][k]
			var b1: Vector3 = rings[i + 1][(k + 1) % 5]
			_face(a0, a1, b1, b0, col, pts[i])


## The root-trees' species at `d`: of root_trees.genera (Ficus first; the
## silk-cotton once filled), the tallest tree passing the place's biome
## gate (HiddenPlaces.tree_gate), or null.
static func root_species(p_map: PlanetData, d: Vector3) -> PlantSpecies:
	var rt: Dictionary = Tuning.table("ruins").get("root_trees", {})
	var genera: Array = rt.get("genera", ["Ficus"])
	var best: PlantSpecies = null
	for sp in SpeciesDB.all():
		if not sp.tier in [PlantSpecies.Tier.EMERGENT, PlantSpecies.Tier.CANOPY] or not genera.has(sp.genus):
			continue
		if not HiddenPlaces.tree_gate(p_map, d, sp):
			continue
		if best == null or sp.height_m.y > best.height_m.y:
			best = sp
	return best


## Root-trees on any other old monument in the wet tropics (ruins.json
## root_trees: by_kind default_monument, one or two; never a camp's
## remains): on the highest wall tops the overgrowth found.
func _root_trees_elsewhere() -> void:
	var rt: Dictionary = Tuning.table("ruins").get("root_trees", {})
	if rt.is_empty() or int(site.kind) in [Ruins.Kind.TEMPLE_CITY, Ruins.Kind.LONG_WALL, Ruins.Kind.CARVED_CLIFFS, Ruins.Kind.CLIFF_DWELLING, Ruins.Kind.BRICK_CITY, Ruins.Kind.STONE_HEADS, Ruins.Kind.TERRACED_PUEBLO, Ruins.Kind.STONE_CIRCLE, Ruins.Kind.HEWN_TEMPLE, Ruins.Kind.HANGING_GARDENS, Ruins.Kind.ABBEY] or int(site.kind) in [Ruins.Kind.IGLOO, Ruins.Kind.TREEHOUSE, Ruins.Kind.BOARDWALK, Ruins.Kind.GRAVEYARD]:
		return
	var bkey: String = BiomeTemplates.KEYS[map.biome[map.cell_at(site.dir)]]
	if not (rt.get("biomes", []) as Array).has(bkey):
		return
	# The tops: faces of the built stone pointing up, a man's height or
	# more over the ground (one in a few, for speed).
	var tops: Array = []
	var i := 0
	while i + 2 < _v.size():
		if _n[i].y > 0.9:
			var c := (_v[i] + _v[i + 1] + _v[i + 2]) / 3.0
			var above := c.y - ground(c.x, c.z)
			if above > 2.5 and (_v[i] - _v[i + 1]).length() > 0.8:
				tops.append([above, c, Transform3D()])
		i += 9
	if tops.is_empty():
		return
	tops.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var want: Array = (rt.get("by_kind", {}) as Dictionary).get("default_monument", [1, 2])
	var n := rng.randi_range(int(want[0]), int(want[1]))
	var used: Array = []
	for t in tops:
		if used.size() >= n:
			break
		var p: Vector3 = t[1]
		var clash := false
		for u in used:
			if (u as Vector3).distance_to(p) < 6.0:
				clash = true
		if clash:
			continue
		used.append(p)
		var xf: Transform3D = t[2]
		_root_tree_at(p, atan2(xf.basis.x.z, xf.basis.x.x), float(t[0]))


# --- The long wall (design 3 Oct §DS.1) --------------------------------------------

## Local stone and rammed earth: a dun, a grey, an earthen core.
const WALL_STONES := [Color(0.5, 0.47, 0.42), Color(0.46, 0.44, 0.4), Color(0.53, 0.5, 0.44), Color(0.43, 0.41, 0.37), Color(0.49, 0.45, 0.38)]
const WALL_CORE := Color(0.5, 0.42, 0.32)
## A wall run's steps along the line, the parapet and the merlons.
const WALL_SEG_M := 6.0
const PARAPET_H := 1.1
const MERLON_H := 0.9


## A plain block (12 triangles, collision) with its own frame.
func _pbox(xf: Transform3D, size: Vector3, col: Color, moss: float) -> void:
	var was := plain
	plain = true
	var ft := foot_y
	foot_y = xf.origin.y - size.y * 0.5
	box(xf, size, col, _growth(moss))
	foot_y = ft
	plain = was


## A direction on the planet in this frame's local x/z.
func _local_of(d: Vector3) -> Vector2:
	var q := d - up * d.dot(up)
	return Vector2(q.dot(ex), q.dot(ez)) * PlanetConst.RADIUS_M


## The wall's state at `m` along its line: "full", "fallen" (with its
## height) or "gap".
func _wall_state(m: float) -> Array:
	for b in site.get("breaks", []):
		if m >= float(b[0]) and m <= float(b[1]):
			return [str(b[2]), float(b[3]) if b.size() > 3 else 0.0]
	return ["full", 0.0]


## The wall along its line from m0 to m1 (the site's line, in this frame):
## a body of stone WALL_SEG_M a step, its top `wall_h` over the lower of
## the ground either side and pitched with it (the walkway: the road on
## top, §DS.1), a parapet on the inner side and a crenellated one on the
## outer; down to its core where it has fallen, gone where there's a gap
## (rubble at the ends).
func _wall_run(m0: float, m1: float) -> void:
	var line: PackedVector3Array = site.line
	var h_full: float = site.wall_h
	var th: float = site.thick_m
	var m := m0
	var prev_state := ""
	while m < m1 - 0.3:
		var mb := minf(m + WALL_SEG_M, m1)
		var st := _wall_state((m + mb) * 0.5)
		if str(st[0]) != prev_state and prev_state != "" and (str(st[0]) == "gap" or prev_state == "gap"):
			var ep := _local_of(RoadNetwork.point_at(line, m))
			rubble(Vector3(ep.x, 0.0, ep.y), 3.5, 7)
		prev_state = str(st[0])
		if str(st[0]) == "gap":
			m = mb
			continue
		var a := _local_of(RoadNetwork.point_at(line, m))
		var b := _local_of(RoadNetwork.point_at(line, mb))
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x) * (th * 0.5)
		var ga := minf(ground(a.x + side.x, a.y + side.y), ground(a.x - side.x, a.y - side.y))
		var gb := minf(ground(b.x + side.x, b.y + side.y), ground(b.x - side.x, b.y - side.y))
		var h := h_full if str(st[0]) == "full" else float(st[1])
		var a3 := Vector3(a.x, ga + h, a.y)
		var b3 := Vector3(b.x, gb + h, b.y)
		var dv := b3 - a3
		var ln := dv.length()
		if ln < 0.05:
			m = mb
			continue
		var xa := dv / ln
		var za := xa.cross(Vector3.UP).normalized()
		var ya := za.cross(xa).normalized()
		var bs := Basis(xa, ya, za)
		var mid := (a3 + b3) * 0.5
		var col: Color = palette[rng.randi() % palette.size()]
		var body_h := h + 3.0
		_pbox(Transform3D(bs, mid - ya * body_h * 0.5), Vector3(ln + 0.5, body_h, th), col if str(st[0]) == "full" else WALL_CORE, 0.25)
		if str(st[0]) == "full":
			# The inner parapet, and the outer one with its merlons.
			_pbox(Transform3D(bs, mid + ya * PARAPET_H * 0.5 + za * (th * 0.5 - 0.25)), Vector3(ln + 0.4, PARAPET_H, 0.5), col.darkened(0.05), 0.35)
			_pbox(Transform3D(bs, mid + ya * 0.3 - za * (th * 0.5 - 0.25)), Vector3(ln + 0.4, 0.6, 0.5), col.darkened(0.08), 0.35)
			for k in 2:
				var u := (k + 0.5) / 2.0 - 0.5
				_pbox(Transform3D(bs, mid + xa * u * ln + ya * (0.6 + MERLON_H * 0.5) - za * (th * 0.5 - 0.25)), Vector3(ln * 0.28, MERLON_H, 0.5), col.darkened(0.1), 0.4)
		m = mb


## A tower on the wall at `m` along its line: a square of stone astride it,
## its roof a platform with merlons; a stump and a heap where it fell.
func _wall_tower(m: float, fallen: bool) -> void:
	var line: PackedVector3Array = site.line
	var total := RoadNetwork.length_m(line)
	var p := _local_of(RoadNetwork.point_at(line, m))
	var q := _local_of(RoadNetwork.point_at(line, clampf(m + 4.0, 0.0, total)))
	var q0 := _local_of(RoadNetwork.point_at(line, clampf(m - 4.0, 0.0, total)))
	var along := (q - q0).normalized()
	var rot := atan2(-along.y, along.x)
	var w := 8.5
	var g := INF
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var c: Vector2 = p + along * cx * w * 0.5 + Vector2(-along.y, along.x) * cz * w * 0.5
			g = minf(g, ground(c.x, c.y))
	var h: float = float(site.wall_h) + 4.5
	if fallen:
		h = rng.randf_range(1.5, 3.0)
	var bs := Basis(Vector3.UP, rot)
	var col: Color = palette[rng.randi() % palette.size()]
	_pbox(Transform3D(bs, Vector3(p.x, g - 3.0 + (h + 3.0) * 0.5, p.y)), Vector3(w, h + 3.0, w), col, 0.3)
	if fallen:
		rubble(Vector3(p.x, 0.0, p.y), 7.0, 14)
		return
	# Its roof's merlons, three a side, and a dark loophole on each face.
	for side in 4:
		var sb := Basis(Vector3.UP, rot + side * PI * 0.5)
		for k in 3:
			var u := (k - 1) * w * 0.34
			_pbox(Transform3D(sb, Vector3(p.x, g + h + MERLON_H * 0.5, p.y) + sb * Vector3(u, 0.0, w * 0.5 - 0.3)), Vector3(w * 0.2, MERLON_H, 0.6), col.darkened(0.1), 0.4)
		_pbox(Transform3D(sb, Vector3(p.x, g + h - 2.0, p.y) + sb * Vector3(0.0, 0.0, w * 0.5 + 0.02)), Vector3(0.5, 1.2, 0.06), Color(0.06, 0.06, 0.07), 0.0)


## A stretch of the long wall between two of its towers (LongWalls streams
## them): the run, and the tower at its end (and its start, the first
## one), the gate's own stretch left to the gate.
func _long_wall_piece() -> void:
	palette = WALL_STONES
	var pc: Array = site.piece
	var m0 := float(pc[0])
	var m1 := float(pc[1])
	_lod_m = (m1 - m0) * 0.5 + LOD_M
	var gs: Array = site.gate_span
	var fallen: Array = site.get("fallen_towers", [])
	# The run, around the gate's stretch.
	if m1 <= float(gs[0]) or m0 >= float(gs[1]):
		_wall_run(m0, m1)
	else:
		if m0 < float(gs[0]):
			_wall_run(m0, float(gs[0]))
		if m1 > float(gs[1]):
			_wall_run(float(gs[1]), m1)
	var gate_m := float(site.gate_m)
	for tm in [m0, m1]:
		if absf(float(tm) - gate_m) < 1.0:
			continue
		# Each tower once: the end of its stretch (the very first one by
		# the first stretch too).
		if float(tm) == m0 and m0 > 0.0:
			continue
		_wall_tower(float(tm), fallen.any(func(f): return absf(float(f) - float(tm)) < 1.0))


## The long wall's gate (the site Ruins.find gives, §DS.1): the gate tower
## astride the wall, hollow, its door on the outer face and the way down
## into its vaults inside it (the barrow kit, Delves.layout: rooms, the
## heart in the undercroft, a postern out on the far side); the gateway
## through the wall beside it, a lintel over the road; and a stair of
## stone up the inner face to the walkway on the other side.
func _long_wall_gate() -> void:
	palette = WALL_STONES
	var gs: Array = site.gate_span
	var gate_m := float(site.gate_m)
	var wh: float = site.wall_h
	_lod_m = float(site.footprint_m) + LOD_M
	# The wall either side: up to the tower, the gateway's two cheeks and
	# its lintel on the far side.
	var gw0 := gate_m + 10.5
	var gw1 := gate_m + 14.5
	_wall_run(float(gs[0]), gate_m - 7.5)
	_wall_run(gate_m + 7.5, gw0)
	_wall_run(gw1, float(gs[1]))
	var line: PackedVector3Array = site.line
	var la := _local_of(RoadNetwork.point_at(line, gw0))
	var lb := _local_of(RoadNetwork.point_at(line, gw1))
	var lmid := (la + lb) * 0.5
	var lal := (lb - la).normalized()
	var lg := ground(lmid.x, lmid.y)
	_pbox(Transform3D(Basis(Vector3.UP, atan2(-lal.y, lal.x)), Vector3(lmid.x, lg + 4.2 + (wh - 4.2) * 0.5 + 0.3, lmid.y)), Vector3(gw1 - gw0 + 1.0, wh - 4.2 + 0.6, float(site.thick_m)), WALL_STONES[2], 0.3)
	# The stair up the inner face behind the tower.
	var s0 := gate_m - 9.0
	var steps := int(ceil(wh / 0.5))
	for k in steps:
		var sm := s0 - k * 0.65
		var sp := _local_of(RoadNetwork.point_at(line, sm))
		var sq := _local_of(RoadNetwork.point_at(line, sm - 1.0))
		var sal := (sp - sq).normalized()
		var inner := Vector2(-sal.y, sal.x) * (float(site.thick_m) * 0.5 + 0.8)
		var c := sp + inner
		var gy := ground(c.x, c.y)
		var top := minf(gy + (k + 1) * 0.5, gy + wh)
		_pbox(Transform3D(Basis(Vector3.UP, atan2(-sal.y, sal.x)), Vector3(c.x, (gy - 1.0 + top) * 0.5, c.y)), Vector3(0.75, top - gy + 1.0, 1.6), WALL_STONES[k % 5], 0.3)
	# The gate tower: four walls round the way down, its door on the outer
	# face (-z), a floor over the hole, a roof with merlons.
	var hs := 7.0
	var h := wh + 6.0
	var g0 := ground(0.0, 0.0)
	for side in 4:
		var rot := side * PI * 0.5
		var bs := Basis(Vector3.UP, -rot)
		if side == 0:
			for sx: float in [-1.0, 1.0]:
				_pblock(bs * Vector3(sx * (hs + 1.0) * 0.5 + sx * 0.6, 0.0, -hs) + Vector3(0.0, g0 + h * 0.5 - 1.5, 0.0), Vector3(hs - 1.2, h + 3.0, 0.9), WALL_STONES[1], 0.4, -rot)
			_pblock(bs * Vector3(0.0, 0.0, -hs) + Vector3(0.0, g0 + 3.2 + (h - 3.2) * 0.5, 0.0), Vector3(2.4, h - 3.2, 0.9), WALL_STONES[2], 0.5, -rot)
		else:
			_pblock(bs * Vector3(0.0, 0.0, -hs) + Vector3(0.0, g0 + h * 0.5 - 1.5, 0.0), Vector3(2.0 * hs + 0.9, h + 3.0, 0.9), WALL_STONES[side % 5], 0.4, -rot)
		for k in 4:
			var u := (k - 1.5) * hs * 0.5
			_pblock(bs * Vector3(u, 0.0, -hs) + Vector3(0.0, g0 + h + MERLON_H * 0.5, 0.0), Vector3(hs * 0.3, MERLON_H, 0.9), WALL_STONES[(k + side) % 5].darkened(0.1), 0.5, -rot)
	_pblock(Vector3(0.0, g0 + h - 0.4, 0.0), Vector3(2.0 * hs + 1.0, 0.8, 2.0 * hs + 1.0), WALL_STONES[0], 0.8)
	_pave(Rect2(-hs, -hs, 2.0 * hs, 2.0 * hs), NAN, Rect2(-1.2, -hs, 2.4, 2.0 * hs))
	if Delves.has_delve(site):
		_delve_build()


# --- The northern styles (design 3 Oct §DS) -----------------------------------------

## Harl: the lime render on a tower house's rubble, weathered pale (§DS).
const HARL := [Color(0.53, 0.52, 0.48), Color(0.49, 0.49, 0.46), Color(0.55, 0.53, 0.47)]
## A broch's drystone: dark grey flags (§DS).
const FLAGS := [Color(0.38, 0.39, 0.43), Color(0.34, 0.35, 0.4), Color(0.42, 0.42, 0.45), Color(0.31, 0.33, 0.38)]
const SLATE := Color(0.24, 0.26, 0.33)


## Is this ruin one of the northern styles (the tower house, the broch)?
func _northern() -> bool:
	return str(site.get("style", "")) in ["tower_house", "broch"]


## A tower house (§DS, ruins.json styles.tower_house): a tall narrow keep
## of harled rubble, keep_h high, its door on the -z face over the way
## down (the barrow kit, Delves: the undercroft, the pit prison below,
## a postern out), slit windows, a corbelled parapet, two bartizans on
## opposite corners, a chimney stack on the back gable, one back corner
## fallen in; round it a low barmkin wall, its gate before the door.
func _tower_house() -> void:
	palette = STONES
	var hx: float = site.keep_hx
	var hz: float = site.keep_hz
	var kh: float = site.keep_h
	var bs: float = site.barmkin_hs
	var t := 1.0
	_lod_m = bs * 1.5 + LOD_M
	_lit_per_pixel = true
	var corners := [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
	# One back corner fallen in (the door's face stands).
	var broken := 2 + rng.randi() % 2
	var cb: Vector2 = corners[broken]
	var keep_top := INF
	inside_at = Vector3.ZERO
	inside = INSIDE
	for f in 4:
		var a: Vector2 = corners[f]
		var b: Vector2 = corners[(f + 1) % 4]
		var along := (b - a).normalized()
		var n := Vector2(along.y, -along.x)
		# The x faces run between the z faces (no faces lying in one plane).
		if f % 2 == 1:
			a += along * t
			b -= along * t
		var runs: Array = [[0.0, a.distance_to(b)]]
		if f == 0:
			var mid := a.distance_to(b) * 0.5
			runs = [[0.0, mid - 0.9], [mid - 0.9, mid + 0.9], [mid + 0.9, a.distance_to(b)]]
		for r in runs:
			var r0: float = r[0]
			var r1: float = r[1]
			var door: bool = f == 0 and runs.size() == 3 and r == runs[1]
			var cols := maxi(1, int(ceil((r1 - r0) / 1.5)))
			var w := (r1 - r0) / cols
			for k in cols:
				var u := r0 + (k + 0.5) * w
				var c := a + along * u - n * t * 0.5
				var g := minf(ground(c.x, c.y), minf(ground(c.x + n.x * t * 0.5, c.y + n.y * t * 0.5), ground(c.x - n.x * t * 0.5, c.y - n.y * t * 0.5)))
				var dfall := c.distance_to(cb)
				var h := kh * lerpf(0.3, 1.0, smoothstep(1.5, 7.5, dfall)) - rng.randf_range(0.0, 0.5)
				var bs3 := Basis(Vector3.UP, atan2(-along.y, along.x))
				var y := g - 0.4
				if door:
					# The doorway: its lintel and the wall over it.
					y = g + 2.6
					jamb = JAMB
				# Bands of harl, the rubble showing where it has fallen.
				while y < g + h - 0.05:
					var top := minf(y + rng.randf_range(2.0, 3.2), g + h)
					var bare := rng.randf() < 0.3 + 0.35 * exp(-(y - g) / 3.0)
					var col: Color = (STONES[rng.randi() % STONES.size()] as Color) if bare else (HARL[rng.randi() % HARL.size()] as Color).darkened(rng.randf_range(0.0, 0.08))
					var moss := 0.1 + 0.45 * exp(-(y - g) / 2.0) + (0.15 if bare else 0.0)
					_pbox(Transform3D(bs3, Vector3(c.x, (y + top) * 0.5, c.y)), Vector3(w + 0.02, top - y, t), col, moss)
					y = top
				jamb = 0.0
				keep_top = minf(keep_top, g + h) if dfall > 7.5 else keep_top
				# Slit windows up its face (R8: voids read dark).
				if not door and k % 2 == 1:
					var sy := g + 3.4
					while sy < g + h - 2.0:
						if rng.randf() < 0.55:
							var big := sy > g + kh * 0.6
							var o := c + n * (t * 0.5 + 0.02)
							_pbox(Transform3D(bs3, Vector3(o.x, sy, o.y)), Vector3(0.6 if big else 0.22, 1.0 if big else 1.1, 0.06), VOID, 0.0)
						sy += rng.randf_range(2.8, 3.6)
				# The corbelled parapet where the wall stands to its height.
				if dfall > 7.5 and h > kh - 0.6:
					var oc := c + n * 0.55
					for q: float in [-0.25, 0.25]:
						var qc := oc + along * q * w
						_pbox(Transform3D(bs3, Vector3(qc.x, g + h - 0.35, qc.y)), Vector3(0.35, 0.6, 0.7), STONES[(k + int(q * 4.0) + 4) % STONES.size()], 0.2)
					var pc := c + n * 0.7
					_pbox(Transform3D(bs3, Vector3(pc.x, g + h + 0.5, pc.y)), Vector3(w + 0.04, 1.3, 0.5), HARL[k % HARL.size()], 0.25)
	inside = 0.0
	inside_at = Vector3.INF
	# The bartizans: little round turrets corbelled out at two corners.
	var bartizan_at := [0, 5 - broken]
	for ci in bartizan_at:
		var cc: Vector2 = corners[ci]
		var out := Vector2(signf(cc.x), signf(cc.y)) * 0.45
		var bc := cc + out
		var gy := ground(cc.x, cc.y)
		var by := gy + kh - 1.4
		for rot: float in [0.0, PI * 0.25]:
			_pbox(Transform3D(Basis(Vector3.UP, rot), Vector3(bc.x, by + 1.3, bc.y)), Vector3(1.9, 2.6, 1.9), HARL[ci % HARL.size()], 0.2)
			_pbox(Transform3D(Basis(Vector3.UP, rot), Vector3(bc.x, by - 0.4, bc.y)), Vector3(1.3, 0.8, 1.3), STONES[1], 0.3)
		for k in 3:
			var sz := 1.7 - k * 0.55
			_pbox(Transform3D(Basis(Vector3.UP, PI * 0.25 * k), Vector3(bc.x, by + 2.6 + 0.35 + k * 0.6, bc.y)), Vector3(sz, 0.62, sz), SLATE, 0.1)
		# A slit in each.
		var so := bc + out.normalized() * 0.97
		_pbox(Transform3D(Basis(Vector3.UP, atan2(-out.x, out.y)), Vector3(so.x, by + 1.4, so.y)), Vector3(0.2, 0.9, 0.06), VOID, 0.0)
	# The chimney stack on the back gable, where the corner left it.
	var chim := Vector2(-hx * 0.45 if broken == 2 else hx * 0.45, hz - t * 0.5)
	var cg := ground(chim.x, chim.y)
	if chim.distance_to(cb) > 7.5:
		_pbox(Transform3D(Basis.IDENTITY, Vector3(chim.x, cg + kh + 1.2, chim.y)), Vector3(1.5, 2.6, 1.0), HARL[1], 0.25)
		_pbox(Transform3D(Basis.IDENTITY, Vector3(chim.x, cg + kh + 2.6, chim.y)), Vector3(1.7, 0.3, 1.2), STONES[3], 0.2)
	rubble(Vector3(cb.x * 1.35, 0, cb.y * 1.25), 4.5, 22)
	# The barmkin: a low wall round the yard, its gate before the door; a
	# gap where the way out comes up (the postern).
	var lay: Dictionary = Delves.layout(map, site)
	var holes: Array = []
	var cairn: Dictionary = lay.get("cairn", {})
	if not cairn.is_empty():
		var mid: Vector2 = (cairn.o as Vector2) - (cairn.dir as Vector2) * (float(cairn.back) * 0.5 - 2.0)
		holes.append([mid, maxf(float(cairn.back) * 0.5, float(cairn.half)) + 2.5])
	var bk := [Vector2(-bs, -bs), Vector2(bs, -bs), Vector2(bs, bs), Vector2(-bs, bs)]
	var breach_side := 1 + rng.randi() % 3
	for f in 4:
		var a: Vector2 = bk[f]
		var b: Vector2 = bk[(f + 1) % 4]
		var cuts: Array = [[0.0, 1.0]]
		if f == 0:
			cuts = [[0.0, (bs - 1.8) / (2.0 * bs)], [(bs + 1.8) / (2.0 * bs), 1.0]]
		for hc in holes:
			var p: Vector2 = hc[0]
			var rr: float = hc[1]
			var tt := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if (a + (b - a) * tt).distance_to(p) < rr:
				var dt := rr / (b - a).length()
				var nc: Array = []
				for c in cuts:
					if tt - dt > c[0]:
						nc.append([c[0], minf(c[1], tt - dt)])
					if tt + dt < c[1]:
						nc.append([maxf(c[0], tt + dt), c[1]])
				cuts = nc
		for c in cuts:
			if float(c[1]) - float(c[0]) < 0.03:
				continue
			var br: Array = []
			if f == breach_side and c == cuts[0]:
				br = [[0.3, 0.55]]
			wall(a.lerp(b, c[0]), a.lerp(b, c[1]), rng.randf_range(2.4, 3.2), 0.9, br, 0.35)
	# The gate's piers.
	for sx: float in [-1.0, 1.0]:
		var gp := Vector2(sx * 2.4, -bs)
		var gg := ground(gp.x, gp.y)
		_pbox(Transform3D(Basis.IDENTITY, Vector3(gp.x, gg + 1.5, gp.y)), Vector3(1.2, 3.8, 1.2), HARL[2], 0.35)
	if Delves.has_delve(site):
		_delve_build()


## A broch (§DS, ruins.json styles.broch): a drystone round tower,
## height_m on a base of base_m, its outer skin drawing in as it rises,
## a gallery between it and the inner skin floored with flags every few
## metres, the voids stacked over the court's side of the door, an arc
## fallen away (the outer skin lower, the gallery showing), its door on
## the +x side; a hearth in the middle of the court under the open sky
## (the camp spot). Its delve, the souterrain, opens beside it on the -z
## side (the barrow kit: the passage, the stair going down under the
## broch, the end chamber the heart, its second mouth the way out).
func _broch() -> void:
	palette = FLAGS
	var ro: float = site.outer_r
	var ri: float = site.inner_r
	var hb: float = site.height_m
	_lod_m = float(site.footprint_m) + LOD_M
	_lit_per_pixel = true
	_tower_r = ro
	# Shelters, when folk live here, go on the +z side (_camp).
	_stub_angle = -PI * 0.5
	var door_a := 0.0
	var slump_a := PI + rng.randf_range(-0.4, 0.4)
	var band := 1.0
	var gap0 := ri + 1.3
	var gap1 := ro - 1.4
	inside_at = Vector3.ZERO
	inside = INSIDE
	# [centre radius at the foot, thickness, draw-in at the top, fallen share]
	var skins := [[ro - 0.7, 1.4, 1.3, 0.75], [ri + 0.65, 1.3, 0.5, 0.5]]
	var tops := {}
	for si in 2:
		var rc: float = skins[si][0]
		var th: float = skins[si][1]
		var lean: float = skins[si][2]
		var fall: float = skins[si][3]
		var segs := maxi(12, int(TAU * rc / 1.8))
		for i in segs:
			var a := TAU * (i + 0.5) / segs
			var near := (cos(a - slump_a) + 1.0) * 0.5
			var h := hb * (1.0 - smoothstep(0.55, 1.0, near) * fall) - rng.randf_range(0.0, 0.7)
			var door := absf(angle_difference(a, door_a)) * rc < 0.9
			var face := Basis(Vector3.UP, -a + PI * 0.5)
			var p0 := Vector2(cos(a), sin(a))
			var g := minf(ground(p0.x * (rc - th * 0.5), p0.y * (rc - th * 0.5)), ground(p0.x * (rc + th * 0.5), p0.y * (rc + th * 0.5)))
			var y := g - 0.5
			if si == 0:
				tops[i] = g + h
			while y < g + h - 0.05:
				var top := minf(y + band, g + h)
				if door and top <= g + 2.3:
					y = top
					continue
				var f := clampf((y - g) / hb, 0.0, 1.0)
				var r := rc - lean * pow(f, 1.6)
				var bw := TAU * r / segs * 1.04
				var c := p0 * r
				var col: Color = (FLAGS[(i + int(y)) % FLAGS.size()] as Color).darkened(rng.randf_range(0.0, 0.07))
				var moss := 0.12 + 0.5 * exp(-(y - g) / 1.6) + rng.randf_range(0.0, 0.15)
				_pbox(Transform3D(face, Vector3(c.x, (y + top) * 0.5, c.y)), Vector3(bw, top - y + 0.02, th), col, moss)
				y = top
		# The gallery's floors: flags across between the skins, every
		# 2.6 m, where both still stand.
		if si == 1:
			var og := maxi(12, int(TAU * (gap0 + gap1) * 0.5 / 1.8))
			for i in og:
				if i % 2 == 1:
					continue
				var a := TAU * (i + 0.5) / og
				var near := (cos(a - slump_a) + 1.0) * 0.5
				var hmin := hb * (1.0 - smoothstep(0.55, 1.0, near) * 0.75)
				var rm := (gap0 + gap1) * 0.5
				var p0 := Vector2(cos(a), sin(a))
				var g := ground(p0.x * rm, p0.y * rm)
				var fy := 2.6
				while fy < hmin - 1.0:
					var f := fy / hb
					var r := rm - 0.9 * pow(f, 1.6)
					_pbox(Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(p0.x * r, g + fy, p0.y * r)), Vector3(TAU * r / og * 1.02, 0.22, gap1 - gap0 + 0.7), FLAGS[2], 0.2)
					fy += 2.6
	inside = 0.0
	inside_at = Vector3.INF
	# The door's lintel through the wall, and the voids stacked over it on
	# the court's side.
	var gd := ground(ro * 0.5 + ri * 0.5, 0.0)
	_pbox(Transform3D(Basis.IDENTITY, Vector3((ro + ri) * 0.5, gd + 2.45, 0.0)), Vector3(ro - ri + 0.2, 0.35, 2.0), FLAGS[3], 0.2)
	var vy := gd + 3.6
	while vy < hb - 1.5:
		_pbox(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(ri - 0.03, vy, 0.0)), Vector3(0.8, 1.2, 0.06), VOID, 0.0)
		vy += 2.6
	rubble(Vector3(cos(slump_a) * (ro + 2.5), 0.0, sin(slump_a) * (ro + 2.5)), 4.5, 24)
	rubble(Vector3(cos(slump_a) * ri * 0.5, 0.0, sin(slump_a) * ri * 0.5), 2.0, 6)
	if Delves.has_delve(site):
		_delve_build()


# --- The carved cliffs (design 3 Oct §DS.2) ----------------------------------------

const VOID := Color(0.04, 0.035, 0.04)


## The facades cut into the canyon wall (Monuments._carved_cliffs): each
## a mass of the wall's own sandstone standing sheer from the wall's foot
## (its back in the slope; where it's taller than the wall, rising over
## the rim), and on its face, in relief, a plinth, columns with capitals,
## an entablature, a stepped pediment, an upper order on the tall ones, a
## dark doorway (R8: a void) with soot over it. The tombs behind the middle
## facade's door are the delve (the barrow kit going in and down; a shaft
## up to the rim its way out).
func _carved_cliffs() -> void:
	palette = SANDSTONE
	var fs: Array = site.facades
	_lod_m = float(site.footprint_m) + LOD_M
	for i in fs.size():
		var f: Dictionary = fs[i]
		var p := _local_of(f.dir)
		var q := _local_of(CreatureSpawner._offset(f.dir, float(f.into), 1.0))
		var into := (q - p).normalized()
		var a := atan2(into.x, into.y)
		var bs := Basis(Vector3.UP, a)
		var w: float = f.w
		var h: float = f.h
		var g := INF
		for u in [-0.5, 0.0, 0.5]:
			var gp: Vector2 = p + Vector2(into.y, -into.x) * w * float(u)
			g = minf(g, ground(gp.x, gp.y))
		var o := Vector3(p.x, g, p.y)
		var mid := i == int(site.mid)
		var stone: Color = SANDSTONE[i % SANDSTONE.size()]
		# The rock mass: sheer in front, its back deep in the slope; the
		# middle one stands on the ground, over the way in.
		var deep := clampf(h * 1.2, 6.0, 22.0)
		var bury := 0.2 if mid else 2.5
		_pbox(Transform3D(bs, o + bs * Vector3(0.0, (h + 1.5 - bury) * 0.5, deep * 0.5)), Vector3(w + 3.0, h + 1.5 + bury, deep), stone.darkened(0.06), 0.15)
		var cols := int(f.cols)
		var hc := h * 0.5
		# Plinth, columns and capitals.
		_pbox(Transform3D(bs, o + bs * Vector3(0.0, 0.4, -0.25)), Vector3(w, 0.8, 0.5), stone, 0.1)
		for k in cols:
			var x := lerpf(-w * 0.5 + 0.7, w * 0.5 - 0.7, float(k) / float(cols - 1))
			_pbox(Transform3D(bs, o + bs * Vector3(x, 0.8 + hc * 0.5, -0.3)), Vector3(0.75, hc, 0.6), stone.lightened(0.04), 0.1)
			_pbox(Transform3D(bs, o + bs * Vector3(x, 0.8 + hc + 0.2, -0.36)), Vector3(1.05, 0.4, 0.72), stone, 0.1)
		var ye := 0.8 + hc + 0.4
		_pbox(Transform3D(bs, o + bs * Vector3(0.0, ye + 0.45, -0.32)), Vector3(w, 0.9, 0.64), stone.darkened(0.03), 0.15)
		# The stepped pediment.
		var yp := ye + 0.9
		for st in 4:
			var pw := w * (1.0 - st * 0.24)
			_pbox(Transform3D(bs, o + bs * Vector3(0.0, yp + 0.25, -0.28)), Vector3(pw, 0.5, 0.56), stone, 0.15)
			yp += 0.5
		# An upper order on the tall ones: four slimmer columns, a band.
		if bool(f.upper) and h - yp > 3.0:
			var hu := h - yp - 1.0
			for k in 4:
				var x := lerpf(-w * 0.32, w * 0.32, float(k) / 3.0)
				_pbox(Transform3D(bs, o + bs * Vector3(x, yp + 0.2 + hu * 0.5, -0.26)), Vector3(0.6, hu, 0.52), stone.lightened(0.04), 0.1)
			_pbox(Transform3D(bs, o + bs * Vector3(0.0, yp + 0.2 + hu + 0.35, -0.3)), Vector3(w * 0.75, 0.7, 0.6), stone.darkened(0.03), 0.15)
		# The doorway (a void) and the soot over it; dark niches either side
		# on the wide ones.
		var dh := minf(4.0, hc * 0.85)
		_pbox(Transform3D(bs, o + bs * Vector3(0.0, 0.8 + dh * 0.5, -0.62)), Vector3(2.0, dh, 0.06), VOID, 0.0)
		_pbox(Transform3D(bs, o + bs * Vector3(0.0, 0.8 + dh + 0.6, -0.61)), Vector3(2.6, 1.6, 0.05), stone.darkened(0.55), 0.0)
		if cols == 6:
			for sx in [-1.0, 1.0]:
				_pbox(Transform3D(bs, o + bs * Vector3(float(sx) * w * 0.3, 0.8 + dh * 0.35, -0.62)), Vector3(1.0, dh * 0.6, 0.06), VOID, 0.0)
		# A creeper in a crack (§DI's dry row: lichen comes with the stone).
		if bool(f.creeper):
			ivy(o + bs * Vector3(w * 0.5 + 0.6, h, -0.1), bs * Vector3(0.0, 0.0, -1.0), rng.randf_range(4.0, minf(9.0, h)))
	if Delves.has_delve(site):
		_delve_build()


# --- The cliff dwelling (design 3 Oct §DS.4) ---------------------------------------

const ROOM_H := 2.2
const PUEBLO := [Color(0.66, 0.52, 0.38), Color(0.62, 0.49, 0.36), Color(0.7, 0.56, 0.41), Color(0.58, 0.46, 0.34), Color(0.64, 0.5, 0.35)]


## The town in its alcove (Monuments._cliff_dwelling): the alcove itself
## (§CK: anything with a roof is a mesh): a back wall of the face's
## sandstone, its ends, and the overhang over it all, its lip hanging at
## the drip line; then the rooms of fitted stone in their storeys (a dark
## T-shaped door on each, beam ends under the top ones), the round towers,
## the ladders, the kivas in the plaza (rings of stone round a dark pit,
## a ladder up out of each), the way down at the alcove's back (the barrow
## kit: the stores cut under the rooms, the heart under the plaza with the
## great kiva's ring over it, a way up out past the plaza). The alcove is
## its roof, so the stone stands nearly whole.
func _cliff_dwelling() -> void:
	palette = PUEBLO
	var w: float = site.alcove_w
	var dd: float = site.alcove_d
	_lod_m = float(site.footprint_m) + LOD_M
	# +z runs out of the face: the alcove's back at z 0, the drip line at
	# dd, the plateau over the face behind (-z).
	var y0 := ground(0.0, 4.0)
	var yt := maxf(ground(0.0, -8.0), maxf(ground(0.0, -12.0), ground(0.0, -16.0)))
	var yu := clampf(yt - 2.5, y0 + float(site.storeys) * ROOM_H + 2.5, y0 + 14.0)
	var top := maxf(yt + 0.4, yu + 2.8)
	var rock: Color = SANDSTONE[3]
	# The back wall, the ends, the overhang and its lip.
	_pbox(Transform3D(Basis(), Vector3(0.0, (y0 - 2.0 + yu + 0.5) * 0.5, -1.6)), Vector3(w + 6.0, yu + 0.5 - y0 + 2.0, 3.2), rock, 0.1)
	for sx: float in [-1.0, 1.0]:
		_pbox(Transform3D(Basis(), Vector3(sx * (w * 0.5 + 1.8), (y0 - 2.0 + yu + 0.5) * 0.5, dd * 0.35)), Vector3(3.6, yu + 0.5 - y0 + 2.0, dd * 0.7 + 3.2), rock.darkened(0.04), 0.1)
	_pbox(Transform3D(Basis(), Vector3(0.0, (yu + top) * 0.5, dd * 0.5 - 1.5)), Vector3(w + 8.0, top - yu, dd + 3.0), rock.darkened(0.08), 0.2)
	_pbox(Transform3D(Basis(), Vector3(0.0, yu - 0.5, dd - 1.0)), Vector3(w + 6.0, 1.2, 2.0), rock.darkened(0.12), 0.25)
	for sx: float in [-1.0, 1.0]:
		_pbox(Transform3D(Basis(), Vector3(sx * (w * 0.5 + 1.0), yu - 0.9, dd * 0.5)), Vector3(3.0, 2.0, dd), rock.darkened(0.1), 0.2)
	# The rooms, storey on storey (each a little back toward the face), a
	# T-shaped door on each one's front.
	for rm in site.rooms:
		var x := float(rm[0])
		var z := float(rm[1])
		var st := int(rm[2])
		var g := ground(x, z)
		for s in st:
			var col: Color = PUEBLO[rng.randi() % PUEBLO.size()]
			var setback := s * 0.15
			_pbox(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)), Vector3(x, g + ROOM_H * 0.5 + s * ROOM_H - 0.1, z - setback)), Vector3(3.1, ROOM_H, 2.9 - setback), col, 0.05)
			var fz := z - setback + (2.9 - setback) * 0.5 + 0.03
			var dy := g + s * ROOM_H
			_pbox(Transform3D(Basis(), Vector3(x, dy + 0.65, fz)), Vector3(0.55, 1.0, 0.06), VOID, 0.0)
			_pbox(Transform3D(Basis(), Vector3(x, dy + 1.3, fz)), Vector3(1.0, 0.45, 0.06), VOID, 0.0)
		# Beam ends under the top storey's roof.
		var by := g + st * ROOM_H - 0.25
		for bx in [-0.9, 0.9]:
			_pbox(Transform3D(Basis(), Vector3(x + float(bx), by, z + 1.6)), Vector3(0.16, 0.16, 0.5), OLD_WOOD, 0.0)
	# The round towers: eight stones of wall round each, a door on the front.
	for tw in site.towers_round:
		var c := Vector2(float(tw[0]), float(tw[1]))
		var r := float(tw[2])
		var g := ground(c.x, c.y)
		var h := float(site.storeys) * ROOM_H + 1.6
		for k in 8:
			var a := k * TAU / 8.0
			var p := c + Vector2(cos(a), sin(a)) * r
			_pbox(Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(p.x, g + h * 0.5 - 0.2, p.y)), Vector3(r * 0.85, h, 0.6), PUEBLO[k % 5], 0.05)
		_pbox(Transform3D(Basis(), Vector3(c.x, g + h * 0.5 - 1.0, c.y + r + 0.32)), Vector3(0.45, 0.7, 0.06), VOID, 0.0)
	# Ladders against the upper storeys.
	for ld in site.ladders:
		var lx := float(ld[0])
		var lz := float(ld[1])
		var g := ground(lx, lz + 0.6)
		var h := float(ld[2]) * ROOM_H - 0.6
		_ladder(Vector3(lx, g, lz + 0.6), Vector3(lx, g + h, lz - 0.1))
	# The kivas in the plaza, and the great kiva over the heart.
	for kv in site.kivas:
		_kiva(Vector2(float(kv[0]), float(kv[1])), float(kv[2]), false)
	if Delves.has_delve(site):
		_delve_build()
		var heart := {}
		for pc in (_delve.get("pieces", []) as Array):
			if str(pc.kind) == "heart":
				heart = pc
		if not heart.is_empty():
			var hc: Vector2 = heart.c
			_kiva(Vector2(hc.x, hc.y + float(heart.len) * 0.5), 4.6, true)


## A ladder from `a` (its foot) to `b` (its top): two rails and rungs.
func _ladder(a: Vector3, b: Vector3) -> void:
	var was := solid
	solid = false
	var up_v := (b - a)
	var side := up_v.cross(Vector3.BACK).normalized() * 0.24
	if side.length() < 0.1:
		side = Vector3(0.24, 0.0, 0.0)
	for s: float in [-1.0, 1.0]:
		_pole(a + side * s, b + side * s, 0.07)
	var n := int(up_v.length() / 0.45)
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n)
		_pole(p - side, p + side, 0.05)
	solid = was


## A kiva: a ring of stone round a dark pit, a ladder up out of it; the
## great one larger, a ring of stone over the heart below, no pit.
func _kiva(c: Vector2, r: float, great: bool) -> void:
	var g := ground(c.x, c.y)
	var n := 16 if great else 10
	for k in n:
		var a := k * TAU / n
		var p := c + Vector2(cos(a), sin(a)) * r
		_pbox(Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(p.x, ground(p.x, p.y) + 0.25, p.y)), Vector3(r * TAU / n * 1.05, 0.9, 0.7), PUEBLO[k % 5].darkened(0.05), 0.1)
	if not great:
		for k in 2:
			_pbox(Transform3D(Basis(Vector3.UP, k * PI * 0.25), Vector3(c.x, g + 0.03, c.y)), Vector3(r * 1.55, 0.06, r * 1.55), VOID, 0.0)
		_ladder(Vector3(c.x, g - 0.5, c.y), Vector3(c.x + 0.3, g + 2.4, c.y + 0.6))


# --- The brick city (design 3 Oct §DS.6) -------------------------------------------

const MUDBRICK := [Color(0.62, 0.5, 0.36), Color(0.58, 0.46, 0.33), Color(0.66, 0.53, 0.38), Color(0.55, 0.44, 0.32), Color(0.6, 0.48, 0.34)]
const MELTED := Color(0.56, 0.47, 0.36)
## The gate's glaze (ruins.json styles.brick_city.gate.glazed: a saturated
## blue that never glows, R8) and its reliefs.
const GLAZE := Color("#1E3FD0")
const RELIEF := Color(0.86, 0.74, 0.42)


## The city (Monuments._brick_city): the tell, a low mound of melted brick
## with the foundation walls standing in it as a maze; the ziggurat at its
## middle; the processional way between high buttressed walls to the
## arched gate on the tell's edge, its face glazed blue with animals in
## relief; and to one side the palace mound over the vaulted stores (the
## barrow kit going down from the mound's foot; the way out comes up
## beyond it).
func _brick_city() -> void:
	palette = MUDBRICK
	var across: float = site.across_m
	var r := across * 0.5
	var cc: Vector2 = site.city_c
	_lod_m = float(site.footprint_m) * 0.5 + LOD_M + r
	# The tell.
	var rise := 3.5
	var rb := r * 0.9
	var rt := r * 0.72
	_tell(cc, rb, rt, rise, MELTED)
	var g0 := ground(cc.x, cc.y) + rise
	# The maze of foundation walls on its top: a grid of 12 m, each side
	# standing or gone by its own roll.
	var mrng := RandomNumberGenerator.new()
	mrng.seed = int(site.maze_seed)
	var cell := 12.0
	var n := int(rt * 0.92 / cell)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var p := cc + Vector2(i, j) * cell
			if (p - cc).length() > rt * 0.9 or (p - cc).length() < 34.0:
				continue
			for side in 2:
				if mrng.randf() > 0.55:
					continue
				var h := mrng.randf_range(0.9, 1.9)
				var mid := p + (Vector2(cell * 0.5, 0.0) if side == 0 else Vector2(0.0, cell * 0.5))
				var gy := ground(mid.x, mid.y) + rise
				var size := Vector3(cell + 0.8, h, 0.9) if side == 0 else Vector3(0.9, h, cell + 0.8)
				_pbox(Transform3D(Basis(), Vector3(mid.x, gy + h * 0.5 - 0.3, mid.y)), size, MUDBRICK[(i + j + side) & 3], 0.05)
	# The ziggurat at the middle: three tiers and a shrine, a stair up the
	# front.
	var zb := minf(54.0, rt * 0.6)
	var y := g0
	var w := zb
	for k in 3:
		var th := 5.5 - k * 0.6
		_pbox(Transform3D(Basis(), Vector3(cc.x, y + th * 0.5 - 0.2, cc.y)), Vector3(w, th, w), MUDBRICK[k], 0.05)
		y += th
		w *= 0.7
	_pbox(Transform3D(Basis(), Vector3(cc.x, y + 1.6, cc.y)), Vector3(w * 0.6, 3.2, w * 0.6), MUDBRICK[3], 0.05)
	var steps := int((y - g0) / 0.6)
	for k in steps:
		_pbox(Transform3D(Basis(), Vector3(cc.x, g0 + k * 0.6 + 0.3, cc.y - zb * 0.5 - 6.0 + k * (6.0 + zb * 0.5 - w * 0.5) / steps)), Vector3(5.0, 0.6, 1.2), MUDBRICK[4], 0.05)
	# The gate on the tell's edge, the processional way out from it.
	var gz := cc.y - rb - 2.0
	var gx := cc.x
	_brick_gate(Vector2(gx, gz))
	var way_len := 70.0
	var z := gz - 4.0
	while z > gz - 4.0 - way_len:
		for sx: float in [-1.0, 1.0]:
			var wx := gx + sx * 8.0
			var gw := ground(wx, z)
			_pbox(Transform3D(Basis(), Vector3(wx, gw + 3.3, z - 3.5)), Vector3(1.8, 7.2, 7.1), MUDBRICK[1], 0.05)
			# A buttress at each step, a band of glaze along the top.
			_pbox(Transform3D(Basis(), Vector3(wx - sx * 1.2, gw + 3.5, z - 0.5)), Vector3(0.9, 7.6, 1.4), MUDBRICK[0], 0.05)
			_pbox(Transform3D(Basis(), Vector3(wx - sx * 0.95, gw + 5.8, z - 3.5)), Vector3(0.08, 0.7, 7.0), GLAZE, 0.0)
		z -= 7.0
	_pave(Rect2(gx - 7.0, gz - 4.0 - way_len, 14.0, way_len), NAN)
	# The palace mound at the origin, its door at its foot over the way down.
	var pr: float = site.palace_r
	_tell(Vector2.ZERO, pr, pr * 0.55, 8.5, MELTED.darkened(0.04))
	var pg := ground(0.0, 0.0) + 8.5
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var wp := Vector2(cos(a), sin(a)) * pr * 0.32
		_pbox(Transform3D(Basis(Vector3.UP, a), Vector3(wp.x, pg + 0.8, wp.y)), Vector3(7.0, 1.8, 0.9), MUDBRICK[k % 5], 0.05)
	var dz := -pr - 0.5
	var dg := ground(0.0, dz)
	for sx: float in [-1.0, 1.0]:
		_pbox(Transform3D(Basis(), Vector3(sx * 1.6, dg + 1.8, dz)), Vector3(1.0, 3.6, 2.0), MUDBRICK[2], 0.05)
	_pbox(Transform3D(Basis(), Vector3(0.0, dg + 3.9, dz)), Vector3(4.4, 0.8, 2.0), MUDBRICK[3], 0.05)
	if Delves.has_delve(site):
		_delve_build()


## A low mound of melted brick at `c`: `rb` across its foot, `rt` across
## its top, `rise` high, walkable.
func _tell(c: Vector2, rb: float, rt: float, rise: float, col: Color) -> void:
	var sides := 16
	var top_pts: Array = []
	var bot_pts: Array = []
	for i in sides:
		var a := TAU * i / sides + rng.randf_range(-0.05, 0.05)
		var tr := rt * rng.randf_range(0.94, 1.04)
		var tp := c + Vector2(cos(a), sin(a)) * tr
		var bp := c + Vector2(cos(a), sin(a)) * rb
		top_pts.append(Vector3(tp.x, ground(tp.x, tp.y) + rise, tp.y))
		bot_pts.append(Vector3(bp.x, ground(bp.x, bp.y) - 0.6, bp.y))
	var ctr := Vector3(c.x, ground(c.x, c.y) + rise, c.y)
	var inside := Vector3(c.x, ctr.y - rise * 2.0, c.y)
	var start := _v.size()
	for i in sides:
		var j := (i + 1) % sides
		_face(ctr, top_pts[j], top_pts[i], top_pts[i], col, inside)
		_face(top_pts[i], top_pts[j], bot_pts[j], bot_pts[i], col.darkened(0.06), inside)
	_smooth_from(start)
	_collide_since(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))


## The gate at `c` (facing -z, down the processional way): two towers with
## pilasters, an arch of brick between them, the face glazed blue with rows
## of animals in relief: aurochs, lions and a dragon of our own.
func _brick_gate(c: Vector2) -> void:
	var g := ground(c.x, c.y)
	var hw := 7.5
	var h := 13.0
	var ow := 2.4
	var oh := 7.5
	# The towers either side of the opening, the mass over the arch.
	for sx: float in [-1.0, 1.0]:
		var tx := c.x + sx * (ow + (hw - ow) * 0.5)
		_pbox(Transform3D(Basis(), Vector3(tx, g + h * 0.5 - 0.5, c.y)), Vector3(hw - ow, h + 1.0, 6.0), MUDBRICK[2], 0.05)
		# Pilasters on the face.
		for k in 2:
			var px := c.x + sx * (ow + 1.0 + k * 3.0)
			_pbox(Transform3D(Basis(), Vector3(px, g + h * 0.5, c.y - 3.25)), Vector3(0.8, h, 0.5), GLAZE.darkened(0.15), 0.0)
	_pbox(Transform3D(Basis(), Vector3(c.x, g + oh + (h - oh) * 0.5, c.y)), Vector3(ow * 2.0 + 0.2, h - oh, 6.0), MUDBRICK[3], 0.05)
	# The arch: brick voussoirs round the opening's head.
	for k in 9:
		var ang := PI * (k + 0.5) / 9.0
		var p := Vector3(c.x - cos(ang) * ow, g + oh - ow + sin(ang) * ow, c.y - 3.1)
		var tangent := Vector3(sin(ang), cos(ang), 0)
		var basis := Basis(tangent, tangent.cross(Vector3(0, 0, 1)).normalized() * -1.0, Vector3(0, 0, 1)).orthonormalized()
		_pbox(Transform3D(basis, p), Vector3(0.9, 0.7, 0.6), GLAZE, 0.0)
	# The glazed face, and the beasts on it: two rows each side.
	for sx: float in [-1.0, 1.0]:
		var fx := c.x + sx * (ow + (hw - ow) * 0.5)
		_pbox(Transform3D(Basis(), Vector3(fx, g + h * 0.5, c.y - 3.08)), Vector3(hw - ow - 0.2, h - 0.6, 0.12), GLAZE, 0.0)
		for row in 3:
			var by := g + 2.2 + row * 3.4
			var kind := row % 3
			_beast(Vector3(fx, by, c.y - 3.2), sx, kind)
	_pbox(Transform3D(Basis(), Vector3(c.x, g + h - 0.3, c.y - 3.08)), Vector3(ow * 2.0, 0.6, 0.12), GLAZE, 0.0)
	# The opening's floor, its dark depth (a void through the gate).
	_pbox(Transform3D(Basis(), Vector3(c.x, g + (oh - ow) * 0.5, c.y + 2.95)), Vector3(ow * 2.0, oh - ow, 0.06), VOID, 0.0)


## A beast in relief on the glazed face at `p`, walking toward `sx` (kind
## 0 an aurochs, 1 a lion, 2 the dragon: long-necked, scaled, its tail up).
func _beast(p: Vector3, sx: float, kind: int) -> void:
	var col := RELIEF if kind != 1 else RELIEF.lightened(0.08)
	var bl := 2.2 if kind != 2 else 2.0
	_pbox(Transform3D(Basis(), p + Vector3(0.0, 0.7, 0.0)), Vector3(bl, 0.9, 0.14), col, 0.0)
	for lx in [-0.8, -0.3, 0.3, 0.8]:
		_pbox(Transform3D(Basis(), p + Vector3(float(lx) * bl * 0.45, 0.12, 0.0)), Vector3(0.18, 0.62, 0.14), col, 0.0)
	match kind:
		0:
			_pbox(Transform3D(Basis(), p + Vector3(sx * (bl * 0.5 + 0.25), 0.95, 0.0)), Vector3(0.6, 0.55, 0.14), col, 0.0)
			_pbox(Transform3D(Basis(Vector3.BACK, 0.6 * sx), p + Vector3(sx * (bl * 0.5 + 0.35), 1.35, 0.0)), Vector3(0.12, 0.5, 0.14), col, 0.0)
		1:
			_pbox(Transform3D(Basis(), p + Vector3(sx * (bl * 0.5 + 0.2), 1.0, 0.0)), Vector3(0.7, 0.75, 0.14), col.darkened(0.1), 0.0)
			_pbox(Transform3D(Basis(Vector3.BACK, -0.5 * sx), p + Vector3(-sx * (bl * 0.5 + 0.2), 0.95, 0.0)), Vector3(0.6, 0.1, 0.14), col, 0.0)
		_:
			_pbox(Transform3D(Basis(Vector3.BACK, -0.35 * sx), p + Vector3(sx * (bl * 0.5 + 0.2), 1.4, 0.0)), Vector3(0.22, 1.2, 0.14), col, 0.0)
			_pbox(Transform3D(Basis(), p + Vector3(sx * (bl * 0.5 + 0.45), 2.0, 0.0)), Vector3(0.5, 0.3, 0.14), col, 0.0)
			_pbox(Transform3D(Basis(Vector3.BACK, 0.7 * sx), p + Vector3(-sx * (bl * 0.5 + 0.2), 1.25, 0.0)), Vector3(0.14, 0.9, 0.14), col, 0.0)


# --- The stone heads (design 3 Oct §DS.3) ------------------------------------------

## Volcanic tuff, and the red scoria of a topknot.
const TUFF := [Color(0.42, 0.39, 0.35), Color(0.38, 0.36, 0.33), Color(0.46, 0.42, 0.37), Color(0.4, 0.37, 0.32), Color(0.44, 0.4, 0.36)]
const SCORIA := Color(0.55, 0.27, 0.2)


## The row (Monuments._stone_heads): a long platform of fitted stone along
## the shore, the heads on it with their backs to the sea, facing inland
## (+z): each a torso and a long head, a heavy brow over deep-shadowed
## eyes, a long nose, a jutting chin, long ears; a red topknot on some;
## one in five face down in the grass before the platform. Inland in the
## hill behind, the quarry's open face over its cave (the barrow kit going
## down; an unfinished head lies in the rock at its heart). Nothing says
## why the trees are gone (§BQ).
func _stone_heads() -> void:
	palette = TUFF
	var heads: Array = site.heads
	var n := heads.size()
	var span := n * 4.6 + 4.0
	_lod_m = maxf(span * 0.5, Monuments.QUARRY_Z) + LOD_M
	# The row turned to face truly inland (the frame is on the grid).
	var fi := (_local_of(CreatureSpawner._offset(site.dir, float(site.inland), 10.0)) - _local_of(site.dir)).normalized()
	var rb := Basis(Vector3.UP, atan2(fi.x, fi.y))
	_stone_row(heads, span, rb)
	# The quarry in the hill behind: its open face, a few tuff blocks
	# round the way down, a half-cut head lying by it.
	var qz := Monuments.QUARRY_Z
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.32
		var qp := Vector2(cos(a) * 9.0, qz + 4.0 + sin(a) * 9.0 * 0.6)
		var qg := ground(qp.x, qp.y)
		var qh := rng.randf_range(2.5, 4.5)
		_pbox(Transform3D(Basis(Vector3.UP, -a), Vector3(qp.x, qg + qh * 0.5 - 0.4, qp.y + 6.0)), Vector3(3.2, qh, 2.4), TUFF[k % 5].darkened(0.04), 0.1)
	var ug := ground(-6.0, qz + 2.0)
	_head_shape(Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, 0.4), Vector3(-6.0, ug + 0.5, qz - 2.0)), 5.5, false, true)
	if Delves.has_delve(site):
		_delve_build()
		for pc in (_delve.get("pieces", []) as Array):
			if str(pc.kind) == "heart":
				var hc: Vector2 = pc.c
				var hl := float(pc.len)
				# The unfinished head, still in the rock at the heart's back.
				_head_shape(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(hc.x, float(pc.y0) - _delve_off + 0.6, hc.y + hl * 0.6)), 4.2, false, true)


## The platform and its heads, laid in the row's own frame `rb` (its +z
## inland), positions turned by it from the site's middle.
func _stone_row(heads: Array, span: float, rb: Basis) -> void:
	var n := heads.size()
	# The platform: fitted blocks along x, its top level.
	var top := -INF
	for k in 9:
		var tp := rb * Vector3(lerpf(-span * 0.5, span * 0.5, k / 8.0), 0.0, 0.0)
		top = maxf(top, ground(tp.x, tp.z))
	top += 1.6
	var x := -span * 0.5
	while x < span * 0.5:
		var bl := minf(rng.randf_range(1.6, 2.6), span * 0.5 - x)
		var pa := rb * Vector3(x + bl * 0.5, 0.0, -2.5)
		var pb := rb * Vector3(x + bl * 0.5, 0.0, 2.5)
		var gb := minf(ground(pa.x, pa.z), ground(pb.x, pb.z))
		var pc := rb * Vector3(x + bl * 0.5, 0.0, 0.0)
		_pbox(Transform3D(rb, Vector3(pc.x, (gb - 0.6 + top) * 0.5, pc.z)), Vector3(bl - 0.04, top - gb + 0.6, 6.0), TUFF[rng.randi() % 5], 0.05)
		x += bl
	# The ramp of stones down the seaward side.
	_pbox(Transform3D(rb * Basis(Vector3.RIGHT, -0.35), rb * Vector3(0.0, 0.0, -4.2) + Vector3(0.0, top - 1.2, 0.0)), Vector3(span, 0.6, 3.4), TUFF[2].darkened(0.06), 0.05)
	for i in n:
		var hd: Dictionary = heads[i]
		var hx := -span * 0.5 + 2.0 + 2.3 + i * 4.6
		var h := float(hd.h)
		if bool(hd.fallen):
			# Face down in the grass before the platform, its head inland.
			var fp := rb * Vector3(hx, 0.0, 4.0)
			var gf := ground(fp.x, fp.z)
			_head_shape(Transform3D(rb * Basis(Vector3.RIGHT, PI * 0.5), Vector3(fp.x, gf + 0.7, fp.z)), h, false)
			continue
		var hp := rb * Vector3(hx, 0.0, 0.0)
		_head_shape(Transform3D(rb * Basis(Vector3.UP, float(hd.turn)), Vector3(hp.x, top, hp.z)), h, bool(hd.topknot))


## One head standing on `xf` (its foot at the origin, facing +z), `h`
## tall: torso, the long head, brow, nose, chin, ears; `topknot` a red
## cylinder of scoria; `rough` an unfinished one (no features cut).
func _head_shape(xf: Transform3D, h: float, topknot: bool, rough := false) -> void:
	var col: Color = TUFF[rng.randi() % 5]
	var tw := h * 0.32
	var th := h * 0.42
	_pbox(xf * Transform3D(Basis(), Vector3(0.0, th * 0.5, 0.0)), Vector3(tw, th, tw * 0.62), col, 0.15)
	var hw := tw * 0.86
	var hh := h * 0.58
	var hy := th + hh * 0.5
	_pbox(xf * Transform3D(Basis(), Vector3(0.0, hy, 0.02)), Vector3(hw, hh, tw * 0.66), col.lightened(0.03), 0.15)
	if rough:
		return
	var fz := tw * 0.33 + 0.02
	# The brow, the shadowed eyes under it, the long nose, the chin.
	_pbox(xf * Transform3D(Basis(), Vector3(0.0, th + hh * 0.72, fz + 0.1)), Vector3(hw * 0.96, hh * 0.1, 0.32), col.darkened(0.04), 0.1)
	for sx: float in [-1.0, 1.0]:
		_pbox(xf * Transform3D(Basis(), Vector3(sx * hw * 0.24, th + hh * 0.63, fz + 0.01)), Vector3(hw * 0.26, hh * 0.08, 0.04), VOID, 0.0)
		_pbox(xf * Transform3D(Basis(), Vector3(sx * (hw * 0.5 + 0.08), th + hh * 0.5, 0.0)), Vector3(0.18, hh * 0.55, tw * 0.3), col.darkened(0.06), 0.1)
	_pbox(xf * Transform3D(Basis(), Vector3(0.0, th + hh * 0.5, fz + 0.16)), Vector3(hw * 0.2, hh * 0.32, 0.36), col, 0.1)
	_pbox(xf * Transform3D(Basis(), Vector3(0.0, th + hh * 0.12, fz + 0.12)), Vector3(hw * 0.62, hh * 0.14, 0.3), col.darkened(0.03), 0.1)
	if topknot:
		_pbox(xf * Transform3D(Basis(), Vector3(0.0, th + hh + h * 0.08, 0.0)), Vector3(hw * 0.78, h * 0.16, hw * 0.78), SCORIA, 0.0)


# --- The terraced pueblo (design 3 Oct §DS.5) --------------------------------------

const ADOBE := [Color(0.7, 0.55, 0.4), Color(0.66, 0.51, 0.37), Color(0.73, 0.58, 0.42), Color(0.63, 0.49, 0.36), Color(0.68, 0.53, 0.38)]


## The town (Monuments._terraced_pueblo): its rooms in rows on a mound of
## its own melted adobe, the back rows standing tallest, each storey set
## back from the one below so the roofs make terraces; doors and roof
## hatches dark (R8), ladders up the terraces, beam ends; the plaza in
## front with its kivas, and the great kiva over the way down (the barrow
## kit: the stores under the town, the heart the deepest, a way up out
## behind it).
func _terraced_pueblo() -> void:
	palette = ADOBE
	var rm: float = site.room_m
	var cols := int(site.cols)
	var rows := int(site.rows)
	var w := cols * rm
	var dpt := rows * rm
	_lod_m = float(site.footprint_m) + LOD_M
	# The mound of melted adobe under it all.
	_tell(Vector2(0.0, 0.0), maxf(w, dpt) * 0.62, maxf(w, dpt) * 0.42, 1.6, ADOBE[3].darkened(0.08))
	var g0 := ground(0.0, 0.0) + 1.6
	var x0 := -w * 0.5 + rm * 0.5
	var z0 := -dpt * 0.5 + rm * 0.5
	for rmv in site.rooms:
		var c := int(rmv[0])
		var r := int(rmv[1])
		var st := int(rmv[2])
		var x := x0 + c * rm
		var z := z0 + r * rm
		for s in st:
			var col: Color = ADOBE[(c + r + s) % 5]
			var sh := ROOM_H + 0.2
			var y := g0 + s * sh
			_pbox(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.02, 0.02)), Vector3(x, y + sh * 0.5 - 0.2, z)), Vector3(rm - 0.1, sh, rm - 0.1), col, 0.04)
			# A door on the front of the front-most room of each storey.
			var front := true
			for o in site.rooms:
				if int(o[0]) == c and int(o[1]) == r - 1 and int(o[2]) > s:
					front = false
					break
			if front:
				_pbox(Transform3D(Basis(), Vector3(x, y + 0.75, z - rm * 0.5 + 0.02)), Vector3(0.6, 1.1, 0.06), VOID, 0.0)
				_pbox(Transform3D(Basis(), Vector3(x, y + 1.45, z - rm * 0.5 + 0.02)), Vector3(1.1, 0.4, 0.06), VOID, 0.0)
		var top := g0 + st * (ROOM_H + 0.2)
		# The roof: a hatch on some, beam ends at the front.
		if rng.randf() < 0.35:
			_pbox(Transform3D(Basis(), Vector3(x + 0.6, top - 0.15, z + 0.4)), Vector3(0.9, 0.06, 0.9), VOID, 0.0)
		for bx in [-1.2, 0.0, 1.2]:
			_pbox(Transform3D(Basis(), Vector3(x + float(bx), top - 0.3, z - rm * 0.5 - 0.2)), Vector3(0.16, 0.16, 0.45), OLD_WOOD, 0.0)
		# A ladder up to the next terrace now and then.
		if st >= 1 and r > 0 and rng.randf() < 0.18:
			var lz := z - rm * 0.5 - 0.7
			_ladder(Vector3(x - 0.8, top - (ROOM_H + 0.2) + 0.0, lz), Vector3(x - 0.8, top + 1.2, lz + 0.5))
	# The plaza: its kivas, the great kiva round the way down.
	for kv in site.kivas:
		_kiva(Vector2(float(kv[0]), float(kv[1])), float(kv[2]), false)
	var gk: Array = site.great_kiva
	var kc := Vector2(float(gk[0]), float(gk[1]))
	var kr := float(gk[2])
	for k in 16:
		var a := k * TAU / 16.0
		var p := kc + Vector2(cos(a), sin(a)) * kr
		# (Open where the stair runs in, +z.)
		if p.y > kc.y and absf(p.x - kc.x) < 1.6:
			continue
		_pbox(Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(p.x, ground(p.x, p.y) + 0.25, p.y)), Vector3(kr * TAU / 16.0 * 1.05, 0.9, 0.7), ADOBE[k % 5].darkened(0.08), 0.1)
	if Delves.has_delve(site):
		_delve_build()


# --- The stone circle (design 3 Oct §DS.7) -----------------------------------------

## The ring (Monuments._stone_circle): its standing stones of the local
## hard stone, leaning a little, some fallen in the grass, lintels on some
## pairs; outside it the ditch (a dark band) and the bank (a low ring of
## turfed earth) with a causeway in; where the seed gives one, the
## souterrain's mouth at the bank (the barrow kit going down under the
## ring, no fire-holders: delves.json by_ruin "none").
func _stone_circle() -> void:
	palette = STONES
	var r: float = site.ring_r
	_lod_m = r + 14.0 + LOD_M
	var stones: Array = site.stones
	var tops: Array = []
	for i in stones.size():
		var s: Dictionary = stones[i]
		var a := float(s.a)
		var p := Vector2(cos(a), sin(a)) * r
		var g := ground(p.x, p.y)
		var h := float(s.h)
		var w := float(s.w)
		var col: Color = STONES[i % STONES.size()]
		var face := Basis(Vector3.UP, -a + PI * 0.5)
		if bool(s.fallen):
			_pbox(Transform3D(face * Basis(Vector3.RIGHT, PI * 0.5 - 0.05), Vector3(p.x * 1.08, g + 0.45, p.y * 1.08)), Vector3(w, h, 0.85), col, 0.4)
			tops.append(Vector3.INF)
			continue
		var bs := face * Basis(Vector3.BACK, float(s.lean))
		_pbox(Transform3D(bs, Vector3(p.x, g + h * 0.5 - 0.6, p.y)), Vector3(w, h + 1.2, 0.95), col, 0.3)
		tops.append(Vector3(p.x, g + h - 0.6, p.y))
	# The lintels across their pairs.
	for i in site.lintels:
		var t1: Vector3 = tops[int(i)]
		var t2: Vector3 = tops[(int(i) + 1) % stones.size()]
		if t1 == Vector3.INF or t2 == Vector3.INF:
			continue
		var mid := (t1 + t2) * 0.5
		var along := (t2 - t1)
		var bl := Basis(Vector3.UP, atan2(-along.z, along.x))
		_pbox(Transform3D(bl, Vector3(mid.x, maxf(t1.y, t2.y) + 0.45, mid.z)), Vector3(along.length() + 1.6, 0.9, 1.0), STONES[2].darkened(0.06), 0.35)
	# The ditch and the bank, the causeway in on the -z side.
	var segs := 36
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var am := (a0 + a1) * 0.5
		if absf(wrapf(am + PI * 0.5, -PI, PI)) < 0.2:
			continue
		for band in [[r + 8.0, 2.4, 0.08, EARTH.darkened(0.45)], [r + 11.5, 2.6, 0.8, GRASS.darkened(0.15)]]:
			var rr: float = band[0]
			var c := Vector2(cos(am), sin(am)) * rr
			var seg_l := TAU * rr / segs + 0.4
			var hh: float = band[2]
			var gy := ground(c.x, c.y)
			_pbox(Transform3D(Basis(Vector3.UP, -am + PI * 0.5), Vector3(c.x, gy + hh * 0.5 - 0.15, c.y)), Vector3(seg_l, hh + 0.3, float(band[1])), band[3], 0.6)
	if Delves.has_delve(site):
		_delve_build()


# --- The hewn temple (design 3 Oct §DZ) ----------------------------------------------

## Basalt, the living rock: grey-black, a little warm in the sun.
const BASALT := [Color(0.29, 0.28, 0.29), Color(0.25, 0.25, 0.28), Color(0.32, 0.3, 0.29), Color(0.23, 0.23, 0.27), Color(0.3, 0.28, 0.27)]
const BASALT_RELIEF := Color(0.36, 0.34, 0.32)


## The hewn temple (Monuments._hewn_temple, HewnTemple.layout): the pit's
## floor and its walls of living rock (5 m thick, so they cover the ground's
## quads left out round it, their tops at the rim), the stair cut down the
## front wall, and standing free in the middle the temple: its plinth with
## elephants round the base, the pillared hall, the shrine with its
## stepped tower, the porch, the gatehouse before it and the two pillars;
## reliefs on its faces. In the back wall the halls (the delve), their
## fronts on the court: the first's open porch, dark windows for the two
## above. A creeper down the walls here and there.
func _hewn_temple() -> void:
	palette = BASALT
	var w: float = site.pit_w
	var l: float = site.pit_l
	var lay: Dictionary = Delves.layout(map, site)
	_delve = lay
	_delve_off = base_e - float(lay.base_e)
	var off := _delve_off
	var yf := float(site.floor_y) - off
	var rim := float(site.rim_y) - off
	_lod_m = Vector2(w, l).length() * 0.5 + LOD_M
	_lit_per_pixel = true
	# The floor.
	var nx := int(ceil(w / 12.0))
	var nz := int(ceil(l / 12.0))
	for i in nx:
		for j in nz:
			var fx := -w * 0.5 + (i + 0.5) * w / nx
			var fz := -l * 0.5 + (j + 0.5) * l / nz
			_pbox(Transform3D(Basis.IDENTITY, Vector3(fx, yf - 0.5, fz)), Vector3(w / nx + 0.02, 1.0, l / nz + 0.02), BASALT[(i + j) % BASALT.size()].darkened(0.04), 0.15)
	# The walls; the back wall opened where the halls come through it.
	var zf := l * 0.5
	var cuts: Array = []
	for i in 3:
		var hx: float = HewnTemple.HALL_X[i]
		var y0 := yf + i * HewnTemple.HALL_RISE
		var hh := HewnTemple.HEART_H if i == 2 else HewnTemple.HALL_H
		var half := HewnTemple.HALL_HALF if i == 0 else HewnTemple.HALL_HALF + Delves.WALL
		cuts.append([hx - half, hx + half, y0 - (1.2 if i == 0 else Delves.WALL), y0 + hh + Delves.SLAB + 0.05])
	_pit_wall(Vector2(-w * 0.5, -zf), Vector2(w * 0.5, -zf), Vector2(0.0, -1.0), [])
	_pit_wall(Vector2(-w * 0.5, zf), Vector2(w * 0.5, zf), Vector2(0.0, 1.0), cuts)
	_pit_wall(Vector2(-w * 0.5, -zf - 5.0), Vector2(-w * 0.5, zf + 5.0), Vector2(-1.0, 0.0), [])
	_pit_wall(Vector2(w * 0.5, -zf - 5.0), Vector2(w * 0.5, zf + 5.0), Vector2(1.0, 0.0), [])
	# The stair down the front wall, from the rim at its -x end.
	var ssx := float(site.get("stair_sx", -1.0))
	var sx0 := ssx * (w * 0.5 - 3.0)
	var gtop := ground(sx0, -zf - 1.0)
	var rise := gtop - yf
	var run := rise / HewnTemple.COURT_STAIR
	var steps := maxi(4, int(ceil(rise / 0.3)))
	var sz := -zf + 1.2
	solid = false
	for k in steps:
		var xa := sx0 - ssx * run * k / steps
		var xb := sx0 - ssx * run * (k + 1) / steps
		var top := gtop - rise * k / steps
		_pbox(Transform3D(Basis.IDENTITY, Vector3((xa + xb) * 0.5, (yf - 0.5 + top) * 0.5, sz)), Vector3(absf(xb - xa) + 0.02, top - yf + 0.5, 2.4), BASALT[k % BASALT.size()], 0.1)
	solid = true
	_dramp(Vector3(sx0 - ssx * run, yf, sz), Vector3(sx0, gtop, sz), 2.4)
	# The temple, standing free.
	_hewn_shrine(yf, rim)
	# The halls' fronts on the court.
	var p0 := Vector2(HewnTemple.HALL_X[0], zf)
	for sx: float in [-1.0, 1.0]:
		_pbox(Transform3D(Basis.IDENTITY, Vector3(p0.x + sx * 1.4, yf + HewnTemple.HALL_H * 0.5, zf - 0.6)), Vector3(0.6, HewnTemple.HALL_H, 0.6), BASALT[2], 0.1)
	for i in [1, 2]:
		var hx: float = HewnTemple.HALL_X[i]
		var y0: float = yf + i * HewnTemple.HALL_RISE
		for px: float in [-2.9, -0.95, 0.95, 2.9]:
			_pbox(Transform3D(Basis.IDENTITY, Vector3(hx + px, y0 + 2.0, zf - 0.08)), Vector3(0.4, 4.0, 0.2), BASALT[2], 0.05)
		for vx: float in [-1.925, 0.0, 1.925]:
			_pbox(Transform3D(Basis.IDENTITY, Vector3(hx + vx, y0 + 1.9, zf - 0.03)), Vector3(1.3 if vx == 0.0 else 1.5, 2.8, 0.06), VOID, 0.0)
		_pbox(Transform3D(Basis.IDENTITY, Vector3(hx, y0 + 4.3, zf - 0.15)), Vector3(7.0, 0.5, 0.3), BASALT[4], 0.1)
	# A creeper down the walls here and there (§DI).
	for k in 10:
		var side := k % 4
		var t := rng.randf_range(-0.4, 0.4)
		var at := Vector2(t * w, -zf) if side == 0 else (Vector2(t * w, zf) if side == 1 else Vector2((-0.5 if side == 2 else 0.5) * w, t * l))
		var inward := Vector3(0.0, 0.0, 1.0) if side == 0 else (Vector3(0.0, 0.0, -1.0) if side == 1 else Vector3(1.0 if side == 2 else -1.0, 0.0, 0.0))
		ivy(Vector3(at.x, ground(at.x, at.y) - 0.2, at.y) + inward * 0.05, inward, rng.randf_range(4.0, minf(12.0, rim - yf)))
	# The court's old hearth (OldHearths), off to the side before the temple
	# (away from the stair's foot).
	_camp_spot = Vector3(ssx * w * 0.32, yf, -l * 0.3)
	# The halls (the delve).
	shade = 0.0
	_delve_from = _v.size()
	_hewn_halls(lay, off)
	_delve_to = _v.size()


## A wall of the pit from `a` to `b` (its inner face's line), its rock `out`
## from there 5 m thick, from under the floor to the rim; `cuts` ([x0, x1,
## y_lo, y_hi] along x) leave the rock out between y_lo and y_hi.
func _pit_wall(a: Vector2, b: Vector2, out: Vector2, cuts: Array) -> void:
	var yb := float(site.floor_y) - _delve_off - 1.0
	var marks: Array = [0.0, 1.0]
	var along := b - a
	var length := along.length()
	for ct in cuts:
		marks.append(clampf((float(ct[0]) - a.x) / along.x, 0.0, 1.0))
		marks.append(clampf((float(ct[1]) - a.x) / along.x, 0.0, 1.0))
	marks.sort()
	for m in marks.size() - 1:
		var t0: float = marks[m]
		var t1: float = marks[m + 1]
		if t1 - t0 < 0.001:
			continue
		var seg := (t1 - t0) * length
		var cols := maxi(1, int(ceil(seg / 4.0)))
		for k in cols:
			var ta := t0 + (t1 - t0) * (k + 0.5) / cols
			var p := a + along * ta
			var top := maxf(ground(p.x, p.y), maxf(ground(p.x + out.x * 2.5, p.y + out.y * 2.5), ground(p.x + out.x * 5.0, p.y + out.y * 5.0))) + 0.1
			var cw := seg / cols + 0.02
			var c := p + out * 2.5
			var size := Vector3(cw if absf(out.y) > 0.5 else 5.0, 0.0, 5.0 if absf(out.y) > 0.5 else cw)
			var col: Color = BASALT[rng.randi() % BASALT.size()]
			var spans: Array = [[yb, top]]
			for ct in cuts:
				if p.x > float(ct[0]) and p.x < float(ct[1]):
					spans = [[yb, float(ct[2])], [float(ct[3]), top]]
			for sp in spans:
				if float(sp[1]) - float(sp[0]) < 0.05:
					continue
				size.y = float(sp[1]) - float(sp[0])
				_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, (float(sp[0]) + float(sp[1])) * 0.5, c.y)), size, col, 0.12)


## The temple in the middle of the court (its front -z), its top under the
## rim: the plinth, its elephants, the pillared hall, the shrine and its
## tower, the porch, the stair up, the gatehouse and the two pillars.
func _hewn_shrine(yf: float, rim: float) -> void:
	var tw: float = site.temple_w
	var tl: float = site.temple_l
	var htot := rim - yf - 1.5
	var ph := 5.0
	var top := yf + ph
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, yf + 0.4, 0.0)), Vector3(tw + 0.6, 0.8, tl + 0.6), BASALT[3], 0.15)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, yf + ph * 0.5, 0.0)), Vector3(tw, ph, tl), BASALT[0], 0.1)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top - 0.3, 0.0)), Vector3(tw + 0.8, 0.6, tl + 0.8), BASALT[2], 0.15)
	# The stair up its front.
	var srun := ph / 0.7
	var sw := 4.0
	var steps := int(ceil(ph / 0.3))
	solid = false
	for k in steps:
		var za := -tl * 0.5 - srun + srun * k / steps
		var zb := -tl * 0.5 - srun + srun * (k + 1) / steps
		var st := yf + ph * (k + 1) / steps
		_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, (yf - 0.2 + st) * 0.5, (za + zb) * 0.5)), Vector3(sw, st - yf + 0.2, zb - za + 0.02), BASALT[k % 5], 0.1)
	solid = true
	_dramp(Vector3(0.0, yf, -tl * 0.5 - srun), Vector3(0.0, top, -tl * 0.5), sw)
	# The elephants round the base, facing out (none across the stair).
	for f in 4:
		var n := [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)][f] as Vector2
		var span := tw if f % 2 == 0 else tl
		var count := int(span / 4.2)
		for k in count:
			var u := -span * 0.5 + (k + 0.5) * span / count
			if f == 0 and absf(u) < sw * 0.5 + 1.2:
				continue
			var at := n * ((tl if f % 2 == 0 else tw) * 0.5) + Vector2(-n.y, n.x) * u
			_elephant(Vector3(at.x, yf + 0.8, at.y), n)
	# The shrine at the back, its stepped tower, and the pillared hall
	# before it; the porch at the front.
	var sv := tw * 0.62
	var vz := tl * 0.5 - sv * 0.5 - 2.0
	var wall_h := 6.0
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top + wall_h * 0.5, vz)), Vector3(sv, wall_h, sv), BASALT[1], 0.1)
	_hewn_reliefs(Vector3(0.0, top, vz), Vector2(sv, sv), wall_h)
	var tiers := int(site.towers)
	# (The crown and finial take the last 2 m.)
	var tower_h := maxf(htot - ph - wall_h - 2.0, 3.0)
	var th := tower_h / tiers
	var y := top + wall_h
	for k in tiers:
		var side := sv * (0.92 - 0.6 * k / tiers)
		_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, y + th * 0.5, vz)), Vector3(side, th, side), BASALT[(k + 1) % 5], 0.12)
		# Little pavilions along each tier's edge.
		var ps := side * 0.16
		for cx: float in [-1.0, 0.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				_pbox(Transform3D(Basis.IDENTITY, Vector3(cx * (side * 0.5 - ps * 0.5), y + th + ps * 0.3, vz + cz * (side * 0.5 - ps * 0.5))), Vector3(ps, ps * 0.6, ps), BASALT[2], 0.1)
				_pbox(Transform3D(Basis.IDENTITY, Vector3(cz * (side * 0.5 - ps * 0.5), y + th + ps * 0.3, vz + cx * (side * 0.5 - ps * 0.5))), Vector3(ps, ps * 0.6, ps), BASALT[2], 0.1)
		y += th
	# The cap: an octagonal crown and its finial.
	var cap := sv * 0.3
	for r: float in [0.0, PI * 0.25]:
		_pbox(Transform3D(Basis(Vector3.UP, r), Vector3(0.0, y + 0.6, vz)), Vector3(cap, 1.2, cap), BASALT[0], 0.1)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, y + 1.6, vz)), Vector3(0.4, 0.8, 0.4), BASALT[2], 0.0)
	# The pillared hall: its roof on pillars, dark within.
	var hl := tl * 0.38
	var hz := vz - sv * 0.5 - hl * 0.5
	var hw := tw * 0.8
	var hh := 5.0
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top + hh * 0.5, hz)), Vector3(hw - 1.6, hh, hl - 1.6), VOID, 0.0)
	var cols := int(hw / 2.6)
	for k in cols + 1:
		var px := -hw * 0.5 + 0.4 + (hw - 0.8) * k / cols
		for pz: float in [-1.0, 1.0]:
			_pbox(Transform3D(Basis.IDENTITY, Vector3(px, top + hh * 0.5, hz + pz * (hl * 0.5 - 0.4))), Vector3(0.8, hh, 0.8), BASALT[2], 0.05)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top + hh + 0.5, hz)), Vector3(hw + 1.0, 1.0, hl + 1.0), BASALT[3], 0.15)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top + hh + 1.4, hz)), Vector3(hw * 0.7, 0.8, hl * 0.7), BASALT[0], 0.15)
	# The porch at the plinth's front, over the stair's head.
	var pz0 := -tl * 0.5 + 4.0
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top + 2.0, pz0)), Vector3(6.0, 4.0, 5.0), BASALT[4], 0.1)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top + 1.4, pz0 - 2.52)), Vector3(1.8, 2.8, 0.06), VOID, 0.0)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, top + 4.4, pz0)), Vector3(6.8, 0.8, 5.8), BASALT[3], 0.15)
	# The gatehouse on the court before the stair: two halves and the
	# lintel over the way through.
	var gz := -tl * 0.5 - srun - 9.0
	var gh := minf(9.0, htot - 1.0)
	for gx: float in [-1.0, 1.0]:
		_pbox(Transform3D(Basis.IDENTITY, Vector3(gx * 4.5, yf + gh * 0.5, gz)), Vector3(6.0, gh, 6.0), BASALT[1], 0.12)
		_hewn_reliefs(Vector3(gx * 4.5, yf, gz), Vector2(6.0, 6.0), gh * 0.6)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, yf + 4.5 + (gh - 4.5) * 0.5, gz)), Vector3(3.2, gh - 4.5, 6.0), BASALT[3], 0.12)
	# The two pillars, standing free either side of the hall.
	var pil_h := minf(ph + 10.0, htot - 1.0)
	for px: float in [-1.0, 1.0]:
		var c := Vector3(px * (tw * 0.5 + 4.0), yf, hz)
		_pbox(Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.6, 0.0)), Vector3(2.2, 1.2, 2.2), BASALT[3], 0.2)
		_pbox(Transform3D(Basis.IDENTITY, c + Vector3(0.0, pil_h * 0.5, 0.0)), Vector3(1.3, pil_h, 1.3), BASALT[2], 0.1)
		_pbox(Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0.0, pil_h + 0.5, 0.0)), Vector3(1.9, 1.0, 1.9), BASALT[0], 0.1)


## An elephant in the round from the plinth's face at `p` (its feet), its
## back in the rock, facing `n`: body, head, ears, trunk down, tusks, legs.
func _elephant(p: Vector3, n: Vector2) -> void:
	var bs := Basis(Vector3.UP, atan2(n.x, n.y))
	var col := BASALT_RELIEF.darkened(rng.randf_range(0.0, 0.08))
	var parts := [[Vector3(0.0, 1.8, 0.4), Vector3(2.0, 2.0, 1.4)], [Vector3(0.0, 2.4, 1.4), Vector3(1.5, 1.4, 1.0)],
		[Vector3(-0.95, 2.4, 1.2), Vector3(0.3, 1.3, 1.0)], [Vector3(0.95, 2.4, 1.2), Vector3(0.3, 1.3, 1.0)],
		[Vector3(0.0, 1.2, 2.0), Vector3(0.45, 1.8, 0.45)], [Vector3(-0.55, 0.55, 1.3), Vector3(0.55, 1.1, 0.55)],
		[Vector3(0.55, 0.55, 1.3), Vector3(0.55, 1.1, 0.55)]]
	for pt in parts:
		_pbox(Transform3D(bs, p + bs * (pt[0] as Vector3)), pt[1], col, 0.1)
	for tx: float in [-0.35, 0.35]:
		_pbox(Transform3D(bs * Basis(Vector3.RIGHT, 0.5), p + bs * Vector3(tx, 1.75, 2.15)), Vector3(0.14, 0.14, 0.8), BASALT_RELIEF.lightened(0.25), 0.0)


## Reliefs round a block whose foot's middle is `c`, `size` (x, z) across:
## on each face a frieze of dark panels, a figure standing in each (no one
## by name, §BO), `h` up its face.
func _hewn_reliefs(c: Vector3, size: Vector2, h: float) -> void:
	for f in 4:
		var n := [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)][f] as Vector2
		var span := size.x if f % 2 == 0 else size.y
		var depth := size.y if f % 2 == 0 else size.x
		var count := maxi(1, int(span / 2.4))
		var bs := Basis(Vector3.UP, atan2(n.x, n.y))
		var py := c.y + h * 0.45
		for k in count:
			var u := -span * 0.5 + (k + 0.5) * span / count
			var at := Vector2(c.x, c.z) + n * (depth * 0.5) + Vector2(-n.y, n.x) * u
			_pbox(Transform3D(bs, Vector3(at.x, py, at.y) + Vector3(n.x, 0.0, n.y) * 0.03), Vector3(1.8, minf(3.0, h * 0.7), 0.06), BASALT[3].darkened(0.35), 0.0)
			var fig := Vector3(at.x, py - 0.4, at.y) + Vector3(n.x, 0.0, n.y) * 0.12
			_pbox(Transform3D(bs, fig), Vector3(0.6, 1.6, 0.18), BASALT_RELIEF, 0.0)
			_pbox(Transform3D(bs, fig + Vector3(0.0, 1.05, 0.0)), Vector3(0.42, 0.45, 0.18), BASALT_RELIEF, 0.0)


## The halls (HewnTemple.layout): the porch, the three halls with their
## pillars and the ribs of their vaults (cut to look like timber that was
## never there), the stairs up through the rock between them, the seated
## figure in the heart's apse, the way out to the hilltop.
func _hewn_halls(lay: Dictionary, off: float) -> void:
	var pieces: Array = lay.pieces
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		var prev: Dictionary = pieces[i - 1] if i > 0 else {}
		var nxt: Dictionary = pieces[i + 1] if i + 1 < pieces.size() else {}
		match str(pc.kind):
			"passage":
				_delve_room(pc, off, [["start", 0.0, float(pc.half) - 0.05], ["end", 0.0, float(pc.half) - 0.05]])
			"room", "heart":
				var opens: Array = []
				opens.append(_opening(pc, (prev.c as Vector2) + (prev.dir as Vector2) * float(prev.len), float(prev.half) if str(prev.kind) != "passage" else float(prev.half) - 0.05))
				if not nxt.is_empty():
					opens.append(_opening(pc, nxt.c, float(nxt.half)))
				_delve_room(pc, off, opens)
				_hewn_hall_dress(pc, off, str(pc.kind) == "heart")
			"stair":
				_delve_stair(pc, off, false, 0.0, 0.0)
			"exit":
				_delve_stair_open_top(pc, off, float(lay.exit_open), float(pc.y1) - off)


## A hall's pillars (two rows, clear of the stairs' doors) and the ribs
## under its ceiling; in the heart, the apse's narrowing and the seated
## figure on its dais, hands in its lap.
func _hewn_hall_dress(pc: Dictionary, off: float, heart: bool) -> void:
	var y := float(pc.y0) - off
	var h := float(pc.h)
	var c: Vector2 = pc.c
	var ln := float(pc.len)
	var zs := float(site.pit_l) * 0.5 + HewnTemple.STAIR_Z
	var z := c.y + 2.0
	while z < c.y + ln - (4.0 if heart else 1.5):
		if absf(z - zs) > 1.6:
			for sx: float in [-1.9, 1.9]:
				_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x + sx, y + h * 0.5, z)), Vector3(0.6, h, 0.6), BASALT[2], 0.0)
		z += 3.0
	var r := c.y + 0.6
	while r < c.y + ln - 0.3:
		_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + h - 0.14, r)), Vector3(2.0 * float(pc.half), 0.28, 0.3), BASALT[4].darkened(0.1), 0.0)
		r += 1.1
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + h - 0.2, c.y + ln * 0.5)), Vector3(0.4, 0.4, ln), BASALT[4].darkened(0.1), 0.0)
	if not heart:
		return
	var ze := c.y + ln
	# The apse narrows on its left; the way out leaves on its right.
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x - 2.4, y + h * 0.5, ze - 1.6)), Vector3(1.2, h, 3.2), BASALT[1], 0.0)
	var fc := BASALT_RELIEF.lightened(0.05)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + 0.25, ze - 1.2)), Vector3(2.2, 0.5, 1.6), BASALT[3], 0.0)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + 1.5, ze - 0.35)), Vector3(1.8, 2.6, 0.2), BASALT[0], 0.0)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + 0.78, ze - 1.3)), Vector3(1.6, 0.55, 1.1), fc, 0.0)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + 1.6, ze - 1.45)), Vector3(0.85, 1.1, 0.55), fc, 0.0)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + 2.42, ze - 1.45)), Vector3(0.48, 0.55, 0.48), fc, 0.0)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y + 1.12, ze - 1.75)), Vector3(0.6, 0.18, 0.35), fc.lightened(0.05), 0.0)


# --- The hanging gardens (design 3 Oct §DT) -------------------------------------------

## Fired brick facings over the sun-dried core, and the terraces' soil.
const FACING := [Color(0.6, 0.45, 0.32), Color(0.56, 0.42, 0.3), Color(0.64, 0.48, 0.34), Color(0.52, 0.4, 0.29), Color(0.58, 0.44, 0.31)]
const TERRACE_SOIL := Color(0.3, 0.36, 0.2)
## The garden's trees (§DT: garden.hand_carried on the upper terraces,
## garden.local below), by catalogue name: the cedar isn't in the
## catalogue yet, so the "Eastern redcedar" juniper stands in for it.
const GARDEN_HIGH := ["Eastern redcedar", "Mediterranean cypress", "Juniper"]
const GARDEN_LOW := ["Date palm", "Pomegranate", "Athel tamarisk", "Saltcedar"]


## The hanging gardens (HangingGardens): the terraces, each a retaining
## wall of brick with its vaults' dark arches along it and the soil of its
## band; the channel coming out on the top terrace by the water-lift's
## stump and stepping down the back (+z) with a fall at every wall, then
## running on the ground to the river; the trees gone wild on the
## terraces; inside, the galleries, the channel's tunnel, the cistern.
func _hanging_gardens() -> void:
	palette = FACING
	var n := int(site.terraces)
	var lay: Dictionary = Delves.layout(map, site)
	_delve = lay
	_delve_off = base_e - float(lay.base_e)
	var off := _delve_off
	var r0 := HangingGardens.half(site, 0)
	_lod_m = r0 * 1.42 + LOD_M
	_lit_per_pixel = true
	var low := INF
	for i in 9:
		for j in 9:
			low = minf(low, ground(lerpf(-r0, r0, i / 8.0), lerpf(-r0, r0, j / 8.0)))
	# The way in and the way out, through the lowest wall.
	var pin: Dictionary = lay.pieces[0]
	var ex: Dictionary = lay.exit
	var cuts_front := [[float((pin.c as Vector2).x) - 1.5, float((pin.c as Vector2).x) + 1.5, -INF, float(site.base_y) - off + Delves.H_STAIR + Delves.SLAB + 0.2]]
	var cuts_back := [[float((ex.c as Vector2).x) - 1.6, float((ex.c as Vector2).x) + 1.6, -INF, maxf(float(ex.y0), float(ex.y1)) - off + Delves.H_STAIR + Delves.SLAB + 0.6]]
	for k in n:
		var hk := HangingGardens.half(site, k)
		var y0 := (low - 1.0) if k == 0 else HangingGardens.top(site, k - 1) - off - 1.0
		var y1 := HangingGardens.top(site, k) - off
		# The walls, their outer faces on the ring.
		for f in 4:
			var cuts: Array = []
			if k == 0 and f == 0:
				cuts = cuts_front
			elif k == 0 and f == 2:
				cuts = cuts_back
			_garden_wall(f, hk, y0, y1, cuts, k)
		# The band's soil, from the next wall's foot to this wall.
		var inner := HangingGardens.half(site, k + 1) - HangingGardens.WALL_T if k + 1 < n else 0.0
		_garden_band(inner, hk - HangingGardens.WALL_T, y1, k + 1 >= n)
	# The water-lift's stump on the top terrace, the channel's head.
	var tt := HangingGardens.top(site, n - 1) - off
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, tt + 1.2, -1.5)), Vector3(4.0, 2.4, 3.0), FACING[3], 0.3)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, tt + 0.9, 0.3)), Vector3(1.2, 1.0, 0.8), FACING[1], 0.3)
	_garden_channel(off)
	_garden_trees(off)
	# A camp at the foot could tend it again (§BQ): its spot before the way in.
	var pc0: Vector2 = pin.c
	_camp_spot = Vector3(pc0.x + 7.0, ground(pc0.x + 7.0, -r0 - 9.0), -r0 - 9.0)
	shade = 0.0
	_delve_from = _v.size()
	_garden_galleries(lay, off)
	_delve_to = _v.size()


## Face `f` (0 -z, 1 +x, 2 +z, 3 -x) of terrace `k`'s retaining wall, half
## `hk`, from y0 to y1: brick columns with the dark arch of a vault in every
## other one (none where the channel falls down the back); `cuts` ([x0, x1,
## y_lo, y_hi] along the face) left open.
func _garden_wall(f: int, hk: float, y0: float, y1: float, cuts: Array, k: int) -> void:
	var n2 := [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)][f] as Vector2
	var t := HangingGardens.WALL_T
	var along := Vector2(-n2.y, n2.x)
	var span := 2.0 * hk
	var cols := maxi(2, int(span / 4.0))
	var w := span / cols
	var bs := Basis(Vector3.UP, atan2(n2.x, n2.y))
	for i in cols:
		var u := -hk + (i + 0.5) * w
		var c := n2 * (hk - t * 0.5) + along * u
		var spans: Array = [[y0, y1]]
		var cut_here := false
		for ct in cuts:
			if u + w * 0.5 > float(ct[0]) and u - w * 0.5 < float(ct[1]):
				spans = [[y0, minf(y1, maxf(y0, float(ct[2])))], [maxf(y0, float(ct[3])), y1]]
				cut_here = true
		for sp in spans:
			if float(sp[1]) - float(sp[0]) < 0.05:
				continue
			_pbox(Transform3D(bs, Vector3(c.x, (float(sp[0]) + float(sp[1])) * 0.5, c.y)), Vector3(w + 0.02, float(sp[1]) - float(sp[0]), t), FACING[(i + k) % FACING.size()], 0.15)
		# A vault's arch, dark (R8), on every other column.
		var chan := f == 2 and absf(u) < 3.0
		if i % 2 == 1 and not chan and not cut_here:
			var ab := y1 - float(site.tier_m) + 0.6 if k > 0 else maxf(y0 + 1.0, y1 - float(site.tier_m) + 0.6)
			var ah := minf(float(site.tier_m) - 1.8, 3.2)
			var o := n2 * (hk + 0.03) + along * u
			_pbox(Transform3D(bs, Vector3(o.x, ab + ah * 0.5, o.y)), Vector3(w * 0.5, ah, 0.06), VOID, 0.0)
			_pbox(Transform3D(bs, Vector3(o.x, ab + ah + 0.25, o.y)), Vector3(w * 0.3, 0.5, 0.06), VOID, 0.0)
	# The coping along its top (open where the channel falls over it).
	for half_run: Array in ([[-hk, -1.4], [1.4, hk]] if f == 2 else [[-hk, hk]]):
		var cp := n2 * (hk - 0.4) + along * (float(half_run[0]) + float(half_run[1])) * 0.5
		_pbox(Transform3D(bs, Vector3(cp.x, y1 + 0.15, cp.y)), Vector3(float(half_run[1]) - float(half_run[0]), 0.3, 1.0), FACING[2].darkened(0.1), 0.3)


## Terrace soil between square rings `inner` and `outer` at `y` (its top);
## `full` fills the middle (the top terrace).
func _garden_band(inner: float, outer: float, y: float, full: bool) -> void:
	var col := TERRACE_SOIL.lerp(TerrainChunk._biome_blend(map, up), 0.25)
	if full:
		_pbox(Transform3D(Basis.IDENTITY, Vector3(0.0, y - 0.5, 0.0)), Vector3(2.0 * outer, 1.0, 2.0 * outer), col, 0.7)
		return
	var bw := outer - inner
	for f in 4:
		var n2 := [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)][f] as Vector2
		var c := n2 * (inner + bw * 0.5)
		var long := 2.0 * outer if f % 2 == 0 else 2.0 * inner
		var size := Vector3(long, 1.0, bw) if f % 2 == 0 else Vector3(bw, 1.0, long)
		_pbox(Transform3D(Basis.IDENTITY, Vector3(c.x, y - 0.5, c.y)), size, col, 0.7)


## The channel (§DT, §BE): from the top terrace's head down the back, a
## fall at each wall, then on the ground to the river (site.riv); kerbs
## of brick both sides, the water bright between them (R6).
func _garden_channel(off: float) -> void:
	var n := int(site.terraces)
	var along := 0.0
	for k in range(n - 1, -1, -1):
		var hk := HangingGardens.half(site, k)
		# From the head by the stump, or from where the fall above lands.
		var z := 0.6 if k == n - 1 else HangingGardens.half(site, k + 1) + 0.3
		var y := HangingGardens.top(site, k) - off + 0.18
		_water_strip(Vector3(0.0, y, z), Vector3(0.0, y, hk - 0.05), 1.0, along)
		along += hk - z
		for sx: float in [-1.0, 1.0]:
			_pbox(Transform3D(Basis.IDENTITY, Vector3(sx * 1.2, y + 0.1, (z + hk) * 0.5)), Vector3(0.4, 0.5, hk - z), FACING[1], 0.5)
		var below := HangingGardens.top(site, k - 1) - off + 0.18 if k > 0 else ground(0.0, hk + 1.5) + 0.12
		_water_fall(Vector3(-1.0, y, hk), Vector3(1.0, y, hk), below)
	# On the ground to the river.
	var a := Vector2(0.0, HangingGardens.half(site, 0) + 1.0)
	var b: Vector2 = site.riv
	var dl := a.distance_to(b)
	var segs := maxi(1, int(dl / 4.0))
	for i in segs:
		var p := a.lerp(b, float(i) / segs)
		var q := a.lerp(b, float(i + 1) / segs)
		var yp := ground(p.x, p.y) + 0.1
		var yq := ground(q.x, q.y) + 0.1
		_water_strip(Vector3(p.x, yp, p.y), Vector3(q.x, yq, q.y), 0.9, along)
		along += p.distance_to(q)
		var dir := (q - p).normalized()
		var side := Vector2(dir.y, -dir.x)
		var mid := (p + q) * 0.5
		for sx: float in [-1.0, 1.0]:
			var kc := mid + side * sx * 1.1
			_pbox(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(kc.x, (yp + yq) * 0.5 + 0.05, kc.y)), Vector3(0.35, 0.45, p.distance_to(q) + 0.05), FACING[3].darkened(0.1), 0.6)


## A strip of running water from `a` to `b` (local), half width `hw`,
## its uv as a river's (across, downstream from `along`).
func _water_strip(a: Vector3, b: Vector3, hw: float, along: float) -> void:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var ln := d.length()
	if ln < 0.05:
		return
	var s := Vector3(d.z, 0.0, -d.x) / ln * hw
	var q := [a - s, a + s, b + s, b - s]
	var uvs := [Vector2(-hw, along), Vector2(hw, along), Vector2(hw, along + ln), Vector2(-hw, along + ln)]
	for idx in [0, 2, 1, 0, 3, 2]:
		_wv.append(q[idx])
		_wuv.append(uvs[idx])
		_wuv2.append(Vector2(0.15, hw))


## A fall's sheet off the lip `a`-`b` (local, the lip's height) down to
## `bottom`, arcing a little out (+z) as it drops (TerrainChunk's falls).
func _water_fall(a: Vector3, b: Vector3, bottom: float) -> void:
	var h := a.y - bottom
	if h < 0.2:
		return
	var w := a.distance_to(b)
	var rows := 4
	var vs: Array = []
	for r in rows + 1:
		var t := float(r) / rows
		var out := Vector3(0.0, 0.0, 0.2 + 0.7 * sin(t * PI * 0.5))
		for side in 2:
			var p: Vector3 = (a if side == 0 else b)
			vs.append([Vector3(p.x, lerpf(a.y, bottom, t), p.z) + out, Vector2(w * side, h * t)])
	for r in rows:
		for idx in [0, 2, 1, 1, 2, 3]:
			var vv: Array = vs[r * 2 + idx]
			_fv.append(vv[0])
			_fn.append(Vector3(0.0, 0.0, 1.0))
			_fuv.append(vv[1])
			_fuv2.append(Vector2(h, w))


## The garden gone wild (§DT, §CS/§CT's one exception): the mountain trees
## the gardeners carried in on the upper terraces, grown past their
## height; the river's own below; never on the channel.
func _garden_trees(off: float) -> void:
	var n := int(site.terraces)
	var high: Array = []
	var lowl: Array = []
	for nm in GARDEN_HIGH:
		var sp := SpeciesDB.find(nm)
		if sp != null:
			high.append(sp)
	for nm in GARDEN_LOW:
		var sp := SpeciesDB.find(nm)
		if sp != null:
			lowl.append(sp)
	for k in n:
		var hk := HangingGardens.half(site, k)
		var inner := HangingGardens.half(site, k + 1) if k + 1 < n else 0.0
		var y := HangingGardens.top(site, k) - off
		var mid := (inner + hk - HangingGardens.WALL_T) * 0.5 if k + 1 < n else hk * 0.5
		var pool: Array = high if k >= n / 2 else lowl
		if pool.is_empty():
			continue
		var count := int(8.0 * mid / 12.0)
		for i in count:
			if _garden.size() >= 48 or rng.randf() < 0.35:
				continue
			var a := TAU * (i + rng.randf_range(0.2, 0.8)) / count
			var p := Vector2(cos(a), sin(a))
			p = p / maxf(absf(p.x), absf(p.y)) * (mid + rng.randf_range(-1.0, 1.0))
			if p.y > 0.0 and absf(p.x) < 3.5:
				continue
			var sp: PlantSpecies = pool[rng.randi() % pool.size()]
			var grow := rng.randf_range(1.1, 1.35) if pool == high else rng.randf_range(0.8, 1.05)
			_garden.append([Vector3(p.x, y, p.y), SpeciesDB.index_of(sp), sp.height_m.y * grow])


## The galleries, the tunnel and the cistern (HangingGardens.layout).
func _garden_galleries(lay: Dictionary, off: float) -> void:
	var pieces: Array = lay.pieces
	for i in pieces.size():
		var pc: Dictionary = pieces[i]
		var prev: Dictionary = pieces[i - 1] if i > 0 else {}
		var nxt: Dictionary = pieces[i + 1] if i + 1 < pieces.size() else {}
		match str(pc.kind):
			"passage":
				if absf(float(pc.y1) - float(pc.y0)) > 0.2:
					_delve_stair(pc, off, false, 0.0, 0.0)
				else:
					_delve_room(pc, off, [["start", 0.0, float(pc.half) - 0.05], ["end", 0.0, float(pc.half) - 0.05]])
			"room", "heart":
				var opens: Array = []
				opens.append(_opening(pc, (prev.c as Vector2) + (prev.dir as Vector2) * float(prev.len), float(prev.half)))
				if not nxt.is_empty():
					opens.append(_opening(pc, nxt.c, float(nxt.half)))
				_delve_room(pc, off, opens)
				# The vault's ribs.
				var y := float(pc.y0) - off
				var c: Vector2 = pc.c
				var r := 0.6
				while r < float(pc.len) - 0.3:
					var rp := c + (pc.dir as Vector2) * r
					_pbox(Transform3D(Basis.IDENTITY, Vector3(rp.x, y + float(pc.h) - 0.14, rp.y)), Vector3(2.0 * float(pc.half), 0.28, 0.3), FACING[3].darkened(0.15), 0.0)
					r += 1.4
				if str(pc.kind) == "heart":
					# The cistern: its basin of dark water, the water-lift's footings.
					var bc := c + (pc.dir as Vector2) * float(pc.len) * 0.55
					_pbox(Transform3D(Basis.IDENTITY, Vector3(bc.x + 0.6, y + 0.1, bc.y)), Vector3(2.6, 0.2, 3.6), Color(0.04, 0.08, 0.14), 0.0)
					for sz: float in [-1.0, 1.0]:
						_pbox(Transform3D(Basis.IDENTITY, Vector3(bc.x + 0.6, y + 0.35, bc.y + sz * 2.0)), Vector3(3.0, 0.7, 0.4), FACING[1], 0.0)
						_pbox(Transform3D(Basis.IDENTITY, Vector3(bc.x + 2.1, y + 0.35, bc.y + sz * 0.9)), Vector3(0.4, 0.7, 1.4), FACING[1], 0.0)
					_pbox(Transform3D(Basis.IDENTITY, Vector3(bc.x + 0.6, y + 1.6, bc.y - 2.6)), Vector3(0.8, 3.2, 0.8), FACING[4], 0.0)
			"stair":
				_delve_stair(pc, off, false, 0.0, 0.0)
			"exit":
				_delve_stair_open_top(pc, off, float(lay.exit_open), float(maxf(float(pc.y0), float(pc.y1))) - off + Delves.H_STAIR)


# --- The abbey (design 3 Oct §DU) -----------------------------------------------------

## Ashlar: pale grey-buff limestone and sandstone.
const ASHLAR := [Color(0.57, 0.54, 0.48), Color(0.53, 0.5, 0.45), Color(0.6, 0.56, 0.48), Color(0.5, 0.48, 0.44), Color(0.55, 0.51, 0.44)]


## The abbey (Monuments._abbey): its church roofless, the west end -z and
## the east end +z: the aisles' outer walls broken and lower, the nave's
## arcades of pointed arches on their piers with the clerestory over them,
## the gables at both ends with their tall lancets open to the sky, the
## transepts' stumps, the tower at the west end's north corner (whole, or
## two of its walls fallen); south of it the cloister and the chapter house
## as foundations in the turf, and the warming house with its chimney
## stack. The crypt (the barrow kit) under the east end.
func _abbey() -> void:
	palette = ASHLAR
	var length: float = site.length_m
	var w: float = site.nave_w
	var h: float = site.wall_h
	var half := length * 0.5
	var hw := w * 0.5
	var t := 1.2
	var aisle := w * 0.22
	_lod_m = half + w + LOD_M
	_lit_per_pixel = true
	var rr := RandomNumberGenerator.new()
	rr.seed = int(site.ruin_seed)
	# The crossing and the transepts.
	var zx0 := half - length * 0.3 - w * 0.8
	var zx1 := zx0 + w * 0.8
	var te := hw + w * 0.55
	# The aisles' outer walls: lower, broken, a lancet a bay; open at the
	# crossing.
	var bay := 5.0
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw - t * 0.5)
		for run: Array in [[-half, zx0], [zx1, half - length * 0.3 + 0.0]]:
			_lancet_wall(Vector2(x, float(run[0])), Vector2(x, float(run[1])), h * 0.55, t, bay, 1.4, rr, 0.35)
		# The chancel's side walls, full height, a lancet a bay.
		_lancet_wall(Vector2(x, half - length * 0.3), Vector2(x, half), h, t, bay, 1.4, rr, 0.15)
		# The transept's end and its two side walls, broken down.
		_lancet_wall(Vector2(sx * te, zx0), Vector2(sx * te, zx1), h * 0.8, t, 4.0, 1.6, rr, 0.5)
		for tz: float in [zx0, zx1]:
			_lancet_wall(Vector2(sx * hw, tz), Vector2(sx * te, tz), h * 0.7, t, 4.0, 1.2, rr, 0.6)
	# The nave's arcades: piers, pointed arches, the clerestory over them.
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw - aisle)
		var z := -half + bay
		var spring := h * 0.42
		while z < zx0 - 0.5:
			var g := ground(x, z)
			var fallen := rr.randf() < 0.18
			var ph := (spring if not fallen else rr.randf_range(1.0, spring * 0.6))
			_pbox(Transform3D(Basis.IDENTITY, Vector3(x, g + ph * 0.5 - 0.5, z)), Vector3(1.3, ph + 1.0, 1.3), ASHLAR[0], 0.25)
			var zn := z + bay
			if not fallen and zn < zx0 - 0.5 and rr.randf() > 0.15:
				var gy := g + spring
				_pointed_arch(Vector3(x, gy, z), Vector3(x, gy, zn), 1.0)
				# The clerestory over the bay, its lancet open.
				var top := g + h * rr.randf_range(0.85, 1.0)
				var ay := gy + bay * 0.55
				for k in 2:
					var zz := z + (0.25 + 0.5 * k) * bay
					_pbox(Transform3D(Basis.IDENTITY, Vector3(x, (ay + top) * 0.5, zz)), Vector3(1.0, top - ay, bay * 0.3), ASHLAR[(k + 1) % 5], 0.2)
				_pbox(Transform3D(Basis.IDENTITY, Vector3(x, top - 0.6, z + bay * 0.5)), Vector3(1.0, 1.2, bay * 0.42), ASHLAR[2], 0.2)
			z = zn
	# The gables: the east end's three tall lancets, the west front's door
	# and window.
	_gable(Vector2(-hw, half), Vector2(hw, half), h * 1.25, t, [[-0.3, 0.12, 0.2, 0.85], [0.0, 0.14, 0.15, 0.95], [0.3, 0.12, 0.2, 0.85]])
	_gable(Vector2(-hw, -half), Vector2(hw, -half), h * 1.15, t, [[0.0, 0.16, 0.0, 0.32], [0.0, 0.2, 0.42, 0.85]])
	# The tower at the west end's north corner.
	var ts := clampf(w * 0.55, 7.0, 10.0)
	var tc := Vector2(-hw - ts * 0.5 + t, -half + ts * 0.5)
	var th: float = site.tower_h
	inside_at = Vector3(tc.x, 0.0, tc.y)
	inside = INSIDE
	for f in 4:
		var n2 := [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)][f] as Vector2
		var along := Vector2(-n2.y, n2.x)
		var a := tc + n2 * (ts * 0.5 - t * 0.5) - along * ts * 0.5
		var b := tc + n2 * (ts * 0.5 - t * 0.5) + along * ts * 0.5
		var wh := th if bool(site.tower_whole) or f < 2 else th * rr.randf_range(0.3, 0.55)
		_lancet_wall(a, b, wh, t, ts * 0.5, 0.9, rr, 0.0 if bool(site.tower_whole) or f < 2 else 0.6, true)
		if wh > th * 0.9:
			# Its parapet's merlons.
			for k in 3:
				var mp := a.lerp(b, (k + 0.5) / 3.0)
				_pbox(Transform3D(Basis(Vector3.UP, atan2(-along.y, along.x)), Vector3(mp.x, ground(mp.x, mp.y) + wh + 0.5, mp.y)), Vector3(ts * 0.2, 1.0, t), ASHLAR[3], 0.3)
		if rr.randf() < 0.7:
			var top3 := Vector3(b.x, ground(b.x, b.y) + wh, b.y) + Vector3(n2.x, 0.0, n2.y) * t * 0.5
			ivy(top3, Vector3(n2.x, 0.0, n2.y), rr.randf_range(4.0, minf(14.0, wh)))
	inside = 0.0
	inside_at = Vector3.INF
	# Rubble where the roof and the vaults came down.
	rubble(Vector3(0.0, 0.0, -half * 0.55), w * 0.3, 18)
	rubble(Vector3(hw * 0.6, 0.0, -half * 0.3), 4.0, 10)
	# South of the church: the cloister, the chapter house, the warming house.
	var cx0 := hw + t
	var cl := clampf(length * 0.45, 18.0, 36.0)
	var cz0 := -half + 6.0
	_foundation(Rect2(cx0, cz0, cl, cl), 0.6)
	_foundation(Rect2(cx0 + 4.0, cz0 + 4.0, cl - 8.0, cl - 8.0), 0.35)
	_foundation(Rect2(cx0 + cl * 0.2, cz0 + cl, cl * 0.5, cl * 0.45), 0.5)
	# The warming house on the cloister's south range, its stack standing.
	var whx := cx0 + cl + 4.5
	var whz := cz0 + cl * 0.5
	var wroom := Rect2(whx - 4.0, whz - 5.0, 8.0, 10.0)
	_foundation(wroom, 2.6)
	var gs := ground(whx + 3.4, whz)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(whx + 3.4, gs + 4.5, whz)), Vector3(1.6, 9.0, 2.4), ASHLAR[1], 0.3)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(whx + 3.4, gs + 9.2, whz)), Vector3(1.9, 0.5, 2.7), ASHLAR[3].darkened(0.2), 0.2)
	_pbox(Transform3D(Basis.IDENTITY, Vector3(whx + 2.55, gs + 0.8, whz)), Vector3(0.06, 1.4, 1.4), VOID, 0.0)
	# The warming house's hearth: the one fire the monks kept (OldHearths).
	_camp_spot = Vector3(whx + 1.2, ground(whx + 1.2, whz), whz)
	if Delves.has_delve(site):
		_delve_build()


## A wall from `a` to `b` (its line, local x/z), `wh` high and `t` thick,
## broken into bays of `bay` m each with a lancet `lw` wide open to the sky;
## `broken` the share of its bays fallen to stumps; `tower` puts the
## lancets high (belfry openings).
func _lancet_wall(a: Vector2, b: Vector2, wh: float, t: float, bay: float, lw: float, rr: RandomNumberGenerator, broken: float, tower := false) -> void:
	var along := b - a
	var ln := along.length()
	if ln < 0.5:
		return
	var dir := along / ln
	var bs := Basis(Vector3.UP, atan2(-dir.y, dir.x))
	var bays := maxi(1, int(round(ln / bay)))
	var bl := ln / bays
	for i in bays:
		var c := a + dir * (i + 0.5) * bl
		var g := minf(ground(c.x, c.y), minf(ground(c.x - dir.x * bl * 0.5, c.y - dir.y * bl * 0.5), ground(c.x + dir.x * bl * 0.5, c.y + dir.y * bl * 0.5)))
		var hh := wh
		if rr.randf() < broken:
			hh = wh * rr.randf_range(0.1, 0.45)
		var sill := wh * (0.62 if tower else 0.3)
		var head := wh * (0.88 if tower else 0.78)
		var win := hh > head + 0.6 and bl > lw + 1.2
		var col: Color = ASHLAR[(i + int(c.x * 3.0)) % ASHLAR.size()]
		if not win:
			_pbox(Transform3D(bs, Vector3(c.x, g - 0.6 + (hh + 0.6) * 0.5, c.y)), Vector3(bl + 0.02, hh + 0.6, t), col, 0.3)
			continue
		# The piers either side of the lancet, the sill under it, the head
		# over it with its point.
		var pw := (bl - lw) * 0.5
		for s2: float in [-1.0, 1.0]:
			var pc := c + dir * s2 * (lw * 0.5 + pw * 0.5)
			_pbox(Transform3D(bs, Vector3(pc.x, g - 0.6 + (hh + 0.6) * 0.5, pc.y)), Vector3(pw + 0.02, hh + 0.6, t), col, 0.3)
		_pbox(Transform3D(bs, Vector3(c.x, g - 0.6 + (sill + 0.6) * 0.5, c.y)), Vector3(lw + 0.04, sill + 0.6, t), col.darkened(0.04), 0.45)
		_pbox(Transform3D(bs, Vector3(c.x, g + (head + hh) * 0.5, c.y)), Vector3(lw + 0.04, hh - head, t), col, 0.3)
		for s2: float in [-1.0, 1.0]:
			var kp := c + dir * s2 * lw * 0.28
			_pbox(Transform3D(bs * Basis(Vector3.BACK, s2 * 0.75), Vector3(kp.x, g + head - lw * 0.22, kp.y)), Vector3(lw * 0.62, 0.35, t * 0.9), col.lightened(0.04), 0.2)


## A pointed arch from pier top `a` to pier top `b` (local), `t` thick:
## two stones leaning together to its point.
func _pointed_arch(a: Vector3, b: Vector3, t: float) -> void:
	var span := a.distance_to(b)
	var apex := (a + b) * 0.5 + Vector3(0.0, span * 0.55, 0.0)
	var along := (b - a).normalized()
	for pair in [[a, apex], [b, apex]]:
		var p0: Vector3 = pair[0]
		var p1: Vector3 = pair[1]
		var mid := (p0 + p1) * 0.5
		var d := p1 - p0
		var ang := atan2(d.y, d.dot(along))
		var bs := Basis(Vector3.UP, atan2(-along.z, along.x)) * Basis(Vector3.BACK, ang)
		_pbox(Transform3D(bs, mid), Vector3(d.length() + 0.4, 0.7, t), ASHLAR[2], 0.25)


## A gable wall from `a` to `b`, `gh` high at its peak, with openings
## [[at (−0.5..0.5 along), half width (share of its length), sill (share
## of its height), head (share)]...] open to the sky.
func _gable(a: Vector2, b: Vector2, gh: float, t: float, holes: Array) -> void:
	var along := b - a
	var ln := along.length()
	var dir := along / ln
	var bs := Basis(Vector3.UP, atan2(-dir.y, dir.x))
	var cols := maxi(4, int(ln / 1.4))
	var cw := ln / cols
	for i in cols:
		var u := (i + 0.5) / cols - 0.5
		var c := a + dir * (u + 0.5) * ln
		var g := ground(c.x, c.y)
		var top := gh * (1.0 - absf(u) * 0.9)
		var spans: Array = [[-0.6, top]]
		for hl in holes:
			if absf(u - float(hl[0])) < float(hl[1]):
				var s0 := gh * float(hl[2])
				var s1 := gh * float(hl[3]) - (absf(u - float(hl[0])) / float(hl[1])) * gh * 0.08
				var nsp: Array = []
				for sp in spans:
					if float(sp[1]) <= s0 or float(sp[0]) >= s1:
						nsp.append(sp)
						continue
					if float(sp[0]) < s0:
						nsp.append([float(sp[0]), s0])
					if float(sp[1]) > s1:
						nsp.append([s1, float(sp[1])])
				spans = nsp
		for sp in spans:
			if float(sp[1]) - float(sp[0]) < 0.1:
				continue
			_pbox(Transform3D(bs, Vector3(c.x, g + (float(sp[0]) + float(sp[1])) * 0.5, c.y)), Vector3(cw + 0.02, float(sp[1]) - float(sp[0]), t), ASHLAR[i % ASHLAR.size()], 0.25)


## Foundations in the turf round rectangle `r` (local x/z), `fh` high.
func _foundation(r: Rect2, fh: float) -> void:
	var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a: Vector2 = cs[k]
		var b: Vector2 = cs[(k + 1) % 4]
		var segs := maxi(1, int(a.distance_to(b) / 3.0))
		for i in segs:
			var p := a.lerp(b, (i + 0.5) / segs)
			var g := ground(p.x, p.y)
			var hh := fh * rng.randf_range(0.6, 1.1)
			var dir := (b - a).normalized()
			_pbox(Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(p.x, g - 0.3 + (hh + 0.3) * 0.5, p.y)), Vector3(a.distance_to(b) / segs + 0.02, hh + 0.3, 0.9), ASHLAR[(i + k) % ASHLAR.size()].darkened(0.06), 0.6)
