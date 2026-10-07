class_name FirePots
extends Node3D
## Fire pots (design 6 Oct night §FA.3, §FA.4, §FJ.5; data/fire_pots.json;
## prompt 60): rare sealed clay pots of oil with a wick (PotMesh), lit off
## the lit torch in your right hand and thrown. Fire is borrowed (§AW): no
## lit torch, no pot. The crawler's one node for them (CrawlerMain makes
## it):
##
##  * Carrying: each pot is an item of the left hand's own strip of the
##    pack (§FB: Inventory.strip, not the carry slots; items.json fire_pot,
##    its "oil" tar or light_oil), carry_max of them at most. They come from
##    the one found pot lying in a side room off the spine (found), and
##    from dev_items (F9: up to carry_max); restored ruins' gifts (§FF.3)
##    come later.
##  * The left hand (§FB, prompt 55: Hands): hold Tab and scroll to bring a
##    pot into your left hand, and again to empty it; `left` reads and sets
##    Hands' left hand. A pot in the left hand shows low left in view, and
##    the torch doesn't swing while it is there (hands.json
##    clicks.left_with_pot). The left hand doesn't change while a pot is
##    being lit or aimed (Hands.left_busy).
##  * Lighting (hands.json clicks.left_with_pot): hold left click with a lit
##    torch in your right hand and the hands come together in view over
##    light_anim_s, and the wick catches off the torch's flame. No lit torch
##    in hand, nothing happens. Let go before it catches and the hands part.
##  * Aiming (§N's hold to charge): keep holding and the lob's range grows
##    from throw.min_m to throw.max_m over charge_s, shown by a faint dotted
##    arc (AimArc's look; throw.arc_shown). The fuse runs from the catch
##    (fuse_s). Held past it, the pot bursts in your hand (cook_off_in_hand;
##    Mike, 7 Oct: "a fuse held too long after lighting will explode in
##    hand and cause 1 point of damage"): the burst where your hand is, the
##    pot gone, and one hit (Harm).
##  * The throw: let go and it lobs (ThrownPot) along your view, throw.lob_deg
##    above it, so looking level it lands at the charged range on level
##    ground; it bursts where it lands, or in the air when the fuse runs out.
##  * The burst (burst(), per oils.<kind>): fire damage within splash_m to
##    every fire target (below); tar sticks and burns what it hits at
##    burn_dps for burn_s and leaves a patch burning patch_radius_m for
##    floor_patch_s; light oil is the burst alone. A resident whose fire_hp
##    runs out burns out and is gone; a boss is driven off into the dark for
##    vs_boss.drives_off_s, never killed (§FA.4). Fire catches what burns
##    (spreads_to). Every flame of it is PotFire's: amber, glowing, smoking,
##    never a flame a torch or a holder takes from (relights_holders null).
##    A burst that catches a creature shows the crosshair's X (Reticle.hit;
##    Mike, 7 Oct).
##  * It can hurt you (hurts_you; Mike, 7 Oct: "your own fire pot should
##    be able to hurt you if you throw it way too close to yourself, like a
##    wall or floor you're right next to"): your own burst within
##    hurts_you_m of your body, with no stone between, is one hit. Its
##    burning patch and stuck tar never hurt you.
##  * It gives you away (§DF): the lit wick, in your hand and in the air, is
##    a flare seen within gives_away.flare_seen_m by anything with a clear
##    line to it (flares, flare_seen_from); the burst is heard within
##    burst_heard_m (bursts_since, and NoiseEvents, the game's hearing).
##
## The fire-target socket (for the boss, prompt 49, and the residents,
## prompt 58): a creature joins the group TARGET_GROUP and has
##   * fire_hp (a float var): a resident's fire hit points left
##     (residents.json creatures.<name>.fire_hp); burn() takes from it, and
##     at 0 calls its burn_out() (else frees it);
##   * fire_creature (a String var, or meta "creature"): its residents.json
##     key, for oil_scale;
##   * drive_off(seconds: float, from: Vector3): a boss's; then nothing
##     burns it down, it leaves for the dark for that long;
##   * optionally fire_hit(amount, from): fire reached it and it still
##     stands (a sleeping skeleton wakes);
##   * optionally fire_center() (where fire meets it; else its origin plus
##     meta fire_center_y, 0.9 m) and meta fire_radius_m (its body, 0.45 m),
##     or for a long body fire_distance(p) (how far p is from it, under 0
##     inside: the snake's whole length; INF while it isn't there).
## What sees and hears reads flare_seen_from() and bursts_since().

const FILE := "res://data/fire_pots.json"
const TARGET_GROUP := "fire_targets"

static var D: Dictionary = _json(FILE)
static var RES: Dictionary = _json("res://data/residents.json")
## The one in play.
static var instance: FirePots = null
## The bursts so far, newest last: {"id", "pos", "heard_m", "oil"}.
static var _bursts: Array = []
static var _next_burst := 1

var world: Node
var lay: Dictionary
var player: CrawlerPlayer
## Seconds since the tomb was built (the fires' and the flares' clock).
var clock := 0.0
## The pot in your left hand (an item of the strip), or {} for empty: the
## left hand is Hands' (§FB); this reads and sets it.
var left: Dictionary:
	get:
		return player.hands.left_item() if player != null and player.hands != null else {}
	set(v):
		if player != null and player.hands != null:
			player.hands.hold_left(v)
