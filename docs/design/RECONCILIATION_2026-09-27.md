# Design reconciliation — 27 Sept 2026

Decisions made in design chat, checked against what the repo actually contains.
Purpose: stop new work duplicating existing systems. Read this before adding anything
from the "Ambient Sandbox RPG" blueprint.

Rule of thumb: **if a system is in section 1, change its data; if it's in section 2,
put the work in the named phase of `WORLD_SYSTEMS_SPEC.md`; only section 3 is new.**

---

## 0. Locked decisions (new or changed)

- **Day/night cycle: 144 min real time — day 60 / dusk 18 / night 48 / dawn 18 (10h / 3h / 8h / 3h in game time).**
  One in-game hour = 6 real minutes exactly, so a clock or sundial reads cleanly. Supersedes 150 and 120 (45/20/35/20) and every earlier value.
  Applied in `data/sky/day_cycle.json` in this commit. `data/dev.json` still overrides to 20 min for testing.
- **Visual target: 1999–2004** (Dreamcast → GameCube/PS2/Xbox). Hard line: before normal maps
  and shader-driven realism (Xbox 360/PS3, ~2005–07). Detail lives in textures, not lighting.
  Rejected: post-2005 "real is brown" realism *and* modern soft Pixar-style shading.
  Melee's strength to copy: archetypal, instantly readable character silhouettes.
- **Tone stays tribal / pre-firearm.** Combat is spear, bow, unarmed, torch. Nothing else.
- **CUT, saved for a possible sequel:** metallurgy, clay brick forges, periodic-table smelting,
  steam machinery, mills, tiered boats (single/double/commercial/enterprise), swords.
  None of this exists in code — do not add it. The spec's single mention of boats as future
  travel may stay; strike any tier list.
- **Campfire / fireplace rules:** a lit fire is a **safe zone** from hostile creatures.
  Healing is **not** automatic on arrival — the player heals by **resting near the fire and
  by eating**. (Current code heals on rest at a lit fire; the eating half arrives with Phase 10
  cooking. Safe-zone behaviour needs a creature-side check — see §3.)
- **Plate tectonics are baked at world generation, never simulated live.** Plate boundaries
  become a permanent map of where earthquakes, volcanoes, tsunamis and hot springs can occur.
- **Living wind + water cycle: keep.** They are felt in play (moisture inland, rain shadows,
  storms that travel). Already implemented — see §1.
- **Ecology is data-driven:** each creature has diet type, aggression range, territorial radius;
  carrying capacity per biome; trophic levels producers → herbivores → carnivores/omnivores →
  scavengers → decomposers; energy loss between levels; a species may turn on itself under
  scarcity; creatures release **pheromones carried by the wind field**.
  Populations are simulated as **per-region numbers**, with entities spawned only near the player.
  **Phase 2 of ecology, not now:** sexual/asexual reproduction tags, enforced trophic energy loss.

- **Player run feel ("ninja run") — Phase 1.** Anime ninja sprint / classic Sonic run.
  Torso pitches forward with speed (~5° walk, ~20° sprint, +8° on acceleration, slight
  back-lean on stop); head counter-rotates to stay level. When not aiming, attacking,
  climbing or holding a torch, arms trail straight back at hip height with ~0.1 s lag,
  fading in between walk and sprint speed. Any action overrides the trailing pose
  **instantly** (no blend out; ~0.3 s blend back in). Cloak streams with the lean.
  Sprint stride longer and smoother than walk, slight lateral lean into turns (~10°).
  No FOV kick. Speeds in `data/movement.json` unchanged. Lives in `player_body.gd`.
  Change one thing at a time with a screenshot or clip after each.

- **Wall cling + chain momentum — Phase 1.** Today right-click in the air within
  `window_s` of a steep face wall-jumps (`_wall_jump()` in `planet_player.gd`,
  tuning in `data/movement.json` → `wall_jump`). Change to:
  - **Tap** right-click = wall jump, as now.
  - **Hold** right-click on a steep face = **cling**: the player stops and holds the
    wall. Clinging drains slowly (a few seconds, tunable) so you can't camp; when it
    runs out you slide off. Releasing without jumping = drop.
  - Jumping **out of a cling** is allowed but is the weak option: it uses a reduced
    take-off (`cling_jump_scale`, ~0.6 of `speed_mps`) and **resets the chain counter**.
  - **Chained** wall jumps (consecutive, no ground touch, no cling) are the strong
    option: each one **keeps or slightly builds** speed rather than decaying.
    NOTE: this **inverts the existing `chain_decay: 0.72`** — it currently loses 28%
    per jump. Replace with a `chain_gain` around 1.0–1.05, capped after ~3–4 jumps so
    it can't run away.
  - Add to `movement.json` `wall_jump`: `cling_hold_s` (how long a cling lasts),
    `cling_jump_scale`, `chain_gain`, `chain_cap`.
  - **Animation is one reused crouch pose.** Build a basic crouch/squat (legs bent,
    torso dropped, cloak pooling) and reuse it for: landing squat, wall-jump kick
    wind-up, and cling. On a wall the same pose is rotated so the feet plant on the
    face. The **cloak hides the legs**, so exact limb placement never has to look right —
    it only has to *feel* right and leave the player guessing at the parkour going on
    underneath. Don't add separate wall-jump or cling rigs; adjust the cloak sim
    (bunch at crouch, snap out on the kick) instead of adding bones or poses.
  - **Melee-tight timing, 60 fps.** The game targets a locked 60 fps (`max_fps` 60,
    physics tick 60) and the wall-jump window is counted in **physics frames**, not
    wall-clock seconds, so a hitch cannot widen it. Tighten `window_s` from 0.25 (15 f)
    to about **0.23 s (14 f)** — settled by play on 2026-09-27 (6–8 f felt too tight);
    still a deliberate tap on contact, not a
    grace period. Shorten `kick_s` from 0.18 to about **0.13–0.16 s (8–10 f)**: first
    ~2 frames are the crouch pose, then the kick, no ease-in. Tune by feel from there.
  Keep `angle_deg` and `min_wall_steepness` as they are.

