class_name AroidGarden
extends Node
## The Amorphophallus near the player, living their real lives (design 29
## Sept 2026, docs/design/AROID_LIFE.md; AroidLife for the timeline,
## PlantGenetics for genomes and crosses).
##
## The plants themselves are placed like any undergrowth (VegetationPlacer:
## one MultiMesh per species per chunk, the umbrella stand-in for the
## leaf). For each of those in the chunks round the player (the detail
## ring), this keeps the original buffer and, every UPDATE_S, writes the
## MultiMesh a new one: each plant's leaf hidden while its tuber rests
## underground, spreading as it unfurls, collapsing as it dies back. Next
## to them, in their chunk's frame, one MultiMesh per passing part
## (AroidMeshes, shaders/aroid_part.gdshader): the cataphyll-wrapped shoot
## spike, the inflorescence bud, the peduncle, the spathe (outside and
## inside colours), the appendix, the pollen once the male phase comes, the
## berries ripening from unripe to ripe; wilting spathes; twin blooms and
## colour-morph spathes for those sports.
## Scent and pollinators: an open bloom in its scent phase draws its own
## pollinators (the species' cycle.bloom.pollinators: carrion beetles, rove
## beetles, blowflies, stingless bees... creatures.json, spawn "bloom") as
## small clouds round the spathe, and the player downwind (or close)
## smells it once: "A stench of rotting meat hangs on the wind."
## Crosses: the female phase comes first, so a bloom takes pollen from
## another plant: when two plants of one species (or a documented hybrid
## pair) are in bloom within POLLEN_M of each other with the donor's pollen
## out while the other is receptive, the cross is real: that bloom sets
## fruit (AroidLife's override) and its seeds are the cross of the two
## genomes (sample_extra()). Blooms nobody sees are rolled (AroidLife).
## Nothing is stored beyond this session.

const SCAN_S := 1.0
const UPDATE_S := 2.0
## Work per frame (microseconds): the plants are stepped a few at a time
## so a rainforest full of aroids never stalls a frame.
const BUDGET_US := 1500
## Blooms this near the player get their pollinators; at most this many
## clouds at once.
const SWARM_M := 110.0
const MAX_SWARMS := 8
## How far pollinators carry pollen between blooms (m).
const POLLEN_M := 400.0
## Hidden: a leaf scaled to this (the shader needs an invertible matrix).
const HIDDEN := 0.002
## How far the scent carries (m) by kind, before heat and genes.
const SCENT_M := {"carrion": 160.0, "gas": 140.0, "dung": 110.0, "cheese": 90.0, "fish": 110.0,
	"musky": 50.0, "fruity": 60.0, "sweet": 45.0, "spicy": 45.0, "none": 0.0}
const SCENT_WORDS := {
	"carrion": "A stench of rotting meat hangs on the wind.",
	"gas": "A whiff of rotten eggs and gas drifts on the wind.",
	"dung": "The wind carries a smell of dung.",
	"cheese": "Something on the wind smells of old cheese and sweat.",
	"fish": "A smell of rotting fish drifts past.",
	"sweet": "A sweet scent drifts on the air.",
	"fruity": "A smell of fermenting fruit drifts on the air.",
	"spicy": "A spicy scent drifts on the air.",
	"musky": "A musky smell hangs in the air.",
}
const PATTERN_MODE := {"plain": 0.0, "mottled": 1.0, "spotted": 2.0, "streaked": 3.0, "lichen": 4.0, "warty": 5.0}
const PARTS := ["spike", "bud", "peduncle", "spathe", "appendix", "pollen", "berries"]

## The one garden (LookTarget and main ask it about plants).
static var instance: AroidGarden

var world: Node
var chunks: ChunkManager
var player: Node3D
var creatures: CreatureSpawner
## main's note (a line near the bottom of the screen for a few seconds).
var say: Callable

