class_name VineCover
## Vines climb and cover (design 1 Oct §CE; data/vines.json). The biome's
## vine-category species (habitat.json always_present.groups.vines: the
## climbers and creepers) grow over the world's surfaces, not only as plants
## of their own:
##   * trunks: the trees' own vine strands (material 3) in the vine
##     species' leafy tile (PlantMeshes.material_for), as many strands as
##     surfaces.trunk.cover x the climate (VegetationPlacer; dead trees,
##     the world's dead wood, wear surfaces.log's mat);
##   * cliff faces and open ground: patches laid by chunk_patches() (on the
##     chunk worker), hanging from the top of a steep face or creeping over
##     flat ground;
##   * ruins: their walls and boulders hung from the top (RuinBuilder's
##     anchors, ruin_patches()), by the ruin's age and cut back as a camp
##     restores it (§BQ: cleared halves them, restored clears them).
## Cover = surfaces[*].cover x climate(): moisture between climate.moisture
## (none to full), fading outside climate.temp_c, denser in shade
## (shade_boost). Each patch is leaf cards on strands with the vine
## species' own leaf tile and cutout (PlantMeshes.vine_patch_mesh), flat
## on the surface, drawn within near_m of the player (TerrainChunk bands it
## by reach like the young trees).

static var D: Dictionary = Tuning.table("vines")
static var SURF: Dictionary = D.get("surfaces", {})
static var CLIM: Dictionary = D.get("climate", {})
static var NEAR_M := float(D.get("near_m", 60.0))
static var _vines: Array = []
static var _mutex := Mutex.new()


## The vine species (always_present group "vines"), built once.
static func vines() -> Array:
	_mutex.lock()
	if _vines.is_empty():
		for sp in SpeciesDB.all():
			if VegetationPlacer.presence_group(sp) == "vines" and sp.density > 0.0:
				_vines.append(sp)
	var out := _vines
	_mutex.unlock()
	return out


## The vine that grows at `d` (biome `biome`, climate t / m / h, rock):
## one of the vine species the biome lists that fits the site, picked by
## fit with the spot's own hash; null where the biome has none.
static func species_at(d: Vector3, biome: int, t: float, m: float, h: float, rock: int) -> PlantSpecies:
	var pick: PlantSpecies = null
	var best := 0.0
	var salt := hash(Vector3i((d * 2000.0).floor()))
	for sp in vines():
		if not (sp as PlantSpecies).biomes.has(biome):
			continue
		var f: float = (sp as PlantSpecies).suitability(t, m, h, rock)
		if f <= 0.0:
			continue
		f *= 0.6 + 0.8 * float(hash([salt, (sp as PlantSpecies).name]) & 1023) / 1023.0
		if f > best:
			best = f
			pick = sp
	return pick


## The climate's share of the cover, 0-1 (x shade_boost in shade).
static func climate(m: float, t: float, shade: float) -> float:
	var mb = CLIM.get("moisture", [0.35, 0.85])
	var tb = CLIM.get("temp_c", [2, 34])
	var f := smoothstep(float(mb[0]), float(mb[1]), m)
	f *= smoothstep(float(tb[0]) - 3.0, float(tb[0]) + 3.0, t) * (1.0 - smoothstep(float(tb[1]) - 3.0, float(tb[1]) + 3.0, t))
	return clampf(f * lerpf(1.0, float(CLIM.get("shade_boost", 1.6)), clampf(shade, 0.0, 1.0)), 0.0, 1.0)


## A surface's cover share here, 0-1.
static func cover(surface: String, m: float, t: float, shade: float) -> float:
	return clampf(float((SURF.get(surface, {}) as Dictionary).get("cover", 0.0)) * climate(m, t, shade), 0.0, 1.0)


## One surface's vines at a spot, 0-1 of its strands: the spot's own hash
## against the cover there (surfaces[s].cover x the climate), and a vined
## one climbs a share in surfaces[s].climb_share; 0 when it rolls bare.
static func on_surface(surface: String, d: Vector3, m: float, t: float, shade: float) -> float:
	var roll := float(hash([d, surface, "vine_on"]) & 0xFFFF) / 65535.0
	if roll >= cover(surface, m, t, shade):
		return 0.0
	var cs = (SURF.get(surface, {}) as Dictionary).get("climb_share", [0.2, 0.8])
	var u := float(hash([d, surface, "vine_climb"]) & 0xFFFF) / 65535.0
	return clampf(lerpf(float(cs[0]), float(cs[1]), u), 0.01, 1.0)


## The vine a tree species carries on its trunk: the vine species that
## shares most of its biomes (any vine when none does; null with no vines).
static var _for_tree := {}

