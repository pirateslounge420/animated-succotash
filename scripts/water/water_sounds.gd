class_name WaterSounds
extends Node
## Running water as sources you can walk to (design 30 Sept §BG, §BE):
## a few "water_flow" players (audio.json) kept at the nearest points of
## the river segments round the player, louder for a faster, wider reach;
## the waterfalls' own roar is on each fall (TerrainChunk._build_falls,
## "waterfall"). Both muffled by terrain and foliage (Audio3D).

const PLAYERS := 4
const REACH_M := 90.0

var world: Node
var chunks: ChunkManager
var player: Node3D
var _players: Array[AudioStreamPlayer3D] = []
var _timer := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	for i in PLAYERS:
		var p := Audio3D.make("water_flow", self, "Flow%d" % i)
		p.stream = SoundSynth.stream("water_loop", i)
		p.volume_db = -60.0
		p.play(randf() * 3.0)
		_players.append(p)


func _process(delta: float) -> void:
	if world == null or chunks == null or chunks.rivers == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4
	var map: PlanetData = world.get("planet")
	var pd: Vector3 = world.dir_of(player.global_position)
	var cell := map.cell_at(pd)
	var rivers: RiverNetwork = chunks.rivers
	# The segments round here, nearest first.
	var near: Array = []
	var seen := {}
	for k in 9:
		var c := cell if k == 8 else map.neighbors[cell * 8 + k]
		for s in rivers.segments_near(map, c):
			if seen.has(s):
				continue
			seen[s] = true
			var dt := rivers.closest_dt(s, pd)
			if dt.x < REACH_M + rivers.width[s]:
				near.append([dt.x, s, dt.y])
	near.sort_custom(func(x, y): return x[0] < y[0])
	for i in PLAYERS:
		var p := _players[i]
		if i >= near.size():
			p.volume_db = lerpf(p.volume_db, -60.0, 0.5)
			continue
		var s: int = near[i][1]
		var t: float = near[i][2]
		var pa := rivers.a[s]
		var at := (pa + (rivers.b[s] - pa) * t).normalized()
		var flow := Current.flow_at(rivers, map, at)
		p.global_position = world.to_scene(at, PlanetConst.RADIUS_M + rivers.level_at(s, t) + 0.3)
		var loud := clampf(0.25 + float(flow.speed) * 0.35 + rivers.width[s] / RiverNetwork.MAX_WIDTH_M * 0.4, 0.0, 1.0)
		p.volume_db = lerpf(p.volume_db, linear_to_db(maxf(loud, 0.001)) - 4.0, 0.5)
		p.pitch_scale = 0.9 + 0.2 * clampf(float(flow.speed) / 3.0, 0.0, 1.0)
