class_name FirePipe
extends Node
## Sitting by the fire: the pipe, the ember, smoking herbs (design §GO.7,
## queue 124; data/herbs.json). Mike, 1 Nov: sit on a log, pack your pipe,
## light it with an ember from the hearth, just be; each herb from a realm
## its own smoke colour and a gentle sensory effect.
##
## Display only (the queue's rule): no stats, no gates, no doses, no
## preparation. A herb is never used up.
##
##   the seat    a log bench round the hub fire, sat the way §GH sits you at
##               the fire (your view set down and turned to the flames, your
##               body still); no song (the song stays the shaman's)
##   the pipe    with a herb carried, interact: pack the bowl, an ember
##               fetched from the hearth with the tongs, a first puff (the
##               folk's pipe idle, §CY, as the look); then the bowl
##               smoulders in the herb's smoke colour
##   the effect  per herb one or two of: the sky tinted, the music
##               muffled, time a touch slower; rising over onset_s, held
##               for peak_s, falling over fade_s as the bowl burns out
##   standing    a move key or Esc: up off the log, the effect fading out
##               over stand_fade_s to nothing
##   the plants  each herb grows on its realm's floor (the built desert's
##               damiana for now), placed like the key cuttings; take a
##               pinch, the plant stays; growing them at camp is a hook
##               (can_plant), not built

static var D: Dictionary = Tuning.table("herbs")

var main: CrawlerMain
var seated := false
var bench := -1
## "" (sitting, unlit) | "pack" | "ember" | "puff" | "smoke" | "out".
var state := ""
var herb := ""
var _t := 0.0
## Seconds since the pipe was lit (the effect's clock).
var lit_t := 0.0
## The effect now, 0..1 of the herb's peak.
var level := 0.0
var _standing := false
var _stand_t := 0.0
var _stand_from := 0.0
var _stand_herb := ""
var _pick := 0
var _layer: CanvasLayer
var _tint: ColorRect
var _tint_mat: ShaderMaterial
var _view: Node3D
var _pipe: Node3D
var _pinch: MeshInstance3D
var _tongs: Node3D
var _ember: MeshInstance3D
var _bowl_glow: MeshInstance3D
var _smoke: CPUParticles3D
var _exhale: CPUParticles3D
var _lp: AudioEffectLowPassFilter
var _lp_bus := -1
var _plants: Array = []


func setup(p_main: CrawlerMain) -> void:
	name = "FirePipe"
	main = p_main


static func herbs() -> Dictionary:
	return D.get("herbs", {})


static func herb_data(id: String) -> Dictionary:
	return herbs().get(id, {})


static func seat_data() -> Dictionary:
	return D.get("seat", {})


## The hook for growing a herb at camp (§GO.7.3, not built yet).
static func can_plant(_id: String) -> bool:
	return false


## The herbs you carry (their keys, in pack order).
func carried() -> Array:
	var out: Array = []
	if main == null or main.player == null:
		return out
	for it in main.player.inventory.carried:
		if it is Dictionary and str(it.get("kind", "")) == "smoking_herb" and not out.has(str(it.get("herb", ""))):
			out.append(str(it.get("herb", "")))
	return out


static func pinch(id: String) -> Dictionary:
	var h := herb_data(id)
	return Inventory.make("smoking_herb", {"herb": id, "title": str(h.get("name", id)).capitalize(), "color": str(h.get("leaf", "#8a9a3a"))})


func _hub() -> HubCamp:
	return main.surface as HubCamp if main.on_surface else null


## The interact button (CrawlerAreas.interact, first): on a log, light the
## pipe; standing by a bench, sit on it; in a realm, a pinch from a herb
## plant. True if it took the press.
func interact() -> bool:
	if main == null or main.leaving:
		return false
	var hub := _hub()
	if hub != null:
		if seated:
			if state in ["", "out"]:
				_light()
			return true
		var i := near_bench()
		if i >= 0:
			sit(i)
			return true
		return false
	if main.on_surface and main.surface == main.area_node:
		return _take_pinch()
	return false


