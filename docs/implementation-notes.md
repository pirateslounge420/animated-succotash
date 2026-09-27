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
    SkyPaint           painted cloud and star panoramas, baked at startup
  WeatherFX            rain/snow particles, wind on foliage
  RippleSim            ripples on the water near the camera (Ripples)
  PlanetPlayer         third-person explorer with planet gravity
  CreatureSpawner      wildlife, wolf packs, mythical creatures, logs
  Landmarks            ruins and glowing places (bioluminescent night)
  Hud, MapOverlay, PostGrade
Audio3D                every world sound's falloff (data/audio.json)
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

  With seed 42 it takes about 6 s (5.9 s measured headless); the dev
  postage stamp (below) about 3 s.
- **Sampling** (`PlanetData.sample`, `weights_at`). Bilinear between cell
  centers, switching to a neighbor-aware kernel within half a cell of a
  cube-face edge, so climate and ground colors run on seamlessly across
  face edges.
- **Distances** (`CubeSphere.angle_between`). Use the chord length, not
  `acos(dot)`: with 32-bit vectors, acos can't resolve anything under
  ~20 m on this planet.

### Dev postage stamp

Spec A4: a fixed-seed mini-planet with one of every major biome band,
used while developing (the full planet is for milestone checks). On
when `data/dev.json` has `"dev_mode": true` and `"postage_stamp": true`
(`World.use_postage_stamp`); its `"stamp"` block sizes it
(`circumference_km`, default 40; `grid_res`, blueprint cells per face
edge, default 48). Missing or false: the full planet, unchanged (the
blueprint, weather and chunk output hash the same as before the stamp
existed).

- **A scale model, not a different planet.** The stamp runs the same
  seed through the same passes. Its *geography* is the full planet's,
  shrunk sideways by `PlanetConst.GEO_SCALE` (0.1 at 40 km) with heights
  unchanged: continents, mountain belts, hills, volcanoes, rock regions
  and the escarpment/ravine regions sample their noise at
  `PlanetConst.GEO_RADIUS_M` (the full radius), and the passes measure
  slopes, upwind ridges and coast/water distances in geographic meters
  (`CubeSphere.geo_distance_m`, `PlanetData.cell_km`). The weather grid
  too, so winds, storms and the climate averages behave exactly as at
  full size. Latitude bands exist on any sphere, so every band is there
  by construction; the land/sea layout decides how much of each.
- **Walking scale stays real.** The ground's grain (detail, roll, shore
  wiggle, the escarpment and ravine lines), chunks (still ~260 m:
  `TerrainChunk.CHUNKS_PER_FACE` follows the planet size, 38 per face on
  the stamp), plants, creatures, the player, ruins (one per 3.2 km grid
  cell), mythical territories (1.6 km), river widths and all scene
  placement use the real radius, `PlanetConst.RADIUS_M`. Consumers that
  read a blueprint distance at walking scale convert it (plants' and
  animals' distance to water) or scale with the cell (glow ponds, the
  camp-beside-water test).
- **Coarser blueprint.** 48 cells per face edge (~208 m real, ~2 km
  geographic). Rules counted in default ~1 km cells scale with the cell
  (`PlanetData.cell_scale`, `cells_for`): the minimum sea size, biome
  patch caps, the relief that makes canyons and badlands, the share of
  land carrying rivers, and river discharge (so widths match).
- **Consequences on screen.** The stamp is 40 km around (radius 6.4 km):
  10 km from equator to pole, about 1.7 hours on foot, so bands are a
  short walk apart. Slopes are ten times steeper than at full size
  (mountains keep their height over a tenth of the width) and the
  horizon is closer (~160 m for a standing player instead of ~500 m).
  The first camp still comes from the same candidate scoring. The
  planet map (M) draws relief against the geography's full-size radius,
  so the stamp's globe reads like the full planet's rather than a lumpy
  ball (on the full planet nothing changes).
