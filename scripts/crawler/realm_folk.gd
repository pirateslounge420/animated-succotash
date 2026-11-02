class_name RealmFolk
extends Node
## The bard and the oracle in every realm (design §GO.10, queue 125;
## data/realm_folk.json). Both mute (§ED): they never speak; the log says
## only what they do. Only the desert is built, so only the desert has
## them yet.
##
##   the bard     sits by the realm's ruin playing their instrument on a
##                loop you hear from far off (louder as you come in; silent
##                past bard.hear_m); interact and they teach you it as a
##                technique (CrawlerSave.data.band.learned, kept through
##                death and save-and-quit); its material lies beside them
##                (red clay for the desert's clay ocarina): take some home,
##                set it down in the camp store, and the maker builds it,
##                and a keeper plays it at the evening meal (HubWork,
##                HubWorkView: the camp's band)
##   the oracle   meditates somewhere secluded, with nothing pointing the
##                way (no sound, no light), never within the bard's hearing,
##                away from the hearth and off the path to the ruin;
##                interact: a brief vision (a still in smoke, placeholder
##                art) and they hand you the realm's sacred text for your
##                library (OracleLibrary)
##
## Placed from the realm's seed (the same layout, the same places).

static var D: Dictionary = Tuning.table("realm_folk")

var main: CrawlerMain
var bard: HearthFolk
var oracle: HearthFolk
var clay: Node3D
var _audio: AudioStreamPlayer3D
var _bard_motion: FolkMotion
var _ocarina: MeshInstance3D
var _area: Surface
var _vision_layer: CanvasLayer
var _vision: ColorRect
var _vision_mat: ShaderMaterial
var vision_t := -1.0
var spots := {}
static var _tunes := {}


func setup(p_main: CrawlerMain) -> void:
	name = "RealmFolk"
	main = p_main


static func realm_data(key := "first") -> Dictionary:
	return (D.get("realms", {}) as Dictionary).get(key, {})


static func instrument(id: String) -> Dictionary:
	return (D.get("instruments", {}) as Dictionary).get(id, {})


## The instruments you have learned (the save).
static func learned() -> Array:
	return ((CrawlerSave.data.get("band", {}) as Dictionary).get("learned", []) as Array).duplicate()


static func learn(id: String) -> bool:
	var b: Dictionary = CrawlerSave.data.get("band", {})
	var l: Array = b.get("learned", [])
	if l.has(id):
		return false
	l.append(id)
	b["learned"] = l
	CrawlerSave.data["band"] = b
	CrawlerSave.save()
	return true


# --- Where they are ----------------------------------------------------------------------

## The bard's, the clay's and the oracle's places on realm `area` drawn
## from `seed_value`: {"bard", "clay", "oracle"} (scene positions).
static func place(area: Surface, seed_value: int) -> Dictionary:
	var B: Dictionary = D.get("bard", {})
	var O: Dictionary = D.get("oracle", {})
	var land := area.land
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "realm folk"])
	var mouth: Vector2 = area.stair.get("mouth", land.center) if area.stair is Dictionary and not (area.stair as Dictionary).is_empty() else land.center
	var hp: Vector3 = area.area_hearth.global_position if area.area_hearth != null and area.area_hearth.is_inside_tree() else (area.area_hearth.position if area.area_hearth != null else Vector3(land.center.x, 0.0, land.center.y))
	var hearth := Vector2(hp.x, hp.z)
	var fr: Array = B.get("from_mouth_m", [12.0, 22.0])
	var bard_p := mouth
	for i in 200:
		var a := rng.randf() * TAU
		var q := mouth + Vector2(cos(a), sin(a)) * rng.randf_range(float(fr[0]), float(fr[1]))
		if land.inside(q, 8.0) and land.slope_at(q.x, q.y) < 0.25 and land.in_wash(q) < 0.05:
			bard_p = q
			break
	var mt := float(B.get("material_m", 3.0))
	var clay_p := bard_p + Vector2(mt, 0.0).rotated(rng.randf() * TAU)
	var hear := float(B.get("hear_m", 120.0)) + float(O.get("clear_of_bard_m", 15.0))
	var best := Vector2.INF
	var best_score := -1e9
	for i in 1500:
		var a2 := rng.randf() * TAU
		var r := land.r_in * sqrt(rng.randf())
		var q2 := land.center + Vector2(cos(a2), sin(a2)) * r
		if not land.inside(q2, 10.0) or land.slope_at(q2.x, q2.y) > 0.3 or land.in_wash(q2) > 0.05:
			continue
		var d_bard := q2.distance_to(bard_p)
		var d_hearth := q2.distance_to(hearth)
		var d_path := _off_segment(q2, hearth, mouth)
		var out := r / maxf(land.r_in, 1.0)
		var score := minf(d_bard - hear, minf(d_hearth - float(O.get("from_hearth_m", 70.0)), d_path - float(O.get("off_path_m", 40.0)))) + 40.0 * minf(out - float(O.get("edge_share", 0.55)), 0.0)
		if score > best_score:
			best_score = score
			best = q2
	var h := func(p: Vector2) -> Vector3: return Vector3(p.x, land.height_at(p.x, p.y), p.y)
	return {"bard": h.call(bard_p), "clay": h.call(clay_p), "oracle": h.call(best), "score": best_score}


