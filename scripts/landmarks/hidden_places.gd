class_name HiddenPlaces
extends Node
## Off the road: hidden places, and the few who speak (design 3 Oct §DJ,
## data/shrines.json → hidden). Hand-made set pieces the generator puts
## where they fit (§CJ.8), never on a road: hidden.off_road_m (150-900 m)
## from the nearest one, about hidden.per_km_of_road (0.25) to a kilometre
## of road, seeded per road, so a different world has different places.
## Placed after the roads (RoadNetwork): each link offers its own
## candidates (for_link, a pure function of the link and the planet), and
## a candidate stands only where no road, its own or another, passes
## within off_road_m[0] of it (near()).
##
## The kits (hidden.kits), each where its site fits:
##   earth_homes     two to four low doors dug into a bank, a stone lintel
##                   over each and the turf running over the roof, a small
##                   camp in front (Camps, under the camp sim: its own
##                   hearth, folk, smoke). Needs a bank (a slope to dig
##                   into), water within WATER_M, woods in reach (a forest
##                   biome here or next to it);
##   oak_door        a great old broadleaf of the place, past the top of its
##                   size band (an oak where oaks grow; else the place's
##                   tallest broadleaf passing its biome gate), on a rise,
##                   its roots gripping a stone doorway at its foot; the
##                   door is a closed stone slab (§DK builds what is
##                   behind it);
##   burning_shrine  the shrine's surface mouth only: a stone portal going
##                   into a slope, steps going down into the dark and
##                   torchlight showing inside (§DK builds the hall).
## The few who speak (hidden.speakers_share, 0.3): at about three in ten,
## one small cloaked figure stays by the place. Mute like all folk: come
## within SPEAK_M and right-click (interact) and one cryptic line
## (hidden.lines) goes into the log as "spoken", once a visit (you leave
## past VISIT_M and come back). No quest log, no markers, no choices, no
## dialogue (§BF); given and asked wait for §DK.

static var D: Dictionary = Tuning.table("shrines").get("hidden", {})
static var instance: HiddenPlaces = null
static var _cache := {}
static var _mutex := Mutex.new()
static var _queued := {}

const BUILD_M := 450.0
const DROP_M := 650.0
const SPEAK_M := 3.0
const VISIT_M := 60.0
## No two hidden places of one road nearer than this.
const SPACING_M := 400.0
## Candidates tried per expected place.
const TRIES := 14
## How far the earth homes' water may be.
const WATER_M := 500.0
## How far round each kit the trees and undergrowth keep back.
const CLEAR_M := {"earth_homes": 16.0, "oak_door": 9.0, "burning_shrine": 7.0}
## Past the top of the tree's size band (as the sacred fig, §CL).
const PAST_BAND := 1.12
## The leaf types that make a broadleaf tree.
const BROADLEAF := ["simple", "compound", "broadleaf", "glossy"]

const STONE := Color(0.46, 0.45, 0.42)
const DARK_STONE := Color(0.3, 0.29, 0.28)
const WOOD := Color(0.3, 0.2, 0.12)
const TURF := Color(0.27, 0.36, 0.15)

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var _root: Node3D
var _built := {} # key -> Node3D
var _timer := 0.0
## Speakers built now: [{"key", "node", "place"}].
var speakers: Array = []
## The keys that have spoken this visit (cleared when you leave).
var _spoke := {}
## How many visits each speaker has had (the line picked per visit).
var _visits := {}


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	instance = self
	_root = Node3D.new()
	_root.name = "HiddenPlaces"
	world.world_root.add_child(_root)


func _exit_tree() -> void:
	if instance == self:
		instance = null


# --- Placement (pure) ----------------------------------------------------------------

## The two ends' keys of `link` (RoadNetwork nodes), its identity whoever
## built it.
static func link_key(roads: RoadNetwork, link: Dictionary) -> String:
	return "%s|%s" % [str(roads.nodes[int(link.a)].key), str(roads.nodes[int(link.b)].key)]


