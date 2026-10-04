# animated-succotash — an ambient open world

> **Start with [`CLAUDE.md`](./CLAUDE.md), the brief.** The current design is
> [`docs/design/RECONCILIATION_2026-09-30.md`](./docs/design/RECONCILIATION_2026-09-30.md)
> (the ambient cut, §AT onward; it wins over the 27 Sept doc). The look is in
> [`docs/design/LOOK_REFERENCE.md`](./docs/design/LOOK_REFERENCE.md), and who owns what is in
> [`docs/WORKING_AGREEMENT.md`](./docs/WORKING_AGREEMENT.md). The shareable summary is
> [`docs/OVERVIEW.md`](./docs/OVERVIEW.md), and how to play is in
> [`docs/HOW_TO_RUN.md`](./docs/HOW_TO_RUN.md). They override this README.

A slow, first-person walk across a procedural cube-sphere planet: **400 km around, one
one hundredth of Earth**, with heights and time at 1/10. Old, overgrown roads lead between
ruins and living camps. You wake with nothing; the torch is the first tool, and fire is
carried, never made. What lurks in the dark is the only enemy, and every ruin is designed to go down into
the dark (§CJ, not built yet). There's no crafting: the camps' makers work what you bring. You
wander, watch the weather roll in, find what lives where, and get back to a fire before
night. The look is early-2000s console 3D (1999–2004),
pixelated and saturated. The momentum movement and the bow-and-spear combat have moved to a
separate ninja game. Their code stays here, switched off (`data/movement.json` →
`profile`); the bow and spear code stays live for when they turn up as finds.

## Engine

**Godot 4.3**, the standard build: GDScript only, no plugins. Open `project.godot` in the
Godot editor and press Play (F5). The main scene is `scenes/main.tscn`. The step-by-step
guide, with download links, is [`docs/HOW_TO_RUN.md`](./docs/HOW_TO_RUN.md).

## Playing

The game boots into the last world you played. Settings (O) → World → New world rolls a new
one with its own seed and its own kind of first camp, and the seed is the world's name. You
wake in the afternoon beside a road, at a camp (design §CY moves this to dawn; not built yet).
**The keys and everything you can do are in `docs/HOW_TO_RUN.md`**, which Claude Code keeps
true to the game as built.

One in-game day is **144 real minutes**, exactly one tenth of a real day, so the whole
calendar runs at 10× and a game hour is 6 real minutes. The planet has an **axial tilt of
23.5°**, so day and night lengths come from latitude and the day of the year (with true polar
night and midnight sun). The equator-at-equinox reference is 60 / 18 / 48 / 18 real minutes
of day / dusk / night / dawn. A year is 365 game days (36.5 real days) with four seasons, and
the moon's cycle is 29.5 days. The numbers are in `data/sky/day_cycle.json`, the reference
maths in `tools/reference/daylight_reference.py`, and the design in
`docs/design/RECONCILIATION_2026-09-27.md` §F. Temperatures everywhere are in **°C**.

**Dev settings.** `data/dev.json` holds them:
- **`dev_mode`** turns on the dev keys.
- **`seed` and `spawn_choice`** are the dev tools' pins. They apply in play only with
  `pin_in_play` true or `DEV_PIN=1` (§CB).
- **`postage_stamp`** is false, so play runs on the full planet. The 40 km postage stamp (every
  climate band a short walk apart, the same rules with the geography shrunk) is for the
  headless checks, which turn it on with `STAMP=1`.

## How the world is built

Only the planet's coarse **blueprint** is built for the whole planet at once, because the
weather and the rivers need it. It is 96 cells along each cube face: about 1 km a cell on the
400 km map the geography is laid out on, and about 10 km on the 4,000 km planet, which is that
map built ten times wider. The blueprint holds:
- terrain, oceans, lakes and rivers;
- a running weather simulation and climate averages;
- rock and soil;
- one of the biome templates per cell.

Everything you can walk on, see up close or meet is **spawned around you** and dropped as you
move on:
- terrain chunks of about 260 m, out to the render distance you set (Settings → Display);
- plants on those chunks, with distant trees drawn as flat pictures;
- the old road network;
- camps, ruins and creatures;
- a coarse far shell for the distant mountains and sea.

The floating origin keeps the player near (0,0,0), so precision holds anywhere on the planet.
File-by-file detail and the numbers are in
[`docs/implementation-notes.md`](./docs/implementation-notes.md).

## Project structure

```
project.godot              Project file; World autoload, main scene
CLAUDE.md                  The brief: read first
DESIGN.md                  The original design spec (superseded in part; see its banner)
docs/
  design/                  The locked design (RECONCILIATION_*), the look reference,
                           the plant schema, ecology and tree references
  references/              Reference frames (internal art direction only)
  OVERVIEW.md              Shareable summary
  WORKING_AGREEMENT.md     Who owns what
  WORLD_SYSTEMS_SPEC.md    Architecture and phase cards
  PROGRESS.md              The log, newest on top
  HOW_TO_RUN.md            How to open and play (keys)
  implementation-notes.md  How the code works, file by file
scenes/main.tscn           Game entry point
data/                      Everything tunable: biomes/, plants/, habitat.json, creatures/,
                           peoples/, techniques.json, camps.json, roads.json, look.json,
                           movement.json, sky/, water/, dev.json (each explains itself)
scripts/
  core/                    World autoload (planet, clock, weather, floating origin),
                           main orchestrator, input
  planet/                  Cube-sphere maths, terrain field, blueprint and its passes
  weather/                 Weather simulation; rain, snow and wind effects
  biomes/                  The biome templates
  sky/                     Sun, moon, mansions, sky, seasons
  terrain/                 Chunk streaming, rivers, roads, far shell
  water/                   Ripples and water sound
  ecology/                 Plant species, placement, meshes, growth
  creatures/               Species, spawner, bodies, synthesized sounds
  landmarks/               Ruins, camps, road props
  peoples/                 The camp simulation and peoples
  player/                  First-person explorer with planet gravity (third person kept
                           for the ninja profile)
  ui/                      HUD, map, log, settings, post-grade
shaders/                   Sky, water, terrain, foliage, fire, grade; look.gdshaderinc
assets/                    Fonts, plant textures, retro tiles, models (see their READMEs)
tools/                     Headless checks (*.gd), Python validators and reference maths
```

## Adding content

- **Plants:** add entries to a biome file in `data/biomes/`, or to a catalogue in
  `data/plants/` with its `biomes` list. A species grows only in the biomes that list it, with
  climate, soil and realm applying inside them (§CA). See `data/biomes/README.md` and
  `docs/design/PLANT_SCHEMA.md`, and run `python3 tools/plant_schema_check.py --strict`.
- **Creatures:** add entries to `data/creatures/creatures.json`. See
  `data/creatures/README.md`.
- **Peoples and techniques:** `data/peoples/` (the README there is the schema) and
  `data/techniques.json`.
- **Day cycle:** `data/sky/day_cycle.json`. See `data/sky/README.md`.
