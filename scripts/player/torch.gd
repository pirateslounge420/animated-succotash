class_name Torch
extends Node3D
## The torch (design 30 Sept §AW, data/torch.json): the first tool. A
## carried thing (`kind` torch, Inventory: burden applies) held in one
## hand (PlanetPlayer.weapon "torch"; Q cycles to it while you carry one),
## drawn in first person like the bow. The swing passes the flame (design
## 2 Oct §CN, superseding §AW's right click): left click (`shoot`) swings
## it on the bare hand's arc and timing (Fists.STRIKE_S), and at the end
## of the arc the flame passes between it and whatever it touches within
## swing.reach_m, from lit to unlit, either way: a lit torch
## lights a laid fire, embers, a delve's fire-holder or a planted torch
## (FireStore.swing_light); an unlit one swung through a lit fire, holder
## or planted torch catches (light). Sharing costs the torch nothing. The
## swing lights nothing else (never the ground, grass, a camp, folk or a
## creature: wildfire stays a dropped torch, §BL) and does nothing to a
## creature (no damage, knockback or flinch; §BA unchanged). Burns
## burn_min real minutes, rain and storms shorten that, then gutters (the
## last gutter_share: dimmer, a harder flicker) and goes out: a stick
## (`burnt`). Water past douse_depth_m puts it out (relight it at a
## flame); so does stowing it (Q away from it) and starting a climb with
## no ground to plant it in; with ground there, a climb plants it. Right
## click the ground with it lit to plant it (PlantedTorch); a dropped lit
## torch lies burning. Its head is a glowing ember, not a flame (Mike,
## 3 Oct; ember_node): a coal with the fire's colours in its cracks and a
## couple of sparks. The light: a point light with the data's falloff,
## breathing slowly with the ember (ember_glow), a soft shadow only while
## it is among the nearest fire lights (FireShadows, §ER.1); the only
## warm light in the world is fire.
## Its state (lit, burn_left_min, burnt) lives in the item's own
## dictionary, so it comes and goes with the pack.

static var D := Tuning.table("torch")
static var L: Dictionary = D.get("light", {})
## The torch's head is a glowing ember (Mike, 3 Oct; ember_node): how it
## breathes. torch.json "ember" when it lands; these are the defaults.
static var EMBER: Dictionary = D.get("ember", {})
## The weather where the player is (main sets it each frame): rain and
## storm shorten the burn, wind flickers the flame.
static var weather := {}
## The one in play (light_at()).
static var instance: Torch = null
## Torch bundles laid by fires (lay_bundle): [WorldItem or null, dir,
## ground, world day it ran out (or -1)], remade after bundle.remake_h_game.
static var bundles: Array = []

var player: PlanetPlayer
var _view: Node3D
var _view_flame: Node3D
var _light: OmniLight3D
var _voice: AudioStreamPlayer3D
var _t := 0.0
var _last_state := ""
## The swing (§CN): 1 .. 0 while one is under way.
var _swing := 0.0
var _down := false
var _blocked := false
## Swings made, and what the last one passed ("" nothing; tests).
var swings := 0
var last_pass := ""
## A line for the player (main shows it and clears it).
var note := ""


