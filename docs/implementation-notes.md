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
- **Vertical scale** (`PlanetConst.HEIGHT_SCALE`, 1/10). Heights are a
  tenth of Earth's (Everest would be ~900 m; this world's peaks reach
  about 490 m), distances a hundredth. Rules and data keep real-world
  numbers and multiply them by the scale: biome and geology thresholds,
  species and creature altitude bands (data files stay in real meters),
  cloud altitudes, the haze height. The lapse rate is Earth's per
  Earth-equivalent kilometer (6.5 °C per 100 m here), so a 400 m summit
  has the climate of a 4 km one, and the blueprint's slope is stored as
  the Earth-equivalent rise over run. The walking-scale layers (detail,
  shore wiggle, roll) aren't scaled: they're the feel of the ground.
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
     - temperature in °C (lapse rate 6.5 °C per Earth-equivalent km,
       i.e. per 100 m here);
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
     oversized patches are eroded from the rim inward. Salt flats are
     deliberately left uncapped: real ones (Bonneville, Uyuni) are vast,
     so a large one here is accurate.

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
  the wind (GPU particles; intensity is `amount_ratio`, so it changes
  smoothly without restarting the emitter), and the sound of rain (a
  synthesized loop on its own bus). Under a crown or a camp shelter the
  rain around you thins to 30% and its sound is low-passed. The same
  wind vector sways all foliage.
- **Storms** (`StormFX`): above storm level 0.55, lightning every ~40 s
  at the threshold down to ~7 s at full strength: a flickering third
  directional light from a random bearing, flashing the sky, the cloud
  tops and the ambient; thunder follows ~3 s per km of a made-up distance
  (0.25-6 km, close strikes rarer): a crack and heavy rumble within
  1.2 km, a long low roll farther off; within 0.8 km the camera shakes.
  Heavy rain soaks the land (fills over ~2 minutes, drains over ~5):
  rivers and waves run faster, drops pock the water, and fresh water
  rises up to 0.3 m, visually only (swimming depth and the terrain don't
  change).

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

- **Day length.** One day is 120 real minutes (`PlanetConst.DAY_LENGTH_S`,
  12x Earth), in four phases at the equator: dawn 15 minutes, day 50,
  dusk 15, night 40 (dawn and dusk are the sun within 10° of the
  horizon). The planet turns uniformly for the weather; what the viewer
  sees is warped (`Astro.apparent_days`): the whole sky, sun, moon and
  stars together, turns slowly through twilight and quickly through the
  night, so each phase takes exactly its time (measured 40.0 / 15.0 /
  50.0 / 15.0 min). Toward the poles twilight stretches (21-minute dawns
  at 60°). The HUD clock is solar time. No axial tilt, so no seasons yet.
- **Sky events** (`SkyEvents`, drawn in the sky shader): common shooting
  stars (about two a minute on a dark night) and rare meteors, gated by
  the I Ching (`IChing`: an all-changing hexagram, 1 in 4,096, cast every
  5 s of darkness: about one in 8-9 nights), in six colors, with a flash
  over the land and a hiss and rumble. Both frequencies are exported.
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
- **Moon phases.** Moonlight follows illumination^3.3 (a half moon gives
  about a tenth of full), with a 5% floor and a night ambient floor so
  thin-moon nights stay playable. The disc: earthshine on a crescent's
  dark side, a slightly rough terminator, maria and limb darkening, a
  halo as bright as the lit area and leaning toward the lit limb. The
  disc adds its light to the sky behind it, so the dark side reads as sky
  at dusk. By day it's a pale ghost. The phase is lit from the sun's real
  direction projected on the sky, so a crescent tilts correctly for the
  viewer's latitude and hour.
- **Grade** (`PostGrade`), always on:
  - PS1-style 15-bit color through a 4×4 ordered dither;
  - vibrance for greens and blues, plus an emerald push (greens lose red
    and gain a little blue, so foliage reads deep rather than lime);
  - blacks crushed slightly;
  - sharpening day and night, plus a wide (3 px) luminance clarity boost
    that separates crowns, trunks and stones.

  At night it adds crushed contrast, a cobalt/violet push in the shadows
  and a vignette. Inside glowing sites it adds extra contrast.

