extends SceneTree
## The walkabout (design 1 Oct §CA, data/habitat.json walkabout): the end
## of every visual pass, in place of the dev frame. One seed per run:
##
##   SEED=101 xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/walkabout.gd
##
## First person at the player's eye (eye_m), at the play preset. The sites
## per seed (sites_per_seed): the opening camp at the spawn hour, a point
## 1 km down the first road, and three random sites in three different
## biomes (BIOMES=SAVANNA,TAIGA,BOG picks them; else a savanna, a forest
## and a wetland rotate in across seeds). At each site: `facings` ways
## round, at each of `hours` (solar hour and weather). Frames go to
## tools/reference/walkabout/<seed>/<site>_<HH>h_f<k>.png and the report
## lines to tools/reference/walkabout/walkabout.txt (RESET=1 starts it
## over): per site the biome, the soil, every species within list_within_m
## with its files, and PASS/FAIL. A species standing in a biome that does
## not list it FAILS the site (unlisted_species_allowed). The opening
## camp's first frame must be dawn (design 3 Oct §CY.1: within the first
## minutes after dawn begins).
## WIND=6 pins the weather's wind at 6 m/s (design §DA's breeze; else
## 1.1 m/s). SEASON=autumn walks in that season (ten days into it).
## CLOUD=0.5 sets §CX's cover (a part-cloudy day's cloud shadows).
## SITES=lake adds the nearest lake's shore, looking over the water.
## MOON=full (new, first_quarter) walks on the nearest night with that moon.
## SITES=ruins the wettest and the driest stone ruins (§DI overgrowth).
## SITES=haunt the nearest haunted graveyard (§DI.4; HOURS=22 for night).
## SITES=hidden the nearest hidden place of each kit (§DJ), from in front.
## SITES=wandering_fire the thirteen (§DP): one of their cold rings, and
## them at their fire (HOURS=19.5 for dusk).
## SITES=long_wall the nearest long wall (§DS.1): from its straight approach
## to the gate tower, and along the wall from a stretch of it.
## SITES=carved_cliffs the nearest carved cliffs (§DS.2): from the canyon
## floor along it, looking at the facades.
## SITES=cliff_dwelling the nearest cliff dwelling (§DS.4): from its plaza's
## approach, 26 m out and to one side (clear of the delve's way out),
## looking into the alcove (SEED=8 has one).
## SITES=brick_city the nearest brick city (§DS.6): down its processional
## way toward the blue gate (SEED=8 has one).
## SITES=stone_heads the stone heads (§DS.3): 30 m inland of them, looking
## at their faces with the sea behind.
## SITES=terraced_pueblo the nearest terraced pueblo (§DS.5): from beyond its
## plaza, looking up its terraces (SEED=8 has one).
## SITES=stone_circle the nearest stone circle (§DS.7): from its causeway
## through the bank (SEED=8 has one).
## SITES=hewn_temple the nearest hewn temple (§DZ): on the rim of its pit
## at the front, looking down at the temple (SEED=7731 has one).
## SITES=northern the nearest tower house and the nearest broch (§DS): the
## keep from beyond its barmkin's gate, the broch from before its door with
## the souterrain's mouth to the left.
## SITES=ox_rider the old man on his ox (§DQ): passing him on his road at
## his own midday (HOURS=12), and the gate at his pass.
## SITES=temple_city the nearest temple city (§DR), from its straight
## approach: at the head of its causeway, 4 m out, looking at its gate.
## SITES=shrine the nearest shrine (§DK): its court and the way down, the
## hall from near its top, and the altar room by torchlight.
## SITES=at AT=lat,lon stands at that place; RH=0.95 sets the air's damp
## (design §DC's shafts; ShaftField prints its gate per frame).
## SITES=nests adds the nearest nests of four kinds (design 1 Oct §CK);
## SITES=fig the sacred fig (§CL).
## SITES=range the nearest great range (design 3 Oct §CR): from its foot,
## looking up at its summit, and from the summit, looking along the crest.
## SITES=delve the nearest overrun barrow (§CN; else the nearest with a
## delve, §CJ): from outside (bones at its door), its stairhead, the first
## room and the heart by torchlight at noon (it must be dark but for the
## torch), the heart's fire-holder laid and lit (clearing it), and the
## cairn the way out comes up in.
## SITES=opening_camp,random_biome keeps a subset; QUICK=1 one facing and
## the first hour (a smoke run). DEV_PIN=0 boots a fresh random world (no
## SEED; its frames go under the seed it rolled) and leaves no save:
##   tools/no_import_check.sh -- env QUICK=1 SITES=opening_camp xvfb-run ...

const OUT_DIR := "res://tools/reference/walkabout"
var W: Dictionary = Tuning.table("habitat").get("walkabout", {})
var fails := 0
var lines: Array[String] = []
var main
var world
var player: PlanetPlayer
var sd := 101


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func ok(cond: bool, what: String) -> void:
	var line := ("PASS  " if cond else "FAIL  ") + what
	print(line)
	lines.append(line)
	if not cond:
		fails += 1


