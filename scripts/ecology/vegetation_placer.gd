class_name VegetationPlacer
## Places plants on one terrain chunk (DESIGN.md "Vegetation"). Plants read
## climate, never biome names; each species grows wherever its bands fit.
##
## Spawning is split so only what's near the player exists:
##   compute_base()   - emergent + canopy trees, for every loaded chunk
##                      (trees are what you see from a distance).
##   compute_detail() - shrubs, ground cover, epiphytes, cypress knees, only
##                      for chunks right around the player; ChunkManager
##                      adds and drops this layer as you walk.
##
## For each tier, candidate sites sit on a jittered grid whose spacing is
## the tier's minimum distance, so trunks never overlap. At each site:
##   climate     - blueprint temperature (°C) corrected by the lapse rate to
##                 the site's exact height, and by aspect: equator-facing
##                 slopes run a few degrees warmer and drier, shaded slopes
##                 cooler and wetter, so each altitude band has a warm and a
##                 cold face.
##   water       - moisture rises near rivers, lakes and coasts, so trees
##                 crowd water and dry grassland gets gallery-forest ribbons
##                 along rivers.
##   suitability - each species' bell-shaped bands x soil x special needs
##                 (standing water, river bank, salt, hot ground).
##   dominance   - a slow noise field per species boosts a local favourite:
##                 one valley mostly spruce with some fir, the next flipped.
##   clumping    - a patch-scale noise mask, so plants grow in patches.
##   clearings   - nothing grows on mythical folk campsites or inside ruins.
##   shade       - ground cover thins under heavy canopy.
## Then per plant: size and lean jitter. Epiphytes attach to trees already
## placed; cypress knees scatter around cypress standing in water.
##
## Both compute functions are thread-safe (read-only planet data);
## build_nodes() makes one MultiMesh per species on the main thread.

## Plants other than water plants keep this far above standing water.
const WATERLINE_M := 0.3
const T := PlantSpecies.Tier
const SPACING_M := {0: 28.0, 1: 7.0, 2: 4.5, 3: 3.5}
const FILL := {0: 0.55, 1: 0.9, 2: 0.65, 3: 0.95}
## Moist forest packs tighter (layered, view-framing woods like the
## references): spacing per tier scales down this far at full moisture.
## (Shrubs stay as they were: packed tighter they wall in the view.)
const DENSE_SPACING := {0: 1.0, 1: 0.8, 2: 1.0, 3: 0.8}
const ASPECT_C := 3.0 # °C warmer on a fully equator-facing steep slope
const ASPECT_MOISTURE := 0.07
const WATER_BOOST := 0.3
const WATER_BOOST_M := 70.0
const DOMINANCE_M := 1500.0
const CLUMP_M := 60.0
const EPIPHYTE_RATE := 0.9

## Instance record layout in the per-species PackedFloat32Array.
const STRIDE := 10 # dir.xyz, radius, yaw, lean_x, lean_z, height, moss, vines
const MM_STRIDE := 20 # MultiMesh buffer floats per instance: 3x4 transform, color, custom

## Built once on the main thread (warm()) and only read by the chunk
## workers: per-species dominance noise, per-tier clump noise, and the
## species cypress knees need.
static var _dominance_noise: Array[FastNoiseLite] = []
static var _clump_noise: Array[FastNoiseLite] = []
static var _cypress: PlantSpecies
static var _knees: PlantSpecies
static var _warm_seed := -1


## Call on the main thread before any chunk is computed (and again if the
## world seed changes).
static func warm(world_seed: int) -> void:
	if _warm_seed == world_seed:
		return
	_warm_seed = world_seed
	_dominance_noise.clear()
	for i in SpeciesDB.all().size():
		var nz := FastNoiseLite.new()
		nz.seed = world_seed * 97 + i * 13
		nz.frequency = 1.0 / DOMINANCE_M
		_dominance_noise.append(nz)
	_clump_noise.clear()
	for tier in 5:
		var nz := FastNoiseLite.new()
		nz.seed = world_seed * 31 + tier
		nz.frequency = 1.0 / CLUMP_M
		_clump_noise.append(nz)
	_cypress = SpeciesDB.find("Bald cypress")
	_knees = null
	for sp in SpeciesDB.all():
		if sp.shape == PlantSpecies.Shape.KNEES:
			_knees = sp


