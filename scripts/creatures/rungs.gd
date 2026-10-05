class_name Rungs
extends RefCounted
## Creature rungs (design 4 Oct §ED.5, data/creatures/rungs.json). Every
## species is to get three: common (creatures.json as is); rare, the same
## mesh with only its tint changed (a white hare, a black wolf), at
## rare.chance; mythic, a changed silhouette with its own voice and
## multipliers on the numbers the species already carries (speed_mps,
## shy_m, notice range, territory, size), at mythic.chance, so it is harder
## to slip away from. Only the species rungs.json lists roll (two for now:
## the hare and its jackalope, the wolf and its dire wolf); the rest are a
## data fill. A species entry matches by name, or by its last word
## ("Arctic wolf" is a wolf).
##
## Creature.setup rolls each animal's rung from its own seed (roll()),
## builds from the varied species (variant()) and dresses the mythic's
## silhouette (dress()). A mythic's voice carries voice_range_x times as
## far as it can see you (voice_range()): a howl alone is the first tell,
## and the log keeps it as "something out there" (heard()); seeing a rare
## or a mythic writes it once (seen()).

static var D: Dictionary = Tuning.table("rungs")
## Tools: force every listed species to this rung ("rare", "mythic").
static var force := ""


static func defaults(rung: String) -> Dictionary:
	return (D.get("defaults", {}) as Dictionary).get(rung, {})


## The rungs.json entry for species `sp` ({} when it has none).
static func entry(sp: CreatureSpecies) -> Dictionary:
	var all: Dictionary = D.get("species", {})
	if all.has(sp.name):
		return all[sp.name]
	if sp.role == "mythical":
		return {}
	var words := sp.name.split(" ")
	var last := words[words.size() - 1].to_lower()
	for k in all:
		if str(k).to_lower() == last:
			return all[k]
	return {}


## This animal's rung, from its seed: "common", "rare" or "mythic".
static func roll(sp: CreatureSpecies, seed_value: int) -> String:
	if sp.has_meta("rung_of"):
		return "common"
	var e := entry(sp)
	if e.is_empty():
		return "common"
	if force != "" and e.has(force):
		return force
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, sp.name, "rung"])
	var r := rng.randf()
	var m := float((e.get("mythic", {}) as Dictionary).get("chance", defaults("mythic").get("chance", 0.002)))
	var rr := float((e.get("rare", {}) as Dictionary).get("chance", defaults("rare").get("chance", 0.02)))
	if e.has("mythic") and r < m:
		return "mythic"
	if e.has("rare") and r < m + rr:
		return "rare"
	return "common"


## A copy of `sp` for `rung`: the rare's tint; the mythic's name, voice,
## and its multipliers on the species' own numbers.
static func variant(sp: CreatureSpecies, rung: String) -> CreatureSpecies:
	if rung == "common":
		return sp
	var e := entry(sp)
	var v := CreatureSpecies.new()
	for p in sp.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var val = sp.get(p.name)
		if val is Dictionary or val is Array:
			val = val.duplicate(true)
		v.set(p.name, val)
	var r: Dictionary = e.get(rung, {})
	if rung == "rare":
		v.color = Color(str(r.get("tint", sp.color.to_html())))
		v.set_meta("rung_note", str(r.get("note", "rare morph")))
		v.set_meta("rung_of", sp.name)
		return v
	var dm := defaults("mythic")
	var x := func(k: String) -> float: return float(r.get(k, dm.get(k, 1.0)))
	v.name = str(r.get("name", sp.name))
	v.sound = str(r.get("voice", sp.sound))
	v.speed_mps = sp.speed_mps * x.call("speed_x")
	v.shy_m = sp.shy_m * x.call("shy_x")
	v.territory_m = sp.territory_m * x.call("territory_x")
	v.size_m = sp.size_m * x.call("size_x")
	if not v.pack.is_empty():
		v.pack["notice_m"] = float(v.pack.get("notice_m", 60.0)) * x.call("notice_x")
		v.pack["territory_m"] = float(v.pack.get("territory_m", 200.0)) * x.call("territory_x")
	v.set_meta("rung_of", sp.name)
	v.set_meta("guardian", bool(r.get("guardian", false)))
	v.set_meta("silhouette", str(r.get("silhouette", "")))
	return v


