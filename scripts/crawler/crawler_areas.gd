class_name CrawlerAreas
extends Node
## Realms reached from the hub by the shaman's song (design §GH, queue 116;
## §GD.1.2-4, queue 113; data/crawler.json areas). One per session
## (CrawlerMain makes it).
##
##   the realm    the surface over the game's first ruin (Surface, sized by
##                areas.first.across_m), with its main hearth near one edge
##                (Surface.area_hearth) and its ruin entrance (the old
##                stair) down into the ruin; the ruin's way out brings you
##                back up near the mouth (CrawlerMain)
##   sitting      the interact button at the hub fire (or beside the
##                shaman) sits you down facing the fire; moving or Esc
##                stands you up, nothing changed
##   the song     the shaman sings the song of a realm you know
##                (areas.songs: Mike's track if there is one, else a drum
##                and hummed chant made from the data), the flames take
##                its colour and a glimpse of it opens in the fire (a
##                camera beside its hearth, its own world, on a soft,
##                heat-wavering card over the fire)
##   the list     left and right scroll through the realms whose songs you
##                know (songs.known_from_start: a stand-in until Mike says
##                how songs are learned, §GH.4 call 1)
##   stepping in  the interact button again: the wash, and you come out at
##                that realm's hearth; with no lit torch you carry a brand
##                from the hub fire (brand). Knowing the song is the key:
##                travel no longer waits on the hearth (§GH.2.1)
##   reclaiming   hold your torch's flame to the realm's cold hearth
##                (reach_m, light_hold_s): it catches and is lit for good
##                (CrawlerSave.data.areas, §FK)
##   home         the interact button at the realm's hearth

static var A: Dictionary = Tuning.table("crawler").get("areas", {})

var main: CrawlerMain
var _hold := 0.0
var travels := 0


static func on() -> bool:
	return bool(A.get("on", true))


static func first() -> Dictionary:
	return A.get("first", {})


static func colour() -> Color:
	return Color(str(first().get("colour", "#3fd0ff")))


## Is the first realm reclaimed in this game (its hearth lit, kept)?
## (Saved as "linked", the name it had before §GH.)
static func linked() -> bool:
	return bool(((CrawlerSave.data.get("areas", {}) as Dictionary).get("first", {}) as Dictionary).get("linked", false))


static func set_linked() -> void:
	var a: Dictionary = CrawlerSave.data.get("areas", {})
	a["first"] = {"linked": true}
	CrawlerSave.data["areas"] = a
	CrawlerSave.save()


static func songs() -> Dictionary:
	return A.get("songs", {})


## The realms whose songs you know, in order (the save's, else the data's
## stand-in), each one that exists (areas.<key>).
static func known() -> Array:
	var k: Variant = CrawlerSave.data.get("songs", null)
	var list: Array = k if k is Array else (songs().get("known_from_start", ["first"]) as Array)
	return list.filter(func(r): return A.get(str(r)) is Dictionary)


static func realm_colour(key: String) -> Color:
	return Color(str((A.get(key, {}) as Dictionary).get("colour", "#3fd0ff")))


## Can you go from the hub now? (You know at least one song.)
func can_go() -> bool:
	return not known().is_empty()


# --- Sitting at the fire, the song, the glimpse ------------------------------------

var sitting := false
var realm := ""
var _ri := 0
var _player_song: AudioStreamPlayer
var _glimpse_vp: SubViewport
var _glimpse_cam: Camera3D
var _glimpse_card: MeshInstance3D
var _glimpse_mat: ShaderMaterial
var _show := 0.0
var _sing_t := 0.0
var _tint := {}
var _shaman_motion: FolkMotion
static var _song_cache := {}


func setup(p_main: CrawlerMain) -> void:
	name = "Areas"
	main = p_main


func _hub() -> HubCamp:
	return main.surface as HubCamp if main.on_surface else null


func _area() -> Surface:
	return main.surface if main.on_surface and not (main.surface is HubCamp) else null


