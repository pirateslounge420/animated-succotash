# Low-Poly Exploration Prototype

An open-world, ambient-exploration, third-person game in a low-polygon
world inspired by the GameCube era — *Super Smash Bros. Melee*, *Phantasy
Star Online Episode I & II*, and *F-Zero GX*. Procedurally generated
biomes (Minecraft-style chunked terrain), a 2-hour day/night cycle, and a
primal, tribal, hunter-gatherer high-fantasy setting.

See [`DESIGN.md`](./DESIGN.md) for the full design doc: art direction,
biome list, day/night timing, point-of-interest design, and technical
architecture.

## Engine

Built in **Godot 4.3+**. Open this repo's root as a Godot project
(`project.godot`) directly in the Godot editor.

This repo can also be driven from **Summer Engine** (a desktop, AI-native
game engine that lets Claude build/control a running game session via
MCP) — Summer Engine operates on your local machine, not inside this
cloud session, so treat this repo as the shared source of truth: changes
made here or from Summer Engine should both land as commits on this
branch.

## Project Structure

```
project.godot          Godot project file, autoloads registered here
DESIGN.md               Full design document
scripts/
  autoload/              Singletons: TimeOfDay, WorldGenConfig
  world/                 Chunk streaming / world management
  procgen/               Noise-based terrain + biome generation
  biomes/                Per-biome scatter/asset logic
  player/                Third-person character controller
scenes/
  world/                 World/chunk scenes
  player/                Player character scene
  biomes/                Per-biome scene composition
  ui/                    UI scenes
resources/
  biomes/                Biome definition resources (.tres)
assets/
  models/ textures/ audio/{music,sfx}/ fonts/
docs/
  design/                Supplementary design notes (expand as needed)
addons/                  Godot editor plugins (empty for now)
```

## Status

Design + scaffold phase — no gameplay is implemented yet. See
`DESIGN.md` section 8 for the suggested next milestones (time-of-day
lighting, first single-biome terrain chunk, third-person controller,
biome blending, first hand-placed point of interest).
