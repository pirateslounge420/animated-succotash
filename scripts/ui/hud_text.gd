class_name HudText
## Every HUD and UI font (design §U; data/hud.json "text"): an early-
## computer / typewriter face, set as the engine's fallback font so every
## Label and every drawn string uses it. The file is text.font
## (assets/fonts/typewriter.ttf, "Special Elite", Apache-2.0); if it's
## missing, the system's monospace. Sizes are at the 720-line reference:
## the project stretches the whole 2D layer with the window height
## (display/window/stretch canvas_items, 1280x720 base, aspect expand), so
## at 1080p everything is 1.5x and at 4K 3x.


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
