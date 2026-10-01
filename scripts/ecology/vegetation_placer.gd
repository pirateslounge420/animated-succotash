class_name VegetationPlacer
## Places plants on one terrain chunk (DESIGN.md "Vegetation"). A species
## grows only in a biome that lists it (design 1 Oct §CA, data/habitat.json:
## a biome file's plants and associations, or a catalogue entry's own
## `biomes`), and within those biomes wherever its climate, soil, altitude,
## needs and realm fit: the biome is a gate on top, co-equal with soil.
## (Until 1 Oct plants read climate alone, never biome names, so a
## floodplain-forest magnolia grew on a savanna riverbank.)
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
##                 (standing water, river bank, salt, hot ground, dry
##                 ground: never in a wetland biome or by the water; forest
##                 floor: only in a forest biome).
##   biome gate  - the cell's biome must list the species (sp.biomes;
##                 habitat.json biome_gate; ecotone_m lets a neighbouring
##                 biome's species cross the line that far, 0: hard
##                 borders).
##   realm       - a catalogue species tagged with realms grows only where
##                 the site's realm (RealmMap) is one of them and the site's
##                 biome has an association for it (design §AA).
##   dominance   - a slow noise field per species boosts a local favourite:
##                 one valley mostly spruce with some fir, the next flipped.
##   clumping    - a patch-scale noise mask, so plants grow in patches.
##   clearings   - nothing grows on mythical folk campsites or inside ruins.
##   shade       - ground cover thins under heavy canopy.
## Then per plant: size and lean jitter. Epiphytes attach to trees already
## placed; cypress knees scatter around cypress standing in water.
##
## Growth (design §AR, PlantGrowth): the stand's young cohort are young
## trees (saplings and poles, drawn in their species' young form), the
## floor under and between the trees carries the canopy species' own
## seedlings and saplings (_place_young(): as many as the light lets live),
## and every plant's light from the crowns above it (_Light) sets its leaf
## size (shade leaves larger) in the MultiMesh custom data's green.
##
## Both compute functions are thread-safe (read-only planet data);
## build_nodes() makes one MultiMesh per species on the main thread, and
## for branchy canopy trees one more per layout (TreeLayouts): each tree
## grows the layout its position hashes to, so trees stay batched.

## Plants other than water plants keep this far above standing water.
const WATERLINE_M := 0.3
## Wetland biomes (BiomeTemplates ids): dry_ground plants never grow in
## them, nor within DRY_GROUND_M of water.
static var WETLANDS := PackedInt32Array(["SWAMP", "FRESHWATER_MARSH", "SALT_MARSH", "BOG", "FEN", "WET_MEADOW", "MANGROVE", "ESTUARY"].map(func(k): return BiomeTemplates.id_of_key(k)))
const DRY_GROUND_M := 8.0
## Forest biomes: where forest_floor plants grow (their floor and gaps).
static var FORESTS := PackedInt32Array(["TROPICAL_RAINFOREST", "JUNGLE", "TROPICAL_DRY_FOREST", "CLOUD_FOREST", "TEMPERATE_DECIDUOUS",
	"TEMPERATE_RAINFOREST", "FLOODPLAIN_FOREST", "MARITIME_FOREST", "TAIGA"].map(func(k): return BiomeTemplates.id_of_key(k)))
## Species of one catalogue genus a chunk can hold at once (the local
## assemblage, _Context._local_assemblage).
const GENUS_LOCAL := 4
## The biome gate's knobs (data/habitat.json, design §CA).
static var HAB: Dictionary = Tuning.table("habitat")
static var BIOME_GATE: bool = bool(HAB.get("biome_gate", true))
static var ECOTONE_M: float = float(HAB.get("ecotone_m", 0.0))
## How far ground cover is drawn (data/look.json "ranges", design §W).
static var RANGES := Tuning.section("look", "ranges")
const T := PlantSpecies.Tier
## How much larger than their species' listed heights plants grow, per
## tier (emergent, canopy, shrub, ground, epiphyte): stand.json size_scale.
## Trees are 1.0 since 1 Oct (Mike: a species at its natural size; the
## 1.3x of the "epic woods" pass put 45 m she-oaks at the first camp);
## the old-growth roll (stand.json) still puts most near the top of their
## band and the giant roll makes the odd true giant. Spacing widens with
## the scale (about with the square root).
static var SIZE_SCALE: Dictionary = _size_scale()
## Herbs whose leaves are the plant: they spread them wider in the shade
## (prepare(); PlantGrowth.leaf_scale).
const HERB_SPREAD := [PlantSpecies.Shape.FERN, PlantSpecies.Shape.ROSETTE, PlantSpecies.Shape.EPIPHYTE_CLUMP,
	PlantSpecies.Shape.UMBRELLA, PlantSpecies.Shape.TREE_FERN, PlantSpecies.Shape.PALM]
const GIANT_CHANCE := 0.15
const GIANT_SCALE := 1.25
## The stand's age (data/stand.json): the tribal planet is old growth, so
## trees roll near the top of their species' band, with giants and a thin
## young cohort in the gaps (_roll_height()).
static var STAND := Tuning.table("stand")


static func _size_scale() -> Dictionary:
	var d: Dictionary = STAND.get("size_scale", {})
	var out := {0: 1.0, 1: 1.0, 2: 1.2, 3: 1.2, 4: 1.2}
	for k in ["emergent", "canopy", "shrub", "ground", "epiphyte"]:
		if d.has(k):
			out[["emergent", "canopy", "shrub", "ground", "epiphyte"].find(k)] = float(d[k])
	return out
