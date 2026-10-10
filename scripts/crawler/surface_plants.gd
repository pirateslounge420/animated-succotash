class_name SurfacePlants
extends Node3D
## The surface's plants (design 9 Oct §FM.7; §EW.1: the biome's species by
## their real silhouettes, §CS: a stand is mostly one species; worlds.json
## surface.plants; the world's biome file in data/biomes): the open world's
## own plants (SpeciesDB, PlantMeshes, drawn as in play: each species' mesh
## in MultiMeshes with its own material), never loaded into anything else.
##
## The ground has three kinds of place (SurfaceGround.zone_at), each grown
## from one of the biome's associations (plants.zones names it; else the
## association whose `where` reads like it), its realm the world's
## (surface.realm):
##
##   wash    the dry watercourse and its banks (the hot desert's mesquite
##           bosque; no tree in the bed itself, BED_OPEN)
##   flats   the basin's floor (creosote and bursage)
##   upland  the bajada under the edge, within upland_from_edge_m of the
##           cliff's foot (saguaro and paloverde)
##
## In each, the association's dominant species take dominant_share of the
## plants and its companions the rest, per_hectare of them where the
## association's cover is 0.3 (more where it covers more); its ground
## species (grasses, ferns) ground_per_hectare within ground_within_m of the
## stairhead. Never on the cliffs, in the yard, on a stack or a find, or on
## ground too steep to hold them; every plant clear_m from the next tree.
##
## Drawn in blocks of BLOCK_M: within near_m of your eye each block's near
## meshes (the branchy trees' open-grown layouts), past it the far ones
## (PlantMeshes' impostors), so the far plain stays light. A tree (taller
## than TREE_M) has a trunk you can't walk through. No seasons here (§ET.2):
## the deciduous species keep their leaves.

const BLOCK_M := 96.0
## Plants this tall or taller stand in your way (a trunk collider).
const TREE_M := 2.5
## No tree where the wash's bed is deeper than this (SurfaceGround.in_wash:
## 1 on its line, 0 past its half width): the bed open, the banks wooded.
const BED_OPEN := 0.25

## Instances placed, by species name (checks, the log), and by zone
## ({zone: {species name: n}}).
var counts := {}
var zone_counts := {}
var placed := 0
## The associations grown, by zone: {"wash": name...}.
var grown := {}
## The species picked, by zone: {zone: {"dominant": [names], "companion": [...], "ground": [...]}}.
var picks := {}
## The trees grown (TREE_M or taller): [[x/z, height, species]...] (queue
## 72: the sacred vine hangs from one, SacredVine).
var trees_placed: Array = []
var _mats := {}


