class_name Smoke
## Smoke (design 3 Oct §CV, data/smoke.json): a column over every lit
## hearth you can read from far off.
##
## - The column (column(), update()): `look.cards` camera-facing cards
##   (shaders/smoke.gdshader) round the fire's spine, sized by the fire's
##   FireStore state (hearth.by_state: flames the full column, low about
##   half, embers a thin wisp, out nothing; a stack's stack_scale of it),
##   leaning with the weather's wind (lean_deg_per_mps, up to max_lean_deg,
##   more toward the top by shear; still under calm_below_mps), pooling
##   flat at calm_pool.at_m on a still dawn, beaten down by rain
##   (rain.top_scale, density_scale). At night no column: only its first
##   fire_lit_m, lit warm by the fire (smoke gives off no light).
## - Which fires: every fire smokes, by its flame's size (Mike, 3 Oct;
##   hearth.by_flame). Every Campfire (camps, rekindled old hearths, nests,
##   mythic folk's fires, the fires you lay) carries meta "smoke" (its
##   scale, 1.0; a delve's hearth breathes through its stack at
##   stack_scale). The small fires (tick_flame()) smoke at their flame's
##   size against a campfire's, the column size^exponent of the by_state
##   row: the torch's burnt end and a planted torch (an ember, the embers
##   row), the tomb lamps and the fat lamp (flames), the pipe's brand.
## - Far hearths (far_columns()): the hearths the world keeps (living camps
##   at ruins and nests) within hearth.far.seen_to_m that aren't built
##   here are drawn from their fire's state in the sim (FireStore's store;
##   a camp nobody has visited burns, as its sim starts).

## SMOKE=0 in the environment draws no smoke (A/B, frame times).
static var ON := OS.get_environment("SMOKE") != "0"
static var D: Dictionary = Tuning.table("smoke")
static var H: Dictionary = D.get("hearth", {})
static var LOOK: Dictionary = H.get("look", {})
static var _strip: ArrayMesh
static var _shader: Shader


## The strip every card is drawn on: x -0.5..0.5, y 0..1 in `rows` rows.
static func strip() -> ArrayMesh:
	if _strip != null:
		return _strip
	var rows := 16
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in rows + 1:
		var y := float(r) / rows
		v.append(Vector3(-0.5, y, 0))
		v.append(Vector3(0.5, y, 0))
		uv.append(Vector2(0, 1.0 - y))
		uv.append(Vector2(1, 1.0 - y))
	for r in rows:
		var a := r * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	_strip = ArrayMesh.new()
	_strip.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _strip


static func _col(key: String, fallback: String, src := {}) -> Color:
	var d: Dictionary = src if not src.is_empty() else LOOK
	return Color(str(d.get(key, fallback))).srgb_to_linear()


