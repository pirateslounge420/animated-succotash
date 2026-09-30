class_name FruitCrop
extends Node
## Flowers and fruit on the trees and shrubs round the player (design §AS;
## each species' researched `fruiting` block, PLANT_SCHEMA §4a4).
##
## Every flowering tree near the player carries its crop at real places on
## it: on its twigs among the leaves (its layout's leaf anchors), on the
## outside of the crown, at the stem tips, on the trunk itself (cauliflory),
## on a tall stalk (an agave's, a yucca's), in bunches under a palm's
## crown, at a cactus's crown. Each is one flower of its own, living its
## year on the world clock (nothing stored: the place's hash and the date):
## a bud swelling, the open flower for its flower_days, then either
## withering (not pollinated) or setting a fruit that swells and turns from
## its unripe to its ripe colour over ripen_days, hangs ripe for hang_days,
## then goes as its kind does: it falls (to the ground under the tree,
## where it rots over rot_days), splits open on the branch, dries on the
## tree, or shatters. A tree blooms for a part of its species' season
## (the population's window from flower_months, a half-year on in the other
## hemisphere); some years a nut or cone tree masts, most years it's lean.
##
## Pollination is flower by flower. The species' pollinators come to the
## open flowers near the player (bees, bumblebees, stingless bees, wasps,
## flies and beetles, butterflies by day; moths and bats by night; nectar
## birds), fly from flower to flower, mostly on one tree and now and then
## to the next of its kind, and stay a moment at each: a flower visited
## may set fruit (its species' fruit_set); one watched through to its
## close without a visit doesn't (wind- and self-pollinated species keep a
## share). Flowers nobody saw are rolled. Rain grounds them; day kinds go
## home at dusk, night kinds come out.
##
## Right click picks the fruit in reach, one at a time: ripe, unripe, split or dry
## off the plant, fallen or rotting off the ground; it goes into the
## inventory (Inventory "fruit") and is gone from the tree for the
## session. Near the player the fruit that falls is seen to fall (a
## winged one spins down).
##
## Drawn with the aroid parts' shader (FruitMeshes; one MultiMesh per part
## per chunk, rebuilt a pass at a time within a frame budget); the
## pollinators and the falling fruit in their own MultiMeshes on the world
## root, every frame.

const SCAN_S := 1.5
const PASS_S := 1.0
## Work per frame (microseconds).
const BUDGET_US := 1500
## Trees this near carry their crop drawn (the nearest MAX_TREES); shrubs
## SHRUB_M (the nearest MAX_SHRUBS).
const TREE_M := 60.0
const SHRUB_M := 30.0
const MAX_TREES := 40
const MAX_SHRUBS := 60
## Everything a little bigger than life, and bigger again far off (x2 at
## FAR_M past the first few metres), so a crown in flower reads.
const VIS := 1.5
const FAR_M := 30.0
## Pollinators work the open flowers this near, at most MAX_AGENTS at once.
const AGENT_M := 32.0
const MAX_AGENTS := 12
## E reaches fruit this far from the hands.
const PICK_M := 2.4
## Fruit falling this near is seen to fall, at most MAX_FALLS at once (a
## jump of the clock drops a whole crop: the rest just lie there).
const FALL_M := 45.0
const MAX_FALLS := 40
## An unpollinated flower withers over this many days, then it's gone.
const WITHER_D := 2.5
const CELL_M := 16.0
const HIDDEN := 0.002
const VISIBLE_GUILDS := ["bee", "bumblebee", "stingless_bee", "wasp", "fly", "beetle", "moth", "butterfly", "bird", "bat"]
const NIGHT_GUILDS := ["moth", "bat"]
## Insects drawn a size up (at life size they'd be specks).
const BUG_VIS := 2.2
enum Ph { NONE, BUD, OPEN, WITHER, FRUIT, SPLIT, DRY, GROUND, RIPE }
## A flower form's mesh length (FruitMeshes: most are 1 across).
const FORM_LEN := {"catkin": 3.0, "spike": 2.0, "panicle": 2.4, "cone": 1.4, "tube": 1.35}
## Forms that hang (built down -Y) or stand up (candles), else face out.
const HANGING_FORMS := ["bell", "catkin"]
const UPRIGHT_FORMS := ["spike", "panicle", "cone"]
## A fruit shape's half-thickness, as a share of its length (lying down).
const SHAPE_R := {"round": 0.48, "ovoid": 0.36, "elongated": 0.17, "pod": 0.13, "coiled": 0.3, "winged": 0.14, "star": 0.28, "cone": 0.36}
## Pollinators: body length (m), flying speed (m/s), seconds at a flower,
## flowers per trip, body and second colour, body mode (aroid_part: 13
## banded), wing colours and mode (14 veined, 2 spotted), wing length (x
## body), wingbeat (Hz; past 25 a blur) and whether it hovers at the
## flower (a hawkmoth, a nectar bird, a bat) rather than landing.
const GUILD := {
	"bee": {"len": 0.013, "speed": 3.0, "dwell": [2.0, 5.0], "visits": [8, 25], "body": "#b8862e", "band": "#2a2016", "mode": 13.0, "wing": "#dfe4e8", "vein": "#7a7a70", "wmode": 14.0, "wlen": 0.6, "hz": 200.0, "hover": false},
	"bumblebee": {"len": 0.02, "speed": 2.5, "dwell": [2.0, 6.0], "visits": [8, 20], "body": "#d9aa2a", "band": "#1b1a18", "mode": 13.0, "wing": "#c9cdd2", "vein": "#5a5a55", "wmode": 14.0, "wlen": 0.55, "hz": 150.0, "hover": false},
	"stingless_bee": {"len": 0.006, "speed": 2.0, "dwell": [3.0, 8.0], "visits": [5, 15], "body": "#3a2c1e", "band": "#5a4630", "mode": 13.0, "wing": "#d8dde0", "vein": "#6a6a66", "wmode": 14.0, "wlen": 0.7, "hz": 200.0, "hover": false},
	"wasp": {"len": 0.016, "speed": 3.0, "dwell": [1.5, 4.0], "visits": [3, 10], "body": "#e3c21e", "band": "#151412", "mode": 13.0, "wing": "#c0b8a0", "vein": "#5a5040", "wmode": 14.0, "wlen": 0.55, "hz": 150.0, "hover": false},
	"fly": {"len": 0.009, "speed": 2.5, "dwell": [2.0, 6.0], "visits": [4, 12], "body": "#2e3134", "band": "#2e3134", "mode": 0.0, "wing": "#cfd4d8", "vein": "#6a6e72", "wmode": 14.0, "wlen": 0.65, "hz": 200.0, "hover": false},
	"beetle": {"len": 0.012, "speed": 1.2, "dwell": [6.0, 20.0], "visits": [2, 5], "body": "#2d4a2a", "band": "#1a2a18", "mode": 0.0, "wing": "#3a4a30", "vein": "#1a2418", "wmode": 0.0, "wlen": 0.6, "hz": 80.0, "hover": false},
	"moth": {"len": 0.022, "speed": 2.0, "dwell": [1.0, 3.0], "visits": [6, 15], "body": "#8c7b62", "band": "#6a5a44", "mode": 0.0, "wing": "#a39278", "vein": "#5a4c3c", "wmode": 2.0, "wlen": 0.9, "hz": 30.0, "hover": true},
	"butterfly": {"len": 0.022, "speed": 1.5, "dwell": [3.0, 8.0], "visits": [3, 8], "body": "#2a2420", "band": "#2a2420", "mode": 0.0, "wing": "#e07a1a", "vein": "#1a1410", "wmode": 2.0, "wlen": 1.3, "hz": 7.0, "hover": false},
	"bird": {"len": 0.1, "speed": 6.0, "dwell": [0.6, 1.5], "visits": [8, 20], "body": "#2f7a4a", "band": "#c83a2a", "mode": 0.0, "wing": "#26603a", "vein": "#1a4028", "wmode": 0.0, "wlen": 0.8, "hz": 40.0, "hover": true},
	"bat": {"len": 0.09, "speed": 6.0, "dwell": [0.4, 1.2], "visits": [4, 10], "body": "#3b2f28", "band": "#3b2f28", "mode": 0.0, "wing": "#2a221e", "vein": "#1a1410", "wmode": 0.0, "wlen": 1.3, "hz": 9.0, "hover": true},
}
## A butterfly's wings: [ground colour, markings], one pair picked each.
const BUTTERFLY_WINGS := [["#e07a1a", "#1a1410"], ["#f0eee4", "#2a2a2a"], ["#eed040", "#3a3020"], ["#3a6ad8", "#101418"], ["#b02018", "#101010"]]

## What E calls a fruit kind (with the species' name before it), unless
## the name already names the fruit.
const KIND_WORD := {"cone": "cone", "pod": "pod", "nut": "nut", "samara": "key", "capsule": "seed capsule",
	"achene": "seed head", "fig": "fig", "citrus": "fruit", "berry": "berry", "drupe": "fruit", "pome": "fruit",
	"syncarp": "fruit", "pepo": "fruit"}
