extends SceneTree
## The render distance setting (settings panel, "display.render_chunks"),
## live: from the camp at the default, then farther, then nearest, then
## back. Per setting: chunks drawn once streaming settles, the farthest
## chunk center, how long the ring took to fill, and the day haze density
## (SkySystem scales it with ChunkManager.fog_scale()). Checks the ring
## grows and shrinks with the setting and the haze follows it. Restores the
## setting it found.
##
##   ~/bin/godot --headless --path . --script tools/render_distance_check.gd

var main
var world
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var was = Settings.get_value("display.render_chunks", ChunkManager.DEFAULT_RENDER)
	var counts := {}
	for n in [3, 5, 1, 3]:
		Settings.set_value("display.render_chunks", n)
		var t0 := Time.get_ticks_msec()
		var last := -1
		var still := 0
		for k in 600:
			await frames(5)
			var c: int = main.chunks.chunks.size()
			still = still + 1 if c == last and main.chunks._pending.is_empty() else 0
			last = c
			if still >= 6:
				break
		var ms := Time.get_ticks_msec() - t0
		var far := 0.0
		var pd: Vector3 = main.player.surface_dir
		var shown := 0
		for key in main.chunks.chunks:
			if not (main.chunks.chunks[key] as Node3D).visible:
				continue
			shown += 1
			far = maxf(far, CubeSphere.surface_distance_m(pd, TerrainChunk.center_of(key)))
		last = shown
		counts[n] = last
		print("[render] %d chunks (%d m): %d drawn, farthest %.0f m, settled in %.1f s; day haze x%.2f, fog now %.4f" % [n, roundi(ChunkManager.render_reach_m(n)), last, far, ms / 1000.0, ChunkManager.fog_scale(), main.sky.environment.fog_density])
	ok(counts[5] > counts[3] and counts[1] < counts[3], "the ring grows and shrinks with the setting (%d, %d, %d chunks)" % [counts[1], counts[3], counts[5]])
	Settings.set_value("display.render_chunks", 1)
	var near_fog := ChunkManager.fog_scale()
	Settings.set_value("display.render_chunks", 6)
	ok(near_fog > 1.0 and ChunkManager.fog_scale() < 1.0, "the haze thickens nearer, thins farther (x%.2f at 1, x%.2f at 6)" % [near_fog, ChunkManager.fog_scale()])
	Settings.set_value("display.render_chunks", was)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
