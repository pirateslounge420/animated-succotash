class_name CreatureHitboxes
## Hitboxes (spec D5: "everything has a proper hitbox ... no
## ghost-through") for the ordinary creatures and the camp folk: the
## bodies CreatureBodies and SculptedBodies build, fitted with the shared
## Hitboxes parts (layer 3, what arrows and the bow's aim ray meet) and,
## for anything the player shouldn't walk through, one blocker (layer 1).
## The Night Rider and the Pond Crawler fit their own.
##
## Each part rides the node that moves that piece of the body (a leg's,
## arm's or tail's pivot, the head, else the body's root), so it follows
## the gait, a seated pose, a turned head, the body's size and fade.
##
##   sculpted bodies  (wolf, deer, goblin, tribal and elder people): a
##                    capsule or sphere per bone, written out below from
##                    SculptedBodies' shapes (torso, neck and head, each
##                    leg, arms, tail, the goblin's ears), plus the
##                    biggest of the small separate parts on them
##                    (antlers, a lantern, a quiver or bow; _extras()).
##   primitive bodies (everything CreatureBodies assembles from spheres,
##                    capsules and cones): each visible piece fitted with
##                    a capsule, sphere or box from its own mesh bounds
##                    (_fit()), the biggest few, so the shapes match what
##                    is drawn without a table per body.
##   tiny ones        at least the biggest piece, however small (a
##                    beetle, a tree frog); fireflies a sphere in the
##                    heart of their cloud.
##   imported models  one shape over the whole model.
## Blockers (blocks()): every mythical, and anything 0.6 m or bigger; a
## capsule tucked inside the torso part.
##
## Off, every body is built without them (for measuring their cost).
static var enabled := true

## Most parts a primitive body gets, by kind of creature.
const MAX_SMALL := 3
const MAX_BIG := 10
const MAX_TALL := 12
## Pieces smaller than this (m) are left out: eyes, noses, claws.
const MIN_LONG_M := 0.06
const MIN_THICK_M := 0.02
## And pieces under this fraction of the body's size (its length, or its
## height for the tall ones).
const MIN_REL := 0.06
## Small separate parts kept on a sculpted body (antlers, gear).
const MAX_EXTRAS := 2

