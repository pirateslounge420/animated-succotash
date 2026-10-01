class_name PlantMeshes
## Low-poly placeholder meshes per plant shape (DESIGN.md: prototype uses
## greybox geometry; real models replace these). Each mesh is 1 unit tall
## (instances scale it to the species' height), grows along +Y from the
## origin (hanging plants grow down along -Y), is smooth shaded (normals
## averaged within each part: a trunk, a crown lobe, a frond), and carries
## vertex color RGB plus a sway weight in alpha (0 at the roots, 1 at the
## crown) that shaders/foliage.gdshader uses for wind.
##
## Branchy canopy trees (TreeLayouts.branchy) are drawn from their layout's
## skeleton in the detail ring: a trunk forking into limbs and branches,
## and leaf clusters on the outer third of each limb and branch with open
## air between them, not a solid crown, so from below you see the limbs,
## sky through the gaps and whatever moves up there (leaf_clusters()).
## Wood you can hold (trunks, limbs, branches, and the trunks of palms,
## conifers and mangroves) has a sway weight of 0, so a handhold never
## drifts off it in the wind; leaves, fronds and vines still sway.
##
## How leafy a crown is: the species' `leaf_density` sets how many clusters
## its mesh carries; each tree's leaf amount (leaf_amount(): its growth and
## how dry its site is, in the MultiMesh custom data) thins and shrinks
## them in the foliage shader, and the season (LeafSeason: the deciduous
## species materials' `leaf_season` and `sp_autumn`) turns and thins them
## through the autumn and brings them back in spring.

const S := PlantSpecies.Shape

static var _cache := {} # Vector3i(species index, lod, layout) -> ArrayMesh (main thread)
## The same keys -> mesh arrays, built by workers (warm()) or on demand;
## and the icosphere cache. Both behind _mutex: chunk workers build plant
## geometry (and ruins, boulders) in parallel.
static var _arrays := {}
static var _mutex := Mutex.new()
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if not _material:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/foliage.gdshader")
		Look.register(_material)
	return _material


## Species with their own tiles (design §AH) get their own material: the
## shared one plus the species' leaf cutout, autumn leaf, foliage mass and
## bark tiles (sp_tiled on, so the shader draws the tiles times white and
## the plant's genes jitter, not times the species colour). Others share
## material(). Main thread; one per species, made on first use, so only
## the region's species are resident.
static var _materials := {} # species index -> ShaderMaterial
static var _tiles := {} # res:// path -> ImageTexture


static func material_for(sp: PlantSpecies) -> ShaderMaterial:
	if sp == null or sp.tiles.is_empty():
		return material()
	var idx := SpeciesDB.index_of(sp)
	if _materials.has(idx):
		return _materials[idx]
	var m := material().duplicate() as ShaderMaterial
	Look.register(m)
	m.set_shader_parameter("sp_tiled", true)
	var leaf := tile(sp.tiles.get("leaf", ""))
	m.set_shader_parameter("sp_leaf", leaf)
	m.set_shader_parameter("sp_leaf_autumn", tile(sp.tiles.get("leaf_autumn", "")) if sp.tiles.has("leaf_autumn") else leaf)
	m.set_shader_parameter("sp_leaves", tile(sp.tiles.get("leaves", "")))
	m.set_shader_parameter("sp_bark", tile(sp.tiles.get("bark", "")))
	m.set_shader_parameter("sp_has_bark", sp.tiles.has("bark"))
	m.set_shader_parameter("sp_leaf_color", sp.leaf_color)
	m.set_shader_parameter("sp_autumn_color", sp.autumn_color)
	# A deciduous species runs the staged season clock (LeafSeason).
	m.set_shader_parameter("sp_deciduous", sp.deciduous)
	m.set_shader_parameter("sp_bark_tile_m", sp.bark_tile_m)
	# A leaf cell on the near cards: the leaf's own length, but never so
	# small that it's below a few pixels a few meters off.
	m.set_shader_parameter("sp_leaf_m", maxf(sp.leaf_m * 1.3, 0.12))
	_materials[idx] = m
	return m


## Every species material made so far, by species index (the season
## updates them).
static func species_materials() -> Dictionary:
	return _materials


## A species tile (design §AH), read straight from its PNG (the folder is
## .gdignore'd: 3,000 generated tiles, not imported resources), with
## mipmaps for the shaders' two-level cap (§AG). Null if missing.
static func tile(path: String) -> ImageTexture:
	if path == "":
		return null
	if _tiles.has(path):
		return _tiles[path]
	var tex: ImageTexture = null
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	if not bytes.is_empty() and img.load_png_from_buffer(bytes) == OK:
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	else:
		push_warning("PlantMeshes: species tile %s is missing" % path)
	_tiles[path] = tex
	return tex


## Detail levels. HERO, for the chunks right around the player: crown
## lobes are geodesic spheres of 180 triangles (not 80), round parts
## (trunks, branches, stems, cones) have half as many sides again, so
## silhouettes up close are round and smooth like GameCube-era models
## rather than faceted. NEAR, the rest of the detail ring: 80-triangle
## lobes. FAR, beyond it: 80-triangle lobes, trunks 5-sided, no branches
## or leaf cards.
const LOD_HERO := 0
const LOD_NEAR := 1
const LOD_FAR := 2
## A branchy tree's light level (1 Oct, Mike's Mac: the jungle's 157 M
## triangles): between the full leaf cards (within look.json
## ranges.tree_full_m) and the far picture (past ranges.tree_light_m), the
## trunk and its main limbs and a few big leaf clusters, about 300
## triangles. Layouts only; anything else falls back to the near level.
const LOD_LIGHT := 3
## Leaf clusters a light tree keeps (spread over the crown, scaled up so
## they cover about the same).
const LIGHT_CLUSTERS := 16
## Main limbs a light tree keeps (a conifer's many whorls thinned evenly).
const LIGHT_LIMBS := 8
## Far trees as 2D (from play: "the distant things as 2D", for speed):
## each species' far level is one quad, turned to face the camera round
## the tree's own up in the foliage shader (UV2.x 6), its outline the far
## model's (_build_impostor()): 2 triangles for the ~1,500 of the far model.
## IMPOSTORS=0 in the environment keeps the far models (renders, A/B).
static var IMPOSTORS := OS.get_environment("IMPOSTORS") != "0"
## Crown lobe detail at each level (geosphere() frequency).
const CROWN_FREQ := [3, 2, 2, 2]

static var _ico := {}

## Every plant mesh carries CUSTOM0 per vertex: for a leaf cluster's cards,
## the cluster's center (unit frame) and its 0-1 thinning key; (0, 0, 0,
## -1) elsewhere.
const FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT


## Unit icosphere [vertices, triangle indices], subdivided `level` times,
## wound so (b - a) x (c - a) points outward like the other parts.
static func icosphere(level: int) -> Array:
	_mutex.lock()
	var cached = _ico.get(level)
	_mutex.unlock()
	if cached != null:
		return cached
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := PackedVector3Array()
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(p.normalized())
	var faces := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4,
		11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5,
		2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for l in level:
		var mid := {}
		var next := PackedInt32Array()
		for f in range(0, faces.size(), 3):
			var m: Array[int] = []
			for e in [[faces[f], faces[f + 1]], [faces[f + 1], faces[f + 2]], [faces[f + 2], faces[f]]]:
				var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
				if not mid.has(key):
					mid[key] = verts.size()
					verts.append((verts[e[0]] + verts[e[1]]).normalized())
				m.append(mid[key])
			next.append_array([faces[f], m[0], m[2], faces[f + 1], m[1], m[0], faces[f + 2], m[2], m[1], m[0], m[1], m[2]])
		faces = next
	# Wind every face outward.
	for f in range(0, faces.size(), 3):
		var a := verts[faces[f]]
		if (verts[faces[f + 1]] - a).cross(verts[faces[f + 2]] - a).dot(a) < 0.0:
			var tmp := faces[f + 1]
			faces[f + 1] = faces[f + 2]
			faces[f + 2] = tmp
	_mutex.lock()
	if not _ico.has(level):
		_ico[level] = [verts, faces]
	var out: Array = _ico[level]
	_mutex.unlock()
	return out


## Unit geodesic sphere [vertices, triangle indices]: each icosahedron
## face split into `freq`² triangles (20 × freq² in all). Powers of two
## are icosphere()'s.
static func geosphere(freq: int) -> Array:
	if freq == 1 or freq == 2 or freq == 4:
		return icosphere([0, 0, 1, 1, 2][freq])
	_mutex.lock()
	var cached = _ico.get(-freq)
	_mutex.unlock()
	if cached != null:
		return cached
	var base: Array = icosphere(0)
	var corners: PackedVector3Array = base[0]
	var tris: PackedInt32Array = base[1]
	var verts := PackedVector3Array()
	var faces := PackedInt32Array()
	var index := {}
	for f in range(0, tris.size(), 3):
		var a := corners[tris[f]]
		var b := corners[tris[f + 1]]
		var c := corners[tris[f + 2]]
		# Grid points a + (b - a) i/n + (c - a) j/n, shared along edges.
		var ids := {}
		for i in freq + 1:
			for j in freq + 1 - i:
				var p := (a + (b - a) * i / freq + (c - a) * j / freq).normalized()
				var key := Vector3i((p * 100000.0).round())
				if not index.has(key):
					index[key] = verts.size()
					verts.append(p)
				ids[Vector2i(i, j)] = index[key]
		for i in freq:
			for j in freq - i:
				faces.append_array([ids[Vector2i(i, j)], ids[Vector2i(i + 1, j)], ids[Vector2i(i, j + 1)]])
				if i + j < freq - 1:
					faces.append_array([ids[Vector2i(i + 1, j)], ids[Vector2i(i + 1, j + 1)], ids[Vector2i(i, j + 1)]])
	# Wind every face outward.
	for f in range(0, faces.size(), 3):
		var p0 := verts[faces[f]]
		if (verts[faces[f + 1]] - p0).cross(verts[faces[f + 2]] - p0).dot(p0) < 0.0:
			var tmp := faces[f + 1]
			faces[f + 1] = faces[f + 2]
			faces[f + 2] = tmp
	_mutex.lock()
	if not _ico.has(-freq):
		_ico[-freq] = [verts, faces]
	var out: Array = _ico[-freq]
	_mutex.unlock()
	return out


