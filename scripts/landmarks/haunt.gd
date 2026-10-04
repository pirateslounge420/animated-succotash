class_name Haunt
extends Node
## Haunted where the dead lie (design 3 Oct §DI.4, data/ruins.json haunt).
##
## Which places: seeded per ruin, `share` of the ruins whose kind is in
## `kinds` (graveyards and barrows: Ruins.Kind names) are haunted, and
## the same share of the tombs (the heart rooms) of any delve.
## When: only while you are in or beside a haunted place AND the light is
## low (dusk or night by the sun, or where you stand the sky visibility is
## under low_light_visibility: a dark hall, a delve). Then, about
## per_real_hour times in an hour so spent (a roll each second), at most
## per_visit_max a visit, never twice in a row at one spot.
## Where: a spot distance_m off, inside the camera's view and seen (no wall
## between), with an occluder (a wall end, a jamb, a headstone, a trunk)
## within occluder_within_m to step behind.
## What: the shared cloaked rig (§0) in `color` at `alpha`, a little
## see-through, lit by the scene with no light of its own (R8): no
## emission, no Light3D, no shadow, no sound, no collision, no footsteps,
## no head-look. It stands for seen_s, then walks behind its occluder; the
## moment it is out of the camera's view or a ray to it is blocked it is
## freed, so the corner you hurry round is empty.
## It never harms, never speaks, never touches the dread (its meter and
## stages) and writes no log line. It is not a lurker (§CU) and gets none
## of their cues; it tells nothing (§BQ).

static var D: Dictionary = Tuning.section("ruins", "haunt")
## How near a haunted ruin counts as in or beside it (m past its footprint).
const BESIDE_M := 25.0
const ROLL_S := 1.0
const WALK_MPS := 1.1
## A spot is "the same" as the last within this (m).
const SAME_SPOT_M := 4.0
## Longest a ghost may linger in view before it is let go anyway (s).
const MAX_LIFE_S := 15.0

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var sky: SkySystem
var landmarks: Landmarks
## Tools: "hour" (dawn/day/dusk/night), "visibility" (at you), "place"
## (a ruin node: the place you are in).
var override := {}
## The ghost now (or {}): {"node", "body", "spot", "occluder", "target",
## "seen", "age", "out_at"}.
var ghost := {}
## Tools: every appearance (seen_log), [ruin id, scene spot, visit number]; the last
## ghost's freeing: {"left_at", "freed_at"} (seconds of this node's clock).
var seen_log: Array = []
var last_freed := {}
var visit := 0
var _visit_place := -1
var _visit_count := 0
var _last_spot := {} # ruin id -> scene spot
var _roll := 0.0
var _pending := false
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
static var _shader: Shader = null


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_sky: SkySystem, p_landmarks: Landmarks) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	sky = p_sky
	landmarks = p_landmarks
	_rng.seed = 97


## Is this ruin haunted (its kind, its own seeded roll)?
static func haunted(site: Dictionary) -> bool:
	if site.is_empty():
		return false
	var kinds: Array = D.get("kinds", [])
	var name := str(Ruins.Kind.keys()[int(site.get("kind", 0))]) if int(site.get("kind", -1)) >= 0 and int(site.get("kind", -1)) < Ruins.Kind.size() else ""
	var share := float(D.get("share", 0.4))
	# (The data names the newer kinds by their style keys: "abbey", §DU.)
	if kinds.has(name) or kinds.has(name.to_lower()):
		return float(hash([int(site.get("seed", 0)), "haunt"]) & 0xFFFF) / 65535.0 < share
	return false


## Is this ruin's delve tomb (its heart) haunted?
static func tomb_haunted(site: Dictionary) -> bool:
	if not Delves.has_delve(site):
		return false
	var kinds: Array = D.get("kinds", [])
	if not (kinds.has("tomb") or kinds.has("mausoleum")):
		return false
	return float(hash([int(site.get("seed", 0)), "haunt_tomb"]) & 0xFFFF) / 65535.0 < float(D.get("share", 0.4))


## The haunted place you are in or beside now (a ruin node), or null.
func place_now() -> Node3D:
	if override.has("place"):
		return override.place
	var pd: Vector3 = world.dir_of(player.global_position)
	if Delves.inside and Delves.instance != null and is_instance_valid(Delves.instance.current_ruin):
		var r: Node3D = Delves.instance.current_ruin
		var site: Dictionary = r.get_meta("site", {})
		if haunted(site) or tomb_haunted(site):
			return r
	for c in landmarks._ruins:
		var node: Node3D = landmarks._ruins[c]
		if not is_instance_valid(node):
			continue
		var site: Dictionary = node.get_meta("site", {})
		if not haunted(site):
			continue
		if CubeSphere.surface_distance_m(site.dir, pd) <= float(site.get("footprint_m", 10.0)) + BESIDE_M:
			return node
	return null


