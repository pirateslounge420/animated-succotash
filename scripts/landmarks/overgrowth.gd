class_name Overgrowth
## A ruin wears its place (design 3 Oct §DI.2, data/ruins.json overgrowth):
## dressing only, nothing to clear, no mechanic. At build time
## (RuinBuilder.compute, on the worker) the place's moisture (the climate's
## 0-1 at the site) picks a blend of the by_moisture rows, and each column
## sets how much the ruin carries of one thing:
##   * moss: the stone's moss (RuinBuilder.box/boulder: vertex alpha, which
##     the ruin shader mixes to the leafy tile), thicker by shade_side_scale
##     on the side away from the sun (north in the northern hemisphere,
##     south in the southern) and on top faces;
##   * fern: ferns the place grows (its own plant file: the biome gate §CA
##     and the community there §CS) at the wall feet and in the gaps (low
##     broken stumps), more on the shade side;
##   * vine: the share of the ruin's hanging places (broken wall tops) that
##     hang a vine: the builder's own ivy strands, and the place's own vine
##     species over them near you (VineCover, §CE);
##   * wall_top: grass and herbs from the place's ground cover along the
##     exposed tops of the walls (its ferns where it has none);
##   * lichen: flecks painted into the stone's own tile (UV.y, the ruin
##     shader; look R9: detail in the albedo, never an overlay).
## age scales all of it (a monument 1.0; a camp's remains 0.5, §CK); where
## the year's mean is under cold_mean_c only lichen and moss grow. Never a
## species the place can't grow. Nothing it adds collides.

static var D: Dictionary = Tuning.section("ruins", "overgrowth")
## The builder's moss pattern (more at a wall's foot and on top) averages
## about this; the moss column scales it so the stone's mean moss is the
## column's.
const PATTERN_MEAN := 0.26
## Share of a ruin's own triangles its plants may add (ferns and wall-top
## herbs; the check holds the whole dressing under 20 %).
const PLANT_TRI_SHARE := 0.12
## At most this many species of each role per ruin (one draw each).
const FERN_KINDS := 2
const TOP_KINDS := 3
## Wall-top plants stay small (m, their tallest).
const TOP_MAX_H := 1.2
const COLUMNS := ["moss", "fern", "vine", "wall_top", "lichen"]


## The age factor of a kind of stone: "monument" or "camp_remains".
static func age_k(kind := "monument") -> float:
	return float((D.get("age", {}) as Dictionary).get(kind, 1.0))


## Each column at `moisture` (0-1; rows blended), times `age`; under
## cold_mean_c (the year's mean, `mean_c`) fern, vine and wall_top are 0.
static func amounts(moisture: float, mean_c: float, age := 1.0) -> Dictionary:
	var cols: Array = D.get("columns", ["moisture"] + COLUMNS)
	var rows: Array = D.get("by_moisture", [])
	var out := {}
	for k in COLUMNS:
		out[k] = 0.0
	if rows.is_empty():
		return out
	var lo: Array = rows[0]
	var hi: Array = rows[rows.size() - 1]
	for i in rows.size() - 1:
		if moisture >= float(rows[i][0]) and moisture <= float(rows[i + 1][0]):
			lo = rows[i]
			hi = rows[i + 1]
			break
	if moisture > float(hi[0]):
		lo = hi
	var span := float(hi[0]) - float(lo[0])
	var t := clampf((moisture - float(lo[0])) / span, 0.0, 1.0) if span > 0.0 else 0.0
	for k in COLUMNS:
		var j := cols.find(k)
		if j < 0:
			continue
		out[k] = lerpf(float(lo[j]), float(hi[j]), t) * age
	out["cold"] = mean_c < float(D.get("cold_mean_c", 0.0))
	if out.cold:
		for k in ["fern", "vine", "wall_top"]:
			out[k] = 0.0
	return out


## The overgrowth at a ruin site: amounts() at its moisture and mean
## temperature, with "moisture", "mean_c", "age" and "shade" (the world
## direction away from the sun: poleward) and "shade_scale".
static func for_site(map: PlanetData, site: Dictionary) -> Dictionary:
	var d: Vector3 = site.dir
	var m := map.sample(map.moisture, d)
	var tc := map.sample(map.temp_c, d)
	var age := age_k(str(site.get("age_kind", "monument")))
	var out := amounts(m, tc, age)
	out["moisture"] = m
	out["mean_c"] = tc
	out["age"] = age
	out["shade"] = CubeSphere.north(d) * (1.0 if CubeSphere.latitude(d) >= 0.0 else -1.0)
	out["shade_scale"] = float(D.get("shade_side_scale", 1.6))
	return out