## A tree shape's proportions, as fractions of its height: Vector4(trunk
## radius, trunk collider height, crown radius, crown bottom). Trunk
## colliders, climbing, rain shelter and rustling read these; a crown
## radius of 0 means no crown to shelter under or brush through.
static func tree_dims(shape: int) -> Vector4:
	match shape:
		S.CONIFER:
			return Vector4(0.04, 0.35, 0.28, 0.15)
		S.BROADLEAF:
			return Vector4(0.05, 0.6, 0.42, 0.45)
		S.GNARLED:
			return Vector4(0.075, 0.45, 0.5, 0.46)
		S.EMERGENT:
			return Vector4(0.03, 0.85, 0.3, 0.8)
		S.UMBRELLA:
			return Vector4(0.045, 0.7, 0.65, 0.72)
		S.PALM:
			return Vector4(0.03, 0.9, 0.42, 0.75)
		S.CYPRESS:
			return Vector4(0.06, 0.62, 0.22, 0.42)
		S.MANGROVE:
			return Vector4(0.2, 0.35, 0.5, 0.53)
		S.BAMBOO:
			return Vector4(0.06, 0.6, 0.2, 0.4)
		S.ROSETTE:
			return Vector4(0.07, 0.75, 0.25, 0.7)
		S.SPIKE_ROSETTE:
			return Vector4(0.2, 0.3, 0.0, 0.0)
		S.CACTUS:
			return Vector4(0.08, 1.0, 0.0, 0.0)
	return Vector4(0.05, 0.5, 0.35, 0.4)


## Can you climb it? Trees with a trunk and branches, not cacti or rosettes.
static func climbable(shape: int) -> bool:
	return shape in [S.CONIFER, S.BROADLEAF, S.GNARLED, S.EMERGENT, S.UMBRELLA, S.PALM, S.CYPRESS, S.MANGROVE, S.BAMBOO]


## A species' mesh at detail level `lod` (LOD_HERO, LOD_NEAR, LOD_FAR);
## for a branchy tree, `layout` (0 .. TreeLayouts.COUNT - 1) picks one of
## its layouts (hero and near levels only; -1, and every far mesh, is the
## old single-crown tree).
static func mesh_for(sp: PlantSpecies, lod := LOD_NEAR, layout := -1) -> ArrayMesh:
	var idx := SpeciesDB.index_of(sp)
	if lod == LOD_FAR or not TreeLayouts.branchy(sp):
		layout = -1
	# Young layouts (TreeLayouts slots) have the near level only: slim
	# young wood gains nothing from more; nor has anything but a layout a
	# light level.
	if layout >= TreeLayouts.COUNT or (lod == LOD_LIGHT and layout < 0):
		lod = LOD_NEAR
	var key := Vector3i(idx, lod, layout)
	if _cache.has(key):
		return _cache[key]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_for(sp, lod, layout), [], {}, FORMAT)
	_cache[key] = mesh
	return mesh


## The world seed that grows the branchy trees' layouts. Call on the main
## thread before any chunk worker runs (ChunkManager.setup); a new seed
## drops the layouts built for the old one.
static func use_seed(world_seed: int) -> void:
	if not TreeLayouts.use_seed(world_seed):
		return
	_mutex.lock()
	for key in _arrays.keys():
		if (key as Vector3i).z >= 0:
			_arrays.erase(key)
	_mutex.unlock()
	for key in _cache.keys():
		if (key as Vector3i).z >= 0:
			_cache.erase(key)


## Build the geometry of these species (indices), every level (and every
## layout of the branchy trees), ahead of need: chunk workers call it for
## the plants they place, so the main thread only uploads meshes
## (mesh_for) instead of building them.
static func warm(species_indices: Array) -> void:
	var all := SpeciesDB.all()
	for key in species_indices:
		# Understory young come keyed by stage (PlantGrowth.JUV_KEY).
		var idx: int = int(key) % PlantGrowth.JUV_KEY
		var code: int = int(key) / PlantGrowth.JUV_KEY
		if code > 0:
			young_arrays(all[idx], code, LOD_NEAR)
			continue
		for lod in 4:
			if lod == LOD_FAR or not TreeLayouts.branchy(all[idx]):
				if lod != LOD_LIGHT:
					arrays_for(all[idx], lod)
			else:
				for layout in TreeLayouts.COUNT:
					arrays_for(all[idx], lod, layout)


## A species' mesh arrays (thread-safe; built once and shared).
static func arrays_for(sp: PlantSpecies, lod := LOD_NEAR, layout := -1) -> Array:
	var idx := SpeciesDB.index_of(sp)
	if lod == LOD_FAR or not TreeLayouts.branchy(sp):
		layout = -1
	if layout >= TreeLayouts.COUNT or (lod == LOD_LIGHT and layout < 0):
		lod = LOD_NEAR
	var key := Vector3i(idx, lod, layout)
	_mutex.lock()
	var cached = _arrays.get(key)
	_mutex.unlock()
	if cached != null:
		return cached
	var built: Array
	if layout >= 0:
		built = _build_layout(sp, idx, lod, layout)
	elif lod == LOD_FAR and IMPOSTORS:
		built = _build_impostor(sp, idx)
	else:
		built = _build(sp, idx, lod)
	_mutex.lock()
	if not _arrays.has(key):
		_arrays[key] = built
	var out: Array = _arrays[key]
	_mutex.unlock()
	return out


## The young layouts (TreeLayouts slots) a chunk's trees grow, ahead of
## need (chunk workers; `prepared`: VegetationPlacer.prepare()'s output).
static func warm_layouts(prepared: Dictionary) -> void:
	var all := SpeciesDB.all()
	for key in prepared:
		var entry: Array = prepared[key]
		if entry.size() < 4:
			continue
		var sp: PlantSpecies = all[int(key) % PlantGrowth.JUV_KEY]
		for l in (entry[3] as Dictionary):
			if int(l) >= TreeLayouts.COUNT:
				arrays_for(sp, LOD_NEAR, int(l))


## An understory young plant's mesh (design §AR; `code`:
## PlantGrowth.young_code): a seedling, or a sapling / young tree in its
## species' young form (a young layout when it grows from its architecture:
## open-grown or forest-grown), else the grown mesh (scaled down).
static func young_mesh(sp: PlantSpecies, code: int, lod := LOD_NEAR) -> ArrayMesh:
	var layout := _young_layout(sp, code)
	if code > 1 and layout < 0:
		return mesh_for(sp, lod)
	if code > 1:
		return mesh_for(sp, lod, layout)
	var key := Vector3i(SpeciesDB.index_of(sp), lod, -2)
	if _cache.has(key):
		return _cache[key]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, young_arrays(sp, code, lod), [], {}, FORMAT)
	_cache[key] = mesh
	return mesh


## Its arrays (thread-safe; built once and shared).
static func young_arrays(sp: PlantSpecies, code: int, lod := LOD_NEAR) -> Array:
	var layout := _young_layout(sp, code)
	if code > 1:
		return arrays_for(sp, lod, layout) if layout >= 0 else arrays_for(sp, lod)
	var idx := SpeciesDB.index_of(sp)
	var key := Vector3i(idx, lod, -2)
	_mutex.lock()
	var cached = _arrays.get(key)
	_mutex.unlock()
	if cached != null:
		return cached
	var built := _build_seedling(sp, idx, lod)
	_mutex.lock()
	if not _arrays.has(key):
		_arrays[key] = built
	var out: Array = _arrays[key]
	_mutex.unlock()
	return out


## The young layout an understory code grows (-1: none: a seedling, or a
## species without an architecture).
static func _young_layout(sp: PlantSpecies, code: int) -> int:
	if code <= 1 or not TreeArch.grows(sp):
		return -1
	var slot := 2 if code <= 3 else 1
	var sub := 0 if code % 2 == 0 else TreeLayouts.COUNT / 2
	return slot * TreeLayouts.COUNT + sub


## A seedling (design §AR), unit frame, by its species' young form: a
## tree's thin stem with its first leaves (two seed leaves low, true leaves
## up it; a conifer's whorls of needles), a palm's or cycad's first strap
## leaves from the ground (a fern's small fronds), a cactus' little globe,
## a rosette's first leaves.
static func _build_seedling(sp: PlantSpecies, idx: int, lod: int) -> Array:
	var b := _Builder.new()
	b.hero = lod == LOD_HERO
	b.freq = 1
	b.rng.seed = hash([idx, "seedling"])
	var leaf := sp.color
	var stem := sp.accent.lerp(leaf, 0.45)
	b.wood = stem
	var needles := sp.leaf_type in ["needle", "scale"] or sp.shape == S.CONIFER or sp.shape == S.CYPRESS
	match sp.juvenile:
		"establishment", "sporeling", "rosette":
			# Strap leaves (a palm's undivided first leaves, a cycad's first
			# fronds) or small fronds, straight from the ground.
			var n := 3 if sp.juvenile == "establishment" else 5
			for k in n:
				var a := TAU * (k + b.rng.randf_range(-0.2, 0.2)) / n
				var w := 0.09 if sp.juvenile == "establishment" else 0.16
				b.frond(Vector3.ZERO, Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35), b.rng.randf_range(0.8, 1.0), w, leaf.lightened(0.04 * k), 1.0, 0.1)
		"globe":
			b.blob(Vector3(0, 0.5, 0), Vector3(0.45, 0.5, 0.45), leaf, 0.0)
		"tuft", "shoot":
			for k in 7:
				var a := TAU * k / 7.0 + 0.3
				b.blade(Vector3(cos(a) * 0.03, 0, sin(a) * 0.03), Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3), 0.05, leaf, 1.0)
		_:
			# A tree: the stem, and its first leaves.
			b.tube([[Vector3.ZERO, 0.018, 0.0], [Vector3(0.01, 0.55, 0.0), 0.012, 0.3], [Vector3(0.0, 0.95, 0.01), 0.006, 0.6]], 5, stem)
			if needles:
				# Whorls of needles up the stem, a tuft at the top.
				for tier in 3:
					var y := lerpf(0.35, 0.95, tier / 2.0)
					var reach := lerpf(0.34, 0.16, tier / 2.0)
					for k in 7:
						var a := TAU * (k + 0.5 * tier) / 7.0
						b.blade(Vector3(0, y, 0), Vector3(cos(a) * reach, y + reach * 0.35, sin(a) * reach), 0.025, leaf.darkened(0.05 * tier), lerpf(0.4, 0.8, y))
			else:
				# Two seed leaves low down, then the true leaves up the stem,
				# one side then the other, the top ones smallest.
				var lsz := clampf(sp.leaf_m / 0.7, 0.1, 0.3)
				for k in 2:
					var a := PI * k + 0.4
					var out := Vector3(cos(a), 0.3, sin(a))
					b.card(Vector3(cos(a) * 0.08, 0.28, sin(a) * 0.08), out + Vector3(0, 0.6, 0), 0.08, leaf.lightened(0.12), 0.3)
				var n := 4
				for k in n:
					var y := lerpf(0.45, 0.92, float(k) / (n - 1))
					var a := 2.39996 * k
					var out := Vector3(cos(a), 0.0, sin(a))
					var sz := lsz * lerpf(1.0, 0.7, float(k) / n)
					b.card(Vector3(0, y, 0) + out * sz * 0.8, out + Vector3(0, 0.9, 0), sz, leaf * (0.95 + 0.05 * k), lerpf(0.4, 0.9, y))
	return b.commit_arrays()


