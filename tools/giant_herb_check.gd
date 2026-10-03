extends SceneTree
## The giant herbs and the Amorphophallus leaves, built as Mike asked after
## his 3 Oct 14:34 play ("supposed to be an Alocasia, but it looks nothing
## like one"), headless:
##   godot --headless --path . --script tools/giant_herb_check.gd
## For every Alocasia and Colocasia (shape "umbrella", no aroid block) at
## each level of detail, asserts:
##  - it is a short base, 3-5 stalks and one whole leaf (UV2.x 2.25) per
##    stalk, with no cluster cards (5) and no leaf hull (1);
##  - each leaf hangs from the end of a stalk (its CUSTOM0 point is a
##    stalk's top), points tip up, and is as long as the leaf block says
##    against the plant's height (size_cm, height_m) and as wide as its
##    aspect says;
##  - each leaf's card spans its leaf tile's frame (leaf_frame) once, no
##    more: the tile is drawn once, not as a grid;
##  - each leaf sways on its own stalk's phase, and as much at the stalk's
##    point as the stalk's top does.
## For every Amorphophallus: the aroid leaf is reached (the petiole and its
## forks are bark; the leaf is whole-tile cards, 2.25), never the giant
## herb's stalks.
## Also: every broad leaf tile (leaf_frame) fills its frame: the blade
## touches all four sides of its box, and the back lobes reach below the
## stalk's point on a sagittate or cordate leaf.

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _run() -> void:
	var herbs := 0
	var aroids := 0
	var aroid_bad := 0
	var aroid_herb := 0
	for sp in SpeciesDB.all():
		if not sp.aroid.is_empty():
			aroids += 1
			var a := PlantMeshes.arrays_for(sp, PlantMeshes.LOD_NEAR)
			var m := _mats(a)
			if int(m.get(2.25, 0)) == 0 or int(m.get(0.0, 0)) == 0 or int(m.get(5.0, 0)) > 0:
				aroid_bad += 1
			continue
		if sp.genus not in ["Alocasia", "Colocasia"]:
			continue
		herbs += 1
		for lod in [PlantMeshes.LOD_HERO, PlantMeshes.LOD_NEAR, PlantMeshes.LOD_FAR]:
			_check_herb(sp, lod)
	ok(herbs >= 4, "the Alocasia and Colocasia giant herbs are in the catalogue (%d)" % herbs)
	ok(aroids > 0 and aroid_bad == 0, "every Amorphophallus (%d) is built as the aroid leaf: bark petiole and forks, whole-leaf cards, no cluster cards (%d not)" % [aroids, aroid_bad])
	_check_tiles()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _mats(a: Array) -> Dictionary:
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var out := {}
	for t in range(0, uv2.size(), 3):
		var k := snappedf(uv2[t].x, 0.25)
		out[k] = int(out.get(k, 0)) + 1
	return out