## Look

`shaders/look.gdshaderinc`, `scripts/sky/look.gd`

- **Day:** a deep ultramarine zenith over a Frutiger Aero aqua horizon
  band, punchy greens, and saturated turquoise/ultramarine water. It uses
  a linear tonemap, because filmic washes colors toward realism.
- **Flat bands:**
  - the sky is a smooth gradient (deep ultramarine overhead, soft haze
    at the horizon, a warm glow on the sun's side); it used to be
    stepped in flat bands;
  - clouds are soft, shaded puffs;
  - distance fog is drawn by the world shaders, smooth, instead of the
    Environment's fog.

  Low ground below eye level fills with extra mist, strongest at night.
- **Textures.** A small procedural set, generated at startup by
  `Look.texture()` (~0.2 s): 128 px, nearest-filtered with mipmaps, and
  centered on 0.5 so shaders multiply by 2 and keep the vertex color's
  hue. Texels stay crisp but are dense with painted detail (thousands
  of grass blades, lit and shadowed pebbles of several sizes), for a
  texture-led look like the hand-painted references rather than big
  blocky texels.
  - grass, dirt, sand and stone on the ground, picked by the ground color
    (green → grass, bright warm → sand, low saturation → stone, otherwise
    dirt). Texels are about 1.4 cm for grass, 1.1 cm for dirt, 2 cm for
    sand and 2.6 cm for stone. Each is sampled twice (a turned, rescaled
    copy blended in by slow noise) so the tiling doesn't show. Smooth
    light and dark patches at two scales (a few meters, a few tens of
    meters) paint over them, with grass warmer in the light and cooler in
    the dark. Contrast eases off between 60 and 450 m so distant ground
    doesn't shimmer;
  - water: a net of caustic lines over a mottled base. The water shader
    drifts two copies across each other (with the current on rivers), for
    darker mottles and bright cyan flecks where the lines cross;
  - bark and leaves on plants, mapped in object space (triplanar) and
    scaled with the plant, so a big tree doesn't get bigger texels;
  - a leaf-cluster card texture with alpha: foliage crowns carry
    alpha-cutout cards (alpha scissor 0.5) that break up their outline;
  - weave (over-under strands) and fur (short strokes hanging down) for
    the player's robe, mantle and hair.
    The material ID (bark, leaves, card) rides in UV2.x;
  - stone on ruins (texels about 1.5 cm), turning to leaves where moss
    grows, with soft weathering patches;
  - the 32 px grain: bound twice, crisp for small-scale grit and smoothly
    filtered (`look_grain_soft`) for large-scale variation, so broad
    patches never come out as blocks.
- **Smooth shading, GameCube style** (the F-Zero GX / Melee / PSO look
  rather than flat low poly): terrain, plants, rocks, ruins and creatures
  have smoothed vertex normals; terrain normals come from a grid padded
  past each chunk edge so chunks agree along every edge.
- **Lighting** is a custom light() in every world shader (Look):
  - Lambert, plus **colored shadows**: where the sun or moon is blocked
    or faces away, a share of it comes back tinted teal by day and cobalt
    at night, multiplying each surface's own color, so shaded forest
    stays green. The day ambient is neutral (0.26); the tint carries the
    color of shade.
  - a soft glossy **sheen** (Blinn-Phong): strongest on creatures, lighter
    on worn stone, a waxy glint on leaves. Sky reflections are off
    everywhere except water.
  - rim light, leaf translucency and the ground's wet toon highlight at
    night, reimplemented because a custom light() replaces Godot's.
- **Clouds** (`CloudLayers`): three transparent shells round the planet,
  each with a tunable altitude and speed multiplier: low cumulus 500-2,000
  m (default 1,500; 4x), mid altocumulus 2,000-7,000 m (3,800; 3x), high
  cirrus 5,000-13,000 m (8,500; 2x, jet stream). Those are Earth's
  numbers; in the world they're times `height_scale` (the terrain's
  1/10), so 50-200, 200-700 and 500-1,300 m, and cloud sizes and drift
  scale with them, so the sky looks the same from the ground.
  Peaks break through the low layer, and from above it's a sea of cloud.
  Soft and painterly, not pixel-stepped. Edges feather out, more so far
  off where a sharp edge would shimmer, and a fine octave frays them into
  wisps. Thick cores shade toward the blue-grey underside color. One
  extra noise tap toward the sun (or the moon once the sun is down)
  brightens the sides facing it, and thin edges catch a silver lining.
  The pattern is three-octave value noise, each octave turned as well as
  scaled so the lattice doesn't show; each layer first checks whether its first
  octave can reach the cover threshold at all and discards the pixel if
  not, so clear sky costs one noise lookup. Standing above the
  low layer brings harsh alpine conditions (stronger wind, drier; HUD:
  "thin, cold air").