## The interact button (CrawlerMain): true if travel took it.
func interact() -> bool:
	if main.leaving or not on():
		return false
	if sitting:
		step_in()
		return true
	var p := main.player.global_position
	var reach := float(A.get("interact_reach_m", 3.0))
	var hub := _hub()
	# The bank first, beside the fire (design §GJ.2).
	if hub != null and hub.bank_node != null and main.bank_panel != null:
		var bp := hub.bank_node.global_position
		if Vector2(p.x - bp.x, p.z - bp.z).length() <= float(CrawlerBank.B.get("reach_m", 2.2)):
			main.bank_panel.open()
			return true
	if hub != null:
		var near_fire := Vector2(p.x - hub.camp.pos.x, p.z - hub.camp.pos.z).length() <= reach
		var near_shaman := hub.shaman != null and p.distance_to(hub.shaman.global_position) <= reach
		if (near_fire or near_shaman) and can_go():
			sit()
			return true
		return false
	var area := _area()
	if area != null and area.area_hearth != null:
		var hp := area.area_hearth.global_position
		if Vector2(p.x - hp.x, p.z - hp.z).length() <= reach:
			to_hub()
			return true
	return false


## Sit down facing the hub fire; the shaman sings the first known realm.
func sit() -> void:
	var hub := _hub()
	if hub == null or sitting:
		return
	sitting = true
	var S: Dictionary = A.get("sit", {})
	var fp: Vector3 = hub.camp.pos
	var pp := main.player.global_position
	var away := Vector2(pp.x - fp.x, pp.z - fp.z)
	away = away.normalized() if away.length() > 0.1 else (hub.frame.n as Vector2)
	var seat := Vector2(fp.x, fp.z) + away * float(S.get("from_fire_m", 2.4))
	var eye_drop := 1.55 - float(S.get("eye_m", 1.05))
	var at := Vector3(seat.x, hub.land.height_at(seat.x, seat.y) - eye_drop, seat.y)
	var to := Vector2(fp.x - seat.x, fp.z - seat.y)
	main.player.spawn_flat(at, atan2(-to.x, -to.y), atan2(fp.y + 1.3 - (at.y + 1.55), to.length()))
	main.player.set_physics_process(false)
	_shaman_motion = FolkMotion.new(hub.shaman) if hub.shaman != null else null
	GameLog.add(str(A.get("log_sing", "You sit at the fire. The shaman begins to sing.")), "world")
	_ri = 0
	_sing(str(known()[0]))


## Up from the fire, nothing changed.
func stand(log_it := true) -> void:
	if not sitting:
		return
	sitting = false
	_stop_song()
	var hub := _hub()
	if hub != null:
		var p := main.player.global_position
		main.player.spawn_flat(Vector3(p.x, hub.land.height_at(p.x, p.z), p.z), main.player.rotation.y, 0.0)
	main.player.set_physics_process(true)
	if log_it:
		GameLog.add(str(A.get("log_stand", "You get up from the fire.")), "world")


## Scroll the known realms (dir -1 left, +1 right).
func scroll(dir: int) -> void:
	if not sitting:
		return
	var k := known()
	_ri = posmod(_ri + dir, k.size())
	_sing(str(k[_ri]))


## Sing realm `key`: its song, its colour in the flames, its glimpse.
func _sing(key: String) -> void:
	_stop_song(false)
	realm = key
	var hub := _hub()
	var c := realm_colour(key)
	_tint = _tint_fire(hub.fire, c)
	if _player_song == null:
		_player_song = AudioStreamPlayer.new()
		_player_song.name = "Song"
		_player_song.bus = AudioMix.bus("ambience")
		add_child(_player_song)
	_player_song.stream = song_stream(key)
	_player_song.volume_db = -8.0
	_player_song.play()
	_sing_t = 0.0
	_show = 0.0
	_open_glimpse(key)


func _stop_song(close_glimpse := true) -> void:
	if _player_song != null:
		_player_song.stop()
	_untint_fire(_tint)
	_tint = {}
	if _shaman_motion != null:
		_shaman_motion.release(0)
		_shaman_motion.release(1)
	if close_glimpse:
		_close_glimpse()


