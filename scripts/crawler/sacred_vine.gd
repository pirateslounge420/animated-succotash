class_name SacredVine
extends Node3D
## The tomb's world's sacred plant on the surface above it (design 9 Oct
## §FM.7 and §FM.9; queue 72; data/brew.json world, vine, teach, plants).
## The world's plant is one entry of data/sacred/sacred_plants.json
## (brew.json world.plant: ololiuhqui, the Aztec world's, the tomb being
## the Aztec world, data/ruin_compass.json), built as the catalogue builds
## an entry and never loaded (SpeciesDB.species_in_file): the open world,
## the species catalogue and the §CC trim stay as they are.
##
## One plant grows: drawn as the engine draws every liana (its shape,
## PlantSpecies.Shape.LIANA, PlantMeshes.mesh_for in the foliage material,
## as SurfacePlants draws every plant up there: a one-plant MultiMesh), hung
## from a tree's crown as the open world hangs one (VegetationPlacer:
## vine.attach_share of the tree's height up it, vine.out_share of its
## height out from the trunk, here on the side toward where you come up),
## its strands down to near the ground (vine.length_share). The tree is one
## the surface grew (SurfacePlants.trees_placed): a tree with a trunk and
## branches (PlantMeshes.climbable) vine.host_h_m tall, ahead of you as you
## come up (vine.from_arrival_m, ahead_deg), the nearest to vine.near_m.
##
## Harvesting takes part of it (plants.<id>.take_share of its length, from
## its foot) and leaves it standing: never below keep_share of its length,
## never uprooted. It regrows on the game clock (World.days, the one clock
## of §FK.3): one take's length every regrow_game_h game hours. Its length
## now is share_now(); its foot, tip().
##
## The shaman teaches the way once (Mike, §FM.7; teach): the first time you
## come up he stands by it, the same figure as the one at the hearth (the
## rig, the cloak, the head and the ladle, add_teacher), and when you come
## near and look at him he crouches, takes a length from its foot with his
## left hand, the plant left standing, shows it to you and puts it away
## (lesson: "wait", "reach", "show", "tuck", "done"); wordless (§ED). Brew
## spawns him and keeps the lesson in the save once seen.

## The entries built so far (id -> PlantSpecies, or null when the file has
## none), for the session.
static var _species := {}

var world: Node
var land: SurfaceGround
## The plant's id (its entry's), its species (never loaded) and its
## brew.json plants block.
var plant := ""
var sp: PlantSpecies
var P: Dictionary = {}
## The tree it hangs from: {"q" (x/z), "h", "species"}.
var host := {}
## Where its strands hang from (scene), its full length (m), its turn, and
## which way is out from the trunk (flat, toward where you come up).
var attach := Vector3.ZERO
var length_m := 0.0
var yaw := 0.0
var out_dir := Vector3.FORWARD
var mmi: MultiMeshInstance3D
var voice: AudioStreamPlayer3D
## A plant on the ground (on_ground: a mushroom): a small group, `bodies`
## plants (brew.json ground.count), shown_bodies of them standing now, on
## the rotting `wood` it grows from.
var group := false
var bodies := 1
var shown_bodies := 1
var wood: MeshInstance3D
var _body_xf: Array[Transform3D] = []
## Its length (a share of length_m) as last cut and the game time (days)
## it was cut at: share_now() grows it back from there.
var _share0 := 1.0
var _days0 := 0.0
var _shown := -1.0
## The plant's transform as last handed to its MultiMesh (the checks read
## it: a headless run keeps no MultiMesh buffer to read back).
var drawn := Transform3D.IDENTITY
## Takes: yours, and the shaman's (the checks).
var takes := 0
var lesson_takes := 0
var refusals := 0

## The shaman's lesson (teach): his figure, how he moves, where he stands,
## the lesson's step and its clock, and the length he took, in his hand.
var teacher: HearthFolk
var motion: FolkMotion
var teacher_at := Vector3.ZERO
var lesson := ""
var taught := false
var _lt := 0.0
var _prop: Node3D


