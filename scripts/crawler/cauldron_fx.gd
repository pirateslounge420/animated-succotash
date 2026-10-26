class_name CauldronFX
extends Node3D
## The camp cauldron's effects (Mike, 26 Oct: "lets get some effects
## steaming up off the cauldron- also, for different brews which would take
## different times there will be different effects"; crawler.json
## hub.cauldron_fx). Sits at the pot's mouth (HubCamp hangs it there):
##
##   steam    soft puffs rising (or, for a heavy brew, rolling over the rim
##            and sinking), in the brew's steam colour
##   bubbles  small beads breaking on the surface
##   sparks   rising motes: embers off the fire, glowing motes, or spores
##            that drift and wander
##   puff     one burst when a brew is done
##   surface  the brew's own colour and its faint light
##
## A brew builds from a simmer to its full look over its brew_s, puffs when
## done and holds there for hold_s. Until something asks for a brew
## (start()), it works through cycle in order, with rest_s of the plain pot
## between: the cook-shaman's own cooking.

signal brewed(key: String)

static var FX: Dictionary = (Tuning.table("crawler").get("hub", {}) as Dictionary).get("cauldron_fx", {})

## The brew in the pot, how far along (0-1), and the clock.
var brew := ""
var progress := 0.0
var held_s := 0.0
var auto_cycle := true
var _cycle_i := 0
var _resting := 0.0
var _steam: CPUParticles3D
var _bubbles: CPUParticles3D
var _sparks: CPUParticles3D
var _puff: CPUParticles3D
## A heavy brew's fog, billowing over the rim and rolling down to the
## ground round the fire (spill > 0 in its brew).
var _spill: CPUParticles3D
## Set by HubCamp: the brew's surface mesh and its light.
var surface: MeshInstance3D
var light: OmniLight3D
var light_max := 0.35


static func brews() -> Dictionary:
	return FX.get("brews", {})


static func info(key: String) -> Dictionary:
	return brews().get(key, {})


func _ready() -> void:
	_steam = _particles("Steam", 56, 3.6, 0.22)
	_bubbles = _particles("Bubbles", 24, 0.5, 0.03)
	_sparks = _particles("Sparks", 20, 2.6, 0.025)
	_puff = _particles("Puff", 40, 2.2, 0.3)
	_spill = _particles("Spill", 80, 9.0, 0.6)
	_spill.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_spill.emission_ring_axis = Vector3.UP
	_spill.emission_ring_radius = 0.4
	_spill.emission_ring_inner_radius = 0.3
	_spill.emission_ring_height = 0.02
	_spill.direction = Vector3(1.0, -0.2, 0.0)
	_spill.spread = 180.0
	_spill.flatness = 0.85
	_spill.damping_min = 0.04
	_spill.damping_max = 0.1
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 1.8))
	_spill.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	_spill.color_ramp = fade
	_puff.one_shot = true
	_puff.emitting = false
	_puff.explosiveness = 0.9
	_puff.initial_velocity_min = 0.6
	_puff.initial_velocity_max = 1.2
	_puff.spread = 35.0
	var first: Array = FX.get("cycle", ["camp_stew"])
	start(str(first[0]) if not first.is_empty() else "camp_stew")


