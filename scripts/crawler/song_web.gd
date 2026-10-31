class_name SongWeb
extends Node
## Plants are the keys (design §GK.2, queue 116 amended; data/song_web.json).
## A song is learned by bringing the shaman a plant: give him a cutting of
## a key and he teaches you the song of the realm it opens (§GH: knowing
## the song puts the realm in the fire). One per session (CrawlerMain
## makes it).
##
##   the platter  a woven tray on a flat stone by the hub fire with one
##                cutting of each of the platter's keys (cactus, mushroom,
##                vine); a new game finds all three there. The interact
##                button takes the one you look at; choosing one decides
##                your first realm (hub_platter.others_stay: the others
##                wait). What is left on it lives in the save
##                (CrawlerSave.data.song_web.platter).
##   the plants   in a realm, living plants of each key that grows there
##                (keys.<key>.grows_in, the realm's id: crawler.json
##                areas.<area>.realm), seeded on its floor. The interact
##                button takes a cutting; the plant stays.
##   the giving   the interact button by the shaman or the hub fire with a
##                cutting of a song you don't know: he takes it, teaches
##                the song (CrawlerSave.data.songs) and sings it
##                (CrawlerAreas.sit).

static var W: Dictionary = Tuning.table("song_web")

var main: CrawlerMain
var platter_node: Node3D
## Key -> its cutting's node on the platter.
var _on_platter := {}
## [{"node", "key"}]: the key plants on the realm's surface.
var _plants: Array = []


func setup(p_main: CrawlerMain) -> void:
	main = p_main
	name = "SongWeb"


static func key_data(key: String) -> Dictionary:
	return (W.get("keys", {}) as Dictionary).get(key, {})


static func look(key: String) -> Dictionary:
	return (W.get("look", {}) as Dictionary).get(key, {})


static func key_name(key: String) -> String:
	return str(look(key).get("name", key))


## The area (crawler.json areas.<area>) a key's song opens, or "" if none
## is there yet: the one whose realm is keys.<key>.opens.
static func area_of(key: String) -> String:
	var realm := str(key_data(key).get("opens", ""))
	if realm == "":
		return ""
	for k in CrawlerAreas.A:
		var v: Variant = CrawlerAreas.A[k]
		if v is Dictionary and str((v as Dictionary).get("realm", "")) == realm:
			return str(k)
	return ""


## The song web's id for area `area` (areas.<area>.realm).
static func realm_of(area: String) -> String:
	return str((CrawlerAreas.A.get(area, {}) as Dictionary).get("realm", area))


## The keys whose cuttings grow in realm `realm`.
static func keys_in(realm: String) -> Array:
	var out: Array = []
	var K: Dictionary = W.get("keys", {})
	for k in K:
		var g: Variant = (K[k] as Dictionary).get("grows_in", [])
		if g is Array and realm in g:
			out.append(str(k))
	return out


static func store() -> Dictionary:
	var t: Variant = CrawlerSave.data.get("song_web", null)
	if not t is Dictionary:
		t = {"platter": (W.get("platter", []) as Array).duplicate()}
		CrawlerSave.data["song_web"] = t
	return t


## The keys still on the hub's platter.
static func platter() -> Array:
	return store().platter


static func cutting(key: String) -> Dictionary:
	return Inventory.make("key_cutting", {"key": key, "title": "%s cutting" % key_name(key).capitalize()})


## Learn the song of `key`'s realm. True if it is new.
static func learn(key: String) -> bool:
	var area := area_of(key)
	if area == "":
		return false
	var k: Variant = CrawlerSave.data.get("songs", null)
	var list: Array = k if k is Array else CrawlerAreas.known().duplicate()
	if area in list:
		return false
	list.append(area)
	CrawlerSave.data["songs"] = list
	CrawlerSave.save()
	return true


static func knows(key: String) -> bool:
	return area_of(key) in CrawlerAreas.known()


func _process(_delta: float) -> void:
	if main == null:
		return
	_ensure_platter()
	_ensure_plants()


# --- The platter at the hub fire -----------------------------------------------------