- **Checked by** `tools/stamp_check.gd`: generation time, cells per band
  (the bands and the minimum are in `data/dev.json`, `"stamp"."bands"`),
  what the walkable world holds, and, with a display, the planet map in
  four modes and a ground shot at the first camp. With seed 42: 3.1 s
  against 5.9 s for the full planet, all 14 bands present, 48 of the 50
  surface templates.

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
  smoothly without restarting the emitter), and the sound of rain: four
  3D players 5 m out north, east, south and west of the camera, moving
  with it, each a different synthesized loop at a slightly different
  speed (so the four don't fuse into one sound in the middle), on their
  own bus. Under a crown or a camp shelter the rain around you thins to
  30% and its sound is low-passed (900 Hz). The same wind vector sways
  all foliage.
- **Storms** (`StormFX`): above storm level 0.55, lightning every ~40 s
  at the threshold down to ~7 s at full strength: a flickering third
  directional light from a random bearing, flashing the sky, the cloud
  tops and the ambient; thunder follows ~3 s per km of a made-up distance
  (0.25-6 km, close strikes rarer): a crack and heavy rumble within
  1.2 km, a long low roll farther off; within 0.8 km the camera shakes.
  The thunder is a 3D sound at the strike (the flash's bearing, that
  distance off, 300 m up), so it comes from where the lightning was, and
  the distance alone makes it quieter and duller (see Sound). Two
  players, so a new peal doesn't cut off the last one's roll.
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

- **Day length.** One day is 120 real minutes (12x Earth), in four
  phases at the equator: day 45 minutes, dusk 20, night 35, dawn 20
  (dawn and dusk are the sun within 10° of the horizon). All of it is
  data: `data/sky/day_cycle.json`, read by `DayCycle`. The planet turns
  uniformly for the weather; what the viewer sees is warped
  (`Astro.apparent_days`, `DayCycle.warp`): the whole sky, sun, moon and
  stars together, turns slowly through twilight (0.19x uniform speed),
  faster by day (1.24x) and fastest at night (1.62x). The speed is
  constant within a phase and eases from one to the next over 12 minutes
  centered on each boundary (a smoothstep), so it never jumps; the four
  speeds are solved so each phase still takes exactly its time (measured
  45.0 / 20.0 / 35.0 / 20.0 min). `DayCycle.unwarp` is the exact inverse
  (bisection), so the game still opens at 17:00 solar time at the camp.
  Toward the poles twilight stretches (24-minute dawns at 50°). The HUD
  clock is solar time. No axial tilt, so no seasons yet.
- **Dev settings** (`data/dev.json`, read by `World`, spec A4): with
  `dev_mode` true, a 20-minute day (every phase scales with it), seed 42
  and the first camp fixed (`spawn_choice` 0). A missing file means the
  game's own settings. F3 shows a debug overlay (`Hud.debug_text`):
  clock, solar time, phase and minutes into it, sky speed, sun and moon
  elevation, moon age, phase and mansion, eased cloud cover. F4, in dev
  mode only, shows the collision view (see Landmarks).
- **No snapping.** Besides the smooth warp: the local weather is
  resampled four times a second and steps every in-game quarter hour,
  so `main.gd` eases a copy of it (`WeatherSim.ease_toward`, time
  constant 5 s) and everything on screen reads the eased copy (sun
  energy, stars, sun disc, clouds, rain); the sun and moon lights fade
  to exactly zero before they're switched off; the clouds' light
  direction turns from the moon to the sun (through the zenith, at an
  even pace) while the sun climbs from -10° to +4° instead of switching
  at -4°. `tools/p0_timelapse.gd` steps the dev clock at 30 fps through
  the sky and fails on any per-frame jump above its limits.
- **Sky events** (`SkyEvents`, drawn in the sky shader): common shooting
  stars (about two a minute on a dark night) and rare meteors, gated by
  the I Ching (`IChing`: an all-changing hexagram, 1 in 4,096, cast every
  5 s of darkness: about one in 8-9 nights), in six colors, with a flash
  over the land and a hiss and rumble. The meteor's sound is a 3D player
  kept 400 m out toward its glowing head as it crosses the sky (then
  where it burned out), so the hiss sweeps across with it. Both
  frequencies are exported.
- **Earth-like moon** (`Astro.moon_dir`, `MoonMode.ORBITAL`, the default):
  - it orbits once per 29.5-day phase cycle (`moon_cycle_days`) on an
    orbit tilted 5.1°;
  - elongation from the sun sets the phase, so a full moon rises at
    sunset, a new moon travels with the sun, and quarter moons are up
    half the day;
  - it rises about 49 minutes of game time later each day.

  `MoonMode.LOCKED_OPPOSITE` keeps the original always-opposite
  behavior as an option.
- **28 lunar mansions** (`LunarMansions`). The mansion follows the moon
  around its orbit: the stars turn with the sun here, so the moon's place
  among them is its elongation, and it walks through all 28 once per
  29.5-day cycle (a new mansion every 1.05 days, Jiao at new moon;
  `Astro.mansion_index`). Its star glyph is drawn next to the moon in the
  sky shader, tinted by its guardian beast's color; when the moon enters
  the next mansion the glyph fades out, swaps unseen and fades back in
  (2.5 s each way), or just swaps if it isn't showing.
- **Lighting** (`SkySystem`):
  - two DirectionalLight3Ds (sun and moon), with intensity and color set
    by elevation; the moon's also scales with phase;
  - a continuous palette runs from a pure saturated blue day, through a
    dusk with a warm band low under an ultramarine sky, to a bright
    ultramarine night (the R1a hex values, `SkySystem.DAY_ZENITH` etc.);
    `_scene_color()` undoes the exposure and adjustment so they read true
    on screen before the post grade;
  - the sky shader draws the moon disc with a phase terminator, the
    baked starfield and the painted clouds (see Look);
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
- **Grade** (`PostGrade`, `shaders/post_grade.gdshader`), always on:
  - slight color bleed (color, not brightness, averaged sideways, like
    composite video);
  - vibrance for greens and blues, plus an emerald push (greens lose red
    and gain a little blue, so foliage reads deep rather than lime);
  - an ultramarine haze over the darks (spec R1a: nothing pure black,
    blue rather than grey), thicker and bluer at night;
  - faint moving film grain;
  - a light ordered dither (spec R1, optional): each channel rounded to 5
    bits through a 4×4 Bayer pattern and mixed in at a quarter strength
    (`dither` uniform, `PostGrade.set_dither(0)` turns it off);
  - no sharpening, clarity or bloom (the era's image is soft).

  At night it cools the shadows toward cobalt (warm, firelit pixels are
  left warm, so fire stays the one warm accent) and adds a vignette,
  which the haze then lifts to deep blue. Inside glowing sites it adds
  extra contrast.

## Look

`shaders/look.gdshaderinc`, `scripts/sky/look.gd`

- **Day:** pure saturated blue sky (#1436FF overhead to #4C7CFF at the
  horizon), punchy greens, and bright saturated blue water. It
  uses a linear tonemap, because filmic washes colors toward realism.
- **Painted skybox** (the 2001-2004 console look), `shaders/sky.gdshader`,
  `SkyPaint`:
  - a smooth gradient (above; night #0A14A0 overhead to #1B2ED8, never
    black or grey; at dusk and dawn the gradient hugs the horizon, so the
    warm band stays low), soft haze at the horizon in the fog's color and
    a warm glow on the sun's side;
  - two panoramas painted once at startup on the GPU (a SubViewport drawn
    once with `sky_paint.gdshader`, ~12 MB), so the per-frame sky is two
    texture reads:
    - clouds (2048 x 512, azimuth x elevation in the viewer's sky):
      brushy banks piled over the horizon and long wispy streaks higher
      up. Stored as densities and shading, so the shader thresholds them
      by the eased weather (a few banks when fair, overcast in a storm)
      and colors them for the hour (white by day, rose at dusk, moonlit
      ultramarine at night, glowing near the sun or moon). Both fade out
      above ~60 degrees, where the panorama pinches to a point (it used
      to paint a smeared starburst at the zenith). They drift round the
      viewer (a turn every ~50 minutes in a light wind);
    - stars (2048 x 1024 equirectangular, celestial frame, turned with
      the sun): three sizes, blue-white to orange, the brightest with a
      small glint, and a milky band with dark rifts. Over it the shader
      adds a dense per-pixel speckle of faint stars (~0.3 degree grid,
      denser in the band). No twinkle;
  - the moon is a big disc (~11 degrees) with phases.
- **Flat bands:**
  - the sky is smooth (it used to be stepped in flat bands);
  - weather clouds are soft, shaded puffs;
  - distance fog is drawn by the world shaders, smooth, instead of the
    Environment's fog.

  Low ground below eye level fills with extra mist, strongest at night.
- **Textures.** A small procedural set (`LookTextures`), painted at
  startup on a worker thread while the planet generates (~0.4 s):
  256 px, linear-filtered with mipmaps (anisotropic on the ground), and
  centered on 0.5 so shaders multiply by 2 and
  keep the vertex color's hue. They're dense with painted detail: grass is 2,200
  tapered, bowed blades in light and dark, leaves are pointed shaded
  leaves with a midrib, dirt is smooth mottling with soft pebbles and
  crumbs, sand has wind ripples, stone has cells and cracks, bark has
  fibers and grooves.
  - grass, dirt, sand and stone on the ground, picked by the ground color
    (green → grass, bright warm → sand, low saturation → stone, otherwise
    dirt). Texels are about 0.7 cm for grass, 0.55 cm for dirt, 1 cm for
    sand and 1.3 cm for stone. Each is sampled twice (a turned, rescaled
    copy blended in by slow noise) so the tiling doesn't show. Smooth
    light and dark patches at two scales (a few meters, a few tens of
    meters) paint over them, with grass warmer in the light and cooler in
    the dark. Contrast eases off between 60 and 450 m so distant ground
    doesn't shimmer;
  - water (`water.gdshader`): flat, painted early-2000s console water
    with no reflections at all (no sky or sun mirrored, no specular,
    fresnel tint or normal map), under the same vertex Lambert as
    everything else. The texture holds a soft mottled body (red) and soft
    highlight blobs (green), no lines (the old caustic net read as a
    white net over the water). Two copies (6 m and 7.5 m repeats, one
    turned) scroll across each other: still water wanders slowly, rivers
    run downstream at 0.5 and 0.75 m/s, and highlights show where the
    two layers' blobs overlap. Day: #3B78FF, sea and fresh water alike,
    landing near #1667FF on screen. Night: near self-lit, #1B3CFF with
    #7FB0FF highlights (R1a; `night_glow` 0.6 lands there through the
    grade). Slightly see-through looking down. Rapids streak white foam
    downstream; rain pocks it. UVs are meters (TerrainChunk: across the
    cube face for standing water, across and downstream for rivers)
    wrapped by 300 m, a whole number of both layers' repeats, so no
    chunk or segment seam shows; the far sea (`far_sea.gdshader`) wears
    the same flat day blue and night glow. Near the camera anything
    touching the water rings it, painted as soft light and dark bands
    (Water ripples);
  - bark and leaves on plants, mapped in object space (triplanar) and
    scaled with the plant, so a big tree doesn't get bigger texels;
  - a leaf-cluster card texture with alpha: foliage crowns carry
    alpha-cutout cards (alpha scissor 0.5) that break up their outline;
  - weave (over-under strands) and fur (short strokes hanging down) for
    the player's robe, mantle and hair.
    The material ID (bark, leaves, card) rides in UV2.x;
  - stone on ruins, turning to leaves where moss grows, with soft
    weathering patches;
  - the 64 px grain (soft noise with a little cellular clumping), for
    large-scale light and dark: broad patches never come out as blocks.
- **Smooth shading and round models, GameCube style** (the F-Zero GX /
  Melee / Beyond Good & Evil look rather than faceted low poly):
  terrain, plants, rocks, ruins and creatures have smoothed vertex
  normals; terrain normals come from a grid padded past each chunk edge
  so chunks agree along every edge. Silhouettes are round where they
  show: trees near the player get 180-triangle crown lobes and 12-sided
  trunks (Vegetation), boulders are 320-triangle spheres, creature parts
  28-sided spheres and capsules, and camp folk, wolves, deer and goblins
  are one-piece sculpted bodies (Creatures).
- **Lighting: vertex-lit, 2001-2004 console style** (Phantasy Star
  Online, Melee, F-Zero GX), not PBR and not soft cartoon shading:
  - every lit world shader (terrain, far terrain, plants, ruins,
    creatures, sculpted bodies, the player, imported models, waterfalls)
    uses Godot's built-in Lambert with `render_mode vertex_lighting` and
    `specular_disabled`. No custom light(): no rim, sheen, sky gloss,
    colored-shadow fill or wet highlight. Plants keep Godot's leaf
    translucency (BACKLIGHT).
  - Godot 4.3 accepts `vertex_lighting` but still lights per pixel in
    Forward+ and Compatibility alike (checked: a quad under a close omni
    light shows a per-pixel hotspot either way, and a custom light() still
    runs per pixel); from 4.4 the same render mode is true per-vertex
    (Gouraud) shading, with no change here. With smooth normals, no
    specular and no shadow maps the two look nearly the same.
  - a strong flat **ambient** (`SkySystem.AMBIENT_DAY` 0.5, a soft cool
    white; `AMBIENT_NIGHT` 0.42 ultramarine #3A4CFF, lifted by the moon
    toward #6480FF and 0.6), so the side away from the sun is plainly
    readable, never black; the sun (0.85) is the one clear light
    direction, the moon (periwinkle #8FA8FF, up to 1.25, greyer when
    low) at night.
  - **no shadow maps**: sun and moon cast none, so trees and ruins cast
    no shadows. Characters get **blob shadows** (`BlobShadow`,
    `shaders/blob_shadow.gdshader`): a soft dark disc (alpha 0.8 in
    linear light, about half as bright on screen; solid to 55% of its
    radius, then fading out) on the ground under the player, every
    creature and the camp folk, sized to the body (0.55 m for the player,
    0.3 × height for people; `footprint()` stretches it along animals),
    in the character's upright frame at the ground under its feet. It's
    drawn a little toward the camera so slopes don't cut it, shrinks as
    the character jumps, hops or climbs, is gone afloat or above 3 m, and
    fades out 35-60 m away and in haze. One mesh and one material serve
    them all.
- **Clouds** (`CloudLayers`): the weather's clouds (fair-weather
  cloudiness is painted into the sky, above; on a fair day the shells
  are nearly empty and they fill in as it clouds over), three
  transparent shells round the planet,
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
- **Atmospheric perspective:** Environment fog plus the shader fog. By
  day distance fades into the sky's own horizon blue (deeper at dusk, so
  the warm band stays in the sky); at night into the R1a night fog
  #1E30C0 (`SkySystem.NIGHT_FOG`, density +0.0017/m: ~40% at 200 m), so
  distance dissolves to blue. Distance ridges fade smoothly.
  The haze thins with altitude (an exponential atmosphere, 150 m scale
  height: 1.5 km at Earth's scale), so valleys are hazy and summits
  clear.
- **Night** (R1: saturated dark fantasy): a bright ultramarine sky
  with dense speckled stars and a big moon with a halo, periwinkle
  moonlight and a strong ultramarine fill (never black), an ultramarine
  haze and thicker low mist, all water glowing cobalt, and strong
  emission on campfires and lanterns. The one warm accent is fire:
  #FF7A2A light and a pool of firelight on the ground round every
  campfire, which the night grade leaves warm.
- **Depth**, the era's way: nothing screen-space.
  - **Baked ambient occlusion** in vertex colors, which works in every
    renderer: terrain darkens in hollows and channels (up to 35%),
    ground under tree crowns (12%, plus dappled shade in the terrain
    shader: patches of shadow broken by sun flecks, as deep as the crowns
    overhead are leafy), the base of every plant, and the
    lowest courses of ruin walls. No SSAO, SSIL, SSR or SDFGI.
  - **Blob shadows** under characters (above); no shadow maps.
  - **No rim light and no glow:** the Environment's glow is off, so
    campfires, lanterns and glowing water and moss are bright emission
    without halos.
  - **Grade:** contrast 1.28 by day and 1.32 at night, saturation 1.42
    by day (1.2 at night; `SkySystem.grade_saturation`, `grade_contrast`),
    exposure 0.9, for deep shadows and bright
    highlights. Sky and fog are smooth gradients (they were stepped in 5
    and 6 flat bands).
- **Palette (spec R1a):** `shaders/palette.gdshaderinc`, included by the
  terrain, far terrain, plant and ruin shaders, pulls each surface's own
  color toward its R1a target rather than replacing it (hue and
  saturation most of the way, half of its brightness variety kept, so
  biomes and species still differ):
  - grass (green ground, 75%) toward #3FA83A on screen by day, green
    leaves (45%) the same way, bark (70%) and dirt (55%) toward the warm
    brown #6B4A2E-#A07A4A, rock faces (85%) toward blue-grey #6F7A8A,
    snow toward #C8D8F0, moss toward #3F7A3A. Flowers and autumn leaves
    aren't green, so they're left alone;
  - as night falls (`look_night`) a second pull lands grass on teal-blue
    (#1E4A6A), stone on slate (#3E4C8C) and bark on deep blue. These
    night targets are albedos tuned by sampling renders: the moon and the
    night ambient are already deep blue, so they hold green and red back
    rather than adding blue;
  - the classification (grass/dirt/sand/stone/snow) still reads the raw
    vertex color, so textures and footsteps don't change; biome and
    species tables keep their own colors;
  - ruin stone (`RuinBuilder.STONES`) is blue-grey; tomb lamps and the
    goblin's and witch's lanterns are lantern gold #FFC040; campfires are
    R1a fire (Landmarks: the opening encampment). There are no lit
    windows yet (#FF3A2A is unused).
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
  - **pyramids**, in any country, on its own roll (`Ruins.PYRAMID_CHANCE`:
    35% of desert ruins, 20% jungle, 10% stone country and marsh, 8% snow;
    a separate random stream, so every other ruin stays where it was) and
    on level ground. `Ruins._pyramid_site()` picks the measurements and the
    clearing; `RuinBuilder._pyramid()` builds to them:
    - **desert**: a 56-84 m sandstone pyramid, 0.62 as tall as it is wide,
      cased smooth but weathered into rough courses that step back at
      each ledge, the capstone gone, sand drifted round the foot, a gabled
      entrance up the -z face, fallen casing stones and a small queen's
      pyramid beside it (about 2.7k triangles: flat faces, not blocks);
    - **jungle** (pale limestone): a steep temple of 7-9 tiers with a
      stair up one face to a shrine with a door and a roof comb, mossy
      and hung with ivy;
    - **marsh**: the same, half sunk (the lowest tier and a half buried),
      its shrine fallen in;
    - **stone** and **snow**: a broad grey ziggurat of 4-6 tiers with a
      stair, a broken obelisk, altar and pillar stumps on top; in snow,
      snow lies on every ledge.

    Stepped tiers are rings of big blocks round a darker core set back
    behind them, so a block fallen out shows a recess, not a hole. The
    stair climbs at 44 degrees (the player walks up to 50), from where it
    meets the ground past the foot; its steps have no collision and a
    smooth ramp stands in for them. The camp (if the ruin is inhabited)
    sits at the foot on the +x side: tribal folk at temples, northerners
    in snow, marsh folk in the marsh, the dead or tribal folk in the
    desert. Glowing-site labels use `Ruins.site_name()` ("Desert pyramid",
    "Temple pyramid", "Step pyramid", "Frozen pyramid", "Sunken pyramid").

    The desert pyramid can be explored: a stair climbs the -z face at 38
    degrees to a portal standing proud of the casing (the courses behind
    it have a gap), and a corridor 2 m wide runs straight in to a burial
    chamber at the heart, 5 by 7 m, with a granite sarcophagus, grave
    goods and a lamp-gold glow (a dim teal one along the corridor).
  - **the dead**, on another roll of its own when a ruin isn't a pyramid
    (`Ruins.TOMB_CHANCE`, [graveyard, barrow]: 12%/12% in stone country,
    8%/15% desert, 6%/10% snow, 10%/6% marsh, none in the jungle), on
    level ground:
    - **graveyards** ("Old graveyard", "Snowbound graveyard", "Sunken
      graveyard"): a low stone wall round a 24-31 m square, the gate on -z
      between capped posts, a breach or two; rows of graves either side
      of a path up the middle, each a headstone (slab, shouldered slab,
      cross or little obelisk, leaning, more so in the marsh, or fallen
      flat) over a low mound (snowed over in the cold); one to three dead
      trees; and at the back a **mausoleum** on a plinth, steps up to its
      door, a gabled roof over pediments, a sarcophagus and grave goods
      inside and a faint glow;
    - **barrows** ("Barrow tomb"): a long earth mound (turf, or snow),
      highest at the front where a dry-stone facade stands across its
      open end with a portal of two uprights and a lintel, standing stones
      before it. Inside, a passage of upright slabs under capstones runs
      in past two pairs of side cells to an end chamber: a sarcophagus,
      urns, bones, a skull, gold, a lamp-gold glow at the end and a dim
      one along the way;
    - in the desert, **mastabas** ("Desert tomb"): a flat-roofed sandstone
      house of the dead on a drift of sand, steps up to its door, one roof
      slab often fallen in so a shaft of sun reaches a false-door stele,
      the sarcophagus and grave goods.

    Tomb lights are `OmniLight3D`s (`RuinBuilder._lights`, made in
    `make_node()`), fading out past 50-70 m. Chambers and passages are
    shelters (no rain inside). Graveyards are kept by the dead; barrows
    by the dead or goblins; desert tombs by the dead or tribal folk.

    Getting in is walkable throughout: stairs and door steps have no
    collision of their own; a smooth ramp stands in for them and meets
    the floor above the sill, so there's no lip to catch on. (Tested by
    walking the player in from outside: the barrow's end chamber, the
    mausoleum, the mastaba, the pyramid's chamber and the stepped
    pyramids' tops.)

  Planet-wide with seed 42: 215 towers, 128 aqueducts, 65 castles, 174
  igloo sites, 72 treehouse villages, 12 boardwalks, 187 pyramids (102
  desert, 42 step, 24 temple, 15 frozen, 4 sunken), 75 graveyards (59
  old, 13 snowbound, 3 sunken), 62 barrows and 25 desert tombs.

  Collision for drawn surfaces (mounds, the cased pyramid, the barrow)
  goes in with its winding reversed (`_collide_since()`): Godot takes
  clockwise triangles as front-facing and concave shapes collide on one
  side only, so copied as drawn they let you walk in from outside and
  then held you under them (castle mottes were affected too). Wood, snow, thatch,
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
  Blocks collide as plain boxes (boulders as hulls; see Hitboxes), and
  the far level of detail past 150 m is plain boxes too (12 triangles a
  block in its face colors, no ivy). Sites are picked without the terrain's
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
  the far LOD and the vines' night glow. Their collision follows the
  cover, with the door left open (see Hitboxes below).
  `Landmarks.sheltered_at()` tells when you're inside one (igloos,
  huts and the cabin count too).
- **Living camps** (`Camps`): a fire burning and two to four folk seated
  round it on logs (stones among the dead), built within 220 m of the
  player. Tribal and northern folk keep their weapons at hand: a spear
  leaning on the log or a bow laid by it. One or two guards stand at the
  edge of the firelight with a spear or a bow (the `archer` tribal
  shape), facing out and turning to watch you come. They look round at each other, gesture as they talk, turn to
  watch you come within 12 m (never further than over a shoulder), and
  one says a line when you step into the firelight. Whenever a line
  comes up (that one, or an arrow in one of them) they murmur as the
  subtitle shows: several soft synthesized voices overlapping, no words
  (`SoundSynth` "murmur"), on a 3D player among them heard to about
  25 m. Found:
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
- **Hitboxes** (spec D5: a proper hitbox on everything, no ghost-through,
  no invisible walls). Ruins and props collide as simple shapes fitted
  to what's drawn, all on physics layer 1 with the ground, so the
  player walks into them, the camera's spring arm stops at them and
  arrows stick in them. Props use `PropCollision`; ruins keep their
  triangles and add convex hulls (`RuinBuilder._ch`), built after the
  triangles, 32 a frame, once the player is within 400 m.
  - Blocks, walls and the hidden ramps under stairs are plain boxes;
    mounds, the cased pyramid and the barrow are their own one-sided
    triangles (as before).
  - Boulders (ruin rubble, cold fire rings, urns) are the convex hull of
    the drawn stone taken at the 42 corners of a once-divided icosphere
    (`boulder_hull()`), within a few cm of it. Stones over 0.9 m in
    radius (den stones, a rock shelter's slab and its boulders,
    `rock_hull()`) take all 162 drawn corners, since there the drawn
    bulges would stand up to 0.4 m proud of the coarse hull. The old
    boxes (0.8 of the radii) stuck out at the corners and left the
    sides sunk in: by about 0.25 m on a 1.3 m stone and about 1 m on a
    rock shelter's slab.
  - Tepees: the poles, except the two framing the door, and a 6 cm shell
    behind each panel of vines or hide. The two panels beside the door are trimmed
    back to 45 cm from the door's middle line, where the drawn doorway
    narrows toward the top, so you walk in at the door and stand
    inside. Before, a solid box filled the tepee. Lean-tos: a slab
    under the roof, and the poles.
  - Giant jungle trees: a hull round each pair of the trunk's 12-sided
    rings, so the collision is the drawn trunk and its flare exactly,
    plus the buttresses and limbs. The leaf crowns don't collide (they
    were solid boxes); decks, ramps and bridges do. Deck and bridge
    handrails get a thin box along each rope (`_rail()`); other ropes
    and hanging vines don't collide.
  - Grave mounds: a low hull with sides at 40 degrees, so you walk over
    a mound instead of through it (a straight 19 cm step would stop
    you). Grave goods collide only when over about 30 cm (urns, long
    bones); skulls and gold don't.
  - Camp props: capsules along campfire stones and logs (a low ring you
    bump into), seat logs and seat stones, leaning spears (thin, so
    arrows stick) and fallen logs (on the part that rolls over). A wolf
    den's boulders are hulls and its lintel a box.
- **Collision view** (F4, dev mode only; `CollisionView`): wireframes
  of every collision shape within 40 m of the player, in Godot's own
  line meshes for each shape, colored by physics layer: the world
  (layer 1) cyan, trees (layers 1 and 2) green, anything on another
  layer (creature hitboxes) magenta, the player's capsule yellow, the
  terrain faint. Lines behind something show dimmed. Off, it costs
  nothing: it's made on the first press and doesn't process until
  turned on. On, it asks the physics space what's near four times a
  second and moves the lines with their bodies every frame.
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
    (`waterfall.gdshader`: near-white at the crest, the water texture's
    streaks sliding down, foam toward the pool, frayed edges) with mist
    at the foot, glowing blue with pale streaks at night;
  - river ribbons (the flowing surface, 0.15 m over the still pool that
    fills the carved channel, its last 2.5 m each side fading into it)
    are drawn seamlessly: each 6 m stretch belongs to the one chunk its
    middle is in (no overlapping see-through layers at chunk edges),
    segment ends share one mitred edge at every joint, and the downstream
    coordinate is continuous along the whole river
    (`RiverNetwork.to_end_m`). Until the water pass they came out empty
    (points were appended to copies of packed arrays), so rivers showed
    only the still pool, with no current and no rapids foam;
  - lake, sea and wetland water tables are added. Each 16 m water quad
    takes the water level at its corners (unless the level jumps more
    than 0.75 m, e.g. a lake rim), so neighboring quads share edges: a
    quad at its own flat level left a hairline step where a river's
    level met the sea's, and the ground showed through as a thin light
    line across the water. River pool quads reaching over a waterfall's
    lip are left out (their flat edge hung out over the fall and hid the
    crest);
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
  - ground collision exists only for the detail ring (nothing farther
    needs it: creatures read heights, arrows fall short) and is built a
    quarter-chunk strip per frame, the player's chunk first
    (`TerrainChunk.build_collision_part`, ~1.5 ms each). It's built on
    the main thread on purpose: in Godot 4.3 a `set_faces` from a worker
    is only queued, and the physics server builds the BVH on the main
    thread at its next call anyway (unless physics runs on its own
    thread), all at once;
  - plant geometry is built by the chunk workers for the species they
    place (`PlantMeshes.warm`), so the main thread only uploads meshes;
  - the loading screen blocks only for the detail ring; its chunks jump
    the worker queue, and work still queued for where the player was
    before a jump is abandoned.
- **Floating origin** (`World`). The planet center is stored in double
  precision and everything under `world_root` shifts when the player
  gets 1.5 km from the origin.
- **Far shell** (`FarShell`). A coarse sphere mesh for distant land and
  sea, sunk slightly and hidden inside the chunk radius, with slope
  normals.

Measured headless (see Performance): per chunk on a worker, terrain
~40 ms and vegetation ~210 ms (trees and undergrowth); the loading
screen's blocking load about 5 s.

**Thread safety note.** Godot 4.3 can corrupt nested constant arrays when
several threads read them at once. Anything the chunk workers read is
therefore a flat packed array (`BiomeTemplates._colors`) or a private
copy.

## Water ripples

`scripts/water/` (`Ripples`, `RippleSim`), `shaders/ripple_step.gdshader`,
`shaders/ripple_view.gdshader`, the ripple part of `water.gdshader`, and
`data/water/ripples.json` (every number below; see its README)

Anything that touches or moves through water near the camera rings it
(spec Phase 1, ripple system). `Ripples` is the one way anything
disturbs water; `RippleSim` owns `World.ripples`.

- **One buffer round the camera** (agreed at Go): 256 × 256 texels of a
  quarter meter, 64 m of water, centered 10 m ahead of whichever camera
  is drawing, instead of one per nearby water chunk. A ring never has to
  cross from one chunk's buffer into the next (or over a cube-face edge),
  it's one simulation instead of four to nine, and a footstep's ring is
  several texels across. The window moves in whole texels and the
  simulation shifts its content back to match, so ripples stay put on
  the water; its axes are carried along the planet, so the grid never
  turns, and it lives in planet directions, so the floating origin never
  smears it. It runs only while there's water (sea, lake, wetland pool
  or river) in the chunks under it. Ripples fade out between 22 and 40 m
  from the camera; past that, and whenever it isn't running, the water
  is the static shader, unchanged.
- **Simulated on the GPU**, one step a frame: a damped wave equation
  (rings spread at 1.1 m/s and die away over a few seconds) drawn by two
  SubViewports taking turns, each reading the other's last state. Height
  and vertical speed are packed as 16-bit numbers in 8-bit channels
  (exact in both renderers). A weak spring settles the surface back to
  flat, and a soft border lets rings leave instead of bouncing back.
- **Contacts** (`Ripples.splash`, `Ripples.wake`) are sized by mass and
  speed from the table and batched, up to 32 stamps a step, each
  zero-sum (pushed down under the body, up round it, as displaced water
  is):
  - a splash is a point: its footprint grows with the cube root of the
    mass, its push with mass^0.3 × speed^0.5, so an arrow at full draw
    (55 m/s) rings the water about as clearly as a wading step, a leaf
    barely;
  - a wake is the line each contact moved along since the last step,
    one furrow per contact, so a moving body drags a continuous wake
    (not a string of splashes) whatever the frame rate;
  - the player: dropping in (a jump or a fall, faster than 1.5 m/s)
    splashes with the whole body, while wading in from the bank is just
    a step; wading, each leg drags a wake and every footstep
    (`Footsteps`) plants a small splash; swimming, the body drags a wake
    and the hands splash with each stroke;
  - creatures (`creature.gd`): wading legs drag wakes and every half
    stride plants a foot's splash; a body afloat (or without legs, like
    a snake) drags one wake from its hull; mass is 25 kg × size³ (a
    1.4 m deer ~70 kg). Anything up a tree, flying, or a wisp doesn't
    touch water;
  - arrows splash where they meet water, then sink; one fast enough to
    go through shallow water onto its bed within one physics step
    splashes where it went in;
  - rain: drops land at random, in 1 m cells, up to 0.05 per m² a
    second in full rain (4 mm/h), each ringing the water (drawn in the
    step shader, not sent one by one). Denser, the rings overlap into a
    blotchy pattern instead of reading as rings;
  - dropped items and falling leaves don't exist in the game yet; when
    they do, each calls `Ripples.splash()` where it meets the water,
    with its own mass in the table, as arrows do.
- **Painted, not lit** (R1, R1a). The view shader turns the state into
  what the water samples: where each ring is in its swing (crest or
  trough), its slope (the surface normal) and how big it is (height and
  speed together hold steady through a swing), all from the surface less
  its mean half a meter round, which keeps the rings and drops the
  broad, slow swell a big splash leaves inside them (painted, that read
  as wide blotches, not rings). The water paints every ring as two soft
  bands: a light one over the crest, toward the highlight blue (night:
  #7FB0FF; measured #81B7FF-#98CCFD on screen, the brighter streaks as
  bright as the water's own highlights), and a dark one over the trough,
  a deeper ultramarine (measured down to #0E31CA, never black).
  A ring keeps the same two tones while it's big and fades as it dies
  away. Under the bands the water's own mottling and sparkle calm, so
  they read as bands (before, rings were lost in the mottling); the
  water's grain roughens their edges, and a finer grain from the same
  texture streaks them like brushwork (R1's crunchy texture on smooth
  shapes; flat fills looked like vector art next to the designer's
  night references); the side of each ring facing the moon (or sun) is
  painted a little lighter; a hard splash churns pale for a moment.
  Nothing is reflected. Bands finer than about two pixels (far off, or
  seen edge on) fade out instead of shimmering.
- **Readers** (agreed at Go): `Ripples.height_at(pos)` and
  `disturbance_at(pos)` (fish fleeing, later) sum the recent
  disturbances (where, how big, how long ago: up to 256 from the last
  6 s) as rings with the simulation's own speed and damping, fitted to
  it: 1.6 s after a splash, the trough's depth and radius match the
  simulated buffer within ~10% (the center's bob is underestimated).
  `Ripples.near(pos)` says whether a contact there would ring anything,
  so callers can skip the work. The buffer itself stays on the GPU
  (`RippleSim.texture`), since Godot 4.3 can only read a texture back by
  stalling the renderer.
- Headless (no renderer) the simulation doesn't run; contacts and the
  readers still work. `enabled: false` in the table turns it all off.

Cost: `update_ripples` averages 0.07-0.12 ms a frame in the demo (the
contacts, the window and the uniforms), 9-20 µs alone without the
software renderer competing for the CPU; `height_at` ~10 µs with 30
recent disturbances. The three ripple passes took 1.3 ms of GPU time a
frame on the software renderer (lavapipe, 960 × 540, busy water:
splashes and a wake every frame) against 5.7 s for the main view, so
well under 0.1% there; whole-frame times on and off were lost in the
noise of other work sharing the machine. The compatibility renderer
runs the same simulation and paints the same bands (checked with the
demo's first night stills). On the GPU, three 256 × 256 passes a frame (the
step, ~9 reads a texel plus the stamps; the view, 13 reads) and two
more texture reads per water pixel while it runs (the buffer and the
bands' brush grain).

Checked with `tools/ripple_demo.gd` (run instructions in its header): on
the postage stamp at night, through the player's own third-person
camera, the player wades along a shore (a ring from every step, a
continuous wake from his legs), looses an arrow that comes down about
8 m out (its own ring, clear of his), wades back through the rings,
then rain rings the water around him: a 13 s recording (Godot's Movie
Maker), or stills of the same plus dusk and noon and the CPU readers
against the simulated buffer.

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
  Trees have crowns of 3-6 overlapping noise-displaced spheres (faces
  buried in a neighboring lobe are dropped, so triangles go to the
  silhouette) with leaf cards on the outside, and trunks that taper, bend
  and flare, with branches into the crown. Three detail levels
  (`PlantMeshes.LOD_*`), swapped per chunk (`TerrainChunk.set_fine`):
  - hero, the chunks within 120 m of the player: round crown lobes
    (180-triangle geodesic spheres), 12-sided trunks with a rounded
    flare, curved branches; a tree is 300-820 triangles, a shrub ~270;
  - near, the rest of the detail ring: 80-triangle lobes, 8-sided trunks;
    120-370 triangles;
  - far, beyond it: 80-triangle lobes, 5-sided trunks, no branches,
    cards or vines; 56-230 triangles.
- **Branchy canopy trees** (Phase 1 (i); `TreeLayouts`). Broadleaf,
  gnarled, emergent, umbrella and cypress canopy and emergent trees are
  drawn from a skeleton instead of one leaf blob: the trunk forks into
  3-5 thick limbs, each limb splits into branches, and the leaves are
  clusters on the outer third of each limb and branch (and twigs fanning
  from the branch tips on leafy species), each 3-4 crossed alpha-cutout
  leaf cards, lumpy, with open air between clusters: from below you see
  the limbs, the sky through the gaps and whatever moves in them, not a
  solid crown. Cypress keeps its column: a leader to the top with short
  upturned limbs, leaves up the top of the leader. How many clusters and
  how big: the species' `leaf_density` (table, else a shape default) in
  the mesh (about 8 on a cypress, 12-16 on paloverde or mesquite, 17-27
  on leafy broadleaves); per tree, `PlantMeshes.leaf_amount(growth,
  moisture)` in the MultiMesh custom data's alpha (as bareness) thins
  them (each cluster has a shuffled 0-1 key in CUSTOM0.w; the shader
  hides those above the tree's amount) and shrinks the rest about their
  centers (CUSTOM0.xyz), so dry sites carry thin crowns. Growth is a
  stand-in until Phase 6 (height within the species' range: mature to
  old); the shader's `leaf_season` (1) is the hook for winter. Each species grows
  `TreeLayouts.COUNT` (6) layouts from the world seed and the species;
  each tree picks one, mirrored or not, by hashing the world seed, its
  chunk and where it stands (`TreeLayouts.pick`), so the same tree grows
  the same way on every visit and neighbours differ. Trees stay batched:
  in the detail ring each chunk draws a branchy species with one
  MultiMesh per layout it uses; beyond it, with the species' old
  single-crown far mesh in one MultiMesh (both sets are built on attach,
  and `set_fine` shows one or the other). Hero draws every ring of the
  skeleton (12-sided trunk, 9-sided limbs, 6-sided branches, four cards
  a cluster; about 1,000 triangles a tree); near draws every other ring
  and three cards a cluster with the same limbs and clusters, so nothing
  pops between them. Wood you can hold (trunk,
  limbs, branches; palm stems, mangrove roots and stems, conifer trunks)
  has zero sway weight, so it holds still in the wind and a handhold
  never drifts off it; leaf clusters, twigs, leaf cards, fronds and vines
  sway as before. The same skeleton gives the mesh, the colliders and the branch
  graph, so all three agree.
- **Branch graphs** (`BranchGraph`, `BranchGraphs`; the contract other
  systems read). Per layout, handholds are laid along the skeleton every
  ~0.5 m (`BranchGraph.SPACING_M`): up the trunk from 0.4 m to where the
  limbs leave, then out along each limb and branch until the wood is
  thinner than 3.5 cm (`BranchGraph.MIN_RADIUS_M`), each with its
  tangent, the wood's radius and its limb number, linked to its
  neighbours along the wood and across each fork (both ways). They're
  cached per layout and 10% height step in the unit-height frame; a
  tree's graph scales them by its height, mirrors them if it is, and
  `xform` places them with the tree's rigid transform (radial up, yaw,
  lean; no scale). Palms, conifers and mangroves (stilt roots too) get
  trunk-only graphs; bamboo, cacti and rosettes none. `ChunkManager`
  gives every tree within 60 m of the player a graph (nearest first,
  1 ms of work a frame) and drops it past 70 m or when its chunk leaves
  the detail ring or is freed. The key is a hash of the chunk key and the
  tree's index in placement order (`chunk.trees` is now in placement
  order: `trees[i]` is `hosts[i]`). Nothing is stored: a chunk that
  unloads and reloads gives the same keys and the same handholds, to the
  millimetre.
- **F6** (dev mode only; `BranchGraphView`): draws the handholds of the
  graphs within 30 m of the player over everything, green where the
  player can hold (wood at least 6 cm thick), yellow where only a monkey
  can, and the links as lines; redrawn four times a second, and gone
  entirely when off.
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
- **What the branchy trees cost.** A branchy tree is 2,100-2,900
  triangles at hero (was ~760), 900-1,330 at near (was ~350), and the
  same 160-235 far. Rendering info for the whole frame (shadow passes
  included), same seed, cameras and time, Forward+ at 960 × 540 on the
  dev stamp:

  | view | draw calls | primitives |
  |---|---|---|
  | rainforest, eye level | 251 → 277 (+10%) | 3.47 → 3.78 M (+9%) |
  | rainforest hero tree, noon / dusk | 293 → 345, 299 → 351 (+18%) | 4.46 → 4.93 M, 4.48 → 4.96 M (+11%) |
  | deciduous forest, eye level | 358 → 491 (+37%) | 4.27 → 5.66 M (+32%) |
  | deciduous hero tree, noon / dusk | 335 → 470, 324 → 465 (+40-44%) | 3.99 → 5.56 M, 3.93 → 5.50 M (+39-40%) |
  | boreal forest, eye level | 456 → 580 (+27%) | 5.33 → 6.39 M (+20%) |
  | dusk river (Phase 0 acceptance view) | 300 → 376 (+25%) | 2.30 → 3.32 M (+44%) |

  Draw calls stay well under double everywhere, so the six layouts
  stay (the agreed fallback was four). The rainforest is mostly palms
  and bamboo, so it changes least.

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

The data (`data/creatures/README.md`) also takes the spec's D4 fields
(`trophic`, `activity`, `biome_lock`, `water_bound`, `light_response`),
loaded for the ecology ledger to read later, and each entry's Linnaean
binomial (`genus`, `species`; invented organisms get an invented one and
`invented: true`). `"spawn": "disabled"` holds a species back from normal
play: no spawn tier or territory picks it, and the others' odds don't
change.

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
    neighboring packs answer back. A pack's howls are exempt from the
    rule that keeps two creatures from making the same call within 4 s
    (it would silence the answers).
  - F8 (dev mode only; `CreatureSpawner.dev_howl()`): the nearest pack
    within 800 m howls now, the leader first and the pack answering; a
    pack still at its den beyond 420 m comes out for 45 s to do it. The
    prompt line says which pack howled and how far off, or "No wolf pack
    within 800 m."
  - Once they notice you, they spread out and close in to about 9 m,
    then drift home when you leave.
- **Mythical** (`Territories`). At most one territory per 1.6 km cell,
  chosen among the mythical species whose climate fits.
  - **Dormant** beyond 1 km: nothing exists.
  - **Aware** from 1 km: unseen but pacing and calling. Calls are
    low-pass filtered and nearly mono far away, then sharpen as you
    approach (the distance muffling every far sound has; see Sound).
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
  `creature_sculpt.gdshader`): wolf, deer, goblin and the camp folk
  ("tribal" and "elder") are one seamless, skinned mesh each instead of
  glued primitives.
  - The body is signed-distance shapes (tapered capsules, ellipsoids)
    blended with a smooth minimum, meshed with surface nets on a worker
    thread at startup and cached per species.
  - Normals come from the field. Creases get baked occlusion, and colors
    blend across the joins, with paint shapes for bellies, muzzles,
    socks, hooves and the goblin's loincloth.
  - Vertices are skinned to the bones of the nearby shapes, and SculptRig
    copies the joint pivots onto a Skeleton3D, so Creature's leg, arm and
    tail swings bend the body at the hip and shoulder.
  - Triplanar fur or skin grain and a coarse LOD past 45 m.
  - Camp folk come in every shade of skin (people also of hide), so the
    tribal, elder and goblin meshes carry skin and hide as tint channels:
    each vertex's weight of each (with its shade and occlusion) in UV2,
    the person's colors in a material shared by everyone within a shade
    of them. One mesh per kind, not one per person (goblins used to start
    a new one-second build for every camp goblin's green, and never got
    to use it).
  - People: lean and long-limbed, a hide tunic to mid-thigh with a belt
    and dark hem, bare arms with leather bracers, leggings, wrapped feet,
    dark hair tied back, ochre paint under the eyes; the elder has a fur
    mantle, a drape down the back, grey hair and a beard. Their gear
    (spear, bow, quivers, staff) is `CreatureBodies.tribal_gear()`, shared
    with the primitive body, which stands in until the mesh is built.
    They start building with the planet (`prewarm_folk()`), and the
    opening camp waits for them.
  - Colors are sRGB, converted to linear when baked, like the primitive
    bodies' (they were baked raw, so sculpted coats came out paler).
  - Triangles (near / far): wolf 2,604 / 416, deer 3,596 / 660, goblin
    4,388 / 820. Built in 0.6-1.1 s each on a worker; no measurable frame
    time change.
- **Imported models** (`ModelLibrary`, `ModelAnimator`,
  `shaders/model.gdshader`; see `assets/models/README.md`): a `.glb` in
  assets/models/ named `player` or after a species or NPC replaces that
  body. It's scaled and placed, relit with the world's lighting on its own
  textures, and its clips play by state. Tested with a rigged stand-in
  exported to a real .glb: read raw at runtime, scaled to its sidecar
  height, relit, Idle and Walk switching as the player moved.
- **Hitboxes** (spec D5; `CreatureHitboxes`, on the shared `Hitboxes`):
  every creature and every camp person has collision parts matching its
  visible body, each riding the node that moves that piece (a leg's, arm's
  or tail's pivot, the head, the body's root), so they follow the gait, a
  seated pose, a turned head, the body's size and fade. Arrows and the
  bow's aim meet them (below, the bow); the sphere tests that stood in
  for them (`CreatureSpawner.creature_on_segment`,
  `Camps.folk_on_segment`) are gone, not kept as a fallback: nothing
  lacks parts.
  - Sculpted bodies (wolf, deer, goblin, people) have their parts written
    out from the sculpt's own shapes, one capsule or sphere per bone: a
    deer's torso, neck, head, each front leg, each hind leg's thigh and
    shin, tail and both antler beams (13 bodies with its blocker); a
    wolf the same without antlers (11); a goblin its torso, head, nose,
    ears, legs, arms and lantern (11); a person torso, head, legs, arms
    and the biggest two pieces of gear (a spear, a bow, a quiver, the
    elder's staff; 7-9).
  - Primitive bodies (everything else, and the sculpted kinds until
    their mesh is built) are fitted from their own meshes: each piece's
    bounds on the node it rides, a capsule when it's long (a limb, a
    torso, a neck), a sphere when it's round (a head), a box when it's
    flat (a wing, a shell, a hat brim), a hull round a tapering cone (a
    robe, a horn); the biggest few, up to 3 for small animals, 10 for
    the rest, 12 for mythicals and people, leaving out eyes, noses and
    claws. The tiniest (a beetle, a tree frog, a songbird) keep at least
    their biggest piece; fireflies a 0.35 m sphere in the heart of the
    cloud (an arrow through it hurts the swarm and flies on). Imported
    models get one shape over the whole model.
  - Hit parts (`Hits`; see Health, hits and the view): every part is
    marked with its kind in a `hit_part` meta: head (with the nose and
    the goblin's ears), limb (legs, arms, wings) or body (torso, neck,
    tail, antlers, gear). Creatures of 0.3 m and up
    (`hits.eyes_from_size_m`) also get a small sphere over each drawn
    eye (the eye meshes carry their side, `eye_l` / `eye_r`), 2.5 times
    the drawn eye's radius and at least 2 cm, so it stands a little
    proud of the head's part and a ray aimed at the eye meets it first.
    A deer has 15 bodies now (13 + two eyes).
  - A blocker on the world's layer, inside the torso, for everything
    0.6 m or bigger, every mythical and every person: the player can't
    walk through a deer or a person (stopped 0.5 m from its middle in
    test). Small animals have none.
  - Parts are static bodies moved with their nodes (a moving static body
    costs the physics step about a sixth of a moving kinematic one:
    it isn't checked against the terrain's bodies). They're in the
    physics space only while they could be hit: shown, alive, at least
    half faded in, and within 90 m of the player (`Hitboxes.ACTIVE_M`)
    or 25 m of an arrow in flight (`Arrow.flying`), so a long shot at a
    far animal still lands. Otherwise they're taken out of the space
    (`Hitboxes.set_active()`, disabled, not just on no layer).
  - Counts: 395-407 part bodies and 23-24 blockers in a busy daytime
    scene at the stamp's opening camp (87-89 creatures, 18 of them a
    herd of deer and a wolf pack added for the test, plus the camp's two
    people), 310-322 of them in the space. Cost: 520 parts on 40
    walking bodies, all moving every frame, add about 0.5 ms to the
    physics step (0.77-0.87 against 0.23-0.40 ms without; a kinematic
    version cost 5.4-5.8 ms), 0.04 ms to move; taken out of the space
    they add ~0.1-0.2 ms. A busy scene has ~20 creatures walking at
    once, ~220 moving parts, so about 0.2 ms a step. The whole-game A/B
    was lost in the noise of the shared machine (±3 ms either way).
- **Pond Crawler** (spec Phase 1 rig; `scripts/creatures/mythics/`
  `pond_crawler.gd`, `pond_crawler_body.gd`;
  `shaders/pond_crawler.gdshader`). *Limnoreptor cucullatus* (invented), a
  mythic of swamp and bog water, out at night. It's held back from normal
  play (`"spawn": "disabled"`) until Phase 7: `PondCrawler.debug_spawn()`
  places one and `tools/pond_crawler_demo.gd` records it; in dev mode F7
  (DevSpawn) puts one in the nearest water it can wade within 120 m.
  `CreatureSpawner.adopt()` ticks a creature placed by hand and lets
  arrows hit it.
  - Body (`PondCrawlerBody`): sculpted like SculptedBodies (signed-distance
    shapes, surface nets, baked occlusion, skinned), in two passes so the
    thin fingers get a finer grid than the body.
    - A low sack sits in the water with a mantle behind.
    - The hood's brim and cowl flaps stand proud of a dark face set back
      inside them.
    - Two long arms (shoulder, a high elbow, wrist) end in four splayed
      fingers with pale claws.
    - 5,832 triangles near, 1,640 past 45 m, 15 bones. It's built once on
      a worker (about 1.5 s) and shared by every crawler.
  - Hide (`pond_crawler.gdshader`): vertex-lit Lambert like the world.
    - Three of Look's painted textures (mottled stone, pebbly dirt, soft
      grain) are sampled triplanar in the body's rest pose, stored per
      vertex, so the crunch rides the skin as the arms bend.
    - Its `color`, #6E7590, is a slate albedo: under the blue night light
      and grade it lands on the trunks' deep ultramarine (screen #081D8D
      on the hood against the trunks' #0C1B7E, texture showing in every
      channel). A saturated blue albedo came out flat violet-blue, because
      the night light and grade crush red and green.
  - Eye: drawn per pixel across the recessed face in #2A6AFF, an almond
    slit with a hotter core.
    - It's narrow while it waits, with a slow blink; it opens wide when it
      lurches, flares when hit and goes out when it dies.
    - Its real light (an OmniLight3D, 5.5 m) hangs just outside the hood,
      lighting the water, its hands and whoever comes close.
  - Movement: the hands are contact points on the pond floor.
    - A step lifts one hand in an arc out of the water and down again.
      Where it breaks the surface it calls `Ripples.splash` (hand mass,
      speed) and plays a soft wet slap (3D, synthesized, six variants).
    - The body hangs from the planted hands on a loose spring: it lags,
      overshoots, sways, leans onto the planted arm and breathes. Its
      drift calls `Ripples.wake` every frame it's in the water. With the
      ripple simulation (RippleSim) each plant shows as a ring, and a
      lurch's overlapping plants stack into a field of them round it.
    - Two-bone IK bends each arm, elbow high and outward. A planted hand
      lies flat with its fingers splayed and curls as it lifts.
  - Behavior:
    - It waits, still, re-planting a hand now and then, and drifts rarely.
    - It lurches when you come within `notice_m`, scaled by your noise:
      arm over arm at `speed_mps`, the next hand lifting before the last
      lands, so the rings stack.
    - Within `strike_m` a hand rears up and slams down where you stand
      (`bite`). It holds its next step until a hand is down to strike
      with; lurching, one hand lifts as the other lands, so otherwise
      neither would ever be free.
    - It never leaves wadeable swamp or bog water (`wade_m`,
      `biome_lock`). Where the water ends before it reaches you, it stops
      at the edge and settles its hands, looking for a way on every half
      second. A step that gets a hand less than 0.2 m further isn't
      taken (it used to paw in place there), and a drift or a return
      that can't go on ends where it is.
    - Shot, it turns on you; killed, the eye goes out and it slumps and
      fades.
  - Hitboxes (spec D5): the shared `Hitboxes` helper, as the Night Rider
    (below). Capsules and spheres on the lump, hood, upper arms, forearms
    and hands, one body each on layer 3, riding the skeleton and
    each arm's bone attachments. An arrow's ray meets the part it visibly
    hits and sticks in it, moving with it. The player bumps into one
    `Hitboxes.blocker()` capsule through the lump (layer 1); the arms,
    like the rider's legs, don't snag you. Hit parts (`Hits`): the hood
    is its head, arms and hands its limbs (a hurt arm shortens its lurch
    strides), and its one slit eye a sphere just proud of the hood,
    marked `eye` with no side: hit, it notices you late all round.
  - Tunables are the entry's `rig` (data/creatures/README.md).
