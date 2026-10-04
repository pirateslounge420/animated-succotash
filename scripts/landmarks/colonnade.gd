class_name Colonnade
## The colonnade's cellar and cistern (design 3 Oct §DV, ruins.json
## styles.colonnade, Monuments._colonnade): in the middle of the house's
## footprint the brick cellar, open to the sky (a hole in the ground), its
## floor under a hand of still water (§BE: wade); from it a low door and a
## few steps down to the cistern under the footprint (the heart, flooded to
## the knee), and from the cistern's far end the old stair up and out past
## the footprint (the way out). Every y from the frame's base_e.

const CELLAR_D := 3.2
const CELLAR_WATER := 0.4
const CISTERN_DROP := 2.2
const CISTERN_LEN := 8.0
const CISTERN_WATER := 0.6
## The dry brick ledges along the cellar's and the cistern's walls.
const LEDGE_H := 0.8


## The cellar's rectangle (local x/z) and its floor.
static func cellar(site: Dictionary) -> Rect2:
	var cw := float(site.house_w) * 0.45
	var cl := float(site.house_l) * 0.42
	return Rect2(-cw * 0.5, -cl * 0.5, cw, cl)


static func layout(map: PlanetData, site: Dictionary) -> Dictionary:
	var fr := Delves.frame(map, site)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "colonnade_delve"])
	var r := cellar(site)
	var g := INF
	for k in 9:
		g = minf(g, Delves._g0(map, fr, lerpf(r.position.x, r.end.x, (k % 3) / 2.0), lerpf(r.position.y, r.end.y, (k / 3) / 2.0)))
	var yc := g - CELLAR_D
	var ze := r.end.y
	var pieces: Array = []
	# The low door out of the cellar's far wall and the steps down, as deep
	# as the ground over the cistern needs.
	var drop := CISTERN_DROP
	var run := 0.0
	var yh := 0.0
	var hz := 0.0
	var heart := {}
	var steps := {}
	for it in 4:
		run = drop / Delves.SLOPE + 0.4
		steps = Delves.piece("passage", Vector2(0.0, ze - 0.2), Vector2(0.0, 1.0), run, 0.9, yc, yc - drop, Delves.H_STAIR)
		yh = yc - drop
		hz = ze - 0.2 + run
		heart = Delves.piece("heart", Vector2(0.0, hz), Vector2(0.0, 1.0), CISTERN_LEN, 2.4, yh, yh, Delves.H_ROOM)
		var short := maxf(Delves._short_of_cover(map, fr, heart, 0.0, CISTERN_LEN), Delves._short_of_cover(map, fr, steps, 1.5, run))
		if short <= 0.0:
			break
		drop += short + 0.3
	pieces.append(steps)
	pieces.append(heart)
	# The old stair up and out past the footprint.
	var start := Vector2(0.0, hz + CISTERN_LEN)
	var top := yh
	var orun := 6.0
	for it in 4:
		top = Delves._g0(map, fr, start.x, start.y + orun) + 0.05
		orun = maxf((top - yh) / Delves.SLOPE, 2.0)
	var exit := Delves.piece("exit", start, Vector2(0.0, 1.0), orun, 0.9, yh, top, Delves.H_STAIR)
	pieces.append(exit)
	var open_from := orun
	var t := 0.0
	while t < orun:
		if Delves.floor_of(exit, t) + Delves.H_STAIR + Delves.SLAB + 0.4 > Delves._g0(map, fr, start.x, start.y + t):
			open_from = t
			break
		t += 0.5
	var lay := {"ok": true, "climbs": true, "base_e": fr.base_e, "pieces": pieces,
		"holes": [r, Delves.rect_of(exit, 0.0, open_from - 0.3, orun + 0.5)], "exit": exit, "cairn": {},
		"room_i": 1, "heart_i": 1, "exit_open": open_from, "cellar_y": yc,
		"door_out": Vector3(r.position.x + 1.0, g, r.position.y - 0.5)}
	# The fires and the find on the dry brick ledges above the water.
	lay.hearth = Vector3(r.position.x + 0.85, yc + LEDGE_H, r.get_center().y + 2.0)
	lay.heart_hearth = Vector3(-1.8, yh + LEDGE_H, hz + 2.0)
	lay.find_kind = "spear" if rng.randf() < 0.5 else "bow"
	lay.find = Vector3(-1.8, yh + LEDGE_H, hz + CISTERN_LEN - 1.6)
	lay.feature = "cistern"
	# Overrun's rooms: the cistern for both.
	return lay