## Stand dominance (design 30 Sept §BH, stand.json "dominance"): each
## stand (a cell stand_m across) picks one dominant species per tier and
## weights it hard, 1-3 associates, a rare accent; the species salad only
## in salad_biomes. The understory tiers follow with their own dominant in
## the same stand cell.
static var DOM: Dictionary = STAND.get("dominance", {})
## The world clock as the placer sees it (main sets it: burn scars age).
static var NOW_DAYS := 0.0
## The trail's strip (roads.json trail): understory kept clear this far
## either side of the tread, a tree within tree_at_bend_m of each bend.
static var ROAD_TRAIL: Dictionary = Tuning.section("roads", "trail")
static var SALAD := PackedInt32Array(Array(DOM.get("salad_biomes", [])).map(func(k): return BiomeTemplates.id_of_key(str(k))))
const SPACING_M := {0: 34.0, 1: 8.2, 2: 4.9, 3: 3.8}
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
const STRIDE := 12 # dir.xyz, radius, yaw, lean_x, lean_z, height, moss, vines, bare, stage
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
	RealmMap.warm(world_seed)
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
	_place_road_trees(ctx, plants, hosts)
	# Each tree's light from the crowns over it: its leaf size.
	_light_pass(plants, _Light.new(data.center, hosts), true)
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
	# The stand's own young on the floor (after the rest, so they don't
	# move it), then everything's light under the crowns: leaf size.
	var light := _Light.new(data.center, hosts)
	_place_young(ctx, plants, light)
	_light_pass(plants, light, false)
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
			# The roads (design 30 Sept §BC): the tread and a strip either
			# side kept clear of the understory, the trees off the tread;
			# the rooms (§BB): the understory thinned on a room's floor,
			# thickened along its edge and a corridor's sides.
			var fill_scale := 1.0
			var gap := ctx.road_gap(site.dir)
			if gap < INF:
				var half := ctx.road_width(site.dir) * 0.5
				var clear := half + (float(ROAD_TRAIL.get("understory_clear_m", 1.0)) if tier >= T.SHRUB else 1.5)
				if gap < clear:
					continue
				if tier == T.SHRUB:
					fill_scale = RoadNetwork.wall_scale(ctx._rooms, gap, clear, site.dir)
			elif tier == T.SHRUB and not ctx._rooms.is_empty():
				fill_scale = RoadNetwork.wall_scale(ctx._rooms, INF, 0.0, site.dir)
			if tier == T.GROUND and not ctx._rooms.is_empty():
				fill_scale = minf(RoadNetwork.wall_scale(ctx._rooms, INF, 0.0, site.dir), 1.0)
			# Most cells come to nothing, so decide that cheaply first: is
			# anything viable here at all (the chance is only drawn then), and
			# does the draw beat the best chance the cell could have (the
			# same product with min(total, 1) at its largest, 1, multiplied
			# in the same order, so it can't round below the real one)?
			# Only then weigh every species. Same draws, same plants.
			var viable := false
			for k in candidates.size():
				if ctx.weight(candidates[k], site) > 0.0:
					viable = true
					break
			if not viable:
				continue
			var clump := ctx.clump_at(tier, gx, gy)
			var shade_f := 1.0
			if tier == T.GROUND:
				shade_f = 1.0 - 0.7 * clampf(ctx.shade_at(gx, gy), 0.0, 1.0)
			# A burn scar (design 30 Sept §BL wildfire, CampSim.scars): the
			# first season nothing stands in the understory and the ground
			# tier blooms with fire-followers; trees stand dead (bare) for
			# as long as the scar lasts. A fertility mark (§BQ black earth,
			# a midden) grows the understory thicker (SoilMarks).
			var scar := CampSim.scar_at(site.dir, VegetationPlacer.NOW_DAYS) if not CampSim.scars.is_empty() else 0.0
			if scar > 0.0:
				if tier == T.SHRUB and scar > 0.5:
					continue
				if tier == T.GROUND:
					fill_scale *= 1.0 + 1.5 * scar
			var fert := SoilMarks.fertility_at(site.dir)
			if fert > 1.0 and tier >= T.SHRUB:
				fill_scale *= fert
			var p_max := clump * 1.0 * float(FILL[tier]) * fill_scale
			if tier == T.GROUND:
				p_max *= shade_f
			var roll := ctx.rng.randf()
			if roll >= p_max:
				continue
			var total := 0.0
			for k in candidates.size():
				var w := ctx.weight(candidates[k], site)
				weights[k] = w
				total += w
			var p := clump * minf(total, 1.0) * float(FILL[tier]) * fill_scale
			if tier == T.GROUND:
				p *= shade_f
			if roll >= p:
				continue
			var pick := ctx.rng.randf() * total
			var chosen := candidates.size() - 1
			for k in candidates.size():
				pick -= weights[k]
				if pick <= 0.0:
					chosen = k
					break
			var sp: PlantSpecies = candidates[chosen]
			var rolled := _roll_tree(ctx.rng, sp, tier)
			var height: float = float(rolled[0]) * float(SIZE_SCALE[tier])
			var burnt := scar > 0.0 and (tier == T.EMERGENT or tier == T.CANOPY)
			var stage: int = PlantGrowth.Stage.MATURE
			if rolled[1] and not sp.growth.is_empty():
				# The young cohort: saplings and young trees in their own form
				# (PlantGrowth.young_tree), heading for a height in the top of
				# the band.
				var h_full := lerpf(sp.height_m.x, sp.height_m.y, lerpf(0.7, 1.0, PlantGenetics.unit(hash([sp.name, site.dir]), 1))) * float(SIZE_SCALE[tier])
				var yt := PlantGrowth.young_tree(sp, site.dir, h_full)
				height = maxf(float(yt[0]), 0.3)
				stage = int(yt[1])
			var sp_idx := SpeciesDB.index_of(sp)
			# Wet sites mossy, wet and warm ones hung with vines (0-1 each,
			# per plant; the foliage shader shows them).
			var moss := smoothstep(0.45, 0.85, site.m)
			var vines := smoothstep(0.62, 0.92, site.m) * smoothstep(4.0, 16.0, site.t)
			# How much leaf a tree carries (its growth, how dry its site is):
			# the foliage shader thins its leaf clusters by it.
			var leaf := 1.0
			if tier == T.EMERGENT or tier == T.CANOPY:
				var growth := PlantMeshes.stand_in_growth(sp, height / float(SIZE_SCALE[tier]))
				# Living trees keep a little leaf; bare 1 means dead.
				leaf = maxf(PlantMeshes.leaf_amount(growth, site.m), 0.05)
				# Dead wood (data/dead_wood.json): a share of trees stand dead,
				# more in beetle-killed taiga, badlands and swamp margins; dry
				# culms among the bamboo. From the spot, so the rest of the
				# placement doesn't shift.
				if DeadWood.is_dead(ctx.map, site.dir, sp):
					leaf = 0.0
					vines *= 0.3
				# A burn scar: the trees stand dead (bare) while it lasts.
				if burnt:
					leaf = 0.0
					vines *= 0.2
			var lean := _lean(ctx, sp, site.dir) if TreeArch.grows(sp) else Vector2.INF
			_emit(out, sp_idx, site.dir, PlanetConst.RADIUS_M + site.h, ctx.rng, height, 0.09, moss, vines, 1.0 - leaf, lean, stage)
			if tier == T.EMERGENT or tier == T.CANOPY:
				hosts.append([site.dir, PlanetConst.RADIUS_M + site.h, height, sp_idx, site.depth, leaf, stage])
				if tier == T.EMERGENT:
					ctx.add_emergent(site.dir)


## A tree's height (m, before the tier's size scale) from its species'
## band, by the stand's age (data/stand.json), and whether it's of the
## young cohort: [height, young]. Old growth: most trees in the top of the
## band, a scatter of giants among the emergents, a thin young cohort in
## the gaps (_place_tier grows those as young trees); "even": the old roll,
## slightly favouring the small end. Shrubs and ground cover take
## shrub_pow instead. (The same draws as ever: the rest of the placement
## doesn't move.)
static func _roll_tree(rng: RandomNumberGenerator, sp: PlantSpecies, tier: int) -> Array:
	var t: float
	var young := false
	var giant_chance := GIANT_CHANCE
	var giant_scale := GIANT_SCALE
	if str(STAND.get("mode", "old_growth")) == "old_growth" and (tier == T.EMERGENT or tier == T.CANOPY):
		if rng.randf() < float(STAND.get("old_share", 0.82)):
			t = lerpf(float(STAND.get("old_min", 0.7)), 1.0, 1.0 - pow(rng.randf(), 1.0 / maxf(float(STAND.get("old_pow", 0.55)), 0.05)))
		else:
			t = rng.randf_range(float(STAND.get("young_min", 0.2)), float(STAND.get("young_max", 0.55)))
			young = true
		giant_chance = float(STAND.get("giant_chance", giant_chance))
		giant_scale = float(STAND.get("giant_scale", giant_scale))
	elif tier == T.EMERGENT or tier == T.CANOPY:
		t = pow(rng.randf(), 0.8)
	else:
		t = pow(rng.randf(), float(STAND.get("shrub_pow", 1.0)))
	var height := lerpf(sp.height_m.x, sp.height_m.y, t)
	if tier == T.EMERGENT and rng.randf() < giant_chance:
		height *= giant_scale
		young = false
	return [height, young]


