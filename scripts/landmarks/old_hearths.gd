class_name OldHearths
extends Node
## Old hearths (Mike, 2 Oct, on the §CJ audit: "a relightable hearth would
## be cool for abandoned camps with your own torch"): where people once
## kept a fire and nobody does now, the hearth is still there, cold. Each
## uninhabited ruin's camp spot (RuinBuilder's camp_spot) and each nest
## that holds an old camp's remains (Nests, state "remains", §CK) has one:
## the ring of stones round cold ash and a couple of charred branches
## (old_hearth_units). Right click it with a lit torch and it catches;
## feed it like any fire (§AX). Lit, it is a fire like any other: it holds
## the dark off (§BA), you can make it your hearth (§AY), and at a tomb it
## lights the lamps inside (RuinBuilder tomb lamps, Landmarks). Untended,
## it burns at the full rate and goes out when its fuel is gone.
##
## Fire is carried, never made (30 Sept §BP): the torch is the only way
## to light one.
##
## A hearth's fire is kept per world once it has been lit (WorldSave
## "old_hearths": key -> its FireStore store plus "dir" and "seen"), and
## burns down while you are away (caught up from "seen" when it is built
## again or asked about).

const BUILD_M := 220.0
const DROP_M := 280.0

static var instance: OldHearths = null

var world: Node
var chunks: ChunkManager
var player: Node3D
var landmarks: Landmarks
var _root: Node3D
var _built := {} # fuel key -> Node3D
var _timer := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D, p_landmarks: Landmarks) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	landmarks = p_landmarks
	instance = self
	_root = Node3D.new()
	_root.name = "OldHearths"
	world.world_root.add_child(_root)
	if not WorldSave.data.get("old_hearths", null) is Dictionary:
		WorldSave.data["old_hearths"] = {}


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Charred branches left in a cold hearth (fuel.json fire.old_hearth_units,
## default 2): enough for the torch to catch, not enough to last.
static func start_units() -> int:
	return int(FireStore.F.get("old_hearth_units", 2))


## Real minutes in one game day (the catch-up clock).
static func _min_per_day(w: Node) -> float:
	return float(w.get("day_length_s")) / 60.0 if w != null else 144.0


## The store for the old hearth at `d` (made cold if new), caught up to
## now. Shared with FireStore.stores and, once lit, the save.
static func store_at(w: Node, d: Vector3) -> Dictionary:
	var key := FireStore.key_of(d)
	var st: Dictionary = FireStore.stores.get(key, {})
	if st.is_empty():
		var saved: Dictionary = WorldSave.data.get("old_hearths", {})
		st = saved.get(key, {})
		if st.is_empty():
			var units: Array = []
			for i in start_units():
				units.append(["branch", FireStore.burn_min("branch") * 0.6])
			st = {"units": units, "embers_min": 0.0, "state": "out", "tended": false}
		FireStore.stores[key] = st
	st["dir"] = [d.x, d.y, d.z]
	catch_up(w, st)
	return st


## Burn a store down for the time since it was last seen.
static func catch_up(w: Node, st: Dictionary) -> void:
	var days := float(w.get("days")) if w != null else 0.0
	if st.has("seen"):
		var minutes := (days - float(st.seen)) * _min_per_day(w)
		# In steps, so a fire that burns out while you are away goes on
		# from embers to out (FireStore.burn takes one step per call).
		var step := maxf(1.0, minutes / 200.0)
		while minutes > 0.0 and str(st.get("state", "out")) != "out":
			FireStore.burn(st, minf(step, minutes))
			minutes -= step
	st["seen"] = days


## Is there an old hearth burning within `within_m` of `d`? (Main: you
## wake at your hearth only while some fire stands there.)
static func lit_at(w: Node, d: Vector3, within_m := 30.0) -> bool:
	var saved: Dictionary = WorldSave.data.get("old_hearths", {})
	for key in saved:
		var st: Dictionary = FireStore.stores.get(key, saved[key])
		var a: Array = st.get("dir", [])
		if a.size() != 3:
			continue
		var hd := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		if CubeSphere.surface_distance_m(hd, d) > within_m:
			continue
		catch_up(w, st)
		if str(st.get("state", "out")) in ["flames", "low"]:
			return true
	return false


## The old hearths near surface direction `pd`: [dir, kind ("ruin" or
## "nest"), ruin node or null] for each uninhabited ruin built now and
## each nest holding remains.
func _wanted(pd: Vector3) -> Dictionary:
	var want := {}
	var ruins := landmarks.built_ruins()
	for c in ruins:
		var node: Node3D = ruins[c]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var site: Dictionary = node.get_meta("site", {})
		if site.is_empty() or Ruins.inhabited(site) or not node.has_meta("camp_spot"):
			continue
		var spot: Vector3 = node.global_transform * (node.get_meta("camp_spot") as Vector3)
		var sd: Vector3 = world.dir_of(spot)
		if CubeSphere.surface_distance_m(sd, pd) < BUILD_M:
			want[FireStore.key_of(sd)] = [sd, "ruin", node]
	for n in Nests.near(pd, BUILD_M):
		if str(n.state) != "remains":
			continue
		var hd: Vector3 = n.hearth
		if hd == Vector3.ZERO or CubeSphere.surface_distance_m(hd, pd) > BUILD_M:
			continue
		want[FireStore.key_of(hd)] = [hd, "nest", null]
	return want


func _build(d: Vector3, kind: String, ruin: Node3D) -> Node3D:
	var st := store_at(world, d)
	var fire := Campfire.build(_root, world, chunks, d, false)
	# Campfire.build registers a tended store only when there is none; this
	# one is the old hearth's own, untended.
	st.tended = false
	FireStore.apply(fire)
	fire.name = "OldHearth"
	fire.set_meta("old_hearth", true)
	fire.set_meta("old_kind", kind)
	# Lit, it can be your hearth (§AY), like a camp's.
	fire.set_meta("hearth_ok", true)
	if ruin != null:
		fire.set_meta("ruin", ruin)
		# A stone ruin's camp spot stands on its floor, not the ground.
		var spot: Vector3 = ruin.global_transform * (ruin.get_meta("camp_spot") as Vector3)
		fire.global_position = spot
	# The logs left in it are charred.
	for c in fire.get_children():
		if c is MeshInstance3D and c.name != "Coals" and (c as MeshInstance3D).mesh is CylinderMesh:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.09, 0.07, 0.06)
			(c as MeshInstance3D).material_override = m
	return fire


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		refresh_now()
	# Flicker every frame (Campfire.flicker).
	var t := Time.get_ticks_msec() / 1000.0
	for key in _built:
		var n: Node3D = _built[key]
		if is_instance_valid(n) and n.is_inside_tree():
			Campfire.flicker(n, t)


