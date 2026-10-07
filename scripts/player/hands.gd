class_name Hands
extends Node3D
## Two hands (design 6 Oct §FB, data/hands.json), in Torchfire 1's
## crawler. The right hand holds the torch, bare hands, or a spear once
## found (right.holds you have, in that order); the left holds a left-hand
## thing from the pack's own strip (Inventory.strip: a fire pot, §FA.3) or
## nothing. The mouse wheel (Controls hand_next / hand_prev) steps the hand
## it drives through its choices, the right by default; with Tab held
## (other_hand) it steps the other hand. On the Controls page the player
## can give the plain wheel to the left hand (Controls.wheel_drives());
## then Tab and the wheel drive the right. Q doesn't swap here
## (hands.json q_swaps). Scrolling a lit torch away puts it out, as built
## (Torch.stow). Holding Tab shows a wordless strip of what Tab and the
## wheel step through (HandStrip, tab_hold). The fire pots (FirePots,
## prompt 60) are the left hand's things: FirePots asks this which pot is
## in hand, draws it low left in view and lights and throws it, and while
## a pot is being lit or aimed the left hand doesn't change. The open
## world keeps Q and its tool swap (PlanetPlayer.swap_weapon): none of
## this runs there.

static var D: Dictionary = Tuning.table("hands")

var player: PlanetPlayer
## The strip place (Inventory.strip) in the left hand, or -1: empty.
var left := -1
## How long Tab (other_hand) has been held, s (HandStrip shows the strip
## past tab_hold.show_after_s).
var tab_s := 0.0
## The last step taken, [hand, from, to], and how many (the checks).
var last_step: Array = []
var steps := 0
var _clock := 0.0
## The wheel's stroke (wheel_step): its way, its last event, what its
## small steps add up to, and whether this stroke has stepped.
var _wheel_dir := 0
var _wheel_at := -10.0
var _wheel_sum := 0.0
var _spent := false


func setup(p: PlanetPlayer) -> void:
	player = p


## Does Q step the right hand (hands.json q_swaps; false: the wheel took
## its place)?
static func q_swaps() -> bool:
	return bool(D.get("q_swaps", false))


static func _tab() -> Dictionary:
	var t = D.get("tab_hold", {})
	return t if t is Dictionary else {}


## The hand the plain wheel drives ("right" or "left"), and the one Tab
## and the wheel drive.
static func wheel_hand() -> String:
	return Controls.wheel_drives()


static func tab_hand() -> String:
	return "left" if Controls.wheel_drives() == "right" else "right"


## What the right hand can hold now, in right.holds' order, as
## PlanetPlayer.weapon names; bare hands always.
func right_choices() -> Array:
	var out: Array = []
	for h in (D.get("right", {}) as Dictionary).get("holds", ["torch", "bare"]):
		match str(h):
			"torch":
				if player.inventory.has_kind("torch"):
					out.append("torch")
			"bare":
				out.append("hands")
			"spear":
				# Once found (§ED.7): worn, and a spear to hold it with.
				if player.spear != null and player.wears("melee", "spear"):
					out.append("spear")
	if not "hands" in out:
		out.append("hands")
	return out


## What the right hand holds of its choices (a torch put down or gone is
## bare hands).
func right_now() -> String:
	return player.weapon if player.weapon in right_choices() else "hands"


## The left hand's choices: the strip's filled places in order, then -1
## (empty).
func left_choices() -> Array:
	var out: Array = []
	var strip: Array = player.inventory.strip
	for i in strip.size():
		if strip[i] != null:
			out.append(i)
	out.append(-1)
	return out


## The thing in the left hand, or {} (empty).
func left_item() -> Dictionary:
	var strip: Array = player.inventory.strip
	if left >= 0 and left < strip.size() and strip[left] is Dictionary:
		return strip[left]
	return {}


## Put `it` (a thing on the strip) in the left hand; {} or a thing not on
## the strip empties it.
func hold_left(it: Dictionary) -> void:
	left = -1
	if it.is_empty():
		return
	var strip: Array = player.inventory.strip
	for i in strip.size():
		if is_same(strip[i], it):
			left = i
			return


## Is the left hand busy (a fire pot being lit or aimed, FirePots)? Then
## it doesn't change.
static func left_busy() -> bool:
	return FirePots.instance != null and is_instance_valid(FirePots.instance) and FirePots.instance.state != "idle"