var _entries := {} # MultiMeshInstance3D id -> entry (see _add)
var _donors := {} # plant key -> {event: donor genome}
var _swarms := {} # "key:event" -> Array of Creature
var _smelled := {} # "key:event" -> true
var _scan_t := 0.0
var _upd_t := 0.0
# The pass under way: entry ids still to do, the one being stepped (its
# plant index, new leaf buffer and part lists), and the open blooms found.
var _todo: Array = []
var _work := {}
var _blooms := []
var _mat: ShaderMaterial


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D, p_creatures: CreatureSpawner) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	creatures = p_creatures
	instance = self
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/aroid_part.gdshader")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if world == null:
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_S
		_scan()
	_upd_t -= delta
	if _todo.is_empty() and _work.is_empty():
		if _upd_t <= 0.0:
			_upd_t = UPDATE_S
			_todo = _entries.keys()
			_blooms = []
	if not _todo.is_empty() or not _work.is_empty():
		_step(BUDGET_US)


## Is plant `k` of the undergrowth MultiMesh `mmi_id` out of sight (its
## tuber resting, or only a spike up)? LookTarget doesn't name it then.
static func hides(mmi_id: int, k: int) -> bool:
	if instance == null or not instance._entries.has(mmi_id):
		return false
	var e: Dictionary = instance._entries[mmi_id]
	var vis: PackedByteArray = e.vis
	return k < vis.size() and vis[k] == 0 and e.shown[k] == 0


## A few words on where plant `k` is in its life, for the HUD ("in bloom,
## female phase", "in fruit, ripening", "shoot coming up"), or "".
static func describe(mmi_id: int, k: int) -> String:
	if instance == null or not instance._entries.has(mmi_id):
		return ""
	var e: Dictionary = instance._entries[mmi_id]
	var states: Array = e.states
	if k >= states.size() or states[k] == null:
		return ""
	var st: Dictionary = states[k]
	match str(st.flower):
		"bud":
			return "in bud"
		"bloom":
			if st.male:
				return "in bloom, shedding pollen"
			return "in bloom, receptive" if st.female else "in bloom"
		"wilt":
			return "bloom withering"
		"fruit":
			return "in fruit, ripe" if float(st.flower_t) > 0.85 else "in fruit, ripening"
	match str(st.leaf):
		"shoot":
			return "shoot coming up"
		"unfurl":
			return "leaf unfurling"
		"senesce":
			return "dying back"
	return ""


# --- Tracking the plants -----------------------------------------------------

func _scan() -> void:
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		if not is_instance_valid(e.mmi) or e.mmi.multimesh == null:
			_drop(id)
	for c in chunks.chunks.values():
		var chunk := c as TerrainChunk
		if chunk == null or chunk.detail_node == null or not is_instance_valid(chunk.detail_node):
			continue
		for ch in chunk.detail_node.get_children():
			var mmi := ch as MultiMeshInstance3D
			if mmi == null or not mmi.has_meta("species") or _entries.has(mmi.get_instance_id()):
				continue
			var sp: PlantSpecies = SpeciesDB.all()[int(mmi.get_meta("species"))]
			if sp.cycle.is_empty() or mmi.multimesh == null or mmi.multimesh.instance_count == 0:
				continue
			_add(mmi, chunk, sp)


