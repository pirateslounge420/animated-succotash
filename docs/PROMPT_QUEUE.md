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

Built so far: 01–36. Next up: 37–43 (§EH–§EN, the village economy, locked 5 Oct 16:04; do them in order, 37 is small and must go first).

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
| 37 | §EH | No metal, and a camp can be fifty | todo |
| 38 | §EL | The workshop: one hut, two benches, the hearth outside | todo |
| 39 | §EI | What a camp needs, and the trades that follow | todo |
| 40 | §EK | The whole animal: the hunt, the hut, the six things | todo |
| 41 | §EJ | Food passed round, the night stories, the gift | todo |
| 42 | §EM | Third places: the soak, the great tree, the water rock, the porch | todo |
| 43 | §EN | The library: the camp book moves, the record-keeper, the winter count | todo |

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

**Status:** todo
**Mike sees:** Nothing new on screen. The marsh folk's maker is a reedworker, no camp anywhere mentions iron, and a camp can grow to fifty folk before it stops.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EH of docs/design/RECONCILIATION_2026-09-30.md (no metal; the craft ceiling is clay, bone, stone, wood and fibre), plus the one number §EI changes (camps.json sim.population.village_cap 24 → 50), and nothing else from that session. No screenshots after every step: check with a headless tools/no_metal_check.gd of your own. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove the [NOT WIRED YET] prefix from camps.json _help.village_economy's first clause only if you wire village_cap (you will), pull with rebase before you push, never force. Explain to Mike in plain English at the end what changed and what he can tune.

READ: §EH, §BO (the old bog-iron exception, now gone), §BN (the maker is never a smith), §BQ (no slag mound), data/peoples/README.md rule 4, data/peoples/marsh.json (maker is now reedworker, technique bog_iron removed, ruin signature smoke_floor), data/techniques.json bog_iron (retired: true), data/villages.json specialties glass and mining (retired), camps.json sim.population.village_cap.

