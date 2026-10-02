class_name Torch
extends Node3D
## The torch (design 30 Sept §AW, data/torch.json): the first tool. A
## carried thing (`kind` torch, Inventory: burden applies) held in one
## hand (PlanetPlayer.weapon "torch"; Q cycles to it while you carry one),
## drawn in first person like the bow. The swing passes the flame (design
## 2 Oct §CN, superseding §AW's right click): left click (`shoot`) swings
## it on the bare hand's arc and timing (Fists.STRIKE_S), and at the end
## of the arc the flame passes between it and whatever it touches within
## swing.lighting_reach_m, from lit to unlit, either way: a lit torch
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
## torch lies burning. The light: a point light with the data's falloff
## and flicker, no shadow map; the only warm light in the world is fire.
## Its state (lit, burn_left_min, burnt) lives in the item's own
## dictionary, so it comes and goes with the pack.

static var D := Tuning.table("torch")
static var L: Dictionary = D.get("light", {})
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
	_view_flame = flame_node(0.2)
	# At the stick's head: its top end, the card's foot a little into the
	# wood so the flame grows out of it (Mike, 1 Oct: it floated beside it).
	_view_flame.position = stick.transform * Vector3(0, cm.height * 0.5 - 0.02, 0)
	_view.add_child(_view_flame)
	_view.position = Vector3(0.34, -0.3, -0.56)
	Bow._no_shadow(_view)
	# The light, at the hand, on the player (it lights the world round you).
	_light = light_node()
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
	return n


## The torch's point light from the data: Minecraft-style falloff, warm,
## no shadow map (§AG).
static func light_node() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "TorchLight"
	l.light_color = Color(str(L.get("color", "#ffb347")))
	l.light_energy = float(L.get("energy", 2.2))
	l.omni_range = float(L.get("range_m", 14.0))
	l.omni_attenuation = float(L.get("attenuation", 1.6))
	l.shadow_enabled = bool(L.get("shadows", false))
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
	return Campfire.lit_near(tree, pos, radius) or PlantedTorch.lit_near(pos, radius)


## How far the flame passes on the swing (torch.json swing, §CN).
static func reach_m() -> float:
	return float((D.get("swing", {}) as Dictionary).get("lighting_reach_m", D.get("lighting_reach_m", 2.2)))


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
	if fire != null and not FireStore.is_lit(fire):
		return ["fire", fire]
	var pt := PlantedTorch.unlit_near(at, r)
	if pt != null:
		return ["planted", pt]
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


## The light's energy this instant: the flicker (harder guttering), scaled
## by `motion` (sprinting doubles it) and the wind.
static func energy_now(it: Dictionary, t: float, motion: float) -> float:
	var hz := float(L.get("flicker_hz", 9.0))
	var amount := float(L.get("flicker_amount", 0.18)) * motion
	var wind_v: Vector3 = weather.get("wind", Vector3.ZERO) if weather.get("wind") is Vector3 else Vector3.ZERO
	amount *= 1.0 + float(L.get("wind_flicker_scale", 1.5)) * clampf(wind_v.length() * 0.08, 0.0, 1.0)
	var e := float(L.get("energy", 2.2))
	if bool(it.get("resin", false)):
		e *= float((D.get("resin", {}) as Dictionary).get("energy_scale", 1.25))
	if guttering(it):
		e = float(L.get("gutter_energy", 0.9))
		amount *= 2.0
	var f := 1.0 + amount * (0.6 * sin(t * hz * TAU) + 0.4 * sin(t * hz * 2.3 * TAU + 1.0))
	return e * f


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
		_light.light_energy = energy_now(it, _t, motion)
		_view_flame.scale = Vector3.ONE * (0.9 + 0.1 * sin(_t * 7.0)) * (0.75 if guttering(it) else 1.0)
	_apply(lit())


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
		var range_m := float(L.get("range_m", 14.0))
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