static func vine_for_tree(sp: PlantSpecies) -> PlantSpecies:
	var idx := SpeciesDB.index_of(sp)
	_mutex.lock()
	var cached = _for_tree.get(idx, false)
	_mutex.unlock()
	if not (cached is bool):
		return cached
	var best: PlantSpecies = null
	var best_n := -1
	for v in vines():
		var n := 0
		for b in sp.biomes:
			if (v as PlantSpecies).biomes.has(b):
				n += 1
		if n > best_n and (v as PlantSpecies).tiles.has("leaves"):
			best_n = n
			best = v
	_mutex.lock()
	_for_tree[idx] = best
	_mutex.unlock()
	return best


## Cliff faces and open ground on a chunk (worker thread): {species index:
## {"hang": [Transform3D...], "creep": [Transform3D...]}} in the chunk's
## frame (the trees' frame: position = dir x radius - center x anchor_r).
## Steep coarse vertices get a patch hanging from a little above them, by
## surfaces.cliff; flat open ones a creeping patch, by surfaces.ground
## (patch_m across), scattered by the spot's hash.
static func chunk_patches(map: PlanetData, data: Dictionary, shade_of: Callable) -> Dictionary:
	var out := {}
	var dirs: PackedVector3Array = data.dirs
	var hs: PackedFloat32Array = data.heights
	var normals: PackedVector3Array = data.normals
	var center: Vector3 = data.center
	var ar: float = data.anchor_r
	var cliff_d: Dictionary = SURF.get("cliff", {})
	var ground_d: Dictionary = SURF.get("ground", {})
	var pm = ground_d.get("patch_m", [1.5, 6.0])
	var share = cliff_d.get("climb_share", [0.1, 0.4])
	for i in dirs.size():
		var at := _vertex(map, dirs[i], hs[i], normals[i], shade_of.call(i))
		if at.is_empty():
			continue
		var d := dirs[i]
		var e := hs[i]
		var form: String = at[0]
		var sp: PlantSpecies = at[1]
		var rng: RandomNumberGenerator = at[2]
		var r := PlanetConst.RADIUS_M + e
		var pos := Vector3(d.x * r - center.x * ar, d.y * r - center.y * ar, d.z * r - center.z * ar)
		var xf: Transform3D
		if form == "hang":
			# Facing out of the slope (its normal's level part), hanging
			# from a share of the face's height above the vertex.
			var out_n := (normals[i] - d * normals[i].dot(d)).normalized()
			var side := d.cross(out_n).normalized()
			var len_m := rng.randf_range(2.0, 6.0) * lerpf(float(share[0]), float(share[1]), rng.randf()) / 0.25
			var top := pos + d * len_m * 0.5 + out_n * 0.15
			xf = Transform3D(Basis(side * rng.randf_range(1.2, 2.0), d * len_m, out_n), top)
		else:
			var a := rng.randf() * TAU
			var east := CubeSphere.east(d)
			var north := CubeSphere.north(d)
			var fx := east * cos(a) + north * sin(a)
			var size := rng.randf_range(float(pm[0]), float(pm[1]))
			xf = Transform3D(Basis(fx * size, d, d.cross(fx) * size), pos + d * 0.02)
		var key := SpeciesDB.index_of(sp)
		if not out.has(key):
			out[key] = {"hang": [], "creep": []}
		(out[key][form] as Array).append(xf)
	return out