BUILD: (1) Sweep the engine for metal: grep scripts/ for bog_iron, "bog iron", smith, bloomery, slag, iron, forge, smelt, ore. Any code path that picks, names, draws or logs them goes: Peoples.* maker names and props (CampProps), Techniques.* (a technique row with retired: true is never taught by a headman, never listed, never logged), RuinMarks and ruin signatures (no slag mound is ever placed; marsh gets smoke_floor from its file), Villages/VillagePlan specialties (a specialties row with retired: true is never rolled). "Iron-red water" at a marsh seep is scenery and stays. (2) village_cap: CampSim reads sim.population.village_cap (50) wherever 24 was a constant; births and the ladder gates are unchanged (sim.ladder_gates.folk_for_specialist stays 8). (3) Nothing with an edge: confirm the §ED.7 rule still holds with the smith gone (spear and bow are finds or a maker's work of wood, bone and stone; items.json needs no change unless a metal word is in a name or description: fix the word).

CHECK (tools/no_metal_check.gd, headless): on seeds 42 and 7731, walk every placed camp and village: no maker named smith, no technique bog_iron taught or listed, no slag_mound signature, no village specialty glass or mining; a marsh camp's maker is reedworker and its ruin has smoke_floor; CampSim's cap resolves to 50 and a camp fed past 24 keeps growing to 50 then stops; grep of scripts/ for the metal words returns only comments that say "no metal (§EH)".
```

## 38 — The workshop: one hut, two benches, the hearth outside — §EL

**Status:** todo
**Mike sees:** At a camp that has reached storage, a second roof beside the fire circle: a workshop in the people's own materials. Inside, a soft bench (a hide on a frame, cord being twisted, a basket) and a hard bench (a knapping floor, bone in a row, a bow drill); folk sit at one or the other and work, with different motions and sounds; the hearth outside has the stew pot and the smoke rack; a kiln hump stands downwind where there is a potter. One thing on the porch tells you which people this is from the road. By day the folk are at the hut; at dusk they are at the fire.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EL of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.workshop and every data/peoples/*.json huts block, and nothing else from that session. One thing at a time. No screenshots after every step: check with a headless tools/workshop_check.gd of your own, run the walkabout once at the end (§CA, tools/walkabout.gd) for the one look, labelled as a harness frame per §CG. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the workshop clause of camps.json _help.village_economy and from the huts blocks you read, pull with rebase before you push, never force. Explain to Mike in plain English at the end: what the code reads, what it writes, what changes on screen, what he can tune.

READ: §EL (all of it), §BN (the maker), §BV–§BW (jobs and pieces: the benches are the §BV work_at_hearth job grown up and moved indoors), §CY (the fire circle: seats, pose, idles; the bench idle is the same seated base pose), §BO (the biome dresses the people), §BQ (the knapping floor and the kiln hump are the live versions of the ruin signatures), §EK.1 step 2 (the carcass will go in this hut's door: leave a door and a named spot for it, nothing more), R9 (big texels, clean silhouettes), R6. camps.json sim.workshop (benches, verbs, idles, sounds, skills_distinct, one_folk_one_bench_at_a_time, cross_bench_per_day_max, maker_bench_share, player_brings_to_bench, day_heart, night_heart, porch_seat); each people file's huts (workshop_form, soft, hard, hearth, kiln, porch_sign); sim.jobs if §BV's jobs are built, and if they are not, build the smallest walker this needs (a folk walks from the fire circle to a bench, sits, works, walks back at dusk) and say so in PROGRESS.

BUILD: (1) At every camp at the storage rung or above (CampSim ladder), place ONE workshop hut 6–10 m from the fire, door toward it, built by CampProps from the people's huts.workshop_form in the camp's own stone/timber/thatch/hide/reed (the same tints the shelter uses), one roof, open or half-open on the fire side so the benches read from outside; a porch seat by the door (sim.workshop.porch_seat). (2) Two benches inside: soft and hard, each a flat surface (log, slab, mat on the floor) with 3–5 props from the people file's huts.soft / huts.hard, as small meshes or cards at 16 texels a metre, the props that exist in the piece vocabulary (camps.json store.pieces and data/animal_use.json pieces_vocabulary) reused rather than redrawn. (3) The hearth station is the existing fire circle: add huts.hearth's props (stew pot on stones, smoke rack, rendering pot, this people's lamp or candle unlit by day) around it. (4) The kiln: where the people's huts.kiln is non-empty, a clay hump 4–8 m from the hut, downwind of the camp's prevailing wind (wind.json), smoking (smoke.json hearth.look, thin) when a potter is at it. (5) The idles: two new seated work loops from the §CY base pose, soft (sew_with_awl, twist_cord, scrape_hide, plait_basket) and hard (knap, grind_axe, bow_drill, hollow_bowl_with_coal), each with its own small motion and its own sound from sim.workshop.benches[].sounds (audio.json rows, short loops, quiet, inside §BG's falloff); a folk at a bench plays only that bench's loops; a folk crosses benches at most cross_bench_per_day_max times a day and never does both at once; the maker sits at a bench maker_bench_share of the gather hours. (6) Day heart / night heart: during loop.gather_hours the non-gathering adults sit at the benches or the porch and the fire circle is nearly empty; at dusk_form everyone comes to the fire (§CY unchanged). (7) The player: bring_material_for_maker (sim.player_nudges) now lands on the bench that works it per sim.workshop.player_brings_to_bench: drop it on the soft or hard bench and it joins that bench's props. (8) porch_sign: one mesh or card from huts.porch_sign at the door, big enough to read at 40 m (§BU silhouette distance).

CHECK (tools/workshop_check.gd, headless): on seed 7731 every camp at or past storage has exactly one workshop with a soft and a hard bench and a door; no camp below storage has one; a marsh camp's porch_sign is the reed-mat press and a tundra camp's is the burning stone lamp; a folk at a bench plays only that bench's idles; no folk is counted at two benches in one tick; the maker's bench time over a game day is within 0.1 of maker_bench_share; during gather hours the fire circle holds only the keeper and the children; the kiln appears only where huts.kiln is non-empty and sits downwind within 30° of the mean wind; triangle budget of a workshop with props ≤ a §CY fire circle with its seats ×2. Walkabout once: the opening river camp from the road at midday (the workshop beside the fire, folk at the benches).
```

## 39 — What a camp needs, and the trades that follow — §EI

**Status:** todo
**Mike sees:** A folk carrying a pot to the river and back, the pot sitting by the hearth. As a camp grows, its benches fill in a real order: cord and baskets first, then a kiln and pots, then hides, then a loom, then the lamp-maker; a camp never shows a craft its land cannot feed, and never more than three.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EI of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.needs and sim.trades, and nothing else from that session. It sits on prompt 38 (the workshop and its benches); if that is not built, stop and tell Mike. No screenshots after every step: check with a headless tools/trades_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the needs and trades clauses of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EI (all), §BM (the four fundamentals and the ladder; sim.ladder, sim.ladder_gates), §BL (the store, the restraint rule), §BV–§BW (a trip is a piece), §EL (which bench each trade lives on), each people file's huts.trades (the trades that life can reach) and materials.gives.

BUILD: (1) sim.needs: a WATER job in sim.jobs.kinds (reuse gather): a folk walks to the camp's water (spring, river, lake or well within needs.water.reach_m: the nearest real water the planet has; a well only at a village) carrying a pot, pauses, walks back, and the pot lands by the hearth as the piece water_pot_by_hearth (store.pieces vocabulary: add the row); trips_per_day trips, counted by the camp's folk count; no store number changes (water is never short; this is the fundamental made visible). A shelter mend: every needs.shelter.mend_job_days a folk carries one piece of the shelter's own material (from the people file's shelter.materials) to a hut and it goes on the roof or wall: one visible patch. (2) sim.trades: for each row in trades.order, a trade is PRESENT at a camp when the camp is at or past the row's rung, every "needs" holds (fibre_or_bark_in_reach, clay_in_reach, timber_in_reach, flint_obsidian_or_fine_stone_in_reach: from the biome's plants and the landform's rock within loop.gather_reach_m; hunt_or_herd: the camp hunts (prompt 40) or its fundamental is herd; fibre_crop_or_wool_herd: a fibre crop in the store or a herd; fat_or_oil_or_resin: animal_use fat pieces present, oil plants in reach, or resin conifers in reach), every "after" trade is present, and the trade is in the people's huts.trades. (3) A present trade adds its visible props to its bench (soft / hard / hearth / kiln) from trades.order[].visible, in order; at most trades.show_max trades show at one camp (the earliest in order win); generalist true trades need no maker; generalist false trades appear only once the camp has a maker (sim.specialists.maker), and the maker's bench is that trade's bench. (4) trades.ceiling and trades.never are a guard: nothing in the sim ever creates a market, money, a chief, a wall or a standing hunter; a comment at the top of CampSim says so with §EI.4.

