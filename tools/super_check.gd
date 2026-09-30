extends "res://tools/tech_check.gd"
## The super meter and overcharge (design §S, SuperMeter):
##   - a perfect wall jump (jump at the face) fills the meter; a second
##     one in the same series fills it more (the chain bonus); a cling
##     (right click held) instead ends the series but keeps the meter;
##   - with meter, a bow held past the full draw for the overcharge's
##     extra_s looses a super shot (critical, a red streak, falls less)
##     and empties the meter; let go before that, a normal shot and the
##     meter kept; with no meter, no overcharge at all;
##   - the spear the same;
##   - a landed hit fills it (Hits.on_hit), a critical more;
##   - dying empties it.
##
##   ~/bin/godot --headless --path . --fixed-fps 60 --script tools/super_check.gd


func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	# (You wake empty-handed, the folk's gifts by you: taken, as play does.)
	main.take_gifts()
	await frames(90)
	var camp_d: Vector3 = player.surface_dir
	var m := player.meter
	var nums := SuperMeter.NUMS

	# --- Filling: perfect wall jumps, a series ---------------------------
	var g := trunk_near(player.global_position)
	fly_at_trunk(g, 6.0, 1.3)
	await wait_contact()
	await press("jump")
	await frames(2)
	await release("jump")
	await frames(2)
	var v1 := m.value
	print("[super] after a wall jump: meter %.3f, series %d, perfects %d" % [v1, m.series, m.perfects])
	ok(v1 > 0.0 and m.perfects == 1, "a perfect wall jump fills the meter (%.2f)" % v1)
	fly_at_trunk(g, 6.0, 1.3)
	player._wj_chain = 1
	await wait_contact()
	await press("jump")
	await frames(2)
	await release("jump")
	await frames(2)
	var gain2 := m.value - v1
	print("[super] second in the series: +%.3f (first +%.3f)" % [gain2, v1])
	ok(gain2 > v1 + 0.001, "the next perfect in the series fills more (chain bonus %.2f)" % float(nums.get("chain_bonus_per_link", 0.01)))
	await settle(camp_d)
	fly_at_trunk(g, 6.0, 3.0)
	await wait_contact()
	var before := m.value
	await press("interact")
	await frames(40)
	await release("interact")
	await frames(2)
	print("[super] out of a cling: series %d, meter %.3f -> %.3f" % [m.series, before, m.value])
	ok(m.series == 0 and absf(m.value - before) < 1e-6, "a cling instead of the tap ends the series, the meter kept")
	await settle(camp_d)

	# --- Spending: the bow -------------------------------------------------
	player.weapon = "bow"
	var draw := Bow.DRAW_S
	var extra := float(SuperMeter.overcharge("bow").get("extra_s", 1.2))
	m.value = 0.3
	var shots0 := player.bow.super_shots
	await press("shoot")
	await frames(int((draw + extra * 0.5) * 60.0))
	print("[super] bow held %.1f s past full: overcharge %.2f" % [extra * 0.5, player.bow.overcharge()])
	await release("shoot")
	await frames(2)
	ok(player.bow.super_shots == shots0 and absf(m.value - 0.3) < 1e-6, "let go before the overcharge completes: a normal shot, meter kept")
	await press("shoot")
	await frames(int((draw + extra + 0.2) * 60.0))
	var over := player.bow.overcharge()
	await release("shoot")
	await frames(2)
	var newest: Arrow = Arrow.flying[Arrow.flying.size() - 1] if not Arrow.flying.is_empty() else null
	print("[super] held through the overcharge (%.2f): super shots %d, meter %.2f, arrow super %s, streak %s, fall x%.2f" % [over, player.bow.super_shots, m.value,
		newest.super_shot if newest else false, newest._trail.color.to_html(false) if newest and newest._trail else "-", newest.gravity_scale if newest else 0.0])
	ok(over >= 1.0 and player.bow.super_shots == shots0 + 1 and m.value == 0.0, "overcharged: a super shot, and the meter empties")
	ok(newest != null and newest.super_shot and newest.pierce == 1 and newest.gravity_scale < 1.0, "the super arrow pierces and falls less")
	ok(newest != null and newest._trail != null and newest._trail.color.r > 0.9 and newest._trail.color.g < 0.3, "with a red streak")
	await press("shoot")
	await frames(int((draw + extra + 0.2) * 60.0))
	ok(player.bow.overcharge() == 0.0, "with no meter there's no overcharge")
	await release("shoot")
	await frames(10)

	# --- Spending: the spear -----------------------------------------------
	player.weapon = "spear"
	m.value = 0.5
	var sextra := float(SuperMeter.overcharge("spear").get("extra_s", 1.0))
	await press("shoot")
	await frames(int((Spear.RAISE_S + sextra + Spear.TAP_S + 0.2) * 60.0))
	var sover := player.spear.overcharge()
	await release("shoot")
	await frames(2)
	var thrown: ThrownSpear = player.spear.thrown
	print("[super] spear overcharge %.2f: super throws %d, meter %.2f, thrown super %s" % [sover, player.spear.super_shots, m.value, thrown.super_shot if thrown else false])
	ok(sover >= 1.0 and player.spear.super_shots == 1 and m.value == 0.0 and thrown != null and thrown.super_shot, "an overcharged spear throw is a super throw, and the meter empties")
	player.weapon = "bow"

	# --- Hits and death ----------------------------------------------------
	m.value = 0.0
	Hits.on_hit.call(false)
	var h1 := m.value
	Hits.on_hit.call(true)
	print("[super] a hit +%.2f, a critical +%.2f" % [h1, m.value - h1])
	ok(absf(h1 - float(nums.get("fill_per_hit", 0.06))) < 1e-4 and m.value - h1 > h1, "a landed hit fills it, a critical more")
	player._damage(10000.0)
	await frames(2)
	ok(m.value == 0.0, "dying empties it")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
