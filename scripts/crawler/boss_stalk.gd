class_name BossStalk
extends RefCounted
## What the snake's pool states share (design 9 Oct §FM.2, Mike's four;
## queue 66; data/boss_pool.json pools.desert): how it knows you are
## looking at it, how far your light reaches, where behind you is, which
## doorway it watches from, and how it follows you through its own dark.
## Pure helpers over a Boss and you (its player). The states
## (scripts/crawler/boss_states/) move it with Boss's own machinery (its
## routes through its dark and its tunnels, Boss._advance), so what the
## boss rule holds for its rounds holds for them too: it never goes into a
## lit room or stretch of its own accord, it goes through the stone only
## by its tunnels, and its body lies along the floor its head took.
##
##   your view     where the camera looks (its axis) from your eye.
##   watched       its head or a length of its body inside look_deg of
##                 your view axis, from_m away (flat), nothing of the stone
##                 between, and lit where it lies: by your torch (its light
##                 there at least light_field.least, as LightField counts
##                 a fire's), by a fire's light on the floor there (a lit
##                 corridor), or within your half-dark sight (§FC.4,
##                 HalfDark: your torch out, no flame near, out to
##                 crawler.json dark.black_m).
##   your circle   your torch's circle (torch_circle_m): how far from your
##                 lit torch its light on the floor stays past the chase's
##                 cap, as LightField counts a fire's (about 7 m as the
##                 numbers stand). What stalks you keeps outside it.
##   behind you    the flat angle between where you look and the way from
##                 you to it, past BEHIND_DEG.

## Behind you: this far round from where you look (deg, flat).
const BEHIND_DEG := 90.0
## How often a state that follows you finds its way again (s), and how far
## you may move before it does sooner (m).
const REPLAN_S := 0.35
const REPLAN_MOVE_M := 1.0
## Its body's lengths looked at for `watched`, this far apart along it (m).
const LOOK_STEP_M := 1.2


static func cam(b: Boss) -> Camera3D:
	if b.player == null or not is_instance_valid(b.player):
		return null
	var c := b.player.camera()
	return c if c != null and c.is_inside_tree() else null


## Your eye (the camera), and where you look (its axis, unit).
static func eye(b: Boss) -> Vector3:
	var c := cam(b)
	return c.global_position if c != null else b.player.global_position + Vector3.UP * 1.5


static func axis(b: Boss) -> Vector3:
	var c := cam(b)
	if c == null:
		return -b.player.global_basis.z
	return (-c.global_basis.z).normalized()


## Where you look, flat (unit).
static func flat_look(b: Boss) -> Vector3:
	var a := axis(b)
	var f := Vector3(a.x, 0.0, a.z)
	if f.length() < 1e-3:
		f = -b.player.global_basis.z
		f.y = 0.0
	return f.normalized() if f.length() > 1e-4 else Vector3.FORWARD