func _run() -> void:
	world = get_root().get_node("World")
	# DEV_PIN=0 (design 1 Oct §CG: tools/no_import_check.sh runs it so): a
	# fresh random world by play's rule, no pin; the frames and the report
	# go under the seed it rolled, and its save and the last-world pointer
	# are put back as they were.
	var fresh := OS.get_environment("DEV_PIN") == "0"
	var had_pointer := FileAccess.file_exists(WorldSave.LAST_PATH)
	var old_pointer := FileAccess.get_file_as_string(WorldSave.LAST_PATH) if had_pointer else ""
	if fresh:
		if had_pointer:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSave.LAST_PATH))
	else:
		sd = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 101
		world.pin(sd, -1)
	Bow.need_capture = false
	PlanetPlayer.EYE_Y = float(W.get("eye_m", 1.6))
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	sd = world.world_seed
	seed(sd)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR.path_join(str(sd))))
	if fresh:
		var made := ProjectSettings.globalize_path("user://worlds/%d.json" % sd)
		WorldSave.read_only = true
		if FileAccess.file_exists(made):
			DirAccess.remove_absolute(made)
		if had_pointer:
			var f := FileAccess.open(WorldSave.LAST_PATH, FileAccess.WRITE)
			if f:
				f.store_string(old_pointer)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSave.LAST_PATH))
	player = main.player
	main.hud.visible = false
	player.set_physics_process(false)
	player.first_person = true
	player._apply_view()
	player.camera().current = true
	lines.append("== World %d (%s%s) — first camp: %s camp, %s" % [sd, "postage stamp" if world.postage_stamp else "full planet", ", a fresh random world (DEV_PIN=0)" if fresh else "", world.first_camp_kind if world.first_camp_kind != "" else "old list", BiomeTemplates.KEYS[world.planet.biome[world.planet.cell_at(main.camp.site)]]])
	var quick := OS.get_environment("QUICK") == "1"
	var only: Array = Array(OS.get_environment("SITES").split(",")) if OS.get_environment("SITES") != "" else []
	var hours: Array = W.get("hours", [{"solar_h": 14.0, "weather": "overcast"}, {"solar_h": 17.5, "weather": "clear"}, {"solar_h": 22.0, "weather": "clear"}])
	if quick:
		hours = [hours[0]]
	var facings := 1 if quick else int(W.get("facings", 4))
	# HOURS=9,18.6: clear solar hours instead (design §DB's flare walk).
	if OS.get_environment("HOURS") != "":
		hours = []
		for hs in OS.get_environment("HOURS").split(","):
			hours.append({"solar_h": float(hs), "weather": "clear"})
	# The sites.
	var sites: Array = []
	var spawn_days: float = world.days
	var camp_d: Vector3 = main.camp.site
	var wanted: Array = Array(OS.get_environment("BIOMES").split(",")) if OS.get_environment("BIOMES") != "" else _wanted_biomes()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sd, "walkabout"])
	var random_i := 0
	var kinds: Array = W.get("sites_per_seed", ["opening_camp", "first_road_1km", "random_biome", "random_biome", "random_biome"])
	if not only.is_empty():
		# SITES picks from these and from "nests" (design 1 Oct §CK).
		kinds = kinds.filter(func(k): return only.has(k))
		if only.has("nests"):
			kinds.append("nests")
		if only.has("fig"):
			kinds.append("fig")
		if only.has("delve"):
			kinds.append("delve")
		if only.has("lake"):
			kinds.append("lake")
		if only.has("range"):
			kinds.append("range")
		if only.has("at"):
			kinds.append("at")
		if only.has("crag"):
			kinds.append("crag")
		if only.has("ruins"):
			kinds.append("ruins")
		if only.has("haunt"):
			kinds.append("haunt")
		if only.has("hidden"):
			kinds.append("hidden")
		if only.has("shrine"):
			kinds.append("shrine")
		if only.has("temple_city"):
			kinds.append("temple_city")
		if only.has("wandering_fire"):
			kinds.append("wandering_fire")
		if only.has("ox_rider"):
			kinds.append("ox_rider")
		if only.has("long_wall"):
			kinds.append("long_wall")
		if only.has("carved_cliffs"):
			kinds.append("carved_cliffs")
		if only.has("cliff_dwelling"):
			kinds.append("cliff_dwelling")
		if only.has("brick_city"):
			kinds.append("brick_city")
		if only.has("stone_heads"):
			kinds.append("stone_heads")
		if only.has("terraced_pueblo"):
			kinds.append("terraced_pueblo")
		if only.has("stone_circle"):
			kinds.append("stone_circle")
		if only.has("northern"):
			kinds.append("northern")
		if only.has("hewn_temple"):
			kinds.append("hewn_temple")
	for kind in kinds:
		match str(kind):
			"nests":
				sites.append_array(_nest_sites(camp_d))
			"fig":
				# The sacred fig (design 1 Oct §CL), seen from the east, 24 m
				# from the trunk, the figure facing you.
				var fig := Uniques.sacred_fig(world.planet)
				if fig.is_empty():
					lines.append("-- fig: none of its biomes on this planet")
				else:
					sites.append({"name": "sacred_fig", "dir": CreatureSpawner._offset(fig.dir, PI * 0.5, 24.0), "look": fig.dir,
						"note": "the sacred fig in %s, %.0f km from the camp" % [str(fig.biome).to_lower(), CubeSphere.surface_distance_m(fig.dir, camp_d) / 1000.0]})
			"delve":
				sites.append_array(_delve_sites(camp_d))
			"range":
				sites.append_array(_range_sites(camp_d))
			"crag":
				# SITES=crag: the nearest crag fortress (design 3 Oct §DO),
				# from its approach: on the line straight out from its foot,
				# where its foot can be seen, looking up at it (§DM.5's road isn't built: this
				# stands where it will run).
				var best := {}
				var bd := INF
				for cs in CragFortress.all_sites(world.planet):
					var dd := CubeSphere.surface_distance_m(cs.dir, camp_d)
					if dd < bd:
						bd = dd
						best = cs
				if best.is_empty():
					lines.append("-- crag: no crag fortress on this planet")
					continue
				var pl: Dictionary = CragFortress.plan(world.planet, best)
				# The nearest point out along the approach (80-300 m) from
				# which the line of sight to its foot clears the ground.
				var t: TerrainField = world.planet.terrain
				var foot_d := Ruins.local_dir(best, 0.0, float(pl.front_z))
				var aim := t.elevation(foot_d, true) + float(best.rise_m) * 0.15
				var stand := Ruins.local_dir(best, 0.0, float(pl.front_z) - 160.0)
				var out_m := 160.0
				for dm in range(80, 320, 20):
					var sd := Ruins.local_dir(best, 0.0, float(pl.front_z) - dm)
					var eye := t.elevation(sd, true) + 1.6
					var clear := true
					for k in range(1, 12):
						var f := k / 12.0
						var pd := Ruins.local_dir(best, 0.0, float(pl.front_z) - dm * (1.0 - f))
						if t.elevation(pd, true) > lerpf(eye, aim, f):
							clear = false
							break
					if clear:
						stand = sd
						out_m = dm
						break
				var top := Ruins.local_dir(best, 0.0, float(pl.zs0))
				sites.append({"name": "crag_fortress_approach", "dir": stand, "look": best.dir, "pitch_to": top, "pitch_add_m": float(pl.top_y) * 0.6,
					"note": "a crag fortress %.0f km from the camp, %.0f m high in %d tiers, from %.0f m out on its approach" % [bd / 1000.0, float(best.rise_m), int(best.tiers), out_m]})
			"haunt":
				# SITES=haunt: the nearest haunted graveyard (design 3 Oct
				# §DI.4), from 14 m off, looking at it (at night: HOURS=22;
				# the ghost may or may not show, that is the point).
				var hb := {}
				var hd := INF
				for hc in CreatureSpawner._cells_around(camp_d, 60000.0, Ruins.CELL_M):
					var hs := Ruins.find(world.planet, hc)
					if hs.is_empty() or int(hs.kind) != Ruins.Kind.GRAVEYARD or not Haunt.haunted(hs):
						continue
					var hdm := CubeSphere.surface_distance_m(hs.dir, camp_d)
					if hdm < hd:
						hd = hdm
						hb = hs
				if hb.is_empty():
					lines.append("-- haunt: no haunted graveyard within 60 km")
					continue
				sites.append({"name": "haunted_graveyard", "dir": CreatureSpawner._offset(hb.dir, 0.3, float(hb.footprint_m) * 0.5 + 12.0), "look": hb.dir,
					"note": "a haunted graveyard %.1f km from the camp" % (hd / 1000.0)})
			"hidden":
				# SITES=hidden: the nearest hidden place of each kit (design 3
				# Oct §DJ), from 12 m in front of its door, looking at it.
				var places := HiddenPlaces.near(main.chunks.roads, camp_d, 40000.0, true)
				for kit in ["earth_homes", "oak_door", "burning_shrine"]:
					var hb := {}
					var hd := INF
					for pl in places:
						if str(pl.kit) != kit:
							continue
						var hdm := CubeSphere.surface_distance_m(pl.dir, camp_d)
						if hdm < hd:
							hd = hdm
							hb = pl
					if hb.is_empty():
						lines.append("-- hidden: no %s within 40 km" % kit)
						continue
					# The earth homes from the side of their camp, so the fire
					# doesn't stand between you and the doors.
					var back := 9.0 if kit == "earth_homes" else 12.0
					var side := 0.75 if kit == "earth_homes" else 0.0
					sites.append({"name": "hidden_" + kit, "dir": CreatureSpawner._offset(hb.dir, float(hb.facing) + side, back), "look": hb.dir,
						"note": "a hidden %s %.1f km from the camp%s" % [kit.replace("_", " "), hd / 1000.0, ", a speaker by it" if bool(hb.speaker) else ""]})
			"shrine":
				sites.append_array(_shrine_sites(camp_d))
			"wandering_fire":
				var p0 := WanderingFire.night_at(world.planet, 0)
				if p0 == Vector3.ZERO:
					lines.append("-- wandering_fire: no desert for them on this world")
					continue
				var hr := float(OS.get_environment("HOURS").split(",")[0]) if OS.get_environment("HOURS") != "" else 19.5
				# The walkabout's own clock for a site (floor(spawn) + 1 at its
				# solar hour), at the group's place.
				var at_days := Astro.days_at_solar_hour(floor(world.days) + 1.0, hr, CubeSphere.longitude(p0), CubeSphere.latitude(p0))
				var ww := WanderingFire.where(world, at_days)
				var past := WanderingFire.past_nights(world, at_days)
				if not past.is_empty():
					var rd := WanderingFire.night_at(world.planet, int(past[past.size() - 1]))
					sites.append({"name": "wandering_fire_ring", "dir": CreatureSpawner._offset(rd, 0.4, 5.0), "look": rd, "note": "their last night's cold ring, night %d" % int(past[past.size() - 1])})
				sites.append({"name": "wandering_fire", "dir": CreatureSpawner._offset(ww.dir, 0.4, 11.0), "look": ww.dir, "note": "the thirteen (%s, night %d)" % [str(ww.state), int(ww.night)]})
			"hewn_temple":
				var hts: Array = Monuments.all_sites(world.planet, "hewn_temple")
				if hts.is_empty():
					lines.append("-- hewn_temple: none on this world")
					continue
				var ht0: Dictionary = hts[0]
				sites.append({"name": "hewn_temple", "dir": Ruins.local_dir(ht0, float(ht0.pit_w) * 0.12, -float(ht0.pit_l) * 0.5 - 2.5), "look": ht0.dir, "pitch_to": ht0.dir, "pitch_add_m": float(ht0.floor_y) + 6.0,
					"note": "the hewn temple from its rim, the pit %.0f by %.0f m and %.0f m deep" % [float(ht0.pit_w), float(ht0.pit_l), float(ht0.depth_m)]})
			"northern":
				var near := {}
				var nd := {}
				var npf := Ruins.cells_per_face()
				for f in 6:
					for i in npf:
						for j in npf:
							var rs := Ruins.find(world.planet, Vector3i(f, i, j))
							if rs.is_empty() or rs.kind is String:
								continue
							var stl := str(rs.get("style", ""))
							if not (stl in ["tower_house", "broch"]):
								continue
							var dd := CubeSphere.surface_distance_m(rs.dir, camp_d)
							if dd < float(nd.get(stl, INF)):
								nd[stl] = dd
								near[stl] = rs
				for stl in ["tower_house", "broch"]:
					if not near.has(stl):
						lines.append("-- %s: none on this world" % stl)
						continue
					var ns: Dictionary = near[stl]
					if stl == "tower_house":
						sites.append({"name": "tower_house", "dir": Ruins.local_dir(ns, 6.0, -float(ns.barmkin_hs) - 26.0), "look": Ruins.local_dir(ns, 0.0, 0.0), "pitch_to": ns.dir, "pitch_add_m": float(ns.keep_h) * 0.45,
							"note": "the tower house, its keep %.1f m, %.0f km from the camp" % [float(ns.keep_h), float(nd[stl]) / 1000.0]})
					else:
						sites.append({"name": "broch", "dir": Ruins.local_dir(ns, float(ns.outer_r) + 24.0, -6.0), "look": ns.dir, "pitch_to": ns.dir, "pitch_add_m": float(ns.height_m) * 0.35,
							"note": "the broch, %.1f m on a base of %.1f m, %.0f km from the camp" % [float(ns.height_m), float(ns.base_m), float(nd[stl]) / 1000.0]})
			"stone_circle":
				var scs: Array = Monuments.all_sites(world.planet, "stone_circle")
				if scs.is_empty():
					lines.append("-- stone_circle: none on this world")
					continue
				var sc0: Dictionary = scs[0]
				sites.append({"name": "stone_circle", "dir": Ruins.local_dir(sc0, 0.0, -(float(sc0.ring_r) + 18.0)), "look": sc0.dir,
					"note": "the stone circle, %d stones" % (sc0.stones as Array).size()})
			"terraced_pueblo":
				var tps: Array = Monuments.all_sites(world.planet, "terraced_pueblo")
				if tps.is_empty():
					lines.append("-- terraced_pueblo: none on this world")
					continue
				var tp0: Dictionary = tps[0]
				var tfz := -float(tp0.rows) * 4.0 * 0.5 - 4.0
				sites.append({"name": "terraced_pueblo", "dir": Ruins.local_dir(tp0, float(tp0.cols) * 1.2, tfz - 26.0), "look": tp0.dir, "pitch_to": tp0.dir, "pitch_add_m": 6.0,
					"note": "the terraced pueblo, %d storeys" % int(tp0.storeys)})
			"stone_heads":
				var shs: Array = Monuments.all_sites(world.planet, "stone_heads")
				if shs.is_empty():
					lines.append("-- stone_heads: none on this world")
					continue
				var sh0: Dictionary = shs[0]
				sites.append({"name": "stone_heads", "dir": CreatureSpawner._offset(sh0.dir, float(sh0.inland), 30.0), "look": sh0.dir, "pitch_to": sh0.dir, "pitch_add_m": 5.0,
					"note": "the stone heads, %d on their platform" % (sh0.heads as Array).size()})
			"brick_city":
				var bcs := {}
				var bcd := INF
				for bs2 in Monuments.all_sites(world.planet, "brick_city"):
					if CubeSphere.surface_distance_m(bs2.dir, camp_d) < bcd:
						bcd = CubeSphere.surface_distance_m(bs2.dir, camp_d)
						bcs = bs2
				if bcs.is_empty():
					lines.append("-- brick_city: none on this world")
					continue
				var bcc: Vector2 = bcs.city_c
				var bgz := bcc.y - float(bcs.across_m) * 0.45 - 2.0
				sites.append({"name": "brick_city", "dir": Ruins.local_dir(bcs, bcc.x + 2.0, bgz - 58.0), "look": Ruins.local_dir(bcs, bcc.x, bgz), "pitch_to": Ruins.local_dir(bcs, bcc.x, bgz), "pitch_add_m": 6.0,
					"note": "the brick city's processional way and its gate (%.0f m across)" % float(bcs.across_m)})
			"cliff_dwelling":
				var cdw := {}
				var cdd := INF
				for cs in Monuments.all_sites(world.planet, "cliff_dwelling"):
					if CubeSphere.surface_distance_m(cs.dir, camp_d) < cdd:
						cdd = CubeSphere.surface_distance_m(cs.dir, camp_d)
						cdw = cs
				if cdw.is_empty():
					lines.append("-- cliff_dwelling: none on this world")
					continue
				sites.append({"name": "cliff_dwelling", "dir": Ruins.local_dir(cdw, float(cdw.alcove_w) * 0.35, float(cdw.alcove_d) + 26.0), "look": Ruins.local_dir(cdw, 0.0, 4.0),
					"note": "the cliff dwelling: %d rooms in its alcove" % int(cdw.room_count)})
			"carved_cliffs":
				var cb := {}
				var cbd := INF
				for cs in Monuments.all_sites(world.planet, "carved_cliffs"):
					if CubeSphere.surface_distance_m(cs.dir, camp_d) < cbd:
						cbd = CubeSphere.surface_distance_m(cs.dir, camp_d)
						cb = cs
				if cb.is_empty():
					lines.append("-- carved_cliffs: none on this world")
					continue
				# Down the canyon 24 m from the middle facade, in its bed.
				var ccy := Monuments.canyon_at(world.planet, cb.dir)
				var cstand: Vector3 = CreatureSpawner._offset(ccy.dir, float(ccy.across) + PI * 0.5, 24.0) if not ccy.is_empty() else Ruins.local_dir(cb, 0.0, -20.0)
				sites.append({"name": "carved_cliffs", "dir": cstand, "look": cb.dir, "note": "the carved cliffs, %d facades in a canyon %.0f m deep" % [(cb.facades as Array).size(), float(cb.depth_m)]})
			"long_wall":
				var lw := {}
				var lwd := INF
				for ls in Monuments.all_sites(world.planet, "long_wall"):
					if CubeSphere.surface_distance_m(ls.dir, camp_d) < lwd:
						lwd = CubeSphere.surface_distance_m(ls.dir, camp_d)
						lw = ls
				if lw.is_empty():
					lines.append("-- long_wall: none on this world")
					continue
				# The gate tower's door from 45 m out on its outer side, and a
				# stretch of the wall 600 m on, from 35 m off its side.
				sites.append({"name": "long_wall_gate", "dir": Ruins.local_dir(lw, 0.0, -45.0), "look": lw.dir, "note": "the long wall's gate tower (%.1f km of wall)" % (float(lw.len_m) / 1000.0)})
				var lm := clampf(float(lw.gate_m) + 600.0, 0.0, float(lw.len_m))
				if lm - float(lw.gate_m) < 300.0:
					lm = clampf(float(lw.gate_m) - 600.0, 0.0, float(lw.len_m))
				var lp := RoadNetwork.point_at(lw.line, lm)
				var lq := RoadNetwork.point_at(lw.line, clampf(lm + 10.0, 0.0, float(lw.len_m)))
				var lsd := (lq - lp).cross(lp).normalized()
				sites.append({"name": "long_wall_run", "dir": (lp + lsd * 35.0 / PlanetConst.RADIUS_M).normalized(), "look": RoadNetwork.point_at(lw.line, clampf(lm + 120.0, 0.0, float(lw.len_m))), "note": "a stretch of the long wall, %.0f m from the gate" % absf(lm - float(lw.gate_m))})
			"ox_rider":
				var orr := OxRider.road(world.planet, main.chunks.rivers, main.chunks.roads)
				if orr.is_empty():
					lines.append("-- ox_rider: no road over a great range on this world")
					continue
				var ohr := float(OS.get_environment("HOURS").split(",")[0]) if OS.get_environment("HOURS") != "" else 12.0
				var opd: Vector3 = orr.pass
				var o_days := Astro.days_at_solar_hour(floor(world.days) + 1.0, ohr, CubeSphere.longitude(opd), CubeSphere.latitude(opd))
				var ow := OxRider.where(world, o_days)
				# On the road 22 m ahead of him, a step to its side, looking
				# back at him coming (the walkabout's clock is the stand's own
				# solar hour: settled twice).
				var oa := OxRider.point(orr, minf(float(ow.m) + 22.0, float(orr.total)))
				for it in 2:
					ow = OxRider.where(world, Astro.days_at_solar_hour(floor(world.days) + 1.0, ohr, CubeSphere.longitude(oa), CubeSphere.latitude(oa)))
					oa = OxRider.point(orr, minf(float(ow.m) + 22.0, float(orr.total)))
				var ofw: Vector3 = (ow.ahead as Vector3) - (ow.behind as Vector3)
				var oside := ofw.cross(oa).normalized()
				sites.append({"name": "ox_rider", "dir": (oa + oside * 1.6 / PlanetConst.RADIUS_M).normalized(), "look": ow.dir, "note": "the old man on his ox (%s, %.0f m along his road of %.0f)" % [str(ow.state), float(ow.m), float(orr.total)]})
				var og := OxRider.gate_site(world.planet)
				if not og.is_empty():
					var ogd: Vector3 = (og.dir as Vector3)
					var ogf: Vector3 = og.fwd
					sites.append({"name": "ox_gate", "dir": (ogd - ogf * 26.0 / PlanetConst.RADIUS_M).normalized(), "look": ogd, "note": "the gate at his pass (%.0f m up)" % float(orr.pass_m)})
			"temple_city":
				var tb := {}
				var tbd := INF
				for ts in Monuments.all_sites(world.planet, "temple_city"):
					if CubeSphere.surface_distance_m(ts.dir, camp_d) < tbd:
						tbd = CubeSphere.surface_distance_m(ts.dir, camp_d)
						tb = ts
				if tb.is_empty():
					lines.append("-- temple_city: none on this world")
					continue
				var half := float(tb.across_m) * 0.5
				sites.append({"name": "temple_city_approach", "dir": Ruins.local_dir(tb, 0.0, -half - 4.0), "look": Ruins.local_dir(tb, 0.0, -half + 14.0),
					"note": "the temple city %.0f km from the camp, %.0f m across, %d enclosures, from its approach" % [tbd / 1000.0, float(tb.across_m), int(tb.enclosures)]})
				sites.append({"name": "temple_city_gallery", "dir": Ruins.local_dir(tb, -half * 0.35, -half * 0.42), "look": Ruins.local_dir(tb, 0.0, 0.0),
					"note": "inside: the galleries, the courtyard's tumbled blocks, the towers"})
			"ruins":
				# SITES=ruins: the wettest and the driest stone ruins of
				# this world (design 3 Oct §DI: a ruin wears its place),
				# each from its shade side (away from the sun, where the
				# moss and ferns are thickest), looking at it.
				sites.append_array(_overgrowth_sites(camp_d))
			"at":
				# SITES=at AT=lat,lon: stand there (design §DC: the wood
				# whose broken crowns shaft_check found).
				var ll := OS.get_environment("AT").split(",")
				if ll.size() == 2:
					var la := deg_to_rad(float(ll[0]))
					var lo := deg_to_rad(float(ll[1]))
					sites.append({"name": "at_%s_%s" % [ll[0], ll[1]], "dir": Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))})
			"opening_camp":
				sites.append({"name": "opening_camp", "dir": camp_d, "spawn_hour": true})
			"first_road_1km":
				var rd := _down_the_road(camp_d, 1000.0)
				sites.append({"name": "first_road_1km", "dir": rd.dir, "note": rd.note})
			"lake":
				# The nearest lake shore to the camp, looking out over the
				# water (design §DA: a lake in a breeze).
				var lk := _lake_shore(camp_d)
				if lk.is_empty():
					lines.append("-- lake: no lake on this planet; skipped")
					continue
				sites.append({"name": "lake", "dir": lk.dir, "look": lk.look, "note": "a lake %.1f km from the camp" % (CubeSphere.surface_distance_m(lk.dir, camp_d) / 1000.0)})
			"random_biome":
				var key: String = wanted[random_i % wanted.size()] if not wanted.is_empty() else ""
				random_i += 1
				var pick := _random_cell_of(key, rng)
				if pick.dir == Vector3.ZERO:
					lines.append("-- random_biome %s: no land cell of that biome on this planet; skipped" % key)
					continue
				sites.append({"name": "random_%s" % pick.key.to_lower(), "dir": pick.dir})
	# Walk them.
	# walkabout.txt grows a site at a time, so a run cut short keeps
	# what it saw.
	if OS.get_environment("RESET") == "1":
		var f0 := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR.path_join("walkabout.txt")), FileAccess.WRITE)
		f0 = null
	_flush()
	for site in sites:
		await _visit(site, hours, facings, spawn_days)
		_flush()
	lines.append("RESULT seed %d fails: %d" % [sd, fails])
	_flush()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Append the lines gathered so far to walkabout.txt and clear them.
