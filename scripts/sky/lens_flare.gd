class_name LensFlare
extends CanvasLayer
## The sun flares when you look at it, the PSO way (design 3 Oct §DB,
## data/look.json lens_flare). Each frame (step()): the sun above the
## horizon, you not underground, its disc inside the frame and nothing in
## front of it (one physics ray toward it for the ground, trunks and walls,
## and the leaves it passes through, FoliageCover's see-through) and no
## cloud over it (§CX's one cover value: thin cloud dims it to
## through_cloud, none past gone_above_cloud; a cloud shadow over you,
## Wind III's field, is a cloud in front of the sun): then a core at the
## sun, a halo round it and rings on the line from the sun through the
## frame's centre, each at its `at` on that line (0 the sun, 1 the centre,
## past 1 the far side). It fades in and out over fade_s (a twig flicking
## past doesn't strobe) and toward the frame's edge over edge_fade.
##
## Drawn as flat discs on a canvas layer under PostGrade's (layer -2), so
## it is drawn into the 480-line frame and graded, 5-bit quantised and
## dithered with everything else: part of the picture, not a sharp overlay
## (§Y, R9). Soft discs with a 2 px edge at most, nothing blurred. Cool
## white and pale cyan (R7 keeps warm for fire); within 10° of the horizon
## the core takes the sun disc's colour (retro.colors.sunset_sun) and the
## rings stay cool. Never the moon, never underground.

static var F: Dictionary = Tuning.section("look", "lens_flare")

## The flare's alpha now (0-1, before strength) and where it was drawn
## (internal pixels): the sun, the core colour, and each ring's centre.
var alpha := 0.0
var target := 0.0
var sun_px := Vector2.ZERO
var center_px := Vector2.ZERO
var ring_px: Array[Vector2] = []
var core_color := Color.WHITE
var _canvas: Control
## Why it shows or not (tools): "", "below", "under", "off_frame",
## "blocked", "cloud".
var why := ""


func _ready() -> void:
	layer = -2
	_canvas = Control.new()
	_canvas.name = "Flare"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_flare)
	add_child(_canvas)


static func _col(hex: Variant, fallback: String) -> Color:
	return Color.from_string(str(hex), Color.from_string(fallback, Color.WHITE))


## One frame: `cam` the camera, `sun_dir` (unit, world, toward the sun),
## its elevation (degrees), §CX's cover, the cloud shade over you (0-1),
## whether you're underground, the frame's size (internal pixels).
func step(cam: Camera3D, sun_dir: Vector3, sun_elev_deg: float, cover: float, cloud_here: float, under: bool, delta: float) -> void:
	var size := cam.get_viewport().get_visible_rect().size
	center_px = size * 0.5
	target = 0.0
	why = ""
	if under:
		why = "under"
	elif sun_elev_deg <= 0.0:
		why = "below"
	elif cover >= float(F.get("gone_above_cloud", 0.85)) or cloud_here > 0.0:
		why = "cloud"
	else:
		var eye := cam.global_position
		var far := eye + sun_dir * 4000.0
		if cam.is_position_behind(far):
			why = "off_frame"
		else:
			sun_px = cam.unproject_position(far)
			var edge := minf(minf(sun_px.x, size.x - sun_px.x), minf(sun_px.y, size.y - sun_px.y))
			if edge <= 0.0:
				why = "off_frame"
			elif blocked(cam, eye, sun_dir):
				why = "blocked"
			else:
				var fade_edge := clampf(edge / maxf(float(F.get("edge_fade", 0.1)) * minf(size.x, size.y), 1.0), 0.0, 1.0)
				var thin := lerpf(1.0, float(F.get("through_cloud", 0.4)), smoothstep(0.15, float(F.get("gone_above_cloud", 0.85)) - 0.05, cover))
				target = fade_edge * thin
	# In and out over fade_s.
	var rate := 1.0 / maxf(float(F.get("fade_s", 0.15)), 0.01)
	alpha = move_toward(alpha, target, rate * delta)
	# The rings on the sun-to-centre line.
	ring_px.clear()
	for r in F.get("rings", []):
		ring_px.append(sun_px + (center_px - sun_px) * float((r as Dictionary).get("at", 1.0)))
	var cool := _col(F.get("core_color", "#F4F8FF"), "#F4F8FF")
	var sunset := _col((Tuning.section("look", "retro").get("colors", {}) as Dictionary).get("sunset_sun", "#FBF486"), "#FBF486")
	core_color = cool.lerp(sunset, 1.0 - smoothstep(8.0, 12.0, sun_elev_deg))
	_canvas.queue_redraw()


## Something stands between you and the sun: the ground, a trunk or a wall
## (one ray), or the leaves the line passes through.
func blocked(cam: Camera3D, eye: Vector3, sun_dir: Vector3) -> bool:
	var space := cam.get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, eye + sun_dir * 2000.0)
	var player := cam.get_parent()
	while player != null and not (player is CollisionObject3D):
		player = player.get_parent()
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	if not space.intersect_ray(q).is_empty():
		return true
	var to := eye + sun_dir * 60.0
	return FoliageCover.see_through(eye, to, FoliageCover.clusters_round(space, eye)) < 0.5


func _draw_flare() -> void:
	var a := alpha * float(F.get("strength", 0.6))
	if a <= 0.004:
		return
	var halo := _col(F.get("halo_color", "#BFE6FF"), "#BFE6FF")
	_disc(sun_px, float(F.get("halo_px", 28)) * 0.5, halo, a * float(F.get("halo_alpha", 0.35)))
	_disc(sun_px, float(F.get("core_px", 10)) * 0.5, core_color, a)
	var rings: Array = F.get("rings", [])
	for i in rings.size():
		var r: Dictionary = rings[i]
		_disc(ring_px[i], float(r.get("px", 9)) * 0.5, _col(r.get("color", "#9FD8FF"), "#9FD8FF"), a * float(r.get("alpha", 0.15)))


## A soft disc: a solid middle and a 2 px edge stepping down, no blur
## (three stacked discs, the outer two at a third of the alpha each).
func _disc(c: Vector2, r: float, col: Color, a: float) -> void:
	var p := c.round()
	_canvas.draw_circle(p, maxf(r, 1.0), Color(col.r, col.g, col.b, a * 0.35), true, -1.0, false)
	_canvas.draw_circle(p, maxf(r - 1.0, 1.0), Color(col.r, col.g, col.b, a * 0.35), true, -1.0, false)
	_canvas.draw_circle(p, maxf(r - 2.0, 0.5), Color(col.r, col.g, col.b, a * 0.6), true, -1.0, false)
