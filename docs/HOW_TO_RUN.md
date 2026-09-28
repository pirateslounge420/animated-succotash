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
  - `day_length_min: 144` is the real cycle: 144 minutes for a full day and night (6 real minutes an in-game hour: day 07:00–17:00, dusk 17:00–20:00, night 20:00–04:00, dawn 04:00–07:00). You wake at the very start of dusk. Lower it (say 20) to see the cycle go by faster.
- To stop, press **Esc** to free the mouse and close the game window. Or, back in the editor, press the **■ Stop** button.

## 5. Keys (keyboard and mouse)
You start in first person. Walk and sprint speeds, the jump and every other movement and weapon number are in `data/movement.json` and `data/combat.json` (each part explained at the top of the file); edit them and restart the game.

| Key | What it does |
|---|---|
| W A S D (or arrow keys) | Walk |
| W twice quickly, then hold | Sprint |
| Shift (hold) | Sneak: crouch, slower and quieter. In the air: drop fast. Tap it right as you land from a big fall: a ninja roll (no fall damage, and the fall turns into speed) |
| Space | Jump (about a metre, heavy and snappy; longer and higher at a sprint); while climbing, push off |
| Right mouse button | The tech button, in the air; what you touch decides. On a wall, cliff, trunk or ruin: tap it within 14 frames (about a quarter second) of touching it to wall jump (chained ones keep building speed), or hold it to cling; letting go of a cling (or Space) still springs you off, a little softer than a perfect tap, and Shift drops you off instead. Near a branch, bamboo or vine: hold it to catch and swing, let go to fly on (green bamboo springs you out; dead, grey wood snaps) |
| Mouse | Look around (straight up and down too) |
| Left mouse button | Bow: hold to draw, release to shoot. Spear: a quick tap thrusts; hold to raise, release to throw. Works in the air too. No aim arc: you learn the drop by eye; a bright streak follows the arrow or spear once it flies |
| Q | Swap between bow, spear and fishing pole |
| E | Interact, whatever you're doing (climbing, swimming, crouched): take a sample of the plant you're looking at, pick up your spear, an arrow or something you set down, grab a tree to climb it (E again lets go), turn over a fallen log, take your things back from your body after dying |
| Tab (or I) | Inventory: what you carry and wear. The world doesn't stop. Click a line to choose it; G sets a carried thing down, E wears a spare. Tab or Esc closes it |
| Mouse wheel | Fishing pole in hand: scroll down to reel the line in, scroll up to let it out |
| V or F5 | Switch between first and third person |
| M | Map. While it's open, 1 = biomes, 2 = height, 3 = temperature, 4 = rainfall, 5 = live weather |
| H | Hide or show the on-screen text |
| Esc | Free the mouse pointer (click in the window to take it back) |
| F3 | Debug overlay: clock, day phase, sun and moon |
| F4 (dev) | Show collision shapes |
| F6 (dev) | Show trees' branch graphs (the handholds) |
| F7 (dev) | Spawn the next test creature beside you, in turn: the Night Rider pair, the Pond Crawler (in the nearest water), the gibbon (on the nearest rainforest tree). It prints why when it can't |
| F8 (dev) | Make the nearest wolf pack howl |
| F9 (dev) | Put a bundle of herbs, a fish, a mushroom and a cut cactus column in your pack (to look at the inventory) |

Gamepad:
- Left stick moves, and clicking it in (held) sprints.
- A jumps, B crouches (fast-fall in the air), X interacts, Y swaps bow and spear.
- The right shoulder wall-jumps.
- The right trigger draws and shoots.
- Clicking the right stick switches first and third person.
- Start opens the inventory, Back the map.

Health: the thin blue bar at the bottom left, with its number. It doesn't come back on its own; stand or sit still by a lit campfire to heal. Nothing hostile can hurt you by a lit fire. Crashing into a trunk or wall at high speed without a tech hurts, and can kill.

Dying: your body stays where you fell, with everything you carried and wore (no marker; birds start circling over it after a while). You wake by the nearest campfire, carried there by the folk who found you, with nothing. Go back and press E by your body to take it all back.

Carrying: ten things at most. Past six you're slower, climb slower and make more noise.

Climbing: walk up to a tree and press E. W and S go up and down the trunk, and A and D go around it. At a fork, look out along a limb and push W to go onto it. Push toward another limb to reach across.

## 6. If something goes wrong
- **"This project was made with a different version":** you opened it with a Godot other than 4.3. Use 4.3 (step 1).
- **A black screen for more than about 20 seconds:** the planet is still generating, or your graphics card doesn't support the Forward+ renderer. Try updating your graphics drivers.
- **An F-key does nothing:** click inside the game window first. When the editor window has focus, F-keys go to the editor instead (there, F5 runs the game and F8 stops it).
