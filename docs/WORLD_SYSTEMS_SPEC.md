# WORLD SYSTEMS SPEC — v3 (Godot project, aligned to commit `fe6ee3e`)

**Read this whole file before touching code. It is the source of truth.** Where it conflicts with `DESIGN.md`, `README.md`, or anything in the repo, this file wins. Then read `docs/PROGRESS.md` to find the current phase, and work on that phase only.

Ordered the way it is *used*: how to work → where the project is → what to do now → architecture → one card per phase → reference tables at the back.

---

# PART A — How we work (read every session)

### A1. Session protocol (Claude Code, every time)
1. Read this spec, then `docs/PROGRESS.md`. State in one line: *"Phase N. Last sign-off: ___. Any agents still working in copies: ___."*
2. **Audit first, build second.** Before any change, list in plain English what you found and what you propose, then stop and wait for "go."
3. Build only the current phase's deliverable. Nothing from later phases — not even scaffolding.
4. Every change ships with **a visible way to verify it**: screenshot, recording, or a debug overlay on a hotkey. If it can't be seen, it isn't done.
5. **Parallel agents:** if restyle/set-piece agents are working in separate copies, their changes are audited against this spec (Appendix R1 for anything visual) *before* merging. Nothing merges blind. One phase = one branch; land it, sign off, then start the next.
6. End of session: prepend 3–6 lines to `docs/PROGRESS.md` — what changed, what's verified, what's next, open questions. Commit with the phase number in the message.

### A2. Standing rules
- **The designer does not code.** Explain every change in one plain-English paragraph: what it reads, what it writes, what changes on screen.
- **Shared state, no direct calls.** Systems read the `World` autoload and write only the fields they own. Systems never call each other's methods to change state.
- **Arrows point down.** A system may read anything above it in the emergence stack (C2); it never writes upward.
- **Nothing hand-placed.** Every terrain feature, plant, animal, nest, and camp must be derivable from the seed plus the passes above it. Pre-built nests, established territories, and half-grown crops are produced by *running the simulation forward at generation time*, not by placing them.
- **Data over code.** Species, plants, biomes, and weather odds live in `data/`. The designer edits tables; Claude Code edits logic. Any tunable number goes in a table. Keep the existing files (`data/biomes/*.json`, `data/creatures/creatures.json`); extend their schemas, don't rename them.
- **Ask before inventing.** If a rule or value isn't in this doc, propose it and wait. (A past prototype invented an unwanted breath meter. Don't.)
- **Fewer polygons, softer textures, moodier light.** When unsure how anything should look, that is the answer — never "more pixels" or "sharper."
- **Few things that matter.** No feature that adds management without changing a decision. No bloat.

### A3. The two-prompt rhythm (designer)
1. Paste the phase's **Prompt A**. Claude Code audits, proposes, waits.
2. Say *"Go. Show me [the deliverable] when done."*
Look at the screenshot/recording. Right → *"Sign off Phase N."* Wrong → describe it in plain words and "Go" again. Never approve on a description.

### A4. Dev settings (always on during development; one file, `data/dev.json` or project settings)
- `DEV_DAY_LENGTH = 20 min` (game: 120 min).
- `DEV_SEED` fixed, so before/after is apples to apples.
- `DEV_POSTAGE_STAMP`: a fixed-seed mini-planet that contains one of every major biome band, generating in seconds. Full 400 km planet for milestone checks only.
- Debug overlays on hotkeys: time/moon, temperature, moisture, biome, pressure + wind arrows, creature population per region, camp food/population. The existing **Map overlay** already shows biome/elevation/temperature/rainfall/live weather — extend it rather than building new.

---

# PART B — Where the project is (audit of `fe6ee3e`)

The build is far past "prototype." Most layers of the stack already exist. The job is now **alignment and gap-filling**, not building from zero.

| Stack layer | Exists in repo | Aligned to spec? | Gap / risk |
|---|---|---|---|
| Geology / terrain | `planet/passes/terrain, geology`; cube-sphere 400 km; continents, mountains, ravines, cliffs, cave mouths | Mostly | No **tectonic skeleton** — mountains not placed by plate boundaries |
| Water | `passes/hydrology`; `river_network` (widths, rapids, waterfalls); rivers swell in storms | Yes | Verify rivers carry a **current direction** boats/swimmers can feel |
| Energy (clock/sky) | `sky_system` 2-hour day, moon phases, real sun+moon lights; `astro`; `lunar_mansions`; `cloud_layers` | Mostly | Day split must be **45/20/35/20**; verify smooth lerps; lunar cycle ~29.5 days |
| Climate | `passes/climate`; `weather_sim` grid with wind | Partly | Verify wind is **pressure-gradient** driven; verify **ridge-blocked moisture** (windward wet / leeward dry) |
| Weather | rain, snow, storms, lightning, thunder; clouds driven by weather | Yes | **Seasons do not exist** |
| Soil | — | No | No fertility layer; `vegetation_placer` uses suitability/shade/clumping only |
| Flora | `species_db`, `vegetation_placer`, 25 plant meshes at 3 LODs; 51 biome plant lists | Mostly | 51 biomes in data vs **52** in design — reconcile. Foliage sway must read live wind |
| Fauna | `creature_spawner` (spawn/despawn near player), behaviors (wander/flee/drink/perch/hunt/attack), `territories` for mythicals, `sound_synth` | Partly | Spawner is **proximity-based, not population-based** — no regional ledger, no food web, no reproduction, no nests |
| Society | `camps` (folk + guards + chatter), `encampment` (elder, hunter), `campfire`; ruins | Partly | Camp folk don't forage/hunt; no cooking; no economy |
| Persistence | — | No | Not started |
| Look | `post_grade` (sharpening, **dithered color depth**, night tint); `look_textures` procedural; 15 shaders | **No** | Dither + sharpen is a PS1 look, not GameCube. Likely the main cause of the "pixely" complaint. Check texture filtering too |
| Player | walk/sprint/crouch/jump/swim/climb, 1st/3rd person, health/death, bow, footsteps by material, tree contact | Mostly | Rebind controls (C5); verify **hitboxes** on everything; add **spear**; audio must be 3D proximity |

