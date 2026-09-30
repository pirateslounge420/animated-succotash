class_name Hearth
## Your hearth (design 30 Sept §AY, camps.json wake_at_home): the fire
## you wake at when you die. The first is the opening camp's; right click
## the lit fire of any camp you find (Camps marks its fires "hearth_ok")
## to make it yours. Kept per world (WorldSave). Death costs nothing
## else: what you carried stays on your body where you fell.

static var dir := Vector3.ZERO
static var key := ""


## At the start of a world: the saved hearth, else the opening camp.
static func setup(opening: Vector3) -> void:
	var saved = WorldSave.data.get("hearth", null)
	if saved is Array and (saved as Array).size() == 3:
		dir = Vector3(float(saved[0]), float(saved[1]), float(saved[2])).normalized()
		key = FireStore.key_of(dir)
	else:
		set_home(opening, false)


static func set_home(d: Vector3, log := true) -> void:
	dir = d.normalized()
	key = FireStore.key_of(dir)
	WorldSave.data["hearth"] = [dir.x, dir.y, dir.z]
	WorldSave.mark_dirty()
	if log:
		GameLog.add("Made this fire your hearth.", "hearth_set")


## Is this fire the hearth?
static func is_home(fire: Node3D) -> bool:
	return fire != null and fire.has_meta("fuel_key") and str(fire.get_meta("fuel_key")) == key


## Can this fire be made the hearth: a camp's lit fire that isn't already.
static func can_set(fire: Node3D) -> bool:
	return fire != null and bool(fire.get_meta("hearth_ok", false)) and FireStore.is_lit(fire) and not is_home(fire)