- **Atmospheric perspective:** Environment fog plus the shader fog,
  blue by day and cobalt at night; distance ridges fade smoothly.
  The haze thins with altitude (an exponential atmosphere, 150 m scale
  height: 1.5 km at Earth's scale), so valleys are hazy and summits
  clear.
- **Night** (the references' moonlit blue): a moon about 2.5× the old size
  with a halo that blooms, bright blue moonlight and a saturated blue
  ambient (never black), a luminous blue haze and thicker low mist, all
  water glowing cobalt, a moon-tinted rim on foliage and creatures, and
  strong emission on campfires and lanterns.
- **Depth** (added because flat lighting alone read too flat):
  - **Ambient occlusion**, in two layers:
    - SSAO on the Environment, including a little on direct light
      (Forward+ only);
    - hard-edged AO baked into vertex colors, which works in every
      renderer: terrain darkens in hollows and channels (up to 35%),
      ground under tree crowns (30%), the base of every plant, and the
      lowest courses of ruin walls.
  - **Hard shadows:** unfiltered shadow maps, a 4096 atlas, and 2 splits
    over a 160 m range, with enough normal bias (5) that lit ground
    stays free of acne.
  - **Rim light:** a light-driven rim (in light()) on plants, creatures
    and (lightly) ruins, plus a moon-tinted emissive rim after dark.
    Roughness 0.75 gives the rim its falloff: the rim exponent is
    (1 − roughness) × 16, and at 1.0 the "rim" would light the whole
    surface.
  - **Glow:** threshold 1.0, no global bloom, levels 1-4. Campfire
    flames, lanterns, glowing water and moss, and the sun push above the
    threshold and bloom; ordinary daylight surfaces don't.
  - **Grade:** contrast 1.28 by day and 1.32 at night, saturation 1.42
    by day (1.2 at night), exposure 0.9, for deep shadows and bright
    highlights. Sky and fog are smooth gradients (they were stepped in 5
    and 6 flat bands).
- **Bioluminescent night** (the third palette): see Landmarks. Moss
  glows in patches a few meters across.

## Landmarks

`scripts/landmarks/`

- **Ruins** (`Ruins`, `RuinBuilder`). At most one per 3.2 km cell. What
  stands there depends on the country at the cell (`Ruins.country()`);
  stone ruins go on the most prominent rise, the rest on the flattest
  ground:
  - castles on hills: a buried motte, an octagonal curtain wall with
    breaches and a gate gap, corner towers, and a tall keep with a fallen
    corner;
  - lone towers 14-22 m tall;
  - aqueducts striding level on tall piers, with some spans fallen;
  - **snow** (ice, tundra, or colder than -3 °C): one to three igloos of
    snow-block rings leaning in, with a crouch-height entrance tunnel,
    some caved in with fallen blocks, plus a windbreak and a drying rack
    hung with hides;
  - **jungle** (tropical and cloud forest): a treehouse village. Three or
    four giant buttressed trees (26-34 m, huge leaf crowns, hanging vines)
    carry plank decks 8-11 m up, with railings, knee braces and thatched
    huts, joined by sagging rope bridges (planks missing, one sometimes
    snapped). A walkable plank ramp spirals up the first tree from the
    ground;
  - **marsh** (wetlands, mangroves): a 40-65 m boardwalk on posts
    wandering across the marsh, planks missing and a stretch sunk under
    the water, dead snags beside it, and a stilt cabin at the end with a
    window, boards gone and part of the thatch caved in.

  Planet-wide with seed 42: 370 towers, 223 aqueducts, 88 castles, 223
  igloo sites, 96 treehouse villages, 21 boardwalks. Wood, snow, thatch,
  leaves and hide carry their own texture (a material id per vertex; the
  ruin shader picks bark, packed snow, straw, leaves or a soft grain).

  All of it is stacked stone blocks, so collapse is jagged column tops,
  V-shaped breaches, missing window blocks and rubble at the foot. The
  blocks are bevelled (each chamfer keeps its two faces' normals, so
  light rolls over the edge like worn stone), jittered at the corners and
  irregular in size; rubble mixes tumbled blocks with noise-displaced
  icosphere boulders. Moss greens the upward faces and low courses, and
  ivy hangs from broken tops, both scaled by the site's moisture: dry
  ruins are bare stone, wet ones mossy all over and curtained in ivy.
  Collision uses plain boxes, and so does the far level of detail past
  150 m (12 triangles a block in its face colors, no ivy). Sites are picked without the terrain's
  roll layer, so 2 m of noise never moves a ruin. Geometry is built on worker threads out to 2.6 km, beyond the
  terrain chunks, so silhouettes rise out of the fog bands. Deep footings
  keep them from floating over the coarser far terrain. Vegetation keeps
  their footprints clear.
- **Camps in ruins** (`RuinBuilder._camp`): about a third of ruins
  (their own seeded roll) hold one to three shelters, in a castle's
  courtyard, at a tower's foot or under an aqueduct's arches, and a cold
  fire ring: tepees (seven leaning poles, woven-vine and hide panels, a
  door gap) and lean-tos (forked uprights, a ridge pole, a vine-thatched
  roof to the ground), built from the same block primitives, so they get
  collision, the far LOD and the vines' night glow.
  `Landmarks.sheltered_at()` tells when you're inside one (igloos,
  huts and the cabin count too).
- **Living camps** (`Camps`): a fire burning and two to four folk seated
  round it on logs (stones among the dead), built within 220 m of the
  player. They look round at each other, gesture as they talk, turn to
  watch you come within 12 m (never further than over a shoulder), and
  one says a line when you step into the firelight. Found:
  - in about half the ruins (`Ruins.inhabited()`), at the spot the
    builder left: the survivors' fire ring (which then burns instead of
    lying cold), a castle courtyard, a tower's foot, under an arch, among
    the igloos, beneath the treehouses, where the boardwalk begins;
  - in the wild, on flat dry ground beside a river or lake (about one
    land cell in six, 1.8 km cells);
  - in rock shelters at the foot of cliffs (escarpments; see Walkable
    terrain), under a great slab jutting from the cliff above the fire,
    boulders either side.

  Who sits there: tribal folk in most land, fur-clad northerners in
  snow, hooded marsh folk, and at about 45% of inhabited stone ruins the
  restless dead, skeletons and a blue-robed hooded one keeping them
  company.
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

