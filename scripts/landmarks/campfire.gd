class_name Campfire
## A campfire: a stone ring, crossed logs on a bed of glowing coals, one
## flame card, embers, a warm light that swells at night, firelight pooled
## on the ground and a log to sit on (DESIGN.md: the warm "pop" against
## the blue night). Used by the camps (Camps), the mythical creatures'
## fires, the player's own fires (PlayerFires) and the opening encampment.
## The stones and logs collide (PropCollision): low capsules you bump into
## at the ring's edge, and the seat log.
##
## Design 30 Sept night §BZ (data/look.json → fire, data/audio.json →
## fire; every number comes from there):
## - The flame is ONE camera-facing card per fire (shaders/flame.gdshader)
##   that turns only about its own up axis, noise scrolled up through a
##   teardrop mask, posterised to flat bands on a 32x48 texel grid, so it
##   is crunchy at any distance; from straight above it thins to a line.
##   When the store burns low the card collapses toward a red flicker; at
##   embers, coals only.
## - The fire breathes (design 3 Oct §CZ, look.json fire.coals, specks,
##   light.breath): the bed of coals (shaders/coals.gdshader) on a coarse
##   texel grid breathes slowly, its patches on their own clocks, and
##   flares on a gust of wind, a poke or a fresh piece (stir()); the light
##   breathes with it, on top of the noise flicker. Specks
##   (shaders/specks.gdshader) are thrown on a random clock and on every
##   pop of the fire's sound, sparks and ash, in place of the embers'
##   steady loop (the torch keeps its own, §CP). At embers the bed is the
##   whole fire, breathing slower and deeper, with a rare speck.
## - The light does not get brighter at night, the world gets darker round
##   it: by day it is `day_share` of full; as the sky goes cobalt the
##   energy and the range swell (`night_energy_scale`, `night_range_scale`),
##   with value noise on the brightness and a small jitter on the light's
##   position so the lit edges dance on the trunks. The §AX burn-down
##   scales it all. The safe/dread radius (fuel.json light_radius_m,
##   lit_near) is a separate number and does not swell.
## - The sound is two point sources (kinds.fire): a steady hiss bed on a
##   loop and pops on a random clock, never a cycle the ear can learn;
##   fewer and quieter pops as the fire burns low, hiss only at embers,
##   silence when out. kinds.fire reaches 90 m, so on the road you hear a
##   camp before you see its glow.

## R1a fire (docs/WORLD_SYSTEMS_SPEC.md): coals #FF4A00 (the flame's bands
## are in look.json fire.flame) and the light (look.json fire.light.color),
## the one warm accent against all the blue (look pass, 1 Oct: orange
## ~#E6552A on screen, short range, high energy): a saturated orange that
## puts lit stone and cloth near #E6552A at about 2 m and blows them to
## orange-yellow within 1 m, falling off fast. The pool on the ground
## stays the deeper #FF7A2A (shaders/fire_glow.gdshader).
const COALS := Color("#ff4a00")
## Radius (m) of the firelight pooled on the ground (shaders/fire_glow).
const GLOW_M := 5.5
const RING_STONE := Color(0.4, 0.45, 0.52) # R1a blue-grey stone
## The fire draws no flame card below this burn level (FireStore.apply
## hides the Flames node there too): embers and out.
const CARD_BELOW := 0.2

## Every campfire in the scene is in this group (lit_near()).
const GROUP := "campfires"

