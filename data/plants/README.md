# Plant catalogues

Genus- or species-level plant catalogues that are NOT tied to one biome.
Every entry carries its own `temp_c`, `moisture` and `altitude_m` bands, so a
catalogue file has no `climate` block; plants grow wherever their bands allow,
exactly like the biome files in `data/biomes/`. Nothing is hand-placed.

`species_db` loads `data/plants/*.json` the same way it loads a biome file
(spec D4 and Phase 6). Top-level keys other than `plants` (`regions`, `types`,
`family_defaults`, `notes`) are documentation and are ignored.

**Not loaded yet.** `species_db` starts reading this folder in Phase 6.

| File | Contents | Extra blocks (read by the Phase 6 plant lifecycle/genetics system; ignored until then) |
|---|---|---|
| `amorphophallus.json` | All 246 *Amorphophallus* species accepted by Kew POWO (fetched 2026-09-26). 34 with documented traits, 212 with genus defaults and a region-based range; see each `source`. `shape` is `umbrella` until the `aroid` shape exists. | `aroid` (petiole pattern/colours, spathe colours), `repro`, `genes` |
| `cannabis.json` | 64 *Cannabis sativa* landrace populations — one species, all interbreed; each is a starting genome for its region. Attestation tagged per entry. | `cannabis` (leaf width, photoperiod flowering, uses), `repro` (dioecious, wind, annual, seed bank), `genes` |
| `trichocereus.json` | 18 *Trichocereus* Andean torch cacti, the ones the ethnobotanical literature records as ceremonially active. Kew files them under *Echinopsis*; each entry keeps that name as its `synonym`. Cold, dry, high, rocky ground; never browsed. | `growth`, `repro`, `genes`, `cannot_be_browsed`, `ceremonial` (`documented` / `reported` / `trace`, read by the ceremony system), `display` (common name) |

Every entry has `genus` and `species` (real binomials) per the D4 rule; entries
that share a binomial are one interbreeding species.
Colours are in-game R1a-leaning values, not botanical measurements.