## The hidden places `link` offers: [{"key", "kit", "dir", "facing"
## (bearing out of the door), "seed", "speaker" (bool), "link_key",
## "tree" (oak_door: [species index, height_m]), "hearth" (earth_homes:
## dir), "homes" (earth_homes: count)}], before the other roads are
## counted (near() does that). Cached per link.
static func for_link(roads: RoadNetwork, link: Dictionary, wait := true) -> Array:
	var lk := link_key(roads, link)
	_mutex.lock()
	var hit = _cache.get(lk)
	var queued := _queued.has(lk)
	if hit == null and not wait and not queued:
		_queued[lk] = true
	_mutex.unlock()
	if hit != null:
		return hit
	if not wait:
		# The main thread never places: a worker does, and the place shows
		# on a later refresh.
		if not queued:
			WorkerThreadPool.add_task(for_link.bind(roads, link, true))
		return []
	var out := _place_along(roads.map, roads.rivers, link, lk)
	_mutex.lock()
	_cache[lk] = out
	_mutex.unlock()
	return out


static func _place_along(map: PlanetData, rivers: RiverNetwork, link: Dictionary, lk: String) -> Array:
	var out: Array = []
	var pts: PackedVector3Array = link.pts
	var total := RoadNetwork.length_m(pts)
	if total < 50.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.terrain.world_seed, lk, "hidden"])
	var off: Array = D.get("off_road_m", [150.0, 900.0])
	var per_km := float(D.get("per_km_of_road", 0.25))
	var want_f := per_km * total / 1000.0
	var want := int(floor(want_f)) + (1 if rng.randf() < want_f - floor(want_f) else 0)
	var kits: Array = []
	for k in D.get("kits", []):
		kits.append(str((k as Dictionary).get("id", "")))
	for slot in want:
		# The kits in a seeded order; each gets its tries before the next,
		# so one easy kit doesn't take every place.
		var order := kits.duplicate()
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]
			order[i] = order[j]
			order[j] = t
		var placed := {}
		for kit in order:
			for attempt in TRIES:
				var m := rng.randf_range(0.0, total)
				var at := RoadNetwork.point_at(pts, m)
				var ahead := RoadNetwork.point_at(pts, minf(total, m + 20.0))
				var behind := RoadNetwork.point_at(pts, maxf(0.0, m - 20.0))
				var fwd := (ahead - behind).normalized()
				if fwd.length() < 0.5:
					continue
				var right := fwd.cross(at).normalized()
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var dist := rng.randf_range(float(off[0]) + 10.0, float(off[1]) - 10.0)
				var p := (at + right * side * dist / PlanetConst.RADIUS_M).normalized()
				var close := false
				for o in out:
					if CubeSphere.surface_distance_m(o.dir, p) < SPACING_M:
						close = true
				if close:
					continue
				placed = fits(map, rivers, p, str(kit))
				if not placed.is_empty():
					break
			if not placed.is_empty():
				break
		if placed.is_empty():
			continue
		var s := rng.randi()
		placed.seed = s
		placed.key = "hidden:%d" % s
		placed.link_key = lk
		placed.speaker = rng.randf() < float(D.get("speakers_share", 0.3))
		out.append(placed)
	return out


