extends SceneTree
## Fire pots (design 6 Oct night §FA.3, §FA.4; prompt 60; FirePots), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/fire_pot_check.gd
## Asserts:
##  1. the data: fire_pots.json wired (no [NOT WIRED YET] on _help.about),
##     items.json has the fire_pot;
##  2. carrying: F9's dev pots fill the strip to carry_max and no further;
##     Tab and the wheel cycle the left hand through every pot and empty;
##  3. no lit torch, no pot: with no torch, or an unlit one, holding left
##     click lights nothing, throws nothing, flares nothing; the torch never
##     swings while a pot is in the left hand;
##  4. lighting: with the torch lit, the wick catches at light_anim_s, not
##     before; let go before it catches and nothing is lit;
##  5. the throw: scripted throws, looking level on flat ground, land at the
##     charged range (min_m, half, max_m) within half a metre, where the aim's
##     arc said; a throw is as loud as a swing; a pot in the air is a flare;
##  6. the fuse: held past fuse_s it goes off in your hand
##     (cook_off_in_hand; Mike, 7 Oct), not before: one burst where your
##     hand is, the pot gone from your hand and your pack, nothing thrown,
##     and one hit (fire:pot_in_hand), never two; in the air with fuse
##     left it bursts when the fuse runs out;
##  6b. your own pot hurts you (hurts_you; Mike, 7 Oct): a burst within
##     hurts_you_m of your body is one hit (fire:pot), one further off
##     isn't, nor one behind stone; thrown at the floor at your feet
##     (looking straight down) it is one hit, thrown level (4 m out) it
##     isn't; its burning patch never hurts you;
##  7. tar: a hit on a skeleton (a stand-in until prompt 58: residents.json
##     skeleton fire_hp and oil_scale) takes the burst, shows the
##     crosshair's X (Reticle.hit; Mike, 7 Oct; a burst on nothing
##     doesn't), and burns at burn_dps:
##     at 0 fire_hp it burns out and is gone; a sturdier one burns for burn_s
##     and then stops; a thrown pot meets a target in its path; the patch on
##     the floor burns what stands in it for floor_patch_s, then its light
##     goes out and char is left;
##  8. light oil: one burst, nothing after, no patch; oil_scale counts (the
##     ghost's light_oil 1.5);
##  9. a boss (a stand-in: drive_off) hit by a pot is driven off for
##     vs_boss.drives_off_s and comes back, never killed, never burnt; and
##     the real one, prompt 49's snake: a pot at its head and one by its
##     tail drive it down below, the chase off, out of the pots' reach
##     while it's down there; it comes up after drives_off_s and never
##     dies; a burning tar patch it lies in drives it off; the lit wick
##     alone (the torch smothered) gives you away to it; a burst is heard
##     within burst_heard_m of it, not past it;
##  9b. the real skeletons (prompt 58's Resident): fire targets with
##     residents.json's fire_hp; tar on a sleeping one wakes it, burns it
##     down and it is gone, its chase off (Harm no longer counts it); light
##     oil burns an awake one out at once; awake, one 12 m off (past its own
##     sight and its torch sight) sees nothing with your torch out, sees the
##     lit wick as your flame, not at 28 m, and hears a burst 30 m off it,
##     not 46 m off;
## 10. it gives you away: the lit wick is seen within flare_seen_m, not past
##     it, not through stone; the burst is heard within burst_heard_m
##     (bursts_since, NoiseEvents);
## 11. fire spreads: a burst by the hearth room's reed mat sets it alight,
##     it burns, chars and never burns again;
## 12. the found pot: over 30 tombs it lies in a side room, never the hearth
##     room, the heart or the spine (prompt 46's, or the way to the heart);
##     in the scene on the floor of its room; right click takes it;
## 13. one firelight (§EX.6): every light of the pot's fire is the hearth's
##     amber, reddening only as it dies; it never lights a cold holder and
##     no torch catches from it (relights_holders null).

const SEEDS := 30

var fails := 0
var main: CrawlerMain
var fp: FirePots
var p: CrawlerPlayer


## A resident stand-in (prompt 58's skeletons): the fire-target socket.
## (Named so as not to hide the real one, Resident, queue 58.)
class ResidentStandIn:
	extends Node3D
	var fire_hp := 3.0
	var fire_creature := "skeleton"
	var burnt := false

	func burn_out() -> void:
		burnt = true
		queue_free()


## A boss stand-in (prompt 49's snake; named so as not to hide the real
## one, Boss): driven off into the dark for the time given, then back to
## where it was.
class BossStandIn:
	extends Node3D
	var fire_creature := "giant snake"
	var home := Vector3.ZERO
	var t := 0.0
	var back_at := -1.0
	var drives := 0
	var last_s := 0.0
	var returned := 0

	func drive_off(seconds: float, from: Vector3) -> void:
		drives += 1
		last_s = seconds
		back_at = t + seconds
		var away := global_position - from
		away.y = 0.0
		global_position += (away.normalized() if away.length() > 0.01 else Vector3.RIGHT) * 30.0

	func _physics_process(delta: float) -> void:
		t += delta
		if back_at > 0.0 and t >= back_at:
			global_position = home
			back_at = -1.0
			returned += 1


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	WorldSave.read_only = true
	# The tomb's skeletons sleep through this check (design §FE; queue 58).
	Residents.stay_asleep = true
	Bow.need_capture = false
	_data()
	_found_layouts()
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	main = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	await _frames(10)
	while not main.baked:
		await process_frame
	fp = main.fire_pots
	p = main.player
	ok(fp != null and FirePots.instance == fp, "the crawler has its fire pots (FirePots)")
	_skeletons_ready()
	# The far floor first: from here on you stand on it, far from every
	# burst that isn't meant to reach you (hurts_you).
	_floor()
	await _found_in_scene()
	_stand(Vector3(0.0, -300.0, 0.0))
	await _frames(5)
	await _spread()
	await _no_holder()
	await _carry()
	await _no_torch_no_pot()
	await _lighting()
	await _throws()
	await _fuse()
	await _self_harm()
	await _tar()
	await _light_oil()
	await _boss()
	await _gives_away()
	await _real_snake()
	await _real_skeletons()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	var about := str((FirePots.D.get("_help", {}) as Dictionary).get("about", ""))
	ok(not about.begins_with("[NOT WIRED YET"), "fire_pots.json is wired (no [NOT WIRED YET] on _help.about)")
	ok((Inventory.data().get("kinds", {}) as Dictionary).has("fire_pot"), "items.json has the fire pot")
	ok(str(FirePots.D.get("vessel", "")) == "clay_pot", "the vessel is a clay pot (§FJ.5)")