- **Chunks** (`TerrainChunk`). 384 per face edge, each about 260 m,
  smooth shaded, from one fine height grid of 64 × 64 quads (~4 m):
  - chunks in the ring nearest the player draw it all; farther chunks
    draw every other vertex (~8 m). The fine mesh's in-between edge
    vertices sit on the 8 m edge, so levels meet without cracks.
    Collision, height_at() and plant placement use the fine heights;
  - a gentle roll layer (~60 m swells, ±2 m) makes slopes undulate,
    fading out near sea level;
  - **escarpments**: in some inland regions the land steps up 14 m along
    long winding lines (the zero line of a slow noise field), over ~4 m:
    70-80° cliff faces with a plateau above;
  - **ravines**: in some hill country, narrow slot canyons 12 m deep with
    40-70° walls and a flat floor, meandering for kilometres (a narrow
    band round another noise field's zero line). Both are walking-scale
    detail, left out of the 1 km blueprint (a blueprint cell landing in a
    ravine would make a phantom lake);
  - where a river runs through ground more than 4 m above its bed, its
    banks steepen from a 12 m slope to near-vertical 3 m walls: a gorge;
  - heights come from `TerrainField` with the detail layer;
  - rivers are carved in with water ribbons (`RiverNetwork`). The water
    follows the ground (a profile sampled every 6 m, a running minimum of
    the terrain between the blueprint levels at each end), so it never
    floats. Steep reaches (steeper than ~1:12) gather their drop into
    **waterfalls** with pools between, and the channel cuts a gorge back
    into the slope: on seed 42 about 740 falls (160 of them 10 m or
    more, the tallest ~42 m) on ~680 km of large rivers, mostly in the
    hills and mountains. Each reach draws its own tallest fall (8-45 m), so
    some rivers descend in cascades and others in single plunges;
    moderate slopes are rapids (white water racing down the ribbon), as
    is the churn below each fall; tributaries meeting a lower river and
    rivers meeting the sea at a cliff end in falls. Each is a sheet arcing off the lip
    (`waterfall.gdshader`: streaks sliding down, foam toward the pool,
    frayed edges) with mist at the foot, glowing blue at night;
  - lake, sea and wetland water tables are added;
  - ground color blends nearby biomes, with sand at shores, rock on steep
    faces and snow wherever it's below freezing at that height.
- **Streaming** (`ChunkManager`):
  - the view ring (3 chunks) gets ground, water and trees (light meshes);
  - the detail ring (1 chunk) switches to the 4 m ground and full trees,
    and adds undergrowth;
  - geometry and plant placement are computed on WorkerThreadPool, down
    to each species' finished MultiMesh buffer (positions are relative
    to the chunk's anchor, so they don't depend on the floating origin);
    nodes are attached a few per frame;
  - the rings are recomputed only when the player crosses into another
    chunk, measured from that chunk's center;
  - collision shapes are built on the main thread: in Godot 4.3 a
    `set_faces` from a worker is only queued, and the physics server
    builds the BVH on the main thread at its next call anyway (unless
    physics runs on its own thread);
  - the loading screen blocks only for the detail ring.
