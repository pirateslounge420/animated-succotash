class_name SoilMarks
## Ground that remembers (design 30 Sept §BQ): black earth, a shell
## midden, a kraal midden: the fertility layer the placer reads (plants
## differ there: the understory grows thicker). A mark is a disc with a
## factor; RuinMarks adds them from the people files' signatures.

static var marks: Array = [] # [[dir, radius_m, factor], ...]


static func add(d: Vector3, radius_m: float, factor: float) -> void:
	for m in marks:
		if (m[0] as Vector3).dot(d) > cos(2.0 / PlanetConst.RADIUS_M):
			return
	marks.append([d, radius_m, factor])


## The fertility factor at `d` (1 where the ground is as it was).
static func fertility_at(d: Vector3) -> float:
	var f := 1.0
	for m in marks:
		var limit := cos(float(m[1]) / PlanetConst.RADIUS_M)
		if (m[0] as Vector3).dot(d) >= limit:
			f = maxf(f, float(m[2]))
	return f