## Does kit `kit` fit at `p`? Its place ({"kit", "dir", "facing", ...}) or
## {}.
static func fits(map: PlanetData, rivers: RiverNetwork, p: Vector3, kit: String) -> Dictionary:
	var cell := map.cell_at(p)
	if map.water[cell] != PlanetData.Water.NONE:
		return {}
	var t := map.terrain
	var e := t.elevation(p, true)
	if e < 3.0:
		return {}
	if not Ruins.near(map, p, 150.0).is_empty():
		return {}
	# The ground's lean: uphill bearing and slope over 8 m.
	var de := t.elevation(CreatureSpawner._offset(p, PI * 0.5, 8.0), true) - t.elevation(CreatureSpawner._offset(p, -PI * 0.5, 8.0), true)
	var dn := t.elevation(CreatureSpawner._offset(p, 0.0, 8.0), true) - t.elevation(CreatureSpawner._offset(p, PI, 8.0), true)
	var slope := Vector2(de, dn).length() / 16.0
	var uphill := atan2(de, dn)
	match kit:
		"earth_homes":
			# A bank to dig into, flatter ground in front for the hearth.
			if slope < 0.08 or slope > 0.7:
				return {}
			var hearth := CreatureSpawner._offset(p, uphill + PI, 9.0)
			var hs := _slope_at(t, hearth)
			if hs > 0.22 or map.water[map.cell_at(hearth)] != PlanetData.Water.NONE:
				return {}
			if water_m(map, rivers, p) > WATER_M or not woods_near(map, p):
				return {}
			var homes := 2 + absi(hash([p, "homes"])) % 3
			return {"kit": kit, "dir": p, "facing": uphill + PI, "hearth": hearth, "homes": homes}
		"oak_door":
			if slope > 0.3:
				return {}
			var ring := 0.0
			for k in 6:
				ring += t.elevation(CreatureSpawner._offset(p, k * TAU / 6.0, 120.0), true)
			if e - ring / 6.0 < 2.5:
				return {}
			var tree := old_tree(map, p)
			if tree.is_empty():
				return {}
			# The door faces downhill (or south on the crown of the rise).
			var face := uphill + PI if slope > 0.03 else PI
			return {"kit": kit, "dir": p, "facing": face, "tree": tree}
		"burning_shrine":
			# Rock or a slope to go into.
			var steep := slope
			for k in 6:
				steep = maxf(steep, _slope_at(t, CreatureSpawner._offset(p, k * TAU / 6.0, 10.0)))
			if steep < 0.22:
				return {}
			return {"kit": kit, "dir": p, "facing": uphill + PI}
	return {}


static func _slope_at(t: TerrainField, p: Vector3) -> float:
	var de := t.elevation(CreatureSpawner._offset(p, PI * 0.5, 6.0), true) - t.elevation(CreatureSpawner._offset(p, -PI * 0.5, 6.0), true)
	var dn := t.elevation(CreatureSpawner._offset(p, 0.0, 6.0), true) - t.elevation(CreatureSpawner._offset(p, PI, 6.0), true)
	return Vector2(de, dn).length() / 12.0


## The nearest water to `p` (m): a river's line, a lake or the sea.
static func water_m(map: PlanetData, rivers: RiverNetwork, p: Vector3) -> float:
	var c := map.cell_at(p)
	var best := INF
	if rivers != null:
		for s in rivers.segments_near(map, c):
			best = minf(best, rivers.closest_dt(s, p).x)
	best = minf(best, map.coast_dist_km[c] * 1000.0 * PlanetConst.GEO_SCALE)
	for k in 8:
		for r in [150.0, 300.0, 450.0]:
			var q := CreatureSpawner._offset(p, k * TAU / 8.0, r)
			if map.water[map.cell_at(q)] == PlanetData.Water.LAKE:
				best = minf(best, r)
	return best


## Woods in reach: a forest biome here or in a neighbouring cell.
static func woods_near(map: PlanetData, p: Vector3) -> bool:
	var c := map.cell_at(p)
	if VegetationPlacer.FORESTS.has(map.biome[c]):
		return true
	for k in 8:
		var n := map.neighbors[c * 8 + k]
		if n >= 0 and VegetationPlacer.FORESTS.has(map.biome[n]):
			return true
	return false


