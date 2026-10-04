extends SceneTree
## The wind you can see, Wind I (design 3 Oct §DA, data/wind.json, Wind,
## shaders/wind.gdshaderinc):
##   SEED=7731 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method forward_plus -s tools/wind_check.gd
## (Headless works for everything but (e), which needs a renderer to run
## the shader; it is skipped there.) With a 6 m/s mean wind, asserts:
##  (a) two points 20 m apart along the wind see the same gust about
##      20 / 6 = 3.3 s apart (the lag that best lines up their gusts);
##  (b) two points 3 m apart share a gust factor within 0.1;
##  (c) a plant under a closed crown (sky visibility 0.1) gets about 0.235
##      of the wind (shelter_floor + 0.85 x 0.1), read back from the code
##      Wind.stamp writes, and a crown part the full wind; the profile
##      gives grass tops about half the 10 m wind, head height about 0.7, a
##      treetop about 1.1;
##  (d) the gust factor stays inside [lull_min, factor_max] over 10,000
##      samples, and below calm_mps the field fades to 1;
##  (e) the shader's field (wind.gdshaderinc, rendered) and Wind's agree at
##      100 random points;
##  (f) in play, the chunks round the opening camp are stamped: grasses and
##      herbs bow (kind 1), canopy trees take the full wind (kind 2), the
##      understory is sheltered where the dapple says so, Populus and the
##      sacred fig flutter.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	Wind.setup()
	# A planet-sized frame: the field lives in the planet's frame.
	Wind._center = Vector3(1200.0, -63700.0, 800.0)
	Wind.drift = Vector3(321.0, 0.0, -97.0)
	Wind.clock = 0.0
	var east := Vector3(1, 0, 0)
	var up := Vector3(0, 1, 0)
	Wind.mean = east * 6.0
	WeatherFX.plant_wind = Wind.mean
	var G: Dictionary = Wind.G
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	# (a) The lag between two points 20 m apart along the wind.
	var p0 := Vector3(10.0, 0.0, 20.0)
	var p1 := p0 + east * 20.0
	var dt := 0.05
	var s0 := PackedFloat32Array()
	var s1 := PackedFloat32Array()
	for k in 2400:
		var t := k * dt
		s0.append(Wind.gust_at(p0, t).x)
		s1.append(Wind.gust_at(p1, t).x)
	var best_lag := 0.0
	var best := -1e9
	for lag_k in range(0, 160):
		var sum := 0.0
		var n := 0
		for k in range(0, 2400 - lag_k):
			sum -= absf(s0[k] - s1[k + lag_k])
			n += 1
		var score := sum / n
		if score > best:
			best = score
			best_lag = lag_k * dt
	ok(absf(best_lag - 20.0 / 6.0) < 0.1 and best > -0.002, "(a) a gust 20 m upwind reaches the next point %.2f s later (20 m / 6 m/s = 3.33 s; mismatch %.4f)" % [best_lag, -best])
	# (b) Neighbours 3 m apart.
	var diffs: Array[float] = []
	for k in 2000:
		var p := Vector3(rng.randf_range(-3000.0, 3000.0), rng.randf_range(-20.0, 20.0), rng.randf_range(-3000.0, 3000.0))
		var a := rng.randf() * TAU
		var q := p + Vector3(cos(a), 0.0, sin(a)) * 3.0
		diffs.append(absf(Wind.gust_at(p, 0.0).x - Wind.gust_at(q, 0.0).x))
	diffs.sort()
	ok(diffs[int(diffs.size() * 0.95)] < 0.1, "(b) two points 3 m apart share a gust factor within 0.1 (median %.3f, 95th percentile %.3f, worst %.3f)" % [diffs[diffs.size() / 2], diffs[int(diffs.size() * 0.95)], diffs[diffs.size() - 1]])
	# (c) Shelter, through the code Wind.stamp writes.
	var under: PlantSpecies = null
	var crown: PlantSpecies = null
	var grass: PlantSpecies = null
	for sp: PlantSpecies in SpeciesDB.all():
		var k := Wind.kind_of(sp)
		if k == 0 and sp.tier == PlantSpecies.Tier.SHRUB and under == null:
			under = sp
		elif k == 2 and crown == null:
			crown = sp
		elif k == 1 and grass == null:
			grass = sp
	var dapple := Image.create(CanopyDapple.DAPPLE_PX, CanopyDapple.DAPPLE_PX, false, Image.FORMAT_R8)
	dapple.fill(Color(0.1, 0.1, 0.1))
	var plants := {}
	for sp in [under, crown, grass]:
		var buf := PackedFloat32Array()
		buf.resize(VegetationPlacer.MM_STRIDE * 3)
		plants[SpeciesDB.index_of(sp)] = [buf, 3, [], {}]
	var center := Vector3(0, 1, 0)
	Wind.stamp(plants, dapple, center)
	var dec_u := Wind.decode((plants[SpeciesDB.index_of(under)][0] as PackedFloat32Array)[18])
	var dec_c := Wind.decode((plants[SpeciesDB.index_of(crown)][0] as PackedFloat32Array)[18])
	var dec_g := Wind.decode((plants[SpeciesDB.index_of(grass)][0] as PackedFloat32Array)[18])
	var sh_u := Wind.shelter(dec_u.x)
	var sh_c := 1.0 if dec_c.z > 1.5 else Wind.shelter(dec_c.x)
	ok(absf(sh_u - 0.235) < 0.01 and int(dec_u.z) == 0, "(c) under a closed crown (sky 0.1) the %s gets %.3f of the wind (want 0.235)" % [under.name, sh_u])
	ok(is_equal_approx(sh_c, 1.0) and int(dec_c.z) == 2, "(c) the %s's crown takes the full wind (%.2f)" % [crown.name, sh_c])
	ok(int(dec_g.z) == 1 and absf(Wind.shelter(dec_g.x) - 0.235) < 0.01, "(c) the %s bows (kind 1) and is sheltered too (%.3f)" % [grass.name, Wind.shelter(dec_g.x)])
	ok(is_equal_approx(Wind.shelter(0.4, true), 0.0), "(c) enclosed (a delve): no wind")
	Wind.z0 = float((Wind.P.get("z0_m", {}) as Dictionary).get("grass", 0.03))
	var pr := [Wind.profile(0.5), Wind.profile(1.7), Wind.profile(20.0)]
	ok(absf(pr[0] - 0.5) < 0.08 and absf(pr[1] - 0.7) < 0.05 and absf(pr[2] - 1.1) < 0.06, "(c) over grass: a 0.5 m grass top gets %.2f of the 10 m wind, head height %.2f, a 20 m treetop %.2f" % pr)
	# (d) The bounds over 10,000 samples, and the calm.
	var lo := 9.0
	var hi := -9.0
	var veer := 0.0
	var at_max := 0
	var at_min := 0
	for k in 10000:
		var p := Vector3(rng.randf_range(-20000.0, 20000.0), rng.randf_range(-100.0, 100.0), rng.randf_range(-20000.0, 20000.0))
		var g := Wind.gust_at(p, rng.randf() * 600.0)
		lo = minf(lo, g.x)
		hi = maxf(hi, g.x)
		veer = maxf(veer, absf(g.y))
		if g.x >= float(G.get("factor_max", 1.6)) - 1e-4:
			at_max += 1
		if g.x <= float(G.get("lull_min", 0.45)) + 1e-4:
			at_min += 1
	ok(lo >= float(G.get("lull_min", 0.45)) - 1e-5 and hi <= float(G.get("factor_max", 1.6)) + 1e-5 and rad_to_deg(veer) <= float(G.get("veer_deg", 10.0)) + 0.01, "(d) 10,000 samples: the factor from %.3f to %.3f (bounds %.2f-%.2f; %d at the top, %d at the bottom), the veer at most %.1f°" % [lo, hi, float(G.get("lull_min", 0.45)), float(G.get("factor_max", 1.6)), at_max, at_min, rad_to_deg(veer)])
	Wind.mean = east * 0.1
	var calm_max := 0.0
	for k in 500:
		var p := Vector3(rng.randf_range(-2000.0, 2000.0), 0.0, rng.randf_range(-2000.0, 2000.0))
		calm_max = maxf(calm_max, absf(Wind.gust_at(p, 0.0).x - 1.0))
	ok(calm_max <= 0.2 * 0.6 + 1e-3, "(d) in still air (0.1 m/s, under calm_mps %.1f) the gusts fade (at most %.2f off the mean)" % [float(G.get("calm_mps", 0.5)), calm_max])
	Wind.mean = east * 6.0
	# (e) The shader's field against Wind's.
	if DisplayServer.get_name() == "headless":
		print("SKIP  (e) the shader comparison needs a renderer (run under xvfb-run, as above)")
	else:
		await _compare_shader(rng)
	# (f) In play: the chunks are stamped.
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, -1)
	Bow.need_capture = false
	WorldSave.read_only = true
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 30:
		await process_frame
	var kinds := {0: 0, 1: 0, 2: 0}
	var wrong := []
	var sheltered := 0
	var total := 0
	var flutter_sp := {}
	var all := SpeciesDB.all()
	for chunk in main.chunks.chunks.values():
		for c in (chunk as Node).find_children("*", "MultiMeshInstance3D", true, false):
			var mmi := c as MultiMeshInstance3D
			if not mmi.has_meta("species") or mmi.multimesh == null or not mmi.multimesh.use_custom_data:
				continue
			# (Other MultiMeshes carry a "species" key of their own.)
			var si := int(mmi.get_meta("species"))
			if si < 0 or si >= all.size() or mmi.material_override == null or not (mmi.material_override as ShaderMaterial).shader.resource_path.ends_with("foliage.gdshader"):
				continue
			var sp: PlantSpecies = all[si]
			var mm := mmi.multimesh
			for i in mini(mm.instance_count, 40):
				# (A band's slot not filled yet has no transform at all.)
				if mm.get_instance_transform(i).basis.y.length() < 1e-6:
					continue
				var d := Wind.decode(mm.get_instance_custom_data(i).b)
				total += 1
				kinds[int(d.z)] = int(kinds.get(int(d.z), 0)) + 1
				if int(d.z) != Wind.kind_of(sp) and not wrong.has(sp.name):
					wrong.append(sp.name)
					print("[wind] %s: kind %d, want %d (%s, instance %d of %d, custom %s)" % [sp.name, int(d.z), Wind.kind_of(sp), str(mmi.get_path()).get_file(), i, mm.instance_count, str(mm.get_instance_custom_data(i))])
				if int(d.z) != 2 and d.x < 0.6:
					sheltered += 1
				if d.y > 0.5:
					flutter_sp[sp.name] = true
				if Wind.flutters(sp) and d.y < 0.5 and not wrong.has(sp.name):
					wrong.append(sp.name)
	print("[wind] %d plants read round the opening camp: %d sheltered or open below the crowns, %d grass and herbs, %d crowns; %d under a crown (sky < 0.6); flutter: %s" % [total, kinds[0], kinds[1], kinds[2], sheltered, ", ".join(flutter_sp.keys()) if not flutter_sp.is_empty() else "none here"])
	ok(total > 0 and wrong.is_empty(), "(f) every plant read carries its species' wind kind and flutter (%s)" % ("all right" if wrong.is_empty() else ", ".join(wrong.slice(0, 12))))
	ok(kinds[1] > 0 or kinds[2] > 0, "(f) the camp's ground has grasses or crowns stamped")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Run wind.gdshaderinc on 100 points in a 100 x 1 viewport and read the