## "idle", "lighting" (the hands coming together), "aiming" (the wick lit).
var state := "idle"
var state_t := 0.0
## 0..1: how far the lob is charged.
var charge := 0.0
## Seconds left on the lit pot's fuse (0: spent; it waits for the impact).
var fuse_left := 0.0
## Throws made; the last one's [from, velocity, charge] (checks).
var throws := 0
## Pots that went off in your hand, and your own bursts that hit you
## (checks).
var cook_offs := 0
var self_hits := 0
var last_launch: Array = []
## Pots in the air, and the fires burning.
var flying: Array = []
var fires: Array = []
## What fire spreads to here (burnables_of; register_burnable).
var burnables: Array = []
## The found pot lying in its side room (null once taken), its room's id.
var found: Node3D = null
var found_room := -1
## Where the aim's arc lands now (INF while not aiming; checks).
var arc_end := Vector3.INF
## Char left on the stone where fire burnt out.
var chars: Array = []
## The ids handed to pots, so no two are alike.
var _next_id := 1

var _view: Node3D
var _view_pot: MeshInstance3D
var _view_oil := ""
var _wick: Node3D
var _wick_light: OmniLight3D
var _caught_at := -100.0
var _arc: MeshInstance3D
var _im := ImmediateMesh.new()
var _down := false
var _voice: AudioStreamPlayer3D

## The pot in view (camera space, at its foot): resting low left; where its
## wick meets the torch; drawn back at a full charge.
const REST := Vector3(-0.3, -0.36, -0.52)
const MEET := Vector3(-0.07, -0.33, -0.46)
const WIND := Vector3(-0.25, -0.24, -0.42)
## The torch in view at rest (Torch._apply's), and leant over to the wick.
const TORCH_REST := Vector3(0.34, -0.3, -0.56)
const TORCH_LEAN := 0.5
## The lit wick's light on you (player space): over the left hand, a third
## of a metre from the pot in view.
const WICK_LIGHT_AT := Vector3(-0.25, 1.62, -0.3)


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("FirePots: %s is missing" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("FirePots: %s is not valid JSON" % path)
		return {}
	return parsed


## oils.<name> ({} if there's no such oil).
static func oil(name: String) -> Dictionary:
	return (D.get("oils", {}) as Dictionary).get(name, {})


static func carry_max() -> int:
	return int(D.get("carry_max", 3))


static func light_anim_s() -> float:
	return maxf(float(D.get("light_anim_s", 0.6)), 0.05)


static func throw_d() -> Dictionary:
	return D.get("throw", {})


static func gravity() -> float:
	return float(throw_d().get("gravity_mps2", 9.8))


func build(p_world: Node, p_lay: Dictionary, p_player: CrawlerPlayer) -> void:
	world = p_world
	lay = p_lay
	player = p_player
	instance = self
	_bursts.clear()
	# In view: the pot in the left hand, low left (the torch is low right).
	_view = Node3D.new()
	_view.name = "PotView"
	player.camera().add_child(_view)
	_view.position = REST
	_view.visible = false
	_voice = Audio3D.make("torch", player, "PotVoice")
	_voice.position = Vector3(-0.3, 1.3, -0.3)
	# The lit wick's light: on you, over the left hand (WICK_LIGHT_AT), not
	# at the wick itself, whose clay would blow out white a few centimetres
	# from a point light.
	var W: Dictionary = D.get("wick", {})
	_wick_light = OmniLight3D.new()
	_wick_light.name = "WickLight"
	_wick_light.light_color = Torch.fire_color()
	_wick_light.omni_range = float(W.get("light_range_m", 4.0))
	_wick_light.omni_attenuation = Campfire.ATTENUATION
	_wick_light.shadow_enabled = false
	_wick_light.position = WICK_LIGHT_AT
	_wick_light.visible = false
	player.add_child(_wick_light)
	_arc = MeshInstance3D.new()
	_arc.name = "PotArc"
	_arc.top_level = true
	_arc.mesh = _im
	_arc.material_override = AimArc.material()
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc)
	burnables = burnables_of(lay)
	found_room = found_room_of(lay)
	# The found pot waits for the tomb's stone to be in the physics world
	# (its spot is tested against it).
	_place_found.call_deferred()


func _exit_tree() -> void:
	if instance == self:
		instance = null


## A new tomb (the way out's stand-in, design §EX.5; CrawlerMain): what lay
## or burnt on the old tomb's floor goes (the found pot, the fires, their
## char, a pot still in the air); what you carry and hold stays (the pack,
## the pot in your left hand, its wick as it was); the new tomb's burnables
## and its found pot.
func retomb(p_lay: Dictionary) -> void:
	lay = p_lay
	for n in get_children():
		if n != _arc:
			remove_child(n)
			NodeRelease.free_later(n)
	flying.clear()
	fires.clear()
	chars.clear()
	found = null
	_bursts.clear()
	burnables = burnables_of(lay)
	found_room = found_room_of(lay)
	_place_found.call_deferred()


# --- Carrying ------------------------------------------------------------------

## A new pot of `p_oil` (an item of the pack).
func make_pot(p_oil: String) -> Dictionary:
	_next_id += 1
	return Inventory.make("fire_pot", {"oil": p_oil, "id": _next_id})


## The pots you carry, in the strip's order.
func pots_carried() -> Array:
	var out: Array = []
	for it in player.inventory.strip:
		if it is Dictionary and str(it.get("kind", "")) == "fire_pot":
			out.append(it)
	return out


## One pot of `p_oil` onto the strip (Inventory.add puts a left-hand thing
## there), if there's room: carry_max pots, and a free place.
func give(p_oil: String) -> bool:
	if pots_carried().size() >= carry_max():
		return false
	return player.inventory.add(make_pot(p_oil))


