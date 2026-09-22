extends Resource
class_name FoliageType
## Declares the temperature/moisture range a plant type tolerates, per
## DESIGN.md section 3 ("Foliage") -- FoliagePass spawns this type
## wherever a land cell's climate falls in range, independent of biome.

@export var type_name: String = ""
@export var temperature_min: float = 0.0
@export var temperature_max: float = 1.0
@export var moisture_min: float = 0.0
@export var moisture_max: float = 1.0
## Chance a single qualifying cell spawns this type (0-1); not a density
## in the "plants per square meter" sense, just a per-cell roll.
@export var density: float = 0.1
@export var marker_color: Color = Color.WHITE
## Placeholder marker height; stands in for the real model (DESIGN.md
## section 8: prototype uses greybox geometry, not final art).
@export var marker_height: float = 1.0


func matches(temperature: float, moisture: float) -> bool:
	return (
		temperature >= temperature_min and temperature <= temperature_max
		and moisture >= moisture_min and moisture <= moisture_max
	)
