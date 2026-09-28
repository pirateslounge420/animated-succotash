class_name Handholds
## How a handhold behaves when caught and swung on (design reconciliation:
## the limit lives in the handhold, not the player). From
## data/handholds.json: the species' own `handhold` block, else its genus
## row, else bamboo or vine, else the default; dead wood brittle, saplings
## whippy, thinner wood breaking sooner and bearing less.
## Returns {break_speed_mps, flex, snapback, hold_load}.

const FILE := "res://data/handholds.json"
static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		_data = parsed if parsed is Dictionary else {"default": {"break_speed_mps": 14.0, "flex": 0.3, "snapback": 0.2, "hold_load": 3.0}}
	return _data


static func props(g: BranchGraph, i: int) -> Dictionary:
	var d := data()
	var out: Dictionary = (d.get("default", {}) as Dictionary).duplicate()
	var sp: PlantSpecies = SpeciesDB.all()[g.species] if g.species >= 0 else null
	var vine := g.is_vine(i)
	var bamboo := sp != null and sp.shape == PlantSpecies.Shape.BAMBOO
	if vine:
		out.merge(d.get("vine", {}), true)
	elif bamboo:
		out.merge(d.get("bamboo", {}), true)
	elif sp != null and (d.get("genus", {}) as Dictionary).has(sp.genus):
		out.merge(d.genus[sp.genus], true)
	if sp != null and not vine:
		out.merge(sp.handhold, true)
	# Thinner wood breaks sooner and bears less (not vines or bamboo).
	if not vine and not bamboo:
		var k := clampf(g.radius[i] / maxf(float(d.get("ref_radius_m", 0.08)), 0.001), 0.4, 3.0)
		out.break_speed_mps = float(out.break_speed_mps) * k
		out.hold_load = float(out.hold_load) * k
		if g.height_m < float(d.get("sapling_height_m", 6.0)):
			var sap: Dictionary = d.get("sapling", {})
			out.break_speed_mps = float(out.break_speed_mps) * float(sap.get("break_scale", 0.6))
			out.flex = minf(float(out.flex) + float(sap.get("flex_add", 0.3)), 1.0)
	if g.dead:
		var dd: Dictionary = d.get("dead", {})
		out.break_speed_mps = float(out.break_speed_mps) * float(dd.get("break_scale", 0.35))
		out.hold_load = float(out.hold_load) * float(dd.get("hold_scale", 0.5))
		out.flex = float(dd.get("flex", 0.03))
		out.snapback = float(dd.get("snapback", 0.0))
	return out
