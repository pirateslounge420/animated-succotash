extends SceneTree
## Torchfire 1's first slice (design 6 Oct §ET.11), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/crawler_check.gd
## Asserts:
##  1. the switch (§ET.2): data/game.json boots the crawler (the project's
##     main scene is the boot scene, which opens GameMode.scene()), GAME
##     overrides it, the open world's scene is still there;
##  2. the tomb kit (§ET.3, §CJ.8) and its plan (§EX.2, §EX.5), over seeds
##     1, 7, 42 and WALK_SEEDS more (env WALK_SEEDS; default 200, drawn
##     from a fixed seed so a failure can be run again): three or four ways
##     out of the hearth room, every piece reachable from it through doors,
##     no two pieces overlapping unless a door joins them, every room past
##     the hearth room with its wall sconces (§EX.4) and no hearth but the
##     hearth room's, the airways placed, the mat, the bundle and the
##     rescuer in the hearth room clear of the hearth; at
##     least one way out (exit.min), at the end of the spine past the
##     heart; the spine through the heart, its last room, and the longest
##     way; the side ways at most side_share of its rooms, each ending in
##     a room; every room's sides, every corridor and flight a whole number
##     of the style's modules, the ceilings the style's heights; every door
##     centred on its wall, the spine's rooms' doors facing; then the walk
##     (exit.check): the player's own body (its capsule, floor rules and
##     step, CrawlerPlayer) walks from the wake spot to the way out in each
##     tomb's real collision with every holder cold, or the seed fails with
##     what stopped it; the median walk reported; in the scene: a floor
##     under every piece and a ceiling over it, and you standing on the
##     floor;
##  2b. one hearth, wall torches in the other rooms (design §EX.4;
##     crawler.json room_torches), on seeds 1, 7 and 42: one hearth, in the
##     hearth room; two or four sconces in every other room by the rule
##     (the heart four, two each side flanking the dead), on the long
##     walls, whole modules apart, in facing pairs where the doors allow;
##     none within clear_m of a door's edge; one shaft (the hearth's), one
##     flue per sconce; the airways clear of the sconces; and each room,
##     with its sconces relit, at least as lit as with its old hearth ring
##     (both reported). In the scene: one hearth among the fires, every
##     room sconce in your reach from somewhere your body fits, and the
##     sconces' lights as the measure assumes;
##  3. relighting (§ET.4): you wake with nothing in hand, the hearth lit,
##     every holder dark (full dark: no light but the hearth's); a torch
##     from the bundle, lit at the hearth by the swing; every holder lit by
##     the swing, staying lit an hour on; a dead torch relit at a holder;
##  4. the snuff rules (§ET.7 as amended by §EZ.1 and §EZ.5, torch.json
##     snuff): walking and looking about a minute never gutter it; it
##     glows brighter at a run; a minute of swinging it, and 120 s flat
##     out round the tomb whipping round every 4 s, leave it lit with no
##     gutter; an ordinary airway leans it and flickers it, never a
##     gutter; standing in a strong mouth's line through three gusts it
##     holds, unguttered and whipped hard (not out of the line or behind
##     cover), the moan and the dust as built; wading toward
##     douse_depth_m gutters it (redder, never bluer), past it douses it;
##  5. the one who found you (§FH): the live shared rig, not a sprite: a
##     HearthFolk holding a seated PlayerBody with its beast head, real
##     geometry (its triangles) and no FigureSprite in the tomb but the
##     boss's body (§EY.5) and the skeletons' (ResidentSprite, §ET.8);
##     facing the hearth on its stone (the stone in the tomb's collision,
##     right under its hips); painted per §ES (no material on it with
##     specular above 0, roughness under 1 or a normal map; its painted
##     detail in big texels, folk_3d.texels_per_m); casting the fire's
##     shadow; breathing (its neck rises and falls); turning its hood to
##     you in front of it; something to bump into. And FigureSprite, kept
##     for creatures and bosses (§ET.8): a sheet's frame picked by where
##     the camera stands (front, side, behind, above, below), its idle
##     stepping;
##  6. the crosshair (§EX.7, Reticle): the one thing in the crawler's HUD
##     (no words, nothing else of the open world's), round the frame's
##     middle pixel and sized per hud.json reticle at the 480 and 270
##     presets, its dark edge one pixel round it, drawn over the grade
##     (no bloom); off with the Settings switch hud.reticle and under an
##     open panel (crawler_frames.gd checks its pixels on screen); a hit
##     (Mike, 7 Oct; hud.json reticle.hit_marker) shows its X for show_s,
##     four diagonals in the corners between the arms at 480 and 270
##     lines, clear of the arms, its dark edge never drawn twice;
##  7. dousing your own torch (§FC.3, Torch.douse): F is the douse key;
##     pressed with a lit torch in hand it goes out and stays in your hand
##     (the same torch, a spare in the pack ahead of it), its burn
##     unchanged, one log line (stealth.json douse.log_line), not water;
##     nothing that watches for a carried flame sees it (Senses), and a
##     hunter's chase gives you up (Pursuit, torch_doused); F with
##     no flame does nothing; the cold torch relights at the hearth, a
##     relit sconce and a planted torch, as built;
##  8. the half-dark (§FC.4, HalfDark): its light navy, never warm, no
##     shadow, no shine, reaching black_m; off with the torch lit and
##     beside a lit fire in sight; on, eased in, with no flame near; a lit
##     torch behind a wall doesn't count, the same torch in sight does, and
##     so does a fire pot's tar burning on the floor;
##  9. sneaking (§FC.1, stealth.json sneak): the eye eases down and back up
##     over camera_ease_s, never a snap, and stays down under a low
##     ceiling; the crosshair takes its dim sneak look and back: its two
##     level dashes alone (shape dashes, Mike 7 Oct), the crosshair's own
##     left and right arms on their dark edge, at 480 and 270 lines (and
##     the first look, the ring, still one clean pixel line round the
##     frame's middle);
##     a crouched step at footstep_volume of a walking one's; the ledge
##     guard: a crouched walk at a 2 m drop stops at the lip, a diagonal
##     one slides along it, neither falls, a standing one falls, and
##     letting go of Shift steps off; and crouched through every door and
##     down every flight of the tomb, the guard never holds you;
## 10. atmosphere, never a puzzle (§FG): glow-moss only on damp stone
##     (none in a dry tomb), no light node, nothing the rules read seeing
##     it; at a torch in hand it falls to dim_to of its rest and creeps back
##     to rest returns_s after the torch has gone; a beetle stays out in the
##     dark but in torchlight is gone into a real joint within a second and
##     comes out again later in the dark; the bugs favour damp, dark walls,
##     none in the hearth room or on the stairs; the crawler runs the
##     world's clock (the 144-minute day) and the shafts' daylight climbs and
##     sinks with the sun, moonlit blue at night;
## 11. the pitch torch (§EZ.2, PitchTorch): every lit torch in the built
##     tomb (in hand, planted) has one flame card and one coal on its
##     pitch head, every unlit one (the bundle's, one put out with burn
##     left) none, a burnt-out one is a bare stick; the wrap six-sided,
##     flat-topped, its bands steps (a vertex test), the coal six-sided;
##     no shine on the head or the stick (no specular, roughness 1, no
##     normal map); the flame's lean 0 standing still and within max_deg
##     at a sprint, leaning back and stretched, settling when you stop,
##     toward an ordinary airway's draft, flat out at max_deg in a strong
##     mouth's gust, never putting it out; the light flickering with the
##     flame on top of the coal's breath, held_scale kept; the smoke
##     darker toward soot and never grey;
## 12. the way out (§EX.5, WayOut): faint daylight in the opening, cool
##     blue by day and fainter at night, seen from the bottom of the
##     flight (nothing between), fainter from far off (exit.glow far_fade:
##     all of it on the landing, less from the wake spot, Mike 7 Oct); stepping into it fades to the next tomb
##     (exit.stand_in): a new seed, you on the mat by its lit hearth, the
##     torch you carried lit or not as it was, the log's line;
## 13. one ruin, one stone (§EX.1, §EX.3; _style_kit, _style_scene, _room_walks):
##     on seeds 1, 7 and 42 every stone vertex within the style's tint +-
##     spread before occlusion, ochre, soot, moss and drift, none from
##     RuinBuilder's palette (poisoned, and a grep), every door a trapezoid
##     narrower at the top by top_share (and in the built tomb, measured by
##     rays), four pillars round the hearth with its shaft open, no ceiling
##     past max_span_m unsupported, the boss's hole off the pillars (and 30
##     more layouts), triangles per room inside 45,000, and the player's own
##     body through every door, corridor, stair and room.

