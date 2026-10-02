class_name Overrun
extends Node
## Overrun ruins: cleared means lit (design 2 Oct §CN, camps.json
## sim.overrun, delves.json overrun). A camp the dark emptied (§BL: its
## fire went out and its folk were taken, "no woodpile and blood") that
## has a den (a delve, §CJ, or a nest's first chamber, §CK) is overrun
## once it has gone to ruin (CampSim marks it); a camp left for hunger is
## not. On a new world nothing has been taken yet, so a seeded
## worldgen_share of the old ruins with a delve start overrun. The camp
## sim never resettles an overrun ruin.
##
## Below, it is always night: whatever holds the delve is there at any
## hour, the biome's hunter (dread.json hunters) in about hunter_share of
## them, else a creature of the night roster (night or dusk species whose
## climate fits; the dark itself where none does). They keep to the dark
## rooms: never within a lit fire-holder's radius (Campfire safe_m), and
## the dread's hunter follows the same rule (Dread, Campfire.lit_near).
## At night they come up: within night_surface.radius_m of the ruin,
## outside a fire, the dread fills dread_scale times as fast (Dread).
## Tells, no UI: by day the sound bed goes quiet near it (SoundBed),
## bones and scat lie at the barrow's door; at night a shape stands in the
## doorway and the hunter calls.
##
## Clearing: the heart's fire-holder (OldHearths, "FireHolder") laid and
## lit with the torch's swing clears the ruin: whatever held it leaves by
## the delve's way out (the cairn), and the log says so. The surface
## hearth can be lit any time and does not clear it. Kept per world
## (WorldSave "overrun": den id -> {"state": overrun | cleared | settled,
## "day", "fell", "dir", "people", "went_to", "survivors", "folk"}); the den
## id is the ruin's seed, or a nest's key.

static var CAMPS_SIM: Dictionary = Tuning.section("camps", "sim").get("overrun", {})
static var DV := Tuning.table("delves")
static var OV: Dictionary = DV.get("overrun", {})
static var LOG: Dictionary = DV.get("log", {})
## 0-1: how quiet the sound bed goes near an overrun ruin by day (SoundBed).
static var quiet := 0.0
## The overrun sites near the player (refreshed by the runtime): [{"dir",
## "id", "site" (or {}), "door" (scene position or INF)}].
static var near_sites: Array = []
## Tests: hold off clearing while a check reads the holders.
static var hold_clear := false
static var instance: Overrun = null

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var landmarks: Landmarks
var sky: SkySystem
## ruin node instance id -> {"node", "site", "holders": [Node3D], "props":
## [Node3D], "door_shape", "leaving": bool, "leave_t"}
var _dens := {}
var _timer := 0.0
var _call_t := 20.0
var _voice: AudioStreamPlayer3D


# --- The state ----------------------------------------------------------------------

static func saved() -> Dictionary:
	var s = WorldSave.data.get("overrun", null)
	if not s is Dictionary:
		s = {}
		WorldSave.data["overrun"] = s
	return s


static func id_of(site: Dictionary) -> String:
	return str(int(site.get("seed", 0)))


## An old ruin with a delve that started the world overrun (worldgen_share
## of them, seeded).
static func worldgen(site: Dictionary) -> bool:
	if site.is_empty() or not Delves.has_delve(site) or Ruins.inhabited(site):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(site.seed), "overrun"])
	return rng.randf() < float(CAMPS_SIM.get("worldgen_share", 0.3))


## "overrun", "cleared", "settled" or "" for a ruin site.
static func state_of(site: Dictionary) -> String:
	var s: Dictionary = saved().get(id_of(site), {})
	if not s.is_empty():
		return str(s.get("state", ""))
	return "overrun" if worldgen(site) else ""


static func is_overrun(site: Dictionary) -> bool:
	return state_of(site) == "overrun"


## Folk have come back to it (part 4: CampSim settles it; Camps builds
## its camp, OldHearths no longer builds its cold hearth).
static func settled(site: Dictionary) -> bool:
	return str((saved().get(id_of(site), {}) as Dictionary).get("state", "")) == "settled"


