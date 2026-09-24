# Implementation notes

How the code implements [`DESIGN.md`](../DESIGN.md): what each part does,
where it lives, how it was checked, and what's still missing. The design
spec is the source of truth; this file describes the prototype.

## Overview

```
World (autoload)       planet blueprint, clock, live weather, floating origin
  PlanetGenerator      builds the blueprint once at startup (worker thread)
main.gd                orchestrates the playable scene:
  ChunkManager         terrain + water + plants streamed around the player
  FarShell             coarse distant terrain and sea
  SkySystem            sun, moon, sky shader, ambient, fog
  WeatherFX            rain/snow particles, wind on foliage
  PlanetPlayer         third-person explorer with planet gravity
  CreatureSpawner      wildlife, wolf packs, mythical creatures, logs
  Hud, MapOverlay, PostGrade
```

Only the coarse blueprint is built for the whole planet, because the
weather simulation and river network need global data. Everything at
walking scale is computed on demand from pure functions of that
blueprint, on worker threads, and thrown away when the player leaves.
Going back to a place rebuilds it identically.

## Planet

`scripts/planet/`

- **Size.** Circumference 400 km, radius 63.66 km (`PlanetConst`). Y is
  the spin axis.
- **Cube-sphere addressing** (`CubeSphere`). Six faces with a tangent warp
  (u, v → tan(u·π/4)), so cells are close to equal in area. It also
  provides latitude/longitude, local east/north frames and great-circle
  distance.
- **Terrain** (`TerrainField`). One continuous 3D-noise height function,
  so every consumer agrees on the height at any point:
  - continents calibrated to 62% ocean;
  - ridged mountain belts, continental shelves and 9 volcanic hotspots;
  - a fine detail layer used only by walkable chunks.
- **Blueprint** (`PlanetData`). 6 × 96² cells of about 1 km each. It is
  built by `PlanetGenerator` in order:
  1. `terrain_pass`: elevation and slope.
  2. `hydrology_pass`: ocean basins (connected water areas of 300+
     cells), lakes filled by priority-flood, flow directions, distance to
     coast and to water.
  3. Weather spin-up (see below). It produces the long-term climate.
  4. `climate_pass`:
     - temperature in °C (lapse rate 6.5 °C/km);
     - precipitation in mm/year, wetter on windward slopes and drier in
       rain shadows;
     - fog;
     - an aridity-based moisture index (0-1).
  5. `hydrology_pass` rivers: discharge weighted by precipitation; the
     top 3.5% of land flow becomes rivers. Also salt lakes in closed
     basins and brackish river mouths.
  6. `geology_pass`: 8 rock types (granite, basalt, karst, sandstone,
     alluvium, coastal sand, clay/peat, glacial till).
  7. `biome_pass`: one of 51 biome templates per cell, by priority rules.

  With seed 42 it takes about 6-8 s.

## Weather

`scripts/weather/weather_sim.gd`: a coarse causal simulation on
6 × 10 × 10 cells.

- **Wind:** from pressure gradients, turned by up to 80° with latitude
  (Coriolis), plus prevailing trade-wind and westerly belts.
- **Transport:** pressure and temperature anomalies and humidity are
  carried downwind (semi-Lagrangian advection).
- **Rising and sinking air:** rising air in lows cools and rains; sinking
  air in highs warms and clears; mountains force air up (orographic lift).
- **Storms:** latent heat deepens lows into storms, with a cap. Clouds
  shade the ground.
- **Stability:** pressure diffuses and total mass is conserved.
- **Chaos:** the simulation is seeded and chaotic; a tiny nudge grows to a
  2-3 hPa difference within days.

Uses:
- **Spin-up:** 8 in-game days of spin-up, then 12 days of averaging, give
  the climate the biomes are built from. Precipitation is rescaled to a
  1000 mm planet-wide mean.
- **Live weather:** the same simulation keeps running during play, one
  step per in-game quarter hour. `local_weather(dir, elevation)` returns
  wind, rain rate, snow or not, temperature, storm and cloud cover at the
  player.
- **Effects:** `WeatherFX` turns that into rain or snow that leans with
  the wind. The same wind vector sways all foliage.

