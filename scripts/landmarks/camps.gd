class_name Camps
extends Node
## Living camps: a fire burning and a few folk sitting round it, talking,
## looking about, turning to watch you come up, and a line of chatter
## when you step into the firelight. They're found:
##   * in inhabited ruins (Ruins.inhabited(): about half), at the spot the
##     ruin's builder left for a fire (RuinBuilder: the survivors' fire
##     ring, a castle courtyard, a tower's foot, under an arch, among the
##     igloos, beneath the treehouses, where the boardwalk starts);
##   * in the wild: flat, dry ground beside a river or lake, one in a few
##     grid cells;
##   * in rock shelters: at the foot of a cliff (TerrainField escarpments),
##     under a great slab of rock jutting out overhead.
## Who sits there depends on the place (Ruins.camp_folk(), country()):
## tribal folk in most land, fur-clad northerners in snow, hooded marsh
## folk, goblins squatting round the fire with their lanterns (some rock
## shelters and stone ruins), and at some stone ruins the restless dead,
## skeletons and a hooded one keeping them company.
##
## Built when the player comes within BUILD_M, freed past DROP_M. The
## folk are placeholder bodies (CreatureBodies), seated by bending the
## leg and arm pivots.

const BUILD_M := 220.0
const DROP_M := 280.0
const WILD_CELL_M := 1800.0
const WILD_CHANCE := 0.3
const WILD_SALT := 777
const CLIFF_CELL_M := 1500.0
const CLIFF_CHANCE := 0.6
const CLIFF_SALT := 778
const SEAT_R := 2.0
const NOTICE_M := 12.0
const TALK_M := 5.0

const FOLK := {
	"tribal": {"names": ["Hunter", "Elder", "Gatherer", "Scout"], "warm": Color(1.0, 0.62, 0.3),
		"lines": ["Sit. The fire's warm.", "The rivers run high this season.", "Stay near the light after dark.",
			"We saw something moving on the ridge last night.", "Eat, if you're hungry. There's enough."]},
	"north": {"names": ["Northerner", "Trapper", "Old one"], "warm": Color(1.0, 0.7, 0.4),
		"lines": ["Cold tonight. Colder tomorrow.", "Keep your hands near the flame.",
			"The ice sings when the moon is full.", "Don't wander past the drifts after dark."]},
	"marsh": {"names": ["Marsh-dweller", "Reed-cutter", "Hooded one"], "warm": Color(0.9, 0.8, 0.45),
		"lines": ["Mind the planks. Some are rotten.", "Things drift up out of the water at night.",
			"The frogs go quiet before it comes.", "Stay on the boards, stranger."]},
	"goblin": {"names": ["Goblin", "Goblin", "Old goblin"], "warm": Color(1.0, 0.6, 0.25),
		"lines": ["Shinies? You got shinies?", "Hehe. The big one's back.", "Don't touch the pot!",
			"We saw you coming. We always see.", "Sit, sit. Nobody bites. Much."]},
	"dead": {"names": ["Skeleton", "Hooded one", "Old bones"], "warm": Color(1.0, 0.55, 0.25),
		"lines": ["...we were kings here, once.", "Sit, wanderer. We have all the time there is.",
			"The fire remembers us.", "Don't mind us. We're only resting.", "Is it night again? It's always night."]},
}

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var landmarks: Landmarks
var hud: Hud
var map: PlanetData

var _root: Node3D
var _camps := {} # key -> Node3D
var _timer := 0.0
var _time := 0.0
var _wild := {} # Vector3i -> site dict or {}
var _cliff := {} # Vector3i -> site dict or {}


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_landmarks: Landmarks, p_hud: Hud) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	landmarks = p_landmarks
	hud = p_hud
	map = world.planet
	_root = Node3D.new()
	_root.name = "Camps"
	world.world_root.add_child(_root)