static func flat_d(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()


## How far you are from its head (flat).
static func to_you(b: Boss) -> float:
	return flat_d(b.player.global_position, b.head)


## The flat angle (deg) between where you look and the way from you to `p`:
## 0 straight ahead of you, 180 straight behind.
static func angle_from_look(b: Boss, p: Vector3) -> float:
	var v := Vector3(p.x - b.player.global_position.x, 0.0, p.z - b.player.global_position.z)
	if v.length() < 1e-3:
		return 0.0
	return rad_to_deg(flat_look(b).angle_to(v.normalized()))


## Is `p` behind you (BEHIND_DEG round from where you look)?
static func behind(b: Boss, p: Vector3) -> bool:
	return angle_from_look(b, p) > BEHIND_DEG


## Its head as drawn (Boss._pose: raised, and reached forward by its lunge),
## its middle.
static func head_point(b: Boss) -> Vector3:
	return b.head + Vector3.UP * (b.lift + 0.2) + b.dir * b.lunge


## What you might see of it: its head, then a length of its body every
## LOOK_STEP_M along it, each at its middle's height.
static func look_points(b: Boss) -> Array:
	var out: Array = [head_point(b)]
	var pts: Array = b._body_pts(LOOK_STEP_M)
	for i in range(1, pts.size()):
		out.append((pts[i] as Vector3) + Vector3.UP * 0.2)
	return out


## Your torch's light at `p` (0 with it out, or stone between): as
## LightField counts a fire's, energy * (1 - (d / range)^4)^2 / d^att, the
## torch in hand's energy and range times torch.json light.held_scale.
static func torch_light_at(b: Boss, p: Vector3) -> float:
	if not b._torch_lit():
		return 0.0
	var flame := b.player.torch.flame_position()
	if b._blocked(flame, p, false):
		return 0.0
	return light_of(flame.distance_to(p))


## The held torch's light at distance `d` (m).
static func light_of(d: float) -> float:
	var hs := Torch.held_scale()
	var e := float(Torch.L.get("energy", 2.2)) * hs
	var r := float(Torch.L.get("range_m", 14.0)) * hs
	var att := float(Torch.L.get("attenuation", 1.6))
	if d >= r:
		return 0.0
	var dd := maxf(d, LightField.num("min_d_m", 1.0))
	var w := 1.0 - pow(d / r, 4.0)
	return e * w * w / pow(dd, att)


## Your torch's circle (m): how far from your lit torch its light on the
## floor stays past the chase's cap (residents.json rules.chase_light_cap),
## counted as LightField counts a fire's (light_of). About 7 m as the
## numbers stand. What stalks you keeps outside it (observe_then_behind).
static func torch_circle_m() -> float:
	var cap := LightField.chase_cap()
	var r := float(Torch.L.get("range_m", 14.0)) * Torch.held_scale()
	var d := 0.5
	while d < r:
		if light_of(d) <= cap:
			return d
		d += 0.05
	return r


## Seen where it lies (`p`) by you: nothing of the stone between your eye
## and it, and lit there by your torch, a fire, or your half-dark sight.
static func seen_lit(b: Boss, p: Vector3) -> bool:
	var e := eye(b)
	if b._blocked(e, p, false):
		return false
	var least := LightField.num("least", 0.002)
	if torch_light_at(b, p) >= least:
		return true
	if b.light != null and b.light.at(p) >= least:
		return true
	var hd := half_dark(b)
	return hd != null and hd.strength > 0.05 and e.distance_to(p) <= HalfDark.black_m()


## Your half-dark sight (§FC.4): CrawlerMain's HalfDark, the boss's sibling.
static func half_dark(b: Boss) -> HalfDark:
	var parent := b.get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("HalfDark") as HalfDark


## You look at it (freeze_watched's needs; its entry `def`: look_deg,
## from_m): from at least from_m[0] away (all of it: its nearest part, its
## head included, that far from your eye, flat), its head or a length of
## its body inside look_deg of your view axis within from_m[1] of you, seen
## there (seen_lit). The point you see it by, or null.
static func watched_point(b: Boss, def: Dictionary) -> Variant:
	if b.player == null or b.player.dead or b.body == null or not b.body.visible:
		return null
	var look := float(def.get("look_deg", 25.0))
	var fr: Variant = def.get("from_m", [12.0, 60.0])
	var lo := 12.0
	var hi := 60.0
	if fr is Array and (fr as Array).size() >= 2:
		lo = float(fr[0])
		hi = float(fr[1])
	elif fr is float or fr is int:
		lo = float(fr)
	var e := eye(b)
	var ax := axis(b)
	var pts := look_points(b)
	for p: Vector3 in pts:
		if flat_d(p, e) < lo:
			return null
	for p: Vector3 in pts:
		var v := p - e
		if Vector2(v.x, v.z).length() > hi:
			continue
		if rad_to_deg(ax.angle_to(v)) > look:
			continue
		if seen_lit(b, p):
			return p
	return null


## How far its nearest part is from your eye (flat): its head and every
## length of its body (tools: the freeze's from_m[0]).
static func nearest_part_m(b: Boss) -> float:
	var e := eye(b)
	var best := INF
	for p: Vector3 in look_points(b):
		best = minf(best, flat_d(p, e))
	return best


static func watched(b: Boss, def: Dictionary) -> bool:
	return watched_point(b, def) != null


## It perceives you by its own senses, as on its rounds (rule.notice: your
## flame in its sight within sees_flame_m, a sprint heard within
## hears_sprint_m, you within feels_m; a fire pot's burst heard): no chase
## begun by it (the state decides).
static func senses_you(b: Boss) -> bool:
	if b.player == null or b.player.dead:
		return false
	var n: Dictionary = Boss.RULE.get("notice", {})
	var pp := b.player.global_position
	var fd := flat_d(pp, b.head)
	var seen := false
	if b._torch_lit():
		var flame := b.player.torch.flame_position()
		seen = b._eye().distance_to(flame) <= float(n.get("sees_flame_m", 20.0)) and not b._blocked(b._eye(), flame, false)
	var heard := b.player.noise_level >= 0.99 and fd <= float(n.get("hears_sprint_m", 15.0))
	var felt := fd <= b.num("feels_m", 1.5)
	var burst := b._hears_burst()
	return seen or heard or felt or burst


## Within its strike's reach of you, nothing between (its strike as built
## may begin).
static func in_reach(b: Boss) -> bool:
	if b._in_tunnel() or b.player == null or b.player.dead:
		return false
	var pp := b.player.global_position
	return flat_d(pp, b.base) <= b.strike.reach_m * 0.95 and absf(pp.y - b.base.y) < 1.5 and b._clear_to(pp)


## Your node (BossGround), or -1 (off its floor: down the stair to floor
## two, design §FM.6, where its graph doesn't go).
static func your_node(b: Boss) -> int:
	return b.ground.node_at(b.player.global_position)


## May a state that goes after you (observe_then_behind, coil_ambush) come
## now: you alive and on its own floor (your_node), and it not letting you
## go (Boss.let_go_t: walked away from, coil_ambush lets you go, and for
## let_go_s nothing of it comes straight back for you).
static func may_stalk(b: Boss) -> bool:
	if b.player == null or not is_instance_valid(b.player) or b.player.dead:
		return false
	return b.let_go_t <= 0.0 and your_node(b) >= 0


# --- Going through its dark --------------------------------------------------

## Where it may go toward `p` through its own dark (and its tunnels):
## {"node", "pos"}: `p` itself in your node when that is dark and it can
## reach it; else the dark node it can reach that is nearest you by the way
## from you, and its floor nearest you (pulled back out of the light past
## the chase's cap where it can be). {} with nowhere.
static func dark_toward(b: Boss, p: Vector3) -> Dictionary:
	var from := b._plan_from()
	var at := int(from.node)
	if at < 0 or not b.ground.is_ground(at):
		return {}
	var reach := b.ground.reach(at)
	var yours := b.ground.node_at(p)
	if yours >= 0 and reach.has(yours):
		var q := p
		q.y = b._floor_at(q)
		return {"node": yours, "pos": q}
	if yours < 0:
		return {}
	var r := b.ground._dijkstra(yours, false, 0.0, 0.0)
	var dist: Dictionary = r.dist
	var prev: Dictionary = r.prev
	var best := -1
	var best_d := INF
	for id in reach:
		if dist.has(id) and float(dist[id]) < best_d:
			best_d = float(dist[id])
			best = int(id)
	if best < 0:
		return {}
	var n: Dictionary = b.ground.nodes[best]
	var c: Vector3 = n.center
	var pos := c
	if prev.has(best):
		var l := b.ground.best_link(best, int(prev[best]))
		if not l.is_empty() and not l.has("tunnel"):
			var via: Vector3 = l.via
			var span := flat_d(via, c)
			# Back from where it touches your side, out of the light if it can.
			for back: float in [1.2, 2.0, 3.0, 4.5]:
				var k := clampf(back / maxf(span, 0.01), 0.0, 1.0)
				pos = via.lerp(c, k)
				pos.y = b._floor_at(pos)
				if b.light == null or b.light.under_cap(pos):
					break
	return {"node": best, "pos": pos}


## Its way to `goal` ({"node", "pos"}) through its dark, set as its route
## from where it is: along the floor (TombNav's dimmest way, from its own
## square, as its chase finds you) when all of that way lies in its dark;
## else through its dark rooms and stretches and its tunnels (BossGround,
## Boss._set_planned; a tunnel it is in, first). False when there is none.
## Found again often as it follows you, so the floor's way comes first: it
## starts where the snake is, never back at a door or a sconce behind it.
static func go_to(b: Boss, goal: Dictionary) -> bool:
	if goal.is_empty():
		return false
	if not b._in_tunnel() and b.nav != null:
		var pts := b._from_here(b.nav.path(b.base, goal.pos, true, TombNav.DIM))
		if not pts.is_empty() and TombNav.reaches(pts, goal.pos, 0.6) and all_dark(b, pts):
			b._set_route(pts)
			return true
	var from := b._plan_from()
	var at := int(from.node)
	if at < 0:
		return false
	var path: Array = [at] if at == int(goal.node) else b.ground.path(at, int(goal.node), true)
	if path.is_empty():
		return false
	b._set_planned(from, path, goal.pos)
	return true


## Does the floor's way `pts` (from where it is) lie in its dark all along
## (looked at every half metre: no lit room or stretch)?
static func all_dark(b: Boss, pts: PackedVector3Array) -> bool:
	var at := b.base
	for q in pts:
		var l := flat_d(at, q)
		var n := maxi(int(ceil(l / 0.5)), 1)
		for i in range(1, n + 1):
			var id := b.ground.node_at(at.lerp(q, float(i) / n))
			if id < 0 or not b.ground.is_ground(id):
				return false
		at = q
	return true


## Does the rest of its route (from where it is) still lie in its dark, the
## floor of it looked at every half metre (what runs through the rock, a
## tunnel or its den, passed over)? A light that catches ahead of a state
## that moves it (Boss._after_light, BossState.lights_changed) asks this,
## so the state finds its way again before it can walk into the light.
static func route_dark(b: Boss) -> bool:
	var at := b.base
	var hid := b.route_hidden.size() == b.route.size()
	for i in range(b.route_i, b.route.size()):
		var q := b.route[i]
		if hid and (b.route_hidden[i] != 0 or (i > 0 and b.route_hidden[i - 1] != 0)):
			at = q
			continue
		var l := flat_d(at, q)
		var n := maxi(int(ceil(l / 0.5)), 1)
		for k in range(1, n + 1):
			var id := b.ground.node_at(at.lerp(q, float(k) / n))
			if id < 0 or not b.ground.is_ground(id):
				return false
		at = q
	return true


## Nowhere to go: it holds where it is; in one of its tunnels, on through
## it to the floor out of the far hole first (a tunnel once begun is gone
## through; it never stops in the rock).
static func hold(b: Boss) -> void:
	if b._in_tunnel():
		var f := b._plan_from()
		b._set_route(f.pts, f.hidden)
	else:
		b._set_route(PackedVector3Array())


## In one of its tunnels a state keeps it going (on its route, at least its
## rounds' pace): true if it did (the state does nothing else this tick).
static func through_tunnel(b: Boss, delta: float, spd := 0.0) -> bool:
	if not b._in_tunnel():
		return false
	if b.route_i >= b.route.size():
		hold(b)
	b._sway = move_toward(b._sway, 0.0, delta * 2.0)
	b.lift = move_toward(b.lift, 0.0, delta)
	b._advance(maxf(spd, b.num("speed_mps", 2.0)), delta)
	return true


## Away from you through its dark: the node it can reach within `most_m`
## of its way that is farthest from you by the way from you (and farther
## than where it is), {"node", "pos"}; {} when it is cornered.
static func away_from_you(b: Boss, most_m := 30.0) -> Dictionary:
	var from := b._plan_from()
	var at := int(from.node)
	var yours := your_node(b)
	if at < 0 or yours < 0:
		return {}
	var reach := b.ground.reach(at)
	var dist: Dictionary = b.ground._dijkstra(yours, false, 0.0, 0.0).dist
	var here := float(dist.get(at, 0.0))
	var best := -1
	var best_d := here + 2.0
	for id in reach:
		if int(id) == yours or float(reach[id]) > most_m or not dist.has(id):
			continue
		if float(dist[id]) > best_d:
			best_d = float(dist[id])
			best = int(id)
	if best < 0:
		return {}
	var n: Dictionary = b.ground.nodes[best]
	var pos: Vector3 = b._room_entry(best) if str(n.kind) == "room" else n.center
	return {"node": best, "pos": pos}


## Does its route come within `m` of you (flat) anywhere on the way (it
## would go past you)?
static func route_passes_you(b: Boss, m: float) -> bool:
	var pp := b.player.global_position
	var at := b.base
	for i in range(b.route_i, b.route.size()):
		var q := b.route[i]
		if b.route_hidden.size() == b.route.size() and b.route_hidden[i] != 0:
			at = q
			continue
		# The nearest point of the leg from `at` to `q`.
		var c := Geometry2D.get_closest_point_to_segment(Vector2(pp.x, pp.z), Vector2(at.x, at.z), Vector2(q.x, q.z))
		if c.distance_to(Vector2(pp.x, pp.z)) < m:
			return true
		at = q
	return false


## A spot `r` m behind you (coil_ambush): on open floor in a dark node it
## can reach, straight behind you to 60 degrees either side (past
## BEHIND_DEG + 20 from where you look), under the chase's cap, off the way
## out, with nothing between it and you (so when you turn, it is there).
## The one nearest `r` from you, then nearest to it by its way.
## {"node", "pos"} or {}.
static func behind_spot(b: Boss, r: float) -> Dictionary:
	if b.nav == null:
		return {}
	var from := b._plan_from()
	var at := int(from.node)
	if at < 0 or not b.ground.is_ground(at):
		return {}
	var reach := b.ground.reach(at)
	var pp := b.player.global_position
	var back := -flat_look(b)
	var best := {}
	var best_s := INF
	for k in 13:
		var a := deg_to_rad(-60.0 + 10.0 * k)
		var dir := back.rotated(Vector3.UP, a)
		for dr: float in [0.0, -0.5, 0.5, -1.0, 1.0]:
			var q := pp + dir * (r + dr)
			var c := b.nav.nearest_open(b.nav.cell_of(q), 3)
			if c.x < 0:
				continue
			q = b.nav.point_of(c)
			var id := b.ground.node_at(q)
			if id < 0 or not reach.has(id):
				continue
			var off := absf(flat_d(q, pp) - r)
			if off > 1.2 or absf(q.y - pp.y) > 1.5:
				continue
			if angle_from_look(b, q) < BEHIND_DEG + 20.0:
				continue
			if b.light != null and not b.light.under_cap(q):
				continue
			if b.on_way_out(q):
				continue
			if b._blocked(pp + Vector3.UP * 1.0, q + Vector3.UP * 0.35, false):
				continue
			var s := off * 40.0 + float(reach[id]) * 0.2 + absf(a) * 2.0
			if s < best_s:
				best_s = s
				best = {"node": id, "pos": q}
	return best


# --- The doorway it watches from (doorway_watch) -------------------------------

## The nearest doorway of an unlit room on its rounds that you are not in
## (doorway_watch; its entry `def`: head_m): a door of a dark room it can
## reach through its dark, never the hearth room, never onto the way out
## or out of the tomb, never into the hearth room, never of the room you
## are in, and never a doorway its own ground has no way through (design
## §FM.6: the stair down to floor two, off its floor, its stone seal
## standing in the mouth until floor one is lit; any door a gate shuts,
## BossGround.shut), so its head never lies in a seal's stone.
## {"node" (the room's), "door", "mid" (the doorway's middle on
## its floor), "out" (flat, out of the room through it), "stand" (where it
## lies, just inside the room: under the chase's cap, on open floor),
## "head" (its head as drawn, in the gap), "lunge" (how far its head
## reaches from where it lies), "deep" and "inner" (the floor it comes to
## the doorway by, from deep in the room)} or {}.
static func pick_doorway(b: Boss, def: Dictionary, with_deep := true) -> Dictionary:
	if b.node < 0 or not b.ground.is_ground(b.node):
		return {}
	var reach := b.ground.reach(b.node)
	var yours := your_node(b) if b.player != null else -1
	var best := {}
	var best_c := INF
	for id in reach:
		var n: Dictionary = b.ground.nodes[int(id)]
		if str(n.kind) != "room" or bool(n.hearth) or int(id) == yours:
			continue
		var pc: Dictionary = b.lay.pieces[int(n.piece)]
		for di in pc.doors:
			var d: Dictionary = b.lay.doors[int(di)]
			var spot := door_spot(b, d, int(id), def)
			if spot.is_empty():
				continue
			var cost := float(reach[id]) + flat_d((n.center as Vector3), spot.stand)
			if cost < best_c:
				best_c = cost
				best = spot
	if with_deep and not best.is_empty():
		# Deep in the room, where it comes to the doorway from (its coil's
		# spot: clear floor far from the doors).
		best["deep"] = b._coil_spot(int(best.node))
	return best


## Doorway `d` of room node `room` as a place to lie and watch from
## (pick_doorway), or {}.
static func door_spot(b: Boss, d: Dictionary, room: int, def: Dictionary) -> Dictionary:
	var n: Dictionary = b.ground.nodes[room]
	var pid := int(n.piece)
	var other := int(d.b) if int(d.a) == pid else int(d.a)
	if other < 0 or other >= (b.lay.pieces as Array).size():
		return {}
	var opc: Dictionary = b.lay.pieces[other]
	if bool(opc.get("exit", false)) or str(opc.get("room_kind", "")) == "hearth":
		return {}
	# A doorway off its own floor (the stair down, §FM.6) or shut by a gate
	# (the fork's seal): no way through it on its ground, so not one to
	# watch from.
	if not b.ground.by_piece.has(other) or b.ground.shut.has(int(d.id)):
		return {}
	var dn: Vector2 = d.n
	var o2 := dn if int(d.a) == pid else -dn
	var out := Vector3(o2.x, 0.0, o2.y).normalized()
	var dp: Vector2 = d.p
	var mid := Vector3(dp.x, float(d.y), dp.y)
	var half_wall := Delves.WALL * 0.5
	# Its head in the gap: its front (the head and the snout, 0.6 of the
	# head's length ahead of its middle) head_m from the room's side of the
	# wall, the head's middle kept within the wall's thickness.
	var snout := float(b.sub("body").get("head_m", 0.55)) * 0.6
	var off := clampf(float(def.get("head_m", 0.8)) - half_wall - snout, -half_wall, half_wall)
	var head := mid + out * off
	head.y = mid.y
	# It lies just inside the room (so it is in the room it watches from).
	var stand := Vector3.INF
	for inset: float in [0.12, 0.25, 0.4, 0.55]:
		var q := mid - out * (half_wall + inset)
		q.y = b._floor_y(q)
		if b.ground.node_at(q) != room:
			continue
		if b.nav != null and not b.nav.is_open(b.nav.cell_of(q)):
			continue
		stand = q
		break
	if not stand.is_finite():
		return {}
	if b.light != null and not b.light.under_cap(stand):
		return {}
	if b.on_way_out(stand) or b.on_way_out(head):
		return {}
	# The floor it comes up to the doorway by: straight in from deep in the
	# room, so its body lies back into the room behind its head.
	var inner := Vector3.INF
	for back: float in [2.0, 1.5, 2.6, 1.1]:
		var q := stand - out * back
		q.y = b._floor_y(q)
		if b.ground.node_at(q) != room:
			continue
		if b.nav != null and not b.nav.is_open(b.nav.cell_of(q)):
			continue
		inner = q
		break
	if not inner.is_finite():
		return {}
	return {"node": room, "door": int(d.id), "mid": mid, "out": out, "stand": stand, "head": head,
		"lunge": flat_d(stand, head), "inner": inner, "half": float(d.half)}


## Is `p` in doorway `spot`'s gap (pick_doorway): within the wall's
## thickness of its middle, and inside its opening's width?
static func in_gap(spot: Dictionary, p: Vector3) -> bool:
	var out: Vector3 = spot.out
	var v: Vector3 = p - (spot.mid as Vector3)
	var along := v.x * out.x + v.z * out.z
	var across := absf(v.x * -out.z + v.z * out.x)
	return absf(along) <= Delves.WALL * 0.5 + 0.06 and across <= float(spot.half)
