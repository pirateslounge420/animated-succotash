extends SceneTree
## Plants are the keys (design §GK.2-3, queue 116 amended; SongKeys,
## CrawlerAreas, data/song_web.json, crawler.json areas.keys, arrive),
## headless:
##   godot --headless --path . --fixed-fps 60 --script tools/song_keys_check.gd
## Asserts, from a new game (SEED=7):
##  1. the platter by the hub fire holds the three keys (cactus, mushroom,
##     vine); no song is known, and the fire only says to bring a plant;
##  2. the interact button by the platter, looking at the cactus, takes a
##     cactus cutting; the other two stay (in the save);
##  3. given to the shaman, he takes it, the desert's song is known, and
##     he sings it at once, you sitting at the fire, its glimpse in the
##     flames;
##  4. the mushroom: its stand-in realm (the dark caves) is sung, its colour
##     in the flames, no glimpse; the fire takes no one there; scrolling
##     back to the desert opens its glimpse;
##  5. stepping into the desert: sound first: near-dark with the realm's own
##     sounds playing and no music, then its music, then the picture, in
##     that order; you stand by its hearth;
##  6. the desert grows its three keys (cactus, root, leaf) on its floor
##     away from its hearth; a root cutting taken once a visit;
##  7. home by its hearth, the root given: the root world's song is known;
##     a cutting of a known song stays in your pack and the shaman just
##     sings;
##  8. Continue keeps the songs and the platter; a game kept before §GK
##     (songs ["first"]) reads it as the desert's song.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(main: CrawlerMain) -> void:
	var w := 0
	while main.leaving and w < 3000:
		await process_frame
		w += 1
	await _frames(5)


func _boot(seed_env: String) -> CrawlerMain:
	OS.set_environment("SEED", seed_env)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while (not main.on_surface or main.leaving) and w < 3000:
		await process_frame
		w += 1
	await _frames(5)
	return main


## Stand `from_m` from `at`, facing it.
func _face(main: CrawlerMain, at: Vector3, from_m: float, ground: Callable) -> void:
	var pp := main.player.global_position
	var away := Vector2(pp.x - at.x, pp.z - at.z)
	away = away.normalized() if away.length() > 0.05 else Vector2(1, 0)
	var p2 := Vector2(at.x, at.z) + away * from_m
	var pos := Vector3(p2.x, float(ground.call(p2.x, p2.y)), p2.y)
	var to := Vector2(at.x - p2.x, at.z - p2.y)
	main.player.spawn_flat(pos, atan2(-to.x, -to.y), atan2(at.y - (pos.y + 1.55), to.length()))
	await _frames(2)