CHECK (tools/trades_check.gd, headless): on seed 7731 every camp's present trades are a subset of its people's huts.trades, in trades.order, never more than show_max; a camp with no clay within reach never shows pottery; textiles never appears before cordage_basketry and leather_hide; a non-generalist trade never appears at a camp with no maker; every camp at or past storage makes at least trips_per_day water trips a game day and the water pot is by its hearth; a shelter patch lands every mend_job_days ± 1. Walkabout once: a river camp at the specialist rung with pottery present (the kiln smoking, jars at the hearth).
```

## 40 — The whole animal: the hunt, the hut, the six things — §EK

**Status:** todo
**Mike sees:** An adult with a spear walks out past the gatherers and comes back carrying a hare over the shoulders, or dragging a deer on a pole. The animal goes in the workshop door and you never see it again. By evening a hide is on the frame, strips are on the smoke rack, a stew is on the fire, bone awls are in a row on the hard bench, a horn cup sits on the bench edge, and a lamp burns that was filled from the fat pot. The log says so, once per species.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EK of docs/design/RECONCILIATION_2026-09-30.md, from data/animal_use.json and camps.json sim.hunt and sim.jobs.kinds.hunt, and nothing else from that session. It sits on prompt 38 (the workshop) and needs the creature spawner's per-region numbers (§BL ecology; CreatureSpawner); if either is missing, stop and tell Mike. No screenshots after every step: check with a headless tools/hunt_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from data/animal_use.json _help and the hunt clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EK (all), §EJ.2 (the hunter never hands out his own kill; no trophy, no head on a pole), §ED.7 (edges touch only flesh and blood; the hunt is the only time a camp folk holds the spear), §BV–§BW (a trip is a piece), §EL (the benches the pieces land on), §BO (the people and biome dress the pieces), data/animal_use.json (classes, parts, pieces_vocabulary, never), camps.json sim.hunt (who, reach_m, beyond_gather_reach, carry by class, to, process_game_h, food_units by class, hunts_per_game_week, log_once_per_species) and sim.jobs.kinds.hunt, data/creatures/*.json for the size class of each species (add a size_class field to the catalogue rows if none exists: large_hoofed, small_hoofed, small_game, bird, fish, marine_mammal, reptile; say so in PROGRESS).

BUILD: (1) The hunt job: hunts_per_game_week times a week, during gather hours, one adult (never the keeper, never a teen) takes the spear (a spear mesh in hand for the walk only), walks out to a point between loop.gather_reach_m and hunt.reach_m where the creature sim's per-region count for a huntable class is above zero, pauses out of sight of the camp (kill_offscreen: nothing is animated; if the player follows and watches, the folk stands over a spot and then lifts the carry), and walks back carrying per hunt.carry: a small animal over the shoulders, a bird in hand, fish on a line, a large animal dragged on a pole (the pole drags; the figure leans). The region's count for that class drops by one (the restraint rule: a camp never hunts a class whose count is at the region's floor). (2) The hut: the carrier walks to the workshop door (sim.hunt.to) and the carcass is removed from the world; no blood, no cutting, no butchering animation ever. A timer runs process_game_h. (3) The after: when it elapses, for the animal's class in animal_use.classes, each part's piece appears on its bench (soft, hard, hearth) as one visible object from pieces_vocabulary, up to things_shown pieces (the hide and the meat always first); the food store gains food_units[class]; meat goes on the camp's food_by_life rack as §BW pieces; fat fills the people's lamp or candle at the hearth, and that night the lamp is lit from the hearth (fire carried, never made). Pieces persist as the store's do (a hide on the frame stays until the camp "uses" it: decay it after a game week into nothing, quietly; bone tools stay). (4) The log: log_once_per_species, the first time each species is brought back to a camp the player is within 120 m of. (5) never: no folk ever carries a head, a skull or an antler rack as a trophy; no piece from any class lands anywhere but a bench or the hearth; nothing from animal_use ever becomes a weapon that touches what lurks in the dark.

CHECK (tools/hunt_check.gd, headless): on seed 7731 over 14 game days at a storage-rung camp with game in reach, hunts land between 2 and 6; every hunt's carrier is an adult who is not the keeper; the carcass is never inside the camera's view at the moment it is removed when the player is at the fire (it is removed at the door, 6–10 m off); no hunt happens where the region count of that class is at its floor; after process_game_h the bench piece count rises by things_shown and the food store by food_units[class]; the lamp is lit that night and not before; a marine_mammal hunt only ever happens at a tundra or coast camp; the log line fires once per species. Walkabout once: a hunter returning to a river camp with a deer on a pole, from the road.
```

