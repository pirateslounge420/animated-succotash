class_name Creature
extends Node3D
## One living creature. It keeps its own spot on the planet as a surface
## direction (so the floating origin never disturbs it) and re-derives its
## scene position every frame, standing on the ground, floating on water,
## perching in a tree crown or flying.
##
## Behavior by habitat role (DESIGN.md "Creature Spawning"):
##   ground      wander near home, graze, now and then walk to nearby
##               water to drink; bolt away when you get close, then stay
##               wary (standing, watching you) until it calms down
##   canopy      perch in one tree's crown; hop or fly to another tree
##   water_edge  waders stand and step in the shallows, ducks paddle on open
##               water; both take off when startled
##   swarm       fireflies drifting over one spot
##   insect      beetles scurry out from under a log, then burrow away
##   pack        driven by CreatureSpawner: rest / patrol / close in / retreat
##   mythical    driven by CreatureSpawner's territory states; temperament
##               sets what "visible" means: hostile stalks at a distance and
##               freezes when looked at, neutral watches, friendly comes over
## How close is "close" depends on how loud you are (the player's
## noise_level: crouched and still, you can get within a third of a
## creature's shy_m; sprinting, it bolts from half again as far) and on its
## suspicion (1 after it's been startled). Suspicion fades while you keep
## still near it (a few seconds) or stay well away (slowly).
##
## It also hears noises out in the world (NoiseEvents: an arrow or the
## spear landing, _hear()): close enough, it startles and runs from the
## noise as if you'd come too close; a little farther, it grows
## suspicious.
##
## In water they ring it (Ripples): wading legs and paddling hulls drag
## wakes, footfalls splash (_water_contacts).
##
## Hitboxes (spec D5; CreatureHitboxes): parts on the body that arrows
## and the bow's aim meet (Hitboxes), and for the bigger ones a blocker
## the player bumps into. They're on only while it's shown, alive, faded
## in, and within Hitboxes.ACTIVE_M of the player or near an arrow in
## flight (_sync_hitboxes()).
##
## Arrows hurt them (hurt()): hit points by size (CreatureSpecies.hp_max()).
## Where the hit lands matters (Hits: the part's multiplier from the
## species' "hit_parts"): a head or eye hit is a critical, an eye hit
## blinds that side (`blind`: it notices you there late), a limb hit lames
## it (`lame`: slower, and it limps). Its health is never drawn; the
## HUD's rising number and its behaviour are the readout.
## Prey bolts; pack hunters and hostile creatures turn on you (`angry`:
## chase and bite, CreatureSpawner.player_hit()); at 0 they die, tip over
## and fade after a while.

signal finished(creature: Creature)
## Hit by the player (CreatureSpawner reacts: the pack turns on you, a
## mythical vanishes or fights).
signal hurt_by_player(creature: Creature, killed: bool)

var species: CreatureSpecies
var world: Node
var chunks: ChunkManager
var spawner: Node

var dir := Vector3.UP # where on the planet
var heading := Vector3.FORWARD # tangent direction it faces
var lift := 0.0 # meters above the ground (or the water, when afloat)
var afloat := false
var home := Vector3.UP # tether point
## How far a drifting swarm wanders from home (m): fireflies over a
## meadow; pollinators close round the bloom that drew them (AroidGarden).
var drift_m := 6.0
var home_radius := 20.0
var host := {} # canopy: {"dir", "base", "height"}
var mode := "idle"
var goal := Vector3.ZERO
var goal_speed := 0.0
var keep_away_m := 0.0 # pack / mythical: stay this far from goal
var ring_offset := 0.0 # pack: slot angle around the player
var voice: AudioStreamPlayer3D
var voice_variant := 0
var leaving := false
var done := false
var fly_off := false
## 0-1: how wary it still is after being startled.
var suspicion := 0.0
var hp := 1.0
var dead := false
## Seconds it keeps hunting you (chase and bite); 0 = not attacking.
var angry := 0.0
var _bite_cd := 0.0
var _dead_t := 0.0
var _flash := 0.0
var _panic := 0.0 # seconds it keeps bolting after being hit, however far
## Wounds (hurt(), _wound()): the share of its speed a hurt leg leaves it
## (1: sound; it limps below 1), and the sides it's blind on ("l", "r",
## or "both" for a single eye) and so notices you there late
## (sight_toward()).
var lame := 1.0
var blind := {}
## Seconds it's still pinned where it stands by a super-thrown spear
## (design §S; combat overcharge.spear.pin): it can't move off.
var pinned_t := 0.0
## Rigs animate only this near the player (design §W; data/look.json
## ranges.rig_m); beyond it a creature still moves but holds its pose.
static var RIG_M := float(Tuning.section("look", "ranges").get("rig_m", 60.0))
var _rig_near := true
var _limp_side := 1.0
## Fleeing from a noise (NoiseEvents) at this surface direction, not from
## the player; ZERO for the player.
var _scare := Vector3.ZERO
## The last noise it has heard (NoiseEvents), so each is heard once.
var _heard_id := 0
## Dead, it falls onto this side (1: its left, the right side up; -1: its
## right), away from the killing blow.
var _topple := 1.0

