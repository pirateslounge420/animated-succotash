extends SceneTree
## The fire breathes (design 3 Oct §CZ, look.json fire.coals, fire.specks,
## fire.light.breath), headless, no planet:
##   godot --headless --path . --script tools/fire_breath_check.gd
## Builds a fire's moving parts (the bed of coals, the specks, the light,
## the pops) and runs Campfire.flicker for ten minutes of fire clock at
## each burn (flames, low, embers, out). Asserts:
##  - the bed breathes about once every 1 / coals.breath_hz seconds, and
##    the light breathes with it by light.breath.amount;
##  - at embers the breath is coals.at_embers' (slower, deeper) and there
##    is no flame card, only the bed;
##  - specks come on a random clock, never a loop: the waits between
##    throws spread like an exponential (their spread about their mean);
##  - every pop throws its burst at the same instant;
##  - about ash.share of the specks are ash;
##  - a poke or a piece laid on makes the bed flare and throws a big
##    burst, which settles over air_settle_s;
##  - a low fire throws fewer, embers a rare one, a dead fire none.

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _camp() -> Node3D:
	var camp := Node3D.new()
	camp.name = "Campfire"
	get_root().add_child(camp)
	camp.add_child(Campfire.coal_bed(1.3))
	camp.add_child(Campfire.speck_node(1.3))
	var flames := Campfire.flame_node(1.0, 1.0, 0, 1.3)
	flames.name = "Flames"
	camp.add_child(flames)
	var light := OmniLight3D.new()
	light.name = "Light"
	camp.add_child(light)
	Audio3D.make("fire", camp, "Pops")
	camp.set_meta("flick_seed", 1.3)
	return camp