- **Floating origin** (`World`). The planet center is stored in double
  precision and everything under `world_root` shifts when the player
  gets 1.5 km from the origin.
- **Far shell** (`FarShell`). A coarse sphere mesh for distant land and
  sea, sunk slightly and hidden inside the chunk radius, with slope
  normals.

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
  all files; currently 107 species (12 of them bamboo), in 34 of the 51
  files (hot desert and
  taiga researched; most others still placeholders).
- **Bigger than life.** Plants grow larger than their listed heights,
  for epic woods: emergent trees ×1.45 (and one in seven a giant, ×1.25
  more), canopy trees ×1.3, shrubs, ground cover and epiphytes ×1.2.
  Spacing widens with them (about with the square root), so crowns don't
  merge into a wall or add instances.
- **Plants read climate, not biome names.** At each candidate site on a
  jittered grid (spacing per tier), `VegetationPlacer` combines:
  - temperature at the exact height, adjusted for aspect (equator-facing
    slopes are warmer and drier);
  - moisture boosted near water, so rivers get gallery forests;
  - bell-shaped suitability bands;
  - soil from rock type;
  - special needs (standing water, river bank, salt, hot ground);
    plants other than water plants keep 0.3 m above standing water, and
    only salt-tolerant ones grow on beach sand;
  - per-species dominance over ~1.5 km (one valley spruce, the next
    fir);
  - patch clumping, and shade thinning the ground cover;
  - size and lean jitter.

  Epiphytes attach to placed trees; cypress knees ring cypresses standing
  in water. Mythical folk campsites and ruins are kept clear.
- **Rendering.** One MultiMesh per species. `PlantMeshes` builds 24
  placeholder shapes (25 with bamboo: clumps of arching, node-ringed culms,
  dwarf to 30 m giants); the foliage shader sways them with the live wind.
  Trees have crowns of 3-6 overlapping noise-displaced icospheres (faces
  buried in a neighboring lobe are dropped, so triangles go to the
  silhouette) with leaf cards on the outside, and 8-sided trunks that
  taper, bend and flare, with branches into the crown. Near the player a
  tree is 120-360 triangles, a shrub ~120; farther out trees swap to a
  light mesh (icosahedron lobes, 5-sided trunk, no cards or vines).
