class_name Fork
extends Node
## The fork (design 9 Oct §FM.6, "an instantaneous first decision for the
## player"; data/descent.json fork): light every torch on floor one (the
## floor's cleared test, crawler.json cleared.when, TombFloors.floor_lit)
## and two ways open together, in that same tick (fork.both_at_once): the
## stair down to floor two (TombFloors), which until then is shut by a
## plain stone seal in its mouth (RelightGate, the first relight_to_open
## gate, crawler.json gates.kinds), and the stair up to the surface (§EX.5's
## way out). Order of choice only (fork.penalty none): up first or down
## first, both in time.
##
## fork.gate_surface false (as shipped; §FM.10 call 2 is Mike's) keeps the
## way out as built, never gated (crawler.json exit.never_gated): it stands
## open throughout and only the way down waits on the lights. Set true, the
## way out's flight is sealed the same way, at the foot of the flight in
## the heart's far wall, until floor one is lit. The surface stair still
## leads where exit.stand_in sends it (the next tomb) until the surface is
## built (prompt 71).
##
## Opening: each seal sinks into its doorway's floor with a grinding of
## stone heard down the passages (the opening you see and hear), and the
## log's one line (fork.log_line), once. Nothing points to the way down,
## before or after (§FG): no light, no mark, no line before it opens. While
## a seal stands, nothing walks through it: the floor grid's squares in its
## doorway are shut (TombNav.close_door), and the graph of the light
## (BossGround.shut) has no way through it, for the skeletons or the boss;
## both open again once it is down.
##
## Kept (design §FK.2, CrawlerSave): once open it stays open in this game's
## save (CrawlerMain keeps "fork_open" for the dungeon on opened_now), and on
## Continue it is open at once, quiet (open_now(true)).

## The ways have just opened, in play (not from a save).
signal opened_now

static var F: Dictionary = Tuning.table("descent").get("fork", {})

var lay: Dictionary
var fires: CrawlerFires
var residents: Residents
var boss: Boss
## The seals: the way down's, and the way out's (gate_surface).
var down: RelightGate
var surface: RelightGate
var gates: Array[RelightGate] = []
## The two ways are open (or opening): the floor's last light has caught,
## or a save said so.
var opened := false
## The physics frame they opened on (-1 not yet).
var opened_frame := -1
## Times the log's line was written (once).
var logged := 0
var _nav: TombNav


## The fork of tomb `p_lay` (TombKit, TombFloors): its seals in their
## doorways, the doorways shut to what walks.
func build(p_lay: Dictionary, p_fires: CrawlerFires, p_residents: Residents = null, p_boss: Boss = null) -> void:
	name = "Fork"
	lay = p_lay
	fires = p_fires
	residents = p_residents
	boss = p_boss
	var dsc: Dictionary = lay.get("descent", {})
	if not dsc.is_empty():
		down = _gate(int(dsc.door))
	if gate_surface():
		var sd := surface_door(lay)
		if sd >= 0:
			surface = _gate(sd)
	for g in gates:
		for gr in _graphs():
			(gr as BossGround).shut[int(g.door.id)] = true


## fork.gate_surface (descent.json; false as shipped).
static func gate_surface() -> bool:
	return bool(F.get("gate_surface", false))


## The door at the foot of the way out's flight (lay.exits' first: from the
## heart into its stair), or -1.
static func surface_door(p_lay: Dictionary) -> int:
	var exits: Array = p_lay.get("exits", [])
	if exits.is_empty():
		return -1
	var st := int(exits[0].stair)
	for d in p_lay.doors:
		if int(d.b) == st and int(d.a) == int(exits[0].heart):
			return int(d.id)
	return -1


func _gate(door_id: int) -> RelightGate:
	var g := RelightGate.new()
	add_child(g)
	g.build(lay, door_id)
	g.gone.connect(_on_gone)
	gates.append(g)
	return g


## The graphs that must not path through a standing seal: the skeletons'
## and the boss's.
func _graphs() -> Array:
	var out: Array = []
	if residents != null and residents.ground != null:
		out.append(residents.ground)
	if boss != null and boss.ground != null:
		out.append(boss.ground)
	return out


## The seals' collision (the floor grid casts through it: Residents
## .see_through).
func seal_rids() -> Array[RID]:
	var out: Array[RID] = []
	for g in gates:
		if not g.is_gone:
			out.append_array(g.rids())
	return out


## The floor grid (TombNav, Residents.build_nav): each standing seal's
## doorway shut on it.
func attach_nav(nav: TombNav) -> void:
	_nav = nav
	if nav == null:
		return
	for g in gates:
		if not g.is_gone:
			nav.close_door(g.door)


func _physics_process(_delta: float) -> void:
	if opened or gates.is_empty():
		return
	if TombFloors.floor_lit(fires, lay, 0):
		open_now()


## Both ways open, on this tick: every seal starts down (`quiet`: a save
## said they were open, so they are gone at once, no sound, no line), and
## the log's line once.
func open_now(quiet := false) -> void:
	if opened:
		return
	opened = true
	opened_frame = Engine.get_physics_frames()
	for g in gates:
		g.open(quiet)
	if not quiet and down != null:
		GameLog.add(str(F.get("log_line", "Every light is lit. Two ways open: up to the day, or down.")), "fork")
		logged += 1
	if not quiet:
		opened_now.emit()


## Is door `door_id` shut by a standing seal?
func shut(door_id: int) -> bool:
	for g in gates:
		if int(g.door.id) == door_id and not g.is_gone:
			return true
	return false


## A seal is down: its doorway open to what walks and to the light's graph.
func _on_gone(g: RelightGate) -> void:
	if _nav != null:
		_nav.open_door(g.door)
	for gr in _graphs():
		(gr as BossGround).shut.erase(int(g.door.id))
