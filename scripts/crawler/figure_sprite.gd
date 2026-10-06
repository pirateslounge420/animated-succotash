class_name FigureSprite
extends MeshInstance3D
## A figure drawn as a pre-rendered sprite (design 6 Oct §ET.8, the Doom
## way; crawler.json sprites, rescuer): the shared rig (CloakedFigure, the
## beast heads of §EO/§EQ, painted per §ES) is put in a little world of
## its own and rendered once, from `around` directions round it (Doom's
## eight) at each of `rows_deg` heights (the camera above or below the
## figure's eye line), for each frame of its idle, into one sheet. In play
## it is this quad: upright, turning about its own up to face you
## (shaders/figure_sprite.gdshader), showing the frame for where you stand
## (the nearest of the eight around it and the nearest height) and the
## idle's frame, stepped at sprites.anim_fps. No skinning, no cloth, no
## physics in play: the small snap between angles is the era's tax.
## Lit by the fire like any pre-lit model, fogged by Look.

static var SP: Dictionary = Tuning.table("crawler").get("sprites", {})
## The idle's frames in order, each held for HOLD ticks of anim_fps: a
## slow breath, in and out.
const HOLD := 4
## A frame's height against the figure's (room for a beast's ears and
## horns over the head, the feet's shadow under them).
const FRAME_K := 1.2

var atlas: ImageTexture
var around := 8
var rows_deg: Array = [-25, 0, 30]
var frames := 1
## The figure's eye height above its feet (m): the rows are picked by the
## camera's height against it.
var eye_m := 1.5
## Which way the figure faces (radians about up; 0 faces -z, as the rig).
var yaw := 0.0
var _t := 0.0
var _mat: ShaderMaterial
## The frame shown now [around index, row, idle frame] (tests).
var shown := Vector3i.ZERO


## The sheet for the figure `body` (a node at the origin, its feet at 0,
## facing -z), `height_m` tall, `px` pixels a frame high, its idle posed
## by `pose` (Callable(body, frame, frames)) for each of `n_frames`.
## Renders in a SubViewport under `host` with its own world, so nothing of
## the scene shows; needs a real renderer (headless gets a blank sheet).
static func bake(host: Node, body: Node3D, height_m: float, px: int, n_frames: int, pose: Callable) -> Image:
	var n_around := int(SP.get("around", 8))
	var rows: Array = SP.get("rows_deg", [-25, 0, 30])
	var w := int(round(px * 0.75))
	var h := px
	var vp := SubViewport.new()
	vp.name = "SpriteBake"
	vp.size = Vector2i(w, h)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	# The paint is in the model (§ES.2): an even white light shows it as
	# painted; the fire lights the sprite in play.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	env.tonemap_mode = SkySystem.tonemapper()
	env.tonemap_exposure = SkySystem.tonemap_exposure()
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	vp.add_child(body)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = height_m * FRAME_K
	cam.near = 0.05
	cam.far = 20.0
	vp.add_child(cam)
	cam.current = true
	# No fog in the bake (the sprite is fogged in play).
	var fog_was: Variant = Look._params.get("look_fog_density", 0.0)
	Look.apply({"look_fog_density": 0.0})
	var sheet := Image.create(w * n_around * n_frames, h * rows.size(), false, Image.FORMAT_RGBA8)
	var center := Vector3(0.0, height_m * 0.5, 0.0)
	var tree := host.get_tree()
	# Let the cloth settle.
	for i in 12:
		await tree.physics_frame
	for f in n_frames:
		if pose.is_valid():
			pose.call(body, f, n_frames)
		for r in rows.size():
			var el := deg_to_rad(float(rows[r]))
			for k in n_around:
				# k 0: in front of the figure (the rig faces -z); then round
				# it the way a camera circling to its left goes.
				var a := TAU * k / n_around
				var dir := Vector3(-sin(a) * cos(el), sin(el), -cos(a) * cos(el))
				cam.global_position = center + dir * 4.0
				cam.look_at(center, Vector3.UP)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				if img == null or img.is_empty():
					continue
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((f * n_around + k) * w, r * h))
	Look.apply({"look_fog_density": fog_was})
	vp.queue_free()
	return sheet


## Show `sheet` (bake()) as a figure `height_m` tall with `n_frames` idle
## frames, eyes at `eye`, facing `face_yaw`.
func setup(sheet: Image, height_m: float, n_frames: int, eye: float, face_yaw: float) -> void:
	around = int(SP.get("around", 8))
	rows_deg = SP.get("rows_deg", [-25, 0, 30])
	frames = maxi(n_frames, 1)
	eye_m = eye
	yaw = face_yaw
	atlas = ImageTexture.create_from_image(sheet)
	var q := QuadMesh.new()
	q.size = Vector2(height_m * FRAME_K * 0.75, height_m * FRAME_K)
	# Its feet on the floor: framed as bake() framed it, round the
	# figure's middle.
	q.center_offset = Vector3(0.0, height_m * 0.5, 0.0)
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/figure_sprite.gdshader")
	_mat.set_shader_parameter("atlas", atlas)
	_mat.set_shader_parameter("grid", Vector2(around * frames, rows_deg.size()))
	Look.register(_mat)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Room round the quad as it turns.
	custom_aabb = AABB(Vector3(-1.0, -0.2 * height_m, -1.0), Vector3(2.0, height_m * 1.4, 2.0))


## The frame for a camera at `cam` (scene): [around index, row].
func frame_for(cam: Vector3) -> Vector2i:
	var foot := global_position
	var to := cam - foot
	var flat := Vector2(to.x, to.z)
	# The angle round the figure from its front (-z turned by yaw), the
	# same way bake() went round.
	var front := Vector2(-sin(yaw), -cos(yaw))
	var ang := atan2(front.x * flat.y - front.y * flat.x, front.dot(flat))
	var k := posmod(int(round(-ang / (TAU / around))), around)
	var el := rad_to_deg(atan2(cam.y - (foot.y + eye_m), maxf(flat.length(), 0.01)))
	var best := 0
	for r in rows_deg.size():
		if absf(float(rows_deg[r]) - el) < absf(float(rows_deg[best]) - el):
			best = r
	return Vector2i(k, best)


## The idle's frame at time `t` (s): 0, 1, ... n-1, ... 1, each held HOLD
## ticks of anim_fps (a breath every few seconds).
func idle_frame(t: float) -> int:
	if frames <= 1:
		return 0
	var seq: Array = []
	for i in frames:
		seq.append(i)
	for i in range(frames - 2, 0, -1):
		seq.append(i)
	var tick := int(floor(t * float(SP.get("anim_fps", 8))))
	return int(seq[(tick / HOLD) % seq.size()])


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam == null or _mat == null:
		return
	var fr := frame_for(cam.global_position)
	var f := idle_frame(_t)
	shown = Vector3i(fr.x, fr.y, f)
	_mat.set_shader_parameter("cell", Vector2(f * around + fr.x, fr.y))