- **Moss and vines.** Each plant carries its site's moss (moisture) and
  vine (moisture and warmth) amounts in the MultiMesh custom data: moss
  creeps over the bark, and tree meshes' hanging vine strands (lianas;
  beard lichen on conifers) show only where it's wet enough, so
  rainforests are hung with them and dry woods have none. Instance
  colors are on too (white): without them the compatibility renderer
  garbles vertex colors when custom data is used.
- **Density.** Wet forest (mean moisture above ~0.6) packs canopy trees
  and ground cover up to 20% closer; shrubs keep their spacing, because
  denser shrubs walled in the view. Ground cover and epiphytes draw out
  to 300 m, which covers the whole detail ring.

## Creatures

`scripts/creatures/` and `data/creatures/creatures.json`

Creatures read the terrain and the placed vegetation: temperature at the
exact spot, moisture, ground cover, trees (canopy dwellers perch on
actual placed trees) and water depth.

How close you get depends on how loud you are: a creature bolts at its
`shy_m` times 0.35 (crouched and still) to 1.6 (sprinting), widened by
its suspicion. A startled ground animal then stands wary, watching you,
until the suspicion fades (about 6 s if you keep still nearby, slowly if
you stay away). Now and then a grazer walks to open water within 45 m,
drinks with its head down and wanders back. Wolf packs notice you by
noise too.

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

- **Rare creatures:** unicorns (night, moist temperate forest and
  meadow, a white horse with a raised neck, silver-lilac mane and a
  glowing spiral horn; they watch you and leave a trail of glowing
  hoofprints that fade over 20 s) and werewolves (cool forests; a
  hunched, dark-furred wolf-man with icy glowing eyes and long clawed
  arms; they walk only on the nights round the full moon, `active:
  full_moon`, and stalk like the skinwalker). Territories weight species
  by `rarity`: with seed 42, 101 unicorn and 400 werewolf territories
  against ~300-1,100 of each other mythical. Goblins also squat at some
  living camps (rock shelters in mild country, a fifth of inhabited
  stone ruins), lanterns and all.

- **Sculpted bodies** (`SculptedBodies`, `SculptRig`,
  `creature_sculpt.gdshader`): wolf, deer and goblin are one seamless,
  skinned mesh each instead of glued primitives.
  - The body is signed-distance shapes (tapered capsules, ellipsoids)
    blended with a smooth minimum, meshed with surface nets on a worker
    thread at startup and cached per species.
  - Normals come from the field. Creases get baked occlusion, and colors
    blend across the joins, with paint shapes for bellies, muzzles,
    socks, hooves and the goblin's loincloth.
  - Vertices are skinned to the bones of the nearby shapes, and SculptRig
    copies the joint pivots onto a Skeleton3D, so Creature's leg, arm and
    tail swings bend the body at the hip and shoulder.
  - Triplanar fur or skin grain, a glossier sheen and rim, and a coarse
    LOD past 45 m.
  - Triangles (near / far): wolf 2,604 / 416, deer 3,596 / 660, goblin
    4,388 / 820. Built in 0.6-1.1 s each on a worker; no measurable frame
    time change.
  - The rest of the bodies are still primitives, pending a verdict on
    these three.
- **Imported models** (`ModelLibrary`, `ModelAnimator`,
  `shaders/model.gdshader`; see `assets/models/README.md`): a `.glb` in
  assets/models/ named `player` or after a species or NPC replaces that
  body. It's scaled and placed, relit with the world's lighting on its own
  textures, and its clips play by state. Tested with a rigged stand-in
  exported to a real .glb: read raw at runtime, scaled to its sidecar
  height, relit, Idle and Walk switching as the player moved.