## The sculpted bodies' parts, in SculptedBodies' own coordinates (body
## units, feet at y 0, facing -Z): [name, bone, a, b, radius]; a == b is
## a sphere. Each is attached to its bone's pivot.
const SCULPTED := {
	"deer": [
		["Torso", "Root", Vector3(0, 0.73, -0.2), Vector3(0, 0.74, 0.24), 0.135],
		["Neck", "Head", Vector3(0, 0.78, -0.24), Vector3(0, 0.95, -0.38), 0.065],
		["Head", "Head", Vector3(0, 0.985, -0.41), Vector3(0, 0.94, -0.55), 0.06],
		["Leg", "FrontL", Vector3(-0.07, 0.68, -0.19), Vector3(-0.07, 0.03, -0.2), 0.04],
		["Thigh", "HindL", Vector3(-0.06, 0.66, 0.23), Vector3(-0.07, 0.33, 0.3), 0.06],
		["Shin", "HindL", Vector3(-0.07, 0.33, 0.3), Vector3(-0.07, 0.03, 0.25), 0.032],
		["Leg", "FrontR", Vector3(0.07, 0.68, -0.19), Vector3(0.07, 0.03, -0.2), 0.04],
		["Thigh", "HindR", Vector3(0.06, 0.66, 0.23), Vector3(0.07, 0.33, 0.3), 0.06],
		["Shin", "HindR", Vector3(0.07, 0.33, 0.3), Vector3(0.07, 0.03, 0.25), 0.032],
		["Tail", "Tail", Vector3(0, 0.8, 0.32), Vector3(0, 0.72, 0.39), 0.035],
	],
	"wolf": [
		["Torso", "Root", Vector3(0, 0.5, -0.19), Vector3(0, 0.5, 0.2), 0.14],
		["Neck", "Head", Vector3(0, 0.55, -0.24), Vector3(0, 0.65, -0.37), 0.08],
		["Head", "Head", Vector3(0, 0.69, -0.41), Vector3(0, 0.655, -0.575), 0.07],
		["Leg", "FrontL", Vector3(-0.075, 0.48, -0.2), Vector3(-0.075, 0.035, -0.215), 0.042],
		["Thigh", "HindL", Vector3(-0.07, 0.46, 0.2), Vector3(-0.075, 0.2, 0.27), 0.06],
		["Shin", "HindL", Vector3(-0.075, 0.2, 0.27), Vector3(-0.075, 0.03, 0.225), 0.032],
		["Leg", "FrontR", Vector3(0.075, 0.48, -0.2), Vector3(0.075, 0.035, -0.215), 0.042],
		["Thigh", "HindR", Vector3(0.07, 0.46, 0.2), Vector3(0.075, 0.2, 0.27), 0.06],
		["Shin", "HindR", Vector3(0.075, 0.2, 0.27), Vector3(0.075, 0.03, 0.225), 0.032],
		["Tail", "Tail", Vector3(0, 0.53, 0.29), Vector3(0, 0.4, 0.52), 0.045],
	],
	"goblin": [
		["Torso", "Root", Vector3(0, 0.38, -0.01), Vector3(0, 0.52, 0.0), 0.115],
		["Head", "Head", Vector3(0, 0.76, -0.03), Vector3(0, 0.76, -0.03), 0.125],
		["Nose", "Head", Vector3(0, 0.77, -0.12), Vector3(0, 0.71, -0.2), 0.025],
		["Leg", "LegL", Vector3(-0.06, 0.3, 0.0), Vector3(-0.072, 0.03, -0.02), 0.04],
		["Leg", "LegR", Vector3(0.06, 0.3, 0.0), Vector3(0.072, 0.03, -0.02), 0.04],
		["Arm", "ArmL", Vector3(-0.13, 0.53, 0.0), Vector3(-0.182, 0.22, -0.05), 0.036],
		["Arm", "ArmR", Vector3(0.13, 0.53, 0.0), Vector3(0.182, 0.22, -0.05), 0.036],
	],
	"tribal": [
		["Torso", "Root", Vector3(0, 0.49, 0.0), Vector3(0, 0.72, -0.005), 0.105],
		["Head", "Head", Vector3(0, 0.87, -0.005), Vector3(0, 0.935, 0.01), 0.064],
		["Leg", "LegL", Vector3(-0.064, 0.48, 0.0), Vector3(-0.065, 0.03, -0.01), 0.045],
		["Leg", "LegR", Vector3(0.064, 0.48, 0.0), Vector3(0.065, 0.03, -0.01), 0.045],
		["Arm", "ArmL", Vector3(-0.145, 0.76, 0.0), Vector3(-0.171, 0.4, -0.005), 0.036],
		["Arm", "ArmR", Vector3(0.145, 0.76, 0.0), Vector3(0.171, 0.4, -0.005), 0.036],
	],
}

## The blocker inside each sculpted torso: [a, b, radius], root space.
const SCULPTED_BLOCKER := {
	"deer": [Vector3(0, 0.73, -0.15), Vector3(0, 0.74, 0.19), 0.1],
	"wolf": [Vector3(0, 0.5, -0.15), Vector3(0, 0.5, 0.16), 0.1],
	"goblin": [Vector3(0, 0.38, -0.01), Vector3(0, 0.5, 0.0), 0.085],
	"tribal": [Vector3(0, 0.5, 0.0), Vector3(0, 0.72, -0.005), 0.08],
}


## Does this species get a blocker (the player can't walk through it)?
static func blocks(sp: CreatureSpecies) -> bool:
	return sp.role == "mythical" or (sp.size_m >= 0.6 and sp.role != "swarm")


