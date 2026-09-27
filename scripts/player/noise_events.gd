class_name NoiseEvents
## Noises the player makes out in the world, for wildlife to hear (spec
## D5: "Player noise (footsteps, sprint, bow, spear) is what creatures
## hear"). The player's own noise is PlanetPlayer.noise_level, heard
## round the player; these are the sounds that happen somewhere else: an
## arrow or the spear thudding into the ground, a tree or an animal, or
## splashing into water. A missed shot can spook the animal it lands by.
##
## One owner each way: the player and its projectiles write (emit()),
## creatures read (since(), Creature._hear()). A creature within the
## noise's radius (widened by its suspicion, as its flight distance is)
## startles and flees from it; within twice that it grows suspicious.
##
## Positions are scene positions (after the floating origin). A noise
## lasts LIFE_FRAMES frames, long enough for every creature to tick once
## (far ones tick every few frames), then it's gone.

const LIFE_FRAMES := 8

## [id, scene position, radius m, frame emitted], oldest first.
static var _events: Array = []
static var _next_id := 1


## A noise at `pos`, heard `loudness_m` meters off.
static func emit(pos: Vector3, loudness_m: float) -> void:
	_prune()
	_events.append([_next_id, pos, loudness_m, Engine.get_process_frames()])
	_next_id += 1


## The noises newer than `last_id`: [{id, pos, radius}], oldest first
## (none, most frames).
static func since(last_id: int) -> Array:
	if _events.is_empty():
		return []
	_prune()
	var out: Array = []
	for e in _events:
		if e[0] > last_id:
			out.append({"id": e[0], "pos": e[1], "radius": e[2]})
	return out


static func clear() -> void:
	_events.clear()


static func _prune() -> void:
	var now := Engine.get_process_frames()
	while not _events.is_empty() and now - int(_events[0][3]) > LIFE_FRAMES:
		_events.pop_front()
