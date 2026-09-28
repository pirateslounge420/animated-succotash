# tools/look — the §AG reference look, as numbers and tiles

- `make_retro_tiles.py` — generates `assets/textures/retro/` (grass, dirt, sand, bark,
  leaves, leaf_card, stone, water at `look.retro.tile_px`, plus `cloud_pano.png`
  512×128). Same mid-grey modulation convention as `LookTextures` (0.5 = no change), so
  `Look.texture(name)` can hand these out instead of painting 256 px textures at startup.
  `cloud_pano.png` keeps `sky.gdshader`'s channels (R bank, G lit, B streak).
  Deterministic by name; `--seed N` rerolls; `--preview` writes
  `docs/references/batch3/retro_tiles_preview.png`.
- `measure_look.py` — frame statistics of any screenshot against `look.retro.targets`
  (mean luma, saturation, navy-not-black shadows, grass share, dominant colours). The
  targets were measured from `docs/references/batch3/`; run it on those to see why.

Design: `docs/design/RECONCILIATION_2026-09-27.md §AG`. Data: `data/look.json retro`.
