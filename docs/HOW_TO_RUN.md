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
  - `day_length_min: 144` is the real cycle: 144 minutes for a full day and night (6 real minutes an in-game hour; at the equator on an equinox: day 07:00–17:00, dusk 17:00–20:00, night 20:00–04:00, dawn 04:00–07:00). You wake at the very start of dusk. Lower it (say 20) to see the cycle go by faster.
- To stop, press **Esc** to free the mouse and close the game window. Or, back in the editor, press the **■ Stop** button.

## 5. Keys (keyboard and mouse)
You start in first person. Walk and sprint speeds, the jump and every other movement and weapon number are in `data/movement.json` and `data/combat.json` (each part explained at the top of the file); edit them and restart the game.

| Key | What it does |
|---|---|
| W A S D (or arrow keys) | Walk |
| W twice quickly, then hold | Sprint |
| Shift (hold) | Sneak: crouch, slower and quieter. In the air: drop fast. Tap it right as you land from a big fall: today a ninja roll (no fall damage, the fall turns into speed); by design §Z the roll moves to right click and Shift becomes the BRAKE — a stopping slide on the ground or on landing (not built yet) |
| Space | Jump. Tap it for a hop (about 2 m); hold it for the full bound: a long, lazy rise and a fast drop (from a sprint about 50 m out and 19 m up). Nothing steers you in the air: you fly where you took off toward, though your body turns with the mouse. Every landing, bounce and kick sends your speed where you're looking (a sharp turn loses more of it). While climbing, push off |
| Right mouse button | The tech button — all movement lives here (design §Z: on the ground, sprinting + right click = slide, right click on touchdown = roll; not built yet). In the air, what you touch decides. On a wall, cliff, trunk or ruin: tap it within 14 frames (about a quarter second) of touching it to wall jump (chained ones keep building speed), or hold it to cling; letting go of a cling (or Space) still springs you off, a little softer than a perfect tap, and Shift drops you off instead. Near a branch, bamboo or vine: hold it to catch and swing, let go to fly on (green bamboo springs you out; dead, grey wood snaps). Landing after a fall on anything you can stand on (a branch, a ledge, the ground): press it just before or just after touchdown for a bounce that turns the fall into speed toward where you look |
| Mouse | Look around (straight up and down too) |
| Left mouse button | Bow: hold to draw, release to shoot. Spear: a quick tap thrusts; hold to raise, release to throw. Works in the air too. No aim arc: you learn the drop by eye; a bright streak follows the arrow or spear once it flies. With super meter (the gold ring round the gauge, filled by perfect wall jumps, rolls and swing releases, and by hits), keep holding past full charge until the gauge fills again in red: a super shot (critical, triple damage, faster, farther, a red streak) that empties the meter; a super-thrown spear kills what it hits outright and pins it. Arrows and a thrown spear carry your own speed. A spear thrust hurts more the faster you're closing on the target, and at 25 m/s (90 km/h) it kills anything but a mythical creature; a thrust into a trunk or wall at speed hurts you instead |
| Q | Cycle bow, spear and fishing pole (the pole is bound; casting is not built yet — design §N) |
| E | Interact, whatever you're doing (climbing, swimming, crouched): take a sample of the plant you're looking at (walk right up to it: plant names and samples only within about a metre), pick up your spear, an arrow or something you set down, grab a tree to climb it (E again lets go), turn over a fallen log, take your things back from your body after dying |
| Tab (or I) | Inventory: what you carry and wear. The world doesn't stop. Click a line to choose it; G sets a carried thing down, E wears a spare. Tab or Esc closes it |
| Mouse wheel | Fishing pole in hand: scroll down to reel the line in, scroll up to let it out (bound; the pole itself is not built yet) |
| V or F5 | Switch between first and third person |
| M | Map. While it's open, 1 = biomes, 2 = height, 3 = temperature, 4 = rainfall, 5 = live weather |
| H | The full HUD: every readout (the time, the moon, its mansion, the season, the biome and soil, the temperature, the weather, the wind, your elevation and position, the speedometer and the clock). H again: just the ones you've pinned |
| O or F10 | Settings (click a line; O, F10 or Esc closes): the speedometer and the clock on or off (the same as pinning them); the picture's internal lines (480, or 720 at most), its shape (16:9, or 4:3 with black bars), integer scaling on or off; sun shadows by day on or off (off: no cast shadows, dark ground under trees and soft blobs under characters, the reference look being tried out); and the volume: everything, the footsteps (walking, running, landings, skids) and the climbing (hands on the bark, breaths), each a slider (click the bar or drag along it; left or right of it for 10 % less or more; footsteps and climbing start at half) |
| Esc | Free the mouse pointer. While it's free (and no inventory, settings or map is open) every readout shows and a line at the top says what to do: click a readout to pin it to the screen (pinned ones are bright with a small gold • before them, the rest dimmed), click it again to unpin it; it's saved at once. Click anywhere else to take the mouse back and carry on |
| F3 | Debug overlay: clock, day phase, sun and moon |
| F2 (dev) | Frame-time readout at the top: frame ms and fps, the renderer's cpu and gpu ms, and what the shadow pass costs (sampled every few seconds by switching shadows off for a few frames, so they blink briefly while it's on) |
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

Readouts: your speed at the bottom right (mph and km/h; faint when you're slow, brighter toward 120 km/h, its glow warming as the super meter fills), and an old railway pocket watch at the top right: a steel case and crown, a white dial with the hours 1-12 in black and 13-24 in red inside them, a minute track, black hands and a red seconds hand (the minute hand goes round once a game hour, 6 real minutes; the seconds hand once a game minute). These two are the only readouts pinned in a new game; the others (the time, the moon, its mansion, the season, the biome and soil, the temperature, the weather, the wind, your elevation and position) show with H, or all the time once you pin them (Esc, then click them). "Swimming" and "Above the clouds" show whenever they apply. All the on-screen text grows with the window.

The picture: the game draws at a fixed 480 lines (854×480) and blows that up to your window with square, unsmoothed pixels, text and all, so a bigger window only means bigger pixels. With integer scaling on (the default) it uses a whole multiple when the window holds at least two (a 1080p screen shows it at exactly 2×, with thin black bars round it); turn it off in settings to fill the screen at 2.25×. 720 lines is the most the settings allow.

Health: the thin blue bar at the bottom left, with its number. It doesn't come back on its own; stand or sit still by a lit campfire to heal. Nothing hostile can hurt you by a lit fire. Crashing into a trunk or wall at high speed without a tech hurts, and can kill.

Dying: your body stays where you fell, with everything you carried and wore (no marker; birds start circling over it after a while). You wake by the nearest campfire, carried there by the folk who found you, with nothing. Go back and press E by your body to take it all back.

Carrying: ten things at most. Past six you're slower, climb slower and make more noise.

Climbing: walk up to a tree and press E. W and S go up and down the trunk, and A and D go around it. At a fork, look out along a limb and push W to go onto it. Push toward another limb to reach across.

## 6. If something goes wrong
- **"This project was made with a different version":** you opened it with a Godot other than 4.3. Use 4.3 (step 1).
- **A black screen for more than about 20 seconds:** the planet is still generating, or your graphics card doesn't support the Forward+ renderer. Try updating your graphics drivers.
- **An F-key does nothing:** click inside the game window first. When the editor window has focus, F-keys go to the editor instead (there, F5 runs the game and F8 stops it).
