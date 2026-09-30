class_name Hud
extends CanvasLayer
## On-screen readout (DESIGN.md: biome names are labels for the map and
## hover readout only). Temperatures in °C.
##
## The readouts are parts (PARTS; data/hud.json "_help" parts, pins,
## modes): one line each, stacked in a column per top corner so a hidden
## part leaves no gap (top left: time, moon, mansion, season; top right:
## biome, temperature, weather, wind, elevation, position), and the two
## dials, the speedometer and the clock (Readouts). In normal play a part
## shows only if it's pinned (is_pinned(): Settings "hud.speedometer" and
## "hud.clock", on by default, the settings panel's switches; and
## "hud.pin.<part>" for the rest, off by default). H (toggle()) shows the
## full HUD, every part, and H again just the pinned ones. Pinning
## (set_pinning(); main, while the mouse is free after Esc and no screen
## that wants it is open): every part shows, the pinned ones bright with a
## pin mark ("• ") before them, the rest dimmed; the one under the mouse
## brightens and its mark previews; a click on it pins or unpins it (saved
## at once), a click anywhere else takes the mouse back as ever
## (PinCatcher says how). Swimming and Above the clouds aren't parts: they
## show whenever they apply, at the bottom of the right column.

const READOUT_INTERVAL_S := 0.25
## The parts, in order: the top-left column, the top-right column, then
## the dials (Readouts).
const PARTS: Array[String] = ["time", "moon", "mansion", "season", "biome", "temperature", "weather", "wind", "elevation", "position", "speedometer", "clock"]
const LEFT_PARTS: Array[String] = ["time", "moon", "mansion", "season"]
const RIGHT_PARTS: Array[String] = ["biome", "temperature", "weather", "wind", "elevation", "position"]
## While pinning every part's line starts with PIN_PAD, and the pin mark
## is drawn over its first cell (VT323 is monospaced: "• " and "  " are
## the same width, so nothing moves as a pin comes and goes).
const PIN_MARK := "•"
const PIN_PAD := "  "
const PIN_CAPTION := "Click a readout to pin it to the screen · click anywhere else to carry on"
## The columns' distance from the screen's edges (480-line px, design §Y).
const MARGIN := 9
## How far a part's click target reaches past its text, so a column's
## lines meet (px).
const HIT_PAD := 2.0
## hud.json "pins": dim_alpha, hover_alpha, preview_alpha, mark_color.
static var PINS := Tuning.section("hud", "pins")
var _readout_timer := 0.0
## The two columns of parts (VBoxContainers as small as what they show).
var _left: VBoxContainer
var _right: VBoxContainer
## H's full HUD: every part, pinned or not.
var full := false
## Pinning with the mouse (set_pinning()).
var pinning := false
var _parts := {} # id -> its Label (the column parts)
var _marks := {} # id -> its pin mark's Label, over the part's first cell
var _part_text := {} # id -> its line (update_readout())
## Swimming / Above the clouds (not parts), under the right column's parts.
var _context: Label
var _caption: Label
var _catcher: PinCatcher
## While pinning: the part under the mouse, and the one just clicked (its
## preview waits until the mouse has left it, so the click's result shows).
var _hover := ""
var _clicked := ""
## Behind the death curtain (_dim_readouts()): no pinning to be seen or done.
var _dimmed := false
var _hint: Label
var _prompt: Label
var _loading: Control
var _loading_label: Label
var _loading_bar: ProgressBar
var _hint_timer := 18.0
var _subtitle: Label
var _lines: Array = [] # [start_s, speaker, text, seconds]
var _clock := 0.0
var _status: StatusHud
## The speedometer and the watch-face clock (design §L).
var readouts: Readouts
## Debug overlay (F3, spec A4): the clock, the day's phase and the sun and
## moon, for checking the day cycle.
var _debug: Label
var debug_visible := false
## The dev frame-time readout (F2, design §W).
var perf: PerfReadout