Sounds are synthesized placeholders (`SoundSynth`): chirp, call, croak,
howl, drone and whisper. Bodies are placeholders (`CreatureBodies`)
built from smooth-shaded spheres and capsules (12 sides × 6 rings for
bodies and heads, coarser for small parts), limbs that taper from hip to
foot, and flattened-cone ears, lit by `creature.gdshader` (colored
shadows, rim, sheen). Meshes are shared by every creature: 336-820
triangles each (deer ~900 and troll ~1,030 with antlers and mossy back).
Wolf dens are framed by boulders and a bevelled slab. (The capsules and
limbs were wound inside out, so their near side was culled and the far
side's inside showed through, lit backwards. `_revolve` now winds them
the way Godot draws a front face.)

## The player

`scripts/player/`

- **Movement** (`PlanetPlayer`): walk 6 km/h; sprint 5.5 m/s by
  double-tapping forward and holding it (or the pad's left stick held
  in); crouch (hold Shift or pad B) lowers the capsule and camera to
  1.05 m, slows to 0.8 m/s and stands back up only with headroom; holding
  jump jumps again on each landing. `noise_level` (0 crouched and still ..
  1 sprinting, eased) and `still_time` are what wildlife reads.
  `anim_state` (idle, walk, sprint, crouch, crouch_walk, air, swim,
  climb) is the hook for a future rigged model's animation tree, with the
  `crouching` / `sprinting` / `climbing` flags.
