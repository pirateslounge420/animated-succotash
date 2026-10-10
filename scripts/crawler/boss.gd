class_name Boss
extends Node3D
## The dungeon's boss (design 6 Oct §EY; data/bosses.json): one in every
## dungeon (rule.one_per_dungeon), the dark given a body (§BA, §CU), not a
## fight: no health bar, nothing to kill (§ET.1). Built (§EY.8 step 1):
## the rule, with one boss, the snake (bosses.desert, the one marked
## first; it stands in the tomb as the test while the tomb's world is
## open). The other bosses wait for their worlds.
##
## A body, never a ghost (Mike's note of 7 Oct: "creatures shouldnt 'sink'
## into the stone- only ghosts/phantoms should have the ability to ohase
## thru walls and floors and ceilings"; "it wont actually despawn and
## respawn places, it needa to physically maneuvar around the ruins to make
## it anywheres"): it goes everywhere at one of its speeds, frame by frame,
## along the floor (the creatures' grid, TombNav, by the dimmest way: the
## light, LightField) or through its own tunnels under the floors, its body
## lying along the path its head took; it never goes into the stone,
## vanishes or comes up anywhere it didn't travel to.
##
##   its ground  the rooms and corridor stretches not yet relit (BossGround,
##               rule.ground unlit), worked out again on every relight. Its
##               prowling goes only through its ground and never into a lit
##               room or stretch (rule.relit_closes_room); the hearth room
##               is never its ground.
##   its rounds  (pattern slither) at speed_mps from one dead-end room of
##               its dark to another, coiling in each for coil_s (coils_in
##               dead_ends); now and then through its own tunnels (below),
##               from one side way to another.
##   noticing    (rule.notice) your carried flame in its sight within
##               sees_flame_m, a sprint (or anything as loud: a swing that
##               lands on it) within hears_sprint_m, or you within feels_m
##               whatever your light; then it hunts you at hunt_mps (Mike's
##               note of 7 Oct: as fast as your walk or faster, 4.6 against
##               your 4.3; your sprint, 5.6, outruns it). The chase is a
##               Pursuit (§FD, bosses.json gives_up: too far, out of its
##               sight and hearing too long, your torch going out), so while
##               it has you, you don't heal (Harm).
##   the edge    (Mike's note of 7 Oct, amending §FD: "the snake can follow
##               you but not get close to the fire"; residents.json
##               rules.chase_light_cap) hunting you, its strike landed or
##               not, it goes only where the light on the floor is at most
##               the cap (TombNav's capped grid), so it comes as far as the
##               edge of the light and no further, and there it rears its
##               head forward into the glow (peek_m, "show just enough of
##               their face/body near the fire") and watches you (watch_s),
##               then gives you up. It strikes you only within its reach of
##               where it may stand: by the hearth or a relit torch you are
##               safe, at the light's dim edge you are not.
##   your torch  (rule.torch_in_hand delay) with your torch lit it hangs at
##               the edge of its circle (torch_delay.hang_m), reared and
##               hissing, for torch_delay.hang_s before it closes; with the
##               torch out it closes straight in.
##   the strike  within its strike block's reach (§FA, CreatureStrike, the
##               piece every creature strikes with): the wind-up (reared
##               back, jaws opening, the hiss), the lunge, the draw back.
##               Rearing, lunging and drawing back, it keeps coming at up
##               to hunt_mps (never past the light's cap; round a corner by
##               its way to you), so a walker it has caught can't step out
##               of it and a sprinter can. A lunge that reaches you is one hit
##               (contact.strike_is_hit; Harm, harm.json: its breath between
##               hits holds). A lit torch swung into its wind-up staggers it
##               (torch.json stagger): it recoils back along its body. Three
##               hits is "Good night", and you wake at the hearth
##               (CrawlerMain) with every light you lit still burning
##               (contact.relit_kept); it lets you go where it is and goes
##               on with its rounds from there.
##   the light   relight the room or stretch it is in (outside a chase) and
##               it leaves at once for the nearest dark (rule.leaves_lit_room)
##               at leave_mps: under the light through its tunnels where
##               they lead there, else across the lit rooms on the dimmest
##               way, at the edges of the light (TombNav, LightField); the
##               hearth room only when there is no other way. Given you up
##               in the light at the edge, it is back in the dark within
##               residents.json rules.back_to_dark_s.
##   its tunnels (Mike's note of 7 Oct: "they may have their own tunnels-
##               this can be the case for the snake"; bosses.json
##               bosses.<key>.tunnels; BossGround.place_tunnels) holes at the
##               foot of the side ways' walls, one in its lair room, joined
##               under the floors: it goes in head first, its body
##               following, travels hidden at its speed (a tunnel takes its
##               length over that speed), and comes out of the other hole
##               (should the far hole's room be lit while it is inside, it
##               turns back under the floor and comes out where it went in);
##               while inside its tell is muffled (tunnels.muffle_db and
##               muffle_hz) and it notices nothing.
##   fire pots   (design §FA.3, §FA.4, Mike's note of 7 Oct: "a pot cant
##               kill a boss but will stun it/cause it to retreat to its
##               cave temporarily"; FirePots) a pot that bursts on or by it
##               (splash_m from any part of its body, or a burning tar
##               patch it crawls into) stuns it: it reels and lies dazed for
##               stun_s, no strike, no chase; then it flees to its lair hole
##               at flee_mps (through its tunnels or on the dimmest way),
##               goes down it into its den and stays there, breathing, out
##               of the pots' reach, for fire_pots.json vs_boss.drives_off_s;
##               then it comes up out of the hole onto its rounds. It is
##               never burnt down or killed. The lit wick gives you away as
##               your flame does, out to gives_away.flare_seen_m with a clear
##               line to it, and a burst within burst_heard_m of it is heard
##               like a sprint: either sets it hunting you.
##   the release when the dungeon's last holder catches (rule.last_light
##               to_lair): wherever it is, it flees to its lair at flee_mps
##               (through its tunnels or across the lit tomb on the dimmest
##               way), the long cry going with it (release.cry_to_lair), and
##               down its hole into the den for good; the tomb's small
##               sounds come back (release.bed_returns: the drips, hushed
##               while it prowled); the log's one line (release.log_line).
##               Then it is in its hole for good, breathing, heard within
##               lair.breathing_heard_m.
##   its tell    scales dragging on stone (BossSounds), on a 3D player at
##               its body, heard well before you can see it; quieter while
##               it lies coiled. No name on screen (§BA).
##   its body    baked sprites (BossBody): a head and a chain of body
##               lengths, each where the head was, so it bends through the
##               corridors, lies in a coil, and slides into a hole after its
##               head.
##   its pool    (design 9 Oct §FM.1, Mike: "a group of different behaviors
##               that each boss can cycle through on RNG level"; queue 65;
##               data/boss_pool.json; BossPool, BossState) what it does next
##               is drawn at random from its own states, by weight, never
##               the same one twice running, on dice of the pool's own (not
##               the game seed), each for its dwell_s. 'rounds' is all of
##               the above, wrapped and not rewritten (rounds_tick), so a
##               pool of 'rounds' alone plays exactly as before. The rule's
##               own moments are never a state's (RULE_MOMENTS: the chase,
##               the torch's hold, the strike, leaving the light, a fire
##               pot, you taken, the last light): the state in charge is
##               over when one begins, and the pool is asked again only once
##               it is free (its strike ready, out of its tunnels). A state
##               strikes only by begin_strike (the strike as built, its tell
##               and wind-up first, after your torch's hold), never stays in
##               the light (lit round it or walked into it, it leaves as
##               built) and never waits on the way out (on_way_out,
##               EXIT_WAIT_S).
##   the snake's (design 9 Oct §FM.2, Mike's four; queue 66; BossStalk and
##               scripts/crawler/boss_states/): freeze_watched (you look at
##               it from far off: it stops dead, camouflaged toward the
##               stone, never gone; it may cut in the moment you first
##               catch sight of it, BossState.cuts_in), doorway_watch,
##               observe_then_behind and coil_ambush. Those that stalk you
##               out of your light spend your flame's delay lying back
##               beyond its edge (begin_strike's held_s); coil_ambush,
##               walked away from, lets you go (let_go).

static var B: Dictionary = Tuning.table("bosses")
static var RULE: Dictionary = B.get("rule", {})
static var CONTACT: Dictionary = B.get("contact", {})
static var LAIR: Dictionary = B.get("lair", {})
static var RELEASE: Dictionary = B.get("release", {})

## The trail's spacing (m): the head's place is kept every this far.
const TRAIL_STEP := 0.08
## The neck: how many body lengths rise with the head.
const NECK := 9
## The body's height off the floor where rays look for what's in its way.
const KNEE := 0.3
## However it hurries (back to the dark within back_to_dark_s), never
## faster than this (m/s).
const MOST_MPS := 6.0
## Its den under the lair's mouth (out of sight, so its body can turn
## round in it): a shaft this deep, then turns of this radius going down
## this much more, long enough to take its whole body (about 10 m of den
## for its 9 m).
const DEN_SHAFT_M := 1.0
const DEN_R_M := 0.45
const DEN_TURNS := 3.5
const DEN_DROP_M := 1.2
## How dear a lit node is to its way home when it flees (BossGround: a
## dark way, or its tunnels, are worth this many metres more).
const FLEE_LIT_COST := 150.0
## The dark it hangs in its tunnels' mouths and its lair's (unlit, like
## the airways' slots).
const VOID := Color(0.004, 0.005, 0.012)
## A route point inside the rock: in a tunnel, or down its den.
const HID_TUNNEL := 1
const HID_DEN := 2
## The rule's own moments (boss_pool.json rule.never_breaks; §FM.1): the
## chase (hunting you, the torch's hold, the strike, watching at the
## light's edge), leaving the light, a fire pot (stunned, fleeing to its
## hole, down it, rising), you taken, the last light. No state of its pool
## is in charge during one, and the pool is never asked.
const RULE_MOMENTS := ["hunt", "hang", "strike", "watch", "leave", "stunned", "flee", "den", "rise", "held", "release", "lair", "gone"]
## A state of its pool may keep it still on the way out (on_way_out) at
## most this long (s), then it is over (never_blocks_exit); the way out
## reaches this far (m) round the middle of a doorway onto it; still is
## slower than this (m/s).
const EXIT_WAIT_S := 0.5
const EXIT_CLEAR_M := 2.0
const STILL_MPS := 0.3
## No state may come now (none can enter): its built behaviour meanwhile,
## and the pool asked again this much later (s).
const POOL_RETRY_S := 1.0
## The draws kept in draw_log (tools).
const DRAW_LOG := 512

## Tools: no pool at all, its tick the built behaviour exactly as before
## queue 65 (the pool's check runs the two and compares the routes).
static var pool_off := false

var key := ""
var def: Dictionary = {}
var name_text := "boss"
var lay: Dictionary = {}
var fires: CrawlerFires
var player: CrawlerPlayer
var ground: BossGround
var body: BossBody
## The creatures' floor grid and the light on it (Residents builds them;
## CrawlerMain hands them over once the stone is in the physics world).
var nav: TombNav
var light: LightField
## Off: the checks drive tick() themselves.
var auto := true
## Placed and going (a physics frame after build()).
var started := false

## coil, prowl, hunt, hang, strike, watch (at the light's edge), leave,
## stunned (a fire pot), flee (to its hole), den (down it), rise (up out
## of it), held (you are taken), release (the last light, to its hole),
## lair (down it for good), gone (no lair: home in its tunnels).
var state := "coil"
## The head's place on the route's middle line, and with the slither's
## sway (on the floor); the way it faces (flat).
var base := Vector3.ZERO
var head := Vector3.ZERO
var dir := Vector3.FORWARD
var route := PackedVector3Array()
## Which of the route's points are inside the rock: 0 on the floor,
## HID_TUNNEL in one of its tunnels, HID_DEN down its hole.
var route_hidden := PackedByteArray()
var route_i := 0
## The head's places, newest first, TRAIL_STEP apart: the body lies on it.
var trail: Array = []
var travelled := 0.0
var node := -1
var speed := 0.0
## The round: the room it is making for, coiling there (coil_left s).
var target := -1
var coiling := false
var coil_left := 0.0
## The head raised (m), the lunge's reach now (m; at the light's edge its
## head reared forward into the glow, peek_m), the jaws.
var lift := 0.0
var lunge := 0.0
var mouth_open := false
var _sway := 0.0