## A column's material (one per column: its size and lean are its own).
static func material(colours := {}) -> ShaderMaterial:
	if _shader == null:
		_shader = preload("res://shaders/smoke.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("look_grain_soft", Look.grain())
	var tx: Array = LOOK.get("texels", [16, 24])
	m.set_shader_parameter("texels", Vector2(float(tx[0]), float(tx[1])))
	m.set_shader_parameter("rise_mps", float(H.get("rise_mps", 1.2)))
	m.set_shader_parameter("shear", float((H.get("wind", {}) as Dictionary).get("shear", 1.5)))
	m.set_shader_parameter("colour_near", _col("colour_near", "#8FA0C8", colours))
	m.set_shader_parameter("colour_far", _col("colour_far", "#B4C2E8", colours))
	m.set_shader_parameter("colour_shade", _col("colour_shade", "#5A6AA0", colours))
	var night: Dictionary = H.get("night", {})
	m.set_shader_parameter("fire_lit_m", float(night.get("fire_lit_m", 8.0)))
	m.set_shader_parameter("fire_lit", Color(str(Campfire.L.get("color", "#FF6E24"))).srgb_to_linear())
	var far: Dictionary = H.get("far", {})
	m.set_shader_parameter("far_m", float(far.get("seen_to_m", 3200.0)))
	var pool: Dictionary = H.get("calm_pool", {})
	m.set_shader_parameter("pool_m", float(pool.get("at_m", 18.0)))
	m.set_shader_parameter("pool_spread_m", float(pool.get("spread_m", 90.0)))
	return m


## A column node (`look.cards` cards sharing one material) under `parent`.
static func column(parent: Node, name := "Smoke", colours := {}) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.top_level = true
	parent.add_child(n)
	var m := material(colours)
	n.set_meta("mat", m)
	var cards := int(LOOK.get("cards", 5))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + parent.get_instance_id()
	for i in cards:
		var mi := MeshInstance3D.new()
		mi.mesh = strip()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16384.0
		mi.set_instance_shader_parameter("card_phase", rng.randf())
		mi.set_instance_shader_parameter("card_off", (float(i) - (cards - 1) * 0.5) * 0.22 + rng.randf_range(-0.05, 0.05))
		n.add_child(mi)
	n.visible = false
	return n


## What the column of a fire in `state` looks like (hearth.by_state), at
## `scale` (a stack's stack_scale): [top_m, width_m, density].
static func size_for(state: String, scale := 1.0) -> Vector3:
	var row: Dictionary = (H.get("by_state", {}) as Dictionary).get(state, {})
	return Vector3(float(row.get("top_m", 0.0)) * scale, float(row.get("width_m", 0.0)) * scale, float(row.get("density", 0.0)))


## Lay a column out this frame: its foot at scene `foot`, up `up`, the fire
## in `state`, the weather's `wind` there (m/s, a world vector), `rain_mm_h`,
## `night` (0-1), `calm_dawn` (true on a still dawn), `scale`.
static func update(col: Node3D, foot: Vector3, up: Vector3, state: String, wind: Vector3, rain_mm_h: float, night: float, calm_dawn: bool, scale := 1.0, shelter_m := 0.0) -> void:
	var sz := size_for(state, scale)
	var rain: Dictionary = H.get("rain", {})
	if rain_mm_h >= float(rain.get("from_mm_h", 1.0)):
		sz.x *= float(rain.get("top_scale", 0.5))
		sz.z *= float(rain.get("density_scale", 0.6))
	var draw := bool((H.get("night", {}) as Dictionary).get("draw_column", false))
	col.visible = sz.x > 0.1 and sz.z > 0.01
	if not col.visible:
		return
	var m: ShaderMaterial = col.get_meta("mat")
	var W: Dictionary = H.get("wind", {})
	var flat := wind - up * wind.dot(up)
	var speed := flat.length()
	var lean := Vector3.ZERO
	if speed > float(W.get("calm_below_mps", 1.0)):
		var deg := minf(speed * float(W.get("lean_deg_per_mps", 8.0)), float(W.get("max_lean_deg", 70.0)))
		lean = flat.normalized() * tan(deg_to_rad(deg))
	m.set_shader_parameter("base", foot)
	m.set_shader_parameter("up_dir", up)
	m.set_shader_parameter("lean", lean)
	m.set_shader_parameter("top_m", sz.x)
	m.set_shader_parameter("width_m", sz.y)
	m.set_shader_parameter("density", sz.z)
	m.set_shader_parameter("pool", 1.0 if calm_dawn and speed <= float(W.get("calm_below_mps", 1.0)) else 0.0)
	m.set_shader_parameter("night", 0.0 if draw else night)
	# The fire lights less of a small fire's smoke (by the flame's size).
	m.set_shader_parameter("fire_lit_m", float((H.get("night", {}) as Dictionary).get("fire_lit_m", 8.0)) * sqrt(maxf(scale, 0.0)))
	# Under trees it rises straight through the crowns and leans above
	# them; its lean follows the gust field at each height, and a gust at
	# the fire shreds it (design §DA, wind.json smoke; the shader).
	var g := Wind.gust_at(foot, Wind.clock).x if bool((((Wind.D.get("smoke", {}) as Dictionary).get("gusts", {})) as Dictionary).get("lean_follows_gust", true)) else 1.0
	m.set_shader_parameter("shelter_m", shelter_m if bool((Wind.D.get("smoke", {}) as Dictionary).get("shelter_under_crowns", true)) else 0.0)
	m.set_shader_parameter("gust", g)
	col.set_meta("top_m", sz.x)
	col.set_meta("lean", lean)
	col.set_meta("shelter_m", shelter_m)
	col.set_meta("foot", foot)
	col.set_meta("up", up)


## How far the column's spine stands off upright `h` m up (scene vector;
## the shader's sum, for the checks): none below the crowns' shelter_m,
## the lean (with the gust field there) above them.
static func lean_offset(col: Node3D, h: float) -> Vector3:
	var m: ShaderMaterial = col.get_meta("mat")
	var lean: Vector3 = col.get_meta("lean", Vector3.ZERO)
	var top := maxf(float(col.get_meta("top_m", 1.0)), 0.1)
	var shelter := float(col.get_meta("shelter_m", 0.0))
	var y := clampf(h / top, 0.0, 1.0)
	var foot: Vector3 = col.get_meta("foot", Vector3.ZERO)
	var up: Vector3 = col.get_meta("up", Vector3.UP)
	var g := Wind.gust_field(foot + up * h + Wind.shift(), Wind.mean.length()).x
	return lean * maxf(h - shelter, 0.0) * (1.0 + float(m.get_shader_parameter("shear")) * y * y) * g


## The height of the crowns over a hearth (m above `foot`; 0 in the open):
## the tallest tree within 9 m whose crown covers it, where the sky is
## mostly closed (§BD's sky visibility under 0.6).
static func shelter_over(foot: Vector3) -> float:
	var chunks: ChunkManager = Wind.chunks
	if chunks == null or chunks.sky_visibility_at(foot) >= 0.6:
		return 0.0
	var best := 0.0
	for key in chunks.chunks:
		var ch: TerrainChunk = chunks.chunks[key]
		if ch.global_position.distance_to(foot) > TerrainChunk.CHUNK_M:
			continue
		for i in ch.trees.size():
			var root := ch.tree_base(i)
			if root.distance_to(foot) < 9.0:
				best = maxf(best, float((ch.trees[i] as Array)[1]) - (foot - root).dot(ch.tree_up(i)))
	return maxf(best, 0.0)


## The fire's FireStore state, for a lit fire node.
static func state_of(fire: Node3D) -> String:
	return str(FireStore.store_of(fire).get("state", "flames")) if not FireStore.store_of(fire).is_empty() else ("flames" if fire.get_meta("lit", true) else "out")


## The weather at the player, for the columns near it (Main sets these
## each frame: the wind, the rain, whether it is a still dawn).
static var wind := Vector3.ZERO
static var rain_mm_h := 0.0
static var calm_dawn := false
## The sun's elevation and the morning here, and the world's day (the
## swifts' clock).
static var sun_deg := 30.0
static var morning := false
static var days := 0.0


## A hearth's column, every frame, from Campfire.flicker (meta "smoke" on
## the fire: its scale; Campfire.build gives every fire 1.0).
static func tick_fire(fire: Node3D) -> void:
	if not ON or not fire.has_meta("smoke"):
		return
	var col = fire.get_meta("smoke_col") if fire.has_meta("smoke_col") else null
	if col == null or not is_instance_valid(col):
		col = column(fire, "Smoke")
		fire.set_meta("smoke_col", col)
	var up := fire.global_basis.y.normalized()
	var foot := fire.global_position + up * 0.4
	# A delve's hearth breathes out of its stack on the ground above.
	var st = fire.get_meta("smoke_stack") if fire.has_meta("smoke_stack") else null
	if st != null and is_instance_valid(st):
		up = (st as Node3D).global_basis.y.normalized()
		foot = (st as Node3D).global_position + up * float((st as Node3D).get_meta("mouth", 1.0))
		# At night a lit hearth below shows as a faint glow at the stack's
		# mouth (outlets.night_mouth).
		var mouth := (st as Node3D).get_node_or_null("Mouth") as MeshInstance3D
		if mouth != null and bool(((D.get("outlets", {}) as Dictionary).get("night_mouth", {}) as Dictionary).get("glow", true)):
			var lit := state_of(fire) in ["flames", "low", "flare"]
			var want := Color(0.01, 0.01, 0.02).lerp(Color(0.55, 0.16, 0.04), Campfire.night * (1.0 if lit else 0.0))
			var mm := mouth.material_override as StandardMaterial3D
			if mm != null and not mm.albedo_color.is_equal_approx(want):
				mm = mm.duplicate()
				mm.albedo_color = want
				mm.emission_enabled = want.r > 0.05
				mm.emission = want
				mouth.material_override = mm
	var state := state_of(fire)
	# The crowns over it (looked up once; a stack's mouth is above them).
	if not fire.has_meta("smoke_shelter") and (st != null or Wind.chunks != null):
		fire.set_meta("smoke_shelter", 0.0 if st != null else shelter_over(foot))
	update(col, foot, up, state, wind, rain_mm_h, Campfire.night, calm_dawn, float(fire.get_meta("smoke")), float(fire.get_meta("smoke_shelter", 0.0)))
	# The hearth's last warm day (the swifts read it), and the flock.
	var stay: Array = (SW.get("lit_below", {}) as Dictionary).get("stay_away_states", ["flames", "flare", "low", "embers"])
	var store := FireStore.store_of(fire)
	var warm := stay.has(state)
	if warm and not store.is_empty():
		store["last_warm"] = days
	var fl = fire.get_meta("swifts") if fire.has_meta("swifts") else null
	if fl != null and is_instance_valid(fl):
		var cold := days - float(store.get("last_warm", -1.0e9)) if not store.is_empty() else 1.0e9
		fly_swifts(fl, swift_mode(sun_deg, morning, cold if not warm else 0.0, warm), Time.get_ticks_msec() / 1000.0)


## A flame's column scale (hearth.by_flame): `size` the flame against a
## campfire's (1.0), the column size^exponent of the by_state row.
static func flame_scale(size: float) -> float:
	return pow(maxf(size, 0.0), float((H.get("by_flame", {}) as Dictionary).get("exponent", 2.0)))


## A small fire's column this frame (Mike, 3 Oct: every fire smokes by its
## flame's size): a torch, a lamp, the pipe's brand. `holder` keeps it (meta
## "smoke_col"; the column is its child, so it hides with it); its foot at
## scene `foot`, up `up`; `size` the flame against a campfire's; `state` a
## by_state row ("out" hides it); `air` more wind (a torch's own motion).
static func tick_flame(holder: Node3D, foot: Vector3, up: Vector3, size: float, state := "flames", air := Vector3.ZERO) -> void:
	if not ON:
		return
	var col = holder.get_meta("smoke_col") if holder.has_meta("smoke_col") else null
	if col == null or not is_instance_valid(col):
		if state == "out":
			return
		col = column(holder, "Smoke")
		holder.set_meta("smoke_col", col)
	update(col, foot, up, state, wind + air, rain_mm_h, Campfire.night, calm_dawn, flame_scale(size))


## Where a delve's hearth breathes (outlets.by_ruin): the stack form for a
## ruin's kind (Ruins.Kind, lowercased: barrow, tomb, castle...).
static func stack_form(ruin_kind: String) -> String:
	var by: Dictionary = (D.get("outlets", {}) as Dictionary).get("by_ruin", {})
	return str(by.get(ruin_kind, by.get("default", "mound_vent")))


## A stack over a delve's hearth (§CV.3), standing on the ground at scene
## `foot` (its up `up`), of `form` (outlets.forms: height_m, width_m,
## soot_lip): a stone-lined shaft with a black, sooted lip and a dark
## mouth, so it reads as a chimney and not a pillar. It collides; it is
## never a way in (outlets.passable). Returns the stack node; its meta
## "mouth" is the mouth's height above its foot.
static func stack(parent: Node3D, foot: Vector3, up: Vector3, form: String, seed_value: int) -> Node3D:
	var O: Dictionary = D.get("outlets", {})
	var f: Dictionary = (O.get("forms", {}) as Dictionary).get(form, {})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hr: Array = f.get("height_m", [0.8, 1.4])
	var h := maxf(rng.randf_range(float(hr[0]), float(hr[1])), 0.3)
	var w := float(f.get("width_m", 0.9))
	var n := Node3D.new()
	n.name = "Stack"
	parent.add_child(n)
	n.global_position = foot
	var fwd := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	n.global_basis = Basis.looking_at(fwd, up)
	var stone: Color = RuinBuilder.STONES[rng.randi() % RuinBuilder.STONES.size()]
	var shaft := MeshInstance3D.new()
	shaft.mesh = RuinBuilder.rock_mesh(Vector3(w * 1.25, h + 0.4, w * 1.25), seed_value, stone, true)
	shaft.material_override = RuinBuilder.material()
	shaft.position = Vector3(0, (h + 0.4) * 0.5 - 0.4, 0)
	n.add_child(shaft)
	var soot := Color(str((O.get("soot", {}) as Dictionary).get("colour", "#0A0C20")))
	if bool(f.get("soot_lip", true)):
		var lip := CreatureBodies.cone(n, w * 0.68, w * 0.62, 0.22, Vector3(0, h + 0.05, 0), soot)
		lip.name = "Lip"
	# The dark mouth.
	var mouth := CreatureBodies.cone(n, w * 0.42, w * 0.42, 0.04, Vector3(0, h + 0.17, 0), Color(0.01, 0.01, 0.02))
	mouth.name = "Mouth"
	var body := PropCollision.body(n)
	PropCollision.capsule(body, Transform3D(Basis(), Vector3(0, h * 0.5, 0)), w * 0.62, h + 0.3)
	n.set_meta("mouth", h + 0.2)
	n.set_meta("form", form)
	return n


## Far hearths (§CV.1, hearth.far): the columns of the living camps the
## world keeps (inhabited ruins, lived nests) within far.seen_to_m that
## aren't built here, drawn from their fire's state in the sim (FireStore's
## store; a camp nobody has visited burns, as its sim starts), leaning with
## the weather's wind there, at least far.min_px pixels wide. Main calls it
## every frame; the list is gathered every FAR_EVERY_S.
const FAR_EVERY_S := 0.5
const FAR_MAX := 12
static var _far: Array = [] # [dir, state, wind] per far hearth
static var _far_cols: Array[Node3D] = []
static var _far_t := 0.0
static var _fire_dirs := {}


static func far_columns(main: Node, pd: Vector3, delta: float) -> void:
	if not ON:
		return
	var world = main.world
	var far: Dictionary = H.get("far", {})
	if not bool(far.get("from_sim_state", true)):
		return
	var seen := float(far.get("seen_to_m", 3200.0))
	_far_t -= delta
	if _far_t <= 0.0:
		_far_t = FAR_EVERY_S
		_far = far_hearths(main, pd, seen)
	while _far_cols.size() < mini(_far.size(), FAR_MAX):
		var c := column(main, "FarSmoke%d" % _far_cols.size())
		_far_cols.append(c)
	var cam: Camera3D = main.get_viewport().get_camera_3d()
	var px_m := 2.0 * tan(deg_to_rad((cam.fov if cam else 78.0) * 0.5)) / 480.0
	for i in _far_cols.size():
		var col := _far_cols[i]
		if i >= _far.size():
			col.visible = false
			continue
		var f: Array = _far[i]
		var d: Vector3 = f[0]
		var foot: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d) + 0.4)
		update(col, foot, d, str(f[1]), f[2], rain_mm_h, Campfire.night, false)
		if col.visible:
			var m: ShaderMaterial = col.get_meta("mat")
			var dist := foot.distance_to(cam.global_position) if cam else 1000.0
			m.set_shader_parameter("width_m", maxf(float(m.get_shader_parameter("width_m")), float(far.get("min_px", 2)) * px_m * dist))