var _parts := {}
var _body: Node3D
## Its collision bodies (Hitboxes): the parts, then the blocker if it has
## one. The Night Rider and the Pond Crawler make their own.
var hitboxes: Array = []
var _hitboxes_on := true
## Near enough for its hitboxes to be wanted, each tick: within
## Hitboxes.ACTIVE_M of the player or Hitboxes.ARROW_WAKE_M of an arrow in
## flight.
var _hitboxes_near := true
## Soft shadow on the ground under it (BlobShadow); null for none.
var _blob: MeshInstance3D
var _blob_size := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _anim := 0.0
var _speed_now := 0.0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_lift := Vector2.ZERO
var _hop_t := 0.0
var _hop_len := 1.0
var _fade := 0.0
var _call_timer := 0.0
## Ambient creatures call only within this many meters of the player.
const CALL_M := 40.0
## And no two calls of the same kind within this long of each other.
const SAME_CALL_GAP_MS := 4000
## Role -> the voice's row in the falloff table (Audio3D); anything else
## is "wildlife_call".
const VOICE_KINDS := {"pack": "howl", "mythical": "mythic_call"}
static var _last_call := {}
var _life := -1.0


var _ground_q := Vector3.INF
var _ground_h := 0.0
var _water_q := Vector3.INF
var _water_h := 0.0
## What the body was last placed from ([dir, lift, heading]) and scaled
## to, so a still animal isn't moved again every tick.
var _placed: Array = [Vector3.ZERO, 0.0, Vector3.ZERO]
var _replace_t := 0.0
var _scaled := -1.0
var _legs_moving := true
## Time skipped by the spawner's level of detail (far animals tick less
## often), handed to the next tick; and which frame of the cycle this one
## ticks on.
var lod_delta := 0.0
var lod_phase := 0
## Half strides taken (_animate's cycle), for footfalls in water.
var _stride_n := 0


func setup(sp: CreatureSpecies, p_world: Node, p_chunks: ChunkManager, p_spawner: Node, d: Vector3, seed_value: int) -> void:
	species = sp
	world = p_world
	chunks = p_chunks
	spawner = p_spawner
	hp = sp.hp_max()
	dir = d
	home = d
	_rng.seed = seed_value
	lod_phase = seed_value & 3
	name = sp.name.replace(" ", "_")
	heading = CubeSphere.north(d).rotated(d, _rng.randf() * TAU)
	_parts = CreatureBodies.build(sp)
	_body = _parts.root
	add_child(_body)
	hitboxes = CreatureHitboxes.build(self, _parts, sp, CreatureHitboxes.blocks(sp))
	# Off until it has faded in.
	_set_hitboxes(false)
	_blob_size = BlobShadow.footprint(sp)
	if _blob_size != Vector2.ZERO:
		_blob = BlobShadow.make(self, _blob_size.x, _blob_size.y)
	home_radius = clampf(sp.one_per_radius_m * 0.6, 8.0, 60.0)
	if sp.sound != "none":
		voice = AudioStreamPlayer3D.new()
		voice_variant = _rng.randi_range(0, SoundSynth.VARIANTS - 1)
		voice.stream = SoundSynth.stream(sp.sound, voice_variant)
		voice.pitch_scale = clampf(0.9 / pow(maxf(sp.size_m, 0.05), 0.15), 0.6, 1.6) * _rng.randf_range(0.93, 1.07)
		# Heard about as far as it can be found: small wildlife within a
		# stone's throw, a pack's howls and the mythical a few hundred
		# meters off, dull and hard to place far away (Audio3D, the
		# falloff table data/audio.json).
		Audio3D.apply(voice, VOICE_KINDS.get(sp.role, "wildlife_call"))
		voice.volume_db = -6.0
		voice.position = Vector3(0, sp.size_m * 0.6, 0)
		add_child(voice)
	_call_timer = _rng.randf_range(2.0, 12.0)
	match sp.role:
		"canopy":
			mode = "perch"
		"water_edge":
			afloat = sp.needs.get("open_water", false)
			mode = "idle"
		"swarm":
			mode = "drift"
		"insect":
			mode = "scurry"
			_life = _rng.randf_range(12.0, 22.0)
		_:
			mode = "idle"
	_timer = _rng.randf_range(0.5, 4.0)


## Perch in a tree crown (canopy dwellers).
func set_host(h: Dictionary) -> void:
	host = h
	dir = _perch_dir(h)
	lift = _perch_lift(h)


## Fade out and free itself (walked out of range, or its time of day ended).
func leave() -> void:
	leaving = true


## Show or hide the body (mythical creatures are heard before they're seen).
func set_visible_body(v: bool) -> void:
	_body.visible = v
	_update_blob()
	_sync_hitboxes()


## Hitboxes on only while it's shown, alive, at least half faded in (not
## while hidden, dead, fading in or leaving) and near the player or an
## arrow.
func _sync_hitboxes() -> void:
	_set_hitboxes(_body.visible and not dead and not leaving and _fade >= 0.5 and _hitboxes_near)


func _set_hitboxes(on: bool) -> void:
	if on != _hitboxes_on:
		_hitboxes_on = on
		Hitboxes.set_active(hitboxes, on)


