extends SceneTree
## Harm in the crawler (design 6 Oct §FD, with §FJ.3's ring and heartbeat;
## queue 56), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/crawler_harm_check.gd
## Boots the crawler and, driving Harm's clock by hand (its tick), asserts:
##  - the crawler's harm is §FD's (Harm.fd) and the open world's isn't; in
##    the crawler no muffle on the Master bus and no grade darkening;
##  - hit 1: the red ring (harm.json fd.hit_1_edge: colour, depth, alpha)
##    and the heartbeat at its pace and loudness; §EC's navy flash still
##    on every hit;
##  - hit 2: the ring darker and deeper, the heart harder and faster;
##  - pursuit (§FD): with a hunter after you (a stand-in holding a Pursuit
##    with the snake's gives_up, bosses.json bosses.desert) no recovery in
##    15 s, beside the lit hearth too (light doesn't heal); out of its
##    sight for out_of_sight_s it gives you up, and a hit heals one step_s
##    later; a new hit resets the timer;
##  - healing steps back down: 2 to 1 the ring eases back to hit 1's and
##    the heart slows and softens; 1 to 0 the heart stops first, then the
##    ring pulls back;
##  - Pursuit's rules: distance, a doused torch, a chase by sound alone not
##    ended by a dark torch, hide false keeping the clock still, a
##    re-notice resetting it; with no light on the floor to go by (a test
##    floor), a lit room open to a chase only once its strike has landed;
##    back to the dark within back_to_dark_s; a freed hunter drops out; a
##    wake (Harm.reset) clears the list and a hunter still after you is
##    back on its next step;
##  - hit 3: "Good night" as built, the ring going under the closing black.
## Then the snake itself (queue 49's Boss), on SEED (SNAKE_SEEDS="1,7,42" for
## more), each scene booted fresh, the snake and Harm stepped together:
##  - a real strike lands in its dark; held where it is (its noticing and
##    its chase's rules running), it keeps you in sight 3 m off for 15 s
##    and nothing heals; you step out of its sight, torch still lit: it
##    gives you up after its out_of_sight_s, and the hit heals one step_s
##    later;
##  - a room next to its dark relit: it strikes you in the dark, you step
##    deep into the lit room (out of its reach of any floor the light lets
##    it stand on), and it follows you only to the light's edge (Mike's
##    note of 7 Oct, amending §FD's chase into the light: residents.json
##    rules.chase_light_cap, never past it), no strike reaching you;
##    nothing heals while it watches you from there; it gives you up after
##    watch_s and is back in an unlit node within residents.json
##    rules.back_to_dark_s;
##  - never into the hearth room: hit at its door, you step in by the fire
##    in its sight and nothing heals (it hasn't lost you); out of its sight
##    there with your torch smothered (§FC.2), it gives you up and you
##    heal;
##  - half the tomb relit, you just inside the lit side of the doorways
##    nearest it (out of its reach of the light's edge) for five minutes,
##    torch lit: it comes after you again and again, never steps from
##    under the chase's cap to past it (finding you in a fire's spill, it
##    goes out of it to the edge first), never steps into a lit node of its
##    own accord, and no strike reaches you.

var fails := 0
var main: CrawlerMain
var harm: Harm
var p: CrawlerPlayer
var gives_up: Dictionary
## The snake's step (s), as boss_check steps it.
const DT := 1.0 / 30.0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## Two colours within `tol` in every channel.
func _near(a: Color, b: Color, tol := 0.01) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _run_for(s: float, step := 0.1) -> void:
	for i in int(round(s / step)):
		harm.tick(step)


## A creature's hit, the way PlanetPlayer.take_hit lands one (the hitstop
## undone at once: the clock here is driven by hand).
func _hit() -> bool:
	var took := harm.hit("creature:giant snake")
	Engine.time_scale = 1.0
	return took


func _run() -> void:
	WorldSave.read_only = true
	# The snake on its built rounds (queue 49's behaviour, its pool's
	# 'rounds'), as these checks test it: its pool's own states (design
	# §FM.2, queue 66) are tools/boss_snake_check.gd's.
	Boss.pool_off = true
	# The tomb's skeletons sleep through this check (design §FE; queue 58).
	Residents.stay_asleep = true
	Bow.need_capture = false
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	var bosses: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses.json"))
	gives_up = ((bosses as Dictionary).bosses.desert as Dictionary).get("gives_up", {})
	ok(not gives_up.is_empty(), "the snake has its gives_up block (bosses.json bosses.desert: %s)" % JSON.stringify(gives_up))
	main = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	p = main.player
	_open_world_untouched()
	await process_frame
	harm = main.get("harm") as Harm
	if harm != null:
		# The crawler's own (queue 49 puts it there): the open world's test
		# Harm above was the instance for a moment and took it with it as it
		# went; this one is the crawler's.
		Harm.instance = harm
	# The snake held still (queue 49): this check runs its own stand-in
	# hunter, and the snake must not join the chase.
	var boss: Variant = main.get("boss")
	if boss is Boss:
		(boss as Boss).auto = false
	if harm == null:
		# Until the boss's pass (queue 49) puts Harm in the crawler: the
		# same node, set up the same way main.gd does.
		harm = Harm.new()
		harm.name = "Harm"
		main.add_child(harm)
		harm.setup(p, main.post, null)
		print("  (Harm made here: the crawler doesn't make one yet)")
	harm.set_process(false)
	harm.reset()
	ok(harm.fd and Harm.instance == harm, "the crawler's harm is §FD's (Harm.fd)")
	_stages()
	_pursuit()
	_healing()
	_reset_timer()
	_rules()
	_good_night()
	main.queue_free()
	await process_frame
	var seeds: Array = [seed_v]
	if OS.get_environment("SNAKE_SEEDS") != "":
		seeds = []
		for sv in OS.get_environment("SNAKE_SEEDS").split(","):
			if sv.strip_edges().is_valid_int():
				seeds.append(int(sv))
	for sv in seeds:
		print("== the snake, seed %d" % sv)
		await _snake_holds(sv)
		await _snake_follows(sv)
		await _snake_hearth(sv)
		await _snake_keeps_out(sv)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## The open world's Harm keeps §EA/§EC: not §FD's, its muffle on the
