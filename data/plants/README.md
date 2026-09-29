# Plant catalogues

Genus- or species-level plant catalogues that are NOT tied to one biome.
Every entry carries its own `temp_c`, `moisture` and `altitude_m` bands, so a
catalogue file has no `climate` block; plants grow wherever their bands allow,
exactly like the biome files in `data/biomes/`. Nothing is hand-placed.

`species_db` loads `data/plants/*.json` the same way it loads a biome file
(spec D4 and Phase 6). Top-level keys other than `plants` (`regions`, `types`,
`family_defaults`, `notes`) are documentation and are ignored.

**Loaded through the biome files:** biome plant lists copy catalogue entries
(`from_catalogue`), so catalogue species already grow in play; `species_db` reads
this folder directly from Phase 6.

**New blocks (design, 27 Sept 2026):** every entry is being given `leaf`, `canopy`,
`tint`, `photoperiod` and an object-form `soil` per `docs/design/PLANT_SCHEMA.md`;
`tools/plant_schema_check.py` validates them (`--strict` requires them). Filled so
far: cypress, pine, acacia, trichocereus, and the rainforest, swamp and tallgrass
prairie biome files. The rest are filled by parallel agents against the same schema.

| File | Contents | Extra blocks (read by the Phase 6 plant lifecycle/genetics system; ignored until then) |
|---|---|---|
| `amorphophallus.json` | All 246 *Amorphophallus* species accepted by Kew POWO (fetched 2026-09-26). 34 with documented traits, 212 with genus defaults and a region-based range; see each `source`. `shape` is `umbrella` until the `aroid` shape exists. | `cycle` (the life cycle, researched per species: docs/design/AROID_LIFE.md), `aroid` (petiole pattern/colours, spathe colours), `repro`, `genes` |
| `cannabis.json` | 64 *Cannabis sativa* landrace populations — one species, all interbreed; each is a starting genome for its region. Attestation tagged per entry. | `cannabis` (leaf width, photoperiod flowering, uses), `repro` (dioecious, wind, annual, seed bank), `genes` |
| `nightshade.json` | 3 *Datura* (upright trumpets, spiny thornapples; dry disturbed ground near camps) and 4 *Brugmansia* (small trees with hanging trumpets; Andean and tropical American stream banks). Night-scented, hawkmoth-pollinated; `toxic`, never browsed, `ceremonial` like Trichocereus. Added 2026-09-28. | `growth`, `repro`, `genes`, `toxic`, `scent`, `ceremonial` |
| `trichocereus.json` | 18 *Trichocereus* Andean torch cacti, the ones the ethnobotanical literature records as ceremonially active. Kew files them under *Echinopsis*; each entry keeps that name as its `synonym`. Cold, dry, high, rocky ground; never browsed. | `growth`, `repro`, `genes`, `cannot_be_browsed`, `ceremonial` (`documented` / `reported` / `trace`, read by the ceremony system), `display` (common name) |

Twenty-five catalogues in all (run `python3 tools/plant_schema_check.py`
for the live count). The per-file counts change as genera are trimmed to the ones the
designer named (docs/WORLD_SYSTEMS_SPEC.md D4).

Every entry has `genus` and `species` (real binomials) per the D4 rule; entries
that share a binomial are one interbreeding species.
Colours are in-game R1a-leaning values, not botanical measurements.
