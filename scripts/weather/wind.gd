class_name Wind
## The wind you can see (design 3 Oct §DA, data/wind.json; Wind I): one
## wind, the weather's (WeatherSim.local_weather, which WeatherFX sets as
## the global plant_wind each frame; nothing here changes the weather),
## with a gust field on top that every reader samples at its own position,
## so a gust is a patch of stronger air that runs across the ground.
##
## The field is written twice and must agree: here for the CPU readers,
## and in shaders/wind.gdshaderinc for the shaders (the plants, the grass,
## the dapple under the trees, the aroids). tools/wind_check.gd renders
## the shader's numbers and compares them with these.
##
## - gust_field(): two octaves of value noise at gusts.patch_m in the
##   planet's frame, carried downwind at the mean wind's speed in real
##   seconds (frozen turbulence). tick() sums the wind's travel (the drift)
##   each frame and sets the shaders' wind_shift. The factor is
##   1 + intensity x the noise, clamped to [lull_min, factor_max]; the
##   direction veers by up to veer_deg; below calm_mps it fades to 1.
## - profile(): the share of the 10 m wind at a height over open ground
##   (the log profile, z0 by the ground round you: water, snow, sand,
##   grass or scrub; under trees the shelter rule does the work instead).
## - shelter(): below the crowns, shelter_floor + (1 - shelter_floor) x the
##   spot's sky visibility (§BD's number). The crowns take the full wind.
##   Enclosed (in a delve): none.
## - stamp(): at placement, each plant's sky visibility (in 31sts), its kind (grass
##   and herbs, woody, or a canopy crown) and its flutter flag (Populus,
##   Ficus religiosa) go into its instance custom data's blue, for the
##   foliage shader.

static var D: Dictionary = Tuning.table("wind")
static var G: Dictionary = D.get("gusts", {})
static var P: Dictionary = D.get("profile", {})
static var C: Dictionary = D.get("crowns", {})
static var GR: Dictionary = D.get("grass", {})
static var FL: Dictionary = D.get("flutter", {})

## 1 / the noise's standard deviation (measured over 6,000 points; the big swell weighs 0.85, the small puff 0.15, so neighbours 3 m apart share a gust), so
## `intensity` is the gusts' own standard deviation as a share of the mean.
const NORM := 3.12
## The noise repeats every 1024 cells; the drift wraps on a period both
## octaves repeat on (1024 x 120 m, the patches' common multiple).
const PERIOD_CELLS := 1024
const OCT2_OFF := Vector3(17.0, 31.0, 47.0)

## The mean wind now (WeatherFX.plant_wind), the drift (m, wrapped), the
## clock (real s) and the ground's roughness round the player.
static var mean := Vector3.ZERO
static var drift := Vector3.ZERO
static var clock := 0.0
static var z0 := 0.03
static var _center := Vector3.ZERO
static var _z0_t := 0.0
static var _set := false


static func patch() -> Vector2:
	var p: Array = G.get("patch_m", [40.0, 12.0])
	return Vector2(float(p[0]), float(p[1]))


static func period_m() -> float:
	var p := patch()
	# Both octaves repeat on PERIOD_CELLS x their patch; the drift wraps
	# on a multiple of both (40 and 12 m: 120 m a cell).
	return PERIOD_CELLS * _lcm(roundi(p.x), roundi(p.y))


static func _lcm(a: int, b: int) -> float:
	var x := maxi(a, 1)
	var y := maxi(b, 1)
	var g := x
	var h := y
	while h != 0:
		var t := g % h
		g = h
		h = t
	return float(x / g * y)


