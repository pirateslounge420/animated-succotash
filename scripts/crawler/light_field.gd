class_name LightField
extends RefCounted
## The light on the tomb's floor (Mike's note of 7 Oct: "creatures that are
## actively chasing will chase near the fire but stay somewhat in the
## darkness if they can"; "the snake and other physical bosses have to move
## thru lit room while doing their best to stay at the edges of the light";
## design §FD, §EY.1 and §FF.2 as that note amends them; crawler.json
## light_field, residents.json rules.chase_light_cap): how much firelight
## falls on each square of the floor grid (TombNav), so what lives in the
## dark can tell where the light ends.
##
## Each permanent fire burning now (the hearth, every relit holder, every
## planted torch; never the torch in your hand, which is the snake's
## torch_delay, nor a fire pot's fire, which burns out) lights the squares
## it has a clear line to, from its light to a body's middle over the
## square (light_field.body_m over the floor), as the renderer lights them:
## its energy times Godot's falloff, (1 - (d / range)^4)^2 / d^attenuation,
## the distance never counted under light_field.min_d_m. A square's light is
## the sum. It is worked out again whenever a fire catches, goes out or is
## planted (refresh(), cheap to call every step); a fire's squares are cast
## once, the first time it burns, and kept.
##
## What reads it (TombNav's two weighted grids):
##   the chase's edge  a creature hunting you may stand only where the light
##                     is at most rules.chase_light_cap (TombNav's capped
##                     grid), so a chase comes as far as the edge of the
##                     light and no further, never close to a fire: by the
##                     hearth or a relit torch you are safe from it, at the
##                     light's dim edge you are not;
##   the dimmest way   a creature that has to cross lit ground (cut off from
##                     the dark, out of a room you relit round it, going
##                     home at the last light, fleeing to its lair) walks
##                     the grid weighted by the light: each square costs 1 +
##                     light_field.dim_weight times its light over the cap
##                     (at most dim_max times), so it keeps to the edges of
##                     the light and the dark corners.

static var LF: Dictionary = Tuning.table("crawler").get("light_field", {})

var nav: TombNav
var fires: CrawlerFires
## Where the casts are made (a node in the tomb's world).
var host: Node3D
var exclude: Array[RID] = []
## Per square of the grid (TombNav's index): the light on it now.
var level := PackedFloat32Array()
## The chase's cap (residents.json rules.chase_light_cap).
var cap := 0.12
## Each fire cast so far: its key -> {"cells": PackedInt32Array, "lv":
## PackedFloat32Array} (the squares it lights and how much).
var _cast := {}
## The fires counted in `level` now: key -> true.
var _on := {}
var _sig := ""
## Tools: fires cast, rays cast, times the light changed.
var casts := 0
var rays := 0
var changes := 0


## The light field on `p_nav`'s grid for the tomb's fires, its rays cast in
## `p_host`'s world past `p_exclude` (you): worked out at once.
static func build(p_nav: TombNav, p_fires: CrawlerFires, p_host: Node3D, p_exclude: Array[RID] = []) -> LightField:
	var lf := LightField.new()
	lf.nav = p_nav
	lf.fires = p_fires
	lf.host = p_host
	lf.exclude = p_exclude
	lf.cap = chase_cap()
	lf.level.resize(p_nav.size.x * p_nav.size.y)
	lf.level.fill(0.0)
	p_nav.attach_light(lf)
	lf.refresh()
	return lf


## The chase's cap (residents.json rules.chase_light_cap): a chasing creature
## stands only where the light is at most this.
static func chase_cap() -> float:
	return float(Tuning.section("residents", "rules").get("chase_light_cap", 0.12))


## light_field's numbers, with their first-guess defaults.
static func num(k: String, dflt: float) -> float:
	return float(LF.get(k, dflt))


## The light on the floor under `p` (0 off the grid).
func at(p: Vector3) -> float:
	var c := nav.cell_of(p)
	if not nav.inside(c):
		return 0.0
	return level[c.y * nav.size.x + c.x]


## May a chasing creature stand at `p` (the light there at most the cap)?
func under_cap(p: Vector3) -> bool:
	return at(p) <= cap


## Is there open floor within `r` m (flat) of `p` where the light is at
## most the cap: somewhere a chasing creature could stand and reach you
## from (a creature's reach)? Only floor joined to yours by open floor
## within that reach counts (never the far side of a wall).
func edge_within(p: Vector3, r: float) -> bool:
	var c := nav.nearest_open(nav.cell_of(p), 2)
	if c.x < 0:
		return false
	var seen := {c: true}
	var todo: Array[Vector2i] = [c]
	var at := Vector2(p.x, p.z)
	while not todo.is_empty():
		var q: Vector2i = todo.pop_back()
		if level[q.y * nav.size.x + q.x] <= cap and absf(nav.floor_y[q.y * nav.size.x + q.x] - p.y) <= 1.2:
			return true
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var nq := q + o
			if seen.has(nq) or not nav.is_open(nq):
				continue
			seen[nq] = true
			var w := nav.point_of(nq)
			if Vector2(w.x, w.z).distance_to(at) <= r:
				todo.append(nq)
	return false


## The light along polyline `pts` (sampled every quarter metre): {"mean",
## "max", "sum" (light times metres), "m" (its length)}.
func along(pts: PackedVector3Array) -> Dictionary:
	var out := {"mean": 0.0, "max": 0.0, "sum": 0.0, "m": 0.0}
	if pts.size() < 2:
		if pts.size() == 1:
			out.max = at(pts[0])
			out.mean = out.max
		return out
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var b := pts[k]
		var seg := a.distance_to(b)
		var n := maxi(int(ceil(seg / 0.25)), 1)
		for i in n:
			var v := at(a.lerp(b, (i + 0.5) / n))
			out.sum = float(out.sum) + v * seg / n
			out.max = maxf(float(out.max), v)
		out.m = float(out.m) + seg
	out.mean = float(out.sum) / maxf(float(out.m), 1e-4)
	return out