- **Night Rider** (Phase 1 rig; `scripts/creatures/mythics/`, data "Night
  rider", *Nyctequus gemellus*, invented): two riders on dark horses,
  always a pair, boreal forest (taiga) at night, aggressive. Held back from
  play until Phase 7 (`spawn: disabled`: CreatureSpawner skips it and
  Territories leaves it out of the odds, so every other territory is
  unchanged; all 53 on the dev stamp hash the same with and without the
  entry). Seen through the dev spawn (`NightRiderPair.debug_spawn()`, on
  its turn of F7 in dev mode) and `tools/night_rider_demo.gd`.
  - Body (`NightRiderBody`): horse and hooded, cloaked rider as one
    sculpted skinned mesh, reusing SculptedBodies' shapes, surface nets and
    skinning with its own spec, cache and rig (no change to the shared
    sculpt code). A heavy horse (deep chest, arched neck, long mane to one
    side, full tail, thick legs with the hair flaring over broad hooves);
    the rider's deep pointed hood with a dark void for a face, broad
    shoulders, sleeves to gloved hands at the reins, the cloak over the
    horse's back and down its flanks with a torn hem. 16 bones in a real
    hierarchy (each leg two: shoulder or hip to knee or hock, then to the
    hoof), mirrored by nested pivots, so a pivot's rotation is its bone's
    local pose. Triangles (near / far, switching at 55 m): 9,756 / 2,420;
    the far mesh's shapes are thickened to at least its cell size so legs
    don't break up. Built in about 4 s on a worker the first time it's
    needed (at startup in dev mode, for F7).
  - Look (`shaders/night_rider.gdshader`): vertex-lit like the world, with
    Look's fur strokes and a hard-edged grain triplanar at a scale where a
    texel is one to three screen pixels at walking distance (crunchy
    texture on smooth shapes). The texture is bound to the rest pose: each
    vertex carries its rest position and normal (CUSTOM0, CUSTOM1) and the
    strokes and grain are looked up there, so they ride on the skin
    instead of sliding over the legs as they walk. Palette (data) deep
    ultramarine and indigo, every color at or above the night sky's
    darkest, #0A14A0, and the shader eases creases and dark strokes onto
    that floor rather than below it. At night they are "lit only by blue
    sheen", as in the designer's references (a dark armoured figure, a
    dark horse): the world's night light reaches them only `night_shade`
    as much (data "look"), so they stand as deep blue masses darker than
    the trunks, and a cold blue sheen (emitted; strongest on the edges
    turned away from you, across the planes facing up and toward you, and
    on what faces the sky, broken into streaks by the strokes and grain,
    like the era's sphere-mapped gloss) carries their shapes. The rider's
    face and the horse's eye sockets and nostrils are a void: untextured,
    catching no sheen, the darkest thing on them. The world's own
    materials have no sheen (look.gdshaderinc); this is the riders' alone.
    Eyes:
    `shaders/eye_glow.gdshader`, small camera-facing points of #FF2A2A
    with a soft halo that never shrink below about three pixels, drawn a
    little toward the camera so the head doesn't swallow them (it still
    hides them from behind). They are the only light on the riders; no
    light sources.
  - Movement (`NightRider`, a Creature): heavy momentum. Speed eases at
    `accel_mps2` (0.25 m/s²: four seconds to walking pace), and the heading
    turns no tighter than an 8 m circle, the turn rate itself easing (a
    heavy body swinging round); nearly stopped it can turn slowly on the
    spot. It wades up to 0.7 m and won't step deeper. The body pitches to
    the slope between fore and hind hooves.
  - Gait: a slow four-beat walk only (left hind, left fore, right hind,
    right fore, a quarter cycle apart). Each hoof is placed by two-bone IK
    on its leg's pivots, fore knees bending forward, hind hocks back. In
    stance the hoof sweeps back exactly as fast as the body moves on (the
    stride scales with speed), so planted hooves don't slide; out of reach
    at the ends of the stride the leg points straight at it, so the hoof
    settles onto the ground and peels off it rather than skating. In swing
    the hoof lifts 13 cm, folding the knee or hock, and sets down softly
    (no spray). The head dips as each fore hoof lands, the body bobs
    1.5 cm and rolls a touch, the rider sways, the tail swings, and each
    hoof follows the ground under it.
  - Pair (`NightRiderPair`): the follower rides in the leader's tracks two
    horse lengths behind (5.1 m nose to nose), steering for the leader's
    recorded track and easing its speed to hold the gap, its gait held 0.4
    of a cycle out of step (so the eight hoofbeats never coincide). The
    leader patrols (waypoints ahead within its territory, in its biome,
    steering round trunks early with rays on the tree layer), walks a
    route, or hunts: at night within `notice_m` (more if you're loud), or
    once shot, it walks at you and strikes in reach
    (`CreatureSpawner.player_hit`, the species' `bite`; no balancing).
  - Hitboxes (`Hitboxes`, generic, now every creature's: Creatures,
    Hitboxes, above): one body (a static body, moved with it) per part
    riding its pivot, sized
    to the mesh: barrel, neck, head, tail, each leg's two segments, the
    rider's body, arms and hood. The parts are on their own physics layer,
    3 (`Hitboxes.LAYER`, bit value 4), not the world's layer 1, so the
    player's movement (mask 1) never snags on a leg. Arrows find them: the
    arrow's physics ray includes layer 3 in its mask (and the bow's aim
    ray looks at every layer), and a ray that meets a part hurts that
    creature (`Hitboxes.creature_of()`) and the arrow sticks in that part,
    riding with it; the gap between the legs is a miss. For the player to
    bump into there is one simple body per creature on layer 1
    (`Hitboxes.blocker()`: a capsule through the horse's barrel, inside
    the parts, so a shot always meets a part first). All off (out of the
    physics space) when it dies. Hit parts (`Hits`): the horse's head and
    the rider's hood are heads, the legs and the rider's arms limbs (a
    lame horse walks slower), and each glowing eye, horse's and
    rider's, has a small sphere marked with its side (a blinded leader
    notices you later on that side).
  - Sound (`NightRiderSounds`): each hoof landing is a soft synthesized
    thud (a low falling thump, a dark press of noise, a brief hush of
    needles; no clop) on a 3D player moved to that hoof (unit size 5 m,
    heard to 110 m). A hoof in water sends `Ripples.splash` as it lands and
    `Ripples.wake` while it wades (no-ops until the ripple simulation is
    attached).
  - Biome cue (`Mythics`): on walking into a `biome_lock` biome during the
    species' hours (or when they begin while you're there), at most every
    `cooldown_s`, a 12 s recording of the pair walking far off
    ("hoofbeats_far": both four-beat walks, out of step, darkened and
    echoed) plays on a 3D player 280-420 m away, in the direction the
    biome runs deepest from you, moving across as they walk, muffled by
    distance. It reads the player's biome cell and the sky's daylight and
    spawns nothing.
  - Dev spawn: `NightRiderPair.debug_spawn(mythics, from, facing)` (from
    code) brings a pair across the view about 30 m ahead, on dry ground.
    The shared F7 key (DevSpawn, below) calls it on the riders' turn and
    sends the pair before away; Mythics no longer handles F7 itself, it
    only ticks the pairs in `pairs`.
