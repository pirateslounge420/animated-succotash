# Low-Poly Exploration Prototype

An ambient open-world exploration game in a smooth-shaded GameCube style,
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
loading screen), then you wake by a campfire in a small tribal camp on a
temperate or tropical coast (a different one each game).

| Key | Action |
|---|---|
| WASD / arrows, left stick | Walk (6 km/h) |
| W twice and hold, left stick click | Sprint, while forward stays held (loud: wildlife notices you sooner) |
| Shift, B | Crouch (hold): slow and nearly silent |
| Space, A | Jump (hold to keep jumping); hold to swim up |
| Mouse, right stick | Look (click the window to capture the mouse, Esc frees it) |
| Left mouse (hold, release), right trigger | Draw the bow and loose an arrow: the longer you hold (up to a second), the farther and harder it flies |
| V or F5, right stick click | First / third person |
| E, X | Turn over a fallen log; else climb the tree in front of you (W/S up and down, A/D around the trunk, E or Space to let go) |
| M, Back | Planet map (keys 1-5 switch biome / elevation / °C / rainfall / live weather; drag to turn, wheel to zoom) |
| H | Hide the HUD |

One in-game day is **120 real minutes** (12x faster than Earth), in four
phases: dawn 15 minutes, day 50, dusk 15, night 40. The planet has no
axial tilt (no seasons yet); toward the poles the sun crosses the horizon
at a shallower angle, so dawn and dusk last longer there.
Temperatures everywhere (HUD, map, data files) are in **°C**.

## How the world is built

Only the planet's coarse ~1 km **blueprint** is built for the whole
planet at once, because the weather and rivers need it: terrain, oceans,
lakes and rivers, a running weather simulation, climate averages, rock
types, and one of the 51 biome templates per cell. Everything you can walk
on, see up close or meet is **spawned around you** and dropped as you
move on:

- terrain chunks (~260 m, smooth shaded; 4 m quads near you, 8 m beyond)
  within ~800 m, with rivers that pour over waterfalls in the mountains;
- trees on those chunks (mossy and vine-hung where it's wet), undergrowth
  only within ~400 m;
- a coarse far shell draws distant mountains and sea;
- wildlife within ~140 m, wolf packs near their dens, mythical creatures
  heard from ~1 km and seen from ~220 m;
- ruins (crumbling towers, castles on hills, aqueducts, and now and then
  a pyramid) from ~2.6 km,
  so their silhouettes rise out of the fog before you reach them; about
  a third hold a survivors' camp of tepees and lean-tos. At night they,
  some lakes and wetlands, and mythical territories glow teal and cobalt.

Wildlife hears you: crouched you can creep close, sprinting sends it
running from far off, and a startled animal calms down if you keep still.
Trees block your way and can be climbed; their crowns (and camp
shelters) keep the rain off. Storms bring lightning and thunder, and
heavy rain swells the rivers.

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
  landmarks/               Ruins (towers, castles, aqueducts) and the
                           glowing places of the bioluminescent night
  player/                  Third-person explorer with planet gravity
  ui/                      HUD, planet map, night post-grade
shaders/                   Sky, water, terrain, foliage, far terrain, ruins,
                           grade; look.gdshaderinc holds the shared banded
                           fog, mist and glow
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
