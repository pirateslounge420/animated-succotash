class_name CrawlerFires
extends Node3D
## The tomb's fire (design 6 Oct §ET.3, §ET.4; crawler.json holders,
## delves.json fire_holders): the hearth in the hearth room, lit when you
## wake and kept by the one who found you; the cold fire-holders down the
## tomb (a hearth ring in each room, delves.json by_ruin tomb, and wall
## sconces down the corridors); and the bundle of unlit torches by the
## hearth (§AW).
##
## Every fire is a Campfire (the same stones, coals, flame card, light,
## sound and smoke as the open world's, so the torch's swing finds them,
## §CN, and lights and catches from them), each with its own store
## (FireStore). The holders start out: dark, nothing glowing, the ash of
## the last fire laid in them (holders.laid: the swing lights them, no
## kindling to find) so the swing of a lit torch catches them; once lit
## they never burn down (holders.kept: FireStore's kept stores) and stay
## lit for the game (§ET.4: light is the score), and an unlit torch swung
## through one catches. A sconce is a flame on a stone bracket at chest
## height on the wall, its light reaching light_radius_m.

static var HOLD: Dictionary = Tuning.table("crawler").get("holders", {})
static var FH: Dictionary = Tuning.table("delves").get("fire_holders", {})
## The ash laid in a cold holder (fuel.json kindling kinds): dry, catches
## after its catch time.
const LAID_KINDLING := "dry_twigs"

var world: Node
var hearth: Node3D
## The cold holders, in the layout's order.
var holders: Array[Node3D] = []
## The bundle by the hearth: [node, torches left].
var bundle: Node3D
var bundle_left := 0
## What never blocks a flame's light in lit_on (the player's own body).
var ray_exclude: Array[RID] = []
var _t := 0.0
var _flames := PackedVector3Array()
var _flames_frame := -1


## A store key for a point in the flat tomb (FireStore keys by surface
## direction; these are just as unique).
static func key_dir(pos: Vector3) -> Vector3:
	return pos * 1.0e-4 + Vector3(0.31, 0.53, 0.79)


func build(p_world: Node, lay: Dictionary) -> void:
	world = p_world
	FireStore.stores.clear()
	# The hearth: lit, tended, kept (the rescuer keeps it, §ET.3).
	var hp: Vector3 = lay.hearth
	hearth = Campfire.build_at(self, world, Transform3D(Basis.IDENTITY, hp), key_dir(hp), false)
	hearth.name = "Hearth"
	var hst := FireStore.store_of(hearth)
	hst["kept"] = true
	hearth.set_meta("crawler_hearth", true)
	# Its smoke goes up the shaft (§ET.6).
	for h in lay.holders:
		holders.append(_holder(h))
	_bundle(lay.bundle)


func _holder(h: Dictionary) -> Node3D:
	var pos: Vector3 = h.pos
	var fire: Node3D
	if str(h.kind) == "sconce":
		fire = _sconce(pos, h.normal)
	else:
		fire = Campfire.build_at(self, world, Transform3D(Basis.IDENTITY, pos), key_dir(pos), false)
		fire.name = "FireHolder"
	# A cold holder: out, the ash laid, kept once lit (§ET.4).
	var st := FireStore.store_of(fire)
	var units: Array = []
	for i in int(FH.get("holds_units", 3)):
		units.append(["branch", FireStore.burn_min("branch")])
	st["units"] = units
	st["max_units"] = float(FH.get("holds_units", 3))
	st["state"] = "out"
	st["tended"] = true
	st["kept"] = bool(HOLD.get("kept", true))
	if bool(HOLD.get("laid", true)):
		st["kindling"] = {"kind": LAID_KINDLING, "wet": false, "wet_days": 0.0}
	fire.set_meta("fire_holder", str(h.kind))
	fire.set_meta("old_hearth", true)
	fire.set_meta("safe_m", float(FH.get("light_radius_m", 8.0)))
	fire.set_meta("range_m", float(FH.get("light_radius_m", 8.0)))
	fire.set_meta("piece", int(h.piece))
	FireStore.apply(fire)
	# Its logs are charred (a cold holder, OldHearths' look).
	for c in fire.get_children():
		if c is MeshInstance3D and c.name != "Coals" and (c as MeshInstance3D).mesh is CylinderMesh:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.09, 0.07, 0.06)
			(c as MeshInstance3D).material_override = m
	return fire


