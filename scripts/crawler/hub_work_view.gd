class_name HubWorkView
extends Node3D
## The keepers' work on screen (design §GM, §GO.1-3; queue 122-123): a
## child of the hub camp running its HubWork and showing it.
##
##   the keepers  walk where their step takes them (FolkMotion, the same
##                one DayShift's lighting rounds use; DayShift has them at
##                dusk and dawn), work bent over the station, sit at their
##                seat or a bench by the fire, go out of sight while away
##                (a hunt past the camp's edge, the dugout out on the
##                river) and into their shelter at night; what they carry
##                rides their right hand; after dark they carry a lit
##                torch in the left, its light moving with them (Mike, 6 Nov)
##   the store    each good drawn at its prop (stocks → show): logs on the
##                woodpile, fish on the line, pots on the plank, hides on
##                the rack ... as many as count / cap of its pieces
##   the tools    the wearing ones at their spots (§GM.2): gone while in a
##                hand, lying dark and broken till the new one comes
##   the chains   every item at its station, shown at the stage it is up
##                to (a gutted fish on the stone, a hide soaking in the pit,
##                wood drying under the lean-to): the station is the
##                progress bar (§GO.2)
##   upgrades     a hide cover over a lean-to, bedding inside, a waterskin
##                on the gourd line, horn cups by the hearth, painted posts
##
## The work is stepped every sim.tick_s real seconds from the world's clock
## (so a fast-forward or time away is caught up, §GM.9), never per frame;
## only the walking is per frame. The camp is kept in the save (§FK) as
## CrawlerSave.data.hub_work.

var hub: HubCamp
var sim: HubWork
var _acc := 1e9
var _saved_t := 0.0
var _motion := {}
var _folk := {}
var _pose := {}
var _stock := {}
var _tool := {}
var _items := {}
var _ups := {}
var _carry := {}
var _smoke := {}
## Each keeper's torch: k -> {"root", "light", "seed"}.
var _torch := {}
var _torch_t := 0.0
## The camp's band at the evening meal (design §GO.10.1, queue 125):
## instrument -> its player's AudioStreamPlayer3D.
var _band := {}
## Minutes caught up at the last setup (the checks).
var caught_min := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_hub: HubCamp) -> void:
	hub = p_hub
	sim = HubWork.new()
	sim.log_max = 600
	var day_min := float(hub.world.get("day_length_s")) / 60.0
	var days := float(hub.world.get("days"))
	var kept: Variant = CrawlerSave.data.get("hub_work", null)
	if kept is Dictionary and not (kept as Dictionary).is_empty():
		sim.from_dict(kept, day_min)
	else:
		sim.fresh(hub.seed_value, days, day_min)
	sim.place(hub.work_spots())
	sim.prey_fn = _prey
	sim.kill_fn = _kill
	if kept is Dictionary and not (kept as Dictionary).is_empty():
		caught_min = sim.catch_up(days)
	_saved_t = sim.t
	_rng.seed = hash([hub.seed_value, "work view"])
	_stations()
	_build_stock()
	_build_tools()
	for f in hub.keeper_folk:
		var k := str((f as HearthFolk).get_meta("keeper"))
		_folk[k] = f
		var r: Dictionary = hub.day_shift._rounds.get(k, {}) if hub.day_shift != null else {}
		var m: FolkMotion = r.get("motion", null)
		if m == null:
			m = FolkMotion.new(f)
			m.ground = hub.land.height_at
		_motion[k] = m
		_pose[k] = {"seated": true, "to": Vector3.INF, "hidden": false}
		_make_torch(k, f)
	print("[hub work] %s camp: %d goods, %d tools, %d items in the chains, %d upgrades%s" % ["kept" if kept is Dictionary else "new", sim.store.size(), sim.tools.size(), sim.items.size(), sim.upgrades.size(), (", caught up %.0f min" % caught_min) if caught_min > 0.0 else ""])


func _process(delta: float) -> void:
	if hub == null or not hub.is_inside_tree():
		return
	tick(delta)


## One frame (the checks drive it with their own delta).
func tick(delta: float) -> void:
	_acc += delta
	if _acc >= float(sim.S.get("tick_s", 15.0)):
		_acc = 0.0
		step()
	_drive(delta)
	_play_band()


