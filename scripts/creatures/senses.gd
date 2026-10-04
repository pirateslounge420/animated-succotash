class_name Senses
## Your light gives you away (design 3 Oct §DF, data/senses.json). How a
## watcher senses the player, by kind (senses.json watchers: lurker,
## night_animal, day_animal, werewolf; goblin_band and stranger are rows
## for §DH and §DF's open calls, built false, and nothing reads them yet).
##
## What you give off: LIGHT, a lit torch in hand or planted, seen from
## light_sight_m at night wherever there is a clear line to it; SIGHT, you
## yourself, seen from sight_day_m by day and by night a share of that
## (night_vision, plus moonlight_adds × the moonlight, so a full moon shows
## you even with your torch out); SOUND, your footsteps (noise_level,
## heard from hearing_m sprinting, half that walking, a fifth sneaking);
## SCENT, always, carried downwind only: a nose within scent_m and within
## the downwind cone smells you, one upwind smells nothing.
##
## Line of sight counts for sight and light alike: one ray against trunks
## and walls, and a march along the line against the ground, which brings
## the ridges and the horizon in on their own. Sound is not stopped by a
## line (the hills muffle it, design §DF; not modelled yet).
##
## Read by the dread's hunter (Dread: what it follows, and the decoy) and
## the rosters (Creature._shy_m: how far an animal notices you).

static var D := Tuning.table("senses")
static var WATCHERS: Dictionary = D.get("watchers", {})
static var PLAYER: Dictionary = D.get("player", {})

static var world: Node = null
static var chunks: ChunkManager = null
static var player: PlanetPlayer = null
static var sky: SkySystem = null
## Tests: {"daylight", "moonlight", "wind" (scene vector m/s), "noise"}
## in place of the live values.
static var override := {}


static func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_sky: SkySystem) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	sky = p_sky


## The senses.json row for `kind` ({} if none).
static func row(kind: String) -> Dictionary:
	return WATCHERS.get(kind, {})


## Is the row built (goblin_band and stranger are not, §DH)?
static func built(kind: String) -> bool:
	var r := row(kind)
	return not r.is_empty() and bool(r.get("built", true))


static func daylight() -> float:
	if override.has("daylight"):
		return float(override.daylight)
	return sky.daylight if sky != null else 1.0


static func moonlight() -> float:
	if override.has("moonlight"):
		return float(override.moonlight)
	return sky.moonlight if sky != null else 0.0


## How far `kind` sees the player (not a light) now: sight_day_m by day;
## at night, night_vision plus moonlight_adds × the moonlight of it (never
## more than by day); blended through dusk by the daylight.
static func sight_m(kind: String) -> float:
	var r := row(kind)
	var day := float(r.get("sight_day_m", 0.0))
	var share := minf(float(r.get("night_vision", 0.0)) + float(D.get("moonlight_adds", 0.5)) * moonlight(), 1.0)
	return day * lerpf(share, 1.0, clampf(daylight(), 0.0, 1.0))


## Its sight now as a share of by day (1 with no day sight to scale).
static func sight_share(kind: String) -> float:
	var day := float(row(kind).get("sight_day_m", 0.0))
	return sight_m(kind) / day if day > 0.0 else 1.0


## How far `kind` sees a lit torch now: light_sight_m at night, fading
## out by day (a flame in sunlight is no beacon); never less than its
## plain sight.
static func light_m(kind: String) -> float:
	var night := clampf(1.0 - daylight() / 0.3, 0.0, 1.0)
	return maxf(float(row(kind).get("light_sight_m", 0.0)) * night, sight_m(kind))


