class_name CollisionView
extends Node3D
## Dev view (F4, dev mode only; spec Phase 1 "Agreed at Go"): wireframes of
## every collision shape within RADIUS_M of the player, to check hitboxes
## against what's drawn (spec D5: no ghost-through, no invisible walls).
## Colored by physics layer: the world (layer 1 only: ruins, props,
## camps) cyan, trees (layer 2) green, anything on another layer (creature
## hitboxes) magenta; the player's own capsule yellow, and the terrain's
## ground faint. Lines behind something show dimmer, and everything fades
## out toward RADIUS_M.
##
## Reads the physics space only. Off, it isn't processing and draws
## nothing (it's made on the first F4 press). On, it asks the physics
## space which shapes overlap a sphere round the player a few times a
## second (REFRESH_S) and draws each with Godot's own line mesh for that
## shape (Shape3D.get_debug_mesh(), made once per shape), and moves the
## lines with their bodies every frame.

const RADIUS_M := 40.0
const REFRESH_S := 0.25
const MAX_SHAPES := 2048
const WORLD_COLOR := Color(0.25, 0.9, 1.0)
const TREE_COLOR := Color(0.55, 1.0, 0.3)
const OTHER_COLOR := Color(1.0, 0.3, 0.85)
const PLAYER_COLOR := Color(1.0, 0.88, 0.3)
const TERRAIN_COLOR := Color(0.85, 0.88, 1.0)

const _SHADER := "
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, world_vertex_coords%s;
uniform vec4 color : source_color;
uniform vec3 center;
uniform float radius;
varying vec3 world_pos;
void vertex() {
	world_pos = VERTEX;
	// A hair toward the camera, so lines on a surface win over it.
	VERTEX += normalize(CAMERA_POSITION_WORLD - VERTEX) * 0.02;
}
void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - smoothstep(radius * 0.75, radius, distance(world_pos, center)));
}
"

var player: Node3D
var _on := false
var _timer := 0.0
var _query: PhysicsShapeQueryParameters3D
var _pool: Array[MeshInstance3D] = []
## [line mesh instance, body, shape owner] for each shape shown.
var _shown: Array = []
## Kind ("world", "tree", "other", "player", "terrain") -> material.
var _mats := {}
var _legend: RichTextLabel
var _legend_layer: CanvasLayer


## Show or hide the view under `parent`, making it the first time
## (main.gd calls this on F4 in dev mode).
static func toggle_for(parent: Node, p_player: Node3D) -> CollisionView:
	var view := parent.get_node_or_null("CollisionView") as CollisionView
	if view == null:
		view = CollisionView.new()
		view.name = "CollisionView"
		view.player = p_player
		parent.add_child(view)
	view.toggle()
	return view


func _ready() -> void:
	set_process(false)
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS_M
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = sphere
	_query.collide_with_areas = true
	_query.collide_with_bodies = true
	for kind in ["world", "tree", "other", "player", "terrain"]:
		var col: Color = {"world": WORLD_COLOR, "tree": TREE_COLOR, "other": OTHER_COLOR,
			"player": PLAYER_COLOR, "terrain": TERRAIN_COLOR}[kind]
		if kind == "terrain":
			# Faint, and only where it's in view.
			_mats[kind] = _material(col, 0.16, false)
			continue
		# Seen through walls, dimly; then drawn again where it's in front.
		var xray := _material(col, 0.3, true)
		xray.next_pass = _material(col, 1.0, false)
		_mats[kind] = xray
	_legend_layer = CanvasLayer.new()
	_legend_layer.layer = 11
	_legend_layer.visible = false
	add_child(_legend_layer)
	_legend = RichTextLabel.new()
	_legend.bbcode_enabled = true
	_legend.fit_content = true
	_legend.scroll_active = false
	_legend.autowrap_mode = TextServer.AUTOWRAP_OFF
	_legend.add_theme_font_size_override("normal_font_size", HudText.px(9))
	_legend.add_theme_font_size_override("bold_font_size", HudText.px(9))
	_legend.add_theme_constant_override("outline_size", 3)
	_legend.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.12))
	_legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_legend.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_legend_layer.add_child(_legend)