func _cuttings(inv: Inventory) -> Array:
	return inv.carried.filter(func(it): return it is Dictionary and str(it.get("kind", "")) == "key_cutting").map(func(it): return str(it.key))


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Torch.burn_down = false
	var main := await _boot("7")
	main.player.set_physics_process(false)
	main.player.inventory.add(Inventory.make("torch"))
	var hub := main.surface as HubCamp
	var ar_ := main.areas
	var sk := main.song_keys
	var desert := SongKeys.realm_of("cactus")
	var hg := func(x: float, z: float) -> float: return hub.land.height_at(x, z)
	# 1. The platter.
	await _frames(3)
	var plat := sk._platter
	var on_plat := sk._plants().map(func(g): return str(g.key))
	ok(plat != null and plat.is_inside_tree() and on_plat == ["cactus", "mushroom", "vine"] and SongKeys.platter() == ["cactus", "mushroom", "vine"], "a new game: the platter by the hub fire holds %s" % str(on_plat))
	var fd := Vector2(plat.global_position.x - hub.camp.pos.x, plat.global_position.z - hub.camp.pos.z).length()
	ok(fd < 2.5, "the platter %.1f m from the fire" % fd)
	ok(CrawlerAreas.known().is_empty() and not ar_.can_go(), "no song known yet")
	await _face(main, hub.camp.pos, 2.4, hg)
	GameLog.entries.clear()
	ok(ar_.interact() and not ar_.sitting and str(GameLog.entries[-1].text).contains("Bring him a plant"), "at the fire with no song: \"%s\"" % str(GameLog.entries[-1].text))
	# 2. Take the cactus.
	var cactus: Node3D = plat.get_children().filter(func(c): return c.has_meta("key") and str(c.get_meta("key")) == "cactus")[0]
	await _face(main, cactus.global_position, 1.1, hg)
	ok(ar_.interact() and _cuttings(main.player.inventory) == ["cactus"], "looking at the cactus, the interact button takes a cactus cutting")
	await _frames(2)
	ok(sk._plants().map(func(g): return str(g.key)) == ["mushroom", "vine"] and SongKeys.platter() == ["mushroom", "vine"], "the mushroom and the vine stay on the platter (and in the save)")
	# 3. Give it to the shaman.
	await _face(main, hub.shaman.global_position + Vector3(0, 1.2, 0), 1.6, hg)
	ok(ar_.interact() and sk.gives == 1 and _cuttings(main.player.inventory).is_empty(), "the shaman takes the cutting")
	await _frames(100)
	var light := hub.fire.get_node_or_null("Light") as OmniLight3D
	ok(CrawlerAreas.known() == [desert] and ar_.sitting and ar_.realm == desert and ar_.song_playing(), "he teaches the desert's song and sings it, you sitting at the fire")
	ok(ar_.glimpse_shown() > 0.9 and light.light_color.is_equal_approx(CrawlerAreas.realm_colour(desert)), "its colour in the flames, its glimpse open (%.2f)" % ar_.glimpse_shown())
	ar_.stand()
	await _frames(3)
	# 4. The mushroom: a stand-in realm.
	var mush: Node3D = plat.get_children().filter(func(c): return c.has_meta("key") and str(c.get_meta("key")) == "mushroom")[0]
	await _face(main, mush.global_position, 1.1, hg)
	ar_.interact()
	await _face(main, hub.shaman.global_position + Vector3(0, 1.2, 0), 1.6, hg)
	ar_.interact()
	await _frames(100)
	var caves := SongKeys.realm_of("mushroom")
	ok(CrawlerAreas.known() == [desert, caves] and ar_.realm == caves and ar_.song_playing(), "the mushroom teaches the dark caves' song, sung at once")
	ok(light.light_color.is_equal_approx(CrawlerAreas.realm_colour(caves)) and ar_.glimpse_shown() == 0.0 and CrawlerAreas.stand_in(caves), "a realm not made yet: its colour in the flames, no glimpse")
	GameLog.entries.clear()
	ar_.step_in()
	await _frames(5)
	ok(ar_.sitting and main.surface == hub and not main.leaving and str(GameLog.entries[-1].text).contains("not made"), "the fire takes no one there: \"%s\"" % str(GameLog.entries[-1].text))
	ar_.scroll(-1)
	await _frames(100)
	ok(ar_.realm == desert and ar_.glimpse_shown() > 0.9, "scrolling back to the desert opens its glimpse")
	# 5. Step in: sound first.
	ar_.step_in()
	var seen := []
	var dark_ok := true
	var music_ok := true
	var w := 0
	while (main.leaving or w < 2) and w < 3000:
		await process_frame
		w += 1
		var ph := ar_.arrive_phase
		if ph != "" and (seen.is_empty() or seen[-1] != ph):
			seen.append(ph)
		if ph == "dark":
			var snd: bool = main.surface != hub and main.surface._sounds.values().any(func(a): return (a as AudioStreamPlayer).playing)
			dark_ok = dark_ok and main._fade.color.a > 0.9 and not ar_.arrival_music_playing() and snd
		if ph == "music" and (not ar_.arrival_music_playing() or main._fade.color.a < 0.9):
			music_ok = false
	ok(seen == ["dark", "music", "picture"], "arriving: %s" % str(seen))
	ok(dark_ok, "first near-dark, the realm's own sounds playing, no music yet")
	ok(music_ok, "then its music, the frame still dark")
	ok(main._fade.color.a < 0.01 and ar_.arrival_music_playing(), "then the picture; the music still playing, fading out")
	var area := main.surface
	var hp := area.area_hearth.global_position
	var pp := main.player.global_position
	ok(area == main.area_node and Vector2(pp.x - hp.x, pp.z - hp.z).length() < 4.0, "by the desert's hearth")
	# 6. Its three keys.
	await _frames(3)
	var grown := sk._growing.map(func(g): return str(g.key))
	grown.sort()
	var want := SongKeys.offers(desert).duplicate()
	want.sort()
	var near := 999.0
	for g in sk._growing:
		var q: Vector3 = (g.node as Node3D).global_position
		near = minf(near, Vector2(q.x - hp.x, q.z - hp.z).length())
	ok(grown == want and want == ["cactus", "leaf", "root"], "the desert grows its keys: %s" % str(grown))
	ok(near >= 17.9 and sk._growing.all(func(g): return area.land.inside(Vector2((g.node as Node3D).global_position.x, (g.node as Node3D).global_position.z), 0.0)), "on its floor, the nearest %.0f m from its hearth" % near)
	var ag := func(x: float, z: float) -> float: return area.land.height_at(x, z)
	var root_g: Dictionary = sk._growing.filter(func(g): return str(g.key) == "root")[0]
	await _face(main, (root_g.node as Node3D).global_position, 1.2, ag)
	ok(ar_.interact() and _cuttings(main.player.inventory) == ["root"], "a root cutting from the root plant")
	ar_.interact()
	ok(_cuttings(main.player.inventory) == ["root"], "one cutting a plant a visit")
	var cac_g: Dictionary = sk._growing.filter(func(g): return str(g.key) == "cactus")[0]
	await _face(main, (cac_g.node as Node3D).global_position, 1.2, ag)
	ar_.interact()
	# 7. Home, and give the root.
	main.player.spawn_flat(hp + Vector3(1.5, 0.0, 0.0), 0.0, 0.0)
	await _frames(2)
	ar_.interact()
	await _settle(main)
	ok(main.surface == main.hub_node, "home by the desert's hearth")
	await _face(main, hub.shaman.global_position + Vector3(0, 1.2, 0), 1.6, hg)
	ar_.interact()
	await _frames(5)
	var rootw := SongKeys.realm_of("root")
	ok(CrawlerAreas.known() == [desert, caves, rootw] and ar_.realm == rootw and _cuttings(main.player.inventory) == ["cactus"], "the root given: the root world's song (%s known)" % str(CrawlerAreas.known()))
	ar_.stand()
	await _frames(2)
	ar_.interact()
	await _frames(2)
	ok(ar_.sitting and sk.gives == 3 and _cuttings(main.player.inventory) == ["cactus"], "a cutting of a song you know stays in your pack; he just sings")
	ar_.stand()
	CrawlerSave.save()
	# 8. Continue.
	main.queue_free()
	await _frames(3)
	var main2 := await _boot("")
	await _frames(3)
	ok(CrawlerSave.continued and CrawlerAreas.known() == [desert, caves, rootw] and SongKeys.platter() == ["vine"] and main2.song_keys._plants().map(func(g): return str(g.key)) == ["vine"], "Continue: three songs known, the vine alone on the platter")
	CrawlerSave.data["songs"] = ["first"]
	ok(CrawlerAreas.known() == [desert], "a game kept before §GK: its song is the desert's")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