## dev_items (F9): pots up to carry_max, of dev_items.oils in turn (both
## oils, to try them). Returns how many came.
func give_dev() -> int:
	var oils: Array = (D.get("dev_items", {}) as Dictionary).get("oils", ["tar", "light_oil", "tar"])
	var n := 0
	var i := 0
	while pots_carried().size() < carry_max() and i < carry_max() * 4 and not oils.is_empty():
		if give(str(oils[i % oils.size()])):
			n += 1
		i += 1
	if n > 0:
		GameLog.add("Dev: %d fire pot%s into the pack." % [n, "" if n == 1 else "s"], "pots")
	return n


func _remove(it: Dictionary) -> void:
	for i in player.inventory.strip.size():
		if is_same(player.inventory.strip[i], it):
			player.inventory.strip[i] = null
			return


# --- The left hand (Hands', §FB) ---------------------------------------------------

## The pot in your left hand, or {} (thrown, or gone from the strip).
func in_left() -> Dictionary:
	return left


## One step of the left hand through the pots you carry and empty (what
## Tab and the wheel do, Hands). Not while a pot is being lit or aimed.
func cycle_left(step: int) -> void:
	if state != "idle":
		return
	player.hands.cycle("left", step)
	if not left.is_empty():
		# The torch doesn't swing from this press on (hands.json clicks).
		player.torch.block_until_release()


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.ui_open or player.typing:
		return
	if event.is_action_pressed("dev_items") and world != null and bool(world.get("dev_mode")):
		give_dev()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and take_found():
		get_viewport().set_input_as_handled()


# --- Lighting, aiming, throwing ------------------------------------------------------

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _physics_process(delta: float) -> void:
	clock += delta
	if player == null:
		return
	var pot := in_left()
	var down := Input.is_action_pressed("shoot") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Bow.need_capture)
	var pressed := down and not _down
	_down = down
	if not pot.is_empty():
		# The torch doesn't swing while a pot is in the left hand (§FB,
		# hands.json clicks.left_with_pot).
		player.torch.block_until_release()
	var able := not pot.is_empty() and not player.dead and not player.ui_open and not player.typing
	match state:
		"idle":
			# No lit torch in hand: nothing happens (§FA.3, §AW).
			if pressed and able and player.torch.lit():
				_set_state("lighting")
		"lighting":
			if not down or not able or not player.torch.lit():
				_set_state("idle")
			else:
				state_t += delta
				if state_t >= light_anim_s():
					_catch(pot)
		"aiming":
			state_t += delta
			fuse_left = maxf(fuse_left - delta, 0.0)
			if pot.is_empty():
				_set_state("idle")
			elif fuse_left <= 0.0 and cooks_off():
				_cook_off(pot)
			elif not down:
				if not player.ui_open:
					_throw(pot)
			else:
				charge = minf(charge + delta / maxf(float(throw_d().get("charge_s", 0.8)), 0.05), 1.0)


## The wick catches off the torch: lit, the fuse running, a flare.
func _catch(pot: Dictionary) -> void:
	pot["lit"] = true
	_set_state("aiming")
	charge = 0.0
	fuse_left = float(D.get("fuse_s", 3.0))
	_caught_at = clock
	_say("fire_snap", randf_range(1.2, 1.4))


## A fuse spent in your hand bursts there (cook_off_in_hand true; null or
## false: it waits for the impact, as first built).
static func cooks_off() -> bool:
	var v: Variant = D.get("cook_off_in_hand", null)
	return typeof(v) == TYPE_BOOL and bool(v)


## The fuse ran out in your hand: the pot bursts where your hand is, gone
## from the pack, and that is one hit.
func _cook_off(pot: Dictionary) -> void:
	var at := hand_point()
	var p_oil := str(pot.get("oil", "tar"))
	_remove(pot)
	left = {}
	_set_state("idle")
	charge = 0.0
	cook_offs += 1
	burst(at, p_oil, null, Vector3.UP, true)


## Where the pot leaves your hand (scene): the pot in view's middle, or
## short of a wall between your eye and it.
func hand_point() -> Vector3:
	var p := _view.global_transform * Vector3(0.0, 0.07, 0.0)
	var eye := player.camera().global_position
	var q := PhysicsRayQueryParameters3D.create(eye, p)
	q.exclude = [player.get_rid()]
	q.collision_mask = PropCollision.WORLD_LAYER
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return (hit.position as Vector3) + ((eye - p).normalized() * 0.05)
	return p


## The speed that lobs a pot `range_m` over level ground `h` m below the
## hand, thrown `elev` radians above level, under gravity `g`.
static func launch_speed(range_m: float, h: float, elev: float, g: float) -> float:
	var c := cos(elev)
	var denom := 2.0 * c * c * (h + range_m * tan(elev))
	return sqrt(g * range_m * range_m / maxf(denom, 0.001))


## The throw now: [from, velocity]. Looking level, it lands charge's range
## (throw.min_m..max_m) out on level ground; looking down, shorter; up,
## higher and longer.
func launch() -> Array:
	var T := throw_d()
	var from := hand_point()
	var h := maxf(from.y - player.global_position.y, 0.2)
	var r := lerpf(float(T.get("min_m", 4.0)), float(T.get("max_m", 14.0)), charge)
	var lob := deg_to_rad(float(T.get("lob_deg", 18.0)))
	var v := launch_speed(r, h, lob, gravity())
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 1e-4 else Vector3.FORWARD
	var elev := clampf(player._pitch + lob, deg_to_rad(-70.0), deg_to_rad(80.0))
	return [from, (fwd * cos(elev) + Vector3.UP * sin(elev)) * v]