func toggle() -> void:
	_on = not _on
	set_process(_on)
	_legend_layer.visible = _on
	_timer = 0.0
	if not _on:
		# Nothing left drawing or held.
		for mi in _pool:
			mi.queue_free()
		_pool.clear()
		_shown.clear()


func is_on() -> bool:
	return _on


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_S
		_refresh()
	var center := player.global_position
	for kind in _mats:
		var m: ShaderMaterial = _mats[kind]
		while m:
			m.set_shader_parameter("center", center)
			m = m.next_pass as ShaderMaterial
	# Follow the bodies (creatures move; a floating-origin shift moves all).
	for s in _shown:
		var mi: MeshInstance3D = s[0]
		# A creature's hitboxes go with it (freed as it leaves) or leave the
		# space while it's hidden, dead or far (Hitboxes.set_active()).
		var b = s[1]
		if is_instance_valid(b) and (b as CollisionObject3D).is_inside_tree() and (b as Node).can_process():
			mi.global_transform = (b as CollisionObject3D).global_transform * (b as CollisionObject3D).shape_owner_get_transform(s[2])
		else:
			mi.visible = false


## Ask the physics space what's near and point the line meshes at it.
func _refresh() -> void:
	_query.transform = Transform3D(Basis(), player.global_position)
	var hits := get_world_3d().direct_space_state.intersect_shape(_query, MAX_SHAPES)
	_shown.clear()
	var used := 0
	var counts := {}
	for hit in hits:
		var b := hit.collider as CollisionObject3D
		if b == null:
			continue
		var index: int = hit.shape
		var owner_id := b.shape_find_owner(index)
		var shape: Shape3D = null
		for k in b.shape_owner_get_shape_count(owner_id):
			if b.shape_owner_get_shape_index(owner_id, k) == index:
				shape = b.shape_owner_get_shape(owner_id, k)
		if shape == null:
			continue
		var kind := _kind(b)
		counts[kind] = counts.get(kind, 0) + 1
		if used >= _pool.size():
			var fresh := MeshInstance3D.new()
			fresh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fresh)
			_pool.append(fresh)
		var mi := _pool[used]
		used += 1
		mi.mesh = shape.get_debug_mesh()
		mi.material_override = _mats[kind]
		mi.global_transform = b.global_transform * b.shape_owner_get_transform(owner_id)
		mi.visible = true
		_shown.append([mi, b, owner_id])
	for i in range(used, _pool.size()):
		_pool[i].visible = false
		_pool[i].mesh = null
	_legend.text = "[b]Collision shapes (F4)[/b] within %d m:  [color=#%s]world %d[/color] · [color=#%s]trees %d[/color] · [color=#%s]other layers %d[/color] · [color=#%s]player[/color] · terrain faint" % [
		int(RADIUS_M), WORLD_COLOR.to_html(false), counts.get("world", 0), TREE_COLOR.to_html(false), counts.get("tree", 0),
		OTHER_COLOR.to_html(false), counts.get("other", 0), PLAYER_COLOR.to_html(false)]


## Which color a body's shapes get, from its physics layers.
func _kind(b: CollisionObject3D) -> String:
	if b == player:
		return "player"
	var layer := b.collision_layer
	if layer & ~(1 | TerrainChunk.TREE_LAYER):
		return "other"
	if layer & TerrainChunk.TREE_LAYER:
		return "tree"
	if b.get_parent() is TerrainChunk:
		return "terrain"
	return "world"


static func _material(col: Color, alpha: float, through: bool) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = _SHADER % (", depth_test_disabled" if through else "")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = 10 if through else 11
	m.set_shader_parameter("color", Color(col.r, col.g, col.b, alpha))
	m.set_shader_parameter("radius", RADIUS_M)
	return m