## The far hearths round `pd` within `seen` m that aren't built here:
## [dir, state, wind] each, nearest first.
static func far_hearths(main: Node, pd: Vector3, seen: float) -> Array:
	var world = main.world
	var map: PlanetData = world.planet
	var out: Array = []
	var dirs: Array = []
	for site in Ruins.near(map, pd, seen):
		if Ruins.inhabited(site) or Overrun.settled(site):
			# (Laying a ruin out to find its fire is slow: once per ruin.)
			var k := int(site.seed)
			if not _fire_dirs.has(k):
				_fire_dirs[k] = Camps.ruin_fire_dir(map, site)
			dirs.append(_fire_dirs[k])
	for n in Nests.near(pd, seen):
		if str(n.state) == "lived" and n.hearth != Vector3.ZERO:
			dirs.append(n.hearth)
	for d in dirs:
		var dm := CubeSphere.surface_distance_m(d, pd)
		if dm > seen or dm < Camps.BUILD_M:
			continue
		var st: Dictionary = FireStore.stores.get(FireStore.key_of(d), {})
		var state := str(st.get("state", "flames"))
		var e: float = world.surface_elevation(d)
		var w: Vector3 = world.weather.local_weather(d, e).get("wind", Vector3.ZERO) if world.weather != null else Vector3.ZERO
		out.append([d, state, w, dm])
	out.sort_custom(func(a, b): return float(a[3]) < float(b[3]))
	return out


