extends SceneTree
## Leaves are cover, not walls (design §AM, FoliageCover), checked headless
## on the numbers with trees stood at the origin (no world):
##   - looking straight up from under a birch's crown, the share of lines
##     that get through the clusters is about its canopy.gap (± 0.1, the
##     §AJ 4 see-through test done on the cluster spheres; the rendered
##     test is tools/species_row.gd UP=1 with tools/look/measure_look.py);
##   - a still player sitting inside an oak's crown (on a limb, in the
##     hollow inside, design §AL 3) is hidden from the side (§AJ 4: from
##     someone level with it 20 m off, most lines cross several clusters);
##   - from right below, looking up, the same player is seen more often
##     (through the gaps and the bare inner crown);
##   - a creature's flight distance with the player hidden and still is
##     under half of the one in the open (Creature._shy_m's sight part);
##   - an arrow through three clusters keeps (1 - foliage_drag)^3 of its
##     speed.
##
##   ~/bin/godot --headless --path . --script tools/cover_check.gd

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## [[clusters in meters, gap]] for species `name`, layout 0, `h` m tall,
## foot at the origin, upright.
func _tree(name: String, h: float) -> Array:
	var sp := SpeciesDB.find(name)
	var unit := FoliageCover._unit_clusters(SpeciesDB.index_of(sp), 0)
	var cl := PackedVector4Array()
	for u in unit:
		cl.append(Vector4(u.x * h, u.y * h, u.z * h, u.w * h))
	return [[cl, float(sp.canopy.get("gap", 0.3))]]


func _run() -> void:
	TreeLayouts.use_seed(42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# 1. Under a birch, looking up.
	var birch := _tree("Paper birch", 16.0)
	var cl: PackedVector4Array = birch[0][0]
	var gap: float = birch[0][1]
	var reach := 0.0
	for c in cl:
		reach = maxf(reach, Vector2(c.x, c.z).length())
	var through := 0.0
	var n := 0
	for k in 600:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * reach * 0.7
		var foot := Vector3(cos(a) * r, 1.4, sin(a) * r)
		through += FoliageCover.see_through(foot, foot + Vector3.UP * 40.0, birch)
		n += 1
	var sky := through / n
	print("[cover] paper birch (gap %.2f): looking up from under the crown, %.2f of the view gets through" % [gap, sky])
	ok(absf(sky - gap) <= 0.1, "the see-through share is the canopy gap ± 0.1 (%.2f vs %.2f)" % [sky, gap])

	# 2. A player in an oak's crown, on a limb.
	var oak_h := 18.0
	var oak := _tree("Oak", oak_h)
	var sk := TreeLayouts.skeleton(SpeciesDB.index_of(SpeciesDB.find("Oak")), 0)
	var seat := Vector3.ZERO
	for pc in sk.pieces:
		if pc.order == 1 and not pc.dead and pc.kind == TreeLayouts.Kind.LIMB:
			var q: Vector3 = pc.at(pc.length() * 0.45)[0]
			if q.y > seat.y and q.y < 0.8:
				seat = q
	var player := seat * oak_h + Vector3.UP * 0.9
	var side := 0.0
	var below := 0.0
	for k in 200:
		# From the side: level with the perch (give or take a few metres),
		# 20 m off (someone in the next tree, up a slope).
		var a := rng.randf() * TAU
		var watcher := Vector3(cos(a) * 20.0, player.y + rng.randf_range(-3.0, 3.0), sin(a) * 20.0)
		side += FoliageCover.see_through(watcher, player, oak)
		var under := Vector3(player.x, 1.4, player.z) + Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1))
		below += FoliageCover.see_through(under, player, oak)
	side /= 200.0
	below /= 200.0
	print("[cover] oak %.0f m, player on a limb %.1f m up: seen from the side (20 m off, level) %.2f of the time, from right below %.2f" % [oak_h, player.y, side, below])
	ok(side < 0.2, "hidden in the crown from the side (%.2f seen)" % side)
	ok(below > side, "seen more from right below, through the gaps (%.2f vs %.2f)" % [below, side])
	# The fox's flight distance: the seeing part is cut by the cover (seen
	# from its side, the leaves between).
	var fox_sp: CreatureSpecies = null
	for c in CreatureSpecies.all():
		if c.name.to_lower().contains("fox"):
			fox_sp = c
			break
	if fox_sp != null:
		var still_noise := 0.02
		var open := fox_sp.shy_m * (0.35 + 1.25 * still_noise)
		var hid := fox_sp.shy_m * (0.35 * side + 1.25 * still_noise)
		print("[cover] %s notices a still player at %.1f m in the open, %.1f m hidden in the crown" % [fox_sp.name, open, hid])
		ok(hid < open * 0.5, "hidden and still, a fox has to come twice as close to notice")
	# 3. An arrow through three clusters.
	var v := 60.0
	for k in 3:
		v *= 1.0 - FoliageCover.DRAG
	print("[cover] foliage_drag %.2f: an arrow through three clusters keeps %.1f of 60 m/s" % [FoliageCover.DRAG, v])
	ok(absf(v - 60.0 * pow(1.0 - 0.05, 3.0)) < 0.5, "three clusters take about 14 %% of an arrow's speed")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
