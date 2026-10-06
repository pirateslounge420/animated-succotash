extends SceneTree
## The render distance setting (settings panel, "display.render_m", in
## metres; design §ER.1 halved its default to 455 m),
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
	world.pin(42, 0)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var was = Settings.get_value("display.render_m", ChunkManager.DEFAULT_RENDER_M)
	ok(absf(ChunkManager.DEFAULT_RENDER_M - ChunkManager.TUNED_REACH_M * 0.5) < 1.0, "the default render distance is half the old 3-chunk reach (%.0f m of %.0f m, §ER.1)" % [ChunkManager.DEFAULT_RENDER_M, ChunkManager.TUNED_REACH_M])
	var counts := {}
	for m in [455.0, 1200.0, 200.0, 455.0]:
		Settings.set_value("display.render_m", m)
		var n := ChunkManager.render_chunks()
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
		counts[m] = last
		await frames(2)
		var edge := float(Look._params.get("look_draw_m", 0.0))
		print("[render] %.0f m (%d-chunk ring): %d drawn, farthest %.0f m, settled in %.1f s; day haze x%.2f, fog now %.4f, fog full at %.0f m" % [m, n, last, far, ms / 1000.0, ChunkManager.fog_scale(), main.sky.environment.fog_density, edge * 0.95])
		ok(is_equal_approx(edge, m), "the fog's far edge follows the setting (%.0f m)" % edge)
		# Every point within the render distance is on a loaded chunk.
		var r := ChunkManager.render_reach_m(n) - ChunkManager.chunk_size_m() * 0.7072
		ok(r >= m, "the %d-chunk ring covers %.0f m wherever you stand in your chunk (%.0f m)" % [n, m, r])
	ok(counts[1200.0] > counts[455.0] and counts[200.0] < counts[455.0], "the ring grows and shrinks with the setting (%d, %d, %d chunks drawn)" % [counts[200.0], counts[455.0], counts[1200.0]])
	Settings.set_value("display.render_m", 455.0)
	var near_fog := ChunkManager.fog_scale()
	Settings.set_value("display.render_m", 2200.0)
	ok(is_equal_approx(near_fog, 1.0) and ChunkManager.fog_scale() < 1.0, "the haze keeps its tuned density up close and thins farther (x%.2f at 455 m, x%.2f at 2200 m)" % [near_fog, ChunkManager.fog_scale()])
	Settings.set_value("display.render_m", was)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)
