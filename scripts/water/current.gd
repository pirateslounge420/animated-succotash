class_name Current
## Water has weight (design 30 Sept §BE, data/water/current.json): every
## river segment (RiverNetwork, from the hydrology pass) carries a flow
## downstream, its speed from the segment's slope and its volume (width),
## a rapid where the white water is, a churn below a fall, next to
## nothing in a pool, none in a lake or the sea. flow_at() gives the flow
## where you are: the direction along the surface, the speed, the kind.
## PlanetPlayer drifts with it, cannot swim up a fast reach, is dragged
## wading; WaterSounds puts the running water's sound at it.

static var D := Tuning.table("current")
static var F: Dictionary = D.get("flow", {})


static func _band(kind: String) -> Vector2:
	var v = (F.get("speed_mps", {}) as Dictionary).get(kind, [0.0, 0.0])
	if v is Array and (v as Array).size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2(float(v), float(v)) if v is float or v is int else Vector2.ZERO


## The flow at surface direction `d`: {"dir": Vector3 (unit, along the
## surface), "speed": m/s, "kind": stream/river/rapid/pool/none,
## "dist_m": to the river's centre line, "seg": the segment, "width"}.
static func flow_at(rivers: RiverNetwork, map: PlanetData, d: Vector3) -> Dictionary:
	var none := {"dir": Vector3.ZERO, "speed": 0.0, "kind": "none", "dist_m": INF, "seg": -1, "width": 0.0, "t": 0.0}
	if rivers == null or map == null:
		return none
	var cell := map.cell_at(d)
	var best := -1
	var best_dt := Vector2(INF, 0.0)
	for s in rivers.segments_near(map, cell):
		var dt := rivers.closest_dt(s, d)
		if dt.x < best_dt.x:
			best_dt = dt
			best = s
	if best < 0:
		return none
	var w := rivers.width[best]
	if best_dt.x > w * 0.5 + 3.0:
		return none
	var pa := rivers.a[best]
	var pb := rivers.b[best]
	var along := (pb - pa)
	along = (along - d * along.dot(d)).normalized()
	var len_m := CubeSphere.surface_distance_m(pa, pb)
	var drop := rivers.level_a[best] - rivers.level_b[best]
	var slope := clampf(drop / maxf(len_m, 1.0) * float(F.get("slope_gain", 2.0)), 0.0, 1.0)
	var volume := clampf(w / RiverNetwork.MAX_WIDTH_M * float(F.get("volume_gain", 0.3)), 0.0, 1.0)
	var kind := "stream" if w < 12.0 else "river"
	var white := rivers.rapids(best)
	var wi := clampi(int(best_dt.y * (white.size() - 1)), 0, maxi(white.size() - 1, 0))
	var churn := 0.0
	if white.size() > 0 and white[wi] > 0.5:
		kind = "rapid"
	# Just below a fall: the plunge pool churns.
	for f in rivers.falls(best):
		var ft := float(f[0])
		if best_dt.y > ft and (best_dt.y - ft) * len_m < 12.0:
			churn = float(F.get("speed_mps", {}).get("fall_pool_churn", 1.5))
	var band := _band(kind)
	var speed := lerpf(band.x, band.y, clampf(slope + volume, 0.0, 1.0))
	speed = maxf(speed, churn)
	# The flow fades at the banks.
	var edge := 1.0 - smoothstep(w * 0.5, w * 0.5 + 3.0, best_dt.x)
	return {"dir": along, "speed": speed * edge, "kind": kind, "dist_m": best_dt.x, "seg": best, "width": w, "t": best_dt.y}
