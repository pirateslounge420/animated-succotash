class_name HubCamp
extends Surface
## The hub camp on the surface (design §GC.1-2, §FZ.1; queue 112; Mike,
## 26 Oct: "spawn in around the campfire at dusk and also set up a RNG camp
## sites for each of our specialized village niches"; data/crawler.json
## hub). Built on Surface's machinery (the basin closed by cliffs, the wash,
## the plants, the life, the sky on the one clock, the old stair down into
## the dungeon) with the hub's own settings laid over it, and on that:
##
##   the kind      stone, ruins or vines, one per game from the seed: what
##                 towers round the clearing (crooked rock pillars,
##                 oversized roots, broken columns, hanging vines)
##   the river     water down the wash, the brightest thing in view
##   the fire      the campfire just in front of the stair's mouth, so the
##                 way down opens behind it; you spawn across it, facing it
##   the ring      standing stones round the way down
##   the shaman    the hooded cook-shaman on a stone by the fire, stirring a
##                 cauldron that glows green (§FZ.1.6)
##   the keepers   the other five keepers' sites (§FZ.1), each placed from
##                 the seed round the fire, the fisher-weaver's on the river
##                 bank, each with its trade's props and a hooded stand-in
##                 in its trade's colours (their looks are §FZ.4's to-do)
##
## Everything is drawn from the game's seed (§FK.2): the same camp every
## time in this game. plan() is the layout alone (no nodes), for the checks.

static var H: Dictionary = Tuning.table("crawler").get("hub", {})

var kind := ""
## {"pos" (the fire, scene), "spawn", "spawn_yaw"}.
var camp: Dictionary = {}
## [{"keeper", "at" (Vector3), "yaw"}]: the five keepers' sites.
var sites: Array = []
var shaman: HearthFolk
var keeper_folk: Array = []
var fire: Node3D
var _mats := {}


static func on() -> bool:
	return bool(H.get("on", true))


## The hub's settings: worlds.json surface (the dungeon's theme's) with
## hub.surface laid over it, sized from `seed_value`.
static func hub_settings(seed_value: int, theme_name: String) -> Dictionary:
	use_theme(theme_name)
	var p := settings()
	_lay_over(p, (H.get("surface", {}) as Dictionary).duplicate(true))
	var ar: Array = H.get("across_m", [150.0, 250.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "hub across"])
	p["across_m"] = rng.randf_range(float(ar[0]), float(ar[1]))
	var pl: Dictionary = p.get("plants", {})
	pl["zones"] = (H.get("zones", {}) as Dictionary).duplicate()
	var r := float(p.across_m) * 0.5
	pl["upland_from_edge_m"] = r * 0.35
	pl["ground_within_m"] = r
	p["plants"] = pl
	var F: Dictionary = p.get("finds", {})
	F["within_m"] = [r * 0.3, r * 0.7]
	F["apart_m"] = r * 0.12
	F["clear_of_stair_m"] = 30.0
	var L: Dictionary = p.get("life", {})
	L["within_m"] = [r * 0.25, r * 0.7]
	L["gone_past_m"] = r * 1.2
	p["life"] = L
	return p


## The camp's seed for this game.
static func seed_of(game_seed: int) -> int:
	return hash([game_seed, "hub"])


## The layout alone, for dungeon `p_lay` in game `game_seed`: {"seed",
## "kind", "land", "stair", "camp", "sites", "P"}. Pure: no nodes.
static func plan(p_lay: Dictionary, game_seed: int) -> Dictionary:
	var s := seed_of(game_seed)
	var p := hub_settings(s, str(p_lay.get("theme", "tomb")))
	var frame := SurfaceBuild.stair_frame(p_lay, p, level())
	var g := SurfaceGround.new()
	g.setup(p, s, frame.mouth, frame.n, level())
	g.carve_stair(frame)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([s, "hub kind"])
	var kinds := ["stone", "ruins", "vines"]
	var k: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var c := camp_of(g, frame)
	return {"seed": s, "kind": k, "land": g, "stair": frame, "camp": c, "sites": sites_of(g, frame, c, s), "P": p}


## The fire just out from the stair's mouth; you across it, facing it.
static func camp_of(g: SurfaceGround, frame: Dictionary) -> Dictionary:
	var F: Dictionary = H.get("fire", {})
	var n: Vector2 = frame.n
	var f2: Vector2 = (frame.mouth as Vector2) + n * float(F.get("out_m", 4.5))
	var s2 := f2 + n * float(F.get("spawn_m", 2.6))
	return {"pos": Vector3(f2.x, g.height_at(f2.x, f2.y), f2.y), "spawn": Vector3(s2.x, g.height_at(s2.x, s2.y) + 0.05, s2.y), "spawn_yaw": atan2(n.x, n.y)}