# --- The fires ---------------------------------------------------------------

## The permanent fires burning now: [{"key", "pos" (its light), "energy",
## "range", "att"}].
func sources() -> Array:
	var out: Array = []
	if fires == null or not is_instance_valid(fires):
		return out
	var all: Array = [fires.hearth]
	all.append_array(fires.holders)
	for f in all:
		var n := f as Node3D
		if n == null or not is_instance_valid(n) or not n.is_inside_tree() or not FireStore.is_lit(n):
			continue
		out.append(fire_light(n))
	if bool(LF.get("planted", true)):
		for p in PlantedTorch.all:
			if is_instance_valid(p) and p.is_inside_tree() and p.lit():
				out.append(torch_light(p))
	return out


## A fire's light at rest (Campfire.flicker's numbers without the flicker):
## the hearth's, or a holder's (its range_m and energy_k).
static func fire_light(n: Node3D) -> Dictionary:
	var l := n.get_node_or_null("Light") as Node3D
	var pos := l.global_position if l != null else n.global_position + Vector3.UP * 0.3
	var cl: Dictionary = Campfire.L
	var energy := Campfire.LIGHT_ENERGY * lerpf(float(cl.get("day_share", 0.45)), float(cl.get("night_energy_scale", 1.3)), Campfire.night) * float(n.get_meta("energy_k", 1.0))
	var reach := float(n.get_meta("range_m")) if n.has_meta("range_m") else Campfire.RANGE_M * lerpf(1.0, float(cl.get("night_range_scale", 1.6)), Campfire.night)
	return {"key": "f%d" % n.get_instance_id(), "pos": pos, "energy": energy, "range": reach, "att": Campfire.ATTENUATION}


## A planted torch's light (torch.json light: a planted torch keeps range_m
## and energy).
static func torch_light(p: PlantedTorch) -> Dictionary:
	var up := float(Tuning.section("torch", "planted").get("stand_height_m", 0.9))
	var pos := p._light.global_position if p._light != null else p.global_position + p.up * up
	return {"key": "t%d" % p.get_instance_id(), "pos": pos, "energy": float(Torch.L.get("energy", 2.2)), "range": float(Torch.L.get("range_m", 14.0)), "att": float(Torch.L.get("attenuation", 1.6))}


## What fires burn now, cheaply: the holders lit, and the planted torches.
func _quick_sig() -> String:
	var s := str(fires.lit_count()) if fires != null and is_instance_valid(fires) else "-"
	for p in PlantedTorch.all:
		if is_instance_valid(p) and p.is_inside_tree() and p.lit():
			s += ",%d" % p.get_instance_id()
	return s


## Work the light out again if a fire has caught, gone out or been planted
## since: each new fire's squares cast (once), each gone one's taken off,
## and TombNav told which squares changed. True if anything did.
func refresh() -> bool:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var sig := _quick_sig()
	if sig == _sig:
		return false
	_sig = sig
	var want := {}
	for s in sources():
		want[s.key] = s
	var touched := {}
	for key in _on.keys():
		if not want.has(key):
			_apply(_cast[key], -1.0, touched)
			_on.erase(key)
	for key in want:
		if _on.has(key):
			continue
		if not _cast.has(key):
			_cast[key] = _cast_fire(want[key])
			casts += 1
		_apply(_cast[key], 1.0, touched)
		_on[key] = true
	if touched.is_empty():
		return false
	nav.light_changed(touched.keys(), self)
	changes += 1
	return true


func _apply(part: Dictionary, sgn: float, touched: Dictionary) -> void:
	var cells: PackedInt32Array = part.cells
	var lv: PackedFloat32Array = part.lv
	for k in cells.size():
		var i := cells[k]
		level[i] = maxf(level[i] + sgn * lv[k], 0.0)
		touched[i] = true


## The squares fire `s` lights: every floor square within its range with a
## clear line from its light to a body's middle over it.
func _cast_fire(s: Dictionary) -> Dictionary:
	var pos: Vector3 = s.pos
	var reach := float(s.range)
	var e := float(s.energy)
	var att := float(s.att)
	var body := num("body_m", 0.5)
	var dmin := maxf(num("min_d_m", 1.0), 0.05)
	var least := num("least", 0.002)
	var cells := PackedInt32Array()
	var lv := PackedFloat32Array()
	var space := host.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = PropCollision.WORLD_LAYER
	q.exclude = exclude
	q.from = pos
	var c0 := nav.cell_of(pos - Vector3(reach, 0.0, reach))
	var c1 := nav.cell_of(pos + Vector3(reach, 0.0, reach))
	for cy in range(maxi(c0.y, 0), mini(c1.y, nav.size.y - 1) + 1):
		for cx in range(maxi(c0.x, 0), mini(c1.x, nav.size.x - 1) + 1):
			var i := cy * nav.size.x + cx
			var fy := nav.floor_y[i]
			if is_nan(fy):
				continue
			var p := Vector3(nav.origin.x + (cx + 0.5) * TombNav.CELL, fy + body, nav.origin.y + (cy + 0.5) * TombNav.CELL)
			var d := pos.distance_to(p)
			if d >= reach:
				continue
			var k := 1.0 - pow(d / reach, 4.0)
			var v := e * k * k / pow(maxf(d, dmin), att)
			if v < least:
				continue
			q.to = p
			rays += 1
			if not space.intersect_ray(q).is_empty():
				continue
			cells.append(i)
			lv.append(v)
	return {"cells": cells, "lv": lv}
