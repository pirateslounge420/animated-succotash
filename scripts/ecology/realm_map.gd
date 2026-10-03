class_name RealmMap
## Where the biogeographic realms lie on this planet (design §AA, the realm
## gate; engine-side proposal, the designer to confirm). Earth's realms are
## continents' floras; this world's continents are noise, so:
##
## Provinces - PROVINCES continent-scale regions, a Voronoi of seeded
##   points on the sphere with warped borders. Each is one "world": the New
##   World, Afro-Europe, Asia, Malesia-Australasia or Oceania (WORLDS, dealt
##   out in a seeded order so each appears).
## Realm - within its world, a place's realm follows its own climate and
##   height, the way Earth's does: tropical New World lowland is
##   neotropic, its high tropical and southern mountains andes, its cool
##   north nearctic; in Asia the humid subtropics are sino_subtropical, the
##   dry interior central_asia, the high mountains himalaya; and so on
##   (realm()).
##
## VegetationPlacer asks realm() per site; a catalogue species tagged with
## realms grows there only if the site's realm is one of them and the
## site's biome has an association for that realm (SpeciesDB.biome_hosts).
## Pure functions of the world seed: thread-safe after warm().

enum World { NEW_WORLD, AFRO_EUROPE, ASIA, AUSTRAL, OCEANIA }
const WORLD_NAMES := ["new_world", "afro_europe", "asia", "austral", "oceania"]
## The provinces' worlds, before the seeded shuffle.
const WORLDS := [World.NEW_WORLD, World.NEW_WORLD, World.AFRO_EUROPE, World.AFRO_EUROPE,
	World.ASIA, World.ASIA, World.ASIA, World.AUSTRAL, World.OCEANIA]
const PROVINCES := 9
## Real metres (the data's altitude bands), not this world's.
const ANDES_M := 1500.0
const HIMALAYA_M := 2000.0

static var _centers := PackedVector3Array()
static var _worlds := PackedInt32Array()
static var _warp := FastNoiseLite.new()
static var _isle := FastNoiseLite.new()
static var _seed := -1


static func warm(world_seed: int) -> void:
	if _seed == world_seed:
		return
	_seed = world_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "realms"])
	_centers.clear()
	# Evenly spread (a Fibonacci sphere), turned at random.
	var turn := Basis(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized(), rng.randf() * TAU)
	for i in PROVINCES:
		var y := 1.0 - (i + 0.5) / PROVINCES * 2.0
		var r := sqrt(1.0 - y * y)
		var a := PI * (3.0 - sqrt(5.0)) * i
		_centers.append((turn * Vector3(cos(a) * r, y, sin(a) * r)).normalized())
	var order := WORLDS.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	_worlds = PackedInt32Array(order)
	_warp.seed = hash([world_seed, "realm_warp"])
	_warp.frequency = 1.6
	_warp.fractal_octaves = 3
	_isle.seed = hash([world_seed, "realm_isle"])
	_isle.frequency = 3.0


## The world of the province at unit direction `d`.
static func world_at(d: Vector3) -> int:
	return world_of(province_at(d))


## The province (0..PROVINCES-1) at unit direction `d`: a land of the
## planet (design 3 Oct §CS: each plant community is native to one).
static func province_at(d: Vector3) -> int:
	var w := Vector3(_warp.get_noise_3dv(d), _warp.get_noise_3dv(d + Vector3(5.3, 0, 0)), _warp.get_noise_3dv(d + Vector3(0, 7.1, 0)))
	var p := (d + w * 0.35).normalized()
	var best := 0
	var best_dot := -2.0
	for i in _centers.size():
		var dd := p.dot(_centers[i])
		if dd > best_dot:
			best_dot = dd
			best = i
	return best


## The world (World) of province `i`.
static func world_of(i: int) -> int:
	return _worlds[i] if i >= 0 and i < _worlds.size() else World.NEW_WORLD


## Province `i`'s middle (a unit direction).
static func province_center(i: int) -> Vector3:
	return _centers[i] if i >= 0 and i < _centers.size() else Vector3.UP


## The realm at `d` in `world`, for a site at `temp_c` (mean annual),
## `moist` (0-1) and `alt_m` real metres.
static func realm(world: int, d: Vector3, temp_c: float, moist: float, alt_m: float) -> String:
	var lat := rad_to_deg(CubeSphere.latitude(d))
	if lat < -60.0:
		return "antarctic"
	match world:
		World.NEW_WORLD:
			if alt_m >= ANDES_M and lat < 15.0:
				return "andes"
			if temp_c >= 18.0 or lat < -15.0:
				return "neotropic"
			return "nearctic"
		World.AFRO_EUROPE:
			if temp_c >= 20.0 and absf(lat) <= 35.0:
				return "madagascar" if lat < 0.0 and _isle.get_noise_3dv(d) > 0.45 else "afrotropic"
			if moist < 0.3 and temp_c >= 14.0:
				return "west_asia"
			if temp_c >= 13.0:
				return "mediterranean"
			return "palearctic"
		World.ASIA:
			if alt_m >= HIMALAYA_M and absf(lat) <= 40.0:
				return "himalaya"
			if temp_c >= 21.0:
				return "indomalaya"
			if temp_c >= 14.0 and moist >= 0.5:
				return "sino_subtropical"
			if moist < 0.35:
				return "central_asia" if temp_c < 14.0 else "west_asia"
			if moist >= 0.5 and temp_c >= 3.0:
				return "east_asia_temperate"
			return "palearctic"
		World.AUSTRAL:
			if temp_c >= 20.0 and moist >= 0.6:
				return "malesia"
			return "australasia"
	return "oceania"

