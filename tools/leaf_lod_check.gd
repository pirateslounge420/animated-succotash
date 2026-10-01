extends SceneTree
## Run: STAMP=1 godot --headless --path . --fixed-fps 60 --script tools/leaf_lod_check.gd
## Mike, 1 Oct, bug 1 (leaf cards drawn as solid shards): at the dev spot,
## list the nearest five trees: their chunk's plant LOD, the mesh they are
## drawn with and how many leaf cards it holds, and whether those cards
## cut out (the material's leaf tile and leaf-card texture are set and
## carry alpha; the shader cuts at ALPHA_SCISSOR 0.5). Also the detail
## ring the profile runs. PASS/FAIL lines, then RESULT.

var main
var world
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	world = get_root().get_node("World")
	world.pin(42, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	await frames(60)
	# Let the chunks round the camp build and their detail come in.
	for i in 40:
		await frames(30)
		if main.chunks.chunks.size() >= 9 and _detail_ready():
			break
	var pp: Vector3 = main.player.global_position
	# FROM=camp lists from the camp's fire (the dev-view frame's subject);
	# N=<count> lists more than five.
	if OS.get_environment("FROM") == "camp":
		pp = main.camp._fire.global_position
	var count := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 5
	print("[lod] profile %s, detail ring %d chunks (view %d), DETAIL_CHUNKS env '%s'" % [Tuning.profile(), main.chunks.detail_radius_chunks, main.chunks.view_radius_chunks, OS.get_environment("DETAIL_CHUNKS")])
	ok(Tuning.profile() != "ambient" or OS.get_environment("DETAIL_CHUNKS") != "" or main.chunks.detail_radius_chunks == mini(2, main.chunks.view_radius_chunks), "the ambient profile runs a 2-chunk detail ring (%d)" % main.chunks.detail_radius_chunks)
	# The nearest five trees.
	var near: Array = []
	for key in main.chunks.chunks:
		var chunk: TerrainChunk = main.chunks.chunks[key]
		for i in chunk.trees.size():
			var d := chunk.tree_base(i).distance_to(pp)
			near.append([d, chunk, i])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var card_tex: Texture2D = Look.texture("leaf_card")
	var card_alpha := card_tex != null and card_tex.get_image().detect_alpha() != Image.ALPHA_NONE
	ok(card_alpha, "the leaf-card texture carries alpha (the cutout edge)")
	var cut_all := true
	for k in mini(count, near.size()):
		var d: float = near[k][0]
		var chunk: TerrainChunk = near[k][1]
		var i: int = near[k][2]
		var sp := chunk.tree_species(i)
		var t: Array = chunk.trees[i]
		var pick: int = t[4]
		var lod: int = chunk._plant_lod
		var mesh_lod: int = chunk.plant_lod(chunk)
		var mesh := PlantMeshes.mesh_for(sp, mesh_lod, TreeLayouts.layout_of(pick) if pick >= 0 else -1)
		var cards := _card_count(mesh)
		var mat := PlantMeshes.material_for(sp)
		var tiled := bool(mat.get_shader_parameter("sp_tiled"))
		var leaf_tile: Texture2D = mat.get_shader_parameter("sp_leaf")
		var tile_alpha := leaf_tile != null and leaf_tile.get_image().detect_alpha() != Image.ALPHA_NONE
		var card_set: Texture2D = mat.get_shader_parameter("look_tex_leaf_card")
		var cut := cards > 0 and card_set != null and card_alpha and (not tiled or tile_alpha)
		cut_all = cut_all and (cut or cards == 0)
		print("[tree %d] %s (%s, %.0f m tall) %.0f m: chunk LOD %s, mesh LOD %s layout %d, %d leaf cards, tiled %s, leaf tile %s, card tex %s -> cutout %s" % [
			k, sp.name, PlantSpecies.Shape.keys()[sp.shape] if sp.shape < PlantSpecies.Shape.keys().size() else str(sp.shape), float(t[1]), d, _lod_name(lod), _lod_name(mesh_lod), TreeLayouts.layout_of(pick) if pick >= 0 else -1, cards, tiled,
			("alpha" if tile_alpha else ("opaque" if leaf_tile != null else "missing")), ("set" if card_set != null else "MISSING"), cut])
	ok(near.size() >= 5, "five trees stand within the loaded chunks (%d)" % near.size())
	# Trees by distance (1 Oct, Mike's Mac): every branchy tree within
	# ranges.tree_full_m is drawn with its full (hero) mesh, as before the
	# bands; within tree_shadow_m its copy casts the sun's shadow; past it,
	# within tree_light_m, the light tree; beyond, the picture.
	var full_ok := 0
	var full_n := 0
	var shadow_bad := 0
	var light_n := 0
	var light_bad := 0
	for item in near:
		var d: float = item[0]
		if d > TerrainChunk.LIGHT_M + 20.0:
			break
		var chunk: TerrainChunk = item[1]
		var i: int = item[2]
		var t: Array = chunk.trees[i]
		var pick: int = t[4]
		if pick < 0:
			continue
		var sp := chunk.tree_species(i)
		var inst := chunk.tree_instance(i)
		if inst.is_empty():
			continue
		var drawn: Mesh = (inst[0] as MultiMesh).mesh
		var dc := chunk.to_local(main.player.global_position).distance_to(t[0])
		if dc < TerrainChunk.FULL_M - 2.0:
			full_n += 1
			if drawn == PlantMeshes.mesh_for(sp, PlantMeshes.LOD_HERO, TreeLayouts.layout_of(pick)):
				full_ok += 1
			var casts := false
			for ch in chunk.get_children():
				if ch is MultiMeshInstance3D and (ch as MultiMeshInstance3D).multimesh == inst[0]:
					casts = (ch as MultiMeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if casts != (dc < TerrainChunk.SHADOW_M):
				shadow_bad += 1
		elif dc > TerrainChunk.FULL_M + 2.0 and dc < TerrainChunk.LIGHT_M - 2.0:
			light_n += 1
			if drawn != PlantMeshes.mesh_for(sp, PlantMeshes.LOD_LIGHT, TreeLayouts.layout_of(pick)):
				light_bad += 1
	print("[bands] within %.0f m: %d of %d branchy trees on their full mesh; %d casting wrongly; %d light trees out to %.0f m, %d wrong" % [TerrainChunk.FULL_M, full_ok, full_n, shadow_bad, light_n, TerrainChunk.LIGHT_M, light_bad])
	ok(full_n > 0 and full_ok == full_n, "every branchy tree within tree_full_m keeps its full leaf cards (%d of %d)" % [full_ok, full_n])
	ok(shadow_bad == 0, "only the trees within tree_shadow_m cast the sun's shadow (%d wrong)" % shadow_bad)
	ok(light_bad == 0, "between tree_full_m and tree_light_m the light tree (%d of %d wrong)" % [light_bad, light_n])
	ok(cut_all, "every near tree's leaf cards cut out (texture set, alpha present)")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _detail_ready() -> bool:
	for key in main.chunks.chunks:
		var chunk: TerrainChunk = main.chunks.chunks[key]
		if chunk._plant_lod != PlantMeshes.LOD_FAR and not chunk.trees.is_empty():
			return true
	return false


func _lod_name(lod: int) -> String:
	match lod:
		PlantMeshes.LOD_HERO:
			return "hero"
		PlantMeshes.LOD_NEAR:
			return "near"
	return "far (pictures)"


## Triangles of leaf cards (mat_id 2 cards, 5 cluster cards; UV2.x) in a
## plant mesh.
func _card_count(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
	if uv2 == null:
		return 0
	var idx = arrays[Mesh.ARRAY_INDEX]
	var n := 0
	if idx != null and (idx as PackedInt32Array).size() > 0:
		for j in range(0, (idx as PackedInt32Array).size(), 3):
			var m: float = (uv2 as PackedVector2Array)[(idx as PackedInt32Array)[j]].x
			if (m > 1.5 and m < 2.5) or m > 4.5:
				n += 1
	else:
		for j in range(0, (uv2 as PackedVector2Array).size(), 3):
			var m: float = (uv2 as PackedVector2Array)[j].x
			if (m > 1.5 and m < 2.5) or m > 4.5:
				n += 1
	return n
