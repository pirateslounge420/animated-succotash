# WORLD SYSTEMS SPEC — v4 (Godot project; v3 was aligned to commit `fe6ee3e`)

**Read this whole file before touching code. It is the source of truth.** Where it conflicts with `DESIGN.md`, `README.md`, or anything in the repo, this file wins. Then read `docs/PROGRESS.md` to find the current phase, and work on that phase only.

Ordered the way it is *used*: how to work → where the project is → what to do now → architecture → one card per phase → reference tables at the back.

---

# PART A — How we work (read every session)

### A1. Session protocol (Claude Code, every time)
1. Read this spec, then `docs/PROGRESS.md`. State in one line: *"Phase N. Last sign-off: ___. Any agents still working in copies: ___."*
2. **Audit first, build second.** Before any change, list in plain English what you found and what you propose, then stop and wait for "go."
3. Build only the current phase's deliverable. Nothing from later phases — not even scaffolding.
4. Every change ships with **a visible way to verify it**: a screenshot, a measured number from a headless tool, or a debug overlay on a hotkey. If it can't be seen or measured, it isn't done. No recordings unless the designer asks for one (A3).
5. **Parallel agents:** if restyle/set-piece agents are working in separate copies, their changes are audited against this spec (Appendix R1 for anything visual) *before* merging. Nothing merges blind. One phase = one branch; land it, sign off, then start the next.
6. End of session: prepend 3–6 lines to `docs/PROGRESS.md` — what changed, what's verified, what's next, open questions. Commit with the phase number in the message.

### A2. Standing rules
- **The designer does not code.** Explain every change in one plain-English paragraph: what it reads, what it writes, what changes on screen.
- **Shared state, no direct calls.** Systems read the `World` autoload and write only the fields they own. Systems never call each other's methods to change state.
- **Arrows point down.** A system may read anything above it in the emergence stack (C2); it never writes upward.
- **Nothing hand-placed.** Every terrain feature, plant, animal, nest, and camp must be derivable from the seed plus the passes above it. Pre-built nests, established territories, and half-grown crops are produced by *running the simulation forward at generation time*, not by placing them.
- **Life comes only from life.** Nothing living appears from nothing. Every plant is a seed, spore, offset or cutting of a plant that existed; every animal is born to parents that existed. The only exception is generation itself, and even there the warm start runs the breeding rules forward so a new world is the descendant of its own first day. Consequences the code must honour:
  - no proximity spawning — the spawner deals individuals from the ledger's population and never rolls new ones;
  - vegetation grows in patches because offspring appear near parents and spread outward through suitable ground, so a lone tree in a meadow has a story and a meadow has edges;
  - a region with no seed source and no seed bank stays bare until something arrives;
  - a species wiped out in a region is gone there until it walks, blows or is carried back in;
  - growth stages are part of this: every plant is seen small before it is seen large.

  **Browsing:** herbivores eat plants at the stage they can reach. Goats and deer strip sprouts, saplings and low shrubs; goats also work slopes and rock that deer avoid, so goat country is bare of young trees and thick with what they won't eat. A plant entry may carry `cannot_be_browsed` (cacti, thorn scrub); those spread where browsers are heavy. Browsing writes to `flora.age_structure`, so a goat-heavy region visibly fails to regenerate.

  ⚑ The code breaks this rule in two places today, and both are already scheduled:
  - creatures spawn by proximity; the ledger spawner comes in Phase 7;
  - plants are placed by suitability and clumping noise; placing them from parents comes in Phase 6.

  The Phase 1 dev spawn key (F7) is a test tool, not play.
- **Data over code.** Species, plants, biomes, and weather odds live in `data/`. The designer edits tables; Claude Code edits logic. Any tunable number goes in a table. Keep the existing files (`data/biomes/*.json`, `data/creatures/creatures.json`); extend their schemas, don't rename them.
- **Ask before inventing.** If a rule or value isn't in this doc, propose it and wait. (A past prototype invented an unwanted breath meter. Don't.)
- **Fewer polygons, softer textures, moodier light.** When unsure how anything should look, that is the answer — never "more pixels" or "sharper."
- **Few things that matter.** No feature that adds management without changing a decision. No bloat.

### A3. The two-prompt rhythm (designer)
1. Paste the phase's **Prompt A**. Claude Code audits, proposes, waits.
2. Say *"Go. Show me [the deliverable] when done."*
Look at the evidence. Right → *"Sign off Phase N."* Wrong → describe it in plain words and "Go" again. Never approve on a description.
- **Done-when evidence** is the designer playing the build on the stamp, or a screenshot or a measured number from a headless tool. A card's "done when" names what to look at, not a video.
- **No recordings unless asked.** Claude Code records a clip only when the designer asks for one.
- **Verification stays under 10% of build time.** Prefer one screenshot or one headless number over a long render; if a check would cost more, say so and let the designer play it.

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
| Geology / terrain | `planet/passes/terrain, geology`; cube-sphere 400 km; continents, mountains, ravines, cliffs, cave mouths | Mostly | No **tectonic skeleton** — mountains not placed by plate boundaries. No caves: the only "cave mouths" are wolf-den props (Phase 3 replaces them) |
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

**Cut or hold:** Rare-event dice, sky events, magic sites, ruins, sculpted bodies all stay as they are — don't touch, don't expand. Exceptions written into the cards: Phase 3 reuses `magic_sites` for the teal fungi at depth; Phase 10 unparks the set pieces (`hold/set-pieces`) and lets camps salvage from ruins.

---

# PART C — What to do now

## Current phase: **Phase 1 — Player feel, hitboxes, audio** (card in Part E)

Phase 0 — Look & Light was signed off on 2026-09-26 (the dusk river shot). Its notes stay below for reference.

Phase 1 is signed off (2026-09-27) for hitboxes, 3D audio, ripples, the Night Rider and the Pond Crawler. **Player feel** (sprint, sneak, bow, spear, climbing, momentum) is held until the designer has played it on the stamp. When Phase 1 closes, **Phase 1.5** (the R1a second-batch render changes) comes next; the Phase 2 audit runs meanwhile, audit only.

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

The planet stays 400 km (1/100 Earth) through Phase 12; it may scale to 1/10–1/30 Earth later because boats will be the main way to travel. Therefore: everything global lives in PlanetData at coarse resolution; everything the player sees is derived per chunk from seed + PlanetData and discarded on stream-out; nothing at detail scale is ever stored except region deltas (ledger counts, nests, carcasses, scars, memories, culture). Scaling the planet up must change only radius/resolution constants and PlanetData's memory, never the streaming or detail code.

