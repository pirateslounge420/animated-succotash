extends SceneTree
## The torch staggers, and every creature has its own strike tell (design
## 6 Oct §FA.1, §FA.2; prompt 57), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/stagger_check.gd
## Boots the crawler, puts a lit torch in your hand and faces you with the
## snake's strike (bosses.json bosses.desert strike, CreatureStrike) two
## metres ahead, every hit going through the player's take_hit to Harm.
## Asserts:
##  1. every strike block (bosses.json, residents.json) makes a strike,
##     and every creature's wind-up tell is its own (§FA.2: no shared cue);
##  2. the wind-up's sound starts on the wind-up's first frame, from a 3D
##     player at the creature's head, in its own voice (snake_hiss), and
##     the pose is the wind-up's;
##  3. a swing landing at 50% of the wind-up staggers it: the strike is
##     broken, it reels back for reel_s by reel_m, and no hit counts; no
##     damage (stagger.damage 0: it is still there, still striking after);
##  4. a second stagger inside cooldown_s fails, and that strike's hit
##     counts;
##  5. a swing landing after the wind-up ends, in the committed strike,
##     doesn't stagger, and the hit counts;
##  6. the same swing as 3 with the torch unlit staggers nothing, and the
##     hit counts;
##  7. a swing that lands is as loud as a sprint, held long enough to be
##     heard; a swing that meets nothing isn't;
##  8. stepped out of reach in the wind-up, the strike misses; a creature
##     behind you, or out of the swing's reach, isn't met by it;
##  9. the swing still passes the flame (§CN): its arc ends as built.

var main: CrawlerMain
var player: CrawlerPlayer
var torch: Torch
var harm: Harm
var creature: Node3D
var strike: CreatureStrike
var lane := {}
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