## Master bus as built.
func _open_world_untouched() -> void:
	GameMode.crawler_running = false
	var fx0 := AudioServer.get_bus_effect_count(0)
	var h := Harm.new()
	get_root().add_child(h)
	h.setup(p, null, null)
	ok(not h.fd and h._lpf != null and AudioServer.get_bus_effect_count(0) == fx0 + 1, "the open world's harm is §EA/§EC's, not §FD's (its muffle on the Master bus)")
	h.queue_free()
	GameMode.crawler_running = true


func _stages() -> void:
	var e1 := Harm.edge_of(1)
	var e2 := Harm.edge_of(2)
	var fx0 := AudioServer.get_bus_effect_count(0)
	var master0 := AudioServer.get_bus_volume_db(0)
	var ring: HarmRing = harm._ring
	ok(ring != null and ring.is_inside_tree() and not ring.visible, "the ring is there, hidden while you're unhurt")
	_hit()
	ok(harm.flash > 0.9, "a hit still flashes §EC's dark navy at the edges (flash %.2f, %s)" % [harm.flash, str((Harm.D.hit_feedback as Dictionary).edge_flash.color)])
	_run_for(1.0)
	var look := Harm.ring_look(harm.ring)
	var c1 := Color(str(e1.color))
	ok(harm.stage == 1 and absf(harm.ring - 1.0) < 0.01, "hit 1: the ring closes round (level %.3f)" % harm.ring)
	ok(ring.visible and _near(ring.ring_color, c1) and absf(ring.alpha - float(e1.alpha)) < 0.01 and absf(ring.width_frac - float(e1.width_frac)) < 0.002, "hit 1: the ring is fd.hit_1_edge's (#%s, alpha %.2f, %.3f of the short side)" % [(ring.ring_color as Color).to_html(false), ring.alpha, ring.width_frac])
	var lines := Display.lines()
	print("  hit 1's ring: %.1f px deep in a %dx%d frame (%d lines)" % [ring.depth_px(), int(ring.size.x), int(ring.size.y), lines])
	ok(absf(ring.depth_px() - float(e1.width_frac) * minf(ring.size.x, ring.size.y)) < 0.5, "hit 1: its depth is width_frac of the frame's short side (%.1f px)" % ring.depth_px())
	var b0 := harm.beats
	_run_for(2.0)
	var bpm1 := float(e1.heart_bpm)
	ok(harm.heart and absf(harm.heart_bpm - bpm1) < 1.0 and absf(harm.heart_db - float(e1.heart_db)) < 0.1, "hit 1: the heartbeat starts, %.0f bpm at %.1f dB" % [harm.heart_bpm, harm.heart_db])
	ok(harm.beats - b0 >= int(2.0 * bpm1 / 60.0) - 1 and harm.beats - b0 <= int(2.0 * bpm1 / 60.0) + 1, "hit 1: %d beats in 2 s at %.0f bpm" % [harm.beats - b0, bpm1])
	var m := main.post._rect.material as ShaderMaterial
	ok(float(m.get_shader_parameter("harm_vignette")) == 0.0 and float(m.get_shader_parameter("harm_desat")) == 0.0, "hit 1: no darkening or drain in the grade (the ring replaces §EA's)")
	ok(AudioServer.get_bus_effect_count(0) == fx0 and absf(AudioServer.get_bus_volume_db(0) - master0) < 0.01, "hit 1: no muffle: the Master bus untouched (%.1f dB, the volume slider's)" % AudioServer.get_bus_volume_db(0))
	# Hit 2.
	_hit()
	_run_for(1.0)
	var c2 := Color(str(e2.color))
	ok(harm.stage == 2 and absf(harm.ring - 2.0) < 0.01, "hit 2: the ring goes to hit 2's (level %.3f)" % harm.ring)
	ok(_near(ring.ring_color, c2) and absf(ring.alpha - float(e2.alpha)) < 0.01 and absf(ring.width_frac - float(e2.width_frac)) < 0.002, "hit 2: the ring is fd.hit_2_edge's (#%s, alpha %.2f, %.3f of the short side)" % [(ring.ring_color as Color).to_html(false), ring.alpha, ring.width_frac])
	ok(c2.get_luminance() < c1.get_luminance() and float(e2.width_frac) > float(e1.width_frac), "hit 2: darker red and deeper (%.1f px against %.1f)" % [ring.depth_px(), float(e1.width_frac) * minf(ring.size.x, ring.size.y)])
	b0 = harm.beats
	_run_for(2.0)
	var bpm2 := float(e2.heart_bpm)
	ok(harm.heart and absf(harm.heart_bpm - bpm2) < 1.0 and harm.heart_db > float(e1.heart_db) + 1.0, "hit 2: the heart harder and faster, %.0f bpm at %.1f dB" % [harm.heart_bpm, harm.heart_db])
	ok(harm.beats - b0 >= int(2.0 * bpm2 / 60.0) - 1, "hit 2: %d beats in 2 s at %.0f bpm" % [harm.beats - b0, bpm2])
	ok(float(m.get_shader_parameter("harm_vignette")) == 0.0 and AudioServer.get_bus_effect_count(0) == fx0, "hit 2: still no darkening and no muffle")