## The five keepers' sites, from seed `s`: on a ring round the fire, apart,
## clear of the stair, the river and the cliffs; the fisher-weaver's on
## the river's bank.
static func sites_of(g: SurfaceGround, frame: Dictionary, c: Dictionary, s: int) -> Array:
	var K: Dictionary = H.get("keepers", {})
	var within: Array = K.get("within_m", [11.0, 26.0])
	var apart := float(K.get("apart_m", 9.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([s, "hub keepers"])
	var fire2 := Vector2((c.pos as Vector3).x, (c.pos as Vector3).z)
	var mouth: Vector2 = frame.mouth
	var n: Vector2 = frame.n
	var out: Array = []
	var taken: Array = [fire2, mouth]
	var wash: Dictionary = (g.G.get("wash", {}) as Dictionary)
	for key in (K.get("list", {}) as Dictionary).keys():
		var best := Vector2.INF
		for attempt in 200:
			var p2 := Vector2.INF
			if key == "fisher_weaver":
				# On the river's bank: along its line, a bank's width off it.
				var along := float(wash.get("from_m", 16.0)) + rng.randf_range(8.0, 40.0)
				var lat := g.wash_offset(along) + (1.0 if rng.randf() < 0.5 else -1.0) * (float(wash.get("width_m", 9.0)) * 0.5 + 2.5)
				p2 = g.center + n * along + Vector2(-n.y, n.x) * lat
			else:
				var a := rng.randf() * TAU
				p2 = fire2 + Vector2(cos(a), sin(a)) * rng.randf_range(float(within[0]), float(within[1]))
			if not g.inside(p2, 25.0) or g.slope_at(p2.x, p2.y) > 0.35:
				continue
			if key != "fisher_weaver" and g.zone_at(p2, 0.0) == "wash":
				continue
			if key == "fisher_weaver" and g.in_wash(p2) > 0.05:
				continue
			# Clear of the stair's cut (behind the mouth, along -n).
			var rel := p2 - mouth
			if rel.dot(n) < 2.0 and absf(rel.dot(Vector2(n.y, -n.x))) < 6.0 and rel.dot(n) > -float(frame.run) - 6.0:
				continue
			var ok := true
			for t: Vector2 in taken:
				if p2.distance_to(t) < apart:
					ok = false
					break
			if ok:
				best = p2
				break
		if best == Vector2.INF:
			continue
		taken.append(best)
		var to_fire := fire2 - best
		out.append({"keeper": key, "at": Vector3(best.x, g.height_at(best.x, best.y), best.y), "yaw": atan2(-to_fire.x, -to_fire.y)})
	return out


## The camp over dungeon `p_lay` (the game's seed, §FK.2); `p_hearth` the
## hearth below.
func build(p_world: Node, p_lay: Dictionary, p_hearth: Node3D) -> void:
	name = "Hub"
	world = p_world
	lay = p_lay
	hearth = p_hearth
	var t0 := Time.get_ticks_msec()
	var pl := plan(p_lay, CrawlerSave.game_seed)
	seed_value = int(pl.seed)
	kind = str(pl.kind)
	P = pl.P
	across_m = float(P.across_m)
	land = pl.land
	camp = pl.camp
	sites = pl.sites
	_ground()
	var data := SurfaceBuild.make(land, lay, P, seed_value)
	stair = data.stair
	stacks = data.stacks
	slots = data.slots
	finds = data.finds
	_stone(data)
	var keep_out: Array = [(stair.yard as Rect2).grow(4.0), SurfaceBuild._rect(stair.bottom, stair.mouth, float(stair.half) + 3.0)]
	var fp: Vector3 = camp.pos
	keep_out.append(Rect2(Vector2(fp.x, fp.z) - Vector2(8.0, 8.0), Vector2(16.0, 16.0)))
	for s in stacks:
		var f: Vector3 = s.foot
		keep_out.append(Rect2(Vector2(f.x, f.z) - Vector2(2.0, 2.0), Vector2(4.0, 4.0)))
	for f in finds:
		var a: Vector3 = f.at
		keep_out.append(Rect2(Vector2(a.x, a.z) - Vector2(4.0, 4.0), Vector2(8.0, 8.0)))
	for st in sites:
		var a: Vector3 = st.at
		keep_out.append(Rect2(Vector2(a.x, a.z) - Vector2(7.0, 7.0), Vector2(14.0, 14.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "hub props"])
	_river()
	_kind_props(rng, keep_out)
	_ring(rng)
	_fire()
	_shaman()
	_keepers()
	_common(rng)
	plants = SurfacePlants.new()
	plants.name = "Plants"
	add_child(plants)
	plants.build(land, P, _biome(), seed_value, keep_out)
	life = SurfaceLife.new()
	add_child(life)
	life.setup(land, P, _climate_of(_biome()), seed_value, null)
	sky = SkySystem.new()
	sky.name = "Sky"
	sky.one_clock = true
	sky.mist_place = float((S.get("sky", {}) as Dictionary).get("mist_place", 0.15))
	add_child(sky)
	_smoke()
	_sound()
	var K: Dictionary = S.get("sky", {})
	var wind_mps := float(K.get("wind_mps", 2.2))
	weather = {"cloud": float(K.get("cloud", 0.15)), "storm": 0.0, "rain_mm_h": 0.0, "wind": Vector3(0.8, 0.0, 0.6).normalized() * wind_mps, "clear": 1.0 - float(K.get("cloud", 0.15))}
	ms["all"] = Time.get_ticks_msec() - t0
	print("[hub] seed %d (game %d): %s camp, %.0f m across, fire at %s, %d keepers' sites (%s), %d plants; built in %d ms" % [seed_value, CrawlerSave.game_seed, kind, across_m, str(Vector2(fp.x, fp.z).snapped(Vector2.ONE * 0.1)), sites.size(), ", ".join(sites.map(func(x): return str(x.keeper))), plants.placed, int(ms.all)])


func _biome() -> Dictionary:
	var key := str(H.get("biome", "TEMPERATE_DECIDUOUS"))
	var dir := DirAccess.open("res://data/biomes")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".json"):
				var doc = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes/" + f))
				if doc is Dictionary and str(doc.get("key", "")) == key:
					return doc
	return biome_doc()


static func _climate_of(doc: Dictionary) -> Dictionary:
	var cl: Dictionary = doc.get("climate", {})
	var t: Array = cl.get("temp_c", [6.0, 19.0])
	var m: Array = cl.get("moisture", [0.5, 0.9])
	return {"temp_c": Vector2(float(t[0]), float(t[1])), "moisture": Vector2(float(m[0]), float(m[1]))}


## Up into the camp: Surface's enter, then (glossy, design §GB; Mike,
## 26 Oct) the sky's environment graded high-contrast and the ground's and
## plants' tiles drawn smooth.
func enter(main: Node) -> void:
	super.enter(main)
	if GlossyLook.active:
		GlossyLook.surface_env(sky.environment)
		if not has_meta("smoothed"):
			set_meta("smoothed", GlossyLook.smooth_all(self))


## You start (and come back up) at the fire, across it, facing it.
func arrival() -> Dictionary:
	return {"pos": camp.spawn, "yaw": float(camp.spawn_yaw)}


# --- Building blocks ---------------------------------------------------------------

func _mat(hex: String, rough := 0.6, glow := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [hex, rough, glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = rough
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = Color(hex)
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


func _block(parent: Node3D, size: Vector3, xf: Transform3D, hex: String, rough := 0.5, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(hex, rough)
	mi.transform = xf
	parent.add_child(mi)
	if solid:
		var body := PropCollision.body(mi)
		PropCollision.box(body, Transform3D.IDENTITY, size)
	return mi


func _cyl(parent: Node3D, r0: float, r1: float, h: float, xf: Transform3D, hex: String, rough := 0.6, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = _mat(hex, rough, glow)
	mi.transform = xf
	parent.add_child(mi)
	return mi


## A rod from `a` to `b` (scene), radius r0 at a, r1 at b.
func _rod(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, hex: String, rough := 0.6, solid := false) -> MeshInstance3D:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var mi := _cyl(parent, r0, r1, a.distance_to(b), Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), hex, rough)
	if solid:
		var body := PropCollision.body(parent)
		PropCollision.capsule_between(body, a, b, maxf(r0, r1))
	return mi


func _ground_at(p: Vector2) -> Vector3:
	return Vector3(p.x, land.height_at(p.x, p.y), p.y)


func _free_spot(rng: RandomNumberGenerator, keep_out: Array, r_from: float, r_to: float, margin: float) -> Vector2:
	var fp: Vector3 = camp.pos
	for i in 80:
		var a := rng.randf() * TAU
		var p := Vector2(fp.x, fp.z) + Vector2(cos(a), sin(a)) * rng.randf_range(r_from, r_to)
		if not land.inside(p, margin) or land.in_wash(p) > 0.05:
			continue
		var clear := true
		for r: Rect2 in keep_out:
			if r.grow(margin).has_point(p):
				clear = false
				break
		if clear:
			return p
	return Vector2.INF


# --- The river ---------------------------------------------------------------------

## Water down the wash's line (SurfaceGround), a hand under the banks: a
## strip of quads following its bends, glossy and bright (§GB.1.3: the
## brightest thing in view).
func _river() -> void:
	var W: Dictionary = land.G.get("wash", {})
	var from := float(W.get("from_m", 16.0))
	var half := float(W.get("width_m", 9.0)) * 0.42
	var n := land.n
	var side := Vector2(-n.y, n.x)
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var s := from + 2.0
	var prev: Array = []
	while s < across_m:
		var c := land.center + n * s + side * land.wash_offset(s)
		if not land.inside(c, 4.0):
			break
		var y := land.height_at(c.x, c.y) + float(W.get("depth_m", 1.8)) * 0.55
		var l := Vector3(c.x - side.x * half, y, c.y - side.y * half)
		var r := Vector3(c.x + side.x * half, y, c.y + side.y * half)
		if not prev.is_empty():
			for q in [prev[0], r, prev[1], prev[0], l, r]:
				v.append(q)
				nr.append(Vector3.UP)
		prev = [l, r]
		s += 2.0
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nr
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#3fa8e8")
	m.roughness = 0.04
	m.metallic_specular = 1.0
	m.emission_enabled = true
	m.emission = Color("#2a7fd0")
	m.emission_energy_multiplier = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- The kind: what towers round the clearing -----------------------------------------

func _kind_props(rng: RandomNumberGenerator, keep_out: Array) -> void:
	var K: Dictionary = (H.get("kinds", {}) as Dictionary).get(kind, {})
	var root := Node3D.new()
	root.name = "Kind_" + kind
	add_child(root)
	var r := across_m * 0.5
	var pr: Array = K.get("pillars", [6, 9])
	var ph: Array = K.get("pillar_h_m", [12.0, 26.0])
	var pillars: Array = []
	for i in rng.randi_range(int(pr[0]), int(pr[1])):
		var p := _free_spot(rng, keep_out, r * 0.25, r * 0.92, 3.0)
		if p == Vector2.INF:
			continue
		keep_out.append(Rect2(p - Vector2(4.0, 4.0), Vector2(8.0, 8.0)))
		pillars.append(_pillar(root, rng, _ground_at(p), rng.randf_range(float(ph[0]), float(ph[1]))))
	var rr: Array = K.get("roots", [1, 2])
	for i in rng.randi_range(int(rr[0]), int(rr[1])):
		var p := _free_spot(rng, keep_out, r * 0.2, r * 0.85, 4.0)
		if p != Vector2.INF:
			keep_out.append(Rect2(p - Vector2(6.0, 6.0), Vector2(12.0, 12.0)))
			_root_arch(root, rng, p)
	var ru: Array = K.get("ruins", [0, 0])
	for i in rng.randi_range(int(ru[0]), int(ru[1])):
		var p := _free_spot(rng, keep_out, 9.0, r * 0.8, 2.0)
		if p != Vector2.INF:
			keep_out.append(Rect2(p - Vector2(2.5, 2.5), Vector2(5.0, 5.0)))
			_broken_column(root, rng, _ground_at(p))
	var vines := float(K.get("vines", 0.0))
	for top in pillars:
		if rng.randf() < vines:
			_vines(root, rng, top as Vector3)


## A tall crooked rock stack: blocks one on another, each leaning and
## turned a little more, narrowing then flaring (exaggerated, §GC.1).
## Returns its top.
func _pillar(parent: Node3D, rng: RandomNumberGenerator, foot: Vector3, h: float) -> Vector3:
	var at := foot - Vector3(0.0, 1.0, 0.0)
	var w := rng.randf_range(2.6, 4.6)
	var lean := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.04, 0.16)
	var made := 0.0
	var yaw := rng.randf() * TAU
	var cols := ["#3c4058", "#454a66", "#33374e"]
	while made < h:
		var bh := minf(rng.randf_range(2.2, 4.8), h - made + 0.5)
		var t := made / h
		var ww := w * lerpf(1.0, 0.55, t) * (1.25 if t > 0.75 else 1.0) * rng.randf_range(0.85, 1.1)
		yaw += rng.randf_range(-0.35, 0.35)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3(lean.y, 0.0, -lean.x).normalized() if lean.length() > 0.0 else Vector3.RIGHT, lean.length() * rng.randf_range(0.5, 1.5))
		_block(parent, Vector3(ww, bh, ww * rng.randf_range(0.7, 1.0)), Transform3D(b, at + Vector3(0.0, bh * 0.5, 0.0)), str(cols[rng.randi_range(0, 2)]), 0.35)
		at += Vector3(lean.x, 1.0, lean.y) * bh
		made += bh
	return at


## An oversized root arching out of the ground and back into it.
func _root_arch(parent: Node3D, rng: RandomNumberGenerator, p: Vector2) -> void:
	var a := rng.randf() * TAU
	var span := rng.randf_range(7.0, 14.0)
	var rise := rng.randf_range(2.5, 6.0)
	var thick := rng.randf_range(0.5, 1.0)
	var d := Vector2(cos(a), sin(a))
	var last := Vector3.INF
	for i in 9:
		var t := float(i) / 8.0
		var q := p + d * (t - 0.5) * span + Vector2(-d.y, d.x) * sin(t * PI * 2.0) * 1.2
		var pt := _ground_at(q) + Vector3(0.0, sin(t * PI) * rise - 0.4, 0.0)
		if last != Vector3.INF:
			_rod(parent, last, pt, thick * (1.0 - 0.3 * absf(t - 0.5)), thick * (1.0 - 0.3 * absf(t - 0.5)), "#3a2a22", 0.55, true)
		last = pt


## A broken column: two or three drums, the top one askew, a fallen drum
## and a lintel block beside it.
func _broken_column(parent: Node3D, rng: RandomNumberGenerator, foot: Vector3) -> void:
	var r := rng.randf_range(0.45, 0.75)
	var at := foot - Vector3(0.0, 0.2, 0.0)
	for i in rng.randi_range(1, 3):
		var h := rng.randf_range(0.9, 1.6)
		var mi := _cyl(parent, r, r * 0.96, h, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)), at + Vector3(0.0, h * 0.5, 0.0)), "#5a5a78", 0.3)
		var body := PropCollision.body(mi)
		PropCollision.capsule(body, Transform3D.IDENTITY, r, h)
		at.y += h
	var side := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(1.5, 2.5)
	var g := _ground_at(Vector2(foot.x + side.x, foot.z + side.z))
	_block(parent, Vector3(rng.randf_range(1.6, 2.6), 0.55, 0.7), Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15)), g + Vector3(0.0, 0.2, 0.0)), "#55556e", 0.3)