func _throw(pot: Dictionary) -> void:
	var l := launch()
	_remove(pot)
	left = {}
	var tp := ThrownPot.new()
	add_child(tp)
	var ex: Array[RID] = [player.get_rid()]
	tp.launch(self, l[0], l[1], str(pot.get("oil", "tar")), fuse_left if fuse_left > 0.0 else -1.0, ex)
	flying.append(tp)
	throws += 1
	last_launch = [l[0], l[1], charge]
	_set_state("idle")
	charge = 0.0
	# A throw is as loud as a swing (Torch.swing).
	player.make_noise(Fists.NOISE * 0.5)
	_say("whip", randf_range(0.6, 0.7))


## A pot in the air has burst (ThrownPot): the last one's {"pos", "target",
## "why", "life" (s in the air), "oil"} (checks).
var last_landing := {}


func landed(tp: ThrownPot) -> void:
	flying.erase(tp)
	last_landing = tp.burst_at.duplicate()
	last_landing["life"] = tp.life
	last_landing["oil"] = tp.oil


func _say(kind: String, pitch: float) -> void:
	if _voice == null:
		return
	_voice.stream = SoundSynth.stream(kind, randi())
	_voice.pitch_scale = pitch
	Audio3D.play(_voice)


# --- The burst -------------------------------------------------------------------

## A pot of `p_oil` bursts at `at` (scene), on `hit` if it met a fire
## target: the flash, the burst's fire on everything within splash_m, tar's
## stuck fire and its patch on the floor under it, what catches, the
## crosshair's X if it caught a creature, and the sound of it, heard
## within burst_heard_m (§DF). Within hurts_you_m of you it is one hit, as
## it is `in_hand` (a cook-off).
func burst(at: Vector3, p_oil: String, hit: Node3D, _normal: Vector3, in_hand := false) -> void:
	var o := oil(p_oil)
	fires.append(PotFire.flash(self, at, p_oil))
	var splash := float(o.get("splash_m", 1.5))
	var caught := false
	for t in targets(get_tree()):
		if t != hit and distance_to(t, at) > splash:
			continue
		if burn(t, float(o.get("burst", 1.0)), p_oil, at):
			caught = true
		if bool(o.get("sticks", false)) and float(o.get("burn_s", 0.0)) > 0.0 and not is_boss(t) and not burnt_out(t):
			stick(t, p_oil)
	if caught:
		Reticle.hit()
	if in_hand:
		_hurt_you(at, "fire:pot_in_hand")
	elif burst_hurts_you(at):
		_hurt_you(at, "fire:pot")
	if float(o.get("floor_patch_s", 0.0)) > 0.0 and float(o.get("patch_radius_m", 0.0)) > 0.0:
		var fl := floor_under(at)
		if fl.is_finite():
			fires.append(PotFire.patch(self, fl, p_oil))
	ignite_near(at, splash)
	var heard := float((D.get("gives_away", {}) as Dictionary).get("burst_heard_m", 40.0))
	_bursts.append({"id": _next_burst, "pos": at, "heard_m": heard, "oil": p_oil})
	_next_burst += 1
	if _bursts.size() > 32:
		_bursts.pop_front()
	NoiseEvents.emit(at, heard)
	GameLog.add("The pot burst and the tar burns on." if p_oil == "tar" else "The pot burst in a sheet of flame.", "pots")


## Your own burst at `at` reaches you (hurts_you): within hurts_you_m of
## your body (your capsule, feet to eye, 0.35 m round), with no stone
## between it and the nearest of you.
func burst_hurts_you(at: Vector3) -> bool:
	var v: Variant = D.get("hurts_you", false)
	if typeof(v) != TYPE_BOOL or not bool(v) or player == null or player.dead:
		return false
	var near := nearest_of_you(at)
	if at.distance_to(near) - YOU_R > float(D.get("hurts_you_m", 1.0)):
		return false
	var dir := (near - at).normalized()
	var q := PhysicsRayQueryParameters3D.create(at + dir * 0.05, near)
	q.exclude = [player.get_rid()]
	q.collision_mask = PropCollision.WORLD_LAYER
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Your body's radius (PlanetPlayer's capsule).
const YOU_R := 0.35


## The point of your body's middle line (feet + YOU_R up to your eye)
## nearest `at` (scene).
func nearest_of_you(at: Vector3) -> Vector3:
	var a := player.global_position + Vector3.UP * YOU_R
	var b := player.camera().global_position
	if b.y < a.y:
		b = a
	var ab := b - a
	var k := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return a + ab * k


## One hit from your own pot (Harm counts it; `cause` its death cause).
func _hurt_you(at: Vector3, cause: String) -> void:
	if player == null or player.dead:
		return
	self_hits += 1
	player.death_cause = cause
	player.take_hit(1.0, at)


## The floor under `at` (scene; INF if none within 4 m).
func floor_under(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.25, at - Vector3.UP * 4.0)
	q.exclude = [player.get_rid()]
	q.collision_mask = PropCollision.WORLD_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.5:
		return Vector3.INF
	return hit.position


## Tar stuck to `t`, burning on it (a fresh coat burns the full burn_s
## again, it doesn't stack).
func stick(t: Node3D, p_oil: String) -> void:
	var old: Variant = t.get_meta("pot_stuck") if t.has_meta("pot_stuck") else null
	if is_instance_valid(old) and old is PotFire and not (old as PotFire).done:
		(old as PotFire).t = 0.0
		return
	var f := PotFire.stuck(self, t, p_oil)
	t.set_meta("pot_stuck", f)
	fires.append(f)