func setup(p: PlanetPlayer) -> void:
	player = p
	instance = self
	# In view (first person): a stick low right, the flame at its head.
	_view = Node3D.new()
	_view.name = "TorchView"
	p.camera().add_child(_view)
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.022
	cm.height = 0.42
	cm.radial_segments = 6
	stick.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.36, 0.25, 0.14)
	sm.roughness = 1.0
	stick.material_override = sm
	stick.rotation = Vector3(0.35, 0.0, -0.25)
	_view.add_child(stick)
	# The stick's top few centimetres are its burnt end (Mike, 3 Oct: an
	# ember, the burned end of the stick, not a ball).
	_view_flame = ember_node(cm.top_radius, 0.06, 0.2)
	# (The stick ends inside the burnt end's wide lower half, so it never
	# pokes out where the end narrows to its tip.)
	_view_flame.position = stick.transform * Vector3(0, cm.height * 0.5 - 0.06 * 0.4, 0)
	_view_flame.rotation = stick.rotation
	_view.add_child(_view_flame)
	_view.position = Vector3(0.34, -0.3, -0.56)
	Bow._no_shadow(_view)
	# The light, at the hand, on the player (it lights the world round you).
	_light = light_node()
	# The torch in hand a bit brighter than a planted one (design 4 Oct
	# §EB.3: light.held_scale on energy and range; same colour).
	_light.omni_range *= held_scale()
	_light.position = Vector3(0.3, 1.25, -0.4)
	p.add_child(_light)
	_voice = Audio3D.make("torch", self, "Voice")
	_voice.position = Vector3(0, 1.3, -0.3)
	_apply(false)


## A flame: the campfire's one flame card (Campfire.flame_node, design
## §BZ: one shader, every fire), at `size` times the campfire's card
## (look.json fire.flame.torch.scale when not given), its noise scrolling
## slower (torch.scroll_scale) with torch.embers embers. The held torch,
## the planted torch (PlantedTorch) and the fat lamp (PlayerFires) all
## use it.
static func flame_node(size := -1.0) -> Node3D:
	var t: Dictionary = Campfire.FL.get("torch", {})
	var s := size if size > 0.0 else float(t.get("scale", 0.32))
	var n := Campfire.flame_node(s, float(t.get("scroll_scale", 0.7)), int(t.get("embers", 2)), randf() * 100.0)
	n.name = "Flame"
	# Its smoke is sized by it (Smoke.tick_flame; §CV, Mike 3 Oct).
	n.set_meta("flame_size", s)
	return n


## A flame's smoke this frame (Smoke.tick_flame): a flame_node at its own
## size, its foot half the flame up, rising along `up`.
static func smoke_flame(flame: Node3D, up: Vector3) -> void:
	var s := float(flame.get_meta("flame_size", 0.32))
	Smoke.tick_flame(flame, flame.global_position + up * s * float(Campfire.FL.get("height_m", 1.0)) * 0.5, up, s)


## The burnt end's smoke (Smoke.tick_flame; every fire smokes by its size,
## Mike 3 Oct): an ember, so the embers row, at the torch flame's size
## (look.json fire.flame.torch.scale); `air` the head's own motion through
## the air, so the wisp trails behind it.
static func smoke_ember(ember: Node3D, up: Vector3, air := Vector3.ZERO) -> void:
	var s := float((Campfire.FL.get("torch", {}) as Dictionary).get("scale", 0.32))
	Smoke.tick_flame(ember, ember.global_position + up * 0.04, up, s, "embers", air)