func say() -> void:
	if voice == null or voice.stream == null or voice.playing:
		return
	# The same kind of call never overlaps itself from two creatures: a
	# chorus of identical chirps reads as a loop, not as wildlife. A pack's
	# howls are the exception: members answering the leader is the chorus.
	var now := Time.get_ticks_msec()
	if species.role != "pack" and now < int(_last_call.get(species.sound, 0)) + SAME_CALL_GAP_MS:
		return
	_last_call[species.sound] = now
	Audio3D.play(voice)


func distance_to(d: Vector3) -> float:
	return CubeSphere.surface_distance_m(dir, d)


func tick(delta: float, ctx: Dictionary) -> void:
	if done:
		return
	_timer -= delta
	var player_dir: Vector3 = ctx.player_dir
	# Up a tree, you're that much farther off (ctx "player_above_m").
	var to_player := Vector2(distance_to(player_dir), float(ctx.get("player_above_m", 0.0))).length()
	_rig_near = to_player < RIG_M
	_hitboxes_near = to_player < Hitboxes.ACTIVE_M or Arrow.near(global_position, Hitboxes.ARROW_WAKE_M)

	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			leave()

	if dead:
		_dead_t += delta
		_speed_now = 0.0
		if _dead_t > 14.0 and not leaving:
			leave()
		_fade = move_toward(_fade, 0.0 if leaving else 1.0, delta * 1.0)
		if leaving and _fade <= 0.0:
			done = true
			finished.emit(self)
			return
		_place(delta)
		return
	if pinned_t > 0.0:
		# Pinned by a spear: it struggles where it stands.
		pinned_t -= delta
		_speed_now = 0.0
		_place(delta)
		return
	if angry > 0.0:
		_attack(delta, ctx, to_player)
		_place(delta)
		return

	var shy := _shy_m(ctx, to_player)
	_calm(delta, ctx, to_player, shy)
	_hear()
	# The territorial charge (species.charge_m): a crocodile, a hippo, a
	# buffalo comes for you unprovoked once you're this near, nearer if
	# you're quiet and still, further if you're loud.
	if species.charge_m > 0.0 and species.bite > 0.0 and not leaving and (not afloat or bool(ctx.get("player_swimming", false))):
		var noise: float = ctx.get("player_noise", 0.5)
		var still: float = ctx.get("player_still", 0.0)
		var reach := species.charge_m * (0.55 + 0.9 * noise) * (0.7 if still > 2.0 else 1.0)
		if to_player < reach * sight_toward(ctx.player_dir):
			angry = 25.0
			say()
			_attack(delta, ctx, to_player)
			_place(delta)
			return
	match species.role:
		"ground":
			_ground(delta, player_dir, to_player, shy)
		"canopy":
			_canopy(delta, player_dir, to_player, shy)
		"water_edge":
			_water_edge(delta, player_dir, to_player, shy)
		"swarm":
			_drift(delta)
		"insect":
			_scurry(delta)
		"pack", "mythical":
			_driven(delta, ctx)

	# Occasional calls while active and not fleeing, and only close enough
	# to spot the caller.
	if voice and species.role != "pack" and species.role != "mythical":
		_call_timer -= delta
		if _call_timer <= 0.0:
			_call_timer = _call_interval()
			if mode != "flee" and not leaving and distance_to(ctx.player_dir) < CALL_M:
				say()

	_fade = move_toward(_fade, 0.0 if leaving else 1.0, delta * 1.5)
	if leaving and _fade <= 0.0:
		done = true
		finished.emit(self)
		return
	_place(delta)


## Hit for `amount` (an arrow or the spear from the player at scene
## position `from_pos`) on `part` (Hits: "body", "head", "limb", "eye_l",
## "eye_r", "eye") at scene position `at` (INF: its middle). The part's
## multiplier from the species' hit table applies, and its wound (_wound():
## a limb lames it, an eye blinds that side); the hit is reported for the
## HUD's number and X (Hits.report()).
func hurt(amount: float, from_pos: Vector3, part := "body", at := Vector3.INF) -> void:
	if dead or done:
		return
	var table := species.hit_table()
	var dealt := Hits.dealt(table, part, amount)
	_wound(table, part, at)
	hp -= dealt
	if at == Vector3.INF:
		at = global_position + global_basis.y * species.size_m * 0.5
	Hits.report(self, at, dealt, Hits.critical(part), hp <= 0.0)
	_flash = 1.0
	suspicion = 1.0
	if hp <= 0.0:
		dead = true
		angry = 0.0
		mode = "dead"
		_topple = 1.0 if _body.global_basis.x.dot(from_pos - global_position) >= 0.0 else -1.0
		lift = 0.0
		_set_hitboxes(false)
		if voice and voice.stream:
			voice.pitch_scale *= 0.8
			Audio3D.play(voice)
		hurt_by_player.emit(self, true)
		return
	if species.bite > 0.0:
		angry = 40.0
	elif species.role != "mythical":
		# Prey bolts, from where the arrow came.
		mode = "flee"
		fly_off = species.role == "canopy" or species.role == "water_edge"
		_timer = 6.0
		_panic = 5.0
	hurt_by_player.emit(self, false)


