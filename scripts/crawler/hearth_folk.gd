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
##
## The shaman (design 9 Oct §FM.6, queue 67; §FM.3: no speaking shamans):
## the one who found you reads as the shaman of the hearth, the cauldron
## hanging over its fire (HearthCauldron). The same rig, the same idle,
## wordless; what marks him is one of the shared props in his right hand
## (rescuer.holds, hold()): a long wooden ladle, the fire circle's stick
## (FireCircle._props) with a bowl at its end, through his fist, leaning
## out to his right and a little toward the fire, its bowl up
## (rescuer.ladle). It rides his hand,
## breath and all; nothing new in the rig. For code (prompt 72 has him
## brew): CrawlerMain.shaman(), the node "Rescuer", its `ladle`.

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
## What it holds in its right hand (hold(): the shaman's ladle), or null.
var ladle: MeshInstance3D

## Where a stick passes through the right fist, in the forearm's own space
## (ElbowR; PlayerBody's glove: the palm facing in, the fingers curled
## round, the thumb forward).
const FIST := Vector3(-0.008, -0.325, -0.012)


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
	# The shaman's ladle (§FM.6).
	f.hold(str(RES.get("holds", "ladle")))
	return f


## Put `what` in its right hand ("ladle": rescuer.ladle; "" nothing): a
## long wooden ladle through the fist, leaning out to its right by out_deg
## and toward the fire by fwd_deg, its bowl open to the sky and tipped
## toward the fire by bowl_tilt_deg (a scoop, never a disc held up);
## painted per §ES as the rig is (the rig's shader, its big texels:
## folk_3d.texels_per_m; its occlusion baked toward navy), casting the
## fire's shadow, nothing to bump into. A child of the right forearm, so it
## rides the hand. The ladle, or null.
func hold(what: String) -> MeshInstance3D:
	if ladle != null and is_instance_valid(ladle):
		ladle.get_parent().remove_child(ladle)
		ladle.free()
	ladle = null
	if what != "ladle" or body == null:
		return null
	var arm: Node3D = body.arms[1]
	var elbow := arm.get_node_or_null("ElbowR") as Node3D
	if elbow == null:
		return null
	var ld: Dictionary = RES.get("ladle", {})
	# The forearm's rest turn in the rig's own frame (no one poses its
	# arms: it sits, hands in its lap), so the ladle can be set by the rig's
	# up, right and front (-z).
	var eb := (arm.basis * elbow.basis).orthonormalized()
	var out := deg_to_rad(float(ld.get("out_deg", 40.0)))
	var fwd := deg_to_rad(float(ld.get("fwd_deg", 15.0)))
	var up := (eb.inverse() * Vector3(tan(out), 1.0, -tan(fwd))).normalized()
	var front := eb.inverse() * Vector3(0.0, 0.0, -1.0)
	front = (front - up * front.dot(up)).normalized()
	var bz := -front
	var bs := Basis(up.cross(bz), up, bz)
	# Its bowl's opening: the rig's up, tipped toward the fire, in the
	# ladle's own frame.
	var tilt := deg_to_rad(float(ld.get("bowl_tilt_deg", 30.0)))
	var opens := (bs.inverse() * (eb.inverse() * Vector3(0.0, cos(tilt), -sin(tilt)))).normalized()
	var mi := MeshInstance3D.new()
	mi.name = "Ladle"
	mi.mesh = ladle_mesh(ld, opens)
	# (Where its bowl opens, in its own frame: the checks.)
	mi.set_meta("opens", opens)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/player.gdshader")
	Look.register(m)
	m.set_shader_parameter("look_tex_weave", Look.texture("weave"))
	m.set_shader_parameter("texel_m", float(F3D.get("texels_per_m", 16.0)))
	mi.material_override = m
	mi.transform = Transform3D(bs, FIST)
	elbow.add_child(mi)
	ladle = mi
	return mi


