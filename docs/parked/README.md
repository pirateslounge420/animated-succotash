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
