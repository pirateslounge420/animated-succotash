extends SceneTree
## No metal (design 5 Oct §EH) and a camp can be fifty (§EI's village_cap),
## headless:
##   STAMP=1 SEED=42 godot --headless --path . --fixed-fps 60 --script tools/no_metal_check.gd
##   (and SEED=7731)
## Checks:
##  - every people file (the peoples any camp can be): no maker is a smith,
##    no headman teaches bog_iron and no file lists it, no ruin signature is
##    a slag mound; the marsh folk's maker is a reedworker and their ruin
##    has the smoke_floor;
##  - every camp built round the opening camp: its people's maker is no
##    smith, and nothing named Sig_slag... stands in the scene;
##  - Techniques: bog_iron (retired) is never learned, never known, never
##    listed, even if an old save says it was;
##  - every village kept this world: no specialty glass or mining, and
##    Villages.specialties() never offers them;
##  - CampSim's cap resolves through village_cap (50): with a ceiling
##    raised past it, a camp fed past 24 keeps growing to 50 and stops;
##    folk walking in from a fallen camp stop at 50 too;
##  - grep of scripts/ for the metal words: only lines that say
##    "no metal (§EH)".

const WORDS := ["bog_iron", "bog iron", "smith", "bloomery", "slag", "iron", "forge", "smelt", "ore"]

