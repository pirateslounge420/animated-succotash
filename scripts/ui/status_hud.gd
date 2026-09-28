class_name StatusHud
extends Control
## Health, aim and hits, drawn over the view (Hud owns it):
##   * the health meter at the bottom left: a slim R1a-blue bar and a small
##     numeral beside it, pulsing when you're low (feedback.meter). Health
##     never comes back on its own (PlanetPlayer: resting at a fire, food,
##     medicine);
##   * the weapon in hand above the meter;
##   * a crosshair while aiming or in first person, with the bow's draw as
##     a filling arc beneath it (or the spear's raise); otherwise a small
##     dot marks the middle of the view, and when it rests on an animal or
##     a plant near you it opens into a ring and the species' binomial
##     shows beneath it in small italics (LookTarget);
##   * hits (Hits.since(): one event per hit, several at once on one
##     target added up): a small number rising from the impact point for
##     about a second, white, yellow on a critical (a head or an eye),
##     sized by distance within min_px..max_px so it stays readable but
##     never dominates (feedback.number, feedback.colors); on a critical
##     the crosshair (or the dot) flashes into an X for crit_x.hold_s with a
##     short sharp tick (SoundSynth "hitmarker", a UI sound), and a kill
##     holds the X for kill_hold_s. Creature health is never shown as a
##     bar: numbers and behaviour are the readout;
##   * a red flash at the screen's edge when you're hurt, and the dark
##     "You died" curtain.
## All the numbers are data/combat.json "feedback" (Hits.feedback()).

var hp := 100.0
var max_hp := 100.0
var aiming := false
var show_crosshair := false
var draw_power := 0.0 # 0-1 bow power
## The super meter (0-1) and how far into an overcharge the draw is (0-1)
## (design §S: a thin ring round the charge gauge, data/hud.json).
var meter := 0.0
var overcharge := 0.0
static var METER_HUD := Tuning.section("hud", "super_meter")
## The crosshair (hud.json reticle, 480-line px, design §W): four arms,
## each size_px / 2 long, starting gap_px out from the middle.
static var RETICLE := Tuning.section("hud", "reticle")
## The weapon in hand ("Bow", "Spear", "Spear (thrown)").
var weapon := ""
## The binomial under the crosshair (LookTarget), or "".
var look_name := ""
## The X now: seconds left, and whether it's a kill's (tests read these).
var x_left := 0.0
var x_kill := false
## Numbers on screen: [{"e": a Hits event, "t": seconds shown}].
var numbers: Array = []
var _last_hit := 0
var _italic: FontVariation
var _hurt := 0.0
var _death := 0.0
var _dead := false
var _time := 0.0
var _death_label: Label
var _tick: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_label = Label.new()
	_death_label.text = "You died"
	_death_label.add_theme_font_size_override("font_size", 31)
	_death_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
	_death_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	_death_label.add_theme_constant_override("outline_size", 5)
	# Fill the screen and center the text in it (a centered preset before
	# the text has a size puts it off to the top).
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.visible = false
	add_child(_death_label)
	# The hit marker's tick: a UI sound, not placed in the world.
	_tick = AudioStreamPlayer.new()
	_tick.name = "HitTick"
	_tick.stream = SoundSynth.stream("hitmarker", 0)
	add_child(_tick)
	# Nothing reported before the HUD existed shows.
	var old := Hits.since(0)
	if not old.is_empty():
		_last_hit = int(old.back().id)


func flash_hurt() -> void:
	_hurt = 1.0


func set_dead(on: bool) -> void:
	_dead = on
	if not on:
		_death = 0.0
	_death_label.visible = on


func _process(delta: float) -> void:
	_time += delta
	_hurt = maxf(_hurt - delta * 1.8, 0.0)
	_death = move_toward(_death, 0.85 if _dead else 0.0, delta * 0.6)
	_death_label.modulate.a = clampf(_death * 1.5, 0.0, 1.0)
	_update_hits(delta)
	queue_redraw()


