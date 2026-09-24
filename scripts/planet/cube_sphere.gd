class_name CubeSphere
## Cube-sphere addressing for the planet (DESIGN.md "Overview").
##
## The sphere is split into 6 cube faces. A point on a face is (face, u, v)
## with u, v in [-1, 1]. Face coordinates go through a tangent warp
## (tan(u * PI/4)) before projection, which keeps cells far more equal in
## area than a plain cube projection and still has an exact inverse.
##
## Y is the planet's spin axis: latitude = asin(dir.y).

const FACE_COUNT := 6

## Per-face outward normal N and in-plane axes U, V, with U x V = N.
const FACE_N: Array[Vector3] = [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
	Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
]
const FACE_U: Array[Vector3] = [
	Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0),
	Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0),
]
const FACE_V: Array[Vector3] = [
	Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1),
	Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0),
]


## Unit direction for face coordinates. u/v slightly outside [-1, 1] are
## valid and land on the neighboring face, which is how cross-face
## neighbors are found.
static func to_dir(face: int, u: float, v: float) -> Vector3:
	var a := tan(u * PI * 0.25)
	var b := tan(v * PI * 0.25)
	return (FACE_N[face] + FACE_U[face] * a + FACE_V[face] * b).normalized()


static func face_of(dir: Vector3) -> int:
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	var az := absf(dir.z)
	if ax >= ay and ax >= az:
		return 0 if dir.x > 0.0 else 1
	if ay >= az:
		return 2 if dir.y > 0.0 else 3
	return 4 if dir.z > 0.0 else 5


## Face coordinates (u, v) of a direction on a given face.
static func face_uv(face: int, dir: Vector3) -> Vector2:
	var p := dir / dir.dot(FACE_N[face])
	var a := p.dot(FACE_U[face])
	var b := p.dot(FACE_V[face])
	return Vector2(atan(a) * 4.0 / PI, atan(b) * 4.0 / PI)


static func latitude(dir: Vector3) -> float:
	return asin(clampf(dir.y, -1.0, 1.0))


static func longitude(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


## Great-circle distance in meters between two unit directions.
static func surface_distance_m(a: Vector3, b: Vector3) -> float:
	return acos(clampf(a.dot(b), -1.0, 1.0)) * PlanetConst.RADIUS_M


## Local east/north tangent frame at a direction (used for aspect, wind
## vectors, and orienting things on the surface).
static func east(dir: Vector3) -> Vector3:
	var e := Vector3.UP.cross(dir)
	if e.length_squared() < 1e-10:
		return Vector3.RIGHT
	return e.normalized()


static func north(dir: Vector3) -> Vector3:
	return dir.cross(east(dir)).normalized()
