extends SceneTree
## Three hits, no bar (design 4 Oct §EA, data/harm.json), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/harm_check.gd
## Boots the ambient game and, driving Harm's clock by hand (its tick),
## asserts:
##  - a creature's hit takes no health and shows no meter (the status bar
##    stays the ninja game's);
##  - stage 1 darkens the edges, drains the colour and muffles, with no
##    heartbeat; stage 2 deepens it and the heart beats at heart_bpm;
##  - after calm the hits are let go one step at a time: the heartbeat
##    settles first, then stage 2 falls to 1 and 1 to 0, the dark last;
##  - three hits spread past window_s do not take you;
##  - three inside it do: the frame closes to black, "Good night" in red
##    shows, held, faded, then the §DE wake lands at a lit fire with folk
##    (or your hearth), "Struck down by a <creature>" in the log, the
##    harm cleared.

var main
var world
var player: PlanetPlayer
var harm: Harm
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _hit(who := "wolf") -> bool:
	player.death_cause = "creature:" + who
	player._invulnerable = 0.0
	player.take_hit(12.0, player.global_position + player.global_basis.z * 2.0)
	return harm.taking


func _run_for(s: float, step := 0.1) -> void:
	var n := int(s / step)
	for i in n:
		harm.tick(step)


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	harm = main.harm
	ok(harm != null and Harm.active(), "the ambient game has its harm (data/harm.json wired)")
	if harm == null:
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	harm.set_process(false)
	var D := Harm.D
	var hp0 := player.hp
	ok(not (D.get("_help", "") as String).begins_with("[NOT WIRED"), "harm.json is no longer marked not wired")
	# Hit 1.
	_hit()
	_run_for(1.0)
	var s1: Dictionary = harm.stage_of(1)
	ok(player.hp == hp0, "a creature's hit takes no health (%.0f)" % player.hp)
	ok(main.hud._status.ambient, "no health meter on screen (the status bar is the ninja game's)")
	ok(harm.stage == 1 and absf(harm.vignette - float(s1.vignette)) < 0.05 and absf(harm.desaturate - float(s1.desaturate)) < 0.05,
		"hit 1: the edges darken and the colour drains (vignette %.2f, desaturate %.2f)" % [harm.vignette, harm.desaturate])
	ok(harm.muffle_db < float(s1.muffle_db) * 0.8, "hit 1: the sound muffles (%.1f dB)" % harm.muffle_db)
	ok(not harm.heart and harm.beats == 0, "hit 1: no heartbeat")
	# Hit 2.
	_hit()
	_run_for(2.0)
	var s2: Dictionary = harm.stage_of(2)
	ok(harm.stage == 2 and harm.vignette > float(s1.vignette) + 0.1, "hit 2: deeper (vignette %.2f)" % harm.vignette)
	ok(harm.heart and harm.beats >= 3 and absf(harm.heart_bpm - float(s2.heart_bpm)) < 10.0, "hit 2: a fast heartbeat (%d beats in 2 s at %.0f bpm)" % [harm.beats, harm.heart_bpm])
	# Recovery: no hits.
	var t_heart := -1.0
	var t_s1 := -1.0
	var t_s0 := -1.0
	var t_clear := -1.0
	var t := 0.0
	while t < 60.0:
		harm.tick(0.1)
		t += 0.1
		if t_heart < 0.0 and not harm.heart:
			t_heart = t
		if t_s1 < 0.0 and harm.stage <= 1:
			t_s1 = t
		if t_s0 < 0.0 and harm.stage == 0:
			t_s0 = t
		if t_clear < 0.0 and harm.vignette < 0.02:
			t_clear = t
	print("[harm] recovery: heart still %.1f s · stage 1 at %.1f s · stage 0 at %.1f s · dark gone %.1f s" % [t_heart, t_s1, t_s0, t_clear])
	ok(t_heart > 0.0 and t_heart <= t_s1, "the heartbeat settles first (%.1f s, before stage 2 falls at %.1f s)" % [t_heart, t_s1])
	ok(t_s1 > 0.0 and t_s0 > t_s1, "the stages fall back in order (2 → 1 at %.1f s, 1 → 0 at %.1f s)" % [t_s1, t_s0])
	ok(t_clear >= t_s0, "the dark pulls back last (%.1f s)" % t_clear)
	# Three spread past the window.
	var window := float(D.get("window_s", 20.0))
	var spread_taken := false
	for i in 3:
		spread_taken = _hit() or spread_taken
		_run_for(window + 1.0)
	ok(not spread_taken, "three hits spread past %.0f s do not take you" % window)
	_run_for(60.0)
	# Three inside the window: taken.
	var deaths0: int = main.camps.deaths
	_hit("wolf")
	_run_for(2.0)
	_hit("wolf")
	_run_for(2.0)
	var took := _hit("wolf")
	ok(took, "three hits inside %.0f s take you" % window)
	_run_for(float(D.taken.close_s) + 0.2)
	ok(main.hud._status._taken_black > 0.99, "the frame closes to black (%.2f)" % main.hud._status._taken_black)
	ok(main.hud._status.taken_text() == str(D.taken.text), "\"%s\" on screen" % main.hud._status.taken_text())
	var col: Color = main.hud._status._taken_label.get_theme_color("font_color")
	ok(col.r > 0.6 and col.g < 0.2 and col.b < 0.2, "in red (%s)" % col.to_html(false))
	ok(not player.dead, "held before the wake")
	harm.set_process(true)
	var waited := 0.0
	while not player.dead and waited < 15.0:
		await process_frame
		waited += 1.0 / 60.0
	ok(player.dead, "then taken (%.1f s on)" % waited)
	# The wake (main._on_player_died: §DE).
	waited = 0.0
	while player.dead and waited < 120.0:
		await process_frame
		waited += 1.0 / 60.0
	ok(not player.dead, "you wake (%.1f s)" % waited)
	ok(int(main.camps.deaths) == deaths0 + 1, "found by folk (the §DE wake)")
	var from := str(main.last_wake.get("from", ""))
	var fire_ok := Campfire.lit_near(self, player.global_position, 12.0)
	ok(from in ["home", "nearest", "opening"] and fire_ok, "the wake lands at §DE's fire (%s, a lit fire within 12 m: %s)" % [from, str(fire_ok)])
	var struck := false
	for e in GameLog.entries:
		if str(e.get("text", "")).begins_with("Struck down by a wolf"):
			struck = true
	ok(struck, "the log says \"Struck down by a wolf\"")
	ok(harm.hits.is_empty() and not harm.taking and main.hud._status._taken_black == 0.0, "the harm is cleared after the wake")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
