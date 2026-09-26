class_name StatusHud
extends Control
## Health and aim, drawn over the view (Hud owns it): ten hearts at the
## bottom left (half hearts too, Minecraft-style) that shiver when you're
## low, a crosshair while aiming or in first person with the bow's draw as
## a filling arc beneath it, a red flash at the screen's edge when you're
## hurt, and the dark "You died" curtain.

var hp := 100.0
var max_hp := 100.0
var aiming := false
var show_crosshair := false
var draw_power := 0.0 # 0-1 bow power
var _hurt := 0.0
var _death := 0.0
var _dead := false
var _time := 0.0
var _death_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_label = Label.new()
	_death_label.text = "You died"
	_death_label.add_theme_font_size_override("font_size", 46)
	_death_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
	_death_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	_death_label.add_theme_constant_override("outline_size", 8)
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_label.visible = false
	add_child(_death_label)


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
	queue_redraw()


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
	# Hearts, bottom left above the key hints.
	var n := 10
	var per := max_hp / n
	var low := hp < max_hp * 0.25
	for i in n:
		var p := Vector2(24 + i * 22, size.y - 96)
		if low and not _dead:
			p.y += sin(_time * 18.0 + i * 1.7) * 1.5
		var fill := clampf((hp - i * per) / per, 0.0, 1.0)
		_heart(p, 9.0, Color(0.12, 0.05, 0.06, 0.8), 1.0)
		if fill > 0.0:
			_heart(p, 7.0, Color(0.9, 0.12, 0.14), 1.0 if fill >= 0.75 else 0.5)
	# Crosshair and draw.
	if show_crosshair and not _dead:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.85)
		draw_line(c + Vector2(-8, 0), c + Vector2(-3, 0), col, 2.0)
		draw_line(c + Vector2(3, 0), c + Vector2(8, 0), col, 2.0)
		draw_line(c + Vector2(0, -8), c + Vector2(0, -3), col, 2.0)
		draw_line(c + Vector2(0, 3), c + Vector2(0, 8), col, 2.0)
		if aiming:
			draw_arc(c, 16.0, PI * 0.25, PI * 0.75, 16, Color(1, 1, 1, 0.3), 3.0)
			var full := draw_power >= 1.0
			draw_arc(c, 16.0, PI * 0.75 - PI * 0.5 * draw_power, PI * 0.75, 16, Color(1.0, 0.85, 0.3) if full else Color(1, 1, 1, 0.9), 3.0)


## A heart at `p`, radius `r`; `part` 0.5 draws only its left half.
func _heart(p: Vector2, r: float, col: Color, part: float) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	for k in steps + 1:
		var t := PI * 2.0 * k / steps
		# The classic heart curve, scaled to r.
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		var q := Vector2(x, y) * (r / 16.0)
		if part < 1.0 and q.x > 0.0:
			q.x = 0.0
		pts.append(p + q)
	draw_colored_polygon(pts, col)