## A wall sconce at `pos` (the flame's foot) on the wall facing `nrm`: a
## stone bracket and cup, the flame card, the coals, the light, the
## sound; a Campfire to everything that looks for fires.
func _sconce(pos: Vector3, nrm: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Sconce"
	root.add_to_group(Campfire.GROUP)
	root.set_meta("lit", false)
	root.set_meta("smoke", 0.25)
	add_child(root)
	var right := Vector3.UP.cross(nrm).normalized()
	root.global_transform = Transform3D(Basis(right, Vector3.UP, nrm), pos + nrm * 0.32)
	var stone := Color(0.4, 0.42, 0.46)
	CreatureBodies.box(root, Vector3(0.16, 0.34, 0.3), Vector3(0.0, -0.22, -0.16), stone.darkened(0.1))
	CreatureBodies.box(root, Vector3(0.3, 0.1, 0.3), Vector3(0.0, -0.04, 0.0), stone)
	var phase := float(posmod(hash(pos), 1000)) * 0.37
	var coals := Campfire.coal_bed(phase)
	coals.position = Vector3(0, 0.02, 0)
	coals.scale = Vector3.ONE * 0.4
	root.add_child(coals)
	var s := float(HOLD.get("sconce_scale", 0.38))
	var flames := Campfire.flame_node(s, 0.9, 2, phase)
	flames.name = "Flames"
	flames.position = Vector3(0, 0.03, 0)
	root.add_child(flames)
	var hiss := Audio3D.make("fire", root, "Hiss")
	hiss.stream = SoundSynth.stream("fire_hiss_loop", posmod(hash(pos), SoundSynth.VARIANTS))
	hiss.volume_db = float((Campfire.A.get("hiss", {}) as Dictionary).get("volume_db", -14.0)) - 6.0
	var pops := Audio3D.make("fire", root, "Pops")
	pops.volume_db = -8.0
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Torch.fire_color()  # one firelight (§EX.6)
	light.omni_attenuation = Campfire.ATTENUATION
	light.position = Vector3(0, 0.3, 0)
	root.add_child(light)
	FireShadows.enlist(light)
	# Nothing of the sconce casts a shadow: the bracket, the cup and the
	# coals sit at the light's own seat, where they'd blot out the whole
	# corridor below it.
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("flick_seed", phase)
	# A small flame's light (Campfire.flicker sets the campfire's; this
	# scales it after).
	root.set_meta("energy_k", s * 1.4)
	root.set_meta("light_y", 0.3)
	FireStore.register(root, world, key_dir(pos), true)
	return root


## The bundle of unlit torches by the hearth (§AW, torch.json bundle):
## sticks bound with a cord, lying on the floor.
func _bundle(pos: Vector3) -> void:
	bundle_left = int((Torch.D.get("bundle", {}) as Dictionary).get("count_at_camp", 3))
	bundle = Node3D.new()
	bundle.name = "TorchBundle"
	add_child(bundle)
	bundle.position = pos
	bundle.rotation.y = randf() * TAU
	var wood := Color(0.36, 0.25, 0.14)
	for i in bundle_left:
		var stick := CreatureBodies.cone(bundle, 0.022, 0.018, 0.62, Vector3((i - (bundle_left - 1) * 0.5) * 0.05, 0.03, 0.0), wood.darkened(0.05 * i))
		stick.rotation = Vector3(PI * 0.5, 0.06 * (i - 1), 0.0)
		stick.name = "Stick%d" % i
		var tip := CreatureBodies.cone(bundle, 0.03, 0.026, 0.07, Vector3((i - (bundle_left - 1) * 0.5) * 0.05, 0.03, 0.31), Color(0.1, 0.08, 0.06))
		tip.rotation = stick.rotation
		tip.name = "Tip%d" % i
	CreatureBodies.cone(bundle, 0.07, 0.07, 0.04, Vector3(0.0, 0.03, -0.05), Color(0.5, 0.42, 0.28)).rotation = Vector3(PI * 0.5, 0.0, 0.0)


## Is the bundle within `reach` m of `pos`, with a torch left in it?
func bundle_in_reach(pos: Vector3, reach: float) -> bool:
	return bundle != null and bundle_left > 0 and bundle.global_position.distance_to(pos) <= reach


## One torch from the bundle (an unlit torch item), or {} when it's empty.
func take_torch() -> Dictionary:
	if bundle_left <= 0:
		return {}
	bundle_left -= 1
	for n in ["Stick%d", "Tip%d"]:
		var c := bundle.get_node_or_null(n % bundle_left)
		if c:
			c.queue_free()
	return Inventory.make("torch")


## Every flame burning now, where its light sits (design §FG: what dims
## the glow-moss and sends the beetles into the joints; the same flames
## HalfDark counts): the hearth, each relit holder and sconce, the torch in
## hand once lit, a planted torch, a fire pot's burning patch, burst or
## caught fire, and a lit wick (§FA.3). Gathered once a frame.
func flame_points() -> PackedVector3Array:
	var frame := Engine.get_process_frames()
	if frame == _flames_frame:
		return _flames
	_flames_frame = frame
	_flames = PackedVector3Array()
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var n := f as Node3D
		if n == null or not n.is_inside_tree() or not FireStore.is_lit(n):
			continue
		var l := n.get_node_or_null("Light") as Node3D
		_flames.append(l.global_position if l else n.global_position + Vector3.UP * 0.3)
	if Torch.instance != null and is_instance_valid(Torch.instance) and Torch.instance.lit():
		_flames.append(Torch.instance.flame_position())
	for p in PlantedTorch.all:
		if is_instance_valid(p) and p.is_inside_tree() and p.lit():
			_flames.append(p.global_position + p.up * float(Tuning.section("torch", "planted").get("stand_height_m", 0.9)))
	var fp := FirePots.instance
	if fp != null and is_instance_valid(fp):
		for f in fp.fires:
			# One gone out may already be freed: no cast before the check.
			if not is_instance_valid(f):
				continue
			var pf := f as PotFire
			if pf == null or not pf.burning():
				continue
			var pl := pf.light()
			if pl != null and pl.is_inside_tree():
				_flames.append(pl.global_position)
		for w in FirePots.flares():
			_flames.append(w.pos)
	return _flames


## Does a flame's light fall on `pos` (design §FG): a flame within
## `radius` with no stone between them? `nrm` is the surface's outward
## normal there; the light is tested to a point a hand off it.
func lit_on(pos: Vector3, nrm: Vector3, radius: float) -> bool:
	var at := pos + nrm * 0.12
	var space := get_world_3d().direct_space_state
	for f in flame_points():
		if f.distance_to(pos) > radius:
			continue
		var q := PhysicsRayQueryParameters3D.create(f, at)
		q.collision_mask = PropCollision.WORLD_LAYER
		q.exclude = ray_exclude
		if space.intersect_ray(q).is_empty():
			return true
	return false


## How many holders are lit now (§ET.4: light is the score).
func lit_count() -> int:
	var n := 0
	for h in holders:
		if FireStore.is_lit(h):
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	FireStore.tick(get_tree(), delta, get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() else Vector3.ZERO)
	# The flame, the light and the sound: the near fires each frame (the
	# far ones are dark beyond their light anyway).
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3.ZERO
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var n := f as Node3D
		if n == null or not n.is_inside_tree():
			continue
		if n.global_position.distance_to(eye) < 60.0 or FireStore.is_lit(n):
			Campfire.flicker(n, _t)
			var l := n.get_node_or_null("Light") as OmniLight3D
			if l:
				l.light_energy *= float(n.get_meta("energy_k", 1.0))
			if n.has_meta("draft"):
				_draft(n, l)
				# A cold holder's light is off, not just at nothing (§ER.1).
				l.visible = float(n.get_meta("burn", 1.0)) > 0.0


## A vented fire's draft (§EV.3, Vents): the vent draws the air,
## so the flame leans toward it, breathing, and its light flickers harder.
func _draft(n: Node3D, l: OmniLight3D) -> void:
	var lean: Vector3 = n.get_meta("draft")
	var hz := float(n.get_meta("draft_hz", 0.6))
	var sd := float(n.get_meta("flick_seed", 0.0))
	var breath := 0.55 + 0.45 * sin(_t * TAU * hz + sd) * sin(_t * TAU * hz * 0.37 + sd * 1.7)
	var flames := n.get_node_or_null("Flames") as Node3D
	if flames:
		# Tilt about the horizontal axis across the lean (local to the fire).
		var local := n.global_basis.inverse() * lean
		var axis := Vector3.UP.cross(local.normalized()) if local.length() > 1e-4 else Vector3.RIGHT
		flames.basis = Basis(axis.normalized(), local.length() * breath).scaled(flames.scale) if axis.length() > 0.5 else flames.basis
	if l:
		l.light_energy *= 1.0 + float(n.get_meta("draft_flicker", 0.2)) * (sin(_t * 11.3 + sd) * sin(_t * 4.1 + sd * 2.0))
