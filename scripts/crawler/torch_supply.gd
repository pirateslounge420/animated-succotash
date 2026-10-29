class_name TorchSupply
extends Node
## Where torches come from, and why there are few (Mike, 27 Oct: "torches
## shouldn't be too abundant, to create a sense of scarcity and encourage
## the player to either prepare during the day or venture out at night to
## find them"; 28 Oct: "it can start with torches but it should not just
## resupply itself; you should have to make it or find them"; torch.json
## crawler_burn.supply). Fire is carried, never made (§ET); an unlit torch
## is found or bound by hand, and nothing fills again by itself:
##   the firekeeper's stack  at the woodcutter-firekeeper's site at the hub
##                (§FZ): a new game finds hub.start torches in it, and that
##                is all. It is also where you bind torches (make): a branch
##                and a lump of resin for each, from your pack.
##   the realms' finds      seeded on each realm's floor: caches (old torches
##                left in a ring of stones), deadfall branches and resin on
##                old stumps. Taken once each, never laid again
##                (finds.<kind>.regrow_days 0); walk the realm by day, or go
##                out in the dark when you've run short.
##   the ruin's bundle      by its hearth, laid once in a game and never again
##                (ruin_bundle_kept; CrawlerMain.take_torch keeps its count).
##   the song     lights a torch you carry (brand_without_torch false: with no
##                torch of your own you go through with none).
## What is left in each lives in the game's save
## (CrawlerSave.data.torch_supply). The interact button by one takes from
## it (carry_max still holds), and at the firekeeper's site binds a torch.

static var S: Dictionary = (Tuning.table("torch").get("crawler_burn", {}) as Dictionary).get("supply", {})

## The kinds of find a realm has, in finds' order.
const KINDS := ["cache", "branch", "resin"]

var main: CrawlerMain
## [{"node", "where": "hub" | realm, "kind" ("hub" or KINDS), "i"}]
var _stacks: Array = []


func setup(p_main: CrawlerMain) -> void:
	main = p_main
	name = "TorchSupply"


static func on() -> bool:
	return bool(S.get("on", true))


static func store() -> Dictionary:
	var t: Variant = CrawlerSave.data.get("torch_supply", null)
	if not t is Dictionary:
		t = {}
		CrawlerSave.data["torch_supply"] = t
	if not (t as Dictionary).has("hub"):
		t["hub"] = {"left": int((S.get("hub", {}) as Dictionary).get("start", 3))}
	if not (t as Dictionary).has("realms"):
		t["realms"] = {}
	return t


## The firekeeper's stack: {"left"}.
static func hub_stack() -> Dictionary:
	return store().hub


## Find `kind` (KINDS) in data: finds.<kind>.
static func find_data(kind: String) -> Dictionary:
	return (S.get("finds", {}) as Dictionary).get(kind, {})


## Realm `realm`'s finds of `kind`: [{"left", "emptied" (the day, -1 if not)}].
static func finds(realm: String, kind: String) -> Array:
	var all: Dictionary = store().realms
	if not all.has(realm):
		all[realm] = {}
	var r: Dictionary = all[realm]
	if not r.has(kind):
		var F := find_data(kind)
		var each: Array = F.get("each", [1, 1])
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([CrawlerSave.game_seed, realm, kind, "finds"])
		var list := []
		for i in int(F.get("count", 4)):
			list.append({"left": rng.randi_range(int(each[0]), int(each[1])), "emptied": -1.0})
		r[kind] = list
	return r[kind]


## The day now on the one clock (§FK.3).
func _days() -> float:
	return float(main.world.get("days")) if main != null and main.world != null else 0.0


## An emptied find comes back regrow_days later, only where the data says
## (0, the build: never; Mike, 28 Oct: nothing resupplies itself).
static func regrow(list: Array, realm: String, kind: String, days: float) -> void:
	var F := find_data(kind)
	var wait := float(F.get("regrow_days", 0.0))
	if wait <= 0.0:
		return
	var each: Array = F.get("each", [1, 1])
	for i in list.size():
		var c: Dictionary = list[i]
		if int(c.left) <= 0 and float(c.emptied) >= 0.0 and days - float(c.emptied) >= wait:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([CrawlerSave.game_seed, realm, kind, i, int(days)])
			c["left"] = rng.randi_range(int(each[0]), int(each[1]))
			c["emptied"] = -1.0