## Vines hung from a pillar's top: long thin strands with leafy knots.
func _vines(parent: Node3D, rng: RandomNumberGenerator, top: Vector3) -> void:
	for i in rng.randi_range(4, 8):
		var o := Vector3(rng.randf_range(-1.6, 1.6), 0.0, rng.randf_range(-1.6, 1.6))
		var a := top + o
		var len := rng.randf_range(4.0, maxf(top.y - land.base_y - 1.0, 5.0))
		var b := a - Vector3(rng.randf_range(-0.5, 0.5), len, rng.randf_range(-0.5, 0.5))
		_rod(parent, a, b, 0.06, 0.04, "#1f5a24", 0.7)
		var k := 0.15
		while k < 1.0:
			var q := a.lerp(b, k)
			var leaf := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = rng.randf_range(0.18, 0.35)
			sp.height = sp.radius * 1.4
			sp.radial_segments = 6
			sp.rings = 3
			leaf.mesh = sp
			leaf.material_override = _mat("#2f6b2a", 0.35)
			leaf.position = q
			parent.add_child(leaf)
			k += rng.randf_range(0.12, 0.25)


# --- The way down: standing stones round the stair ------------------------------------

func _ring(rng: RandomNumberGenerator) -> void:
	var R: Dictionary = H.get("ring", {})
	var root := Node3D.new()
	root.name = "StandingStones"
	add_child(root)
	var mid: Vector2 = (stair.mouth as Vector2) - (stair.n as Vector2) * float(stair.run) * 0.5
	var n_stones := int(R.get("stones", 7))
	var hr: Array = R.get("h_m", [1.8, 3.2])
	var rad := float(R.get("r_m", 4.2)) + float(stair.run) * 0.5
	var fp: Vector3 = camp.pos
	for i in n_stones:
		var a := TAU * float(i) / n_stones + rng.randf_range(-0.15, 0.15)
		var p := mid + Vector2(cos(a), sin(a)) * rad
		# Leave the gap toward the fire open (the way in).
		if p.distance_to(Vector2(fp.x, fp.z)) < rad * 0.8:
			continue
		var h := rng.randf_range(float(hr[0]), float(hr[1]))
		var g := _ground_at(p)
		_block(root, Vector3(rng.randf_range(0.7, 1.1), h, rng.randf_range(0.4, 0.6)), Transform3D(Basis(Vector3.UP, a + PI * 0.5) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)), g + Vector3(0.0, h * 0.5 - 0.3, 0.0)), "#4a4d6e", 0.25)


