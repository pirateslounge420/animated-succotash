# Low-Poly Exploration Prototype

An ambient open-world exploration game in a GameCube-era low-poly style,
set on a walkable, procedurally generated cube-sphere planet about 400 km
around, at a tribal, pre-firearm tech level. No combat and no quests: you
wander, watch the weather roll in, and find what lives where.

- [`DESIGN.md`](./DESIGN.md) is the design spec.
- [`docs/implementation-notes.md`](./docs/implementation-notes.md) explains
  how the code implements it, file by file, and what's still missing.
- [`data/biomes/README.md`](./data/biomes/README.md): how to add plants.
- [`data/creatures/README.md`](./data/creatures/README.md): how to add
  creatures.

## Engine

**Godot 4.3+** (GDScript only, no plugins). Open the repo root
(`project.godot`) in the Godot editor or in **Summer Engine** and press
Play. The main scene is `scenes/main.tscn`.

## Playing

The planet is generated when the game starts (about 6-8 seconds behind a
loading screen), then you're dropped on a temperate or tropical coast.

| Key | Action |
|---|---|
| WASD / arrows, left stick | Walk (4.5 km/h, the spec's walking pace) |
| Shift, B | Run |
| Ctrl | Fast travel (60 m/s, for testing) |
| Space, A | Jump; hold to swim up |
| Mouse, right stick | Look (click the window to capture the mouse, Esc frees it) |
| E, X | Inspect: turn over a fallen log |
| M, Back | Planet map (keys 1-5 switch biome / elevation / °C / rainfall / live weather; drag to turn, wheel to zoom) |
| H | Hide the HUD |
| `]` / `[` | Speed time up / slow it down (x4 steps, up to x256) |

One in-game day is **48 real minutes**. Twilight counts as day, as on
Earth, so at the equator the lit part runs about 25 minutes and the night
about 23. The planet has no axial tilt (no seasons yet); toward the poles
the sun crosses the horizon at a shallower angle, so twilight lasts longer.
Temperatures everywhere (HUD, map, data files) are in **°C**.

## How the world is built

Only the planet's coarse ~1 km **blueprint** is built for the whole
planet at once, because the weather and rivers need it: terrain, oceans,
lakes and rivers, a running weather simulation, climate averages, rock
types, and one of the 51 biome templates per cell. Everything you can walk
on, see up close or meet is **spawned around you** and dropped as you
move on:

- terrain chunks (~260 m, flat-shaded 8 m quads) within ~800 m;
- trees on those chunks, undergrowth only within ~400 m;
- a coarse far shell draws distant mountains and sea;
- wildlife within ~140 m, wolf packs near their dens, mythical creatures
  heard from ~1 km and seen from ~220 m.

The floating origin keeps the player near (0,0,0), so precision holds
anywhere on the planet.

## Project structure

```
project.godot              Project file; World autoload, main scene
DESIGN.md                  Design spec
docs/implementation-notes.md
scenes/main.tscn           Game entry point
data/
  biomes/                  51 biome files: plant lists per biome (edit these)
  creatures/creatures.json Creature species (edit this)
scripts/
  core/                    World autoload (planet, clock, weather, floating
                           origin), main orchestrator, input actions
  planet/                  Cube-sphere math, terrain field, blueprint data,
                           generator and its passes
  weather/                 Weather simulation; rain/snow/wind effects
  biomes/                  The 51 biome templates (names, colors, sizes)
  sky/                     Sun, Earth-like moon, 28 lunar mansions, sky
  terrain/                 Chunk streaming, rivers, far shell
  ecology/                 Plant species, placement rules, meshes
  creatures/               Creature species, spawner, territories, bodies,
                           synthesized sounds
  player/                  Third-person explorer with planet gravity
  ui/                      HUD, planet map, night post-grade
shaders/                   Sky, water, terrain, foliage, far terrain, grade
assets/                    Empty placeholders for models/textures/audio
```

## Adding content

- **Plants:** add entries to a biome file in `data/biomes/`. A name is
  enough; the plant then grows anywhere on the planet whose climate
  matches that biome's. See `data/biomes/README.md` for size, shape,
  color, soil and special needs.
- **Creatures:** add entries to `data/creatures/creatures.json`: habitat
  role, climate range, density, activity time, needs, looks and sound.
  See `data/creatures/README.md`.
- **Biomes:** there are 51 template slots (50 surface + caves) matching
  DESIGN.md. Many biome files are still `placeholder` or `empty`; their
  status field says which.