func _flush() -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join("walkabout.txt"))
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		for l in lines:
			f.store_line(l)
	lines.clear()


## A savanna, a forest and a wetland, rotated by seed so every run has
## all three somewhere; any missing on this planet is swapped for another
## land biome present.
func _wanted_biomes() -> Array:
	var forests := ["TEMPERATE_DECIDUOUS", "TROPICAL_RAINFOREST", "TAIGA", "JUNGLE", "TEMPERATE_RAINFOREST", "CLOUD_FOREST", "TROPICAL_DRY_FOREST"]
	var wetlands := ["SWAMP", "FRESHWATER_MARSH", "BOG", "FEN", "WET_MEADOW", "FLOODPLAIN_FOREST"]
	var present := {}
	var map: PlanetData = world.planet
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.NONE:
			present[BiomeTemplates.KEYS[map.biome[c]]] = true
	var out: Array = []
	for group in [["SAVANNA", "TROPICAL_DRY_FOREST", "THORN_SCRUB"], forests, wetlands]:
		var pick := ""
		for i in group.size():
			var k: String = group[(i + sd) % group.size()]
			if present.has(k):
				pick = k
				break
		if pick == "":
			var keys := present.keys()
			pick = str(keys[sd % keys.size()])
		out.append(pick)
	return out