## The seeds §EX.4's room torches are checked on (queue 47).
const TORCH_SEEDS := [1, 7, 42]
## The lit level's sample spacing over a room's floor and walls (m).
const LIT_STEP := 0.25
## The light (Godot's light energy units, after the falloff) at which lit
## tomb stone shows white: its red clips where the grade's exposure (0.9)
## times the stone's red (about 0.28 after the night pull and the painted
## light, ruin.gdshader) times this reaches 1. More light there can't be
## seen, so a sample counts at most this much (the hot patch on the wall
## right at a sconce counts as white, no more).
const LIT_WHITE := 4.0
## Seeds walked beyond 1, 7 and 42 (env WALK_SEEDS overrides).
const WALK_SEEDS := 200
## The walk's grid (m a cell), and how far over its floor your capsule is
## tried (clear of a flag's settled corner).
const WALK_CELL_M := 0.25
const WALK_LIFT_M := 0.1

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	# The residents (design §FE) stay asleep for these checks, which put
	# you all over the tomb; tools/residents_check.gd wakes them.
	Residents.stay_asleep = true
	_switch()
	var seeds := _walk_seeds()
	_layouts(seeds)
	_room_torches()
	await _walks(seeds)
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	await _scene(main)
	_masonry(main)
	_style_kit()
	await _style_scene(main)
	await _vents(main)
	_hearth_pit(main)
	_flue_slots(main)
	_firelight(main)
	_torch_room(main)
	await _ambience(main)
	await _relight(main)
	await _pitch(main)
	await _snuff(main)
	await _lean(main)
	await _douse(main)
	await _half_dark(main)
	await _rescuer(main)
	_sprite_kept(main)
	await _reticle(main)
	await _sneak(main)
	# The room sconces' lights, every holder still lit from _relight.
	await _torch_lights(main)
	await _way_out(main)
	await _stand_in(main)
	await _room_walks(main)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _switch() -> void:
	ok(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/boot.tscn", "the project boots the boot scene (scenes/boot.tscn)")
	var want := OS.get_environment("GAME")
	OS.set_environment("GAME", "")
	ok(GameMode.game() == "torchfire1" and GameMode.scene() == "res://scenes/crawler.tscn", "data/game.json picks Torchfire 1, the crawler (%s)" % GameMode.scene())
	OS.set_environment("GAME", "torchfire2")
	ok(GameMode.scene() == "res://scenes/main.tscn" and ResourceLoader.exists("res://scenes/main.tscn"), "GAME=torchfire2 opens the open world, still there (scenes/main.tscn)")
	OS.set_environment("GAME", want)


## The seeds the plan and the walk run over: 1, 7, 42 and WALK_SEEDS more
## from a fixed draw.
func _walk_seeds() -> Array:
	var n := WALK_SEEDS
	if OS.get_environment("WALK_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("WALK_SEEDS")), 0)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 46
	while out.size() < 3 + n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


## Is `v` m a whole number of modules `m`?
func _whole(v: float, m: float) -> bool:
	return absf(v / m - roundf(v / m)) < 1e-3 and roundf(v / m) >= 1.0


func _layouts(seeds: Array) -> void:
	var ways_ok := true
	var reach_ok := true
	var overlap_ok := true
	var heart_ok := true
	var holders_ok := true
	var spots_ok := true
	var exit_ok := true
	var spine_ok := true
	var longest_ok := true
	var share_ok := true
	var ends_ok := true
	var module_ok := true
	var heights_ok := true
	var centred_ok := true
	var facing_ok := true
	var strong := 0
	var rooms_n := 0
	var pieces_n := 0
	var stairs := 0
	var two_door := 0
	var facing_n := 0
	var spine_rooms := {}
	var kinds := {}
	var share := float((TombKit.PLAN.get("side_branches", {}) as Dictionary).get("side_share", 0.6))
	var want_exits := int(TombKit.EXIT.get("min", 1))
	var t0 := Time.get_ticks_msec()
	for s in seeds:
		var lay := TombKit.layout(int(s))
		var pieces: Array = lay.pieces
		var m := float(lay.module)
		var st := TombKit.style_of(str(lay.theme))
		var hs: Dictionary = st.get("heights_m", {})
		pieces_n += pieces.size()
		if int(lay.hearth_ways) < 3 or int(lay.hearth_ways) > 4 or (pieces[0].doors as Array).size() != int(lay.hearth_ways):
			ways_ok = false
			print("  seed %d: %d ways out of the hearth room" % [lay.seed, lay.hearth_ways])
		# Reachable through doors from the hearth room.
		var seen := {0: true}
		var stack := [0]
		while not stack.is_empty():
			var id: int = stack.pop_back()
			for di in pieces[id].doors:
				var d: Dictionary = lay.doors[di]
				for o in [int(d.a), int(d.b)]:
					if o >= 0 and not seen.has(o):
						seen[o] = true
						stack.append(o)
		if seen.size() != pieces.size():
			reach_ok = false
		# No overlaps but through a door.
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				var joined := false
				for di in pieces[i].doors:
					var d: Dictionary = lay.doors[di]
					if int(d.a) == j or int(d.b) == j:
						joined = true
				if joined:
					continue
				if TombKit.outer(pieces[i]).grow(-0.02).intersects(TombKit.outer(pieces[j]).grow(-0.02)):
					overlap_ok = false
					print("  seed %d: pieces %d and %d overlap" % [lay.seed, i, j])
		# The spine (§EX.2): from the hearth room through every one of its
		# rooms, the heart its last, on to the way out; never a dead end.
		var spine: Array = lay.spine
		var branches: Array = lay.branches
		if not lay.has("heart") or not spine.has(int(lay.heart)) or branches.is_empty() or (branches[0] as Array) != spine:
			heart_ok = false
			print("  seed %d: the heart %s is not on the spine %s" % [lay.seed, str(lay.get("heart")), str(spine)])
		var spine_room_ids: Array = []
		for id in spine:
			if str(pieces[id].kind) == "room":
				spine_room_ids.append(int(id))
		if spine_room_ids.is_empty() or int(spine_room_ids[-1]) != int(lay.get("heart", -1)):
			spine_ok = false
			print("  seed %d: the heart is not the spine's last room (%s)" % [lay.seed, str(spine_room_ids)])
		spine_rooms[spine_room_ids.size()] = int(spine_rooms.get(spine_room_ids.size(), 0)) + 1
		# Each spine piece joins the next through a door (one passage).
		var prev := 0
		for id in spine:
			var joined := false
			for di in pieces[prev].doors:
				var d: Dictionary = lay.doors[di]
				if (int(d.a) == prev and int(d.b) == int(id)) or (int(d.b) == prev and int(d.a) == int(id)):
					joined = true
			if not joined:
				spine_ok = false
				print("  seed %d: spine piece %d does not open off %d" % [lay.seed, id, prev])
			prev = int(id)
		# The way out (§EX.5): at least exit.min, at the spine's end, past the
		# heart, its opening out of the tomb.
		var exits: Array = lay.exits
		if exits.size() < want_exits:
			exit_ok = false
			print("  seed %d: %d ways out" % [lay.seed, exits.size()])
		for ex in exits:
			var od: Dictionary = lay.doors[int(ex.door)]
			if int(ex.heart) != int(lay.get("heart", -2)) or int(od.b) != -1 or int(od.a) != int(spine[-1]) or str(pieces[int(ex.stair)].kind) != "stair" \
					or float(pieces[int(ex.stair)].y1) - float(pieces[int(ex.stair)].y0) < float(TombKit.EXIT.get("rise_m", 6.0)) - 0.01:
				exit_ok = false
				print("  seed %d: way out %s is not past the heart at the spine's end" % [lay.seed, str(ex)])
		# The side ways: shorter, each ending in a room.
		for bi in range(1, branches.size()):
			var b: Array = branches[bi]
			var n := 0
			for id in b:
				if str(pieces[id].kind) == "room":
					n += 1
			if n >= spine_room_ids.size():
				longest_ok = false
			if n > floori(share * spine_room_ids.size() + 1e-4):
				share_ok = false
				print("  seed %d: side way %d has %d rooms, the spine %d" % [lay.seed, bi, n, spine_room_ids.size()])
			if b.is_empty() or str(pieces[int(b[-1])].kind) != "room":
				ends_ok = false
				print("  seed %d: side way %d ends in a %s" % [lay.seed, bi, pieces[int(b[-1])].kind if not b.is_empty() else "nothing"])
		# §EX.4: every holder a wall sconce (no hearth ring anywhere), each
		# room past the hearth room with its count.
		var in_room := {}
		for h in lay.holders:
			if str(h.kind) != "sconce":
				holders_ok = false
			elif bool(h.get("room", false)):
				in_room[int(h.piece)] = int(in_room.get(int(h.piece), 0)) + 1
		for pc in pieces:
			var k := str(pc.kind)
			# The module (§EX.2): a room's sides, a corridor's or flight's length.
			if k in ["room", "landing"]:
				if not _whole(float(pc.len), m) or not _whole(2.0 * float(pc.half), m):
					module_ok = false
					print("  seed %d: %s %d is %.2f x %.2f m, not whole %.1f m modules" % [lay.seed, k, pc.id, pc.len, 2.0 * float(pc.half), m])
			elif k in ["corridor", "stair"] and not _whole(float(pc.len), m):
				module_ok = false
				print("  seed %d: %s %d is %.2f m long, not whole %.1f m modules" % [lay.seed, k, pc.id, pc.len, m])
			# The style's heights.
			var hk := "hearth_room" if str(pc.get("room_kind", "")) == "hearth" else ("room" if k == "room" else "corridor")
			if hs.has(hk) and absf(float(pc.h) - float(hs[hk])) > 1e-4:
				heights_ok = false
				print("  seed %d: %s %d is %.2f m high, the style says %.2f" % [lay.seed, k, pc.id, pc.h, float(hs[hk])])
			if k == "room":
				kinds[str(pc.room_kind)] = int(kinds.get(str(pc.room_kind), 0)) + 1
				if str(pc.room_kind) != "hearth":
					rooms_n += 1
					if int(in_room.get(int(pc.id), 0)) != _sconces_wanted(lay, pc):
						holders_ok = false
				elif in_room.has(int(pc.id)):
					holders_ok = false
				# Doors centred on the walls they cut; two facing on the spine.
				var walls: Array = []
				for di in pc.doors:
					var sd: Array = TombKit.door_side(pc, lay.doors[di])
					walls.append(str(sd[0]))
					if absf(float(sd[1])) > 0.01:
						centred_ok = false
						print("  seed %d: door %d sits %.2f m off the middle of room %d's %s wall" % [lay.seed, di, float(sd[1]), pc.id, sd[0]])
				if walls.size() == 2:
					two_door += 1
					var faces := (walls.has("start") and walls.has("end")) or (walls.has("left") and walls.has("right"))
					if faces:
						facing_n += 1
					elif bool(pc.get("spine", false)):
						facing_ok = false
						print("  seed %d: spine room %d's doors don't face (%s)" % [lay.seed, pc.id, str(walls)])
			elif k == "stair":
				stairs += 1
		for a in lay.airways:
			if bool(a.strong):
				strong += 1
		var hr: Dictionary = pieces[0]
		for spot in [lay.wake[0], lay.bundle, lay.rescuer[0]]:
			var aa := Delves.along_across(hr, Vector2((spot as Vector3).x, (spot as Vector3).z))
			if aa.x < 0.5 or aa.x > float(hr.len) - 0.5 or absf(aa.y) > float(hr.half) - 0.5 or (spot as Vector3).length() < 0.8:
				spots_ok = false
	var n_s := seeds.size()
	ok(ways_ok, "%d seeds: three or four ways out of the hearth room every time" % n_s)
	ok(reach_ok, "every piece reachable from the hearth room through doors")
	ok(overlap_ok, "no two pieces overlap except through a door")
	ok(exit_ok, "every tomb has at least %d way out (exit.min): a flight climbing %.0f m from the heart's far wall at the spine's end, an opening out of the tomb at its top" % [want_exits, float(TombKit.EXIT.get("rise_m", 6.0))])
	ok(heart_ok and spine_ok, "the spine runs from the hearth room through the heart, its last room, door to door, on to the way out (spine rooms per tomb: %s)" % str(spine_rooms))
	ok(longest_ok and share_ok, "the spine is the longest way; every side way has at most %.0f%% of its rooms" % (share * 100.0))
	ok(ends_ok, "no side way ends in a bare corridor: each ends in a room")
	ok(module_ok, "every room's sides, every corridor and flight a whole number of the style's modules (%.1f m)" % float(TombKit.module_of("tomb")))
	ok(heights_ok, "every ceiling one of the style's heights (masonry.json heights_m)")
	ok(centred_ok, "every door centred on the wall it cuts")
	ok(facing_ok, "every spine room's two doors face each other (all two-door rooms: %d of %d facing)" % [facing_n, two_door])
	ok(holders_ok, "every room past the hearth room has its wall sconces by the rule, and no hearth ring anywhere (§EX.4; %d rooms)" % rooms_n)
	ok(spots_ok, "the mat, the bundle and the rescuer stand in the hearth room, clear of the hearth")
	ok(strong >= n_s * 0.8, "strong airway mouths placed (%d in %d tombs)" % [strong, n_s])
	print("  %d pieces in %d tombs (%.1f each), %d flights of stairs; rooms by kind %s (%d ms)" % [pieces_n, n_s, float(pieces_n) / n_s, stairs, str(kinds), Time.get_ticks_msec() - t0])


## The walk to the way out (design §EX.5, crawler.json exit.check) in
## every seed's tomb: PASS only if your body got out of every one.
func _walks(seeds: Array) -> void:
	var world_node := get_root().get_node("World")
	var walked: Array = []
	var failed: Array = []
	var t0 := Time.get_ticks_msec()
	for s in seeds:
		var r: Dictionary = await _walk_out_of(int(s), world_node)
		if bool(r.ok):
			walked.append(float(r.m))
		else:
			failed.append(s)
			print("  seed %d: your body did not get out: %s" % [s, r.why])
	walked.sort()
	var med := float(walked[walked.size() / 2]) if not walked.is_empty() else 0.0
	ok(failed.is_empty(), "%d seeds: your body (its capsule, floor rules and step) walks from the wake spot to the way out every time, every holder cold, no gate (none built)%s" % [seeds.size(), "" if failed.is_empty() else (": failed %s" % str(failed))])
	if not walked.is_empty():
		print("  the walk out: median %.0f m (shortest %.0f, longest %.0f; %d s for %d tombs)" % [med, walked[0], walked[-1], (Time.get_ticks_msec() - t0) / 1000, seeds.size()])


## The player's own body from the wake spot to the way out of tomb `seed_v`
## (exit.check: every holder cold, every gate shut; none are built), in
## the tomb's real collision (TombBuild's collision_only build: the game's
## faces and hulls exactly) and its cold fires (CrawlerFires), in a world
## of its own. First a route: a grid over the tomb's floors, WALK_CELL_M a
## cell, open where your capsule stands clear on the floor there (the same
## capsule, as a shape query: walls, lintels, coffins, rubble, fire rings;
## on stairs and through doorways the floor is found by a ray, the flight's
## ramp), A* over the open cells to the opening. Then your body walks it
## (CrawlerPlayer.step_body at WALK_SPEED, its floor rules: the slopes it
## can climb, the snap that holds it down) until it steps into the opening
## (WayOut.in_opening, the game's own test). {"ok", "m" (walked), "why"}.
func _walk_out_of(seed_v: int, world_node: Node) -> Dictionary:
	var lay := TombKit.layout(seed_v)
	if (lay.exits as Array).is_empty():
		return {"ok": false, "m": 0.0, "why": "no way out"}
	var ex: Dictionary = lay.exits[0]
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(4, 4)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_root().add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	root.add_child(CrawlerMain.collision_body(TombBuild.build(lay, true)))
	var fires := CrawlerFires.new()
	fires.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(fires)
	fires.build(world_node, lay)
	# The one who found you, sitting across the hearth: something to bump
	# into (§FH, HearthFolk's blocker), rolled as CrawlerMain rolls it.
	var seat: Array = lay.rescuer
	var rr := RandomNumberGenerator.new()
	rr.seed = hash([int(lay.seed), "rescuer"])
	var pal := CloakedFigure.roll_palette(rr, CloakedFigure.tribe_family(int(lay.seed)))
	HearthFolk.make(root, "Rescuer", seat[0], float(seat[1]), float(CrawlerMain.RES.get("height_m", 1.62)), pal, "")
	await physics_frame
	await physics_frame
	var space := vp.find_world_3d().direct_space_state
	var r := _route(lay, ex, space)
	if not bool(r.ok):
		NodeRelease.free_later(vp)
		return {"ok": false, "m": 0.0, "why": r.why}
	var result := await _walk_body(lay, ex, root, r.path)
	NodeRelease.free_later(vp)
	return result


## Where `p` (x/z) is: the piece or doorway, for a report.
func _where(lay: Dictionary, p: Vector3) -> String:
	var id := TombKit.piece_at(lay, p)
	if id < 0:
		for d in lay.doors:
			var dp: Vector2 = d.p
			if Vector2(p.x, p.z).distance_to(dp) < float(d.half) + 0.6:
				return "the doorway from piece %d to %d" % [d.a, d.b]
		return "outside every piece"
	var pc: Dictionary = lay.pieces[id]
	return "piece %d (%s%s%s)" % [id, pc.kind, (" " + str(pc.room_kind)) if pc.has("room_kind") else "", ", spine" if bool(pc.get("spine", false)) else ""]


## The route (_walk_out_of): {"ok", "path" [Vector3 cell middles on their
## floors], "why"}.
func _route(lay: Dictionary, ex: Dictionary, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var g := WALK_CELL_M
	var bounds := Delves.rect_of(lay.pieces[0], 2.0)
	for pc in lay.pieces:
		bounds = bounds.merge(Delves.rect_of(pc, 2.0))
	bounds = bounds.grow(TombBuild.OUTSIDE_M + 1.0)
	var w := ceili(bounds.size.x / g) + 1
	var h := ceili(bounds.size.y / g) + 1
	var cell := func(x: float, z: float) -> Vector2i:
		return Vector2i(roundi((x - bounds.position.x) / g), roundi((z - bounds.position.y) / g))
	var mid := func(c: Vector2i) -> Vector2:
		return bounds.position + Vector2(c) * g
	# Each cell's floor: a piece's own (rooms, corridors, the landing: flat),
	# or a ray's (stairs and doorways: the flight's ramp runs through them);
	# NAN off the floors.
	var fy := PackedFloat32Array()
	fy.resize(w * h)
	fy.fill(NAN)
	var by_ray := PackedByteArray()
	by_ray.resize(w * h)
	var goal_cells: Array = []
	for pc in lay.pieces:
		var rr := Delves.rect_of(pc, 0.0)
		var c0: Vector2i = cell.call(rr.position.x, rr.position.y)
		var c1: Vector2i = cell.call(rr.end.x, rr.end.y)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q: Vector2 = mid.call(Vector2i(i, j))
				var aa := Delves.along_across(pc, q)
				if aa.x < 0.0 or aa.x > float(pc.len) or absf(aa.y) > float(pc.half):
					continue
				fy[j * w + i] = Delves.floor_of(pc, aa.x)
				by_ray[j * w + i] = 1 if str(pc.kind) == "stair" else 0
	for d in lay.doors:
		var dp: Vector2 = d.p
		var dn: Vector2 = d.n
		var out := Delves.WALL * 0.5 + (TombBuild.OUTSIDE_M if int(d.b) < 0 else 0.05)
		var reach := Vector2(Delves.WALL * 0.5 + 0.05, out)
		var ext := float(d.half) + 0.1
		var corners := [dp - dn * reach.x - Delves.perp(dn) * ext, dp + dn * reach.y + Delves.perp(dn) * ext]
		var rr := Rect2(corners[0], Vector2.ZERO).expand(corners[1])
		var c0: Vector2i = cell.call(rr.position.x, rr.position.y)
		var c1: Vector2i = cell.call(rr.end.x, rr.end.y)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q: Vector2 = mid.call(Vector2i(i, j))
				var rel := q - dp
				var along := rel.dot(dn)
				if along < -reach.x or along > reach.y or absf(rel.dot(Delves.perp(dn))) > float(d.half):
					continue
				if is_nan(fy[j * w + i]):
					fy[j * w + i] = float(d.y)
					by_ray[j * w + i] = 1
				if int(d.b) < 0 and WayOut.in_opening(ex, Vector3(q.x, float(d.y), q.y)):
					goal_cells.append(Vector2i(i, j))
	# Open where your capsule stands clear.
	var shape := CrawlerPlayer.body_shape()
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = shape
	qs.collision_mask = 1
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(g, g)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	astar.fill_solid_region(astar.region, true)
	var floor_at := PackedFloat32Array()
	floor_at.resize(w * h)
	var open := 0
	for k in w * h:
		if is_nan(fy[k]):
			continue
		var c := Vector2i(k % w, k / w)
		var q: Vector2 = mid.call(c)
		var y := fy[k]
		if by_ray[k] == 1:
			var rq := PhysicsRayQueryParameters3D.create(Vector3(q.x, y + 1.0, q.y), Vector3(q.x, y - 0.8, q.y))
			var hit := space.intersect_ray(rq)
			if hit.is_empty():
				continue
			y = (hit.position as Vector3).y
		floor_at[k] = y
		qs.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, y + WALK_LIFT_M + CrawlerPlayer.STAND_HEIGHT * 0.5, q.y))
		if space.intersect_shape(qs, 1).is_empty():
			astar.set_point_solid(c, false)
			open += 1
	var wk: Vector3 = (lay.wake as Array)[0]
	var start: Vector2i = cell.call(wk.x, wk.z)
	if astar.is_point_solid(start):
		return {"ok": false, "why": "your capsule doesn't fit at the wake spot (%s)" % str(wk)}
	var goal := Vector2i(-1, -1)
	var od := Vector2((ex.p as Vector3).x, (ex.p as Vector3).z)
	var best := INF
	for c in goal_cells:
		var dd := (mid.call(c) as Vector2).distance_to(od)
		if not astar.is_point_solid(c) and dd < best:
			best = dd
			goal = c
	if goal.x < 0:
		return {"ok": false, "why": "your capsule doesn't fit in the opening (%d goal cells)" % goal_cells.size()}
	var ids := astar.get_id_path(start, goal, true)
	if ids.is_empty() or ids[-1] != goal:
		var last: Vector2i = ids[-1] if not ids.is_empty() else start
		var lq: Vector2 = mid.call(last)
		var lp := Vector3(lq.x, floor_at[last.y * w + last.x], lq.y)
		return {"ok": false, "why": "no route for your capsule: it gets as far as %s at %s (%d open cells)" % [_where(lay, lp), str(lp.snapped(Vector3.ONE * 0.01)), open]}
	var path: Array = []
	for c in ids:
		var q: Vector2 = mid.call(c)
		path.append(Vector3(q.x, floor_at[c.y * w + c.x], q.y))
	return {"ok": true, "path": path}


## Your body along `path` (_route) until it steps into way out `ex`'s
## opening: {"ok", "m", "why"}.
func _walk_body(lay: Dictionary, ex: Dictionary, root: Node3D, path: Array) -> Dictionary:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	cs.shape = CrawlerPlayer.body_shape()
	cs.position = Vector3(0.0, CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0)
	body.add_child(cs)
	CrawlerPlayer.floor_rules(body)
	root.add_child(body)
	var wk: Vector3 = (lay.wake as Array)[0]
	body.global_position = wk + Vector3(0.0, 0.05, 0.0)
	await physics_frame
	var dt := 1.0 / 60.0
	var k := 0
	var walked := 0.0
	var best := INF
	var stall := 0
	var left := 0.0
	for i in range(1, path.size()):
		left += (path[i] as Vector3).distance_to(path[i - 1])
	var steps := int(left / maxf(CrawlerPlayer.WALK_SPEED, 0.5) * 60.0 * 2.0) + 600
	for i in steps:
		var pos := body.global_position
		# The next point at least 0.35 m off (cells are 0.25 m).
		while k < path.size() - 1 and Vector2(pos.x - (path[k] as Vector3).x, pos.z - (path[k] as Vector3).z).length() < 0.35:
			k += 1
		var to: Vector3 = (path[k] as Vector3) - pos
		to.y = 0.0
		var wish := to.normalized() if to.length() > 0.02 else Vector3.ZERO
		CrawlerPlayer.step_body(body, wish, CrawlerPlayer.WALK_SPEED, dt)
		walked += body.global_position.distance_to(pos)
		if WayOut.in_opening(ex, body.global_position):
			return {"ok": true, "m": walked, "why": ""}
		# Stuck: no nearer the end of the route in two seconds.
		var togo := float(path.size() - k) * WALK_CELL_M + to.length()
		if togo < best - 0.05:
			best = togo
			stall = 0
		else:
			stall += 1
			if stall > 120:
				return {"ok": false, "m": walked, "why": "your body stuck in %s at %s, on the floor %s" % [_where(lay, body.global_position), str(body.global_position.snapped(Vector3.ONE * 0.01)), body.is_on_floor()]}
		if body.global_position.y < float(ex.y) - 30.0:
			return {"ok": false, "m": walked, "why": "your body fell out of the tomb near %s" % _where(lay, pos)}
	return {"ok": false, "m": walked, "why": "your body ran out of time in %s" % _where(lay, body.global_position)}


## How many wall sconces room `pc` should have (design §EX.4, crawler.json
## room_torches): the heart `heart`; else `small` when its long walls are
## up to small_room_max_m, `large` when longer.
func _sconces_wanted(lay: Dictionary, pc: Dictionary) -> int:
	var rt: Dictionary = TombKit.RT
	if str(pc.room_kind) == "heart":
		return int(rt.get("heart", 4))
	var long := maxf(float(pc.len), 2.0 * float(pc.half))
	var n := int(rt.get("small", 2)) if long <= float(rt.get("small_room_max_m", 8.0)) + 0.001 else int(rt.get("large", 4))
	# A room on pillars: two facing pairs (room_torches.pillared; Mike, 7 Oct).
	return maxi(n, int(rt.get("pillared", 4))) if TombBuild.on_pillars(lay, pc) else n


## A full fire's light energy at night (look.json fire.light; Campfire.
## flicker with its flicker at the middle; underground it is always night).
static func _fire_energy() -> float:
	return Campfire.LIGHT_ENERGY * float(Campfire.L.get("night_energy_scale", 1.3))


## The light a sconce holder `h` gives, as the lit level counts it:
## [position, energy, range, decay] (CrawlerFires._sconce: its cup in its
## niche, design §EX.3, the light 0.3 m over it and LIGHT_OUT_M out from
## the wall, in front of the niche; energy_k, light_radius_m).
static func _sconce_light(h: Dictionary) -> Array:
	var k := float(CrawlerFires.HOLD.get("sconce_scale", 0.38)) * 1.4 * (float(TombKit.RT.get("light_scale", 1.0)) if bool(h.get("room", false)) else 1.0)
	return [(h.pos as Vector3) + (h.normal as Vector3) * CrawlerFires.LIGHT_OUT_M + Vector3(0.0, 0.3, 0.0), _fire_energy() * k, float(CrawlerFires.FH.get("light_radius_m", 8.0)), Campfire.ATTENUATION]


## Room `pc`'s old hearth ring's light (until §EX.4, TombKit put one in
## every room past the hearth room: in its middle, 0.62 of the way down
## the heart; a Campfire's light 1 m over the ring).
static func _ring_light(pc: Dictionary) -> Array:
	var at: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * (0.62 if str(pc.room_kind) == "heart" else 0.5)
	return [Vector3(at.x, float(pc.y0) + 1.0, at.y), _fire_energy(), float(CrawlerFires.FH.get("light_radius_m", 8.0)), Campfire.ATTENUATION]


## How lit room `pc` of `lay` is by `lights` ([[position, energy, range,
## decay]...]): the light on its floor and its walls, sampled every
## LIT_STEP m (the walls up to its ceiling, not across its doorways), as
## Godot lights a Lambert surface (energy x the cosine x the omni's falloff,
## (1 - (d / range)^4)^2 / d^decay). Returns [the mean share of white
## (each sample capped at LIT_WHITE), the mean light uncapped].
func _lit_level(lay: Dictionary, pc: Dictionary, lights: Array) -> Array:
	var dv: Vector2 = pc.dir
	var pv := Delves.perp(dv)
	var length := float(pc.len)
	var half := float(pc.half)
	var y0 := float(pc.y0)
	var samples: Array = []
	var a := LIT_STEP * 0.5
	while a < length:
		var c := -half + LIT_STEP * 0.5
		while c < half:
			var q: Vector2 = (pc.c as Vector2) + dv * a + pv * c
			samples.append([Vector3(q.x, y0, q.y), Vector3.UP])
			c += LIT_STEP
		a += LIT_STEP
	var doors: Array = []
	for di in pc.doors:
		doors.append(lay.doors[di])
	for side in ["start", "end", "left", "right"]:
		var span := TombKit.wall_len(pc, side)
		var off := -span * 0.5 + LIT_STEP * 0.5
		while off < span * 0.5:
			var fp := TombKit.face_point(pc, side, off)
			var q: Vector2 = fp[0]
			var n2: Vector2 = fp[1]
			var y := y0 + LIT_STEP * 0.5
			while y < y0 + float(pc.h):
				var open := false
				for d in doors:
					if TombKit.door_gap(d, q) < 0.01 and y < float(d.y) + float(d.h):
						open = true
				if not open:
					samples.append([Vector3(q.x, y, q.y), Vector3(n2.x, 0.0, n2.y)])
				y += LIT_STEP
			off += LIT_STEP
	var seen := 0.0
	var plain := 0.0
	for s in samples:
		var p: Vector3 = s[0]
		var nrm: Vector3 = s[1]
		var e := 0.0
		for l in lights:
			var v: Vector3 = (l[0] as Vector3) - p
			var d := maxf(v.length(), 1e-4)
			var cs := nrm.dot(v) / d
			if cs <= 0.0:
				continue
			var fall := maxf(1.0 - pow(d / float(l[2]), 4.0), 0.0)
			e += float(l[1]) * cs * fall * fall * pow(d, -float(l[3]))
		seen += minf(e, LIT_WHITE)
		plain += e
	var n_s := maxf(samples.size(), 1.0)
	return [seen / n_s / LIT_WHITE, plain / n_s]


## One hearth per dungeon; wall torches in every other room (design §EX.4;
## crawler.json room_torches), on TORCH_SEEDS: the layouts, their vents and
## airways, and each room's light with its sconces relit against its old
## hearth ring.
func _room_torches() -> void:
	var rt: Dictionary = TombKit.RT
	var clear := float(rt.get("clear_m", 0.6))
	var flank := int(rt.get("heart_flank_dead", 2))
	var opp := {"left": "right", "right": "left", "start": "end", "end": "start"}
	var hearths_ok := true
	var counts_ok := true
	var heart_ok := true
	var long_ok := true
	var spaced_ok := true
	var faced := 0
	var n_pairs := 0
	var vents_ok := true
	var air_ok := true
	var lit_ok := true
	var least_gap := INF
	var n_sconces := 0
	var n_rooms := 0
	var pillared_ok := true
	var n_pillared := 0
	# By kind of room: [old ring's share of white, sconces', old ring's
	# light, sconces', rooms].
	var sums := {"small": [0.0, 0.0, 0.0, 0.0, 0], "large": [0.0, 0.0, 0.0, 0.0, 0], "heart": [0.0, 0.0, 0.0, 0.0, 0]}
	var worst := INF
	var worst_what := ""
	var t0 := Time.get_ticks_msec()
	for seed_v in TORCH_SEEDS:
		var lay := TombKit.layout(int(seed_v))
		var module := TombKit.module_of(str(lay.theme))
		# One hearth, the hearth room's; every holder a sconce.
		var hearth_rooms := 0
		for pc in lay.pieces:
			if str(pc.kind) == "room" and str(pc.room_kind) == "hearth":
				hearth_rooms += 1
		var not_sconce := 0
		for h in lay.holders:
			if str(h.kind) != "sconce" or TombKit.vent_type(str(h.kind)) == "shaft":
				not_sconce += 1
		if hearth_rooms != int(rt.get("hearth_rooms", 1)) or TombKit.piece_at(lay, lay.hearth) != 0 or str((lay.pieces[0] as Dictionary).room_kind) != "hearth" or not_sconce > 0:
			hearths_ok = false
			print("  seed %d: %d hearth rooms, the hearth in piece %d, %d other fires not sconces" % [seed_v, hearth_rooms, TombKit.piece_at(lay, lay.hearth), not_sconce])
		var by_room := {}
		for h in lay.holders:
			n_sconces += 1
			var q := Vector2((h.pos as Vector3).x, (h.pos as Vector3).z)
			for d in lay.doors:
				var g := TombKit.door_gap(d, q)
				if g < least_gap:
					least_gap = g
			if bool(h.get("room", false)):
				if not by_room.has(int(h.piece)):
					by_room[int(h.piece)] = []
				(by_room[int(h.piece)] as Array).append(h)
		for pc in lay.pieces:
			if str(pc.kind) != "room" or str(pc.room_kind) == "hearth":
				continue
			n_rooms += 1
			var mine: Array = by_room.get(int(pc.id), [])
			if mine.size() != _sconces_wanted(lay, pc):
				counts_ok = false
				print("  seed %d room %d (%s, %.1f x %.1f m): %d sconces, the rule says %d" % [seed_v, pc.id, pc.room_kind, pc.len, 2.0 * float(pc.half), mine.size(), _sconces_wanted(lay, pc)])
			# On the long walls (the heart's side walls), in facing pairs where
			# the doors allow, whole modules apart down each wall.
			var long_walls: Array = ["left", "right"] if str(pc.room_kind) == "heart" or float(pc.len) >= 2.0 * float(pc.half) - 0.001 else ["start", "end"]
			var walls := {}
			for h in mine:
				if not walls.has(str(h.side)):
					walls[str(h.side)] = []
				(walls[str(h.side)] as Array).append(float(h.off))
				if not str(h.side) in long_walls and absf(float(pc.len) - 2.0 * float(pc.half)) > 0.001:
					long_ok = false
					print("  seed %d room %d (%.1f x %.1f m): a sconce on its short %s wall" % [seed_v, pc.id, pc.len, 2.0 * float(pc.half), h.side])
			for side in walls:
				var offs: Array = walls[side]
				offs.sort()
				if side in ["left", "start"]:
					for o in offs:
						n_pairs += 1
						for o2 in walls.get(opp[side], []):
							if absf(float(o2) - float(o)) < 0.01:
								faced += 1
								break
				for i in range(1, offs.size()):
					var m := (float(offs[i]) - float(offs[i - 1])) / module
					if absf(m - roundf(m)) > 0.001 or roundf(m) < 1.0:
						spaced_ok = false
						print("  seed %d room %d: sconces %.2f m apart on its %s wall" % [seed_v, pc.id, float(offs[i]) - float(offs[i - 1]), side])
			var is_heart := str(pc.room_kind) == "heart"
			if is_heart:
				# Two each side, one before the dead and one past them.
				var dead := float(pc.len) * 0.5 - TombKit.HEART_DEAD_M
				for side in ["left", "right"]:
					var offs: Array = walls.get(side, [])
					if offs.size() != flank or float(offs.min()) >= dead or float(offs.max()) <= dead:
						heart_ok = false
						print("  seed %d heart %d: its %s wall's sconces %s, the dead at %.2f" % [seed_v, pc.id, side, str(offs), dead])
			# Its light: the sconces relit against the old hearth ring.
			var lights: Array = []
			for h in mine:
				lights.append(_sconce_light(h))
			var now_l := _lit_level(lay, pc, lights)
			var old_l := _lit_level(lay, pc, [_ring_light(pc)])
			var cls := "heart" if is_heart else ("small" if mine.size() <= int(rt.get("small", 2)) else "large")
			var sm: Array = sums[cls]
			sm[0] = float(sm[0]) + float(old_l[0])
			sm[1] = float(sm[1]) + float(now_l[0])
			sm[2] = float(sm[2]) + float(old_l[1])
			sm[3] = float(sm[3]) + float(now_l[1])
			sm[4] = int(sm[4]) + 1
			var ratio := float(now_l[0]) / maxf(float(old_l[0]), 1e-6)
			if ratio < worst:
				worst = ratio
				worst_what = "seed %d room %d (%s, %.1f x %.1f m, %d sconces): %.2f against the ring's %.2f" % [seed_v, pc.id, pc.room_kind, pc.len, 2.0 * float(pc.half), mine.size(), now_l[0], old_l[0]]
			if float(now_l[0]) < float(old_l[0]) or float(now_l[1]) < float(old_l[1]):
				lit_ok = false
				print("  seed %d room %d (%s, %d sconces): lit %.3f (%.2f) against the old ring's %.3f (%.2f)" % [seed_v, pc.id, pc.room_kind, mine.size(), now_l[0], now_l[1], old_l[0], old_l[1]])
		# The vents: one shaft (the hearth's), one flue per sconce.
		var shafts := 0
		var flues := {}
		for v in lay.vents:
			if str(v.type) == "shaft":
				shafts += 1
				if int(v.fire_index) != -1:
					vents_ok = false
			elif str(v.kind) == "sconce":
				flues[int(v.fire_index)] = int(flues.get(int(v.fire_index), 0)) + 1
		if shafts != 1 or flues.size() != (lay.holders as Array).size():
			vents_ok = false
			print("  seed %d: %d shafts, %d sconces with a flue of %d" % [seed_v, shafts, flues.size(), (lay.holders as Array).size()])
		for k in flues:
			if int(flues[k]) != 1:
				vents_ok = false
		# A room standing on pillars as built has two facing pairs of wall
		# torches (room_torches.pillared; Mike, 7 Oct): its pillars shadow a
		# single pair's light off the floor (queue 48).
		var plans: Dictionary = TombBuild.build(lay, true).plans
		for id in plans:
			var pp: Dictionary = lay.pieces[int(id)]
			if str(pp.kind) != "room" or str(pp.room_kind) in ["hearth", "heart"] or (plans[id].pillars as Array).is_empty():
				continue
			n_pillared += 1
			if (by_room.get(int(id), []) as Array).size() < int(rt.get("pillared", 4)) or not TombBuild.on_pillars(lay, pp):
				pillared_ok = false
				print("  seed %d room %d (%s, %.1f x %.1f m) stands on pillars with %d wall torches" % [seed_v, int(id), pp.room_kind, pp.len, 2.0 * float(pp.half), (by_room.get(int(id), []) as Array).size()])
		# The airways clear of the sconces on their wall.
		for aw in lay.airways:
			var pc: Dictionary = lay.pieces[int(aw.piece)]
			var ap: Vector3 = aw.pos
			var aa := Delves.along_across(pc, Vector2(ap.x, ap.z))
			var need := float(TombKit.AIRWAY_HALF[0 if bool(aw.strong) else 1]) + clear + TombKit.SCONCE_HALF - 0.001
			for h in lay.holders:
				if int(h.piece) != int(pc.id):
					continue
				var sa := Delves.along_across(pc, Vector2((h.pos as Vector3).x, (h.pos as Vector3).z))
				if absf(absf(sa.y) - float(pc.half)) < 0.05 and signf(sa.y) == signf(aa.y) and absf(sa.x - aa.x) < need:
					air_ok = false
					print("  seed %d: an airway %.2f m from a sconce on its wall" % [seed_v, absf(sa.x - aa.x)])
	ok(hearths_ok, "seeds %s: one hearth per tomb, in the hearth room; every other fire a wall sconce (§EX.4)" % str(TORCH_SEEDS))
	ok(counts_ok, "every other room has its sconces: %d up to %.0f m long, %d longer or on pillars, the heart %d (%d rooms, %d sconces in all)" % [int(rt.get("small", 2)), float(rt.get("small_room_max_m", 8.0)), int(rt.get("large", 4)), int(rt.get("heart", 4)), n_rooms, n_sconces])
	ok(heart_ok, "the heart's: %d on each side wall, flanking the dead" % flank)
	ok(pillared_ok and n_pillared > 0, "every room standing on pillars as built has %d wall torches, two facing pairs (room_torches.pillared, Mike 7 Oct; %d rooms on pillars)" % [int(rt.get("pillared", 4)), n_pillared])
	ok(long_ok and spaced_ok, "the rooms' sconces stand on their long walls, whole modules apart (%.0f m, masonry.json styles module_m)" % TombKit.module_of("tomb"))
	ok(faced >= n_pairs * 0.9, "and in facing pairs where the doors allow: %d of %d pairs face each other exactly (the rest step apart to clear a door)" % [faced, n_pairs])
	ok(least_gap >= clear - 0.001, "no sconce within %.1f m of a door's edge (the nearest %.2f m)" % [clear, least_gap])
	ok(vents_ok, "vents: one shaft per tomb (the hearth's, its daylight the only column), one flue per sconce")
	ok(air_ok, "the airways keep clear of the sconces")
	for cls in ["small", "large", "heart"]:
		var sm: Array = sums[cls]
		if int(sm[4]) > 0:
			var n := float(sm[4])
			print("  lit, %s rooms (%d): old hearth ring %.2f of white (light %.2f), sconces relit %.2f (light %.2f)" % [cls, int(sm[4]), float(sm[0]) / n, float(sm[2]) / n, float(sm[1]) / n, float(sm[3]) / n])
	print("  the least lit against its old ring: %s (light_scale %.2f; %d ms)" % [worst_what, float(rt.get("light_scale", 1.0)), Time.get_ticks_msec() - t0])
	ok(lit_ok, "with its sconces relit, every room is at least as lit as with its old hearth ring (the worst %.2f times)" % worst)


func _ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	return get_root().get_world_3d().direct_space_state.intersect_ray(q)


func _scene(main: CrawlerMain) -> void:
	var lay := main.lay
	var floors := true
	var ceilings := true
	for pc in lay.pieces:
		# A few spots across the piece (a holder's logs or a coffin may
		# stand on one): the floor must be found at its height at most.
		var found := 0
		var fy := Delves.floor_of(pc, float(pc.len) * 0.5)
		var c2 := Vector2.ZERO
		for spot in [[0.5, 0.3], [0.2, 0.0], [0.8, 0.0], [0.35, -0.5]]:
			var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * float(spot[0]) + Delves.perp(pc.dir) * float(spot[1])
			var y := Delves.floor_of(pc, float(pc.len) * float(spot[0]))
			var hit := _ray(Vector3(q.x, y + 1.2, q.y), Vector3(q.x, y - 1.0, q.y), [main.player.get_rid()])
			if not hit.is_empty() and absf((hit.position as Vector3).y - y) <= (0.45 if str(pc.kind) == "stair" else 0.12):
				found += 1
				c2 = q
		if found < 2:
			floors = false
			print("  piece %d (%s): the floor found at %d of 4 spots" % [pc.id, pc.kind, found])
		# A ceiling over it (any of the spots: one may sit under a flue).
		var roofed := false
		for spot2 in [[0.5, 0.3], [0.2, 0.0], [0.8, 0.0], [0.35, -0.5]]:
			var q2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * float(spot2[0]) + Delves.perp(pc.dir) * float(spot2[1])
			var y2 := Delves.floor_of(pc, float(pc.len) * float(spot2[0]))
			if not _ray(Vector3(q2.x, y2 + 1.2, q2.y), Vector3(q2.x, y2 + float(pc.h) + 3.0, q2.y), [main.player.get_rid()]).is_empty():
				roofed = true
		if not roofed:
			ceilings = false
			print("  piece %d (%s): no ceiling" % [pc.id, pc.kind])
	ok(floors, "a floor under every piece, at its height")
	ok(ceilings, "a ceiling over every piece")
	ok(main.player.is_on_floor() and absf(main.player.global_position.y) < 0.2, "you wake standing on the hearth room's floor (y %.2f)" % main.player.global_position.y)
	print("  the tomb's stone: %d triangles" % int(main.tomb.get_meta("triangles", 0)))


func _place_facing(p: CrawlerPlayer, at: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z))


func _lights_on(main: CrawlerMain) -> int:
	var n := 0
	for l in main.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		if o.is_visible_in_tree() and o.light_energy > 0.01:
			n += 1
	return n


