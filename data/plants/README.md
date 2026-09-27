# Plant catalogues

Big lists of real plants, kept apart from the biome files: one file per group
(a genus, or one species' landraces). Spec: D4 and Phase 6.

- `amorphophallus.json`: all 246 *Amorphophallus* species accepted by Kew's
  Plants of the World Online.
- `cannabis.json`: 64 landrace populations of the single species *Cannabis
  sativa*.

A catalogue is laid out like a biome file (`key`, `name`, `kind`, `status`,
`notes`, `plants` by tier), with two differences:

- It has no `climate` block. Every entry carries its own `temp_c`,
  `moisture` and `altitude_m` bands, so it grows wherever those allow,
  anywhere on the planet. Nothing is hand-placed.
- The loader ignores the `regions`, `types` and `family_defaults` keys,
  which are notes for people and for the plant lifecycle system.

Entries use the plant fields from `data/biomes/README.md`, plus the Phase 6
blocks `repro`, `genes`, `aroid` and `cannabis` (D4). Like every plant,
each entry needs `genus` and `species`. Entries that share a binomial are
one interbreeding species.

**Not loaded yet.** `species_db` starts reading this folder in Phase 6. Until
the `aroid` shape exists, the aroids use `umbrella`.
