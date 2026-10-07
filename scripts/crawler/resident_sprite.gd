class_name ResidentSprite
extends FigureSprite
## A resident drawn as a baked sprite (design §ET.8, §EY.5: creatures are
## sprites; Residents): FigureSprite's upright quad, turning to face you,
## showing the frame for where you stand (eight around by three heights)
## in the pose its creature is in now (`pose`: SkeletonRig.POSES, one
## block of rows of the sheet each). Lit by the fire, fogged by Look, as
## the rescuer is.

## The sheet's poses, and the one shown.
var poses := 1
var pose := 0
## A frame's width against its height.
var aspect := 0.9


## Show `sheet` (bake_poses()) as a creature `height_m` tall standing,
## with `n_poses` poses, eyes at `eye`, facing `face_yaw`.
func setup_poses(sheet: Image, height_m: float, n_poses: int, p_aspect: float, eye: float, face_yaw: float) -> void:
	around = int(SP.get("around", 8))
	rows_deg = SP.get("rows_deg", [-25, 0, 30])
	frames = 1
	poses = maxi(n_poses, 1)
	aspect = p_aspect
	eye_m = eye
	yaw = face_yaw
	atlas = ImageTexture.create_from_image(sheet)
	var q := QuadMesh.new()
	q.size = Vector2(height_m * FRAME_K * aspect, height_m * FRAME_K)
	q.center_offset = Vector3(0.0, height_m * 0.5, 0.0)
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/figure_sprite.gdshader")
	_mat.set_shader_parameter("atlas", atlas)
	_mat.set_shader_parameter("grid", Vector2(around, rows_deg.size() * poses))
	Look.register(_mat)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1.2, -0.3 * height_m, -1.2), Vector3(2.4, height_m * 1.6, 2.4))


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _mat == null:
		return
	var fr := frame_for(cam.global_position)
	shown = Vector3i(fr.x, fr.y, pose)
	_mat.set_shader_parameter("cell", Vector2(fr.x, pose * rows_deg.size() + fr.y))


## The sheet for `body` (its feet at the origin, facing -z) `height_m`
## tall, each of `n_poses` posed by `pose_fn` (Callable(body, index)):
## for each pose a block of rows (sprites.rows_deg heights), each row the
## eight views round it (sprites.around), a frame `px` high and `aspect`
## of that wide. All eight views render at once (eight SubViewports on one
## world under `host`), so the sheet takes a few frames per pose; a real
## renderer only (headless gets a blank sheet of the right size).
static func bake_poses(host: Node, body: Node3D, height_m: float, px: int, aspect: float, n_poses: int, pose_fn: Callable) -> Image:
	var n_around := int(SP.get("around", 8))
	var rows: Array = SP.get("rows_deg", [-25, 0, 30])
	var w := int(round(px * aspect))
	var h := px
	var sheet := Image.create(w * n_around, h * rows.size() * n_poses, false, Image.FORMAT_RGBA8)
	if DisplayServer.get_name() == "headless":
		body.queue_free()
		return sheet
	var world := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	env.tonemap_mode = SkySystem.tonemapper()
	env.tonemap_exposure = SkySystem.tonemap_exposure()
	world.environment = env
	var vps: Array[SubViewport] = []
	var cams: Array[Camera3D] = []
	for k in n_around:
		var vp := SubViewport.new()
		vp.name = "PoseBake%d" % k
		vp.size = Vector2i(w, h)
		vp.world_3d = world
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		host.add_child(vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = height_m * FRAME_K
		cam.near = 0.05
		cam.far = 20.0
		vp.add_child(cam)
		cam.current = true
		vps.append(vp)
		cams.append(cam)
	vps[0].add_child(body)
	var center := Vector3(0.0, height_m * 0.5, 0.0)
	var tree := host.get_tree()
	await tree.process_frame
	for f in n_poses:
		pose_fn.call(body, f)
		for r in rows.size():
			var el := deg_to_rad(float(rows[r]))
			for k in n_around:
				# k 0: in front (the body faces -z); then round it the way a
				# camera circling to its left goes (as FigureSprite.bake).
				var a := TAU * k / n_around
				var dir := Vector3(-sin(a) * cos(el), sin(el), -cos(a) * cos(el))
				cams[k].global_position = center + dir * 4.0
				cams[k].look_at(center, Vector3.UP)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			for k in n_around:
				var img := vps[k].get_texture().get_image()
				if img == null or img.is_empty():
					continue
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(k * w, (f * rows.size() + r) * h))
	for vp in vps:
		vp.queue_free()
	return sheet
