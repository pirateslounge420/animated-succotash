class_name SongKeys
extends Node
## Plants are the keys (design §GK.2, queue 116 amended; data/song_web.json,
## crawler.json areas.keys). A song is learned by bringing the shaman a
## plant: "Go fetch me a plant, and I'll teach you its song."
##   the platter   a new game lays song_web.json platter's three key plants
##                 (cactus, mushroom, vine) on a wooden platter by the hub
##                 fire; the interact button takes the one you look at as a
##                 cutting in your pack. The others stay (kept in the save)
##                 until you take them too.
##   giving        the interact button by the shaman (or the fire) with a
##                 cutting of a song you don't know: he takes it, teaches you
##                 its realm's song (kept in the save, CrawlerSave.data.songs)
##                 and sings it at once, you sitting at the fire
##                 (CrawlerAreas.sit).
##   in a realm    every key its realm_offers lists grows on its surface
##                 (the desert: cactus, root, leaf); take a cutting (one per
##                 plant per visit) and carry it home. Where the two new
##                 ones grow moves to §GL.3's end and side path (queue 121).
## Which realms are built and which are stand-ins: areas.realms.

static var W: Dictionary = Tuning.table("song_web")

var main: CrawlerMain
var _platter: Node3D
var _platter_shown := []
## [{"node", "key", "realm", "visit"}]: the plants growing in a realm.
var _growing: Array = []
var _area_built: Surface
var gives := 0
var takes := 0


func setup(p_main: CrawlerMain) -> void:
	main = p_main
	name = "SongKeys"


static func K() -> Dictionary:
	return CrawlerAreas.A.get("keys", {})


## The realm key `key` opens (song_web.json keys.<key>.opens), or "".
static func realm_of(key: String) -> String:
	return str(((W.get("keys", {}) as Dictionary).get(key, {}) as Dictionary).get("opens", ""))


## The realm the built area `area` is (areas.realms.<realm>.area), or "".
static func realm_of_area(area := "first") -> String:
	var R: Dictionary = CrawlerAreas.A.get("realms", {})
	for r in R:
		if str((R[r] as Dictionary).get("area", "")) == area:
			return str(r)
	return ""


## The keys realm `realm` offers (song_web.json realm_offers), [] if open.
static func offers(realm: String) -> Array:
	var o: Variant = (W.get("realm_offers", {}) as Dictionary).get(realm, [])
	return o if o is Array else []


## The songs you know, in the order learned (the save's; a game kept before
## §GK keeps its "first" as the desert's).
static func known() -> Array:
	var k: Variant = CrawlerSave.data.get("songs", null)
	if not k is Array:
		k = ((CrawlerAreas.songs().get("known_from_start", []) as Array)).duplicate()
		CrawlerSave.data["songs"] = k
	var i := (k as Array).find("first")
	if i >= 0:
		k[i] = realm_of_area("first")
	return k


static func knows(realm: String) -> bool:
	return known().has(realm)


## Learn realm `realm`'s song (kept). False if it was known already.
static func learn(realm: String) -> bool:
	if realm == "" or knows(realm):
		return false
	known().append(realm)
	CrawlerSave.save()
	return true


## The keys still on the hub's platter (the save's; a new game's are
## song_web.json platter).
static func platter() -> Array:
	var p: Variant = CrawlerSave.data.get("platter", null)
	if not p is Array:
		p = (W.get("platter", ["cactus", "mushroom", "vine"]) as Array).duplicate()
		CrawlerSave.data["platter"] = p
	return p


static func look(key: String) -> Dictionary:
	return (K().get("look", {}) as Dictionary).get(key, {})


## A cutting of key `key`, for your pack.
static func cutting(key: String) -> Dictionary:
	var L := look(key)
	return Inventory.make("key_cutting", {"key": key, "title": str(L.get("title", key.capitalize())), "glyph": str(L.get("glyph", "cutting")), "color": str(L.get("colour", "#5a8a3a")), "accent": str(L.get("accent", "#6b4a2c"))})


