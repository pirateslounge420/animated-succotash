class_name CanopyDapple
## Dappled canopy shade (design §AJ 3): the ground darkening under trees is
## a top-down render of their leaf clusters, not a disc. A chunk's trees
## that grow from their architecture (TreeArch) are stamped into one shade
## map across the chunk (DAPPLE_PX square, about half a meter a texel):
## each cluster a disc of shade, the gaps between them sun, so the shade
## under an oak is a patchwork and under a palm it is stripes. Trees
## without a skeleton keep the baked disc (TerrainChunk.bake_canopy_shade).
##
## A stamp is made once per (species, layout, mirror) at STAMP_PX from the
## skeleton's anchors seen from above, then turned in quarter turns
## (Image.rotate_90) to the tree's yaw, scaled to its height and blended
## in by how much leaf it carries (bare trees cast nearly none). The map's
## texels hold 1 - shade (white is open sky); the terrain shader samples it
## by the ground's UV (meters on the chunk's tangent plane).
##
## Built on the chunk worker after the trees are placed.

const DAPPLE_PX := 512
## data/look.json dapple.mode: "stamped" (this map) or "disc" (no map;
## every tree casts the baked crown disc with the shader's sun flecks —
## cheaper, and the shade needn't match the crown exactly).
static func stamped() -> bool:
	return str(Tuning.section("look", "dapple").get("mode", "stamped")) == "stamped"

const STAMP_PX := 32
## Shade under one cluster (its cards leave a little light through).
const CLUSTER_SHADE := 0.8

static var _stamps := {}
static var _lock := Mutex.new()


## The chunk's shade map span in meters (a little more than the chunk, so
## its edge texels aren't clipped).
static func span_m() -> float:
	return PlanetConst.CIRCUMFERENCE_M / 4.0 / TerrainChunk.CHUNKS_PER_FACE * 1.04


## The shade map for a chunk's placed trees (VegetationPlacer.prepare()'s
## output), or null when none of them grows from its architecture.
static func bake(center: Vector3, plants: Dictionary) -> Image:
	if not stamped():
		return null
	var all := SpeciesDB.all()
	var east := CubeSphere.east(center)
	var north := CubeSphere.north(center)
	var span := span_m()
	var px_m := span / DAPPLE_PX
	var img: Image = null
	for sp_idx in plants:
		var sp: PlantSpecies = all[sp_idx]
		if not TreeArch.grows(sp):
			continue
		var rec: Array = plants[sp_idx]
		var buf: PackedFloat32Array = rec[0]
		for t in rec[2]:
			var pick: int = t[3]
			if pick < 0:
				continue
			# How much leaf it carries (the custom data's bare, alpha).
			var leaf := 1.0 - buf[int(t[2]) * VegetationPlacer.MM_STRIDE + 19]
			if leaf < 0.05:
				continue
			var h: float = t[1]
			var rot: Basis = t[5]
			var yaw := atan2(rot.x.dot(north), rot.x.dot(east))
			var turns := posmod(roundi(yaw / (PI * 0.5)), 4)
			var st: Array = _stamp(int(sp_idx), pick, turns)
			if st.is_empty():
				continue
			var half_m: float = float(st[1]) * h
			var px := int(ceil(half_m * 2.0 / px_m))
			if px < 2:
				continue
			var stamp: Image = (st[0] as Image).duplicate()
			stamp.resize(px, px, Image.INTERPOLATE_NEAREST)
			if leaf < 0.999:
				_fade(stamp, leaf)
			# Where the crown is: the trunk's foot, moved by the lean.
			var top := rot * Vector3(0.0, h * 0.7, 0.0)
			var pos: Vector3 = t[0]
			var c := Vector2(pos.dot(east) + top.dot(east), pos.dot(north) + top.dot(north))
			var dst := Vector2i(int((c.x + span * 0.5) / px_m) - px / 2, int((c.y + span * 0.5) / px_m) - px / 2)
			if img == null:
				img = Image.create(DAPPLE_PX, DAPPLE_PX, false, Image.FORMAT_RGBA8)
				img.fill(Color.WHITE)
			img.blend_rect(stamp, Rect2i(0, 0, px, px), dst)
	if img != null:
		img.convert(Image.FORMAT_R8)
	return img


## Scale a stamp's shade by `k` (a thinly leaved tree).
static func _fade(stamp: Image, k: float) -> void:
	var data := stamp.get_data()
	for i in range(3, data.size(), 4):
		data[i] = int(data[i] * k)
	stamp.set_data(stamp.get_width(), stamp.get_height(), false, Image.FORMAT_RGBA8, data)


## [image, half-width in tree heights] for a species' layout seen from
## above, turned `turns` quarter turns; [] if it has no clusters.
static func _stamp(sp_idx: int, pick: int, turns: int) -> Array:
	var key := Vector3i(sp_idx, pick, turns)
	_lock.lock()
	var got = _stamps.get(key)
	_lock.unlock()
	if got != null:
		return got
	var out: Array = []
	if turns > 0:
		var base := _stamp(sp_idx, pick, 0)
		if not base.is_empty():
			var img: Image = (base[0] as Image).duplicate()
			for k in turns:
				img.rotate_90(CLOCKWISE)
			out = [img, base[1]]
	else:
		out = _draw(TreeLayouts.skeleton(sp_idx, TreeLayouts.layout_of(pick)), TreeLayouts.is_mirrored(pick))
	_lock.lock()
	if not _stamps.has(key):
		_stamps[key] = out
	out = _stamps[key]
	_lock.unlock()
	return out


## The clusters seen from above: a disc of shade per anchor (its cluster's
## spread), in the tree's own frame (x east, z south of it at yaw 0), with
## the image's rows running north.
static func _draw(sk: TreeLayouts.Skeleton, mirrored: bool) -> Array:
	if sk.anchors.is_empty():
		return []
	var mx := -1.0 if mirrored else 1.0
	var half := 0.0
	for an in sk.anchors:
		var p: Vector3 = an[0]
		half = maxf(half, maxf(absf(p.x), absf(p.z)) + float(an[5]))
	half = maxf(half, 0.02)
	var n := STAMP_PX
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var to_px := n / (half * 2.0)
	for an in sk.anchors:
		var p: Vector3 = an[0]
		var hang: Vector3 = an[2]
		var r: float = an[5]
		# The cluster sits a little out along its hang from the twig.
		var q := p + hang * r * 0.45
		var cx := (q.x * mx + half) * to_px
		var cy := (half - q.z) * to_px
		var rp := maxf(r * 0.95 * to_px, 0.6)
		for y in range(maxi(0, int(cy - rp)), mini(n, int(cy + rp) + 1)):
			for x in range(maxi(0, int(cx - rp)), mini(n, int(cx + rp) + 1)):
				var dx := x + 0.5 - cx
				var dy := y + 0.5 - cy
				if dx * dx + dy * dy <= rp * rp:
					var i := (y * n + x) * 4 + 3
					data[i] = maxi(data[i], int(CLUSTER_SHADE * 255.0))
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	return [img, half]