## The song of realm `key`: Mike's track (songs.<key>.music) if it is
## there, else the placeholder: a drum loop and a hummed chant, from data.
static func song_stream(key: String) -> AudioStream:
	var sd: Dictionary = songs().get(key, {})
	var music := str(sd.get("music", ""))
	if music != "" and ResourceLoader.exists(music):
		return load(music)
	if _song_cache.has(key):
		return _song_cache[key]
	var rate := 22050
	var bpm := maxf(float(sd.get("bpm", 76.0)), 20.0)
	var beat := 60.0 / bpm
	var chant: Array = sd.get("chant", [0, 3, 5, 3])
	var drum: Array = sd.get("drum", [1, 0, 0.5, 0])
	var beats := maxi(chant.size(), drum.size())
	var n := int(beats * beat * rate)
	var root := float(sd.get("root_hz", 98.0))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var b := int(t / beat)
		var tb := t - b * beat
		var v := 0.0
		# The drum: a deep thump, its pitch falling, and a little skin.
		var dk := float(drum[b % drum.size()]) if b % drum.size() < drum.size() else 0.0
		if dk > 0.0:
			var env := exp(-tb * 9.0)
			v += dk * 0.55 * env * sin(TAU * (52.0 + 40.0 * exp(-tb * 25.0)) * tb)
		# The chant: hummed, a few soft harmonics, a slow vibrato, swelling in
		# and out on each note.
		var note: Variant = chant[b % chant.size()]
		if note != null:
			var f := root * pow(2.0, float(note) / 12.0) * (1.0 + 0.006 * sin(TAU * 5.0 * t))
			var e := sin(PI * clampf(tb / beat, 0.0, 1.0))
			v += 0.22 * e * (sin(TAU * f * t) + 0.45 * sin(TAU * 2.0 * f * t) + 0.18 * sin(TAU * 3.0 * f * t))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	_song_cache[key] = w
	return w


## The glimpse: realm `key`'s surface in a world of its own, seen from
## beside its hearth, on a card over the hub fire.
func _open_glimpse(key: String) -> void:
	var G: Dictionary = A.get("glimpse", {})
	var area := main._ensure_area()
	if area == null:
		return
	if _glimpse_vp == null:
		_glimpse_vp = SubViewport.new()
		_glimpse_vp.name = "Glimpse"
		_glimpse_vp.own_world_3d = true
		var px: Array = G.get("px", [320, 200])
		_glimpse_vp.size = Vector2i(int(px[0]), int(px[1]))
		_glimpse_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_glimpse_vp)
		_glimpse_cam = Camera3D.new()
		_glimpse_cam.far = 600.0
		_glimpse_vp.add_child(_glimpse_cam)
	if area.get_parent() == null:
		# The realm, paused (its life, sounds and routines still), in the
		# glimpse's own world.
		area.process_mode = Node.PROCESS_MODE_DISABLED
		_glimpse_vp.add_child(area)
	_glimpse_cam.current = true
	_aim_glimpse(0.0)
	var hub := _hub()
	if _glimpse_card == null:
		_glimpse_card = MeshInstance3D.new()
		_glimpse_card.name = "GlimpseCard"
		var q := QuadMesh.new()
		var sz: Array = G.get("size_m", [1.5, 1.0])
		q.size = Vector2(float(sz[0]), float(sz[1]))
		_glimpse_card.mesh = q
		_glimpse_mat = ShaderMaterial.new()
		_glimpse_mat.shader = preload("res://shaders/fire_glimpse.gdshader")
		_glimpse_card.material_override = _glimpse_mat
		_glimpse_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _glimpse_card.get_parent() != hub:
		if _glimpse_card.get_parent() != null:
			_glimpse_card.get_parent().remove_child(_glimpse_card)
		hub.add_child(_glimpse_card)
	_glimpse_mat.set_shader_parameter("view", _glimpse_vp.get_texture())
	_glimpse_mat.set_shader_parameter("waver", float(G.get("waver", 0.012)))
	var c := realm_colour(key)
	_glimpse_mat.set_shader_parameter("rim_colour", Vector3(c.r, c.g, c.b))
	_glimpse_mat.set_shader_parameter("show", 0.0)
	var fp: Vector3 = hub.camp.pos
	var cam := main.player.camera()
	var to_you := Vector3(cam.global_position.x - fp.x, 0.0, cam.global_position.z - fp.z).normalized()
	var at := fp + Vector3(0.0, float(G.get("height_m", 1.55)), 0.0) + to_you * float(G.get("toward_you_m", 0.55))
	_glimpse_card.transform = Transform3D(Basis.looking_at(-to_you, Vector3.UP), at)
	_glimpse_card.visible = true