static func _emit(out: Dictionary, sp_idx: int, d: Vector3, radius: float, rng: RandomNumberGenerator, height: float,
		lean_max := 0.09, moss := 0.0, vines := 0.0, bare := 0.0, lean := Vector2.INF, stage: int = PlantGrowth.Stage.MATURE) -> void:
	if not out.has(sp_idx):
		out[sp_idx] = PackedFloat32Array()
	var arr: PackedFloat32Array = out[sp_idx]
	var yaw := rng.randf() * TAU
	if lean == Vector2.INF:
		lean = Vector2(rng.randf_range(-lean_max, lean_max), rng.randf_range(-lean_max, lean_max))
	arr.append_array([d.x, d.y, d.z, radius, yaw, lean.x, lean.y, height, moss, vines, bare, float(stage)])
	out[sp_idx] = arr


## A tree's lean (design §AK 1): up to its architecture's lean_max_deg,
## toward downhill (the ground's fall over ~60 m) and downwind (the
## place's prevailing wind), with a random share: the (fwd x up, fwd)
## tangent components prepare() tilts by.
static func _lean(ctx: _Context, sp: PlantSpecies, d: Vector3) -> Vector2:
	var fwd := d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD).normalized()
	var side := fwd.cross(d)
	var e := CubeSphere.east(d)
	var n := CubeSphere.north(d)
	var step := 60.0 / PlanetConst.RADIUS_M
	var h0 := ctx.map.sample(ctx.map.elevation, d)
	var he := ctx.map.sample(ctx.map.elevation, (d + e * step).normalized()) - h0
	var hn := ctx.map.sample(ctx.map.elevation, (d + n * step).normalized()) - h0
	var down := -(e * he + n * hn) / 60.0
	var wind: Vector3 = ctx.map.wind_avg[ctx.map.cell_at(d)] if ctx.map.wind_avg.size() > 0 else Vector3.ZERO
	var toward := down.normalized() * clampf(down.length() * 4.0, 0.0, 1.0) \
		+ wind.normalized() * clampf(wind.length() / 8.0, 0.0, 1.0) \
		+ (side * ctx.rng.randf_range(-1.0, 1.0) + fwd * ctx.rng.randf_range(-1.0, 1.0)) * 0.6
	toward -= d * toward.dot(d)
	if toward.length() < 1e-4:
		return Vector2.ZERO
	var amount := deg_to_rad(float(sp.arch.get("lean_max_deg", 8.0))) * ctx.rng.randf_range(0.15, 1.0)
	toward = toward.normalized() * amount
	return Vector2(toward.dot(side), toward.dot(fwd))


## The road's own trees (design 30 Sept §BC): a canopy tree of the
## stand's dominant within tree_at_bend_m of each bend, on the outside
## of the turn, and the lone old tree of an off-road find: a giant of
## the emergent (else canopy) dominant.
static func _place_road_trees(ctx: _Context, out: Dictionary, hosts: Array) -> void:
	for i in ctx._road_bends.size():
		var b := ctx._road_bends[i]
		var list := ctx.species_for(T.CANOPY)
		if list.is_empty():
			continue
		var sp := _dominant_of(ctx, list)
		var side := 1.0 if PlantGenetics.unit(hash([b, "bend"]), 1) < 0.5 else -1.0
		var d := CreatureSpawner._offset(b, PlantGenetics.unit(hash([b, "bend"]), 2) * TAU, ctx.road_width(b) * 0.5 + float(ROAD_TRAIL.get("tree_at_bend_m", 3.0)) * 0.8)
		if ctx.in_clearing(d) or _crowded(d, hosts):
			continue
		var site := ctx.site_at(d)
		if ctx.weight(sp, site) <= 0.0:
			continue
		var h := lerpf(sp.height_m.x, sp.height_m.y, 0.85) * float(SIZE_SCALE[T.CANOPY])
		_emit(out, SpeciesDB.index_of(sp), d, PlanetConst.RADIUS_M + site.h, ctx.rng, h, 0.05 * side)
		hosts.append([d, h * 0.04, h, SpeciesDB.index_of(sp), 0.0])
	for i in ctx._old_trees.size():
		var d := ctx._old_trees[i]
		var list := ctx.species_for(T.EMERGENT)
		var tier := T.EMERGENT
		if list.is_empty():
			list = ctx.species_for(T.CANOPY)
			tier = T.CANOPY
		if list.is_empty() or ctx.in_clearing(d):
			continue
		var sp := _dominant_of(ctx, list)
		var site := ctx.site_at(d)
		if ctx.weight(sp, site) <= 0.0:
			continue
		var h := sp.height_m.y * float(SIZE_SCALE[tier]) * float(STAND.get("giant_scale", 1.3))
		_emit(out, SpeciesDB.index_of(sp), d, PlanetConst.RADIUS_M + site.h, ctx.rng, h, 0.03)
		hosts.append([d, h * 0.045, h, SpeciesDB.index_of(sp), 0.0])
		ctx.add_emergent(d)


## The stand's dominant among `list`: the species with the largest
## dominance factor here (_apply_dominance).
static func _dominant_of(ctx: _Context, list: Array[PlantSpecies]) -> PlantSpecies:
	var best: PlantSpecies = list[0]
	for sp in list:
		if float(ctx.dominance.get(sp, 1.0)) > float(ctx.dominance.get(best, 1.0)):
			best = sp
	return best


## In a stand: at least two other trees within 9 m (design §AK 2: forest-
## grown), else a lone, open-grown tree.
static func _any_biome(wanted: PackedInt32Array, here: PackedInt32Array) -> bool:
	for b in here:
		if wanted.has(b):
			return true
	return false


static func _crowded(d: Vector3, hosts: Array) -> bool:
	var near := 0
	var lim := 9.0 / PlanetConst.RADIUS_M
	for h in hosts:
		var hd: Vector3 = h[0]
		var dd := (hd - d).length()
		if dd > 1e-7 and dd < lim:
			near += 1
			if near >= 2:
				return true
	return false


## Epiphytes hang from or cling to hosts already placed.
static func _place_epiphytes(ctx: _Context, out: Dictionary, hosts: Array) -> void:
	var epis := ctx.species_for(T.EPIPHYTE)
	if epis.is_empty():
		return
	for host in hosts:
		# Young trees (saplings, poles) don't carry epiphytes yet.
		if host.size() > 6 and int(host[6]) < PlantGrowth.Stage.MATURE:
			continue
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
				var size := lerpf(sp.height_m.x, sp.height_m.y, pow(ctx.rng.randf(), float(STAND.get("shrub_pow", 1.0)))) * float(SIZE_SCALE[4])
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