static func _off_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _process(delta: float) -> void:
	if main == null:
		return
	tick(delta)


## One step (the checks drive it with their own delta).
func tick(delta: float) -> void:
	_ensure()
	_hear()
	if _bard_motion != null and bard != null and bard.is_inside_tree():
		# Both hands up to the ocarina at the lips, swaying a little.
		var face := bard.global_position + Vector3(0, 1.05, 0) + bard.front() * 0.28
		var sway := 0.02 * sin(Time.get_ticks_msec() * 0.003)
		_bard_motion.reach_point(0, face + Vector3(sway, 0, 0))
		_bard_motion.reach_point(1, face - Vector3(sway, 0, 0))
		_bard_motion.update(delta)
		if _ocarina != null:
			_ocarina.global_position = face
	_vision_tick(delta)


func _ensure() -> void:
	var area := main.area_node
	if area == null or not is_instance_valid(area) or area.land == null or area != main.surface:
		return
	if _area == area and bard != null and is_instance_valid(bard):
		return
	_area = area
	var R := realm_data("first")
	if R.is_empty():
		return
	spots = place(area, area.seed_value)
	var B: Dictionary = D.get("bard", {})
	var O: Dictionary = D.get("oracle", {})
	# The bard on a stone, facing the ruin's mouth.
	var bp: Vector3 = area.to_local(spots.bard)
	var mouth: Vector2 = area.stair.get("mouth", area.land.center) if area.stair is Dictionary and not (area.stair as Dictionary).is_empty() else area.land.center
	var yaw := FolkMotion.yaw_of(Vector3(mouth.x - bp.x, 0.0, mouth.y - bp.z))
	var bc: Array = B.get("cloak", ["#6a3a5a", "#8a5a7a"])
	_seat(area, bp, yaw)
	bard = HearthFolk.make(area, "Bard", bp, yaw, 1.6, [Color(str(bc[0])), Color(str(bc[1]))], "")
	bard.hold("")
	_bard_motion = FolkMotion.new(bard)
	_bard_motion.ground = area.land.height_at
	_ocarina = MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.05
	om.height = 0.07
	_ocarina.mesh = om
	_ocarina.material_override = _mat("#a8603a")
	area.add_child(_ocarina)
	var ins := str(R.get("instrument", ""))
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "BardTune"
	_audio.stream = tune_stream(ins)
	_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_audio.bus = AudioMix.bus("ambience")
	bard.add_child(_audio)
	_audio.position = Vector3(0, 1.1, 0)
	_audio.play()
	# Its material beside them: a patch of red clay to dig a lump from.
	var mat := str(instrument(ins).get("material", ""))
	clay = Node3D.new()
	clay.name = "Material_" + mat
	clay.set_meta("material", mat)
	area.add_child(clay)
	clay.position = area.to_local(spots.clay)
	var col := str(((D.get("materials", {}) as Dictionary).get(mat, {}) as Dictionary).get("color", "#a8402a"))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.7
	cm.height = 0.1
	var cmi := MeshInstance3D.new()
	cmi.mesh = cm
	cmi.material_override = _mat(col)
	clay.add_child(cmi)
	# The oracle, sat on the ground in meditation, facing away from the way in.
	var opos: Vector3 = area.to_local(spots.oracle)
	var oc: Array = O.get("cloak", ["#3a3a4a", "#5a5a6a"])
	var oy := FolkMotion.yaw_of(Vector3(opos.x - area.land.center.x, 0.0, opos.z - area.land.center.y))
	_seat(area, opos, oy)
	oracle = HearthFolk.make(area, "Oracle", opos, oy, 1.55, [Color(str(oc[0])), Color(str(oc[1]))], "")
	oracle.hold("")
	print("[realm folk] the bard at %s (%.0f m from the ruin), the oracle at %s (%.0f m from the bard)" % [str(Vector2(bp.x, bp.z).snapped(Vector2.ONE)), Vector2(bp.x, bp.z).distance_to(mouth), str(Vector2(opos.x, opos.z).snapped(Vector2.ONE)), Vector2(opos.x, opos.z).distance_to(Vector2(bp.x, bp.z))])


