# Plant catalogues

Three catalogues stay here, whole, by design (§CC, 1 Oct 2026: the catalogue is
trimmed to archetypes; `data/habitat.json → trim.keep_whole`). Every other genus
catalogue that lived here was folded into the biome files it serves (its archetypal
species copied in with their full blocks) and the file itself moved, whole, to
`docs/plant_archive/` with `git mv` — nothing is lost, it is just not loaded. The
category of every entry before the trim, and why, is in
`docs/plant_archive/TRIM_2026-10-01.md`; the entries each biome dropped are in
`docs/plant_archive/biomes/<biome file>`. The four per category were chosen from Mike's seed
list first (`docs/plant_archive/TRIM_SEED_LIST_2026-10-01.md`, 12:08): a real, native, drawable name
on it was kept and, where no file had it, added to the biome file with the full schema. A biome's
`hero_species` survive on top of the four. What each biome holds now, by category, is
`docs/plant_archive/TRIM_RESULT_2026-10-01.md` (`python3 tools/plant_trim.py result`).

Every entry carries its own `temp_c`, `moisture` and `altitude_m` bands, so a
catalogue file has no `climate` block, and a `biomes` list (design §CA): the biome
gate lets it grow only in the biomes that list names, and inside those wherever its
bands fit. Nothing is hand-placed.

`species_db` loads `data/plants/*.json` the same way it loads a biome file (spec D4 and
Phase 6). Top-level keys other than `plants` (`regions`, `types`, `family_defaults`,
`notes`) are documentation and are ignored.

| File | Contents | Extra blocks (read by the Phase 6 plant lifecycle/genetics system) |
|---|---|---|
| `amorphophallus.json` | All 246 *Amorphophallus* species accepted by Kew POWO (fetched 2026-09-26). 34 with documented traits, 212 with genus defaults and a region-based range; see each `source`. Drawn as leaf cards on one mottled petiole (`_aroid_leaf`). | `cycle` (the life cycle, researched per species: docs/design/AROID_LIFE.md), `aroid` (petiole pattern/colours, spathe colours), `repro`, `genes` |
| `cannabis.json` | 64 *Cannabis sativa* landrace populations — one species, all interbreed; each is a starting genome for its region. Attestation tagged per entry. | `cannabis` (leaf width, photoperiod flowering, uses), `repro` (dioecious, wind, annual, seed bank), `genes` |
| `trichocereus.json` | 18 *Trichocereus* Andean torch cacti, the ones the ethnobotanical literature records as ceremonially active. Kew files them under *Echinopsis*; each entry keeps that name as its `synonym`. Cold, dry, high, rocky ground; never browsed. | `growth`, `repro`, `genes`, `cannot_be_browsed`, `ceremonial` (`documented` / `reported` / `trace`, read by the ceremony system), `display` (common name) |

`python3 tools/plant_schema_check.py --strict` validates every entry's blocks and its
`biomes` list; `python3 tools/biome_species_check.py [KEY ...]` prints, per biome, the
species the gate allows by category and the grand total; `python3 tools/plant_trim.py
survivors` shows the per-biome counts against the four-per-category rule.

Every entry has `genus` and `species` (real binomials) per the D4 rule; entries
that share a binomial are one interbreeding species.
Colours are in-game R1a-leaning values, not botanical measurements.