## Noticing: whether it has you and where it last had you; whether it
## perceives you now (its last look); the chase (§FD, Pursuit).
var noticed := false
var last_seen := Vector3.ZERO
var perceives := false
var pursuit: Pursuit
## Its strike (§FA, CreatureStrike), at its head.
var strike: CreatureStrike
## The torch's delay used up (s), and whether it has struck since it last
## found you.
var hang_t := 0.0
var struck := false
## The stagger's reel under way (the strike's stagger_frame) and which way
## it goes: back along its body, or straight away from the swing.
var _reel_frame := -1
var _reel_back := true
var watch_t := 0.0
var _notice_t := 0.0
var _replan_t := 0.0
## Where you were when it last found its way to you, and whether that way
## stops at the light's edge short of you.
var _hunt_to := Vector3.INF
var _edge := false
var _hiss_t := 0.0
var _lit_n := -1
var _rng := RandomNumberGenerator.new()

## The lair (TombKit: lay.lair), its node.
var lair: Dictionary = {}
var lair_node := -1
var released := false
var _bed_t := -1.0
## How fast it is leaving the light now (m/s; _leave).
var _leave_mps := 4.0
## Stunned (s left), and how long it stays down its hole (a fire pot's
## drives_off_s), and how long it has left there.
var stun_t := 0.0
var _den_s := 30.0
var den_t := 0.0
## A light changed while it was in a tunnel: it decides once it is out.
var _after_tunnel := false
## It turned back in a tunnel (the far hole lit while it was inside): on its
## rounds afresh once it is out where it went in.
var _turned_back := false

var _tell: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D
var _cry: AudioStreamPlayer3D
var _tell_cutoff := 5000.0
## The tomb's small sounds (the drips' loop; CrawlerMain), hushed while it
## prowls, and their own level.
var bed: AudioStreamPlayer
var bed_db := -20.0

## The checks: times it walked into a lit node of its own accord (never);
## lit nodes it went into chasing you (only where the light is under the
## cap), and crossing (leaving the light, fleeing home); its steps in the
## hearth room (crossing it when there was no other way); the brightest
## light it stood in chasing you; the hits it landed.
var lit_entries := 0
var chase_lit_entries := 0
var cross_lit_entries := 0
var hearth_steps := 0
var chase_light_peak := 0.0
var hits_landed := 0
## Its tunnels (tools): transits finished, and the last one ({"s" (time
## inside), "m" (metres inside), "straight" (m between the two mouths),
## "from", "to" (mouths)}); times it turned back inside one (the far hole
## lit); its own clock.
var transits := 0
var last_transit := {}
var turned_back := 0
var clock := 0.0
var _inside := false
var _in_t0 := 0.0
var _in_m0 := 0.0
var _in_at := Vector3.ZERO
## Fire pots (FirePots): times a pot drove it off, and the last burst it
## listened for.
var driven := 0
var _burst_id := 0

## Its behaviour pool (§FM.1; BossPool; null with pool_off); the state in
## charge now ("" between: one of the rule's own moments, or before the
## first draw) and its unit; how long it has left (its dwell); whether the
## pool is to be asked at the next free tick; the state before.
var pool: BossPool
var behaviour := ""
var _unit: BossState
var _dwell_left := 0.0
var _pool_due := true
var _prev_behaviour := ""
## Tools: the draws, oldest first, the last DRAW_LOG of them ({"id", "state"
## (its own state then), "strike" (its strike's), "tunnel", "clock"}); how
## the states in charge ended (their dwell, themselves, the rule's moments,
## and the guards: the light, the way out).
var draw_log: Array = []
var states_ended := {"dwell": 0, "done": 0, "rule": 0, "light": 0, "exit": 0, "swap": 0}
## The way out's guard: how long a state has kept it still there, and where
## it was last tick; the doorways onto the way out (on_way_out).
var _exit_wait := 0.0
var _guard_at := Vector3.INF
var _way_out_doors: Array = []
## The way out's guard tripped: on its built rounds until it is off the way
## out, and only then the pool asked again.
var _clear_way_out := false
## A state of its pool cutting in (queue 66; BossState.cuts_in), looked for
## this often (s); each such state's needs as last seen (id -> bool), so it
## cuts in only on their turning true.
const CUT_IN_S := 0.2
var _cut_t := 0.0
var _cut_was: Dictionary = {}
## Its camouflage (§FM.2, freeze_watched; boss_pool.json camouflage): the
## share its sprites have moved toward the stone, easing to camo_want over
## CAMO_EASE_S, never above camouflage.max_blend (BossBody.set_camouflage).
const CAMO_EASE_S := 0.8
var camo := 0.0
var camo_want := 0.0
## It has let you go (coil_ambush, walked away from): for this long (s) its
## rounds don't take you up by sight or hearing (feels_m still does), and
## the states of its pool that go after you may not come
## (BossStalk.may_stalk).
var let_go_t := 0.0
## Tools: the level its tell is easing to now (dB; -INF silent).
var tell_want := -INF


## The boss of this dungeon (§EY.8: the tomb's world is open, so the one
## marked first stands in): its key in bosses.json bosses.
static func pick() -> String:
	var bs: Dictionary = B.get("bosses", {})
	for k in bs:
		if bool((bs[k] as Dictionary).get("first", false)):
			return str(k)
	return "desert" if bs.has("desert") else ""


func build(p_lay: Dictionary, p_fires: CrawlerFires, p_player: CrawlerPlayer, p_bed: AudioStreamPlayer = null) -> void:
	name = "Boss"
	lay = p_lay
	fires = p_fires
	player = p_player
	bed = p_bed
	if bed != null:
		bed_db = bed.volume_db
	key = pick()
	def = (B.get("bosses", {}) as Dictionary).get(key, {})
	name_text = str(def.get("creature", "boss"))
	_rng.seed = hash([int(lay.seed), "boss"])
	ground = BossGround.build(lay, true)
	lair = lay.get("lair", {})
	if not lair.is_empty():
		lair_node = ground.node_at(lair.pos)
	body = BossBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(def)
	_tell = Audio3D.make("boss_tell", self, "Tell")
	_tell.stream = BossSounds.stream("scales_loop", _rng.randi())
	_tell_cutoff = _tell.attenuation_filter_cutoff_hz
	_hiss = Audio3D.make("strike_tell", self, "Hiss")
	# Its strike (CreatureStrike, bosses.json bosses.<key>.strike): driven
	# from here (tick), so the checks' stepped clock drives it too.
	strike = CreatureStrike.new()
	strike.name = "Strike"
	add_child(strike)
	strike.setup(sub("strike"), name_text)
	strike.set_physics_process(false)
	strike.target = player
	strike.on_hit = _on_strike_hit
	strike.struck.connect(func(_landed: bool) -> void: struck = true)
	pursuit = Pursuit.new(self, sub("gives_up"))
	# A fire pot's burst can reach it (FirePots' fire-target socket).
	add_to_group(FirePots.TARGET_GROUP)
	_breath = Audio3D.make("boss_breath", self, "Breath")
	_breath.stream = BossSounds.stream("breath_loop", _rng.randi())
	_breath.max_distance = float(LAIR.get("breathing_heard_m", 12.0))
	_cry = Audio3D.make("boss_cry", self, "Cry")
	_cry.stream = BossSounds.stream("retreat", _rng.randi())
	if not lair.is_empty():
		# Below the floor, down the hole.
		_breath.position = (lair.pos as Vector3) - Vector3(0.0, 1.2, 0.0)
		_mouth(lair)
	_hole_mouths()
	# Its behaviour pool (§FM.1): its own states (boss_pool.json pools), on
	# dice of the pool's own; the first is drawn at its first free tick.
	pool = null if pool_off else BossPool.for_boss(key, int(lay.seed))
	_way_out_doors = _find_way_out_doors()
	_refresh(true)
	_begin.call_deferred()


## Start once the tomb's stone is in the physics world (its rays see it).
func _begin() -> void:
	if is_inside_tree():
		await get_tree().physics_frame
	_start_far()
	started = true


static func _void_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = VOID
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The hole's mouth (TombBuild._lair_hole lays its broken edge): a black
## void a hand over the floor, unlit like the airways' slots, so nothing of
## the floor shows through it.
func _mouth(l: Dictionary) -> void:
	var c: Vector3 = l.pos
	var r := float(l.r)
	var mrng := RandomNumberGenerator.new()
	mrng.seed = hash([int(lay.seed), "lair_mouth"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var rim: Array = []
	for k in n:
		var a := TAU * k / n
		rim.append(Vector3(cos(a), 0.0, sin(a)) * r * mrng.randf_range(0.92, 1.08))
	for k in n:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(rim[(k + 1) % n])
		st.add_vertex(rim[k])
	var mi := MeshInstance3D.new()
	mi.name = "LairMouth"
	mi.mesh = st.commit()
	mi.material_override = _void_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = c + Vector3(0.0, 0.07, 0.0)


## Its tunnels' holes (TombBuild cuts them into the walls): the dark hung
## near the back of each, unlit, so a hole reads as a way into the black
## and its body is lost in it as it goes in.
func _hole_mouths() -> void:
	var holes: Array = (lay.get("tunnels", {}) as Dictionary).get("holes", [])
	var m := _void_mat()
	for hi in holes.size():
		var h: Dictionary = holes[hi]
		var n: Vector3 = h.n
		var u: Vector3 = h.u
		var c: Vector3 = (h.pos as Vector3) - n * (float(h.depth) - 0.04)
		var arch := TombBuild._arch(0.0, float(h.w) - 0.01, -0.01, float(h.h) - 0.005)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mid := Vector2(0.0, float(h.h) * 0.45)
		for k in arch.size():
			var p: Vector2 = arch[k]
			var q: Vector2 = arch[(k + 1) % arch.size()]
			for v: Vector2 in [mid, p, q]:
				st.add_vertex(u * v.x + Vector3.UP * v.y)
		var mi := MeshInstance3D.new()
		mi.name = "TunnelMouth%d" % hi
		mi.mesh = st.commit()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = c


## The numbers (bosses.json bosses.<key>), with first-guess defaults.
func num(k: String, dflt: float) -> float:
	return float(def.get(k, dflt))


func sub(k: String) -> Dictionary:
	var v: Variant = def.get(k, {})
	return v if v is Dictionary else {}


func _range(v: Variant, lo: float, hi: float) -> float:
	if v is Array and (v as Array).size() == 2:
		return _rng.randf_range(float(v[0]), float(v[1]))
	return _rng.randf_range(lo, hi)


## The fastest it ever moves (m/s): its hunt, its flight home, its leaving
## the light, and a hurry back to the dark (at most MOST_MPS): the checks'
## bound on a step.
func max_mps() -> float:
	return maxf(MOST_MPS, maxf(num("hunt_mps", 4.6), maxf(num("leave_mps", 4.0), num("flee_mps", 5.0))))


# --- Its place ------------------------------------------------------------------

## The floor's height under (x/z) `p`.
func _floor_y(p: Vector3) -> float:
	var id := ground.node_at(p)
	if id < 0:
		return p.y
	var pc: Dictionary = lay.pieces[int(ground.nodes[id].piece)]
	return Delves.floor_of(pc, Delves.along_across(pc, Vector2(p.x, p.z)).x)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Start (when the tomb is built, before you see it): coiled in the dark
## dead end farthest from the hearth room (or the farthest dark room).
func _start_far() -> void:
	var dist := _all_dist(_hearth_node())
	var best := -1
	var best_d := -INF
	for id in dist:
		if not ground.is_ground(int(id)) or str(ground.nodes[id].kind) != "room":
			continue
		var d := float(dist[id]) + (100.0 if ground.dead_end(int(id)) else 0.0)
		if d > best_d:
			best_d = d
			best = int(id)
	if best < 0:
		for id in dist:
			if ground.is_ground(int(id)) and float(dist[id]) > best_d:
				best_d = float(dist[id])
				best = int(id)
	if best < 0:
		# No dark left anywhere from the start: a kept dungeon whose every
		# light you relit (design §FK.2, CrawlerSave). It is home as the last
		# light left it (§EY.2), down its hole, with no cry and no log line.
		released = true
		_home()
		body.visible = false
		return
	_lie_coiled(best)


func _hearth_node() -> int:
	for n in ground.nodes:
		if bool(n.hearth):
			return int(n.id)
	return 0


## Every node's distance from `from` through anything.
func _all_dist(from: int) -> Dictionary:
	return ground._dijkstra(from, false, 0.0).dist


## Lying coiled in room `id` already: the whole body in the coil, the head
## on top.
func _lie_coiled(id: int) -> void:
	target = id
	var c := _coil_spot(id)
	var entry := _room_entry(id)
	var pts: Array = [entry]
	for p in _spiral(c, entry):
		pts.append(p)
	trail.clear()
	_trail_from(pts)
	base = pts[-1]
	head = base
	var last: Vector3 = pts[-1]
	var prev: Vector3 = pts[-2]
	dir = _flat(last - prev).normalized() if _flat(last - prev).length() > 0.001 else Vector3.FORWARD
	node = ground.node_at(base)
	state = "coil"
	coiling = false
	coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0)
	_set_route(PackedVector3Array())
	lift = 0.12
	_sway = 0.0


## Lying along corridor stretch `id`, head toward its far end (the checks
## lay it here; in play it gets anywhere only by going there).
func _lie_along(id: int) -> void:
	var n: Dictionary = ground.nodes[id]
	var pc: Dictionary = lay.pieces[int(n.piece)]
	var a0 := float(n.a0)
	var a1 := float(n.a1)
	var pts: Array = []
	var length := float(sub("body").get("length_m", 9.0))
	# Back along the corridor past the stretch's start if it is short (the
	# tail may lie in the next stretch).
	var k := a1 - 0.3 - length
	while k <= a1 - 0.3:
		pts.append(BossGround.point(pc, clampf(k, 0.0, float(pc.len)), 0.0))
		k += 0.25
	_trail_from(pts)
	base = pts[-1]
	head = base
	dir = _flat(BossGround.point(pc, a1, 0.0) - BossGround.point(pc, a0, 0.0)).normalized()
	if dir.length() < 0.5:
		dir = Vector3.FORWARD
	node = ground.node_at(base)
	target = id
	state = "coil"
	coiling = false
	coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0) * 0.5
	_set_route(PackedVector3Array())