# --- The fire, the cook-shaman, the keepers -------------------------------------------

func _fire() -> void:
	var fp: Vector3 = camp.pos
	fire = Campfire.build_at(self, world, Transform3D(Basis.IDENTITY, fp), CrawlerFires.key_dir(fp + Vector3(0.0, 0.37, 0.0)), false)
	fire.name = "HubFire"


func _shaman() -> void:
	var S2: Dictionary = H.get("shaman", {})
	var fp: Vector3 = camp.pos
	var n: Vector2 = stair.n
	var side := Vector2(n.y, -n.x)
	var d := float(S2.get("from_fire_m", 1.7))
	var cauld2 := Vector2(fp.x, fp.z) + side * (d * 0.6)
	var seat2 := Vector2(fp.x, fp.z) + side * (d + 0.6)
	var seat := _ground_at(seat2)
	var to := Vector2(fp.x, fp.z) - seat2
	var cl: Array = S2.get("cloak", ["#1d1a2a", "#2c2638"])
	_block(self, Vector3(0.6, 0.34, 0.45), Transform3D(Basis(Vector3.UP, atan2(-to.x, -to.y)), seat + Vector3(0.0, 0.12, 0.0)), "#3a3c55", 0.4)
	shaman = HearthFolk.make(self, "CookShaman", seat, atan2(-to.x, -to.y), 1.62, [Color(str(cl[0])), Color(str(cl[1]))], "")
	# The pipe: a long bone pipe from the hood, a thin smoke wisp off its bowl.
	var head := shaman.body.head as Node3D
	if head != null:
		var pipe := _rod(head, Vector3(0.0, -0.05, -0.12), Vector3(0.05, -0.2, -0.55), 0.012, 0.018, "#d8cfa8", 0.4)
		pipe.name = "Pipe"
		var bowl := _cyl(head, 0.03, 0.04, 0.07, Transform3D(Basis.IDENTITY, Vector3(0.05, -0.17, -0.56)), "#d8cfa8", 0.4)
		var wisp := CPUParticles3D.new()
		wisp.name = "PipeSmoke"
		wisp.amount = 24
		wisp.lifetime = 3.0
		wisp.direction = Vector3.UP
		wisp.spread = 8.0
		wisp.gravity = Vector3(0.05, 0.12, 0.0)
		wisp.initial_velocity_min = 0.08
		wisp.initial_velocity_max = 0.14
		wisp.scale_amount_min = 0.6
		wisp.scale_amount_max = 1.6
		var q := QuadMesh.new()
		q.size = Vector2(0.06, 0.06)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(0.6, 0.62, 0.75, 0.25)
		q.material = sm
		wisp.mesh = q
		wisp.position = Vector3(0.0, 0.05, 0.0)
		bowl.add_child(wisp)
	# The cauldron: a black iron-dark clay pot on three stones, its brew
	# glowing green (the frame's one green accent, §GB.1.2).
	var cg := _ground_at(cauld2)
	var pot := Node3D.new()
	pot.name = "Cauldron"
	pot.position = cg
	add_child(pot)
	for i in 3:
		var a := TAU * i / 3.0
		_block(pot, Vector3(0.22, 0.2, 0.22), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.3, 0.1, sin(a) * 0.3)), "#3a3c55", 0.4, false)
	var body := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.42
	sp.height = 0.62
	body.mesh = sp
	body.material_override = _mat("#14141c", 0.25)
	body.position = Vector3(0.0, 0.48, 0.0)
	pot.add_child(body)
	var glow_hex := str(S2.get("glow", "#7cff4f"))
	var brew := _cyl(pot, 0.34, 0.34, 0.02, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.74, 0.0)), glow_hex, 0.2, 3.0)
	brew.name = "Brew"
	var gl := OmniLight3D.new()
	gl.name = "BrewGlow"
	gl.light_color = Color(glow_hex)
	gl.light_energy = float(S2.get("glow_energy", 1.4))
	gl.omni_range = float(S2.get("glow_range_m", 5.0))
	gl.position = Vector3(0.0, 1.0, 0.0)
	pot.add_child(gl)
	var pc := PropCollision.body(pot)
	PropCollision.capsule(pc, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0)), 0.42, 0.9)


