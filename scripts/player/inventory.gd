class_name Inventory
extends RefCounted
## What the player carries and wears (spec Appendix R4; the designer's
## first play, item 11). Kept tiny: CARRY slots (data/items.json), each
## holding one thing, and the equipment slots (ranged, melee, amulet,
## rings), each with what's worn and its spares. The screen (I,
## InventoryScreen) shows these and nothing else.
##
## An item is a Dictionary: {"kind"} (a key of items.json "kinds") plus
## whatever that item carries. A plant sample carries its species (index,
## binomial) and its look (colors, shape, the part taken), so it can be
## looked at now and traded or planted later.
##
## Weight is felt, never read: past the movement table's burden.free_items
## carried things, the player is slower, climbs slower and is louder
## (PlanetPlayer.burden()).

const FILE := "res://data/items.json"

static var _data := {}

## One per carry slot: an item, or null.
var carried: Array = []
## Equipment slot -> Array: the worn items first, then the spares (null
## where empty).
var worn := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		if not parsed is Dictionary:
			push_warning("Inventory: %s is missing or not valid JSON" % FILE)
			parsed = {"carry_slots": 10, "equipment": {}, "kinds": {}}
		_data = parsed
	return _data


static func carry_slots() -> int:
	return int(data().get("carry_slots", 10))


## An equipment slot's {label, worn, spares}.
static func slot_info(slot: String) -> Dictionary:
	return data().get("equipment", {}).get(slot, {"label": slot.capitalize(), "worn": 1, "spares": 2})


static func kind_info(kind: String) -> Dictionary:
	return data().get("kinds", {}).get(kind, {"name": kind.capitalize(), "icon": "sample", "color": "#c8d8f0"})


func _init() -> void:
	carried.resize(carry_slots())
	carried.fill(null)
	for slot in data().get("equipment", {}):
		var info := slot_info(slot)
		var a: Array = []
		a.resize(int(info.worn) + int(info.spares))
		a.fill(null)
		worn[slot] = a


## Put on a kit from items.json (`kit`: "starting_kit", the three tools):
## each of its worn items into its slot, if the slot has room (tools and
## tests; in play they're the folk's gifts on the ground, main._lay_gifts()).
static func wear_kit(inv: Inventory, kit: String) -> void:
	for w in data().get(kit, {}).get("worn", []):
		if w is Dictionary and w.has("kind"):
			inv.wear(make(str(w.kind)))


## A new item of `kind`, with `extra` fields.
static func make(kind: String, extra := {}) -> Dictionary:
	var it := {"kind": kind}
	it.merge(extra)
	return it


## A sample of plant species `sp_idx` (SpeciesDB): a cutting, a seed head,
## a leaf or a cut column, by the plant's shape (items.json sample_part);
## a bundle of herbs for the herb genera.
## `extra`: what AroidGarden knows of this very plant (its sport, its
## ploidy; berries from a fruiting one carry the cross and the seedling's
## genome: PlantGenetics), merged in.
static func plant_sample(sp_idx: int, extra := {}) -> Dictionary:
	var sp: PlantSpecies = SpeciesDB.all()[sp_idx]
	var shape_name: String = PlantSpecies.Shape.keys()[sp.shape]
	var part: String = data().get("sample_part", {}).get(shape_name, "cutting")
	var kind := "plant_sample"
	if part == "column":
		kind = "cactus_column"
	elif sp.genus in data().get("bundle_genera", []):
		kind = "herb_bundle"
		part = "bundle"
	var fields := {
		"species": sp_idx,
		"binomial": sp.binomial(),
		"part": part,
		"shape": shape_name,
		"color": sp.color.to_html(false),
		"accent": sp.accent.to_html(false),
		"height_m": snappedf((sp.height_m.x + sp.height_m.y) * 0.5, 0.1),
	}
	fields.merge(extra, true)
	return make(kind, fields)


## The item's name on the screen ("Cutting", "Seed head", "Bow", ...).
static func title(it: Dictionary) -> String:
	match str(it.get("part", "")):
		"cutting":
			return "Cutting"
		"seed":
			return "Seed head"
		"leaf":
			return "Leaf"
		"berries":
			return "Berries"
	if it.has("title"):
		return str(it.title)
	return str(kind_info(it.kind).get("name", it.kind))


## The item's main and second colors (a sample's species colors).
static func colors(it: Dictionary) -> Array:
	var main := Color(str(it.get("color", kind_info(it.kind).get("color", "#c8d8f0"))))
	var second := Color(str(it.get("accent", main.darkened(0.3).to_html(false))))
	return [main, second]


## Put `it` in the first empty carry slot. False if your hands are full.
func add(it: Dictionary) -> bool:
	for i in carried.size():
		if carried[i] == null:
			carried[i] = it
			return true
	return false


## Take the thing out of carry slot `i` (null if it was empty).
func take(i: int):
	if i < 0 or i >= carried.size():
		return null
	var it = carried[i]
	carried[i] = null
	return it


## How many things you carry.
func count() -> int:
	var n := 0
	for it in carried:
		if it != null:
			n += 1
	return n


## Carried things past the free handful (0 when not overburdened).
func over() -> int:
	return maxi(0, count() - int(Tuning.num("movement", "burden", "free_items")))


## Wear `it` in its slot: worn if a worn place is free, else as a spare.
## False if the slot is full or the item isn't worn.
func wear(it: Dictionary) -> bool:
	var slot := str(kind_info(it.kind).get("slot", ""))
	if not worn.has(slot):
		return false
	var a: Array = worn[slot]
	for i in a.size():
		if a[i] == null:
			a[i] = it
			return true
	return false


## What's worn in `slot` (the first worn place), or null.
func worn_in(slot: String):
	return (worn[slot] as Array)[0] if worn.has(slot) else null


## Swap the spare at position `i` of `slot` with the first worn place
## (for rings, the worn place that's empty, else the first).
func wear_spare(slot: String, i: int) -> void:
	if not worn.has(slot):
		return
	var a: Array = worn[slot]
	var n_worn := int(slot_info(slot).worn)
	if i < n_worn or i >= a.size() or a[i] == null:
		return
	var to := 0
	for w in n_worn:
		if a[w] == null:
			to = w
			break
	var t = a[to]
	a[to] = a[i]
	a[i] = t