## Parts (and a blocker if `block`) for a body `b` (CreatureBodies.build()'s
## dictionary) belonging to `owner` (a Creature, or a camp person's
## holder): what an arrow hitting them names (Hitboxes.creature_of()).
## Returns every body made, the parts first.
static func build(owner: Node, b: Dictionary, sp: CreatureSpecies, block: bool) -> Array:
	if not enabled:
		return []
	var root: Node3D = b.root
	var out: Array = []
	if b.get("sculpted", "") != "":
		_sculpted(owner, b, str(b.sculpted), block, out)
	elif b.get("animator") != null:
		_model(owner, root, block, out)
	elif sp.body == "swarm" and sp.role == "swarm":
		# Fireflies: the heart of the cloud (CreatureBodies._swarm()).
		var s := Hitboxes.sphere(owner, root, Vector3(0, 1.0, 0), 0.35)
		s.name = "Swarm"
		out.append(s)
	else:
		_primitive(owner, b, sp, block, out)
	return out


# --- Sculpted bodies -----------------------------------------------------------

static func _sculpted(owner: Node, b: Dictionary, kind: String, block: bool, out: Array) -> void:
	var root: Node3D = b.root
	var table: String = "tribal" if kind == "elder" else kind
	for p: Array in SCULPTED[table]:
		var at := _bone(root, p[1])
		var off := at.position if at != root else Vector3.ZERO
		var r: float = p[4]
		if kind == "elder" and p[0] == "Torso":
			r += 0.012 # the fur mantle
		var a: Vector3 = p[2] - off
		var c: Vector3 = p[3] - off
		var part := Hitboxes.sphere(owner, at, a, r) if a == c else Hitboxes.capsule(owner, at, a, c, r)
		# "Torso", "Head", "LegFrontL", "ThighHindR", "ArmL" ...
		part.name = str(p[0]) + ("" if p[1] in ["Root", "Head", "Tail"] else str(p[1]).trim_prefix(str(p[0])))
		out.append(part)
	if kind == "goblin":
		# The big ears, along their long axis (SculptedBodies._goblin()).
		var head := _bone(root, "Head")
		for sd: float in [-1.0, 1.0]:
			var ear_b := Basis(Vector3.BACK, 0.25 * sd) * Basis(Vector3.UP, -0.25 * sd)
			var c := Vector3(0.18 * sd, 0.8, 0.0) - head.position
			var u := ear_b * Vector3.RIGHT
			var ear := Hitboxes.capsule(owner, head, c - u * 0.07, c + u * 0.07, 0.035)
			ear.name = "Ear" + ("L" if sd < 0.0 else "R")
			out.append(ear)
	_extras(owner, b, {"deer": "Antler", "goblin": "Lantern"}.get(kind, "Gear"), out)
	if block:
		var k: Array = SCULPTED_BLOCKER[table]
		out.append(Hitboxes.blocker(owner, root, k[0], k[1], k[2]))


## A bone's pivot on a sculpted body (the root for the root bone).
static func _bone(root: Node3D, bone: String) -> Node3D:
	if bone == "Root":
		return root
	var n := root.get_node_or_null(bone) as Node3D
	return n if n else root


## The biggest few small parts a sculpted body carries (antlers, a
## lantern, gear), fitted like a primitive body's pieces and named
## `what` (numbered).
static func _extras(owner: Node, b: Dictionary, what: String, out: Array) -> void:
	var root: Node3D = b.root
	var pieces := _pieces(root, _anchors(b), root.scale.x)
	for i in mini(pieces.size(), MAX_EXTRAS):
		var part := _fit(owner, pieces[i])
		part.name = what + str(i + 1)
		out.append(part)


# --- Primitive bodies ----------------------------------------------------------