## The shaders' constant uniforms, from wind.json (Main, once).
static func setup() -> void:
	var p := patch()
	var period: Array = C.get("sway_period_s", [[3.0, 0.8], [10.0, 1.7], [20.0, 2.8], [40.0, 4.5], [70.0, 6.0]])
	var hs := PackedFloat32Array()
	var ss := PackedFloat32Array()
	for row in period:
		hs.append(float(row[0]))
		ss.append(float(row[1]))
	while hs.size() < 5:
		hs.append(hs[hs.size() - 1] + 1.0)
		ss.append(ss[ss.size() - 1])
	var RS := RenderingServer
	RS.global_shader_parameter_set("wind_gust", Vector4(float(G.get("intensity", 0.28)), float(G.get("factor_max", 1.6)), float(G.get("lull_min", 0.45)), float(G.get("calm_mps", 0.5))))
	RS.global_shader_parameter_set("wind_gust2", Vector4(p.x, p.y, deg_to_rad(float(G.get("veer_deg", 10.0))), NORM))
	RS.global_shader_parameter_set("wind_prof", Vector4(z0, float(P.get("reference_height_m", 10.0)), float(P.get("shelter_floor", 0.15)), float(FL.get("amount", 0.08))))
	RS.global_shader_parameter_set("wind_crowns", Vector4(float(C.get("leaves_mps", 1.6)), float(C.get("twigs_mps", 3.4)), float(C.get("small_branches_mps", 5.5)), float(C.get("small_trees_mps", 8.0))))
	RS.global_shader_parameter_set("wind_crowns2", Vector4(float(C.get("large_branches_mps", 10.8)), float(C.get("whole_trees_mps", 13.9)), float(FL.get("from_mps", 0.1)), float(GR.get("lean_max", 0.55))))
	RS.global_shader_parameter_set("wind_grass", Vector4(float(GR.get("lean_from_mps", 1.6)), float(GR.get("flatten_mps", 13.9)), 1.0 if bool(GR.get("sheen", true)) else 0.0, 0.0))
	RS.global_shader_parameter_set("wind_sway_h", Vector4(hs[0], hs[1], hs[2], hs[3]))
	RS.global_shader_parameter_set("wind_sway_s", Vector4(ss[0], ss[1], ss[2], ss[3]))
	RS.global_shader_parameter_set("wind_sway_last", Vector2(hs[4], ss[4]))
	_set = true


## Each frame (Main, after WeatherFX): the wind's travel this frame, the
## shaders' wind_shift, and every couple of seconds the ground's roughness
## round the player. `delta` real seconds.
static func tick(delta: float, world, player) -> void:
	if not _set:
		setup()
	mean = WeatherFX.plant_wind
	clock += delta
	drift += mean * delta
	var per := period_m()
	drift = Vector3(fposmod(drift.x, per), fposmod(drift.y, per), fposmod(drift.z, per))
	if world != null:
		_center = world.planet_center()
	RenderingServer.global_shader_parameter_set("wind_shift", shift())
	_z0_t -= delta
	if _z0_t <= 0.0 and player != null and player is PlanetPlayer:
		_z0_t = 2.0
		var z := ground_z0(Footsteps.material_under(player))
		if not is_equal_approx(z, z0):
			z0 = z
			RenderingServer.global_shader_parameter_set("wind_prof", Vector4(z0, float(P.get("reference_height_m", 10.0)), float(P.get("shelter_floor", 0.15)), float(FL.get("amount", 0.08))))


## The field's offset for scene points: -(planet centre) - drift.
static func shift() -> Vector3:
	return -_center - drift


## The roughness (profile.z0_m) for what's underfoot (Footsteps'
## materials): water, snow, sand, grass; bare dirt, stone and wood count as
## scrub. Under trees the shelter rule stands in for the forest's own.
static func ground_z0(material: String) -> float:
	var z: Dictionary = P.get("z0_m", {})
	match material:
		"water":
			return float(z.get("water", 0.0002))
		"snow":
			return float(z.get("snow", 0.001))
		"sand":
			return float(z.get("sand", 0.001))
		"grass":
			return float(z.get("grass", 0.03))
	return float(z.get("scrub", 0.1))


## One lattice value, 0-1 (wind.gdshaderinc wind_hash, in 32-bit
## arithmetic).
static func _hash(x: int, y: int, z: int) -> float:
	var ux := x & 1023
	var uy := y & 1023
	var uz := z & 1023
	var h := (ux * 374761393 + uy * 668265263 + uz * 1440662683) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 16777215) / 16777215.0