## The carry slot of a cutting whose song you don't know yet (and that
## opens a realm the game has), or -1.
static func unknown_slot(inv: Inventory) -> int:
	var R: Dictionary = CrawlerAreas.A.get("realms", {})
	for i in inv.carried.size():
		var it: Variant = inv.carried[i]
		if it is Dictionary and str(it.get("kind", "")) == "key_cutting":
			var r := realm_of(str(it.get("key", "")))
			if R.has(r) and not knows(r):
				return i
	return -1


# --- Giving and taking -----------------------------------------------------------------

## By the shaman with a cutting of a song you don't know: he takes it,
## teaches you the song and sings it, you at the fire. True if given.
func give() -> bool:
	var inv := main.player.inventory
	var i := unknown_slot(inv)
	if i < 0:
		return false
	var it: Dictionary = inv.take(i)
	var realm := realm_of(str(it.key))
	learn(realm)
	gives += 1
	GameLog.add(str(K().get("log_give", "The shaman takes the %s and teaches you its song.")) % str(it.title).to_lower(), "world")
	main.areas.sit(realm)
	return true


## The interact button by the platter or a realm's key plant: a cutting in
## your pack. True if it took the press.
func take() -> bool:
	var best := _aimed()
	if best.is_empty():
		return false
	var key := str(best.key)
	var it := cutting(key)
	if not main.player.inventory.add(it):
		GameLog.add(str(K().get("log_full", "Your pack is full.")), "world")
		return true
	takes += 1
	if str(best.realm) == "hub":
		platter().erase(key)
		CrawlerSave.save()
		GameLog.add(str(K().get("log_take_platter", "You take the %s from the platter.")) % str(it.title).to_lower(), "world")
	else:
		best["visit"] = main.areas.travels
		GameLog.add(str(K().get("log_take_realm", "You take a %s.")) % str(it.title).to_lower(), "world")
	return true


## The key plant in reach you look at most squarely, within aim_deg of
## your view (else none): the platter's or a realm's that has a cutting to
## give this visit.
func _aimed() -> Dictionary:
	var reach := float(K().get("reach_m", 1.6))
	var aim := cos(deg_to_rad(float(K().get("aim_deg", 25.0))))
	var cam := main.player.camera()
	var eye := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var p := main.player.global_position
	var best := {}
	var bs := -INF
	for g in _plants():
		var node: Node3D = g.node
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if str(g.realm) != "hub" and int(g.visit) == main.areas.travels:
			continue
		var q := node.global_position
		if Vector2(q.x - p.x, q.z - p.z).length() > reach:
			continue
		var s := (q - eye).normalized().dot(fwd)
		if s >= aim and s > bs:
			bs = s
			best = g
	return best


## Every key plant that can be taken now: the platter's and the realm's.
func _plants() -> Array:
	var out: Array = []
	if _platter != null and is_instance_valid(_platter):
		for c in _platter.get_children():
			if c.has_meta("key"):
				out.append({"node": c, "key": str(c.get_meta("key")), "realm": "hub", "visit": -1})
	out.append_array(_growing)
	return out


# --- The platter and the realm's plants ------------------------------------------------

func _process(_delta: float) -> void:
	if main == null:
		return
	_ensure_platter()
	_ensure_realm()