func _aim_glimpse(t: float) -> void:
	var G: Dictionary = A.get("glimpse", {})
	var area := main.area_node
	if area == null or _glimpse_cam == null or area.area_hearth == null:
		return
	var hp := area.area_hearth.position
	var c := Vector3(area.land.center.x, hp.y, area.land.center.y)
	var dir := (c - hp).normalized()
	var drift := deg_to_rad(float(G.get("drift_deg", 25.0))) * sin(TAU * t / maxf(float(G.get("drift_s", 20.0)), 1.0))
	var look := dir.rotated(Vector3.UP, drift)
	var eye := hp - dir * float(G.get("from_hearth_m", 4.0))
	eye.y = area.land.height_at(eye.x, eye.z) + float(G.get("eye_m", 1.7))
	_glimpse_cam.transform = Transform3D(Basis.looking_at(look, Vector3.UP), eye)


## Back out of the glimpse: the realm leaves its world (kept for travel).
func _close_glimpse() -> void:
	if _glimpse_card != null:
		_glimpse_card.visible = false
	var area := main.area_node
	if area != null and is_instance_valid(area) and _glimpse_vp != null and area.get_parent() == _glimpse_vp:
		_glimpse_vp.remove_child(area)
		area.process_mode = Node.PROCESS_MODE_INHERIT


func glimpse_shown() -> float:
	return _show if _glimpse_card != null and _glimpse_card.visible else 0.0


func song_playing() -> bool:
	return _player_song != null and _player_song.playing


