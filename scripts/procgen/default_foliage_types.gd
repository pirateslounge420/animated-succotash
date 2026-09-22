extends RefCounted
class_name DefaultFoliageTypes
## Example foliage type definitions demonstrating the data-driven pattern
## from FoliageType/FoliagePass. Swap or extend these per biome without
## touching foliage_pass.gd itself -- this is placeholder data, not a
## final plant roster.


static func get_all() -> Array[FoliageType]:
	var types: Array[FoliageType] = []
	types.append(_make("Grass Tuft", 0.2, 0.85, 0.2, 0.7, 0.35, Color(0.45, 0.7, 0.25), 0.4))
	types.append(_make("Pine", 0.15, 0.5, 0.35, 1.0, 0.18, Color(0.15, 0.4, 0.25), 2.2))
	types.append(_make("Broadleaf Tree", 0.45, 0.8, 0.4, 1.0, 0.15, Color(0.3, 0.55, 0.2), 2.5))
	types.append(_make("Desert Scrub", 0.55, 1.0, 0.0, 0.3, 0.08, Color(0.55, 0.5, 0.25), 0.6))
	types.append(_make("Mangrove", 0.55, 1.0, 0.65, 1.0, 0.2, Color(0.2, 0.45, 0.35), 1.6))
	types.append(_make("Frost Lichen", 0.0, 0.2, 0.0, 1.0, 0.12, Color(0.75, 0.8, 0.85), 0.2))
	return types


static func _make(
	type_name: String,
	temperature_min: float,
	temperature_max: float,
	moisture_min: float,
	moisture_max: float,
	density: float,
	marker_color: Color,
	marker_height: float
) -> FoliageType:
	var t := FoliageType.new()
	t.type_name = type_name
	t.temperature_min = temperature_min
	t.temperature_max = temperature_max
	t.moisture_min = moisture_min
	t.moisture_max = moisture_max
	t.density = density
	t.marker_color = marker_color
	t.marker_height = marker_height
	return t
