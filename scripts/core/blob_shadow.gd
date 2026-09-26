class_name BlobShadow
## Soft round blob shadows under the player, creatures and camp folk
## (shaders/blob_shadow.gdshader): nothing casts a real shadow (no shadow
## maps), so characters are grounded the way 2001-2004 console games did
## it, by a dark disc on the ground. One quad mesh and one material serve
## every blob; each is a child of its character's upright (unscaled) node,
## so local +Y is the planet's up and y = 0 the ground under its feet.

## Blobs beyond this are culled (the shader has faded them by then).
const FAR_M := 60.0
## Just above the ground.
const LIFT := 0.03

static var _mesh: PlaneMesh
static var _mat: ShaderMaterial


## A blob under `parent`: `radius` meters across the body, `length` along
## it (-Z, the way bodies face; 0 for round).
static func make(parent: Node3D, radius: float, length := 0.0) -> MeshInstance3D:
	if _mesh == null:
		_mesh = PlaneMesh.new()
		_mesh.size = Vector2(2.0, 2.0)
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://shaders/blob_shadow.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = FAR_M
	mi.position = Vector3(0.0, LIFT, 0.0)
	mi.scale = Vector3(radius, 1.0, length if length > 0.0 else radius)
	parent.add_child(mi)
	return mi


## A species' blob (half-width, half-length) in meters; zero for none
## (fireflies, wisps). Animals' size_m is their length, mythical figures'
## and people's their height.
static func footprint(sp: CreatureSpecies) -> Vector2:
	var s := sp.size_m
	var kind := sp.shape if sp.role == "mythical" else sp.body
	match kind:
		"swarm", "wisp":
			return Vector2.ZERO
		"quadruped", "wolf", "deer", "rodent":
			return Vector2(0.26, 0.5) * s
		"tortoise", "beetle", "frog":
			return Vector2(0.36, 0.46) * s
		"bird", "duck", "wader":
			return Vector2(0.26, 0.36) * s
		"unicorn":
			return Vector2(0.26, 0.48) * s
		"werewolf", "troll":
			return Vector2(0.36, 0.36) * s
	# Upright figures (people, goblins, witches, stalkers).
	return Vector2(0.3, 0.3) * s