## The trail laid along polyline `poly` (oldest first): newest first,
## TRAIL_STEP apart.
func _trail_from(poly: Array) -> void:
	var out: Array = []
	var carry := 0.0
	for i in range(poly.size() - 1):
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[i + 1]
		var l := a.distance_to(b)
		var s := carry
		while s < l:
			out.append(a.lerp(b, s / maxf(l, 1e-4)))
			s += TRAIL_STEP
		carry = s - l
	out.append(poly[-1])
	out.reverse()
	trail = out


## Where a room's way in is: just inside its first door (its only one in a
## dead end).
func _room_entry(id: int) -> Vector3:
	var n: Dictionary = ground.nodes[id]
	for l in n.links:
		if int(l.door) >= 0:
			var d: Dictionary = lay.doors[int(l.door)]
			var n3 := Vector3((d.n as Vector2).x, 0.0, (d.n as Vector2).y)
			var sgn := 1.0 if int(d.b) == int(n.piece) else -1.0
			var p: Vector3 = (l.via as Vector3) + n3 * sgn * 1.0
			p.y = _floor_y(p)
			return p
	return n.center


## The coil's middle in room `id`: clear of the walls, the doors, the
## fires on the floor, the lair's hole and whatever stands in the room
## (rays at the body's height), as far from its doors as it can be.
func _coil_spot(id: int) -> Vector3:
	var n: Dictionary = ground.nodes[id]
	var pc: Dictionary = lay.pieces[int(n.piece)]
	var r := float(sub("body").get("coil_r_m", 0.9))
	var best := n.center as Vector3
	var best_s := -INF
	var length := float(pc.len)
	var half := float(pc.half)
	for ka in 5:
		for kc in 3:
			var along := lerpf(r + 0.5, length - r - 0.5, ka / 4.0)
			var across := lerpf(-(half - r - 0.5), half - r - 0.5, kc / 2.0) if half > r + 0.5 else 0.0
			var p := BossGround.point(pc, along, across)
			var s := 0.0
			var ok := true
			for di in pc.doors:
				var d: Dictionary = lay.doors[di]
				var dd := Vector2(p.x, p.z).distance_to(d.p)
				if dd < r + 1.2:
					ok = false
				s += minf(dd, 8.0)
			for h in lay.holders:
				if int(h.piece) == int(pc.id) and str(h.kind) != "sconce":
					if Vector2(p.x, p.z).distance_to(Vector2((h.pos as Vector3).x, (h.pos as Vector3).z)) < r + 1.0:
						ok = false
			if not lair.is_empty() and int(lair.piece) == int(pc.id):
				if Vector2(p.x, p.z).distance_to(Vector2((lair.pos as Vector3).x, (lair.pos as Vector3).z)) < r + float(lair.r) + 0.4:
					ok = false
			if ok and is_inside_tree():
				ok = _clear_disk(p, r + 0.2)
			if not ok:
				s -= 1000.0
			if s > best_s:
				best_s = s
				best = p
	return best


## Is the floor round `c` clear `r` out, at the body's height: nothing
## standing there (a coffin, an urn of the dead's goods, the heart's box)
## and no wall within it?
func _clear_disk(c: Vector3, r: float) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = PropCollision.WORLD_LAYER
	for ring: float in [0.0, 0.5, 1.0]:
		var n := 1 if ring == 0.0 else 8
		for k in n:
			var a := TAU * (k + 0.5 * ring) / n
			q.position = c + Vector3(cos(a), 0.0, sin(a)) * r * ring + Vector3(0.0, KNEE, 0.0)
			if not space.intersect_point(q, 1).is_empty():
				return false
	for k in 8:
		var a := TAU * k / 8.0
		if _blocked(c + Vector3(0, KNEE, 0), c + Vector3(cos(a), 0.0, sin(a)) * r + Vector3(0, KNEE, 0)):
			return false
	return true


## The coil: from `entry`, round the middle `c` and in, long enough to
## take the whole body (a coiled snake lies on itself), each turn rising a
## little on the last.
func _spiral(c: Vector3, entry: Vector3) -> Array:
	var r0 := float(sub("body").get("coil_r_m", 0.9))
	var r1 := 0.28
	var want := float(sub("body").get("length_m", 9.0)) + 0.4
	var a := atan2(entry.z - c.z, entry.x - c.x)
	var sgn := 1.0 if (int(lay.seed) + target) % 2 == 0 else -1.0
	# The angle it takes to lay `want` metres from r0 in to r1.
	var theta := want / ((r0 + r1) * 0.5)
	var out: Array = []
	var steps := maxi(int(theta / 0.3), 8)
	for k in range(1, steps + 1):
		var u := float(k) / steps
		var r := lerpf(r0, r1, u)
		var ak := a + sgn * u * theta
		var p := c + Vector3(cos(ak), 0.0, sin(ak)) * r
		p.y = c.y + u * 0.26
		out.append(p)
	return out


# --- Moving ---------------------------------------------------------------------

## A new route (`hidden`: which of its points are inside the rock; none
## when left out).
func _set_route(pts: PackedVector3Array, hidden := PackedByteArray()) -> void:
	route = pts
	route_hidden = hidden
	if route_hidden.size() != route.size():
		route_hidden.resize(route.size())
		route_hidden.fill(0)
	route_i = 0


## On along the route at `spd` m/s for `delta` s. True at its end.
func _advance(spd: float, delta: float) -> bool:
	speed = spd
	var step := spd * delta
	var moved := 0.0
	while step > 1e-6 and route_i < route.size():
		var to := route[route_i]
		var d := base.distance_to(to)
		if d <= step:
			base = to
			step -= d
			moved += d
			route_i += 1
		else:
			var v := (to - base) / d
			base += v * step
			moved += step
			step = 0.0
	var fv := Vector3.ZERO
	if route_i < route.size():
		fv = _flat(route[route_i] - base)
	if fv.length() > 0.01:
		dir = _turn(dir, fv.normalized(), clampf(delta * 6.0, 0.0, 1.0))
	travelled += moved
	# The slither: the head swings side to side as it goes, so the body
	# lies in waves behind it (straight in a tunnel).
	var b: Dictionary = sub("body")
	var amp := 0.0 if _in_tunnel() else float(b.get("undulate_m", 0.22)) * _sway
	var wave := maxf(float(b.get("wave_m", 2.6)), 0.5)
	var side := Vector3(-dir.z, 0.0, dir.x)
	head = base + side * sin(travelled * TAU / wave) * amp
	if moved > 0.0:
		_push_trail(head)
	_track_node()
	_track_tunnel()
	return route_i >= route.size()


## The head's place kept: the trail's first point follows the head, and
## the head's place is kept once it is TRAIL_STEP on from the last kept
## one (so the trail is the path the head took, however small each frame's
## step; measured from the first point it never grew at a slow slither,
## and the body was drawn straight from its head to wherever it last kept
## one).
func _push_trail(p: Vector3) -> void:
	if trail.size() < 2:
		trail.push_front(p)
	elif (trail[1] as Vector3).distance_to(p) >= TRAIL_STEP:
		trail[0] = p
		trail.push_front(p)
	else:
		trail[0] = p
	var keep := int((float(sub("body").get("length_m", 9.0)) + 1.5) / TRAIL_STEP) + 4
	while trail.size() > keep:
		trail.pop_back()


## Is its head inside the rock now (going through a tunnel, or down its
## den): on a stretch of its route with an end hidden?
func _in_tunnel() -> bool:
	if route_i >= route.size() or route_hidden.size() != route.size():
		return false
	return route_hidden[route_i] != 0 or (route_i > 0 and route_hidden[route_i - 1] != 0)


## Is it going through one of its tunnels (not its den)?
func _in_tunnel_run() -> bool:
	if route_i >= route.size() or route_hidden.size() != route.size():
		return false
	return route_hidden[route_i] == HID_TUNNEL or (route_i > 0 and route_hidden[route_i - 1] == HID_TUNNEL)


## Which node it is in now (not while it is in the rock), and its tally of
## lit nodes: never of its own accord; chasing you only under the light's
## cap; crossing (leaving the light, fleeing home, or out of a tunnel into a
## room lit while it was under the floor, both its holes lit).
func _track_node() -> void:
	if _in_tunnel():
		return
	var was := node
	node = ground.node_at(base)
	if node < 0:
		return
	if bool(ground.nodes[node].hearth):
		hearth_steps += 1
	if node != was and not ground.is_ground(node):
		match state:
			"hunt", "hang", "strike", "watch":
				chase_lit_entries += 1
			"leave", "flee", "release", "rise", "stunned", "held":
				cross_lit_entries += 1
			_:
				if _after_tunnel:
					# Out of a tunnel into a room lit while it was under the
					# floor, both its holes lit (it leaves at once).
					cross_lit_entries += 1
				else:
					lit_entries += 1
	if noticed and state in ["hunt", "hang", "strike", "watch"] and light != null:
		chase_light_peak = maxf(chase_light_peak, light.at(base))


## Into one of its tunnels or out of one (tools: transits, last_transit:
## the time and metres it was inside, and the straight line between where
## it went in and came out).
func _track_tunnel() -> void:
	var inside := _in_tunnel_run()
	if inside and not _inside:
		_in_t0 = clock
		_in_m0 = travelled
		_in_at = base
	elif not inside and _inside:
		transits += 1
		last_transit = {"s": clock - _in_t0, "m": travelled - _in_m0, "straight": _flat(base - _in_at).length(), "from": _in_at, "to": base}
	_inside = inside


## Where its next way starts (Mike's note of 7 Oct: a tunnel, once begun, is
## gone through): {"pos", "node", "pts", "hidden"}: in the rock, the rest of
## it out of the far hole to the floor before it; else where it is, with
## nothing first.
func _plan_from() -> Dictionary:
	if not _in_tunnel():
		return {"pos": base, "node": node, "pts": PackedVector3Array(), "hidden": PackedByteArray()}
	var pts := PackedVector3Array()
	var hid := PackedByteArray()
	var i := route_i
	# The rest of the rock...
	while i < route.size() and route_hidden[i] != 0:
		pts.append(route[i])
		hid.append(route_hidden[i])
		i += 1
	# ...then its mouth and the floor before it.
	var k := 0
	while i < route.size() and k < 2:
		pts.append(route[i])
		hid.append(route_hidden[i])
		i += 1
		k += 1
	var end: Vector3 = pts[pts.size() - 1] if not pts.is_empty() else base
	return {"pos": end, "node": ground.node_at(end), "pts": pts, "hidden": hid}


## A route made from `start` (_plan_from) and on through nodes `path` to
## `end` (_route_nodes): set, the tunnel it is in first if it is in one.
func _set_planned(start: Dictionary, path: Array, end: Vector3) -> void:
	var r := _route_nodes(path, end, start.pos)
	var pts: PackedVector3Array = start.pts
	var hid: PackedByteArray = start.hidden
	_set_route(pts + (r.pts as PackedVector3Array), hid + (r.hidden as PackedByteArray))