## The vine at one coarse vertex, or []: [form, species, its rng] — a
## steep one hangs a patch (surfaces.cliff), a flat open one creeps
## (surfaces.ground), by the spot's own hash against the cover there.
## The same decision for the near patches and the far tint (green()).
static func _vertex(map: PlanetData, d: Vector3, e: float, normal: Vector3, shade: float) -> Array:
	if e < PlanetConst.SEA_LEVEL_M + 0.5:
		return []
	var c := map.cell_at(d)
	if map.water[c] != PlanetData.Water.NONE:
		return []
	var w := map.weights_at(d)
	var m := map.sample_w(map.moisture, w)
	var t := map.sample_w(map.temp_c, w) + (map.sample_w(map.elevation, w) - e) * PlanetConst.LAPSE_RATE_C_PER_M
	var steep := 1.0 - normal.dot(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([d, "vine"])
	var form := ""
	var cov := 0.0
	if steep > 0.25:
		form = "hang"
		cov = cover("cliff", m, t, shade)
	elif steep < 0.12:
		form = "creep"
		cov = cover("ground", m, t, shade)
	if form == "" or rng.randf() >= cov:
		return []
	var sp := species_at(d, map.biome[c], t, m, e, map.rock[c])
	if sp == null:
		return []
	return [form, sp, rng]


## Beyond near_m the cards are not drawn: the ground under a patch takes
## the vine's green instead (far_tint of the way to the species' colour),
## in the chunk's own vertex colours (base data, worker thread, after
## the canopy shade is baked into their alpha).
static func green(map: PlanetData, data: Dictionary) -> void:
	var cols: PackedColorArray = data.get("colors", PackedColorArray())
	var dirs: PackedVector3Array = data.dirs
	var hs: PackedFloat32Array = data.heights
	var normals: PackedVector3Array = data.normals
	var tint := float(D.get("far_tint", 0.5))
	if cols.size() != dirs.size() or tint <= 0.0:
		return
	for i in dirs.size():
		var at := _vertex(map, dirs[i], hs[i], normals[i], 1.0 - cols[i].a)
		if at.is_empty():
			continue
		var c := cols[i]
		var g: Color = (at[1] as PlantSpecies).color
		cols[i] = Color(lerpf(c.r, g.r, tint), lerpf(c.g, g.g, tint), lerpf(c.b, g.b, tint), c.a)
	data["colors"] = cols


## Ruin surfaces (main thread): patches hanging from RuinBuilder's anchors
## ([top, out, length] in the ruin's frame) on `ruin` by its cover: the
## surface's share (surfaces.ruin, or .boulder for its tumbled rocks) x
## the climate x its age (full_after_years),
## cut back as a camp restores it (legibility 1 cleared: half; 2 restored:
## none, ruins.restored_clears).
static func ruin_patches(ruin: Node3D, anchors: Array, sp: PlantSpecies, m: float, t: float, age_years: float, legibility: int, surface := "ruin") -> MultiMeshInstance3D:
	if sp == null or anchors.is_empty():
		return null
	var rd: Dictionary = D.get("ruins", {})
	var age := clampf(age_years / maxf(float(rd.get("full_after_years", 40.0)), 1.0), 0.0, 1.0)
	var cut := 1.0
	if bool(rd.get("restored_clears", true)):
		cut = 1.0 if legibility <= 0 else (0.5 if legibility == 1 else 0.0)
	var cov := cover(surface, m, t, 0.5) * age * cut
	if cov <= 0.0:
		return null
	var share = (SURF.get(surface, {}) as Dictionary).get("climb_share", [0.4, 1.0])
	var xfs: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ruin.name, "ruin_vines"])
	for k in anchors.size():
		var a: Array = anchors[k]
		# Each strand's own roll, so less cover keeps a subset of the
		# strands more cover keeps (cutting back only ever removes).
		if float(hash([ruin.name, k, surface, "ruin_vine"]) & 0xFFFF) / 65535.0 >= cov:
			continue
		var top: Vector3 = a[0]
		var out_n: Vector3 = (a[1] as Vector3).normalized()
		var len_m := float(a[2]) * lerpf(float(share[0]), float(share[1]), rng.randf())
		var side := Vector3.UP.cross(out_n).normalized()
		xfs.append(Transform3D(Basis(side * rng.randf_range(1.0, 1.8), Vector3.UP * len_m, out_n), top + out_n * 0.05))
	if xfs.is_empty():
		return null
	var mmi := _mmi(sp, "hang", xfs)
	mmi.name = "Vines" if surface == "ruin" else "Vines_" + surface
	mmi.visibility_range_end = NEAR_M
	ruin.add_child(mmi)
	return mmi


## A MultiMeshInstance3D of a vine species' patches (the foliage material
## and its leaf tile), every patch at `xfs`.
static func _mmi(sp: PlantSpecies, form: String, xfs: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = PlantMeshes.vine_patch_mesh(sp, form)
	mm.instance_count = xfs.size()
	# The raw buffer (20 floats: transform rows, colour, custom), like
	# every other plant MultiMesh: banding and LookTarget read it back.
	var buf := PackedFloat32Array()
	buf.resize(xfs.size() * 20)
	for i in xfs.size():
		var t: Transform3D = xfs[i]
		var k := i * 20
		for r in 3:
			buf[k + r * 4] = t.basis.x[r]
			buf[k + r * 4 + 1] = t.basis.y[r]
			buf[k + r * 4 + 2] = t.basis.z[r]
			buf[k + r * 4 + 3] = t.origin[r]
		for c in 4:
			buf[k + 12 + c] = 1.0
		# (moss, vines, rustle, bare): all 0, so every card shows.
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = PlantMeshes.material_for(sp)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta("species", SpeciesDB.index_of(sp))
	return mmi


## The chunk's cliff and ground patches as MultiMeshes under `parent`
## (the chunk's undergrowth node; main thread), each marked "vine" so the
## chunk draws only the patches within near_m (TerrainChunk.setup_bands).
static func build_nodes(parent: Node3D, patches: Dictionary) -> void:
	var all := SpeciesDB.all()
	for key in patches:
		var sp: PlantSpecies = all[int(key)]
		for form in ["hang", "creep"]:
			var xfs: Array = patches[key][form]
			if xfs.is_empty():
				continue
			var mmi := _mmi(sp, form, xfs)
			mmi.name = "Vines_%s_%s" % [sp.name.replace(" ", "_"), form]
			mmi.set_meta("vine", true)
			mmi.visibility_range_end = NEAR_M + TerrainChunk.CHUNK_M * 0.75
			parent.add_child(mmi)
