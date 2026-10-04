class_name HewnTemple
## The hewn temple's halls as its delve (design 3 Oct §DZ, ruins.json
## styles.hewn_temple, Monuments._hewn_temple): three halls cut into the
## pit's back wall (+z), side by side and a level apart, the stairs
## between them climbing through the rock; the deepest (the top one, the
## longest, its apse holding a seated figure) the heart; from its far end a
## stair up to the hilltop, the way out. The pit itself is a hole in the
## ground (its rectangle is the layout's first hole: TerrainChunk leaves
## its quads out); RuinBuilder._hewn_temple builds its floor, its walls,
## the temple standing free in it and these halls.
## Every y here is from the frame's base_e (Delves.frame).

## The halls: x of their middles, how far each is up from the floor, how
## long each runs into the rock, their half width and height.
const HALL_X := [-14.0, 0.0, 14.0]
const HALL_RISE := 5.0
const HALL_LEN := [14.0, 13.4, 17.0]
const HALL_HALF := 3.0
const HALL_H := 4.0
const HEART_H := 4.5
## The porch through the wall into the first hall: its half width.
const PORCH_HALF := 2.4
## The way out leaves the heart's end this far right of its middle (the
## seated figure sits in the middle of the apse).
const EXIT_X := 2.0
## The stairs between the halls run across, this far into the rock.
const STAIR_Z := 9.0
## The top hall's roof over the floor (Monuments keeps the hill over it).
const TOP_ROOF := 2.0 * HALL_RISE + HEART_H + Delves.SLAB
## The stair cut down the court's front wall: its grade.
const COURT_STAIR := 0.8


static func layout(map: PlanetData, site: Dictionary) -> Dictionary:
	var fr := Delves.frame(map, site)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site.seed, "hewn_delve"])
	var w := float(site.pit_w)
	var l := float(site.pit_l)
	var yf := float(site.floor_y)
	var zf := l * 0.5
	var pieces: Array = []
	# 0: the porch through the wall into the first hall.
	pieces.append(Delves.piece("passage", Vector2(HALL_X[0], zf - 0.3), Vector2(0.0, 1.0), 3.3, PORCH_HALF, yf, yf, HALL_H))
	for i in 3:
		var y := yf + i * HALL_RISE
		var z0 := zf + 3.0 if i == 0 else zf + 0.6
		var ln := float(HALL_LEN[i]) - (3.0 if i == 0 else 0.6)
		pieces.append(Delves.piece("heart" if i == 2 else "room", Vector2(HALL_X[i], z0), Vector2(0.0, 1.0), ln, HALL_HALF, y, y, HEART_H if i == 2 else HALL_H))
		if i < 2:
			var run := HALL_RISE / Delves.SLOPE
			pieces.append(Delves.piece("stair", Vector2(float(HALL_X[i]) + HALL_HALF, zf + STAIR_Z), Vector2(1.0, 0.0), run, 0.85, y, y + HALL_RISE, Delves.H_STAIR))
	var heart: Dictionary = pieces[5]
	var yh := float(heart.y0)
	# The way out: from the heart's far end up to the hilltop.
	var start := (heart.c as Vector2) + (heart.dir as Vector2) * float(heart.len) + Vector2(EXIT_X, 0.0)
	var run := 10.0
	var top := yh
	for it in 4:
		top = Delves._g0(map, fr, start.x, start.y + run) + 0.05
		run = maxf((top - yh) / Delves.SLOPE, 2.0)
	var exit := Delves.piece("exit", start, Vector2(0.0, 1.0), run, 0.9, yh, top, Delves.H_STAIR)
	pieces.append(exit)
	# Its ceiling breaks the ground from here on: open to the sky.
	var open_from := run
	var t := 0.0
	while t < run:
		if Delves.floor_of(exit, t) + Delves.H_STAIR + Delves.SLAB + 0.4 > Delves._g0(map, fr, start.x, start.y + t):
			open_from = t
			break
		t += 0.5
	var holes: Array = [Rect2(-w * 0.5, -l * 0.5, w, l), Delves.rect_of(exit, 0.0, open_from - 0.3, run + 0.5)]
	var lay := {"ok": true, "climbs": true, "base_e": fr.base_e, "pieces": pieces, "holes": holes, "exit": exit, "cairn": {},
		"room_i": 1, "heart_i": 5, "exit_open": open_from,
		# Where the way in starts: the top of the stair down the court's
		# front wall, on the rim.
		"door_out": Vector3(float(site.get("stair_sx", -1.0)) * (w * 0.5 - 3.0), float(site.rim_y), -l * 0.5 - 1.0)}
	# The first hall's old hearth (its one safe room, §CJ) and the heart's
	# hearth ring, down their middles; the find by the figure.
	var h1: Dictionary = pieces[1]
	lay.hearth = Vector3(float(HALL_X[0]), yf, float((h1.c as Vector2).y) + 3.5)
	lay.heart_hearth = Vector3(float(HALL_X[2]), yh, float((heart.c as Vector2).y) + 5.5)
	lay.find_kind = "spear" if rng.randf() < 0.5 else "bow"
	lay.find = Vector3(float(HALL_X[2]) + 1.6, yh, float((heart.c as Vector2).y) + float(heart.len) - 4.5)
	lay.feature = "halls"
	return lay
