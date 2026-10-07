class_name Boss
extends Node3D
## The dungeon's boss (design 6 Oct §EY; data/bosses.json): one in every
## dungeon (rule.one_per_dungeon), the dark given a body (§BA, §CU), not a
## fight: no health bar, nothing to kill (§ET.1). Built (§EY.8 step 1):
## the rule, with one boss, the snake (bosses.desert, the one marked
## first; it stands in the tomb as the test while the tomb's world is
## open). The other bosses wait for their worlds.
##
##   its ground  the rooms and corridor stretches not yet relit (BossGround,
##               rule.ground unlit), worked out again on every relight. It
##               moves only through its ground and never goes into a lit
##               room or stretch (rule.relit_closes_room); the hearth room
##               is never its ground.
##   its rounds  (pattern slither) along the corridors at speed_mps, from
##               one dead-end room to another, coiling in each for coil_s
##               (coils_in dead_ends).
##   noticing    (rule.notice) your carried flame in its sight within
##               sees_flame_m, a sprint (or anything as loud: a swing
##               that lands on it) within hears_sprint_m, or you within
##               feels_m whatever your light; then it hunts you through its
##               ground at hunt_mps, never into the light: if you stand in
##               a lit room it waits at the edge of its dark (watch_s) and
##               gives you up. The chase is a Pursuit (§FD, bosses.json
##               gives_up: too far, out of its sight and hearing too long,
##               your torch going out), so while it has you, you don't
##               heal (Harm).
##   your torch  (rule.torch_in_hand delay) with your torch lit it hangs at
##               the edge of its circle (torch_delay.hang_m), reared and
##               hissing, for torch_delay.hang_s before it closes; with the
##               torch out it closes straight in.
##   the strike  within its strike block's reach (§FA, CreatureStrike, the
##               piece every creature strikes with): the wind-up (reared
##               back, jaws opening, the hiss), the lunge, the draw back. A
##               lunge that reaches you is one hit (contact.strike_is_hit;
##               Harm, harm.json: its breath between hits holds), never in
##               a lit room (rule.relit_room safe). A lit torch swung into
##               its wind-up staggers it (torch.json stagger): it recoils
##               back along its body. Three hits is "Good night", and you
##               wake at the hearth (CrawlerMain) with every light you lit
##               still burning (contact.relit_kept); it goes back to its
##               rounds.
##   the light   relight the room or stretch it is in and it leaves at once
##               for the nearest dark by the way with least light in it
##               (rule.leaves_lit_room), at leave_mps, out across the lit
##               stretch beyond if it must, never through the hearth room.
##               Cut off deeper in the light than that, it goes down into
##               the dark below the tomb (the caves its lair opens on): it
##               slides off toward its hole while you can see it and is
##               gone the moment you can't; after a coil's while it comes
##               up out of its hole if that room is still dark, else in the
##               dark nearest the hole, out of your sight.
##   the release when the dungeon's last holder catches (rule.last_light
##               to_lair): if you can see it, it flees toward its lair and
##               is gone the moment you can't (else it is gone at once); a
##               long sound goes away along the tomb and down into the hole
##               (release.cry_to_lair); the tomb's small sounds come back
##               (release.bed_returns: the drips, hushed while it prowled);
##               the log's one line (release.log_line). Then it is in its
##               hole for good, breathing, heard within
##               lair.breathing_heard_m.
##   fire pots   (design §FA.3, §FA.4; FirePots) a pot that bursts on or
##               by it (splash_m from any part of its body, or a burning
##               tar patch it crawls into) drives it off: down below the
##               tomb as when the light cuts it off, for fire_pots.json
##               vs_boss.drives_off_s, and the chase is off. It is never
##               burnt down or killed. The lit wick gives you away as your
##               flame does, out to gives_away.flare_seen_m with a clear
##               line to it, and a burst within burst_heard_m of it is
##               heard like a sprint: either sets it hunting you.
##   its tell    scales dragging on stone (BossSounds), on a 3D player at
##               its body, heard well before you can see it; quieter while
##               it lies coiled. No name on screen (§BA).
##   its body    baked sprites (BossBody): a head and a chain of body
##               lengths, each where the head was, so it bends through the
##               corridors and lies in a coil.

static var B: Dictionary = Tuning.table("bosses")
static var RULE: Dictionary = B.get("rule", {})
static var CONTACT: Dictionary = B.get("contact", {})
static var LAIR: Dictionary = B.get("lair", {})
static var RELEASE: Dictionary = B.get("release", {})

## The trail's spacing (m): the head's place is kept every this far.
const TRAIL_STEP := 0.08
## The neck: how many body lengths rise with the head.
const NECK := 9
## The body's height off the floor where rays look for what's in its way.
const KNEE := 0.3
## Lit round it, it slides out across at most this many more lit nodes
## (the lit stretch outside a room); cut off deeper than that, it goes
## down into the dark below.
const LEAVE_LIT_MAX := 2

var key := ""
var def: Dictionary = {}
var name_text := "boss"
var lay: Dictionary = {}
var fires: CrawlerFires
var player: CrawlerPlayer
var ground: BossGround
var body: BossBody
## Off: the checks drive tick() themselves.
var auto := true
## Placed and going (a physics frame after build()).
var started := false

## coil, prowl, hunt, hang, strike, watch, leave, below (cut off in the
## light: gone down into the dark under the tomb for a while), held (you
## are taken), release, lair, gone (no lair: it went into the dark for
## good).
var state := "coil"
## The head's place on the route's middle line, and with the slither's
## sway (on the floor); the way it faces (flat).
var base := Vector3.ZERO
var head := Vector3.ZERO
var dir := Vector3.FORWARD
var route := PackedVector3Array()
var route_i := 0
## The head's places, newest first, TRAIL_STEP apart: the body lies on it.
var trail: Array = []
var travelled := 0.0
var node := -1
var speed := 0.0
## The round: the room it is making for, coiling there (coil_left s).
var target := -1
var coiling := false
var coil_left := 0.0
## The head raised (m), the lunge's reach now (m), the jaws.
var lift := 0.0
var lunge := 0.0
var mouth_open := false
var _sway := 0.0

## Noticing: whether it has you and where it last had you; whether it
## perceives you now (its last look); the chase (§FD, Pursuit).
var noticed := false
var last_seen := Vector3.ZERO
var perceives := false
var pursuit: Pursuit
## Its strike (§FA, CreatureStrike), at its head.
var strike: CreatureStrike
## The torch's delay used up (s), and whether it has struck since it last
## found you.
var hang_t := 0.0
var struck := false
## The stagger's reel under way (the strike's stagger_frame) and which way
## it goes: back along its body, or straight away from the swing.
var _reel_frame := -1
var _reel_back := true
var watch_t := 0.0
var _notice_t := 0.0
var _replan_t := 0.0
var _player_node := -1
var _hiss_t := 0.0
var _lit_n := -1
var _rng := RandomNumberGenerator.new()

