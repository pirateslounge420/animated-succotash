# Day cycle data

`day_cycle.json` sets the clock, the sun's four phases and the moon.
Edit it; changes apply the next time you run the game. While developing,
`data/dev.json` can override the day length.

| Field | Meaning |
|---|---|
| `day_length_min` | Real minutes per in-game day (game: 144). |
| `phase_min` | The reference: real minutes of each phase at the **equator on an equinox** (`day`: sun more than `twilight_deg` up; `dusk` and `dawn`: sun within `twilight_deg` of the horizon; `night`). The sky's three turning speeds are calibrated so that place and date get exactly these; everywhere else the phases **derive** from the latitude and the day of the year (long summer days and short winter ones away from the equator, midnight sun and polar night past the polar circles, twilight that lingers at high latitudes). The whole day is always `day_length_min`. |
| `twilight_deg` | Dawn and dusk run while the sun is within this many degrees of the horizon; they last as long as the sun takes to cross that band there. |
| `rate_blend_deg` | How gradually the sky changes speed between night, twilight and day, in degrees of the sun's elevation either side of each boundary. Larger is gentler. |
| `axial_tilt_deg` | The planet's tilt (Earth: 23.5). The sun's declination swings between plus and minus this over the year. 0 would make every day an equinox. |
| `year_days` | In-game days in a year (365 = 36.5 real days at the 144-minute day). |
| `year_start_day` | Day of the year at game day 0 (0 = the northern spring equinox, about 91 the June solstice, 182 the September equinox, 274 the December solstice). |
| `moon_cycle_days` | In-game days from one new moon to the next (Earth: 29.5). The moon also passes through all 28 lunar mansions in this time. |
| `full_moon_illumination` | [NOT WIRED YET — design §DG] The lit share of the moon's disc (0 new, 1 full) at or above which a night counts as a full-moon night: the werewolf hunts only then. 0.97 is about the three nights round full, a full moon every 70.8 hours of play (`tools/reference/moon_reference.py`). One number for every reader: `creature_species.gd` gates `active: full_moon` at 0.85 today (about seven nights) and `dread.gd` boosts the werewolf above a moonlight of 0.9; both should read this. |
| `weather_smoothing_s` | Real seconds for the sky, clouds and rain to follow a change in the local weather about two-thirds of the way. The weather updates in steps; this eases them so the light never jumps. |
| `cloud_light_band_deg` | Sun elevations (degrees, low to high) over which the clouds' lighting turns from the moon's direction to the sun's. |
| `glyph_fade_s` | Seconds the lunar-mansion glyph takes to fade out (and again to fade back in) when the moon moves into the next mansion. |