### D2. The emergence stack (mirrors Earth; the dependency order)
```
1. Geology    seed → tectonic skeleton → heightmap → rock type → caves  (static)
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
| cave_density | `World.planet.cave_density` (PlanetData, per cell) | u8 per cell (0–1 in 1/255 steps) | geology pass, once at generation | 3 |
| season | derived from `World.days` and `year_days` in `data/sim.json`; nothing stored | — | World clock | 5 |
| regions | `World.regions`: `cell_to_region` (per cell), `center`, `area_km2`, `neighbors` | i32 per cell; vec3, f32, 8×i32 | ecology/ledger, at generation | 6 |
| soil.fertility | `World.soil.fertility` | f32 | ledger (soil rules); the soil pass seeds it | 6 |
| soil.carcass | `World.soil.carcass` | f32 (kg) | ledger | 8 |
| flora.age_structure[species] | `World.flora.age_structure`, sparse: per region only the species present (id + a count per growth stage) | ~20–60 × (u16 + 4× u16) | ledger (flora rules); the warm start seeds it | 6 |
| flora.biomass[species] | `World.flora.biomass`, same sparse layout: the weighted sum of `age_structure`, kept as a cache | ~20–60 × f32 | ledger (derived from `age_structure`) | 6 |
| flora.seedbank[species] | `World.flora.seedbank`, same sparse layout, annuals only | ~0–30 × f32 | ledger | 6 |
| flora.genome_mean[species][gene] | `World.flora.genome_mean`, same sparse layout | present species × 6–10 u8 | ledger | 6 |
| flora.snags, flora.logs | `World.flora.snags`, `World.flora.logs` | u16 each | ledger; tree ages seed them; fungi decay them (Phase 7) | 6 |
| flora.litter | `World.flora.litter` | f32 (kg) | ledger: leaf fall from the age structure each autumn and at dormancy; fungi decay it | 7 |
| soil.dung | `World.soil.dung` | f32 (kg) | ledger: from herbivore counts; dung fungi and beetles decay it | 7 |
| fungi.biomass[species] | `World.fungi.biomass`, sparse like flora: per region only the fungi present | ~5–20 × f32 | ledger (decay rules) | 7 |
| flora.cavities ⚑ | `World.flora.cavities` | 2× u8 (free, used) | ledger | 7 |
| flora.burn_scar | `World.flora.burn_scar` | u16 (days since burn, 0 = none) | ledger (fire) | 9 |
| water level (seasonal) | `World.hydro.level_offset` (added to `planet.water_level`) | f32 (m) | ledger (living water) | 9 |
| fauna.pop[species] | `World.fauna.pop` | S× f32 | ledger | 7 |
| fauna.sex_ratio[species] | `World.fauna.sex_ratio` | S× u8 | ledger | 8 |
| fauna.genome_mean[species][gene] | `World.fauna.genome_mean` | S×G× u8 (0–1 in 1/255 steps) | ledger | 8 |
| fauna.packs ⚑ | `World.fauna.packs`: per pack its territory (regions) and members {age, sex, parents, genes incl. dominance}; ranks are derived from it, never stored | a few packs per region × ≤12 members × ~24 B | ledger | 8 |
| events | `World.events`: per region a ring of the last ~50 records {day, kind, params} + a per-kind summary (count, first day, last day). Kinds include `scent` (a blooming aroid or a carcass: strength, until-day) | ~1.1 KB | ecology/events: append-only, every system adds records through it | 6 |
| society[camp] | `World.society`: packed arrays per camp id (camps are few): pop, food, roles; culture {fish, hunt, forage, wary, range, ritual_smoke, ceremony}; `landmark` (kind + id of the remnant it formed around); `salvage` {worked stone, timber, metal}; `standing` (the player's standing with the camp) and `guest_until` (day: a guest of the fire after a ceremony); `oracle_standing` | per camp: ~17 f32 + 2 i32 | camps | 10 |
| player.haze, player.vision | `World.player.haze`, `World.player.vision` (a small player-state object) | one f32 each, 0–1 | player (writes); `post_grade`, audio, creatures read | 10 |
| creature.memory[] | on each NEAR creature node; saved as a region delta in `World.fauna.memory_delta` (sparse, by region) | ≤5 × {what, where, day, good/bad} | creature | 11 |

**Regions: PlanetData cells or a fixed coarsening.** Option A: one region per cell. Option B: a fixed k×k block of cells within a cube face, k in `data/sim.json`. Per region the fauna fields, soil, water and events come to about 2.4 KB at a planning roster of S = 64 species (25 today), G = 15 genes and ~24 event kinds (5.3 KB if genomes are f32). Flora is per species from Phase 6, but a region holds only the species actually present there: about 20–60 of them × ~28 bytes (id, counts per growth stage, biomass, seed bank, 6–10 gene means), so 0.6–1.7 KB more; stored densely for all 435 plant entries (107 biome plants + the three catalogues) it would be ~12 KB more per region. Totals at ~4.1 KB per region:

| | Regions | Ledger memory |
|---|---|---|
| Full planet, A (cells, ~1 km) | 55,296 | ~225 MB |
| Full planet, B k=2 (~2 km) | 13,824 | ~57 MB |
| Full planet, B k=4 (~4 km) | 3,456 | ~14 MB |
| Stamp, A (cells, ~208 m) | 13,824 | ~57 MB |
| Stamp, B k=4 (~830 m) | 864 | ~3.5 MB |
| 10× planet with ~1 km cells, B k=4 | 345,600 | ~1.4 GB dense (see ⚑) |

Proposed: **B, k = 4.** It keeps the ledger small and, above all, keeps the warm start affordable: 50–200 years of `tick_region` over 3,456 regions is 16× less work than over 55,296. Rules work in densities per km², so the region size can change later without retuning. (At 10× the planet PlanetData itself is ~660 MB at ~1 km cells, so a bigger planet also means coarser cells.)

⚑ Unsure / flagged:
- Sky and eased weather are not on World today (a SkySystem node and main.gd). Proposed: publish read-only copies as `World.sky` and `World.weather_local` so systems never reach into main.
- The ledger core (regions, `tick_region`, events, `data/sim.json`, the warm start, `eco_sim`) now starts in Phase 6, because the flora ledger and the harness's flora half are Phase 6 work; Phase 7 adds fauna to the same ledger and run. `soil.fertility` and `flora.*` are seeded by generation passes and change live from Phase 6.
- `flora.cavities` isn't in the designer's list, but the cavity chain (Phase 7) needs somewhere to keep cavity slots.
- A 10× planet can't hold dense ledger arrays; FAR regions would store nothing until first simulated (regenerated deterministically per R6.5, then kept as a delta). That needs a region-id indirection from the start (Phase 6) so storage can go sparse without touching `tick_region`. Flora is sparse per region from day one.
- Stored deltas beyond D1's list: felled and burned trees (chopping and fire make snags that tree age can't derive), plants that germinated during play and crops (as cohorts per region: species, germination day, count), placed items (a bundle drying by a fire or in a hut for days), and possibly remnant salvage (if salvaging uses a landmark up, `salvage_left` per landmark is a delta).
- `cave_density`: GLACIAL_TILL isn't in the designer's rock list; proposed none (loose glacial deposits), like alluvial.
- `player.haze` and `player.vision` need a home for player state on World; `World.player` is proposed, holding only those two for now.
- Human seed dispersal "along camp foraging ranges and paths" needs Phase 10's ranges; until then it uses each camp's position and a table radius.

### D4. Data schemas (extend existing files; don't rename)
```
data/biomes/<biome>.json   + weather_odds, mythic_creature, (keep plant lists; add per-plant stratum)
data/plants/<catalogue>.json  plant catalogues, laid out like a biome file (key, name, kind, status, notes,
                             plants{stratum: [entries]}) but with no climate block: every entry carries its
                             own temp_c / moisture / altitude_m bands. The keys regions, types and
                             family_defaults are ignored by species_db. Today: amorphophallus.json (246
                             species), cannabis.json (64 landraces of one species), trichocereus.json (18
                             Andean torch cacti), yucca.json (all 55 Kew-accepted species), palms.json (43
                             curated regional dominants), fungi.json (43 species, fungus block below).
                             469 entries in all. Loaded from Phase 6.
biome file `special`         computed list of the catalogue plants whose climate centre falls inside that
                             biome (informational; Phase 6 may raise their density there so they are findable)