## The den held by the biome's hunter (hunter_share of them, seeded)?
static func hunter_held(id: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id, "den_hunter"])
	return rng.randf() < float(OV.get("hunter_share", 0.5))


## Has the camp `st` (CampSim) a den: a delve under its ruin, or a nest
## with a first chamber? Returns the den id ("" none).
static func den_of_camp(map: PlanetData, st: Dictionary) -> String:
	var key := str(st.get("key", ""))
	var needs: Array = CAMPS_SIM.get("needs_den", ["delve", "nest_first_chamber"])
	if key.begins_with("ruin:") and needs.has("delve") and map != null:
		var a: Array = st.dir
		var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		for s in Ruins.near(map, d, 400.0):
			if int(s.seed) == int(st.seed) and Delves.has_delve(s):
				return id_of(s)
		return ""
	var nest := Nests.by_key(key)
	if not nest.is_empty() and needs.has("nest_first_chamber") and str(nest.get("kind", "")) in ["cave_mouth", "grotto"]:
		return key
	return ""


## The camp sim (CampSim._tick_empty): a camp the dark took has gone to
## ruin. Overrun if it has a den (and the dark, not hunger, emptied it).
static func camp_fell(map: PlanetData, st: Dictionary, days: float) -> bool:
	if not bool(CAMPS_SIM.get("from_dark_taken", true)):
		return false
	# Taken by the dark (blood), not left for hunger (from_starving false).
	var why := str(st.get("why", ""))
	if not (why in ["taken", "fled"] and bool(st.get("blood", false))):
		return false
	var id := den_of_camp(map, st)
	if id == "":
		return false
	saved()[id] = {"state": "overrun", "day": days, "fell": days, "dir": st.dir, "people": st.get("people", ""),
		"key": st.get("key", ""), "went_to": st.get("went_to", ""), "survivors": int(st.get("survivors", 0))}
	WorldSave.mark_dirty()
	return true


## The heart's fire caught: cleared. Whatever held it leaves.
static func clear(site: Dictionary, days: float) -> void:
	var id := id_of(site)
	var s: Dictionary = saved().get(id, {})
	if str(s.get("state", "overrun")) != "overrun":
		return
	if s.is_empty():
		s = {"fell": -1.0, "dir": [site.dir.x, site.dir.y, site.dir.z]}
	s["state"] = "cleared"
	s["day"] = days
	saved()[id] = s
	WorldSave.mark_dirty()
	GameLog.add(str(LOG.get("heart_lit", "The fire at the heart caught. Whatever held this place has gone.")), "delve")


## The ruin site a saved den id names ({} for a nest's den, or not found).
static func site_of(map: PlanetData, id: String, e: Dictionary) -> Dictionary:
	if not id.is_valid_int() or map == null:
		return {}
	var a: Array = e.get("dir", [])
	if a.size() != 3:
		return {}
	var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	for s in Ruins.near(map, d, 600.0):
		if int(s.seed) == int(id):
			return s
	return {}


## The camp key Camps gives the ruin `site` ("ruin:<its grid cell>").
static func camp_key(map: PlanetData, site: Dictionary) -> String:
	for c in CreatureSpawner._cells_around(site.dir, 10.0, Ruins.CELL_M):
		var r := Ruins.find(map, c)
		if not r.is_empty() and int(r.seed) == int(site.seed):
			return "ruin:%s" % str(c)
	return ""


## Dread fills this many times as fast at `pos` (Dread, at night on the
## surface): within night_surface.radius_m of an overrun ruin.
static func dread_scale(pos: Vector3) -> float:
	if Delves.underground > 0.5:
		return 1.0
	var ns: Dictionary = OV.get("night_surface", {})
	var r := float(ns.get("radius_m", 120.0))
	for s in near_sites:
		var door: Vector3 = s.door
		if door != Vector3.INF and door.distance_to(pos) < r:
			return float(ns.get("dread_scale", 1.5))
	return 1.0


