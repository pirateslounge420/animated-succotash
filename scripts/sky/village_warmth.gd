class_name VillageWarmth
extends RefCounted
## A lit village goes amber; the wild stays blue (design 5 Oct §EE.1,
## data/look.json village_warmth). Blue owns the frame by default, not
## always: warm light is still only firelight, and only what gives light
## glows.
##
## Each village registers its middle, its radius and its hearths; whoever
## owns the hearths (Villages) says which are lit. Its lit fraction (lit
## hearths / all, 0-1) is the one number the lighting and the grade read:
##   - every LIT hearth warms a patch round it (hearth_radius_m): the
##     night's blue pull on surfaces eases there and the ground takes a
##     pool of firelight (look.gdshaderinc look_warm, look_warm_pool_light),
##     so a village warms one house at a time;
##   - the lit fraction eases the night pull across the whole village
##     (village_ease at full) and warms the grade while you stand in it
##     (PostGrade.set_warmth: grade_warmth here).
## A dead village (nothing lit) and the wild between villages read 0
## everywhere: the frame is exactly as before.
##
## update() runs each frame (main): the nearest village and up to
## max_hearths lit hearths nearest the eye go to the shaders as global
## uniforms (look_warm_village, look_warm_lit, look_warm_tex,
## look_warm_count, look_warm_ease, look_warm_pool).

static var W: Dictionary = Tuning.section("look", "village_warmth")
const TEX_W := 16

## id -> {"dir": Vector3, "r": float (its middle's distance from the
## planet's centre), "radius_m": float, "hearths": [[dir, r], ...],
## "lit": PackedByteArray (1 lit, 0 cold, per hearth)}
static var villages := {}
## The grade's warmth from the last update() (0-1; checks read it).
static var grade_warmth := 0.0
static var _img: Image
static var _tex: ImageTexture
static var _consts_set := false


## Add (or replace) a village: its middle `dir` at radius `r` from the
## planet's centre, its radius (m), and its hearths ([dir, r] each). All
## start cold.
static func register(id: String, dir: Vector3, r: float, radius_m: float, hearths: Array) -> void:
	var lit := PackedByteArray()
	lit.resize(hearths.size())
	var old: Dictionary = villages.get(id, {})
	if not old.is_empty() and (old.lit as PackedByteArray).size() == hearths.size():
		lit = old.lit
	villages[id] = {"dir": dir, "r": r, "radius_m": radius_m, "hearths": hearths, "lit": lit}


static func forget(id: String) -> void:
	villages.erase(id)


## Hearth `i` of village `id` lit or cold.
static func set_hearth(id: String, i: int, lit: bool) -> void:
	var v: Dictionary = villages.get(id, {})
	if v.is_empty():
		return
	var arr: PackedByteArray = v.lit
	if i >= 0 and i < arr.size():
		arr[i] = 1 if lit else 0
		v.lit = arr


## Light the first round(f x n) hearths and put out the rest (tools, and a
## quick way to set a village's warmth by its fraction).
static func set_lit(id: String, f: float) -> void:
	var v: Dictionary = villages.get(id, {})
	if v.is_empty():
		return
	var arr: PackedByteArray = v.lit
	var n := roundi(clampf(f, 0.0, 1.0) * arr.size())
	for i in arr.size():
		arr[i] = 1 if i < n else 0
	v.lit = arr


## The village's lit fraction, 0 (dead) to 1 (every hearth lit).
static func lit_fraction(id: String) -> float:
	var v: Dictionary = villages.get(id, {})
	if v.is_empty():
		return 0.0
	var arr: PackedByteArray = v.lit
	if arr.is_empty():
		return 0.0
	var n := 0
	for b in arr:
		n += b
	return float(n) / arr.size()