## The lair (TombKit: lay.lair), its node, the release's sound path.
var lair: Dictionary = {}
var lair_node := -1
var released := false
var _cry_path: Array = []
var _cry_t := -1.0
var _vanish_t := -1.0
var _bed_t := -1.0
## Below: how long before it comes up again.
var below_t := 0.0

var _tell: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D
var _cry: AudioStreamPlayer3D
## The tomb's small sounds (the drips' loop; CrawlerMain), hushed while it
## prowls, and their own level.
var bed: AudioStreamPlayer
var bed_db := -20.0

## The checks: times it walked into a lit node of its own accord (never),
## and the hits it landed.
var lit_entries := 0
var hits_landed := 0
## Fire pots (FirePots): times a pot drove it off, and the last burst it
## listened for.
var driven := 0
var _burst_id := 0


## The boss of this dungeon (§EY.8: the tomb's world is open, so the one
## marked first stands in): its key in bosses.json bosses.
static func pick() -> String:
	var bs: Dictionary = B.get("bosses", {})
	for k in bs:
		if bool((bs[k] as Dictionary).get("first", false)):
			return str(k)
	return "desert" if bs.has("desert") else ""


func build(p_lay: Dictionary, p_fires: CrawlerFires, p_player: CrawlerPlayer, p_bed: AudioStreamPlayer = null) -> void:
	name = "Boss"
	lay = p_lay
	fires = p_fires
	player = p_player
	bed = p_bed
	if bed != null:
		bed_db = bed.volume_db
	key = pick()
	def = (B.get("bosses", {}) as Dictionary).get(key, {})
	name_text = str(def.get("creature", "boss"))
	_rng.seed = hash([int(lay.seed), "boss"])
	ground = BossGround.build(lay)
	lair = lay.get("lair", {})
	if not lair.is_empty():
		lair_node = ground.node_at(lair.pos)
	body = BossBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(def)
	_tell = Audio3D.make("boss_tell", self, "Tell")
	_tell.stream = BossSounds.stream("scales_loop", _rng.randi())
	_hiss = Audio3D.make("strike_tell", self, "Hiss")
	# Its strike (CreatureStrike, bosses.json bosses.<key>.strike): driven
	# from here (tick), so the checks' stepped clock drives it too.
	strike = CreatureStrike.new()
	strike.name = "Strike"
	add_child(strike)
	strike.setup(sub("strike"), name_text)
	strike.set_physics_process(false)
	strike.target = player
	strike.on_hit = _on_strike_hit
	strike.struck.connect(func(_landed: bool) -> void: struck = true)
	pursuit = Pursuit.new(self, sub("gives_up"))
	# A fire pot's burst can reach it (FirePots' fire-target socket).
	add_to_group(FirePots.TARGET_GROUP)
	_breath = Audio3D.make("boss_breath", self, "Breath")
	_breath.stream = BossSounds.stream("breath_loop", _rng.randi())
	_breath.max_distance = float(LAIR.get("breathing_heard_m", 12.0))
	_cry = Audio3D.make("boss_cry", self, "Cry")
	_cry.stream = BossSounds.stream("retreat", _rng.randi())
	if not lair.is_empty():
		# Below the floor, down the hole.
		_breath.position = (lair.pos as Vector3) - Vector3(0.0, 1.2, 0.0)
		_mouth(lair)
	_refresh(true)
	_begin.call_deferred()


## Start once the tomb's stone is in the physics world (its rays see it).
func _begin() -> void:
	if is_inside_tree():
		await get_tree().physics_frame
	_start_far()
	started = true


## The hole's mouth (TombBuild._lair_hole lays its broken edge): a black
## void a hand over the floor, unlit like the airways' slots, so nothing of
## the floor shows through it.
func _mouth(l: Dictionary) -> void:
	var c: Vector3 = l.pos
	var r := float(l.r)
	var mrng := RandomNumberGenerator.new()
	mrng.seed = hash([int(lay.seed), "lair_mouth"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var rim: Array = []
	for k in n:
		var a := TAU * k / n
		rim.append(Vector3(cos(a), 0.0, sin(a)) * r * mrng.randf_range(0.92, 1.08))
	for k in n:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(rim[(k + 1) % n])
		st.add_vertex(rim[k])
	var mi := MeshInstance3D.new()
	mi.name = "LairMouth"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.004, 0.005, 0.012)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = c + Vector3(0.0, 0.07, 0.0)


## The numbers (bosses.json bosses.<key>), with first-guess defaults.
func num(k: String, dflt: float) -> float:
	return float(def.get(k, dflt))


func sub(k: String) -> Dictionary:
	var v: Variant = def.get(k, {})
	return v if v is Dictionary else {}


func _range(v: Variant, lo: float, hi: float) -> float:
	if v is Array and (v as Array).size() == 2:
		return _rng.randf_range(float(v[0]), float(v[1]))
	return _rng.randf_range(lo, hi)


# --- Its place ------------------------------------------------------------------

## The floor's height under (x/z) `p`.
func _floor_y(p: Vector3) -> float:
	var id := ground.node_at(p)
	if id < 0:
		return p.y
	var pc: Dictionary = lay.pieces[int(ground.nodes[id].piece)]
	return Delves.floor_of(pc, Delves.along_across(pc, Vector2(p.x, p.z)).x)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Start, or start again (after you wake): coiled in the dark dead end
## farthest from the hearth room (or the farthest dark room).
func _start_far() -> void:
	var dist := _all_dist(_hearth_node())
	var best := -1
	var best_d := -INF
	for id in dist:
		if not ground.is_ground(int(id)) or str(ground.nodes[id].kind) != "room":
			continue
		var d := float(dist[id]) + (100.0 if ground.dead_end(int(id)) else 0.0)
		if d > best_d:
			best_d = d
			best = int(id)
	if best < 0:
		for id in dist:
			if ground.is_ground(int(id)) and float(dist[id]) > best_d:
				best_d = float(dist[id])
				best = int(id)
	if best < 0:
		state = "gone"
		body.visible = false
		return
	_lie_coiled(best)


func _hearth_node() -> int:
	for n in ground.nodes:
		if bool(n.hearth):
			return int(n.id)
	return 0


## Every node's distance from `from` through anything.
func _all_dist(from: int) -> Dictionary:
	return ground._dijkstra(from, false, 0.0).dist


## Lying coiled in room `id` already: the whole body in the coil, the head
## on top.
func _lie_coiled(id: int) -> void:
	target = id
	var c := _coil_spot(id)
	var entry := _room_entry(id)
	var pts: Array = [entry]
	for p in _spiral(c, entry):
		pts.append(p)
	trail.clear()
	_trail_from(pts)
	base = pts[-1]
	head = base
	var last: Vector3 = pts[-1]
	var prev: Vector3 = pts[-2]
	dir = _flat(last - prev).normalized() if _flat(last - prev).length() > 0.001 else Vector3.FORWARD
	node = ground.node_at(base)
	state = "coil"
	coiling = false
	coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0)
	route = PackedVector3Array()
	route_i = 0
	lift = 0.12
	_sway = 0.0