## Grow them over ground `land` (worlds.json surface `p`, the biome file
## `biome`, the world's realm), seeded `seed_value`, clear of `keep_out`
## ([Rect2...] x/z).
func build(land: SurfaceGround, p: Dictionary, biome: Dictionary, seed_value: int, keep_out: Array) -> void:
	var PL: Dictionary = p.get("plants", {})
	var realm := str(p.get("realm", ""))
	var zones := {}
	var named: Dictionary = PL.get("zones", {})
	var assocs: Array = biome.get("associations", [])
	for z in ["wash", "flats", "upland"]:
		var a := _association(assocs, str(named.get(z, "")), z, realm)
		if a.is_empty():
			continue
		var dom := _species(a.get("dominant", []))
		var com := _species(a.get("companion", []))
		var gnd := _species(a.get("ground", []))
		if dom.is_empty() and com.is_empty():
			continue
		zones[z] = {"dominant": dom, "companion": com, "ground": gnd, "cover": clampf(float(a.get("cover", 0.3)), 0.05, 1.0)}
		grown[z] = str(a.get("name", ""))
		picks[z] = {"dominant": dom.map(func(s): return s.name), "companion": com.map(func(s): return s.name), "ground": gnd.map(func(s): return s.name)}
	# The flats' ground species stand in wherever a zone has none of its own.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "surface plants"])
	var per_ha := maxf(float(PL.get("per_hectare", 75.0)), 0.0)
	var dom_share := clampf(float(PL.get("dominant_share", 0.6)), 0.0, 1.0)
	var gnd_ha := maxf(float(PL.get("ground_per_hectare", 140.0)), 0.0)
	var gnd_in := float(PL.get("ground_within_m", 240.0))
	var up_from := float(PL.get("upland_from_edge_m", 160.0))
	var clear := maxf(float(PL.get("clear_m", 3.0)), 0.5)
	var step := 5.0
	var cell_ha := step * step / 10000.0
	# [block key] -> {[species index, layout, near?] -> [Transform3D...]}
	var blocks := {}
	var trees: Array = []
	var tree_grid := {}
	# The branchy trees' layouts grown from this world's seed.
	PlantMeshes.use_seed(seed_value)
	var half := land.half_m()
	var lo := land.center - Vector2(half, half)
	var nx := int(2.0 * half / step)
	var reach := land.r_in * (1.0 + absf(float(land.E.get("wander", 0.07))))
	var most := 0.0
	for z in zones:
		most = maxf(most, float((zones[z] as Dictionary).cover))
	var max_p := (per_ha * most / 0.3 + gnd_ha) * cell_ha
	for j in nx:
		for i in nx:
			# The same dice every cell, so a world grows the same plants.
			var q := lo + Vector2((i + rng.randf()) * step, (j + rng.randf()) * step)
			var roll := rng.randf()
			if roll >= max_p or (q - land.center).length() > reach or not land.inside(q, 3.0):
				continue
			var blocked := false
			for r: Rect2 in keep_out:
				if r.has_point(q):
					blocked = true
					break
			if blocked:
				continue
			var zone := land.zone_at(q, up_from)
			if not zones.has(zone):
				continue
			var zd: Dictionary = zones[zone]
			var slope := land.slope_at(q.x, q.y)
			var dens := per_ha * float(zd.cover) / 0.3
			var sp: PlantSpecies = null
			if roll < dens * cell_ha and slope < 0.6:
				var dom: Array = zd.dominant
				var com: Array = zd.companion
				if not dom.is_empty() and (com.is_empty() or rng.randf() < dom_share):
					sp = dom[rng.randi() % dom.size()]
				elif not com.is_empty():
					sp = com[rng.randi() % com.size()]
			elif roll < (dens + gnd_ha) * cell_ha and (q - land.center).length() < gnd_in and slope < 0.45:
				var gl: Array = zd.ground if not (zd.ground as Array).is_empty() else ((zones.get("flats", {}) as Dictionary).get("ground", []) as Array)
				if not gl.is_empty():
					sp = gl[rng.randi() % gl.size()]
			if sp == null:
				continue
			var h := lerpf(sp.height_m.x, sp.height_m.y, pow(rng.randf(), 1.6))
			var tall := h >= TREE_M and sp.tier != PlantSpecies.Tier.GROUND
			# The wash's bed stays open sand (its floods scour it): its trees
			# stand on the banks, so the bed runs out pale toward the butte.
			if tall and land.in_wash(q) > BED_OPEN:
				continue
			if tall:
				# Clear of the next tree.
				var key := Vector2i(floori(q.x / (clear * 2.0)), floori(q.y / (clear * 2.0)))
				var near_tree := false
				for dj in range(-1, 2):
					for di in range(-1, 2):
						for t in tree_grid.get(key + Vector2i(di, dj), []):
							if (t as Vector2).distance_to(q) < clear:
								near_tree = true
				if near_tree:
					continue
				if not tree_grid.has(key):
					tree_grid[key] = []
				(tree_grid[key] as Array).append(q)
				trees.append([q, h, sp])
			var y := land.height_at(q.x, q.y) - 0.04 * h
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * h)
			var xf := Transform3D(basis, Vector3(q.x, y, q.y))
			var idx := SpeciesDB.index_of(sp)
			var layout := rng.randi_range(0, 2) if TreeLayouts.branchy(sp) else -1
			var bk := Vector2i(floori((q.x - lo.x) / BLOCK_M), floori((q.y - lo.y) / BLOCK_M))
			if not blocks.has(bk):
				blocks[bk] = {}
			var b: Dictionary = blocks[bk]
			var near_key := Vector3i(idx, layout, 1)
			var far_key := Vector3i(idx, -1, 0)
			if not b.has(near_key):
				b[near_key] = []
			if not b.has(far_key):
				b[far_key] = []
			(b[near_key] as Array).append(xf)
			(b[far_key] as Array).append(xf)
			counts[sp.name] = int(counts.get(sp.name, 0)) + 1
			if not zone_counts.has(zone):
				zone_counts[zone] = {}
			(zone_counts[zone] as Dictionary)[sp.name] = int((zone_counts[zone] as Dictionary).get(sp.name, 0)) + 1
			placed += 1
	var near_m := maxf(float(PL.get("near_m", 110.0)), 20.0)
	var all := SpeciesDB.all()
	for bk in blocks:
		var b: Dictionary = blocks[bk]
		for key: Vector3i in b:
			var sp: PlantSpecies = all[key.x]
			var near := key.z == 1
			var lod := PlantMeshes.LOD_NEAR if near else PlantMeshes.LOD_FAR
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.use_colors = true
			mm.mesh = PlantMeshes.mesh_for(sp, lod, key.y)
			var xfs: Array = b[key]
			mm.instance_count = xfs.size()
			for k in xfs.size():
				mm.set_instance_transform(k, xfs[k])
				mm.set_instance_color(k, Color.WHITE)
				# Full leaves, no moss, no sport (the foliage shader's custom data).
				mm.set_instance_custom_data(k, Color(0, 0, 0, 0))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s_%d_%d" % [sp.name.replace(" ", "_"), "near" if near else "far", bk.x, bk.y]
			mmi.multimesh = mm
			mmi.material_override = _material(sp)
			if near:
				mmi.visibility_range_end = near_m
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sp.tier != PlantSpecies.Tier.GROUND else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mmi.visibility_range_begin = near_m
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
	trees_placed = trees
	# The trees' trunks, in your way.
	if not trees.is_empty():
		var body := StaticBody3D.new()
		body.name = "Trunks"
		body.collision_layer = PropCollision.WORLD_LAYER
		add_child(body)
		for t in trees:
			var q: Vector2 = t[0]
			var h := float(t[1])
			var r := clampf(0.03 * h, 0.12, 0.35)
			var shape := CylinderShape3D.new()
			shape.radius = r
			shape.height = minf(h, 3.0)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(q.x, land.height_at(q.x, q.y) + shape.height * 0.5, q.y)
			body.add_child(cs)