static func _json(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _run() -> void:
	WorldSave.read_only = true
	# The tomb's skeletons sleep through this check (design §FE; queue 58).
	Residents.stay_asleep = true
	Bow.need_capture = false
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	_blocks()
	main = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	player = main.player
	torch = player.torch
	# Hits go through the player's take_hit to Harm (§EA, §EC); the crawler
	# installs its own once it has creatures (prompt 49), else one here.
	harm = Harm.instance if Harm.instance != null and is_instance_valid(Harm.instance) else null
	if harm == null:
		harm = Harm.new()
		harm.name = "Harm"
		main.add_child(harm)
		harm.setup(player, main.post, null)
	ok(Harm.active(), "hits count through Harm (the ambient profile)")
	lane = _lane()
	ok(not lane.is_empty(), "a clear lane in the hearth room: you, the creature 2 m ahead, room behind you")
	if lane.is_empty():
		_done()
		return
	# A torch from the bundle, lit.
	player.inventory.add(Inventory.make("torch"))
	player.weapon = "torch"
	torch.light()
	ok(torch.lit(), "a lit torch in hand")
	var desert: Dictionary = (_json("res://data/bosses.json").get("bosses", {}) as Dictionary).get("desert", {})
	creature = Node3D.new()
	creature.name = "StandIn"
	main.add_child(creature)
	strike = CreatureStrike.new()
	strike.name = "Strike"
	creature.add_child(strike)
	strike.setup(desert.get("strike", {}), str(desert.get("creature", "giant snake")))
	strike.target = player
	_place()
	await _tell()
	await _stagger_at_half()
	await _cooldown()
	await _committed()
	await _unlit()
	await _noise()
	await _misses()
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## 1. Every strike block, and every creature's own tell.
func _blocks() -> void:
	var bosses := _json("res://data/bosses.json")
	var res := _json("res://data/residents.json")
	var blocks := {}
	for group in ["bosses", "unplaced"]:
		var g: Dictionary = bosses.get(group, {})
		for k in g:
			if (g[k] as Dictionary).has("strike"):
				blocks["boss " + str(k)] = g[k]
	var rc: Dictionary = res.get("creatures", {})
	for k in rc:
		if (rc[k] as Dictionary).has("strike"):
			blocks["resident " + str(k)] = rc[k]
	var good := 0
	var tells := {}
	var shared := []
	for k in blocks:
		var c: Dictionary = blocks[k]
		var s := CreatureStrike.new()
		s.setup(c.strike, str(c.get("creature", k)))
		if s.reach_m > 0.0 and s.wind_up_s > 0.0 and s.strike_s >= 0.0:
			good += 1
		s.free()
		var words := str((c.strike as Dictionary).get("tell", (c.get("tells", {}) as Dictionary).get("wind_up", "")))
		if words != "":
			if tells.has(words):
				shared.append(words)
			tells[words] = k
	ok(good == blocks.size() and blocks.size() >= 10, "every strike block makes a strike (%d: %s)" % [blocks.size(), ", ".join(blocks.keys())])
	var desert: Dictionary = (bosses.get("bosses", {}) as Dictionary).get("desert", {})
	var ds: Dictionary = desert.get("strike", {})
	ok(not ds.is_empty() and float(ds.get("wind_up_s", 0.0)) > 0.0 and float(ds.get("reach_m", 0.0)) > 0.0 and str(ds.get("tell", "")) != "" and str(ds.get("sound", "")) != "",
		"the snake has its strike: reach %.1f m, wind-up %.2f s, \"%s\" (%s)" % [float(ds.get("reach_m", 0.0)), float(ds.get("wind_up_s", 0.0)), str(ds.get("tell", "")), str(ds.get("sound", ""))])
	ok(shared.is_empty() and tells.size() >= 7, "every creature's wind-up tell is its own (%d tells, none shared%s)" % [tells.size(), "" if shared.is_empty() else ": " + ", ".join(shared)])
	var st: Dictionary = Tuning.table("torch").get("stagger", {})
	ok(float(st.get("damage", 1.0)) == 0.0 and bool(st.get("lit_only", false)) and str(st.get("on", "")) == "wind_up",
		"torch.json stagger: no damage, lit only, in the wind-up (reel %.1f s, cooldown %.1f s)" % [float(st.get("reel_s", 0.0)), float(st.get("cooldown_s", 0.0))])
	ok(not str((Tuning.table("torch").get("_help", {}) as Dictionary).get("stagger", "")).begins_with("[NOT WIRED"), "torch.json _help.stagger is no longer marked not wired")
	ok(SoundSynth.stream(str(ds.get("sound", "")), 0) != null, "the snake's tell has a voice in the synth (%s)" % str(ds.get("sound", "")))


## A clear lane along one of the hearth room's walls: you 1.6 m in from
## the middle line, facing along the wall, the creature 2 m ahead, 1.2 m
## behind you clear (the hearth, the bundle, the mat and anything built
## round the hearth well off to the side).
func _lane() -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	for k in 4:
		var yaw := k * PI * 0.5
		var b := Basis(Vector3.UP, yaw)
		var at := b * Vector3(3.2, 0.0, 1.6)
		var fwd := b * Vector3(0.0, 0.0, -1.0)
		var head := at + fwd * 2.0 + Vector3.UP * 0.6
		var chest := at + Vector3.UP * 0.9
		var clear := true
		for to in [head, at - fwd * 1.2 + Vector3.UP * 0.6, at - fwd * 0.8 + Vector3.UP * 0.9, head - fwd * 1.0]:
			var q := PhysicsRayQueryParameters3D.create(chest, to, PropCollision.WORLD_LAYER)
			q.exclude = [player.get_rid()]
			if not space.intersect_ray(q).is_empty():
				clear = false
		var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 0.5, PropCollision.WORLD_LAYER)
		down.exclude = [player.get_rid()]
		var floor_hit := space.intersect_ray(down)
		if clear and not floor_hit.is_empty() and absf((floor_hit.position as Vector3).y) < 0.2:
			return {"at": at, "yaw": yaw, "fwd": fwd, "head": head}
	return {}


## You at the lane's spot facing along it, the creature 2 m ahead, ready.
func _place() -> void:
	player.global_position = lane.at
	player.velocity = Vector3.ZERO
	player.set_view(0.0, float(lane.yaw))
	creature.global_position = lane.head
	strike.cancel()
	strike.cooldown_left = 0.0
	harm.reset()
	player._invulnerable = 0.0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		creature.global_position += strike.take_reel()


## Step until the strike is `share` of the way into its wind-up less the
## swing's own time to its top, then swing.
func _swing_for(share: float) -> void:
	var lead := Fists.STRIKE_S * (1.0 - Torch.SWING_TOP) + 1.0 / 60.0
	var guard := 0
	while strike.state == "wind_up" and strike.t < share * strike.wind_up_s - lead and guard < 600:
		await _frames(1)
		guard += 1
	torch.swing()


## Step until the last swing has reached its top (or `n` frames).
func _to_top(n := 30) -> void:
	for i in n:
		if torch._swing <= Torch.SWING_TOP:
			return
		await _frames(1)