func _unhandled_input(event: InputEvent) -> void:
	if not sitting or main.leaving:
		return
	if event.is_action_pressed("move_left"):
		scroll(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		scroll(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("move_back") or event.is_action_pressed("ui_cancel"):
		stand()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		step_in()
		get_viewport().set_input_as_handled()


## Into the fire as the song swells: out at the sung realm's hearth.
func step_in() -> void:
	if not sitting:
		return
	GameLog.add(str(A.get("log_step", "You step into the fire.")), "world")
	var key := realm
	sitting = false
	main.player.set_physics_process(true)
	await to_area(key)


## Hub -> realm `key`'s hearth through the fire (the song's wash).
func to_area(key := "first") -> void:
	if main.leaving:
		return
	main.leaving = true
	var c := realm_colour(key)
	var T: Dictionary = A.get("travel", {})
	await main._wash(c, 1.0, float(T.get("wash_s", 1.0)))
	_stop_song()
	if bool(A.get("brand", true)):
		_brand()
	main._to_area_now()
	travels += 1
	await main._wash(c, 0.0, float(T.get("wash_s", 1.0)))
	main.leaving = false


## The realm -> the hub, through its hearth: the shaman's song carries you
## home (design §GI.2.2), and what you carry is yours now.
func to_hub() -> void:
	if main.leaving:
		return
	main.leaving = true
	GameLog.add(str(A.get("log_home", "The shaman's song carries you home through the fire.")), "world")
	var T: Dictionary = A.get("travel", {})
	var key := "first"
	if _player_song == null:
		_player_song = AudioStreamPlayer.new()
		_player_song.name = "Song"
		_player_song.bus = AudioMix.bus("ambience")
		add_child(_player_song)
	_player_song.stream = song_stream(key)
	_player_song.volume_db = -10.0
	_player_song.play()
	home_songs += 1
	await main._wash(realm_colour(key), 1.0, float(T.get("wash_s", 1.0)))
	main._to_hub_now()
	# Home: the pages you carried are yours for good (Mike, 27 Oct).
	TomePages.home_all()
	travels += 1
	await main._wash(realm_colour(key), 0.0, float(T.get("wash_s", 1.0)))
	_player_song.stop()
	main.leaving = false


# --- Dying, and what you lose (design §GI.2, §GJ) ------------------------------------

var home_songs := 0
## Play has begun (CrawlerMain sets it once you stand at the hub).
var live := false
## Pile id -> its node.
var _pile_nodes := {}


static func piles() -> Array:
	var p: Variant = CrawlerSave.data.get("piles", null)
	if not p is Array:
		p = []
		CrawlerSave.data["piles"] = p
	return p


## Taken in a realm, surface or ruin: everything carried drops where you
## fell (one pile, kept), and you wake at the hub fire with nothing.
func die() -> void:
	var pl := main.player
	var where := "ruin" if not main.on_surface else "surface"
	var at := pl.global_position
	if pl.torch.lit():
		pl.torch.put_out("taken")
	var inv := pl.inventory
	var lost := {"carried": [], "strip": [], "worn": [], "currency": carried_currency, "pages": TomePages.drop_carried()}
	for i in inv.carried.size():
		if inv.carried[i] != null:
			(lost.carried as Array).append(inv.carried[i])
			inv.carried[i] = null
	for i in inv.strip.size():
		if inv.strip[i] != null:
			(lost.strip as Array).append(inv.strip[i])
			inv.strip[i] = null
	for slot in inv.worn:
		var arr: Array = inv.worn[slot]
		for i in arr.size():
			if arr[i] != null:
				(lost.worn as Array).append(arr[i])
				arr[i] = null
	carried_currency = 0
	var n := (lost.carried as Array).size() + (lost.strip as Array).size() + (lost.worn as Array).size()
	if n > 0 or int(lost.currency) > 0 or not (lost.pages as Array).is_empty():
		piles().append({"id": "pile_%d_%d" % [Time.get_ticks_usec(), piles().size()], "realm": "first", "where": where, "pos": [at.x, at.y, at.z], "lost": lost})
	CrawlerSave.save()
	pl.weapon = "hands"
	if pl.hands != null and not Hands.left_busy():
		pl.hands.hold_left({})
	pl.death_cause = ""
	pl.revive()
	main.harm.reset()
	if main.boss != null:
		main.boss.after_wake()
	if main.residents != null:
		main.residents.player_woke()
	sitting = false
	main._to_hub_from_anywhere()
	refresh_piles()
	GameLog.add(str((A.get("death", {}) as Dictionary).get("log_wake", "You wake at the hub fire with nothing on you.")), "death_cause")
	var tw := main.create_tween()
	tw.tween_property(main._fade, "color:a", 0.0, 2.5)
	tw.tween_callback(func(): main._fade.visible = false)


## Currency carried (teeth, §FZ.3; not built yet: kept ready, lost on death).
var carried_currency := 0


## A node for every kept pile whose place is built: the realm's surface or
## its ruin (under the tomb, so it comes and goes with the dungeon).
func refresh_piles() -> void:
	for p in piles():
		var id := str(p.id)
		if _pile_nodes.has(id) and is_instance_valid(_pile_nodes[id]):
			continue
		var parent: Node3D = null
		if str(p.where) == "surface":
			parent = main.area_node
		else:
			parent = main.tomb
		if parent == null or not is_instance_valid(parent):
			continue
		var pos: Array = p.pos
		_pile_nodes[id] = _pile_node(parent, Vector3(float(pos[0]), float(pos[1]), float(pos[2])))


func _pile_node(parent: Node3D, at: Vector3) -> Node3D:
	var D: Dictionary = A.get("death", {})
	var root := Node3D.new()
	root.name = "LostPile"
	root.position = at
	parent.add_child(root)
	var bundle := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.36
	bundle.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#5a4026")
	m.roughness = 0.8
	bundle.material_override = m
	bundle.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(bundle)
	var gc := Color(str(D.get("glow_colour", "#ff7a1a")))
	for i in 5:
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.035
		es.height = 0.07
		e.mesh = es
		var em := StandardMaterial3D.new()
		em.albedo_color = gc
		em.emission_enabled = true
		em.emission = gc
		em.emission_energy_multiplier = 3.0
		e.material_override = em
		e.position = Vector3(cos(i * 1.3) * 0.22, 0.05, sin(i * 1.3) * 0.22)
		root.add_child(e)
	var l := OmniLight3D.new()
	l.light_color = gc
	l.light_energy = float(D.get("glow_energy", 0.6))
	l.omni_range = 2.5
	l.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(l)
	return root


## Walk to a pile: all of it back to you (what will not fit stays).
func _pickups() -> void:
	# Not while the game is still setting you down (at the start the dungeon
	# is readied with you on its mat for a moment), nor mid-crossing.
	if not live or main.leaving:
		return
	var pp := main.player.global_position
	var reach := float((A.get("death", {}) as Dictionary).get("pickup_m", 1.4))
	for p in piles().duplicate():
		var node: Node3D = _pile_nodes.get(str(p.id))
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if node.global_position.distance_to(pp) > reach:
			continue
		var lost: Dictionary = p.lost
		var inv := main.player.inventory
		var left: Array = []
		for k in ["carried", "strip", "worn"]:
			for it in lost.get(k, []):
				if not inv.add(it):
					left.append(it)
		carried_currency += int(lost.get("currency", 0))
		TomePages.pick_up(lost.get("pages", []))
		if left.is_empty():
			piles().erase(p)
			node.queue_free()
			_pile_nodes.erase(str(p.id))
		else:
			p["lost"] = {"carried": left, "strip": [], "worn": [], "currency": 0, "pages": []}
		CrawlerSave.save()
		GameLog.add(str((A.get("death", {}) as Dictionary).get("log_pile", "You gather up what you lost.")), "world")



## A lit torch in hand if you hold none lit (the brand from the hub fire).
func _brand() -> void:
	var pl := main.player
	if pl.torch.lit():
		return
	if not pl.inventory.has_kind("torch"):
		pl.inventory.add(Inventory.make("torch"))
	pl.weapon = "torch"
	pl.torch.light("A brand from the hub fire.")


## The fire's flames and light in `c` for the crossing; what they were.
func _tint_fire(fire: Node3D, c: Color) -> Dictionary:
	var kept := {"mats": [], "light": null, "col": Color.WHITE}
	if fire == null:
		return kept
	for mi in fire.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as ShaderMaterial
		if m == null or not m.shader.code.contains("band0"):
			continue
		var was := {}
		for k in ["band0", "band1", "band2", "band3"]:
			was[k] = m.get_shader_parameter(k)
		(kept.mats as Array).append([m, was])
		var hot := Vector3(c.r, c.g, c.b) * 2.0
		m.set_shader_parameter("band0", hot + Vector3(0.6, 0.6, 0.6))
		m.set_shader_parameter("band1", hot)
		m.set_shader_parameter("band2", hot * 0.5)
		m.set_shader_parameter("band3", hot * 0.15)
	var l := fire.get_node_or_null("Light") as OmniLight3D
	if l != null:
		kept.light = l
		kept.col = l.light_color
		l.light_color = c
	return kept


func _untint_fire(kept: Dictionary) -> void:
	for pair in kept.get("mats", []):
		var m := pair[0] as ShaderMaterial
		for k in (pair[1] as Dictionary):
			m.set_shader_parameter(k, pair[1][k])
	var l := kept.get("light") as OmniLight3D
	if l != null and is_instance_valid(l):
		l.light_color = kept.col


func _process(delta: float) -> void:
	_pickups()
	if sitting:
		_sing_t += delta
		_show = minf(_sing_t / maxf(float((A.get("glimpse", {}) as Dictionary).get("fade_s", 1.5)), 0.01), 1.0)
		if _glimpse_mat != null:
			_glimpse_mat.set_shader_parameter("show", _show)
		_aim_glimpse(_sing_t)
		# The shaman sings: his hands rise and sway over the fire.
		var hub := _hub()
		if _shaman_motion != null and hub != null:
			var sway := sin(_sing_t * 1.6) * 0.35
			var up: Vector3 = hub.camp.pos + Vector3(0.0, 1.4 + 0.15 * sin(_sing_t * 2.3), 0.0)
			_shaman_motion.reach_point(0, up + Vector3(sway, 0.0, 0.0))
			_shaman_motion.reach_point(1, up - Vector3(sway, 0.0, 0.0))
			_shaman_motion.update(delta)
	var area := _area()
	if area == null or area.area_hearth == null or area.hearth_lit():
		_hold = 0.0
		return
	# Your torch's flame held to the cold hearth: it catches.
	var t := main.player.torch
	var H: Dictionary = first().get("hearth", {})
	var hp := area.area_hearth.global_position + Vector3(0.0, 0.3, 0.0)
	if t.lit() and t.in_hand() and t.flame_position().distance_to(hp) <= float(H.get("reach_m", 1.3)):
		_hold += delta
		if _hold >= float(H.get("light_hold_s", 1.0)):
			_hold = 0.0
			area.light_hearth()
			set_linked()
			GameLog.add(str(A.get("log_link", "The hearth catches.")), "world")
	else:
		_hold = 0.0
