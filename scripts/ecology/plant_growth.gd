class_name PlantGrowth
## Plants grow at their real rates on the game's clock (design §AR, from
## play: "the life cycle of a seed or tuber or any other plant should
## directly correlate to its speed in real life; game time is 10x faster
## than earth, so each plant should grow about 10x faster in game"). A game
## day is 144 real minutes, and every plant grows a real day's worth in it:
## a leaf that takes 30 days to unfurl takes 30 game days (three real
## days); an oak's 40 years are 40 game years (four real years).
##
## Nothing is stored. A plant's age is a function of where it grows (a hash
## of its place: the same plant on every visit) and the world clock; its
## height is its species' height-by-age curve at that age, from the
## researched `growth` block (height_years: the years to half and to ~90 %
## of full height, open-grown), fitted per species as the Chapman-Richards
## curve h = H (1 - e^(-k t))^p. Growth slows in shade by how much shade
## the species' young stand: a tolerant fir's seedling keeps growing slowly
## under the canopy for decades; an intolerant pine's barely grows and
## dies within a year or two (yearly_survival()).
##
## Stages: SEEDLING (under about a metre, or a twelfth of full height for
## small plants), SAPLING (to about a third of full height), POLE (a young
## tree, to 70 %), MATURE, OLD (past three quarters of its typical life).
## PlantMeshes draws the young ones in their species' young form
## (`juvenile`: a whip, a cone, a palm's stemless establishment rosette...).
##
## Light and leaves: a plant's light (0 deep shade .. 1 open sky) comes from
## the crowns above it (VegetationPlacer); shade leaves grow larger (and
## thinner and darker) than sun leaves, so its leaf size is scaled up to
## ~1.45x in deep shade and down to ~0.85x in full sun, more for the shade-
## tolerant species (the plastic ones). The scale rides in the MultiMesh
## custom data's green beside the vines (vines 0-1 + 2 x a code 1-16; 0
## means no code, full size), which the foliage shader reads.

enum Stage { SEEDLING, SAPLING, POLE, MATURE, OLD }
## What the HUD adds after a plant's name for its stage ("" : nothing).
const STAGE_WORDS := ["seedling", "sapling", "young tree", "", ""]

## World.days when a new game starts (World.days' first value): the world
## as first seen is the world as placed, and ages run on from there.
const EPOCH_DAYS := 13.62
## The world clock as the chunk workers see it (game days): the main thread
## sets it (ChunkManager) before handing chunks out.
static var now_days := EPOCH_DAYS

## Understory young (VegetationPlacer): their records and MultiMeshes are
## keyed species index + JUV_KEY x a code: 1 a seedling, 2 an open-grown
## sapling, 3 a forest-grown one, 4 / 5 the same for a young tree (pole).
const JUV_KEY := 1 << 16

const SHADE_TOL := {"very_intolerant": 0.0, "intolerant": 0.25, "intermediate": 0.5, "tolerant": 0.75, "very_tolerant": 1.0}
## Leaf-size codes: 1..16 -> LEAF_MIN .. LEAF_MIN + 15 LEAF_STEP (0: none,
## full size).
const LEAF_MIN := 0.8
const LEAF_STEP := 0.05
## Understory young grow out of the understory at this share of full height
## (and are then counted among the stand's trees).
const UNDERSTORY_CAP := 0.35


## Every species' curve and traits from its `growth` block (SpeciesDB).
static func setup(all: Array) -> void:
	for sp in all:
		_derive(sp)


static func _derive(sp: PlantSpecies) -> void:
	var g := sp.growth
	var hy = g.get("height_years")
	if g.is_empty() or g.has("stages") or not (hy is Array and (hy as Array).size() == 2):
		_defaults(sp)
		return
	var t50 := maxf(float(hy[0]), 0.005)
	var t90 := maxf(float(hy[1]), t50 * 1.05)
	var kp := fit(t50, t90)
	sp.grow_k = kp.x
	sp.grow_p = kp.y
	sp.shade_tol = float(SHADE_TOL.get(str(g.get("shade", "intermediate")), 0.5))
	sp.juvenile = str(g.get("juvenile", "whip"))
	sp.life = str(g.get("life", "perennial"))
	var ls = g.get("lifespan_years")
	if ls is Array and (ls as Array).size() == 2:
		sp.lifespan_y = Vector2(float(ls[0]), float(ls[1]))
	sp.first_seed_y = float(g.get("first_seed_years", t50))
	var ty = g.get("trunk_years")
	sp.trunk_y = float(ty) if ty != null else 0.0