# --- Swifts (§CV.5, smoke.json swifts) -------------------------------------

static var SW: Dictionary = D.get("swifts", {})
static var _bird_quad: QuadMesh


## Does the stack over `site`'s hearth at `d` hold a flock? A form wide
## enough (swifts.forms, min_width_m), a climate that suits (climate:
## temp_c the annual mean, moisture), share_of_stacks of the rest (seeded
## by the stack), and not over an overrun delve (overrun.roost false).
static func swifts_roost(map: PlanetData, d: Vector3, form: String, site: Dictionary) -> bool:
	if not (SW.get("forms", []) as Array).has(form):
		return false
	var f: Dictionary = ((D.get("outlets", {}) as Dictionary).get("forms", {}) as Dictionary).get(form, {})
	if float(f.get("width_m", 0.0)) < float(SW.get("min_width_m", 0.9)):
		return false
	var cl: Dictionary = SW.get("climate", {})
	var t := map.sample(map.temp_c, d)
	var m := map.sample(map.moisture, d)
	var tr: Array = cl.get("temp_c", [8, 30])
	var mr: Array = cl.get("moisture", [0.3, 1.0])
	if t < float(tr[0]) or t > float(tr[1]) or m < float(mr[0]) or m > float(mr[1]):
		return false
	if not bool((SW.get("overrun", {}) as Dictionary).get("roost", false)) and not site.is_empty() and Overrun.is_overrun(site):
		return false
	var h := float(posmod(hash([d, "swifts"]), 1000)) / 1000.0
	return h < float(SW.get("share_of_stacks", 0.6))