## A floor of its own far below the tomb, to throw on.
func _floor() -> void:
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 2.0, 4000.0)
	cs.shape = box
	ground.add_child(cs)
	ground.position = Vector3(0.0, -301.0, 0.0)
	main.add_child(ground)


func _stand(at: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	p.spawn_flat(at, yaw, pitch)


func _torch(lit: bool) -> void:
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	if lit and not p.torch.lit():
		p.torch.light()
	elif not lit and p.torch.lit():
		p.torch.put_out("stowed")


## A pot of `oil` in the left hand (made if none of that oil is carried).
func _pot_in_hand(oil := "tar") -> Dictionary:
	var want: Dictionary = {}
	for it in fp.pots_carried():
		if str(it.get("oil", "")) == oil and not bool(it.get("lit", false)):
			want = it
	if want.is_empty():
		if fp.pots_carried().size() >= FirePots.carry_max():
			fp._remove(fp.pots_carried()[0])
		fp.give(oil)
		want = fp.pots_carried()[-1]
	fp.left = want
	return want


func _carry() -> void:
	_stand(Vector3(0.0, -300.0, 0.0))
	await _frames(10)
	for it in fp.pots_carried():
		fp._remove(it)
	var n := fp.give_dev()
	ok(n == FirePots.carry_max() and fp.pots_carried().size() == FirePots.carry_max(), "F9 (dev_items) fills the strip to carry_max (%d pots)" % n)
	ok(not fp.give("tar") and fp.give_dev() == 0, "no pot past carry_max (%d)" % FirePots.carry_max())
	var oils := {}
	for it in fp.pots_carried():
		oils[str(it.oil)] = true
	ok(oils.has("tar") and oils.has("light_oil"), "the dev pots are of both oils, to try them")
	fp.left = {}
	var seen := []
	for k in FirePots.carry_max() + 1:
		fp.cycle_left(1)
		var cur := fp.in_left()
		var fresh := true
		for s in seen:
			if is_same(s, cur):
				fresh = false
		if fresh:
			seen.append(cur)
	ok(seen.size() == FirePots.carry_max() + 1 and fp.in_left().is_empty(), "Tab and the wheel: the left hand goes through all %d pots and back to empty" % FirePots.carry_max())


func _no_torch_no_pot() -> void:
	_stand(Vector3(0.0, -300.0, 0.0))
	await _frames(5)
	for lit_case in ["no torch", "an unlit torch"]:
		if lit_case == "no torch":
			p.weapon = "hands"
		else:
			_torch(false)
		var pot := _pot_in_hand("tar")
		var swings := p.torch.swings
		var throws := fp.throws
		Input.action_press("shoot")
		await _frames(90)
		var st := fp.state
		var fl := FirePots.flares().size()
		Input.action_release("shoot")
		await _frames(5)
		ok(st == "idle" and fl == 0 and not bool(pot.get("lit", false)) and fp.throws == throws and fp.in_left() == pot, "%s in the right hand: holding left click lights nothing, throws nothing (§FA.3: no lit torch, no pot)" % lit_case)
		ok(p.torch.swings == swings, "%s: the torch doesn't swing while a pot is in the left hand" % lit_case)


func _lighting() -> void:
	_stand(Vector3(0.0, -300.0, 0.0))
	await _frames(5)
	_torch(true)
	var pot := _pot_in_hand("tar")
	var anim := FirePots.light_anim_s()
	# Let go before it catches.
	Input.action_press("shoot")
	await _frames(int(anim * 60.0 * 0.5))
	var mid := fp.state
	Input.action_release("shoot")
	await _frames(3)
	ok(mid == "lighting" and fp.state == "idle" and not bool(pot.get("lit", false)) and fp.in_left() == pot, "let go before the wick catches: the hands part, nothing lit, the pot still in hand")
	# Hold through.
	var swings := p.torch.swings
	Input.action_press("shoot")
	await _frames(int(anim * 60.0) - 4)
	var before := fp.state
	var lit_before := bool(pot.get("lit", false))
	await _frames(8)
	ok(before == "lighting" and not lit_before and fp.state == "aiming" and bool(pot.get("lit", false)), "held with the torch lit, the wick catches at light_anim_s (%.2f s), not before" % anim)
	var fl := FirePots.flares()
	ok(fl.size() == 1 and str(fl[0].from) == "hand", "the lit wick in your hand is a flare (%d)" % fl.size())
	ok(p.torch.swings == swings, "lighting the pot doesn't swing the torch")
	ok(fp.arc_end.is_finite(), "aiming shows where the lob will land (the arc ends at %s)" % str(fp.arc_end))
	Input.action_release("shoot")
	await _frames(2)
	await _wait_landed(400)


## Until every pot in the air has burst (or `n` frames).
func _wait_landed(n: int) -> void:
	for i in n:
		if fp.flying.is_empty():
			return
		await physics_frame


## Light a pot and charge `k` (0..1) of the way, then let go: the launch's
## [from, velocity, charge] and the arc's end before the release.
func _throw_k(k: float, oil := "tar") -> Dictionary:
	_torch(true)
	_pot_in_hand(oil)
	Input.action_press("shoot")
	for i in 120:
		await physics_frame
		if fp.state == "aiming":
			break
	var cs := float(FirePots.throw_d().get("charge_s", 0.8))
	await _frames(int(round(k * cs * 60.0)))
	await process_frame
	var arc := fp.arc_end
	Input.action_release("shoot")
	await _frames(2)
	var l := fp.last_launch.duplicate()
	var noise := p.noise_level
	await _wait_landed(600)
	return {"launch": l, "arc": arc, "landing": fp.last_landing.duplicate(), "noise": noise}


func _throws() -> void:
	var T := FirePots.throw_d()
	var lo := float(T.get("min_m", 4.0))
	var hi := float(T.get("max_m", 14.0))
	var all_ok := true
	var arc_ok := true
	for k in [0.0, 0.5, 1.0]:
		_stand(Vector3(0.0, -300.0, 0.0), 0.3, 0.0)
		await _frames(8)
		var r := await _throw_k(k)
		var l: Array = r.launch
		if l.is_empty() or (r.landing as Dictionary).is_empty():
			all_ok = false
			print("  k %.1f: no throw" % k)
			continue
		var from: Vector3 = l[0]
		var at: Vector3 = r.landing.pos
		var want := lerpf(lo, hi, float(l[2]))
		var got := Vector2(at.x - from.x, at.z - from.z).length()
		print("  charge %.2f: lands %.2f m out (charged range %.2f m), %s after %.2f s; the arc said %s" % [float(l[2]), got, want, r.landing.why, float(r.landing.life), str(r.arc)])
		if absf(got - want) > 0.5 or str(r.landing.why) != "world":
			all_ok = false
		if not (r.arc as Vector3).is_finite() or (r.arc as Vector3).distance_to(at) > 0.6:
			arc_ok = false
	ok(all_ok, "scripted throws looking level land at the charged range (%.0f to %.0f m) within half a metre" % [lo, hi])
	ok(arc_ok, "the aim's arc ends where the pot lands")
	# Loud: crouched you're quiet, and the throw is as loud as a swing.
	_stand(Vector3(0.0, -300.0, 0.0), 0.3, 0.0)
	Input.action_press("crouch")
	await _frames(20)
	var quiet := p.noise_level
	var rq := await _throw_k(0.0)
	Input.action_release("crouch")
	ok(quiet < Fists.NOISE * 0.5 and float(rq.noise) >= Fists.NOISE * 0.5 - 0.001, "a throw is as loud as a swing: crouched %.2f, the throw %.3f (a swing's %.3f)" % [quiet, float(rq.noise), Fists.NOISE * 0.5])
	# A pot in the air is a flare.
	_stand(Vector3(0.0, -300.0, 0.0), 0.3, -0.6)
	await _frames(5)
	_torch(true)
	_pot_in_hand("tar")
	Input.action_press("shoot")
	await _frames(int(FirePots.light_anim_s() * 60.0) + 4)
	Input.action_release("shoot")
	await _frames(3)
	var air := 0
	for f in FirePots.flares():
		if str(f.from) == "air":
			air += 1
	ok(air == 1, "a pot in the air is a flare (its wick alight)")
	await _wait_landed(600)


func _fuse() -> void:
	_stand(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	var harm := Harm.instance
	ok(harm != null and FirePots.cooks_off(), "cook_off_in_hand is on (Mike, 7 Oct), and the crawler counts hits (Harm)")
	if harm == null:
		return
	harm.reset()
	await _frames(45)
	_torch(true)
	_pot_in_hand("light_oil")
	var carried := fp.pots_carried().size()
	var bursts := FirePots.bursts_since(0).size()
	var cooks := fp.cook_offs
	var selfs := fp.self_hits
	var throws0 := fp.throws
	var landed0 := harm.landed
	var fuse_s := float(FirePots.D.get("fuse_s", 3.0))
	Input.action_press("shoot")
	# Just short of the fuse: still in your hand, whole.
	await _frames(int((FirePots.light_anim_s() + fuse_s) * 60.0) - 8)
	var before_ok := fp.state == "aiming" and FirePots.bursts_since(0).size() == bursts and harm.landed == landed0
	var eye := p.camera().global_position
	await _frames(16)
	var b := FirePots.bursts_since(0)
	Input.action_release("shoot")
	await _frames(3)
	var at: Vector3 = b[-1].pos if b.size() > bursts else Vector3.INF
	ok(before_ok and fp.cook_offs == cooks + 1 and b.size() == bursts + 1 and at.is_finite() and at.distance_to(eye) < 1.0, "held past fuse_s (%.1f s from the catch) it bursts in your hand (%.2f m from your eye), not before" % [fuse_s, at.distance_to(eye) if at.is_finite() else -1.0])
	ok(fp.state == "idle" and fp.in_left().is_empty() and fp.pots_carried().size() == carried - 1 and fp.throws == throws0 and fp.flying.is_empty(), "the pot is gone: the left hand empty, one fewer in the pack (%d), nothing thrown" % fp.pots_carried().size())
	ok(harm.landed == landed0 + 1 and fp.self_hits == selfs + 1 and harm.cause == "fire:pot_in_hand", "and it is one hit, never two (Harm %d -> %d, %s)" % [landed0, harm.landed, harm.cause])
	harm.reset()
	await _frames(45)
	# With fuse left, in the air: it bursts when the fuse runs out.
	var tp := ThrownPot.new()
	fp.add_child(tp)
	var ex: Array[RID] = [p.get_rid()]
	tp.launch(fp, Vector3(0.0, -260.0, 20.0), Vector3(1.0, 0.0, 0.0), "light_oil", 0.5, ex)
	fp.flying.append(tp)
	await _wait_landed(200)
	ok(str(fp.last_landing.get("why", "")) == "fuse" and absf(float(fp.last_landing.get("life", 0.0)) - 0.5) < 0.05, "in the air with fuse left, it bursts as the fuse runs out (after %.2f s, %s)" % [float(fp.last_landing.get("life", 0.0)), str(fp.last_landing.get("why", ""))])


## A box of stone (the world's layer) `size` big, centred `at`.
func _stone(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PropCollision.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	main.add_child(body)
	body.global_position = at
	return body


## Your own pot hurts you (hurts_you, hurts_you_m; Mike, 7 Oct).
func _self_harm() -> void:
	var harm := Harm.instance
	var within := float(FirePots.D.get("hurts_you_m", 1.0))
	ok(harm != null and bool(FirePots.D.get("hurts_you", false)), "hurts_you is on (Mike, 7 Oct): your own pot can hurt you")
	if harm == null:
		return
	var at := Vector3(0.0, -300.0, 0.0)
	_stand(at, 0.0, 0.0)
	await _frames(20)
	harm.reset()
	await _frames(45)
	var l0 := harm.landed
	var s0 := fp.self_hits
	# Beside you at knee height, within reach: one hit, and the tar's patch
	# burning round your feet after it, none.
	fp.burst(p.global_position + Vector3(FirePots.YOU_R + within * 0.5, 0.5, 0.0), "tar", null, Vector3.UP)
	await _frames(2)
	var near_ok := harm.landed == l0 + 1 and fp.self_hits == s0 + 1 and harm.cause == "fire:pot"
	await _frames(180)
	var patch_ok := harm.landed == l0 + 1 and fp.self_hits == s0 + 1
	harm.reset()
	await _frames(int(float(FirePots.oil("tar").get("floor_patch_s", 12.0)) * 60.0))
	_stand(at, 0.0, 0.0)
	await _frames(10)
	# Further off: nothing.
	fp.burst(p.global_position + Vector3(FirePots.YOU_R + within + 0.5, 0.5, 0.0), "light_oil", null, Vector3.UP)
	await _frames(2)
	var far_ok := harm.landed == l0 + 1 and fp.self_hits == s0 + 1
	ok(near_ok and far_ok, "your own burst %.2f m from you is one hit (fire:pot); one %.2f m off isn't (hurts_you_m %.1f)" % [within * 0.5, within + 0.5, within])
	ok(patch_ok, "standing in its burning tar after, nothing more: its patch never hurts you")
	# Behind stone: a wall between you and a burst within reach.
	var wall := _stone(Vector3(0.1, 3.0, 3.0), p.global_position + Vector3(FirePots.YOU_R + 0.25, 1.5, 0.0))
	await _frames(2)
	fp.burst(p.global_position + Vector3(FirePots.YOU_R + 0.55, 0.8, 0.0), "light_oil", null, Vector3.UP)
	await _frames(2)
	ok(harm.landed == l0 + 1 and fp.self_hits == s0 + 1, "nor one %.2f m off behind a wall" % 0.55)
	wall.queue_free()
	await _frames(45)
	# Thrown at the floor at your feet, looking straight down: one hit.
	_stand(at, 0.0, -1.5)
	await _frames(10)
	var r := await _throw_k(0.0)
	var land: Vector3 = (r.landing as Dictionary).get("pos", Vector3.INF)
	var d_feet := Vector2(land.x - p.global_position.x, land.z - p.global_position.z).length() if land.is_finite() else -1.0
	ok(harm.landed == l0 + 2 and fp.self_hits == s0 + 2 and str((r.landing as Dictionary).get("why", "")) == "world", "thrown at the floor at your feet (looking straight down) it bursts %.2f m from them, and that is one hit (Harm %d)" % [d_feet, harm.landed - l0])
	harm.reset()
	await _frames(45)
	# Thrown level: it lands 4 m out, and nothing.
	_stand(at, 0.0, 0.0)
	await _frames(10)
	var r2 := await _throw_k(0.0)
	ok(harm.landed == l0 + 2 and fp.self_hits == s0 + 2 and str((r2.landing as Dictionary).get("why", "")) == "world", "thrown level it lands out of reach (%s), and nothing" % str(((r2.landing as Dictionary).get("pos", Vector3.ZERO) as Vector3).snapped(Vector3.ONE * 0.1)))
	harm.reset()
	await _frames(45)


## A stand-in resident hung `at` (far from any floor unless asked), its
## fire_hp and kind.
func _resident(at: Vector3, hp: float, kind := "skeleton") -> ResidentStandIn:
	var r := ResidentStandIn.new()
	r.fire_hp = hp
	r.fire_creature = kind
	r.add_to_group(FirePots.TARGET_GROUP)
	main.add_child(r)
	r.global_position = at
	return r


func _tar() -> void:
	var S: Dictionary = (FirePots.RES.get("creatures", {}) as Dictionary).get("skeleton", {})
	var hp := float(S.get("fire_hp", 3.0))
	var o := FirePots.oil("tar")
	var burst := float(o.get("burst", 1.0))
	var dps := float(o.get("burn_dps", 0.5))
	var burn_s := float(o.get("burn_s", 8.0))
	# A skeleton, high above any floor (no patch under it): the burst, then
	# the tar burning until its fire_hp is gone.
	var sk := _resident(Vector3(40.0, -200.0, 0.0), hp)
	var x0 := Reticle.hits
	fp.burst(FirePots.center_of(sk), "tar", sk, Vector3.UP)
	await _frames(1)
	ok(Reticle.hits == x0 + 1, "a burst that catches a creature shows the crosshair's X, once (Reticle.hit; Mike, 7 Oct: %d)" % (Reticle.hits - x0))
	var after_burst := sk.fire_hp
	var stuck: Variant = sk.get_meta("pot_stuck") if sk.has_meta("pot_stuck") else null
	ok(absf(after_burst - (hp - burst)) < 0.02 and stuck is PotFire, "tar on a skeleton: the burst takes %.1f of its %.1f fire_hp and the tar sticks" % [burst, hp])
	var need := (hp - burst) / maxf(dps, 0.001)
	var gone_at := -1.0
	for i in int((need + 1.5) * 60.0):
		await physics_frame
		if not is_instance_valid(sk):
			gone_at = (i + 1) / 60.0
			break
	ok(gone_at > need - 0.2 and gone_at < need + 0.3, "it burns at burn_dps (%.1f a second) and at 0 fire_hp burns out and is gone (after %.2f s; %.2f s expected)" % [dps, gone_at, need])
	# A sturdier one burns for burn_s, then stops.
	var big := _resident(Vector3(44.0, -200.0, 0.0), 20.0)
	fp.burst(FirePots.center_of(big), "tar", big, Vector3.UP)
	await _frames(int(burn_s * 60.0) + 30)
	var at_end := big.fire_hp
	await _frames(120)
	var want := 20.0 - burst - dps * burn_s
	ok(absf(at_end - want) < 0.1 and absf(big.fire_hp - at_end) < 0.001, "a sturdier one burns for burn_s (%.0f s): %.2f fire_hp left (%.2f expected), and then no more" % [burn_s, big.fire_hp, want])
	big.queue_free()
	# A thrown pot meets a target in its path.
	_stand(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	var T := FirePots.throw_d()
	var range_m := lerpf(float(T.get("min_m", 4.0)), float(T.get("max_m", 14.0)), 0.5)
	var hand := fp.hand_point()
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var tgt := _resident(Vector3(hand.x, -300.0, hand.z) + fwd * (range_m - 1.2), 50.0)
	var r := await _throw_k(0.5)
	ok(str(r.landing.get("why", "")) == "target" and tgt.fire_hp < 50.0, "a thrown pot bursts on a creature in its path (%s, fire_hp %.1f)" % [str(r.landing.get("why", "")), tgt.fire_hp])
	tgt.queue_free()
	await _frames(2)
	# The patch on the floor.
	var foot := Vector3(60.0, -300.0, 0.0)
	var n_patch := _count("patch")
	var x1 := Reticle.hits
	fp.burst(foot + Vector3.UP * 0.3, "tar", null, Vector3.UP)
	await _frames(2)
	ok(Reticle.hits == x1, "a burst on nothing shows no X")
	var patch: PotFire = null
	for f in fp.fires:
		if is_instance_valid(f) and (f as PotFire).kind == "patch" and (f as PotFire).foot.distance_to(foot) < 0.5:
			patch = f
	ok(patch != null and _count("patch") == n_patch + 1 and absf(patch.radius - float(o.get("patch_radius_m", 1.2))) < 0.01, "tar leaves a patch burning on the floor (%.1f m round)" % float(o.get("patch_radius_m", 1.2)))
	var walker := _resident(foot + Vector3(0.5, 0.0, 0.0), 20.0)
	walker.set_meta("fire_center_y", 0.9)
	var lights_ok := true
	var e_mid := 0.0
	var e_late := 0.0
	var life := float(o.get("floor_patch_s", 12.0))
	var col0 := Torch.fire_color()
	for i in int((life + 1.0) * 60.0):
		await physics_frame
		if i == int(life * 0.4 * 60.0) and is_instance_valid(patch):
			e_mid = patch.light().light_energy
		if i == int(life * 0.92 * 60.0) and is_instance_valid(patch):
			e_late = patch.light().light_energy
			var c := patch.light().light_color
			if c.b / maxf(c.r, 1e-4) > col0.b / col0.r + 1e-4 or c.g / maxf(c.r, 1e-4) > col0.g / col0.r + 1e-4:
				lights_ok = false
	var took := 20.0 - walker.fire_hp
	ok(absf(took - dps * life) < 0.25, "the patch burns what stands in it at burn_dps for floor_patch_s (%.2f taken over %.0f s)" % [took, life])
	ok(not is_instance_valid(patch) and e_late < e_mid * 0.6 and lights_ok, "the patch is a light that goes out: dimmer and redder at the end (%.2f from %.2f), then gone" % [e_late, e_mid])
	var charred := false
	for c in fp.chars:
		if is_instance_valid(c) and (c as Node3D).global_position.distance_to(foot) < 0.3:
			charred = true
	ok(charred, "char is left on the stone where it burnt")
	walker.queue_free()


func _count(kind: String) -> int:
	var n := 0
	for f in fp.fires:
		if is_instance_valid(f) and (f as PotFire).kind == kind:
			n += 1
	return n


func _light_oil() -> void:
	var o := FirePots.oil("light_oil")
	var burst := float(o.get("burst", 4.0))
	var r := _resident(Vector3(80.0, -200.0, 0.0), 10.0)
	fp.burst(FirePots.center_of(r), "light_oil", r, Vector3.UP)
	await _frames(1)
	var after := r.fire_hp
	await _frames(240)
	ok(absf(after - (10.0 - burst)) < 0.02 and absf(r.fire_hp - after) < 0.001 and not r.has_meta("pot_stuck"), "light oil: one burst of %.1f and nothing after (%.1f left)" % [burst, r.fire_hp])
	r.queue_free()
	var foot := Vector3(90.0, -300.0, 0.0)
	var n_patch := _count("patch")
	fp.burst(foot + Vector3.UP * 0.2, "light_oil", null, Vector3.UP)
	await _frames(30)
	ok(_count("patch") == n_patch, "light oil leaves no patch")
	var sk := _resident(Vector3(84.0, -200.0, 0.0), float((((FirePots.RES.get("creatures", {}) as Dictionary).get("skeleton", {})) as Dictionary).get("fire_hp", 3.0)))
	fp.burst(FirePots.center_of(sk), "light_oil", sk, Vector3.UP)
	await _frames(3)
	ok(not is_instance_valid(sk), "light oil burns a skeleton out at once (burst %.1f against fire_hp 3)" % burst)
	var gh := _resident(Vector3(88.0, -200.0, 0.0), 10.0, "ghost")
	var sc := FirePots.oil_scale(gh, "light_oil")
	fp.burst(FirePots.center_of(gh), "light_oil", gh, Vector3.UP)
	await _frames(1)
	ok(absf((10.0 - gh.fire_hp) - burst * sc) < 0.02 and sc != 1.0, "oil_scale counts: light oil does %.1fx to a ghost (%.1f taken)" % [sc, 10.0 - gh.fire_hp])
	gh.queue_free()


func _boss() -> void:
	var b := BossStandIn.new()
	b.add_to_group(FirePots.TARGET_GROUP)
	main.add_child(b)
	b.global_position = Vector3(120.0, -200.0, 0.0)
	b.home = b.global_position
	var s := float((FirePots.D.get("vs_boss", {}) as Dictionary).get("drives_off_s", 30.0))
	fp.burst(FirePots.center_of(b), "tar", b, Vector3.UP)
	await _frames(2)
	ok(b.drives == 1 and absf(b.last_s - s) < 0.01 and b.global_position.distance_to(b.home) > 10.0, "a boss hit by a pot is driven off into the dark for drives_off_s (%.0f s)" % s)
	ok(not b.has_meta("pot_stuck") and not b.has_meta("fire_taken"), "nothing burns a boss down: no tar sticks, no fire taken (§FA.4)")
	fp.burst(b.global_position + Vector3.UP * 0.9, "light_oil", b, Vector3.UP)
	await _frames(2)
	ok(b.drives == 1, "already going: a second pot doesn't drive it again")
	await _frames(int(s * 60.0) + 30)
	ok(b.returned == 1 and is_instance_valid(b) and not FirePots.burnt_out(b), "it comes back later and never dies")
	b.queue_free()


func _gives_away() -> void:
	_stand(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	await _frames(5)
	var seen_m := float((FirePots.D.get("gives_away", {}) as Dictionary).get("flare_seen_m", 25.0))
	var heard_m := float((FirePots.D.get("gives_away", {}) as Dictionary).get("burst_heard_m", 40.0))
	var space := p.get_world_3d().direct_space_state
	var near := p.global_position + Vector3(0.0, 1.2, seen_m - 3.0)
	var far := p.global_position + Vector3(0.0, 1.2, seen_m + 3.0)
	var hid := p.global_position + Vector3(seen_m - 10.0, 1.2, 0.0)
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.6, 6.0, 6.0)
	cs.shape = bx
	wall.add_child(cs)
	main.add_child(wall)
	wall.global_position = p.global_position + Vector3(4.0, 1.5, 0.0)
	await _frames(3)
	_torch(true)
	ok(FirePots.flare_seen_from(near, space).is_empty(), "the torch alone is no flare (the creatures' own sees_flame_m reads it)")
	_pot_in_hand("tar")
	Input.action_press("shoot")
	await _frames(int(FirePots.light_anim_s() * 60.0) + 4)
	await process_frame
	ok(not FirePots.flare_seen_from(near, space).is_empty(), "a creature %.0f m off with a clear line sees the wick's flare (flare_seen_m %.0f)" % [seen_m - 3.0, seen_m])
	ok(FirePots.flare_seen_from(far, space).is_empty(), "one %.0f m off doesn't" % (seen_m + 3.0))
	ok(FirePots.flare_seen_from(hid, space).is_empty(), "one behind stone doesn't")
	var last := 0
	var bs := FirePots.bursts_since(0)
	if not bs.is_empty():
		last = int(bs[-1].id)
	var noise_last := 0
	Input.action_release("shoot")
	await _frames(2)
	await _wait_landed(600)
	var heard := FirePots.bursts_since(last)
	ok(heard.size() == 1 and absf(float(heard[0].heard_m) - heard_m) < 0.01, "the burst is heard within burst_heard_m (%.0f m; bursts_since)" % heard_m)
	var noises := NoiseEvents.since(noise_last)
	var loud := false
	for e in noises:
		if absf(float(e.radius) - heard_m) < 0.01:
			loud = true
	ok(loud, "and on the game's hearing (NoiseEvents), %.0f m round it" % heard_m)
	wall.queue_free()


func _spread() -> void:
	var mat: Dictionary = {}
	for b in fp.burnables:
		if str(b.tag) == "rushes":
			mat = b
	ok(not mat.is_empty() and "rushes" in (FirePots.D.get("spreads_to", []) as Array), "the hearth room's reed mat is tagged to burn (rushes)")
	if mat.is_empty():
		return
	fp.burst((mat.pos as Vector3) + Vector3(0.3, 0.4, 0.0), "light_oil", null, Vector3.UP)
	await _frames(2)
	ok(str(mat.state) == "burning", "a burst by it sets it alight (fire spreads to what burns)")
	var burn_s := float(((FirePots.D.get("spread", {}) as Dictionary).get("burn_s", {}) as Dictionary).get("rushes", 15.0))
	await _frames(int((burn_s + 0.5) * 60.0))
	var charred := false
	for c in fp.chars:
		if is_instance_valid(c) and Vector2((c as Node3D).global_position.x - (mat.pos as Vector3).x, (c as Node3D).global_position.z - (mat.pos as Vector3).z).length() < 0.2:
			charred = true
	ok(str(mat.state) == "burnt" and charred, "it burns spread.burn_s (%.0f s) and lies charred" % burn_s)
	var n := _count("spread")
	fp.burst((mat.pos as Vector3) + Vector3(0.0, 0.4, 0.0), "light_oil", null, Vector3.UP)
	await _frames(2)
	ok(_count("spread") == n and str(mat.state) == "burnt", "and never burns again")


## The pot's fire never lights a cold holder, and no torch catches from it.
func _no_holder() -> void:
	var cold: Node3D = null
	for h in main.fires.holders:
		if not FireStore.is_lit(h) and str(h.get_meta("fire_holder")) != "sconce":
			cold = h
			break
	if cold == null:
		for h in main.fires.holders:
			if not FireStore.is_lit(h):
				cold = h
				break
	ok(cold != null, "a cold holder to try")
	if cold == null:
		return
	var at := cold.global_position
	var foot := fp.floor_under(at + Vector3.UP * 0.5)
	fp.burst(at + Vector3.UP * 0.4, "tar", null, Vector3.UP)
	await _frames(3)
	var lights_ok := true
	var want := Torch.fire_color()
	for f in fp.fires:
		if is_instance_valid(f) and (f as PotFire).light() != null and (f as PotFire).gutter() == 0.0 and (f as PotFire).kind != "flash":
			if not (f as PotFire).light().light_color.is_equal_approx(want):
				lights_ok = false
	ok(lights_ok, "one firelight: the pot's fire lights in the hearth's amber (#%s)" % want.to_html(false))
	for i in 240:
		FireStore.tick(self, 1.0 / 60.0, at)
		await physics_frame
	ok(not FireStore.is_lit(cold), "tar burning on a cold %s never lights it (relights_holders null)" % str(cold.get_meta("fire_holder")))
	var near_p := foot if foot.is_finite() else at
	ok(not Torch.flame_near(self, near_p + Vector3.UP * 0.4, 0.8), "and no torch catches from the pot's fire (not a flame the swing takes from)")
	# Let it burn out before the rest.
	await _frames(int(float(FirePots.oil("tar").get("floor_patch_s", 12.0)) * 60.0) + 30)


func _found_layouts() -> void:
	var placed := 0
	var off_spine := true
	var kinds_ok := true
	var ends_ok := true
	for s in SEEDS:
		var lay := TombKit.layout(1000 + s * 7919)
		var room := FirePots.found_room_of(lay)
		if room < 0:
			continue
		placed += 1
		var pc: Dictionary = lay.pieces[room]
		if str(pc.kind) != "room" or str(pc.get("room_kind", "")) in ["hearth", "heart"]:
			kinds_ok = false
		if room in FirePots.spine_of(lay):
			off_spine = false
			print("  seed %d: the found pot's room %d is on the spine" % [lay.seed, room])
		var any_end := false
		for q in lay.pieces:
			if str(q.kind) == "room" and not str(q.get("room_kind", "")) in ["hearth", "heart"] and not int(q.id) in FirePots.spine_of(lay) and (q.doors as Array).size() == 1:
				any_end = true
		if any_end and (pc.doors as Array).size() != 1:
			ends_ok = false
	ok(placed >= int(SEEDS * 0.9), "a found pot in %d of %d tombs" % [placed, SEEDS])
	ok(kinds_ok, "always in a side room: never the hearth room or the heart")
	ok(off_spine, "never on the spine (prompt 46's; until it's in, the way from the hearth room to the heart)")
	ok(ends_ok, "in a dead end where the tomb has one")


func _found_in_scene() -> void:
	for i in 10:
		if fp.found != null:
			break
		await physics_frame
	var f := fp.found
	ok(f != null, "the found pot lies in its room (piece %d)" % fp.found_room)
	if f == null:
		return
	var at := f.global_position
	ok(TombKit.piece_at(main.lay, at + Vector3.UP * 0.2) == fp.found_room, "in the side room the layout chose")
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at - Vector3.UP * 0.5)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	ok(not hit.is_empty() and absf((hit.position as Vector3).y - at.y) < 0.06, "standing on the floor")
	_stand(at + Vector3(4.0, 0.0, 0.0))
	await _frames(5)
	ok(not fp.take_found(), "out of reach, right click doesn't take it")
	for it in fp.pots_carried():
		fp._remove(it)
	_stand(at + Vector3(0.9, 0.0, 0.0))
	await _frames(5)
	var oil := str(f.get_meta("oil", ""))
	ok(fp.take_found() and fp.found == null and fp.pots_carried().size() == 1 and str(fp.pots_carried()[0].oil) == oil, "right click by it takes it into the pack (%s)" % oil)
	for it in fp.pots_carried():
		fp._remove(it)


## A spot `d` m from the snake's head in its own dark (boss_check's).
func _beside_snake(b: Boss, d: float) -> Vector3:
	for k in 16:
		var a := TAU * k / 16.0
		var q := b.head + Vector3(cos(a), 0.0, sin(a)) * d
		q.y = b._floor_y(q)
		var id := b.ground.node_at(q)
		if id >= 0 and b.ground.is_ground(id) and (id == b.node or not b.ground.link(id, b.node).is_empty()) and not b._blocked(b.head + Vector3(0, 0.6, 0), q + Vector3(0, 0.6, 0), false):
			var pc: Dictionary = b.lay.pieces[int(b.ground.nodes[id].piece)]
			var aa := Delves.along_across(pc, Vector2(q.x, q.z))
			if aa.x > 0.4 and aa.x < float(pc.len) - 0.4 and absf(aa.y) < float(pc.half) - 0.45:
				return q
	return Vector3.INF


func _tick_snake(b: Boss, secs: float, stop: Callable = Callable()) -> float:
	var t := 0.0
	while t < secs:
		b.tick(1.0 / 60.0)
		t += 1.0 / 60.0
		if stop.is_valid() and bool(stop.call()):
			break
	return t


## Hold it coiled where it lies, calm (its noticing still runs).
func _hold_snake(b: Boss) -> void:
	b._let_go("check")
	b._calm()
	b.state = "coil"
	b.coiling = false
	b.coil_left = 999.0
	b.route = PackedVector3Array()
	b.route_i = 0
	b.speed = 0.0


## The real snake (prompt 49's Boss) through the fire-target socket.
func _real_snake() -> void:
	var b: Boss = main.get("boss")
	ok(b != null, "the tomb has its snake (prompt 49)")
	if b == null:
		return
	for i in 120:
		if b.started:
			break
		await physics_frame
	b.auto = false
	# What it heard before now, it heard.
	b._hears_burst()
	ok(b.is_in_group(FirePots.TARGET_GROUP) and FirePots.is_boss(b), "the snake is a fire target, and a boss: driven off, never burnt down")
	if b.state == "below":
		_tick_snake(b, 60.0, func() -> bool: return b.state != "below")
	_hold_snake(b)
	var spot := Vector3.INF
	for d in [6.0, 5.0, 4.0, 3.0]:
		spot = _beside_snake(b, d)
		if spot != Vector3.INF:
			break
	ok(spot != Vector3.INF, "a spot in the snake's dark a few metres from it")
	if spot == Vector3.INF:
		return
	_torch(false)
	fp.left = {}
	var to := b.head - spot
	p.spawn_flat(spot, atan2(-to.x, -to.z), 0.0)
	await _frames(3)
	_tick_snake(b, 1.0)
	var calm := not b.noticed
	# The lit wick alone: the pot caught off the torch, then the torch
	# smothered.
	Bow.need_capture = false
	_torch(true)
	var pot := _pot_in_hand("tar")
	Input.action_press("shoot")
	fp._catch(pot)
	p.torch.put_out("smothered")
	await _frames(2)
	_tick_snake(b, 0.5)
	var by_wick := b.noticed and b.pursuit.on and not p.torch.lit()
	fp._set_state("idle")
	fp.left = {}
	Input.action_release("shoot")
	fp._remove(pot)
	ok(calm and by_wick, "your torch out, it hadn't noticed you %.1f m off; with only the pot's lit wick in its sight it does, and the chase is on" % spot.distance_to(b.head))
	# A burst heard: within burst_heard_m of it, and past it (high over
	# the tomb, so it is only heard).
	var heard_m := float((FirePots.D.get("gives_away", {}) as Dictionary).get("burst_heard_m", 40.0))
	_hold_snake(b)
	_tick_snake(b, 1.0)
	var away := Vector3(1.0, 0.0, 0.0)
	fp.burst(b.head + away * (heard_m + 6.0) + Vector3(0.0, 40.0, 0.0), "light_oil", null, Vector3.UP)
	_tick_snake(b, 0.5)
	var far_heard := b.noticed
	fp.burst(b.head + away * (heard_m - 10.0) + Vector3(0.0, 40.0, 0.0), "light_oil", null, Vector3.UP)
	_tick_snake(b, 0.5)
	ok(not far_heard and b.noticed, "a burst %.0f m off it hears (burst_heard_m %.0f) and hunts you; one %.0f m off it doesn't" % [heard_m - 10.0, heard_m, heard_m + 6.0])
	# You away (out of its dark), for the rest.
	_stand(Vector3(0.0, -300.0, 0.0))
	await _frames(3)
	_hold_snake(b)
	_tick_snake(b, 0.5)
	# A pot at its head: driven off, the chase off, out of reach below.
	var s := float((FirePots.D.get("vs_boss", {}) as Dictionary).get("drives_off_s", 30.0))
	var driven := b.driven
	b.pursuit.notice(false)
	fp.burst(b.fire_center(), "tar", b, Vector3.UP)
	ok(b.state == "below" and b.driven == driven + 1 and not b.pursuit.on and is_instance_valid(b), "a pot at the snake's head drives it off down below (%s), the chase off" % b.state)
	ok(FirePots.distance_to(b, b.fire_center()) == INF, "down there no pot reaches it")
	b.remove_meta("pot_driven_until")
	var up_after := _tick_snake(b, s + 20.0, func() -> bool: return b.state != "below")
	ok(b.state != "below" and up_after >= s - 0.1 and not b.state in ["release", "lair", "gone"] and is_instance_valid(b), "it comes up again after drives_off_s (%.0f s; up after %.1f s), back on its rounds, never dead" % [s, up_after])
	# By its tail: the body counts, not only the head (it slithers out
	# first, so all of it lies on the floor).
	_tick_snake(b, 6.0)
	var tail_at := Vector3.INF
	var length := float(b.sub("body").get("length_m", 9.0))
	var i_tail := mini(b.trail.size() - 1, int(length * 0.85 / Boss.TRAIL_STEP))
	if i_tail > 0:
		tail_at = (b.trail[i_tail] as Vector3) + Vector3(0.0, 0.3, 0.0)
	var gap := tail_at.distance_to(b.fire_center()) if tail_at.is_finite() else -1.0
	driven = b.driven
	if tail_at.is_finite() and b.state != "below":
		fp.burst(tail_at, "light_oil", null, Vector3.UP)
	ok(gap > float(FirePots.oil("light_oil").get("splash_m", 3.0)) + 0.3 and b.driven == driven + 1 and b.state == "below", "a pot by its tail, %.1f m from its head, drives it off too (its whole length is in reach)" % gap)
	b.remove_meta("pot_driven_until")
	_tick_snake(b, s + 20.0, func() -> bool: return b.state != "below")
	# A burning tar patch it lies in.
	_tick_snake(b, 1.0)
	driven = b.driven
	var under := fp.floor_under(b.fire_center())
	if under.is_finite() and b.state != "below":
		var patch := PotFire.patch(fp, under, "tar")
		fp.fires.append(patch)
		await _frames(3)
	ok(b.driven == driven + 1, "a burning tar patch under it drives it off")
	b.remove_meta("pot_driven_until")
	b.auto = true


## Before any pot is thrown: every skeleton a fire target, with
## residents.json's fire_hp.
func _skeletons_ready() -> void:
	var rs: Residents = main.get("residents")
	if rs == null:
		ok(false, "the tomb has its skeletons (prompt 58)")
		return
	var hp0 := float(rs.creature("skeleton").get("fire_hp", 3.0))
	var all_in := not rs.all.is_empty()
	for r in rs.all:
		if not r.is_in_group(FirePots.TARGET_GROUP) or absf(r.fire_hp - hp0) > 0.001 or r.fire_creature != "skeleton":
			all_in = false
	ok(all_in, "every skeleton (%d) is a fire target with residents.json's fire_hp (%.1f)" % [rs.all.size(), hp0])


## The real skeletons (prompt 58's Resident) through the fire-target socket.
func _real_skeletons() -> void:
	var rs: Residents = main.get("residents")
	ok(rs != null and rs.all.size() >= 3, "the tomb has its skeletons (prompt 58; %d)" % (rs.all.size() if rs != null else 0))
	if rs == null or rs.all.size() < 3:
		return
	var hp0 := float(rs.creature("skeleton").get("fire_hp", 3.0))
	_torch(false)
	_stand(Vector3(0.0, -300.0, 0.0))
	await _frames(3)
	# Tar on one lying asleep: it wakes, burns down, and is gone.
	var r: Resident = null
	for c in rs.all:
		if c.state == Resident.REST:
			r = c
			break
	ok(r != null, "a skeleton asleep to try")
	if r != null:
		var burst := float(FirePots.oil("tar").get("burst", 1.0))
		fp.burst(r.fire_center(), "tar", r, Vector3.UP)
		var woke := r.awake()
		var hp1 := r.fire_hp
		var chased := r.pursuit.on
		var gone_s := -1.0
		for i in int(10.0 * 60.0):
			await physics_frame
			if not is_instance_valid(r):
				gone_s = (i + 1) / 60.0
				break
		ok(woke and chased and absf(hp1 - (hp0 - burst)) < 0.02, "tar on a sleeping skeleton: it wakes and climbs out, burning (fire_hp %.1f after the burst), the chase on" % hp1)
		var counted := false
		if Harm.instance != null:
			for w in Harm.instance.pursuers:
				if not is_instance_valid(w):
					counted = true
		ok(gone_s > 0.0 and gone_s <= float(FirePots.oil("tar").get("burn_s", 8.0)) and not rs.all.has(r) and not counted, "it burns down to nothing and is gone (after %.2f s), off the tomb's list, its chase off" % gone_s)
	# Light oil on one awake: out at once.
	var r2: Resident = null
	for c in rs.all:
		if c.state == Resident.REST:
			r2 = c
			break
	if r2 != null:
		r2.wake()
		await _frames(2)
		fp.burst(r2.fire_center(), "light_oil", r2, Vector3.UP)
		await _frames(2)
		ok(not is_instance_valid(r2), "light oil burns an awake skeleton out at once")
	# Its senses, on the open floor: a skeleton up and hunting, 12 m off
	# (past its own sight, sees_you_m, and its torch sight, sees_flame_m).
	var r3: Resident = null
	for c in rs.all:
		if is_instance_valid(c):
			r3 = c
			break
	ok(r3 != null, "a skeleton to sense with")
	if r3 == null:
		return
	r3.set_physics_process(false)
	r3._enter(Resident.HUNT)
	r3.hears_burst()
	var seen_m := float((FirePots.D.get("gives_away", {}) as Dictionary).get("flare_seen_m", 25.0))
	var heard_m := float((FirePots.D.get("gives_away", {}) as Dictionary).get("burst_heard_m", 40.0))
	r3.global_position = Vector3(0.0, -300.0, -12.0)
	_stand(Vector3(0.0, -300.0, 0.0), 0.0, 0.0)
	_torch(false)
	await _frames(4)
	var nothing := rs.sense(r3)
	Bow.need_capture = false
	_torch(true)
	var pot := _pot_in_hand("tar")
	Input.action_press("shoot")
	fp._catch(pot)
	p.torch.put_out("smothered")
	await _frames(3)
	var by_wick := rs.sense(r3)
	r3.global_position = Vector3(0.0, -300.0, -(seen_m + 3.0))
	var far_wick := rs.sense(r3)
	fp._set_state("idle")
	fp.left = {}
	Input.action_release("shoot")
	fp._remove(pot)
	ok(nothing == "" and by_wick == "flame" and far_wick == "", "awake 12 m off, your torch out: it senses nothing (%s); the pot's lit wick it sees as your flame (%s); %.0f m off it doesn't (%s)" % [nothing if nothing != "" else "-", by_wick, seen_m + 3.0, far_wick if far_wick != "" else "-"])
	r3.global_position = Vector3(0.0, -300.0, -12.0)
	fp.burst(r3.eye() + Vector3(heard_m + 6.0, 0.0, 0.0), "light_oil", null, Vector3.UP)
	var far_burst := rs.sense(r3)
	fp.burst(r3.eye() + Vector3(heard_m - 10.0, 0.0, 0.0), "light_oil", null, Vector3.UP)
	var near_burst := rs.sense(r3)
	ok(far_burst == "" and near_burst == "hearing", "a burst %.0f m off it hears (%s); %.0f m off it doesn't (%s)" % [heard_m - 10.0, near_burst, heard_m + 6.0, far_burst if far_burst != "" else "-"])
	r3.give_up("check")
	r3.set_physics_process(true)