## Trees. Returns {"plants": {species_index: PackedFloat32Array},
## "hosts": [[dir, radius, height, species_index, water_depth], ...]}.
static func compute_base(key: Vector3i, map: PlanetData, data: Dictionary) -> Dictionary:
	var ctx := _Context.new(key, map, data, 1)
	var plants := {}
	var hosts: Array = []
	_place_tier(ctx, T.EMERGENT, plants, hosts)
	_place_tier(ctx, T.CANOPY, plants, hosts)
	return {"plants": plants, "hosts": hosts}


## Undergrowth and epiphytes. `hosts` comes from compute_base().
static func compute_detail(key: Vector3i, map: PlanetData, data: Dictionary, hosts: Array) -> Dictionary:
	var ctx := _Context.new(key, map, data, 2)
	var plants := {}
	var unused: Array = []
	_place_tier(ctx, T.SHRUB, plants, unused)
	_place_tier(ctx, T.GROUND, plants, unused)
	_place_epiphytes(ctx, plants, hosts)
	_place_knees(ctx, plants, hosts)
	return plants


static func _place_tier(ctx: _Context, tier: int, out: Dictionary, hosts: Array) -> void:
	var candidates := ctx.species_for(tier)
	if candidates.is_empty():
		return
	var spacing: float = SPACING_M[tier] * lerpf(1.0, DENSE_SPACING[tier], smoothstep(0.5, 0.75, ctx.mean_moisture))
	var cells := maxi(1, int(ctx.chunk_m / spacing))
	var weights := PackedFloat32Array()
	weights.resize(candidates.size())
	for b in cells:
		for a in cells:
			var gx := (a + 0.5 + ctx.rng.randf_range(-0.3, 0.3)) / cells * TerrainChunk.QUADS
			var gy := (b + 0.5 + ctx.rng.randf_range(-0.3, 0.3)) / cells * TerrainChunk.QUADS
			var site := ctx.site(gx, gy)
			if ctx.in_clearing(site.dir):
				continue
			if tier == T.CANOPY and ctx.near_emergent(site.dir):
				continue
			var total := 0.0
			for k in candidates.size():
				var w := ctx.weight(candidates[k], site)
				weights[k] = w
				total += w
			if total <= 0.0:
				continue
			var p := ctx.clump_at(tier, gx, gy) * minf(total, 1.0) * float(FILL[tier])
			if tier == T.GROUND:
				p *= 1.0 - 0.7 * clampf(ctx.shade_at(gx, gy), 0.0, 1.0)
			if ctx.rng.randf() >= p:
				continue
			var pick := ctx.rng.randf() * total
			var chosen := candidates.size() - 1
			for k in candidates.size():
				pick -= weights[k]
				if pick <= 0.0:
					chosen = k
					break
			var sp: PlantSpecies = candidates[chosen]
			var height := lerpf(sp.height_m.x, sp.height_m.y, pow(ctx.rng.randf(), 0.8))
			var sp_idx := SpeciesDB.index_of(sp)
			# Wet sites mossy, wet and warm ones hung with vines (0-1 each,
			# per plant; the foliage shader shows them).
			var moss := smoothstep(0.45, 0.85, site.m)
			var vines := smoothstep(0.62, 0.92, site.m) * smoothstep(4.0, 16.0, site.t)
			_emit(out, sp_idx, site.dir, PlanetConst.RADIUS_M + site.h, ctx.rng, height, 0.09, moss, vines)
			if tier == T.EMERGENT or tier == T.CANOPY:
				hosts.append([site.dir, PlanetConst.RADIUS_M + site.h, height, sp_idx, site.depth])
				if tier == T.EMERGENT:
					ctx.add_emergent(site.dir)


