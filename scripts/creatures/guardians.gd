class_name Guardians
extends Node
## Guardians (design 4 Oct §ED.6, rungs.json guardians). Some overrun ruins
## (§CN) have a mythic holding the ground outside, on top of what lurks in
## the dark inside: one whose rungs.json mythic is guardian true (the dire
## wolf for now), bound to share of the overrun ruins, seeded per ruin. Its
## ground lies ground_out_m beyond the ruin's door; it keeps hold_m round
## it (Creature._guardian):
##   - flesh and blood, it ignores light: a torch or a fire does not turn it;
##   - a walker in its sight (no faster than slow_mps) it closes on, and
##     bites (bite) within reach;
##   - a runner (run_mps or faster) spooks it off for spook_s;
##   - it ranges out at dusk to hunt and is back at dawn: the ground is
##     empty from dusk until dawn;
##   - a wound from spear or bow drives it off for drive_off_game_h game
##     hours;
##   - when the ruin's hearth is restored (the ruin is no longer overrun:
##     cleared or settled) it leaves for good (WorldSave "guardians": id ->
##     {"gone": true, "away_until": days}).

static var G: Dictionary = (Tuning.table("rungs").get("guardians", {}) as Dictionary)
static var instance: Guardians = null

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var spawner: CreatureSpawner
## ruin id -> Creature (standing now)
var standing := {}
var _timer := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_spawner: CreatureSpawner) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	spawner = p_spawner
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func saved() -> Dictionary:
	var s = WorldSave.data.get("guardians", null)
	if not s is Dictionary:
		s = {}
		WorldSave.data["guardians"] = s
	return s


## The guardian species bound to overrun ruin `id` (a mythic variant), or
## null: share of them, seeded.
static func species_for(id: String) -> CreatureSpecies:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id, "guardian"])
	if rng.randf() >= float(G.get("share", 0.5)):
		return null
	var pool: Array[CreatureSpecies] = []
	var all: Dictionary = Rungs.D.get("species", {})
	for k in all:
		var m: Dictionary = (all[k] as Dictionary).get("mythic", {})
		if not bool(m.get("guardian", false)):
			continue
		var base := _base_species(str(k))
		if base != null:
			pool.append(Rungs.variant(base, "mythic"))
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]


## The creature a rungs.json key stands for: its own name, else the first
## species whose last word it is ("Wolf": the Arctic wolf).
static func _base_species(key: String) -> CreatureSpecies:
	var sp := CreatureSpecies.find(key)
	if sp != null:
		return sp
	for s in CreatureSpecies.all():
		if s.role == "mythical":
			continue
		var w := s.name.split(" ")
		if w[w.size() - 1].to_lower() == key.to_lower():
			return s
	return null


## Is the guardian of ruin `id` on its ground now? Not gone, not driven
## off, not out hunting (dusk until dawn).
func present(id: String, d: Vector3) -> bool:
	var st: Dictionary = saved().get(id, {})
	if bool(st.get("gone", false)):
		return false
	if float(st.get("away_until", -1.0)) > float(world.days):
		return false
	var c: Vector2 = world.local_clock(d)
	var phase := FireCircle.phase_name(c.y, CubeSphere.latitude(d), world.days)
	return phase != "dusk" and phase != "night"


func _process(delta: float) -> void:
	if world == null or player == null or spawner == null:
		return
	_timer -= delta
	# Feed each standing guardian your pace every frame.
	var up: Vector3 = player.up if "up" in player else world.dir_of(player.global_position)
	var spd: float = (player.velocity - up * player.velocity.dot(up)).length()
	for id in standing:
		var cr: Creature = standing[id]
		if is_instance_valid(cr):
			cr.guard["player_speed"] = spd
	if _timer > 0.0:
		return
	_timer = 1.0
	var pd: Vector3 = player.surface_dir
	var want := {}
	for s in Overrun.near_sites:
		var id := str(s.id)
		var sp := species_for(id)
		if sp == null:
			continue
		var site: Dictionary = s.get("site", {})
		if site.is_empty():
			continue
		# The hearth restored: gone for good.
		if not Overrun.is_overrun(site):
			_gone(id)
			continue
		var ground := ground_of(s)
		if CubeSphere.surface_distance_m(ground, pd) > float(G.get("spawn_within_m", 220.0)):
			continue
		if present(id, ground):
			want[id] = [sp, ground]
	# Gone for good from ruins the runtime no longer calls overrun.
	for id in standing.keys():
		var cr: Creature = standing[id]
		if not is_instance_valid(cr) or cr.done:
			standing.erase(id)
			continue
		if str(cr.guard.get("state", "")) == "driven":
			# Wounded: off for drive_off_game_h.
			var st: Dictionary = saved().get(id, {})
			st["away_until"] = float(world.days) + float(G.get("drive_off_game_h", 8.0)) / 24.0
			saved()[id] = st
			WorldSave.mark_dirty()
			GameLog.add("It breaks off and runs, wounded. It will be back.", "guardian")
			cr.guard["state"] = "spooked"
			cr.guard["spook_s"] = 9999.0
			cr.leave()
			standing.erase(id)
			continue
		if not want.has(id):
			cr.leave()
			standing.erase(id)
	for id in want:
		if standing.has(id):
			continue
		standing[id] = _spawn(id, want[id][0], want[id][1])


## The guardian's ground: ground_out_m beyond the ruin's door, along the
## way out from the ruin's middle (or its own seeded bearing).
func ground_of(s: Dictionary) -> Vector3:
	var site: Dictionary = s.get("site", {})
	var d: Vector3 = site.get("dir", s.dir)
	var door = s.get("door", Vector3.INF)
	var out_m := float(G.get("ground_out_m", 22.0))
	if door is Vector3 and door != Vector3.INF:
		var dd: Vector3 = world.dir_of(door)
		var away := (dd - d)
		if away.length() > 1e-9:
			return (dd + away.normalized() * out_m / PlanetConst.RADIUS_M).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(s.id), "ground"])
	return CreatureSpawner._offset(d, rng.randf() * TAU, 30.0 + out_m)


func _spawn(id: String, sp: CreatureSpecies, ground: Vector3) -> Creature:
	var cr := Creature.new()
	spawner.adopt(cr)
	cr.setup(sp, world, chunks, spawner, ground, hash([id, "guardian", int(world.days)]))
	cr.set_meta("guardian_of", id)
	cr.guard = {"ground": ground, "hold_m": float(G.get("hold_m", 28.0)), "state": "hold", "t": 0.0,
		"player_speed": 0.0, "slow_mps": float(G.get("slow_mps", 2.2)), "run_mps": float(G.get("run_mps", 4.5)),
		"spook_s": float(G.get("spook_s", 10.0)), "bite": float(G.get("bite", 24.0))}
	return cr


func _gone(id: String) -> void:
	var st: Dictionary = saved().get(id, {})
	if bool(st.get("gone", false)):
		return
	st["gone"] = true
	saved()[id] = st
	WorldSave.mark_dirty()
	if standing.has(id) and is_instance_valid(standing[id]):
		(standing[id] as Creature).leave()
		standing.erase(id)