## New hits (Hits.since()): a number each, and the X on a critical or a
## kill; numbers age and go.
func _update_hits(delta: float) -> void:
	var fb := Hits.feedback()
	var num: Dictionary = fb.number
	var cx: Dictionary = fb.crit_x
	x_left = maxf(x_left - delta, 0.0)
	for n in numbers:
		n.t += delta
	numbers = numbers.filter(func(n): return n.t < float(num.life_s))
	for e in Hits.since(_last_hit):
		_last_hit = int(e.id)
		numbers.append({"e": e, "t": 0.0})
		if e.killed:
			x_left = maxf(x_left, float(cx.kill_hold_s))
			x_kill = true
			_play_tick(true)
		elif e.crit:
			# A kill's X showing stays a kill's (never cut short).
			if x_left <= 0.0:
				x_kill = false
			x_left = maxf(x_left, float(cx.hold_s))
			_play_tick(false)
	while numbers.size() > int(num.max_on_screen):
		numbers.pop_front()


func _play_tick(kill: bool) -> void:
	if _tick == null or _tick.stream == null:
		return
	var s: Dictionary = Hits.feedback().sound
	_tick.volume_db = float(s.volume_db)
	_tick.pitch_scale = float(s.kill_pitch) if kill else float(s.pitch)
	_tick.play()


func _draw() -> void:
	var size := get_viewport_rect().size
	# Hurt: red at the edges.
	if _hurt > 0.0:
		var c := Color(0.8, 0.05, 0.02, 0.45 * _hurt)
		var w := size.x * 0.12
		draw_rect(Rect2(0, 0, w, size.y), c)
		draw_rect(Rect2(size.x - w, 0, w, size.y), c)
		draw_rect(Rect2(w, 0, size.x - 2 * w, size.y * 0.1), c)
		draw_rect(Rect2(w, size.y * 0.9, size.x - 2 * w, size.y * 0.1), c)
	if _death > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.0, 0.0, _death))
	var fb := Hits.feedback()
	var ink := Color.from_string(str(fb.colors.outline), Color(0.04, 0.07, 0.31))
	_draw_meter(size, fb.meter, ink)
	# The weapon in hand, above the meter.
	if weapon != "" and not _dead:
		var font := get_theme_default_font()
		var at := Vector2(10, size.y - 76)
		draw_string_outline(font, at, weapon, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.05, 0.07, 0.15))
		draw_string(font, at, weapon, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.97, 1.0))
	if not _dead:
		_draw_numbers(fb, ink)
	# The small dot in the middle of the view (or the X), and the name of
	# what it rests on.
	if not _dead:
		var c := size * 0.5
		var dot_ink := Color(0.05, 0.07, 0.15, 0.7)
		if x_left > 0.0:
			_draw_x(c, fb.crit_x, ink)
		elif not show_crosshair:
			if look_name != "":
				draw_arc(c, 3.0, 0.0, TAU, 16, dot_ink, 2.0)
				draw_arc(c, 3.0, 0.0, TAU, 16, Color(1, 1, 1, 0.9), 1.0)
			else:
				draw_circle(c, 1.8, dot_ink)
				draw_circle(c, 1.1, Color(1, 1, 1, 0.8))
		if look_name != "":
			if _italic == null:
				_italic = FontVariation.new()
				_italic.base_font = get_theme_default_font()
				_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
			var at := Vector2(c.x - 135.0, c.y + (20.0 if show_crosshair else 15.0))
			draw_string_outline(_italic, at, look_name, HORIZONTAL_ALIGNMENT_CENTER, 270.0, 9, 3, Color(0.05, 0.07, 0.15))
			draw_string(_italic, at, look_name, HORIZONTAL_ALIGNMENT_CENTER, 270.0, 9, Color(0.95, 0.97, 1.0, 0.95))
	# Crosshair and draw.
	if show_crosshair and not _dead:
		var c := size * 0.5
		if x_left <= 0.0:
			var col := Color(str(RETICLE.get("color", "#7FB0FF")))
			var gap := float(RETICLE.get("gap_px", 3))
			var tip := gap + float(RETICLE.get("size_px", 10)) * 0.5
			var w := float(RETICLE.get("thickness_px", 1))
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(c + d * (gap - 1.0), c + d * (tip + 1.0), Color(0.05, 0.07, 0.15, 0.7), w + 2.0)
				draw_line(c + d * gap, c + d * tip, col, w)
		if aiming:
			draw_arc(c, 11.0, PI * 0.25, PI * 0.75, 12, Color(1, 1, 1, 0.3), 2.0)
			var full := draw_power >= 1.0
			draw_arc(c, 11.0, PI * 0.75 - PI * 0.5 * draw_power, PI * 0.75, 12, Color(1.0, 0.85, 0.3) if full else Color(1, 1, 1, 0.9), 2.0)
			# Overcharging: the gauge fills again in red, over the full one.
			if overcharge > 0.0:
				var red := Color(str(SuperMeter.overcharge("").get("tracer_color", "#FF2A2A")))
				draw_arc(c, 11.0, PI * 0.75 - PI * 0.5 * overcharge, PI * 0.75, 12, red, 2.0)
		# The super meter: a thin ring round the gauge, only when it holds
		# something.
		if meter > float(METER_HUD.get("show_below", 0.02)):
			var ring := Color(str(METER_HUD.get("ring_color", "#FFD23A")))
			draw_arc(c, 14.0, -PI * 0.5, -PI * 0.5 + TAU * meter, 48, ring, float(METER_HUD.get("ring_px", 2)))