## A wild camp in grid cell `c`, or {}: {"dir", "folk", "seed"}.
static func wild_site(map: PlanetData, c: Vector3i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c, WILD_SALT])
	if rng.randf() > WILD_CHANCE:
		return {}
	var n := CreatureSpawner._cells_per_face(WILD_CELL_M)
	var center := CreatureSpawner._cell_point(c, n, WILD_SALT)
	for i in 14:
		var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * WILD_CELL_M * 0.4)
		var cell := map.cell_at(p)
		if map.water[cell] != PlanetData.Water.NONE:
			continue
		# Next to a river or lake (the blueprint measures in whole ~1 km
		# cells: 1.04 is the cell beside one).
		if map.water_dist_km[cell] > 1.1:
			continue
		var e := map.terrain.elevation(p, true)
		if e < 2.0:
			continue
		var slope := absf(map.terrain.elevation(CreatureSpawner._offset(p, 0.0, 6.0), true) - map.terrain.elevation(CreatureSpawner._offset(p, PI, 6.0), true)) / 12.0
		if slope > 0.12:
			continue
		var land := Ruins.country(map, p)
		var folk := "north" if land == "snow" else ("marsh" if land == "marsh" else "tribal")
		return {"dir": p, "folk": folk, "seed": hash([c, "wild"])}
	return {}


## A rock-shelter camp in grid cell `c`, or {}: {"dir" (the fire),
## "cliff" (bearing toward the cliff), "height" (m), "folk", "seed"}.
static func cliff_site(map: PlanetData, c: Vector3i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c, CLIFF_SALT])
	if rng.randf() > CLIFF_CHANCE:
		return {}
	var n := CreatureSpawner._cells_per_face(CLIFF_CELL_M)
	var center := CreatureSpawner._cell_point(c, n, CLIFF_SALT)
	for i in 40:
		var p := CreatureSpawner._offset(center, rng.randf() * TAU, sqrt(rng.randf()) * CLIFF_CELL_M * 0.45)
		if map.water[map.cell_at(p)] != PlanetData.Water.NONE:
			continue
		var e := map.terrain.elevation(p, true)
		if e < 3.0:
			continue
		for k in 8:
			var a := k * TAU / 8.0
			var wall := map.terrain.elevation(CreatureSpawner._offset(p, a, 7.0), true) - e
			if wall < 8.0:
				continue
			# Open, flat ground on the other side for the fire and seats.
			var fire := CreatureSpawner._offset(p, a + PI, 3.5)
			var ef := map.terrain.elevation(fire, true)
			var flat := absf(map.terrain.elevation(CreatureSpawner._offset(fire, a + PI, 3.0), true) - ef) + absf(map.terrain.elevation(CreatureSpawner._offset(fire, a + PI * 0.5, 3.0), true) - ef)
			if flat > 1.2:
				continue
			var land := Ruins.country(map, fire)
			var folk := "north" if land == "snow" else ("marsh" if land == "marsh" else "tribal")
			# Goblins hole up under rocks in milder country.
			if land == "" and map.sample(map.temp_c, fire) > 8.0 and rng.randf() < 0.45:
				folk = "goblin"
			return {"dir": fire, "cliff": a, "height": wall, "folk": folk, "seed": hash([c, "cliff"])}
	return {}


## Per frame.
func update_camps(delta: float) -> void:
	_time += delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_refresh()
	var pp := player.global_position
	for key in _camps:
		_animate(_camps[key], delta, pp)