## Two hits taken (from _stages): a hunter after you, close and in sight.
func _pursuit() -> void:
	var hunter := Node3D.new()
	hunter.name = "StandInHunter"
	main.add_child(hunter)
	var chase := Pursuit.new(hunter, gives_up)
	chase.hit(true)
	ok(harm.chased(), "a hunter that hits you is pursuing you (§FD)")
	# By the lit hearth (light doesn't heal), the hunter close and in sight.
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.2)
	for i in 150:
		chase.step(0.1, true, 2.0, true)
		harm.tick(0.1)
	ok(harm.hits.size() == 2, "kept in its sight and close, nothing heals in 15 s, beside the lit hearth too (%d hits)" % harm.hits.size())
	# Out of its sight: it gives you up after out_of_sight_s.
	var t := 0.0
	var gave := false
	while t < 30.0 and not gave:
		gave = chase.step(0.1, false, 6.0, true)
		harm.tick(0.1)
		t += 0.1
	var oos := float(gives_up.get("out_of_sight_s", 6.0))
	ok(gave and chase.why == "out_of_sight" and absf(t - oos) < 0.15, "out of its sight, it gives you up after %.1f s (out_of_sight_s %.1f)" % [t, oos])
	ok(not harm.chased(), "given up, it no longer pursues you")
	var step_s := float((Harm.D.recover as Dictionary).step_s)
	_run_for(step_s - 0.2)
	ok(harm.hits.size() == 2, "%.1f s after it gives you up, still two hits" % (step_s - 0.2))
	_run_for(0.3)
	ok(harm.hits.size() == 1, "one step_s (%.1f s) after it gives you up, a hit heals" % step_s)
	hunter.queue_free()


## From _pursuit: one hit left, healing on.
func _healing() -> void:
	# 2 to 1 just happened: the ring eases back to hit 1's, the heart slows.
	var e1 := Harm.edge_of(1)
	ok(harm.ring > 1.0 and harm.heart, "healing 2 to 1: the ring still easing back (level %.2f), the heart going" % harm.ring)
	_run_for(4.0)
	ok(absf(harm.ring - 1.0) < 0.1 and absf(harm.heart_bpm - float(e1.heart_bpm)) < 8.0 and harm.heart_db < float(e1.heart_db) + 1.0, "healing 2 to 1: back to hit 1's ring (level %.2f), the heart slower and softer (%.0f bpm, %.1f dB)" % [harm.ring, harm.heart_bpm, harm.heart_db])
	var t := 0.0
	while not harm.hits.is_empty() and t < 2.0:
		harm.tick(0.05)
		t += 0.05
	ok(harm.hits.is_empty(), "the last hit heals one step_s later")
	# 1 to 0: the heart first, then the ring.
	var heart_off_ring := -1.0
	t = 0.0
	while t < 10.0:
		harm.tick(0.05)
		t += 0.05
		if not harm.heart and heart_off_ring < 0.0:
			heart_off_ring = harm.ring
	ok(heart_off_ring >= 0.9, "healing 1 to 0: the heart settles and stops first (the ring still at %.2f when it stops)" % heart_off_ring)
	ok(harm.ring < 0.01 and not harm._ring.visible, "then the ring pulls back to the edge and is gone (level %.3f)" % harm.ring)


## §EC as built, in the crawler too: a new hit sets the step back (nothing
## pursuing).
func _reset_timer() -> void:
	harm.reset()
	_hit()
	_run_for(3.0)
	_hit()
	_run_for(4.8)
	ok(harm.hits.size() == 2, "a new hit resets the timer (still two hits 7.8 s after the first)")
	_run_for(0.4)
	ok(harm.hits.size() == 1, "a full step_s after the last, one heals")
	harm.reset()


