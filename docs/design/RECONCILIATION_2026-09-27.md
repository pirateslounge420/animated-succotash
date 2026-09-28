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
    to about **0.10–0.13 s (6–8 f)** — Melee-style: a deliberate tap on contact, not a
    grace period. Shorten `kick_s` from 0.18 to about **0.13–0.16 s (8–10 f)**: first
    ~2 frames are the crouch pose, then the kick, no ease-in. Tune by feel from there.
  Keep `angle_deg` and `min_wall_steepness` as they are.

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
    run speed and capped by `roll_max_mps`. Higher fall → longer roll → faster exit.
    This is what lets the player chain wall-jump → drop → roll → sprint and "sling"
    through terrain. Roll exit feeds straight into the ninja-run lean.
  - A **missed** roll (no input, or outside the window) is the existing squat and
    full fall damage. Mistimed input during the squat does nothing — no punish
    beyond the normal landing.
  - Roll length scales with fall height (`roll_len_m` per metre fallen, capped).
    During the roll: no steering, no jump, i-frame-free (creatures can still hit).
  - **Animation:** reuse the crouch pose → tuck → the cloak does the rest. The roll
    itself is a rotation of the body root with the cloak wrapping; no new rig.
  - Add to `movement.json`: a `roll` block with `window_s`, `safe_m`, `max_m`,
    `damage_scale`, `carry`, `max_mps`, `len_per_m`, `len_cap_m`.

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
