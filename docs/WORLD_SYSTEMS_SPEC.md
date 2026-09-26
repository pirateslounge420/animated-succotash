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

## Current phase: **Phase 0 — Look & Light**

Target: **2000–2004 console 3D** (Dreamcast / GameCube). Low-poly *and smooth*. See Appendix R1.

**Suspected causes of the blocky look, to confirm in audit:**
1. `post_grade` — dithered color depth and sharpening. Replace with: subtle film grain, slight color bleed, mild fog haze, viewport render scale ~0.75–0.8 for 480p softness. Keep the night tint.
2. Texture filtering — procedural `look_textures` may be sampled nearest-neighbor. All world materials → **linear with mipmaps** (`texture_filter = LINEAR_MIPMAP`).
3. Foliage — check that leaf clusters are alpha-cutout quads/low-poly clusters, vertex-colored, not blocky.
4. Terrain normals — smooth, not faceted; no stepped edges.
5. Environment — glow/bloom off, SSAO off, MSAA 2x at most.
6. Sky — 45/20/35/20 split, smooth lerps of sky/sun/ambient/fog through dawn and dusk.

**Done when:** a dusk screenshot by the river could be from a GameCube disc, and a 20-min time-lapse shows sun and moon crossing with no snapping.

**Prompt A (paste this):**
> Read docs/WORLD_SYSTEMS_SPEC.md and docs/PROGRESS.md. We are in Phase 0. First, tell me exactly what the restyle and set-piece agents are changing in their copies, and whether it matches Appendix R1. Then audit the current render path against R1 and the six suspected causes in Part C — post_grade, texture filtering, foliage, terrain normals, environment settings, and the day split — and list in plain English where it diverges. Propose a fix order. Don't change anything yet.

---

# PART D — Architecture

### D1. World scale (locked)
Spherical wraparound cube-sphere, **400 km** circumference, relief ≈ 1/10 Earth, floating origin around the player. Already built — keep it.

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
Each field has exactly one owner. Existing fields keep their names; add the missing ones.

```
seed                         planet_generator
clock.time_of_day/day/season sky_system (season NEW)
sky.sun_dir/moon_dir/moon_phase/light/ambient   sky_system
terrain.height/rock/water/current/temp_base/moisture/biome   planet passes
atmo.pressure/wind/temp/humidity                 weather_sim
weather.state/intensity                          weather_sim
soil.fertility[]                                 NEW soil pass
flora.biomass[region][stratum]                   vegetation_placer (NEW field)
fauna.pop[region][species]                       NEW ecology ledger
society[camp].pop/food/roles                     camps (NEW fields)
```