## What holds a den: the dread.json hunter entry for the biome, or a
## night-roster species fitting the climate ({} the dark itself).
static func holder_entry(map: PlanetData, d: Vector3, id: String, biome: String) -> Dictionary:
	if hunter_held(id):
		# The biome's own hunter (dread.json hunters), whichever it is.
		var e := Dread.entry_for(biome)
		for h in Dread.D.get("hunters", []):
			if h is Dictionary and (h.get("biomes", []) as Array).has(biome):
				e = h
		if e.get("creature") != null:
			return {"creature": str(e.creature), "pattern": str(e.get("pattern", "pacer")), "speed_mps": float(e.get("speed_mps", 5.8)), "hunter": true}
		return {"creature": "", "pattern": "pacer", "speed_mps": float(e.get("speed_mps", 5.8)), "hunter": true}
	var t := float(map.temp_c[map.cell_at(d)]) if map != null and not map.temp_c.is_empty() else 12.0
	var best: Array = []
	var fallback: Array = []
	for sp in CreatureSpecies.all():
		if sp.role == "mythical" or t < sp.temp_c.x or t > sp.temp_c.y:
			continue
		if sp.active in ["night", "dusk"]:
			best.append(sp)
		elif sp.temperament in ["predator", "aggressive", "hostile"]:
			fallback.append(sp)
	var pool := best if not best.is_empty() else fallback
	if pool.is_empty():
		return {"creature": "", "pattern": "pacer", "speed_mps": 5.8, "hunter": false}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id, "den_roster"])
	var pick: CreatureSpecies = pool[rng.randi() % pool.size()]
	return {"creature": pick.name, "pattern": "pacer", "speed_mps": maxf(pick.speed_mps, 3.0), "hunter": false}


## A body for a holder: the species' (CreatureBodies), else a cloaked
## shape, the dark itself.
static func body_for(creature: String) -> Node3D:
	var sp := CreatureSpecies.find(creature) if creature != "" else null
	if sp != null:
		var b = CreatureBodies.build(sp)
		if b is Dictionary and (b as Dictionary).get("root") is Node3D:
			return b.root
	var cb := CloakedFigure.build(2.1, Color(0.015, 0.015, 0.03), Color(0.03, 0.03, 0.05))
	return cb.root


# --- The runtime --------------------------------------------------------------------

func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_landmarks: Landmarks, p_sky: SkySystem) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	landmarks = p_landmarks
	sky = p_sky
	instance = self
	saved()
	_voice = Audio3D.make("dread_close", self, "DenCall")


func _exit_tree() -> void:
	if instance == self:
		instance = null
		quiet = 0.0
		near_sites = []
		Dread.den_entry = {}


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_refresh()
	var night := sky.daylight < 0.2 if sky != null else false
	var pp := player.global_position
	# The quiet by day, and what the dread meets underground.
	var q := 0.0
	var r := float((OV.get("night_surface", {}) as Dictionary).get("radius_m", 120.0))
	for s in near_sites:
		var door: Vector3 = s.door
		if door != Vector3.INF:
			q = maxf(q, 1.0 - smoothstep(r * 0.5, r, door.distance_to(pp)))
	quiet = move_toward(quiet, q * (0.0 if night else 0.85), delta / 3.0)
	Dread.den_entry = {}
	for id in _dens:
		var den: Dictionary = _dens[id]
		if not is_instance_valid(den.node):
			continue
		if Delves.inside and Delves.instance != null and Delves.instance.current_ruin == den.node and not bool(den.leaving):
			Dread.den_entry = den.entry
		_move_holders(den, delta)
		_door_tells(den, night, delta)
		_check_heart(den)


## Build the dens of the overrun delves built now; drop the rest.
func _refresh() -> void:
	var seen := {}
	var sites: Array = []
	if Delves.instance != null:
		for node: Node3D in Delves.instance.built():
			var site: Dictionary = node.get_meta("site")
			var st := state_of(site)
			var door := _door_point(node)
			if st == "overrun":
				sites.append({"dir": site.dir, "id": id_of(site), "site": site, "door": door})
			var id := node.get_instance_id()
			if st == "overrun" or (_dens.has(id) and bool(_dens[id].leaving)):
				seen[id] = true
				if not _dens.has(id):
					_dens[id] = _make_den(node, site)
	near_sites = sites
	for id in _dens.keys():
		if not seen.has(id) or not is_instance_valid(_dens[id].node):
			_free_den(_dens[id])
			_dens.erase(id)


