# Design Document — [Working Title]

An open-world, ambient-exploration, third-person game set in a low-polygon
world of primal high fantasy. Built in Godot 4.x, developed collaboratively
with Claude (and, on the desktop side, Summer Engine's Claude-native
workflow).

## 1. Core Pillars

1. **Ambient exploration over objectives.** The world rewards wandering.
   There is no HUD-driven quest funnel — discovery is its own payoff.
2. **Primal high fantasy.** Tribal, hunter-gatherer societies. No guns, no
   heavy armor, no gunpowder-era or industrial-age technology. Stone, wood,
   bone, hide, fire, and early metalwork at most.
3. **Low-poly, high-readability art.** Geometry stays simple; mood is
   carried by lighting, color, and silhouette rather than surface detail.
4. **A living, cyclical world.** Procedural biomes and a full day/night
   cycle make the world feel like it continues without the player.

## 2. Art Style

Primary references: **Super Smash Bros. Melee** (GameCube-era character
proportions and clean shading), **Phantasy Star Online Ep. I & II**
(painterly skyboxes, ruin/nature blending, ambient sound-driven mood),
**F-Zero GX** (bold, saturated lighting and strong silhouette design despite
low geometry budgets).

Guidelines:

- **Geometry:** low vertex counts, flat or lightly beveled faces, no
  high-frequency surface noise. Nature assets (trees, rocks) built from a
  small number of reusable low-poly modules.
- **Shading:** baked/vertex lighting feel — soft flat shading over PBR
  roughness maps. Avoid modern PBR realism; favor GameCube-era toon-lit
  gradients.
- **Color:** biome-driven palettes, saturated but not neon. Strong
  time-of-day color grading does most of the "wow" work (see §4).
- **Texture budget:** small, tiling, low-resolution textures (64–256px) or
  vertex-color-only surfaces where possible, to keep the GameCube-era
  reference honest and keep asset production fast.
- **Silhouette first:** every creature, tribe structure, and landmark should
  read at a glance from a distance, the way F-Zero GX tracks and PSO ruins
  do.

### 2.1 Mood Reference (Night)

Moodboard reference (fan-rendered fantasy night scenes, not owned assets —
described here rather than embedded) pins down the night-time target from
§4 concretely:

- **Palette:** deep blue-violet ambient/moonlight dominates; a single warm
  light source (campfire, glowing window, lit doorway) provides near-total
  color contrast against it rather than a broad warm fill.
- **Moon:** rendered large and graphic in the sky — a mood element, not a
  realistically-scaled disc.
- **Silhouettes:** pine forests, jagged peaks, and ruin architecture read
  as near-black shapes against the blue sky; detail lives in the rim
  light, not the shadow side.
- **Accent glow:** POI light sources (windows, water, fungal/bioluminescent
  flora) should match the cool ambient hue rather than reading as warm,
  reserving warm light specifically for fire/hearth — this is what should
  make campfires and tribal hearths pop as the "welcome" signal from a
  distance at night.
- **Stars & moon:** a dense, visible star field at night, with the moon
  (full or crescent) always rendered oversized/graphic per the point
  above — both read as deliberate sky design, not realism.

**Scope note:** several moodboard sources pull from a general dark-fantasy
aesthetic that includes castles and plate-armored knights. Those are
**excluded by §1.2** (no heavy armor, primal/tribal only) — only the
lighting, color, and atmosphere from such shots apply here, never the
architecture or character content. Don't reintroduce castle/knight
content from future reference images without an explicit setting change.

## 3. World & Procedural Generation

Minecraft-style **chunked procedural generation**: the world streams in
around the player in fixed-size chunks, generated from layered noise
(heightmap, moisture, temperature) rather than hand-authored terrain.

### 3.1 Biomes

Biome comes from height, temperature, and moisture together (§3.5), not
a single axis. Two groups:

**Lowland / climate table** (temperature × moisture, Whittaker-style):

| Biome | Terrain character | Tribal presence hook |
|---|---|---|
| Forest | Rolling hills, temperate woodland, clearings | Tribes living **in the canopy** (rope bridges, platform villages) |
| Jungle | Dense hot/wet rainforest, thick canopy | Deep-canopy tribes, more vertically layered than temperate Forest |
| Savanna | Warm grassland, scattered trees | Semi-nomadic hunter camps, stone circles, migratory herds |
| Prairie | Cooler/temperate open grassland | Semi-nomadic camps, similar to Savanna but cold-tolerant herds |
| Desert | Dunes, mesas, sparse oases | Nomadic camps, sunken ruins half-buried in sand |
| Swamp | Hot, very wet wetland, mangroves, bioluminescent flora | Stilt-and-vine villages, hidden shrines |
| Marsh | Temperate, very wet wetland, reedy/open (freshwater-adjacent) | Reed-boat camps, fishing platforms |
| Bog | Cold, very wet wetland, peat/moss | Sparse, isolated dwellings on drier hummocks |