func _keepers() -> void:
	var L: Dictionary = (H.get("keepers", {}) as Dictionary).get("list", {})
	for st in sites:
		var key := str(st.keeper)
		var at: Vector3 = st.at
		var yaw := float(st.yaw)
		var site := Node3D.new()
		site.name = "Site_" + key
		site.position = at
		site.rotation.y = yaw
		add_child(site)
		# Its seat, and its keeper (a hooded stand-in in its trade's cloak).
		_block(site, Vector3(0.6, 0.34, 0.45), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.0)), "#3a3c55", 0.4)
		var cl: Array = (L.get(key, {}) as Dictionary).get("cloak", ["#2c2638", "#3c3648"])
		var f := HearthFolk.make(self, "Keeper_" + key, at, yaw, 1.62, [Color(str(cl[0])), Color(str(cl[1]))], "")
		f.hold("")
		f.set_meta("keeper", key)
		keeper_folk.append(f)
		var drng := RandomNumberGenerator.new()
		drng.seed = hash([seed_value, "dress", key])
		_dress(site, key, drng)
		match key:
			"hunter_tanner":
				_rack(site, Vector3(-1.8, 0.0, 1.4), "#6b4a2e", "#8a6a48", true)
				for i in 5:
					_rod(site, Vector3(1.4 + i * 0.12, 0.1, 1.0), Vector3(1.9 - i * 0.1, 0.12, 1.5), 0.04, 0.03, "#d8cfa8", 0.5)
			"fisher_weaver":
				_rack(site, Vector3(-1.6, 0.0, 1.2), "#4a3a28", "#9aa0b8", false)
				_basket(site, Vector3(1.3, 0.0, 0.9))
				_basket(site, Vector3(1.8, 0.0, 1.5))
				_rod(site, Vector3(0.8, 0.0, -0.4), Vector3(1.2, 2.4, -1.8), 0.03, 0.015, "#6b5030", 0.6)
			"woodcutter_firekeeper":
				for row in 3:
					for i in 4 - row:
						_rod(site, Vector3(-2.4, 0.18 + row * 0.3, 1.0 + i * 0.32 + row * 0.16), Vector3(-0.8, 0.18 + row * 0.3, 1.0 + i * 0.32 + row * 0.16), 0.15, 0.15, "#5a3e24", 0.7, row == 0)
				_cyl(site, 0.38, 0.4, 0.55, Transform3D(Basis.IDENTITY, Vector3(1.5, 0.27, 1.0)), "#6b4a2e", 0.6)
				_rod(site, Vector3(1.5, 0.55, 1.0), Vector3(1.8, 1.1, 1.1), 0.025, 0.025, "#8a6a48", 0.6)
			"forager_herbalist":
				_rack(site, Vector3(-1.7, 0.0, 1.3), "#4a3a28", "#3e6a2e", false)
				_basket(site, Vector3(1.4, 0.0, 1.1))
				_basket(site, Vector3(1.0, 0.0, 1.7))
			"knapper_potter":
				_kiln(site, Vector3(-2.0, 0.0, 1.6))
				for i in 4:
					var pot := _cyl(site, 0.16, 0.12, 0.34, Transform3D(Basis.IDENTITY, Vector3(1.2 + (i % 2) * 0.45, 0.17, 0.9 + (i / 2) * 0.45)), "#9a5e3a", 0.35)
					pot.name = "Pot"
				for i in 6:
					_block(site, Vector3(0.22, 0.12, 0.18), Transform3D(Basis(Vector3.UP, i * 1.1), Vector3(0.5 + (i % 3) * 0.2, 0.06, 1.8 + (i / 3) * 0.2)), "#2a2c3e", 0.2, false)


## `local` (in `site`'s frame) set down on the ground there.
func _on(site: Node3D, local: Vector3) -> Vector3:
	var w := site.to_global(Vector3(local.x, 0.0, local.z)) if site.is_inside_tree() else site.transform * Vector3(local.x, 0.0, local.z)
	return Vector3(local.x, land.height_at(w.x, w.z) - site.position.y + local.y, local.z)


