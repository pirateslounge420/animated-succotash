class_name HangingGardens
## The hanging gardens' shape and delve (design 3 Oct §DT, ruins.json
## styles.hanging_gardens, Monuments._hanging_gardens): a stepped mound of
## `terraces` square terraces, each tier_m high, the lowest across_m wide
## and the top one 2 * top_half; its back (+z) toward its river. Each
## terrace is a retaining wall (WALL_T thick, a ring at half(k)) and the
## soil slab of its band; inside it is hollow but for the galleries.
## The delve (HangingGardens.layout): in at the front foot, the vaulted
## galleries under the terraces one a level, left and right by turns, the
## stairs between them climbing across; from the top gallery the channel's
## tunnel runs down and back to the cistern at the foot of the mound (the
## heart, where the water-lift stood), and out at the back by the river
## (the channel's mouth). Every y is from the frame's base_e (Delves.frame).

## A terrace at least this high (a gallery and its stair fit under it).
const TIER_MIN_M := 5.0
const WALL_T := 2.0
## The galleries: half width, ceiling, how far they reach in past the next
## terrace's wall.
const GAL_HALF := 1.8
const GAL_H := 3.2
const GAL_OVER := 4.5
## The cistern's length and half width.
const CISTERN_LEN := 9.0
const CISTERN_HALF := 2.5


## Half the side of terrace `k` (0 the lowest).
static func half(site: Dictionary, k: int) -> float:
	var n := int(site.terraces)
	var r := float(site.across_m) * 0.5
	var t := float(site.top_half)
	return r - (r - t) * k / maxf(n - 1, 1)


## The top of terrace `k` (its soil); k = -1 the ground floor.
static func top(site: Dictionary, k: int) -> float:
	return float(site.base_y) + (k + 1) * float(site.tier_m)


## The underside of whatever solid stands over (x, z) in the mound: a
## terrace's slab, or a retaining wall's foot (-INF in the lowest wall,
## which stands on the ground; INF outside the mound).
static func roof_at(site: Dictionary, x: float, z: float) -> float:
	var r := maxf(absf(x), absf(z))
	var n := int(site.terraces)
	if r >= half(site, 0):
		return INF
	var k := 0
	while k + 1 < n and r < half(site, k + 1):
		k += 1
	if r >= half(site, k) - WALL_T:
		return -INF if k == 0 else top(site, k - 1) - 1.0
	return top(site, k) - 1.0


