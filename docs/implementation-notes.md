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
  Landmarks            ruins and glowing places (bioluminescent night)
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
     Small specialty pockets are then held to DESIGN.md's sizing (hot
     springs 1 km², oases 2, bogs and fens 5, cloud forest 12, ...):
     oversized patches are eroded from the rim inward.

  With seed 42 it takes about 7-8 s.
- **Sampling** (`PlanetData.sample`, `weights_at`). Bilinear between cell
  centers, switching to a neighbor-aware kernel within half a cell of a
  cube-face edge, so climate and ground colors run on seamlessly across
  face edges.
- **Distances** (`CubeSphere.angle_between`). Use the chord length, not
  `acos(dot)`: with 32-bit vectors, acos can't resolve anything under
  ~20 m on this planet.

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
- **Traveling systems:** on its own the coarse grid settles into a steady
  state, so 11 seeded synoptic systems ride on it:
  - mid-latitude lows in the westerly belts;
  - tropical cyclones over warm ocean, drifting poleward;
  - broad highs.

  Each is steered by the simulated wind, grows and decays over 2-6 days,
  and adds its pressure to the field. Wind, rising air, rain, storms and
  clearing all respond through the same rules.

Uses:
- **Spin-up:** 8 in-game days of spin-up, then 12 days of averaging, give
  the climate the biomes are built from. Precipitation is rescaled to a
  1000 mm planet-wide mean.
- **Live weather:** the same simulation keeps running during play, one
  step per in-game quarter hour. `local_weather(dir, elevation)` returns
  wind, rain rate, snow or not, temperature, storm level (0-1,
  continuous) and cloud cover at the player. It also adds what the 10 km
  grid can't resolve:
  - land/sea breezes, onshore by afternoon and offshore at night;
  - gusts;
  - drifting shower cells. The grid's rain rate is an areal average, so
    it falls locally in showers whose coverage grows with intensity,
    keeping the long-run totals.
- **Effects:** `WeatherFX` turns that into rain or snow that leans with
  the wind. The same wind vector sways all foliage.

Verified:
- equator ~2000 mm/yr, subtropical deserts ~120 mm/yr;
- a windward coast at 2430 mm/yr against 1140 mm/yr in the rain shadow;
- over one in-game day, the wind turns 28-31° in the steady tropical
  trades and 40-100° at mid and high latitudes, with gusts;
- storms form and dissipate everywhere (none persist for 5 days), and
  the storm level at a spot builds and fades rather than switching;
- rain is intermittent: 10-25% of hours in wet climates, with
  occasional downpours above 2 mm/h;
- precipitation falls as snow wherever the air at the player's height is
  below freezing, including on mountains above rain-fed lowlands.

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
- **Grade** (`PostGrade`), always on:
  - PS1-style 15-bit color through a 4×4 ordered dither;
  - vibrance for greens and blues.

  At night it adds sharpening, crushed contrast and a cobalt/violet push
  in the shadows. Inside glowing sites it adds extra contrast.

## Look

`shaders/look.gdshaderinc`, `scripts/sky/look.gd`

- **Day:** a deep ultramarine zenith over a Frutiger Aero aqua horizon
  band, punchy greens, and saturated turquoise/ultramarine water. It uses
  a linear tonemap, because filmic washes colors toward realism.
- **Flat bands:**
  - the sky gradient is stepped;
  - clouds are three-tone cel shapes;
  - distance fog is drawn by the world shaders in hard-edged bands
    (N64-style) instead of the Environment's smooth fog.

  Low ground below eye level fills with extra mist, strongest at night.
- **Texture and lighting economy:**
  - The world is vertex-colored, plus one deliberately low-res 32 px
    nearest-filtered grain texture on the ground, far terrain and ruins.
  - Lighting is flat: Lambert diffuse on face normals, with specular
    disabled everywhere except water.
  - At night the ground gets a hard-edged toon highlight, for the wet
    look.
  - Creature and prop materials are Lambert with no specular too.
- **Bioluminescent night** (the third palette): see Landmarks.

## Landmarks

`scripts/landmarks/`

- **Ruins** (`Ruins`, `RuinBuilder`). At most one per 3.2 km cell, placed
  on the most prominent rise:
  - castles on hills: a buried motte, an octagonal curtain wall with
    breaches and a gate gap, corner towers, and a tall keep with a fallen
    corner;
  - lone towers 14-22 m tall;
  - aqueducts striding level on tall piers, with some spans fallen.

  All of it is stacked stone blocks, so collapse is jagged column tops,
  V-shaped breaches, missing window blocks and rubble at the foot. Moss
  greens the upward faces and low courses, and ivy hangs from broken
  tops. Geometry is built on worker threads out to 2.6 km, beyond the
  terrain chunks, so silhouettes rise out of the fog bands. Deep footings
  keep them from floating over the coarser far terrain. Vegetation keeps
  their footprints clear.
- **Glowing places** (`MagicSites`, `Landmarks`): every ruin, every
  mythical territory, and about a third of fresh lakes and wetland cells
  (glow ponds).
  - The nearest 8 go to every world shader. After dark, water there shines
    from within, moss on ruins and ground glows in patches, and about half
    the plants glow at their tips, in teal drifting to cobalt.
  - A pool of 6 OmniLights near the player lets the glow light the scene.
  - Standing inside a site at night dims the moonlight and ambient, pulls
    the sky toward black and raises contrast, so it reads as neon against
    black.

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
  in water. Mythical folk campsites and ruins are kept clear.
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

Verification scripts measure behavior rather than reading code; the
latest results:

- **Wind, storms, rain and snow:** see Weather above.
- **Biome borders** blend over about 1 km, with no step larger than 0.006
  in color per 25 m. Cube-face edges are seamless (a 0.78 color jump
  before the fix).
- **Walking between biomes:** tree species overlap strongly between
  neighboring chunks, with lower overlap only at coasts.
- **Clumping:** plant counts per 32 m quadrat have a variance/mean ratio
  of 2-13, so plants are clumped rather than sprinkled evenly (1 would
  be random).
- **Gallery forests:** in dry country, trees stand at 46-56 per hectare
  within 100 m of rivers against 12-13 farther out.
- **Epiphytes:** 97% sit within their host's crown, on average about 4 m
  from its trunk.
- **Canopy dwellers:** all 56 in a temperate forest perched on tree
  instances that exist in the loaded chunk, within 0.54 m of the crown
  top, and still did after 40 s of hopping.
- **Wolf packs** close in when the player approaches. When the player
  leaves, the pack retreats and is home within about 16 m of the den.
- **Mythical calls** go from low-pass 700 Hz with 0.05 stereo panning at
  900 m to 20 kHz with full panning at 60 m.


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
- **Foliage wind.** One wind vector (the local weather at the player)
  sways every plant in view. That's right at walking scale, but plants a
  few kilometers off don't feel their own local wind.
- **Weather grid.** The live grid is coarse (~10 km cells); breezes,
  gusts and showers are local detail added at the player, not simulated
  across the planet.
- **Salt flats** aren't size-capped. They're salt lakes of any size, and
  a few reach 50+ km².