static func B() -> Dictionary:
	return Brew.data()


## The world's plant: its entry's id (brew.json world.plant; over a ruin
## kind world.by_theme names, that one: the Aztec temple's world grows
## teonanácatl, §FN.5.4, §FN.8 call 1). The surface being built says which
## ruin kind (Surface.theme).
static func plant_id() -> String:
	var Wd: Dictionary = B().get("world", {})
	var by: Dictionary = Wd.get("by_theme", {})
	if by.has(Surface.theme):
		return str(by[Surface.theme])
	return str(Wd.get("plant", "ololiuhqui"))


## Is the plant this surface's own pick (brew.json world.by_theme), not
## the tomb's world.plant?
static func chosen_by_world() -> bool:
	return ((B().get("world", {}) as Dictionary).get("by_theme", {}) as Dictionary).has(Surface.theme)


## Does the plant grow on the ground (a small group: a mushroom), not hung
## from a tree?
static func on_ground(s: PlantSpecies) -> bool:
	return s != null and s.shape == PlantSpecies.Shape.MUSHROOM


## Does its entry list the surface's biome (the entry's own `biomes`: the
## game grows each species only where it really grows)? An entry that
## lists none is not held to one.
static func grows_here(s: PlantSpecies) -> bool:
	if s == null:
		return false
	var bid := BiomeTemplates.id_of_key(Surface.biome_key())
	var any := false
	for b in s.biomes:
		if b >= 0:
			any = true
	return not any or s.biomes.has(bid)


## A plant's brew.json block (plants.<id>), {} if none.
static func plant_data(id: String) -> Dictionary:
	return (B().get("plants", {}) as Dictionary).get(id, {})


## The plant's entry as a species (data/sacred, brew.json world.file),
## built from its entry and never added to the catalogue (SpeciesDB
## species_in_file: no index); null when the file has no such entry.
static func species_of(id: String) -> PlantSpecies:
	if _species.has(id):
		return _species[id]
	var file := str((B().get("world", {}) as Dictionary).get("file", SpeciesDB.SACRED_PATH))
	var s := SpeciesDB.species_in_file(file, id)
	_species[id] = s
	return s


