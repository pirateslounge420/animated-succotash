# PROGRESS.md — running log (newest on top)

Claude Code prepends 3–6 lines every session. The designer signs off phases here.

---

## 2026-10-02 — Mike's 1 Oct 23:11 play: grey-box plants and Day 14 — causes found and reproduced (design chat; design §CG)
- **The frames shown so far were all harness frames:** `tools/dev_view.gd` (seed 42, the first camp, a fixed third-person camera 9 m south of the fire, weather held clear), `walkabout.gd` and `species_row.gd`, all rendered on the cloud machine (xvfb, lavapipe, Godot 4.3, the import cache complete). None is play on Mike's Mac, and none could show this bug.
- **The grey boxes, reproduced** (Godot 4.3.stable.official.77dcf97d8 headless, this branch at `34f9d42`, `.godot` built by `--import`): with the import cache present, `Look.texture("leaf_card")` is an ImageTexture with 458 of 1,024 pixels cut out and the plant material holds it. With `.godot/imported` moved aside (the class cache kept), `ResourceLoader.exists` still says true (the committed `.import` file), `load()` fails ("Failed loading resource: res://.godot/imported/leaf_card.png-….ctex. Make sure resources have been imported by opening the project in the editor at least once."), `Look.texture()` stops on "Cannot call method 'get_image' on a null value" and returns null, and the plant material's `look_tex_leaf_card`, `look_tex_leaves` and `look_tex_bark` are all null. The same for grass. Godot samples an unset `sampler2D` as opaque white: alpha 1, so the cards never cut out, and `foliage.gdshader` draws `base × tex × 2`, so they wash out pale. The 23:11 frame, cropped: bamboo culms with their shader-drawn node rings and no bark, leaf cards as flat solid quads, the ground smooth green with no tiles. Every importer-fed texture is empty; every shader-drawn detail is there.
- **Since when:** `df993d6` (28 Sept, 18:24 Chicago) moved the world tiles to `load()` through the importer; before it every world texture was painted at startup (LookTextures), so a project copy older than that draws its plants on any machine.
- **The same path elsewhere:** `SkySystem`'s cloud panorama (`load()` behind `ResourceLoader.exists`; it then bakes clouds itself but logs the load errors) and `ModelLibrary._scene` (an un-imported .glb whose `.import` exists gives null and never reaches `_read_raw`; no models are tracked yet). The font already guards this (`HudText._imported`, the 15:30 fix). The species tiles (`PlantMeshes.tile`) read their PNGs from disk and are safe.
- **Not the cause:** a headless `--import` prints 23 "Global uniform 'look_fog_color' does not exist" shader errors (`look.gdshaderinc:28`). They come from the dummy renderer, which ignores `[shader_globals]`; the global is declared in `project.godot` and a real GPU registers it.
- **Day 14:** `World.START_DAYS` is 13.62 (a near-full moon the first night). The HUD prints `int(Astro.apparent_days(...)) + 1`, the log's stamps `floor(world.days) + 1`, and the log's first line a fixed "day 1". At Mike's spawn (12.7°N, 140.1°W; the game's own `days_at_solar_hour` and `apparent_days`): `world.days` 13.9553, the HUD "Day 14 · 13:43" on waking, then "Day 15 · 14:40" 5.2 real minutes later; the log's stamps flip at 6.4 minutes. The day turns over at midnight at longitude 0, not the player's. The clock face and the log's stamps read the uniform clock (`fposmod(time_of_day + longitude / TAU, 1)`), the HUD line the sky's warped solar time: 13:35 on the face against 13:43 on the HUD at that spawn (Mike's frame: about 13:40 against 13:47).
- **Not known from here:** why the cache on Mike's Mac lacks the tiles (how the game is launched there, or the editor not re-scanning since 28 Sept). §CG makes it not matter. Opening the project in the Godot 4.3 editor and letting the import finish should bring the plants back before the fix lands.

## 2026-10-02 — Japanese hemp is an accent only: no evidence of terpene relevance (Mike: "we won't have that much Japanese hemp because there's no evidence of terpene relevance"; `cannabis.json`, `habitat.json`)
- **Where all the hemp came from:** in East Asian temperate forest Japanese hemp is often the Cannabis sativa landrace nearest in climate (one roll per binomial), so §CE's always_present made it a forced associate (an associate's whole share, not just `min_share`), and the stand roll could make it the dominant. Taking only the lift away still left it 8.8–24.4 % of the shrub layer, so the rule keeps it out of the stand roll's principal places too.
- **The rule** (`VegetationPlacer.accent_only`, `_apply_dominance`): the entry records `cannabis.terpene_evidence: "none"` (Mike's call, in its `terpene_note`), and the cannabis group's `no_terpene_evidence: "accent_only"` (`habitat.json always_present`) keeps such a landrace to the accents: never lifted, never a stand's dominant or associate. It still grows wherever it fits, scattered. A stand without it rolls exactly as before (the same draws).
- **Shrub layer at the same sites, before → after:** seed 467606063 2,968 (12.9 %) → 207 (0.9 %) and 7,198 (28.1 %) → 166 (0.8 %); 1378252316 4,476 (16.2 %) → 236 (0.9 %); 7731 (temperate deciduous) 5,057 (22.2 %) → 300 (1.3 %), and beside Korean hemp 551 → 26 and 643 → 45. Korean hemp, Kentucky feral hemp and the drug landraces (Kerala 13.3 %, Panama Red with Lamb's Bread 12.0 %) are unchanged. `tools/plant_presence_check.gd` now prints each group's share of its layer.
- **Not decided here:** the other six hemp-type landraces (Korean, Northern Chinese, Central Russian, Carmagnola, Anatolian, Kentucky feral) and the four ruderals carry no terpene note; adding `"terpene_evidence": "none"` to one makes it an accent the same way.
- **Checks:** `plant_presence_check` on 7731, 467606063 and 1378252316: every group PASS, 0 fails, 0 script errors; `plant_schema_check --strict` 0 errors; `biome_species_check` 998 allowed; `plant_trim check-keep` PASS; headless boot clean (the one quit-time thread warning, as before).

## 2026-10-02 — §CE presence and vines: the named plants always grow where they fit, vines over every surface (design 1 Oct §CE; `habitat.json` `always_present`, `vines.json`)
- **Always present** (`VegetationPlacer.presence_group`, `_apply_dominance`, `_one_per_binomial`): a member of an `always_present` group (Musa, Amorphophallus, Cannabis, Trichocereus, Acacia s.l., bamboo, vines; by genus, shape or name) that fits a stand's middle is always an associate, never an accent, and each group present gets at least `min_share` (6 %) of its tier's stems, split among its fitting members, the rest scaled to make room. Entries sharing a binomial roll as one species (`one_roll_per_binomial`): of the 64 Cannabis sativa landraces, the one nearest in climate.
- **Why Amorphophallus never grew:** the catalogue's `family_defaults.needs: ["forest_floor"]` was added to every entry on top of its own needs; 25 entries list a savanna, thorn-scrub or other open biome (§CA) and 5 list only open ones, so they could never pass. The entry's own biome list now wins over the family's `forest_floor` (`SpeciesDB`; the data is unchanged). The rest is soil: 238 of 246 take only alluvium, clay-peat, basalt or karst, so a rainforest on granite has none — the presence check now picks sites where a member's biome, realm, soil and climate all fit (`tools/plant_presence_check.gd`; a group with no such site is SKIP, not FAIL).
- **Trim** (`tools/plant_trim.py`): `always_keep` groups are never trimmed; vine is the tenth category; `check-keep` asserts a re-run keeps every member (21 of 21 restored present, 7 groups).
- **Vines over surfaces** (`VineCover`, `data/vines.json`): the biome's vine species that fits the spot (`species_at`):
  - trunks — `surfaces.trunk.cover` × climate of the trees carry one, up their `climb_share` of strands; the mat-3 strands take the vine species' leaf tile and colour (`foliage.gdshader` `sp_vine_*`);
  - dead wood — `surfaces.log`;
  - cliffs — patches hanging down steep faces; open ground — creeping patches (`surfaces.cliff`, `surfaces.ground`), leaf cards on strands with the species tile, drawn within `near_m`; past it the ground under a patch takes the vine's green (`VineCover.green`, `far_tint`, default 0.5 — not in vines.json yet);
  - ruin walls and heaps — hung from the ivy strands' tops (`RuinBuilder` `vine_anchors`, recorded without a new roll, so every ruin builds the same), by `surfaces.ruin` × climate × age (`ruins.full_after_years`); a camp restoring it cuts them back with its ladder (rung 1 half, rung 2 bare; `restored_clears`); an abandoned camp is taken back as the forest takes it (`CampSim.reclaim`, `forest_takes_game_days`).
  - boulders — a ruin's tumbled rocks, draped from their tops (`boulder_anchors`, `surfaces.boulder`); the road-gate and camp boulders not yet.
- **Data fixes with sources:** _A. incurvatus_ `temp_c` [14, 21] (Kerinci, 1,770 m; the lapse rate from lowland Sumatra's ~27 °C); Cannabis "Kashmir" `moisture` [0.45, 0.68] (Srinagar ~13.4 °C and ~700 mm a year).
- **Checks (full planet):** `plant_presence_check` 0 fails on 7731, 467606063 and 1378252316 (every group PASS on each); `BIOME=SAVANNA` 0 fails (Amorphophallus 20 species, acacia, bamboo, vines; Musa, Cannabis, Trichocereus have no savanna habitat: SKIP); `BIOME=STEPPE PLANT_GROUPS=trichocereus,cannabis` has no fitting steppe on 7731 or 1378252316 (SKIP) and passes on 467606063 (T. bridgesii, macrogonus, peruvianus; Cannabis "Mazar-i-Sharif"); `BIOME=TEMPERATE_DECIDUOUS` 0 fails (Cannabis, bamboo, vines). New `tools/vine_check.gd` (7731) 0 fails: temperate forest — ivy on 19 % of trunks (2,151 of 11,366) and 25 % of dead wood, 2,062 ground and 3 cliff patches, a castle 2.6 km off with ivy on 36 of its 84 strands and 5 of 36 boulders, cut back 36 → 16 → 0 by a restoring camp; rainforest — liana, pothos and philodendron on 35 % of trunks, 4,543 ground patches, a treehouse with liana on 13 of 16 strands and 9 of 20 boulders (13 → 9 → 0). The §CA walkabout (QUICK, full planet, seeds 101 202 303 404): 0 species standing in a biome that does not list them, 0 fails. Seed 303's opening camp and its first road site stand on a dry-forest/savanna boundary: the walkabout judged every plant within 30 m by *your* cell's biome and flagged 3 + 3 species from the other side; it now judges each plant by its own cell, as the placer does, and notes them as "across the boundary, in its own biome" (`tools/walkabout.gd`). `plant_schema_check --strict` 1,187 entries 0 errors; `biome_species_check` 998 species allowed; `plant_trim check-keep` PASS; `tree_check`, `cover_check`, `litter_check` 0 fails; headless boot clean. `fruit_check` fails 2 ("all of them up in the tree" — flower sites to 38.5 m on a 23.3 m tree; "lies rotting under the tree" — 0 on the ground) the same way at 56e221e, before today's work: not this pass.
- **Also fixed:** AroidGarden stepped a plant whose chunk had unloaded mid-pass ("previously freed instance", 1,541 lines a run); it now drops the rest of that pass. Vine patch MultiMeshes are filled through their raw buffer (LookTarget and the banding read it back).

## 2026-10-01 — The twenty favourites: reference batch 4 measured, the look reference doc, `measure_look.py --fav` (design chat; Mike: "push what you can… so we can truly hone in on the aesthetic"; design §CF)
- **Batch 4** (`docs/references/batch4/`): Mike's 20 favourite frames cropped to the video. With them: a contact sheet with each frame's five dominant colours; the findings card (3× zooms showing clean edges against the sky and big texels on surfaces, plus the measured colours); and `measurements.json` (every frame through `measure_look.py`'s own formulas plus the blue / green / warm shares; day 8, night 10, character 2).
- **`docs/design/LOOK_REFERENCE.md`**: the eye test for Mike's next play, ten rules with the frames and numbers behind them, the composition rules for the landmark and road pass, the favourites against `retro.targets`, what's built and what's open, and five open calls.
- **`measure_look.py --fav`**: also prints where a frame sits among the favourites of its band, and the nearest favourite to open side by side. Without the flag the output is unchanged. Checked: a favourite's own crop names itself as nearest (#9 at night, #2 by day), and batch3 #2 reads as before without the flag.
- **Not changed:** `retro.targets`, every other `look.json` value, every shader. The favourites read darker by day than the day band (median luma 0.21 against 0.26–0.36) and up to 0.87 saturated at night; both are open calls in §CF. **The grey leaves** (step 0 of the look pass prompt) aren't in the look pass's log. Check them on the Mac before judging any colour.

## 2026-10-01 — Look pass for the ambient open world: hue-safe navy grade, cobalt sky, electric water, hard 16-texel tiles (Mike's on-screen targets; `look.json`, tuning only — no second pipeline)
- **Colour and glow** (`post_grade.gdshader`, `SkySystem` environment, campfire): Linear tonemap (`grade.tonemap`, exposure 0.9); a saturated navy ambient (`day.ambient_color` #1838C8, `night.ambient_color` #0C1C8C). The grade pulls shadows to navy (`shadow_color` #06186C) and highlights to cyan-white (`highlight_color` #D8F8FF day / #C8F0FF night), lifts saturation (`day.saturation` 1.5), and leaves oranges and golds alone (`grade.protect_hue_deg` −20° to 62°, feathered). Glow takes only HDR above 1.0 (`retro.bloom`); the fire is the one warm accent: flame bands #FEFC54 core → #E6552A → #5A0A00, HDR 1.8 at the core, light #FF6E24 at 7 m.
- **Sky, distance and mist** (`SkySystem`, `sky.gdshader`, `look.gdshaderinc`): every colour was derived by running Mike's target through the grade backwards (a Python copy of `post_grade`), so the on-screen result lands on it. Day zenith #0509BF (target #0000C4), 3° horizon #2248EB (#2350F0), clouds #A4B0E5 (#A8B4E6), far mountains #5198ED (#4F98EF), deep night #040939 (#050938), full moon overhead #0E17BE (up to #0000C0), night mist #17369A (#153695). The file's stops look slightly violet (day) and teal (night fog) because the grade pulls dark blues to navy. Low mist now hugs the ground by height above the planet surface (`mist.*`, new globals `look_fog_start_m`, `look_mist_density`, `look_mist_scale_m`).
- **Water** (`water.gdshader`, `waterfall.gdshader`, new `waterfall_mist.gdshader`, `WaterLook`): a self-lit electric-blue body (`water.base`, `self_lit`, `glow`), calm ponds navy (`water.calm`), cyan glints from two scrolling noise layers that bloom (`glint` #85FCFF × `glint_hdr` 1.5). Falls carry scrolling streaks and three mist cards at the plunge (`waterfall.mist`). Rain and rising water now reach the per-biome water materials too (they only reached the default one).
- **Textures and contact shade** (`make_retro_tiles.py`, `terrain.gdshader`, `RuinBuilder._contact`, `TerrainChunk._bake_tree_feet`): grass, dirt, sand, stone, bark and leaves redrawn at 16 texels a metre (was 32–64) with hard darks (0.19) and lit flecks (0.81), 6–8 grey levels a tile; nearest with 2 mips, no normal maps, every world shader `specular_disabled`. Dark rings at tree feet from a per-chunk feet map; ruins darken where they meet the ground, under every block, inside towers and at doorway jambs (`cavity.*`). Ruin geometry and rolls unchanged.
- **Render size:** `render.preset` stays "default" (480 lines).
- **Checks:** every script parses; every shader in `shaders/` drawn for 30 frames under Forward+ (lavapipe) with no shader error; headless boot clean. Visuals built — needs a frame from Mike's Mac.
- **Left for later (audit):** spring pools (`road_props.gd`, `camp_props.gd`) are glossy (roughness 0.1); a few small materials keep Godot's default specular 0.5 (`_hang_vines`, lantern, torch, corpse, world items, fishing line, ruin marks, coals); `far_terrain.gdshader` samples stone without `retro_tex`; `retro.filter` / `retro.anisotropy` are not read by any code.

## 2026-10-01 — Mac play fix 3: trees drawn by their own distance, 157 M triangles down to 15–23 M; no road region on the main thread (Mike's 15:30 play; `look.json` `ranges`)
- **Leaf cards by distance, per tree** (`TerrainChunk.setup_bands` / `band_trees`, `ChunkManager._band_some`): every branchy tree is drawn by its own distance from you, not its chunk's ring. Within `ranges.tree_full_m` (120 m) its full leaf cards (the hero mesh, as before); of those, only the ones within `tree_shadow_m` (35 m, the hard shadow map's reach) cast the sun's shadow; out to `tree_light_m` (350 m) the new light tree (`PlantMeshes.LOD_LIGHT`: the trunk, at most 8 main limbs, 16 big leaf clusters; 187–464 triangles, mean 257 over all 840 layouts, against ~17,000 for the full tree); beyond, the one-quad picture. Each layout's trees are split into three copies (shadow, full, light), the species' picture keeps only the far ones, and a chunk re-sorts after you move `tree_reband_m` (15 m), nearest chunks first within 2 ms a frame. Young trees (saplings and seedlings, leaf cards too) draw only the plants within their reach, not the whole chunk's. Tree shaking (`tree_instance`) follows a tree into whichever copy draws it.
- **Triangles loaded round a site** (`tools/scene_load_check.gd`, now asserting at most 25 M and printing the split by drawing):

  | Seed | Biome | Before | After |
  |---|---|---|---|
  | 7731 | jungle | 161.7 M | 15.3 M |
  | 7731 | temperate deciduous | 19.3 M | 2.2 M |
  | 7731 | savanna | 63.9 M | 9.6 M |
  | 467606063 | jungle | — | 16.8 M |
  | 467606063 | temperate deciduous | — | 18.9 M |
  | 467606063 | savanna | — | 10.2 M |

  (Before on 7731: Mike's entry, and a run of the previous commit for the jungle. After: the jungle is ~6 M full trees, ~3 M light trees, ~6 M other plants.) `leaf_lod_check`: every branchy tree within 120 m is on its full mesh, only those within 35 m cast, the light trees between — 0 fails. "Parameter m is null" lines in the headless checks come from the check counting meshes the dummy renderer never made; the previous commit prints them too, and the game's own boot prints none.
- **Road regions off the main thread** (`RoadNetwork.ensure` / `links_near`): a worker still builds what it needs and waits for a region another thread is building; the main thread (travellers, road props, rooms, main) never builds or waits — it queues the missing regions on a worker and uses what is built. The checks ask with `block` to get the whole network.
- **Checks that never write a save never restore a kept camp** (`main._opening_site`): a pinned check run picks its camp fresh, so a check gives the same answer whatever worlds the machine has played (seed 1378252316 had an old save here and rolled no kind).

## 2026-10-01 — Mac play fixes 1–2: the pixel font always, and a world keeps its camp (Mike's 15:30 play; `hud.json` `text`, `WorldSave`)
- **The font** (`HudText.install`): VT323 through its import when the imported data is on disk; else the TTF read straight from the file (`FontFile.load_dynamic_font`), with the same no-antialiasing, no-hinting settings; else the other face in `assets/fonts` (typewriter) with one `push_error` naming why. Never a system font. `HudText.loaded_from` says which ("import" here; "disk" with the import data hidden — tested, same VT323, the same 144 px for "Wind 3 m/s from NW" at 20 px, and no engine load errors since the import is checked before it is loaded).
- **The HUD never runs off the frame** (`Hud.fit_lines`): a column line too wide for its half of the frame wraps onto the next line at a " · " break, else at a space; never inside a word, never an ellipsis (the old fit dropped parts and cut letters: "Wind 3 m/s from…"). `hud_pin_check` asserts every part's every line fits, every word of the readout is shown and nothing is off the frame at each preset: chunky 640, default 854, half_hd 960, fine 1280 — all PASS, and the face is VT323.
- **A world keeps its camp** (`main._opening_site`, `World.restore_spawn_site`): a new world saves its opening camp's fire site and kind (`opening_site`, `first_camp_kind`); every later boot rebuilds the camp exactly there and routes its opening road from it. `pick_spawn_site` is for a brand-new world only (and the dev frame). **Migration:** a save with no `opening_site` whose hearth is no ruin camp's fire (no inhabited ruin within 250 m) takes that hearth as the opening camp, keeps it, and routes the opening road to it (to a people's camp at the hint's distance, else the nearest one a road reaches within 15 km). **Never wake at no fire:** on death in ambient, a hearth that is neither the opening camp nor any camp's fire (`Camps.fire_at`: a ruin camp's fire, a wild or cliff camp, a wandering group) wakes you at the opening camp, makes it the hearth again, and logs "Your hearth was gone; you woke at the camp."
- **And a real road bug it turned up:** `RoadNetwork.REGION_M` and `MARGIN_M` were static values set when the class first loaded; loaded before `PlanetConst` was set up (the new-world check's boot order) they were 0 and no road was ever built. They are set when a network is made now.
- **Checks:** `new_world_check` (`DEV_PIN=0`): 16 PASS, 0 fails — besides the old ones, with the first-camp weights changed Continue rebuilds the camp 0.0 m from where it was; a pre-`d690997` save (hearth 2.6 km off, no `opening_site`) rebuilds its camp at the hearth with its opening road routed (node 18 m from the fire, a people's camp 7.2 km off); a hearth with no fire wakes you 3 m from the camp with the log line. `hud_pin_check` 0 fails.

## 2026-10-01 — No camp left without a road: the shallows are fordable (Mike: "fix the reason some camps don't have roads"; design §BC, `roads.json`)
- **Why the last camps had no road:** each unreached camp's log line now names why its six candidate routes failed (`RoadNetwork._why`: "off the grid", "start in water", "search cap", "walled in (N cells)"). Within 25 km of four spawns the only cause left was "walled in" after 9 and 19 lattice cells: two camps on seed 90210 stand on a spit or islet ringed by sea, the water a few tenths of a metre deep.
- **The fix** (`_Lattice.cell`, `_route`, `_decay`): standing water shallower than `WADE_M` (1 m, sea or lake, from the drawn ground) can be waded at `WADE_COST` (6×) the cost, and the road marks it as a ford (stepping stones, `RoadProps._crossing`). Deeper water still bars the way, so a true island stays logged. Lakes now also judge their water on the drawn ground near the surface.
- **Checks, full planet:** `road_reach_check` 0 fails on 467606063, 1378252316, 7731 and 90210; every people's camp within 15 km is on a road (20/20, 17/17, 18/18, 17/17), and with `REACH_KM=25` seed 90210 has 39 of 39 camps and 74 of 74 ruins on a road. No "has no road" line on any seed. `road_check` (stamp) 0 fails: its traveller test now follows the traveller it puts on the road (a second one, walking of its own accord on the denser network, made "exactly one" fail).
- **Invented:** `WADE_M` 1 m, `WADE_COST` 6, a shallows ford counted 6 m wide. `REACH_KM` for the reach check.

## 2026-10-01 — Mike's 15:30 play (after the roads pass): Courier font cut off, no camp after a respawn, a laggy jungle — causes found (design chat; `tools/scene_load_check.gd`)
- **The font:** `HudText.install` loads `assets/fonts/vt323.ttf` only through the importer (`ResourceLoader.exists` + `load`); when that fails it silently falls back to a SystemFont "Courier New", which is what Mike's frame shows (wider, so the 30 px sizes run off the frame and the HUD ellipsises "Wind 3 m/s from…"). The font files are tracked and unchanged since 30 Sept; the import came up empty on his Mac.
- **No camp after a respawn:** the opening camp is never saved — `main` rebuilds it every boot at `world.pick_spawn_site()` — but the hearth is saved as a position (`Hearth.setup`). The roads pass changed what a seed picks, so a world made before it rebuilds its camp elsewhere while the saved hearth still points at the old site; dying wakes you there, at no fire. Every pre-`d690997` world does this.
- **The lag is plant triangles:** loaded around a site on seed 7731 (instances × mesh triangles, before culling): **jungle 157.4 M** (110,720 plants; banyan, teak, trumpet tree and sal 37,000 trees at 2,900–5,600 triangles each = 151 M), temperate deciduous 19.3 M, savanna 63.9 M. Every tree in the 2-chunk detail ring (~1.3 km across) draws its full leaf cards; the salad biomes stack ~115 canopy trees a hectare. Road regions build in 0.1–0.7 s each (seed 7731, this container), on the asking thread — a hitch when the main thread asks first, not the steady lag.
- **The roads pass checked:** `road_reach_check` seed 7731 all PASS (first camp kind rolled, camp 1 m from the road, 28/28 ruins and 18/18 camps linked within 15 km).

## 2026-10-01 — Roads reach the camps: the first camp rolls on the full planet, the opening camp is on the road, every people's camp is linked, and the tread reads in the forest (design §BC, §BX, §BY and the §CB first-camp fix; `roads.json`, `camps.json` `first_camp`; `tools/road_reach_check.gd`)
- **The first camp's kind rolls on the full planet** (`Encampment.water_m`, `fire_site`, `World.pick_spawn_site`): the water rule is judged from the cell's nearest point (centre distance less half the cell's diagonal, ~7.4 km on the full planet), and the fire is then placed for real: `fire_site` walks the kind's water (river polylines every 250 m, or the sea or lake shore found by marching out on 24 bearings), and picks a level, dry spot inside one of the kind's biomes within `within_m` of it, never in the water and at least the river's half width + 20 m off it. In play a kind with no site is dropped and another kind is rolled; the old single list is used only if every kind fails (with an error). The dev frame (`spawn_choice` ≥ 0) still uses the old list.
- **The opening camp is on the road** (§BX, `opening_road`): the first camp is chosen among its kind's candidates so an inhabited ruin lies about `length_km_hint` along a road (straight-line target = hint / 1.08, the routed winding measured on four seeds), and the road is checked to route (`RoadNetwork.can_route`) before it is picked. The camp is a road node (`RoadNetwork.opening`, key "opening") 18 m from the fire, and its link to that people's camp is forced whatever the pruning says (then the next alternatives); the link carries `opening`. You wake facing 60 m along that road (`main.gd` `_opening_road_ahead`), else as before, toward the fire.
- **The network's nodes as §BC names them** (`_find_nodes`): "camp" is the people's camps (inhabited ruins and the opening camp); other ruins are "ruin". The mythic territories are no longer road nodes. New: springs (where a river rises), fords (a river point whose banks rise less than 20 m within half its width + 120 m), passes (a saddle on the detailed terrain within 1.5 km of a 4 km hash point). Hot springs and standing stones kept. `min_spacing_km` never drops a camp or a ruin; other nodes keep it from each other and a third of it from camps and ruins.
- **Every people's camp gets a road**: a camp or ruin with no link after the pruning tries its next nearest nodes within `link_max_km`, up to six; a camp still unlinked is logged ("a people's camp … has no road", `RoadNetwork.unreached`).
- **Three routing bugs, found on seed 90210:** (1) the A* lattices were cached by the cube their region's centre fell in once pushed onto the sphere, which can be the neighbour's cube, so whichever region built first lent its lattice to the next and every route there was "no way"; they are keyed by centre and reach now. (2) Ground within 0.5 m above the sea counted as sea, and the coastal flats' ruins (0.2–0.5 m up, or −0.2 to −0.5 m on the smooth height while the drawn ground is dry) could not be left; the sea is now ground under the water on the drawn (detailed) height near sea level, and the strand costs 1.5×. (3) A region another thread was still building read as built (empty); `ensure` now waits for it, so a chunk never keeps a road-less tread.
- **The tread reads, overgrown but never illegible** (§BC, §BY; `TerrainChunk._tread`, `terrain.gdshader` `road_tread`): the tread is its own vertex attribute (CUSTOM0: signed distance to the centreline, half-width, `trail.wear`, overgrown), not the colour. The signed distance is linear across the road, so the fine and coarse meshes find the centreline between vertices 4–8 m apart. In the shader a worn core down the middle switches the grass tile to the dirt tile and the colour to the path; grass takes it back in noisy patches about a metre across, more toward the edges and across it as `trail.overgrown` rises; the near grass flecks are off on the bare tread; rock and snow stay themselves. Footsteps still read the path (`ground_color_at` adds the tread). The colour lerp toward `PATH` is gone.
- **Lost and found** (§BY, `lost_and_found`; `RoadNetwork._lost_and_found`): each link alternates clear stretches (`clear_len_m`, scaled so the vanished length comes to `vanish_share`) and vanished ones (`vanish_len_m`) where overgrown rises to `overgrown_in_vanish` over 10 m and the tread fades to grass; the first and last 80 m of a link stay clear so a trail always leaves a node plainly. Where the trail resumes a tell stands within `tell_within_m` (one of `pickup_tells`, never fallen). Waymarks gained their looks for `stone_step` (two flat steps), `abutment` (a dressed block) and `notched_tree` (a dead stem with a pale blaze); before they drew as posts.
- **Checks, full planet (no STAMP):** `tools/road_reach_check.gd` now also measures the tread (bare share at a clear stretch's centre, its edge, in a vanished stretch, 30 m off) and the lost-and-found share and tells. 0 fails on all four seeds:

  | Seed | First camp | Spawn to road | Opening road | People's camps on a road | Ruins on a road |
  |---|---|---|---|---|---|
  | 467606063 | cold_shore (taiga) | 21 m | 5.3 km | 20 of 20 | 35 of 35 |
  | 1378252316 | river_valley (temperate deciduous) | 17 m | 7.0 km | 17 of 17 | 38 of 38 |
  | 7731 | tropical_forest (tropical rainforest) | 2 m | 7.2 km | 18 of 18 | 28 of 28 |
  | 90210 | scrub (Mediterranean scrub) | 15 m | 6.6 km | 17 of 17 | 30 of 31 |

  Tread on every seed: 0.64–0.67 at a clear stretch's centre, 0.20–0.21 at its edge, 0.07 in a vanished stretch; 28–29 % of road vanished, every stretch with its tell. Before (seed 467606063): 6 fails, the old list, the nearest road 1,650 m off, 20 of 28 camps on a road. `road_check` (STAMP=1) 0 fails; `new_world_check` 0 fails with `DEV_PIN=0` and `DEV_PIN=1`. A headless boot of the play path (seed 42: a forest camp, the player 17 m from the road after 600 frames) prints no error or warning; a rendered boot under xvfb compiles the ground shader with no shader error. The signal 11 on quit and the one `Playback can only happen…` line in `road_check` are older than this pass.
- **The look is built — needs a frame from Mike's Mac:** the target is the trail visible at least 30 m ahead from the eye in a forest by day.
- **Invented, for Mike:** `ROAD_WINDING` 1.08 (measured), the fire 18 m from its road node, `fire_site`'s rings and its level test, the ford and pass thresholds (20 m banks; saddle relief 5 m on an 800 m grid), the strand's 0.5 m and 1.5× cost, the 80 m clear at a link's ends, the reclaim noise (patches ~1 m and tufts), the three new waymark looks. **Flags:** no pass and no hot spring turned up within 15 km of these four spawns (the saddle finder found 19 in 1,008 land samples planet-wide; 1/10 relief is gentle). With `vanish_share` 0.3 and these lengths the trail vanishes every 150–250 m, so the 7 km opening road loses it about 35 times, not "twice" as `detour_allowance_min` imagines; say if the opening road should be spared or the share lowered. On seed 90210 two camps beyond 15 km have no road (logged); the other three seeds log none.

## 2026-10-01 — The named plants checked in the running game (design chat; §CE, `tools/plant_presence_check.gd`)
- **Before** (seed 7731, full planet, 3 sites per group, chunks loaded as in play): Musa PASS (wild banana, Indian, in tropical rainforest), Amorphophallus PASS (114 plants of 8 African species at one rainforest site, 0 at a savanna and a second rainforest site), bamboo PASS (4 species), vines PASS (ivy only); **cannabis FAIL (0 at 3 sites), Trichocereus FAIL (0 at 3 puna sites), Acacia FAIL (0 at 3 hot-desert sites)**.
- **Causes and data fixes (pushed):** the umbrella thorn, the savanna's "Acacia" and mulga used the `sand` soil preset — a hard gate to sand and sandstone — so on alluvium and granite they could not spawn: now the soils they grow on (object form). Trichocereus (realm `andes`) could grow only in a biome hosting `andes`, and no dry biome did: an inter-Andean dry-valley association (`andes`) added to steppe and Mediterranean scrub, and those biomes added to all 18 entries' `biomes`.
- **After** (same seed, savanna sites): acacias 22,000–35,000 per site (Acacia, whistling thorn, umbrella thorn); savanna bamboo and the climbing fire lily present. Trichocereus now finds `andes` steppe sites but grows **0** there; cannabis 0 in savanna and steppe; Amorphophallus 0 in savanna. Cause: the stand rule (§BH) — one dominant, 1–3 associates, a 3 % accent pool for the rest — and the 64 cannabis landraces rolling as 64 species. The engine fix is §CE's `always_present` (associates when they fit, a minimum share, one roll per binomial).
- **The §CC trim (`a9f00ff`) landed before §CE and cut 21 of the named groups** (4 acacias, 7 bamboos, 10 vines; Musa, Amorphophallus, cannabis and Trichocereus intact). Restored from `7bb5f97` into the biome files that listed them (30 placements, `restored_note` on each); `make_plant_tiles.py` rebuilt the atlas (998 species, 4,051 tiles; 3 duplicate tiles merged, every reference on disk); `plant_schema_check --strict` 1,187 entries, 0 errors; `biome_species_check` 998 species allowed somewhere.
- Data errors left for the research pass: *Amorphophallus incurvatus* (band 23–28 °C, only biome cloud forest 6–21 °C) and Cannabis "Kashmir" (moisture 0.2–0.45, both biomes wetter than 0.48).

## 2026-10-01 — The catalogue trimmed to archetypes, Mike's seed list first (design §CC; `data/habitat.json` `trim`)
- **What each biome holds now** (`docs/plant_archive/TRIM_RESULT_2026-10-01.md`, `tools/plant_trim.py result`): at most four species per category (tree, shrub, grass, moss, orchid, aroid, fern, cacti, fungi) per biome, chosen from Mike's seed list first (`TRIM_SEED_LIST_2026-10-01.md`: a real accepted binomial, native to the kind of place, drawable at 480p), then the biome file's dominants and companions. Coordinator's ruling, for Mike to confirm: `hero_species` survive on top of the four, so a hero cannot push out a seed pick (temperate deciduous forest keeps its ginkgo, dawn redwood, tulip tree and Yulan magnolia and has white oak, American beech, shagbark hickory and sugar maple again). Never kept: yeasts, molds, rusts, smuts, slime molds, bacteria, algae, diatoms, plankton, chytrids, endophytes, flat crust lichens, millimetre fungi (`never_drawable`).
- **Numbers** (biome files, the three whole catalogues aside): 579 binomials before, 643 now — 356 kept, 281 new to the project (each a full PLANT_SCHEMA entry written from a flora: leaf, bark, canopy, tint, photoperiod, soil, growth, repro, genes, appearance, architecture for the woody ones; estimated values marked), 6 restored from the old `*.full.json` catalogues and completed (Swiss stone pine, whitebark, jack and slash pine, walking palm, huisache), 330 archived. With cannabis (64), trichocereus (18) and amorphophallus (246) untouched: 1,157 entries, 977 species. Every other `data/plants` catalogue moved whole to `docs/plant_archive/` (`git mv`); each biome's dropped entries and any association left without a member are in `docs/plant_archive/biomes/<file>`.
- **How:** thirteen agents, one per biome group, in three passes (the trim; Mike's seed list as he first sent it; and after his 12:30 change, the seed list first and added where missing). The first pass's agents stopped mid-way on a usage limit and were restarted from what they had written. `tools/plant_trim.py`: the nine-way categoriser (now also: fungi by their `fungus` block or the fungi catalogue's genera, club mosses as moss, forbs drawn with a grass shape as none), `survivors` (heroes on top of the four), `sync-tags` (each entry's `biomes` = the files that list it), `result`. Names made one-to-one where two species shared one (hard fern → deer fern / hammock fern; stalked puffball → stalked desert puffball / desert shaggy mane) and where agents had padded a fungus's name for the old categoriser. Bands: where a copied entry's band missed its new biome by a hair, that file's copy was widened just to overlap (e.g. saltgrass in the salt marsh, Fremont cottonwood in the cold desert, four thorn-scrub and badlands entries the species check caught).
- **Code that followed the data:** litter fungi now fruit from any species with a `fungus.substrate` "litter" block (they read the fungi catalogue file before); a biome-file entry's `realm` holds as a catalogue's did. The checks that named trimmed species (tree, climb, cover, litter, fruit) point at survivors of the same kind (white oak, American beech, black spruce, African baobab, downy birch, shagbark hickory); `fruit_check` expects over 300 fruiting species (381 now).
- **Checks:** `plant_schema_check --strict` 1,157 entries, 0 errors; `biome_species_check` 0 hard; `plant_trim.py survivors` none over four; the species atlas rebuilt from the survivors (`make_plant_tiles.py`: 977 species, 3,963 tiles, stale ones gone); `tools/species_mesh_check.gd` (new) builds every species at the near and far level: 977, 0 fails, every leafed species finds its tiles. The trees, fruit, cover and litter checks pass on the trimmed data: the tree check's oak is the white oak, its straddle count averaged over the open-grown layouts; a date palm's suckers now share one tree's leaflet budget (`TreeArch._palm`); the fruit check walks from the dev camp to its nearest trees when none stands within 60 m (the trim took the silk floss tree that used to). `realm_check` had gone stale (young plants keyed by stage, 12-float plant rows) and is fixed; its run on the trimmed data is reported with the roads pass.
- **For Mike:** seed list first cost regions his list does not name — the taiga's Norway spruce, Scots pine and Siberian larch; the krummholz's birch, larch and mountain pine; the Chilean temperate rainforest; Bornean dipterocarps; the Indian, Bolivian and Madagascan dry forest; Australian and Mediterranean shore plants; the Namib quiver tree. They are archived whole with their stands; a hero flag brings any back. Stand names that no longer match their dominants are left as they were (renaming is his). Glacier, ice sheet and deep ocean are almost or wholly empty: everything on his lists there is microscopic. Map lichen went out as a flat crust (ice sheet, alpine tundra, krummholz); it stayed where it was an earlier survivor (glacier, sea ice, volcanic field).
## 2026-10-01 — Roads verified on the full planet: they generate, but the spawn is off them, some camps are unreached, and in forests the tread does not show (design chat, Mike asked; `tools/road_reach_check.gd`)
- **Run on three full-planet seeds** (no STAMP; 467606063, 1378252316, 7731), the real game booted headless with the play rules. The network builds: 126–224 links and 500–870 km of road within 15 km of the spawn, waymarks along them, tread 0.40 at a road's centre.
- **FAIL — the opening camp is not on the network:** the nearest road is 460 m – 2.2 km from where you wake; the opening camp is never a road node (`RoadNetwork._find_nodes` gathers ruins, `Territories` — the mythic folk's — hot springs and standing stones; the `spring`, `ford` and `pass` kinds in `roads.json` are silently skipped). §BX's "spawn beside the road" is data only.
- **FAIL — 4–10 of ~27 inhabited ruins (people's camps) within 15 km have no road within 400 m**; 6–19 ruins in all. Roads mostly link the mythic territories (35–54 within 15 km).
- **FAIL — the first camp's kind never rolls on the full planet** ("no first-camp kind has candidates … the old list" on every seed): `Encampment.candidates_by_kind` measures the water rule (300–1,500 m) from map-cell centres kilometres apart, so no cell passes; it worked only on the 40 km stamp (200 m cells). Seed 1378252316 woke in a hot desert, which `first_camp.never` forbids.
- **The tread is invisible in forests:** `TerrainChunk._vertex_colors` tints the vertex colour 40 % toward `PATH`, but `terrain.gdshader` picks the grass tile vs the dirt tile by greenness; computed per biome, the road's centre stays 100 % grass tile in taiga, temperate deciduous and rainforest, cloud forest, jungle, tropical rainforest, floodplain, maritime forest, mangrove, alpine meadow and the wet biomes (it flips to dirt only in open country). Plants are cleared off the road correctly (ground cover to half-width + 1 m).

## 2026-10-01 — Every new world is a new world, and the first camp's kind rolls (design §CB; `dev.json`, `camps.json` `first_camp`)
- **The pins are the tools'** (`World.pin`, `pins_apply`): `dev.json` `seed` / `spawn_choice` hold in play only with `pin_in_play` true or `DEV_PIN=1` (`DEV_PIN=0` forces play's rule, for the check). `tools/dev_view.gd` and the 32 checks pin themselves (`world.pin(42, 0)`, dev_view from `SEED` / `SPAWN`), and a `--script` run that forgot to pin is still pinned and never writes a save or the pointer (`WorldSave.read_only`).
- **A new world rolls a seed** (`World.startup_seed`, `WorldSave.last_seed` / `set_last` / `exists`): the last world played is `user://worlds/last.json` = {"seed": N}; booting continues it when its save exists, else a fresh positive seed is rolled, written as the pointer, and its first camp is rolled from the seed (`pick_spawn_dir`: the same camp every boot of that world). Old worlds stay by seed; nothing is deleted. The seed is the world's name: the log's first line reads "World 7731 — day 1 — a forest camp" (`main.gd`, after `GameLog.load_saved`), the F3 status shows "World 7731", and a fresh world's clock starts at `World.START_DAYS` again (`generate` resets `days`).
- **New world** (`SettingsPanel` "World > New world", the dev key **F12**): one confirmation line ("Start a new world? This one stays saved." / "Press F12 again"), then `Main.start_new_world`: the save flushes, the next boot of the scene rolls a fresh seed, and the main scene reloads. `World.reset_world_state` clears what the last world held in static tables (fire stores, clearings, torch bundles, soil marks, coppice stools, the hearth, the log) before the new one builds, so the camp, hearth, log and camp sim all come from the new seed's save.
- **The first camp's kind** (`Encampment.candidates_by_kind`, `World.pick_spawn_dir`, `camps.json` `first_camp`): one candidate list per kind (a cell qualifies when its biome is in the kind's `biomes`, it lies within `within_m` of the kind's water — river by the river network's segments, sea by the coast distance, lake by the nearest lake cell, water any — and passes the common gates: fuel in `fuel.json`, `temp_c`, `slope_max`, `elevation_m`, no water on the cell, not in `never`), scored as before minus the latitude term, the best `candidates_per_kind` kept `min_separation_m` apart. With `roll_kind` the world rolls a kind by weight among the kinds with candidates (seeded from the world seed; `FIRST_CAMP=<kind>` forces one), then a random cell of it; `spawn_choice` ≥ 0 keeps the old list and that index (the dev frame). `site_near` keeps the fire in the rolled cell's biome. The camp's people, fuel kind and store pieces follow the site as before (`Peoples.pick`, `FireStore`, `CampSim`). The river network is built once per planet (`Encampment.rivers_for`; the chunk manager shares it).
- **Checks:** `tools/new_world_check.gd` (`DEV_PIN=0`: a fresh seed, the pointer, the save, New world → another seed and camp cell, the old save kept, Continue lands back; `DEV_PIN=1`: dev.json's pins): 0 fails both ways. Fresh worlds 467606063 (a coast camp on a beach) and, after New world, 1378252316 (a river valley camp in temperate deciduous forest); Continue lands back at the same cell. `tools/first_camp_check.gd` (seeds 7, 8, 9 twice each, and `KINDS=forest,savanna,cold_shore` forced): 0 fails. Seed 7 rolls a scrub camp in Mediterranean scrub (its first run put the camp on a dune next door: `site_near` now stays in the home biome), seed 8 a river valley camp in temperate deciduous forest with the river people, seed 9 a forest camp in temperate rainforest with the canopy folk; each seed rolls the same camp twice. The forced kinds land in temperate deciduous (forest), tropical dry forest (savanna) and taiga (cold shore). `highland` found no candidate on the dev stamp.
- **Invented:** the dev key F12 (`controls.gd` `dev_new_world`); nothing in the data. Note: `dev.json` ships `spawn_choice -1`, so `DEV_PIN=1` in play is seed 42 with a rolled kind camp; the dev frame's spawn 0 comes from the tools' own pin.

## 2026-10-01 — The fire (Mike, from chat; design §BZ, `look.json` `fire`, `audio.json` `fire` and `kinds.fire`)
- **The flame** (`shaders/flame.gdshader`, `Campfire.flame_node`): one camera-facing card per fire, turning only about its own up axis, `flame.width_m` × `height_m`; the four overlapping tongues are gone (no crossed cards anywhere). The grey noise scrolls up through the teardrop mask (the lick and the breathing kept) in whole texel rows, the heat is posterised to the four `bands` (a small pale heart, gold, orange, a thin dark edge; thresholds 0.72 / 0.45 / 0.2), and everything is read from the UV snapped to the `texels` grid (32×48) with a hard alpha cut, so the card is flat squares at any distance and the 480p frame does the rest; nearer it is simply bigger. Unshaded, blend_mix with depth: it reads bright over the coals by day and by night. **Embers** (`shaders/ember.gdshader`): `embers.count` single-pixel billboards (`px` internal pixels at any depth) rising from the coals at `rise_mps`, each on its own `life_s`, drifting, blinking once, off at the end; a MultiMesh the vertex shader animates from TIME and per-ember seeds, nothing on the CPU. **Low fire:** the bands blend toward `low.bands_low` and the card's height toward `low.height_scale` as the burn drops; FireStore draws a fire at burn 1 / 0.55 (low) / 0.12 (embers) / 0, so the collapse ramps from 1 and is complete at `below_share` (a low fire is 60 % collapsed, a red ragged flicker across the clearing; noted in `look.json` `flame.low._help`). At embers no card, coals and a few embers only; out, nothing. **The torch** (`Torch.flame_node`): the same card at `torch.scale` of the campfire's (the planted torch; the held one 0.2 and the fat lamp 0.12, their old sizes), its scroll slowed by `torch.scroll_scale`, `torch.embers` embers. The player's fires, the opening camp, the camps and the mythic folk's fires all go through `Campfire.build`, so they have the new card.
- **The light** (`Campfire.flicker`): energy = 7 × lerp(`light.day_share`, `light.night_energy_scale`, night) × flicker × burn, range = 14 m × lerp(1, `light.night_range_scale`, night), colour `light.color`; the flicker is two layers of value noise at `flicker.hz` by `flicker.amount` (no sines), and the light's position jitters by `flicker.position_jitter_m` from three more noise lanes so the lit edges move on the trunks. The ground glow and warm discs scale by `light.ground_glow_night_scale` at night. The safe/dread radius is untouched. *Note:* the fire's OmniLight has no shadow map (as the torch, §AG), so what dances is the light's falloff on the trunks, not cast shadows; a shadow map on the fire is a toggle away if Mike wants the real thing and will pay for it.
- **The sound** (`SoundSynth`, `Campfire._voice`): `fire_loop` is gone. `fire_hiss_loop` is a seamless 4 s bed, white noise through a one-pole low-pass at `hiss.cutoff_hz` with a slow breath and a faint rumble under it; `fire_snap` (20–45 ms, a noise burst and a ring at 1.5–4 kHz) and `fire_crackle` (80–220 ms, two to five small pops with a low thump) are one-shots in five variants each. Every fire has two 3D players of kind `fire`: the hiss on its loop at `hiss.volume_db`, and pops on a random clock (the next `pops.every_s[0..1]` seconds away, volume and pitch drawn from `pops.volume_db` / `pops.pitch`, a `snaps_share` of them snaps): never a cycle. As the fire burns low the pops come `low_fire.pops_every_scale` times less often and `volume_db_offset` quieter (ramping with the same collapse); at embers hiss only; out, silence. `kinds.fire` is Mike's 90 m with muffle [20, 90]: `Audio3D.muffle` lowers the cutoff and the panning between those distances every frame, so a camp is a dull, directionless hiss from the road before its glow shows. `Tuning` now knows `data/audio.json` (`Tuning.section("audio", ...)`).
- **Invented, flagged in the data:** `flame.embers.spread_m` 0.25 and `wobble_m` 0.08 (where the embers start and how far they drift; `embers._help`). The base light (7, 14 m) stays in code as before.
- **Also fixed:** the headless boot's `SHADER ERROR` in `pond_crawler.gdshader` (from the pixel-toggle pass: its triplanar function took the nearest stone tile and the linear grain through one sampler argument; the grain has its own function now).
- **Checks:** `audio_mix_check` 12/12; `fire_wall_check` the opening camp 4/4 (within 0.2–0.9 m of the fire from every side; the ruin half still cannot run headless here, the ruin build never completes under load, as before); `camp_check` 60/60. A headless boot of the project (`--quit-after 2000`) prints no new error or warning: the two lines it does print, one `Playback can only happen when a node is inside the scene tree` from a non-3D player and a signal 11 on the quit-after path, are there on the previous commit too and are not this pass (the check scripts quit cleanly through their own `quit()`); the pond crawler's shader error is gone.

## 2026-10-01 — The pixel style as toggles: pixel-size presets, near hard shadows, the dither confirmed (Mike, from chat; design §BU, `look.json` `render.presets`, `light.day_shadows_near`)
- **Pixel size** (`Display`, Settings > Display > Pixel size): the internal height is a named preset from `render.presets` (chunky 640×360, default 854×480, half_hd 960×540, fine 1280×720; `render.preset` is the file's choice, chunky as Mike set it), stored as `display.preset`; an older `display.lines` setting still counts until a preset is chosen. The whole frame (the 3D, fog, grade, water, dither, the rain streaks, the HUD) is the root window's viewport content at that height, upscaled nearest, integer multiples where the window holds two or more (`project.godot` stretch mode viewport / integer). F11 (`dev_pixel`) cycles the presets live with a note on screen. *Nothing bilinear:* every texture sampler is nearest now (the fur and weave, the far shell's stone, the pond crawler's tiles, the star pano, the ripple buffer, the post grade's screen read); the one thing left linear is the soft modulation grain (`look_grain`, `look_grain_soft`), which is not a texture but a light-and-dark field at 10–100 m scale, and sampled nearest it would paint 10 m blocks across the ground.
- **Shadows** (Settings > Display > Shadows: near hard cast, off: blobs only; `display.day_shadows`, default `light.day_shadows_near.enabled` true): on, the sun casts a hard shadow map within `max_m` (35 m) only, two splits, no blur, no soft filter (`soft_shadow_filter_quality` 0), the 480p frame edging it; off, §AG 6's blob-only day with the canopy darkening. The A/B applies live.
- **The dither, confirmed** (`post_grade.gdshader`): one 4×4 Bayer, `retro.dither` 1.0 (every pixel on the grid), `levels` 31 (5 bits per channel), on the full-screen grade that reads the whole internal frame after the 3D, so the sky and the water quantise with everything else; the floor and the grain come before it. The HUD draws above the grade and is not dithered (text).
- **Frame times at the dev spot** (`perf_bench.gd PRESETS=1`, this container's software rasteriser, so only the ratios mean anything): not measurable here. `perf_bench.gd PRESETS=1` runs (chunky 640×360: 14.5 s a frame on llvmpipe, nearly all of it the viewport being re-created at the new size and the first frames at it), so the preset ratios need a real GPU: in play, F11 cycles the presets and F2 shows the frame time, which is the comparison Mike asked for.

## 2026-10-01 — The look, measured: tiles, the floor, one-colour night, water, sky and rain, grass, night accents (Mike, from chat; design §AG, §BD, §BU, §Y)
- **The gate** (`tools/look/measure_look.py`, `look.json` `retro.targets`): the targets are two bands now, `day` and `night`, with Mike's numbers from the twelve reference frames (day luma 0.26–0.36, saturation 0.58–0.70, texel 0.014+, darkest 5 % 0.05–0.10 navy; night 0.15–0.25, 0.67–0.80, 0.011+, 0.015–0.035). The band is picked by `--day` / `--night` or the frame's `_HHh` name. Texel detail is the mean luma step between neighbouring pixels (both axes, 0–1) over the frame. A letterboxed capture is cropped to its frame first (the NaN came from an all-black 5 % band). The darkest-5 % line now prints its luma too.
- **Before / after at the dev spot** (`dev_view.gd`, `WAIT_DETAIL=1`, 14:00 and 02:00; luma / saturation / texel / darkest-5 % luma, blue:red):
  | frame | before | after (first) | after (tuned) | target |
  |---|---|---|---|---|
  | 14:00 | 0.29 / 0.71 / 0.047 / 0.070, 9.8 | 0.28 / 0.71 / 0.050 / 0.070, 9.8 | 0.29 / 0.68 / 0.053 / 0.070, 9.9 (all PASS; at chunky 640×360, the preset Mike set) | 0.26–0.36 / 0.58–0.70 / 0.014+ / 0.05–0.10, ≥2 |
  | 02:00 | 0.13 / 0.72 / 0.025 / 0.072, 7.2 | 0.12 / 0.92 / 0.030 / 0.014, 31 | 0.16 / 0.87 / 0.037 / 0.035, 42 (luma, texel, darkest and blue:red in band; saturation over the 0.80 line, see the note below) | 0.15–0.25 / 0.67–0.80 / 0.011+ / 0.015–0.035, ≥2 |

  The before frames already sat near the day band because the dev spot is open ground under a clear noon; the gap Mike measured was a dusk frame under a closed crown with the floor zeroed (step 2) and a greyed night (step 3). After the first pass the night went fully blue (darkest 0.014, blue:red 31, saturation 0.92, over the band) and the day stayed put, so the night floor came up a step (#04082A), the night sky gain to 2.2, night saturation 1.25 and day saturation 1.4 (from Mike's 1.5, which measured 0.71 against 0.58–0.70); the tuned column is the fifth re-render. **The night saturation is the palette, not the grade:** the third tune (night shadow tint 0.55 → 0.4, `night.saturation` 1.25 → 0.95) moved the number 0.90 → 0.89, which showed the preset's saturation knob was dead at night: the one-colour pull mixed every dark pixel toward the floor colour at the floor's own purity (0.9), after the saturation step. The pull now keeps each pixel's own saturation (hue collapses, chroma stays; the knob is live again), and the frame reads 0.87: every band of it, the darkest 16 % at 0.94 down to the lit 4 % at 0.67, sits where its colour's purity puts it, because the whole night palette is about 0.9 pure (`ambient_floor.night.floor_color` #04082A, which the floor rule pins the darks to; `SkySystem.NIGHT_ZENITH` #0A14A0 and `NIGHT_HORIZON` #1B2ED8, a third of the frame). The references' navies are about 0.73 pure (a #1A2A5A kind of navy, not a #0A14A0 one). Closing the last 0.07 means greying those three colours a step (toward #0A1030 / #182070 / #2A3AB0 kinds of values), which is §AG's night palette and Mike's call; the grade has nothing left to take it from without flattening the fire. Texel detail: the references read 0.015–0.024 under this metric and our internal frame 0.047–0.050 (the dither and nearest tiles, which is the point), so the band is a floor (0.014+); a window capture at 2× reads half, which is where Mike's 0.009 came from.
- **Step 1, the §AG tiles wired** (`look.gdshaderinc` `retro_tile`, `look_tile_contrast`): the 64 px tiles from `assets/textures/retro` (128 stone, 32 leaves) were already the textures (Look.texture) and already sampled nearest with two mips on terrain, bark, leaves, stone and the ruins; the water, the waterfall and the far shell's stone still sampled linear with anisotropy, and `retro.tile_contrast` went nowhere. All seven now go through `retro_tile`: nearest, at most `retro.max_mips`, no anisotropy, repeated every `retro.tile_m`, their light and dark pushed apart about the tile's mid grey by `tile_contrast` (a new global). The NOT WIRED tag is gone from `look.json`.
- **Step 2, the floor after the grade** (`SkySystem._update_floor`, `post_grade.gdshader`): the post grade's floor was already applied after the presets' contrast and before the dither, but it was scaled by the dapple stamp's sky visibility, so under a closed crown (the camp's she-oaks, a savanna acacia) it went to zero and the dither quantised the darks to pure black. The post floor is now the hour's floor colour wherever the player is not enclosed (the five-ray test; a ruin interior or a cave still goes black without a torch); the dapple stamp shapes only the world shaders' lift. The night floor colour is darker (`ambient_floor.night.floor_color` #03061F, luma 0.025) so the darkest 5 % at night lands near 0.02 instead of 0.08, with `floor_energy` raised to 0.3 so the world shaders' night lift stays where it was.
- **Step 3, night is one colour** (`post_grade.gdshader` `night_pull`): the mesopic desaturation is gone. At night every pixel below `pull_below_luma` is pulled toward the floor's blue at its own brightness, saturation kept (hue collapses, chroma does not); warm pixels (fire) keep their warmth. Day: `day.saturation` stays Mike's 1.5 (vivid where the sun hits, navy in shade); `night.saturation` 0.95 after the tunes (the knob is live again since the pull keeps each pixel's chroma; see the table's note).
- **Step 4, water the brightest thing** (`WaterLook`, `look.json` `water`, Mike's addendum): each chunk's water takes the family of the biome at its middle (clear, river, lake, swamp, sea, reef, desert, tropics; the sea always `sea`; anything unmapped `default_family`) with that family's base and highlight, one material per family. By day the base is multiplied by `water.glow` (1.35: brighter than the scene) and a nearest caustic tile scrolls over it at `caustic_tile_m` / `caustic_scroll_mps`; at night the emission is scaled by `water.night.glow` (1.6) so the water is the most saturated surface. The far sea takes the sea family's base. Waterfalls (`waterfall.gdshader`, `water.waterfall`): a flat sheet between `shadow` and `sheet` blue-white, the vertical streak tile (nearest, stretched four times taller than wide) scrolling down at `streak_scroll_mps`, a hard foam line at the foot over the plunge, the crest still white; the current is untouched.
- **Step 5, the sky and the rain**: the night sky's zenith, mid and horizon colours are lifted by `ambient_floor.night.sky_gain` (1.8) as the sun sets, so the night sky glows indigo with the painted cloud tile and the stars over it instead of going black. Rain is drawn by `RainOverlay` (`shaders/rain_streaks.gdshader`): a canvas under the post grade, so it takes the grade and the dither, with one-pixel-wide straight streaks rolling down the internal 480-line frame in two layers of columns, more columns lit as the rain thickens (dense in a storm), thinned under cover, leaning with the wind. The rain particles are off (the snow stays).
- **Step 5b, grass near** (`terrain.gdshader`, `look_grass_m` from `ranges.grass_m`): within 40 m the grass tile gains a second, three-times-finer layer of blade flecks, tinted by the ground's own colour, fading to the plain tile by 40 m. Shader flecks, not card geometry: if Mike wants blades standing off the ground, that is a placer tier next.
- **Step 6, night accents** (`NightAccents`, `data/night_accents.json`, added as a feel call; the designer owns the data): once the sky's daylight is under `shows_below_daylight`, glowing moss hangs in strands under the crowns of the willows (`genera`) in SWAMP and BOG within `range_m`, cold green-cyan with a slow flicker; at ruins in TEMPERATE_DECIDUOUS and TEMPERATE_RAINFOREST a swarm of blue butterflies drifts and flaps round the ruin within `radius_m`, like the fireflies but blue. Both are freed by day. Fire stays the only warm light.
- **Checks:** `camp_check` 60/60, 0 fails (the camps unchanged by the look). The ruin-side night accent and the waterfall could not be rendered at the dev spot (no ruin and no fall within the frame); they compile and run in the renders above.

## 2026-10-01 — Three bugs from Mike's dusk play and the sprint feel (Mike, from chat)
- **Bug 1, leaf cards as solid shards.** The suspect was wrong: today's ambient-floor edit touched only the leaves' emission, and the cutout path (the leaf cell near 25 m, the mass tile's holes farther, `ALPHA_SCISSOR` 0.5) is intact: the §AJ 4 see-through render (`species_row.gd UP=1`, an oak) reads 0.23 sky through a ragged crown, a lone she-oak 0.78, and `tools/leaf_lod_check.gd` at the dev spot lists every tree round the camp at the hero level with ~1,900 cut-out cards each, every leaf and card texture set with alpha, the ambient detail ring at 2 chunks. Two things did read as shards and are fixed: a tree with no branch layout (the understory tiers, palms, herbs like the Datura; `TreeLayouts.branchy` is false below the canopy tier) was drawn as the old crown hull with the foliage mass painted on and the shader gave that surface alpha 1 (a faceted blob up close), and the far tree pictures had a smooth profile for an outline. The hull is now cut like the cards (`foliage.gdshader` mat 1: the leaf cutout near, the mass tile's holes far), and the pictures keep only what the leaf-card cutout keeps over the outer half of the crown, so sky shows through their rim. *What is still solid, measured:* the dev-view frame at 18:00 (rendered before and after, with the chunk at the hero level) shows the camp's she-oaks as flattened solid crowns with a few leaf holes. The listing names them: forty trees round the fire, every one a Beach she-oak 39–45 m tall (the stand's giants, conifer shape, 1,900 cards each). The same species stood alone at 21 m reads sparse and ragged (the renders above), so the cards are right and the *stand* is wrong: at a giant's scale the cards are twice the size the see-through sizing assumed and their union closes. That is a §AJ sizing task (cards sized against the tree's own height, the gap test run at the giant's scale), noted for the look pass, not a shader bug. *The 2-chunk ring:* the choice is `min(2, display.render_chunks)` in the ambient profile with no headless-only branch (`ChunkManager`), so it runs on any GPU; it collapses to 1 only if the render distance is set to 1 in settings (the default is 3). The F3 overlay now prints the detail ring and the plant level of the chunk you stand in, so a frame from a real GPU can say what it was drawing. A real-GPU frame I cannot take here.
- **Bug 2, the invisible wall at the fire.** Found by code, then proved by the walk: every camp prop's colliders (`CampProps`: the shelter, the racks, the woodpile, the food store) and every ruin mark's (`RuinMarks`) were added to the camp's own body at the prop's *local* transform, so the shelter's 1.6 m capsule, the woodpile and the rest all sat at the camp's origin, which is the fire. Each prop now carries its own `StaticBody3D`, so its shapes ride with it. The dev readout asked for: when the unstick rule frees you it prints the blocking colliders' node paths and shape sizes (`data/dev.json` `stall_log`, or `STALL_LOG=1`; `[stall] wedge at …; blocked by: …`). `tools/fire_wall_check.gd` walks at the fire from four bearings holding W: at the opening camp every approach ends 0.19 m from the fire (the stones stop you, and with the readout on they name themselves: the fire's own ring-stone capsules). The ruin-camp half could not run here: in headless on this box a ruin's build task never completes (one task pending for the whole run, so no ruin and no ruin camp is ever built in the checks; it also makes the camp check's ruin-signature test vacuous), which is a harness limit to fix next, not a play bug (Mike's savanna camp is a ruin camp).
- **Bug 3, fires out for good in a pre-loop save.** A tended camp fire that is "out" now relights at dawn from the woodpile when the pile has units (the folk keep an ember; no fire is made), feeding `feed_units_per_tick` as the loop does; the catch-up tick runs the same at every missed dawn, so an old save's dead fires come back at the first dawn after load. The camp check's collapse scenario had to change with it: a fire merely put out recovers now (as it should), so the scenario strips the woods in reach, which is what §BL says takes a camp.
- **Feel, the sprint through a jump** (`movement.json` `profiles.ambient`, flagged in `_help.sprint_momentum`): the momentum died in the landing squat (`squat_s` with the target zeroed and ground friction at 60 m/s² cost ~3 m/s of 5.6 every hop). In ambient: `landing.sprint_keeps_speed` true: a sprint held through a light landing takes no squat and no friction frame; a jump from a sprint carries the run's full speed; `air.sprint_jump` 1.05 in the profile scales the *carry* of a running hop (in the shinobi profile it still scales the jump's height), and `air.hop_cap` 1.1 caps chained hops at that times the sprint, so bunny-hopping never beats running. Holding Space reaches none of the disabled tech: the bounce and wall jump are behind their `enabled` flags and the cling is on right click.
- **Checks:** `camp_check` 60/60 (the relight at dawn and the stripped-woods collapse both green); `leaf_lod_check` 4/4; `fire_wall_check` opening camp 4/4, the ruin half blocked by the headless ruin build above.

## 2026-10-01 — Camps are alive: a people per site, the store and the loop, the ladder, the headman's gifts, ruins that remember, collapse, wildfire, the canopy folk (Mike, from chat; design 30 Sept §BL–§BT, `data/peoples/`, `data/techniques.json`, `camps.json` → `sim`)
- **Step 1, a people per site** (§BO, `biome_map.json`, `Peoples`): every camp and ruin site runs the site rules in order (rock shelter: a cliff site or CAVES; karst: limestone karst, one site in two; canopy: the five old forests, one site in six; mangrove; coast: the tideline within 300 m; lake: a lagoon or lake shore within 200 m; marsh: the wet biomes; river: a reach 10 m wide within 200 m; then `by_biome`), and the first that matches names the people. The camp is dressed from its people file and the biome's `dressing.by_biome` row (`CampProps`): the shelter's form read from its words (a tent cone, a dome, stilts, a longhouse, adobe, a reed barrel, an overhang wall, a low house), three or four of `aesthetic.props` round the fire (racks, a hull, the midden, flats, a ring, jars, a frame, a spring, a cairn, net poles, a lamp, bundles), the palette from the dressing's colour words, the fuel kinds in the sim; `folk_kinds` picks each camp's kind (human, goblin, orc, fae, small folk) and the rig reads the silhouette's `folk_scale` (an orc is tall, a goblin short), all friendly. The log says "the <people> live here" the first time you come to a fire. *Design calls I made:* the canopy and karst rules hash the site (the stand's giants and a cave are not known when the site is named; the canopy camp then checks the real giants when it builds, Step 8); a folk kind changes scale and palette only (no ears or tusks yet); the opening camp keeps its two authored folk and gains the store props.
- **Step 2, the store and the loop** (§BL, `camps.json` `sim`, `CampSim`, `WorldSave` `camps`): each camp has a state (its folk, wood and food in units, the woods within reach, its rung, the fire's own store) that ticks once per game hour (`tick_game_h`) and catches up every missed tick on load (`catch_up`: the camp grows while you are away; the sim burns an unloaded fire itself, `FireStore.burn`, so a camp's fire is one store whether the scene holds it or not). By day (`gather_hours`) the folk split their gatherer-hours by what the fire burns and what they eat (a unit of wood is one branch's worth of burning, whatever the people burn: reeds go on by the armful, a log is one), bring wood and food to the store up to its targets (`wood_days_target`, `food_days_target`), the spare hours to food (a surplus is the ladder); they feed the fire from the woodpile when it drops under `feed_fire_below_units`; the woods within reach thin with the take and grow back a share a day, slower once stripped, and a stripped wood means a longer walk (`reach_m`). The store is visible, no HUD: a woodpile whose rows grow with the units and a food store (a rack of strips and baskets) that fills, both by the fire; one of the folk walks out `walk_out_m` and back now and then. Right click either with fuel, food (fruit, mushrooms, fish, herbs) or seeds in hand to give it (`CampSim.wood_units`, `food_units`, `is_seed`). *Data added as first guesses (flagged in `camps.json` `_help.sim_first_guesses`; the designer owns them):* `loop.wood_per_gatherer_h`, `food_per_gatherer_h`, `walk_out_m`; `store.feed_units_per_tick`, `feed_fire_below_units`; `restraint.woods_units_in_reach`, `regrow_per_game_day`, `reach_grow_per_stripped_day_m`; retuned once after the first run so a camp of three keeps its fire and a camp of five banks a surplus (the first numbers let every camp strip its woods in ten days and die).
- **Step 3, population and the ladder** (§BM, `sim.population`, `sim.births`, `sim.ladder_gates`): a camp starts with 3–5 folk, men and women (the rig: a woman's build at 0.94, the voice pitch; the first two one of each). **Three life stages (Mike, `sim.births.stages`): a child by the fire does not gather; a teen gathers at `gather_rate` and holds no role; an adult does both; each stage its `game_days`, the rig at its `rig_scale`.** Births need a man and a woman, `needs_surplus_days` of surplus, a slow clock (`every_game_days`) and room under the ceiling: `forage_cap`, plus `fundamental_adds` once the people's fundamental stands (a weir at the shore for fish_run peoples, placed where the water is; a garden plot by the fire for crop peoples once seeds that take in that soil and climate are in the store, `PlantSpecies.suitability`), plus `crop_adds`, never past `village_cap`. The ladder (`sim.ladder`): fire → food (a day of food banked) → storage (`surplus_days_for_storage`: the headman, a man, and the plantkeeper, a woman, appear, marked by the staff and the pouch) → specialist (the maker, where the people has one and `folk_for_specialist` adults and a surplus) → exchange (a neighbour at specialist within `neighbour_km_for_exchange` with a different craft). A specialist still gathers at `specialist_gather_rate` (a role, not a job; flagged). Herd and managed_burn are not built (§BM: last). Restraint: the woodpile thins when the take outruns the regrow.
- **Step 4, the headman bestows** (§BN, §BP, `techniques.json`, `Techniques`, `WorldSave` `techniques`): right click the headman and the people's `headman_teaches` technique is yours, a permanent flag per world, "The <people> showed you <name>." in the log; mute, no cutscene. Five verbs are real: **line and hook** (`FishingLine`: right click a branch with grass or reeds in the pack to make a pole, item kind `pole`; hold it and click at water within `cast_m`: the float lands, a bite after `bite_s`, click within `hook_window_s` to land a fish, else it is gone); **the coppice** (`Coppice`: right click a hazel, ash, willow, alder, lime or chestnut and it is cut to the stool, three branches drop, the far and near meshes of that tree go, its graph and trunk shapes with them; the stool regrows poles on `PlantGrowth`'s clock for the species, honestly slow; `Coppice.ready` → right click takes the poles; kept per world, `stools`); **the resin torch** (right click a conifer with an unlit torch in hand: the torch carries resin, `torch.json` `resin`: `burn_scale` longer, `energy_scale` brighter, drizzle-proof, storms at `storm_burn_scale`); **the ember carrier** (right click a lit fire with nothing in hand: a coal wrapped in bark, item `ember`, good for `ember_game_h`; right click the ground to lay a new fire from it, `PlayerFires`: an untended fire of `fire_units` kept per world; neglected it goes cold; it gives no light); **the fat lamp** (right click the food store knowing the technique: a lamp for `costs_food_units` of food, item `fat_lamp`; right click the ground to set it down: a dim light of `range_m` for `burn_game_h`, never blown out, kept per world). The other techniques are flags. No fire drill anywhere. *Data added, flagged:* `techniques.json` `params` per real verb (`_help.params`); `torch.json` `resin`; `items.json` kinds `pole`, `ember`, `fat_lamp`.
- **Step 5, ruins remember** (§BQ, `RuinMarks`, `SoilMarks`): every ruin carries its people's `ruin.signatures` as props at its footprint, each starting at `legible` "heap" (a mound that reads as what it was: a shell midden, weir stakes, salt pans, house pits, a kiln, a cairn…); when a camp squats there the marks advance with its ladder (cleared at food, restored at storage: the mound becomes the thing) and the camp inherits what `inherits` says (`CampSim.inherit`: the weir from the first season, salt from day one, a clay pit's surplus, level ground) once. A midden or black earth marks the soil (`SoilMarks.fertility_at`): the placer grows the ground tier richer on it (`plants_differ`), so a midden reads as a different green from fifty metres.
- **Step 6, collapse and the dark** (§BL, §BA, `sim.collapse`, `sim.abandon`, `embers_game_h`): a fire kept low (not in flames at any night hour) for `fire_low_nights_to_taken` nights lets the dark walk in: `taken_per_night` folk a night, blood by the fire; the survivors walk to the nearest lit fire and join it (`survivor_lost_chance_per_night` on the way) with a share of the store. Food short for `starve_moves_after_days` moves them to a neighbour instead, no blood. A camp fire's embers last `embers_game_h` (longer than yours) so an armful of fuel can save it; survivors come back to a fire relit within ten days. An empty camp keeps its needful things by the dead fire (a fuel pile, a torch bundle; the pot waits on a potter), is a ruin after `ruin_after_game_days` and the forest takes it over `forest_takes_game_days` (the props sink). Camps never harm each other.
- **Step 7, wildfire, rare** (§BL, `sim.wildfire`): only where all three hold: a fire-prone biome (`fire_prone_biomes`, flagged), a dry spell of `dry_spell_game_days` (less than `dry_rain_mm_h` of rain in a tick keeps it counting) and an ignition: lightning in a storm (`lightning_chance_per_storm_h`) or a lit torch of yours lying in the grass near a camp. The burn runs downwind from the ignition (`spread_m` by the wind), an ellipse scar kept per world (`CampSim.scars`): the ground is darkened in the chunk's vertex colours, the shrubs are gone, the trees in it stand bare and dead (the placer's `burnt`: no leaf), the ground tier comes back thicker (the fire-followers), and the scar fades over `scar_lasts_game_days`. A camp in its path walks away and rebuilds a valley over (a `moved:` state at the nearest free ruin site within 6 km). Nothing moves terrain (§BS).
- **Step 8, the canopy folk** (§BT, `canopy.json`, `CanopyVillage`): at a site that passed the canopy rule, when three or more giants stand within 60 m (the chunk's real trees: branchy, climbable, taller than their species' band or over 26 m), the village goes up in the tallest three or four: a deck lashed round each trunk 8–15 m up (four plank strips with a hole for the trunk, props down to the trunk, rail posts and rope rails, a leaf roof on posts over the back half, bark walls in the cloud forest and the deciduous), vine bridges between neighbours (planks along a sagging line, each with its collision, rope rails, a cable from each end up the trunk), a clay hearth box on the first deck with the camp's fire in it, the folk seated round it and at the back of their own decks, the store a small bundle on the hearth deck; no shelter on the ground, no walker (they never come down), no torch bundle at the foot. No ladder comes down for a stranger: climb the trunk (the §AU climb, which goes on through the deck's hole) and let go onto the deck. Once the headman has met you the rope ladder hangs from the hearth deck's edge (`met_headman`): right click its foot to climb it, its top to come down (`PlanetPlayer.start_ladder`, a scripted climb, hands busy). The log, at the fire: "They live up in the giants. No ladder comes down for a stranger." With the giants not yet in (the chunk's trees come after the camp), the camp waits on the ground and is built again when they are. `tools/camp_check.gd` lashes three giants into a chunk and builds one: three decks, bridges, the hearth up, the ladder hidden, the climb.
- **Checks:** `camp_check` (steps 1–8) 59 passes, 0 fails; rerun since camps, main, the placer and the terrain changed: `dread_check` 26/26, `hud_pin_check` 43/43 (ambient), `tech_check` 24/24 (shinobi).
- **What still reads as copy-paste between two camps of the same life, and what the dressings most need next.** Two coast camps now differ in their palette, their biome row's words and their folk kind, but they still stand the same way: the same shelter form, the same three props at the same radii, the same woodpile rows and food rack, the same seats round the same fire, and the folk do the same walk out and back. What would break the copy is the *site* writing the camp: the shelter turned from the prevailing wind and dug into the dune's lee where the dressing says so, the racks on the shore side, the midden downwind, the weir where the water actually is (it is: the one prop that already reads the site), and the people's `food.how` as visible activity (one at the racks, one at the tideline, one at the fire) instead of one walker. The dressings most need, in order: a *second* form per people (a summer and a winter shelter, or a rich and a poor one, so a camp on the ladder's fourth rung looks different from one on its first), props that *scale with the rung* the way the store already does (the midden grows, the racks multiply, the plot widens), a palette that leans on the biome row's own colour words harder than the people's list (they are mostly the people's list now), and folk kinds with a silhouette beyond scale (a goblin's ears, an orc's tusks, the fae's hood light at night, the small folk's lantern is in). The canopy village is the one camp the site writes already, because the trees do; the next most site-written would be the rock shelter (the overhang is there), then the marsh (the hummock and the boardwalk).

## 2026-09-30 — Rooms, roads, current, sound, stands, travellers (Mike, from chat; design 30 Sept §BB, §BC, §BE–§BH)
- **Step 1, the sound split** (§BG, `audio.json`): two systems now. *The bed* (`SoundBed`, no position, its own bus): four loops from the synth (`wind_loop`, `insects_loop`, `frogs_loop`, `birds_far_loop`), mixed by the biome's group (forest, open, wetland, desert, cold, coast) × the hour (dawn, day, dusk, night) × the season × the weather (rain quiets birds and insects; insects and frogs silent below `cold_c_silence`), frogs only within `frogs_near_water_km` of water, the wind loop by the wind's own speed. Wind pressure changes under canopy: the wind loop's gain and a low-pass on the bed bus follow how much sky the place sees (the dapple stamp's sky visibility and the sky system's enclosure), so stepping under the trees closes the wind. The bed thins at dread stage 1 (`Dread.bed_gain`, with the creatures' calls). *Sources* (every `kinds` row, `class: source`): a 3D player at a place you can walk to, muffled by terrain and foliage where `muffle` is set (now also water, the falls, fire, the torch, the litter's rustle). New sources: every campfire crackles (`fire_loop`, quieter as it burns down, silent when out); the rivers run (`WaterSounds`: four `water_flow` players kept at the nearest reaches, louder for a faster, wider one) and every waterfall roars from its plunge pool (`waterfall_loop`, on the chunk's fall). The filing is in `audio.json` `_help_bed` and the `bed` block: **I added the `bed` data as a feel call (levels per group, hour and season); the designer owns it from here.** The creatures' calls stay sources (one animal calling from where it is); insects and swarms were already silent as creatures, so the bed carries them.
- **Step 2, waterfalls, then the current** (§BE, `data/water/current.json`). *Waterfalls checked first* (`tools/water_check.gd`): they generate (on the stamp world 903 falls on 202 of 344 river segments, `RiverNetwork.falls`) and render (the chunk at the nearest fall carries its `Waterfalls` sheet mesh, `shaders/waterfall.gdshader`), so the pipeline is intact; what Mike saw as broken is most likely the *look*: the sheet is a thin translucent arc that reads as river surface from the lip, and it has no sound until now. Each fall now roars from its plunge pool (`waterfall_loop`, louder for a taller, wider fall). *The current* (`Current.flow_at`): every river segment carries a flow downstream, its speed from the segment's slope (`slope_gain`) and width (`volume_gain`) within the kind's band (stream, river; a rapid where the white water is; the churn below a fall; nothing in a lake or the sea), fading at the banks. In the water you drift with it (`PlanetPlayer.current`, added to the velocity: full share swimming, a smaller one wading); wading drags by depth (`wade_drag` knee / waist / chest); against a reach at `upstream_wall_ratio` of the swim speed or more there is no headway upstream (the wish against the flow is cancelled): rivers are one-way corridors; carried over a lip you fall, and the fall hurts as any fall does; the torch douses as before (§AW). The rivers sound (`WaterSounds`: `water_flow` sources at the nearest reaches). `dev_view` takes `AT=x,y,z` (`LOOK_AT=`, `AT_YAW=`) to stand anywhere.
- **Step 3, stand dominance** (§BH, `stand.json` `dominance`): each stand (a cell `stand_m` across, its size drawn per coarse cell) rolls, per tier, one dominant species (by fit here and the old slow dominance noise), 1–3 associates and the rest as accents, and the dominance factors are set so that at the chunk's middle the species' weights come out in those shares (the dominant `dominant_share`, the associates the rest less `accent_share`); in the `salad_biomes` the dominant holds only `salad_dominant_share` and every other species is an associate. The understory tiers roll their own dominant in the same stand cell, so a stand's floor is as consistent as its canopy, and the young cohort already grows from the stand's own trees. The catalogue is untouched: it changes how it is drawn from. `tools/stand_check.gd` measures the top species' share of the trees per chunk round the camp.
- **Step 4, roads** (§BC, `data/roads.json`, `RoadNetwork`, `RoadProps`): a trail network laid before the plants, built by region on demand from any thread (the chunk colours and the placer ask for it as chunks compute). *Nodes:* the ruins (`Ruins.find`), the mythic folk's camps (`Territories.find`), hot springs (the biome) and standing stones (their own hash), none closer than `min_spacing_km`, ruins kept first. *Links:* each node's three nearest within `link_max_km`, pruned to a relative-neighbourhood graph, each routed by A* over a 200 m lattice of the terrain that costs grade above `max_grade` (the road switchbacks), water crossings, lakes and the sea (never), and rewards a river bank, so roads follow rivers and contours; the ends on the nodes, the line smoothed. *Unmaintained:* per link by its own hash, a bridge (a wide river) out with `bridge_out_share`, both stone abutments standing on either bank and the deck gone; a ford (a narrow one) with stepping stones; a trail that ends at a collapse with `collapse_end_share` (cut short, rubble across the way); waymarks every `waymark_every_m` (cairns, standing stones, posts; `waymark_fallen_share` tipped over); the tread on the ground (`TerrainChunk.PATH` blended into the vertex colours by `trail.wear` × (1 − `overgrown`); Footsteps read it as dirt) with the understory kept `understory_clear_m` clear either side and the trees off it; a canopy tree of the stand's dominant at every bend (`tree_at_bend_m`). *Off the road:* half the links set a find 40–120 m off the trail, out of sight (the ground between rises over the line of sight, or 60 m into a forest; the placer tries five spots): a tall standing stone, a spring (a ring of stones round a pool with its own quiet water) or a lone old tree (a giant of the stand's emergent, placed by the placer). *Forks legible:* where two links leave a node along the same ground, the second starts where they part, so the fork is where you see the roads separate (a waymark logic for the fork proper is still to come). Rivers are the other road type (§BE made them one-way). The props are built round the player as the links come into reach (`RoadProps`, 450 m) and freed as they go. *Not yet:* ruts (a texture pass, not vertex colour), passes as nodes (the routing finds them, nothing marks them), the road's own name on the HUD.
- **Step 5, rooms** (§BB, `data/rooms.json`): rooms hang off the network where it widens: at the nodes, at fords and bridges, and at four bends in ten, `size_m` across. The understory at eye level makes the walls (`RoadNetwork.wall_scale`, in the placer's shrub tier): the room's floor thinned to `floor_density_scale`, its edge band (`edge_band_m`) thickened to `edge_density_scale`, a corridor's sides just past the cleared strip to `corridor_side_scale`; the ground tier thinned on the floor. *The reveal:* a room's open headings are where the ground drops away or water lies just past its edge (a ridge, a valley edge, a shore): no wall is grown on that side, so the corridor's end opens. *Thresholds:* where a road crosses a room's edge a boulder stands either side of the way (`RoadProps`, `threshold.width_m` between). *The test:* `tools/road_check.gd` runs a ray version of the sky-share measure (rooms.json `test`) at a room within reach: sixteen headings from eye height, closed within 40 m or open; the measure_look.py image measure stays the reference for a real frame (it needs a render). The vista stays and stays cheap: nothing here touches the pictures and far shell. *Not yet:* a ceiling preference (canopy over corridors) beyond what the bend trees give; a stair or arch threshold (boulders only).
- **Step 6, travellers** (§BF, `data/travellers.json`, `Travellers`): rare cloaked figures walking the roads (`per_km_of_road` of the road within 700 m; put down out of sight, 140 m or more off), day and night, never off the road, never stopping, never speaking; a tribe's palette or ash grey. The hood tracks you from `watch_m` while you are in front of it, capped at the hood (the §B rig's head band; the torso never turns, the body never breaks stride), holds `hold_s` after you pass, then turns back to the road. At a road's end they turn back if you can still see them, else they go (where they are going comes later). They walk unharmed through the dark: the dark hunts only you. The check drives one and watches its hood.

## 2026-09-30 — Ambient cut, the eight steps: movement profile, first person, ambient floor, torch, fuel, hearth, log, dread (Mike, from chat; design 30 Sept §AU, §AV, §BD, §AW, §AX, §AY, §AZ, §BA)
- **Step 1, the movement profile** (§AU, `movement.json` `profile` / `profiles`): `Tuning` deep-merges `profiles[<profile>]` over the base table when it loads movement (`MOVEMENT_PROFILE=shinobi` in the environment forces the other one for the checks). A block with `enabled: false` is off in code, not just tuned down: wall jump, cling and wall kick (`WALL_JUMP_ON`), bounce, swing, redirect and the missed-roll penalty, the roll as a landing tech (a heavy fall hurts instead), fast fall when its speed is 0, the super meter (`SuperMeter.ENABLED`: no perfects, no hits). Space is the jump; right click is interact and starts the tree climb; tree climbing, handholds, burden, footsteps and fall damage stay. The shinobi profile still passes `tech_check`, `super_check` and `climb_check` with everything on. The HUD's default pins come from `hud.json` `pins_ambient` in ambient (the clock only; the speedometer is unpinned) and the key help reads for ambient.
- **Step 2, first person only** (§AV): `camera.third_person false` in the profile makes V a no-op and forces first person on load; the third-person rig never draws. In first person only what is in your hand is drawn (bow, spear, torch, or nothing).
- **Step 3, the ambient floor and the regression** (§BD, `look.json` `ambient_floor`). *The audit of the darkening stack:* terrain = shadow map × dapple stamp × crown disc × `look_canopy_dark`, and the crown fleck term (0.66×) and the dapple darkening were both applied inside the shadow map's own range, so ground under a tree took the shadow map, then the stamp, then the crown term, near black at noon. Now the stamp and fleck terms fade in only beyond `look_leaf_shadow_m` where the shadow map ends, and the floor is added *after* the stack: `look_floor` (the hour's floor colour × energy) × sky visibility (the dapple stamp, 1 in the open; `TerrainChunk.sky_visibility_at`, 5 taps with `feather_m`) × the enclosure check (`SkySystem._update_floor`: five rays up, 40 m; three or more non-tree hits = inside, eased over a quarter second → floor 0 in a ruin or a cave), never below `sky_visibility.min_outdoors` while any sky is visible. Foliage gets the floor too. The hour's sky ambient is the day/night `sky_energy` × sky visibility. Night is mesopic: the floor is blue-grey (`night.floor`), and the post grade drains colour below `desaturate_below_luma` (`night_desat`, `desat_luma` in `post_grade.gdshader`). *The regression:* dusk read like sun because the sun's "up" ramp finished at 6° elevation (now 9°, so the low sun stays dim and orange); the ground was black near trees for the stacking above; the cruder leaves were the far pictures starting at the 1-chunk detail ring after the render-distance work, so the ambient profile runs a 2-chunk detail ring (`ChunkManager.DEFAULT_DETAIL_CHUNKS`, `DETAIL_CHUNKS=` overrides). Leaf shadows on the cards are unchanged.
- **Step 4, the torch and empty hands** (§AW, `data/torch.json`, `items.json` `starting_kit_ambient`): in ambient you wake with nothing and nothing is laid beside you; every camp fire (the opening camp and the ruin camps, `Torch.lay_bundle`) keeps a bundle of three unlit torches beside it, remade after `bundle.remake_h_game`. Right click takes one (Q cycles to it; it goes into the hand if the hand was empty). `Torch` (a node on the player, first-person stick and flame under the camera, an `OmniLight3D` with the data's range, falloff and 9 Hz flicker, no shadow): unlit until right-clicked against a lit campfire or a planted torch within `lighting_reach_m` ("You light the torch"); burns `burn_min`, rain and storms shorten it (`rain_burn_scale`, `storm_burn_scale`), the last `gutter_share` gutters (dimmer, harder flicker), then out: a burnt stick. Swimming or wading past `douse_depth_m` puts it out; so does Q-ing away from it. Right click the ground with it lit to plant it (`PlantedTorch`: a standing stick with the same flame and light, burning down on its own; right click to take it back, burning or burnt); a lit torch dropped from the pack lies burning. Starting a climb or a cling plants it if there is ground, else it goes out. Creatures' `light_response` (flee / avoid / shy / drawn) now reads `Torch.light_at` and `PlantedTorch.light_at`, which is the actual light on them. The log gets its buffer (`GameLog`, step 7 draws it): lit, planted, out.
- **Step 5, fire is fuel** (§AX, `data/fuel.json`, `FireStore`, `FuelField`): every campfire has a store of fuel units (kind, minutes left) that burns down flames → low (below `low_share`) → embers (relightable for `embers_min`) → out; `Campfire.flicker` draws the burn level (smaller, dimmer flames; embers a dull glow; a dead fire dark coals, no ground glow) and `lit_near()` reads it, so embers and a dead fire give no safety, light no torch and drain no dread. The store is keyed by the fire's place, so a camp rebuilt as you come back remembers. Every fire built so far is a folk's fire and burns at `tended_burn_scale`; camp folk don't die yet, so a camp only dies where its biome offers nothing to burn (ice, salt flats, the open sea's shores) and the eight starting units run out. Fuel lies in the world by the biome table (`FuelField`: hashed places in the chunks round you, so many per chunk as the abundances add up to, drawn as what they are: logs, branches, brush, reeds, grass, dung, peat, driftwood, fronds, ribs, culms); right click gathers a piece (a log counts two carried things for the burden, `carry_items`); gathered in rain or off soaked ground it is wet and burns at `wet.burn_scale` until it dries in the pack (`dry_h_game`). Right click the fire with fuel in the pack puts the first piece on ("the fire is stacked full" past `store_max_units`); wet fuel on embers catches only with `light_chance`, else hisses and is lost; dry fuel on embers relights them; fuel on a dead fire stacks cold. Right click embers or a dead fire with a lit torch relights it ("nothing left to burn" if the store is empty). The log gets fire lit / embers / out for fires within earshot.
- **Step 6, the hearth** (§AY, `camps.json` `wake_at_home`, `Hearth`, `WorldSave`): the first hearth is the opening camp's fire; right click the lit fire of any camp you find ("Make this your hearth"; the camps' fires and the opening camp's are marked, a mythic folk's fire is not) and it is yours. In the ambient profile a death wakes you at the hearth wherever you fell (the 29 Sept nearest-ruin rule stays for the shinobi profile), the folk's line and all; what you carried stays on your body where you fell, as before. The hearth is kept per world in `user://worlds/<seed>.json` (`WorldSave`, written a few seconds after a change and when the game closes; the log will live there too).
- **Step 7, the log** (§AZ, `hud.json` `log`, `LogPanel`, `GameLog`): Enter opens a Minecraft-chat panel low on the left of the 480-line frame, `lines_visible` lines at `font_px`, newest at the bottom, each stamped from the clock (the hour on the line, a dim day line where the day changes); a text box at the bottom takes a note (Enter keeps it, `note_max_chars`), Esc or Enter on an empty box closes; the wheel and Page Up / Down scroll. While it is open the movement keys are the box's (`PlanetPlayer.typing`). The events: deaths with their cause (`death_lines`: "Fell", "Killed by a wolf", "Taken by the dark"; `PlanetPlayer.death_cause` is set by whatever deals the blow), the torch lit / guttering / out, the fire lit / embers / out, the hearth set, a camp found (the first time you come to its fire), a biome first entered, dawn and dusk. Kept per world in the same save as the hearth (`WorldSave`). No other chat, no commands.
- **Step 8, the dark closes in** (§BA, `data/dread.json`, `Dread`): a hidden meter, nothing on the HUD. Night past `dusk_grace_min`: full dark fills it at `fill_per_min_dark`, moonlight at `fill_per_min_moon`, a lit torch in hand or planted within its range at `fill_per_min_torch`; inside a lit fire's radius it drains at `drain_per_min_fire` (embers and a dead fire don't count: `FireStore`); day empties it. The stages by `stages[].at`, each heard before seen: 1 the bed thins (`Dread.bed_gain` falls over `bed_fade_s` and the creatures' calls stop); 2 a sound behind you, only while you move, at the data's bearing and distance (a scuff, a crack, a rustle); 3 a shape at the edge of the light off to one side, gone when you look at it for `vanish_on_look_s` (or after a few seconds); 4 it follows in the open, the pacer: parallel at `keep_m`, faster than you; 5 it closes if there is no light on you or you are past `far_from_fire_m` from any lit fire, howls (the werewolf) or whispers (the dark), and takes you: "Taken by the dark" in the log, and you wake at the hearth. With light on you at stage 5 it holds off at its distance until the torch gutters. Never inside a lit fire's `never_within_fire_m`; it ignores travellers (it only ever hunts you); no bestiary, no HUD. The one hunter built: the werewolf as a pacer in the temperate forests (`hunters`, `first`; `full_moon_speed_scale` when the moon is full), its body from `CreatureBodies`; everywhere else, including the biomes whose named hunters aren't built yet (night rider, pond crawler, skinwalker, yeti), the dark itself: a cloaked shape with no species. Ambient profile only. The hunter glides (no leg animation yet). `tools/dread_check.gd` runs the fuel store, the hearth, the log and the dark end to end (13 checks).
- **The checks and the two profiles:** the fuel economy, the fuel field and the dark run in the ambient profile only (design §AT: the shinobi game keeps its fires burning, its nights safe). The checks written for the shinobi cut (`tech_check`, `super_check`, `climb_check`, `tool_check`, `inventory_check`, `play_fixes_check`, `hits_check`, `strike_check`) run with `MOVEMENT_PROFILE=shinobi`; `hud_pin_check` reads the profile's pins; `dread_check` runs ambient.
- **What the reference frames still have that we don't** (Mike's ask, after the eight steps): the reference stills are lit by one thing at a time, and ours still aren't quite: their night is a single blue-grey wash with the fire the only warm note, where ours still carries the sky's gradient and the moon's colour into the ground; their canopy is a few big, soft shapes against the sky (four or five values, no fleck), where ours breaks into many small cards past the near ring; their fog is a flat band that sits the trees in depth, where ours still shows the horizon through it; their frame has a foreground (a branch, a rock, a hand with the torch) that ours has only when the torch is lit; and their ground is one texture at one scale, where ours changes tile and colour at the detail ring and again at the litter. The next look pass is those five: a flatter night, fewer bigger canopy shapes, a thicker fog band, a foreground element, and one ground scale to the horizon.

## 2026-09-30 — HUD lettering bigger; the 1/10 scale checked (Mike, from chat)
- **HUD text** (`data/hud.json`): body, prompts, subtitles and the plant name at 30 px on the 480-line frame (VT323 is crisp at multiples of 10; crisp sizes 20/30/40), the origin line, speedometer, weapon line and the key-help block at 20. Rendered at 14:00 to check; `hud_pin_check` passes.
- **The 1/10 audit, everything on one clock:** a game day is 144 real minutes (Earth's 1440); the planet's circumference, heights and lapse rate are 1/10 (`PlanetConst`); the year is 365 *game* days, the moon 29.5, the seasons and their transitions in game days (`seasons.json`); the weather sim steps in game hours (`World` → `WeatherSim.step`); plants grow, flower, fruit and rot in game days (`PlantGrowth`, `FruitCrop`, `AroidLife`, `LeafSeason`, litter stages), creatures reproduce in game days. Walking, running, arrows, wind and water are at real speed and real size, which on a 1/10 planet is what makes crossing it feel 10x fast. The few world processes timed in real seconds (ground drying 90 s, scavengers gathering 45 s) sit inside the 10x range of their real-life hours. Nothing found off scale. Still open: the clock restarts at day 13.62 every session.

## 2026-09-29 — Plants grow at real rates; seedlings, saplings and shade leaves; flowers, pollinators and fruit (Mike, from chat)
- **Growth researched for every species** (design §AR, PLANT_SCHEMA §4a4; 1224 entries, `plant_schema_check.py` 0 errors): germination, years to half and 90 % height, first seed, lifespan, shade tolerance, the young form. `PlantGrowth` fits a Chapman-Richards curve per species; one game day = one real day of growth; ages are storage-free (place hash + world clock). **Open question for Mike:** the world clock starts at day 13.62 every session, so growth only accrues within a session. Save the date between sessions, or run the clock off real time?
- **The young:** the stand's regeneration cohort grows young layouts (`TreeLayouts` slots 1 young tree / 2 sapling; `TreeArch` grows saplings as whips, cones, multi-stems, palm establishment rosettes with eophylls, at a third of the mesh budget). The understory holds seedlings and saplings of the stand's species as the light lets live (`VegetationPlacer._place_young`, `PlantGrowth.understory`: a fir's seedling bank under a closed canopy at 1.5 % of full sun, a pine's saplings only in gaps). HUD: "seedling", "sapling", "young tree".
- **Shade leaves:** each plant's light from the crowns over it (`_Light`: optical depth, e^(−1.6·depth)); leaves 1.45x in deep shade to 0.85x in full sun, packed into the custom data's green with the vines (`foliage.gdshader` scales clusters and cards, darkens shade leaves).
- **Flowers and fruit** (design §AS, `FruitCrop`, `FruitMeshes`): every fruiting tree and shrub near the player carries buds, flowers, fruit ripening from unripe to ripe colour, fallen fruit rotting under it, at real places (layout anchors, crown shell, trunk, stalk, under a palm's crown). Pollinators (bees, flies, beetles, butterflies by day; moths, bats by night; birds) visit flower by flower; a flower watched to its close unvisited sets no fruit. Right click picks one fruit at a time ("Right click: pick the ripe crab apple") into the pack (item kind `fruit`, its own icon). Aroid shader gains modes 13 (banded) and 14 (wing). `tools/fruit_check.gd`, `tools/fruit_view.gd`.
- Checks: `growth_check` 0 fails; `growth_world_check` (RENDER_CHUNKS=2 to fit the 6 GB container) 0 fails; a chunk's undergrowth 3.6 s with the young vs 2.8 s without.

## 2026-09-29 — Wake empty-handed with the folk's gifts; bare hands fight; Space is the wall jump, right click the interact; the roll saves you; the fishing pole shelved (Mike, from chat)
- **Waking:** a new game and after a death alike, you wake with nothing on you. The folk who saved you have laid a bow and a spear on the ground by you (`main._lay_gifts()`, items.json `starting_kit`), drawn as themselves. Right click takes each: it's worn in its slot, and goes into your hand if the hand was empty. A set left untaken at an earlier fire is gone. Your old tools wait on your body with the rest; when you take the rest back, any tool you already have again stays with the body (three tools, never more).
- **Bare hands** (`Fists`, combat `fists`): with nothing in hand, left click jabs; hold it to wind up a haymaker, release to throw it. Your speed adds the melee strike bonus, and at `strike.kill_mps` a blow kills anything that isn't mythical. Punching a trunk at speed hurts you. Q now cycles bow → spear → bare hands, skipping tools you don't have.
- **The fishing pole is shelved** (Mike: too much scope; it goes to a separate fishing-simulator game to merge back later; the spear fishes). The cast I'd built (wind up, cast along the look, float on the water, reel with the wheel) is kept in `archive/fishing/fishing_pole.gd`, out of the game: no pole slot, no pole kind, no reel bindings.
- **Controls:**
  - **Space:** jumps on the ground. In the air at a face you've just touched it wall-jumps (or press it a moment early). Just before or after landing it bounces. On a cling it leaps off.
  - **Right click is interact (E is gone):** take things, pick up, climb the tree in front of you. Held in the air at a face: cling (let go to drop off). Held near a branch or vine: catch it and swing. On the ground at a wall or rock: cling.
  - Prompts say "Right click: …". Helper `Controls.interact_word()`. The `wall_jump` action is gone.
- **The ninja roll negates the fall:** Shift within 8 frames of touchdown (was 5), before or after, after any fall past a body length. It takes no damage however high (`roll.safe_m` 1000). Missed, the fall hurts as before.
- Checks updated to the new controls (Space kicks, right click holds): `tech_check`, `super_check`, `play_fixes_check`, `climb_check`. `inventory_check`, `strike_check` and the others take the gifts at the start (`main.take_gifts()`). New `tools/tool_check.gd`: waking, gifts, Q, fists, the high-fall roll, death and the body.
## 2026-09-30 — Titan arum, round two (Mike, from more photos)
- **The spathe is a rolled sheet, not a bowl:** it wraps a little more than once round, the outer edge a flap lying over the seam down one side, closed at the neck and rolling open toward the rim, where it unfurls into the frill. The rim wavers (a torn edge). `AroidMeshes._add_pleated(seam_at, overlap, open_from)`; every Amorphophallus spathe has it.
- **The leaf is built like a small tree:** three arms forking twice into twigs, each carrying a clump of crossed leaf cards (as tree foliage does), leaflets hanging under; layered foliage with the arms showing through, not a plate.
- The seam's side is fixed on the mesh, so in play each bloom's flap faces where its plant happens to turn. **Queued (Mike: "yes" to more epic):** a leaflet tile with lobed edges; crisp white rings on the petiole instead of the generic bark mottle.
- The in-the-wild render was stopped at Mike's word; the model viewer is the way to look at aroids.

## 2026-09-30 — Titan arum made epic (Mike: "the largest inflorescence known to man", with reference photos)
- **A picture in seconds:** `tools/aroid_model_view.gd` draws one Amorphophallus on its own (leaf and bloom, plain ground, one sun), no planet. `aroid_view`'s in-the-wild walk took 20+ minutes a spot on this machine's software renderer (and twice sat on a stale class list after new scripts landed; `godot --editor --quit` refreshes it); it now has `FIND=1` (headless search, prints the spot) and `AT=` (go straight there).
- **The bloom, from the photos:** the spadix appendix now rises from the spathe's foot to 2.15x the spathe's height (3.1 m over a 1.4 m spathe on a 5 m plant; was a stub sat on the rim). The spathe is a pleated bell with a frilled rim that flares past its height and rolls back, green below flushing to the maroon inside colour toward the rim. `AroidGarden.bloom_dims()` holds the proportions.
- **The leaf:** every Amorphophallus grows its real leaf now instead of the umbrella-tree stand-in: one mottled petiole, three rachises forking into three more, hung with big drooping leaflets, a canopy as wide as the plant is tall (the second photo). `PlantMeshes._aroid_leaf`. Far LOD: 3 leaflets a rachis instead of 6.
- **For the designer:** the spadix colour comes from `flower.spadix`, which titanum's entry doesn't set (fallback pale cream). The spathe's rim flush is fixed at 85 % of the inside colour; a per-species `spathe.rim` would let a green-rimmed species stay green.
- Checks: aroid_check 0, tree_check 0.

## 2026-09-29 — The clock is a railway pocket watch; footsteps and climbing quieter, with sliders (Mike, from chat)
- **Pocket watch** (design §AQ, from a photo of Mike's own watch): steel case with its knurled crown at 12, white dial, minute track, bold black 1-12 (a 5 x 7 pixel face with two-cell strokes), red 13-24 inside (3 x 5), black skeleton hands, a red seconds hand on a red cap; no brand, no dawn/dusk marks. 80 px across (+ the crown). Every figure drawn cell by cell on the 480-line grid. `data/hud.json` clock: case, numerals, hours_24, minute_track, seconds_hand, colours. Rendered at eight times of day to check (the OpenGL renderer draws the HUD here).
- **Audio sliders** (settings panel, new Audio section): Volume, Footsteps, Climbing, 0-100 %, clicked or dragged (`AudioMix`: Footsteps and Climbing buses sending to Master; settings `audio.master` / `audio.footsteps` / `audio.climbing`). Footsteps and climbing start at 50 % (-6 dB), from play. Branch cracks and whips moved to their own player on the master bus so the footsteps slider doesn't hide them. `tools/audio_mix_check.gd` 0 fails; `tools/hud_pin_check.gd` 0 fails.

## 2026-09-29 — Round any trunk, however it leans (Mike: "the way that a tree leans should matter… clinging and shimmying, they should be able to circumnavigate it regardless of how it twists")
- **Measured:** `climb_lab` now holds D for 15 s on each trunk with the camera still, adding up the turn about the trunk's own axis. Before this change, straight trunks (pine, birch) went round and round, but every leaning trunk stalled at 5–107°. There were three causes:
  - **A/D reached for whatever lay to your right.** On a leaning trunk, the next hold up or down the trunk lies to the side too, so D climbed the trunk or stepped onto a limb. A/D on a trunk now goes round it, about its own axis.
  - **A/D's direction followed the camera every reach,** so round the back of the trunk D turned you back again. Which way round is now set when the key goes down and kept while it's held.
  - **The feet hung straight down from the hands,** so on a leaning trunk the body dangled on its low side wherever the hands went. The feet now hang along the trunk, and the body model tilts to hug it, even from underneath. Only the body tilts, not the camera (`TreeClimb.body_up` / `body_face`; `PlanetPlayer._tilt_to`).
  - Also fixed: on thin wood, the hands' spread and a diagonal's swing, which are lengths of bark turned into angles, put the hands over half a turn apart. Their average then flipped to the far side and the spiral undid itself. Both are capped in angle (`MAX_HALF_APART`, `MAX_SWING`).
- **Result:** D goes round all ten sample trunks, leans up to 57° (about a lap per 2.3 s). W+D spirals 270–380° in 3 s. In game, W+D does 316–325° on a tamarisk, Miombo and pequi.
- **The cling (right click) likewise:**
  - W goes up the trunk's axis (its branch graph), not the planet's up flattened onto the bark;
  - A/D keeps its way round while held;
  - the trunk counts as held from any side but straight below;
  - the top of a leaning trunk no longer counts as the ground;
  - the body tilts along the trunk.

  Result: 670° round a tamarisk and 875° round a Miombo in 6 s. **Not solved:** on a pequi the cling snags on low limbs (their colliders stop the body 1.2 m out) and gets 49°. Climbing on the graph (E) isn't affected. Whether limbs should stop a clinging body is Mike's call (asked).
- `climb_check`: the W+D and cling-round turns are added up as they go (start-to-end read a whole spiral as nothing), and the leap after circling aims out from where you are. The limb step picks the limb on the side you end up on, which on the big tamarisk is one inside its tangle (the sweep still reaches 10 of 11 of the sample tamarisk's limbs).

## 2026-09-29 — Every branch reachable; hiding at a branch's end (Mike: "any branch that branches off should be accessible (not twigs or overly thin sticks)… crouching at the end of a branch which has leaves hides the player… hide and seek")
- **Measured first:** `climb_lab BRANCHES=1` takes every branch off the trunk thick enough to hold (grip radius 4.5 cm, a metre or more of it). From the trunk beside its foot, looking out along it (or the way it leaves the trunk), it holds W and checks that you reach an end of it, where the wood gets too thin.
  - Most of the misses the first versions reported were the test's own mistakes (too short a hold; one "tip" for a branch that forks into several), not the game's.
  - With the old code: 91–100 % per species on ten species.
- **Fixed:** a stem rising almost straight up out of a fork still leans its own way, and now looking that way picks it (a baobab's crown of stems: 14 → 15 of 15). Now 91–100 % everywhere. The one miss is a tamarisk limb inside a tangle of limbs leading the same way, which a lower start reaches.
- **Hiding already works against animals** (FoliageCover, design §AM 2): out 11.5 m along a tamarisk limb and perched in its leaves, animals on the ground round the tree see you 5 % of the time; perched near the trunk, 77 %. It depends on the leaves at that end: a Miombo's umbrella-tip end left you 61 % seen (14 % near its trunk). Animals now look for your real eye height (lower crouched or perched; it was always 1.4 m).
  - **For the designer:** hide-and-seek PvP is a new design line (multiplayer isn't in the spec). The cover model is ready for it: per-species `canopy.gap`, the season's leaf, and the clusters round you. A player-vs-player version would need other players' sight to use `FoliageCover.see_through` the way animals' does.
- **Fixed, cling on a thin trunk (a pequi):** the right-click grab took the first of its fan of rays to hit, and a side ray grazing the trunk's edge gave a face pointing across you. The crawl pressed along it, past the trunk, and let go. It now takes the face met most squarely: crawl 0.0 → 1.5 m in a second, and the leap off works.
- **climb_check's own bugs**, all from leaning trunks: "your side" was measured from the trunk's foot, and "round the trunk" was flattened onto the ground (13° read for a real 40°). It now measures round the trunk's own axis (43° / 64° / 84° on a tamarisk / Miombo / pequi). `SPECIES=` picks the tree, since the nearest tree changes run to run. It now also climbs out to a limb's end, perches, and prints the cover there.
- `play_fixes_check` is noisy on its own: 1–3 different failures run to run (sprint jump, slides, the deer shot), the sprint jump on the unchanged code too. Not from this work; queued.
## 2026-09-29 — A classic 12-hour clock face (Mike, from chat)
- The HUD clock is a classic 12-hour clock now (design §AQ): rim, twelve hour ticks, pixel numerals at 12, 3, 6 and 9, a broad hour hand and a thin minute hand (once a game hour). The 24-hour ring, the dawn/dusk marks and the PM dot are gone. 44 px across (was 30). `Readouts.feed` no longer takes dawn/dusk; `data/hud.json` clock: `numerals` (quarters | none), `minute_marks`, colours.
- Checked by rendering it at eight times of day (the OpenGL renderer draws the HUD fine here) and `tools/hud_pin_check.gd`.

## 2026-09-29 — Aroids live their real lives; genes, crosses and sports for every plant; HUD pins (Mike, from chat)
- **HUD** (`c94d7fc`): one label per readout; normal play shows only pinned parts (the two dials by default); H = the full HUD; Esc frees the mouse and a click on a readout pins it (gold mark, saved at once). `tools/hud_pin_check.gd` 0 fails.
- **Amorphophallus life cycle** (design §AP, `docs/design/AROID_LIFE.md`): all 246 species got a researched `cycle` block (dormancy dry 196 / cold 6 / everwet cycle 43 / evergreen 1; shoot and bud cataphylls and timings; bloom timing, protogyny, heat, scent, pollinator guilds; fruit; tuber; ploidy; hybrids; sports). ~60 wrong regions/origins fixed from the protologues (47 species moved region, 43 of them got that region's bands).
  - `AroidLife` (pure, off the world clock) + `AroidGarden` (the detail ring, stepped a few plants a frame): leaf hidden while the tuber rests, spike, unfurl, bud, spathe opening at its hour, pollen in the male phase, wilting, berries; the smell on the wind (once per bloom); pollinator clouds (14 insect species, `spawn: "bloom"`, body `insects`); real crosses between plants in bloom; berries as samples carrying the cross; the HUD names the stage.
  - Aroids are no longer `deciduous` (the autumn clock): their whole-plant die-back is theirs.
- **Genes and sports for every plant** (`data/sports.json`, `PlantGenetics`): about one plant in 3,000 is a sport (aroids 1,500, cacti 2,000; grasses/mosses none), kinds weighted to what's documented in the genus (217 of 469 genera researched) and species; clonal clumps sport together. Size sports scale the plant (VegetationPlacer.prepare); the code rides in the moss channel (moss + 2 × code) — foliage.gdshader decodes it and draws the colour sports (tetraploid, variegated, golden, green form, dark form, blue); form sports are recorded for the mesh builders. The HUD adds "variegated sport" etc. after the common name (plants and trees).
- **Checks:** `tools/aroid_check.gd` 0 fails (no world); `tools/aroid_world_check.gd` (STAMP=1) 0 fails; `plant_schema_check` now validates `cycle` (0 errors). The foliage and part shaders compile (checked under GL compatibility with the instance uniform stubbed; this container has no Vulkan to render them).
- **Open:** seedlings don't grow (no persistence / flora ledger yet); the `aroid` mesh (painted petiole, dissected blade) is still the umbrella stand-in; form sports aren't drawn; crosses are only seen within the detail ring. With ~2,000 aroids in the ring on the dev planet a full pass takes ~1-2 s at 1.5 ms a frame.

## 2026-09-29 — Far trees as 2D pictures; shadows only near (Mike: "distant things as 2D… should help performance")
- **Far trees are pictures now (impostors).** Past the detail ring, every tree is one camera-facing quad (2 triangles) instead of the ~1.5k-triangle far model. The quad is baked from the real far model: its height, where the crown starts, the mean leaf colour, a 4-band crown outline and the trunk's width (`PlantMeshes._build_impostor`). The foliage shader (material id 6) draws the ragged crown, the trunk under it, the season's colour (autumn turn, bare winter twigs, dead trees just a trunk), the palette pulls and the same fog as the real leaves. The pictures stand upright on each tree's own up, so they don't tip over on the curved planet. `IMPOSTORS=0` in the environment brings the 3D far crowns back for comparison.
  - First pass: facing the camera, the pictures were lit from behind when you looked away from the sun, a dark band against the haze. Now they're lit like a crown's top.
- **Only the nearest ring's plants cast shadows** (`TerrainChunk.plant_shadow`): the hero chunks within 120 m. Shadows reach only 50 m (look `shadow_max_m`), so farther trees never drew one; they just cost the shadow pass.
- **Measured** (full planet, the camp, `perf_bench` on this machine's software GPU, so compare as ratios):
  - Frame 19.4 s → 17.4 s (−10 %).
  - Visible triangles 13.56M → 12.97M.
  - Shadow pass 17.6M → 16.0M triangles, 440 → 404 draws.
  - The rest of both is the detail ring's 3D trees (10–16k triangles each), which have to stay 3D (climbing, collisions, the look up close).
- **Next for frame time** (not done): pictures for the outer part of the detail ring too (it's chunk-sized today, so the split point is ~260 m), or fewer leaf cards on NEAR trees. On a real GPU the big cost is triangle count, which the pictures cut most at render distance 5–8.
- **climb_check** now picks a different tree near the camp from run to run: whichever tree's skeleton a worker finishes first. That surfaced three climbing weak spots that were already in the last commit, not caused by this change:
  - a leaning Athel tamarisk (W looking out along a thin 0.08–0.14 m limb climbs the trunk instead, or hops to a steep neighbouring limb);
  - a Miombo (W+D went only 13° round the trunk; the test wants 15°);
  - a Cerrado pequi (clinging to its thin trunk didn't crawl up).

  The check's "your side of the trunk" is now measured where you hold it, not at a leaning trunk's foot. Queued as the next climbing fix. `climb_lab` has `TRACE=out`.
- `dev_view`: `VISTA_M=` sets the vista camera's height (150 m to look over the canopy).

## 2026-09-29 — The 4,000 km planet had no forests: geography laid out at 400 km again, built 10x
- **Found while testing the render distance:** after the 1/10-Earth lock, seed 42's full planet had no rainforest, deciduous, taiga, grassland or scrub. It was all desert (25 %), tundra, alpine and coast (53 % of land), and the camp spawned in hot desert with no trees (`tech_check` and `climb_check`: "no tree near the camp"). The stamp had lost every forest band too.
- **Cause:** the geography (continent, belt and ridge noise; hotspots; the weather grid; the passes' distances and slopes) is sampled in geographic metres with fixed wavelengths tuned on the 400 km planet. With `GEO_CIRCUMFERENCE_M` at 4,000 km, the same noise drew ten times as many continents a tenth the size: an archipelago with no interiors, so no moisture gradients and no forest.
- **Fix (code):** `PlanetConst.GEO_CIRCUMFERENCE_M` is 400 km again, the layout the geography was tuned on. The 4,000 km planet is built as a 10x sideways scale model of it (`GEO_SCALE` 10), just as the stamp is a 0.1x one. Heights are unchanged, and everything at walking scale is real size.
- **Result** (`biome_scale`, seeds 42 and 7):
  - Every band is back in the old proportions (rainforest 8–11 %, deciduous 12 %, desert 17–23 %, coast 18 %).
  - Regions are 10x wider: the largest are 45–370 km across, and a straight walk stays 10–43 km in one biome.
  - Every band has a region of at least 1,600 km² on both seeds. That covers Mike's "biomes change too fast" and "a continent of every biome" on the full planet (#89); only the grow pass for tiny bands remains, and it isn't needed on these seeds.
- **For the designer:** "landmass at 1/10 Earth" now means continents 10x the old ones, not 10x as many. Per-km feature density (oases, lagoons, rivers) is the old planet's divided by 100 in area, as your note expected. If you wanted more, smaller continents, that's a new noise scale to choose, not this constant.
- **Tools:** `STAMP=1` / `STAMP=0` in the environment overrides `dev.json` (`World`), so the dev checks can run on the stamp while play is on the full planet.

## 2026-09-29 — Render distance setting (Mike: "view distance similar to Minecraft")
- **Settings panel (O / F10) → Display → Render distance, 1–8 chunks** (260 m each; `display.render_chunks`, default 3, the distance the look was tuned at):
  - Click the left half of the row for fewer chunks, the right half for more. The row shows the reach in metres (1: ~400 m, 3: ~920 m, 5: ~1.45 km, 8: ~2.2 km).
  - It changes live: the chunk manager picks it up on its next update (`ChunkManager.render_chunks()`; `RENDER_CHUNKS=` overrides it for tools).
- **The day haze follows it** (`ChunkManager.fog_scale()`), so the ring's edge always fades out: the tuned density at 3 chunks, thinner farther (×0.64 at 5, ×0.54 at 6: you see farther, like Minecraft), thicker nearer (×2.33 at 1). Night, storm and cloud-forest fog add on as before.
  - **Flag for the designer:** above 3 chunks this thins §AG's retro haze ("far hills flat blue-purple by ~300–400 m") on purpose. If the look must hold, the far settings can keep the tuned haze and only help from hilltops.
- **Only the render distance is drawn:** chunks kept one ring past it (so stepping back and forth doesn't reload them) are now hidden, not drawn. That saves draws at every setting.
- **Cost:** each chunk's trees take about 1.5 s of worker time to place, so a bigger ring fills in over time as you arrive (5 chunks: 123 chunks, about 50 s to fill here on 4 slow cores). Walking, only the new edge loads.
- **Fix after the 4,000 km planet (for the designer):**
  - `TerrainChunk.CHUNK_M` was derived from `FULL_CIRCUMFERENCE_M`, so the 1/10-Earth lock made every chunk 2.6 km across instead of 260 m. That meant 81 m ground quads, a render ring 9 km out, and a tree placement grid ten times coarser. On the stamp it meant 4 chunks per face edge.
  - It is now the fixed 260.4 m walking scale; the chunk count follows the planet (3,840 per face edge on the full planet).
  - Streaming cost is unchanged from before the lock, as the note there says: the render check on the full planet draws 49 / 123 / 13 chunks at 3 / 5 / 1.
  - Still following the planet size: `FarShell`'s 96 quads per face edge are now ~10 km each (were ~1 km), so distant mountains are much coarser. Raising it is a cost trade for later.
- `tools/render_distance_check.gd` (new): switches the setting live (3 → 5 → 1 → 3) from the camp. Drawn chunks go 51 / 123 / 9, and the haze follows. 2/0.
## 2026-09-29 — Archetype pass over every plant (Mike: "make each plant more archetypal to what it really looks like")
- Six parallel botanist passes re-checked all 1,224 entries' `leaf`, `canopy`, `bark`, `architecture` and `tint` against the real species (Kew POWO / floras / the genus table in TREE_ARCHITECTURE.md §5), within the locked vocabulary; `plant_schema_check` 0 errors. Every entry now carries a `silhouette` line (PLANT_SCHEMA §4a2): what it looks like from 60 m, the 64 px target.
- Biggest corrections: coconut and nipa palms had grass-blade `strap` leaves → pinnate fronds 4–9 m; all 64 cannabis landraces were on the forking (leeuwenberg) model → monopodial (attims), with distinct broad-leaf (dense conical), narrow-leaf, hemp (unbranched poles) and ruderal forms; 14 Trichocereus were single columns → clumps from the base, two → candelabra trees; Scots pine (taiga, dunes, pine) → flat-topped umbrella crown on a bare orange trunk; cottonwood → excurrent with a high fork; treeline lodgepole → a 2–10 m wind-flagged multi-stem; kauri → opposite leaves, decurrent crown of huge limbs; yellow paloverde bark → green_stem; solitary palms (assai, fishtail, wild date) → corner model; octopus bush → candelabra umbrella; Brugmansia/Datura stems → smooth / green; balsam fir needles → distichous; diamond willow bark → diamond; Sitka spruce → low buttress; black spruce → sparse clubbed spire; cordgrasses → winter die-back.
- Left for the designer: larch/tamarack needle tufts are capped by the schema's `fascicle` ≤ 8 (they're 15–40); forbs carry the engine `shape: "grass"` by convention; the quiver tree has no `architecture` block though its forked trunk is its whole silhouette; duplicate entries across biome files (baobab ×2 in savanna, umbrella thorn in three files) were made consistent, not merged; palm fronds are encoded as `strap` segments per the schema — flag if the engine wants `frond`.

## 2026-09-29 — Real planet on; dapple mode switch (Mike, from chat)
- `data/dev.json` `postage_stamp` is now **false**: play is on the full 4,000 km planet. The stamp settings stay for the dev checks (`postage_stamp: true` brings it back).
- `data/look.json` `dapple.mode`: `stamped` (the §AJ 3 cluster shade map, default) or `disc` (no map: every tree casts the baked feathered crown disc with the shader's sun flecks). Mike: the shade doesn't need to be mapped to exactly where the light comes through the canopy — "the shade goes here with some dappling in it" is enough — so if the stamped map ever costs frame time, flip to `disc` rather than optimising it. Today it's ~52 ms per chunk on the worker, so it's left on.

## 2026-09-29 — Planet size locked at 1/10 Earth in the code (Mike, from chat)
- `PlanetConst.FULL_CIRCUMFERENCE_M` 400 km → **4,000 km**, so landmass, height (`HEIGHT_SCALE` 0.1, unchanged) and time (the 144-min day, unchanged) share the one 1/10 ratio design §I locked on the 27th. The dev postage stamp (`data/dev.json`, 40 km) is untouched and still on; turn it off to play the full planet.
- What changes on the full planet: the 96-cell blueprint's cells are now ~7 km (were ~1 km), so rivers, lake edges and biome borders are decided at 7 km steps and detailed by noise in the chunk; small features (oases, hot springs, lagoons) are sparser per km. Generation cost is the same (fixed cell count); streaming cost is unchanged (view distance, not planet size).
- Follow-ups: the smallest-band grow pass (every seed gets a continent of every biome); check `tools/biome_scale.gd` numbers at the new size; sparse ledger storage for the 100× area (spec D3). Docs updated: DESIGN.md overview, README, WORLD_SYSTEMS_SPEC.

## 2026-09-29 — Mike's play notes: astride in trees, a still cling, the zenith, your own arrows
- **Always astride in a tree** (Mike: "always straddle, no hanging"):
  - The hang pose is gone. On any limb, thick or thin, level or not, you sit astride it; on the trunk and steep wood you hug it as before.
  - A/D on a limb now leans you round it astride, up to about 57° either side (`TreeClimb.ROUND_MAX` 1 radian), with your hands going round with you. It no longer takes you under it.
  - **Contradiction flagged:** Mike asked earlier to go "however you want" round a limb. Leaning astride is how I've squared the two.
  - **S on a limb** always goes back along it toward where it grows from, hand over hand, whichever way you look. By the look it could send you out to a thin tip, where the hands swapped the same two holds for ever.
  - Any reach that would put the hands back on the grip they had two reaches ago now counts as nothing that way, so the ways on (down whatever goes down, back along the limb) take over.
  - `climb_lab` 68/0 and `climb_check` 0 fails. The round-limb tests now expect "leans round, always astride".
- **A still cling** (Mike: "only the cloak in the wind and the head looking round should move"):
  - A new `cling` body pose: tucked, feet braced on the face, hands up on it.
  - The torso no longer turns after the look, the feet don't step when you crawl, and the lean with speed and the stride are off. The head turns with the look (up to `head_max_deg`), and the cloak still simulates.
- **Looking straight up** (Mike: the clouds and sky "come to a convergence"):
  - The painted cloud panorama is wrapped round the sky by compass bearing and height, so at the zenith all its columns met at one point. Both of its layers now fade out between 25° and 50° up (from 50–77°, the streaks between still pointed at the zenith). Overhead belongs to the weather's flat cloud decks (`CloudLayers`), which don't pinch.
  - It was the cloud wrap, not the field of view.
  - `dev_view` gained `PITCH=` (first person, or tipping the vista camera up) to render it. Straight up now shows only the soft weather decks; the painted banks at the horizon are unchanged.
- **Your own arrows can hit you** (Mike):
  - An arrow ignores you only for its first 0.4 s, while it leaves the bow. After that, one coming back down on you hurts like any other hit (by its speed), glances off and drops.
  - `play_fixes` gained a test: one of yours falling from 12 m onto you.

## 2026-09-29 — §AJ + §AL canopy on the skeleton; Mike's play notes (jump, text, HUD)
- **§AJ + §AL canopy** (the tree/plant build, step 3):
  - **No hull at any LOD:** leaves are cluster cards on order-3+ twigs, and each card keeps its mass tile's holes (cut to `canopy.gap`), so sky shows through every card. Near (25 m), cluster cards show the leaf cutout at the leaf's real size. Far: every third cluster at 1.9×, over the order-1/2 lines.
  - **Clusters sized to the see-through test:** the anchors are placed first, then all clusters are scaled together until the share of sky seen looking straight up from under the crown equals the species' `canopy.gap` (a 24×24 raster from below; each cluster passes `gap` of the light and overlaps multiply). By the cluster spheres, a paper birch reads 0.36 against its 0.45 gap (`tools/cover_check.gd`).
  - **Real-tree fixes from the renders** (Mike: "just make it look like the trees do in real life but stylistically"):
    - the twig and anchor budgets were spent from the bottom up and left a spruce's top half bare, so both are now shuffled over the crown, and top whorls always exist, making a spire to the leader;
    - palm fronds arch, older ones more, with leaflets hanging in a V under the rachis.
  - **Wind (§AJ 5, §AL 5):** each twig has its own sway phase, carried on its wood (CUSTOM0.w) and on its clusters (UV2.y), so the gaps open and close with the twig.
  - **Dappled ground shade (§AJ 3):** `CanopyDapple` is new.
    - Each branchy tree's clusters are seen from above and stamped (a 32 px stamp per layout, turned in quarter turns to the tree's yaw, scaled and moved by the lean) into a 512² shade map per chunk (about 0.5 m texels), which the terrain shader samples by UV. The map wobbles a little in the wind.
    - Branchy trees are left out of the old disc bake; other trees keep the disc.
    - Cost: 52 ms per chunk on the worker, against 1,564 ms of plant placement (`tools/chunk_time.gd` now times prepare and shade); 28 of 36 camp chunks have a map.
    - With the shadow map on, the near clusters cast real shadows and the map fills in beyond `leaf_shadow_m`.
  - **Tools:**
    - `species_row`: UP=1 (under the first tree, looking up), PERCH=<creature> (sits it on a limb in the crown), SIDE_M=x (looks at the perch level), ANCHORS=1 (the §AL debug view: a dot at every anchor).
    - `measure_look.py` prints the sky share.
  - Reference still has: shrubs are still hull lumps (not skeleton plants); no baked far impostor (the far mesh is fewer, bigger cards with holes); the rendered dev checks (a) winter row with anchors and (b) birch look-up and perch are rendering now and get their own entry.
- **§AM leaves are cover, not walls** (step 4):
  - **Colliders:** trees already collided only on their wood; there was no crown collider left to remove.
  - **Arrows and the spear** (`FoliageCover.clusters_on`): each leaf cluster on the way takes `combat.foliage_drag` (5 %) of the speed and rustles its tree; wood stops them as before.
  - **Creature sight:** when you're in or under a crown, the clusters round you are looked up (four times a second). Each animal's line of sight to you loses `gap` per cluster it crosses, and that cuts the seeing part of its flight distance; noise still carries.
  - **Height counts:** creatures now add your height above the ground to how far off you are (before, a fox under your tree counted you as 0 m away).
  - **`tools/cover_check.gd` (new) passes 7/0:**
    - a still player on an oak limb inside the crown is seen from the side 13 % of the time and from right below 30 %;
    - an Arctic fox notices a still player at 1.4 m hidden, against 7.5 m in the open;
    - three clusters take 14 % of an arrow's speed.
  - **Wood colliders (§AM 1, 5):**
    - Orders 1–2 get capsules down to 3 cm thick (before, only limbs of 10 cm and up, so an oak had 8; now 116, within the 60 m graph ring).
    - Order-3 twigs of 4 cm and up get their own capsules, only within 30 m (dropped past 35 m). An 18 m oak has none that thick; a 40 m one has 61.
    - Palm fronds get none (`tree_check` 16/0).
  - Reference still has: the in-game dev check (c) with a fox and a thrown spear.
- **Big main branches, perch and duck anywhere, shorter people** (Mike, from play):
  - **Scaffold limbs:** broad crowns (not a single leader, not whorls; oak, beech, maple and the like) now stand on 5–8 big main limbs per stem. They leave the stem at 62–78 % of its thickness, taper to 45 % and are 10 % longer; twigs and leaves fill out from them.
    - Broadleaf trunks are stouter (height over foot diameter 22, was 28).
    - An open oak now has 11 main limbs (was 28), and 45 of its limb handholds are thick and flat enough to straddle (was 0).
    - Palms keep full-size leaflets (the gap fitting shrank them).
  - **Straddling** starts at 8 cm radius (was 15).
  - **Shift in a tree** perches or ducks at any hold: on a limb or branch you sit on top of it; on the trunk or steep wood you tuck in against it, pinned where you are. Your hands are free (bow, spear, pole), the stick takes hold again and Space jumps off. The prompt says "Shift perch" or "Shift duck".
  - **Heights:** the player is 1.35 m (`player_scale` 0.86, was 0.92), and every cloaked figure (the elder, the hunter, camp folk, wanderers, small folk) is 6 % shorter (`body.folk_scale` 0.94). The first-person eye is capped at 0.93 of the body's height (1.26 m). **Flag for the designer:** §AG 7's 1.4 m eye no longer fits the body.
  - `tools/climb_check.gd` (new): up a branchy tree from the foot, duck on the trunk and draw the bow, out onto a limb and perch on top, back down.
  - **Climbing stalled at forks** (`climb_check`, a 26 m miombo: W stopped at the fork 6 m up). The trunk's handholds end there and the stems count as limbs, taken only if you look out along one. Now pushing up on the trunk with nothing that way carries on up whatever climbs most steeply within reach (stem or limb, any side), and steep wood climbs like the trunk.
  - **Legs on the tree, not dangling** (Mike): `PlayerBody.climb_pose`.
    - Trunk or steep wood: knees up, feet braced on the bark, one stepping up every 35 cm of travel.
    - On a limb or perched on top: astride it.
    - Under thin wood: knees drawn up.
    - Ducked against the trunk: the trunk pose.
    - The cloak still covers most of it.
  - **Diagonals** (Mike): on steep wood, W+D (and the other three pairs) reaches up or down and swings round the wood toward that side in the same move.
  - **Go round any limb you can climb** (Mike): on a limb, A/D take you round it: astride on top, hugging its side, hanging under it. You keep that side as you shimmy along; W/S still go along it or across to another limb. Shift sits on top or tucks in against the side. Steep wood and the trunk went round already.
  - **Cling, crawl, leap** (Mike: "cling with right click, move with WASD, release right click to jump toward where you're looking, hold again at the right time to cling to the next surface"):
    - Right click on the ground facing a wall, rock or trunk within 0.9 m grabs on.
    - While clinging, WASD crawls over the face at 1.6 m/s (up, down and round a trunk, following its curve).
    - No slip-down (Mike): a cling holds still when you don't move and lasts as long as you hold right click (`cling_slide_mps` 0; `cling_hold_s` 0 means no limit).
    - Letting go leaps toward the look, as steep as you look (12–80° above level).
    - Pressing right click up to 14 frames before meeting the next face, and holding it, clings there on arrival.
    - The tap wall jump is unchanged.
- **Climbing that works on every tree (Mike: "doesn't always work")**:
  - `tools/climb_lab.gd` (new) drives the climber on the branch graphs of 8 species × 2 layouts (open and forest-grown), offline, in seconds, the camera held still while the stick is, as in play:
    - W from the foot into the crown;
    - S all the way down;
    - W+D from halfway up the trunk;
    - out along a thick limb and round it.
  - It found, and these are fixed (68/0 now):
    - **S stuck on every tree** (from a few metres up to the top): backing off the trunk points "out", so S reached out and round instead of down, or swung a hand round a thin trunk and back for ever. S is now down the wood; "looking out along a limb" needs W or A/D.
    - **W stopped at forks** when the hand that looked higher was on the trunk below the fork (the stem above isn't linked to it). The way on up is now searched from both hands.
    - **Self-pruned stubs were labelled trunk** (a forest Scots pine stopped 1.3 m up, holding a stub). Stubs now get their own limb number.
    - **Grip:** wood you can hold is now 4.5 cm radius, a 9 cm pole (was 6 cm). Forest-grown birch stems and the top few metres of most trunks were out of bounds, and climbs stopped 2–3 m up. Every tree now climbs to within about 3 m of its top.
    - **W+D:** each reach swings about 0.3 m round for its 0.5 m up. Bigger swings overshot the side you steer to and swung back. Round a thin trunk, the sideways part let a hand step down, so W and W+D never step down steep wood (nor S up). Diagonals spiral and don't wander off onto limbs.
    - **S on a limb** with nothing that way (looking across it) goes down whatever goes down, else back along the limb toward where it grows from.
    - **Out at a limb's end,** W no longer takes you back up the trunk above.
  - **Right click at a trunk from the ground** now works:
    - the hop onto the face puts you against it (the ray met it up to 0.9 m off, and the cling lost the face on its first move);
    - crawling up from just off the ground no longer counts as landing, and a cling rides out 8 frames without touching the face (going up a trunk, the flared foot's collider gives way to the narrower one above, and the cling let go 0.3 m up);
    - left alone the cling holds dead still (it slid 0.2 m a second round a trunk).
  - **Tests:**
    - `climb_check` passes 0 fails in the world. Its look-up helper set the yaw instead of the pitch, so the "leap toward the look" test leapt sideways.
    - `play_fixes`: the trunk wall-jump test starts 2.2 m up (with the snappier fall it reached the trunk at the ground), and the fast-fall test holds jump (a tap is only a 0.3 m hop).
    - `play_fixes` is at 1 fail, the air shot at the deer, which is on its known-intermittent list. Now the shot is taken on the ground at full draw, with the crosshair 0.3 m from the deer, and it still missed on the last run. Not chased further.
    - `tech_check` 0 fails, `tree_check` 0 fails. tech_check crashed once on an engine thread error after the wake test; it didn't repeat.
  - **Renders (dev checks):**
    - (a) The winter row with anchor dots shows every anchor on a twig.
    - (b) Birch look-up and side views; a raccoon perches 9.2 m up.
    - (d) Autumn, days 150 / 158 / 166 / 175: the row goes red and orange, dulls, and by 175 has 58 % of its leaves, each tree on its own day. A paper birch alone on day 175 is yellow and nearly bare.
    - The species row re-rendered: the coconut palm has its arching frond crown back, and the oak and beech stand on big main limbs.
    - The HUD shot: the opening controls hint no longer covers the Elder's first line or the bow line.
  - **Waking after a death:** the ruin whose fire you wake at, and its camp, are built before you wake. They came in a ruin a frame, and you could wake with no fire yet (tech_check found it 7.5 km from where you fell).
- **§AI.1 revised: each tree turns on its own clock** (step 5 of the tree build):
  - The foliage shader now runs the `autumn_colour` clock per tree and per cluster. LeafSeason publishes where the year is (days since the spring and autumn transitions) and the stage table as globals.
  - Each deciduous tree is offset by its own seeded day (± `jitter_days`, seeded by its turn and lean, which the floating origin never changes). Its top and outer clusters run up to `cluster_lead_days` ahead, so a tree turns from the outside in.
  - Colour: green → yellow-green (hue drifting toward the autumn colour by `hue_toward_autumn`) → peak → dull (`sat` 0.6, `val` 0.8). Each cluster drops from the dull stage on (24 days at 6 %).
  - Spring: buds (darker and greyer, clusters small) → young pale leaves (brighter, hue shifted toward yellow) → full, over `spring_days`.
  - Gusts still strip on top (the material's `leaf_season`).
  - `litter_check` 23/0: a hillside of 30 trees turns over 4.5 weeks, each tree on its own day, spread over 13 days.
  - Reference still has: the rendered run of days 130–200 (queued) and dev check (d) through one autumn. Falling leaves and litter still follow the mean clock, not each tree's.
- **Jump and gravity (Mike, from play: "jumps way too high and floaty; gravity more consistent and snappier; can't jump as high"):**
  - Rising gravity went from 1.9 to 26 m/s² (falling stays 28), and take-off from 7.6 to 9.7 m/s.
  - A held jump now peaks about 1.8 m up with 0.73 s in the air (it was about 15 m); a sprint jump about 2.3 m; a tap about 0.3 m.
  - `play_fixes_check` now expects a tap hop under 0.6 m and a sprint bound about 7 m out, under 3 m up.
  - **Flag for the designer:** this replaces §J's "long lazy rise, shark-fin arc" (the asymmetry is now slight). §J and the `air` `_help` need the new numbers; I updated `_help`.
- **Legible text (Mike: "make sure the text is actually legible"):**
  - The HUD font is now VT323, a DEC terminal face under the SIL OFL (`assets/fonts/vt323.ttf`, with its license), drawn with no antialiasing or hinting.
  - Every size snaps to its pixel grid (`HudText.px()`: 20 px body, 40 headings; `hud.json text.crisp_px`), so no glyph falls between pixels at 480 lines.
  - The typewriter face at 9–11 px, antialiased and then upscaled, was mush.
  - Inventory rows went from 22 to 24 px, and the settings panel was rebuilt at the new size.
- **HUD you choose:** the settings panel (O / F10) now switches every HUD element: speedometer, clock, health bar, weapon, crosshair dot, names, damage numbers, prompts and subtitles. All are on by default.
- **Orchid names up the trees:** plants other than trees (epiphytes, orchids on limbs) are now named within reach of your body, height included. You read an orchid by climbing up to it, not from the ground under it. Trees keep the along-the-ground reach.
- `dev_view`: SETTINGS=1 opens the panel; LOOK_NAME="binomial|common name" puts a name under the crosshair.
- **Biomes change too fast (Mike): measured, proposal, not changed yet.** `tools/biome_scale.gd` (new) walks straight lines over the land of seeds 42, 7 and 1234.
  - **The dev postage stamp is the cause.** `data/dev.json` generates a 40 km planet (`postage_stamp`, every band squeezed in with `min_cells_per_band` 3), and the game opens in it.
    - There a straight walk leaves a biome after 0.2–0.5 km (2–5 minutes' walk).
    - The largest region of any band is 1–13 km², and no band has a 25 km² region on any seed.
  - **On the full 400 km planet**, a straight walk stays 1–6 km in a biome.
    - The largest regions are 16–40 km across (desert 30–41 km, rainforest 19–28 km, deciduous 17–32 km).
    - Every band has a region of 25 km² or more on seed 1234. On seeds 42 and 7, woodland/shrubland (Mediterranean scrub, sagebrush) is the one exception (largest 21 and 16 km²).
    - Temperate grassland is small everywhere (largest 85–164 km²).
  - The full planet generates in 8 s against the stamp's 4 s.
  - **Proposal (for Mike and the designer):**
    1. Play the full planet: `postage_stamp` false for play, the stamp kept for tests.
    2. For "a continent of every biome on every seed": a check after generation that grows the smallest bands (woodland/shrubland, grassland) toward a region of at least N km², by nudging the climate where the band already is.
  - Not done without a yes: the stamp is the designer's dev setting.
- **For the designer (data; Mike's requests from play, not built):**
  - **Fish and reptiles.** Already in the data: mahi-mahi (dolphinfish, *Coryphaena hippurus*), grouper (*Epinephelus marginatus*), red-bellied piranha (*Pygocentrus nattereri*), electric eel (*Electrophorus electricus*), Nile and saltwater crocodiles (*Crocodylus niloticus*, *C. porosus*). Missing:
    - redfish (red drum, *Sciaenops ocellatus*);
    - alewife (*Alosa pseudoharengus*);
    - a flounder (summer flounder, *Paralichthys dentatus*, or the European *Platichthys flesus*);
    - golden dorado (*Salminus brasiliensis*), the river "dorado", if Mike meant that one rather than mahi-mahi.
    - Fish don't spawn in the world until Phase 7, so these are data only for now.
  - **Sonoran Desert toad** (*Incilius alvarius*; it was *Bufo alvarius*). Mike wants to milk its parotoid glands and smoke the dried secretion, which holds 5-MeO-DMT and bufotenine. That needs a creature entry, an interact action on the toad, an item, and the effect under Phase 10's `player.haze`. Only the entry is data work now.
  - **Orchids: "every orchid, epiphytic and terrestrial, with its fungus".**
    - The live list has 5 (2 ground, 3 epiphyte) and the archive has 60. Kew accepts about 28,000 species, so "every orchid" can't be taken literally. I suggest a set per realm and biome, from the archive up.
    - Each needs a `habit` of epiphytic, lithophytic or terrestrial (the tier already says most of this).
    - Each needs a fungal partner. Correction for Mike: most orchids aren't bound to one unique fungus. They germinate with broad groups: *Tulasnella*, *Ceratobasidium* and *Serendipita* for most green orchids, and *Russula*, *Thelephora* or *Armillaria* for the leafless mycoheterotrophs. So the field is the partner genus or group, or a species where one is known (for example *Tulasnella calospora*).
    - Climbing up to an epiphyte already names it on the HUD (common and scientific); a partner line under it is one more field once the data has it.
  - **PvP ninjas** (Mike): an idea for later, not scheduled.

## 2026-09-29 — §AK trees grown from their architecture block
- **Skeleton** (`TreeArch`, new): 149 tree-tier woody species with an `architecture` block now grow their trunk and branches from it. Cacti, bamboo, lianas, mangroves, knee-roots and shrubs keep their own builders.
  - Model programs:
    - whorls for massart / attims (a spruce has 16);
    - a golden-angle spiral for rauh;
    - sympodial zig-zag with droop for koriba / troll;
    - forks for leeuwenberg / schoute (a baobab is a candelabra of 4–6 stems);
    - a single column with fronds for corner / tomlinson / holttum palms and tree ferns.
  - Leonardo thickness: each fork splits the parent's cross-section (r_parent² = Σ r_child²). Taper follows `taper_exponent`, the foot flares, and `sinuosity` bends the wood.
  - Also from the block: `fork_height_frac`, `branch_angle_deg`, `spacing_m`, `orders` and buttress fins.
  - Dead limbs are grey, bare, and lowest on the tree. Self-pruning species leave stubs below the crown.
- **Open- vs forest-grown:** each species has 6 layouts, 3 open-grown and 3 forest-grown. The placer picks forest-grown when 2 or more hosts stand within 9 m.
  - Forest-grown trees are narrower, taller, crowned higher (`live_crown_ratio`), and carry leaves only on their top and outer face.
  - An open-grown oak's crown starts at 0.26 of its height; in a stand it starts at 0.64.
- **Lean:** downhill (the slope over 60 m) plus the prevailing wind plus a little random, up to `lean_max_deg`.
- **Leaves on twigs:** every cluster anchor lies on an order-3+ twig or a palm frond, on the outer 60 % of it; the inside of the crown is bare branchwork. Clusters are sized so the crown seen from outside is about 1 − `canopy.gap` covered.
- **LOD:**
  - Twigs are 1–2 px dark lines.
  - The far mesh keeps the order-1/2 lines under fewer, bigger clusters, never a cone.
- **Handholds** come from the skeleton (an 18 m oak has 376) and never lie on twigs. Colliders follow the wood.
- **Check:** `tools/tree_check.gd` (new) passes 13/0: anchors on wood (60,061 checked), only on twigs, Leonardo, bare dead limbs, open crown lower than forest crown, pine stubs, spruce whorls, palm fronds, handholds.
- **Dev check (a):** winter, bare, side by side: oak, beech, spruce, Scots pine, coconut palm, baobab (`species_row BARE=1`). Each is recognisable. The bare palm is a column, because its fronds are its leaves.
- The global shader-parameter buffer was raised to 262,144 (per-instance lean and season data ran out).
- Reference still has: canopy cards that are not yet cut out to the gap share per card; ground shade that is still a disc; leaf collision and cover (§AM); the full §AI.1 staged gradient.

## 2026-09-29 — §AH per-species tiles; §AI leaf fall, piles and rot (4 steps)
- **§AH tiles:**
  - `SpeciesDB` reads `atlas_species.json`: all 1,031 species get their leaf / leaf_autumn / leaves / litter / bark / petiole files. 121 mosses, air plants and conks have no bark tile and keep the class bark.
  - `PlantMeshes.material_for(sp)` gives each species its own copy of the foliage material with its tiles. Tiles are read straight from the PNGs, lazily, so only the region's species are resident. The folder is `.gdignore`'d rather than 3,900 imported resources, so an exported build would need it added as raw files.
  - The shader draws them times white and a per-plant genes jitter (warm/cool ±6 %, value ±10 %). There is no genes code yet, so the jitter comes from the instance hash.
  - Bark tiles every 0.4 m. Crowns get the foliage mass over their own shade.
  - Near cards (25 m) show the leaf cutout at the leaf's real size, in leaf cells inside the ragged cluster outline. Clumps and far cards show the mass.
  - Tile values are read raw like every vertex colour here: decoding sRGB halved them.
  - Wind is now a global (`plant_wind`).
- **§AI 1 colour and fall** (`LeafSeason`, at the player's latitude):
  - Colour blends leaf → autumn over the summer → autumn transition, and the mass is recoloured by the same share.
  - Shedding starts at `start_at` and takes `per_day_share` per game-day over `deciduous_days`; crowns are bare in winter and leaf out green over the spring transition.
  - **Revised mid-build by the designer's §AI.1 (fbde19f).** An interim wiring now follows `seasons.autumn_colour`: the colour runs on the 42-day clock from 12 days before the transition, by each stage's `blend`, and the fall starts at the `dull` stage (day 19.5 of the transition, 24 days at 6 %).
  - Not wired yet: the dull stage's sat/val, `hue_toward_autumn`, the ±7-day per-tree jitter, the 8-day cluster lead, and the bud → young → full spring stages.
  - A gust over `gust_mps` drops `gust_share` at once.
  - Crowns thin in leaf-sized cells.
  - Falling leaves are the species' leaf card, spinning and flipping, from the trees within 45 m at the rate their crowns lose leaves. They are drawn at twice the leaf's size to read at 480 lines, and unshaded.
- **§AI 2 piles** (`LitterField`, 4 m cells fixed to the ground):
  - Mass from the crowns: deciduous 0.4 kg/m² of crown over the fall; evergreens 1.0 kg/m² × 0.3 a year.
  - It is laid within crown radius × spread, drifted downwind.
  - Depth → cm → a mound up to 0.25 m. Each cell is drawn with the dominant species' litter tile (a Texture2DArray): ragged edge, scattered when thin.
  - Rustle above 3 cm; sprinting in kicks 15 % of the top layer up as leaves.
- **§AI 3–4 rot:**
  - Stages flow first-order at `days_at_reference` × Q10 (freeze_rate below 0 °C) × moisture curve × leaf multiplier. Dry → wet-dark waits on rain.
  - The shader does the stage colour transform, the holes mask and the height, like the designer's preview.
  - Humus goes into `flora_litter_kg` (per cell `humus_at`). Nothing reads it yet (soil fertility is Phase 7).
  - Litter fungi (`substrate: litter`) fruit on stage 2–3 cells 2–5 days after rain, in season and temperature, for 5 days. They are drawn with their catalogue mesh (a rosette: there is no mushroom shape yet).
- **Checks:** `tools/litter_check.gd` (new) passes 21/0: the crown timeline, Q10/freeze/moisture, multipliers, first-order stages with mass kept, rain → wet-dark, humus. Durations (leaf shape gone / into soil):
  - tropical broadleaf 159 / 323 days;
  - temperate broadleaf 450 / 912 days;
  - boreal needles 3,590 / 7,287 days.
  - `tools/species_row.gd` (new) shows oak, maple, Scots pine and coconut palm side by side through the year. Options: RUN, DAYS, TOP, WIND, DIST, FRAMES, NO_TILES.
- **Play checks after these steps:** strike passes. tech_check crashed once with engine-internal `rb_set` errors right after its respawn teleport. It then passed 23/0 on this code, and 23/0 on the commit before §AH, so it's intermittent. It's not reproduced, so a race in the new per-species materials during a burst of new chunks isn't ruled out; watch for it.
- **Dev run** (`species_row RUN=145,330`, a temperate year, rain every 9 days):
  - green on day 150; turning on 160; 90 % shed by 170; bare by 180;
  - piles 1.4 cm deep at most (four trees 11 m apart), rotting through dry (stage 1.4 by day 212) to wet-dark (2.2 by day 330);
  - buds on day 330.
- **Flags for the designer:**
  - Tropical broadleaf loses its leaf shape in about 5 months with these `days_at_reference`; §AI 4 says weeks.
  - Morel is tagged `fruit_season: autumn`, but it fruits in spring.
  - Litter fungi are drawn with their catalogue shape (rosette).
- **Reference still has:** real mushroom forms, and litter that hides what's under it (snags, burrows: the kick doesn't expose anything yet).

---

## 2026-09-29 — §AG: the look tuned to the reference clips (steps 1–7; shadows A/B not locked)
- **1 Dither and bleed** (`post_grade`): a hard ordered dither at `retro.dither` 1.0 onto a true 5-bit grid per channel (`bits_per_channel`), bleed 0.2, grain 0.025, all at the 480-line internal frame. The header comment is fixed.
- **2 Fog** (`SkySystem`, `look.gdshaderinc`): day density `retro.fog.day_density` 0.0035, so far hills are ~65 % haze at 300 m and ~75 % at 400 m. The fog colour stays the horizon colour. Valley fog adds `height_density` below the local ground mean: `main` samples the eye and a 250 m ring every 0.5 s and sends `look_ground_m`. dev_view `VISTA=1` gives a far view.
- **3 Tiles:**
  - `Look.texture()` hands out the `assets/textures/retro` tiles (64 px, stone 128, leaves and leaf card 32). Weave and fur are still painted.
  - Terrain, foliage, ruin and model samplers are `filter_nearest_mipmap` with no anisotropy, read through `retro_tex()`, which caps the mip at `retro.max_mips` (2).
  - Repeats come from `retro.tile_m` (the `look_tile_m`/`look_tile_m2` globals).
  - The terrain's rotated second copy is gone and its far fade dropped from 0.55 to 0.2. The ground now sparkles with texels.
  - Leaf-cluster cards use the 32 px noisy cutout, mirrored and turned per cluster.
- **4 Colours:**
  - The sky is a three-stop gradient from `retro.colors` (#0810B8 / #3560D0 / #7A90E0, no white band).
  - Around sunset the whole sky takes `sunset_bands`. Night keeps §C's ultramarine.
  - The sun is an 8° soft disc (`sun_disc_deg`) with a radial falloff, #FBF486 low down. There's no bloom.
  - Water is #04087A.
  - Palette: grass darker (lit grass measures #3A6832 against the #3F6E2C target), a canopy target for crowns, olive path dirt; bark keeps the old brown.
  - The grade gets a shadow floor at `shadow_floor` #080C4A.
  - dev_view gains `SPAWN`, `SUNWARD` and `CLOUD`.
- **5 Clouds:**
  - `cloud_pano` 512×128 is drawn nearest, in two layers: far 2.2× smaller, low and hazier, 1 turn / 40 min; near 1 turn / 12 min.
  - The greyscale tile is tinted by the sky, taking the sunset bands at sunset. SkyPaint only bakes clouds when the tile is missing.
- **6 Shadows A/B (not locked):** `SkySystem.day_shadows()`: the "Sun shadows by day" setting, or DAY_SHADOWS=0/1 for tools. It defaults to look "light" shadows (on), so today's look stands until the designer picks.
  - B turns the sun's shadow map off, switches on blob shadows (`BlobShadow.set_enabled`) and darkens ground under canopy by `canopy_dark` 0.45. The top-down canopy mask in ground vertex alpha is now feathered over `canopy_feather_m` 3 m. The terrain grid is ~8 m, so vertex interpolation softens it further.
  - `perf_bench`, dev frame at 15:00, 480 lines, on llvmpipe (compare ratios): **A 2279 ms a frame** (the shadow pass ≈ 384 ms: 261 draws, 1.07M tris). **B 1833 ms, −20 %**; the shadow pass is gone and the blobs cost nothing measurable. On a GPU that's ~1.24× A's fps.
  - Forest camp mean luma: A 0.13, B 0.28 (reference 0.18–0.32).
- **7 Camera:** FOV `retro.fov_deg` 78 (aiming zooms to the same share, 67). First-person eye at `retro.eye_m` 1.4 m, crouched eye scaled to match.
- **Checks:**
  - `biome_species_check.py` HARD 0 (SOFT 131); `plant_schema_check.py` 0 errors.
  - daylight, soil, strike, super, inventory and tech pass; hits keeps its known failure.
  - play_fixes varied 10 → 3 fails across two runs on this code, and 0 with the step-7 player file reverted. That spread is its known intermittency: the eye and FOV only move the camera, and the 3-fail run hit only its usual slides and bound.
- **Reference still has:** sprawling bright meadows and paths flanked by trees (world-gen, §AG 7, Phase 9); its clouds are whiter and softer-edged than our lavender-tinted posterised tile; our camp clearings are sand, so the frame averages brighter (0.37–0.45 luma at the dev spot vs 0.18–0.32).

---

## 2026-09-28 — Step 6.5: realm gate and direct catalogue loading (design §AA)
- **Direct loading:** `SpeciesDB` reads `data/plants/*.json` after the biome files.
  - 427 catalogue species are new, giving 1031 in all.
  - A catalogue entry whose name is already a biome plant (72 old copies) only tags that plant with its realm. The copy's bands and needs stand until the designer removes the copies (§AA 1). Letting the catalogue widen them moved 31 existing plants, the camp's trees among them.
  - Catalogue `family_defaults.needs` apply to every entry in the file.
  - The catalogue README's "read directly from Phase 6" is now true.
- **The realm gate:**
  - Each biome file's association realms are read (`SpeciesDB.realms_of_biome`, `biome_hosts`).
  - A realm-tagged species grows only where the site's own realm is one of its realms **and** the site's biome has an association for that realm (or an `any` one). That is checked per site in `VegetationPlacer.weight`, with a chunk-level prefilter at the chunk's middle.
  - Catalogue entries with no `realm` yet (the 171 outside Amorphophallus, Cannabis and Trichocereus) don't grow until they're tagged. Their old biome copies keep growing as their biome files say, so nothing already in the world disappears.
- **Where the realms are (`RealmMap`; engine-side, for the designer to confirm):** the design gives no realm map for this noise-continent world, so I proposed one.
  - 9 continent-scale provinces, a warped Voronoi on the sphere. Each is one "world": New World ×2, Afro-Europe ×2, Asia ×3, Malesia–Australasia, Oceania, dealt in a seeded order.
  - Within its world, a place's realm follows its own climate and height:
    - **New World:** high (≥ 1500 m real) and tropical or southern is andes; warm or southern is neotropic; otherwise nearctic.
    - **Asia:** ≥ 2000 m is himalaya; ≥ 21 °C indomalaya; humid subtropics sino_subtropical; dry central_asia or west_asia; humid temperate east_asia_temperate; otherwise palearctic.
    - **Afro-Europe:** afrotropic (patches of madagascar in the south), west_asia, mediterranean, palearctic.
    - **Malesia–Australasia:** hot and wet is malesia, otherwise australasia.
  - Below 60° S everything is antarctic.
- **Needs:**
  - `dry_ground` is now enforced: never in a wetland biome (swamp, marshes, bog, fen, wet meadow, mangrove, estuary) nor within 8 m of water.
  - New `forest_floor`: only in a forest biome. Amorphophallus carries it through a one-line `family_defaults.needs` in `amorphophallus.json`, for the designer to confirm (§AA 4: "forest floor and gaps"). Without it, the 246 species' own bands let them into riverside desert, beach and hot-spring sites.
- **A local assemblage:** a chunk holds at most 4 species of one catalogue genus, the ones with the highest local dominance. One valley has its own handful of Amorphophallus and the next a different handful, and each site weighs a bounded list.
- **Cost:** plant placement (worker threads, 36 chunks averaged) +7 % in an Asian tropical forest (1319 → 1415 ms a chunk) and +15 % round the camp (1619 → 1862 ms), measured before the untagged entries were gated out. `tools/chunk_time.gd`; `NO_CATALOGUES=1` compares.
- **Verification** (`tools/realm_check.gd`, new): 775 chunks computed exactly as in play, stratified over 288 (biome, realm) groups; every catalogue plant tallied by its own spot. 0 violations.
  - **Amorphophallus:** 2516 placed, all on forest floors. By realm: indomalaya and malesia rainforest, jungle and dry forest, ground tier (plus 40 shrub-tier). None in the afrotropic sample.
  - **Cannabis:** 2506 placed, each landrace in its own realm on dry ground. Hindu Kush, Pamir and Chitral in Central Asian steppe and cold desert; Kashmir in Himalayan meadow; Acapulco Gold and Sinaloan in neotropic dry forest and savanna; Kerala in indomalayan jungle; the Russian hemps in palearctic taiga.
  - **Trichocereus:** 0. Its bands (8–21 °C, moisture 0.15–0.6, to 3400 m) fit no biome with an `andes` association: puna and páramo are −3–5 °C, cloud forest is wet, and cold desert and canyon (where §AA puts it) have only nearctic and central_asia associations. **Data to add: an `andes` association in cold desert, canyon or thorn scrub (Andean dry valleys).**
  - The tool prints the count of catalogue species placed per biome.
- **Checks:**
  - `biome_species_check.py` HARD 0 (SOFT 127, unchanged); `plant_schema_check.py` 0 errors; realm_check, super, strike, inventory, daylight and soil pass; hits keeps its known failure.
  - **tech_check:** its trunk picker now skips trunks that fork below 4 m or have anything in the approach or under the cling spot. A cling slides down onto a low fork and, rightly, ends there. That happened on a thin acacia once one extra shrub candidate reshuffled the camp's shrubs. It now passes.
  - **play_fixes:** varies run to run: 1 failure one run, 4 the next, from its known-intermittent list (slides, sprint jump, deer shot, bound in the open). The designer's new biome data alone gave 1 (the tree-patch walk). Its bound check now looks for a clear arc from the actual take-off point.

---

## 2026-09-28 — Step 5.5: performance pass (design §W)
- **Measured, not guessed:**
  - F2 (dev mode) shows a frame-time line: frame ms and fps, the root viewport's cpu and gpu render ms, and the shadow pass (`PerfReadout`). Godot 4.3 gives scripts no per-pass GPU timing, so the shadow pass's ms is sampled by switching the sun's shadows off for a few frames every 4 s; its draw calls and triangles come straight from the renderer.
  - `tools/perf_bench.gd` times the fixed dev frame with shadows on and off.
- **The numbers:** this container's GPU is a software rasterizer, so the ms are huge. Read them as ratios; the geometry counts don't depend on the GPU. Dev frame at 480 lines, 15:00:

  | step | frame ms | shadow pass | shadow draws / tris | visible draws / tris |
  |---|---|---|---|---|
  | baseline (after 5.4) | 3645 | 1203 ms | 633 / 2.67M | 723 / 2.34M |
  | (1) shadows | 2939 | 568 ms | 292 / 1.22M | 717 / 2.34M |
  | (2) plant ranges | 2520 | 417 ms | 288 / 1.22M | 700 / 2.13M |
  | final | 2551 | 474 ms | 292 / 1.22M | 699 / 2.12M |

  That's −30 % frame and −61 % shadow pass. At 1080 internal (what §Y replaced), 60 frames didn't finish in 15 minutes here, so the internal size was the biggest cost of all.
- **(1) Shadows** (`look.json` light):
  - 2 cascades instead of 4 (`shadow_splits`), `shadow_max_m` 90 → 50, shadow map 4096 → 2048.
  - Leaves can stop casting beyond `leaf_shadow_m` of the eye: in the shadow pass the foliage shader collapses them in the vertex stage, so they cost no raster.
  - Tried at the design's 15 m, it saved only another ~114 ms of 568 and visibly flattened the midground: crowns stopped shading each other and the trunks. It is left at 50 m, the whole shadow range, so the look is unchanged. The knob is there.
- **(2) Plants** (`look.json` "ranges", new):
  - Grasses, tussocks and reeds to 40 m; other ground cover and epiphytes to 80 m (was 300); shrubs to 150 m (had no limit, so they drew out to about 390 m).
  - A triangle census showed ground cover was 1.38M of the 3.3M triangles around the camp.
  - One undergrowth MultiMesh spans a 260 m chunk, so a node visibility range can't do this. Each plant is shrunk away by its own distance from the eye in the foliage shader (`draw_range_m` instance uniform, over the last tenth), and the node itself only culls once nothing in it can be in range.
  - Tree crowns and cards wait for Step 7 (leaf cards with the ragged impostor beyond).
- **(3) Creatures:** rigs animate only within `ranges.rig_m` (60 m); farther ones still travel but hold their pose. Posing the camp's 69 creatures dropped from 0.82 to 0.59 ms a frame. That is on top of the existing think-less-often stride for far animals.
- **(4) Render scale:** superseded by 5.4's fixed 480 lines.
- **HUD:**
  - The crosshair comes from `hud.json` reticle: arms of `size_px`/2 from `gap_px` out, `thickness_px` wide, in `color` with a dark ink edge. That is larger than before.
  - Plant and tree names (and so E samples) only show within `plant_name.reach_m` (1.2 m) of you, measured along the ground. Animals are still named to 40 m.
- **Checks:**
  - tech, super, strike, inventory (with a new name-reach line), daylight and soil pass; hits keeps its known folk-head failure.
  - play_fixes passes except the intermittent "E with nothing in reach lets go" (Step 8 retires E climbing). Its sprint-slide check is also intermittent: 0.79–1.93 m on runs of the same code, depending on where its open-ground search lands. It failed once here and passed on the re-run.
- **Not verified here:** the locked 60 fps target (design §W, updated during this step to be at the 480-line render). This container has no real GPU; the designer's F2 readout will tell.
- **Reference still has:** ragged leaf-card canopies against the sky (Step 7).

---

## 2026-09-28 — Step 5.4: 480p internal render (design §Y)
- **Fixed internal frame:**
  - The root window uses the "viewport" content scale (`scripts/core/display.gd`, from `data/look.json` "render"). The whole frame is drawn at 854×480 and upscaled to the window nearest-neighbour: the 3D, the post-grade with its grain and Bayer dither, and the HUD.
  - It replaces `scaling_3d/scale` 0.8, which has been removed from project.godot. Checked on screen: fractional upscales are hard-edged too, not filtered.
- **Integer scaling** (on by default) uses whole multiples when the window holds at least two. A 1080p screen shows exactly 2× (1708×960) with a thin black border; with it off, 2.25× fills the screen.
- **Settings** (O / F10): internal lines 480 or 720 (720 is the file's max), aspect 16:9 or 4:3 (640×480, letterboxed), and integer scaling on or off. They apply at once and are saved in `user://settings.cfg`.
- **HUD at the 480 reference:**
  - `hud.json` and combat `feedback` px are used as they are.
  - The default label size is `text.base_px` (9).
  - hud.gd and status_hud.gd constants were converted from the 720 base (×⅔, rounded).
  - The key hint was reflowed to fit 854 px.
  - The inventory screen keeps its layout numbers and is drawn through a ⅔ transform, with clicks mapped back.
  - The settings panel was redrawn at 480, and the map and collision legends were resized.
  - Window-height text scaling is gone: the upscale does it.
- **dev_view:** `SCREEN=1` also saves the window as shown on screen (the upscaled frame). `INTEGER=0` gives a fractional run. Under xvfb, fullscreen is taken as a 1920×1080 window at the screen origin, because there's no window manager to switch modes.
- **Reference still has:** ragged leaf-card canopies against the sky. At 480 lines the smooth blob crowns read even more as solid shapes (Step 7).

---

## 2026-09-28 — Session 3, Step 6: momentum and HUD (design §J, §K, §L, §R)
- **6a, HUD readouts** (`data/hud.json`; `scripts/ui/readouts.gd`):
  - A speedometer at the bottom right shows mph and km/h (m/s too in dev mode). It is faint below 6 m/s and brightens toward 33.3 m/s. Its glow goes from cold blue to warm gold as the super meter fills.
  - A watch-face clock at the top right has a 12-hour hand, a minute hand and a 24-hour outer ring. Two gold marks sit at today's dawn and dusk here (DayCycle, from latitude and season).
  - Both are on by default. O or F10 opens a small settings panel with a switch for each, saved to `user://settings.cfg`.
  - All text uses the typewriter font (`assets/fonts/typewriter.ttf`, Special Elite, Apache 2.0) and scales with the window height (project stretch mode, base 1280×720).
- **6b, asymmetric gravity** (`movement.air`):
  - The pull is 1.9 m/s² while rising and 28 m/s² while falling. The rising value was tuned from the design's 2.8 so a held sprint bound lands about 50 m out.
  - Measured: **50.2–50.7 m out, 19 m up, 5.7 s** in the air. A tap is cut by `jump_release_cut` to a hop of about 1.97 m, and the fall from it takes 0.37 s: a shark fin, not a float.
- **6c, no air steering; the body turns freely; redirect** (`movement.redirect`):
  - In the air your velocity is fixed. The body faces the look, so you can moonwalk.
  - Every contact sends the kept speed toward the look: landings, rolls, bounces, wall kicks and swing releases.
  - The share kept follows `keep_by_angle`, times `perfect_gain` for a perfect tech or `miss_scale` for a missed roll, capped at `sanity_mps`.
- **6d, branch bounce** (`movement.bounce`):
  - After a fall of at least 1 m onto anything you can stand on, press right click within 14 frames either side of touchdown. The fall speed turns into forward speed toward the look (carry 0.8, gain 1.05), and you bound again.
  - A bounce is a chain link, a super-meter perfect, and it plants the other foot.
  - Fall damage now counts only the drop below where you took off, so your own rise doesn't hurt. The bounce itself uses the whole fall.
  - A right click already spent on a wall jump, cling or catch no longer also counts as a bounce.
- **6e, alternating feet** (`movement.bounds`): every landing, bounce and wall kick plants the other foot. The torso and cloak hem lean with it (`PlayerBody.plant()`), and the camera never bobs.
- **6f, momentum in combat** (`combat.strike`, `overcharge.spear`):
  - Arrows and a thrown spear inherit your full velocity (this was already the case).
  - A spear thrust adds `(closing − 6) × 8` damage, and at 25 m/s closing it kills anything but a mythic (`Hits.strike_bonus`, `strike_kills`, `mythic`).
  - A thrust into a trunk, wall or rock at speed is an impact on you (`PlanetPlayer.thrust_impact`).
  - A super-thrown spear kills on impact (`impact_kill`) and pins what it's in: `Creature.pinned_t` holds it in place for as long as the shaft is in it.
- **Tags:** `[NOT WIRED YET]` is removed from `movement` air, redirect, bounce, bounds and super_meter, and from `combat` strike. The overcharge tag now covers only fishing; fishing is still unwired.
- **Checks:**
  - New `tools/strike_check.gd`: 6/6 pass.
  - tech_check passes. Its late-press case now waits in the air clear of the tree: on the light up-gravity you would otherwise still be rubbing the trunk, and on the ground the press is a legitimate bounce.
  - play_fixes_check has these changes:
    - new sprint-bound, bounce, foot and no-self-fall-damage checks;
    - the hop check updated to about 1.9 m;
    - "drawing slows you" became "drawing never slows you" (§N);
    - the deer shot now waits for you to land and stop, since the kick carries about 47 m.
  - super_check passes 12/12.
  - Last solo run of play_fixes_check: all pass except the intermittent "E with nothing in reach lets go". It leaves you on the tree, so the tree-patch walk after it covers 0 m. Step 8 takes E out of climbing anyway.
  - hits_check still has its known folk-head failure.
  - inventory_check's laden walk failed once (you were off the floor) and passed on the re-run.
  - daylight_check, soil_check and plant_schema_check pass.
- **Design §Y** (pushed during this step): a 480-line internal render, with HUD px sizes now given at 480. It isn't built yet, so the readouts draw at the new smaller px against the 720 base, about ⅔ size, until §Y lands.
- **Reference still has:** ragged leaf-card canopies against the sky; ours are still smooth blobs (Step 7).

---

## 2026-09-28 — Cloak colors for every other camp; the super meter and overcharge (design §S)
- **Cloaks:**
  - Every cloaked figure outside the opening camp rolls its cloak at random from `data/cloaks.json`: red, orange, yellow, green, blue, indigo, violet, magenta, pink, black, white, grey.
  - Its fringe (hem and trim) is another random color from the same list, never the cloak's own, and never the player's indigo-with-orange.
  - Seeded per camp, so a camp keeps its people.
  - The opening pair stays the designer's pick: the elder ochre yellow, the hunter madder red.
- **Super meter** (`scripts/player/super_meter.gd`; numbers in `data/movement.json` "super_meter"):
  - Perfect techs fill it: a tap wall jump in its window, a landing roll, letting go of a swing. Each perfect in the series adds more (0.04, then +0.01 per earlier link).
  - A missed or late tech ends the series; the meter keeps its fill. That covers a press after the window, a cling instead of the tap, a heavy landing without the roll, a snapped branch or an impact.
  - Landed hits on creatures add 0.06, a critical 0.12.
  - It never decays; dying empties it.
- **Overcharge** (`data/combat.json` "overcharge"):
  - With any meter, holding the bow or spear past full charge keeps charging for extra time (bow 1.2 s, spear 1.0 s).
  - Released then, it's a super shot, and the meter empties: a critical hit, ×3 damage, ×1.3 speed, falling ×1.5 less, and a red streak. The arrow also pierces the first body.
  - Released earlier, it's a normal full shot and the meter is kept.
  - The drawn arrow's tip glints red and the bow creaks when overcharged.
- **HUD:** a thin gold ring round the charge gauge shows the meter (only when it's above 2 %); the gauge fills again in red through the overcharge (`data/hud.json`).
- **Not yet:**
  - the spear's pin and impact-kill, and the fishing pole's overcharge (the pole isn't built);
  - the speedometer glow (no speedometer yet);
  - NPC shinobi meters;
  - the bounce and hop-landing perfects (those techs aren't built).
- **Checks:**
  - `tools/super_check.gd`: 12/12 pass (fill, chain bonus, cling break, early release keeps meter, super arrow with pierce/fall/red streak, no meter means no overcharge, super spear, hit and critical fill, death reset).
  - tech_check passes.
  - play_fixes_check and hits_check fail only their known, earlier failures.

---

## 2026-09-28 — Session 2, Step 5: soil as a hard spawn gate (addendum §G2)
- **Readable soil:**
  - Each point's soil class comes from the geology pass (granite, basalt, karst, sandstone, alluvium, sand, clay/peat, till: the schema's names).
  - Read it with `PlanetData.soil_at()`, which jitters the cell lookup by 0.6 of a cell (`data/soil.json`) so borders wander instead of following the grid.
  - `PlanetData.soil_name()` gives the name. The HUD shows it next to the biome, and F3 shows it too.
- **The gate:**
  - `PlantSpecies.suitability()` now checks temperature, moisture and soil class first, as co-equal gates. Outside any of them the species is 0 and never spawns. Then come the weights: the two climate bands, the soil preference within its classes, and altitude.
  - Placement reads the soil at each candidate point.
- **Species data:**
  - Existing entries name a soil preset; `data/soil.json` maps each preset to its allowed classes. For example, rich forest no longer grows on beach sand or peat bog, and sand plants grow only on sand and sandstone.
  - The schema's `"soil": {"classes": [...]}` form is read too, ready for the data fill.
  - All 640 species allow at least one class.
- **Measured** (`tools/soil_check.gd`):
  - The stamp's cells are 60 % basalt (the sea floor counts), 10 % sand, 8 % granite, 8 % alluvium, 7 % till, 5 % sandstone, 2 % karst, 0.4 % clay/peat.
  - Around the first camp, 2,369 trees are placed and none stands on a soil its species doesn't allow. Without the gate there were 2,447, so about 3 % are gone, mostly on granite.
- **No depth, fertility, drainage, pH or salinity yet** (as asked).
- **Tests:**
  - Two test fixtures relied on where trees stood, which the gate moved:
    - tech_check's catch test now picks a branch with a clear approach;
    - play_fixes_check's "E with nothing in reach lets go" now holds the look target empty (E rightly samples a plant in reach first).
  - tech_check, inventory_check and stamp_check pass.
  - play_fixes_check fails only the 2 checks from the other session's data commit (see Step 3).
- **Reference still has:** ground that shows its soil (sand, peat, scree, karst pavement read at a glance). Ours colors the ground by biome, not by soil class.

---

## 2026-09-28 — Session 2, Step 4: head-look (addendum §B)
- **One rig for everyone** (`PlayerBody`, numbers in `data/look.json` "head_look"):
  - Small turns of the look move the hood first, and the shoulders shift a fifth of that with it.
  - Past 45° the torso follows, up to 50° more.
  - Pitch tilts the hood alone within ±30°.
  - The hood catches up quickly (9/s) and the torso lags (4/s).
- **The player:** third person only. The hood follows where the camera looks, including while clinging or climbing, so a pinned figure reads as looking around. In first person it's flat (no body is drawn).
- **Folk:**
  - Every cloaked figure (camp folk, the opening pair, cloaked creatures) looks at your head when you're within 12 m (scaled by its size) and in front of it.
  - Otherwise it glances about now and then (up to 35°).
  - Seated folk turn the hood and half the torso.
- **Dev view:** `CLOSE=1` gives a close-up; `HEADLOOK=yaw,pitch` sets the wanderer's look (shot: 70° left and 10° up; the hood in profile, the torso following).
- **Checks:** tech_check passes; the wanderer's cloth numbers are unchanged.
- **Reference still has:** hand gestures and idle body language on folk. Ours only turn their heads.

---

## 2026-09-28 — Session 2, Step 3: seasons (addendum §F)
- **Calendar:**
  - Four seasons over the 365-day year: `scripts/sky/seasons.gd`, numbers in `data/seasons.json`.
  - Each season's middle sits `lag_days` (20) after its solstice or equinox.
  - A 20-day change straddles each boundary; the rest is settled. Measured at 45° N: 71 / 20 / 71 / 20 / 72 / 20 / 71 / 20 days.
  - The south runs half a year behind.
- **Temperature:**
  - `warmth` is −1 in winter, 0 in spring and autumn and +1 in summer, eased through the changes (plateaus, not a sine).
  - Times a latitude swing: about ±1.5 °C at the equator, ±15 °C at 45°, ±22 °C at the poles, damped to 45 % over open water.
- **Moisture:** a multiplier on evaporation (so on cloud and rain), by band:
  - tropics: wet summer ×1.45, dry winter ×0.55;
  - temperate: winter ×1.12, summer ×0.85;
  - polar: summer ×1.2.
- **Wired into the weather sim:**
  - Each cell relaxes toward its latitude norm plus the season's offset.
  - Evaporation is scaled by the season's moisture.
  - The day/night heating is now measured against that day's mean sunshine at that latitude, so the tilted sun doesn't double-count the season.
  - The spin-up that builds the climate maps runs season-free with the equinox sun: the maps stay annual means and world gen is unchanged (stamp_check passes).
- **For the climate code:**
  - `local_weather()` now also returns `season` (for example "Spring → Summer 40%"), `season_temp_c` and `season_moisture`.
  - F3 shows the season, the day of the season, the swing and the wetness.
- **No plant response yet.**
- **Checks:**
  - daylight_check (now with the seasons), p0_timelapse, stamp_check and tech_check pass.
  - play_fixes_check fails 2: "the shot on release hit the deer" and "drawing slows you on the ground". Both come from the other session's data commit 8d508a6 (`aim_mps` 0.75 → 8.8, arrows `inherit_velocity` 1.0, no air steering). The tests encode the old design.
- **Reference still has:** visible seasons (leaf turn, frost, thaw). Here the season exists only in the numbers until plants respond.

---

## 2026-09-28 — Session 2, Step 2: derived day/night (addendum §F)
- **Tilt:**
  - Axial tilt is 23.5° and the year is 365 game days; day of the year 0 is the northern spring equinox. Game day 0 is year day 0 (`year_start_day`); the world clock starts on day 13.6.
  - The sun's declination swings ±23.5°.
  - The moon follows the same geometry: its declination is the ecliptic's at its own place (plus its 5° inclination). At 45° N the winter full moon rides 65° high at midnight, the summer one 18°.
- **The warp is now astronomy:**
  - The sky turns at one of three speeds (night, twilight within ±10°, day), blended over 4° of sun elevation.
  - The speeds are calibrated once so the equator on an equinox gives exactly the reference 60/18/48/18.
  - Anywhere else the same speeds act on that place's sun, and the turn is scaled to still take 144 minutes.
  - Day, dusk, night and dawn therefore derive from latitude and declination.
- **Measured** (`tools/daylight_check.gd`; minutes day / dusk / night / dawn):

  | Place | Date | Daylight | Day / dusk / night / dawn (min) |
  |---|---|---|---|
  | Equator | Equinox | 14.1 h | 60 / 18 / 48 / 18 |
  | Equator | Solstice | 14.2 h | 58.5 / 19.3 / 46.8 / 19.3 |
  | 45° N | Equinox | 14.4 h | 53 / 24 / 43 / 24 |
  | 45° N | June | 16.7 h | 65 / 27 / 25 / 27 |
  | 45° N | December | 12.2 h | 32 / 29 / 55 / 29 |
  | 75° N | June | 24 h (midnight sun) | 107 / 37 / 0 / 0 |
  | 75° N | December | 0 h (polar night) | 0 / 0 / 102 / 42 |

  Twilight lingers at high latitude (48 min each at 75° on the equinox).
- **Where it's wired:**
  - `DayCycle` and `Astro` take a latitude everywhere (main, HUD, tools).
  - You still wake at the start of dusk: that hour now depends on your latitude and the date.
  - The weather heats by the tilted sun, so it has seasons on its own.
- **Dev readout (F3):** latitude, year day, the sun's declination, hours of daylight on the 24-hour clock, and today's minutes of each phase here.
- **Checks:**
  - daylight_check passes.
  - p0_timelapse passes: no jumps, the equator's phases at 59.9 / 18.1 / 47.9 / 18.1, the start-hour inverse exact at two latitudes.
  - tech_check and play_fixes_check each report 0 fails.
- **Note for photoperiod:** the reference split puts day plus twilight at 96 of 144 minutes, so the equator gets about 14 h of daylight on the game clock, not 12. Real short-day thresholds (for example cannabis at about 12 h) would never trigger in the tropics unless they are read against that.
- **Reference still has:** a deep cobalt sky with bold painted clouds by day and indigo with baked stars by night (checklist item 2). Our sky is still the old R1a gradient.

---

## 2026-09-28 — Design + data session (Claude, chat; the designer's late-night calls)
- **Design doc:** `docs/design/RECONCILIATION_2026-09-27.md` now runs Thesis + §0–V. New tonight: §I 1/10 planet with 1/10 biomes; §J momentum ceiling 120 km/h, asymmetric gravity, branch bounce, alternating feet; §K momentum in combat; §L HUD speedometer + watch-face clock; §M/§T three tools only, starting kit; §N hold-to-charge, charging never slows; §O master shinobi; §P opening/wake-up with fleeing shinobi; §Q enemy camp; §R committed air momentum + free body rotation + contact re-aim by angle; §S super meter and the super shot; §U controls/HUD text/loading screen/arrow fixes; §V folk catch arrows, diagonal movement, tree tops + perch, climb on right-click cling.
- **Data (additive, marked `[NOT WIRED YET]` where code doesn't read it):** `movement.json` air (gravity_up/down, no air steer), redirect, bounce, bounds, super_meter; `combat.json` fishing, overcharge, strike, quiver, trail_min_m, fletching_from_cloak, arrows inherit full velocity; `items.json` starting_kit, pole slot, no tool spares, stone tool gone; new `data/hud.json`.
- **Controls:** Tab (and I) inventory; mouse wheel reel_in / reel_out bound.
- **Reference maths:** `tools/reference/daylight_reference.py` + `daylight_table.csv` — tilt, sunrise by latitude, natural twilight, polar cases, the stylised 144-min clock (design §F2 explains why the warp stays), seasons, photoperiod. Claude Code's Step 2 should match it.
- **Plants:** `docs/design/PLANT_SCHEMA.md` locked; `tools/plant_schema_check.py` validates; pilot fill done by parallel agents on 7 files / 135 species (cypress, pine, acacia, trichocereus, rainforest, swamp, tallgrass prairie), all `--strict` clean.
- **Consistency audit:** a read-only agent swept README, DESIGN, spec, notes, data help and code headers against the design; fixes applied to precedence (spec now cites the design doc), scale/time, look, tools, phase numbering (design doc aligned to the spec's), Tab, climbing. Code-comment staleness (planet_const, world, planet_player, bow, camps headers) is left for Claude Code to fix as it touches those files.
- **`docs/WORKING_AGREEMENT.md`** — who owns what between the two agents, pull-before-push, additive data, docs describe the built game.
- **Open for Claude Code:** the five-step Session 2 prompt (steps 2–5) plus Step 6 (§J/§K/§L data), then §U/§V fixes: arrow trail at the apex, fletching colour, diagonal movement, tree-top handhold + perch, climb on cling, Tab, HUD scale/font, loading runner.

---

## 2026-09-28 — Session 2, Step 1: dark daylight (addendum §C, lighting model and grade only)
- **Light:**
  - The sun is the one directional light by day and casts real shadow maps (there were none before): hard-edged, with no blur and soft filtering off; 4 splits over 90 m.
  - Ambient is cut to a low, deep blue (#2448D0 at 0.42 by day), which is all a shadow gets, so shadows read deep blue: sand in shade is about (19, 19, 100) on screen.
  - Sky ambient and sky reflections are off.
  - The light's elevation is squeezed under 38° (`rake_max_deg`), so it rakes even at noon: the dev spot's 58.5° noon sun lights at 34.7°. The sun disc stays true.
  - The moon lights the night the same way.
- **Grade:** two presets, day and night, in `data/look.json`.
  - Each preset: mids down (a power curve), saturation ×1.35 day / ×1.3 night, greens toward teal, blue shadow tint, contrast and vignette.
  - The frame is graded by each preset in full and crossfaded by daylight, never one curve.
  - The environment's old saturation/contrast adjustment and the old haze veil are gone.
  - No SSAO, bloom, SSR or soft shadows.
- **Fixes along the way:**
  - Plant shaders are double-sided (for leaf cards), so trunks shadowed themselves in striped acne that no bias could fix. In the shadow pass, closed shapes (bark, crowns, culms) now cast from their far faces only.
  - Blob shadows are off (`look.light.blob_shadows`); real shadows replace them.
- **Dev viewpoint:** `tools/dev_view.gd` gives the same frame every time: seed 42 stamp, first camp, you on the fire's north side (`Encampment.fixed_side`), the camera 9 m south of the fire. It saves noon and midnight.
- **Checks:**
  - p0_timelapse passes; its light-energy limits are now a share of full strength.
  - tech_check passes.
  - play_fixes_check fails only the "wall jump out of a sprint jump" check, which failed before this change too.
- **Open:**
  - Striped shadows from leaf cards remain on some bush tops.
  - The shadow cost is unmeasured on real hardware. `look.light.shadows` false switches shadows off; `shadow_max_m` shortens them.
- **Reference still has:** ragged leaf-card canopies against the sky; ours are still smooth blobs, which the hard light now shows up.

---

## 2026-09-28 — Feel pass 2 (the designer's second play)
- **Jump:** gravity 19.6 → 28 m/s² and take-off 5.2 → 7.6 m/s: a hop is about 1.0–1.1 m high (was 0.7) with the same 0.53 s in the air, so it's higher and less floaty. Fast-fall 26 m/s. Swings keep their old rhythm (swing gravity_scale 0.7).
- **Wall jump:**
  - The window is 14 frames (was 7).
  - The kick is 11 m/s (was 7.5), about 1.5 m up even from a standstill.
  - Letting go of right click out of a cling now springs you off at 0.9 of a kick (it used to drop you). Shift drops off.
  - Only a perfect tap chains.
- **Body:**
  - The player is 0.92 scale, about 1.44 m to the hood (movement "body" player_scale). The capsule, eyes, camera, climbing reach and your corpse scale with it.
  - Arms are 0.06 m longer (shoulder to mid-hand 0.62 m), in proportion. Folk keep their own heights.
- **Ninja run arms:**
  - The arms trail back 76° from hanging, flared 14° out, elbows bent 14°, and bob 6° with each stride.
  - They trail through jumps and ease back over 0.22 s. All of it is in movement "run_pose".
- **Climbing:**
  - About twice as fast: 4.1 m up in 2 s (was 2.1). Reach speeds are doubled, beats cut to 0.05–0.08 s, and the minimum reach time is now in data (min_reach_s 0.12).
  - A and D were reversed round the trunk. D now always goes to the camera's right, whichever way the wood's angle runs, and the arms no longer cross.
- **Bow and spear:** no aim arc before release (combat "arc" show_aim_arc false). After release, a brighter, wider streak follows the shot, and it stays visible far off.
- **First person:** nothing of your body shows (no cloak edges, hands or boots); your shadow stays. Set movement "camera" first_person_body to true to bring the hands and boots back.
- **Checks:**
  - tech_check and inventory_check pass.
  - play_fixes_check passes except "wall jump out of a sprint jump", which fails the same way on the previous commit (it depends on where creatures wander).
  - hits_check's "folk head hit reads 2x critical" also fails on the previous commit.
  - The hop and aim-arc checks now test the new design.

---

## 2026-09-28 — Design reconciliation built into Phase 1 (from docs/design/RECONCILIATION_2026-09-27.md)
- **Merged:**
  - All the reconciliation commits.
  - `data/plant-catalogues` at edd25cd: bark and leaf tiles, appearance blocks, the fish catalogue. Nothing reads these yet.
- **Time:**
  - The game is locked at 60 fps with 60 Hz physics.
  - You wake at the start of dusk: 17:00 on the 144-minute clock.
  - `data/dev.json` now plays the real 144-minute day.
- **The tech button (right click in the air):**
  - On a wall, cliff, trunk or ruin face: a tap within 7 frames of touching it is a wall jump. Chained wall jumps gain ×1.03 each, up to 4, so a chain keeps or builds speed (was −28% each).
  - Holding is a cling that lasts 2.5 s. Space out of a cling kicks off weakly and starts the chain over.
  - Near a limb, bamboo or vine: hold to catch and swing. You can hang as long as you like; let go to fly on.
  - Handholds behave per species (`data/handholds.json`): break speed, flex, snapback, how much weight they bear.
    - Green bamboo launches you (breaks at 60 m/s, snapback 0.9).
    - Dead wood cracks at a third of that.
  - Vines hang from wet, warm-country trees; on the stamp's rainforest, 7–9 of 83 trees carry 170–220 vine handholds.
- **Roll, momentum, impact:**
  - Landing roll: crouch within 5 frames of touchdown. A 10 m drop costs 0 health instead of 28 and exits at 17.5 m/s.
  - Over sprint speed, momentum carries on the ground.
  - Hitting a trunk at 22 m/s without a tech: 60 damage. With a tap: none.
- **Look:**
  - The ninja run pose.
  - One crouch pose for the squat, kick, cling and roll.
  - The first-person view never tumbles.
- **Dead wood:** 3% of trees stand dead by default (taiga 12%, badlands 18%, swamps 10%) and 15% of bamboo culms. They are bare and grey, and brittle as handholds. There is one fixed decay stage until Phase 5.
- **Death:**
  - Your body stays where you fell with all your gear, and birds circle it after 45 s.
  - You wake by the nearest camp fire with nothing. Test: 1,459 m from the body, full health, no bow.
  - E by the body takes everything back.
  - Nothing hostile hurts you within 8 m of a lit fire.
- **Cloaked folk:**
  - Tribal, marsh and northern folk, the opening camp's elder and hunter, the small folk (the goblins, renamed, with their lanterns), the Forest troll and the Marsh witch all use the player's rig and cloak, scaled.
  - Each person wears a rolled dyed-cloth palette, mostly from their tribe's family; the player's indigo and rust is never rolled.
- **Checks (headless):** tech_check 23 of 23, play_fixes_check 35 of 35, inventory_check and hits_check all pass; every script compiles.
- **Open:**
  - Bamboo shoots (a forage item) wait for Phase 10.
  - Dead wood's decomposers, cavities and residents wait for Phases 5–8.
  - Northerners' fur trim and the big folk's heavier hood aren't done.
  - The restless dead at ruins keep their bones.
  - The era texture tweaks from the reconciliation doc (`filter_nearest_mipmap`, render scale) are still open.

## 2026-09-28 — Phase 1 play session 1: the designer's eleven items fixed, ready to re-test
- **Checks:** `tools/play_fixes_check.gd` (items 1–5 and 7–9, every check passes), `tools/inventory_check.gd` (all pass), `tools/hits_check.gd` (all pass); every script compiles.
- **Tables:** every movement and weapon number now lives in `data/movement.json` and `data/combat.json` (hits, feedback and healing included), each part explained at the top of the file. Items are in `data/items.json`.
- **1. Stuck:** shrubs collide only at their woody stem. You are unstuck when wedged between two things, held off the ground (under a root) or caught on a crease of the ground. Headless: 2 minutes through the densest patch, 748 m covered, never held for a second. The creases' cause is not found yet (they happen every few seconds in a forest; freed in 0.08 s).
- **2. Speeds:** walk 5.5 m/s, sprint 8.8, sneak 0.8.
- **3. View:** first person by default; you can look straight up and down (89.9 degrees) in both views.
- **4. Tracers:** a dotted blue-white arc while drawing or raising, and a trail behind the arrow or spear. It now also stops on ground beyond the collision; a shot at 109 m landed 0.7 m from the arc's end.
- **5. E in any state:** while climbing, one hand takes a stuck spear or arrow and the other keeps the wood.
- **6. Wanderer:** short, hooded, faceless, with an ultramarine cloak and a rust hem. The cloak is cloth (swings, trails, settles, lifts in wind, lies down when crouched). First-person eye height is lowered to 1.45 m.
- **7. Feel:**
  - Standing hop: 0.52 s, 0.74 m.
  - Stop slide: 0.3 m from a walk, 1 m from a sprint, about 1.6 m when wet.
  - Turn-around: a 0.2 s skid.
  - Jump length: 3.2 m from a walk, 5.9 m from a sprint.
  - A 3 m ledge drops in 0.55 s (0.78 s at Earth's pull).
  - Fast-fall: 20 m/s.
  - Landing squat: 50 ms, or 160 ms after a big drop. Bumps no longer count as landings.
  - Fall damage goes by height, so a fast-fall never hurts.
- **8. Wall jump (right click):** off a trunk, 4 m/s away and 6.4 m/s up; the next one in a chain keeps 72% of the height. It plays a scuff that creatures hear.
- **9. Chain:** drawing no longer ends a sprint or jump; it slows you to 0.75 m/s on the ground only. The aim wanders 0.3 degrees standing and about 0 at a jump's apex. Sprint, jump, wall jump, draw in the air, hold through the landing and release all work in one input run, and the arrow killed the deer with a torso hit. Input log: forward at 0.000 s, 0.033 s up and 0.067 s held (the sprint); jump 0.767 s; wall jump 0.950 s; draw 1.000 s; release 2.367 s.
- **10. Health and hits:** a slim blue bar with a number replaces the hearts; no regeneration; resting at a fire heals. Head 2x, eye 4x and blinds, limbs lame. Rising numbers, and the X on a critical or a kill. tools/hits_check.gd passes.
- **11. Inventory (I):**
  - Worn slots: ranged, melee, amulet, rings, each with spares. Ten carry slots.
  - E on a plant takes a sample carrying its binomial (6 species taken in the test).
  - G sets a thing down; E takes it back.
  - Past six things: 8% slower each, climbing 12% slower, 15% louder.
  - The world doesn't pause while it's open.
- **Open:**
  - The bow and spear are sized for the old taller body.
  - The ground-crease cause is not found.
  - Fish and mushrooms have no source yet (stone tools are cut: three tools only, design §T).

## 2026-09-27 — Plant world restructured: merged data/plant-catalogues at 1a88bfe (data + spec)
- **Hero genera:**
  - 3–5 archetypal species each; the full lists are archived in docs/plant_archive/ (66 files, not loaded).
  - Cannabis 64, Amorphophallus 246 and Trichocereus 18 stay complete; fungi 43.
  - New catalogues: fern 16, moss 14, bucephalandra 4, cypress 5, sequoia 3, araucaria 5.
  - 24 catalogues, 499 entries.
- **Biomes rebuilt:** 52 files, 911 entries (234 `from_catalogue`); hero_species lists; traits on every entry.
- **Conflicts:** my earlier trim conflicted in 29 files; the branch's version was taken throughout.
  - Macrogonus set back to `reported` (designer ruling).
  - `leaf_density` re-applied where the species survive: holm oak, both umbrella thorns, paloverde, savanna acacia. Beech, mesquite and the dry-season deciduous tree are gone.
- **Dry run:**
  - Biome files: 0 warnings, 640 names.
  - Catalogues: 24 parse OK, no warnings beyond the 24 expected "unknown biome key".
  - 1,031 species in all; 16 landmark, 4 rheophyte.
- **Open:** 18 fern and moss names (Bracken, Resurrection fern, Sphagnum moss, Reindeer lichen…) are plain biome entries, although these families are meant to be catalogue-only. The loader folds each catalogue copy into the biome one.

## 2026-09-27 — Catalogues trimmed to the genera the designer named (data only)
- **Designer:** "keep it simple … reduce the amount of actual variety". Biome files unchanged. Catalogue entries 807 → 623.
- **Trimmed:**
  - magnolia 18→16, giant_herbs 24→18, vine 30→3, bromeliad 30→14, cycad 24→5, palms 43→8, orchid 60→9, fungi 43→15.
  - The single-genus catalogues, baobab + ginkgo, acacia (all three acacia genera) and carnivore (all 13 genera were named) are unchanged.
- **My picks where nothing was named:**
  - Palms: one genus per crown form in the shape work (doum, coconut, date palms, Washingtonia).
  - Orchids: lady's slippers and Dendrobium.
  - Bromeliads: one tank bromeliad, so the frog-tank rule has a plant.
  - Fungi: the one dung and one carcass fungus, so those pools can decay.
- **References:** removed names stripped from 37 association `catalogue` entries and 138 `special` entries; no association lost a dominant.
- **Dry run:** 0 warnings beyond the 18 "unknown biome key"; 1,166 species. stamp_check PASS.

## 2026-09-27 — Plant associations (data + spec; nothing built)
- **Merged:** `data/plant-catalogues` at 859d296. 213 plant associations across the 42 land biome files (2–8 each, cover 0.1–0.95). Every member name resolves to a loaded plant. cc70585 gives every entry a species-level binomial, so the tepui "spp." entries are fixed.
- **Spec:**
  - Phase 6: two-step placement replaces per-species placement. Per patch, choose an association by its `where` cue; lay down its members together; outsiders stay at low density. It is the R6 pre-filter; succession reads it; three new done-when lines.
  - D4: the `associations` block. R6.10 updated.
  - ⚑ Proposed: a fixed cue vocabulary for `where`, parsed at load.
- **Species readout (HUD):**
  - Tree trunks are named correctly (Acer saccharinum, Populus deltoides).
  - Small plants: the plant index builds (16,769 instances at the tepui spot), but a lookup through a Stegolepis still returns nothing. Being traced.
  - The animal test froze the squirrel, so its hitboxes never switched on. A test flaw; to redo.

## 2026-09-27 — Carnivorous plants and the tepui (the 52nd biome); data + spec, one template added
- **Merged:** `data/plants/carnivore.json` (0881fb9, 43 species) and `data/biomes/51_tepui.json` (4398f90, 16 endemics).
- **`biome_templates.gd`:** TEPUI added last (id 51, group Mountain, small), so existing ids are unchanged. Nothing classifies as it until the Phase 2 landform. This resolves 51 vs 52.
- **Dry run:** load_all "bad scripts: 0". Biome files: 0 warnings (TEPUI is a known key now), 677 entries, 574 names. Catalogues: 18 files, 807 entries, parse OK; the only warnings are the 18 expected "unknown biome key" ones. 1,342 species loaded together.
  - Carnivore clashes: Sun pitcher and Round-leaved sundew, already biome plants.
  - Trap types: pitfall 23, flypaper 16, snap 2, bladder 1, corkscrew 1.
- **stamp_check:** PASS, 48 of 51 surface templates present (Puna, Maritime forest and Tepui absent; Tepui as designed).
- **Spec:**
  - Phase 2: the tepui landform; 52 biomes resolved.
  - Phase 3: quartzite caves in tepuis.
  - D4: the carnivore block and tank_dweller.
  - Phase 6: carnivorous plants. Phase 7: they read the insect ledger. Phase 9: savanna carnivores need burns.
  - Phase 11: the tepui is the oldest land.
  - Part F: one new line.
- **Open:**
  - Three tepui entries (Cyathea spp., Cladonia spp., Navia spp.) have no species name (binomial rule).
  - No tepui mythic exists yet.

## 2026-09-27 — Merged data/plant-catalogues at 5a4ad60 (data + spec only; nothing built)
- 17 plant catalogues, 764 entries, all with binomials (adds pine, magnolia, rhododendron, citrus, cycad, baobab + ginkgo, acacia, vine, orchid, bromeliad, giant_herbs), plus `data/creatures/catalogue_dragonflies_snakes.json` (33). No conflicts; leaf densities and macrogonus `reported` intact.
- **Plant dry run** (the real loader's `_load_file`, read-only):
  - Biome files: 0 warnings, 558 names.
  - Catalogues: 17 parse OK; the only warnings are the 17 expected "unknown biome key" ones. 727 new species, 1,285 in all.
  - 36 catalogue names match biome plants and fold into them (the loader merges by name and keeps only the biome entry's data). Rattan is in both palms and vine.
- **Creature dry run** (`CreatureSpecies._from` on both files): 0 warnings, 61 creatures, 61 unique names, all with binomials. The catalogue's 33 are `"spawn": "ambient"`, not disabled; harmless while the loader reads only creatures.json, and the Phase 7 card says the loader holds them back.
- **Spec:** D4 (catalogue list, landmark, climber, camp_follower, orchid, bromeliad, growth default, venom, sound, hibernate, lifecycle, data/creatures/*.json); Phase 6 (catalogue rules, shape work, 661 + 764 pre-filter); Phase 7 (pollinator specifics, creature catalogues, snakes, dragonflies); Phase 9 (fire-adapted pines); Phase 11 (landmark trees named).
- **Open:**
  - Pollinator specifics live only in `repro.note` text; a `pollinated_by` field is proposed.
  - The 36 name clashes: which copy should win?
  - The 26 older creatures.json entries have no `trophic`.

## 2026-09-27 — Phase 1 partly signed off; plant catalogues merged; Phase 1 fixes; spec for plant groups, foraging and fungi
- **Signed off (designer):** Phase 1 for hitboxes, 3D audio, ripples, Night Rider and Pond Crawler. **Held:** player feel, until the designer has played it on the stamp (docs/HOW_TO_RUN.md).
- **Merged `data/plant-catalogues` (4021760).** All 50 surface biomes researched: 661 entries, 537 binomials, 558 names. New catalogues: yucca (55), palms (43), fungi (43), making 469 catalogue entries. Each land biome has a computed `special` list.
  - **Dry run:** 0 warnings from the biome files. Six catalogues parse OK, with only the six expected "unknown biome key" warnings.
  - **Name clashes:** 8 catalogue names match biome plants (Soapweed yucca; 7 palms). The loader folds each into the biome entry.
  - **Fungi:** they load as ordinary plants today.
  - **stamp_check:** PASS, with 48 of 50 templates present.
  - Leaf densities re-applied to the six species.
- **Phase 1 fixes:**
  - Limb climbing at about 0.3 m/s. Estimated from the reach speed, not measured: after the merge the headless climb test finds only giant trees at its spot (below).
  - The bow aims from the crosshair (`PlanetPlayer.crosshair_point()`, shared with the spear); spear test 32/32.
  - The Night Rider, Pond Crawler and gibbon sounds are on the falloff table.
  - Macrogonus is `reported`.
- **Spec:**
  - A3: evidence is play, a screenshot or a headless number; no recordings unless asked; verification under 10% of build time.
  - Phase 1 sign-off status and Phase 1.5 (the R1a batch-2 look: a dusk river and a deep night).
  - The camp rule: only new camps stay out of landmarks.
  - Phase 6: plant groups, the species pre-filter (and R6.10), palm, yucca and aroid shapes, fungi data and look.
  - Phase 7: foraging, pollination and dispersal as side effects, insects as creatures, the decay loop replacing the snag and log timers.
  - D3/D4 fields; Part F ×3.
- **Phase 2 audit done (audit only),** reported to the designer; nothing built.
- **Open:**
  - Researched heights make giant trees (teak up to 50 m, trunks up to 2.6 m in radius at chest height; a 31 m strangler fig). Climbing fails on trunks that thick: shape proportions are Phase 6, and a climbable-girth rule is wanted.
  - Mycorrhizal fungi don't name their hosts.
  - The 8 name clashes.

## 2026-09-27 — See-through crowns (designer request; Phase 1 follow-up)
- Leaves on branchy trees are now clusters on the outer third of each limb and branch (crossed alpha-cutout leaf cards per R1, lumpy, twigs fanning from branch tips on leafy species) with open air between them, instead of solid crown lobes. From below you see limbs, sky and the gibbon.
- Count and size: new table field `leaf_density` (shape defaults; set on beech, holm oak, dry-season deciduous, acacia, mesquite, paloverde) sets clusters per tree (about 8 on cypress, 12-16 on sparse species, 17-27 on leafy broadleaves). Per tree, `PlantMeshes.leaf_amount(growth, moisture)` thins and shrinks them in the shader: down to about 40% in the driest bands. Growth is a stand-in (height within the species' range) until Phase 6; the shader's `leaf_season` is the Phase 5 winter hook (1 today, so no winter effect yet).
- Ground under crowns: dappled shade (patches of shadow broken by sun flecks, weighted by each tree's leafiness) in the terrain shader, since there are no shadow maps to cast real dapples.
- Verified: load_all "bad scripts: 0"; before/after stills from the ground under the same tree with the gibbon crossing (/tmp/shots/canopy/cmp_*.png). A hero tree is about 1,000 triangles, fewer than the old lobe crowns.
- Open: the far LOD keeps the solid single crown; winter thinning waits for Phase 5; `leaf_density` on the rest of the table is a data pass if wanted.

## 2026-09-27 — Phase 1 build: all builders merged (done-when clips deferred)
- Merged the spear (Q/Y swap; tap to thrust about 2 m, hold to raise and throw at 9–24 m/s on an aimed arc; it sticks in the part it hits and rides along; E takes it back; a carcass that fades drops it), plus noise creatures hear (`NoiseEvents`: arrow 8 m, spear 12 m, thrust 5 m; grazers flee, go wary or ignore it).
- Merged climbing on branch graphs (hand over hand up the trunk, onto limbs at forks, shimmy until too thin, reach across; about 0.5 m/s on a trunk, 0.36–0.46 m/s on limbs), the gibbon on the real trees (8 m leaps, climbs to regain height, rests out of range), and the F7 dev spawn (riders → crawler → gibbon, with the reason printed when it can't).
- At the merge: arrows and the spear now hit any rig with hurt(), so the gibbon is no longer treated as a camp person, and they stick to the exact collision shape only when one body carries several parts. Spear and climbing sounds moved onto the falloff table (new rows: spear, spear_impact, climb_hand, climb_breath).
- Verified: load_all "bad scripts: 0"; momentum; spear test 32/32; climb test (2,033 hand checks, worst 2.9 cm off the wood; the engine crashes on quit after the checks pass, as seen before the merge); F7/gibbon-arrow test; stamp_check PASS.
- Deferred at the designer's request: the done-when recordings (sprint, sneaking, arrow and spear sticking, howl, climbing under the gibbon, wading rings).
- Open: limb speed is above the brief's ~0.3 m/s (slow it?); the gibbon travels inside the crowns, so it's hard to see from the ground; the bow's aim ray still starts at the camera (0.55 m off the crosshair while drawing); the elf has no elbows; damage values and the spear and climb sounds are placeholders.

## 2026-09-27 — Phase 1 build: sound merged (climbing and spear still in their copies)
- Merged so far: tree limbs + branch graph (F6), ruin/prop colliders (F4), shared creature hitboxes, momentum movement, gibbon, Night Rider, Pond Crawler, ripples. Now also every world sound in 3D (D5): one falloff table (`data/audio.json`, `Audio3D`), rain ring, thunder placed at the strike, footsteps/hurt/meteors 3D, a camp murmur when folk speak, F8 dev_howl. A headless audit finds no 2D players left.
- Verified: load_all "bad scripts: 0", momentum test, stamp_check PASS. Howl clip: about −8 dBFS at 25 m, about −25 dBFS past 100 m; the left/right balance swings +34 dB → −25 dB as the camera turns (sent).
- Still in copies: climbing + gibbon on real trees + F7; spear + projectile noise events. After them: the Phase 1 done-when clips.
- Known gaps: the Night Rider and Pond Crawler sounds are outside the falloff table; the camp murmur plays only with subtitles; the howl clip barely shows the pack (steep den).

## 2026-09-27 — Spec: life from life, Trichocereus, the ceremony (docs only, nothing built)
- Merged `data/plant-catalogues` (28f31bf): adds `data/plants/trichocereus.json` (18 torch cacti). Its amorphophallus and cannabis files are byte-identical to ours, and the READMEs are combined. All three catalogues parse cleanly (no duplicate keys; genus/species on every entry). A read-only dry run through species_db's loader takes 328 entries; the only warning is the expected "unknown biome key", which the Phase 6 loader skips.
- A2 gains **Life comes only from life** (no proximity spawning, plants in patches from parents, bare ground until a seed arrives, local extinction sticks) and **Browsing** (`cannot_be_browsed`; browsing writes `flora.age_structure`). Phases 6 and 7 cross-reference it. R3 gains goats (cold–mild and mild–warm mountains).
- Phase 6 gains the Trichocereus catalogue. The check shows today's `cactus` shape is one fixed two-armed column, so Phase 6 must add arms, clumps and a trunked form. Phase 10 gains the Trichocereus ceremony: oracle, `ceremonial` tags, `player.vision`, the tocapu lattice in #E8B84A/#A01020 (now in R1a), a reading drawn from real records, and a done-when check. D3 gains culture `ceremony`, `oracle_standing`, `guest_until` and `player.vision`; D4 gains `cannot_be_browsed`, `synonym`, `display`, `ceremonial`.
- Open: the file tags five species documented (macrogonus too) vs four in the text; validus is 4–8 m; chalaensis grows low; six entries share Kew's *E. macrogona*. Existing cacti and thorn scrub don't carry `cannot_be_browsed` yet (a data pass, when wanted).

## 2026-09-27 — Spec: R1a second reference batch; pack order (docs only, nothing built)
- R1a changes:
  - day sky zenith #0A1AE0, hard-edged white clouds, grass #4CC03A in full sun;
  - a deep-night full-blue grade toward #1B2ED8, with the old night values as the dusk end;
  - purple-magenta storm and volcanic skies (#5A1AA0 → #C030C0);
  - a rare dread red #A01020;
  - warm light tiny (one or two points per scene); snow fully blue.
  The designer's text is quoted verbatim in R1a.
- Phase 10 gains new remnant kinds (stone stairways, hung bells, a stone giant/idol gate, hollow-tree dwellings, wells, candlelit chapels) and names herb bundles hanging from rafters as the reference for the drying state.
- Phase 8 gains (d) Pack order: family packs, ranks derived from age, sex, parentage and a dominance gene; leaders choose, eat first and howl first; splits found new packs; rank is visible; killing a leader breaks the pack. D3 gains `fauna.packs`. Done-when and Part F gain a check each.
- Open: the R1a batch changes the signed-off look; the renderer is unchanged until the designer says when. The designer then attached ten stills; they're in `docs/references/batch2/`, linked from R1a.

## 2026-09-27 — Spec: plant growth stages (docs only, nothing built)
- Phase 6 Lifecycle gains growth stages:
  - trees go sprout, sapling, mature, old; herbs and shrubs go sprout, young, mature;
  - growth runs 0–1, and plant_meshes changes the silhouette per stage;
  - only old trees carry the branch graph and are climbable;
  - growth rate follows fertility, suitability and dormancy;
  - browsing holds saplings back;
  - only mature plants yield;
  - crops use the same block.
- The ledger gains `flora.age_structure` (counts per stage); biomass becomes its weighted sum; the warm start yields a real age mix. D4 gains the `growth` block.
- Done-when gains: all four stages in a forest patch; a browsed sapling never becomes a tree; a camp plot grows each dev day. Part F gains: where deer are thick, no saplings.
- Open:
  - `lifespan_years` becomes the sum of the stages (derive it?);
  - browsing needs Phase 7's herbivore counts;
  - camp plots are Phase 10 (a dev test plot until then);
  - plants germinated in play are stored as cohorts.

## 2026-09-27 — Spec v4: caves, renumbering, plant life, catalogues, binomials (docs + data pass; nothing built)
- **New Phase 3 — Caves and underground**; the old Phases 3–11 are now 4–12 (Wind 4, Seasons 5, Soil & flora 6, Ecology 7, Living populations 8, Disturbance 9, Camp life 10, Memory 11, Persistence 12). Cross-references fixed in D1, D3, the cards, R4, R5 and this log. Snags and dead wood sit on Phases 6, 7, 9 and 10 exactly as re-sent.
- **Phase 6** gains plant reproduction, lifecycle, the flora ledger (per species, sparse per region), plant genetics, `eco_sim`'s flora half, the Amorphophallus catalogue and the cannabis rules. The ledger core therefore moves up from Phase 7, which now adds fauna and cave fauna. **Phase 10** gains camps formed around remnants (set pieces unpark there) and the cannabis loop with `player.haze`. Part F gains four checks.
- **D3/D4:** new fields `cave_density`, `flora.biomass` / `seedbank` / `genome_mean` per species, `society.landmark` / `salvage` / `standing`, culture `ritual_smoke`, `player.haze`, and `scent` events. D4 adds the `data/plants` catalogues, the `repro`, `genes`, `aroid` and `cannabis` blocks, the `aroid` shape, `underground`, and the binomial rule.
- **Data:** `data/plants/amorphophallus.json` and `cannabis.json` added. Both parse cleanly (Python strict and Godot JSON, no duplicate keys). A read-only dry run through species_db's real entry loader loads 310 entries (246 as umbrella, 64 as shrub) with no warnings other than the expected "unknown biome key", which the Phase 6 loader change skips. Every existing plant (111 entries, 107 species) and creature (25) now has genus and species: 77 real plants and 30 invented, 17 real creatures and 8 invented. Tables load with no warnings; tools/stamp_check.gd passes.
- **Parked work saved:** the local-only `hold/set-pieces` branch is now `docs/parked/set-pieces.patch` (applies cleanly).
- **Open:** do the inhabited-ruin camps move out ("never inside a landmark")? Hunger, a fear vignette, oracle tribes and a torch don't exist yet. GLACIAL_TILL caves: none? 15 aroids reach 12 °C, so the mild band too. Placed items, felled trees and salvage as stored deltas.

## 2026-09-26 — Phase 0 signed off; spec patched for Phase 1 (docs only, nothing built)
- **Phase 0 — Look & Light signed off** by the designer on the dusk river shot. Current phase: **Phase 1 — Player feel, hitboxes, audio**.
- Designer's answers: stamp stays 40 km; ruins and mythicals stay on the stamp (test bed for Phases 6–10); dusk clouds fine as shot; fire trial: #FFA050 for the light on folk and props, #FFB020 core and #FF4A00 coals kept. Trial shot sent (runtime override only; the code change waits for Go).
- Spec: D1 scale note (400 km through the last phase, now Phase 12; maybe 1/10–1/30 Earth later; two-tier storage). D3 rewritten against the code: where every field lives now, a proposed home and owner for each missing one, regions as 4×4 cell blocks (~8 MB ledger on the full planet). D4 gains tree lifespans. Phase 1 card gains the branch graph, climbing, gibbon brachiation, and the ripple / Night Rider / Pond Crawler text verbatim. Phase 2 gains the memory and current checks. Snags and dead wood run across Phases 6, 7, 9 and 10 (numbers since the caves renumbering), plus R3 (woodpeckers, owls) and Part F (two checks).
- Next: Phase 1 Prompt A (audit + minimal changes), then wait for Go. The ripple, Night Rider and Pond Crawler agents are still in their copies; they get audited against the patched card before any merge.
- Open: D3 flags (sky and eased weather not on World; new `flora.cavities`; sparse storage for a 10× planet; felled/burned trees as stored deltas). Band grouping (alpine incl. páramo/puna). Ruin hash differs from the old expected value (predates this session). Earlier entries were dated 2026-09-27 by mistake; corrected to 2026-09-26.

## 2026-09-26 — Spec update: R6, Phases 6–11 (docs only, nothing built)
- Added Appendix R6 (simulation tiers and living-world rules), replaced the old Phases 6–8 with Ecology core, Living populations, and Disturbance and living water (now Phases 7, 8, 9 since the caves renumbering); Camp life gained culture (now Phase 10), Memory and lore is new (now Phase 11), Persistence gained tick_region catch-up (now Phase 12). Part F gained four checks.
- D3 gained: world.events, fauna.genome_mean, fauna.sex_ratio, soil.carcass, flora.burn_scar, terrain.water_level (seasonal), society[camp].culture, creature.memory[] (NEAR only). Owners inferred from the phase cards — designer to confirm.
- Cross-references renumbered: R4 inventory built in Phase 10; R5 out of scope until Phase 12 (numbers since the caves renumbering).
- Still in Phase 0 (awaiting sign-off). Phase 1 ripple + Night Rider + Pond Crawler agents (started on the designer's "GO") are still working in their copies; not merged.

## 2026-09-26 — Phase 0 session 2 (commits 35fdd3a → a213f49) — awaiting sign-off
- Changed: spec R1 replaced + R1a palette added; DESIGN.md matches spec (45/20/35/20, 29.5-day moon). Merged: painted sky (ultramarine night, dense stars, big moon, day #1436FF→#4C7CFF, night fog #1E30C0), flat water (no reflections, no white net, seam line fixed, rivers now flow), R1a ground/stone/fire palette with firelight pool, 1/4 ordered dither, ultramarine haze. Postage-stamp planet (40 km, every band, 3.1 s) ON in data/dev.json; full planet via "postage_stamp": false.
- Verified: tools/p0_timelapse.gd PASS, tools/stamp_check.gd PASS, gl_compatibility no shader errors. Dusk river re-shoot on the full planet: /tmp/shots/p0final_river_{12.0,17.5,18.5,23.0}.png (sent to designer).
- Flagged too clean: day clouds (airbrushed banks), camp folk/fire props/mat (flat colour), far trunks and far hills (texture fades out), mid-distance grass (low-contrast grain), pyramid faces.
- Known misses: stone at night #000963 vs #3E4C8C (night contrast crushes it); folk by fire read red not orange; moonlit snow a little blue/dim; dusk clouds hot pink across upper sky; weak waterfall crests; foliage near-black at night in Compatibility renderer.
- Next: designer sign-off on the dusk river shot, or corrections. Then Phase 1.
- Open: stamp size 40 km? ruins/mythicals on the stamp? band grouping (alpine incl. páramo/puna)? pink dusk clouds OK? warmer #FFA050 fire so folk read orange? ruin hash differs from the old expected value (predates this session's work).

## 2026-09-26 — Phase 0 session 1 (commits a87aee8, 922916b)
- Changed: post grade (dither/black crush out; slight color bleed, cool haze, faint grain; night tint kept), all world textures linear + mipmaps, 3D render scale 0.8. Day split 45/20/35/20 (day/dusk/night/dawn) with smooth sky speed, eased weather-driven light, sun→moon cloud-light crossfade, 29.5-day moon with the mansion following it. Earlier (1993da5, merged before the spec): vertex-lit Lambert, flat ambient, no glow/SSAO/SSR/shadow maps, blob shadows.
- Dev: data/dev.json (20-min day, seed 42, first camp), F3 debug overlay, tools/p0_timelapse.gd (PASS: no frame-to-frame jumps).
- Verified: time-lapse sheet + curves; river-bank shots at 12:00/17:30/18:30/19:30/23:00. Dusk shot NOT yet GameCube-disc quality: water still reflects the sky (pink swirls) and glows neon at night; cloud layers look smeared, not painted.
- Held: set pieces on local branch hold/set-pieces (spec: no new ruins). Painted skybox + flat bright water exist in stopped agent copies (both matched R1 in audit) — designer to decide whether to finish them. Carved stone + old sky: discard.
- Next: fix water (no reflections, softer night glow) and sky/clouds (painted), then re-shoot dusk by the river for sign-off.
- Open: 45/20/35/20 order confirmed? dev day also speeds weather 6x; DESIGN.md still says 15/50/15/40 + 28-day moon; postage-stamp planet not built.

## 2026-09-26 — Spec v3 adopted (aligned to commit fe6ee3e)
- Current phase: **Phase 0 — Look & Light**
- Last sign-off: none yet
- Agents in copies: restyle, set-piece — audit against Appendix R1 before merging
- Next: send Phase 0 Prompt A (spec Part C), get the audit, then "Go."
- Open questions: 51 biomes in data vs 52 in design (resolve in Phase 2)
