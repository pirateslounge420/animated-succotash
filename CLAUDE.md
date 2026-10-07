# animated-succotash — the brief (read at the start of every session)

This repo is **Torchfire 1: an ambient, first-person dungeon crawler** (design §ET, 6 Oct, not
built yet). You wake underground by a lit hearth and reclaim procedurally generated ruins by
relighting them, stage by themed stage; fire is carried, never made; the dark is the only enemy;
no combat. **The stages are pocket worlds (§EW, 6 Oct, not built yet):** one bounded slice per
biome (~1–2 km, first guess) with its ruins above and its dungeon below, a day-night cycle and
ambient life; worlds join underground, show on each other's horizons, and a map fast-travels to
visited ones. **Each world's dungeon has one boss (§EY, 6 Oct, not built yet):** a creepy
mythical creature that prowls only the rooms not yet relit and is never fought; the last light
drives it back into its lair (`data/bosses.json`). **Fire fights back (§FA–§FH, 6 Oct night, not built
yet; amends "no combat"):** a little combat, all of it fire: a lit torch swung into a creature's
wind-up staggers it (never wounds), and rare fire pots, lit off your torch, burn; running, sneaking
(Shift), hiding and dousing your own torch stay the default. Each ruin kind has its residents
(`data/residents.json`) below its boss; a lit floor is cleared; three hits with a red first edge,
and a chase can follow you into the light. The wheel and Tab-and-wheel replace Q (`data/hands.json`);
the hearth folk are live 3D, not sprites (§FH). **§FJ (22:52):** torches burn down again (a timer, three at most, from the hearth's bundle; relight from any flame); the first ruin is drawn at random from the roster; the fire pot is clay. **§FK (7 Oct, not built yet):** a new game rolls one seed and every world and dungeon comes from it, unique to that playthrough and then kept for good (a save; relit and restored stay so); one 144-minute clock, the same in every world (no latitude). **The open world described below (planet, roads, ecology, weather, camp sim) is
Torchfire 2:** shelved, its code kept and switched off, not deleted (§ET.2). Where this brief
and §ET disagree, §ET wins. Mike Flow is the designer. He doesn't code, so explain every change in
plain English: what it reads, what it writes, what changes on screen.

## Engine
- **Godot 4.3, the standard build. GDScript only, no plugins.** Mike opens `project.godot`
  straight in the Godot editor. Plain Godot is the only engine (design 30 Sept doc §CI).
- The project boots `scenes/boot.tscn`, which opens the game `data/game.json` names (§ET.2, `GameMode`): Torchfire 1, the crawler (`scenes/crawler.tscn`, `scripts/crawler/`), by default; the open world (Torchfire 2) is `scenes/main.tscn`, still the scene every check in `tools/` boots. The autoload is `World` (`scripts/core/world.gd`). How
  Mike opens and plays the game, the walkabout command, and where this machine's headless
  Godot lives are all in `docs/HOW_TO_RUN.md`.

## Scale
**Torchfire 2's planet (the open world, shelved; §ET.2, §FK.1).** Torchfire 1 has no planet: bounded
pocket worlds (§EW) and one clock (§FK.3). What follows is the open world's, as built.
**1/100 Earth in distance, 1/10 in height and time** (design §CR, built 3 Oct): **400 km around**
(radius ~63.7 km, `data/world_scale.json` → `planet.circumference_m`), **heights 1/10** (an
Everest-class summit is ~885 m; `HEIGHT_SCALE` 0.1), and a **144-minute day** (1/10 of a real day).
The geography is laid out on a 400 km map (`PlanetConst.GEO_CIRCUMFERENCE_M`) and now built at its
own size (`GEO_SCALE` 1). Everything at walking scale (you, folk, creatures, plants, ruins, camps)
is true size; only the gaps between things shrank. A handful of great ranges (4–7, summits
500–885 m) keep real angles, and slopes are walked at Tobler's pace. From eye height the horizon is
~400 m on flat ground. Play runs on the full planet. The 40 km postage stamp is only for the checks
(`STAMP=1`); it has no great ranges.

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
   onward, newest sections at the bottom). **§ET.11 is the order of work for Torchfire 1**; it
   replaces §BR's queue until Mike reorders. §EW.7 and §EX.8 follow it (`docs/PROMPT_QUEUE.md` 44–48 first). It wins over everything below.
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
- **Ruin walls (§EU, built 6 Oct in the tomb):** fitted polygonal stone in real relief (stones proud, joints sunk; no normal maps), a seed per wall face, settled with age, moss and vines only where the climate allows. Firelit stone underground may go amber (§EU.6).
- **One ruin, one stone (§EX.1, not built yet):** every ruin type has one style (`masonry.json → styles`), and its floor, ceiling, doors, stairs, niches, sconces and stone dressing are cut from the walls' own stone in the same way. Nothing built of stone takes the general palette.
- **3D pixel art (§ES, frame amended by §EU):** a 480-line internal frame by default (§EU.1, 6 Oct; 270 "painted" stays a preset) with nearest-neighbour scaling; lighting painted into textures (diffuse-only, baked occlusion tinted navy/olive), mid-poly models. Texel density is re-measured under §ES (was 16 a metre at 480).
- Clean silhouettes, and no normal maps or specular.
- Dark but saturated, and blue owns the frame by default, not always: a relit village may go
  amber, one lit hearth at a time, while the wild between villages stays blue (§EE.1). The sun
  is the one light in the wild.
- Shade goes navy (olive in green scenes, firelit brown in a lit village), never grey. Distance
  gets lighter and bluer.
- Water is the brightest thing in view. Fire is the only warm light: one warm accent in the
  wild, many in a lit village (§EE.1). Only things that give off light glow.
- **One firelight (§EX.6):** every fire, the torch in hand included, lights in the hearth's amber
  (`look.json → fire.light.color`); fires differ in reach and strength, never in hue.

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
