# Low-Poly Exploration Prototype

An ambient open-world exploration game in a GameCube-era low-poly style
(*Phantasy Star Online Ep. I & II*, *F-Zero GX*, *Super Smash Bros.
Melee*), set on a walkable, procedurally generated planet at a tribal,
pre-firearm tech level.

- [`DESIGN.md`](./DESIGN.md) is the design spec.
- [`docs/implementation-notes.md`](./docs/implementation-notes.md)
  records what the prototype code currently does, which files do it, how
  it was verified, and the roadmap. Parts of it lag behind the spec.

## Engine

Built in **Godot 4.3+**. Open this repo's root as a Godot project
(`project.godot`) directly in the Godot editor. It is also meant to be
worked on from **Summer Engine**, an AI-native desktop engine built on
Godot.

## Project Structure

```
project.godot            Godot project file, autoloads registered here
DESIGN.md                Design spec
docs/
  implementation-notes.md  What's built, how it works, roadmap
scripts/
  autoload/              Singletons: TimeOfDay, WorldGenConfig
  procgen/               World-gen pipeline (WorldMapGenerator + passes/)
  world/                 Sky/lighting, world-map viewer, boat, debug camera
scenes/
  world/                 world_map_demo.tscn (main scene), older demos
assets/                  Empty placeholders for models/textures/audio/fonts
```

## Running it

Open the project and press Play. The main scene is
`scenes/world/world_map_demo.tscn`: a generated world region you can fly
around (right-click to look, WASD to move, Space/Shift for up/down). Keys
1–5 switch the terrain coloring between biome, height, temperature,
moisture and fog chance.