## The trail laid along polyline `poly` (oldest first): newest first,
## TRAIL_STEP apart.
func _trail_from(poly: Array) -> void:
	var out: Array = []
	var carry := 0.0
	for i in range(poly.size() - 1):
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[i + 1]
		var l := a.distance_to(b)
		var s := carry
		while s < l:
			out.append(a.lerp(b, s / maxf(l, 1e-4)))
			s += TRAIL_STEP
		carry = s - l
	out.append(poly[-1])
	out.reverse()
	trail = out


## Where a room's way in is: just inside its first door (its only one in a
## dead end).
func _room_entry(id: int) -> Vector3:
	var n: Dictionary = ground.nodes[id]
	for l in n.links:
		if int(l.door) >= 0:
			var d: Dictionary = lay.doors[int(l.door)]
			var n3 := Vector3((d.n as Vector2).x, 0.0, (d.n as Vector2).y)
			var sgn := 1.0 if int(d.b) == int(n.piece) else -1.0
			var p: Vector3 = (l.via as Vector3) + n3 * sgn * 1.0
			p.y = _floor_y(p)
			return p
	return n.center


## The coil's middle in room `id`: clear of the walls, the doors, the
## fires on the floor, the lair's hole and whatever stands in the room
## (rays at the body's height), as far from its doors as it can be.
func _coil_spot(id: int) -> Vector3:
	var n: Dictionary = ground.nodes[id]
	var pc: Dictionary = lay.pieces[int(n.piece)]
	var r := float(sub("body").get("coil_r_m", 0.9))
	var best := n.center as Vector3
	var best_s := -INF
	var length := float(pc.len)
	var half := float(pc.half)
	for ka in 5:
		for kc in 3:
			var along := lerpf(r + 0.5, length - r - 0.5, ka / 4.0)
			var across := lerpf(-(half - r - 0.5), half - r - 0.5, kc / 2.0) if half > r + 0.5 else 0.0
			var p := BossGround.point(pc, along, across)
			var s := 0.0
			var ok := true
			for di in pc.doors:
				var d: Dictionary = lay.doors[di]
				var dd := Vector2(p.x, p.z).distance_to(d.p)
				if dd < r + 1.2:
					ok = false
				s += minf(dd, 8.0)
			for h in lay.holders:
				if int(h.piece) == int(pc.id) and str(h.kind) != "sconce":
					if Vector2(p.x, p.z).distance_to(Vector2((h.pos as Vector3).x, (h.pos as Vector3).z)) < r + 1.0:
						ok = false
			if not lair.is_empty() and int(lair.piece) == int(pc.id):
				if Vector2(p.x, p.z).distance_to(Vector2((lair.pos as Vector3).x, (lair.pos as Vector3).z)) < r + float(lair.r) + 0.4:
					ok = false
			if ok and is_inside_tree():
				ok = _clear_disk(p, r + 0.2)
			if not ok:
				s -= 1000.0
			if s > best_s:
				best_s = s
				best = p
	return best


## Is the floor round `c` clear `r` out, at the body's height: nothing
## standing there (a coffin, an urn of the dead's goods, the heart's box)
## and no wall within it?
func _clear_disk(c: Vector3, r: float) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = PropCollision.WORLD_LAYER
	for ring: float in [0.0, 0.5, 1.0]:
		var n := 1 if ring == 0.0 else 8
		for k in n:
			var a := TAU * (k + 0.5 * ring) / n
			q.position = c + Vector3(cos(a), 0.0, sin(a)) * r * ring + Vector3(0.0, KNEE, 0.0)
			if not space.intersect_point(q, 1).is_empty():
				return false
	for k in 8:
		var a := TAU * k / 8.0
		if _blocked(c + Vector3(0, KNEE, 0), c + Vector3(cos(a), 0.0, sin(a)) * r + Vector3(0, KNEE, 0)):
			return false
	return true


## The coil: from `entry`, round the middle `c` and in, long enough to
## take the whole body (a coiled snake lies on itself), each turn rising a
## little on the last.
func _spiral(c: Vector3, entry: Vector3) -> Array:
	var r0 := float(sub("body").get("coil_r_m", 0.9))
	var r1 := 0.28
	var want := float(sub("body").get("length_m", 9.0)) + 0.4
	var a := atan2(entry.z - c.z, entry.x - c.x)
	var sgn := 1.0 if (int(lay.seed) + target) % 2 == 0 else -1.0
	# The angle it takes to lay `want` metres from r0 in to r1.
	var theta := want / ((r0 + r1) * 0.5)
	var out: Array = []
	var steps := maxi(int(theta / 0.3), 8)
	for k in range(1, steps + 1):
		var u := float(k) / steps
		var r := lerpf(r0, r1, u)
		var ak := a + sgn * u * theta
		var p := c + Vector3(cos(ak), 0.0, sin(ak)) * r
		p.y = c.y + u * 0.26
		out.append(p)
	return out


# --- Moving ---------------------------------------------------------------------

func _set_route(pts: PackedVector3Array) -> void:
	route = pts
	route_i = 0


## On along the route at `spd` m/s for `delta` s. True at its end.
func _advance(spd: float, delta: float) -> bool:
	speed = spd
	var step := spd * delta
	var moved := 0.0
	while step > 1e-6 and route_i < route.size():
		var to := route[route_i]
		var d := base.distance_to(to)
		if d <= step:
			base = to
			step -= d
			moved += d
			route_i += 1
		else:
			var v := (to - base) / d
			base += v * step
			moved += step
			step = 0.0
	var fv := Vector3.ZERO
	if route_i < route.size():
		fv = _flat(route[route_i] - base)
	if fv.length() > 0.01:
		dir = _turn(dir, fv.normalized(), clampf(delta * 6.0, 0.0, 1.0))
	travelled += moved
	# The slither: the head swings side to side as it goes, so the body
	# lies in waves behind it.
	var b: Dictionary = sub("body")
	var amp := float(b.get("undulate_m", 0.22)) * _sway
	var wave := maxf(float(b.get("wave_m", 2.6)), 0.5)
	var side := Vector3(-dir.z, 0.0, dir.x)
	head = base + side * sin(travelled * TAU / wave) * amp
	if moved > 0.0:
		_push_trail(head)
	_track_node()
	return route_i >= route.size()


func _push_trail(p: Vector3) -> void:
	if trail.is_empty() or (trail[0] as Vector3).distance_to(p) >= TRAIL_STEP:
		trail.push_front(p)
	else:
		trail[0] = p
	var keep := int((float(sub("body").get("length_m", 9.0)) + 1.5) / TRAIL_STEP) + 4
	while trail.size() > keep:
		trail.pop_back()


