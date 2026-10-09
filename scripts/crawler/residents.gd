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
##   watched()      can you see it (Mike's 7 Oct note, the Boos; its
##                  creature's creep block): any of its view points in your
##                  frame or within creep.view_margin of its edge, within
##                  creep.seen_m of your eye, nothing of the stone between;
##                  the dark doesn't hide it. While you can, a creeper holds
##                  still (Resident.holds_still);
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
## cleared), counted per floor (design §FM.6, TombFloors: floor one, and
## floor two below it; a resident is its resting place's floor's). The
## light is 49's graph of the tomb's rooms and corridor stretches
## (BossGround, `ground`), worked out again whenever a holder catches, and
## the light on the floor itself (LightField, `light`, on the floor grid:
## Mike's note of 7 Oct, "creatures that are actively chasing will chase
## near the fire but stay somewhat in the darkness if they can"):
##
##   the light     a resident keeps to dark nodes unless it is chasing you;
##                 chasing (its strike landed or not), it may stand only
##                 where the light is at most rules.chase_light_cap
##                 (may_be_at): it comes as far as the light's edge, and it
##                 strikes you only within its reach of where it may stand
##                 (may_strike), so by a fire you are safe. Relight the node
##                 one rests or stands in and it falls back into the
##                 nearest dark (light_changed) by the dimmest way;
##                 cut off from every dark but through the lit hearth room,
##                 it crosses that too (dark_way), only unseen;
##   dark pockets  on a half-lit floor they hang back in what dark is left
##                 (pocket_spot), and strike at you when you come within
##                 rules.pocket_counterattack_m (Resident's lunge);
##   cleared       when a floor's last light catches (clear_floor), every
##                 one of that floor leaves by its retreat_to: home to its
##                 own niche or grave, or a nearer one left open
##                 (claim_hole), by the dimmest way, seen or not, to lie
##                 down there as bones for good (Mike's note of 7 Oct:
##                 nothing sinks into the stone); and the log's one line,
##                 once for each floor.

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
## The light on the floor (LightField; with the nav, once the tomb's fires
## are in): the chase's edge and the dimmest way (the snake reads it too).
var light: LightField
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
## Every floor is cleared: every light on each relit (crawler.json
## cleared); each floor's own, when it was (the clock), in cleared_floors
## (floor -> seconds).
var cleared := false
var cleared_floors := {}
## What the floor grid casts through (design §FM.6: a gate's seal,
## RelightGate): the gate shuts its doorway's squares itself (Fork,
## TombNav.close_door), so they open with it.
var see_through: Array[RID] = []
## Every resting place the tomb laid (its open niches and graves): the
## holes a resident can go back into when the floor is cleared.
var holes: Array = []
## Seconds of play (not counting "Good night"), when a floor was last
## cleared (-1 not yet), and who has gone off the roll for good, lying in
## its niche or grave as bones: [{"name", "at", "seen"}] (tools).
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


## The floor's grid, and the light on it: call once the tomb's stone is in
## the physics world. A resting place's way out that something stands on
## (an urn, a lid) moves to the nearest open floor.
func build_nav() -> void:
	var ex: Array[RID] = [player.get_rid()]
	var nav_ex: Array[RID] = ex.duplicate()
	nav_ex.append_array(see_through)
	nav = TombNav.build(lay, get_world_3d().direct_space_state, NAV_RADIUS, nav_ex)
	if fires != null:
		light = LightField.build(nav, fires, self, ex)
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


## Have you come near enough to `r` at rest to bring it out: your head
## within its waking distance (Resident.waking_m: a creeper's creep.arms_m
## arms it, a waker's wakes_m wakes it), a clear line from its head to
## yours?
func can_wake(r: Resident) -> bool:
	if stay_asleep or paused():
		return false
	var head := player.eye_position()
	var e: Vector3 = r.place.eye
	return e.distance_to(head) <= r.waking_m() and clear_line(e, head)


## Can you see `r` now (Mike's 7 Oct note; its creep block): what holds a
## creeper still.
func watched(r: Resident) -> bool:
	return points_watched(r.view_points(), r.creep())


