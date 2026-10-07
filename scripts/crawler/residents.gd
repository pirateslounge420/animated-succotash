class_name Residents
extends Node3D
## What lives in the tomb's dark (design 6 Oct §FE; data/residents.json):
## the framework every resident runs on, and its first resident, the
## tomb's skeletons (§FE.2), with hiding (§FC.2). One Resident per resting
## place the tomb kit laid (TombKit residents), and what they share:
##
##   sense()        what a resident senses of you, by its notice row: you
##                  yourself, seen within sees_you_m only with a clear
##                  line from its eyes to your head (so crouched behind a
##                  lidded coffin you are hidden; no hide button, no
##                  prompt); your lit torch's flame, or the stone it lights
##                  round you (stealth.json hide: glow_samples rays out to
##                  glow_reach_m), seen within sees_flame_m with a clear
##                  line (a lit torch gives you away round cover, §DF);
##                  what you sound like, heard within hears_step_m scaled
##                  by your noise (a walk; a sprint, or a swing that lands
##                  on a creature, torch.json stagger.noise, three times as
##                  far; a sneak under a third; standing still, nothing);
##                  and within TOUCH_M, always;
##   hidden_from()  you are out of its sight only because of low cover
##                  (§FC.2: crouched behind it; standing, it would see you):
##                  what its Pursuit's hide rule reads;
##   nav            the floor they walk (TombNav, built once the tomb's
##                  stone is in the physics world);
##   bake()         their sheets (SkeletonRig, ResidentSprite: §ET.8).
##
## Each resident's strike is prompt 57's (CreatureStrike: the wind-up and
## its tell, the stagger, one hit through Harm) and its chase prompt 56's
## (Pursuit: Harm counts it as pursuing you, so you heal only once nothing
## hunts you, §FD). While "Good night" closes the frame they wait; when you
## wake at the hearth every one that was after you gives you up and goes
## home (player_woke).

static var D: Dictionary = Tuning.table("residents")
static var HIDE: Dictionary = Tuning.table("stealth").get("hide", {})
## Checks that aren't about the residents keep them asleep (crawler_check,
## crawler_frames).
static var stay_asleep := false
## The walk's noise_level (CrawlerPlayer.moving_state): hears_step_m is
## how far a walking step carries.
const WALK_NOISE := 0.35
## Standing still you are heard only louder than this: a loud moment (a
## swing that lands, CrawlerPlayer.make_noise), never your breath.
const STILL_HEARD := 0.5
## Closer than this a resident knows you are there, seen or not (m).
const TOUCH_M := 1.0
## The body a resident walks with, for its paths (m round): a sprite
## with no body, kept off the stone.
const NAV_RADIUS := 0.25

var lay: Dictionary
var player: CrawlerPlayer
var nav: TombNav
var all: Array[Resident] = []
## Points on the stone your torch lights (sense()).
var glow: Array = []
var baked := false
var _glow_t := 0.0


func build(p_lay: Dictionary, p_player: CrawlerPlayer) -> void:
	lay = p_lay
	player = p_player
	for r in lay.get("residents", []):
		var res := Resident.new()
		add_child(res)
		res.setup(self, r)
		all.append(res)


## The floor's grid: call once the tomb's stone is in the physics world.
## A resting place's way out that something stands on (an urn, a lid) moves
## to the nearest open floor.
func build_nav() -> void:
	var ex: Array[RID] = [player.get_rid()]
	nav = TombNav.build(lay, get_world_3d().direct_space_state, NAV_RADIUS, ex)
	for r in all:
		var out: Vector3 = r.place.out
		var c := nav.cell_of(out)
		if not nav.is_open(c):
			var near := nav.nearest_open(c, 4)
			if near.x >= 0:
				var p := nav.point_of(near)
				r.place["out"] = Vector3(p.x, p.y, p.z)


## Bake each kind's sheet (§ET.8) under `host`, and show it.
func bake(host: Node) -> void:
	var kinds := {}
	for r in all:
		kinds[r.kind] = true
	for k in kinds:
		if k != "skeleton":
			continue
		var sp: Dictionary = creature(k).get("sprite", {})
		var h := float(sp.get("height_m", 1.68))
		var px := int(sp.get("px", 112))
		var aspect := 0.9
		var rig := SkeletonRig.build(h)
		var sheet: Image = await ResidentSprite.bake_poses(host, rig, h, px, aspect, SkeletonRig.POSES.size(), func(b: Node3D, f: int) -> void: (b as SkeletonRig).pose(SkeletonRig.POSES[f]))
		for r in all:
			if r.kind == k:
				r.show_sheet(sheet, h, SkeletonRig.POSES.size(), aspect)
	baked = true


