class_name HandStrip
extends Control
## The hands' strip (design 6 Oct §FB, hands.json tab_hold): while Tab is
## held, a small row of what Tab and the wheel step through, the one in
## hand marked: the left hand's things (Inventory.strip) and an empty
## hand, low on the left. With the plain wheel given to the left hand
## (the Controls page) Tab and the wheel drive the right, and the strip
## shows the right hand's choices low on the right. Icons only, no words
## (ItemIcon), drawn inside the 480-line frame (§Y: sizes at the 480
## reference, HudText.scale()). A tap of Tab shows nothing
## (tab_hold.show_after_s; Hands.strip_showing()).

const PANEL := Color(0.035, 0.055, 0.19, 0.72)
const EDGE := Color("#C8D8F0")
const DIM := Color(0.62, 0.68, 0.82)
## The one in hand's cell (the inventory screen's chosen row).
const PICK := Color(0.16, 0.26, 0.62, 0.9)
## A cell, the gap between cells, the panel's pad round them and its
## margin from the frame's edge (px at 480 lines).
const CELL := 26.0
const GAP := 3.0
const PAD := 4.0
const MARGIN := 18.0

var hands: Hands


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	var on := hands != null and is_instance_valid(hands) and hands.strip_showing()
	if on != visible:
		visible = on
	if on:
		queue_redraw()


## The strip as laid out now: {"hand", "panel": Rect2, "cells": [[Rect2,
## entry, chosen], ...]} (the checks read it too).
func layout() -> Dictionary:
	var hand := Hands.tab_hand()
	var got: Array = hands.strip_for(hand)
	var entries: Array = got[0]
	var k := HudText.scale()
	var cell := roundf(CELL * k)
	var gap := roundf(GAP * k)
	var pad := roundf(PAD * k)
	var n := entries.size()
	var w := n * cell + (n - 1) * gap + pad * 2.0
	var h := cell + pad * 2.0
	var m := roundf(MARGIN * k)
	var x := m if hand == "left" else size.x - m - w
	var panel := Rect2(Vector2(x, size.y - m - h), Vector2(w, h))
	var cells: Array = []
	for i in n:
		var r := Rect2(panel.position + Vector2(pad + i * (cell + gap), pad), Vector2(cell, cell))
		cells.append([r, entries[i], i == int(got[1])])
	return {"hand": hand, "panel": panel, "cells": cells}


func _draw() -> void:
	if hands == null or not is_instance_valid(hands):
		return
	var lay := layout()
	draw_rect(lay.panel, PANEL)
	draw_rect(lay.panel, Color(EDGE, 0.35), false, 1.0)
	for c in lay.cells:
		var r: Rect2 = c[0]
		var it: Dictionary = c[1]
		var chosen: bool = c[2]
		if chosen:
			draw_rect(r, PICK)
			draw_rect(r, EDGE, false, 1.0)
		else:
			draw_rect(r, Color(DIM, 0.35), false, 1.0)
		var at := r.get_center().floor()
		var rad := r.size.x * 0.36
		if it.is_empty():
			ItemIcon.draw_hand(self, at, rad, EDGE if chosen else DIM, lay.hand == "right")
		else:
			ItemIcon.draw_icon(self, at, rad, it)
