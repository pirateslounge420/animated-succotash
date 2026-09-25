class_name BiomePass
## Pass 6: biome label per blueprint cell (BiomeTemplates), from the
## weather-derived climate averages plus terrain, water and rock. Rules run
## in priority order; the first match wins:
##
##   1. Water: ocean templates by depth and sea temperature (sea ice,
##      coral reef, kelp forest, shelf sea, deep ocean, lagoon); lakes are
##      fresh water, salt flats (salt lakes) or oases (lakes in deserts).
##   2. Small special pockets: hot springs and volcanic fields (volcanic
##      rock), glaciers and ice sheets (deep cold).
##   3. Coast (land touching the sea): mangrove, rocky shore, salt marsh,
##      estuary, dunes, beach; maritime forest a little further in.
##   4. Wetlands (flat, waterlogged ground): floodplain forest, swamp,
##      freshwater marsh, wet meadow, fen, bog.
##   5. Rugged dry country: canyons along rivers, badlands.
##   6. Altitude zonation above MOUNTAIN_BASE_M: above the treeline it's
##      páramo/puna in the tropics, alpine meadow then alpine tundra
##      elsewhere; around the treeline krummholz; below it on moist
##      mountainsides montane/cloud forest.
##   7. Everything else: temperature x moisture climate table.
##
## Then small specialty pockets are held to their DESIGN.md "Biome Sizing"
## (under ~40 minutes to walk across, many under 5): any patch bigger than
## its cap in PATCH_CAP is eroded from the outside in, its rim cells taking
## the most common neighboring biome, so a rare landmark keeps its core
## instead of spreading over a whole volcano or desert basin.
##
## There are no seasons (no axial tilt), so the treeline and the
## boundaries use mean annual temperature, like the real tropics.
##
## Reads everything written before it. Writes biome.


## Heights below are Earth's, times PlanetConst.HEIGHT_SCALE.
const H := PlanetConst.HEIGHT_SCALE
const MOUNTAIN_BASE_M := 900.0 * H
const TREELINE_C := 3.0 # mean annual temperature at the tree line
const KRUMMHOLZ_BAND_C := 3.0 # stunted trees within this many degrees above it
const TROPICAL_LAT := 0.4363 # 25 degrees
const VOLCANIC_CORE := 0.45 # share of a volcano's radius that is bare lava field
const GLACIER_MIN_M := 2200.0 * H
const GLACIER_MAX_LAT := 0.96 # 55 degrees; closer to the poles high ice is ice sheet


## Largest patch, in ~1 km cells, for small specialty pockets. Linear
## coastal and river biomes (beach, dunes, mangrove, canyon, ...) are
## narrow strips, quick to cross however long, so they aren't capped; nor
## are glaciers, nor salt flats (real ones like Bonneville and Uyuni are
## vast, so a large one here is accurate).
const PATCH_CAP := {
	BiomeTemplates.HOT_SPRING: 1,
	BiomeTemplates.OASIS: 2,
	BiomeTemplates.BOG: 5,
	BiomeTemplates.FEN: 5,
	BiomeTemplates.FRESHWATER_MARSH: 8,
	BiomeTemplates.SWAMP: 10,
	BiomeTemplates.VOLCANIC_FIELD: 10,
	BiomeTemplates.BADLANDS: 10,
	BiomeTemplates.KRUMMHOLZ: 12,
	BiomeTemplates.CLOUD_FOREST: 12,
	BiomeTemplates.ALPINE_MEADOW: 12,
	BiomeTemplates.PARAMO: 12,
	BiomeTemplates.PUNA: 12,
	BiomeTemplates.SAGEBRUSH: 12,
	BiomeTemplates.MEDITERRANEAN_SCRUB: 12,
}


static func run(map: PlanetData) -> void:
	var nbrs := map.neighbors
	var biome := PackedInt32Array()
	biome.resize(map.cell_count)
	for c in map.cell_count:
		biome[c] = classify(map, c, nbrs)
	for id in PATCH_CAP:
		_cap_patches(map, biome, id, PATCH_CAP[id])
	map.biome = biome


## Erode every patch of `id` larger than `cap` cells from its rim inward.
static func _cap_patches(map: PlanetData, biome: PackedInt32Array, id: int, cap: int) -> void:
	var seen := {}
	for start in map.cell_count:
		if biome[start] != id or seen.has(start):
			continue
		var patch := _flood(map, biome, start, id)
		for c in patch:
			seen[c] = true
		for round in 30:
			if patch.size() <= cap:
				break
			var rim: Array = []
			var inner: Array = []
			for c in patch:
				var same := 0
				for k in 8:
					if biome[map.neighbors[c * 8 + k]] == id:
						same += 1
				(inner if same == 8 else rim).append([same, c])
			if inner.size() < cap:
				# Too thin to erode ring by ring: keep the best-connected cells.
				rim.sort_custom(func(x, y): return x[0] > y[0])
				rim = rim.slice(cap - inner.size())
			for e in rim:
				biome[e[1]] = _replacement(map, biome, e[1], id)
			patch = []
			for e in inner:
				patch.append(e[1])
			if inner.size() < cap:
				break