## The work stepped to the world's clock now, and the props redrawn.
func step() -> void:
	var days := float(hub.world.get("days"))
	sim.band_learned = RealmFolk.learned()
	var dt := (days - sim.days0) * sim.day_min - sim.t
	if dt > 5.0:
		sim.catch_up(days)
	elif dt > 0.0:
		sim.advance(dt)
	refresh()
	CrawlerSave.data["hub_work"] = sim.to_dict()
	if sim.t - _saved_t >= float(sim.S.get("save_every_min", 6.0)):
		_saved_t = sim.t
		CrawlerSave.save()


## Written to the save (leaving the hub).
func flush() -> void:
	if sim == null:
		return
	CrawlerSave.data["hub_work"] = sim.to_dict()
	CrawlerSave.save()


# --- The keepers ----------------------------------------------------------------------

func _drive(delta: float) -> void:
	var speed := float(sim.S.get("walk_mps", 1.1))
	_torch_t += delta
	for k in _folk:
		var f: HearthFolk = _folk[k]
		var m: FolkMotion = _motion[k]
		var pz: Dictionary = _pose[k]
		_carry_torch(k, f, m, pz)
		var r: Dictionary = hub.day_shift._rounds.get(k, {}) if hub.day_shift != null else {}
		if bool(r.get("walking", false)):
			# The lighting round is DayShift's (§GF).
			pz.seated = false
			pz.to = Vector3.INF
			_show(k, f, true)
			continue
		var kp: Dictionary = sim.keepers.get(k, {})
		var st := sim.step_of(k)
		var doing := str(st.get("do", "idle"))
		var goal_spot := str(st.to) if doing in ["go", "carry"] else str(kp.get("at", ""))
		var goal: Vector3 = sim.spots.get(goal_spot, f.global_position)
		var here := f.global_position
		var far := Vector2(goal.x - here.x, goal.z - here.z).length()
		_carrying(k, f, kp)
		if bool(kp.get("away", false)):
			_show(k, f, false)
			continue
		if far > 0.35:
			_show(k, f, true)
			if bool(pz.seated):
				m.rise_from_seat(Vector3(here.x, hub.land.height_at(here.x, here.z), here.z))
				m.stand_up()
				pz.seated = false
			if (pz.to as Vector3) != goal:
				pz.to = goal
				m.walk_to(PackedVector3Array([goal]))
			m.release(1)
			m.walk(delta, speed, 240.0)
			m.update(delta)
			continue
		pz.to = Vector3.INF
		match doing:
			"sleep":
				# In their shelter for the night (§GM.8.7).
				_show(k, f, not goal_spot.ends_with(".shelter"))
			"work":
				_show(k, f, true)
				_stand(k, m, pz)
				var at: Vector3 = sim.spots.get(str(kp.at), goal)
				var face := Vector3(at.x - hub.camp.pos.x, 0.0, at.z - hub.camp.pos.z)
				m.turn_toward(-face.normalized() if face.length() > 0.1 else m.front(), delta, 120.0)
				var bob := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004 + float(k.hash() % 7))
				m.crouch(0.35 + 0.25 * bob)
				m.reach_point(1, f.global_position + m.front() * 0.55 + Vector3(0, 0.35 + 0.25 * bob, 0))
			_:
				_show(k, f, true)
				m.release(1)
				m.crouch(0.0)
				if goal_spot == "%s.seat" % k or goal_spot.begins_with("bench.") or goal_spot.ends_with(".seat"):
					if not bool(pz.seated):
						var fp: Vector3 = hub.camp.pos
						var yaw := FolkMotion.yaw_of(Vector3(fp.x - goal.x, 0.0, fp.z - goal.z)) if goal_spot.begins_with("bench.") else float(r.get("yaw", f.rotation.y))
						m.sit_at(goal, yaw)
						pz.seated = true
				else:
					_stand(k, m, pz)
		m.update(delta)


func _stand(_k: String, m: FolkMotion, pz: Dictionary) -> void:
	if bool(pz.seated):
		var p := m.f.global_position
		m.rise_from_seat(Vector3(p.x, hub.land.height_at(p.x, p.z), p.z))
		m.stand_up()
		pz.seated = false


func _show(k: String, f: HearthFolk, on: bool) -> void:
	if f.visible != on:
		f.visible = on
	(_pose[k] as Dictionary).hidden = not on


