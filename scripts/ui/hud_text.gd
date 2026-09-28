class_name HudText
## Every HUD and UI font (design §U; data/hud.json "text"): an early-
## computer / typewriter face, set as the engine's fallback font so every
## Label and every drawn string uses it. The file is text.font
## (assets/fonts/typewriter.ttf, "Special Elite", Apache-2.0); if it's
## missing, the system's monospace. Every size is at the internal frame's
## reference (design §Y: 480 lines, Display): the HUD is drawn inside the
## low-res frame and upscaled with it, nearest-neighbour, so text is
## pixel-chunky and the right size at any window. text.base_px is the
## default size for every Label.


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
	ThemeDB.fallback_font = font
	# Labels and other controls read the default theme's font.
	ThemeDB.get_default_theme().default_font = font
	ThemeDB.get_default_theme().default_font_size = int(t.get("base_px", 9))
	ThemeDB.fallback_font_size = int(t.get("base_px", 9))