func _rules() -> void:
	var h := Node3D.new()
	main.add_child(h)
	var dist := float(gives_up.get("distance_m", 24.0))
	var c := Pursuit.new(h, gives_up)
	c.notice(true)
	ok(not c.step(0.1, true, dist - 1.0, true) and c.step(0.1, true, dist + 1.0, true) and c.why == "distance", "it gives you up past distance_m (%.0f m)" % dist)
	c.notice(true)
	ok(c.step(0.1, true, 5.0, false) and c.why == "torch_doused", "your torch going out while it chases you loses you at once (torch_doused)")
	c.notice(false)
	ok(not c.step(0.1, true, 5.0, false) and c.on, "a chase begun by sound with your torch dark isn't ended by the dark torch")
	c.give_up()
	var stubborn := Pursuit.new(h, {"out_of_sight_s": 2.0, "hide": false})
	stubborn.notice(false)
	var held := true
	for i in 30:
		if stubborn.step(0.1, false, 5.0, false, true):
			held = false
	ok(held and stubborn.on, "hide false: hidden behind cover, its clock waits (still on after 3 s)")
	var gone_at := 0.0
	for i in 40:
		gone_at += 0.1
		if stubborn.step(0.1, false, 5.0, false, false):
			break
	ok(not stubborn.on and absf(gone_at - 2.0) < 0.15, "hide false: out of its sight in the open, it gives you up after its out_of_sight_s (%.1f s)" % gone_at)
	var c2 := Pursuit.new(h, {"out_of_sight_s": 2.0})
	c2.notice()
	for i in 15:
		c2.step(0.1, false, 5.0, false)
	c2.notice()
	var on_still := true
	for i in 15:
		if c2.step(0.1, false, 5.0, false):
			on_still = false
	ok(on_still, "noticing you again sets its out-of-sight clock back")
	c2.give_up()
	# Into the light with no light on the floor to go by (a test floor;
	# Pursuit.may_enter): never prowling, only once its strike has landed.
	# On the tomb's floor the light's own cap decides (the snake below).
	var lc := Pursuit.new(h, gives_up)
	var prowl_ok := lc.may_enter(false) and not lc.may_enter(true)
	lc.notice(true)
	var noticed_ok := not lc.may_enter(true)
	lc.hit(true)
	var hit_ok := lc.may_enter(true)
	lc.give_up()
	ok(prowl_ok and noticed_ok and hit_ok and not lc.may_enter(true), "with no light on the floor to go by: a lit room is closed to its prowling and to a chase until its strike lands, open to the chase after (chase_enters_light), closed again once it gives you up")
	var back_s := float(Pursuit.RULES.get("back_to_dark_s", 4.0))
	var v_near := Pursuit.back_to_dark_mps(2.0, 2.0)
	var v_far := Pursuit.back_to_dark_mps(18.0, 2.0)
	ok(v_near == 2.0 and 18.0 / v_far < back_s and v_far > 2.0, "given up in the light it hurries back to the dark within back_to_dark_s %.1f s (18 m at %.1f m/s; 2 m at its own 2.0)" % [back_s, v_far])
	# A freed hunter drops out.
	var h2 := Node3D.new()
	main.add_child(h2)
	Pursuit.new(h2, gives_up).notice()
	ok(harm.chased(), "a hunter noticing you pursues you (§FD)")
	h2.free()
	ok(not harm.chased(), "a hunter freed mid-chase drops out")
	# The wake clears the list; one still after you is back on its next step.
	var c3 := Pursuit.new(h, gives_up)
	c3.notice(true)
	harm.reset()
	ok(not harm.chased(), "waking (Harm.reset), nothing pursues you")
	c3.step(0.1, true, 3.0, true)
	ok(harm.chased(), "a hunter still after you is back on its next step")
	c3.give_up()
	h.queue_free()


func _good_night() -> void:
	harm.reset()
	_hit()
	_run_for(0.7)
	_hit()
	_run_for(0.7)
	var took := _hit()
	ok(took and harm.taking, "hit 3: taken, as built")
	var close := float((Harm.D.taken as Dictionary).close_s)
	_run_for(close * 0.5)
	var want := float(Harm.ring_look(harm.ring).alpha) * (1.0 - harm.black)
	ok(harm.black > 0.3 and absf(harm._ring.alpha - want) < 0.02, "the ring goes under the closing black (black %.2f, ring alpha %.2f)" % [harm.black, harm._ring.alpha])
	harm.reset()


# --- The snake (queue 49's Boss) -------------------------------------------------

func _boot(sv: int) -> CrawlerMain:
	OS.set_environment("SEED", str(sv))
	var m: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(m)
	for i in 10:
		await physics_frame
	while not m.baked or not m.boss.started:
		await process_frame
	m.boss.auto = false
	m.harm.set_process(false)
	m.harm.reset()
	return m


func _done(m: CrawlerMain) -> void:
	m.queue_free()
	await process_frame
	Engine.time_scale = 1.0


