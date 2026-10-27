class_name TorchSupply
extends Node
## Where torches come from, and why there are few (Mike, 27 Oct: "torches
## shouldn't be too abundant, to create a sense of scarcity and encourage
## the player to either prepare during the day or venture out at night to
## find them"; torch.json crawler_burn.supply). Fire is carried, never made
## (§ET); unlit torches are made by the folk and found:
##   the firekeeper's stack  at the woodcutter-firekeeper's site at the hub
##                (§FZ): he binds per_day torches each day, the stack
##                holding at most max; a new game finds start in it. Take
##                them by day, before night falls, and you are ready.
##   the realms' caches     a few old torches left in each realm (caches.count
##                places a realm, seeded), torches each; one emptied fills
##                again restock_days later. Found by walking the realm, by
##                day or, when you've run short, by night.
##   the ruin's bundle      by its hearth, laid once in a game and never again
##                (ruin_bundle_kept; CrawlerMain.take_torch keeps its count).
##   the brand    the song gives one only when you hold no torch, and it is
##                short (brand_burn_min): enough to light the realm's hearth,
##                not to walk the night (CrawlerAreas._brand).
## What is in the stacks and caches lives in the game's save
## (CrawlerSave.data.torch_supply). The interact button by a stack or a
## cache takes one torch (carry_max still holds, the rustle when full).

static var S: Dictionary = (Tuning.table("torch").get("crawler_burn", {}) as Dictionary).get("supply", {})

var main: CrawlerMain
## [{"node", "where": "hub" | realm, "i" (cache index, -1 the hub's)}]
var _stacks: Array = []


func setup(p_main: CrawlerMain) -> void:
	main = p_main
	name = "TorchSupply"


static func on() -> bool:
	return bool(S.get("on", true))


static func store() -> Dictionary:
	var t: Variant = CrawlerSave.data.get("torch_supply", null)
	if not t is Dictionary:
		var H: Dictionary = S.get("hub", {})
		t = {"hub": {"left": int(H.get("start", 2)), "day": -1}, "caches": {}}
		CrawlerSave.data["torch_supply"] = t
	return t


## The firekeeper's stack: {"left", "day" (the last day he bound torches)}.
static func hub_stack() -> Dictionary:
	return store().hub


## Realm `realm`'s caches: [{"left", "emptied" (the day, -1 if not)}].
static func caches(realm: String) -> Array:
	var all: Dictionary = store().caches
	if not all.has(realm):
		var C: Dictionary = S.get("caches", {})
		var tr: Array = C.get("torches", [1, 2])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([CrawlerSave.game_seed, realm, "torch caches"])
		var list := []
		for i in int(C.get("count", 4)):
			list.append({"left": rng.randi_range(int(tr[0]), int(tr[1])), "emptied": -1.0})
		all[realm] = list
	return all[realm]


## The day now on the one clock (§FK.3).
func _days() -> float:
	return float(main.world.get("days")) if main != null and main.world != null else 0.0


## The firekeeper binds torches each day (day: floor of the clock): per_day
## more for every day gone since he last did, up to max. A stack the game has
## not yet seen a day of (day -1) starts now.
static func bind_days(st: Dictionary, days: float) -> void:
	var H: Dictionary = S.get("hub", {})
	var today := floorf(days)
	if float(st.day) < 0.0:
		st["day"] = today
		return
	var gone := int(today - float(st.day))
	if gone < 0:
		# The clock set back (a new game is set to its first dusk once built).
		st["day"] = today
		return
	if gone == 0:
		return
	st["left"] = mini(int(st.left) + gone * int(H.get("per_day", 2)), maxi(int(H.get("max", 3)), int(st.left)))
	st["day"] = today


## An emptied cache fills again restock_days after (to its first count).
static func restock(list: Array, realm: String, days: float) -> void:
	var C: Dictionary = S.get("caches", {})
	var tr: Array = C.get("torches", [1, 2])
	for i in list.size():
		var c: Dictionary = list[i]
		if int(c.left) <= 0 and float(c.emptied) >= 0.0 and days - float(c.emptied) >= float(C.get("restock_days", 2.0)):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([CrawlerSave.game_seed, realm, i, int(days)])
			c["left"] = rng.randi_range(int(tr[0]), int(tr[1]))
			c["emptied"] = -1.0


## Where realm `area`'s caches lie (seeded; on its floor, away from its
## hearth and its ruin's mouth).
static func cache_spots(area: Surface, realm: String, n: int) -> Array:
	var C: Dictionary = S.get("caches", {})
	var land := area.land
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([area.seed_value, realm, "torch cache spots"])
	var hp := area.area_hearth.global_position if area.area_hearth != null else Vector3(land.center.x, 0.0, land.center.y)
	var h2 := Vector2(hp.x, hp.z)
	var mouth: Vector2 = area.stair.get("mouth", Vector2.INF) if area.stair is Dictionary else Vector2.INF
	var apart := float(C.get("apart_m", 30.0))
	var out: Array = []
	for attempt in 600:
		if out.size() >= n:
			break
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * land.r_in
		var p := land.center + Vector2(cos(a), sin(a)) * r
		if not land.inside(p, 12.0) or land.slope_at(p.x, p.y) > 0.3 or land.in_wash(p) > 0.05:
			continue
		if p.distance_to(h2) < float(C.get("from_hearth_m", 35.0)) or (mouth != Vector2.INF and p.distance_to(mouth) < 10.0):
			continue
		var ok := true
		for q: Vector3 in out:
			if p.distance_to(Vector2(q.x, q.z)) < apart * (0.5 if attempt > 300 else 1.0):
				ok = false
				break
		if ok:
			out.append(Vector3(p.x, land.height_at(p.x, p.y), p.y))
	return out