## Keeper `k`'s torch, in its left fist: a stick, the pitch head alight and
## its own light; out of sight till dark (built here so the glossy look
## smooths its flame with the rest of the camp).
func _make_torch(k: String, f: HearthFolk) -> void:
	var arm: Node3D = f.body.arms[0] if f.body != null else null
	var elbow := arm.get_node_or_null("ElbowL") as Node3D if arm != null else null
	if elbow == null:
		return
	var T: Dictionary = (HubCamp.H.get("keepers", {}) as Dictionary).get("folk_torch", {})
	var root := Node3D.new()
	root.name = "FolkTorch"
	root.position = FolkMotion.FIST_L
	root.visible = false
	elbow.add_child(root)
	var top := 0.34
	hub._rod(root, Vector3(0, -0.22, 0), Vector3(0, top, 0), 0.02, 0.018, "#4a3220", 0.6)
	var head := PitchTorch.head_node(0.02, k.hash())
	head.position = Vector3(0, top - PitchTorch.length_m() * 0.9, 0)
	root.add_child(head)
	PitchTorch.set_lit(head, true)
	var l := OmniLight3D.new()
	l.name = "FolkTorchLight"
	l.light_color = Torch.fire_color()
	l.light_energy = float(T.get("energy", 1.6))
	l.omni_range = float(T.get("range_m", 9.0))
	l.position = Vector3(0, top + 0.2, 0)
	root.add_child(l)
	_torch[k] = {"root": root, "light": l, "seed": float(k.hash() % 97)}


## After dark, up and about: the torch held out ahead and upright, flickering.
## Sitting or by day it is put by.
func _carry_torch(k: String, f: HearthFolk, m: FolkMotion, pz: Dictionary) -> void:
	var e: Dictionary = _torch.get(k, {})
	if e.is_empty():
		return
	var root: Node3D = e.root
	var on := hub.day_shift != null and hub.day_shift.is_night(k) and not bool(pz.seated)
	if root.visible != on:
		root.visible = on
		if not on:
			m.release(0)
	if not on or not f.visible:
		return
	var front := m.front()
	m.reach(0, f.global_position + front * 0.4 + Vector3.UP.cross(front) * 0.22 + Vector3.UP * f.height * 0.82)
	root.global_basis = Basis.IDENTITY
	var T: Dictionary = (HubCamp.H.get("keepers", {}) as Dictionary).get("folk_torch", {})
	var t := _torch_t * 9.0 + float(e.seed)
	(e.light as OmniLight3D).light_energy = float(T.get("energy", 1.6)) * (1.0 + float(T.get("flicker", 0.18)) * (0.6 * sin(t) + 0.4 * sin(t * 2.7 + 1.3)))


## Torches alight now (the checks).
func torches_lit() -> int:
	return _torch.values().filter(func(e): return (e.root as Node3D).is_visible_in_tree()).size()


## What keeper `k` carries, in its right hand: goods, an item of a chain,
## or a tool it has taken.
func _carrying(k: String, f: HearthFolk, kp: Dictionary) -> void:
	var what := ""
	if not (kp.get("carry", {}) as Dictionary).is_empty():
		what = "goods"
	elif int(kp.get("item", -1)) >= 0:
		what = "item"
	else:
		for id in sim.tools:
			if str(sim.tools[id].by) == k:
				what = "tool"
				break
	var mi: MeshInstance3D = _carry.get(k, null)
	if what == "":
		if mi != null:
			mi.visible = false
		return
	if mi == null:
		var arm: Node3D = f.body.arms[1] if f.body != null else null
		var elbow := arm.get_node_or_null("ElbowR") as Node3D if arm != null else null
		if elbow == null:
			return
		mi = MeshInstance3D.new()
		mi.name = "Carry"
		elbow.add_child(mi)
		mi.position = HearthFolk.FIST + Vector3(0, -0.08, 0)
		_carry[k] = mi
	if str(mi.get_meta("what", "")) != what:
		mi.set_meta("what", what)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.7, 0.05) if what == "tool" else Vector3(0.32, 0.2, 0.22)
		mi.mesh = bm
		mi.material_override = hub._mat("#6b4a2e" if what == "tool" else "#8a7a4a", 0.7)
	mi.visible = true