## What a hit on `part` leaves (the hit table's rules): a limb lames it
## (its speed times limb_slow each time, never under limb_slow_floor; it
## limps, rolling toward the side it was hit on, `at`), an eye blinds that
## side (a single eye, both) if eye_blinds.
func _wound(table: Dictionary, part: String, at: Vector3) -> void:
	match Hits.kind_of(part):
		"limb":
			lame = maxf(lame * float(table.get("limb_slow", 1.0)), float(table.get("limb_slow_floor", 0.0)))
			if at != Vector3.INF:
				_limp_side = 1.0 if global_basis.x.dot(at - global_position) >= 0.0 else -1.0
		"eye":
			if bool(table.get("eye_blinds", false)):
				var side := Hits.side_of(part)
				blind[side if side != "" else "both"] = true


## How well it sees toward surface direction `d`: 1, or on a side it's
## blind on, hits.blind_notice (it notices you there only that much
## closer).
func sight_toward(d: Vector3) -> float:
	if blind.is_empty():
		return 1.0
	if blind.has("both"):
		return float(Hits.hits().blind_notice)
	var side := "r" if _tangent_to(d).dot(heading.cross(dir)) >= 0.0 else "l"
	return float(Hits.hits().blind_notice) if blind.has(side) else 1.0


## Chase the player and bite when in reach; give up when they're far.
func _attack(delta: float, ctx: Dictionary, to_player: float) -> void:
	angry -= delta
	_bite_cd -= delta
	var pd: Vector3 = ctx.player_dir
	if to_player > 70.0:
		angry = 0.0
		return
	var reach := 0.9 + species.size_m * 0.45
	# By a lit fire you're safe: it gives up and goes.
	if Campfire.lit_near(get_tree(), world.to_scene(pd, PlanetConst.RADIUS_M + _ground_at(pd)), Tuning.num("combat", "death", "fire_safe_m")):
		angry = 0.0
		return
	# A creature that lives in the water (afloat: sharks, crocodiles out
	# in the open) hunts only while you're in it too, and never beaches
	# itself: it circles at the shallows if you get out.
	if afloat:
		if not bool(ctx.get("player_swimming", false)):
			angry = minf(angry, 4.0)
			mode = "idle"
			_speed_now = 0.0
			return
		if to_player > reach:
			mode = "go"
			_walk(pd, species.speed_mps * 1.15, delta, true)
		else:
			_speed_now = 0.0
			heading = _tangent_to(pd)
			if _bite_cd <= 0.0:
				_bite_cd = 1.3
				spawner.player_hit(species.bite, global_position, species.name)
		return
	if to_player > reach:
		mode = "go"
		_walk(pd, species.speed_mps * 1.15, delta)
	else:
		_speed_now = 0.0
		heading = _tangent_to(pd)
		if _bite_cd <= 0.0:
			_bite_cd = 1.3
			spawner.player_hit(species.bite, global_position, species.name)


func _call_interval() -> float:
	match species.sound:
		"croak":
			return _rng.randf_range(6.0, 16.0)
		"chirp":
			return _rng.randf_range(8.0, 22.0)
	return _rng.randf_range(15.0, 40.0)


# --- Roles ---------------------------------------------------------------------

## Flight distance now: shy_m scaled by the player's noise, widened by
## suspicion, and narrowed where it's blind (sight_toward()). The seeing
## part (the 0.35 a silent player still gets) is cut by the leaves between
## its eyes and you (design §AM 2, FoliageCover: ctx "cover", the clusters
## round you when you're in or under a crown): a still player in a crown
## is only heard, not seen.
func _shy_m(ctx: Dictionary, to_player := INF) -> float:
	var noise: float = ctx.get("player_noise", 0.4)
	var sight := sight_toward(ctx.player_dir) if ctx.has("player_dir") else 1.0
	var seen := 1.0
	# Torchlight (design 30 Sept §AW; creature_species light_response):
	# "flee" / "avoid" / "shy": a light on it reads as a presence come
	# close; "drawn": it hides you less. "none" or unset: nothing.
	var torchlight := Torch.light_at(global_position) if species.light_response != "" and species.light_response != "none" else 0.0
	if torchlight > 0.0:
		match species.light_response:
			"flee", "avoid", "shy":
				noise = maxf(noise, torchlight)
			"drawn":
				seen *= 1.0 - 0.5 * torchlight
	var cover: Array = ctx.get("cover", [])
	if not cover.is_empty() and to_player < species.shy_m * 4.0 * (1.0 + suspicion):
		var eye := global_position + global_basis.y * maxf(species.size_m * 0.6, 0.2)
		seen = FoliageCover.see_through(eye, ctx.player_eye, cover)
	return species.shy_m * (0.35 * seen + 1.25 * noise) * (1.0 + suspicion) * sight


## Noises out in the world (NoiseEvents: an arrow or the spear landing):
## within the noise's radius, widened by suspicion the way the flight
## distance is (_shy_m), prey startles as if you'd come too close and
## runs from the noise; within twice that it grows suspicious (a grazer
## stops and watches). Pack and mythical creatures are driven by the
## spawner and don't; nor do fireflies and beetles.
func _hear() -> void:
	var events := NoiseEvents.since(_heard_id)
	if events.is_empty():
		return
	for e in events:
		_heard_id = e.id
		if species.shy_m <= 0.0 or not species.role in ["ground", "canopy", "water_edge"]:
			continue
		var d := global_position.distance_to(e.pos)
		var r: float = e.radius * (1.0 + suspicion)
		if d < r:
			_startle(world.dir_of(e.pos))
		elif d < r * 2.0:
			suspicion = maxf(suspicion, 0.5)
			if species.role == "ground" and mode in ["idle", "walk", "to_water", "drink"]:
				_body.rotation.x = 0.0
				mode = "wary"


