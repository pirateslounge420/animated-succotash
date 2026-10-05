extends SceneTree
## The opening is a river camp (design 4 Oct §ED.1, camps.json
## first_camp.river_camp), on the full planet with the play rules:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/river_camp_check.gd
## Asserts: the camp lies in the temperate band of the hemisphere in spring
## or summer on day one; its fire stands within within_m of a river that
## runs on flow_m both ways; 4-5 folk sit at it inside old walls; the
## opening road leads to a people's camp and a second road leaves the
## other way; you wake holding an unlit torch, with no spear or bow laid
## or worn (§ED.7).

var main
var world
var player: PlanetPlayer
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, -1)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	var rc := Encampment.river_rule()
	ok(not rc.is_empty(), "camps.json first_camp.river_camp is on")
	var site: Vector3 = main.camp.site
	var lat := rad_to_deg(CubeSphere.latitude(site))
	var band: Array = rc.get("lat_deg", [28, 52])
	var sign := Encampment.summer_sign()
	print("[river_camp] seed %d: %s camp at %.2f°%s, summer hemisphere %s (declination %.1f°)" % [seed_v, world.first_camp_kind, absf(lat), "N" if lat >= 0 else "S", "north" if sign > 0 else "south", rad_to_deg(Astro.declination(world.START_DAYS))])
	ok(lat * sign >= float(band[0]) and lat * sign <= float(band[1]), "in the temperate band of the summer hemisphere (%.1f° in %s)" % [lat, str(band)])
	var rivers: RiverNetwork = main.chunks.rivers
	var best := INF
	var best_s := -1
	for s in rivers.segments_near(world.planet, world.planet.cell_at(site)):
		var dm := rivers.closest_dt(s, site).x - rivers.width[s] * 0.5
		if dm < best:
			best = dm
			best_s = s
	ok(best <= float(rc.get("within_m", 140.0)) + 10.0, "the fire stands by a river (%.0f m from its bank)" % best)
	if best_s >= 0:
		var runs := Encampment.river_runs(rivers, best_s, float(rc.get("flow_m", 2500.0)))
		ok(runs.x >= float(rc.get("flow_m", 1000.0)) and runs.y >= float(rc.get("flow_m", 1000.0)), "the river runs on both ways (%.0f m up, %.0f m down)" % [runs.x, runs.y])
	var folk: int = main.camp._npcs.size()
	var fr: Array = rc.get("folk", [4, 5])
	ok(folk >= int(fr[0]) and folk <= int(fr[1]), "%d folk at the hearth" % folk)
	ok(main.camp.find_child("OldWalls", true, false) != null, "the hearth stands inside old walls")
	var roads: RoadNetwork = main.chunks.roads
	var opening_link := false
	var back_link := false
	for l in roads.links_near(site, 15000.0, true):
		opening_link = opening_link or bool(l.get("opening", false))
		back_link = back_link or bool(l.get("opening_back", false))
	ok(opening_link, "the opening road leads to a people's camp")
	ok(back_link or world.opening.get("back", Vector3.ZERO) == Vector3.ZERO, "a second road leaves the other way (%s)" % ("routed" if back_link else "no ruin that way"))
	ok(player.inventory.has_kind("torch") and player.in_hand() == "torch", "you wake holding a torch (%s)" % player.in_hand())
	ok(not player.wears("melee", "spear") and not player.wears("ranged", "bow") and main._gifts.is_empty(), "no spear or bow laid or worn (§ED.7)")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