Verified:
- equator ~2000 mm/yr, subtropical deserts ~120 mm/yr;
- storm belts stormy 13-29% of the time;
- a windward coast at 2340 mm/yr against 1120 mm/yr in the rain shadow.

## Time, sun and moon

`scripts/sky/`

- **Day length.** One day is 48 real minutes (`PlanetConst.DAY_LENGTH_S`).
  Sunrise and sunset are counted at a sun elevation of −3.6°, so twilight
  counts as day and the lit part is slightly longer than the night: about
  25 against 23 minutes at the equator. The planet has no axial tilt, so
  there are no seasons yet.
- **Earth-like moon** (`Astro.moon_dir`, `MoonMode.ORBITAL`, the default):
  - it orbits once per 28-day phase cycle on an orbit tilted 5.1°;
  - elongation from the sun sets the phase, so a full moon rises at
    sunset, a new moon travels with the sun, and quarter moons are up
    half the day;
  - it rises about 51 minutes of game time later each day.

  `MoonMode.LOCKED_OPPOSITE` keeps the original always-opposite
  behavior as an option.
- **28 lunar mansions** (`LunarMansions`). The mansion follows the moon
  around its orbit. Its star glyph is drawn next to the moon in the sky
  shader, tinted by its guardian beast's color.
- **Lighting** (`SkySystem`):
  - two DirectionalLight3Ds (sun and moon), with intensity and color set
    by elevation; the moon's also scales with phase;
  - a continuous palette runs from Frutiger Aero day, through dusk, to a
    cobalt/violet night;
  - the sky shader draws the moon disc with a phase terminator, stars and
    clouds from the live weather;
  - ambient light and fog follow.
- **Night grade** (`PostGrade`): sharpening and a violet tint on the
  screen at night, for the crunchy look.

## Walkable terrain

`scripts/terrain/`

- **Chunks** (`TerrainChunk`). 384 per face edge, each about 260 m with
  32 × 32 flat-shaded quads of about 8 m:
  - heights come from `TerrainField` with the detail layer;
  - rivers are carved in with water ribbons (`RiverNetwork`);
  - lake, sea and wetland water tables are added;
  - ground color blends nearby biomes, with sand at shores, rock on steep
    faces and snow wherever it's below freezing at that height.
- **Streaming** (`ChunkManager`):
  - the view ring (3 chunks) gets ground, water and trees;
  - the detail ring (1 chunk) adds undergrowth;
  - geometry and plant placement are computed on WorkerThreadPool; nodes
    are attached a few per frame;
  - the loading screen blocks only for the detail ring.
- **Floating origin** (`World`). The planet center is stored in double
  precision and everything under `world_root` shifts when the player
  gets 1.5 km from the origin.
- **Far shell** (`FarShell`). A coarse sphere mesh for distant land and
  sea, sunk slightly and hidden inside the chunk radius.

Measured with the compatibility renderer:
- blocking load of 13 chunks in about 5 s;
- streaming to 50 chunks in about 3 s;
- per chunk: terrain 18 ms, trees 51 ms, undergrowth ~330 ms, all on
  worker threads.

**Thread safety note.** Godot 4.3 can corrupt nested constant arrays when
several threads read them at once. Anything the chunk workers read is
therefore a flat packed array (`BiomeTemplates._colors`) or a private
copy.

## Vegetation

`scripts/ecology/` and `data/biomes/*.json`

- **Plants are data.** Each biome file lists plants per tier (emergent,
  canopy, shrub, ground, epiphyte). A plant's default tolerance is its
  biome's climate block (°C, moisture, altitude). Listing a plant in
  several biomes gives it the union of their ranges. `SpeciesDB` loads
  all files; currently 80 species, in 34 of the 51 files.
- **Plants read climate, not biome names.** At each candidate site on a
  jittered grid (spacing per tier), `VegetationPlacer` combines:
  - temperature at the exact height, adjusted for aspect (equator-facing
    slopes are warmer and drier);
  - moisture boosted near water, so rivers get gallery forests;
  - bell-shaped suitability bands;
  - soil from rock type;
  - special needs (standing water, river bank, salt, hot ground);
  - per-species dominance over ~1.5 km (one valley spruce, the next
    fir);
  - patch clumping, and shade thinning the ground cover;
  - size and lean jitter.

  Epiphytes attach to placed trees; cypress knees ring cypresses standing
  in water. Mythical folk campsites are kept clear.
