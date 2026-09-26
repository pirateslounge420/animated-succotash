# Day cycle data

`day_cycle.json` sets the clock, the sun's four phases and the moon.
Edit it; changes apply the next time you run the game. While developing,
`data/dev.json` can override the day length.

| Field | Meaning |
|---|---|
| `day_length_min` | Real minutes per in-game day (game: 120). |
| `phase_min` | Real minutes of each phase in a `day_length_min` day at the equator: `day` (sun more than `twilight_deg` up), `dusk` and `dawn` (sun within `twilight_deg` of the horizon) and `night`. They should add up to `day_length_min`. If the day length changes (the dev clock), every phase scales with it. |
| `twilight_deg` | Dawn and dusk run while the sun is within this many degrees of the horizon. |
| `rate_blend_min` | How gradually the sky changes speed between phases, in minutes of a `day_length_min` day. The sky turns slowly through dawn and dusk and faster by day and night; this is how long each change of speed takes. Larger is gentler; it can't exceed the shortest phase. |
| `moon_cycle_days` | In-game days from one new moon to the next (Earth: 29.5). The moon also passes through all 28 lunar mansions in this time. |
| `weather_smoothing_s` | Real seconds for the sky, clouds and rain to follow a change in the local weather about two-thirds of the way. The weather updates in steps; this eases them so the light never jumps. |
| `cloud_light_band_deg` | Sun elevations (degrees, low to high) over which the clouds' lighting turns from the moon's direction to the sun's. |
| `glyph_fade_s` | Seconds the lunar-mansion glyph takes to fade out (and again to fade back in) when the moon moves into the next mansion. |