## Which node it is in now, and a count of any it walked into while lit
## (never, but leaving or fleeing).
func _track_node() -> void:
	var was := node
	node = ground.node_at(base)
	if node != was and node >= 0 and not ground.is_ground(node) and not state in ["leave", "release", "held", "below"]:
		lit_entries += 1


## The way through nodes `path` (from the one it is in) to `end`: through
## each door square on to it, each sconce on the corridor's middle line;
## round anything standing in the way.
func _route_nodes(path: Array, end: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in range(path.size() - 1):
		var l := ground.link(int(path[k]), int(path[k + 1]))
		if l.is_empty():
			continue
		var via: Vector3 = l.via
		if int(l.door) >= 0:
			var d: Dictionary = lay.doors[int(l.door)]
			var n3 := Vector3((d.n as Vector2).x, 0.0, (d.n as Vector2).y)
			var sgn := 1.0 if int(ground.nodes[int(path[k])].piece) == int(d.a) else -1.0
			var before := via - n3 * sgn * 0.75
			var after := via + n3 * sgn * 0.75
			before.y = _floor_y(before)
			after.y = _floor_y(after)
			pts.append(before)
			pts.append(via)
			pts.append(after)
		else:
			pts.append(via)
	pts.append(end)
	return _around(pts)


## Round what stands in the way (a coffin, the heart's box, a fire on the
## floor): a leg that hits something gets a step aside.
func _around(pts: PackedVector3Array) -> PackedVector3Array:
	if not is_inside_tree():
		return pts
	var out := PackedVector3Array()
	var from := base
	for p in pts:
		var guard := 0
		while guard < 2:
			guard += 1
			var hit: Variant = _blocked_at(from + Vector3(0, KNEE, 0), p + Vector3(0, KNEE, 0))
			if hit == null:
				break
			var h: Vector3 = hit
			var fwd := _flat(p - from).normalized()
			var side := Vector3(-fwd.z, 0.0, fwd.x)
			var found := false
			for off: float in [0.9, -0.9, 1.5, -1.5, 2.2, -2.2]:
				var q := Vector3(h.x, from.y, h.z) + side * off - fwd * 0.3
				q.y = _floor_y(q)
				if _blocked_at(from + Vector3(0, KNEE, 0), q + Vector3(0, KNEE, 0)) == null and _blocked_at(q + Vector3(0, KNEE, 0), p + Vector3(0, KNEE, 0)) == null:
					out.append(q)
					from = q
					found = true
					break
			if not found:
				break
		out.append(p)
		from = p
	return out


func _blocked(a: Vector3, b: Vector3, fires_too := true) -> bool:
	return _blocked_at(a, b, fires_too) != null


## Where the way from `a` to `b` meets stone or (fires_too) a fire on the
## floor; null if it doesn't.
func _blocked_at(a: Vector3, b: Vector3, fires_too := true) -> Variant:
	if a.distance_to(b) < 0.05:
		return null
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = PropCollision.WORLD_LAYER
	if player != null:
		q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	if not fires_too:
		return null
	# The fires on the floor have no stone to hit: kept off by hand.
	for h in lay.holders:
		if str(h.kind) == "sconce":
			continue
		var hp := Vector2((h.pos as Vector3).x, (h.pos as Vector3).z)
		var cp := Geometry2D.get_closest_point_to_segment(hp, Vector2(a.x, a.z), Vector2(b.x, b.z))
		if cp.distance_to(hp) < 0.85 and absf((h.pos as Vector3).y - a.y) < 1.5:
			return Vector3(cp.x, a.y, cp.y)
	return null


## Cut `from_end` metres off the route's far end (to stop short of you).
func _trim(pts: PackedVector3Array, from_end: float) -> PackedVector3Array:
	var all := PackedVector3Array([base]) + pts
	var left := from_end
	while all.size() >= 2 and left > 0.0:
		var a := all[all.size() - 2]
		var b := all[all.size() - 1]
		var l := a.distance_to(b)
		if l <= left:
			all.remove_at(all.size() - 1)
			left -= l
		else:
			all[all.size() - 1] = b.lerp(a, left / l)
			left = 0.0
	all.remove_at(0)
	return all


# --- Every tick ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if auto:
		tick(delta)


func tick(delta: float) -> void:
	if not started:
		return
	if state == "lair" or state == "gone":
		_bed_tick(delta)
		_sound_tick(delta)
		return
	_refresh(false)
	if state == "release":
		_release_tick(delta)
		_pose()
		_bed_tick(delta)
		_sound_tick(delta)
		return
	if Harm.instance != null and Harm.instance.taking:
		# You are taken: it holds where it is, quiet, until you wake.
		if state != "held":
			state = "held"
			_calm()
	if state == "held":
		lift = move_toward(lift, 0.1, delta)
		lunge = move_toward(lunge, 0.0, delta * 3.0)
		_pose()
		_sound_tick(delta)
		return
	strike.tick(delta)
	_notice(delta)
	_chase(delta)
	match state:
		"coil":
			_coil_tick(delta)
		"prowl":
			_prowl_tick(delta)
		"hunt":
			_hunt_tick(delta)
		"hang":
			_hang_tick(delta)
		"strike":
			_strike_tick(delta)
		"watch":
			_watch_tick(delta)
		"leave":
			_leave_tick(delta)
		"below":
			_below_tick(delta)
	_pose()
	_bed_tick(delta)
	_sound_tick(delta)


## The lights: worked out again whenever a holder catches. The last one
## sends it home; a light round it sends it off.
func _refresh(force: bool) -> void:
	var n := fires.lit_count()
	if n == _lit_n and not force:
		return
	_lit_n = n
	var lit: Array = []
	for h in fires.holders:
		lit.append(FireStore.is_lit(h))
	ground.update(lit)
	if force:
		return
	if ground.ground_count() == 0:
		release()
		return
	if state in ["release", "lair", "gone", "below"]:
		return
	node = ground.node_at(base)
	if not ground.is_ground(node):
		_leave()
		return
	# The way it was going may have gone into the light: think again.
	_replan_t = 0.0
	if state == "prowl":
		for p in route.slice(route_i):
			if not ground.is_ground(ground.node_at(p)):
				_next_round()
				break
	elif state == "watch":
		_go_watch(ground.node_at(player.global_position))


# --- Noticing ----------------------------------------------------------------

func _eye() -> Vector3:
	return head + Vector3(0.0, 0.35 + lift, 0.0)


func _notice(delta: float) -> void:
	_notice_t -= delta
	if state == "below":
		# Down below it hears no burst (none waits for it to come up).
		_hears_burst()
		return
	if _notice_t > 0.0:
		return
	_notice_t = 0.2
	perceives = false
	if player == null or player.dead:
		return
	var n: Dictionary = RULE.get("notice", {})
	var pp := player.global_position
	var flat_d := _flat(pp - head).length()
	var lit := _torch_lit()
	var seen := false
	if lit:
		var flame := player.torch.flame_position()
		seen = _eye().distance_to(flame) <= float(n.get("sees_flame_m", 20.0)) and not _blocked(_eye(), flame, false)
	# A sprint, or anything as loud (a swing that lands on it, §FA.1).
	var heard := player.noise_level >= 0.99 and flat_d <= float(n.get("hears_sprint_m", 15.0))
	var felt := flat_d <= num("feels_m", 1.5)
	# A fire pot gives you away (§FA.3, FirePots): the lit wick's flare in
	# its sight within gives_away.flare_seen_m, the burst within its
	# burst_heard_m.
	var flared := not FirePots.flare_seen_from(_eye(), get_world_3d().direct_space_state).is_empty()
	var burst := _hears_burst()
	perceives = seen or heard or felt or flared or burst
	if perceives:
		if not noticed:
			hang_t = 0.0
			struck = false
		noticed = true
		last_seen = pp
		pursuit.notice(lit)
		if state in ["coil", "prowl"]:
			state = "hunt"
			coiling = false
			_replan_t = 0.0


func _torch_lit() -> bool:
	return player != null and player.torch != null and player.torch.lit()


## A pot's burst within its heard_m since it last listened (FirePots).
func _hears_burst() -> bool:
	var out := false
	for b in FirePots.bursts_since(_burst_id):
		_burst_id = int(b.id)
		if _flat((b.pos as Vector3) - head).length() <= float(b.heard_m):
			out = true
	return out


# --- Fire pots (FirePots' fire-target socket; design §FA.3, §FA.4) ------------

## Where a pot meets its head (the sphere a thrown pot hits).
func fire_center() -> Vector3:
	return head + Vector3(0.0, KNEE + lift, 0.0)


## How far `p` is from its body (m; under 0 inside it): its head and its
## length along the trail, girth_m thick. INF while it isn't in the tomb
## (below, home, gone).
func fire_distance(p: Vector3) -> float:
	if state in ["below", "lair", "gone"] or (body != null and not body.visible):
		return INF
	var r := float(sub("body").get("girth_m", 0.38)) * 0.5 + 0.1
	var best := fire_center().distance_to(p)
	var step := maxi(int(0.5 / TRAIL_STEP), 1)
	var n := mini(trail.size(), int(float(sub("body").get("length_m", 9.0)) / TRAIL_STEP) + 1)
	for i in range(0, n, step):
		best = minf(best, ((trail[i] as Vector3) + Vector3(0.0, KNEE, 0.0)).distance_to(p))
	return best - r


## A fire pot burst on it (§FA.4: a pot never kills a boss; fire_pots.json
## vs_boss): driven off into the dark for `seconds`, down below the tomb as
## when the light cuts it off (sliding off toward its hole while you can
## see it, gone the moment you can't), the chase off; then up again, out of
## its hole or the dark nearest it. Nothing to drive off at home, taken or
## gone.
func drive_off(seconds: float, _from: Vector3) -> void:
	if state in ["release", "lair", "gone", "held", "below"]:
		return
	driven += 1
	_go_below()
	below_t = seconds


## The chase's own rules (Pursuit, bosses.json gives_up): too far, out of
## its sight and hearing too long, your torch put out. Given up, it goes
## back to its rounds.
func _chase(delta: float) -> void:
	if not noticed:
		return
	var d := _flat(player.global_position - head).length()
	if pursuit.step(delta, perceives, d, _torch_lit()):
		noticed = false
		if state in ["hunt", "hang", "strike", "watch"]:
			_next_round()


## Gives you up (the watch ran out, it was taken home, you woke).
func _let_go(why: String) -> void:
	noticed = false
	pursuit.give_up(why)


## Whatever strike was under way, off.
func _calm() -> void:
	strike.cancel()
	mouth_open = false
	lunge = 0.0


# --- The states ----------------------------------------------------------------

func _coil_tick(delta: float) -> void:
	if coiling:
		_sway = move_toward(_sway, 0.0, delta * 2.0)
		if _advance(num("speed_mps", 2.0) * 0.6, delta):
			coiling = false
			coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0)
		lift = move_toward(lift, 0.12, delta)
		return
	speed = 0.0
	lift = move_toward(lift, 0.12, delta * 0.5)
	coil_left -= delta
	if coil_left <= 0.0:
		_next_round()