- **Right-click is one context-sensitive "tech" button — Phase 1.** The same
  Melee-tight timing, the game picks the move by what you're touching:
  - **Wall / cliff / trunk / ruin face** → wall jump (tap) or cling (hold), as above.
  - **Branch / vine / anything too thin or loose to kick off** → **catch and swing**.
  One input, one timing to learn; the terrain decides the result.

- **Branch catch and swing — Phase 1.** Reuses `BranchGraph` (`scripts/ecology/
  branch_graph.gd`), which already serves player climbing and gibbon brachiation
  (`scripts/creatures/gibbon/gibbon_planner.gd`). The swing is a third reader of the
  same handholds — do **not** build a separate grab system.
  - Moving fast through the air (from a jump, wall chain, or roll exit), tap
    right-click within the tech window while passing near a handhold that is
    **too thin for a wall jump** (radius under the wall-jump threshold, or a limb
    rather than a trunk face): the player **catches** it and swings.
  - Catch rules: the handhold must be within `catch_reach_m` (~1.2) of the hands,
    roughly ahead-and-above of travel. Aim matters: the look direction biases which
    handhold is chosen. Missed timing = no catch, you keep flying (and land as usual).
  - Swing physics: a pendulum from the handhold, entering with the player's current
    speed. Release (release right-click, or jump) at the bottom of the arc keeps
    momentum; release later throws you up. This **preserves or builds momentum**
    the same way a chain wall jump does, and counts as a chain link.
  - Chaining swing → swing follows the graph's links (the gibbon planner's next-
    handhold logic), so canopy travel is possible where the graph allows it.
  - **Vines** are not in `BranchGraph` yet. Add vines (jungle/rainforest/swamp biomes)
    as hanging handhold chains registered with `BranchGraphs` so the same catch code
    finds them. Vine swings are longer and looser than branch swings.
  - Failure: a swing into a trunk or the ground at speed without a tech is impact
    damage, same as the wall rule. Speed → risk applies everywhere.
  - Animation: hands reach and grip (the trailing-arm run pose flips forward on
    catch), body hangs, cloak trails the arc. Reuse gibbon brachiation timing as the
    reference for the hang-and-release rhythm.
  - **Hanging is unlimited.** No timer, no stamina drain — you can hang from a
    branch indefinitely (wait out a wolf, take in the view). The limit lives in the
    **handhold, not the player**: what you're holding decides whether it holds.
  - **Handholds have material properties**, from the plant species (extend
    `species_db` / plant JSON, read by `BranchGraph` per handhold):
    - `break_speed_mps` — catch or swing faster than this and the branch/vine
      **snaps**; you keep flying with reduced speed (same as a missed tech) and the
      handhold is gone from the graph. Thinner wood breaks sooner (scale by radius).
    - `flex` — how far the handhold bends under load (visual sway on catch).
    - `snapback` — how much of the flex returns as a push on release. High snapback
      **maintains or adds momentum**: catching a green, whippy stem and releasing
      on the rebound is a launch. Zero snapback is a plain pendulum.
    - `hold_load` — static weight it bears; below this hanging is free forever.
  - **Alive vs dead matters.** Plants get an `alive` state. Dead wood is **brittle**:
    lower `break_speed_mps`, near-zero `flex` and `snapback`. Green wood is springy.
    Dead wood is a real ecosystem object, not just a movement flag — see
    "Dead wood" below.
  - **Species examples** (starting values, tune by feel):
    - **Giant bamboo, green:** effectively **unbreakable** (very high
      `break_speed_mps`), high `flex`, **high `snapback`** — the premier momentum
      tool; a bamboo grove is a launch corridor. **Dead/dry bamboo:** brittle, low
      break speed, no snapback; it shatters.
    - **Vines (rainforest / jungle / swamp):** long swing, medium break speed that
      drops with age, low snapback (they stretch, they don't spring).
    - **Live oak / cypress limbs:** high break speed, low flex, low snapback —
      reliable, boring pendulums.
    - **Birch / young saplings:** low break speed, high flex, medium snapback —
      whippy but fragile; snap if you come in hot.
    - **Pine:** medium all round; dead pine limbs snap easily.
  - Snapping and snapback are both **readable at a glance**: a green stem bows and
    springs; a dry one cracks. Sound: `sound_synth` gets a crack (dry) and a whip
    (green). This is how the player learns which plants launch and which fail.
  - Add to `movement.json`: a `swing` block with `catch_reach_m`, `max_branch_radius_m`
    (above this it's a wall-jump surface), `release_carry`, `gravity_scale`,
    `snap_speed_keep` (fraction of speed kept when a handhold breaks under you).
    Per-species values live in the plant data, not here.

- **Dead wood: snags, logs and dead bamboo — Phases 5–8, seeded now.** The spec
  already plans `flora.snags` and `flora.logs` as ledgers (tree age seeds them,
  fungi decay them, Phase 7) and `flora.litter` for soil. **Promote them from
  numbers to placed objects**, because dead wood does four jobs at once:
  1. **Movement** — brittle handholds (above). Dry bamboo shatters; a rotten limb
     drops you.
  2. **Decomposer food** — the decomposer rung of the food web (blueprint) gets a
     physical home. Fungi (shelf fungi on snags, mushrooms on logs) and insects
     (termites, beetle larvae) live on dead wood and **break it down over in-game
     seasons** into soil fertility (Phase 5 `flora.litter` / soil layer). Decay is a
     visible state machine: fresh snag → barked → bare → hollow → rotten → gone,
     each stage changing its material properties and who lives in it.
  3. **Homes** — hollow snags are **cavity sites** for owls, woodpeckers and other
     cavity nesters; rotten logs shelter salamanders, snakes, small mammals. Add a
     `site: "snag_cavity"` / `"log"` type alongside the catalogue's existing
     `"termite_mound"` so creature JSON can claim dead wood the way snakes claim
     mounds. Woodpeckers *make* cavities (a snag with a woodpecker becomes a cavity
     site later); owls take over. A snag with a resident gives an audio cue (drumming
     by day, hoots by night) — how the player learns a dead tree is "occupied".
  4. **Landscape reading** — standing snags mark burn scars, beaver-flooded ground,
     bark-beetle kills, and the wet edges of swamps (cypress knees and dead
     trunks are a Louisiana signature).
  - **Placement:** a small fraction of trees per biome are dead at generation, weighted
    up in badlands, swamp margins, taiga (beetle kill), and old burn scars. Dead bamboo
    culms stand inside living groves (bamboo dies back after flowering).
  - **Bamboo shoots** exist too: young culms, short and edible (a forage item for
    Phase 10), later becoming green culms. So a grove has shoots, green culms and
    dry culms mixed — three different handhold behaviours in one place.
  - Do not build the decay simulation before Phase 5 — for now, place dead wood with
    a fixed decay stage so the movement and creature systems have something real to
    use, and let the ledgers drive stage changes later.

- **Tribal folk use the player's body — Phase 1 (fits the Phase 1.5 look pass).**
  Camp and encampment folk (`camps.gd`, `encampment.gd`, `Ruins.camp_folk()`) are
  placeholder `CreatureBodies` shapes. Replace them with the **player's procedural
  rig and cloak** (`scripts/player/player_body.gd`): same proportions, same hood,
  same cloak sim, seated by bending the same rig. One body, many people.
  - **Player stays exactly as is:** cloak `#222a6c` (indigo) with the `#a4492b` rust
    hem band. That combination is **reserved for the player** — no folk may roll it.
  - **Folk get a randomised palette** per person, seeded from the camp seed so the
    same camp has the same people on every visit:
    - **Main cloak colour** from a scale (a hue ramp with the muted, dyed-cloth
      saturation of the era palette in `palette.gdshaderinc` — ochres, madder reds,
      bog browns, woad blues, moss greens, undyed greys) — never the player's indigo.
    - **Hem/edge colour** randomised separately from a second scale, contrasting with
      the main (warm edge on cool cloak and vice versa). Never the player's rust on
      an indigo cloak.
    - `TUNIC`, `TROUSERS`, `LINING` derived from the main colour (darker/desaturated)
      so each person reads as one outfit, not a random pile.
  - **Tribe identity through colour:** each camp's folk draw from a **narrow slice**
    of the scale (a tribe has a look — mostly ochre with green edges, say), with one
    or two outliers. Different camps → visibly different tribes. Later (Phase 11)
    the slice can be tied to the biome cultures.
  - Elders, hunters and guards can carry small marks (a longer hem, a different
    hood, a spear) but the body is the same rig.
  - **There are no goblins.** Every "higher" intelligent creature is a **cloaked
    figure**, the same rig at a different scale. The current goblin (`size_m` 1.0,
    lantern-carrying, holes up under rocks, squats at the fire) becomes a **small
    cloaked folk** — keep the behaviour and the lanterns, drop the goblin body and
    the word. Rename in `creatures.json` and `camps.gd` (`"goblin"` folk →
    `"small_folk"` or a proper tribe name).
  - **Guiding principle — the Falcon/Ganondorf rule.** In Melee, Captain Falcon
    and Ganondorf share one moveset and skeleton; what differs is scale, weight,
    speed and colour, and nobody confuses them. Do the same here: **one rig, one
    animation set** (walk, run, sit, climb, tech, cook, idle) for every cloaked
    figure. Species = scale + timing + palette. Big folk play the same animations
    slower and heavier (longer stride, more settle on landing); small folk play
    them quicker and lighter. **Never build a per-species animation set.**
  - **Scale is the species.** Cloaked figures at roughly: small folk ~1.0 m,
    tribal / marsh / north folk ~1.7 m, and the `Forest troll` (3.2 m) as a
    **big cloaked figure** with the same rig scaled up and a heavier cloak. The
    `Marsh witch` (1.7 m, friendly) is already a cloaked figure by nature — same rig.
  - **Beasts stay beasts.** `Mountain yeti` (a mythical beast — **uncloaked**, fur
    body, stays on the creature side), `Werewolf`, `Desert skinwalker`, `Night rider`,
    `Pond Crawler`, `Unicorn`, `Bog wisp` are not "higher intelligent" in this
    sense and keep their creature bodies. If a creature would ever sit at a fire
    or talk, it's a cloaked figure; if it hunts, haunts or grazes, it's a beast.
  - Northerners may keep fur trim over the cloak; big folk get a heavier hood.
  - **Melee principle applies:** silhouette is the player-vs-folk tell as much as
    colour is, so the player's cloak length, hood and hem band stay unique.
  - Implementation: factor `PlayerBody`'s palette constants into a `Palette`
    record it takes at build time (player passes its fixed one; folk pass a rolled
    one). No second rig.

- **Ninja landing roll — Phase 1.** Landing from height already triggers a squat
  (`landing.squat_s` / `heavy_squat_s`, threshold `heavy_fall_m` 1.7) and fall damage
  past `fall_damage.safe_m`. Add a **timed roll**:
  - Pressing crouch within a short window around touchdown on a heavy fall
    (Melee-tight: about **±4–6 frames**, tunable `roll_window_s`) converts the landing
    into a forward roll instead of a squat.
  - A successful roll **negates fall damage** up to `roll_safe_m` (well above `safe_m`)
    and **minimises** it beyond that (`roll_damage_scale`, ~0.25). Above a hard cap
    (`roll_max_m`) the roll still fires but damage is only reduced, not removed.
  - A successful roll **converts vertical speed into horizontal speed**: on exit the
    player carries `roll_carry` (~0.5–0.7) of the fall speed forward, added to
    run speed. Higher fall → longer roll → faster exit. This is what lets the player
    chain wall-jump → drop → roll → sprint and "sling" through terrain. Roll exit
    feeds straight into the ninja-run lean.
  - **Momentum is nearly uncapped.** `roll_max_mps` and `chain_cap` are only sanity
    limits (physics stability), set far above anything a player will reach by skill —
    not a design ceiling. The balance is **risk, not a cap**: the faster you go, the
    harder momentum is to control and the more a miss costs. Fall damage and impact
    damage scale with speed, so a missed roll or wall jump at high speed **can kill
    outright**. Perfect execution keeps you alive and fast; one mistake ends the run.
    Speed → risk → the health bar is the governor.
  - A **missed** roll (no input, or outside the window) is the existing squat and
    full fall damage. Mistimed input during the squat does nothing — no punish
    beyond the normal landing.
  - Roll length scales with fall height (`roll_len_m` per metre fallen, capped).
    During the roll: no steering, no jump, i-frame-free (creatures can still hit).
  - **Animation:** reuse the crouch pose → tuck → the cloak does the rest. The roll
    itself is a rotation of the body root with the cloak wrapping; no new rig.
  - **The first-person camera never tumbles.** During a roll the body rotates but
    the camera stays **locked to the look direction** (yaw and pitch exactly as the
    cursor has them), following the body's position only. At most a small vertical
    dip (like the landing squat's `dip_m`) and a brief blur of cloak across the
    edges of the view. Same rule for the swing and the wall-jump kick: the body
    flips, the view doesn't. Third-person shows the full roll.
  - Add to `movement.json`: a `roll` block with `window_s`, `safe_m`, `max_m`,
    `damage_scale`, `carry`, `max_mps` (sanity only), `len_per_m`, `len_cap_m`.
  - **Impact damage:** hitting a wall, trunk or the ground at speed without a tech
    (roll or wall jump) deals damage by impact speed above `impact_safe_mps`
    (`impact_per_mps`), same shape as fall damage. Make both lethal at the top end.

- **Death and respawn — Phase 1 / Phase 10.** Death already exists (`main.respawn()`,
  slump-and-lie-still). Lock the consequence: **you respawn, but your gear drops
  where you died.** Carried inventory (the R4 few-things carry) and equipped items
  fall as a pickup bundle at the death spot.
  **Respawn is diegetic: you wake up by a campfire because tribal folk found you
  unconscious and brought you in.** The game's signature opening (spawn at a fire in
  the woods) *is* the respawn. Rules:
  - You wake at the **nearest camp / lit fire** to where you died (the folk who found
    you carried you to their fire), not the last one you visited. If none is in range,
    a small wandering group's fire is placed for the wake-up.
  - Wake-up is a short unskippable-feeling moment, not a cutscene: fade from black,
    lying by the fire, one or two camp folk nearby (the ones who "found you"), maybe
    an elder line of chatter. Then control returns. Reuses `encampment` folk.
  - Full health, empty carry, no gear — it's all in the bundle back where you fell.
    The camp folk did not loot you.
  - **The drop is a corpse, not an icon.** Your body stays where you fell, in the
    existing death-slump pose with the cloak on it, holding all your gear. Interact
    to recover it. **No map pin, no compass, no marker** — you find it by retracing
    your route, the same way you find anything else in this world.
  - **The corpse is in the world, so the world acts on it.** Scavengers gather
    near it (circling birds, a fox) — which is a *help*, since they show you where
    to look — and, once creature memory exists (Phase 7/8), whatever killed you may
    still be around your gear. Finding your corpse is the risk half of the loop.
  - The corpse persists until recovered or the world state expires it (Phase 12
    persistence decides how long). No other penalty — the walk back is the penalty,
    and it starts from a fire, which is a safe zone, so it's never hopeless.
  - Later hook (Phase 11 lore/rumours): folk at that camp can remember they found you.

---

## 1. Already built — adjust data, do not re-implement

| Decision | Where it lives | Status / action |
|---|---|---|
| Day/night cycle | `data/sky/day_cycle.json`, `scripts/sky/day_cycle.gd`, `sky_system.gd` | **Values changed to 144 / 60-18-48-18 in this commit.** No code change. |
| Cube-sphere, 1/100 Earth, 1/10 height | `scripts/planet/planet_const.gd` (400 km, `HEIGHT_SCALE` 0.1) | Done. |
| Whittaker biomes, all 52 | `scripts/planet/passes/biome_pass.gd`, `data/biomes/00…51` | Done. `tepui` is registered but never assigned. |
| Rivers, waterfalls, storm swell | `scripts/terrain/river_network.gd` | Done. Gap: no current direction affecting travel (§3). |
| Plants with temp/moisture tolerances | `data/plants/*` (~1,031 species incl. biome lists), `scripts/ecology/species_db.gd`, `vegetation_placer.gd` | Done. Cleanup: 36 plant names clash between catalogues and biome files (loader keeps the biome copy); `docs/plant_archive/` (66 lists) is unused. |
| LOD / VisibilityRange | Plants `visibility_range_end` 300, fade 40; creatures LOD 40/90 m; also ruins and blob shadows | Done. The blueprint's LOD paragraph is a duplicate — ignore it. |
| Live wind + water cycle | `scripts/weather/weather_sim.gd` (~10 km grid, pressure-driven wind capped 28 m/s, evaporation/condensation, 11 travelling systems, orographic lift, sea breeze), `weather_fx`, `storm_fx` | **Done.** The "not simulating live weather yet" note in older design docs is stale. |
| Vertex lighting, no bloom/sharpen, grain + dither | `shaders/look.gdshaderinc`, `post_grade.gdshader` (grain 0.025, 4×4 Bayer 0.25), `project.godot` scale 0.8 | Mostly done. Two era tweaks pending: texture sampling is `filter_linear_mipmap` → try `filter_nearest_mipmap`; consider render scale 0.5–0.6. Do one at a time with a screenshot. |
| Werewolf on full moon | `creature_species.gd`, `moon_cycle_days` 29.5 | Done. |
| Spear, bow, hitboxes | `scripts/player/bow.gd`, `spear.gd`, `data/combat.json` (placeholder numbers) | Done. `README.md` still says "no combat" — stale. |
| Health, rest-heal at campfire | `planet_player.gd`, `landmarks/campfire.gd` | Done for the rest half; eating half is Phase 10. |
| Ruins, magic sites, I Ching RNG, sky events | `ruin_builder.gd`, `magic_sites.gd`, `core/iching.gd`, `sky/sky_events.gd` | Done. Spec says "don't expand." |
| Creature spawner around player | `creature_spawner.gd` (`ACTIVE_RADIUS` 140, `DESPAWN` 175, `MAX_AMBIENT` 70) | Done. This *is* the "spawn only near the player" half of the population plan. |

---

## 2. Already planned — put the work in the existing phase

| Decision | Phase in `WORLD_SYSTEMS_SPEC.md` | Current state |
|---|---|---|
| Data-driven ecology (diet, aggression, territory, carrying capacity, trophic levels) | **Phase 7 Ecology core**, **Phase 8 Living populations**; food web in Appendix R | 28 creatures in `data/creatures/creatures.json`; behaviours wander/flee/drink/perch/hunt/attack; only 2 have `trophic`; no populations; creatures ignore each other. `territories.gd` exists for mythicals only. |
| Per-region population numbers | Phase 8 | Spawner half exists; population layer does not. |
| Campfire cooking, ingredient status effects, one-meal-a-day rhythm | **Phase 10 Camp life** (fish / forage / hunt → carry → cook at the fire with camp folk) | Only a `PlanetPlayer.heal()` hook today. No hunger meter exists. |
| Caves | Phase 3 | Wolf dens already mark cave mouths. |
| Soil / fertility | Phase 5 | Doesn't exist. |
| Seasons | Phase 4 | Needs axial tilt; none yet. |

---

## 3. Genuinely new — add to the named phase

- **Tectonics at generation** → `geology_pass.gd` assigns rock types (basalt, sand, alluvium,
  clay/peat, till, karst, sandstone, granite) but mountains are not placed by plate boundaries.
  Add a plate pass ahead of terrain shaping; expose boundary distance to biome/hazard logic.
  → **Phase 2.**
- **Pheromones on the wind** → wind field exists, creatures don't sample it. → **Phase 7.**
- **River current affecting travel** (upstream harder) → rivers exist, no current. → **Phase 2 or 10.**
- **Fire as a creature safe zone** → needs a hostile-creature check against lit-fire radius. → **Phase 7** (steering) or earlier if trivial in `creature.gd`.
- **Hunger / eating heals** → no meter; design intent is one meal per in-game day, light-touch, never lethal on its own. → **Phase 10.**
- **Reproduction tags, enforced trophic energy loss** → **Phase 8, after** herbivore + one predator already work.

---

## 4. Housekeeping the repo already needs (not design work)

- Two creature body systems: `creatures/creature_bodies.gd` (744 lines) vs `sculpted_bodies.gd` (878) + `sculpt_rig.gd`.
- Two hitbox files: `creatures/hitboxes.gd` and `creature_hitboxes.gd`.
- Two fire-glow shaders: `fire_glow` and `fire_glow_warm`.
- `planet_const.gd` `WALK_SPEED` 6 km/h disagrees with `data/movement.json` (walk 5.5 m/s).
- `data/creatures/catalogue_dragonflies_snakes.json` (33 creatures) is never loaded.
- `README.md` is stale ("no combat / no quests").
- Open from the 2026-09-28 play session (`PROGRESS.md`): bow and spear sized for the old
  taller body; unexplained ground-crease snag; no source yet for fish, mushrooms or stone tools.

---

## 5. What to actually do next

1. Confirm the new cycle feels right in play (`data/dev.json` still shortens it for testing).
2. Try `filter_nearest_mipmap` in the shader includes; screenshot; keep or revert.
3. Finish Phase 1 open items before touching anything in §2 or §3.


---
---

# Session 2 addendum — 27 Sept 2026, evening (after the designer's second play)

Everything below is confirmed. Where it contradicts something above, this wins.

## A. Play feedback → corrections

- **Wall-jump window is 14 frames** (~0.23 s at 60 fps), not 6–8. Corrected above.
- **Cling keeps some momentum** — it no longer dumps you to a standstill, but it does
  cost speed versus a tap wall jump. Tap = the snappy skill move that preserves speed;
  cling = the safer, slower bail-out for long climbs. Both stay ninja-snappy.
- **First person is clean:** no hands, no cloak, nothing in the periphery — only what is
  equipped (bow, spear, torch). Already applied in play; keep it that way.

## B. Head-look on cloaked figures (third person and other figures only)

- Small look changes turn the **hood first**; the cloak's shoulders shift with it; the
  **torso follows only past ~45°** of yaw. Pitch tilts the hood alone within a smaller range.
- Purpose: a figure clinging to a trunk or wall reads as *looking around* from outside,
  even though the body is pinned. Same rig for the player in third person and for folk.
- Not rendered in first person at all (see A). So the head-look rig only ever has to look
  right from outside.

## C. Aesthetic direction — CHANGE: dark and moody, day included

- The daytime "Frutiger Aero" note above is **superseded**. The whole game is dark and moody
  at every hour. Day is bright *where the sun hits* and deep everywhere else.
- **Lighting model, not a grade tweak:** the sun stays the single directional light doing
  all the work. **Ambient and sky contribution go way down.** Shadows are deep,
  blue-tinted, **hard-edged** (no soft shadows, no PCF blur). High contrast, not low
  brightness. Keep the sun low and raking even near noon — never flat overhead.
- Sky is the most saturated thing in the frame: deep cobalt, bold painted clouds.
- Look-pass checklist (from the screenshot comparison, in priority order):
  1. exposure/grade: cut ambient, pull mids down, saturation up ~30–40 %, blue shadows,
     greens toward forest/teal not mint;
  2. sky: cobalt + painted clouds by day, indigo + baked stars by night — two presets;
  3. trees: leaf-card canopies with ragged edges (see D), trunks are already fine;
  4. texture crunch: nearest filtering, render scale toward 0.5–0.6;
  5. water: darken the base blue, keep a bright scrolling highlight.
  Grade day and night as **two presets**, never one curve through the middle.

## D. Plant generation — full revamp on botanical vocabulary

See **`docs/design/PLANT_SCHEMA.md`** for the locked vocabulary and field list.
Summary of the decision:
- Canopies are no longer blobs. Every species carries a small set of **taxonomic
  descriptors** (leaf outline, margin, venation, arrangement, canopy form, colour tint),
  and a **card builder** draws each species' leaf card **procedurally from those
  parameters at load time**, baked to a shared atlas. Nobody hand-draws leaves.
- **Stylised archetype, not photoreal.** The test: a species is recognisable by silhouette
  or low-res pattern at 64 px. Real taxonomy is the *source*; the output is Melee-clean.
- **Per-species green tint** (a colour multiplier) so a forest is not one green.
- **LOD rule:** distance drops leaf detail but **never smooths the silhouette**. The blob
  is the far LOD we are removing; the ragged edge survives to the horizon.
- **Process:** the schema is locked first (PLANT_SCHEMA.md). The ~1,000 species are then
  filled by parallel research agents, split by family/biome, choosing **only** from the
  fixed vocabulary. The card builder and atlas are built against the schema separately.
  Merging is trivial because the field names never vary.

## E. Amorphophallus — the petiole is the plant

`data/plants/amorphophallus.json` already holds 246 species with a **genus grammar** for
petiole pattern (mottled / spotted / streaked / warty / plain), base hues, two-layer
markings (large blotches + fine dots, confluent low, separating higher), textures
(smooth / warty / hairy), a pink-grey base zone, spathe colours, and `repro.bloom`.
Keep all of it. Changes:
- **Each tuber rolls its own pattern** within the species ranges, seeded per plant
  (kin, not twins). Already the intent of the grammar; make it per-instance, not per-species.
- **Bloom is a tuber-maturity gate, not a fixed interval.** Replace `interval_years` with:
  the tuber accumulates mass over good leaf seasons (soil, light); past a species mass
  threshold it *may* bloom; blooming spends the tuber, which drops back. Rich soil → yearly
  blooms; poor soil → skips. The designer grows these and confirms mature tubers can bloom
  annually. Needs seasons (F) and soil (Phase 5).
- **Bloom scent is a pheromone source** on the wind field: carrion mimics draw blowflies,
  carrion/dung beetles, drosophilids; the bloom self-heats to throw scent further. Insects
  drawn in feed whatever eats insects — a real event in the ecology.
- Record per species where known: height, inflorescence description, pollinators, bloom
  duration (`repro.bloom.days`). Spellings: *A. hewittii*, *A. paeoniifolius*.
- Timing runs on the game clock (1/10 real time), like everything else.

## F. Seasons — LOCKED, and the day split becomes derived

- **Axial tilt 23.5°.** **Year = 365 game days = 36.5 real days** (144 min is exactly one
  tenth of a real day, so the whole calendar runs at 10×). Game week ≈ 16.8 real h, month
  ≈ 3 real days, season ≈ 9 real days.
- **Four seasons — winter, spring, summer, autumn.** Between each pair a **transition**
  of ~2 real days (~20 game days), with ~7 real days (~71 game days) settled in between.
  Transitions are where the drama is (leaf turn, first frost, thaw, mass bloom) — make them
  generous and visible, like dusk and dawn are.
- **The 60/18/48/18 split is now the equator/equinox reference, not a rule.** With tilt,
  day and night lengths must **derive from astronomy**: sun declination follows the tilt
  through the year; daylight at a point is a function of **latitude** and day-of-year.
  Equator: ~60/48 all year. Temperate: summer solstice ≈ 78 day / 30 night, winter the
  reverse. High latitudes: **true midnight sun and true polar night** (a 144-minute "day"
  with no sun) — realistic, per the "world surprises its creator" principle.
  Dusk/dawn also derive: twilight lasts as long as the sun takes to cross `twilight_deg`
  (10°) — short at the equator, long and lingering at high latitude. 18 minutes is what the
  equator gets, not a constant.
- **The moon follows the same geometry:** winter full moons ride high, summer ones low.
- **The 144-minute day is fixed**; only its division varies. `day_length_min` stays 144;
  `phase_min` becomes the equinox reference the astronomy is calibrated against.
- Consequence: because spawn biome is random, a tundra spawn and a rainforest spawn get
  different calendars. That is a feature; "night is 48 minutes" is no longer a promise.

## G. Photoperiod, latitude and elevation in the ecology

- Add a **`photoperiod`** field per species: `short_day` (flowers when daylight drops
  below `threshold_h` — cannabis, chrysanthemum, poinsettia), `long_day` (bolts/flowers
  when daylight exceeds it — lettuce, many temperate grasses), or `neutral`. Cannabis
  already carries photoperiod data in `cannabis.json`; map it to this field. Autumn is
  when cannabis flowers because the days shorten — never scripted.
- **Latitude** now matters to plants twice: through temperature (already) and through
  **day length / growing-season length** (new). **Elevation** already cools via the lapse
  rate in `planet_const.gd`; add its effect on growing-season length. **Longitude** only
  shifts local solar time — no ecological effect on its own.
- These feed the tuber-maturity gate (E), the soil layer (Phase 5) and seasons (Phase 4).

## G2. Soil is a first-class spawn check — LOCKED

- Every plant placement checks **temperature × rainfall/moisture × soil type** as three
  co-equal gates before anything else (then altitude, water proximity, light, photoperiod).
  Soil is **not** a soft multiplier: a species outside its soil set does not spawn.
- The terrain build must **mark soil type explicitly** per point, differentiated and
  readable by plant checks and by the ecology. `geology_pass.gd` already assigns
  rock/soil (basalt, sand, alluvium, clay/peat, till, karst, sandstone, granite); keep
  that and add the Phase 5 layer on top: **depth**, **fertility/organic content**,
  **drainage**, **pH class** (acid / neutral / alkaline — bogs vs karst limestone), and
  **salinity** (coasts, salt flats). Fertility is fed by `flora.litter`, dead wood decay
  (dead-wood section above) and animal waste; it is what the Amorphophallus tuber gate reads.
- Plant data: `soil` stays, but it becomes a **set of allowed soil classes** plus optional
  preferences (e.g. cypress: clay/peat + alluvium, waterlogged; pine: sand/till, acid,
  well-drained; Trichocereus: rocky/till, alkaline, sharp drainage). The data-fill agents
  add `soil` in this form using the same allowed-value rule as the leaf vocabulary.
- Why: without a real soil gate the same forest appears on every substrate and the
  food web has nothing to stand on. Ecosystems function because soil differs.

## H. Housekeeping

- Pronunciations of *hewittii* and *paeoniifolius*: the designer corrected the assistant
  twice on the call; phonetics to be added when supplied.


---
---

# Session 3 addendum — 27 Sept 2026, late (scale, momentum, HUD)

Confirmed decisions. Where these contradict anything above, these win.

## I. Planet scale → one tenth of Earth — LOCKED

- `FULL_CIRCUMFERENCE_M` goes from 400 km (1/100) to **4,000 km (1/10)**. The world is now
  1/10 in every axis: horizontal 1/10, height already 1/10 (`HEIGHT_SCALE` 0.1), and time
  1/10 (144-min day). One consistent ratio.
- **Biome size does NOT scale with the planet.** Biome patch size is a noise-frequency knob,
  independent of circumference. Keep patches roughly their current ~10 km scale and raise
  the biome-noise frequency so there are ~100× more of them — which is more Earth-like
  anyway (Earth has dozens of temperate forests, not one).
- **Consequence to check:** height stays the same while the land spreads 10× wider, so
  slopes become 10× gentler than now — true proportion, but mountains will read as long
  hills rather than walls. Decide by eye after the change; the fix, if wanted, is a modest
  horizontal exaggeration of relief in the terrain pass, not a change to `HEIGHT_SCALE`.
- **Numbers for reference:** at walk (5.5 m/s) circling the planet is ~200 real hours;
  at the momentum cap (below) ~33 hours. A 10 km biome is ~30 min at walk, ~5 min at cap.
- **Generation does not happen all at once — already true, keep it so.** Terrain is chunked
  around the player with a floating origin and a far shell; the planet-wide passes (climate,
  hydrology, biomes, weather at `RES` 10) run on coarse cube-sphere grids. At 10× the
  circumference keep those grids at a **fixed cell count** (coarser per km) and refine
  locally from noise; do not scale cell counts with area. Rivers: keep the trunk logic on the
  coarse grid; tributaries emerge locally as now. The dev postage stamp stays for testing.
- Scale is now the *reason* the movement is fun, not a problem: crossing a biome is a
  skill test.

## J. Momentum ceiling and asymmetric gravity — LOCKED

- **Base speeds unchanged:** walk 5.5 m/s, sprint ~8.8 m/s (`movement.json`). Skill, not
  the floor, is what makes you fast.
- **Ceiling of a perfect chain: 120 km/h = 33.3 m/s (readout rounds to 75 mph).** This is
  not a hard wall: it is where trees stop reading as objects at draw distance and where
  impact damage is reliably lethal, so risk makes the player back off. Set `roll_max_mps`,
  `chain_cap` and swing `max_mps` sanity values just above it (~36 m/s). Reference: anime
  shinobi at full tilt are usually reckoned at 30–50 m/s; 33 is the readable bottom of
  that band.
- **Asymmetric gravity.** The player is an Earth-strength body on a 1/10 planet:
  - **Rising:** low gravity, in the spirit of a 1/10-mass world — jumps ~10× Earth height
    (a 0.5 m standing hop → ~5 m; a running bound at sprint → ~50 m), so the player can
    reach branches, ledges and canopies.
  - **Falling:** gravity snaps back to **Earth strength or stronger** (current
    `gravity_mps2` 19.6 = 2× Earth is fine) so there is no float: the arc is a shark fin —
    long lazy rise, sharp drop, exactly how the anime draws it.
  - Implement as two gravity values: `gravity_up_mps2` (applied while vertical speed > 0)
    and `gravity_down_mps2`. Tune the up value so a sprint bound lands near 50 m.
  - **Real falling physics on the way down:** speed builds with fall height until
    terminal velocity (~50 m/s for a body on Earth; keep it in that range). A ~50 m fall
    already reaches the momentum cap, so the roll (above) is the only safe landing from
    height. Fall damage as before.
- **Branch bounce.** Same tech button, same 14-frame window: land on **top** of a branch
  or ledge and tap within the window → a perfect landing that **adds** momentum (downward
  speed converts to forward, plus a bonus), like the roll but from a branch. Miss the
  window → normal landing, no gain. This is the canopy chain: bounce → bounce → swing.
- **Alternating bounds.** Every landing/bounce alternates feet — left, right, left — like a
  real runner; the cloak hem and torso lean follow whichever leg is planted, so the whole
  body lilts in rhythm even though the legs are hidden. Same reused crouch pose, mirrored.
  **Camera never bobs with it** (first-person lock rule above).

## K. Momentum in combat — LOCKED

- **Arrows inherit the archer's velocity.** A shot from mid-swing or mid-bound flies
  differently from a standing shot; movement skill becomes shooting skill.
- **Spear at speed = impact weapon.** A spear thrust or running strike deals damage by
  closing speed, the same curve as impact damage; at the top of the momentum band it is
  an instant kill. A spear tip is a wall with a point on it.
- **It cuts both ways:** whatever kills at speed kills *you* at speed — a missed thrust
  into a trunk is impact damage on you.
- **Multiplayer / PvP is a someday**, not a plan: momentum-based canopy PvP would be
  unusual, but netcode for fast physics is brutal. Build single-player in a way that does
  not rule it out (deterministic tunables, state that could be replicated), nothing more.

## L. Two always-on HUD readouts — Phase 1

Both **on by default**, each **toggleable in the settings menu**, both small and quiet.
- **Speedometer:** shows **mph and km/h** (and m/s in dev builds). **Dim when slow,
  brightens progressively with speed** so it only asserts itself when you're moving fast.
- **Clock:** a **watch-face**, not digital. **12-hour inner ring, 24-hour outer ring** (old
  pocket-watch / field-watch style) so both readers get it at a glance. A game hour is
  exactly 6 real minutes, so the hand sweep is just brisk. **Mark dawn and dusk on the
  outer ring**, and let those marks **move with the season and latitude** (derived
  day/night, addendum §F). This is a HUD aid, not an in-world object; the world itself
  has no clocks.

## M. Starting kit — LOCKED

- On a **new game** the player always spawns at the opening campfire carrying:
  **a spear, a bow with 20 arrows, and a fishing pole.** Nothing else.
- The fishing pole is the third tool of the fish / forage / hunt loop (Phase 10) and the
  first fishing item in the game; fishing itself lands with Phase 10, but the pole exists
  in the inventory from day one.
- **On respawn after death you wake with nothing** — the kit is on your corpse with the
  rest of your gear (corpse rule above). The walk back is the penalty; the fire is safe.
  (Designer's call to confirm: if this feels too harsh early, the fallback is that the
  folk who found you leave a spear by the fire — one item, not the kit.)
- **Arrows stick in whatever they hit** — ground, trunk, ruin, or the **body part of a
  creature or figure**, riding along with it as it moves (already built: `arrow.gd`
  parents the arrow to the hit collision shape; take it back with E within `pick_m`).
  Keep this; it is the visual record of a fight. Arrows are recoverable from anything
  they stuck in, including a dead creature; an arrow that hits a creature has a small
  chance to break (`break_chance` in `combat.json`, tune later).

## N. Hold left click to charge — one rule for all three tools — LOCKED

Left click is the **charge** button, the way right click is the **tech** button: hold to
build power, release to act. Power sets both **strength and trajectory**.
- **Bow:** already built (`bow.gd`): hold to draw, Minecraft-style power curve over
  `draw_s`, release to loose; a longer draw is a faster, flatter, harder arrow. Keep.
- **Spear:** already built (`spear.gd`): tap = thrust, hold = raise; longer raise = faster,
  flatter, harder throw. Keep. (Momentum from §K stacks on top via `inherit_velocity`.)
- **Fishing pole — new:** hold to wind up, release to **cast**; charge sets **cast
  distance** (and arc): a tap drops the line at your feet, a full charge reaches
  `cast_max_m` (~25–30 m). Aim with the look direction. The line lands on water or not;
  reel in with the same button held (or a second input, tune by feel). Fishing itself
  (bites, fish species by water temperature, catch) is Phase 10; the cast is Phase 1 so
  the pole is usable from the first play.
- **Charging never slows you down.** Remove the bow's walk-slowdown while drawing
  (`bow.gd`); no tool reduces speed or momentum while charged. A charge is **held
  through techs** — right click does not cancel it.
- **Charging makes momentum harder to keep — and the difficulty is purely the
  player's own multitasking. No artificial handicap.** Every tech stays available with
  its normal window while a charge is held; nothing is disabled, nothing tightens, aim
  does not drift. The game simply asks for two things at once:
  - **Left mouse = the item in hand** (hold to charge, release to act).
  - **Right mouse = movement** (the tech button: wall jump, cling, bounce, swing, roll
    timing).
  A player focused on the weapon hand will miss a movement input, and a missed tech at
  speed is the usual lethal impact. That is the whole skill: keeping both hands honest
  at 120 km/h. The game never nerfs you for trying.
- The charge gauge, if any, is the same tiny arc for all three tools so the player
  learns one gauge.
- Add to `data/combat.json`: a `fishing` block — `wind_s`, `cast_min_m`, `cast_max_m`,
  `line_max_m`, `reel_mps`, `inherit_velocity` (so casting mid-bound throws the line
  further, same as arrows).

## O. Master shinobi — momentum-harnessing NPCs (Phase 8+, design locked now)

- A rare, hostile (or neutral-until-provoked) **cloaked figure** that is a **master of
  the momentum system**: chains wall jumps, bounces, swings and rolls at or near the
  120 km/h ceiling, **kites the player and their comrades**, and fights on the move with
  **aimbot-grade** spear throws, arrows, and fishing-pole casts (a cast line that snags,
  trips, or reels the player off a branch is their signature trick).
- **Same rig, same rules (Falcon/Ganondorf).** They use the player's rig, the player's
  animation set, and the **same tunables in `movement.json` and `combat.json`** — same
  gravity, same tech windows, same impact damage, same terminal velocity. No cheating
  physics, no ignoring gravity, no teleporting. Their edge is *execution*: perfect
  windows, perfect release timing, perfect reads of your arc. They can **die the same
  way you can** — a master who misjudges a rotten branch snaps it and eats the impact.
- **Readability.** Their approach is heard before it is seen: cloak whip, branch creak,
  the alternating-foot rhythm at speed. Their palette is distinct (a tribe's colours or a
  lone black-and-ash look); silhouette is the player's, which is the point.
- **AI needs:** this is a Phase 7/8 creature behaviour (steering, pathfinding through
  `BranchGraph`s, target prediction). Build it **after** the player's momentum system is
  finished and feels right, because the NPC must drive the *same* code paths — if the
  player's chain works, the master's chain is a planner over it, not a new system.
- **Why it matters:** it is the proof that the movement system is a combat system, and
  the mirror the player measures themselves against. Beating one is the game's
  unspoken mastery test. Groups of them are the only "raid"-tier threat the game needs.