## The way through nodes `path` (from the one it starts in, at `from`) to
## `end`, along the floor by the dimmest way (TombNav, the light: the
## edges of the light, the dark corners): through each door's middle, on
## by each sconce's line, and through each tunnel the way takes (in at one
## hole, under the floors, out at the other): {"pts", "hidden"}.
func _route_nodes(path: Array, end: Vector3, from: Vector3) -> Dictionary:
	var pts := PackedVector3Array()
	var hid := PackedByteArray()
	var at := from
	for k in range(path.size() - 1):
		var l := ground.best_link(int(path[k]), int(path[k + 1]))
		if l.is_empty():
			continue
		if l.has("tunnel"):
			var tp := _tunnel_pts(l)
			_floor_leg(pts, hid, at, tp[0])
			for i in range(1, tp.size()):
				pts.append(tp[i])
				hid.append(HID_TUNNEL if bool(BossGround.TUNNEL_HIDDEN[i]) else 0)
			at = tp[tp.size() - 1]
			continue
		var via: Vector3 = l.via
		if int(l.door) >= 0:
			var d: Dictionary = lay.doors[int(l.door)]
			var n3 := Vector3((d.n as Vector2).x, 0.0, (d.n as Vector2).y)
			var sgn := 1.0 if int(ground.nodes[int(path[k])].piece) == int(d.a) else -1.0
			var before := via - n3 * sgn * 0.75
			var after := via + n3 * sgn * 0.75
			before.y = _floor_y(before)
			after.y = _floor_y(after)
			_floor_leg(pts, hid, at, before)
			pts.append(via)
			hid.append(0)
			pts.append(after)
			hid.append(0)
			at = after
		else:
			_floor_leg(pts, hid, at, via)
			at = via
	_floor_leg(pts, hid, at, end)
	return {"pts": pts, "hidden": hid}


## Tunnel link `l`'s way (lay.tunnels links' pts), from this end's hole.
func _tunnel_pts(l: Dictionary) -> PackedVector3Array:
	var t: Dictionary = (lay.tunnels.links as Array)[int(l.tunnel)]
	var pts: PackedVector3Array = t.pts
	if int(t.a) == int(l.from_hole):
		return pts
	var out := PackedVector3Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(pts[i])
	return out


## The floor from `a` to `b` by the dimmest way (TombNav, DIM; round what
## stands in the way without a grid), onto `pts` (its own first square
## left out where it is there already), ending at `b` exactly.
func _floor_leg(pts: PackedVector3Array, hid: PackedByteArray, a: Vector3, b: Vector3) -> void:
	if nav == null:
		for p in _around(PackedVector3Array([b]), a):
			pts.append(p)
			hid.append(0)
		return
	var leg := nav.path(a, b, true, TombNav.DIM)
	for i in leg.size():
		if i == 0 and leg[i].distance_to(a) < 0.35:
			continue
		pts.append(leg[i])
		hid.append(0)
	if leg.is_empty() or leg[leg.size() - 1].distance_to(b) > 0.05:
		pts.append(b)
		hid.append(0)


## Round what stands in the way (a coffin, the heart's box, a fire on the
## floor), without the floor grid: a leg that hits something gets a step
## aside.
func _around(pts: PackedVector3Array, from: Vector3) -> PackedVector3Array:
	if not is_inside_tree():
		return pts
	var out := PackedVector3Array()
	for p in pts:
		var guard := 0
		while guard < 2:
			guard += 1
			var hit: Variant = _blocked_at(from + Vector3(0, KNEE, 0), p + Vector3(0, KNEE, 0))
			if hit == null:
				break
			var h: Vector3 = hit
			var fwd := _flat(p - from).normalized()
			var side := Vector3(-fwd.z, 0.0, fwd.x)
			var found := false
			for off: float in [0.9, -0.9, 1.5, -1.5, 2.2, -2.2]:
				var q := Vector3(h.x, from.y, h.z) + side * off - fwd * 0.3
				q.y = _floor_y(q)
				if _blocked_at(from + Vector3(0, KNEE, 0), q + Vector3(0, KNEE, 0)) == null and _blocked_at(q + Vector3(0, KNEE, 0), p + Vector3(0, KNEE, 0)) == null:
					out.append(q)
					from = q
					found = true
					break
			if not found:
				break
		out.append(p)
		from = p
	return out


func _blocked(a: Vector3, b: Vector3, fires_too := true) -> bool:
	return _blocked_at(a, b, fires_too) != null


## Where the way from `a` to `b` meets stone or (fires_too) a fire on the
## floor; null if it doesn't.
func _blocked_at(a: Vector3, b: Vector3, fires_too := true) -> Variant:
	if a.distance_to(b) < 0.05:
		return null
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = PropCollision.WORLD_LAYER
	if player != null:
		q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	if not fires_too:
		return null
	# The fires on the floor have no stone to hit: kept off by hand.
	for h in lay.holders:
		if str(h.kind) == "sconce":
			continue
		var hp := Vector2((h.pos as Vector3).x, (h.pos as Vector3).z)
		var cp := Geometry2D.get_closest_point_to_segment(hp, Vector2(a.x, a.z), Vector2(b.x, b.z))
		if cp.distance_to(hp) < 0.85 and absf((h.pos as Vector3).y - a.y) < 1.5:
			return Vector3(cp.x, a.y, cp.y)
	return null


## Cut `from_end` metres off the route's far end (to stop short of you).
func _trim(pts: PackedVector3Array, from_end: float) -> PackedVector3Array:
	var all := PackedVector3Array([base]) + pts
	var left := from_end
	while all.size() >= 2 and left > 0.0:
		var a := all[all.size() - 2]
		var b := all[all.size() - 1]
		var l := a.distance_to(b)
		if l <= left:
			all.remove_at(all.size() - 1)
			left -= l
		else:
			all[all.size() - 1] = b.lerp(a, left / l)
			left = 0.0
	all.remove_at(0)
	return all


## How far its route runs on from where it is (m, flat).
func _route_left() -> float:
	var m := 0.0
	var at := base
	for i in range(route_i, route.size()):
		m += _flat(route[i] - at).length()
		at = route[i]
	return m


## Nothing of the stone between its body and you, at the height it rears.
func _clear_to(p: Vector3) -> bool:
	return not _blocked(base + Vector3(0, 0.6, 0), p + Vector3(0, 0.6, 0), false)


## May it stand at `p` chasing you: on the floor its grid knows, and no
## brighter there than the chase's cap (Mike's note of 7 Oct)?
func _may_stand(p: Vector3) -> bool:
	if nav != null:
		var c := nav.cell_of(p)
		if nav.inside(c) and not nav.is_open(c):
			return false
	return light == null or light.under_cap(p)


## The floor's height under `p` (the grid's, else its piece's).
func _floor_at(p: Vector3) -> float:
	if nav != null:
		var fy := nav.floor_at(p)
		if not is_nan(fy):
			return fy
	return _floor_y(p)


## In its wind-up, its lunge and its draw back, still coming (Mike's note
## of 7 Oct: as fast as your walk): toward you at up to hunt_mps until you
## are back within its reach at the distance it strikes from, never past
## the light's cap, never through stone: straight at you, or round a corner
## or a door's jamb along the chase's own way to you (TombNav's capped
## grid).
func _creep_in(to: Vector3, delta: float) -> void:
	var v := _flat(to - base)
	var d := v.length()
	var keep := strike.reach_m * 0.7
	if d <= keep + 0.02:
		return
	var step := minf(num("hunt_mps", 4.6) * delta, d - keep)
	var nxt := base + v / d * step
	nxt.y = _floor_at(nxt)
	if _may_stand(nxt) and not _blocked(base + Vector3(0, KNEE, 0), nxt + Vector3(0, KNEE, 0)):
		_set_route(PackedVector3Array([nxt]))
	else:
		_replan_t -= delta
		if _replan_t <= 0.0 or route_i >= route.size():
			_replan_t = 0.3
			_set_route(_cap_path(to))
	_creep_along(step)
	speed = step / maxf(delta, 1e-4)


## On along its route `m` metres, its head on its line (no slither: it is
## reared to strike).
func _creep_along(m: float) -> void:
	var left := m
	while left > 1e-6 and route_i < route.size():
		var to := route[route_i]
		var d := base.distance_to(to)
		if d <= left:
			base = to
			left -= d
			route_i += 1
		else:
			base += (to - base) / d * left
			left = 0.0
	if left >= m:
		return
	head = base
	travelled += m - left
	_push_trail(head)
	_track_node()


# --- Every tick ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if auto:
		tick(delta)


func tick(delta: float) -> void:
	if not started:
		return
	clock += delta
	let_go_t = maxf(let_go_t - delta, 0.0)
	_camo_tick(delta)
	if light != null:
		# (Its own step too: the checks drive it by hand, between the
		# residents' physics steps.)
		light.refresh()
	if state == "lair" or state == "gone":
		_bed_tick(delta)
		_sound_tick(delta)
		return
	_refresh(false)
	if state == "release":
		_release_tick(delta)
		_pose()
		_bed_tick(delta)
		_sound_tick(delta)
		return
	if Harm.instance != null and Harm.instance.taking and not (state in ["stunned", "flee", "den", "rise"]):
		# You are taken: it holds where it is, quiet, until you wake.
		if state != "held":
			state = "held"
			_calm()
			# One of the rule's own moments: the state of its pool is over.
			_end_unit("rule")
	if state == "held":
		lift = move_toward(lift, 0.1, delta)
		lunge = move_toward(lunge, 0.0, delta * 3.0)
		_pose()
		_sound_tick(delta)
		return
	strike.tick(delta)
	# Its pool (§FM.1): the next state drawn when it is due and the boss is
	# free; then the one in charge, its built rounds in the rule's moments.
	_pool_step(delta)
	if _unit == null or rule_moment():
		rounds_tick(delta)
	else:
		_unit.tick(self, delta)
		_pool_guard(delta)
	if _after_tunnel and not _in_tunnel():
		_after_tunnel = false
		_after_light()
	_pose()
	_bed_tick(delta)
	_sound_tick(delta)


## The built behaviour (queues 49, 56, 57), the pool's 'rounds' (§FM.1),
## unchanged: noticing you, the chase, and whatever it is doing now.
func rounds_tick(delta: float) -> void:
	_notice(delta)
	_chase(delta)
	match state:
		"coil":
			_coil_tick(delta)
		"prowl":
			_prowl_tick(delta)
		"hunt":
			_hunt_tick(delta)
		"hang":
			_hang_tick(delta)
		"strike":
			_strike_tick(delta)
		"watch":
			_watch_tick(delta)
		"leave":
			_leave_tick(delta)
		"stunned":
			_stunned_tick(delta)
		"flee":
			_flee_tick(delta)
		"den":
			_den_tick(delta)
		"rise":
			_rise_tick(delta)


## The lights: worked out again whenever a holder catches. The last one
## sends it home; a light round it sends it off.
func _refresh(force: bool) -> void:
	var n := fires.lit_count()
	if n == _lit_n and not force:
		return
	_lit_n = n
	var lit: Array = []
	for h in fires.holders:
		lit.append(FireStore.is_lit(h))
	ground.update(lit)
	if force:
		return
	if ground.ground_count() == 0:
		release()
		return
	if state in ["release", "lair", "gone", "stunned", "flee", "den", "rise", "held"]:
		return
	if _in_tunnel():
		# In the rock: it decides once it is out, turning back first if the
		# hole it is making for now opens into the light.
		_after_tunnel = true
		_turn_back_if_lit()
		return
	_after_light()


## In one of its tunnels on its rounds or leaving the light, when a light
## catches: if the hole it is making for now opens into the light and the
## one it went in by is still dark, it turns back under the floor (unseen)
## and comes out where it went in (Mike's note of 7 Oct: it does its best
## to keep to the dark). True if it turned back.
func _turn_back_if_lit() -> bool:
	if not _in_tunnel_run() or not (state in ["prowl", "leave"]):
		return false
	# The hole it went in by (its mouth at j, the floor before it at j - 1)
	# and the one it is making for (its mouth at k, the floor at k + 1).
	var j := route_i - 1
	while j >= 0 and route_hidden[j] != 0:
		j -= 1
	var k := route_i
	while k < route.size() and route_hidden[k] != 0:
		k += 1
	if j < 1 or k + 1 >= route.size():
		return false
	var ahead := ground.node_at(route[k + 1])
	var behind := ground.node_at(route[j - 1])
	if ahead < 0 or ground.is_ground(ahead) or behind < 0 or not ground.is_ground(behind):
		return false
	var pts := PackedVector3Array()
	var hid := PackedByteArray()
	for i in range(route_i - 1, j - 2, -1):
		pts.append(route[i])
		hid.append(route_hidden[i])
	_set_route(pts, hid)
	_turned_back = state == "prowl"
	turned_back += 1
	return true