func _check_herb(sp: PlantSpecies, lod: int) -> void:
	# The far level's model (arrays_for gives its flat far picture).
	var a := PlantMeshes.arrays_for(sp, lod) if lod != PlantMeshes.LOD_FAR else PlantMeshes._build(sp, SpeciesDB.index_of(sp), lod)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var cu: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var tag := "%s (level %d)" % [sp.name, lod]
	var m := _mats(a)
	ok(int(m.get(5.0, 0)) == 0 and int(m.get(1.0, 0)) == 0, "%s: no cluster cards and no leaf hull" % tag)
	# The blades: 6 vertices each, in order.
	var blades: Array = []
	for t in range(0, v.size(), 6):
		if absf(uv2[t].x - 2.25) < 0.01:
			blades.append(t)
	# Stalk tops: the highest bark vertex of each twig phase.
	var tops := {}
	for i in v.size():
		if uv2[i].x < 0.5 and cu[i * 4 + 3] >= 0.0:
			var ph := snappedf(cu[i * 4 + 3], 0.0001)
			if not tops.has(ph) or v[i].y > (tops[ph][0] as Vector3).y:
				tops[ph] = [v[i], col[i].a]
	ok(blades.size() >= 3 and blades.size() <= 5 and blades.size() == tops.size(), "%s: %d stalks, %d whole leaves, one on each" % [tag, tops.size(), blades.size()])
	var hm := (sp.height_m.x + sp.height_m.y) * 0.5
	var want_len := clampf((sp.leaf_size_m.x + sp.leaf_size_m.y) * 0.5 / hm, 0.2, 0.6)
	var asp := sp.leaf_aspect if sp.leaf_aspect > 0.2 else 1.5
	var frame := sp.leaf_frame
	var worst_join := 0.0
	var worst_len := 0.0
	var worst_w := 0.0
	var down := 0
	var off_frame := 0
	var bad_sway := 0
	for t in blades:
		var attach := Vector3(cu[t * 4], cu[t * 4 + 1], cu[t * 4 + 2])
		var ph := snappedf(uv2[t].y, 0.0001)
		# The quad's corners: lo-left, lo-right, hi-right (first triangle),
		# hi-left (second triangle's last).
		var lo := (v[t] + v[t + 1]) * 0.5
		var hi := (v[t + 2] + v[t + 5]) * 0.5
		worst_len = maxf(worst_len, absf((hi - lo).length() / want_len - 1.0))
		worst_w = maxf(worst_w, absf((v[t + 1] - v[t]).length() / (want_len / asp) - 1.0))
		if hi.y <= attach.y:
			down += 1
		var join := 1.0
		if tops.has(ph):
			join = attach.distance_to(tops[ph][0]) / want_len
			if absf(col[t].a - float(tops[ph][1])) > 0.02:
				bad_sway += 1
		else:
			bad_sway += 1
		worst_join = maxf(worst_join, join)
		if frame.size() == 5:
			var u_min := minf(uv[t].x, uv[t + 1].x)
			var u_max := maxf(uv[t].x, uv[t + 1].x)
			if absf(u_min - frame[0]) > 1e-3 or absf(u_max - frame[2]) > 1e-3 or absf(uv[t].y - frame[3]) > 1e-3 or absf(uv[t + 2].y - frame[1]) > 1e-3:
				off_frame += 1
	ok(worst_join < 0.1, "%s: every leaf hangs from its stalk's top (farthest %.0f %% of a leaf off)" % [tag, worst_join * 100.0])
	ok(worst_len < 0.02 and worst_w < 0.02, "%s: leaves %.2f of the plant's height long (size_cm over height_m), aspect %.1f (off by %.0f %%, %.0f %%)" % [tag, want_len, asp, worst_len * 100.0, worst_w * 100.0])
	ok(down == 0, "%s: every leaf points tip up (%d don't)" % [tag, down])
	ok(off_frame == 0 and frame.size() == 5, "%s: each card spans its leaf tile's frame once (%d don't; frame %s)" % [tag, off_frame, str(frame)])
	ok(bad_sway == 0, "%s: each leaf sways on its stalk's phase, as much as the stalk's top (%d don't)" % [tag, bad_sway])


func _check_tiles() -> void:
	var seen := {}
	var bad: Array[String] = []
	var n := 0
	for sp in SpeciesDB.all():
		if sp.leaf_frame.size() != 5 or not sp.tiles.has("leaf"):
			continue
		var path: String = sp.tiles["leaf"]
		if seen.has(path):
			continue
		seen[path] = true
		n += 1
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			bad.append(sp.name + " (no tile)")
			continue
		var w := img.get_width()
		var h := img.get_height()
		var fr := sp.leaf_frame
		var x0 := w
		var x1 := -1
		var y0 := h
		var y1 := -1
		var below := 0
		var ya := int(fr[4] * h)
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a > 0.5:
					x0 = mini(x0, x)
					x1 = maxi(x1, x)
					y0 = mini(y0, y)
					y1 = maxi(y1, y)
					if y > ya + 1:
						below += 1
		# The blade's box in pixels, within a pixel or two of its frame.
		var fx0 := fr[0] * w
		var fx1 := fr[2] * w
		var fy0 := fr[1] * h
		var fy1 := fr[3] * h
		var tol := 2.5
		if absf(x0 - fx0) > tol or absf(x1 + 1 - fx1) > tol or absf(y0 - fy0) > tol or absf(y1 + 1 - fy1) > tol:
			bad.append("%s (blade %d-%d x %d-%d, frame %.0f-%.0f x %.0f-%.0f)" % [sp.name, x0, x1, y0, y1, fx0, fx1, fy0, fy1])
		elif sp.leaf_outline in ["sagittate", "cordate"] and below < 6:
			bad.append("%s (no back lobes below the notch)" % sp.name)
	for b in bad:
		print("[tiles]   " + b)
	ok(n > 0 and bad.is_empty(), "every broad leaf tile (%d) fills its frame, with back lobes on the arrowheads and hearts (%d don't)" % [n, bad.size()])