## Where the barrow's way in meets the ground (its front end), in the scene.
func _door_point(node: Node3D) -> Vector3:
	var site: Dictionary = node.get_meta("site")
	var lp := Vector3(0.0, 0.0, -float(site.half_l) - 0.8)
	var p := node.global_transform * lp
	var d: Vector3 = world.dir_of(p)
	return world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))


## The dark rooms a holder keeps to, deepest first: [scene floor point].
func _room_spots(node: Node3D) -> Array:
	var lay: Dictionary = node.get_meta("delve")
	var off := float(node.get_meta("delve_off", 0.0))
	var out: Array = []
	# The heart's deep end, then the first room's near end (each as far
	# as it can be from the other room's fire).
	for k in [3, 1]:
		if k >= (lay.pieces as Array).size():
			continue
		var pc: Dictionary = lay.pieces[k]
		var c2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * (0.8 if k == 3 else 0.25)
		out.append(node.global_transform * Vector3(c2.x, float(pc.y0) - off + 0.02, c2.y))
	return out


func _make_den(node: Node3D, site: Dictionary) -> Dictionary:
	var id := id_of(site)
	var biome := FireStore.biome_key(world, site.dir)
	var entry := holder_entry(world.planet, site.dir, id, biome)
	var holders: Array = []
	var n := 1 if bool(entry.get("hunter", false)) else 2
	for i in n:
		var h := Node3D.new()
		h.name = "DenHolder"
		h.add_child(body_for(str(entry.creature)))
		world.world_root.add_child(h)
		h.set_meta("room", i)
		holders.append(h)
	var den := {"node": node, "site": site, "entry": entry, "holders": holders, "props": [], "door_shape": null,
		"leaving": false, "leave_t": 0.0, "spots": _room_spots(node)}
	for i in holders.size():
		var spots: Array = den.spots
		if not spots.is_empty():
			(holders[i] as Node3D).global_position = spots[i % spots.size()]
	den.props = _door_props(node)
	var shape := Node3D.new()
	shape.name = "DoorShape"
	shape.add_child(body_for(str(entry.creature)))
	world.world_root.add_child(shape)
	shape.visible = false
	den.door_shape = shape
	return den


func _free_den(den: Dictionary) -> void:
	for h in den.holders + den.props:
		if is_instance_valid(h):
			(h as Node).queue_free()
	if den.door_shape != null and is_instance_valid(den.door_shape):
		(den.door_shape as Node).queue_free()


## Is a lit fire within its own reach of `p`? (A fire-holder: safe_m.)
func _lit_at(p: Vector3) -> bool:
	return Campfire.lit_near(get_tree(), p, float((DV.get("fire_holders", {}) as Dictionary).get("light_radius_m", 8.0)) + 0.5)


## Holders keep to the dark rooms: each to its room, else to another
## unlit one; with none, out of sight. Leaving, they walk to the way out
## and are gone.
func _move_holders(den: Dictionary, delta: float) -> void:
	var spots: Array = den.spots
	var node: Node3D = den.node
	if bool(den.leaving):
		den.leave_t = float(den.leave_t) + delta
		var lay: Dictionary = node.get_meta("delve")
		var cairn: Dictionary = lay.get("cairn", {})
		var out := _door_point(node)
		if not cairn.is_empty():
			var o: Vector2 = cairn.o
			out = node.global_transform * Vector3(o.x, float(cairn.floor) - float(node.get_meta("delve_off", 0.0)), o.y)
		for h in den.holders:
			if is_instance_valid(h):
				var hn := h as Node3D
				hn.global_position = hn.global_position.move_toward(out, 3.5 * delta)
				hn.visible = float(den.leave_t) < 8.0
		return
	for h in den.holders:
		if not is_instance_valid(h):
			continue
		var hn := h as Node3D
		var want := Vector3.INF
		var i := int(hn.get_meta("room", 0))
		for k in spots.size():
			var p: Vector3 = spots[(i + k) % spots.size()]
			if not _lit_at(p):
				want = p
				break
		if want == Vector3.INF:
			hn.visible = false
			continue
		hn.visible = true
		var next := hn.global_position.move_toward(want, 2.5 * delta)
		# Caught in a fire's light, it is gone into the dark at once: it
		# never stands or walks within a lit fire's radius.
		if _lit_at(hn.global_position) or _lit_at(next):
			next = want
		hn.global_position = next
		# Turned to you when you come near.
		var up: Vector3 = world.dir_of(hn.global_position)
		var to := player.global_position - hn.global_position
		to = to - up * to.dot(up)
		if to.length() > 0.1:
			hn.global_basis = Basis.looking_at(to.normalized(), up)