func _process(_delta: float) -> void:
	if not on() or main == null:
		return
	var days := _days()
	bind_days(hub_stack(), days)
	_ensure_hub()
	_ensure_area()
	for s in _stacks:
		if s.node != null and is_instance_valid(s.node):
			_show(s)


func _has(where: String) -> bool:
	_stacks = _stacks.filter(func(s): return s.node != null and is_instance_valid(s.node))
	return _stacks.any(func(s): return str(s.where) == where)


## The firekeeper's stack, laid at his site once the hub is built.
func _ensure_hub() -> void:
	var hub := main.hub_node as HubCamp
	if hub == null or not is_instance_valid(hub) or not hub.is_inside_tree() or _has("hub"):
		return
	var at: Vector3 = hub.camp.pos + Vector3(2.0, 0.0, 2.0)
	var yaw := 0.0
	for site in hub.sites:
		if str(site.get("keeper", "")) == str((S.get("hub", {}) as Dictionary).get("keeper", "woodcutter_firekeeper")):
			yaw = float(site.get("yaw", 0.0))
			var off := Vector3(-1.2, 0.0, 0.6).rotated(Vector3.UP, yaw)
			at = (site.at as Vector3) + off
			at.y = hub.land.height_at(at.x, at.z)
	_stacks.append({"node": _stack_node(hub, at, yaw), "where": "hub", "i": -1, "realm": ""})


## A realm's caches, laid once its surface is built.
func _ensure_area() -> void:
	var area := main.area_node
	# (Not while it is only the glimpse in the fire, CrawlerAreas.)
	if area == null or not is_instance_valid(area) or area.land == null or not area.is_inside_tree() or area != main.surface:
		return
	var realm := "first"
	if _has(realm):
		return
	var list := caches(realm)
	var spots := cache_spots(area, realm, list.size())
	for i in spots.size():
		var node := _stack_node(area, spots[i], hash([realm, i]) % 628 / 100.0)
		# An old cache: a ring of stones round it, so it reads as left there.
		var C: Dictionary = S.get("caches", {})
		for k in 6:
			var st := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.14
			st.mesh = sm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(str(C.get("stone_colour", "#4a4858")))
			m.roughness = 0.9
			st.material_override = m
			st.position = Vector3(cos(k * TAU / 6.0) * 0.55, 0.04, sin(k * TAU / 6.0) * 0.55)
			node.add_child(st)
		_stacks.append({"node": node, "where": realm, "i": i, "realm": realm})


func _stack_node(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.name = "TorchStack"
	parent.add_child(n)
	n.global_position = at
	n.rotation.y = yaw
	n.set_meta("shown", -1)
	return n


## How many torches stack `s` holds now.
func left_of(s: Dictionary) -> int:
	if str(s.where) == "hub":
		return int(hub_stack().left)
	var list := caches(str(s.realm))
	restock(list, str(s.realm), _days())
	return int(list[int(s.i)].left)


## Its sticks, as many as it holds.
func _show(s: Dictionary) -> void:
	var n := left_of(s)
	var node: Node3D = s.node
	if int(node.get_meta("shown")) == n:
		return
	node.set_meta("shown", n)
	for c in node.get_children():
		if str(c.name).begins_with("Stick") or str(c.name).begins_with("Tip") or str(c.name) == "Cord" or str(c.name) == "Sticks":
			c.queue_free()
	var holder := Node3D.new()
	holder.name = "Sticks"
	node.add_child(holder)
	CrawlerFires.lay_sticks(holder, n, hash(node.position))


## The nearest stack in reach with a torch in it, or {}.
func in_reach() -> Dictionary:
	var p := main.player.global_position
	var reach := float(S.get("reach_m", 2.0))
	var best := {}
	var bd := INF
	for s in _stacks:
		var node: Node3D = s.node
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var d := node.global_position.distance_to(p)
		if d <= reach and d < bd and left_of(s) > 0:
			best = s
			bd = d
	return best


## The interact button by a stack: one torch, unlit, into your hand (or
## pack). True if it was taken (or refused for a full carry).
func take() -> bool:
	if not on():
		return false
	var s := in_reach()
	if s.is_empty():
		return false
	var pl := main.player
	if pl.torch.at_carry_max():
		GameLog.add(str(S.get("log_full", "Your hands are full of torches.")), "torch")
		return true
	if not pl.inventory.add(Inventory.make("torch")):
		return false
	if str(s.where) == "hub":
		hub_stack()["left"] = int(hub_stack().left) - 1
	else:
		var c: Dictionary = caches(str(s.realm))[int(s.i)]
		c["left"] = int(c.left) - 1
		if int(c.left) <= 0:
			c["emptied"] = _days()
	if pl.weapon != "torch":
		pl.weapon = "torch"
		pl.torch.block_until_release()
	GameLog.add(str(S.get("log_hub" if str(s.where) == "hub" else "log_cache", "You take a torch.")), "torch")
	CrawlerSave.save()
	return true