## The bench you stand by (within seat.reach_m of its log), or -1.
func near_bench() -> int:
	var hub := _hub()
	if hub == null:
		return -1
	var p := main.player.global_position
	var reach := float(seat_data().get("reach_m", 1.3))
	# Nearer the fire or the shaman the button is the song's and his
	# (CrawlerAreas.interact_reach_m): the bench takes it from beyond.
	var song := float(CrawlerAreas.A.get("interact_reach_m", 3.0))
	var fp: Vector3 = hub.camp.pos
	if Vector2(p.x - fp.x, p.z - fp.z).length() <= song or (hub.shaman != null and p.distance_to(hub.shaman.global_position) <= song):
		return -1
	for i in hub.benches.size():
		var b: Vector3 = hub.benches[i].at
		if Vector2(p.x - b.x, p.z - b.z).length() <= reach:
			return i
	return -1


## Down on bench `i`, facing the fire (§GH's sitting: the view set down,
## the body still).
func sit(i: int) -> void:
	var hub := _hub()
	if hub == null or seated:
		return
	seated = true
	bench = i
	state = ""
	_standing = false
	level = 0.0
	var b: Vector3 = hub.benches[i].at
	var fp: Vector3 = hub.camp.pos
	var away := Vector2(b.x - fp.x, b.z - fp.z).normalized()
	var seat := Vector2(b.x, b.z) + away * 0.35
	var eye := float(seat_data().get("eye_m", 1.0))
	var at := Vector3(seat.x, hub.land.height_at(seat.x, seat.y) - (1.55 - eye), seat.y)
	var to := Vector2(fp.x - seat.x, fp.z - seat.y)
	main.player.spawn_flat(at, atan2(-to.x, -to.y), atan2(fp.y + 0.6 - (at.y + 1.55), to.length()))
	main.player.set_physics_process(false)
	var have := carried()
	_pick = 0
	herb = str(have[0]) if not have.is_empty() else ""
	GameLog.add(str(D.get("log_sit", "You sit on the log by the fire.")), "world")
	_ensure_view()


## Up off the log: the effect fades out over stand_fade_s.
func stand(log_it := true) -> void:
	if not seated:
		return
	seated = false
	bench = -1
	if level > 0.0:
		_standing = true
		_stand_t = 0.0
		_stand_from = level
		_stand_herb = herb
	state = ""
	lit_t = 0.0
	var hub := _hub()
	if hub != null:
		var p := main.player.global_position
		main.player.spawn_flat(Vector3(p.x, hub.land.height_at(p.x, p.z), p.z), main.player.rotation.y, 0.0)
	main.player.set_physics_process(true)
	if _view != null:
		_view.visible = false
	if log_it:
		GameLog.add(str(D.get("log_stand", "You get up from the log.")), "world")


## Left or right while unlit: the next herb you carry.
func pick(dir: int) -> void:
	var have := carried()
	if have.is_empty() or state not in ["", "out"]:
		return
	_pick = posmod(_pick + dir, have.size())
	herb = str(have[_pick])


func _light() -> void:
	var have := carried()
	if have.is_empty():
		GameLog.add(str(D.get("log_no_herb", "You have nothing to smoke.")), "world")
		return
	if not have.has(herb):
		herb = str(have[0])
	state = "pack"
	_t = 0.0
	lit_t = 0.0
	_ensure_view()
	GameLog.add(str(D.get("log_light", "You pack your pipe with {name} and light it.")).format({"name": str(herb_data(herb).get("name", herb))}), "world")


