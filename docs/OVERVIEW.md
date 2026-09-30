# Project Overview — an ambient open world you cross like a shinobi

*Working title: "animated-succotash". Solo project by Mike Flow, built in Summer Engine
(Godot 4) with two AI collaborators. This overview is for sharing: what the game is, how
its systems fit, and where it stands. Feedback wanted on anything.*

---

## The one-sentence version

A dark, moody, early-2000s-console-looking planet — one tenth the size of Earth, real
biomes, real seasons, real ecology — that you explore with a movement system built to
feel like an anime ninja: wall jumps, branch swings, landing rolls, momentum you build and
can lose, and three tools that never change.

## The thesis

**The game is about the fundamentals: a world, and exploring it through movement that
feels good.** Every feature has to pass one test — does it make moving through the world
feel better, or make the world worth moving through? If neither, it doesn't go in. That's
why there is no crafting, no tool tiers, no quest log, and no levels. Progression is your
hands.

## The look

- **Era:** 1999–2004 (Dreamcast, GameCube, PS2). Detail lives in textures, not in
  lighting. No normal maps, no bloom, no soft shadows. Reference points: *Phantasy Star
  Online*, *Melee*, *F-Zero GX*, *Wind Waker*.
- **Mood:** dark and moody at every hour. The sun is the only real light; ambient is low
  and blue; shadows are deep and hard-edged. Skies are saturated cobalt with painted
  clouds by day, indigo with baked stars by night.
- **Characters:** everything intelligent is a **cloaked figure** on one shared rig —
  small folk at 1 m, tribal folk at 1.7 m, trolls scaled up — distinguished by size,
  timing and cloak colour, the way Captain Falcon and Ganondorf share a moveset. The
  player's indigo cloak with a rust hem is reserved. Beasts (wolves, werewolves, yeti,
  the night rider) keep their own bodies.
- **Plants** are being rebuilt from real botanical vocabulary — leaf outline, margin,
  venation, arrangement, canopy form — into procedurally generated leaf cards, so a
  species is recognisable by silhouette at 64 px and the far horizon never becomes a
  green blob.

## The world

- **Scale:** a walkable cube-sphere planet **4,000 km around (1/10 Earth)**, with terrain
  height, time and biomes all at the same 1/10 ratio. Nothing is generated until you
  get near it; the horizon is drawn as one low mesh; performance depends on what's in
  view, not on how big the world is.
- **Time:** a day is **144 real minutes** — exactly one tenth of a real day, so a game hour
  is six real minutes and the whole calendar runs at 10×. A year is 365 game days
  (36.5 real days) with four seasons and generous transitions.
- **Tilt and seasons:** 23.5° axial tilt, so day and night lengths depend on latitude and
  date: midnight sun and true polar night exist. Deciduous trees turn and drop; evergreens
  don't. Short-day plants (cannabis, chrysanthemum) flower when the days shorten — because
  the days actually shorten.
- **Biomes:** all 52 real-world biomes (Whittaker temperature × rainfall, plus altitude,
  coasts, wetlands, caves), at real 1/10-Earth extents, blending through microclimates.
  Plants spawn by three co-equal gates: temperature, rainfall, and **soil type**, which
  the terrain marks explicitly (basalt, sand, alluvium, peat, till, karst…).
- **Weather:** a live global wind and water cycle — pressure-driven wind, evaporation,
  storms that travel, rain shadows behind mountains. Creature scents ride the wind.
- **Geology:** plate tectonics are baked at world generation; their boundaries decide
  where earthquakes, volcanoes, hot springs and tsunamis can happen.
- **Rivers** are long, navigable, with waterfalls and storm swell; dead wood, snags and
  fallen logs are real objects that fungi and insects break down and that owls and
  woodpeckers live in.
- **Amorphophallus** (the designer grows them) are a showcase genus: 246 species whose
  petiole patterns are generated from the real taxonomic descriptions, each tuber rolling
  its own mottling, blooming when the tuber is mature enough — and stinking on the wind
  to pull in carrion flies.

## Movement — the heart of it

- **One rule for the air:** once you leave a surface your velocity is fixed until you
  touch something. Your **body** is free to turn — spin 180° mid-jump (it reads as a
  moonwalk), shoot backwards at a pursuer, turn back for the landing.
- **Every contact re-aims your momentum to where you're looking** — landing, wall jump,
  branch bounce, swing release. How much momentum survives falls off with how far you
  turn: a nudge is free, a right angle costs half, a full reversal costs nearly all.
  No technique beats the geometry.
- **The tech button (right mouse):** tap on a wall = wall jump; hold = cling; on a
  branch or vine too thin to kick = catch and swing; land on top of a branch and tap =
  bounce. Chained perfect inputs keep or build speed; clinging is the safe, slower
  bail-out. Timing windows are Melee-tight (14 frames at a locked 60 fps).
- **Landing roll:** tap crouch on touchdown from height and the fall becomes forward
  speed and does no damage. Miss it and the fall hurts — at speed, it kills.
- **Asymmetric gravity:** you jump like an Earth-strength body on a small planet (a bound
  carries tens of metres) but fall at Earth gravity or stronger — a shark-fin arc, no
  floating.