## The platter by the hub fire, its plants as the save has them.
func _ensure_platter() -> void:
	var hub := main.hub_node as HubCamp
	if hub == null or not is_instance_valid(hub) or hub.land == null:
		return
	if _platter == null or not is_instance_valid(_platter):
		var P: Dictionary = K().get("platter", {})
		var fp: Vector3 = hub.camp.pos
		var n: Vector2 = hub.frame.n
		var side := Vector2(n.y, -n.x)
		var sp: Vector3 = hub.camp.spawn
		var to_you := Vector2(sp.x - fp.x, sp.z - fp.z).normalized()
		var at2 := Vector2(fp.x, fp.z) + side * float(P.get("from_fire_m", 1.35)) + to_you * float(P.get("toward_you_m", 0.9))
		_platter = Node3D.new()
		_platter.name = "SongPlatter"
		hub.add_child(_platter)
		_platter.position = Vector3(at2.x, hub.land.height_at(at2.x, at2.y), at2.y)
		var r := float(P.get("radius_m", 0.42))
		var dish := MeshInstance3D.new()
		dish.name = "Dish"
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r * 0.8
		cm.height = 0.07
		cm.radial_segments = 16
		dish.mesh = cm
		dish.material_override = _mat(str(P.get("wood", "#6b4a2c")), 0.55)
		dish.position = Vector3(0.0, 0.08, 0.0)
		_platter.add_child(dish)
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = r * 0.35
		lm.bottom_radius = r * 0.45
		lm.height = 0.06
		lm.radial_segments = 10
		leg.mesh = lm
		leg.material_override = dish.material_override
		leg.position = Vector3(0.0, 0.03, 0.0)
		_platter.add_child(leg)
		_platter_shown = []
	var want := platter().duplicate()
	if want == _platter_shown:
		return
	_platter_shown = want
	for c in _platter.get_children():
		if c.has_meta("key"):
			_platter.remove_child(c)
			c.queue_free()
	var all: Array = W.get("platter", ["cactus", "mushroom", "vine"])
	var r2 := float((K().get("platter", {}) as Dictionary).get("radius_m", 0.42)) * 0.55
	for i in all.size():
		var key := str(all[i])
		if not want.has(key):
			continue
		var pl := plant(key, float((K().get("platter", {}) as Dictionary).get("plant_scale", 1.8)))
		pl.set_meta("key", key)
		var a := TAU * float(i) / float(all.size())
		pl.position = Vector3(cos(a) * r2, 0.115, sin(a) * r2)
		pl.rotation.y = a
		_platter.add_child(pl)


## The key plants of the realm you are on, laid once its surface is built
## (one each of realm_offers, seeded, away from the hearth and the mouth).
func _ensure_realm() -> void:
	var area := main.area_node
	if area == null or not is_instance_valid(area) or area.land == null or area != main.surface or not area.is_inside_tree():
		return
	if area == _area_built:
		return
	_area_built = area
	_growing = []
	var realm := realm_of_area("first")
	var IR: Dictionary = K().get("in_realm", {})
	var keys := offers(realm)
	var spots := _spots(area, realm, keys.size() * int(IR.get("count", 1)))
	for i in spots.size():
		var key := str(keys[i % keys.size()])
		var pl := plant(key, 2.6)
		area.add_child(pl)
		pl.position = spots[i]
		pl.rotation.y = float(hash([realm, key, i]) % 628) / 100.0
		_growing.append({"node": pl, "key": key, "realm": realm, "visit": -1})


## Where a realm's key plants grow (seeded by the realm's surface): on its
## floor from_hearth_m out from its hearth, off the wash and the slopes,
## clear of its ruin's mouth, apart_m from each other.
static func _spots(area: Surface, realm: String, n: int) -> Array:
	var IR: Dictionary = K().get("in_realm", {})
	var fh: Array = IR.get("from_hearth_m", [18.0, 140.0])
	var apart := float(IR.get("apart_m", 25.0))
	var land := area.land
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([area.seed_value, realm, "key plants"])
	var hp := area.area_hearth.position if area.area_hearth != null else Vector3(land.center.x, 0.0, land.center.y)
	var h2 := Vector2(hp.x, hp.z)
	var mouth: Vector2 = area.stair.get("mouth", Vector2.INF) if area.stair is Dictionary else Vector2.INF
	var out: Array = []
	for attempt in 1200:
		if out.size() >= n:
			break
		var a := rng.randf() * TAU
		var p := h2 + Vector2(cos(a), sin(a)) * rng.randf_range(float(fh[0]), float(fh[1]))
		if not land.inside(p, 12.0) or land.slope_at(p.x, p.y) > 0.3 or land.in_wash(p) > 0.05:
			continue
		if mouth != Vector2.INF and p.distance_to(mouth) < 10.0:
			continue
		var ok := true
		for q: Vector3 in out:
			if p.distance_to(Vector2(q.x, q.z)) < apart * (0.5 if attempt > 600 else 1.0):
				ok = false
				break
		if ok:
			out.append(Vector3(p.x, land.height_at(p.x, p.y), p.y))
	return out