func _ensure_platter() -> void:
	var hub := main.hub_node as HubCamp
	if hub == null or not is_instance_valid(hub) or not hub.is_inside_tree():
		return
	if platter_node != null and is_instance_valid(platter_node) and platter_node.get_parent() == hub:
		return
	var P: Dictionary = W.get("hub_platter", {})
	var fp: Vector3 = hub.camp.pos
	var n: Vector2 = hub.frame.n
	var side := Vector2(n.y, -n.x)
	var b := deg_to_rad(float(P.get("bearing_deg", 45.0)))
	var at2 := Vector2(fp.x, fp.z) + (side * cos(b) + n * sin(b)) * float(P.get("from_fire_m", 1.9))
	platter_node = Node3D.new()
	platter_node.name = "Platter"
	hub.add_child(platter_node)
	platter_node.position = Vector3(at2.x, hub.land.height_at(at2.x, at2.y), at2.y)
	var to := Vector2(fp.x, fp.z) - at2
	platter_node.rotation.y = atan2(-to.x, -to.y)
	# A flat stone, the woven tray on it.
	_box(platter_node, Vector3(0.9, 0.22, 0.7), Vector3(0.0, 0.09, 0.0), "#4a4d6e", 0.3)
	_cyl(platter_node, 0.4, 0.36, 0.05, Vector3(0.0, 0.225, 0.0), "#9a7a44", 0.85)
	_cyl(platter_node, 0.41, 0.41, 0.02, Vector3(0.0, 0.25, 0.0), "#6b5030", 0.8)
	_on_platter.clear()
	var keys: Array = W.get("platter", [])
	for i in keys.size():
		var key := str(keys[i])
		var a := TAU * i / maxf(keys.size(), 1.0) + PI * 0.5
		var holder := Node3D.new()
		holder.name = "Cutting_" + key
		holder.position = Vector3(cos(a) * 0.2, 0.26, sin(a) * 0.2)
		platter_node.add_child(holder)
		_plant(holder, key, 0.25)
		_on_platter[key] = holder
	_show_platter()


func _show_platter() -> void:
	var left := platter()
	for key in _on_platter:
		(_on_platter[key] as Node3D).visible = key in left


## Take the platter cutting you look at (within look_cos of your line of
## sight). True if the press was the platter's.
func _take_from_platter() -> bool:
	if platter_node == null or not is_instance_valid(platter_node) or not platter_node.is_inside_tree():
		return false
	var P: Dictionary = W.get("hub_platter", {})
	var pp := main.player.global_position
	var pc := platter_node.global_position
	if Vector2(pp.x - pc.x, pp.z - pc.z).length() > float(P.get("reach_m", 1.6)):
		return false
	var left := platter()
	if left.is_empty():
		return false
	# The one you look at: the cutting nearest your line of sight.
	var cam := main.player.camera()
	var eye := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var best := ""
	var bd := -2.0
	for key in left:
		var node: Node3D = _on_platter.get(key)
		if node == null:
			continue
		var d := fwd.dot((node.global_position - eye).normalized())
		if d > bd:
			bd = d
			best = str(key)
	# Only when you look at it (look_cos): looking at the fire, you sit.
	if best == "" or bd < float(P.get("look_cos", 0.9)):
		return false
	if not main.player.inventory.add(cutting(best)):
		GameLog.add("Your pack is full.", "world")
		return true
	if bool(P.get("others_stay", true)):
		left.erase(best)
	else:
		left.clear()
	_show_platter()
	CrawlerSave.save()
	GameLog.add(str(P.get("log_take", "You take the {name} from the platter.")).format({"name": key_name(best)}), "world")
	return true


# --- Key plants in a realm -----------------------------------------------------------

func _ensure_plants() -> void:
	var area := main.area_node
	# (Not while it is only the glimpse in the fire, CrawlerAreas.)
	if area == null or not is_instance_valid(area) or area.land == null or area != main.surface:
		return
	_plants = _plants.filter(func(p): return p.node != null and is_instance_valid(p.node))
	if not _plants.is_empty():
		return
	var C: Dictionary = W.get("cuttings", {})
	var realm := realm_of("first")
	var placed: Array = []
	for key in keys_in(realm):
		var at := spots(area, realm, key, int(C.get("plants_per_key", 2)), placed)
		placed.append_array(at)
		for i in at.size():
			var node := Node3D.new()
			node.name = "KeyPlant_" + key
			area.add_child(node)
			node.position = area.to_local(at[i])
			node.rotation.y = float(hash([realm, key, i]) % 628) / 100.0
			_plant(node, key, 1.0)
			_plants.append({"node": node, "key": key})