func _unhandled_input(event: InputEvent) -> void:
	if not seated or main.leaving:
		return
	if event.is_action_pressed("move_left"):
		pick(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		pick(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("move_back") or event.is_action_pressed("ui_cancel"):
		stand()
		get_viewport().set_input_as_handled()


# --- The effect -----------------------------------------------------------------------------

## The herb's curve at `s` seconds lit: up over onset_s, held for peak_s,
## down over fade_s; 0 after.
static func curve(id: String, s: float) -> float:
	var h := herb_data(id)
	var on := maxf(float(h.get("onset_s", 8.0)), 0.01)
	var pk := float(h.get("peak_s", 30.0))
	var fd := maxf(float(h.get("fade_s", 12.0)), 0.01)
	if s <= 0.0:
		return 0.0
	if s < on:
		return s / on
	if s < on + pk:
		return 1.0
	if s < on + pk + fd:
		return 1.0 - (s - on - pk) / fd
	return 0.0


## What the effect does now: {"tint" (0..1, its colour in "color"),
## "cutoff_hz" (0: none), "time_scale"}.
func effect() -> Dictionary:
	var id := herb if seated else _stand_herb
	var E: Dictionary = herb_data(id).get("effects", {})
	var out := {"tint": 0.0, "color": Color.WHITE, "cutoff_hz": 0.0, "time_scale": 1.0}
	if level <= 0.0:
		return out
	if E.has("sky_tint"):
		out.tint = float(E.sky_tint.get("strength", 0.3)) * level
		out.color = Color(str(E.sky_tint.get("color", "#ffffff")))
	if E.has("music_filter"):
		out.cutoff_hz = lerpf(20500.0, float(E.music_filter.get("cutoff_hz", 1000.0)), level)
	if E.has("time_slow"):
		out.time_scale = lerpf(1.0, float(E.time_slow.get("scale", 0.9)), level)
	return out


func _process(delta: float) -> void:
	if main == null:
		return
	# The pipe's own clock runs on real time, not time slowed.
	tick(delta / maxf(Engine.time_scale, 0.01))


## One step (the checks drive it with their own delta).
func tick(delta: float) -> void:
	_ensure_plants()
	if seated and _hub() == null:
		stand(false)
	var P: Dictionary = seat_data().get("pose", {})
	if seated and state in ["pack", "ember", "puff"]:
		_t += delta
		var dur := float(P.get(state + "_s", 1.5))
		if _t >= dur:
			_t = 0.0
			state = {"pack": "ember", "ember": "puff", "puff": "smoke"}[state]
			if state == "smoke":
				lit_t = 0.0
				if _exhale != null:
					_exhale.restart()
	if seated and state == "smoke":
		lit_t += delta
		level = curve(herb, lit_t)
		if level <= 0.0 and lit_t > 0.5:
			state = "out"
			GameLog.add(str(D.get("log_out", "The pipe goes out.")), "world")
	elif seated:
		level = 0.0
	elif _standing:
		_stand_t += delta
		var f := maxf(float(seat_data().get("stand_fade_s", 2.0)), 0.01)
		level = _stand_from * maxf(1.0 - _stand_t / f, 0.0)
		if level <= 0.0:
			_standing = false
			_stand_herb = ""
	else:
		level = 0.0
	_apply()
	_pose()


func _apply() -> void:
	var e := effect()
	# The sky tinted (the top of the view, fading toward the horizon).
	if float(e.tint) > 0.0 and _tint == null:
		_ensure_tint()
	if _tint != null:
		_tint.visible = float(e.tint) > 0.0
		_tint_mat.set_shader_parameter("amount", float(e.tint))
		_tint_mat.set_shader_parameter("tint", e.color)
	# The music muffled.
	if float(e.cutoff_hz) > 0.0:
		if _lp == null:
			_lp = AudioEffectLowPassFilter.new()
			_lp_bus = AudioServer.get_bus_index(AudioMix.bus("ambience"))
			if _lp_bus >= 0:
				AudioServer.add_bus_effect(_lp_bus, _lp)
		_lp.cutoff_hz = float(e.cutoff_hz)
	elif _lp != null:
		_remove_filter()
	# Time a touch slower.
	var ts := float(e.time_scale)
	if absf(Engine.time_scale - ts) > 1e-4 and (ts < 1.0 or has_meta("slowed")):
		Engine.time_scale = ts
		if ts < 1.0:
			set_meta("slowed", true)
		else:
			remove_meta("slowed")


func _remove_filter() -> void:
	if _lp_bus >= 0:
		for i in AudioServer.get_bus_effect_count(_lp_bus):
			if AudioServer.get_bus_effect(_lp_bus, i) == _lp:
				AudioServer.remove_bus_effect(_lp_bus, i)
				break
	_lp = null
	_lp_bus = -1


## Nothing of the effect is left (the checks): no tint, no filter, time
## at its own pace.
func clear() -> bool:
	return level <= 0.0 and (_tint == null or not _tint.visible) and _lp == null and absf(Engine.time_scale - 1.0) < 1e-4


func _exit_tree() -> void:
	if has_meta("slowed"):
		Engine.time_scale = 1.0
	if _lp != null:
		_remove_filter()


func _ensure_tint() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "HerbTint"
	_layer.layer = 5
	add_child(_layer)
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(1.0);\nuniform float amount = 0.0;\nvoid fragment() {\n\tfloat sky = 1.0 - smoothstep(0.05, 0.6, UV.y);\n\tCOLOR = vec4(tint.rgb, amount * (0.25 + 0.75 * sky));\n}\n"
	_tint_mat = ShaderMaterial.new()
	_tint_mat.shader = sh
	_tint.material = _tint_mat
	_layer.add_child(_tint)


# --- The pipe in your hands -----------------------------------------------------------------

func _mat(c: String, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = 0.6
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c)
		m.emission_energy_multiplier = glow
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, c: String, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c, glow)
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _puffs(col: Color, amount: int, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.amount = amount
	p.lifetime = 2.2
	p.one_shot = one_shot
	p.explosiveness = 0.8 if one_shot else 0.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, 0.12, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.15
	p.scale_amount_min = 0.6
	p.scale_amount_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.55))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.emitting = false
	return p


