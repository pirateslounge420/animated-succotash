# Parked work

Work that was set aside until a later phase, saved here so it can't be lost.
A local branch disappears when the cloud container is recycled; a file in the
repository doesn't.

- `set-pieces.patch`: the rotunda, chapel, mission and bridges set pieces
  (commit 7366634, from the local branch `hold/set-pieces`). The spec
  unparks them in Phase 10, where camps form around remnants. It applies
  cleanly to the tip of the branch as of 2026-09-27. To bring it back:
  `git am docs/parked/set-pieces.patch`, or use `git apply --3way` if the
  files have moved on since.
- `foliage_derivatives.patch`: the leaf-card shader takes its texture
  derivatives once, at the top of `fragment()`, before any branch
  (`retro_tex_g` / `retro_tile_g` in `look.gdshaderinc`; `pick2` / `pick3`
  in `foliage.gdshader`). It compiled and drew under Forward+ (lavapipe).
  Design 1 Oct §CG keeps it queued, with the F9 foliage views: it was not
  the cause of the grey boxes. It applies cleanly to the tip of the branch
  as of 2026-10-02: `git apply docs/parked/foliage_derivatives.patch`.
