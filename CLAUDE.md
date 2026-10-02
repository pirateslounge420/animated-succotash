# animated-succotash — the brief (read at the start of every session)

This repo is **the ambient open world**: a slow, first-person walk across a procedural planet
at 1/10 Earth scale. Old, overgrown roads lead between ruins and living camps; fire is carried,
never made; the dark is the only enemy; and every ruin is designed to lead down into a delve
(§CJ, not built yet). Mike Flow is the designer. He doesn't code, so explain every change in
plain English: what it reads, what it writes, what changes on screen.

## Engine
- **Godot 4.3, the standard build. GDScript only, no plugins.** Mike opens `project.godot`
  straight in the Godot editor. Plain Godot is the only engine (design 30 Sept doc §CI).
- The main scene is `scenes/main.tscn`; the autoload is `World` (`scripts/core/world.gd`). How
  Mike opens and plays the game, the walkabout command, and where this machine's headless
  Godot lives are all in `docs/HOW_TO_RUN.md`.

## Scale
1/10 Earth in everything: **4,000 km around** (radius ~637 km), **heights 1/10** (Everest
would be ~900 m), and a **144-minute day** (1/10 of a real day). The geography is laid out on a
400 km map (`PlanetConst.GEO_CIRCUMFERENCE_M`) and built ten times wider (`GEO_SCALE`). That
400 km figure is the layout, not the planet; 1/100 Earth is gone everywhere. Play runs on the
full planet. The 40 km postage stamp is only for the checks (`STAMP=1`).

## Two games
The momentum kit (wall jump, cling, swing, roll, 120 km/h chains), momentum combat, the super
meter, the starting kit, the shinobi and third person belong to a **separate ninja game**
(§AT). Their code stays here, compiling, tested and switched off behind `data/movement.json` →
`profile`: `ambient` is this game and `shinobi` is the other. Don't delete that code, don't
build on it, and don't turn it on in this game.

The weapon code is the exception. `bow.gd`, `spear.gd`, `fists.gd`, `arrow.gd` and the §N
charge rule **stay live code paths**, because the bow and the spear come back as rare finds in
ruins (§AW, §CJ).

## Sources of truth, in order
1. `docs/design/RECONCILIATION_2026-09-30.md`: the ambient cut and every decision since (§AT
   onward, newest sections at the bottom). **§BR at the end is the order of work.** It wins
   over everything below.
2. `docs/design/RECONCILIATION_2026-09-27.md`: the earlier locked design (§0–§AS), for
   whatever the 30 Sept doc doesn't touch.
3. `docs/design/LOOK_REFERENCE.md`: the look, with rules R1–R10 and the eye test, measured
   from Mike's twenty favourites (`docs/references/batch4/`). These are findings, not locked:
   where they disagree with a locked section (§BU), the locked section stands until Mike
   settles the open calls.
4. `docs/design/PLANT_SCHEMA.md` and `data/habitat.json`: plant vocabulary, and where each
   plant may grow.
5. `docs/WORLD_SYSTEMS_SPEC.md`: architecture and the phase cards, kept for reference. The
   order of work is §BR.
6. `docs/PROGRESS.md`: the log, newest on top.

Everything else (README, DESIGN.md, implementation notes, code comments) follows these. If
two of them disagree, tell Mike. Don't quietly pick one.

## The look, in short
"Almost like Minecraft, except not in boxes, and everything flows better." The era is
1999–2004 consoles.
- A 480-line internal frame with nearest-neighbour scaling, and 16 texels a metre.
- Clean silhouettes, and no normal maps or specular.
- Dark but saturated, and blue owns the frame. The sun is the one light.
- Shade goes navy (olive in green scenes), never grey. Distance gets lighter and bluer.
- Water is the brightest thing in view and fire the one warm accent. Only things that give
  off light glow.

The numbers are in LOOK_REFERENCE.md.

## How we work
@docs/WORKING_AGREEMENT.md

- **No screenshots after every step.** Mike plays on his Mac and reports back. Check a
  visual pass once, at the end, with the walkabout (§CA, `tools/walkabout.gd`). Use headless
  numbers for everything else.
- Pull with rebase before every push, and never force. Claude in chat pushes design docs and
  additive data to the same branch.
- Every design section has a letter. Cite it in commits, `_help` text and PROGRESS entries.
- At the end of a session, prepend a PROGRESS entry and keep `docs/HOW_TO_RUN.md` true to the
  game as built.
- The reference frames in `docs/references/` are third-party clips, for internal art
  direction only. Never ship them.
