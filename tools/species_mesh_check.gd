extends SceneTree
## Loads SpeciesDB and builds every species' mesh at the near and far
## levels (design §CC: after the trim, every survivor and every added
## entry must build and find its tiles). Prints warnings the loader and
## builder raise, and a RESULT line.
##   godot --headless --path . --script tools/species_mesh_check.gd

func _initialize() -> void:
	var all := SpeciesDB.all()
	var fails := 0
	for sp in all:
		for lod in [PlantMeshes.LOD_NEAR, PlantMeshes.LOD_FAR]:
			var m := PlantMeshes.mesh_for(sp, lod)
			if m == null or m.get_surface_count() == 0:
				print("FAIL  %s (%s %s) builds no mesh at lod %d" % [sp.name, sp.genus, sp.species, lod])
				fails += 1
		# Leafless entries (fungi, lichens) carry no tiles: they draw from
		# their colours.
		if sp.tiles.is_empty() and sp.leaf_type not in ["", "none"]:
			print("WARN  %s has no tiles in the atlas" % sp.name)
		else:
			PlantMeshes.material_for(sp)
	print("RESULT species %d, fails %d" % [all.size(), fails])
	quit(1 if fails > 0 else 0)