func _ready() -> void:
	layer = 10
	_left = _column(false)
	_right = _column(true)
	for id in LEFT_PARTS:
		_add_part(id, _left)
	for id in RIGHT_PARTS:
		_add_part(id, _right)
	_context = _label(HORIZONTAL_ALIGNMENT_RIGHT, _right)
	_context.name = "Context"
	_context.size_flags_horizontal = Control.SIZE_SHRINK_END
	_context.visible = false
	_hint = _label(HORIZONTAL_ALIGNMENT_LEFT)
	# (The four lines of key help stay at the small size: reference, not
	# reading.)
	_hint.add_theme_font_size_override("font_size", HudText.px(20))
	# (Up above the subtitle, the prompt and the weapon line: at the start
	# it sat on the Elder's first words and the bow.)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 9)
	_hint.offset_bottom -= 104
	_hint.offset_top -= 104
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.text = "WASD move · W W sprint · Space jump (at a wall: wall jump · as you land: bounce)\nShift crouch (in the air: drop · as you land: roll) · right click: take, climb, hold on\nleft click: draw / thrust / punch · Q tool · V view · Tab pack\nM map · O settings · F3 debug · H full HUD · Esc frees the mouse: click readouts to pin them"
	if Tuning.profile() == "ambient":
		# The ambient profile (design 30 Sept §AU, §AV): a walk, first
		# person, right click to take and climb; nothing else on the keys.
		_hint.text = "WASD move · W W sprint · Space jump · Shift crouch\nright click: take things, climb the tree in front of you · left click: use what's in hand\nQ tool · Tab pack · Enter log · M map · O settings · F3 debug · H full HUD\nEsc frees the mouse: click readouts to pin them"
	_prompt = _label(HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 47)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.add_theme_font_size_override("font_size", HudText.px(30))
	_subtitle = _label(HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 80)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.add_theme_font_size_override("font_size", HudText.px(30))
	_debug = _label(HORIZONTAL_ALIGNMENT_LEFT)
	_debug.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 9)
	_debug.grow_vertical = Control.GROW_DIRECTION_BOTH
	_debug.add_theme_color_override("font_color", Color(1.0, 0.93, 0.6))
	_debug.visible = false
	_status = StatusHud.new()
	add_child(_status)
	move_child(_status, 0)
	readouts = Readouts.new()
	readouts.name = "Readouts"
	add_child(readouts)
	move_child(readouts, 1)
	perf = PerfReadout.new()
	add_child(perf)
	# Pinning: the caption at the top centre (the columns step down a line
	# under it, _place_columns()) and the click target.
	_caption = _label(HORIZONTAL_ALIGNMENT_CENTER)
	_caption.name = "PinCaption"
	_caption.text = PIN_CAPTION
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.visible = false
	_catcher = PinCatcher.new()
	_catcher.name = "PinCatcher"
	_catcher.hud = self
	add_child(_catcher)
	_build_loading()


func _label(align: HorizontalAlignment, parent: Node = null) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", HudText.px(Tuning.num("hud", "text", "base_px")))
	l.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.15))
	l.add_theme_constant_override("outline_size", 3)
	(parent if parent != null else self).add_child(l)
	return l


## A column of parts in a top corner, only as big as what it shows (a
## hidden part takes no room: anchored with no size of its own, it's its
## minimum size), MARGIN from the edges (_place_columns()).
func _column(right: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Right" if right else "Left"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The lines as close as they were in one Label.
	box.add_theme_constant_override("separation", _line_spacing())
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	if right:
		box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	return box


## A part's line in its column: only as wide as its text (so its rect is
## the line itself, the click target while pinning), with its pin mark.
func _add_part(id: String, box: VBoxContainer) -> void:
	var right := box == _right
	var l := _label(HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, box)
	l.name = id.capitalize()
	l.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	_parts[id] = l
	_part_text[id] = ""
	var m := _label(HORIZONTAL_ALIGNMENT_LEFT, l)
	m.name = "Pin"
	m.text = PIN_MARK
	m.add_theme_color_override("font_color", Color(str(PINS.get("mark_color", "#FFD23A"))))
	m.visible = false
	_marks[id] = m


## The gap between lines in one Label (the theme's line_spacing).
static func _line_spacing() -> int:
	return ThemeDB.get_default_theme().get_constant("line_spacing", "Label")


func _build_loading() -> void:
	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.03, 0.04, 0.12)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_loading)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(280, 0)
	box.position = Vector2(-140, -27)
	_loading.add_child(box)
	var title := Label.new()
	title.text = "Generating planet"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", HudText.px(30))
	box.add_child(title)
	_loading_label = Label.new()
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_label)
	_loading_bar = ProgressBar.new()
	_loading_bar.max_value = 1.0
	_loading_bar.custom_minimum_size = Vector2(280, 12)
	box.add_child(_loading_bar)


