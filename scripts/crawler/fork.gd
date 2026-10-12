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
## The way up (design 10 Oct §FO.3; data/ruin_loop.json exit): since
## §FO.2 every ruin is one floor, so there is no way down and the fork's
## seal on it is not built (descent.json floors.count 1; its code kept).
## exit.sealed_until_home true (Mike's word, §FO.3) seals the way out's
## flight at its foot, in the heart's far wall, until the boss is first
## driven home: §EY.2's release, every torch lit and the boss gone down its
## lair (Boss.released and its state lair or gone; with no boss, the
## floor's last light). Then that seal sinks with the same grinding. false
## keeps it open from the start, as built before (§EX.5's 'an exit always
## exists', crawler.json exit.never_gated; §FO.9 call 3 is Mike's). The
## older key descent.json fork.gate_surface is read only when ruin_loop.json
## has no exit.sealed_until_home. The surface stair still leads where
## exit.stand_in sends it.
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
## save (CrawlerMain keeps "fork_open" for the dungeon on opened_now, and
## "exit_open" on exit_opened_now: first time only, §FO.3), and on
## Continue it is open at once, quiet (open_now(true), open_exit(true)).

## The secret opening (design §FO.4, SecretWing; lay.secret.door): a
## third seal of the same kind (ruin_loop.json secret.opening.kind
## stone_seal), standing from the start, seen and not passed, until the
## boss is first driven home (home()), whatever exit.sealed_until_home
## says; then it sinks with the same grinding. Kept as "secret_open".

## The ways have just opened, in play (not from a save).
signal opened_now
## The way up has just opened (the boss first driven home), in play.
signal exit_opened_now
## The secret opening has just opened, in play.
signal secret_opened_now

static var F: Dictionary = Tuning.table("descent").get("fork", {})
## ruin_loop.json exit (§FO.3).
static var EXIT: Dictionary = Tuning.table("ruin_loop").get("exit", {})

var lay: Dictionary
var fires: CrawlerFires
var residents: Residents
var boss: Boss
## The seals: the way down's, and the way out's (gate_surface).
var down: RelightGate
var surface: RelightGate
## The secret wing's seal (lay.secret), or null.
var secret: RelightGate
var gates: Array[RelightGate] = []
## The two ways are open (or opening): the floor's last light has caught,
## or a save said so.
var opened := false
## The physics frame they opened on (-1 not yet).
var opened_frame := -1
## The way up is open (or opening): the boss first driven home, or a save
## said so, or it was never sealed.
var exit_opened := false
## The physics frame the way up's seal began to open on (-1 not yet).
var exit_frame := -1
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
	var sec: Dictionary = lay.get("secret", {})
	if not sec.is_empty():
		secret = _gate(int(sec.door))
	for g in gates:
		for gr in _graphs():
			(gr as BossGround).shut[int(g.door.id)] = true


## Is the way up sealed until the boss is first driven home? ruin_loop.json
## exit.sealed_until_home (§FO.3, true), else descent.json
## fork.gate_surface.
static func gate_surface() -> bool:
	if EXIT.has("sealed_until_home"):
		return bool(EXIT.sealed_until_home)
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
	if not opened and down != null and TombFloors.floor_lit(fires, lay, 0):
		open_now()
	if not exit_opened and surface != null and home():
		open_exit()
	if secret != null and not secret.opened and home():
		open_secret()


## Has the boss been driven home (§EY.2's release: the last light, and it
## gone down its lair or into its tunnels)? With no boss, the floor's last
## light.
func home() -> bool:
	if boss != null and is_instance_valid(boss):
		return boss.released and boss.state in ["lair", "gone"]
	return TombFloors.floor_lit(fires, lay, 0)


## The way down opens, on this tick: its seal starts down (`quiet`: a save
## said it was open, so it is gone at once, no sound, no line), and the
## log's line once.
func open_now(quiet := false) -> void:
	if opened:
		return
	opened = true
	opened_frame = Engine.get_physics_frames()
	if down != null:
		down.open(quiet)
	if not quiet and down != null:
		GameLog.add(str(F.get("log_line", "Every light is lit. Two ways open: up to the day, or down.")), "fork")
		logged += 1
	if not quiet:
		opened_now.emit()


## The way up opens (§FO.3): its seal starts down with the grinding of
## stone (audio.json stone_seal, heard as far as the fork's), `quiet` gone
## at once from a save. Once only.
func open_exit(quiet := false) -> void:
	if exit_opened:
		return
	exit_opened = true
	exit_frame = Engine.get_physics_frames()
	if surface != null:
		surface.open(quiet)
	if not quiet:
		exit_opened_now.emit()


## The secret opening opens (§FO.4), with the grinding (`quiet`: from a
## save, gone at once). Once only.
func open_secret(quiet := false) -> void:
	if secret == null or secret.opened:
		return
	secret.open(quiet)
	if not quiet:
		secret_opened_now.emit()


## Is the way up open to walk (never sealed, or its seal gone)?
func exit_open() -> bool:
	return surface == null or surface.is_gone


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
