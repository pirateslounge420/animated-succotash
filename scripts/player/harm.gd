class_name Harm
extends Node
## Three hits, no bar (design 4 Oct §EA, data/harm.json), the ambient
## profile only: the ninja game keeps PlanetPlayer.hp and its status bar.
##
## A creature's hit (or a ram's knockback landing: PlanetPlayer.take_hit,
## anything but the dark's catch) no longer takes health: it counts one.
## Hits older than window_s are forgotten; hits_to_take of them inside the
## window take you.
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
## Recovery mirrors it: once calm_s pass with no hit, the oldest hit is let
## go every step_s; the heartbeat slows and stops first, then the dark
## pulls back (the stage's look eases to the next one down).

static var instance: Harm = null
static var D: Dictionary = Tuning.table("harm")

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
## Tools: the clock (s) and a stand-in for the real one.
var now := 0.0
var _last_hit := -INF
var _step_t := 0.0
var _beat_t := 0.0
var _heart: AudioStreamPlayer
var _bus_fx := -1
var _lpf: AudioEffectLowPassFilter


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


## A hit landed (PlanetPlayer.take_hit). `who` is the death cause
## ("creature:<name>"). Returns true when it takes you.
func hit(who: String) -> bool:
	if taking:
		return true
	var window := float(D.get("window_s", 20.0))
	hits = hits.filter(func(t: float) -> bool: return now - t <= window)
	hits.append(now)
	_last_hit = now
	_step_t = 0.0
	cause = who
	stage = mini(hits.size(), 2)
	if hits.size() >= int(D.get("hits_to_take", 3)):
		_take()
		return true
	return false


func _take() -> void:
	taking = true
	taken_t = 0.0
	stage = 2
	player.typing = true
	if hud != null:
		hud.set_taken(0.0, 0.0, "")


## All clear (after the wake, a new world).
func reset() -> void:
	hits.clear()
	stage = 0
	taking = false
	taken_t = 0.0
	black = 0.0
	text_alpha = 0.0
	vignette = 0.0
	desaturate = 0.0
	muffle_db = 0.0
	heart = false
	heart_bpm = 0.0
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
	if taking:
		_taken(delta)
	elif not hits.is_empty() and now - _last_hit > float(rec.get("calm_s", 8.0)):
		# Calm: the oldest hit is let go every step_s.
		_step_t += delta
		if _step_t >= float(rec.get("step_s", 6.0)):
			_step_t = 0.0
			hits.pop_front()
			stage = mini(hits.size(), 2)
	# The look eases toward the stage's (the dark comes in fast, pulls back
	# slowly); the heart goes first on the way down (recover.heart_first).
	var st := stage_of(stage)
	var calm := not taking and not hits.is_empty() and now - _last_hit > float(rec.get("calm_s", 8.0)) * 0.5
	var want_heart := bool(st.get("heartbeat", false)) and not (calm and bool(rec.get("heart_first", true)))
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
	if taken_t >= close + hold + fade and not player.dead:
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
	AudioServer.set_bus_volume_db(0, muffle_db)
	if _lpf != null:
		# 0 dB wide open; each -4 dB takes the top off a little more.
		_lpf.cutoff_hz = clampf(20000.0 * pow(2.0, muffle_db / 2.5), 900.0, 20000.0)
