# Prompt queue — the locked sections as Claude Code passes, one each, in build order

This file is Claude (chat)'s hand-off to Claude Code: every section Mike locked on 3 Oct (§DA–§DL,
the morning voice session; §DO–§DS, the monuments and the sages; §DT–§DZ, the second batch of
ruin kinds), written as **one focused Claude Code pass each**, in §BR's order. It mirrors the
prompt page Mike copies from; this copy is the one Claude Code reads, so nothing has to be pasted.

**Mike:** open a Claude Code session on the repo and say

> Pull, then read docs/PROMPT_QUEUE.md and do the next prompt marked todo.

or name one: "… and do prompt 17". One session, one prompt; a fresh session for the next one.

**Claude Code:** take the first `todo` row in the table (or the number Mike names) and do only
that prompt. The fenced text under its heading is the whole instruction, as if Mike had pasted
it; it already says to read `CLAUDE.md` and `docs/WORKING_AGREEMENT.md` first. When the pass is
pushed, change that row's status to `built <short hash>` and push that with the PROGRESS entry
(pull with rebase first; never force). Don't edit the prompt texts: if one contradicts the design
doc or the built game, say so to Mike and stop.

**Claude (chat)** appends new prompts after the ones already here (numbers never change) and
keeps the table's marks when it regenerates this file.

**Not in this file:** §DM (the road is the stage) and §DN (the lighthouse) were locked in other
chats and handed over there. Their design and data are `2978fb9`, `053c218` and `dd1349f`; in the
engine only §DM.1 (the hard grade cap) is built, as `e4ba236`. §DM.2–6 and §DN are not built yet
(Claude Code, 4 Oct). §DH (the goblin band) waits for Mike's four calls.

Built so far: 01–43 (37–43, §EH–§EN, the village economy, built 5–6 Oct). 44–48 are §EX, Mike's notes from playing the first dungeon (6 Oct night), Torchfire 1: do them in order, before §EW.7 step 2. 49 is §EY, the boss in every dungeon (6 Oct night): after 48. 50–51 are §EZ, the torch (6 Oct night): 50 (only water puts it out) is small and can run any time; 51 after 44. 52–61 are §FA–§FH, fire fights back, sneaking and what lurks (6 Oct, 22:32): 52, 53, 54 (after 50), 55 and 61 any time; 56, 57, 58 after 49, in that order; 59 after 58; 60 after 55, 57 and 58. 62 is §FJ (6 Oct, 22:52), torches burning down again: after 50 (whose no-burn-down step §FJ withdrew). 63 is §FK (7 Oct, 00:39), one world per new game, kept for good: after 46 (it replaces 46's new-seed stand-in with a seed drawn from the game's). 64 is §FL.2 (undone by Mike's 7 Oct evening correction; nothing to build). 65–74 are §FM (9 Oct, Mike by voice; bones only): 65 the boss pool, then 66 the snake's states; 67 the shaman and cauldron any time; 68 floors and the fork, then 69 fog, 70 the room pool and 73 tomes as pages (all after 68); 71 the tomb's surface (after 63 and 68). **Rows marked `waits` are not `todo`: 72 waits for 67 and 71 (its plant entries are written, §FM.9) and 74 for a second world and Mike's answers to §FM.10 calls 1 and 3. Do not start a `waits` row.** 75–77 are §FM.13, three new plant shapes (mushroom, globe cactus, bulb): any time, any order. The other ruins of the compass are in docs/design/RUIN_ROSTER_REFERENCE.md and data/ruin_compass.json, reference only, and have no queue rows. 78–84 are §FN (10 Oct, Mike by voice; bones plus what he specified): 78 the snake's plumes and rattle and 79 the Aztec stone any time; 80 the Aztec temple as a ruin kind with its two fixed chambers (after 79); 81 a third floor any time; 84 the surface pyramid (after 79 and 80). **82 waits for Mike's answer to §FN.8 call 1 (which biome world the Aztec ruin sits in, since the mushroom must grow where it grows) and 83 waits for 80 and 82. Do not start a `waits` row.**