## Build the hearths in reach now (after waking by a fire), drop the far
## ones, and keep the lit ones' clocks.
func refresh_now() -> void:
	var pd: Vector3 = world.dir_of(player.global_position)
	var want := _wanted(pd)
	for key in want:
		if not _built.has(key) or not is_instance_valid(_built[key]):
			var w: Array = want[key]
			_built[key] = _build(w[0], w[1], w[2])
	var saved: Dictionary = WorldSave.data["old_hearths"]
	for key in _built.keys():
		var node: Node3D = _built[key]
		if not is_instance_valid(node) or not want.has(key):
			if is_instance_valid(node):
				NodeRelease.free_later(node)
			_built.erase(key)
			continue
		var st: Dictionary = FireStore.stores.get(key, {})
		if st.is_empty():
			continue
		st["seen"] = float(world.days)
		# Kept once it has burnt (the save holds the same dictionary).
		if not saved.has(key) and str(st.state) != "out":
			saved[key] = st
			WorldSave.mark_dirty()


## The old hearth node built nearest `pos` within `radius` m, or null.
func nearest(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for key in _built:
		var n: Node3D = _built[key]
		if is_instance_valid(n) and n.global_position.distance_to(pos) < best_d:
			best_d = n.global_position.distance_to(pos)
			best = n
	return best


## Is the fire of `ruin` (its old hearth) burning? (Tomb lamps.)
func ruin_lit(ruin: Node3D) -> bool:
	for key in _built:
		var n: Node3D = _built[key]
		if is_instance_valid(n) and n.get_meta("ruin", null) == ruin:
			return FireStore.is_lit(n)
	return false