## The forest's young (design §AR): seedlings and saplings of the stand's
## own species on the floor under and between its trees, as many as the
## light lets live: a shade-tolerant fir's seedling bank under a closed
## canopy, a pine's saplings only in the gaps. A spot every YOUNG_SPACING_M
## (jittered), in a stand (a tree within YOUNG_NEAR_M), takes one of the
## chunk's tree species by how well it grows there and how well its young
## come up in that light (PlantGrowth.establish); what stands there now
## is the spot's run of occupants at this hour of the world clock
## (PlantGrowth.understory: dying young in the shade, or growing up out of
## the understory). Drawn by stage (PlantGrowth.JUV_KEY): a seedling, or a
## sapling in its species' young form, open- or forest-grown by its light.
const YOUNG_SPACING_M := 3.6
const YOUNG_FILL := 0.6
const YOUNG_NEAR_M := 22.0
## YOUNG=0 in the environment leaves the understory young out (A/B, timing).
static var YOUNG := OS.get_environment("YOUNG") != "0"


static func _place_young(ctx: _Context, out: Dictionary, light: _Light) -> void:
	if not light.any or not YOUNG:
		return
	var candidates: Array[PlantSpecies] = []
	for tier in [T.EMERGENT, T.CANOPY]:
		for sp in ctx.species_for(tier):
			if not sp.growth.is_empty() and not sp.growth.has("stages") and sp.juvenile != "none":
				candidates.append(sp)
	if candidates.is_empty():
		return
	var cells := maxi(1, int(ctx.chunk_m / YOUNG_SPACING_M))
	var weights := PackedFloat32Array()
	weights.resize(candidates.size())
	for b in cells:
		for a in cells:
			var key := hash([ctx.key, a, b, "young"])
			var gx := (a + 0.5 + (PlantGenetics.unit(key, 1) - 0.5) * 0.7) / cells * TerrainChunk.QUADS
			var gy := (b + 0.5 + (PlantGenetics.unit(key, 2) - 0.5) * 0.7) / cells * TerrainChunk.QUADS
			# The spot's fill roll first: most spots stay empty whatever
			# grows round them (the full test below is stricter), so they
			# cost no site or weights.
			var clump := ctx.clump_at(T.SHRUB, gx, gy)
			var roll := PlantGenetics.unit(key, 3)
			if roll >= YOUNG_FILL * clump:
				continue
			var site := ctx.site(gx, gy)
			if ctx.in_clearing(site.dir) or not light.near(site.dir, YOUNG_NEAR_M):
				continue
			var gap := ctx.road_gap(site.dir)
			if gap < ctx.road_width(site.dir) * 0.5 + float(ROAD_TRAIL.get("understory_clear_m", 1.0)):
				continue
			var lit := light.at(site.dir, 0.5)
			var total := 0.0
			for k in candidates.size():
				var w := ctx.weight(candidates[k], site)
				if w > 0.0:
					w *= PlantGrowth.establish(candidates[k], lit)
				weights[k] = w
				total += w
			if total <= 0.0 or roll >= minf(total, 1.0) * YOUNG_FILL * clump:
				continue
			var pick := PlantGenetics.unit(key, 4) * total
			var chosen := candidates.size() - 1
			for k in candidates.size():
				pick -= weights[k]
				if pick <= 0.0:
					chosen = k
					break
			var sp: PlantSpecies = candidates[chosen]
			var tier: int = sp.tier
			var h_full := lerpf(sp.height_m.x, sp.height_m.y, lerpf(0.7, 1.0, PlantGenetics.unit(key, 5))) * float(SIZE_SCALE[tier])
			var now := PlantGrowth.understory(sp, key, lit, h_full)
			if now.is_empty():
				continue
			var stage: int = now[1]
			var code := PlantGrowth.young_code(stage, lit > 0.5)
			if code <= 0:
				continue
			var h := maxf(float(now[0]), 0.05)
			_emit(out, SpeciesDB.index_of(sp) + PlantGrowth.JUV_KEY * code, site.dir, PlanetConst.RADIUS_M + site.h, ctx.rng, h,
				0.06, smoothstep(0.45, 0.85, site.m) * 0.5, 0.0, 0.0, Vector2.INF, stage)


## Each plant's light from the crowns above it (`light`: the chunk's trees)
## sets its leaf size (PlantGrowth.leaf_scale: shade leaves bigger), packed
## with its vines into the record (the custom data's green). Trees
## (`trees`) are lit at the middle of their crowns, by crowns whose
## underside is above that (an emergent over a canopy tree, the canopy over
## a young tree); everything else at its top.
static func _light_pass(out: Dictionary, light: _Light, trees: bool) -> void:
	var all := SpeciesDB.all()
	for key in out:
		var sp: PlantSpecies = all[int(key) % PlantGrowth.JUV_KEY]
		var arr: PackedFloat32Array = out[key]
		for i in arr.size() / STRIDE:
			var o := i * STRIDE
			var d := Vector3(arr[o], arr[o + 1], arr[o + 2])
			var h: float = arr[o + 7]
			var at_m := h * 0.7 if trees else h
			var lit := light.at(d, at_m) if light.any else 1.0
			arr[o + 9] = PlantGrowth.encode_green(arr[o + 9], PlantGrowth.leaf_code(PlantGrowth.leaf_scale(sp, lit)))
		out[key] = arr


## The chunk's tree crowns, for the light under them (_light_pass,
## _place_young): each tree's crown a disc (its shape's crown radius,
## PlantMeshes.tree_dims) at the height its crown starts, letting through
## its canopy gap (and more on a bare tree), binned on a CELL_M grid in the
## chunk's tangent plane.
class _Light:
	const CELL_M := 16.0
	var cells := {}
	var any := false
	var _c: Vector3
	var _e: Vector3
	var _n: Vector3

	func _init(center: Vector3, hosts: Array) -> void:
		_c = center
		_e = CubeSphere.east(center)
		_n = CubeSphere.north(center)
		var all := SpeciesDB.all()
		for hst in hosts:
			var sp: PlantSpecies = all[int(hst[3])]
			var dims := PlantMeshes.tree_dims(sp.shape)
			if dims.z <= 0.0:
				continue
			var ht := float(hst[2])
			var leaf := float(hst[5]) if hst.size() > 5 else 1.0
			var op := clampf((1.0 - float(sp.canopy.get("gap", 0.3))) * leaf, 0.0, 0.92)
			if op <= 0.02:
				continue
			var p := xy(hst[0])
			var k := Vector2i(floori(p.x / CELL_M), floori(p.y / CELL_M))
			if not cells.has(k):
				cells[k] = []
			(cells[k] as Array).append([p.x, p.y, maxf(ht * dims.z, 0.8), ht * dims.w, op])
			any = true

	func xy(d: Vector3) -> Vector2:
		var off := (d - _c) * PlanetConst.RADIUS_M
		return Vector2(off.dot(_e), off.dot(_n))

	## The light (0-1) reaching leaves `at_m` above the ground at `d`: each
	## crown over them adds its optical depth (its opacity, full out to
	## 55 % of its radius, fading to nothing a little past its edge), and
	## the light falls as e^(-1.6 x depth): under one crown about a third
	## gets through, under two a tenth, under a closed canopy's three or
	## four a few percent (a forest floor's 1-5 % of full sun).
	func at(d: Vector3, at_m: float) -> float:
		var p := xy(d)
		var cx := floori(p.x / CELL_M)
		var cy := floori(p.y / CELL_M)
		var depth := 0.0
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var list = cells.get(Vector2i(cx + ox, cy + oy))
				if list == null:
					continue
				for rec in list:
					if float(rec[3]) <= at_m:
						continue
					var dist := Vector2(p.x - float(rec[0]), p.y - float(rec[1])).length()
					var r: float = rec[2]
					if dist >= r * 1.15 or dist < 0.05:
						continue
					depth += float(rec[4]) * (1.0 - smoothstep(r * 0.55, r * 1.15, dist))
		return exp(-1.6 * depth)

	## A tree trunk within `m` of `d`?
	func near(d: Vector3, m: float) -> bool:
		var p := xy(d)
		var cx := floori(p.x / CELL_M)
		var cy := floori(p.y / CELL_M)
		var reach := int(ceil(m / CELL_M))
		for oy in range(-reach, reach + 1):
			for ox in range(-reach, reach + 1):
				var list = cells.get(Vector2i(cx + ox, cy + oy))
				if list == null:
					continue
				for rec in list:
					if Vector2(p.x - float(rec[0]), p.y - float(rec[1])).length() < m:
						return true
		return false


