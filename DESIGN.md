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

## 3. World & Procedural Generation

Minecraft-style **chunked procedural generation**: the world streams in
around the player in fixed-size chunks, generated from layered noise
(heightmap, moisture, temperature) rather than hand-authored terrain.

### 3.1 Biomes (initial set)

| Biome | Terrain character | Tribal presence hook |
|---|---|---|
| Forest | Rolling hills, dense canopy, clearings | Tribes living **in the canopy** (rope bridges, platform villages) |
| Mountains | Sharp elevation, cliffs, alpine plateaus | Tribes carved **into the mountain** (terraced dwellings, cave-mouth entries) |
| Desert | Dunes, mesas, sparse oases | Nomadic camps, sunken ruins half-buried in sand |
| Ocean/Coast | Beaches, reefs, cliffs, sea caves | Tribes **behind waterfalls**, stilt villages over shallow water |
| Plains | Open grassland, scattered groves | Semi-nomadic hunter camps, stone circles, migratory herds |
| Snow Tundra | Frozen flats, ice formations, aurora skies at night | Sheltered enclaves in ice caves or wind-break ravines |
| Swamp | Wetlands, mangroves, fog, bioluminescent flora | Stilt-and-vine villages, hidden bog shrines |

Biomes blend at their borders via noise-based interpolation (height,
vegetation density, and palette all cross-fade) rather than hard edges, in
the spirit of Minecraft's biome blending but tuned for a hand-painted look.

### 3.2 Points of Interest

Discoverable locations are the primary "content" of ambient exploration.
Design principle: **every POI should be visible or hinted at from a
distance (smoke, sound, light, silhouette) but require actual traversal
effort to reach** (climbing, swimming, finding a hidden path).

Examples called out by the concept: canopy tribes, waterfall-hidden tribes,
cave-dwelling tribes, mountain tribes. Extend this pattern to each biome
(see table above) rather than clustering all POIs in one biome type.

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
  - Dusk: warm oranges/reds, long shadows, rim-lighting on silhouettes.
  - Night: cool blue/violet ambient, low-key, stars/moon visible, biome
    accent lighting (bioluminescence in swamp, aurora in tundra, tribal
    fires everywhere) becomes a primary light source.
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

## 7. Out of Scope (this prototype phase)

- Combat systems, guns/heavy armor (excluded by setting, not just
  unimplemented).
- Multiplayer/networking.
- Full biome roster beyond the seven listed in §3.1.
- Final art assets — prototype uses greybox/primitive geometry first.

## 8. Roadmap (suggested next milestones)

1. Repo/project scaffold (this pass).
2. `TimeOfDay` autoload + basic sky/lighting gradient driven by it.
3. Single-biome chunked terrain (start with Plains or Forest) with
   noise-based heightmap.
4. Third-person character controller (ambient movement: walk/run/climb/swim).
5. Biome blending — add a second and third biome, tune transitions.
6. First discoverable POI (e.g. a canopy village) as a hand-placed
   prototype before POIs are procedurally scattered.
