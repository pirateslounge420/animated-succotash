class_name DeadWood
## Which trees stand dead (data/dead_wood.json): a share per biome, dry
## culms among the bamboo. Decided from the spot (a hash of its direction)
## so it's the same tree on every visit and the rest of the placement
## doesn't shift. Dead trees are drawn bare (the foliage shader: bare 1)
## and their handholds are brittle (Handholds).

const FILE := "res://data/dead_wood.json"
static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		_data = parsed if parsed is Dictionary else {"share": {"default": 0.03}, "bamboo_share": 0.15}
	return _data


static func is_dead(map: PlanetData, dir: Vector3, sp: PlantSpecies) -> bool:
	var share: float
	if sp.shape == PlantSpecies.Shape.BAMBOO:
		share = float(data().get("bamboo_share", 0.15))
	else:
		var shares: Dictionary = data().get("share", {})
		var b: int = map.biome[map.cell_at(dir)]
		var key: String = BiomeTemplates.KEYS[b] if b >= 0 and b < BiomeTemplates.KEYS.size() else ""
		share = float(shares.get(key, shares.get("default", 0.03)))
	var h := hash(Vector3i((dir * 1.0e7).round())) & 0xFFFF
	return float(h) / 65535.0 < share
