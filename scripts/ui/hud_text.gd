class_name HudText
## Every HUD and UI font (design §U; data/hud.json "text"): an early-
## computer terminal face, set as the engine's fallback font so every
## Label and every drawn string uses it. The file is text.font
## (assets/fonts/vt323.ttf, "VT323", SIL OFL 1.1; the old typewriter face
## "Special Elite" is still there); if it's missing, the system's
## monospace. Every size is at the internal frame's reference (design §Y:
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


static func install() -> void:
	var t := Tuning.section("hud", "text")
	var path := "res://" + str(t.get("font", "assets/fonts/typewriter.ttf"))
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path) as Font
	if font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Courier New", "Courier", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
		font = sys
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