## Smoothed value noise, 0-1 (wind_vnoise).
static func _vnoise(p: Vector3) -> float:
	var ix := floorf(p.x)
	var iy := floorf(p.y)
	var iz := floorf(p.z)
	var fx := p.x - ix
	var fy := p.y - iy
	var fz := p.z - iz
	var wx := fx * fx * (3.0 - 2.0 * fx)
	var wy := fy * fy * (3.0 - 2.0 * fy)
	var wz := fz * fz * (3.0 - 2.0 * fz)
	var cx := int(ix)
	var cy := int(iy)
	var cz := int(iz)
	var x00 := lerpf(_hash(cx, cy, cz), _hash(cx + 1, cy, cz), wx)
	var x10 := lerpf(_hash(cx, cy + 1, cz), _hash(cx + 1, cy + 1, cz), wx)
	var x01 := lerpf(_hash(cx, cy, cz + 1), _hash(cx + 1, cy, cz + 1), wx)
	var x11 := lerpf(_hash(cx, cy + 1, cz + 1), _hash(cx + 1, cy + 1, cz + 1), wx)
	return lerpf(lerpf(x00, x10, wy), lerpf(x01, x11, wy), wz)


## The field at field point `q` (a scene point plus shift()) under a mean
## wind of `mean_mps`: (factor, veer in radians) (wind_gust_field).
static func gust_field(q: Vector3, mean_mps: float) -> Vector2:
	var p := patch()
	var a := _vnoise(q / p.x) * 2.0 - 1.0
	var b := _vnoise(q / p.y + OCT2_OFF) * 2.0 - 1.0
	var n := (0.85 * a + 0.15 * b) * NORM
	var calm := clampf(mean_mps / maxf(float(G.get("calm_mps", 0.5)), 1e-3), 0.0, 1.0)
	var f := clampf(1.0 + float(G.get("intensity", 0.28)) * n, float(G.get("lull_min", 0.45)), float(G.get("factor_max", 1.6)))
	var veer := deg_to_rad(float(G.get("veer_deg", 10.0))) * clampf((a - b) * 1.9, -1.0, 1.0)
	return Vector2(lerpf(1.0, f, calm), veer * calm)


## The gust at scene point `world_pos` at `time` real seconds on Wind's
## clock (now: Wind.clock): (factor, veer in radians). Away from now the
## field is carried on at today's mean wind (steady), which is how the
## checks step it.
static func gust_at(world_pos: Vector3, time: float) -> Vector2:
	var q := world_pos + shift() - mean * (time - clock)
	return gust_field(q, mean.length())


## The gusted wind at scene point `p` now (m/s, a world vector: the mean
## times the factor, veered about `up`) (wind_gust_vec).
static func gust_vec(p: Vector3, up: Vector3) -> Vector3:
	var g := gust_field(p + shift(), mean.length())
	var v := mean * g.x
	return v * cos(g.y) + up.cross(v) * sin(g.y)


## The share of the 10 m wind `z` m up over open ground (wind_profile).
static func profile(z: float, z0_m := -1.0) -> float:
	var r := maxf(z0 if z0_m < 0.0 else z0_m, 1e-4)
	return clampf(log(maxf(z, r * 1.5) / r) / log(float(P.get("reference_height_m", 10.0)) / r), 0.0, 1.5)


## Below the crowns: the share of the wind through, by sky visibility
## (wind_shelter). Enclosed: profile.enclosed (none).
static func shelter(sky: float, enclosed := false) -> float:
	if enclosed:
		return float(P.get("enclosed", 0.0))
	var f := float(P.get("shelter_floor", 0.15))
	return f + (1.0 - f) * clampf(sky, 0.0, 1.0)


## The wind (m/s) on something `z` m up at scene point `p`, under sky
## visibility `sky` (1 open), a crown or not: the gusted 10 m wind x the
## profile x the shelter. For the CPU readers of later passes.
static func at(p: Vector3, up: Vector3, z: float, sky := 1.0, crown := false, enclosed := false) -> Vector3:
	var s := 1.0 if crown and not enclosed else shelter(sky, enclosed)
	return gust_vec(p, up) * profile(z) * s


## Flutter: genus Populus and the species Ficus religiosa (flutter.genera,
## flutter.species).
static func flutters(sp: PlantSpecies) -> bool:
	return (FL.get("genera", ["Populus"]) as Array).has(sp.genus) or (FL.get("species", ["Ficus religiosa"]) as Array).has(sp.name)


## The plant's wind kind for the foliage shader: 1 grass, reeds and herbs
## (they bow); 2 a canopy or emergent crown (always the full wind); 0
## the rest (shrubs and the understory, sheltered).
static func kind_of(sp: PlantSpecies) -> int:
	var S := PlantSpecies.Shape
	if sp.shape in [S.GRASS, S.TUSSOCK, S.REED]:
		return 1
	if sp.tier == PlantSpecies.Tier.GROUND and sp.shape in [S.FERN, S.ROSETTE]:
		return 1
	if sp.tier == PlantSpecies.Tier.EMERGENT or sp.tier == PlantSpecies.Tier.CANOPY:
		return 2
	return 0