## A flock at `stack` (Node3D, meta "mouth"): flock birds as small dark
## billboards (a MultiMesh); fly_swifts() moves them.
static func swift_flock(stack: Node3D, seed_value: int) -> MultiMeshInstance3D:
	if _bird_quad == null:
		_bird_quad = QuadMesh.new()
		_bird_quad.size = Vector2(0.32, 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var fr: Array = SW.get("flock", [12, 60])
	var n := rng.randi_range(int(fr[0]), int(fr[1]))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bird_quad
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.name = "Swifts"
	mi.multimesh = mm
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str((SW.get("species", {}) as Dictionary).get("color", "#2A2A34")))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.extra_cull_margin = 400.0
	var seeds := PackedFloat32Array()
	for i in n:
		seeds.append_array([rng.randf(), rng.randf(), rng.randf()])
	mi.set_meta("seeds", seeds)
	mi.set_meta("gone_until", -1.0)
	stack.add_child(mi)
	return mi


## Where the flock is this frame: "hunt" by day over the ruin, "circle"
## then "enter" at dusk (the sun between dusk.sun_deg), "in" at night,
## "leave" at dawn (pouring out over leave_game_min), "away" while the
## hearth below burns (they leave at once) and until it has been cold
## lit_below.return_after_cold_game_days. `sun_deg` the sun's elevation,
## `morning` before noon, `cold_days` since the hearth was last warm.
static func swift_mode(sun_deg: float, morning: bool, cold_days: float, lit: bool) -> Dictionary:
	var lb: Dictionary = SW.get("lit_below", {})
	if lit or cold_days < float(lb.get("return_after_cold_game_days", 10)):
		return {"mode": "away", "k": 1.0}
	var dk: Array = (SW.get("dusk", {}) as Dictionary).get("sun_deg", [2.0, -4.0])
	var hi := float(dk[0])
	var lo := float(dk[1])
	if sun_deg >= hi:
		return {"mode": "hunt", "k": 0.0}
	if sun_deg <= lo:
		return {"mode": "in", "k": 1.0}
	var p := (hi - sun_deg) / maxf(hi - lo, 0.01)
	if morning:
		# Dawn: they pour back out as the light comes.
		return {"mode": "leave", "k": 1.0 - p}
	var circle := float((SW.get("dusk", {}) as Dictionary).get("circle_game_min", 20))
	var enter := float((SW.get("dusk", {}) as Dictionary).get("enter_game_min", 10))
	var split := circle / maxf(circle + enter, 1.0)
	if p < split:
		return {"mode": "circle", "k": p / split}
	return {"mode": "enter", "k": (p - split) / maxf(1.0 - split, 0.01)}