## No growth block (fungi, placeholders): a curve for the tier and shape.
static func _defaults(sp: PlantSpecies) -> void:
	var t := Vector2(4.0, 12.0)
	match sp.tier:
		PlantSpecies.Tier.EMERGENT, PlantSpecies.Tier.CANOPY:
			t = Vector2(20.0, 60.0)
		PlantSpecies.Tier.GROUND:
			t = Vector2(0.4, 1.5)
	var kp := fit(t.x, t.y)
	sp.grow_k = kp.x
	sp.grow_p = kp.y
	sp.first_seed_y = t.x
	sp.lifespan_y = Vector2(t.y * 3.0, t.y * 8.0)


## The curve through (t50, half) and (t90, 90 %): p from the ratio
## t90 / t50 (which falls as p grows), then k.
static func fit(t50: float, t90: float) -> Vector2:
	var r := t90 / t50
	var lo := 0.25
	var hi := 30.0
	for i in 48:
		var mid := sqrt(lo * hi)
		if _ratio(mid) > r:
			lo = mid
		else:
			hi = mid
	var p := sqrt(lo * hi)
	var k := -log(1.0 - pow(0.5, 1.0 / p)) / t50
	return Vector2(k, p)


static func _ratio(p: float) -> float:
	return log(1.0 - pow(0.9, 1.0 / p)) / log(1.0 - pow(0.5, 1.0 / p))


## The share of full height at `age_y` years of growth (in good light).
static func fraction(sp: PlantSpecies, age_y: float) -> float:
	if age_y <= 0.0:
		return 0.0
	return pow(1.0 - exp(-sp.grow_k * age_y), sp.grow_p)


## The years of growth to reach share `f` of full height.
static func age_of(sp: PlantSpecies, f: float) -> float:
	var ff := clampf(f, 0.0, 0.999)
	if ff <= 0.0:
		return 0.0
	return -log(1.0 - pow(ff, 1.0 / sp.grow_p)) / sp.grow_k


## The stage of a plant at share `f` of its full height `h_full_m`, `age_y`
## years old.
static func stage_of(sp: PlantSpecies, f: float, age_y: float, h_full_m: float) -> int:
	if f < clampf(1.0 / maxf(h_full_m, 0.01), 0.04, 0.12):
		return Stage.SEEDLING
	if f < UNDERSTORY_CAP:
		return Stage.SAPLING
	if f < 0.7:
		return Stage.POLE
	if age_y > sp.lifespan_y.x * 0.75:
		return Stage.OLD
	return Stage.MATURE


## How fast it grows at `light` (0-1), as a share of its open-grown rate:
## a shade-tolerant young plant keeps a third of its pace in deep shade, an
## intolerant one a sixteenth.
static func shade_rate(sp: PlantSpecies, light: float) -> float:
	return lerpf(lerpf(0.06, 0.3, sp.shade_tol), 1.0, smoothstep(0.05, 0.7, light))


## The light (0-1, a share of open sky) a species' young need to get going
## and keep going: half of full sun for a very intolerant pine or birch, a
## fifth for an intolerant one, a tenth for the middling oaks and ashes, a
## few percent for a tolerant maple and 1.5 % for a very tolerant fir,
## hemlock or beech, whose seedling bank lives on a closed forest's floor
## (1-5 % of full sun). Geometric between.
static func light_need(sp: PlantSpecies) -> float:
	return 0.5 * pow(0.03, sp.shade_tol)


## The chance a young plant lives through a year at `light`: most do in the
## light they're made for; below it an intolerant seedling starves in a
## year or two, a tolerant one hangs on for years.
static func yearly_survival(sp: PlantSpecies, light: float) -> float:
	var need := light_need(sp)
	return lerpf(0.35, 0.93, smoothstep(need * 0.3, need * 1.6, light))


## How likely a seed comes up and gets going at `light` (a weight 0-1 for
## choosing which species' young grow on a spot).
static func establish(sp: PlantSpecies, light: float) -> float:
	var need := light_need(sp)
	return lerpf(0.05, 1.0, smoothstep(need * 0.4, need * 2.0, light))