## The band (§GO.10.1): through the evening meal, each instrument the maker
## has built is played by its keeper on the bench, one more layer each.
func _play_band() -> void:
	var ph := sim.phase()
	var evening := str(ph.part) == "night" and float(ph.get("since_dark", 0.0)) < float(sim.S.get("evening_min", 12.0))
	for id in sim.band_made:
		var k := str(sim.band_made[id])
		var f: HearthFolk = _folk.get(k, null)
		if f == null:
			continue
		var a: AudioStreamPlayer3D = _band.get(id, null)
		if a == null:
			a = AudioStreamPlayer3D.new()
			a.name = "Band_" + str(id)
			a.stream = RealmFolk.tune_stream(str(id))
			a.bus = AudioMix.bus("ambience")
			a.unit_size = 6.0
			f.add_child(a)
			a.position = Vector3(0, 1.1, 0)
			_band[id] = a
		var on := evening and str(sim.step_of(k).get("do", "")) == "meal" and f.visible
		if on and not a.playing:
			a.play()
		elif not on and a.playing:
			a.stop()


## The instruments being played now.
func band_playing() -> Array:
	return _band.keys().filter(func(id): return (_band[id] as AudioStreamPlayer3D).playing)


# --- Real game for the hunter (§GM.4) -------------------------------------------------------

func _prey() -> Vector3:
	if hub.life == null:
		return Vector3.INF
	var fp: Vector3 = hub.camp.pos
	var reach := float(sim.S.get("hunt_reach_m", 60.0))
	var best := Vector3.INF
	for a in hub.life.animals:
		if str(a.get("state", "")) == "asleep" or not (a.root as Node3D).visible:
			continue
		var p: Vector3 = a.pos
		var d := Vector2(p.x - fp.x, p.z - fp.z).length()
		if d <= reach and (best == Vector3.INF or d < Vector2(best.x - fp.x, best.z - fp.z).length()):
			best = p
	return best


func _kill(at: Vector3) -> void:
	if hub.life == null:
		return
	for a in hub.life.animals:
		var p: Vector3 = a.pos
		if p.distance_to(at) < 6.0:
			hub.life.animals.erase(a)
			(a.root as Node3D).queue_free()
			return


# --- Bringing (§GO.2) ---------------------------------------------------------------------

## Set down what you carry that the camp can use, in the store. True if
## anything went in.
func try_bring(inv: Inventory) -> bool:
	var B: Dictionary = sim.D.get("store", {})
	var any := false
	var i := 0
	while i < inv.carried.size():
		var it: Variant = inv.carried[i]
		var what := ""
		if it is Dictionary:
			what = str(it.get("what", "")) if str(it.get("kind", "")) == "haul" else str(it.get("kind", ""))
		if what != "" and ((sim.D.get("bring", {}) as Dictionary).get(what, null) is Dictionary) and sim.bring(what):
			inv.take(i)
			GameLog.add(str(B.get("log_drop", "You set the {name} down in the camp store.")).format({"name": str(it.get("name", what.replace("_", " ")))}), "world")
			any = true
			continue
		i += 1
	if any:
		refresh()
		CrawlerSave.data["hub_work"] = sim.to_dict()
		CrawlerSave.save()
	return any


# --- The props ----------------------------------------------------------------------------

## The stations §GO.1 adds that the 26 Oct camp had no prop for: the
## butchering stone, the cleaning stone at the water, the weaving frame,
## the sorting mat, the drying mats, the settling jar, the soak pit.
func _stations() -> void:
	var looks := {
		"hunter_tanner.butchering_stone": ["slab", "#5a5c78"],
		"hunter_tanner.soak_pit": ["pit", "#1e1a16"],
		"fisher_weaver.cleaning_stone": ["slab", "#6a6c8a"],
		"fisher_weaver.weaving_frame": ["frame", "#5a4026"],
		"forager_herbalist.sorting_mat": ["mat", "#8a7a4a"],
		"forager_herbalist.drying_mats": ["mat", "#7a6a3a"],
		"forager_herbalist.water_jar": ["jar", "#8a5a3a"],
	}
	for sp in looks:
		if not sim.spots.has(sp):
			continue
		var at: Vector3 = sim.spots[sp]
		var n := Node3D.new()
		n.name = "Station_" + str(sp).replace(".", "_")
		n.position = at
		add_child(n)
		var c := str(looks[sp][1])
		match str(looks[sp][0]):
			"slab":
				hub._block(n, Vector3(0.9, 0.22, 0.6), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), c, 0.3, false)
			"pit":
				hub._cyl(n, 0.55, 0.6, 0.08, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), c, 0.9)
			"frame":
				hub._rod(n, Vector3(-0.6, 0, 0), Vector3(-0.6, 1.3, 0), 0.035, 0.03, c)
				hub._rod(n, Vector3(0.6, 0, 0), Vector3(0.6, 1.3, 0), 0.035, 0.03, c)
				hub._rod(n, Vector3(-0.65, 1.25, 0), Vector3(0.65, 1.25, 0), 0.025, 0.025, c)
			"mat":
				hub._block(n, Vector3(1.2, 0.03, 0.8), Transform3D(Basis.IDENTITY, Vector3(0, 0.015, 0)), c, 0.95, false)
			"jar":
				hub._cyl(n, 0.2, 0.16, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), c, 0.4)