## A torch's head: the burnt end of the stick, smouldering (Mike, 3 Oct:
## "more of a glowing ember", then "like a burned end of a stick, not
## rounded"): the stick's own last `length_m` m, `radius` m thick (the
## stick's), six-sided, a little thinner toward a jagged broken tip
## (_burnt_end_mesh), drawn by shaders/torch_ember.gdshader (black char,
## grey ash, heat in its cracks growing to the glowing tip, breathing with
## the light: set_glow), and the fire's few single-pixel sparks rising off
## the tip (Campfire's embers, torch.embers of them, at `spark_size` of a
## campfire's). Its origin is where the char meets the wood. The held and
## planted torches use it; the lamps keep their flames.
static func ember_node(radius: float, length_m: float, spark_size: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Ember"
	var head := MeshInstance3D.new()
	head.name = "Head"
	var phase := randf() * 50.0
	head.mesh = _burnt_end_mesh(radius, length_m, int(phase * 1000.0))
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/torch_ember.gdshader")
	m.set_shader_parameter("look_grain_soft", Look.grain())
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("length_m", length_m)
	m.set_shader_parameter("texels_m", float(EMBER.get("texels_m", 150.0)))
	m.set_shader_parameter("crawl", float(EMBER.get("crawl", 0.06)))
	var bands: Array = Campfire.FL.get("bands", ["#FEFC54", "#FCA82C", "#E6552A", "#5A0A00"])
	var hdr: Array = Campfire.FL.get("hdr", [1.0, 1.0, 1.0, 1.0])
	for i in 4:
		m.set_shader_parameter("band%d" % i, Campfire.emissive(bands[mini(i, bands.size() - 1)], float(hdr[i]) if i < hdr.size() else 1.0))
	head.material_override = m
	n.add_child(head)
	var t: Dictionary = Campfire.FL.get("torch", {})
	var count := int(t.get("embers", 2))
	if count > 0:
		var sparks := Campfire._ember_node(count, spark_size, phase)
		sparks.position = Vector3(0, length_m * 0.95, 0)
		n.add_child(sparks)
	return n


## The burnt end as a mesh: a six-sided piece of stick from y 0 (where it
## meets the wood, `radius` thick) to about `length_m`, a little thinner at
## the top, its top edge broken unevenly and its tip a jagged, sunken cap
## (no dome). Flat faces, seeded by `seed` so no two match.
static func _burnt_end_mesh(radius: float, length_m: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	const SIDES := 6
	var bottom: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in SIDES:
		var a := TAU * i / SIDES
		var dir := Vector3(cos(a), 0.0, sin(a))
		bottom.append(dir * radius * 1.04)
		mid.append(dir * radius * rng.randf_range(0.88, 1.0) + Vector3(0, length_m * rng.randf_range(0.45, 0.6), 0))
		top.append(dir * radius * rng.randf_range(0.62, 0.82) + Vector3(0, length_m * rng.randf_range(0.8, 1.0), 0))
	var cap := Vector3(rng.randf_range(-0.2, 0.2) * radius, length_m * rng.randf_range(0.72, 0.84), rng.randf_range(-0.2, 0.2) * radius)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SIDES:
		var j := (i + 1) % SIDES
		_flat_quad(st, bottom[i], bottom[j], mid[j], mid[i])
		_flat_quad(st, mid[i], mid[j], top[j], top[i])
		# The broken tip: sunken in the middle, a jagged rim round it.
		_flat_tri(st, top[i], top[j], cap)
	return st.commit()


static func _flat_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_flat_tri(st, a, b, c)
	_flat_tri(st, a, c, d)


## One outward-facing triangle with its own flat normal (cap faces point
## up: the shader's tip glow reads NORMAL.y).
static func _flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var nrm := (c - a).cross(b - a).normalized()
	var centre := (a + b + c) / 3.0
	var out := Vector3(centre.x, 0.0, centre.z)
	# Outward on the sides, up on the cap (Godot's front is clockwise).
	var want := out.normalized() if out.length() > 1e-5 and absf(nrm.y) < 0.7 else Vector3.UP
	if nrm.dot(want) < 0.0:
		var t := b
		b = c
		c = t
		nrm = -nrm
	for p in [a, b, c]:
		st.set_normal(nrm)
		st.add_vertex(p)


## The ember's glow now (1 full; the light's energy follows it): a slow
## breath and a faint shimmer, brighter when the air feeds it (sprinting:
## `motion`, and the wind), lower and slower guttering.
static func ember_glow(it: Dictionary, t: float, motion: float) -> float:
	var hz := float(EMBER.get("pulse_hz", 0.5))
	var amount := float(EMBER.get("pulse_amount", 0.14))
	var sh_hz := float(EMBER.get("shimmer_hz", 2.3))
	var sh := float(EMBER.get("shimmer_amount", 0.05))
	var wind_v: Vector3 = weather.get("wind", Vector3.ZERO) if weather.get("wind") is Vector3 else Vector3.ZERO
	var air := (motion - 1.0) * 0.5 + clampf(wind_v.length() * 0.08, 0.0, 1.0)
	var g := 1.0 + float(EMBER.get("air_brighten", 0.18)) * air
	if guttering(it):
		hz *= 0.6
		amount *= 1.6
	g *= 1.0 + amount * sin(t * hz * TAU) + sh * sin(t * sh_hz * TAU + 1.3)
	return g


## Set an ember_node's glow (its shader's `glow`; guttering draws it
## cooler: ember.gutter_glow).
static func set_glow(ember: Node3D, glow: float, it: Dictionary) -> void:
	var head := ember.get_node_or_null("Head") as MeshInstance3D
	if head and head.material_override:
		(head.material_override as ShaderMaterial).set_shader_parameter("glow", glow * (float(EMBER.get("gutter_glow", 0.72)) if guttering(it) else 1.0))


## The torch's point light from the data: Minecraft-style falloff, warm;
## a soft shadow only while it's among the nearest fire lights
## (FireShadows, design 6 Oct §ER.1).
## The torch in hand's light over a planted one's (light.held_scale; §EB.3).
static func held_scale() -> float:
	return float(L.get("held_scale", 1.0))


static func light_node() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "TorchLight"
	l.light_color = Color(str(L.get("color", "#ffb347")))
	l.light_energy = float(L.get("energy", 2.2))
	l.omni_range = float(L.get("range_m", 14.0))
	l.omni_attenuation = float(L.get("attenuation", 1.6))
	# A shadow only while among the nearest fire lights (FireShadows,
	# §ER.1; light.shadows no longer read).
	FireShadows.enlist(l)
	return l


# --- The torch in hand ------------------------------------------------------------

## The carried torch in hand (the lit one first), or {} with none.
func item() -> Dictionary:
	var best := {}
	for it in player.inventory.carried:
		if it is Dictionary and str(it.get("kind", "")) == "torch":
			if bool(it.get("lit", false)):
				return it
			if best.is_empty():
				best = it
	return best


func in_hand() -> bool:
	return player.weapon == "torch" and not item().is_empty()


func lit() -> bool:
	var it := item()
	return in_hand() and bool(it.get("lit", false))


## Any flame within `radius` of `pos` a torch can be lit at (a lit fire,
## a planted torch).
static func flame_near(tree: SceneTree, pos: Vector3, radius: float) -> bool:
	return Campfire.lit_near(tree, pos, radius) or PlantedTorch.lit_near(pos, radius) \
		or (Shrines.instance != null and Shrines.instance.sconce_near(pos, radius + 0.4, true) != null)


## How far the flame passes on the swing (torch.json swing, §CN).
static func reach_m() -> float:
	return float((D.get("swing", {}) as Dictionary).get("reach_m", D.get("lighting_reach_m", 2.2)))


## Where the swing's flame passes: the torch's head at the end of the arc,
## a little ahead of your chest.
func swing_point() -> Vector3:
	return player.reach_from() - player.global_basis.z * 0.4


## What a swing now would pass the flame to: [kind, node] with kind
## "torch" (an unlit torch catches), "fire" (a cold fire or holder),
## "planted" (a planted torch gone out), or [] for nothing.
func swing_target() -> Array:
	var it := item()
	if not in_hand() or bool(it.get("burnt", false)):
		return []
	var at := swing_point()
	var r := reach_m()
	if not bool(it.get("lit", false)):
		return ["torch", null] if flame_near(get_tree(), at, r) else []
	var fire := FireStore.nearest(get_tree(), at, r)
	if fire != null and not FireStore.is_lit(fire) and FireStore.state_of(fire) != "catching":
		return ["fire", fire]
	var pt := PlantedTorch.unlit_near(at, r)
	if pt != null:
		return ["planted", pt]
	# A shrine's dark sconce (design 3 Oct §DK): lit by the swing, no
	# kindling.
	if Shrines.instance != null:
		var sc := Shrines.instance.sconce_near(at, r + 0.4, false)
		if sc != null:
			return ["sconce", sc]
	return []


## Swing it (left click with it in hand). The flame passes at the end of
## the arc (pass_flame).
func swing() -> void:
	if _swing > 0.0 or not in_hand():
		return
	_swing = 1.0
	swings += 1
	player.make_noise(Fists.NOISE * 0.5)
	_voice.stream = SoundSynth.stream("whip", randi())
	_voice.pitch_scale = randf_range(0.7, 0.8)
	_voice.play()


func block_until_release() -> void:
	_blocked = true


## The end of the arc: the flame passes, lit to unlit, either way. Returns
## and keeps (last_pass) what it did: "torch" (this torch caught),
## "fire:<FireStore result>", "planted", or "" (nothing in reach).
func pass_flame() -> String:
	var t := swing_target()
	last_pass = ""
	if t.is_empty():
		return last_pass
	match str(t[0]):
		"torch":
			light()
			note = "The torch catches."
			last_pass = "torch"
		"planted":
			(t[1] as PlantedTorch).relight()
			note = "The planted torch catches."
			last_pass = "planted"
		"sconce":
			Shrines.instance.light(t[1])
			note = "The sconce catches."
			last_pass = "sconce"
		"fire":
			var fire: Node3D = t[1]
			var how := FireStore.swing_light(fire, player.world.days)
			last_pass = "fire:" + how
			note = FireStore.swing_words(fire, how)
	return last_pass


func light() -> void:
	var it := item()
	if it.is_empty():
		return
	it["lit"] = true
	if not it.has("burn_left_min"):
		it["burn_left_min"] = float(D.get("burn_min", 50.0))
	_play("torch_light")
	GameLog.add("Lit a torch from a flame.", "torch")
	_apply(true)


## Ground to plant it in: a point on the ground just ahead, within reach.
func plant_spot() -> Dictionary:
	var from := player.global_position + player.up * 1.0 - player.global_basis.z * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, from - player.up * 2.2)
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return {}
	var cb: Object = h.collider
	if cb is CollisionObject3D and ((cb as CollisionObject3D).collision_layer & TerrainChunk.TREE_LAYER) != 0:
		return {}
	return {"pos": h.position, "normal": h.normal}


func can_plant() -> bool:
	return lit() and not plant_spot().is_empty()


## Stand it in the ground where you look (right click the ground with it
## lit): out of the pack, burning on there.
func plant() -> bool:
	var spot := plant_spot()
	if spot.is_empty() or not lit():
		return false
	var it := item()
	_remove_from_pack(it)
	PlantedTorch.plant(it, player.world, spot.pos, player.up)
	GameLog.add("Planted the torch.", "torch")
	player.weapon = player.next_tool("torch") if player.inventory.has_kind("torch") else "hands"
	_apply(false)
	return true


## Both hands wanted (a climb, a cling): a lit torch is planted if there is
## ground for it, else it goes out.
func hands_needed() -> void:
	if not lit():
		return
	if bool(D.get("climb", {}).get("plant_if_ground", true)) and plant():
		return
	put_out("stowed")


## Q away from it, or into the pack: a lit torch goes out.
func stow() -> void:
	if lit():
		put_out("stowed")


func put_out(why: String) -> void:
	var it := item()
	if it.is_empty():
		return
	it["lit"] = false
	match why:
		"burnt":
			it["burnt"] = true
			GameLog.add("The torch has burnt out: a stick now.", "torch")
		"doused":
			GameLog.add("The water put the torch out.", "torch")
		_:
			GameLog.add("The torch is out.", "torch")
	_play("torch")
	_apply(false)


func _remove_from_pack(it: Dictionary) -> void:
	for i in player.inventory.carried.size():
		if player.inventory.carried[i] == it:
			player.inventory.carried[i] = null
			return


# --- Burning -----------------------------------------------------------------------

## Burn `it` down over `delta` seconds by the weather (rain and storms
## shorten it). Returns "gutter" the frame it starts to gutter, "out" the
## frame it dies, else "".
static func burn_step(it: Dictionary, delta: float, wx: Dictionary, _held: bool) -> String:
	if not bool(it.get("lit", false)):
		return ""
	var scale := 1.0
	var resin: Dictionary = D.get("resin", {})
	var is_resin := bool(it.get("resin", false))
	if float(wx.get("storm", 0.0)) > 0.5:
		scale = 1.0 / maxf(float(resin.get("storm_burn_scale", 0.7) if is_resin else D.get("storm_burn_scale", 0.35)), 0.05)
	elif float(wx.get("rain_mm_h", 0.0)) > 0.1 and not (is_resin and bool(resin.get("rain_immune", true))):
		scale = 1.0 / maxf(float(D.get("rain_burn_scale", 0.6)), 0.05)
	# A resin torch (design §BP) burns burn_scale times as long.
	if is_resin:
		scale /= maxf(float(resin.get("burn_scale", 1.8)), 0.1)
	var before := float(it.get("burn_left_min", float(D.get("burn_min", 50.0))))
	var after := before - delta / 60.0 * scale
	it["burn_left_min"] = after
	var gutter_at := float(D.get("burn_min", 50.0)) * float(D.get("gutter_share", 0.12))
	if after <= 0.0:
		it["lit"] = false
		it["burnt"] = true
		return "out"
	if before > gutter_at and after <= gutter_at:
		return "gutter"
	return ""


## Guttering?
static func guttering(it: Dictionary) -> bool:
	return float(it.get("burn_left_min", 99.0)) <= float(D.get("burn_min", 50.0)) * float(D.get("gutter_share", 0.12))


## How bright it is now against full (0-1): 1, or the gutter's share.
static func share_now(it: Dictionary) -> float:
	return float(L.get("gutter_energy", 0.9)) / maxf(float(L.get("energy", 2.2)), 0.01) if guttering(it) else 1.0


## The light's energy this instant: the data's energy (gutter_energy
## guttering, the resin's scale), breathing with the ember (ember_glow:
## a slow pulse, not a flame's flicker; Mike, 3 Oct), brighter when the
## air feeds it (`motion`: sprinting; the wind).
static func energy_now(it: Dictionary, t: float, motion: float) -> float:
	var e := float(L.get("energy", 2.2))
	if bool(it.get("resin", false)):
		e *= float((D.get("resin", {}) as Dictionary).get("energy_scale", 1.25))
	if guttering(it):
		e = float(L.get("gutter_energy", 0.9))
	return e * ember_glow(it, t, motion)


func update_torch(delta: float) -> void:
	_t += delta
	_update_swing(delta)
	var it := item()
	# Stowed (not in hand) but still lit: it goes out.
	if not it.is_empty() and bool(it.get("lit", false)) and player.weapon != "torch":
		put_out("stowed")
	if lit():
		var what := burn_step(it, delta, weather, true)
		if what == "gutter":
			GameLog.add("The torch gutters.", "torch")
			_play("torch")
		elif what == "out":
			put_out("burnt")
			return
		# Water: swimming, or wading past the douse depth.
		var water := player.chunks.water_level_at(player.surface_dir)
		var depth: float = (PlanetConst.RADIUS_M + water) - player.world.radius_of(player.global_position)
		# (In a delve, §CJ, you are under the ground, not under the sea.)
		if player.swimming or (depth > float(D.get("douse_depth_m", 0.6)) and not Delves.inside):
			put_out("doused")
			return
		var motion := float(L.get("sprint_flicker_scale", 2.0)) if player.sprinting else 1.0
		_light.light_energy = energy_now(it, _t, motion) * held_scale()
		set_glow(_view_flame, ember_glow(it, _t, motion), it)
	_apply(lit())
	if lit() and _view_flame.visible:
		smoke_ember(_view_flame, player.up, -player.velocity)


func _apply(on: bool) -> void:
	_view.visible = in_hand() and player.first_person and not player.climbing
	_view_flame.visible = _view.visible and on
	_light.visible = on and not player.climbing
	# The swing's arc, the fist's (Fists._carry): out along the aim and back.
	var s := sin(_swing * PI) if _swing > 0.0 else 0.0
	_view.position = Vector3(0.34, -0.3, -0.56).lerp(Vector3(0.1, -0.16, -0.86), s)
	_view.rotation = Vector3(-0.9 * s, 0.35 * s, 0.0)


## Left click with the torch in hand (§CN): one swing a press; the flame
## passes as the arc ends.
func _update_swing(delta: float) -> void:
	var down := Input.is_action_pressed("shoot") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Bow.need_capture)
	if not down:
		_blocked = false
	if down and not _down and not _blocked and in_hand() and not player.dead and not player.climbing and not player.swimming and not player.ui_open:
		swing()
	_down = down
	if _swing > 0.0:
		_swing = maxf(_swing - delta / maxf(Fists.STRIKE_S, 0.05), 0.0)
		if _swing <= 0.0:
			pass_flame()