plant                      { name, genus, species, invented?, stratum(canopy|under|ground), temp_min/max,
                             moisture_min/max, soil_min, slope_max, sway_stiffness, seasonal_color,
                             lifespan_years, snag_years, log_years,
                             growth?, repro?, genes?, family?, aroid?, cannabis?, landrace?, landrace_id?, type?,
                             cannot_be_browsed?, synonym?, display?, ceremonial?, leaf_density? }
  leaf_density             0–1, how leafy a branchy tree's crown is: how many leaf clusters its limbs carry
                             and how big (plant_meshes). Default by shape (broadleaf 0.8, gnarled and emergent
                             0.7, umbrella 0.6, cypress 0.85); set today on beech 0.9, holm oak 0.85, dry-season
                             deciduous 0.55, acacia 0.5, mesquite 0.45, paloverde 0.3
  cannot_be_browsed        true: browsers never eat it (cacti, thorn scrub); it spreads where browsers are heavy
  synonym                  the accepted Kew name when the game uses another (Trichocereus → Echinopsis)
  display                  the name shown in the game when `name` holds the binomial ("San Pedro cactus")
  ceremonial               documented | reported | trace — read by the ceremony system (Phase 10)
  growth                   { stages: [[name, days], …], final_size } — default trees: sprout, sapling, mature, old;
                             herbs and shrubs: sprout, young, mature. Growth runs 0–1 through the stages; the
                             size gene scales final_size. Crops use the same block.
  repro                    { mode: seed|clonal|both,
                             pollinator: insect|wind|carrion_fly|bird|bat|self,
                             disperser: bird|mammal|wind|water|gravity|human, or a list (each adds its kernel),
                             clonal: runner|rhizome|tuber_offset|bulbil|sucker|none,
                             bloom: {season, days (or [min, max]), interval_years: [min, max]},
                             dormant: dry|cold|seed|none, lifespan: annual|perennial, dioecious: bool }
                             entries without repro get their tier's default
  genes                    { <gene>: [min, max] } 6–10 genes in 0–1; the species table maps each to a visible trait
  aroid                    { petiole: {pattern, base, spots}, spathe: {outside, inside}, bloom_with_leaf }
  cannabis                 { leaf_width, flowering: {trigger, hours, days}, uses, camp_follower }
  shape                    + aroid (catalogue entries use umbrella until the aroid shape exists)
  fungus                   { substrate: snag_log|litter|dung|carcass|burn|mycorrhizal, edible: yes|cook|no|
                             poison|deadly, glow, fruit_after_rain_days: [min, max], fruit_season, decay_rate }
                             fungi.json entries only. Fungi read dead matter, not climate (Phase 6, 7)
data/creatures/creatures.json
creature                   { name, genus, species, invented?, id, trophic(insect|herbivore|small_pred|apex|scavenger|fish),
                             diet:[ids or "seeds"|"insects"|"leaves"|"fish"], temp_min/max, water_bound,
                             activity(day|night|dusk), temperament(friendly|skittish|aggressive|pack),
                             light_response, herd_min/max, nest:{type, site}, reproduce_days,
                             biome_lock (mythic only), rare_variant, underground (cave fauna),
                             range_m?, senses_m?, seed_carry_h? }
  diet (Phase 7)           names food object kinds: bloom (nectar), fruit, seed, leaves, sprouts, insects,
                             carcass, dung, fungi, or prey creature ids
  range_m / senses_m       how far it forages from home, and how far it notices each food kind (a bee sees
                             blooms within tens of metres; a fruit bat smells ripe fruit across a valley)
  seed_carry_h             how long eaten seed rides in the gut before it is dropped (frugivores)
  nest.type                + hive (bees)
```
**Binomials (every entry, from now on).** Every plant and creature entry has `genus` and `species`; `name` stays the display name. Real organisms use their real binomial — the accepted name in Kew's Plants of the World Online for plants (*Tsuga heterophylla* for the hemlock, *Canis lupus* for the wolf). Invented ones — mythics, Night Rider, Pond Crawler, the placeholder plants named by habitat and form ("Understory shrub") — get an invented binomial in the same Linnaean style and `"invented": true`. No entry is valid without them. Entries sharing a binomial are one interbreeding species. One exception to Kew: the torch cacti keep the name *Trichocereus*, with Kew's *Echinopsis* name recorded as `synonym`. (`repro.lifespan` — annual or perennial — is separate from `lifespan_years`, a tree's age at death.)

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
  - **See-through crowns.** Leaves are clusters on the outer third of each limb and branch (noisy alpha-cutout cards per R1, no per-leaf geometry), with open air between them: from the ground you see the limbs, sky through the gaps and anything moving in them. Cluster count and size follow the species' `leaf_density` and, per tree, its growth and how dry its site is; the ground under a crown is dappled, shade broken by sun flecks. The far LOD keeps the solid crown.
- **(ii) Climbing:** the player climbs trunks and shimmies along thick branches: slow, effortful, no swinging; extend `tree_contact`. About 0.5 m/s up a trunk and ~0.3 m/s along a limb.
- **(iii) Monkey:** a gibbon-type monkey rig that brachiates along the branch graph — arc-and-release with momentum, next handhold chosen by reach and swing arc; monkey-only; it goes in R3's warm–wet band.
- **(iv) Ripple system, Night Rider, Pond Crawler** — the designer's spec, verbatim:
> Two new creature templates, plus the ripple system they depend on. Add both to `data/creatures/creatures.json` under the existing schema; nothing spawns until [Phase 7], but the movement rigs and ripple system are Phase 1 work.
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
- All rigs are testable on the stamp via a dev spawn key; nothing spawns in normal play until Phase 7.
- **Agreed at Go (2026-09-27).** The designer said Go without answering these; the recommendations below stand until the designer overrides them:
  - Ripples keep one ~256×256 buffer (0.25 m a texel, 64 m across) centred on the camera instead of one per nearby water chunk; beyond ~40 m the static wave shader takes over.
  - `World.ripples` gives readers the recent disturbances (where, how big, how long ago) through `Ripples.height_at()` and `disturbance_at()`; the height buffer itself stays on the GPU.
  - Canopy trees get about 6 branch layouts per species; each tree picks one by hashing its position, so trees stay batched. Thick limbs don't sway.
  - Climbing is effortful by rhythm (a beat between reaches, breath sounds); no stamina meter.
  - Spear: Q (pad Y) swaps bow and spear; tap to thrust, hold and release to throw; E picks it back up.
  - Dev keys (dev mode only): F4 collision shapes, F6 branch graphs, F7 spawns the next rig, F8 makes the nearest wolf pack howl.
  - Deferred: creatures steering around trunks and ruin walls (pathfinding, Phase 7/8), wind sound, campfire crackle.
  - Fire light on folk and props is #FFA050 (R1a updated).
  - The bow and the spear both aim along the crosshair ray (from where the over-the-shoulder view is centred, not from the camera); every 3D sound, the Night Rider's, the Pond Crawler's and the gibbon's included, takes its falloff from `data/audio.json`.
- **Do not build:** new creatures or systems beyond the ones on this card, combat balancing.
- **Done when:** the designer, playing on the stamp, can double-tap sprint, sneak past a deer that would otherwise flee, see an arrow and a thrown spear stick where they visibly hit, hear a howl pan and fade walking away (F8), climb a tree while a monkey passes overhead (F7), and see a wading creature leave rings (F7). Headless numbers back each one (A3).
- **Prompt A:**
> Phase 1. Audit the input map, player movement states, collision shapes on player/creatures/trees/ruins/arrows, how world sounds are played (2D vs 3D, attenuation), and how plant_meshes builds canopy trees today. Then audit the ripple and creature agents already running in copies against the patched Phase 1 card. Propose the minimal changes to hit D5 and the new card exactly, in plain English. Wait.

## Phase 1.5 — R1a second-batch look
- **When:** after Phase 1 closes (player feel signed off). Held until then.
- **Touches:** `sky_system` and the sky shaders, `post_grade`, `palette.gdshaderinc`, `storm_fx`, the water shader.
- Apply the R1a second-batch additions (Appendix R1a, verbatim there): day zenith `#0A1AE0` with hard-edged white clouds and grass `#4CC03A` in full sun, no haze washing the day out; deep night a full-blue grade toward `#1B2ED8` with local colour nearly gone, sliding from the dusk/moonrise values through the night; storm and volcanic skies purple-magenta `#5A1AA0` → `#C030C0`; warm light tiny, one or two points per scene; `#A01020` a rare dread accent; snow scenes fully blue.
- **Do not build:** the new remnant kinds (stairways, hung bells, idol gates, hollow-tree dwellings, wells, candlelit chapels) — Phase 10.
- **Done when:** two screenshots on the stamp — a dusk river and a deep-night scene — sit beside the batch-2 stills in `docs/references/batch2/` and belong.

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