func _relight(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var fires := main.fires
	ok(p.weapon == "hands" and not t.in_hand(), "you wake with nothing in hand (§AW)")
	ok(FireStore.is_lit(fires.hearth), "the hearth is lit")
	ok(fires.lit_count() == 0, "every holder starts cold (%d holders)" % fires.holders.size())
	for i in 5:
		await process_frame
	ok(_lights_on(main) == 1, "full dark: the hearth's is the only light burning (%d)" % _lights_on(main))
	# The bundle.
	_place_facing(p, fires.bundle.global_position + Vector3(1.0, 0.0, 0.0), fires.bundle.global_position)
	var before := fires.bundle_left
	ok(main.take_torch() and t.in_hand() and not t.lit() and fires.bundle_left == before - 1, "right click by the bundle takes an unlit torch into your hand (%d left)" % fires.bundle_left)
	# Lit at the hearth.
	var hp := fires.hearth.global_position
	_place_facing(p, hp + Vector3(0.0, 0.0, 1.0), hp)
	ok(t.pass_flame() == "torch" and t.lit(), "the swing through the hearth lights the torch (§CN)")
	# Every holder.
	var all_caught := true
	for h in fires.holders:
		var at := h.global_position
		var stand := _stand_by(main, h)
		_place_facing(p, stand, at)
		var how := t.pass_flame()
		if not how.begins_with("fire:"):
			all_caught = false
			print("  holder %s at %s: the swing passed '%s'" % [h.name, str(at), how])
	ok(all_caught, "the swing reaches every holder")
	for i in 240:
		FireStore.tick(self, 1.0 / 60.0, p.global_position)
	ok(fires.lit_count() == fires.holders.size(), "every holder caught (%d of %d)" % [fires.lit_count(), fires.holders.size()])
	FireStore.tick(self, 3600.0, p.global_position)
	for i in 6:
		FireStore.tick(self, 600.0, p.global_position)
	ok(fires.lit_count() == fires.holders.size(), "relit holders stay lit an hour on (kept, §ET.4)")
	# A dead torch relit at a holder.
	t.put_out("stowed")
	var h0: Node3D = fires.holders[0]
	var st0 := _stand_by(main, h0)
	_place_facing(p, st0, h0.global_position)
	ok(not t.lit() and t.pass_flame() == "torch" and t.lit(), "a dead torch relights at a relit holder")


## The pitch torch's parts showing on one head: (flame cards, coals).
func _fire_parts(head: Node3D) -> Vector2i:
	var n := Vector2i.ZERO
	for c in head.find_children("*", "Node3D", true, false):
		if not (c as Node3D).is_visible_in_tree():
			continue
		if c.name == "Card":
			n.x += 1
		elif c.name == "Coal":
			n.y += 1
	return n


## The wrap's shape (PitchTorch's mesh, surface 0): "" when every corner
## sits on one of the six sides, the top is flat (nothing above it, its
## faces flat up or the sides', no dome), there are only the bands' own
## heights, and each band's lower edge stands out over the one below (a
## step); else what is wrong.
func _wrap_shape(head: Node3D) -> String:
	var L := PitchTorch.length_m()
	var n := PitchTorch.sides()
	var nb := PitchTorch.bands()
	var wrap := head.get_node_or_null("Wrap") as MeshInstance3D
	if wrap == null:
		return "no wrap"
	var arr := (wrap.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var radii := {}
	for i in v.size():
		var q := v[i]
		if q.y > L + 1e-5:
			return "a vertex above the flat top (y %.4f)" % q.y
		var lv := snappedf(q.y, 1e-4)
		var r := Vector2(q.x, q.z).length()
		if r > 1e-5:
			var a := fposmod(atan2(q.x, q.z), TAU / n)
			if a > 1e-3 and a < TAU / n - 1e-3:
				return "a corner off the %d sides (%.3f rad)" % [n, a]
			if not radii.has(lv):
				radii[lv] = []
			if not (radii[lv] as Array).any(func(x): return absf(float(x) - r) < 1e-5):
				(radii[lv] as Array).append(r)
		if absf(q.y - L) < 1e-5 and nm[i].y > 0.2 and nm[i].y < 0.99:
			return "a sloping face at the top (normal y %.2f): rounded" % nm[i].y
	var heights := radii.keys()
	heights.sort()
	if heights.size() != nb + 1:
		return "%d heights, not the bands' %d" % [heights.size(), nb + 1]
	for k in range(1, nb):
		var rs: Array = radii[heights[k]]
		if rs.size() != 2 or float(rs.max()) < float(rs.min()) * 1.08:
			return "band %d: no step at its lower edge (%s)" % [k, str(rs)]
	return ""


## No shine (the R-rules): "" for a material with no specular, roughness 1
## and no normal map (an unshaded one has no light at all); else why.
func _shine(m: Material) -> String:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.normal_enabled:
			return "a normal map"
		if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			return ""
		if b.specular_mode != BaseMaterial3D.SPECULAR_DISABLED and b.metallic_specular > 0.0:
			return "specular %.2f" % b.metallic_specular
		if b.roughness < 1.0:
			return "roughness %.2f" % b.roughness
		if b.metallic > 0.0:
			return "metallic %.2f" % b.metallic
		return ""
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var code := (m as ShaderMaterial).shader.code
		if code.contains("NORMAL_MAP"):
			return "a normal map"
		var rm := ""
		for line in code.split("\n"):
			if line.strip_edges().begins_with("render_mode"):
				rm = line
		if rm.contains("unshaded"):
			return ""
		if not rm.contains("specular_disabled"):
			return "specular (no specular_disabled)"
		var re := RegEx.new()
		re.compile("ROUGHNESS\\s*=\\s*([0-9.]+)")
		for mt in re.search_all(code):
			if float(mt.get_string(1)) < 1.0:
				return "roughness %s" % mt.get_string(1)
		return ""
	return "no material"


## The pitch torch (design 6 Oct §EZ.2; PitchTorch, torch.json
## pitch_head): every torch in the built tomb.
func _pitch(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var fires := main.fires
	await _frames(2)
	# The bundle's torches: the pitch head alone.
	var bundle_heads: Array = []
	for c in fires.bundle.get_children():
		if c.has_meta("pitch_head") and not c.is_queued_for_deletion():
			bundle_heads.append(c)
	var none := true
	for h in bundle_heads:
		if _fire_parts(h) != Vector2i.ZERO or not (h as Node3D).is_visible_in_tree():
			none = false
	ok(bundle_heads.size() == fires.bundle_left and fires.bundle_left > 0 and none, "the bundle's %d torches: the pitch head alone, no coal, no flame (unlit)" % bundle_heads.size())
	# In hand: lit, put out with burn left, burnt out.
	var vh: Node3D = t._view_flame
	ok(t.pitch and t.lit() and vh.has_meta("pitch_head") and _fire_parts(vh) == Vector2i(1, 1), "the torch in hand, lit: one flame card and one coal on its pitch head (%s)" % str(_fire_parts(vh)))
	var card := vh.get_node("Flame/Card") as MeshInstance3D
	var tx: Vector2 = (card.material_override as ShaderMaterial).get_shader_parameter("texels")
	ok(tx.is_equal_approx(PitchTorch.flame_texels()) and tx.y < float((Campfire.FL.get("texels", [32, 48]) as Array)[1]), "its flame card is on a coarser texel grid than the campfire's (%dx%d)" % [int(tx.x), int(tx.y)])
	t.put_out("doused")
	ok(not t.lit() and _fire_parts(vh) == Vector2i.ZERO and vh.is_visible_in_tree(), "put out with burn left: the pitch head alone in hand, no coal, no flame")
	var it := t.item()
	t.put_out("burnt")
	ok(not vh.is_visible_in_tree() and (t._view.get_node("Stick") as Node3D).is_visible_in_tree(), "burnt out: a bare stick, as built")
	it.erase("burnt")
	it["burn_left_min"] = float(Torch.D.get("burn_min", 50.0))
	t.light()
	# Planted in the tomb: lit, out with burn left, burnt out.
	var at := p.global_position + Vector3(0.0, 0.0, 0.0)
	var pl := PlantedTorch.plant(Inventory.make("torch", {"lit": true, "burn_left_min": 30.0}), main.world, at + Vector3(0.6, 0.0, 0.0), Vector3.UP, false, main)
	var po := PlantedTorch.plant(Inventory.make("torch", {"lit": false, "burn_left_min": 12.0}), main.world, at + Vector3(1.2, 0.0, 0.0), Vector3.UP, false, main)
	var pb := PlantedTorch.plant(Inventory.make("torch", {"lit": false, "burnt": true}), main.world, at + Vector3(1.8, 0.0, 0.0), Vector3.UP, false, main)
	await _frames(3)
	ok(pl.pitch and pl._flame.has_meta("pitch_head") and _fire_parts(pl._flame) == Vector2i(1, 1), "a planted torch, lit: one flame card and one coal (%s)" % str(_fire_parts(pl._flame)))
	ok(_fire_parts(po._flame) == Vector2i.ZERO and po._flame.is_visible_in_tree(), "a planted torch out with burn left: the pitch head alone")
	ok(not pb._flame.is_visible_in_tree(), "a burnt-out planted torch: a bare stick, as built")
	# The shape: six flat sides, a flat top, the bands as steps; the coal too.
	var shapes: Array = [["in hand", vh], ["planted", pl._flame]]
	for h in bundle_heads:
		shapes.append(["in the bundle", h])
	var bad := ""
	for e in shapes:
		var why := _wrap_shape(e[1])
		if why != "":
			bad += "%s: %s; " % [e[0], why]
	ok(bad == "", "every wrap: six flat sides, a flat top (no dome), the %d bands as steps in its silhouette%s" % [PitchTorch.bands(), "" if bad == "" else " (" + bad + ")"])
	var cv: PackedVector3Array = ((vh.get_node("Coal") as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var coal_ok := true
	for q in cv:
		if Vector2(q.x, q.z).length() > 1e-5:
			var a := fposmod(atan2(q.x, q.z), TAU / PitchTorch.sides())
			coal_ok = coal_ok and (a < 1e-3 or a > TAU / PitchTorch.sides() - 1e-3)
	ok(coal_ok, "the coal: six-sided, the glowing top of the wrap")
	var dv: PackedVector3Array = ((vh.get_node("Wrap") as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
	var lowest := 0.0
	for q in dv:
		lowest = minf(lowest, q.y)
	var dr: Dictionary = PitchTorch.H.get("drips", {})
	ok(dv.size() > 0 and -lowest >= float((dr.get("length_m", [0.02, 0.07]) as Array)[0]) - 1e-4 and -lowest <= float((dr.get("length_m", [0.02, 0.07]) as Array)[1]) + 1e-4, "drips of pitch run down the stick below the wrap (the longest %.0f mm)" % (-lowest * 1000.0))
	# No shine on any head or stick.
	var shiny := ""
	var roots: Array = [t._view, pl, po, fires.bundle]
	for r in roots:
		for g in (r as Node).find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			var mat: Material = gi.material_override
			if mat == null and gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
				mat = (gi as MeshInstance3D).mesh.surface_get_material(0)
			var why := _shine(mat)
			if why != "":
				shiny += "%s %s; " % [gi.name, why]
	ok(shiny == "", "no shine on the heads or the sticks: no specular, roughness 1, no normal map%s" % ("" if shiny == "" else " (" + shiny + ")"))
	for x in [pl, po, pb]:
		(x as PlantedTorch).take()
	await _frames(2)


## The flame's lean, its light and its smoke (§EZ.2), on the floor of
## _snuff's own (the torch in hand).
func _lean(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var LN: Dictionary = PitchTorch.P.get("lean", {})
	var per_mps := float(LN.get("per_mps", 6.0))
	var max_deg := float(LN.get("max_deg", 50.0))
	var settle := float(LN.get("settle_s", 0.4))
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	t.light()
	await _frames(120)
	var drawn := PitchTorch.drawn_lean_deg(t._view_flame, p.up)
	ok(t.lit() and t.lean.deg() == 0.0 and drawn < 0.01, "standing still (0 m/s): the flame upright, lean 0 (drawn %.2f deg)" % drawn)
	# The light: the flame's flicker on top of the coal's breath (the light
	# over what the coal's breath alone gives it is the flame's share).
	var ks: Array[float] = []
	var sum := 0.0
	for i in 120:
		await physics_frame
		var coal := Torch.energy_now(t.item(), t._t, 1.0) * Torch.held_scale()
		ks.append(t._light.light_energy / maxf(coal, 1e-4))
		sum += ks[-1]
	var mean := sum / ks.size()
	ok(ks.max() - ks.min() > 0.06 and absf(mean - 1.0) < 0.05, "the light flickers with the flame (x%.2f to x%.2f over 2 s) on top of the coal's breath" % [ks.min(), ks.max()])
	ok(absf(t._light.omni_range - float(Torch.L.get("range_m", 14.0)) * Torch.held_scale()) < 1e-3, "the torch in hand still reaches held_scale further (%.1f m, §EB.3)" % t._light.omni_range)
	# The smoke: darker toward soot, never a neutral grey.
	var col: Node3D = t._view_flame.get_meta("smoke_col") if t._view_flame.has_meta("smoke_col") else null
	var sooty := col != null
	var worst := ""
	if col != null:
		var m: ShaderMaterial = col.get_meta("mat")
		var night_v: Vector3 = m.get_shader_parameter("colour_night")
		var night_def := PitchTorch.smoke_night(m)
		var pairs := [[Color(night_v.x, night_v.y, night_v.z), Color(night_def.x, night_def.y, night_def.z), "night"]]
		for key in ["colour_near", "colour_far", "colour_shade"]:
			pairs.append([m.get_shader_parameter(key), Color(str(Smoke.LOOK.get(key, "#8FA0C8"))).srgb_to_linear(), key])
		for pr in pairs:
			var c: Color = pr[0]
			var base: Color = pr[1]
			var grey := c.b - maxf(c.r, c.g) < 0.005
			if c.get_luminance() >= base.get_luminance() or grey:
				sooty = false
				worst += "%s #%s; " % [pr[2], c.to_html(false)]
	ok(sooty, "its smoke: darker toward soot than the hearth's, still blue, never a neutral grey%s" % ("" if worst == "" else " (" + worst + ")"))
	# Sprinting (well short of the sprint rule's gutter).
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(int(2.5 * 60.0))
	var v := Vector3(p.velocity.x, 0.0, p.velocity.z)
	var deg := t.lean.deg()
	var want := minf(v.length() * per_mps, max_deg)
	var fl := t._view_flame.get_node("Flame") as Node3D
	var top := fl.global_basis.y
	var back := Vector3(top.x, 0.0, top.z).dot(v) < 0.0
	drawn = PitchTorch.drawn_lean_deg(t._view_flame, p.up)
	var stretch := t.lean.stretch
	var height_k := fl.global_basis.y.length()
	Input.action_release("sprint")
	Input.action_release("move_forward")
	ok(t.lit() and deg > 1.0 and deg <= max_deg + 1e-3 and absf(deg - want) < 1.0 and absf(drawn - deg) < 0.5 and back, "sprinting (%.1f m/s): the flame leans back %.1f deg, within max_deg %.0f (drawn %.1f)" % [v.length(), deg, max_deg, drawn])
	ok(absf(stretch - float(LN.get("sprint_stretch", 1.3))) < 0.02 and absf(height_k - stretch) < 0.02, "and stretches to sprint_stretch (%.2f of its height)" % stretch)
	await _frames(int((settle * 3.0 + 0.6) * 60.0))
	ok(t.lit() and t.lean.deg() == 0.0 and absf(t.lean.stretch - 1.0) < 1e-3, "stopped, it settles upright within settle_s's three time constants (%.1f s)" % (settle * 3.0))
	# An ordinary airway's draft leans it toward the slot, and it holds.
	var aw := main.airways
	var slot: Dictionary = {}
	var si := -1
	for i in aw.mouths.size():
		if not bool(aw.mouths[i].strong):
			slot = aw.mouths[i]
			si = i
			break
	if not slot.is_empty():
		var mp: Vector3 = slot.pos
		var nrm: Vector3 = slot.normal
		var piece: Dictionary = main.lay.pieces[int((main.lay.airways as Array)[si].piece)]
		var face := -nrm
		var stand := mp + nrm * 1.0 - Basis(Vector3.UP, atan2(-face.x, -face.z)) * Vector3(0.3, 0.0, -0.4)
		stand.y = Delves.floor_of(piece, 0.0)
		p.spawn_flat(stand, atan2(-face.x, -face.z), 0.0)
		await _frames(150)
		var d := aw.draft_at(t.flame_position())
		# The slot is high in the wall: the flame tips with the draft's
		# sideways part (an upward draw only draws it up).
		var push: Vector3 = d.lean
		push.y = 0.0
		var to_slot := mp - t.flame_position()
		var tilt := t.lean.tilt
		ok(t.lit() and push.length() > 0.05 and tilt.length() > 0.2 and tilt.normalized().dot(Vector3(to_slot.x, 0.0, to_slot.z).normalized()) > 0.5 and absf(tilt.length() - minf(push.length() * per_mps, max_deg)) < 0.5, "an ordinary airway's draft leans the flame toward its slot (%.1f deg from %.2f m/s across), and it holds" % [tilt.length(), push.length()])
	# A strong mouth's gust whips it flat out, at max_deg, away from the
	# mouth (§EZ.5), and it holds; standing 2.5 m out on its line.
	var strong: Dictionary = {}
	var gi := -1
	for i in aw.mouths.size():
		if bool(aw.mouths[i].strong):
			strong = aw.mouths[i]
			gi = i
			break
	if not strong.is_empty():
		var gp: Vector3 = strong.pos
		var gn: Vector3 = strong.normal
		var gpiece: Dictionary = main.lay.pieces[int((main.lay.airways as Array)[gi].piece)]
		var gface := -gn
		var gstand := gp + gn * 2.5 - Basis(Vector3.UP, atan2(-gface.x, -gface.z)) * Vector3(0.3, 0.0, -0.4)
		gstand.y = Delves.floor_of(gpiece, 0.0)
		strong.t = 30.0
		p.spawn_flat(gstand, atan2(-gface.x, -gface.z), 0.0)
		await _frames(5)
		t.light()
		var warn_s := float(Airways.SN.get("warn_s", 1.5))
		var gust_s := float(Airways.A.get("gust_s", 2.2))
		strong.t = warn_s + 0.4
		var most := 0.0
		var drawn_most := 0.0
		var away := false
		var held := true
		for i in int((warn_s + 0.4 + gust_s + 0.5) * 60.0):
			await physics_frame
			held = held and t.lit()
			if t.snuff.gust and t.lean.deg() > most:
				most = t.lean.deg()
				drawn_most = PitchTorch.drawn_lean_deg(t._view_flame, p.up)
				away = t.lean.tilt.dot(Vector3(gn.x, 0.0, gn.z)) > 0.0
		strong.t = 30.0
		ok(held and absf(most - max_deg) < 0.5 and absf(drawn_most - most) < 0.5 and away, "a strong mouth's gust whips the flame flat out, %.1f deg (max_deg %.0f), away from the mouth (drawn %.1f), and it holds" % [most, max_deg, drawn_most])
	# Out by water, as _snuff left it, for _douse.
	t.put_out("doused")
	await _frames(2)


## The fitted-stone walls (design §EU; FittedStone, masonry.json).
func _masonry(main: CrawlerMain) -> void:
	var stones := int(main.tomb.get_meta("stones", 0))
	var faces := int(main.tomb.get_meta("faces", 0))
	ok(stones > 200 and faces > 20, "fitted stones on every seen wall face (%d stones on %d faces, %s for the %s)" % [stones, faces, FittedStone.preset_name(), main.lay.theme])
	# The partition is tight: the cells fill the wall, no gaps, no overlaps,
	# for both presets, after the relaxation.
	var rng := RandomNumberGenerator.new()
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	for preset in ["megalithic", "fitted_small"]:
		FittedStone.preset_override = preset
		for k in 6:
			rng.seed = 900 + k
			var l := rng.randf_range(2.0, 11.0)
			var h := rng.randf_range(2.5, 3.8)
			var area := 0.0
			for c in FittedStone.cells(l, h, rng):
				area += FittedStone._area(c[1])
			worst = maxf(worst, absf(area - l * h) / (l * h))
	FittedStone.preset_override = ""
	ok(worst < 0.002, "the stones' cells fill each wall exactly in both presets: shared edges, no gaps (worst %.4f of the wall; %d ms)" % [worst, Time.get_ticks_msec() - t0])
	# Every face its own seed: the two faces of one wall differ.
	var ra := RandomNumberGenerator.new()
	var rb := RandomNumberGenerator.new()
	ra.seed = hash([1, -1.0])
	rb.seed = hash([1, 1.0])
	var ca := FittedStone.cells(6.0, 3.0, ra)
	var cb := FittedStone.cells(6.0, 3.0, rb)
	ok((ca[0][0] as Vector2).distance_to(cb[0][0]) > 0.01, "every wall face its own stones: the two sides of a wall don't mirror")
	# A typical room's triangles (the tomb mesh inside each room's walls).
	var per_room: Array = []
	var arrs: Array = []
	for mi in main.tomb.get_children():
		if mi is MeshInstance3D:
			arrs.append((mi as MeshInstance3D).mesh.surface_get_arrays(0))
	for pc in main.lay.pieces:
		if str(pc.kind) != "room":
			continue
		var n := 0
		for arr in arrs:
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in range(0, vv.size(), 3):
				var c3 := (vv[i] + vv[i + 1] + vv[i + 2]) / 3.0
				var aa := Delves.along_across(pc, Vector2(c3.x, c3.z))
				if aa.x > -0.7 and aa.x < float(pc.len) + 0.7 and absf(aa.y) < float(pc.half) + 0.7 and c3.y > float(pc.y0) - 0.5 and c3.y < float(pc.y0) + float(pc.h) + 0.5:
					n += 1
		per_room.append(n)
	per_room.sort()
	if not per_room.is_empty():
		print("  triangles in a room: median %d (fewest %d, most %d, %d rooms); the whole tomb %d" % [per_room[per_room.size() / 2], per_room[0], per_room[-1], per_room.size(), int(main.tomb.get_meta("triangles", 0))])
	# The climate: the theme's world's biome through vines.json climate.
	var cl_tomb := FittedStone.climate_of("tomb")
	var cl_snow := FittedStone.climate_of("snow_ruins")
	print("  climate: tomb %s (%.2f, %.0f C), snow_ruins %s (%.2f, %.0f C)" % [cl_tomb.from, cl_tomb.moisture, cl_tomb.temp_c, cl_snow.from, cl_snow.moisture, cl_snow.temp_c])
	ok(str(cl_snow.from) == "tundra" and FittedStone.moss_of(Vector2(cl_snow.moisture, cl_snow.temp_c)) == 0.0, "the snow ruins take the tundra world's climate: too cold for moss")
	# The moisture differs from place to place, and the overgrowth with it.
	var lo := 1.0
	var hi := 0.0
	for pc in main.lay.pieces:
		var c: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5
		var cl := FittedStone.climate_at(str(main.lay.theme), int(main.lay.seed), Vector3(c.x, float(pc.y0), c.y))
		var mk := FittedStone.moss_of(cl)
		lo = minf(lo, mk)
		hi = maxf(hi, mk)
	print("  the tomb's moss runs %.2f to %.2f" % [lo, hi])
	ok(hi - lo > 0.15, "the moss differs from place to place (%.2f to %.2f)" % [lo, hi])
	ok(FittedStone.moss_of(Vector2(0.2, 14.0)) == 0.0 and FittedStone.moss_of(Vector2(0.95, 14.0)) > 0.9, "no moss where it's dry, full moss where it's wet (vines.json climate)")
	# One wall dressed in a desert and in a damp place: dust and bare stone,
	# then vines.
	var out := {}
	for wi in 2:
		var cl2: Vector2 = [Vector2(0.1, 26.0), Vector2(0.9, 14.0)][wi]
		var tb := TombBuild.new()
		var r2 := RandomNumberGenerator.new()
		r2.seed = 77
		FittedStone.face(tb, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, 8.0, -0.1, 3.0, 0.0, cl2, r2)
		var leaf := 0
		for m in tb._m:
			if int(round(m.x)) == RuinBuilder.LEAF_M:
				leaf += 1
		out[wi] = [tb._boulder_anchors.size(), leaf / 3]
	ok(int(out[0][0]) > 0 and int(out[0][1]) == 0, "a desert wall: drifted sand at its foot and corners, no vines (%d drifts)" % out[0][0])
	ok(int(out[1][0]) == 0 and int(out[1][1]) > 0, "a damp wall: vines from its top and cracks, no sand (%d leaf triangles)" % out[1][1])


## One firelight (design §EX.6): every fire light in the built tomb (the
## hearth, every holder, the torch in hand) is the hearth's amber, and
## torch.json's colour is look.json's.
func _firelight(main: CrawlerMain) -> void:
	var want := Torch.fire_color()
	var lights: Array = []
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		# (The half-dark's light at your eye is no fire: _half_dark.)
		if n is OmniLight3D and not n.has_meta("half_dark"):
			lights.append(n)
		stack.append_array(n.get_children())
	var odd := 0
	for l in lights:
		if not (l as OmniLight3D).light_color.is_equal_approx(want):
			odd += 1
			print("  light %s: #%s" % [(l as Node).get_path(), (l as OmniLight3D).light_color.to_html(false)])
	ok(lights.size() >= (main.lay.holders as Array).size() + 2 and odd == 0, "one firelight: all %d fire lights in the tomb (hearth, holders, the torch) are #%s" % [lights.size(), want.to_html(false)])
	ok(Color(str(Torch.L.get("color", ""))).is_equal_approx(want), "torch.json light.color is look.json fire.light.color (#%s)" % want.to_html(false))


## The room torches in the built tomb (design §EX.4): one hearth among its
## fires, in the hearth room, every other fire a sconce; and every room
## sconce in your reach from somewhere your body fits (_swing_spot).
func _torch_room(main: CrawlerMain) -> void:
	var lay := main.lay
	var hearths: Array = []
	for f in main.get_tree().get_nodes_in_group(Campfire.GROUP):
		if not (f as Node3D).has_meta("fire_holder") or str(f.get_meta("fire_holder")) != "sconce":
			hearths.append(f)
	var hearth_ok: bool = hearths.size() == 1 and hearths[0] == main.fires.hearth and TombKit.piece_at(lay, main.fires.hearth.global_position) == 0
	ok(hearth_ok, "in the scene: one hearth among the %d fires (the hearth room's), every other fire a wall sconce" % main.get_tree().get_nodes_in_group(Campfire.GROUP).size())
	var n := 0
	var blocked := 0
	var far := 0.0
	for i in main.fires.holders.size():
		if not bool((lay.holders[i] as Dictionary).get("room", false)):
			continue
		n += 1
		var h: Node3D = main.fires.holders[i]
		var d := _swing_spot(main, h)
		if d < 0.0:
			blocked += 1
			var pc: Dictionary = lay.pieces[int(h.get_meta("piece"))]
			print("  room sconce %d in room %d (%s): nowhere to stand and swing at it" % [i, pc.id, pc.room_kind])
		far = maxf(far, d)
	ok(n > 0 and blocked == 0, "every room sconce in your reach from somewhere you can stand (%d of %d; the farthest you need stand %.2f m out from its wall)" % [n - blocked, n, far])


## Where you could stand to swing at wall sconce `h`: a grid before it
## (0.5 to 2.5 m out from its wall, up to 1.8 m either side) inside its
## room, nearest first, where your body (the crawler's capsule) fits and
## the swing's point (Torch.swing_point: 0.9 m up, 0.4 m on toward it) is
## within torch.json swing.reach_m of it and nearer it than any other
## fire. The nearest such spot's distance from the wall (m), or -1.
func _swing_spot(main: CrawlerMain, h: Node3D) -> float:
	var pc: Dictionary = main.lay.pieces[int(h.get_meta("piece"))]
	var cup := h.global_position
	var nrm := h.global_basis.z
	nrm.y = 0.0
	nrm = nrm.normalized()
	var tan := nrm.cross(Vector3.UP)
	var floor_y := Delves.floor_of(pc, Delves.along_across(pc, Vector2(cup.x, cup.z)).x)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = PlanetPlayer.STAND_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.exclude = [main.player.get_rid()]
	var space := get_root().get_world_3d().direct_space_state
	var fires := main.get_tree().get_nodes_in_group(Campfire.GROUP)
	var reach := Torch.reach_m()
	for oi in 9:
		var o := 0.2 + 0.25 * oi
		for si in 13:
			var sv := 0.3 * ceili(si * 0.5) * (1.0 if si % 2 == 1 else -1.0)
			var at := Vector3(cup.x, floor_y, cup.z) + nrm * o + tan * sv
			var aa := Delves.along_across(pc, Vector2(at.x, at.z))
			if aa.x < 0.35 or aa.x > float(pc.len) - 0.35 or absf(aa.y) > float(pc.half) - 0.35:
				continue
			var to := Vector3(cup.x - at.x, 0.0, cup.z - at.z).normalized()
			var swing := at + Vector3(0.0, 0.9, 0.0) + to * 0.4
			var dd := swing.distance_to(cup)
			if dd > reach:
				continue
			var nearest := true
			for f in fires:
				if f != h and (f as Node3D).global_position.distance_to(swing) < dd:
					nearest = false
			if not nearest:
				continue
			q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, cap.height * 0.5 + 0.12, 0.0))
			if space.intersect_shape(q, 1).is_empty():
				# From the wall's face: the cup stands in its niche (§EX.3).
				return o - TombBuild.sconce_inset()
	return -1.0


## The room sconces' lights as built, after relighting (CrawlerFires; the
## lit level in _room_torches counts them this way): each lit and shining,
## its range, falloff and strength (room_torches.light_scale) and where it
## hangs as assumed there.
func _torch_lights(main: CrawlerMain) -> void:
	for i in 30:
		await process_frame
	var lay := main.lay
	var n := 0
	var odd := 0
	var e_sum := 0.0
	var want_e := 0.0
	for i in main.fires.holders.size():
		var hd: Dictionary = lay.holders[i]
		if not bool(hd.get("room", false)):
			continue
		n += 1
		var h: Node3D = main.fires.holders[i]
		var l := h.get_node_or_null("Light") as OmniLight3D
		var m := _sconce_light(hd)
		var base: Vector3 = h.global_transform * Vector3(0.0, float(h.get_meta("light_y", 1.0)), float(h.get_meta("light_z", 0.0)))
		var k := float(CrawlerFires.HOLD.get("sconce_scale", 0.38)) * 1.4 * float(TombKit.RT.get("light_scale", 1.0))
		if l == null or not FireStore.is_lit(h) or not l.visible or absf(l.omni_range - float(m[2])) > 0.01 or absf(l.omni_attenuation - float(m[3])) > 0.001 or absf(float(h.get_meta("energy_k", 0.0)) - k) > 0.001 or base.distance_to(m[0]) > 0.01:
			odd += 1
			print("  room sconce %d: lit %s, light %s, range %.2f, decay %.2f, energy_k %.3f, at %s against %s" % [i, FireStore.is_lit(h), l != null and l.visible, l.omni_range if l else 0.0, l.omni_attenuation if l else 0.0, float(h.get_meta("energy_k", 0.0)), str(base), str(m[0])])
		elif l:
			e_sum += l.light_energy
			want_e += float(m[1])
	ok(n > 0 and odd == 0, "every relit room sconce shines as the lit level counts it (%d: range, falloff, place; light_scale %.2f)" % [n, float(TombKit.RT.get("light_scale", 1.0))])
	# Its strength flickers about the steady one the lit level takes.
	ok(want_e > 0.0 and absf(e_sum / want_e - 1.0) < 0.35, "the room sconces' light flickers about the strength the lit level takes (now %.2f of it)" % (e_sum / maxf(want_e, 1e-6)))


## Every built-in fire's own vent (design §EV; TombKit, Vents, smoke.json
## vents).
func _vents(main: CrawlerMain) -> void:
	var lay := main.lay
	var vents: Array = lay.vents
	var V: Dictionary = TombKit.vents_table()
	var surface := float(V.get("surface_y_m", 9.0))
	ok(vents.size() == (lay.holders as Array).size() + 1, "every permanent fire has a vent: the hearth and %d holders (%d vents)" % [(lay.holders as Array).size(), vents.size()])
	var reach := true
	var open := true
	var drafts := true
	for v in vents:
		var legs: Array = v.legs
		if absf(((legs[-1] as Array)[1] as Vector3).y - surface) > 0.01:
			reach = false
		# The way up the flue is open (straight flues: a ray up the middle).
		if legs.size() == 1:
			var m: Vector3 = v.mouth
			var hit := _ray(m - Vector3(0.0, 0.3, 0.0), Vector3(m.x, surface - 0.1, m.z), [main.player.get_rid()])
			if not hit.is_empty():
				open = false
				print("  vent over %s at %s: blocked at %s" % [v.kind, str(m), str(hit.position)])
		var fire: Node3D = main.fires.hearth if int(v.fire_index) < 0 else main.fires.holders[int(v.fire_index)]
		if not fire.has_meta("draft"):
			drafts = false
	ok(reach, "every flue reaches the surface (%.1f m)" % surface)
	ok(open, "every straight flue is open from its mouth to the sky")
	ok(drafts, "every vented fire feels the draft")
	# Deeper: narrower, and a shaft as deep fainter (the hearth's is the
	# tomb's one shaft since §EX.4, so the sconces' flues show the depth).
	var shallow: Dictionary = {}
	var deep: Dictionary = {}
	for v in vents:
		if str(v.type) != "flue":
			continue
		if shallow.is_empty() or float(v.depth) < float(shallow.depth):
			shallow = v
		if deep.is_empty() or float(v.depth) > float(deep.depth):
			deep = v
	if not deep.is_empty() and float(deep.depth) > float(shallow.depth) + 0.5:
		var s_sh := TombKit.daylight_share(float(shallow.depth))
		var s_dp := TombKit.daylight_share(float(deep.depth))
		ok(float(deep.d) < float(shallow.d) and s_dp < s_sh, "a deeper fire's vent is narrower, and a shaft as deep would let less daylight down (%.1f m: %.2f m wide, %.2f; %.1f m: %.2f m, %.2f)" % [shallow.depth, shallow.d, s_sh, deep.depth, deep.d, s_dp])
	# A shaft for a big fire, a narrow flue for a small one; only shafts
	# let daylight down (design §EV.1-2).
	var sized := true
	var n_shaft := 0
	for v in vents:
		var wr: Array = (V.get(str(v.type), {}) as Dictionary).get("width_m", [0.0, 9.0])
		if str(v.type) != TombKit.vent_type(str(v.kind)) or float(v.d) < float(wr[0]) - 0.001 or float(v.d) > float(wr[1]) + 0.001:
			sized = false
			print("  vent over %s: %s %.2f m wide" % [v.kind, v.type, v.d])
		if str(v.type) == "shaft" and bool(v.sky):
			n_shaft += 1
		if str(v.type) == "flue" and bool(v.sky):
			sized = false
	ok(sized, "every vent is sized by its fire: shafts %s m, flues %s m" % [str((V.get("shaft", {}) as Dictionary).get("width_m")), str((V.get("flue", {}) as Dictionary).get("width_m"))])
	ok(main.vents.shafts.size() == n_shaft and n_shaft >= 1, "daylight comes down the shafts only (%d of %d vents), never a flue" % [n_shaft, vents.size()])
	var fade: Array = (V.get("daylight", {}) as Dictionary).get("fade_depth_m", [3.0, 25.0])
	ok(TombKit.daylight_share(float(fade[0])) == 1.0 and TombKit.daylight_share(float(fade[1]) + 0.5) == 0.0, "full daylight down a shaft %.0f m long, none past %.0f m (daylight.fade_depth_m)" % [fade[0], fade[1]])
	# Never a way in or out (passable false): every mouth out of reach
	# overhead; and each keeps what it becomes on the surface (§EV.4).
	var reachable := 0
	var outlets := true
	for v in vents:
		var pc: Dictionary = lay.pieces[int(v.piece)]
		var m: Vector3 = v.mouth
		if m.y - Delves.floor_of(pc, Delves.along_across(pc, Vector2(m.x, m.z)).x) < 2.4:
			reachable += 1
		if str(v.get("outlet", "")) == "":
			outlets = false
	ok(reachable == 0, "no vent is a way out: every mouth overhead, out of reach (%d low)" % reachable)
	ok(outlets, "every vent knows its outlet for the surface to come (a shaft's stack, a flue's slot; §EV.4 with §EW)")
	# Day and night on the world's clock.
	ok(Vents.daylight_at(13.5) > 0.99 and Vents.daylight_at(13.0) < 0.01, "the shafts follow the clock: full day at noon, night at midnight")
	var w := main.world
	var keep_days: float = w.days
	w.days = 13.5
	# Two frames: the vents read the clock in their own frame's _process.
	await process_frame
	await process_frame
	var e_day := 0.0
	for sh in main.vents.shafts:
		e_day += (sh.light as SpotLight3D).light_energy
	var col_day: Color = (main.vents.shafts[0].light as SpotLight3D).light_color
	w.days = 13.0
	await process_frame
	await process_frame
	var e_night := 0.0
	for sh in main.vents.shafts:
		e_night += (sh.light as SpotLight3D).light_energy
	var col_night: Color = (main.vents.shafts[0].light as SpotLight3D).light_color
	w.days = keep_days
	ok(e_day > e_night * 3.0 and col_day.b > col_day.r and col_night.b > col_night.r, "the shafts: cool blue and strong by day (%.1f), dim moonlit blue at night (%.1f)" % [e_day, e_night])
	# Soot: the stone round every flue's mouth darkened (TombBuild._soot).
	var stained := 0
	var tb_arrays: Array = []
	for mi in main.tomb.get_children():
		if mi is MeshInstance3D:
			tb_arrays.append((mi as MeshInstance3D).mesh.surface_get_arrays(0))
	for v in vents:
		var m: Vector3 = v.mouth
		var darkest := 1.0
		for arr in tb_arrays:
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var cc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			for i in range(0, vv.size(), 1):
				var p: Vector3 = vv[i]
				if absf(p.y - m.y) < 0.7 and Vector2(p.x - m.x, p.z - m.z).length() < float(v.d) * 0.5 + 0.6:
					darkest = minf(darkest, cc[i].get_luminance())
		if darkest < 0.15:
			stained += 1
		else:
			print("  vent %s d %.2f at %s: darkest %.3f" % [v.kind, float(v.d), str(m), darkest])
	ok(stained == vents.size(), "soot round every flue's mouth (%d of %d)" % [stained, vents.size()])


## The hearth's pit and its shaft (Mike, 7 Oct: "where the main hearths
## sit there should be a fire pit made into the ground"; "the exit draft
## vent should be situated more directly above the fire"; masonry.json
## styles hearth sunk_pit, smoke.json vents.shaft.over_fire): the fire
## down in its pit, its light where it was over the room's floor; the
## pit's floor under it and the room's floor round it where they should be;
## the guard round its lip; the flags cut round it; the shaft straight over
## the fire, the flame standing straight in its draft.
func _hearth_pit(main: CrawlerMain) -> void:
	var pt := TombBuild.pit()
	ok(not pt.is_empty(), "the tomb's style sinks its hearth in a pit (masonry.json styles hearth sunk_pit)")
	if pt.is_empty():
		return
	var lay := main.lay
	var hp: Vector3 = lay.hearth
	var depth := float(pt.depth)
	var a := float(pt.r)
	var outer := a + float(pt.kerb_w)
	var fire := main.fires.hearth
	ok(absf(fire.global_position.y - (hp.y - depth)) < 0.01 and Vector2(fire.global_position.x - hp.x, fire.global_position.z - hp.z).length() < 0.01, "the hearth's fire sits down in its pit, %.2f m under the room's floor (at y %.2f)" % [depth, fire.global_position.y])
	var lt := fire.get_node_or_null("Light") as Node3D
	ok(lt != null and absf(lt.global_position.y - (hp.y + 1.0)) < 0.15, "its light hangs where it did, about 1 m over the room's floor (y %.2f), so the room is lit as before" % (lt.global_position.y if lt else -99.0))
	var ex: Array[RID] = [main.player.get_rid()]
	# (Not the fire's own logs and its hidden ring, which lie in the pit.)
	for b in fire.find_children("*", "CollisionObject3D", true, false):
		ex.append((b as CollisionObject3D).get_rid())
	# The pit's floor at its foot, the room's floor round it.
	var hit_in := _ray(hp + Vector3(0.12, 1.5, 0.08), hp + Vector3(0.12, -2.0, 0.08), ex)
	var y_in: float = (hit_in.position as Vector3).y if not hit_in.is_empty() else 99.0
	var out_p := hp + Vector3(outer + 0.35, 0.0, 0.0)
	var hit_out := _ray(out_p + Vector3(0.0, 1.5, 0.0), out_p + Vector3(0.0, -2.0, 0.0), ex)
	var y_out: float = (hit_out.position as Vector3).y if not hit_out.is_empty() else 99.0
	ok(absf(y_in - (hp.y - depth)) < 0.03 and absf(y_out - hp.y) < 0.03, "in the pit you'd stand on its floor %.2f m down (%.2f), past its kerb on the room's floor (%.2f)" % [depth, y_in, y_out])
	# The guard: you stand at its lip, never in it; it stays under every
	# eye (yours crouched at 0.78 m).
	var guard_ok := true
	var guard_far := 0.0
	for k in 16:
		var dir := Vector3(cos(TAU * k / 16.0), 0.0, sin(TAU * k / 16.0))
		var g := _ray(hp + dir * 1.35 + Vector3(0.0, 0.25, 0.0), hp + Vector3(0.0, 0.25, 0.0), ex)
		if g.is_empty() or Vector2((g.position as Vector3).x - hp.x, (g.position as Vector3).z - hp.z).length() > outer / cos(PI / int(pt.sides)) + 0.02:
			guard_ok = false
			print("  toward the pit at 0.25 m: %s" % ("nothing" if g.is_empty() else "met %s at %s" % [str(g.get("collider")), str(g.position)]))
		else:
			guard_far = maxf(guard_far, Vector2((g.position as Vector3).x - hp.x, (g.position as Vector3).z - hp.z).length())
		var over := _ray(hp + dir * 2.0 + Vector3(0.0, 0.7, 0.0), hp - dir * 2.0 + Vector3(0.0, 0.7, 0.0), ex)
		if not over.is_empty() and Vector2((over.position as Vector3).x - hp.x, (over.position as Vector3).z - hp.z).length() < outer + 0.3:
			guard_ok = false
			print("  across the pit at 0.7 m: met %s at %s" % [str(over.get("collider")), str(over.position)])
	ok(guard_ok and float(pt.guard) < 0.78, "a guard round its lip keeps you out of the fire (met %.2f m from its middle all round) and passes under every eye (%.2f m up; a line across it at 0.7 m meets nothing)" % [guard_far, float(pt.guard)])
	# The flags cut round it: no stone at the floor's height inside its lip.
	var inside := 0
	var lip := a - TombBuild.PIT_LIP_M - 0.03
	for mi in main.tomb.get_children():
		if not mi is MeshInstance3D:
			continue
		var vv: PackedVector3Array = (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for q in vv:
			if q.y > hp.y - 0.1 and q.y < hp.y + 0.2 and Vector2(q.x - hp.x, q.z - hp.z).length() < lip:
				inside += 1
	ok(inside == 0, "the floor's flags are cut round the pit: no stone at the floor's height inside its lip (%d vertices)" % inside)
	# The shaft straight over the fire, its daylight falling on it, the
	# flame standing straight in its draft.
	var shaft: Dictionary = {}
	for v in lay.vents:
		if int(v.fire_index) == -1:
			shaft = v
	var m: Vector3 = shaft.get("mouth", Vector3.INF)
	var off := Vector2(m.x - hp.x, m.z - hp.z).length()
	ok(str(shaft.get("type", "")) == "shaft" and off < 0.05, "the hearth's shaft stands straight over its fire (its mouth %.2f m off the fire's middle, smoke.json vents.shaft.over_fire)" % off)
	var lean: Vector3 = fire.get_meta("draft", Vector3.ONE)
	ok(lean.length() < 1e-4 and fire.has_meta("draft_flicker"), "its draft draws the hearth's flame straight up: no lean, only the flicker")
	var lit_fire := false
	for sh in main.vents.shafts:
		var sp := sh.light as SpotLight3D
		if Vector2(sp.global_position.x - hp.x, sp.global_position.z - hp.z).length() < 0.05:
			lit_fire = true
	ok(lit_fire, "the shaft's column of daylight falls on the fire")


## The wall torches' flue slots (design §EV.1: "a narrow flue slot in the
## wall above it"; Mike, 7 Oct: "please ensure torches in the indents on the
## wall still have exit vents above them"; TombBuild._flue_slot_op): every
## sconce in its niche has a slot cut up the wall from just over its niche
## to the wall face's top, as wide as its flue, straight under its vent's
## mouth in the ceiling against the wall, that vent open to the sky
## (_vents).
func _flue_slots(main: CrawlerMain) -> void:
	var lay := main.lay
	var slots: Array = main.tomb.get_meta("flue_slots", [])
	var sc := TombBuild.sconce_niche()
	var with_slot := 0
	var under_mouth := 0
	var worst := ""
	for i in (lay.holders as Array).size():
		var hd: Dictionary = lay.holders[i]
		if str(hd.kind) != "sconce":
			continue
		var pos: Vector3 = hd.pos
		var nrm: Vector3 = hd.normal
		var niche_top := pos.y - float((sc.cup as Vector3).y) + float(sc.h)
		var pc: Dictionary = lay.pieces[int(hd.piece)]
		var ceil_y := Delves.floor_of(pc, Delves.along_across(pc, Vector2(pos.x, pos.z)).x) + float(pc.h)
		var found: Dictionary = {}
		for sl in slots:
			var b: Vector3 = sl.bottom
			if Vector2(b.x - pos.x, b.z - pos.z).length() < 0.05 and b.y > niche_top - 0.01 and b.y < niche_top + 0.12:
				found = sl
				break
		if found.is_empty() or (found.top as Vector3).y < ceil_y - 0.45:
			worst = "sconce %d at %s: %s" % [i, str(pos), "no slot" if found.is_empty() else "its slot stops at %.2f, the ceiling at %.2f" % [(found.top as Vector3).y, ceil_y]]
			continue
		with_slot += 1
		# Its vent's mouth in the ceiling, against the wall over it.
		for v in lay.vents:
			if int(v.fire_index) != i:
				continue
			var mo: Vector3 = v.mouth
			var rel := Vector3(mo.x - pos.x, 0.0, mo.z - pos.z)
			var along := rel - nrm * rel.dot(nrm)
			if along.length() < 0.05 and rel.dot(nrm) - float(v.d) * 0.5 < 0.15 and absf(float(found.w) - clampf(float(v.d), 0.12, float(sc.w) * float(sc.top) - 0.06)) < 0.01:
				under_mouth += 1
			elif worst == "":
				worst = "sconce %d: its mouth %.2f m along and %.2f m out from its slot" % [i, along.length(), rel.dot(nrm)]
	var n := 0
	for hd in lay.holders:
		if str(hd.kind) == "sconce":
			n += 1
	if worst != "":
		print("  " + worst)
	ok(with_slot == n and n > 0, "every wall torch has its flue slot cut up the wall from just over its niche to the ceiling (%d of %d)" % [with_slot, n])
	ok(under_mouth == n, "each slot is its flue's width, straight under its vent's mouth in the ceiling against the wall (%d of %d)" % [under_mouth, n])


## Where the torch in hand's flame would be if you stood at `stand` facing
## `target` (the light sits at (0.3, 1.25, -0.4) in your frame).
func _flame_from(stand: Vector3, target: Vector3) -> Vector3:
	var flat := Vector3(target.x - stand.x, 0.0, target.z - stand.z)
	return stand + Basis(Vector3.UP, atan2(-flat.x, -flat.z)) * Vector3(0.3, 1.25, -0.4)


## A spot on the floor `out_m` in front of `pos` on its wall (normal `n`)
## from which the torch's light would reach it with nothing between; Vector3.INF
## if there's none (not in a corridor or room, or something in the way).
func _stand_before(main: CrawlerMain, pos: Vector3, n: Vector3, out_m: float) -> Vector3:
	var at := pos + n * out_m
	var pid := TombKit.piece_at(main.lay, at)
	if pid < 0 or str(main.lay.pieces[pid].kind) not in ["corridor", "room"] or str(main.lay.pieces[pid].get("room_kind", "")) == "hearth":
		return Vector3.INF
	var pc: Dictionary = main.lay.pieces[pid]
	at.y = Delves.floor_of(pc, Delves.along_across(pc, Vector2(at.x, at.z)).x)
	var q := PhysicsRayQueryParameters3D.create(_flame_from(at, pos), pos + n * 0.12)
	q.collision_mask = PropCollision.WORLD_LAYER
	q.exclude = [main.player.get_rid()]
	if not get_root().get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return Vector3.INF
	return at


## The torch out of your hand and out of your pack again.
func _drop_torches(p: CrawlerPlayer) -> void:
	p.torch.put_out("stowed")
	for i in p.inventory.carried.size():
		var it = p.inventory.carried[i]
		if it is Dictionary and str(it.get("kind", "")) == "torch":
			p.inventory.take(i)
	p.weapon = "hands"


## Atmosphere, never a puzzle (design §FG): the glow-moss (GlowMoss), the
## beetles and scarabs (WallLife) and the world's clock in the crawler (the
## shafts' daylight, Vents). Run before the holders are relit (only the
## hearth burns); the torch is handed over and taken back again.
func _ambience(main: CrawlerMain) -> void:
	var lay := main.lay
	var p := main.player
	var t := p.torch
	var gm := main.glow_moss
	var G: Dictionary = GlowMoss.G
	var rest := GlowMoss.rest_energy()
	var dim_to := float(G.get("dim_to", 0.1))
	var returns_s := float(G.get("returns_s", 6.0))
	var w: Array = lay.wake
	# The snake held still (queue 49): it would come for the torch in the
	# dark while this stands about there.
	var boss: Variant = main.get("boss")
	var keep_auto := true
	if boss is Boss:
		keep_auto = (boss as Boss).auto
		(boss as Boss).auto = false
	# Where it grows: damp stone, never dry.
	var off := 0
	var misplaced := 0
	for pp in gm.patches:
		var pos: Vector3 = pp.pos
		var cl := FittedStone.climate_at(str(lay.theme), int(lay.seed), pos)
		if FittedStone.dry_of(cl) > 0.0 or FittedStone.moss_of(cl) <= 0.0 or not GlowMoss.damp_enough(lay, pos):
			off += 1
		var pid := TombKit.piece_at(lay, pos + (pp.n as Vector3) * 0.5)
		if pid < 0 or str(lay.pieces[pid].kind) == "stair" or str(lay.pieces[pid].get("room_kind", "")) == "hearth":
			misplaced += 1
		for fp in GlowMoss.fire_spots(lay):
			if (fp as Vector3).distance_to(pos) < float(G.get("clear_of_fire_m", 1.5)) - 0.01:
				misplaced += 1
	ok(gm.patches.size() >= 3, "glow-moss grows on this tomb's damp stone (%d patches)" % gm.patches.size())
	ok(off == 0, "no glow-moss patch sits on dry stone: every one damp (damp_min %.2f), mossy, not dry (%d off)" % [float(G.get("damp_min", 0.62)), off])
	ok(misplaced == 0, "none in the hearth room or on a stair, none within clear_of_fire_m of a fire (%d)" % misplaced)
	# A dry tomb (a desert's climate) grows none; a wet one grows more.
	var th := str(lay.theme)
	var keep_cl: Variant = FittedStone._climates.get(th)
	FittedStone._climates[th] = {"moisture": 0.3, "temp_c": 24.0, "from": "check"}
	var dry_n := GlowMoss.place(lay, main.walls).size()
	FittedStone._climates[th] = {"moisture": 0.8, "temp_c": 14.0, "from": "check"}
	var wet_n := GlowMoss.place(lay, main.walls).size()
	if keep_cl == null:
		FittedStone._climates.erase(th)
	else:
		FittedStone._climates[th] = keep_cl
	ok(dry_n == 0 and wet_n > gm.patches.size(), "a dry tomb grows no glow-moss and a wet one more (dry %d, as built %d, wet %d)" % [dry_n, gm.patches.size(), wet_n])
	# Nothing the game's rules read knows it is there.
	var seen := 0
	for pp in gm.patches:
		var eye: Vector3 = (pp.pos as Vector3) + (pp.n as Vector3) * 0.3
		if Torch.light_at(eye) > 0.0 or Campfire.lit_near(self, eye, 0.6) or main.fires.lit_on(pp.pos, pp.n, 0.25):
			seen += 1
	ok(gm.find_children("*", "Light3D", true, false).is_empty() and seen == 0, "the glow-moss is no light node and nothing the rules read (the torch's light, the fires) sees it")
	# Dims at a flame: a torch in hand a metre off its wall.
	var target: Dictionary = {}
	var stand := Vector3.INF
	for pp in gm.patches:
		# Far from where you're sent after (the wake spot).
		if (pp.pos as Vector3).distance_to(w[0]) < 6.0:
			continue
		var at := _stand_before(main, pp.pos, pp.n, 1.1)
		if at != Vector3.INF:
			target = pp
			stand = at
			break
	ok(not target.is_empty(), "a glow-moss patch with open floor before it")
	if not target.is_empty():
		_place_facing(p, stand, target.pos)
		await _frames(3)
		var i_t := gm.patches.find(target)
		ok(absf(gm.energy_of(target) - rest) < 1e-5, "unlit, it glows at its rest (energy %.3f, %s)" % [gm.energy_of(target), str(G.get("color", ""))])
		if not p.inventory.has_kind("torch"):
			p.inventory.add(Inventory.make("torch"))
		p.weapon = "torch"
		t.light()
		await _frames(int((float(G.get("dims_s", 0.6)) + 0.4) * 60.0))
		var e_near := gm.energy_of(target)
		var drawn := gm._img.get_pixel(i_t, 1).a
		print("  the torch's flame %.2f m from the patch" % t.flame_position().distance_to(target.pos))
		ok(absf(e_near - dim_to * rest) < 1e-4 and absf(drawn - e_near) < 1e-4, "a torch in hand a metre off: the glow-moss falls to dim_to of its rest (%.4f = %.2f x %.3f; the stone draws %.4f)" % [e_near, dim_to, rest, drawn])
		# The torch goes (back to the hearth room, still lit).
		p.spawn_flat(w[0], float(w[1]), -0.32)
		await _frames(int(returns_s * 0.5 * 60.0))
		var e_half := gm.energy_of(target)
		await _frames(int(returns_s * 0.5 * 60.0) + 2)
		var e_back := gm.energy_of(target)
		ok(e_half > e_near and e_half < rest * 0.8 and absf(e_back - rest) < 1e-4, "once the torch has gone it creeps back: %.4f halfway through returns_s, at rest again (%.4f) %.0f s after" % [e_half, e_back, returns_s])
	_drop_torches(p)
	# The beetles and scarabs: where they live.
	var wl := main.wall_life
	var fire_at := GlowMoss.fire_spots(lay)
	var bad := 0
	for b in wl.bugs:
		var f: Dictionary = main.walls[int(b.face)]
		# On a wall it may live on, on the stretch seen from its own piece.
		if WallLife.face_weight(lay, f, fire_at) <= 0.0 or TombKit.piece_at(lay, wl.world_pos(b) + (f.n as Vector3) * 0.3) != TombKit.piece_at(lay, f.probe):
			bad += 1
	var sum_w := 0.0
	var sum_l := 0.0
	var wd := 0.0
	var ld := 0.0
	var wf := 0.0
	var lf := 0.0
	for f in main.walls:
		var wgt := WallLife.face_weight(lay, f, fire_at)
		if wgt <= 0.0:
			continue
		var mid: Vector3 = (f.o as Vector3) + (f.u as Vector3) * float(f.length) * 0.5 + Vector3.UP * (float(f.floor_y) + 0.8)
		var near := INF
		for fp in fire_at:
			near = minf(near, (fp as Vector3).distance_to(mid))
		var damp := GlowMoss.dampness(lay, mid)
		sum_w += wgt
		wd += wgt * damp
		wf += wgt * near
		sum_l += float(f.length)
		ld += float(f.length) * damp
		lf += float(f.length) * near
	ok(wl.bugs.size() >= 6 and bad == 0, "%d beetles and scarabs on the walls where they are seen, none in the hearth room or on a stair (%d off)" % [wl.bugs.size(), bad])
	if sum_w > 0.0:
		ok(wd / sum_w > ld / sum_l and wf / sum_w > lf / sum_l, "more on damp, dark walls: their walls' dampness %.3f against %.3f for any wall, %.1f m from a fire against %.1f" % [wd / sum_w, ld / sum_l, wf / sum_w, lf / sum_l])
	# A beetle in torchlight is gone from view within a second.
	var bug: Dictionary = {}
	var bstand := Vector3.INF
	for kind in ["beetle", "scarab"]:
		for b in wl.bugs:
			if str(b.kind) != kind or str(b.state) not in ["crawl", "rest"] or wl.world_pos(b).distance_to(w[0]) < 6.0:
				continue
			var f: Dictionary = main.walls[int(b.face)]
			var at := _stand_before(main, wl.world_pos(b), f.n, 1.1)
			if at != Vector3.INF:
				bug = b
				bstand = at
				break
		if not bug.is_empty():
			break
	ok(not bug.is_empty(), "a beetle out on a wall with open floor before it")
	if not bug.is_empty():
		# Held still (resting) so it waits for the light.
		bug.state = "rest"
		bug.t = 60.0
		var bp := wl.world_pos(bug)
		_place_facing(p, bstand, bp)
		if not p.inventory.has_kind("torch"):
			p.inventory.add(Inventory.make("torch"))
		p.weapon = "torch"
		await _frames(30)
		ok((bug.node as Node3D).visible and str(bug.state) == "rest", "in the dark it stays out on the wall, you a metre off with the torch unlit")
		var at0: Vector2 = bug.at
		t.light()
		var gone := -1.0
		for i in 90:
			await process_frame
			if not (bug.node as Node3D).visible:
				gone = (i + 1) / 60.0
				break
		print("  the %s %.2f m from the flame, %.2f m from its joint" % [bug.kind, t.flame_position().distance_to(bp), (bug.crack as Vector2).distance_to(at0)])
		ok(gone > 0.0 and gone <= 1.0, "a %s in torchlight is gone from view within a second (%.2f s)" % [bug.kind, gone])
		var cells: Array = (main.walls[int(bug.face)] as Dictionary).get("cells", [])
		var jd := INF
		for c in cells:
			var poly: PackedVector2Array = c[1]
			for k in poly.size():
				jd = minf(jd, Geometry2D.get_closest_point_to_segment(bug.crack, poly[k], poly[(k + 1) % poly.size()]).distance_to(bug.crack))
		ok(jd < 0.002, "it went into a joint of the stone it was on (%.4f m off the joint's line)" % jd)
		# Out again later, in the dark.
		_drop_torches(p)
		p.spawn_flat(w[0], float(w[1]), -0.32)
		var hide: Array = WallLife.W.get("hide_s", [8.0, 22.0])
		var back := -1.0
		for i in int((float(hide[1]) + 2.0) * 60.0):
			await process_frame
			if (bug.node as Node3D).visible:
				back = (i + 1) / 60.0
				break
		ok(back >= float(hide[0]) - 0.1 and back <= float(hide[1]) + 0.5, "it comes out of its crack again later, in the dark (after %.1f s; hide_s %s)" % [back, str(hide)])
	# The world's clock runs in the crawler: the 144-minute day.
	var world := main.world
	var d0: float = world.days
	for i in 120:
		await process_frame
	var ran := (float(world.days) - d0) * float(world.day_length_s)
	ok(absf(ran - 2.0) < 0.05 and absf(float(world.day_length_s) - DayCycle.day_length_min() * 60.0) < 1.0, "the crawler runs the world's clock: 2 s of play turn its %.0f-minute day by %.3f s" % [float(world.day_length_s) / 60.0, ran])
	# The shafts' daylight with the sun over the tomb.
	var keep_days: float = world.days
	var e := {}
	var col_night := Color()
	for hh: float in [0.0, 6.0, 9.0, 12.0, 15.0, 17.0]:
		world.days = Vents.days_at_solar_hour(13.0, hh)
		await process_frame
		await process_frame
		var s := 0.0
		for sh in main.vents.shafts:
			s += (sh.light as SpotLight3D).light_energy
		e[hh] = s
		if hh == 0.0:
			col_night = (main.vents.shafts[0].light as SpotLight3D).light_color
	world.days = keep_days
	await process_frame
	print("  the shafts' light (summed): midnight %.1f, sunrise %.1f, 9:00 %.1f, noon %.1f, 15:00 %.1f, 17:00 %.1f" % [e[0.0], e[6.0], e[9.0], e[12.0], e[15.0], e[17.0]])
	ok(e[12.0] > e[9.0] and e[9.0] > e[6.0] and e[6.0] > e[0.0], "the shafts' daylight climbs with the sun: noon (%.1f) over 9:00 (%.1f) over sunrise (%.1f) over midnight (%.1f)" % [e[12.0], e[9.0], e[6.0], e[0.0]])
	ok(e[15.0] > e[17.0] and e[17.0] > e[0.0], "and sinks with it: 15:00 (%.1f) over 17:00 (%.1f)" % [e[15.0], e[17.0]])
	ok(col_night.b > col_night.r and col_night.b > col_night.g, "at night the shafts are moonlit blue (#%s)" % col_night.to_html(false))
	if boss is Boss:
		(boss as Boss).auto = keep_auto


## Where to stand to swing at holder `h`: a step out from a sconce's
## wall, a step back toward the room's way in from a hearth ring.
func _stand_by(main: CrawlerMain, h: Node3D) -> Vector3:
	var at := h.global_position
	var piece: Dictionary = main.lay.pieces[int(h.get_meta("piece"))]
	if str(h.get_meta("fire_holder")) == "sconce":
		return Vector3(at.x, at.y - float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), at.z) + h.global_basis.z * 0.8
	var d: Vector2 = piece.dir
	return Vector3(at.x - d.x, float(piece.y0), at.z - d.y)


## Frames of play: physics and process both, `n` of them.
func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _snuff(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	# A floor of its own far from the tomb, to run on.
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 2.0, 4000.0)
	cs.shape = box
	ground.add_child(cs)
	ground.position = Vector3(0.0, -301.0, 0.0)
	main.add_child(ground)
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(10)
	if not t.lit():
		t.light()
	# Walking and looking about a minute.
	Input.action_press("move_forward")
	var gmax := 0.0
	for i in 3600:
		p._yaw += 0.02 * sin(i * 0.01)
		p._pitch = 0.6 * sin(i * 0.013)
		await physics_frame
		gmax = maxf(gmax, t.snuff.gutter)
		if not t.lit():
			break
	Input.action_release("move_forward")
	ok(t.lit() and gmax == 0.0, "a minute of walking and looking about: lit, never guttering (§ET.7 walking_and_looking never)")
	# Running feeds the coal air (§EZ.1): the light over 4 s (two of the
	# coal's breaths) standing, then 4 s flat out.
	await _frames(30)
	var e_stand := 0.0
	for i in 240:
		await physics_frame
		e_stand += t._light.light_energy / 240.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var e_run := 0.0
	for i in 240:
		await physics_frame
		e_run += t._light.light_energy / 240.0
	Input.action_release("sprint")
	Input.action_release("move_forward")
	ok(t.lit() and e_run > e_stand * 1.03, "the torch glows brighter at a run: mean light energy %.2f flat out, %.2f standing (x%.3f; ember.air_brighten %.2f, §EZ.1)" % [e_run, e_stand, e_run / maxf(e_stand, 1e-4), float(Torch.EMBER.get("air_brighten", 0.18))])
	await _frames(30)
	# A minute of swinging it (§CN), looking about as you swing.
	var swings0 := t.swings
	var held := false
	var lit_all := true
	gmax = 0.0
	for i in 3600:
		p._yaw += 0.03 * sin(i * 0.02)
		p._pitch = 0.5 * sin(i * 0.017)
		if held:
			Input.action_release("shoot")
			held = false
		elif t._swing <= 0.0:
			Input.action_press("shoot")
			held = true
		await physics_frame
		gmax = maxf(gmax, t.snuff.gutter)
		lit_all = lit_all and t.lit()
	Input.action_release("shoot")
	ok(lit_all and gmax == 0.0 and t.swings - swings0 >= 30, "a minute of swinging it (%d swings, §CN): lit, never guttering (§EZ.1)" % (t.swings - swings0))
	# 120 s flat out round the tomb (every door depth-first from the hearth
	# room and back, again and again), whipping round every 4 s. Beside it,
	# §ET.7's removed sprint rule is kept on paper (a sprint held 6 s
	# guttered the torch, 9 s put it out, stopping drained it in 2 s), to
	# show when it would have put the torch out.
	var pts := _tour(main.lay)
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), 0.0)
	await _frames(5)
	if not t.lit():
		t.light()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var wi := 0
	var on_point := 0
	var stalls_here := 0
	var side := 1.0
	var window := 0
	var mark_d := INF
	var follow := false
	var follow_for := 0
	var detours := 0
	var skips := 0
	var stuck_in := {}
	var spin := 0
	var whips := 0
	var got := 0
	var at_sprint := 0
	var bank := 0.0
	var old_out := -1.0
	var dist := 0.0
	var in_draft := 0
	var flick_max := 0.0
	var gust_frames := 0
	var burn_gutter := false
	var last := p.global_position
	gmax = 0.0
	lit_all = true
	for i in 7200:
		var target: Vector3 = pts[wi]
		var to := Vector3(target.x - p.global_position.x, 0.0, target.z - p.global_position.z)
		if to.length() < 0.6:
			wi = (wi + 1) % pts.size()
			got += 1
			on_point = 0
			stalls_here = 0
			side = 1.0
			window = 0
			mark_d = INF
			follow = false
			target = pts[wi]
			to = Vector3(target.x - p.global_position.x, 0.0, target.z - p.global_position.z)
		if i % 240 == 120:
			spin = 15
			whips += 1
		if spin > 0:
			# A full turn in a quarter of a second.
			p._yaw += TAU / 15.0
			spin -= 1
		elif follow:
			# Round what's in the way: the clear heading nearest the point,
			# turning to one side, until the straight line is clear again.
			follow_for += 1
			if _clear_ahead(p, to, minf(to.length(), 1.5)):
				follow = false
				p._yaw = atan2(-to.x, -to.z)
			else:
				p._yaw = _clear_heading(p, to, side)
			if follow_for == 180:
				side = -side
		elif to.length() > 0.01:
			p._yaw = atan2(-to.x, -to.z)
		p._pitch = 0.5 * sin(i * 0.05)
		await physics_frame
		var now := p.global_position
		dist += Vector2(now.x - last.x, now.z - last.z).length()
		last = now
		var flat := Vector3(p.velocity.x, 0.0, p.velocity.z).length()
		if p.sprinting and flat > PlanetPlayer.WALK_SPEED * 0.9:
			at_sprint += 1
			bank += 1.0 / 60.0
		else:
			bank = maxf(bank - 1.0 / 60.0 * 6.0 / 2.0, 0.0)
		if bank >= 9.0 and old_out < 0.0:
			old_out = (i + 1) / 60.0
		gmax = maxf(gmax, t.snuff.gutter)
		lit_all = lit_all and t.lit()
		burn_gutter = burn_gutter or Torch.guttering(t.item())
		if t.snuff.lean.length() > 0.05:
			in_draft += 1
		flick_max = maxf(flick_max, t.snuff.flicker)
		if t.snuff.gust:
			gust_frames += 1
		# No headway for a moment (the hearth, a coffin, rubble): follow round
		# it; after 6 s on one point, skip to it.
		on_point += 1
		var d_now := Vector2(target.x - now.x, target.z - now.z).length()
		if spin > 0 or follow:
			window = 0
			mark_d = INF
		else:
			window += 1
			if window >= 18:
				if d_now > mark_d - 0.25:
					stalls_here += 1
					if stalls_here > 1:
						side = -side
					follow = true
					follow_for = 0
					detours += 1
				mark_d = d_now
				window = 0
		if on_point > 360:
			skips += 1
			var where := _piece_at(main.lay, now)
			stuck_in[where] = int(stuck_in.get(where, 0)) + 1
			p.spawn_flat(target, p._yaw, p._pitch)
			last = target
			on_point = 0
			follow = false
		if not t.lit():
			break
	Input.action_release("sprint")
	Input.action_release("move_forward")
	print("  the run: %d points on the tour, %d reached; %d times round something in the way, %d points skipped to %s; %.1f s in an airway's draft (flicker up to %.2f), %.1f s in a strong gust" % [pts.size(), got, detours, skips, str(stuck_in), in_draft / 60.0, flick_max, gust_frames / 60.0])
	ok(lit_all and gmax == 0.0 and not burn_gutter, "120 s flat out round the tomb (%.0f m, %d whip turns): lit, gutter 0 throughout (§EZ.1 moving_fast never)" % [dist, whips])
	# A real sprint, not a runner stuck against a wall (the turns, the
	# whips and the odd prop cost 10-20 s of the 120).
	ok(at_sprint / 60.0 >= 90.0 and old_out > 0.0, "a real sprint: %.0f s of the 120 at a sprint by the removed rule's own measure, which would have put the torch out %.1f s in" % [at_sprint / 60.0, old_out])
	await _frames(30)
	# The airways move the flame and never put it out (§EZ.5).
	var aw := main.airways
	var strong: Dictionary = {}
	var ordinary: Dictionary = {}
	for m in aw.mouths:
		if bool(m.strong) and strong.is_empty():
			strong = m
		elif not bool(m.strong) and ordinary.is_empty():
			ordinary = m
	var most := float(Airways.A.get("flicker", 0.25))
	if not ordinary.is_empty():
		var d := aw.draft_at((ordinary.pos as Vector3) + (ordinary.normal as Vector3) * 1.0)
		ok((d.lean as Vector3).length() > 0.1 and float(d.flicker) > 0.0 and float(d.flicker) <= most + 0.001 and not d.has("out") and not d.has("gutter"), "an ordinary airway leans the flame and quickens its flicker, never a gutter (lean %.2f m/s, flicker %.2f)" % [(d.lean as Vector3).length(), float(d.flicker)])
		# Stand under it with the torch lit.
		var opc: Dictionary = main.lay.pieces[int((main.lay.airways as Array)[aw.mouths.find(ordinary)].piece)]
		var under := (ordinary.pos as Vector3) + (ordinary.normal as Vector3) * 0.9
		under.y = Delves.floor_of(opc, Delves.along_across(opc, Vector2(under.x, under.z)).x)
		var onrm: Vector3 = ordinary.normal
		p.spawn_flat(under, atan2(onrm.x, onrm.z), 0.0)
		await _frames(5)
		t.light()
		var e_lo := INF
		var e_hi := 0.0
		gmax = 0.0
		for i in 120:
			await physics_frame
			gmax = maxf(gmax, t.snuff.gutter)
			e_lo = minf(e_lo, t._light.light_energy)
			e_hi = maxf(e_hi, t._light.light_energy)
		ok(t.lit() and gmax == 0.0 and t.snuff.flicker > 0.0 and t.snuff.lean.length() > 0.1, "under it the torch leans and flickers (flicker %.2f, light %.2f-%.2f) and never gutters" % [t.snuff.flicker, e_lo, e_hi])
	ok(not strong.is_empty(), "this tomb has a strong airway mouth")
	if not strong.is_empty():
		var mp: Vector3 = strong.pos
		var nrm: Vector3 = strong.normal
		var piece: Dictionary = main.lay.pieces[int((main.lay.airways as Array)[aw.mouths.find(strong)].piece)]
		var fy := Delves.floor_of(piece, 0.0)
		# Stand so the flame is 2.5 m out on its line: the flame sits at
		# (0.3, 1.25, -0.4) in your frame, so back off along the line.
		var face := -nrm
		var at := mp + nrm * 2.5
		var stand := at - Basis(Vector3.UP, atan2(-face.x, -face.z)) * Vector3(0.3, 0.0, -0.4)
		stand.y = fy
		strong.t = 30.0
		p.spawn_flat(stand, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		t.light()
		var fp := t.flame_position()
		print("  the flame %.2f m out from the mouth, %.2f m off its line" % [(fp - mp).dot(nrm), ((fp - mp) - nrm * (fp - mp).dot(nrm)).length()])
		var warn_s := float(Airways.SN.get("warn_s", 1.5))
		var gust_s := float(Airways.A.get("gust_s", 2.2))
		var voice: AudioStreamPlayer3D = strong.voice
		var lit_g := true
		var g_g := 0.0
		var lean_max := 0.0
		var whipped := 0
		var dusty := 0
		var moaned := 0
		for k in 3:
			strong.t = warn_s + 0.4
			var saw_gust := false
			var saw_dust := false
			var loud := -80.0
			for i in int((warn_s + 0.4 + gust_s + 1.0) * 60.0):
				await physics_frame
				lit_g = lit_g and t.lit()
				g_g = maxf(g_g, t.snuff.gutter)
				if str(strong.phase) == "warn":
					saw_dust = saw_dust or (strong.dust as CPUParticles3D).emitting
					loud = maxf(loud, voice.volume_db)
				if t.snuff.gust:
					saw_gust = true
					lean_max = maxf(lean_max, t.snuff.lean.length())
			whipped += 1 if saw_gust else 0
			dusty += 1 if saw_dust else 0
			moaned += 1 if loud > -12.0 else 0
		ok(lit_g and g_g == 0.0 and whipped == 3, "standing in a strong mouth's line through three gusts: lit, never guttering (§EZ.5; %d of 3 gusts reached the flame)" % whipped)
		ok(lean_max > 3.0, "each gust whips the torch hard away from the mouth (%.1f m/s at the flame: the coal's smoke streams flat)" % lean_max)
		ok(dusty == 3 and moaned == 3, "the mouth still moans and streams dust before every gust, as built (%d of 3, %d of 3)" % [moaned, dusty])
		# Out of its line, and behind cover, the gust doesn't reach it.
		strong.t = 30.0
		await _frames(2)
		p.spawn_flat(stand + nrm.cross(Vector3.UP).normalized() * 2.2, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		strong.t = -0.1
		var reached := false
		for i in 30:
			await physics_frame
			reached = reached or t.snuff.gust
		ok(t.lit() and not reached, "out of its line the gust passes the torch by")
		strong.t = 30.0
		await _frames(2)
		p.spawn_flat(stand, atan2(-face.x, -face.z), 0.0)
		await _frames(5)
		var block := StaticBody3D.new()
		var bcs := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(1.2, 1.2, 0.3)
		bcs.shape = bb
		block.add_child(bcs)
		main.add_child(block)
		block.global_transform = Transform3D(Basis.looking_at(nrm, Vector3.UP), mp + nrm * 1.2)
		await _frames(2)
		strong.t = -0.1
		reached = false
		for i in 30:
			await physics_frame
			reached = reached or t.snuff.gust
		print("  cover: lit %s draft %s covered %s" % [t.lit(), str(aw.draft_at(t.flame_position())), aw._covered(mp + nrm * 0.35, t.flame_position())])
		ok(t.lit() and not reached, "behind cover the gust doesn't reach it (§ET.7 shelter)")
		block.queue_free()
		strong.t = 30.0
	# Water: the one thing that puts it out (§EZ.5), warning first.
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	t.light()
	await _frames(5)
	var steady: Color = t._light.light_color
	var douse := float(Torch.D.get("douse_depth_m", 0.6))
	p.water_depth_m = douse - 0.08
	await _frames(30)
	ok(t.lit() and t.snuff.gutter > 0.3 and t.snuff.cause == "water", "wading toward douse_depth_m gutters it, still lit (gutter %.2f)" % t.snuff.gutter)
	# Guttering reddens, never cools (§EX.6).
	var gut: Color = t._light.light_color
	ok(gut.b / maxf(gut.r, 1e-4) <= steady.b / maxf(steady.r, 1e-4) + 1e-4 and gut.g / maxf(gut.r, 1e-4) <= steady.g / maxf(steady.r, 1e-4) + 1e-4, "a guttering torch's light is redder, never bluer (steady #%s, guttering #%s)" % [steady.to_html(false), gut.to_html(false)])
	p.water_depth_m = douse + 0.1
	await _frames(3)
	ok(not t.lit() and str(GameLog.entries[-1].get("text", "")).contains("water"), "past douse_depth_m the water puts it out (§AW; the one way out now, §EZ.5)")
	p.water_depth_m = -INF


## Can your own body move `m` metres along `toward` (flat), lifted clear
## of the floor's lips?
func _clear_ahead(p: CrawlerPlayer, toward: Vector3, m: float) -> bool:
	var dir := Vector3(toward.x, 0.0, toward.z).normalized()
	return not p.test_move(p.global_transform.translated(Vector3(0.0, 0.15, 0.0)), dir * maxf(m, 0.3))


## The clear heading (0.7 m along it) nearest `toward`, turning to `side`
## (+1 left, -1 right) in 15° steps: so a body following it slides round
## what's in the way.
func _clear_heading(p: CrawlerPlayer, toward: Vector3, side: float) -> float:
	var base := atan2(-toward.x, -toward.z)
	var from := p.global_transform.translated(Vector3(0.0, 0.15, 0.0))
	for k in range(1, 13):
		var yaw: float = base + side * deg_to_rad(15.0 * k)
		if not p.test_move(from, Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.7):
			return yaw
	return base + PI


## Which piece `pos` is in: its room's kind, or corridor / stair.
func _piece_at(lay: Dictionary, pos: Vector3) -> String:
	for pc in lay.pieces:
		var aa := Delves.along_across(pc, Vector2(pos.x, pos.z))
		if aa.x >= -0.05 and aa.x <= float(pc.len) + 0.05 and absf(aa.y) <= float(pc.half) + 0.05:
			return str(pc.get("room_kind", pc.kind))
	return "between"


## A run round the tomb: every door crossed depth-first from the hearth
## room and back, as points a step either side of it at its floor; not the
## way out's opening (stepping into it walks you out, §EX.5): the run turns
## on its landing.
func _tour(lay: Dictionary) -> Array:
	var pts: Array = []
	_tour_from(lay, 0, {0: true}, pts)
	return pts


func _tour_from(lay: Dictionary, id: int, seen: Dictionary, pts: Array) -> void:
	for di in lay.pieces[id].doors:
		var d: Dictionary = lay.doors[di]
		var o := int(d.b) if int(d.a) == id else int(d.a)
		if o < 0 or seen.has(o):
			continue
		seen[o] = true
		var n: Vector2 = (d.n as Vector2) if int(d.a) == id else -(d.n as Vector2)
		var dp: Vector2 = d.p
		var y := float(d.y)
		var near := Vector3(dp.x - n.x * 0.9, y, dp.y - n.y * 0.9)
		var far := Vector3(dp.x + n.x * 0.9, y, dp.y + n.y * 0.9)
		pts.append(near)
		pts.append(far)
		_tour_from(lay, o, seen, pts)
		pts.append(far)
		pts.append(near)


## Press F as the player would: the key through the input, a couple of
## frames for it to land.
func _press_f() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F
		ev.keycode = KEY_F
		ev.pressed = down
		Input.parse_input_event(ev)
		for i in 2:
			await process_frame


## A lit torch stood at `at` (scene), as PlantedTorch.plant stands one (the
## crawler has no world root to hang it from).
func _planted(main: CrawlerMain, at: Vector3) -> PlantedTorch:
	var pt := PlantedTorch.new()
	pt.item = Inventory.make("torch", {"lit": true, "burn_left_min": 40.0})
	main.add_child(pt)
	pt.global_position = at
	PlantedTorch.all.append(pt)
	return pt


func _unplant(pt: PlantedTorch) -> void:
	PlantedTorch.all.erase(pt)
	pt.queue_free()


## Dousing your own torch (design 6 Oct §FC.3; Torch.douse, F).
func _douse(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var fires := main.fires
	var hands = JSON.parse_string(FileAccess.get_file_as_string("res://data/hands.json"))
	var keyed := false
	for ev in InputMap.action_get_events("douse"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_F:
			keyed = true
	ok(keyed and str((hands as Dictionary).get("douse_key", "")) == "F", "the douse action is on F (hands.json douse_key)")
	# The torch is out (the water, at the end of the snuff rules): relit at
	# the hearth.
	var hp := fires.hearth.global_position
	_place_facing(p, hp + Vector3(0.0, 0.0, 1.0), hp)
	await _frames(5)
	ok(not t.lit() and t.pass_flame() == "torch" and t.lit(), "the torch the water put out relights at the hearth")
	# A spare in the pack ahead of the torch in hand.
	var held := t.item()
	var slots: Array = p.inventory.carried
	for i in slots.size():
		if is_same(slots[i], held):
			slots[i] = null
	p.inventory.add(Inventory.make("torch"))
	p.inventory.add(held)
	ok(is_same(t.item(), held) and t.lit(), "a spare goes in the pack ahead of the lit torch in hand")
	# Watchers by night (Senses: a lurker 20 m off sees a lit torch from
	# light_sight_m; it neither sees you dark nor smells you).
	Senses.override = {"daylight": 0.0, "moonlight": 0.0}
	var eye := p.eye_position() + Vector3(20.0, 0.0, 0.0)
	var sensed_lit := Senses.can_sense("lurker", eye, p, 0.0)
	var lights_lit := Senses.lights().size()
	# F, the physics held still so the burn can't move.
	p.set_physics_process(false)
	var burn := float(held.get("burn_left_min", -1.0))
	var n_log := GameLog.entries.size()
	var line := str(Torch.DOUSE.get("log_line", ""))
	# A hunter's chase (§FD, Pursuit): one whose gives_up says
	# torch_doused loses you the moment your torch goes out.
	var chase := Pursuit.new(main, {"torch_doused": true})
	chase.notice(t.lit())
	var chased := not chase.step(0.1, true, 5.0, t.lit())
	await _press_f()
	ok(not t.lit() and t.in_hand() and p.weapon == "torch" and is_same(t.item(), held), "F smothers the lit torch: out, and still the one in your hand")
	ok(float(held.get("burn_left_min", -2.0)) == burn, "its burn is unchanged (%.4f min)" % burn)
	ok(GameLog.entries.size() == n_log + 1 and str(GameLog.entries[-1].get("text", "")) == line and line != "", "one log line: \"%s\"" % line)
	ok(t.last_out == "smothered" and not str(GameLog.entries[-1].get("text", "")).contains("water"), "smothered, not water (its reason '%s')" % t.last_out)
	ok(sensed_lit == "light" and lights_lit >= 1 and Senses.lights().is_empty() and Senses.can_sense("lurker", eye, p, 0.0) == "" and Torch.light_at(p.global_position) == 0.0, "a doused torch gives nothing away: the lurker saw its light (%s), now nothing (%s)" % [sensed_lit, Senses.can_sense("lurker", eye, p, 0.0)])
	Senses.override = {}
	var lost := chase.step(0.1, true, 5.0, t.lit())
	ok(chased and lost and chase.why == "torch_doused" and not chase.on, "a hunter's chase gives you up the moment you smother it (Pursuit, gives_up torch_doused: '%s')" % chase.why)
	await _press_f()
	ok(not t.lit() and GameLog.entries.size() == n_log + 1, "F with no flame does nothing")
	p.set_physics_process(true)
	await _frames(60)
	ok(float(held.get("burn_left_min", -2.0)) == burn, "out, it keeps its burn")
	# Relight: the hearth, a relit sconce, a planted torch (§CN, as built).
	ok(t.pass_flame() == "torch" and t.lit() and is_same(t.item(), held) and float(held.get("burn_left_min", -2.0)) == burn, "the smothered torch relights at the hearth, the same torch, its burn as it was")
	var sconce: Node3D = null
	for h in fires.holders:
		if str(h.get_meta("fire_holder")) == "sconce" and FireStore.is_lit(h):
			sconce = h
			break
	ok(sconce != null, "a relit sconce to relight at")
	if sconce != null:
		_place_facing(p, _stand_by(main, sconce), sconce.global_position)
		await _frames(5)
		ok(t.douse() and not t.lit() and t.pass_flame() == "torch" and t.lit(), "smothered by a relit sconce, it relights at the sconce")
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	var pt := _planted(main, Vector3(0.0, -300.0, -1.0))
	await _frames(2)
	ok(t.douse() and not t.lit() and t.pass_flame() == "torch" and t.lit(), "smothered by a planted torch, it relights at the planted torch")
	_unplant(pt)
	await _frames(2)


## The half-dark (design 6 Oct §FC.4; HalfDark, crawler.json dark).
func _half_dark(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var hd := main.half_dark
	var l := hd.light
	var c := l.light_color
	ok(c.is_equal_approx(HalfDark.color()) and c.b > c.r * 2.0 and c.b > c.g * 2.0, "the half-dark's light is the dark's navy (#%s), never warm" % c.to_html(false))
	ok(not l.shadow_enabled and l.light_specular == 0.0 and is_equal_approx(l.omni_range, HalfDark.black_m()), "no shadow, no shine, nothing past black_m (%.0f m)" % HalfDark.black_m())
	var adjust := float(HalfDark.DARK.get("adjust_s", 1.2))
	var fade := float(HalfDark.DARK.get("fade_s", 0.4))
	# Away from every fire (the floor of its own below the tomb).
	p.spawn_flat(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	if not t.lit():
		t.light()
	await _frames(int(adjust * 60.0) + 10)
	ok(hd.strength == 0.0 and not l.visible, "your torch lit: nothing added (strength %.2f)" % hd.strength)
	t.douse()
	await _frames(int(adjust * 30.0))
	var half := hd.strength
	await _frames(int(adjust * 30.0) + 10)
	ok(half > 0.2 and half < 0.8 and hd.strength == 1.0 and l.visible and is_equal_approx(l.light_energy, HalfDark.energy()), "doused with no flame near, the dark eases readable over adjust_s (%.2f halfway, then %.2f; energy %.2f)" % [half, hd.strength, l.light_energy])
	t.light()
	await _frames(1)
	ok(hd.strength == 0.0 and not l.visible, "the torch relit: off at once")
	# A lit planted torch 3 m off: behind a wall it doesn't count, in sight
	# it does.
	t.douse()
	var pt := _planted(main, Vector3(0.0, -300.0, -3.0))
	var wall := StaticBody3D.new()
	wall.collision_layer = PropCollision.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4.0, 4.0, 0.3)
	cs.shape = bx
	wall.add_child(cs)
	main.add_child(wall)
	wall.global_position = Vector3(0.0, -299.0, -1.5)
	await _frames(int(adjust * 60.0) + 10)
	ok(hd.strength == 1.0, "a lit torch 3 m off behind a wall is no flame near: the dark readable (%.2f)" % hd.strength)
	wall.queue_free()
	await _frames(int(fade * 60.0) + 10)
	ok(hd.strength == 0.0 and not l.visible, "the same torch in sight: nothing added (%.2f)" % hd.strength)
	_unplant(pt)
	# A fire pot's tar burning on the floor 3 m off (§FA.3): fire too.
	await _frames(int(adjust * 60.0) + 10)
	var back := hd.strength
	main.fire_pots.burst(Vector3(0.0, -299.75, -3.0), "tar", null, Vector3.UP)
	await _frames(int(fade * 60.0) + 10)
	ok(back == 1.0 and hd.strength == 0.0 and not l.visible, "a fire pot's tar burning 3 m off is a flame near too: nothing added (%.2f, from %.2f)" % [hd.strength, back])
	# Beside a relit sconce, doused: its light is on you.
	var sconce: Node3D = null
	for h in main.fires.holders:
		if str(h.get_meta("fire_holder")) == "sconce" and FireStore.is_lit(h):
			sconce = h
			break
	if sconce != null:
		await _frames(int(adjust * 60.0) + 10)
		_place_facing(p, _stand_by(main, sconce), sconce.global_position)
		await _frames(int(fade * 60.0) + 10)
		ok(hd.strength == 0.0, "beside a relit sconce, doused: the sconce's light, nothing added (%.2f)" % hd.strength)
	# Waking by the hearth.
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(int(fade * 60.0) + 10)
	ok(hd.strength == 0.0, "by the lit hearth: nothing added (%.2f)" % hd.strength)


## The materials on every mesh under `n`: [GeometryInstance3D, Material].
func _materials_under(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		if g.material_override != null:
			out.append([g, g.material_override])
		var mi := g as MeshInstance3D
		if mi != null and mi.mesh != null and g.material_override == null:
			for si in mi.mesh.get_surface_count():
				var m: Material = mi.get_surface_override_material(si)
				if m == null:
					m = mi.mesh.surface_get_material(si)
				if m != null:
					out.append([g, m])
	return out


## Diffuse only (§ES.2): "" if `m` has no specular above 0, no roughness
## under 1 and no normal map; else what's wrong.
func _diffuse_only(m: Material) -> String:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.specular_mode != BaseMaterial3D.SPECULAR_DISABLED and b.metallic_specular > 0.0:
			return "specular %.2f" % b.metallic_specular
		if b.roughness < 1.0:
			return "roughness %.2f" % b.roughness
		if b.normal_enabled:
			return "a normal map"
		return ""
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh == null:
			return "no shader"
		var code := sh.code
		var rm := RegEx.create_from_string("render_mode([^;]*);").search(code)
		var modes := rm.get_string(1) if rm != null else ""
		if not modes.contains("specular_disabled") and not modes.contains("unshaded"):
			return "%s: specular not disabled" % sh.resource_path
		for a in RegEx.create_from_string("ROUGHNESS\\s*=\\s*([^;]+);").search_all(code):
			if a.get_string(1).strip_edges() != "1.0":
				return "%s: ROUGHNESS = %s" % [sh.resource_path, a.get_string(1)]
		for a in RegEx.create_from_string("SPECULAR\\s*=\\s*([^;]+);").search_all(code):
			if a.get_string(1).strip_edges() != "0.0":
				return "%s: SPECULAR = %s" % [sh.resource_path, a.get_string(1)]
		if code.contains("NORMAL_MAP"):
			return "%s: a normal map" % sh.resource_path
		return ""
	return "a %s" % m.get_class()


func _rescuer(main: CrawlerMain) -> void:
	var r := main.rescuer
	var p := main.player
	# Back on the mat, across the fire from it (the rig poses only near the
	# eyes, as every figure does).
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(30)
	# The live rig, not a sprite (§FH); the boss's body stays sprites
	# (creatures and bosses keep theirs, §EY.5, queue 49).
	var sprites := 0
	for n in main.find_children("*", "", true, false):
		# The boss's body and the residents' stay sprites (creatures and
		# bosses keep theirs, §ET.8, §EY.5; queues 49 and 58).
		if n is FigureSprite and not (main.boss != null and main.boss.is_ancestor_of(n)) and not (n is ResidentSprite):
			sprites += 1
	var body := r.body if r != null else null
	ok(r is HearthFolk and body is PlayerBody and r.get_parent() == main and sprites == 0, "the rescuer is the live 3D rig (a HearthFolk holding the shared PlayerBody), and no FigureSprite in the tomb but the boss's and the skeletons' (%d)" % sprites)
	if body == null:
		return
	var beast_mi := body.head.get_node_or_null("Beast") as MeshInstance3D
	ok(body.seated and r.beast != "" and body.beast == r.beast and beast_mi != null and beast_mi.is_visible_in_tree(), "seated, wearing its beast's head: %s (§EO, §EQ)" % r.beast)
	var tris := body.triangles
	if beast_mi != null:
		tris += int(beast_mi.mesh.get_meta("tris", 0))
	var parts := 0
	for g in r.find_children("*", "GeometryInstance3D", true, false):
		if (g as GeometryInstance3D).is_visible_in_tree():
			parts += 1
	print("  the rescuer: %s, %d triangles in %d parts, scale %.2f, its cloth %.0f µs a step" % [r.beast, tris, parts, r.k, body.sim_usec_avg])
	# (The rig is ~4.4k against §ES.2's ~1,500, an open call for Mike since
	# the §ES pass; this only holds it there.)
	ok(tris >= 600 and tris <= 6000, "real geometry, the shared rig's own: %d triangles (§ES.2's ~1,500 is Mike's open call)" % tris)
	# Facing the hearth, on its stone.
	var to_hearth := main.fires.hearth.global_position - r.global_position
	to_hearth.y = 0.0
	ok(r.front().dot(to_hearth.normalized()) > 0.9, "it sits facing the hearth")
	var blockers: Array[RID] = [p.get_rid()]
	for b in r.find_children("Blocker", "StaticBody3D", true, false):
		blockers.append((b as StaticBody3D).get_rid())
	# Chest high, from 1 m in front of it: the blocker stops the ray at it.
	var chest := r.global_position + Vector3.UP * 0.7
	var bump := _ray(chest + r.front() * 1.0, chest - r.front() * 0.3, [p.get_rid()])
	var bump_m := (bump.position as Vector3).distance_to(chest + r.front() * 1.0) if not bump.is_empty() else INF
	ok(blockers.size() == 2 and not bump.is_empty() and Hitboxes.creature_of(bump.collider) == r and bump_m > 0.5 and bump_m < 0.9, "something to bump into, round it (the rig's blocker, %.2f m in from 1 m)" % bump_m)
	var seat := HearthFolk.seat((main.lay.rescuer as Array)[0], float((main.lay.rescuer as Array)[1]))
	var sc: Vector3 = (seat.xf as Transform3D).origin
	var hit := _ray(Vector3(sc.x, 1.5, sc.z), Vector3(sc.x, -0.5, sc.z), blockers)
	var hips := (body.get_node("Hips") as Node3D).global_position
	var under := hips.y - 0.075 * r.k
	var top := float((hit.get("position", Vector3.ZERO) as Vector3).y)
	print("  its stone: top %.3f m, under its hips %.3f m (hips %.3f)" % [top, under, hips.y])
	ok(not hit.is_empty() and absf(top - float(HearthFolk.RES.get("seat_h_m", 0.32))) < 0.04 and absf(under - top) < 0.03 and Vector2(hips.x - sc.x, hips.z - sc.z).length() < 0.15, "it sits on its stone: the stone in the tomb's collision right under its hips (%.2f m)" % top)
	# Painted per §ES: diffuse only, big texels, casting the fire's shadow.
	var mats := _materials_under(r)
	var bad: Array = []
	var texel_ok := true
	var want_texels := float(HearthFolk.F3D.get("texels_per_m", 16.0))
	var shadowless := 0
	for e in mats:
		var why := _diffuse_only(e[1])
		if why != "":
			bad.append("%s: %s" % [(e[0] as Node).name, why])
		if e[1] is ShaderMaterial and absf(float((e[1] as ShaderMaterial).get_shader_parameter("texel_m")) - want_texels) > 0.01:
			texel_ok = false
		if (e[0] as GeometryInstance3D).is_visible_in_tree() and (e[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadowless += 1
	ok(mats.size() > 0 and bad.is_empty(), "no material on it has specular above 0, roughness under 1 or a normal map (§ES.2; %d checked)%s" % [mats.size(), (": " + ", ".join(bad)) if not bad.is_empty() else ""])
	ok(texel_ok, "its painted detail in big texels, %.0f a metre, the walls' grid (folk_3d.texels_per_m), its head too" % want_texels)
	ok(shadowless == 0, "every part of it casts the fire's shadow, its head too (%d without)" % shadowless)
	var shared_head := BeastHeads.material(r.beast)
	var shared_texels: Variant = shared_head.get_shader_parameter("texel_m")
	ok(beast_mi != null and beast_mi.material_override != shared_head and (shared_texels == null or absf(float(shared_texels)) < 0.001), "its head's big texels are its own: the %s heads elsewhere keep theirs" % r.beast)
	# Its idle (§FH): a slow breath, the neck rising and falling with it.
	var neck := body.head
	var lo := INF
	var hi := -INF
	var breath_s := float(HearthFolk.RES.get("breath_s", 4.5))
	for i in int(breath_s * 60.0 * 1.2):
		await physics_frame
		lo = minf(lo, neck.global_position.y)
		hi = maxf(hi, neck.global_position.y)
	ok(hi - lo > 0.008 and hi - lo < 0.06, "it breathes: its neck rises and falls %.1f cm over a breath (%.1f s)" % [(hi - lo) * 100.0, breath_s])
	# Its hood to you, in front of it and off to one side.
	var front := r.front()
	var side := front.cross(Vector3.UP)
	var at := r.global_position + (front * cos(0.6) + side * sin(0.6)) * 2.2
	_place_facing(p, Vector3(at.x, 0.0, at.z), r.global_position)
	await _frames(90)
	var cam := get_root().get_viewport().get_camera_3d().global_position
	var to_cam := cam - neck.global_position
	to_cam.y = 0.0
	var hood := -neck.global_basis.z
	hood.y = 0.0
	var a_hood := rad_to_deg(hood.angle_to(to_cam))
	var a_body := rad_to_deg(front.angle_to(to_cam))
	print("  you %.0f° off its front: its hood %.0f° from you" % [a_body, a_hood])
	ok(a_hood < a_body - 15.0, "it turns its hood to you while you're near and in front of it (%.0f° off, from %.0f°)" % [a_hood, a_body])
	p.spawn_flat(w[0], float(w[1]), -0.32)
	await _frames(10)


## FigureSprite stays for creatures and bosses (§ET.8, folk_3d.
## sprites_stay_for): a sheet (blank here: no renderer) on a test sprite,
## the frame picked by where the camera stands, its idle stepping.
func _sprite_kept(main: CrawlerMain) -> void:
	var rows: Array = FigureSprite.SP.get("rows_deg", [-25, 0, 30])
	var around := int(FigureSprite.SP.get("around", 8))
	var n := 4
	var px := 96
	var r := FigureSprite.new()
	r.name = "SpriteCheck"
	main.add_child(r)
	r.global_position = Vector3(0.0, -300.0, 40.0)
	var yaw := 0.7
	var sheet := Image.create(int(round(px * 0.75)) * around * n, px * rows.size(), false, Image.FORMAT_RGBA8)
	r.setup(sheet, 1.62, n, 1.62 * 0.93, yaw)
	ok(r.atlas.get_width() == int(round(px * 0.75)) * around * n and r.atlas.get_height() == px * rows.size(), "FigureSprite kept for creatures and bosses: a sheet %d around x %d heights x %d idle frames (%dx%d)" % [around, rows.size(), n, r.atlas.get_width(), r.atlas.get_height()])
	var foot := r.global_position
	var front := Vector3(-sin(r.yaw), 0.0, -cos(r.yaw))
	var left := front.cross(Vector3.UP) * -1.0
	var eye := foot + Vector3(0.0, r.eye_m, 0.0)
	var row_of := func(deg: float) -> int:
		for i in rows.size():
			if is_equal_approx(float(rows[i]), deg):
				return i
		return -1
	var row0: int = row_of.call(0.0)
	ok(r.frame_for(eye + front * 3.0) == Vector2i(0, row0), "a sprite in front at eye height: frame 0, the level row")
	ok(r.frame_for(eye + left * 3.0) == Vector2i(2, row0), "at its left: frame 2 of 8")
	ok(r.frame_for(eye - front * 3.0) == Vector2i(4, row0), "behind it: frame 4 of 8")
	ok(r.frame_for(eye + front * 2.0 + Vector3(0.0, 2.0, 0.0)).y == row_of.call(30.0), "from above: the row from above")
	ok(r.frame_for(eye + front * 3.0 - Vector3(0.0, 1.6, 0.0)).y == row_of.call(-25.0), "from below: the row from below")
	var seen := {}
	for i in 60:
		seen[r.idle_frame(i * 0.25)] = true
	ok(seen.size() == n, "its idle steps through all %d frames" % n)
	NodeRelease.free_later(r)


## Process frames (the crosshair redraws in its own _process, after the
## frame's signal).
func _ticks(n: int) -> void:
	for i in n:
		await process_frame


## The crosshair (design §EX.7; Reticle, crawler.json hud, hud.json
## reticle).
func _reticle(main: CrawlerMain) -> void:
	var R: Dictionary = Tuning.section("hud", "reticle")
	var H: Dictionary = CrawlerMain.HUD
	# Waking's dark lifted (it is drawn over the crosshair while it lasts).
	for i in 600:
		if not main._fade.visible:
			break
		await process_frame
	var ret: Reticle = main.reticle
	var n_ret := 0
	var open_world := 0
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Reticle:
			n_ret += 1
		if n is StatusHud or n is Hud:
			open_world += 1
		stack.append_array(n.get_children())
	ok(bool(H.get("reticle", false)) and ret != null and n_ret == 1 and ret.get_parent() == main.ui, "crawler.json hud.reticle: one crosshair, in the crawler's HUD (%d)" % n_ret)
	if ret == null:
		return
	ok(open_world == 0, "nothing else of the open world's HUD comes with it: no StatusHud, no Hud (%d)" % open_world)
	# The player's settings, put back at the end.
	var had_preset: Variant = Settings.get_value("display.preset") if Settings.has("display.preset") else null
	var had_switch: Variant = Settings.get_value("hud.reticle") if Settings.has("hud.reticle") else null
	Settings.set_bool("hud.reticle", true)
	await _ticks(2)
	# In play: the crosshair and nothing else, no words (§ET.3).
	var shown_now: Array = []
	var words := 0
	for c in main.ui.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		shown_now.append(str(ctl.name))
		var t: Variant = ctl.get("text")
		if t is String and str(t) != "":
			words += 1
	ok(not bool(H.get("words", true)) and shown_now == ["Reticle"] and words == 0 and ret.showing(), "in play the crawler's HUD shows the crosshair and nothing else, and no words (shown: %s)" % [shown_now])
	# Drawn over the finished frame (past the grade, the dither and the
	# 3D glow, which never takes the canvas here), in a solid, ordinary
	# colour: it gives off no light.
	var col := Reticle.color()
	ok(main.ui.layer > main.post.layer and main.environment.background_mode != Environment.BG_CANVAS and col.a == 1.0 and maxf(col.r, maxf(col.g, col.b)) <= 1.0, "it gives off no light: drawn over the graded frame (layer %d over the grade's %d), never in the 3D glow, solid #%s" % [main.ui.layer, main.post.layer, col.to_html(false)])
	# Round the frame's middle pixel and sized per hud.json at 480 and
	# 270 lines (its sizes are at the 480 reference, like the text's).
	var ref := float(Tuning.section("hud", "text").get("ref_height_px", 480))
	for lines_want in [480, 270]:
		var pname := ""
		for nm in Display.presets():
			if int(Display.presets()[nm]) == lines_want:
				pname = str(nm)
		if pname == "":
			ok(false, "a pixel-size preset of %d lines (look.json render.presets)" % lines_want)
			continue
		Settings.set_value("display.preset", pname)
		Display.apply()
		await _ticks(2)
		var f := Display.internal_size()
		var k := float(lines_want) / ref
		var arm := maxi(roundi(float(R.get("size_px", 10)) * 0.5 * k), 1)
		var gap := maxi(roundi(float(R.get("gap_px", 3)) * k), 0)
		var w := maxi(roundi(float(R.get("thickness_px", 1)) * k), 1)
		var cl := Reticle.cells(f)
		var arms: Array = cl.arms
		var bad: Array = []
		var px := {}
		var box := Rect2i()
		for i in arms.size():
			var a: Rect2i = arms[i]
			if a.size != (Vector2i(arm, w) if i < 2 else Vector2i(w, arm)):
				bad.append("arm %d is %s" % [i, a.size])
			box = a if i == 0 else box.merge(a)
			for y in range(a.position.y, a.end.y):
				for x in range(a.position.x, a.end.x):
					if px.has(Vector2i(x, y)):
						bad.append("arms overlap at %s" % Vector2i(x, y))
					px[Vector2i(x, y)] = true
		# A plus: left and right on the up arm's rows, up and down on its
		# columns, each gap clear of the band where they cross.
		var l: Rect2i = arms[0]
		var r: Rect2i = arms[1]
		var u: Rect2i = arms[2]
		var d: Rect2i = arms[3]
		if l.position.y != r.position.y or u.position.x != d.position.x or l.position.y != u.end.y + gap or r.position.y != l.position.y:
			bad.append("not a plus")
		var gaps := [u.position.x - l.end.x, r.position.x - u.end.x, l.position.y - u.end.y, d.position.y - l.end.y]
		for g in gaps:
			if int(g) != gap:
				bad.append("gaps %s" % [gaps])
				break
		# The same on every side: the arms mirror round the box's middle,
		# which is the frame's (within half a pixel: a one-pixel line sits
		# on the middle pixel, right and below the frame's centre).
		for p: Vector2i in px:
			if not px.has(Vector2i(box.position.x + box.end.x - 1 - p.x, p.y)) or not px.has(Vector2i(p.x, box.position.y + box.end.y - 1 - p.y)):
				bad.append("not symmetric")
				break
		var mid := Vector2(box.position + box.end) * 0.5
		var off := mid - Vector2(f) * 0.5
		if absf(off.x) > 0.5 or absf(off.y) > 0.5 or box.size != Vector2i.ONE * (2 * (gap + arm) + w):
			bad.append("box %s, %s off the centre" % [box, off])
		# The dark edge: every pixel next to an arm (8 ways) that isn't
		# one, each once, and nothing else.
		var edge := {}
		var twice := 0
		for e: Rect2i in cl.edge:
			for y in range(e.position.y, e.end.y):
				for x in range(e.position.x, e.end.x):
					var p := Vector2i(x, y)
					if edge.has(p) or px.has(p):
						twice += 1
					edge[p] = true
		var want_edge := {}
		for p: Vector2i in px:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := p + Vector2i(dx, dy)
					if not px.has(q):
						want_edge[q] = true
		var edge_ok := twice == 0 and edge.size() == want_edge.size()
		for q in want_edge:
			if not edge.has(q):
				edge_ok = false
		if not edge_ok:
			bad.append("edge %d px (want %d), %d twice" % [edge.size(), want_edge.size(), twice])
		var vp := ret.get_viewport_rect().size
		if Vector2i(vp.round()) != f:
			bad.append("drawn on a %s frame, not the internal %s" % [vp, f])
		print("  %d lines (%dx%d): middle pixel %s; arms %d px x %d, %d clear of the middle, %d px across; edge %d px" % [lines_want, f.x, f.y, str(cl.middle), arm, w, gap, box.size.x, edge.size()])
		ok(bad.is_empty(), "%d lines: the crosshair round the frame's middle pixel, four arms %d px long and %d wide, %d px clear of the middle, the same on every side, its dark edge one pixel round it (hud.json size_px %s, gap_px %s, thickness_px %s at the 480 reference)%s" % [lines_want, arm, w, gap, str(R.get("size_px")), str(R.get("gap_px")), str(R.get("thickness_px")), "" if bad.is_empty() else ": %s" % [bad]])
	# The Settings switch (Crosshair dot) hides it, and shows it again.
	Settings.set_bool("hud.reticle", false)
	await _ticks(2)
	var off_ok := not ret.showing() and not ret._key.is_empty() and not bool(ret._key[0])
	Settings.set_bool("hud.reticle", true)
	await _ticks(2)
	var on_ok := ret.showing() and bool(ret._key[0])
	ok(off_ok and on_ok, "the Settings switch hud.reticle (Crosshair dot) hides it, and brings it back")
	# Never over an open panel: the log and the settings both cover the
	# middle of the frame.
	main.log_panel.open()
	await _ticks(2)
	var under_log := ret.showing()
	main.log_panel.close()
	main.settings_panel.open()
	await _ticks(2)
	var under_settings := ret.showing()
	main.settings_panel.close()
	await _ticks(2)
	ok(not under_log and not under_settings and ret.showing(), "hidden while the log or the settings are open, back when they close")
	# A hit (Mike, 7 Oct; hud.json reticle.hit_marker): its X for show_s.
	var HM: Dictionary = R.get("hit_marker", {})
	var show_s := float(HM.get("show_s", 0.3))
	var x_before := ret.hit_showing()
	Reticle.hit()
	await _ticks(2)
	var x_on := ret.hit_showing() and ret._key.size() > 4 and bool(ret._key[4])
	await _ticks(int(show_s * 60.0) + 4)
	ok(not x_before and x_on and not ret.hit_showing(), "a hit (Reticle.hit) shows the X, and it goes again after show_s (%.2f s)" % show_s)
	for lines_n in [480, 270]:
		var k := float(lines_n) / ref
		var fw := int(round(lines_n * 16.0 / 9.0))
		var f := Vector2i(fw + (fw & 1), lines_n)
		var faults: Array = []
		for under in ["cross", "dashes"]:
			for e in _x_faults(f, k, under):
				faults.append("over the %s: %s" % [under, e])
		var xc := Reticle.x_cells(f, k)
		ok(faults.is_empty(), "%d lines: the hit's X is four diagonals in the corners between the arms, %d to %d px out along each from the middle (from_px %s, length_px %s at the 480 reference), the same in every corner, clear of the arms and their edge, its own edge one pixel round it and never over the crosshair's (standing or sneaking)%s" % [lines_n, int(xc.from), int(xc.from) + int(xc.length) - 1, str(HM.get("from_px")), str(HM.get("length_px")), "" if faults.is_empty() else ": %s" % [faults]])
	if had_preset == null:
		Settings.erase("display.preset")
	else:
		Settings.set_value("display.preset", had_preset)
	if had_switch == null:
		Settings.erase("hud.reticle")
	else:
		Settings.set_value("hud.reticle", had_switch)
	Display.apply()


## A box of solid ground under `parent`: `size`, centred at `at`.
func _box(parent: Node, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	body.position = at
	parent.add_child(body)
	return body


## A walk with `keys` held for `n` frames: the lowest your feet went.
func _walk(p: CrawlerPlayer, keys: Array, n: int) -> float:
	for k in keys:
		Input.action_press(k)
	var low := p.global_position.y
	for i in n:
		await process_frame
		low = minf(low, p.global_position.y)
	for k in keys:
		Input.action_release(k)
	return low


## The eye height each frame for `n` frames.
func _eye_track(p: CrawlerPlayer, n: int) -> Array:
	var out: Array = []
	for i in n:
		await process_frame
		out.append(p._spring.position.y)
	return out


## The eye track's verdict: monotonic toward `to` (falling if `down`), its
## first frame at `to` (s, -1 never) and its biggest one-frame step (m).
func _eased(track: Array, from: float, to: float, down: bool) -> Dictionary:
	var mono := true
	var prev := from
	var at := -1.0
	var big := 0.0
	for i in track.size():
		var y: float = track[i]
		if (down and y > prev + 1e-6) or (not down and y < prev - 1e-6):
			mono = false
		big = maxf(big, absf(y - prev))
		if at < 0.0 and absf(y - to) < 1e-4:
			at = (i + 1) / 60.0
		prev = y
	return {"mono": mono, "at": at, "big": big}


## The sneak's dashes on a frame `f` at scale `k` (Reticle.dash_cells):
## what is wrong with them, or nothing. The crosshair's own two level arms
## and no up or down arm; their dark edge one pixel round them, each pixel
## once.
func _dash_faults(f: Vector2i, k: float) -> Array:
	var dc := Reticle.dash_cells(f, k)
	var cl := Reticle.cells(f, k)
	var bad: Array = []
	var arms: Array = dc.arms
	if arms.size() != 2 or arms[0] != cl.arms[0] or arms[1] != cl.arms[1]:
		bad.append("not the crosshair's two level arms: %s" % [arms])
	var px := {}
	for a: Rect2i in arms:
		if a.size.x <= a.size.y:
			bad.append("an arm not level: %s" % a)
		for y in range(a.position.y, a.end.y):
			for x in range(a.position.x, a.end.x):
				px[Vector2i(x, y)] = true
	var edge := {}
	var twice := 0
	for e: Rect2i in dc.edge:
		for y in range(e.position.y, e.end.y):
			for x in range(e.position.x, e.end.x):
				var q := Vector2i(x, y)
				if px.has(q) or edge.has(q):
					twice += 1
				edge[q] = true
	var want_edge := {}
	for p: Vector2i in px:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var q := p + Vector2i(dx, dy)
				if not px.has(q):
					want_edge[q] = true
	if twice > 0 or edge.size() != want_edge.size():
		bad.append("edge %d px (want %d), %d over a dash or twice" % [edge.size(), want_edge.size(), twice])
	return bad


## The hit's X on a frame `f` at scale `k` over the crosshair's `under`
## shape (Reticle.x_cells): what is wrong with it, or nothing. Four
## diagonals, one in each corner between the arms, from_px to from_px +
## length_px - 1 pixels out from the arms' band along each, as wide as the
## arms, the same in every corner; none of it on the arms' band, an arm or
## the arms' dark edge; its own dark edge one pixel round it, each pixel
## once, never over what the shape under it draws.
func _x_faults(f: Vector2i, k: float, under: String) -> Array:
	var HM: Dictionary = Tuning.section("hud", "reticle").get("hit_marker", {})
	var xc := Reticle.x_cells(f, k, under)
	var cl := Reticle.cells(f, k)
	var bad: Array = []
	var from := maxi(roundi(float(HM.get("from_px", 3)) * k), 1)
	var length := maxi(roundi(float(HM.get("length_px", 4)) * k), 1)
	if int(xc.from) != from or int(xc.length) != length:
		bad.append("from %d, length %d (want %d, %d)" % [xc.from, xc.length, from, length])
	var w := int(cl.width)
	var px := {}
	for r: Rect2i in xc.x:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				px[Vector2i(x, y)] = true
	if px.size() != 4 * length * w:
		bad.append("%d px (want %d)" % [px.size(), 4 * length * w])
	var box := Rect2i()
	var drawn := {}
	for i in (cl.arms as Array).size():
		var a: Rect2i = cl.arms[i]
		box = a if i == 0 else box.merge(a)
	var shape_rects: Array = cl.arms + cl.edge
	if under == "dashes":
		var dc := Reticle.dash_cells(f, k)
		shape_rects = dc.arms + dc.edge
	for r: Rect2i in shape_rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				drawn[Vector2i(x, y)] = true
	var all_cross := {}
	for r: Rect2i in cl.arms + cl.edge:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				all_cross[Vector2i(x, y)] = true
	var lo: Vector2i = (cl.middle as Vector2i) - Vector2i(w / 2, w / 2)
	var hi := lo + Vector2i(w - 1, w - 1)
	for p: Vector2i in px:
		if not px.has(Vector2i(box.position.x + box.end.x - 1 - p.x, p.y)) or not px.has(Vector2i(p.x, box.position.y + box.end.y - 1 - p.y)):
			bad.append("not the same in every corner")
			break
	for p: Vector2i in px:
		if (p.x >= lo.x and p.x <= hi.x) or (p.y >= lo.y and p.y <= hi.y):
			bad.append("on the arms' band at %s" % p)
			break
		if all_cross.has(p):
			bad.append("on an arm or its edge at %s" % p)
			break
		if p.x > hi.x and p.y > hi.y:
			var dx := p.x - hi.x
			var dy := p.y - hi.y
			if dx < from or dx > from + length - 1 or dy - dx < 0 or dy - dx > w - 1:
				bad.append("off its diagonal at %s" % p)
				break
	var edge := {}
	var twice := 0
	for e: Rect2i in xc.edge:
		for y in range(e.position.y, e.end.y):
			for x in range(e.position.x, e.end.x):
				var q := Vector2i(x, y)
				if px.has(q) or edge.has(q) or drawn.has(q):
					twice += 1
				edge[q] = true
	var want_edge := {}
	for p: Vector2i in px:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var q := p + Vector2i(dx, dy)
				if not px.has(q) and not drawn.has(q):
					want_edge[q] = true
	if twice > 0 or edge.size() != want_edge.size():
		bad.append("edge %d px (want %d), %d over the X, the crosshair or twice" % [edge.size(), want_edge.size(), twice])
	return bad


## The sneak's ring on a frame `f` at scale `k` (Reticle.ring_cells): what
## is wrong with it, or nothing. One clean pixel line `want_r` out from the
## arms' crossing, the same on every side, the middle clear, its dark edge
## one pixel round it inside and out.
func _ring_faults(f: Vector2i, k: float, want_r: int) -> Array:
	var rc := Reticle.ring_cells(f, k)
	var bad: Array = []
	var px := {}
	var box := Rect2i()
	var first := true
	for r: Rect2i in rc.ring:
		box = r if first else box.merge(r)
		first = false
		for x in range(r.position.x, r.end.x):
			px[Vector2i(x, r.position.y)] = true
	var w := int(rc.width)
	if int(rc.radius) != want_r or box.size != Vector2i.ONE * (2 * want_r + w):
		bad.append("radius %d, box %s (want %d, %d across)" % [rc.radius, box.size, want_r, 2 * want_r + w])
	for p: Vector2i in px:
		if not px.has(Vector2i(box.position.x + box.end.x - 1 - p.x, p.y)) or not px.has(Vector2i(p.x, box.position.y + box.end.y - 1 - p.y)) or not px.has(Vector2i(p.y - box.position.y + box.position.x, p.x - box.position.x + box.position.y)):
			bad.append("not the same on every side")
			break
	var off := Vector2(box.position + box.end) * 0.5 - Vector2(f) * 0.5
	if absf(off.x) > 0.5 or absf(off.y) > 0.5:
		bad.append("%s off the frame's centre" % off)
	var m: Vector2i = rc.middle
	if px.has(m):
		bad.append("the middle not clear")
	# One pixel line: no 2x2 block of ring pixels anywhere (w 1).
	if w == 1:
		for p: Vector2i in px:
			if px.has(p + Vector2i.RIGHT) and px.has(p + Vector2i.DOWN) and px.has(p + Vector2i.ONE):
				bad.append("a 2x2 lump at %s" % p)
				break
	var edge := {}
	for e: Rect2i in rc.edge:
		for x in range(e.position.x, e.end.x):
			var q := Vector2i(x, e.position.y)
			if px.has(q) or edge.has(q):
				bad.append("edge over the ring or twice at %s" % q)
			edge[q] = true
	var want_edge := {}
	for p: Vector2i in px:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var q := p + Vector2i(dx, dy)
				if not px.has(q):
					want_edge[q] = true
	if edge.size() != want_edge.size():
		bad.append("edge %d px, want %d" % [edge.size(), want_edge.size()])
	return bad


## Sneaking (design §FC.1, stealth.json sneak).
func _sneak(main: CrawlerMain) -> void:
	var p := main.player
	var sn: Dictionary = CrawlerPlayer.SNEAK
	var ease := float(sn.get("camera_ease_s", 0.18))
	var share := float(sn.get("footstep_volume", 0.25))
	var look: Dictionary = sn.get("reticle", {})
	var dim := float(look.get("dim", 0.75))
	for k in ["move_forward", "sprint", "crouch"]:
		Input.action_release(k)
	# A platform of its own, far below the tomb: its top at y0, its lip at
	# x = 10 over a floor 2 m down.
	var y0 := -800.0
	var lip := 10.0
	var plat := _box(main, Vector3(20.0, 2.0, 20.0), Vector3(0.0, y0 - 1.0, 0.0))
	var below := _box(main, Vector3(200.0, 2.0, 200.0), Vector3(0.0, y0 - 3.0, 0.0))
	p.spawn_flat(Vector3(-4.0, y0, -6.0), 0.0, 0.0)
	await _frames(20)
	var stand_eye := PlanetPlayer.EYE_Y
	var crouch_eye := PlanetPlayer.CROUCH_EYE_Y
	var r := main.reticle
	var shape := func() -> String: return r.shape_now() if r != null else "none"
	var alpha := func() -> float: return r.alpha_now() if r != null else 0.0
	ok(not p.crouching and absf(p._spring.position.y - stand_eye) < 1e-4 and shape.call() == "cross" and is_equal_approx(alpha.call(), 1.0), "standing: the eye at %.2f m and the crosshair whole (%s)" % [stand_eye, shape.call()])
	# Down, and the collision at once.
	Input.action_press("crouch")
	var track := await _eye_track(p, 18)
	var dn := _eased(track, stand_eye, crouch_eye, true)
	ok(dn.mono and float(dn.at) > 0.0 and float(dn.at) <= ease + 1.0 / 60.0 + 1e-6, "Shift: over the first 0.3 s the eye eases down, never back up, and is at %.2f m by %.3f s, the first tick past camera_ease_s %.2f" % [crouch_eye, dn.at, ease])
	ok(float(dn.big) < (stand_eye - crouch_eye) * 0.25, "never a snap: the biggest one-frame step %.3f m of the %.2f m" % [dn.big, stand_eye - crouch_eye])
	ok(p.crouching and is_equal_approx(p._shape.height, PlanetPlayer.CROUCH_HEIGHT), "the collision crouches at once (%.2f m tall)" % p._shape.height)
	var want_shape := str(look.get("shape", "dashes"))
	ok(shape.call() == want_shape and is_equal_approx(alpha.call(), dim) and r._key.size() > 1 and bool(r._key[1]), "crouched, the crosshair takes its sneak look, %s (%s), dimmed to %.2f" % [want_shape, "the up and down arms gone, the two level dashes left" if want_shape == "dashes" else "stealth.json sneak.reticle.shape", alpha.call()])
	# Up again.
	Input.action_release("crouch")
	track = await _eye_track(p, 18)
	var rise := _eased(track, crouch_eye, stand_eye, false)
	ok(rise.mono and float(rise.at) > 0.0 and float(rise.at) <= ease + 1.0 / 60.0 + 1e-6 and float(rise.big) < (stand_eye - crouch_eye) * 0.25, "let go: the eye eases back up, never back down, and is at %.2f m by %.3f s (biggest step %.3f m)" % [stand_eye, rise.at, rise.big])
	ok(shape.call() == "cross" and is_equal_approx(alpha.call(), 1.0), "standing again, the crosshair is whole")
	# The ring's pixels at 480 and 270 lines (ring_px at the 480 reference).
	var ref := float(Tuning.section("hud", "text").get("ref_height_px", 480))
	for lines_n in [480, 270]:
		var k := float(lines_n) / ref
		# The 16:9 frame of that many lines (Display.internal_size).
		var fw := int(round(lines_n * 16.0 / 9.0))
		var f := Vector2i(fw + (fw & 1), lines_n)
		var want_r := maxi(roundi(float(look.get("ring_px", 4)) * k), maxi(roundi(float(Tuning.section("hud", "reticle").get("thickness_px", 1)) * k), 1) + 1)
		var faults := _ring_faults(f, k, want_r)
		ok(faults.is_empty(), "%d lines: the ring (shape ring, the first look) is one clean pixel line %d px out from the crosshair's middle, the same on every side, the middle clear, its dark edge one pixel round it%s" % [lines_n, want_r, "" if faults.is_empty() else ": %s" % [faults]])
		var dfaults := _dash_faults(f, k)
		ok(dfaults.is_empty(), "%d lines: the dashes (shape dashes) are the crosshair's own two level arms and nothing else, on their dark edge one pixel round them, each pixel once%s" % [lines_n, "" if dfaults.is_empty() else ": %s" % [dfaults]])
	# Under a low ceiling the view stays down.
	Input.action_press("crouch")
	await _frames(20)
	var lid := _box(main, Vector3(3.0, 0.2, 3.0), p.global_position + Vector3(0.0, 1.1, 0.0))
	await _frames(2)
	Input.action_release("crouch")
	await _frames(30)
	ok(p.crouching and absf(p._spring.position.y - crouch_eye) < 1e-4, "under a ceiling 1.0 m up, letting go of Shift keeps you down: the eye stays at %.2f m, under it" % p._spring.position.y)
	lid.queue_free()
	await _frames(int(ease * 60.0) + 4)
	ok(not p.crouching and absf(p._spring.position.y - stand_eye) < 1e-4, "out from under it you stand and the eye rises to %.2f m" % p._spring.position.y)
	# Quieter feet.
	var fs := p.footsteps
	_place_facing(p, Vector3(-8.0, y0, 3.0), Vector3(0.0, y0, 3.0))
	await _frames(10)
	var n0 := fs._count
	await _walk(p, ["move_forward"], 120)
	var walk_db := fs.last_db
	var n1 := fs._count
	Input.action_press("crouch")
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(170)
	var noise := p.noise_level
	Input.action_release("move_forward")
	Input.action_release("crouch")
	var sneak_db := fs.last_db
	var n2 := fs._count
	var ratio := db_to_linear(sneak_db - walk_db)
	ok(n1 - n0 >= 4 and n2 - n1 >= 3 and absf(ratio - share) < 0.001, "a crouched step plays at %.3f of a walking step's volume (%.1f dB against %.1f; footstep_volume %.2f; %d and %d steps)" % [ratio, sneak_db, walk_db, share, n1 - n0, n2 - n1])
	ok(is_equal_approx(noise, 0.1), "crouched, the noise you make stays a tenth (noise_level %.2f, as built)" % noise)
	var plain := Footsteps.new()
	ok(is_equal_approx(plain.base_db("crouch"), float(Footsteps.VOLUME_DB.crouch)), "the open world's crouched step keeps its own volume (%.0f dB)" % plain.base_db("crouch"))
	plain.free()
	await _frames(int(ease * 60.0) + 4)
	# The ledge guard: straight at the lip.
	_place_facing(p, Vector3(lip - 2.5, y0, 0.0), Vector3(lip, y0, 0.0))
	await _frames(10)
	Input.action_press("crouch")
	await _frames(20)
	var low := await _walk(p, ["move_forward"], 600)
	var short := lip - p.global_position.x
	ok(low > y0 - 0.1 and p.is_on_floor() and short >= 0.0 and short <= 0.35, "a crouched walk straight at a 2 m drop for 10 s stops %.3f m short of the lip and never falls (lowest %.2f m)" % [short, low - y0])
	Input.action_release("crouch")
	low = await _walk(p, ["move_forward"], 90)
	ok(low < y0 - 1.5, "let go of Shift and you step off (down %.1f m)" % (y0 - low))
	# Diagonally along it.
	_place_facing(p, Vector3(lip - 2.5, y0, -5.0), Vector3(lip - 1.5, y0, -4.0))
	await _frames(10)
	Input.action_press("crouch")
	await _frames(20)
	var z0 := p.global_position.z
	low = await _walk(p, ["move_forward"], 600)
	Input.action_release("crouch")
	short = lip - p.global_position.x
	ok(low > y0 - 0.1 and p.is_on_floor() and short >= 0.0 and short <= 0.35 and p.global_position.z - z0 > 4.0, "the same walk at 45 degrees slides along the lip (%.1f m along it, %.3f m short of it) and never falls" % [p.global_position.z - z0, short])
	await _frames(int(ease * 60.0) + 4)
	# Standing, you go over.
	_place_facing(p, Vector3(lip - 2.5, y0, 5.0), Vector3(lip, y0, 5.0))
	await _frames(10)
	low = await _walk(p, ["move_forward"], 120)
	ok(low < y0 - 1.5, "the same walk standing goes over the lip and falls (down %.1f m)" % (y0 - low))
	plat.queue_free()
	below.queue_free()
	# The tomb's own floor never trips it: crouched through every door,
	# and down every flight of stairs.
	var lay := main.lay
	var holds0 := p.ledge_holds
	var held: Array = []
	var gone: Array = []
	var doors_n := 0
	Input.action_press("crouch")
	for d in lay.doors:
		# Not the way out's opening (§EX.5): through it you walk out of the
		# tomb.
		if int(d.b) < 0:
			continue
		doors_n += 1
		var n2d: Vector2 = d.n
		var q: Vector2 = (d.p as Vector2) - n2d * 1.3
		var hit := _ray(Vector3(q.x, float(d.y) + 1.6, q.y), Vector3(q.x, float(d.y) - 2.0, q.y), [p.get_rid()])
		if hit.is_empty():
			continue
		var from := Vector3(q.x, (hit.position as Vector3).y, q.y)
		_place_facing(p, from, from + Vector3(n2d.x, 0.0, n2d.y))
		await _frames(8)
		var h0 := p.ledge_holds
		await _walk(p, ["move_forward"], 230)
		gone.append(Vector2(p.global_position.x - from.x, p.global_position.z - from.z).dot(n2d))
		if p.ledge_holds != h0:
			held.append("door %d (pieces %d-%d)" % [d.id, d.a, d.b])
	var flights := 0
	var drops: Array = []
	for pc in lay.pieces:
		if str(pc.kind) != "stair":
			continue
		flights += 1
		# Down every flight from its top: the way out's climbs (§EX.5), so
		# it is walked from its far end back.
		var up := float(pc.y1) > float(pc.y0)
		var along := float(pc.len) - 0.5 if up else 0.5
		var dir: Vector2 = -(pc.dir as Vector2) if up else (pc.dir as Vector2)
		var a: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along
		var top := Vector3(a.x, Delves.floor_of(pc, along), a.y)
		_place_facing(p, top, top + Vector3(dir.x, 0.0, dir.y))
		await _frames(8)
		var h1 := p.ledge_holds
		var y_top := p.global_position.y
		await _walk(p, ["move_forward"], int((float(pc.len) - 1.0) / PlanetPlayer.CROUCH_SPEED * 60.0) + 30)
		drops.append([y_top - p.global_position.y, absf(float(pc.y0) - float(pc.y1))])
		if p.ledge_holds != h1:
			held.append("stair %d" % pc.id)
	Input.action_release("crouch")
	gone.sort()
	var down_ok := true
	for dr in drops:
		if float(dr[0]) < float(dr[1]) * 0.6:
			down_ok = false
	ok(held.is_empty() and gone.size() >= doors_n - 2, "crouched through all %d doors of the tomb (median %.1f m on through), the guard never holds you%s" % [gone.size(), gone[gone.size() / 2] if not gone.is_empty() else 0.0, "" if held.is_empty() else ": held at " + ", ".join(held)])
	if flights == 0:
		print("  no flights of stairs in this tomb (seeds 1 and 42 have them)")
	else:
		var went: Array = []
		for dr in drops:
			went.append("%.2f of %.1f m" % [dr[0], dr[1]])
		ok(down_ok, "crouched down all %d flights of stairs, all the way down (%s)" % [flights, ", ".join(went)])
	print("  the ledge guard held %d ticks at the test platform's lip, %d in the tomb" % [holds0, p.ledge_holds - holds0])
	await _frames(int(ease * 60.0) + 4)


## The way out in the scene (design §EX.5; WayOut): faint daylight in the
## opening by the world's clock, seen from the bottom of the flight.
func _way_out(main: CrawlerMain) -> void:
	var lay := main.lay
	var wo := main.way_out
	ok(wo != null and wo.openings.size() == (lay.exits as Array).size() and wo.openings.size() >= 1, "the way out is built: %d opening with daylight in it" % (wo.openings.size() if wo != null else 0))
	if wo == null or wo.openings.is_empty():
		return
	var o: Dictionary = wo.openings[0]
	var ex: Dictionary = o.exit
	var sp: SpotLight3D = o.light
	var mat: StandardMaterial3D = o.mat
	var w := main.world
	var keep: float = w.days
	# Noon and midnight by the sun (the clock is warped: Vents); two
	# frames, as the way out reads the clock in its own frame's _process.
	w.days = Vents.days_at_solar_hour(13.0, 12.0)
	await process_frame
	await process_frame
	var day_c := sp.light_color
	var day_e := sp.light_energy
	var day_sheet := mat.albedo_color
	var shaft_e := 0.0
	for sh in main.vents.shafts:
		shaft_e = maxf(shaft_e, (sh.light as SpotLight3D).light_energy)
	w.days = Vents.days_at_solar_hour(13.0, 0.0)
	await process_frame
	await process_frame
	var night_c := sp.light_color
	var night_e := sp.light_energy
	var night_sheet := mat.albedo_color
	w.days = keep
	await process_frame
	print("  the way out's daylight: day #%s %.2f (the opening #%s), night #%s %.2f (#%s); the brightest shaft by day %.2f" % [day_c.to_html(false), day_e, day_sheet.to_html(false), night_c.to_html(false), night_e, night_sheet.to_html(false), shaft_e])
	ok(day_c.b > day_c.r and night_c.b > night_c.r and day_sheet.b > day_sheet.r and night_sheet.b > night_sheet.r, "its daylight is the shafts' cool blue (§EV.2), by day and by night")
	ok(day_e > night_e * 2.0 and day_sheet.get_luminance() > night_sheet.get_luminance() * 2.0, "it follows the world's clock: day %.2f, night %.2f" % [day_e, night_e])
	ok(day_e < shaft_e and maxf(day_sheet.r, maxf(day_sheet.g, day_sheet.b)) < 1.0, "faint, never a spotlight: its wash (%.2f) is weaker than a shaft's daylight (%.2f), the opening never blown white" % [day_e, shaft_e])
	# Seen from below: nothing between your eye at the foot of the flight and
	# the opening's daylight under its lintel.
	var stair: Dictionary = lay.pieces[int(ex.stair)]
	var foot: Vector2 = (stair.c as Vector2) + (stair.dir as Vector2) * 0.4
	var eye := Vector3(foot.x, float(stair.y0) + CrawlerPlayer.EYE_Y, foot.y)
	var n: Vector3 = ex.n
	var aim := (ex.p as Vector3) + Vector3.UP * (float(ex.h) - 0.3) + n * 0.4
	var hit := _ray(eye, aim, [main.player.get_rid()])
	ok(hit.is_empty(), "from the foot of the flight, looking up %.1f m over %.1f m, nothing stands between your eye and the opening's daylight%s" % [aim.y - eye.y, Vector2(aim.x - eye.x, aim.z - eye.z).length(), "" if hit.is_empty() else (" (hit at %s)" % str(hit.position))])
	# Faint from far off (Mike, 7 Oct; exit.glow near_m, far_m, far_share):
	# the opening's sheet shows all its glow within near_m of your eye,
	# easing down to far_share of it by far_m; by day as by night.
	var gl: Dictionary = WayOut.G
	var near_m := float(gl.get("near_m", 8.0))
	var far_m := float(gl.get("far_m", 30.0))
	var far_share := float(gl.get("far_share", 0.55))
	var mid_k := WayOut.far_fade((near_m + far_m) * 0.5)
	ok(is_equal_approx(WayOut.far_fade(near_m * 0.5), 1.0) and is_equal_approx(WayOut.far_fade(far_m + 5.0), far_share) and mid_k < 1.0 and mid_k > far_share, "faint from far off: all its glow within %.0f m, %.2f of it halfway out, %.2f of it past %.0f m (exit.glow near_m, far_share, far_m)" % [near_m, mid_k, far_share, far_m])
	var p := main.player
	var shares: Array = []
	for when in [Vents.days_at_solar_hour(13.0, 12.0), Vents.days_at_solar_hour(13.0, 0.0)]:
		w.days = when
		p.spawn_flat((ex.p as Vector3) - n * 2.0, atan2(-n.x, -n.z), 0.0)
		await process_frame
		await process_frame
		var near_share := wo.seen_share
		var near_l := mat.albedo_color.get_luminance()
		var wk: Array = lay.wake
		p.spawn_flat(wk[0], float(wk[1]), 0.0)
		await process_frame
		await process_frame
		var far_d := (ex.p as Vector3).distance_to(p.camera().global_position)
		shares.append([near_share, wo.seen_share, far_d, WayOut.far_fade(far_d), mat.albedo_color.get_luminance() / maxf(near_l, 1e-6)])
	w.days = keep
	await process_frame
	var fade_ok := true
	for sh in shares:
		if not is_equal_approx(float(sh[0]), 1.0) or absf(float(sh[1]) - float(sh[3])) > 0.01 or absf(float(sh[4]) - float(sh[1])) > 0.02 or (float(sh[2]) > near_m + 1.0 and float(sh[1]) >= 1.0):
			fade_ok = false
	print("  the way out's sheet from the landing and from the wake spot, by day and by night: %s" % [shares])
	ok(fade_ok and shares.size() == 2, "on the landing the opening shows all its glow; from the wake spot %.0f m off it shows %.2f of it, by day and by night" % [float(shares[0][2]), float(shares[0][1])])


## Stepping into the opening (design §EX.5's stand-in, exit.stand_in): the
## fade, the next tomb from a new seed, you on the mat by its lit hearth
## carrying the torch you carried, lit or not as it was, and the log's line.
func _stand_in(main: CrawlerMain) -> void:
	var p := main.player
	var t := p.torch
	var si: Dictionary = TombKit.EXIT.get("stand_in", {})
	for lit_case in [true, false]:
		var ex: Dictionary = main.lay.exits[0]
		var old_seed := main.seed_value
		if not p.inventory.has_kind("torch"):
			p.inventory.add(Inventory.make("torch"))
		p.weapon = "torch"
		if lit_case and not t.lit():
			t.light()
		elif not lit_case and t.lit():
			t.put_out("stowed")
		var n: Vector3 = ex.n
		p.spawn_flat((ex.p as Vector3) - n * 1.3, atan2(-n.x, -n.z), 0.0)
		await _frames(5)
		var pack := _pack(p)
		Input.action_press("move_forward")
		var began := false
		for i in 240:
			await physics_frame
			if main.leaving:
				began = true
				break
		Input.action_release("move_forward")
		ok(began, "walking into the opening begins the way out (torch %s)" % ("lit" if lit_case else "unlit"))
		if not began:
			return
		var line := str(GameLog.entries[-1].get("text", ""))
		var t0 := Time.get_ticks_msec()
		for i in 3000:
			await process_frame
			if not main.leaving:
				break
		var took := Time.get_ticks_msec() - t0
		var piece := TombKit.piece_at(main.lay, p.global_position)
		ok(not main.leaving and main.seed_value != old_seed and main.seed_value == CrawlerMain.next_seed(old_seed) and int(main.lay.seed) == main.seed_value, "it fades to the next tomb from a new seed (%d after %d; %d ms)" % [main.seed_value, old_seed, took])
		ok(piece == 0 and absf(p.global_position.y) < 0.3 and (p.global_position - (main.lay.wake[0] as Vector3)).length() < 0.6, "you arrive in its hearth room, on the mat (%s)" % str(p.global_position.snapped(Vector3.ONE * 0.01)))
		ok(FireStore.is_lit(main.fires.hearth) and main.fires.lit_count() == 0, "its hearth lit, its lights below cold")
		ok(t.in_hand() and t.lit() == lit_case and _pack(p) == pack, "the torch you carried, %s as it was, and nothing else changed" % ("lit" if lit_case else "unlit"))
		ok(line == str(si.get("log", "")) and line != "", "the log says so: \"%s\"" % line)
		await _frames(int(float(si.get("fade_s", 2.0)) * 60.0) + 10)
		ok(main.baked and main.rescuer != null and is_instance_valid(main.rescuer) and not main._fade.visible, "its rescuer at its hearth, the dark lifted")


## What you carry, kind by kind (the stand-in changes none of it).
func _pack(p: CrawlerPlayer) -> String:
	var kinds: Array = []
	for it in p.inventory.carried:
		kinds.append(str((it as Dictionary).get("kind", "")) if it is Dictionary else "-")
	return ",".join(kinds)


# --- One ruin, one stone (design §EX.1, §EX.3) ------------------------------------

const STYLE_SEEDS := [1, 7, 42]
## The crawler's scripts may hold these colours of their own, none of them
## built stone: the heart's ochre (paint), the checks' poison, the charred
## logs, the torch bundle's wood, tips and cord, an airway's void and dust,
## the waking fade, a sprite's clear background, RuinStyle's grey for a
## theme with no stone at all (missing data).
## The scripts that lay the tomb's stone (TombBuild, the masonry it cuts,
## the style, the fires' holders, the layout): the colour search looks in
## these. Every crawler script is searched for the general palette by name.
const STONE_SCRIPTS := ["tomb_build.gd", "fitted_stone.gd", "ruin_style.gd", "crawler_fires.gd", "tomb_kit.gd"]
const OWN_COLOURS := ["Color(0.62, 0.3, 0.14)", "Color(1.0, 0.0, 1.0)", "Color(0.09, 0.07, 0.06)", "Color(0.36, 0.25, 0.14)",
	"Color(0.1, 0.08, 0.06)", "Color(0.5, 0.42, 0.28)", "Color(0.01, 0.012, 0.03)", "Color(0.58, 0.6, 0.66)",
	"Color(0.0, 0.0, 0.01)", "Color(0, 0, 0, 0)", "Color(0.5, 0.5, 0.5)"]


## Is `c` the poison (magenta) or anything shaded from it?
static func _poisoned(c: Color) -> bool:
	return c.r > c.g * 2.5 + 0.05 and c.b > c.g * 2.5 + 0.05 and absf(c.r - c.b) < 0.3


## One ruin, one stone (design §EX.1, §EX.3; masonry.json styles, RuinStyle),
## on pure builds of seeds 1, 7 and 42, built as cut (TombBuild.bare: no
## joint or contact shade, ochre, soot, moss or drift) with RuinBuilder's
## palette poisoned: every vertex is the style's stone within tint +-
## spread, another material (bone, clay, gold, reed, hide) or overgrowth,
## and none shows the poison; the crawler's scripts name no general palette,
## and the ones that lay stone no stone colour of their own (grep); every
## door is narrower at the top by doors.top_share; the hearth room stands on
## four pillars round the hearth, its shaft open between them; no ceiling
## spans past max_span_m unsupported; the boss's hole keeps off the pillars;
## triangles in every room inside the 45,000 budget.
func _style_kit() -> void:
	var th := "tomb"
	ok(RuinStyle.style_name(th) == "andean_tomb" and str(RuinStyle.val("walls.preset", "", th)) == str((FittedStone.M.get("by_theme", {}) as Dictionary).get(th, "")), "the tomb is built in its style, %s; the style's wall preset is by_theme's (%s)" % [RuinStyle.style_name(th), FittedStone.preset_name()])
	var tint := RuinStyle.tint(th)
	var spread := RuinStyle.spread(th)
	var own := str(((Tuning.table("crawler").get("themes", {}) as Dictionary).get(th, {}) as Dictionary).get("stone", ""))
	ok(own.begins_with("#") and tint.is_equal_approx(Color(own)), "one stone: the style's tint is the theme's own stone (crawler.json themes.tomb.stone #%s), each stone within %.2f of it" % [tint.to_html(false), spread])
	var top_share := RuinStyle.num("doors.top_share", 0.85, th)
	var max_span := RuinStyle.num("max_span_m", 6.0, th)
	var untagged := 0
	var poisoned := 0
	var outside := 0
	var stone_v := 0
	var other_v := 0
	var grown_v := 0
	var lo := Color(1, 1, 1)
	var hi := Color(0, 0, 0)
	var doors_n := 0
	var doors_bad := 0
	var spans_bad := 0
	var worst_slab := 0.0
	var worst_beam := 0.0
	var pillared := 0
	var rooms_n := 0
	var hearth_ok := true
	var per_room: Array = []
	var side_m := RuinStyle.num("pillars.side_m", 0.6, th)
	var lair_gap := INF
	var lair_rooms := 0
	TombBuild.bare = true
	TombBuild.poison = true
	for s in STYLE_SEEDS:
		var lay := TombKit.layout(int(s))
		var data := TombBuild.build(lay)
		var v: PackedVector3Array = data.v
		var c: PackedColorArray = data.c
		var m: PackedVector2Array = data.m
		var runs: Array = data.tags
		var ri := 0
		var tag := TombBuild.T_NONE
		for i in v.size():
			while ri < runs.size() and int(runs[ri][0]) <= i:
				tag = int(runs[ri][1])
				ri += 1
			var col := c[i]
			if _poisoned(col):
				poisoned += 1
			var kind := int(round(m[i].x))
			if kind == RuinBuilder.LEAF_M or kind == FittedStone.DUST_M:
				grown_v += 1
				continue
			if tag == TombBuild.T_NONE:
				untagged += 1
			elif tag == TombBuild.T_OTHER:
				other_v += 1
			else:
				stone_v += 1
				lo = Color(minf(lo.r, col.r), minf(lo.g, col.g), minf(lo.b, col.b))
				hi = Color(maxf(hi.r, col.r), maxf(hi.g, col.g), maxf(hi.b, col.b))
				if absf(col.r - tint.r) > spread + 1e-3 or absf(col.g - tint.g) > spread + 1e-3 or absf(col.b - tint.b) > spread + 1e-3:
					outside += 1
					if outside <= 3:
						print("  seed %d vertex %d at %s: #%s outside the stone" % [s, i, str(v[i]), col.to_html(false)])
		# Doors: the trapezoid, narrower at the top by top_share.
		for d in data.doors:
			doors_n += 1
			if absf(float(d.top) / maxf(float(d.foot), 0.01) - top_share) > 0.005:
				doors_bad += 1
		# The ceilings' spans and the hearth room's pillars.
		for pc in lay.pieces:
			if str(pc.kind) != "room":
				continue
			rooms_n += 1
			var pl: Dictionary = data.plans[int(pc.id)]
			var sp: Dictionary = pl.get("spans", {})
			worst_slab = maxf(worst_slab, float(sp.get("slab", 99.0)))
			worst_beam = maxf(worst_beam, float(sp.get("beam", 0.0)))
			if float(sp.get("slab", 99.0)) > max_span + 1e-3 or float(sp.get("beam", 0.0)) > max_span + 1e-3:
				spans_bad += 1
				print("  seed %d room %d (%s, %.1f x %.1f): slabs span %.2f m, beams %.2f m" % [s, pc.id, pc.room_kind, float(pc.len), 2.0 * float(pc.half), float(sp.get("slab", 99.0)), float(sp.get("beam", 0.0))])
			if not (pl.pillars as Array).is_empty():
				pillared += 1
			if str(pc.room_kind) == "hearth":
				var why := _hearth_pillars(lay, pc, pl)
				if why != "":
					hearth_ok = false
					print("  seed %d hearth room: %s" % [s, why])
		# The boss's hole (queue 49) keeps off its room's pillars, as built.
		var gap := _lair_gap(lay, (data.plans.get(int((lay.get("lair", {}) as Dictionary).get("piece", -1)), {}) as Dictionary).get("pillars", []), side_m)
		if gap < INF:
			lair_rooms += 1
			lair_gap = minf(lair_gap, gap)
		# Triangles in each room (the tomb mesh inside its walls).
		for pc in lay.pieces:
			if str(pc.kind) != "room":
				continue
			var n := 0
			for i in range(0, v.size(), 3):
				var c3 := (v[i] + v[i + 1] + v[i + 2]) / 3.0
				var aa := Delves.along_across(pc, Vector2(c3.x, c3.z))
				if aa.x > -0.7 and aa.x < float(pc.len) + 0.7 and absf(aa.y) < float(pc.half) + 0.7 and c3.y > float(pc.y0) - 0.5 and c3.y < float(pc.y0) + float(pc.h) + 0.5:
					n += 1
			per_room.append(n)
	TombBuild.bare = false
	TombBuild.poison = false
	# And in 30 more layouts, the pillars as planned (TombBuild.pillars_for).
	for s in range(101, 131):
		var lay := TombKit.layout(s)
		var l: Dictionary = lay.get("lair", {})
		if l.is_empty():
			continue
		var pc: Dictionary = lay.pieces[int(l.piece)]
		var pts: Array = []
		for q: Vector2 in TombBuild.pillars_for(lay, pc):
			pts.append(Delves.along_across(pc, q))
		var gap := _lair_gap(lay, pts, side_m)
		if gap < INF:
			lair_rooms += 1
			lair_gap = minf(lair_gap, gap)
	print("  the stone as cut over seeds %s: %d stone vertices from #%s to #%s (tint #%s +- %.2f), %d of other materials, %d of moss, vines and drift" % [str(STYLE_SEEDS), stone_v, lo.to_html(false), hi.to_html(false), tint.to_html(false), spread, other_v, grown_v])
	ok(untagged == 0, "every vertex of the tomb is the style's stone or another material (%d untold)" % untagged)
	ok(stone_v > 100000 and outside == 0, "no vertex of the tomb's stone strays outside its tint +- spread before occlusion, ochre, soot, moss and drift (%d of %d)" % [outside, stone_v])
	ok(poisoned == 0, "no stone takes RuinBuilder's palette: with it poisoned, none of the tomb shows it (%d vertices)" % poisoned)
	var hits := _palette_grep()
	ok(hits.is_empty(), "the crawler's scripts name no general palette, and the ones that lay stone no stone colour of their own (grep: %s)" % ("none" if hits.is_empty() else ", ".join(hits)))
	ok(doors_n > 30 and doors_bad == 0, "every door is a trapezoid, its top %.2f of its foot (doors.top_share; %d doors, %d off)" % [top_share, doors_n, doors_bad])
	ok(hearth_ok, "the hearth room stands on four pillars round the hearth, the hearth, the mat, the bundle and the rescuer clear of them, its shaft open between them")
	ok(spans_bad == 0, "no room's ceiling spans past max_span_m (%.1f m) unsupported: slabs at most %.2f m, beams %.2f m; %d of %d rooms on pillars" % [max_span, worst_slab, worst_beam, pillared, rooms_n])
	ok(lair_rooms > 0 and lair_gap >= 0.75, "the boss's hole keeps off the pillars: its rim at least %.2f m from a pillar's base, room to pass (%d holes in rooms on pillars, seeds %s as built and 30 more layouts)" % [lair_gap, lair_rooms, str(STYLE_SEEDS)])
	per_room.sort()
	ok(not per_room.is_empty() and int(per_room[-1]) <= 45000, "triangles in a room inside the 45,000 budget: median %d, fewest %d, most %d (%d rooms)" % [per_room[per_room.size() / 2], per_room[0], per_room[-1], per_room.size()])


## How far the boss's hole's rim (its collision ring) stands from the
## nearest pillar's base (`pillars`: along/across in its room; a base as the
## circle round its corners), m; INF with no hole or no pillars.
func _lair_gap(lay: Dictionary, pillars: Array, side_m: float) -> float:
	var l: Dictionary = lay.get("lair", {})
	if l.is_empty() or pillars.is_empty():
		return INF
	var pc: Dictionary = lay.pieces[int(l.piece)]
	var c := Vector2((l.pos as Vector3).x, (l.pos as Vector3).z)
	var least := INF
	for q: Vector2 in pillars:
		least = minf(least, RuinBuilder._pp(pc, q.x, q.y).distance_to(c) - float(l.r) - 0.05 - side_m * 0.71)
	return least


## Why the hearth room's pillars are wrong ("" when they're right): four of
## them round the hearth, clear of the hearth, the mat, the bundle and the
## rescuer, the hearth's shaft between them and no pillar or beam across it.
func _hearth_pillars(lay: Dictionary, pc: Dictionary, pl: Dictionary) -> String:
	var pillars: Array = pl.get("pillars", [])
	if pillars.size() != 4:
		return "%d pillars" % pillars.size()
	var side := RuinStyle.num("pillars.side_m", 0.6)
	var bw := RuinStyle.num("pillars.beam_w_m", 0.5)
	var box := Rect2(pillars[0], Vector2.ZERO)
	for q: Vector2 in pillars:
		box = box.expand(q)
	var aa_of := func(p: Vector3) -> Vector2: return Delves.along_across(pc, Vector2(p.x, p.z))
	var hearth: Vector2 = aa_of.call(lay.hearth)
	if not box.grow(-0.5).has_point(hearth):
		return "the hearth is not between its pillars"
	# The mat by three points down its length (its half width and a hand
	# clear of a pillar's base), the rest by their middles.
	var w: Array = lay.wake
	var axis := Vector3(sin(float(w[1])), 0.0, cos(float(w[1])))
	var things: Array = [["the hearth", lay.hearth, 0.85], ["the bundle", lay.bundle, 0.45], ["the rescuer", (lay.rescuer as Array)[0], 0.5]]
	for k: float in [-0.7, 0.0, 0.7]:
		things.append(["the mat", (w[0] as Vector3) + axis * k, 0.6])
	var base := side * 0.5 + 0.08
	for th in things:
		var at: Vector2 = aa_of.call(th[1])
		for q: Vector2 in pillars:
			var near := Vector2(clampf(at.x, q.x - base, q.x + base), clampf(at.y, q.y - base, q.y + base))
			if near.distance_to(at) < float(th[2]):
				return "a pillar at %s crowds %s" % [str(q), th[0]]
	for vt in lay.vents:
		if int(vt.fire_index) != -1:
			continue
		var m: Vector2 = aa_of.call(vt.mouth)
		var r := float(vt.d) * 0.5
		var hole := Rect2(m - Vector2(r, r), Vector2(2.0 * r, 2.0 * r))
		if not box.has_point(m):
			return "the shaft is not between the pillars"
		for q: Vector2 in pillars:
			if Rect2(q - Vector2(side, side) * 0.5, Vector2(side, side)).intersects(hole):
				return "a pillar stands under the shaft"
		var ax := int(pl.s_axis)
		for bm in pl.beams:
			var br := Rect2(float(bm[0]) - bw * 0.5, float(bm[1]), bw, float(bm[2]) - float(bm[1])) if ax == 0 else Rect2(float(bm[1]), float(bm[0]) - bw * 0.5, float(bm[2]) - float(bm[1]), bw)
			if br.intersects(hole):
				return "a beam crosses the shaft"
	return ""


## The crawler's scripts: any read of RuinBuilder's palette, any of its
## general palettes by name, any numeric colour that isn't one of the
## known non-stone ones (OWN_COLOURS). ["file:line"...].
func _palette_grep() -> Array:
	var hits: Array = []
	var re := RegEx.new()
	re.compile("Color\\([0-9][^)]*\\)")
	var dir := DirAccess.open("res://scripts/crawler")
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var ln := 0
		for line in FileAccess.get_file_as_string("res://scripts/crawler/" + f).split("\n"):
			ln += 1
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			if code.contains("palette[") or code.contains("palette.size") or code.contains("STONES") or code.contains("SANDSTONE") or code.contains("LIMESTONE"):
				hits.append("%s:%d" % [f, ln])
				continue
			if not f in STONE_SCRIPTS:
				continue
			for mt in re.search_all(code):
				if not mt.get_string() in OWN_COLOURS:
					hits.append("%s:%d %s" % [f, ln, mt.get_string()])
	return hits


## The door frames in the built tomb (design §EX.3 doors): rays across each
## opening at its foot and near its top meet the jamb stones, the opening
## narrower at the top as top_share says.
func _style_scene(main: CrawlerMain) -> void:
	var lay := main.lay
	var top_share := RuinStyle.num("doors.top_share", 0.85)
	var worst := 0.0
	var probed := 0
	var shut := 0
	for d in lay.doors:
		var p2: Vector2 = d.p
		var n2: Vector2 = d.n
		var t := Vector3(-n2.y, 0.0, n2.x)
		var c := Vector3(p2.x, float(d.y), p2.y)
		var w: Array = []
		for hgt: float in [0.35, float(d.h) - 0.2]:
			var o := c + Vector3.UP * hgt
			var r1 := _ray(o, o + t * 2.0, [main.player.get_rid()])
			var r2 := _ray(o, o - t * 2.0, [main.player.get_rid()])
			if r1.is_empty() or r2.is_empty():
				w.append(-1.0)
			else:
				w.append(o.distance_to(r1.position) + o.distance_to(r2.position))
		if float(w[0]) <= 0.0 or float(w[1]) <= 0.0:
			shut += 1
			continue
		probed += 1
		var fw := 2.0 * float(d.half)
		var h := float(d.h)
		var want := (fw - fw * (1.0 - top_share) * (h - 0.2) / h) / (fw - fw * (1.0 - top_share) * 0.35 / h)
		worst = maxf(worst, absf(float(w[1]) / float(w[0]) - want))
		if probed <= 2:
			print("  door %d: %.2f m across at its foot, %.2f m near its top (%.3f; the trapezoid %.3f)" % [d.id, w[0], w[1], float(w[1]) / float(w[0]), want])
	ok(probed == (lay.doors as Array).size() and worst < 0.02, "the doorways in stone: across every one of %d, near its top narrower than at its foot as top_share says (worst %.3f off; %d unprobed)" % [probed, worst, shut])


## The player's own body walks the built tomb (design §EX.5's check; the
## stone kit of §EX.3 mustn't stand in the way: thresholds, battered jambs,
## pillars, coffins, block stairs): through every door both ways, along
## every corridor and stair from door to door, from every door into the
## middle of its room (round its pillars and what lies there), the
## CharacterBody3D with the crawler's own capsule, step and slope, steered
## like a player (a step aside when something stands in the way). Seeds 1,
## 7 and 42 (the scene's own, then the others built in turn).
func _room_walks(main: CrawlerMain) -> void:
	var seeds_done: Array = []
	var all_ok := true
	var walked := 0.0
	var legs := 0
	var blocked: Array = []
	var builds: Array = []
	# The scene's own tomb when it is one of them (the way out's stand-in
	# may have moved it on to the next).
	if int(main.lay.seed) in STYLE_SEEDS:
		var res := await _walk_tomb(main)
		seeds_done.append(int(main.lay.seed))
		all_ok = bool(res.ok)
		walked = float(res.m)
		legs = int(res.legs)
		blocked = res.blocked
		builds.append("%d: %d ms" % [int(main.lay.seed), int(main.tomb.get_meta("build_ms", 0))])
	var cur := main
	for s in STYLE_SEEDS:
		if int(s) in seeds_done:
			continue
		cur.queue_free()
		await process_frame
		await process_frame
		OS.set_environment("SEED", str(s))
		cur = load("res://scenes/crawler.tscn").instantiate()
		get_root().add_child(cur)
		for i in 10:
			await physics_frame
		while not cur.baked:
			await process_frame
		builds.append("%d: %d ms" % [int(s), int(cur.tomb.get_meta("build_ms", 0))])
		var r2 := await _walk_tomb(cur)
		seeds_done.append(int(s))
		all_ok = all_ok and bool(r2.ok)
		walked += float(r2.m)
		legs += int(r2.legs)
		blocked.append_array(r2.blocked)
	print("  the tomb's build: %s" % ", ".join(builds))
	ok(all_ok, "the player's body walks every tomb of seeds %s: every door both ways, every corridor and stair, into every room (%d legs, %.0f m%s)" % [str(seeds_done), legs, walked, "" if blocked.is_empty() else "; blocked: " + ", ".join(blocked)])


## Walk one built tomb: {"ok", "m" (metres walked), "legs", "blocked"
## [what stopped the body]}.
func _walk_tomb(main: CrawlerMain) -> Dictionary:
	var lay := main.lay
	var p := main.player
	p.typing = false
	p.ui_open = false
	var legs: Array = []
	# A door: from its one side to its other, both ways. Not the way out's
	# opening (b -1, §EX.5): stepping into it walks you out to the next
	# tomb, and 46's own walk (_walks) goes through it.
	for d in lay.doors:
		if int(d.a) < 0 or int(d.b) < 0:
			continue
		var a_pc: Dictionary = lay.pieces[int(d.a)]
		var b_pc: Dictionary = lay.pieces[int(d.b)]
		var p2: Vector2 = d.p
		var n2: Vector2 = d.n
		var from := _on_floor(a_pc, p2 - n2 * 1.1)
		var to := _on_floor(b_pc, p2 + n2 * 1.1)
		legs.append([from, to, "door %d" % d.id])
		legs.append([to, from, "door %d back" % d.id])
	# A corridor or a stair: from the one door to the other.
	for pc in lay.pieces:
		if str(pc.kind) == "room":
			continue
		var ends: Array = []
		for di in pc.doors:
			ends.append(_inside_door(lay, pc, lay.doors[di]))
		for i in range(1, ends.size()):
			legs.append([ends[0], ends[i], "%s %d" % [pc.kind, pc.id]])
	# A room: from each door to its middle (the wake spot in the hearth
	# room), or as near it as the floor goes, the way a person would find
	# round its pillars and what lies there (TombNav, the skeletons' grid).
	var blocked: Array = []
	var nav := TombNav.build(lay, get_root().get_world_3d().direct_space_state, 0.36, [p.get_rid()])
	for pc in lay.pieces:
		if str(pc.kind) != "room":
			continue
		var ways := _room_ways(main, pc, nav)
		if ways.is_empty():
			blocked.append("seed %d %s %d: no way in to within 2 m of its middle from every door, or not across it" % [int(lay.seed), pc.room_kind, pc.id])
			continue
		for di in pc.doors:
			var pts: Array = ways[di]
			for i in range(1, pts.size()):
				legs.append([pts[i - 1], pts[i], "into %s %d by door %d" % [pc.room_kind, pc.id, di]])
	var walked := 0.0
	var out0 := main.walked_out
	for leg in legs:
		var res := await _walk_leg(p, leg[0], leg[1])
		walked += float(res.m)
		if not bool(res.ok):
			blocked.append("seed %d %s (stopped at %s)" % [int(lay.seed), leg[2], str(res.at)])
		if main.walked_out != out0 or main.leaving:
			# The legs after it would walk the next tomb's stone.
			blocked.append("seed %d %s: walked out of the tomb" % [int(lay.seed), leg[2]])
			break
	for a in ["move_forward", "move_left", "move_right", "move_back", "sprint"]:
		Input.action_release(a)
	return {"ok": blocked.is_empty(), "m": walked, "legs": legs.size(), "blocked": blocked}


## A point on piece `pc`'s floor (x/z `q`).
static func _on_floor(pc: Dictionary, q: Vector2) -> Vector3:
	return Vector3(q.x, Delves.floor_of(pc, Delves.along_across(pc, q).x), q.y)


## Just inside piece `pc` through door `d`.
static func _inside_door(lay: Dictionary, pc: Dictionary, d: Dictionary) -> Vector3:
	var p2: Vector2 = d.p
	var n2: Vector2 = d.n
	var into := n2 if int(d.b) == int(pc.id) else -n2
	return _on_floor(pc, p2 + into * 1.1)


## Just inside room `pc` through door `d`, where the body stands clear:
## 1.1 m in, or nearer the door where something stands closer than that
## (a coffin across the way in). A sweep starting inside a stone would pass
## through it (cast_motion leaves out what it starts in).
func _clear_inside(q: PhysicsShapeQueryParameters3D, lay: Dictionary, pc: Dictionary, d: Dictionary) -> Vector3:
	var p2: Vector2 = d.p
	var n2: Vector2 = d.n
	var into := n2 if int(d.b) == int(pc.id) else -n2
	for k: float in [1.1, 0.9, 0.7, 0.5]:
		var at := _on_floor(pc, p2 + into * k)
		if _stands(q, at):
			return at
	return _inside_door(lay, pc, d)


## The body's capsule (a hair wider than the player's), for finding ways.
func _body_query(main: CrawlerMain) -> PhysicsShapeQueryParameters3D:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.37
	shape.height = PlanetPlayer.STAND_HEIGHT - 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.exclude = [main.player.get_rid()]
	return q


## Does the body stand clear at `at` (on a floor)? Its capsule's foot 4 cm
## up: over the flags and the thresholds' lips, not over any stone it
## couldn't step onto.
func _stands(q: PhysicsShapeQueryParameters3D, at: Vector3) -> bool:
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.04 + (q.shape as CapsuleShape3D).height * 0.5, 0.0))
	q.motion = Vector3.ZERO
	return get_root().get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## The ways into room `pc`: {door id: [points to walk through]}, each from
## just inside its door (where the body stands clear: _clear_inside) to the
## room's middle (the wake spot in the hearth room), or as near it as the
## floor goes, round its pillars and whatever lies there: the way found on
## `nav` (TombNav at your size, the skeletons' own floor grid). {} when a
## door's way stops more than 2 m short of the middle, or the room can't be
## crossed from one of its doors to another.
func _room_ways(main: CrawlerMain, pc: Dictionary, nav: TombNav) -> Dictionary:
	var q := _body_query(main)
	var hub := _on_floor(pc, (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5)
	if str(pc.room_kind) == "hearth":
		hub = (main.lay.wake as Array)[0]
	var ways := {}
	var starts := {}
	for di in pc.doors:
		var s0 := _clear_inside(q, main.lay, pc, main.lay.doors[di])
		starts[di] = s0
		var path := nav.path(s0, hub, true)
		if path.is_empty() or Vector2(path[-1].x - hub.x, path[-1].z - hub.z).length() > 2.0:
			return {}
		var pts: Array = [s0]
		for k in path.size():
			if k > 0 or path[k].distance_to(s0) > 0.3:
				pts.append(path[k])
		ways[di] = pts
	var ds: Array = starts.keys()
	for k in range(1, ds.size()):
		if nav.path(starts[ds[0]], starts[ds[k]], false).is_empty():
			return {}
	return ways


## Walk the body from `from` to `to` like a player would: face it, walk;
## when something stands in the way, a step to the side and on. {"ok", "m",
## "at"}.
func _walk_leg(p: CrawlerPlayer, from: Vector3, to: Vector3, max_s := 12.0) -> Dictionary:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	p.spawn_flat(from, atan2(-flat.x, -flat.y), 0.0)
	await _frames(3)
	Input.action_press("move_forward")
	var best := INF
	var since := 0
	var dodge := 0
	var side := 1.0
	var ok_ := false
	var start := p.global_position
	for i in int(max_s * 60.0):
		var here := p.global_position
		var go := Vector2(to.x - here.x, to.z - here.z)
		if go.length() < 0.45 and absf(here.y - to.y) < 0.7:
			ok_ = true
			break
		p._yaw = atan2(-go.x, -go.y)
		if dodge > 0:
			dodge -= 1
			if dodge == 0:
				Input.action_release("move_left")
				Input.action_release("move_right")
		elif since > 30:
			side = -side
			dodge = 26
			since = 0
			Input.action_press("move_left" if side < 0.0 else "move_right")
		await physics_frame
		var dd := Vector2(to.x - p.global_position.x, to.z - p.global_position.z).length()
		if dd < best - 0.05:
			best = dd
			since = 0
		else:
			since += 1
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	return {"ok": ok_, "m": start.distance_to(p.global_position), "at": p.global_position.snapped(Vector3.ONE * 0.01)}