static func _emit(out: Dictionary, sp_idx: int, d: Vector3, radius: float, rng: RandomNumberGenerator, height: float,
		lean_max := 0.09, moss := 0.0, vines := 0.0) -> void:
	if not out.has(sp_idx):
		out[sp_idx] = PackedFloat32Array()
	var arr: PackedFloat32Array = out[sp_idx]
	arr.append_array([d.x, d.y, d.z, radius, rng.randf() * TAU,
		rng.randf_range(-lean_max, lean_max), rng.randf_range(-lean_max, lean_max), height, moss, vines])
	out[sp_idx] = arr


## Epiphytes hang from or cling to hosts already placed.
static func _place_epiphytes(ctx: _Context, out: Dictionary, hosts: Array) -> void:
	var epis := ctx.species_for(T.EPIPHYTE)
	if epis.is_empty():
		return
	for host in hosts:
		var d: Vector3 = host[0]
		var site := ctx.site_at_dir(d)
		var host_h: float = host[2]
		for sp in epis:
			var w := sp.suitability(site.t, site.m, site.h, site.rock) * EPIPHYTE_RATE
			var count := int(w * 2.0 + ctx.rng.randf())
			for k in count:
				var angle := ctx.rng.randf() * TAU
				var off := (CubeSphere.east(d) * cos(angle) + CubeSphere.north(d) * sin(angle)) * host_h * 0.22
				var attach := host_h * ctx.rng.randf_range(0.55, 0.85)
				var size := lerpf(sp.height_m.x, sp.height_m.y, ctx.rng.randf())
				if sp.shape == PlantSpecies.Shape.LIANA:
					attach = host_h * 0.8
					size = minf(size, attach * 0.9)
				var pd := (d + off / PlanetConst.RADIUS_M).normalized()
				_emit(out, SpeciesDB.index_of(sp), pd, float(host[1]) + attach, ctx.rng, size, 0.03)


## Cypress knees scatter around bald cypress standing in water.
static func _place_knees(ctx: _Context, out: Dictionary, hosts: Array) -> void:
	var cypress := _cypress
	var knees := _knees
	if knees == null or cypress == null:
		return
	var cypress_idx := SpeciesDB.index_of(cypress)
	for host in hosts:
		if host[3] != cypress_idx or float(host[4]) <= 0.0:
			continue
		var d: Vector3 = host[0]
		for k in ctx.rng.randi_range(3, 7):
			var angle := ctx.rng.randf() * TAU
			var dist := ctx.rng.randf_range(1.2, 4.0)
			var off := (CubeSphere.east(d) * cos(angle) + CubeSphere.north(d) * sin(angle)) * dist
			var pd := (d + off / PlanetConst.RADIUS_M).normalized()
			var site := ctx.site_at_dir(pd)
			var size := lerpf(knees.height_m.x, knees.height_m.y, ctx.rng.randf()) + maxf(site.depth, 0.0)
			_emit(out, SpeciesDB.index_of(knees), pd, PlanetConst.RADIUS_M + site.h, ctx.rng, size, 0.05)


