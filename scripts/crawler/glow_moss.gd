class_name GlowMoss
extends Node
## Glow-moss (design 6 Oct §FG; crawler.json ambience.glow_moss): small
## patches of a faint cold blue-green glow on damp stone in the dark,
## Mike's phosphorescent moss. Its real cousins are foxfire, the fungi
## that glow on rotting wood, and cave glow-worms, which dim when
## disturbed. It gives off light, so it glows (the R-rules); never amber
## (the one firelight is the fire's, §EX.6). Atmosphere, never a puzzle:
## it is placed by the damp, not by the way, and marks nothing.
##
##   where   on the tomb's dressed wall faces (TombBuild wall_faces), low on
##           the wall where the moss is thickest (height_m), only where the
##           stone is damp (dampness: the wet field the moss itself grows
##           by, §EU.4, FittedStone.climate_at, plus the damp air at the
##           airways' mouths) at damp_min or over; never on dry stone
##           (FittedStone.dry_of), never within clear_of_fire_m of a fire
##           (its soot burnt the moss off, its flame would keep it dim),
##           never in the hearth room (always lit) or on the stairs.
##           per_m patches to a metre of damp wall, at least spacing_m
##           apart, at most max, each radius_m across.
##   drawn   in the stone's own shader (ruin.gdshader glow_moss): the moss's
##           own texels glow, thickest at a patch's heart and ragged at its
##           rim, and a faint cold light (light_m, light_strength) falls on the
##           stone and the floor round it. There is no light node: nothing
##           the game's rules read (the torch's light, the fires, the dark)
##           knows it is there, so it lights nothing that matters.
##   dims    when any flame (the torch in hand, a planted torch, the hearth,
##           a relit holder or sconce) comes within dims_near_flame_m and
##           its light reaches the patch (CrawlerFires.lit_on: no stone
##           between), its glow fades to dim_to of its rest over dims_s;
##           once the flame has gone it creeps back to rest over returns_s.

static var G: Dictionary = ((Tuning.table("crawler").get("ambience", {}) as Dictionary).get("glow_moss", {}) as Dictionary)
## The most patches the stone's shader takes.
const MAX_PATCHES := 64

## The patches: [{"pos" (on the wall's face, scene), "n" (out of the wall),
## "r" (radius), "damp", "level" (0-1 of its rest glow now)}].
var patches: Array = []
var fires: CrawlerFires
var _img: Image
var _tex: ImageTexture
var _mat: ShaderMaterial


## The glow at rest (ambience.glow_moss.energy).
static func rest_energy() -> float:
	return float(G.get("energy", 0.15))


## How damp the stone is at `pos` (0-1): the wet field the moss grows by
## (§EU.4: the theme's climate wandering from place to place, wetter each
## flight down) and the damp air at the airways' mouths, airway_damp at a
## mouth falling to nothing by near_airway_m.
static func dampness(lay: Dictionary, pos: Vector3) -> float:
	var m := FittedStone.climate_at(str(lay.get("theme", "tomb")), int(lay.seed), pos).x
	var reach := maxf(float(G.get("near_airway_m", 3.5)), 0.01)
	var best := 0.0
	for a in lay.get("airways", []):
		best = maxf(best, 1.0 - (a.pos as Vector3).distance_to(pos) / reach)
	return clampf(m + float(G.get("airway_damp", 0.12)) * best, 0.0, 1.0)


## Is the stone at `pos` damp enough for glow-moss, and not dry (the
## rule place() keeps)?
static func damp_enough(lay: Dictionary, pos: Vector3) -> bool:
	var cl := FittedStone.climate_at(str(lay.get("theme", "tomb")), int(lay.seed), pos)
	return FittedStone.dry_of(cl) <= 0.0 and dampness(lay, pos) >= float(G.get("damp_min", 0.62))


## Where every fire stands (the hearth, every holder): the moss keeps
## clear_of_fire_m from each.
static func fire_spots(lay: Dictionary) -> Array:
	var out: Array = [lay.hearth]
	for h in lay.holders:
		out.append(h.pos)
	return out