static func _mat(c: String, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = rough
	return m


static func _part(parent: Node3D, mesh: Mesh, at: Vector3, col: String, rough := 0.7, sc := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, rough)
	mi.position = at
	mi.scale = sc
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _sphere(r: float, h := -1.0, hemi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0.0 else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cylm(r0: float, r1: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


## Key `key`'s plant, `s` times its platter size (a cutting on the platter
## at 1; growing in a realm bigger).
static func plant(key: String, s: float) -> Node3D:
	var L := look(key)
	var col := str(L.get("colour", "#5a8a3a"))
	var acc := str(L.get("accent", "#6b4a2c"))
	var root := Node3D.new()
	root.name = "KeyPlant_" + key
	var body := Node3D.new()
	body.scale = Vector3.ONE * s
	root.add_child(body)
	match key:
		"cactus":
			# A ribbed barrel with a flower on top.
			_part(body, _sphere(0.07, 0.15), Vector3(0, 0.07, 0), col, 0.45)
			for k in 8:
				var a := TAU * k / 8.0
				_part(body, _cylm(0.006, 0.006, 0.13), Vector3(cos(a) * 0.066, 0.07, sin(a) * 0.066), Color(col).darkened(0.3).to_html(false), 0.5)
			_part(body, _sphere(0.022), Vector3(0, 0.145, 0), acc, 0.4)
		"mushroom":
			_part(body, _cylm(0.018, 0.014, 0.08), Vector3(0, 0.04, 0), acc, 0.7)
			_part(body, _sphere(0.06, 0.06, true), Vector3(0, 0.075, 0), col, 0.5)
		"vine":
			# A coil of woody vine with a few leaves.
			var prev := Vector3(0.0, 0.01, 0.0)
			for k in 7:
				var a := k * 1.2
				var nxt := Vector3(cos(a) * 0.07, 0.015 + 0.012 * k, sin(a) * 0.07)
				var mid := (prev + nxt) * 0.5
				var d := nxt - prev
				var seg := _part(body, _cylm(0.008, 0.008, d.length()), mid, acc, 0.7)
				var y := d.normalized()
				var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
				seg.transform = Transform3D(Basis(x, y, x.cross(y)), mid)
				if k % 2 == 1:
					_part(body, _sphere(0.03), nxt + Vector3(0, 0.01, 0), col, 0.55, Vector3(1.0, 0.18, 0.55), Vector3(0, a, 0))
				prev = nxt
		"root":
			for k in 3:
				var a := TAU * k / 3.0
				_part(body, _cylm(0.012, 0.004, 0.18), Vector3(cos(a) * 0.03, 0.02, sin(a) * 0.03), col, 0.8, Vector3.ONE, Vector3(PI * 0.5, a, 0.3 * k))
			_part(body, _sphere(0.03), Vector3(0, 0.03, 0), acc, 0.8)
		"leaf":
			_part(body, _cylm(0.004, 0.004, 0.08), Vector3(0, 0.04, 0), acc, 0.7)
			_part(body, _sphere(0.08), Vector3(0, 0.09, 0.03), col, 0.5, Vector3(0.6, 0.12, 1.0), Vector3(-0.4, 0, 0))
		_:
			_part(body, _sphere(0.06), Vector3(0, 0.06, 0), col, 0.6)
	return root
