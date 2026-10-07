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
##    re-notice resetting it; a lit room open to a chase only once its
##    strike has landed, and back to the dark within back_to_dark_s after;
##    a freed hunter drops out; a wake
##    (Harm.reset) clears the list and a hunter still after you is back on
##    its next step;
##  - hit 3: "Good night" as built, the ring going under the closing black.

var fails := 0
var main: CrawlerMain
var harm: Harm
var p: CrawlerPlayer
var gives_up: Dictionary


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
	# Into the light (§FD): never prowling, only once its strike has landed.
	var lc := Pursuit.new(h, gives_up)
	var prowl_ok := lc.may_enter(false) and not lc.may_enter(true)
	lc.notice(true)
	var noticed_ok := not lc.may_enter(true)
	lc.hit(true)
	var hit_ok := lc.may_enter(true)
	lc.give_up()
	ok(prowl_ok and noticed_ok and hit_ok and not lc.may_enter(true), "a lit room is closed to its prowling and to a chase until its strike lands, open to the chase after (chase_enters_light), closed again once it gives you up")
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