## Phase 3 — Caves and underground
- **Touches:** geology pass, `terrain_field`, `terrain_chunk`, `chunk_manager`, look shaders, `data/biomes/50_caves.json`.
- **(a) Blueprint:** PlanetData gains `cave_density[cell]` from rock plus noise — high in LIMESTONE_KARST (karst systems, underground rivers), medium in BASALT_VOLCANIC (lava tubes), low in granite and sandstone, none in alluvial, coastal sand and clay/peat. Nothing hand-placed.
- **(b) Cave field:** a seeded 3D density field under the surface, evaluated only in chunks whose cell has `cave_density` > 0. Wide rooms at depth, winding tunnels linking them, narrow crawls, and open ravines that split the surface — the Minecraft 1.18 model. Tunnels drift toward the water table; rooms below `water_level` fill with water. Where the field meets the surface it makes a real opening — cliff-side mouths, sinkholes, and behind waterfalls — and the surface mesh gets a hole there.
  - Cave-mouth logic today: the only cave mouths are the wolf dens' props (`creature_spawner` `_find_den` / `_den_prop`: two boulders and a lintel around a near-black ball on a steep, cold slope, no tunnel). Replace them with this: dens pick a real mouth from the field. The cliff camps' overhang (`camps`) is a rock shelter, not a cave, and stays.
- **(c) Meshing:** caves are a separate mesh per chunk, marching cubes, NEAR only, with collision, unloaded with the chunk. Cave geometry is never stored — regenerate from seed. Report the per-chunk cost and keep it under the surface mesh's.
- **(d) Look, per R1/R1a:** never black. Deep ultramarine haze that thickens with distance, cold #3E4C8C stone, water near self-lit, warm light only from the player's torch or a fire. Depth bands: shallow root-and-soil caves; limestone with stalactites, pools and underground rivers; deep volcanic with lava glow (#FF4A00) under BASALT_VOLCANIC. Teal fungi at depth reuse `magic_sites`.
- **(e) Underground biome:** `50_caves.json` becomes real — moss, fungi and glow fungi by depth band. Cave fauna (bats that roost by day and pour out at dusk, cave fish, blind salamanders, spiders) join the ledger in Phase 7 with `underground: true`. Cave ambience: the drone, drips, echoing footsteps, all 3D.
- **(f) Hooks only, not built:** sunken temples in flooded rooms; the rare deep tribe by the lava, later.
- **Do not build:** cave creatures, ruins inside caves, the lava tribe.
- **Done when:** on the stamp, a karst cliff mouth leads through tunnels to a room with a pool and an underground river; a ravine splits the surface somewhere; a mouth exists behind a waterfall; F3 shows `cave_density`; frame rate underground matches the surface.
- **Prompt A:**
> Phase 3. Audit the geology pass, terrain_field, terrain_chunk meshing and chunk_manager for how a second, volumetric mesh layer can be added per chunk without slowing the surface. Propose the noise model, the mouth logic, and a marching-cubes budget. Wait.

## Phase 4 — Wind into the world
- **Touches:** `weather_sim`, foliage shader, `cloud_layers`, `weather_fx`.
- Verify wind = **pressure gradient** with latitude deflection. Foliage shader reads live wind at its position; sway/rustle scale with magnitude and per-plant `sway_stiffness`. Clouds and fog drift with wind.
- **Do not build:** seasons, ecology.
- **Done when:** pressure/wind overlay shows cells moving; the forest visibly sways harder as a low approaches; fog rolls in the wind's direction.

## Phase 5 — Seasons
- **Touches:** `sky_system` (season clock), `weather_sim` (temp modulation, odds), foliage shader (`seasonal_color`).
- 4 seasons with transition periods; season shifts the temperature field → weather odds → foliage color. Biomes stay fixed.
- Winter thins the leaf clusters of deciduous trees: the foliage shader's `leaf_season` (1 today) multiplies each tree's leaf amount.
- **Done when:** on the dev clock, the deciduous forest turns and snow reaches lower altitude in winter.

## Phase 6 — Soil & flora strata
- **Touches:** new soil pass, `species_db`, `vegetation_placer`, `data/biomes/*.json`, `data/plants/*.json`, `plant_meshes`, foliage shader; NEW `ecology/ledger` (core and flora rules), `ecology/events`, `tools/eco_sim.gd` (flora half), `data/sim.json`.
- Soil fertility accumulates where warm, moist, flat, littered; thin on steep rock, cold, dry. `vegetation_placer` adds fertility to suitability.
- Tag every plant with a **stratum**; ensure each biome has canopy / understory / ground per Appendix R2. Small counts.
- **Tree lifecycle:** every tree has an age derived from seed + position + world day (nothing stored). Each species has a lifespan in its table. Past lifespan a tree becomes a **snag** — standing dead, bare, broken top, own mesh in `plant_meshes` — for a species-set number of years, then a fallen log, then it's gone and its region gets a fertility bump. Chopping or fire (Phase 9) makes a snag immediately. Add `flora.snags[region]` and `flora.logs[region]` to the ledger so other systems can read them.
- **Ledger core:** the flora ledger needs R6 rules 1–7, regions and `tick_region` in this phase; Phase 7 adds fauna to the same ledger and the same harness run.
- **Life from life (A2):** placement grows patches outward from parent plants and the seed bank instead of scattering by suitability and noise; a region with no seed source stays bare.
- **Plant catalogues:** `species_db` loads `data/plants/*.json` exactly like a biome file: entries carry their own bands, there is no biome climate block, and the `regions`, `types` and `family_defaults` keys are ignored (so is the biome-key check). `species_db` warns on any entry without `genus` and `species` (D4).
- **Reproduction data:** each plant entry may add a `repro` block; entries without one get their tier's default (fields in D4). `dormant`: the plant withdraws to its root and shows nothing, or a withered stem, until its season returns; `seed` means an annual that dies and comes back from the seed bank. `dioecious`: each plant is male or female and only females fruit.
- **Lifecycle (NEAR):** each plant has an age from seed + position + world day for generated plants (nothing stored), and from the region delta for plants that germinated during play. States seedling → vegetative → bloom → fruit → dormant on the species' calendar, offset by a timing gene. Bloom and fruit are visible states with their own mesh part; dormant plants vanish or wither. Some species bloom before they leaf. Flowering may be triggered by day length (a `flower_trigger` gene read against the sky system's day length at that latitude) or by age.
  - **Growth stages:** every plant has a growth level. Each species' table gives a `growth` block: a list of stages with the days each lasts — default four for trees (sprout, sapling, mature, old) and three for herbs and shrubs (sprout, young, mature) — plus a `final_size` the size gene scales. Growth is a 0–1 value through the stages, so the mesh builder gets a continuous number, not a switch. (The yearly states above run inside the stages; a sprout is the seedling.)
  - **Stages change silhouette, not just scale.** `plant_meshes` takes growth as a parameter per shape: a sprout is a single thin stem with two or three leaves; a sapling is a narrow whip with a small crown; mature is the current full shape; old is wider, gnarled, with a broken limb or two and moss, and in trees it's the stage that carries the branch graph — only old trees are climbable and only old forest has the canopy world. Meshes are cached per species, stage and LOD, so the cost is memory, not per-frame work.
    - Leaf clusters already read growth: `PlantMeshes.leaf_amount(growth, moisture)` thins and shrinks a tree's clusters. Until this phase, growth is a stand-in read off the tree's height within its species' range (every generated tree mature or old); swap in the real growth value here.
  - **What growth reads and writes.** Growth rate scales with soil fertility and climate suitability and pauses during dormancy, so the same species grows fast in a valley and slow on a ridge. Herbivores browse sprouts and saplings — a region with heavy grazing keeps its saplings from ever reaching maturity, which is how meadows stay open and old forests fail to replace themselves. Only mature plants yield: berries, fruit, fibre, seed, the aroid bloom, the cannabis harvest; only mature and old trees give real timber, and old trees pass into the snag lifecycle. Crops use the same block, so anything camp folk plant visibly grows day by day.
  - **Ledger side.** `flora.age_structure[region][species]` holds counts per stage, and biomass is the weighted sum, so a region knows whether its forest is young, mature or ancient. Warm start produces a real age mix — a new world has sprouts, saplings, giants and snags together, never a plantation of identical trees. Fire scars regrow through the stages; that is the succession the player sees.
  - ⚑ Notes:
    - Until this phase every canopy tree carries the Phase 1 branch graph; from here only old trees do.
    - With Phase 1's ~6 branch layouts per species the mesh cache is species × layout × stage × LOD — report its memory.
    - A tree's `lifespan_years` is the sum of its stages; proposed: derive it from the `growth` block rather than keep both.
    - Browsing reads herbivore counts, a table value until Phase 7.
    - Camp plots arrive with Phase 10; here a dev-planted test plot shows crops growing.
    - Plants germinated during play are stored as cohorts per region (species, germination day, count), not one record per plant; NEAR places them deterministically.