## Where realm `area`'s plants of `key` grow (seeded; on its floor, away
## from its hearth and its ruin's mouth, apart from each other and from
## `taken`).
static func spots(area: Surface, realm: String, key: String, n: int, taken: Array = []) -> Array:
	var C: Dictionary = W.get("cuttings", {})
	var land := area.land
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([area.seed_value, realm, key, "key plants"])
	var hp := area.area_hearth.position if area.area_hearth != null else Vector3(land.center.x, 0.0, land.center.y)
	var h2 := Vector2(hp.x, hp.z)
	var mouth: Vector2 = area.stair.get("mouth", Vector2.INF) if area.stair is Dictionary else Vector2.INF
	var apart := float(C.get("apart_m", 30.0))
	var out: Array = []
	for attempt in 800:
		if out.size() >= n:
			break
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * land.r_in
		var p := land.center + Vector2(cos(a), sin(a)) * r
		if not land.inside(p, 12.0) or land.slope_at(p.x, p.y) > 0.3 or land.in_wash(p) > 0.05:
			continue
		if p.distance_to(h2) < float(C.get("from_hearth_m", 25.0)) or (mouth != Vector2.INF and p.distance_to(mouth) < 10.0):
			continue
		var ok := true
		for q: Vector3 in out + taken:
			if p.distance_to(Vector2(q.x, q.z)) < apart * (0.5 if attempt > 400 else 1.0):
				ok = false
				break
		if ok:
			out.append(Vector3(p.x, land.height_at(p.x, p.y), p.y))
	return out


## The key plants on the realm's surface now: [{"node", "key"}].
func plants() -> Array:
	return _plants.filter(func(p): return p.node != null and is_instance_valid(p.node) and (p.node as Node3D).is_inside_tree())


func _take_cutting() -> bool:
	var C: Dictionary = W.get("cuttings", {})
	var pp := main.player.global_position
	var reach := float(C.get("reach_m", 1.8))
	for p in plants():
		var np := (p.node as Node3D).global_position
		if Vector2(pp.x - np.x, pp.z - np.z).length() > reach:
			continue
		var key := str(p.key)
		if carried_key(key) >= 0:
			GameLog.add(str(C.get("log_have", "You already carry a {name} cutting.")).format({"name": key_name(key)}), "world")
			return true
		if not main.player.inventory.add(cutting(key)):
			GameLog.add("Your pack is full.", "world")
			return true
		CrawlerSave.save()
		GameLog.add(str(C.get("log_take", "You take a cutting of the {name}.")).format({"name": key_name(key)}), "world")
		return true
	return false


## The carry slot holding a cutting of `key` ("" any key), or -1.
func carried_key(key := "") -> int:
	var inv := main.player.inventory
	for i in inv.carried.size():
		var it: Variant = inv.carried[i]
		if it is Dictionary and str(it.get("kind", "")) == "key_cutting" and (key == "" or str(it.get("key", "")) == key):
			return i
	return -1


# --- Giving the shaman a cutting -----------------------------------------------------

## Do you carry a cutting of a song you don't know yet?
func _teachable() -> bool:
	for it in main.player.inventory.carried:
		if it is Dictionary and str(it.get("kind", "")) == "key_cutting":
			var key := str(it.get("key", ""))
			if area_of(key) != "" and not knows(key):
				return true
	return false


## By the shaman or the hub fire: hand him a cutting of a song you don't
## know (he teaches it and starts singing it); with only known ones he
## hands them back; with none and no song known he asks for a plant.
## True if the press was taken.
func _give(near: bool) -> bool:
	if not near:
		return false
	var C: Dictionary = W.get("cuttings", {})
	var inv := main.player.inventory
	var known_one := ""
	for i in inv.carried.size():
		var it: Variant = inv.carried[i]
		if not (it is Dictionary and str(it.get("kind", "")) == "key_cutting"):
			continue
		var key := str(it.get("key", ""))
		if knows(key) or area_of(key) == "":
			known_one = key
			continue
		inv.take(i)
		learn(key)
		GameLog.add(str(C.get("log_teach", "He turns the {name} in his hands.")).format({"name": key_name(key)}), "world")
		main.areas.sit(area_of(key))
		return true
	if known_one != "":
		# (Then he sings what you know, CrawlerAreas.interact.)
		GameLog.add(str(C.get("log_known", "He hands the {name} back.")).format({"name": key_name(known_one)}), "world")
		return false
	if CrawlerAreas.known().is_empty():
		GameLog.add(str(C.get("log_ask", "\"Bring me a plant, and I'll teach you its song.\"")), "world")
		return true
	return false


## The interact button (CrawlerAreas.interact, after the bank): the
## platter, a key plant, or giving the shaman a cutting (`near_shaman`:
## you stand by him or the fire). True if it took the press.
func interact(near_shaman: bool) -> bool:
	if main.on_surface and main.surface is HubCamp:
		# A cutting he can teach goes to him before the platter is touched.
		if near_shaman and _teachable() and _give(true):
			return true
		if _take_from_platter():
			return true
		return _give(near_shaman)
	if main.on_surface and main.surface == main.area_node:
		return _take_cutting()
	return false