## Worker thread: turn compute_base/compute_detail output into ready
## MultiMesh buffers. Positions are relative to the chunk's anchor (its
## center at `anchor_r` from the planet center), which doesn't depend on
## the floating origin, so the whole buffer is built here and the main
## thread only hands it over. Returns sp_idx -> [buffer, count, trees,
## layouts]: trees being [local_position, height, instance, pick,
## layout_instance, rotation, order] of canopy and emergent plants, and
## layouts, for branchy species, layout -> [buffer, count]: the same trees
## again, split by the layout each grows and mirrored when its pick says
## so (TreeLayouts.pick), drawn instead in the detail ring. `rotation` is
## the tree's rigid rotation (radial up, yaw, lean; no scale).
##
## For the trees (compute_base's output) pass `hosts`, the chunk `key` and
## the world seed: the seed, key and each tree's surface direction pick
## its layout, and `order` is its index in `hosts` (placement order).
static func prepare(plants: Dictionary, center: Vector3, anchor_r: float, hosts := [],
		key := Vector3i.ZERO, world_seed := 0) -> Dictionary:
	var out := {}
	var all := SpeciesDB.all()
	var cx := center.x * anchor_r
	var cy := center.y * anchor_r
	var cz := center.z * anchor_r
	# The k-th tree of a species is that species' k-th host.
	var order := {} # sp_idx -> host indices, in order
	for hi in hosts.size():
		var s: int = hosts[hi][3]
		if not order.has(s):
			order[s] = []
		(order[s] as Array).append(hi)
	for pkey in plants:
		# Understory young come keyed by stage too (PlantGrowth.JUV_KEY).
		var sp_idx: int = int(pkey) % PlantGrowth.JUV_KEY
		var young_code: int = int(pkey) / PlantGrowth.JUV_KEY
		var sp: PlantSpecies = all[sp_idx]
		var arr: PackedFloat32Array = plants[pkey]
		var count := arr.size() / STRIDE
		var buf := PackedFloat32Array()
		buf.resize(count * MM_STRIDE)
		var trees: Array = []
		var tall := (sp.tier == T.EMERGENT or sp.tier == T.CANOPY) and young_code == 0
		var branchy := tall and TreeLayouts.branchy(sp)
		var ords: Array = order.get(sp_idx, [])
		var spread_ok := sp.shape in HERB_SPREAD and (sp.tier == T.GROUND or sp.tier == T.SHRUB or sp.tier == T.EPIPHYTE)
		for i in count:
			var o := i * STRIDE
			var d := Vector3(arr[o], arr[o + 1], arr[o + 2])
			var r: float = arr[o + 3]
			var pos := Vector3(d.x * r - cx, d.y * r - cy, d.z * r - cz)
			var up := d
			var fwd := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
			var basis := Basis(fwd.cross(up), up, fwd).orthonormalized()
			basis = basis.rotated(up, arr[o + 4])
			# The lean: a tilt (radians) toward the tangent vector
			# (lean_x along fwd x up, lean_z along fwd), so it can point
			# downhill or downwind (_lean()).
			var lean := fwd.cross(up) * arr[o + 5] + fwd * arr[o + 6]
			if lean.length() > 1e-5:
				basis = Basis(up.cross(lean).normalized(), lean.length()) * basis
			var rot := basis
			# A rare sport (PlantGenetics, data/sports.json): its size now,
			# its kind packed in with the moss for the shader and the HUD.
			var sport := PlantGenetics.sport_at(sp, d)
			var h: float = arr[o + 7] * PlantGenetics.size_of(sport)
			var moss_s := PlantGenetics.encode_moss(arr[o + 8], sport)
			# Herbs with big leaves spread them wider in the shade (their
			# leaves are the plant: PlantGrowth.leaf_scale); a sapling is
			# mirrored now and then (one layout per species here).
			var sx := h * (pow(PlantGrowth.leaf_of(arr[o + 9]), 0.8) if spread_ok else 1.0)
			if young_code >= 2 and PlantGenetics.unit(hash([sp_idx, d]), 7) < 0.5:
				sx = -sx
			basis = basis * Basis.from_scale(Vector3(sx, h, absf(sx)))
			_put(buf, i * MM_STRIDE, basis, pos, moss_s, arr[o + 9], arr[o + 10])
			if tall:
				var pick := TreeLayouts.pick(world_seed, key, d, _crowded(d, hosts), TreeArch.grows(sp)) if branchy else -1
				# A young tree grows a young layout (TreeLayouts: its stage's
				# slot), drawn and climbed in its young form.
				if pick >= 0:
					pick = TreeLayouts.with_slot(pick, TreeLayouts.slot_of(int(arr[o + 11])))
				trees.append([pos, h, i, pick, -1, rot, ords[i] if i < ords.size() else -1, moss_s])
		var layouts := {}
		if branchy:
			var counts := PackedInt32Array()
			counts.resize(TreeLayouts.ALL)
			for t in trees:
				var l := TreeLayouts.layout_of(t[3])
				t[4] = counts[l]
				counts[l] += 1
			for l in TreeLayouts.ALL:
				if counts[l] == 0:
					continue
				var lbuf := PackedFloat32Array()
				lbuf.resize(counts[l] * MM_STRIDE)
				for t in trees:
					if TreeLayouts.layout_of(t[3]) != l:
						continue
					var h: float = t[1]
					var mirror := -h if TreeLayouts.is_mirrored(t[3]) else h
					var o: int = int(t[2]) * STRIDE
					_put(lbuf, int(t[4]) * MM_STRIDE, (t[5] as Basis) * Basis.from_scale(Vector3(mirror, h, h)), t[0],
						float(t[7]), arr[o + 9], arr[o + 10])
				layouts[l] = [lbuf, counts[l]]
		out[pkey] = [buf, count, trees, layouts]
	return out


