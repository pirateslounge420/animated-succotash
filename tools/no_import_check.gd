extends SceneTree
## The game run the way Mike's Mac had it (design 1 Oct §CG): no import
## cache. Run by tools/no_import_check.sh, which moves .godot/imported
## aside (the class cache stays), runs this, puts it back whatever happens,
## and fails on any "Failed loading resource" line in the output.
##   tools/no_import_check.sh
## Boots a fresh random world (play's rule, no pins) and asserts: every
## look_tex_* on the plant, terrain, water and ruin materials is a real
## texture; the leaf card cuts out exactly what its PNG does (counted from
## the file); the species tiles load; the HUD's face is VT323. Cleans up the
## world it made and puts the player's last-world pointer back.

var fails := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	Bow.need_capture = false
	var cache_hidden := not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://.godot/imported"))
	print("[no_import] the import cache is %s" % ("hidden" if cache_hidden else "PRESENT (run tools/no_import_check.sh)"))
	ok(cache_hidden, "the run has no import cache (.godot/imported moved aside)")
	# A fresh random world: start with no last-world pointer.
	var had_pointer := FileAccess.file_exists(WorldSave.LAST_PATH)
	var old_pointer := FileAccess.get_file_as_string(WorldSave.LAST_PATH) if had_pointer else ""
	if had_pointer:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSave.LAST_PATH))
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 120:
		await process_frame
	print("[no_import] world %d · %s" % [world.world_seed, main.camp.site])
	# The world's materials and their look textures.
	var mats := {
		"plant": PlantMeshes.material(),
		"terrain": TerrainChunk._terrain_mat,
		"salt water": TerrainChunk._salt_mat,
		"fresh water": TerrainChunk._fresh_mat,
		"ruin": RuinBuilder.material(),
	}
	for key in mats:
		var m: ShaderMaterial = mats[key]
		if m == null or m.shader == null:
			ok(false, "the %s material exists" % key)
			continue
		var used: Array[String] = []
		var empty: Array[String] = []
		for u in m.shader.get_shader_uniform_list(true):
			var uname := str(u.name)
			if not uname.begins_with("look_tex_"):
				continue
			used.append(uname)
			var t = m.get_shader_parameter(uname)
			if not (t is Texture2D) or (t as Texture2D).get_width() <= 0:
				empty.append(uname)
		ok(not used.is_empty() and empty.is_empty(), "the %s material: %d look textures, every one a real texture%s" % [key, used.size(), (" (empty: %s)" % str(empty)) if not empty.is_empty() else ""])
	# The leaf card cuts out what its PNG does.
	var path := "res://%s/leaf_card.png" % str(Look.RETRO.get("tiles_dir", ""))
	var file_img := ResFiles.disk_image(path)
	var want := _clear(file_img) if file_img != null else -1
	var got := _clear(Look.texture("leaf_card").get_image())
	ok(want > 0 and got == want, "the leaf card cuts out what its PNG does: %d of %d texels clear (the file: %d)" % [got, file_img.get_width() * file_img.get_height() if file_img else 0, want])
	print("[no_import] world textures: %s · %s" % [Look.sources_text(), str(Look.sources)])
	ok(not Look.sources.values().has("painted"), "every world texture came from its file, none painted (%s)" % Look.sources_text())
	# The species tiles (read from disk since §AH).
	var sp_mats := PlantMeshes.species_materials()
	var with_leaf := 0
	var null_leaf := 0
	for k in sp_mats:
		var m: ShaderMaterial = sp_mats[k]
		if m.get_shader_parameter("sp_leaf") is Texture2D:
			with_leaf += 1
		else:
			null_leaf += 1
	ok(with_leaf > 0 and null_leaf == 0, "the species tiles load: %d species materials with their leaf tile, %d without" % [with_leaf, null_leaf])
	# The HUD's face.
	ok(ThemeDB.fallback_font.get_font_name() == "VT323", "the HUD's face is VT323 (%s, from %s)" % [ThemeDB.fallback_font.get_font_name(), HudText.loaded_from])
	# Clean up the world this made; the player's own pointer goes back.
	WorldSave.read_only = true
	var made := ProjectSettings.globalize_path("user://worlds/%d.json" % world.world_seed)
	if FileAccess.file_exists(made):
		DirAccess.remove_absolute(made)
	if had_pointer:
		var f := FileAccess.open(WorldSave.LAST_PATH, FileAccess.WRITE)
		if f:
			f.store_string(old_pointer)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSave.LAST_PATH))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Texels with alpha under one half (the cutout's threshold).
func _clear(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.5:
				n += 1
	return n