## How far this animal sees you (m): its notice range, else its shyness.
static func sight_m(sp: CreatureSpecies) -> float:
	return maxf(float(sp.pack.get("notice_m", 0.0)) if not sp.pack.is_empty() else 0.0, maxf(sp.shy_m, 20.0))


## How far a mythic's voice carries (m): voice_range_x times its sight.
static func voice_range(sp: CreatureSpecies) -> float:
	var e := entry_of_variant(sp)
	var r: Dictionary = e.get("mythic", {})
	return sight_m(sp) * float(r.get("voice_range_x", defaults("mythic").get("voice_range_x", 2.0)))


## The entry of a variant (its rung_of name) or a species.
static func entry_of_variant(sp: CreatureSpecies) -> Dictionary:
	if sp.has_meta("rung_of"):
		var all: Dictionary = D.get("species", {})
		var of := str(sp.get_meta("rung_of"))
		if all.has(of):
			return all[of]
		var words := of.split(" ")
		var last := words[words.size() - 1].to_lower()
		for k in all:
			if str(k).to_lower() == last:
				return all[k]
	return entry(sp)


## The mythic's changed silhouette on the body `parts` (CreatureBodies):
## the jackalope's pronged antlers on the hare's head, the dire wolf's
## heavier head and chest. Matched on the silhouette's words, so a data
## fill can reuse them.
static func dress(parts: Dictionary, sp: CreatureSpecies) -> void:
	var sil := str(sp.get_meta("silhouette", "")).to_lower()
	if sil == "":
		return
	var root: Node3D = parts.root
	var head := root.find_child("Head", true, false) as Node3D
	var horn := Color(0.78, 0.7, 0.55)
	if sil.find("antler") >= 0:
		var at := head if head != null else root
		var base := Vector3(0, 0.08, 0.0) if head != null else Vector3(0, 0.42, -0.36)
		for s: float in [-1.0, 1.0]:
			var beam := CreatureBodies.cone(at, 0.016, 0.008, 0.22, base + Vector3(0.05 * s, 0.1, 0.02), horn, 0.0, 5)
			beam.rotation = Vector3(-0.25, 0.0, -0.45 * s)
			var tine := CreatureBodies.cone(at, 0.011, 0.0, 0.11, base + Vector3(0.1 * s, 0.17, -0.04), horn, 0.0, 5)
			tine.rotation = Vector3(0.6, 0.0, -0.2 * s)
			var tine2 := CreatureBodies.cone(at, 0.009, 0.0, 0.09, base + Vector3(0.13 * s, 0.2, 0.05), horn, 0.0, 5)
			tine2.rotation = Vector3(-0.5, 0.0, -0.7 * s)
	if sil.find("heavier") >= 0 or sil.find("chest") >= 0:
		var fur := sp.color.darkened(0.15)
		if head != null:
			head.scale *= 1.3
		# A deep ruff at the chest, the shoulders built up.
		CreatureBodies.ball(root, Vector3(0.17, 0.17, 0.16), Vector3(0, 0.62, -0.26), fur)
		CreatureBodies.ball(root, Vector3(0.16, 0.12, 0.2), Vector3(0, 0.74, -0.14), fur)


## Seen: a rare or a mythic in sight writes the log once per kind.
static func seen(sp: CreatureSpecies, rung: String) -> void:
	if rung == "rare":
		GameLog.add_once("seen:%s:rare" % sp.name, "A %s %s." % [str(sp.get_meta("rung_note", "rare")).replace(" morph", ""), sp.name.to_lower()], "sighting")
	elif rung == "mythic":
		GameLog.add_once("seen:%s" % sp.name, "A %s. It saw you first." % sp.name.to_lower(), "sighting")


## Heard: a mythic's voice from beyond sight writes "something out there"
## once.
static func heard(sp: CreatureSpecies) -> void:
	GameLog.add_once("heard:%s" % sp.name, "Something out there.", "sighting")


## What lurks in the dark (design 4 Oct §ED.7, §CU): in this game (the
## ambient profile) the hostile mythic things of the night (the werewolf,
## the night rider, the skinwalker, the pond crawler and their kind), not
## the guardians, who are flesh and blood. Edges never touch them.
static func of_the_dark(sp: CreatureSpecies) -> bool:
	if Tuning.profile() != "ambient" or sp.has_meta("rung_of"):
		return false
	return sp.role == "mythical" and sp.temperament in ["hostile", "aggressive"]

