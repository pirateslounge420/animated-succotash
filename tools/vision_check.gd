extends SceneTree
## The Aztec brew's vision (design §FN.5, queue 83; BrewVision's palette
## swap, HiddenCarvings; data/brew.json plants.teonanacatl_aztecorum.vision
## palette and carvings), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/vision_check.gd
## Asserts:
##  1. the data: the temple's plant's vision has a palette block and a
##     carvings block, each with a _help line; the tomb's has neither;
##  2. the hidden carvings are in the temple from the start: over each of
##     the calendar room's 20 day-sign panels (on its walls, inside the
##     room), its two friezes (the left one the picture-history, kinds 1-4,
##     the right one glyphs), a glyph on each corner face of the blood
##     altar's round chamber; none in a tomb;
##  3. sober they are not drawn (hidden, reveal 0) and the frame has no
##     palette swap;
##  4. under the brew they are drawn (from the next frames, reveal the
##     vision's envelope), the swap shown at palette.amount times the same
##     envelope, the placeholder tint and bands not drawn; their time runs
##     (the glyphs change and breathe);
##  5. the bounds: no Light3D, no collision under them, an unshaded material
##     (its glow is paint); the floor's lit test, the light field (its
##     sources and its level at every panel), the boss's state, place and
##     speed, your torch's burn and every holder's state the same with them
##     drawn as without;
##  6. the fade ends clean: at its end the carvings hidden, reveal 0, the
##     swap hidden at amount 0, the vision stopped.
## The rest (nothing else changes while the brew runs: data tables, the
## environment, the grade, the look, the camera, harm, the save, your walk,
## the clocks) is brew_check's with THEME=aztec_temple, the same drink.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	WorldSave.read_only = true
	Residents.stay_asleep = true
	CrawlerSave.force_first = "aztec_temple"
	CrawlerSave.aztec_on = true
	Surface.use_theme("aztec_temple")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	# 1. The data.
	var D := Brew.data()
	var id := SacredVine.plant_id()
	var V: Dictionary = SacredVine.plant_data(id).get("vision", {})
	var help: Dictionary = D.get("_help", {})
	ok(id == "teonanacatl_aztecorum" and V.get("palette") is Dictionary and V.get("carvings") is Dictionary and str(help.get("vision_aztec", "")).contains("§FN.5"), "the temple's brew (%s): its vision a palette swap and the hidden carvings, its _help line citing §FN.5" % id)
	var tomb_v: Dictionary = SacredVine.plant_data("ololiuhqui").get("vision", {})
	ok(not tomb_v.has("palette") and not tomb_v.has("carvings"), "the tomb's brew keeps its placeholder tint (no palette, no carvings)")
	ok(HiddenCarvings.make(TombKit.layout(seed_v, "tomb"), null) == null, "no hidden carvings in a tomb")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked:
		await process_frame
	await _frames(10)
	var boss: Variant = main.get("boss")
	if boss is Boss:
		(boss as Boss).auto = false
	var hc := main.hidden_carvings
	ok(main.lay.theme == "aztec_temple" and hc != null and hc.is_inside_tree(), "the temple has its hidden carvings from the start (%s)" % ("HiddenCarvings" if hc != null else "none"))
	if hc == null:
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	_layout(main, hc)
	var vis := main.brew.vision
	# 3. Sober.
	ok(not hc.visible and hc.reveal == 0.0 and not vis.active and not vis.swap.visible, "sober: the carvings not drawn (reveal 0), no palette swap")
	var before := _numbers(main, hc)
	# 4. Under the brew.
	vis.start(id, V)
	await _frames(2)
	ok(hc.visible and hc.reveal > 0.0 and absf(hc.reveal - vis.envelope()) < 1e-4 and vis.swap.visible, "under the brew they come up from the next frames (reveal %.3f, the vision's envelope)" % hc.reveal)
	await _frames(int(float(V.get("fade_in_s", 4.0)) * 60.0) + 30)
	var amt := float((V.palette as Dictionary).get("amount", 0.6))
	ok(absf(hc.reveal - 1.0) < 1e-3 and absf(vis.palette_amount() - amt) < 1e-3 and vis.has_palette(), "full after fade_in_s: the carvings at 1, the palette swap at its amount %.2f" % amt)
	ok(absf(vis.level() - vis.palette_amount()) < 1e-6, "the placeholder tint and bands replaced by the swap (level is the swap's amount)")
	var t0 := hc.t
	await _frames(60)
	ok(hc.t > t0 + 0.9 and float((hc._mat as ShaderMaterial).get_shader_parameter("t")) > t0, "their time runs while it lasts (%.2f s): the glyphs change, multiply and breathe" % hc.t)
	# 5. The bounds.
	ok(hc.find_children("*", "Light3D", true, false).is_empty() and hc.find_children("*", "CollisionObject3D", true, false).is_empty(), "no light and no collision of their own")
	var code := ((hc._mat as ShaderMaterial).shader as Shader).code
	ok(code.contains("unshaded") and not code.contains("LIGHT"), "their glow is paint (an unshaded material, no light function)")
	var during := _numbers(main, hc)
	var diff: Array = []
	for k in before:
		if str(before[k]) != str(during[k]):
			diff.append("%s: %s against %s" % [k, str(before[k]), str(during[k])])
	ok(diff.is_empty(), "with them drawn as without: the floor's lit test, the light field (its sources, its level at each of %d panels), the boss (state, place, speed), every holder, your torch%s" % [hc.panels.size(), "" if diff.is_empty() else " (changed: %s)" % "; ".join(diff)])
	# 6. The fade ends clean.
	vis.t = vis.length_s() - 0.5
	await _frames(20)
	ok(hc.visible and hc.reveal > 0.0 and hc.reveal < 0.2, "fading near the end (%.3f)" % hc.reveal)
	await _frames(30)
	ok(not vis.active and not hc.visible and hc.reveal == 0.0 and not vis.swap.visible and float((vis.swap.material as ShaderMaterial).get_shader_parameter("amount")) == 0.0, "the fade ends clean: the vision stopped, the carvings hidden at 0, the swap hidden at 0")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## 2. Where they are.