## A fire has gone out (PotFire).
func fire_ended(f: PotFire) -> void:
	fires.erase(f)


# --- Fire targets ------------------------------------------------------------------

## The fire targets in play (TARGET_GROUP), not yet burnt out.
static func targets(tree: SceneTree) -> Array:
	var out: Array = []
	for n in tree.get_nodes_in_group(TARGET_GROUP):
		var t := n as Node3D
		if t != null and is_instance_valid(t) and t.is_inside_tree() and not burnt_out(t):
			out.append(t)
	return out


static func center_of(t: Node3D) -> Vector3:
	if t.has_method("fire_center"):
		return t.fire_center()
	return t.global_position + Vector3.UP * float(t.get_meta("fire_center_y", 0.9))


static func radius_of(t: Node3D) -> float:
	return float(t.get_meta("fire_radius_m", 0.45))


## How far `p` is from `t`'s body (m, under 0 inside): its own
## fire_distance() (a long body: the snake's length), else a ball of
## fire_radius_m round its fire_center.
static func distance_to(t: Node3D, p: Vector3) -> float:
	if t.has_method("fire_distance"):
		return float(t.call("fire_distance", p))
	return center_of(t).distance_to(p) - radius_of(t)


## A boss: driven off, never burnt down (§FA.4, vs_boss.kills false).
static func is_boss(t: Node3D) -> bool:
	return t.has_method("drive_off") and not bool((D.get("vs_boss", {}) as Dictionary).get("kills", false))


static func burnt_out(t: Node3D) -> bool:
	return bool(t.get_meta("burnt_out", false))


## Its residents.json key.
static func creature_of(t: Node3D) -> String:
	if "fire_creature" in t:
		return str(t.get("fire_creature"))
	return str(t.get_meta("creature", ""))


## How much more (or less) `p_oil` does to `t` (residents.json
## creatures.<name>.oil_scale, §FA.3: "some oils do more to certain
## creatures"); 1 for anything not listed.
static func oil_scale(t: Node3D, p_oil: String) -> float:
	var c: Dictionary = (RES.get("creatures", {}) as Dictionary).get(creature_of(t), {})
	return float((c.get("oil_scale", {}) as Dictionary).get(p_oil, 1.0))


## Fire on `t`: `amount` (fire_hp units) times its oil_scale off its
## fire_hp, and at 0 it burns out and is gone; a boss is driven off
## instead, never killed (§FA.4). True when the fire reached a creature.
func burn(t: Node3D, amount: float, p_oil: String, from: Vector3) -> bool:
	if t == null or not is_instance_valid(t) or burnt_out(t):
		return false
	if is_boss(t):
		drive_off(t, from)
		return true
	if not "fire_hp" in t:
		return false
	var a := amount * oil_scale(t, p_oil)
	t.set("fire_hp", maxf(float(t.get("fire_hp")) - a, 0.0))
	t.set_meta("fire_taken", float(t.get_meta("fire_taken", 0.0)) + a)
	if float(t.get("fire_hp")) <= 0.0:
		_burn_out(t)
	elif t.has_method("fire_hit"):
		t.call("fire_hit", a, from)
	return true


## Fire on what stands in a burning patch round `at` (`radius` m on the
## floor, a metre up).
func burn_what_stands_in(at: Vector3, radius: float, amount: float, p_oil: String, _src: PotFire) -> void:
	for t in targets(get_tree()):
		var inside := false
		if t.has_method("fire_distance"):
			inside = float(t.call("fire_distance", at)) <= radius
		else:
			var c := center_of(t)
			inside = Vector2(c.x - at.x, c.z - at.z).length() <= radius + radius_of(t) * 0.5 and absf(t.global_position.y - at.y) < 1.0
		if inside:
			burn(t, amount, p_oil, at)


## A boss hit by a pot leaves for the dark for vs_boss.drives_off_s (once:
## it's already going).
func drive_off(t: Node3D, from: Vector3) -> void:
	if clock < float(t.get_meta("pot_driven_until", -1.0)):
		return
	var s := float((D.get("vs_boss", {}) as Dictionary).get("drives_off_s", 30.0))
	t.set_meta("pot_driven_until", clock + s)
	t.set_meta("pot_drives", int(t.get_meta("pot_drives", 0)) + 1)
	t.call("drive_off", s, from)


func _burn_out(t: Node3D) -> void:
	t.set_meta("burnt_out", true)
	# The last flare as it goes (§FA.3: it burns out and is gone).
	fires.append(PotFire.flash(self, center_of(t), "tar", 0.7, false))
	if t.has_method("burn_out"):
		t.call("burn_out")
	else:
		t.queue_free()


# --- It gives you away ---------------------------------------------------------------

## The wicks burning now: the pot lit in your hand and every pot in the
## air, each a flare seen within gives_away.flare_seen_m:
## [{"pos", "seen_m", "from": "hand" / "air"}].
static func flares() -> Array:
	var out: Array = []
	if instance == null or not is_instance_valid(instance):
		return out
	var seen := float((D.get("gives_away", {}) as Dictionary).get("flare_seen_m", 25.0))
	if instance.state == "aiming" and instance._wick != null:
		out.append({"pos": instance._wick.global_position, "seen_m": seen, "from": "hand"})
	for tp in instance.flying:
		if is_instance_valid(tp) and (tp as ThrownPot).flying:
			out.append({"pos": (tp as ThrownPot).wick_point(), "seen_m": seen, "from": "air"})
	return out