## Worker thread: turn compute_base/compute_detail output into ready
## MultiMesh buffers. Positions are relative to the chunk's anchor (its
## center at `anchor_r` from the planet center), which doesn't depend on
## the floating origin, so the whole buffer is built here and the main
## thread only hands it over. Returns sp_idx -> [buffer, count, trees],
## trees being [local_position, height] of canopy and emergent plants.
static func prepare(plants: Dictionary, center: Vector3, anchor_r: float) -> Dictionary:
	var out := {}
	var all := SpeciesDB.all()
	var cx := center.x * anchor_r
	var cy := center.y * anchor_r
	var cz := center.z * anchor_r
	for sp_idx in plants:
		var sp: PlantSpecies = all[sp_idx]
		var arr: PackedFloat32Array = plants[sp_idx]
		var count := arr.size() / STRIDE
		var buf := PackedFloat32Array()
		buf.resize(count * MM_STRIDE)
		var trees: Array = []
		var tall := sp.tier == T.EMERGENT or sp.tier == T.CANOPY
		for i in count:
			var o := i * STRIDE
			var d := Vector3(arr[o], arr[o + 1], arr[o + 2])
			var r: float = arr[o + 3]
			var pos := Vector3(d.x * r - cx, d.y * r - cy, d.z * r - cz)
			var up := d
			var fwd := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
			var basis := Basis(fwd.cross(up), up, fwd).orthonormalized()
			basis = basis.rotated(up, arr[o + 4])
			basis = basis.rotated(basis.x, arr[o + 5]).rotated(basis.z, arr[o + 6])
			basis = basis.scaled(Vector3.ONE * arr[o + 7])
			var k := i * MM_STRIDE
			# Transform as the rows of its 3x4 matrix, then color (white),
			# then custom data (moss, vines, 0, 0): Godot's MultiMesh layout.
			buf[k] = basis.x.x
			buf[k + 1] = basis.y.x
			buf[k + 2] = basis.z.x
			buf[k + 3] = pos.x
			buf[k + 4] = basis.x.y
			buf[k + 5] = basis.y.y
			buf[k + 6] = basis.z.y
			buf[k + 7] = pos.y
			buf[k + 8] = basis.x.z
			buf[k + 9] = basis.y.z
			buf[k + 10] = basis.z.z
			buf[k + 11] = pos.z
			buf[k + 12] = 1.0
			buf[k + 13] = 1.0
			buf[k + 14] = 1.0
			buf[k + 15] = 1.0
			buf[k + 16] = arr[o + 8]
			buf[k + 17] = arr[o + 9]
			if tall:
				trees.append([pos, arr[o + 7]])
		out[sp_idx] = [buf, count, trees]
	return out


## Main thread: one MultiMeshInstance3D per species under `parent`, from
## prepare()'s buffers. Records trees on the chunk for canopy-dwelling
## creatures.
static func build_nodes(parent: Node3D, chunk: TerrainChunk, prepared: Dictionary) -> void:
	var all := SpeciesDB.all()
	for sp_idx in prepared:
		var sp: PlantSpecies = all[sp_idx]
		var entry: Array = prepared[sp_idx]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true # (moss, vines, 0, 0)
		# Instance colors (all white) too: without them the compatibility
		# renderer garbles vertex colors when custom data is on.
		mm.use_colors = true
		# Trees on the chunk start with their light far mesh; the chunk
		# swaps in the full one near the player (TerrainChunk.set_fine).
		var lod := parent == chunk
		mm.mesh = PlantMeshes.mesh_for(sp, lod)
		mm.instance_count = entry[1]
		mm.buffer = entry[0]
		for t in entry[2]:
			chunk.trees.append([t[0], t[1], sp_idx])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = sp.name.replace(" ", "_")
		mmi.multimesh = mm
		mmi.material_override = PlantMeshes.material()
		if lod:
			mmi.set_meta("species", sp_idx)
		if sp.tier == T.GROUND or sp.tier == T.EPIPHYTE:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Out to 300 m so the ground never reads bare (it only exists in
			# the detail ring anyway, ~390 m).
			mmi.visibility_range_end = 300.0
			mmi.visibility_range_end_margin = 40.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mmi)