## The health meter, bottom left where the hearts were: a slim bar on a
## dark blue track, a bright edge along its top, the numeral beside it;
## below low_share of full health the fill pulses toward the edge color.
func _draw_meter(size: Vector2, m: Dictionary, ink: Color) -> void:
	var w := float(m.width_px)
	var h := float(m.height_px)
	var at := Vector2(10.0, size.y - 64.0 - h * 0.5)
	var share := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var fill := Color.from_string(str(m.fill), Color(0.3, 0.49, 1.0))
	var edge := Color.from_string(str(m.edge), Color(0.5, 0.69, 1.0))
	var track := Color.from_string(str(m.track), Color(0.04, 0.08, 0.63))
	if share < float(m.low_share) and not _dead:
		fill = fill.lerp(edge, 0.5 + 0.5 * sin(_time * 7.0))
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(ink, 0.85))
	draw_rect(Rect2(at, Vector2(w, h)), Color(track, 0.8))
	if share > 0.0:
		draw_rect(Rect2(at, Vector2(w * share, h)), fill)
		draw_rect(Rect2(at, Vector2(w * share, 1.0)), edge)
	var font := get_theme_default_font()
	var px := int(m.numeral_px)
	var text := str(ceili(hp)) if hp > 0.0 else "0"
	var tp := Vector2(at.x + w + 5.0, at.y + h * 0.5 + px * 0.36)
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 3, ink)
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.93, 0.96, 1.0))


## Each number where its impact point is now (Hits.where(): riding the
## animal it's on), risen along the view's up by rise_m over its life,
## sized by the distance, fading over its last fade_s.
func _draw_numbers(fb: Dictionary, ink: Color) -> void:
	if numbers.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var num: Dictionary = fb.number
	var font := get_theme_default_font()
	var life := float(num.life_s)
	var normal := Color.from_string(str(fb.colors.normal), Color.WHITE)
	var crit := Color.from_string(str(fb.colors.critical), Color(1.0, 0.82, 0.23))
	for n in numbers:
		var e: Dictionary = n.e
		var k := clampf(n.t / life, 0.0, 1.0)
		var world := Hits.where(e) + cam.global_basis.y * float(num.rise_m) * (1.0 - pow(1.0 - k, 2.0))
		if cam.is_position_behind(world):
			continue
		var d := maxf(cam.global_position.distance_to(world), 0.5)
		var px := int(round(clampf(float(num.size_px) * pow(float(num.ref_distance_m) / d, float(num.distance_power)), float(num.min_px), float(num.max_px))))
		var alpha := clampf((life - n.t) / maxf(float(num.fade_s), 0.01), 0.0, 1.0)
		var text := str(maxi(roundi(float(e.amount)), 1))
		var p := cam.unproject_position(world)
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var at := p + Vector2(-sz.x * 0.5, px * 0.35)
		var col: Color = crit if e.crit else normal
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(3, px / 4), Color(ink, alpha * 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, alpha))


## The Black Ops-style X over the middle of the view: four short strokes
## out from a small gap, on a dark edge; the kill's color for a kill.
func _draw_x(c: Vector2, x: Dictionary, ink: Color) -> void:
	var col := Color.from_string(str(x.kill_color if x_kill else x.color), Color.WHITE)
	var reach := float(x.size_px)
	var gap := float(x.gap_px)
	var wpx := float(x.width_px)
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var u := d.normalized()
		draw_line(c + u * (gap - 0.5), c + u * (reach + 0.5), ink, wpx + 2.0)
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var u := d.normalized()
		draw_line(c + u * gap, c + u * reach, col, wpx)