## A tree's growth, 0-1 through its stages (spec Phase 6: sprout, sapling,
## mature, old). Until Phase 6 gives plants real ages every generated tree
## is mature or old, read off where its height sits in its species' range
## (`height_m`, before the tier's size scale): 0.55 for the smallest, 1 for
## the tallest.
static func stand_in_growth(sp: PlantSpecies, height_m: float) -> float:
	var t := inverse_lerp(sp.height_m.x, sp.height_m.y, height_m)
	# Old growth (data/stand.json growth_floor): no tree is placed young
	# enough for a thin crown; the young cohort is at least this grown.
	var floor_g := float(Tuning.table("stand").get("growth_floor", 0.55))
	return lerpf(floor_g, 1.0, clampf(t, 0.0, 1.0))


## How much of its leaf clusters a tree shows, 0-1 (the foliage shader
## hides the rest and shrinks what's left): few and small on a sprout, full
## on a mature tree, thinning a little as it grows old; sparser on a dry
## site (moisture 0-1), down to less than half in the driest bands.
static func leaf_amount(growth: float, moisture: float) -> float:
	var g := smoothstep(0.05, 0.5, growth) * (1.0 - 0.2 * smoothstep(0.85, 1.0, growth))
	var dry := lerpf(0.4, 1.0, smoothstep(0.15, 0.6, moisture))
	return clampf(g * dry, 0.0, 1.0)


## A branchy tree's layout (TreeLayouts) at the hero or near level: the
## same skeleton and the same random draws at both, so only the detail
## changes between them and the silhouette doesn't pop.
static func _build_layout(sp: PlantSpecies, idx: int, lod: int, layout: int) -> Array:
	var b := _Builder.new()
	b.hero = lod == LOD_HERO
	b.light = lod == LOD_LIGHT
	b.freq = CROWN_FREQ[lod]
	b.wood = sp.accent
	b.rng.seed = hash([idx, layout, 7919])
	# Vines as the old crowns had them: beard lichen on cypress, lianas on
	# the rest.
	var vine_col := Color(0.5, 0.55, 0.42) if sp.shape == S.CYPRESS else sp.color.darkened(0.3)
	b.skeleton(TreeLayouts.skeleton(idx, layout), sp.color, vine_col, sp.leaf_density_of())
	return b.commit_arrays()