## Startled by a noise at surface direction `from`: the same as the
## player coming too close (_ground, _canopy, _water_edge), away from the
## noise.
func _startle(from: Vector3) -> void:
	suspicion = 1.0
	match species.role:
		"ground":
			# Already running from you (or hit): it keeps to that.
			if mode == "flee" and _scare == Vector3.ZERO:
				return
			if mode != "flee":
				mode = "flee"
				_body.rotation.x = 0.0
				_timer = _rng.randf_range(3.0, 6.0)
			_scare = from
			_panic = maxf(_panic, 2.5)
		"canopy":
			if mode == "perch":
				var next: Dictionary = spawner.host_near(dir, 25.0, host, from)
				if not next.is_empty():
					_hop(_perch_dir(next), _perch_lift(next))
					host = next
		"water_edge":
			if not fly_off:
				fly_off = true
				heading = -_tangent_to(from)
				spawner.cooldown(self)


## Suspicion fades while the player keeps still nearby (it's watching you
## and nothing happens), slowly when you're far off.
func _calm(delta: float, ctx: Dictionary, to_player: float, shy: float) -> void:
	if suspicion <= 0.0:
		return
	var still: float = ctx.get("player_still", 0.0)
	if still > 1.5 and to_player < shy * 4.0 + 10.0:
		suspicion -= delta / 6.0
	elif to_player > shy * 3.0:
		suspicion -= delta / 25.0
	suspicion = maxf(suspicion, 0.0)


func _ground(delta: float, player_dir: Vector3, to_player: float, shy: float) -> void:
	if species.shy_m > 0.0 and to_player < shy and (mode != "flee" or _scare != Vector3.ZERO):
		mode = "flee"
		suspicion = 1.0
		_scare = Vector3.ZERO
		_body.rotation.x = 0.0
		_timer = _rng.randf_range(3.0, 6.0)
	match mode:
		"flee":
			# From you, or from a noise (_startle()).
			var away := -_tangent_to(player_dir if _scare == Vector3.ZERO else _scare)
			_walk(dir + away * 0.001, species.speed_mps, delta)
			_panic -= delta
			if (_timer <= 0.0 or to_player > shy * 2.5) and _panic <= 0.0:
				_scare = Vector3.ZERO
				mode = "wary"
				home = dir
				_timer = _rng.randf_range(2.0, 6.0)
		"wary":
			# Stands and watches you until its suspicion has faded.
			_speed_now = 0.0
			var t := _tangent_to(player_dir)
			heading = heading.slerp(t, clampf(delta * 3.0, 0.0, 1.0)).normalized()
			if suspicion <= 0.0:
				mode = "idle"
				_timer = _rng.randf_range(1.0, 3.0)
		"idle":
			_speed_now = 0.0
			if _timer <= 0.0:
				if _rng.randf() < DRINK_CHANCE and _go_drink():
					return
				goal = _random_near(home, home_radius)
				mode = "walk" if _is_dry(goal) else "idle"
				_timer = _rng.randf_range(1.0, 3.0)
		"walk":
			var left := _walk(goal, species.speed_mps * 0.35, delta)
			if left < 0.5 or _timer < -20.0:
				mode = "idle"
				_timer = _rng.randf_range(2.0, 8.0)
		"to_water":
			var left := _walk(goal, species.speed_mps * 0.35, delta)
			if left < 0.5:
				mode = "drink"
				_timer = _rng.randf_range(5.0, 9.0)
			elif _timer < -25.0:
				mode = "idle"
				_timer = _rng.randf_range(2.0, 5.0)
		"drink":
			# Head down at the water's edge, then back to its usual ground.
			_speed_now = 0.0
			_body.rotation.x = lerpf(_body.rotation.x, -0.3, clampf(delta * 4.0, 0.0, 1.0))
			if _timer <= 0.0:
				_body.rotation.x = 0.0
				goal = _random_near(home, home_radius * 0.5)
				mode = "walk" if _is_dry(goal) else "idle"
				_timer = _rng.randf_range(1.0, 3.0)


## Now and then a grazer wanders off to drink (flavor, not a needs
## simulation): open water within DRINK_REACH_M, walking to the last dry
## ground before it.
const DRINK_CHANCE := 0.08
const DRINK_REACH_M := 45.0


func _go_drink() -> bool:
	var a0 := _rng.randf() * TAU
	for k in 12:
		var a := a0 + k * TAU / 12.0
		var prev := dir
		for step in range(1, 7):
			var p := CreatureSpawner._offset(dir, a, DRINK_REACH_M * step / 6.0)
			if not _is_dry(p):
				if step == 1:
					break
				goal = prev
				mode = "to_water"
				_timer = 0.0
				return true
			prev = p
	return false