## Can the engine draw it: an entry whose shape it has a mesh for that
## isn't empty (a liana: PlantMeshes' LIANA strands).
static func drawable(s: PlantSpecies) -> bool:
	if s == null:
		return false
	var arr := PlantMeshes.arrays_for(s, PlantMeshes.LOD_NEAR)
	return arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null and (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= 3


## The vine over ground `p_land`, its tree one of `trees` (SurfacePlants
## trees_placed: [x/z, height, species]) as seen from the stairhead `stair`
## (Surface.stair: where you arrive, which way you face), the surface's
## seed `seed_value`. Null (with a warning) when the world's plant can't be
## drawn or no tree takes it.
## `reach_m` (§FV.1, Surface.stand_reach_m), when over 0, caps how far from
## where you come up the tree may stand: in sight within half a minute.
static func make(p_world: Node, p_land: SurfaceGround, stair: Dictionary, trees: Array, seed_value: int, reach_m := 0.0) -> SacredVine:
	var id := plant_id()
	var s := species_of(id)
	if not drawable(s):
		push_warning("SacredVine: the world's plant %s can't be drawn (data/sacred has no such entry, or no shape the engine draws)" % id)
		return null
	# A world's own plant (world.by_theme) grows only where its entry says
	# (its biomes); the tomb's ololiuhqui (world.plant) is grown as built.
	if chosen_by_world() and not grows_here(s):
		push_warning("SacredVine: %s does not grow in %s (its entry's biomes)" % [id, Surface.biome_key()])
		return null
	var ground := on_ground(s)
	var V: Dictionary = B().get("vine", {})
	if ground:
		# A small group in the grass under a tree's crown (brew.json ground).
		V = V.duplicate()
		V.merge(B().get("ground", {}), true)
	var h := pick_host(stair, trees, seed_value, V, reach_m, ground, p_land)
	if h.is_empty():
		push_warning("SacredVine: no tree on the surface for %s to grow %s" % [id, "under" if ground else "from"])
		return null
	var v := SacredVine.new()
	v.name = "SacredVine"
	v.world = p_world
	v.land = p_land
	v.plant = id
	v.sp = s
	v.P = plant_data(id)
	v.host = h
	v.group = ground
	if ground:
		v._place_group(stair, V, seed_value)
	else:
		v._place(stair, V)
	if p_world != null:
		v._days0 = float(p_world.get("days"))
	return v


## The tree it hangs from: a tree with a trunk and branches host_h_m tall,
## from_arrival_m from where you come up and within ahead_deg of the way
## you face there, the nearest to near_m (the seed breaking ties); else any
## such tree round the stair, nearer first; {} if none.
## `shade` (a plant on the ground, brew.json ground): the tree is one that
## casts shade (a canopy tree, not a shrub; any shape), and there is a spot
## for the group under its crown on ground the plant may stand on
## (shade_spot); its "spot" is in what comes back.
static func pick_host(stair: Dictionary, trees: Array, seed_value: int, V: Dictionary, reach_m := 0.0, shade := false, p_land: SurfaceGround = null) -> Dictionary:
	var arrive: Vector2 = stair.get("arrive", Vector2.ZERO)
	var n: Vector2 = stair.get("n", Vector2(0.0, 1.0))
	n = n.normalized() if n.length() > 1e-4 else Vector2(0.0, 1.0)
	var hr: Array = V.get("host_h_m", [3.0, 8.0])
	var dr: Array = V.get("from_arrival_m", [16.0, 70.0])
	var near := float(V.get("near_m", 30.0))
	var ahead := deg_to_rad(float(V.get("ahead_deg", 40.0)))
	var tiers: Array = [[ahead, float(dr[0]), float(dr[1])], [PI, float(dr[0]), float(dr[1])], [PI, float(dr[0]), 240.0], [PI, 4.0, 4000.0]]
	if reach_m > 0.0:
		# §FV.1: never further than reach_m (ahead first, then anywhere).
		var hi := minf(float(dr[1]), reach_m)
		var lo := minf(float(dr[0]), hi * 0.5)
		near = minf(near, hi * 0.75)
		tiers = [[ahead, lo, hi], [deg_to_rad(90.0), lo, hi], [PI, 4.0, reach_m]]
	for tier in tiers:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "sacred vine"])
		var best := {}
		var best_s := INF
		for t in trees:
			var q: Vector2 = t[0]
			var th := float(t[1])
			var tsp: PlantSpecies = t[2]
			var roll := rng.randf()
			if tsp == null or th < float(hr[0]) or th > float(hr[1]):
				continue
			if shade and not (tsp.tier == PlantSpecies.Tier.CANOPY or tsp.tier == PlantSpecies.Tier.EMERGENT):
				continue
			if not shade and not PlantMeshes.climbable(tsp.shape):
				continue
			var rel := q - arrive
			var d := rel.length()
			if d < float(tier[1]) or d > float(tier[2]) or absf(n.angle_to(rel)) > float(tier[0]):
				continue
			var score := absf(d - near) + roll * 0.5
			if score < best_s:
				var spot := Vector2.INF
				if shade:
					spot = shade_spot(p_land, q, th, arrive, V)
					if spot == Vector2.INF:
						continue
				best_s = score
				best = {"q": q, "h": th, "species": tsp.name}
				if shade:
					best["spot"] = spot
		if not best.is_empty():
			return best
	return {}