func _refresh() -> void:
	var pp := player.global_position
	var pd: Vector3 = world.dir_of(pp)
	var want := {}
	# Inhabited ruins, from the ruins Landmarks has built.
	var ruins := landmarks.built_ruins()
	for c in ruins:
		var node: Node3D = ruins[c]
		var site: Dictionary = node.get_meta("site")
		if not Ruins.inhabited(site):
			continue
		var spot: Vector3 = node.global_transform * (node.get_meta("camp_spot") as Vector3)
		if spot.distance_to(pp) < BUILD_M:
			want["ruin:%s" % str(c)] = [spot, Ruins.camp_folk(site), site.seed]
	# Wild camps near water.
	for c in CreatureSpawner._cells_around(pd, BUILD_M, WILD_CELL_M):
		if not _wild.has(c):
			_wild[c] = wild_site(map, c)
		var ws: Dictionary = _wild[c]
		if ws.is_empty():
			continue
		var spot: Vector3 = world.to_scene(ws.dir, PlanetConst.RADIUS_M + chunks.ground_height(ws.dir))
		if spot.distance_to(pp) < BUILD_M:
			want["wild:%s" % str(c)] = [spot, ws.folk, ws.seed]
	# Rock shelters under cliffs.
	for c in CreatureSpawner._cells_around(pd, BUILD_M, CLIFF_CELL_M):
		if not _cliff.has(c):
			_cliff[c] = cliff_site(map, c)
		var cs: Dictionary = _cliff[c]
		if cs.is_empty():
			continue
		var spot: Vector3 = world.to_scene(cs.dir, PlanetConst.RADIUS_M + chunks.ground_height(cs.dir))
		if spot.distance_to(pp) < BUILD_M:
			want["cliff:%s" % str(c)] = [spot, cs.folk, cs.seed, cs]
	for key in want:
		if not _camps.has(key):
			var w: Array = want[key]
			_camps[key] = _build(w[0], w[1], w[2])
			if w.size() > 3:
				_overhang(_camps[key], w[3])
	for key in _camps.keys():
		var node: Node3D = _camps[key]
		if node.global_position.distance_to(pp) > DROP_M:
			NodeRelease.free_later(node)
			_camps.erase(key)


## A camp at scene position `at`: the fire, seats, and folk facing it.
func _build(at: Vector3, folk: String, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var info: Dictionary = FOLK[folk]
	var d: Vector3 = world.dir_of(at)
	var root := Node3D.new()
	root.name = "Camp"
	_root.add_child(root)
	root.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(d), d), at)
	var fire := Campfire.build(root, world, chunks, d, info.warm, false)
	fire.global_position = at
	root.set_meta("fire", fire)
	root.set_meta("folk", folk)
	root.set_meta("talked", false)
	var count := rng.randi_range(2, 4)
	var a0 := rng.randf() * TAU
	var sitters: Array[Node3D] = []
	for i in count:
		var a := a0 + TAU * i / count + rng.randf_range(-0.25, 0.25)
		var seat_pos := Vector3(cos(a), 0, sin(a)) * SEAT_R
		# Seat: a log across, a flat stone among the dead; goblins squat.
		if folk == "goblin":
			pass
		elif folk == "dead":
			var stone := CreatureBodies.box(root, Vector3(0.6, 0.4, 0.5), seat_pos + Vector3(0, 0.2, 0), Color(0.42, 0.42, 0.44))
			stone.rotation.y = -a
		else:
			var log_seat := CreatureBodies.cone(root, 0.17, 0.17, 1.1, seat_pos + Vector3(0, 0.17, 0), Color(0.36, 0.25, 0.16))
			log_seat.rotation = Vector3(0, -a, PI * 0.5)
		var holder := _sitter(root, folk, i, rng)
		holder.position = seat_pos
		# Face the fire.
		holder.basis = Basis.looking_at(-seat_pos.normalized(), Vector3.UP)
		holder.set_meta("base_yaw", holder.rotation.y)
		holder.set_meta("phase", rng.randf() * TAU)
		sitters.append(holder)
		# Tribal and northern folk keep their weapons at hand: a spear
		# leaning on the log, or a bow laid by it.
		if folk == "tribal" or folk == "north":
			var side := Vector3(-sin(a), 0, cos(a)) * 0.75
			if i % 3 == 2:
				var bow := BowMesh.build(1.2)
				root.add_child(bow)
				bow.position = seat_pos * 1.25 + side + Vector3(0, 0.05, 0)
				bow.rotation = Vector3(PI * 0.5, -a, 0.0)
			else:
				_spear(root, seat_pos * 1.3 + side, Vector3(cos(a), 0, sin(a)), 1.9)
	root.set_meta("sitters", sitters)
	# Guards: tribal and northern camps post one or two on their feet at
	# the edge of the firelight, spear or bow in hand, watching the dark.
	var guards: Array[Node3D] = []
	if folk == "tribal" or folk == "north":
		for g in rng.randi_range(1, 2):
			var a := a0 + TAU * (g + 0.5) / count + PI / count
			var at_pos := Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.5, 5.5)
			var guard := _guard(root, folk, g, rng)
			guard.position = at_pos
			# Facing outward, away from the fire.
			guard.basis = Basis.looking_at(at_pos.normalized(), Vector3.UP)
			guard.set_meta("base_yaw", guard.rotation.y)
			guard.set_meta("phase", rng.randf() * TAU)
			guards.append(guard)
	root.set_meta("guards", guards)
	return root