func _canopy(delta: float, player_dir: Vector3, to_player: float, shy: float) -> void:
	match mode:
		"perch":
			_speed_now = 0.0
			var startled := species.shy_m > 0.0 and to_player < shy
			if startled:
				suspicion = 1.0
			if startled or _timer <= 0.0:
				var next: Dictionary = spawner.host_near(dir, 12.0 if not startled else 25.0, host, player_dir if startled else Vector3.ZERO)
				if next.is_empty():
					_timer = _rng.randf_range(4.0, 12.0)
				else:
					_hop(_perch_dir(next), _perch_lift(next))
					host = next
		"hop":
			_hop_step(delta)
			if _hop_t >= 1.0:
				mode = "perch"
				_timer = _rng.randf_range(6.0, 25.0)


func _water_edge(delta: float, player_dir: Vector3, to_player: float, shy: float) -> void:
	if fly_off:
		# Took off: climb away and vanish.
		lift += delta * 2.5
		dir = (dir + heading * species.speed_mps * 6.0 * delta / PlanetConst.RADIUS_M).normalized()
		_speed_now = 6.0
		if lift > 25.0:
			leave()
		return
	if species.shy_m > 0.0 and to_player < shy:
		suspicion = 1.0
		if afloat and to_player > shy * 0.45:
			mode = "flee"
		else:
			fly_off = true
			heading = -_tangent_to(player_dir)
			spawner.cooldown(self)
			return
	match mode:
		"flee":
			_walk(dir - _tangent_to(player_dir) * 0.001, species.speed_mps * 2.0, delta, true)
			if to_player > shy * 1.5:
				mode = "idle"
		"idle":
			_speed_now = 0.0
			if _timer <= 0.0:
				var g := _random_near(home, 15.0)
				if _water_ok(g):
					goal = g
					mode = "walk"
				_timer = _rng.randf_range(3.0, 10.0)
		"walk":
			if _walk(goal, species.speed_mps, delta, true) < 0.4 or _timer < -15.0:
				mode = "idle"
				_timer = _rng.randf_range(4.0, 14.0)


func _drift(delta: float) -> void:
	if _timer <= 0.0:
		goal = _random_near(home, drift_m)
		_timer = _rng.randf_range(4.0, 10.0)
	_walk(goal, species.speed_mps, delta, false, false)
	lift = 0.0


func _scurry(delta: float) -> void:
	if _timer <= 0.0:
		heading = heading.rotated(dir, _rng.randf_range(-1.2, 1.2))
		_timer = _rng.randf_range(0.3, 1.2)
	_walk(dir + heading * 0.001, species.speed_mps, delta)


## Pack and mythical creatures: CreatureSpawner sets `mode` and `goal`.
##   rest      stand still near goal
##   go        walk to goal
##   ring      hold `keep_away_m` from goal (the player), slot `ring_offset`
##   stalk     hold keep_away_m, freeze while the player looks at it
##   watch     stand and face the player
func _driven(delta: float, ctx: Dictionary) -> void:
	var player_dir: Vector3 = ctx.player_dir
	var bob := 0.0
	match mode:
		"rest":
			_speed_now = 0.0
			if _timer <= 0.0 and distance_to(goal) > 3.0:
				_walk(goal, species.speed_mps * 0.3, delta)
		"go":
			if _walk(goal, goal_speed if goal_speed > 0.0 else species.speed_mps * 0.4, delta) < 1.0:
				# Arrived: turn to look at the player.
				_speed_now = 0.0
				var t := _tangent_to(player_dir)
				if distance_to(player_dir) < 80.0 and t.length() > 0.5:
					heading = heading.slerp(t, clampf(delta * 3.0, 0.0, 1.0)).normalized()
		"ring", "stalk":
			var looked_at: bool = mode == "stalk" and ctx.get("looking_at", {}).has(self)
			var d := distance_to(player_dir)
			var to_p := _tangent_to(player_dir)
			var side := to_p.cross(dir).normalized()
			var want := Vector3.ZERO
			if d > keep_away_m + 2.0:
				want += to_p
			elif d < keep_away_m - 2.0:
				want -= to_p
			if mode == "ring":
				want += side * sin(ring_offset + Time.get_ticks_msec() * 0.0002) * 0.6
			if looked_at:
				_speed_now = 0.0
			elif want.length() > 0.1:
				var sp := species.speed_mps * (0.8 if mode == "ring" else 0.6)
				_walk(dir + want.normalized() * 0.001, sp, delta)
			else:
				_speed_now = 0.0
			heading = to_p if to_p.length() > 0.5 else heading
		"watch":
			_speed_now = 0.0
			var t := _tangent_to(player_dir)
			if t.length() > 0.5:
				heading = heading.slerp(t, clampf(delta * 2.0, 0.0, 1.0)).normalized()
	if species.shape == "wisp":
		bob = sin(Time.get_ticks_msec() * 0.0015 + ring_offset) * 0.4
		lift = 0.6 + bob


# --- Movement ------------------------------------------------------------------

## Unit tangent from here toward a surface direction.
func _tangent_to(d: Vector3) -> Vector3:
	var t := d - dir * dir.dot(d)
	if t.length_squared() < 1e-14:
		return heading
	return t.normalized()


