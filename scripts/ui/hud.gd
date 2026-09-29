class_name Hud
extends CanvasLayer
## On-screen readout (DESIGN.md: biome names are labels for the map and
## hover readout only). Temperatures in °C.

const READOUT_INTERVAL_S := 0.25
var _readout_timer := 0.0
var _left: Label
var _right: Label
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
	_left = _label(HORIZONTAL_ALIGNMENT_LEFT)
	_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 9)
	_right = _label(HORIZONTAL_ALIGNMENT_RIGHT)
	_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 9)
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint = _label(HORIZONTAL_ALIGNMENT_LEFT)
	# (Up above the subtitle, the prompt and the weapon line: at the start
	# it sat on the Elder's first words and the bow.)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 9)
	_hint.offset_bottom -= 104
	_hint.offset_top -= 104
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.text = "WASD move · W W sprint · Shift crouch (air: drop) · Space jump (tap hop, hold bound)\nright click at a wall: wall jump (hold: cling) · as you land: bounce\nleft click: draw / release · Q bow, spear · E interact · V view · Tab pack\nM map · H hide HUD · O settings · F3 debug · Esc frees mouse"
	_prompt = _label(HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 47)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.add_theme_font_size_override("font_size", HudText.px(15))
	_subtitle = _label(HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 80)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.add_theme_font_size_override("font_size", HudText.px(15))
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
	_build_loading()


func _label(align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", HudText.px(Tuning.num("hud", "text", "base_px")))
	l.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.15))
	l.add_theme_constant_override("outline_size", 3)
	add_child(l)
	return l


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
	title.add_theme_font_size_override("font_size", HudText.px(17))
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


## Context prompt near the bottom of the screen ("E: turn over the log").
## The health meter, crosshair, the bow's draw (or the spear's raise) and
## the weapon in hand from the player, every frame (the hits' numbers and
## X StatusHud reads for itself, Hits).
func update_status(player: PlanetPlayer) -> void:
	_status.hp = player.hp
	_status.max_hp = PlanetPlayer.MAX_HP
	_status.aiming = player.aiming()
	_status.draw_power = player.aim_power()
	readouts.top_right_below = _right.get_rect().end.y if _right.visible and visible else 0.0
	_status.meter = player.meter.value
	_status.overcharge = maxf(player.bow.overcharge(), player.spear.overcharge())
	_status.show_crosshair = player.first_person or player.aiming()
	_status.look_name = player.look.text if player.look != null and not player.ui_open else ""
	if player.weapon == "bow":
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


## The readouts step back behind the death curtain (by alpha, so the
## show/hide toggle keeps its own state).
func _dim_readouts(dim: bool) -> void:
	for l: Label in [_left, _right, _hint, _prompt]:
		l.modulate.a = 0.0 if dim else 1.0


func set_prompt(text: String) -> void:
	_prompt.text = text if Settings.get_bool("hud.prompts") else ""


func toggle_debug() -> void:
	debug_visible = not debug_visible
	_debug.visible = debug_visible
	_readout_timer = 0.0


func toggle() -> void:
	_left.visible = not _left.visible
	_right.visible = _left.visible
	_hint.visible = _left.visible


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
	_left.text = "Day %d · %02d:%02d · %s\n%s (%d%% lit)%s\nMansion: %s · %s" % [
		int(days) + 1, hh, mm, part,
		Astro.phase_name(days), int(round(Astro.moon_illumination(days) * 100.0)),
		" · moon up" if moon_up else "",
		Astro.MANSION_NAMES[mansion], Astro.BEAST_NAMES[Astro.beast_index(mansion)],
	]

	if debug_visible:
		_debug.text = debug_text(world, player_dir, weather)

	var c := map.cell_at(player_dir)
	var now_c: float = weather.get("temp_c", NAN)
	var avg_c := map.sample(map.temp_c, player_dir) + (map.sample(map.elevation, player_dir) - elevation_m) * PlanetConst.LAPSE_RATE_C_PER_M
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	_right.text = "%s · %s soil\n%.1f °C now · %.1f °C average\n%s · %d mm rain a year\nWind %d m/s from %s\nElevation %d m · %.1f°%s %.1f°%s%s" % [
		BiomeTemplates.name_of(map.biome[c]), PlanetData.soil_name(map.soil_at(player_dir)).replace("_", "/"),
		now_c, avg_c,
		_weather_word(weather, map.sample(map.fog, player_dir)), int(map.sample(map.precip_mm, player_dir)),
		int(round(wind.length())), _compass(-wind, player_dir),
		int(round(elevation_m)), absf(rad_to_deg(lat)), "N" if lat >= 0.0 else "S", absf(rad_to_deg(lon)), "E" if lon >= 0.0 else "W",
		("\nSwimming" if swimming else "") + ("\nAbove the clouds · thin, cold air" if weather.get("above_clouds", false) else ""),
	]


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