static func layout(map: PlanetData, site: Dictionary) -> Dictionary:
	var fr := Delves.frame(map, site)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "gardens_delve"])
	var n := int(site.terraces)
	var th := float(site.tier_m)
	var m := n - 1
	var run := th / Delves.SLOPE
	var gx := run * 0.5 + GAL_HALF
	var pieces: Array = []
	# 0: the way in, through the lowest wall at the front foot, up (or
	# down) from the ground outside to the galleries' floor.
	var x0 := -gx
	var z_in := -half(site, 0) + WALL_T + 0.3
	var g_out := Delves._g0(map, fr, x0, -half(site, 0) - 1.0)
	var rise := float(site.base_y) - g_out
	var len_in := maxf(WALL_T + 0.6, absf(rise) / Delves.SLOPE + 0.6)
	pieces.append(Delves.piece("passage", Vector2(x0, z_in - len_in), Vector2(0.0, 1.0), len_in, 1.2, g_out + 0.05, float(site.base_y), Delves.H_STAIR))
	# The galleries and the stairs between them.
	for k in m:
		var gxk := -gx if k % 2 == 0 else gx
		var y := top(site, k - 1)
		var z0 := -half(site, k) + WALL_T + 0.3
		var step := half(site, k) - half(site, k + 1)
		pieces.append(Delves.piece("room", Vector2(gxk, z0), Vector2(0.0, 1.0), step + GAL_OVER, GAL_HALF, y, y, GAL_H))
		if k < m - 1:
			var sgn := 1.0 if gxk < 0.0 else -1.0
			var zs := -half(site, k + 1) + WALL_T + 0.3 + 2.0
			pieces.append(Delves.piece("stair", Vector2(gxk + sgn * GAL_HALF, zs), Vector2(sgn, 0.0), run, 0.85, y, y + th, Delves.H_STAIR))
	# The channel's tunnel down from the top gallery's far end to the
	# cistern at the floor.
	var last: Dictionary = pieces[pieces.size() - 1]
	var lx := float((last.c as Vector2).x)
	var za := float((last.c as Vector2).y) + float(last.len)
	var y_top := float(last.y0)
	var drop := y_top - float(site.base_y)
	var tunnel := Delves.piece("stair", Vector2(lx, za), Vector2(0.0, 1.0), maxf(drop / Delves.SLOPE, 1.0), 0.85, y_top, float(site.base_y), Delves.H_STAIR)
	pieces.append(tunnel)
	var zb := za + float(tunnel.len)
	var heart := Delves.piece("heart", Vector2(lx, zb), Vector2(0.0, 1.0), CISTERN_LEN, CISTERN_HALF, float(site.base_y), float(site.base_y), Delves.H_HEART)
	pieces.append(heart)
	# The way out: on through the back wall to the ground by the river.
	var ze := zb + CISTERN_LEN
	var back := half(site, 0)
	var g_back := Delves._g0(map, fr, lx, back + 1.5)
	var len_out := maxf(back + 1.0 - ze, absf(g_back - float(site.base_y)) / Delves.SLOPE + 0.6)
	var exit := Delves.piece("exit", Vector2(lx, ze), Vector2(0.0, 1.0), len_out, 0.9, float(site.base_y), g_back + 0.05, Delves.H_STAIR)
	pieces.append(exit)
	# Every piece under the mound with room to spare (its ceiling under
	# the slab or wall over it): else the mound won't hold it.
	var ok := ze < back - WALL_T - 0.5
	for pc in pieces:
		if not ok:
			break
		if str(pc.kind) in ["passage", "exit"]:
			continue
		var a := 0.0
		while a <= float(pc.len) + 0.01:
			for s: float in [-1.0, 1.0]:
				var p: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + Delves.perp(pc.dir) * s * (float(pc.half) + Delves.WALL)
				var ceil_y := maxf(Delves.floor_of(pc, a), Delves.floor_of(pc, minf(a + 1.0, float(pc.len)))) + float(pc.h) + Delves.SLAB + 0.3
				if ceil_y > roof_at(site, p.x, p.y):
					ok = false
			a += 1.0
	# The ground's holes: where the way out leaves the mound (its ceiling
	# above the ground beyond the wall).
	var out_from := back - ze - 0.5
	var holes: Array = [Delves.rect_of(exit, 0.0, maxf(out_from, 0.0), len_out + 0.5)]
	var heart_i := pieces.size() - 2
	var lay := {"ok": ok, "climbs": true, "base_e": fr.base_e, "pieces": pieces, "holes": holes, "exit": exit, "cairn": {},
		"room_i": 1, "heart_i": heart_i, "exit_open": maxf(out_from, 0.0),
		"door_out": Vector3(x0, g_out, -half(site, 0) - 1.5)}
	# The first gallery's old hearth (the safe room, §CJ); the cistern's
	# hearth ring by its basin; the find on its far side.
	var g0: Dictionary = pieces[1]
	lay.hearth = Vector3(float((g0.c as Vector2).x), float(g0.y0), float((g0.c as Vector2).y) + float(g0.len) * 0.35)
	lay.heart_hearth = Vector3(lx - 1.4, float(site.base_y), zb + 1.6)
	lay.find_kind = "spear" if rng.randf() < 0.5 else "bow"
	lay.find = Vector3(lx + 1.5, float(site.base_y), zb + CISTERN_LEN - 1.5)
	lay.feature = "galleries"
	return lay
