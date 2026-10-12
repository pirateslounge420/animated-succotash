class_name RitualLock
extends Node
## The shaman's ritual as a little cutscene (design 10 Oct §FR.1, queue 97;
## data/shaman_ritual.json → cutscene). When you drink the shaman's brew
## (Brew.drink, queue 72) the frame moves to a fixed angle on the shaman
## (cutscene.camera fixed_on_shaman): a second camera, made once at setup
## and parked, set beside and a little behind your eyes, looking at the
## shaman, and held there. Your movement and look are locked for lock_s
## (the low end of the data's range, a first guess); then your own camera
## is current again, where you stood, facing as you faced.
##
## harm_during_lock false: while it is on, `active` is true, and Harm.hit
## lands nothing, Pursuit.notice starts no chase and the torch's burn
## does not run (CrawlerPlayer skips Torch.update_torch, so its timer
## pauses and resumes exactly).
##
## The beat hook (prompt 98): a culture registers a Callable in `beats`
## under its ruin's id (brew.json → world.ruin); begin() calls it with this
## lock. With none (every culture built so far: cutscene.other_cultures
## frame_only_nothing_happens) the lock is just the drinking.

const FILE := "res://data/shaman_ritual.json"

## On while the camera is locked (read by Harm, Pursuit and CrawlerPlayer).
static var active := false
## A culture's own beat by ruin id: Callable(lock: RitualLock).
static var beats := {}

var main: CrawlerMain
var cam: Camera3D
var t := 0.0
var lock_s := 10.0
var culture := ""
## Times the lock has run, and the last one's length (tools).
var runs := 0
var last_len := 0.0
var _hold_at := Vector3.ZERO


static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		if not parsed is Dictionary:
			push_warning("RitualLock: %s is missing or not valid JSON" % FILE)
			parsed = {}
		_data = parsed
	return _data


static func C() -> Dictionary:
	return data().get("cutscene", {})


## lock_s from the data: a number, or a [low, high] range read at its low end.
static func lock_len() -> float:
	var v: Variant = C().get("lock_s", 10.0)
	if v is Array and not (v as Array).is_empty():
		return maxf(float(v[0]), 0.0)
	return maxf(float(v), 0.0)


func setup(p_main: CrawlerMain) -> void:
	main = p_main
	name = "RitualLock"
	active = false
	cam = Camera3D.new()
	cam.name = "RitualCamera"
	cam.current = false
	add_child(cam)


## The drink: lock the frame on `shaman`.
func begin(shaman: Node3D) -> void:
	if main == null or main.player == null:
		return
	var c := C()
	if not bool(c.get("input_locked", true)):
		return
	var p := main.player
	var pc := p.camera()
	cam.fov = pc.fov
	cam.near = pc.near
	cam.far = pc.far
	cam.cull_mask = pc.cull_mask
	cam.attributes = pc.attributes
	_place(shaman)
	lock_s = lock_len()
	t = 0.0
	_hold_at = p.global_position
	p.ritual_locked = true
	p.velocity = Vector3.ZERO
	if not bool(c.get("harm_during_lock", false)):
		active = true
	cam.current = true
	runs += 1
	culture = str(Brew.data().get("world", {}).get("ruin", ""))
	var beat: Variant = beats.get(culture)
	if beat is Callable and (beat as Callable).is_valid():
		(beat as Callable).call(self)


func locked() -> bool:
	return main != null and main.player != null and main.player.ritual_locked


## The fixed angle: beside and a little behind your eyes, looking at the
## shaman's chest and head, pulled in short of any stone.
func _place(shaman: Node3D) -> void:
	var p := main.player
	var eye := p.eye_position()
	var head := eye + -p.camera().global_basis.z
	if shaman != null and is_instance_valid(shaman):
		var k := 1.0
		if shaman is HearthFolk:
			k = (shaman as HearthFolk).height / 1.62
		head = shaman.global_position + Vector3.UP * 1.35 * k
	var d := Vector3(head.x - eye.x, 0.0, head.z - eye.z)
	d = d.normalized() if d.length() > 0.05 else -p.global_basis.z
	var side := d.cross(Vector3.UP).normalized()
	var want := eye - d * 0.55 + side * 0.55 + Vector3.UP * 0.12
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, want, PropCollision.WORLD_LAYER)
	q.exclude = [p.get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = eye.lerp(hit.position, 0.7)
	cam.global_transform = Transform3D(Basis.IDENTITY, want)
	if want.distance_to(head) > 0.1:
		cam.look_at(head - Vector3.UP * 0.15, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not locked():
		return
	var p := main.player
	p.global_position = _hold_at
	p.velocity = Vector3.ZERO
	t += delta
	if t >= lock_s - 1e-6:
		end()


## The frame yours again, exactly as before.
func end() -> void:
	if main == null or main.player == null:
		active = false
		return
	var p := main.player
	last_len = t
	p.ritual_locked = false
	active = false
	cam.current = false
	p.camera().current = true


## A new tomb or the game over again: no lock carried over.
func reset() -> void:
	if locked():
		end()
	active = false