func _seat(area: Surface, at: Vector3, yaw: float) -> void:
	var s := HearthFolk.seat(at, yaw)
	var b := BoxMesh.new()
	b.size = s.size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = _mat("#5a5c78")
	mi.transform = s.xf
	area.add_child(mi)


func _mat(c: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = 0.7
	return m


# --- The bard's tune -------------------------------------------------------------------------

## How loud the bard is `d` m off (dB; -80 past hear_m): full at ref_m,
## falling as the distance grows (inverse distance).
static func heard_db(d: float) -> float:
	var B: Dictionary = D.get("bard", {})
	if d > float(B.get("hear_m", 120.0)):
		return -80.0
	return float(B.get("base_db", -2.0)) - 20.0 * log(maxf(d, float(B.get("ref_m", 8.0))) / float(B.get("ref_m", 8.0))) / log(10.0)


func _hear() -> void:
	if _audio == null or not is_instance_valid(_audio) or not _audio.is_inside_tree():
		return
	var cam: Camera3D = main.player.camera() if main.player != null else null
	var you := cam.global_position if cam != null else main.player.global_position
	_audio.volume_db = heard_db(you.distance_to(_audio.global_position))


## Instrument `id`'s loop: a breathy flute voice over its tune.
static func tune_stream(id: String) -> AudioStream:
	if _tunes.has(id):
		return _tunes[id]
	var T: Dictionary = instrument(id).get("tune", {})
	var rate := 22050
	var beat := 60.0 / maxf(float(T.get("bpm", 84.0)), 20.0)
	var notes: Array = T.get("notes", [0, 3, 5, 7])
	var n := int(notes.size() * beat * rate)
	var root := float(T.get("root_hz", 523.25))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var noise := 0.0
	for i in n:
		var t := float(i) / rate
		var b := int(t / beat)
		var tb := t - b * beat
		var v := 0.0
		var note: Variant = notes[b % notes.size()]
		noise = noise * 0.9 + rng.randf_range(-1.0, 1.0) * 0.1
		if note != null:
			var f := root * pow(2.0, float(note) / 12.0) * (1.0 + 0.004 * sin(TAU * 5.5 * t))
			var e := minf(tb / 0.04, 1.0) * clampf((beat - tb) / 0.12, 0.0, 1.0)
			v = e * (0.3 * sin(TAU * f * t) + 0.04 * sin(TAU * 2.0 * f * t) + 0.12 * noise)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	_tunes[id] = w
	return w


## Is the bard heard where you stand (above -60 dB)?
func bard_heard() -> bool:
	return _audio != null and _audio.playing and _audio.volume_db > -60.0


# --- Interact ----------------------------------------------------------------------------------

## The bard teaches, the clay is dug, the oracle gives the text. True if
## it took the press.
func interact() -> bool:
	if main == null or main.leaving or not (main.on_surface and main.surface == main.area_node) or _area == null:
		return false
	var p := main.player.global_position
	var B: Dictionary = D.get("bard", {})
	var O: Dictionary = D.get("oracle", {})
	var R := realm_data("first")
	if bard != null and _flat(p, bard.global_position) <= float(B.get("reach_m", 2.5)):
		var id := str(R.get("instrument", ""))
		var nm := str(instrument(id).get("name", id))
		if learn(id):
			GameLog.add(str(B.get("log_learn", "The bard teaches you the {name}.")).format({"name": nm}), "world")
		else:
			GameLog.add(str(B.get("log_known", "You already know the {name}.")).format({"name": nm}), "world")
		return true
	if clay != null and _flat(p, clay.global_position) <= 1.8:
		var mat := str(clay.get_meta("material", ""))
		var mn := str(((D.get("materials", {}) as Dictionary).get(mat, {}) as Dictionary).get("name", mat))
		var inv := main.player.inventory
		for it in inv.carried:
			if it is Dictionary and str(it.get("kind", "")) == "haul" and str(it.get("what", "")) == mat:
				GameLog.add(str(B.get("log_material_have", "You already carry some {name}.")).format({"name": mn}), "world")
				return true
		if not inv.add(Inventory.make("haul", {"what": mat, "title": mn.capitalize(), "color": str(((D.get("materials", {}) as Dictionary).get(mat, {}) as Dictionary).get("color", "#a8402a"))})):
			GameLog.add("Your pack is full.", "world")
			return true
		GameLog.add(str(B.get("log_material", "You dig a lump of {name}.")).format({"name": mn}), "world")
		return true
	if oracle != null and _flat(p, oracle.global_position) <= float(O.get("reach_m", 2.2)):
		var text := str(R.get("text", ""))
		show_vision()
		if OracleLibrary.give(text):
			GameLog.add(str(O.get("log_text", "The oracle hands you the {title}.")).format({"title": OracleLibrary.title(text)}), "world")
		else:
			GameLog.add(str(O.get("log_again", "The oracle sits in silence.")), "world")
		return true
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- The vision ------------------------------------------------------------------------------

## A still in smoke (placeholder art): it fades in, holds and fades out
## over oracle.vision_s.
func show_vision() -> void:
	if _vision == null:
		_vision_layer = CanvasLayer.new()
		_vision_layer.name = "Vision"
		_vision_layer.layer = 6
		add_child(_vision_layer)
		_vision = ColorRect.new()
		_vision.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vision.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float show = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec2 uv = UV * vec2(1.6, 1.0);
	float s = fbm(uv * 3.0 + fbm(uv * 2.0) * 1.5);
	vec2 c = UV - vec2(0.5, 0.45);
	float figure = smoothstep(0.16, 0.1, length(c * vec2(1.4, 1.0))) * 0.5 + smoothstep(0.32, 0.2, length((UV - vec2(0.5, 0.78)) * vec2(1.0, 1.6))) * 0.4;
	float vig = smoothstep(0.85, 0.2, length(UV - 0.5));
	vec3 col = mix(vec3(0.05, 0.04, 0.10), vec3(0.62, 0.58, 0.78), s * vig) + vec3(0.85, 0.82, 0.95) * figure * s;
	COLOR = vec4(col, show);
}
"""
		_vision_mat = ShaderMaterial.new()
		_vision_mat.shader = sh
		_vision.material = _vision_mat
		_vision_layer.add_child(_vision)
	vision_t = 0.0


## How much of the vision shows now (0..1).
func vision_shown() -> float:
	if vision_t < 0.0:
		return 0.0
	var dur := float((D.get("oracle", {}) as Dictionary).get("vision_s", 6.0))
	return clampf(minf(vision_t / 1.0, (dur - vision_t) / 1.0), 0.0, 1.0)


func _vision_tick(delta: float) -> void:
	if vision_t < 0.0:
		return
	vision_t += delta
	var dur := float((D.get("oracle", {}) as Dictionary).get("vision_s", 6.0))
	if vision_t >= dur:
		vision_t = -1.0
	if _vision_mat != null:
		_vision_mat.set_shader_parameter("show", vision_shown())
		_vision.visible = vision_t >= 0.0