## Each keeper's place made theirs (Mike, 26 Oct: "more fleshed out ...
## consider the different niches"): a shelter in their trade's way, a
## torch post, and their trade's work laid round it (crawler.json
## hub.keepers.dress).
func _dress(site: Node3D, key: String, rng: RandomNumberGenerator) -> void:
	_torch_post(site, _on(site, Vector3(1.2, 0.0, -0.8)))
	match key:
		"hunter_tanner":
			# A hide tent: a cone of stitched hides on poles.
			_tent(site, _on(site, Vector3(0.0, 0.0, 4.2)), 1.7, 2.6, "#7a5236", "#4a2e1e")
			# A hide stretched on a hoop frame, a skull-and-antler totem,
			# spears leaning on a crossbar, meat drying over a smoke pit.
			var hoop := _on(site, Vector3(2.6, 0.0, 1.8))
			_cyl(site, 0.9, 0.9, 0.05, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.2), hoop + Vector3(0, 1.0, 0)), "#5a3e24", 0.6)
			_cyl(site, 0.82, 0.82, 0.02, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.2), hoop + Vector3(0, 1.0, 0.01)), "#a8805a", 0.75)
			_totem(site, _on(site, Vector3(-2.8, 0.0, -0.6)), rng, true)
			var rack := _on(site, Vector3(-3.0, 0.0, 2.8))
			_rod(site, rack + Vector3(-0.8, 0, 0), rack + Vector3(-0.8, 1.4, 0), 0.04, 0.04, "#5a3e24", 0.6)
			_rod(site, rack + Vector3(0.8, 0, 0), rack + Vector3(0.8, 1.4, 0), 0.04, 0.04, "#5a3e24", 0.6)
			_rod(site, rack + Vector3(-0.8, 1.35, 0), rack + Vector3(0.8, 1.35, 0), 0.03, 0.03, "#5a3e24", 0.6)
			for i in 4:
				var x := -0.6 + i * 0.4
				_rod(site, rack + Vector3(x, 0.0, 0.5), rack + Vector3(x + 0.1, 2.3, -0.1), 0.025, 0.02, "#6b4a2e", 0.5)
				_cyl(site, 0.0, 0.05, 0.22, Transform3D(Basis.IDENTITY, rack + Vector3(x + 0.1, 2.4, -0.1)), "#2a2c3e", 0.15)
			var pit := _on(site, Vector3(1.0, 0.0, 3.0))
			_cyl(site, 0.5, 0.55, 0.12, Transform3D(Basis.IDENTITY, pit + Vector3(0, 0.03, 0)), "#1e1a1a", 0.9)
			for i in 3:
				_block(site, Vector3(0.3, 0.12, 0.05), Transform3D(Basis.IDENTITY, pit + Vector3(-0.3 + i * 0.3, 1.1, 0)), "#7a2a1e", 0.4, false)
			_rod(site, pit + Vector3(-0.6, 0, 0), pit + Vector3(-0.6, 1.3, 0), 0.03, 0.03, "#5a3e24")
			_rod(site, pit + Vector3(0.6, 0, 0), pit + Vector3(0.6, 1.3, 0), 0.03, 0.03, "#5a3e24")
			_rod(site, pit + Vector3(-0.6, 1.25, 0), pit + Vector3(0.6, 1.25, 0), 0.02, 0.02, "#5a3e24")
		"fisher_weaver":
			# A reed hut, a dugout drawn up on the bank, a fish-drying line, a
			# fish trap and a net spread on stakes.
			_hut(site, _on(site, Vector3(-0.5, 0.0, 4.0)), 1.6, "#8a7a4a", "#5a4a2a")
			var boat := _on(site, Vector3(2.6, 0.0, 2.2))
			var hull := _cyl(site, 0.38, 0.38, 3.4, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.7)), boat + Vector3(0, 0.22, 0)), "#4a3220", 0.45)
			hull.name = "Dugout"
			_cyl(site, 0.3, 0.3, 3.2, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.55)), boat + Vector3(0, 0.36, 0)), "#24180e", 0.8)
			var line := _on(site, Vector3(-2.6, 0.0, 1.2))
			_rod(site, line, line + Vector3(0, 1.7, 0), 0.035, 0.03, "#5a4a2a")
			_rod(site, line + Vector3(0, 0, 2.2), line + Vector3(0, 1.7, 2.2), 0.035, 0.03, "#5a4a2a")
			_rod(site, line + Vector3(0, 1.62, 0), line + Vector3(0, 1.62, 2.2), 0.01, 0.01, "#b8a878")
			for i in 6:
				var fish := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.06
				sp.height = 0.32
				sp.radial_segments = 6
				sp.rings = 3
				fish.mesh = sp
				fish.material_override = _mat("#a8c0d8", 0.15)
				fish.position = line + Vector3(0, 1.45, 0.25 + i * 0.32)
				site.add_child(fish)
			_basket(site, _on(site, Vector3(-1.2, 0.0, -1.2)))
			var trap := _cyl(site, 0.0, 0.32, 0.9, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), _on(site, Vector3(0.6, 0.25, 2.8))), "#9a8a5a", 0.8)
			trap.name = "FishTrap"
		"woodcutter_firekeeper":
			# A bark lean-to, felled trunks with an axe bitten in, stumps,
			# kindling bundles and a carried-fire pot (the firekeeper's ember).
			_lean_to(site, _on(site, Vector3(0.0, 0.0, 4.0)), "#3e2a1a", "#5a4026")
			var log_at := _on(site, Vector3(2.8, 0.0, 2.0))
			_rod(site, log_at + Vector3(-1.8, 0.3, 0), log_at + Vector3(1.8, 0.3, 0.3), 0.3, 0.26, "#5a3e24", 0.7, true)
			_rod(site, log_at + Vector3(0.4, 0.55, 0.1), log_at + Vector3(0.5, 1.1, 0.1), 0.025, 0.025, "#8a6a48")
			_block(site, Vector3(0.05, 0.16, 0.2), Transform3D(Basis.IDENTITY, log_at + Vector3(0.38, 0.55, 0.1)), "#2a2c3e", 0.15, false)
			for i in 3:
				var st := _on(site, Vector3(-3.0 + i * 1.3, 0.0, -1.5 + (i % 2) * 0.8))
				_cyl(site, 0.32, 0.36, 0.4, Transform3D(Basis.IDENTITY, st + Vector3(0, 0.15, 0)), "#5a3e24", 0.7)
				_cyl(site, 0.3, 0.3, 0.02, Transform3D(Basis.IDENTITY, st + Vector3(0, 0.36, 0)), "#b8945a", 0.6)
			for i in 3:
				var b := _on(site, Vector3(-2.6, 0.0, 2.8 + i * 0.4))
				for k in 5:
					_rod(site, b + Vector3(-0.4, 0.1 + (k % 2) * 0.06, -0.1 + k * 0.05), b + Vector3(0.4, 0.1 + (k % 2) * 0.06, -0.1 + k * 0.05), 0.03, 0.03, "#6b4a2e")
			var pot := _cyl(site, 0.16, 0.2, 0.3, Transform3D(Basis.IDENTITY, _on(site, Vector3(1.0, 0.15, 0.6))), "#7a4a32", 0.4)
			_cyl(site, 0.13, 0.13, 0.02, Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0)), "#ff7a1a", 0.3, 3.0).reparent(pot, false)
		"forager_herbalist":
			# A thatched hut, a garden bed of strange flowers (the frame's
			# purple and acid green), gourds on a line, a mortar on a stone.
			_hut(site, _on(site, Vector3(0.0, 0.0, 4.2)), 1.8, "#6a7a3a", "#3e4a26")
			var bed := _on(site, Vector3(2.8, 0.0, 1.6))
			_block(site, Vector3(2.2, 0.12, 1.4), Transform3D(Basis.IDENTITY, bed + Vector3(0, 0.02, 0)), "#2a1e16", 0.95, false)
			var flower_cols := ["#b24ad8", "#e04aa8", "#7cff4f", "#5a6aff", "#ffd84a"]
			for i in 18:
				var q := bed + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-0.6, 0.6))
				var h := rng.randf_range(0.25, 0.6)
				_rod(site, q, q + Vector3(0, h, 0), 0.012, 0.01, "#2f6b2a")
				var bloom := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = rng.randf_range(0.05, 0.1)
				sp.height = sp.radius * 1.6
				sp.radial_segments = 6
				sp.rings = 3
				bloom.mesh = sp
				var c := str(flower_cols[rng.randi_range(0, flower_cols.size() - 1)])
				bloom.material_override = _mat(c, 0.3, 0.6 if c == "#7cff4f" else 0.0)
				bloom.position = q + Vector3(0, h, 0)
				site.add_child(bloom)
			var line := _on(site, Vector3(-2.6, 0.0, 0.8))
			_rod(site, line, line + Vector3(0, 1.8, 0), 0.03, 0.03, "#4a3a28")
			_rod(site, line + Vector3(0, 0, 2.0), line + Vector3(0, 1.8, 2.0), 0.03, 0.03, "#4a3a28")
			_rod(site, line + Vector3(0, 1.75, 0), line + Vector3(0, 1.75, 2.0), 0.012, 0.012, "#8a7a4a")
			for i in 4:
				var g := MeshInstance3D.new()
				var sp2 := SphereMesh.new()
				sp2.radius = 0.12
				sp2.height = 0.34
				g.mesh = sp2
				g.material_override = _mat("#c8a24a", 0.3)
				g.position = line + Vector3(0, 1.48, 0.35 + i * 0.45)
				site.add_child(g)
			var mortar := _on(site, Vector3(-1.0, 0.0, -1.2))
			_block(site, Vector3(0.7, 0.35, 0.6), Transform3D(Basis.IDENTITY, mortar + Vector3(0, 0.15, 0)), "#4a4d6e", 0.3, false)
			_cyl(site, 0.16, 0.12, 0.16, Transform3D(Basis.IDENTITY, mortar + Vector3(0, 0.4, 0)), "#5a5a78", 0.25)
			_rod(site, mortar + Vector3(0, 0.42, 0), mortar + Vector3(0.1, 0.7, 0.05), 0.025, 0.02, "#d8cfa8")
		"knapper_potter":
			# A clay hut, the clay pit, pots set out to dry on a plank, a
			# knapping stone with flakes round it, the kiln's smoke.
			_hut(site, _on(site, Vector3(1.0, 0.0, 4.4)), 1.7, "#8a5a3a", "#5a3a24")
			var pit := _on(site, Vector3(2.8, 0.0, 1.2))
			_cyl(site, 0.9, 1.0, 0.1, Transform3D(Basis.IDENTITY, pit + Vector3(0, 0.0, 0)), "#5a3420", 0.15)
			var plank := _on(site, Vector3(-2.6, 0.0, 0.0))
			_block(site, Vector3(0.4, 0.35, 2.4), Transform3D(Basis.IDENTITY, plank + Vector3(0, 0.18, 0)), "#5a3e24", 0.6)
			for i in 5:
				var h := rng.randf_range(0.2, 0.42)
				_cyl(site, rng.randf_range(0.1, 0.16), rng.randf_range(0.07, 0.12), h, Transform3D(Basis.IDENTITY, plank + Vector3(0, 0.35 + h * 0.5, -0.9 + i * 0.45)), "#b8805a", 0.4)
			var knap := _on(site, Vector3(0.9, 0.0, -1.3))
			_block(site, Vector3(0.6, 0.3, 0.5), Transform3D(Basis.IDENTITY, knap + Vector3(0, 0.12, 0)), "#4a4d6e", 0.3, false)
			for i in 8:
				_block(site, Vector3(0.08, 0.02, 0.06), Transform3D(Basis(Vector3.UP, i * 0.8), knap + Vector3(cos(i * 0.8) * 0.5, 0.01, sin(i * 0.8) * 0.5)), "#1a1c2a", 0.1, false)
			var smoke := _wisp(Color(0.5, 0.5, 0.6, 0.3), 0.4, 60)
			smoke.position = _on(site, Vector3(-2.0, 1.4, 1.6))
			site.add_child(smoke)


