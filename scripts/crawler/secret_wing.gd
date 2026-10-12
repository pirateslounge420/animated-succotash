class_name SecretWing
extends Node3D
## The secret opening, its rooms and the scroll (design 10 Oct §FO.4,
## queue 86; data/ruin_loop.json secret). Not §FM.4's game-wide secret
## layer, a separate idea, untouched.
##
## Laid out (lay_out, pure, TombKit.layout's last step, on its own dice from
## the dungeon's seed, §FK.2, so nothing else on the floor moves): one
## opening in a side wall of a room on the main route (the spine's rooms
## first, from the hearth outward in a seeded order, then the heart, then
## the side ways' rooms), so that walking the route you see a way you
## cannot pass; never the way out's door, never a spine door (§EX.5). Past
## it a short corridor and one or two rooms (secret.rooms, a seeded count),
## in the ruin's one stone (TombBuild builds them like any piece, §EX.1),
## clear of everything laid (TombKit._free). A wall is taken only if the
## room keeps every torch, coffin, niche and pillar where it was with the
## new door in it, and nothing laid there (an airway, a resident's place,
## the boss's holes) stands within reach of the doorway.
##
## lay.secret: {"host" (the room it opens from), "door" (the opening's door:
## the seal stands there), "pieces" (the wing's piece ids, in order),
## "end" (the last room), "artifact" (Vector3, where the scroll lies: by the
## end room's far wall, on its floor)}. Its pieces carry "secret": true and
## are on no way (lay.branches, lay.spine): no sconces of their own (§FF.2:
## not counted in the floor's lit test; you carry your torch in), no
## residents, airways or vents; the boss's graph takes their light from the
## room the opening leaves, as a torchless room's.
##
## The opening (secret.opening.kind stone_seal) is a RelightGate the Fork
## stands in it (Fork.secret), collision and all, until the boss is first
## driven home; then it sinks with the stone_seal grinding (§FO.3, queue
## 85). Same floor, same scene: no loading screen.
##
## In play (this node): the scroll lying at the far end (TomePages's rolled
## scroll, the ruin's matte stone material, no light), never named on
## screen. Right click (interact) beside it takes it: once, kept in the
## game's save (the dungeon's "secret_taken", and CrawlerSave.data
## "ruin_scrolls", the game's collection of them, §FM.5's sense of a
## collection; not one of §FM.5's tome pages: §FO.9 call 5 is open), the
## paper's rustle, the log's plain line. `taken_now` fires: phase two
## hangs on it (queue 87).

## The scroll has just been taken, in play.
signal taken_now

const KEEP := "ruin_scrolls"

static var S: Dictionary = (Tuning.table("ruin_loop") as Dictionary).get("secret", {})

var lay: Dictionary
var player: CrawlerPlayer
## The place in this game's world (CrawlerSave) the dungeon is.
var at := 0
## The scroll lying there (null once taken).
var scroll: Node3D
var taken := false
## Times it was taken (the checks: once).
var taken_count := 0
var _voice: AudioStreamPlayer3D


# --- Laid out (pure) -------------------------------------------------------------

## The wing's rooms (secret.rooms: [least, most]).
static func rooms_span() -> Vector2i:
	var r: Array = S.get("rooms", [1, 2])
	return Vector2i(maxi(int(r[0]), 1), maxi(int(r[r.size() - 1]), maxi(int(r[0]), 1)))


## The wing for `lay` (TombKit.layout's last step). Nothing when none fits
## (a warning: then the ruin has none).
static func lay_out(lay: Dictionary) -> void:
	if not bool(S.get("on", true)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "secret wing"])
	var want := rng.randi_range(rooms_span().x, rooms_span().y)
	var hosts := _hosts(lay, rng)
	var walls := {}
	for host in hosts:
		var sides: Array = ["left", "right"]
		if rng.randf() < 0.5:
			sides.reverse()
		# Then its end and start walls, where no door is (a side way's last
		# room: its far wall faces you as you come in).
		sides.append_array(["end", "start"])
		walls[int(host.id)] = sides
	# Centred in its wall first (§EX.2's doors); only where no centred one
	# fits anywhere, a module or two off the wall's middle.
	var mod := float(lay.module)
	var chalf := float(TombKit.K.get("corridor_half_m", 1.0))
	for off_m in [0, 1, -1, 2, -2]:
		for host in hosts:
			for side in walls[int(host.id)]:
				if _used(lay, host, str(side)):
					continue
				var off := float(off_m) * mod
				if absf(off) + chalf + 0.6 > TombKit.wall_len(host, str(side)) * 0.5:
					continue
				for n in range(want, 0, -1):
					if _try(lay, rng, host, str(side), n, off):
						return
	push_warning("SecretWing: tomb %d has no room on its route with space for a secret wing" % int(lay.seed))