func show_loading(step: String, fraction: float) -> void:
	_loading.visible = true
	_loading_label.text = step
	_loading_bar.value = fraction


func hide_loading() -> void:
	_loading.visible = false


## A spoken line as a subtitle ("Elder: You're finally awake."), shown
## `delay` s from now for `seconds`.
func say(speaker: String, text: String, delay: float, seconds: float) -> void:
	_lines.append([_clock + delay, speaker, text, seconds])


func _process(delta: float) -> void:
	_clock += delta
	var shown := ""
	for l in _lines:
		if _clock >= l[0] and _clock < l[0] + l[3]:
			shown = "%s: %s" % [l[1], l[2]]
	_subtitle.text = shown if Settings.get_bool("hud.subtitles") else ""
	_lines = _lines.filter(func(l): return _clock < l[0] + l[3])
	# Pinning: the part under the mouse (the one just clicked keeps showing
	# its new state until the mouse leaves it).
	_hover = part_at(get_viewport().get_mouse_position()) if pinning else ""
	if _hover != _clicked:
		_clicked = ""
	# Every frame, so the settings panel's switches show at once too.
	_apply()


## Context prompt near the bottom of the screen ("Right click: turn over
## the log").
## The health meter, crosshair, the bow's draw (or the spear's raise) and
## the weapon in hand from the player, every frame (the hits' numbers and
## X StatusHud reads for itself, Hits).
func update_status(player: PlanetPlayer) -> void:
	_status.hp = player.hp
	_status.max_hp = PlanetPlayer.MAX_HP
	_status.aiming = player.aiming()
	_status.draw_power = player.aim_power()
	_status.meter = player.meter.value
	_status.overcharge = maxf(player.bow.overcharge(), player.spear.overcharge())
	_status.show_crosshair = player.first_person or player.aiming()
	_status.look_name = player.look.text if player.look != null and not player.ui_open else ""
	if player.weapon == "hands":
		_status.weapon = "Bare hands"
	elif player.weapon == "bow":
		_status.weapon = "Bow" if player.wears("ranged", "bow") else "Bare hands"
	elif not player.wears("melee", "spear"):
		_status.weapon = "Bare hands"
	else:
		_status.weapon = "Spear" if player.spear.thrown == null else "Spear (thrown)"


func flash_hurt() -> void:
	_status.flash_hurt()


func show_death() -> void:
	_status.set_dead(true)
	_dim_readouts(true)


func hide_death() -> void:
	_status.set_dead(false)
	_dim_readouts(false)


## The readouts step back behind the death curtain (by alpha, so which
## parts show keeps its own state); no pinning meanwhile.
func _dim_readouts(dim: bool) -> void:
	_dimmed = dim
	for c: CanvasItem in [_left, _right, _hint, _prompt, _caption]:
		c.modulate.a = 0.0 if dim else 1.0
	# The controls hint comes back only as far as it had faded (it used to
	# come back for good after a death).
	_hint.modulate.a = 0.0 if dim else clampf(_hint_timer / 3.0, 0.0, 1.0)
	_apply()


func set_prompt(text: String) -> void:
	_prompt.text = text if Settings.get_bool("hud.prompts") else ""


func toggle_debug() -> void:
	debug_visible = not debug_visible
	_debug.visible = debug_visible
	_readout_timer = 0.0


## H: the full HUD (every part) or just the pinned parts. It hides
## nothing else.
func toggle() -> void:
	full = not full
	_apply()


## The Settings key that pins a part: the dials' own switches
## ("hud.speedometer", "hud.clock", the settings panel's) and
## "hud.pin.<part>" for the rest.
static func pin_key(id: String) -> String:
	return "hud." + id if id in ["speedometer", "clock"] else "hud.pin." + id


## Pinned in a new game: the two dials (hud.json on_by_default, design
## §L's always-on readouts), nothing else.
static func pin_default(id: String) -> bool:
	# The ambient movement profile has its own list (hud.json pins_ambient,
	# design 30 Sept §AU: walking never lights the speedometer).
	if Tuning.profile() == "ambient":
		var pins = Tuning.table("hud").get("pins_ambient", null)
		if pins is Array:
			return id in pins
	if id in ["speedometer", "clock"]:
		return bool(Tuning.section("hud", id).get("on_by_default", true))
	return false


static func is_pinned(id: String) -> bool:
	return Settings.get_bool(pin_key(id), pin_default(id))