## The ladle's mesh in its own frame: the handle up +y from below_fist_m
## under the fist (0) to the bowl, the bowl opening toward `opens` (its own
## frame), the handle's top on its rim. Vertex colours its wood, occlusion
## baked in (Prelit); UV.x 0 (the rig's shader draws it as its leather,
## never recoloured).
static func ladle_mesh(ld: Dictionary, opens := Vector3(0.0, 0.0, -1.0)) -> ArrayMesh:
	var col := Color(str(ld.get("color", "#4f3a27")))
	var length := maxf(float(ld.get("handle_m", 0.82)), 0.2)
	var below := clampf(float(ld.get("below_fist_m", 0.1)), 0.0, length * 0.5)
	var rr: Array = ld.get("handle_r_m", [0.014, 0.011])
	var r0 := maxf(float(rr[0]), 0.004)
	var r1 := maxf(float(rr[1]) if rr.size() > 1 else r0, 0.004)
	var br := maxf(float(ld.get("bowl_r_m", 0.05)), 0.02)
	var bd := clampf(float(ld.get("bowl_deep_m", 0.04)), 0.01, br)
	var st := HearthCauldron.new_arrays()
	var y0 := -below
	var y1 := length - below
	# The handle: a slim lathe, its foot and top closed, darker where it's
	# held.
	var hp := PackedVector2Array([Vector2(0.0, y0), Vector2(r0, y0), Vector2(r0, y0), Vector2(r0 * 0.96, 0.08), Vector2(r1, y1 - 0.01), Vector2(r1, y1), Vector2(r1, y1), Vector2(0.0, y1)])
	var grip := col.darkened(0.2)
	HearthCauldron.lathe(st, hp, PackedColorArray([col, col, col, grip, col, col, col, col]), 6, 0.0)
	# The bowl, its rim on the handle's top: a shallow cup, its dome up the
	# lathe's y (turned below away from `opens`) and its hollow below: from
	# the middle of the hollow out to the rim, over it, and back over the
	# dome.
	var wall := 0.006
	var cup := PackedVector2Array()
	var cc := PackedColorArray()
	for i in 5:
		var a := PI * 0.5 * float(i) / 4.0
		cup.append(Vector2((br - wall) * sin(a), (bd - wall) * cos(a)))
		cc.append(col.darkened(0.15))
	for i in range(4, -1, -1):
		var a := PI * 0.5 * float(i) / 4.0
		cup.append(Vector2(br * sin(a), bd * cos(a)))
		cc.append(col)
	# The cup's own axis (the lathe's +y, its dome) away from `opens`; its
	# rim's middle off the handle's top in the handle's lean across that
	# rim, so the handle meets the rim's near edge and the bowl hangs past.
	var ob := opens.normalized() if opens.length() > 1e-4 else Vector3(0.0, 0.0, -1.0)
	var yb := -ob
	var xb := yb.cross(Vector3.FORWARD if absf(yb.z) < 0.9 else Vector3.RIGHT).normalized()
	var across := Vector3.UP - ob * Vector3.UP.dot(ob)
	across = across.normalized() if across.length() > 1e-4 else xb
	var xf := Transform3D(Basis(xb, yb, xb.cross(yb)), Vector3(0.0, y1, 0.0) + across * br)
	HearthCauldron.lathe(st, cup, cc, 10, 0.0, xf)
	Prelit.bake(st.arrays, 16, 5, 0.8)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.arrays)
	return mesh


## The seat stone under a hearth folk at `at` facing `yaw`: {"xf" (its
## middle), "size"} for RuinBuilder.box().
static func seat(at: Vector3, yaw: float) -> Dictionary:
	var h := float(RES.get("seat_h_m", 0.32))
	var bs := Basis(Vector3.UP, yaw)
	return {"xf": Transform3D(bs, at + bs * Vector3(0.0, h * 0.5, SEAT_BACK)), "size": Vector3(SEAT_W, h, SEAT_D)}


## Which way it faces (scene, flat).
func front() -> Vector3:
	return -global_basis.z.normalized()