**Cut or hold:** Rare-event dice, sky events, magic sites, ruins, sculpted bodies all stay as they are — don't touch, don't expand.

---

# PART C — What to do now

## Current phase: **Phase 1 — Player feel, hitboxes, audio** (card in Part E)

Phase 0 — Look & Light was signed off on 2026-09-26 (the dusk river shot). Its notes stay below for reference.

Target: **late-90s/early-2000s console 3D, saturated dark-fantasy**. Low-poly but rounded. See Appendix R1 and R1a.

**Suspected causes of the blocky look, to confirm in audit:**
1. `post_grade` — dithered color depth and sharpening. Replace with: subtle film grain, slight color bleed, mild fog haze, viewport render scale ~0.75–0.8 for 480p softness. Keep the night tint.
2. Texture filtering — procedural `look_textures` may be sampled nearest-neighbor. All world materials → **linear with mipmaps** (`texture_filter = LINEAR_MIPMAP`).
3. Foliage — check that leaf clusters are alpha-cutout quads/low-poly clusters, vertex-colored, not blocky.
4. Terrain normals — smooth, not faceted; no stepped edges.
5. Environment — glow/bloom off, SSAO off, MSAA 2x at most.
6. Sky — 45/20/35/20 split, smooth lerps of sky/sun/ambient/fog through dawn and dusk.

**Done when:** a dusk river screenshot could sit beside the R1a references and belong, and a 20-min time-lapse shows sun and moon crossing with no snapping.

**Prompt A (paste this):**
> Read docs/WORLD_SYSTEMS_SPEC.md and docs/PROGRESS.md. We are in Phase 0. First, tell me exactly what the restyle and set-piece agents are changing in their copies, and whether it matches Appendix R1. Then audit the current render path against R1 and the six suspected causes in Part C — post_grade, texture filtering, foliage, terrain normals, environment settings, and the day split — and list in plain English where it diverges. Propose a fix order. Don't change anything yet.

---

# PART D — Architecture

### D1. World scale (locked)
Spherical wraparound cube-sphere, **400 km** circumference, relief ≈ 1/10 Earth, floating origin around the player. Already built — keep it.

The planet stays 400 km (1/100 Earth) through Phase 11; it may scale to 1/10–1/30 Earth later because boats will be the main way to travel. Therefore: everything global lives in PlanetData at coarse resolution; everything the player sees is derived per chunk from seed + PlanetData and discarded on stream-out; nothing at detail scale is ever stored except region deltas (ledger counts, nests, carcasses, scars, memories, culture). Scaling the planet up must change only radius/resolution constants and PlanetData's memory, never the streaming or detail code.

### D2. The emergence stack (mirrors Earth; the dependency order)
```
1. Geology    seed → tectonic skeleton → heightmap → rock type      (static)
2. Water      oceans, lakes, rivers (with current), groundwater     (static shape)
3. Energy     sun & moon, day length by latitude                    (sky_system, astro)
4. Climate    temperature, pressure, wind, humidity                 (climate pass, weather_sim)
5. Weather    rain, snow, fog, storms, seasons                      (weather_sim, weather_fx, storm_fx)
6. Soil       fertility = f(rock, moisture, slope, plant litter)    (NEW)
7. Flora      producers by tolerance: canopy / understory / ground  (species_db, vegetation_placer)
8. Fauna      food web: insects → small → mid → apex; fish; scavengers → soil   (creature_*, NEW ledger)
9. Society    camps eat fauna + flora, burn wood                    (camps, encampment, NEW)
```
Soil and the food web are the two layers that let the world balance itself instead of being scripted.

### D3. World state — the shared spine (on the `World` autoload)
Each field has exactly one owner: the only code that writes it; everything else reads. Cross-layer effects (camp hunters taking deer, the player killing something, a fire reaching a region) are written as `world.events` records and applied by the field's owner, never written directly (R6.6).

**Today, as in the code** (`cell` = PlanetData cell, `face·res² + j·res + i`; `res` 96 on the full planet, 48 on the stamp):