## Where a group on the ground stands under the crown of the tree at `q`
## (`h` tall): from_trunk_m [lo, hi] of its height out from the trunk (in
## the crown's shade and its litter), on the side toward `arrive` first,
## then round it; a spot the plant may stand on (ground_ok). INF if none.
static func shade_spot(p_land: SurfaceGround, q: Vector2, h: float, arrive: Vector2, V: Dictionary) -> Vector2:
	var fr: Array = V.get("from_trunk_m", [0.08, 0.14])
	var out := arrive - q
	out = out.normalized() if out.length() > 1e-4 else Vector2(0.0, 1.0)
	var dist := clampf(h * 0.5 * (float(fr[0]) + float(fr[1])), 0.8, 2.6)
	for deg in [0.0, 40.0, -40.0, 80.0, -80.0, 120.0, -120.0, 180.0]:
		var c: Vector2 = q + out.rotated(deg_to_rad(deg)) * dist
		if ground_ok(p_land, c, V):
			return c
	return Vector2.INF


## May a plant on the ground stand at `c`? Inside the pocket, not in the
## wash's scoured bed (SurfacePlants.BED_OPEN), not on the talus or the
## cliffs (zone edge), on ground gentler than ground.max_slope.
static func ground_ok(p_land: SurfaceGround, c: Vector2, V: Dictionary) -> bool:
	if p_land == null:
		return true
	if not p_land.inside(c, 3.0) or p_land.in_wash(c) > SurfacePlants.BED_OPEN:
		return false
	if p_land.zone_at(c, 0.0) == "edge":
		return false
	return p_land.slope_at(c.x, c.y) < float(V.get("max_slope", 0.45))