## Push this frame's warmth to the shaders for the eye at `cam_pos`
## (scene); returns the grade's warmth (PostGrade.set_warmth).
static func update(world, cam_pos: Vector3) -> float:
	_consts()
	var cam_dir: Vector3 = world.dir_of(cam_pos)
	var best_id := ""
	var best_gap := INF
	for id in villages:
		var v: Dictionary = villages[id]
		var gap := CubeSphere.surface_distance_m(cam_dir, v.dir) - float(v.radius_m)
		if gap < best_gap:
			best_gap = gap
			best_id = id
	grade_warmth = 0.0
	var village := Vector4.ZERO
	var lit_f := 0.0
	if best_id != "":
		var v: Dictionary = villages[best_id]
		var mid: Vector3 = world.to_scene(v.dir, float(v.r))
		village = Vector4(mid.x, mid.y, mid.z, float(v.radius_m))
		lit_f = lit_fraction(best_id)
		var cf: Array = W.get("camera_fade", [0.8, 1.4])
		var d := CubeSphere.surface_distance_m(cam_dir, v.dir)
		var rad := float(v.radius_m)
		grade_warmth = lit_f * (1.0 - smoothstep(float(cf[0]) * rad, float(cf[1]) * rad, d))
	# The lit hearths nearest the eye, from every village.
	var lit: Array = []
	for id in villages:
		var v: Dictionary = villages[id]
		var arr: PackedByteArray = v.lit
		for i in arr.size():
			if arr[i] == 0:
				continue
			var h: Array = v.hearths[i]
			lit.append([CubeSphere.surface_distance_m(cam_dir, h[0]), h])
	lit.sort_custom(func(a, b): return a[0] < b[0])
	var n := mini(lit.size(), mini(int(W.get("max_hearths", 16)), TEX_W))
	var hr := float(W.get("hearth_radius_m", 10.0))
	for i in TEX_W:
		if i < n:
			var h: Array = lit[i][1]
			var p: Vector3 = world.to_scene(h[0], float(h[1]) + 1.0)
			_img.set_pixel(i, 0, Color(p.x, p.y, p.z, hr))
		else:
			_img.set_pixel(i, 0, Color(0, 0, 0, 0))
	_tex.update(_img)
	RenderingServer.global_shader_parameter_set("look_warm_village", village)
	RenderingServer.global_shader_parameter_set("look_warm_lit", lit_f)
	RenderingServer.global_shader_parameter_set("look_warm_count", n)
	return grade_warmth


static func _consts() -> void:
	if _consts_set:
		return
	_consts_set = true
	_img = Image.create(TEX_W, 1, false, Image.FORMAT_RGBAF)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("look_warm_tex", _tex)
	RenderingServer.global_shader_parameter_set("look_warm_ease", Vector3(float(W.get("hearth_ease", 0.85)), float(W.get("village_ease", 0.45)), float(W.get("village_fade", 0.3))))
	var pc := Color(str(W.get("pool_color", "#FF8A3C"))).srgb_to_linear()
	RenderingServer.global_shader_parameter_set("look_warm_pool", Vector4(pc.r, pc.g, pc.b, float(W.get("pool_strength", 0.22))))


## How much the night's blue pull eases at `scene_pos` (0-1): the shaders'
## look_warm, on the CPU, for the checks.
static func warm_at(world, scene_pos: Vector3) -> float:
	var d_at: Vector3 = world.dir_of(scene_pos)
	var w := 0.0
	var hr := float(W.get("hearth_radius_m", 10.0))
	for id in villages:
		var v: Dictionary = villages[id]
		var f := lit_fraction(id)
		if f > 0.0:
			var rad := float(v.radius_m)
			var d := CubeSphere.surface_distance_m(d_at, v.dir)
			w = maxf(w, f * float(W.get("village_ease", 0.45)) * (1.0 - smoothstep(rad * (1.0 - float(W.get("village_fade", 0.3))), rad, d)))
		var arr: PackedByteArray = v.lit
		for i in arr.size():
			if arr[i] == 1:
				var dh := CubeSphere.surface_distance_m(d_at, (v.hearths[i] as Array)[0])
				w = maxf(w, float(W.get("hearth_ease", 0.85)) * (1.0 - smoothstep(hr * 0.35, hr, dh)))
	return clampf(w, 0.0, 1.0)