## look.json → fire: light and flame.
static var FIRE: Dictionary = Tuning.section("look", "fire")
static var L: Dictionary = FIRE.get("light", {})
static var FL: Dictionary = FIRE.get("flame", {})
## The light at full flame, full night, before the night swell (look.json
## fire.light.energy).
static var LIGHT_ENERGY := float(L.get("energy", 7.0))
## The light's base range (m; fire.light.range_m); the night swell
## multiplies it.
static var RANGE_M := float(L.get("range_m", 14.0))
## How fast it falls off (fire.light.attenuation, the omni's exponent).
static var ATTENUATION := float(L.get("attenuation", 1.1))
## audio.json → fire: hiss, pops, low_fire.
static var A: Dictionary = Tuning.section("audio", "fire")
## look.json → fire.coals and fire.specks (§CZ).
static var C: Dictionary = FIRE.get("coals", {})
static var SP: Dictionary = FIRE.get("specks", {})
static var _bed_mesh: PlaneMesh
static var _speck_quad: QuadMesh

## 0 by day, 1 at night (Main sets it each frame from the sky).
static var night := 1.0
static var _card: QuadMesh
static var _ember_quad: QuadMesh
static var _glow_mesh: PlaneMesh
static var _glow_mat: ShaderMaterial
static var _warm_mat: ShaderMaterial