| Field | Lives in | Owner (writes) | Per cell / notes |
|---|---|---|---|
| seed | `World.world_seed` | World (from `data/dev.json` or `main.world_seed`) | |
| grid | `World.planet` (PlanetData): `dir`, `lat`, `neighbors` | PlanetData | vec3, f32, 8×i32 |
| geology | `World.planet`: `elevation`, `slope`, `rock` | terrain + geology passes, once at generation | f32, f32, u8 |
| water | `World.planet`: `water`, `water_level`, `flow_to`, `flow_order`, `flow_accum`, `salinity`, `coast_dist_km`, `water_dist_km` | hydrology pass, once | u8, f32, i32, i32, f32, u8, f32, f32 |
| climate | `World.planet`: `temp_c`, `temp_swing_c`, `precip_mm`, `moisture`, `fog`, `wind_avg` | climate pass (from WeatherSim spin-up averages), once | f32 ×5, vec3 |
| biome | `World.planet`: `biome` | biome pass, once | i32 (BiomeTemplates id) |
| live weather | `World.weather` (WeatherSim, its own grid of 6×10×10 = 600 cells, ~10 km on the full planet): `pressure`, `temp`, `humidity`, `wind`, `precip_rate`, `rel_humidity`, `storm`, `storm_level`, `synoptic`, `clear`; `avg_*` from spin-up | WeatherSim, each in-game quarter hour | |
| eased local weather | `main._weather_eased` | main.gd, each frame | ⚑ not on World |
| clock | `World.days` (days since start; the fraction is time of day), `World.day_length_s` | World (`_process`); length from DayCycle / `data/dev.json` | 45/20/35/20 phase warp in Astro + DayCycle |
| sky | SkySystem: `sun_dir`, `moon_dir`, `sun_elevation_deg`, `moon_elevation_deg`, `daylight`, `moonlight`, `cloud_light_dir`, `magic` | SkySystem, each frame | ⚑ a node under main, not on World |
| ripples | `World.ripples` | ripple system (Phase 1) | interface `scripts/water/ripples.gd`; simulation in progress |

PlanetData is ~119 bytes per cell: 6.6 MB on the full planet, 1.6 MB on the stamp. Derived caches (rebuilt from seed + PlanetData on load, never saved, not state): RiverNetwork (`ChunkManager.rivers`), mythical territories, ruin and camp sites, encampment candidates, the species tables.

**Proposed, not built.** One object per stack layer on World, each holding packed arrays indexed by region id (R6.4), in PlanetData's style. Ledger fields are written only inside `tick_region` (R6.2); "owner" names the system whose rules run there.

| Field | Home | Per region | Owner | Phase |
|---|---|---|---|---|
| season | derived from `World.days` and `year_days` in `data/sim.json`; nothing stored | — | World clock | 4 |
| regions | `World.regions`: `cell_to_region` (per cell), `center`, `area_km2`, `neighbors` | i32 per cell; vec3, f32, 8×i32 | ecology/ledger, at generation | 6 |
| soil.fertility | `World.soil.fertility` | f32 | ledger (soil rules); the soil pass seeds it | 5, live from 6 |
| soil.carcass | `World.soil.carcass` | f32 (kg) | ledger | 7 |
| flora.biomass[stratum] | `World.flora.biomass` | 3× f32 | ledger (flora rules); vegetation_placer seeds it | 5, live from 6 |
| flora.snags, flora.logs | `World.flora.snags`, `World.flora.logs` | u16 each | ledger; Phase 5 fills them from tree ages | 5 |
| flora.cavities ⚑ | `World.flora.cavities` | 2× u8 (free, used) | ledger | 6 |
| flora.burn_scar | `World.flora.burn_scar` | u16 (days since burn, 0 = none) | ledger (fire) | 8 |
| water level (seasonal) | `World.hydro.level_offset` (added to `planet.water_level`) | f32 (m) | ledger (living water) | 8 |
| fauna.pop[species] | `World.fauna.pop` | S× f32 | ledger | 6 |
| fauna.sex_ratio[species] | `World.fauna.sex_ratio` | S× u8 | ledger | 7 |
| fauna.genome_mean[species][gene] | `World.fauna.genome_mean` | S×G× u8 (0–1 in 1/255 steps) | ledger | 7 |
| events | `World.events`: per region a ring of the last ~50 records {day, kind, params} + a per-kind summary (count, first day, last day) | ~1.1 KB | ecology/events: append-only, every system adds records through it | 6 |
| society[camp] pop/food/roles/culture | `World.society`: packed arrays per camp id (camps are few) | per camp: a few f32; culture {fish, hunt, forage, wary, range} 5× f32 | camps | 9 |
| creature.memory[] | on each NEAR creature node; saved as a region delta in `World.fauna.memory_delta` (sparse, by region) | ≤5 × {what, where, day, good/bad} | creature | 10 |

**Regions: PlanetData cells or a fixed coarsening.** Option A: one region per cell. Option B: a fixed k×k block of cells within a cube face, k in `data/sim.json`. Memory for the proposed per-region fields at a planning roster of S = 64 species (25 today), G = 15 genes, 3 strata and ~24 event kinds is about 2.4 KB per region (the events ring and genome means are most of it; 5.3 KB if genomes are f32):

| | Regions | Ledger memory |
|---|---|---|
| Full planet, A (cells, ~1 km) | 55,296 | ~130 MB |
| Full planet, B k=2 (~2 km) | 13,824 | ~33 MB |
| Full planet, B k=4 (~4 km) | 3,456 | ~8 MB |
| Stamp, A (cells, ~208 m) | 13,824 | ~33 MB |
| Stamp, B k=4 (~830 m) | 864 | ~2 MB |
| 10× planet with ~1 km cells, B k=4 | 345,600 | ~830 MB dense (see ⚑) |