## Step toward a surface direction; returns the remaining distance in m.
## Land walkers refuse to step into water; swimmers refuse to leave it.
## A lame animal goes at `lame` of the speed asked.
func _walk(target: Vector3, speed: float, delta: float, in_water := false, turn := true) -> float:
	speed *= lame
	var left := distance_to(target)
	if left < 0.05:
		_speed_now = 0.0
		return left
	var t := _tangent_to(target)
	var step := minf(speed * delta, left)
	var next := (dir + t * step / PlanetConst.RADIUS_M).normalized()
	var flies := species.role == "swarm" or species.shape == "wisp"
	var ok := _water_ok(next) if in_water else (flies or _is_dry(next))
	if not ok:
		heading = heading.rotated(dir, PI * 0.6)
		_speed_now = 0.0
		_timer = minf(_timer, 0.5)
		if mode == "walk":
			mode = "idle"
		return left
	dir = next
	if turn:
		heading = heading.slerp(t, clampf(delta * 8.0, 0.0, 1.0)).normalized()
	_speed_now = speed
	return left - step


func _hop(to_dir: Vector3, to_lift: float) -> void:
	_hop_from = dir
	_hop_to = to_dir
	_hop_lift = Vector2(lift, to_lift)
	_hop_t = 0.0
	_hop_len = maxf(CubeSphere.surface_distance_m(dir, to_dir) / (species.speed_mps * lame), 0.4)
	heading = _tangent_to(to_dir)
	mode = "hop"


func _hop_step(delta: float) -> void:
	_hop_t = minf(_hop_t + delta / _hop_len, 1.0)
	dir = _hop_from.slerp(_hop_to, _hop_t).normalized()
	lift = lerpf(_hop_lift.x, _hop_lift.y, _hop_t) + sin(_hop_t * PI) * minf(2.0 + _hop_len, 6.0)
	_speed_now = species.speed_mps


## Birds and climbers sit on top of the crown, where you can spot them
## against the sky; tree frogs cling to the trunk lower down.
func _perch_dir(h: Dictionary) -> Vector3:
	var d: Vector3 = h.dir
	var off := CubeSphere.north(d).rotated(d, _rng.randf() * TAU)
	var r: float = h.height * (0.06 if species.body != "frog" else 0.05)
	return (d + off * r / PlanetConst.RADIUS_M).normalized()


func _perch_lift(h: Dictionary) -> float:
	var frac := 0.97 if species.body != "frog" else _rng.randf_range(0.25, 0.45)
	return h.base - PlanetConst.RADIUS_M - chunks.ground_height(h.dir) + h.height * frac


func _random_near(center: Vector3, radius: float) -> Vector3:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * radius
	var t := CubeSphere.north(center).rotated(center, a)
	return (center + t * r / PlanetConst.RADIUS_M).normalized()


func _is_dry(d: Vector3) -> bool:
	return _water_at(d) < _ground_at(d) + 0.08


## Water creatures: waders need 5-60 cm of water, swimmers at least 40 cm.
func _water_ok(d: Vector3) -> bool:
	var depth := _water_at(d) - _ground_at(d)
	if afloat:
		return depth > 0.4
	return depth > 0.03 and depth < 0.6


## Ground and water height at `d`, remembering the last spot asked about:
## a step is checked (_is_dry) and then stood on (_place) at the same spot.
func _ground_at(d: Vector3) -> float:
	if d != _ground_q:
		_ground_q = d
		_ground_h = chunks.ground_height(d)
	return _ground_h


func _water_at(d: Vector3) -> float:
	if d != _water_q:
		_water_q = d
		_water_h = chunks.water_level_at(d)
	return _water_h


func _place(delta: float) -> void:
	# Standing still (most of the time), nothing needs moving: skip the
	# ground lookup and the transform, except for a refresh now and then
	# (the ground under it may have loaded in finer).
	_replace_t -= delta
	if dir != _placed[0] or lift != _placed[1] or heading != _placed[2] or _replace_t <= 0.0:
		_replace_t = 0.5
		_placed = [dir, lift, heading]
		var ground := _ground_at(dir)
		var base := ground
		if afloat:
			base = maxf(ground, _water_at(dir))
		global_position = world.to_scene(dir, PlanetConst.RADIUS_M + base + lift)
		var fwd := heading - dir * heading.dot(dir)
		if fwd.length_squared() < 1e-6:
			fwd = CubeSphere.north(dir)
		global_basis = Basis.looking_at(fwd.normalized(), dir)
		_update_blob()
	var size := 1.0 if species.role == "swarm" else species.size_m
	_flash = maxf(_flash - delta * 5.0, 0.0)
	var scale_now := size * maxf(_fade, 0.001) * (1.0 + 0.12 * _flash)
	if scale_now != _scaled:
		_scaled = scale_now
		_body.scale = Vector3.ONE * scale_now
		_update_blob()
	if dead:
		# Topples onto its side, the side the killing blow came from up
		# (an arrow or the spear in it stays in view).
		_body.rotation.z = lerpf(_body.rotation.z, PI * 0.5 * _topple, clampf(delta * 5.0, 0.0, 1.0))
	if _rig_near:
		_animate(delta)
	_water_contacts()
	_sync_hitboxes()