## A torch post: a stake with a burning head (the one amber, §EX.6).
func _torch_post(site: Node3D, at: Vector3) -> void:
	_rod(site, at, at + Vector3(0, 1.7, 0), 0.04, 0.035, "#4a3220", 0.6)
	var head := _cyl(site, 0.06, 0.07, 0.16, Transform3D(Basis.IDENTITY, at + Vector3(0, 1.75, 0)), "#ff9a3a", 0.3, 4.0)
	head.name = "TorchHead"
	var l := OmniLight3D.new()
	l.name = "TorchLight"
	l.light_color = Torch.fire_color()
	l.light_energy = float((H.get("keepers", {}) as Dictionary).get("torch_energy", 0.9))
	l.omni_range = float((H.get("keepers", {}) as Dictionary).get("torch_range_m", 6.0))
	l.position = at + Vector3(0, 2.0, 0)
	site.add_child(l)


## A hide tent: a ring of poles leaning in, covered by a cone.
func _tent(site: Node3D, at: Vector3, r: float, h: float, hide: String, pole: String) -> void:
	var c := _cyl(site, r, 0.08, h, Transform3D(Basis.IDENTITY, at + Vector3(0, h * 0.5, 0)), hide, 0.7)
	c.name = "Tent"
	var body := PropCollision.body(site)
	PropCollision.capsule(body, Transform3D(Basis.IDENTITY, at + Vector3(0, h * 0.5, 0)), r * 0.85, h)
	for i in 5:
		var a := TAU * i / 5.0
		_rod(site, at + Vector3(cos(a) * r * 0.95, 0, sin(a) * r * 0.95), at + Vector3(cos(a) * 0.15, h + 0.5, sin(a) * 0.15), 0.03, 0.025, pole)
	_block(site, Vector3(0.6, 1.0, 0.05), Transform3D(Basis.IDENTITY, at + Vector3(0, 0.5, -r * 0.62)), "#120c0a", 0.9, false)


## A round hut: a low wall and a thatched cone roof.
func _hut(site: Node3D, at: Vector3, r: float, roof: String, wall: String) -> void:
	_cyl(site, r, r, 1.3, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.65, 0)), wall, 0.8)
	var rf := _cyl(site, r + 0.45, 0.05, 1.6, Transform3D(Basis.IDENTITY, at + Vector3(0, 2.05, 0)), roof, 0.85)
	rf.name = "Roof"
	var body := PropCollision.body(site)
	PropCollision.capsule(body, Transform3D(Basis.IDENTITY, at + Vector3(0, 1.0, 0)), r, 2.0)
	_block(site, Vector3(0.7, 1.05, 0.05), Transform3D(Basis.IDENTITY, at + Vector3(0, 0.52, -r - 0.01)), "#120c0a", 0.9, false)


## A bark lean-to: two forked posts, a ridge pole, a sloped bark roof.
func _lean_to(site: Node3D, at: Vector3, bark: String, pole: String) -> void:
	_rod(site, at + Vector3(-1.4, 0, -0.8), at + Vector3(-1.4, 1.9, -0.8), 0.06, 0.05, pole, 0.6, true)
	_rod(site, at + Vector3(1.4, 0, -0.8), at + Vector3(1.4, 1.9, -0.8), 0.06, 0.05, pole, 0.6, true)
	_rod(site, at + Vector3(-1.6, 1.85, -0.8), at + Vector3(1.6, 1.85, -0.8), 0.05, 0.05, pole)
	_block(site, Vector3(3.2, 0.06, 2.4), Transform3D(Basis(Vector3.RIGHT, -0.66), at + Vector3(0, 1.0, 0.1)), bark, 0.75)