## The group on the ground (a mushroom): `count` plants, each the shape's
## few bodies, round the host's spot within spread_m, on a length of
## rotting wood half sunk in the grass (wood: its substrate, the entry's
## fungus.substrate snag_log); attach the top of the tallest, length_m its
## height: taking one takes a plant (take_share of the group), the rest
## stand.
func _place_group(stair: Dictionary, V: Dictionary, seed_value: int) -> void:
	var c: Vector2 = host.get("spot", host.q)
	var arrive: Vector2 = stair.get("arrive", c + Vector2(0.0, 1.0))
	var out2 := arrive - c
	out2 = out2.normalized() if out2.length() > 1e-4 else Vector2(0.0, 1.0)
	out_dir = Vector3(out2.x, 0.0, out2.y)
	yaw = FolkMotion.yaw_of(-out_dir)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "sacred group"])
	bodies = maxi(int(V.get("count", 4)), 1)
	var spread := float(V.get("spread_m", 0.35))
	var gy := land.height_at(c.x, c.y) if land != null else 0.0
	var tallest := 0.0
	_body_xf.clear()
	for k in bodies:
		var a := TAU * float(k) / float(bodies) + rng.randf_range(-0.4, 0.4)
		var r := spread * (0.35 + 0.65 * rng.randf()) if k > 0 else 0.0
		var p := c + Vector2(cos(a), sin(a)) * r
		var hh := lerpf(sp.height_m.x, sp.height_m.y, rng.randf())
		tallest = maxf(tallest, hh)
		var y := land.height_at(p.x, p.y) if land != null else gy
		_body_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * hh), Vector3(p.x, y - 0.01, p.y)))
	length_m = maxf(tallest, 0.03)
	attach = Vector3(c.x, gy + length_m, c.y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = PlantMeshes.mesh_for(sp, PlantMeshes.LOD_NEAR)
	mm.instance_count = bodies
	for k in bodies:
		mm.set_instance_transform(k, _body_xf[k])
		mm.set_instance_color(k, Color.WHITE)
		mm.set_instance_custom_data(k, Color(0, 0, 0, 0))
	mmi = MultiMeshInstance3D.new()
	mmi.name = "Group"
	mmi.multimesh = mm
	mmi.material_override = PlantMeshes.material_for(sp)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = float(V.get("visible_m", 60.0))
	add_child(mmi)
	if bool(V.get("wood", true)):
		# The rotting wood it grows from, half sunk: a stick of old branch.
		var wl := float(V.get("wood_m", 0.9))
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.07
		cyl.height = wl
		cyl.radial_segments = 6
		cyl.rings = 1
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(str(V.get("wood_color", "#4a3b2c")))
		wm.roughness = 1.0
		wm.metallic_specular = 0.0
		wood = MeshInstance3D.new()
		wood.name = "Wood"
		wood.mesh = cyl
		wood.material_override = wm
		# Lying across the way you look at it (its axis, the cylinder's y,
		# flat and side-on to you).
		var along := out_dir.cross(Vector3.UP).normalized()
		wood.transform = Transform3D(Basis(along.cross(Vector3.UP), along, Vector3.UP), Vector3(c.x, gy + 0.01, c.y))
		add_child(wood)
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.unit_size = 3.0
	add_child(voice)
	_apply(1.0)


## Hung from the tree's crown, out toward where you come up; its strands
## near to the ground.
func _place(stair: Dictionary, V: Dictionary) -> void:
	var q: Vector2 = host.q
	var h := float(host.h)
	var arrive: Vector2 = stair.get("arrive", q + Vector2(0.0, 1.0))
	var out2 := (arrive - q)
	out2 = out2.normalized() if out2.length() > 1e-4 else Vector2(0.0, 1.0)
	out_dir = Vector3(out2.x, 0.0, out2.y)
	# The tree stands where SurfacePlants stood it (its foot a little sunk).
	var foot := Vector3(q.x, land.height_at(q.x, q.y) - 0.04 * h, q.y) if land != null else Vector3(q.x, 0.0, q.y)
	attach = foot + Vector3.UP * h * float(V.get("attach_share", 0.8)) + out_dir * h * float(V.get("out_share", 0.22))
	var below := attach.y - (land.height_at(attach.x, attach.z) if land != null else foot.y)
	length_m = clampf(below * float(V.get("length_share", 0.9)), 0.5, maxf(sp.height_m.y, 0.5))
	yaw = FolkMotion.yaw_of(-out_dir)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = PlantMeshes.mesh_for(sp, PlantMeshes.LOD_NEAR)
	mm.instance_count = 1
	mm.set_instance_color(0, Color.WHITE)
	# Full leaves, no moss, no sport (the foliage shader's custom data).
	mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
	mmi = MultiMeshInstance3D.new()
	mmi.name = "Vine"
	mmi.multimesh = mm
	mmi.material_override = PlantMeshes.material_for(sp)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# A liana has no far picture (the open world's impostor is a crown's
	# outline); the near strands only, as far as vine.visible_m.
	mmi.visibility_range_end = float(V.get("visible_m", 180.0))
	add_child(mmi)
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.unit_size = 3.0
	add_child(voice)
	_apply(1.0)


func take_share() -> float:
	return clampf(float(P.get("take_share", 0.25)), 0.01, 1.0)


## How much one take is (m): a length of the vine; a whole mushroom of a
## group (its tallest's height).
func cutting_len() -> float:
	return length_m if group else length_m * take_share()


func keep_share() -> float:
	return clampf(float(P.get("keep_share", 0.5)), 0.05, 1.0)


func regrow_h() -> float:
	return maxf(float(P.get("regrow_game_h", 2.0)), 0.001)


func _days(days: float) -> float:
	return days if not is_nan(days) else (float(world.get("days")) if world != null else _days0)


## Its length now (a share of length_m): as last cut, grown back since on
## the game clock (World.days) by one take's length every regrow_game_h
## game hours, to its whole length at most.
func share_now(days := NAN) -> float:
	var d := _days(days)
	var per_day := take_share() / regrow_h() * 24.0
	return minf(1.0, _share0 + maxf(d - _days0, 0.0) * per_day)


## Its foot now (scene): the lowest point of its strands.
func tip(days := NAN) -> Vector3:
	return attach - Vector3.UP * length_m * share_now(days)


## Is there a length to take now without cutting it below keep_share?
func can_take(days := NAN) -> bool:
	return share_now(days) - take_share() >= keep_share() - 1e-5


## Take one length from its foot (it stands: never below keep_share);
## false, nothing cut, if it hasn't one to give.
func take(days := NAN) -> bool:
	if not can_take(days):
		return false
	var d := _days(days)
	_share0 = share_now(d) - take_share()
	_days0 = d
	_apply(_share0)
	_sound(1.0, -6.0)
	return true


## Does its foot lie within carry.reach_m of `eye` (scene)?
func in_reach(eye: Vector3) -> bool:
	var reach := float((B().get("carry", {}) as Dictionary).get("reach_m", 2.4))
	var t := tip()
	# The nearest point of its strands to the eye (they hang from attach to
	# the tip): your hand goes to the part it can reach.
	var y := clampf(eye.y, t.y, attach.y)
	return eye.distance_to(Vector3(attach.x, y, attach.z)) <= reach and eye.distance_to(t) <= reach + 0.6


## Nothing to take (a soft rustle, no words).
func refuse() -> void:
	refusals += 1
	_sound(0.75, -12.0)


func _sound(pitch: float, db: float) -> void:
	if voice == null or not voice.is_inside_tree():
		return
	voice.global_position = tip()
	voice.stream = SoundSynth.stream("rustle", takes + lesson_takes + refusals)
	voice.pitch_scale = pitch
	voice.volume_db = db
	Audio3D.play(voice)


## Its strands at `share` of their length (the MultiMesh's one plant,
## scaled down its hang from where it hangs).
func _apply(share: float) -> void:
	if mmi == null:
		return
	_shown = share
	if group:
		# The group: as many of its plants standing as its share leaves
		# (one take, take_share of the group, is a plant picked; one comes back
		# each time a whole take has grown back).
		shown_bodies = clampi(floori(share * float(bodies) + 0.01), 1, bodies)
		mmi.multimesh.visible_instance_count = shown_bodies
		drawn = _body_xf[0] if not _body_xf.is_empty() else Transform3D.IDENTITY
		return
	var bs := Basis(Vector3.UP, yaw).scaled(Vector3(length_m, length_m * share, length_m))
	drawn = Transform3D(bs, attach)
	mmi.multimesh.set_instance_transform(0, drawn)


## A length of the vine (its own strands, `length` m long, thinner than the
## plant's), hanging from its origin: what you carry and what the shaman
## holds and works.
static func cutting_node(s: PlantSpecies, length: float, width := 0.6) -> Node3D:
	var n := Node3D.new()
	n.name = "Cutting"
	if s == null:
		return n
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = PlantMeshes.mesh_for(s, PlantMeshes.LOD_NEAR)
	mm.instance_count = 1
	mm.set_instance_color(0, Color.WHITE)
	mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
	if on_ground(s):
		# A picked mushroom (the shape's few bodies), whole, its own size at
		# most: standing up from where it is held.
		var k := clampf(length, 0.03, maxf(s.height_m.y, 0.03))
		mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), Vector3.ZERO))
	else:
		mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3(width, length, width)), Vector3.ZERO))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Strands"
	mi.multimesh = mm
	mi.material_override = PlantMeshes.material_for(s)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