## The patches for tomb `lay` on its dressed wall faces `walls` (pure: the
## same tomb gives the same patches).
static func place(lay: Dictionary, walls: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "glow_moss"])
	var heights: Array = G.get("height_m", [0.08, 1.0])
	var radii: Array = G.get("radius_m", [0.18, 0.4])
	var clear := float(G.get("clear_of_fire_m", 1.5))
	var spacing := float(G.get("spacing_m", 2.5))
	var damp_min := float(G.get("damp_min", 0.62))
	var th := str(lay.get("theme", "tomb"))
	var step := 0.7
	var fires := fire_spots(lay)
	var cands: Array = []
	for f in walls:
		var pid := TombKit.piece_at(lay, f.probe)
		if pid < 0:
			continue
		var pc: Dictionary = lay.pieces[pid]
		if str(pc.kind) == "stair" or str(pc.get("room_kind", "")) == "hearth":
			continue
		var a := 0.45
		while a <= float(f.length) - 0.45:
			var h := rng.randf_range(float(heights[0]), float(heights[1]))
			var pos: Vector3 = (f.o as Vector3) + (f.u as Vector3) * a + Vector3.UP * (float(f.floor_y) + h)
			a += step
			# In front of its own piece's floor (a room's side wall runs on
			# past its ends into the corners, behind the end walls).
			if TombKit.piece_at(lay, pos + (f.n as Vector3) * 0.3) != pid:
				continue
			var dmp := dampness(lay, pos)
			if dmp < damp_min or FittedStone.dry_of(FittedStone.climate_at(th, int(lay.seed), pos)) > 0.0:
				continue
			var near_fire := false
			for fp in fires:
				if (fp as Vector3).distance_to(pos) < clear:
					near_fire = true
					break
			if near_fire:
				continue
			# A damper spot is likelier first (a weighted shuffle).
			cands.append({"pos": pos, "n": f.n, "damp": dmp, "key": pow(rng.randf(), 1.0 / (dmp - damp_min + 0.05))})
	var want := mini(roundi(cands.size() * step * float(G.get("per_m", 0.08))), mini(int(G.get("max", 24)), MAX_PATCHES))
	cands.sort_custom(func(x, y): return float(x.key) > float(y.key))
	var out: Array = []
	for c in cands:
		if out.size() >= want:
			break
		var spaced := true
		for o in out:
			if (o.pos as Vector3).distance_to(c.pos) < spacing:
				spaced = false
				break
		if spaced:
			out.append({"pos": c.pos, "n": c.n, "r": rng.randf_range(float(radii[0]), float(radii[1])), "damp": c.damp, "level": 1.0})
	return out


func build(lay: Dictionary, walls: Array, p_fires: CrawlerFires) -> void:
	fires = p_fires
	patches = place(lay, walls)
	_img = Image.create(maxi(patches.size(), 1), 2, false, Image.FORMAT_RGBAF)
	_tex = ImageTexture.create_from_image(_img)
	_mat = RuinBuilder.material_lit()
	var c := Color(str(G.get("color", "#3fbfa0"))).srgb_to_linear()
	_mat.set_shader_parameter("glow_moss_color", Vector3(c.r, c.g, c.b))
	_mat.set_shader_parameter("glow_moss_light", Vector2(float(G.get("light_m", 0.9)), float(G.get("light_strength", 4.0))))
	_mat.set_shader_parameter("glow_moss_data", _tex)
	_mat.set_shader_parameter("glow_moss_count", patches.size())
	_upload()


func _exit_tree() -> void:
	if _mat != null:
		_mat.set_shader_parameter("glow_moss_count", 0)


## A patch's glow now (rest_energy at rest, dim_to of it by a flame).
func energy_of(p: Dictionary) -> float:
	return rest_energy() * float(p.level)


func _process(delta: float) -> void:
	step(delta)


## The glow follows the flames: down to dim_to over dims_s while a flame's
## light is on a patch, back to rest over returns_s once it has gone.
func step(delta: float) -> void:
	var near_m := float(G.get("dims_near_flame_m", 3.0))
	var dim_to := clampf(float(G.get("dim_to", 0.1)), 0.0, 1.0)
	var down := (1.0 - dim_to) / maxf(float(G.get("dims_s", 0.6)), 0.01)
	var up := (1.0 - dim_to) / maxf(float(G.get("returns_s", 6.0)), 0.01)
	var changed := false
	for p in patches:
		var lit := fires != null and fires.lit_on(p.pos, p.n, near_m)
		var was := float(p.level)
		p.level = move_toward(was, dim_to if lit else 1.0, (down if lit else up) * delta)
		changed = changed or float(p.level) != was
	if changed:
		_upload()


## The patches into the stone shader's data (glow_moss_data).
func _upload() -> void:
	for i in patches.size():
		var p: Dictionary = patches[i]
		var pos: Vector3 = p.pos
		var n: Vector3 = p.n
		_img.set_pixel(i, 0, Color(pos.x, pos.y, pos.z, float(p.r)))
		_img.set_pixel(i, 1, Color(n.x, n.y, n.z, energy_of(p)))
	_tex.update(_img)