## Build one on the ground at surface direction `d`, under `parent`
## (which must be in the scene tree).
static func build(parent: Node3D, world: Node, chunks: ChunkManager, d: Vector3, seat := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	# Every fire, wherever it was built (camps, the opening camp, mythic
	# folk), for lit_near(); "lit" until something puts it out.
	root.add_to_group(GROUP)
	root.set_meta("lit", true)
	# Every fire smokes (§CV; Mike, 3 Oct): a campfire's flame is the 1.0
	# the column is sized against (a delve's hearth resets it to its stack's).
	root.set_meta("smoke", 1.0)
	parent.add_child(root)
	root.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	root.global_basis = Basis.looking_at(CubeSphere.north(d), d)
	var body := PropCollision.body(root)
	for i in 8:
		var a := i * TAU / 8.0
		var stone := CreatureBodies.box(root, Vector3(0.28, 0.18, 0.22), Vector3(cos(a) * 0.62, 0.09, sin(a) * 0.62), RING_STONE)
		stone.rotation.y = a
		# Along the stone's length (its x).
		PropCollision.capsule(body, Transform3D(stone.basis * Basis(Vector3(0, 0, 1), -PI * 0.5), stone.position), 0.09, 0.28)
	for i in 3:
		var l := CreatureBodies.cone(root, 0.06, 0.06, 0.9, Vector3(0, 0.12, 0), Color(0.3, 0.2, 0.12))
		l.rotation = Vector3(PI * 0.5, i * TAU / 3.0, 0)
		PropCollision.capsule(body, l.transform, 0.06, 0.9)
	# Its own phase, so fires don't flicker or pop together.
	var phase := float(posmod(hash(d), 1000)) * 0.37
	var coals := coal_bed(phase)
	coals.position = Vector3(0, 0.05, 0)
	root.add_child(coals)
	root.add_child(speck_node(phase))
	var flames := flame_node(1.0, 1.0, 0, phase)
	flames.name = "Flames"
	flames.position = Vector3(0, 0.1, 0)
	root.add_child(flames)
	for part in _ground_glow():
		root.add_child(part)
	# Its voice: a hiss bed on a loop and pops on a random clock, both
	# sources you can walk to (design 30 Sept §BG, §BZ).
	var hiss := Audio3D.make("fire", root, "Hiss")
	hiss.stream = SoundSynth.stream("fire_hiss_loop", posmod(hash(d), SoundSynth.VARIANTS))
	hiss.volume_db = float(A.get("hiss", {}).get("volume_db", -14.0))
	hiss.position = Vector3(0, 0.4, 0)
	# flicker() starts it once the fire is in the tree (a camp's root may
	# not be yet) and keeps it to the burn.
	var pops := Audio3D.make("fire", root, "Pops")
	pops.position = Vector3(0, 0.4, 0)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(str(L.get("color", "#FF6E24")))
	light.light_energy = LIGHT_ENERGY
	light.omni_range = RANGE_M
	light.omni_attenuation = ATTENUATION
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	# One of the fires that may cast a shadow when it's among the nearest
	# (FireShadows, §ER.1).
	FireShadows.enlist(light)
	root.set_meta("flick_seed", phase)
	if seat:
		var log_seat := CreatureBodies.cone(root, 0.18, 0.18, 1.5, Vector3(0, 0.18, 2.0), Color(0.36, 0.25, 0.16))
		log_seat.rotation.z = PI * 0.5
		PropCollision.capsule(body, log_seat.transform, 0.18, 1.5)
	# Its fuel store (design 30 Sept §AX, FireStore): every fire built so
	# far is a folk's fire, tended.
	FireStore.register(root, world, d, true)
	return root


## One flame: the card (`Card`) at `size` times the campfire's
## width_m x height_m, its noise scrolling at `scroll_scale` of the
## campfire's, and `embers` single-pixel embers rising from its foot. The
## campfire uses it at 1.0; the torch (Torch.flame_node) small and slow.
## Each flame has its own materials (its phase and its low-fire blend).
static func flame_node(size: float, scroll_scale: float, embers: int, phase := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Flame"
	var card := MeshInstance3D.new()
	card.name = "Card"
	card.mesh = _card_mesh()
	card.material_override = _flame_material(phase, scroll_scale)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.scale = Vector3(float(FL.get("width_m", 0.62)) * size, float(FL.get("height_m", 1.0)) * size, 1.0)
	n.add_child(card)
	if embers > 0:
		n.add_child(_ember_node(embers, size, phase))
	return n


## Firelight pooled on the ground round the fire, after dark only: a disc
## that filters the ground warm (shaders/fire_glow_warm.gdshader), then
## the same disc adding the orange light (shaders/fire_glow.gdshader),
## drawn in that order. One mesh and two materials serve every fire.
static func _ground_glow() -> Array[MeshInstance3D]:
	if _glow_mesh == null:
		_glow_mesh = PlaneMesh.new()
		_glow_mesh.size = Vector2(2.0, 2.0)
		_warm_mat = ShaderMaterial.new()
		_warm_mat.shader = preload("res://shaders/fire_glow_warm.gdshader")
		_warm_mat.render_priority = 0
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = preload("res://shaders/fire_glow.gdshader")
		_glow_mat.render_priority = 1
	var out: Array[MeshInstance3D] = []
	for m: ShaderMaterial in [_warm_mat, _glow_mat]:
		var mi := MeshInstance3D.new()
		mi.name = "GroundWarm" if m == _warm_mat else "GroundGlow"
		mi.mesh = _glow_mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, 0.04, 0.0)
		mi.scale = Vector3(GLOW_M, 1.0, GLOW_M)
		out.append(mi)
	return out


## A unit card standing on its bottom edge.
static func _card_mesh() -> QuadMesh:
	if _card == null:
		_card = QuadMesh.new()
		_card.center_offset = Vector3(0, 0.5, 0)
	return _card


## A look.json on-screen colour as the scene colour (linear) that lands on
## it through the environment's exposure (SkySystem.tonemap_exposure; the
## grade leaves oranges and golds alone), with its full channels (those at
## 90 %+ on screen) pushed `gain` times past 1.0 so it blooms (look.json
## retro.bloom) while the screen still shows the same, clipped, colour.
static func emissive(hex: Variant, gain := 1.0) -> Vector3:
	var c := Color(str(hex))
	var lin := c.srgb_to_linear()
	var out := Vector3(lin.r, lin.g, lin.b) / SkySystem.tonemap_exposure()
	for i in 3:
		out[i] *= 1.0 + (gain - 1.0) * smoothstep(0.9, 1.0, c[i])
	return out


## The flame card's material: the bands (on-screen colours, the hot ones
## pushed past 1 by fire.flame.hdr so they bloom), the texel grid and the
## scroll from look.json fire.flame; `low` (0-1) is driven by flicker().
static func _flame_material(phase: float, scroll_scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/flame.gdshader")
	m.set_shader_parameter("look_grain_soft", Look.grain())
	m.set_shader_parameter("phase", phase)
	var tx: Array = FL.get("texels", [32, 48])
	m.set_shader_parameter("texels", Vector2(float(tx[0]), float(tx[1])))
	m.set_shader_parameter("scroll", float(FL.get("noise_scroll_per_s", 1.6)) * scroll_scale)
	var bands: Array = FL.get("bands", ["#FEFC54", "#FCA82C", "#E6552A", "#5A0A00"])
	var hdr: Array = FL.get("hdr", [1.0, 1.0, 1.0, 1.0])
	for i in 4:
		m.set_shader_parameter("band%d" % i, emissive(bands[mini(i, bands.size() - 1)], float(hdr[i]) if i < hdr.size() else 1.0))
	# The collapsed (low fire) bands don't bloom: a dying fire is a red
	# flicker, not a glow.
	var low: Array = (FL.get("low", {}) as Dictionary).get("bands_low", ["#FF4A00", "#8A1A00", "#3A0800"])
	for i in 3:
		m.set_shader_parameter("low%d" % i, emissive(low[mini(i, low.size() - 1)]))
	m.set_shader_parameter("low", 0.0)
	return m


## `count` single-pixel embers drifting up from the foot of a flame of
## `size` (shaders/ember.gdshader animates them from TIME and each
## instance's seeds; nothing per frame on the CPU).
static func _ember_node(count: int, size: float, phase: float) -> MultiMeshInstance3D:
	var E: Dictionary = FL.get("embers", {})
	if _ember_quad == null:
		_ember_quad = QuadMesh.new()
		_ember_quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _ember_quad
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = int(phase * 1000.0)
	for i in count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Embers"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ember.gdshader")
	m.set_shader_parameter("color", emissive(E.get("color", "#FFB020"), float(E.get("hdr", 1.0))))
	m.set_shader_parameter("px", float(E.get("px", 1)))
	m.set_shader_parameter("rise_mps", float(E.get("rise_mps", 0.6)) * size)
	var life: Array = E.get("life_s", [1.0, 2.5])
	m.set_shader_parameter("life_min", float(life[0]))
	m.set_shader_parameter("life_max", float(life[1]))
	m.set_shader_parameter("spread_m", float(E.get("spread_m", 0.25)) * size)
	m.set_shader_parameter("wobble_m", float(E.get("wobble_m", 0.08)) * size)
	m.set_shader_parameter("phase", phase)
	mi.material_override = m
	# The instances all sit at the origin; the shader moves them, so tell
	# the culler how far they climb.
	var reach := float(E.get("rise_mps", 0.6)) * float(life[1]) * size + 0.3
	var wide := float(E.get("spread_m", 0.25)) * size + 0.3
	mi.custom_aabb = AABB(Vector3(-wide, -0.1, -wide), Vector3(wide * 2.0, reach, wide * 2.0))
	return mi


## The bed of coals (§CZ): a flat disc bed_width_m across, drawn by
## shaders/coals.gdshader; its own material (its breath and flare are set
## per fire by flicker(), its heat by FireStore.apply).
static func coal_bed(phase: float) -> MeshInstance3D:
	var w := float(C.get("bed_width_m", 0.6))
	if _bed_mesh == null:
		_bed_mesh = PlaneMesh.new()
		_bed_mesh.size = Vector2(w, w)
		_bed_mesh.subdivide_width = 6
		_bed_mesh.subdivide_depth = 6
	var mi := MeshInstance3D.new()
	mi.name = "Coals"
	mi.mesh = _bed_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/coals.gdshader")
	var bands: Array = FL.get("bands", ["#FEFC54", "#FCA82C", "#E6552A", "#5A0A00"])
	var hdr: Array = FL.get("hdr", [1.0, 1.0, 1.0, 1.0])
	for i in 4:
		m.set_shader_parameter("band%d" % i, emissive(bands[mini(i, bands.size() - 1)], float(hdr[i]) if i < hdr.size() else 1.0))
	m.set_shader_parameter("char_col", emissive(C.get("char", "#1A0C08")))
	m.set_shader_parameter("texels_m", float(C.get("texels_m", 32.0)))
	m.set_shader_parameter("width_m", w)
	var ph: Array = C.get("patch_hz", [0.6, 1.4])
	m.set_shader_parameter("patch_hz", Vector2(float(ph[0]), float(ph[1])))
	m.set_shader_parameter("patch_amount", float(C.get("patch_amount", 0.35)))
	m.set_shader_parameter("crawl", float(C.get("crawl", 0.06)))
	m.set_shader_parameter("air_brighten", float(C.get("air_brighten", 0.25)))
	m.set_shader_parameter("phase", phase)
	mi.material_override = m
	return mi


## The pool of specks a fire throws (§CZ): fire.specks.max_alive slots in
## a MultiMesh drawn by shaders/specks.gdshader; throw() fills them.
static func speck_node(phase: float) -> MultiMeshInstance3D:
	if _speck_quad == null:
		_speck_quad = QuadMesh.new()
		_speck_quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _speck_quad
	mm.instance_count = int(SP.get("max_alive", 24))
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(-1000.0, 0.0, 0.0, 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Specks"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.1, 0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/specks.gdshader")
	var spd: Array = SP.get("speed_mps", [0.5, 2.2])
	var life: Array = SP.get("life_s", [0.8, 3.5])
	var spark: Dictionary = SP.get("spark", {})
	var ash: Dictionary = SP.get("ash", {})
	m.set_shader_parameter("px", float(SP.get("px", 1)))
	m.set_shader_parameter("speed_mps", Vector2(float(spd[0]), float(spd[1])))
	m.set_shader_parameter("cone_deg", float(SP.get("cone_deg", 35.0)))
	m.set_shader_parameter("drag", float(SP.get("drag", 0.9)))
	m.set_shader_parameter("curl_m", float(SP.get("curl_m", 0.15)))
	m.set_shader_parameter("wind_share", float(SP.get("wind_share", 1.0)))
	m.set_shader_parameter("life_s", Vector2(float(life[0]), float(life[1])))
	m.set_shader_parameter("height_max_m", float(SP.get("height_max_m", 3.0)))
	m.set_shader_parameter("ash_life_scale", float(ash.get("life_scale", 1.6)))
	m.set_shader_parameter("spread_m", float(C.get("bed_width_m", 0.6)) * 0.35)
	m.set_shader_parameter("spark_col", emissive(spark.get("color", "#FFB020"), float(spark.get("hdr", 2.0))))
	m.set_shader_parameter("spark_cool", emissive(spark.get("cools_to", "#E6552A")))
	# Ash doesn't glow: its own colour, never past 1 (no bloom).
	m.set_shader_parameter("ash_col", Color(str(ash.get("color", "#8FA0C8"))).srgb_to_linear())
	mi.material_override = m
	var reach := float(SP.get("height_max_m", 3.0)) + 0.5
	mi.custom_aabb = AABB(Vector3(-3, -0.2, -3), Vector3(6, reach + 2.0, 6))
	mi.set_meta("phase", phase)
	return mi


## Throw `n` specks from `camp` at `time` (its flicker clock): each a
## spark or, ash.share of the time, a flake of ash, into the pool's next
## slots (the oldest go first).
static func throw(camp: Node3D, time: float, n: int) -> void:
	var sp := camp.get_node_or_null("Specks") as MultiMeshInstance3D
	if sp == null or n <= 0:
		return
	var mm := sp.multimesh
	var slot := int(camp.get_meta("speck_slot", 0))
	var ash_share := float((SP.get("ash", {}) as Dictionary).get("share", 0.3))
	for i in mini(n, mm.instance_count):
		var kind := 1.0 if randf() < ash_share else 0.0
		mm.set_instance_custom_data(slot, Color(time, randf(), randf(), kind + randf() * 0.49))
		if kind > 0.5:
			camp.set_meta("ash_thrown", int(camp.get_meta("ash_thrown", 0)) + 1)
		slot = (slot + 1) % mm.instance_count
	camp.set_meta("speck_slot", slot)
	camp.set_meta("specks_thrown", int(camp.get_meta("specks_thrown", 0)) + mini(n, mm.instance_count))


## A burst's size from fire.specks: burst, now and then a big_burst.
static func burst_size(big := false) -> int:
	var b: Array = SP.get("big_burst", [6, 12]) if big or randf() < float(SP.get("big_burst_chance", 0.12)) else SP.get("burst", [1, 4])
	return randi_range(int(b[0]), int(b[1]))


## Air on the fire (§CZ): a poke ("poke", §CY's poke_fire) or a fresh
## piece laid on ("feed", FireStore.add_fuel) makes the bed flare and
## throws a big burst of specks, at the fire's next flicker.
static func stir(camp: Node3D, kind := "poke") -> void:
	if camp == null:
		return
	if (kind == "feed" and not bool(SP.get("on_feed", true))) or (kind == "poke" and not bool(SP.get("on_poke", true))):
		camp.set_meta("stir", "air")
	else:
		camp.set_meta("stir", kind)


## The bed's slow breath at `time` (-1..1) and how much it breathes, for
## the coals and the light alike: at embers (burn at or under CARD_BELOW)
## coals.at_embers' slower, deeper breath.
static func breath(camp: Node3D, time: float, burn: float) -> Vector2:
	var at_e: Dictionary = C.get("at_embers", {})
	var embers := burn <= CARD_BELOW
	var hz := float(at_e.get("breath_hz", 0.2)) if embers else float(C.get("breath_hz", 0.35))
	var amount := float(at_e.get("breath_amount", 0.45)) if embers else float(C.get("breath_amount", 0.3))
	var sd := float(camp.get_meta("flick_seed", 0.0))
	return Vector2(sin(TAU * hz * time + sd), amount)


## How the fire breathes this frame (§CZ): the bed's breath, its flare
## (a gust, a poke, a piece laid on, settling over air_settle_s), and the
## specks on their random clock. Returns the breath (-1..1) for the light.
static func _breathe(camp: Node3D, time: float, burn: float) -> float:
	var sd := float(camp.get_meta("flick_seed", 0.0))
	var b := breath(camp, time, burn)
	var settle := maxf(float(C.get("air_settle_s", 2.5)), 0.1)
	var stirred := str(camp.get_meta("stir", ""))
	if stirred != "":
		camp.remove_meta("stir")
		camp.set_meta("air_t", time)
		if stirred != "air" and burn > 0.0:
			throw(camp, time, burst_size(true))
	var air := 0.0
	if camp.has_meta("air_t"):
		var since := time - float(camp.get_meta("air_t"))
		air = exp(-maxf(since, 0.0) / settle) if since >= 0.0 else 0.0
	# A gust of the weather's wind at the fire: the gust field there (design
	# §DA, wind.json specks.read_gust_field), the stronger the wind the more.
	var wind := WeatherFX.plant_wind.length()
	var gust := smoothstep(1.05, 1.45, Wind.gust_at(camp.global_position, Wind.clock).x) * clampf(wind / 8.0, 0.0, 1.0)
	air = maxf(air, gust)
	var coals := camp.get_node_or_null("Coals") as MeshInstance3D
	if coals and coals.material_override is ShaderMaterial:
		var m := coals.material_override as ShaderMaterial
		m.set_shader_parameter("breath", 1.0 + b.y * b.x)
		m.set_shader_parameter("air", air)
	var sp := camp.get_node_or_null("Specks") as MultiMeshInstance3D
	if sp:
		(sp.material_override as ShaderMaterial).set_shader_parameter("now", time)
		sp.visible = true
		# The random clock: an exponential wait (mean_gap_s), longer as the
		# fire burns down (scale_with_burn), none from a dead fire.
		if burn > 0.0:
			var gap := float(SP.get("mean_gap_s", 1.4))
			if bool(SP.get("scale_with_burn", true)):
				gap /= maxf(burn, 0.02)
			if not camp.has_meta("speck_at"):
				camp.set_meta("speck_at", time - log(maxf(randf(), 1e-4)) * gap)
			if time >= float(camp.get_meta("speck_at")):
				throw(camp, time, burst_size() if burn > CARD_BELOW else 1)
				camp.set_meta("speck_at", time - log(maxf(randf(), 1e-4)) * gap)
	return b.x * float((L.get("breath", {}) as Dictionary).get("amount", 0.12))


## Is a lit campfire within `radius` m of scene position `pos` (resting
## there heals the player: PlanetPlayer)?
static func lit_near(tree: SceneTree, pos: Vector3, radius: float) -> bool:
	for f in tree.get_nodes_in_group(GROUP):
		var fire := f as Node3D
		# A fire with its own reach (a delve's fire-holder, meta safe_m:
		# design 2 Oct §CN) holds only that far, whatever was asked.
		var r := minf(radius, float(fire.get_meta("safe_m"))) if fire and fire.has_meta("safe_m") else radius
		if fire and fire.is_inside_tree() and fire.get_meta("lit", true) and fire.global_position.distance_to(pos) < r:
			return true
	return false


## How far the fire has collapsed toward a red flicker (0 full flame, 1
## at flame.low.below_share and under): the burn-down from FireStore.apply
## (flames 1, low 0.55, embers 0.12, out 0) read against the data.
static func lowness(burn: float) -> float:
	var below := float((FL.get("low", {}) as Dictionary).get("below_share", 0.25))
	return clampf((1.0 - burn) / maxf(1.0 - below, 0.01), 0.0, 1.0)


## Flicker the flame, the light and the sound (call every frame with a
## running time, in seconds).
static func flicker(camp: Node3D, time: float) -> void:
	# How far the store has burnt down (FireStore.apply): low flames are
	# smaller and dimmer, embers give a little light, a dead fire none.
	var burn := float(camp.get_meta("burn", 1.0))
	var sd := float(camp.get_meta("flick_seed", 0.0))
	var fk: Dictionary = L.get("flicker", {})
	var hz := float(fk.get("hz", 9.0))
	var amount := float(fk.get("amount", 0.18))
	# Value noise on the brightness: two layers, the fast one smaller.
	var k := 1.0 + amount * (0.7 * (_vnoise(time * hz, sd) * 2.0 - 1.0) + 0.3 * (_vnoise(time * hz * 2.7, sd + 11.0) * 2.0 - 1.0))
	var low := lowness(burn)
	var lowdata: Dictionary = FL.get("low", {})
	# The bed breathes and the light with it (§CZ, fire.light.breath).
	k *= 1.0 + _breathe(camp, time, burn)
	# The flame: one card, collapsing toward the low bands and height.
	var flames := camp.get_node_or_null("Flames") as Node3D
	if flames:
		flames.scale = Vector3(1.0, lerpf(1.0, float(lowdata.get("height_scale", 0.45)), low), 1.0)
		var card := flames.get_node_or_null("Card") as MeshInstance3D
		if card:
			card.visible = burn > CARD_BELOW
			(card.material_override as ShaderMaterial).set_shader_parameter("low", low)
		var embers := flames.get_node_or_null("Embers") as MultiMeshInstance3D
		if embers:
			# Fewer embers as the fire dies; a few still rise from the coals.
			embers.visible = burn > 0.0
			embers.multimesh.visible_instance_count = ceili(embers.multimesh.instance_count * burn) if burn > 0.0 else 0
	# The light: swells at night, flickers with the noise, jitters so the
	# lit edges move on the trunks; the burn-down scales it all.
	var light := camp.get_node_or_null("Light") as OmniLight3D
	if light:
		light.light_energy = LIGHT_ENERGY * lerpf(float(L.get("day_share", 0.45)), float(L.get("night_energy_scale", 1.3)), night) * k * burn
		light.omni_range = (float(camp.get_meta("range_m")) if camp.has_meta("range_m") else RANGE_M * lerpf(1.0, float(L.get("night_range_scale", 1.6)), night))
		var jm := float(fk.get("position_jitter_m", 0.06))
		light.position = Vector3(0, 1.0, 0) + Vector3(_vnoise(time * hz, sd + 3.0) - 0.5, _vnoise(time * hz, sd + 5.0) - 0.5, _vnoise(time * hz, sd + 7.0) - 0.5) * (2.0 * jm)
	# The pool on the ground swells with the light.
	var gs := GLOW_M * lerpf(1.0, float(L.get("ground_glow_night_scale", 1.4)), night)
	for n in ["GroundWarm", "GroundGlow"]:
		var g := camp.get_node_or_null(n) as Node3D
		if g:
			g.scale = Vector3(gs, 1.0, gs)
	_voice(camp, time, burn, low)
	# Its smoke (§CV, Smoke).
	Smoke.tick_fire(camp)


## The hiss bed and the pops: pops on a random clock (the next one
## pops.every_s away), each at a random loudness and pitch, a snaps_share
## of them sharp; fewer and quieter as the fire burns low; hiss only at
## embers; silence when out.
static func _voice(camp: Node3D, time: float, burn: float, low: float) -> void:
	var hiss := camp.get_node_or_null("Hiss") as AudioStreamPlayer3D
	var lowf: Dictionary = A.get("low_fire", {})
	var offset := float(lowf.get("volume_db_offset", -6.0)) * low
	if hiss:
		hiss.volume_db = float(A.get("hiss", {}).get("volume_db", -14.0)) + offset
		if burn <= 0.0 and hiss.playing:
			hiss.stop()
		elif burn > 0.0 and not hiss.playing and hiss.is_inside_tree():
			Audio3D.play(hiss, randf() * 2.0)
	var pops := camp.get_node_or_null("Pops") as AudioStreamPlayer3D
	if pops == null:
		return
	if burn <= CARD_BELOW:
		return # embers: hiss only
	var P: Dictionary = A.get("pops", {})
	if not camp.has_meta("pop_at"):
		camp.set_meta("pop_at", time + _rand_in(P.get("every_s", [0.3, 2.8])))
	if time < float(camp.get_meta("pop_at")):
		return
	var sharp := randf() < float(P.get("snaps_share", 0.3))
	pops.stream = SoundSynth.stream("fire_snap" if sharp else "fire_crackle", randi() % SoundSynth.VARIANTS)
	pops.pitch_scale = _rand_in(P.get("pitch", [0.8, 1.4]))
	pops.volume_db = _rand_in(P.get("volume_db", [-10.0, -3.0])) + offset
	Audio3D.play(pops)
	# Every pop throws its burst at the same instant (§CZ specks.on_pop).
	camp.set_meta("popped_at", time)
	if bool(SP.get("on_pop", true)):
		throw(camp, time, burst_size())
	camp.set_meta("pop_at", time + _rand_in(P.get("every_s", [0.3, 2.8])) * lerpf(1.0, float(lowf.get("pops_every_scale", 2.5)), low))


static func _rand_in(span: Array) -> float:
	return randf_range(float(span[0]), float(span[1]))


## Smooth value noise in 0..1 at `x`, one lattice point per unit.
static func _vnoise(x: float, sd: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(i + sd), _hash(i + 1.0 + sd), f)


static func _hash(i: float) -> float:
	return fposmod(sin(i * 12.9898 + 78.233) * 43758.5453, 1.0)
