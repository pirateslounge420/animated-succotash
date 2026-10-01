class_name HudText
## Every HUD and UI font (design §U; data/hud.json "text"): an early-
## computer terminal face, set as the engine's fallback font so every
## Label and every drawn string uses it. The file is text.font
## (assets/fonts/vt323.ttf, "VT323", SIL OFL 1.1; the old typewriter face
## "Special Elite" is still there); if its import is missing the TTF is
## read from disk, and if that fails the other face, never a system font. Every size is at the internal frame's reference (design §Y:
## 480 lines, Display): the HUD is drawn inside the low-res frame and
## upscaled with it, nearest-neighbour. So the font is drawn without
## antialiasing or hinting, on its own pixel grid: VT323's is 10 px, so
## it's pixel-exact at 20 px (and 40), and every size goes through px()
## (2026-09-29, from play: the typewriter face, antialiased at 9-11 px and
## then upscaled, was hard to read). text.base_px is the default size for
## every Label.

## The crisp sizes, smallest first (text.crisp_px).
static var CRISP: Array = Tuning.section("hud", "text").get("crisp_px", [20, 40])


## The crisp size for a wanted size: the largest crisp size not more than
## `want` (never below the smallest), so nothing is drawn between grids.
static func px(want: float) -> int:
	var out := int(CRISP[0])
	for c in CRISP:
		if want >= float(c) * 0.8:
			out = int(c)
	return out


## How the face was loaded, for the checks and the log: "import" (the
## project's imported resource), "disk" (the TTF read straight from the
## file, when the import is missing — what Mike's Mac needed, 1 Oct) or
## "fallback:<file>" (the other face in assets/fonts). Never a system font:
## a system monospace is wider and ran the HUD off the frame.
static var loaded_from := ""

## The other face in assets/fonts, when text.font cannot be read at all.
const FALLBACK_FONT := "assets/fonts/typewriter.ttf"


static func install() -> void:
	var t := Tuning.section("hud", "text")
	var want := str(t.get("font", "assets/fonts/vt323.ttf"))
	var font: Font = null
	var why: Array = []
	for rel in [want, FALLBACK_FONT]:
		var path: String = "res://" + rel
		if _imported(path):
			font = load(path) as Font
			if font != null:
				loaded_from = "import" if rel == want else "fallback:" + rel
				break
			why.append("%s: the import would not load" % rel)
		else:
			why.append("%s: no import" % rel)
		# The import is missing (a fresh checkout whose .godot never
		# imported it): read the TTF itself.
		if FileAccess.file_exists(path):
			var ff := FontFile.new()
			var err := ff.load_dynamic_font(path)
			if err == OK:
				font = ff
				loaded_from = "disk" if rel == want else "fallback:" + rel
				break
			why.append("%s: load_dynamic_font error %d" % [rel, err])
		else:
			why.append("%s: no file" % rel)
		if rel == want:
			push_error("HudText: the HUD font %s could not be loaded (%s); using %s" % [rel, "; ".join(why), FALLBACK_FONT])
	if font == null:
		# Nothing on disk at all: the engine's own default font, never a
		# system face (logged above).
		push_error("HudText: no HUD font could be loaded (%s)" % "; ".join(why))
		loaded_from = "engine default"
		return
	if font is FontFile:
		var ff := font as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.generate_mipmaps = false
	ThemeDB.fallback_font = font
	# Labels and other controls read the default theme's font.
	ThemeDB.get_default_theme().default_font = font
	ThemeDB.get_default_theme().default_font_size = px(float(t.get("base_px", 20)))
	ThemeDB.fallback_font_size = px(float(t.get("base_px", 20)))


## Is the import of `path` there to load (its .import file and the
## imported data it points at)? Asked first so a missing import falls to
## the disk read without the engine's load errors.
static func _imported(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path + ".import") != OK:
		return true
	var dest := str(cfg.get_value("remap", "path", ""))
	return dest == "" or FileAccess.file_exists(dest)
