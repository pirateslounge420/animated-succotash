# PROGRESS.md — running log (newest on top)

Claude Code prepends 3–6 lines every session. The designer signs off phases here.

---

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
