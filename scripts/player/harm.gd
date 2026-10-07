class_name Harm
extends Node
## Three hits, no bar (design 4 Oct §EA, data/harm.json), the ambient
## profile only: the ninja game keeps PlanetPlayer.hp and its status bar.
##
## A creature's hit (or a ram's knockback landing: PlanetPlayer.take_hit,
## anything but the dark's catch) no longer takes health: it counts one,
## and hits_to_take of them take you. Amended by §EC (4 Oct, 19:33): every
## hit is unmistakable (a dark-navy flash at the frame's edges, a camera
## kick, a thud and a breath, a hitstop of a few frames); after a hit no
## other counts for invuln_s; one hit heals every recover.step_s, and any
## new hit sets that timer back to a full step_s (no window, no "break
## contact").
##   hit 1  the frame's edges darken and the colour drains a little toward
##          the dark's navy (never grey: PostGrade.set_harm), sound goes a
##          little muffled (the Master bus: muffle_db and a low-pass);
##   hit 2  the same, deeper, and a fast heartbeat comes up under
##          everything (heart_bpm);
##   hit 3  taken: the dark closes the frame to black over close_s, "Good
##          night" in big red letters inside the 480-line frame, held
##          hold_s, faded over fade_s, then the §DE wake (main: home hearth
##          else the nearest lit fire with folk, the lost days, the found
##          line, "Struck down by a {creature}").
## Recovery mirrors it: a hit heals every step_s (the timer reset by any
## hit); healing from 2 to 1 the heartbeat slows and stops first, then the
## dark pulls back (the stage's look eases to the next one down).
##
## In the crawler (Torchfire 1; design 6 Oct §FD, with §FJ.3's ring and
## heartbeat, harm.json fd) the stages look and sound different, and you
## heal only once nothing is chasing you; the open world keeps all of the
## above:
##   hit 1  a red ring closes round the edge of the view (fd.hit_1_edge:
##          its colour, its depth as a share of the frame's short side,
##          its alpha; HarmRing, inside the 480-line frame) and the
##          heartbeat starts (heart_bpm, heart_db);
##   hit 2  the ring goes darker red and reaches a little further in
##          (fd.hit_2_edge), the heart beats harder and faster;
##   hit 3  "Good night", as above.
## The ring and the heart replace the darkening, the drain and the muffle
## (no grade, no Master-bus muffle in the crawler); §EC's navy flash on
## every hit stays. Healing steps back down the same way: 2 to 1 the ring
## eases back to hit 1's and the heart slows and softens; 1 to 0 the heart
## settles and stops first, then the ring pulls back to the edge.
## Pursuit (§FD): whatever hunts you (Pursuit: the boss now, residents
## later) registers when it notices or hits you and clears when it gives
## you up; recover.step_s counts only while nothing is (fd.recover_starts
## "pursuer_gives_up"), held at zero until then, and any new hit resets it
## as built. Light doesn't heal (fd.light_heals false): nothing here looks
## at the light.

static var instance: Harm = null
static var D: Dictionary = Tuning.table("harm")
static var FD: Dictionary = D.get("fd", {})
## The ring's canvas layer: over the grade (PostGrade, -1), under the
## crawler's UI (10: the log, the settings, the fades).
const RING_LAYER := 5

var player: PlanetPlayer
var post: PostGrade
var hud: Hud
## Times (s, this node's clock) of the hits that still count.
var hits: Array = []
## The stage the hits make (0, 1, 2) and the look now, eased toward it.
var stage := 0
var vignette := 0.0
var desaturate := 0.0
var muffle_db := 0.0
## The heartbeat: on, and its pace (bpm) now.
var heart := false
var heart_bpm := 0.0
var beats := 0
## Taken: the sequence's clock (s since hit 3) and its parts 0-1.
var taking := false
var taken_t := 0.0
var black := 0.0
var text_alpha := 0.0
var cause := ""
## Dead some other way (a fall, the dark's catch): the same closing and
## "Good night", but nobody to take (main waits taken_s()).
var _dead_already := false
## Tools: the clock (s) and a stand-in for the real one.
var now := 0.0
var _last_hit := -INF
var _step_t := 0.0
var _beat_t := 0.0
var _heart: AudioStreamPlayer
var _thud: AudioStreamPlayer
## The edge flash now (0-1 of hit_feedback.edge_flash.alpha), and how many
## hits have landed (tools).
var flash := 0.0
var landed := 0
var _bus_fx := -1
var _lpf: AudioEffectLowPassFilter
## §FD in the crawler (setup(): while GameMode.crawler_running): the ring,
## the heartbeat from hit 1, recovery only once nothing pursues you.
var fd := false
## Who is chasing you now (§FD): the hunters' nodes, by pursue(); a freed
## one drops out by itself.
var pursuers: Array = []
## The ring now: 0 none, 1 hit 1's, 2 hit 2's, eased between (_fd_look).
var ring := 0.0
## The heartbeat's loudness now (dB; fd.hit_N_edge heart_db).
var heart_db := 0.0
var _ring_layer: CanvasLayer
var _ring: HarmRing


