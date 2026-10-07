class_name HearthFolk
extends Node3D
## The folk at a hearth, live in 3D (design 6 Oct §FH; crawler.json
## folk_3d, rescuer). Mike, on the one who found you: not a flat pixel
## sprite but "the goat pixel guy" of reference frame 3, made of pixels
## and still a 3D model. So the rescuer (and any later folk at a hearth,
## folk_3d.who) is the shared rig itself, in the scene as real geometry:
## CloakedFigure (one rig, one wardrobe, §ET.9) with its beast head (§EO,
## §EQ) and its cloak's colours, painted per §ES (diffuse only, roughness
## 1, no normal maps, its occlusion baked into its vertex colours toward
## navy: Prelit), its painted detail in big texels on the tomb walls' own
## grid (folk_3d.texels_per_m, PlayerBody.set_texels()), made pixel by
## the 480-line frame. The hearth's amber falls on it live, and its shadow
## (the beast's head with the rest) goes over the floor and up the stone.
##
## It sits on a low stone by the fire (seat(); TombBuild lays the stone),
## facing the hearth in the rig's seated pose: hunched a little toward the
## warmth, hands in its lap. Its idle is the rig's own: a slow breath
## (rescuer.breath, breath_s), the hood turning to you while you're near
## and in front of it (the rig's head-look; CrawlerMain hands it your eyes)
## and otherwise glancing about now and then. It runs smooth at the frame
## rate (folk_3d.step_fps 0; 8 would step it as the sprites stepped). Its
## cloak is the rig's own cloth, in still air. You bump into it, never
## through it (the rig's blocker; nothing here swings at folk).
##
## Creatures and bosses stay baked sprites (FigureSprite, §ET.8;
## folk_3d.sprites_stay_for) until Mike says (§FI.2 call 11).

static var F3D: Dictionary = Tuning.table("crawler").get("folk_3d", {})
static var RES: Dictionary = Tuning.table("crawler").get("rescuer", {})

## The rig's seat in its own units: the seated hips (PlayerBody: SHIN_M +
## 0.06 up, 0.05 back) less the thighs' half thickness under them.
const SEAT_TOP := PlayerBody.SHIN_M - 0.015
## The seat stone (m): its width, its depth, and how far its middle sits
## behind the figure's own middle (the hips sit back; the shins hang in
## front of the stone).
const SEAT_W := 0.56
const SEAT_D := 0.42
const SEAT_BACK := 0.04

## The rig (PlayerBody) under this holder, and its head's animal ("" the
## empty hood).
var body: PlayerBody
var beast := ""
## The rig's scale (its height against the player's rig).
var k := 1.0


## A hearth folk `height_m` tall in `pal` ([main, trim], sRGB) wearing
## `animal`'s head, seated on the stone at `at` (its foot on the floor)
## facing `yaw` (radians about up; 0 faces -z, as the rig), under `parent`.
static func make(parent: Node, fname: String, at: Vector3, yaw: float, height_m: float, pal: Array, animal: String) -> HearthFolk:
	var f := HearthFolk.new()
	f.name = fname
	f.beast = animal
	# Where its head comes from, as on every camp's root (BeastHeads).
	f.set_meta("beast", animal)
	var b := CloakedFigure.build(height_m, pal[0], pal[1], true)
	f.body = b.root
	f.k = f.body.scale.x
	f.body.set_beast(animal)
	# Underground the air is still: the cloak hangs (no wind field here).
	f.body.set_wind(Vector3.ZERO)
	f.body.breath = float(RES.get("breath", 0.02))
	f.body.breath_s = float(RES.get("breath_s", 4.5))
	f.body.pose_fps = float(F3D.get("step_fps", 0.0))
	f.body.set_texels(float(F3D.get("texels_per_m", 16.0)))
	f.add_child(f.body)
	# The head's shadow too (the rig leaves a beast head's off, for camps of
	# many): by the hearth its ears and horns go up the wall with the rest.
	var head_mi := f.body.head.get_node_or_null("Beast") as GeometryInstance3D
	if head_mi != null:
		head_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# On its stone: the rig sits at its own seat height; a stone higher or
	# lower lifts or sinks it to match.
	var seat_h := float(RES.get("seat_h_m", 0.32))
	f.position = at + Vector3(0.0, seat_h - SEAT_TOP * f.k, 0.0)
	f.rotation = Vector3(0.0, yaw, 0.0)
	parent.add_child(f)
	# Something to bump into, round the seated torso (body space), once it
	# sits where it sits.
	Hitboxes.blocker(f, f.body, Vector3(0.0, 0.3, 0.05), Vector3(0.0, 1.0, 0.05), 0.24)
	return f


## The seat stone under a hearth folk at `at` facing `yaw`: {"xf" (its
## middle), "size"} for RuinBuilder.box().
static func seat(at: Vector3, yaw: float) -> Dictionary:
	var h := float(RES.get("seat_h_m", 0.32))
	var bs := Basis(Vector3.UP, yaw)
	return {"xf": Transform3D(bs, at + bs * Vector3(0.0, h * 0.5, SEAT_BACK)), "size": Vector3(SEAT_W, h, SEAT_D)}


## Which way it faces (scene, flat).
func front() -> Vector3:
	return -global_basis.z.normalized()
