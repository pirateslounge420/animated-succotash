# How to open and play the project (no coding needed)

## 1. Get Godot 4.3
- The project is built for **Godot 4.3 (stable), the standard build** — not the ".NET" build, and not 4.4 or later.
- Download it from the Godot archive: https://godotengine.org/download/archive/4.3-stable/
  - Windows: "Standard — 64-bit". You get a zip; unzip it anywhere. The program is `Godot_v4.3-stable_win64.exe`.
  - macOS: "Standard — Universal". Drag `Godot.app` into Applications. The first time, right-click it and choose Open.
  - Linux: "Standard — x86_64". Unzip; the program is `Godot_v4.3-stable_linux.x86_64`.
- Godot needs no installer and changes nothing else on your computer.
- (Claude Code's cloud machine has its own copy at `/root/bin/godot`, version 4.3.stable.official 77dcf97d8. That machine has no screen, so to play you need Godot on your own computer.)

## 2. Get the project
- On GitHub, open `pirateslounge420/animated-succotash` and switch the branch menu to `claude/lowpoly-exploration-prototype-i1z8g3`.
- Click **Code → Download ZIP**, and unzip it somewhere easy to find, such as Documents.
- (If you already use Git: `git clone` the repository and check out that branch.)

## 3. Open it in Godot
1. Start Godot. The **Project Manager** window opens.
2. Click **Import**, go into the unzipped folder, pick the file **`project.godot`**, and click **Import & Edit** (on some versions, **Open**).
3. The first time, Godot imports everything. Wait for the progress bar to finish (a minute or two).
4. You're now in the editor. You don't need to touch anything in it.

## 4. Play
- Press **F5**, or click the **▶ Play** button at the top right. That runs the main scene, `scenes/main.tscn`.
- A game window opens. For a few seconds the small test planet (the "postage stamp", 40 km around) is generated. Then you wake by the campfire at the first camp.
- `data/dev.json` already sets this up:
  - `dev_mode: true` turns the F4–F8 dev keys on.
  - `postage_stamp: true` gives you the small planet with every kind of biome.
  - `seed: 42` makes it the same planet every time.
  - `spawn_choice: 0` wakes you at the first camp every time.
  - `day_length_min: 20` makes a full day and night last 20 minutes.
- To stop, press **Esc** to free the mouse and close the game window. Or, back in the editor, press the **■ Stop** button.

## 5. Keys (keyboard and mouse)
| Key | What it does |
|---|---|
| W A S D (or arrow keys) | Walk |
| W twice quickly, then hold | Sprint |
| Shift (hold) | Sneak: crouch, slower and quieter |
| Space | Jump (hold for a higher jump); while climbing, push off |
| Mouse | Look around |
| Left mouse button | Bow: hold to draw, release to shoot. Spear: a quick tap thrusts; hold to raise, release to throw |
| Q | Swap between bow and spear |
| E | Interact: grab a tree to climb it (E again lets go), pick your thrown spear back up, turn over a fallen log |
| V or F5 | Switch between first and third person |
| M | Map. While it's open, 1 = biomes, 2 = height, 3 = temperature, 4 = rainfall, 5 = live weather |
| H | Hide or show the on-screen text |
| Esc | Free the mouse pointer (click in the window to take it back) |
| F3 | Debug overlay: clock, day phase, sun and moon |
| F4 (dev) | Show collision shapes |
| F6 (dev) | Show trees' branch graphs (the handholds) |
| F7 (dev) | Spawn the next test creature beside you, in turn: the Night Rider pair, the Pond Crawler (in the nearest water), the gibbon (on the nearest rainforest tree). It prints why when it can't |
| F8 (dev) | Make the nearest wolf pack howl |

Gamepad:
- Left stick moves, and clicking it in (held) sprints.
- A jumps, B crouches, X interacts, Y swaps bow and spear.
- The right trigger draws and shoots.
- Clicking the right stick switches first and third person.
- Back opens the map.

Climbing: walk up to a tree and press E. W and S go up and down the trunk, and A and D go around it. At a fork, look out along a limb and push W to go onto it. Push toward another limb to reach across.

## 6. If something goes wrong
- **"This project was made with a different version":** you opened it with a Godot other than 4.3. Use 4.3 (step 1).
- **A black screen for more than about 20 seconds:** the planet is still generating, or your graphics card doesn't support the Forward+ renderer. Try updating your graphics drivers.
- **An F-key does nothing:** click inside the game window first. When the editor window has focus, F-keys go to the editor instead (there, F5 runs the game and F8 stops it).
