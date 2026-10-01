class_name Display
## The fixed internal resolution (design §Y; data/look.json "render"):
## the whole frame (the 3D, the post-grade and dither, the HUD) is drawn
## at internal_lines (480 by default, 720 at most; 1080 is never
## rendered), 16:9 (854x480) or 4:3 (640x480, letterboxed), and upscaled
## to the window with nearest-neighbour: square, honest pixels, so a
## bigger window only means bigger pixels. It's the root window's
## "viewport" content scale (project.godot [display]); every HUD px is at
## the internal reference.
##
## Integer scaling (on by default): whole multiples when the window holds
## at least two (2x at 960 lines, 3x at 1440), a thin letterbox round
## them; a window smaller than that gets the fractional ratio, still
## nearest.
##
## The player's settings (SettingsPanel) override the file:
## "display.preset" (a name from render.presets: chunky 360 / default 480
## / half_hd 540 / fine 720, design §BU; an older "display.lines" still
## counts while no preset is chosen), "display.aspect" ("16:9" / "4:3"),
## "display.integer" (on / off). apply() re-reads them. A dev key (F11,
## dev_pixel) cycles the presets live.

const LINE_CHOICES := [480, 720]
const ASPECTS := ["16:9", "4:3"]

static var _window: Window


## Set the root window up, and keep it right as it's resized.
static func install(window: Window) -> void:
	_window = window
	if not window.size_changed.is_connected(_fit):
		window.size_changed.connect(_fit)
	apply()


static func render() -> Dictionary:
	return Tuning.section("look", "render")


## The pixel-size presets (render.presets), in the file's order.
static func presets() -> Dictionary:
	return render().get("presets", {"default": 480})


## The active preset's name: the setting, else the file's render.preset.
static func preset() -> String:
	var p := str(Settings.get_value("display.preset", str(render().get("preset", "default"))))
	return p if presets().has(p) else "default"


## Internal lines now: the preset's (an older "display.lines" setting
## wins while no preset is chosen), clamped to the file's max.
static func lines() -> int:
	var r := render()
	var v := int(presets().get(preset(), int(r.get("internal_lines", 480))))
	if str(Settings.get_value("display.preset", "")) == "" and int(Settings.get_value("display.lines", 0)) != 0:
		v = int(Settings.get_value("display.lines", v))
	return clampi(v, 240, int(r.get("max_internal_lines", 720)))


## The next preset in the file's order (the settings panel, the dev key).
static func cycle_preset(left := false) -> String:
	var names := presets().keys()
	var i := names.find(preset())
	var n: String = names[(i + (names.size() - 1 if left else 1)) % names.size()]
	Settings.set_value("display.preset", n)
	Settings.set_value("display.lines", 0)
	apply()
	return n


## "chunky (640x360)" for the panel and the dev key's note.
static func preset_label() -> String:
	var s := internal_size()
	return "%s (%dx%d)" % [preset(), s.x, s.y]


static func aspect() -> String:
	var a := str(Settings.get_value("display.aspect", str(render().get("aspect", "16:9"))))
	return a if a in ASPECTS else "16:9"


static func integer() -> bool:
	return Settings.get_bool("display.integer", bool(render().get("integer_scale", true)))


## The internal frame size: 854x480 at 16:9, 640x480 at 4:3.
static func internal_size() -> Vector2i:
	var h := lines()
	var w := h * 4 / 3 if aspect() == "4:3" else int(round(h * 16.0 / 9.0))
	return Vector2i(w + (w & 1), h)


static func apply() -> void:
	if _window == null:
		return
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_window.content_scale_size = internal_size()
	_fit()


## Integer multiples when the window holds two or more; else fractional.
static func _fit() -> void:
	if _window == null:
		return
	var s := internal_size()
	var k := mini(_window.size.x / s.x, _window.size.y / s.y)
	_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if integer() and k >= 2 else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## How many window pixels one internal pixel is now (tests, readouts).
static func scale() -> float:
	if _window == null:
		return 1.0
	var s := internal_size()
	var f := minf(float(_window.size.x) / s.x, float(_window.size.y) / s.y)
	return floorf(f) if _window.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER else f