## The next round: to another dark dead end it can reach through the dark
## (the farther the likelier), else the farthest dark it can reach.
func _next_round() -> void:
	_calm()
	var reach := ground.reach(node)
	var cands: Array = []
	var total := 0.0
	for id in reach:
		if int(id) == node or not ground.dead_end(int(id)):
			continue
		cands.append(int(id))
		total += float(reach[id]) + 5.0
	var pick := -1
	if not cands.is_empty():
		var r := _rng.randf() * total
		for id in cands:
			r -= float(reach[id]) + 5.0
			if r <= 0.0:
				pick = id
				break
		if pick < 0:
			pick = int(cands[-1])
	else:
		var far := 0.0
		for id in reach:
			if int(id) != node and float(reach[id]) > far and str(ground.nodes[id].kind) == "room":
				far = float(reach[id])
				pick = int(id)
	if pick < 0:
		# Nowhere else in its dark: coil where it is.
		state = "coil"
		coiling = false
		coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0) * 0.5
		return
	target = pick
	var path := ground.path(node, pick, true)
	_set_route(_route_nodes(path, _room_entry(pick)))
	state = "prowl"


func _prowl_tick(delta: float) -> void:
	_sway = move_toward(_sway, 1.0, delta)
	lift = move_toward(lift, 0.08, delta)
	if _advance(num("speed_mps", 2.0), delta):
		# Arrived: coil (§EY.3: "coils in dead ends between rounds").
		var c := _coil_spot(target)
		var pts := PackedVector3Array()
		for p in _spiral(c, base):
			pts.append(p)
		_set_route(pts)
		state = "coil"
		coiling = true


func _hunt_tick(delta: float) -> void:
	_sway = move_toward(_sway, 0.7, delta)
	var pp := player.global_position
	var pn := ground.node_at(pp)
	if not ground.is_ground(pn):
		_go_watch(pn)
		return
	var torch_lit := _torch_lit()
	var delay := sub("torch_delay")
	var hang_m := float(delay.get("hang_m", 3.5))
	var hang_s := float(delay.get("hang_s", 4.0))
	var holding := torch_lit and not struck and hang_t < hang_s
	var stop := hang_m if holding else strike.reach_m * 0.7
	var d := _flat(pp - base).length()
	if d <= stop + 0.1 and _same_dark(pn):
		if holding:
			state = "hang"
		else:
			state = "strike"
			strike.begin()
		return
	_replan_t -= delta
	if _replan_t <= 0.0 or pn != _player_node:
		_replan_t = 0.4
		_player_node = pn
		var path := ground.path(node, pn, true)
		if path.is_empty():
			_go_watch(pn)
			return
		var pts := _route_nodes(path, Vector3(pp.x, _floor_y(pp), pp.z))
		_set_route(_trim(pts, stop))
	lift = move_toward(lift, 0.35, delta)
	_advance(num("hunt_mps", 3.6), delta)