## Pin or unpin a part (saved at once), and show it so.
func set_pinned(id: String, on: bool) -> void:
	if not id in PARTS:
		push_warning("Hud: no part %s" % id)
		return
	Settings.set_bool(pin_key(id), on)
	_apply()


## Pinning with the mouse on or off (main, each frame: on while the mouse
## is free after Esc and no inventory, settings panel or map is open).
func set_pinning(on: bool) -> void:
	if on == pinning:
		return
	pinning = on
	_hover = ""
	_clicked = ""
	_apply()


## Whether a part is on screen now (at any brightness).
func is_shown(id: String) -> bool:
	if _parts.has(id):
		return (_parts[id] as Label).is_visible_in_tree()
	return readouts.is_visible_in_tree() and float(readouts.share.get(id, 0.0)) > 0.0


## Where a part is drawn now (screen px, the internal frame), or an empty
## rect when it isn't; while pinning it takes in the pin mark's cell.
func part_rect(id: String) -> Rect2:
	if not is_shown(id):
		return Rect2()
	if _parts.has(id):
		var l: Label = _parts[id]
		return l.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, l.size)
	return readouts.speedometer_rect() if id == "speedometer" else readouts.clock_rect()


## The part at a point on the screen (screen px) while pinning, or "".
func part_at(at: Vector2) -> String:
	if not pinning or _dimmed:
		return ""
	for id in PARTS:
		var r := part_rect(id)
		if r.has_area() and r.grow(HIT_PAD).has_point(at):
			return id
	return ""


## A click while pinning (PinCatcher): the part under it pinned or
## unpinned.
func _pin_click(at: Vector2) -> void:
	var id := part_at(at)
	if id == "":
		return
	_clicked = id
	set_pinned(id, not is_pinned(id))


## A part's look now: x its line's alpha, y its pin mark's (0: none). Out
## of pinning, plain. Pinning: a pinned part full, its mark on; an
## unpinned one at dim_alpha; the one under the mouse brightens (an
## unpinned one to hover_alpha) and its mark previews the click: a faint
## mark (preview_alpha) on an unpinned part, a pinned part's mark fading to
## it.
func _look(id: String) -> Vector2:
	if not pinning or _dimmed:
		return Vector2(1.0, 0.0)
	var hot := id == _hover and id != _clicked
	var preview := float(PINS.get("preview_alpha", 0.45))
	if is_pinned(id):
		return Vector2(1.0, preview if hot else 1.0)
	return Vector2(float(PINS.get("hover_alpha", 0.85)) if hot else float(PINS.get("dim_alpha", 0.45)), preview if hot else 0.0)


## Which parts show and how (pins, the full HUD, pinning); every frame.
func _apply() -> void:
	var pin := pinning and not _dimmed
	var pad := PIN_PAD if pin else ""
	for id in PARTS:
		var shown := pin or full or is_pinned(id)
		var look := _look(id)
		if _parts.has(id):
			var l: Label = _parts[id]
			l.visible = shown
			l.text = pad + str(_part_text[id])
			l.self_modulate.a = look.x
			var m: Label = _marks[id]
			m.visible = look.y > 0.0
			m.self_modulate.a = look.y
		else:
			readouts.share[id] = look.x if shown else 0.0
			readouts.mark[id] = look.y
	readouts.pinning = pin
	readouts.queue_redraw()
	_caption.visible = pin
	_place_columns(pin)
	readouts.top_right_below = _right_bottom() if visible else 0.0


## The columns MARGIN from the top, or a line lower while pinning (the
## caption above them). Anchored with no size of their own, each is just
## its minimum size.
func _place_columns(pin: bool) -> void:
	var top := float(MARGIN)
	if pin:
		top += _caption.get_combined_minimum_size().y + _line_spacing()
	for box: VBoxContainer in [_left, _right]:
		box.offset_top = top
		box.offset_bottom = top


## The bottom of the right column (0 while it shows nothing), so the
## clock in that corner sits just below it (Readouts.top_right_below).
func _right_bottom() -> float:
	for c in _right.get_children():
		if (c as Control).visible:
			return _right.get_rect().end.y
	return 0.0