## Water contacts (Ripples), only where the ripples run (water near the
## camera): legs standing in water drag a wake as they walk and each
## stride plants a small splash; a body afloat (or without legs) drags a
## wake from its hull. Mass from its size (RippleSim.creature_mass).
func _water_contacts() -> void:
	if dead or leaving or not _body.visible or not Ripples.near(global_position):
		return
	# Up in a tree or the air, or hovering (fireflies, wisps): no contact.
	if not afloat and (lift > 0.3 or species.role == "swarm" or species.shape == "wisp"):
		return
	var water := _water_at(dir)
	if not afloat and water < _ground_at(dir) + 0.03:
		return
	var surface: Vector3 = world.to_scene(dir, PlanetConst.RADIUS_M + water)
	var mass := RippleSim.creature_mass(species.size_m)
	var key := get_instance_id() * 8
	var legs: Array = _parts.legs
	if afloat or legs.is_empty():
		Ripples.wake(key + 7, surface, mass, _speed_now)
		return
	var each := mass / legs.size()
	for i in mini(legs.size(), 6):
		var p: Vector3 = (legs[i] as Node3D).global_position
		Ripples.wake(key + i, p - dir * dir.dot(p - surface), each, _speed_now)
	# A foot comes down every half stride.
	var stride := int(_anim / PI)
	if _speed_now > 0.05 and stride != _stride_n:
		var p: Vector3 = (legs[stride % legs.size()] as Node3D).global_position
		Ripples.splash(p - dir * dir.dot(p - surface), each, _speed_now + 0.5)
	_stride_n = stride


## The blob stays on the ground under it: it shrinks as the creature
## rises (a hop, taking off) and is gone when it's afloat, perched or
## flying high.
func _update_blob() -> void:
	if _blob == null:
		return
	var show := _body.visible and not afloat and lift < 3.0
	_blob.visible = show
	if show:
		var k := maxf((1.0 - lift / 3.0) * _fade, 0.001)
		_blob.position.y = BlobShadow.LIFT - lift
		_blob.scale = Vector3(_blob_size.x * k, 1.0, _blob_size.y * k)


func _animate(delta: float) -> void:
	var moving := _speed_now > 0.05
	# A cloaked figure's rig strides and its cloak swings by its own
	# velocity (PlayerBody), the same moves as the player's at its scale.
	if _body is PlayerBody:
		(_body as PlayerBody).set_velocity(heading * _speed_now)
	_anim += delta * (4.0 + _speed_now * 3.0 / maxf(species.size_m, 0.2))
	# An imported model plays its own clips.
	var animator: ModelAnimator = _parts.get("animator")
	if animator:
		var fast := _speed_now > species.speed_mps * 0.7
		animator.set_state("sprint" if fast else ("walk" if moving else "idle"), clampf(0.6 + _speed_now / maxf(species.speed_mps, 0.1), 0.6, 1.8))
	var swing := sin(_anim) * (0.6 if moving else 0.0)
	var legs: Array = _parts.legs
	# Legs at rest stay put (no transform to update).
	if moving or _legs_moving:
		_legs_moving = false
		for i in legs.size():
			var leg: Node3D = legs[i]
			var target := swing * (1.0 if i % 2 == 0 else -1.0)
			var x := lerpf(leg.rotation.x, target, clampf(delta * 10.0, 0.0, 1.0))
			if absf(x - target) > 0.002:
				_legs_moving = true
			leg.rotation.x = x
	# A limp (lame < 1, _wound()): once a stride the body rolls down toward
	# the side it was hit on, more the lamer it is (hits.limp_roll_deg at
	# limb_slow_floor), so the slower gait reads uneven.
	if not dead and (lame < 1.0 or _body.rotation.z != 0.0):
		var floor_k := float(species.hit_table().get("limb_slow_floor", 0.0))
		var k := clampf((1.0 - lame) / maxf(1.0 - floor_k, 0.05), 0.0, 1.0)
		var roll := 0.0
		if moving:
			roll = -_limp_side * deg_to_rad(float(Hits.hits().limp_roll_deg)) * k * maxf(sin(_anim), 0.0)
		_body.rotation.z = lerpf(_body.rotation.z, roll, clampf(delta * 12.0, 0.0, 1.0))
		if absf(_body.rotation.z) < 1e-4 and roll == 0.0:
			_body.rotation.z = 0.0
	var flying :=mode == "hop" and species.body in ["bird", "wader", "duck"] or fly_off
	var wings: Array = _parts.wings
	for i in wings.size():
		var w: Node3D = wings[i]
		var s := 1.0 if i % 2 == 0 else -1.0
		if species.role == "mythical":
			# Arms: hang and sway.
			w.rotation.x = sin(_anim * 0.5 + i) * (0.3 if moving else 0.06)
		elif flying:
			w.rotation.z = sin(_anim * 3.0) * 0.9 * s
		else:
			var folded := -1.2 * s if species.body != "bird" else -1.35 * s
			if absf(w.rotation.z - folded) > 0.002:
				w.rotation.z = lerpf(w.rotation.z, folded, clampf(delta * 6.0, 0.0, 1.0))
	if _parts.tail:
		(_parts.tail as Node3D).rotation.y = sin(_anim * 0.7) * 0.25