## One instance into a MultiMesh buffer at float `k`: the transform as the
## rows of its 3x4 matrix, then color (white), then custom data (moss,
## vines, rustle 0, bare): Godot's MultiMesh layout.
static func _put(buf: PackedFloat32Array, k: int, basis: Basis, pos: Vector3, moss: float, vines: float, bare := 0.0) -> void:
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
	buf[k + 16] = moss
	buf[k + 17] = vines
	buf[k + 19] = bare


## Main thread: one MultiMeshInstance3D per species under `parent`, from
## prepare()'s buffers; for a branchy species that one draws its trees
## only beyond the detail ring, and one more per layout draws them in it
## (TerrainChunk.set_fine shows one set or the other). Records the trees
## on the chunk, in placement order (chunk.trees[i] is chunk.hosts[i]),
## for climbing, rustling, branch graphs and canopy-dwelling creatures.
static func build_nodes(parent: Node3D, chunk: TerrainChunk, prepared: Dictionary) -> void:
	var all := SpeciesDB.all()
	var own := parent == chunk
	# Each at the chunk's current detail level; the chunk swaps meshes as
	# the player comes and goes (TerrainChunk.set_fine).
	var lod := chunk.plant_lod(parent)
	var placed: Array = []
	for pkey in prepared:
		var sp_idx: int = int(pkey) % PlantGrowth.JUV_KEY
		var young_code: int = int(pkey) / PlantGrowth.JUV_KEY
		var sp: PlantSpecies = all[sp_idx]
		var entry: Array = prepared[pkey]
		if young_code > 0:
			# Understory young (design §AR): their stage's mesh, drawn to the
			# shrubs' reach (saplings) or the ground cover's (seedlings).
			# (Always the near level: slim young wood gains nothing from more.)
			var ymm := _multimesh(PlantMeshes.young_mesh(sp, young_code, PlantMeshes.LOD_NEAR), entry[0], entry[1])
			var yreach := float(RANGES.get("ground_m", 80.0)) if young_code == 1 else float(RANGES.get("shrub_m", 150.0))
			var ymi := _instance(parent, sp_idx, sp, ymm, "%s_young%d" % [sp.name.replace(" ", "_"), young_code], yreach)
			ymi.set_meta("young", young_code)
			TerrainChunk.plant_shadow(ymi, sp, lod if young_code > 1 else PlantMeshes.LOD_NEAR)
			continue
		var layouts: Dictionary = entry[3]
		var far_only := not layouts.is_empty()
		# A branchy species' own MultiMesh only ever shows the far crown.
		var mm := _multimesh(PlantMeshes.mesh_for(sp, PlantMeshes.LOD_FAR if far_only else lod), entry[0], entry[1])
		var mmi := _instance(parent, sp_idx, sp, mm, sp.name.replace(" ", "_"))
		TerrainChunk.plant_shadow(mmi, sp, lod)
		if far_only:
			mmi.set_meta("far_only", true)
			mmi.visible = lod == PlantMeshes.LOD_FAR
		var near := lod != PlantMeshes.LOD_FAR
		for l in layouts:
			# Meshless until the chunk comes into the detail ring.
			var lmesh: Mesh = PlantMeshes.mesh_for(sp, lod, l) if near else null
			var lmm := _multimesh(lmesh, layouts[l][0], layouts[l][1])
			var lmi := _instance(parent, sp_idx, sp, lmm, "%s_%d" % [sp.name.replace(" ", "_"), l])
			lmi.set_meta("layout", l)
			TerrainChunk.plant_shadow(lmi, sp, lod)
			lmi.visible = near
			if own:
				chunk.layout_mm[Vector2i(sp_idx, l)] = lmm
		if own:
			chunk.tree_mm[sp_idx] = mm
		var tbuf: PackedFloat32Array = entry[0]
		for t in entry[2]:
			# Its vines and bareness (custom data g and a: 1 = dead) ride
			# along in the record (TerrainChunk reads them there, not back
			# from the MultiMesh).
			var j: int = int(t[2]) * 20
			var vines := PlantGrowth.vines_of(tbuf[j + 17]) if j + 19 < tbuf.size() else 0.0
			var bare := tbuf[j + 19] if j + 19 < tbuf.size() else 0.0
			var sport := PlantGenetics.decode_sport(float(t[7])) if t.size() > 7 else 0
			placed.append([t[0], t[1], sp_idx, t[2], t[3], t[4], t[5], t[6], vines, bare, sport])
	# In placement order when every tree knows its place (compute_base's
	# trees always do), else in the order they came.
	var n := placed.size()
	var sorted: Array = []
	sorted.resize(n)
	for t in placed:
		var at: int = t[7]
		if at < 0 or at >= n or sorted[at] != null:
			sorted.clear()
			break
		sorted[at] = t
	for t in (sorted if not sorted.is_empty() else placed):
		# Vines, bareness and the tree's sport (PlantGenetics; LookTarget
		# names it) after the seven fields.
		var extra := [t[8], t[9], t[10]]
		t.resize(7)
		t.append_array(extra)
		chunk.trees.append(t)