## The nearest burning wick a creature whose eyes are at `eye` can see:
## within its seen_m, nothing of the tomb's stone between ({} if none).
## `exclude`: the looker's own bodies.
static func flare_seen_from(eye: Vector3, space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> Dictionary:
	var best := {}
	var best_d := INF
	for f in flares():
		var p: Vector3 = f.pos
		var d := eye.distance_to(p)
		if d > float(f.seen_m) or d >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, p)
		var ex := exclude.duplicate()
		if instance.player != null:
			ex.append(instance.player.get_rid())
		q.exclude = ex
		q.collision_mask = PropCollision.WORLD_LAYER
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.15:
			best = f
			best_d = d
	return best


## The bursts newer than `last_id`: [{"id", "pos", "heard_m", "oil"}],
## oldest first. A creature hears one if it is within heard_m of it.
static func bursts_since(last_id: int) -> Array:
	var out: Array = []
	for b in _bursts:
		if int(b.id) > last_id:
			out.append(b)
	return out


# --- Fire spreads ----------------------------------------------------------------

## What burns in a tomb (spreads_to): the hearth room's reed mat (rushes)
## and the bedroll by the wall (cloth), where TombBuild lays them.
## {"tag", "pos", "radius", "size", "yaw", "state" ("", "burning", "burnt")}.
static func burnables_of(p_lay: Dictionary) -> Array:
	var out: Array = []
	var w: Array = p_lay.get("wake", [])
	if w.size() == 2:
		out.append({"tag": "rushes", "what": "reed mat", "pos": (w[0] as Vector3) + Vector3(0.0, 0.03, 0.0), "radius": 0.9, "size": Vector3(0.9, 0.05, 1.9), "yaw": float(w[1]), "state": ""})
	var r: Array = p_lay.get("rescuer", [])
	if r.size() == 2:
		var rp: Vector3 = r[0]
		var back := Vector3(rp.x, 0.0, rp.z).normalized() * 1.3
		out.append({"tag": "cloth", "what": "bedroll", "pos": rp + back + Vector3(0.8, 0.12, 0.2), "radius": 0.7, "size": Vector3(0.5, 0.24, 1.4), "yaw": float(r[1]) + 0.4, "state": ""})
	return out


## Something else that burns (a web, a wooden run: the residents' and
## worlds' passes add theirs). `size` and `yaw` shape its char.
func register_burnable(tag: String, pos: Vector3, radius: float, size := Vector3.ZERO, yaw := 0.0) -> Dictionary:
	var b := {"tag": tag, "what": tag, "pos": pos, "radius": radius, "size": size if size != Vector3.ZERO else Vector3(radius * 2.0, 0.05, radius * 2.0), "yaw": yaw, "state": ""}
	burnables.append(b)
	return b


## Everything that burns within `radius` of `pos` catches (§FA.3: fire
## spreads to what burns).
func ignite_near(pos: Vector3, radius: float) -> void:
	var tags: Array = D.get("spreads_to", [])
	for b in burnables:
		if str(b.state) != "" or not str(b.tag) in tags:
			continue
		if pos.distance_to(b.pos) <= radius + float(b.radius):
			b["state"] = "burning"
			fires.append(PotFire.spread(self, b))


## Char where fire burnt out on the stone (`r` round `at`), or over the
## thing that burnt (`b`).
func char_mark(at: Vector3, r: float, b: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Char"
	mi.mesh = _char_mesh()
	mi.material_override = _char_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if b.is_empty():
		mi.global_position = at + Vector3.UP * 0.012
		mi.rotation.y = randf() * TAU
		mi.scale = Vector3(r, 1.0, r)
	else:
		var sz: Vector3 = b.size
		mi.global_position = (b.pos as Vector3) + Vector3.UP * (sz.y * 0.5 + 0.006)
		mi.rotation.y = float(b.yaw)
		mi.scale = Vector3(sz.x * 0.62, 1.0, sz.z * 0.62)
	chars.append(mi)


static var _char_m: ArrayMesh
static var _char_mat: StandardMaterial3D


## A unit disc, black in the middle fading to nothing at its rim.
static func _char_mesh() -> ArrayMesh:
	if _char_m != null:
		return _char_m
	var c := Color(str((D.get("look", {}) as Dictionary).get("char_color", "#0b0c14")))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 14
	for i in N:
		var a0 := TAU * i / N
		var a1 := TAU * (i + 1) / N
		for v in [[Vector3.ZERO, 0.85], [Vector3(cos(a1), 0.0, sin(a1)), 0.0], [Vector3(cos(a0), 0.0, sin(a0)), 0.0]]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(c.r, c.g, c.b, float(v[1])))
			st.add_vertex(v[0])
	_char_m = st.commit()
	return _char_m


## Matte and lit like the stone it lies on: no shine.
static func _char_material() -> StandardMaterial3D:
	if _char_mat == null:
		_char_mat = StandardMaterial3D.new()
		_char_mat.vertex_color_use_as_albedo = true
		_char_mat.albedo_color = Color.WHITE
		_char_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_char_mat.roughness = 1.0
		_char_mat.metallic = 0.0
		_char_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_char_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _char_mat


# --- The found pot ---------------------------------------------------------------

