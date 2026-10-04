class_name PillarShrines
## The pillar shrines' delve pillar (design 3 Oct §DY, ruins.json
## styles.pillar_shrines, Monuments._pillar_shrines): the pillar at the
## valley's middle, its tiers of rock round a shaft (CragFortress's), the
## climb up inside it (CragFortress.shaft_layout: a passage in at the foot,
## flights turning at landings, the summit shrine over the shaft the heart,
## its door out onto the summit the way out).

const TIERS := 5
const BASE_HS := 14.0


## {"g_f", "top_y", "y_b", "tiers", "zs0", "zs1", "front_z", "base_e"}: the
## crag fortress's plan's shape, for the delve pillar.
static func plan(map: PlanetData, site: Dictionary) -> Dictionary:
	var fr := Delves.frame(map, site)
	var p0: Array = (site.pillars as Array)[0]
	var rise := float(p0[3])
	var g_f := Delves._g0(map, fr, 0.0, -BASE_HS)
	var g_min := INF
	for i in range(-2, 3):
		for j in range(-2, 3):
			g_min = minf(g_min, Delves._g0(map, fr, BASE_HS * i * 0.5, BASE_HS * j * 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "pillar_plan"])
	var tiers: Array = []
	for k in TIERS:
		var t := float(k) / (TIERS - 1)
		var hs := lerpf(BASE_HS, CragFortress.TOP_HS, t)
		var sx := hs * (rng.randf_range(0.95, 1.08) if k < TIERS - 1 else 1.0)
		var sz := hs
		var y0 := g_min - 3.0 if k == 0 else g_f + rise * k / TIERS
		tiers.append({"y0": y0, "y1": g_f + rise * (k + 1) / TIERS, "sx": maxf(sx, CragFortress.TOP_HS), "sz": sz, "zc": 0.0, "xc": 0.0})
	var top: Dictionary = tiers[TIERS - 1]
	return {"g_f": g_f, "top_y": g_f + rise, "y_b": g_min - 3.0, "tiers": tiers,
		"zs0": float(top.zc) - float(top.sz) + CragFortress.RING_M, "zs1": float(top.zc) + float(top.sz) - CragFortress.RING_M,
		"front_z": -BASE_HS, "base_e": fr.base_e}
