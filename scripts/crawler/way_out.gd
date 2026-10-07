class_name WayOut
extends Node3D
## The way out (design §EX.5; crawler.json exit; TombKit._way_out lays it,
## TombBuild builds its flight, landing and opening in the tomb's stone):
## at the top of the long flight past the heart, the old way in, and
## daylight in it: faint and cool, §EV.2's colours on the world's clock
## (smoke.json vents.daylight: cool blue by day, a faint moonlit blue at
## night; brighter as the sun climbs, as the shafts are, §FG), so from the
## bottom of the flight you can see where out is
## (light as wayfinding). Faint, never a spotlight (exit.glow): the
## opening glows (a flat sheet of the sky's colour just outside it, drawn
## as the vents' sky is, sheet_share of a shaft's sky; at night it keeps
## sheet_night of that on the night's blue, so it still shows) and a soft
## wash of it falls in over the landing and the top of the flight
## (light_share of a shaft's daylight, reaching reach_m). From far off the
## opening shows less of its glow (Mike, 7 Oct: "it should be relatively
## faint from far away but depends on time of day"): all of it within
## near_m of your eye, easing down to far_share by far_m; the wash is
## the stone's own light and stays as it is.
##
## Stepping into the opening is the way out: CrawlerMain asks stepped_in()
## and, until §EW.3's seam or §EW.7's surface is built, fades to the next
## tomb (exit.stand_in).

static var EXIT: Dictionary = Tuning.table("crawler").get("exit", {})
static var G: Dictionary = EXIT.get("glow", {})

var world: Node
## [{"exit", "sheet", "mat", "light"}]
var openings: Array = []
## 0-1 now: day (1) or night (0) on the world's clock (tests read it).
var daylight := 1.0
## The share of its glow the first opening shows from where you stand now
## (far_fade; tests read it).
var seen_share := 1.0


func build(p_world: Node, lay: Dictionary) -> void:
	world = p_world
	for ex in lay.get("exits", []):
		_opening(ex)
	_update()


## The daylight in an opening: the sheet outside it, the wash falling in.
func _opening(ex: Dictionary) -> void:
	var p: Vector3 = ex.p
	var n: Vector3 = ex.n
	var half := float(ex.half)
	var h := float(ex.h)
	var side := Vector3.UP.cross(n).normalized()
	# The sheet: past the threshold, between the stone carried on out
	# either side of the opening (TombBuild._outside), wider than the
	# opening so its edges never show, and reaching well over its head:
	# from the foot of the flight your eye goes up through the opening.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	var below := 0.4
	var above := h + TombBuild.OUTSIDE_UP_M
	q.size = Vector2(2.0 * half + 1.0, above + below)
	var sheet := MeshInstance3D.new()
	sheet.name = "Daylight"
	sheet.mesh = q
	sheet.material_override = mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	sheet.global_transform = Transform3D(Basis(side, Vector3.UP, n), p + n * (Delves.WALL * 0.5 + TombBuild.OUTSIDE_M) + Vector3.UP * ((above - below) * 0.5))
	# The wash: from high in the opening, in and down over the landing to
	# the top of the flight; soft-edged, no shadow (the vents' way).
	var sp := SpotLight3D.new()
	sp.name = "Wash"
	sp.shadow_enabled = false
	sp.spot_range = float(G.get("reach_m", 9.0))
	sp.spot_angle = 55.0
	sp.spot_attenuation = 1.2
	sp.spot_angle_attenuation = 2.0
	add_child(sp)
	var from := p + Vector3.UP * (h - 0.25) - n * 0.1
	var rise := float(ex.get("rise", 6.0))
	sp.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(from - n * 6.0 - Vector3.UP * minf(rise * 0.6, 4.0), Vector3.UP)
	openings.append({"exit": ex, "sheet": sheet, "mat": mat, "light": sp})


func _process(_delta: float) -> void:
	_update()


## The openings by the world's clock, as the shafts are (Vents): the
## colour by the twilight, the strength by the sun's height (§FG).
func _update() -> void:
	if world == null:
		return
	var L: Dictionary = Vents.L
	var days := float(world.get("days"))
	daylight = Vents.daylight_at(days)
	var sun := Vents.sun_light_at(days)
	var col := Color(str(L.get("night_color", "#2a3f80"))).lerp(Color(str(L.get("day_color", "#6f95e8"))), daylight)
	var energy := lerpf(float(L.get("night_energy", 0.45)), float(L.get("day_energy", 3.2)), sun) * float(G.get("light_share", 0.3))
	# At night the opening keeps sheet_night of its glow (on the night's
	# darker blue), so the way out still shows, faint, from below.
	var glow := float(L.get("sky_glow", 1.3)) * lerpf(float(G.get("sheet_night", 0.6)), 1.0, sun) * float(G.get("sheet_share", 0.6))
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for i in openings.size():
		var o: Dictionary = openings[i]
		var sp: SpotLight3D = o.light
		sp.light_color = col
		sp.light_energy = energy
		var k := 1.0 if cam == null else far_fade((o.exit.p as Vector3).distance_to(cam.global_position))
		if i == 0:
			seen_share = k
		var m: StandardMaterial3D = o.mat
		m.albedo_color = Color(col.r * glow * k, col.g * glow * k, col.b * glow * k)


## The share of its glow an opening shows from `d` m off (exit.glow): all
## of it within near_m, easing down to far_share by far_m.
static func far_fade(d: float) -> float:
	var near := float(G.get("near_m", 8.0))
	var far := maxf(float(G.get("far_m", 30.0)), near + 0.1)
	return lerpf(1.0, clampf(float(G.get("far_share", 0.55)), 0.0, 1.0), smoothstep(near, far, d))


## The way out whose opening `pos` (feet, scene) has stepped into, or -1.
func stepped_in(pos: Vector3) -> int:
	for i in openings.size():
		if in_opening(openings[i].exit, pos):
			return i
	return -1


## Is `pos` (feet, scene) in way out `ex`'s opening: past the inner face of
## its wall, within its width, at its floor?
static func in_opening(ex: Dictionary, pos: Vector3) -> bool:
	var rel := pos - (ex.p as Vector3)
	var n: Vector3 = ex.n
	var along := rel.x * n.x + rel.z * n.z
	var lateral := absf(rel.x * n.z - rel.z * n.x)
	return along > -Delves.WALL * 0.5 and lateral <= float(ex.half) and absf(rel.y) < 1.2