## The nearest lake to `d`: a land cell beside a lake cell (its direction)
## and a point out over the water to look at; {} if there is none.
func _lake_shore(d: Vector3) -> Dictionary:
	var map: PlanetData = world.planet
	var best := -1
	var best_m := INF
	for c in map.cell_count:
		if map.water[c] != PlanetData.Water.LAKE:
			continue
		var m := CubeSphere.surface_distance_m(map.dir[c], d)
		if m < best_m:
			best_m = m
			best = c
	if best < 0:
		return {}
	for k in 8:
		var nb := map.neighbors[best * 8 + k]
		if nb >= 0 and map.water[nb] == PlanetData.Water.NONE:
			var shore: Vector3 = map.dir[nb].lerp(map.dir[best], 0.35).normalized()
			return {"dir": shore, "look": map.dir[best]}
	return {"dir": map.dir[best], "look": CreatureSpawner._offset(map.dir[best], 0.0, 30.0)}


## A random land cell of biome `key` (direction), or ZERO.
func _random_cell_of(key: String, rng: RandomNumberGenerator) -> Dictionary:
	var map: PlanetData = world.planet
	var bid := BiomeTemplates.id_of_key(key)
	var cells := PackedInt32Array()
	for c in map.cell_count:
		if map.water[c] == PlanetData.Water.NONE and (bid < 0 or map.biome[c] == bid):
			cells.append(c)
	if cells.is_empty():
		return {"dir": Vector3.ZERO, "key": key}
	var c := cells[rng.randi() % cells.size()]
	return {"dir": map.dir[c], "key": BiomeTemplates.KEYS[map.biome[c]]}