func _add(mmi: MultiMeshInstance3D, chunk: TerrainChunk, sp: PlantSpecies) -> void:
	var mm := mmi.multimesh
	var n := mm.instance_count
	var base := mm.buffer
	var keys := PackedInt64Array()
	var clumps := PackedInt64Array()
	var dirs := PackedVector3Array()
	var lats := PackedFloat32Array()
	var lons := PackedFloat32Array()
	var sports := PackedInt32Array()
	for i in n:
		var j := i * 20
		var local := Vector3(base[j + 3], base[j + 7], base[j + 11])
		var d := (chunk.center_dir * chunk.anchor_radius + local).normalized()
		dirs.append(d)
		keys.append(PlantGenetics.key_of(sp.name, d, false))
		clumps.append(PlantGenetics.key_of(sp.name, d, sp.clonal))
		lats.append(CubeSphere.latitude(d))
		lons.append(CubeSphere.longitude(d))
		sports.append(PlantGenetics.decode_sport(base[j + 16]))
	var holder := Node3D.new()
	holder.name = "AroidParts_" + sp.name.replace(" ", "_")
	chunk.detail_node.add_child(holder)
	var parts := {}
	for p in PARTS:
		var pm := MultiMesh.new()
		pm.transform_format = MultiMesh.TRANSFORM_3D
		pm.use_colors = true
		pm.use_custom_data = true
		pm.mesh = AroidMeshes.get_mesh(p)
		var pmi := MultiMeshInstance3D.new()
		pmi.multimesh = pm
		pmi.material_override = _mat
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(pmi)
		parts[p] = pmi
	var vis := PackedByteArray()
	vis.resize(n)
	vis.fill(1)
	var shown := PackedByteArray()
	shown.resize(n)
	var states := []
	states.resize(n)
	_entries[mmi.get_instance_id()] = {"mmi": mmi, "chunk": chunk, "sp": sp, "n": n, "base": base,
		"keys": keys, "clumps": clumps, "dirs": dirs, "lat": lats, "lon": lons, "sport": sports,
		"genomes": {}, "vis": vis, "shown": shown, "states": states, "holder": holder, "parts": parts}
	_upd_t = 0.0


func _drop(id: int) -> void:
	var e: Dictionary = _entries[id]
	for k in e.keys:
		for sk in _swarms.keys():
			if str(sk).begins_with("%d:" % k):
				_end_swarm(sk)
	if is_instance_valid(e.holder):
		e.holder.queue_free()
	_entries.erase(id)


## A plant's genome (its clump's: PlantGenetics.wild_genome), cached.
func genome_of(e: Dictionary, i: int) -> Dictionary:
	var g: Dictionary = e.genomes
	if not g.has(i):
		g[i] = PlantGenetics.wild_genome(e.sp, e.clumps[i], e.dirs[i], e.sport[i])
	return g[i]


# --- The update ---------------------------------------------------------------

## A whole pass at once (tools and tests).
func update_now() -> void:
	_todo = _entries.keys()
	_work = {}
	_blooms = []
	_step(1 << 40)