- **Ledger (MID):** `flora.biomass[region][species]` grows toward a cap set by soil fertility and climate suitability. Annuals also keep `flora.seedbank[region][species]`, which decays over a few years and germinates each spring — the general rule for all annuals, grasses included. Spread differs by strategy:
  - Clonal spreads only into adjacent regions through continuous suitable ground, slowly, but recovers fast from the root after fire, grazing or harvest.
  - Seed spread is propagules = biomass × bloom success × disperser availability, with a kernel by disperser — gravity 0–1 region, wind 1–3 regions downwind along `wind_avg`, water downstream along `flow_to`, bird 1–5 regions toward forest and water, mammal 1–3, human along camp foraging ranges and paths.
  - Bloom success reads the ledger's insect count for insect and carrion-fly pollinators and bird count for birds; wind and self are 1. Until Phase 7 fills the ledger those counts are a table value.
  - Seeders die out locally with no seed source in range — that is what makes fire-scar succession emerge (wind-seeded grasses first, bird-seeded berries later, trees last). **Do not script succession stages.**
- **Genetics:** 6–10 genes per plant in 0–1; the species table maps each to a visible trait — size, leaf colour shift, pattern intensity (petiole mottling on aroids, bark on trees), bloom colour, scent strength, timing offset, dormancy length, and allocation (how much goes to blooms versus offsets when mode is both). Seed offspring mix two parents plus mutation; clonal offspring copy the parent with tiny mutation, so a clonal patch is visibly uniform and a seeded population visibly varied. Allocation is heritable, so strategy evolves: where fire is frequent or pollinators scarce, clonal genes win; where insects are rich, seeders win. Entries sharing a binomial are one interbreeding species; a landrace or regional form is a starting genome for its region, and where two ranges overlap, hybrids appear by the ordinary seed rules. The harness must show this per region.
- **Harness:** build `eco_sim`'s flora half in this phase — biomass by species and region over years, spread maps, succession after a scripted test burn, allocation gene means by region. Phase 7 adds fauna to the same run.
- **Aroids — the Amorphophallus catalogue:** new shape `aroid`: one petiole with a dissected umbrella leaf; bloom part is a spathe and spadix; dormant shows nothing. Carrion-fly pollinated — the bloom writes a short-lived scent record (`world.events`, kind `scent`) that draws the same insects the carcass chain uses; berries dispersed by birds; tuber offsets, and bulbils on the leaf for some species; dormant in the dry season; the giants bloom every 3–10 years for two or three days. `data/plants/amorphophallus.json` holds all 246 species accepted by Kew, each with its own temp_c/moisture/altitude band, height, density, soil, an `aroid` block (petiole pattern and colours, spathe colours), a `repro` block and `genes` ranges. Its shape is `umbrella` for now — switch every entry to `aroid` once that shape exists. Do not hand-place any of them; they grow wherever their bands allow, which will be the warm–hot bands only. (⚑ 15 East Asian species, konjac among them, are banded down to 12 °C, so they also reach the warm edge of the mild band.)
- **Cannabis:** `data/plants/cannabis.json` holds 64 landrace populations of the single species *Cannabis sativa*, loaded like the aroid catalogue. All entries interbreed as one species. Each plant is male or female — only females carry the harvestable flower, and on windy days a faint yellow drift blows downwind from a male stand. Wind-pollinated, annual, seed bank. Flowering starts when the day length at that latitude drops below the plant's `flower_trigger` (ruderal types flower by age), so a tropical landrace carried north by a camp may never finish before the cold — that failure is allowed. Camp-follower dispersal, so it grows on middens and trail edges near camps that use it. Genes gain `leaf_width`, `resin`, `fibre`, `flower_trigger`, `purple`; broad-leaf types purple in cold. (Its uses are Phase 10.)
- **Trichocereus — the Andean torch cacti:** `data/plants/trichocereus.json` holds 18 of them, loaded like the other catalogues. Kew files them under *Echinopsis*; the game uses the *Trichocereus* name with the synonym recorded.
  - All of them need cold, dry, high, rocky ground (thin soil, dry ground), so on the planet they appear only on the dry side of high ranges in the mild band.
  - Columnar, slow four-stage growth, clumping from basal pups and rooted fallen segments (`clonal: sucker`).
  - One-night white flowers pollinated by bats and moths in late spring; red fruit spread by birds; cold-dormant; never browsed.
  - The tree-sized ones (terscheckii, validus, 6–12 m) sit in lower dry valleys and act as landmarks.
  - Each entry carries a `ceremonial` tag — `documented` (pachanoi, peruvianus, bridgesii, scopulicola), `reported`, or `trace` — that the ceremony system reads.
  - The `cactus` shape exists already; verify it can do a many-armed column and a trunked tree form.
  - ⚑ Checked, and it can't yet. Today's `cactus` is one fixed saguaro-like silhouette — a single column with two elbow arms, the same for every cactus species. It makes no many-armed column, no basal clump and no trunked tree. This phase gives it parameters (arm count and heights, basal pups, a trunked candelabra) along with the growth stages.
  - Macrogonus is `reported` (set in the file 2026-09-27, as the designer ruled); four species are `documented`, as above.
  - ⚑ The file differs from this text in three places:
    - validus is 4–8 m tall, not 6–12;
    - chalaensis grows at 100–1,200 m, not high ground;
    - six entries share Kew's *Echinopsis macrogona* but count as separate species under the binomial rule.
- **Plant groups.** Every biome has four groups, and they overlap freely across biomes because plants read climate, not biome names: **trees** (canopy, emergent), **bushes** (shrub), **grasses and low plants** (ground), and **the catalogue plants** (aroids, cannabis, torch cacti, yuccas, palms, fungi), which carry their own bands and land wherever they fit. The biome files hold 661 researched entries (537 binomials, 558 names); the catalogues 469.
- **Species pre-filter per cell (R6 performance gate) — required.** 661 + 469 entries is too many to test per site. At load, bin species by climate (temperature × moisture bins per tier, with margins for aspect, lapse across a chunk and the water boost); a chunk takes the union of the bins it covers, then drops what its soil and needs exclude. Report per-site candidate counts and chunk timings before and after.
- **Shape work** (with the growth stages, which every plant shows):
  - `palm`: fan versus feather crowns, a clustering (multi-stem) form, and the doum palm's forking trunk.
  - `cactus` / `gnarled` builder: a dagger-crown yucca tree (Joshua-tree form: forking arms, each ending in a ball of stiff leaves), besides the torch-cactus forms above.
  - `aroid`, as specified above.