const FRUIT_NOUNS := ["apple", "pear", "cherry", "plum", "fig", "olive", "orange", "lemon", "lime", "mango", "date",
	"coconut", "peach", "apricot", "walnut", "hazel", "chestnut", "almond", "pecan", "berry", "grape", "guava",
	"papaya", "banana", "persimmon", "quince", "medlar", "pomegranate", "avocado", "cacao", "durian", "jackfruit",
	"breadfruit", "lychee", "mangosteen", "tamarind", "carob", "hickory", "acorn", "nutmeg", "cashew", "pistachio"]

## The one crop (main and LookTarget ask it).
static var instance: FruitCrop
static var _crops := {}

var world: Node
var chunks: ChunkManager
var player: Node3D
## Fed by main every frame: the sky's daylight (0 night .. 1 day) and the
## rain.
var daylight := 1.0
var rain_mm_h := 0.0
## Flowers visited (tests read it).
var visits_done := 0

var _entries := {} # entry key -> Entry
var _by_plant := {} # "chunk id:tree" or "mmi id:instance" -> entry key
var _grids := {} # chunk id -> cell -> PackedInt32Array of tree indices
var _sgrids := {} # MultiMeshInstance3D id -> cell -> PackedInt32Array of instances
var _holders := {} # chunk id -> {"node", "mmis": mesh key -> MultiMeshInstance3D}
var _visits := {} # kc -> true
var _open_seen := {} # kc -> world day it was last seen open in the pollinators' reach
var _fate := {} # kc -> set fruit or not (decided in sight)
var _picked := {} # kc -> true
var _falling := {} # kc -> true while its fall is drawn
var _falls: Array = []
var _agents: Array = []
var _open: Array = [] # [agent-holder position, kc, entry key, species index, normal]
var _open_keys := {}
var _pickable: Array = []
var _scan_t := 0.0
var _pass_t := 0.0
var _todo: Array = []
var _lists := {} # chunk id -> mesh key -> PackedFloat32Array (the pass being built)
var _next_open: Array = []
var _next_pick: Array = []
var _passing := false
var _agent_node: Node3D
var _agent_mmis := {}
var _mat: ShaderMaterial
var _spawn_t := 0.0
var _rng := RandomNumberGenerator.new()
var _lin := {} # colour cache: hex -> linear Color
var _now := 0.0


## A species' crop: its season, flowers, pollinators and fruit, derived
## once from its `fruiting` block (null when it has none).
class Crop:
	var sp: PlantSpecies
	var idx := -1
	var yd0 := 0.0 # the window's first day (year day, the data's hemisphere)
	var win := 30.0 # the population's flowering window (days)
	var tree_win := 14.0 # one plant's own bloom
	var hemi := 1 # 1 north, -1 south, 0 equatorial (no shift)
	var bud_d := 5.0
	var open_d := 3.0
	var form := "cup"
	var where := "twigs"
	var per_cluster := Vector2(1, 3)
	var col := Color.WHITE
	var eye := Color.YELLOW
	var fl_m := 0.03 # a flower's drawn size (m)
	var guilds: Array = []
	var abiotic := false
	var p_set := 0.3 # a drawn flower's chance of fruit
	var shape := "round"
	var fr_m := Vector2(0.03, 0.05) # drawn fruit length (m)
	var unripe := Color.GREEN
	var ripe := Color.RED
	var ripen := Vector2(90, 120)
	var hang := Vector2(10, 30)
	var drop := "falls"
	var rot := Vector2(14, 40)
	var fruits := 30
	var flowers := 90
	var kind := "berry"
	var word := "fruit"
	var edible := "no"
	var years := 1
	var mast := false


## One plant carrying a crop near the player.
class Entry:
	var key := 0
	var crop: Crop
	var chunk: TerrainChunk
	var tree := -1 # its index in chunk.trees, or -1 for a shrub
	var mmi: MultiMeshInstance3D
	var inst := -1
	var pick := -1
	var xf := Transform3D.IDENTITY # its unit frame -> chunk-local
	var h := 1.0
	var up := Vector3.UP
	var lat := 0.0
	var g0 := 0.0 # its bloom's first day in year 0 (game days, before t_off)
	var t_off := 0.0
	var vigour := 1.0
	var dist := 0.0
	var built := false
	var stalk_len := 0.0 # a rosette's flower stalk (unit lengths), 0: none
	var sites := PackedVector3Array() # chunk-local
	var ground := PackedVector3Array() # chunk-local: where each one's fruit lands
	var skey := PackedInt64Array()
	var u := PackedFloat32Array() # six draws a site
	var face: Array = [] # Basis a site: a flower facing out
	var hang: Array = [] # Basis a site: a fruit hanging
	var lie: Array = [] # Basis a site: a fruit lying on the ground
	var hanging := {} # kc -> true: on the plant at the last pass
	var summary := PackedInt32Array()
	var masts := {} # year -> crop factor


class Agent:
	var kind := "bee"
	var g: Dictionary
	var sp := -1
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var head := Vector3.FORWARD
	var up := Vector3.UP
	var goal := Vector3.ZERO
	var goal_n := Vector3.UP
	var goal_kc := 0
	var goal_entry := 0
	var state := 0 # 0 flying to a flower, 1 at it, 2 leaving
	var dwell := 0.0
	var visits := 10
	var t := 0.0
	var phase := 0.0
	var size := 0.02
	var body := Color.WHITE
	var band := Color.BLACK
	var wing := Color.WHITE
	var vein := Color.GRAY
	var recent: Array = []
	var away := Vector3.ZERO


class Fall:
	var kc := 0
	var entry := 0
	var chunk: TerrainChunk
	var p0 := Vector3.ZERO
	var p1 := Vector3.ZERO
	var up := Vector3.UP
	var b0 := Basis.IDENTITY
	var b1 := Basis.IDENTITY
	var shape := "round"
	var col := Color.WHITE
	var col2 := Color.WHITE
	var mode := 11.0
	var t := 0.0
	var spin := false
	var drift := Vector3.ZERO


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	instance = self
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/aroid_part.gdshader")
	_rng.seed = 7919
	_agent_node = Node3D.new()
	_agent_node.name = "Pollinators"
	world.world_root.add_child(_agent_node)
	if world.has_signal("origin_shifted"):
		world.origin_shifted.connect(_on_origin_shifted)


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if is_instance_valid(_agent_node):
		_agent_node.queue_free()


func _on_origin_shifted(_offset: Vector3) -> void:
	# Positions gathered this pass were in the old frame: start again.
	_restart_pass()


# --- Species -------------------------------------------------------------------

static func crop_of(sp_idx: int) -> Crop:
	if _crops.has(sp_idx):
		return _crops[sp_idx]
	var sp: PlantSpecies = SpeciesDB.all()[sp_idx]
	var c: Crop = _derive(sp, sp_idx) if not sp.fruiting.is_empty() else null
	_crops[sp_idx] = c
	return c


static func _num(v, fallback: float) -> float:
	if v is Array and not (v as Array).is_empty():
		var s := 0.0
		for x in v:
			s += float(x)
		return s / (v as Array).size()
	if v is float or v is int:
		return float(v)
	return fallback