## Step the pass for up to `budget_us`: plant by plant through the
## entries; each entry's buffers go to its MultiMeshes when it's done, and
## the crosses and pollinators when the pass is.
func _step(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	var days: float = world.days
	while Time.get_ticks_usec() - t0 < budget_us:
		if _work.is_empty():
			if _todo.is_empty():
				_cross(_blooms)
				_pollinators(_blooms)
				return
			var id: int = _todo.pop_back()
			if not _entries.has(id):
				continue
			var e: Dictionary = _entries[id]
			if not is_instance_valid(e.mmi) or e.mmi.multimesh == null:
				_drop(id)
				continue
			_work = _begin(e)
		var w := _work
		var we: Dictionary = w.e
		if int(w.i) >= int(we.n):
			_commit(w)
			_work = {}
			continue
		_plant_step(w, int(w.i), days, _blooms)
		w.i = int(w.i) + 1


func _col(hex, fallback: Color) -> Color:
	var c := Color.from_string(str(hex), fallback) if hex != null else fallback
	return c.srgb_to_linear()


## The colours and sizes one species' parts share, and a fresh leaf
## buffer and part lists, for stepping entry `e`.
func _begin(e: Dictionary) -> Dictionary:
	var sp: PlantSpecies = e.sp
	var base: PackedFloat32Array = e.base
	var cur := base.duplicate()
	var cy := sp.cycle
	var shoot: Dictionary = cy.get("shoot", {})
	var bud: Dictionary = cy.get("bud", {})
	var fr: Dictionary = cy.get("fruit", {})
	var cat: Dictionary = shoot.get("cataphylls", {})
	var bcat: Dictionary = bud.get("cataphylls", {})
	var pet: Dictionary = sp.aroid.get("petiole", {})
	var spa: Dictionary = sp.aroid.get("spathe", {})
	var cat_c := _col(cat.get("colour"), Color(0.55, 0.5, 0.4))
	var cat_c2 := _col(cat.get("markings"), cat_c.darkened(0.4))
	var cat_m := float(PATTERN_MODE.get(str(cat.get("pattern", "plain")), 0.0))
	var bud_c := _col(bcat.get("colour"), cat_c)
	var bud_c2 := _col(bcat.get("markings"), bud_c.darkened(0.4))
	var bud_m := float(PATTERN_MODE.get(str(bcat.get("pattern", "plain")), 0.0))
	var ped_c := _col(pet.get("base"), Color(0.35, 0.45, 0.3))
	var ped_c2 := _col(pet.get("spots"), ped_c.lightened(0.4))
	var ped_m := float(PATTERN_MODE.get(str(pet.get("pattern", "mottled")), 1.0))
	var sp_out := _col(spa.get("outside"), Color(0.45, 0.2, 0.25))
	var sp_in := _col(spa.get("inside"), Color(0.3, 0.05, 0.1))
	var app_c := _col(sp.flower.get("spadix"), Color(0.88, 0.84, 0.55))
	var fr_u := _col(fr.get("unripe"), Color(0.4, 0.6, 0.25))
	var fr_r := _col(fr.get("ripe"), Color(0.85, 0.15, 0.1))
	var ped_cm = bud.get("peduncle_cm", [10, 30])
	var ped_mean := (float(ped_cm[0]) + float(ped_cm[1])) * 0.005 if ped_cm is Array and ped_cm.size() == 2 else 0.2
	var twin := PlantGenetics.code_of("twin_inflorescence")
	var morph := PlantGenetics.code_of("colour_morph_flower")
	var lists := {}
	for p in PARTS:
		lists[p] = PackedFloat32Array()
	return {"e": e, "i": 0, "cur": cur, "lists": lists, "cat_c": cat_c, "cat_c2": cat_c2, "cat_m": cat_m,
		"bud_c": bud_c, "bud_c2": bud_c2, "bud_m": bud_m, "ped_c": ped_c, "ped_c2": ped_c2, "ped_m": ped_m,
		"sp_out": sp_out, "sp_in": sp_in, "app_c": app_c, "fr_u": fr_u, "fr_r": fr_r, "ped_mean": ped_mean,
		"twin": twin, "morph": morph}


## One plant of the entry being stepped: its state, its leaf in the new
## buffer, its parts in the lists, its bloom (if open) for the crosses.
func _plant_step(w: Dictionary, i: int, days: float, blooms: Array) -> void:
	var e: Dictionary = w.e
	var sp: PlantSpecies = e.sp
	var base: PackedFloat32Array = e.base
	var cur: PackedFloat32Array = w.cur
	var lists: Dictionary = w.lists
	var cat_c: Color = w.cat_c
	var cat_c2: Color = w.cat_c2
	var cat_m: float = w.cat_m
	var bud_c: Color = w.bud_c
	var bud_c2: Color = w.bud_c2
	var bud_m: float = w.bud_m
	var ped_c: Color = w.ped_c
	var ped_c2: Color = w.ped_c2
	var ped_m: float = w.ped_m
	var sp_out: Color = w.sp_out
	var sp_in: Color = w.sp_in
	var app_c: Color = w.app_c
	var fr_u: Color = w.fr_u
	var fr_r: Color = w.fr_r
	var ped_mean: float = w.ped_mean
	var twin: int = w.twin
	var morph: int = w.morph
	var vis: PackedByteArray = e.vis
	var shown: PackedByteArray = e.shown
	var states: Array = e.states
	var mmi: MultiMeshInstance3D = e.mmi
	var chunk_xf: Transform3D = mmi.global_transform
	if true:
		var j := i * 20
		var gx := Vector3(base[j], base[j + 4], base[j + 8])
		var gy := Vector3(base[j + 1], base[j + 5], base[j + 9])
		var gz := Vector3(base[j + 2], base[j + 6], base[j + 10])
		var o := Vector3(base[j + 3], base[j + 7], base[j + 11])
		var h := gy.length()
		var up := gy / maxf(h, 1e-4)
		var side := gx.normalized()
		var fwd := gz.normalized()
		var key: int = e.keys[i]
		var gen := genome_of(e, i)
		var ov: Dictionary = _donors.get(key, {})
		var fert := PlantGenetics.fertility(gen, gen)
		var st := AroidLife.state(sp, key, e.lat[i], e.lon[i], days, ov, fert)
		states[i] = st
		# The leaf.
		var sx := HIDDEN
		var sy := HIDDEN
		match str(st.leaf):
			"unfurl":
				var t := float(st.leaf_t)
				sy = lerpf(0.85, 1.0, t)
				sx = lerpf(0.12, 1.0, t * t * (3.0 - 2.0 * t))
			"leaf":
				sx = 1.0
				sy = 1.0
			"senesce":
				var t2 := float(st.leaf_t)
				sy = lerpf(1.0, 0.25, t2)
				sx = lerpf(1.0, 0.6, t2)
		vis[i] = 1 if sx > HIDDEN else 0
		var nx := gx * sx
		var ny := gy * sy
		var nz := gz * sx
		cur[j] = nx.x
		cur[j + 4] = nx.y
		cur[j + 8] = nx.z
		cur[j + 1] = ny.x
		cur[j + 5] = ny.y
		cur[j + 9] = ny.z
		cur[j + 2] = nz.x
		cur[j + 6] = nz.y
		cur[j + 10] = nz.z
		# The shoot spike: the petiole's length, cataphyll-wrapped.
		var any_part := false
		if str(st.leaf) == "shoot":
			var sh := h * 0.72 * lerpf(0.06, 1.0, float(st.leaf_t))
			var r := maxf(0.008, h * 0.03)
			_emit(lists.spike, side * r, up * sh, fwd * r, o, cat_c, cat_c2, cat_m)
			any_part = true
		# The inflorescence.
		var fl := str(st.flower)
		if fl != "":
			any_part = true
			var dims := bloom_dims(h)
			var s_len: float = dims.x
			var a_len: float = dims.y
			var a_r: float = dims.z
			var ped := minf(ped_mean, maxf(h, 0.05))
			var at := o
			if str(st.leaf) != "dormant":
				at += side * maxf(0.06, h * 0.09)
			var n_heads := 2 if int(e.sport[i]) == twin else 1
			var so := sp_out
			var si := sp_in
			if int(e.sport[i]) == morph:
				so = Color.from_hsv(fposmod(sp_out.h + 0.45, 1.0), sp_out.s * 0.6, minf(sp_out.v * 1.6 + 0.1, 1.0))
				si = Color.from_hsv(fposmod(sp_in.h + 0.45, 1.0), sp_in.s * 0.6, minf(sp_in.v * 1.6 + 0.1, 1.0))
			for head in n_heads:
				var hp := at + side * (s_len * 0.9 * float(head))
				var t3 := float(st.flower_t)
				match fl:
					"bud":
						var grow := lerpf(0.15, 1.0, t3)
						if ped > 0.02:
							_emit(lists.peduncle, side * s_len * 0.07, up * ped * t3, fwd * s_len * 0.07, hp, ped_c, ped_c2, ped_m)
						_emit(lists.bud, side * s_len * 0.3 * grow, up * s_len * 1.1 * grow, fwd * s_len * 0.3 * grow, hp + up * ped * t3, bud_c, bud_c2, bud_m)
					"bloom":
						var open := clampf(float(st.open_h) / 3.0, 0.0, 1.0)
						var ok_ := lerpf(0.35, 1.0, open * open * (3.0 - 2.0 * open))
						if ped > 0.02:
							_emit(lists.peduncle, side * s_len * 0.07, up * ped, fwd * s_len * 0.07, hp, ped_c, ped_c2, ped_m)
						var top := hp + up * ped
						_emit(lists.spathe, side * s_len * 0.42 * ok_, up * s_len, fwd * s_len * 0.42 * ok_, top, so, si, 10.0)
						# The appendix rises from the spathe's foot, out past its
						# rim to twice its height.
						_emit(lists.appendix, side * a_r, up * a_len, fwd * a_r, top + up * s_len * 0.05, app_c, app_c, 0.0)
						if st.male:
							_emit(lists.pollen, side * s_len * 0.15, up * s_len * 0.05, fwd * s_len * 0.15, top + up * s_len * 0.14, Color(0.95, 0.8, 0.25).srgb_to_linear(), Color.BLACK, 12.0)
					"wilt":
						var k := 1.0 - t3
						if ped > 0.02:
							_emit(lists.peduncle, side * s_len * 0.07, up * ped, fwd * s_len * 0.07, hp, ped_c.darkened(0.3 * t3), ped_c2, ped_m)
						var top2 := hp + up * ped
						var lean := Basis(fwd, 0.9 * t3)
						_emit(lists.spathe, side * s_len * 0.42 * lerpf(1.0, 0.55, t3), up * s_len * lerpf(1.0, 0.45, t3), fwd * s_len * 0.42 * lerpf(1.0, 0.55, t3), top2, so.darkened(0.5 * t3), si.darkened(0.5 * t3), 10.0)
						_emit(lists.appendix, lean * (side * a_r), lean * (up * a_len * lerpf(1.0, 0.7, t3)), lean * (fwd * a_r), top2 + up * s_len * 0.05, app_c.darkened(0.45 * (1.0 - k)), app_c, 0.0)
					"fruit":
						var pl := ped * lerpf(1.0, 1.35, t3)
						if ped > 0.02:
							_emit(lists.peduncle, side * s_len * 0.07, up * pl, fwd * s_len * 0.07, hp, ped_c, ped_c2, ped_m)
						var ripe := smoothstep(0.45, 1.0, t3)
						var bc := fr_u.lerp(fr_r, ripe)
						_emit(lists.berries, side * s_len * 0.16, up * maxf(s_len * 0.45, 0.02), fwd * s_len * 0.16, hp + up * pl, bc, bc, 11.0)
			if fl == "bloom":
				blooms.append([e, i, st, chunk_xf * (at + up * (ped + s_len * 0.8))])
		shown[i] = 1 if any_part else 0
		w.cur = cur
		for p in PARTS:
			w.lists[p] = lists[p]


## An entry done: its leaf buffer and its parts to their MultiMeshes.
func _commit(w: Dictionary) -> void:
	var e: Dictionary = w.e
	if not is_instance_valid(e.mmi) or e.mmi.multimesh == null:
		return
	e.mmi.multimesh.buffer = w.cur
	for p in PARTS:
		var pmi: MultiMeshInstance3D = e.parts[p]
		if not is_instance_valid(pmi):
			continue
		var buf: PackedFloat32Array = w.lists[p]
		var pm := pmi.multimesh
		# NodeRelease nulls every MultiMesh under a detail node it lets go.
		if pm == null:
			continue
		pm.instance_count = buf.size() / 20
		if buf.size() > 0:
			pm.buffer = buf
		pmi.visible = buf.size() > 0


## An open inflorescence's sizes for a plant `h` tall: the spathe's height,
## the appendix's length (twice it, from the spathe's foot: the titan arum's
## 3 m spike over its 1.3 m spathe) and the appendix's radius (m).
static func bloom_dims(h: float) -> Vector3:
	var s_len := clampf(h * 0.28, 0.03, 1.5)
	return Vector3(s_len, clampf(s_len * 2.15, 0.05, 3.2), s_len * 0.11)


## One part instance: its basis columns (x, y, z: sizes built in), origin,
## main colour, second colour and mode (shaders/aroid_part.gdshader).
static func _emit(buf: PackedFloat32Array, x: Vector3, y: Vector3, z: Vector3, o: Vector3, c: Color, c2: Color, mode: float) -> void:
	buf.append_array([x.x, y.x, z.x, o.x, x.y, y.y, z.y, o.y, x.z, y.z, z.z, o.z,
		c.r, c.g, c.b, 1.0, c2.r, c2.g, c2.b, mode])


# --- Crosses ------------------------------------------------------------------

## Species that can cross with `sp` (itself and its documented hybrids).
static func _partners(sp: PlantSpecies) -> Array:
	var out := [sp.name]
	for h in sp.cycle.get("hybrids", []):
		if h is Dictionary:
			out.append(str(h.get("with", "")))
	return out


## Real crosses between the blooms in sight: a receptive bloom and another
## plant's pollen out, within POLLEN_M, and compatible.
func _cross(blooms: Array) -> void:
	for a in blooms:
		var sa: Dictionary = a[2]
		if not sa.female:
			continue
		var ea: Dictionary = a[0]
		var ka: int = ea.keys[a[1]]
		if _donors.get(ka, {}).has(sa.event):
			continue
		var ok_names := _partners(ea.sp)
		for b in blooms:
			if b == a:
				continue
			var eb: Dictionary = b[0]
			var sb: Dictionary = b[2]
			if not sb.male or not (eb.sp.name in ok_names or ea.sp.name in _partners(eb.sp)):
				continue
			if eb.clumps[b[1]] == ea.clumps[a[1]] and ea.sp.cycle.get("bloom", {}).get("self_compatible", false) != true:
				continue # its own clone: self-pollen, which it rejects
			if (a[3] as Vector3).distance_to(b[3]) > POLLEN_M:
				continue
			if not _donors.has(ka):
				_donors[ka] = {}
			_donors[ka][sa.event] = genome_of(eb, b[1]).duplicate(true)
			_donors[ka][sa.event]["species"] = eb.sp.name
			break


## Seeds (or a sport's note) for a sample taken of plant species `sp_idx`
## at scene point `point`: {} when it's no aroid in sight. A fruiting
## plant's berries carry the cross: the mother and her donor (a real one
## seen, else one from her population), the seedling's ploidy, sport and
## genes (PlantGenetics.cross()).
func sample_extra(sp_idx: int, point: Vector3) -> Dictionary:
	var best := {}
	var best_i := -1
	var best_d := 2.5
	for id in _entries:
		var e: Dictionary = _entries[id]
		if SpeciesDB.index_of(e.sp) != sp_idx or not is_instance_valid(e.mmi):
			continue
		var xf: Transform3D = e.mmi.global_transform
		var base: PackedFloat32Array = e.base
		for i in int(e.n):
			var j := i * 20
			var p := xf * Vector3(base[j + 3], base[j + 7], base[j + 11])
			if p.distance_to(point) < best_d:
				best_d = p.distance_to(point)
				best = e
				best_i = i
	if best_i < 0:
		return {}
	var out := {}
	var gen := genome_of(best, best_i)
	if int(gen.sport) > 0:
		out["sport"] = PlantGenetics.label(int(gen.sport))
	out["ploidy"] = int(gen.ploidy)
	var st = best.states[best_i]
	if st is Dictionary and str(st.flower) == "fruit":
		var key: int = best.keys[best_i]
		var donor: Dictionary = _donors.get(key, {}).get(st.event, {})
		var seen := not donor.is_empty()
		if donor.is_empty():
			donor = PlantGenetics.wild_genome(best.sp, hash([key, st.event, "donor"]), best.dirs[best_i], 0)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([key, st.event, "seed"])
		var apo: bool = best.sp.cycle.get("bloom", {}).get("apomixis", false) == true
		var kid := PlantGenetics.cross(gen, donor, rng, apo)
		out["part"] = "berries"
		out["cross"] = "apomictic (the mother's clone)" if apo else ("%s x %s%s" % [PlantGenetics.describe(gen), PlantGenetics.describe(donor), " (a pollinator's)" if not seen else " (seen)"])
		out["seed"] = PlantGenetics.describe(kid)
		out["seed_ploidy"] = int(kid.ploidy)
		out["seed_sport"] = PlantGenetics.label(int(kid.sport))
		out["seed_genes"] = kid.genes
		out["ripe"] = float(st.flower_t) > 0.85
	return out


# --- Scent and pollinators ------------------------------------------------------

func _pollinators(blooms: Array) -> void:
	var pp: Vector3 = player.global_position
	var active := {}
	var wind: Vector3 = WeatherFX.plant_wind
	for b in blooms:
		var e: Dictionary = b[0]
		var st: Dictionary = b[2]
		var pos: Vector3 = b[3]
		var bl: Dictionary = e.sp.cycle.get("bloom", {})
		var fem_max := 24.0
		var fh = bl.get("female_hours", [12, 24])
		if fh is Array and fh.size() == 2:
			fem_max = float(fh[1])
		# The scent phase: the first night, while it's receptive and hot.
		if float(st.open_h) > fem_max + 10.0:
			continue
		var key: int = e.keys[b[1]]
		var sk := "%d:%d" % [key, int(st.event)]
		var dist := pos.distance_to(pp)
		# The smell, once, downwind or close.
		var kind := str(bl.get("scent", "none"))
		var gen := genome_of(e, b[1])
		var reach := float(SCENT_M.get(kind, 0.0)) * (1.4 if bl.get("thermogenic", false) == true else 1.0) * lerpf(0.7, 1.3, float(gen.genes.get("scent", 0.5)))
		if reach > 0.0 and dist < reach and not _smelled.has(sk):
			var downwind := wind.length() > 0.3 and (pp - pos).normalized().dot(wind.normalized()) > 0.3
			if dist < 15.0 or downwind:
				_smelled[sk] = true
				if say.is_valid():
					say.call(SCENT_WORDS.get(kind, "A strange smell drifts on the air."))
		if dist > SWARM_M:
			continue
		active[sk] = true
		if not _swarms.has(sk) and _swarms.size() < MAX_SWARMS:
			_start_swarm(sk, e, b[1], pos, bl)
	for sk in _swarms.keys():
		if not active.has(sk):
			_end_swarm(sk)


func _start_swarm(sk: String, e: Dictionary, i: int, pos: Vector3, bl: Dictionary) -> void:
	var guilds: Array = bl.get("pollinators", [])
	var picked := []
	for g in guilds:
		var name := _guild_species(str(g))
		if name != "" and not picked.has(name):
			picked.append(name)
		if picked.size() >= 2:
			break
	if picked.is_empty():
		picked.append("House flies")
	var list := []
	var d: Vector3 = world.dir_of(pos)
	var ground: float = chunks.ground_height(d)
	var h := pos.distance_to(world.to_scene(d, PlanetConst.RADIUS_M + ground))
	for n in picked:
		var cs := CreatureSpecies.find(n)
		if cs == null:
			continue
		var cr := Creature.new()
		creatures.adopt(cr)
		cr.setup(cs, world, chunks, creatures, d, hash([sk, n]))
		cr.drift_m = clampf(h * 0.35, 0.3, 1.8)
		for p in cr.find_children("*", "CPUParticles3D", true, false):
			(p as CPUParticles3D).position.y = h
			(p as CPUParticles3D).emission_sphere_radius = clampf(h * 0.3, 0.12, 1.2)
		list.append(cr)
	_swarms[sk] = list


func _end_swarm(sk) -> void:
	for cr in _swarms.get(sk, []):
		if is_instance_valid(cr):
			(cr as Creature).leave()
	_swarms.erase(sk)


## The creature (creatures.json, spawn "bloom") for a pollinator guild.
static func _guild_species(guild: String) -> String:
	for cs in CreatureSpecies.all():
		if str(cs.data.get("pollinator_guild", "")) == guild:
			return cs.name
	return ""