## The share of hearing_m at which a noise level (0 silent .. 1 sprinting)
## is heard: senses.json player.sound.heard_share, points [noise, share]
## (sprinting 1, walking half, sneaking a fifth, still nothing).
static func heard_share(noise: float) -> float:
	var pts: Array = (PLAYER.get("sound", {}) as Dictionary).get("heard_share", [[0.0, 0.0], [0.12, 0.2], [0.4, 0.5], [1.0, 1.0]])
	if noise <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		if noise <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (noise - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
	return float(pts[pts.size() - 1][1])


static func hearing_m(kind: String, noise: float) -> float:
	return float(row(kind).get("hearing_m", 0.0)) * heard_share(noise)


## The wind at the player, a scene vector (m/s): the gust field (Wind I),
## or the test's.
static func wind_at(p: Vector3, up: Vector3) -> Vector3:
	if override.has("wind"):
		return override.wind
	if Dread.wind_pin != Vector3.INF:
		return Dread.wind_pin
	# Once a frame (every animal asks at your position).
	var f := Engine.get_process_frames()
	if f != _wind_frame or p.distance_to(_wind_at) > 1.0:
		_wind_frame = f
		_wind_at = p
		_wind_v = Wind.gust_vec(p, up)
	return _wind_v


static var _wind_frame := -1
static var _wind_at := Vector3.INF
static var _wind_v := Vector3.ZERO


## Is `nose` in the scent from `from` (scene positions), for a nose that
## smells scent_m: within scent_m and within cone_deg of straight
## downwind (senses.json player.scent); in a calm, only within calm_share
## of scent_m, all round.
static func in_scent(scent_m: float, nose: Vector3, from: Vector3, up: Vector3) -> bool:
	if scent_m <= 0.0:
		return false
	var to := nose - from
	to -= up * to.dot(up)
	var dist := to.length()
	if dist > scent_m:
		return false
	var sc: Dictionary = PLAYER.get("scent", {})
	var w := wind_at(from, up)
	w -= up * w.dot(up)
	if w.length() < float(sc.get("calm_mps", 0.5)):
		return dist <= scent_m * float(sc.get("calm_share", 0.25))
	if dist < 1.0:
		return true
	return rad_to_deg(w.normalized().angle_to(to / dist)) <= float(sc.get("cone_deg", 30.0))


## Is the line from `a` to `b` (scene positions) clear: no trunk, wall or
## rock across it (one ray), and the ground nowhere above it (a march
## along it, so the ridges and the horizon stop it). `exclude`: RIDs the
## ray passes through (the player's body, the watcher's).
static func clear_line(a: Vector3, b: Vector3, exclude: Array = []) -> bool:
	if world == null:
		return true
	var dist := a.distance_to(b)
	if dist < 0.5:
		return true
	# The ground: every few metres (more steps for a longer line).
	var step := clampf(dist / 64.0, 3.0, 25.0)
	var n := int(ceil(dist / step))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		var dp: Vector3 = world.dir_of(p)
		var ground: float = PlanetConst.RADIUS_M + (chunks.ground_height(dp) if chunks != null else world.surface_elevation(dp))
		if world.radius_of(p) < ground - 0.2:
			return false
	# Trunks, walls and rocks.
	var space: PhysicsDirectSpaceState3D = null
	if player != null and player.is_inside_tree():
		space = player.get_world_3d().direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(a, b, PropCollision.WORLD_LAYER | TerrainChunk.TREE_LAYER)
	q.exclude = exclude
	q.hit_from_inside = false
	return space.intersect_ray(q).is_empty()


## The lit torches you give off: [{"pos": scene, "held": bool}], the one
## in hand (at its flame) and the planted ones.
static func lights() -> Array:
	var out: Array = []
	if Torch.instance != null and is_instance_valid(Torch.instance) and Torch.instance.lit() and Torch.instance._light != null:
		out.append({"pos": Torch.instance._light.global_position, "held": true})
	for t in PlantedTorch.all:
		if is_instance_valid(t) and t.is_inside_tree() and t.lit():
			out.append({"pos": t.global_position + t.up * 0.9, "held": false})
	return out


## Does `kind` at `eye` (scene) see the light at `light_pos`: within
## light_m with a clear line?
static func sees_light(kind: String, eye: Vector3, light_pos: Vector3, exclude: Array = []) -> bool:
	return eye.distance_to(light_pos) <= light_m(kind) and clear_line(eye, light_pos, exclude)


## The sense by which a watcher of `kind` at `eye` (scene position, at its
## eyes) senses the player now: "light" (the torch in hand), "sight",
## "hearing", "scent", or "" (nothing). Touch: within touch_m always.
## `noise`: the player's noise level (else theirs).
static func can_sense(kind: String, eye: Vector3, p: PlanetPlayer = null, noise := -1.0) -> String:
	p = p if p != null else player
	if p == null or row(kind).is_empty():
		return ""
	var body: Vector3 = p.global_position
	var up: Vector3 = p.surface_dir
	var their_eye: Vector3 = p.eye_position()
	var dist := eye.distance_to(their_eye)
	var ex: Array = [p.get_rid()]
	if dist <= float(D.get("touch_m", 3.0)):
		return "sight"
	# Light: the torch in hand, from far.
	if Torch.instance != null and is_instance_valid(Torch.instance) and Torch.instance.lit() and Torch.instance._light != null:
		var lp: Vector3 = Torch.instance._light.global_position
		if eye.distance_to(lp) <= light_m(kind) and clear_line(eye, lp, ex):
			return "light"
	# Sight: you yourself.
	if dist <= sight_m(kind) and clear_line(eye, their_eye, ex):
		return "sight"
	# Sound: your footsteps.
	var nz := noise if noise >= 0.0 else float(override.get("noise", p.noise_level))
	if dist <= hearing_m(kind, nz):
		return "hearing"
	# Scent, downwind of you.
	if in_scent(float(row(kind).get("scent_m", 0.0)), eye, body, up):
		return "scent"
	return ""


## The lit planted torches `kind` at `eye` can see: [scene pos], nearest
## first (§DF.3: what comes for the light finds the torch).
static func torches_seen(kind: String, eye: Vector3, exclude: Array = []) -> Array:
	var out: Array = []
	for l in lights():
		if not bool(l.held) and sees_light(kind, eye, l.pos, exclude):
			out.append(l.pos)
	out.sort_custom(func(x: Vector3, y: Vector3) -> bool: return eye.distance_to(x) < eye.distance_to(y))
	return out


## The senses.json watcher kind for a roster species: "werewolf" for the
## werewolf, "night_animal" for what is out at night or at dusk, else
## "day_animal" (design §DF: the ordinary rosters, §CH).
static func kind_of(sp: CreatureSpecies) -> String:
	if sp == null:
		return "day_animal"
	if row(sp.name.to_lower()).size() > 0 and built(sp.name.to_lower()):
		return sp.name.to_lower()
	return "night_animal" if sp.active in ["night", "dusk", "full_moon"] else "day_animal"