## You and it in one stretch of dark (or next to each other in it): close
## enough to rear at, nothing lit between.
func _same_dark(pn: int) -> bool:
	if pn == node:
		return true
	return not ground.link(node, pn).is_empty() and ground.is_ground(pn)


## Flat direction `from` turned toward `to` by share `k` (0-1).
static func _turn(from: Vector3, to: Vector3, k: float) -> Vector3:
	var v := from.lerp(to, k)
	if v.length() < 1e-3:
		# Straight about: turn through the side.
		v = from.lerp(Vector3(-from.z, 0.0, from.x), 0.5)
	return v.normalized()


func _face(p: Vector3, delta: float) -> void:
	var v := _flat(p - base)
	if v.length() > 0.01:
		dir = _turn(dir, v.normalized(), clampf(delta * 8.0, 0.0, 1.0))


func _hang_tick(delta: float) -> void:
	var pp := player.global_position
	var pn := ground.node_at(pp)
	speed = 0.0
	_face(pp, delta)
	lift = move_toward(lift, 0.85, delta * 1.5)
	hang_t += delta
	_hiss_t -= delta
	if _hiss_t <= 0.0:
		_hiss_t = _rng.randf_range(1.2, 2.2)
		_play_hiss()
	var delay := sub("torch_delay")
	var d := _flat(pp - base).length()
	if not ground.is_ground(pn):
		_go_watch(pn)
	elif not _torch_lit() or hang_t >= float(delay.get("hang_s", 4.0)) or d > float(delay.get("hang_m", 3.5)) + 1.2:
		# The flame has held it long enough (or there is none): it comes.
		state = "hunt"
		_replan_t = 0.0


## The strike (CreatureStrike): the pose follows its parts.
func _strike_tick(delta: float) -> void:
	var pp := player.global_position
	var pn := ground.node_at(pp)
	var d := _flat(pp - base).length()
	speed = 0.0
	_face(pp, delta)
	var k := strike.pose_k()
	if strike.winding_up() and not ground.is_ground(pn):
		# You stepped into the light in its wind-up: it breaks off.
		_calm()
		_go_watch(pn)
		return
	match strike.state:
		"wind_up":
			# Reared back, jaws opening: its tell (the hiss is the strike's).
			lift = move_toward(lift, 0.95, delta * 2.5)
			lunge = lerpf(lunge, -0.3, clampf(delta * 6.0, 0.0, 1.0))
			mouth_open = k > 0.5
		"strike":
			lunge = lerpf(-0.3, clampf(d - 0.35, 0.0, strike.reach_m), k)
			lift = move_toward(lift, 0.55, delta * 4.0)
			mouth_open = true
		"recover":
			lunge = move_toward(lunge, 0.0, delta * 3.0)
			lift = move_toward(lift, 0.75, delta)
			mouth_open = k < 0.3
		"reel":
			# Staggered (§FA.1): thrown back from the swing, jaws shut.
			_reel(strike.take_reel())
			lift = move_toward(lift, 0.3, delta * 3.0)
			lunge = move_toward(lunge, 0.0, delta * 4.0)
			mouth_open = false
		_:
			mouth_open = false
			lunge = move_toward(lunge, 0.0, delta * 3.0)
			if not ground.is_ground(pn):
				_go_watch(pn)
			elif d <= strike.reach_m * 1.05 and _same_dark(pn):
				strike.begin()
			else:
				state = "hunt"
				_replan_t = 0.0


## A strike reached you (CreatureStrike.on_hit): one hit
## (contact.strike_is_hit; Harm's breath between hits holds), unless you
## stand in the light (rule.relit_room safe).
func _on_strike_hit(_target: Node3D) -> void:
	if not bool(CONTACT.get("strike_is_hit", true)):
		return
	if not ground.is_ground(ground.node_at(player.global_position)):
		return
	var before := Harm.instance.landed if Harm.instance != null else 0
	player.death_cause = "creature:%s" % name_text
	player.take_hit(1.0, strike.global_position)
	if Harm.instance != null and Harm.instance.landed > before:
		hits_landed += 1
	pursuit.hit(_torch_lit())


## Staggered: this frame's share `v` of the reel (flat, away from the
## swing; CreatureStrike.take_reel). Back along its own body when the body
## leads away from the swing (it came at you along it) and lies in its
## dark; when it doesn't (it struck from its coil, or round a corner),
## straight away from the swing, its body following, stopping at stone and
## at the edge of its dark. Chosen once for each reel.
func _reel(v: Vector3) -> void:
	var m := v.length()
	if strike.stagger_frame != _reel_frame:
		_reel_frame = strike.stagger_frame
		# The body starts where the head is drawn, so the head never jumps.
		_push_trail(head)
		var from := strike.reel_from
		var back := _back_along(strike.reel_m)
		_reel_back = _flat(back - from).length() >= _flat(head - from).length() + strike.reel_m * 0.5 and _dark_along(strike.reel_m)
	if m < 1e-5:
		return
	if _reel_back:
		_recoil(m)
		return
	var to := head + v
	to.y = _floor_y(to)
	var tn := ground.node_at(to)
	if tn < 0 or not ground.is_ground(tn) or _blocked(head + Vector3(0, 0.3, 0), to + Vector3(0, 0.3, 0)):
		return
	head = to
	base = to
	_push_trail(head)
	_track_node()


## Where its head would be `m` metres back along its own body.
func _back_along(m: float) -> Vector3:
	if trail.size() < 2:
		return base
	var left := m
	var at: Vector3 = trail[0]
	for i in range(1, trail.size()):
		var nxt: Vector3 = trail[i]
		var l := at.distance_to(nxt)
		if l >= left:
			return at.lerp(nxt, left / maxf(l, 1e-4))
		left -= l
		at = nxt
	return at


## Whether the first `m` metres of its body lie all in its dark.
func _dark_along(m: float) -> bool:
	var s := 0.0
	while s <= m + 1e-3:
		if not ground.is_ground(ground.node_at(_seg_at(s))):
			return false
		s += 0.25
	return true


## Drawn back `m` metres along its own body (a stagger's reel).
func _recoil(m: float) -> void:
	var left := m
	while left > 0.0 and trail.size() > 2:
		var a: Vector3 = trail[0]
		var b: Vector3 = trail[1]
		var l := a.distance_to(b)
		if l <= left:
			trail.pop_front()
			left -= l
		else:
			trail[0] = a.lerp(b, left / maxf(l, 1e-4))
			left = 0.0
	if not trail.is_empty():
		base = trail[0]
		head = base
		_track_node()