## residents.json creatures.<kind>.
func creature(kind: String) -> Dictionary:
	return (D.get("creatures", {}) as Dictionary).get(kind, {})


## Everything waits while "Good night" plays.
func paused() -> bool:
	return player == null or player.dead or (Harm.instance != null and Harm.instance.taking)


func torch_lit() -> bool:
	return player.torch.lit()


## Is the line from `a` to `b` clear of the tomb's stone (and you)?
func clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, PropCollision.WORLD_LAYER)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Does `r`, at rest, wake (you within its wakes_m, a clear line from its
## head to yours)?
func can_wake(r: Resident) -> bool:
	if stay_asleep or paused():
		return false
	var head := player.eye_position()
	var e: Vector3 = r.place.eye
	return e.distance_to(head) <= float(r.def.get("wakes_m", 3.0)) and clear_line(e, head)


## What `r` senses of you now: "touch", "sight", "flame", "glow",
## "hearing" or "". A fire pot's lit wick is your flame too, and its burst
## is heard (§FA.3, FirePots).
func sense(r: Resident) -> String:
	if paused():
		return ""
	var burst := r.hears_burst()
	var head := player.eye_position()
	var e := r.eye()
	var dist := e.distance_to(head)
	if dist <= TOUCH_M:
		return "touch"
	var n := r.notice()
	# You yourself: only along a clear line; low cover means nothing to one
	# that finds you behind it (gives_up.hide false).
	if dist <= float(n.get("sees_you_m", 0.0)) and (clear_line(e, head) or (not bool(r.gives_up().get("hide", true)) and hidden_from(r))):
		return "sight"
	# Your light (§DF), round cover too.
	if torch_lit() and bool(HIDE.get("lit_torch_gives_away", true)):
		var sf := float(n.get("sees_flame_m", 0.0))
		var fl := player.torch.flame_position()
		if e.distance_to(fl) <= sf and clear_line(e, fl):
			return "flame"
		for g in glow:
			if e.distance_to(g) <= sf and clear_line(e, g):
				return "glow"
	# A fire pot's lit wick, in your hand or in the air: your flame too, out
	# to fire_pots.json gives_away.flare_seen_m, even with the torch out.
	if not FirePots.flare_seen_from(e, get_world_3d().direct_space_state).is_empty():
		return "flame"
	# What you sound like: your steps by how loud they are, and a loud
	# moment (a swing that lands) even standing still.
	var hs := float(n.get("hears_step_m", 0.0))
	var heard := player.anim_state in ["walk", "sprint", "crouch_walk"] or player.noise_level > STILL_HEARD
	if heard and dist <= hs * player.noise_level / WALK_NOISE:
		return "hearing"
	# A fire pot's burst within its burst_heard_m gives you away.
	if burst:
		return "hearing"
	return ""


## You are out of `r`'s sight only because of low cover (§FC.2): within
## its sees_you_m, crouched, the line from its eyes to your head blocked
## and the one to where your head would be standing clear.
func hidden_from(r: Resident) -> bool:
	if not player.crouching or paused():
		return false
	var head := player.eye_position()
	var e := r.eye()
	if e.distance_to(head) > float(r.notice().get("sees_you_m", 0.0)) or clear_line(e, head):
		return false
	return clear_line(e, player.global_position + Vector3(0.0, PlanetPlayer.EYE_Y, 0.0))


func _physics_process(delta: float) -> void:
	_glow_t -= delta
	if _glow_t <= 0.0:
		_glow_t = float(HIDE.get("glow_every_s", 0.2))
		update_glow()


## The stone your lit torch lights (stealth.json hide): glow_samples rays
## out from the flame to glow_reach_m, a point a little off each surface
## they meet. Only while a resident is up to see it.
func update_glow() -> void:
	glow.clear()
	if player == null or not torch_lit():
		return
	var any := false
	for r in all:
		if r.awake():
			any = true
			break
	if not any:
		return
	var fl := player.torch.flame_position()
	var reach := float(HIDE.get("glow_reach_m", 4.0))
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = PropCollision.WORLD_LAYER
	q.exclude = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	var dirs := glow_dirs()
	for i in mini(int(HIDE.get("glow_samples", 14)), dirs.size()):
		q.from = fl
		q.to = fl + dirs[i] * reach
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			glow.append((hit.position as Vector3) + (hit.normal as Vector3) * 0.06)


## The glow's rays: up, down and the four ways round, then the eight
## corners between.
static func glow_dirs() -> Array:
	var out: Array = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				out.append(Vector3(x, y, z).normalized())
	return out


## You woke at the hearth (§FD): whatever was after you gives you up.
func player_woke() -> void:
	for r in all:
		if r.hunting() or r.pursuit.on:
			r.give_up("taken")
