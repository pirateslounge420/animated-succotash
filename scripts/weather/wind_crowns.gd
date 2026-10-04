class_name WindCrowns
extends Node3D
## The crowns round you as sound sources in the gusts (design 3 Oct §DA
## point 4, data/wind.json sound.crowns; §BG: a source is a place you can
## walk to). Every quarter second the trees within crowns.radius_m (the
## loaded chunks') are scored by the gust at their crown (the same field
## the eye sees, at the same instant; a canopy crown takes the full wind,
## a smaller tree the shelter of the crowns over it); those past from_mps
## sound, the strongest max_sources of them at once, each an Audio3D
## source at its trunk (audio.json kinds crown_hush, crown_rustle,
## crown_clatter, crown_rattle) whose loop SoundSynth makes. The voice
## follows the leaf: needles hush, broad leaves rustle, palm fronds
## clatter, dry autumn leaves rattle (a deciduous crown well into its
## autumn colour, LeafSeason).

static var S: Dictionary = (Tuning.section("wind", "sound").get("crowns", {}) as Dictionary)
const TICK_S := 0.25
const FADE_DB_S := 40.0

var main: Node
var _t := 0.0
## One per source: {"p": player, "tree": key or "", "want_db": float}.
var _src: Array = []
## The crowns sounding now (tools): [{"key", "voice", "pos", "gust_mps"}].
var sounding: Array = []


func setup(p_main: Node) -> void:
	main = p_main
	for i in int(S.get("max_sources", 4)):
		var p := Audio3D.make("crown_rustle", self, "Crown%d" % i)
		p.volume_db = -60.0
		_src.append({"p": p, "tree": "", "want_db": -60.0})


## The voice for a crown of species `sp`: hush (needles), clatter (palm
## fronds), rattle (dry autumn leaves) or rustle (broad leaves).
static func voice_of(sp: PlantSpecies, autumn: float) -> String:
	var Sh := PlantSpecies.Shape
	if sp.shape in [Sh.CONIFER, Sh.CYPRESS]:
		return "hush"
	if sp.shape in [Sh.PALM, Sh.BAMBOO, Sh.TREE_FERN]:
		return "clatter"
	if sp.deciduous and autumn > 0.55:
		return "rattle"
	return "rustle"


## The gust (m/s) at a crown: the field at the crown, in the full wind for
## a canopy crown, else sheltered by the sky visibility at its foot.
func crown_gust(top: Vector3, up: Vector3, sp: PlantSpecies) -> float:
	var g := Wind.gust_vec(top, up).length()
	if Wind.kind_of(sp) == 2:
		return g
	var sky := 1.0
	if main != null and main.chunks != null:
		sky = main.chunks.sky_visibility_at(top)
	return g * Wind.shelter(sky)


## Score the crowns round `eye` (scene): [{"key", "pos", "gust_mps",
## "voice", "dist"}], strongest first, only those past from_mps within
## radius_m.
func candidates(eye: Vector3) -> Array:
	if main == null or main.chunks == null:
		return []
	var ls: LeafSeason = main.get("leaf_season") if main.get("leaf_season") is LeafSeason else null
	var autumn := ls.autumn if ls != null else 0.0
	var r := float(S.get("radius_m", 40.0))
	var from := float(S.get("from_mps", 1.6))
	var all := SpeciesDB.all()
	var out: Array = []
	for key in main.chunks.chunks:
		var ch: TerrainChunk = main.chunks.chunks[key]
		if ch.global_position.distance_to(eye) > r + TerrainChunk.CHUNK_M:
			continue
		for i in ch.trees.size():
			var t: Array = ch.trees[i]
			var root := ch.tree_base(i)
			var dist := root.distance_to(eye)
			if dist > r:
				continue
			var sp: PlantSpecies = all[int(t[2])]
			# A dead snag (bare) has nothing to rustle.
			if t.size() > 8 and float(t[8]) >= 0.975:
				continue
			var up := ch.tree_up(i)
			var h: float = t[1]
			var top := root + up * h * 0.7
			var g := crown_gust(top, up, sp)
			if g < from:
				continue
			out.append({"key": "%s:%d" % [str(key), i], "pos": top, "gust_mps": g, "voice": voice_of(sp, autumn), "dist": dist})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.gust_mps) / (1.0 + float(a.dist) * 0.02) > float(b.gust_mps) / (1.0 + float(b.dist) * 0.02))
	return out


func update_crowns(delta: float) -> void:
	if main == null or main.player == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = TICK_S
		_assign(candidates(main.player.global_position))
	for s in _src:
		var p: AudioStreamPlayer3D = s.p
		p.volume_db = move_toward(p.volume_db, float(s.want_db), FADE_DB_S * delta)
		if p.volume_db <= -59.0 and float(s.want_db) <= -59.0 and p.playing:
			p.stop()


func _assign(cands: Array) -> void:
	var from := float(S.get("from_mps", 1.6))
	var take := cands.slice(0, _src.size())
	var keys := {}
	for c in take:
		keys[c.key] = c
	# Sources whose crown is still among the loudest keep it; the rest
	# fade out and are reused.
	var free: Array = []
	for s in _src:
		if keys.has(s.tree):
			var c: Dictionary = keys[s.tree]
			s.want_db = _db(float(c.gust_mps), from)
			(s.p as AudioStreamPlayer3D).global_position = c.pos
			keys.erase(s.tree)
		else:
			s.want_db = -60.0
			if (s.p as AudioStreamPlayer3D).volume_db <= -55.0:
				free.append(s)
	for k in keys:
		if free.is_empty():
			break
		var c: Dictionary = keys[k]
		var s: Dictionary = free.pop_back()
		var p: AudioStreamPlayer3D = s.p
		Audio3D.apply(p, "crown_" + str(c.voice))
		p.stream = SoundSynth.stream("crown_%s_loop" % str(c.voice), absi(hash(k)))
		p.global_position = c.pos
		p.volume_db = -50.0
		p.play(randf() * 2.0)
		s.tree = k
		s.want_db = _db(float(c.gust_mps), from)
	sounding.clear()
	for s in _src:
		if str(s.tree) != "" and float(s.want_db) > -59.0:
			sounding.append({"key": s.tree, "pos": (s.p as AudioStreamPlayer3D).global_position, "want_db": s.want_db})


## Louder the harder the gust is past the threshold.
static func _db(g: float, from: float) -> float:
	return lerpf(-22.0, -4.0, clampf((g - from) / (from * 4.0), 0.0, 1.0))