## A point `m` metres down the nearest road from `d` (the first road), or
## 1 km north with a note when no road lies within 3 km.
func _down_the_road(d: Vector3, m: float) -> Dictionary:
	var roads: RoadNetwork = main.chunks.roads
	var near: Array = roads.links_near(d, 3000.0, true)
	var hit := RoadNetwork.nearest_in(near, d, 3000.0)
	if hit.is_empty():
		return {"dir": CreatureSpawner._offset(d, 0.0, m), "note": "no road within 3 km of the camp: 1 km north instead"}
	var pts: PackedVector3Array = hit.link.pts
	var at := 0.0
	for i in int(hit.seg):
		at += CubeSphere.surface_distance_m(pts[i], pts[i + 1])
	at += CubeSphere.surface_distance_m(pts[int(hit.seg)], pts[int(hit.seg) + 1]) * float(hit.t)
	var total := RoadNetwork.length_m(pts)
	var target := at + m if at + m <= total else maxf(at - m, 0.0)
	var note := "the road %.0f m from the camp, %.0f m along it" % [float(hit.dist_m), target]
	if total < m:
		note += " (a short link, %.0f m long: its end)" % total
		target = total if at < total * 0.5 else 0.0
	# A road can run to a shore or a ford: a frame under water shows no
	# plants, so step back along the road toward the camp, 50 m at a time,
	# to the first dry ground.
	var p := RoadNetwork.point_at(pts, target)
	var back := 0
	while not _dry(p) and absf(target - at) > 50.0:
		target += -50.0 if target > at else 50.0
		back += 1
		p = RoadNetwork.point_at(pts, target)
	if back > 0:
		note += " (water there: %d m back toward the camp)" % (back * 50)
	return {"dir": p, "note": note}


## The nests near the opening camp (design 1 Oct §CK): the nearest of up
## to four kinds with something to see (a cave mouth, a grotto, a cenote, an
## escarpment overhang, a waterfall, a slot canyon, a glowing bay), within
## 150 km, each seen from where you'd stand: out before a cliff's shelter
## looking in, on a cenote's rim, at a fall's pool tail, in a slot's bed
## looking along it.
func _nest_sites(camp: Vector3) -> Array:
	var out: Array = []
	for kind in ["cave_mouth", "grotto", "cenote", "escarpment", "waterfall", "slot_canyon", "bioluminescent_bay"]:
		if out.size() >= 4:
			break
		var best := {}
		var bd := INF
		for r in [40000.0, 150000.0]:
			for n in Nests.near(camp, r, [kind]):
				if kind == "cenote" and str(n.variant) != "":
					continue
				var dd := CubeSphere.surface_distance_m(n.dir, camp)
				if dd < bd:
					bd = dd
					best = n
			if not best.is_empty():
				break
		if best.is_empty():
			lines.append("-- nest %s: none within 150 km of the camp" % kind)
			continue
		var f: Vector3 = best.dir
		var stand := f
		var look := f
		match kind:
			"cave_mouth", "escarpment":
				# Out on the floor before the shelter, looking in under the roof.
				stand = CreatureSpawner._offset(f, float(best.toward) + PI, float(best.get("overhang_m", 6.0)) + 5.0)
			"grotto":
				# Just outside the mouth, inside its clearing.
				stand = CreatureSpawner._offset(f, float(best.toward) + PI, float(best.get("passage_m", 14.0)) + 3.5)
			"cenote", "waterfall", "bioluminescent_bay":
				if (best.hearth as Vector3) != Vector3.ZERO:
					stand = best.hearth
				else:
					stand = CreatureSpawner._offset(f, float(best.facing) + PI, 35.0)
			"slot_canyon":
				look = CreatureSpawner._offset(f, float(best.facing) + PI * 0.5, 30.0)
		out.append({"name": "nest_%s" % kind, "dir": stand, "look": look,
			"note": "%s %.1f km from the camp, %s%s" % [Nests.name_of(best).to_lower(), bd / 1000.0, best.state, (", " + Peoples.name_of(Peoples.get_people(str(best.people))).to_lower()) if best.has("people") else ""]})
	return out


## Dry land: a cell with no water on it and ground above the sea.
func _dry(d: Vector3) -> bool:
	var map: PlanetData = world.planet
	return map.water[map.cell_at(d)] == PlanetData.Water.NONE and world.surface_elevation(d) > PlanetConst.SEA_LEVEL_M + 0.5


