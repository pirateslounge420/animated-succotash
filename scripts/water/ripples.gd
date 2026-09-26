class_name Ripples
## Water ripples: the one way anything disturbs a water surface (spec
## Phase 1). Callers don't need to know whether the simulation is running
## or where the water is: they report contacts, and the ripple simulation
## (registered with `attach()`) turns them into rings on the nearby water
## chunks. With no simulation attached every call is a harmless no-op.
##
## Positions are scene positions (after the floating origin, like any
## node's global_position). Sizes come from the object's mass and speed.
##
## Readers (fish fleeing a disturbance, later) use `height_at()` or the
## shared state on World (`World.ripples`).

## The running simulation (owner of World.ripples), or null.
static var _sim: Object = null


static func attach(sim: Object) -> void:
	_sim = sim


static func detach(sim: Object) -> void:
	if _sim == sim:
		_sim = null


## A single touch: a foot or hand planting, a dropped item, an arrow or a
## raindrop hitting the surface. `mass_kg` and `speed_mps` size the ring.
static func splash(pos: Vector3, mass_kg: float, speed_mps: float) -> void:
	if _sim:
		_sim.add_splash(pos, mass_kg, speed_mps)


## A body moving through water: call every frame while it's in the water,
## with a stable `key` per contact (e.g. get_instance_id() * 8 + contact
## index). The simulation draws a continuous wake between successive
## positions of the same key, not a string of separate splashes.
static func wake(key: int, pos: Vector3, mass_kg: float, speed_mps: float) -> void:
	if _sim:
		_sim.add_wake(key, pos, mass_kg, speed_mps)


## Surface displacement (m, + up) of the ripples at `pos`, 0 away from any
## simulated water.
static func height_at(pos: Vector3) -> float:
	if _sim:
		return _sim.height_at(pos)
	return 0.0
