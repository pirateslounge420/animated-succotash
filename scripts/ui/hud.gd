class_name Hud
extends CanvasLayer
## On-screen readout (DESIGN.md: biome names are labels for the map and
## hover readout only). Temperatures in °C.

var _left: Label
var _right: Label
var _hint: Label
var _prompt: Label
var _loading: Control
var _loading_label: Label
var _loading_bar: ProgressBar
var _hint_timer := 18.0


func _ready() -> void:
	layer = 10
	_left = _label(HORIZONTAL_ALIGNMENT_LEFT)
	_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_right = _label(HORIZONTAL_ALIGNMENT_RIGHT)
	_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint = _label(HORIZONTAL_ALIGNMENT_LEFT)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.text = "WASD move · Shift run · Space jump · E inspect\nM map · H hide HUD · [ ] time speed · click to look, Esc frees mouse"
	_prompt = _label(HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.add_theme_font_size_override("font_size", 18)
	_build_loading()


func _label(align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.15))
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


func _build_loading() -> void:
	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.03, 0.04, 0.12)
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_loading)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -40)
	_loading.add_child(box)
	var title := Label.new()
	title.text = "Generating planet"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_loading_label = Label.new()
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_label)
	_loading_bar = ProgressBar.new()
	_loading_bar.max_value = 1.0
	_loading_bar.custom_minimum_size = Vector2(420, 18)
	box.add_child(_loading_bar)


func show_loading(step: String, fraction: float) -> void:
	_loading.visible = true
	_loading_label.text = step
	_loading_bar.value = fraction


func hide_loading() -> void:
	_loading.visible = false


## Context prompt near the bottom of the screen ("E: turn over the log").
func set_prompt(text: String) -> void:
	_prompt.text = text


func toggle() -> void:
	_left.visible = not _left.visible
	_right.visible = _left.visible
	_hint.visible = _left.visible


func update_readout(world: Node, player_dir: Vector3, elevation_m: float, weather: Dictionary, time_scale: float, swimming: bool, delta: float) -> void:
	var map: PlanetData = world.planet
	var lon := CubeSphere.longitude(player_dir)
	# Solar time: the sky's (warped) clock, so noon is when the sun peaks.
	var days: float = Astro.apparent_days(world.days, lon)
	var lat := CubeSphere.latitude(player_dir)
	var hours := Astro.local_hours(days, lon)
	var hh := int(hours)
	var mm := int((hours - hh) * 60.0)
	var sun_el := rad_to_deg(Astro.elevation(Astro.sun_dir(days), player_dir))
	# The four phases: night, dawn and dusk (sun within TWILIGHT_DEG of the
	# horizon), day.
	var part := "Night"
	if sun_el > PlanetConst.TWILIGHT_DEG:
		part = "Morning" if hours < 11.0 else ("Afternoon" if hours > 13.0 else "Midday")
	elif sun_el > -PlanetConst.TWILIGHT_DEG:
		part = "Dawn" if hours < 12.0 else "Dusk"
	var mansion := Astro.mansion_index(days)
	var moon_up := rad_to_deg(Astro.elevation(Astro.moon_dir(days), player_dir)) > 0.0
	var speed := "" if is_equal_approx(time_scale, 1.0) else "   (time x%s)" % str(time_scale)
	_left.text = "Day %d · %02d:%02d · %s%s\n%s (%d%% lit)%s\nMansion: %s · %s" % [
		int(days) + 1, hh, mm, part, speed,
		Astro.phase_name(days), int(round(Astro.moon_illumination(days) * 100.0)),
		" · moon up" if moon_up else "",
		Astro.MANSION_NAMES[mansion], Astro.BEAST_NAMES[Astro.beast_index(mansion)],
	]

	var c := map.cell_at(player_dir)
	var now_c: float = weather.get("temp_c", NAN)
	var avg_c := map.sample(map.temp_c, player_dir) + (map.sample(map.elevation, player_dir) - elevation_m) * PlanetConst.LAPSE_RATE_C_PER_M
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	_right.text = "%s\n%.1f °C now · %.1f °C average\n%s · %d mm rain a year\nWind %d m/s from %s\nElevation %d m · %.1f°%s %.1f°%s%s" % [
		BiomeTemplates.name_of(map.biome[c]),
		now_c, avg_c,
		_weather_word(weather, map.sample(map.fog, player_dir)), int(map.sample(map.precip_mm, player_dir)),
		int(round(wind.length())), _compass(-wind, player_dir),
		int(round(elevation_m)), absf(rad_to_deg(lat)), "N" if lat >= 0.0 else "S", absf(rad_to_deg(lon)), "E" if lon >= 0.0 else "W",
		"\nSwimming" if swimming else "",
	]
	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 3.0, 0.0, 1.0)


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