## The association grown in `zone`: the one named, else the one whose
## `where` reads like it, in the world's realm (or any realm).
func _association(assocs: Array, name: String, zone: String, realm: String) -> Dictionary:
	if name != "":
		for a in assocs:
			if a is Dictionary and str(a.get("name", "")) == name:
				return a
	var words := {"wash": ["wash", "arroyo", "riparian", "channel"], "upland": ["slope", "bajada", "hill", "rocky", "upland"], "flats": ["flat", "plain", "valley", "floor"]}
	for a in assocs:
		if not a is Dictionary:
			continue
		var r = a.get("realm", "")
		var realms: Array = r if r is Array else [str(r)]
		if realm != "" and not realms.has(realm) and not realms.has("any"):
			continue
		var where := (str(a.get("where", "")) + " " + str(a.get("name", ""))).to_lower()
		for w in words.get(zone, []):
			if where.contains(str(w)):
				return a
	return {}


## The species these names are (SpeciesDB), those the engine has.
static func _species(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var sp := SpeciesDB.find(str(n))
		if sp != null:
			out.append(sp)
	return out


## A species' material as in play (PlantMeshes.material_for), its leaves
## kept all year (no seasons in Torchfire 1, §ET.2).
func _material(sp: PlantSpecies) -> Material:
	if _mats.has(sp.name):
		return _mats[sp.name]
	var m: Material = PlantMeshes.material_for(sp)
	if sp.deciduous and m is ShaderMaterial:
		m = (m as ShaderMaterial).duplicate()
		Look.register(m as ShaderMaterial)
		(m as ShaderMaterial).set_shader_parameter("sp_deciduous", false)
	_mats[sp.name] = m
	return m