## 41 — Food passed round, the night stories, the gift — §EJ

**Status:** todo
**Mike sees:** At dusk a folk takes a piece off the food store, carries it to the fire, and everyone seated gets a bowl; the store is visibly smaller. If you sit in the circle, you are handed a bowl too. At night one folk tells, hands moving, and the others look at the teller instead of the fire. After you have brought a camp a few armfuls, someone walks up and hands you a pot, once.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EJ of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.sharing and sim.fire_circle.idles.night_stories, and nothing else from that session. It sits on §CY (the fire circle, built) and §BV–§BW (pieces); if dusk_form is not built, build it here as §CY wrote it. No screenshots after every step: check with a headless tools/sharing_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the sharing clause and the night_stories clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EJ (all), §BL (restraint is a rule, not a lecture: nothing here is a speech), §CY (dusk_form steps: walk_in_carrying, drop_piece_on_store, sit_down; the bowls and the pipe), §BW (a piece is a real object on the store), §BO (mute, plus a line in the log), §EK (the hunter's kill went to the hut, not to him), §EN (the record-keeper gives the gift when there is one), camps.json sim.sharing (meal_at_dusk_form, piece_off_store_per_meal, store_shrinks_visibly, bowls_to_everyone_seated, player_gets_bowl, player_log_once, private_stores false, hunter_hands_out_own_kill false, no_folk_commands_another, gift_back), sim.fire_circle.idles.night_stories (what, who, hold_s, needs fire_fed, listeners_look_at_teller, max_at_once, weight night 4).

BUILD: (1) The meal: at dusk_form, after the last load is dropped, one adult (never the one who hunted today, §EJ.2) walks to the food store, takes piece_off_store_per_meal visible pieces OFF it (refresh_woodpile's sibling for food: remove the mesh), carries them to the fire, and sits; every seated folk then shows a bowl prop for the eat idle; the sim's food units fall by the meal exactly as before (no accounting change: the piece leaving is the existing per-tick eating made visible once a day). The store must be visibly smaller afterwards (store_shrinks_visibly). (2) The player's bowl: when the player sits in the circle (§CY's spare seat) during the meal, the nearest folk turns and a bowl prop appears in the player's hands for the eat idle's length; the log says player_log_once the first time at each camp; no stat changes. (3) No private stores: assert in CampSim that food and wood belong to one store per camp, never to a folk; no_folk_commands_another: no animation or idle in the game has one folk standing over another; the headman's teach-on-contact (§BN) stays as it is. (4) night_stories: a new §CY idle from the data row: night only, needs the fire fed (store.feed_fire_below_units not breached), max_at_once 1 teller; the teller's hands move and the hood turns to each listener in turn; every other seated folk's notice target becomes the teller for the hold (listeners_look_at_teller), then returns to the fire; the pipe may still pass. A camp whose fire is low has no telling. (5) gift_back: CampSim counts the units the player has put on this camp's store; when it passes after_player_brings_units and once_per_camp has not fired, at the next dusk_form the record-keeper (if the camp has one, §EN) or any adult walks to the player, holds out one gift from gift_back.gifts (an items.json item the camp could make: a pot, a torch, a bowl of stew, a cord hank, a basket), it goes in the inventory, the log says gift_back.log, and the flag is set. Mute throughout.

CHECK (tools/sharing_check.gd, headless): on seed 7731 at a camp with a full food store, the store's visible piece count falls by piece_off_store_per_meal at each dusk_form and by nothing at other times; the food units match the sim before and after (no double-eating); the folk who hunted today never carries the meal; the player seated at the meal gets a bowl and the log line once per camp; night_stories never plays by day, never at a low fire, and never with two tellers; every listener's look target is the teller for the hold; gift_back fires exactly once per camp after after_player_brings_units and never before; grep of CampSim for a per-folk food field returns nothing. Walkabout once: the opening camp at dusk, the meal.
```

## 42 — Third places: the soak, the great tree, the water rock, the porch — §EM

**Status:** todo
**Mike sees:** In the heat of the day folk are not at the fire: two sit under the camp's biggest tree, one has his feet in the river with a line in the water, one leans on the workshop porch with a pipe. Near a hot spring they walk over in the afternoon and sit in it, hoods back, in the steam.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EM of docs/design/RECONCILIATION_2026-09-30.md, from camps.json sim.third_places, and nothing else from that session. It sits on §CY (seats and idles, built) and prompt 38 (the porch seat); if the porch is not built, place the porch seat here. No screenshots after every step: check with a headless tools/third_places_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from the third_places clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EM (all), §CY (seats by biome, the base pose, idles, the pipe, notice), §EG.4 (prospect and refuge: a back to something, a view of something), §EF.6 and §EF.10 (edges to linger on; the one landmark tree), §CV (smoke.json hearth.look: the steam uses it, white and slow), R6 (water the brightest thing), §BP (fishing_line, the technique's idle), 27 Sept §0 (hot springs at plate boundaries; the hot_spring biome), each people file's huts.third_places (which kinds fit this life, plus its own one, written as a phrase: that phrase is a seat of the people's own, placed by CampProps at the named spot if the spot exists at the camp, else skipped), camps.json sim.third_places (kinds: soak hot_spring_m, hours, hoods_back, steam, max_at_once; great_tree_bench; water_rock; hut_porch; idles; prospect_and_refuge; counts_as_rest; gather_hours_unchanged).

BUILD: (1) At every camp, after the fire circle is placed, find the third places that exist: the oldest/largest tree within 60 m (great_tree_bench: a log or flat stone seat at its foot, §CY seat kinds by biome, placed so the sitter's back is to the trunk and the view is the open side, §EG.4); the nearest water edge within 60 m (water_rock: a flat stone at the edge, feet toward the water); a hot spring pool within third_places.kinds.soak.hot_spring_m (soak: seats are the pool's rim stones; folk sit IN the water to the chest); the workshop porch (hut_porch, from prompt 38). Only the kinds in the people's huts.third_places are placed. (2) Who goes: folk who are not on a job and not at a bench go to a third place during the hours its kind names (midday_heat: the middle third of gather hours; afternoon: the last third; day: any) up to max_at_once, instead of standing idle; the fire circle's rest_hours rule is unchanged, and loop.gather_hours is unchanged (gather_hours_unchanged): third places only fill the hours a folk was already idle. counts_as_rest: no sim number moves. (3) The idles: sit, lean_back, look_out, pipe (the §CY pipe reused), from the base pose; at the soak hoods_back: the hood is down (the one time a cloaked figure's hood is down; the head is the rig's plain head, no face detail beyond R9), and steam rises off the pool from smoke.json hearth.look recoloured white, slow, lit by the scene; at the water_rock a folk who knows fishing_line plays the line idle (the pole and line, the §BP technique's own prop). (4) Notice: a folk at a third place notices the player as the circle does (§CY notice), hood only. (5) Prospect and refuge: every placed seat must have a solid thing within 2 m behind it (trunk, rock, wall, bank) and open ground or water in front; if a candidate spot fails, move it round the feature until it passes or skip it.

CHECK (tools/third_places_check.gd, headless): on seed 7731 every camp has at least one third place when its people file lists one and the feature exists; no camp places a kind its people file does not list; every seat passes the back-and-view test; the soak places only within hot_spring_m of a hot_spring biome pool and never more than max_at_once sit in it; during gather hours the count of folk at third places never reduces the count of folk on jobs (jobs first, third places from the remainder); a folk at the soak has the hood down and nowhere else does; the sim's food, wood and population are identical over 3 game days with third places on and off. Walkabout once: a hot-spring camp in the afternoon.
```

## 43 — The library: the camp book moves, the record-keeper, the winter count — §EN

**Status:** todo
**Mike sees:** A small hut, or a lean-to against the ruin wall, with the camp book on a shelf inside and a folk sitting at it with a quill, or walking round the camp looking at the woodpile and the new child before going back to write. On one wall, the tomes and scrolls the camp rescued from the ruins. On the other, a painted hide with one small picture per year, and a cord of knots, one per folk. At a dead camp the hide is still there, and the last picture is black.

```text
Read CLAUDE.md and docs/WORKING_AGREEMENT.md first. This pass builds ONE thing: design §EN of docs/design/RECONCILIATION_2026-09-30.md, from data/camp_books.json (placement_eh, record_keeper, memory) and camps.json sim.library and sim.specialists.record_keeper, and nothing else from that session. It sits on §ED.3 (CampBook, CampBookPanel, built), §DL (tomes.json, TomePanel), §BN (the three faces) and prompt 38 (the workshop, for where the library stands); if the camp book is not built, stop and tell Mike. No screenshots after every step: check with a headless tools/library_check.gd of your own, walkabout once at the end. Prepend a PROGRESS entry, keep docs/HOW_TO_RUN.md true, remove [NOT WIRED YET] from camp_books.json placement_eh and the library clause of camps.json _help.village_economy, pull with rebase before you push, never force. Explain to Mike in plain English at the end what changes on screen and what he can tune.

READ: §EN (all), §ED.3 (the camp book: one per camp, the sim's only readout, the rumour, copy to log: all unchanged, only its place moves), §BN (headman, plantkeeper, maker: the record-keeper is the fourth, at the storage rung), §BQ (the ending stays unnamed: the pictures do not say either), §CN (overrun ruins keep their library), §DL (tomes.json and the tome panel: the tomes on the wall are these), §EJ.4 (the record-keeper gives the gift), §EL (the library stands near the workshop, never inside it), each people file's huts.library (what the library is built as, and what the winter count is painted on), camps.json sim.library (rung, form, holds, tomes_max, winter_count events and dead_camp_last_pictogram, knot_cord colour_by_stage, survives_abandonment, player_reads_tomes_here), camp_books.json record_keeper (writes_after_event_game_h, idles, looks_at, gives_gift) and memory (winter_count_hide pictograms by event, knot_cord).

BUILD: (1) The library: at every camp at or past storage, a small hut or a lean-to from the people's huts.library (CampProps, the camp's own materials, one roof), 4–8 m from the fire and not inside the workshop; at a ruin camp prefer the lean-to against the ruin wall. Move the camp book: CampBook's placement is the library shelf (camp_books.json placement_eh) once the library exists; below storage it stays on the altar by the hearth as built. Reading it is unchanged. (2) The record-keeper: the fourth specialist, appearing at the storage rung with the headman (sim.specialists.record_keeper at_storage); one adult; idles write_at_shelf (seated at the shelf with the quill prop, writes_after_event_game_h after each camp-book event), walk_camp_look_at_things (walks to one of record_keeper.looks_at that exists, stands, hood tips, returns), sit_with_tome; gathers at specialist_gather_rate like the other faces; gives the §EJ.4 gift when prompt 41 is built. (3) The tome wall: up to tomes_max tome/scroll items (items.json tome, scroll; tomes.json) that the camp "rescued": at a camp in or beside a ruin, the ruin's delve tomes (§DL) that the player has NOT taken are shown on the shelf as props, and the player may read them here with the existing TomePanel (player_reads_tomes_here); taking one off the shelf is not possible (they are the camp's). (4) The winter-count hide: a hide (or the people's surface from huts.library: bark, reed mat, plaster, stone slab, clay slab) on the second wall carrying one small pictogram per game year of the camp's life, drawn as pixel glyphs at 16 texels a metre from camp_books.json memory.winter_count_hide.pictograms, spiralling from the centre as real winter counts do; the event for a year is the sim's biggest event that year by sim.library.winter_count.events order (first in the list wins ties); the current year's glyph is added at the year's end (sky/day_cycle.json day-of-year). No text anywhere on it. (5) The knot cord: a cord hung beside the hide with one knot per living folk, coloured by stage from knot_cord.colour_by_stage (undyed, ochre, indigo); re-tied when the population changes. No text. (6) Dead camps: when a camp is abandoned or overrun (§BL abandon, §CN), the library and its hide persist (survives_abandonment) with one more glyph, dead_camp_last_pictogram (a black square), and no further years; the knot cord stays as it was. The camp book persists as built. Nothing names what happened (§BQ).

CHECK (tools/library_check.gd, headless): on seed 7731 every camp at or past storage has a library and a record-keeper, and none below does; the camp book at such a camp is on the library shelf and reading it still copies the rumour to the log; a camp's winter count has exactly (years lived) glyphs and the glyph for a year with a birth and a hunt is the birth; the knot count equals the living folk count and colours match stages after a birth and after an ageing; a camp that goes dark keeps its library with a black last glyph and no new glyphs over the next 2 game years; the tome shelf shows only tomes the player has not taken and the panel opens from it; grep of the glyph atlas for any font glyph returns nothing (no text). Walkabout once: a ruin camp's library in the morning, the record-keeper at the shelf.
```