## The side room the found pot lies in (fire_pots.json found): a room off
## the spine, never the hearth room or the heart, a dead end where there
## is one, picked by the tomb's seed; -1 if the tomb has none. The spine is
## prompt 46's (lay.spine) once it's in; until then the way through the
## doors from the hearth room to the heart, which the spine will follow.
static func found_room_of(p_lay: Dictionary) -> int:
	var spine := spine_of(p_lay)
	var rooms: Array = []
	var ends: Array = []
	for pc in p_lay.get("pieces", []):
		if str(pc.kind) != "room":
			continue
		var rk := str(pc.get("room_kind", ""))
		if rk == "hearth" or rk == "heart" or int(pc.id) in spine:
			continue
		rooms.append(int(pc.id))
		if (pc.doors as Array).size() == 1:
			ends.append(int(pc.id))
	var pool := ends if not ends.is_empty() else rooms
	if pool.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(p_lay.get("seed", 0)), "fire_pot_found"])
	return int(pool[rng.randi_range(0, pool.size() - 1)])


## The spine's pieces: lay.spine (ids) or pieces marked spine/on_spine
## when prompt 46 is in; else the way through the doors from the hearth
## room (piece 0) to the heart.
static func spine_of(p_lay: Dictionary) -> Array:
	var out: Array = []
	var sp: Variant = p_lay.get("spine", null)
	if sp is Array:
		for v in sp:
			if v is int or v is float:
				out.append(int(v))
			elif v is Dictionary and (v as Dictionary).has("id"):
				out.append(int(v.id))
	for pc in p_lay.get("pieces", []):
		if bool(pc.get("spine", false)) or bool(pc.get("on_spine", false)):
			if not int(pc.id) in out:
				out.append(int(pc.id))
	if not out.is_empty() or not p_lay.has("heart"):
		return out
	# The way from the hearth room to the heart (breadth first through the
	# doors).
	var goal := int(p_lay.heart)
	var prev := {0: -1}
	var queue: Array = [0]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if id == goal:
			break
		for di in p_lay.pieces[id].doors:
			var d: Dictionary = p_lay.doors[di]
			for o in [int(d.a), int(d.b)]:
				if not prev.has(o):
					prev[o] = id
					queue.append(o)
	var at := goal
	while prev.has(at) and at != -1:
		out.append(at)
		at = int(prev[at])
	return out


## Lay the found pot on the floor of its room: the first clear spot of a
## few by its walls (the end wall's middle first), tested against the
## tomb's stone and away from the room's fire and its airways.
func _place_found() -> void:
	if found_room < 0 or not is_inside_tree():
		return
	# The tomb's collision is in the physics world after a step.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pc: Dictionary = lay.pieces[found_room]
	var spot := _found_spot(pc)
	if not spot.is_finite():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "fire_pot_oil"])
	var F: Dictionary = D.get("found", {})
	var weights: Dictionary = F.get("oils", {"tar": 1, "light_oil": 1})
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	var pick := "tar"
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			pick = str(k)
			break
	found = Node3D.new()
	found.name = "FoundPot"
	found.set_meta("oil", pick)
	add_child(found)
	found.add_child(PotMesh.node(pick))
	found.global_position = spot
	found.rotation.y = rng.randf() * TAU


func _found_spot(pc: Dictionary) -> Vector3:
	var length := float(pc.len)
	var half := float(pc.half)
	var sides := {}
	for di in pc.doors:
		sides[str(TombKit.door_side(pc, lay.doors[di])[0])] = true
	var tries: Array = []
	if not sides.has("end"):
		tries.append_array([[length - 0.7, 0.0], [length - 0.7, half * 0.45], [length - 0.7, -half * 0.45]])
	for sd: float in [1.0, -1.0]:
		if not sides.has("left" if sd > 0.0 else "right"):
			tries.append([length * 0.5, sd * (half - 0.6)])
			tries.append([length * 0.3, sd * (half - 0.6)])
	tries.append_array([[length - 0.9, half * 0.5], [length - 0.9, -half * 0.5], [length * 0.75, 0.0], [length * 0.25, half * 0.5], [length * 0.25, -half * 0.5]])
	var space := get_world_3d().direct_space_state
	for tr in tries:
		var q2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(tr[0]) + Delves.perp(pc.dir) * float(tr[1])
		var y := Delves.floor_of(pc, float(tr[0]))
		var p := Vector3(q2.x, y, q2.y)
		var near := false
		for h in lay.holders:
			if (h.pos as Vector3).distance_to(p) < 1.3:
				near = true
		for a in lay.airways:
			if Vector2((a.pos as Vector3).x - p.x, (a.pos as Vector3).z - p.z).length() < 1.2:
				near = true
		# Clear of the boss's hole and the stone broken round it (queue 49).
		var lair: Dictionary = lay.get("lair", {})
		if not lair.is_empty() and Vector2((lair.pos as Vector3).x - p.x, (lair.pos as Vector3).z - p.z).length() < float(lair.r) + 1.5:
			near = true
		if near:
			continue
		var down := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.4, p - Vector3.UP * 0.5)
		down.collision_mask = PropCollision.WORLD_LAYER
		down.exclude = [player.get_rid()]
		var hit := space.intersect_ray(down)
		if hit.is_empty() or absf((hit.position as Vector3).y - y) > 0.06:
			continue
		var ball := SphereShape3D.new()
		ball.radius = 0.24
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = ball
		sq.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.32)
		sq.collision_mask = PropCollision.WORLD_LAYER
		sq.exclude = [player.get_rid()]
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		return hit.position
	return Vector3.INF


## Right click by the found pot: onto the strip, if it has room.
func take_found() -> bool:
	if found == null or not is_instance_valid(found):
		return false
	if player.global_position.distance_to(found.global_position) > CrawlerPlayer.REACH_M + 0.4:
		return false
	if not give(str(found.get_meta("oil", "tar"))):
		return false
	found.queue_free()
	found = null
	GameLog.add("Took a fire pot.", "pots")
	_say("scuff", 1.4)
	return true


# --- In view ---------------------------------------------------------------------