Proposed: **B, k = 4.** It keeps the ledger small and, above all, keeps the warm start affordable: 50–200 years of `tick_region` over 3,456 regions is 16× less work than over 55,296. Rules work in densities per km², so the region size can change later without retuning. (At 10× the planet PlanetData itself is ~660 MB at ~1 km cells, so a bigger planet also means coarser cells.)

⚑ Unsure / flagged:
- Sky and eased weather are not on World today (a SkySystem node and main.gd). Proposed: publish read-only copies as `World.sky` and `World.weather_local` so systems never reach into main.
- `soil.fertility` and `flora.biomass` are seeded by generation passes (Phase 5) but change live from Phase 6 (grazing, carcasses, fire, floods), so their live owner is the ledger.
- `flora.cavities` isn't in the designer's list, but the cavity chain (Phase 6) needs somewhere to keep cavity slots.
- A 10× planet can't hold dense ledger arrays; FAR regions would store nothing until first simulated (regenerated deterministically per R6.5, then kept as a delta). That needs a region-id indirection from Phase 6 so storage can go sparse without touching `tick_region`.
- Snags from chopping or fire aren't derivable from tree age; they're per-tree region deltas. D1's list of stored deltas may need "felled and burned trees".

### D4. Data schemas (extend existing files; don't rename)
```
data/biomes/<biome>.json   + weather_odds, mythic_creature, (keep plant lists; add per-plant stratum)
plant                      { id, stratum(canopy|under|ground), temp_min/max, moisture_min/max,
                             soil_min, slope_max, sway_stiffness, seasonal_color,
                             lifespan_years, snag_years, log_years }
data/creatures/creatures.json
creature                   { id, trophic(insect|herbivore|small_pred|apex|scavenger|fish),
                             diet:[ids or "seeds"|"insects"|"leaves"|"fish"], temp_min/max, water_bound,
                             activity(day|night|dusk), temperament(friendly|skittish|aggressive|pack),
                             light_response, herd_min/max, nest:{type, site}, reproduce_days,
                             biome_lock (mythic only), rare_variant }
```

### D5. Player & controls (locked)
- **Sprint = Minecraft-style:** tap W, then tap-and-hold W again quickly (double-tap window ~0.3 s). No Shift-to-sprint.
- **Shift = crouch/sneak.** Sneaking is quieter: smaller noise radius for creatures' hearing.
- **Jump** stays. Momentum-based movement stays (F-Zero GX / Melee spirit).
- **Everything has a proper hitbox.** Player, creatures, trees, ruins, arrows, spear — no ghost-through, no invisible walls. Audit collision shapes against visible meshes.
- **Weapons for now:** bow and arrow (exists) + **spear** (thrust, throw, retrieve). Nothing else.
- **Audio is proximity-based:** every world sound is a 3D player with distance attenuation and direction; howls, calls, camp chatter, storms all fall off with distance. Player noise (footsteps, sprint, bow, spear) is what creatures hear.

---

# PART E — Build phases (one card each; do not reorder)

Each card: **Touches / Do not build / Done when / Prompt A.** Sign-off only on the visible deliverable.

## Phase 0 — Look & Light  (signed off 2026-09-26)
See Part C.

