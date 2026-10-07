class_name Vents
extends Node3D
## Every built-in fire underground has its own vent to the sky (design §EV;
## smoke.json vents; TombKit places the vents, TombBuild carves them and
## paints their soot). This draws what comes down them and what the air
## does:
##
##   the daylight  down a shaft only (a hearth's, a hearth ring's, an
##                 altar's; a sconce's or brazier's narrow flue lets in no
##                 light worth drawing, §EV.2): a column of sky-light
##                 falling to the floor beside the fire (a spot light, a
##                 seen beam of lit air, the sky's disc up the shaft), cool
##                 blue by day and a faint moonlit blue by night on the
##                 world's clock (the 144-minute day, which CrawlerMain
##                 runs), so blue owns the frame and the fire is the one
##                 warm accent; brightening and dimming with the sun's
##                 height over the tomb (design §FG: flavour, never a key;
##                 daylight.sky_band_deg, low_sun_share); fainter and
##                 narrower the deeper the shaft (daylight.fade_depth_m)
##   the draft     the air the vent draws leans the fire's flame toward it
##                 and quickens its flicker, the ordinary lean only (§EV.3;
##                 CrawlerFires reads the fire's "draft" meta)
##
## The soot is painted into the stone (TombBuild._soot).

static var V: Dictionary = TombKit.vents_table()
static var L: Dictionary = V.get("daylight", {})

var world: Node
## [{"vent", "light", "beam", "sky", "beam_mat", "sky_mat"}]
var shafts: Array = []
## 0-1 now: day (1) or night (0) on the world's clock (tests read it).
var daylight := 1.0
## 0-1 now: how much of noon's light comes down a shaft (sun_light_at).
var sun := 1.0


## The sun's height (degrees) over the tomb at world time `days`. One
## clock everywhere (design §FK.3): no latitude, no axial tilt, no day of
## the year, so every day is DayCycle's reference day (the equator on an
## equinox: day 60, dusk 18, night 48, dawn 18 of the 144 minutes), the
## sky turning on its warp, the sun 90° up at noon and its hour angle off
## the overhead after.
static func sun_deg(days: float) -> float:
	return 90.0 - absf(DayCycle.warp(fposmod(days, 1.0), 0.0, 0.0) - 0.5) * 360.0


## The world time on the day of `base_days` when the tomb's sky reaches
## solar hour `hour` (0-24, 12 the sun overhead; sun_deg's day).
static func days_at_solar_hour(base_days: float, hour: float) -> float:
	return floorf(base_days) + DayCycle.unwarp(hour / 24.0, 0.0, 0.0)


## The day's share (0 night - 1 day) at world time `days`: the sky's blue
## coming up as the sun climbs through daylight.sky_band_deg (twilight).
static func daylight_at(days: float) -> float:
	var b: Array = L.get("sky_band_deg", [-7.0, 11.5])
	return smoothstep(float(b[0]), float(b[1]), sun_deg(days))


## How much of noon's light comes down a shaft at world time `days` (0-1):
## the twilight's share times the sun's height (with the sun on the
## horizon daylight.low_sun_share of it, rising with the sine of the sun's
## height to all of it overhead), so the column brightens through the
## morning and dims through the afternoon (design §FG).
static func sun_light_at(days: float) -> float:
	var low := clampf(float(L.get("low_sun_share", 0.35)), 0.0, 1.0)
	return daylight_at(days) * lerpf(low, 1.0, clampf(sin(deg_to_rad(sun_deg(days))), 0.0, 1.0))


func build(p_world: Node, lay: Dictionary, fires: CrawlerFires) -> void:
	world = p_world
	for v in lay.get("vents", []):
		var fire: Node3D = fires.hearth if int(v.fire_index) < 0 else fires.holders[int(v.fire_index)]
		_draft(v, fire)
		if bool(v.sky):
			_shaft(v, lay)
	_update(true)