static func _flood(map: PlanetData, biome: PackedInt32Array, start: int, id: int) -> Array:
	var out := [start]
	var seen := {start: true}
	var i := 0
	while i < out.size():
		var c: int = out[i]
		i += 1
		for k in 8:
			var n := map.neighbors[c * 8 + k]
			if biome[n] == id and not seen.has(n):
				seen[n] = true
				out.append(n)
	return out


## Most common neighboring land biome (lake cells become fresh water).
static func _replacement(map: PlanetData, biome: PackedInt32Array, c: int, id: int) -> int:
	if map.water[c] == PlanetData.Water.LAKE:
		return BiomeTemplates.FRESHWATER
	var votes := {}
	for k in 8:
		var b := biome[map.neighbors[c * 8 + k]]
		if b == id or BiomeTemplates.is_ocean(b) or b in [BiomeTemplates.FRESHWATER, BiomeTemplates.OASIS, BiomeTemplates.LAGOON, BiomeTemplates.SALT_FLAT]:
			continue
		if PATCH_CAP.has(b):
			votes[b] = votes.get(b, 0) + 0.5 # prefer ordinary surroundings
		else:
			votes[b] = votes.get(b, 0) + 1
	var best := id
	var best_v := 0.0
	for b in votes:
		if votes[b] > best_v:
			best_v = votes[b]
			best = b
	return best


static func classify(map: PlanetData, c: int, nbrs: PackedInt32Array) -> int:
	var water: int = map.water[c]
	var elev := map.elevation[c]
	var t := map.temp_c[c]
	var m := map.moisture[c]
	var slope := map.slope[c]
	var rock: int = map.rock[c]

	# Neighborhood facts.
	var ocean_nbrs := 0
	var near_river := water == PlanetData.Water.RIVER
	var near_lake := false
	var relief := 0.0
	for k in 8:
		var nb := nbrs[c * 8 + k]
		var nw: int = map.water[nb]
		if nw == PlanetData.Water.OCEAN:
			ocean_nbrs += 1
		elif nw == PlanetData.Water.RIVER:
			near_river = true
		elif nw == PlanetData.Water.LAKE:
			near_lake = true
		relief = maxf(relief, absf(map.elevation[nb] - elev))

	# 1. Water.
	if water == PlanetData.Water.OCEAN:
		return _ocean(map, c, elev, t, ocean_nbrs)
	if water == PlanetData.Water.LAKE:
		if map.salinity[c] == PlanetData.Salinity.SALT:
			return BiomeTemplates.SALT_FLAT
		if m < 0.25:
			return BiomeTemplates.OASIS
		return BiomeTemplates.FRESHWATER

	# 2. Special pockets.
	if rock == PlanetData.Rock.BASALT_VOLCANIC:
		# Only the summit area is bare lava; lower slopes are ordinary
		# biomes on rich volcanic soil.
		var hot := map.terrain.nearest_hotspot(map.dir[c])
		if hot.distance_m < hot.radius_m * VOLCANIC_CORE:
			return BiomeTemplates.HOT_SPRING if m > 0.45 and t > -5.0 else BiomeTemplates.VOLCANIC_FIELD
	if t < -8.0 and elev > GLACIER_MIN_M and map.precip_mm[c] > 150.0 and absf(map.lat[c]) < GLACIER_MAX_LAT:
		return BiomeTemplates.GLACIER
	if t < -11.0:
		return BiomeTemplates.ICE_SHEET

	# 3. Coast.
	var coastal := ocean_nbrs > 0 and elev < 60.0 * H
	if coastal:
		if near_river and map.salinity[c] == PlanetData.Salinity.BRACKISH:
			return BiomeTemplates.ESTUARY
		if slope > 0.22:
			return BiomeTemplates.ROCKY_SHORE
		if t > 20.0 and m > 0.5 and slope < 0.08:
			return BiomeTemplates.MANGROVE
		if t > 4.0 and t <= 20.0 and m > 0.62 and slope < 0.04:
			return BiomeTemplates.SALT_MARSH
		if m < 0.3 or rock == PlanetData.Rock.SANDSTONE:
			return BiomeTemplates.DUNES
		return BiomeTemplates.BEACH
	if map.coast_dist_km[c] < 2.0 and elev < 200.0 * H and m > 0.45 and t > 4.0 and t < 22.0:
		return BiomeTemplates.MARITIME_FOREST

	# 4. Wetlands: flat, wet, and with water nearby or peat underfoot.
	var flat := slope < 0.035
	var waterlogged := m > 0.68 and (map.water_dist_km[c] < 2.5 or rock == PlanetData.Rock.CLAY_PEAT)
	if flat and near_river and m > 0.5 and t > 4.0 and map.flow_accum[c] > _big_river(map):
		return BiomeTemplates.FLOODPLAIN_FOREST
	if flat and waterlogged:
		if t > 17.0:
			return BiomeTemplates.SWAMP
		if t > 4.0:
			return BiomeTemplates.FRESHWATER_MARSH if (near_lake or near_river) else BiomeTemplates.WET_MEADOW
		if t > -6.0:
			# Fens are fed by groundwater and streams; bogs only by rain.
			return BiomeTemplates.FEN if (near_river or near_lake) else BiomeTemplates.BOG

	# 5. Rugged dry country.
	if m < 0.35 and relief > 350.0 * H:
		if near_river:
			return BiomeTemplates.CANYON
		if rock == PlanetData.Rock.SANDSTONE and elev < 2200.0 * H:
			return BiomeTemplates.BADLANDS

	# 6. Altitude zonation.
	if elev >= MOUNTAIN_BASE_M:
		if t < TREELINE_C:
			if absf(map.lat[c]) < TROPICAL_LAT:
				return BiomeTemplates.PARAMO if m > 0.55 else BiomeTemplates.PUNA
			if t < -2.0:
				return BiomeTemplates.ALPINE_TUNDRA
			return BiomeTemplates.ALPINE_MEADOW if m > 0.35 else BiomeTemplates.ALPINE_TUNDRA
		if t < TREELINE_C + KRUMMHOLZ_BAND_C:
			return BiomeTemplates.KRUMMHOLZ
		if t < 20.0 and m > 0.55 and map.fog[c] > 0.45:
			return BiomeTemplates.CLOUD_FOREST

	# 7. Climate table.
	return _climate(map, c, t, m)