func _visit(site: Dictionary, hours: Array, facings: int, spawn_days: float) -> void:
	var d: Vector3 = site.dir
	var map: PlanetData = world.planet
	var cell := map.cell_at(d)
	var biome_key: String = BiomeTemplates.KEYS[map.biome[cell]]
	var soil := PlanetData.soil_name(map.soil_at(d)).replace("_", "/")
	# Stand there (as dev_view's AT= does): rebase, load, spawn.
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(d)
	player.spawn_at(d, site.get("look", CreatureSpawner._offset(d, 0.0, 30.0)))
	# The long walls' stretches in sight (§DS.1: streamed, LongWalls).
	if main.get("long_walls") != null:
		main.long_walls.build_now(d, LongWalls.BUILD_M)
	await _frames(20)
	if site.has("delve_stand"):
		await _into_delve(site)
	if site.has("shrine_stand"):
		await _into_shrine(site)
	elif site.has("shrine_pitch"):
		main.hidden_places.refresh(true)
		await _frames(5)
		player.set_view(float(site.shrine_pitch), 0.0)
	# Wait for the chunk's near plants (the leaf cards, not the far
	# pictures), as play has them within seconds on a GPU.
	# Bounded by the clock, not frames: the software renderer draws about
	# a frame a second, so a frame count would wait an hour.
	var ck: Vector3i = TerrainChunk.key_at(d)
	var t0 := Time.get_ticks_msec()
	var detail := false
	while Time.get_ticks_msec() - t0 < int(W.get("detail_wait_s", 240.0) * 1000.0):
		var c: TerrainChunk = main.chunks.chunks.get(ck, null)
		if c != null and c.plant_lod(c) != PlantMeshes.LOD_FAR and c.detail_node != null:
			detail = true
			break
		await process_frame
	if not detail:
		site["note"] = (str(site.note) + " · " if site.has("note") else "") + "near plants not in after %d s" % ((Time.get_ticks_msec() - t0) / 1000)
	await _frames(10)
	lines.append("-- %s: %s · %s soil · %.2f°%s %.2f°%s%s" % [site.name, biome_key, soil, absf(rad_to_deg(map.lat[cell])), "N" if map.lat[cell] >= 0.0 else "S", absf(rad_to_deg(CubeSphere.longitude(d))), "E" if CubeSphere.longitude(d) >= 0.0 else "W", (" · " + str(site.note)) if site.has("note") else ""])
	# The species within reach, and the gate's verdict on each.
	var within := float(W.get("list_within_m", 30.0))
	var found := _species_within(player.global_position, within)
	var unlisted := 0
	var names: Array = found.keys()
	names.sort()
	var other := {}
	for n in names:
		var sp: PlantSpecies = found[n][0]
		var count: int = found[n][1]
		var stray: int = found[n][2]
		# Unlisted: standing in a cell whose biome does not list it. Listed
		# where it stands but not in your own cell's biome: the next
		# biome over, within reach across the boundary.
		var listed := stray == 0
		if not listed:
			unlisted += 1
		var nest_own: int = found[n][3] if (found[n] as Array).size() > 3 else 0
		var across := listed and nest_own < count and not sp.biomes.has(map.biome[cell])
		if across:
			other[n] = true
		var at_nest: int = found[n][3] if (found[n] as Array).size() > 3 else 0
		lines.append("   %s%s x%d [%s, %s]%s%s" % ["" if listed else "UNLISTED HERE: ", n, count, PlantSpecies.Tier.keys()[sp.tier].to_lower(), ", ".join(sp.files), (" (%d of them outside its biomes)" % stray) if stray > 0 else (" (across the boundary, in its own biome)" if across else ""), (" (%d a nest's own, §CM)" % at_nest) if at_nest > 0 else ""])
	ok(unlisted <= int(W.get("unlisted_species_allowed", 0)), "%s (%s): %d species within %.0f m, %d in a biome that does not list them%s" % [site.name, biome_key, names.size(), within, unlisted, (" (%d across a boundary, in their own biome)" % other.size()) if not other.is_empty() else ""])
	# The hours and facings.
	var lon := CubeSphere.longitude(d)
	var lat := CubeSphere.latitude(d)
	var base: float = floor(spawn_days) + 1.0
	# MOON=full, new or first_quarter: the night nearest after the spawn with
	# that moon (design §DD's measured nights).
	if OS.get_environment("MOON") != "":
		var want_m := OS.get_environment("MOON")
		var best_k := 0
		var best_s := INF
		for k in 31:
			var il := Astro.moon_illumination(base + k)
			var waxing := Astro.moon_illumination(base + k + 0.5) > il
			var score: float = {"full": 1.0 - il, "new": il}.get(want_m, absf(il - 0.5) + (0.0 if waxing else 1.0))
			if score < best_s:
				best_s = score
				best_k = k
		base += best_k
	# SEASON=autumn (or spring, summer, winter): the first day after the
	# spawn that sits in the middle of that season here (design §DA's
	# autumn road).
	if OS.get_environment("SEASON") != "":
		var want := OS.get_environment("SEASON")
		for k in int(DayCycle.year_days()) + 1:
			var at := Seasons.at(base + k, lat)
			if str(at.get("name", "")) == want and float(at.get("t", 0.0)) == 0.0:
				base += k + 10.0
				break
	var first := true
	if site.has("delve_stand") or site.has("delve_hours"):
		# Down there it is dark at noon but for the torch (§CJ).
		hours = [{"solar_h": 13.0, "weather": "clear"}]
		facings = 1
	for h in hours:
		var hour := float(h.get("solar_h", 14.0))
		var overcast := str(h.get("weather", "clear")) == "overcast"
		# WIND=<m/s> blows that hard (design §DA: a meadow in a breeze);
		# else the gentle 1.1 m/s of every walkabout before it.
		var wind_v := Vector3(1, 0, 0.5)
		if OS.get_environment("WIND") != "":
			wind_v = wind_v.normalized() * float(OS.get_environment("WIND"))
		var wx := {"wind": wind_v, "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 0.0 if overcast else 1.0, "cloud": 0.95 if overcast else 0.12}
		# CLOUD=0.5: §CX's cover that much (a part-cloudy day: the cloud
		# shadows, design §DA).
		if OS.get_environment("CLOUD") != "" and not overcast:
			wx["cloud"] = float(OS.get_environment("CLOUD"))
		# RH=0.95: the air's damp (design §DC: a misty dawn's shafts).
		if OS.get_environment("RH") != "":
			wx["rh"] = float(OS.get_environment("RH"))
		main._weather_timer = 1e9
		main._local_weather = wx
		main._weather_eased = wx.duplicate()
		if site.get("spawn_hour", false) and first:
			# The spawn hour itself: the clock as the world opened.
			world.days = spawn_days
		else:
			world.days = Astro.days_at_solar_hour(base, hour, lon, lat)
		# A site that looks up at something (a great range's summit) tips
		# the first facing up to it.
		var pitch0 := 0.0
		if site.has("pitch_to"):
			var tp: Vector3 = site.pitch_to
			var to: Vector3 = world.to_scene(tp, PlanetConst.RADIUS_M + world.planet.terrain.elevation(tp, true) + float(site.get("pitch_add_m", 0.0))) - player.global_position
			pitch0 = clampf(asin(clampf(to.normalized().dot(player.up), -1.0, 1.0)) * 0.7, -0.8, 0.8)
		# FACE_SUN=1: the first facing looks at the sun (design §DB).
		var yaw0 := 0.0
		if OS.get_environment("FACE_SUN") == "1":
			for i in 6:
				await process_frame
			var sd: Vector3 = main.sky.sun_dir
			var best := -2.0
			for j in 36:
				var yw := TAU * j / 36.0
				player.set_view(0.0, yw)
				# (set_view takes on the next frame.)
				await process_frame
				var fwd := -player.camera().global_basis.z
				var flat := (fwd - player.up * fwd.dot(player.up)).normalized()
				var sflat := (sd - player.up * sd.dot(player.up)).normalized()
				if flat.dot(sflat) > best:
					best = flat.dot(sflat)
					yaw0 = yw
			pitch0 = clampf(asin(clampf(sd.dot(player.up), -1.0, 1.0)) * 0.85, -0.2, 1.2)
		for k in facings:
			var yaw := TAU * k / facings + yaw0
			for i in (12 if k == 0 else 6):
				player.set_view(pitch0 if k == 0 else 0.0, yaw)
				main.hud._readout_timer = 0.0
				await process_frame
			var img := get_root().get_texture().get_image()
			if k == 0 and main.get("day_accents") != null:
				var dac: DayAccents = main.day_accents
				print("[butterflies] %s %02dh: %d (%s)" % [site.name, int(hour), dac.flies.size(), "on" if bool(dac.gate_state.get("ok", false)) else str(dac.gate_state.get("why", ""))])
			if k == 0 and main.get("ruin_sounds") != null:
				# What a ruin round you sounds like (design 3 Oct §DI.3).
				var rsn: RuinSounds = main.ruin_sounds
				rsn.refresh()
				var heard: Array = []
				for rn in rsn.state.get("ruins", {}):
					var rst: Dictionary = rsn.state.ruins[rn]
					heard.append("%s %.0f m: %s%s" % [rn, float(rst.get("dist", 0.0)), ", ".join(rst.get("who", [])) if not (rst.get("who", []) as Array).is_empty() else "none", " (overrun, silent)" if bool(rst.get("silent", false)) else ""])
				print("[ruin sounds] %s %02dh (%s): %s; bed: stone wind %.2f (wind at the opening %.1f m/s), drips %.2f, hush %.2f" % [site.name, int(hour), str(rsn.state.get("hour", "")), "; ".join(heard) if not heard.is_empty() else "no ruin near", RuinSounds.stone_wind, float(rsn.state.get("wind_mps", 0.0)), RuinSounds.drips, RuinSounds.hush])
			if k == 0 and main.get("haunt") != null:
				var hn: Haunt = main.haunt
				var hp := hn.place_now()
				if hp != null:
					print("[haunt] %s %02dh: in a haunted place (%s), light %s, ghost %s, %d seen so far" % [site.name, int(hour), hp.name, "low" if hn.low_light() else "too bright", "standing in view" if not hn.ghost.is_empty() else "none now", hn.seen_log.size()])
			if k == 0 and main.get("shafts") != null:
				var sf: ShaftField = main.shafts
				print("[shafts] %s %02dh: %d (%s, air %.2f)" % [site.name, int(hour), sf.shafts.size(), "on" if bool(sf.gate_state.get("ok", false)) else str(sf.gate_state.get("why", "")), float(sf.gate_state.get("air", 0.0))])
			if OS.get_environment("FACE_SUN") == "1" and k == 0 and main.get("flare") != null:
				var fl := "%s %02dh: the flare at %.2f%s" % [site.name, int(hour), float(main.flare.alpha), (" (" + str(main.flare.why) + ")") if str(main.flare.why) != "" else ""]
				print("[flare] " + fl)
				lines.append("   " + fl)
			var solar := fposmod(Astro.time_of_day(world.days) + lon / TAU, 1.0) * 24.0
			var fname := "%s_%02dh_f%d.png" % [site.name, int(round(solar)), k]
			img.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(str(sd)).path_join(fname)))
			if site.get("spawn_hour", false) and first and k == 0:
				# On the game's own clock (World.local_clock, what the HUD and
				# DayCycle read), not the frame name's mean solar hour.
				var dawn := DayCycle.phase_start_hour("dawn", lat, Astro.declination(world.days))
				var local_h: float = world.local_clock(d).y
				var into: float = fposmod(local_h - dawn, 24.0) / 24.0 * (world.day_length_s / 60.0)
				ok(into < 4.0, "the opening camp's first frame is dawn (%.2f h on the clock, dawn begins %.2f h, %.1f real min in, sun %.1f°)" % [local_h, dawn, into, main.sky.sun_elevation_deg])
		first = false


## Every species within `r` m of `center` (scene): the trees of the loaded
## chunks and their understory MultiMeshes (meta "species"), name ->
## [species, count].
func _species_within(center: Vector3, r: float) -> Dictionary:
	var out := {}
	var all := SpeciesDB.all()
	for key in main.chunks.chunks:
		var chunk: TerrainChunk = main.chunks.chunks[key]
		if chunk.global_position.distance_to(center) > r + 400.0:
			continue
		for i in chunk.trees.size():
			var tb := chunk.tree_base(i)
			if tb.distance_to(center) <= r:
				_count(out, all[int(chunk.trees[i][2])], tb)
		if chunk.detail_node == null:
			continue
		for n in chunk.detail_node.get_children():
			var mmi := n as MultiMeshInstance3D
			if mmi == null or not mmi.has_meta("species") or mmi.multimesh == null:
				continue
			var sp: PlantSpecies = all[int(mmi.get_meta("species"))]
			var buf := mmi.multimesh.buffer
			var count := mmi.multimesh.instance_count if mmi.multimesh.visible_instance_count < 0 else mmi.multimesh.visible_instance_count
			for k in count:
				var j := k * 20
				if j + 11 >= buf.size():
					break
				var base := mmi.global_transform * Vector3(buf[j + 3], buf[j + 7], buf[j + 11])
				if base.distance_to(center) <= r:
					_count(out, sp, base)


	return out