## The great old tree for an oak door at `p`: an oak (genus Quercus) where
## an oak passes the place's biome gate (tree_gate), else the place's
## tallest broadleaf tree that does; [species index, height_m] past the
## top of its band, or [].
static func old_tree(map: PlanetData, p: Vector3) -> Array:
	var best: PlantSpecies = null
	var best_score := -INF
	for sp in SpeciesDB.all():
		if not sp.tier in [PlantSpecies.Tier.EMERGENT, PlantSpecies.Tier.CANOPY] or not sp.leaf_type in BROADLEAF:
			continue
		if not tree_gate(map, p, sp):
			continue
		var score := sp.height_m.y + (1000.0 if sp.genus == "Quercus" else 0.0)
		if score > best_score:
			best_score = score
			best = sp
	if best == null:
		return []
	return [SpeciesDB.index_of(best), best.height_m.y * PAST_BAND]


## May tree `sp` grow at `p`: the biome gate (§CA: its biomes, its realm
## where it names realms, the climate and soil there). The understory's
## community step (Overgrowth.gate) is for the plants under the trees; a
## stand's trees are dealt by dominance (§BH).
static func tree_gate(map: PlanetData, p: Vector3, sp: PlantSpecies) -> bool:
	var biome: int = map.biome[map.cell_at(p)]
	if not sp.biomes.has(biome):
		return false
	var t := map.sample(map.temp_c, p)
	var m := map.sample(map.moisture, p)
	var h := map.terrain.elevation(p, true)
	if not sp.realms.is_empty():
		var realm := RealmMap.realm(RealmMap.world_at(p), p, t, m, h / PlanetConst.HEIGHT_SCALE)
		if not sp.realms.has(realm) or not SpeciesDB.biome_hosts(biome, realm):
			return false
	return sp.suitability(t, m, h, map.soil_at(p)) > 0.0


## The hidden places within `radius` m of `d` that stand: off every road
## by at least off_road_m[0] (the roads built round them; `block` builds
## them first, as the checks do). One per place across the links.
static func near(roads: RoadNetwork, d: Vector3, radius: float, block := false) -> Array:
	var out: Array = []
	if roads == null:
		return out
	var off: Array = D.get("off_road_m", [150.0, 900.0])
	var seen := {}
	var wait := block or OS.get_thread_caller_id() != OS.get_main_thread_id()
	for link in roads.links_near(d, radius + float(off[1]), block):
		for pl in for_link(roads, link, wait):
			if seen.has(pl.key) or CubeSphere.surface_distance_m(pl.dir, d) > radius:
				continue
			seen[pl.key] = true
			var nr := RoadNetwork.nearest_in(roads.links_near(pl.dir, float(off[0]) + 20.0, block), pl.dir, float(off[0]))
			if not nr.is_empty():
				continue
			out.append(pl)
	return out


## [dir, radius_m] the trees and undergrowth keep out of (VegetationPlacer).
static func clearings_near(d: Vector3, radius: float) -> Array:
	var out: Array = []
	if RoadNetwork.instance == null:
		return out
	for pl in near(RoadNetwork.instance, d, radius + 20.0):
		out.append([pl.dir, float(CLEAR_M.get(str(pl.kit), 8.0))])
		if pl.has("hearth"):
			out.append([pl.hearth, 6.0])
	return out


## The earth homes' camps near `d` (Camps builds them): [place].
static func camps_near(d: Vector3, radius: float) -> Array:
	var out: Array = []
	if RoadNetwork.instance == null:
		return out
	for pl in near(RoadNetwork.instance, d, radius):
		if str(pl.kit) == "earth_homes":
			out.append(pl)
	return out


## The line a speaker says on visit `visit` (hidden.lines, seeded).
static func line_for(place: Dictionary, visit: int) -> String:
	var lines: Array = D.get("lines", [])
	if lines.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(place.seed), visit, "line"])
	return str(lines[rng.randi() % lines.size()])


# --- In play -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or chunks == null or chunks.roads == null or player == null:
		return
	# A visit ends when you walk away.
	for k in _spoke.keys():
		var gone := true
		for s in speakers:
			if s.key == k and is_instance_valid(s.node) and (s.node as Node3D).global_position.distance_to(player.global_position) < VISIT_M:
				gone = false
		if gone:
			_spoke.erase(k)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	refresh()