## Where realm `area`'s finds of `kind` lie (seeded; on its floor, away
## from its hearth and its ruin's mouth, apart from each other and from
## `taken`, the spots already placed).
static func spots(area: Surface, realm: String, kind: String, n: int, taken: Array = []) -> Array:
	var F := find_data(kind)
	var land := area.land
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([area.seed_value, realm, kind, "find spots"])
	var hp := area.area_hearth.position if area.area_hearth != null else Vector3(land.center.x, 0.0, land.center.y)
	var h2 := Vector2(hp.x, hp.z)
	var mouth: Vector2 = area.stair.get("mouth", Vector2.INF) if area.stair is Dictionary else Vector2.INF
	var apart := float(F.get("apart_m", 20.0))
	var out: Array = []
	for attempt in 800:
		if out.size() >= n:
			break
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * land.r_in
		var p := land.center + Vector2(cos(a), sin(a)) * r
		if not land.inside(p, 12.0) or land.slope_at(p.x, p.y) > 0.3 or land.in_wash(p) > 0.05:
			continue
		if p.distance_to(h2) < float(F.get("from_hearth_m", 20.0)) or (mouth != Vector2.INF and p.distance_to(mouth) < 10.0):
			continue
		var ok := true
		for q: Vector3 in out + taken:
			if p.distance_to(Vector2(q.x, q.z)) < apart * (0.5 if attempt > 400 else 1.0):
				ok = false
				break
		if ok:
			out.append(Vector3(p.x, land.height_at(p.x, p.y), p.y))
	return out


func _process(_delta: float) -> void:
	if not on() or main == null:
		return
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
	_stacks.append({"node": _node(hub, at, yaw), "where": "hub", "kind": "hub", "i": -1})


## A realm's finds, laid once its surface is built.
func _ensure_area() -> void:
	var area := main.area_node
	# (Not while it is only the glimpse in the fire, CrawlerAreas.)
	if area == null or not is_instance_valid(area) or area.land == null or not area.is_inside_tree() or area != main.surface:
		return
	var realm := "first"
	if _has(realm):
		return
	var placed: Array = []
	for kind in KINDS:
		var list := finds(realm, kind)
		var at := spots(area, realm, kind, list.size(), placed)
		placed.append_array(at)
		for i in at.size():
			var node := _node(area, at[i], float(hash([realm, kind, i]) % 628) / 100.0)
			_dress(node, kind)
			_stacks.append({"node": node, "where": realm, "kind": kind, "i": i})