## Step `hand` ("right" or "left") to its next thing (`dir` 1) or the one
## before (-1), round again past the end; the left not while it's busy.
func cycle(hand: String, dir: int) -> void:
	if hand == "left" and left_busy():
		return
	steps += 1
	if hand == "left":
		_cycle_left(dir)
	else:
		_cycle_right(dir)


func _cycle_right(dir: int) -> void:
	var choices := right_choices()
	var from: String = player.weapon
	var to: String = choices[posmod(choices.find(right_now()) + dir, choices.size())]
	last_step = ["right", from, to]
	if to == from:
		return
	if from == "torch":
		# Put away, a lit torch goes out (§AW, as built).
		player.torch.stow()
	player.weapon = to
	# A swing held through the change waits for the button to be let go.
	player.torch.block_until_release()


func _cycle_left(dir: int) -> void:
	if left_item().is_empty():
		left = -1
	var choices := left_choices()
	var to: int = choices[posmod(choices.find(left) + dir, choices.size())]
	last_step = ["left", left, to]
	left = to


## The wheel, or a key bound to hand_next / hand_prev (Controls): true if
## the event was one of them (used up, whether it stepped or not).
func wheel_input(event: InputEvent) -> bool:
	var dir := 0
	if event.is_action_pressed("hand_next"):
		dir = 1
	elif event.is_action_pressed("hand_prev"):
		dir = -1
	if dir == 0:
		return false
	if player.ui_open or player.typing or player.dead:
		return true
	# The mouse's own buttons only while the game has the mouse (as the
	# swing, Bow.need_capture).
	if event is InputEventMouseButton and Bow.need_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return true
	if not _counts(event, dir):
		return true
	var hand := wheel_hand()
	if Input.is_action_pressed("other_hand"):
		hand = tab_hand()
		# Turning the wheel with Tab held shows the strip at once.
		tab_s = maxf(tab_s, float(_tab().get("show_after_s", 0.15)))
	cycle(hand, dir)
	return true


## One step a notch (hands.json wheel_step): a mouse wheel's event (factor
## at least notch) steps each; a trackpad's or a smooth wheel's small ones
## add up to one step a stroke, the stroke ending when the wheel rests
## reset_s or turns the other way. A key or a button bound here steps each
## press.
func _counts(event: InputEvent, dir: int) -> bool:
	if not Controls.is_wheel(event):
		return true
	var W: Dictionary = D.get("wheel_step", {})
	var notch := float(W.get("notch", 1.0))
	var f := (event as InputEventMouseButton).factor
	if f <= 0.0:
		f = notch
	if dir != _wheel_dir or _clock - _wheel_at > float(W.get("reset_s", 0.25)):
		_wheel_sum = 0.0
		_spent = false
	_wheel_dir = dir
	_wheel_at = _clock
	if f >= notch * 0.99:
		return true
	if _spent:
		return false
	_wheel_sum += f
	if _wheel_sum >= notch * 0.99:
		_spent = true
		return true
	return false


## Each physics frame (CrawlerPlayer): the clock, and how long Tab has
## been held.
func update(delta: float) -> void:
	_clock += delta
	if Input.is_action_pressed("other_hand") and not player.ui_open and not player.typing:
		tab_s += delta
	else:
		tab_s = 0.0
	if left >= 0 and left_item().is_empty():
		# Gone from the strip (thrown): the hand is empty.
		left = -1


## Is the strip up (HandStrip)? Once Tab has been held show_after_s (a tap
## shows nothing), or at once when the wheel turns with it held.
func strip_showing() -> bool:
	var t := _tab()
	return bool(t.get("shows_strip", true)) and tab_s > 0.0 and tab_s >= float(t.get("show_after_s", 0.15))


## What the strip shows for `hand`: [entries, chosen]. An entry is an
## item, drawn by its icon, or {} for an empty hand; chosen is the one in
## hand.
func strip_for(hand: String) -> Array:
	var entries: Array = []
	var chosen := 0
	if hand == "left":
		var strip: Array = player.inventory.strip
		var now := left if not left_item().is_empty() else -1
		for i in left_choices():
			if int(i) == now:
				chosen = entries.size()
			entries.append(strip[i] if int(i) >= 0 else {})
	else:
		var now := right_now()
		for w in right_choices():
			if w == now:
				chosen = entries.size()
			match str(w):
				"torch":
					entries.append(player.torch.item())
				"spear":
					var sp = player.inventory.worn_in("melee")
					entries.append(sp if sp is Dictionary else {"kind": "spear"})
				_:
					entries.append({})
	return [entries, chosen]
