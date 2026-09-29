# Per-species plant tiles

Generated — do not hand-edit. `python3 tools/look/make_plant_tiles.py` rebuilds the whole
set from the catalogue's `leaf` / `bark` / `tint` / `aroid` blocks (design §AH, PLANT_SCHEMA
§0–§3, §1b). To change a plant's look, change its description in `data/plants` or
`data/biomes`, then re-run and commit.

`atlas_species.json` maps every species name to its files: `leaf` (48×48 cutout),
`leaf_autumn` (deciduous), `leaves` (32×32 tileable mass), `bark` (64×64 tileable, ~40 cm),
`petiole` (Amorphophallus, 32×128), plus `leaf_color`. Identical renders share one file.
Tiles carry the species colour; the shader multiplies by white × the genes jitter, not by
the species `color`. Nearest-filtered, ≤ 2 mips (§AG).