## A totem: stacked carved blocks, a face slightly too big (§GB.2), and
## with `antlers` a skull and antlers on top.
func _totem(site: Node3D, at: Vector3, rng: RandomNumberGenerator, antlers: bool) -> void:
	var y := 0.0
	for i in 3:
		var h := rng.randf_range(0.6, 0.9)
		_block(site, Vector3(0.5, h, 0.45), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), at + Vector3(0, y + h * 0.5, 0)), ["#5a3e24", "#6b4a2e", "#4a3220"][i], 0.5, i == 0)
		_block(site, Vector3(0.12, 0.12, 0.05), Transform3D(Basis.IDENTITY, at + Vector3(-0.12, y + h * 0.65, -0.24)), "#d8cfa8", 0.3, false)
		_block(site, Vector3(0.12, 0.12, 0.05), Transform3D(Basis.IDENTITY, at + Vector3(0.12, y + h * 0.65, -0.24)), "#d8cfa8", 0.3, false)
		y += h
	if antlers:
		var sk := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.2
		sp.height = 0.34
		sk.mesh = sp
		sk.material_override = _mat("#d8cfa8", 0.3)
		sk.position = at + Vector3(0, y + 0.15, 0)
		site.add_child(sk)
		for side in [-1.0, 1.0]:
			var base := at + Vector3(side * 0.15, y + 0.28, 0)
			var tip := base + Vector3(side * 0.6, 0.7, 0)
			_rod(site, base, tip, 0.03, 0.015, "#d8cfa8", 0.4)
			_rod(site, base.lerp(tip, 0.5), base.lerp(tip, 0.5) + Vector3(side * 0.05, 0.35, -0.15), 0.02, 0.01, "#d8cfa8", 0.4)


func _wisp(col: Color, size: float, amount: int) -> CPUParticles3D:
	var w := CPUParticles3D.new()
	w.amount = amount
	w.lifetime = 5.0
	w.direction = Vector3.UP
	w.spread = 10.0
	w.gravity = Vector3(0.1, 0.25, 0.0)
	w.initial_velocity_min = 0.2
	w.initial_velocity_max = 0.4
	w.scale_amount_min = 0.6
	w.scale_amount_max = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = col
	q.material = sm
	w.mesh = q
	return w


## The camp's common ground: log benches round the fire, worn paths from
## it to every keeper's site, and a few totems at the clearing's edge.
func _common(rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Common"
	add_child(root)
	var fp: Vector3 = camp.pos
	var n: Vector2 = stair.n
	var base_a := atan2(n.y, n.x)
	# Benches: logs on the arc facing the fire, leaving the stair's side
	# and the spawn's line open.
	for i in 4:
		var a := base_a + PI * 0.5 + (i - 1.5) * 0.55 + (PI if i >= 2 else 0.0) * 0.0
		a = base_a + [1.25, 1.85, -1.25, -1.85][i]
		var c := Vector2(fp.x, fp.z) + Vector2(cos(a), sin(a)) * 3.4
		var g := _ground_at(c)
		var t := Vector2(-sin(a), cos(a))
		_rod(root, g + Vector3(-t.x, 0.22, -t.y) * 1.0 + Vector3(0, 0.22, 0) * 0.0, g + Vector3(t.x, 0.22, t.y) * 1.0, 0.22, 0.2, "#5a3e24", 0.65, true)
	# Paths: stepping stones from the fire to each site (a solid strip
	# read as a black slab under the grade, 26 Oct).
	var C: Dictionary = H.get("common", {})
	var step := float(C.get("step_m", 1.3))
	for st in sites:
		var a3: Vector3 = st.at
		var from := Vector2(fp.x, fp.z)
		var to := Vector2(a3.x, a3.z)
		var d := to - from
		var len := d.length()
		var side := Vector2(-d.y, d.x).normalized()
		var k := 4.2
		while k < len - 1.6:
			var t := k / len
			var c := from + d * t + side * (sin(t * PI) * len * 0.08 + rng.randf_range(-0.15, 0.15))
			var g := _ground_at(c)
			_block(root, Vector3(rng.randf_range(0.5, 0.75), 0.1, rng.randf_range(0.4, 0.6)), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), g + Vector3(0, 0.02, 0)), str(C.get("stone_color", "#6a6c8a")), 0.25, false)
			k += step
	# Totems at the clearing's edge.
	for i in int((H.get("common", {}) as Dictionary).get("totems", 3)):
		var p := _free_spot(rng, [], 9.0, 16.0, 2.0)
		if p == Vector2.INF:
			continue
		var holder := Node3D.new()
		holder.position = _ground_at(p)
		root.add_child(holder)
		_totem(holder, Vector3.ZERO, rng, i == 0)


## A drying rack: two posts and a crossbar, hung with `hang` (hides as flat
## slabs, or bundles as knots).
func _rack(parent: Node3D, at: Vector3, wood: String, hang: String, hides: bool) -> void:
	var a := at + Vector3(-0.9, 0.0, 0.0)
	var b := at + Vector3(0.9, 0.0, 0.0)
	_rod(parent, a - Vector3(0.0, 0.2, 0.0), a + Vector3(0.0, 1.8, 0.0), 0.05, 0.045, wood, 0.6, true)
	_rod(parent, b - Vector3(0.0, 0.2, 0.0), b + Vector3(0.0, 1.8, 0.0), 0.05, 0.045, wood, 0.6, true)
	_rod(parent, a + Vector3(0.0, 1.7, 0.0), b + Vector3(0.0, 1.7, 0.0), 0.04, 0.04, wood, 0.6)
	for i in 3:
		var x := -0.55 + i * 0.55
		if hides:
			_block(parent, Vector3(0.45, 0.9, 0.03), Transform3D(Basis(Vector3.UP, 0.05 * i), at + Vector3(x, 1.2, 0.0)), hang, 0.7, false)
		else:
			var mi := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.14
			sp.height = 0.45
			sp.radial_segments = 6
			sp.rings = 3
			mi.mesh = sp
			mi.material_override = _mat(hang, 0.6)
			mi.position = at + Vector3(x, 1.45, 0.0)
			parent.add_child(mi)


func _basket(parent: Node3D, at: Vector3) -> void:
	_cyl(parent, 0.22, 0.3, 0.32, Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.16, 0.0)), "#8a6a3a", 0.8)


## A clay kiln: a dome with a glowing mouth (fire's own amber, §EX.6).
func _kiln(parent: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.85
	sp.height = 1.3
	sp.is_hemisphere = true
	mi.mesh = sp
	mi.material_override = _mat("#7a4a32", 0.5)
	mi.position = at
	parent.add_child(mi)
	var body := PropCollision.body(mi)
	PropCollision.capsule(body, Transform3D.IDENTITY, 0.8, 1.6)
	var mouth := _cyl(parent, 0.22, 0.22, 0.05, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0.0, 0.25, 0.8)), "#ff7a1a", 0.3, 2.5)
	mouth.name = "KilnMouth"
	var l := OmniLight3D.new()
	l.light_color = Torch.fire_color()
	l.light_energy = 0.6
	l.omni_range = 3.0
	l.position = at + Vector3(0.0, 0.3, 1.1)
	parent.add_child(l)