func _run() -> void:
	var C: Dictionary = Campfire.C
	var SP: Dictionary = Campfire.SP
	Campfire.night = 1.0
	var dt := 1.0 / 30.0
	var per_min := {}
	for burn in [1.0, 0.55, 0.12, 0.0]:
		var camp := _camp()
		camp.set_meta("burn", burn)
		var throws: Array[float] = []
		var last_thrown := 0
		var pops := 0
		var pop_bursts := 0
		var breath: Array[float] = []
		var light_e: Array[float] = []
		var t := 0.0
		var steps := int(600.0 / dt)
		for i in steps:
			t = i * dt
			Campfire.flicker(camp, t)
			var thrown := int(camp.get_meta("specks_thrown", 0))
			if thrown > last_thrown:
				throws.append(t)
				if camp.has_meta("popped_at") and is_equal_approx(float(camp.get_meta("popped_at")), t):
					pop_bursts += 1
				last_thrown = thrown
			if camp.has_meta("popped_at") and is_equal_approx(float(camp.get_meta("popped_at")), t):
				pops += 1
			var m := (camp.get_node("Coals") as MeshInstance3D).material_override as ShaderMaterial
			breath.append(float(m.get_shader_parameter("breath")))
			light_e.append((camp.get_node("Light") as OmniLight3D).light_energy)
		var n := int(camp.get_meta("specks_thrown", 0))
		per_min[burn] = n / 10.0
		var tag := "burn %.2f" % burn
		if burn <= 0.0:
			ok(n == 0, "%s (out): no specks (%d)" % [tag, n])
			camp.free()
			continue
		# The breath's period, from its upward crossings of 1.
		var ups: Array[float] = []
		for i in range(1, breath.size()):
			if breath[i - 1] < 1.0 and breath[i] >= 1.0:
				ups.append(i * dt)
		var period := (ups[ups.size() - 1] - ups[0]) / maxf(ups.size() - 1, 1) if ups.size() > 2 else 0.0
		var at_e: Dictionary = C.get("at_embers", {})
		var want_hz := float(at_e.get("breath_hz", 0.2)) if burn <= Campfire.CARD_BELOW else float(C.get("breath_hz", 0.35))
		var want_amt := float(at_e.get("breath_amount", 0.45)) if burn <= Campfire.CARD_BELOW else float(C.get("breath_amount", 0.3))
		var bmax: float = breath.max()
		ok(absf(period - 1.0 / want_hz) < 0.1 and absf(bmax - 1.0 - want_amt) < 0.02, "%s: the bed breathes once every %.2f s (want %.2f), by %.2f (want %.2f)" % [tag, period, 1.0 / want_hz, bmax - 1.0, want_amt])
		# The light with it: its energy over the breath's highs and lows.
		var hi := 0.0
		var lo := 0.0
		var nh := 0
		var nl := 0
		for i in breath.size():
			if breath[i] > 1.0 + want_amt * 0.9:
				hi += light_e[i]
				nh += 1
			elif breath[i] < 1.0 - want_amt * 0.9:
				lo += light_e[i]
				nl += 1
		var lb := float((Campfire.L.get("breath", {}) as Dictionary).get("amount", 0.12))
		var ratio := (hi / maxf(nh, 1)) / maxf(lo / maxf(nl, 1), 1e-6)
		ok(ratio > 1.0 + lb, "%s: the light breathes with the bed (%.2f brighter at the breath's top than its bottom; %.2f of it is the breath)" % [tag, ratio, (1.0 + lb) / (1.0 - lb)])
		if burn <= Campfire.CARD_BELOW:
			Campfire.flicker(camp, t)
			ok(not (camp.get_node("Flames/Card") as Node3D).visible, "%s (embers): no flame card, the bed is the fire" % tag)
		# The random clock.
		var gaps: Array[float] = []
		for i in range(1, throws.size()):
			gaps.append(throws[i] - throws[i - 1])
		var mean := 0.0
		for g in gaps:
			mean += g
		mean /= maxf(gaps.size(), 1)
		var vr := 0.0
		for g in gaps:
			vr += (g - mean) * (g - mean)
		var cv := sqrt(vr / maxf(gaps.size(), 1)) / maxf(mean, 1e-6)
		print("[fire] %s: %d specks in 10 min (%.0f a minute) in %d throws, mean wait %.2f s, spread %.2f of the mean; %d pops" % [tag, n, n / 10.0, throws.size(), mean, cv, pops])
		if gaps.size() > 20:
			ok(cv > 0.6, "%s: the specks come on a random clock, never a loop (spread %.2f of the mean)" % [tag, cv])
		if burn > Campfire.CARD_BELOW:
			ok(pops > 0 and pop_bursts == pops, "%s: every pop throws its burst at the same instant (%d of %d)" % [tag, pop_bursts, pops])
			var ash := int(camp.get_meta("ash_thrown", 0))
			var share := float((SP.get("ash", {}) as Dictionary).get("share", 0.3))
			ok(absf(float(ash) / maxf(n, 1) - share) < 0.08, "%s: %.0f %% of the specks are ash (want %.0f %%)" % [tag, 100.0 * ash / maxf(n, 1), share * 100.0])
		# A poke: the bed flares, a big burst, then it settles.
		if burn >= 1.0:
			var before := int(camp.get_meta("specks_thrown", 0))
			Campfire.stir(camp, "poke")
			t += 0.5
			Campfire.flicker(camp, t)
			var m := (camp.get_node("Coals") as MeshInstance3D).material_override as ShaderMaterial
			var air0 := float(m.get_shader_parameter("air"))
			var big := int(camp.get_meta("specks_thrown", 0)) - before
			var bb: Array = SP.get("big_burst", [6, 12])
			t += float(C.get("air_settle_s", 2.5)) * 3.0
			Campfire.flicker(camp, t)
			var air1 := float(m.get_shader_parameter("air"))
			ok(air0 > 0.95 and big >= int(bb[0]) and air1 < 0.15, "%s: a poke flares the bed (air %.2f) with a big burst (%d specks) and it settles (%.2f after %.1f s)" % [tag, air0, big, air1, float(C.get("air_settle_s", 2.5)) * 3.0])
		camp.free()
	ok(per_min[1.0] > per_min[0.55] and per_min[0.55] > per_min[0.12] and per_min[0.12] < 6.0, "a low fire throws fewer specks, embers a rare one (%.0f, %.0f, %.1f a minute)" % [per_min[1.0], per_min[0.55], per_min[0.12]])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