## A species' far level as a picture (IMPOSTORS): one quad as wide as the
## far model's crown and as tall as the tree, carrying its outline for the
## foliage shader to cut: CUSTOM0 the crown's half-width at four heights up
## the crown (shares of the widest), UV2 (6, crown base + 10 x the trunk's
## half-width in hundredths of the crown's), COLOR its mean leaf colour
## (sway 0: the far trees stand still). Unit frame like every plant mesh.
static func _build_impostor(sp: PlantSpecies, idx: int) -> Array:
	var model := _build(sp, idx, LOD_FAR)
	var v: PackedVector3Array = model[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = model[Mesh.ARRAY_COLOR]
	var m: PackedVector2Array = model[Mesh.ARRAY_TEX_UV2]
	var top := 0.05
	var base := 1.0
	var leaves := 0
	var leaf_col := Color(0, 0, 0)
	for i in v.size():
		top = maxf(top, v[i].y)
		if m[i].x > 0.5 and v[i].y > 0.02:
			base = minf(base, v[i].y)
			leaves += 1
			leaf_col += c[i]
	if leaves < 12:
		# Leafless (a cactus, a snag): the whole plant is the "crown", in
		# its own colour.
		base = 0.0
		leaves = 0
		leaf_col = Color(0, 0, 0)
		for i in v.size():
			leaf_col += c[i]
			leaves += 1
	leaf_col /= float(maxi(leaves, 1))
	base = clampf(base, 0.0, top * 0.9)
	var bins := [0.0, 0.0, 0.0, 0.0]
	var trunk := 0.0
	for i in v.size():
		var r := Vector2(v[i].x, v[i].z).length()
		var crown := m[i].x > 0.5 or base == 0.0
		if crown:
			var t := clampf((v[i].y - base) / maxf(top - base, 1e-3), 0.0, 0.999)
			var b := int(t * 4.0)
			bins[b] = maxf(bins[b], r)
		elif v[i].y < base and v[i].y > 0.05:
			trunk = maxf(trunk, r)
	var half := maxf(maxf(bins[0], bins[1]), maxf(bins[2], bins[3]))
	half = maxf(half, 0.02)
	var tw := clampf(trunk / half, 0.0, 0.99)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var qv := PackedVector3Array()
	var qn := PackedVector3Array()
	var qc := PackedColorArray()
	var quv := PackedVector2Array()
	var quv2 := PackedVector2Array()
	var qcu := PackedFloat32Array()
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in corners:
		var q: Vector2 = k
		qv.append(Vector3((q.x - 0.5) * 2.0 * half * 1.08, q.y * top, 0.0))
		qn.append(Vector3(0, 0, 1))
		qc.append(Color(leaf_col.r, leaf_col.g, leaf_col.b, 0.0))
		quv.append(q)
		quv2.append(Vector2(6.0, base / top + 10.0 * roundf(tw * 100.0)))
		for b in 4:
			qcu.append(bins[b] / half)
	arrays[Mesh.ARRAY_VERTEX] = qv
	arrays[Mesh.ARRAY_NORMAL] = qn
	arrays[Mesh.ARRAY_COLOR] = qc
	arrays[Mesh.ARRAY_TEX_UV] = quv
	arrays[Mesh.ARRAY_TEX_UV2] = quv2
	arrays[Mesh.ARRAY_CUSTOM0] = qcu
	return arrays


static func _aroid_leaf(b: _Builder, leaf: Color, wood: Color, far: bool) -> void:
	# The petiole, then a small tree (from play: "build it like a small
	# tree"): three arms forking twice more into twigs, each twig tip
	# carrying a clump of crossed leaf cards (the way a tree's leaf
	# clusters go) and leaflets hanging below, so it reads as layered
	# foliage with the arms showing through, not a solid plate.
	b.cylinder(Vector3.ZERO, 0.032, 0.6, 5 if far else 8, wood, 0.0, 0.0)
	var top := Vector3(0, 0.6, 0)
	var tips: Array = []
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var d := Vector3(cos(a), 0.5, sin(a)).normalized()
		var end := top + d * 0.26
		b.strut(top, end, 0.014, wood)
		tips.append([end, d, 0.2])
		for f in [-0.8, 0.0, 0.8]:
			var d2 := (d.rotated(Vector3.UP, f) + Vector3(0, -0.15, 0)).normalized()
			var end2 := end + d2 * 0.22
			b.strut(end, end2, 0.008, wood)
			tips.append([end2, d2, 0.22])
			if far:
				continue
			tips.append([end + d2 * 0.11, d2, 0.17])
			for f2 in [-0.6, 0.6]:
				var d3 := (d2.rotated(Vector3.UP, f2) + Vector3(0, -0.25, 0)).normalized()
				var end3 := end2 + d3 * 0.15
				b.strut(end2, end3, 0.005, wood)
				tips.append([end3, d3, 0.18])
	# A clump of leaf cards at every twig tip, plus one at each fork.
	var key := 0.0
	for t in tips:
		var p: Vector3 = t[0]
		var d: Vector3 = t[1]
		var r: float = t[2]
		var side := d.cross(Vector3.UP).normalized()
		b.frond_card(p + Vector3.UP * r * 0.15, d, side, r, leaf, 0.9, key)
		b.frond_card(p + d * r * 0.3, (d + Vector3.UP * 0.9).normalized(), side, r * 0.9, leaf.lightened(0.06), 0.9, key)
		b.frond_card(p, side, (d + Vector3.UP * 0.6).normalized(), r * 0.85, leaf.darkened(0.05), 0.9, key)
		key = fmod(key + 0.37, 1.0)
		if not far:
			var out := Vector3(p.x, 0, p.z).normalized()
			for sgn in [-1.0, 1.0]:
				var sd: Vector3 = out.cross(Vector3.UP) * float(sgn)
				b.frond(p, (out * 0.6 + sd * 0.5 + Vector3.DOWN * 0.6).normalized(), 0.18, 0.05, leaf, 0.9, 0.4)


static func _build(sp: PlantSpecies, idx: int, lod: int) -> Array:
	var b := _Builder.new()
	b.far = lod == LOD_FAR
	b.hero = lod == LOD_HERO
	b.freq = CROWN_FREQ[lod]
	if TreeArch.grows(sp):
		# A tree grown from its architecture: far off, its first layout's
		# order 1-2 wood and fewer, bigger cards (never a cone or a ball).
		b.wood = sp.accent
		b.rng.seed = hash([idx, 0, 7919])
		b.arch_tree(TreeLayouts.skeleton(idx, 0), sp.color)
		return b.commit_arrays()
	var far := b.far
	var leaf := sp.color
	var wood := sp.accent
	b.wood = wood
	b.rng.seed = idx * 7919 + 11
	if sp.shape == S.CACTUS:
		b.wood = leaf # ribbed: the bark streaks read as cactus ribs
	if sp.shape == S.UMBRELLA and not TreeArch.grows(sp):
		# The "umbrella until the aroid shape exists" placeholder of the
		# giant herbs (Alocasia, Colocasia, the taros): leaf cards on
		# stalks, never the umbrella tree's crown (design 1 Oct §CA).
		b.herb_leaves(3 if far else b.rng.randi_range(3, 6), 0.62, 0.24, 0.3, 0.22, leaf, wood, 0.8)
		return b.commit_arrays()
	if not sp.aroid.is_empty():
		# An Amorphophallus leaf (from reference photos of the titan arum):
		# one mottled petiole, a tree in itself, forking at its top into
		# three rachises that fork again, each hung with leaflets, a canopy
		# as wide as the plant is tall. (Was the umbrella tree stand-in.)
		_aroid_leaf(b, leaf, wood, far)
		return b.commit_arrays()
	match sp.shape:
		S.CONIFER:
			b.trunk(0.04, 0.3, 0.0, 0.0)
			# Three tiers of cluster cards where the cones were (§CA).
			b.cluster_shell(Vector3(0, 0.3, 0), Vector3(0.26, 0.2, 0.26), leaf.darkened(0.1), 0.4)
			b.cluster_shell(Vector3(0, 0.55, 0), Vector3(0.2, 0.18, 0.2), leaf, 0.65)
			b.cluster_shell(Vector3(0, 0.78, 0), Vector3(0.12, 0.16, 0.12), leaf.lightened(0.08), 0.9)
			# Old-man's-beard lichen in wet conifer forest.
			b.vines(5, Color(0.55, 0.6, 0.45))
		S.BROADLEAF:
			b.trunk(0.05, 0.62, 0.04, 0.3)
			b.branches(2, 0.36, 0.2, 0.62, 0.3)
			b.crown(Vector3(0, 0.7, 0), Vector3(0.36, 0.3, 0.36), 5, leaf, 0.8)
			b.vines(5, leaf.darkened(0.3))
		S.GNARLED:
			b.trunk(0.075, 0.42, 0.12, 0.2)
			b.branches(3, 0.3, 0.26, 0.5, 0.25)
			b.crown(Vector3(0.08, 0.66, 0), Vector3(0.42, 0.2, 0.34), 5, leaf, 0.8)
			b.vines(6, leaf.darkened(0.3))
		S.EMERGENT:
			b.trunk(0.03, 0.9, 0.03, 0.5)
			b.branches(2, 0.75, 0.16, 0.9, 0.5)
			b.crown(Vector3(0, 0.91, 0), Vector3(0.26, 0.1, 0.26), 3, leaf, 1.0)
			b.vines(4, leaf.darkened(0.3))
		S.UMBRELLA:
			b.trunk(0.045, 0.7, 0.06, 0.3)
			b.branches(3, 0.55, 0.3, 0.8, 0.3)
			b.crown(Vector3(0.04, 0.82, 0), Vector3(0.6, 0.1, 0.55), 5, leaf, 1.0)
			b.vines(5, leaf.darkened(0.3))
		S.PALM when sp.genus in ["Musa", "Ensete"]:
			# A banana: a soft pseudostem and five or six paddle cards
			# (design §CA), not palm fronds.
			b.cylinder(Vector3.ZERO, 0.05, 0.55, 6, wood, 0.0, 0.0)
			b.herb_leaves(4 if far else 6, 0.55, 0.11, 0.32, 0.12, leaf, wood, 0.9)
		S.PALM:
			# The stem holds still (it can be climbed); the fronds sway from
			# where they leave it.
			b.cylinder(Vector3.ZERO, 0.03, 0.92, 5, wood, 0.0, 0.0, Vector3(0.08, 1, 0).normalized())
			for k in 7:
				var a := TAU * k / 7.0
				b.frond(Vector3(0.07, 0.92, 0), Vector3(cos(a), -0.35, sin(a)), 0.45, 0.07, leaf, 1.0, 0.0)
		S.CYPRESS:
			b.cone(Vector3.ZERO, 0.12, 0.25, 8, wood, 0.0, 0.0)
			b.trunk(0.045, 0.62, 0.0, 0.4)
			b.crown(Vector3(0, 0.72, 0), Vector3(0.17, 0.3, 0.17), 3, leaf, 0.9)
			b.vines(4, Color(0.5, 0.55, 0.42))
		S.MANGROVE:
			for k in 5:
				var a := TAU * k / 5.0
				b.strut(Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), Vector3(0, 0.3, 0), 0.02, wood)
			b.cylinder(Vector3(0, 0.28, 0), 0.04, 0.4, 8, wood, 0.0, 0.0)
			b.crown(Vector3(0, 0.75, 0), Vector3(0.4, 0.22, 0.4), 3, leaf, 0.9)
			b.vines(5, leaf.darkened(0.3))
		S.ROSETTE:
			b.cylinder(Vector3.ZERO, 0.07, 0.75, 6, wood, 0.0, 0.3)
			for k in 10:
				var a := TAU * k / 10.0
				b.frond(Vector3(0, 0.78, 0), Vector3(cos(a), 0.7, sin(a)), 0.25, 0.06, leaf, 1.0)
		S.SPIKE_ROSETTE:
			b.blob(Vector3(0, 0.12, 0), Vector3(0.22, 0.13, 0.22), leaf, 0.1)
			b.cone(Vector3(0, 0.2, 0), 0.07, 0.8, 6, wood, 0.2, 0.6)
		S.SHRUB:
			b.crown(Vector3(0, 0.45, 0), Vector3(0.5, 0.45, 0.5), 2, leaf, 0.6)
		S.TUSSOCK:
			for k in 9:
				var a := TAU * k / 9.0
				b.blade(Vector3.ZERO, Vector3(cos(a) * 0.45, 1, sin(a) * 0.45), 0.07, leaf, 1.0)
		S.GRASS:
			for k in 5:
				var a := TAU * k / 5.0 + 0.4
				b.blade(Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), Vector3(cos(a) * 0.25, 1, sin(a) * 0.25), 0.06, leaf, 1.0)
			if wood.s > 0.3 and wood.v > 0.6:
				b.blob(Vector3(0.1, 0.95, 0), Vector3(0.08, 0.08, 0.08), wood, 1.0)
				b.blob(Vector3(-0.12, 0.85, 0.08), Vector3(0.07, 0.07, 0.07), wood, 1.0)
		S.REED:
			for k in 6:
				var a := TAU * k / 6.0
				b.blade(Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), Vector3(cos(a) * 0.12, 1, sin(a) * 0.12), 0.03, leaf, 1.0)
			b.cylinder(Vector3(0, 0.72, 0), 0.025, 0.15, 5, wood, 0.9, 1.0)
		S.FERN:
			for k in 7:
				var a := TAU * k / 7.0
				b.frond(Vector3.ZERO, Vector3(cos(a), 1.1, sin(a)), 0.9, 0.2, leaf, 1.0)
			if wood.r > 0.8:
				b.blob(Vector3(0, 0.6, 0), Vector3(0.1, 0.1, 0.1), wood, 1.0)
		S.TREE_FERN:
			b.cylinder(Vector3.ZERO, 0.05, 0.75, 6, wood, 0.0, 0.5)
			for k in 8:
				var a := TAU * k / 8.0
				b.frond(Vector3(0, 0.75, 0), Vector3(cos(a), 0.25, sin(a)), 0.4, 0.09, leaf, 1.0)
		S.CACTUS:
			b.cylinder(Vector3.ZERO, 0.07, 1.0, 7, leaf, 0.0, 0.05)
			b.cylinder(Vector3(0.06, 0.4, 0), 0.04, 0.2, 6, leaf, 0.02, 0.05, Vector3(1, 0.15, 0).normalized())
			b.cylinder(Vector3(0.24, 0.43, 0), 0.04, 0.3, 6, leaf, 0.05, 0.08)
			b.cylinder(Vector3(-0.06, 0.55, 0), 0.035, 0.15, 6, leaf, 0.02, 0.05, Vector3(-1, 0.2, 0).normalized())
			b.cylinder(Vector3(-0.2, 0.58, 0), 0.035, 0.22, 6, leaf, 0.05, 0.08)
		S.CUSHION:
			b.blob(Vector3(0, 0.45, 0), Vector3(1.5, 0.55, 1.5), leaf, 0.2)
			if wood.v > 0.8:
				b.blob(Vector3(0.5, 0.9, 0.3), Vector3(0.25, 0.2, 0.25), leaf.lightened(0.2), 0.3)
		S.MOSS:
			b.disc(Vector3(0, 0.2, 0), 6.0, 0.8, 7, leaf, 0.0)
		S.HANGING_MOSS:
			for k in 5:
				var a := TAU * k / 5.0
				b.strand(Vector3(cos(a) * 0.12, 0, sin(a) * 0.12), 1.0 - 0.15 * (k % 3), 0.07, leaf)
		S.EPIPHYTE_CLUMP:
			for k in 6:
				var a := TAU * k / 6.0
				b.frond(Vector3.ZERO, Vector3(cos(a), 0.9, sin(a)), 0.7, 0.2, wood, 0.8)
			b.blob(Vector3(0, 0.55, 0), Vector3(0.22, 0.22, 0.22), leaf, 1.0)
		S.LIANA:
			for k in 3:
				b.strand(Vector3((k - 1) * 0.02, 0, 0), 1.0 - 0.2 * k, 0.012, leaf)
		S.KNEES:
			b.cone(Vector3.ZERO, 0.25, 1.0, 5, leaf, 0.0, 0.0)
		S.THERMOPHILE_MAT:
			b.disc(Vector3(0, 0.3, 0), 40.0, 0.6, 9, leaf, 0.0)
			b.disc(Vector3(0, 0.7, 0), 22.0, 0.6, 9, wood, 0.0)
		S.BAMBOO:
			b.bamboo(wood, leaf)
		_:
			b.blob(Vector3(0, 0.5, 0), Vector3(0.4, 0.5, 0.4), leaf, 0.8)
	return b.commit_arrays()