## Move a flock (every frame): its birds by swift_mode, round the stack's
## mouth. Returns how many are out.
static func fly_swifts(flock: MultiMeshInstance3D, mode: Dictionary, time: float) -> int:
	var stack := flock.get_parent() as Node3D
	var up := stack.global_basis.y.normalized()
	var mouth := stack.global_position + up * float(stack.get_meta("mouth", 1.0))
	var e1 := stack.global_basis.x.normalized()
	var e2 := up.cross(e1).normalized()
	var seeds: PackedFloat32Array = flock.get_meta("seeds")
	var mm := flock.multimesh
	var rng_range := float(SW.get("day_range_m", 300.0))
	var out := 0
	var md := str(mode.mode)
	var k := float(mode.k)
	for i in mm.instance_count:
		var a := seeds[i * 3]
		var b := seeds[i * 3 + 1]
		var c := seeds[i * 3 + 2]
		# Wide hunting circles by day, a tightening wheel at dusk.
		var r_day := lerpf(40.0, rng_range, b)
		var r_dusk := lerpf(6.0, 18.0, b)
		var h_day := lerpf(15.0, 55.0, c)
		var h_dusk := lerpf(8.0, 24.0, c)
		var w := (0.25 + 0.35 * c) * (1.0 if a < 0.5 else -1.0)
		var ang := time * w + a * TAU
		var r := r_day
		var h := h_day
		var shown := true
		match md:
			"hunt":
				pass
			"circle":
				r = lerpf(r_day * 0.4, r_dusk, k)
				h = lerpf(h_day, h_dusk, k)
				ang = time * (1.4 + c) * signf(w) + a * TAU
			"enter", "leave":
				# One at a time down (or up out of) the stack: bird i's turn
				# at its seed through the window.
				var turn := a
				var into := k if md == "enter" else 1.0 - k
				if into > turn:
					var dive := clampf((into - turn) * 6.0, 0.0, 1.0)
					r = lerpf(r_dusk, 0.0, dive)
					h = lerpf(h_dusk, -0.5, dive)
					shown = dive < 1.0
				else:
					r = r_dusk
					h = h_dusk
				ang = time * (1.4 + c) * signf(w) + a * TAU
			"in", "away":
				shown = false
		var p := mouth + (e1 * cos(ang) + e2 * sin(ang)) * r + up * h
		var xf := Transform3D(Basis(), p)
		if not shown:
			xf = Transform3D(Basis().scaled(Vector3.ZERO), mouth)
		else:
			out += 1
		mm.set_instance_transform(i, xf)
	flock.visible = out > 0
	return out