static func _range(v, fallback: Vector2) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[(v as Array).size() - 1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return fallback


static func _hex(v, fallback: Color) -> Color:
	return Color.from_string(str(v), fallback).srgb_to_linear() if v != null else fallback.srgb_to_linear()


static func _derive(sp: PlantSpecies, idx: int) -> Crop:
	var f := sp.fruiting
	var c := Crop.new()
	c.sp = sp
	c.idx = idx
	var year := DayCycle.year_days()
	var months = f.get("flower_months", [4, 5])
	var m0 := 4
	var m1 := 5
	if months is Array and not (months as Array).is_empty():
		m0 = clampi(int(months[0]), 1, 12)
		m1 = clampi(int(months[(months as Array).size() - 1]), 1, 12)
	var n_months := posmod(m1 - m0, 12) + 1
	c.win = n_months * year / 12.0
	# Year day 0 is the northern spring equinox, 20 March (the 79th day).
	c.yd0 = fposmod((m0 - 1) * year / 12.0 - 79.0 / 365.0 * year, year)
	c.hemi = {"north": 1, "south": -1}.get(str(f.get("hemisphere", "north")), 0)
	c.open_d = clampf(_num(f.get("flower_days"), 3.0), 0.5, 30.0)
	c.bud_d = clampf(c.open_d * 2.0, 3.0, 20.0)
	c.tree_win = c.win if n_months >= 10 else clampf(c.win * 0.35, minf(c.open_d * 2.5, c.win), c.win)
	c.form = str(f.get("flower_form", "cup"))
	c.where = str(f.get("flower_position", "twigs"))
	c.per_cluster = _range(f.get("flowers_per_cluster"), Vector2(1, 3))
	c.col = _hex(f.get("flower_colour"), Color(0.95, 0.93, 0.88))
	match c.form:
		"cup", "star", "pea", "brush":
			c.eye = Color(0.95, 0.8, 0.25).srgb_to_linear()
		"bell", "tube":
			c.eye = c.col.darkened(0.35)
		_:
			c.eye = c.col.lightened(0.15)
	var fl_cm := clampf(_num(f.get("flower_size_cm"), 2.0), 0.3, 40.0)
	c.fl_m = maxf(fl_cm / 100.0 / float(FORM_LEN.get(c.form, 1.0)), 0.008) * VIS
	for g in f.get("pollinators", []):
		if str(g) in VISIBLE_GUILDS:
			c.guilds.append(str(g))
		else:
			c.abiotic = true
	if c.guilds.is_empty():
		c.abiotic = true
	c.shape = str(f.get("fruit_shape", "round"))
	c.fr_m = _range(f.get("fruit_size_cm"), Vector2(2, 4)) / 100.0 * VIS
	c.fr_m.x = maxf(c.fr_m.x, 0.006)
	c.fr_m.y = maxf(c.fr_m.y, c.fr_m.x)
	c.unripe = _hex(f.get("unripe_colour"), Color(0.45, 0.6, 0.3))
	c.ripe = _hex(f.get("ripe_colour"), Color(0.6, 0.3, 0.2))
	c.ripen = _range(f.get("ripen_days"), Vector2(60, 120))
	c.hang = _range(f.get("hang_days"), Vector2(7, 30))
	c.drop = str(f.get("drop", "falls"))
	c.rot = _range(f.get("rot_days"), Vector2(14, 40))
	c.kind = str(f.get("fruit_kind", "berry"))
	c.edible = str(f.get("edible", "no"))
	c.mast = c.kind in ["nut", "cone"]
	# How many to draw on a grown tree: its crop (a geometric mean), capped
	# by the fruit's size; enough flowers that its fruit set leaves that
	# many, at most three flowers a fruit (a low-set tree's flowers aren't
	# all drawn).
	var crop_r := _range(f.get("crop_per_tree"), Vector2(20, 200))
	var crop := sqrt(maxf(crop_r.x, 1.0) * maxf(crop_r.y, 1.0))
	var size_cm := (c.fr_m.x + c.fr_m.y) * 0.5 / VIS * 100.0
	var cap := 150 if size_cm < 2.0 else (90 if size_cm < 5.0 else (50 if size_cm < 12.0 else 24))
	c.fruits = clampi(roundi(crop), 1, cap)
	var fs := clampf(float(f.get("fruit_set", 0.3)), 0.005, 1.0)
	c.flowers = clampi(roundi(c.fruits / fs), c.fruits + 1, mini(c.fruits * 3, 240))
	c.p_set = float(c.fruits) / c.flowers
	var life := c.bud_d + c.tree_win + c.open_d * 1.3 + c.ripen.y + c.hang.y + c.rot.y + WITHER_D
	c.years = ceili(life / year) + 1
	c.word = word_for(sp, c.kind)
	return c


## "crab apple", "Scots pine cone", "pecan nut", "sycamore key".
static func word_for(sp: PlantSpecies, kind: String) -> String:
	var name := sp.name.to_lower()
	var last := name.split(" ")[-1]
	var w := str(KIND_WORD.get(kind, "fruit"))
	for noun in FRUIT_NOUNS:
		if last == noun or last == noun + "s" or (noun == "berry" and last.ends_with("berry")):
			if w in ["fruit", "berry", "fig", "nut"]:
				return name
	if last == w:
		return name
	return "%s %s" % [name, w]


# --- Tracking the plants ---------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or player == null:
		return
	_now = float(world.days)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_S
		_scan()
	if not _passing:
		_pass_t -= delta
		if _pass_t <= 0.0:
			_begin_pass()
	if _passing:
		_step(BUDGET_US)
	_update_agents(delta)
	_update_falls(delta)
	_draw_moving()


## A whole pass at once (tools and tests).
func update_now() -> void:
	_now = float(world.days)
	_scan()
	_begin_pass()
	_step(1 << 40)


func _scan() -> void:
	var pp: Vector3 = player.global_position
	var trees: Array = []
	var shrubs: Array = []
	for id in _grids.keys():
		if not is_instance_id_valid(id):
			_grids.erase(id)
	for id in _sgrids.keys():
		if not is_instance_id_valid(id):
			_sgrids.erase(id)
	for id in _holders.keys():
		if not is_instance_id_valid(id):
			_holders.erase(id)
	for c in chunks.chunks.values():
		var chunk := c as TerrainChunk
		if chunk == null or not is_instance_valid(chunk) or not chunk.is_inside_tree():
			continue
		var lp := pp - chunk.global_position
		if lp.length() > TREE_M + TerrainChunk.CHUNK_M:
			continue
		var g := _grid(chunk)
		var ea := CubeSphere.east(chunk.center_dir)
		var na := CubeSphere.north(chunk.center_dir)
		var cx := floori(lp.dot(ea) / CELL_M)
		var cy := floori(lp.dot(na) / CELL_M)
		var reach := ceili(TREE_M / CELL_M)
		for oy in range(-reach, reach + 1):
			for ox in range(-reach, reach + 1):
				var list = g.get(Vector2i(cx + ox, cy + oy))
				if list == null:
					continue
				for i in (list as PackedInt32Array):
					var dist := (chunk.trees[i][0] as Vector3).distance_to(lp)
					if dist < TREE_M:
						trees.append([dist, chunk, i])
		if chunk.detail_node == null or not is_instance_valid(chunk.detail_node) or lp.length() > SHRUB_M + TerrainChunk.CHUNK_M:
			continue
		for ch in chunk.detail_node.get_children():
			var mmi := ch as MultiMeshInstance3D
			if mmi == null or not mmi.has_meta("species") or mmi.has_meta("young") or mmi.multimesh == null:
				continue
			var crop := crop_of(int(mmi.get_meta("species")))
			if crop == null or crop.sp.tier != PlantSpecies.Tier.SHRUB:
				continue
			var sg := _shrub_grid(mmi, chunk)
			var ml := pp - mmi.global_position
			var sx := floori(ml.dot(ea) / CELL_M)
			var sy := floori(ml.dot(na) / CELL_M)
			var sr := ceili(SHRUB_M / CELL_M)
			var buf := mmi.multimesh.buffer
			for oy in range(-sr, sr + 1):
				for ox in range(-sr, sr + 1):
					var list2 = sg.get(Vector2i(sx + ox, sy + oy))
					if list2 == null:
						continue
					for k in (list2 as PackedInt32Array):
						var at := Vector3(buf[k * 20 + 3], buf[k * 20 + 7], buf[k * 20 + 11])
						var dist2 := at.distance_to(ml)
						if dist2 < SHRUB_M:
							shrubs.append([dist2, chunk, -1, mmi, k, crop])
	trees.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	shrubs.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var want := {}
	for i in mini(trees.size(), MAX_TREES):
		var t: Array = trees[i]
		var chunk2: TerrainChunk = t[1]
		var pk := "%d:%d" % [chunk2.get_instance_id(), int(t[2])]
		var key: int = _by_plant.get(pk, 0)
		if key == 0 or not _entries.has(key):
			var e := _tree_entry(chunk2, int(t[2]))
			if e == null:
				continue
			key = e.key
			_entries[key] = e
			_by_plant[pk] = key
		(_entries[key] as Entry).dist = float(t[0])
		want[key] = true
	for i in mini(shrubs.size(), MAX_SHRUBS):
		var s: Array = shrubs[i]
		var mmi2: MultiMeshInstance3D = s[3]
		var pk2 := "%d:%d" % [mmi2.get_instance_id(), int(s[4])]
		var key2: int = _by_plant.get(pk2, 0)
		if key2 == 0 or not _entries.has(key2):
			var e2 := _shrub_entry(s[1], mmi2, int(s[4]), s[5])
			key2 = e2.key
			_entries[key2] = e2
			_by_plant[pk2] = key2
		(_entries[key2] as Entry).dist = float(s[0])
		want[key2] = true
	for key in _entries.keys():
		var e3: Entry = _entries[key]
		if not want.has(key) or not is_instance_valid(e3.chunk):
			_entries.erase(key)
	for pk in _by_plant.keys():
		if not _entries.has(_by_plant[pk]):
			_by_plant.erase(pk)


## The chunk's grown trees that flower, binned on CELL_M in its tangent
## plane.
func _grid(chunk: TerrainChunk) -> Dictionary:
	var id := chunk.get_instance_id()
	if _grids.has(id):
		return _grids[id]
	var g := {}
	var ea := CubeSphere.east(chunk.center_dir)
	var na := CubeSphere.north(chunk.center_dir)
	for i in chunk.trees.size():
		var t: Array = chunk.trees[i]
		if t.size() > 8 and float(t[8]) > 0.5:
			continue # dead
		var pk := int(t[4])
		if pk >= 0 and TreeLayouts.layout_of(pk) >= TreeLayouts.COUNT:
			continue # a sapling or a young tree: not in flower yet
		var crop := crop_of(int(t[2]))
		if crop == null or float(t[1]) < crop.sp.height_m.x * 0.5:
			continue
		var p: Vector3 = t[0]
		var k := Vector2i(floori(p.dot(ea) / CELL_M), floori(p.dot(na) / CELL_M))
		if not g.has(k):
			g[k] = PackedInt32Array()
		var arr: PackedInt32Array = g[k]
		arr.append(i)
		g[k] = arr
	_grids[id] = g
	return g


func _shrub_grid(mmi: MultiMeshInstance3D, chunk: TerrainChunk) -> Dictionary:
	var id := mmi.get_instance_id()
	if _sgrids.has(id):
		return _sgrids[id]
	var g := {}
	var ea := CubeSphere.east(chunk.center_dir)
	var na := CubeSphere.north(chunk.center_dir)
	var buf := mmi.multimesh.buffer
	for k in mmi.multimesh.instance_count:
		var p := Vector3(buf[k * 20 + 3], buf[k * 20 + 7], buf[k * 20 + 11])
		var c := Vector2i(floori(p.dot(ea) / CELL_M), floori(p.dot(na) / CELL_M))
		if not g.has(c):
			g[c] = PackedInt32Array()
		var arr: PackedInt32Array = g[c]
		arr.append(k)
		g[c] = arr
	_sgrids[id] = g
	return g


func _tree_entry(chunk: TerrainChunk, i: int) -> Entry:
	var t: Array = chunk.trees[i]
	var crop := crop_of(int(t[2]))
	if crop == null:
		return null
	var e := Entry.new()
	e.crop = crop
	e.chunk = chunk
	e.tree = i
	var h: float = t[1]
	e.h = h
	e.pick = int(t[4])
	var mirror := -h if TreeLayouts.is_mirrored(e.pick) else h
	e.xf = Transform3D((t[6] as Basis) * Basis.from_scale(Vector3(mirror, h, h)), t[0])
	_place(e)
	return e


func _shrub_entry(chunk: TerrainChunk, mmi: MultiMeshInstance3D, k: int, crop: Crop) -> Entry:
	var e := Entry.new()
	e.crop = crop
	e.chunk = chunk
	e.mmi = mmi
	e.inst = k
	var buf := mmi.multimesh.buffer
	var j := k * 20
	var b := Basis(Vector3(buf[j], buf[j + 4], buf[j + 8]), Vector3(buf[j + 1], buf[j + 5], buf[j + 9]), Vector3(buf[j + 2], buf[j + 6], buf[j + 10]))
	var to_chunk := chunk.global_transform.affine_inverse() * mmi.global_transform
	e.xf = to_chunk * Transform3D(b, Vector3(buf[j + 3], buf[j + 7], buf[j + 11]))
	e.h = b.y.length()
	_place(e)
	return e


## Where it stands on the planet (its up, latitude and key) and its year:
## its species' window in its own hemisphere, its bloom's place in it.
func _place(e: Entry) -> void:
	var c := e.crop
	var d := _dir_of(e.chunk, e.xf.origin)
	e.up = d
	e.lat = CubeSphere.latitude(d)
	e.key = PlantGenetics.key_of(c.sp.name, d, false)
	if e.key == 0:
		e.key = 1
	var year := DayCycle.year_days()
	var shift := year * 0.5 if c.hemi != 0 and absf(e.lat) > 0.05 and signf(e.lat) != float(c.hemi) else 0.0
	e.g0 = fposmod(c.yd0 + shift - DayCycle.year_start_day(), year)
	e.t_off = PlantGenetics.unit(e.key, 41)
	e.vigour = lerpf(0.6, 1.3, PlantGenetics.unit(e.key, 42))
	e.summary.resize(Ph.size())


## The surface direction of chunk-local point `p` (in doubles: the planet's
## centre is millions of metres off).
static func _dir_of(chunk: TerrainChunk, p: Vector3) -> Vector3:
	var ax: float = float(chunk.center_dir.x) * chunk.anchor_radius + p.x
	var ay: float = float(chunk.center_dir.y) * chunk.anchor_radius + p.y
	var az: float = float(chunk.center_dir.z) * chunk.anchor_radius + p.z
	var r := sqrt(ax * ax + ay * ay + az * az)
	return Vector3(ax / r, ay / r, az / r)


## How far chunk-local point `p` is above the ground under it (m).
func _above_ground(chunk: TerrainChunk, p: Vector3) -> float:
	var ax: float = float(chunk.center_dir.x) * chunk.anchor_radius + p.x
	var ay: float = float(chunk.center_dir.y) * chunk.anchor_radius + p.y
	var az: float = float(chunk.center_dir.z) * chunk.anchor_radius + p.z
	var r := sqrt(ax * ax + ay * ay + az * az)
	var d := Vector3(ax / r, ay / r, az / r)
	return r - (PlanetConst.RADIUS_M + maxf(chunks.ground_height(d), chunks.water_level_at(d)))


# --- Where the flowers are ----------------------------------------------------------

func _build_sites(e: Entry) -> void:
	e.built = true
	var c := e.crop
	var rng := RandomNumberGenerator.new()
	rng.seed = e.key
	var n: int
	if e.tree >= 0:
		n = clampi(roundi(float(c.flowers) * clampf(e.h / maxf(c.sp.height_m.y * 0.7, 1.0), 0.35, 1.2)), 4, 240)
	else:
		n = clampi(c.flowers / 3, 3, 60)
	var k_lo := clampi(roundi(c.per_cluster.x), 1, 6)
	var k_hi := clampi(roundi(c.per_cluster.y), k_lo, 6)
	var n_cl := maxi(1, ceili(float(n) / ((k_lo + k_hi) * 0.5)))
	var pts := _anchor_points(e, n_cl, rng)
	if pts.is_empty():
		return
	var count := 0
	var ci := 0
	while count < n:
		var a: Array = pts[ci % pts.size()]
		var p_local: Vector3 = e.xf * (a[0] as Vector3)
		var nrm: Vector3 = (e.xf.basis * (a[1] as Vector3)).normalized()
		if ci >= pts.size():
			# More flowers than places: round the same ones, a little aside.
			p_local += Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)) * maxf(e.h * 0.03, 0.1)
		ci += 1
		var k := rng.randi_range(k_lo, k_hi)
		var drop := maxf(_above_ground(e.chunk, p_local), 0.0)
		var gp := p_local - e.up * drop
		var side := nrm.cross(e.up)
		if side.length() < 0.1:
			side = nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD)
		side = side.normalized()
		var side2 := nrm.cross(side).normalized()
		var spread := maxf(c.fl_m * 1.3, 0.04) * sqrt(float(k))
		for j in k:
			if count >= n:
				break
			var ang := rng.randf() * TAU
			var r := spread * sqrt(rng.randf()) if k > 1 else 0.0
			var off := (side * cos(ang) + side2 * sin(ang)) * r
			e.sites.append(p_local + off)
			var flat := (side * cos(ang + 1.3) + side2 * sin(ang + 1.3))
			flat = (flat - e.up * flat.dot(e.up)).normalized() if (flat - e.up * flat.dot(e.up)).length() > 0.05 else side
			e.ground.append(gp + off + flat * rng.randf_range(0.0, 0.4) * minf(drop, 3.0) * 0.3)
			e.skey.append(hash([e.key, ci, j]))
			for q in 6:
				e.u.append(rng.randf())
			# Its bases: the flower facing out (up for candles, hanging for
			# bells and catkins), the fruit hanging off its stalk, the fruit
			# lying on the ground on its side.
			var fy := (nrm + e.up * 0.6).normalized()
			if c.form in HANGING_FORMS:
				fy = e.up
			elif c.form in UPRIGHT_FORMS:
				fy = (e.up * 0.75 + nrm * 0.25).normalized()
			e.face.append(_basis_y(fy, rng.randf() * TAU))
			var tilt_axis := side.rotated(e.up, rng.randf() * TAU)
			e.hang.append(_basis_y(e.up.rotated(tilt_axis, rng.randf_range(0.0, 0.3)), rng.randf() * TAU))
			e.lie.append(_basis_y(flat, rng.randf() * TAU))
			count += 1