func update_readout(world: Node, player_dir: Vector3, elevation_m: float, weather: Dictionary, swimming: bool, delta: float) -> void:
	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 3.0, 0.0, 1.0)
	# The text only needs to change a few times a second.
	_readout_timer -= delta
	if _readout_timer > 0.0:
		return
	_readout_timer = READOUT_INTERVAL_S
	var map: PlanetData = world.planet
	var lon := CubeSphere.longitude(player_dir)
	# Solar time: the sky's (warped) clock, so noon is when the sun peaks.
	var lat := CubeSphere.latitude(player_dir)
	var days: float = Astro.apparent_days(world.days, lon, lat)
	var hours := Astro.local_hours(days, lon)
	var hh := int(hours)
	var mm := int((hours - hh) * 60.0)
	var sun_el := rad_to_deg(Astro.elevation(Astro.sun_dir(days), player_dir))
	# The four phases: night, dawn and dusk (sun within TWILIGHT_DEG of the
	# horizon), day.
	var part := "Night"
	if sun_el > DayCycle.twilight_deg():
		part = "Morning" if hours < 11.0 else ("Afternoon" if hours > 13.0 else "Midday")
	elif sun_el > -DayCycle.twilight_deg():
		part = "Dawn" if hours < 12.0 else "Dusk"
	var mansion := Astro.mansion_index(days)
	var moon_up := rad_to_deg(Astro.elevation(Astro.moon_dir(days), player_dir)) > 0.0
	# Each part's line (_apply() puts them on screen, pinned or not).
	_part_text["time"] = "Day %d · %02d:%02d · %s" % [int(days) + 1, hh, mm, part]
	_part_text["moon"] = "%s (%d%% lit)%s" % [Astro.phase_name(days), int(round(Astro.moon_illumination(days) * 100.0)), " · moon up" if moon_up else ""]
	_part_text["mansion"] = "Mansion: %s · %s" % [Astro.MANSION_NAMES[mansion], Astro.BEAST_NAMES[Astro.beast_index(mansion)]]
	# (VT323 has no arrow: "Spring -> Summer 40%", not a taller line in a
	# fallback font.)
	_part_text["season"] = "%s · day %d of the season" % [Seasons.label(world.days, lat).replace("→", "->"), int(Seasons.at(world.days, lat).day_of_season) + 1]

	if debug_visible:
		_debug.text = debug_text(world, player_dir, weather)

	var c := map.cell_at(player_dir)
	var now_c: float = weather.get("temp_c", NAN)
	var avg_c := map.sample(map.temp_c, player_dir) + (map.sample(map.elevation, player_dir) - elevation_m) * PlanetConst.LAPSE_RATE_C_PER_M
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	_part_text["biome"] = "%s · %s soil" % [BiomeTemplates.name_of(map.biome[c]), PlanetData.soil_name(map.soil_at(player_dir)).replace("_", "/")]
	_part_text["temperature"] = "%.1f °C now · %.1f °C average" % [now_c, avg_c]
	_part_text["weather"] = "%s · %d mm rain a year" % [_weather_word(weather, map.sample(map.fog, player_dir)), int(map.sample(map.precip_mm, player_dir))]
	_part_text["wind"] = "Wind %d m/s from %s" % [int(round(wind.length())), _compass(-wind, player_dir)]
	_part_text["elevation"] = "Elevation %d m" % int(round(elevation_m))
	_part_text["position"] = "%.1f°%s, %.1f°%s" % [absf(rad_to_deg(lat)), "N" if lat >= 0.0 else "S", absf(rad_to_deg(lon)), "E" if lon >= 0.0 else "W"]
	# Not parts: shown whenever they apply, under the right column's parts.
	var context: Array[String] = []
	if swimming:
		context.append("Swimming")
	if weather.get("above_clouds", false):
		context.append("Above the clouds · thin, cold air")
	_context.text = "\n".join(context)
	_context.visible = not context.is_empty()