func _process(_delta: float) -> void:
	var s := share_now()
	if absf(s - _shown) > 0.0005:
		_apply(s)
	if teacher != null and is_instance_valid(teacher) and _prop != null and is_instance_valid(_prop) and _prop.visible:
		# The length he took hangs from his left fist.
		_prop.global_transform = Transform3D(Basis.IDENTITY, motion.fist(0))


# --- The shaman's lesson (teach) -------------------------------------------------

## The shaman by the vine, the same figure as the one at the hearth (`look`:
## {"height_m", "pal", "beast"}, HearthFolk's), standing teach.stand_m out
## from it toward where you come up, facing it, his ladle in his right hand.
func add_teacher(look: Dictionary) -> void:
	if teacher != null and is_instance_valid(teacher):
		return
	var T: Dictionary = B().get("teach", {})
	var g := Vector3(attach.x, 0.0, attach.z) + out_dir * float(T.get("stand_m", 0.7))
	g.y = land.height_at(g.x, g.z) if land != null else 0.0
	teacher_at = g
	teacher = HearthFolk.make(self, "Shaman", g, FolkMotion.yaw_of(-out_dir), float(look.get("height_m", 1.62)), look.get("pal", [Color("#5a4a3a"), Color("#8a6a4a")]), str(look.get("beast", "")))
	motion = FolkMotion.new(teacher)
	if land != null:
		motion.ground = land.height_at
	motion.stand_at(g)
	teacher.rotation = Vector3(0.0, FolkMotion.yaw_of(-out_dir), 0.0)
	lesson = "wait"
	_lt = 0.0