## The pipe, the pinch, the tongs and the ember, riding your view.
func _ensure_view() -> void:
	var cam: Camera3D = main.player.camera() if main.player != null else null
	if cam == null:
		return
	if _view == null or not is_instance_valid(_view):
		_view = Node3D.new()
		_view.name = "PipeView"
		cam.add_child(_view)
		_pipe = Node3D.new()
		_view.add_child(_pipe)
		var stem := CylinderMesh.new()
		stem.top_radius = 0.006
		stem.bottom_radius = 0.008
		stem.height = 0.22
		var s := _mesh(_pipe, stem, Vector3(0, 0, 0.1), "#d8cfa8")
		s.rotation = Vector3(PI * 0.5, 0, 0)
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.022
		bowl.bottom_radius = 0.016
		bowl.height = 0.05
		_mesh(_pipe, bowl, Vector3(0, 0.02, 0), "#c8b890")
		var glow := CylinderMesh.new()
		glow.top_radius = 0.018
		glow.bottom_radius = 0.018
		glow.height = 0.004
		_bowl_glow = _mesh(_pipe, glow, Vector3(0, 0.044, 0), "#ff7a1a", 3.0)
		var pm := SphereMesh.new()
		pm.radius = 0.016
		pm.height = 0.02
		_pinch = _mesh(_pipe, pm, Vector3(0, 0.06, 0), "#6a8a3a")
		_tongs = Node3D.new()
		_view.add_child(_tongs)
		for side in [-1.0, 1.0]:
			var arm := CylinderMesh.new()
			arm.top_radius = 0.003
			arm.bottom_radius = 0.004
			arm.height = 0.3
			var a := _mesh(_tongs, arm, Vector3(side * 0.008, 0, 0.15), "#3a2a1c")
			a.rotation = Vector3(PI * 0.5, 0, side * 0.03)
		var em := SphereMesh.new()
		em.radius = 0.012
		em.height = 0.024
		_ember = _mesh(_tongs, em, Vector3(0, 0, 0), "#ff6a10", 4.0)
		_smoke = _puffs(Color.WHITE, 24, false)
		_smoke.position = Vector3(0, 0.05, 0)
		_pipe.add_child(_smoke)
		_exhale = _puffs(Color.WHITE, 30, true)
		_exhale.position = Vector3(0, -0.02, -0.35)
		_exhale.direction = Vector3(0, 0.3, -1)
		_exhale.initial_velocity_min = 0.2
		_exhale.initial_velocity_max = 0.45
		_view.add_child(_exhale)
	_view.visible = true
	_colour_smoke()


## The smoke in the herb's own colour.
func _colour_smoke() -> void:
	if _smoke == null:
		return
	var col := Color(str(herb_data(herb).get("smoke", "#d8d8e8"))) if herb != "" else Color(0.85, 0.85, 0.9)
	for p in [_smoke, _exhale]:
		var g := (p as CPUParticles3D).color_ramp
		g.set_color(0, Color(col.r, col.g, col.b, 0.55))
		g.set_color(1, Color(col.r, col.g, col.b, 0.0))