## Per-chunk working state: climate on a coarse grid, per-species
## dominance, clump and shade grids, and nearby emergent trunks.
class _Context:
	const G := 8 # climate/shade grid cells per chunk edge
	const CG := 16 # clump grid cells per chunk edge

	var map: PlanetData
	var data: Dictionary
	var rng := RandomNumberGenerator.new()
	var chunk_m: float
	var dominance := {} # PlantSpecies -> factor for this chunk
	var _species := {}
	var _clump := {} # tier -> PackedFloat32Array (CG+1)^2
	var _shade := PackedFloat32Array() # (G+1)^2
	var _clim_t := PackedFloat32Array()
	var _clim_m := PackedFloat32Array()
	var mean_moisture := 0.0
	var _clim_e := PackedFloat32Array()
	var _clim_wd := PackedFloat32Array()
	var _clim_coast := PackedFloat32Array()
	var _clim_rock := PackedInt32Array()
	var _emergents := PackedVector3Array()
	var _hot_center := Vector3.ZERO
	var _hot_r := 0.0
	var _clearings: Array = [] # [dir, radius_m]

	func _init(key: Vector3i, p_map: PlanetData, p_data: Dictionary, salt: int) -> void:
		map = p_map
		data = p_data
		rng.seed = hash([key, map.terrain.world_seed, salt])
		chunk_m = PlanetConst.CIRCUMFERENCE_M / 4.0 / TerrainChunk.CHUNKS_PER_FACE
		_sample_climate()
		var hot := map.terrain.nearest_hotspot(data.center)
		_hot_r = hot.radius_m
		_hot_center = map.terrain.hotspot_dirs[hot.index]
		for camp in Territories.camps_near(map, data.center, chunk_m * 0.75):
			_clearings.append([camp, Territories.CLEARING_M])
		_clearings.append_array(Ruins.clearings_near(map, data.center, chunk_m * 0.75))
		_filter_species()

	## Mythical folk camps (Territories) and ruins are kept clear of plants.
	func in_clearing(d: Vector3) -> bool:
		for c in _clearings:
			if CubeSphere.surface_distance_m(c[0], d) < c[1]:
				return true
		return false

	func _sample_climate() -> void:
		var dirs: PackedVector3Array = data.dirs
		var n := TerrainChunk.QUADS + 1
		var step := TerrainChunk.QUADS / G
		for j in G + 1:
			for i in G + 1:
				var d := dirs[(j * step) * n + i * step]
				_clim_t.append(map.sample(map.temp_c, d))
				_clim_m.append(map.sample(map.moisture, d))
				_clim_e.append(map.sample(map.elevation, d))
				_clim_wd.append(map.sample(map.water_dist_km, d) * 1000.0)
				_clim_coast.append(map.sample(map.coast_dist_km, d))
				_clim_rock.append(map.rock[map.cell_at(d)])
		for v in _clim_m:
			mean_moisture += v
		mean_moisture /= _clim_m.size()

	## Species whose bands could fit anywhere in this chunk, plus their
	## dominance factor here (it varies over ~1.5 km, so one value per chunk).
	func _filter_species() -> void:
		var heights: PackedFloat32Array = data.heights
		var hmin := INF
		var hmax := -INF
		for h in heights:
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
		var tmin := INF
		var tmax := -INF
		for k in _clim_t.size():
			tmin = minf(tmin, _clim_t[k] + (_clim_e[k] - hmax) * PlanetConst.LAPSE_RATE_C_PER_M - ASPECT_C)
			tmax = maxf(tmax, _clim_t[k] + (_clim_e[k] - hmin) * PlanetConst.LAPSE_RATE_C_PER_M + ASPECT_C)
		var center: Vector3 = data.center
		for tier in [T.EMERGENT, T.CANOPY, T.SHRUB, T.GROUND, T.EPIPHYTE]:
			var list: Array[PlantSpecies] = []
			for sp in SpeciesDB.by_tier(tier):
				if sp.density <= 0.0 or sp.temp_c.y < tmin or sp.temp_c.x > tmax:
					continue
				if sp.altitude_m.y < hmin or sp.altitude_m.x > hmax:
					continue
				list.append(sp)
				var v := VegetationPlacer._dominance_noise[SpeciesDB.index_of(sp)].get_noise_3dv(center * PlanetConst.RADIUS_M)
				dominance[sp] = 0.35 + 1.3 * smoothstep(-0.2, 0.5, v)
			_species[tier] = list

	func species_for(tier: int) -> Array[PlantSpecies]:
		if _species.has(tier):
			return _species[tier]
		return [] as Array[PlantSpecies]

	## Clumping mask (0.15-1), sampled on a 16 m grid and interpolated.
	func clump_at(tier: int, gx: float, gy: float) -> float:
		if not _clump.has(tier):
			var nz: FastNoiseLite = VegetationPlacer._clump_noise[tier]
			var grid := PackedFloat32Array()
			var dirs: PackedVector3Array = data.dirs
			var n := TerrainChunk.QUADS + 1
			var step := TerrainChunk.QUADS / CG
			for j in CG + 1:
				for i in CG + 1:
					var d := dirs[(j * step) * n + i * step]
					grid.append(0.15 + 0.85 * smoothstep(-0.35, 0.35, nz.get_noise_3dv(d * PlanetConst.RADIUS_M)))
			_clump[tier] = grid
		return _grid_sample(_clump[tier], CG, gx, gy)

	## Canopy cover estimate (0-1), on the climate grid.
	func shade_at(gx: float, gy: float) -> float:
		if _shade.is_empty():
			var step := float(TerrainChunk.QUADS) / G
			for j in G + 1:
				for i in G + 1:
					var s := site(minf(i * step, TerrainChunk.QUADS - 0.001), minf(j * step, TerrainChunk.QUADS - 0.001))
					var total := 0.0
					for sp in species_for(T.CANOPY):
						total += weight(sp, s)
					_shade.append(total * 0.8)
		return _grid_sample(_shade, G, gx, gy)

	func _grid_sample(grid: PackedFloat32Array, cells: int, gx: float, gy: float) -> float:
		var cx := gx / TerrainChunk.QUADS * cells
		var cy := gy / TerrainChunk.QUADS * cells
		var i0 := clampi(int(cx), 0, cells - 1)
		var j0 := clampi(int(cy), 0, cells - 1)
		return _bilerp(grid, j0 * (cells + 1) + i0, cells + 1, cx - i0, cy - j0)

	## Site values at grid coordinates (0..QUADS on each axis).
	func site(gx: float, gy: float) -> _Site:
		var n := TerrainChunk.QUADS + 1
		var dirs: PackedVector3Array = data.dirs
		var hs: PackedFloat32Array = data.heights
		var i0 := clampi(int(gx), 0, TerrainChunk.QUADS - 1)
		var j0 := clampi(int(gy), 0, TerrainChunk.QUADS - 1)
		var tx := gx - i0
		var ty := gy - j0
		var a00 := j0 * n + i0
		var a10 := a00 + 1
		var a01 := a00 + n
		var a11 := a01 + 1
		var s := _Site.new()
		s.dir = (dirs[a00].lerp(dirs[a10], tx)).lerp(dirs[a01].lerp(dirs[a11], tx), ty).normalized()
		# On the drawn 4 m ground, so plants sit on it exactly.
		s.h = TerrainChunk.fine_height(data.fine_heights, gx * 2.0, gy * 2.0)
		var wl: PackedFloat32Array = data.water_level
		s.depth = lerpf(lerpf(wl[a00], wl[a10], tx), lerpf(wl[a01], wl[a11], tx), ty) - s.h
		var salt: PackedByteArray = data.salt
		s.salt = salt[a00] == 1
		var rd: PackedFloat32Array = data.river_dist
		var river := lerpf(lerpf(rd[a00], rd[a10], tx), lerpf(rd[a01], rd[a11], tx), ty)
		# Aspect from the quad's slope; the sun crosses over the equator.
		var p00 := dirs[a00] * (PlanetConst.RADIUS_M + hs[a00])
		var p10 := dirs[a10] * (PlanetConst.RADIUS_M + hs[a10])
		var p01 := dirs[a01] * (PlanetConst.RADIUS_M + hs[a01])
		var normal := (p10 - p00).cross(p01 - p00).normalized()
		if normal.dot(s.dir) < 0.0:
			normal = -normal
		var horizontal := normal - s.dir * normal.dot(s.dir)
		var toward_equator := CubeSphere.north(s.dir) * (-signf(s.dir.y) if absf(s.dir.y) > 1e-4 else 0.0)
		_climate_at(gx, gy, s, river, horizontal.dot(toward_equator))
		return s

	func site_at_dir(d: Vector3) -> _Site:
		var face := CubeSphere.face_of(d)
		var uv := CubeSphere.face_uv(face, d)
		var key: Vector3i = data.key
		var gx := clampf((uv.x + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE * TerrainChunk.QUADS - key.y * TerrainChunk.QUADS, 0.0, TerrainChunk.QUADS - 0.001)
		var gy := clampf((uv.y + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE * TerrainChunk.QUADS - key.z * TerrainChunk.QUADS, 0.0, TerrainChunk.QUADS - 0.001)
		return site(gx, gy)

	func _climate_at(gx: float, gy: float, s: _Site, river_m: float, aspect: float) -> void:
		var cx := gx / TerrainChunk.QUADS * G
		var cy := gy / TerrainChunk.QUADS * G
		var i0 := clampi(int(cx), 0, G - 1)
		var j0 := clampi(int(cy), 0, G - 1)
		var tx := cx - i0
		var ty := cy - j0
		var w := G + 1
		var k00 := j0 * w + i0
		var t := _bilerp(_clim_t, k00, w, tx, ty)
		var m := _bilerp(_clim_m, k00, w, tx, ty)
		var e := _bilerp(_clim_e, k00, w, tx, ty)
		var wd := _bilerp(_clim_wd, k00, w, tx, ty)
		s.coast_km = _bilerp(_clim_coast, k00, w, tx, ty)
		s.rock = _clim_rock[k00]
		var water_m := minf(wd, river_m)
		if s.depth > -1.0:
			water_m = minf(water_m, maxf(-s.depth, 0.0) * 10.0)
		s.water_m = water_m
		s.t = t + (e - s.h) * PlanetConst.LAPSE_RATE_C_PER_M + ASPECT_C * aspect
		s.m = clampf(m + WATER_BOOST * exp(-water_m / WATER_BOOST_M) - ASPECT_MOISTURE * aspect, 0.0, 1.0)
		s.hot = CubeSphere.surface_distance_m(s.dir, _hot_center) < _hot_r * 0.45

	static func _bilerp(arr, k00: int, w: int, tx: float, ty: float) -> float:
		return lerpf(lerpf(arr[k00], arr[k00 + 1], tx), lerpf(arr[k00 + w], arr[k00 + w + 1], tx), ty)

	## Species weight at a site: climate bands x soil x needs x dominance.
	func weight(sp: PlantSpecies, s: _Site) -> float:
		var w := sp.suitability(s.t, s.m, s.h, s.rock)
		if w <= 0.0:
			return 0.0
		var in_water := s.depth > 0.05
		if sp.has_need(PlantSpecies.Needs.STANDING_WATER):
			if not in_water or s.depth < sp.water_depth_m.x or s.depth > sp.water_depth_m.y:
				return 0.0
		elif s.depth > -WATERLINE_M:
			# Ground at or barely above the water: the drawn water (flat
			# quads, waves) covers it, so a plant there stands in the sea.
			return 0.0
		# Beach sand (the band TerrainChunk colors as sand): salt-tolerant
		# plants only.
		if s.h < 3.0 and s.coast_km < 1.5 and smoothstep(3.0, 0.8, s.h) > 0.35 \
				and not sp.has_need(PlantSpecies.Needs.SALT_WATER):
			return 0.0
		if sp.has_need(PlantSpecies.Needs.SALT_WATER):
			if sp.has_need(PlantSpecies.Needs.STANDING_WATER):
				if not s.salt:
					return 0.0
			else:
				w *= 1.0 - smoothstep(0.3, 1.0, s.coast_km)
		if sp.has_need(PlantSpecies.Needs.RIVER_BANK):
			w *= 1.0 - smoothstep(25.0, 70.0, s.water_m)
		if sp.has_need(PlantSpecies.Needs.HOT_GROUND) and not s.hot:
			return 0.0
		return w * dominance.get(sp, 1.0)

	func add_emergent(d: Vector3) -> void:
		_emergents.append(d)

	func near_emergent(d: Vector3) -> bool:
		var limit := cos(4.0 / PlanetConst.RADIUS_M)
		for e in _emergents:
			if e.dot(d) > limit:
				return true
		return false


class _Site:
	var dir: Vector3
	var h: float
	var t: float # °C at this exact spot
	var m: float
	var rock: int
	var depth: float # standing water depth (negative = above water)
	var salt: bool
	var water_m: float # distance to nearest water
	var coast_km: float
	var hot: bool
