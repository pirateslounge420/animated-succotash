class_name Blackout
extends Node
## Phase two: the blackout and the boss's angry round (design 10 Oct §FO.5,
## §FO.6, queue 87; data/ruin_loop.json phase_two). One per dungeon, built
## with it (CrawlerMain) and kept out of the tree with it while you are up
## on the surface.
##
## The trigger is taking the scroll at the end of the secret wing
## (SecretWing.taken_now, phase_two.trigger artifact_taken). Then every
## flame in the ruin goes out at once (phase_two.blackout): every relit
## holder and the hearth (every Campfire in the tomb: FireStore's store put
## out, its kindling and catching gone), every planted torch, the torch in
## your hand (and any lit torch in your pack), a fire pot's fire burning on
## the floor, and a lit wick in your hand. And nothing can be lit again
## (blackout.relight false): FireStore.blackout, while this node is in the
## tree, stops the swing lighting a fire (FireStore.swing_light), a torch
## catching (Torch.light), a planted torch relighting (PlantedTorch
## .relight) and a fire pot's wick catching (FirePots._catch). The code that
## keeps a relit holder lit (§ET.4) and the torch's hold are untouched
## everywhere else: only this overrides them, and only here.
##
## The light that is left is the place's own (phase_two.light ambient_only;
## §FO.9 call 4 is Mike's): the day and night shafts down the vents on the
## one clock (Vents), the glow moss (GlowMoss, brighter now no flame dims
## it), the way out's daylight at the top of its flight (WayOut), and your
## eyes adjusting to the dark (HalfDark, which comes on with no flame near
## you). Nothing else glows.
##
## The boss comes out again (phase_two.boss; Boss.anger): angry from now on,
## every speed of its own times speed_mult, for any boss through the one
## code path (Boss.num); down its lair, it comes up after emerge_after_s,
## its long cry travelling up from its hole (the release reversed), and
## prowls the whole floor: no light burns, so every room is its ground and
## none is closed to it. Everything else holds: never beaten, three hits and
## Good night (which wakes you by the cold hearth, in the dark), every
## wind-up and tell, its pool. The way up stays open (it opened when the
## boss was first driven home, §FO.3) and walking out ends the visit as it
## always has.
##
## Kept (phase_two.save true, §FO.9 call 7's first guess): the dungeon's
## "blackout" in the game's save, so Continue loads the dark (the relit
## holders are kept as they were, so false brings the lights back on
## Continue).

## The blackout has just come down, in play.
signal fell

static var P2: Dictionary = (Tuning.table("ruin_loop") as Dictionary).get("phase_two", {})

var main: Node
var fires: CrawlerFires
var boss: Boss
var player: CrawlerPlayer
## The place in this game's world (CrawlerSave).
var at := 0
## Down: every flame out, nothing lights.
var active := false
## The physics frame it came down on (-1 not yet).
var fell_frame := -1
## Flames it put out when it came down (the checks).
var put_out := 0


func build(p_fires: CrawlerFires, p_boss: Boss, p_player: CrawlerPlayer, p_at: int) -> void:
	name = "Blackout"
	fires = p_fires
	boss = p_boss
	player = p_player
	at = p_at


## Is the blackout kept in the save (phase_two.save; true unless the data
## says false)?
static func kept() -> bool:
	var v: Variant = P2.get("save", true)
	return v == null or bool(v)


static func boss_def() -> Dictionary:
	return P2.get("boss", {})


## Every flame out and nothing to light again (`quiet`: from a save, no
## line). Once.
func start(quiet := false) -> void:
	if active:
		return
	active = true
	fell_frame = Engine.get_physics_frames()
	FireStore.blackout = is_inside_tree()
	put_out = douse_all()
	if boss != null and is_instance_valid(boss):
		var bd := boss_def()
		if bool(bd.get("emerges", true)):
			boss.anger(float(bd.get("speed_mult", 1.2)), float(bd.get("emerge_after_s", 3.0)))
	if kept():
		CrawlerSave.keep(at, "blackout", true)
	if not quiet:
		GameLog.add(str(P2.get("log_line", "Every flame in the ruin goes out at once.")), "world")
		fell.emit()


## Put out every flame in the tomb; how many.
func douse_all() -> int:
	var n := 0
	if not is_inside_tree():
		return n
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var fire := f as Node3D
		if fire == null or not fire.is_inside_tree():
			continue
		var st := FireStore.store_of(fire)
		if st.is_empty():
			continue
		if FireStore.is_lit(fire) or str(st.get("state", "")) in ["catching", "embers"]:
			n += 1
		st["state"] = "out"
		st.erase("kindling")
		st.erase("catch_s")
		st.erase("flare_s")
		FireStore.apply(fire)
	for p in PlantedTorch.all:
		if is_instance_valid(p) and p.lit():
			p.item["lit"] = false
			p._apply()
			n += 1
	if player != null and player.torch != null:
		if player.torch.lit():
			player.torch.put_out("blackout")
			n += 1
		if player.inventory != null:
			for it in player.inventory.carried + player.inventory.strip:
				if it is Dictionary and bool((it as Dictionary).get("lit", false)):
					it["lit"] = false
	var fp := FirePots.instance
	if fp != null and is_instance_valid(fp):
		for f in fp.fires:
			if is_instance_valid(f) and (f as PotFire).burning():
				(f as PotFire).t = (f as PotFire).life_s
				n += 1
		if fp.state == "aiming":
			var pot: Dictionary = fp.in_left()
			if not pot.is_empty():
				pot["lit"] = false
			fp._set_state("idle")
			n += 1
	return n


func _enter_tree() -> void:
	if active:
		FireStore.blackout = true


func _exit_tree() -> void:
	FireStore.blackout = false


## While down: anything that still shows a flame (a fire caught on its own
## catch time, say) goes out again at once.
func _physics_process(_delta: float) -> void:
	if not active:
		return
	FireStore.blackout = true
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var fire := f as Node3D
		if fire != null and fire.is_inside_tree() and (FireStore.is_lit(fire) or FireStore.state_of(fire) == "catching"):
			douse_all()
			return


## The flames burning in the tomb now (the hearth, holders, planted torches,
## the torch in hand, pot fires, wicks): CrawlerFires.flame_points.
func flames_now() -> int:
	return fires.flame_points().size() if fires != null and is_instance_valid(fires) else 0