## Is the light low where you are: dusk or night, or a dark hall?
func low_light() -> bool:
	var hour := str(override.hour) if override.has("hour") else SoundBed._hour_word(float(world.local_clock(world.dir_of(player.global_position)).y), sky.sun_elevation_deg if sky != null else NAN)
	if hour == "dusk" or hour == "night":
		return true
	var vis := float(override.visibility) if override.has("visibility") else (chunks.sky_visibility_at(player.global_position) * (1.0 - (sky.enclosure() if sky != null else 0.0)) if chunks != null else 1.0)
	if Delves.inside:
		vis = 0.0
	return vis < float(D.get("low_light_visibility", 0.25))


## A new visit (the tools, between their simulated visits).
func new_visit() -> void:
	_visit_place = -1


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	tick(delta)


## The haunt's clock: `delta` seconds (the tools step it in whole seconds).
func tick(delta: float) -> void:
	_clock += delta
	if not ghost.is_empty():
		_move_ghost(delta)
		return
	var place := place_now()
	if place == null:
		_visit_place = -1
		return
	var pid := place.get_instance_id()
	if pid != _visit_place:
		# Arriving at a haunted place: a new visit.
		_visit_place = pid
		_visit_count = 0
		_pending = false
		visit += 1
	if _visit_count >= int(D.get("per_visit_max", 1)) or not low_light():
		return
	_roll -= delta
	if _roll > 0.0:
		return
	var steps := maxf(delta, ROLL_S)
	_roll = ROLL_S
	# A roll won waits (this visit) for a spot in view to show itself at.
	if not _pending and _rng.randf() >= float(D.get("per_real_hour", 1.0)) * steps / 3600.0:
		return
	_pending = true
	var spot := find_spot(place)
	if spot.is_empty():
		return
	_pending = false
	appear(place, spot)


## A spot for it now (scene points): {"spot", "occluder"} or {}.
func find_spot(place: Node3D) -> Dictionary:
	var cam := player.camera()
	if cam == null:
		return {}
	var space := player.get_world_3d().direct_space_state
	var eye := cam.global_position
	var up: Vector3 = player.up
	var fwd := -cam.global_basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var right := fwd.cross(up).normalized()
	var dr: Array = D.get("distance_m", [8.0, 20.0])
	var occ := float(D.get("occluder_within_m", 1.5))
	var last: Vector3 = _last_spot.get(place.get_instance_id(), Vector3.INF)
	for attempt in 40:
		var dist := _rng.randf_range(float(dr[0]), float(dr[1]))
		var ang := _rng.randf_range(-0.6, 0.6)
		var flat := player.global_position + (fwd * cos(ang) + right * sin(ang)) * dist
		var d: Vector3 = world.dir_of(flat)
		var foot: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
		if last != Vector3.INF and foot.distance_to(last) < SAME_SPOT_M:
			continue
		var chest := foot + up * 1.2
		if not cam.is_position_in_frustum(chest):
			continue
		# Seen: nothing between the eye and it.
		var q := PhysicsRayQueryParameters3D.create(eye, chest)
		q.exclude = [player.get_rid()]
		if not space.intersect_ray(q).is_empty():
			continue
		# Something to step behind, close by.
		var best := {}
		for k in 8:
			var a := TAU * k / 8.0
			var dirv := (fwd * cos(a) + right * sin(a)).normalized()
			var from := foot + up * 0.8
			var rq := PhysicsRayQueryParameters3D.create(from, from + dirv * occ)
			rq.exclude = [player.get_rid()]
			var hit := space.intersect_ray(rq)
			if not hit.is_empty():
				best = hit
				break
		if best.is_empty():
			continue
		return {"spot": foot, "occluder": best.position}
	return {}