## The light changed round it: chasing you, it stays unless the light where
## it stands is now past the chase's cap (then it gives you up and leaves);
## else, its room or stretch lit, it leaves for the dark; its way gone into
## the light, it thinks again.
func _after_light() -> void:
	node = ground.node_at(base)
	if _unit != null and not _unit.built() and not rule_moment():
		# A state of its pool in charge (§FM.1): lit round it, the state is
		# over and it leaves for the dark as built (never_breaks
		# relit_room_stays_safe); else the state thinks again.
		if node >= 0 and not ground.is_ground(node):
			_end_unit("light")
			_leave()
		else:
			_unit.lights_changed(self)
		return
	if noticed and state in ["hunt", "hang", "strike", "watch"]:
		if light != null and light.at(base) > light.cap:
			# The light caught round it: back to its edge (_hunt_tick).
			_calm()
			state = "hunt"
		# The edge may have moved: find the way again.
		_replan_t = 0.0
		_hunt_to = Vector3.INF
		return
	if node >= 0 and not ground.is_ground(node):
		_leave()
		return
	if state == "leave":
		_leave()
		return
	_replan_t = 0.0
	if state == "prowl":
		for i in range(route_i, route.size()):
			if route_hidden.size() == route.size() and route_hidden[i] != 0:
				continue
			if not ground.is_ground(ground.node_at(route[i])):
				_next_round()
				break


# --- Noticing ----------------------------------------------------------------

func _eye() -> Vector3:
	return head + Vector3(0.0, 0.35 + lift, 0.0)


func _notice(delta: float) -> void:
	_notice_t -= delta
	if state in ["stunned", "flee", "den", "rise"] or _in_tunnel():
		# Dazed, fleeing, down its hole or in its tunnels: it notices nothing
		# (and hears no burst that waits for it).
		_hears_burst()
		perceives = false
		return
	if _notice_t > 0.0:
		return
	_notice_t = 0.2
	perceives = false
	if player == null or player.dead:
		return
	var n: Dictionary = RULE.get("notice", {})
	var pp := player.global_position
	var flat_d := _flat(pp - head).length()
	var lit := _torch_lit()
	var seen := false
	if lit:
		var flame := player.torch.flame_position()
		seen = _eye().distance_to(flame) <= float(n.get("sees_flame_m", 20.0)) and not _blocked(_eye(), flame, false)
	# A sprint, or anything as loud (a swing that lands on it, §FA.1).
	var heard := player.noise_level >= 0.99 and flat_d <= float(n.get("hears_sprint_m", 15.0))
	var felt := flat_d <= num("feels_m", 1.5)
	# A fire pot gives you away (§FA.3, FirePots): the lit wick's flare in
	# its sight within gives_away.flare_seen_m, the burst within its
	# burst_heard_m.
	var flared := not FirePots.flare_seen_from(_eye(), get_world_3d().direct_space_state).is_empty()
	var burst := _hears_burst()
	if let_go_t > 0.0:
		# It has let you go (coil_ambush, walked away from; queue 66): only
		# you right by it count.
		seen = false
		heard = false
		flared = false
		burst = false
	perceives = seen or heard or felt or flared or burst
	if perceives:
		if not noticed:
			hang_t = 0.0
			struck = false
		noticed = true
		last_seen = pp
		pursuit.notice(lit)
		if state in ["coil", "prowl"]:
			state = "hunt"
			coiling = false
			_replan_t = 0.0


func _torch_lit() -> bool:
	return player != null and player.torch != null and player.torch.lit()


## A pot's burst within its heard_m since it last listened (FirePots).
func _hears_burst() -> bool:
	var out := false
	for b in FirePots.bursts_since(_burst_id):
		_burst_id = int(b.id)
		if _flat((b.pos as Vector3) - head).length() <= float(b.heard_m):
			out = true
	return out


# --- Fire pots (FirePots' fire-target socket; design §FA.3, §FA.4) ------------

## Where a pot meets its head (the sphere a thrown pot hits).
func fire_center() -> Vector3:
	return head + Vector3(0.0, KNEE + lift, 0.0)


## How far `p` is from its body (m; under 0 inside it): its head and its
## length along the trail, girth_m thick, but what is down in the rock (a
## tunnel's run, its den). INF while all of it is out of reach (down its
## hole, home, gone).
func fire_distance(p: Vector3) -> float:
	if state in ["den", "lair", "gone"] or (body != null and not body.visible):
		return INF
	var r := float(sub("body").get("girth_m", 0.38)) * 0.5 + 0.1
	var best := INF
	if not _in_tunnel():
		best = fire_center().distance_to(p)
	for q: Vector3 in _body_pts(0.5):
		if q.y < _floor_y(q) - 0.3:
			continue
		best = minf(best, (q + Vector3(0.0, KNEE, 0.0)).distance_to(p))
	return best - r


## Points along its body as drawn, `step` m apart from its head back to
## its length_m, along the trail its head left.
func _body_pts(step: float) -> Array:
	if trail.is_empty():
		return [head]
	var length := float(sub("body").get("length_m", 9.0))
	var out: Array = [trail[0]]
	var want := step
	var acc := 0.0
	for i in range(trail.size() - 1):
		if want > length:
			break
		var a: Vector3 = trail[i]
		var b: Vector3 = trail[i + 1]
		var l := a.distance_to(b)
		while want <= acc + l and want <= length:
			out.append(a.lerp(b, (want - acc) / maxf(l, 1e-4)))
			want += step
		acc += l
	return out


## A fire pot burst on it (§FA.4; Mike's note of 7 Oct: "a pot cant kill a
## boss but will stun it/cause it to retreat to its cave temporarily";
## fire_pots.json vs_boss): stunned where it lies for stun_s, the chase
## off; then it flees to its lair hole and down it for `seconds`, and comes
## up again (_flee_home, _den_tick). Nothing to drive off at home, taken,
## or already going.
func drive_off(seconds: float, _from: Vector3) -> void:
	if state in ["release", "lair", "gone", "held", "stunned", "flee", "den", "rise"]:
		return
	driven += 1
	_let_go("pot")
	_calm()
	_den_s = seconds
	stun_t = num("stun_s", 1.5)
	state = "stunned"
	speed = 0.0
	if not _in_tunnel():
		# Where it was going, forgotten (in a hole, it goes on through).
		_set_route(PackedVector3Array())
	# It reels: a sharp hiss, its head thrown down.
	_play_hiss(str(sub("strike").get("sound", "snake_hiss")))


## The chase's own rules (Pursuit, bosses.json gives_up): too far, out of
## its sight and hearing too long, your torch put out. Given up, it goes
## back to its rounds; given up at the light's edge in a lit room or
## stretch, back to the dark first, there within residents.json
## rules.back_to_dark_s.
func _chase(delta: float) -> void:
	if not noticed:
		return
	var d := _flat(player.global_position - head).length()
	if pursuit.step(delta, perceives, d, _torch_lit()):
		noticed = false
		if not (state in ["hunt", "hang", "strike", "watch"]):
			return
		_calm()
		if node >= 0 and not ground.is_ground(node):
			_leave(true)
		else:
			_next_round()


## Gives you up (the watch ran out, it was driven off, taken home, you
## woke).
func _let_go(why: String) -> void:
	noticed = false
	pursuit.give_up(why)


## Hunting you (its chase on, and after you)?
func chasing() -> bool:
	return noticed and state in ["hunt", "hang", "strike", "watch"]


## Whatever strike was under way, off.
func _calm() -> void:
	strike.cancel()
	mouth_open = false
	lunge = 0.0


# --- The states ----------------------------------------------------------------

func _coil_tick(delta: float) -> void:
	if coiling:
		_sway = move_toward(_sway, 0.0, delta * 2.0)
		if _advance(num("speed_mps", 2.0) * 0.6, delta):
			coiling = false
			coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0)
		lift = move_toward(lift, 0.12, delta)
		return
	speed = 0.0
	lift = move_toward(lift, 0.12, delta * 0.5)
	coil_left -= delta
	if coil_left <= 0.0:
		_next_round()


## The next round: to another dark dead end it can reach through the dark
## and its tunnels (the farther the likelier), else the farthest dark it
## can reach. Standing in the light (a chase given up at its edge), out of
## it first.
func _next_round() -> void:
	_calm()
	var from := _plan_from()
	var at := int(from.node)
	if at < 0:
		return
	if not ground.is_ground(at):
		_leave()
		return
	var reach := ground.reach(at)
	var cands: Array = []
	var total := 0.0
	for id in reach:
		if int(id) == at or not ground.dead_end(int(id)):
			continue
		cands.append(int(id))
		total += float(reach[id]) + 5.0
	var pick := -1
	if not cands.is_empty():
		var r := _rng.randf() * total
		for id in cands:
			r -= float(reach[id]) + 5.0
			if r <= 0.0:
				pick = id
				break
		if pick < 0:
			pick = int(cands[-1])
	else:
		var far := 0.0
		for id in reach:
			if int(id) != at and float(reach[id]) > far and str(ground.nodes[id].kind) == "room":
				far = float(reach[id])
				pick = int(id)
	if pick < 0:
		# Nowhere else in its dark: coil where it is (out of the tunnel first).
		_set_route(from.pts, from.hidden)
		state = "coil"
		coiling = not route.is_empty()
		coil_left = _range(def.get("coil_s", [10.0, 25.0]), 10.0, 25.0) * 0.5
		return
	target = pick
	_set_planned(from, ground.path(at, pick, true), _room_entry(pick))
	state = "prowl"


func _prowl_tick(delta: float) -> void:
	_sway = move_toward(_sway, 1.0, delta)
	lift = move_toward(lift, 0.0 if _in_tunnel() else 0.08, delta)
	if _advance(num("speed_mps", 2.0), delta) and _turned_back:
		# Back out where it went in: on its rounds afresh.
		_turned_back = false
		node = ground.node_at(base)
		_next_round()
		return
	if route_i >= route.size():
		# Arrived: coil (§EY.3: "coils in dead ends between rounds").
		var c := _coil_spot(target)
		var pts := PackedVector3Array()
		for p in _spiral(c, base):
			pts.append(p)
		_set_route(pts)
		state = "coil"
		coiling = true


## The way to you for the chase (Mike's note of 7 Oct): TombNav's capped
## grid, never onto floor brighter than the cap, so with you in the light
## it ends at the edge of it nearest you.
func _cap_path(to: Vector3) -> PackedVector3Array:
	if nav == null:
		return PackedVector3Array([Vector3(to.x, _floor_y(to), to.z)])
	return _from_here(nav.path(base, to, true, TombNav.CAP))


## A grid way from where it is, without the middle of its own square first
## (no step back to it each time it finds the way again).
func _from_here(pts: PackedVector3Array) -> PackedVector3Array:
	if pts.size() >= 2 and _flat(pts[0] - base).length() < 0.36:
		pts.remove_at(0)
	return pts


## The way out of the light to its nearest edge (open floor no brighter
## than the chase's cap, within 8 m), by the dimmest way; [] if none.
func _to_edge() -> PackedVector3Array:
	if nav == null or light == null:
		return PackedVector3Array()
	var c := nav.cell_of(base)
	for r in range(1, 33):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if maxi(absi(ox), absi(oy)) != r:
					continue
				var q := c + Vector2i(ox, oy)
				if not nav.is_open(q) or nav.light_of(q) > light.cap:
					continue
				var d := Vector2(ox, oy).length()
				if d < best_d:
					best_d = d
					best = q
		if best.x >= 0:
			return _from_here(nav.path(base, nav.point_of(best), true, TombNav.DIM))
	return PackedVector3Array()


func _hunt_tick(delta: float) -> void:
	_sway = move_toward(_sway, 0.7, delta)
	var pp := player.global_position
	var torch_lit := _torch_lit()
	var delay := sub("torch_delay")
	var hang_m := float(delay.get("hang_m", 3.5))
	var hang_s := float(delay.get("hang_s", 4.0))
	var holding := torch_lit and not struck and hang_t < hang_s
	# It strikes from within 0.8 of its reach, its way aimed nearer (half
	# its reach short of you), so a walker it gains on is caught.
	var stop := hang_m if holding else strike.reach_m * 0.8
	var d := _flat(pp - base).length()
	if light != null and light.at(base) > light.cap:
		# In the light past the chase's cap (it found you going through a
		# fire's spill, or a fire caught or was planted by it): out to the
		# light's edge first, never deeper in.
		_replan_t -= delta
		if _replan_t <= 0.0 or route_i >= route.size():
			_replan_t = 0.4
			_hunt_to = Vector3.INF
			var out := _to_edge()
			if out.is_empty():
				_let_go("light")
				_leave(true)
				return
			_set_route(out)
		_advance(num("hunt_mps", 4.6), delta)
		return
	if absf(pp.y - base.y) < 1.5 and d <= stop + 0.1 and _clear_to(pp):
		if holding:
			state = "hang"
		else:
			state = "strike"
			strike.begin()
		return
	_replan_t -= delta
	if _replan_t <= 0.0 or pp.distance_to(_hunt_to) > 0.75:
		_replan_t = 0.4
		_hunt_to = pp
		var pts := _cap_path(pp)
		if pts.is_empty():
			_start_watch()
			return
		# A way that stops short of you stops at the light's edge: all the
		# way to it, then it watches you from there.
		_edge = not TombNav.reaches(pts, pp, 0.6)
		_set_route(pts if _edge else _trim(pts, hang_m if holding else strike.reach_m * 0.5))
	lift = move_toward(lift, 0.35, delta)
	if _advance(num("hunt_mps", 4.6), delta) and _edge:
		# The light between: it has come as far as the light lets it.
		_start_watch()


