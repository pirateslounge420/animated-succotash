class_name Hearth
## Your hearth (design 30 Sept §AY, camps.json wake_at_home): the fire
## you wake at when you die. Right click the lit fire of any camp you find
## (Camps marks its fires "hearth_ok") to make it yours. Until you do you
## have none, and folk carry you to the nearest lit fire with folk at it
## (design 3 Oct §DE amends §AY: the opening camp is no longer your hearth
## by default). Kept per world (WorldSave). Death costs nothing else: what
## you carried stays on your body where you fell.

static var dir := Vector3.ZERO
static var key := ""


## At the start of a world: the hearth you made, else none (§DE). A save
## from before §DE kept the opening camp as its hearth without asking:
## that one is let go unless you chose it ("hearth_chosen").
static func setup(opening: Vector3) -> void:
	dir = Vector3.ZERO
	key = ""
	var saved = WorldSave.data.get("hearth", null)
	if saved is Array and (saved as Array).size() == 3:
		var d := Vector3(float(saved[0]), float(saved[1]), float(saved[2])).normalized()
		var by_default := opening != Vector3.ZERO and CubeSphere.surface_distance_m(d, opening) < 30.0 and not bool(WorldSave.data.get("hearth_chosen", false))
		if not by_default:
			dir = d
			key = FireStore.key_of(dir)


## Make the fire at `d` your hearth (right click its lit fire).
static func set_home(d: Vector3, log := true) -> void:
	dir = d.normalized()
	key = FireStore.key_of(dir)
	WorldSave.data["hearth"] = [dir.x, dir.y, dir.z]
	WorldSave.data["hearth_chosen"] = true
	WorldSave.mark_dirty()
	if log:
		GameLog.add("Made this fire your hearth.", "hearth_set")


## No hearth (its fire is gone from the world).
static func clear() -> void:
	dir = Vector3.ZERO
	key = ""
	WorldSave.data.erase("hearth")
	WorldSave.data.erase("hearth_chosen")
	WorldSave.mark_dirty()


## Is this fire the hearth?
static func is_home(fire: Node3D) -> bool:
	return fire != null and fire.has_meta("fuel_key") and str(fire.get_meta("fuel_key")) == key


## Can this fire be made the hearth: a camp's lit fire that isn't already.
static func can_set(fire: Node3D) -> bool:
	return fire != null and bool(fire.get_meta("hearth_ok", false)) and FireStore.is_lit(fire) and not is_home(fire)