# --- The wildfire plume (§CV.6, smoke.json wildfire_plume) --------------------

static var WP: Dictionary = D.get("wildfire_plume", {})
## How long a wildfire burns and smokes after it starts (game hours): the
## sim lays its scar at once (CampSim.start_fire), so the plume stands over
## a fresh scar for this long, thinning toward the end. A first guess.
const PLUME_GAME_H := 6.0
static var _plume: Node3D


## The plume over the nearest burning wildfire within seen_to_m: wide,
## tall and dark (wildfire_plume), leaning with the wind, its base lit
## orange at night. Main calls it every frame.
static func plumes(main: Node, pd: Vector3) -> void:
	if not ON:
		return
	var world = main.world
	var seen := float(WP.get("seen_to_m", 7500.0))
	var best := {}
	var best_m := seen
	for scar in CampSim.scars:
		var age_h := (float(world.days) - float(scar.day)) * 24.0
		if age_h < 0.0 or age_h > PLUME_GAME_H:
			continue
		var a: Array = scar.dir
		var c := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		var dm := CubeSphere.surface_distance_m(c, pd)
		if dm < best_m:
			best_m = dm
			best = {"dir": c, "burn": 1.0 - smoothstep(PLUME_GAME_H * 0.6, PLUME_GAME_H, age_h)}
	if _plume == null or not is_instance_valid(_plume):
		_plume = column(main, "WildfirePlume", {"colour_near": WP.get("colour_near", "#3A3460"), "colour_far": WP.get("colour_far", "#6A6CA8"), "colour_shade": "#1A1838"})
		var m0: ShaderMaterial = _plume.get_meta("mat")
		m0.set_shader_parameter("fire_lit_m", 80.0)
		m0.set_shader_parameter("far_m", seen)
	if best.is_empty():
		_plume.visible = false
		return
	var d: Vector3 = best.dir
	var foot: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	var w: Vector3 = world.weather.local_weather(d, 0.0).get("wind", Vector3.ZERO) if world.weather != null else Vector3.ZERO
	var m: ShaderMaterial = _plume.get_meta("mat")
	var flat := w - d * w.dot(d)
	var deg := minf(flat.length() * float(WP.get("lean_deg_per_mps", 10.0)), 70.0)
	_plume.visible = true
	m.set_shader_parameter("base", foot)
	m.set_shader_parameter("up_dir", d)
	m.set_shader_parameter("lean", flat.normalized() * tan(deg_to_rad(deg)) if flat.length() > 0.5 else Vector3.ZERO)
	m.set_shader_parameter("top_m", float(WP.get("top_m", 400.0)) * float(best.burn))
	m.set_shader_parameter("width_m", float(WP.get("width_m", 120.0)) * 0.5)
	m.set_shader_parameter("density", float(best.burn))
	m.set_shader_parameter("pool", 0.0)
	# At night the column itself is unlit; its base glows orange.
	m.set_shader_parameter("night", Campfire.night if bool(WP.get("night_base_glow", true)) else 0.0)
	_plume.set_meta("burning_at", d)