## Flat direction `from` turned toward `to` by share `k` (0-1).
static func _turn(from: Vector3, to: Vector3, k: float) -> Vector3:
	var v := from.lerp(to, k)
	if v.length() < 1e-3:
		# Straight about: turn through the side.
		v = from.lerp(Vector3(-from.z, 0.0, from.x), 0.5)
	return v.normalized()


func _face(p: Vector3, delta: float) -> void:
	var v := _flat(p - base)
	if v.length() > 0.01:
		dir = _turn(dir, v.normalized(), clampf(delta * 8.0, 0.0, 1.0))


func _hang_tick(delta: float) -> void:
	var pp := player.global_position
	speed = 0.0
	if light != null and light.at(base) > light.cap:
		# The light caught round it: back to its edge first (_hunt_tick).
		state = "hunt"
		_replan_t = 0.0
		return
	_face(pp, delta)
	lift = move_toward(lift, 0.85, delta * 1.5)
	hang_t += delta
	_hiss_t -= delta
	if _hiss_t <= 0.0:
		_hiss_t = _rng.randf_range(1.2, 2.2)
		_play_hiss()
	var delay := sub("torch_delay")
	var d := _flat(pp - base).length()
	if not _torch_lit() or hang_t >= float(delay.get("hang_s", 4.0)) or d > float(delay.get("hang_m", 3.5)) + 1.2:
		# The flame has held it long enough (or there is none): it comes.
		state = "hunt"
		_replan_t = 0.0


## The strike (CreatureStrike): the pose follows its parts. Standing where
## the light passes the chase's cap (a fire caught by it, or planted), it
## breaks off (but for the committed lunge and a reel) and goes back to the
## light's edge first (_hunt_tick).
func _strike_tick(delta: float) -> void:
	var pp := player.global_position
	var d := _flat(pp - base).length()
	speed = 0.0
	if light != null and light.at(base) > light.cap and not (strike.state in ["strike", "reel"]):
		strike.cancel()
		_calm()
		state = "hunt"
		_replan_t = 0.0
		return
	_face(pp, delta)
	var k := strike.pose_k()
	match strike.state:
		"wind_up":
			# Reared back, jaws opening: its tell (the hiss is the strike's).
			# And still coming, as fast as your walk (Mike's note of 7 Oct).
			_creep_in(pp, delta)
			lift = move_toward(lift, 0.95, delta * 2.5)
			lunge = lerpf(lunge, -0.3, clampf(delta * 6.0, 0.0, 1.0))
			mouth_open = k > 0.5
		"strike":
			# The lunge carries its body on after you too.
			_creep_in(pp, delta)
			d = _flat(pp - base).length()
			lunge = lerpf(-0.3, clampf(d - 0.35, 0.0, strike.reach_m), k)
			lift = move_toward(lift, 0.55, delta * 4.0)
			mouth_open = true
		"recover":
			# Drawing its head back, its body still coming.
			_creep_in(pp, delta)
			lunge = move_toward(lunge, 0.0, delta * 3.0)
			lift = move_toward(lift, 0.75, delta)
			mouth_open = k < 0.3
		"reel":
			# Staggered (§FA.1): thrown back from the swing, jaws shut.
			_reel(strike.take_reel())
			lift = move_toward(lift, 0.3, delta * 3.0)
			lunge = move_toward(lunge, 0.0, delta * 4.0)
			mouth_open = false
		_:
			mouth_open = false
			lunge = move_toward(lunge, 0.0, delta * 3.0)
			if d <= strike.reach_m * 1.05 and absf(pp.y - base.y) < 1.5 and _clear_to(pp):
				strike.begin()
			else:
				state = "hunt"
				_replan_t = 0.0


## A strike reached you (CreatureStrike.on_hit): one hit
## (contact.strike_is_hit; Harm's breath between hits holds). It strikes
## only from where it may stand (the light's edge at most), so wherever
## its lunge finds you counts.
func _on_strike_hit(_target: Node3D) -> void:
	if not bool(CONTACT.get("strike_is_hit", true)):
		return
	var before := Harm.instance.landed if Harm.instance != null else 0
	player.death_cause = "creature:%s" % name_text
	player.take_hit(1.0, strike.global_position)
	if Harm.instance != null and Harm.instance.landed > before:
		hits_landed += 1
	pursuit.hit(_torch_lit())


## Staggered: this frame's share `v` of the reel (flat, away from the
## swing; CreatureStrike.take_reel). Back along its own body when the body
## leads away from the swing (it came at you along it) and lies where it
## may stand; when it doesn't (it struck from its coil, or round a corner),
## straight away from the swing, its body following, stopping at stone and
## where the light passes the chase's cap. Chosen once for each reel.
func _reel(v: Vector3) -> void:
	var m := v.length()
	if strike.stagger_frame != _reel_frame:
		_reel_frame = strike.stagger_frame
		# The body starts where the head is drawn, so the head never jumps.
		_push_trail(head)
		var from := strike.reel_from
		var back := _back_along(strike.reel_m)
		_reel_back = _flat(back - from).length() >= _flat(head - from).length() + strike.reel_m * 0.5 and _stands_along(strike.reel_m)
	if m < 1e-5:
		return
	if _reel_back:
		_recoil(m)
		return
	var to := head + v
	to.y = _floor_y(to)
	var tn := ground.node_at(to)
	if tn < 0 or not _may_reel(to, tn) or not _on_floor(to, tn) or _blocked(head + Vector3(0, 0.3, 0), to + Vector3(0, 0.3, 0)):
		return
	head = to
	base = to
	_push_trail(head)
	_track_node()


## May its reel take it to `p` (in node `tn`): in its dark, or under the
## light's cap.
func _may_reel(p: Vector3, tn: int) -> bool:
	if light != null:
		return light.under_cap(p)
	return ground.is_ground(tn)


## `p` on node `id`'s floor, off its walls by the body's girth (queue 57:
## a reel's small steps can't slip through a wall's face the way a ray
## that starts on it can).
func _on_floor(p: Vector3, id: int) -> bool:
	var pc: Dictionary = lay.pieces[int(ground.nodes[id].piece)]
	var aa := Delves.along_across(pc, Vector2(p.x, p.z))
	var m := float(sub("body").get("girth_m", 0.38)) * 0.5 + 0.1
	return aa.x >= m and aa.x <= float(pc.len) - m and absf(aa.y) <= float(pc.half) - m


## Where its head would be `m` metres back along its own body.
func _back_along(m: float) -> Vector3:
	if trail.size() < 2:
		return base
	var left := m
	var at: Vector3 = trail[0]
	for i in range(1, trail.size()):
		var nxt: Vector3 = trail[i]
		var l := at.distance_to(nxt)
		if l >= left:
			return at.lerp(nxt, left / maxf(l, 1e-4))
		left -= l
		at = nxt
	return at


## Whether the first `m` metres of its body lie where it may stand (its
## dark, or under the light's cap).
func _stands_along(m: float) -> bool:
	var s := 0.0
	while s <= m + 1e-3:
		var q := _seg_at(s)
		var id := ground.node_at(q)
		if id < 0 or not _may_reel(q, id):
			return false
		s += 0.25
	return true


## Drawn back `m` metres along its own body (a stagger's reel).
func _recoil(m: float) -> void:
	var left := m
	while left > 0.0 and trail.size() > 2:
		var a: Vector3 = trail[0]
		var b: Vector3 = trail[1]
		var l := a.distance_to(b)
		if l <= left:
			trail.pop_front()
			left -= l
		else:
			trail[0] = a.lerp(b, left / maxf(l, 1e-4))
			left = 0.0
	if not trail.is_empty():
		base = trail[0]
		head = base
		_track_node()


## At the edge of the light (or no way to you): it stops where it is and
## watches you.
func _start_watch() -> void:
	if state != "watch":
		watch_t = 0.0
	state = "watch"
	_set_route(PackedVector3Array())
	_replan_t = 0.4


## Watching you from the edge of the light (Mike's note of 7 Oct): reared,
## its head forward into the glow (peek_m), hissing its warning now and
## then; it strikes if you come within its reach of where it stands, comes
## on if the light lets it nearer, and after watch_s gives you up.
func _watch_tick(delta: float) -> void:
	_sway = move_toward(_sway, 0.3, delta)
	var pp := player.global_position
	var d := _flat(pp - base).length()
	speed = 0.0
	_face(pp, delta)
	lift = move_toward(lift, 0.85, delta * 1.5)
	lunge = move_toward(lunge, num("peek_m", 0.7) if perceives or d < 8.0 else 0.0, delta * 1.2)
	_hiss_t -= delta
	if _hiss_t <= 0.0:
		_hiss_t = _rng.randf_range(1.6, 3.0)
		if perceives:
			_play_hiss()
	if light != null and light.at(base) > light.cap:
		# A fire caught or was planted by it: back to the light's edge.
		state = "hunt"
		_replan_t = 0.0
		return
	var delay := sub("torch_delay")
	if _torch_lit() and not struck and hang_t < float(delay.get("hang_s", 4.0)) and d <= float(delay.get("hang_m", 3.5)) + 0.1:
		# Your flame holds it a while first, here as anywhere (the torch's
		# delay).
		state = "hang"
		return
	if d <= strike.reach_m * 0.95 and absf(pp.y - base.y) < 1.5 and _clear_to(pp):
		# You came within its reach of where it may stand.
		state = "strike"
		strike.begin()
		return
	_replan_t -= delta
	if _replan_t <= 0.0:
		_replan_t = 0.4
		var pts := _cap_path(pp)
		if not pts.is_empty():
			var e := pts[pts.size() - 1]
			if TombNav.reaches(pts, pp, 0.6) or _flat(e - pp).length() < d - 0.6:
				# The light lets it nearer now.
				state = "hunt"
				_replan_t = 0.0
				_hunt_to = Vector3.INF
				return
	watch_t += delta
	if watch_t >= num("watch_s", 10.0):
		# It gives you up and goes back to its rounds: out of the light first,
		# back in the dark within back_to_dark_s (§FD).
		_let_go("watch")
		node = ground.node_at(base)
		if node >= 0 and not ground.is_ground(node):
			_leave(true)
		else:
			_next_round()


## Out of the light (its node lit round it, or it gave you up at the
## light's edge in a lit node): to the nearest dark at once at leave_mps,
## under the light through its tunnels where they lead there, else across
## it on the dimmest way, the hearth room only when there is no other way
## (BossGround.nearest_dark). `hurry` (§FD: it gave you up in the light):
## fast enough to be in the dark within residents.json
## rules.back_to_dark_s, never faster than MOST_MPS.
func _leave(hurry := false) -> void:
	_calm()
	var from := _plan_from()
	var at := int(from.node)
	_leave_mps = num("leave_mps", 4.0)
	if at >= 0 and ground.is_ground(at):
		# In the dark already (or out of the tunnel into it).
		_set_route(from.pts, from.hidden)
		state = "leave"
		target = at
		return
	var path := ground.nearest_dark(at, BossGround.HEARTH_COST) if at >= 0 else []
	if path.is_empty():
		# No dark it can reach: it coils where it is (the last light sends
		# it home).
		_set_route(from.pts, from.hidden)
		state = "coil"
		coiling = not route.is_empty()
		coil_left = 2.0
		return
	var to := int(path[-1])
	var end: Vector3 = ground.nodes[to].center
	if str(ground.nodes[to].kind) == "room":
		end = _room_entry(to)
	_set_planned(from, path, end)
	if hurry:
		_leave_mps = minf(Pursuit.back_to_dark_mps(_route_left(), _leave_mps), MOST_MPS)
	state = "leave"
	target = to


func _leave_tick(delta: float) -> void:
	_sway = move_toward(_sway, 1.0, delta * 2.0)
	lift = move_toward(lift, 0.0 if _in_tunnel() else 0.1, delta)
	if _advance(_leave_mps, delta) or (not _in_tunnel() and node >= 0 and ground.is_ground(node) and route_i >= route.size() - 1):
		if node < 0 or not ground.is_ground(node):
			_leave()
			return
		state = "hunt" if noticed else "prowl"
		if state == "prowl":
			_next_round()
		_replan_t = 0.0


