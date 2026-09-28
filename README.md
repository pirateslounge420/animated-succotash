# Low-Poly Exploration Prototype

> **The locked design lives in `docs/design/RECONCILIATION_2026-09-27.md` (thesis, decisions §0–V) and `docs/design/PLANT_SCHEMA.md`. They override this README, `DESIGN.md` and `docs/WORLD_SYSTEMS_SPEC.md` wherever they differ.**

An ambient open-world exploration game in a smooth-shaded GameCube style,
set on a walkable, procedurally generated cube-sphere planet — 4,000 km around, one tenth of Earth (design §I; the code
still says 400 km until that change lands) — at a tribal, pre-firearm tech level.
No quests and no crafting: three tools for the whole game (spear, bow, fishing
pole), momentum-based movement that is the point of the game, and you
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
| WASD / arrows, left stick | Walk (5.5 m/s; W twice and hold to sprint) |
| W twice and hold, left stick click | Sprint, while forward stays held (loud: wildlife notices you sooner) |
| Shift, B | Crouch (hold): slow and nearly silent |
| Space, A | Jump (hold to keep jumping); hold to swim up |
| Mouse, right stick | Look (click the window to capture the mouse, Esc frees it) |
| Left mouse (hold, release), right trigger | Draw the bow and loose an arrow: the longer you hold (up to a second), the farther and harder it flies |
| V or F5, right stick click | First / third person |
| E, X | Interact: turn over a fallen log, take a sample, pick things up; today it also starts a climb (changing to hold-right-click cling + move, design §V) |
| Right mouse | The tech button: wall jump / cling / catch-and-swing (see docs/HOW_TO_RUN.md) |
| Tab (or I) | Inventory |
| Q | Cycle bow / spear / fishing pole |
| M, Back | Planet map (keys 1-5 switch biome / elevation / °C / rainfall / live weather; drag to turn, wheel to zoom) |
| H | Hide the HUD |
| F3 | Debug overlay: clock, day phase (dawn / day / dusk / night and how far into it), sky speed, sun and moon elevation, moon age and phase, mansion |

One in-game day is **144 real minutes** — exactly one tenth of a real day, so the
whole calendar runs at 10× and a game hour is 6 real minutes. The planet has an
**axial tilt of 23.5°**, so day and night lengths derive from latitude and the day
of the year (true polar night and midnight sun); 60 / 18 / 48 / 18 real minutes of
day / dusk / night / dawn is the equator-at-equinox reference. A year is 365 game
days (36.5 real days) with four seasons and ~20-day transitions. The moon's cycle
is 29.5 days. Numbers: `data/sky/day_cycle.json`, reference maths:
`tools/reference/daylight_reference.py`, design: `docs/design/RECONCILIATION_2026-09-27.md` §F.

**Dev settings.** While `data/dev.json` has `"dev_mode": true` the game
uses its settings instead: the day length set there (currently the full 144 min), seed 42 and always the same
first camp (`spawn_choice` 0), so before/after screenshots match. Set
`dev_mode` to false (or delete the file) for the game's own settings.
`tools/p0_timelapse.gd` checks the day cycle for snapping and renders a
time-lapse contact sheet (how to run it is at the top of the file).

**Postage stamp.** With `"postage_stamp": true` (on while developing)
the dev game runs on a small scale model of the planet instead of the
full 4,000 km one: 40 km around, so the equator is 10 km from the pole and
every climate band (rainforest, savanna, desert, temperate rainforest and
forest, grassland, scrub, taiga, tundra, alpine, plus sea, coast, rivers
and lakes) is a short walk from the next. It's the same seed and the same
world-building rules with the geography shrunk; the ground underfoot,
plants, animals and ruins keep their real size. It builds in about 3 s
instead of 6. Set it to false (or leave it out) for the full planet, for
milestone checks. The `"stamp"` block sets its size (`circumference_km`)
and blueprint detail (`grid_res`), and lists the bands it must contain.
`tools/stamp_check.gd` checks that they're all there and draws the
stamp's map and a ground view at the first camp (how to run it is at the
top of the file).
Temperatures everywhere (HUD, map, data files) are in **°C**.

## How the world is built

Only the planet's coarse ~1 km **blueprint** is built for the whole
planet at once, because the weather and rivers need it: terrain, oceans,
lakes and rivers, a running weather simulation, climate averages, rock
types, and one of the 52 biome templates per cell. Everything you can walk
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
  a pyramid, a graveyard or a barrow; tombs, mausoleums and the desert
  pyramid's burial chamber can be walked into) from ~2.6 km,
  so their silhouettes rise out of the fog before you reach them; about
  a third hold a survivors' camp of tepees and lean-tos. At night they,
  some lakes and wetlands, and mythical territories glow teal and cobalt.

Wildlife hears you: crouched you can creep close, sprinting sends it
running from far off, and a startled animal calms down if you keep still.
Trees block your way and can be climbed; their crowns (and camp
shelters) keep the rain off. Storms bring lightning and thunder, and
heavy rain swells the rivers.

Near you, anything that touches the water rings it: your steps and the
wake you drag as you wade, swimming strokes, animals' legs, arrows and
rain. The rings are painted as soft light and dark bands; their reach,
sizes and look are in `data/water/ripples.json`. `tools/ripple_demo.gd`
records them at night (how to run it is at the top of the file).

The floating origin keeps the player near (0,0,0), so precision holds
anywhere on the planet.

## Project structure

```
project.godot              Project file; World autoload, main scene
DESIGN.md                  Design spec
docs/implementation-notes.md
scenes/main.tscn           Game entry point
data/
  biomes/                  52 biome files: plant lists per biome (edit these)
  creatures/creatures.json Creature species (edit this)
  water/ripples.json       Water ripples: reach, sizes, rain, look (edit this)
scripts/
  core/                    World autoload (planet, clock, weather, floating
                           origin), main orchestrator, input actions
  planet/                  Cube-sphere math, terrain field, blueprint data,
                           generator and its passes
  weather/                 Weather simulation; rain/snow/wind effects
  biomes/                  The 52 biome templates (names, colors, sizes)
  sky/                     Sun, Earth-like moon, 28 lunar mansions, sky
  terrain/                 Chunk streaming, rivers, far shell
  water/                   Ripples on the water near the camera
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
- **Day cycle:** phase lengths, day length, moon cycle and transition
  timings in `data/sky/day_cycle.json`. See `data/sky/README.md`.
- **Creatures:** add entries to `data/creatures/creatures.json`: habitat
  role, climate range, density, activity time, needs, looks and sound.
  See `data/creatures/README.md`.
- **Biomes:** there are 52 template slots (51 surface + caves) matching
  DESIGN.md. Many biome files are still `placeholder` or `empty`; their
  status field says which.