## Begin the lesson now (you came near and looked at him, or put your hand
## to the vine first).
func begin_lesson() -> void:
	if lesson == "wait":
		lesson = "reach"
		_lt = 0.0


## Is the lesson under way (not waiting, not done)?
func lesson_running() -> bool:
	return lesson in ["reach", "show", "tuck"]


## Each physics step while you are up here: the lesson, and his arms.
func lesson_step(delta: float, player: CrawlerPlayer) -> void:
	if teacher == null or not is_instance_valid(teacher) or motion == null:
		return
	var T: Dictionary = B().get("teach", {})
	_lt += delta
	match lesson:
		"wait":
			if player != null and player.camera() != null:
				var eye := player.eye_position()
				var head := teacher.global_position + Vector3.UP * 1.45 * motion.scale()
				var look := -player.camera().global_basis.z
				if eye.distance_to(head) <= float(T.get("watch_m", 12.0)) and rad_to_deg(look.angle_to((head - eye).normalized())) <= float(T.get("view_deg", 40.0)):
					begin_lesson()
		"reach":
			# Down to the vine's foot, the left hand to the length he takes.
			var reach_s := maxf(float(T.get("reach_s", 1.2)), 0.1)
			if _lt <= delta * 1.5:
				motion.crouch(clampf(float(T.get("crouch", 0.6)), 0.0, 1.0))
				motion.reach(0, attach - Vector3.UP * length_m * (share_now() - take_share() * 0.5))
			else:
				motion.reach_point(0, attach - Vector3.UP * length_m * (share_now() - take_share() * 0.5))
			if _lt >= reach_s:
				var len_now := cutting_len()
				if take():
					lesson_takes += 1
					_prop = cutting_node(sp, minf(len_now, 0.6))
					add_child(_prop)
				lesson = "show"
				_lt = 0.0
		"show":
			# Up again, turned to you, the length held out a little.
			if _lt <= delta * 1.5:
				motion.stand_up()
			var to := Vector3.FORWARD
			if player != null:
				to = player.global_position - teacher.global_position
				to.y = 0.0
			if to.length() > 0.05:
				motion.turn_toward(to.normalized(), delta, 160.0)
				var hold := teacher.global_position + to.normalized() * 0.45 * motion.scale() + Vector3.UP * 1.0 * motion.scale()
				if _lt > 0.4:
					motion.reach(0, hold)
					motion.reach_point(0, hold)
			if _lt >= maxf(float(T.get("show_s", 1.6)), 0.2):
				motion.release(0)
				lesson = "tuck"
				_lt = 0.0
		"tuck":
			# Put away (into his cloak).
			if _lt >= maxf(float(T.get("tuck_s", 0.8)), 0.1) * 0.5 and _prop != null and is_instance_valid(_prop):
				_prop.queue_free()
				_prop = null
			if _lt >= maxf(float(T.get("tuck_s", 0.8)), 0.1):
				lesson = "done"
				taught = true
	motion.update(delta)


## You go down (the surface out of the tree): once the lesson is seen, he
## is not up here again.
func left_surface() -> void:
	if not taught:
		return
	drop_teacher()


func drop_teacher() -> void:
	if _prop != null and is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null
	if teacher != null and is_instance_valid(teacher):
		if teacher.get_parent() != null:
			teacher.get_parent().remove_child(teacher)
		NodeRelease.free_later(teacher)
	teacher = null
	motion = null
	if lesson != "done":
		lesson = ""