- **Gibbon** (spec Phase 1 (iii); `scripts/creatures/gibbon/`,
  `shaders/gibbon.gdshader`, the "Gibbon" entry, *Hylobates lar*): R3's
  gibbon-type monkey, travelling by brachiation along the trees' branch
  graphs (BranchGraph, found through BranchGraphs; it only reads them).
  Nothing spawns it in normal play (`"spawn": "disabled"`);
  `Gibbon.debug_spawn(parent, near_pos)` hangs one on the nearest handhold
  it can hang from; F7 (DevSpawn) calls it on the gibbon's turn, on the
  nearest rainforest tree within 200 m.
  - Body (`GibbonBody`): SculptedBodies' shapes and mesher, one smooth
    skinned mesh. A small torso, arms twice its length (1.57 m fingertip
    to fingertip against 0.78 m crown to heel), short legs with long
    grasping feet, no tail, a round head. The coat and the pale parts
    (the ring round the face, hands and feet) are tint channels, so the
    species' `color` and `accent` set them. The face and its ring are
    drawn per pixel in the shader, in rest-pose space, so they stay crisp
    on a coarse mesh. Every vertex carries its rest position and normal
    (CUSTOM0/1) and the fur is textured in those, so it doesn't slide as
    the arms swing. At night coat and ring ease into the ultramarine and
    a floor keeps the creases deep blue, never black; the eyes are small
    dark beads, lit, no glow. 4,604 triangles near, 1,708 past 28 m,
    built once on a worker (about 2 s).
  - Rig (`GibbonRig`): each arm reaches its target with two-bone IK, the
    palm turned to the wood and the fingers hooked round it; the chest
    bends, the head looks, the legs are set directly.
  - Swinging (`Gibbon`): a pendulum from the top of the wood to the center
    of mass (0.78 m) under gravity with a little damping, pumped up by the
    legs when it wants a bigger swing, braked when it wants to slow. The
    body hangs from the holding arm, leaning away from it and turned so
    the free shoulder leads; the arm never stretches past its reach, so
    the hand stays exactly on the handhold.
  - Leaping (`GibbonPlanner`): for a handhold x m ahead and y m up,
    `solve()` tries release angles against catch angles and returns the
    swing, the release point and the flight. At that point of a forward
    swing it lets go, flies the exact ballistic arc to the catch
    (`launch()`, the pulling arm adding up to 4.6 m/s, a release at up
    to ~8 m/s) and catches with the other hand. Short gaps are "contact"
    moves: the free hand closes on the next handhold as the body swings
    under it. A catch keeps at most a 77-degree swing (the arm soaks up
    the rest). It can leap 8 m across (about 6.5 m on the level; the
    longer ones drop), climb 1.5 m and drop 6 m in one leap. (Built
    against the fixture it leapt 5.8 m, climbed 1 m and dropped 3.5 m;
    the real canopies needed more, below.)
  - Climbing (`Gibbon` "climb", `GibbonPlanner.climbable()`): wood it
    can't hang from (thicker than 15 cm radius, or steeper than about 58
    degrees) but no thicker than 1.2 m it climbs where its route goes that
    way: hand over hand up or down a trunk or steep limb at 0.9 m/s,
    clinging to the side the route leads to, the hands taking turns on the
    bark and the legs gripping frog-like; or upright along the top of a
    thick limb flatter than 30 degrees at 1.3 m/s, arms raised for
    balance, legs stepping (the gibbon's bipedal walk). At the end it
    hangs from the next handhold it can hang from and swings on. The
    route search crosses climbing wood at 2.2 times its length and each
    goal scores down by its meters of climbing, so it swings where it can
    and climbs to get round, up (after a leap down) or out of a tree.
    Trees with nothing to hang from (palms, a giant whose thinnest wood is
    too thick for a hand) are left out of the search: no leap leaves them.
  - Choosing handholds: at each new grip it asks
    `BranchGraphs.handholds_within()` for handholds within 10 m it can
    hang from (3.5-15 cm radius, no steeper than about 58 degrees) that a
    swing can reach. It prefers those further along its route (any
    direction the route turns), else ones in its direction of travel that
    bring it nearer the route ahead. It also prefers the next handholds
    along the same limb when the gap is short, and moves its momentum
    already carries it toward. The swing it has matters: a big swing
    takes a long leap, and near its goal it slows by choosing short ones.
  - Behaviour: it picks a goal 10-38 m off through the canopy that it can
    reach and also get back from (`GibbonPlanner.search()`, forward and
    reversed, because a leap drops further than it climbs), so it never
    strands itself on a limb it can only drop out of. It travels there,
    pauses and often hoots, pulls up to sit on thick wood (6 cm radius or
    more) if it's holding some, and turns round on its hand when the next
    goal is behind it. Leaving its route (or finding the way blocked)
    routes it again from where it is.
  - Staying near (`player`, set by the dev spawn): more than 35 m from
    the player (across the ground), its next goal is the one that brings
    it nearest them. When its own tree leaves NEAR range (its graph is
    dropped at 70 m) it rests: sits up if the wood takes it, else hangs
    still, until the tree is back in range. Graphs of trees that come back
    are new objects with the same key and handholds; it swaps to them
    every half second (its grip, its target, its route), so the route
    search sees the tree it holds. If its tree's chunk goes altogether it
    is "away" (hidden, hitboxes off) and hangs on again when a graph with
    that key returns. (It used to free itself.)
  - Shot (`hurt()`): the arrow's hit reaches it through its hitboxes'
    `creature` meta (`Hitboxes.creature_of()`); it gives an alarm call,
    breaks off a rest or a sit, gives up a goal toward the shooter and for
    20 s prefers goals away from where the shot came from. It takes no
    damage (it has no health yet), but the hit reads like any creature's
    (`Hits`): the part's number rises and a head or eye hit flashes the
    X. The arrow sticks in the part it hit: Arrow
    now parents itself to the collision shape the ray met (its shape
    owner), which GibbonHitboxes moves with its bone every frame, so it
    rides along with that arm or leg.
  - Hoots (`GibbonHoot`, synthesized like SoundSynth's placeholders): a
    few rising "hoo-wup" notes, or the great call (notes climbing and
    quickening into a trill), from an AudioStreamPlayer3D heard at full
    volume within 12 m and gone at 160 m.
  - A blob shadow only within 3 m of the ground (a ray down against the
    world's layer; tree trunks don't count).
  - Hitboxes (`GibbonHitboxes`, D5): 15 capsules and spheres fitted to the
    body (hips, chest, head, the two eyes, and per side upper arm, forearm,
    hand, thigh, shin; each shape marked with its hit kind), in one
    kinematic body that follows the posed bones every
    frame. It's on physics layer 3, named `creature_hitboxes` in
    project.godot, not layer 1, so the player never snags on it; rays that
    don't filter layers (the bow's aim, the arrow) meet it. The body
    carries the gibbon as its `creature` meta and `part_name()` names the
    part a ray hit.
  - Test canopy (`GibbonCanopyFixture`): until the real branch graphs
    land, eight synthetic trees 16-30 m tall stand 5.8-6.6 m apart in two
    staggered rows with overlapping crowns. Each has a trunk and 3-5
    limbs (some with side branches), handholds every 0.5 m, the wood
    tapering from 0.25 m to 0.035 m, links along the wood. They are
    registered with BranchGraphs under one Node3D chunk and drawn as
    tapered bark tubes and leafy lobes in the plants' material.
  - Checks: `tools/gibbon_demo.gd` (stills of the body by day, sitting and
    at night; a still with the debug lines; a dusk recording, run with
    `--write-movie` and trimmed at the frame it prints). It stands the
    fixture in the stamp's rainforest (hiding the planet's canopy trees
    around its footprint) and spawns through `debug_spawn()`.
    Run headless over the fixture for 90 s (5 seeds), it made 22-29 leaps
    and 21-26 reaches and reached 5-6 goals, with sits and turns, no
    failed swings, and the holding hand within 0.1 mm of its handhold.
  - The real canopies (headless, the dev stamp's rainforest, seed 42).
    With the old limits the crowns hardly joined: at four spots only 2-7
    trees with wood it can hang from joined up (of 7-23), most gaps
    between crowns being 6-8 m, and palms and the big buttressed trees
    (whose thinnest wood is 15 cm radius or more low down) offer nothing
    to hang from at all; from the first spot a gibbon could reach one
    tree. Hence the longer leaps and the climbing. Over 90 s at each of
    five spots (spawned the dev key's way): 0-9 leaps (longest 7.4 m),
    0-6 reaches, 1-4 climbs (3-60 m of climbing: at the spots of big
    buttressed trees it mostly climbs, since their hangable wood is high
    and sparse), 2-9 goals, sits and turns, no failed swings, never more
    than 3.2 s without a goal, nothing freed, and the holding hand within
    1.7 cm of the wood (on steep wood the grip sits round the bark).
- **Dev spawn key** (F7, the `dev_spawn` action; `DevSpawn`, which main
  adds only in dev mode, and which checks dev mode again on every press):
  each press spawns the next Phase 1 rig beside the player, in turn the
  Night Rider pair (`NightRiderPair.debug_spawn()`, the pair before sent
  away), the Pond Crawler (`PondCrawler.debug_spawn()` in the nearest
  water it can wade within 120 m, searched outward in rings on a 3 m grid
  with 3 m of wadeable water round it; outside its swamp and bog it is
  placed unlocked and the console says so) and the gibbon
  (`Gibbon.debug_spawn()` on the nearest wood it can hang from of a
  rainforest or jungle tree within 200 m, set to stay near the player).
  It prints what it spawned or why not ("[F7] no gibbon: no rainforest
  trees within 200 m (you're in Beach)"); a rig that can't be placed
  doesn't stall the cycle. A new crawler or gibbon replaces the last one
  the key made. Nothing spawns in normal play.
  Checked headless on the dev stamp with real F7 key events: at the first
  camp (a beach) the riders came 37 m off, a crawler went in 0.76 m of
  water 38 m off (outside its swamp and bog, said so), and the gibbon's
  turn printed "no rainforest trees within 200 m (you're in Beach)"; in
  the rainforest all three spawned (the gibbon 10 m up a 15 m tree); by
  swamp water the crawler went into 0.98 m of Swamp / bayou water; with
  dev mode off, F7 did nothing. An arrow shot at the spawned gibbon
  stuck in its chest (the `chest` shape), counted a hit, and over the
  next 3 s rode 0.30 m with it while staying exactly in place on the
  part.

Sounds are synthesized placeholders (`SoundSynth`): chirp, call, croak,
howl, drone and whisper, each on the creature's own 3D player (see
Sound). Bodies are placeholders (`CreatureBodies`)
built from smooth-shaded spheres and capsules (28 sides × 14 rings for
bodies and heads, 16 × 8 for snouts and tails, coarser for eyes and
noses), limbs that taper from hip to foot (12 sides), and
flattened-cone ears, vertex-lit by `creature.gdshader` (Lambert, no
specular), each with a blob shadow (`BlobShadow`). Meshes are shared by
every creature: 336-820 triangles each (deer ~900 and troll ~1,030 with
antlers and mossy back). Wolf dens are framed by boulders and a bevelled
slab. (The capsules and
limbs were wound inside out, so their near side was culled and the far
side's inside showed through, lit backwards. `_revolve` now winds them
the way Godot draws a front face.)

## Sound

`scripts/core/audio3d.gd`, `data/audio.json`, `SoundSynth`

Every world sound is a 3D player with distance and direction (spec D5):
nothing plays as a flat 2D sound any more. One table, `data/audio.json`,
has a row per kind of sound; `Audio3D.apply(player, kind)` sets a
player's unit size (full loudness within it), max distance (silent past
it, fading out linearly toward it), attenuation model (`inverse`: about
6 dB quieter per doubling of distance, like sound in the open; also
`inverse_square`, `log`, `none`), loudest boost when closer than the unit
size, and distance muffling:

| Kind | Who | Unit m | Max m | Muffled m |
|---|---|---|---|---|
| footstep | the player's feet (`Footsteps`) | 4 | 35 | — |
| player_voice | the player hit, at the chest | 4 | 40 | — |
| bow | draw and release, at the hands | 4 | 40 | — |
| arrow | its thunk where it lands | 6 | 60 | — |
| rustle | a tree's crown (`TreeContact`) | 6 | 60 | — |
| rain | four round the camera (`WeatherFX`) | 6 | 60 | — |
| wildlife_call | small wildlife | 8 | 60 | 25-60 |
| howl | wolves | 40 | 1200 | 60-760 |
| mythic_call | mythical creatures | 30 | 400 | 60-760 |
| hoofbeats_far | the Night Riders' biome cue (`Mythics`) | 45 | 1000 | 30-500 |
| camp_chatter | camp folk's murmur (`Camps`, `Encampment`) | 3 | 25 | 6-25 |
| thunder | the strike (`StormFX`) | 1000 | 12000 | 400-8000 |
| meteor | toward its head, 400 m out (`SkyEvents`) | 400 | 3000 | — |

The player's own sounds never get louder than set when the camera is
closer than the unit size (max boost 0 dB), so first and third person
sound alike. Muffled kinds lose their high end (down to 700 Hz) and most
of their left-right direction (panning down to 5%) between the two
distances from the listener, the camera drawing the view; one `Audio3D`
node, made on first use, updates the playing ones every frame, so a howl
dulls as you walk away from it (this replaces the spawner's old
`_fidelity`, which only wolves and mythicals had). The Night Rider's hoof
thuds and the Pond Crawler's sounds keep their own settings in
`scripts/creatures/mythics/`. Wind and campfire crackle have no sound
yet (deferred).

## The player

`scripts/player/`

- **Tables** (`Tuning`, `scripts/core/tuning.gd`): every movement and
  weapon number lives in `data/movement.json` and `data/combat.json`,
  each section explained in its `_help` block; read once at start
  (`Tuning.num(table, section, key)`, a missing key warns once and reads
  0). The designer's first play asked for this.
- **Movement** (`PlanetPlayer`; the feel of Melee's spacies): walk
  5.5 m/s (the old sprint), sprint 8.8 m/s (double-tap forward and hold,
  or the pad's left stick held in; timed in game time, so a slow frame
  doesn't break the tap), sneak 0.8 m/s (hold Shift or pad B). Gravity
  is 2x Earth's (19.6 m/s²) and the jump a short hop (5.2 m/s: 0.52 s in
  the air, 0.74 m high); a sprint jump takes off 1.12x faster and carries
  the sprint (5.9 m vs 3.2 m from a walk). Crouch in the air after the
  apex fast-falls at 20 m/s. Ground: 45 m/s² to speed, 60 m/s² to a stop
  times the traction underfoot (sand 0.75, snow 0.4, ice 0.15, shallow
  water and rain-soaked ground 0.5; `ground_wet` from the local rain,
  drying over 90 s), so a stop slides 0.3 m from a walk, 1 m from a
  sprint, 1.4 m on wet ground. Pushing the other way at speed keeps a
  quarter of the speed for a brief skid (a scuff) and goes: 4 m/s the
  other way in 0.2 s. In the air you steer at most 2.5 m/s off your
  take-off velocity, so a jump commits you; running off a ledge drops
  (0.55 s down 3 m, against 0.78 s at Earth's pull). Landing after a jump
  or a drop of more than 0.3 m squats 50 ms (no steering, no jump), 160 ms
  after more than a body length (1.7 m). Fall damage goes by the drop
  (over 6 m, 7 HP a metre), so a fast-fall out of a hop never hurts.
  Drawing the bow or raising the spear slows you to 0.75 m/s on the
  ground only; it no longer ends a sprint or a jump, and every action
  (draw, loose, throw, thrust, E) works in the air and out of a wall
  jump; a draw begun in the air holds through the landing.
- **Wall jump** (right mouse, pad right shoulder): in the air within
  0.25 s of touching a steep face (a wall, cliff, trunk, ruin), kick off
  it back the way you came (the approach reversed, turned away from the
  face) at 7.5 m/s angled 58 degrees up; each further wall jump before you
  land keeps 72% of the last one's upward speed (6.4 then 4.6 m/s), so you
  can chain between faces. The body tips back in a kick; a scuff sound,
  and creatures hear it 7 m off.
- **Aim** (`aim_sway_deg()`, combat table "aim"): the aim wanders a
  little, smoothly: 0.3 degrees standing, up to 1.2 at a sprint, least at
  a jump's apex (0 there, plus 0.45 degrees per m/s rising or falling).
  The aim arc shows the wander and the shot follows the arc.
- **Unstick**: stuck is touching something and going nowhere: wedged
  between two walls (a trunk and a shrub's stem), held off the ground
  (under a root), or caught on a crease of the ground's collision mesh
  (the last happens every few seconds in a dense forest; freed after
  0.08 s, a hitch you barely feel, by a nudge of a couple of frames'
  travel toward the free direction nearest where you push; the others
  after 0.5 s by 0.35 m). One trunk head-on isn't stuck. Headless: 2
  minutes through the stamp's densest patch, 715 m covered, never held
  for a second. The creases' cause (the capsule on the ground's trimesh)
  isn't found yet.
- **Inventory** (`Inventory`, `InventoryScreen`, `ItemIcon`, `WorldItem`;
  `data/items.json`; spec R4, the designer's item 11): ten carry slots,
  each holding one thing, and the equipment slots: ranged (the bow),
  melee (the spear), amulet, rings, each one worn plus two spares (rings
  two worn plus two). I opens a small plain panel in the R1a blues: what
  you wear on the left (spares dimmer), what you carry on the right, the
  chosen thing drawn large with its name and a sample's binomial in
  italics; nothing else. It doesn't pause the world; the mouse is free
  while it's open. E on a worn spare wears it; G sets a carried thing
  down on the ground (E takes it back). E on a plant (not a tree: E climbs
  those) within 2.2 m of your hands takes a sample by its shape: a
  cutting, a seed head, a leaf, a cut cactus column, or a bundle of herbs
  for the herb genera; it carries the species index, binomial, shape and
  colors, so it can be looked at now and traded or planted later. Past
  six carried things, each more is 8% slower (never below 60%), 12%
  slower climbing and 15% louder, and the body leans forward: felt, never
  shown. F9 (dev) puts one of each loose kind in the pack. Fish,
  mushrooms and stone tools have no source yet.
- **Noises out in the world** (`NoiseEvents`, spec D5: "player noise ...
  bow, spear ... is what creatures hear"): a tiny static facade.
  `NoiseEvents.emit(scene_pos, loudness_m)` records a noise for 8 frames;
  the player and its projectiles write them, creatures read them
  (`Creature._hear()`), each noise once. Where an arrow lands is heard
  8 m off (6 m when it splashes into water), the spear 12 m (9 m in
  water), a thrust's knock 5 m. Within that radius, widened by the
  creature's suspicion the way its flight distance is, ground, canopy and
  water-edge animals startle as if you'd come too close, but run, hop or
  fly from the noise rather than from you; within twice the radius they
  grow suspicious (a grazer stops and watches). Packs and mythicals are
  driven by the spawner and don't listen yet. So a missed shot spooks the
  deer it lands beside.
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
  sway baked per vertex, and about twice as many sides around as he had
  (30 round the robe, 36 round the ragged mantle, 22 × 13 for the head
  and hair), so his outline is smooth. The parts merge into four meshes,
  so four draw calls: the robe and gear, then Head at the neck and
  ArmL/ArmR at the shoulders (pivots for later animation). The shader
  lights him like the creatures and gives each material one of `Look`'s
  painterly textures, including `weave` and `fur`.
  The hem, sleeve ends and hair trail behind and flutter with
  `set_motion()` (the player's speed). Crouching still squashes the body
  vertically.
- **Trees** (`TerrainChunk` trunk colliders, `TreeContact`): canopy and
  emergent trees in the detail ring get colliders that follow the drawn
  wood (D5: no invisible walls, no ghost-through), built from the same
  skeleton as the mesh (`TreeLayouts.collider_segments`): up to four
  stacked cylinders along the trunk that lean, turn and taper with it
  (a flared foot takes two), each just inside the bark; a mangrove's
  five stilt roots and its stem instead of one fat post; a cactus's
  trunk and arms; no collider at all for plants whose wood stays below
  knee height (0.5 m), and no more 2 m minimum. Trees with a branch graph
  (within 60 m) also get capsules on their limbs and branches at least
  5 cm thick, so arrows stick in limbs. All on one static body per chunk
  (a shape owner per piece of wood, on physics layer 2 as well as 1),
  60 trees a frame (all at once behind the loading screen);
  `TerrainChunk.tree_up` now follows the tree's lean. One sphere query a few times a second finds trunks near the
  player: under a crown is `under_canopy` (rain shelter); walking through
  a crown or bumping a trunk rustles it (a synthesized rustle from that
  tree's crown, where it stays as you walk on, and a crown shiver through
  the MultiMesh custom data's b channel). A physics query
  stands in for a trigger volume per tree, which would be thousands of
  nodes.
- **Climbing** (spec Phase 1 (ii); `TreeContact`, `TreeClimb`,
  `ClimbSounds`): E facing a trunk (a ray on the tree layer) takes hold of
  the tree's branch graph at the handhold nearest your hands that you can
  hold (wood at least 6 cm in radius, F6's green). Two hands, each on a
  handhold (on a trunk or other steep wood also at an angle round it); one
  moves at a time and the body follows the middle of the hands, so it
  never swings and never leaps.
  - Trunk: W/S hand over hand up and down the trunk's handholds (which
    follow its lean and bend: the hands sit on the bark at the handhold,
    the body hugs the wood off the bark), A/D round it (the hands shuffle,
    never crossing). At a fork, pushing toward a limb on your side (the
    camera looking out along it) takes you onto it; the trunk's own top
    is as high as it goes. Down at the foot of the trunk (hands below
    1.3 m) S steps off.
  - Limbs: push along the limb (camera-relative) to shimmy out or back;
    the hands shuffle (the rear one catches up, then the front one reaches
    on). You hang under wood thinner than 15 cm radius (side on, shoulders
    along the line of the hands, as low as the arms allow) and straddle
    thicker wood flatter than about 33 degrees; limbs steeper than about
    44 degrees are climbed like the trunk. You stop where the wood gets
    thinner than a grip ("Too thin to hold any further out"). Push toward
    another limb of the same tree within 1.2 m of the front hand to reach
    across to it; push back to return, down onto the trunk from a limb's
    first handhold.
  - Every reach must carry the moving hand at least 0.1 m further the way
    you push (the direction is held while the stick and the camera stay
    put), so the hands can't dither back and forth.
  - Effort is rhythm, not a meter (agreed at Go): a reach moves the body
    at 0.72 m/s on steep wood and 0.45 m/s along a limb, then a beat
    (0.3 s) before the next; with a handhold every ~0.5 m that is about
    0.5 m/s up a trunk and 0.3 m/s along a limb. A breath out as a reach
    starts (every reach along a limb, every other one on the trunk), the
    bark brushing the hand that lets go, the bark rasping under the hand
    that takes hold, now and then a breath in: synthesized in
    `ClimbSounds` (its own, not SoundSynth) and played from three
    AudioStreamPlayer3Ds on TreeContact, at each hand and the head.
  - The elf's arms point from the shoulders at the hands and stretch or
    shorten a little (there are no elbows) so the hands sit on the wood;
    an imported model plays its "climb" clip. Taking hold eases the body
    from where it stood onto the tree over 0.4 s.
  - E lets go (you drop), jump pushes off: away from the trunk, back from
    under a limb, sideways off a straddle, handed to the momentum (`_move`)
    as before. Noise while climbing stays 0.3.
  - `TreeContact.graph_of(chunk, tree)`, `nearest_graph(pos, max_m)` and
    `nearest_holdable(graph, pos)` are the queries; a tree is found by its
    graph's key (`BranchGraph.key`), so it is the same tree with the same
    handholds when you come back, and a graph rebuilt under you is picked
    up again by key. Holds are kept in the tree's frame, so the floating
    origin never moves them.
  - A tree with no graph (bamboo; a tree whose graph isn't built yet) is
    climbed the old way: W/S at 1.1 m/s up to 90% of its height, A/D round
    it. E prefers a fallen log in reach.
  - Checked headless on a 16.7 m dry-season deciduous tree in the stamp's
    rainforest: E at its foot took the trunk at 1.8 m; W took 9 reaches
    up the trunk to the fork at 6 m; looking out along the limb, W took it;
    3 m along it in 2.6 s (0.46 m/s with the beats; 0.36 m/s on another
    run); a reach across 0.9 m to the next limb; on out along that one
    until "Too thin to hold any further out" at 7 cm radius. Every hold
    was logged; over 2,033 frame checks the holding hands stayed within
    2.9 cm of the bark.
- **Footsteps** (`Footsteps`): one per stride (0.5 / 0.78 / 1.25 m
  crouched / walking / sprinting), louder with speed, plus a landing.
  The ground: shallow water; else the collider underfoot (ruin stone,
  tree roots); else the terrain's vertex color classified like the
  terrain shader's texture pick (grass, stone, snow, sand, dirt). Seven
  synthesized sounds, on a 3D player at the feet; a step in shallow
  water also splashes (`PlanetPlayer.foot_splash`, `Ripples`).

## Health, hits, the bow and the view

The designer's item 10, "PSO-style health and hit feedback". Every number
below is in `data/combat.json` (`hits`, `feedback`, `healing`, each
explained in its `_help`) or `data/creatures/creatures.json`
(`hit_parts`); `Hits` (`scripts/creatures/hits.gd`) loads the first.

- **Health** (`PlanetPlayer`): 100 HP, shown as a health meter at the
  bottom left where the hearts were (`StatusHud`): a slim bar, 150 x 5 px,
  R1a blue (#4C7CFF on a #0A14A0 track, a #7FB0FF edge along its top,
  an #0A1250 outline, never black), and a small numeral beside it (13 px,
  whole HP rounded up). Under a quarter of full health the fill pulses
  toward the edge color. A red flash at the screen's edge on a hit, a
  thump and a gasp from a 3D player at the chest, and the "You died"
  curtain are as before; the weapon label sits above the meter.
  - **No regeneration.** Health comes back only three ways:
    - resting at a fire: standing or crouching still on the ground (not
      climbing, swimming or aiming) for 2 s within 4 m of a lit campfire
      (any: the camps', the opening camp's, mythic folk's; `Campfire`
      puts every fire in the `campfires` group, `Campfire.lit_near()`,
      each carrying a `lit` meta for a later fire system to put out)
      heals 1.5 HP/s. There is no sit action yet; crouching counts.
    - cooked food and camp medicine: hooks for Phase 10's inventory.
      `PlanetPlayer.heal(amount, source)` is the one entry point (returns
      what it healed, never past 100; `healed_by` counts per source), and
      `PlanetPlayer.heal_for(source)` gives the table's usual amount
      (`healing.sources`: cooked_food 20, camp_medicine 45).
    - waking by the fire after dying, at full health.
  - Falls faster than 11 m/s (about a 6 m drop) hurt 7 HP per extra m/s:
    15 m costs about 43.
  - Bites: a pack that turns on you (you shot one, or walked into them at
    night) and werewolves on full-moon nights chase and bite, knocking you
    back. Anything hostile that you shoot fights back.
  - The knock-back is added fresh each frame and fades. It used to
    compound: a hit's upward shove taken in the air re-added itself every
    frame and threw you tens of meters.
  - At 0 you slump, the screen goes dark ("You died"), and you wake by the
    opening camp's fire with full health and 3 s of grace.
- **Creatures can be hurt** (`Creature.hurt`): hit points by size
  (`CreatureSpecies.hp_max`, or `hp` in the data). A hare dies to one
  arrow, a deer takes two, mythical creatures several. Prey bolts from the
  shot. Hunters (`bite` > 0: packs and hostile mythicals) turn on you
  until you're 70 m off. Neutral mythicals vanish for five minutes. The
  dead topple (the side the killing blow came from facing up, so the
  arrow or spear in it stays in view) and fade after 14 s; a killed pack or mythical stays gone
  half an hour. Their health is never drawn: the rising numbers and
  their behaviour (limping, fleeing, going down) are the only readout.
- **Hit parts** (`Hits`): every hitbox part carries its kind (body,
  head, limb, or an eye with its side; see Creatures, Hitboxes). The
  weapons have one way in, `Hits.strike()` (the arrow, the thrown spear,
  the thrust), which calls the creature's own
  `hurt(amount, from_pos, part, at)`; that applies the species'
  multiplier (`hit_parts` in creatures.json: a species-level block, with
  a species' own entries over it; the tortoise's shell takes 0.4x) and
  the wound, and reports the hit.
  - body 1x; head 2x, critical; eye 4x, critical, and it blinds that
    side (`Creature.blind`): the animal notices you there at 0.3 of its
    flight distance (`hits.blind_notice`; the Pond Crawler's one eye
    blinds it all round, a Night Rider leader notices you later on that
    side); limb 1x and lames it: its speed times 0.5 each limb hit, never
    under 0.25 (`limb_slow`, `limb_slow_floor`; `Creature.lame`), and it
    limps: once a stride its body rolls down toward the side it was hit
    on, up to 7° (`hits.limp_roll_deg`). Critical parts are
    `hits.critical_parts`.
  - Camp folk and mythics use the same system. The Night Rider and the
    Pond Crawler are Creatures and take it all. Camp folk still can't be
    harmed (they had no health before, and none was added): a hit on
    them shows its number (the species-level table: a head is 2x and
    critical) and the X, and they complain as before (`Camps.shot_at()`);
    a glancing arrow or spear counts only its first touch. The gibbon
    (no health yet either) shows numbers and the X too.
- **Hit feedback** (`StatusHud`, reading `Hits.since()`: the creatures
  write the events, the HUD reads them, as with `NoiseEvents`):
  - a small number rises 0.7 m from the impact point over a second,
    riding the animal it's on, fading over its last 0.35 s: whole
    damage dealt ("12"), white, yellow (#FFD23A, the one warm accent) on
    a critical, edged in dark blue. Its size follows the camera
    distance, 15 px at 8 m times (8 / distance)^0.5, kept within
    11-19 px, so it's readable far off and never big up close. At most 4
    on screen (the oldest goes); hits on one target in the same physics
    frame (`combine_s`, one frame) add up to one number.
  - on a critical (head or eye) the crosshair, or the small dot, flashes
    into a Black Ops-style X (four short strokes out from a 3 px gap, 10
    px long) for 0.12 s, with a short sharp tick (SoundSynth
    "hitmarker": a bright ping over a click, 70 ms; a UI sound, the one
    sound not placed in the world). A kill holds the X 0.4 s, in the
    warm yellow, with the tick a little lower. An ordinary hit that
    doesn't kill shows only its number.
  - The bow's own random "critical" (a full draw's damage up to half
    again, `Bow._loose()`) is untouched: it's a damage roll, not a
    critical here.
- **The bow** (`Bow`, `Arrow`, `BowMesh`), as simple as Minecraft's: hold
  the left mouse button (or the pad's right trigger) to draw, release to
  loose.
  - Power is Minecraft's curve on a one-second draw, (t² + 2t) / 3,
    capped at 1. A full draw flies at 55 m/s for 30 damage, with a chance
    of a critical hit up to half again; under 0.1, nothing is loosed.
  - Walking slows to under half pace while drawing. Third person closes in
    over the shoulder, and a full draw zooms a little.
  - Arrows aim at whatever is under the crosshair (the aim ray meets
    creatures' parts too, so it aims at the deer, not the ground behind
    it), fall with the planet's gravity and stick in the ground, trees and
    ruins (60 s, at most 40 about), ride in a creature they hit, in the
    very part they hit (Creatures, Hitboxes), and sink in water. One
    physics ray per step finds all of it.
    Camp folk you hit complain, and the arrow glances back off the part
    it met (a head, an arm, the torso).
  - In test, a full draw landed 103 m away after 1.9 s, and one arrow
    killed a hare.
- **The spear** (`Spear`, `ThrownSpear`; agreed at Go). Q (the pad's Y)
  swaps bow and spear (`PlanetPlayer.weapon`, `swap_weapon()`); the one
  not in hand is slung on the back. With the spear in hand:
  - a tap of the shoot button (under 0.22 s) thrusts: a 12 cm sphere cast
    2 m from the chest toward the crosshair, over the world and the
    creatures' and people's parts (Hitboxes). A creature it meets is
    hurt (25, a placeholder); a camp person complains, as for an arrow.
  - Holding raises it over the shoulder (the right arm up and back, the
    camera over the shoulder, a slow walk, no sprint); releasing throws
    it. Power follows the bow's curve over 0.8 s, 9 to 24 m/s, 45 damage
    at full. It flies much slower than an arrow, so it's thrown lofted
    (the flatter arc that comes down on the crosshair; out of reach, 45°
    toward it) and visibly arcs. It sticks where it hits, point 22 cm in:
    ground, trunk, limb, ruin, or the very part of a creature it hit,
    riding along with it. When a carcass fades, the spear drops to the
    ground where it lay. In water it splashes (`spear_kg` in
    data/water/ripples.json) and floats, riding the ripples. A throw
    doesn't touch the player's momentum.
  - There is one spear. While it's out the hand is empty (the HUD says
    "Spear (thrown)"). Within 2 m of its shaft, E takes it back into your
    hand ("E: take the spear back"): main's E lets go of a tree first,
    then picks up the spear, then turns a log, then climbs.
  - The HUD names the weapon in hand above the health meter; the raise fills
    the same arc under the crosshair as the bow's draw.
- **First person** (V, F5, the right stick click): the camera at eye
  height (1.6 m, 0.98 crouched), wider pitch, your body hidden from the
  camera (its own visual layer, with its blob shadow), and the bow
  in view, its string coming back as you draw, or the spear to the right,
  raised level over the shoulder and jabbing forward on a thrust.

## The opening encampment

`scripts/landmarks/encampment.gd`, `campfire.gd`

`Encampment.candidates()` scores every blueprint cell with the old spawn
rule (low, mild, green land ~2 km from the coast) and keeps the best 12,
at least 20 km apart; each new game picks one at random
(`World.spawn_choice` pins one). `site_near()` finds a flat, dry spot
there (off water, rivers and wetlands, level across the camp), plants
keep a 12 m clearing, and the camp is a campfire (`Campfire`, shared with
the other camps), the player's hide mat facing it, and an elder and a
hunter (sculpted bodies) across the fire on log seats, who breathe and
turn toward the player when near. Both have hitboxes and a blocker
(`CreatureHitboxes`): you can't walk through them, and an arrow glances
off them. The fire is a ring of stones and
crossed logs on a bed of glowing coals under four tongues of flame
(`shaders/flame.gdshader`): cards that turn to face the camera, drawn
additively so they build an orange-gold core (R1a #FFB020) through the
coals' orange (#FF4A00) to a deep red edge, licked and torn by grain
scrolling up, each on its own phase. The fire's light is R1a fire-light
orange (#FF7A2A, 14 m) for every camp: energy 7 at night, easing to 45%
of that in full daylight, when the sun drowns it. After dark a flat disc
5.5 m across pools firelight on the ground: drawn once multiplied, to
filter the ground under it warm (`shaders/fire_glow_warm.gdshader`), then
added in the same orange, flickering with the flames
(`shaders/fire_glow.gdshader`), since blue-green night grass under an
orange light alone goes olive, not orange. At the start
they speak once, as subtitles (`Hud.say`): "You're finally awake." /
"Be careful at night, don't let it get you...", each with a one-voice
wordless murmur from the speaker (`Encampment.talk`, 3D, heard to
~25 m). The camera opens over
the player's shoulder so the fire is in view.

## UI

- **HUD:**
  - time of day, moon phase and mansion;
  - F3: the debug overlay (see Dev settings);
  - F4, dev mode only: the collision view's legend, with shape counts
    by layer (see Landmarks);
  - biome, temperature now and on average (°C), weather, rainfall, wind,
    elevation and coordinates;
  - a context prompt;
  - `StatusHud`, drawn under the rest: the health meter (a slim blue bar
    and numeral, bottom left) with the weapon in hand above it, the
    crosshair or the middle dot with the binomial of what it rests on,
    the hits' rising numbers and the critical / kill X, the red hurt
    flash and the "You died" curtain (see Health, hits, the bow and the
    view). No creature health bars, ever.
- **Map (M):** a globe lit by the real sun, colored by biome, elevation,
  temperature, rainfall or live weather.

## Performance

Profiled headless with a fixed 1/60 s step (`--fixed-fps 60`, and the
headless frame sleep off, which otherwise pads every frame to 6.9 ms),
sprinting a fixed path, before and after:

| | before | after |
|---|---|---|
| frame, mean | 3.81 ms | 2.58 ms |
| frame, 99th percentile | 8.33 ms | 4.89 ms |
| worst frame sprinting | 20.7 ms | 8.9 ms |
| worst frame standing still | 33-51 ms | 8.5 ms |
| loading screen after a 5 km jump | 11.8 s | 5.2 s |

- **Shared shader values are global uniforms** (`[shader_globals]` in
  project settings; `Look.apply` writes each once). They used to be set
  on every registered material each frame: 139 materials, ~0.3 ms.
- **Creatures think less far away.** Ambient animals past 40 m tick every
  other frame and past 90 m every fourth, catching up the skipped time;
  anything fleeing, flying or angry stays at full rate. A still animal
  isn't moved, scaled or its legs set again, and its ground lookup is
  shared between the step check and the placement; sculpted bodies only
  set bones that moved. The creature update went from 2.5 to ~1.1 ms a
  frame with ~90 animals about.
- **Collision near the player only, in strips** (above), and ruins'
  collision only within 400 m, 2,500 faces a frame (a castle has ~18k):
  a new chunk used to cost 5-9 ms of BVH on attach, two a frame.
- **Chunk workers:** river distances no longer take the river profile's
  lock per vertex per segment (the water level is looked up only where
  it's needed), vertex colors find their planet interpolation weights
  once instead of four times, and vegetation decides most grid cells
  cheaply: the cheap site checks run before the climate bands, and a
  cell's acceptance roll is compared with the most it could be before
  every species is weighed. The draws and results are unchanged (a hash
  of 30 chunks' output, terrain and plants, matches bit for bit).
  Terrain 58 → 40 ms, vegetation 350 → 210 ms per chunk.
- **Creature hitboxes** cost the physics step ~1 µs per moving part
  as static bodies (about six times less than as kinematic ones), and
  are in the space only near the player or an arrow (Creatures,
  Hitboxes): ~0.2 ms a step in a busy scene.
- **Ruins build 3x faster** (127 → 43 ms each on a worker): a block's
  24 vertices, 6 normals and colors are worked out once instead of by
  ~300 lambda calls. Output matches bit for bit (hashed over 32 ruins).

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
- **Hitboxes** (headless, `--fixed-fps 60`):
  - Tepees: a body set up like the player (capsule 0.35 x 1.7 m, 50°
    floor limit, 0.6 m snap, walking pace, `move_and_slide`) walks from
    1.2 m outside the door to the middle and back out, then toward the
    middle from nine bearings 60-300° off the door. Tried on every
    tepee on the seed 42 and 24 stamps (8) and on 16 at the size limits
    (r 1.4-1.8 m, h 2.8-3.5 m): it gets in to within 0.1 m of the middle
    and out again, and from every other side the cover stops it 1.4-1.8
    m from the middle. Two seed-42 tepees have a drawn obstacle on the
    straight line out from the door (a fallen castle block, a fire-ring
    stone), which you walk round.
  - Lean-tos (5): a ray down over the middle of the floor meets the
    roof's collision within 1 cm of the drawn roof, and the space under
    it is free.
  - Stones, by rays from 642 directions at the drawn stone and at its
    hull: the 42-corner hull stands 1-2 cm proud at most and sinks in by
    up to 7 cm on a 1.3 m stone (the drawn bulges between its corners);
    the 162-corner hull of big stones never sinks in and bridges dips of
    up to 6 cm on a 2.5 m boulder and 14 cm on the 7.5 m slab.
  - Nothing drawn moved: an MD5 over the ruins' meshes, far LOD,
    shelters, camp spots and lights (three sites of each kind per
    stamp) is the same before and after on seeds 42, 2, 6 and 4. Only
    the collision lists changed.
  - Cost, measured on a machine shared with other jobs (load ~20), so
    these are upper bounds: a piece of 32 hulls builds in 1.3 ms on average, 5.4 ms at worst, against
    1.8-2.0 and 10.7 ms for the 2,500-face pieces. A castle has about
    50 hulls, a graveyard 32 (its mounds), a treehouse village 24 (the
    trunks). The collision view at a castle camp: 4.3 ms per refresh
    (four a second), 0.09 ms a frame moving the lines, 15 ms on the
    first press; nothing when off.
  - Rendered with F4 on, before and after, on seed 24's stamp: a tepee,
    a lean-to, a ruin boulder, a giant jungle tree, a cliff camp's fire
    and its rock shelter, and a graveyard; and a recording of the player
    walking into the tepee and out.
  - Creatures and people (seed 42 stamp, standing still, side on,
    arrows at full speed): arrows at a deer's torso middle (1.03 m up;
    the old sphere topped out at 0.88 m), head and antler, a wolf's head,
    a goblin's torso from behind and its arm from the side each stuck
    in that part, 0.01-0.09 m from the aim point. The bow's aim ray
    met the deer's torso and the real bow's arrow stuck there. Walking
    at a deer, at the opening camp's elder (from the side: behind him
    is his seat log) and at a camp guard, the player stopped 0.49-0.51 m
    from its middle. Arrows at the elder's side and head and a seated
    hunter's torso glanced back off the arm, head and torso they met.
    A deer 130 m off had all 13 bodies out of the space; an arrow from
    30 m woke them and stuck in its torso; killed, they went off. The
    Night Rider and the Pond Crawler, on the static parts, still take
    arrows in their barrel and lump.
  - Rendered with F4 on: a deer mid-stride, a wolf pack, a goblin,
    birds (heron, duck, toucan), folk at a camp, the opening camp's two;
    and a recording of an arrow sticking in a deer's flank.


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
- **Branchy trees and branch graphs** (headless, in the rainforest):
  - `chunk.trees` is in placement order (0 of 9,622 trees out of step
    with `hosts`);
  - every handhold sampled (1,427 on 25 trees, 5 of them mirrored) lies
    inside the drawn bark: four rays out across the wood from each one
    all leave through the bark within 7 cm of the wood's radius;
  - rendered, the MultiMesh transforms of 706 branchy trees match their
    records exactly (rotation, height, mirror);
  - after walking away (the chunks unload and the graphs are dropped:
    none of the 30 old keys stayed registered) and back, all 30 graphs
    come back with the same keys and handholds within 0.0000 m;
  - links all run both ways; F6 redraws in ~3.5 ms, the tree-contact
    scan takes 0.14 ms, a 75 m tree's graph 0.6 ms.
  - A mirrored and a plain copy of the same layout, side by side, light
    alike (`cull_disabled` with vertex lighting and a flat-colour
    ambient).
- **The spear and noise** (headless, on the dev stamp): Q swaps to the
  spear; a tap thrusts and hurts a deer 1.5 m in front, not one 5 m off;
  held half a second and released, the spear sticks in the deer's Torso
  part (0.1 m from the aim point) and moves 3 m with it, unmoved in the
  part's frame; E 6 m off does nothing, E beside it takes it back into
  your hand; thrown again it lands 0.2 m from the aim point in the ground
  and is picked up; stuck in a carcass that fades, it drops to the ground
  and is picked up there; into water it floats. A throw leaves `_move`
  as it was; raising ends a sprint. A missed arrow landing 3 m from a
  grazing deer makes it bolt, 12 m makes it wary, 30 m does nothing.
  Loosing, thrusting and throwing raise `noise_level` to 0.6, back under
  0.3 a second later. Recorded: swapping to the spear, throwing it into a
  deer's flank, sprinting over and taking it back.
- **Hits and health** (`tools/hits_check.gd`, headless, `--fixed-fps 60`,
  on the stamp; a fresh deer, 36.4 HP, for each arrow, loosed 2.5 m from
  the part at full speed): an arrow carrying 10 into the torso deals 10,
  not critical, and the deer flees at 7.0 m/s; into the head 20 (2x),
  critical; one carrying 5 into the right eye 20 (4x), critical, blind on
  the right only: it bolts from a quiet, still player at 4.0 m on its
  right and 13.5 m on its left; into a hind shin 10, lame 0.5, and it
  flees at 3.5 m/s (5.2 m in 1.5 s against 10.5 m). The X holds 0.10 s
  counted for a critical (0.12 s in the table; the first frame is spent
  reading the hit) and 0.38 s for a kill (0.40), in the kill color. Two
  hits on one deer in one physics frame (4 on the body, 6 on the head)
  make one number, 16, critical. An arrow into the opening camp's elder's
  head: 20, critical, a complaint, no harm. 60 s idle 60 m from any fire
  at 50 health: still 50. 20 s standing 3.3 m from the opening camp's
  fire: 50 to 77, resting 18 s at 1.50 HP/s (from 2 s still).
  `heal(heal_for("cooked_food"), "cooked_food")`: +20. Stills
  (`-- --shots`): the X and a yellow number over a head-shot deer, the
  number risen with the meter at 64, a white body-hit number.

## Known gaps and next steps

- **Hits and health (item 10).**
  - Cooked food and camp medicine don't exist yet (Phase 10): only their
    hook, `PlanetPlayer.heal()`, and their amounts in the table.
  - No sit action: resting counts standing or crouching still.
  - Camp folk and the gibbon have no health, so their numbers are what the
    hit would have dealt; nothing is harmed.
  - A limb hit doesn't know which leg: the whole gait slows and the body
    rolls toward the side the arrow came in on. Wounds never heal.
  - Mythic rigs slow when lamed (the horse's walk, the crawler's strides)
    but don't roll into a limp.
  - A number whose target is freed mid-rise goes back to where the hit
    landed; a floating-origin rebase in that second would misplace it.
  - The bow's random full-draw damage bonus is still called a "critical"
    in `Bow`; it's a damage roll, unrelated to head and eye criticals.
- **Spear and noise (Phase 1, D5).**
  - Damage numbers are placeholders (no balancing, per the card). The
    thrust and throw reuse the bow's synthesized sounds, pitched down.
  - The elf's right arm lifts to hold and throw; an imported player model
    gets no spear pose yet, only fixed hand positions.
  - A spear stuck in a creature that is freed without fading out first
    returns to the hand (a safety net), rather than dropping there.
  - Noises keep scene positions for their 8 frames; a floating-origin
    rebase inside those frames would misplace one. Packs and mythicals
    don't hear them.
  - The bow's aim ray still starts at the camera, not the over-the-shoulder
    view centre (0.55 m to its right while drawing); the spear's does.

- **Branchy trees and branch graphs (Phase 1 (i)).**
  - Climbing still uses the old trunk climb (`PlanetPlayer`, radius from
    `tree_dims`); climbing and the monkey are built on the graphs
    separately.
  - Graphs and limb colliders exist only within 60 m of the player;
    farther crowns have trunk colliders only, so arrows pass through
    distant limbs.
  - Conifers get trunk-only graphs up to where the lowest cone hides the
    trunk (0.3 of the height); palms their stem; bamboo, cacti and
    rosettes none.
  - Leaf clumps sway and branches don't: in a gale (the shader's full
    0.8 m lean) a small tree's clump can slide off its branch tip.
  - A mirrored tree is a negative-scale MultiMesh instance. It lights
    correctly because the foliage material is `cull_disabled`,
    vertex-lit and has a flat-colour ambient; per-pixel lighting or sky
    ambient there would need a normal flip for mirrored instances.
  - Stacked cylinders are sized to the wood halfway along each one, so
    at the thin end of a tapering piece they stand up to ~6% proud of
    the bark.
  - Each branchy species keeps its 12 layout meshes (6 hero, 6 near;
    ~3.5 MB of arrays) once it has appeared.
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
  GPU's. The compatibility renderer gets the same look and only needs
  not to break.
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
- **Hitboxes, rough edges.**
  - With the 50° floor limit and no step-up, a walking player can't get
    over anything much above 12 cm with steep sides. Fire-ring stones
    (18-22 cm) and small rubble stop you: you go round or jump.
  - A tepee's collision leaves its door at least 0.9 m wide, so near
    head height up to ~20 cm of drawn hide beside the door can be walked
    through (the body is slimmer than the capsule, so it barely shows).
  - Hulls bridge a boulder's dips (up to 14 cm on a rock shelter's
    slab). A grave mound's hull stands ~8 cm out at its foot and ~7 cm
    inside its top edge.
  - A bow laid by a seat doesn't collide.
  - Creatures' parts are fixed shapes on rigid pivots: a sculpted body's
    skin that bends across a joint can bulge a centimeter or two past
    them, and a primitive body is fitted with its biggest pieces only (a
    unicorn keeps two of its five mane tufts). Ears, tails of small
    animals and beaks are often left out.
  - Past 90 m a creature's parts wake only when an arrow comes within
    25 m, so the bow's aim ray doesn't see a far animal: it aims at the
    ground behind it (at that range the drop matters more).
  - The blockers are on the world's layer, so the third-person camera's
    spring arm pulls in when a deer walks between it and the player.
  - In dense ruins the collision view is busy: lines behind walls show
    through, and a ruin's triangle piece (2,500 faces, often spread
    over much of the ruin) is drawn whole once any part of it is within
    40 m, fading out past 30 m.
- **Storm fakes.** Rain doesn't collide with crowns; under cover the
  falling rain thins instead. Thunder's distance is made up per strike
  (there is no bolt; the sound is placed at that made-up spot), and
  flooding is visual only.
- **NPCs** speak their opening lines once and otherwise only watch you;
  there's no dialogue or behavior beyond that yet.
- **Frame cost of the movement/storm batch** (headless, main thread, the
  same 30 s run at the same speed): 4.1-4.2 → 4.5 ms on average, 6.5 →
  6.7-6.9 ms at the 95th percentile, nearly all from the trunk colliders
  (building them as chunks enter the detail ring, and the player
  colliding with them); the contact scan, footsteps and shelter checks
  are each under 0.02 ms.
- **Ripples.** Dropped items and falling leaves don't exist yet, so
  nothing calls `Ripples.splash()` for them; the call is ready. Rings
  don't reflect off banks (they run on under the ground and are hidden)
  and a river's current doesn't carry them downstream. Beyond the 64 m
  window, and past 40 m from the camera, water doesn't ring at all and
  the readers get 0 there. Rain is kept sparse (0.05 drops per m² a
  second): denser, the rings merge into blotches; even so, round a
  player wading in rain the overlapping rings read more as broad
  blotches than as rings. Creatures' contacts were checked headless (a
  heron wading at 0.6 m/s drags a wake from each leg and splashes every
  half stride, a swimming duck drags one from its hull) but not filmed:
  ground animals don't choose to walk through water. Costs were measured
  on a software renderer only.
- **Waterfalls** have no sound yet, and the fine terrain grid (4 m) can't
  make a truly vertical cliff, so the gorge wall under a tall fall is a
  steep ramp.
- **Foliage wind.** One wind vector (the local weather at the player)
  sways every plant in view. That's right at walking scale, but plants a
  few kilometers off don't feel their own local wind.
- **Weather grid.** The live grid is coarse (~10 km cells); breezes,
  gusts and showers are local detail added at the player, not simulated
  across the planet.