## A basis with `y` its up (normalized), turned `yaw` about it.
static func _basis_y(y: Vector3, yaw: float) -> Basis:
	var yy := y.normalized()
	var ref := Vector3.RIGHT if absf(yy.x) < 0.9 else Vector3.FORWARD
	var x := yy.cross(ref).normalized()
	var z := x.cross(yy).normalized()
	return Basis(x, yy, z).rotated(yy, yaw)


## `n` places on the plant (its unit frame, height 1), each [position,
## the way a flower there faces], by where its species flowers.
func _anchor_points(e: Entry, n: int, rng: RandomNumberGenerator) -> Array:
	var c := e.crop
	var out: Array = []
	if e.tree >= 0 and e.pick >= 0:
		var sk := TreeLayouts.skeleton(c.idx, TreeLayouts.layout_of(e.pick))
		if c.where == "trunk":
			for pc in sk.pieces:
				if pc.order != 0 or pc.kind == TreeLayouts.Kind.ROOT or pc.pts.size() < 2:
					continue
				for k in n:
					var f := rng.randf_range(0.08, 0.55) * float(pc.pts.size() - 1)
					var i0 := clampi(int(f), 0, pc.pts.size() - 2)
					var p: Vector3 = pc.pts[i0].lerp(pc.pts[i0 + 1], f - i0)
					var r: float = lerpf(pc.rad[i0], pc.rad[i0 + 1], f - i0)
					var along: Vector3 = (pc.pts[i0 + 1] - pc.pts[i0]).normalized()
					var out_dir := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized().rotated(along, rng.randf() * TAU)
					out.append([p + out_dir * r * 1.05, out_dir])
				break
		elif not sk.anchors.is_empty():
			var min_outer := 0.0
			match c.where:
				"crown":
					min_outer = 0.55
				"stem_tips":
					min_outer = 0.75
			var idx: Array = []
			for i in sk.anchors.size():
				if float(sk.anchors[i][4]) >= min_outer:
					idx.append(i)
			if idx.is_empty():
				for i in sk.anchors.size():
					idx.append(i)
			for i in range(idx.size() - 1, 0, -1):
				var jj := rng.randi_range(0, i)
				var tmp = idx[i]
				idx[i] = idx[jj]
				idx[jj] = tmp
			for k in mini(n, idx.size()):
				var an: Array = sk.anchors[idx[k]]
				var p0: Vector3 = an[0]
				var tan: Vector3 = an[1]
				var hang: Vector3 = an[2]
				var r2: float = an[5]
				var p2 := p0 + hang * r2 * rng.randf_range(0.5, 0.95) + tan * r2 * 0.25
				out.append([p2, (tan + Vector3.UP * 0.5 + hang * 0.3).normalized()])
	if out.is_empty():
		out = _shape_points(e, n, rng)
	return out


