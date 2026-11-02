extends SceneTree
## The keepers' real work and the camp's supply chains (design §GM, §GO.1-3;
## queue 122-123; HubWork, HubWorkView, data/hub_work.json), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/hub_work_check.gd
## DAYS= how many days the long run lives (10 by default); HIDE_DAYS= the
## first-guess days for a hide to reach an upgrade (6).
## Asserts:
##  1. a new game opens on the bare camp (§GO.1): every keeper under a
##     lean-to, no tents or huts, no totems, every station placed and
##     empty (no items, no upgrades), the start's store;
##  2. a DAYS-day run at speed (the camp's own clock, minute quarters):
##     every work or carry logged changed the store, a chain item or a
##     tool (none with an empty delta); every stock between 0 and its cap
##     after every step; firewood never runs out; every keeper rests at
##     least a quarter of daylight on an average day; every item that
##     entered a chain ended as store goods (or tonight's food, or given
##     back to the fields) or is still on its way, its every move logged;
##     a hide reached an upgrade within HIDE_DAYS;
##  3. the axe broken: the knapper's next work is the axe head, before his
##     own stock; he carries it over; the woodcutter fetches dead wood
##     again after;
##  4. a full store makes a lazy day (the rest share up);
##  5. catch-up after 3 days away matches 3 days lived within 10 %;
##  6. in the game: the props follow the store and the stations their
##     items' stages over a fast-forwarded day; a realm haul set down in
##     the camp store enters its chain; the camp's save round trip;
##  7. frame time with the work on within 1 ms of it off.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


const WORK := ["recipe", "cook", "stage", "source", "tend", "order", "upgrade", "carry", "band"]