static func active() -> bool:
	return instance != null and Tuning.profile() == "ambient" and not D.is_empty()


func setup(p_player: PlanetPlayer, p_post: PostGrade, p_hud: Hud) -> void:
	player = p_player
	post = p_post
	hud = p_hud
	instance = self
	_heart = AudioStreamPlayer.new()
	_heart.name = "Heartbeat"
	_heart.stream = SoundSynth.stream("heartbeat", 0)
	add_child(_heart)
	_thud = AudioStreamPlayer.new()
	_thud.name = "HitThud"
	add_child(_thud)
	fd = GameMode.crawler_running and not FD.is_empty()
	if fd:
		# §FJ.3: the ring, not the grade's dark nor the muffle (the Master
		# bus stays the volume slider's alone).
		_ring_layer = CanvasLayer.new()
		_ring_layer.name = "HarmRingLayer"
		_ring_layer.layer = RING_LAYER
		add_child(_ring_layer)
		_ring = HarmRing.new()
		_ring.name = "HarmRing"
		_ring_layer.add_child(_ring)
		return
	# The muffle: a low-pass on the Master bus, wide open until a hit.
	_lpf = AudioEffectLowPassFilter.new()
	_lpf.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _lpf)
	_bus_fx = AudioServer.get_bus_effect_count(0) - 1


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if _bus_fx >= 0 and _bus_fx < AudioServer.get_bus_effect_count(0) and AudioServer.get_bus_effect(0, _bus_fx) == _lpf:
		AudioServer.remove_bus_effect(0, _bus_fx)
		AudioServer.set_bus_volume_db(0, 0.0)


func stage_of(n: int) -> Dictionary:
	return (D.get("stages", {}) as Dictionary).get(str(n), {})


## A hunter has you, or has given you up (§FD; `who` the hunter's node,
## `on` false when it gives you up; Pursuit, the residents): while any
## has you, you don't heal (fd.recover_starts). Harmless twice.
func pursue(who: Object, on := true) -> void:
	if who == null:
		return
	if not on:
		pursuers.erase(who)
	elif not pursuers.has(who):
		pursuers.append(who)


## Anything chasing you now (a hunter freed mid-chase drops out).
func chased() -> bool:
	pursuers = pursuers.filter(func(o) -> bool: return is_instance_valid(o))
	return not pursuers.is_empty()


## The stage's ring and heartbeat in the crawler (§FJ.3), {} at 0.
static func edge_of(n: int) -> Dictionary:
	return FD.get("hit_%d_edge" % n, {}) if n > 0 else {}


## Inside invuln_s of the last hit (§EC): a new one doesn't land.
func invulnerable() -> bool:
	return taking or now - _last_hit < float(D.get("invuln_s", 0.6))


## A hit landed (PlanetPlayer.take_hit). `who` is the death cause
## ("creature:<name>"). Returns true when it takes you.
func hit(who: String) -> bool:
	if taking:
		return true
	if invulnerable():
		return false
	hits.append(now)
	_last_hit = now
	_step_t = 0.0
	cause = who
	landed += 1
	stage = mini(hits.size(), 2)
	_feedback()
	if hits.size() >= int(D.get("hits_to_take", 3)):
		_take()
		return true
	return false