## Build what is within BUILD_M, free what is past DROP_M.
func refresh(block := false) -> void:
	var pd: Vector3 = world.dir_of(player.global_position)
	for pl in near(chunks.roads, pd, BUILD_M, block):
		if not _built.has(pl.key):
			_built[pl.key] = build(pl)
	for key in _built.keys():
		var n: Node3D = _built[key]
		if not is_instance_valid(n) or n.global_position.distance_to(player.global_position) > DROP_M:
			if is_instance_valid(n):
				NodeRelease.free_later(n)
			_built.erase(key)
	speakers = speakers.filter(func(s): return is_instance_valid(s.node))


func built() -> Dictionary:
	return _built


## The speaker within SPEAK_M of `pos` ({} if none).
func speaker_in_reach(pos: Vector3) -> Dictionary:
	for s in speakers:
		if is_instance_valid(s.node) and (s.node as Node3D).global_position.distance_to(pos) < SPEAK_M:
			return s
	return {}


## Right click by a speaker: its one line into the log, once a visit.
## True if it spoke.
func speak(s: Dictionary) -> bool:
	if s.is_empty() or _spoke.has(s.key):
		return false
	var v := int(_visits.get(s.key, 0))
	_visits[s.key] = v + 1
	_spoke[s.key] = true
	var line := line_for(s.place, v)
	if line == "":
		return false
	GameLog.add(line, "spoken")
	return true


## The set piece for `pl`, placed in the world.
func build(pl: Dictionary) -> Node3D:
	var d: Vector3 = pl.dir
	var root := Node3D.new()
	root.name = "Hidden_%s" % str(pl.kit)
	_root.add_child(root)
	root.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(d), d), world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d)))
	root.set_meta("place", pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl.seed)
	var body := PropCollision.body(root)
	match str(pl.kit):
		"earth_homes":
			_earth_homes(root, pl, rng, body)
		"oak_door":
			_oak_door(root, pl, rng, body)
		"burning_shrine":
			_burning_shrine(root, pl, rng, body)
	if bool(pl.get("speaker", false)):
		_speaker(root, pl, rng)
	return root


## Root-local position of the ground at `d` (+`lift`).
func _local(root: Node3D, d: Vector3, lift := 0.0) -> Vector3:
	return root.global_transform.affine_inverse() * world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d) + lift)


## A frame facing bearing `b` (local -z out of the door) at `d`.
func _frame(root: Node3D, d: Vector3, b: float, lift := 0.0) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	n.position = _local(root, d, lift)
	n.rotation.y = -b
	return n