## The rooms it may open from, the likeliest first: the spine's rooms past
## the hearth room (shuffled by the seed), then the heart, then the side
## ways' rooms. Floor one, never the hearth room, never a big room (its
## doors are its archetype's).
static func _hosts(lay: Dictionary, rng: RandomNumberGenerator) -> Array:
	var spine: Array = []
	for id in lay.get("spine", []):
		var pc: Dictionary = lay.pieces[int(id)]
		if str(pc.kind) == "room" and not str(pc.get("room_kind", "")) in ["hearth", "heart"] and not pc.has("big_room") and int(pc.get("floor", 0)) == 0:
			spine.append(pc)
	TombKit._shuffle(rng, spine)
	if lay.has("heart"):
		spine.append(lay.pieces[int(lay.heart)])
	var branches: Array = lay.get("branches", [])
	for bi in range(1, branches.size()):
		for id in branches[bi]:
			var pc: Dictionary = lay.pieces[int(id)]
			if str(pc.kind) == "room" and not pc.has("big_room") and int(pc.get("floor", 0)) == 0 and str(pc.get("room_kind", "")) != "hearth":
				spine.append(pc)
	return spine


static func _used(lay: Dictionary, pc: Dictionary, side: String) -> bool:
	for di in pc.doors:
		if str(TombKit.door_side(pc, lay.doors[di])[0]) == side:
			return true
	return false


## What the room `pc` holds that a new door could move: its torches, a
## crypt's coffins' rows, a catacomb's niches, its pillars.
static func _room_things(lay: Dictionary, pc: Dictionary) -> String:
	var parts: Array = []
	for h in TombKit._room_sconces(lay, pc):
		parts.append(str((h.pos as Vector3).snapped(Vector3.ONE * 0.01)))
	# (A crypt's coffins stand in its rows, a catacomb's stacks in its
	# niches: TombBuild lays them from these, so they must not move.)
	if str(pc.get("room_kind", "")) == "crypt":
		parts.append(str(TombKit.coffin_rows(lay, pc)))
	if str(pc.get("room_kind", "")) == "catacomb":
		parts.append(str(TombKit.niche_spots(lay, pc)))
	parts.append(str(TombKit._pillars_aa(lay, pc)))
	return "|".join(parts)


## Does anything laid stand within reach of the doorway at `p` (on the
## room's floor `y`)? An airway, a resident's place, the boss's lair or a
## tunnel hole, a holder.
static func _crowded(lay: Dictionary, p: Vector2, y: float) -> bool:
	var pts: Array = []
	for h in lay.get("holders", []):
		pts.append(h.pos)
	for a in lay.get("airways", []):
		pts.append(a.pos)
	for r in lay.get("residents", []):
		for k in ["pos", "out"]:
			if (r as Dictionary).has(k):
				pts.append(r[k])
	var lair: Dictionary = lay.get("lair", {})
	if not lair.is_empty():
		pts.append(lair.pos)
	for hole in (lay.get("tunnels", {}) as Dictionary).get("holes", []):
		for k in ["pos", "out"]:
			if (hole as Dictionary).has(k):
				pts.append(hole[k])
	for q in pts:
		var v: Vector3 = q
		if absf(v.y - y) < 2.5 and Vector2(v.x - p.x, v.z - p.y).length() < 1.6:
			return true
	return false