- **The ceiling is 120 km/h**, and it isn't a wall: it's where trees stop reading as
  objects and any mistake is lethal. Risk is the governor, not a cap.
- **Handholds have material:** each plant species has a break speed, a flexibility and a
  snapback. Green giant bamboo is unbreakable and springs you out — a grove is a launch
  corridor. Dead wood is brittle and cracks. You can hang as long as you like; what you're
  holding decides if it holds you.
- **Climbing** is holding the cling and moving. Every tree has a top, and at the top you
  can **perch**.
- **The body sells it:** ninja-run lean, arms trailing back, alternating feet on every
  landing, the cloak doing most of the animation; the hood turns before the torso so
  you can read where a figure is about to go. First person shows only what's in your
  hands and never tumbles.

## Tools and combat — three tools, forever

- **Spear, and a bow with a quiver of twenty.** You wake empty-handed with the two lying
  beside you, the folk's gift; there is nothing else to find or make. Bare hands can
  still fight: a jab, or a wound-up haymaker. (The fishing pole is shelved for a separate
  fishing game; the spear fishes.) Left mouse holds to charge (draw, raise, wind up);
  release to act. **Charging never slows you** — the only difficulty is doing two things
  at once with two buttons at speed.
- **Momentum is the weapon:** arrows inherit your velocity; a spear thrust at speed is
  an impact strike that can kill outright; the same physics kills you if you miss a
  trunk.
- **Super meter:** perfect techs and landed hits fill it. Hold a charge past full and
  the shot becomes a **super shot** — a critical, triple damage, faster and farther,
  with a red tracer — and the meter empties. The pole's version is a grapple.
- Arrows stick in whatever they hit and carry the shooter's cloak colour in the fletching.
- **Q cycles the two** (whichever you have) **and bare hands.** The spear spear-fishes. Fishing itself (bites, species
  by water temperature, cooking) comes with the camp-life phase.

## Death, camps and the enemy

- **Camps are safe zones.** A lit fire keeps hostile creatures off; you heal by resting
  near it and eating. Camp folk are cloaked figures in their tribe's colours.
- **Death is diegetic.** You wake by the nearest fire because tribal folk found you and
  carried you in, and they've left you a new bow and spear. Your body —
  everything you had — is still where you fell, marker-free; you retrace your route,
  and scavengers circling it help you find it.
- **The opening is the same scene.** You come to by a fire; **enemy shinobi**, already
  at speed, are leaving through the canopy above you; the folk explain they were coming
  for your body but the village's own shinobi always get there first. No quest text.
- **The enemy camp is real.** It's 50–70 km away in a fixed direction; a determined
  player can follow the bearing and the signs through a whole night and reach it by
  dawn. It's a creepy place, and a safe zone for nobody.
- **Master shinobi** are the standing threat: cloaked figures that play by exactly the
  same physics, kite you at the ceiling, and hit with aimbot precision — and can die
  the same way you can. Beating one is the game's unspoken mastery test.

## Interface

- Almost none. A small **speedometer** (mph and km/h) that brightens as you go faster; a
  **railway pocket watch** (steel case and crown, white dial, black 1-12 and red
  13-24, a red seconds hand); a slim health bar; the super meter as a ring on the charge
  gauge. Typewriter-style font. Map on M (biome, height, temperature, rainfall,
  weather layers) — it never marks your corpse or the enemy.

## Where it stands (28 Sept 2026)

Built and playable: the planet, all 52 biomes, rivers and water, ~1,400 plant species
with climate and soil bands, 28 creatures with behaviours, live weather, the day/night
cycle, the player rig and cloak, wall jump / cling / swing / roll, vines and handhold
materials, bow and spear with body-part hitboxes, death and waking by a fire, camps with
folk, ruins. The dark-daylight lighting pass just landed. The designer's verdict from
the last play: "lowkey already getting fun."

In progress: derived day/night from tilt, seasons, head-look, soil as a hard gate, the
HUD readouts, asymmetric gravity and the momentum ceiling, branch bounce, the fishing
pole, the leaf-card plant builder (schema locked, 135 species filled so far).

Later: ecology food web and populations, camp life and cooking, the opening scene with
fleeing shinobi, master shinobi AI, the enemy camp, lore and rumour, persistence.
Multiplayer is a someday.

## How it's being built

By one designer directing two AI agents on the same repository: one in the engine
(code, shaders, screenshots, feel), one in design, data and reference maths (design
document, plant data via parallel research agents, astronomy tables the engine must
match). A locked design document is the source of truth; a working agreement says who
owns what. Everything is procedural and rule-based on purpose — the goal is a world
that surprises its own creator.

## Questions we'd love opinions on

1. Does "three tools, forever" feel like freedom or like a ceiling?
2. Is a 120 km/h ceiling with lethal misses exciting or punishing for a newcomer?
3. Would you chase the shinobi through the night? What would make you?
4. Is a 36-real-day year (with ~9-day seasons) a feature or too slow to notice?
5. The grapple as an overcharge only — too rare, or exactly right?