## Stunned by a fire pot (§FA.4, Mike's note of 7 Oct): lying dazed, its
## head down, for stun_s; then it flees to its hole.
func _stunned_tick(delta: float) -> void:
	speed = 0.0
	_sway = move_toward(_sway, 0.0, delta * 3.0)
	lift = move_toward(lift, 0.0, delta * 2.0)
	lunge = move_toward(lunge, 0.0, delta * 3.0)
	mouth_open = false
	if _in_tunnel():
		# Caught going into a hole: on through it, dazed.
		_advance(num("speed_mps", 2.0) * 0.5, delta)
	stun_t -= delta
	if stun_t <= 0.0:
		_flee_home()


## Off to its lair hole and down it (a fire pot drove it off): through its
## tunnels or across the light on the dimmest way, at flee_mps.
func _flee_home() -> void:
	state = "flee"
	_set_home_route()


## Its way home (_flee_home, release): to the floor by its lair's hole by
## the way with the least light and the most tunnel (BossGround: lit
## nodes dear, the hearth room only if there is no other way), then into
## the hole and down round its den, its whole body under the floor. With
## no lair, into the nearest of its tunnels' holes and down it.
func _set_home_route() -> void:
	var from := _plan_from()
	var at := int(from.node)
	if lair.is_empty() or lair_node < 0 or at < 0:
		_home_by_tunnel(from)
		return
	var path: Array = [at]
	if at != lair_node:
		path = ground.path(at, lair_node, false, FLEE_LIT_COST, BossGround.HEARTH_COST)
	if path.is_empty():
		_home_by_tunnel(from)
		return
	var c: Vector3 = lair.pos
	var rim := _rim_point()
	var r := _route_nodes(path, rim, from.pos)
	var pts: PackedVector3Array = (from.pts as PackedVector3Array) + (r.pts as PackedVector3Array)
	var hid: PackedByteArray = (from.hidden as PackedByteArray) + (r.hidden as PackedByteArray)
	pts.append(Vector3(c.x, c.y, c.z))
	hid.append(0)
	var den := _den_pts(rim)
	_set_route(pts + (den[0] as PackedVector3Array), hid + (den[1] as PackedByteArray))


## The floor by the lair's hole where it goes in and comes out: toward the
## room's way in, on open floor.
func _rim_point() -> Vector3:
	var c: Vector3 = lair.pos
	var toward := _room_entry(lair_node) if lair_node >= 0 else c + Vector3.FORWARD
	var v := _flat(toward - c)
	if v.length() < 0.01:
		v = Vector3.FORWARD
	v = v.normalized()
	var r := float(lair.r)
	for k in 8:
		var a := floorf((k + 1) * 0.5) * (0.6 if k % 2 == 1 else -0.6)
		var q := c + v.rotated(Vector3.UP, a) * (r + 0.75)
		q.y = _floor_at(q)
		if nav == null or nav.is_open(nav.cell_of(q)):
			return q
	var p := c + v * (r + 0.75)
	p.y = _floor_at(p)
	return p


## Down its hole from the floor by it (`rim`): the mouth's middle on the
## floor, then the den under it, the whole body taken under the floor:
## [PackedVector3Array, PackedByteArray (hidden)].
func _den_pts(rim: Vector3) -> Array:
	var c: Vector3 = lair.pos
	var pts := PackedVector3Array()
	var hid := PackedByteArray()
	pts.append(c - Vector3(0.0, DEN_SHAFT_M, 0.0))
	hid.append(HID_DEN)
	var a0 := atan2(c.z - rim.z, c.x - rim.x)
	var steps := int(DEN_TURNS * 16.0)
	for k in range(steps + 1):
		var u := float(k) / steps
		var a := a0 + u * DEN_TURNS * TAU
		pts.append(c + Vector3(cos(a) * DEN_R_M, -DEN_SHAFT_M - u * DEN_DROP_M, sin(a) * DEN_R_M))
		hid.append(HID_DEN)
	return [pts, hid]


## With no lair (or no way to it): into the nearest of its tunnels' holes,
## and its body after it: at home in its tunnels ("gone"), never vanished.
## With no tunnel either, it coils where it is.
func _home_by_tunnel(from: Dictionary) -> void:
	var holes: Array = (lay.get("tunnels", {}) as Dictionary).get("holes", [])
	var best := {}
	var best_d := INF
	for h in holes:
		var d := (from.pos as Vector3).distance_to(h.out)
		if d < best_d:
			best_d = d
			best = h
	if best.is_empty():
		_set_route(from.pts, from.hidden)
		return
	var pts: PackedVector3Array = from.pts
	var hid: PackedByteArray = from.hidden
	var r := _route_nodes([], best.out, from.pos)
	pts = pts + (r.pts as PackedVector3Array)
	hid = hid + (r.hidden as PackedByteArray)
	var n: Vector3 = best.n
	var back: Vector3 = (best.pos as Vector3) - n * (float(best.depth) - 0.05)
	# In, and straight down behind the wall, its length and more under the
	# floor.
	pts.append(best.pos)
	hid.append(0)
	for p: Vector3 in [back, back - Vector3(0.0, float(sub("body").get("length_m", 9.0)) + 1.5, 0.0)]:
		pts.append(p)
		hid.append(HID_DEN)
	_set_route(pts, hid)


func _flee_tick(delta: float) -> void:
	_sway = move_toward(_sway, 0.0 if _in_tunnel() else 1.0, delta * 2.0)
	lift = move_toward(lift, 0.0 if _in_tunnel() else 0.1, delta)
	if _advance(num("flee_mps", 5.0), delta):
		# Down its hole: out of everything's reach, breathing, for the pot's
		# while.
		state = "den"
		den_t = _den_s
		if not lair.is_empty():
			Audio3D.play(_breath)


## Down its hole (driven off by a pot): it stays drives_off_s, breathing,
## then comes up.
func _den_tick(delta: float) -> void:
	speed = 0.0
	den_t -= delta
	if den_t <= 0.0:
		_breath.stop()
		_rise_up()


## Up out of its hole: from its den, up the shaft to the mouth and out onto
## the floor by it, then on its rounds (out of the room first if it was
## lit meanwhile).
func _rise_up() -> void:
	state = "rise"
	if lair.is_empty():
		_set_route(PackedVector3Array())
		return
	var c: Vector3 = lair.pos
	var pts := PackedVector3Array()
	var hid := PackedByteArray()
	var top := Vector3(base.x, c.y - 0.4, base.z)
	for p: Vector3 in [top, c - Vector3(0.0, 0.3, 0.0)]:
		pts.append(p)
		hid.append(HID_DEN)
	pts.append(Vector3(c.x, c.y, c.z))
	hid.append(0)
	pts.append(_rim_point())
	hid.append(0)
	_set_route(pts, hid)


func _rise_tick(delta: float) -> void:
	_sway = move_toward(_sway, 0.6, delta)
	lift = move_toward(lift, 0.15, delta)
	if _advance(num("speed_mps", 2.0), delta):
		node = ground.node_at(base)
		_next_round()


# --- The last light -------------------------------------------------------------

## The dungeon's last holder has caught (rule.last_light to_lair): it goes
## home, physically, and the tomb hears it go (Mike's note of 7 Oct: it
## never vanishes).
func release() -> void:
	if released:
		return
	released = true
	var was := state
	_calm()
	# The last light is the rule's: no state of its pool after it (§FM.1).
	_end_unit("rule")
	_let_go("home")
	var line := str(RELEASE.get("log_line", "Drove the {boss} into its hole")).format({"boss": name_text})
	GameLog.add(line + ".", "boss")
	if bool(RELEASE.get("cry_to_lair", true)):
		_cry.global_position = head
		Audio3D.play(_cry)
	if was == "den":
		# Down its hole already (a pot drove it there): it stays.
		_home()
		return
	state = "release"
	_set_home_route()


func _release_tick(delta: float) -> void:
	_sway = move_toward(_sway, 0.0 if _in_tunnel() else 1.0, delta)
	lift = move_toward(lift, 0.0, delta)
	var done := _advance(num("flee_mps", 5.0), delta)
	# The long cry goes with it, along the tomb and down its hole.
	_cry.global_position = head
	if done:
		_home()


## In its hole for good (or its tunnel, with no lair): breathing, below;
## its body all under the floor, so it is drawn no more.
func _home() -> void:
	state = "gone" if lair.is_empty() else "lair"
	speed = 0.0
	if not lair.is_empty():
		Audio3D.play(_breath)
	if _all_below():
		body.visible = false
	_bed_t = 0.0


## Is all of it under the floor (its head and every length of its body as
## drawn, length_m along its trail)?
func _all_below() -> bool:
	if head.y > _floor_y(head) - 0.3:
		return false
	for q: Vector3 in _body_pts(0.25):
		if q.y > _floor_y(q) - 0.3:
			return false
	return true


## Can you see it: in the frame, nothing between.
func _in_view() -> bool:
	if not is_inside_tree() or not body.visible:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	for p: Vector3 in [head + Vector3(0, 0.3, 0), _seg_at(float(sub("body").get("length_m", 9.0)) * 0.3)]:
		if cam.is_position_in_frustum(p) and not _blocked(cam.global_position, p, false):
			return true
	return false


# --- You were taken --------------------------------------------------------------

## You wake at the hearth (CrawlerMain): it lets you go where it is (Mike's
## note of 7 Oct: it doesn't reappear anywhere) and goes on with its
## rounds from there, out of the light first; a tunnel it was in, it
## finishes.
func after_wake() -> void:
	_let_go("wake")
	_calm()
	hang_t = 0.0
	struck = false
	if state in ["release", "lair", "gone", "stunned", "flee", "den", "rise"]:
		return
	if _in_tunnel():
		state = "prowl"
		return
	node = ground.node_at(base)
	state = "coil"
	_next_round()


# --- Its pool (design 9 Oct §FM.1; BossPool, BossState) ----------------------

## In one of the rule's own moments (RULE_MOMENTS, its strike under way, the
## last light): no state of its pool is in charge and the pool is not asked.
func rule_moment() -> bool:
	return released or state in RULE_MOMENTS or (strike != null and strike.busy())


## The pool, every tick before the one in charge: the state in charge is
## over the moment one of the rule's own moments begins; once it ends
## itself or its dwell runs out, and the boss is free (none of the rule's
## moments, its strike ready, not in its tunnels), the pool is asked for
## the next (rule.never_breaks: never mid-strike, in its wind-up, going
## home at the last light or fleeing a pot).
func _pool_step(delta: float) -> void:
	if pool == null:
		return
	if rule_moment():
		_end_unit("rule")
		return
	if _unit != null:
		_dwell_left -= delta
		if _unit.done or _dwell_left <= 0.0:
			_pool_due = true
	elif not _pool_due:
		# None could come last time: asked again in a while.
		_dwell_left -= delta
		if _dwell_left <= 0.0:
			_pool_due = true
	if _pool_due and not _in_tunnel():
		if _clear_way_out and on_way_out(base):
			# Kept still on the way out: off it on its rounds first.
			return
		_clear_way_out = false
		_draw_next()
	elif not _in_tunnel() and not _clear_way_out:
		_cut_in_step(delta)


## A state that may cut in (queue 66, BossState.cuts_in: the freeze, the
## moment you first catch sight of it from far off): every CUT_IN_S, when
## its needs turn true and it is not in charge, the pool weighs it against
## the one in charge (BossPool.draw_cut_in); if it wins it takes over at
## once (exit, then enter). Only while the boss is free (_pool_step).
func _cut_in_step(delta: float) -> void:
	if pool.cut_ins.is_empty():
		return
	_cut_t -= delta
	if _cut_t > 0.0:
		return
	_cut_t = CUT_IN_S
	for id in pool.cut_ins:
		var now := pool.unit(id).can_enter(self)
		var was := bool(_cut_was.get(id, false))
		_cut_was[id] = now
		if not now or was or id == behaviour:
			continue
		var cut := pool.draw_cut_in(id, behaviour)
		if draw_log.size() >= DRAW_LOG:
			draw_log.pop_front()
		draw_log.append({"id": id if cut else "", "state": state, "strike": strike.state, "tunnel": _in_tunnel(), "clock": clock, "cut_in": true})
		if not cut:
			continue
		_end_unit("cut")
		_pool_due = false
		behaviour = id
		_unit = pool.unit(id)
		_unit.done = false
		_dwell_left = pool.dwell(id)
		_exit_wait = 0.0
		_guard_at = base
		_unit.enter(self, _prev_behaviour)
		return