## Would you see any of `pts` (points on a body: feet, middle, head; the
## middle also taken `cr`.side_m to either side as you see it, so an arm at
## the frame's edge counts) from your eye now: in the frame or within
## `cr`.view_margin of its edge (a share of the frame on each side), within
## `cr`.seen_m, with nothing of the stone between? The dark doesn't hide
## them. With no creep block, in the frame within Resident.SEEN_M.
func points_watched(pts: Array, cr: Dictionary = {}) -> bool:
	if pts.is_empty() or not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var c := cam.global_position
	var far := float(cr.get("seen_m", Resident.SEEN_M))
	var margin := float(cr.get("view_margin", 0.0))
	var side := float(cr.get("side_m", 0.0))
	var all_pts := pts.duplicate()
	if side > 0.0 and pts.size() >= 2:
		var across := ((pts[1] as Vector3) - c).cross(Vector3.UP)
		across.y = 0.0
		if across.length() > 0.001:
			across = across.normalized() * side
			all_pts.append((pts[1] as Vector3) + across)
			all_pts.append((pts[1] as Vector3) - across)
	for q: Vector3 in all_pts:
		if c.distance_to(q) <= far and off_frame(cam, q) <= margin and clear_line(c, q):
			return true
	return false


## How far `p` lies outside camera `cam`'s frame, as a share of the frame
## (its width across, its height up and down): 0 on its edge, below 0
## inside it, INF behind the camera.
static func off_frame(cam: Camera3D, p: Vector3) -> float:
	var lp := cam.global_transform.affine_inverse() * p
	var ahead := -lp.z
	if ahead < 0.01:
		return INF
	var size := cam.get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var tv := tan(deg_to_rad(cam.fov) * 0.5)
	var th := tv * aspect
	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		th = tv
		tv = th / aspect
	return (maxf(absf(lp.x / ahead) / th, absf(lp.y / ahead) / tv) - 1.0) * 0.5


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
## only rises): the light on the floor and the graph worked out afresh,
## then each floor cleared whose last light that was, and every resident
## on a floor still dark told (light_changed).
func refresh_light() -> void:
	if fires == null or ground == null:
		return
	if light != null:
		light.refresh()
	var n := fires.lit_count()
	if n == _lit_n:
		return
	_lit_n = n
	var lit: Array = []
	for h in fires.holders:
		lit.append(FireStore.is_lit(h))
	ground.update(lit)
	for f in TombFloors.floors_of(lay):
		if not cleared_floors.has(f) and floor_lit(f):
			clear_floor(f)
	# The checks that aren't about them keep them asleep through it.
	if stay_asleep:
		return
	for r in all.duplicate():
		if not cleared_floors.has(floor_of(r)):
			r.light_changed()


## Every light on floor `f` relit (crawler.json cleared.when
## every_light_on_floor_relit, design §FM.6: per floor, TombFloors); `f`
## -1, every light on every floor.
func floor_lit(f := -1) -> bool:
	if fires == null or fires.holders.is_empty():
		return false
	if f < 0 or TombFloors.floors_of(lay).size() < 2:
		return fires.lit_count() >= fires.holders.size()
	return TombFloors.floor_lit(fires, lay, f)


## The floor resident `r` belongs to: its resting place's.
func floor_of(r: Resident) -> int:
	return TombFloors.floor_of(lay, int(r.place.get("piece", -1)))


## Floor `f`'s last light has caught (§FF.2; `f` -1: every floor not yet
## cleared): it is cleared. The log's one line for it (crawler.json
## cleared.log_line: no creature named, §BA; once a floor), and every
## resident of it leaves by its retreat_to (residents.json
## rules.retreat_on_floor_lit): home to lie down as bones for good, seen
## going if you can see it, walking on there unseen however far (Resident
## .retreat; Mike's note of 7 Oct). The boss's release is its own
## (Boss.release, §EY.2), as is the fork's (Fork, design §FM.6).
func clear_floor(f := -1) -> void:
	var floors: Array = TombFloors.floors_of(lay) if f < 0 else [f]
	for fl in floors:
		if cleared_floors.has(fl):
			continue
		cleared_floors[fl] = clock
		cleared_at = clock
		GameLog.add(str(CLEARED.get("log_line", "Banished the dark. What lived in it fled.")), "cleared")
		if stay_asleep or not bool(CLEARED.get("residents_leave", true)) or not bool(RULES.get("retreat_on_floor_lit", true)):
			continue
		for r in all.duplicate():
			if floor_of(r) == int(fl):
				r.retreat()
	cleared = cleared_floors.size() >= TombFloors.floors_of(lay).size()