static func _ocean(map: PlanetData, c: int, elev: float, sst: float, ocean_nbrs: int) -> int:
	var depth := -elev / H # Earth-equivalent
	if sst < -1.5:
		return BiomeTemplates.SEA_ICE
	if depth < 15.0 and ocean_nbrs <= 3:
		# Shallow water mostly wrapped by land.
		return BiomeTemplates.LAGOON
	if depth < 80.0:
		if sst > 23.0:
			return BiomeTemplates.CORAL_REEF
		if sst > 6.0 and sst < 18.0:
			return BiomeTemplates.KELP_FOREST
	if depth < 250.0:
		return BiomeTemplates.SHELF_SEA
	return BiomeTemplates.DEEP_OCEAN


static func _climate(map: PlanetData, c: int, t: float, m: float) -> int:
	if t < -3.0:
		return BiomeTemplates.TUNDRA
	if t < -1.0:
		return BiomeTemplates.KRUMMHOLZ # forest-tundra, the arctic variant
	if t < 7.0: # cold / boreal
		if m < 0.22:
			return BiomeTemplates.COLD_DESERT
		if m < 0.38:
			return BiomeTemplates.STEPPE
		if m > 0.82 and map.coast_dist_km[c] < 15.0:
			return BiomeTemplates.TEMPERATE_RAINFOREST
		return BiomeTemplates.TAIGA
	if t < 18.0: # temperate
		if m < 0.2:
			return BiomeTemplates.COLD_DESERT
		if m < 0.3:
			return BiomeTemplates.SAGEBRUSH if map.temp_swing_c[c] > 4.0 else BiomeTemplates.STEPPE
		if t > 12.0 and m < 0.55 and (map.rock[c] == PlanetData.Rock.LIMESTONE_KARST or map.coast_dist_km[c] < 25.0):
			return BiomeTemplates.MEDITERRANEAN_SCRUB
		if m < 0.42:
			return BiomeTemplates.SHORTGRASS_PRAIRIE
		if m < 0.52:
			return BiomeTemplates.TALLGRASS_PRAIRIE
		if m > 0.82 and map.coast_dist_km[c] < 15.0:
			return BiomeTemplates.TEMPERATE_RAINFOREST
		return BiomeTemplates.TEMPERATE_DECIDUOUS
	# warm / tropical
	if m < 0.18:
		return BiomeTemplates.HOT_DESERT
	if m < 0.28:
		return BiomeTemplates.THORN_SCRUB
	if m < 0.45:
		return BiomeTemplates.SAVANNA
	if m < 0.56:
		return BiomeTemplates.TROPICAL_DRY_FOREST
	if m < 0.64:
		return BiomeTemplates.JUNGLE
	return BiomeTemplates.TROPICAL_RAINFOREST


## Discharge above which a river is big enough to have a floodplain. Cached
## for the map being classified (a percentile over river cells); a new map
## replaces the entry, so regenerating never grows it.
static var _big_river_map_id := 0
static var _big_river_value := INF


static func _big_river(map: PlanetData) -> float:
	var key := map.get_instance_id()
	if key == _big_river_map_id:
		return _big_river_value
	var vals := PackedFloat32Array()
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.RIVER:
			vals.append(map.flow_accum[c])
	vals.sort()
	var v: float = vals[int(vals.size() * 0.6)] if vals.size() > 0 else INF
	_big_river_map_id = key
	_big_river_value = v
	return v