## The shade side's factor for a face whose horizontal normal meets the
## shade direction at `dot` (-1 sun side, 1 shade side): shade_scale times
## the sun side's, averaging 1 round a wall.
static func side_factor(dot: float, shade_scale: float) -> float:
	var sun := 2.0 / (1.0 + shade_scale)
	return lerpf(sun, sun * shade_scale, 0.5 + 0.5 * clampf(dot, -1.0, 1.0))


## May `sp` grow at `d` (the biome there, the community dealt it, the realm,
## its needs a wall's foot can meet, and its climate)? The placer's gate
## (VegetationPlacer._Context.weight) without the water and the shore: a
## ruin's stones are dry land.
static func gate(map: PlanetData, d: Vector3, sp: PlantSpecies) -> bool:
	var cell := map.cell_at(d)
	var biome: int = map.biome[cell]
	if not sp.biomes.has(biome):
		return false
	var bits := sp.need_bits()
	for need in [PlantSpecies.Needs.STANDING_WATER, PlantSpecies.Needs.SALT_WATER, PlantSpecies.Needs.HOT_GROUND, PlantSpecies.Needs.RIVER_BANK]:
		if bits & (1 << need) != 0:
			return false
	if bits & (1 << PlantSpecies.Needs.FOREST_FLOOR) != 0 and not VegetationPlacer.FORESTS.has(biome):
		return false
	if bits & (1 << PlantSpecies.Needs.DRY_GROUND) != 0 and VegetationPlacer.WETLANDS.has(biome):
		return false
	var ci := Communities.at(d, biome)
	if not Communities.admits(ci, sp):
		return false
	var t := map.sample(map.temp_c, d)
	var m := map.sample(map.moisture, d)
	var h := map.terrain.elevation(d, true)
	if not Communities.member(ci, sp) and not sp.realms.is_empty():
		var realm := RealmMap.realm(RealmMap.world_at(d), d, t, m, h / PlanetConst.HEIGHT_SCALE)
		if not sp.realms.has(realm) or not SpeciesDB.biome_hosts(biome, realm):
			return false
	return sp.suitability(t, m, h, map.soil_at(d)) > 0.0


## Is `sp` a fern (the cracks and the foot) or a wall-top plant (grass and
## herbs of the ground cover, small; never a fungus)?
static func role_of(sp: PlantSpecies) -> String:
	if sp.tier != PlantSpecies.Tier.GROUND or not sp.fungus.is_empty():
		return ""
	if sp.shape == PlantSpecies.Shape.FERN:
		return "fern"
	if sp.shape in [PlantSpecies.Shape.GRASS, PlantSpecies.Shape.TUSSOCK, PlantSpecies.Shape.ROSETTE, PlantSpecies.Shape.CUSHION, PlantSpecies.Shape.SHRUB] \
			and sp.height_m.y <= TOP_MAX_H:
		return "wall_top"
	return ""


## The species of `role` that may grow at `d`, the best-suited first (with
## the site's own jitter), at most `n`.
static func species(map: PlanetData, d: Vector3, role: String, n: int, salt: int) -> Array[PlantSpecies]:
	var t := map.sample(map.temp_c, d)
	var m := map.sample(map.moisture, d)
	var h := map.terrain.elevation(d, true)
	var rock := map.soil_at(d)
	var scored: Array = []
	for sp in SpeciesDB.all():
		if role_of(sp) != role or sp.density <= 0.0 or not gate(map, d, sp):
			continue
		var f := sp.suitability(t, m, h, rock) * (0.6 + 0.8 * float(hash([salt, sp.name]) & 1023) / 1023.0)
		scored.append([f, sp])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array[PlantSpecies] = []
	for s in scored:
		out.append(s[1])
		if out.size() >= n:
			break
	return out


