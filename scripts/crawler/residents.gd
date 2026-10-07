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
##
## Cleared by light (design §FF.2; residents.json rules, crawler.json
## cleared). Until floors exist (§FF.1) a floor is the whole dungeon. The
## light is 49's graph of the tomb's rooms and corridor stretches
## (BossGround, `ground`), worked out again whenever a holder catches:
##
##   the light     a resident keeps to dark nodes unless it is chasing you
##                 (§FD: its strike has landed, so its chase may follow you
##                 into the light, Pursuit.may_enter). Relight the node one
##                 rests or stands in and it falls back into the nearest
##                 dark (light_changed); no strike reaches you in the light
##                 until one has hit you (may_strike, as the snake's
##                 relit_room safe);
##   dark pockets  on a half-lit floor they hang back in what dark is left
##                 (pocket_spot), and strike at you when you come within
##                 rules.pocket_counterattack_m (Resident's lunge);
##   cleared       when the floor's last light catches (clear_floor), every
##                 one leaves by its retreat_to, into its niche or the
##                 nearest hole (the tomb's open niches and graves, holes),
##                 seen going if you can see it, gone at once if you can't,
##                 and gone for good; and the log's one line.

static var D: Dictionary = Tuning.table("residents")
static var RULES: Dictionary = D.get("rules", {})
static var CLEARED: Dictionary = Tuning.table("crawler").get("cleared", {})
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
## The light (§FF.2): the tomb's holders, and 49's graph of its rooms and
## stretches lit or dark (none without the holders: no light rule then).
var fires: CrawlerFires
var ground: BossGround
var _lit_n := -1
## The floor is cleared: every light on it relit (crawler.json cleared).
var cleared := false
## Every resting place the tomb laid (its open niches and graves): the
## holes a resident can go back into when the floor is cleared.
var holes: Array = []
## Seconds of play (not counting "Good night"), when the floor was cleared
## (-1 not yet), and who has gone for good: [{"name", "at", "seen"}] (tools).
var clock := 0.0
var cleared_at := -1.0
var gone: Array = []


func build(p_lay: Dictionary, p_player: CrawlerPlayer, p_fires: CrawlerFires = null) -> void:
	lay = p_lay
	player = p_player
	fires = p_fires
	if fires != null:
		ground = BossGround.build(lay)
	for r in lay.get("residents", []):
		holes.append(r)
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
	if not paused():
		clock += delta
	refresh_light()
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


# --- Cleared by light (design §FF.2) ---------------------------------------------

## The light again whenever a holder catches (relit stays lit, so the count
## only rises): the graph worked out afresh, then the floor cleared if that
## was its last light, else every resident told (light_changed).
func refresh_light() -> void:
	if fires == null or ground == null:
		return
	var n := fires.lit_count()
	if n == _lit_n:
		return
	_lit_n = n
	var lit: Array = []
	for h in fires.holders:
		lit.append(FireStore.is_lit(h))
	ground.update(lit)
	if floor_lit():
		clear_floor()
		return
	# The checks that aren't about them keep them asleep through it.
	if stay_asleep:
		return
	for r in all.duplicate():
		r.light_changed()


## Every light on the floor relit (crawler.json cleared.when
## every_light_on_floor_relit; until floors exist, §FF.1, the floor is the
## whole dungeon).
func floor_lit() -> bool:
	return fires != null and not fires.holders.is_empty() and fires.lit_count() >= fires.holders.size()


## The floor's last light has caught (§FF.2): it is cleared. The log's one
## line (crawler.json cleared.log_line: no creature named, §BA), and every
## resident leaves by its retreat_to, seen going if you can see it, gone
## for good either way (residents.json rules.retreat_on_floor_lit). The
## boss's release is its own (Boss.release, §EY.2).
func clear_floor() -> void:
	if cleared:
		return
	cleared = true
	cleared_at = clock
	GameLog.add(str(CLEARED.get("log_line", "Banished the dark. What lived in it fled.")), "cleared")
	if stay_asleep or not bool(CLEARED.get("residents_leave", true)) or not bool(RULES.get("retreat_on_floor_lit", true)):
		return
	for r in all.duplicate():
		r.retreat()


## `r` has gone for good (Resident._gone): off the roll.
func went(r: Resident, seen: bool) -> void:
	all.erase(r)
	gone.append({"name": str(r.name), "at": clock, "seen": seen})


## The node of the graph (BossGround) `pos` stands in, or -1 when it is not
## on the tomb's floor at all (the checks' test floor: no light rule there).
## A doorway is in the wall between two pieces, so within the wall's
## thickness of a piece counts as on the floor.
func node_of(pos: Vector3) -> int:
	if ground == null:
		return -1
	if TombKit.piece_at(lay, pos) < 0:
		var near := false
		for pc in lay.pieces:
			var fy := Delves.floor_of(pc, clampf(Delves.along_across(pc, Vector2(pos.x, pos.z)).x, 0.0, float(pc.len)))
			if Delves.rect_of(pc, Delves.WALL + 0.1).has_point(Vector2(pos.x, pos.z)) and pos.y > fy - 1.0 and pos.y < fy + float(pc.h) + 0.5:
				near = true
				break
		if not near:
			return -1
	return ground.node_at(pos)


## Is `pos` in the dark (a node not yet relit, or off the tomb's floor)?
func dark_at(pos: Vector3) -> bool:
	var n := node_of(pos)
	return n < 0 or ground.is_ground(n)


## May `r` stand at `pos`: in the dark, or anywhere while its chase has its
## teeth in you (§FD, rules.chase_enters_light)?
func may_be_at(r: Resident, pos: Vector3) -> bool:
	return r.chasing() or dark_at(pos)