## `r` lies in its niche or grave as bones for good (Resident._lay_down, the
## last light): off the roll, its node kept where it lies.
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


## May `r`, chasing you, stand at `pos` (Mike's note of 7 Oct, amending
## §FD): only where the light on the floor is at most rules.chase_light_cap
## (the light's edge, whether its strike has landed or not). Without the
## light on the floor (a test floor), in the dark, or anywhere while its
## chase has its teeth in you (queue 59's rule).
func may_be_at(r: Resident, pos: Vector3) -> bool:
	if light != null:
		return light.under_cap(pos)
	return r.chasing() or dark_at(pos)


## May `r` stand at `pos` hunting you (may_be_at)?
func light_ok(r: Resident, pos: Vector3) -> bool:
	return may_be_at(r, pos)


## May `r` come for you where you stand: is there floor no brighter than
## the chase's cap within its reach of you, joined to you by open floor,
## that its own way under the cap gets it to (Mike's note of 7 Oct: it
## strikes only within its reach of where it may stand, so by a fire you
## are safe, a shadow beside you that the light cuts off from it too)?
## Without the light on the floor, queue 59's rule: in the dark, or once it
## has hit you.
func may_strike(r: Resident) -> bool:
	if light != null:
		var reach := r.strike.reach_m if r.strike != null else float(r.strike_def().get("reach_m", 1.6))
		var you := player.global_position
		if not light.edge_within(you, reach):
			return false
		var pts := nav.path(r.global_position, you, true, TombNav.CAP)
		if pts.is_empty():
			return false
		var e := pts[pts.size() - 1]
		return Vector2(e.x - you.x, e.z - you.z).length() <= reach
	return r.chasing() or dark_at(player.global_position)


## The way from node `from` to the nearest dark node by the way with least
## light in it (BossGround.nearest_dark), crossing the lit hearth room only
## when there is no other (a branch all relit: Mike's note of 7 Oct,
## nothing goes into the stone, so it walks out): [node ids], [] when no
## dark is left that it can reach.
func dark_way(from: int) -> Array:
	if ground == null or from < 0:
		return []
	return ground.nearest_dark(from, BossGround.HEARTH_COST)


## The nearest dark node to node `from` (dark_way's end), or -1.
func nearest_dark(from: int) -> int:
	var path := dark_way(from)
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
			# Out of whatever light spills in (the floor's own light).
			var glare := 0.0
			if light != null:
				glare = minf(light.at(p) / maxf(light.cap, 1e-4), 10.0) * 2.0
			var s := d_light - crowd - glare - 0.03 * Vector2(p.x - r.global_position.x, p.z - r.global_position.z).length()
			if s > best_s:
				best_s = s
				best = p
	return best if best != Vector3.INF else (n.center as Vector3)


## Would you see something standing at `p` (its feet, middle and head):
## points_watched by `cr` (a creeper's creep block: what it counts as being
## seen, Mike's 7 Oct note), else in the frame within Resident.SEEN_M,
## nothing of the stone between?
func seen_at(p: Vector3, cr: Dictionary = {}) -> bool:
	return points_watched(Resident.standing_points(p), cr)


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


## The resting place `r` goes back into when the floor is cleared (its
## retreat_to: the skeleton's back_into_its_niche, "back into its niche or
## the nearest hole"; Mike's note of 7 Oct: it lies down there for good):
## its own, unless a niche or grave left open (its sleeper burnt out) is
## much nearer; never one another lies in or is going back to.
func claim_hole(r: Resident) -> Dictionary:
	var best: Dictionary = r.place
	var best_d := (r.place.out as Vector3).distance_to(r.global_position) * 0.6
	for h in holes:
		if h == r.place or _hole_taken(h, r):
			continue
		var d := (h.out as Vector3).distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = h
	return best


## Is resting place `h` someone else's (a resident still in the tomb whose
## own it is, or who is going back into it or lies in it)?
func _hole_taken(h: Dictionary, r: Resident) -> bool:
	for c in get_children():
		var q := c as Resident
		if q == null or q == r or not is_instance_valid(q) or q.is_queued_for_deletion():
			continue
		if q.place == h or q.hole == h:
			return true
	return false


## residents.json rules (the §FF.2 numbers), with their defaults.
static func rule(k: String, dflt: float) -> float:
	return float(RULES.get(k, dflt))