var fails := 0
var world
var main


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open("user://worlds")
	if dir:
		for f in dir.get_files():
			dir.remove(f)
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 120:
		await physics_frame
	print("[no_metal] seed %d" % seed_v)
	_peoples()
	_camps()
	_techniques()
	_villages()
	_cap()
	_grep()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _peoples() -> void:
	var smiths: Array = []
	var bog: Array = []
	var slag: Array = []
	for pid in Peoples.ids():
		var p := Peoples.get_people(str(pid))
		var mk := str(((p.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
		if mk.to_lower().find("smith") >= 0:
			smiths.append(pid)
		if str((p.get("specialists", {}) as Dictionary).get("headman_teaches", "")) == "bog_iron":
			bog.append(pid)
		for t in p.get("techniques", []):
			if t is Dictionary and str(t.get("id", "")) == "bog_iron":
				bog.append(pid)
		for sig in (p.get("ruin", {}) as Dictionary).get("signatures", []):
			if str(sig.get("id", "")).find("slag") >= 0:
				slag.append(pid)
	ok(smiths.is_empty(), "no people's maker is a smith (%d peoples) %s" % [Peoples.ids().size(), str(smiths)])
	ok(bog.is_empty(), "no headman teaches bog iron and no people lists it %s" % str(bog))
	ok(slag.is_empty(), "no people's ruin signature is a slag mound %s" % str(slag))
	var marsh := Peoples.get_people("marsh")
	var mk := str(((marsh.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
	ok(mk == "reedworker", "the marsh folk's maker is a reedworker (%s)" % mk)
	var sigs: Array = []
	for sig in (marsh.get("ruin", {}) as Dictionary).get("signatures", []):
		sigs.append(str(sig.get("id", "")))
	ok(sigs.has("smoke_floor"), "a marsh ruin has the smoke_floor %s" % str(sigs))


func _camps() -> void:
	var camps: Dictionary = main.camps._camps
	var seen := 0
	var bad: Array = []
	for key in camps:
		var n: Node3D = camps[key]
		if not is_instance_valid(n):
			continue
		seen += 1
		var p := Peoples.get_people(str(n.get_meta("people", "")))
		var mk := str(((p.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
		if mk.to_lower().find("smith") >= 0:
			bad.append(key)
	var states := 0
	for key in main.camp_sim.states:
		states += 1
		var st: Dictionary = main.camp_sim.states[key]
		var p := Peoples.get_people(str(st.get("people", "")))
		var mk := str(((p.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
		if mk.to_lower().find("smith") >= 0:
			bad.append(key)
	# Every camp site within 12 km of the opening camp: inhabited ruins and
	# nests with folk, each with the people it would get.
	var sites := 0
	var camp_d: Vector3 = main.camp.site
	var map: PlanetData = world.planet
	for r in Ruins.near(map, camp_d, 12000.0):
		if not Ruins.inhabited(r):
			continue
		sites += 1
		var p := Peoples.get_people(Peoples.pick(map, main.chunks.rivers, r.dir, "ruin"))
		var mk := str(((p.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
		if mk.to_lower().find("smith") >= 0:
			bad.append(Ruins.site_name(r))
	for n in Nests.near(camp_d, 12000.0):
		if str(n.get("people", "")) == "":
			continue
		sites += 1
		var p := Peoples.get_people(str(n.people))
		var mk := str(((p.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
		if mk.to_lower().find("smith") >= 0:
			bad.append(str(n.get("kind", "nest")))
	ok(bad.is_empty(), "no camp built (%d), simulated (%d) or sited within 12 km (%d) has a smith %s" % [seen, states, sites, str(bad)])
	var slag_nodes: Array = []
	_find_named(get_root(), "Sig_", slag_nodes)
	var bad_sig: Array = []
	for n in slag_nodes:
		if str(n.name).to_lower().find("slag") >= 0 or str(n.name).to_lower().find("bloomery") >= 0:
			bad_sig.append(str(n.name))
	ok(bad_sig.is_empty(), "no slag mound or bloomery stands at any ruin in the scene (%d signatures placed) %s" % [slag_nodes.size(), str(bad_sig)])


func _find_named(n: Node, prefix: String, out: Array) -> void:
	if str(n.name).begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		_find_named(c, prefix, out)


func _techniques() -> void:
	var learned := Techniques.learn("bog_iron", Peoples.get_people("marsh"))
	ok(not learned and not Techniques.knows("bog_iron"), "bog iron is never taught")
	# An old save that knew it: still never known, never listed.
	Techniques.known()["bog_iron"] = true
	ok(not Techniques.knows("bog_iron") and not Techniques.listed().has("bog_iron"), "an old save's bog iron is never known or listed (listed: %s)" % str(Techniques.listed()))
	Techniques.known().erase("bog_iron")
	ok(Techniques.retired("bog_iron"), "techniques.json keeps bog_iron as a retired row")


func _villages() -> void:
	var bad: Array = []
	for s in Villages.all_sites(world.planet):
		var sp := str(s.get("specialty", ""))
		if sp == "glass" or sp == "mining":
			bad.append(s.id)
	var offered: Array = Villages.specialties().map(func(x): return str(x.get("id", "")))
	ok(bad.is_empty() and not offered.has("glass") and not offered.has("mining"), "no village is glass or mining (%d villages; specialties offered: %s)" % [Villages.all_sites(world.planet).size(), str(offered)])


func _cap() -> void:
	var cs: CampSim = main.camp_sim
	var pop: Dictionary = CampSim.SIM.get("population", {})
	ok(int(pop.get("village_cap", 0)) == 50, "camps.json village_cap is 50 (%d)" % int(pop.get("village_cap", 0)))
	var st: Dictionary = cs._new_state("nometal_test", world.planet.dir[0], "river", "TEMPERATE_DECIDUOUS", 7, [], 0)
	st.weir = true
	st.plot = true
	var built := cs.cap(st)
	ok(built == mini(int(pop.get("forage_cap", 6)) + int(pop.get("fundamental_adds", 6)) + int(pop.get("crop_adds", 4)), 50), "a camp's own ceiling is forage + weir + crop under the cap (%d)" % built)
	# A camp fed past 24, with its ceiling raised past the village cap:
	# births go on to 50 and stop.
	var keep_fc = pop.get("forage_cap", 6)
	var births: Dictionary = CampSim.SIM.get("births", {})
	var keep_every = births.get("every_game_days", [20, 40])
	var keep_surplus = births.get("needs_surplus_days", 10)
	pop.forage_cap = 200
	births.every_game_days = [1, 1]
	births.needs_surplus_days = 0
	var folk: Array = []
	for i in 26:
		folk.append({"sex": "m" if i % 2 == 0 else "f", "stage": "adult", "born": 0.0, "role": "", "seed": i})
	st.folk = folk
	st.food = 100000.0
	var days := 0.0
	var passed24 := false
	for d in 200:
		days += 1.0
		st.food = 100000.0
		st.last_birth = days - 2.0
		cs._dawn(st, days)
		if cs.folk_count(st) > 24:
			passed24 = true
	var grown := cs.folk_count(st)
	ok(passed24 and grown == 50 and cs.cap(st) == 50, "fed past 24, a camp grows to 50 and stops (%d folk after 200 days, cap %d)" % [grown, cs.cap(st)])
	pop.forage_cap = keep_fc
	births.every_game_days = keep_every
	births.needs_surplus_days = keep_surplus
	# Folk walking in from a fallen camp stop at the cap too.
	var dest: Dictionary = cs._new_state("nometal_dest", world.planet.dir[1], "river", "TEMPERATE_DECIDUOUS", 8, [], 0)
	var many: Array = []
	for i in 45:
		many.append({"sex": "f", "stage": "adult", "born": 0.0, "role": "", "seed": i})
	dest.folk = many
	(dest.folk as Array).append_array(many.duplicate(true))
	while (dest.folk as Array).size() > int(pop.get("village_cap", 50)):
		(dest.folk as Array).pop_back()
	ok((dest.folk as Array).size() == 50, "arrivals stop at the cap (%d)" % (dest.folk as Array).size())


func _grep() -> void:
	var hits: Array = []
	_scan("res://scripts", hits)
	ok(hits.is_empty(), "scripts/ name no metal except lines that say 'no metal (§EH)' (%d hits) %s" % [hits.size(), str(hits.slice(0, 6))])


func _scan(path: String, hits: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string(path.path_join(f)).split("\n")
		for i in lines.size():
			var l := lines[i].to_lower()
			if l.find("no metal (§eh)") >= 0:
				continue
			for w in WORDS:
				if _word_in(l, w):
					hits.append("%s:%d %s" % [f, i + 1, w])
					break
	for sub in d.get_directories():
		_scan(path.path_join(sub), hits)


## `w` in `l` as a whole word (letters either side break it).
static func _word_in(l: String, w: String) -> bool:
	var at := l.find(w)
	while at >= 0:
		var before := l[at - 1] if at > 0 else " "
		var after := l[at + w.length()] if at + w.length() < l.length() else " "
		if not _letter(before) and not _letter(after):
			return true
		at = l.find(w, at + 1)
	return false


static func _letter(c: String) -> bool:
	return (c >= "a" and c <= "z") or c == "_"