## The plants a ruin carries (worker): from the builder's spots
## (RuinBuilder._og_spots: "feet" [pos, out], "gaps" [pos], "tops" [pos]),
## each kept by its own hash against its column (and the shade side for
## ferns): [[species index, local position, yaw, height, role]], shuffled
## so trimming to a budget thins them evenly.
static func plants(map: PlanetData, site: Dictionary, og: Dictionary, spots: Dictionary, shade_local: Vector3) -> Array:
	var out: Array = []
	var d: Vector3 = site.dir
	var salt := int(site.seed)
	var ss := float(og.get("shade_scale", 1.6))
	for role in ["fern", "wall_top"]:
		var amount := float(og.get(role, 0.0))
		if amount <= 0.0:
			continue
		var kinds := species(map, d, role, FERN_KINDS if role == "fern" else TOP_KINDS, salt)
		# A place whose ground cover has no small grass or herb (a cloud
		# forest's is ferns) puts its ferns on the wall tops.
		if kinds.is_empty() and role == "wall_top":
			kinds = species(map, d, "fern", FERN_KINDS, salt)
		if kinds.is_empty():
			continue
		var places: Array = []
		if role == "fern":
			for f in spots.get("feet", []):
				var o: Vector3 = f[1]
				places.append([f[0], side_factor(Vector2(o.x, o.z).normalized().dot(Vector2(shade_local.x, shade_local.z)), ss)])
			for g in spots.get("gaps", []):
				places.append([g[0], 1.0])
		else:
			for tp in spots.get("tops", []):
				places.append([tp[0], 1.0])
		for i in places.size():
			var p: Vector3 = places[i][0]
			var u := float(hash([salt, role, i]) & 0xFFFF) / 65535.0
			if u >= amount * float(places[i][1]):
				continue
			var sp: PlantSpecies = kinds[hash([salt, role, i, "kind"]) % kinds.size()]
			var hu := float(hash([salt, role, i, "h"]) & 1023) / 1023.0
			var height := lerpf(sp.height_m.x, sp.height_m.y, hu * 0.7) * float(VegetationPlacer.SIZE_SCALE[int(sp.tier)])
			out.append([SpeciesDB.index_of(sp), p, float(hash([salt, role, i, "yaw"]) & 1023) / 1023.0 * TAU, height, role])
	out.sort_custom(func(a: Array, b: Array) -> bool: return hash([salt, a[1]]) < hash([salt, b[1]]))
	return out


## Main thread: the ruin's plants as MultiMeshes under `node` (the ruin's
## frame), within PLANT_TRI_SHARE of the ruin's own triangles: one per
## species, drawn at the ground cover's reach. Returns the instances kept.
static func dress(node: Node3D, data: Dictionary) -> int:
	var list: Array = data.get("og_plants", [])
	if list.is_empty():
		return 0
	var all := SpeciesDB.all()
	var budget := int(float((data.v as PackedVector3Array).size() / 3) * PLANT_TRI_SHARE)
	var used := 0
	var by_sp := {}
	var mesh_of := {}
	for p in list:
		var si := int(p[0])
		if not mesh_of.has(si):
			var mesh := PlantMeshes.mesh_for(all[si], PlantMeshes.LOD_NEAR)
			mesh_of[si] = [mesh, _tris(mesh)]
		var tris: int = mesh_of[si][1]
		if used + tris > budget:
			continue
		used += tris
		if not by_sp.has(si):
			by_sp[si] = []
		(by_sp[si] as Array).append(p)
	var kept := 0
	for si in by_sp:
		var sp: PlantSpecies = all[si]
		var items: Array = by_sp[si]
		var buf := PackedFloat32Array()
		buf.resize(items.size() * 20)
		for i in items.size():
			var p: Array = items[i]
			var h := float(p[3])
			var basis := Basis(Vector3.UP, float(p[2])) * Basis.from_scale(Vector3(h, h, h))
			VegetationPlacer._put(buf, i * 20, basis, p[1], 0.0, 0.0)
		var mm := VegetationPlacer._multimesh(mesh_of[si][0], buf, items.size())
		var mmi := VegetationPlacer._instance(node, si, sp, mm, "Overgrowth_" + sp.name.replace(" ", "_"))
		mmi.set_meta("overgrowth", str(items[0][4]))
		kept += items.size()
	node.set_meta("overgrowth_tris", used)
	return kept


static func _tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null and idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


## The vine dressing of a ruin (§CE over §DI): its builder already kept
## the hanging places by the vine column (RuinBuilder.ivy), so the place's
## vine species hangs from every one of them near you, times the ruin's
## age and a camp's cutting back; and over its boulders by the column too.
static func dress_vines(map: PlanetData, node: Node3D, data: Dictionary, age_years: float, legibility: int) -> void:
	var site: Dictionary = data.get("site", {})
	var og: Dictionary = data.get("og", {})
	var d: Vector3 = site.dir
	var t := map.sample(map.temp_c, d)
	var m := map.sample(map.moisture, d)
	var h := map.terrain.elevation(d, true)
	var sp := VineCover.species_at(d, map.biome[map.cell_at(d)], t, m, h, map.soil_at(d))
	# (The vines are an always-present group, §CE: VineCover's own rule,
	# the biome listing it and its climate, is the gate, as on the trees.)
	if sp == null:
		return
	VineCover.ruin_patches(node, data.get("vine_anchors", []), sp, m, t, age_years, legibility, "ruin", 1.0)
	VineCover.ruin_patches(node, data.get("boulder_anchors", []), sp, m, t, age_years, legibility, "boulder", float(og.get("vine", 0.0)))
