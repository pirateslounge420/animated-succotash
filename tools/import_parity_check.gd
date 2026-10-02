extends SceneTree
## The world's textures read from their PNGs on disk (Look.tile_image,
## design 1 Oct §CG) are the importer's, pixel for pixel: with the import
## cache present, every §AG tile through both ways, compared at every mip
## level; and the cloud panorama (no mips). Run with the cache present:
##   godot --headless --path . --script tools/import_parity_check.gd

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	var dir := str(Look.RETRO.get("tiles_dir", ""))
	for name in ["grass", "dirt", "sand", "bark", "leaves", "leaf_card", "stone", "water"]:
		var path := "res://%s/%s.png" % [dir, name]
		var a := Look.tile_image(path, "disk")
		var b := Look.tile_image(path, "import")
		if a == null or b == null:
			ok(false, "%s: both ways read (disk %s, import %s)" % [name, a != null, b != null])
			continue
		ok(_same(a, b, name), "%s: disk and import identical at all %d mip levels (%dx%d)" % [name, a.get_mipmap_count() + 1, a.get_width(), a.get_height()])
	var pano := "res://%s/cloud_pano.png" % dir
	var pa := ResFiles.disk_image(pano)
	var pb := ResFiles.imported_image(pano)
	if pa != null and pb != null:
		pa.fix_alpha_edges()
		pa.convert(Image.FORMAT_RGBA8)
		pb.convert(Image.FORMAT_RGBA8)
		ok(_same(pa, pb, "cloud_pano"), "cloud_pano: disk and import identical (%dx%d)" % [pa.get_width(), pa.get_height()])
	else:
		ok(false, "cloud_pano: both ways read")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Same size, format, mip count and bytes at every level (the first level
## that differs is named).
func _same(a: Image, b: Image, name: String) -> bool:
	if a.get_size() != b.get_size() or a.get_format() != b.get_format() or a.get_mipmap_count() != b.get_mipmap_count():
		print("   %s: %s %s %d mips vs %s %s %d mips" % [name, a.get_size(), a.get_format(), a.get_mipmap_count(), b.get_size(), b.get_format(), b.get_mipmap_count()])
		return false
	var da := a.get_data()
	var db := b.get_data()
	for level in a.get_mipmap_count() + 1:
		var start := a.get_mipmap_offset(level)
		var end := a.get_mipmap_offset(level + 1) if level < a.get_mipmap_count() else da.size()
		var diff := 0
		for i in range(start, end):
			if da[i] != db[i]:
				diff += 1
		if diff > 0:
			print("   %s: mip %d differs in %d of %d bytes" % [name, level, diff, end - start])
			return false
	return true