- **Fungi — data and look** (`data/plants/fungi.json`, 43 species with a `fungus` block, D4). Fungi are not plants: they read **dead matter** — `substrate` snag_log, litter, dung, carcass or burn — or are `mycorrhizal`, living on the roots of named living trees and fruiting under them. Climate only gates **when** they fruit: `fruit_after_rain_days` after rain, in `fruit_season`. `species_db` loads them apart from the plants: never placed by climate bands, only on their substrate.
  - NEAR: fruiting bodies appear on the actual snag, log, litter patch, dung or carcass a few days after rain and run pin → button → cap → spent over days. Fairy rings widen each year. Glowing kinds (honey-fungus foxfire, ghost fungus, jack-o'-lantern, the glowing bonnets) light the forest floor and cave mouths at night as small teal-green points in the R1a accent. Morels flood last year's fire scar.
  - The player can forage them, reading `edible` (yes, cook, no, poison, deadly). Hooks for Phase 10: camp folk who know the woods warn of the deadly ones; tinder fungus lights fires; reishi and truffle are trade goods; a giant puffball feeds a camp.
  - ⚑ The seven mycorrhizal entries don't name their host trees yet; the host list is a data pass before Phase 7 reads it.
- **Do not build:** fauna in the ledger (Phase 7), spreading fire (Phase 9; this phase has only the harness's scripted test burn), camp and player uses of plants (Phase 10).
- **Done when:** a fertility overlay explains why a valley is lush and a ridge is bare; walking the stamp shows the right plant sizes in the right places; an old-growth patch on the stamp shows live trees, snags and logs together, and a young patch shows none; a runner plant shows visible stems linking a uniform patch; a bird-dispersed berry appears across a river its parent can't cross; a test burn regrows grass, then shrub, then trees with no stage coded; an aroid blooms, stinks, draws flies, and vanishes for the dry season; a female cannabis plant flowers on the day the sky says it should for that latitude; a forest patch on the stamp shows all four stages at once and a burn scar shows only the first two; a sapling browsed by deer never becomes a tree; a camp's planted plot is visibly taller each dev day; the species pre-filter's candidate counts and chunk timings are reported before and after; brackets appear on a wet-forest snag a few days after rain, and foxfire glows on it at night.

## Phase 7 — Ecology core
- **Touches:** `ecology/ledger`, `ecology/events` and `tools/eco_sim.gd` (all from Phase 6), `creature_spawner`, `creatures.json`.
- **Life from life (A2):** the spawner deals individuals from the ledger's population and never rolls new ones; a species wiped out in a region stays gone until it walks back in. Browsing (A2) runs here: goats and deer eat plants at the stages they reach, writing `flora.age_structure`.
- Add fauna to Phase 6's ledger and harness: food web (R3), diet caps, nests, fauna in the warm start; the harness (a headless run of N years on the stamp at max speed, CSV plus PNG charts, fixed seed with a multi-seed flag) gains population by species and region, camp food and the events timeline.
- **Cave fauna:** bats that roost by day and pour out at dusk, cave fish, blind salamanders and spiders join the ledger with `underground: true`; their regions are the cave-bearing cells from Phase 3.
- **Cavity chain:** snags are habitat. Wood-boring beetles and grubs live in snags and logs (insect count capped by snag count). Woodpeckers eat them and carve cavities — a snag gains a cavity slot when a woodpecker nests there. Owls, squirrels and other cavity nesters use old cavities; they can't nest without one. Owls hunt rodents at night. So `nest.site: cavity` requires a snag with a free cavity in the region.
- **Foraging is the interaction** (part of the creature loop). Every creature's "seek food" step is a real trip to a real food object, not a number from the ledger.
  - NEAR food objects: blooms, fruit and seed on mature plants; leaves and sprouts by growth stage; insects on their substrates; carcasses; fungi; prey.
  - Each creature's `diet` names object kinds (D4). It searches its range for the nearest reachable match — bees see blooms within tens of metres, a fruit bat smells ripe fruit across a valley — goes there and eats it, and the object visibly changes.
  - **Pollination is a side effect of feeding.** A nectar-feeder carries pollen from one bloom to the next same-species bloom it visits; a matching visit sets seed. `pollinator` says who can: insect (bees, beetles, butterflies by day, moths by night), carrion_fly, bird, bat, wind (no visit — pollen drifts along `wind_avg` and sets seed if a same-species plant is in range), self. No matching feeders in range means no seed: the yucca without moths spreads only by offsets, and the aroid without flies never fruits.
  - **Dispersal is a side effect of eating fruit.** A frugivore carries seed for `seed_carry_h` and drops it where it is then — a bird at its roost or over water, a mammal on its trails, a fish downstream — as a real seed-bank entry at that spot. Gravity, wind and water need no creature. Human dispersal is camp folk dropping seed on the midden.
  - **MID** runs the same rules as rates from feeder counts and bloom counts; the harness checks that both tiers agree on average.
  - **Insects are creatures:** bees with hives (a nest type) and a range, butterflies following blooms, beetles and flies following carrion and dung, moths at night on pale blooms. Ledger counts like everything else; eaten by birds; the base of the food web.
- **Decay loop (fungi, ledger side).** Dead-matter pools: `flora.snags`, `flora.logs`, new `flora.litter` (leaf fall from the age structure each autumn and at dormancy), `soil.carcass`, and `soil.dung` from herbivore counts (D3). Fungi are the only thing that moves matter out of those pools into soil fertility, at `decay_rate` × moisture, per region, for the fungi present — this **replaces** Phase 6's fixed snag and log timers. No fungi in a dry region means logs sit for decades; a wet forest eats its dead in years. Mycorrhizal species raise their host trees' growth rate slightly.
- **Do not build:** fauna genetics, migration, fire, camps.
- **Done when:** the harness shows a stable 100-year run, a new world already has nests, the population overlay balances over dev days, a cat takes a rodent, a wolf pack shows up where deer are; a woodpecker is seen on a snag by day, an owl leaves a cavity at dusk; a flowering shrub with bees sets fruit and one without doesn't; a berry bush's seedlings come up under the birds' roost tree; a wind-pollinated grass sets seed on a windy day with no insects; a wet-forest snag sprouts brackets after rain and is gone in a few dev years while a dry-ridge snag stands for decades; a fairy ring is wider next year; foxfire glows at night.

## Phase 8 — Living populations
- **Touches:** ledger, `creature`, creature shader, `creatures.json`, `creature_spawner` (packs and dens).
- **(a) Genetics:** 8–15 genes per creature in 0–1; the species table maps each gene to a visible trait (size, coat, marking, leg length, speed, temperament bias) with a clamped range; newborns take each gene from either parent plus small mutation; the shader reads tint, pattern, and scale from genes; the rare variant is a gene past normal range and is heritable. Sex is one bit; the species table has male and female rows for range, nest-tending, and aggression; breeding needs both in a region.
- **(b) Migration:** food location shifts with season; herbivores follow food downhill and warmward, predators follow prey — no new behaviour, only seasonal food.
- **(c) Carcass chain:** any death leaves a carcass record {region, position, mass, day}; scavengers seek it, predators are drawn by it, it decays into soil fertility over days.
- **(d) Pack order** (any species with temperament: pack — wolves, wild dogs, jackals, hyenas, lions). A pack is a family: a breeding pair leads, their surviving offspring rank below them by age, and the youngest are last. Rank is derived, not stored: age, sex, and parentage from the ledger, plus a dominance gene. No alpha stat.
  - **Rank decides who does what.** Leaders choose the target, the direction of travel, and eat first at a kill; the rest eat in order and the lowest wait — a big pack at a small carcass leaves its youngest hungry, which the memory system turns into scavenging or leaving. Leaders howl first; the pack answers. Mid-rank adults flank and drive prey; the lowest hang back and yip. Only the leading pair breeds.
  - **Order changes.** When a leader dies or grows old, the strongest adult offspring takes over, or a pack splits — an older offspring leaves with a few siblings and founds a new pack in an empty region if one is free. Two packs meeting at a border posture and, rarely, fight; the loser's territory shrinks. All of it writes to the events log.
  - **Visible.** Rank reads on screen: leaders larger with tail and head up, the lowest crouched with tail down; the pack moves in file behind the leader; at a kill the order is watchable.
  - **Player.** The pack targets whoever the leader targets; kill a leader and the pack breaks off and regroups; a leaderless pack is bolder around camps and worse at hunting for a season.
  - ⚑ "Age, sex and parentage from the ledger" means packs are kept as families: `fauna.packs` (D3), and ranks are computed from it. The memory system is Phase 11; until then the hungry youngest scavenge or leave by rule.
- **Done when:** the harness shows genome means drifting apart between separated regions, herds visibly move in winter on the stamp, and a carcass draws a scavenger and leaves a green patch; on the stamp, a wolf pack walks in file, feeds in order, and a new pack appears in an empty valley within a few dev years of the old one growing.

## Phase 9 — Disturbance and living water
- **Touches:** `weather_sim`, ledger, soil, `vegetation_placer`, `river_network`, `terrain_chunk` water.
- **(a) Fire:** lightning or a camp fire, plus dryness and flora density, ignites; spreads per region by wind and dryness; consumes flora biomass, adds fertility, writes `burn_scar`; NEAR shows burning trees, smoke, blackened ground; scars regrow over years — grass, then shrub, then young trees — by Phase 6's seed, clonal and growth rules, never as scripted stages. A burned patch becomes a field of snags at once.
- **(b) Flood:** storm plus swollen river floods low regions; flattens ground flora, deposits fertility, drowns burrow nests.
- **(c) Living water:** lake level and river width follow season and recent rain; boats read width for passability; the water mesh height updates when a chunk streams.
- **Done when:** on the stamp a dry-season strike burns a patch that comes back as meadow, the harness shows fires as bounded pulses, and a river you could paddle in spring is a rocky bed in late summer.

## Phase 10 — Camp life and culture
- **Touches:** `camps`, `encampment`, `campfire`, `player/*`, light inventory, `landmarks`, `ruin_builder`, the parked set pieces (`hold/set-pieces`), `post_grade`, audio.
- **Player loop:** fish (rivers/lakes/coast, by water temp), forage (berries/fruit/roots by biome), hunt (bow/spear) → carry a few things (Appendix R4) → bring to a campfire → **cook at night with the camp folk**. Cooked food restores health; the fire is the ambient social moment.
- **Camp folk loop:** foragers/hunters/fishers go out by day, gather from the ledger and flora, return by dusk; food surplus → camp grows → more pressure on nearby prey → range farther or shrink. Background camp-to-camp trade. **Do not script outcomes.**
- Camps are night safe zones. Interaction proximity-based; no dialogue trees.
- **Firewood:** camp folk gather snags and logs for firewood first, so old wood thins near camps.
- **Culture:** each camp holds culture sliders {fish, hunt, forage, wary, range, ritual_smoke, ceremony} seeded from biome and the landmark it formed around, and moved by events — a wolf raid raises wary, a rich river raises fish. Goods, chatter, and how folk react to the player read from the sliders.
- **Camps form around remnants:** camps already sit in inhabited ruins, wild sites and cliff sites. Make it a scored rule: every landmark — tower, castle, aqueduct, pyramid, graveyard, barrow, boardwalk, treehouse, igloo, bridges (unpark `hold/set-pieces` for this phase), cave mouths, springs, river fords, waterfalls — gives nearby sites a camp score from water, flat ground, food (flora biomass and ledger fauna), shelter, and distance from other camps. The highest scores get camps. The landmark's kind seeds the camp: aqueduct → water and farming; ford or bridge → crossing and trade; graveyard or barrow → small, wary, afraid of the night; cave mouth → shelter and mining, wary of the dark; castle or tower → largest and best defended. Camp folk salvage from the remnant (worked stone, timber, metal scraps) — the remnants are the work of an older, more advanced people, and salvage is where a camp's rarer tools come from. Culture sliders start from the landmark kind. New camps at remnants never form inside a landmark; the fire sits where the ruin builder left it. Camps already inside ruins (the inhabited-ruin camps) stay where they are — the rule is for new camps only.
  - New remnant kinds, built in this phase (R1a, second reference batch): stone stairways up cliffs, hung bells, a stone giant or idol gate, hollow-tree dwellings, wells, chapels with candlelit interiors. The parked set pieces already hold a chapel.
  - ⚑ Today the ruin builder puts tepees, lean-tos and a fire inside some ruins. Read as: the builder's fire stays where it is and scored camps form beside landmarks, not in them — confirm whether those inhabited-ruin camps move out. Fords don't exist yet (derive them from river width and depth); cave mouths come from Phase 3.
- **Cannabis — the loop:** three uses through the ordinary R4 carry rules — hemp types give fibre (stems → cordage and cloth for camp folk) and seed (food, oil); resinous types give smoke. Player: cut flowering females → carry a bundle (one inventory item) → hang it by a campfire or in a hut, where it dries over several in-game days as a visible state (the reference: dried herb bundles hanging from rafters, R1a second batch) → smoke it in a pipe (bone or clay; craftable, or a camp folk hands one over) at the fire. No numbers in the UI; strength comes from the plant's resin gene and how much is smoked.
- **Haze, on the player:** one status, `player.haze`, 0–1, in WorldState so other systems read it; decays over about an in-game hour.
  - Visual, in `post_grade` as a temporary grade shift within R1: the world goes more R1a — night bluer, fire warmer, saturation up, edges soften, the camera sways slowly, stars swim, distance haze thickens. Audio muffles with more reverb and footsteps go hollow.
  - Status: hunger rises faster, fear cues soften (the howl still comes but the panic vignette doesn't), sprint starts slower, the bow sways, and an occasional cough is a real noise event creatures hear — sneaking while hazed is worse.
  - Overdo it and the vignette closes in, the ground tilts, and the player stumbles for a while; nothing lethal. It's a trade — calm and company against slow and loud — never a plain buff.
  - ⚑ Hunger, a fear/panic vignette and oracle tribes don't exist yet; they arrive with this phase or stay hooks.
- **Haze, in camps:** culture slider `ritual_smoke` (0–1), seeded from whether a resinous landrace grows in the camp's range, moved by history like the others. In a camp with the habit the pipe goes round at the fire after cooking: folk sit longer, chatter turns to laughter and slower speech, they sleep later, guards are drowsier — the camp is a little less safe that night, which the ledger's predators may notice. Astrology tribes with oracles smoke before reading the moon. Sharing the pipe is a proximity interaction, no dialogue tree, and raises standing with that camp the way sharing food does. Camps without the habit ignore the bundle; a few wary ones dislike the smell.
- **Trichocereus ceremony:** ceremonial only; the cactus can't be used raw or alone. A highland camp with an oracle (astrology tribes; culture slider `ceremony`, seeded high in the Andean-type mountain bands where the cactus grows) holds a night ceremony at the fire when moon and season line up.
  - The oracle prepares a brew from cut columns — one visible pot at the fire over a few in-game hours — and offers it to the circle. The player takes part by sitting in the circle; camp folk who take part are visibly in it too. No numbers, no menu.
  - The oracle reads each cactus entry's `ceremonial` tag: `documented` gives the full ceremony, `reported` a shorter, dimmer one, `trace` is refused — "not this one." Only the documented species can produce the reading.
  - **Effects on the player:** one status, `player.vision`, 0–1, in WorldState, lasting several in-game hours and rising slowly before it peaks.
    - Visual, in `post_grade` within R1: geometry stays put but surfaces breathe; textures slowly slide and repeat; a faint stepped-geometric lattice in the Incan tocapu style — squares, diagonals, stepped crosses — drifts over the world and gathers at the screen edges, in gold #E8B84A and deep red #A01020 over the blue; colours cycle toward the R1a extremes; moon and stars grow trails; distant mountains seem to lean in.
    - At the peak the fire shows brief figures — a stag, a serpent, a condor — that vanish when looked at, drawn from that region's events log so the visions are its history.
    - Audio: the drone rises, the fire's crackle spreads into rhythm, camp chatter falls away.
    - Status: no sprint, aim useless, hunger and thirst afterwards, and the player is effectively helpless — which is why it's done inside a camp, with guards.
    - Taken outside a ceremony, or if the player wanders from the fire into the dark, the lattice turns cold blue, fear cues sharpen instead of softening, and creatures read the player as easy prey. It's a trade of a night's safety for sight.
  - **What the player gets: the oracle's reading.** At the peak the ceremony reveals one true thing about this world from the events log or the ledger — where the mythic sleeps, which valley the herds will winter in, when the next full moon falls, a remnant nobody has found. Nothing invented: the reading is always a real record. This is how a wanderer learns what the tribes know.
  - **Camp folk:** on ceremony nights the camp sits up till dawn, no hunting the next day, the oracle's standing rises, and a player who took part is treated as a guest of the fire. Camps without the cactus in range never hold one; carrying cut columns to a camp that has an oracle but no cactus is one of the few trades that matters.
  - ⚑ Thirst, like hunger, doesn't exist yet; oracles arrive with this phase.
- **Done when:** you catch a fish, bring it to the opening camp, cook it at dusk with the folk, and the camp's own hunters are seen leaving and returning; plus two camps with different histories visibly behave differently; on the stamp, every large landmark has a camp near it or a visible reason it doesn't (no water, too steep), and camps at two different landmark kinds look and act differently; a hemp stand near a camp becomes rope on its huts; the player dries a bundle by the fire, smokes it, the grade shifts and a cough spooks a deer; the camp folk pass a pipe and their guard nods off; at a highland camp on the stamp a ceremony happens on a full moon, the lattice and fire-figures show, the oracle's reading names a real event from the log, and the player is visibly vulnerable until dawn.

## Phase 11 — Memory and lore
- **Touches:** `creature` (NEAR), `camps`, scrolls, HUD place names.
- **(a) Creature memory:** each NEAR creature keeps up to ~5 memories {what, where, when, good or bad} that decay over days; a wolf that lost packmates near the campfire avoids it, a fed fox returns.
- **(b) Lore:** place names, scroll text, and camp chatter are generated from `world.events` — "the meadow where the herd died," "the ridge fire of year 12" — so the world's story is what actually happened in this seed.
- **Done when:** a creature visibly changes behaviour toward the player after an encounter, and a camp folk mentions an event the harness log shows really happened nearby.

## Phase 12 — Persistence
- Elapsed-time catch-up on login using the warm-start code (Phases 6–7). **Done when:** log out, wait, log in — crops/nests/populations/moon advanced, nothing exploded.
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
- No bees in the valley, no fruit in the valley.
- The plant that survives the fires is the one that spreads underground.
- The camp that smokes gets raided more.
- The landrace that crossed the mountains with a tribe doesn't flower in time.
- Where the deer are thick there are no saplings, and the forest ages without children.
- The valley with no wolves gets its wolves from the pack next door's grown children.
- Kill the bees and the orchard stops.
- The fig's children grow where the bats sleep.
- The forest that keeps its fungi keeps its soil.

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
| Day sky | #0A1AE0 zenith (was #1436FF) → #4C7CFF horizon — as saturated as night; clouds hard-edged white; no haze washing the day out |
| Grass | day #3FA83A, #4CC03A in full sun / shadow #1F5A22, cooling toward #1E4A6A at night |
| Dirt / bark | #6B4A2E → #A07A4A — the one warm ground colour |
| Stone | #6F7A8A day, #3E4C8C night; moss #3F7A3A |
| Fire | #FFB020 core, #FF4A00 coals, #FFA050 light on folk and props, #FF7A2A ground pool |
| Windows / lanterns | #FF3A2A / #FFC040 |
| Snow | #C8D8F0 with #6A82C0 shadows; snow scenes go fully blue, no white |
| Deep night (grade) | full blue: every surface tinted toward #1B2ED8, local colour nearly gone. The night rows above are the dusk/moonrise end of the range; the grade slides between the two through the night |
| Storm / volcanic sky | purple-magenta, #5A1AA0 → #C030C0 streaks, instead of grey |
| Dread accent | #A01020, a single deep red, rare |
| Vision lattice (ceremony only) | gold #E8B84A and deep red #A01020 over the blue (Phase 10, Trichocereus ceremony) |

Rules: saturate, never desaturate; scenes are blue plus one warm accent; nothing pure black. Warm light stays tiny — candles, hearths, windows — one or two points per scene. The tone ceiling is dread, not gore.

**Second reference batch (designer, 2026-09-27)**, stills in `docs/references/batch2/` (ten: day castle by a river, cottage with ghost sheets in teal mist, moonlit river, boat under a nebula, glowing-bark pool, candlelit corridor with an antler shadow, bell trees under a swirling sky, skull dwelling, fountain of blood, wizard and goblins), the designer's text verbatim:
> R1a additions from the second reference batch. Day sky is as saturated as night: zenith `#0A1AE0`, clouds hard-edged white, grass `#4CC03A` in full sun; no haze washing the day out. Deep night is a full-blue grade: every surface tinted toward `#1B2ED8` with local colour nearly gone; current R1a night values are the dusk/moonrise end of the range and the grade slides between them through the night. Storm and volcanic skies go purple-magenta (`#5A1AA0` → `#C030C0` streaks) instead of grey. Warm light stays tiny — candles, hearths, windows — one or two points per scene; a single deep red (`#A01020`) is allowed as a rare accent for dread. Snow scenes go fully blue, no white. New remnant kinds for the ruin builder, to be built in the Camp life phase, not now: stone stairways up cliffs, hung bells, stone giant/idol gate, hollow-tree dwellings, wells, chapels with candlelit interiors. Dried herb bundles hanging from rafters are the reference for the drying state in camp huts.

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

**Mountains, cold–mild and mild–warm bands:** goats — herd animal, sure-footed on slopes, browser (A2, Browsing).

Rules: generalists (wolf, deer, bear, hawk, cats, rats) span many bands; cold-blooded lock to warm bands; every predator has a `diet` list and is capped by it; herd and pack sizes follow food, never set directly; water creatures read water temperature; mythic ignores sharing rules.

Nesting habits (examples for `nest.site`): tree-fork, cavity, cliff-ledge, ground-scrape, reed-bed, burrow. Different birds pick different sites; that's the whole rule.

## R4. Inventory principle (built in Phase 10, kept tiny)
- A **handful** of items; visibly overburdened — slower, worse climbing, louder — past a low threshold. No grid.
- Every carried item changes a decision (torch, spear, tonight's food, one trade good).
- Equipment slot-based: one equipped + two spares per slot (rings: two worn + two spares).
- Weight felt in movement, never read in a menu.

## R5. Out of scope until Phase 12 is stable
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
10. **Performance gate: species pre-filter.** No per-site loop tests every species. Placement and the ledger read per-cell (or per-chunk) candidate lists built once at load from climate bins (Phase 6). Required from Phase 6: 661 biome entries + 469 catalogue entries.