## A dressed stone block (or a plank: any colour) `size` at `pos` in
## `parent`, on the ruins' material (RuinBuilder.rock_mesh as a block:
## crisp edges, its own chips).
func _block(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RuinBuilder.rock_mesh(size, hash([pos, size]), col, true)
	mi.material_override = RuinBuilder.material()
	mi.position = pos
	parent.add_child(mi)
	return mi


## A doorway: two jambs and a lintel round a door `w` × `h`, with `door`
## a slab filling it (closed) or none (open).
func _doorway(parent: Node3D, w: float, h: float, stone: Color, door: Color, body: StaticBody3D, open := false) -> void:
	var jw := 0.32
	for sx in [-1.0, 1.0]:
		var j := _block(parent, Vector3(jw, h + 0.2, 0.45), Vector3(sx * (w * 0.5 + jw * 0.5), (h + 0.2) * 0.5 - 0.1, 0.0), stone)
		PropCollision.box(body, parent.transform * j.transform, Vector3(jw, h + 0.2, 0.45))
	var l := _block(parent, Vector3(w + jw * 2.0 + 0.3, 0.32, 0.55), Vector3(0.0, h + 0.16, 0.0), stone.darkened(0.05))
	PropCollision.box(body, parent.transform * l.transform, Vector3(w + jw * 2.0 + 0.3, 0.32, 0.55))
	if not open:
		var dr := _block(parent, Vector3(w, h, 0.14), Vector3(0.0, h * 0.5, 0.12), door)
		PropCollision.box(body, parent.transform * dr.transform, Vector3(w, h, 0.14))


func _earth_homes(root: Node3D, pl: Dictionary, rng: RandomNumberGenerator, body: StaticBody3D) -> void:
	var d: Vector3 = pl.dir
	var face := float(pl.facing)
	var n := int(pl.get("homes", 3))
	for i in n:
		var lat := (i - (n - 1) * 0.5) * 6.5 + rng.randf_range(-0.8, 0.8)
		var at := CreatureSpawner._offset(CreatureSpawner._offset(d, face + PI * 0.5, lat), face + PI, 0.6)
		var f := _frame(root, at, face + rng.randf_range(-0.12, 0.12))
		var w := rng.randf_range(0.8, 0.95)
		var h := rng.randf_range(1.2, 1.4)
		_doorway(f, w, h, STONE.darkened(rng.randf_range(0.0, 0.15)), WOOD.darkened(rng.randf_range(0.0, 0.2)), body)
		# The turf over the roof: a low mound running back into the bank.
		var mound := CreatureBodies.ball(f, Vector3(2.0, 1.25, 2.5), Vector3(0.0, 0.35, 2.3), TURF.darkened(rng.randf_range(0.0, 0.12)))
		mound.name = "Turf"
		PropCollision.capsule(body, f.transform * Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(0.0, 0.4, 2.4)), 1.3, 3.0)
		# The facing wall round the door: dry stone set into the turf.
		for sx in [-1.0, 1.0]:
			var wall := _block(f, Vector3(1.1, h * 0.85, 0.5), Vector3(sx * (w * 0.5 + 0.9), h * 0.42, 0.2), STONE.darkened(0.12))
			PropCollision.box(body, f.transform * wall.transform, Vector3(1.1, h * 0.85, 0.5))
	root.set_meta("hearth", pl.hearth)