func _run() -> void:
	var days_n := int(OS.get_environment("DAYS")) if OS.get_environment("DAYS") != "" else 10
	var hide_days := float(OS.get_environment("HIDE_DAYS")) if OS.get_environment("HIDE_DAYS") != "" else 6.0
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while not main.on_surface and w < 3000:
		await process_frame
		w += 1
	await _frames(3)
	var hub := main.surface as HubCamp
	ok(hub != null and hub.work_view != null, "the hub camp with its work (sim.on)")
	if hub == null or hub.work_view == null:
		_done()
		return
	var wv := hub.work_view
	main.set_process(false)

	# 1. The bare camp.
	var lean := 0
	var tents := 0
	for st in hub.sites:
		var site := hub.get_node("Site_" + str(st.keeper)) as Node3D
		var has := false
		for c in site.get_children():
			has = has or bool(c.get_meta("shelter", false))
			if str(c.name).begins_with("Tent") or str(c.name).begins_with("Roof"):
				tents += 1
		lean += 1 if has or str(st.keeper) == "woodcutter_firekeeper" else 0
	var totems := hub.find_children("*", "", true, false).filter(func(n): return n is MeshInstance3D and (n as MeshInstance3D).mesh is SphereMesh and (n as MeshInstance3D).material_override is StandardMaterial3D and ((n as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.to_html(false) == "d8cfa8" and (n as Node3D).global_position.y - hub.land.height_at((n as Node3D).global_position.x, (n as Node3D).global_position.z) > 1.5).size()
	ok(lean == hub.sites.size() and tents == 0, "every keeper under a lean-to (%d of %d), no tents or huts (%d)" % [lean, hub.sites.size(), tents])
	ok(totems == 0, "no skull totems in the bare camp (%d)" % totems)
	var stations := wv.get_children().filter(func(n): return str(n.name).begins_with("Station_")).size()
	ok(stations == 7 and hub.store_node != null, "every new station placed (%d of 7: butchering and cleaning stones, weaving frame, sorting and drying mats, settling jar, soak pit) and the camp store" % stations)
	var st0: Dictionary = (HubWork.D.get("start", {}) as Dictionary).get("stocks", {})
	var start_ok := true
	for g in wv.sim.store:
		start_ok = start_ok and absf(float(wv.sim.store[g]) - float(st0.get(g, 0.0))) < 0.001
	ok(wv.sim.items.is_empty() and wv.sim.upgrades.is_empty() and start_ok, "stations empty, no upgrades, the start's store (%s)" % str(st0))

	# 2. The long run.
	var spots := hub.work_spots()
	var sim := HubWork.new()
	sim.fresh(hub.seed_value, float(main.world.get("days")), float(main.world.get("day_length_s")) / 60.0)
	sim.place(spots)
	var bad_bounds: Array = []
	var fw_min := 1e9
	var steps_n := int(days_n * sim.day_min / 0.25)
	var t0 := Time.get_ticks_msec()
	var first_up := -1.0
	for i in steps_n:
		sim.advance(0.25)
		for g in sim.store:
			var c := float(sim.store[g])
			if c < -1e-6 or c > sim.cap(str(g)) + 1e-6:
				bad_bounds.append("%s=%.2f@%.0f" % [g, c, sim.t])
		fw_min = minf(fw_min, sim.count("firewood"))
		if first_up < 0.0 and not sim.upgrades.is_empty():
			first_up = sim.t
	print("  (%d days in %d ms; %d log entries; %d items ended, %d on their way; upgrades %s)" % [days_n, Time.get_ticks_msec() - t0, sim.log.size(), sim.ended.size(), sim.items.size(), str(sim.upgrades.keys())])
	var empty: Array = sim.log.filter(func(e): return str(e.kind) in WORK and (e.delta as Dictionary).is_empty())
	var acts := {}
	for e in sim.log:
		if str(e.kind) in WORK:
			acts[str(e.act).get_slice("@", 0)] = int(acts.get(str(e.act).get_slice("@", 0), 0)) + 1
	print("  actions: %s" % str(acts))
	ok(empty.is_empty(), "every work and carry changed something (%d logged; empty: %s)" % [sim.log.filter(func(e): return str(e.kind) in WORK).size(), str(empty.slice(0, 5))])
	ok(bad_bounds.is_empty(), "every stock stays between 0 and its cap (%s)" % str(bad_bounds.slice(0, 5)))
	ok(fw_min > 0.0, "firewood never runs out (lowest %.1f)" % fw_min)
	var rs := sim.rest_share()
	var lazy_ok := true
	for k in rs:
		lazy_ok = lazy_ok and float(rs[k]) >= 0.25
	ok(lazy_ok, "every keeper rests at least a quarter of daylight on an average day (%s)" % str(rs.keys().map(func(k): return "%s %.2f" % [k, rs[k]])))
	var entered := sim.ended.size() + sim.items.size()
	var ends := {}
	var bad_end: Array = []
	for e in sim.ended:
		ends[str(e.end)] = int(ends.get(str(e.end), 0)) + 1
		if not (str(e.end) in ["store", "fresh", "store+fields", "fresh+fields"]):
			bad_end.append(e.id)
		var mv: Array = e.moves
		if mv.size() < 3 or str(mv[0][1]) != "enter" or str(mv[mv.size() - 1][1]) != "end":
			bad_end.append(e.id)
	var chains_seen := {}
	for e in sim.ended:
		chains_seen[str(e.chain)] = true
	ok(entered > 0 and bad_end.is_empty() and sim._next - 1 >= entered, "every item that entered a chain ended as goods or is on its way (%d entered: %s, %d on their way; bad %s)" % [entered, str(ends), sim.items.size(), str(bad_end.slice(0, 5))])
	ok(chains_seen.size() == HubWork.chains().size(), "all five chains ran to the end (%s)" % str(chains_seen.keys()))
	ok(first_up >= 0.0 and first_up / sim.day_min <= hide_days, "a hide became an upgrade within %.0f days (day %.1f)" % [hide_days, first_up / sim.day_min if first_up >= 0.0 else -1.0])

	# 3. The broken axe.
	var ax := HubWork.new()
	ax.fresh(hub.seed_value, float(main.world.get("days")), sim.day_min)
	ax.place(spots)
	_to_morning(ax)
	ax.store["firewood"] = 2.0
	ax.store["flint"] = 6.0
	ax.store["sinew"] = 3.0
	ax.tools["stone_axe"].uses = 1
	var mark := ax.log.size()
	var broke_at := -1.0
	var busy_with: Array = []
	for i in int(2 * ax.day_min / 0.25):
		ax.advance(0.25)
		if broke_at < 0.0 and bool(ax.tools.stone_axe.broken):
			broke_at = ax.t
			mark = ax.log.size()
			# What the knapper is already in the middle of, he finishes.
			for st2 in (ax.keepers.knapper_potter.steps as Array):
				if str(st2.do) == "work":
					busy_with.append(str(st2.get("act", "")))
		if broke_at >= 0.0 and not bool(ax.tools.stone_axe.broken) and ax.log.slice(mark).any(func(e): return str(e.k) == "woodcutter_firekeeper" and str(e.act) == "gather_dead_wood"):
			break
	var after: Array = ax.log.slice(mark)
	var knap: Array = after.filter(func(e): return str(e.k) == "knapper_potter" and str(e.kind) in WORK and str(e.kind) != "carry")
	if not knap.is_empty() and busy_with.has(str(knap[0].act)):
		knap.pop_front()
	var first_k := str(knap[0].act) if not knap.is_empty() else ""
	var delivered := after.any(func(e): return str(e.k) == "knapper_potter" and str(e.act) == "deliver_stone_axe")
	var wood_again := after.any(func(e): return str(e.k) == "woodcutter_firekeeper" and str(e.act) == "gather_dead_wood")
	ok(broke_at >= 0.0 and first_k == "make_stone_axe", "the axe broke and the knapper's next work was the axe head (%s)" % first_k)
	ok(delivered and wood_again and not bool(ax.tools.stone_axe.broken), "carried over, and the woodcutter fetched dead wood again (%s, %s)" % [delivered, wood_again])

	# 4. A lazy day.
	var busy := _day_rest(hub, spots, false)
	var lazy := _day_rest(hub, spots, true)
	ok(lazy > busy, "a full store makes a lazy day (rest share %.2f against %.2f)" % [lazy, busy])

	# 5. Catch-up.
	var a := HubWork.new()
	a.fresh(hub.seed_value, float(main.world.get("days")), sim.day_min)
	a.place(spots)
	var b := HubWork.new()
	b.from_dict(a.to_dict(), sim.day_min)
	b.place(spots)
	a.advance(3.0 * sim.day_min, 0.25)
	var caught := b.catch_up(b.now_days() + 3.0)
	var pa := 0.0
	var pb := 0.0
	for g in a.produced:
		pa += float(a.produced[g])
	for g in b.produced:
		pb += float(b.produced[g])
	ok(absf(caught - 3.0 * sim.day_min) < 0.5 and pa > 0.0 and absf(pa - pb) / pa <= 0.1, "catch-up after 3 days away (%.0f min) matches 3 days lived within 10 %% (made %.0f against %.0f)" % [caught, pb, pa])

	# 6. In the game: props and stations over a fast-forwarded day.
	var per_day := float(main.world.get("day_length_s"))
	var mism: Array = []
	var stock_bad: Array = []
	var seen_items := 0
	for i in 640:
		main.world.days = float(main.world.get("days")) + 15.0 / per_day
		hub.day_shift.tick(15.0)
		wv.step()
		wv.tick(0.05)
		for it in wv.sim.items:
			var n: Node3D = wv._items.get(int(it.id), null)
			seen_items += 1
			if n == null or str(n.get_meta("show", "")) != str(it.get("shown", "raw")) or str(n.get_meta("at", "")) != str(it.at):
				mism.append("%d:%s@%s" % [int(it.id), it.get("shown", ""), it.at])
		for g in wv._stock:
			var e: Dictionary = wv._stock[g]
			var c := wv.sim.count(str(g))
			var vis := (e.units as Array).filter(func(u): return (u as Node3D).visible).size()
			if (c > 0.0) != (vis > 0):
				stock_bad.append("%s %.1f/%d" % [g, c, vis])
	ok(seen_items > 0 and mism.is_empty(), "each station shows its items at the stage they are up to (%d looks; wrong: %s)" % [seen_items, str(mism.slice(0, 5))])
	ok(stock_bad.is_empty(), "each good's prop shows when there is some and is bare when none (%s)" % str(stock_bad.slice(0, 5)))
	var tools_ok := true
	for id in wv._tool:
		var tl: Dictionary = wv.sim.tools[id]
		var n2: Node3D = wv._tool[id].node
		tools_ok = tools_ok and (n2.visible == (str(tl.by) == ""))
	ok(tools_ok, "a tool in a keeper's hand is gone from its spot, the rest at theirs (%d tools)" % wv._tool.size())
	# A realm haul set down in the camp store.
	var inv := main.player.inventory
	inv.add({"kind": "haul", "what": "agave_fibre", "name": "agave fibre"})
	main.player.global_position = hub.store_node.global_position + Vector3(0.6, 0.0, 0.0)
	var n_before := wv.sim.items.size()
	var took := main.areas.interact()
	var brought := wv.sim.items.filter(func(it): return str(it.chain) == "plants" and str(it.at) == "store")
	ok(took and brought.size() >= 1 and wv.sim.items.size() == n_before + 1 and not inv.carried.any(func(x): return x is Dictionary and str(x.get("what", "")) == "agave_fibre"), "agave fibre set down in the camp store enters the plants chain (%d items now)" % wv.sim.items.size())
	var forager_took := false
	for i in 1200:
		main.world.days = float(main.world.get("days")) + 15.0 / per_day
		wv.step()
		if not brought.is_empty() and wv.sim.item(int(brought[0].id)).is_empty() or (not brought.is_empty() and str(wv.sim.item(int(brought[0].id)).get("at", "")) != "store"):
			forager_took = true
			break
	ok(forager_took, "and a keeper carries it on from the store")
	# The save.
	var d := wv.sim.to_dict()
	var back := HubWork.new()
	back.from_dict(JSON.parse_string(JSON.stringify(d)), sim.day_min)
	var same := true
	for g in wv.sim.store:
		same = same and absf(float(back.store.get(g, -1.0)) - float(wv.sim.store[g])) < 1e-4
	ok(same and back.items.size() == wv.sim.items.size() and back.upgrades.size() == wv.sim.upgrades.size() and CrawlerSave.data.has("hub_work"), "the camp's save round trip (store, %d items, %d upgrades)" % [back.items.size(), back.upgrades.size()])

	# 7. Frame time.
	main.set_process(true)
	var on_us: Array = []
	var off_us: Array = []
	for rep in 4:
		for on in [true, false]:
			wv.set_process(on)
			await _frames(5)
			var t1 := Time.get_ticks_usec()
			for i in 60:
				wv._acc = 1e9 if i % 15 == 0 else wv._acc
				await process_frame
			(on_us if on else off_us).append(float(Time.get_ticks_usec() - t1) / 60.0)
	wv.set_process(true)
	var mon: float = on_us.reduce(func(x, y): return x + y, 0.0) / on_us.size()
	var moff: float = off_us.reduce(func(x, y): return x + y, 0.0) / off_us.size()
	ok(absf(mon - moff) < 1000.0, "frame time with the work on within 1 ms of it off (%.2f against %.2f ms)" % [mon / 1000.0, moff / 1000.0])
	_done()


## Step `s` on to the next morning's daylight.
func _to_morning(s: HubWork) -> void:
	var guard := 0
	while guard < 2000:
		var ph := s.phase()
		s.advance(0.25)
		if str(ph.part) == "day" and float(ph.frac) < 0.1:
			return
		guard += 1


## The rest share over one daylight, the store as it starts (or every
## stock at its target).
func _day_rest(hub: HubCamp, spots: Dictionary, full: bool) -> float:
	var s := HubWork.new()
	s.fresh(hub.seed_value + 1, 1000.0, 144.0)
	s.place(spots)
	_to_morning(s)
	if full:
		for g in s.store:
			s.store[g] = maxf(s.target(str(g)), float(s.store[g]))
			s.store[g] = minf(maxf(float(s.store[g]), s.target(str(g)) + 2.0), s.cap(str(g)))
	var d0 := s.day_no
	while s.day_no == d0:
		s.advance(0.25)
	var dd: Dictionary = s.days.get(d0, {})
	var r := 0.0
	var l := 0.0
	for k in dd:
		r += float(dd[k].rest)
		l += float(dd[k].light)
	return r / l if l > 0.0 else 0.0


func _done() -> void:
	print("hub_work_check: %d fails" % fails)
	quit(1 if fails > 0 else 0)
