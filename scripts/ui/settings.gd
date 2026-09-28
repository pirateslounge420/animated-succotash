class_name Settings
## The player's settings (user://settings.cfg): keys like "hud.speedometer"
## (section.key). Read anywhere with get_bool(); the settings panel
## (SettingsPanel, O or F10) changes and saves them.

const PATH := "user://settings.cfg"
static var _cfg: ConfigFile


static func _load() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	_cfg.load(PATH) # missing on a first run: every setting at its default


static func get_bool(key: String, default := true) -> bool:
	_load()
	var p := key.split(".", true, 1)
	return bool(_cfg.get_value(p[0], p[1] if p.size() > 1 else "value", default))


static func set_bool(key: String, v: bool) -> void:
	_load()
	var p := key.split(".", true, 1)
	_cfg.set_value(p[0], p[1] if p.size() > 1 else "value", v)
	_cfg.save(PATH)
