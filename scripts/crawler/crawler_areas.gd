class_name CrawlerAreas
extends Node
## Areas joined to the hub by fire (design §GD.1.2-4; queue 113;
## data/crawler.json areas). One per session (CrawlerMain makes it).
##
##   the area     the surface over the game's first ruin (Surface, sized by
##                areas.first.across_m), with its main hearth near one edge
##                (Surface.area_hearth), cold until lit, and its ruin
##                entrance (the old stair) down into the ruin; the ruin's
##                way out brings you back up near the mouth (CrawlerMain)
##   lighting     hold your torch's flame to the cold hearth (reach_m, for
##                light_hold_s): it catches, and the link is kept in the
##                game's save (CrawlerSave.data.areas)
##   travel       the interact button at the hub fire (or beside the
##                cook-shaman): her powder turns the flames the area's
##                colour, a wash of it fills the frame, and you step out at
##                the area's hearth; at the area's hearth the same button
##                brings you home
##   stand-in     until §GD.5 call 1 is answered, she opens the first link
##                herself (stand_in_first_link): the first trip works
##                unlinked, the cold hearth brings you home this session,
##                and lighting it keeps the link
##   brand        stepping through with no lit torch, you carry one lit
##                from the hub fire (brand)

static var A: Dictionary = Tuning.table("crawler").get("areas", {})

var main: CrawlerMain
## The first link opened by the stand-in this session (not saved).
var session_open := false
var _hold := 0.0
var travels := 0


static func on() -> bool:
	return bool(A.get("on", true))


static func first() -> Dictionary:
	return A.get("first", {})


static func colour() -> Color:
	return Color(str(first().get("colour", "#3fd0ff")))


## Is the first area linked in this game (its hearth lit, kept)?
static func linked() -> bool:
	return bool(((CrawlerSave.data.get("areas", {}) as Dictionary).get("first", {}) as Dictionary).get("linked", false))


static func set_linked() -> void:
	var a: Dictionary = CrawlerSave.data.get("areas", {})
	a["first"] = {"linked": true}
	CrawlerSave.data["areas"] = a
	CrawlerSave.save()


## Can you go from the hub to the first area now?
func can_go() -> bool:
	return linked() or session_open or bool(A.get("stand_in_first_link", true))


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
	var p := main.player.global_position
	var reach := float(A.get("interact_reach_m", 3.0))
	var hub := _hub()
	if hub != null:
		var near_fire := Vector2(p.x - hub.camp.pos.x, p.z - hub.camp.pos.z).length() <= reach
		var near_shaman := hub.shaman != null and p.distance_to(hub.shaman.global_position) <= reach
		if (near_fire or near_shaman) and can_go():
			if not linked():
				session_open = true
			to_area()
			return true
		return false
	var area := _area()
	if area != null and area.area_hearth != null:
		var hp := area.area_hearth.global_position
		if Vector2(p.x - hp.x, p.z - hp.z).length() <= reach and (area.hearth_lit() or session_open):
			to_hub()
			return true
	return false


## Hub -> the first area, through the fire.
func to_area() -> void:
	if main.leaving:
		return
	main.leaving = true
	var hub := _hub()
	GameLog.add(str(A.get("log_go", "The flames turn, and you step through.")), "world")
	var T: Dictionary = A.get("travel", {})
	var kept := _tint_fire(hub.fire, colour()) if hub != null else {}
	await main.get_tree().create_timer(maxf(float(T.get("flame_s", 1.2)), 0.0)).timeout
	await main._wash(colour(), 1.0, float(T.get("wash_s", 1.0)))
	_untint_fire(kept)
	if bool(A.get("brand", true)):
		_brand()
	main._to_area_now()
	travels += 1
	await main._wash(colour(), 0.0, float(T.get("wash_s", 1.0)))
	main.leaving = false


## The first area -> the hub, through its hearth.
func to_hub() -> void:
	if main.leaving:
		return
	main.leaving = true
	GameLog.add(str(A.get("log_home", "Through the fire, home to the camp.")), "world")
	var T: Dictionary = A.get("travel", {})
	await main._wash(colour(), 1.0, float(T.get("wash_s", 1.0)))
	main._to_hub_now()
	travels += 1
	await main._wash(colour(), 0.0, float(T.get("wash_s", 1.0)))
	main.leaving = false


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
