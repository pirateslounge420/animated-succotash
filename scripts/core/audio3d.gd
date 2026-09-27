class_name Audio3D
extends Node
## Every world sound is a 3D player with distance and direction (spec
## D5). One falloff table, data/audio.json, holds a row per kind of sound
## (footstep, howl, thunder, camp_chatter...): unit size, max distance,
## attenuation model, loudest boost and distance muffling. apply() tunes an
## AudioStreamPlayer3D from its kind's row; nothing else sets those.
##
## Muffling: a kind with "muffle" [near_m, far_m] loses its high end and
## most of its left-right direction between those distances from the
## listener (the camera drawing the view), the way a far howl sounds dull
## and seems to come from everywhere. Players of such kinds join GROUP;
## one Audio3D node (made on first use, under the scene root) re-muffles
## the playing ones every frame, so a howl dulls as you walk away from it.

const DATA_PATH := "res://data/audio.json"
const GROUP := "audio3d_muffle"
const MODELS := {
	"inverse": AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
	"inverse_square": AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE,
	"log": AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC,
	"none": AudioStreamPlayer3D.ATTENUATION_DISABLED,
}
## Used for a kind missing from the table (and warned about once).
const FALLBACK := {"unit_size": 10.0, "max_distance": 100.0, "model": "inverse", "max_db": 3.0, "muffle": null}

static var _table := {}
static var _warned := {}
static var _node: Audio3D


## The falloff table (data/audio.json), loaded once.
static func table() -> Dictionary:
	if _table.is_empty():
		_table = {"muffle_far": {"cutoff_hz": 700.0, "pan": 0.05}, "kinds": {}}
		if FileAccess.file_exists(DATA_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
			if parsed is Dictionary:
				_table.merge(parsed, true)
			else:
				push_warning("Audio3D: %s is not valid JSON, using defaults" % DATA_PATH)
	return _table


## A kind's row (FALLBACK if the table has none).
static func row(kind: String) -> Dictionary:
	var kinds: Dictionary = table().kinds
	if kinds.has(kind):
		return kinds[kind]
	if not _warned.has(kind):
		_warned[kind] = true
		push_warning("Audio3D: no row for \"%s\" in %s" % [kind, DATA_PATH])
	return FALLBACK


## A new 3D player of `kind`, added under `parent`.
static func make(kind: String, parent: Node, player_name := "") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	if player_name != "":
		p.name = player_name
	apply(p, kind)
	parent.add_child(p)
	return p


## Tune `p` from `kind`'s row.
static func apply(p: AudioStreamPlayer3D, kind: String) -> void:
	var r := row(kind)
	p.set_meta("audio_kind", kind)
	p.unit_size = float(r.get("unit_size", 10.0))
	p.max_distance = float(r.get("max_distance", 0.0))
	p.attenuation_model = MODELS.get(str(r.get("model", "inverse")), AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	p.max_db = float(r.get("max_db", 3.0))
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	var m = r.get("muffle")
	if m is Array and (m as Array).size() == 2:
		p.set_meta("muffle", Vector2(float(m[0]), float(m[1])))
		p.add_to_group(GROUP)
		_ensure_node()
	else:
		if p.has_meta("muffle"):
			p.remove_meta("muffle")
		p.attenuation_filter_cutoff_hz = 20500.0 # off
		p.panning_strength = 1.0
		if p.is_in_group(GROUP):
			p.remove_from_group(GROUP)


## Start `p` (from `from_s` seconds in), muffled for where it is now.
static func play(p: AudioStreamPlayer3D, from_s := 0.0) -> void:
	if p == null or p.stream == null:
		return
	muffle(p)
	p.play(from_s)


## Set `p`'s muffling for its distance to the listener now.
static func muffle(p: AudioStreamPlayer3D) -> void:
	if not p.has_meta("muffle") or not p.is_inside_tree():
		return
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return
	var span: Vector2 = p.get_meta("muffle")
	var dist := cam.global_position.distance_to(p.global_position)
	var near := clampf(1.0 - (dist - span.x) / maxf(span.y - span.x, 1.0), 0.0, 1.0)
	var far: Dictionary = table().muffle_far
	p.attenuation_filter_cutoff_hz = lerpf(float(far.get("cutoff_hz", 700.0)), 20000.0, near * near)
	p.panning_strength = lerpf(float(far.get("pan", 0.05)), 1.0, near)


static func _ensure_node() -> void:
	if is_instance_valid(_node):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_node = Audio3D.new()
	_node.name = "Audio3D"
	tree.root.add_child.call_deferred(_node)


func _process(_delta: float) -> void:
	for n in get_tree().get_nodes_in_group(GROUP):
		var p := n as AudioStreamPlayer3D
		if p and p.playing:
			muffle(p)