## The wing through wall `side` of room `host`: a corridor, a room, and for
## two a corridor on from that room's far wall and a second room. True if
## laid (else nothing changed).
static func _try(lay: Dictionary, rng: RandomNumberGenerator, host: Dictionary, side: String, n_rooms: int, off := 0.0) -> bool:
	var K: Dictionary = TombKit.K
	var mod := float(lay.module)
	var th := str(lay.theme)
	var ch := TombKit.height_of(th, "corridor", float(K.get("corridor_h_m", 2.6)))
	var rh := TombKit.height_of(th, "room", float(K.get("room_h_m", 3.2)))
	var chalf := float(K.get("corridor_half_m", 1.0))
	var rspan := TombKit.module_span(K.get("room_m", []), 6.0, 11.0, mod)
	var wp := TombKit.wall_point(host, side, off)
	var y := float(host.y1)
	if _crowded(lay, wp[0], y):
		return false
	var before := _room_things(lay, host)
	var n_pieces := (lay.pieces as Array).size()
	var n_doors := (lay.doors as Array).size()
	var host_doors := (host.doors as Array).size()
	var laid: Array = []
	var cur := host
	var cur_side := side
	for k in n_rooms:
		var w := TombKit.wall_point(cur, cur_side, off if k == 0 else 0.0)
		var n: Vector2 = w[1]
		var start: Vector2 = (w[0] as Vector2) + n * (TombKit.WALL * 0.5)
		var first := rng.randi_range(1, 2)
		# Small rooms: the kit's least, a module more at most (no pillars).
		var nl := rng.randi_range(rspan.x, mini(rspan.x + 1, rspan.y))
		var nw := rspan.x
		# Where that won't fit: the corridor a module shorter or longer (up
		# to three), the room its least both ways.
		var cor := {}
		var room := {}
		var fits := false
		for tryl in [first, 3 - first, 3]:
			for size in [[nl, nw], [rspan.x, rspan.x]]:
				var clen := float(tryl) * mod
				cor = Delves.piece("corridor", start, n, clen, chalf, y, y, ch)
				room = Delves.piece("room", start + n * (clen + TombKit.WALL), n, int(size[0]) * mod, int(size[1]) * mod * 0.5, y, y, rh)
				if TombKit._free(lay, TombKit.outer(cor), [int(cur.id)]) and TombKit._free(lay, TombKit.outer(room), []):
					fits = true
					break
			if fits:
				break
		if not fits:
			break
		var clen := float(cor.len)
		TombKit._add(lay, cor)
		TombKit._add(lay, room)
		TombKit._door(lay, w[0], n, chalf - 0.1, y, minf(ch, float(cur.h)) - 0.2, cur, cor)
		TombKit._door(lay, start + n * (clen + TombKit.WALL * 0.5), n, chalf - 0.1, y, ch - 0.2, cor, room)
		for pc in [cor, room]:
			pc["secret"] = true
			pc["branch"] = -2
			pc["spine"] = false
			pc["depth"] = int(host.get("depth", 0)) + 1 + k
		room["room_kind"] = "secret"
		room["branch_of"] = int(host.id)
		laid.append_array([int(cor.id), int(room.id)])
		cur = room
		cur_side = "end"
	if laid.is_empty() or _room_things(lay, host) != before or TombBuild.on_pillars(lay, lay.pieces[int(laid[-1])]):
		(lay.pieces as Array).resize(n_pieces)
		(lay.doors as Array).resize(n_doors)
		(host.doors as Array).resize(host_doors)
		return false
	var end: Dictionary = lay.pieces[int(laid[-1])]
	var far := float(end.len) - 0.7
	var q: Vector2 = (end.c as Vector2) + (end.dir as Vector2) * far
	lay["secret"] = {"host": int(host.id), "door": n_doors, "pieces": laid, "end": int(end.id),
		"artifact": Vector3(q.x, Delves.floor_of(end, far), q.y), "along": Delves.perp(end.dir)}
	return true


## Is piece `pid` part of the wing?
static func is_secret(lay: Dictionary, pid: int) -> bool:
	return pid >= 0 and pid < (lay.pieces as Array).size() and bool((lay.pieces[pid] as Dictionary).get("secret", false))


# --- In play ---------------------------------------------------------------------

## The scroll at the wing's end (unless this dungeon's was taken already).
func build(p_lay: Dictionary, p_player: CrawlerPlayer, p_at: int) -> void:
	name = "SecretWing"
	lay = p_lay
	player = p_player
	at = p_at
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Voice"
	_voice.unit_size = 2.0
	add_child(_voice)
	var sec: Dictionary = lay.get("secret", {})
	taken = bool(CrawlerSave.kept_value(at, "secret_taken", false))
	if sec.is_empty() or taken:
		return
	scroll = Node3D.new()
	scroll.name = "Scroll"
	add_child(scroll)
	scroll.position = sec.artifact
	var al: Vector2 = sec.along
	scroll.rotation.y = atan2(-al.y, al.x)
	scroll.add_child(TomePages.scroll_node())


## The ids kept in the game's collection (CrawlerSave.data "ruin_scrolls"):
## one per dungeon whose scroll you took ("<place>").
static func collected() -> Array:
	var v: Variant = CrawlerSave.data.get(KEEP, [])
	return (v as Array).duplicate() if v is Array else []


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.ui_open or player.typing or player.dead:
		return
	if event.is_action_pressed("interact") and take():
		get_viewport().set_input_as_handled()


## Take the scroll, if you stand within reach of it (TomePages.reach_m):
## once. True if taken now.
func take() -> bool:
	if taken or scroll == null or player == null:
		return false
	if player.global_position.distance_to(scroll.global_position) > TomePages.reach_m():
		return false
	taken = true
	taken_count += 1
	var pos := scroll.global_position
	scroll.queue_free()
	scroll = null
	CrawlerSave.keep(at, "secret_taken", true)
	var c := collected()
	if not c.has(str(at)):
		c.append(str(at))
		CrawlerSave.data[KEEP] = c
		CrawlerSave.save()
	GameLog.add(str(S.get("log_line", "You take the scroll.")), "tome")
	if _voice != null and _voice.is_inside_tree():
		_voice.global_position = pos
		_voice.stream = SoundSynth.stream("rustle", int(lay.get("seed", 0)))
		_voice.pitch_scale = 1.2
		_voice.volume_db = -10.0
		Audio3D.play(_voice)
	taken_now.emit()
	return true