## Phase 1 — Player feel, hitboxes, audio  ← current
- **Touches:** `player/*`, `core/controls`, `project.godot` input map, `creatures/sound_synth`, audio players, `plant_meshes`, `tree_contact`, `World.ripples`; for the D5 hitbox and sound audits also `terrain_chunk` (tree colliders), `vegetation_placer`, the foliage and water shaders, `ruin_builder`, `camps`, `campfire`, `encampment`, `creature`, `creature_spawner`, `creature_species`, `creatures.json`, `weather_fx`, `storm_fx`, `sky_events`.
- Implement D5 in full: double-tap sprint, Shift sneak with reduced noise radius, hitbox audit on player/creatures/trees/ruins/projectiles, spear (thrust/throw/retrieve), all sounds 3D with attenuation.
- **(i) Branch graph:** canopy trees get individual branch meshes instead of a leaf blob; each tree exposes a branch graph — handhold points plus which ones are reachable from which — generated deterministically from seed + tree position, NEAR only.
- **(ii) Climbing:** the player climbs trunks and shimmies along thick branches: slow, effortful, no swinging; extend `tree_contact`.
- **(iii) Monkey:** a gibbon-type monkey rig that brachiates along the branch graph — arc-and-release with momentum, next handhold chosen by reach and swing arc; monkey-only; it goes in R3's warm–wet band.
- **(iv) Ripple system, Night Rider, Pond Crawler** — the designer's spec, verbatim:
> Two new creature templates, plus the ripple system they depend on. Add both to `data/creatures/creatures.json` under the existing schema; nothing spawns until Phase 6, but the movement rigs and ripple system are Phase 1 work.
>
> Both creatures and the ripple rings follow Appendix R1/R1a exactly — crunchy noisy textures on smooth rounded shapes, bodies tinted into the night ultramarine, the eye glows as the single accent (#2A6AFF for the crawler's eye, #FF2A2A for the riders' eyes), nothing pure black, water flat and dark with no sky reflection. If a creature would not sit beside the R1a reference stills and belong, it isn't done.
>
> **Ripple system.** Any water surface keeps a small ripple height buffer (~256×256 per nearby water chunk) that the water shader reads for surface normals. Anything that touches or moves through water — player, creatures, dropped items, arrows, rain drops, falling leaves — writes a splash into that buffer at its contact point, sized by the object's mass and speed. The buffer propagates and decays each frame so rings spread and fade, and rings from separate sources overlap. Every creature and the player registers contact points (feet, hands, hooves, hull); a body moving through water drags a continuous wake, not repeated splashes. Only simulate near the camera; fall back to the static wave shader at distance. Rings read as soft painted bands. Write the buffer to WorldState so other systems (fish fleeing disturbance, later) can read it.
>
> **Night Rider** — trophic: mythic, biome_lock: boreal/taiga, activity: night, temperament: aggressive, light_response: none. Two riders on horses, always a pair, the second trailing two body lengths and out of phase. Gait: slow four-beat walk only, never trot or gallop, tiny head bob, horse heads dip on front steps. Foot contact is soft — no snow spray. Momentum: heavy, slow to turn. The only light on them is small red eye points on horse and rider. Cue on entering their biome: distant hoofbeats, 3D positioned.
>
> **Pond Crawler** — trophic: mythic, biome_lock: swamp/bog, water_bound: true, activity: night, temperament: aggressive at close range, otherwise still. Body is a rounded hooded lump with one large blue slit eye that is a real point light. Locomotion: bipedal on two long arms with splayed fingers, wading not swimming. Each hand lifts and re-plants slowly; each plant fires a ripple, and the body's slow drift fires a wide wake ring. It mostly waits motionless in water; when the player is near it lurches — a faster arm-over-arm crawl that stacks overlapping rings. Physics: hands are contact points on the water surface and pond floor; the body follows with lag so it sways.
>
> Both get proper hitboxes per D5. Show me a short recording of each moving on the test planet at night, with rings visible under the crawler.
- All rigs are testable on the stamp via a dev spawn key; nothing spawns in normal play until Phase 6.
- **Agreed at Go (2026-09-27).** The designer said Go without answering these; the recommendations below stand until the designer overrides them:
  - Ripples keep one ~256×256 buffer (0.25 m a texel, 64 m across) centred on the camera instead of one per nearby water chunk; beyond ~40 m the static wave shader takes over.
  - `World.ripples` gives readers the recent disturbances (where, how big, how long ago) through `Ripples.height_at()` and `disturbance_at()`; the height buffer itself stays on the GPU.
  - Canopy trees get about 6 branch layouts per species; each tree picks one by hashing its position, so trees stay batched. Thick limbs don't sway.
  - Climbing is effortful by rhythm (a beat between reaches, breath sounds); no stamina meter.
  - Spear: Q (pad Y) swaps bow and spear; tap to thrust, hold and release to throw; E picks it back up.
  - Dev keys (dev mode only): F4 collision shapes, F6 branch graphs, F7 spawns the next rig, F8 makes the nearest wolf pack howl.
  - Deferred: creatures steering around trunks and ruin walls (pathfinding, Phase 6/7), wind sound, campfire crackle.
  - Fire light on folk and props is #FFA050 (R1a updated).
- **Do not build:** new creatures or systems beyond the ones on this card, combat balancing.
- **Done when:** a recording shows double-tap sprint, sneak past a deer that would otherwise flee, an arrow and a thrown spear sticking where they visibly hit, and a howl that pans and fades as you walk away; the player climbs a tree while a monkey passes overhead, and a wading creature leaves rings.
- **Prompt A:**
> Phase 1. Audit the input map, player movement states, collision shapes on player/creatures/trees/ruins/arrows, how world sounds are played (2D vs 3D, attenuation), and how plant_meshes builds canopy trees today. Then audit the ripple and creature agents already running in copies against the patched Phase 1 card. Propose the minimal changes to hit D5 and the new card exactly, in plain English. Wait.

## Phase 2 — World generation alignment
- **Touches:** `planet/passes/*`, `river_network`, `biome_templates`, `data/biomes`.
- Add a **tectonic skeleton** pass before terrain (plate boundaries on the sphere; ranges and ravines follow them; plates never move).
- Verify hydrology produces a **current direction** per river segment.
- Verify climate pass does **ridge-blocked moisture** (windward wet+fog, leeward dry) using prevailing wind.
- Reconcile **51 vs 52 biomes**; make sure biome lookup is Whittaker (temp × moisture) with smooth noise blending.
- Confirm the two-tier generation in D1; report PlanetData memory at the current resolution and at a 10× planet; confirm `flow_to` gives boats and swimmers a usable current direction per river segment.
- **Do not build:** seasons, soil, ecology.
- **Done when:** postage-stamp overlays for temperature/moisture/biome make sense, mountain ranges visibly follow plate edges, and a coastal range is green on the sea side and brown behind.
- **Prompt A:**
> Phase 2. Audit the five planet passes and river_network against the Phase 2 card: is there a tectonic skeleton, do rivers store current direction, is moisture blocked by ridges, how many biomes are in data and how are they looked up. List gaps, propose minimal changes. Wait.

## Phase 3 — Wind into the world
- **Touches:** `weather_sim`, foliage shader, `cloud_layers`, `weather_fx`.
- Verify wind = **pressure gradient** with latitude deflection. Foliage shader reads live wind at its position; sway/rustle scale with magnitude and per-plant `sway_stiffness`. Clouds and fog drift with wind.
- **Do not build:** seasons, ecology.
- **Done when:** pressure/wind overlay shows cells moving; the forest visibly sways harder as a low approaches; fog rolls in the wind's direction.

## Phase 4 — Seasons
- **Touches:** `sky_system` (season clock), `weather_sim` (temp modulation, odds), foliage shader (`seasonal_color`).
- 4 seasons with transition periods; season shifts the temperature field → weather odds → foliage color. Biomes stay fixed.
- **Done when:** on the dev clock, the deciduous forest turns and snow reaches lower altitude in winter.

## Phase 5 — Soil & flora strata
- **Touches:** new soil pass, `species_db`, `vegetation_placer`, `data/biomes/*.json`, `plant_meshes`.
- Soil fertility accumulates where warm, moist, flat, littered; thin on steep rock, cold, dry. `vegetation_placer` adds fertility to suitability.
- Tag every plant with a **stratum**; ensure each biome has canopy / understory / ground per Appendix R2. Small counts.
- **Tree lifecycle:** every tree has an age derived from seed + position + world day (nothing stored). Each species has a lifespan in its table. Past lifespan a tree becomes a **snag** — standing dead, bare, broken top, own mesh in `plant_meshes` — for a species-set number of years, then a fallen log, then it's gone and its region gets a fertility bump. Chopping or fire (Phase 8) makes a snag immediately. Add `flora.snags[region]` and `flora.logs[region]` to the ledger so other systems can read them.
- **Done when:** a fertility overlay explains why a valley is lush and a ridge is bare; walking the stamp shows the right plant sizes in the right places; an old-growth patch on the stamp shows live trees, snags and logs together, and a young patch shows none.

## Phase 6 — Ecology core
- **Touches:** NEW `ecology/ledger`, `ecology/events`, `tools/eco_sim.gd`, `creature_spawner`, `creatures.json`.
- Build R6 rules 1–7 first, then the ledger, food web (R3), diet caps, nests, warm start, and the harness: a headless run of N years on the stamp at max speed, outputting CSV plus PNG charts (population by species and region, camp food, events timeline), fixed seed with a multi-seed flag.
- **Cavity chain:** snags are habitat. Wood-boring beetles and grubs live in snags and logs (insect count capped by snag count). Woodpeckers eat them and carve cavities — a snag gains a cavity slot when a woodpecker nests there. Owls, squirrels and other cavity nesters use old cavities; they can't nest without one. Owls hunt rodents at night. So `nest.site: cavity` requires a snag with a free cavity in the region.
- **Do not build:** genetics, migration, fire, camps.
- **Done when:** the harness shows a stable 100-year run, a new world already has nests, the population overlay balances over dev days, a cat takes a rodent, a wolf pack shows up where deer are; a woodpecker is seen on a snag by day, an owl leaves a cavity at dusk.

## Phase 7 — Living populations
- **Touches:** ledger, `creature`, creature shader, `creatures.json`.
- **(a) Genetics:** 8–15 genes per creature in 0–1; the species table maps each gene to a visible trait (size, coat, marking, leg length, speed, temperament bias) with a clamped range; newborns take each gene from either parent plus small mutation; the shader reads tint, pattern, and scale from genes; the rare variant is a gene past normal range and is heritable. Sex is one bit; the species table has male and female rows for range, nest-tending, and aggression; breeding needs both in a region.
- **(b) Migration:** food location shifts with season; herbivores follow food downhill and warmward, predators follow prey — no new behaviour, only seasonal food.
- **(c) Carcass chain:** any death leaves a carcass record {region, position, mass, day}; scavengers seek it, predators are drawn by it, it decays into soil fertility over days.
- **Done when:** the harness shows genome means drifting apart between separated regions, herds visibly move in winter on the stamp, and a carcass draws a scavenger and leaves a green patch.

## Phase 8 — Disturbance and living water
- **Touches:** `weather_sim`, ledger, soil, `vegetation_placer`, `river_network`, `terrain_chunk` water.
- **(a) Fire:** lightning or a camp fire, plus dryness and flora density, ignites; spreads per region by wind and dryness; consumes flora biomass, adds fertility, writes `burn_scar`; NEAR shows burning trees, smoke, blackened ground; scars regrow in stages (grass → shrub → young trees) over years. A burned patch becomes a field of snags at once.
- **(b) Flood:** storm plus swollen river floods low regions; flattens ground flora, deposits fertility, drowns burrow nests.
- **(c) Living water:** lake level and river width follow season and recent rain; boats read width for passability; the water mesh height updates when a chunk streams.
- **Done when:** on the stamp a dry-season strike burns a patch that comes back as meadow, the harness shows fires as bounded pulses, and a river you could paddle in spring is a rocky bed in late summer.

## Phase 9 — Camp life and culture
- **Touches:** `camps`, `encampment`, `campfire`, `player/*`, light inventory.
- **Player loop:** fish (rivers/lakes/coast, by water temp), forage (berries/fruit/roots by biome), hunt (bow/spear) → carry a few things (Appendix R4) → bring to a campfire → **cook at night with the camp folk**. Cooked food restores health; the fire is the ambient social moment.
- **Camp folk loop:** foragers/hunters/fishers go out by day, gather from the ledger and flora, return by dusk; food surplus → camp grows → more pressure on nearby prey → range farther or shrink. Background camp-to-camp trade. **Do not script outcomes.**
- Camps are night safe zones. Interaction proximity-based; no dialogue trees.
- **Firewood:** camp folk gather snags and logs for firewood first, so old wood thins near camps.
- **Culture:** each camp holds culture sliders {fish, hunt, forage, wary, range} seeded from biome and moved by events — a wolf raid raises wary, a rich river raises fish. Goods, chatter, and how folk react to the player read from the sliders.
- **Done when:** you catch a fish, bring it to the opening camp, cook it at dusk with the folk, and the camp's own hunters are seen leaving and returning; plus two camps with different histories visibly behave differently.

## Phase 10 — Memory and lore
- **Touches:** `creature` (NEAR), `camps`, scrolls, HUD place names.
- **(a) Creature memory:** each NEAR creature keeps up to ~5 memories {what, where, when, good or bad} that decay over days; a wolf that lost packmates near the campfire avoids it, a fed fox returns.
- **(b) Lore:** place names, scroll text, and camp chatter are generated from `world.events` — "the meadow where the herd died," "the ridge fire of year 12" — so the world's story is what actually happened in this seed.
- **Done when:** a creature visibly changes behaviour toward the player after an encounter, and a camp folk mentions an event the harness log shows really happened nearby.

## Phase 11 — Persistence
- Elapsed-time catch-up on login using the Phase 6 warm-start code. **Done when:** log out, wait, log in — crops/nests/populations/moon advanced, nothing exploded.
- Catch-up runs `tick_region` and applies region deltas (ledger, nests, carcasses, scars, memories, culture).

---

# PART F — Emergence checklist
The designer should be **surprised**. If any of these had to be hard-coded, the system is wrong.
- A camp by a river stays fed and grows; one in scrubland stays small.
- Prey thins near a big camp; predators drift off.
- Rain on the sea side of a range, drought behind it; the forest roars before rain arrives.
- Full-moon nights are noticeably worse than new-moon nights.
- Birds nest in different places for different reasons, without anyone placing a nest.
- A cat's territory sits where the rodents are, and moves when they do.
- A fire scar is where the berries are.
- The wolves of the far valley are darker than the near ones.
- A camp that got raided is wary of you.
- The river you rowed up in spring is unrowable in late summer.
- A burned hillside is full of woodpeckers three years later and owls ten years later.
- There are no owls near a big camp.

---

# APPENDICES — Reference (Claude Code consults; designer edits)

## R1. Render target: late-90s/early-2000s console 3D, saturated dark-fantasy
The references have crunchy textures on smooth, rounded shapes. Grain, dither and low-res texture noise are IN. Blocky geometry, cube foliage, stepped terrain and oversized pixels are OUT.

| Element | Do | Don't |
|---|---|---|
| Geometry | Low-poly but rounded, organic silhouettes | Blocky geometry, cube foliage, stepped terrain |
| Textures | 128–256px painted-style with visible noise; texels never bigger than 2–3 screen pixels; nearest or bilinear both fine | Oversized pixels |
| Lighting | Directional sun + moon with strong coloured fill — ultramarine at night, warm orange near fire | |
| Post | Subtle grain, mild haze, night tint, light dither at ~1/4 strength optional; render scale 0.75–0.85 | Sharpening, bloom, SSAO |
| Sky | Dense speckled stars, big visible moon, painted cloud streaks on pure saturated blue by day | |

**Acceptance test:** a dusk river screenshot could sit beside the R1a references and belong.

## R1a. Palette
| Thing | Colour |
|---|---|
| Night sky | #0A14A0 → #1B2ED8 — bright ultramarine, never black or grey |
| Night fog | #1E30C0 at ~40%; distance dissolves to blue |
| Night water | #1B3CFF with #7FB0FF highlights — near self-lit; waterfalls near-white at the crest |
| Moonlight on stone/snow | #8FA8FF |
| Day sky | #1436FF zenith → #4C7CFF horizon |
| Grass | day #3FA83A / shadow #1F5A22, cooling toward #1E4A6A at night |
| Dirt / bark | #6B4A2E → #A07A4A — the one warm ground colour |
| Stone | #6F7A8A day, #3E4C8C night; moss #3F7A3A |
| Fire | #FFB020 core, #FF4A00 coals, #FFA050 light on folk and props, #FF7A2A ground pool |
| Windows / lanterns | #FF3A2A / #FFC040 |
| Snow | #C8D8F0 with #6A82C0 shadows |

Rules: saturate, never desaturate; scenes are blue plus one warm accent; nothing pure black.

## R2. Plant strata by Whittaker region (tolerance guide)

| Region | Canopy | Understory | Ground | Notes |
|---|---|---|---|---|
| Tropical rainforest (hot, very wet) | Emergent broadleaf giants, buttress roots | Palms, tree ferns | Broad-leaf herbs, fungi | Canopy world lives here |
| Tropical seasonal / savanna (hot, moderate) | Scattered flat-top acacia-type | Thorn scrub | Tall grasses | Grazers; lions |
| Subtropical desert (hot, dry) | Lone cactus-tree / date palm at oases | Cacti, succulents | Sparse tufts | Sandstorms |
| Temperate rainforest (mild, very wet) | Moss-draped conifer giants | Ferns, rhododendron-type | Moss, mushrooms | Windward coastal ranges |
| Temperate deciduous (mild, moderate) | Oak/beech/maple-type | Hazel, holly-type | Ferns, wildflowers, litter | Big seasonal color shift |
| Temperate grassland (mild, dry) | None / lone tree at water | Low shrubs | Grasses, prairie flowers | Tornadoes; herds |
| Woodland / shrubland (warm, dry summer) | Short olive/pine-type | Aromatic scrub | Dry grasses | Mediterranean |
| Boreal / taiga (cold, moderate) | Spruce/fir/pine, tall narrow | Willow, alder by water | Moss, lichen, berries | Long snow |
| Tundra (very cold) | None | Dwarf willow | Lichen, moss, cotton-grass | Legendary wolf pack |
| Alpine (cold by altitude) | None above treeline | Krummholz at the line | Cushion plants, lichen | Tundra rule by height |

## R3. Food web by temperature band (creatures.json guide)

| Band | Insects & bottom | Small (birds, rodents) | Mid predators | Apex | Water | Mythic (one biome) |
|---|---|---|---|---|---|---|
| Very cold | Few; summer midges | Ptarmigan-type, lemming-type, hare | Arctic fox, snowy owl | Wolf pack, polar bear-type | Cold-water fish, seal-type | Tundra white wolf pack · Alpine yeti-kin |
| Cold–mild | Beetles, worms, caterpillars | Songbirds, woodpeckers, squirrels, voles | Fox, lynx, hawk, owl, wildcat | Wolf, bear | Trout-type, otter, beaver | Boreal moose-elk · Deciduous stag spirit |
| Mild–warm | Beetles, butterflies, worms | Songbirds, woodpeckers, rabbits, rats, mice | Coyote-type, bobcat-type, eagle, owl | Cougar-type, bear | Bass-type, heron | Grassland thunder-bull · Woodland horned boar |
| Warm–hot, wet | Giant beetles, butterflies, ants | Parrots, gibbon-type monkeys, agouti-type | Ocelot-type, big snakes, harpy-type | Jaguar/tiger-type | **Cichlids**, crocodile, piranha-type | Rainforest canopy serpent · Swamp bog-lurker |
| Warm–hot, dry | Scarabs, scorpions | Sand grouse, jerboa-type, lizards | Jackal-type, caracal-type, vulture | **Lion**, hyena | Oasis fish | Savanna mane-lord · Desert sand-wyrm |
| Ocean / big lake | Plankton (implicit) | Shoal fish | Big fish | **Shark** | — | Leviathan |

Rules: generalists (wolf, deer, bear, hawk, cats, rats) span many bands; cold-blooded lock to warm bands; every predator has a `diet` list and is capped by it; herd and pack sizes follow food, never set directly; water creatures read water temperature; mythic ignores sharing rules.

Nesting habits (examples for `nest.site`): tree-fork, cavity, cliff-ledge, ground-scrape, reed-bed, burrow. Different birds pick different sites; that's the whole rule.

## R4. Inventory principle (built in Phase 9, kept tiny)
- A **handful** of items; visibly overburdened — slower, worse climbing, louder — past a low threshold. No grid.
- Every carried item changes a decision (torch, spear, tonight's food, one trade good).
- Equipment slot-based: one equipped + two spares per slot (rings: two worn + two spares).
- Weight felt in movement, never read in a menu.

## R5. Out of scope until Phase 11 is stable
Werewolf/vampire transformation, grappling hook, underwater exploration/breath meter, player-founded tribes, advanced tech tiers (rail carts, forges), crafting quality tiers, combat damage balancing, any weapon beyond bow and spear. All remain in the long-term design.

## R6. Simulation tiers and living-world rules
1. **Three tiers by distance to the player.** NEAR (loaded chunks): individual creatures, physics, animation, memory. MID (regions within a radius set in `data/sim.json`, start ~10 km on the stamp): ledger only — per-region counts and fields, ticked every in-game hour. FAR: frozen; caught up with the warm-start code when the player approaches or logs in. Nothing far away ever has a node.
2. **One simulation function.** `tick_region(region, dt)` is the only place ecology advances. Live play, warm start, login catch-up, and the headless harness all call it. If it exists twice, it's wrong.
3. **Time-sliced.** The sim gets a fixed per-frame budget (start at 2 ms); regions tick round-robin, never all at once. A region that falls behind catches up on its next slice.
4. **Flat data.** Region fields are packed arrays indexed by region id, not objects. Creatures, nests, carcasses, and fire become scene nodes only in NEAR.
5. **Deterministic.** RNG for any region and day is seeded from (world seed, region id, day), so regenerated detail matches and harness runs repeat exactly.
6. **Events, not polling.** Anything notable writes one record to `world.events` — {day, region, kind, params}. Systems read the log; they never watch each other. Per region: a ring buffer of the last ~50 events plus a permanent compact summary (count per kind, first and last day).
7. **Every rate lives in `data/sim.json`.** The designer tunes; code never hard-codes a number.
8. **Merge gate:** a system merges only when `eco_sim` shows, across 3 seeds and 100 years, no species at zero, none above 3× baseline, and every older chart unchanged in shape.
9. **World age** is random at generation (warm start 50–200 years), so worlds differ in how much history they carry.
