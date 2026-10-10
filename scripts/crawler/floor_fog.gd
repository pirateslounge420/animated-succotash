class_name FloorFog
extends Node
## Floor two's fog (design 9 Oct §FM.6, queue 69; data/descent.json
## floor_two.fog): "the same stone and architecture as floor one ... with
## the energy of the whole place a little bit darker: a layer of fog across
## floor two, uniform for now." One fog over the whole of floor two, none
## on floor one.
##
## Fog is only fog: it changes how far you see, and how far your torch's
## light shows, by rendering, and nothing else. The light field's numbers
## (LightField), what the snake and the skeletons see and hear, the
## torch's light itself and every rule are as they were; this node writes
## the environment's fog and the look's haze and nothing more.
##
##   the fog       Godot's exponential fog, its amount 1 - exp(-density x
##                 distance), at floor_two.fog.density per metre, in the
##                 look's shade navy (color_from: look_shade_navy, look.json
##                 retro.targets.colours.shade, #06186C; LOOK_REFERENCE R3),
##                 never grey. Over the tomb's dark it makes distance lighter
##                 and bluer (R5); the torch's pool and every lit wall it
##                 veils the more the farther off they are.
##   where it is   the environment's fog, for whatever is drawn with Godot's
##   drawn         own materials (the bones, the voids, the vents' daylight),
##                 and the look's haze (shaders/look.gdshaderinc, look_fog),
##                 which every look material (the stone, the sprites, the
##                 folk, the glows) draws itself in place of the
##                 environment's: there it is added to floor one's own faint
##                 haze (crawler.json look fog_density and fog_color, the
##                 depth's dark, which both floors keep), the two colours
##                 mixed by their densities.
##   the stair     eased by where your eye is on the one flight between the
##                 floors (lay.descent, TombFloors): none until the last
##                 ease_m metres of the stair down, full at its foot, and out
##                 over the same metres going up (smoothstep: no pop). Off
##                 the flight it is 0 on floor one and 1 on floor two
##                 (TombFloors.floor_at); between the pieces (a doorway's
##                 thickness) it holds what it was.
##
## Written only when it changes, so FigureSprite.bake (which takes the haze
## off for its bake and puts back what it found) is never written over in
## the middle of one.

static var FOG: Dictionary = ((Tuning.table("descent").get("floor_two", {}) as Dictionary).get("fog", {}) as Dictionary)

var main: Node
## How much of floor two's fog is on now: 0 (floor one) to 1 (floor two).
var share := 0.0
## Tools: pins the share (0-1); below 0, it follows your eye.
var force_share := -1.0
## Tools: times the fog was written.
var writes := 0


## The fog for `p_main` (CrawlerMain: its environment, its player, the
## tomb's layout now).
func setup(p_main: Node) -> void:
	main = p_main


## floor_two.fog.density: per metre, at full (floor two).
static func density() -> float:
	return maxf(float(FOG.get("density", 0.04)), 0.0)


## floor_two.fog.ease_m: the stair's last metres the fog eases in over.
static func ease_m() -> float:
	return maxf(float(FOG.get("ease_m", 4.0)), 0.0)


## The fog's colour (sRGB), from floor_two.fog.color_from: look_shade_navy
## (look.json retro.targets.colours.shade, #06186C), look_shade_deep
## (shade_deep, #020A39), or a colour of its own ("#rrggbb").
static func color() -> Color:
	var from := str(FOG.get("color_from", "look_shade_navy"))
	var cols: Dictionary = (Tuning.section("look", "retro").get("targets", {}) as Dictionary).get("colours", {})
	if from == "look_shade_deep":
		return Color(str(cols.get("shade_deep", "#020A39")))
	if from.begins_with("#") and Color.html_is_valid(from):
		return Color(from)
	return Color(str(cols.get("shade", "#06186C")))


## Floor one's own haze (crawler.json look, as CrawlerMain._environment sets
## it): the depth's dark, on both floors.
static func haze_density() -> float:
	return float(CrawlerMain.LOOKD.get("fog_density", 0.025))


static func haze_color() -> Color:
	return Color(str(CrawlerMain.LOOKD.get("fog_color", "#05081c")))


## The look's haze with `s` (0-1) of floor two's fog in it: {"density" per
## metre, "color" sRGB}: the two densities added, their colours mixed by
## them (in linear light, as the two would scatter).
static func look_haze(s: float) -> Dictionary:
	var hd := haze_density()
	var fd := density() * clampf(s, 0.0, 1.0)
	if fd <= 0.0:
		return {"density": hd, "color": haze_color()}
	var c := haze_color().srgb_to_linear().lerp(color().srgb_to_linear(), fd / (hd + fd))
	c.a = 1.0
	return {"density": hd + fd, "color": c.linear_to_srgb()}


## How much of floor two's fog is on with your eye at `pos` (scene) in
## tomb `lay`: on the flight between the floors (and in its two doorways)
## eased by how far down it you are (ease_along); elsewhere 0 on floor one
## and 1 on floor two; `held` where `pos` is on no piece. 0 in a tomb with
## one floor.
static func share_at(lay: Dictionary, pos: Vector3, held := 0.0) -> float:
	var d: Dictionary = lay.get("descent", {})
	if d.is_empty():
		return 0.0
	var top: Vector3 = d.top
	var bottom: Vector3 = d.bottom
	var down: Vector3 = d.down
	var run := (bottom - top).dot(down)
	var rel := pos - top
	var along := rel.dot(down)
	var across := absf(rel.dot(Vector3(-down.z, 0.0, down.x)))
	var stair: Dictionary = lay.pieces[int(d.stair)]
	if along >= -TombKit.WALL and along <= run + TombKit.WALL and across <= float(stair.half) + 0.3 \
			and pos.y > bottom.y - 1.0 and pos.y < top.y + float(stair.h) + 1.0:
		return ease_along(run, along)
	var f := TombFloors.floor_at(lay, pos)
	if f < 0:
		return held
	return 1.0 if f >= 1 else 0.0


## The share `along` m down the flight from its mouth (the doorway on floor
## one), `run` m from the mouth to its foot: 0 until the last ease_m metres
## (all of the flight if it is shorter), then smoothly to 1 at the foot.
static func ease_along(run: float, along: float) -> float:
	var e := minf(ease_m(), run)
	if e <= 0.001:
		return 1.0 if along >= run else 0.0
	return smoothstep(run - e, run, along)


func _process(_delta: float) -> void:
	update_now()


## The share where your eye is now (or force_share), written if it changed.
func update_now() -> void:
	if main == null:
		return
	var s := force_share
	if s < 0.0:
		var lay: Dictionary = main.get("lay")
		var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
		var player := main.get("player") as Node3D
		if cam == null and player == null:
			return
		s = share_at(lay, cam.global_position if cam != null else player.global_position, share)
	s = clampf(s, 0.0, 1.0)
	if absf(s - share) > 1e-5:
		apply(s)


## The fog at share `s`: the environment's (off at 0) and the look's haze.
func apply(s: float) -> void:
	share = clampf(s, 0.0, 1.0)
	writes += 1
	var env: Environment = main.get("environment") if main != null else null
	if env != null:
		env.fog_enabled = share > 0.0
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = density() * share
		env.fog_light_color = color()
		env.fog_light_energy = 1.0
		env.fog_sun_scatter = 0.0
		env.fog_aerial_perspective = 0.0
		env.fog_sky_affect = 0.0
		env.fog_height_density = 0.0
	var h := look_haze(share)
	Look.apply({"look_fog_density": float(h.density), "look_fog_color": h.color as Color})