## The next state from the pool. The same one again (only when it is the
## only one that may come) goes on as it is, its time renewed; another
## takes over from the one in charge (exit, then enter).
func _draw_next() -> void:
	var ended_self := _unit != null and _unit.done
	var id := pool.draw(func(i: String) -> bool: return pool.unit(i).can_enter(self))
	if draw_log.size() >= DRAW_LOG:
		draw_log.pop_front()
	draw_log.append({"id": id, "state": state, "strike": strike.state, "tunnel": _in_tunnel(), "clock": clock})
	if id != "" and _unit != null and id == behaviour and not ended_self:
		_dwell_left = pool.dwell(id)
		_pool_due = false
		return
	if _unit != null:
		_end_unit("done" if ended_self else "dwell")
	_pool_due = false
	if id == "":
		# None may come now: its built behaviour meanwhile (back on its
		# rounds from wherever a state of its own left it: queue 66's leave
		# it lying still in states of their own, "freeze", "doorway"...).
		_dwell_left = POOL_RETRY_S
		resume_rounds()
		return
	behaviour = id
	_unit = pool.unit(id)
	_unit.done = false
	_dwell_left = pool.dwell(id)
	_exit_wait = 0.0
	_guard_at = base
	_unit.enter(self, _prev_behaviour)


## The state in charge is over (`why`: its dwell, itself, one of the rule's
## moments, the guards' light or way out): its exit, and the pool is asked
## at the next free tick.
func _end_unit(why: String) -> void:
	if _unit == null:
		return
	var u := _unit
	_unit = null
	_prev_behaviour = behaviour
	behaviour = ""
	_pool_due = true
	_exit_wait = 0.0
	states_ended[why] = int(states_ended.get(why, 0)) + 1
	u.why = why
	u.exit(self)


## A state of its pool in charge (not its built rounds, which the boss
## check holds to the rule), after its tick (rule.never_breaks): it never
## stays in the light (in a lit room or stretch outside the chase, the
## state is over and it leaves for the dark as built), and never waits on
## the way out (kept still there EXIT_WAIT_S, the state is over and it
## sets off on its rounds).
func _pool_guard(delta: float) -> void:
	if _unit == null or _unit.built() or rule_moment() or _in_tunnel():
		_exit_wait = 0.0
		_guard_at = base
		return
	var at := ground.node_at(base)
	if at >= 0 and not ground.is_ground(at):
		node = at
		_end_unit("light")
		_leave()
		return
	var moved := _flat(base - _guard_at).length() if _guard_at.is_finite() else INF
	_guard_at = base
	if moved <= STILL_MPS * delta and on_way_out(base):
		_exit_wait += delta
		if _exit_wait >= EXIT_WAIT_S:
			_end_unit("exit")
			_clear_way_out = true
			node = ground.node_at(base)
			_next_round()
	else:
		_exit_wait = 0.0


## Its pool swapped (tools: a test pool): the state in charge is over, and
## the new pool is asked at the next free tick.
func set_pool(p: BossPool) -> void:
	_end_unit("swap")
	pool = p
	_prev_behaviour = ""
	_pool_due = true


## The state in charge ends itself (BossState.done): the pool draws the
## next at the boss's next free tick.
func end_state() -> void:
	if _unit != null:
		_unit.done = true


## The state in charge has begun a move of its own that takes longer than
## its dwell has left (queue 66: going round behind you, lying in wait once
## it is there): the pool waits at least `s` more seconds. The rule's
## moments still end it at once.
func renew_dwell(s: float) -> void:
	if _unit != null:
		_dwell_left = maxf(_dwell_left, s)


## It lets you go (queue 66, coil_ambush walked away from): the chase off,
## and for `s` seconds its rounds don't take you up by sight or hearing,
## only you right by it (feels_m), and nothing of its pool that goes after
## you comes (BossStalk.may_stalk).
func let_go(s: float) -> void:
	_let_go("let_go")
	let_go_t = maxf(let_go_t, s)


## Its camouflage eased toward camo_want (never above camouflage.max_blend)
## and shown on its sprites: toward the stone it lies on, the ruin's one
## stone (RuinStyle), straying by that stone's own spread.
func _camo_tick(delta: float) -> void:
	var most := float((BossPool.DATA.get("camouflage", {}) as Dictionary).get("max_blend", 0.5))
	var want := clampf(camo_want, 0.0, most)
	if is_equal_approx(camo, want) and (body == null or is_equal_approx(body.camo, camo)):
		return
	camo = minf(move_toward(camo, want, delta / maxf(CAMO_EASE_S, 0.01) * maxf(most, 0.01)), most)
	if body != null:
		var th := str(lay.get("theme", ""))
		body.set_camouflage(camo, RuinStyle.tint(th), RuinStyle.spread(th))


## Back on its built rounds from wherever a state of its pool left it (the
## pool's 'rounds' taking over from another): coiling or prowling it
## carries on; else it sets off on its next round from where it is.
func resume_rounds() -> void:
	if rule_moment() or state in ["coil", "prowl"]:
		return
	node = ground.node_at(base)
	_next_round()


## Your lit torch still holds it off (rule.torch_in_hand delay): it hasn't
## struck since it found you, and hasn't yet held at your flame for
## torch_delay.hang_s.
func holding_off() -> bool:
	return _torch_lit() and not struck and hang_t < float(sub("torch_delay").get("hang_s", 4.0))


## The strike as built (§FA, queue 57; CreatureStrike): the only way a
## state of its pool strikes. Its tell and its wind-up come first, always
## (never_breaks wind_up_and_tell_always_play), and while your lit torch
## still holds it off it goes into the hold as built, the strike following
## from there (torch_hold_holds). Either way the chase is on (Pursuit) and
## the state is over (the strike and the chase are the rule's). True if
## the wind-up began now. `held_s` (queue 66): how long your lit flame has
## already held it off, the state lying back beyond the edge of your
## torch's bright circle (torch_delay.hang_m) while it stalked you: it
## counts toward torch_delay.hang_s, "in all", as the hold does.
func begin_strike(held_s := 0.0) -> bool:
	if player == null or strike.busy() or rule_moment():
		return false
	if not noticed:
		hang_t = 0.0
		struck = false
	hang_t = maxf(hang_t, held_s)
	noticed = true
	last_seen = player.global_position
	pursuit.notice(_torch_lit())
	coiling = false
	_replan_t = 0.0
	_hunt_to = Vector3.INF
	if holding_off() or not strike.begin():
		state = "hunt"
		return false
	state = "strike"
	return true


## On the way out (§EX.5): in a piece marked exit (the flight up and the
## landing to the daylight), or within EXIT_CLEAR_M of the middle of a
## doorway onto it or out of the tomb. No state of its pool waits there
## (never_blocks_exit).
func on_way_out(p: Vector3) -> bool:
	var pid := TombKit.piece_at(lay, p)
	if pid >= 0 and bool((lay.pieces[pid] as Dictionary).get("exit", false)):
		return true
	for q: Vector3 in _way_out_doors:
		if _flat(p - q).length() <= EXIT_CLEAR_M and absf(p.y - q.y) < 2.0:
			return true
	return false


## The doorways onto the way out: out of the tomb (no piece beyond), or
## into a piece marked exit; the middle of each on its floor.
func _find_way_out_doors() -> Array:
	var out: Array = []
	for d in lay.get("doors", []):
		var onto := int(d.b) < 0
		for side: int in [int(d.a), int(d.b)]:
			if side >= 0 and side < (lay.pieces as Array).size() and bool((lay.pieces[side] as Dictionary).get("exit", false)):
				onto = true
		if not onto:
			continue
		var dp: Variant = d.p
		if dp is Vector2:
			out.append(Vector3((dp as Vector2).x, float(d.y), (dp as Vector2).y))
		elif dp is Vector3:
			out.append(dp)
	return out


# --- The body and the sound -------------------------------------------------

## The point `s` metres back along the body from the head.
func _seg_at(s: float) -> Vector3:
	var acc := 0.0
	for i in range(trail.size() - 1):
		var a: Vector3 = trail[i]
		var b: Vector3 = trail[i + 1]
		var l := a.distance_to(b)
		if acc + l >= s:
			return a.lerp(b, (s - acc) / maxf(l, 1e-4))
		acc += l
	return trail[-1] if not trail.is_empty() else head


func _pose() -> void:
	if body == null:
		return
	if not body.visible and not (state in ["lair", "gone"]) and body.baked:
		body.visible = true
	var seg_pos: Array = []
	var seg_dir: Array = []
	var n := body.segs.size()
	var want := body.head_len * 0.45
	var i := 0
	var acc := 0.0
	var k := 0
	var last_dir := -dir
	while i < n:
		var p: Vector3
		var dv: Vector3
		if k < trail.size() - 1:
			var a: Vector3 = trail[k]
			var b: Vector3 = trail[k + 1]
			var l := a.distance_to(b)
			if acc + l < want:
				acc += l
				k += 1
				continue
			p = a.lerp(b, (want - acc) / maxf(l, 1e-4))
			dv = _flat(a - b)
			if dv.length() > 1e-4:
				last_dir = -dv.normalized()
		else:
			# Past the trail's end: straight on back.
			var end: Vector3 = trail[-1] if not trail.is_empty() else head
			p = end + last_dir * (want - acc)
			dv = -last_dir
		# The neck rises with the head and reaches with the lunge (and, at the
		# light's edge, into the glow).
		if i < NECK:
			var w := pow(1.0 - float(i) / NECK, 1.6)
			p += Vector3.UP * lift * w + dir * lunge * w * 0.6
		seg_pos.append(p)
		seg_dir.append(dv.normalized() if dv.length() > 1e-4 else dir)
		want += body.spacing
		i += 1
	var hp := head + Vector3.UP * lift + dir * lunge
	body.pose(hp, dir, mouth_open, seg_pos, seg_dir)
	# Where a swing has to reach to stagger it, and where its strike comes
	# from: its head. Its reach is measured from its body where it struck
	# from (base), not from the head as it lunges out (queue 57), so a step
	# back out of reach_m that it can't follow still makes it miss.
	strike.global_position = hp + Vector3(0.0, 0.2, 0.0)
	strike.origin = base
	# The tell sits in the body's thick, behind the head.
	if not seg_pos.is_empty():
		_tell.global_position = seg_pos[mini(4, seg_pos.size() - 1)]
		_hiss.global_position = hp


## Its hiss at your flame while it holds off: a low, slow warning of its
## own (bosses.json torch_delay.sound, SoundSynth snake_warn), never its
## strike's sharp hiss (strike.sound), so that one always means the strike
## is coming (§FA.2, queue 57); `which` another voice (a fire pot's stun:
## the sharp hiss, as it reels).
func _play_hiss(which := "") -> void:
	if _hiss == null:
		return
	var kind := which if which != "" else str(sub("torch_delay").get("sound", "snake_warn"))
	_hiss.stream = SoundSynth.stream(kind, _rng.randi())
	if _hiss.is_inside_tree():
		Audio3D.play(_hiss)


## The tell: loud on the move, softer reared and still, quiet coiled,
## muffled in its tunnels (tunnels.muffle_db, muffle_hz); none down its
## hole or once it has gone home.
func _sound_tick(delta: float) -> void:
	if _tell == null:
		return
	var want := -INF
	match state:
		"prowl", "hunt", "leave", "flee", "release", "rise":
			want = 0.0
		"coil":
			want = -2.0 if coiling else -14.0
		"hang", "strike", "watch", "held":
			want = -8.0 if speed < 0.1 else -2.0
		"stunned":
			want = -12.0
		_:
			# A state of its pool in a state of its own (queue 66): its own
			# level (BossState.tell_db).
			if _unit != null and not _unit.built():
				want = _unit.tell_db(self)
	tell_want = want
	var tun := sub("tunnels")
	var inside := _in_tunnel()
	if inside and want > -INF:
		want += float(tun.get("muffle_db", -14.0))
	_tell.attenuation_filter_cutoff_hz = float(tun.get("muffle_hz", 700.0)) if inside else _tell_cutoff
	if want == -INF:
		if _tell.playing:
			_tell.stop()
		return
	if not _tell.playing and _tell.is_inside_tree():
		Audio3D.play(_tell)
	_tell.volume_db = lerpf(_tell.volume_db, want, clampf(delta * 3.0, 0.0, 1.0))
	var base_speed := maxf(num("speed_mps", 2.0), 0.1)
	_tell.pitch_scale = clampf(0.75 + 0.25 * speed / base_speed, 0.7, 1.3) if state != "coil" or coiling else 0.72


## The tomb's small sounds (release.bed_returns): hushed while it prowls,
## back once it has gone home.
func _bed_tick(delta: float) -> void:
	if bed == null:
		return
	var hush := float(RELEASE.get("bed_hush_db", -18.0)) if bool(RELEASE.get("bed_returns", true)) else 0.0
	var want := bed_db + hush
	if state in ["lair", "gone"]:
		if _bed_t >= 0.0:
			_bed_t += delta
		var k := clampf(_bed_t / maxf(float(RELEASE.get("bed_return_s", 4.0)), 0.1), 0.0, 1.0)
		want = lerpf(bed_db + hush, bed_db, k)
		bed.volume_db = want
		return
	bed.volume_db = want