## Bones and scat at the barrow's door (§CN tells), on the ground.
func _door_props(node: Node3D) -> Array:
	var out: Array = []
	var site: Dictionary = node.get_meta("site")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(site.seed), "den_door"])
	var bone := Color(0.78, 0.74, 0.64)
	var scat := Color(0.16, 0.12, 0.09)
	for i in 7:
		var lp := Vector3(rng.randf_range(-1.4, 1.4), 0.0, -float(site.half_l) - rng.randf_range(0.6, 2.4))
		var p := node.global_transform * lp
		var d: Vector3 = world.dir_of(p)
		var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
		var holder := Node3D.new()
		holder.name = "DenSign%d_%d" % [int(site.seed) % 100000, i]
		world.world_root.add_child(holder)
		holder.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(d), d).rotated(d, rng.randf() * TAU), at)
		if i < 4:
			var b := CreatureBodies.cone(holder, 0.03, 0.025, rng.randf_range(0.25, 0.45), Vector3(0, 0.03, 0), bone)
			b.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			CreatureBodies.box(holder, Vector3(0.07, 0.05, 0.06), Vector3(0, 0.03, rng.randf_range(0.12, 0.2)), bone.darkened(0.1))
		else:
			for k in 3:
				CreatureBodies.box(holder, Vector3(0.05, 0.04, 0.07), Vector3(rng.randf_range(-0.06, 0.06), 0.02, rng.randf_range(-0.06, 0.06)), scat)
		out.append(holder)
	return out


## At night a shape stands in the doorway (gone when you come close) and
## the hunter calls from the barrow now and then.
func _door_tells(den: Dictionary, night: bool, delta: float) -> void:
	var shape: Node3D = den.door_shape
	if shape == null or not is_instance_valid(shape):
		return
	var door := _door_point(den.node)
	var dist := door.distance_to(player.global_position)
	var r := float((OV.get("night_surface", {}) as Dictionary).get("radius_m", 120.0))
	shape.visible = night and not bool(den.leaving) and dist > 12.0 and dist < r and not Delves.inside
	if shape.visible:
		var d: Vector3 = world.dir_of(door)
		var out := door - (den.node as Node3D).global_position
		out = (out - d * out.dot(d)).normalized()
		shape.global_transform = Transform3D(Basis.looking_at(out if out.length() > 0.1 else CubeSphere.north(d), d), door)
	if night and dist < r and not bool(den.leaving):
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = randf_range(30.0, 70.0)
			_voice.global_position = door + world.dir_of(door) * 1.5
			_voice.stream = SoundSynth.stream("howl" if str(den.entry.creature) == "Werewolf" else "whisper", randi())
			Audio3D.play(_voice)


## The heart's fire caught: the ruin is cleared, its holders leave.
func _check_heart(den: Dictionary) -> void:
	if bool(den.leaving) or hold_clear:
		return
	var seed_v := int((den.site as Dictionary).seed)
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var fire := f as Node3D
		if fire != null and fire.has_meta("heart_of") and int(fire.get_meta("heart_of")) == seed_v and FireStore.is_lit(fire):
			clear(den.site, world.days)
			den.leaving = true
			den.leave_t = 0.0
			for p in den.props:
				if is_instance_valid(p):
					(p as Node).queue_free()
			den.props = []
			return


## The holders of the den under `node` now (tests).
func holders_of(node: Node3D) -> Array:
	var den: Dictionary = _dens.get(node.get_instance_id(), {})
	return den.get("holders", [])