## The lit wick's tip in view (scene), or INF.
func wick_point() -> Vector3:
	return _wick.global_position if _wick != null and _wick.visible else Vector3.INF


func _process(_delta: float) -> void:
	if player == null:
		return
	var pot := in_left()
	var show := not pot.is_empty() and player.first_person
	_view.visible = show
	if show and (_view_pot == null or _view_oil != str(pot.get("oil", "tar"))):
		_dress_view(str(pot.get("oil", "tar")))
	var lit := state == "aiming"
	if _wick != null:
		_wick.visible = show and lit
	_wick_light.visible = show and lit
	if show:
		_pose()
		if lit:
			_wick_glow()
	_update_arc()


## The pot in view for `p_oil` (its plug and drips), its wick's flame and
## light (off until it catches).
func _dress_view(p_oil: String) -> void:
	for c in _view.get_children():
		c.queue_free()
	_view_oil = p_oil
	_view_pot = PotMesh.node(p_oil)
	_view.add_child(_view_pot)
	var W: Dictionary = D.get("wick", {})
	_wick = Torch.flame_node(float(W.get("flame_scale", 0.12)))
	_wick.name = "Wick"
	_wick.position = PotMesh.wick_tip()
	_view.add_child(_wick)
	_wick.visible = false
	_wick_light.visible = false
	Bow._no_shadow(_view)


## The hands: lighting, they come together (the pot to the middle, the
## torch leaning over it until its head meets the wick); aiming, the pot
## draws back with the charge and the torch goes back to its place.
func _pose() -> void:
	var tv: Node3D = player.torch._view if player.torch != null else null
	match state:
		"lighting":
			var k := smoothstep(0.0, 1.0, state_t / light_anim_s())
			_view.position = REST.lerp(MEET, k)
			_view.rotation = Vector3(0.0, 0.0, -0.25 * k)
			if tv != null:
				tv.position = TORCH_REST.lerp(_torch_meet(), k)
				tv.rotation = Vector3(0.0, 0.0, TORCH_LEAN * k)
		"aiming":
			var back := smoothstep(0.0, 1.0, charge)
			_view.position = MEET.lerp(WIND, back)
			_view.rotation = Vector3(0.35 * back, 0.0, -0.25 * (1.0 - back))
			# The torch goes back to its place over a quarter second.
			var k2 := 1.0 - smoothstep(0.0, 0.25, state_t)
			if tv != null and k2 > 0.0:
				tv.position = TORCH_REST.lerp(_torch_meet(), k2)
				tv.rotation = Vector3(0.0, 0.0, TORCH_LEAN * k2)
		_:
			_view.position = REST
			_view.rotation = Vector3.ZERO


## Where the torch's view stands with its head at the wick (camera space).
func _torch_meet() -> Vector3:
	var head := Vector3(0.05, 0.17, -0.06)
	var ef: Node3D = player.torch._view_flame
	if ef != null:
		# The pitch head's coal at the top of its wrap (§EZ.2, its origin is
		# the wrap's foot); the burnt end's glowing tip.
		head = ef.transform * Vector3(0.0, PitchTorch.length_m(), 0.0) if ef.has_meta("pitch_head") else ef.position + Vector3(0.0, 0.03, 0.0)
	var wick := MEET + Basis(Vector3(0, 0, 1), -0.25) * PotMesh.wick_tip()
	return wick + Vector3(0.012, 0.008, 0.0) - Basis(Vector3(0, 0, 1), TORCH_LEAN) * head


## The lit wick: its light flares as it catches and settles to a small
## steady flame (wick: energy, flare_energy over flare_s), and it smokes.
func _wick_glow() -> void:
	var W: Dictionary = D.get("wick", {})
	var since := clock - _caught_at
	var e := float(W.get("energy", 1.0))
	var flare := float(W.get("flare_energy", 3.0))
	_wick_light.light_energy = e + (flare - e) * exp(-since / maxf(float(W.get("flare_s", 0.35)), 0.05))
	Smoke.tick_flame(_wick, _wick.global_position, Vector3.UP, float(W.get("flame_scale", 0.12)), "flames", -player.velocity)


## The faint dotted arc of the lob while aiming (throw.arc_shown; AimArc's
## look): the throw's own flight, stepped to the first stone it meets.
func _update_arc() -> void:
	_im.clear_surfaces()
	if state != "aiming":
		arc_end = Vector3.INF
		return
	var l := launch()
	var pos: Vector3 = l[0]
	var vel: Vector3 = l[1]
	var space := get_world_3d().direct_space_state
	var dots := PackedVector3Array()
	var step := 1.0 / 30.0
	var g := gravity()
	arc_end = Vector3.INF
	for k in 90:
		vel.y -= g * step
		var nxt := pos + vel * step
		var q := PhysicsRayQueryParameters3D.create(pos, nxt)
		q.exclude = [player.get_rid()]
		q.collision_mask = PropCollision.WORLD_LAYER
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			arc_end = hit.position
			dots.append(hit.position)
			break
		pos = nxt
		if k >= 2 and k % 2 == 0:
			dots.append(pos)
	if not bool(throw_d().get("arc_shown", true)) or dots.size() < 2:
		return
	_arc.global_transform = Transform3D.IDENTITY
	_im.surface_begin(Mesh.PRIMITIVE_POINTS)
	for i in dots.size():
		var fade := 1.0 - float(i) / dots.size()
		_im.surface_set_color(Color(AimArc.COLOR, 0.12 + 0.3 * fade))
		_im.surface_add_vertex(dots[i])
	_im.surface_end()