## May `r` strike at you where you stand? Not into the light until it has
## hit you (the snake's relit_room safe, §EY.2; §FD once it has).
func may_strike(r: Resident) -> bool:
	return r.chasing() or dark_at(player.global_position)


## The nearest dark node to node `from` by the way with least light in it,
## never through the hearth room (BossGround.nearest_dark), or -1 when no
## dark is left that it can reach.
func nearest_dark(from: int) -> int:
	if ground == null or from < 0:
		return -1
	var path := ground.nearest_dark(from)
	return int(path[-1]) if not path.is_empty() else -1


## Can `r` walk home from where it is through the dark: its resting place in
## the dark, and a way there that crosses no light (the hearth room is
## always lit)?
func can_go_home(r: Resident) -> bool:
	var home := node_of(r.place.out)
	var at := node_of(r.global_position)
	if home < 0 or at < 0:
		return true
	if not ground.is_ground(home):
		return false
	return at == home or not ground.path(at, home, true).is_empty()


## A spot to hang back in, in dark node `id` (§FF.2: the dark pockets): on
## open floor, as far from where the light comes in (its lit neighbours'
## doorways, its own lit sconces) as the node allows, clear of the others
## already hanging back, and not far out of `r`'s way.
func pocket_spot(id: int, r: Resident) -> Vector3:
	var n: Dictionary = ground.nodes[id]
	var pc: Dictionary = lay.pieces[int(n.piece)]
	var lights: Array = []
	for l in n.links:
		if bool(ground.nodes[int(l.to)].lit):
			lights.append(l.via)
	for e in n.ends:
		if str(e.type) == "sconce" and fires != null and int(e.holder) < fires.holders.size() and FireStore.is_lit(fires.holders[int(e.holder)]):
			lights.append(fires.holders[int(e.holder)].global_position)
	var taken: Array = []
	for q in all:
		if q != r and q.pocket != Vector3.INF and q.state in [Resident.LEAVE, Resident.LURK]:
			taken.append(q.pocket)
	var a0 := float(n.a0)
	var a1 := float(n.a1)
	var room := str(n.kind) == "room"
	var edge := minf(0.7, (a1 - a0) * 0.5)
	var acrosses: Array = [0.0]
	if room:
		var w := maxf(float(pc.half) - 0.8, 0.0)
		acrosses = [-w, -w * 0.5, 0.0, w * 0.5, w]
	var best := Vector3.INF
	var best_s := -INF
	for ka in 7:
		var along := lerpf(a0 + edge, a1 - edge, ka / 6.0)
		for across in acrosses:
			var p := BossGround.point(pc, along, float(across))
			if nav != null and not nav.is_open(nav.cell_of(p)):
				continue
			var d_light := 8.0
			for lp in lights:
				d_light = minf(d_light, Vector2(p.x - (lp as Vector3).x, p.z - (lp as Vector3).z).length())
			var crowd := 0.0
			for tp in taken:
				if (tp as Vector3).distance_to(p) < 1.4:
					crowd += 2.0
			var s := d_light - crowd - 0.03 * Vector2(p.x - r.global_position.x, p.z - r.global_position.z).length()
			if s > best_s:
				best_s = s
				best = p
	return best if best != Vector3.INF else (n.center as Vector3)


## Where `r`, gone into the stone because the light cut it off (Resident
## below), comes up: a spot to hang back in, in the dark node nearest it
## through the rock, never where you would see it come up nor near enough
## to strike at you at once. {"node", "pos"}, or {} when there is nowhere
## like that just now.
func come_up_spot(r: Resident) -> Dictionary:
	if ground == null:
		return {}
	var best := {}
	var best_d := INF
	var keep_off := rule("pocket_counterattack_m", 3.0) * 2.0
	for n in ground.nodes:
		if bool(n.lit):
			continue
		var d := (n.center as Vector3).distance_to(r.global_position)
		if d >= best_d:
			continue
		var spot := pocket_spot(int(n.id), r)
		if spot.distance_to(player.global_position) < keep_off or seen_at(spot):
			continue
		best_d = d
		best = {"node": int(n.id), "pos": spot}
	return best


## Would you see something standing at `p` (its middle and its head): in the
## frame, near enough, nothing of the stone between?
func seen_at(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	var c := cam.global_position
	for q: Vector3 in [p + Vector3(0.0, 0.5, 0.0), p + Vector3(0.0, 1.5, 0.0)]:
		if c.distance_to(q) <= Resident.SEEN_M and cam.is_position_in_frustum(q) and clear_line(c, q):
			return true
	return false


## Where the light comes into dark node `id` nearest `at` (a doorway to a lit
## neighbour, else the node's middle): what one hanging back there watches.
func light_way(id: int, at: Vector3) -> Vector3:
	var n: Dictionary = ground.nodes[id]
	var best: Vector3 = n.center
	var best_d := INF
	for l in n.links:
		if bool(ground.nodes[int(l.to)].lit) and (l.via as Vector3).distance_to(at) < best_d:
			best_d = (l.via as Vector3).distance_to(at)
			best = l.via
	return best


## The hole `r` goes back into when the floor is cleared (its retreat_to:
## the skeleton's back_into_its_niche, "back into its niche or the nearest
## hole"): its own resting place unless another of the tomb's open niches
## and graves is much nearer.
func nearest_hole(r: Resident) -> Dictionary:
	var best: Dictionary = r.place
	var best_d := (r.place.out as Vector3).distance_to(r.global_position) * 0.6
	for h in holes:
		var d := (h.out as Vector3).distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = h
	return best


## residents.json rules (the §FF.2 numbers), with their defaults.
static func rule(k: String, dflt: float) -> float:
	return float(RULES.get(k, dflt))
