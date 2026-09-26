# Character models

Drop a `.glb` (or `.gltf`) here and the game uses it instead of the
procedural body. No code changes needed.

| File | Replaces |
|---|---|
| `player.glb` | the player (the elf, `PlayerBody`) |
| `<name>.glb` | a creature or NPC, by its name in snake case: `goblin.glb`, `deer.glb`, `arctic_wolf.glb`, `unicorn.glb`, `werewolf.glb`, `elder.glb`, `hunter.glb`, `skeleton.glb`, `hooded_one.glb`, `northerner.glb`, `marsh_dweller.glb`, ... (names from `data/creatures/creatures.json` and the camp folk in `scripts/landmarks/camps.gd`) |

## What the game does with it

`ModelLibrary` (`scripts/core/model_library.gd`):

- **Scale and placement:** the player is scaled to `height_m` (default
  1.75 m); creatures are scaled to their species `size_m`. Feet go at the
  ground, the model is centered, and it's turned to face the way the
  character walks.
- **Lighting:** every material's color and texture are kept, lit like the
  rest of the world: colored shadows, rim light, a glossy sheen, the
  moonlit edge at night, and the distance haze. Set `"lighting": "own"` to
  keep the model's materials exactly as they are.
- **Animation:** if the model has an AnimationPlayer, its clips play by
  what the character is doing. For the player that's idle, walk, sprint,
  crouch, crouch_walk, air, swim and climb. Creatures use idle, walk and
  sprint, and camp folk use sit. Clips are matched by name ("Walk",
  "walking" and "Armature|Walk" all serve walk). A missing one falls back
  to idle, then to the first clip.

## Optional sidecar: `<name>.json`

```json
{
  "height_m": 1.75,
  "measure": "height",
  "yaw_deg": 180,
  "lighting": "world",
  "animations": {"idle": "Idle", "walk": "Walk", "sprint": "Run", "sit": "Sitting"}
}
```

- `measure`: `"length"` for animals whose `size_m` is nose-to-tail.
- `yaw_deg`: glTF models face +Z, and the game walks along -Z, so the
  default is 180. Use 0 if your model comes in backwards.

## Summer Engine workflow

1. Generate the model from reference art (image-to-3D).
2. If you can, rig it and add clips named idle, walk, run, crouch, jump,
   swim, climb and sit. Unrigged models work too; they just don't animate.
3. Export `.glb`. Aim for about 2,000-6,000 triangles for the player and
   NPCs, and 800-2,500 for wildlife.
4. Save it here under the right name, and run the game.