## Places on a plant without a layout, by its shape (unit frame).
func _shape_points(e: Entry, n: int, rng: RandomNumberGenerator) -> Array:
	var c := e.crop
	var S := PlantSpecies.Shape
	var dims := PlantMeshes.tree_dims(c.sp.shape)
	var out: Array = []
	var shape := c.sp.shape
	if c.where == "stalk" or shape == S.SPIKE_ROSETTE or shape == S.ROSETTE:
		# A tall flower stalk from the rosette's heart, the flowers on its
		# upper part.
		e.stalk_len = 1.4 if shape == S.SPIKE_ROSETTE else 0.8
		var y0 := 0.85
		for k in n:
			var f := rng.randf_range(0.55, 1.0)
			var y := y0 + e.stalk_len * f
			var rho := e.stalk_len * lerpf(0.12, 0.02, f) * rng.randf_range(0.4, 1.0)
			var a := rng.randf() * TAU
			var o := Vector3(cos(a), 0, sin(a))
			out.append([Vector3(0, y, 0) + o * rho, (o + Vector3.UP * 0.4).normalized()])
		return out
	for k in n:
		var a := rng.randf() * TAU
		var o := Vector3(cos(a), 0, sin(a))
		if shape == S.PALM:
			# In bunches under the crown, round the trunk's top.
			var y := rng.randf_range(0.84, 0.92)
			out.append([Vector3(0, y, 0) + o * rng.randf_range(0.03, 0.07), (o - Vector3.UP * 0.3).normalized()])
		elif shape == S.CONIFER:
			var bot := dims.w
			var y2 := rng.randf_range(lerpf(bot, 1.0, 0.35), 0.97)
			var rr := dims.z * (1.0 - (y2 - bot) / maxf(1.0 - bot, 0.01)) * rng.randf_range(0.75, 0.95)
			out.append([Vector3(0, y2, 0) + o * rr, (o + Vector3.UP * 0.4).normalized()])
		elif shape == S.CACTUS:
			# The crown of the column, or an arm's tip.
			var tips := [[Vector3(0, 1.0, 0), 0.06], [Vector3(0.24, 0.73, 0), 0.035], [Vector3(-0.2, 0.8, 0), 0.03]]
			var tp: Array = tips[0] if rng.randf() < 0.6 else tips[rng.randi_range(1, 2)]
			out.append([(tp[0] as Vector3) + o * float(tp[1]) * rng.randf_range(0.3, 1.0) - Vector3.UP * rng.randf_range(0.0, 0.02), (Vector3.UP + o * 0.3).normalized()])
		else:
			# The crown's shell (a shrub's round bush, a tree's ellipsoid),
			# the upper parts more than the lower.
			var ctr := Vector3(0, 0.45, 0)
			var rad := Vector3(0.5, 0.45, 0.5)
			if e.tree >= 0:
				ctr = Vector3(0, (dims.w + 1.0) * 0.5, 0)
				rad = Vector3(dims.z, (1.0 - dims.w) * 0.5, dims.z)
			var dir := Vector3(rng.randfn(), absf(rng.randfn()) * 0.8 - 0.1, rng.randfn()).normalized()
			out.append([ctr + dir * rad * rng.randf_range(0.85, 1.0), dir])
	return out


# --- The pass -------------------------------------------------------------------------

func _begin_pass() -> void:
	_todo = _entries.keys()
	# The nearest first.
	_todo.sort_custom(func(a, b) -> bool: return (_entries[a] as Entry).dist > (_entries[b] as Entry).dist)
	_lists = {}
	_next_open = []
	_next_pick = []
	_passing = true


func _restart_pass() -> void:
	_passing = false
	_pass_t = 0.0


func _step(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < budget_us:
		if _todo.is_empty():
			_commit()
			return
		var key: int = _todo.pop_back()
		if not _entries.has(key):
			continue
		var e: Entry = _entries[key]
		if not is_instance_valid(e.chunk) or (e.tree < 0 and (not is_instance_valid(e.mmi) or e.mmi.multimesh == null)):
			_entries.erase(key)
			continue
		_entry_step(e)


func _lists_for(chunk: TerrainChunk) -> Dictionary:
	var id := chunk.get_instance_id()
	if not _lists.has(id):
		_lists[id] = {}
	return _lists[id]


func _buf(lists: Dictionary, mesh_key: String) -> PackedFloat32Array:
	if not lists.has(mesh_key):
		lists[mesh_key] = PackedFloat32Array()
	return lists[mesh_key]


## One part instance: basis (sizes built in), origin, main colour, second
## colour and mode (shaders/aroid_part.gdshader). Returns its index.
static func _emit(buf: PackedFloat32Array, b: Basis, o: Vector3, c: Color, c2: Color, mode: float) -> int:
	buf.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z,
		c.r, c.g, c.b, 1.0, c2.r, c2.g, c2.b, mode])
	return buf.size() / 20 - 1


func _lin_of(c: Color) -> Color:
	return c.srgb_to_linear()