## The debug overlay's text: real and solar clock, the phase and how far
## into it (real minutes at the running day length), the sky's turning
## speed, sun and moon elevation, the moon's age and phase, the mansion
## and the eased cloud cover; then the calendar at this latitude: day of
## the year, the sun's declination, hours of daylight (the 24-hour clock)
## and today's minutes of day, dusk, night and dawn here.
static func debug_text(world: Node, player_dir: Vector3, weather: Dictionary) -> String:
	var lon := CubeSphere.longitude(player_dir)
	var lat := CubeSphere.latitude(player_dir)
	var clock := fposmod(Astro.time_of_day(world.days) + lon / TAU, 1.0)
	var days: float = Astro.apparent_days(world.days, lon, lat)
	var decl := Astro.declination(world.days)
	var solar_h := Astro.local_hours(days, lon)
	var day_min: float = world.day_length_s / 60.0
	var ph := DayCycle.phase_at(clock, lat, decl)
	var pm := DayCycle.phase_minutes_at(lat, decl)
	var scale := day_min / DayCycle.day_length_min()
	var sun_el := rad_to_deg(Astro.elevation(Astro.sun_dir(days), player_dir))
	var moon_el := rad_to_deg(Astro.elevation(Astro.moon_dir(days), player_dir))
	var mansion := Astro.mansion_index(days)
	return "DEBUG (F3)%s\nClock %s · solar %s · %.0f-min day\n%s %.1f / %.1f min · sky speed x%.2f\nSun %+.1f° · Moon %+.1f°\nMoon day %.1f of %.1f · %s · %d%% lit\nMansion %d %s · cloud %.2f\nLat %.1f° · year day %d of %d · sun decl %+.1f°\nDaylight %.1f h · day %.0f · dusk %.0f · night %.0f · dawn %.0f min" % [
		" · dev mode" if world.dev_mode else "",
		_hhmm(clock * 24.0), _hhmm(solar_h), day_min,
		String(ph.name).capitalize(), float(ph.into) * day_min, float(ph.length) * day_min, DayCycle.turn_rate(clock, lat, decl),
		sun_el, moon_el,
		Astro.moon_age_days(days), DayCycle.moon_cycle_days(), Astro.phase_name(days), int(round(Astro.moon_illumination(days) * 100.0)),
		mansion + 1, Astro.MANSION_NAMES[mansion], float(weather.get("cloud", 0.0)),
		rad_to_deg(lat), int(Astro.year_day(world.days)) + 1, int(DayCycle.year_days()), rad_to_deg(decl),
		DayCycle.daylight_hours(lat, decl), float(pm.day) * scale, float(pm.dusk) * scale, float(pm.night) * scale, float(pm.dawn) * scale,
	] + "\nSoil %s (plants gate on it)" % PlanetData.soil_name(world.planet.soil_at(player_dir)).replace("_", "/") + "\nSeason %s · day %d · %+.1f °C · wet x%.2f" % [
		Seasons.label(world.days, lat), int(Seasons.at(world.days, lat).day_of_season) + 1,
		Seasons.temp_offset_c(world.days, lat), Seasons.moisture_mult(world.days, lat),
	]


static func _hhmm(hours: float) -> String:
	var h := fposmod(hours, 24.0)
	return "%02d:%02d" % [int(h), int((h - int(h)) * 60.0)]


static func _weather_word(w: Dictionary, fog: float) -> String:
	var rain: float = w.get("rain_mm_h", 0.0)
	var snow: bool = w.get("snow", false)
	if w.get("storm", 0.0) > 0.5:
		return "Snowstorm" if snow else "Storm"
	if rain > 0.3:
		return ("Snow" if snow else "Rain") if rain > 1.0 else ("Light snow" if snow else "Light rain")
	var cloud: float = w.get("cloud", 0.0)
	var words := "Overcast" if cloud > 0.65 else ("Cloudy" if cloud > 0.3 else "Clear")
	if fog > 0.5:
		words += ", misty"
	return words


static func _compass(v: Vector3, up: Vector3) -> String:
	if v.length() < 0.3:
		return "calm"
	var a := atan2(v.dot(CubeSphere.east(up)), v.dot(CubeSphere.north(up)))
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[posmod(int(round(a / (TAU / 8.0))), 8)]


## Pinning's click target. Input goes _input, then GUI controls, then
## _unhandled_input, and PlanetPlayer takes the mouse back in
## _unhandled_input on any click while it's free. This control covers the
## screen but holds only the parts' rects (_has_point: Hud.part_at(),
## nothing while not pinning), so the GUI hands it a click on a part and,
## its filter being MOUSE_FILTER_STOP, marks that click handled: it never
## reaches _unhandled_input and the mouse stays free for the next pin. A
## click anywhere else finds no control, goes on to _unhandled_input and
## takes the mouse back as before (and main ends pinning).
class PinCatcher extends Control:
	var hud: Hud

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _has_point(point: Vector2) -> bool:
		return hud != null and hud.part_at(get_global_transform_with_canvas() * point) != ""

	func _gui_input(event: InputEvent) -> void:
		var b := event as InputEventMouseButton
		if b != null and b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
			hud._pin_click(get_global_transform_with_canvas() * b.position)
		accept_event()