## A spear leaning out from `base` (camp space) along `lean`, `length` m.
func _spear(parent: Node3D, base: Vector3, lean: Vector3, length: float) -> void:
	var shaft := CreatureBodies.cone(parent, 0.018, 0.015, length, Vector3.ZERO, Color(0.42, 0.3, 0.18), 0.0, 5)
	var dirv := (Vector3.UP + lean * 0.35).normalized()
	var x := dirv.cross(Vector3.FORWARD if absf(dirv.z) < 0.9 else Vector3.RIGHT).normalized()
	shaft.transform = Transform3D(Basis(x, dirv, x.cross(dirv)), base + dirv * length * 0.5)
	var head := CreatureBodies.cone(parent, 0.035, 0.0, 0.16, Vector3.ZERO, Color(0.34, 0.35, 0.38), 0.0, 4)
	head.transform = Transform3D(Basis(x, dirv, x.cross(dirv)), base + dirv * (length + 0.08))


## A standing guard: a hunter with a spear or an archer with a bow.
func _guard(parent: Node3D, folk: String, i: int, rng: RandomNumberGenerator) -> Node3D:
	var sp := CreatureSpecies.new()
	sp.name = "Guard"
	sp.body = "tribal"
	sp.shape = "archer" if i % 2 == 1 or rng.randf() < 0.4 else "hunter"
	sp.size_m = rng.randf_range(1.72, 1.85)
	if folk == "north":
		sp.color = Color(0.78, 0.62, 0.5).darkened(rng.randf_range(0.0, 0.15))
		sp.accent = Color(0.82, 0.8, 0.76).darkened(rng.randf_range(0.0, 0.25))
	else:
		sp.color = Color(0.62, 0.44, 0.32).darkened(rng.randf_range(-0.1, 0.25))
		sp.accent = Color(0.55, 0.4, 0.26).lightened(rng.randf_range(-0.1, 0.1))
	var b := CreatureBodies.build(sp)
	var holder := Node3D.new()
	holder.name = sp.name
	parent.add_child(holder)
	var body: Node3D = b.root
	body.name = "Body"
	holder.add_child(body)
	holder.set_meta("arms", b.wings)
	holder.set_meta("head", body.get_node_or_null("Head"))
	holder.set_meta("speaker", "Guard")
	holder.set_meta("standing", true)
	var f := BlobShadow.footprint(sp)
	BlobShadow.make(holder, f.x, f.y)
	return holder


## A rock shelter over a cliff camp: a great slab jutting out from the
## cliff above the fire, and boulders either side.
func _overhang(camp: Node3D, cs: Dictionary) -> void:
	var d: Vector3 = cs.dir
	var up: Vector3 = d
	var at := camp.global_position
	var toward_d := CreatureSpawner._offset(d, cs.cliff, 5.0)
	var toward: Vector3 = world.to_scene(toward_d, PlanetConst.RADIUS_M + chunks.ground_height(d)) - at
	toward = (toward - up * toward.dot(up)).normalized()
	var along := up.cross(toward).normalized()
	var h: float = cs.height
	var rng := RandomNumberGenerator.new()
	rng.seed = cs.seed
	var col := Color(0.44, 0.43, 0.42)
	var slab := MeshInstance3D.new()
	slab.mesh = RuinBuilder.rock_mesh(Vector3(7.5, 1.8, 6.0), cs.seed, col)
	slab.material_override = RuinBuilder.material()
	camp.add_child(slab)
	slab.global_transform = Transform3D(Basis(along, up, -toward).rotated(along, 0.12), at + toward * 3.2 + up * (h * 0.8))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.5, 1.4, 5.0)
	shape.shape = bs
	body.add_child(shape)
	slab.add_child(body)
	for s in [-1.0, 1.0]:
		var rock := MeshInstance3D.new()
		var size := Vector3(rng.randf_range(1.6, 2.4), rng.randf_range(1.8, 2.8), rng.randf_range(1.6, 2.2))
		rock.mesh = RuinBuilder.rock_mesh(size, cs.seed + int(s * 7.0), col.darkened(0.05))
		rock.material_override = RuinBuilder.material()
		camp.add_child(rock)
		rock.global_transform = Transform3D(Basis(along, up, -toward).rotated(up, rng.randf() * TAU), at + along * s * 3.6 + toward * 1.8 + up * size.y * 0.35)