func _entry_step(e: Entry) -> void:
	if not e.built:
		_build_sites(e)
	e.summary.fill(0)
	if e.sites.is_empty():
		return
	var c := e.crop
	var now := _now
	var year := DayCycle.year_days()
	var lists := _lists_for(e.chunk)
	var chunk_pos := e.chunk.global_position
	var agent_off := chunk_pos - _agent_node.global_position
	var in_agent := e.dist < AGENT_M and not c.guilds.is_empty()
	var near := e.dist < 10.0 + e.h
	var fall_ok := e.dist < FALL_M
	var hanging := {}
	var grow := 1.0 + clampf((e.dist - 8.0) / FAR_M, 0.0, 1.5)
	var yr_now := floori((now - e.g0) / year)
	var tw_off := e.t_off * maxf(c.win - c.tree_win, 0.0)
	var span := c.tree_win + c.open_d * 1.3 + c.ripen.y + c.hang.y + c.rot.y + WITHER_D + 2.0
	var flower_key := "flower:" + c.form
	var fruit_key := "fruit:" + c.shape
	var brown := Color(0.36, 0.25, 0.14).srgb_to_linear()
	var rot_c := Color(0.16, 0.11, 0.06).srgb_to_linear()
	var mold := Color(0.62, 0.62, 0.56).srgb_to_linear()
	var dry_c := Color(0.45, 0.35, 0.23).srgb_to_linear()
	var bud_green := Color(0.3, 0.42, 0.2).srgb_to_linear()
	var seeds_c := Color(0.1, 0.08, 0.06).srgb_to_linear()
	var shape_r := float(SHAPE_R.get(c.shape, 0.4))
	var stalk_on := false
	for yi in range(-1, c.years + 1):
		var yr := yr_now - yi
		var g0 := e.g0 + float(yr) * year + tw_off
		if now < g0 - c.bud_d * 1.25 or now > g0 + span:
			continue
		stalk_on = true
		var p_year := clampf(c.p_set * e.vigour * _mast(e, yr), 0.0, 1.0)
		var cu := fposmod(float(yr) * 0.6180339887, 1.0)
		for s in e.sites.size():
			var j := s * 6
			var u1 := fposmod(e.u[j] + cu, 1.0)
			var u2 := fposmod(e.u[j + 1] + cu * 1.7, 1.0)
			var o := g0 + u1 * maxf(c.tree_win - c.open_d * 0.5, 0.5)
			var b0 := o - c.bud_d * lerpf(0.8, 1.2, u2)
			if now < b0:
				continue
			var kc: int = e.skey[s] + yr * 1000003
			if _picked.has(kc):
				continue
			var site: Vector3 = e.sites[s]
			var od := c.open_d * lerpf(0.7, 1.3, u2)
			if now < o:
				var t := (now - b0) / maxf(o - b0, 0.01)
				var bs := c.fl_m * 0.45 * lerpf(0.3, 1.0, t) * grow
				_emit(_buf(lists, "bud"), (e.face[s] as Basis).scaled(Vector3.ONE * bs), site, c.col.lerp(bud_green, 0.6 * (1.0 - t)), bud_green, 0.0)
				e.summary[Ph.BUD] += 1
				continue
			var close := o + od
			if now < close:
				var t2 := (now - o) / od
				var fs := c.fl_m * lerpf(0.55, 1.0, smoothstep(0.0, 0.15, t2)) * grow
				_emit(_buf(lists, flower_key), (e.face[s] as Basis).scaled(Vector3.ONE * fs), site, c.col, c.eye, 10.0)
				e.summary[Ph.OPEN] += 1
				if in_agent:
					_open_seen[kc] = now
					_next_open.append([site + agent_off, kc, e.key, c.idx, (e.face[s] as Basis).y])
				continue
			var u6 := fposmod(e.u[j + 5] + cu * 5.9, 1.0)
			if not _fate_of(c, kc, u6, p_year, close):
				if now < close + WITHER_D:
					var t3 := (now - close) / WITHER_D
					var ws := c.fl_m * lerpf(1.0, 0.55, t3) * grow
					_emit(_buf(lists, flower_key), (e.face[s] as Basis).scaled(Vector3.ONE * ws), site, c.col.lerp(brown, t3), c.eye.lerp(brown, t3), 10.0)
					e.summary[Ph.WITHER] += 1
				continue
			var u3 := fposmod(e.u[j + 2] + cu * 2.3, 1.0)
			var u4 := fposmod(e.u[j + 3] + cu * 3.1, 1.0)
			var u5 := fposmod(e.u[j + 4] + cu * 4.3, 1.0)
			var pol := o + od * 0.5
			var ripe_t := pol + lerpf(c.ripen.x, c.ripen.y, u3)
			var hang_end := ripe_t + lerpf(c.hang.x, c.hang.y, u4)
			var length := lerpf(c.fr_m.x, c.fr_m.y, u5)
			var on_plant := true
			var col := c.ripe
			var col2 := c.ripe
			var mode := 11.0
			var fl := length
			var state := "ripe"
			var ph := Ph.RIPE
			if now < ripe_t:
				var g := smoothstep(close, pol + (ripe_t - pol) * 0.7, now)
				var ripe := smoothstep(ripe_t - (ripe_t - pol) * 0.25, ripe_t, now)
				fl = length * lerpf(0.12, 1.0, g)
				col = c.unripe.lerp(c.ripe, ripe)
				col2 = col
				state = "ripe" if ripe > 0.8 else "unripe"
				ph = Ph.RIPE if ripe > 0.8 else Ph.FRUIT
			elif now < hang_end:
				var t4 := (now - ripe_t) / maxf(hang_end - ripe_t, 0.01)
				match c.drop:
					"splits":
						col = c.ripe.darkened(0.25)
						col2 = seeds_c
						mode = 1.0
						fl = length * 1.08
						state = "split"
						ph = Ph.SPLIT
					"persists":
						col = c.ripe.lerp(dry_c, t4)
						col2 = col
						state = "dry"
						ph = Ph.DRY
			else:
				on_plant = false
			if on_plant:
				var hb := (e.hang[s] as Basis).scaled(Vector3.ONE * fl * grow)
				var idx := _emit(_buf(lists, fruit_key), hb, site, col, col2, mode)
				hanging[kc] = true
				e.summary[ph] += 1
				if near:
					_next_pick.append([e.chunk, site - e.up * fl * 0.5, maxf(fl * 0.5, 0.03), kc, e.key, state, c, col, fruit_key, idx])
				continue
			if c.drop == "shatters":
				continue
			var rot_end := hang_end + lerpf(c.rot.x, c.rot.y, fposmod(u6 * 7.31 + 0.13, 1.0))
			if now >= rot_end:
				continue
			var gcol := c.ripe
			if c.drop == "splits":
				gcol = c.ripe.darkened(0.25)
			elif c.drop == "persists":
				gcol = dry_c
			var ground_at: Vector3 = e.ground[s] + e.up * length * shape_r
			if fall_ok and e.hanging.has(kc) and not _falling.has(kc) and _falls.size() < MAX_FALLS:
				_start_fall(e, kc, site, ground_at, (e.hang[s] as Basis).scaled(Vector3.ONE * length), (e.lie[s] as Basis).scaled(Vector3.ONE * length), gcol)
			if _falling.has(kc):
				continue
			var t5 := (now - hang_end) / maxf(rot_end - hang_end, 0.01)
			var shrink := lerpf(1.0, 0.55, t5 * t5)
			var lb := (e.lie[s] as Basis).scaled(Vector3(shrink, shrink, shrink * lerpf(1.0, 0.7, t5)) * length * grow)
			var rc := gcol.lerp(rot_c, smoothstep(0.1, 0.8, t5))
			var rc2 := gcol.darkened(0.25).lerp(rot_c.darkened(0.4), t5).lerp(mold, smoothstep(0.55, 0.9, t5))
			var gidx := _emit(_buf(lists, fruit_key), lb, ground_at - e.up * length * shape_r * (1.0 - shrink), rc, rc2, 1.0)
			e.summary[Ph.GROUND] += 1
			if near:
				_next_pick.append([e.chunk, ground_at, maxf(length * 0.5, 0.03), kc, e.key, "fallen" if t5 < 0.35 else "rotting", c, rc, fruit_key, gidx])
	e.hanging = hanging
	# An agave's or a yucca's flower stalk, up while it's in bloom or fruit.
	if e.stalk_len > 0.0 and stalk_on:
		var foot: Vector3 = e.xf * Vector3(0, 0.85, 0)
		var len_m := e.stalk_len * e.h
		var r := maxf(0.02, len_m * 0.012)
		var sb := _basis_y(e.up, 0.0)
		_emit(_buf(lists, "stalk"), Basis(sb.x * r, sb.y * len_m, sb.z * r), foot, Color(0.42, 0.5, 0.26).srgb_to_linear(), Color.BLACK, 0.0)


## A year's crop at this plant's place: a nut or cone tree masts now and
## then (lean most years), the rest vary a little.
func _mast(e: Entry, yr: int) -> float:
	if e.masts.has(yr):
		return e.masts[yr]
	var u := PlantGenetics.unit(hash([e.crop.idx, yr, int(e.lat * 8.0)]), 5)
	var m := lerpf(0.15, 1.7, u * u) if e.crop.mast else lerpf(0.7, 1.2, u)
	e.masts[yr] = m
	return m


## Did the flower `kc` set fruit? Visited in sight: likelier than its
## species' share; watched through to its close with no visit: no (a
## wind-pollinated share aside); unseen: rolled. Decisions made in sight
## are kept for the session.
func _fate_of(c: Crop, kc: int, u: float, p: float, close: float) -> bool:
	if _fate.has(kc):
		return _fate[kc]
	var f: bool
	if _visits.has(kc):
		f = u < minf(1.0, p * 1.4)
	elif c.guilds.is_empty():
		return u < p
	else:
		var seen := float(_open_seen.get(kc, -1e9))
		if close - seen > 0.05:
			return u < p
		f = c.abiotic and u < p * 0.6
	_fate[kc] = f
	return f


func _commit() -> void:
	_passing = false
	_pass_t = PASS_S
	for id in _holders.keys():
		if not _lists.has(id):
			_lists[id] = {}
	for id in _lists:
		if not is_instance_id_valid(id):
			continue
		var chunk := instance_from_id(id) as TerrainChunk
		if chunk == null or not chunk.is_inside_tree():
			continue
		var h := _holder(chunk)
		var lists: Dictionary = _lists[id]
		var mmis: Dictionary = h.mmis
		for mk in mmis.keys():
			if not lists.has(mk):
				var old: MultiMeshInstance3D = mmis[mk]
				if is_instance_valid(old) and old.multimesh != null:
					old.multimesh.instance_count = 0
					old.visible = false
		for mk in lists:
			var buf: PackedFloat32Array = lists[mk]
			var mmi := _part_mmi(h, str(mk))
			if mmi == null or mmi.multimesh == null:
				continue
			mmi.multimesh.instance_count = buf.size() / 20
			if buf.size() > 0:
				mmi.multimesh.buffer = buf
			mmi.visible = buf.size() > 0
	_lists = {}
	_open = _next_open
	_open_keys = {}
	for f in _open:
		_open_keys[f[1]] = true
	_pickable = _next_pick
	_next_open = []
	_next_pick = []