## You are in the light: to the edge of its dark nearest you, and wait.
func _go_watch(pn: int) -> void:
	var reach := ground.reach(node)
	var pp := player.global_position
	var best := {}
	var best_d := INF
	for id in reach:
		for l in ground.nodes[id].links:
			if ground.is_ground(int(l.to)):
				continue
			var dd := (l.via as Vector3).distance_to(pp)
			if dd < best_d:
				best_d = dd
				best = {"from": int(id), "via": l.via, "to": int(l.to), "door": int(l.door)}
	_calm()
	if best.is_empty():
		_next_round()
		return
	var path := ground.path(node, int(best.from), true)
	var via: Vector3 = best.via
	var into := _flat(via - (ground.nodes[int(best.from)].center as Vector3)).normalized()
	var stand := via - into * 0.9
	stand.y = _floor_y(stand)
	_set_route(_route_nodes(path, stand))
	if state != "watch":
		watch_t = 0.0
	state = "watch"


func _watch_tick(delta: float) -> void:
	_sway = move_toward(_sway, 0.4, delta)
	var pp := player.global_position
	var pn := ground.node_at(pp)
	if ground.is_ground(pn) and noticed:
		state = "hunt"
		_replan_t = 0.0
		return
	if route_i < route.size():
		_advance(num("hunt_mps", 3.6), delta)
		lift = move_toward(lift, 0.3, delta)
	else:
		speed = 0.0
		_face(pp, delta)
		lift = move_toward(lift, 0.6, delta)
		watch_t += delta
		if watch_t >= num("watch_s", 10.0):
			# It gives you up and goes back to its rounds.
			_let_go("watch")
			_next_round()


## Its node was lit round it: off to the nearest dark at once, across no
## more than LEAVE_LIT_MAX more lit nodes; cut off deeper in the light, down
## into the dark below.
func _leave() -> void:
	var path := ground.nearest_dark(node)
	_calm()
	if path.is_empty() or ground.lit_on(path) > LEAVE_LIT_MAX + 1:
		_go_below()
		return
	var to := int(path[-1])
	var end: Vector3 = ground.nodes[to].center
	if str(ground.nodes[to].kind) == "room":
		end = _room_entry(to)
	_set_route(_route_nodes(path, end))
	state = "leave"
	target = to


## Cut off in the light: it goes down into the dark under the tomb. While
## you can see it, it slides off toward its hole; the moment you can't (at
## once, if you can't now), it is gone.
func _go_below() -> void:
	state = "below"
	_let_go("below")
	_calm()
	below_t = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0)
	var path: Array = []
	if lair_node >= 0:
		path = ground.path(node, lair_node, false)
	if not path.is_empty() and _in_view():
		_set_route(_route_nodes(path, lair.pos))
		_vanish_t = 6.0
	else:
		_vanish()


func _below_tick(delta: float) -> void:
	if _vanish_t >= 0.0:
		_sway = move_toward(_sway, 1.0, delta)
		_vanish_t -= delta
		var done := _advance(num("leave_mps", 4.0), delta)
		if done or _vanish_t <= 0.0 or not _in_view():
			_vanish()
		return
	below_t -= delta
	if below_t <= 0.0:
		_come_up()


## Up again from below: out of its hole if the hole's room is dark, else in
## the dark nearest the hole, out of your sight.
func _come_up() -> void:
	if ground.ground_count() == 0:
		return
	if lair_node >= 0 and ground.is_ground(lair_node):
		# Out of the hole: the body still down it, the head at its mouth.
		var c: Vector3 = lair.pos
		var pts: Array = []
		var depth := float(sub("body").get("length_m", 9.0)) + 1.0
		var k := depth
		while k >= 0.0:
			pts.append(c - Vector3(0.0, k, 0.0))
			k -= 0.25
		_trail_from(pts)
		base = c
		head = c
		node = lair_node
		body.visible = body.baked
		_next_round()
		return
	var from := lair_node if lair_node >= 0 else node
	var dist := _all_dist(from)
	var best := -1
	var best_d := INF
	for id in dist:
		if ground.is_ground(int(id)) and float(dist[id]) < best_d:
			best_d = float(dist[id])
			best = int(id)
	if best < 0:
		return
	if str(ground.nodes[best].kind) == "room":
		_lie_coiled(best)
	else:
		_lie_along(best)
	body.visible = body.baked


## Lying along corridor stretch `id`, head toward its far end.
func _lie_along(id: int) -> void:
	var n: Dictionary = ground.nodes[id]
	var pc: Dictionary = lay.pieces[int(n.piece)]
	var a0 := float(n.a0)
	var a1 := float(n.a1)
	var pts: Array = []
	var length := float(sub("body").get("length_m", 9.0))
	# Back along the corridor past the stretch's start if it is short (the
	# tail may lie in the next stretch).
	var k := a1 - 0.3 - length
	while k <= a1 - 0.3:
		pts.append(BossGround.point(pc, clampf(k, 0.0, float(pc.len)), 0.0))
		k += 0.25
	_trail_from(pts)
	base = pts[-1]
	head = base
	dir = _flat(BossGround.point(pc, a1, 0.0) - BossGround.point(pc, a0, 0.0)).normalized()
	if dir.length() < 0.5:
		dir = Vector3.FORWARD
	node = ground.node_at(base)
	target = id
	state = "coil"
	coiling = false
	coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0) * 0.5
	route = PackedVector3Array()
	route_i = 0


func _leave_tick(delta: float) -> void:
	_sway = move_toward(_sway, 1.0, delta * 2.0)
	lift = move_toward(lift, 0.1, delta)
	if _advance(num("leave_mps", 4.0), delta) or (ground.is_ground(node) and route_i >= route.size() - 1):
		if not ground.is_ground(node):
			_leave()
			return
		state = "hunt" if noticed else "prowl"
		if state == "prowl":
			_next_round()
		_replan_t = 0.0


# --- The last light -------------------------------------------------------------

## The dungeon's last holder has caught (rule.last_light to_lair): it goes
## home, and the tomb hears it go.
func release() -> void:
	if released:
		return
	released = true
	state = "release"
	_calm()
	_let_go("home")
	var line := str(RELEASE.get("log_line", "Drove the {boss} into its hole")).format({"boss": name_text})
	GameLog.add(line + ".", "boss")
	# The way home: along the tomb to the hole and down it.
	var pts: Array = [head]
	if lair_node >= 0:
		for p in _route_nodes(ground.path(node, lair_node, false), lair.pos):
			pts.append(p)
	else:
		pts.append(head + dir * 8.0)
	var bottom: Vector3 = (pts[-1] as Vector3) - Vector3(0.0, 2.5, 0.0)
	pts.append(bottom)
	_cry_path = pts
	_cry_t = 0.0
	if bool(RELEASE.get("cry_to_lair", true)):
		_cry.global_position = head
		Audio3D.play(_cry)
	# Seen: it flees toward the hole, gone the moment you can't see it;
	# else it is gone now.
	if _in_view() and lair_node >= 0:
		var flee := PackedVector3Array()
		for k in range(1, pts.size()):
			flee.append(pts[k])
		_set_route(flee)
		_vanish_t = 6.0
	else:
		_vanish()