## 2. The tell.
func _tell() -> void:
	_place()
	ok(strike.begin(), "the strike begins")
	ok(strike.wind_up_frame == Engine.get_physics_frames() and strike.tell_frame == strike.wind_up_frame,
		"its sound starts on the wind-up's first frame (frame %d, sound %d)" % [strike.wind_up_frame, strike.tell_frame])
	var tell: AudioStreamPlayer3D = strike.get_node_or_null("Tell")
	ok(tell != null and tell.stream != null and tell.playing and str(tell.get_meta("audio_kind", "")) == "strike_tell" and strike.sound == "snake_hiss",
		"its own voice, from a 3D player at its head (%s, %s)" % [strike.sound, str(tell.get_meta("audio_kind", "")) if tell != null else "none"])
	ok(strike.pose() == "wind_up", "its sprite's pose is the wind-up (%s)" % strike.pose())
	await _frames(int(ceil(strike.wind_up_s * 60.0)) + 1)
	ok(strike.state == "strike" or strike.state == "recover", "after wind_up_s it is committed (%s)" % strike.state)
	ok(tell != null and not tell.playing, "its tell stops as the strike goes")
	var hits0 := harm.landed
	await _frames(int(ceil((strike.strike_s + strike.recover_s) * 60.0)) + 2)
	ok(strike.landed == 1 and harm.landed == hits0 + 1, "left alone, the strike lands one hit (strike %d, Harm %d -> %d)" % [strike.landed, hits0, harm.landed])


## 3. A swing at half the wind-up.
func _stagger_at_half() -> void:
	_place()
	await _frames(2)
	var hits0 := harm.landed
	var landed0 := strike.landed
	var d0 := Vector2(creature.global_position.x - player.global_position.x, creature.global_position.z - player.global_position.z).length()
	strike.begin()
	await _swing_for(0.5)
	await _to_top()
	await _frames(1)
	ok(torch.last_contact == "staggered" and strike.staggers == 1 and strike.state == "reel",
		"a lit swing landing at %.0f%% of the wind-up staggers it (%s, %s)" % [strike.met_at_share * 100.0, torch.last_contact, strike.state])
	ok(absf(strike.met_at_share - 0.5) < 0.06, "it landed at half the wind-up (%.2f)" % strike.met_at_share)
	var tell: AudioStreamPlayer3D = strike.get_node_or_null("Tell")
	ok(tell != null and not tell.playing, "its tell is broken off with its strike")
	ok(strike.pose() == "reel", "its pose is the reel (%s)" % strike.pose())
	var guard := 0
	while strike.state == "reel" and guard < 300:
		await _frames(1)
		guard += 1
	await _frames(1)
	var d1 := Vector2(creature.global_position.x - player.global_position.x, creature.global_position.z - player.global_position.z).length()
	var reel_took := (strike.reel_end_frame - strike.stagger_frame) / 60.0
	ok(absf(reel_took - CreatureStrike.reel_s()) < 0.034, "it reels for reel_s (%.2f s, reel_s %.2f), unable to strike" % [reel_took, CreatureStrike.reel_s()])
	ok(absf((d1 - d0) - strike.reel_m) < 0.1, "it reels back %.2f m (reel_m %.2f)" % [d1 - d0, strike.reel_m])
	await _frames(60)
	ok(harm.landed == hits0 and strike.landed == landed0 and strike.strikes == 1,
		"its strike broken: no hit counts (Harm %d, still %d after)" % [hits0, harm.landed])
	ok(is_instance_valid(creature) and creature.is_inside_tree() and CreatureStrike.all.has(strike), "no damage: it is still there (stagger.damage 0)")


## 4. Again inside the cooldown.
func _cooldown() -> void:
	# Back where it was, still inside cooldown_s of the stagger.
	creature.global_position = lane.head
	var left := strike.cooldown_left
	ok(left > 0.0, "still inside the cooldown (%.2f s left of %.1f)" % [left, float(CreatureStrike.D.get("cooldown_s", 3.0))])
	var hits0 := harm.landed
	ok(strike.begin(), "it strikes again inside the cooldown")
	await _swing_for(0.5)
	await _to_top()
	await _frames(1)
	ok(torch.last_contact == "landed" and strike.staggers == 1 and strike.state == "wind_up",
		"a second stagger inside cooldown_s fails (%s at %.0f%%, %.2f s of cooldown left)" % [torch.last_contact, strike.met_at_share * 100.0, strike.cooldown_left])
	await _frames(int(ceil((strike.wind_up_s + strike.strike_s) * 60.0)))
	ok(harm.landed == hits0 + 1, "and that strike's hit counts (Harm %d -> %d)" % [hits0, harm.landed])
	await _frames(int(ceil(strike.recover_s * 60.0)) + 2)