- **Rendering.** One MultiMesh per species. `PlantMeshes` builds 24
  low-poly placeholder shapes; the foliage shader sways them with the
  live wind.

## Creatures

`scripts/creatures/` and `data/creatures/creatures.json`

Creatures read the terrain and the placed vegetation: temperature at the
exact spot, moisture, ground cover, trees (canopy dwellers perch on
actual placed trees) and water depth.

Spawn tiers:

- **Interaction.** Fallen logs lie near trees in forests. Pressing E
  within 2 m rolls a log over, revealing damp soil and, if the climate
  suits, 6-12 beetles that scurry off and burrow.
- **Ambient** (`CreatureSpawner`). Each species has a planet-wide
  jittered grid with one candidate spot per circle of `one_per_radius_m`.
  - Spots within 140 m whose habitat fits get a creature while its time
    of day lasts; it fades out when you leave.
  - The same spot always gives the same answer, so wildlife feels
    persistent with no off-screen simulation.
  - Behaviors by role:
    - ground dwellers graze and bolt;
    - canopy dwellers hop between crowns;
    - waders step in the shallows and ducks paddle on open water, and
      both take off when startled;
    - fireflies drift.
- **Pack hunters.** Wolf dens are cave mouths on steep, cold slopes,
  found per grid cell.
  - Packs rest by day and patrol their territory at night.
  - They howl in call-and-response: members answer the leader, and
    neighboring packs answer back.
  - Once they notice you, they spread out and close in to about 9 m,
    then drift home when you leave.
- **Mythical** (`Territories`). At most one territory per 1.6 km cell,
  chosen among the mythical species whose climate fits.
  - **Dormant** beyond 1 km: nothing exists.
  - **Aware** from 1 km: unseen but pacing and calling. Calls are
    low-pass filtered and nearly mono far away, then sharpen with
    distance.
  - **Visible** within 220 m.
  - Temperament decides what they do:
    - hostile ones stalk at a distance and freeze while you look at them;
    - neutral ones watch you, and wisps drift ahead, leading you on;
    - friendly ones walk over to you.
  - Folk (troll, witch, goblin) keep a campfire with a warm light: the
    spec's warm "pop" against the blue night.

Sounds are synthesized placeholders (`SoundSynth`): chirp, call, croak,
howl, drone and whisper. Bodies are primitive low-poly placeholders
(`CreatureBodies`).

## UI

- **HUD:**
  - time of day, moon phase and mansion;
  - biome, temperature now and on average (°C), weather, rainfall, wind,
    elevation and coordinates;
  - a context prompt.
- **Map (M):** a globe lit by the real sun, colored by biome, elevation,
  temperature, rainfall or live weather.

## How it was tested

- **Headless.** The full game loop was run headless:
  - loading;
  - walking and fast travel with chunk streaming;
  - midnight with night creatures;
  - log interaction.

  No script errors.
- **Rendered.** Screenshots were rendered under xvfb with the
  compatibility renderer: day forest, dusk, night, rain, the map,
  wildlife, a campfire camp and a wolf den.
- **Climate checks.** Weather and climate checks cover the figures listed
  above; 49-50 of the 50 surface templates appear on each tested seed.

## Known gaps and next steps

- **Placeholder content.** Mansion star patterns are approximate (the
  star counts are right). Most plant and creature data is placeholder,
  and so are all the models and sounds.
- **Aquatic life.** There is no aquatic tier yet: no fish, coral or kelp
  meshes, and ocean biomes have no underwater plants.
- **Karst and caves.** The template is reserved, but the cave system is
  not built. Wolf dens mark where cave mouths will go.
- **Interaction between species.** Creatures ignore each other; predator
  and prey behavior is the spec's noted future layer.
- **Rendering.** Tested with the compatibility renderer; the Forward+
  look (MSAA, shadows) should be checked on real hardware.
