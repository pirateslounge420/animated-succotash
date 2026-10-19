# The real Earth (design §FX, 18 Oct 2026)

The planet is the real Earth at 1/100 sideways and 1/10 up (the sizes are in
`data/world_scale.json`, unchanged). Three rasters put it in the game, all equirectangular
(row 0 is the north edge at +90°, column 0 the −180° edge, sample centres at the half-step),
each built once from a public source by Claude Code's build script (queue 103–105) and
committed small. **The sources are not in the repo**: they are hundreds of MB each and live
in a gitignored folder outside it; the script rebuilds the small files from them.

| file | what | size | source | licence |
|---|---|---|---|---|
| `relief.bin` (+ header in `earth.json → relief`) | elevation and sea floor, int16 Earth metres, 10 arc-minutes (2,160 × 1,080) | ~4.7 MB | ETOPO 2022, 60″ ice surface, NOAA NCEI, doi:10.25921/fd45-gt74 | US government work; cite it |
| `climate_bio1.bin`, `_bio5`, `_bio6`, `_bio12`, `_bio15` | mean annual temperature, warmest-month high, coldest-month low, annual precipitation, rain seasonality; int16, 0.25° (1,440 × 720) | ~2 MB each | CHELSA V2.1 climatologies 1981–2010, 30″ (Karger et al. 2017) | CC0 1.0 |
| `ecoregions.bin` + `ecoregions.json` | ECO_ID per sample at 0.1° (3,600 × 1,800, uint16, 0 = none) and the attribute table | a few MB | RESOLVE Ecoregions 2017 (Dinerstein et al. 2017), 846 ecoregions, 14 biomes, 8 realms | CC BY 4.0 (credit required) |

The rules files are Claude (chat)'s and are data, not code:

- **`earth.json`**: the switch (`on`), every raster's header, sea level, the great ranges'
  stretch (`ranges.stretch_max`, 1.0 = honest), the named peaks, the credit lines, and the
  known places the headless checks test against.
- **`realms.json`**: how each ecoregion gets one of the game's 17 realms (§AA): RESOLVE's realm
  as the default, then named overrides for the finer nine (madagascar, malesia, himalaya,
  central_asia, west_asia, mediterranean, sino_subtropical, east_asia_temperate, andes).
  `tools/earth_data_check.py --ecoregions data/earth/ecoregions.json --write` applies them and
  writes `ecoregion_realms.json`, which `RealmMap` reads.
- **`biome_map.json`**: which of the 52 templates each RESOLVE biome may become; `biome_pass`'s
  climate and landform rules pick among them.

## Why these sources
ETOPO is the standard global relief grid and holds land and sea floor in one, so the shelves,
the deep ocean and the real coast all come from one file. CHELSA is public domain (CC0) where
WorldClim's site states no terms, and at 30″ it resolves the mountains' climate before it is
averaged down. RESOLVE 2017 is the current version of the WWF ecoregions, carries a realm
and a biome per ecoregion, and its CC BY licence only asks for the credit line that
`earth.json → credits` holds.

## Rebuilding
Run the build script (queue 103 writes it; the name is recorded in `earth.json` once it exists)
with the source folder; it downloads what is missing, block-averages, writes the small files
and fills the headers (`built`, `min_m`, `max_m`, `source_scale_offset`). Then:

```
python3 tools/earth_data_check.py                      # the rules files and the headers
python3 tools/earth_data_check.py --relief             # the relief against the known places
python3 tools/earth_data_check.py --ecoregions data/earth/ecoregions.json --write
python3 tools/reference/earth_reference.py             # the scale, slope and budget tables
```

## What the checks expect
`earth.json → checks`: land 27–31% of the sphere; the Dead Sea a lake below sea level; the
Caspian a lake, not an ocean; the Amazon, Nile and Mississippi mouths on the coast where they
are; Manaus hot and wet, Cairo dry, Cherrapunji the wettest, Verkhoyansk the coldest; the
Andes puna and páramo, Madagascar its own realm, Borneo malesia, Crete mediterranean.

## Known losses at this resolution
Islands narrower than about 20 km on Earth (200 m here) vanish from the 10′ relief. The
10′ average shaves the sharpest summits: Everest's cell is expected to read 600–700 m here,
not 885 (§FX.3; `peaks.restore_named` is the switch to stamp the named summits back, not
built). Every slope is ten times Earth's (§FX.3): the big ranges read as walls with valley
routes, which queue 106 reports range by range.