## Counts a plant, and whether it stands where its biome is: the gate
## judges each plant by its own cell (VegetationPlacer: a site's biome is
## its cell's), so near a boundary the 30 m round you holds both biomes'
## plants. [species, count, count outside a biome that lists it].
func _count(out: Dictionary, sp: PlantSpecies, at: Vector3) -> void:
	if not out.has(sp.name):
		out[sp.name] = [sp, 0, 0]
	out[sp.name][1] += 1
	var map: PlanetData = world.planet
	var d: Vector3 = world.dir_of(at)
	if not sp.biomes.has(map.biome[map.cell_at(d)]):
		# A nest's own plant at its spot (design 1 Oct §CM: it grows there
		# even where the biome's list lacks it) is where it belongs.
		if _nest_plant(sp, d):
			if out[sp.name].size() < 4:
				out[sp.name].append(0)
			out[sp.name][3] += 1
		else:
			out[sp.name][2] += 1


## Is `sp` one of a nest's own plants (landforms.json plants.add) at one of
## its spots, within reach of `d`?
func _nest_plant(sp: PlantSpecies, d: Vector3) -> bool:
	for n in Nests.near(d, 40.0):
		if not (Nests.entry(str(n.kind)).get("plants", {}) as Dictionary).get("add", []).has(sp.binomial()):
			continue
		for spot in Nests.plant_spots(n):
			if CubeSphere.surface_distance_m(spot[0], d) <= float(spot[1]) + 1.5:
				return true
	return false


## The nearest great range (design 3 Oct §CR, TerrainField.great_ranges):
## from its foot (out across the flank from the summit, past where the
## range rises) looking up at the summit, and from the summit looking
## along the crest.
func _range_sites(camp: Vector3) -> Array:
	var t: TerrainField = world.planet.terrain
	var best := {}
	var bd := INF
	for g in t.great_ranges:
		var dd := CubeSphere.surface_distance_m(g.summit, camp)
		if dd < bd:
			bd = dd
			best = g
	if best.is_empty():
		lines.append("-- range: no great range on this planet")
		return []
	var top: Vector3 = best.summit
	var hw := float(best.summit_m) / tan(deg_to_rad(TerrainField.FLANK_DEG))
	var side: Vector3 = best.side
	var foot := (top + side * (hw * 1.15) / PlanetConst.GEO_RADIUS_M).normalized()
	var along: Vector3 = best.axis
	var note := "the great range %.0f km from the camp, summit %.0f m" % [bd / 1000.0, t.elevation(top, true)]
	return [
		{"name": "range_foot", "dir": foot, "look": top, "note": note + ", from its foot", "pitch_to": top},
		{"name": "range_summit", "dir": CreatureSpawner._offset(top, 0.0, 6.0), "look": (top + along * 3000.0 / PlanetConst.GEO_RADIUS_M).normalized(), "note": note + ", from the top along the crest"},
	]


## The nearest overrun barrow (design 2 Oct §CN; else the nearest barrow
## with a delve, §CJ) within 150 km: from outside (the bones at its door),
## at the stairhead, in the first room and in the heart by torchlight,
## where its fire-holder is laid and lit and the ruin cleared, and at the
## cairn's door.
func _delve_sites(camp: Vector3) -> Array:
	var map: PlanetData = world.planet
	var site := {}
	var bd := INF
	for want_over in [true, false]:
		for r in [40000.0, 150000.0]:
			for s in Ruins.near(map, camp, r):
				if Delves.has_delve(s) and (not want_over or Overrun.is_overrun(s)) and CubeSphere.surface_distance_m(s.dir, camp) < bd:
					bd = CubeSphere.surface_distance_m(s.dir, camp)
					site = s
			if not site.is_empty():
				break
		if not site.is_empty():
			break
	if site.is_empty():
		lines.append("-- delve: no barrow with a delve within 150 km")
		return []
	var lay := Delves.layout(map, site)
	var fr := Delves.frame(map, site)
	var l: float = site.half_l
	var note := "the %sbarrow %.1f km from the camp" % ["overrun " if Overrun.is_overrun(site) else "", bd / 1000.0]
	var out: Array = []
	out.append({"name": "delve_barrow", "dir": Delves.to_dir(fr, 0.0, -l - 14.0), "look": site.dir, "note": note + ", its facade", "delve_hours": true})
	var zc: float = lay.zc
	out.append({"name": "delve_stairhead", "dir": Delves.to_dir(fr, 0.0, zc - 1.6), "look": Delves.to_dir(fr, 0.0, zc + 20.0), "note": note + ", the chamber and the stair down",
		"delve_seed": int(site.seed), "delve_stand": Vector3(0.0, NAN, zc - 1.6), "delve_look": Vector3(0.0, -1.5, zc + 3.0)})
	var room: Dictionary = lay.pieces[1]
	var rc: Vector2 = room.c
	out.append({"name": "delve_room", "dir": Delves.to_dir(fr, rc.x, rc.y + 0.6), "look": Delves.to_dir(fr, rc.x, rc.y + 20.0), "note": "the first room (%s), its old hearth cold" % lay.feature,
		"delve_seed": int(site.seed), "delve_stand": Vector3(rc.x, float(room.y0), rc.y + 0.6), "delve_look": Vector3(rc.x, float(room.y0), rc.y + 4.0), "torch": true})
	var heart: Dictionary = lay.pieces[3]
	var hc: Vector2 = heart.c
	var s2 := float(lay.get("s2", 1.0))
	var lh := float(heart.len)
	out.append({"name": "delve_heart", "dir": Delves.to_dir(fr, s2 * 1.7, hc.y + lh * 0.85), "look": Delves.to_dir(fr, -s2 * 1.8, hc.y - 6.0), "note": "the heart: the dead and the %s, looking back at its fire-holder" % lay.find_kind,
		"delve_seed": int(site.seed), "delve_stand": Vector3(s2 * 1.7, float(heart.y0), hc.y + lh * 0.85), "delve_look": Vector3(-s2 * 1.8, float(heart.y0) + 0.2, hc.y + 1.0), "torch": true, "light_heart": true})
	var cairn: Dictionary = lay.cairn
	if not cairn.is_empty():
		var o: Vector2 = cairn.o
		var dv: Vector2 = cairn.dir
		var at: Vector2 = o + dv * 9.0
		out.append({"name": "delve_cairn", "dir": Delves.to_dir(fr, at.x, at.y), "look": Delves.to_dir(fr, o.x, o.y), "note": "the cairn the way out comes up in, its slab shut", "delve_hours": true})
	return out


## The nearest shrine (design 3 Oct §DK): its court, the hall, the altar.
func _shrine_sites(camp: Vector3) -> Array:
	var map: PlanetData = world.planet
	var pl := {}
	var bd := INF
	for p in HiddenPlaces.near(main.chunks.roads, camp, 40000.0, true):
		if str(p.kit) in Shrines.KITS and CubeSphere.surface_distance_m(p.dir, camp) < bd:
			bd = CubeSphere.surface_distance_m(p.dir, camp)
			pl = p
	if pl.is_empty():
		lines.append("-- shrine: none within 40 km")
		return []
	var lay := Shrines.layout(map, pl)
	var fr: Dictionary = lay.fr
	var hall: Dictionary = lay.pieces[0]
	var room: Dictionary = lay.pieces[1]
	var hl := float(hall.len)
	var zr := float((room.c as Vector2).y)
	var note := "the shrine behind a %s %.1f km from the camp, %d sconces" % [str(pl.kit).replace("_", " "), bd / 1000.0, (lay.sconces as Array).size()]
	var out: Array = []
	out.append({"name": "shrine_court", "dir": Delves.to_dir(fr, 0.0, -5.0), "look": Delves.to_dir(fr, 0.0, 12.0), "note": note + ", the court and the way down", "shrine_key": str(pl.key), "shrine_pitch": -0.35})
	out.append({"name": "shrine_hall", "dir": Delves.to_dir(fr, 0.0, 0.5 + float(lay.open_to) + 1.0), "look": Delves.to_dir(fr, 0.0, zr + 4.0), "note": "the hall going down, its sconces",
		"shrine_key": str(pl.key), "shrine_stand": Vector3(0.0, Delves.floor_of(hall, float(lay.open_to) + 1.0), 0.5 + float(lay.open_to) + 1.0), "shrine_look": Vector3(0.0, Delves.floor_of(hall, hl) + 1.0, zr + 2.0)})
	out.append({"name": "shrine_altar", "dir": Delves.to_dir(fr, 0.9, zr + 0.8), "look": Delves.to_dir(fr, 0.0, zr + 6.0), "note": "the altar room: the scroll on the altar, the wall behind it",
		"shrine_key": str(pl.key), "shrine_stand": Vector3(0.9, float(room.y0), zr + 0.8), "shrine_look": Vector3(0.0, float(room.y0) + 1.0, zr + Shrines.ROOM_L - 1.5), "torch": true})
	return out