## 5. In the committed strike.
func _committed() -> void:
	await _frames(int(ceil(strike.cooldown_left * 60.0)) + 2)
	_place()
	await _frames(2)
	var hits0 := harm.landed
	strike.begin()
	# Swung so its top comes just after the wind-up ends.
	await _swing_for(1.0 + 0.5 * strike.strike_s / strike.wind_up_s)
	var state_at := ""
	for i in 30:
		if torch._swing <= Torch.SWING_TOP:
			break
		await _frames(1)
		state_at = strike.state
	await _frames(1)
	ok(torch.last_contact == "landed" and strike.staggers == 1 and strike.cooldown_left <= 0.0,
		"a swing landing after the wind-up ends (in the %s) doesn't stagger it (%s)" % [state_at, torch.last_contact])
	await _frames(int(ceil(strike.strike_s * 60.0)) + 2)
	ok(harm.landed == hits0 + 1, "and the hit counts (Harm %d -> %d)" % [hits0, harm.landed])
	await _frames(int(ceil(strike.recover_s * 60.0)) + 2)


## 6. Unlit.
func _unlit() -> void:
	_place()
	await _frames(40)
	torch.item()["lit"] = false
	ok(not torch.lit() and torch.in_hand(), "the torch in hand, unlit")
	var hits0 := harm.landed
	strike.begin()
	await _swing_for(0.5)
	await _to_top()
	await _frames(1)
	ok(torch.last_contact == "landed" and strike.staggers == 1 and absf(strike.met_at_share - 0.5) < 0.06,
		"the same swing unlit staggers nothing (%s at %.0f%%)" % [torch.last_contact, strike.met_at_share * 100.0])
	await _frames(int(ceil((strike.wind_up_s + strike.strike_s) * 60.0)))
	ok(harm.landed == hits0 + 1, "and the hit counts (Harm %d -> %d)" % [hits0, harm.landed])
	torch.light()
	await _frames(int(ceil(strike.recover_s * 60.0)) + 2)


## 7. Loud.
func _noise() -> void:
	_place()
	await _frames(40)
	var idle := player.noise_level
	torch.swing()
	await _to_top()
	await _frames(1)
	ok(torch.last_contact == "landed" and player.noise_level >= 0.99,
		"a swing that lands is as loud as a sprint (%.2f; standing it is %.2f)" % [player.noise_level, idle])
	await _frames(int(CrawlerPlayer.LOUD_HOLD_S * 60.0) - 6)
	ok(player.noise_level >= 0.99, "still loud %.2f s on, for anything listening" % ((int(CrawlerPlayer.LOUD_HOLD_S * 60.0) - 5) / 60.0))
	await _frames(20)
	ok(player.noise_level < 0.5, "then quiet again (%.2f)" % player.noise_level)
	# Nothing in reach: a swing at the air is no louder than standing.
	creature.global_position = lane.at + lane.fwd * 6.0 + Vector3.UP * 0.6
	torch.swing()
	await _to_top()
	await _frames(2)
	ok(torch.last_contact == "" and player.noise_level < 0.5, "a swing that meets nothing isn't (%.2f)" % player.noise_level)
	await _frames(20)


## 8. Reach.
func _misses() -> void:
	_place()
	await _frames(40)
	var hits0 := harm.landed
	strike.begin()
	await _frames(int(strike.wind_up_s * 0.5 * 60.0))
	# Back out of reach, half way through its wind-up.
	player.global_position = lane.at - lane.fwd * (strike.reach_m - 2.0 + 0.4)
	await _frames(int(ceil((strike.wind_up_s * 0.5 + strike.strike_s) * 60.0)) + 2)
	ok(strike.strikes >= 1 and harm.landed == hits0 and strike.state == "recover",
		"stepped out of reach in the wind-up, the strike misses (Harm %d -> %d)" % [hits0, harm.landed])
	await _frames(int(ceil(strike.recover_s * 60.0)) + 2)
	_place()
	await _frames(2)
	# Behind you, within the swing's reach.
	creature.global_position = lane.at - lane.fwd * 1.2 + Vector3.UP * 0.6
	var met := strike.swings_met
	strike.begin()
	await _swing_for(0.5)
	await _to_top()
	await _frames(1)
	ok(torch.last_contact == "" and strike.swings_met == met and strike.staggers == 1, "a creature behind you isn't met by the swing (%s)" % torch.last_contact)
	strike.cancel()
	# Past the swing's reach, ahead.
	creature.global_position = lane.at + lane.fwd * (Torch.reach_m() + strike.body_r + 1.2) + Vector3.UP * 0.6
	strike.cooldown_left = 0.0
	strike.begin()
	await _swing_for(0.5)
	await _to_top()
	await _frames(1)
	ok(torch.last_contact == "" and strike.staggers == 1, "nor one past the swing's reach (%.1f m ahead)" % (Torch.reach_m() + strike.body_r + 1.2))
	strike.cancel()
	# 9. The swing still ends by passing the flame (§CN).
	while torch._swing > 0.0:
		await _frames(1)
	var passes := torch.swings
	torch.swing()
	for i in 30:
		await _frames(1)
	ok(torch.swings == passes + 1 and torch._swing == 0.0, "the swing still runs its arc to the end, where the flame passes (§CN)")
