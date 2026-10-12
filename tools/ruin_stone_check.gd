extends SceneTree
## A ruin's own stone, for the styles cut like queue 79's Aztec stone
## (squared, coursed blocks): the Egyptian ruin's big sandstone blocks
## (design §FO.1, queue 88: style egyptian_pyramid, preset great_blocks)
## and the Maya temple's limestone (§FQ.1, queue 94: style maya_temple,
## preset dressed_blocks). Run once per style:
##   STYLE=egyptian_pyramid SEED=7 godot --headless --path . --fixed-fps 60 --script tools/ruin_stone_check.gd
##   STYLE=maya_temple SEED=7 godot --headless --path . --fixed-fps 60 --script tools/ruin_stone_check.gd
## Asserts, as aztec_stone_check does for its style:
##  1. the data: the style and its preset are there and registered;
##     style_by_theme keeps the tomb, the snow ruins, the default and the
##     Aztec temple as before;
##  2. the tomb unchanged (its stone hash printed, to compare with a run
##     before), and the Aztec temple's stone still its own;
##  3. the cut: the preset gives every wall face true courses of
##     rectangles, inside the face, tiled whole, joints staggered;
##  4. one stone: tombs of seeds 1, 7 and 42 built in the style with
##     RuinBuilder's palette poisoned: walls, floors, ceilings, doors,
##     stairs and niches all built, every stone vertex within the tint +-
##     spread, none poisoned, every door square.