static func _multimesh(mesh: Mesh, buf: PackedFloat32Array, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true # (moss, vines, rustle, bare)
	# Instance colors (all white) too: without them the compatibility
	# renderer garbles vertex colors when custom data is on.
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buf
	return mm


static func _instance(parent: Node3D, sp_idx: int, sp: PlantSpecies, mm: MultiMesh, node_name: String, reach_m := -1.0) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = PlantMeshes.material_for(sp)
	mmi.set_meta("species", sp_idx)
	# Detail only near the eye (design §W; data/look.json "ranges"):
	# grasses to grass_m, the rest of the ground cover and epiphytes to
	# ground_m, shrubs to shrub_m, each fading out over its last tenth.
	var reach := 0.0
	if sp.tier == T.GROUND or sp.tier == T.EPIPHYTE:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var grassy := sp.shape == PlantSpecies.Shape.GRASS or sp.shape == PlantSpecies.Shape.TUSSOCK or sp.shape == PlantSpecies.Shape.REED
		reach = float(RANGES.get("grass_m" if grassy else "ground_m", 40.0 if grassy else 80.0))
	elif sp.tier == T.SHRUB:
		reach = float(RANGES.get("shrub_m", 150.0))
	if reach_m > 0.0:
		reach = reach_m
	if reach > 0.0:
		# Each plant by its own distance (the foliage shader shrinks it
		# away over the last tenth, draw_range_m); the whole node, which
		# spans its chunk, only once no plant in it can be in range.
		mmi.set_instance_shader_parameter("draw_range_m", reach)
		mmi.visibility_range_end = reach + TerrainChunk.CHUNK_M * 0.75
	parent.add_child(mmi)
	return mmi


## Per-chunk working state: climate on a coarse grid, per-species
## dominance, clump and shade grids, and nearby emergent trunks.
class _Context:
	const G := 8 # climate/shade grid cells per chunk edge
	const CG := 16 # clump grid cells per chunk edge

	var map: PlanetData
	var data: Dictionary
	var key: Vector3i
	var rng := RandomNumberGenerator.new()
	var chunk_m: float
	var dominance := {} # PlantSpecies -> factor for this chunk
	## This chunk's province (RealmMap.World).
	var world := 0
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
	## The roads (design 30 Sept §BC) and rooms (§BB) round this chunk:
	## polyline segments and room discs, from RoadNetwork.
	var _road_segs: Array = []
	var _rooms: Array = []
	var _road_bends := PackedVector3Array()
	var _old_trees := PackedVector3Array()

	func _init(p_key: Vector3i, p_map: PlanetData, p_data: Dictionary, salt: int) -> void:
		map = p_map
		data = p_data
		key = p_key
		rng.seed = hash([p_key, map.terrain.world_seed, salt])
		chunk_m = PlanetConst.CIRCUMFERENCE_M / 4.0 / TerrainChunk.CHUNKS_PER_FACE
		_sample_climate()
		var hot := map.terrain.nearest_hotspot(data.center)
		_hot_r = hot.radius_m
		_hot_center = map.terrain.hotspot_dirs[hot.index]
		for camp in Territories.camps_near(map, data.center, chunk_m * 0.75):
			_clearings.append([camp, Territories.CLEARING_M])
		_clearings.append_array(Ruins.clearings_near(map, data.center, chunk_m * 0.75))
		_clearings.append_array(Encampment.clearings_near(data.center, chunk_m * 0.75))
		world = RealmMap.world_at(data.center)
		if RoadNetwork.instance != null:
			var reach := chunk_m * 0.75 + 20.0
			var near := RoadNetwork.instance.links_near(data.center, reach + 140.0)
			_road_segs = RoadNetwork.segments_in(near, data.center, reach)
			_rooms = RoadNetwork.instance.rooms_near(data.center, reach)
			var limit := cos(reach / PlanetConst.RADIUS_M)
			for link in near:
				for b in link.get("bends", PackedVector3Array()):
					if b.dot(data.center) >= limit and TerrainChunk.key_at(b) == key:
						_road_bends.append(b)
				var lm: Dictionary = link.get("landmark", {})
				if not lm.is_empty() and str(lm.kind) == "old_tree" and TerrainChunk.key_at(lm.dir) == key:
					_old_trees.append(lm.dir)
		_filter_species()

	## The site at a surface direction inside this chunk (the road's bend
	## trees, the lone old tree).
	func site_at(d: Vector3) -> _Site:
		var uv := CubeSphere.face_uv(key.x, d)
		var gx := clampf(((uv.x + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE - key.y) * TerrainChunk.QUADS, 0.0, TerrainChunk.QUADS - 0.001)
		var gy := clampf(((uv.y + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE - key.z) * TerrainChunk.QUADS, 0.0, TerrainChunk.QUADS - 0.001)
		return site(gx, gy)

	## Distance (m) to the nearest road, INF with none near.
	func road_gap(d: Vector3) -> float:
		if _road_segs.is_empty():
			return INF
		var r := RoadNetwork.nearest_seg(_road_segs, d, 60.0)
		return float(r.dist_m) if not r.is_empty() else INF

	## The road's width where `d` is nearest it (0 with none).
	func road_width(d: Vector3) -> float:
		var r := RoadNetwork.nearest_seg(_road_segs, d, 60.0)
		return float((r.link as Dictionary).get("width_m", 2.0)) if not r.is_empty() else 0.0

	## Mythical folk camps (Territories), ruins and the opening encampment
	## are kept clear of plants.
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
				# The blueprint measures geographic km; plants want real meters.
				_clim_wd.append(map.sample(map.water_dist_km, d) * 1000.0 * PlanetConst.GEO_SCALE)
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
		# The chunk's middle: its realm and biome decide which realm-tagged
		# species are candidates at all (each site still checks its own).
		var mid := site(TerrainChunk.QUADS * 0.5, TerrainChunk.QUADS * 0.5)
		var biomes_here := PackedInt32Array([mid.biome])
		for corner in [Vector2(1, 1), Vector2(TerrainChunk.QUADS - 1, 1), Vector2(1, TerrainChunk.QUADS - 1), Vector2(TerrainChunk.QUADS - 1, TerrainChunk.QUADS - 1)]:
			var cb := site(corner.x, corner.y).biome
			if not biomes_here.has(cb):
				biomes_here.append(cb)
		for tier in [T.EMERGENT, T.CANOPY, T.SHRUB, T.GROUND, T.EPIPHYTE]:
			var list: Array[PlantSpecies] = []
			for sp in SpeciesDB.by_tier(tier):
				if sp.density <= 0.0 or sp.temp_c.y < tmin or sp.temp_c.x > tmax:
					continue
				if sp.altitude_m.y < hmin or sp.altitude_m.x > hmax:
					continue
				if not sp.realms.is_empty() and (not sp.realms.has(mid.realm) or not SpeciesDB.biome_hosts(mid.biome, mid.realm)):
					continue
				# The biome gate (design §CA): the species must be listed
				# by one of the biomes sampled here (with an ecotone the
				# per-site test decides).
				if VegetationPlacer.BIOME_GATE and VegetationPlacer.ECOTONE_M <= 0.0 and not VegetationPlacer._any_biome(sp.biomes, biomes_here):
					continue
				list.append(sp)
				var v := VegetationPlacer._dominance_noise[SpeciesDB.index_of(sp)].get_noise_3dv(center * PlanetConst.RADIUS_M)
				dominance[sp] = 0.35 + 1.3 * smoothstep(-0.2, 0.5, v)
			_species[tier] = _local_assemblage(list)
			_apply_dominance(tier, mid)

	## Stand dominance (design 30 Sept §BH): the stand this chunk's middle
	## is in (a cell of stand_m across, its size drawn per coarse cell)
	## rolls a dominant for this tier, its associates, and the rest as
	## accents; the dominance factors are set so that at the chunk's middle
	## the species' weights come out in those shares (the dominant 60-85 %
	## of stems, salad_dominant_share in the salad biomes where every
	## other species is an associate). The roll is by the species' own
	## fit here and the old slow dominance noise, so a pine wood is pine
	## where pine fits and the next valley's stand is another.
	func _apply_dominance(tier: int, mid: _Site) -> void:
		var dom: Dictionary = VegetationPlacer.DOM
		if not bool(dom.get("enabled", true)) or tier == T.EPIPHYTE:
			return
		var list: Array[PlantSpecies] = _species.get(tier, [] as Array[PlantSpecies])
		if list.size() < 2:
			return
		var band = dom.get("stand_m", [100, 400])
		var p: Vector3 = data.center * PlanetConst.RADIUS_M
		var coarse := float(band[1])
		var srng := RandomNumberGenerator.new()
		srng.seed = hash([Vector3i((p / coarse).floor()), "stand_size", map.terrain.world_seed])
		var size := srng.randf_range(float(band[0]), float(band[1]))
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = hash([Vector3i((p / size).floor()), "stand", tier, map.terrain.world_seed])
		var fit := {}
		var pool: Array = []
		var pool_w: Array = []
		for sp in list:
			var f := maxf(sp.suitability(mid.t, mid.m, mid.h, mid.rock), 0.02)
			fit[sp] = f
			pool.append(sp)
			pool_w.append(f * float(dominance.get(sp, 1.0)))
		var salad := VegetationPlacer.SALAD.has(mid.biome)
		var ds = dom.get("dominant_share", [0.6, 0.85])
		var share := float(dom.get("salad_dominant_share", 0.25)) if salad else rng2.randf_range(float(ds[0]), float(ds[1]))
		var asc = dom.get("associates", [1, 3])
		var n_assoc := list.size() - 1 if salad else mini(rng2.randi_range(int(asc[0]), int(asc[1])), list.size() - 1)
		var picks: Array = []
		for k in 1 + n_assoc:
			var total := 0.0
			for w in pool_w:
				total += float(w)
			var r := rng2.randf() * total
			var idx := pool.size() - 1
			for i in pool.size():
				r -= float(pool_w[i])
				if r <= 0.0:
					idx = i
					break
			picks.append(pool[idx])
			pool.remove_at(idx)
			pool_w.remove_at(idx)
		var accent := float(dom.get("accent_share", 0.03))
		var rest := list.size() - picks.size()
		var assoc_share := (1.0 - share - (accent if rest > 0 else 0.0)) / maxf(n_assoc, 1.0)
		for sp in list:
			var target: float
			if sp == picks[0]:
				target = share
			elif picks.has(sp):
				target = assoc_share
			else:
				target = accent / rest
			dominance[sp] = target / float(fit[sp])

	## A place holds only a few species of one big catalogue genus (246
	## Amorphophallus could all fit a tropical Asian forest by climate):
	## per genus, the GENUS_LOCAL with the highest dominance here, so one
	## valley has its own handful and the next a different one (and each
	## site weighs a bounded list).
	func _local_assemblage(list: Array[PlantSpecies]) -> Array[PlantSpecies]:
		var by_genus := {}
		for sp in list:
			if sp.from_catalogue and sp.genus != "":
				if not by_genus.has(sp.genus):
					by_genus[sp.genus] = []
				by_genus[sp.genus].append(sp)
		var drop := {}
		for g in by_genus:
			var members: Array = by_genus[g]
			if members.size() <= VegetationPlacer.GENUS_LOCAL:
				continue
			members.sort_custom(func(a, b): return dominance[a] > dominance[b])
			for i in range(VegetationPlacer.GENUS_LOCAL, members.size()):
				drop[members[i]] = true
		if drop.is_empty():
			return list
		var out: Array[PlantSpecies] = []
		for sp in list:
			if not drop.has(sp):
				out.append(sp)
		return out

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
		var ck: Vector3i = data.key
		var gx := clampf((uv.x + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE * TerrainChunk.QUADS - ck.y * TerrainChunk.QUADS, 0.0, TerrainChunk.QUADS - 0.001)
		var gy := clampf((uv.y + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE * TerrainChunk.QUADS - ck.z * TerrainChunk.QUADS, 0.0, TerrainChunk.QUADS - 0.001)
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
		# Soil: the class at this very point (hard gate, PlanetData.soil_at).
		s.rock = map.soil_at(s.dir)
		var water_m := minf(wd, river_m)
		if s.depth > -1.0:
			water_m = minf(water_m, maxf(-s.depth, 0.0) * 10.0)
		s.water_m = water_m
		s.t = t + (e - s.h) * PlanetConst.LAPSE_RATE_C_PER_M + ASPECT_C * aspect
		s.m = clampf(m + WATER_BOOST * exp(-water_m / WATER_BOOST_M) - ASPECT_MOISTURE * aspect, 0.0, 1.0)
		s.hot = CubeSphere.geo_distance_m(s.dir, _hot_center) < _hot_r * 0.45
		s.beach = s.h < 3.0 and s.coast_km < 1.5 and smoothstep(3.0, 0.8, s.h) > 0.35
		s.biome = map.biome[map.cell_at(s.dir)]
		s.realm = RealmMap.realm(world, s.dir, s.t, s.m, s.h / PlanetConst.HEIGHT_SCALE)

	static func _bilerp(arr, k00: int, w: int, tx: float, ty: float) -> float:
		return lerpf(lerpf(arr[k00], arr[k00 + 1], tx), lerpf(arr[k00 + w], arr[k00 + w + 1], tx), ty)

	## Species weight at a site: climate bands x soil x needs x dominance.
	## The site checks that rule a species out come first (they're cheap and
	## most failures are these); the product is the same.
	## Within ECOTONE_M of a cell whose biome lists the species (four
	## bearings, that far out), when its own bands fit here.
	func _ecotone_ok(sp: PlantSpecies, s: _Site) -> bool:
		for k in 4:
			var q := CreatureSpawner._offset(s.dir, k * TAU / 4.0, VegetationPlacer.ECOTONE_M)
			if sp.biomes.has(map.biome[map.cell_at(q)]):
				return true
		return false

	func weight(sp: PlantSpecies, s: _Site) -> float:
		var bits := sp.need_bits()
		var standing := bits & (1 << PlantSpecies.Needs.STANDING_WATER) != 0
		var salty := bits & (1 << PlantSpecies.Needs.SALT_WATER) != 0
		if standing:
			if s.depth <= 0.05 or s.depth < sp.water_depth_m.x or s.depth > sp.water_depth_m.y:
				return 0.0
		elif s.depth > -WATERLINE_M:
			# Ground at or barely above the water: the drawn water (flat
			# quads, waves) covers it, so a plant there stands in the sea.
			return 0.0
		# Beach sand (the band TerrainChunk colors as sand): salt-tolerant
		# plants only.
		if s.beach and not salty:
			return 0.0
		if salty and standing and not s.salt:
			return 0.0
		if bits & (1 << PlantSpecies.Needs.HOT_GROUND) != 0 and not s.hot:
			return 0.0
		# Dry ground (tubers rot in the wet): never in a wetland biome, nor
		# right by the water.
		if bits & (1 << PlantSpecies.Needs.DRY_GROUND) != 0 and (VegetationPlacer.WETLANDS.has(s.biome) or s.water_m < VegetationPlacer.DRY_GROUND_M):
			return 0.0
		# Forest floor: under or in the gaps of a forest (a forest biome).
		if bits & (1 << PlantSpecies.Needs.FOREST_FLOOR) != 0 and not VegetationPlacer.FORESTS.has(s.biome):
			return 0.0
		# The realm gate (design §AA).
		if not sp.realms.is_empty() and (not sp.realms.has(s.realm) or not SpeciesDB.biome_hosts(s.biome, s.realm)):
			return 0.0
		# The biome gate (design §CA): only where a biome lists it; with
		# an ecotone, a neighbouring cell's biome that lists it will do.
		if VegetationPlacer.BIOME_GATE and not sp.biomes.has(s.biome):
			if VegetationPlacer.ECOTONE_M <= 0.0 or not _ecotone_ok(sp, s):
				return 0.0
		var w := sp.suitability(s.t, s.m, s.h, s.rock)
		if w <= 0.0:
			return 0.0
		if salty and not standing:
			w *= 1.0 - smoothstep(0.3, 1.0, s.coast_km)
		if bits & (1 << PlantSpecies.Needs.RIVER_BANK) != 0:
			w *= 1.0 - smoothstep(25.0, 70.0, s.water_m)
		return w * dominance.get(sp, 1.0)

	func add_emergent(d: Vector3) -> void:
		_emergents.append(d)

	func near_emergent(d: Vector3) -> bool:
		var limit := cos(5.5 / PlanetConst.RADIUS_M)
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
	var beach: bool # on the sand band by the sea
	var biome: int # BiomeTemplates id of the cell
	var realm: String # RealmMap.realm() here