- **Body** (`PlayerBody`, `shaders/player.gdshader`): an elf wanderer,
  still unrigged placeholder geometry. He has long chestnut hair with two
  locks down the chest, pointed ears angled out and back, and a leather
  headband with a feather. His ankle-length robe is woven plant fiber,
  with pleats that deepen toward a leather hem and creases painted darker
  in the vertex colors. A fur mantle carries bone and wooden beads with a
  tooth pendant. A hide belt with a bone toggle holds a satchel. Every
  part is a smooth surface of revolution with its color, material and
  sway baked per vertex. The parts merge into four meshes, so four draw
  calls and about 2,070 triangles: the robe and gear, then Head at the
  neck and ArmL/ArmR at the shoulders (pivots for later animation). The
  shader lights him like the creatures and gives each material one of
  `Look`'s chunky 64 px textures, including the new `weave` and `fur`.
  The hem, sleeve ends and hair trail behind and flutter with
  `set_motion()` (the player's speed). Crouching still squashes the body
  vertically.
- **Trees** (`TerrainChunk` trunk colliders, `TreeContact`): canopy and
  emergent trees in the detail ring get a cylinder collider each (one
  static body per chunk, a shape owner per tree, sized from
  `PlantMeshes.tree_dims`, on physics layer 2 as well as 1), 60 a frame
  (~0.2 ms; all at once behind the loading screen). One sphere query a few times a second finds trunks near the
  player: under a crown is `under_canopy` (rain shelter); walking through
  a crown or bumping a trunk rustles it (a synthesized rustle and a crown
  shiver through the MultiMesh custom data's b channel). A physics query
  stands in for a trigger volume per tree, which would be thousands of
  nodes.
- **Climbing**: E facing a trunk (a ray on the tree layer) grabs it; W/S
  climb at 1.1 m/s up to 90% of the tree's height, A/D circle it; E or
  jump lets go (jump pushes off). E prefers a fallen log in reach.
- **Footsteps** (`Footsteps`): one per stride (0.5 / 0.78 / 1.25 m
  crouched / walking / sprinting), louder with speed, plus a landing.
  The ground: shallow water; else the collider underfoot (ruin stone,
  tree roots); else the terrain's vertex color classified like the
  terrain shader's texture pick (grass, stone, snow, sand, dirt). Seven
  synthesized sounds.

## The opening encampment

`scripts/landmarks/encampment.gd`, `campfire.gd`

`Encampment.candidates()` scores every blueprint cell with the old spawn
rule (low, mild, green land ~2 km from the coast) and keeps the best 12,
at least 20 km apart; each new game picks one at random
(`World.spawn_choice` pins one). `site_near()` finds a flat, dry spot
there (off water, rivers and wetlands, level across the camp), plants
keep a 12 m clearing, and the camp is a campfire (`Campfire`, shared with
the mythical folk camps), the player's hide mat facing it, and an elder
and a hunter (`CreatureBodies` tribal bodies) across the fire on log
seats, who breathe and turn toward the player when near. At the start
they speak once, as subtitles (`Hud.say`): "You're finally awake." /
"Be careful at night, don't let it get you...". The camera opens over
the player's shoulder so the fire is in view.

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
  - walking, and a 2 km jump with chunk streaming;
  - midnight with night creatures;
  - log interaction.

  No script errors, and no engine errors either: the headless (dummy)
  renderer used to log `Parameter "m" is null` about 3,500 times per run
  when meshes were freed with their nodes; `NodeRelease` detaches meshes
  before streamed-out nodes are freed.
- **Rendered.** Screenshots were rendered under xvfb, in Forward+ on a
  software Vulkan driver (lavapipe) and in the compatibility renderer,
  from fixed views: forest by day and night, a castle by day and at dusk,
  a hilltop overlook, a creature close-up, a waterfall, a wet ruin and a
  coast, plus a sheet of moon phases.
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
- **Rendering.** Forward+ is the target; screenshots were rendered in it
  on a software Vulkan driver (lavapipe), so real hardware should match
  but hasn't been checked, and lavapipe frame times say little about a
  GPU's. SSAO exists only in Forward+. The compatibility renderer gets
  everything else and only needs not to break.
- **Frame cost of the organic pass** (Forward+ on lavapipe, a CPU
  renderer, 640 × 360, same views before and after): the forest view
  4.88 → 4.95 s/frame (6.5 → 7.1 M triangles including shadow passes),
  the overlook unchanged (0.61 s), the castle view 1.36 → 2.32 s (2.2 →
  3.4 M triangles): bevelled blocks are 44 triangles instead of 12 and a
  castle has thousands. On a real GPU these triangle counts are small,
  but it hasn't been measured there.
- **Frame cost of the review pass** (same setup): a castle 400 m off
  1.63 → 1.43 s/frame with the plain-box LOD, the forest 7.2 → 6.9 s;
  the other views within run-to-run noise (lavapipe spends its time on
  geometry, so the cheaper cloud shader barely shows). On the CPU side
  (headless, main thread only, a 30 s run through forest) frames went
  from 5.2-5.7 to 4.1-4.2 ms on average and from 7.4-8.9 to 6.0-6.7 ms
  at the 95th percentile, mostly from building plant buffers on the
  workers; attaching a chunk's undergrowth dropped from ~90 to ~20 ms.
- **Player model (rig deferred).** The elf (`PlayerBody`) and the camp's
  NPCs are unrigged placeholder shapes. A rigged humanoid with an animation tree (idle,
  walk, sprint, crouch, climb) needs an asset pipeline first (which tool
  exports to Godot, who makes the model). The hooks are in place:
  `PlanetPlayer.anim_state` plus the `crouching`, `sprinting` and
  `climbing` flags; footsteps then should follow the animation's foot
  contacts instead of the stride timer.
- **Storm fakes.** Rain doesn't collide with crowns; under cover the
  falling rain thins instead. Thunder's distance is made up per strike
  (there is no bolt), and flooding is visual only.
- **NPCs** speak their opening lines once and otherwise only watch you;
  there's no dialogue or behavior beyond that yet.
- **Frame cost of the movement/storm batch** (headless, main thread, the
  same 30 s run at the same speed): 4.1-4.2 → 4.5 ms on average, 6.5 →
  6.7-6.9 ms at the 95th percentile, nearly all from the trunk colliders
  (building them as chunks enter the detail ring, and the player
  colliding with them); the contact scan, footsteps and shelter checks
  are each under 0.02 ms.
- **Waterfalls** have no sound yet, and the fine terrain grid (4 m) can't
  make a truly vertical cliff, so the gorge wall under a tall fall is a
  steep ramp.
- **Foliage wind.** One wind vector (the local weather at the player)
  sways every plant in view. That's right at walking scale, but plants a
  few kilometers off don't feel their own local wind.
- **Weather grid.** The live grid is coarse (~10 km cells); breezes,
  gusts and showers are local detail added at the player, not simulated
  across the planet.