# --- The plants' shapes --------------------------------------------------------------

func _mat(c: String, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, c: String, rough := 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, rough)
	mi.position = at
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, at: Vector3, c: String, rough := 0.6, segs := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = _mat(c, rough)
	mi.position = at
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, squash: float, at: Vector3, c: String, rough := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(c, rough)
	mi.position = at
	parent.add_child(mi)
	return mi


func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, c: String) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var mi := _cyl(parent, r * 0.8, r, d.length(), (a + b) * 0.5, c, 0.7, 5)
	var up := d.normalized()
	var x := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, up, x.cross(up))


## Key `key`'s plant at scale `s` (1 a living plant in a realm, ~0.25 a
## cutting on the platter).
func _plant(parent: Node3D, key: String, s: float) -> void:
	var L := look(key)
	var body := str(L.get("body", "#4f9a3a"))
	var accent := str(L.get("accent", "#ffffff"))
	match key:
		"cactus":
			# A ribbed column with two arms and a flower on top.
			_cyl(parent, 0.13 * s, 0.15 * s, 1.3 * s, Vector3(0.0, 0.65 * s, 0.0), body, 0.4, 8)
			_ball(parent, 0.13 * s, 0.7, Vector3(0.0, 1.3 * s, 0.0), body, 0.4)
			for side in [-1.0, 1.0]:
				var base := Vector3(side * 0.13 * s, (0.55 + 0.15 * side) * s, 0.0)
				var elbow := base + Vector3(side * 0.22 * s, 0.0, 0.0)
				_rod(parent, base, elbow, 0.08 * s, body)
				_rod(parent, elbow, elbow + Vector3(0.0, 0.35 * s, 0.0), 0.08 * s, body)
			_ball(parent, 0.06 * s, 0.6, Vector3(0.0, 1.4 * s, 0.0), accent, 0.3)
		"mushroom":
			# Three pale stems, brown caps.
			for i in 3:
				var off := Vector3(cos(i * 2.1) * 0.12, 0.0, sin(i * 2.1) * 0.12) * s
				var h := (0.35 + 0.12 * i) * s
				_cyl(parent, 0.035 * s, 0.05 * s, h, off + Vector3(0.0, h * 0.5, 0.0), body, 0.6, 6)
				_ball(parent, (0.13 + 0.03 * i) * s, 0.45, off + Vector3(0.0, h, 0.0), accent, 0.5)
		"vine":
			# A woody vine coiling up, leaves along it.
			var prev := Vector3.ZERO
			for i in 12:
				var t := float(i + 1) / 12.0
				var p := Vector3(cos(t * TAU * 2.0) * 0.12, t * 1.1, sin(t * TAU * 2.0) * 0.12) * s
				_rod(parent, prev, p, 0.03 * s, body)
				if i % 2 == 1:
					_ball(parent, 0.07 * s, 0.35, p + Vector3(cos(t * 9.0), 0.0, sin(t * 9.0)) * 0.08 * s, accent, 0.5)
				prev = p
		"root":
			# A gnarled root arching out of the ground and back in.
			var pts: Array[Vector3] = []
			for i in 9:
				var t := float(i) / 8.0
				pts.append(Vector3((t - 0.5) * 1.4, sin(t * PI) * 0.7 + 0.04 * sin(t * 17.0), 0.06 * sin(t * 7.0)) * s)
			for i in 8:
				_rod(parent, pts[i], pts[i + 1], (0.09 - 0.02 * absf(i - 3.5) / 3.5) * s, body)
			for i in [2, 5]:
				_rod(parent, pts[i], pts[i] + Vector3(0.1, -0.3, 0.25) * s, 0.025 * s, accent)
		"leaf":
			# A low shrub of broad leaves on short stems.
			_cyl(parent, 0.04 * s, 0.06 * s, 0.4 * s, Vector3(0.0, 0.2 * s, 0.0), body, 0.7, 6)
			for i in 7:
				var a := i * TAU / 7.0
				var p := Vector3(cos(a) * 0.3, 0.4 + 0.12 * (i % 3), sin(a) * 0.3) * s
				_rod(parent, Vector3(0.0, 0.35 * s, 0.0), p, 0.015 * s, body)
				var lf := _ball(parent, 0.2 * s, 0.25, p, accent, 0.45)
				lf.rotation = Vector3(0.3 * cos(a), a, 0.3 * sin(a))
		_:
			_ball(parent, 0.2 * s, 0.8, Vector3(0.0, 0.2 * s, 0.0), body, 0.5)
			_ball(parent, 0.06 * s, 1.0, Vector3(0.0, 0.42 * s, 0.0), accent, 0.4)
