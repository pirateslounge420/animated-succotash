class_name Kindling
## Kindling (design 2 Oct §CN, fuel.json kindling): what a fire that is
## fully out needs before the torch's swing will light it. Whatever is
## fine and dry where you are, real for each biome (kindling.biomes, the
## likeliest first). It is carried (burden applies: `carry_items`) and
## gathered with right click:
##   - litter and ground kinds (dead twigs, dead leaves, needles, husks,
##     driftwood shavings, bogwood) from the ground at your feet;
##   - plant, fungus and lichen kinds from a plant of one of the kind's
##     genera under the crosshair (a birch gives birch bark), only where
##     the biome lists the kind and in its season.
## The dry grass and reeds are the existing fuel items (`fuel_kind`): a
## bundle of either is kindling as it stands. The pouch keeps kindling dry
## (design 2 Oct §CO, kindling.pouch_keeps_dry, superseding §CN's
## "gathered or carried in rain"): only kindling gathered while it rains,
## outside a roof, starts damp, and it dries in the pouch after fuel.json
## wet.dry_h_game game hours. Anything can be gathered in any weather. Dry kindling always catches; wet
## kindling only if its kind is wet_ok (birch bark, fatwood, Douglas-fir
## pitchwood), otherwise it smokes and the fire stays cold. No dice. The
## flame takes after catch.time_s_max x (1 - catch_dry or catch_wet).
## The laying and the lighting are FireStore's (lay_kindling, swing_light).

static var FUEL := Tuning.table("fuel")
static var D: Dictionary = FUEL.get("kindling", {})

## Until the data's kindling block is there: the core kinds (§CN).
const CORE := {
	"grass_bundle": {"name": "Dry grass", "gather": "litter", "genera": [], "catch_dry": 0.95, "catch_wet": 0.1, "wet_ok": false, "burn_s": 20, "fuel_kind": true},
	"reeds": {"name": "Dry reeds", "gather": "litter", "genera": [], "catch_dry": 0.9, "catch_wet": 0.1, "wet_ok": false, "burn_s": 25, "fuel_kind": true},
	"dry_twigs": {"name": "Dead twigs", "gather": "litter", "genera": [], "catch_dry": 0.75, "catch_wet": 0.25, "wet_ok": false, "burn_s": 60},
	"dead_leaves": {"name": "Dead leaves", "gather": "litter", "genera": [], "catch_dry": 0.85, "catch_wet": 0.05, "wet_ok": false, "burn_s": 12},
	"conifer_needles": {"name": "Dry needles", "gather": "litter", "genera": ["Pinus", "Picea", "Abies", "Larix", "Pseudotsuga", "Tsuga", "Cedrus"], "catch_dry": 0.9, "catch_wet": 0.2, "wet_ok": false, "burn_s": 25},
}
const CORE_LIST := ["dry_twigs", "dead_leaves", "grass_bundle", "reeds"]
## How many kindling things you carry before right click on a plant goes
## back to taking a sample.
const KEEP := 3


static func kinds() -> Dictionary:
	var k = D.get("kinds", {})
	return k if k is Dictionary and not (k as Dictionary).is_empty() else CORE


static func info(kind: String) -> Dictionary:
	var k = kinds().get(kind, CORE.get(kind, {}))
	return k if k is Dictionary else {}


static func name_of(kind: String) -> String:
	return str(info(kind).get("name", kind.replace("_", " ").capitalize()))


## What the biome at `d` offers as kindling, likeliest first.
static func biome_list(world, d: Vector3) -> Array:
	var b = D.get("biomes", null)
	if not b is Dictionary:
		return CORE_LIST
	var l = (b as Dictionary).get(FireStore.biome_key(world, d), CORE_LIST)
	return l if l is Array else CORE_LIST


## Out of season? Kinds with a `season` ("autumn to spring") are there
## outside the summer only.
static func in_season(kind: String, days: float, lat: float) -> bool:
	var s := str(info(kind).get("season", ""))
	if s == "" or days < 0.0:
		return true
	var now := str(Seasons.at(days, lat).name)
	if s.begins_with("autumn"):
		return now != "summer"
	if s.begins_with("spring"):
		return now != "winter"
	return true