## How each good is drawn: [shape, colour]. stack: logs in rows; line:
## things hung on a line; row: pots stood in a row; pile: a heap of bits;
## bundle: tied bundles; level: one vessel, fuller with more.
const LOOK := {
	"firewood": ["stack", "#5a3e24"], "kindling": ["bundle", "#7a5a34"], "logs": ["stack", "#4a3220"],
	"raw_meat": ["pile", "#8a2a1e"], "smoked_meat": ["line", "#6a2a1a"], "raw_hide": ["slab", "#a8805a"],
	"leather": ["slab", "#7a5236"], "sinew": ["bundle", "#d8cfa8"], "bone_antler": ["pile", "#d8cfa8"],
	"teeth": ["pile", "#ece4c8"], "raw_fish": ["pile", "#a8c0d8"], "dried_fish": ["line", "#b8a878"],
	"cordage": ["bundle", "#b8a878"], "baskets": ["row", "#9a8a5a"], "roots_greens": ["pile", "#5a7a2e"],
	"fibre": ["bundle", "#a8a05a"], "fresh_herbs": ["line", "#4f8a3a"], "dried_herbs": ["line", "#6a7a3a"],
	"ground_herbs": ["row", "#c8a24a"], "water": ["level", "#3fa8e8"], "flint": ["pile", "#2a2c3e"],
	"clay": ["pile", "#7a4a32"], "green_pots": ["row", "#b8805a"], "fired_pots": ["row", "#9a5e3a"],
	"meal": ["level", "#8a6a3a"], "brew": ["level", "#5a8a4a"], "compost": ["pile", "#3a2a1a"],
	"ash": ["pile", "#9a9aa8"], "charcoal": ["pile", "#1a1a20"], "horn": ["pile", "#c8b890"],
	"fish_bones": ["pile", "#e8e0d0"], "seed_stock": ["pile", "#b89a5a"], "fresh_food": ["pile", "#c86a3a"],
	"hearth_wood": ["stack", "#5a3e24"],
}


func _stock_spot(g: String) -> String:
	var show := str((sim.meta.get(g, {}) as Dictionary).get("show", ""))
	var o := sim.owner(g)
	if o == "shaman" or show in ["hearth", "cauldron"]:
		return "hearth"
	return "%s.%s" % [o, show]


func _build_stock() -> void:
	var used := {}
	for g in sim.meta:
		var sp := _stock_spot(str(g))
		if not sim.spots.has(sp) or str(g) in ["meal", "brew"]:
			continue
		var slot := int(used.get(sp, 0))
		used[sp] = slot + 1
		var base: Vector3 = sim.spots[sp]
		if sp == "hearth":
			# Round the fire, past the stones.
			var a := 0.9 + slot * 0.7
			base += Vector3(cos(a), 0.0, sin(a)) * 1.9
		var n := Node3D.new()
		n.name = "Stock_" + str(g)
		n.set_meta("good", str(g))
		n.position = base + Vector3(0.5 * slot, 0.0, 0.0) * (0.0 if sp == "hearth" else 1.0)
		add_child(n)
		var lk: Array = LOOK.get(str(g), ["pile", "#8a8a8a"])
		var cap := sim.cap(str(g))
		var pieces := clampi(int(cap), 1, 10)
		var units: Array = []
		for i in pieces:
			units.append(_unit(n, str(lk[0]), str(lk[1]), i, pieces))
		_stock[g] = {"node": n, "units": units, "shown": -1}