func _oak_door(root: Node3D, pl: Dictionary, rng: RandomNumberGenerator, body: StaticBody3D) -> void:
	var d: Vector3 = pl.dir
	var face := float(pl.facing)
	var tree: Array = pl.tree
	var sp: PlantSpecies = SpeciesDB.all()[int(tree[0])]
	var h := float(tree[1])
	root.set_meta("species", sp.name)
	# The tree, drawn here (one hero mesh), the placer's trees kept back.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = PlantMeshes.mesh_for(sp, PlantMeshes.LOD_HERO, 0)
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(h, h, h)), _local(root, d, -0.3)))
	mm.set_instance_color(0, Color(1, 1, 1, 1))
	mm.set_instance_custom_data(0, Color(0.2, 0.0, 0.0, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tree"
	mmi.multimesh = mm
	mmi.material_override = PlantMeshes.material_for(sp)
	root.add_child(mmi)
	var trunk_r := clampf(h * 0.03, 0.6, 1.4)
	PropCollision.capsule(body, Transform3D(Basis(), _local(root, d, 2.0)), trunk_r, 4.0)
	# The doorway at its foot, sunk a little, facing out; roots over it.
	var at := CreatureSpawner._offset(d, face, trunk_r + 0.3)
	var f := _frame(root, at, face, -0.35)
	_doorway(f, 0.95, 1.55, DARK_STONE, STONE.darkened(0.25), body)
	var bark := Color(0.28, 0.22, 0.16)
	for k in 5:
		var side := -1.0 if k % 2 == 0 else 1.0
		var x := side * rng.randf_range(0.5, 1.1)
		var root_r := rng.randf_range(0.1, 0.2)
		var rlen := rng.randf_range(1.6, 2.6)
		var c := CreatureBodies.cone(f, root_r * 1.6, root_r * 0.5, rlen, Vector3(x, 1.2 + rng.randf() * 0.5, 0.15), bark)
		c.rotation = Vector3(rng.randf_range(-0.3, 0.2), 0.0, side * rng.randf_range(0.5, 1.1))


func _burning_shrine(root: Node3D, pl: Dictionary, rng: RandomNumberGenerator, body: StaticBody3D) -> void:
	var d: Vector3 = pl.dir
	var face := float(pl.facing)
	var f := _frame(root, d, face)
	var w := 1.3
	var h := 2.1
	_doorway(f, w, h, STONE, STONE, body, true)
	# The porch going in: side walls and a roof slab, the slope over it.
	var deep := 3.2
	for sx in [-1.0, 1.0]:
		var wall := _block(f, Vector3(0.35, h + 0.4, deep), Vector3(sx * (w * 0.5 + 0.2), (h + 0.4) * 0.5 - 0.2, deep * 0.5), DARK_STONE)
		PropCollision.box(body, f.transform * wall.transform, Vector3(0.35, h + 0.4, deep))
	var roof := _block(f, Vector3(w + 1.0, 0.4, deep + 0.4), Vector3(0.0, h + 0.3, deep * 0.5), DARK_STONE.darkened(0.1))
	PropCollision.box(body, f.transform * roof.transform, Vector3(w + 1.0, 0.4, deep + 0.4))
	# Steps going down into the dark, and the dark itself.
	for k in 4:
		var st := _block(f, Vector3(w, 0.18, 0.5), Vector3(0.0, 0.02 - k * 0.22, 0.5 + k * 0.55), DARK_STONE.darkened(0.15 + k * 0.15))
		st.name = "Step%d" % k
	var back := _block(f, Vector3(w + 0.2, h + 1.0, 0.2), Vector3(0.0, h * 0.5 - 0.6, deep - 0.1), Color(0.02, 0.02, 0.03))
	back.name = "Dark"
	# Torchlight showing inside: a torch in a bracket on the wall.
	var sconce := Node3D.new()
	sconce.name = "Sconce"
	f.add_child(sconce)
	sconce.position = Vector3(-w * 0.5 + 0.12, 1.35, 1.6)
	_block(sconce, Vector3(0.08, 0.08, 0.3), Vector3(0.0, -0.1, 0.0), Color(0.15, 0.13, 0.12))
	CreatureBodies.cone(sconce, 0.035, 0.03, 0.45, Vector3(0.05, 0.1, 0.0), WOOD)
	var flame := Torch.flame_node()
	flame.position = Vector3(0.05, 0.38, 0.0)
	sconce.add_child(flame)
	var light := Torch.light_node()
	light.position = Vector3(0.25, 0.4, 0.0)
	light.light_energy *= 0.8
	sconce.add_child(light)
	root.set_meta("light", light)


## One small cloaked figure (small folk's scale) standing by the place.
func _speaker(root: Node3D, pl: Dictionary, rng: RandomNumberGenerator) -> void:
	var d: Vector3 = pl.dir
	var face := float(pl.facing)
	var sd := CreatureSpawner._offset(d, face + rng.randf_range(-0.9, 0.9), rng.randf_range(4.0, 6.0))
	var holder := _frame(root, sd, face + PI)
	holder.name = "Speaker"
	var palettes := [[Color(0.2, 0.28, 0.16), Color(0.14, 0.2, 0.1)], [Color(0.32, 0.24, 0.16), Color(0.22, 0.16, 0.1)], [Color(0.24, 0.24, 0.3), Color(0.16, 0.16, 0.22)]]
	var pal: Array = palettes[rng.randi() % palettes.size()]
	var b := CloakedFigure.build(rng.randf_range(0.95, 1.1), pal[0], pal[1])
	var fig: Node3D = b.root
	# Facing the place's way out (+z of the holder is the place).
	fig.rotation.y = PI
	holder.add_child(fig)
	BlobShadow.make(holder, 0.35, 0.5)
	speakers.append({"key": str(pl.key), "node": holder, "place": pl})