## The beat of lighting it, then the pipe at rest in your hand.
func _pose() -> void:
	if not seated or _view == null:
		return
	if herb != "":
		(_pinch.material_override as StandardMaterial3D).albedo_color = Color(str(herb_data(herb).get("leaf", "#6a8a3a")))
	var P: Dictionary = seat_data().get("pose", {})
	var rest := Vector3(0.13, -0.17, -0.42)
	var hold := Vector3(0.02, -0.12, -0.34)
	var mouth := Vector3(0.0, -0.07, -0.16)
	var k := 0.0
	_tongs.visible = state == "ember"
	_pinch.visible = state == "pack"
	_bowl_glow.visible = state in ["puff", "smoke"]
	_smoke.emitting = state == "smoke" and level > 0.02
	if _smoke.emitting:
		_smoke.amount = maxi(4, int(24 * level))
	match state:
		"pack":
			k = clampf(_t / float(P.get("pack_s", 1.6)), 0.0, 1.0)
			_pipe.position = rest.lerp(hold, minf(k * 3.0, 1.0))
			_pinch.position = Vector3(0, lerpf(0.09, 0.035, k), 0)
			_pinch.scale = Vector3.ONE * lerpf(1.0, 0.6, k)
		"ember":
			k = clampf(_t / float(P.get("ember_s", 2.2)), 0.0, 1.0)
			_pipe.position = hold
			# From the fire, low ahead, to the bowl.
			var from := Vector3(-0.25, -0.35, -0.9)
			var to := hold + Vector3(-0.01, 0.07, 0.0)
			_tongs.position = from.lerp(to, smoothstep(0.0, 0.8, k))
			_ember.visible = k < 0.95
		"puff":
			k = clampf(_t / float(P.get("puff_s", 1.4)), 0.0, 1.0)
			_pipe.position = hold.lerp(mouth, sin(k * PI))
		_:
			_pipe.position = rest


# --- Herbs growing in the realms (§GO.7.3) -----------------------------------------------------

func _ensure_plants() -> void:
	var area := main.area_node
	if area == null or not is_instance_valid(area) or area.land == null or area != main.surface:
		return
	_plants = _plants.filter(func(p): return p.node != null and is_instance_valid(p.node))
	if not _plants.is_empty():
		return
	var key := "first"
	var realm := SongWeb.realm_of(key)
	var taken: Array = []
	for p in (main.song_web.plants() if main.song_web != null else []):
		taken.append((p.node as Node3D).global_position)
	var n := int((D.get("plants", {}) as Dictionary).get("per_realm", 3))
	for id in herbs():
		if str(herb_data(id).get("realm_area", "")) != key:
			continue
		var at := SongWeb.spots(area, realm, "herb_" + str(id), n, taken)
		taken.append_array(at)
		for i in at.size():
			var node := Node3D.new()
			node.name = "Herb_" + str(id)
			area.add_child(node)
			node.position = area.to_local(at[i])
			node.rotation.y = float(hash([id, i]) % 628) / 100.0
			_plant(node, str(id))
			_plants.append({"node": node, "herb": str(id)})


## The herb plants on the realm's floor now: [{"node", "herb"}].
func plants() -> Array:
	return _plants.filter(func(p): return p.node != null and is_instance_valid(p.node) and (p.node as Node3D).is_inside_tree())


func _plant(node: Node3D, id: String) -> void:
	var h := herb_data(id)
	var leaf := str(h.get("leaf", "#6a8a3a"))
	var flower := str(h.get("flower", "#f0d040"))
	for i in 7:
		var a := TAU * i / 7.0
		var b := BoxMesh.new()
		b.size = Vector3(0.09, 0.02, 0.28)
		var mi := _mesh(node, b, Vector3(cos(a) * 0.14, 0.12 + 0.03 * (i % 2), sin(a) * 0.14), leaf)
		mi.rotation = Vector3(-0.5, -a + PI * 0.5, 0)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.01
	stem.bottom_radius = 0.015
	stem.height = 0.45
	_mesh(node, stem, Vector3(0, 0.25, 0), leaf)
	for i in 5:
		var s := SphereMesh.new()
		s.radius = 0.03
		s.height = 0.05
		_mesh(node, s, Vector3(0.03 * cos(i * 1.3), 0.42 + i * 0.03, 0.03 * sin(i * 1.3)), flower)


func _take_pinch() -> bool:
	var C: Dictionary = D.get("plants", {})
	var pp := main.player.global_position
	for p in plants():
		var np := (p.node as Node3D).global_position
		if Vector2(pp.x - np.x, pp.z - np.z).length() > float(C.get("reach_m", 1.8)):
			continue
		var id := str(p.herb)
		var nm := str(herb_data(id).get("name", id))
		if carried().has(id):
			GameLog.add(str(C.get("log_have", "You already carry {name}.")).format({"name": nm}), "world")
			return true
		if not main.player.inventory.add(pinch(id)):
			GameLog.add("Your pack is full.", "world")
			return true
		CrawlerSave.save()
		GameLog.add(str(C.get("log_take", "You pinch some {name}.")).format({"name": nm}), "world")
		return true
	return false
