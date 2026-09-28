# Design reconciliation — 27 Sept 2026

Decisions made in design chat, checked against what the repo actually contains.
Purpose: stop new work duplicating existing systems. Read this before adding anything
from the "Ambient Sandbox RPG" blueprint.

Rule of thumb: **if a system is in section 1, change its data; if it's in section 2,
put the work in the named phase of `WORLD_SYSTEMS_SPEC.md`; only section 3 is new.**

---

## 0. Locked decisions (new or changed)

- **Day/night cycle: 144 min real time — day 62 / dusk 20 / night 42 / dawn 20.**
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

---

## 1. Already built — adjust data, do not re-implement

| Decision | Where it lives | Status / action |
|---|---|---|
| Day/night cycle | `data/sky/day_cycle.json`, `scripts/sky/day_cycle.gd`, `sky_system.gd` | **Values changed to 144 / 62-20-42-20 in this commit.** No code change. |
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