func _play(kind: String) -> void:
	# The synth has no torch sounds yet: a crack for the lighting, a scuff
	# for going out (SoundSynth kinds).
	_voice.stream = SoundSynth.stream({"torch_light": "crack", "torch": "scuff"}.get(kind, kind), randi())
	_voice.play()


## Torchlight at `pos` (0-1): the one in hand and the planted ones. What
## the dark (§BA) and creatures' light response read.
static func light_at(pos: Vector3) -> float:
	var best := PlantedTorch.light_at(pos)
	if instance != null and is_instance_valid(instance) and instance.lit():
		var range_m := float(L.get("range_m", 14.0)) * held_scale()
		best = maxf(best, clampf(1.0 - instance._light.global_position.distance_to(pos) / range_m, 0.0, 1.0) * share_now(instance.item()))
	return best


# --- Bundles by the fire -------------------------------------------------------------

## A bundle of unlit torches laid by `fire` (items.json starting_kit_ambient
## by_the_fire; the ambient profile's camps): a WorldItem of `count`.
static func lay_bundle(world, chunks: ChunkManager, fire: Node3D) -> void:
	var kit: Dictionary = Inventory.data().get("starting_kit_ambient", {})
	for b in kit.get("by_the_fire", []):
		if not b is Dictionary or str(b.get("kind", "")) != "torch":
			continue
		var n := int(b.get("count", int(D.get("bundle", {}).get("count_at_camp", 3))))
		var fd: Vector3 = world.dir_of(fire.global_position)
		var at := fire.global_position + CubeSphere.north(fd).rotated(fd, 0.7) * 1.15
		var d: Vector3 = world.dir_of(at)
		var ground: float = chunks.ground_height(d)
		var it := Inventory.make("torch", {"count": n})
		var w := WorldItem.drop(it, world, d, ground)
		w.gift = true
		bundles.append([w, d, ground, -1.0])


## One torch from a bundle (main._take_lying): the bundle keeps the rest,
## or is gone when it runs out (remade after bundle.remake_h_game).
static func take_from_bundle(w: WorldItem, days: float) -> Dictionary:
	var it := w.item
	var one := Inventory.make("torch")
	var left := int(it.get("count", 1)) - 1
	if left > 0:
		it["count"] = left
	else:
		for b in bundles:
			if b[0] == w:
				b[0] = null
				b[3] = days
		w.pick_up()
	return one


## The folk make more: an empty bundle is laid again after remake_h_game
## game hours.
static func remake_bundles(world, chunks: ChunkManager, days: float) -> void:
	var wait := float(D.get("bundle", {}).get("remake_h_game", 24.0)) / 24.0
	for b in bundles:
		if b[0] == null and float(b[3]) >= 0.0 and days - float(b[3]) >= wait:
			var n := int(D.get("bundle", {}).get("count_at_camp", 3))
			var w := WorldItem.drop(Inventory.make("torch", {"count": n}), world, b[1], float(b[2]))
			w.gift = true
			b[0] = w
			b[3] = -1.0