func _layout(main: CrawlerMain, hc: HiddenCarvings) -> void:
	var cal: Array = []
	var hist: Array = []
	var frieze_g: Array = []
	var altar: Array = []
	for pn in hc.panels:
		var d: Dictionary = pn
		if d.room == "altar":
			altar.append(d)
		elif int(d.kind) > 0:
			hist.append(int(d.kind))
		elif (d.size as Vector2).y < 0.8 and (d.size as Vector2).x != (d.size as Vector2).y:
			frieze_g.append(d)
		else:
			cal.append(d)
	var pc_cal := {}
	var pc_alt := {}
	for pc in main.lay.pieces:
		if str((pc as Dictionary).get("big_room", "")) == "aztec_calendar_room":
			pc_cal = pc
		elif str((pc as Dictionary).get("big_room", "")) == "aztec_blood_altar":
			pc_alt = pc
	var inside := true
	for d in cal + altar:
		var pc: Dictionary = pc_cal if d.room == "calendar" else pc_alt
		var aa := Delves.along_across(pc, Vector2((d.at as Vector3).x, (d.at as Vector3).z))
		if aa.x < -0.5 or aa.x > float(pc.len) + 0.5 or absf(aa.y) > float(pc.half) + 0.5:
			inside = false
	ok(cal.size() == 20 and AztecBuild.calendar_plan(pc_cal).size() == 20, "a hidden glyph over each of the calendar room's 20 day-sign panels")
	ok(hist == [1, 2, 3, 4] and frieze_g.size() == 4, "its left frieze a wordless picture-history, read left to right (kinds %s: footprints, reeds in water, a stepped temple, a rayed disc), its right frieze %d glyphs" % [str(hist), frieze_g.size()])
	ok(altar.size() == 8, "a glyph on each of the blood altar's 8 corner faces (%d)" % altar.size())
	ok(inside, "every one inside its own room, on its walls")


## What play reads, now: the floor's lit test, the light field, the boss,
## the holders, your torch.
func _numbers(main: CrawlerMain, hc: HiddenCarvings) -> Dictionary:
	var out := {}
	out["floor_lit"] = TombFloors.floor_lit(main.fires, main.lay, 0)
	var b: Variant = main.get("boss")
	if b is Boss:
		var bb := b as Boss
		out["boss"] = [bb.state, bb.head.snapped(Vector3.ONE * 0.001), snappedf(bb.speed, 0.001), bb.noticed]
		if bb.light != null:
			out["sources"] = bb.light.sources().size()
			var lv: Array = []
			for pn in hc.panels:
				lv.append(snappedf(bb.light.at(pn.at), 0.0001))
			out["light_at_panels"] = lv
	var lit := 0
	for h in main.fires.holders if main.fires.get("holders") != null else []:
		if h is Node and (h as Node).get("lit") == true:
			lit += 1
	out["holders_lit"] = lit
	var p := main.player
	# (Its burn over a second, under the brew and not, is brew_check's.)
	out["torch"] = p.torch.lit()
	out["lights"] = get_root().find_children("*", "Light3D", true, false).size()
	return out