## Its leaves' size at `light` as a share of the species' (shade leaves
## bigger, sun leaves smaller; the tolerant species change most).
static func leaf_scale(sp: PlantSpecies, light: float) -> float:
	var plast := lerpf(0.55, 1.0, sp.shade_tol)
	return lerpf(1.0 + 0.45 * plast, 1.0 - 0.15 * plast, smoothstep(0.05, 0.9, light))


## The code (1-16) for a leaf scale.
static func leaf_code(scale: float) -> int:
	return 1 + clampi(roundi((scale - LEAF_MIN) / LEAF_STEP), 0, 15)


## The custom data's green: vines (0-1) and the leaf code.
static func encode_green(vines: float, code: int) -> float:
	return clampf(vines, 0.0, 1.0) + 2.0 * float(clampi(code, 0, 16))


static func code_of(green: float) -> int:
	return int(floor(green * 0.5 + 1e-4))


static func vines_of(green: float) -> float:
	return green - 2.0 * float(code_of(green))


static func leaf_of(green: float) -> float:
	var c := code_of(green)
	return 1.0 if c <= 0 else LEAF_MIN + LEAF_STEP * float(c - 1)


## A young tree of the stand's regeneration cohort (data/stand.json
## young_share; VegetationPlacer): how far it has got (a sapling or a young
## tree in a gap, from where it stands, not the chunk's random stream) and
## how tall that makes it now: [height (m), stage]. `h_full` is the height
## it will reach.
static func young_tree(sp: PlantSpecies, d: Vector3, h_full: float) -> Array:
	var key := hash([sp.name, "young", d])
	var f := lerpf(0.36, 0.7, PlantGenetics.unit(key, 2)) if PlantGenetics.unit(key, 3) < 0.65 \
		else lerpf(0.14, 0.35, PlantGenetics.unit(key, 2))
	# On from the day the world was first seen, at a gap's pace.
	var age := age_of(sp, f) + maxf(now_days - EPOCH_DAYS, 0.0) / 365.0
	f = fraction(sp, age)
	return [h_full * f, stage_of(sp, f, age, h_full)]


## The occupant of an understory spot now, [height (m), stage], or [] when
## the spot is empty. Occupants follow one another: each comes up a while
## after the last (its seed's wait and germination), grows at its species'
## rate slowed by the shade (shade_rate()), and either dies (a year's
## survival: yearly_survival()) or grows out of the understory (past
## UNDERSTORY_CAP of its full height `h_full`), after which the spot waits
## for the next seed. `key`: the spot's hash; `light` there.
static func understory(sp: PlantSpecies, key: int, light: float, h_full: float) -> Array:
	var rate := shade_rate(sp, light)
	var surv := clampf(yearly_survival(sp, light), 0.05, 0.995)
	var t_out := maxf(age_of(sp, UNDERSTORY_CAP) / rate, 0.05)
	var now_y := now_days / 365.0
	var germ = sp.growth.get("germination_days", [14, 60])
	var germ_y := (float(germ[0]) + float(germ[1])) * 0.5 / 365.0 if germ is Array and (germ as Array).size() == 2 else 0.1
	# The run of occupants started a while back: within a few lives.
	var span := minf(t_out, 80.0) * 2.5 + 3.0
	var t := now_y - span * PlantGenetics.unit(key, 11)
	for n in 48:
		# How long this one lives: survival year on year, at most until it
		# grows out.
		var u := PlantGenetics.unit(key, 20 + n)
		var life_y := minf(-log(maxf(1.0 - u, 1e-6)) / maxf(-log(surv), 1e-4) + germ_y, t_out + germ_y)
		if now_y < t + life_y:
			var age := now_y - t - germ_y
			if age <= 0.0:
				return [] # still a seed
			var f := fraction(sp, age * rate)
			return [h_full * f, stage_of(sp, f, age, h_full)]
		t += life_y + lerpf(0.3, 3.0, PlantGenetics.unit(key, 90 + n))
		if t > now_y:
			return []
	return []


## A young stage's code among the understory keys (JUV_KEY): 1 a seedling,
## 2 / 3 an open- / forest-grown sapling, 4 / 5 a young tree (pole).
static func young_code(stage: int, open: bool) -> int:
	match stage:
		Stage.SEEDLING:
			return 1
		Stage.SAPLING:
			return 2 if open else 3
		Stage.POLE:
			return 4 if open else 5
	return 0


## The stage an understory code draws.
static func stage_of_code(code: int) -> int:
	if code == 1:
		return Stage.SEEDLING
	return Stage.SAPLING if code <= 3 else Stage.POLE
