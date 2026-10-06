class_name Prelit
## Pre-lit models (design 6 Oct §ES.2, Mike: 3D pixel art, after reference
## frame 3): the light is painted into the models, as on the Dreamcast and
## the GameCube, and the engine's live light only adds the time of day's
## tint (and its cast shadows) and the fire. Two halves:
##
##   * baked here, into each model's vertex colours as it's built: ambient
##     occlusion (creases, the inside of a hood, the heart of a crown, the
##     foot of a trunk), never grey: the dark is pulled toward the scene's
##     shade colour, navy, or dark olive on green things (ao_tint());
##   * painted in the shaders (shaders/prelit.gdshaderinc): top-lit from the
##     sky, the shade side toward the same navy or olive, and a light()
##     where the sun and moon tint without N.L and the fire rounds what it
##     lights (shaders/prelit_light.gdshaderinc).
##
## data/look.json "prelit"; on: false (or PRELIT=0 in the environment)
## puts the old live lighting back for an A/B.

static var P: Dictionary = Tuning.section("look", "prelit")


static func on() -> bool:
	var env := OS.get_environment("PRELIT")
	if env != "":
		return env != "0"
	return bool(P.get("on", true))


## The shade multipliers (linear): what a fully occluded colour is
## multiplied by, before the occlusion's strength. Navy keeps the blue and
## cuts the red; olive keeps the green and some red.
static func shade_navy() -> Color:
	return Color(str(P.get("shade_navy", "#9ab0f8"))).srgb_to_linear()


static func shade_olive() -> Color:
	return Color(str(P.get("shade_olive", "#ceda95"))).srgb_to_linear()


## 0-1: how green a colour is (its green over the larger of red and blue,
## as the grade's olive test does).
static func greenness(c: Color) -> float:
	return clampf((c.g - maxf(c.r, c.b)) / maxf(c.g, 1e-3) * 2.5, 0.0, 1.0)


## `c` darkened by occlusion `ao` (1 open, 0 shut in) toward the scene's
## shade colour: navy, or olive on a green.
static func ao_tint(c: Color, ao: float) -> Color:
	var floor_k := float(P.get("ao_floor", 0.4))
	var a := clampf(ao, 0.0, 1.0)
	var shade := shade_navy().lerp(shade_olive(), greenness(c))
	var dark := Color(c.r * shade.r, c.g * shade.g, c.b * shade.b) * floor_k
	var out := dark.lerp(c, a)
	out.a = c.a
	return out


## Bake ambient occlusion into a triangle mesh's vertex colours (arrays as
## for ArrayMesh; non-indexed or indexed): the mesh's triangles are dropped
## into a coarse occupancy grid (`cells` along its longest side), and each
## vertex looks out along its normal's hemisphere (8 directions, `steps`
## cells each): the nearer the cells it meets are filled, the darker.
## Small models (figures, heads, hoods, props); trees and the ground have
## their own cheaper terms. Returns the arrays, changed in place.
static func bake(arrays: Array, cells := 20, steps := 5, strength := 1.0) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm = arrays[Mesh.ARRAY_NORMAL]
	if v.is_empty() or nrm == null or (nrm as PackedVector3Array).size() != v.size():
		return arrays
	var n: PackedVector3Array = nrm
	var col = arrays[Mesh.ARRAY_COLOR]
	var colors: PackedColorArray = col if col != null and (col as PackedColorArray).size() == v.size() else PackedColorArray()
	if colors.is_empty():
		colors.resize(v.size())
		colors.fill(Color.WHITE)
	var idx = arrays[Mesh.ARRAY_INDEX]
	var tris := PackedInt32Array()
	if idx != null and (idx as PackedInt32Array).size() > 0:
		tris = idx
	else:
		tris.resize(v.size())
		for i in v.size():
			tris[i] = i
	var lo := v[0]
	var hi := v[0]
	for p in v:
		lo = lo.min(p)
		hi = hi.max(p)
	var span := maxf(maxf(hi.x - lo.x, hi.y - lo.y), maxf(hi.z - lo.z, 1e-3))
	var cell := span / float(cells)
	lo -= Vector3.ONE * cell
	var dims := Vector3i(((hi - lo) / cell).ceil()) + Vector3i(2, 2, 2)
	var grid := PackedByteArray()
	grid.resize(dims.x * dims.y * dims.z)
	# Fill: each triangle's corners, middle and edge middles (the cells are
	# coarse next to the triangles, so that marks every cell it crosses).
	for t in range(0, tris.size() - 2, 3):
		var a := v[tris[t]]
		var b := v[tris[t + 1]]
		var c := v[tris[t + 2]]
		for p in [a, b, c, (a + b + c) / 3.0, (a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5]:
			var g := Vector3i(((p as Vector3) - lo) / cell)
			if g.x >= 0 and g.y >= 0 and g.z >= 0 and g.x < dims.x and g.y < dims.y and g.z < dims.z:
				grid[(g.z * dims.y + g.y) * dims.x + g.x] = 1
	var dirs: Array[Vector3] = []
	for k in 8:
		var a := TAU * k / 8.0
		dirs.append(Vector3(cos(a) * 0.75, 0.66, sin(a) * 0.75).normalized())
	for i in v.size():
		var nn := n[i].normalized()
		var t1 := nn.cross(Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := nn.cross(t1)
		var hit := 0.0
		for d in dirs:
			var w := (t1 * d.x + nn * d.y + t2 * d.z).normalized()
			for s in steps:
				var p := v[i] + nn * cell * 0.6 + w * cell * (s + 1.0)
				var g := Vector3i((p - lo) / cell)
				if g.x < 0 or g.y < 0 or g.z < 0 or g.x >= dims.x or g.y >= dims.y or g.z >= dims.z:
					break
				if grid[(g.z * dims.y + g.y) * dims.x + g.x] == 1:
					hit += 1.0 - float(s) / float(steps)
					break
		var ao := 1.0 - clampf(hit / float(dirs.size()) * strength, 0.0, 1.0)
		colors[i] = ao_tint(colors[i], ao)
	arrays[Mesh.ARRAY_COLOR] = colors
	return arrays