## One seated figure (an unscaled holder, the body under it).
func _sitter(parent: Node3D, folk: String, i: int, rng: RandomNumberGenerator) -> Node3D:
	var sp := CreatureSpecies.new()
	var names: Array = FOLK[folk].names
	sp.name = names[i % names.size()]
	sp.size_m = rng.randf_range(1.62, 1.8)
	match folk:
		"dead":
			if i == 0:
				sp.body = "robed"
				sp.color = Color(0.12, 0.2, 0.62) # deep blue robe
				sp.accent = Color(0.86, 0.82, 0.68)
				sp.name = "Hooded one"
			else:
				sp.body = "skeleton"
				sp.color = Color(0.86, 0.82, 0.68).darkened(rng.randf_range(0.0, 0.12))
				sp.name = "Skeleton"
		"goblin":
			sp.body = "goblin"
			sp.size_m = rng.randf_range(0.85, 1.05)
			sp.color = Color(0.43, 0.54, 0.23).lightened(rng.randf_range(-0.1, 0.1))
			sp.accent = Color(1.0, 0.54, 0.16)
		"marsh":
			sp.body = "robed"
			sp.color = Color(0.28, 0.34, 0.26).lightened(rng.randf_range(-0.05, 0.08))
			sp.accent = Color(0.72, 0.58, 0.46)
		"north":
			sp.body = "tribal"
			sp.shape = "elder_seated" if i % 2 == 0 else "hunter_seated"
			sp.color = Color(0.78, 0.62, 0.5).darkened(rng.randf_range(0.0, 0.15))
			sp.accent = Color(0.82, 0.8, 0.76).darkened(rng.randf_range(0.0, 0.25)) # pale furs
		_:
			sp.body = "tribal"
			sp.shape = "elder_seated" if i % 2 == 0 else "hunter_seated"
			sp.color = Color(0.62, 0.44, 0.32).darkened(rng.randf_range(-0.1, 0.25))
			sp.accent = Color(0.55, 0.4, 0.26).lightened(rng.randf_range(-0.1, 0.1))
	var b := CreatureBodies.build(sp)
	var holder := Node3D.new()
	holder.name = sp.name
	parent.add_child(holder)
	var body: Node3D = b.root
	body.name = "Body"
	holder.add_child(body)
	# Sitting: hips down to seat height, legs forward and down, arms
	# forward to rest on the knees.
	body.position.y = (0.05 - 0.3 * sp.size_m) if folk == "goblin" else (0.4 - 0.5 * sp.size_m)
	for leg in b.legs:
		(leg as Node3D).rotation.x = 1.05
	for arm in b.wings:
		(arm as Node3D).rotation.x = 0.55
	# An imported model sits with its own clip (and sits on its own feet).
	var animator: ModelAnimator = b.get("animator")
	if animator:
		body.position.y = 0.0
		animator.set_state("sit")
	holder.set_meta("arms", b.wings)
	holder.set_meta("head", body.get_node_or_null("Head"))
	holder.set_meta("speaker", sp.name)
	# Seated: the shadow reaches forward under the knees.
	var blob := BlobShadow.make(holder, 0.3 * sp.size_m, 0.4 * sp.size_m)
	blob.position.z = -0.12 * sp.size_m
	return holder


