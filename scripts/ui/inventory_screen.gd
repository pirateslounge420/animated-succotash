class_name InventoryScreen
extends Control
## The inventory (I; the designer's first play, item 11): a small plain
## panel in the R1a palette, the way PSO's item screen is plain. What you
## wear on the left (ranged, melee, amulet, rings: worn, then the spares in
## a dimmer line), what you carry on the right (one row per carry slot),
## and under them a picture of the chosen thing with its name, a plant
## sample's binomial in italics. Nothing else: no numbers, no weights, no
## crafting. The world goes on while it's open (it doesn't pause).
##
## Click a row to choose it (the mouse is free while the screen is open).
## E on a worn spare wears it; G sets a carried thing down on the ground
## (WorldItem: E picks it up again). I or Esc closes.

const INK := Color(0.05, 0.07, 0.15)
const PANEL := Color(0.035, 0.055, 0.19, 0.84)
const EDGE := Color("#C8D8F0")
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.82)
const PICK := Color(0.16, 0.26, 0.62, 0.9)
const ROW_H := 22.0
const W := 580.0
const PAD := 16.0
## The layout above is at the old 720-line reference; it's drawn scaled
## into the 480-line internal frame (design §Y, Display).
const K := 480.0 / 720.0

var inventory: Inventory
## [kind, key, index]: "carried", i or "worn", slot, i. Empty: nothing.
var chosen: Array = []
var _rows: Array = [] # [Rect2, ["carried", i] or ["worn", slot, i]]
var _italic: FontVariation


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_italic = FontVariation.new()
	_italic.base_font = ThemeDB.fallback_font
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)


func open() -> void:
	visible = true
	if chosen.is_empty():
		chosen = ["carried", 0]
	queue_redraw()


func close() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## The item chosen now, or null.
func chosen_item():
	if chosen.is_empty() or inventory == null:
		return null
	if chosen[0] == "carried":
		return inventory.carried[chosen[1]]
	return (inventory.worn[chosen[1]] as Array)[chosen[2]]


## A click on a row chooses it (called by main with the screen position).
func click(at: Vector2) -> bool:
	at /= K
	for r in _rows:
		if (r[0] as Rect2).has_point(at):
			chosen = r[1]
			return true
	return false


func _panel_rect() -> Rect2:
	var n := maxi(Inventory.carry_slots(), 12)
	var h := PAD * 2.0 + 24.0 + ROW_H * n + 96.0
	var sz := size / K
	return Rect2(Vector2(sz.x * 0.5 - W * 0.5, sz.y * 0.5 - h * 0.5), Vector2(W, h))


func _draw() -> void:
	if inventory == null:
		return
	_rows.clear()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(K, K))
	var font := ThemeDB.fallback_font
	var r := _panel_rect()
	draw_rect(r, PANEL)
	draw_rect(r, Color(EDGE, 0.55), false, 1.0)
	var col_w := (W - PAD * 3.0) * 0.5
	var left := r.position + Vector2(PAD, PAD)
	var right := left + Vector2(col_w + PAD, 0)
	_text(font, left + Vector2(0, 14), "Worn", 13, DIM)
	_text(font, right + Vector2(0, 14), "Carried", 13, DIM)
	# Worn: each slot's worn place(s), then its spares, dimmer.
	var y := left.y + 24.0
	for slot in Inventory.data().get("equipment", {}):
		var info := Inventory.slot_info(slot)
		var a: Array = inventory.worn[slot]
		var n_worn := int(info.worn)
		for i in a.size():
			var spare := i >= n_worn
			var row := Rect2(Vector2(left.x, y), Vector2(col_w, ROW_H - 2.0))
			var label := str(info.label) if i == 0 else ("  spare" if spare else " ")
			_row(font, row, ["worn", slot, i], label, a[i], spare)
			y += ROW_H if not spare else ROW_H - 4.0
		y += 4.0
	# Carried: one row per slot.
	y = right.y + 24.0
	for i in inventory.carried.size():
		var row := Rect2(Vector2(right.x, y), Vector2(col_w, ROW_H - 2.0))
		_row(font, row, ["carried", i], "", inventory.carried[i], false)
		y += ROW_H
	# The chosen thing, looked at.
	var foot := Rect2(Vector2(r.position.x + PAD, r.end.y - PAD - 80.0), Vector2(W - PAD * 2.0, 80.0))
	draw_line(foot.position - Vector2(0, 8), Vector2(foot.end.x, foot.position.y - 8), Color(EDGE, 0.3), 1.0)
	var it = chosen_item()
	if it != null:
		ItemIcon.draw_icon(self, foot.position + Vector2(36, 40), 34.0, it)
		var tx := foot.position + Vector2(84, 30)
		_text(font, tx, Inventory.title(it), 17, TEXT)
		var bin := str(it.get("binomial", ""))
		if bin != "":
			draw_string_outline(_italic, tx + Vector2(0, 24), bin, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, INK)
			draw_string(_italic, tx + Vector2(0, 24), bin, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
		var hint := ""
		if chosen[0] == "carried":
			hint = "G: set it down"
		elif chosen[2] >= int(Inventory.slot_info(chosen[1]).worn):
			hint = "E: wear it"
		if hint != "":
			_text(font, Vector2(foot.end.x - 8.0 - font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, foot.end.y - 4.0), hint, 12, DIM)


func _row(font: Font, row: Rect2, key: Array, label: String, it, spare: bool) -> void:
	_rows.append([row, key])
	if key == chosen:
		draw_rect(row, PICK)
	var size_px := 12 if spare else 14
	var x := row.position.x + 6.0
	if label != "":
		_text(font, Vector2(x, row.position.y + 15.0), label, 12, DIM)
		x += 64.0
	if it == null:
		_text(font, Vector2(x, row.position.y + 15.0), "—", size_px, Color(DIM, 0.45))
		return
	ItemIcon.draw_icon(self, Vector2(x + 7.0, row.position.y + row.size.y * 0.5), 8.0, it)
	var title := Inventory.title(it)
	_text(font, Vector2(x + 20.0, row.position.y + 15.0), title, size_px, DIM if spare else TEXT)
	# A sample's species beside it, small, so two cuttings tell apart.
	var bin := str(it.get("binomial", ""))
	if bin != "":
		var bx := x + 28.0 + font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var room := row.end.x - bx - 4.0
		if room > 30.0:
			draw_string(_italic, Vector2(bx, row.position.y + 15.0), bin, HORIZONTAL_ALIGNMENT_LEFT, room, 12, DIM)


func _text(font: Font, at: Vector2, s: String, px: int, col: Color) -> void:
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, INK)
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