## The snake and Harm stepped together `secs` s (you stand as placed).
func _sim(m: CrawlerMain, secs: float, stop: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		m.boss.tick(DT)
		m.harm.tick(DT)
		Engine.time_scale = 1.0
		t += DT
		if stop.is_valid() and bool(stop.call()):
			break
	return t


## The snake held where it lies, its noticing and its chase's rules running.
func _sim_held(m: CrawlerMain, secs: float, stop: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		m.boss._notice(DT)
		m.boss._chase(DT)
		m.harm.tick(DT)
		t += DT
		if stop.is_valid() and bool(stop.call()):
			break
	return t


func _place(pl: CrawlerPlayer, at: Vector3, look: Vector3) -> void:
	var flat := Vector3(look.x - at.x, 0.0, look.z - at.z)
	pl.spawn_flat(at, atan2(-flat.x, -flat.z), 0.0)


func _torch(pl: CrawlerPlayer, lit: bool) -> void:
	if not pl.inventory.has_kind("torch"):
		pl.inventory.add(Inventory.make("torch"))
	pl.weapon = "torch"
	if lit and not pl.torch.lit():
		pl.torch.light()
	elif not lit and pl.torch.lit():
		pl.torch.put_out("stowed")


func _light(m: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(m.world.get("days")))
	for i in 600:
		FireStore.tick(self, 1.0 / 60.0, h.global_position)
		if FireStore.is_lit(h):
			return


## A spot `d` m from its head in its own dark, in its sight (as boss_check).
func _beside(b: Boss, d: float) -> Vector3:
	for k in 16:
		var a := TAU * k / 16.0
		var q := b.head + Vector3(cos(a), 0.0, sin(a)) * d
		q.y = b._floor_y(q)
		var id := b.ground.node_at(q)
		if id >= 0 and b.ground.is_ground(id) and (id == b.node or not b.ground.link(id, b.node).is_empty()) and not b._blocked(b.head + Vector3(0, 0.6, 0), q + Vector3(0, 0.6, 0), false):
			var pc: Dictionary = b.lay.pieces[int(b.ground.nodes[id].piece)]
			var aa := Delves.along_across(pc, Vector2(q.x, q.z))
			if aa.x > 0.4 and aa.x < float(pc.len) - 0.4 and absf(aa.y) < float(pc.half) - 0.45:
				return q
	return Vector3.INF


## Every node's floor middle, and points along each corridor stretch.
func _spots(b: Boss) -> Array:
	var out: Array = []
	for n in b.ground.nodes:
		out.append(n.center)
		if str(n.kind) == "stretch":
			var pc: Dictionary = b.lay.pieces[int(n.piece)]
			var a := float(n.a0) + 0.6
			while a < float(n.a1) - 0.6:
				out.append(BossGround.point(pc, a, 0.0))
				a += 1.5
	return out


## You with your lit torch somewhere between `lo` and `hi` m from its head
## where it can't see the flame (false if there is nowhere).
func _hide(m: CrawlerMain, lo: float, hi: float) -> bool:
	var b := m.boss
	for q: Vector3 in _spots(b):
		var d := (q - b.head).length()
		if d < lo or d > hi:
			continue
		_place(m.player, q, b.head)
		if b._blocked(b._eye(), m.player.torch.flame_position(), false):
			return true
	return false


## One hit lands, then it keeps you in its sight 3 m off for 15 s, held
## where it is: nothing heals; out of its sight, it gives you up after
## out_of_sight_s, and the hit heals one step_s later.
func _snake_holds(sv: int) -> void:
	var m := await _boot(sv)
	var b := m.boss
	var h := m.harm
	var pl := m.player
	var spot := _beside(b, 1.2)
	if spot == Vector3.INF:
		ok(false, "a spot beside the snake in its dark (seed %d)" % sv)
		await _done(m)
		return
	# Torch out: it comes straight in.
	_torch(pl, false)
	_place(pl, spot, b.head)
	await physics_frame
	var landed0 := h.landed
	var t_hit := _sim(m, 10.0, func(): return h.landed > landed0)
	ok(h.landed == landed0 + 1 and b.noticed and b.pursuit.on and b.pursuit.has_hit and h.chased(), "a strike in its dark: one hit (%.1f s), and it is pursuing you (Harm.chased)" % t_hit)
	# Held: you 3 m off in its sight, your torch lit, for 15 s.
	var near := _beside(b, 3.0)
	if near == Vector3.INF:
		near = spot
	_torch(pl, true)
	_place(pl, near, b.head)
	# (A lambda keeps its own copy of a local: the tally lives in a
	# dictionary.)
	var seen := {"lost": 0}
	_sim_held(m, 15.0, func():
		if not b.perceives:
			seen.lost += 1
		return false)
	ok(h.hits.size() == 1 and b.pursuit.on and h.chased() and int(seen.lost) == 0, "kept in its sight 3 m off for 15 s, nothing heals (%d hit, its chase on, it saw you every step)" % h.hits.size())
	# Out of its sight, the torch still lit.
	var oos := float(gives_up.get("out_of_sight_s", 6.0))
	if not _hide(m, 4.0, float(gives_up.get("distance_m", 24.0)) - 2.0):
		ok(false, "a spot out of its sight within its distance_m (seed %d)" % sv)
		await _done(m)
		return
	var t_gone := _sim_held(m, oos + 3.0, func(): return not b.pursuit.on)
	ok(not b.pursuit.on and b.pursuit.why == "out_of_sight" and absf(t_gone - oos) < 0.35 and not h.chased(), "out of its sight (torch lit, %.1f m off), it gives you up after %.1f s (out_of_sight_s %.1f)" % [(pl.global_position - b.head).length(), t_gone, oos])
	var step_s := float((Harm.D.recover as Dictionary).step_s)
	var t_heal := 0.0
	while not h.hits.is_empty() and t_heal < step_s + 2.0:
		h.tick(DT)
		t_heal += DT
	ok(h.hits.is_empty() and absf(t_heal - step_s) < 0.2, "and the hit heals %.1f s later (one step_s, %.1f)" % [t_heal, step_s])
	await _done(m)


## A room next to its dark relit: it strikes you in the dark; you step
## deep into the light, and it follows you only to the light's edge (Mike's
## note of 7 Oct: "the snake can follow you but not get close to the fire";
## before it, §FD's chase followed you in once its strike had landed and
## struck you there). It watches you from the edge, nothing heals, no
## strike reaches you; it gives you up after watch_s and is back in the
## dark within back_to_dark_s.
func _snake_follows(sv: int) -> void:
	var m := await _boot(sv)
	var b := m.boss
	var h := m.harm
	var pl := m.player
	var g := b.ground
	var lf := m.residents.light
	var pair := _room_by_dark(m)
	if pair.is_empty():
		ok(false, "a room to relight beside a stretch of its dark (seed %d)" % sv)
		await _done(m)
		return
	var room := int(pair.room)
	var dark := int(pair.dark)
	ok(not g.is_ground(room) and g.is_ground(dark), "relit: room %d (a %s) is lit, the %s beside it (node %d) still its dark" % [room, m.lay.pieces[int(g.nodes[room].piece)].get("room_kind", "room"), g.nodes[dark].kind, dark])
	# The snake in that dark, you beside it, your torch out.
	if str(g.nodes[dark].kind) == "room":
		b._lie_coiled(dark)
	else:
		b._lie_along(dark)
	b.noticed = false
	var spot := _beside(b, 1.2)
	if spot == Vector3.INF:
		ok(false, "a spot beside the snake in node %d (seed %d)" % [dark, sv])
		await _done(m)
		return
	_torch(pl, false)
	_place(pl, spot, b.head)
	await physics_frame
	var landed0 := h.landed
	_sim(m, 10.0, func(): return h.landed > landed0)
	ok(h.landed == landed0 + 1 and b.pursuit.has_hit, "it strikes you in its dark: one hit, its teeth in you")
	# Deep into the lit room, the torch lit (it sees you go): out of its
	# reach of any floor the light lets it stand on.
	var deep := _deep_in(m, room, b.strike.reach_m)
	if deep == Vector3.INF:
		ok(false, "a spot deep in the lit room, out of its reach of the light's edge (seed %d)" % sv)
		await _done(m)
		return
	_torch(pl, true)
	_place(pl, deep, b.head)
	# As near as the light lets it come: the end of its own way to you on
	# the chase's grid (TombNav, CAP).
	var way := m.residents.nav.path(b.base, deep, true, TombNav.CAP)
	var edge_m := Vector2(way[way.size() - 1].x - deep.x, way[way.size() - 1].z - deep.z).length() if not way.is_empty() else INF
	var landed1 := h.landed
	var back_s := float(Pursuit.RULES.get("back_to_dark_s", 4.0))
	var watch_s := b.num("watch_s", 10.0)
	var w := {"t": 0.0, "peak": 0.0, "near": INF, "watch": 0.0, "gave": -1.0, "why": "", "dark": -1.0, "healed": false, "under": false, "at": Vector3.INF}
	_sim(m, watch_s + back_s + 12.0, func():
		w.t += DT
		if b.chasing():
			# Once under the cap, never past it again (it may have been laid,
			# or have found you, in a fire's spill, and go out of it first;
			# given you up, it leaves the light by the dimmest way, however
			# bright, and is no longer chasing even if it sees you again).
			if lf.at(b.base) <= lf.cap:
				w.under = true
			if bool(w.under):
				w.peak = maxf(float(w.peak), lf.at(b.base))
			var dn := Vector2(b.base.x - deep.x, b.base.z - deep.z).length()
			if dn < float(w.near):
				w.near = dn
				w.at = b.base
		if b.state == "watch":
			w.watch += DT
		if float(w.gave) < 0.0 and not b.pursuit.on:
			w.gave = w.t
			w.why = b.pursuit.why
		if float(w.gave) < 0.0 and h.hits.is_empty():
			w.healed = true
		if float(w.gave) >= 0.0 and float(w.dark) < 0.0 and g.is_ground(g.node_at(b.base)) and not b._in_tunnel():
			w.dark = w.t - float(w.gave)
		return float(w.dark) >= 0.0)
	var cap := lf.cap
	var glow := _glow_near(lf, w.at, 0.75) if w.at != Vector3.INF else 0.0
	ok(bool(w.under) and float(w.peak) <= cap + 1e-4 and float(w.near) <= edge_m + 0.6 and float(w.near) > b.strike.reach_m, "you step deep into the lit room (the light %.2f where you stand): it follows you to the light's edge and no further (the light at its feet %.3f at most, the cap %.3f; %.1f m from you at the nearest, its way on the chase's grid ending %.1f m from you; the most light within 0.75 m of it there %.2f), Mike's note of 7 Oct" % [lf.at(deep), float(w.peak), cap, float(w.near), edge_m, glow])
	ok(h.landed == landed1 and not bool(w.healed) and float(w.watch) > 0.5, "it watches you from there (%.1f s): no strike reaches you in the light, and nothing heals while it does" % float(w.watch))
	ok(float(w.gave) > 0.0 and float(w.dark) >= 0.0 and float(w.dark) <= back_s, "it gives you up (%s, %.1f s on) and is back in the dark %.1f s later (back_to_dark_s %.1f)" % [str(w.why), float(w.gave), float(w.dark), back_s])
	await _done(m)


## The most light on open floor within `r` m of `p`, joined to it by open
## floor (the glow just beyond where it stands, never through a wall).
func _glow_near(lf: LightField, p: Vector3, r: float) -> float:
	var nav := lf.nav
	var c := nav.nearest_open(nav.cell_of(p), 2)
	if c.x < 0:
		return 0.0
	var best := 0.0
	var seen := {c: true}
	var todo: Array[Vector2i] = [c]
	while not todo.is_empty():
		var q: Vector2i = todo.pop_back()
		best = maxf(best, nav.light_of(q))
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nq := q + o
			if seen.has(nq) or not nav.is_open(nq):
				continue
			seen[nq] = true
			var wp := nav.point_of(nq)
			if Vector2(wp.x - p.x, wp.z - p.z).length() <= r:
				todo.append(nq)
	return best


## The open floor in node `id` deepest in the light: brightest, with no
## floor the chase may stand on (under the cap) within `reach` and a
## half (INF if none).
func _deep_in(m: CrawlerMain, id: int, reach: float) -> Vector3:
	var g := m.boss.ground
	var nav := m.residents.nav
	var lf := m.residents.light
	var pc: Dictionary = m.lay.pieces[int(g.nodes[id].piece)]
	var best := Vector3.INF
	var best_l := -INF
	var al := 0.5
	while al < float(pc.len) - 0.5:
		var ac := -float(pc.half) + 0.5
		while ac < float(pc.half) - 0.5:
			var q := BossGround.point(pc, al, ac)
			if nav.is_open(nav.cell_of(q)) and g.node_at(q) == id and not lf.edge_within(q, reach + 0.5):
				var lv := lf.at(q)
				if lv > best_l:
					best_l = lv
					best = q
			ac += 0.25
		al += 0.25
	return best


## The hearth room stays shut to it even in a chase that has had you (its
## ways never go through it, BossGround, and the hearth's light passes the
## chase's cap well outside its door): it lies in the dark just outside the
## hearth room's door, hits you there, you step in by the fire, and it
## never comes in; it watches from its dark and gives you up, and you heal.
func _snake_hearth(sv: int) -> void:
	var m := await _boot(sv)
	var b := m.boss
	var g := b.ground
	var h := m.harm
	var pl := m.player
	var w: Array = m.lay.wake
	var hearth := g.node_at(w[0])
	var outside := -1
	var via := Vector3.ZERO
	for l in g.nodes[hearth].links:
		if g.is_ground(int(l.to)):
			outside = int(l.to)
			via = l.via
			break
	if outside < 0:
		ok(false, "a stretch of its dark at the hearth room's door (seed %d)" % sv)
		await _done(m)
		return
	if str(g.nodes[outside].kind) == "room":
		b._lie_coiled(outside)
	else:
		b._lie_along(outside)
	b.noticed = false
	var spot := _beside(b, 1.2)
	if spot == Vector3.INF:
		ok(false, "a spot beside the snake by the hearth room (seed %d)" % sv)
		await _done(m)
		return
	_torch(pl, false)
	_place(pl, spot, b.head)
	await physics_frame
	var landed0 := h.landed
	_sim(m, 10.0, func(): return h.landed > landed0)
	# In by the fire, 2.5 m inside the door, the torch lit: in its sight.
	var c: Vector3 = g.nodes[hearth].center
	var into := Vector3(c.x - via.x, 0.0, c.z - via.z).normalized()
	var by_fire := via + into * 2.5
	by_fire.y = b._floor_y(by_fire)
	_torch(pl, true)
	_place(pl, by_fire, b.head)
	var inside := {"steps": 0, "watch": 0.0}
	_sim(m, 30.0, func():
		if g.node_at(b.base) == hearth:
			inside.steps += 1
		if b.state == "watch":
			inside.watch += DT
		return false)
	ok(h.landed == landed0 + 1 and int(inside.steps) == 0 and h.hits.size() == 1, "after a hit at its door you step in by the hearth, in its sight (%.1f m): for 30 s it never comes into the hearth room (%.0f s watching from its dark), and nothing heals: it hasn't lost you" % [(pl.global_position - b.head).length(), float(inside.watch)])
	# Hidden (§FC.2): out of its sight deeper in the hearth room, and your
	# torch smothered, since a lit one gives you away round cover (it
	# finds you again from along its corridor otherwise).
	var hid := false
	var pc: Dictionary = m.lay.pieces[int(g.nodes[hearth].piece)]
	var al := 0.6
	while al < float(pc.len) - 0.6 and not hid:
		var ac := -float(pc.half) + 0.6
		while ac < float(pc.half) - 0.6 and not hid:
			var q := BossGround.point(pc, al, ac)
			q.y = b._floor_y(q)
			var off_fire := Vector2(q.x - (m.lay.hearth as Vector3).x, q.z - (m.lay.hearth as Vector3).z).length()
			if g.node_at(q) == hearth and off_fire > 1.4:
				_place(pl, q, b.head)
				hid = b._blocked(b._eye(), pl.torch.flame_position(), false)
			ac += 0.5
		al += 0.5
	_torch(pl, false)
	var t := _sim(m, 15.0, func(): return not b.pursuit.on)
	ok(not b.pursuit.on and g.node_at(b.base) != hearth, "%s and your torch smothered, it gives you up %.1f s on (%s)" % ["out of its sight behind the hearth room's wall" if hid else "in the hearth room", t, b.pursuit.why])
	var step_s := float((Harm.D.recover as Dictionary).step_s)
	var t_heal := _sim(m, step_s + 2.0, func(): return h.hits.is_empty())
	ok(h.hits.is_empty() and absf(t_heal - step_s) < 0.2, "and by the hearth the hit heals %.1f s after it lets you go (one step_s)" % t_heal)
	await _done(m)


## A lit-able room (its own torches, not the hearth room) with a stretch
## or room of the dark beside it once relit: {"room", "dark"}, its torches
## lit; {} if none.
func _room_by_dark(m: CrawlerMain) -> Dictionary:
	var g := m.boss.ground
	for n in g.nodes:
		if str(n.kind) != "room" or bool(n.hearth) or (n.holders as Array).is_empty():
			continue
		for l in n.links:
			var other: Dictionary = g.nodes[int(l.to)]
			if bool(other.hearth):
				continue
			# Light the room's own torches, and see.
			for i in n.holders:
				_light(m, m.fires.holders[int(i)])
			m.boss._refresh(false)
			if not g.is_ground(int(n.id)) and g.is_ground(int(l.to)):
				return {"room": int(n.id), "dark": int(l.to)}
	return {}


## A floor spot at least `d` m from the snake's head (INF if none).
func _far_spot(m: CrawlerMain, d: float) -> Vector3:
	var best := Vector3.INF
	var best_d := 0.0
	for q: Vector3 in _spots(m.boss):
		var dd := (q - m.boss.head).length()
		if dd > best_d:
			best_d = dd
			best = q
	return best if best_d >= d else Vector3.INF


## Half the tomb relit (outward from the hearth), you just inside the lit
## side of the doorways nearest it (the first floor past its reach of the
## light's edge) with your torch lit, five minutes, moved every 10 s to
## the one nearest it now: it sees you, comes to the edge of the light,
## watches and gives you up, again and again; chasing, it never steps
## from under the light's cap to past it (Mike's note of 7 Oct; before it,
## it never stood in a lit node at all until its strike had landed; one
## that finds you in a fire's spill goes out of it first), it never steps
## into a lit node of its own accord, and no strike reaches you.
func _snake_keeps_out(sv: int) -> void:
	var m := await _boot(sv)
	var b := m.boss
	var g := b.ground
	var pl := m.player
	var lf := m.residents.light
	var nav := m.residents.nav
	var reach := b.strike.reach_m
	var order: Array = _outward(m)
	for k in order.size() / 2:
		_light(m, m.fires.holders[int(order[k])])
	b._refresh(false)
	lf.refresh()
	# The lit side of each doorway onto its dark: the first open floor in
	# from the doorway past its reach of the light's edge (the chase's own
	# way there, TombNav's capped grid from the dark beyond the doorway,
	# ends further than its reach from you).
	var doors: Array = []
	for n in g.nodes:
		if g.is_ground(int(n.id)) or bool(n.hearth):
			continue
		for l in n.links:
			if not g.is_ground(int(l.to)) or l.has("tunnel"):
				continue
			var via: Vector3 = l.via
			var into := Vector3((n.center as Vector3).x - via.x, 0.0, (n.center as Vector3).z - via.z)
			if into.length() < 0.1:
				continue
			into = into.normalized()
			var from: Vector3 = g.nodes[int(l.to)].center
			var d := 0.5
			while d < 12.0:
				var q := via + into * d
				q.y = b._floor_y(q)
				if g.node_at(q) == int(n.id) and nav.is_open(nav.cell_of(q)) and lf.at(q) > lf.cap:
					var pts := nav.path(from, q, true, TombNav.CAP)
					if not pts.is_empty() and Vector2(pts[pts.size() - 1].x - q.x, pts[pts.size() - 1].z - q.z).length() > reach + 0.3:
						doors.append(q)
						break
				d += 0.25
	if doors.is_empty():
		ok(false, "lit doorways onto its dark (seed %d)" % sv)
		await _done(m)
		return
	_torch(pl, true)
	var past_cap := 0
	var steps := 0
	var after_t := 0.0
	var watched := 0.0
	var peak := 0.0
	var was_under := false
	while steps * DT < 300.0:
		if steps % int(round(10.0 / DT)) == 0:
			var best: Vector3 = doors[0]
			for q: Vector3 in doors:
				if (q - b.head).length() < (best - b.head).length():
					best = q
			_place(pl, best, b.head)
		steps += 1
		b.tick(DT)
		m.harm.tick(DT)
		Engine.time_scale = 1.0
		if b.noticed:
			after_t += DT
		if b.state == "watch":
			watched += DT
		if b.chasing() and not b._in_tunnel():
			# A step past the cap from under it (finding you in a fire's spill,
			# it goes out of it to the edge first: not a step into it).
			var lv := lf.at(b.base)
			if lv > lf.cap + 1e-4 and was_under:
				past_cap += 1
				peak = maxf(peak, lv)
			was_under = lv <= lf.cap + 1e-4
		else:
			was_under = false
	ok(after_t >= 30.0, "five minutes just inside the lit doorways (%d onto its dark): it was after you %.0f s of it, %.0f s watching from the light's edge" % [doors.size(), after_t, watched])
	ok(past_cap == 0 and b.lit_entries == 0 and b.hits_landed == 0, "chasing, it never stepped from under the chase's cap to past it (%d steps; the light at its feet %.3f at most there, the cap %.3f), never stepped into a lit node of its own accord (%d), and no strike reached you (%d hits)" % [past_cap, peak, lf.cap, b.lit_entries, b.hits_landed])
	await _done(m)


## The holders by their distance from the hearth room (as boss_check).
func _outward(m: CrawlerMain) -> Array:
	var g := m.boss.ground
	var dist: Dictionary = g._dijkstra(0, false, 0.0).dist
	var hs: Array = []
	for i in (m.lay.holders as Array).size():
		var hd: Dictionary = m.lay.holders[i]
		hs.append([float(dist.get(g.node_at(hd.pos), 999.0)), i])
	hs.sort_custom(func(a, b2): return float(a[0]) < float(b2[0]))
	var out: Array = []
	for x in hs:
		out.append(int(x[1]))
	return out