func _node(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.name = "TorchFind"
	parent.add_child(n)
	n.position = parent.to_local(at) if parent.is_inside_tree() else at
	n.rotation.y = yaw
	n.set_meta("shown", -1)
	return n


func _mat(c: String, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = rough
	return m


## What stays when it is empty: a cache's ring of stones, a resin stump.
func _dress(node: Node3D, kind: String) -> void:
	var F := find_data(kind)
	match kind:
		"cache":
			for k in 6:
				var st := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.12
				sm.height = 0.14
				st.mesh = sm
				st.material_override = _mat(str(F.get("colour", "#4a4858")), 0.9)
				st.position = Vector3(cos(k * TAU / 6.0) * 0.55, 0.04, sin(k * TAU / 6.0) * 0.55)
				node.add_child(st)
		"resin":
			# An old pine stump, split and weeping.
			var stump := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.24
			cm.bottom_radius = 0.32
			cm.height = 0.55
			cm.radial_segments = 7
			stump.mesh = cm
			stump.material_override = _mat(str(F.get("wood_colour", "#4a3020")), 0.8)
			stump.position = Vector3(0.0, 0.27, 0.0)
			node.add_child(stump)


## Its torches, branch or resin, as many as it holds.
func _show(s: Dictionary) -> void:
	var n := left_of(s)
	var node: Node3D = s.node
	if int(node.get_meta("shown")) == n:
		return
	node.set_meta("shown", n)
	var old := node.get_node_or_null("Held")
	if old != null:
		node.remove_child(old)
		old.queue_free()
	var holder := Node3D.new()
	holder.name = "Held"
	node.add_child(holder)
	match str(s.kind):
		"hub", "cache":
			CrawlerFires.lay_sticks(holder, n, hash(node.position))
		"branch":
			# Deadfall: a crooked branch lying on the ground, a twig off it.
			if n > 0:
				var F := find_data("branch")
				var b := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.025
				cm.bottom_radius = 0.04
				cm.height = 1.1
				cm.radial_segments = 5
				b.mesh = cm
				b.material_override = _mat(str(F.get("colour", "#5a3e24")))
				b.rotation = Vector3(PI * 0.5, 0.0, 0.08)
				b.position = Vector3(0.0, 0.05, 0.0)
				holder.add_child(b)
				var tw := MeshInstance3D.new()
				var tm := CylinderMesh.new()
				tm.top_radius = 0.01
				tm.bottom_radius = 0.018
				tm.height = 0.4
				tm.radial_segments = 4
				tw.mesh = tm
				tw.material_override = b.material_override
				tw.rotation = Vector3(PI * 0.5, 0.9, 0.0)
				tw.position = Vector3(0.12, 0.05, 0.2)
				holder.add_child(tw)
		"resin":
			# Amber beads down the stump's split side (no glow: resin gives no light).
			var F := find_data("resin")
			for k in n * 3:
				var r := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.035 + 0.01 * (k % 2)
				sm.height = sm.radius * 2.4
				r.mesh = sm
				r.material_override = _mat(str(F.get("colour", "#d8902a")), 0.15)
				r.position = Vector3(0.24 * cos(k * 0.5), 0.15 + 0.12 * k, 0.24 * sin(k * 0.5))
				holder.add_child(r)


## How much `s` holds now.
func left_of(s: Dictionary) -> int:
	if str(s.kind) == "hub":
		return int(hub_stack().left)
	var list := finds(str(s.where), str(s.kind))
	regrow(list, str(s.where), str(s.kind), _days())
	return int(list[int(s.i)].left)


## The nearest of `stacks` in reach of you (that `want` passes), or {}.
func in_reach(want := func(_s): return true) -> Dictionary:
	var p := main.player.global_position
	var reach := float(S.get("reach_m", 2.0))
	var best := {}
	var bd := INF
	for s in _stacks:
		var node: Node3D = s.node
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var d := node.global_position.distance_to(p)
		if d <= reach and d < bd and want.call(s):
			best = s
			bd = d
	return best


## The materials a torch is bound from (make.needs: {kind: n}).
static func needs() -> Dictionary:
	return (S.get("make", {}) as Dictionary).get("needs", {"branch": 1, "resin": 1})


## How many things of `kind` you carry.
static func carried_of(inv: Inventory, kind: String) -> int:
	var n := 0
	for it in inv.carried:
		if it is Dictionary and str(it.get("kind", "")) == kind:
			n += maxi(int(it.get("count", 1)), 1)
	return n


## Can you bind a torch from what you carry?
static func can_make(inv: Inventory) -> bool:
	var nd := needs()
	for k in nd:
		if carried_of(inv, str(k)) < int(nd[k]):
			return false
	return true


## Bind one torch from your pack's materials (they are used up). True if made.
static func make(inv: Inventory) -> bool:
	if not can_make(inv):
		return false
	var nd := needs()
	for k in nd:
		for n in int(nd[k]):
			inv.take(inv.slot_of(str(k)))
	return inv.add(Inventory.make("torch"))


func _in_hand(pl: CrawlerPlayer) -> void:
	if pl.weapon != "torch":
		pl.weapon = "torch"
		pl.torch.block_until_release()


## The interact button by a find or the firekeeper's stack. True if it took
## the press (a thing taken or made, or a full carry told).
func take() -> bool:
	if not on():
		return false
	var pl := main.player
	var s := in_reach(func(x): return left_of(x) > 0)
	if s.is_empty():
		# At the firekeeper's site with nothing left in his stack: bind one.
		var hub := in_reach(func(x): return str(x.kind) == "hub")
		if hub.is_empty() or not can_make(pl.inventory):
			return false
		if pl.torch.at_carry_max():
			GameLog.add(str(S.get("log_full", "You can carry no more torches.")), "torch")
			return true
		if make(pl.inventory):
			_in_hand(pl)
			GameLog.add(str((S.get("make", {}) as Dictionary).get("log", "You bind a branch and resin into a torch.")), "torch")
			CrawlerSave.save()
		return true
	var kind := str(s.kind)
	var what := "torch" if kind in ["hub", "cache"] else kind
	if what == "torch" and pl.torch.at_carry_max():
		GameLog.add(str(S.get("log_full", "You can carry no more torches.")), "torch")
		return true
	if not pl.inventory.add(Inventory.make(what)):
		GameLog.add(str(S.get("log_pack_full", "Your pack is full.")), "torch")
		return true
	if kind == "hub":
		hub_stack()["left"] = int(hub_stack().left) - 1
	else:
		var c: Dictionary = finds(str(s.where), kind)[int(s.i)]
		c["left"] = int(c.left) - 1
		if int(c.left) <= 0:
			c["emptied"] = _days()
	if what == "torch":
		_in_hand(pl)
	var logs: Dictionary = S.get("logs", {})
	GameLog.add(str(logs.get(kind, "You take it.")), "torch")
	CrawlerSave.save()
	return true