static func _primitive(owner: Node, b: Dictionary, sp: CreatureSpecies, block: bool, out: Array) -> void:
	var root: Node3D = b.root
	var anchors := _anchors(b, "Wing" if sp.body in ["bird", "wader", "duck"] else "Arm")
	var pieces := _pieces(root, anchors, root.scale.x)
	if pieces.is_empty():
		# Tiny (a beetle): its biggest piece, however small.
		pieces = _pieces(root, anchors, root.scale.x, true)
		pieces.resize(mini(pieces.size(), 1))
	var most := MAX_BIG
	if sp.size_m < 0.6 and sp.role != "mythical":
		most = MAX_SMALL
	elif sp.role == "mythical" or sp.body in ["tribal", "robed", "skeleton"]:
		most = MAX_TALL
	var torso: Dictionary = {}
	var used := {}
	for i in mini(pieces.size(), most):
		var pc: Dictionary = pieces[i]
		var part := _fit(owner, pc)
		# "Body", "Head", "Leg2", "ArmL", "Tail" (numbered on repeats).
		var label: String = anchors[pc.anchor]
		used[label] = int(used.get(label, 0)) + 1
		part.name = label + (str(used[label]) if used[label] > 1 else "")
		out.append(part)
		if torso.is_empty() and pc.anchor == root:
			torso = pc
	if block and not torso.is_empty():
		out.append(_blocker_in(owner, torso))


## Nodes the body's pieces ride, each with a name for its parts: its root
## ("Body"), the leg, arm (or wing) and tail pivots, the head.
static func _anchors(b: Dictionary, arm := "Arm") -> Dictionary:
	var root: Node3D = b.root
	var out := {root: "Body"}
	for i in b.legs.size():
		out[b.legs[i]] = "Leg" + str(i + 1)
	for i in b.wings.size():
		out[b.wings[i]] = arm + ("L" if i % 2 == 0 else "R")
	if b.tail:
		out[b.tail] = "Tail"
	var head := root.get_node_or_null("Head")
	if head:
		out[head] = "Head"
	return out


## Each mesh under `root` as an oriented box on the node it rides:
## {"anchor", "center", "axes" (three half-extent vectors), "vol",
## "inner" (the half-thickness a blocker may fill), "hull" (points round
## a tapering cone, else empty)}, the biggest first. Skips meshes under a
## skeleton (a sculpted body's skin), see-through ones (a wisp's halo)
## and, unless `all`, pieces smaller than MIN_LONG_M / MIN_THICK_M at the
## body's `scale_m` or than MIN_REL of the body (eyes, noses, claws).
static func _pieces(root: Node3D, anchors: Dictionary, scale_m: float, all := false) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Skeleton3D:
			continue
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or mi.transparency > 0.0:
			continue
		# The mesh's frame on its anchor: the fixed nodes between folded in.
		var xf := mi.transform
		var p := mi.get_parent() as Node3D
		while p != null and not anchors.has(p):
			xf = p.transform * xf
			p = p.get_parent() as Node3D
		if p == null:
			continue
		var box := mi.mesh.get_aabb()
		var axes: Array = [xf.basis.x * box.size.x * 0.5, xf.basis.y * box.size.y * 0.5, xf.basis.z * box.size.z * 0.5]
		var ext: Array = [(axes[0] as Vector3).length(), (axes[1] as Vector3).length(), (axes[2] as Vector3).length()]
		ext.sort()
		if not all and (ext[2] * 2.0 < MIN_REL or ext[2] * 2.0 * scale_m < MIN_LONG_M or ext[1] * 2.0 * scale_m < MIN_THICK_M):
			continue
		var pc := {"anchor": p, "center": xf * box.get_center(), "axes": axes, "vol": ext[0] * ext[1] * ext[2],
			"inner": ext[0], "hull": PackedVector3Array()}
		var cyl := mi.mesh as CylinderMesh
		if cyl and minf(cyl.top_radius, cyl.bottom_radius) < 0.7 * maxf(cyl.top_radius, cyl.bottom_radius):
			# A tapering cone (a robe, a hat, a horn): its own outline.
			var pts := PackedVector3Array()
			for k in 8:
				var a := TAU * k / 8.0
				var ring := Vector3(cos(a), 0.0, sin(a))
				pts.append(xf * (ring * cyl.bottom_radius - Vector3(0, cyl.height * 0.5, 0)))
				if cyl.top_radius > 0.0:
					pts.append(xf * (ring * cyl.top_radius + Vector3(0, cyl.height * 0.5, 0)))
			if cyl.top_radius <= 0.0:
				pts.append(xf * Vector3(0, cyl.height * 0.5, 0))
			pc.hull = pts
			var across := (xf.basis.x.length() + xf.basis.z.length()) * 0.5
			pc.inner = maxf(minf(cyl.top_radius, cyl.bottom_radius), 0.35 * maxf(cyl.top_radius, cyl.bottom_radius)) * across
		out.append(pc)
	out.sort_custom(func(x, y): return x.vol > y.vol)
	return out