func _unit(n: Node3D, shape: String, col: String, i: int, of: int) -> MeshInstance3D:
	var y := hub.land.height_at(n.position.x, n.position.z) - n.position.y
	match shape:
		"stack":
			var row := 0
			var left := i
			var w := 4
			while left >= w and w > 1:
				left -= w
				row += 1
				w -= 1
			var z := -0.5 + left * 0.3 + row * 0.15
			return hub._rod(n, Vector3(-0.7, y + 0.15 + row * 0.27, z), Vector3(0.7, y + 0.15 + row * 0.27, z), 0.13, 0.13, col, 0.7)
		"line":
			var mi := _ball(n, Vector3(0, y + 1.45, -0.6 + i * (1.2 / maxf(of - 1, 1))), 0.07, col)
			return mi
		"row":
			return hub._cyl(n, 0.13, 0.1, 0.3, Transform3D(Basis.IDENTITY, Vector3(-0.6 + (i % 5) * 0.3, y + 0.15, (i / 5) * 0.3)), col, 0.4)
		"bundle":
			return hub._rod(n, Vector3(-0.25, y + 0.08 + (i / 4) * 0.12, -0.3 + (i % 4) * 0.18), Vector3(0.25, y + 0.08 + (i / 4) * 0.12, -0.3 + (i % 4) * 0.18), 0.05, 0.05, col, 0.8)
		"slab":
			return hub._block(n, Vector3(0.45, 0.6, 0.03), Transform3D(Basis(Vector3.UP, 0.08 * i), Vector3(-0.6 + (i % 4) * 0.4, y + 1.0, 0.05 * (i / 4))), col, 0.7, false)
		"level":
			var b := BoxMesh.new()
			b.size = Vector3(0.18, 0.04, 0.18)
			var mi2 := MeshInstance3D.new()
			mi2.mesh = b
			mi2.material_override = hub._mat(col, 0.2)
			mi2.position = Vector3(0, y + 0.05 + i * 0.045, 0)
			n.add_child(mi2)
			return mi2
	# pile
	var a := float(i) * 2.4
	var r := 0.08 + 0.05 * sqrt(float(i))
	return hub._block(n, Vector3(0.12, 0.08, 0.1), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r * 2.0, y + 0.04 + (i / 6) * 0.07, sin(a) * r * 2.0)), col, 0.5, false)


