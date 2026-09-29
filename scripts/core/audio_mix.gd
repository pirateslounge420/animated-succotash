class_name AudioMix
## The player's volume sliders (the settings panel's Audio section): the
## master volume, and two groups of sounds on buses of their own so they
## can be turned down on their own: the footsteps (walking, running,
## landings, the skid of a sharp turn and a wall jump's kick: Footsteps) and
## the climbing (hands on the bark, the breaths between reaches:
## TreeContact). Settings "audio.master", "audio.footsteps" and
## "audio.climbing", each 0-100 %: 100 % is a group's full level (what it
## was before the sliders), 0 mutes it. From play (2026-09-29): the climbing
## and the walking and running were too loud, so both start at half.

## Group -> its bus.
const BUSES := {"footsteps": "Footsteps", "climbing": "Climbing"}
## Each slider's setting and its level in a new game (%).
const DEFAULTS := {"audio.master": 100, "audio.footsteps": 50, "audio.climbing": 50}


## The bus a group's players play on, made (sending to Master, at its
## slider's level) the first time it's asked for.
static func bus(group: String) -> String:
	var name: String = BUSES.get(group, "Master")
	if AudioServer.get_bus_index(name) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
		_level(name, percent("audio." + group))
	return name


## A slider's level (%), saved or its default.
static func percent(key: String) -> int:
	return clampi(int(Settings.get_value(key, DEFAULTS.get(key, 100))), 0, 100)


## Set a slider (saved at once) and hear it straight away.
static func set_percent(key: String, pct: int) -> void:
	Settings.set_value(key, clampi(pct, 0, 100))
	apply(key)


## Put the saved levels on the buses (`key`: just that slider's).
static func apply(key := "") -> void:
	for k in DEFAULTS:
		if key != "" and key != k:
			continue
		if k == "audio.master":
			_level("Master", percent(k))
		else:
			var group: String = str(k).trim_prefix("audio.")
			_level(bus(group), percent(k))


static func _level(bus_name: String, pct: int) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, pct <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pct / 100.0, 0.0001)))