func _holder(chunk: TerrainChunk) -> Dictionary:
	var id := chunk.get_instance_id()
	if _holders.has(id) and is_instance_valid(_holders[id].node):
		return _holders[id]
	var node := Node3D.new()
	node.name = "FruitCrop"
	chunk.add_child(node)
	_holders[id] = {"node": node, "mmis": {}}
	return _holders[id]


func _part_mmi(h: Dictionary, mesh_key: String) -> MultiMeshInstance3D:
	var mmis: Dictionary = h.mmis
	if mmis.has(mesh_key) and is_instance_valid(mmis[mesh_key]):
		return mmis[mesh_key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _mesh_for(mesh_key)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mesh_key.replace(":", "_")
	mmi.multimesh = mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(h.node as Node3D).add_child(mmi)
	mmis[mesh_key] = mmi
	return mmi


static func _mesh_for(mesh_key: String) -> Mesh:
	var parts := mesh_key.split(":")
	match parts[0]:
		"bud":
			return FruitMeshes.bud()
		"flower":
			return FruitMeshes.flower(parts[1], 1)
		"fruit", "fall":
			return FruitMeshes.fruit(parts[1])
		"stalk":
			return FruitMeshes.stalk()
		"visitor":
			return FruitMeshes.visitor(parts[1])
		"wing":
			return FruitMeshes.wing()
	return FruitMeshes.bud()


# --- Falling fruit ---------------------------------------------------------------------

func _start_fall(e: Entry, kc: int, from: Vector3, to: Vector3, b0: Basis, b1: Basis, col: Color) -> void:
	var f := Fall.new()
	f.kc = kc
	f.entry = e.key
	f.chunk = e.chunk
	f.p0 = from
	f.p1 = to
	f.up = e.up
	f.b0 = b0
	f.b1 = b1
	f.shape = e.crop.shape
	f.col = col
	f.col2 = col
	f.mode = 11.0
	f.spin = e.crop.shape == "winged"
	var wind: Vector3 = WeatherFX.plant_wind if f.spin else Vector3.ZERO
	f.drift = (wind - e.up * wind.dot(e.up)) * 0.15
	_falls.append(f)
	_falling[kc] = true


func _update_falls(delta: float) -> void:
	for i in range(_falls.size() - 1, -1, -1):
		var f: Fall = _falls[i]
		f.t += delta
		var h := maxf((f.p0 - f.p1).dot(f.up), 0.0)
		var land_t := h / 1.3 if f.spin else sqrt(2.0 * h / 9.8)
		if f.t > land_t + 0.35 or not is_instance_valid(f.chunk):
			_falls.remove_at(i)
			_falling.erase(f.kc)
			_pass_t = minf(_pass_t, 0.05)


## `a` turned toward `b` by `t` (both scaled bases of one size: the
## rotation is slerped, the size kept).
static func _turn(a: Basis, b: Basis, t: float) -> Basis:
	var sc := a.get_scale()
	var q := a.orthonormalized().get_rotation_quaternion().slerp(b.orthonormalized().get_rotation_quaternion(), t)
	return Basis(q).scaled(sc)


func _fall_pose(f: Fall) -> Array:
	var h := maxf((f.p0 - f.p1).dot(f.up), 0.0)
	var flat0 := f.p0 - f.up * (f.p0 - f.p1).dot(f.up)
	if f.spin:
		var land_t := h / 1.3
		var k := clampf(f.t / maxf(land_t, 0.01), 0.0, 1.0)
		var p := flat0.lerp(f.p1, k) + f.drift * minf(f.t, land_t) + f.up * h * (1.0 - k)
		var b := f.b0.rotated(f.up, f.t * 14.0)
		return [p, _turn(b, f.b1, smoothstep(0.85, 1.0, k))] if k >= 1.0 else [p, b]
	var fall_t := sqrt(2.0 * h / 9.8)
	if f.t < fall_t:
		var y := h - 4.9 * f.t * f.t
		var k2 := f.t / maxf(fall_t, 0.01)
		return [flat0.lerp(f.p1, k2 * k2) + f.up * y, _turn(f.b0, f.b1, k2)]
	# A little bounce, and it's still.
	var bt := clampf((f.t - fall_t) / 0.35, 0.0, 1.0)
	var hop := minf(0.25, h * 0.04) * sin(PI * bt)
	return [f.p1 + f.up * hop, f.b1]


# --- Pollinators -------------------------------------------------------------------------

func _update_agents(delta: float) -> void:
	_spawn_agents(delta)
	var grounded := rain_mm_h > 0.5
	for i in range(_agents.size() - 1, -1, -1):
		var a: Agent = _agents[i]
		a.t += delta
		var night: bool = a.kind in NIGHT_GUILDS
		if a.state != 2 and (grounded or (night and daylight > 0.45) or (not night and daylight < 0.15)):
			_leave(a)
		match a.state:
			1:
				a.dwell -= delta
				if not _open_keys.has(a.goal_kc):
					a.dwell = minf(a.dwell, 0.3)
				# Hovering ones hold in the air before it; the rest walk
				# about on it a little.
				var bob := sin(a.t * 9.0 + a.phase) * a.size * 0.15
				a.pos = a.goal + a.goal_n * _perch_off(a) + a.up * bob
				if a.g.hover:
					a.head = -a.goal_n
				else:
					a.head = a.head.rotated(a.up, delta * sin(a.t * 1.3 + a.phase) * 0.8)
				if a.dwell <= 0.0:
					_visits[a.goal_kc] = true
					visits_done += 1
					a.visits -= 1
					a.recent.append(a.goal_kc)
					if a.recent.size() > 6:
						a.recent.pop_front()
					if a.visits <= 0 or not _next_flower(a):
						_leave(a)
					else:
						a.state = 0
			_:
				if a.state == 0 and not _open_keys.has(a.goal_kc) and not _open.is_empty():
					if not _next_flower(a):
						_leave(a)
				var target := a.goal + a.goal_n * _perch_off(a) if a.state == 0 else a.away
				var to := target - a.pos
				var d := to.length()
				var sp: float = a.g.speed
				var want := to / maxf(d, 1e-4) * minf(sp, d * 2.5 + 0.15)
				var side := to.cross(a.up)
				if side.length() > 1e-3:
					want += side.normalized() * sin(a.t * 5.0 + a.phase) * sp * 0.25 * clampf(d, 0.0, 1.0)
				want += a.up * sin(a.t * 3.3 + a.phase * 2.0) * sp * 0.12 * clampf(d, 0.0, 1.0)
				a.vel = a.vel.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
				a.pos += a.vel * delta
				if a.vel.length() > 0.05:
					a.head = a.vel.normalized()
				if a.state == 0 and d < maxf(0.02, sp * delta * 1.5):
					a.state = 1
					a.pos = target
					a.vel = Vector3.ZERO
					var dw: Array = a.g.dwell
					a.dwell = _rng.randf_range(float(dw[0]), float(dw[1]))
				elif a.state == 2 and (d < 0.5 or a.t > 40.0):
					_agents.remove_at(i)


func _perch_off(a: Agent) -> float:
	return a.size * (1.3 if a.g.hover else 0.35)


func _spawn_agents(delta: float) -> void:
	if _open.is_empty() or rain_mm_h > 0.5:
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = _rng.randf_range(0.6, 1.8)
	var target := mini(MAX_AGENTS, ceili(_open.size() / 6.0))
	if _agents.size() >= target:
		return
	var f: Array = _open[_rng.randi() % _open.size()]
	var crop := crop_of(int(f[3]))
	if crop == null:
		return
	var kinds: Array = []
	for g in crop.guilds:
		var night: bool = g in NIGHT_GUILDS
		if (night and daylight < 0.3) or (not night and daylight > 0.3):
			kinds.append(g)
	if kinds.is_empty():
		return
	var a := Agent.new()
	a.kind = kinds[_rng.randi() % kinds.size()]
	a.g = GUILD[a.kind]
	a.sp = int(f[3])
	a.phase = _rng.randf() * TAU
	var bug := a.kind != "bird" and a.kind != "bat"
	a.size = float(a.g.len) * (BUG_VIS if bug else 1.0) * _rng.randf_range(0.85, 1.15)
	a.body = _col(str(a.g.body))
	a.band = _col(str(a.g.band))
	a.wing = _col(str(a.g.wing))
	a.vein = _col(str(a.g.vein))
	if a.kind == "butterfly":
		var pair: Array = BUTTERFLY_WINGS[_rng.randi() % BUTTERFLY_WINGS.size()]
		a.wing = _col(str(pair[0]))
		a.vein = _col(str(pair[1]))
	var vs: Array = a.g.visits
	a.visits = _rng.randi_range(int(vs[0]), int(vs[1]))
	a.goal = f[0]
	a.goal_kc = f[1]
	a.goal_entry = f[2]
	a.goal_n = f[4]
	a.up = world.dir_of(_agent_node.to_global(a.goal))
	var flat := a.up.cross(Vector3.RIGHT if absf(a.up.x) < 0.9 else Vector3.FORWARD).normalized().rotated(a.up, _rng.randf() * TAU)
	a.pos = a.goal + flat * _rng.randf_range(8.0, 15.0) + a.up * _rng.randf_range(1.0, 4.0)
	a.head = (a.goal - a.pos).normalized()
	_agents.append(a)


func _col(hex: String) -> Color:
	if not _lin.has(hex):
		_lin[hex] = Color.from_string(hex, Color.WHITE).srgb_to_linear()
	return _lin[hex]


## The next open flower for `a`: of its species, not one it's just been at,
## the near ones on the same plant first, now and then the next plant.
func _next_flower(a: Agent) -> bool:
	var best := -1
	var best_s := INF
	for i in _open.size():
		var f: Array = _open[i]
		if int(f[3]) != a.sp or int(f[1]) == a.goal_kc or a.recent.has(f[1]):
			continue
		var d := (f[0] as Vector3).distance_to(a.pos)
		if d > 25.0:
			continue
		var s := d * _rng.randf_range(0.6, 1.4) + (0.0 if int(f[2]) == a.goal_entry else 3.0 * _rng.randf())
		if s < best_s:
			best_s = s
			best = i
	if best < 0:
		return false
	var g: Array = _open[best]
	a.goal = g[0]
	a.goal_kc = g[1]
	a.goal_entry = g[2]
	a.goal_n = g[4]
	return true


func _leave(a: Agent) -> void:
	a.state = 2
	var flat := a.head - a.up * a.head.dot(a.up)
	if flat.length() < 0.1:
		flat = a.up.cross(Vector3.RIGHT if absf(a.up.x) < 0.9 else Vector3.FORWARD)
	a.away = a.pos + flat.normalized() * 20.0 + a.up * 6.0
	a.t = minf(a.t, 20.0)


## The pollinators and the falling fruit, every frame.
func _draw_moving() -> void:
	var lists := {}
	var wings := PackedFloat32Array()
	for a: Agent in _agents:
		var z := a.head.normalized()
		var y := (a.up - z * a.up.dot(z))
		y = y.normalized() if y.length() > 1e-3 else a.up.cross(Vector3.RIGHT).normalized()
		var x := y.cross(z)
		var b := Basis(x, y, z)
		var key := "visitor:" + a.kind
		if not lists.has(key):
			lists[key] = PackedFloat32Array()
		_emit(lists[key], b.scaled(Vector3.ONE * a.size), a.pos, a.body, a.band, float(a.g.mode))
		var hz: float = a.g.hz
		var flying := a.state != 1 or bool(a.g.hover)
		var wl: float = a.size * float(a.g.wlen)
		for sgn: float in [-1.0, 1.0]:
			var flap := 0.0
			var sweep := 0.0
			if flying:
				flap = _rng.randf_range(-0.5, 0.9) if hz > 25.0 else 0.2 + 0.9 * sin(TAU * hz * a.t + a.phase)
				sweep = 0.15
			elif a.kind == "butterfly":
				flap = 1.35 + 0.15 * sin(a.t * 2.0 + a.phase)
				sweep = 0.1
			elif a.kind == "beetle":
				sweep = 1.45
			else:
				flap = 0.1
				sweep = 1.15
			var wb := b * Basis(Vector3(0, 0, 1), sgn * flap) * Basis(Vector3.UP, sgn * sweep) * Basis.from_scale(Vector3(sgn * wl, wl, wl))
			var wo := a.pos + b * (Vector3(sgn * 0.06, 0.08, 0.1) * a.size)
			_emit(wings, wb, wo, a.wing, a.vein, float(a.g.wmode))
	lists["wing"] = wings
	for f: Fall in _falls:
		if not is_instance_valid(f.chunk):
			continue
		var pose := _fall_pose(f)
		var at: Vector3 = _agent_node.to_local(f.chunk.to_global(pose[0]))
		var key2 := "fall:" + f.shape
		if not lists.has(key2):
			lists[key2] = PackedFloat32Array()
		_emit(lists[key2], pose[1], at, f.col, f.col2, f.mode)
	for mk in _agent_mmis.keys():
		if not lists.has(mk):
			var old: MultiMeshInstance3D = _agent_mmis[mk]
			if old.multimesh.instance_count > 0:
				old.multimesh.instance_count = 0
			old.visible = false
	for mk in lists:
		var buf: PackedFloat32Array = lists[mk]
		if buf.is_empty() and not _agent_mmis.has(mk):
			continue
		if not _agent_mmis.has(mk):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = _mesh_for(str(mk))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = str(mk).replace(":", "_")
			mmi.multimesh = mm
			mmi.material_override = _mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_agent_node.add_child(mmi)
			_agent_mmis[mk] = mmi
		var m: MultiMeshInstance3D = _agent_mmis[mk]
		m.multimesh.instance_count = buf.size() / 20
		if buf.size() > 0:
			m.multimesh.buffer = buf
		m.visible = buf.size() > 0


# --- Picking --------------------------------------------------------------------------

## The fruit on the ray from `from` along `dir` within `reach` of `hand`
## (the nearest along the ray), or {}.
func fruit_at(from: Vector3, dir: Vector3, hand: Vector3, reach := PICK_M) -> Dictionary:
	var best := {}
	var best_t := INF
	for p in _pickable:
		var chunk = p[0]
		if not is_instance_valid(chunk) or _picked.has(p[3]):
			continue
		var at: Vector3 = chunk.to_global(p[1])
		var r: float = p[2]
		if at.distance_to(hand) > reach + r:
			continue
		var t := (at - from).dot(dir)
		if t < 0.0:
			continue
		if (from + dir * t).distance_to(at) > r * 1.3 + 0.06:
			continue
		if t < best_t:
			best_t = t
			best = {"chunk": chunk, "at": at, "kc": p[3], "entry": p[4], "state": p[5], "crop": p[6], "color": p[7], "mesh": p[8], "index": p[9]}
	return best


## "Right click: pick the ripe crab apple", "Right click: pick up the
## fallen pecan nut".
static func prompt_for(info: Dictionary) -> String:
	var c: Crop = info.crop
	var state := str(info.state)
	if state == "fallen" or state == "rotting":
		return "%s: pick up the %s %s" % [Controls.interact_word(), state, c.word]
	return "%s: pick the %s %s" % [Controls.interact_word(), state, c.word]


## The inventory item for the fruit `info` (fruit_at()).
static func item_for(info: Dictionary) -> Dictionary:
	var c: Crop = info.crop
	var state := str(info.state)
	var col: Color = (info.color as Color).linear_to_srgb()
	var title := "%s %s" % [state.capitalize(), c.word]
	return Inventory.make("fruit", {
		"species": c.idx,
		"binomial": c.sp.binomial(),
		"title": title,
		"fruit": c.word,
		"fruit_kind": c.kind,
		"state": state,
		"ripe": state == "ripe" or state == "fallen",
		"edible": c.edible,
		"color": col.to_html(false),
		"accent": col.darkened(0.3).to_html(false),
		"shape": c.shape,
	})


## Take the fruit `info` off the plant (or the ground): gone for the
## session, at once.
func take(info: Dictionary) -> void:
	_picked[info.kc] = true
	var chunk: TerrainChunk = info.chunk
	if is_instance_valid(chunk) and _holders.has(chunk.get_instance_id()):
		var h: Dictionary = _holders[chunk.get_instance_id()]
		var mmi: MultiMeshInstance3D = h.mmis.get(str(info.mesh))
		var i: int = info.index
		if is_instance_valid(mmi) and mmi.multimesh != null and i < mmi.multimesh.instance_count:
			var xf := mmi.multimesh.get_instance_transform(i)
			mmi.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * HIDDEN), xf.origin))
	if _passing:
		_restart_pass()


