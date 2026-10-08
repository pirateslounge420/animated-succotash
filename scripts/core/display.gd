class_name Display
## The fixed internal resolution (design §Y; data/look.json "render"):
## the whole frame (the 3D, the post-grade and dither, the HUD) is drawn
## at the preset's lines (480, "default", the committed default again
## since Mike's 6 Oct dungeon lock; 270 "painted" was §ES's; 720 at most;
## 1080 is never rendered, Mike, 7 Oct evening, undoing §FL.2's 480), 16:9
## (854x480) or 4:3, and upscaled
## to the window with nearest-neighbour: square, honest pixels, so a
## bigger window only means bigger pixels. It's the root window's
## "viewport" content scale (project.godot [display]); every HUD px is at
## the internal reference.
##
## Integer scaling (on by default): whole multiples when the window holds
## at least two (4x at 1080 for 270 lines, 3x at 1440 for 480), a thin
## letterbox round
## them; a window smaller than that gets the fractional ratio, still
## nearest.
##
## The player's settings (SettingsPanel) override the file:
## "display.preset" (a name from render.presets: painted 270 / chunky
## 360 / default 480, the default / half_hd 540 / fine 720, the most,
## design §BU; or "auto"; a name not in the file is the file's own
## preset; an older "display.lines" still counts while no preset is
## chosen, held to 720), "display.aspect" ("16:9" / "4:3"),
## "display.integer" (on / off). apply() re-reads them. A dev key (F11,
## dev_pixel) cycles the presets live.

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


## The active preset's name: the setting, else the file's render.preset
## ("default", 480 lines); "auto" is a choice too.
static func preset() -> String:
	var p := str(Settings.get_value("display.preset", str(render().get("preset", "default"))))
	if p == AUTO or presets().has(p):
		return p
	var file := str(render().get("preset", "default"))
	return file if presets().has(file) else "default"


## "auto" (look.json render.auto): the first preset in render.auto.prefer
## whose lines divide the window's height exactly (a whole-number upscale,
## so nothing crawls), at or under max_internal_lines; none does: the
## file's own preset (default, 480), letterboxed. 1440 windows get
## default (x3); 1080 and 2160, half_hd (x2, x4).
const AUTO := "auto"

static func auto_preset() -> String:
	if _window == null:
		return str(render().get("preset", "default"))
	return auto_for(_window.size.y)


## auto's pick for a window `h` pixels tall.
static func auto_for(h: int) -> String:
	var r := render()
	for name in (r.get("auto", {}) as Dictionary).get("prefer", presets().keys()):
		var lines_n := int(presets().get(str(name), 0))
		if lines_n > 0 and lines_n <= max_lines() and h % lines_n == 0:
			return str(name)
	return str(r.get("preset", "default"))


## The most lines any setting may give (render.max_internal_lines, 720;
## never 1080).
static func max_lines() -> int:
	return int(render().get("max_internal_lines", 720))


## Internal lines now: the preset's (an older "display.lines" setting
## wins while no preset is chosen), clamped to the file's max.
static func lines() -> int:
	var r := render()
	var name := auto_preset() if preset() == AUTO else preset()
	var v := int(presets().get(name, int(r.get("internal_lines", 480))))
	if str(Settings.get_value("display.preset", "")) == "" and int(Settings.get_value("display.lines", 0)) != 0:
		v = int(Settings.get_value("display.lines", v))
	return clampi(v, 240, max_lines())


## The next preset in the file's order (the settings panel, the dev key).
static func cycle_preset(left := false) -> String:
	var names := presets().keys()
	names.append(AUTO)
	var i := names.find(preset())
	var n: String = names[(i + (names.size() - 1 if left else 1)) % names.size()]
	Settings.set_value("display.preset", n)
	Settings.set_value("display.lines", 0)
	apply()
	return n


## "chunky (640x360)" for the panel and the dev key's note.
static func preset_label() -> String:
	var s := internal_size()
	if preset() == AUTO:
		return "auto: %s (%dx%d)" % [auto_preset(), s.x, s.y]
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
	# The HUD's text sizes follow the frame's lines (HudText.scale()).
	HudText.refresh()


## Integer multiples when the window holds two or more; else fractional.
static func _fit() -> void:
	if _window == null:
		return
	var s := internal_size()
	# "auto" re-picks for the new window size.
	if preset() == AUTO and _window.content_scale_size != s:
		_window.content_scale_size = s
		HudText.refresh()
	var k := mini(_window.size.x / s.x, _window.size.y / s.y)
	_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if integer() and k >= 2 else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## How many window pixels one internal pixel is now (tests, readouts).
static func scale() -> float:
	if _window == null:
		return 1.0
	var s := internal_size()
	var f := minf(float(_window.size.x) / s.x, float(_window.size.y) / s.y)
	return floorf(f) if _window.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER else f