| # | § | Prompt | Status |
|---|---|---|---|
| 1 | §DA (part 1 of 3) | Wind I: the gust field and the plants | built cfd6f6d |
| 2 | §DA (part 2 of 3) | Wind II: the ground, the ear, the cloth and the sparks | built 55a2e1b |
| 3 | §DA (part 3 of 3) | Wind III: water, cloud shadows and the smoke column | built a1cbe6e |
| 4 | §DB | The lens flare, the PSO way | built 244365e |
| 5 | §DD | The moon's two nights, and the year | built 9286ac2 |
| 6 | §DE | Waking: found by folk, days later | built fb74e3c |
| 7 | §DG | The full-moon werewolf | built 6b40278 |
| 8 | §DC (part 1 of 2) | Shafts of light, only when the air would really show them | built 0d0a3f8 |
| 9 | §DC (part 2 of 2) | Butterflies by day | built d8880fa |
| 10 | §DI (part 1 of 3) | Ruins wear their place: the overgrowth | built db1ba8b |
| 11 | §DI (part 2 of 3) | A ruin sounds like what lives in it | built 63e9956 |
| 12 | §DI (part 3 of 3) | The ghost at the corner | built 81ad44d |
| 13 | §DF | Your light gives you away | built 8217d38 |
| 14 | §DJ | Off the road: hidden places, and the few who speak | built 812f794 |
| 15 | §DK | The shrine and the sealed scroll | built 5ef2aa4 |
| 16 | §DL | Tomes: the I Ching first | built a4e6994 |
| 17 | §DO | The crag fortress | built 5d88fbe |
| 18 | §DR | The temple city: roots over stone | built 1b7eacc |
| 19 | §DP | The wandering fire: thirteen in the desert | built b545e71 |
| 20 | §DQ | The old man on his ox | built c0fae2b |
| 21 | §DS.1 | The long wall | built 8c59923 |
| 22 | §DS.2 | The carved cliffs | built ffc23f7 |
| 23 | §DS.4 | The cliff dwelling | built 719f939 |
| 24 | §DS.6 | The brick city | built 6666f21 |
| 25 | §DS.3 | The stone heads (and the oceania realm) | built b0965f2 |
| 26 | §DS.5 | The terraced pueblo | built 373561d |
| 27 | §DS.7 | The stone circle | built 51dcffb |
| 28 | §DS | The tower house and the broch | built 0cb81c7 |
| 29 | §DZ | The hewn temple, found from above | built 40ca950 |
| 30 | §DT | The hanging gardens | built 74439f5 |
| 31 | §DU | The ruined abbey | built 40a3af1 |
| 32 | §DW | The temple park | built 6de4562 |
| 33 | §DY | The pillar shrines | built fc29d06 |
| 34 | §DV | The old colonnade | built a4711a9 |
| 35 | §DX | The columns: columnar basalt as a nest | built 21ecf1b |
| 36 | §EA | Three hits, no bar, "Good night" | built 6c08095 |
| 37 | §EH | No metal, and a camp can be fifty | built d5dbe75 |
| 38 | §EL | The workshop: one hut, two benches, the hearth outside | built d4b159e |
| 39 | §EI | What a camp needs, and the trades that follow | built defc49a |
| 40 | §EK | The whole animal: the hunt, the hut, the six things | built 2d4b6a2 |
| 41 | §EJ | Food passed round, the night stories, the gift | built 6939b24 |
| 42 | §EM | Third places: the soak, the great tree, the water rock, the porch | built 6dec101 |
| 43 | §EN | The library: the camp book moves, the record-keeper, the winter count | built c6a2bd8 |
| 44 | §EX.6 | One firelight: the torch takes the hearth's amber | built cb946c1 |
| 45 | §EX.7 | A reticle in the crawler | built 475c143 |
| 46 | §EX.2, §EX.5 | The plan and the way out: a spine, the module, an exit every time | built 28dafd4 |
| 47 | §EX.4 | One hearth per dungeon; wall torches in the other rooms | built 6578210 |
| 48 | §EX.1, §EX.3 | One ruin, one stone: floor, ceiling, doors, stairs and sconces in the walls' style | built 8799b26 |
| 49 | §EY.1, §EY.2 | A boss in the dungeon: the snake prowls only the unlit rooms; the last light drives it into its hole | built 827805b |
| 50 | §EZ.1, §EZ.5 | The torch stays lit: only deep water puts it out | built dacd5d3 |
| 51 | §EZ.2 | The pitch torch: a wrapped, tarred head and a pixel flame | built afac6a9 |
| 52 | §FH | The folk at the hearth in 3D, made pixel by the frame | built 8c409e6 |
| 53 | §FC.1 | Sneak: the view eases down, the reticle changes, quiet feet, the ledge guard | built c40b2da |
| 54 | §FC.3, §FC.4 | Douse your own torch, and a dark you can half see in | built 972a2d5 |
| 55 | §FB | Two hands: the wheel, Tab and the wheel, and a Controls page | built 5402764 |
| 56 | §FD, §FJ.3 | Harm: a red ring and a heartbeat; a chase follows you into the light; heal once it gives you up | built b998d05 |
| 57 | §FA.1, §FA.2 | The torch staggers, and every creature has its own strike tell | built a4f1b00 |
| 58 | §FE, §FC.2 | The tomb's residents: skeletons out of the walls, and somewhere to hide | built 43688cb |
| 59 | §FF.2 | Cleared by light: the retreat, and the half-lit floor that bites | built 828e1fa |
| 60 | §FA.3 | Fire pots: lit off your torch, thrown, tar that clings, oil that bursts | built b21b5cd |
| 61 | §FG | Atmosphere, not puzzles: glow-moss, beetles, daylight with the clock | built e11418b |
| 62 | §FJ.4 | Torches burn down: a timer, the hearth's bundle, three at most | built 56dc352 |
| 63 | §FK.2, §FK.3 | One world per new game: one seed, a save, Continue and New game; one clock | built c90ea52 |
| 64 | §FL.2 | 480 lines the most | built 596646a, undone by a1e64b3 (720 the most, §FM.11) |
| 65 | §FM.1 | The boss behaviour pool: every boss draws its moves at random | built 492ae98 |
| 66 | §FM.2 | The snake's pool: freeze, doorway, observe, coil | built 1bc37be |
| 67 | §FM.6 | The shaman and the cauldron at the hearth | built 3485919 |
| 68 | §FM.6 | Floors and the fork: light the first floor and two ways open | built f2bd277 |
| 69 | §FM.6 | Floor two's fog: the same stone, darker | built a490eda |
| 70 | §FM.6 | The room pool: hand-built big rooms shuffled into each run | built fae9712 |
| 71 | §FM.7 | The tomb's surface: day and night above the stair | built 0181fcf |
| 72 | §FM.7 | Harvest and brew: a plant from above, a brew from the shaman | built 376cf23 |
| 73 | §FM.5 | Tomes as collected pages: found on the base layer | built 1bff283 |
| 74 | §FM.8 | The compass walk and the reference map | waits (a second world; §FM.10 calls 1, 3) |
| 75 | §FM.13 | A mushroom shape: a cap on a stalk | built 431c230 |
| 76 | §FM.13 | A globe cactus shape: a low button in the ground | built d2c2859 |
| 77 | §FM.13 | A bulb shape: a fan of leaves on a bulb, and its flower head | built ea48c3c |
| 78 | §FN.2 | The snake becomes the feathered serpent: plumes and a rattle | todo |
| 79 | §FN.1 | The Aztec temple's stone: a masonry style | todo |
| 80 | §FN.1 | The Aztec temple as a ruin kind: the blood altar and the calendar room | todo (after 79) |
| 81 | §FN.3 | A third floor, drawn by seed | superseded (§FO.0: one floor per ruin; do not build) |
| 82 | §FN.5 | The Aztec brew plant becomes teonanácatl | waits (Mike's answer to §FN.8 call 1) |
| 83 | §FN.5 | The vision filter: palette, hidden carvings, glowing and moving glyphs | waits (80 and 82) |
| 84 | §FN.4 | The Aztec pyramid on the surface | todo (after 79 and 80) |
| 85 | §FO.2, §FO.3 | One floor per ruin, and the way up opens when the boss is first driven home | todo |
| 86 | §FO.4 | The secret opening, its room and the tome | todo (after 85) |
| 87 | §FO.5, §FO.6 | Phase two: the blackout, and the boss's angry round | waits (86) |
| 88 | §FO.1 | The Egyptian stone: big sandstone blocks | todo |
| 89 | §FO.1 | The Egyptian ruin and the pharaoh in its sarcophagus | waits (87, 88, and Mike's answer to §FO.9 call 2) |
| 90 | §FP.1 | Scarabs: ambient skitterers in the Egyptian ruin | waits (89) |
| 91 | §FP.2 | The pharaoh's locust swarm: a ranged slow | waits (89) |
| 92 | §FP.3 | Hieroglyphs on the walls | waits (88 and 89) |
| 93 | §FP.4 | The Egyptian brew: blue lotus, mandrake, a vision that feels real, glyphs that read | waits (89, 92, 83, and Mike's answer to §FO.9 call 2) |
| 94 | §FQ.1 | The Maya stone: limestone | todo (after 88) |
| 95 | §FQ.1 | The Maya ruin: a jungle temple, its calendar room and a way down | waits (89, 94, and Mike's answer to §FQ.5 call 1) |
| 96 | §FQ.2 | Camazotz, the death bat | waits (95) |

## 01 — Wind I: the gust field and the plants — §DA (part 1 of 3)

**Status:** built cfd6f6d
**Mike sees:** Gusts you can see coming across a meadow; a wood where neighbours sway together and the tops toss while the air at your face is still.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DA (part 1 of 3) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DA (points 1–4, and the build order at its end), data/wind.json (gusts, beaufort, profile, grass, crowns, flutter and their _help lines). The wind's SOURCE stays the weather sim (WeatherSim.local_weather; WeatherFX sets the global shader parameter plant_wind each frame). Don't change the weather.

WHAT IS WRONG TODAY (confirmed 3 Oct): in shaders/foliage.gdshader (the vertex sway around lines 285–314) every plant leans by 0.65 + 0.35·sin(TIME·… + its own phase), so neighbours move out of step and nothing travels across a field or a wood; the weather's own gusts in local_weather are swells about 1.2 and 0.5 game hours long (minutes of real time), a slow freshening, not a gust; plants sway as hard under a closed crown as in the open.

BUILD, in this order:
1. The gust field. One function, written once for the shaders (a new shaders/wind.gdshaderinc, included by foliage.gdshader, terrain.gdshader's grass dapple and aroid_part.gdshader) and once in GDScript (a static Wind.gust_at(world_pos, time) for the CPU readers of later passes), and they must agree. It is two octaves of noise at wind.json gusts.patch_m (40 m and 12 m) carried DOWNWIND at the mean wind's speed in REAL seconds (frozen turbulence: sample the noise at world_pos − wind_dir · |wind| · time). Factor = 1 + gusts.intensity · noise, clamped to [lull_min 0.45, factor_max 1.6]; the direction veers by veer_deg (10°) · noise; below gusts.calm_mps (0.5) the field fades to 1. The weather's slow swell stays underneath as the mean. Every reader samples the SAME field at its own world position, so a gust is a patch that runs across the ground.
2. Height and shelter (wind.json profile). Over open ground the wind falls off toward the ground by the log profile with z0_m by ground kind: grass tops get about half the 10 m wind, head height about 0.7, a treetop about 1.1. Under a canopy everything BELOW the crowns is sheltered: shelter = shelter_floor (0.15) + 0.85 × that spot's sky visibility (the §BD number: ChunkManager.sky_visibility_at / the dapple stamp; pass it per instance at placement in vegetation_placer.gd). The crowns themselves (a tree's own canopy parts) always take the full wind, so in a closed wood the tops toss and the understory and the air at your face are still. Enclosed (ruin halls, caves, delves): no wind except at openings.
3. The crowns by Beaufort (wind.json crowns). Gate each movement on the gusted wind at the plant: leaves flutter from 1.6 m/s, twigs from 3.4, small branches from 5.5, small trees sway from 8, large branches from 10.8, whole trees from 13.9. Each trunk sways at its own period from sway_period_s by its height (the height is already in MODEL_MATRIX[1]), so a stand of one species sways together and mixed heights don't. Use the mesh's existing sway weight (COLOR.a) and the twig phase; nothing breaks (§BS).
4. Grass (wind.json grass): grass, reeds and herbs bow from 1.6 m/s up to lean_max 0.55 of their height, flat from 13.9; a passing gust is a bowed patch, and the cards tip their lit side away, so a paler sheen sweeps over a meadow ahead of the gust (brighten the card a little by the gust factor as it bends). Grass cards are in plant_meshes.gd / foliage.gdshader; terrain.gdshader's dapple wobble (around line 198) should read the same field.
5. Flutter (wind.json flutter): leaves on long or flattened stalks tremble in any air, from 0.1 m/s, by amount 0.08 on top of the crown's sway: genus Populus and the species Ficus religiosa (§CL's reason for this). A per-instance flag set at placement (the species is known there); keep it in instance custom data, not a new varying.
6. foliage.gdshader uses 8 of the house's 12 varying slots: keep all of this in the vertex stage and re-run tools/shader_varying_check.py (it must still pass).

CHECK (tools/wind_check.gd, headless): with a 6 m/s mean wind, (a) two points 20 m apart along the wind see the same gust about 3.3 s apart; (b) two points 3 m apart share a factor within 0.1; (c) a point under a closed crown (sky visibility 0.1) gets about 0.235 of the wind and a crown part gets the full wind; (d) the gust factor stays inside [0.45, 1.6] over 10,000 samples; (e) the GDScript and shader versions agree at 100 random points (read the shader back or port the maths once and compare). Then the walkabout once: a meadow in a breeze and a wood.

DON'T BUILD IN THIS PASS: the ground litter, the sound, the cloaks, the fire's specks, the water, the cloud shadows and the smoke column. Those are Wind II and Wind III. Don't touch the weather sim.

REPORT TO MIKE: in plain English, what now reads the gust field, how fast a gust crosses the ground, and that wind.json's Beaufort table is his dial (every threshold is a wind speed he can move).
```

## 02 — Wind II: the ground, the ear, the cloth and the sparks — §DA (part 2 of 3)

**Status:** built 55a2e1b
**Mike sees:** Leaves skating down an autumn road in a gust, the rustle rising in the trees the gust reaches, cloaks and sparks answering the same air.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DA (part 2 of 3) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

Wind I (the gust field, shaders/wind.gdshaderinc and Wind.gust_at) must be built first. READ: §DA point 4 (litter, cloaks, the fire, sound), data/wind.json (litter, cloaks, specks, sound and their _help lines), §BG (bed sounds have no position; sources are places you can walk to).

BUILD, in this order:
1. Litter skates (wind.json litter). Round the player (radius_m 25, count_max 40 at once) loose pieces lift when the GUSTED wind at that spot, after shelter, passes the kind's from_mps: leaves 5.5, needles 9, sand 6.5, snow 5, dust 7. A leaf is a pixel card in the colour of the tree it fell from (the per-species tint and the season: litter_field.gd and leaf_season.gd already know the pile's species and colour) that tumbles end over end downwind (reuse leaf_fall.gdshader's spin and flip), skips along the ground and settles after settle_s 2–6 s. Needles mostly stay put. Sand, snow and dust are low streaming skins (one scrolling ground-level card, not pieces): sand on dunes, beaches and hot desert; spindrift on fresh snow cover; dust off dry bare ground and old roads in dry country. The shelter rule puts this on roads, clearings and edges, rarely deep in a closed wood. Pieces come from the real litter field (what actually lies there), never conjured where nothing fell.
2. The ear (wind.json sound). The bed's wind loop (sound_bed.gd, the gain around line 185) follows the gust factor at the player, not only the mean, and still closes under canopy as built. New SOURCES: when the gust reaches a crown within radius_m 40 of the player and the gusted wind there passes 1.6 m/s, that crown's rustle rises from where it stands (an Audio3D player at the trunk, audio.json kinds: add crown_hush, crown_rustle, crown_clatter, crown_rattle, synthesized in sound_synth.gd like the other voices, no samples), at most max_sources 4 at once; the voice follows the leaf: needles hush, broad leaves rustle, palm fronds clatter, dry autumn leaves rattle (leaf_season knows when a crown is dry). The ear gets the gust when the eye does: same field, same instant.
3. The cloth (wind.json cloaks). PlayerBody.set_wind takes WeatherFX's mean wind today; pass it the gusted wind at the figure, for the player and every CloakedFigure (cloaked_figure.gd uses the same rig).
4. The fire (wind.json specks). §CZ is built: the campfire's specks (shaders/specks.gdshader) already drift with the wind and the coals flare on a gust. Make both read the gust field at the fire instead of the mean. The torch's own sparks (shaders/torch_ember.gdshader, §CP) drift the same way with the gusted wind at the torch. The pipe's puffs (§CY.4) take the wind at the camp if and when they exist; nothing to build here if they don't.

CHECK (extend tools/wind_check.gd): on an autumn road with a 7 m/s gust over it, leaves lift and travel downwind and settle within 2–6 s; at 4 m/s none lift; needles don't lift at 7; the bed's wind gain rises with the gust factor; a crown source plays only within 40 m and only when the gust at that crown passes 1.6 m/s, never more than 4 at once; the cloak's wind vector equals the gusted wind at the player. Walkabout once: an autumn road in a breeze.

DON'T BUILD: water, cloud shadows, the smoke column (Wind III).
```

## 03 — Wind III: water, cloud shadows and the smoke column — §DA (part 3 of 3)

**Status:** built a1cbe6e
**Mike sees:** Cat's paws sliding over a lake, cloud shadows sailing across a part-cloudy hillside, and a hearth's smoke rising straight through the trees and bending above them.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DA (part 3 of 3) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

Wind I and II must be built first. READ: §DA point 4 (water, cloud shadows) and point 5 (the smoke column), data/wind.json (water, cloud_shadows, smoke), §CX (one cover value drives the drawn cloud, the HUD word, the rain and the sun's dimming: use that value), §CV and data/smoke.json (the column itself), LOOK_REFERENCE R3, R5, R6.

BUILD, in this order:
1. Water (wind.json water). In shaders/water.gdshader sample the gust field at the water's world position: below calm_below_mps 1.0 the surface is a mirror; above cats_paws_mps 2.5 a patch roughens where the gust passes (its glints break up: scale the glint/caustic term down, and deepen its colour a little) and slides downwind with the gust; from whitecaps_mps 8 a few pale pixel crests on lakes and wide rivers, never foam sheets. Water stays the brightest thing in view (R6) and biome-matched in hue (§BU).
2. Cloud shadows (wind.json cloud_shadows). Only on part-cloudy days: between from_cover 0.15 and to_cover 0.85 of §CX's one cover value (clear has none, overcast is all shade). A world-space patch field (200–800 m) scrolled with the wind at speed_x 1.8 × the ground wind scales the sun's DIRECT light in terrain.gdshader and foliage.gdshader (cheapest: a global uniform with the field's offset and strength plus a noise function in look.gdshaderinc, no texture). In a cloud's shadow the shade colour holds (navy or olive, R3; §BD's floor), the edge is hard and pixel-crunched like everything else, and the sun's shadow maps stay as they are (a cloud shadow darkens the lit side; it doesn't move the hard shadows).
3. The smoke column, ONLY if §CV's column is built (code reading data/smoke.json). If it is: a hearth under trees is sheltered like everything below the crowns (Wind I's shelter), so its column rises straight up through the trees and takes the wind's lean only once it clears them; the lean follows the gust field at each height, not only the mean, so the column leans and recovers as the grass does; a gust shreds the cards near the fire (break the cards up over the gust). The numbers behind smoke.json far.seen_to_m (3,200 m) and far.min_px (2) are in tools/reference/beacon_reference.py: on the 400 km planet a full 60 m column is under two internal pixels past about 2.1 km, so min_px carries it the rest of the way; a hearth's column shows from about 3.2 km at eye height. If §CV is NOT built yet, skip this step and say so in PROGRESS; don't build the column in this pass (it is §CV's own).

CHECK (extend tools/wind_check.gd): a water point's roughness is 0 under 1 m/s, > 0 at 3 m/s in a gust patch, with crests only from 8; the cloud-shadow strength is 0 at cover 0.1 and 0.9 and > 0 at 0.5; the shadow field moves 1.8× the ground wind; if the column exists, a hearth under a closed crown leans 0° below the crowns and the full lean above them. Walkabout once: a lake in a breeze, and a part-cloudy day on open ground.
```

## 04 — The lens flare, the PSO way — §DB

**Status:** built 244365e
**Mike sees:** Look up at the sun from a clearing and it throws a soft core, a halo and a faint ring or two that slide as you turn, as PSO's forests did.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DB of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DB, data/look.json → lens_flare (and its _help), LOOK_REFERENCE R7 (warm is fire's) and R8 (only what emits glows). The sun's direction and elevation are in SkySystem (sun_dir, sun_elevation_deg); the internal 480-line frame and its nearest upscale are Display and PostGrade (scripts/core/display.gd, scripts/ui/post_grade.gd); §CX's one cover value is the cloud amount to read; Delves.underground says when you are below.

BUILD:
1. Each frame: if the sun is above the horizon and you are not underground, project sun_dir into the camera. If the sun's disc is inside the frame, test whether anything stands in front of it with ONE ray from the camera toward the sun (a RayCast3D to the far plane, or the depth at the sun's pixel; the ray is the cheap one). Blocked, or outside the frame, or over cloud: no flare.
2. The flare fades in and out over fade_s 0.15 s (a twig flicking past must not strobe) and fades toward the frame's edge over edge_fade 0.1 of the frame. Thin cloud dims it (through_cloud 0.4 of its strength) and it is gone once the cover is over gone_above_cloud 0.85.
3. Draw it as flat 2D sprites INTO the internal frame, before PostGrade's dither and 5-bit quantise, so it is part of the picture and not a sharp overlay (§Y, R9): a core of core_px 10 at the sun in core_color; a halo of halo_px 28 at halo_alpha 0.35; rings on the line from the sun through the frame's centre at their `at` (0 the sun, 1 the centre, past 1 the far side): 9 px at 0.55 and 16 px at 1.35, with their colours and alphas. Everything times strength 0.6. Soft discs with a 2–3 px gradient at most, nearest-filtered, nothing blurred.
4. Colour: cool white and pale cyan, never warm (R7). Within about 10° of the horizon the core takes the sun disc's colour (retro.colors.sunset_sun) and the rings stay cool. The sun's own bloom stays (R8). Never the moon, never underground.
5. Restraint is the point: PSO's soft flare, no anamorphic bars, no lens dirt, no streaks.

CHECK (tools/flare_check.gd, headless): the sun 30° up and in front of the camera with nothing between: flare alpha > 0 after 0.15 s; a wall placed between: 0 within 0.15 s; cover 0.9: 0; the sun below the horizon: 0; the sun just outside the frame: 0; the ring positions sit on the sun→centre line within a pixel. Walkabout once: a look toward the sun from a clearing at 09:00 and again at sunset.

REPORT TO MIKE: what it costs (one ray a frame), and that every size, colour and the strength are in look.json → lens_flare for his eye.
```

## 05 — The moon's two nights, and the year — §DD

**Status:** built 9286ac2
**Mike sees:** A full-moon night you can wander by and a new-moon night that is dark but readable; the HUD reads Day 12 of Year 1.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DD of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), and the walkabout only if the pass changes something you can see. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DD, data/look.json → moon_nights, data/hud.json → calendar, data/dread.json → full_moon.moon_fill_by_light only (the werewolf part of that block is §DG, a later pass), tools/reference/moon_reference.py (run it), §BD (under a closed crown and inside tombs: torch or nothing; that stands), §BU (the favourites' night), §CG (Day 1, local midnight; unchanged).

WHAT IS BUILT: a real orbital moon (astro.gd), a 29.5-day month, the 28 mansions, the moon and mansion HUD parts. SkySystem.update_sky already curves the moonlight: moonlight = moon_up × max(pow(illumination, 3.3), MOON_FLOOR 0.05), and the night palette, moon.light_energy and ambient_floor.night.moon_add lift with it.

BUILD:
1. Full against new, obvious, and you can always see. Make the whole night lift (the palette lift, the moon light's energy, ambient_floor.night.moon_add, the night sky stops) follow moonlight so that a 02:00 frame OUTDOORS UNDER OPEN SKY measures: full moon high ≈ moon_nights.full_mean_luma 0.20, first quarter ≈ 0.13, new moon ≈ 0.10. Measure with tools/look/measure_look.py the way retro.targets are measured, from the walkabout/dev_view harness with the clock set to those nights (frames labelled as harness frames, §CG). The lever is the moon's share of the night's light, NOT the floor: ambient_floor.night's floor stays, so the darkest 5 % stays navy and never black outdoors. Read curve_exponent from look.json (set to the code's own 3.3) so the curve lives in one place.
2. The moon sets how dangerous the night is: in dread.gd (around line 147) replace the switch at sky.moonlight > 0.3 with a lerp between meter.fill_per_min_dark and fill_per_min_moon by moonlight (0..1), so a bright night fills slower and a moonless one fastest.
3. The year joins the day count (hud.json calendar): the HUD's time part (hud.gd, _part_text["time"], via World.clock_text) and every GameLog stamp read calendar.time_format "Day {day} of Year {year}" and calendar.log_stamp "Y{year} D{day} {hh}:{mm}". day = ((local day count − 1) mod year_days) + 1 and year = floor((local day count − 1) / year_days) + 1, with year_days from DayCycle.year_days() and the local day count exactly as built (World.first_local_day; the day still turns at local midnight where you stand). A new world opens on Day 1 of Year 1. calendar.year_names stays "number" (open for Mike).
4. Remove the NOT WIRED prefixes on the three blocks you wired (leave dread.json full_moon's werewolf part marked).

CHECK (tools/day_check.gd extended, headless): local day 1 → "Day 1 of Year 1", day 365 → "Day 365 of Year 1", day 366 → "Day 1 of Year 2"; a log stamp and the HUD line agree at three times; the dread fill at moonlight 0, 0.5 and 1 is dark, halfway and moon; the two measured 02:00 lumas (full and new) land within ±0.03 of the targets and the darkest 5 % of both frames is navy (blue/red ratio > 2).

REPORT TO MIKE: the three measured lumas, and the open call: what a year is called (numbers, the twelve animals, the four beasts of the mansions, or our own names).
```

## 06 — Waking: found by folk, days later — §DE

**Status:** built fb74e3c
**Mike sees:** You come to beside a camp's fire with a log line saying folk found you and two days have passed, and the world has moved on without you.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DE of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), and the walkabout only if the pass changes something you can see. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DE (including its flag against §CW), data/camps.json → wake_found (the block and its _help line), data/hud.json → log_more (the "found" event), §AY (you wake at your hearth; the corpse stays), §CY.1 ("after a death you wake at whatever hour it is"), §CY.2 (the fire circle is its own pass: don't build it here; folk at the camp are doing whatever the camp does at that hour), §CW (the clock never skips otherwise). The death flow today is main.gd _on_player_died (around line 613: hud.show_death, GameLog.add(_death_line), camps.wake_fire, the wake_at_home branch around line 626, Hearth.dir), player_corpse.gd keeps the gear where you fell, and the catch-ups that already run time away are CampSim.catch_up, OldHearths.catch_up and the FireStore burn-down.

BUILD:
1. Where you wake (wake_found.where / no_home / skip_home_if): if a hearth was made (Hearth.dir) AND its camp is lit with folk at it AND it is not dark, overrun or abandoned → wake there. Otherwise the NEAREST lit fire with folk at it, measured from where you fell (extend camps.wake_fire with those conditions; an overrun ruin is never chosen: read the overrun state). Failing everything, the opening camp. This amends §AY: the opening camp is no longer the default.
2. The lost days (wake_found.lost_days): roll a uniform span between 1 and 3 game days and move world.days by it, so you wake at whatever hour that lands on. Run the world for those days the way it already runs for time away: every camp's ticks (CampSim.catch_up), the old hearths, every FireStore burning down (including the one at the camp you wake at, which the folk have kept fed, and your torch lying with your corpse, which burns out), PlantGrowth and the plantings, the weather stepped forward, the moon and the season simply following the clock. Reuse the existing catch-up paths; fake nothing; the local day count moves on (§CG). Nothing else in the game may ever move the clock (§CW): only this.
3. The log (§AZ): the cause line first, using wake_found.death_lines_found when waking this way (creature → "Struck down by a {creature}"; the others as listed), then wake_found.log with {days} written as a word (Two, Three) or log_one_day for one, stamped with the waking time. Both lines persist with the log as built.
4. You wake at the fire at that hour (the existing wake(seconds) blur is fine), empty-handed, your gear where you fell (as built). If §CY.2's circle exists by then you wake into it; if not, into the camp as it is.

CHECK (tools/wake_check.gd, headless): die 3 km from a lit home hearth → wake there; with no home → the nearest lit camp with folk; with the home camp overrun → the nearest instead; over 20 deaths the lost days all fall in [1, 3] and are not all equal; the clock advanced by exactly the rolled span; the log holds the cause line then the found line, in that order, stamped at the wake time; the corpse and its gear are still where you fell; a camp's woodpile changed by about lost_days × its daily burn (the catch-up ran).

REPORT TO MIKE: in plain English, and repeat §DE's flag: the clock now moves past him on a death and on nothing else (§CW), so a player could die on purpose to pass a night; his call to keep that or shorten the lost time.
```

## 07 — The full-moon werewolf — §DG

**Status:** built 6b40278
**Mike sees:** The werewolf is out only on the three brightest nights a month, comes from downwind, and your torch neither hides you from it nor gives you away.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DG of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), and the walkabout only if the pass changes something you can see. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DG, data/dread.json → full_moon (and hunters: the werewolf row, full_moon_speed_scale, and the creature-null row, the lurker with no species, §CU), data/sky/day_cycle.json → full_moon_illumination (0.97) and its README row, data/senses.json → watchers.werewolf (only this row matters here: scent 400 m, light_sight 0, held_by_light true), tools/reference/moon_reference.py (run it). §BA stands: light holds every beast off; never a fight.

WHAT IS BUILT: creature_species.gd active_now gates "full_moon" at moon_full > 0.85 (about seven nights a month); CreatureSpawner sets moon_full from Astro.moon_illumination; dread.gd _follow (around line 241) scales the werewolf's speed above sky.moonlight 0.9; the hunter for a biome is picked around dread.gd line 287–330.

BUILD:
1. One threshold for every reader: DayCycle gains full_moon_illumination() (data, default 0.97). creature_species.gd active_now uses it instead of 0.85. dread.gd's full_moon_speed_scale applies when Astro.moon_illumination(days) ≥ it, instead of sky.moonlight > 0.9.
2. Only on the brightest nights: for the biomes whose hunter is in full_moon.only (the werewolf's four forests), the hunter is the werewolf only while the lit share is at or above the threshold; on every other night those biomes use the creature-null fallback row (the lurker), as the grasslands do every night. The werewolf keeps its pacer pattern, 6.5 m/s and ×1.3 on the full moon.
3. By scent: the werewolf's noticing never reads the torch: a lit torch neither draws it nor hides you from it (senses.json werewolf: light_sight_m 0). It comes from DOWNWIND: pick the pacer's side as the downwind side of the player (WeatherFX.plant_wind, or the gust field if Wind I is built), re-picked slowly, so the wind decides which side it approaches from. Light still holds it back at stage 5 exactly as built (a torch slows, a fire keeps it out).
4. Remove the NOT WIRED prefix from full_moon (and from the README row); leave senses.json marked (its other rows are §DF, a later pass).

CHECK (tools/dread_check.gd extended, headless): in a temperate deciduous forest at a lit share of 0.5 the hunter is the fallback lurker; at 0.98 it is the werewolf at 6.5 × 1.3 m/s; active_now flips at 0.97, not 0.85; with a steady 5 m/s wind the werewolf's chosen side is within ±45° of downwind in at least 80 % of samples; lighting a torch changes nothing about whether it notices you.

REPORT TO MIKE: the open call from §DG: as built (World.START_DAYS 13.62, kept by §CY.1), nights 1, 2 and 3 of every new world are werewolf nights wherever the werewolf lives; starting two days earlier would make the first full moon fall on nights 3–5. Don't change START_DAYS in this pass; it is his call.
```

## 08 — Shafts of light, only when the air would really show them — §DC (part 1 of 2)

**Status:** built 0d0a3f8
**Mike sees:** A misty dawn wood with hard-edged shafts through the gaps, a sunbeam into a dark hall with dust in it, rays fanning from a sun behind broken cloud; a dry noon wood with none.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DC (part 1 of 2) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DC (the shafts; the butterflies are the next pass), data/look.json → shafts (and its _help), §BD (sky visibility: ChunkManager.sky_visibility_at and the dapple stamp), the 1 Oct mist (look.json mist, SkySystem's mist density), §CX (one cover value), LOOK_REFERENCE R7 (cool, never warm) and R8 (lit air never blooms). The way NightAccents builds and frees its props round the player (scripts/sky/night_accents.gd) is the pattern to follow.

BUILD a ShaftField that, each frame near the player (within about 60 m), draws shafts ONLY when three real things meet:
1. Direct sun on the place: the sun above 2°, §CX's cover under max_cloud 0.75, and the place not under a cloud shadow (if Wind III's cloud shadows exist; otherwise skip that test).
2. Something in the air: air = the largest of the weather's fog likelihood, smoothstep(haze_rh_from 0.8 → 1.0) of the relative humidity (the damp after rain, at dawn), the mist density where you stand, smoke within smoke_m 40 of a lit hearth (only if §CV's column is built), and dust (1.0 inside a ruin hall). No air, no shafts: the same wood at a dry noon has none.
3. A broken roof, which picks the kind: CANOPY under broken crowns, where sky visibility is between gap_visibility 0.15 and 0.7 (neither open sky nor a closed roof); RUIN, a sunbeam into a dark hall through its broken vault or a window (RuinBuilder knows its openings; first pass: the enclosed cells within a few metres of an opening above), with dust motes in it; CREPUSCULAR, rays fanning from the sun across the open sky from gaps in broken cloud, only when the cover is inside broken_cloud 0.3–0.7.

Draw them the era's way: long flat see-through quads along the sun's direction (length_m 6–30, width_m 0.4–2.5) from the gap down to the ground, in the sky's light colour #DDF2FF at most alpha_max 0.22 × air × the low_sun scale (the table in the data: strongest and longest with the sun low) × a facing factor (brightest looking toward the sun, faint with it behind you). Hard pixel edges, nearest, dithered with everything, never soft volumetric fog, and never past the bloom threshold (R8: lit air doesn't glow). Never more than max_per_view 6. They waver as the crowns above move (sample the gust field if Wind I is built, else a slow sine). Motes: count_per_shaft 12 single pixels drifting drift_mps 0.05 only inside the light. Free everything when the gate fails, as NightAccents frees its props by day.

CHECK (tools/shaft_check.gd, headless): a jungle spot at 07:00 with relative humidity 0.95 and cover 0.2 → between 1 and 6 shafts; the same spot at 13:00 with rh 0.5, no fog, no mist, no hearth → 0; cover 0.9 → 0; a ruin hall by day → at least 1 with motes; the shaft colour is cool (blue above red) and its brightest pixel stays under the bloom threshold. Walkabout once: a misty dawn wood, and the same wood at a dry noon.
```

## 09 — Butterflies by day — §DC (part 2 of 2)

**Status:** built d8880fa
**Mike sees:** A few small butterflies dancing round flowers in a sunlit meadow, sitting in the grass when it blows, gone at night.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DC (part 2 of 2) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DC (the butterflies paragraph), data/day_accents.json (and its _help), scripts/sky/night_accents.gd (the pattern: _swarm and _fly build the night's blue butterflies at the ruins; those STAY as they are), LOOK_REFERENCE R7 and R8 (nothing in the day's air glows), data/wind.json water/grass thresholds are not needed; only day_accents.butterflies.calm_below_mps is.

BUILD DayAccents, the day's counterpart of NightAccents: while it is day (the inverse of night_accents' shows_below_daylight), within range_m 30 of the player, count 2–6 small flapping pixel quads of size_m 0.08 at height_m 0.3–2.5, dancing round plants in flower (use the species' bloom state where PlantGrowth has one; otherwise any herb or shrub by day), only where the sun reaches (sky visibility over min_visibility 0.4: never under closed crowns), inside temp_c 14–40, and while the wind is under calm_below_mps 5.5: when it blows harder they land in the grass and stop until it eases. They drift a little downwind. A flap is a two-frame pixel card. Their material is NOT emissive and they cast no light (R8). Colours from palette_by_family by the biome's family (mostly whites, yellows and blues; an orange one is a small fleck, never a scene's accent, R7). Never at night, never over snow. Free them at dusk the way NightAccents frees by day.

CHECK (tools/day_accents_check.gd, headless): a warm meadow at noon → 2–6 butterflies within 30 m; the same at 02:00 → 0; a snowfield at noon → 0; a closed jungle floor (sky visibility 0.1) → 0; with the wind at 8 m/s they are on the ground with zero speed; their material has no emission. Walkabout once: a meadow at noon.

REPORT TO MIKE: that each land's real species and colours are a later data fill from chat (one agent per biome family, §CS), and these first colours are placeholders by family.
```

## 10 — Ruins wear their place: the overgrowth — §DI (part 1 of 3)

**Status:** built db1ba8b
**Mike sees:** A cloud-forest ruin green to the cornice, a desert one nearly bare with lichen, moss thicker on the shaded side; dressing only, nothing to clear.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DI (part 1 of 3) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DI point 2, data/ruins.json → overgrowth (and its _help), §CA (the biome gate), §CS (the community of the place; if communities aren't built yet, the biome's own plant file is the list), §CE (vines over surfaces: VineCover.build_nodes in scripts/ecology/vine_cover.gd), §CM (the nest ferns are already in the plant data), §BQ (signatures stay), LOOK_REFERENCE R9 (detail in the albedo). The ruins are built in scripts/landmarks/ruin_builder.gd and shaded by shaders/ruin.gdshader.

BUILD, at ruin build time, by the site's moisture (the climate's 0–1 at the cell) through the by_moisture rows (blend between rows):
1. Moss on the stones: a moss overlay or a second stone tile blended by the moss column, thicker by shade_side_scale 1.6 on the side facing away from the sun (north in the northern hemisphere, south in the southern).
2. Ferns in the cracks and at the foot: the fern species the biome itself grows (its plant file; the §CM nest ferns are there), placed by the fern column along wall feet and in gaps; existing plant meshes, placed by rule.
3. Vines over the walls: VineCover on the ruin's wall meshes with the biome's own vine species (§CE), by the vine column.
4. Grass and herbs along the wall tops, from the biome's ground cover, by the wall_top column.
5. Lichen painted into the stone's own tile: a lichen-flecked variant of the ruin stone tile, blended by the lichen column (in the albedo, R9; never a shiny overlay).
6. age: a monument ×1.0, a camp's remains ×0.5 (§CK). cold_mean_c: where the year's mean is under 0 °C, lichen and moss only. Never a species the place can't grow (§CA). It is dressing: nothing collides beyond the existing walls, nothing is cleared, no mechanic.

CHECK (tools/overgrowth_check.gd, headless): a castle in cloud forest (moisture ≈ 1.0) gets moss coverage ≥ 0.6 and ferns > 0; a hot-desert ruin gets vine ≤ 0.05 and no moss; a tundra ruin gets lichen and moss only; the shade side's moss is more than the sun side's; every placed species passes the biome gate; the ruin's triangle count grows by less than 20 %. Walkabout once: one wet ruin and one dry.
```

## 11 — A ruin sounds like what lives in it — §DI (part 2 of 3)

**Status:** built 63e9956
**Mike sees:** Birds in a tower top by day, bats out of the vault at dusk, an owl in a window at night, something scrabbling below in the dark, wind moaning through the gaps; an overrun ruin silent by day.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DI (part 2 of 3) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DI point 3, data/audio.json → ruins (residents, bed, overrun_quiet_by_day, and its _help), §BG (two systems: the bed has no position; a source is a place you can walk to; muffled by terrain and foliage), §CH (the night roster; the bats), §CN and data/delves.json → overrun.tells (sound_bed_quiet by day), §CV.5 (the swifts in a cold stack are smoke.json's; build them only if §CV is built). The bed is scripts/core/sound_bed.gd; sources are Audio3D players with voices synthesized in scripts/creatures/sound_synth.gd (no samples); the muffle rules are audio.json kinds.

BUILD:
1. Residents as SOURCES: for each loaded ruin, by the hour and by what the biome's roster actually has (creatures.json active and the spawner's lists): a bird call from the tower's top by day; bats pouring out of the vault at dusk and back at dawn (reuse §CH's bats if built, else a short synthesized flutter-and-squeak burst at the vault's mouth); an owl from a window at night; something small scrabbling below at dusk and night; frogs and drips at a cistern where the ruin has water; lizards rustling in warm dry stone by day. Each is an Audio3D player AT that part of the ruin (new audio.json kinds: ruin_birds, ruin_scrabble, ruin_drip, ruin_lizard, with unit_size, max_distance and muffle like the other sources), never a positionless loop.
2. The ruin's own BED: inside and near a ruin add its room tone to SoundBed: wind in the stones (a low moan when the wind at an opening passes bed.stone_wind_from_mps 6; read the gust field at the opening if Wind I is built, else the mean), drips where there is water, and the hush of a closed hall (lower the outdoor bed inside enclosed cells).
3. Overrun: an overrun ruin's residents are silent by day (delves.json overrun.tells: sound_bed_quiet), and at night the shapes and the hunter's call stay as built. The ghost (§DI point 4, a later pass) makes no sound at all; don't give it one.
4. Not written, on purpose: Minecraft's cave groans (§BG took untrackable noises out; §DI leaves them open for Mike).

CHECK (tools/ruin_sound_check.gd, headless): a tower ruin at noon → at least one resident source playing, positioned at the ruin; at 02:00 → the owl or the scrabble and no day bird; a swamp ruin with a cistern → frogs and drips; an overrun ruin at noon → 0 residents and the bed quiet; the stone-wind gain is 0 under 6 m/s at the opening and > 0 above; every new kind has a muffle so it can be walked to. Walkabout once (for the ear): stand in a ruin at dusk.
```

## 12 — The ghost at the corner — §DI (part 3 of 3)

**Status:** built 81ad44d
**Mike sees:** In a graveyard at night a pale figure stands at the edge of your light, steps round a headstone, and the corner is empty when you get there.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DI (part 3 of 3) of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DI point 4, data/ruins.json → haunt (and its _help), §BA (the dread's stage-3 shape is NOT this: a ghost comes with no warning and touches no meter), §CU (a ghost is not a lurker), §BQ (it tells nothing), LOOK_REFERENCE R8 (no light of its own). The shared cloaked rig is scripts/creatures/cloaked_figure.gd; Ruins.Kind names the ruin kinds; the delves' tomb and mausoleum rooms are in scripts/landmarks/delves.gd; sky visibility is ChunkManager.sky_visibility_at; the camera's frustum test is Camera3D.is_position_in_frustum (player_body.gd uses it).

BUILD a Haunt:
1. Which places: seeded per ruin, share 0.4 of GRAVEYARD and BARROW ruins and of the tomb and mausoleum rooms of any delve are haunted; the rest never are.
2. When: only while the player is in or beside a haunted place AND the light is low: dusk, night, or a dark hall by day (sky visibility under low_light_visibility 0.25). Rolled rarely: about per_real_hour 1.0 over time spent in such places, at most per_visit_max 1 a visit, never twice in a row at one spot.
3. Where: a spot distance_m 8–20 off at a corner, a doorway or the edge of your light, that is currently inside the camera frustum, with an occluder within occluder_within_m 1.5 to step behind (a wall end, a doorway jamb, a headstone, a trunk).
4. What: the shared cloaked rig in color #C8D8FF at alpha 0.55, pale and a little see-through, no light, no sound, no collision, no footsteps, no head-look. It stands for seen_s 0.5–2 s, then walks behind the occluder; the moment it leaves the frustum or a ray from the camera to it is blocked, it is freed, so the corner you hurry round is empty.
5. What it never does: harm, speak, change the dread meter or its stages, write a log line, or appear at noon in the open. It is not a lurker and gets none of their cues.

CHECK (tools/haunt_check.gd, headless): over 100 simulated ten-minute visits to a haunted graveyard at night, a ghost appears in roughly 10–25 % of them, never more than once a visit, never twice at the same spot in a row; at noon outdoors 0; in an unhaunted ruin 0; each is freed within half a second of leaving the frustum; the dread meter's value is identical with and without the haunt; its material has no emission and it holds no Light3D. Walkabout once: a graveyard at night (the ghost may or may not show; that is the point).
```

## 13 — Your light gives you away — §DF

**Status:** built 8217d38
**Mike sees:** A torch lit at night is seen from far by what lurks; plant it and walk into the dark and the lurker goes to the torch; a werewolf smells you from downwind regardless.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DF of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), and the walkabout only if the pass changes something you can see. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DF, data/senses.json (every block and its _help; leave watchers.goblin_band and watchers.stranger with built false: §DH's calls are open), §BA (the dread and its stages stand), §CQ (dread.json torch_circle: the circle is how far the lurkers keep back; this pass is how far they SEE), §CU (lurkers), §CH (the rosters' light_response in creatures.json stands), §AW (a planted torch is a light like a held one), §DG (the werewolf's row, built in its own pass). Footstep noise is scripts/player/noise_events.gd; the lurker's logic is scripts/creatures/dread.gd; the ordinary creatures notice through creature.gd / territories.gd.

BUILD:
1. What you give off: LIGHT (a lit torch held or planted: a world position that is "seen from" far beyond its circle; a planted torch counts), SOUND (noise_events as built: 0 silent to 1 sprinting), SCENT (always; it rides the wind: a watcher is in your scent only within its scent_m AND within about ±30° of downwind of you, from WeatherFX.plant_wind or the gust field if Wind I is built).
2. A Senses helper: can_sense(watcher_kind, watcher_pos, player) → the sense that works, from senses.json watchers: sight_day_m by day scaled by daylight; night_vision × (1 + moonlight_adds 0.5 × moonlight) of that at night; light_sight_m when a lit torch is in LINE OF SIGHT (one ray; the terrain and the horizon stop it on their own, 451 m from eye height on level ground); hearing_m × the noise level (walking half, sneaking a fifth); scent_m in the downwind cone. Trunks, walls and ridges stop sight and light alike.
3. Wire the lurker (dread.gd): the hunter notices and follows by can_sense instead of a flat radius; the meter's rules are unchanged. With the torch lit it finds you from light_sight_m 1,500 m away (line of sight permitting) and is held at the circle's edge as built; with it out it has only its night sight, hearing and nothing else (scent_m 0). The DECOY: when the player is dark and beyond its night sight, a planted torch is the light it goes to; it ends at the torch, not the player.
4. Wire the rosters: night_animal and day_animal noticing (shy_m / notice) reads can_sense, so a day animal at night barely sees a dark player (0.15) but sees you fine under a full moon (×1.5), and a night animal hears and smells you.
5. Going dark costs nothing new here: §AW and §CQ.4 already make the relight a flame or the carried coal.
6. Don't build: the goblin band and the stranger (open, §DH / §DF); keep their rows marked built false.

CHECK (tools/senses_check.gd, headless): a lurker 400 m away at night with a clear line sees a lit torch and does not see a dark player; with a hill between, neither; a day animal at 60 m at night does not see a dark player at new moon and does at full moon; a werewolf-kind watcher 300 m downwind smells you and 300 m upwind does not; the decoy: plant a torch and walk 50 m into the dark and the hunter's target is the torch's position; sprinting is heard at hearing_m and sneaking only at a fifth of it.

REPORT TO MIKE: the open call: what the stranger does when they come (stands with you, walks you to a fire, leaves you a coal, or something stranger), and that the goblin band waits on his four §DH calls.
```

## 14 — Off the road: hidden places, and the few who speak — §DJ

**Status:** built 812f794
**Mike sees:** Off the trail, a hidden grove with turf-roofed homes dug into a bank, a doorway under a gnarled old oak, a shrine's mouth; a small strange figure who says one cryptic line in the log.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DJ of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DJ, data/shrines.json → hidden (the three kits, off_road_m, per_km_of_road, speakers_share, and the _help), data/hud.json → log_more (spoken; given and asked are wired by the scroll pass, not here), §BC (finds off the road), §CJ.8 (placed by rule, never hand-placed), §BO (small folk; our own folklore), §BF (lines, not dialogue), §BL (the earth homes are a camp), §CU and §CV (their hearth counts and smokes like any). The one-of-a-kind placement pattern is scripts/landmarks/uniques.gd (the sacred fig); the road distances are scripts/terrain/road_network.gd; set pieces on terrain are built the way scripts/landmarks/nest_builder.gd builds the cliff shelter; small folk are the shared rig at small scale (cloaked_figure.gd).

BUILD a HiddenPlaces pass after the roads:
1. Placement: candidates 150–900 m off the nearest road (never on one), about 0.25 to a kilometre of road, each kit where its site fits: earth_homes needs a sheltered hollow or bank with water near and woods in reach; oak_door needs an old broadleaf of that place past the top of its size band (an oak where oaks grow; §CA/§CS) on a rise; burning_shrine needs rock or a slope to go into. Seeded; a different world, different places.
2. The kits, as set pieces: earth_homes: two to four turf-covered doorways dug into the bank (a stone lintel, a low door, the turf running over the roof), a small camp under the camp sim with its own hearth, folk included, counted as a hearth (§CU) that smokes (§CV, when built). oak_door: the great tree's roots gripping a stone doorway that goes down; until §DK's shrine exists, the door is a closed stone door. burning_shrine: the shrine's surface mouth only (a stone portal going down into the slope with torchlight showing inside); §DK builds what is behind it.
3. The few who speak (speakers_share 0.3): at about three in ten hidden places, one small cloaked figure (small folk scale) stays by the place. Mute like all folk; when you come within 3 m and right-click (interact), ONE cryptic line goes into the log (hud.json log_more: spoken), once per visit. Write 8–10 first-guess lines into shrines.json → hidden.lines (short, strange, no names, no instructions, no quest text; Mike will replace them), and pick one per figure per visit.
4. No quest log, no markers, no choices, no dialogue trees (§BF). Given and asked (a thing handed over, a thing wanted) wait for §DK.

CHECK (tools/hidden_check.gd, headless): on seed 7731, count the hidden places; every one is 150–900 m from the nearest road; the count is within ±50 % of 0.25 per km of road; every oak_door tree passes the biome gate; every earth_homes site has water within reach and a lit hearth with folk; about 30 % of places have a speaker; approaching and interacting adds exactly one "spoken" log line per visit. Walkabout once: one of each kit.
```

## 15 — The shrine and the sealed scroll — §DK

**Status:** built 5ef2aa4
**Mike sees:** An ominous hall going down, torches burning in sconces, a sealed scroll on an altar; far away someone reads it and asks where you found it; back at the shrine the right torches open the wall.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DK of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DK (all nine points and its open calls), data/shrines.json → shrine, scroll and log (and the _help), data/items.json → kinds.scroll, data/hud.json → log_more (scroll, shown, asked, deciphered, keep_deciphered_whole), §CN (the swing passes the flame; right click is interact), data/delves.json → fire_holders (the sconce kind), §CJ (every ruin's delve; the barrow delve is built), §CV (sconces never smoke), §BI (the trade gesture: hold a thing out to a folk). The log panel is scripts/ui/log_panel.gd; the delves are scripts/landmarks/delves.gd and ruin_builder.gd; §DJ's hidden places may already have placed the shrine's surface mouth (oak_door, burning_shrine): if so, build behind them; if not, place shrines as their own hidden places by §DJ's rule.

BUILD:
1. The shrine: from the mouth, a long descending hall (a §BB corridor: narrow, dark, the torchlight the only light), sconces 6–8 of them along its walls, each a lit torch in a bracket (the delve's "sconce" fire-holder, lit at world generation and burning without fuel: §DK leaves what they burn with open, so for now they simply burn; say so in PROGRESS), and an altar room at the end with the sealed scroll on the altar. The delve behind the altar is shut by a solid wall. Sconces never smoke.
2. The scroll item: right-click takes it (log: shrines.json log.taken). Carried with burden like anything; it stays with your corpse where you fall (as built).
3. The reader: §DK leaves who they are open, so build the mechanism with a marked stand-in: this world's reader is the headman of the nearest grown camp that is at least scroll.reader_far_km[0] 5 km from the shrine and within 60 km (write "headman_far" as the first guess into shrines.json scroll.readers and flag it for Mike). Showing the scroll is §BI's gesture: right-click a folk with the scroll in hand. Anyone else: they turn it over and hand it back (log.shown). The reader: log.asked_where ("Where did you find this?"), then the deciphered text, kept WHOLE in the log so it can be read back: a passage (write 3–5 short lines of your own first-guess cryptic text into shrines.json scroll.passage_first_guess; no copyrighted text; Mike will replace it) and the pattern as a sentence ("The first, the fourth and the sixth burn. The rest are dark."). The item becomes "Opened scroll". The log panel must show a long multi-line entry whole (log_more.keep_deciphered_whole).
4. The pattern lock: each shrine has a seeded pattern of lit and dark sconces (never all lit, never all dark). A sconce is put out by right-click (smother) and lit by the torch's swing (§CN), with no kindling (laying is for fires). When the hall matches the pattern, the wall behind the altar gives way (log.opened) to steps down into the shrine's delve (use the barrow delve kit for now; what lies deeper is open). A wrong pattern does nothing; there is no hint, no counter, no UI.
5. Don't build: a stranger light for the sconces, what lies deeper, a quest log or markers.

CHECK (tools/shrine_check.gd, headless): a shrine generates with 6–8 sconces and a pattern that is neither all lit nor all dark; taking the scroll writes log.taken; showing it to a non-reader writes log.shown and keeps the item; the reader writes asked_where then the whole deciphered entry (passage and pattern), and the item is renamed; setting the sconces to the pattern opens the wall exactly once; any other arrangement leaves it shut; the log panel shows the whole deciphered entry; the sconces draw no smoke. Walkabout once: the hall from the mouth to the altar.

REPORT TO MIKE: the three open calls you stood in for (the reader, the passage text, the sconces' light) and what lies deeper.
```

## 16 — Tomes: the I Ching first — §DL

**Status:** built a4e6994
**Mike sees:** At a delve's heart a tome lies where someone left it; carry it and open it to read, one hexagram to a page, in the HUD's font.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DL of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), and the walkabout only if the pass changes something you can see. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DL, data/tomes.json (find, tomes, and the _help), data/items.json → kinds.tome, data/hud.json → log_more (tome), §AW (rare finds live in ruins, never chests), §CJ.3 (the heart's find), the log panel (scripts/ui/log_panel.gd: the reader opens the same way, in the internal frame, in the HUD's font), scripts/player/inventory.gd.

BUILD:
1. The find: for share_of_hearts 0.15 of delves (seeded per delve), the heart's find is a tome lying where someone left it (on the altar or the floor), instead of its other find. Right-click takes it; the log notes it (hud.json log_more: tome: "You found a tome: The Book of Changes"). It is carried like anything and stays with your corpse.
2. The reader: with a tome in hand, one press (your call inside §CN's scheme: right click is interact, left click is the item-in-hand action, so pick a free key and document it in HOW_TO_RUN) opens a panel built like the log panel: the title page, then one page at a time (one hexagram a page for the I Ching), left and right to turn, Esc closes; nothing else on screen changes, the clock keeps running (§CW).
3. The text: the panel reads the tome's text_file from data/tomes/ (data/tomes/iching_legge.txt, a later data job from chat: Legge's 1882 public-domain translation, never Wilhelm/Baynes). Define the file format now and write it into data/tomes/README.md so the fill matches: plain UTF-8, the first line the title, pages separated by a line holding only ---, and a page's first line its heading. Honest when the text isn't there: a tome whose text_file is missing or whose tomes.json entry has filled false does NOT spawn in the world at all (no blank books), and the dev overlay says "tome text missing: <id>".
4. No systems on it (Mike): the I Ching coin cast in scripts/core/iching.gd (the rare-event RNG) is a separate thing; don't connect them.

CHECK (tools/tome_check.gd, headless): with a three-page test file in the format, the panel shows the title and turns three pages and no more; with the file absent, no tome spawns anywhere and the overlay says so; over 200 seeded delves about 15 % (±5) hold a tome once the text exists; taking it writes the log line; the clock runs while the panel is open.

REPORT TO MIKE: that the game is ready for the text, and that filling data/tomes/iching_legge.txt from Legge's public-domain edition is a chat data job (one agent per group of hexagrams, checked against the source).
```

## 17 — The crag fortress — §DO

**Status:** built 5d88fbe
**Mike sees:** A whitewashed fortress climbing a crag in tiers under a cobalt sky, the red band under every roofline, one long stair up the rock; its delve climbs to the chapel at the top.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DO of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DO, data/ruins.json → styles.crag_fortress (kind own) and _help.styles_kinds, data/smoke.json → outlets.by_ruin.crag_fortress, data/delves.json → fire_holders.by_ruin.crag_fortress, §CJ (a tower's stair may climb: this delve goes UP), §CK (nests: kopje, volcanic_neck, escarpment, mesa; walking-scale sizes), §CV.3, §DI, §DM.5, LOOK_REFERENCE R7 (the red band is a matte material, never a light) and R10. Mike's reference: a hilltop fortress-monastery of the Tibetan kind.

BUILD the kind: tiers of limewashed battered walls (leaning in 5–8°) climbing a rock rise of 40–100 m, flat roofs, small dark windows in trapezoid frames, the matte red-brown band under every roofline (#5A2420), one matte gilt finial on the top chapel (#B08A2E, never glowing: R8), a single long stair cut up the rock from the foot, a cluster of lesser buildings at the foot where a camp may live (§CK). The crag: use the nests at their larger sizes, or raise a rock rise for it where the gate holds (puna, cold desert, steppe, alpine meadow, krummholz at altitude; realms central_asia, east_asia_temperate, andes, palearctic); never on a flat, never wet or warm; at most four a world. The delve climbs: from the foot, the stair through the tiers, stores and a cistern cut into the rock on the way, braziers on the landings, the heart is the top chapel, the way out is the outside stair (§CJ.4). Smoke: each delve hearth vents through a roof vent. Overgrowth: lichen and a little moss on the shaded faces only. No cloth anywhere (no prayer flags, Mike).

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 18 — The temple city: roots over stone — §DR

**Status:** built 1b7eacc
**Mike sees:** Galleries of square columns, tiered towers with faces, a moat, courtyards of tumbled blocks, and pale trees standing on the gallery roofs with their roots poured over the doorways.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DR of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DR (all seven points), data/ruins.json → styles.temple_city and root_trees, §CL (the fig's roots gripping old stone) and §DJ (the oak door: the same mechanism), §BB (galleries are corridors, gopuras thresholds, courtyards rooms), §CJ.6 (the collapse is the obstacle), §DI (moss on every roof here), §CA/§CS (the species are the place's own), LOOK_REFERENCE R3 (olive shade in green scenes) and R8 (doorways as voids). Mike's references: eight frames of the temple the forest took back, then its face towers and guardian causeway.

BUILD the kind, 150–300 m across (ruins.json across_m): two or three concentric enclosures of long low galleries with square columns, carved doorways (gopuras) through each wall, courtyards knee-deep in tumbled blocks, five towers rising in diminishing tiers at the centre, a moat outside; on flat lowland near water in indomalaya jungle and monsoon forest only, never on a crag; at most two a world. The gate towers carry a great serene face on each of four sides; the causeway over the moat is lined with rows of crouching guardians holding a serpent's body as a balustrade, half scowling and half serene; the gate's corners are a three-headed elephant pulling lotus trunks from the wall; reliefs of dancers and guardians on the walls, nobody's gods by name (§BO). ROOT-TREES: one on about every third gopura and gallery: an old-growth tree of the place's own species (Ficus benghalensis, Ficus religiosa; Tetrameles once filled) whose trunk stands ON the roof and whose roots pour down over the lintel and the wall to the ground, bark pale against dark stone; build the root drape as a few thick tapered tubes following the wall's surface, not a particle. Then ruins.json root_trees for everything else: any other old monument in jungle, rainforest, dry forest and cloud forest carries one or two; a camp's remains none. The delve walks inward: enclosure, gallery, inner enclosure, the central tower as the heart, a collapsed gallery on the far side as the way out; hearth rings. Smoke: the delve's hearths vent through the towers. A living camp here wears ochre (#CC7722, §CL's colour; first guess).

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 19 — The wandering fire: thirteen in the desert — §DP

**Status:** built b545e71
**Mike sees:** A line of cold fire rings across the sand a day's walk apart, and at the end of it, at night, thirteen figures round a fire that wasn't there yesterday.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DP of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DP and its three open calls (each written at its default), data/uniques.json → uniques.wandering_fire (and the file's _help: one rig, a pose and a palette, never a new body), the sacred fig entry as the pattern (Uniques wires it), §BP (fire is never made: they carry a coal), §CQ.4 (the ember carrier), §AX and fuel.json (what the desert gives), §BA (a safe circle), §CY.2 (the circle loops, if built), §BF (walking pace), §CV (no column at night; the glow is the beacon).

BUILD the second one-of-a-kind, the first that moves: thirteen cloaked figures on the shared rig at folk scale, one set apart by an undyed pale robe with the hood down (#E8E0D0), the twelve in the desert folk's palette; one group per world, in the hot desert and thorn scrub and the wadi and oasis nests only; never a settled camp, never a ruin, no store, no woodpile. By day they WALK, on and off the roads, a few kilometres a day, carrying their flame as a coal (an ember carrier, no light); at dusk they lay a fire where they are from the desert's fuel and sit round it in §CY.2's circle loops (watch the fire, warm hands, eat, doze; no pipe); at dawn they walk on and leave the ring. The rings persist: a cold fire ring with ash at each night's camp, a day's walk apart, so the trail can be followed. Their fire is a FireStore like any (fuel, embers, out) and a safe circle (§BA): the lurkers keep off it; a coal from it is free to take (§CQ.4); it smokes by day only if they rest. Mute like all folk; the log's line the first time you come within reach: "Thirteen sit round a fire in the sand." Play names nobody (§BO; the open call, at its default). While unloaded they move as a number (a position advanced by their day's walk each tick, the way camps tick), so the trail is real when you find it.

CHECK (tools/wandering_fire_check.gd, headless): exactly one group on seed 7731, in a desert biome; over ten simulated days its night positions are 2–6 km apart and never the same; a cold ring exists at each past night's position; by day the figures are moving and their fire is out; at night the fire is lit and thirteen figures are within its radius; the dread meter drains inside its radius; the log line fires once. Walkabout once: find them by their trail at dusk.
```

## 20 — The old man on his ox — §DQ

**Status:** built c0fae2b
**Mike sees:** An old man on a slow dark ox on the high pass road, hood turning to hold you a beat as you pass, then on toward the pass; at dusk he stops where he is.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DQ of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DQ and its open calls (written at their defaults), data/uniques.json → road_regulars.ox_rider (and the block's _help: §DM.7's cast, this is its first entry), §BF (travellers: mute, never stop, the hood tracks and holds, unharmed in the dark; travellers.json), §CR.4 (the great ranges' routes to their passes), §DM (the road), data/tomes.json → tao (found at the pass gate, filled false: it does not spawn until the text exists, §DL's rule), §BL (the gate's camp), §0 (beasts keep creature bodies).

BUILD: (1) THE OX, a new creature body in the sculpted-body system (creature_bodies.gd / sculpted_bodies.gd): a domestic ox, heavy and slow, horns curving forward and out, a dull black-brown coat (#2A2220), no load, no plough; a walk gait under the player's walk; it grazes when stopped. (2) THE RIDER: the shared rig seated on it, hood up, a plain dark robe (first guess), using the §BF traveller rules: mute, never stops for you, the hood turns and holds a beat past comfortable (travellers.json head_look), the dark ignores him (dread.json rules.ignore_travellers). (3) THE HABIT (§DM.7: one habit, one stretch, one hour): one per world, on the high roads of one great range (§CR.4), riding toward its highest pass, westward; by day he rides at the ox's pace; at dusk he stops where he is, the ox grazes, no fire; at dawn he rides on. On a sphere he never arrives: when he reaches the pass he carries on over it and round, and is always to be found on that range's pass roads. Unloaded, he moves as a number like the wandering fire. The log, once: "An old man rides an ox up the pass road, slowly." Play names nobody (§BO). (4) THE GATE, first guess (one line to strike if Mike says so): a gatehouse at the highest pass of his range, a small camp with its keeper (§BL, one or two folk, its own hearth, counted for §CU and §CV), and the second tome lying there: tomes.json tao, found_at pass_gate, which spawns only once data/tomes/tao_legge.txt exists (§DL's rule).

CHECK (tools/ox_rider_check.gd, headless): exactly one rider on seed 7731, on a great range's road; over ten simulated days his positions advance along the road toward the pass and stop at dusk; the ox's speed is under the walk; the hood turns for a passing player and the body never breaks stride; dread never targets him; the gate camp exists at the pass with a lit hearth; with no tome text file, no tome lies there. Walkabout once: pass him on the road at midday.
```

## 21 — The long wall — §DS.1

**Status:** built 8c59923
**Mike sees:** A wall running over the ridges for miles with towers at intervals, broken in places, a road along its top.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS.1 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS.1, data/ruins.json → styles.long_wall, §DM (the road: the wall's top is a road kind, with §DM's grade rules), §CJ, §CV, §BQ (stone remains, earth cores melt).

BUILD the kind: a wall 3–12 km long following a ridgeline, 5–8 m high, towers every 250–500 m, broken in stretches (gaps, fallen lengths, a tower collapsed), a road along its top joined to the road network at the gate towers; east_asia_temperate and central_asia, on the steppe edge, mountains and cold desert; at most two a world. The delve is the gate towers' vaults: down into the undercroft, the heart there, a postern on the far side as the way out; braziers; the towers vent through wall flues. The first linear monument besides the aqueduct: it must stream in chunks like the roads do, not as one mesh.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 22 — The carved cliffs — §DS.2

**Status:** built ffc23f7
**Mike sees:** Facades cut into a sandstone canyon wall, reached through a slot canyon, the tombs behind them.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS.2 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS.2, data/ruins.json → styles.carved_cliffs, §CK (the slot canyon and wadi nests), §CJ, §CV, §BQ.

BUILD the kind: 3–9 facades cut into a sandstone canyon wall, 8–30 m tall, columns and pediments carved in the rock face (relief, not free-standing), entered through a slot canyon or along a wadi; palearctic and afrotropic hot desert, canyon and badlands, sandstone only; at most two a world. The delve is the rock-cut tombs behind the facades: in through the doors, the deepest tomb the heart, a shaft to the canyon rim the way out; hearth rings; smoke out the facade doors with soot above them (no stack). Overgrowth: a creeper in a crack, lichen (§DI's dry row).

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 23 — The cliff dwelling — §DS.4

**Status:** built 719f939
**Mike sees:** A town of fitted sandstone rooms and round towers filling an alcove under an overhang, ladders and kivas in the plaza in front.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS.4 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS.4, data/ruins.json → styles.cliff_dwelling, §CK (the mesa nest and its alcove; §CM's hanging garden at the alcove's seep), §CJ, §CV, §BQ (the alcove is its roof, so the stone stays nearly whole). Mike's references: Cliff Palace, a smaller alcove ruin, the great kiva.

BUILD the kind: 20–150 fitted sandstone rooms in two to four storeys filling a sandstone alcove under an overhang, round towers, ladders between levels, kivas (round sunken rooms with a firebox and a vent) in the plaza in front; nearctic canyon, cold desert and sagebrush at the mesa alcove nest with water below; at most three a world. The delve: the great kiva as the heart and stores cut into the alcove's back, a ladder to the alcove's rim as the way out; hearth rings; smoke out the kivas' vents and the roof hatches. It needs the alcove set piece (§CK: anything with a roof is a mesh) at a size that holds it.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 24 — The brick city — §DS.6

**Status:** built 6666f21
**Mike sees:** A tell of melted brick on a desert river with the foundation walls standing in it as a maze, a processional way between buttressed walls, and the arched gate still standing with its blue glazed face.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS.6 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS.6, data/ruins.json → styles.brick_city (and styles.ziggurat, which stands at its centre), §CK (the levee and oasis nests), §CJ, §CV, §BQ (sun-dried brick melts into a mound; fired brick facings stay), LOOK_REFERENCE R8 (the glazed gate is a saturated blue material that never glows). Mike's references: the processional way, the gate, the maze of foundation walls, the palace mound above the palms.

BUILD the kind, 200–400 m across: a tell (a low mound of melted brick) with the foundation walls standing in it as a waist-to-head-high maze, a processional way between high buttressed walls leading to an arched gate with pilasters whose face is glazed blue (#1E3FD0) with animals in relief (aurochs, lions, a dragon of our own), a palace mound to one side, the existing ziggurat style at the centre; palearctic and central_asia on a desert river's floodplain (hot desert, oasis, steppe by a river; the levee and oasis nests), flat, never a crag; at most two a world. The delve: the vaulted stores under the palace mound, the deepest vault the heart, the well shaft to the river bank the way out; braziers; smoke out the courtyards' roof hatches.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 25 — The stone heads (and the oceania realm) — §DS.3

**Status:** built b0965f2
**Mike sees:** A row of great stone heads on their platforms along a treeless coast, facing inland, with nothing to say why the trees are gone.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS.3 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS.3, data/ruins.json → styles.stone_heads (waits_for the oceania realm), scripts/ecology/realm_map.gd (the nine realms are code: afrotropic, palearctic, neotropic, andes, central_asia, nearctic, east_asia_temperate, malesia, indomalaya, plus madagascar as a special case), §AA (the realm gate), §CS (communities are dealt per land), §BL (the restraint rule, which this monument is as a landscape), §BQ.

BUILD, in two steps. (1) THE REALM: add oceania to RealmMap as a tenth realm for isolated subtropical islands and coasts far from the other lands (your call how the seed deals it: first guess, a share of the small isolated landmasses in the warm temperate and subtropical bands); report in PROGRESS what plant communities it has today (none are tagged for it, so it draws from the nearest land until a fill tags some: §CS.4's short-biome rule) so chat can fill it. (2) THE KIND: 5–15 great stone heads of volcanic tuff, 4–10 m tall, on a long stone platform along a treeless grass coast, facing inland; one site per world, in oceania only, on coastal grassland (tallgrass or shortgrass prairie by the shore, beach, rocky shore), never where trees grow: the builder clears nothing; it places only where the land is already treeless. The delve is the quarry's cave in the hill behind: an unfinished head still in the rock is the heart, the quarry's open face the way out; hearth rings. No smoke outlet (no built hearth). Nothing in the game says why there are no trees (§BQ).

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 26 — The terraced pueblo — §DS.5

**Status:** built 373561d
**Mike sees:** A stepped adobe town of many storeys on open dry ground, melted to a mound with its walls still standing in it.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS.5 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS.5, data/ruins.json → styles.terraced_pueblo, §CJ, §CV, §BQ (adobe melts). Mike's "pueblo pyramids", read as the stepped adobe towns of many storeys.

BUILD the kind: a stepped adobe town of three to five storeys on open ground near water, each storey set back from the one below, ladders and roof hatches, melted to a mound with walls standing in it; nearctic cold desert, sagebrush and canyon; at most three a world. The delve: the kivas (round sunken rooms) and stores, the great kiva the heart, a roof hatch the way out; hearth rings; smoke out the roof hatches. Overgrowth: §DI's dry row.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 27 — The stone circle — §DS.7

**Status:** built 51dcffb
**Mike sees:** A ring of standing stones, some with lintels, on open grass or moor, with a ditch and bank round it.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS.7 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS.7, data/ruins.json → styles.stone_circle, §BC (standing stones are already waymarks: this is the great one), §CJ (the one allowed exception: the delve is a souterrain, or none), §BQ.

BUILD the kind: a ring of 9–30 standing stones of the local hard stone, 2–7 m tall, some pairs carrying lintels, inside a ditch and bank, on open grassland or moor (tallgrass and shortgrass prairie, wet meadow, bog), palearctic, never in forest or on a slope; at most two a world. The delve, where the seed gives one: a souterrain, a low stone-lined passage from a hidden mouth at the bank to an end chamber (the heart) and a second mouth (the way out); no fire-holders. No smoke. The wind in the stones is §DI's bed (a moan through the lintels when the gust passes 6 m/s).

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 28 — The tower house and the broch — §DS

**Status:** built 0cb81c7
**Mike sees:** On the cold wet coasts: a tall narrow keep inside a low wall, and a drystone round tower with a passage under the ground beside it.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DS of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DS (new styles of kinds we have), data/ruins.json → styles.tower_house (a castle style) and styles.broch (a tower style), the pyramid styles as the pattern for how a style is picked by realm and biome, §CJ (castle: the undercroft; tower: the stair), §CV (the castle's chimney stack; the broch's open roof), §DI (lichen and moss).

BUILD two styles, picked by spawn.realm and spawn.biomes where the castle and tower kinds already place: THE TOWER HOUSE, a tall narrow rubble-stone keep of 12–20 m inside a low wall, harled (rendered), on the cold wet coasts and moors (palearctic maritime forest, rocky shore, tundra, bog, temperate deciduous); its delve the vaulted undercroft and a pit prison, a postern the way out; braziers; the castle's chimney stack. THE BROCH, a drystone round tower of 8–13 m on a base of 14–20 m, double-walled with a gallery between the walls, on the coasts and moors (rocky shore, tundra, bog, maritime forest); its delve the gallery between the walls and then a souterrain to an end chamber (the heart) with a second mouth (the way out); hearth rings; a central hearth under an open roof, no stack.

CHECK (tools/northern_styles_check.gd, headless): on seed 7731 every tower house and broch sits in its biomes and realm; a castle in the hot desert never takes the tower house; each has its delve and way out; the walkabout once at one of each from the approach.
```

## 29 — The hewn temple, found from above — §DZ

**Status:** built 40ca950
**Mike sees:** The road comes along a hilltop, the ground opens at your feet, and a whole temple stands below you in a pit of living rock, elephants carved round its base, halls dug into the walls.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DZ of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DZ, data/ruins.json → styles.hewn_temple (kind own) and styles.carved_cliffs (the difference: Petra's facades are cut INTO a face; this is cut OUT of the hill), §BB (the reveal, inverted), §CK (the escarpment nest, the volcanic field), §CJ, §DM.5 (the approach runs along the rim), §DI's dry row.

BUILD the kind: a pit 60–120 m across cut down into a basalt escarpment, and in the middle a temple left standing free in the living rock: towers, courts, two free-standing pillars, a row of elephants carved round the base, reliefs on every face (nobody's gods by name, §BO); halls dug into the court's walls on two or three levels, columned, with ribbed vaults, a seated figure with its hands in its lap in the deepest apse. The road arrives along the hilltop at the rim (the approach), so the first view is DOWN into it; the way down is a stair cut in the court's wall. Indomalaya, tropical dry forest, thorn scrub and savanna, on a basalt escarpment; at most two a world. The delve is the halls as they stand: in through the court, up the cut stairs between levels, the deepest hall the heart, a stair to the hilltop the way out; hearth rings; no smoke. Dark basalt: navy shade. Overgrowth: grass on the hill above, a creeper down the court walls, lichen.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 30 — The hanging gardens — §DT

**Status:** built 74439f5
**Mike sees:** A stepped mound of vaulted brick on a desert river, water stepping down its terraces, and the mountain trees a king planted gone wild over it.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DT of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DT, data/ruins.json → styles.hanging_gardens (kind own; its garden.hand_carried and garden.local lists), §BP (irrigation is a rule: a plot by a channel counts as watered), §CS and §CT (the one place a community grows outside its land before the player plants anything), §BE (water stepping down), §CJ, §CV, §DI, R6, R10.

BUILD the kind: a stepped mound of vaulted brick 20–35 m high and 80–150 m across on a desert river's floodplain (palearctic and central_asia; hot desert, oasis, steppe; the levee and oasis nests), one a world. A channel drawn from the river upstream runs onto the top terrace and steps down the terraces with a small fall at each wall into the river (§BE's falls; R6). The garden is overgrown, not tended: on the terraces, old-growth trees of the hand_carried species (juniper and cypress are in the catalogue; cedar is a later fill, so use the juniper for it until then) grown past the top of their bands and rooting into the vaults, and the river's own date palms, pomegranates and tamarisk below (the fig is a later fill); seedlings in every crack, moss and ferns where the water runs. These plants place here by the entry, as §CS/§CT's one generator-placed exception, and nowhere else outside their lands. The delve is the vaulted galleries under the terraces, level by level, the channel running through them, the cistern where the water-lift stood as the heart, the channel's mouth at the river as the way out; hearth rings; the gallery hearths vent through the terraces' drains.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 31 — The ruined abbey — §DU

**Status:** built 40a3af1
**Mike sees:** A great church with its roof gone: arcades and lancet windows framing the sky, one tower, a grass floor, and on a misty morning the sun through the windows onto the grass.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DU of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DU, data/ruins.json → styles.abbey (kind own) and haunt.kinds (the abbey is haunted), §DC (the ruin kind of shaft, if built: the lancets are its windows), §DI (residents in the tower and the window; the wind in the arcades; the haunt), §CV (the warming house's chimney stack), §CJ, §DN (on a headland it is a coast-road landmark), §DM.5.

BUILD the kind: a roofless church 40–90 m long: the nave's walls and arcades standing, pointed arches and lancet windows framing the sky, one tower whole or half, the floor grass, the cloister and chapter house as foundations in the turf, a warming house with its chimney stack standing; palearctic, in temperate deciduous country, maritime forest, the moor (tundra and bog edges) and on headlands over the sea (rocky shore), or on a river valley's floor by the water; at most two a world. The delve: the crypt and the undercroft under the east end, the crypt's chapel the heart, the night stair up into the cloister the way out; braziers; smoke by the castle's chimney stack at the warming house. Register it with the haunt (§DI) as a haunted kind at the data's share, and with the residents (jackdaws in the tower by day, an owl in a window at night). Overgrowth at §DI's wet row: moss on the ledges, ferns in the sills, ivy up the tower; lichen on the headland ones.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 32 — The temple park — §DW

**Status:** built 6de4562
**Mike sees:** Brick platforms, rows of roofless columns, stupas and ribbed towers, seated figures in niches, and lotus ponds with the towers reflected in them, all under open sky.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DW of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DW, data/ruins.json → styles.temple_park (kind own; its spawn.min_km_from the temple city), §DR (the closed cousin: keep them apart), §CS.6 (the lotus's niche), §CJ, §DI's dry row, R6.

BUILD the kind: a flat precinct 200–400 m across in indomalaya tropical dry forest and the jungle's open edges, on flat lowland with still water, never within 5 km of a temple city; at most two a world. Stepped brick platforms; grids of roofless laterite columns (the roofs rotted, §BQ); bell-shaped and lotus-bud stupas; two or three tall ribbed corn-cob towers; seated figures in brick niches, hands in the lap, faces worn smooth, nobody by name (§BO); lotus and lily ponds between the platforms with the towers reflected in them (R6); one great old fig at a pond's edge with its roots in the bank (a root-tree, ruins.json root_trees). The ponds are water plots for the lotus community once Nelumbo and Nymphaea are in the catalogue (a later fill): place the pond, and let the plants come with the data. The delve: the great stupa's relic crypt reached by a shaft, the stores around it, the crypt the heart, the shaft up the tower's side the way out; hearth rings; open fires only. Overgrowth: grass over every platform, a creeper on the columns, moss at the ponds' edges.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 33 — The pillar shrines — §DY

**Status:** built fc29d06
**Mike sees:** A valley of stone pillars out of mist, a shrine on every top, stairs cut up the faces, and bridges between them: stone ones standing, rope ones gone but for their posts, root bridges still growing.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DY of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DY, data/ruins.json → styles.pillar_shrines (kind own; its bridges block), §CK (the karst towers nest), §BT (the canopy folk and the living root bridge), §BC (forks legible before you commit; one-way gates), §BY (half the bridges are out), §AU (no wall climbing: the cut stairs are the only way up), §DA (rope sways in the gust), §CJ, look.json mist (pooled in valleys).

BUILD the kind: a valley of 6–15 pillars 50–150 m high (the karst towers nest, and a sandstone pillar variant of it) in cloud forest, temperate rainforest, jungle and monsoon forest (east_asia_temperate and indomalaya), where the mist pools; at most two a world. A small shrine or hermitage on each top; stairs cut into the rock faces (walkable at §CR.5's pace, the only way up); and the bridges by span: stone arches over short gaps still stand; rope-and-plank bridges over long gaps are gone, only stone abutments and anchor posts left, except about one in six that still hangs and sways in the gust (§DA); living root bridges of fig where canopy folk lived, standing and growing. The result is §BC's fork in the air: from one top you see the next shrine across a gap with no bridge, and the way is another pillar's stair or round through the valley floor. The delve is inside a pillar: a cave at its foot and a stair cut up through it to the summit shrine (the heart); a bridge or the cliff stair the way out; hearth rings. A camp here is canopy folk (§BT).

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 34 — The old colonnade — §DV

**Status:** built a4711a9
**Mike sees:** A ring of tall plastered columns standing in a clearing among old oaks, the house they held long gone, an avenue running to it from the road.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DV of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DV, data/ruins.json → styles.colonnade (kind own), §BQ (the imperishable part, and the ending unnamed), §DM.4 (the avenue), §CJ, §BE (still water in the cellar), §CD (resurrection fern on the limbs), §DI's wet row.

BUILD the kind, the smallest in the set: 20–30 plastered brick columns 10–14 m tall with iron capitals standing in a ring on the footprint of a house of wood that burned, a few fallen, the brick cellar open to the sky in the middle, and a planted avenue of old oaks (§DM.4, taller and older than the wild) running to it from the road; nearctic, in the humid south (floodplain forest, maritime forest, the southern temperate deciduous woods) on a rise above a river; at most three a world. The delve: the brick cellar and the cistern under the footprint, half flooded (wade), the cistern the heart, the cellar's outside stair the way out; hearth rings; no stack. Overgrowth: vines on the columns, ferns at their feet, the oaks' limbs over everything with resurrection fern on them.

EVERY NEW KIND, the same way (§DS's rule): a new Ruins.Kind value with its name_in_play as the KIND_NAMES entry; placed by the sites pass only where its ruins.json spawn (realm, biomes, nest, needs, never) holds, capped by per_world_max and chance; built by RuinBuilder from a small kit of parts, big texels and clean silhouettes (R9), hard shadows; its delve by its ruins.json delve block (§CJ: rooms, the heart, a way out, fire-holders from delves.json by_ruin, overrun as §CN); its smoke outlet from smoke.json outlets.by_ruin (§CV, if the column is built); its overgrowth from §DI's rules when built; §DM.5's straight approach runs at it. Real references live only in the entry's source line: never a real name in play (§BO).

CHECK (a tools/<kind>_check.gd, headless): on seed 7731 the kind places only where its gate holds and never past per_world_max; every one has a delve with a heart and a way out; the builder's triangle count per instance is within the budget of a castle; the walkabout once, at one of them, from the straight approach.
```

## 35 — The columns: columnar basalt as a nest — §DX

**Status:** built 21ecf1b
**Mike sees:** A stair of hexagonal stones going down into the sea with water in every cup; a cliff of columns with a fall over it; a sea cave with a roof of columns and a ledge of broken stumps along the wall.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §DX of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from that session. One thing at a time. No screenshots after every step: check with headless numbers (a tools/*_check.gd of your own), run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Then prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true to the built game, remove the [NOT WIRED YET] prefix from every data block you wire, pull with rebase before you push, never force. Explain what you did to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, and what he can tune in the data.

READ: §DX, data/landforms.json → landforms.columnar_basalt (and its two variants, organ_pipes and columned_sea_cave), §CK (nests: what one gives a camp, the hearth spot, the camp loop; anything with a roof is a mesh), §CY.3 (a flat stone is a seat), §BG (the sea cave's boom is a source), §BD (the mouth is the only light), §CH (the night roster dens in it), §BC (a road into the sea; the log line), R6. This is a NEST, not a ruin: it goes in the sites pass with the other landforms, as a tier-2 set piece.

BUILD the nest in its three forms: (1) THE CAUSEWAY on a volcanic coast (rocky shore, volcanic field; basalt; an old flow at the water): a field of close-packed hexagonal columns 30–50 cm across with stepped tops, 6–12 m tall at the landward edge and vanishing under the sea at the seaward one, the whole reading as a stair of flat stones going down into the water; rain and tide pools in the cups with green weed (bright water, R6); a hexagon tile at 16 texels a metre on the tops and faces; the camp's floor and seats are the column tops, the hearth spot the highest dry step above the spray; the lower steps awash at high water. (2) THE ORGAN PIPES inland where a river or a fall cuts basalt country (canyon, volcanic field, tundra, maritime forest): a cliff of columns 10–40 m tall, the fall pouring over it (reuse the waterfall), the hearth spot at the foot by the pool. (3) THE COLUMNED SEA CAVE on a basalt cliff coast facing open sea: a cave hollowed into the column cliff, the roof the underside of the columns, the sea running in (water with §BE's swell), a ledge of broken column stumps along one wall above the water to the back, the mouth the only light, a boom with the swell as a §BG source audible from the clifftop; never a camp (no dry floor); the night roster dens in it; the hearth spot on the clifftop. The log line once at the causeway: "A road of stone steps goes down into the sea." Nothing says whether anyone made it.

CHECK (tools/basalt_check.gd, headless): on seed 7731 every columnar basalt site sits on basalt where the gate holds (an old flow at the sea or a river), the three forms each place at least once where their biomes exist; the causeway's hearth spot is above the high-water line; the sea cave's hearth spot is on the clifftop and the cave holds no camp; the sea cave's source plays only inside its max_distance; the hexagon tile reads at 16 texels a metre (the tile is 32 px over 2 m, or the house tile size). Walkabout once: the causeway at low tide, from the coast road.
```

## 36 — Three hits, no bar, "Good night" — §EA

**Status:** built 6c08095
**Mike sees:** A creature hits you and the edges of the screen darken; a second hit and your heart pounds; a third and the dark closes in, "Good night" in red, and you wake at a fire with folk.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EA of docs/design/RECONCILIATION_2026-09-30.md, from data/harm.json. No screenshots after every step: check with a headless tools/harm_check.gd, walkabout once at the end. Prepend a PROGRESS entry, keep HOW_TO_RUN true, remove [NOT WIRED YET] from harm.json, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

BUILD, ambient profile only (the ninja game keeps PlanetPlayer.hp and the status bar untouched): hide the HP meter; count creature hits (knockback counts) within harm.window_s; hit 1 = vignette + slight desaturate + muffle; hit 2 = deeper, plus a fast heartbeat; recovery steps back per harm.recover, heartbeat settling first, then the dark pulling back; hit 3 = close the frame to black, "Good night" big and red inside the 480-line frame, hold, fade, then hand to the existing §DE wake (camps.json wake_found: home hearth else nearest lit fire with folk, lost days, the found line, "Struck down by a {creature}"). Shade stays navy in the vignette, never grey.

CHECK: three hits inside the window take you, three spread past it do not; stage 2 plays the heartbeat, stage 1 does not; after calm the stages fall back in order; the wake lands at §DE's fire. Walkabout once: take two hits and recover.
```

## 37 — No metal, and a camp can be fifty — §EH

**Status:** built d5dbe75
**Mike sees:** Nothing new on screen. The marsh folk's maker is a reedworker, no camp anywhere mentions iron, and a camp can grow to fifty folk before it stops.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EH of docs/design/RECONCILIATION_2026-09-30.md (no metal; the craft ceiling is clay, bone, stone, wood and fibre), plus the one number §EI changes (camps.json sim.population.village_cap 24 → 50), and nothing else from that session. No screenshots after every step: check with a headless tools/no_metal_check.gd of your own. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove the [NOT WIRED YET] prefix from camps.json _help.village_economy's first clause only if you wire village_cap (you will), pull with rebase before you push, never force. Explain to Mike in plain English at the end what changed and what he can tune.

READ: §EH, §BO (the old bog-iron exception, now gone), §BN (the maker is never a smith), §BQ (no slag mound), data/peoples/README.md rule 4, data/peoples/marsh.json (maker is now reedworker, technique bog_iron removed, ruin signature smoke_floor), data/techniques.json bog_iron (retired: true), data/villages.json specialties glass and mining (retired), camps.json sim.population.village_cap.

BUILD: (1) Sweep the engine for metal: grep scripts/ for bog_iron, "bog iron", smith, bloomery, slag, iron, forge, smelt, ore. Any code path that picks, names, draws or logs them goes: Peoples.* maker names and props (CampProps), Techniques.* (a technique row with retired: true is never taught by a headman, never listed, never logged), RuinMarks and ruin signatures (no slag mound is ever placed; marsh gets smoke_floor from its file), Villages/VillagePlan specialties (a specialties row with retired: true is never rolled). "Iron-red water" at a marsh seep is scenery and stays. (2) village_cap: CampSim reads sim.population.village_cap (50) wherever 24 was a constant; births and the ladder gates are unchanged (sim.ladder_gates.folk_for_specialist stays 8). (3) Nothing with an edge: confirm the §ED.7 rule still holds with the smith gone (spear and bow are finds or a maker's work of wood, bone and stone; items.json needs no change unless a metal word is in a name or description: fix the word).

CHECK (tools/no_metal_check.gd, headless): on seeds 42 and 7731, walk every placed camp and village: no maker named smith, no technique bog_iron taught or listed, no slag_mound signature, no village specialty glass or mining; a marsh camp's maker is reedworker and its ruin has smoke_floor; CampSim's cap resolves to 50 and a camp fed past 24 keeps growing to 50 then stops; grep of scripts/ for the metal words returns only comments that say "no metal (§EH)".
```

## 38 — The workshop: one hut, two benches, the hearth outside — §EL

**Status:** built d4b159e
**Mike sees:** At a camp that has reached storage, a second roof beside the fire circle: a workshop in the people's own materials. Inside, a soft bench (a hide on a frame, cord being twisted, a basket) and a hard bench (a knapping floor, bone in a row, a bow drill); folk sit at one or the other and work, with different motions and sounds; the hearth outside has the stew pot and the smoke rack; a kiln hump stands downwind where there is a potter. One thing on the porch tells you which people this is from the road. By day the folk are at the hut; at dusk they are at the fire.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EL of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.workshop and every data/peoples/*.json huts block, and nothing else from that session. One thing at a time. No screenshots after every step: check with a headless tools/workshop_check.gd of your own, run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the workshop clause of camps.json _help.village_economy and from the huts blocks you read, pull with rebase before you push, never force. Explain to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, what he can tune.

READ: §EL (all of it), §BN (the maker), §BV–§BW (jobs and pieces: the benches are the §BV work_at_hearth job grown up and moved indoors), §CY (the fire circle: seats, pose, idles; the bench idle is the same seated base pose), §BO (the biome dresses the people), §BQ (the knapping floor and the kiln hump are the live versions of the ruin signatures), §EK.1 step 2 (the carcass will go in this hut's door: leave a door and a named spot for it, nothing more), R9 (big texels, clean silhouettes), R6. camps.json sim.workshop (benches, verbs, idles, sounds, skills_distinct, one_folk_one_bench_at_a_time, cross_bench_per_day_max, maker_bench_share, player_brings_to_bench, day_heart, night_heart, porch_seat); each people file's huts (workshop_form, soft, hard, hearth, kiln, porch_sign); sim.jobs if §BV's jobs are built, and if they are not, build the smallest walker this needs (a folk walks from the fire circle to a bench, sits, works, walks back at dusk) and say so in PROGRESS.

BUILD: (1) At every camp at the storage rung or above (CampSim ladder), place ONE workshop hut 6–10 m from the fire, door toward it, built by CampProps from the people's huts.workshop_form in the camp's own stone/timber/thatch/hide/reed (the same tints the shelter uses), one roof, open or half-open on the fire side so the benches read from outside; a porch seat by the door (sim.workshop.porch_seat). (2) Two benches inside: soft and hard, each a flat surface (log, slab, mat on the floor) with 3–5 props from the people file's huts.soft / huts.hard, as small meshes or cards at 16 texels a metre, the props that exist in the piece vocabulary (camps.json store.pieces and data/animal_use.json pieces_vocabulary) reused rather than redrawn. (3) The hearth station is the existing fire circle: add huts.hearth's props (stew pot on stones, smoke rack, rendering pot, this people's lamp or candle unlit by day) around it. (4) The kiln: where the people's huts.kiln is non-empty, a clay hump 4–8 m from the hut, downwind of the camp's prevailing wind (wind.json), smoking (smoke.json hearth.look, thin) when a potter is at it. (5) The idles: two new seated work loops from the §CY base pose, soft (sew_with_awl, twist_cord, scrape_hide, plait_basket) and hard (knap, grind_axe, bow_drill, hollow_bowl_with_coal), each with its own small motion and its own sound from sim.workshop.benches[].sounds (audio.json rows, short loops, quiet, inside §BG's falloff); a folk at a bench plays only that bench's loops; a folk crosses benches at most cross_bench_per_day_max times a day and never does both at once; the maker sits at a bench maker_bench_share of the gather hours. (6) Day heart / night heart: during loop.gather_hours the non-gathering adults sit at the benches or the porch and the fire circle is nearly empty; at dusk_form everyone comes to the fire (§CY unchanged). (7) The player: bring_material_for_maker (sim.player_nudges) now lands on the bench that works it per sim.workshop.player_brings_to_bench: drop it on the soft or hard bench and it joins that bench's props. (8) porch_sign: one mesh or card from huts.porch_sign at the door, big enough to read at 40 m (§BU silhouette distance).

CHECK (tools/workshop_check.gd, headless): on seed 7731 every camp at or past storage has exactly one workshop with a soft and a hard bench and a door; no camp below storage has one; a marsh camp's porch_sign is the reed-mat press and a tundra camp's is the burning stone lamp; a folk at a bench plays only that bench's idles; no folk is counted at two benches in one tick; the maker's bench time over a game day is within 0.1 of maker_bench_share; during gather hours the fire circle holds only the keeper and the children; the kiln appears only where huts.kiln is non-empty and sits downwind within 30° of the mean wind; triangle budget of a workshop with props ≤ a §CY fire circle with its seats ×2. Walkabout once: the opening river camp from the road at midday (the workshop beside the fire, folk at the benches).
```

## 39 — What a camp needs, and the trades that follow — §EI

**Status:** built defc49a
**Mike sees:** A folk carrying a pot to the river and back, the pot sitting by the hearth. As a camp grows, its benches fill in a real order: cord and baskets first, then a kiln and pots, then hides, then a loom, then the lamp-maker; a camp never shows a craft its land cannot feed, and never more than three.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EI of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.needs and sim.trades, and nothing else from that session. It sits on prompt 38 (the workshop and its benches); if that is not built, stop and tell Mike. No screenshots after every step: check with a headless tools/trades_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the needs and trades clauses of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EI (all), §BM (the four fundamentals and the ladder; sim.ladder, sim.ladder_gates), §BL (the store, the restraint rule), §BV–§BW (a trip is a piece), §EL (which bench each trade lives on), each people file's huts.trades (the trades that life can reach) and materials.gives.

BUILD: (1) sim.needs: a WATER job in sim.jobs.kinds (reuse gather): a folk walks to the camp's water (spring, river, lake or well within needs.water.reach_m: the nearest real water the planet has; a well only at a village) carrying a pot, pauses, walks back, and the pot lands by the hearth as the piece water_pot_by_hearth (store.pieces vocabulary: add the row); trips_per_day trips, counted by the camp's folk count; no store number changes (water is never short; this is the fundamental made visible). A shelter mend: every needs.shelter.mend_job_days a folk carries one piece of the shelter's own material (from the people file's shelter.materials) to a hut and it goes on the roof or wall: one visible patch. (2) sim.trades: for each row in trades.order, a trade is PRESENT at a camp when the camp is at or past the row's rung, every "needs" holds (fibre_or_bark_in_reach, clay_in_reach, timber_in_reach, flint_obsidian_or_fine_stone_in_reach: from the biome's plants and the landform's rock within loop.gather_reach_m; hunt_or_herd: the camp hunts (prompt 40) or its fundamental is herd; fibre_crop_or_wool_herd: a fibre crop in the store or a herd; fat_or_oil_or_resin: animal_use fat pieces present, oil plants in reach, or resin conifers in reach), every "after" trade is present, and the trade is in the people's huts.trades. (3) A present trade adds its visible props to its bench (soft / hard / hearth / kiln) from trades.order[].visible, in order; at most trades.show_max trades show at one camp (the earliest in order win); generalist true trades need no maker; generalist false trades appear only once the camp has a maker (sim.specialists.maker), and the maker's bench is that trade's bench. (4) trades.ceiling and trades.never are a guard: nothing in the sim ever creates a market, money, a chief, a wall or a standing hunter; a comment at the top of CampSim says so with §EI.4.

CHECK (tools/trades_check.gd, headless): on seed 7731 every camp's present trades are a subset of its people's huts.trades, in trades.order, never more than show_max; a camp with no clay within reach never shows pottery; textiles never appears before cordage_basketry and leather_hide; a non-generalist trade never appears at a camp with no maker; every camp at or past storage makes at least trips_per_day water trips a game day and the water pot is by its hearth; a shelter patch lands every mend_job_days ± 1. Walkabout once: a river camp at the specialist rung with pottery present (the kiln smoking, jars at the hearth).
```

## 40 — The whole animal: the hunt, the hut, the six things — §EK

**Status:** built 2d4b6a2
**Mike sees:** An adult with a spear walks out past the gatherers and comes back carrying a hare over the shoulders, or dragging a deer on a pole. The animal goes in the workshop door and you never see it again. By evening a hide is on the frame, strips are on the smoke rack, a stew is on the fire, bone awls are in a row on the hard bench, a horn cup sits on the bench edge, and a lamp burns that was filled from the fat pot. The log says so, once per species.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EK of docs/design/RECONCILIATION_2026-09-30.md, from data/animal_use.json and camps.json sim.hunt and sim.jobs.kinds.hunt, and nothing else from that session. It sits on prompt 38 (the workshop) and needs the creature spawner's per-region numbers (§BL ecology; CreatureSpawner); if either is missing, stop and tell Mike. No screenshots after every step: check with a headless tools/hunt_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from data/animal_use.json _help and the hunt clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EK (all), §EJ.2 (the hunter never hands out his own kill; no trophy, no head on a pole), §ED.7 (edges touch only flesh and blood; the hunt is the only time a camp folk holds the spear), §BV–§BW (a trip is a piece), §EL (the benches the pieces land on), §BO (the people and biome dress the pieces), data/animal_use.json (classes, parts, pieces_vocabulary, never), camps.json sim.hunt (who, reach_m, beyond_gather_reach, carry by class, to, process_game_h, food_units by class, hunts_per_game_week, log_once_per_species) and sim.jobs.kinds.hunt, data/creatures/*.json for the size class of each species (add a size_class field to the catalogue rows if none exists: large_hoofed, small_hoofed, small_game, bird, fish, marine_mammal, reptile; say so in PROGRESS).

BUILD: (1) The hunt job: hunts_per_game_week times a week, during gather hours, one adult (never the keeper, never a teen) takes the spear (a spear mesh in hand for the walk only), walks out to a point between loop.gather_reach_m and hunt.reach_m where the creature sim's per-region count for a huntable class is above zero, pauses out of sight of the camp (kill_offscreen: nothing is animated; if the player follows and watches, the folk stands over a spot and then lifts the carry), and walks back carrying per hunt.carry: a small animal over the shoulders, a bird in hand, fish on a line, a large animal dragged on a pole (the pole drags; the figure leans). The region's count for that class drops by one (the restraint rule: a camp never hunts a class whose count is at the region's floor). (2) The hut: the carrier walks to the workshop door (sim.hunt.to) and the carcass is removed from the world; no blood, no cutting, no butchering animation ever. A timer runs process_game_h. (3) The after: when it elapses, for the animal's class in animal_use.classes, each part's piece appears on its bench (soft, hard, hearth) as one visible object from pieces_vocabulary, up to things_shown pieces (the hide and the meat always first); the food store gains food_units[class]; meat goes on the camp's food_by_life rack as §BW pieces; fat fills the people's lamp or candle at the hearth, and that night the lamp is lit from the hearth (fire carried, never made). Pieces persist as the store's do (a hide on the frame stays until the camp "uses" it: decay it after a game week into nothing, quietly; bone tools stay). (4) The log: log_once_per_species, the first time each species is brought back to a camp the player is within 120 m of. (5) never: no folk ever carries a head, a skull or an antler rack as a trophy; no piece from any class lands anywhere but a bench or the hearth; nothing from animal_use ever becomes a weapon that touches what lurks in the dark.

CHECK (tools/hunt_check.gd, headless): on seed 7731 over 14 game days at a storage-rung camp with game in reach, hunts land between 2 and 6; every hunt's carrier is an adult who is not the keeper; the carcass is never inside the camera's view at the moment it is removed when the player is at the fire (it is removed at the door, 6–10 m off); no hunt happens where the region count of that class is at its floor; after process_game_h the bench piece count rises by things_shown and the food store by food_units[class]; the lamp is lit that night and not before; a marine_mammal hunt only ever happens at a tundra or coast camp; the log line fires once per species. Walkabout once: a hunter returning to a river camp with a deer on a pole, from the road.
```

## 41 — Food passed round, the night stories, the gift — §EJ

**Status:** built 6939b24
**Mike sees:** At dusk a folk takes a piece off the food store, carries it to the fire, and everyone seated gets a bowl; the store is visibly smaller. If you sit in the circle, you are handed a bowl too. At night one folk tells, hands moving, and the others look at the teller instead of the fire. After you have brought a camp a few armfuls, someone walks up and hands you a pot, once.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EJ of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.sharing and sim.fire_circle.idles.night_stories, and nothing else from that session. It sits on §CY (the fire circle, built) and §BV–§BW (pieces); if dusk_form is not built, build it here as §CY wrote it. No screenshots after every step: check with a headless tools/sharing_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the sharing clause and the night_stories clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EJ (all), §BL (restraint is a rule, not a lecture: nothing here is a speech), §CY (dusk_form steps: walk_in_carrying, drop_piece_on_store, sit_down; the bowls and the pipe), §BW (a piece is a real object on the store), §BO (mute, plus a line in the log), §EK (the hunter's kill went to the hut, not to him), §EN (the record-keeper gives the gift when there is one), camps.json sim.sharing (meal_at_dusk_form, piece_off_store_per_meal, store_shrinks_visibly, bowls_to_everyone_seated, player_gets_bowl, player_log_once, private_stores false, hunter_hands_out_own_kill false, no_folk_commands_another, gift_back), sim.fire_circle.idles.night_stories (what, who, hold_s, needs fire_fed, listeners_look_at_teller, max_at_once, weight night 4).

BUILD: (1) The meal: at dusk_form, after the last load is dropped, one adult (never the one who hunted today, §EJ.2) walks to the food store, takes piece_off_store_per_meal visible pieces OFF it (refresh_woodpile's sibling for food: remove the mesh), carries them to the fire, and sits; every seated folk then shows a bowl prop for the eat idle; the sim's food units fall by the meal exactly as before (no accounting change: the piece leaving is the existing per-tick eating made visible once a day). The store must be visibly smaller afterwards (store_shrinks_visibly). (2) The player's bowl: when the player sits in the circle (§CY's spare seat) during the meal, the nearest folk turns and a bowl prop appears in the player's hands for the eat idle's length; the log says player_log_once the first time at each camp; no stat changes. (3) No private stores: assert in CampSim that food and wood belong to one store per camp, never to a folk; no_folk_commands_another: no animation or idle in the game has one folk standing over another; the headman's teach-on-contact (§BN) stays as it is. (4) night_stories: a new §CY idle from the data row: night only, needs the fire fed (store.feed_fire_below_units not breached), max_at_once 1 teller; the teller's hands move and the hood turns to each listener in turn; every other seated folk's notice target becomes the teller for the hold (listeners_look_at_teller), then returns to the fire; the pipe may still pass. A camp whose fire is low has no telling. (5) gift_back: CampSim counts the units the player has put on this camp's store; when it passes after_player_brings_units and once_per_camp has not fired, at the next dusk_form the record-keeper (if the camp has one, §EN) or any adult walks to the player, holds out one gift from gift_back.gifts (an items.json item the camp could make: a pot, a torch, a bowl of stew, a cord hank, a basket), it goes in the inventory, the log says gift_back.log, and the flag is set. Mute throughout.

CHECK (tools/sharing_check.gd, headless): on seed 7731 at a camp with a full food store, the store's visible piece count falls by piece_off_store_per_meal at each dusk_form and by nothing at other times; the food units match the sim before and after (no double-eating); the folk who hunted today never carries the meal; the player seated at the meal gets a bowl and the log line once per camp; night_stories never plays by day, never at a low fire, and never with two tellers; every listener's look target is the teller for the hold; gift_back fires exactly once per camp after after_player_brings_units and never before; grep of CampSim for a per-folk food field returns nothing. Walkabout once: the opening camp at dusk, the meal.
```

## 42 — Third places: the soak, the great tree, the water rock, the porch — §EM

**Status:** built 6dec101
**Mike sees:** In the heat of the day folk are not at the fire: two sit under the camp's biggest tree, one has his feet in the river with a line in the water, one leans on the workshop porch with a pipe. Near a hot spring they walk over in the afternoon and sit in it, hoods back, in the steam.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EM of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.third_places, and nothing else from that session. It sits on §CY (seats and idles, built) and prompt 38 (the porch seat); if the porch is not built, place the porch seat here. No screenshots after every step: check with a headless tools/third_places_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the third_places clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EM (all), §CY (seats by biome, the base pose, idles, the pipe, notice), §EG.4 (prospect and refuge: a back to something, a view of something), §EF.6 and §EF.10 (edges to linger on; the one landmark tree), §CV (smoke.json hearth.look: the steam uses it, white and slow), R6 (water the brightest thing), §BP (fishing_line, the technique's idle), 27 Sept §0 (hot springs at plate boundaries; the hot_spring biome), each people file's huts.third_places (which kinds fit this life, plus its own one, written as a phrase: that phrase is a seat of the people's own, placed by CampProps at the named spot if the spot exists at the camp, else skipped), camps.json sim.third_places (kinds: soak hot_spring_m, hours, hoods_back, steam, max_at_once; great_tree_bench; water_rock; hut_porch; idles; prospect_and_refuge; counts_as_rest; gather_hours_unchanged).

BUILD: (1) At every camp, after the fire circle is placed, find the third places that exist: the oldest/largest tree within 60 m (great_tree_bench: a log or flat stone seat at its foot, §CY seat kinds by biome, placed so the sitter's back is to the trunk and the view is the open side, §EG.4); the nearest water edge within 60 m (water_rock: a flat stone at the edge, feet toward the water); a hot spring pool within third_places.kinds.soak.hot_spring_m (soak: seats are the pool's rim stones; folk sit IN the water to the chest); the workshop porch (hut_porch, from prompt 38). Only the kinds in the people's huts.third_places are placed. (2) Who goes: folk who are not on a job and not at a bench go to a third place during the hours its kind names (midday_heat: the middle third of gather hours; afternoon: the last third; day: any) up to max_at_once, instead of standing idle; the fire circle's rest_hours rule is unchanged, and loop.gather_hours is unchanged (gather_hours_unchanged): third places only fill the hours a folk was already idle. counts_as_rest: no sim number moves. (3) The idles: sit, lean_back, look_out, pipe (the §CY pipe reused), from the base pose; at the soak hoods_back: the hood is down (the one time a cloaked figure's hood is down; the head is the rig's plain head, no face detail beyond R9), and steam rises off the pool from smoke.json hearth.look recoloured white, slow, lit by the scene; at the water_rock a folk who knows fishing_line plays the line idle (the pole and line, the §BP technique's own prop). (4) Notice: a folk at a third place notices the player as the circle does (§CY notice), hood only. (5) Prospect and refuge: every placed seat must have a solid thing within 2 m behind it (trunk, rock, wall, bank) and open ground or water in front; if a candidate spot fails, move it round the feature until it passes or skip it.

CHECK (tools/third_places_check.gd, headless): on seed 7731 every camp has at least one third place when its people file lists one and the feature exists; no camp places a kind its people file does not list; every seat passes the back-and-view test; the soak places only within hot_spring_m of a hot_spring biome pool and never more than max_at_once sit in it; during gather hours the count of folk at third places never reduces the count of folk on jobs (jobs first, third places from the remainder); a folk at the soak has the hood down and nowhere else does; the sim's food, wood and population are identical over 3 game days with third places on and off. Walkabout once: a hot-spring camp in the afternoon.
```

## 43 — The library: the camp book moves, the record-keeper, the winter count — §EN

**Status:** built c6a2bd8
**Mike sees:** A small hut, or a lean-to against the ruin wall, with the camp book on a shelf inside and a folk sitting at it with a quill, or walking round the camp looking at the woodpile and the new child before going back to write. On one wall, the tomes and scrolls the camp rescued from the ruins. On the other, a painted hide with one small picture per year, and a cord of knots, one per folk. At a dead camp the hide is still there, and the last picture is black.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EN of docs/design/RECONCILIATION_2026-09-30.md, from data/camp_books.json (placement_eh, record_keeper, memory) and camps.json sim.library and sim.specialists.record_keeper, and nothing else from that session. It sits on §ED.3 (CampBook, CampBookPanel, built), §DL (tomes.json, TomePanel), §BN (the three faces) and prompt 38 (the workshop, for where the library stands); if the camp book is not built, stop and tell Mike. No screenshots after every step: check with a headless tools/library_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from camp_books.json placement_eh and the library clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EN (all), §ED.3 (the camp book: one per camp, the sim's only readout, the rumour, copy to log: all unchanged, only its place moves), §BN (headman, plantkeeper, maker: the record-keeper is the fourth, at the storage rung), §BQ (the ending stays unnamed: the pictures do not say either), §CN (overrun ruins keep their library), §DL (tomes.json and the tome panel: the tomes on the wall are these), §EJ.4 (the record-keeper gives the gift), §EL (the library stands near the workshop, never inside it), each people file's huts.library (what the library is built as, and what the winter count is painted on), camps.json sim.library (rung, form, holds, tomes_max, winter_count events and dead_camp_last_pictogram, knot_cord colour_by_stage, survives_abandonment, player_reads_tomes_here), camp_books.json record_keeper (writes_after_event_game_h, idles, looks_at, gives_gift) and memory (winter_count_hide pictograms by event, knot_cord).

BUILD: (1) The library: at every camp at or past storage, a small hut or a lean-to from the people's huts.library (CampProps, the camp's own materials, one roof), 4–8 m from the fire and not inside the workshop; at a ruin camp prefer the lean-to against the ruin wall. Move the camp book: CampBook's placement is the library shelf (camp_books.json placement_eh) once the library exists; below storage it stays on the altar by the hearth as built. Reading it is unchanged. (2) The record-keeper: the fourth specialist, appearing at the storage rung with the headman (sim.specialists.record_keeper at_storage); one adult; idles write_at_shelf (seated at the shelf with the quill prop, writes_after_event_game_h after each camp-book event), walk_camp_look_at_things (walks to one of record_keeper.looks_at that exists, stands, hood tips, returns), sit_with_tome; gathers at specialist_gather_rate like the other faces; gives the §EJ.4 gift when prompt 41 is built. (3) The tome wall: up to tomes_max tome/scroll items (items.json tome, scroll; tomes.json) that the camp "rescued": at a camp in or beside a ruin, the ruin's delve tomes (§DL) that the player has NOT taken are shown on the shelf as props, and the player may read them here with the existing TomePanel (player_reads_tomes_here); taking one off the shelf is not possible (they are the camp's). (4) The winter-count hide: a hide (or the people's surface from huts.library: bark, reed mat, plaster, stone slab, clay slab) on the second wall carrying one small pictogram per game year of the camp's life, drawn as pixel glyphs at 16 texels a metre from camp_books.json memory.winter_count_hide.pictograms, spiralling from the centre as real winter counts do; the event for a year is the sim's biggest event that year by sim.library.winter_count.events order (first in the list wins ties); the current year's glyph is added at the year's end (sky/day_cycle.json day-of-year). No text anywhere on it. (5) The knot cord: a cord hung beside the hide with one knot per living folk, coloured by stage from knot_cord.colour_by_stage (undyed, ochre, indigo); re-tied when the population changes. No text. (6) Dead camps: when a camp is abandoned or overrun (§BL abandon, §CN), the library and its hide persist (survives_abandonment) with one more glyph, dead_camp_last_pictogram (a black square), and no further years; the knot cord stays as it was. The camp book persists as built. Nothing names what happened (§BQ).

CHECK (tools/library_check.gd, headless): on seed 7731 every camp at or past storage has a library and a record-keeper, and none below does; the camp book at such a camp is on the library shelf and reading it still copies the rumour to the log; a camp's winter count has exactly (years lived) glyphs and the glyph for a year with a birth and a hunt is the birth; the knot count equals the living folk count and colours match stages after a birth and after an ageing; a camp that goes dark keeps its library with a black last glyph and no new glyphs over the next 2 game years; the tome shelf shows only tomes the player has not taken and the panel opens from it; grep of the glyph atlas for any font glyph returns nothing (no text). Walkabout once: a ruin camp's library in the morning, the record-keeper at the shelf.
```

## 44 — One firelight: the torch takes the hearth's amber — §EX.6

**Status:** built cb946c1
**Mike sees:** The torch in your hand lights the stone the same amber as the hearth: walls near you go warm orange, never pale or blue-white, and a guttering coal goes dimmer and redder. The navy dark past the light, and the blue daylight down the hearth's shaft, are unchanged.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EX.6 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from §EX. Torchfire 1, the crawler (scripts/crawler/). No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from crawler.json _help.firelight, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EX.6 and the "What Claude found" list at the top of §EX; §EU.6 (the amber underground); §EB.3 (the brighter hand torch: same energy and range scales, only the hue changes now); §ET.7 (guttering warns first); torch.json light (color is now #FF6E24, light._help_color) and _help.ember (gutter_glow); look.json fire.light.color (#FF6E24) and grade.protect_hue_deg / protect_chroma; crawler.json firelight; shaders/post_grade.gdshader (protect) and CrawlerMain's post.set_night(1.0).

BUILD: (1) One colour: Torch.light_node, planted torches, CrawlerFires' hearth and sconces, and any other fire light in the crawler take one firelight colour. Make look.json fire.light.color the single source (torch.json light.color must equal it; if you prefer the torch to read look.json directly, keep torch.json's key and its help true). (2) Measure first: in tools/crawler_frames.gd add a frame with the torch in hand 1 m from a wall and a frame 1 m from a relit sconce, and report the mean hue and chroma of the lit wall patch in each, before and after. If the torchlit patch falls outside the grade's protection (most likely where the near stone blows bright and pale, and the night preset's highlight pull, teal and night pull tint it cyan-white), fix it at the cause: firelit pixels are left to the fire as hearth-lit ones are, the bright stone right at the torch included. Your call how (a wider protect band for bright warm pixels, a firelight mask, or easing the highlight pull on warm pixels); do not warm the dark past the fire's reach and do not touch the vent daylight column (§EV.2 stays blue). (3) Guttering: the coal and its light dim and redden while guttering (torch.json ember.gutter_glow); nothing cools toward white or blue.

CHECK (headless, in tools/crawler_check.gd or crawler_frames.gd): every fire light in a built tomb has the same light_color; the torchlit wall patch and the sconce-lit patch land within 8 degrees of hue of each other and both inside the orange band (-20 to 62 degrees); a guttering torch's light is never bluer than a steady one's; the corridor's full-dark mean and the vent column's blue are unchanged from the last PROGRESS entry's numbers. Walkabout once: the torch in hand beside a relit sconce.
```

## 45 — A reticle in the crawler — §EX.7

**Status:** built 475c143
**Mike sees:** A small crosshair in the middle of the screen in the crawler, chunky in the low-res frame like the rest of the HUD. Still no words anywhere. The Settings crosshair switch still turns it off.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EX.7 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from §EX. Torchfire 1, the crawler (scripts/crawler/). No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from crawler.json _help.hud (keep warms_near_flame false: it is an idea, not locked), pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EX.7; §ET.3 (wordless: no tooltips, no prompts); §Y (the HUD is drawn inside the internal frame and scaled with it); §W (the reticle's size); hud.json reticle and _help.reticle; scripts/ui/status_hud.gd (the open world's crosshair, StatusHud) and the Settings key hud.reticle; crawler.json hud; CrawlerMain's ui CanvasLayer.

BUILD: (1) Show the open world's crosshair in the crawler in first person, from hud.json reticle (size_px, thickness_px, gap_px, color), inside the 480-line frame and nearest-scaled with it, through the same drawing code if you can (no second crosshair to drift apart). (2) Nothing else from StatusHud comes with it: no health meter, no plant name, no numbers, no prompts. (3) The Settings switch hud.reticle hides it. (4) It never blooms (it gives off no light) and it stays readable on dark navy and on amber-lit stone: if it is not, give it a one-pixel dark outline and say so in the PROGRESS entry.

CHECK (headless): the crawler's frame at seed 7 has the reticle's pixels at the frame's centre at the 480 preset and at the 270 preset, sized per hud.json; with hud.reticle off there are none; no text is drawn anywhere in the crawler's HUD. Walkabout once: the hearth room, then a dark corridor.
```

## 46 — The plan and the way out: a spine, the module, an exit every time — §EX.2, §EX.5

**Status:** built 28dafd4 (follow-up b7956e0). Found while building 58 (7 Oct): seed 126's crypt (piece 16) can't be walked through by your body, with or without the skeletons. Its coffins and hearth ring close off the aisle, so this pass's walk check should catch it. `tools/residents_check.gd` walks your body from the wake spot into the heart as a stand-in, and `TombNav` (a floor grid at your body's size) may help here. (46: on the new layouts seed 126 walks out and all three of its crypts can be crossed; see its PROGRESS entry.)
**Mike sees:** Every tomb now has a way on: one main passage (the spine) runs from the hearth room through the heart to a long stair climbing out, with faint daylight at its top you can see from below. Walking up it fades to a fresh tomb. Side passages are shorter and end in a room. Rooms line up and doors face each other, so you often look straight down a passage to the next light.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EX.2 and §EX.5 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from §EX. Torchfire 1, the crawler (scripts/crawler/). No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from crawler.json _help.plan and _help.exit, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EX.2, §EX.5, and the "What Claude found" list at the top of §EX (every branch is a dead end today); §ET.3 (three or four ways leave the hearth room: one of them is now the spine); §ET.4 (gates: they may close only side ways and shortcuts now); §CJ.3 (the heart); §EV.2 (the daylight column's colours, reused faint at the exit's top); §EW.3 and §EW.7 (where the exit will lead); crawler.json plan, exit, kit; masonry.json styles (module_m, heights_m; the style for a theme is masonry.json style_by_theme); scripts/crawler/tomb_kit.gd (layout, _branch, _mark_heart), tomb_build.gd, crawler_main.gd.

BUILD: (1) The module: kit.room_m, kit.corridor_m and the hearth room's sides snap to whole multiples of the theme's style's module_m; ceilings take the style's heights_m. (2) The spine: one of the hearth room's ways is grown first and longest, through the heart (the heart is now the spine's deepest room, not merely the deepest room overall), and on to the exit. Its rooms never end the branch: the spine carries on. (3) Side branches: the other ways, at most plan.side_branches.side_share of the spine's room count each, and each ends in a room, never a bare corridor. (4) Doors centred on the wall they cut; where a room has two doors, put them on opposite walls facing each other when the layout allows (plan.facing). (5) The exit (exit.place spine_end_past_heart, form stair_up): a long flight of stairs climbing exit.rise_m from a door past the heart, built in the tomb's stone, to an opening at the top with a faint cool daylight glow (§EV.2's day or night colour on the clock you already run, faint, never a spotlight), visible from the bottom of the stair. (6) The stand-in (exit.stand_in): stepping into the opening fades out over fade_s and builds the next tomb from a new seed, the player arriving in its hearth room with its hearth lit; keep the torch you carried (lit or not) and nothing else changes. Log line: your wording, short, in the log's voice. (7) Never gated: no gate (none are built yet) may ever be placed between the wake spot and an exit; leave a comment where gates will go saying so.

CHECK (tools/crawler_check.gd, headless, seeds 1, 7, 42 and 200 more random seeds): every tomb has at least one exit; with every holder cold, walk the player's own capsule (CharacterBody3D with the crawler's real collision and step height, or a navigation bake using the player's radius and step) from the wake spot to the exit and fail the seed if it can't get there (report which door or stair blocked it); the spine passes through the heart; no side branch ends in a corridor; every room side is a whole number of modules; the hearth room still has three or four ways. Report the median walk from wake to exit in metres. Walkabout once: from the bottom of the exit stair, looking up.
```

## 47 — One hearth per dungeon; wall torches in the other rooms — §EX.4

**Status:** built 6578210
**Mike sees:** The hearth room is the only room with a hearth. Every other room has wall torches to relight instead: two facing each other in a small room, four in a big one, four in the heart (two either side of the dead). Only the hearth has the shaft with daylight; each wall torch has its own little flue and soot streak.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EX.4 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from §EX. Torchfire 1, the crawler (scripts/crawler/). No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from crawler.json _help.room_torches, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EX.4; §ET.4 (relit stays lit, and you can relight a torch at any relit holder); §EV (every built-in fire has its own vent: hearth a shaft, sconce a flue; soot); §CN (the swing lights a holder); crawler.json room_torches and holders; delves.json fire_holders (unchanged: it still serves the open world, Torchfire 2); scripts/crawler/tomb_kit.gd (_place_holders), crawler_fires.gd (_sconce, the hearth ring), vents.gd.

BUILD: (1) In TombKit._place_holders, the hearth room keeps its hearth (room_torches.hearth_rooms 1) and no other room gets a hearth ring: every other room gets wall sconces, room_torches.small in a room up to small_room_max_m long, large in a longer one, in facing pairs on the long walls, spaced on the style's module (masonry.json styles module_m) and clear of doors and wall niches; the heart gets room_torches.heart, heart_flank_dead of them either side of the dead at its end. Corridors keep their sconces as built. (2) Each sconce is a holder like the corridor ones: cold and laid, lit by the swing, stays lit, relights a torch. (3) Vents follow the rule as built: the hearth's shaft is now the only shaft and the only daylight column in a dungeon; each room sconce gets a flue and soot. (4) The log's relit count and anything else that counted hearth rings now counts the sconces. (5) The sconce's look is unchanged in this pass (prompt 48 restyles it).

CHECK (tools/crawler_check.gd, headless, seeds 1, 7, 42): exactly one hearth per tomb and it is in the hearth room; every other room has 2 or 4 sconces per the rule and the heart 4; no sconce within 0.6 m of a door's edge; vents: exactly one shaft per tomb, one flue per sconce; with every sconce in a room relit, the room's mean lit level is at least the old hearth ring's (report both numbers). Walkabout once: a crypt with its two sconces relit.
```

## 48 — One ruin, one stone: floor, ceiling, doors, stairs and sconces in the walls' style — §EX.1, §EX.3

**Status:** built 8799b26
**Mike sees:** The tomb looks built by one people from one quarry: the floor is fitted polygonal flags of the same stone as the pillowed walls, worn smooth down the middle; the ceiling is long single slabs of that stone, with a step of corbel above the walls in the rooms; doorways and niches are Inca trapezoids under one big lintel; stairs are single blocks; the wall torches sit in trapezoid niches cut into the wall. The snow ruins, when built, use the passage-grave kit: orthostats, rough slab floors, corbelled chambers closed by a capstone.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EX.1 and §EX.3 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from §EX. Torchfire 1, the crawler (scripts/crawler/). No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from masonry.json _help.styles and _help.style_by_theme, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EX.1, §EX.3, and the "What Claude found" list at the top of §EX; §EU (fitted stone, settled, overgrowth; built); §ES.2 (light painted into the stone, occlusion tinted to the scene's shade, no normal maps, no shine); §BQ (the heart's ochre: paint on the style's stone); §EV.1 (soot over it); masonry.json styles and style_by_theme (with the existing presets, relief and settle); scripts/crawler/fitted_stone.gd, tomb_build.gd (_room, _pave, _ceiling, _doorway, _delve_stair, _dress), crawler_fires.gd (_sconce's hard-coded stone), and the stone dressing (coffins, shelves, rubble).

BUILD, for the tomb (andean_tomb) now; the passage_grave_snow style is data for when the snow ruins are built, so read it but do not build the snow ruins: (1) One stone: every built stone surface in the tomb takes the style's stone (stone.tint, with stone.spread at most per stone) and the same joint occlusion as the walls; remove every use of the general palette and every hard-coded stone colour in the crawler (rule.no_general_palette); ochre, soot, moss and drift stay on top (rule.on_top). (2) Floor (fitted_flags): FittedStone's cutter laid flat, stones floor.stone_scale times the wall preset's, pillow and proud times pillow_scale, joints filled to joint_fill with grit in the scene's shade, and worn (flatter, lighter by a little) along the middle of each passage (wear). (3) Ceiling (lintel_slabs): single slabs wall to wall, slab_w_m wide, each its own width, bevel and a little settle like the walls, still cut round vent mouths; in rooms one corbel course (rooms.corbel_courses, corbel_step_m) steps in above the wall top first. Rooms wider than max_span_m get pillars of the stone on the module carrying stone beams, the slabs spanning beam to beam; the hearth room (hearth_room four_pillars) gets four pillars round the hearth with the shaft open between them. Keep the hearth, the wake mat, the bundle and the rescuer clear and the sight lines from prompt 46 open. (4) Doors (trapezoid, top_share): the opening narrower at the top under one monolithic lintel, the threshold one stone; the catacomb's bone niches take niches.shape. (5) Stairs (block_steps): each step one block of the stone, settled like the walls. (6) Sconces (niche_cup): a trapezoid niche niche_w_m x niche_h_m cut into the wall's own fitted stone with a stone cup in it; the flame, coals and light as built. (7) Coffins, shelves and rubble: the style's stone. (8) Triangle budget: report a typical room's count before and after; if the floor's fitted flags push a room past 45,000 triangles, merge small floor cells first and say so.

CHECK (headless, seeds 1, 7, 42): no vertex colour in the tomb's stone falls outside the style's tint +/- spread (before occlusion, ochre, soot, moss and drift); no stone surface uses RuinBuilder's palette (grep and a runtime count); every door is narrower at the top by top_share; the hearth room has four pillars and its shaft is clear between them; no room ceiling spans more than max_span_m unsupported; prompt 46's walk-to-exit check still passes on all its seeds; triangles per room and the tomb's build time reported. Walkabout once: the hearth room and a crypt, the same frames as the last visual pass, so Mike can compare.
```

## 49 — A boss in the dungeon: the snake prowls only the unlit rooms; the last light drives it into its hole — §EY.1, §EY.2

**Status:** built 827805b
**Mike sees:** Something long moves in the tomb's dark. You hear scales dragging on stone before you see it. It slithers the unlit corridors, coils in dead ends, and comes for you when it sees your flame. It never enters a room you have relit, and if you relight the room it is in, it slides away into the dark. Let it reach you and each strike is a hit; three is "Good night", and you wake at the hearth with every torch you lit still burning. Light the last torch and you hear it go, a long sound travelling away and down into a hole in a side room, and then the tomb's small sounds come back. Stand at the edge of that hole and you can hear it breathing below.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompts 44–48: it needs §EX.4's one hearth with torches in every other room and §EX.5's way out. This pass builds ONE thing: design §EY.1, §EY.2 and §EY.8 step 1 of docs/design/RECONCILIATION_2026-09-30.md, the boss rule in the tomb with one boss, the snake (data/bosses.json → bosses.desert, first). Nothing else from §EY: the other seven bosses wait for their worlds. Torchfire 1, the crawler (scripts/crawler/). No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off bosses.json's _help for the parts you wire (rule, contact, lair, release, bosses.desert) and say in _help.about that the other bosses are not wired, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EY (all of it for context); §EX.4 and §EX.5; §ET.4 (relit stays lit), §ET.7 (snuff), §ET.8 (baked sprites); §BA (heard before seen; a torch is a delay, a fire is safety); §EA, §EC and data/harm.json (hits, i-frames, "Good night"); §ET.3 and §DE (waking at the hearth); data/bosses.json (rule, contact, lair, release, bosses.desert); crawler.json holders; the tomb kit, CrawlerFires and Harm.

BUILD: (1) Its ground: a graph of the tomb's rooms and corridor stretches. A node is the boss's ground while it is unlit (rule.room_relit_when all_torches_lit; a corridor stretch between two lit sconces counts as lit; the hearth room never is). Recompute on every relight. (2) The snake, pattern slither: it moves only through its ground, along corridors, at speed_mps; between rounds it coils in a dead-end room for coil_s; it never enters a lit node (rule.relit_closes_room); if the node it is in becomes lit it leaves for the nearest unlit node by the shortest unlit path (rule.leaves_lit_room), and if none is left it goes to its lair. (3) Noticing and hunting: it notices you per rule.notice (a carried flame in line of sight within sees_flame_m, a sprint within hears_sprint_m) and follows you through its ground, never into a lit node. A torch in hand is a delay (rule.torch_in_hand): with your torch lit it hangs at the edge of the torch's circle for a short while before it closes (your number, put it in bosses.json with a _help line); with the torch out it closes straight in. Within strike_m a strike is one Harm hit (contact.strike_is_hit), respecting the i-frames; three is "Good night", you wake at the hearth (contact.wake), every relit holder stays lit (contact.relit_kept), and the snake goes back to its rounds. (4) The lair: the generator puts a hole in the floor or wall of one side room off the spine (lair: hole, off_main_path), dark and readable as a den. It is never on the spine and never blocks the way out (rule.never_blocks_exit); prompt 46's walk-to-exit check must still pass. Once the snake is in, its breathing is heard within lair.breathing_heard_m. Not enterable. (5) The release: when the dungeon's last holder catches, the snake leaves for its lair (if it can't get there unseen through the dark, it may vanish where it is), a long sound travels away and down to the hole (release.cry_to_lair), the tomb's small sounds come back (release.bed_returns), and the log gets release.log_line with {boss} = "giant snake". (6) The tell: scales dragging on stone, positional, heard before it is seen; quieter while coiled. No name on screen (§BA). (7) The sprite: §ET.8's baked sprites, a creature body, not the cloaked rig, painted per §ES; a long body as a chain of segment sprites following the head's path is §EY.5's first guess and your call. A placeholder bake is fine this pass.

CHECK (headless, seeds 1, 7, 42): the ground's node count falls with each relit holder and reaches zero at the last; over a scripted run that relights the holders in order, the snake never stands in a lit node, and after the last light it is in its lair; the lair room is off the spine; prompt 46's walk-to-exit check passes with the snake in play; a scripted stand-still in the dark beside it lands hits at harm.json's pace and "Good night" on the third, then waking at the hearth with the relit holders still lit. Walkabout once at the end: the snake in a corridor at the edge of torchlight, and the lair.
```

## 50 — The torch stays lit: only deep water puts it out — §EZ.1, §EZ.5

**Status:** built dacd5d3
**Mike sees:** Run flat out for as long as you like, spin round, swing the torch: it stays lit, and it glows a little brighter while you run. A strong gust at a marked airway whips the flame hard but it holds. Only wading into deep water puts it out. (Amended by §FJ.4, 6 Oct 22:52: torches burn down again; that part is prompt 62.)

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EZ.1 and §EZ.5 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from §EZ. Torchfire 1, the crawler; the open world (Torchfire 2) keeps its own torch rules unless a line below says otherwise. No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take the [NOT WIRED YET — design §EZ.1] and [NOT WIRED YET — design §EZ.5] notes off torch.json _help.snuff once the rules are gone, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EZ.1 and §EZ.5; §ET.7 (the snuff rules as locked: the sprint rule and the strong gust's snuff are now removed, only deep water stays); §FJ.4 (torches burn down again in the crawler: leave the burn alone, prompt 62 sets it); §EY.2 (amended: running no longer risks the torch, and the boss's torch-out case comes only from water); torch.json snuff (moving_fast never, only water; burns_down is true again per §FJ.4; sprint still present only so the code loads), burn_min, gutter_share, ember.air_brighten, pitch_head.lean.max_deg; scripts/player/torch_snuff.gd (TorchSnuff.step: the sprint bank, the "sprint" and "draft" reasons), scripts/crawler/airways.gd (the strong gust), scripts/player/torch.gd (the burn countdown and burnt_out); crawler.json snuff_log.sprint and snuff_log.draft.

BUILD: (1) Remove the sprint rule from TorchSnuff: no sprint bank, no "sprint" gutter or reason. Walking, sprinting for any length of time, turning, looking about and the swing (§CN) never gutter the torch or put it out. Then delete torch.json snuff.sprint and crawler.json snuff_log.sprint (data the design no longer mandates; say so in the commit). (2) Keep sprinting's flare: running still feeds the coal air (ember.air_brighten, light sprint_flicker_scale) so the torch glows a little brighter at a run. (3) The strong airway gust no longer puts the torch out or gutters it toward out: keep the marked mouths, their cycle, the moan and the dust exactly as built, and let a gust in line whip the flame hard sideways (the coal's lean now; the flame's lean at pitch_head.lean.max_deg once prompt 51 is built); delete crawler.json snuff_log.draft. Ordinary drafts lean it as before. (4) [Withdrawn by design §FJ.4, 6 Oct 22:52: torches burn down again in the crawler. Don't stop burn_left_min counting down; prompt 62 sets the crawler's burn time and the three-torch limit.] (5) Deep water is the only way out: wading toward douse_depth_m gutters it and past it puts it out, as built. Out means out: relight at the hearth or any relit holder. (6) If the boss (prompt 49) is built, its noticing a sprint by sound is unchanged: running draws it, it just no longer costs the light; its torch-out case now comes only from water.

CHECK (headless, in tools/crawler_check.gd): a scripted 120 s flat-out sprint round the tomb, with fast turns, leaves the torch lit with gutter 0 throughout; a scripted 60 s of swinging the torch leaves it lit; standing in a strong gust's line through three gusts leaves it lit; wading past douse_depth_m still puts it out after the gutter; the torch's light energy at a sprint is above its energy standing still. No walkabout needed for this pass.
```

## 51 — The pitch torch: a wrapped, tarred head and a pixel flame — §EZ.2

**Status:** built afac6a9
**Mike sees:** The torch's tip is wrapped in bands soaked black with pitch, a few drips running down the stick, glowing coal at the top of the wrap, and a small chunky pixel flame on top, in the hearth's amber. The flame leans back when you walk and streams a little when you run. Unlit torches by the hearth show the black pitch head and no flame.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EZ.2 of docs/design/RECONCILIATION_2026-09-30.md, and nothing else from §EZ. Torchfire 1, the crawler; the open world (Torchfire 2) keeps its own torch rules unless a line below says otherwise. No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off torch.json _help.pitch_head, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EZ.2; §CP (the ember head, built 9e3e7ef and b7ebed5: the burnt end's six flat sides, never a ball; the coal's breath); §BZ and §CZ (the one flame card, posterised bands, crunched texels; the sparks); §EX.6 (one amber firelight: do this after prompt 44 so the flame and its light are the hearth's amber); §EV.3 (a draft leans the flame); §CV (smoke by a flame's size, Smoke.tick_flame); R3 and the R-rules (no shine, no specular, smoke never neutral grey); §EH (no metal: the wrap is fibre or bark and pine pitch or birch tar); torch.json pitch_head, ember, light; look.json fire.flame (texels, bands, torch: scale, scroll_scale, embers); scripts/player/torch.gd (ember_node, flame_node, the in-view stick and _view_flame, planted torches), shaders/torch_ember.gdshader, Campfire.flame_node.

BUILD: (1) The head: replace the burnt end on every torch in the crawler (in hand in first person, planted, and in the bundle by the hearth) with the pitch head from pitch_head.head: six flat sides, straight, swell times the stick's radius, length_m long, bands showing as small steps in the silhouette, and drips (count, length_m) of pitch running down the stick below it, all as geometry plus painted vertex colour or texture at texels_m; colours from pitch_head.colors, painted not lit (no specular, no shine, no normal map); the head's top band shades to colors.thin just under the flame. (2) The coal: the ember shader's glow and breath (ember block) move to the top of the wrap, under the flame (pitch_head.coal). (3) The flame: when lit, the campfire's one flame card (Campfire.flame_node via Torch.flame_node, look.json fire.flame.torch for size and scroll) sits on the head, its texel grid pitch_head.flame.texel_scale times coarser than the campfire's so it reads chunky in first person at the 480 and 270 presets, in the flame's own bands, with the torch's couple of single-pixel sparks. It must read as a flame at the bottom right of the first-person view, not a smear: check its on-screen size in pixels at 480 and report it. (4) The lean: the flame leans back against the player's velocity by pitch_head.lean.per_mps degrees per m/s up to max_deg, stretches to sprint_stretch of its height at a sprint, leans toward an airway draft (Airways' lean, as the coal does now), and settles over settle_s; nothing about it can put the torch out (§EZ.1). (5) The light: §EX.6's amber; flicker from the flame's noise (§BZ) plus the coal's breath (§CP), your mix; the held_scale brightness (§EB.3) unchanged. (6) Unlit (the bundle, a doused torch with burn left): the pitch head only, no coal, no flame. Burnt out: as built. (7) Smoke: as built by the flame's size, pulled pitch_head.smoke.soot_scale toward soot, never a neutral grey. (8) The open world (Torchfire 2) may keep the ember head; your call, say which in PROGRESS.

CHECK (headless): every lit torch in a built tomb has one flame card and one coal, and every unlit one none; the head's silhouette has six sides and no rounded cap (vertex test); no material on the head or stick has specular or roughness under 1; the flame's lean at a 0 m/s stand is 0 and at a sprint within max_deg; the flame's on-screen height in pixels at 480 and at 270 reported from tools/crawler_frames.gd with the torch in hand. Walkabout once: the torch in hand in a dark corridor, standing and then sprinting.
```

## 52 — The folk at the hearth in 3D, made pixel by the frame — §FH

**Status:** built 8c409e6
**Mike sees:** The person sitting at the hearth when you wake is a solid little 3D figure now, not a flat cut-out: walk round them and they stay solid from every side, chunky with painted pixels like the goat with the bowl in frame 3, lit amber by the fire against the blue.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §FH of docs/design/RECONCILIATION_2026-09-30.md, the hearth folk as live 3D figures. Torchfire 1, the crawler (scripts/crawler/). No screenshots after every step: check with headless numbers, and run the walkabout or tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off crawler.json _help.folk_3d, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FH; §ET.8 (baked sprites; amended for folk only), §ET.9 (one rig, one wardrobe), §ES (3D pixel art: light painted into textures, diffuse only, navy/olive occlusion), §EO and §EQ (beast heads, the hood behind the head), §EX.6 (amber firelight), §ER (performance); crawler.json folk_3d, rescuer, sprites; scripts/crawler/crawler_main.gd (_bake_rescuer and where the rescuer is placed), scripts/crawler/figure_sprite.gd, the CloakedFigure rig and its beast heads.

BUILD: (1) The rescuer (and any later folk at a hearth, folk_3d.who) is drawn as the live shared rig, CloakedFigure with its beast head and cloak colours as now, in the scene as real geometry, instead of a FigureSprite quad. (2) Paint it per §ES: diffuse only, no specular, no normal map, the light baked into its texture or vertex colour with the occlusion tinted the scene's shade (navy), texels sized so it pixelates like the walls at the 480 preset; the hearth's amber light falls on it live. Target: ozavry_ frame 3, the goat with the bowl (docs/references). (3) Its idle (the slow breath, sitting by the fire) plays on the rig; whether it steps at sprites.anim_fps for the era feel or runs smooth is your call, say which in PROGRESS. (4) Keep FigureSprite and its bake for creatures and bosses (folk_3d.sprites_stay_for); don't delete it. (5) Report the frame time in the hearth room before and after (PerfReadout, §ER).

CHECK (headless): in a built crawler the rescuer is a 3D rig node, not a FigureSprite; no material on it has specular above 0 or roughness under 1; the hearth room's frame time before and after, in PROGRESS. Walkabout once: circling the hearth at 480, the rescuer from front, side and back.
```

## 53 — Sneak: the view eases down, the reticle changes, quiet feet, and you can't step off a ledge — §FC.1

**Status:** built c40b2da
**Mike sees:** Hold Shift and the view glides down into a crouch instead of snapping, the dot of the reticle opens into a small dim ring, and your steps go soft. Creep to the edge of a drop and you stop right at the lip, however hard you push; let go of Shift and you can step off.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §FC.1 of docs/design/RECONCILIATION_2026-09-30.md, sneaking in the crawler. Nothing else from §FC. Torchfire 1, the crawler; the open world and the ninja profile keep their crouch as built. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off stealth.json _help.about for the sneak block, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FC.1 (Mike: Amnesia's sneaking, Minecraft's ledge); §EX.7 and hud.json reticle (the crawler's reticle, prompt 45); stealth.json sneak; scripts/crawler/crawler_player.gd (crouching, CROUCH_SPEED, noise_level, moving_state), PlanetPlayer._set_crouch and _apply_view, scripts/player/footsteps.gd.

BUILD: (1) Shift is still crouch (Controls "crouch"). The camera's eye height eases between standing and crouched over sneak.camera_ease_s, both ways (smoothstep), never a snap; the collision shape may change at once, but standing up under a low ceiling must not push the view through it. (2) While crouched, the reticle takes sneak.reticle: the dot opens into a small ring and dims to its dim scale; back on standing. If prompt 45 isn't built yet, build the reticle swap on top of hud.json's reticle anyway and say so. (3) Footsteps while crouched play at sneak.footstep_volume of the walk's volume; noise_level stays 0.1 as built. (4) The ledge guard: while crouched and on the floor, no move may carry you off a drop deeper than sneak.ledge_drop_m: test the ground under the capsule's leading edge each physics tick and cancel the part of the move that would leave support, per axis, so you can slide along an edge. Let go of Shift and you step off normally. Not in the air.

CHECK (headless, tools/crawler_check.gd): the eye height over the first 0.3 s of a crouch rises or falls monotonically and reaches its target by camera_ease_s; a scripted crouched walk straight at a 2 m drop for 10 s stops within 0.35 m of the lip and never falls; the same walk diagonally along the edge slides and never falls; the same walk standing falls; the reticle reports the ring while crouched; a crouched step's volume is footstep_volume times a walking step's.
```

## 54 — Douse your own torch, and a dark you can half see in — §FC.3, §FC.4

**Status:** built 972a2d5
**Mike sees:** Press F and you smother your torch: the flame dies, you're still holding it, and whatever was watching for your light loses you. Swing it to any lit sconce, planted torch or the hearth and it catches again. With no flame near you the dark isn't blind: the walls and floor close by show faintly in navy, and only farther off does it go fully black.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 50 (the torch's snuff rules). This pass builds ONE thing: design §FC.3 and §FC.4 of docs/design/RECONCILIATION_2026-09-30.md: dousing your own torch, and the half-dark. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and run tools/crawler_frames.gd once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off crawler.json _help.dark and stealth.json's douse note, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FC.3, §FC.4; §DF (your light gives you away); §ET.7 and §EZ.5 (out means out; water is the only thing in the world that puts it out); §CN (the swing passes the flame); stealth.json douse; hands.json douse_key; crawler.json dark and look; scripts/player/torch.gd (put_out, stow, pass_flame), scripts/core/controls.gd (DEFAULTS), and the boss's notice if prompt 49 is built (bosses.json rule.notice).

BUILD: (1) A "douse" action in Controls.DEFAULTS (hands.json douse_key, F; a pad button of your choice): with a lit torch in hand it goes out (a new put_out reason, "smothered", logging stealth.json douse.log_line, with a short smother hiss) and stays in your hand with its burn unchanged. Nothing in the world counts it as water. (2) Relighting stays as built: swing the cold torch to the hearth, a relit sconce or a planted torch; check each. (3) A doused torch gives nothing away: anything that notices a carried flame (the boss's sees_flame_m if built, dread/senses where they run in the crawler) stops seeing it at once. (4) The half-dark: with no flame near you, surfaces within dark.readable_m read faintly in dark.readable_color and fall to black by dark.black_m. How is your call (a weak player-centred fill light that never adds warmth, the fog curve, or both); shade stays navy, never grey; it must not change how far the torch reaches or how the lit rooms look.

CHECK: douse with a lit torch → lit false, burn_left_min unchanged, still in hand, one log line; a swing at a relit sconce relights it; with prompt 49 built, the snake that saw your flame loses it on the douse. From tools/crawler_frames.gd with the torch doused in a cold corridor: mean luminance of wall pixels at about 3 m above a readable floor you pick, at about 15 m near black, and their hue blue (report the numbers). Same frame with the torch lit unchanged from before this pass.
```

## 55 — Two hands: the wheel, Tab and the wheel, and a Controls page — §FB

**Status:** built 5402764
**Mike sees:** Q no longer swaps anything. The mouse wheel cycles what's in your right hand (torch, bare hands). Holding Tab and scrolling cycles your left hand through the left-hand things you carry, and back to empty, with a small wordless strip showing while Tab is held. In Settings there's a Controls page where every key can be rebound, including which hand the wheel drives.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §FB of docs/design/RECONCILIATION_2026-09-30.md, the two hands and rebinding. Throwing a fire pot is prompt 60, not this pass. Torchfire 1, the crawler; the open world keeps Q and its weapon swap as built. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true (it lists the controls), take [NOT WIRED YET] off hands.json _help.about, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and how to rebind.

READ: §FB; §CN (left click swings the right hand's thing); hands.json; scripts/core/controls.gd (DEFAULTS, MOUSE_BUTTONS, ensure: Project Settings bindings win), scripts/crawler/crawler_player.gd (_unhandled_input, weapon_swap, swap_weapon), scripts/player/torch.gd (stow: a lit torch put away goes out), scripts/ui/settings_panel.gd, the 480-line HUD (§Y).

BUILD: (1) Right hand: in the crawler the mouse wheel cycles hands.json right.holds that you have (torch, bare hands; the spear once found). Q does nothing in the crawler. Scrolling a lit torch away puts it out, as built. (2) Left hand: a left-hand slot and its own small strip in the pack (left.holds; fire pots arrive in prompt 60, so give dev_items, F9, a placeholder left-hand item to test with). Holding Tab and scrolling cycles the strip and "empty"; holding Tab shows the strip, icons only, inside the 480-line frame; Tab tapped alone does nothing in the crawler. (3) wheel_drives: right by default; set to left, the plain wheel drives the left hand and Tab-and-wheel the right. (4) A Controls page in Settings: every Controls action with its key, mouse button or wheel; click one and press a new input to rebind; a reset to defaults; wheel_drives as a toggle. Saved per player (a file under user://, your choice) and applied by Controls.ensure at start, so a saved binding wins over DEFAULTS. Keyboard, mouse buttons and wheel at least; pad optional.

CHECK (headless): with only the torch, the wheel goes torch → bare hands → torch; Q changes nothing in the crawler; with the placeholder left item, Tab+wheel goes item → empty → item; wheel_drives left swaps them; a binding saved, the game restarted (or Controls re-run), and the new binding in force; reset restores DEFAULTS.
```

## 56 — Harm: a red edge on the first hit; a chase follows you into the light; you heal only once it gives you up — §FD

**Status:** built b998d05
**Mike sees:** Take a hit and a red ring closes round the edge of your view and you hear your heartbeat; a second and the ring goes darker red and your heart pounds harder and faster; a third is "Good night". Running into a lit room doesn't save you: the thing that hit you follows you in. You only start to recover once you've lost it, by getting far enough away, out of its sight long enough, into a hiding place, or by dousing your torch. Then it slinks back to the dark.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 49 (the boss). This pass builds ONE thing: design §FD of docs/design/RECONCILIATION_2026-09-30.md, with §FJ.3's ring and heartbeat. Torchfire 1, the crawler; the open world keeps §EA/§EC as built. No screenshots after every step: check with headless numbers, and run tools/crawler_frames.gd once at the end for the red ring. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off harm.json fd._note and say in bosses.json _help.rule that chase_enters_light is wired, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FD and §FJ.3; §EA and §EC (three hits, the stages, i-frames, the per-hit flash, the 5 s step); §EY.1 and §EY.2 (amended: a relit room is closed to the boss's prowling, not to a chase); harm.json (recover, stages, fd); residents.json rules (gives_up, chase_enters_light, back_to_dark_s); bosses.json rule and bosses.desert; scripts/player/harm.gd and the boss code from prompt 49.

BUILD: (1) Hit 1: a red ring round the edge of the view (harm.json fd.hit_1_edge: colour, width_frac of the frame's short side, alpha), inside the 480-line frame, and the heartbeat starts at heart_bpm. Hit 2: the ring as fd.hit_2_edge, darker red and a little wider, and the heartbeat harder and faster (heart_bpm, heart_db). These replace §EA's stage darkening and muffle in the crawler. Hit 3 "Good night" as built. Healing steps back down the same way. §EC's quick navy flash on every hit stays. (2) Pursuit: anything that hunts you (the boss now, residents from prompt 58) registers as pursuing when it notices or hits you and clears it when it gives you up. It gives up by its own mix of residents.json rules.gives_up: distance, out of its sight for long enough, you hidden (out of its sight line, §FC.2), your torch doused (prompt 54). Give the snake its numbers in bosses.json bosses.desert (a gives_up block, with a _help line). (3) Recovery: Harm's step timer (recover.step_s) counts only while nothing is pursuing you (fd.recover_starts); a new hit resets it as built. Light doesn't heal (fd.light_heals false). (4) The chase crosses into light: a boss that has hit you may follow you into lit nodes until it gives you up, then returns to the nearest unlit node within residents.json rules.back_to_dark_s. Its prowling never enters a lit node, as prompt 49 built.

CHECK (headless): one scripted hit, the snake kept in sight and close: no recovery after 15 s; break its sight for its out_of_sight time, it gives up, the hit heals one step_s later; after a hit the snake follows into a lit room; a snake that hasn't hit you never enters a lit node over a 5-minute scripted run; after giving up in a lit room it is in an unlit node within back_to_dark_s. Frames once with one hit and with two: the ring visible and darker on two, report its depth in pixels at 480; the heartbeat playing from hit 1.
```

## 57 — The torch staggers, and every creature has its own strike tell — §FA.1, §FA.2

**Status:** built a4f1b00
**Mike sees:** When the snake draws its head back to strike, you hear its hiss; swing your lit torch into it right then and it reels away, its strike broken, giving you a second to run. Swing too late, once it's already lunging, and the bite lands anyway. The torch never hurts it.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 49 (the boss) and prompt 56 (harm). This pass builds ONE thing: design §FA.1 and §FA.2 of docs/design/RECONCILIATION_2026-09-30.md, the stagger and the strike tells, on the snake. Fire pots are prompt 60. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off torch.json _help.stagger, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FA.1, §FA.2; §CN (the swing, which still passes the flame); §DF (a swing that lands is loud); torch.json stagger and swing; bosses.json bosses.desert; residents.json _help.creatures (strike.reach_m, wind_up_s, tells); scripts/player/torch.gd (swing, swing_target) and the boss code from prompt 49.

BUILD: (1) A creature's strike has two parts: a wind-up of strike.wind_up_s, then the committed strike (its active frames). Give the snake a strike block in bosses.json bosses.desert (reach_m, wind_up_s, and a wind_up tell: Claude's first guess "a hiss and the head drawing back", put it in with a _help line). (2) A swing of the lit torch (torch.json stagger.lit_only) that reaches the creature during its wind-up staggers it: the strike is cancelled, it reels back for stagger.reel_s, and it can't be staggered again for stagger.cooldown_s. No damage, ever (stagger.damage 0). A swing during the committed strike does nothing to it: the hit lands as normal. (3) The tells: the wind-up is visible on the creature (a pose on its sprite: your call) and audible as its own positional sound, so an ambush is heard before it is seen. (4) A swing that lands makes noise like a sprint (stagger.noise) for anything that hears. (5) Make it general (any creature with a strike block), since prompt 58 adds skeletons.

CHECK (headless): a scripted swing landing at 50% of the snake's wind-up staggers it and no hit counts; one landing after the wind-up ends doesn't, and the hit counts; the same swing with the torch unlit staggers nothing; a second stagger inside cooldown_s fails; the wind-up sound starts at the wind-up's first frame.
```

## 58 — The tomb's residents: skeletons that climb out of the walls, and somewhere to hide — §FE, §FC.2

**Status:** built 43688cb
**Mike sees:** Skeletons lie still in the tomb's wall niches and graves. Walk too close and you hear bone grinding as one climbs out and comes after you, slow; its jaw drops open just before it swings. Duck out of its sight behind a sarcophagus or pillar, or get far enough away, and it gives up and goes back to lie in its niche.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompts 49, 56 and 57. This pass builds ONE thing: the residents framework from design §FE.1 of docs/design/RECONCILIATION_2026-09-30.md with its first resident, the tomb's skeletons (§FE.2), and hiding (§FC.2). The other creatures wait for their worlds. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and run the walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off residents.json _help.about for the parts you wire (say the other creatures are not wired) and off stealth.json's hide note, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FE (all), §FC.2; §FD and prompt 56's pursuit; §FA.1–2 and prompt 57's strike, stagger and tells; §EX.2–5 (the plan, the spine, the way out: never blocked); §ET.8 and §EY.5 (sprites for creatures); §DF; residents.json (rules, creatures.skeleton); stealth.json hide; the tomb kit and its niches and sarcophagi (frame 9 on the Project sheets: a skeleton leaning out of a mossy stone box).

BUILD: (1) A resident framework driven by residents.json: pattern, notice (sees_flame_m, hears_step_m, a sneak heard at noise_level as built), gives_up, strike (prompt 57's), tells, retreat_to; residents register as pursuers for Harm (prompt 56). Fire hp is for prompt 60; carry it but don't use it. (2) Skeletons in the tomb: the generator lays some in wall niches and graves (first guess 3–6 a tomb, more toward the heart, none in the hearth room, none in the way out's path); asleep they are set dressing. Within wakes_m they rise over rise_s with the near tell, walk at walk_mps, hunt per notice, strike with the wind-up tell, give up per gives_up, and walk back to lie in their niche (returns_to_rest). (3) Hiding: a creature sees you only with a clear line from its eyes to your head (raycasts); crouched behind low cover is out of sight. No hide button, no prompt. A lit torch gives you away round cover: a creature within sees_flame_m with a line to any lit surface within your torch's reach notices you (your call how, cheaply). (4) Placeholder sprites per §ET.8 are fine (lying, rising, walking, wind-up).

CHECK (headless, seeds 1, 7, 42): every skeleton rests off the spine's walkable line and prompt 46's walk-to-exit check passes; a scripted approach wakes one at wakes_m; a scripted hide behind a sarcophagus, crouched, with the torch doused breaks its sight and it gives up after out_of_sight_s and returns to its niche; the same with the torch lit, it finds you; a strike lands as one hit at the end of its wind-up, and a stagger in the wind-up cancels it. Walkabout once: a skeleton climbing out of a niche in torchlight.
```

## 59 — Cleared by light: the retreat, and the half-lit floor that bites — §FF.2

**Status:** built 828e1fa
**Mike sees:** Relight the last torch on a floor and you catch the skeletons going: climbing back into their niches and holes, gone for good. While parts of the floor are still dark, they hang back in those dark pockets, and if you walk too close to one, it lunges.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 58. This pass builds ONE thing: design §FF.2 of docs/design/RECONCILIATION_2026-09-30.md. Floors (§FF.1) and the people coming home (§FF.3) are later. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and run the walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off crawler.json _help.cleared, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FF.2; §EY.1–2 (the boss's ground: the unlit nodes, and the last light sending it home; prompt 49's graph); residents.json rules (retreat_on_floor_lit, pocket_counterattack_m) and creatures.skeleton.retreat_to; crawler.json cleared.

BUILD: (1) Until floors exist (§FF.1), a floor is the whole dungeon. When its last light is relit, every resident retreats: it goes to its retreat_to (a skeleton back into its niche or the nearest hole) where you can see it go if it's in view, and is then gone for good (relit stays lit; it doesn't come back). The boss's release (prompt 49) still plays. (2) Half-lit: residents that aren't chasing you keep to unlit nodes (prompt 49's graph); one in a dark pocket strikes anyone who comes within pocket_counterattack_m, as a normal strike with its wind-up (so a stagger works). (3) One log line when a floor is cleared, in the log's voice (your words; no creature named on screen, §BA).

CHECK (headless): over a scripted run relighting every holder, no resident stands in a lit node unless chasing; after the last light, every resident has gone within a few seconds and none returns over 5 minutes; a scripted walk to 2 m from a resident in a dark pocket draws a strike with its wind-up. Walkabout once: the last torch catching with a skeleton in view going back into the wall.
```

## 60 — Fire pots: lit off your torch, thrown, tar that clings, oil that bursts — §FA.3

**Status:** built b21b5cd
**Mike sees:** With a fire pot in your left hand and your torch lit in your right, hold left click: your hands come together and the wick catches, you aim, release, and it lobs and bursts in amber fire. Tar clings and keeps a skeleton burning and leaves a patch alight on the floor; light oil goes off in one big flash. Lighting it lights you up too, and everything nearby knows where you are.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompts 55 (two hands), 57 (the stagger) and 58 (the residents). This pass builds ONE thing: design §FA.3 of docs/design/RECONCILIATION_2026-09-30.md, fire pots. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and run tools/crawler_frames.gd once at the end for the burst and a tar patch. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off fire_pots.json _help.about, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FA.3, §FA.4, §FA.5 (the vessel is "pot" until Mike chooses clay or glass: make it read as a small sealed clay pot with a wick); §AW (fire is borrowed: no lit torch, no pot); §ED.7 (only fire answers the dark); §EX.6 (amber); §DF; §N (hold to charge); fire_pots.json; hands.json clicks.left_with_pot; residents.json creatures.<name>.fire_hp and oil_scale; bosses.json (§FA.4: a pot drives a boss off, never kills it); prompt 55's left hand.

BUILD: (1) Fire pots as left-hand items (prompt 55's strip), up to carry_max. (2) With a pot in the left hand: left click held with a lit torch in the right brings the hands together in view over light_anim_s and the wick catches (no lit torch: nothing happens); keep holding to aim, the lob's range growing from throw.min_m to max_m over charge_s, with a faint arc if you have one (aim_arc.gd); release throws; it bursts on impact or when fuse_s runs out. cook_off_in_hand is null: it never goes off in your hand this pass. (3) The burst, per oils.<kind>: burst fire damage within splash_m against residents' fire_hp (times oil_scale); tar sticks to what it hits and burns it at burn_dps for burn_s, and leaves a floor patch burning patch_radius_m for floor_patch_s; light oil only the burst. A resident at 0 fire_hp burns out and is gone. A boss hit is driven off into the dark for vs_boss.drives_off_s and never killed. (4) All its fire lights amber (§EX.6), glows, and smokes as fire does; a tar patch is a light that goes out; it never lights a holder (relights_holders null). (5) It gives you away: the wick's flare is seen within gives_away.flare_seen_m and the burst heard within burst_heard_m by anything that sees or hears. (6) Fire spreads to things tagged as spreads_to (tag the tomb's dry wood and cloth dressing if it has any). (7) Sources: dev_items (F9) gives carry_max; place one found pot in a side room per dungeon for now (sources: found, a first guess), never on the spine.

CHECK (headless): no pot lights with the torch unlit; a scripted throw lands within the charged range; a tar hit on a skeleton burns it for burn_s and kills it if its fire_hp runs out; a light-oil burst does its burst once and leaves no patch; the snake hit by a pot leaves for the dark and returns later, never dies; a creature beyond flare_seen_m doesn't notice the wick, one within does. Frame once: the burst and a tar patch at 480.
```

## 61 — Atmosphere, not puzzles: glow-moss that dims at your flame, beetles that scatter, daylight that follows the clock — §FG

**Status:** built e11418b
**Mike sees:** On damp stone in the dark there's a faint blue-green glow of moss that fades as your torch comes near and creeps back after you pass. Beetles and the odd scarab crawl the walls and scatter from your light into the cracks. The daylight down the hearth's shaft brightens and dims with the time of day. None of it is a puzzle; it's just there.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §FG of docs/design/RECONCILIATION_2026-09-30.md, the parts that fit the tomb now: glow-moss, wall life, and daylight that follows the clock. Windows over the wilderness wait for surface ruins (§EW.7), swaying vines for a jungle style. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and run the walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off crawler.json _help.ambience for the parts you wire, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §FG (Mike: atmosphere, never a puzzle); the R-rules (only things that give off light glow; no shine; shade navy); §EU.4 (moss only where it's wet); §EV.2 (the hearth's shaft and its column of daylight); crawler.json ambience; the day clock (DayCycle) and whether the crawler runs it.

BUILD: (1) Glow-moss: small patches on damp stone in the tomb (near airways, drips or water; your rule from §EU.4's wetness), drawn in the moss's texels, emitting a faint cold light (ambience.glow_moss color and energy, never amber). When any flame comes within dims_near_flame_m it fades to dim_to, and it returns over returns_s once the flame has gone. No light from it touches gameplay. (2) Wall life: a few beetles and the odd scarab crawling the walls (tiny sprites or meshes, your call), more in damp and dark places; when torchlight within scatter_from_light_m falls on them they scuttle to the nearest crack and vanish, and come out again later in the dark. (3) Daylight follows the clock: the hearth shaft's column of daylight (§EV.2) brightens and dims with the sun's height on the game clock and is moonlit blue at night. If the crawler doesn't run the clock yet, run DayCycle there (the 144-minute day) and say so. (4) Nothing here is ever required to progress, and nothing marks a way.

CHECK (headless): glow-moss energy near a held torch is dim_to times its rest and back to rest returns_s after the torch leaves; no glow-moss patch sits on dry stone; a beetle in torchlight is gone from view within a second; the shaft's light energy at noon is above dawn's and night's is blue. Walkabout once: a damp corridor with moss glowing ahead and dimming as you walk up.
```

## 62 — Torches burn down: a timer, the hearth's bundle, three at most — §FJ.4

**Status:** built 56dc352
**Mike sees:** A torch burns for a while and then gutters, dims and goes out, leaving a charred stick. Torches come from the bundle by the hearth, and you can carry three at most. A torch with burn left catches again from any flame, and smothering it saves what's left, so the light you carry is something to spend carefully.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 50. This pass builds ONE thing: design §FJ.4 of docs/design/RECONCILIATION_2026-09-30.md, the crawler torch's timer and the three-torch limit. Torchfire 1, the crawler; the open world keeps its own burn (top-level burn_min). No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off torch.json _help.crawler_burn, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FJ.4 (reverses §EZ.5's no burn-down); §EZ.1 and §EZ.5 (moving fast never puts it out; deep water does; the strong gust doesn't, unchanged); §ET.3 and §ET.7 (the bundle by the hearth; the gutter warning; out means out); §FC.3 (dousing, prompt 54, if built: it stops the clock); torch.json crawler_burn, snuff.burns_down, gutter_share, bundle, burnt_out; scripts/player/torch.gd (burn_step, guttering, put_out "burnt", take_from_bundle, remake_bundles) and the crawler's bundle by the hearth.

BUILD: (1) In the crawler a lit torch's burn counts down in real time at crawler_burn.burn_min per torch (the open world keeps the top-level burn_min). It gutters over the last gutter_share as built (dimmer, redder, §EX.6), then goes out burnt: a charred stick, never relit. Moving fast still never costs it anything (§EZ.1). (2) Only lit time counts: an unlit or doused torch keeps its burn, and any torch with burn left relights from any flame (the hearth, a relit sconce, a planted torch), as built. (3) Carry limit: at most crawler_burn.carry_max torches at once, the one in hand included (carry_counts_hand); taking from the bundle stops at the limit (a wordless refusal, a soft sound, no text). (4) Sources: at first only the bundle by the hearth (source_first). The bundle remakes over bundle.remake_h_game game hours if the crawler runs the clock; if it doesn't, say so in PROGRESS and leave it as is. Sconces give flame, never torches. (5) pitch_scale is for the pitch technique (§FF.3), which doesn't exist yet: carry it, don't use it.

CHECK (headless, tools/crawler_check.gd): a lit torch fast-forwarded through burn_min guttering over its last share and then burnt and unrelightable; a torch doused at half burn keeps half and relights from a sconce; a 120 s sprint costs nothing but the 120 s of burn; taking a fourth torch from the bundle with three carried fails; deep water still puts it out.
```

## 63 — One world per new game: one seed, a save, Continue and New game; one clock — §FK.2, §FK.3

**Status:** built c90ea52
**Mike sees:** A new game makes a world that is yours. Quit and come back, press Continue, and you wake in the same tomb with every light you relit still burning. Walking out always leads to the same next tomb in this world, not a random one. New game rolls a brand new world. If the crawler shows the sky or the daylight shaft, the day runs the same length everywhere.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 46. This pass builds ONE thing: design §FK.2 and §FK.3 of docs/design/RECONCILIATION_2026-09-30.md, the game seed, the save, Continue and New game, and the fixed clock, in the crawler. Torchfire 1 (scripts/crawler/); the open world (Torchfire 2) stays as it is. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off crawler.json _help.persistence and worlds.json _help.generation for the parts you wire, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes, what is saved and where, and what he can tune.

READ: §FK (Mike: generated by rules, unique to each playthrough, kept for good; one clock everywhere); §ET.10 call 3 and §EW.8 calls 2 and 7 (what §FK answers); §EX.5 (the exit and its stand-in, prompt 46); §FJ.1 (the first ruin drawn from the new game's seed); crawler.json persistence and exit.stand_in; worlds.json generation and clock; scripts/core/world_save.gd (WorldSave: the open world's save in user://worlds/<seed>.json, flush, last world) and scripts/core/world.gd (its Continue, around line 186); scripts/crawler/crawler_main.gd (_seed) and crawler_fires.gd (the holders and their lit state); the day clock (DayCycle) and whether the crawler runs it (prompt 61 may have added it).

BUILD: (1) One seed per new game (persistence.seed): New game rolls it; every dungeon's own seed is drawn from it and the dungeon's place in the world (persistence.dungeon_seeds), so the first tomb (§FJ.1's pick when wired, the tomb until then) and the one the exit leads to are the same every time for that game. The exit's stand-in (prompt 46) takes the next dungeon from the game's seed, not a new one. SEED= in the environment still pins a game for the checks. (2) The save (persistence.save): the game's seed, which dungeon you are in, each dungeon's relit holders (and gates when they exist), written when they change and when the game closes. Reuse WorldSave if it fits the crawler cleanly; if it doesn't, a crawler save beside it in user://, your call, and say which in PROGRESS. The tools never write a save (WorldSave.read_only). (3) Continue and New game (persistence.continue): Continue opens the last world in the dungeon you were in, at its hearth, its relit holders lit; New game rolls a new seed and starts fresh. Use the boot or settings screen that exists; no new menu art, plain is fine. (4) One clock (§FK.3, worlds.json clock): wherever the crawler runs DayCycle, it runs the fixed 144-minute split from sky/day_cycle.json (day 60, dusk 18, night 48, dawn 18) with no latitude, axial tilt or day of year. If the crawler doesn't run the clock yet, leave that part and say so. The open world's latitude clock is unchanged.

CHECK (headless, tools/crawler_check.gd): the same game seed builds the same first tomb and the same next tomb twice over (same pieces, holders, exits); two different game seeds build different first tombs; relight three holders, save, reload into a fresh scene, and the same three are lit and no others; New game after that rolls a different seed and every holder is cold; a check run writes no save. If the clock part is built: dusk, night and dawn start at the same clock times whatever world or seed.
```

## 64 — §FL.2: 480 lines the most
**Status:** built 596646a; undone by Mike's correction, a1e64b3 (7 Oct evening: 720 the most, 480 the default, never 1080; half_hd and fine back)

look.json max_internal_lines is now 480 (was 720). Drop presets above 480 (half_hd 540, fine 720) from Settings > Display > Pixel size and from auto's order; auto picks the tallest preset ≤480 that divides the window exactly, else 480 letterboxed. 480 stays default. Update the _help lines that mention 720/540.

(Superseded by §FM.11, 9 Oct: Mike's 7 Oct evening correction, "the very maximum resolution should be 720 but default at 480. no 1080." Nothing to build; a1e64b3 already did it.)

## 65 — The boss behaviour pool: every boss draws its moves at random — §FM.1

**Status:** built 492ae98
**Mike sees:** Nothing yet. A boss now picks what to do next from a list at random, so no boss can be learned like a script. Until the snake gets its new moves (66), every boss plays exactly as it does today.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 57 (built). This pass builds ONE thing: design §FM.1 of docs/design/RECONCILIATION_2026-09-30.md, the scaffolding for a boss's behaviour pool, and nothing from §FM.2 (the snake's new states are prompt 66). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off boss_pool.json _help.about for the parts you wire, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.1 and §FM.2 (so the scaffold fits what the snake will need); §EY (the boss rule: one per dungeon, prowls only the unlit, the last light drives it to its lair); data/boss_pool.json (rule, pools, _help) and data/bosses.json (rule; every boss's pattern); scripts/crawler/boss.gd (build, tick, _begin, _refresh, _after_light, _turn_back_if_lit, _notice), boss_ground.gd, pursuit.gd, creature_strike.gd.

BUILD: (1) A BossPool class (scripts/crawler/boss_pool.gd) that loads a boss's states from boss_pool.json pools[<boss id>], draws the next state by weight, never the same state twice running unless it is the only one (rule.repeat_gap), from live RNG (not seeded from the game seed: rule.live_rng), and returns how long it lasts (dwell_s as [min, max]). (2) Boss asks the pool for its next state when the current one ends or its dwell runs out. The state 'rounds' is the boss's existing behaviour, wrapped and not rewritten: a pool with only 'rounds' plays exactly as the boss does now. (3) A state is a small unit with enter, tick and exit, registered by its id, so prompt 66 can add the snake's. An id in the data that no code registers is skipped with one warning, never a crash. (4) rule.never_breaks holds: the pool is never asked while the boss is mid-strike, in its wind-up, retreating (the last light, §EY) or fleeing a pot; a state can't skip the strike's tell and wind-up, can't block the exit, can't stay in a relit room. (5) Change no number in bosses.json and nothing about the strike.

CHECK (headless, tools/crawler_check.gd or a new tools/boss_pool_check.gd): a test pool of three states over 200 draws: the order is not a fixed sequence, no state repeats twice running, every state is drawn, and the draws follow the weights within a loose tolerance; every boss with only 'rounds' walks the same route from the same seed as before this pass (compare with the boss check as built); an unknown state id warns once and is skipped; no draw happens mid-strike.
```

## 66 — The snake's pool: freeze, doorway, observe, coil — §FM.2

**Status:** built 1bc37be
**Mike sees:** The snake stops being predictable. Look at it from far off and it goes still and half-vanishes into the stone. It sits in doorways and watches you. It follows you a while before it circles round behind. And sometimes you turn at the sound of it and it is already coiled and striking.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 65. This pass builds ONE thing: design §FM.2 of docs/design/RECONCILIATION_2026-09-30.md, the four new states in the desert snake's pool, on prompt 65's BossPool. The snake only; no other boss changes. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look at the freeze once with the walkabout at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off boss_pool.json _help.desert and _help.camouflage, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.2 (Mike's four behaviours: a plain big snake, no feathers); §EY; data/boss_pool.json (pools.desert, camouflage and their _help); data/bosses.json bosses.desert (hunt_mps, watch_s, coils_in, torch_delay, peek_m, tunnels, strike, body); scripts/crawler/boss.gd, boss_body.gd (the snake's sprites: how they are tinted), boss_ground.gd (tunnels, doors, dead ends), boss_sounds.gd, creature_strike.gd, pursuit.gd, half_dark.gd (§FC.4).

BUILD, each a state registered on the desert pool: (1) freeze_watched: you look at it (its head or body inside look_deg of your view axis, seen in your torch's light or your half-dark sight) from at least from_m[0] away: it stops dead and lies still. Its sprites' value and hue move toward the stone under it by camouflage.blend, never above camouflage.max_blend, never transparent: a texture and value shift only, so a frozen snake is hard to spot but never gone (Mike keeps invisibility for another boss). It holds until you close inside close_m, look away for look_away_s, or its dwell ends, then the pool draws the next state with no tell. It never freezes in a room you have lit. (2) doorway_watch: it picks the nearest doorway of an unlit room on its rounds that you are not in and lies with its head in the gap (head_m), still, for its dwell; it leaves when that room is lit, as the boss rule says. (3) observe_then_behind: it follows you at observe_m, outside your torch's circle, along corridors and its tunnels, for observe_s; then goes round behind you and strikes with the strike as built (tell, wind-up, recovery unchanged). (4) coil_ambush: it goes round into a coil lies_coiled_behind_m behind you and waits; its tell sounds as you move on; if you turn toward it, its wind-up has already begun (wind_up_begun_on_turn), so the jump scare is real; the hit is hit 1 of three (§FD), never more; if you keep walking it lets you go when its dwell ends. Keep everything 49 and 57 built (the slither, the torch hold, the peek, the tunnels, the strike tell); a sprinter still outruns it (hunt_mps unchanged).

CHECK (headless): over 300 draws all four new states and 'rounds' are entered; the freeze starts only with the head inside look_deg and beyond from_m[0], and ends on close_m, look_away_s or dwell; the sprites' blend never exceeds max_blend (sample the tint); doorway_watch's head sits in a doorway of an unlit room and the snake leaves when it is lit; observe_then_behind's distance stays inside observe_m and outside the torch circle; in coil_ambush a view turn toward it starts the wind-up on that tick and the resulting hit counts as one hit; hunt_mps is still 4.6. Walkabout once: the snake frozen at 20 m in a lit corridor, readable on a second look.
```

## 67 — The shaman and the cauldron at the hearth — §FM.6

**Status:** built 3485919
**Mike sees:** You wake at the hearth with the shaman sitting across the fire, and a cauldron hangs over the flame. It is there from the first moment in every dungeon.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time after prompt 52 (built). This pass builds ONE thing: design §FM.6's opening room, the shaman and the cauldron at the hearth, and nothing else from §FM.6. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look at the hearth room once with the walkabout at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.6 (the opening room); §FM.3 (what was not taken from the pasted Aztec doc: no speaking shamans, no obsidian mirrors); §EX.4 (one hearth per dungeon), §ET.9 (one rig, one animation set), §FH (the folk at the hearth in 3D), §FL.1 (metal is allowed again); crawler.json rescuer and folk_3d; scripts/crawler/hearth_folk.gd, tomb_build.gd (where the hearth is built), tomb_kit.gd, light_field.gd.

BUILD: (1) The one figure at the hearth (the rescuer) reads as the shaman. Same rig, same animations, wordless: give him what the shared wardrobe already allows, such as a ladle or stirring stick in the hand, and nothing new in the rig. Nobody speaks (§ED). (2) A cauldron hangs over the hearth's flame from a tripod or chain, in the ruin's own material or clay or iron, your call. It is painted per §ES and the hearth's amber falls on it live. It is empty: the brew is prompt 72. (3) It must not hide the flame: lighting a torch at the hearth works from the usual spot, and the hearth's entry in the light field (light_field.gd) is unchanged. (4) It is in the hearth room of every dungeon from the first moment, and it does not move the place you wake.

CHECK (headless, tools/crawler_check.gd): over 20 seeds every dungeon's hearth room has exactly one shaman figure and one cauldron within the hearth's radius; a torch lights at the hearth from the usual spot; the light field at 3 m from the hearth is unchanged within 1 percent; the wake spot is not inside the cauldron's or the figure's collision. Walkabout once at the hearth: the cauldron reads against the flame and the shaman sits across the fire.
```

## 68 — Floors and the fork: light the first floor and two ways open — §FM.6

**Status:** built f2bd277
**Mike sees:** Light every torch on the first floor and two openings appear together: a stair up toward the day and a stair down to a second floor. Take either one first. Nothing is lost by choosing.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 59 (built). This pass builds ONE thing: design §FM.6's floors and the fork, in the crawler. Floor two is a plain second floor here: its fog is prompt 69, the room pool is prompt 70, and the boss does not move (see below). No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off descent.json _help.floors and _help.fork and crawler.json _help.floors for what you wire, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.6, §FM.10 calls 2 and 4; §FF.1 (floors) and §FF.2 (cleared by light); §EX.4 (one hearth per dungeon) and §EX.5 (the exit, never gated, its stand-in); §EY.3 (the lair); §FG (nothing marks a way); data/descent.json (floors, fork, _help); crawler.json exit, floors, cleared, gates, plan; scripts/crawler/way_out.gd, tomb_build.gd (the plan, the spine), crawler_fires.gd, crawler_main.gd.

BUILD: (1) A dungeon has descent.json floors.count floors (two). Floor one is the tomb as built. Floor two lies below it, reached by a stair down, built by the same generator in the same stone (same_stone) with no second hearth (§EX.4); its rooms get wall torches to light like the others. Its stair up lands at floor one's stair down. Cleared-by-light (§FF.2) counts per floor. (2) The fork: when every torch on floor one is lit (the cleared.when test), fork.opens happens in the same tick: the stair down and the surface stair both open, with a visible and audible opening (reuse the gates machinery, gates.relight_to_open) and fork.log_line once. Until then the way down is a plain stone seal in the stair's mouth. Nothing points to it (§FG). (3) fork.gate_surface is false: the surface stair stays open as built (§EX.5, exit.never_gated) and only the way down waits on the lights. Set true, the surface stair is sealed until floor one is lit. Mike has not answered §FM.10 call 2, so keep it false and say so in PROGRESS. The surface stair still leads where exit.stand_in sends it until prompt 71 builds the surface. (4) The boss stays on floor one as built and its lair hole (§EY.3) does not move: moving its home to the base layer waits for Mike's answer to §FM.10 call 4. (5) If prompt 63's save exists, the fork's opened state is saved per dungeon with the relit holders.

CHECK (headless, tools/crawler_check.gd): floor one's torches cold: the way down is sealed; all lit but one: still sealed; the last one lit: both openings open on the same tick and the log line shows once; with gate_surface false the surface stair is open throughout, and true it is sealed until lit; take the stair down to floor two and back up to the matching stair on floor one; floor two has no second hearth and its own torches count toward its own cleared test only; over 50 seeds the way down is always reachable once lit and the exit is still reachable with every holder cold.
```

## 69 — Floor two's fog: the same stone, darker — §FM.6

**Status:** built a490eda
**Mike sees:** Floor two is the same stone as floor one, but a low fog fills it all the way through, so it feels darker and you see less far.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 68. This pass builds ONE thing: design §FM.6's floor-two fog, uniform, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look at floor two once with the walkabout at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off descent.json _help.floor_two, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.6 (floor two: the energy of the whole place a little darker, a layer of fog, uniform for now, no separate system); docs/design/LOOK_REFERENCE.md and §ES (the frame: shade is navy and never grey, distance gets lighter and bluer); data/descent.json (floor_two.fog and _help); look.json; scripts/crawler/crawler_main.gd (the environment), light_field.gd.

BUILD: (1) Floor two gets one fog across the whole floor at descent.json floor_two.fog.density, its colour from the look's shade navy (color_from) and never grey, lighter and bluer with distance. Floor one has none. (2) Fog is only fog: it changes how far you see and how far your torch reaches by rendering, and nothing else. No change to the light field's numbers, to what the boss sees or hears, or to any rule. (3) Ease it in over the last metres of the stair down and out over the stair up, so there is no pop. (4) It must hold in the 480-line nearest-neighbour frame (§ES) without banding badly or breaking the dither.

CHECK (headless, tools/crawler_check.gd and tools/crawler_frames.gd): floor two's environment fog is on at the data's density and floor one's is off; the fog colour has blue above red and is not grey (red, green and blue within 0.02 of each other fails); at the stair the density eases between the two floors in the ease distance; the frame renders at the default 480 lines. Walkabout once on floor two: a lit torch's pool reads in the fog and the far end of a corridor is lost. Mike tunes density in descent.json.
```

## 70 — The room pool: hand-built big rooms shuffled into each run — §FM.6

**Status:** built fae9712
**Mike sees:** Two tombs now differ in the rooms you come to, not only in the winding. Each run draws a few hand-built big rooms into the layout, a pillar hall, a stepped hall, a sunken court, among the usual rooms and passages.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 68. This pass builds ONE thing: design §FM.6's room pool, Phantasy Star Online style, three archetypal big rooms for the tomb. It adds to §EX.2's plan and replaces nothing. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look at each new room once with the walkabout at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off room_pool.json _help.about for what you wire, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.6; §EX.1 (one ruin, one stone), §EX.2 (the plan: spine, module, side branches) and §EX.4 (one hearth per dungeon, wall torches in the other rooms); §EU (the walls) and §ES (painted detail); data/room_pool.json (big_rooms, generic, archetypes and _help); crawler.json plan; masonry.json styles; rooms.json; scripts/crawler/tomb_build.gd, tomb_kit.gd, ruin_style.gd, fitted_stone.gd.

BUILD: (1) Author the three archetypes in room_pool.json (pillar_hall, stepped_hall, sunken_court) as hand-built rooms in the tomb's one stone: footprint, door places, what stands in them, sconce places. They are first guesses on Claude's three briefs; say in PROGRESS that Mike may rename or replace them. Their torches count toward the floor's lit test (§FF.2). (2) The plan draws big_rooms.per_dungeon of them by the dungeon's seed and places them on the spine or a side branch, never on the exit's last stretch and never in the heart room (the one hearth room, §EX.4); an archetype appears once per dungeon. (3) The generic rooms and paths are the ones already built, shuffled by the seed. The spine through the heart, the exit that is always reachable (§EX.5) and one hearth all still hold. (4) Same seed, same dungeon.

CHECK (headless, tools/crawler_check.gd): over 100 seeds every dungeon has its spine, its heart and an exit reachable with every holder cold; the number of big rooms is inside per_dungeon; all three archetypes appear somewhere and none twice in one dungeon; the same seed twice gives the same plan; no room overlaps another; one hearth per dungeon. Walkabout once in each archetype: it reads in the tomb's stone and its torches can be lit.
```

## 71 — The tomb's surface: day and night above the stair — §FM.7

**Status:** built 0181fcf
**Mike sees:** Take the stair up and you come out into daylight on a small stretch of land above the tomb. It is day, dusk or night as the clock says, with things to find and look at. You no longer wake in another tomb.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompts 63 (the one clock, the seed) and 68 (the fork). This pass builds ONE thing: design §FM.7 and §EW.7 step 2, the surface pocket above the tomb. It does not build any other world, the passages between worlds, the far horizon's other worlds, or the map (§EW.7 steps 3 and 4), and no harvesting (prompt 72). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look at the surface once with the walkabout at the end (dawn, noon, dusk, night). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off worlds.json _help for the parts you wire, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.7 and §FM.8 (the map is reference only for now); §EW (§EW.1 size and edge, the layered horizon, §EW.7 step 2) and §EV (the hearth shaft and the vents' stacks); §FK.1 and §FK.3 (no planet; one 144-minute clock, the same everywhere, no latitude); §FM.10 calls 1 and 3 (open: how a culture ruin sits with the biome worlds; compass walks against underground passages); worlds.json (size, edge, clock, horizon, generation, worlds.desert); crawler.json exit (stand_in, leads_to, daylight_at_top) and way_out.gd; sky/day_cycle.json and DayCycle; the biome data for the tomb's world.

BUILD: (1) A bounded surface pocket in the tomb's biome (worlds.json size; the land itself closes it, never an invisible wall, §DM), with ground, ground cover and sky in the look (§ES; the sun is the one light, shade navy, distance lighter and bluer). (2) The stair up from the dungeon (the surface stair of prompt 68, and exit.leads_to) comes out at the ruin on the surface above it, with daylight at the top as built; the same stair takes you back down to the same dungeon with its relit holders still lit. exit.stand_in stays for any dungeon with no surface yet. (3) The day-night cycle runs there for ambience only: the one clock of §FK.3 (the fixed 144-minute split, day 60, dusk 18, night 48, dawn 18), the same clock as underground, not a copy of it. Nothing is gated by the time of day. (4) The vents' stacks (§EV) stand on it. A little ambient life from the ecosystem archetypes, and a few things to find that are never required (§FG): ruin remains, litter, old camp marks. (5) No map, no fast travel, no edges to other worlds here.

CHECK (headless, tools/crawler_check.gd): the stair up arrives on the surface at the ruin above the stair; the stair down returns to the same dungeon with the same holders lit; the sun's height at the start of dawn, noon, dusk and night matches the 60/18/48/18 split and is the same value as the underground clock at the same moment; walking 2000 m from the stair in any direction never leaves the pocket's edge into void; over 20 seeds the surface builds. Walkabout: noon, dusk, night.
```

## 72 — Harvest and brew: a plant from above, a brew from the shaman — §FM.7

**Status:** built 376cf23
**Mike sees:** On the surface you find the local sacred plant and take part of it, carry it down to the shaman, and he brews it in the cauldron. What you drink is a different experience for each plant.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this only after prompts 67 and 71. The world's plant is in data/sacred/sacred_plants.json (design §FM.9; the Aztec world's is ololiuhqui, id ololiuhqui, a liana the engine already draws); read its flags first. Load that one entry for the surface only, never into data/plants (the open world and the §CC trim stay as they are). If the engine can't draw the world's plant, say so to Mike and stop; do not stand in another plant. This pass builds ONE thing: design §FM.7's harvest-and-brew loop for the tomb's world, and nothing for the other ruins. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.7 (harvest, carry, brew; respect; a different experience per plant, never a harder one; what a brew does is NOT locked); §FM.4 (nothing here reaches the secret layer: not decided); §FM.3 (no timers, torch drain or hallucinations: Mike did not choose them); data/ruin_compass.json (the world's plant); docs/design/RUIN_ROSTER_REFERENCE.md (the rite, in one line; no doses, no preparation); data/plants; hands.json; scripts/crawler/hearth_folk.gd and the prompt 67 cauldron.

BUILD: (1) One harvestable plant of the world's species grows on the surface. Harvesting takes part of it and leaves the plant standing, never uproots it, and it regrows on the game clock; the shaman, seen once doing the same, wordless, is how the way is taught (Mike: the shaman teaches the respectful harvest). (2) You carry it, as one carried thing, to the hearth: the shaman takes it to the cauldron and works it, wordless, using the rig's own animations. (3) You drink. The effect is a placeholder vision tint and pulse, set per plant in data, for a first guess of 120 seconds, then it fades. It gates nothing and changes no rule: no timer on anything else, no torch drain, no hallucinations. (4) Nothing about it reaches the secret layer (§FM.4).

CHECK (headless): the plant stands after a harvest and regrows in the data's time; carrying and handing over works from the usual spot; the tint starts on drinking and ends on its time; no gameplay number anywhere changes while it runs.
```

## 73 — Tomes as collected pages: found on the base layer — §FM.5

**Status:** built 1bff283
**Mike sees:** On the lowest floor you find old scrolls and tomes, each holding only some pages of a longer book. You keep what you find, and reopen any of it to read.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 68. This pass builds ONE thing: design §FM.5, tomes as collected pages, found on the base layer. It adds no new texts: the text fill is chat's. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.5 and §DL; data/tomes.json (find, tomes: only the I Ching and the Tao Te Ching so far, both filled false) and data/tomes/README.md (the page format: pages split on a line of ---); data/descent.json floors.base_layer; hud.json log_more (tome); scripts/player/tomes.gd and scripts/ui/tome_panel.gd (R to read a tome you carry).

BUILD: (1) A tome can be split into fragments: tomes.json gets an additive fragments list per tome (an id and a page range each), and each fragment is its own pickup. Nothing changes for a tome with no fragments list. (2) Fragments lie on the dungeon's base layer (descent.json floors.base_layer, the last floor), by the existing find rule (find.at, share_of_hearts), never in a chest, and different fragments of a book can lie in different dungeons. (3) What you pick up you keep. You can reopen any collected fragment to read it, and the book's title page says how much you hold ('pages 1 to 5 of 12'). That is all: no systems, no scoring (§DL: flavour for now). (4) A tome whose text file is unfilled opens its title page only, as built. Two tiers of depth for now (§FM.5); do not build a third.

CHECK (headless): a split tome's fragments are each found at most once per dungeon and only on the last floor; a collected fragment can be reopened after leaving the dungeon; the title page's count is right with zero, some and all fragments; a tome with no fragments list behaves as before.
```

## 74 — The compass walk and the reference map — §FM.8

**Status:** waits (a second world, and §FM.10 calls 1 and 3)
**Mike sees:** Each surface has four directions, and walking one leads to the neighbouring ruin. A map shows where you have been and which way things lie, and takes you nowhere.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this only after prompt 71 and once a second world exists, and only after Mike has answered §FM.10 calls 1 and 3. If he hasn't, say so to Mike and stop. This pass builds ONE thing: design §FM.8, the fixed compass walk between surfaces and the reference-only map. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, take [NOT WIRED YET] off ruin_compass.json _help.about, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes.

READ: §FM.8 and §FM.10; docs/design/RUIN_ROSTER_REFERENCE.md; data/ruin_compass.json (map, walk, ruins and their exits); worlds.json (map, links); the built surface from prompt 71.

BUILD: (1) On a surface, the open edge in a direction leads to the neighbouring ruin's surface named by ruin_compass.json exits, the same in every playthrough; other edges stay closed by the land (§DM). (2) The map is reference only: it shows the ruins you have reached and their bearings, and takes you nowhere. Set worlds.json map.fast_travel off (§FM.8 supersedes §EW and §FK.3 for now). (3) The first ruin is still drawn at random (§FJ.1) and each ruin's inside still comes from the game's seed (§FK.2).

CHECK (headless): every exit in ruin_compass.json that points at a built world arrives there from the opposite side; an exit that points at a ruin not built yet stays closed by the land; the map lists only reached ruins; no map action moves the player.
```

## 75 — A mushroom shape: a cap on a stalk — §FM.13

**Status:** built 431c230
**Mike sees:** Nothing in the crawler yet. The engine can now draw a real mushroom, a little cap on a thin stalk, so teonanácatl (and the fly agaric) stop being drawn as a leaf rosette.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time. This pass builds ONE thing: design §FM.13 item 1, a MUSHROOM plant shape, and nothing else. No screenshots after every step: check with headless numbers, and look once at the end with species_row. Prepend a PROGRESS entry, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.9 and §FM.13 of docs/design/RECONCILIATION_2026-09-30.md; docs/design/PLANT_SCHEMA.md (the archetype rule: readable at 64 px, LOD never smooths the silhouette); §ES (painted: diffuse only, roughness 1, no normal maps, occlusion baked toward navy or olive); data/sacred/sacred_plants.json (the entry's appearance, height_m, color, accent, tint, and the file's flags); scripts/ecology/plant_species.gd (enum Shape, how a shape string is read), scripts/ecology/plant_meshes.gd (mesh_for, material_for, the CACTUS, ROSETTE and SPIKE_ROSETTE builders it sits beside), tools/species_mesh_check.gd and tools/species_row.gd. Also scripts/ecology/litter_field.gd (litter fungi fruit with mesh_for, so they will pick the new shape up) and the Amanita muscaria and A. caesarea entries in data/biomes/04_taiga.json and 12_mediterranean_scrub.json.

BUILD: (1) Add MUSHROOM to PlantSpecies.Shape and its string "mushroom". (2) PlantMeshes builds it: a cap (conic, bell or flat by the entry's cap.form, with an optional low nipple) on a stalk whose height and thickness come from height_m and the cap's size_cm; a few fruit bodies grouped per instance, slightly leaning. Cap colour from appearance.cap.colour with its secondary toward the rim; gills dark under the cap. Near and far levels: the far one keeps the cap-on-stalk silhouette. No leaf tiles (leaf type none). (3) Data, as a data-driven one-liner (say so in the commit): set teonanacatl's shape to "mushroom" in data/sacred/sacred_plants.json, and Amanita muscaria's and A. caesarea's in their biome files (their broad caps and stout stalks from their own entries). Do not add data/sacred to SpeciesDB's load: build the test species straight from its entry the way SpeciesDB builds a catalogue entry, so the open world and the §CC trim are untouched.

CHECK (headless): species_mesh_check passes with the two Amanitas now built as mushrooms; a new check builds teonanacatl from its data/sacred entry at both levels and gets a mesh whose height is inside height_m and whose widest point is in its top third (a cap, not a rosette). species_row once: the fly agaric and teonanácatl side by side in grass, readable as mushrooms.
```

## 76 — A globe cactus shape: a low button in the ground — §FM.13

**Status:** built d2c2859
**Mike sees:** Nothing in the crawler yet. The engine can now draw peyote as what it is, a flat blue-green button with white woolly tufts sitting in the gravel, instead of a tall cactus column.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time. This pass builds ONE thing: design §FM.13 item 2, a GLOBE_CACTUS plant shape, and nothing else. No screenshots after every step: check with headless numbers, and look once at the end with species_row. Prepend a PROGRESS entry, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.9 and §FM.13 of docs/design/RECONCILIATION_2026-09-30.md; docs/design/PLANT_SCHEMA.md (the archetype rule: readable at 64 px, LOD never smooths the silhouette); §ES (painted: diffuse only, roughness 1, no normal maps, occlusion baked toward navy or olive); data/sacred/sacred_plants.json (the entry's appearance, height_m, color, accent, tint, and the file's flags); scripts/ecology/plant_species.gd (enum Shape, how a shape string is read), scripts/ecology/plant_meshes.gd (mesh_for, material_for, the CACTUS, ROSETTE and SPIKE_ROSETTE builders it sits beside), tools/species_mesh_check.gd and tools/species_row.gd. Also the Trichocereus entries in data/plants/trichocereus.json (the CACTUS column it must not become).

BUILD: (1) Add GLOBE_CACTUS to PlantSpecies.Shape and its string "globe_cactus". (2) PlantMeshes builds it: a flattened dome as wide as appearance.stem.diameter_cm and as tall as height_m, sunk to its rim (most of its height below the ground line), its rib count from stem.ribs, the ribs cut by cross-furrows into rounded bumps, a pale wool tuft (areole_colour) on each bump and a woolly boss at the centre; no spines when spine_cm is [0, 0]. Several heads in a tight clump per instance. Stem colour and secondary from the entry; flower (a small pink bell at the crown) only where the entry blooms. The far level keeps the flat button. (3) Data, as a data-driven one-liner (say so in the commit): set peyote's shape to "globe_cactus" in data/sacred/sacred_plants.json. CACTUS is unchanged. Do not add data/sacred to SpeciesDB's load: build the test species straight from its entry the way SpeciesDB builds a catalogue entry, so the open world and the §CC trim are untouched.

CHECK (headless): species_mesh_check still passes (every CACTUS unchanged); a new check builds peyote from its data/sacred entry at both levels and gets a mesh no taller than height_m above the ground line and at least three times as wide as it is tall above ground. species_row once: peyote in gravel beside a San Pedro, readable as a button, not a stub column.
```

## 77 — A bulb shape: a fan of leaves on a bulb, and its flower head — §FM.13

**Status:** built ea48c3c
**Mike sees:** Nothing in the crawler yet. The engine can now draw leshoma as it looks: a bare brown bulb half out of the ground with a flat fan of grey-green rippled leaves, and in its season a round head of pink flowers.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time. This pass builds ONE thing: design §FM.13 item 3, a BULB plant shape, and nothing else. No screenshots after every step: check with headless numbers, and look once at the end with species_row. Prepend a PROGRESS entry, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FM.9 and §FM.13 of docs/design/RECONCILIATION_2026-09-30.md; docs/design/PLANT_SCHEMA.md (the archetype rule: readable at 64 px, LOD never smooths the silhouette); §ES (painted: diffuse only, roughness 1, no normal maps, occlusion baked toward navy or olive); data/sacred/sacred_plants.json (the entry's appearance, height_m, color, accent, tint, and the file's flags); scripts/ecology/plant_species.gd (enum Shape, how a shape string is read), scripts/ecology/plant_meshes.gd (mesh_for, material_for, the CACTUS, ROSETTE and SPIKE_ROSETTE builders it sits beside), tools/species_mesh_check.gd and tools/species_row.gd. Also leshoma's repro.bloom and growth blocks (when it flowers, and that the flowers come before the leaves) and the season code the other plants use for bloom (leaf_season.gd, fruit_crop.gd).

BUILD: (1) Add BULB to PlantSpecies.Shape and its string "bulb". (2) PlantMeshes builds it: a bare brown bulb, about half above the ground, and from its neck a flat upright fan of strap leaves in ONE plane (two ranks), 8 to 16 of them, stiff, blunt and rippled at the edges (appearance.leaf), sometimes twisted a little; the fan's plane turns at random per instance. In its bloom season, a single round head of narrow pink trumpets (appearance.flower) on a short thick stalk sits on the bulb, with no leaves yet, as the entry says; if the bloom season can't be shown on this pass, build the leafy form only and say so in PROGRESS. The far level keeps the fan in one plane. (3) Data, as a data-driven one-liner (say so in the commit): set leshoma's shape to "bulb" in data/sacred/sacred_plants.json. SPIKE_ROSETTE is unchanged. Do not add data/sacred to SpeciesDB's load: build the test species straight from its entry the way SpeciesDB builds a catalogue entry, so the open world and the §CC trim are untouched.

CHECK (headless): species_mesh_check still passes (every SPIKE_ROSETTE unchanged); a new check builds leshoma from its data/sacred entry at both levels and gets a mesh whose leaf fan is thin across (its depth under a quarter of its width, before the random turn) with a bulb at the base. species_row once: leshoma in grass, readable as a fan on a bulb from the side and as a line from edge-on.
```

## 78 — The snake becomes the feathered serpent: plumes and a rattle — §FN.2

**Status:** todo
**Mike sees:** The snake wears quetzal plumes along its neck and back, and has a rattle at the tip of its tail you can hear. It moves, hunts and strikes exactly as before.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time. This pass builds ONE thing: design §FN.2, the snake's plumes and its rattle, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FN.0 call 1 (this supersedes §FM.2's "no feathers and no Quetzalcoatl": Mike's later words), §FN.2, §FM.2 and §FA.2; data/aztec_temple.json → snake (plumes, rattle, fireless); data/bosses.json bosses.desert (body, strike, torch_delay) and data/boss_pool.json (pools.desert, camouflage); data/audio.json (snake_warn, snake_hiss); scripts/crawler/boss_body.gd (BossBody and its bake), boss_sounds.gd, scripts/creatures/sound_synth.gd, shaders/figure_sprite.gdshader; LOOK_REFERENCE.md and §ES (painted: diffuse only, no normal maps, no shine).

BUILD: (1) Plumes: a row of feather shapes along the snake's neck and spine on its baked head and body sprites, painted green and turquoise with a little red toward the breast (aztec_temple.json snake.plumes; Claude's first guess, Mike tunes by eye). They must read at the sprite's pixel height (px_head, px_seg); if the bake cannot hold them at that size, raise the sizes in data and say so, never blur. The camouflage (§FM.2 freeze) still works and still never goes past max_blend; the plumes take the blend too. (2) A rattle: a few rings at the tail tip on the last body sprite, and a new sound snake_rattle in SoundSynth, a dry fast shiver, played through the same boss sound path as snake_warn, with the same distance and muffling. (3) When it sounds is Mike's call and not made (§FN.8 call 8): add a data block with _help whose first guess is aztec_temple.json snake.rattle.claude_guess_when (it sounds while the snake holds off at your flame, beside snake_warn, so the sharp snake_hiss still always means the strike), and list in _help the other values Mike may switch to by editing (always while it moves; just before the strike). (4) Change no behaviour or number: speeds, reach, wind-up, the four states, never beaten. The snake breathes no fire (§FN.2).

CHECK (headless): boss_snake_check, boss_check and boss_pool_check still pass with the same counts; a new check finds the plume colours in the baked sprites' pixels and the sprite heights unchanged, finds snake_rattle in SoundSynth non-silent, and shows it plays in exactly the states the data names and never when the list is empty. Walkabout once: the snake in a lit corridor, reading as a snake with plumes at its distance.
```

## 79 — The Aztec temple's stone: a masonry style — §FN.1

**Status:** todo
**Mike sees:** Nothing in the crawler yet. The game can now cut a temple in dark volcanic stone with red, pitted tezontle, so the Aztec ruin has its own look and the Inca stone stays the Inca's.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time. This pass builds ONE thing: design §FN.1's stone, a masonry.json style for the Aztec temple, and nothing else. It does not change which stone the tomb as built uses. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FN.1 and §EX.1 (one ruin, one stone: floor, ceiling, doors, stairs, niches, sconces, stone dressing and rubble are cut from the walls' own stone); data/masonry.json (styles, style_by_theme, and andean_tomb as the model: rule, walls preset, floor, ceiling, doors, hearth, pillars); data/aztec_temple.json → stone; docs/design/RUIN_ROSTER_REFERENCE.md (Aztec); scripts/crawler/ruin_style.gd and fitted_stone.gd; §EU (relief in real geometry, settled with age) and §ES (painted).

BUILD: (1) A new style aztec_temple in masonry.json, additive, with its own _help: squared, coursed blocks of dark volcanic stone (basalt and andesite) with reddish porous tezontle for the pitted red look; relief carving possible on its faces (the day-sign panels of prompt 80 use it); plaster and red paint surviving only in the recesses, weathered and settled with age; every stone surface cut from the same stone (no_general_palette true). Doors: a flat lintel over a square opening, not the Inca's trapezoid (Claude's first guess; adjust if it reads wrong). (2) Register it as a new style_by_theme key (aztec_temple), changing no existing entry: the tomb keeps andean_tomb, snow_ruins keeps passage_grave_snow, default is unchanged.

CHECK (headless): the existing masonry and crawler checks pass with the same counts; the tomb's style is unchanged byte for byte; the new style builds a wall, a floor, a ceiling, a door, a stair and a niche all in the one stone, with no surface taking the general palette. Walkabout once: an Aztec-style test room beside a tomb room, reading as two different stones.
```

## 80 — The Aztec temple as a ruin kind: the blood altar and the calendar room — §FN.1

**Status:** todo (after 79)
**Mike sees:** A new ruin, the Aztec temple, when the game is told to draw it: a round blood-altar chamber and a calendar room are always in it, joined by shuffled ways. Until Mike says which world it sits in, the game still plays the tomb.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 79. This pass builds ONE thing: design §FN.1, the Aztec temple as a ruin kind with its two fixed chambers, and nothing else. It builds no pyramid (84), no brew change (82, 83) and no new floor count (81). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FN.1 (a temple, not a tomb; the tonalpohualli; the two named chambers; PSO-style bones) and §FN.8 calls 1 and 8 (open: which world; which floor holds each chamber); §FM.6 and §FJ.1 (how the first ruin is drawn from the roster); data/aztec_temple.json (chambers, calendar, floors); data/room_pool.json (big_rooms, generic, archetypes and their _help); data/masonry.json (aztec_temple, prompt 79); scripts/crawler/room_pool.gd, room_pool_build.gd, tomb_kit.gd, tomb_floors.gd, tomb_build.gd.

BUILD: (1) The Aztec temple as a kind the generator can build: the tomb generator and the room pool run with the aztec_temple stone and the temple's own big rooms, drawn from the dungeon's seed (§FK.2). (2) Two archetypes in room_pool.json, each with ruin_kinds ["aztec_temple"] and its own _help, built in the temple's one stone: aztec_blood_altar, a round chamber with a low round stone altar in the middle, a stone bowl beside it, the stain dried near-black brown (never bright red; fire is the one warm accent), offerings, no bodies; and aztec_calendar_room, whose walls carry the tonalpohualli: the 20 day-sign panels of aztec_temple.json calendar.day_signs with dot numerals 1–13, in relief, flavour only, no puzzle and nothing to operate. Both are in every Aztec temple (count 2, no repeat); the pool's other big rooms stay drawn at random. Torches in them count toward the floor's lit test (§FF.2) as in any room. (3) Which floor holds each chamber is open: put both on floor one for now, in data, and say so. (4) Mike has not said which biome world the Aztec temple sits in (§FN.8 call 1): add aztec_temple.json → enabled, default false, and read it where the first ruin is drawn. With it false the game plays exactly as now; with it true the temple joins the roster. Do not choose a world.

CHECK (headless): with enabled false, crawler_check, room_pool_check and the other crawler checks pass with the same counts; with it true, over 100 seeds every temple has its altar chamber and its calendar room exactly once, the plan is reachable with every holder cold, the same seed gives the same plan, and the tomb's own archetypes never appear in a temple nor the temple's in a tomb. Walkabout once in each chamber.
```

## 81 — A third floor, drawn by seed — §FN.3

**Status:** superseded (§FO.0, 10 Oct: Mike made every ruin one floor; this prompt is not to be built)
**Mike sees:** Some ruins now go three floors down instead of two. Light a floor and the stone seal grinds open onto the next, as it does on floor one.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time after prompt 68 (built). This pass builds ONE thing: design §FN.3, a third floor, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FN.3, §FM.6 and §FM.1; data/descent.json (floors, fork, floor_two, and their _help: count is held to 2 as built); data/audio.json stone_seal; scripts/crawler/tomb_floors.gd, fork.gd, relight_gate.gd, floor_fog.gd, tome_pages.gd (last_floor), residents.gd, tomb_kit.gd.

BUILD: (1) A dungeon has two or three floors, drawn by its seed (§FK.2): add floors.range [2, 3] to descent.json with a _help line, keeping count as the older key it is read beside. (2) A third floor is grown by the same generator in the ruin's one style, like floor two, with floor two's fog (density the same for now; Mike tunes, §FN.3 leaves open whether it is darker again), residents read per floor. (3) Light every torch on floor two and a stone seal sinks in its stair down to floor three, grinding as floor one's does (stone_seal, the same cue), the way up staying as built. A dungeon of two floors plays exactly as before. (4) The tomes lie on the dungeon's last floor, as last_floor already says. The boss stays where it is: §FM.10 call 4 is unanswered, so do not move it.

CHECK (headless): over 200 seeds both counts occur and the same seed gives the same count; a two-floor dungeon matches the old plan; on a three-floor one floor three is reachable only after floor two is lit, every floor has an exit reachable with every holder cold, the split tome's pages lie only on floor three, and fork_check, fog_check and tome_pages_check still pass. Walkabout once on floor three.
```

## 82 — The Aztec brew plant becomes teonanácatl — §FN.5

**Status:** waits (Mike's answer to §FN.8 call 1)
**Mike sees:** On the surface above the Aztec temple you find the sacred mushroom, take some, carry it down, and the shaman brews it.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this only after Mike has answered §FN.8 call 1 (which biome world the Aztec temple sits in): teonanácatl grows in cloud forest and wet meadow in the data, and the game grows each species only where it really grows. If he hasn't answered, say so to Mike and stop. This pass builds ONE thing: design §FN.5.4, the Aztec brew plant, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FN.5.4 and §FN.8 calls 1 and 2; §FM.7 (the respectful harvest, one carried thing, a different experience per plant); data/brew.json (world, vine, teach, carry, plants); data/sacred/sacred_plants.json (teonanacatl: appearance, habitat, sacred); data/visions.json; scripts/crawler/brew.gd, sacred_vine.gd, surface_plants.gd; scripts/ecology/mushroom_mesh.gd and tools/mushroom_check.gd (queue 75).

BUILD: (1) brew.json → world.plant becomes teonanacatl for the Aztec world; ololiuhqui stays in the data, not grown. (2) The mushroom grows on the surface where its habitat says, a small group in short grass, not hung from a tree: the engine draws it with the MUSHROOM shape. (3) The harvest, the shaman's teaching, the carry and the brew are as built for the vine: you take some and leave the rest standing, it regrows on the game clock, wordless. (4) The placeholder vision stays until prompt 83.

CHECK (headless): brew_check passes with the new plant; the group stands after a harvest and regrows in the data's time; it stands only on ground its habitat allows; carrying and handing over work from the usual spot.
```

## 83 — The vision filter: palette, hidden carvings, glowing and moving glyphs — §FN.5

**Status:** waits (80 and 82)
**Mike sees:** Drink the brew and the temple changes: its colours shift, carvings you could not see come up in the stone, and the glyphs glow and move. It fades, and the carvings are gone from view again. Nothing about how you play changes.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this only after prompts 80 and 82. This pass builds ONE thing: design §FN.5, the vision filter for the Aztec brew, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FN.5 (every point, especially 5.3's bounds), §FM.7 and §FM.3 (no hallucinations, no timer, no torch drain); data/visions.json (rule, cultures.aztec); data/brew.json plants.*.vision (the placeholder tint and pulse); data/aztec_temple.json (calendar, calendar_room); scripts/ui/brew_vision.gd and post_grade.gd; scripts/crawler/brew.gd; LOOK_REFERENCE.md and §ES.

BUILD: (1) A palette swap on the frame while the brew is active, replacing the placeholder tint for this plant; its direction is visions.json cultures.aztec.look (geometry breathing across the stone), colours Claude Code's first guess, Mike tunes by eye. (2) Hidden carvings: a layer of relief and marks that is in the ruin from the start and is drawn only while the brew is active, on the calendar room's panels and elsewhere in the temple, in the temple's stone; a few panels read as a short wordless picture-history of the temple's people (placeholder panels; the story's content is Claude (chat)'s to write later, and the game never names the culture). (3) Glow and motion: the glyphs glow, multiply and change while the brew lasts. (4) The bounds hold: the carvings are really there, so no creature, face or other thing is added; the glow casts no light, does not count toward a floor's lit test (§FF.2), and does not touch the boss or the dark; nothing about play changes, no timer, no torch drain. (5) It fades in and out as the placeholder does; the length stays brew.json's value (§FN.8 call 6 is open).

CHECK (headless): with the brew active the hidden layer is drawn and with it off it is not; the floor's lit test, the boss's behaviour and every gameplay number are identical with and without the brew; no light node is added by the glyph glow; the fade ends clean. Walkabout once: the calendar room sober, then under the brew.
```

## 84 — The Aztec pyramid on the surface — §FN.4

**Status:** todo (after 79 and 80)
**Mike sees:** On the surface above the Aztec temple a step pyramid stands, overgrown and crumbling, with an altar at the top. It is scenery: it takes you nowhere.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompts 79 and 80. This pass builds ONE thing: design §FN.4's Aztec surface twin, a step pyramid with an altar at its top, and nothing else. No other culture's silhouette (Mike: flagged only). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FN.4 (ambient world building; not a fast-travel landmark; whether you come up inside it or beside it is open; two altars, §FN.8 call 5); §FM.7; data/worlds.json → surface (ground, edge, landmark, plants); data/aztec_temple.json → surface, stone; data/masonry.json (aztec_temple); scripts/crawler/surface.gd, surface_build.gd, surface_ground.gd, surface_plants.gd; LOOK_REFERENCE.md (the shot: a path to a landmark against the sky).

BUILD: (1) A stepped pyramid in the Aztec stone: broad tiers, a stair up one face, a small altar on the flat top, weathered, crumbling, overgrown only as the surface's climate allows. (2) It stands on land (never water), in view from where you come up, as a landmark the eye is led to; the stair up from the dungeon comes out beside it for now (inside or beside is open). (3) It is scenery only: no fast travel, no beacon, no exit, no gameplay number; walking up its stair is just walking. (4) It stands only where the Aztec temple does: read aztec_temple.json → enabled (prompt 80), so with that false nothing changes.

CHECK (headless): with enabled false, surface_check passes with the same counts; with it true there is exactly one pyramid, on land, visible from the arrival point, its stair walkable and its top reachable, and no gameplay number or exit differs. Walkabout once at dusk: the pyramid against the sky from the arrival point.
```

## 85 — One floor per ruin, and the way up opens when the boss is first driven home — §FO.2, §FO.3

**Status:** todo
**Mike sees:** Every ruin is one floor. Light every torch and the boss goes home to its lair; the stone grinds and the way up to the surface opens. There is no stair down and no darker second floor.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time (68 and 69 are built). This pass builds ONE thing: design §FO.2 and the exit half of §FO.3: one floor per ruin, and the way up opening when the boss is first driven home. It builds no secret room (86), no blackout (87) and nothing Egyptian (88, 89). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FO.0 to §FO.3 and §FO.9 call 3; §FM.6, §FN.3 (superseded: queue 81 is not to be built), §EX.4, §EX.5, §EY.2; data/ruin_loop.json (floors, boss_home, exit and their _help); data/descent.json (floors, fork, floor_two and their _help); data/audio.json stone_seal; scripts/crawler/tomb_floors.gd, fork.gd, relight_gate.gd, floor_fog.gd, way_out.gd, boss.gd (release), tomb_kit.gd, crawler_save.gd.

BUILD: (1) A ruin has one floor: read ruin_loop.json floors.count where descent.json floors.count is read now, and set descent.json floors.count to 1 with §FO.2 in its _help. The stair down is not built and floor two's fog is not drawn; leave that code in place, switched off by data (never delete it), and say which keys you read. (2) The way up opens when the boss is first driven home: §EY.2's release, every torch lit and the boss gone down its lair. Add ruin_loop.json → exit.sealed_until_home, default true (Mike's word, §FO.3), with a _help line naming §EX.5's 'an exit always exists' and §FO.9 call 3: true seals the way up until then; false keeps it open from the start as built today. When it opens, the stone_seal grinding plays, heard as far as it is now. (3) First time only, and kept: crawler_save keeps the exit open on Continue. (4) The room pool fills the one floor as it filled floor one. Nothing else about the boss changes.

CHECK (headless): over 100 seeds every dungeon is one floor with no stair down and no fog node; light every torch and the boss is in its lair and the way up is open, and it stays open after a save and Continue; before the last light, with sealed_until_home true, the way up is sealed, and with it false it is open as before; fork_check, fog_check, room_pool_check, boss_check and crawler_save_check pass, or are updated to say one floor (name each change). Walkabout once: light the floor, hear the stone, walk out.
```

## 86 — The secret opening, its room and the tome — §FO.4

**Status:** todo (after 85)
**Mike sees:** A sealed way you can see from the start. When the boss goes home it grinds open onto rooms joined to the ruin, with no loading screen, and at the end lies a scroll or tome you can take. Taking it does nothing else yet.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 85. This pass builds ONE thing: design §FO.4, the secret opening, its rooms and the tome, and nothing else. It builds no blackout and no angry boss (87). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FO.3, §FO.4 and §FO.9 call 5; §FM.4 (the game-wide secret layer: a different idea, untouched), §FM.5, §FM.6, §EX.5; data/ruin_loop.json (secret and its _help); data/room_pool.json; data/tomes.json; data/audio.json stone_seal; scripts/crawler/tomb_kit.gd, tomb_build.gd, tomb_floors.gd, room_pool.gd, room_pool_build.gd, relight_gate.gd, tome_pages.gd.

BUILD: (1) From the dungeon's seed (§FK.2) the generator plans one secret wing on the floor: one or two rooms, built in the ruin's one stone, joined to the floor by one opening. The opening is placed where it can be seen from a main route as you walk (the thing to get right: you see a way you cannot pass), and it never sits on the way out (§EX.5). (2) The opening is a stone seal (ruin_loop.json secret.opening.kind) with collision until the boss is first driven home, then it slides open with the stone_seal grinding (prompt 85). The wing is the same floor and the same scene: no loading screen, no new world. (3) The wing has no sconces of its own and does not count toward the floor's lit test (§FF.2); you carry your torch in. (4) One scroll or tome lies at the end of the wing, in the ruin's culture's own real marks (§FN.5.1), never named on screen. Use tome_pages.gd's page object if it fits, else a plain scroll model; you pick it up with the usual interact and it joins your collection (§FM.5). Taking it does nothing else yet: prompt 87 hangs phase two on it. Say which you used and whether it counts as one of §FM.5's pages (§FO.9 call 5 is open).

CHECK (headless): over 100 seeds every ruin has exactly one secret wing, joined by one opening that is visible from a main route and is not on the way out; the same seed gives the same plan; the wing is unreachable before the boss goes home and reachable after; the floor's lit test is unchanged with the wing present; the tome can be taken once; crawler_check, room_pool_check and tome_pages_check pass. Walkabout once: see the sealed way, light the floor, walk in, take the tome.
```

## 87 — Phase two: the blackout, and the boss's angry round — §FO.5, §FO.6

**Status:** waits (86)
**Mike sees:** Take the tome and every flame in the ruin goes out, the hearth and your own torch too, and nothing can be relit. The boss comes out again, faster and meaner, and you run for the exit on whatever light the place has without fire. The snake does it first.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 86. This pass builds ONE thing: design §FO.5 and §FO.6, phase two, and nothing else. The snake is the boss built, so it is the first test; no new boss. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FO.5, §FO.6 and §FO.9 calls 1, 4 and 7; §EY (rule, release), §FM.1 (never beaten; the pool's never_breaks), §FD (three hits), §FA (fire pots), §ET.3 (you wake at the hearth); data/ruin_loop.json (phase_two and its _help); data/bosses.json (rule, release, bosses.desert), data/boss_pool.json, data/torch.json, data/harm.json; scripts/crawler/boss.gd, boss_pool.gd, boss_ground.gd, crawler_fires.gd, light_field.gd, half_dark.gd, vents.gd, glow_moss.gd, fire_pots.gd, crawler_save.gd; tools/boss_snake_check.gd.

BUILD: (1) The trigger is taking the tome (prompt 86). It puts out every flame: every relit holder and planted torch, the torch in your hand and the hearth fire. Nothing can be lit again: unlit torches stay unlit, a fire pot cannot be lit, the hearth cannot relight them (ruin_loop.json phase_two.blackout). The code that keeps a relit holder lit (§ET.4) and the torch hold hold everywhere else; only phase two overrides them. (2) The dark is ambient light only: count only what the place gives off without a flame. First guess: the day and night shafts from above (vents.gd, on the one clock), glow moss and anything else the look rules let glow. Say which sources you counted; Mike answers §FO.9 call 4. (3) The boss comes out again: it leaves its lair (the release reversed: its long cry travelling up from its hole, over emerge_after_s from the data), prowls the whole floor (no room is lit, so none is closed to it), and runs at its own speeds times phase_two.boss.speed_mult. Do it for any boss key through the one code path, no per-boss code; the snake is the one you can test. (4) Everything else holds: never beaten; three hits and Good night; every wind-up and tell plays; its pool is unchanged. 'Good night' wakes you at the hearth as built, in the dark; say what you saw (§FO.9 call 1). (5) The way up stays open and walking out ends the visit as it does now. (6) Save: first guess is that the blackout is kept, so Continue loads the dark (otherwise quitting restores the lights); put it in ruin_loop.json phase_two.save (true), say so in its _help, and flip by data if Mike answers otherwise (§FO.9 call 7).

CHECK (headless): after the tome, no holder, torch or hearth is lit and none can be lit (hearth, sconce, pot, torch); the lit-holder count is zero; the snake emerges after emerge_after_s and its hunt speed is the base times speed_mult, still under the 5.6 sprint; no room is closed to it; the way up is open and reachable on foot with no flame; three hits end in Good night and a wake by the hearth; a save and Continue mid-blackout loads the dark; boss_check, boss_snake_check, boss_pool_check, fire_pot_check, crawler_harm_check and crawler_save_check pass. Walkabout once: take the tome, the dark, the run.
```

## 88 — The Egyptian stone: big sandstone blocks — §FO.1

**Status:** todo
**Mike sees:** Nothing in the crawler yet. The game can now cut a ruin in big squared sandstone blocks, so the Egyptian ruin has its own look and no other culture's stone is touched.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this any time. This pass builds ONE thing: design §FO.1's stone, a masonry.json style for the Egyptian ruin, and nothing else. It does not change any stone already in use. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FO.1 and §EX.1 (one ruin, one stone: floor, ceiling, doors, stairs, niches, sconces, stone dressing and rubble cut from the walls' own stone); data/masonry.json (styles, style_by_theme, andean_tomb and the prompt 79 style aztec_temple as models); data/ruins.json → styles.true_pyramid (the nearest existing source, not wired); data/ruin_compass.json → ruins.egypt; docs/design/RUIN_ROSTER_REFERENCE.md; scripts/crawler/ruin_style.gd and fitted_stone.gd; §EU (relief in real geometry, settled with age; firelit stone underground may go amber, §EU.6) and §ES (painted).

BUILD: (1) A new style egyptian_pyramid in masonry.json, additive, with its own _help: very large squared sandstone blocks in even courses with tight, straight joints (Mike: 'big sandstone blocks'), pale to ochre, settled with age and wind-worn, relief possible on its faces; shade in the scene's navy, never grey; every stone surface cut from the same stone (no_general_palette true). Doors: a flat lintel over a square opening. Claude's note, from its own knowledge and not a source opened: Giza itself is mostly limestone and the big sandstone-block temples are Karnak, Luxor and Abu Simbel; build the sandstone Mike asked for. (2) Register it as a new style_by_theme key (egyptian_pyramid), changing no existing entry.

CHECK (headless): the existing masonry and crawler checks pass with the same counts; every existing style is unchanged byte for byte; the new style builds a wall, a floor, a ceiling, a door, a stair and a niche all in the one stone, with no surface taking the general palette. Walkabout once: an Egyptian test room beside a tomb room and an Aztec one, reading as three different stones.
```

## 89 — The Egyptian ruin and the pharaoh in its sarcophagus — §FO.1

**Status:** waits (87 and 88, and Mike's answer to §FO.9 call 2)
**Mike sees:** An Egyptian ruin of big sandstone blocks, with mummies waking in their sarcophagi and a mummy pharaoh who prowls the dark, its own sarcophagus its lair: the lid grinds aside as it comes out and grinds shut when the last light sends it home.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this only after prompts 87 and 88 and Mike's answer to §FO.9 call 2 (which biome world holds the Egyptian ruin). If he hasn't answered, say so to Mike and stop. This pass builds ONE thing: design §FO.1, the Egyptian ruin kind and its pharaoh, and nothing else. No brew, no plant, no surface silhouette (§FO.7). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FO.1, §FO.7 and §FO.9 calls 2 and 6; §FJ.2 and §FN.0 call 2 (the mummy and sarcophagi are Egypt's); §EY.3 and §FM.1; data/bosses.json → unplaced.pharaoh and _help.pharaoh; data/residents.json → creatures.mummy; data/masonry.json (egyptian_pyramid, prompt 88); data/room_pool.json; scripts/crawler/boss.gd, boss_body.gd, boss_ground.gd, boss_pool.gd, residents.gd, resident.gd, tomb_build.gd, tomb_kit.gd, room_pool.gd.

BUILD: (1) The Egyptian ruin as a kind the generator can build, in the egyptian_pyramid stone, one floor, drawn by the dungeon's seed (§FK.2). Add egyptian_pyramid.json → enabled, default false, read where the first ruin is drawn; with it false the game plays exactly as now. Do not choose a world: use the one Mike named. (2) Sarcophagi with ordinary mummies (residents.json mummy, the waker: its lid grinds aside) laid by the generator as the skeletons are. (3) The pharaoh: move its entry from bosses.json unplaced to bosses.<world> once Mike names the world, keep its lair block, and add its boss_pool.json entry with 'rounds' only (boss_pool_check counts one pool per boss in bosses). Its body is its own, as the snake's is (§FO.1). Its lair is its own sarcophagus: put it in the pharaoh's chamber at the base of the floor; the lid grinds aside while it prowls and grinds shut when the last light drives it in, through §EY.2's release as built for the snake; a ring of collision keeps you at its edge (enterable false). Its numbers are Claude Code's first guesses, slow and unhurried to start, in data with _help, and Mike tunes. No strike block yet beyond what boss.gd needs, with a tell distinct from the mummy resident's. Phase two (prompt 87) applies to it with no per-boss code.

CHECK (headless): with enabled false everything passes with the same counts; with it true, over 100 seeds every Egyptian ruin has its pharaoh's chamber with one sarcophagus, mummies in sarcophagi, one floor, a plan reachable with every holder cold and the same plan for the same seed; the lid is open while the pharaoh prowls and shut once it is home; boss_check, boss_pool_check, residents_check and the prompt 85 to 87 checks pass. Walkabout once: the chamber, the lid.
```

## 90 — Scarabs: ambient skitterers in the Egyptian ruin — §FP.1

**Status:** waits (89)
**Mike sees:** Small scarabs skitter across the Egyptian ruin's floors and walls and scatter from your steps and your light. They never touch you and do nothing.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 89. This pass builds ONE thing: design §FP.1, the ambient scarabs, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FP.1 and §FP.7; data/egypt_ruin.json (scarabs and its _help); data/worlds.json → life (ambient, population_sim false); scripts/crawler/wall_life.gd, surface_life.gd, resident.gd, resident_sprite.gd, tomb_build.gd.

BUILD: (1) Ambient scarabs in the Egyptian ruin (the kind prompt 89 builds), a handful to a room, placed from the dungeon's seed, skittering along the floor and up the walls in short runs. (2) They scatter from your footsteps (egypt_ruin.json scarabs.skitter.from_steps_m) and from your light, and never touch you: no collision with you, no strike, no slow, no hit of any kind. (3) They count in nothing: not the floor's lit test (§FF.2), not the boss, not the residents. (4) A small dark beetle that reads from above at a glance, painted per §ES (diffuse only, no shine); Claude Code's first guess, Mike settles by eye. Read the numbers from the data file with their defaults.

CHECK (headless): in every Egyptian ruin over 50 seeds each room has scarabs within the data's count; walking the whole floor produces no hit, no slow and no change to harm.json's counters; the lit test is identical with and without them; they scatter inside from_steps_m. Walkabout once: walk a room and watch them scatter.
```

## 91 — The pharaoh's locust swarm: a ranged slow — §FP.2

**Status:** waits (89)
**Mike sees:** From a distance the pharaoh sends a small swarm of locusts that lunges at you. You hear it coming from far off. If it catches you it only slows you for a moment, which is how the pharaoh gets close. It never counts as a hit.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 89. This pass builds ONE thing: design §FP.2, the locust swarm as one state in the pharaoh's pool, and nothing else. No other plague. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FP.2, §FP.9 calls 1 and 2; §FM.1 (the pool's never_breaks) and §EY; data/egypt_ruin.json (pharaoh_plagues and its _help); data/bosses.json → unplaced.pharaoh (or bosses.<world> once prompt 89 moves it); data/boss_pool.json (rule, the desert's entries as the model); scripts/crawler/boss.gd, boss_pool.gd, boss_state.gd, boss_states/coil_ambush.gd (the model for a state), creature_strike.gd, crawler_player.gd (where your speed is set), boss_sounds.gd, scripts/creatures/sound_synth.gd.

BUILD: (1) A pool state locust_swarm (scripts/crawler/boss_states/locust_swarm.gd, id matching) in the pharaoh's boss_pool.json entry beside 'rounds' (weight 2, dwell 8 to 18 s: first guesses, in data with _help). It needs you within trigger_m of the pharaoh and not within its melee reach, and never in a lit room or stretch. (2) The tell, always played before a launch: a drone heard from heard_m away that builds as the swarm nears (a SoundSynth voice, built from the data). (3) The swarm: a small cloud of locust sprites that lunges at you at lunge_mps through the dark, and stays out of lit rooms like the rest of the boss. If it reaches you it slows you to slow_mult of your speed for slow_s through the player's speed multiplier, then your speed is restored exactly; cooldown_s between swarms. It is a status, not a hit: harm.json is untouched, no red ring, no heartbeat, and three swarms never end in Good night. (4) in_phase_two is false: with prompt 87's blackout the state is left out of the draw (BossState.can_enter) until Mike answers §FP.9 call 1. torch_stops_it stays null until call 2: do not invent a torch rule, and say so. (5) The pharaoh's melee and its 'rounds' do not change.

CHECK (headless): over 200 draws the state comes up, never twice running; the tell plays before every launch; a swarm that reaches you applies slow_mult for slow_s and then your speed is exactly as before; the harm counters never move from a swarm; it never launches into a lit room; in phase two it is not drawn; boss_pool_check, boss_check and crawler_harm_check pass (update boss_pool_check to name the new state). Walkabout once: hear it from far, get caught, be slowed, get away.
```

## 92 — Hieroglyphs on the walls — §FP.3

**Status:** waits (88 and 89)
**Mike sees:** Rows of real hieroglyphs carved in relief dress the Egyptian ruin's walls. You can see them but not read them yet.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompts 88 and 89. This pass builds ONE thing: design §FP.3, hieroglyphs as wall marks, and nothing else. No text to read yet (93). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FP.3, §FN.5.1 (real marks, never named on screen), §EU (relief in real geometry) and §EX.1 (one ruin, one stone); data/egypt_ruin.json (hieroglyphs and its _help); data/masonry.json (egyptian_pyramid from prompt 88; aztec_temple and prompt 80's day-sign panels as the model for relief panels); scripts/crawler/fitted_stone.gd, ruin_style.gd, tomb_build.gd, room_pool_build.gd.

BUILD: (1) Hieroglyph panels in relief, cut from the ruin's one stone, on the Egyptian ruin's walls and pillar faces: bands and columns of signs in registers, placed from the dungeon's seed. (2) Real signs only, never invented (§FN.5.1): take a small set of genuine, common Egyptian signs (for example the ankh, was sceptre, djed pillar, wedjat eye, scarab, reed leaf, water ripple, owl, vulture) and list them in a new block in data/egypt_ruin.json → hieroglyphs.signs with their Unicode names, drawn as relief by the engine. No sign is arranged to spell a passage yet. (3) Give each panel a stable id from the seed so prompt 93 can attach a line of text to it; set reads false on every panel for now. (4) A panel never sits on the way out or in a doorway, and never blocks a route (§EX.5). The game never says what the marks are.

CHECK (headless): every Egyptian ruin over 50 seeds has panels, every panel is in the ruin's one stone and its signs are all from the data's list; ids are unique and the same seed gives the same ids; no panel blocks a route or the way out; crawler_check and the masonry checks pass with the same counts. Walkabout once: a corridor of hieroglyphs lit by your torch.
```

## 93 — The Egyptian brew: blue lotus, mandrake, a vision that feels real, and glyphs that read — §FP.4

**Status:** waits (89, 92, and Mike's answer to §FO.9 call 2)
**Mike sees:** On the surface you find the blue lotus or the mandrake, carry it down, and the shaman brews it. Drink it and the ruin shows you things that feel completely real, perhaps the boss glimpsed in the dark, though nothing is there; and the hieroglyphs on the walls turn into lines you can read. It fades and the marks go quiet again.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this only after prompts 89 and 92, prompt 83 (the vision filter) and Mike's answer to §FO.9 call 2 (which biome world holds the Egyptian ruin). If he hasn't answered, say so to Mike and stop. The plants grow only where they really grow (§FP.5): if the world he names grows neither, say so and stop. This pass builds ONE thing: design §FP.4, the Egyptian brew, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FP.0 call 1, §FP.3 to §FP.6 and §FP.9 calls 3, 5 and 7; §FM.7, §FN.5 (every point); data/visions.json (rule, cultures.egypt, and its amends and kept_inside_for_egypt); data/brew.json; data/sacred/sacred_plants.json (blue_lotus, mandrake: appearance, habitat, flags); data/egypt_ruin.json (hieroglyphs); scripts/crawler/brew.gd, sacred_vine.gd, surface_plants.gd; scripts/ui/brew_vision.gd and post_grade.gd (prompt 83); the panels of prompt 92.

BUILD: (1) brew.json gets the Egyptian world's two plants, blue_lotus and mandrake, grown on the surface where their habitat allows and drawn in the nearest shape the engine has (neither draws right yet: no water-lily shape, no trunkless rosette; say so). The harvest, the shaman's teaching, the carry and the brew are as built for the other cultures, wordless, respectful, leave the rest standing. (2) The vision runs through prompt 83's filter, for Egypt only: the palette and hidden-carving behaviour as that prompt built it, plus display-only figures that look completely real: mummies and the pharaoh glimpsed in doorways and dark corners, standing where the real boss never is. They have no collision, no strike, no sound that counts, change no gameplay number or the floor's lit test, and fade with the brew; every other culture's brew keeps its 'no creatures' rule. Blue lotus and mandrake give the same vision for now; Mike has not said whether the lotus is gentler (§FP.9 call 3), so keep that in data. (3) The glyphs read: under the brew each hieroglyph panel of prompt 92 shows one line of text, and sober it is marks again. Mike has not picked the passages (§FP.9 call 5): use a plain placeholder line from a data list and say so; real passages only, with a public-domain translation (§DL). (4) How long it lasts is the built placeholder (§FN.8 call 6); do not change it.

CHECK (headless): with the brew active the figures and the readable lines are drawn and with it off they are not; collision, harm counters, the lit test, every boss behaviour and every gameplay number are identical with and without the brew; no figure ever stands where the real boss stands; no light node is added; another culture's brew still draws no figures; the fade ends clean. Walkabout once: sober, the marks; under the brew, the lines and a figure in a doorway.
```

## 94 — The Maya stone: limestone — §FQ.1

**Status:** todo (after 88)
**Mike sees:** A new stone in the game's data: pale weathered limestone with a trace of old red in the carving. Nothing in the game uses it yet.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 88 and by the same method. This pass builds ONE thing: the Maya ruin's stone (design §FQ.1), and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FQ.1 and §EX.1 (one ruin, one stone); data/masonry.json (styles, and prompt 88's egyptian_pyramid as the model); data/maya_ruin.json (ruin); scripts/crawler/fitted_stone.gd, ruin_style.gd; the masonry checks.

BUILD: (1) A masonry.json style maya_temple: pale grey-cream limestone, finely dressed and carved, a trace of old red stucco only in the deepest recesses (no bright paint; the look rules and diffuse-only hold, §ES). Block sizes, joint depth and settle are Claude Code's first guesses in data with _help; Mike tunes by eye. (2) Floor, ceiling, doors, stairs, niches and sconces cut from the same stone (§EX.1). (3) Nothing builds a Maya ruin yet: the style is only defined, so no existing ruin changes.

CHECK (headless): the style loads and every masonry check passes with the same counts for the existing styles; the tomb and the Aztec temple are unchanged. Walkabout once: a test wall in the new stone beside the Egyptian one.
```

## 95 — The Maya ruin: a jungle temple, its calendar room and a way down — §FQ.1

**Status:** waits (89, 94, and Mike's answer to §FQ.5 call 1)
**Mike sees:** A limestone temple swallowed by jungle, with the Maya count carved in a room of its own, and a cenote leading down into it.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this only after prompts 89 and 94 and Mike's answer to §FQ.5 call 1 (which biome world holds the Maya ruin). If he hasn't answered, say so to Mike and stop. This pass builds ONE thing: design §FQ.1, the Maya ruin kind, and nothing else. No boss yet (96). Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FQ.0 to §FQ.1 and §FQ.5 calls 1 and 3; §FO (one floor, the way out, the secret room); §FN.1 and §FN.5.1 (the Aztec calendar room as the model; real marks never named); data/maya_ruin.json (ruin); data/ruin_compass.json (maya); scripts/crawler/tomb_build.gd, room_pool_build.gd, dungeon_builder.gd as prompt 89 left them.

BUILD: (1) The maya_temple ruin kind, built as prompt 89 builds the Egyptian one: the limestone of prompt 94, one floor, a plan reachable with every holder cold, the same plan for the same seed, and the secret room and the exit of §FO. (2) A calendar room, a fixed chamber among the shuffled rooms, carved with the Maya count: the 260-day Tzolkin, the 365-day Haab and the Calendar Round as real relief, never named, flavour only (as the Aztec calendar room). Use real signs only. (3) The cenote: a round natural shaft with a pool, open to the sky, as the way down only if Mike has said so in call 3; otherwise a set piece in the secret room, and say which. (4) Jungle growth on the stone only where the climate allows (§EU).

CHECK (headless): over 100 seeds every Maya ruin has its calendar room, one floor and a plan reachable with every holder cold; the same plan for the same seed; its stone is the one limestone style; the prompt 85 to 87 checks and the masonry checks pass. Walkabout once: the temple, the calendar room and the cenote.
```

## 96 — Camazotz, the death bat — §FQ.2

**Status:** waits (95)
**Mike sees:** A bat the size of a man hangs in the dark overhead where you are about to walk. Pass beneath and it swoops and gets you once, then keeps diving through any room with room to dive, so you run. In a tight passage it drops and crawls at you, slower. A lit room is safe.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. Do this after prompt 95. This pass builds ONE thing: design §FQ.2, Camazotz and his three states, and nothing else. Torchfire 1, the crawler. No screenshots after every step: check with headless numbers, and look once at the end with the walkabout (§CA). Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes and what he can tune.

READ: §FQ.2 and §FQ.5 calls 2, 4 to 6; §FM.1 (the pool's never_breaks), §EY and §FD (three hits); data/maya_ruin.json (camazotz and its _help); data/bosses.json → unplaced.camazotz; data/boss_pool.json (rule, the desert's entries as the model); scripts/crawler/boss.gd, boss_pool.gd, boss_state.gd, boss_states/coil_ambush.gd and observe_then_behind.gd (the models for a state), creature_strike.gd, boss_ground.gd, boss_sounds.gd, scripts/creatures/sound_synth.gd.

BUILD: (1) Camazotz as the boss of the maya_temple ruin kind, keyed like the pharaoh in prompt 89: a boss_pool.json entry and a bosses.json entry in the same pass (boss_pool_check wants pools.size() == bosses.size()), with a lair in the bat house. (2) Three pool states (scripts/crawler/boss_states/): roost_ambush (it hangs from an overhead point on the unlit way you are likely to take, chosen by extrapolating your heading to the nearest unlit room or junction, and strikes when you pass beneath), swoop_chase (once it has swooped it is activated and keeps diving where the room has the overhead space, min_ceiling_m in the data) and ground_crawl (where the space is too tight to swoop it lands and crawls, slower than its swoop). All numbers are the data's first guesses; read them with defaults. (3) A connected swoop or crawl strike is one hit of three through the existing strike code (harm.json, CreatureStrike), after a tell that always plays (SoundSynth voices from the data). Whether every later swoop hits or only the first is Mike's call 2: build every swoop as a hit unless he has said otherwise, and say so. (4) It never enters a relit room, never blocks the exit, and a torch hold holds; the last light drives it to its lair. (5) Phase two: left out of the draw until Mike answers call 6, and say so.

CHECK (headless): over 200 draws each state comes up and never the same twice running; the tell plays before every strike; a swoop that connects is exactly one hit and three end in Good night; it never enters a lit room; it never roosts on the way out; the pool counts match, boss_pool_check, boss_check, crawler_harm_check and stagger_check pass (update them to name the new states). Walkabout once: be ambushed from overhead, run from the dives, get into a tight passage and see the crawl.
```