## A piece's shape: a tapering cone its own hull; a flat piece a box (a
## wing, a hat brim); a long one a capsule along it (a limb, a torso, a
## neck); a round one a sphere (a head). Capsules and spheres take the
## mean of the piece's thicknesses, so an oval body is met about where
## it's drawn.
static func _fit(owner: Node, pc: Dictionary) -> StaticBody3D:
	var at: Node3D = pc.anchor
	if not (pc.hull as PackedVector3Array).is_empty():
		return Hitboxes.hull(owner, at, pc.hull)
	var axes: Array = pc.axes
	var order := [0, 1, 2]
	order.sort_custom(func(i, j): return (axes[i] as Vector3).length() > (axes[j] as Vector3).length())
	var h0: float = (axes[order[0]] as Vector3).length()
	var h1: float = (axes[order[1]] as Vector3).length()
	var h2: float = (axes[order[2]] as Vector3).length()
	var c: Vector3 = pc.center
	if h2 < h1 * 0.4:
		var x: Vector3 = (axes[0] as Vector3).normalized()
		var y: Vector3 = (axes[1] as Vector3).normalized()
		var z: Vector3 = (axes[2] as Vector3).normalized()
		if x.cross(y).dot(z) < 0.0:
			z = -z
		var size := Vector3((axes[0] as Vector3).length(), (axes[1] as Vector3).length(), (axes[2] as Vector3).length()) * 2.0
		size = Vector3(maxf(size.x, 1e-3), maxf(size.y, 1e-3), maxf(size.z, 1e-3))
		return Hitboxes.box(owner, at, c, size, Basis(x, y, z))
	if h0 > h1 * 1.15:
		var r := (h1 + h2) * 0.5
		var u: Vector3 = (axes[order[0]] as Vector3).normalized()
		return Hitboxes.capsule(owner, at, c - u * maxf(h0 - r, 0.0), c + u * maxf(h0 - r, 0.0), r)
	return Hitboxes.sphere(owner, at, c, (h0 + h1 + h2) / 3.0)


## A blocker inside a torso piece: along it, a quarter thinner than its
## thinnest.
static func _blocker_in(owner: Node, pc: Dictionary) -> StaticBody3D:
	var axes: Array = pc.axes
	var order := [0, 1, 2]
	order.sort_custom(func(i, j): return (axes[i] as Vector3).length() > (axes[j] as Vector3).length())
	var h0: float = (axes[order[0]] as Vector3).length()
	var inner: float = pc.inner
	var c: Vector3 = pc.center
	var u: Vector3 = (axes[order[0]] as Vector3).normalized()
	var half := maxf(h0 - inner, 0.0)
	return Hitboxes.blocker(owner, pc.anchor, c - u * half, c + u * half, inner * 0.75)


# --- Imported models -----------------------------------------------------------

## One shape over a whole imported model (ModelLibrary), from its meshes'
## bounds in the model's space.
static func _model(owner: Node, root: Node3D, block: bool, out: Array) -> void:
	var box := AABB()
	var first := true
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := mi.transform
		var p := mi.get_parent() as Node3D
		while p != null and p != root:
			xf = p.transform * xf
			p = p.get_parent() as Node3D
		var bb := xf * mi.mesh.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if first:
		return
	var pc := {"anchor": root, "center": box.get_center(),
		"axes": [Vector3(box.size.x * 0.5, 0, 0), Vector3(0, box.size.y * 0.5, 0), Vector3(0, 0, box.size.z * 0.5)], "vol": 1.0,
		"inner": minf(box.size.x, minf(box.size.y, box.size.z)) * 0.5, "hull": PackedVector3Array()}
	out.append(_fit(owner, pc))
	if block:
		out.append(_blocker_in(owner, pc))