**Altitude zonation** (elevated land, keyed on temperature so a polar
mountain snows over at a lower absolute height than an equatorial one —
see §3.5): climbing from the base, a windward/moist mountain runs
**base Forest/Jungle → Cloud Forest → Dwarf Forest → Mountains (bare
alpine rock) → Snow Tundra (cap)**. A leeward/dry mountain skips Cloud
Forest and goes straight from its (often Desert) base to Dwarf Forest,
matching the rain-shadow behavior in §3.5.

| Biome | Terrain character | Tribal presence hook |
|---|---|---|
| Cloud Forest | Moist montane forest, persistent mist, moss/epiphytes | Mist-shrouded tribes, hard to spot until close |
| Dwarf Forest | Sparse, wind-stunted subalpine/treeline forest | Small, hardy enclaves; more shelter than settlement |
| Mountains | Bare rock, cliffs, alpine plateaus, above the treeline | Tribes carved **into the mountain** (terraced dwellings, cave-mouth entries) |
| Snow Tundra | Frozen flats (polar) or permanent snow cap (high alpine) | Sheltered enclaves in ice caves or wind-break ravines |

**Water and coast:**

| Biome | Notes |
|---|---|
| Ocean | Salt water. |
| Lake | Fresh water (enclosed basin — see §3.5's flood-fill). |
| Beach | Low-elevation strip specifically adjacent to Ocean (salt water), not any water body. |

Rivers are fresh water too, but aren't a biome of their own — see §3.2.

**Caves** are a structural/subsurface POI feature (§3.3: "cave-dwelling
tribes"), not a surface biome — they can appear within Mountains or any
other biome and aren't part of this height/temperature/moisture lookup.

Biomes blend at their borders via noise-based interpolation (height,
vegetation density, and palette all cross-fade) rather than hard edges, in
the spirit of Minecraft's biome blending but tuned for a hand-painted look.
The current implementation (§3.5) assigns one discrete biome ID per cell;
smoothstepped cross-fading at borders is still open (roadmap item 8).

### 3.2 Rivers

Rivers are a terrain-carving feature layered on top of a biome's base
heightmap, not a biome of their own — this is what gives the "nice
gradient" between dry land and water rather than a hard trench:

- A **river mask** (0 = dry land, 1 = river centerline) is computed per
  vertex, independent of the height noise, and smoothed with `smoothstep`
  across a configurable band width so banks slope rather than cliff.
- Final height = `lerp(land_height, riverbed_height, river_mask)`, where
  `riverbed_height` sits below the world's fixed `water_level`.
- A single flat water plane is placed at `water_level` per chunk; it's
  invisible under normal land (terrain sits above it) and only becomes
  visible where the carved riverbed dips below it — no per-river custom
  geometry needed for the water surface itself.
- **Navigability:** any river segment wide/deep enough (mask above a
  navigability threshold) supports boat travel. Boats use simple,
  Minecraft-esque physics — not real fluid/buoyancy simulation: the boat
  is height-locked to the water surface, accelerates from paddle input,
  drifts along a per-segment current-direction vector, and collides with
  the banks. See `scripts/world/boat.gd`.
- This same mask/blend approach is the template for biome-to-biome
  blending in general (§3.1): a continuous weight per biome pair,
  smoothstepped across a border band, rather than a hard biome ID lookup
  per vertex.

### 3.3 Points of Interest

Discoverable locations are the primary "content" of ambient exploration.
Design principle: **every POI should be visible or hinted at from a
distance (smoke, sound, light, silhouette) but require actual traversal
effort to reach** (climbing, swimming, finding a hidden path). A visible
path, treeline break, or worn stone trail leading off toward a
fog-shrouded landmark is the standard "lure" — the player follows the
line before they know what's at the end of it.

Examples called out by the concept: canopy tribes, waterfall-hidden tribes,
cave-dwelling tribes, mountain tribes. Extend this pattern to each biome
(see table above) rather than clustering all POIs in one biome type.

Concrete architectural language per biome (moodboard-derived, see §2.1):

- **Forest:** bulbous, organic hut clusters (mushroom-cap roofs read well
  at low-poly) connected by simple wooden plank bridges at ground level or
  in the canopy.
- **Swamp:** structures on stilts above the waterline, reached via a raised
  wooden boardwalk that threads through reeds/fog — the approach itself is
  the traversal beat, not just the destination.
- **Waterfall POIs (coastal/mountain):** water falling through worn,
  moss-covered stone/ruin architecture (ties back to the PSO ruin
  reference in §2); the waterfall and pool glow as the site's light
  source at night.

### 3.4 Rivers as Traversal, Not Just Scenery

The river system in §3.2 doubles as a POI delivery mechanism: a
navigable river is a natural through-line the player can follow by boat,
so waterfall- and stilt-village POIs should bias toward spawning along or
just off river/coastline paths rather than being purely landlocked.

### 3.5 Implementation: The Generation Pipeline

The world-gen core (as opposed to the single hand-tuned Plains+river
chunk built earlier) is a seed-driven, ordered pass pipeline: **every
value is derived, nothing is hand-placed**, and each pass reads only the
outputs of the passes before it. Entry point:
`scripts/procgen/world_map_generator.gd` (`WorldMapGenerator.generate()`),
which runs, in order:

1. **Height** — `scripts/procgen/passes/heightmap_pass.gd`. Layered
   noise: a low-frequency layer shapes continents/oceans, a
   ridged-fractal layer adds mountain ridges on top (masked so ridges
   only appear where the continent is already high), plus a small detail
   layer.
2. **Water** — `scripts/procgen/passes/water_pass.gd`. Flood-fills
   below-sea-level cells reachable from the map border as ocean;
   below-sea-level cells *not* reachable from the border (enclosed
   basins) become lakes. Rivers trace via steepest-descent from
   high-elevation source cells until they reach the sea/a lake or hit a
   local minimum.
3. **Temperature** — `scripts/procgen/passes/temperature_pass.gd`.
   Latitude band (distance from the map's equator row) minus a
   height-based lapse rate, normalized 0–1.
4. **Moisture** — `scripts/procgen/passes/moisture_pass.gd`. Two
   components multiplied together: (a) distance-decay from every water
   cell (multi-source BFS), and (b) a rain-shadow factor from marching
   along a prevailing wind direction per row, tracking the tallest ridge
   crossed so far — cells past a ridge (leeward) get shadowed, cells
   still climbing toward one (windward) don't. `fog_chance` is derived
   from moisture weighted by that same shadow factor, so fog is likelier
   on the moist windward side than in a rain shadow. Verified: windward
   cells average ~68% higher moisture than their leeward counterparts
   across the same ridges.
5. **Biome** — `scripts/procgen/passes/biome_pass.gd`. Water cells become
   Ocean/Lake directly (salt/fresh, per §3.1); low ocean-adjacent land
   becomes Beach; elevated land (height >= a mountain-base threshold)
   goes through an altitude ladder keyed on *temperature* (not raw
   height) — snow cap, then bare alpine rock, then dwarf/subalpine
   forest, then Cloud Forest if moist enough at that band (else it stays
   Dwarf Forest, which is how a leeward/rain-shadowed mountain skips
   Cloud Forest entirely) — and falls through to the same lowland
   Whittaker table everything else uses once it's warm enough at that
   elevation to be "the mountain's base." Keying the ladder on
   temperature rather than height means a polar mountain hits its snow
   line at a lower physical height than an equatorial one, for free,
   since TemperaturePass already folds latitude into that value.
   Verified directly: a moist (windward) mountain's synthetic hot→cold
   sweep produces Jungle → Forest → Cloud Forest → Dwarf Forest →
   Mountains → Snow Tundra in order; the same sweep at low moisture
   (leeward) produces Desert → Dwarf Forest → Mountains → Snow Tundra,
   skipping Cloud Forest as intended.
6. **Foliage** — `scripts/procgen/passes/foliage_pass.gd` +
   `scripts/procgen/foliage_type.gd`. Each `FoliageType` resource
   declares its own temperature/moisture tolerance range independently
   of the biome table (not a biome lookup — a plant just checks whether
   the local climate is in its range), plus a per-cell spawn-chance
   density; `scripts/procgen/default_foliage_types.gd` has six example
   types spanning the climate space.

`scripts/world/world_map_view.gd` is the validation renderer: a single
vertex-colored greybox mesh over the whole generated region (no chunk
streaming yet — that's roadmap item 6), with a runtime toggle (keys 1–5)
between coloring by biome, height, temperature, moisture, or fog chance,
plus `MultiMeshInstance3D` placeholder markers (colored boxes, not real
models) for foliage spawns. `scenes/world/world_map_demo.tscn` is the
scene to open/run to see it; `scripts/world/debug_fly_camera.gd` gives a
free-fly inspection camera (right-click to look, WASD to move).

## 4. Day/Night Cycle

- **Full cycle length:** 120 in-game minutes (real time), i.e. 2 hours.
- **Day:** 70 minutes.
- **Night:** 50 minutes.
- **Dawn/Dusk:** not separate fixed phases — they are the *gradient
  transition* between day and night lighting states, so the color/light
  interpolation itself is the transition period (sun angle driven). Target
  a visually distinct golden-hour window of roughly 8–10 real-time minutes
  on each transition for the ambient mood shift to read clearly.
- **Lighting targets:**
  - Day: bright, saturated, high-key, minimal fog.
  - Dusk: a vertical sky gradient band — cool blue at the zenith, through
    violet/purple at mid-sky, down to warm orange/red hugging the horizon
    — with long shadows and rim-lighting on silhouettes.
  - Night: cool blue/violet ambient, low-key, stars/moon visible (moon
    rendered large/graphic rather than realistically scaled). Biome accent
    lighting (bioluminescence in swamp, aurora in tundra) should read
    *cool*, matching the ambient hue; warm light is reserved for
    fire/hearths specifically, so a campfire or lit tribal window pops as
    a clear "warmth/shelter" signal against the cold world rather than
    blending into general ambient glow. See §2.1 for the full reference.
  - Dawn: cool-to-warm inverse of dusk.
- Implementation should drive a single normalized `time_of_day` value
  (0.0–1.0 over the 120-minute cycle) that feeds sun/moon rotation, sky
  gradient, fog color, and ambient light color — not separate hardcoded
  lighting states.

## 5. Setting & Tone

High fantasy at a **primal/tribal technology level**: hunting, gathering,
early agriculture, oral tradition, animism/spirit-based belief implied by
environmental storytelling (totems, shrines, ritual sites) rather than
exposition. No firearms, no plate armor — furs, woven fiber, bone/wood
tools, and stone or early bronze at the most advanced.

## 6. Technical Architecture (Godot 4.x)

- **Engine:** Godot 4.x, 3D (Forward+ or Mobile renderer — evaluate for
  low-poly performance vs. visual target once art pipeline is running).
- **World streaming:** chunk-based, loaded/unloaded around the player using
  a grid of chunk coordinates; each chunk owns its own terrain mesh +
  scatter (vegetation, rocks, POIs).
- **Terrain generation:** layered `FastNoiseLite` (or custom noise stack)
  for heightmap, moisture, and temperature maps; biome selection derives
  from moisture/temperature lookup (Whittaker-diagram style), height from
  the heightmap, blended at borders.
- **Time system:** a single autoload (`TimeOfDay`) driving the normalized
  day/night clock described in §4, broadcast via signal so sky, lighting,
  and gameplay systems can react without polling.
- **Camera/controller:** third-person, ambient/exploration-focused (no
  target-lock combat camera needed for this prototype phase).

## 7. Platform & Distribution

- **Target:** Steam (Windows/Mac/Linux via Godot's native export
  templates). No mobile/console target for this prototype phase.
- Steamworks integration (achievements, cloud saves, rich presence) is
  explicitly **out of scope** until the prototype phase is done — don't
  couple gameplay code to a Steamworks SDK/GodotSteam wrapper yet.
- Desktop-first render settings (MSAA, Forward+ renderer) are already the
  default in `project.godot`; revisit only if a Steam Deck target is
  confirmed later (would push toward the Mobile renderer or tighter
  shadow/MSAA budgets).

## 8. Out of Scope (this prototype phase)

- Combat systems, guns/heavy armor (excluded by setting, not just
  unimplemented).
- Multiplayer/networking.
- Full biome roster beyond the seven listed in §3.1.
- Final art assets — prototype uses greybox/primitive geometry first.
- Realistic water/fluid simulation — rivers use the simplified
  height-locked boat physics in §3.2, not a physics-based fluid sim.
- Steamworks SDK integration (see §7).

## 9. Roadmap (suggested next milestones)

1. Repo/project scaffold. ✅
2. Plains biome, single chunk: noise heightmap + carved navigable river
   with smooth (gradient) banks, per §3.2. ✅
3. Boat entity with simple height-locked/current-driven physics. ✅
4. `TimeOfDay` autoload + basic sky/lighting gradient driven by it. ✅
5. Core world-generation pipeline — height/water/temperature/moisture/
   biome/foliage passes and the validation renderer, per §3.5. ✅
6. Third-person character controller (ambient movement: walk/run/climb/swim).
7. Chunk streaming — replace the single demo region in §3.5 with a grid
   that loads/unloads around the player, each chunk querying the same
   `WorldMapGenerator` passes rather than its own noise (this also
   retires the standalone Plains+river prototype from item 2, folding
   river generation into `WaterPass`).
8. Biome blending — BiomePass currently assigns one discrete biome ID
   per cell; add smoothstep cross-fading at biome borders (height,
   vegetation density, palette), same technique as the river's
   `river_mask` in §3.2.
9. First discoverable POI (e.g. a canopy village) as a hand-placed
   prototype before POIs are procedurally scattered.