func _ball(n: Node3D, at: Vector3, r: float, col: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 4.0
	sp.radial_segments = 6
	sp.rings = 3
	mi.mesh = sp
	mi.material_override = hub._mat(col, 0.4)
	mi.position = at
	n.add_child(mi)
	return mi


## The tools that wear (uses > 0), each a prop at its spot; the dugout and
## the fish trap are the camp's own props.
func _build_tools() -> void:
	var used := {}
	for id in sim.tools:
		var T: Dictionary = HubWork._tools().get(id, {})
		if int(T.get("uses", 0)) <= 0 and not (str(id) in ["dugout"]):
			continue
		if str(T.get("spot", "")) == "in_hand":
			continue
		var sp := HubWork.tool_spot(str(id))
		var named := {"dugout": "Dugout", "fish_trap": "FishTrap"}
		if named.has(id):
			var site := hub.get_node_or_null("Site_fisher_weaver")
			var own := site.find_child(str(named[id]), true, false) if site != null else null
			if own != null:
				_tool[id] = {"node": own, "shown": ""}
				continue
		if not sim.spots.has(sp):
			continue
		var slot := int(used.get(sp, 0))
		used[sp] = slot + 1
		var n := Node3D.new()
		n.name = "Tool_" + str(id)
		n.position = (sim.spots[sp] as Vector3) + Vector3(-0.35 + 0.25 * slot, 0.0, 0.45)
		add_child(n)
		var head := "#2a2c3e" if str(id) in ["spear", "stone_axe", "skinning_knife", "hide_scraper", "flint_blade", "fishing_spear"] else "#6b4a2e"
		hub._rod(n, Vector3(0, 0, 0), Vector3(0.1, 1.05, 0.05), 0.025, 0.02, "#6b4a2e", 0.6)
		hub._block(n, Vector3(0.06, 0.14, 0.1), Transform3D(Basis.IDENTITY, Vector3(0.1, 1.08, 0.05)), head, 0.2, false)
		_tool[id] = {"node": n, "shown": ""}


func _item_look(it: Dictionary) -> Array:
	var sh := str(it.get("shown", "raw"))
	match sh:
		"fish_gutted":
			return ["fish", "#c8d8e8"]
		"fish_split":
			return ["flat", "#b8a878"]
		"water_settling":
			return ["jar", "#5a8ab8"]
		"water_boiling":
			return ["jar", "#9ac8e8"]
		"forage_sorted":
			return ["heap", "#4f8a3a"]
		"herbs_drying":
			return ["flat", "#6a7a3a"]
		"wood_split":
			return ["logs", "#7a5a34"]
		"wood_drying":
			return ["logs", "#5a3e24"]
		"carcass":
			return ["hide", "#8a6a48"]
		"hide_scraped":
			return ["hide", "#c8a07a"]
		"hide_soaking":
			return ["hide", "#6a5a48"]
		"hide_stretched":
			return ["hide", "#b8906a"]
		"hide_smoking":
			return ["hide", "#8a6040"]
		"hide_soft":
			return ["hide", "#a07a54"]
	match str(it.get("chain", "")):
		"fish":
			return ["fish", "#a8c0d8"]
		"water":
			return ["jar", "#3fa8e8"]
		"plants":
			return ["heap", "#5a7a2e"]
		"wood":
			return ["logs", "#6b4a2e"]
		"hunt":
			return ["carcass", "#6b4a2e"]
	return ["heap", "#8a8a8a"]


func _item_node(it: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Item_%d" % int(it.id)
	add_child(n)
	_dress_item(n, it)
	return n


func _dress_item(n: Node3D, it: Dictionary) -> void:
	for c in n.get_children():
		c.free()
	var lk := _item_look(it)
	n.set_meta("show", str(it.get("shown", "raw")))
	var col := str(lk[1])
	match str(lk[0]):
		"fish":
			_ball(n, Vector3(0, 0.3, 0), 0.07, col)
		"flat":
			hub._block(n, Vector3(0.5, 0.03, 0.3), Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)), col, 0.6, false)
		"jar":
			hub._cyl(n, 0.16, 0.13, 0.36, Transform3D(Basis.IDENTITY, Vector3(0, 0.18, 0)), "#8a5a3a", 0.4)
			hub._cyl(n, 0.13, 0.13, 0.02, Transform3D(Basis.IDENTITY, Vector3(0, 0.36, 0)), col, 0.1)
		"heap":
			hub._cyl(n, 0.25, 0.3, 0.2, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), "#9a8a5a", 0.8)
			_ball(n, Vector3(0, 0.25, 0), 0.12, col)
		"logs":
			for i in 3:
				hub._rod(n, Vector3(-0.5, 0.12 + (i / 2) * 0.2, -0.15 + (i % 2) * 0.25), Vector3(0.5, 0.12 + (i / 2) * 0.2, -0.15 + (i % 2) * 0.25), 0.1, 0.1, col, 0.7)
		"hide":
			hub._block(n, Vector3(0.9, 0.9, 0.03), Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 1.0, 0)), col, 0.75, false) if str(it.get("shown", "")) != "hide_soaking" else hub._block(n, Vector3(0.8, 0.04, 0.6), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), col, 0.75, false)
		"carcass":
			hub._block(n, Vector3(0.9, 0.35, 0.4), Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), col, 0.7, false)
	n.set_meta("look", str(lk[0]))