# --- What the HUD says ---------------------------------------------------------------

## A few words on tree `i` of `chunk`'s flowers and fruit ("in flower",
## "in fruit, ripe"), or "".
static func describe_tree(chunk: TerrainChunk, i: int) -> String:
	if instance == null or chunk == null:
		return ""
	return instance._describe("%d:%d" % [chunk.get_instance_id(), i])


## The same for plant `k` of the undergrowth MultiMesh `mmi_id`.
static func describe_plant(mmi_id: int, k: int) -> String:
	if instance == null:
		return ""
	return instance._describe("%d:%d" % [mmi_id, k])


func _describe(pk: String) -> String:
	var key: int = _by_plant.get(pk, 0)
	if key == 0 or not _entries.has(key):
		return ""
	var s: PackedInt32Array = (_entries[key] as Entry).summary
	if s.size() < Ph.size():
		return ""
	if s[Ph.OPEN] > 0:
		return "in flower"
	if s[Ph.BUD] > 0:
		return "in bud"
	if s[Ph.RIPE] > 0 or s[Ph.SPLIT] > 0:
		return "in fruit, ripe"
	if s[Ph.FRUIT] > 0 or s[Ph.DRY] > 0:
		return "in fruit"
	if s[Ph.GROUND] > 0:
		return "fruit on the ground"
	return ""
