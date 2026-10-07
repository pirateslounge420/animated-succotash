class_name HalfDark
extends Node
## A dark you can half see in (design 6 Oct §FC.4, crawler.json dark):
## with no flame near you, the stone close by reads faintly in the dark's
## own navy (readable_color), still readable at readable_m, gone to black
## by black_m; farther off you go by sound. Amends the "full dark between"
## the lights (§CJ.5, §ET.11 3): still dark, no longer blind at arm's
## length.
##
## Built as one weak light at your eye, your eyes adjusted to the dark:
## its colour is readable_color, so it only ever adds navy (never warmth,
## never grey); no shadow and no shine; its reach black_m, where it is
## exactly nothing: Godot's omni window, (1 - (d / black_m)^4)^2, nearly
## even out to readable_m and fading after, times 1 / d^falloff (0 in the
## data: no more dimming than that), its strength set so a wall facing you
## at readable_m gets fill_energy. (The grade's navy floor, look.json
## retro.colors.shadow_floor, swallows anything fainter than itself, so a
## weaker fill shows nothing at all.) It never lights what a flame
## already lights:
##
##   - your torch lit in hand: off at once (the torch's reach and look,
##     and a torchlit frame, are just as they were);
##   - a lit fire (the hearth, a relit holder or sconce), a lit planted
##     torch, or a fire pot's fire or lit wick (§FA.3) within its light's
##     reach of you, with a clear line from its flame to your eye: off,
##     eased over fade_s (a lit room looks as it did; a fire round a
##     corner doesn't count, its light doesn't reach);
##   - otherwise on, easing up over adjust_s as your eyes adjust.
##
## The torch's reach, the fires' light and the fog are untouched.

static var DARK: Dictionary = Tuning.table("crawler").get("dark", {})

## Off for an A/B (tools/crawler_frames.gd: the same frame with and
## without it).
var enabled := true
## 0 (a flame near: nothing added) .. 1 (no flame near: the dark readable).
var strength := 0.0
## The light at your eye (scene: the camera's child).
var light: OmniLight3D
var player: CrawlerPlayer


static func readable_m() -> float:
	return maxf(float(DARK.get("readable_m", 5.0)), 0.1)


static func black_m() -> float:
	return maxf(float(DARK.get("black_m", 12.0)), readable_m() + 0.1)


static func color() -> Color:
	return Color(str(DARK.get("readable_color", "#141c5c")))


## The light's energy: fill_energy on a wall facing you at readable_m,
## through Godot's omni falloff, (1 - (d / range)^4)^2 / d^falloff.
static func energy() -> float:
	var r := readable_m()
	var window := pow(1.0 - pow(r / black_m(), 4.0), 2.0)
	return float(DARK.get("fill_energy", 1.5)) * pow(r, float(DARK.get("falloff", 1.0))) / maxf(window, 0.01)


func setup(p: CrawlerPlayer) -> void:
	player = p
	light = OmniLight3D.new()
	light.name = "HalfDarkLight"
	light.light_color = color()
	light.light_energy = 0.0
	light.light_specular = 0.0
	light.shadow_enabled = false
	light.omni_range = black_m()
	light.omni_attenuation = float(DARK.get("falloff", 1.0))
	light.visible = false
	# Not a fire (the one-firelight check passes it by, §EX.6).
	light.set_meta("half_dark", true)
	p.camera().add_child(light)


func _physics_process(delta: float) -> void:
	if player == null or light == null:
		return
	if not enabled or player.torch.lit():
		# Your own flame: nothing added, at once.
		strength = 0.0
	elif flame_near():
		strength = maxf(strength - delta / maxf(float(DARK.get("fade_s", 0.4)), 0.01), 0.0)
	else:
		strength = minf(strength + delta / maxf(float(DARK.get("adjust_s", 1.2)), 0.01), 1.0)
	light.light_energy = energy() * smoothstep(0.0, 1.0, strength)
	light.visible = strength > 0.001


## A flame near you now: your torch lit in hand, or a lit fire, planted
## torch or fire pot's fire or wick within its light's reach of your eye
## with a clear line between.
func flame_near() -> bool:
	if player.torch.lit():
		return true
	var eye := light.global_position
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		var n := f as Node3D
		if n == null or not n.is_inside_tree():
			continue
		var l := n.get_node_or_null("Light") as OmniLight3D
		if l != null and l.global_position.distance_to(eye) < l.omni_range and FireStore.is_lit(n) and _clear(l.global_position, eye):
			return true
	for pt in PlantedTorch.all:
		if not is_instance_valid(pt) or not pt.is_inside_tree() or not pt.lit():
			continue
		var at := pt.global_position + pt.up * float(Tuning.section("torch", "planted").get("stand_height_m", 0.9))
		if at.distance_to(eye) < float(Torch.L.get("range_m", 14.0)) and _clear(at, eye):
			return true
	# A fire pot's fire (§FA.3, FirePots): a burning patch, a burst, a fire
	# caught; and a lit wick, the pot in your hand or one in the air.
	var fp := FirePots.instance
	if fp != null and is_instance_valid(fp):
		for f in fp.fires:
			var pf := f as PotFire
			if pf == null or not is_instance_valid(pf) or not pf.burning():
				continue
			var pl := pf.light()
			if pl != null and pl.is_inside_tree() and pl.global_position.distance_to(eye) < pl.omni_range and _clear(pl.global_position, eye):
				return true
		var wick_m := float((FirePots.D.get("wick", {}) as Dictionary).get("light_range_m", 4.0))
		for w in FirePots.flares():
			var wp: Vector3 = w.pos
			if wp.distance_to(eye) < wick_m and _clear(wp, eye):
				return true
	return false


## No stone between `a` and `b` (the tomb's collision; your body passed).
func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, PropCollision.WORLD_LAYER)
	q.exclude = [player.get_rid()]
	q.hit_from_inside = false
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