## Everything brought up to the camp's state now.
func refresh() -> void:
	for g in _stock:
		var e: Dictionary = _stock[g]
		var units: Array = e.units
		var c := sim.count(str(g))
		var on := 0 if c <= 0.0 else clampi(int(ceil(c / maxf(sim.cap(str(g)), 1.0) * units.size())), 1, units.size())
		if on != int(e.shown):
			e.shown = on
			for i in units.size():
				(units[i] as Node3D).visible = i < on
	for id in _tool:
		var e2: Dictionary = _tool[id]
		var tl: Dictionary = sim.tools.get(id, {})
		var state := "held" if str(tl.get("by", "")) != "" else ("broken" if bool(tl.get("broken", false)) else "whole")
		if state != str(e2.shown):
			e2.shown = state
			var n: Node3D = e2.node
			n.visible = state != "held"
			n.set_meta("state", state)
			if n.name.begins_with("Tool_"):
				n.rotation = Vector3(0.0, 0.0, 1.45) if state == "broken" else Vector3.ZERO
	# Chain items at their stations (stacked where several wait).
	var live := {}
	var at_spot := {}
	for it in sim.items:
		var id := int(it.id)
		live[id] = true
		var n: Node3D = _items.get(id, null)
		if n == null:
			n = _item_node(it)
			_items[id] = n
		if str(n.get_meta("show", "")) != str(it.get("shown", "raw")):
			_dress_item(n, it)
		var sp := str(it.at)
		var slot := int(at_spot.get(sp, 0))
		at_spot[sp] = slot + 1
		var p: Vector3 = sim.spots.get(sp, hub.camp.pos)
		n.position = p + Vector3(0.35 * (slot % 3), 0.0, 0.35 * (slot / 3))
		n.set_meta("at", sp)
		n.visible = str(it.get("held", "")) == ""
	for id in _items.keys():
		if not live.has(id):
			(_items[id] as Node3D).queue_free()
			_items.erase(id)
	for u in sim.upgrades:
		if not _ups.has(u):
			_ups[u] = _upgrade(str(u))
	# The kiln smokes hard while pots fire; the smoke pit while meat smokes.
	var kiln := hub.get_node_or_null("Site_knapper_potter/KilnSmoke") as CPUParticles3D
	var firing := sim.batches.any(func(b): return str(b.act) == "fire_pots")
	if kiln != null:
		kiln.amount = 140 if firing else 60
	var smoking := sim.batches.any(func(b): return str(b.act) == "smoke_meat") or sim.items.any(func(it): return str(it.get("shown", "")) == "hide_smoking")
	if not _smoke.has("pit") and sim.spots.has("hunter_tanner.smoke_pit"):
		var w := hub._wisp(Color(0.55, 0.55, 0.62, 0.3), 0.35, 50)
		w.position = (sim.spots["hunter_tanner.smoke_pit"] as Vector3) + Vector3(0, 0.6, 0)
		add_child(w)
		_smoke["pit"] = w
	if _smoke.has("pit"):
		(_smoke.pit as CPUParticles3D).emitting = smoking


## An upgrade's prop (§GO.1.4).
func _upgrade(key: String) -> Node3D:
	var id := key.get_slice("@", 0)
	var who := key.get_slice("@", 1) if key.contains("@") else ""
	var n := Node3D.new()
	n.name = "Upgrade_" + key.replace("@", "_")
	n.set_meta("upgrade", key)
	match id:
		"hide_cover", "bedding":
			var site := hub.get_node_or_null("Site_" + who) as Node3D
			var l: Array = ((sim.D.get("spots", {}) as Dictionary).get(who, {}) as Dictionary).get("shelter", [0, 4])
			if site == null:
				return n
			site.add_child(n)
			var at := hub._on(site, Vector3(float(l[0]), 0.0, float(l[1])))
			if id == "hide_cover":
				hub._block(n, Vector3(3.3, 0.04, 2.5), Transform3D(Basis(Vector3.RIGHT, -0.66), at + Vector3(0, 1.08, 0.1)), "#8a6040", 0.7, false)
			else:
				hub._block(n, Vector3(1.4, 0.06, 0.8), Transform3D(Basis.IDENTITY, at + Vector3(0, 0.04, 0.4)), "#6a5040", 0.9, false)
			return n
		"waterskin":
			add_child(n)
			n.position = sim.spots.get("forager_herbalist.gourd_line", hub.camp.pos)
			_ball(n, Vector3(0, 1.4, 0), 0.12, "#7a5236")
		"horn_cups":
			add_child(n)
			n.position = (hub.camp.pos as Vector3) + Vector3(1.6, 0.0, -1.0)
			for i in 3:
				hub._cyl(n, 0.05, 0.02, 0.14, Transform3D(Basis.IDENTITY, Vector3(i * 0.15, 0.07, 0)), "#c8b890", 0.3)
		"painted_posts":
			add_child(n)
			for head in hub.find_children("TorchHead", "", true, false):
				var h := head as Node3D
				var b := hub._block(n, Vector3(0.1, 0.12, 0.1), Transform3D(Basis.IDENTITY, Vector3.ZERO), "#a8241a", 0.6, false)
				b.global_position = h.global_position - Vector3(0, 0.45, 0)
				var b2 := hub._block(n, Vector3(0.1, 0.08, 0.1), Transform3D(Basis.IDENTITY, Vector3.ZERO), "#1a1a20", 0.6, false)
				b2.global_position = h.global_position - Vector3(0, 0.62, 0)
		_:
			add_child(n)
	return n