func _vanish() -> void:
	_vanish_t = -1.0
	body.visible = false
	route = PackedVector3Array()
	route_i = 0


func _release_tick(delta: float) -> void:
	if _vanish_t >= 0.0:
		_sway = move_toward(_sway, 1.0, delta)
		_vanish_t -= delta
		var done := _advance(num("leave_mps", 4.0) * 1.3, delta)
		if done or _vanish_t <= 0.0 or not _in_view():
			_vanish()
	# The cry goes along the way home and down the hole.
	if _cry_t >= 0.0:
		var cs := float(RELEASE.get("cry_s", 5.0))
		_cry_t += delta
		_cry.global_position = _along(_cry_path, clampf(_cry_t / cs, 0.0, 1.0))
		if _cry_t >= cs:
			_cry_t = -1.0
			_home()


## In its hole for good: breathing, below.
func _home() -> void:
	_vanish()
	if lair.is_empty():
		state = "gone"
	else:
		state = "lair"
		base = lair.pos
		head = base
		node = lair_node
		Audio3D.play(_breath)
	_bed_t = 0.0


## The point `u` (0-1) of the way along polyline `pts`.
func _along(pts: Array, u: float) -> Vector3:
	if pts.size() < 2:
		return pts[0] if not pts.is_empty() else Vector3.ZERO
	var total := 0.0
	for i in range(pts.size() - 1):
		total += (pts[i] as Vector3).distance_to(pts[i + 1])
	var want := total * u
	for i in range(pts.size() - 1):
		var l := (pts[i] as Vector3).distance_to(pts[i + 1])
		if want <= l:
			return (pts[i] as Vector3).lerp(pts[i + 1], want / maxf(l, 1e-4))
		want -= l
	return pts[-1]


## Can you see it: in the frame, nothing between.
func _in_view() -> bool:
	if not is_inside_tree() or not body.visible:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	for p: Vector3 in [head + Vector3(0, 0.3, 0), _seg_at(float(sub("body").get("length_m", 9.0)) * 0.3)]:
		if cam.is_position_in_frustum(p) and not _blocked(cam.global_position, p, false):
			return true
	return false


# --- You were taken --------------------------------------------------------------

## You wake at the hearth (CrawlerMain): it lets you go and goes back to its
## rounds, from far off.
func after_wake() -> void:
	_let_go("wake")
	_calm()
	hang_t = 0.0
	struck = false
	if state in ["release", "lair", "gone"]:
		return
	state = "coil"
	_start_far()


# --- The body and the sound -------------------------------------------------

## The point `s` metres back along the body from the head.
func _seg_at(s: float) -> Vector3:
	var acc := 0.0
	for i in range(trail.size() - 1):
		var a: Vector3 = trail[i]
		var b: Vector3 = trail[i + 1]
		var l := a.distance_to(b)
		if acc + l >= s:
			return a.lerp(b, (s - acc) / maxf(l, 1e-4))
		acc += l
	return trail[-1] if not trail.is_empty() else head


func _pose() -> void:
	if body == null:
		return
	if not body.visible and not (state in ["release", "lair", "gone", "below"]) and body.baked:
		body.visible = true
	var seg_pos: Array = []
	var seg_dir: Array = []
	var n := body.segs.size()
	var want := body.head_len * 0.45
	var i := 0
	var acc := 0.0
	var k := 0
	var last_dir := -dir
	while i < n:
		var p: Vector3
		var dv: Vector3
		if k < trail.size() - 1:
			var a: Vector3 = trail[k]
			var b: Vector3 = trail[k + 1]
			var l := a.distance_to(b)
			if acc + l < want:
				acc += l
				k += 1
				continue
			p = a.lerp(b, (want - acc) / maxf(l, 1e-4))
			dv = _flat(a - b)
			if dv.length() > 1e-4:
				last_dir = -dv.normalized()
		else:
			# Past the trail's end: straight on back.
			var end: Vector3 = trail[-1] if not trail.is_empty() else head
			p = end + last_dir * (want - acc)
			dv = -last_dir
		# The neck rises with the head and reaches with the lunge.
		if i < NECK:
			var w := pow(1.0 - float(i) / NECK, 1.6)
			p += Vector3.UP * lift * w + dir * lunge * w * 0.6
		seg_pos.append(p)
		seg_dir.append(dv.normalized() if dv.length() > 1e-4 else dir)
		want += body.spacing
		i += 1
	var hp := head + Vector3.UP * lift + dir * lunge
	body.pose(hp, dir, mouth_open, seg_pos, seg_dir)
	# Where a swing has to reach to stagger it, and where its strike comes
	# from: its head.
	strike.global_position = hp + Vector3(0.0, 0.2, 0.0)
	# The tell sits in the body's thick, behind the head.
	if not seg_pos.is_empty():
		_tell.global_position = seg_pos[mini(4, seg_pos.size() - 1)]
		_hiss.global_position = hp


## Its hiss at your flame while it holds off (the strike's own voice,
## bosses.json strike.sound).
func _play_hiss() -> void:
	if _hiss == null:
		return
	_hiss.stream = SoundSynth.stream(str(sub("strike").get("sound", "snake_hiss")), _rng.randi())
	Audio3D.play(_hiss)


## The tell: loud on the move, softer reared and still, quiet coiled; none
## once it has gone home.
func _sound_tick(delta: float) -> void:
	if _tell == null:
		return
	var want := -INF
	match state:
		"prowl", "hunt", "leave":
			want = 0.0
		"coil":
			want = -2.0 if coiling else -14.0
		"hang", "strike", "watch", "held":
			want = -8.0 if speed < 0.1 else -2.0
		"release", "below":
			want = -2.0 if _vanish_t >= 0.0 else -INF
	if want == -INF:
		if _tell.playing:
			_tell.stop()
		return
	if not _tell.playing and _tell.is_inside_tree():
		Audio3D.play(_tell)
	_tell.volume_db = lerpf(_tell.volume_db, want, clampf(delta * 3.0, 0.0, 1.0))
	var base_speed := maxf(num("speed_mps", 2.0), 0.1)
	_tell.pitch_scale = clampf(0.75 + 0.25 * speed / base_speed, 0.7, 1.3) if state != "coil" or coiling else 0.72


## The tomb's small sounds (release.bed_returns): hushed while it prowls,
## back once it has gone home.
func _bed_tick(delta: float) -> void:
	if bed == null:
		return
	var hush := float(RELEASE.get("bed_hush_db", -18.0)) if bool(RELEASE.get("bed_returns", true)) else 0.0
	var want := bed_db + hush
	if state in ["lair", "gone"]:
		if _bed_t >= 0.0:
			_bed_t += delta
		var k := clampf(_bed_t / maxf(float(RELEASE.get("bed_return_s", 4.0)), 0.1), 0.0, 1.0)
		want = lerpf(bed_db + hush, bed_db, k)
		bed.volume_db = want
		return
	bed.volume_db = want