class _Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array() # card texture coordinates
	var uv2 := PackedVector2Array() # x: material (0 bark, 1 leaves, 2 card, 3 vine, 4 culm, 5 cluster card; 6 far picture, _build_impostor)
	## CUSTOM0, 4 floats a vertex: a cluster card's cluster center and key.
	var cu := PackedFloat32Array()
	var wood := Color.BLACK # this species' wood color: cylinders/cones in it are bark
	var mat := 1.0
	var rng := RandomNumberGenerator.new()
	## Smoothing group of each vertex: normals are averaged over vertices
	## at the same spot in the same part; -1 keeps the vertex's own normal.
	var parts := PackedInt32Array()
	var part := 0
	var far := false
	var hero := false
	## The light level (LOD_LIGHT): trunk, main limbs, a few big clusters.
	var light := false
	var freq := 2 # crown lobe detail (PlantMeshes.geosphere())
	## Vine strands: UV2.y holds each strand's 0-1 key; the foliage shader
	## shows the strands whose key is under the plant's vine amount.
	var strand_key := 0.0
	## A branchy tree's twig sway phase (0-1, per twig; -1 none): its wood
	## carries it in CUSTOM0.w, its leaf clusters in UV2.y, so a cluster
	## sways with the twig that holds it (§AJ 5, §AL 5).
	var twig_phase := -1.0
	## Where vines can hang from: [center, radii] per crown lobe or cone.
	var hang_from: Array = []

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, sa: float, sb: float, sd: float) -> void:
		tri3(a, b, d, col, col, col, sa, sb, sd)

	func tri3(a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color, sa: float, sb: float, sd: float) -> void:
		var nrm := (b - a).cross(d - a).normalized()
		v.append_array([a, b, d])
		n.append_array([nrm, nrm, nrm])
		c.append_array([Color(ca, sa), Color(cb, sb), Color(cd, sd)])
		uv.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		var m := Vector2(mat, strand_key)
		uv2.append_array([m, m, m])
		parts.append_array([part, part, part])
		var w := twig_phase if mat < 0.5 else -1.0
		cu.append_array([0.0, 0.0, 0.0, w, 0.0, 0.0, 0.0, w, 0.0, 0.0, 0.0, w])

	## One leaf as a card (design §CA, no blobs): a cluster card standing on
	## a stalk's `tip`, its tile upright along `up` (the leaf's base at the
	## tip, its point `2 * h` up), facing `normal`, half `w` wide; the
	## shader draws the species' leaf cutout at the leaf's size, back-lit.
	func leaf_card(tip: Vector3, up: Vector3, normal: Vector3, w: float, h: float, col: Color, sway: float, key: float) -> void:
		var u := up.normalized()
		var side := u.cross(normal)
		if side.length() < 1e-4:
			side = u.cross(Vector3.RIGHT)
		side = side.normalized()
		var nrm := side.cross(u).normalized()
		var center := tip + u * h
		var a1 := side * w
		var a2 := u * h
		var p := [center - a1 - a2, center + a1 - a2, center + a1 + a2, center - a1 + a2]
		var q := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [[0, 1, 2], [0, 2, 3]]:
			for jj in idx:
				v.append(p[jj])
				n.append(nrm)
				c.append(Color(col, sway))
				uv.append(q[jj])
				uv2.append(Vector2(5.0, twig_phase))
				parts.append(-1)
				cu.append_array([center.x, center.y, center.z, key])

	## A giant herb (design §CA: an Alocasia is two to six big heart cards
	## on stalks, a banana its paddles): `count` petioles from the crown of
	## the plant, a thin drawn stem each, one upright leaf card at the tip,
	## leaning out and a little down; no hull.
	func herb_leaves(count: int, stem_h: float, w: float, h: float, lean: float, leaf: Color, stem: Color, sway: float) -> void:
		for k in count:
			var a := TAU * k / count + rng.randf_range(-0.35, 0.35)
			var out := Vector3(cos(a), 0.0, sin(a))
			var tip := out * lean + Vector3(0, stem_h * rng.randf_range(0.75, 1.0), 0)
			strut(Vector3(0, 0.02, 0), tip, 0.014, stem)
			var up := (Vector3.UP + out * rng.randf_range(0.3, 0.7)).normalized()
			var nrm := (out - up * out.dot(up)).normalized()
			leaf_card(tip, up, nrm, w, h, leaf.lightened(rng.randf_range(-0.04, 0.06)), sway, 0.05 + 0.1 * k)

	## A leaf-cluster card (alpha cutout), square with half-size `s`, facing
	## `facing`, spun randomly.
	func card(center: Vector3, facing: Vector3, s: float, col: Color, sway: float) -> void:
		var f := facing.normalized()
		var t1 := f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := f.cross(t1)
		var spin := rng.randf() * TAU
		var a1 := (t1 * cos(spin) + t2 * sin(spin)) * s
		var a2 := (-t1 * sin(spin) + t2 * cos(spin)) * s
		var p := [center - a1 - a2, center + a1 - a2, center + a1 + a2, center - a1 + a2]
		var q := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var nrm := f
		for idx in [[0, 1, 2], [0, 2, 3]]:
			for k in idx:
				v.append(p[k])
				n.append(nrm)
				c.append(Color(col, sway))
				uv.append(q[k])
				uv2.append(Vector2(2.0, 0.0))
				parts.append(-1)
				# Its middle, so the shader can size it (shade leaves are
				# bigger: PlantGrowth.leaf_scale).
				cu.append_array([center.x, center.y, center.z, -1.0])

	## Round parts get half as many sides again right around the player:
	## smooth silhouettes up close, light meshes farther off.
	func sides(n: int) -> int:
		return int(ceil(n * 1.5)) if hero else n

	func cylinder(base: Vector3, r: float, h: float, sides_n: int, col: Color, s0: float, s1: float, axis := Vector3.UP) -> void:
		var sides := sides(sides_n)
		var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var side2 := axis.cross(side).normalized()
		var top := base + axis * h
		mat = 0.0 if col.is_equal_approx(wood) else 1.0
		part += 1
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var o0 := (side * cos(a0) + side2 * sin(a0)) * r
			var o1 := (side * cos(a1) + side2 * sin(a1)) * r
			tri(base + o0, top + o1, base + o1, col, s0, s1, s0)
			tri(base + o0, top + o0, top + o1, col, s0, s1, s1)
		mat = 1.0

	func cone(base: Vector3, r: float, h: float, sides_n: int, col: Color, s0: float, s1: float) -> void:
		var sides := sides(sides_n) if sides_n < 12 else sides_n
		var tip := base + Vector3(0, h, 0)
		var is_wood := col.is_equal_approx(wood)
		mat = 0.0 if is_wood else 1.0
		part += 1
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p0 := base + Vector3(cos(a0), 0, sin(a0)) * r
			var p1 := base + Vector3(cos(a1), 0, sin(a1)) * r
			tri(p0, tip, p1, col, s0, s1, s0)
		# The underside is its own flat part (a hard edge at the skirt).
		part += 1
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			tri(base + Vector3(cos(a1), 0, sin(a1)) * r, base, base + Vector3(cos(a0), 0, sin(a0)) * r, col.darkened(0.25), s0, s0, s0)
		mat = 1.0
		if not is_wood:
			hang_from.append([base + Vector3(0, h * 0.2, 0), Vector3(r, h * 0.2, r)])
		# Foliage cones get ragged leaf cards around their skirt.
		if not is_wood and r > 0.1 and not far:
			for k in 4:
				var a := TAU * (k + rng.randf()) / 4.0
				var out := Vector3(cos(a), 0.0, sin(a))
				var y := rng.randf_range(0.1, 0.5) * h
				var rr := r * (1.0 - y / h)
				card(base + out * rr * 0.95 + Vector3(0, y, 0), out + Vector3(0, 0.6, 0), r * 0.42, col, lerpf(s0, s1, y / h))

	## A smooth ellipsoid: an icosphere, subdivided like crown lobes (just
	## an icosahedron when it's small: seed heads, buds).
	## A rounded mass of leaves: never a sphere (design 1 Oct §CA, no blobs
	## on any plant): a small one is a single cutout card, a bigger one a
	## shell of leaf-cluster cards with air between them.
	func blob(center: Vector3, radii: Vector3, col: Color, sway: float) -> void:
		part += 1
		var mean_r := (radii.x + radii.y + radii.z) / 3.0
		if mean_r < 0.12:
			card(center, Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)), mean_r, col, sway)
			return
		cluster_shell(center, radii, col, sway)

	var trunk_top := Vector3.ZERO
	var trunk_h := 0.5
	var trunk_bend := 0.0

	## Trunk: 12-sided right around the player (8 in the rest of the detail
	## ring, 5 beyond), tapering to `top_frac` of the base radius, bending
	## sideways by `bend` at the top, with a flared foot (rounded in more
	## rings up close). Sways from 0 at the ground to `s1` at the top.
	func trunk(r: float, h: float, bend: float, s1: float, top_frac := 0.45) -> void:
		var rings := [[0.0, 1.7], [0.05, 1.15], [0.45, 1.0], [1.0, 1.0]]
		if hero:
			rings = [[0.0, 1.75], [0.03, 1.3], [0.08, 1.08], [0.25, 1.0], [0.5, 1.0], [0.75, 1.0], [1.0, 1.0]]
		elif far:
			rings = [[0.0, 1.5], [0.4, 1.0], [1.0, 1.0]]
		var pts: Array = []
		for ring in rings:
			var t: float = ring[0]
			var rr := r * lerpf(1.0, top_frac, t) * float(ring[1])
			var off := Vector3(bend * t * t, 0, bend * 0.3 * t * t)
			pts.append([Vector3(0, t * h, 0) + off, rr, lerpf(0.0, s1, t)])
		tube(pts, 5 if far else (12 if hero else 8), wood)
		trunk_top = pts[pts.size() - 1][0]
		trunk_h = h
		trunk_bend = bend

	## `count` branches leaving the trunk between heights y0 and y1, angled
	## up and out, ending inside the crown.
	func branches(count: int, y0: float, reach: float, y1: float, sway: float) -> void:
		if far:
			return
		for k in count:
			var a := TAU * (k + rng.randf_range(0.0, 0.5)) / count
			var y := lerpf(y0, minf(y1, trunk_h * 0.9), rng.randf())
			var tt := y / trunk_h
			var start := Vector3(trunk_bend * tt * tt, y, trunk_bend * 0.3 * tt * tt)
			var out := Vector3(cos(a), 0.0, sin(a))
			var end := start + out * reach + Vector3(0, reach * rng.randf_range(0.7, 1.1), 0)
			if hero:
				var mid := start.lerp(end, 0.5) + Vector3(0, reach * 0.08, 0)
				tube([[start, 0.022, sway * 0.6], [mid, 0.016, sway * 0.8], [end, 0.01, sway]], 8, wood)
			else:
				tube([[start, 0.022, sway * 0.6], [end, 0.01, sway]], 5, wood)

	## A tube along a polyline: `pts` = [[center, radius, sway], ...].
	func tube(pts: Array, sides: int, col: Color) -> void:
		mat = 0.0 if col.is_equal_approx(wood) else 1.0
		part += 1
		var rings: Array = []
		for i in pts.size():
			var p: Vector3 = pts[i][0]
			var next_p: Vector3 = pts[mini(i + 1, pts.size() - 1)][0]
			var prev_p: Vector3 = pts[maxi(i - 1, 0)][0]
			var axis := (next_p - prev_p).normalized()
			var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
			var side2 := axis.cross(side).normalized()
			var ring: Array = []
			for k in sides:
				var a := TAU * k / sides
				ring.append(p + (side * cos(a) + side2 * sin(a)) * float(pts[i][1]))
			rings.append(ring)
		for i in pts.size() - 1:
			var s0: float = pts[i][2]
			var s1: float = pts[i + 1][2]
			for k in sides:
				var k1 := (k + 1) % sides
				tri(rings[i][k], rings[i + 1][k1], rings[i][k1], col, s0, s1, s0)
				tri(rings[i][k], rings[i + 1][k], rings[i + 1][k1], col, s0, s1, s1)
		mat = 1.0

	## A branchy tree from its layout's skeleton (TreeLayouts): the trunk
	## (flared foot, capped top), the limbs (capped ends) and the branches
	## as smooth bark tubes that don't sway, and leaf clusters along the
	## outer third of the limbs and branches (leaf_clusters()), that do.
	## Near the player every ring of the skeleton is drawn; farther, every
	## other one, so the main limbs keep their silhouette.
	func skeleton(sk: TreeLayouts.Skeleton, col: Color, vine_col: Color, density: float) -> void:
		if sk.arch:
			arch_tree(sk, col)
			if not light:
				vines(sk.vines, vine_col)
			return
		if sk.buttress != Vector2.ZERO:
			cone(Vector3.ZERO, sk.buttress.x, sk.buttress.y, 6 if light else 8, wood, 0.0, 0.0)
		for pc in sk.pieces:
			if light and pc.kind == TreeLayouts.Kind.BRANCH:
				continue
			var n := pc.pts.size()
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			for i in n:
				if hero or i % 2 == 0 or i == n - 1:
					pts.append(pc.pts[i])
					rad.append(pc.rad[i])
			var ring := 0
			match pc.kind:
				TreeLayouts.Kind.TRUNK:
					ring = 12 if hero else (5 if light else 8)
				TreeLayouts.Kind.LIMB:
					ring = 9 if hero else (4 if light else 6)
				_:
					ring = 6 if hero else 5
			if light and pts.size() > 3:
				pts = PackedVector3Array([pts[0], pts[pts.size() / 2], pts[pts.size() - 1]])
				rad = PackedFloat32Array([rad[0], rad[rad.size() / 2], rad[rad.size() - 1]])
			wood_tube(pts, rad, ring, pc.kind != TreeLayouts.Kind.BRANCH)
		leaf_clusters(sk, col, density)
		if not light:
			vines(sk.vines, vine_col)

	## A tree grown from its architecture (TreeArch, design §AK/§AJ/§AL):
	## its wood order by order, every piece a bark tube (the trunk and
	## stems round, the limbs a little less, branches coarse, twigs a thin
	## three-sided prism never thinner than TWIG_MIN_R so they read as dark
	## 1-2 px lines through the gaps), dead wood marked for the shader's
	## grey (UV2.y 1), buttress fins at the foot; and its leaf clusters, a
	## few crossed cutout cards each, hung only at its anchors (every one on
	## a drawn twig), never a hull. Far off (`far`): the order 1-2 lines and
	## fewer, bigger cards (every third anchor, 1.9x) with the same holes.
	## The trunk, limbs and branches hold still (handholds); a twig sways
	## from nothing at its foot to TWIG_SWAY at its tip and its clusters
	## sway with it, so the leaves stay on the wood in the wind. A palm's
	## leaflets lie flat along its fronds.
	const TWIG_MIN_R := 0.0018
	const TWIG_SWAY := 0.45

	func arch_tree(sk: TreeLayouts.Skeleton, col: Color) -> void:
		for f in sk.fins:
			fin(f[0], f[1], f[2])
		# The light level: the trunk and at most LIGHT_LIMBS main limbs.
		var limb_step := 1
		if light:
			var limbs := 0
			for pc in sk.pieces:
				if pc.order == 1 and not pc.frond:
					limbs += 1
			limb_step = maxi(1, ceili(float(limbs) / LIGHT_LIMBS))
		var limb_i := 0
		for pc in sk.pieces:
			var order := pc.order
			if far and order >= 3 and not pc.frond:
				continue
			if light and (order >= 2 or pc.frond):
				continue
			if light and order == 1:
				limb_i += 1
				if (limb_i - 1) % limb_step != 0:
					continue
			var n := pc.pts.size()
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			var sw := PackedFloat32Array()
			for i in n:
				if hero or i % 2 == 0 or i == n - 1:
					if (far or light) and order >= 1 and i != 0 and i != n - 1 and i != n / 2:
						continue
					pts.append(pc.pts[i])
					var r := pc.rad[i]
					if order >= 2 or pc.frond:
						r = maxf(r, TWIG_MIN_R * (1.4 if far else 1.0))
					rad.append(r)
					var t := float(i) / maxf(n - 1, 1)
					sw.append(t * TWIG_SWAY if (order >= 3 or pc.frond) else 0.0)
			var ring := 3
			match order:
				0:
					ring = 12 if hero else (5 if light else (8 if not far else 6))
				1:
					ring = 8 if hero else (3 if light else (6 if not far else 4))
				2:
					ring = 5 if hero else (4 if not far else 3)
			if pc.frond:
				ring = 3
			strand_key = 1.0 if pc.dead else 0.0
			twig_phase = _twig_phase(sk, pc) if (order >= 3 or pc.frond) else -1.0
			wood_tube(pts, rad, ring, order > 0, sw)
			strand_key = 0.0
			twig_phase = -1.0
		# The leaf clusters at the anchors.
		var list: Array = sk.anchors
		if far or light:
			# Every k-th anchor, its cluster grown to cover the ones it
			# stands for (area: k times, so sqrt(k) across).
			var k := 3 if far else maxi(2, ceili(float(sk.anchors.size()) / LIGHT_CLUSTERS))
			var grow := 1.9 if far else sqrt(float(k)) * 0.95
			list = []
			for i in range(0, sk.anchors.size(), k):
				var a2: Array = (sk.anchors[i] as Array).duplicate()
				a2[5] = float(a2[5]) * grow
				list.append(a2)
		var order_keys: Array[int] = []
		for i in list.size():
			order_keys.append(i)
		for i in range(order_keys.size() - 1, 0, -1):
			var jj := rng.randi_range(0, i)
			var t := order_keys[i]
			order_keys[i] = order_keys[jj]
			order_keys[jj] = t
		for rank in order_keys.size():
			var an: Array = list[order_keys[rank]]
			var key := (rank + 0.5) / list.size()
			var p: Vector3 = an[0]
			var tan: Vector3 = an[1]
			var hang: Vector3 = an[2]
			var r: float = an[5]
			var pc: TreeLayouts.Piece = sk.pieces[an[3]]
			var tone := col
			match rank % 3:
				1:
					tone = col.lightened(0.08)
				2:
					tone = col.darkened(0.08)
			twig_phase = _twig_phase(sk, pc)
			if pc.frond:
				frond_card(p + hang * r * 0.55, tan, hang, r, tone, TWIG_SWAY, key)
			else:
				# The card's middle a little out from the twig, so the twig
				# runs into it: its anchor on the wood.
				cluster(p + hang * r * 0.45, r, 0.8, tone, TWIG_SWAY, key)
			twig_phase = -1.0
			hang_from.append([p, Vector3(r, r, r)])

	## A twig's sway phase: from where it leaves its parent, so the twig and
	## every cluster on it share it.
	func _twig_phase(sk: TreeLayouts.Skeleton, pc: TreeLayouts.Piece) -> float:
		var p := pc.pts[0]
		return fposmod(p.x * 41.3 + p.y * 17.9 + p.z * 29.1, 1.0)

	## A buttress fin: a flat plank of bark from the trunk out along `dir`,
	## `height` up the trunk, `reach` out at the ground.
	func fin(dir: Vector3, height: float, reach: float) -> void:
		mat = 0.0
		part += 1
		var side := dir.cross(Vector3.UP).normalized() * reach * 0.08
		var a := Vector3(0, height, 0)
		var b := dir * reach
		var o := Vector3.ZERO
		for sgn in [1.0, -1.0]:
			var off: Vector3 = side * sgn
			tri(o + off, a + off, b + off, wood, 0.0, 0.0, 0.0)
		tri(b + side, a + side, a - side, wood, 0.0, 0.0, 0.0)
		tri(b + side, a - side, b - side, wood, 0.0, 0.0, 0.0)
		mat = 1.0

	## A palm's leaflet card: flat along the frond, hanging to one side.
	func frond_card(center: Vector3, along: Vector3, side: Vector3, r: float, col: Color, sway: float, key: float) -> void:
		var a1 := along.normalized() * r
		var a2 := side.normalized() * r
		var nrm := a1.cross(a2).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		var p := [center - a1 - a2, center + a1 - a2, center + a1 + a2, center - a1 + a2]
		var q := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
		for idx in [[0, 1, 2], [0, 2, 3]]:
			for jj in idx:
				v.append(p[jj])
				n.append(nrm)
				c.append(Color(col, sway))
				uv.append(q[jj])
				uv2.append(Vector2(5.0, twig_phase))
				parts.append(-1)
				cu.append_array([center.x, center.y, center.z, key])

	## Leaf clusters on the outer third of every limb and branch: each a few
	## crossed alpha-cutout cards (the leaf-card texture's ragged cluster of
	## leaves; no per-leaf geometry), sitting on and a little above the wood,
	## one side then the other like leaves along a twig, so the limb shows
	## beneath them; at each branch tip a leafy species also fans out a
	## twig or two, each ending in a cluster. Open air between clusters: none
	## closer to another than the gap, wider on a sparse species. So from
	## below the crown reads as limbs, twigs, leaves and sky, not a solid
	## ball. A column crown (cypress) also gets them up the top of its
	## leader. `density` (the species' leaf_density, 0-1) sets their size,
	## how closely they follow along the wood, the gap and the twigs. Each
	## cluster gets a 0-1 key, shuffled, so the shader can thin a tree
	## evenly by hiding the clusters whose key is above its leaf amount.
	func leaf_clusters(sk: TreeLayouts.Skeleton, col: Color, density: float) -> void:
		var d := clampf(density, 0.05, 1.0)
		var cr: Vector3 = sk.clump_r
		var r := cr.x * lerpf(0.46, 0.6, d)
		# Plate crowns (umbrella, emergent) grow flat clusters.
		var flat := clampf(cr.y / cr.x * 1.4, 0.45, 1.0)
		var step := r * lerpf(2.8, 1.25, d)
		var gap := r * lerpf(2.6, 1.8, d)
		var twigs := int(d * 2.5)
		var column := sk.buttress != Vector2.ZERO
		var centers: Array[Vector3] = []
		var fits := func(at: Vector3) -> bool:
			for o in centers:
				if (o - at).length() < gap:
					return false
			return true
		for pc in sk.pieces:
			var wood_kind := pc.kind == TreeLayouts.Kind.LIMB or pc.kind == TreeLayouts.Kind.BRANCH
			var leader := column and pc.kind == TreeLayouts.Kind.TRUNK
			if not wood_kind and not leader:
				continue
			var total := pc.length()
			var s0 := total * (0.85 if leader else 2.0 / 3.0)
			# From the tip inward, so every piece ends in leaves.
			var s := total
			var flip := 1.0 if rng.randf() < 0.5 else -1.0
			while s >= s0 - 1e-6:
				var q := pc.at(s)
				var p: Vector3 = q[0]
				var axis: Vector3 = q[1]
				var side := axis.cross(Vector3.UP)
				side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
				var tip := s >= total - 1e-6
				# Up off the wood and out to one side (the tip's sits on it).
				var off := (0.0 if tip else flip * r * rng.randf_range(0.9, 1.15)) + r * rng.randf_range(-0.2, 0.2)
				var at := p + Vector3.UP * r * flat * rng.randf_range(0.35, 0.6) + side * off
				if fits.call(at):
					centers.append(at)
				if tip and pc.kind == TreeLayouts.Kind.BRANCH and not light:
					for k in twigs:
						# A twig out from the tip, forward and up, fanned.
						var fan := rng.randf_range(0.6, 1.2) * (1.0 if k % 2 == 0 else -1.0)
						var dir := (axis * 0.7 + side * fan * 0.7 + Vector3.UP * rng.randf_range(0.2, 0.5)).normalized()
						var end := p + dir * r * rng.randf_range(1.7, 2.3)
						var tc := end + Vector3.UP * r * flat * 0.3
						if not fits.call(tc):
							continue
						var tr := maxf(float(q[2]) * 0.55, 0.002)
						tube([[p, tr, sk.sway * 0.3], [p.lerp(end, 0.5) + Vector3.UP * r * 0.15, tr * 0.8, sk.sway * 0.5], [end, tr * 0.5, sk.sway * 0.7]], 4, wood)
						centers.append(tc)
				flip = -flip
				s -= step
		# Thinning keys: a shuffled even spread over 0-1.
		var order: Array[int] = []
		for i in centers.size():
			order.append(i)
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := order[i]
			order[i] = order[j]
			order[j] = t
		var keep := order.size()
		var grow := 1.0
		if light and order.size() > LIGHT_CLUSTERS:
			keep = LIGHT_CLUSTERS
			grow = sqrt(float(order.size()) / LIGHT_CLUSTERS) * 0.95
		for rank in keep:
			var i := order[rank]
			var key := (rank + 0.5) / keep
			var tone := col
			match i % 3:
				1:
					tone = col.lightened(0.08)
				2:
					tone = col.darkened(0.08)
			var size := r * rng.randf_range(0.85, 1.15) * grow
			cluster(centers[i], size, flat, tone, sk.sway, key)
			hang_from.append([centers[i], Vector3(size, size * flat, size)])

	## One leaf cluster: crossed alpha-cutout cards around `center`, one
	## lying nearly flat (what you see from below), two upright at right
	## angles, and near the player one more tilted between them, each
	## nudged off the middle so the clump is lumpy, not a ball. Normals
	## point out from the cluster's middle (and up a little), so it shades
	## like a rounded clump, not flat cards. Material 5: the foliage shader
	## hides it when `key` is above the tree's leaf amount, else scales it
	## about its center by that amount.
	func cluster(center: Vector3, r: float, flat: float, col: Color, sway: float, key: float) -> void:
		var spin := rng.randf() * TAU
		var facings: Array[Vector3] = [
			Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)),
			Vector3(cos(spin), 0.15, sin(spin)),
			Vector3(cos(spin + PI * 0.5), 0.15, sin(spin + PI * 0.5)),
		]
		if hero:
			facings.append(Vector3(cos(spin + PI * 0.25), 0.8, sin(spin + PI * 0.25)))
		for k in facings.size():
			var f := facings[k].normalized()
			var t1 := f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
			var t2 := f.cross(t1)
			var a := rng.randf() * TAU
			var size := r * (1.15 if k == 0 else 1.0)
			var a1 := (t1 * cos(a) + t2 * sin(a)) * size
			var a2 := (-t1 * sin(a) + t2 * cos(a)) * size
			var squash := Vector3(1.0, flat, 1.0)
			var mid := center + Vector3(rng.randfn(), rng.randfn() * 0.5, rng.randfn()) * r * 0.22 * squash
			var p := [mid + (-a1 - a2) * squash, mid + (a1 - a2) * squash, mid + (a1 + a2) * squash, mid + (-a1 + a2) * squash]
			# Mirror the texture on some cards so neighbours don't repeat.
			var q := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			if rng.randf() < 0.5:
				q = [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]
			for idx in [[0, 1, 2], [0, 2, 3]]:
				for j in idx:
					var pv: Vector3 = p[j]
					var nrm := (pv - center + Vector3.UP * r * 0.6).normalized()
					v.append(pv)
					n.append(nrm)
					c.append(Color(col * (0.88 + 0.12 * nrm.y), sway))
					uv.append(q[j])
					uv2.append(Vector2(5.0, twig_phase))
					parts.append(-1)
					cu.append_array([center.x, center.y, center.z, key])

	## Bark tube along a centerline (`pts`, radius `rad` at each point),
	## `ring` sides, no sway. Each ring's orientation is carried along from
	## the one before (no twist where the wood curves); `cap` closes the far
	## end with a low rounded cone.
	func wood_tube(pts: PackedVector3Array, rad: PackedFloat32Array, ring: int, cap: bool, sw := PackedFloat32Array()) -> void:
		mat = 0.0
		part += 1
		var n := pts.size()
		var rings: Array = []
		var side := Vector3.ZERO
		var axis := Vector3.UP
		for i in n:
			axis = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			if i == 0:
				side = axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
			else:
				side = (side - axis * side.dot(axis)).normalized()
			var side2 := axis.cross(side).normalized()
			var r: Array = []
			for k in ring:
				var a := TAU * k / ring
				r.append(pts[i] + (side * cos(a) + side2 * sin(a)) * rad[i])
			rings.append(r)
		var swv := func(i: int) -> float: return sw[i] if i < sw.size() else 0.0
		for i in n - 1:
			var s0: float = swv.call(i)
			var s1: float = swv.call(i + 1)
			for k in ring:
				var k1 := (k + 1) % ring
				tri(rings[i][k], rings[i + 1][k1], rings[i][k1], wood, s0, s1, s0)
				tri(rings[i][k], rings[i + 1][k], rings[i + 1][k1], wood, s0, s1, s1)
		if cap:
			var tip := pts[n - 1] + axis * rad[n - 1] * 0.6
			var st: float = swv.call(n - 1)
			for k in ring:
				var k1 := (k + 1) % ring
				tri(rings[n - 1][k], tip, rings[n - 1][k1], wood, st, st, st)
		mat = 1.0

	## A crown of `lobes` overlapping, noise-displaced icospheres: one big
	## lobe at `center`, the rest clustered around its upper half. Faces
	## buried inside another lobe are dropped (the triangles go to the
	## silhouette). Leaf cards sit on the outer surface to rag the outline.
	func crown(center: Vector3, radii: Vector3, lobes: int, col: Color, sway: float) -> void:
		var specs: Array = [[center, radii, col]]
		for k in lobes - 1:
			var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / maxf(lobes - 1, 1)
			var dir := Vector3(cos(a), rng.randf_range(0.05, 0.45), sin(a)).normalized()
			var tone := col.lightened(0.08) if k % 2 == 0 else col.darkened(0.06)
			specs.append([center + dir * radii * 0.62, radii * rng.randf_range(0.5, 0.7), tone])
		for sp in specs:
			hang_from.append([sp[0], sp[1]])
		# No hull on any plant (design 1 Oct §CA): each lobe is a shell of
		# leaf-cluster cards, open between them, never a smooth ball.
		for i in specs.size():
			cluster_shell(specs[i][0], specs[i][1], specs[i][2], sway)

	## A lobe's worth of leaf-cluster cards scattered over the shell of an
	## ellipsoid (centre, radii): the §AJ cards where a hull used to be.
	func cluster_shell(center: Vector3, radii: Vector3, col: Color, sway: float) -> void:
		var mean := (radii.x + radii.y + radii.z) / 3.0
		var count := clampi(int(mean * 16.0), 3, 10) * (1 if far else 2)
		for i in count:
			var d := Vector3(rng.randfn(), rng.randfn() * 0.8 + 0.3, rng.randfn()).normalized()
			cluster(center + d * radii * 0.75, maxf(mean * 0.55, 0.05), 0.8, col * (0.85 + 0.15 * d.y), sway, rng.randf())

	## One icosphere lobe with a lumpy surface and top-lit vertex shading;
	## faces inside any of `others` ([center, radii, ...]) are skipped.
	## `cards`: leaf cards on it (-1: three on lobes big enough for them).
	func lobe(center: Vector3, radii: Vector3, col: Color, sway: float, detail: int, others := [], cards := -1) -> void:
		part += 1
		var sphere: Array = PlantMeshes.geosphere(detail)
		var verts: PackedVector3Array = sphere[0]
		var faces: PackedInt32Array = sphere[1]
		var ph := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var disp := PackedVector3Array()
		var shade := PackedColorArray()
		for u in verts:
			var bump := 0.11 * sin(u.x * 3.1 + ph.x) * sin(u.y * 2.7 + ph.y) + 0.07 * sin(u.z * 4.3 + u.x * 1.7 + ph.z)
			disp.append(center + u * radii * (1.0 + bump))
			shade.append(col * (0.82 + 0.18 * u.y))
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b2 := faces[f + 1]
			var d := faces[f + 2]
			if _buried((disp[a] + disp[b2] + disp[d]) / 3.0, others):
				continue
			tri3(disp[a], disp[b2], disp[d], shade[a], shade[b2], shade[d], sway, sway, sway)
		var mean_r := (radii.x + radii.y + radii.z) / 3.0
		if cards < 0:
			cards = 3 if mean_r >= 0.1 and not far else 0
		if not far:
			for i in cards:
				# Outward and mostly sideways or up: where the silhouette is.
				var d := Vector3(rng.randfn(), rng.randfn() * 0.6 + 0.3, rng.randfn()).normalized()
				var p := center + d * radii * 0.95
				if not _buried(p, others):
					card(p, d, mean_r * 0.55, col * (0.85 + 0.15 * d.y), sway)

	## Inside one of the lobes in `others` (with a margin for the bumps)?
	func _buried(p: Vector3, others: Array) -> bool:
		for o in others:
			if ((p - (o[0] as Vector3)) / ((o[1] as Vector3) * 0.86)).length() < 1.0:
				return true
		return false

	## Hanging vines (lianas, or beard lichen on conifers): `count` strands
	## from under the crown toward the ground, each two crossed ribbons in
	## three swaying segments. Hidden unless the site is wet (shader).
	func vines(count: int, col: Color) -> void:
		if far or hang_from.is_empty():
			return
		mat = 3.0
		for k in count:
			strand_key = (k + 0.5) / count
			part += 1
			var h: Array = hang_from[rng.randi() % hang_from.size()]
			var c: Vector3 = h[0]
			var rr: Vector3 = h[1]
			var a := rng.randf() * TAU
			var top := c + Vector3(cos(a) * rr.x * 0.75, -rr.y * 0.45, sin(a) * rr.z * 0.75)
			var length := minf(rng.randf_range(0.25, 0.5), top.y - 0.06)
			if length < 0.08:
				continue
			var w := 0.016
			var prev := top
			for seg in 3:
				var t1 := float(seg + 1) / 3.0
				var p := top + Vector3(sin(a + t1 * 2.0) * 0.03, -length * t1, cos(a + t1 * 2.0) * 0.03)
				var s0 := lerpf(0.8, 1.0, float(seg) / 3.0)
				var s1 := lerpf(0.8, 1.0, t1)
				var tone := col.darkened(0.1 * seg)
				for side in [Vector3(w, 0, 0), Vector3(0, 0, w)]:
					tri(prev - side, p - side * 0.7, p + side * 0.7, tone, s0, s1, s1)
					tri(prev - side, p + side * 0.7, prev + side, tone, s0, s1, s0)
				prev = p
		strand_key = 0.0
		mat = 1.0

	## A bamboo clump: culms in a tight cluster (about an eighth of the
	## height across), rising straight and arching outward near the top,
	## each with feathery leaf sprays (cards) along its upper part. Culms
	## are material 4: the foliage shader rings them with nodes. The whole
	## clump sways, most at the tips.
	func bamboo(culm: Color, leaf: Color) -> void:
		var count := 4 if far else 7
		var sides := 5
		for k in count:
			var a := TAU * (k + rng.randf_range(-0.3, 0.3)) / count
			var r0 := rng.randf_range(0.015, 0.06)
			var base := Vector3(cos(a) * r0, 0.0, sin(a) * r0)
			var out := Vector3(cos(a), 0.0, sin(a))
			var h := rng.randf_range(0.72, 1.0)
			var lean := rng.randf_range(0.08, 0.2)
			var radius := rng.randf_range(0.006, 0.009)
			var pts: Array = []
			var rings := [0.0, 0.5, 0.8, 1.0] if not far else [0.0, 0.6, 1.0]
			for t in rings:
				# Straight low down, arching out toward the tip.
				var bend := out * lean * pow(t, 2.2) * h
				pts.append([base + Vector3(0, t * h, 0) + bend - Vector3(0, lean * 0.4 * pow(t, 3.0) * h, 0), radius * lerpf(1.0, 0.55, t), lerpf(0.0, 1.0, t)])
			mat = 4.0
			part += 1
			var rs: Array = []
			for i in pts.size():
				var p: Vector3 = pts[i][0]
				var nxt: Vector3 = pts[mini(i + 1, pts.size() - 1)][0]
				var prv: Vector3 = pts[maxi(i - 1, 0)][0]
				var axis := (nxt - prv).normalized()
				var s1 := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
				var s2 := axis.cross(s1).normalized()
				var ring: Array = []
				for j in sides:
					var ang := TAU * j / sides
					ring.append(p + (s1 * cos(ang) + s2 * sin(ang)) * float(pts[i][1]))
				rs.append(ring)
			for i in pts.size() - 1:
				var sw0: float = pts[i][2]
				var sw1: float = pts[i + 1][2]
				for j in sides:
					var j1 := (j + 1) % sides
					tri(rs[i][j], rs[i + 1][j1], rs[i][j1], culm, sw0, sw1, sw0)
					tri(rs[i][j], rs[i + 1][j], rs[i + 1][j1], culm, sw0, sw1, sw1)
			mat = 1.0
			# Feathery leaf sprays down the upper two-thirds of the culm,
			# small and many, drooping outward.
			var sprays := 2 if far else 5
			for n in sprays:
				var t := lerpf(0.38, 1.0, (n + rng.randf()) / sprays)
				var seg := int(t * (pts.size() - 1))
				var f := t * (pts.size() - 1) - seg
				var c: Vector3 = (pts[seg][0] as Vector3).lerp(pts[mini(seg + 1, pts.size() - 1)][0], f)
				var side := Vector3(rng.randfn(), 0.0, rng.randfn()).normalized()
				var dir := (out * 0.8 + side * 0.7 + Vector3(0, rng.randf_range(-0.35, 0.15), 0)).normalized()
				var size := h * rng.randf_range(0.045, 0.07) * (1.6 if far else 1.0)
				card(c + dir * size * 0.8, dir, size, leaf * rng.randf_range(0.8, 1.05), t)

	## Flat leaf from `base` outward along `dir`, drooping at the tip. Its
	## base sways `base_sway` (by default 0.4 of the tip's).
	func frond(base: Vector3, dir: Vector3, length: float, width: float, col: Color, sway: float, base_sway := -1.0) -> void:
		part += 1
		var d := dir.normalized()
		var side := d.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized() * width
		var mid := base + d * length * 0.55
		var tip := base + d * length + Vector3(0, -length * 0.15, 0)
		tri(base, mid + side, mid - side, col, sway * 0.4 if base_sway < 0.0 else base_sway, sway, sway)
		tri(mid - side, mid + side, tip, col.lightened(0.05), sway, sway, sway)

	## Thin grass blade from base to tip.
	func blade(base: Vector3, tip: Vector3, width: float, col: Color, sway: float) -> void:
		part += 1
		var side := (tip - base).cross(Vector3.FORWARD).normalized() * width
		if side.length() < 1e-4:
			side = Vector3(width, 0, 0)
		tri(base - side, tip, base + side, col, 0.0, sway, 0.0)

	## Straight root/strut from a to b (wood you can hold: no sway).
	func strut(a: Vector3, b2: Vector3, r: float, col: Color) -> void:
		var axis := (b2 - a)
		cylinder(a, r, axis.length(), 4, col, 0.0, 0.0, axis.normalized())

	## Hanging strand from `top` down by `length`, sways fully.
	func strand(top: Vector3, length: float, width: float, col: Color) -> void:
		part += 1
		var bottom := top + Vector3(0, -length, 0)
		var s := Vector3(width, 0, 0)
		var s2 := Vector3(0, 0, width)
		tri(top - s, bottom, top + s, col, 0.4, 1.0, 0.4)
		tri(top - s2, bottom, top + s2, col.darkened(0.1), 0.4, 1.0, 0.4)

	## Flat irregular patch on the ground.
	func disc(center: Vector3, r: float, h: float, sides_n: int, col: Color, sway: float) -> void:
		var sides := sides(sides_n)
		part += 1
		var top := center + Vector3(0, h, 0)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var r0 := r * (0.75 + 0.25 * sin(a0 * 3.0))
			var r1 := r * (0.75 + 0.25 * sin(a1 * 3.0))
			var p0 := center + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p1 := center + Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			tri(p0, top, p1, col, sway, sway, sway)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, commit_arrays(), [], {}, PlantMeshes.FORMAT)
		return mesh

	func commit_arrays() -> Array:
		# Baked ambient occlusion: the base of each plant (trunk foot, grass
		# roots) is darker, the way it would be in its own shadow. Hanging
		# plants grow down from their origin (y < 0) and are left alone.
		for i in v.size():
			var y := v[i].y
			if y >= 0.0 and y < 0.14:
				var k := lerpf(0.58, 1.0, smoothstep(0.0, 0.14, y))
				c[i] = Color(c[i].r * k, c[i].g * k, c[i].b * k, c[i].a)
		_smooth()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_CUSTOM0] = cu
		return arrays

	## Smooth shading: every vertex of a part gets the area-weighted mean
	## of the face normals meeting at its position in that part.
	func _smooth() -> void:
		var acc := {}
		var keys: Array = []
		keys.resize(v.size())
		for t in range(0, v.size(), 3):
			var fn := (v[t + 1] - v[t]).cross(v[t + 2] - v[t])
			for k in 3:
				var i := t + k
				if parts[i] < 0:
					continue
				var q := Vector3i(v[i] * 20000.0)
				var key := Vector4i(parts[i], q.x, q.y, q.z)
				keys[i] = key
				acc[key] = acc.get(key, Vector3.ZERO) + fn
		for i in v.size():
			if parts[i] < 0:
				continue
			var sum: Vector3 = acc[keys[i]]
			if sum.length_squared() > 1e-12:
				n[i] = sum.normalized()