## factor and veer back (16 bits each).
func _compare_shader(rng: RandomNumberGenerator) -> void:
	var n := 100
	var pts := Image.create(n, 1, false, Image.FORMAT_RGBF)
	var want: Array[Vector2] = []
	for i in n:
		var p := Vector3(rng.randf_range(-3000.0, 3000.0), rng.randf_range(-50.0, 50.0), rng.randf_range(-3000.0, 3000.0))
		pts.set_pixel(i, 0, Color(p.x, p.y, p.z))
		want.append(Wind.gust_field(p + Wind.shift(), Wind.mean.length()))
	RenderingServer.global_shader_parameter_set("wind_shift", Wind.shift())
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
render_mode blend_disabled;
#include "res://shaders/wind.gdshaderinc"
uniform sampler2D pts : filter_nearest;
uniform float mean_mps;
void fragment() {
	vec3 p = texelFetch(pts, ivec2(int(FRAGCOORD.x), 0), 0).xyz;
	vec2 g = wind_gust_field(p, mean_mps);
	float f = floor(clamp(g.x / 2.0, 0.0, 1.0) * 65535.0 + 0.5);
	float v = floor(clamp(g.y / 0.5 + 0.5, 0.0, 1.0) * 65535.0 + 0.5);
	COLOR = vec4(floor(f / 256.0) / 255.0, mod(f, 256.0) / 255.0, floor(v / 256.0) / 255.0, mod(v, 256.0) / 255.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("pts", ImageTexture.create_from_image(pts))
	mat.set_shader_parameter("mean_mps", Wind.mean.length())
	var vp := SubViewport.new()
	vp.size = Vector2i(n, 1)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = Vector2(n, 1)
	rect.material = mat
	vp.add_child(rect)
	get_root().add_child(vp)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var worst_f := 0.0
	var worst_v := 0.0
	for i in n:
		var c := img.get_pixel(i, 0)
		var f := (roundf(c.r * 255.0) * 256.0 + roundf(c.g * 255.0)) / 65535.0 * 2.0
		var v := ((roundf(c.b * 255.0) * 256.0 + roundf(c.a * 255.0)) / 65535.0 - 0.5) * 0.5
		worst_f = maxf(worst_f, absf(f - want[i].x))
		worst_v = maxf(worst_v, absf(v - want[i].y))
	ok(worst_f < 2e-3 and worst_v < 2e-3, "(e) the shader and Wind agree at %d points (worst factor %.5f, worst veer %.5f rad)" % [n, worst_f, worst_v])
	vp.queue_free()