## The flame leans toward its vent (CrawlerFires applies it).
func _draft(v: Dictionary, fire: Node3D) -> void:
	var m: Vector3 = v.mouth
	var f: Vector3 = v.fire
	var to := Vector3(m.x - f.x, 0.0, m.z - f.z)
	var dir := to.normalized() if to.length() > 0.05 else Vector3(1, 0, 0).rotated(Vector3.UP, float(posmod(hash(f), 628)) / 100.0)
	var dr: Dictionary = V.get("draft", {})
	fire.set_meta("draft", dir * deg_to_rad(float(dr.get("lean_deg", 7.0))))
	fire.set_meta("draft_flicker", float(dr.get("flicker", 0.22)))
	fire.set_meta("draft_hz", float(dr.get("hz", 0.6)))
	fire.set_meta("vent", v)


## The daylight down a shaft: the spot light, the seen beam, the sky's disc.
func _shaft(v: Dictionary, lay: Dictionary) -> void:
	var m: Vector3 = v.mouth
	var pc: Dictionary = lay.pieces[int(v.piece)]
	var floor_y := Delves.floor_of(pc, Delves.along_across(pc, Vector2(m.x, m.z)).x)
	var height := maxf(m.y - floor_y, 0.5)
	var d := float(v.d)
	var pool_r := d * float(L.get("pool_scale", 1.7)) * 0.5 + 0.2
	var sp := SpotLight3D.new()
	sp.name = "Daylight"
	sp.shadow_enabled = false
	sp.spot_range = height + 1.2
	sp.spot_angle = clampf(rad_to_deg(atan2(pool_r, height)), 4.0, 60.0)
	sp.spot_attenuation = 0.6
	sp.spot_angle_attenuation = 1.5
	add_child(sp)
	sp.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), m - Vector3(0.0, 0.05, 0.0))
	# The beam of lit air: one flat quad turned about the vertical to face
	# you, hard-edged, one flat colour (ShaftField's way, R7/R8).
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	bm.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2(d * 0.85, height)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = q
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.global_position = Vector3(m.x, floor_y + height * 0.5, m.z)
	# The sky at the flue's top, seen looking up it.
	var top: Vector3 = v.top
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sq := QuadMesh.new()
	sq.size = Vector2(d, d)
	var sky := MeshInstance3D.new()
	sky.name = "Sky"
	sky.mesh = sq
	sky.material_override = sm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	sky.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), top - Vector3(0.0, 0.05, 0.0))
	shafts.append({"vent": v, "light": sp, "beam": beam, "sky": sky, "beam_mat": bm, "sky_mat": sm})


func _process(_delta: float) -> void:
	_update(false)


## The shafts by the world's clock and their depth: the colour by the
## twilight (moonlit blue to day blue), the strength by the sun's height.
func _update(_force: bool) -> void:
	if world == null:
		return
	var days := float(world.get("days"))
	daylight = daylight_at(days)
	sun = sun_light_at(days)
	var day_c := Color(str(L.get("day_color", "#6f95e8")))
	var night_c := Color(str(L.get("night_color", "#2a3f80")))
	var col := night_c.lerp(day_c, daylight)
	var energy := lerpf(float(L.get("night_energy", 0.45)), float(L.get("day_energy", 3.2)), sun)
	var ref_d := float(((V.get("shaft", {}) as Dictionary).get("width_m", [0.6, 1.2]) as Array)[1])
	for s in shafts:
		var v: Dictionary = s.vent
		var share := float(v.share)
		# A narrow flue lets less in.
		var width_k := clampf(pow(float(v.d) / ref_d, 1.2), 0.08, 1.0)
		var sp: SpotLight3D = s.light
		sp.light_color = col
		sp.light_energy = energy * share * width_k
		var bm: StandardMaterial3D = s.beam_mat
		var a := float(L.get("beam_alpha", 0.2)) * share * lerpf(0.25, 1.0, sun) * sqrt(width_k)
		bm.albedo_color = Color(col.r, col.g, col.b, a)
		var sm: StandardMaterial3D = s.sky_mat
		var glow := float(L.get("sky_glow", 1.3)) * lerpf(0.18, 1.0, sun)
		sm.albedo_color = Color(col.r * glow, col.g * glow, col.b * glow)