## The hit felt (§EC hit_feedback): the edge flash, the kick, the thud and
## the breath, the hitstop.
func _feedback() -> void:
	var fb: Dictionary = D.get("hit_feedback", {})
	flash = 1.0
	if player != null:
		player.kick(float(fb.get("camera_kick_deg", 4.0)))
	if _thud != null and _thud.is_inside_tree():
		_thud.stream = SoundSynth.stream("thud_breath", landed)
		_thud.play()
	var stop := float(fb.get("hitstop_s", 0.05))
	if stop > 0.0 and is_inside_tree() and Engine.time_scale >= 1.0:
		Engine.time_scale = 0.05
		get_tree().create_timer(stop, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _take() -> void:
	taking = true
	taken_t = 0.0
	stage = 2
	player.typing = true
	if hud != null:
		hud.set_taken(0.0, 0.0, "")


## Every death in the ambient game closes the same way (Mike, 5 Oct: "the
## old You died screen is replaced with Good night"): a fall or the dark's
## catch plays the closing and the words; main waits taken_s().
func close_for_death() -> void:
	if taking:
		return
	taking = true
	_dead_already = true
	taken_t = 0.0
	stage = 2


## All clear (after the wake, a new world).
func reset() -> void:
	hits.clear()
	stage = 0
	flash = 0.0
	taking = false
	_dead_already = false
	taken_t = 0.0
	black = 0.0
	text_alpha = 0.0
	vignette = 0.0
	desaturate = 0.0
	muffle_db = 0.0
	heart = false
	heart_bpm = 0.0
	ring = 0.0
	# Waking, nothing has you (a hunter still after you says so again on
	# its next step, Pursuit.step).
	pursuers.clear()
	if player != null:
		player.typing = false
	if hud != null:
		hud.set_taken(0.0, 0.0, "")
	_apply()


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	now += delta
	var rec: Dictionary = D.get("recover", {})
	var fb: Dictionary = (D.get("hit_feedback", {}) as Dictionary).get("edge_flash", {})
	flash = maxf(flash - delta / maxf(float(fb.get("fade_s", 0.25)), 0.01), 0.0)
	if taking:
		_taken(delta)
	elif not hits.is_empty():
		# One hit heals every step_s; any hit set the timer back (§EC). In
		# the crawler the timer waits at zero while anything is chasing you
		# (§FD: you heal by losing it, counted from when it gives you up).
		if fd and str(FD.get("recover_starts", "")) == "pursuer_gives_up" and chased():
			_step_t = 0.0
		else:
			_step_t += delta
		if _step_t >= float(rec.get("step_s", 5.0)):
			_step_t = 0.0
			hits.pop_front()
			stage = mini(hits.size(), 2)
	if fd:
		_fd_look(delta)
		_apply()
		return
	# The look eases toward the stage's (the dark comes in fast, pulls back
	# slowly); the heart goes first on the way down (recover.heart_first).
	var st := stage_of(stage)
	var want_heart := bool(st.get("heartbeat", false))
	var k_in := 1.0 - exp(-delta * 6.0)
	var k_out := 1.0 - exp(-delta * 0.8)
	var tv := float(st.get("vignette", 0.0))
	var td := float(st.get("desaturate", 0.0))
	var tm := float(st.get("muffle_db", 0.0))
	if heart and not want_heart:
		# Hold the dark while the heart settles.
		tv = maxf(tv, vignette)
		td = maxf(td, desaturate)
	vignette = lerpf(vignette, tv, k_in if tv > vignette else k_out)
	desaturate = lerpf(desaturate, td, k_in if td > desaturate else k_out)
	muffle_db = lerpf(muffle_db, tm, k_in if tm < muffle_db else k_out)
	var bpm := float(st.get("heart_bpm", stage_of(2).get("heart_bpm", 150)))
	if want_heart:
		heart = true
		heart_bpm = lerpf(heart_bpm if heart_bpm > 0.0 else bpm, bpm, k_in)
	elif heart:
		# The heart settles: slower, then still.
		heart_bpm = lerpf(heart_bpm, 60.0, k_out * 2.0)
		if heart_bpm < 75.0:
			heart = false
			heart_bpm = 0.0
	if heart:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = 60.0 / maxf(heart_bpm, 30.0)
			beats += 1
			if _heart.is_inside_tree():
				_heart.volume_db = -2.0
				_heart.play()
	_apply()


## The crawler's stages (§FD, §FJ.3): the ring eases toward the stage's
## (closing in fast, pulling back slowly) and the heart takes the stage's
## edge: hit 1's pace and loudness, hit 2's harder and faster. Healing from
## 1 to 0 the heart settles and stops first, then the ring pulls back
## (recover.heart_first, as in the open world).
func _fd_look(delta: float) -> void:
	var edge := edge_of(stage)
	var want_heart := bool(edge.get("heartbeat", false))
	var k_in := 1.0 - exp(-delta * 6.0)
	var k_out := 1.0 - exp(-delta * 0.8)
	var target := float(stage)
	if heart and not want_heart:
		# Hold the ring while the heart settles.
		target = maxf(target, minf(ring, 1.0))
	ring = lerpf(ring, target, k_in if target > ring else k_out)
	if absf(ring - target) < 0.002:
		ring = target
	if want_heart:
		var bpm := float(edge.get("heart_bpm", 105.0))
		var db := float(edge.get("heart_db", 0.0))
		if not heart:
			# It starts with the hit: the thud and the breath, then the
			# first beat.
			heart = true
			heart_bpm = bpm
			heart_db = db
			_beat_t = 0.3
		else:
			heart_bpm = lerpf(heart_bpm, bpm, k_in if bpm > heart_bpm else k_out * 2.0)
			heart_db = lerpf(heart_db, db, k_in if db > heart_db else k_out * 2.0)
			if absf(heart_db - db) < 0.05:
				heart_db = db
	elif heart:
		# The heart settles: slower, then still.
		heart_bpm = lerpf(heart_bpm, 60.0, k_out * 2.0)
		if heart_bpm < 75.0:
			heart = false
			heart_bpm = 0.0
	if heart:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = 60.0 / maxf(heart_bpm, 30.0)
			beats += 1
			if _heart.is_inside_tree():
				_heart.volume_db = heart_db
				_heart.play()


## The ring's look at `level` (0-2, §FJ.3): {color, alpha, width_frac}. Up
## to 1 it closes in from the edge to hit 1's depth, fading in over the
## first third of the way; past 1 it darkens and reaches toward hit 2's.
static func ring_look(level: float) -> Dictionary:
	var e1 := edge_of(1)
	var c1 := Color(str(e1.get("color", "#B01818")))
	var a1 := float(e1.get("alpha", 0.6))
	var w1 := float(e1.get("width_frac", 0.1))
	if level <= 1.0:
		return {"color": c1, "alpha": a1 * smoothstep(0.0, 0.35, level), "width_frac": w1 * maxf(level, 0.0)}
	var e2 := edge_of(2)
	var t := clampf(level - 1.0, 0.0, 1.0)
	return {"color": c1.lerp(Color(str(e2.get("color", "#6A0A0E"))), t), "alpha": lerpf(a1, float(e2.get("alpha", 0.8)), t), "width_frac": lerpf(w1, float(e2.get("width_frac", 0.16)), t)}


## Hit 3: the frame closes to black, "Good night", held, faded; then the
## wake.
func _taken(delta: float) -> void:
	var tk: Dictionary = D.get("taken", {})
	var close := float(tk.get("close_s", 1.2))
	var hold := float(tk.get("hold_s", 2.5))
	var fade := float(tk.get("fade_s", 1.5))
	taken_t += delta
	black = clampf(taken_t / close, 0.0, 1.0)
	vignette = maxf(vignette, black)
	if taken_t < close:
		text_alpha = 0.0
	elif taken_t < close + hold:
		text_alpha = 1.0
	else:
		text_alpha = clampf(1.0 - (taken_t - close - hold) / fade, 0.0, 1.0)
	if hud != null:
		hud.set_taken(black, text_alpha, str(tk.get("text", "Good night")), Color(str(tk.get("text_color", "#C81E1E"))), int(tk.get("text_size_px", 40)))
	if taken_t >= close + hold + fade and not player.dead and not _dead_already:
		# Then the §DE wake (main._on_player_died, told by `taking`).
		player.typing = false
		player.death_cause = cause if cause != "" else "creature:something"
		player.fall_taken()


## The full sequence's length (s).
static func taken_s() -> float:
	var tk: Dictionary = D.get("taken", {})
	return float(tk.get("close_s", 1.2)) + float(tk.get("hold_s", 2.5)) + float(tk.get("fade_s", 1.5))


func _apply() -> void:
	if post != null:
		post.set_harm(vignette, desaturate)
	if hud != null:
		var ef: Dictionary = (D.get("hit_feedback", {}) as Dictionary).get("edge_flash", {})
		hud.set_hit_flash(Color(str(ef.get("color", "#0A1440"))), flash * float(ef.get("alpha", 0.55)))
	if fd:
		# The ring (no muffle in the crawler); the closing black covers it.
		if _ring != null:
			var look := ring_look(ring)
			_ring.show_ring(look.color, float(look.alpha) * (1.0 - black), float(look.width_frac))
		return
	AudioServer.set_bus_volume_db(0, muffle_db)
	if _lpf != null:
		# 0 dB wide open; each -4 dB takes the top off a little more.
		_lpf.cutoff_hz = clampf(20000.0 * pow(2.0, muffle_db / 2.5), 900.0, 20000.0)
