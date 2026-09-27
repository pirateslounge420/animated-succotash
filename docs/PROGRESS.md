# PROGRESS.md — running log (newest on top)

Claude Code prepends 3–6 lines every session. The designer signs off phases here.

---

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