func _particles(nm: String, amount: int, life: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 12.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	# A soft round puff, not a square: a radial fade to clear.
	m.albedo_texture = _soft()
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	p.color_ramp = g
	add_child(p)
	return p


static var _soft_tex: GradientTexture2D


static func _soft() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


## Start brewing `key` (a key of hub.cauldron_fx.brews): from a simmer.
## Stops the cook-shaman's own cycle if `manual`.
func start(key: String, manual := false) -> void:
	if not brews().has(key):
		return
	if manual:
		auto_cycle = false
	brew = key
	progress = 0.0 if float(info(key).get("brew_s", 0.0)) > 0.0 else 1.0
	held_s = 0.0
	_resting = float(FX.get("rest_s", 30.0)) if float(info(key).get("brew_s", 0.0)) <= 0.0 else 0.0
	_look(true)


func brew_s() -> float:
	return float(info(brew).get("brew_s", 0.0))


func is_ready() -> bool:
	return progress >= 1.0


func _process(delta: float) -> void:
	advance(delta)


## The clock (the checks drive it directly).
func advance(delta: float) -> void:
	if brew == "":
		return
	var bs := brew_s()
	if progress < 1.0:
		progress = minf(progress + delta / maxf(bs, 0.001), 1.0)
		if progress >= 1.0:
			_puff.restart()
			_puff.emitting = true
			brewed.emit(brew)
	else:
		held_s += delta
		if auto_cycle and bs > 0.0 and held_s >= float(FX.get("hold_s", 40.0)):
			# Back to the plain pot for a rest, then the next in the cycle.
			_resting = float(FX.get("rest_s", 30.0))
			brew = "camp_stew" if brews().has("camp_stew") else brew
			progress = 1.0
			held_s = 0.0
		elif auto_cycle and bs <= 0.0 and held_s >= _resting:
			var cyc: Array = FX.get("cycle", [])
			if cyc.size() > 1:
				_cycle_i = (_cycle_i + 1) % cyc.size()
				if str(cyc[_cycle_i]) == "camp_stew":
					_cycle_i = (_cycle_i + 1) % cyc.size()
				start(str(cyc[_cycle_i]))
				return
	_look(false)


## The look now: the brew's colours, at the strength its progress gives
## (a simmer at 0.25, full at 1).
func _look(recolour: bool) -> void:
	var b := info(brew)
	var k := lerpf(0.25, 1.0, progress)
	var steam_c := Color(str(b.get("steam", "#d8dce8")))
	var glow_c := Color(str(b.get("glow", "#7cff4f")))
	var sr := float(b.get("steam_rate", 0.5)) * k
	_steam.color = Color(steam_c.r, steam_c.g, steam_c.b, clampf(0.12 + 0.45 * sr, 0.0, 1.0))
	_steam.scale_amount_min = 0.6 + sr
	_steam.scale_amount_max = 1.4 + 2.0 * sr
	var lift := float(b.get("steam_lift", 0.0)) if b.has("steam_lift") else (-0.18 if sr > 0.85 else 0.18)
	_steam.gravity = Vector3(0.05, lift, 0.0)
	_steam.initial_velocity_min = 0.15 + 0.25 * sr
	_steam.initial_velocity_max = 0.35 + 0.45 * sr
	_steam.spread = 12.0 if lift > 0.0 else 60.0
	# A heavy brew's fog (spill, 0-1): slow, faint, wide puffs pushed out
	# over the rim, sinking and spreading on the ground as they grow; the
	# column above goes thin and wide (Mike, 26 Oct: "billowing and flowing
	# over the edges").
	var spill := float(b.get("spill", 0.0)) * k
	_spill.visible = spill > 0.01
	_spill.emitting = spill > 0.01
	if spill > 0.01:
		_spill.color = Color(steam_c.r, steam_c.g, steam_c.b, clampf(0.05 + 0.13 * spill, 0.0, 1.0))
		_spill.initial_velocity_min = 0.3
		_spill.initial_velocity_max = 0.45 + 0.35 * spill
		_spill.gravity = Vector3(0.0, -0.4, 0.0)
		_spill.scale_amount_min = 1.2
		_spill.scale_amount_max = 2.0 + 1.5 * spill
		_steam.color.a *= 0.5
		_steam.scale_amount_max *= 1.6
	var bub := float(b.get("bubbles", 0.4)) * k
	_bubbles.color = glow_c.lightened(0.3)
	_bubbles.color.a = clampf(bub, 0.0, 1.0)
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 0.26
	_bubbles.initial_velocity_min = 0.02
	_bubbles.initial_velocity_max = 0.08 + 0.2 * bub
	_bubbles.gravity = Vector3.ZERO
	_bubbles.scale_amount_min = 0.6
	_bubbles.scale_amount_max = 1.0 + 1.5 * bub
	var sp := float(b.get("sparks", 0.2)) * k
	var kind := str(b.get("spark_kind", "motes"))
	_sparks.visible = kind != "none" and sp > 0.01
	_sparks.color = (Torch.fire_color() if kind == "embers" else glow_c)
	_sparks.color.a = clampf(0.2 + sp, 0.0, 1.0)
	match kind:
		"embers":
			_sparks.initial_velocity_min = 0.8
			_sparks.initial_velocity_max = 1.6
			_sparks.gravity = Vector3(0.0, 0.3, 0.0)
			_sparks.lifetime = 1.4
			_sparks.tangential_accel_min = 0.0
			_sparks.tangential_accel_max = 0.0
		"spores":
			_sparks.initial_velocity_min = 0.05
			_sparks.initial_velocity_max = 0.2
			_sparks.gravity = Vector3(0.0, 0.06, 0.0)
			_sparks.lifetime = 5.0
			_sparks.tangential_accel_min = -0.3
			_sparks.tangential_accel_max = 0.3
			_sparks.damping_min = 0.05
			_sparks.damping_max = 0.2
		_:
			_sparks.initial_velocity_min = 0.2
			_sparks.initial_velocity_max = 0.45
			_sparks.gravity = Vector3(0.0, 0.1, 0.0)
			_sparks.lifetime = 3.0
			_sparks.tangential_accel_min = 0.4
			_sparks.tangential_accel_max = 0.8
	_sparks.speed_scale = lerpf(0.4, 1.0, sp)
	if recolour:
		_puff.color = Color(steam_c.r, steam_c.g, steam_c.b, 0.85)
		if surface != null:
			var m := StandardMaterial3D.new()
			m.albedo_color = glow_c
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = glow_c
			surface.material_override = m
		if light != null:
			light.light_color = glow_c
	if surface != null and surface.material_override is StandardMaterial3D:
		(surface.material_override as StandardMaterial3D).emission_energy_multiplier = lerpf(1.0, 3.0, progress)
	if light != null:
		light.light_energy = light_max * lerpf(0.4, 1.0, progress)