## It appears at `spot` ({"spot", "occluder"}) in haunted place `place`.
func appear(place: Node3D, spot: Dictionary) -> void:
	var cb := CloakedFigure.build(1.72, Color(str(D.get("color", "#C8D8FF"))), Color(str(D.get("color", "#C8D8FF"))).darkened(0.15))
	var body: PlayerBody = cb.root
	var node := Node3D.new()
	node.name = "Ghost"
	world.world_root.add_child(node)
	node.add_child(body)
	_ghost_look(body)
	var foot: Vector3 = spot.spot
	var up: Vector3 = player.up
	node.global_position = foot
	var to_occ: Vector3 = (spot.occluder as Vector3) - foot
	to_occ -= up * to_occ.dot(up)
	if to_occ.length() < 0.05:
		to_occ = player.global_basis.x
	node.global_basis = Basis.looking_at(to_occ.normalized(), up)
	# Behind its occluder from the eye: past it, away from the camera.
	var cam := player.camera()
	var away: Vector3 = (spot.occluder as Vector3) - cam.global_position
	away -= up * away.dot(up)
	var target: Vector3 = (spot.occluder as Vector3) + away.normalized() * 1.8
	var dr: Array = D.get("seen_s", [0.5, 2.0])
	ghost = {"node": node, "body": body, "spot": foot, "occluder": spot.occluder, "target": target,
		"seen": _rng.randf_range(float(dr[0]), float(dr[1])), "age": 0.0, "out_at": -1.0, "place": place.get_instance_id()}
	_visit_count += 1
	_last_spot[place.get_instance_id()] = foot
	seen_log.append([place.get_instance_id(), foot, visit])


## The pale, see-through look: the body's own shader with an alpha, the
## hood's hollow and all of it in `color`, no emission; no shadow.
func _ghost_look(body: PlayerBody) -> void:
	if _shader == null:
		var code := (preload("res://shaders/player.gdshader") as Shader).code
		code = code.replace("render_mode vertex_lighting, diffuse_lambert, specular_disabled;", "render_mode vertex_lighting, diffuse_lambert, specular_disabled, blend_mix, depth_draw_always, cull_back;\nuniform vec3 ghost_color = vec3(0.6, 0.7, 1.0);\nuniform float ghost_alpha = 0.55;")
		code = code.replace("		ALBEDO = vec3(0.0);\n		EMISSION = hollow_color;", "		ALBEDO = ghost_color * 0.15;")
		code = code.replace("		ALBEDO = base * mix(vec3(1.0), t * 2.0, k) * (0.7 + 0.6 * g);\n	}", "		ALBEDO = base * mix(vec3(1.0), t * 2.0, k) * (0.7 + 0.6 * g);\n		ALBEDO = mix(ALBEDO, ghost_color * (0.75 + 0.5 * g), 0.85);\n	}\n	ALPHA = ghost_alpha;")
		_shader = Shader.new()
		_shader.code = code
	var col := Color(str(D.get("color", "#C8D8FF"))).srgb_to_linear()
	for m in [body._mat, body._cloth_mat]:
		(m as ShaderMaterial).shader = _shader
		(m as ShaderMaterial).set_shader_parameter("ghost_color", Vector3(col.r, col.g, col.b))
		(m as ShaderMaterial).set_shader_parameter("ghost_alpha", float(D.get("alpha", 0.55)))
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Is the ghost in view now (in the frustum, nothing between)?
func in_view() -> bool:
	if ghost.is_empty() or not is_instance_valid(ghost.node):
		return false
	var cam := player.camera()
	var chest: Vector3 = (ghost.node as Node3D).global_position + player.up * 1.2
	if not cam.is_position_in_frustum(chest):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, chest)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _move_ghost(delta: float) -> void:
	var node: Node3D = ghost.node
	if not is_instance_valid(node):
		ghost = {}
		return
	ghost.age = float(ghost.age) + delta
	# Gone the moment it is out of view.
	if not in_view() or float(ghost.age) > MAX_LIFE_S:
		free_ghost()
		return
	var body: PlayerBody = ghost.body
	if float(ghost.age) < float(ghost.seen):
		body.set_motion(0.0, delta)
		body.set_velocity(Vector3.ZERO)
		return
	var to: Vector3 = (ghost.target as Vector3) - node.global_position
	to -= player.up * to.dot(player.up)
	if to.length() > 0.1:
		var step := to.normalized() * minf(WALK_MPS * delta, to.length())
		var d: Vector3 = world.dir_of(node.global_position + step)
		node.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
		node.global_basis = Basis.looking_at(to.normalized(), player.up)
		body.set_motion(0.35, delta)
		body.set_velocity(to.normalized() * WALK_MPS)


func free_ghost() -> void:
	if not ghost.is_empty() and is_instance_valid(ghost.node):
		(ghost.node as Node3D).queue_free()
	last_freed = {"freed_at": _clock}
	ghost = {}