## Stand at a shrine: built, the player on its floor (layout coordinates),
## looking along it; a lit torch in hand if the site asks.
func _into_shrine(site: Dictionary) -> void:
	main.hidden_places.refresh(true)
	await _frames(5)
	var e: Dictionary = Shrines.instance.built.get(str(site.shrine_key), {}) if Shrines.instance != null else {}
	if e.is_empty():
		site["note"] = str(site.get("note", "")) + " · the shrine did not build"
		return
	var node: Node3D = e.node
	var off := float(e.off)
	var st: Vector3 = site.shrine_stand
	var lk: Vector3 = site.shrine_look
	player.global_position = node.global_transform * Vector3(st.x, st.y - off + 0.02, st.z)
	player.velocity = Vector3.ZERO
	await _frames(5)
	if bool(site.get("torch", false)):
		player.inventory.add(Inventory.make("torch"))
		player.weapon = "torch"
		player.torch.light()
	for i in 30:
		player.torch.update_torch(1.0 / 60.0)
		await process_frame
	var to: Vector3 = node.global_transform * Vector3(lk.x, lk.y - off, lk.z) - player.eye_position()
	player.set_view(clampf(asin(clampf(to.normalized().dot(player.up), -1.0, 1.0)), -0.8, 0.8), 0.0)
	site["note"] = str(site.get("note", "")) + " · inside (%s)" % ("underground" if Delves.underground > 0.5 else "at ground level")


## Stand inside a delve: the barrow built and solid, the player on the
## piece's floor (layout coordinates, NAN y: the ground), a lit torch in
## hand if the site asks for one.
func _into_delve(site: Dictionary) -> void:
	var node: Node3D = null
	var t0 := Time.get_ticks_msec()
	while node == null and Time.get_ticks_msec() - t0 < 60000:
		main.landmarks.build_ruin_at(site.dir)
		var ruins: Dictionary = main.landmarks.built_ruins()
		for c in ruins:
			var n: Node3D = ruins[c]
			if is_instance_valid(n) and int((n.get_meta("site", {}) as Dictionary).get("seed", 0)) == int(site.delve_seed):
				node = n
		await process_frame
	if node == null:
		site["note"] = str(site.get("note", "")) + " · the barrow did not build"
		return
	for i in 400:
		if not RuinBuilder.wants_collision(node):
			break
		RuinBuilder.build_collision_part(node)
	var off := float(node.get_meta("delve_off", 0.0))
	var st: Vector3 = site.delve_stand
	var lk: Vector3 = site.delve_look
	# The floor (layout y; NAN: the paving on the ground), the player's
	# feet on it (physics is off in the walkabout: no settling).
	var y: float = st.y - off
	if is_nan(st.y):
		y = main.chunks.ground_height(world.dir_of(node.global_transform * Vector3(st.x, 0.0, st.z))) - (world.radius_of(node.global_position) - PlanetConst.RADIUS_M) + 0.03
	player.global_position = node.global_transform * Vector3(st.x, y + 0.02, st.z)
	player.velocity = Vector3.ZERO
	# (A few frames first, so Delves knows you are inside before the torch
	# is lit: in play you walk down and it always does.)
	await _frames(5)
	if bool(site.get("torch", false)):
		player.inventory.add(Inventory.make("torch"))
		player.weapon = "torch"
		player.torch.light()
	# (Physics is off here, and the torch's light is set from it.)
	for i in 30:
		player.torch.update_torch(1.0 / 60.0)
		await process_frame
	if bool(site.get("light_heart", false)):
		# The heart's fire-holder (§CN): laid with kindling and fuel, lit by
		# the swing's rule; an overrun ruin is cleared by it.
		main.old_hearths.refresh_now()
		var holder: Node3D = null
		for f in get_nodes_in_group(Campfire.GROUP):
			if (f as Node3D).has_meta("heart_of") and int((f as Node3D).get_meta("heart_of")) == int(site.delve_seed):
				holder = f
		if holder == null:
			site["note"] = str(site.get("note", "")) + " · no fire-holder"
		else:
			var was := Overrun.is_overrun(node.get_meta("site"))
			FireStore.lay_kindling(holder, Kindling.make("dry_twigs"), world.days)
			for k in 3:
				FireStore.add_fuel(holder, Inventory.make("fuel", {"fuel": "branch"}), world.days)
			FireStore.swing_light(holder, world.days)
			for i in 120:
				player.torch.update_torch(1.0 / 60.0)
				await process_frame
				if FireStore.is_lit(holder):
					break
			for i in 40:
				player.torch.update_torch(1.0 / 60.0)
				await process_frame
			site["note"] = str(site.get("note", "")) + " · its fire-holder %s%s" % ["lit" if FireStore.is_lit(holder) else "NOT lit", (", the ruin %s" % Overrun.state_of(node.get_meta("site"))) if was else ""]
	var lp := node.global_transform * Vector3(lk.x, (lk.y - off) if not is_nan(lk.y) else y, lk.z)
	var to := lp - player.global_position
	site["note"] = str(site.get("note", "")) + (" · inside (%s)" % ("underground" if Delves.underground > 0.5 else "at ground level"))
	if to.length() > 0.1:
		player.set_view(clampf(asin(clampf(to.normalized().dot(player.up), -1.0, 1.0)), -0.8, 0.8), 0.0)


## The wettest and the driest stone ruins (castle, tower, aqueduct) of
## this world from a sample of ruin cells (design 3 Oct §DI), each seen
## from its shade side.
func _overgrowth_sites(camp_d: Vector3) -> Array:
	var map: PlanetData = world.planet
	var n := Ruins.cells_per_face()
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var wet := {}
	var dry := {}
	for i in 6000:
		var c := Vector3i(r.randi() % 6, r.randi() % n, r.randi() % n)
		var f := Ruins.find(map, c)
		if f.is_empty() or not int(f.kind) in [Ruins.Kind.CASTLE, Ruins.Kind.TOWER, Ruins.Kind.AQUEDUCT]:
			continue
		var m := map.sample(map.moisture, f.dir)
		if map.sample(map.temp_c, f.dir) < 5.0:
			continue
		if wet.is_empty() or m > float(wet.m):
			wet = {"f": f, "m": m}
		if dry.is_empty() or m < float(dry.m):
			dry = {"f": f, "m": m}
	var out: Array = []
	for pick in [wet, dry]:
		if pick.is_empty():
			continue
		var f: Dictionary = pick.f
		var og := Overgrowth.for_site(map, f)
		var bearing := 0.0 if CubeSphere.latitude(f.dir) >= 0.0 else PI
		# (An aqueduct's footprint is half its length: stand by its piers.)
		var stand := CreatureSpawner._offset(f.dir, bearing, 16.0 if int(f.kind) == Ruins.Kind.AQUEDUCT else float(f.footprint_m) + 12.0)
		out.append({"name": "ruin_%s" % ("wet" if pick == wet else "dry"), "dir": stand, "look": f.dir,
			"note": "%s in %s, moisture %.2f (moss %.2f fern %.2f vine %.2f wall-top %.2f lichen %.2f), %.0f km from the camp, from its shade side" % [Ruins.site_name(f), BiomeTemplates.KEYS[map.biome[map.cell_at(f.dir)]].to_lower(), float(pick.m), float(og.moss), float(og.fern), float(og.vine), float(og.wall_top), float(og.lichen), CubeSphere.surface_distance_m(f.dir, camp_d) / 1000.0]})
	return out