### D4. Data schemas (extend existing files; don't rename)
```
data/biomes/<biome>.json   + weather_odds, mythic_creature, (keep plant lists; add per-plant stratum)
plant                      { id, stratum(canopy|under|ground), temp_min/max, moisture_min/max,
                             soil_min, slope_max, sway_stiffness, seasonal_color }
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

## Phase 0 — Look & Light  ← current
See Part C.

## Phase 1 — Player feel, hitboxes, audio
- **Touches:** `player/*`, `core/controls`, `project.godot` input map, `creatures/sound_synth`, audio players.
- Implement D5 in full: double-tap sprint, Shift sneak with reduced noise radius, hitbox audit on player/creatures/trees/ruins/projectiles, spear (thrust/throw/retrieve), all sounds 3D with attenuation.
- **Do not build:** new creatures, new systems, combat balancing.
- **Done when:** a recording shows double-tap sprint, sneak past a deer that would otherwise flee, an arrow and a thrown spear sticking where they visibly hit, and a howl that pans and fades as you walk away.
- **Prompt A:**
> Phase 1. Audit the input map, player movement states, collision shapes on player/creatures/trees/ruins/arrows, and how world sounds are played (2D vs 3D, attenuation). Propose the minimal changes to hit D5 exactly. Wait.

## Phase 2 — World generation alignment
- **Touches:** `planet/passes/*`, `river_network`, `biome_templates`, `data/biomes`.
- Add a **tectonic skeleton** pass before terrain (plate boundaries on the sphere; ranges and ravines follow them; plates never move).
- Verify hydrology produces a **current direction** per river segment.
- Verify climate pass does **ridge-blocked moisture** (windward wet+fog, leeward dry) using prevailing wind.
- Reconcile **51 vs 52 biomes**; make sure biome lookup is Whittaker (temp × moisture) with smooth noise blending.
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
- **Touches:** new soil pass, `species_db`, `vegetation_placer`, `data/biomes/*.json`.
- Soil fertility accumulates where warm, moist, flat, littered; thin on steep rock, cold, dry. `vegetation_placer` adds fertility to suitability.
- Tag every plant with a **stratum**; ensure each biome has canopy / understory / ground per Appendix R2. Small counts.
- **Done when:** a fertility overlay explains why a valley is lush and a ridge is bare; walking the stamp shows the right plant sizes in the right places.

## Phase 6 — Ecology ledger & food web  (the big one)
- **Touches:** NEW `ecology/ledger`, `creature_spawner`, `creature`, `creatures.json`, `territories`.
- **Regional population ledger:** per region, per species, a count. The spawner *reads the ledger* to decide what appears near the player, instead of rolling from nothing.
- **Food web** (Appendix R3): insects (beetles, worms, caterpillars→butterflies) and seeds → birds and small rodents → cats and small canines → apex (big cats, wolves, bears; sharks and big fish in water; cichlids in warm lakes/rivers). Each species has a `diet`; predators are capped by prey counts; prey by flora biomass; scavengers return biomass to soil.
- **Every creature has the same loop:** seek food → drink → rest/perch → reproduce (`reproduce_days`) → build/maintain `nest` per its habits (ground, tree, cliff, burrow, reed). Nests are real objects in the world.
- **Warm start:** at generation, run the ledger forward N in-game days so the world spawns *already running* — nests built, territories settled, populations at a plausible balance. This is the same code Phase 8 uses for catch-up. Build it once.
- Night danger, mythic per biome (`biome_lock` + distance-scaled cue), full-moon hunters, rare variants — as in R3.
- **Do not build:** combat balancing, inventory, camp economy.
- **Done when:** population overlay shows a region balancing over several dev days; a bird visibly returns to a nest; a cat takes a rodent; a wolf pack shows up where deer are; a new world already has nests in the trees.
- **Prompt A:**
> Phase 6. Audit creature_spawner, creature behaviors, territories, and creatures.json. Propose the ledger structure (region size, tick rate), how the spawner will read it, the diet/capping rule, the nest object, and the warm-start. Draft a first roster from Appendix R3 — insects, birds, rodents, cats, canines, deer, wolf, bear, fish, shark. Wait.

## Phase 7 — Camp life
- **Touches:** `camps`, `encampment`, `campfire`, `player/*`, light inventory.
- **Player loop:** fish (rivers/lakes/coast, by water temp), forage (berries/fruit/roots by biome), hunt (bow/spear) → carry a few things (Appendix R4) → bring to a campfire → **cook at night with the camp folk**. Cooked food restores health; the fire is the ambient social moment.
- **Camp folk loop:** foragers/hunters/fishers go out by day, gather from the ledger and flora, return by dusk; food surplus → camp grows → more pressure on nearby prey → range farther or shrink. Background camp-to-camp trade. **Do not script outcomes.**
- Camps are night safe zones. Interaction proximity-based; no dialogue trees.
- **Done when:** you catch a fish, bring it to the opening camp, cook it at dusk with the folk, and the camp's own hunters are seen leaving and returning.

## Phase 8 — Persistence
- Elapsed-time catch-up on login using the Phase 6 warm-start code. **Done when:** log out, wait, log in — crops/nests/populations/moon advanced, nothing exploded.

---

# PART F — Emergence checklist
The designer should be **surprised**. If any of these had to be hard-coded, the system is wrong.
- A camp by a river stays fed and grows; one in scrubland stays small.
- Prey thins near a big camp; predators drift off.
- Rain on the sea side of a range, drought behind it; the forest roars before rain arrives.
- Full-moon nights are noticeably worse than new-moon nights.
- Birds nest in different places for different reasons, without anyone placing a nest.
- A cat's territory sits where the rodents are, and moves when they do.

---

# APPENDICES — Reference (Claude Code consults; designer edits)

## R1. Render target: 2000–2004 console 3D
References: Phantasy Star Online Ep. 1&2, F-Zero GX, Super Smash Bros. Melee, American McGee's Alice, early League of Legends map atmosphere.

| Element | Do | Don't |
|---|---|---|
| Geometry | Low polycount, smooth-shaded organic shapes; rounded trunks, sloped terrain | Voxels, cubes, faceted flat shading |
| Textures | 64–256px painted-style, **linear + mipmaps**, gently soft | Nearest-neighbor / pixel-art |
| Terrain | Continuous mesh, smooth normals | Blocks, stepped terraces |
| Lighting | Directional sun + directional moon, simple shading; soft ambient fill | Blocky baked light, harsh cutoffs |
| Post | Subtle grain, slight color bleed, mild haze; render scale ~0.75–0.8 | Sharpening, dithered color depth, bloom, SSAO, heavy AA |
| Palette | Saturated blue nights, warm orange fire, mossy greens, cold grey stone | Neon, pastel, pure-black shadows |
| Foliage | Alpha-cutout quads / low-poly clusters, vertex-colored | Cube leaves |

**Acceptance test:** a dusk screenshot by the river could be from a GameCube disc.

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
| Cold–mild | Beetles, worms, caterpillars | Songbirds, squirrels, voles | Fox, lynx, hawk, wildcat | Wolf, bear | Trout-type, otter, beaver | Boreal moose-elk · Deciduous stag spirit |
| Mild–warm | Beetles, butterflies, worms | Songbirds, rabbits, rats, mice | Coyote-type, bobcat-type, eagle | Cougar-type, bear | Bass-type, heron | Grassland thunder-bull · Woodland horned boar |
| Warm–hot, wet | Giant beetles, butterflies, ants | Parrots, monkeys, agouti-type | Ocelot-type, big snakes, harpy-type | Jaguar/tiger-type | **Cichlids**, crocodile, piranha-type | Rainforest canopy serpent · Swamp bog-lurker |
| Warm–hot, dry | Scarabs, scorpions | Sand grouse, jerboa-type, lizards | Jackal-type, caracal-type, vulture | **Lion**, hyena | Oasis fish | Savanna mane-lord · Desert sand-wyrm |
| Ocean / big lake | Plankton (implicit) | Shoal fish | Big fish | **Shark** | — | Leviathan |

Rules: generalists (wolf, deer, bear, hawk, cats, rats) span many bands; cold-blooded lock to warm bands; every predator has a `diet` list and is capped by it; herd and pack sizes follow food, never set directly; water creatures read water temperature; mythic ignores sharing rules.

Nesting habits (examples for `nest.site`): tree-fork, cavity, cliff-ledge, ground-scrape, reed-bed, burrow. Different birds pick different sites; that's the whole rule.

## R4. Inventory principle (built in Phase 7, kept tiny)
- A **handful** of items; visibly overburdened — slower, worse climbing, louder — past a low threshold. No grid.
- Every carried item changes a decision (torch, spear, tonight's food, one trade good).
- Equipment slot-based: one equipped + two spares per slot (rings: two worn + two spares).
- Weight felt in movement, never read in a menu.

## R5. Out of scope until Phase 8 is stable
Werewolf/vampire transformation, grappling hook, underwater exploration/breath meter, player-founded tribes, advanced tech tiers (rail carts, forges), crafting quality tiers, combat damage balancing, any weapon beyond bow and spear. All remain in the long-term design.