## The litter kind you'd find at your feet at `d` ("" none: ice, or a
## biome with nothing fine and dry).
static func ground_kind(world, d: Vector3, days := -1.0) -> String:
	for k in biome_list(world, d):
		var g := str(info(str(k)).get("gather", ""))
		if g in ["litter", "ground"] and in_season(str(k), days, CubeSphere.latitude(d)):
			return str(k)
	return ""


## The kind a plant of `genus` gives here ("" none).
static func plant_kind(world, d: Vector3, genus: String, days := -1.0) -> String:
	if genus == "":
		return ""
	for k in biome_list(world, d):
		var i := info(str(k))
		if str(i.get("gather", "")) in ["plant", "fungus", "lichen"] and genus in (i.get("genera", []) as Array) and in_season(str(k), days, CubeSphere.latitude(d)):
			return str(k)
	return ""


## A kindling thing: a kind that is also a fuel (grass, reeds) is the fuel
## item itself; any other is a `kindling` item.
static func make(kind: String) -> Dictionary:
	var i := info(kind)
	if bool(i.get("fuel_kind", false)):
		return Inventory.make("fuel", {"fuel": kind, "title": FireStore.pretty(kind).capitalize(),
			"carry_items": int((FireStore.KINDS.get(kind, {}) as Dictionary).get("carry_items", 1))})
	return Inventory.make("kindling", {"kindling": kind, "title": name_of(kind), "carry_items": int(i.get("carry_items", 1))})


## The kindling kind of a carried thing ("" if it isn't kindling).
static func kind_of(it) -> String:
	if not it is Dictionary:
		return ""
	match str(it.get("kind", "")):
		"kindling":
			return str(it.get("kindling", ""))
		"fuel":
			var f := str(it.get("fuel", ""))
			return f if bool(info(f).get("fuel_kind", false)) else ""
	return ""


## Wet now? Rained on within the last wet.dry_h_game game hours.
static func is_wet(it: Dictionary, days: float) -> bool:
	return bool(it.get("wet", false)) and (days - float(it.get("wet_days", days))) * 24.0 < float((FUEL.get("wet", {}) as Dictionary).get("dry_h_game", 6.0))


## Burns damp? The kind's wet_ok (else catch_wet at or over the
## threshold).
static func wet_ok(kind: String) -> bool:
	var i := info(kind)
	if i.has("wet_ok"):
		return bool(i.wet_ok)
	return float(i.get("catch_wet", 0.0)) >= float((D.get("catch", {}) as Dictionary).get("wet_threshold", 0.5))


## Seconds until the flame takes: time_s_max x (1 - catch).
static func catch_s(kind: String, wet: bool) -> float:
	var i := info(kind)
	var c := float(i.get("catch_wet" if wet else "catch_dry", 0.5))
	return float((D.get("catch", {}) as Dictionary).get("time_s_max", 2.0)) * clampf(1.0 - c, 0.0, 1.0)


static func burn_s(kind: String) -> float:
	return float(info(kind).get("burn_s", 20.0))


## Rain on what you carry (main, each frame it rains on you outside a
## roof): with the pouch (§CO, the default) nothing; without it, every
## kindling thing is wet from now.
static func rain_on(inv: Inventory, days: float) -> void:
	if bool(D.get("pouch_keeps_dry", true)):
		return
	for it in inv.carried:
		if kind_of(it) != "":
			it["wet"] = true
			it["wet_days"] = days


## The carry slot of the kindling to lay: dry before wet, a kindling
## item before a bundle of fuel (you'd rather keep the grass to burn).
static func best_slot(inv: Inventory, days: float) -> int:
	var best := -1
	var best_v := -1
	for i in inv.carried.size():
		var it = inv.carried[i]
		var k := kind_of(it)
		if k == "":
			continue
		var v := (2 if not is_wet(it, days) else (1 if wet_ok(k) else 0)) * 2 + (1 if str(it.kind) == "kindling" else 0)
		if v > best_v:
			best_v = v
			best = i
	return best


## Gathered now: damp if it rains on you outside a roof (§CO; soaked
## ground alone doesn't wet kindling).
static func gathered(it: Dictionary, raining: bool, under_roof: bool, days: float) -> bool:
	var wet := raining and not under_roof
	if wet:
		it["wet"] = true
		it["wet_days"] = days
	return wet


static func count(inv: Inventory) -> int:
	var n := 0
	for it in inv.carried:
		if kind_of(it) != "":
			n += 1
	return n
