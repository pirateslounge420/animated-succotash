extends SceneTree
## The camp cauldron's effects (CauldronFX; crawler.json hub.cauldron_fx;
## Mike, 26 Oct), headless:
##   godot --headless --path . --script tools/cauldron_fx_check.gd
## Asserts, for every brew in the file: started, it simmers (progress 0)
## and brews to ready over exactly its brew_s (not before), emitting ready
## once, with a puff; its steam, bubbles and motes in its own colours, at a
## simmer weaker than at full; its kind of motes (embers fast, spores
## slow and wandering); a brew rated to roll over the rim sinks, the rest
## rise. The brews take different times and look different. Left alone,
## the pot works through the cycle: the stew, then the next brew after
## rest_s. Then in the game: the hub's cauldron carries it.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var looks := {}
	var times := {}
	for key: String in CauldronFX.brews():
		var b := CauldronFX.info(key)
		var fx := CauldronFX.new()
		root.add_child(fx)
		fx.set_process(false)
		fx.start(key, true)
		var bs := float(b.get("brew_s", 0.0))
		times[key] = bs
		var got := []
		fx.brewed.connect(func(k): got.append(k))
		var simmer_a := fx._steam.color.a
		var simmer_s := fx._steam.scale_amount_max
		if bs > 0.0:
			ok(fx.progress == 0.0, "%s: starts at a simmer" % key)
			fx.advance(bs * 0.98)
			ok(not fx.is_ready() and got.is_empty(), "%s: not ready before its %.0f s" % [key, bs])
			fx.advance(bs * 0.03)
			ok(fx.is_ready() and got == [key] and fx._puff.emitting, "%s: ready at %.0f s, once, with a puff" % [key, bs])
			ok(fx._steam.color.a > simmer_a and fx._steam.scale_amount_max > simmer_s, "%s: thicker steam at full than at a simmer (%.2f > %.2f)" % [key, fx._steam.color.a, simmer_a])
		var sc := Color(str(b.get("steam", "#ffffff")))
		ok(fx._steam.color.r == sc.r and fx._steam.color.g == sc.g and fx._steam.color.b == sc.b, "%s: steam #%s" % [key, sc.to_html(false)])
		var gc := Color(str(b.get("glow", "#ffffff")))
		var kind := str(b.get("spark_kind", "motes"))
		if kind != "embers" and kind != "none":
			ok(fx._sparks.color.r == gc.r and fx._sparks.color.b == gc.b, "%s: %s in the brew's #%s" % [key, kind, gc.to_html(false)])
		if kind == "embers":
			ok(fx._sparks.initial_velocity_max >= 1.0, "%s: embers fly up fast" % key)
		elif kind == "spores":
			ok(fx._sparks.lifetime >= 4.0 and fx._sparks.tangential_accel_max > 0.0 and fx._sparks.initial_velocity_max < 0.3, "%s: spores drift slow and wander" % key)
		var heavy := float(b.get("steam_rate", 0.5)) > 0.85
		ok((fx._steam.gravity.y < 0.0) == heavy, "%s: steam %s" % [key, "rolls over the rim and sinks" if heavy else "rises"])
		looks[key] = [fx._steam.color.to_html(), fx._sparks.color.to_html(), kind]
		fx.free()
	var distinct_t := {}
	for k in times:
		distinct_t[times[k]] = true
	var distinct_l := {}
	for k in looks:
		distinct_l[str(looks[k])] = true
	ok(distinct_t.size() == times.size(), "every brew takes its own time: %s" % str(times))
	ok(distinct_l.size() == looks.size(), "every brew looks different (%d looks)" % distinct_l.size())
	# The cook-shaman's own cycle.
	var cyc: Array = CauldronFX.FX.get("cycle", [])
	var fx2 := CauldronFX.new()
	root.add_child(fx2)
	fx2.set_process(false)
	ok(fx2.brew == str(cyc[0]), "left alone, it starts on %s" % cyc[0])
	fx2.advance(float(CauldronFX.FX.get("rest_s", 30.0)) + 0.1)
	fx2.advance(0.01)
	ok(fx2.brew == str(cyc[1]) and fx2.progress < 0.01, "after rest_s it brews the next: %s" % fx2.brew)
	fx2.advance(float(CauldronFX.info(str(cyc[1])).get("brew_s", 0.0)) + 0.1)
	fx2.advance(float(CauldronFX.FX.get("hold_s", 40.0)) + 0.1)
	fx2.advance(0.01)
	ok(fx2.brew == "camp_stew", "held hold_s, then back to the stew to rest")
	fx2.free()
	# In the game: the hub's cauldron carries it.
	WorldSave.read_only = true
	Boss.pool_off = true
	OS.set_environment("SEED", "7")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while not main.on_surface and w < 3000:
		await process_frame
		w += 1
	var hub := main.surface as HubCamp
	ok(hub != null and hub.cauldron_fx != null and hub.cauldron_fx.is_inside_tree() and hub.cauldron_fx._steam.emitting, "the camp's cauldron steams (%s)" % (hub.cauldron_fx.brew if hub != null and hub.cauldron_fx != null else "none"))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