const SEEDS := [1, 7, 42]
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seed_value := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7
	var th := OS.get_environment("STYLE") if OS.get_environment("STYLE") != "" else "egyptian_pyramid"
	var M: Dictionary = Tuning.table("masonry")
	var styles: Dictionary = M.get("styles", {})
	var by: Dictionary = M.get("style_by_theme", {})
	# 1. The data.
	var pre := str(((styles.get(th, {}) as Dictionary).get("walls", {}) as Dictionary).get("preset", ""))
	print("  style %s, walls %s" % [th, pre])
	ok(styles.has(th) and pre != "" and (M.get("presets", {}) as Dictionary).has(pre) and str(((M.get("presets", {}) as Dictionary).get(pre, {}) as Dictionary).get("cut", "")) == "squared", "masonry.json has the %s style and its squared preset %s" % [th, pre])
	ok(str(by.get("tomb")) == "andean_tomb" and str(by.get("snow_ruins")) == "passage_grave_snow" and str(by.get("default")) == "andean_tomb", "style_by_theme as before: tomb andean_tomb, snow_ruins passage_grave_snow, default andean_tomb")
	ok(str(by.get("aztec_temple")) == "aztec_temple" and str(RuinStyle.val("walls.preset", "", "aztec_temple")) == "coursed_blocks" and RuinStyle.tint("aztec_temple").is_equal_approx(Color("#6e3a30")), "the Aztec temple keeps its own style: coursed_blocks, #6e3a30")
	ok(RuinStyle.style_name(th) == th and str(RuinStyle.val("walls.preset", "", th)) == pre and bool(RuinStyle.val("rule.no_general_palette", false, th)), "the %s theme takes its own style, walls %s, no general palette" % [th, pre])
	ok(str((M.get("by_theme", {}) as Dictionary).get(th, "")) == pre, "by_theme agrees with the style's walls.preset")
	# 2. The tomb unchanged.
	var lay := TombKit.layout(seed_value)
	var data := TombBuild.build(lay)
	var hc := hash([Array(data.v as PackedVector3Array), Array(data.c as PackedColorArray)])
	print("  the tomb, seed %d: %d vertices, stone hash %d" % [seed_value, (data.v as PackedVector3Array).size(), hc])
	ok(RuinStyle.style_name("tomb") == "andean_tomb" and FittedStone.preset_name() == "fitted_small", "the tomb is still built in andean_tomb, its walls fitted_small")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tomb_cells := FittedStone.cells(6.0, 2.6, rng)
	ok(_squared_share(tomb_cells) < 0.5, "the tomb's walls are still fitted polygons (%.0f%% of %d cells rectangles)" % [100.0 * _squared_share(tomb_cells), tomb_cells.size()])
	# 3. The cut.
	FittedStone.preset_override = pre
	var bad := 0
	var faces := 0
	var stagger_bad := 0
	var sizes: Array = ((M.get("presets", {}) as Dictionary).get(pre, {}) as Dictionary).get("stone_m", [0.0, 99.0])
	var wide := 0.0
	var nb := 0
	for i in 40:
		rng.seed = 1000 + i
		var length := rng.randf_range(1.2, 14.0)
		var height := rng.randf_range(1.0, 4.0)
		var cs := FittedStone.cells(length, height, rng)
		faces += 1
		var area := 0.0
		var rows := {}
		for c in cs:
			var poly: PackedVector2Array = c[1]
			var r := _rect(poly)
			if r.size.x <= 0.0 or r.position.x < -1e-4 or r.position.y < -1e-4 or r.end.x > length + 1e-4 or r.end.y > height + 1e-4:
				bad += 1
			area += r.get_area()
			if r.size.x < length - 1e-3 and r.position.x > 1e-4 and r.end.x < length - 1e-4:
				wide += r.size.x
				nb += 1
			var key := snappedf(r.position.y, 0.001)
			if not rows.has(key):
				rows[key] = []
			if r.end.x < length - 1e-4:
				(rows[key] as Array).append(snappedf(r.end.x, 0.001))
		if _squared_share(cs) < 1.0 or absf(area - length * height) > 1e-3 * length * height:
			bad += 1
		var ks := rows.keys()
		ks.sort()
		for j in range(1, ks.size()):
			for x in rows[ks[j]]:
				for x0 in rows[ks[j - 1]]:
					if absf(float(x) - float(x0)) < 0.05:
						stagger_bad += 1
	FittedStone.preset_override = ""
	ok(bad == 0, "%s cuts every wall face into true courses of rectangles, inside the face and tiling it whole (%d faces, %d off)" % [pre, faces, bad])
	print("  inner blocks: %d, mean width %.2f m (stone_m %s)" % [nb, wide / maxf(nb, 1), str(sizes)])
	ok(nb > 0 and wide / nb >= float(sizes[0]) * 0.8 and wide / nb <= float(sizes[1]) * 1.1, "the blocks are the preset's size: mean width %.2f m within stone_m %s" % [wide / maxf(nb, 1), str(sizes)])
	ok(stagger_bad == 0, "no joint runs straight on from one course into the next (%d)" % stagger_bad)
	# 4. One stone.
	var tint := RuinStyle.tint(th)
	var spread := RuinStyle.spread(th)
	ok(str(RuinStyle.val("stone.tint", "", th)).begins_with("#") and tint.is_equal_approx(Color(str(RuinStyle.val("stone.tint", "", th)))), "its one stone: tint #%s, each stone within %.2f of it" % [tint.to_html(false), spread])
	TombBuild.bare = true
	TombBuild.poison = true
	var stone_v := 0
	var outside := 0
	var poisoned := 0
	var n := {"walls": 0, "floors": 0, "ceilings": 0, "doors": 0, "stairs": 0, "niches": 0}
	var square_bad := 0
	var lo := Color(1, 1, 1)
	var hi := Color(0, 0, 0)
	for s in SEEDS:
		var l := TombKit.layout(int(s))
		l["theme"] = th
		var d := TombBuild.build(l)
		ok(FittedStone.preset_name() == pre, "seed %d built with the %s walls" % [s, pre])
		var v: PackedVector3Array = d.v
		var c: PackedColorArray = d.c
		var m: PackedVector2Array = d.m
		var runs: Array = d.tags
		var ri := 0
		var tag := TombBuild.T_NONE
		for i in v.size():
			while ri < runs.size() and int(runs[ri][0]) <= i:
				tag = int(runs[ri][1])
				ri += 1
			var col := c[i]
			if col.r > col.g * 2.5 + 0.05 and col.b > col.g * 2.5 + 0.05 and absf(col.r - col.b) < 0.3:
				poisoned += 1
			var kind := int(round(m[i].x))
			if kind == RuinBuilder.LEAF_M or kind == FittedStone.DUST_M or tag != TombBuild.T_STONE:
				continue
			stone_v += 1
			lo = Color(minf(lo.r, col.r), minf(lo.g, col.g), minf(lo.b, col.b))
			hi = Color(maxf(hi.r, col.r), maxf(hi.g, col.g), maxf(hi.b, col.b))
			if absf(col.r - tint.r) > spread + 1e-3 or absf(col.g - tint.g) > spread + 1e-3 or absf(col.b - tint.b) > spread + 1e-3:
				outside += 1
		n.walls += _count(d.walls)
		n.floors += _count(d.flags)
		n.ceilings += _count(d.slabs)
		n.doors += _count(d.doors)
		n.niches += _count(d.niches)
		for pc in l.pieces:
			if str(pc.kind) == "stair":
				n.stairs += 1
		for dr in (d.doors if d.doors is Array else []):
			if absf(float(dr.top) - float(dr.foot)) > 1e-4:
				square_bad += 1
	TombBuild.bare = false
	TombBuild.poison = false
	print("  over seeds %s: %d stone vertices from #%s to #%s; %s" % [str(SEEDS), stone_v, lo.to_html(false), hi.to_html(false), str(n)])
	ok(n.walls > 0 and n.floors > 0 and n.ceilings > 0 and n.doors > 0 and n.stairs > 0 and n.niches > 0, "a wall, floor, ceiling, door, stair and niche are all built in the %s stone" % th)
	ok(stone_v > 100000 and outside == 0, "every stone vertex within the tint +- spread (%d of %d outside)" % [outside, stone_v])
	ok(poisoned == 0, "no surface takes RuinBuilder's general palette: with it poisoned, none shows it (%d)" % poisoned)
	ok(n.doors > 30 and square_bad == 0, "every door a square opening under a flat lintel: its top as wide as its foot (%d doors, %d off)" % [n.doors, square_bad])
	# Back to the tomb: the style's cache keyed by theme, so nothing leaks.
	ok(RuinStyle.tint("tomb").is_equal_approx(Color("#636870")), "the tomb's stone is still #636870")
	print("ruin_stone_check %s: %d fails" % [th, fails])
	quit(1 if fails > 0 else 0)


static func _rect(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## The share of cells that are axis-aligned rectangles.
static func _squared_share(cs: Array) -> float:
	if cs.is_empty():
		return 0.0
	var k := 0
	for c in cs:
		var poly: PackedVector2Array = c[1]
		if poly.size() != 4:
			continue
		var r := _rect(poly)
		var good := true
		for p in poly:
			if not ((absf(p.x - r.position.x) < 1e-4 or absf(p.x - r.end.x) < 1e-4) and (absf(p.y - r.position.y) < 1e-4 or absf(p.y - r.end.y) < 1e-4)):
				good = false
		if good:
			k += 1
	return float(k) / cs.size()


static func _count(x: Variant) -> int:
	if x is int or x is float:
		return int(x)
	if x is Array or x is Dictionary:
		return x.size()
	return 0