## Idle life: the fire flickers; the folk look round at each other and the
## fire, now and then lift an arm as they talk, and turn toward the player
## when close; stepping into the firelight gets a line of chatter.
func _animate(camp: Node3D, delta: float, pp: Vector3) -> void:
	Campfire.flicker(camp.get_meta("fire"), _time)
	var sitters: Array = camp.get_meta("sitters")
	var near := camp.global_position.distance_to(pp)
	for i in sitters.size():
		var s: Node3D = sitters[i]
		var ph: float = s.get_meta("phase")
		var yaw: float = s.get_meta("base_yaw")
		var target := yaw + 0.35 * sin(_time * 0.3 + ph)
		if near < NOTICE_M:
			# Turn toward the player, but no further than over a shoulder.
			var to := s.global_transform.affine_inverse() * pp
			var want := s.rotation.y + atan2(-to.x, -to.z)
			target = yaw + clampf(angle_difference(yaw, want), -1.2, 1.2)
		s.rotation.y = lerp_angle(s.rotation.y, target, clampf(delta * 1.5, 0.0, 1.0))
		# Talking hands.
		var arms: Array = s.get_meta("arms")
		var talk := maxf(sin(_time * 0.7 + ph * 3.0), 0.0)
		if not arms.is_empty():
			(arms[0] as Node3D).rotation.x = 0.55 + 0.6 * talk * talk
		var head: Node3D = s.get_meta("head")
		if head:
			head.rotation.y = 0.4 * sin(_time * 0.45 + ph)
	for g in camp.get_meta("guards", []):
		var gn: Node3D = g
		var ph: float = gn.get_meta("phase")
		var yaw: float = gn.get_meta("base_yaw")
		var target := yaw + 0.7 * sin(_time * 0.2 + ph)
		var to := gn.global_transform.affine_inverse() * pp
		if gn.global_position.distance_to(pp) < 20.0:
			target = gn.rotation.y + atan2(-to.x, -to.z)
		gn.rotation.y = lerp_angle(gn.rotation.y, target, clampf(delta * 1.2, 0.0, 1.0))
	if near < TALK_M and not camp.get_meta("talked"):
		camp.set_meta("talked", true)
		var folk: String = camp.get_meta("folk")
		var lines: Array = FOLK[folk].lines
		var s0: Node3D = sitters[0]
		hud.say(s0.get_meta("speaker"), lines[randi() % lines.size()], 0.2, 4.0)


## The camp folk (seated or on guard) an arrow flying from `a` to `b` hits
## first: [holder, fraction along a..b], or [].
func folk_on_segment(a: Vector3, b: Vector3) -> Array:
	var best: Array = []
	var best_t := INF
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 1e-6)
	for key in _camps:
		var camp: Node3D = _camps[key]
		if camp.global_position.distance_to(a) > 60.0:
			continue
		var folk: Array = camp.get_meta("sitters", [])
		folk = folk + camp.get_meta("guards", [])
		for f in folk:
			var n: Node3D = f
			var up: Vector3 = world.dir_of(n.global_position)
			var center := n.global_position + up * (0.9 if n.get_meta("standing", false) else 0.55)
			var t := clampf((center - a).dot(ab) / l2, 0.0, 1.0)
			if (a + ab * t).distance_to(center) < 0.45 and t < best_t:
				best_t = t
				best = [n, t]
	return best


const SHOT_LINES := ["Hey! Watch where you shoot!", "Oi! Put that bow down!", "Are you trying to get yourself killed?", "Aim at the deer, not at us!"]
const SHOT_LINES_DEAD := ["...that tickles.", "You can't kill what's already dead, wanderer.", "Rude."]
var _shot_cd := 0.0


## An arrow struck one of the camp folk: they don't take kindly to it.
func shot_at(folk: Node3D) -> void:
	if _time < _shot_cd:
		return
	_shot_cd = _time + 3.0
	var dead := String(folk.get_meta("speaker", "")) in ["Skeleton", "Hooded one"]
	var lines := SHOT_LINES_DEAD if dead else SHOT_LINES
	hud.say(folk.get_meta("speaker", "?"), lines[randi() % lines.size()], 0.0, 3.0)