## The code in a plant's custom data blue: rustle (0-1, TreeContact) +
## 2 x (cover 0-31 + 32 x flutter + 64 x kind), cover = (1 - sky
## visibility) in 31sts, so an unstamped plant (0) stands in the open.
static func code(sky: float, flutter: bool, kind: int) -> float:
	var cover := clampi(roundi((1.0 - clampf(sky, 0.0, 1.0)) * 31.0), 0, 31)
	return 2.0 * float(cover + (32 if flutter else 0) + 64 * kind)


## A code's (sky visibility, flutter 0/1, kind), as the foliage shader
## reads it.
static func decode(b: float) -> Vector3:
	var c := floorf(b * 0.5 + 1e-4)
	return Vector3(1.0 - fmod(c, 32.0) / 31.0, fmod(floorf(c / 32.0), 2.0), floorf(c / 64.0))


## The rustle in a custom data blue, without its code.
static func rustle_of(b: float) -> float:
	return b - 2.0 * floorf(b * 0.5 + 1e-4)


## The custom data blue with `rustle` and the code kept.
static func with_rustle(b: float, rustle: float) -> float:
	return 2.0 * floorf(b * 0.5 + 1e-4) + clampf(rustle, 0.0, 1.0)


## The sky visibility grid for a chunk (64 x 64, about 4 m a cell) from
## its dapple map (CanopyDapple: white is open sky), by box-filtered mips;
## empty when the chunk has none (all open).
static func shelter_grid(dapple: Image) -> PackedByteArray:
	if dapple == null:
		return PackedByteArray()
	var img := dapple.duplicate() as Image
	if img.get_format() != Image.FORMAT_R8:
		img.convert(Image.FORMAT_R8)
	img.generate_mipmaps()
	var lvl := 0
	var n := img.get_width()
	while n > 64 and lvl < img.get_mipmap_count():
		lvl += 1
		n = maxi(n / 2, 1)
	var off := img.get_mipmap_offset(lvl)
	return img.get_data().slice(off, off + n * n)


## Stamp every placed plant's code (VegetationPlacer.prepare()'s output,
## `plants`: species key -> [buf, count, trees, layouts]) on the chunk worker,
## from the chunk's `dapple` map (§BD's sky visibility) round `center`.
static func stamp(plants: Dictionary, dapple: Image, center: Vector3) -> void:
	var grid := shelter_grid(dapple)
	var gn := int(sqrt(float(grid.size())))
	var east := CubeSphere.east(center)
	var north := CubeSphere.north(center)
	var span := CanopyDapple.span_m()
	var all := SpeciesDB.all()
	for pkey in plants:
		# (A young stand is keyed with its stage: PlantGrowth.JUV_KEY.)
		var sp: PlantSpecies = all[int(pkey) % PlantGrowth.JUV_KEY]
		var fl := flutters(sp)
		var kind := kind_of(sp)
		var rec: Array = plants[pkey]
		rec[0] = _stamp_buf(rec[0], fl, kind, grid, gn, east, north, span)
		if rec.size() > 3 and rec[3] is Dictionary:
			for l in rec[3]:
				var lay: Array = rec[3][l]
				lay[0] = _stamp_buf(lay[0], fl, kind, grid, gn, east, north, span)


## One MultiMesh buffer's codes (a packed array is a value: the caller
## stores the result back).
static func _stamp_buf(buf: PackedFloat32Array, fl: bool, kind: int, grid: PackedByteArray, gn: int, east: Vector3, north: Vector3, span: float) -> PackedFloat32Array:
	var S := VegetationPlacer.MM_STRIDE
	var count := buf.size() / S
	for i in count:
		var k := i * S
		var sky := 1.0
		if gn > 0 and kind != 2:
			var p := Vector3(buf[k + 3], buf[k + 7], buf[k + 11])
			var gx := int((p.dot(east) / span + 0.5) * gn)
			var gy := int((p.dot(north) / span + 0.5) * gn)
			if gx >= 0 and gy >= 0 and gx < gn and gy < gn:
				sky = grid[gy * gn + gx] / 255.0
		buf[k + 18] = code(sky, fl, kind)
	return buf
