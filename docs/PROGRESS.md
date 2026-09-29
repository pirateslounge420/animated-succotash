# PROGRESS.md — running log (newest on top)

Claude Code prepends 3–6 lines every session. The designer signs off phases here.

---

## 2026-09-29 — The clock is a railway pocket watch; footsteps and climbing quieter, with sliders (Mike, from chat)
- **Pocket watch** (design §AQ, from a photo of Mike's own watch): steel case with its knurled crown at 12, white dial, minute track, bold black 1-12 (a 5 x 7 pixel face with two-cell strokes), red 13-24 inside (3 x 5), black skeleton hands, a red seconds hand on a red cap; no brand, no dawn/dusk marks. 80 px across (+ the crown). Every figure drawn cell by cell on the 480-line grid. `data/hud.json` clock: case, numerals, hours_24, minute_track, seconds_hand, colours. Rendered at eight times of day to check (the OpenGL renderer draws the HUD here).
- **Audio sliders** (settings panel, new Audio section): Volume, Footsteps, Climbing, 0-100 %, clicked or dragged (`AudioMix`: Footsteps and Climbing buses sending to Master; settings `audio.master` / `audio.footsteps` / `audio.climbing`). Footsteps and climbing start at 50 % (-6 dB), from play. Branch cracks and whips moved to their own player on the master bus so the footsteps slider doesn't hide them. `tools/audio_mix_check.gd` 0 fails; `tools/hud_pin_check.gd` 0 fails.

## 2026-09-29 — Round any trunk, however it leans (Mike: "the way that a tree leans should matter… clinging and shimmying, they should be able to circumnavigate it regardless of how it twists")
- **Measured:** `climb_lab` now holds D for 15 s on each trunk with the camera still, adding up the turn about the trunk's own axis. Before this change, straight trunks (pine, birch) went round and round, but every leaning trunk stalled at 5–107°. There were three causes:
  - **A/D reached for whatever lay to your right.** On a leaning trunk, the next hold up or down the trunk lies to the side too, so D climbed the trunk or stepped onto a limb. A/D on a trunk now goes round it, about its own axis.
  - **A/D's direction followed the camera every reach,** so round the back of the trunk D turned you back again. Which way round is now set when the key goes down and kept while it's held.
  - **The feet hung straight down from the hands,** so on a leaning trunk the body dangled on its low side wherever the hands went. The feet now hang along the trunk, and the body model tilts to hug it, even from underneath. Only the body tilts, not the camera (`TreeClimb.body_up` / `body_face`; `PlanetPlayer._tilt_to`).
  - Also fixed: on thin wood, the hands' spread and a diagonal's swing, which are lengths of bark turned into angles, put the hands over half a turn apart. Their average then flipped to the far side and the spiral undid itself. Both are capped in angle (`MAX_HALF_APART`, `MAX_SWING`).
- **Result:** D goes round all ten sample trunks, leans up to 57° (about a lap per 2.3 s). W+D spirals 270–380° in 3 s. In game, W+D does 316–325° on a tamarisk, Miombo and pequi.
- **The cling (right click) likewise:**
  - W goes up the trunk's axis (its branch graph), not the planet's up flattened onto the bark;
  - A/D keeps its way round while held;
  - the trunk counts as held from any side but straight below;
  - the top of a leaning trunk no longer counts as the ground;
  - the body tilts along the trunk.

  Result: 670° round a tamarisk and 875° round a Miombo in 6 s. **Not solved:** on a pequi the cling snags on low limbs (their colliders stop the body 1.2 m out) and gets 49°. Climbing on the graph (E) isn't affected. Whether limbs should stop a clinging body is Mike's call (asked).
- `climb_check`: the W+D and cling-round turns are added up as they go (start-to-end read a whole spiral as nothing), and the leap after circling aims out from where you are. The limb step picks the limb on the side you end up on, which on the big tamarisk is one inside its tangle (the sweep still reaches 10 of 11 of the sample tamarisk's limbs).

## 2026-09-29 — Every branch reachable; hiding at a branch's end (Mike: "any branch that branches off should be accessible (not twigs or overly thin sticks)… crouching at the end of a branch which has leaves hides the player… hide and seek")
- **Measured first:** `climb_lab BRANCHES=1` takes every branch off the trunk thick enough to hold (grip radius 4.5 cm, a metre or more of it). From the trunk beside its foot, looking out along it (or the way it leaves the trunk), it holds W and checks that you reach an end of it, where the wood gets too thin.
  - Most of the misses the first versions reported were the test's own mistakes (too short a hold; one "tip" for a branch that forks into several), not the game's.
  - With the old code: 91–100 % per species on ten species.
- **Fixed:** a stem rising almost straight up out of a fork still leans its own way, and now looking that way picks it (a baobab's crown of stems: 14 → 15 of 15). Now 91–100 % everywhere. The one miss is a tamarisk limb inside a tangle of limbs leading the same way, which a lower start reaches.
- **Hiding already works against animals** (FoliageCover, design §AM 2): out 11.5 m along a tamarisk limb and perched in its leaves, animals on the ground round the tree see you 5 % of the time; perched near the trunk, 77 %. It depends on the leaves at that end: a Miombo's umbrella-tip end left you 61 % seen (14 % near its trunk). Animals now look for your real eye height (lower crouched or perched; it was always 1.4 m).
  - **For the designer:** hide-and-seek PvP is a new design line (multiplayer isn't in the spec). The cover model is ready for it: per-species `canopy.gap`, the season's leaf, and the clusters round you. A player-vs-player version would need other players' sight to use `FoliageCover.see_through` the way animals' does.
- **Fixed, cling on a thin trunk (a pequi):** the right-click grab took the first of its fan of rays to hit, and a side ray grazing the trunk's edge gave a face pointing across you. The crawl pressed along it, past the trunk, and let go. It now takes the face met most squarely: crawl 0.0 → 1.5 m in a second, and the leap off works.
- **climb_check's own bugs**, all from leaning trunks: "your side" was measured from the trunk's foot, and "round the trunk" was flattened onto the ground (13° read for a real 40°). It now measures round the trunk's own axis (43° / 64° / 84° on a tamarisk / Miombo / pequi). `SPECIES=` picks the tree, since the nearest tree changes run to run. It now also climbs out to a limb's end, perches, and prints the cover there.
- `play_fixes_check` is noisy on its own: 1–3 different failures run to run (sprint jump, slides, the deer shot), the sprint jump on the unchanged code too. Not from this work; queued.
## 2026-09-29 — A classic 12-hour clock face (Mike, from chat)
- The HUD clock is a classic 12-hour clock now (design §AQ): rim, twelve hour ticks, pixel numerals at 12, 3, 6 and 9, a broad hour hand and a thin minute hand (once a game hour). The 24-hour ring, the dawn/dusk marks and the PM dot are gone. 44 px across (was 30). `Readouts.feed` no longer takes dawn/dusk; `data/hud.json` clock: `numerals` (quarters | none), `minute_marks`, colours.
- Checked by rendering it at eight times of day (the OpenGL renderer draws the HUD fine here) and `tools/hud_pin_check.gd`.

## 2026-09-29 — Aroids live their real lives; genes, crosses and sports for every plant; HUD pins (Mike, from chat)
- **HUD** (`c94d7fc`): one label per readout; normal play shows only pinned parts (the two dials by default); H = the full HUD; Esc frees the mouse and a click on a readout pins it (gold mark, saved at once). `tools/hud_pin_check.gd` 0 fails.
- **Amorphophallus life cycle** (design §AP, `docs/design/AROID_LIFE.md`): all 246 species got a researched `cycle` block (dormancy dry 196 / cold 6 / everwet cycle 43 / evergreen 1; shoot and bud cataphylls and timings; bloom timing, protogyny, heat, scent, pollinator guilds; fruit; tuber; ploidy; hybrids; sports). ~60 wrong regions/origins fixed from the protologues (47 species moved region, 43 of them got that region's bands).
  - `AroidLife` (pure, off the world clock) + `AroidGarden` (the detail ring, stepped a few plants a frame): leaf hidden while the tuber rests, spike, unfurl, bud, spathe opening at its hour, pollen in the male phase, wilting, berries; the smell on the wind (once per bloom); pollinator clouds (14 insect species, `spawn: "bloom"`, body `insects`); real crosses between plants in bloom; berries as samples carrying the cross; the HUD names the stage.
  - Aroids are no longer `deciduous` (the autumn clock): their whole-plant die-back is theirs.
- **Genes and sports for every plant** (`data/sports.json`, `PlantGenetics`): about one plant in 3,000 is a sport (aroids 1,500, cacti 2,000; grasses/mosses none), kinds weighted to what's documented in the genus (217 of 469 genera researched) and species; clonal clumps sport together. Size sports scale the plant (VegetationPlacer.prepare); the code rides in the moss channel (moss + 2 × code) — foliage.gdshader decodes it and draws the colour sports (tetraploid, variegated, golden, green form, dark form, blue); form sports are recorded for the mesh builders. The HUD adds "variegated sport" etc. after the common name (plants and trees).
- **Checks:** `tools/aroid_check.gd` 0 fails (no world); `tools/aroid_world_check.gd` (STAMP=1) 0 fails; `plant_schema_check` now validates `cycle` (0 errors). The foliage and part shaders compile (checked under GL compatibility with the instance uniform stubbed; this container has no Vulkan to render them).
- **Open:** seedlings don't grow (no persistence / flora ledger yet); the `aroid` mesh (painted petiole, dissected blade) is still the umbrella stand-in; form sports aren't drawn; crosses are only seen within the detail ring. With ~2,000 aroids in the ring on the dev planet a full pass takes ~1-2 s at 1.5 ms a frame.

## 2026-09-29 — Far trees as 2D pictures; shadows only near (Mike: "distant things as 2D… should help performance")
- **Far trees are pictures now (impostors).** Past the detail ring, every tree is one camera-facing quad (2 triangles) instead of the ~1.5k-triangle far model. The quad is baked from the real far model: its height, where the crown starts, the mean leaf colour, a 4-band crown outline and the trunk's width (`PlantMeshes._build_impostor`). The foliage shader (material id 6) draws the ragged crown, the trunk under it, the season's colour (autumn turn, bare winter twigs, dead trees just a trunk), the palette pulls and the same fog as the real leaves. The pictures stand upright on each tree's own up, so they don't tip over on the curved planet. `IMPOSTORS=0` in the environment brings the 3D far crowns back for comparison.
  - First pass: facing the camera, the pictures were lit from behind when you looked away from the sun, a dark band against the haze. Now they're lit like a crown's top.
- **Only the nearest ring's plants cast shadows** (`TerrainChunk.plant_shadow`): the hero chunks within 120 m. Shadows reach only 50 m (look `shadow_max_m`), so farther trees never drew one; they just cost the shadow pass.
- **Measured** (full planet, the camp, `perf_bench` on this machine's software GPU, so compare as ratios):
  - Frame 19.4 s → 17.4 s (−10 %).
  - Visible triangles 13.56M → 12.97M.
  - Shadow pass 17.6M → 16.0M triangles, 440 → 404 draws.
  - The rest of both is the detail ring's 3D trees (10–16k triangles each), which have to stay 3D (climbing, collisions, the look up close).
- **Next for frame time** (not done): pictures for the outer part of the detail ring too (it's chunk-sized today, so the split point is ~260 m), or fewer leaf cards on NEAR trees. On a real GPU the big cost is triangle count, which the pictures cut most at render distance 5–8.
- **climb_check** now picks a different tree near the camp from run to run: whichever tree's skeleton a worker finishes first. That surfaced three climbing weak spots that were already in the last commit, not caused by this change:
  - a leaning Athel tamarisk (W looking out along a thin 0.08–0.14 m limb climbs the trunk instead, or hops to a steep neighbouring limb);
  - a Miombo (W+D went only 13° round the trunk; the test wants 15°);
  - a Cerrado pequi (clinging to its thin trunk didn't crawl up).

  The check's "your side of the trunk" is now measured where you hold it, not at a leaning trunk's foot. Queued as the next climbing fix. `climb_lab` has `TRACE=out`.
- `dev_view`: `VISTA_M=` sets the vista camera's height (150 m to look over the canopy).

## 2026-09-29 — The 4,000 km planet had no forests: geography laid out at 400 km again, built 10x
- **Found while testing the render distance:** after the 1/10-Earth lock, seed 42's full planet had no rainforest, deciduous, taiga, grassland or scrub. It was all desert (25 %), tundra, alpine and coast (53 % of land), and the camp spawned in hot desert with no trees (`tech_check` and `climb_check`: "no tree near the camp"). The stamp had lost every forest band too.
- **Cause:** the geography (continent, belt and ridge noise; hotspots; the weather grid; the passes' distances and slopes) is sampled in geographic metres with fixed wavelengths tuned on the 400 km planet. With `GEO_CIRCUMFERENCE_M` at 4,000 km, the same noise drew ten times as many continents a tenth the size: an archipelago with no interiors, so no moisture gradients and no forest.
- **Fix (code):** `PlanetConst.GEO_CIRCUMFERENCE_M` is 400 km again, the layout the geography was tuned on. The 4,000 km planet is built as a 10x sideways scale model of it (`GEO_SCALE` 10), just as the stamp is a 0.1x one. Heights are unchanged, and everything at walking scale is real size.
- **Result** (`biome_scale`, seeds 42 and 7):
  - Every band is back in the old proportions (rainforest 8–11 %, deciduous 12 %, desert 17–23 %, coast 18 %).
  - Regions are 10x wider: the largest are 45–370 km across, and a straight walk stays 10–43 km in one biome.
  - Every band has a region of at least 1,600 km² on both seeds. That covers Mike's "biomes change too fast" and "a continent of every biome" on the full planet (#89); only the grow pass for tiny bands remains, and it isn't needed on these seeds.
- **For the designer:** "landmass at 1/10 Earth" now means continents 10x the old ones, not 10x as many. Per-km feature density (oases, lagoons, rivers) is the old planet's divided by 100 in area, as your note expected. If you wanted more, smaller continents, that's a new noise scale to choose, not this constant.
- **Tools:** `STAMP=1` / `STAMP=0` in the environment overrides `dev.json` (`World`), so the dev checks can run on the stamp while play is on the full planet.

## 2026-09-29 — Render distance setting (Mike: "view distance similar to Minecraft")
- **Settings panel (O / F10) → Display → Render distance, 1–8 chunks** (260 m each; `display.render_chunks`, default 3, the distance the look was tuned at):
  - Click the left half of the row for fewer chunks, the right half for more. The row shows the reach in metres (1: ~400 m, 3: ~920 m, 5: ~1.45 km, 8: ~2.2 km).
  - It changes live: the chunk manager picks it up on its next update (`ChunkManager.render_chunks()`; `RENDER_CHUNKS=` overrides it for tools).
- **The day haze follows it** (`ChunkManager.fog_scale()`), so the ring's edge always fades out: the tuned density at 3 chunks, thinner farther (×0.64 at 5, ×0.54 at 6: you see farther, like Minecraft), thicker nearer (×2.33 at 1). Night, storm and cloud-forest fog add on as before.
  - **Flag for the designer:** above 3 chunks this thins §AG's retro haze ("far hills flat blue-purple by ~300–400 m") on purpose. If the look must hold, the far settings can keep the tuned haze and only help from hilltops.
- **Only the render distance is drawn:** chunks kept one ring past it (so stepping back and forth doesn't reload them) are now hidden, not drawn. That saves draws at every setting.
- **Cost:** each chunk's trees take about 1.5 s of worker time to place, so a bigger ring fills in over time as you arrive (5 chunks: 123 chunks, about 50 s to fill here on 4 slow cores). Walking, only the new edge loads.
- **Fix after the 4,000 km planet (for the designer):**
  - `TerrainChunk.CHUNK_M` was derived from `FULL_CIRCUMFERENCE_M`, so the 1/10-Earth lock made every chunk 2.6 km across instead of 260 m. That meant 81 m ground quads, a render ring 9 km out, and a tree placement grid ten times coarser. On the stamp it meant 4 chunks per face edge.
  - It is now the fixed 260.4 m walking scale; the chunk count follows the planet (3,840 per face edge on the full planet).
  - Streaming cost is unchanged from before the lock, as the note there says: the render check on the full planet draws 49 / 123 / 13 chunks at 3 / 5 / 1.
  - Still following the planet size: `FarShell`'s 96 quads per face edge are now ~10 km each (were ~1 km), so distant mountains are much coarser. Raising it is a cost trade for later.
- `tools/render_distance_check.gd` (new): switches the setting live (3 → 5 → 1 → 3) from the camp. Drawn chunks go 51 / 123 / 9, and the haze follows. 2/0.
## 2026-09-29 — Archetype pass over every plant (Mike: "make each plant more archetypal to what it really looks like")
- Six parallel botanist passes re-checked all 1,224 entries' `leaf`, `canopy`, `bark`, `architecture` and `tint` against the real species (Kew POWO / floras / the genus table in TREE_ARCHITECTURE.md §5), within the locked vocabulary; `plant_schema_check` 0 errors. Every entry now carries a `silhouette` line (PLANT_SCHEMA §4a2): what it looks like from 60 m, the 64 px target.
- Biggest corrections: coconut and nipa palms had grass-blade `strap` leaves → pinnate fronds 4–9 m; all 64 cannabis landraces were on the forking (leeuwenberg) model → monopodial (attims), with distinct broad-leaf (dense conical), narrow-leaf, hemp (unbranched poles) and ruderal forms; 14 Trichocereus were single columns → clumps from the base, two → candelabra trees; Scots pine (taiga, dunes, pine) → flat-topped umbrella crown on a bare orange trunk; cottonwood → excurrent with a high fork; treeline lodgepole → a 2–10 m wind-flagged multi-stem; kauri → opposite leaves, decurrent crown of huge limbs; yellow paloverde bark → green_stem; solitary palms (assai, fishtail, wild date) → corner model; octopus bush → candelabra umbrella; Brugmansia/Datura stems → smooth / green; balsam fir needles → distichous; diamond willow bark → diamond; Sitka spruce → low buttress; black spruce → sparse clubbed spire; cordgrasses → winter die-back.
- Left for the designer: larch/tamarack needle tufts are capped by the schema's `fascicle` ≤ 8 (they're 15–40); forbs carry the engine `shape: "grass"` by convention; the quiver tree has no `architecture` block though its forked trunk is its whole silhouette; duplicate entries across biome files (baobab ×2 in savanna, umbrella thorn in three files) were made consistent, not merged; palm fronds are encoded as `strap` segments per the schema — flag if the engine wants `frond`.

## 2026-09-29 — Real planet on; dapple mode switch (Mike, from chat)
- `data/dev.json` `postage_stamp` is now **false**: play is on the full 4,000 km planet. The stamp settings stay for the dev checks (`postage_stamp: true` brings it back).
- `data/look.json` `dapple.mode`: `stamped` (the §AJ 3 cluster shade map, default) or `disc` (no map: every tree casts the baked feathered crown disc with the shader's sun flecks). Mike: the shade doesn't need to be mapped to exactly where the light comes through the canopy — "the shade goes here with some dappling in it" is enough — so if the stamped map ever costs frame time, flip to `disc` rather than optimising it. Today it's ~52 ms per chunk on the worker, so it's left on.

## 2026-09-29 — Planet size locked at 1/10 Earth in the code (Mike, from chat)
- `PlanetConst.FULL_CIRCUMFERENCE_M` 400 km → **4,000 km**, so landmass, height (`HEIGHT_SCALE` 0.1, unchanged) and time (the 144-min day, unchanged) share the one 1/10 ratio design §I locked on the 27th. The dev postage stamp (`data/dev.json`, 40 km) is untouched and still on; turn it off to play the full planet.
- What changes on the full planet: the 96-cell blueprint's cells are now ~7 km (were ~1 km), so rivers, lake edges and biome borders are decided at 7 km steps and detailed by noise in the chunk; small features (oases, hot springs, lagoons) are sparser per km. Generation cost is the same (fixed cell count); streaming cost is unchanged (view distance, not planet size).
- Follow-ups: the smallest-band grow pass (every seed gets a continent of every biome); check `tools/biome_scale.gd` numbers at the new size; sparse ledger storage for the 100× area (spec D3). Docs updated: DESIGN.md overview, README, WORLD_SYSTEMS_SPEC.

## 2026-09-29 — Mike's play notes: astride in trees, a still cling, the zenith, your own arrows
- **Always astride in a tree** (Mike: "always straddle, no hanging"):
  - The hang pose is gone. On any limb, thick or thin, level or not, you sit astride it; on the trunk and steep wood you hug it as before.
  - A/D on a limb now leans you round it astride, up to about 57° either side (`TreeClimb.ROUND_MAX` 1 radian), with your hands going round with you. It no longer takes you under it.
  - **Contradiction flagged:** Mike asked earlier to go "however you want" round a limb. Leaning astride is how I've squared the two.
  - **S on a limb** always goes back along it toward where it grows from, hand over hand, whichever way you look. By the look it could send you out to a thin tip, where the hands swapped the same two holds for ever.
  - Any reach that would put the hands back on the grip they had two reaches ago now counts as nothing that way, so the ways on (down whatever goes down, back along the limb) take over.
  - `climb_lab` 68/0 and `climb_check` 0 fails. The round-limb tests now expect "leans round, always astride".
- **A still cling** (Mike: "only the cloak in the wind and the head looking round should move"):
  - A new `cling` body pose: tucked, feet braced on the face, hands up on it.
  - The torso no longer turns after the look, the feet don't step when you crawl, and the lean with speed and the stride are off. The head turns with the look (up to `head_max_deg`), and the cloak still simulates.
- **Looking straight up** (Mike: the clouds and sky "come to a convergence"):
  - The painted cloud panorama is wrapped round the sky by compass bearing and height, so at the zenith all its columns met at one point. Both of its layers now fade out between 25° and 50° up (from 50–77°, the streaks between still pointed at the zenith). Overhead belongs to the weather's flat cloud decks (`CloudLayers`), which don't pinch.
  - It was the cloud wrap, not the field of view.
  - `dev_view` gained `PITCH=` (first person, or tipping the vista camera up) to render it. Straight up now shows only the soft weather decks; the painted banks at the horizon are unchanged.
- **Your own arrows can hit you** (Mike):
  - An arrow ignores you only for its first 0.4 s, while it leaves the bow. After that, one coming back down on you hurts like any other hit (by its speed), glances off and drops.
  - `play_fixes` gained a test: one of yours falling from 12 m onto you.

## 2026-09-29 — §AJ + §AL canopy on the skeleton; Mike's play notes (jump, text, HUD)
- **§AJ + §AL canopy** (the tree/plant build, step 3):
  - **No hull at any LOD:** leaves are cluster cards on order-3+ twigs, and each card keeps its mass tile's holes (cut to `canopy.gap`), so sky shows through every card. Near (25 m), cluster cards show the leaf cutout at the leaf's real size. Far: every third cluster at 1.9×, over the order-1/2 lines.
  - **Clusters sized to the see-through test:** the anchors are placed first, then all clusters are scaled together until the share of sky seen looking straight up from under the crown equals the species' `canopy.gap` (a 24×24 raster from below; each cluster passes `gap` of the light and overlaps multiply). By the cluster spheres, a paper birch reads 0.36 against its 0.45 gap (`tools/cover_check.gd`).
  - **Real-tree fixes from the renders** (Mike: "just make it look like the trees do in real life but stylistically"):
    - the twig and anchor budgets were spent from the bottom up and left a spruce's top half bare, so both are now shuffled over the crown, and top whorls always exist, making a spire to the leader;
    - palm fronds arch, older ones more, with leaflets hanging in a V under the rachis.
  - **Wind (§AJ 5, §AL 5):** each twig has its own sway phase, carried on its wood (CUSTOM0.w) and on its clusters (UV2.y), so the gaps open and close with the twig.
  - **Dappled ground shade (§AJ 3):** `CanopyDapple` is new.
    - Each branchy tree's clusters are seen from above and stamped (a 32 px stamp per layout, turned in quarter turns to the tree's yaw, scaled and moved by the lean) into a 512² shade map per chunk (about 0.5 m texels), which the terrain shader samples by UV. The map wobbles a little in the wind.
    - Branchy trees are left out of the old disc bake; other trees keep the disc.
    - Cost: 52 ms per chunk on the worker, against 1,564 ms of plant placement (`tools/chunk_time.gd` now times prepare and shade); 28 of 36 camp chunks have a map.
    - With the shadow map on, the near clusters cast real shadows and the map fills in beyond `leaf_shadow_m`.
  - **Tools:**
    - `species_row`: UP=1 (under the first tree, looking up), PERCH=<creature> (sits it on a limb in the crown), SIDE_M=x (looks at the perch level), ANCHORS=1 (the §AL debug view: a dot at every anchor).
    - `measure_look.py` prints the sky share.
  - Reference still has: shrubs are still hull lumps (not skeleton plants); no baked far impostor (the far mesh is fewer, bigger cards with holes); the rendered dev checks (a) winter row with anchors and (b) birch look-up and perch are rendering now and get their own entry.
- **§AM leaves are cover, not walls** (step 4):
  - **Colliders:** trees already collided only on their wood; there was no crown collider left to remove.
  - **Arrows and the spear** (`FoliageCover.clusters_on`): each leaf cluster on the way takes `combat.foliage_drag` (5 %) of the speed and rustles its tree; wood stops them as before.
  - **Creature sight:** when you're in or under a crown, the clusters round you are looked up (four times a second). Each animal's line of sight to you loses `gap` per cluster it crosses, and that cuts the seeing part of its flight distance; noise still carries.
  - **Height counts:** creatures now add your height above the ground to how far off you are (before, a fox under your tree counted you as 0 m away).
  - **`tools/cover_check.gd` (new) passes 7/0:**
    - a still player on an oak limb inside the crown is seen from the side 13 % of the time and from right below 30 %;
    - an Arctic fox notices a still player at 1.4 m hidden, against 7.5 m in the open;
    - three clusters take 14 % of an arrow's speed.
  - **Wood colliders (§AM 1, 5):**
    - Orders 1–2 get capsules down to 3 cm thick (before, only limbs of 10 cm and up, so an oak had 8; now 116, within the 60 m graph ring).
    - Order-3 twigs of 4 cm and up get their own capsules, only within 30 m (dropped past 35 m). An 18 m oak has none that thick; a 40 m one has 61.
    - Palm fronds get none (`tree_check` 16/0).
  - Reference still has: the in-game dev check (c) with a fox and a thrown spear.
- **Big main branches, perch and duck anywhere, shorter people** (Mike, from play):
  - **Scaffold limbs:** broad crowns (not a single leader, not whorls; oak, beech, maple and the like) now stand on 5–8 big main limbs per stem. They leave the stem at 62–78 % of its thickness, taper to 45 % and are 10 % longer; twigs and leaves fill out from them.
    - Broadleaf trunks are stouter (height over foot diameter 22, was 28).
    - An open oak now has 11 main limbs (was 28), and 45 of its limb handholds are thick and flat enough to straddle (was 0).
    - Palms keep full-size leaflets (the gap fitting shrank them).
  - **Straddling** starts at 8 cm radius (was 15).
  - **Shift in a tree** perches or ducks at any hold: on a limb or branch you sit on top of it; on the trunk or steep wood you tuck in against it, pinned where you are. Your hands are free (bow, spear, pole), the stick takes hold again and Space jumps off. The prompt says "Shift perch" or "Shift duck".
  - **Heights:** the player is 1.35 m (`player_scale` 0.86, was 0.92), and every cloaked figure (the elder, the hunter, camp folk, wanderers, small folk) is 6 % shorter (`body.folk_scale` 0.94). The first-person eye is capped at 0.93 of the body's height (1.26 m). **Flag for the designer:** §AG 7's 1.4 m eye no longer fits the body.
  - `tools/climb_check.gd` (new): up a branchy tree from the foot, duck on the trunk and draw the bow, out onto a limb and perch on top, back down.
  - **Climbing stalled at forks** (`climb_check`, a 26 m miombo: W stopped at the fork 6 m up). The trunk's handholds end there and the stems count as limbs, taken only if you look out along one. Now pushing up on the trunk with nothing that way carries on up whatever climbs most steeply within reach (stem or limb, any side), and steep wood climbs like the trunk.
  - **Legs on the tree, not dangling** (Mike): `PlayerBody.climb_pose`.
    - Trunk or steep wood: knees up, feet braced on the bark, one stepping up every 35 cm of travel.
    - On a limb or perched on top: astride it.
    - Under thin wood: knees drawn up.
    - Ducked against the trunk: the trunk pose.
    - The cloak still covers most of it.
  - **Diagonals** (Mike): on steep wood, W+D (and the other three pairs) reaches up or down and swings round the wood toward that side in the same move.
  - **Go round any limb you can climb** (Mike): on a limb, A/D take you round it: astride on top, hugging its side, hanging under it. You keep that side as you shimmy along; W/S still go along it or across to another limb. Shift sits on top or tucks in against the side. Steep wood and the trunk went round already.
  - **Cling, crawl, leap** (Mike: "cling with right click, move with WASD, release right click to jump toward where you're looking, hold again at the right time to cling to the next surface"):
    - Right click on the ground facing a wall, rock or trunk within 0.9 m grabs on.
    - While clinging, WASD crawls over the face at 1.6 m/s (up, down and round a trunk, following its curve).
    - No slip-down (Mike): a cling holds still when you don't move and lasts as long as you hold right click (`cling_slide_mps` 0; `cling_hold_s` 0 means no limit).
    - Letting go leaps toward the look, as steep as you look (12–80° above level).
    - Pressing right click up to 14 frames before meeting the next face, and holding it, clings there on arrival.
    - The tap wall jump is unchanged.
- **Climbing that works on every tree (Mike: "doesn't always work")**:
  - `tools/climb_lab.gd` (new) drives the climber on the branch graphs of 8 species × 2 layouts (open and forest-grown), offline, in seconds, the camera held still while the stick is, as in play:
    - W from the foot into the crown;
    - S all the way down;
    - W+D from halfway up the trunk;
    - out along a thick limb and round it.
  - It found, and these are fixed (68/0 now):
    - **S stuck on every tree** (from a few metres up to the top): backing off the trunk points "out", so S reached out and round instead of down, or swung a hand round a thin trunk and back for ever. S is now down the wood; "looking out along a limb" needs W or A/D.
    - **W stopped at forks** when the hand that looked higher was on the trunk below the fork (the stem above isn't linked to it). The way on up is now searched from both hands.
    - **Self-pruned stubs were labelled trunk** (a forest Scots pine stopped 1.3 m up, holding a stub). Stubs now get their own limb number.
    - **Grip:** wood you can hold is now 4.5 cm radius, a 9 cm pole (was 6 cm). Forest-grown birch stems and the top few metres of most trunks were out of bounds, and climbs stopped 2–3 m up. Every tree now climbs to within about 3 m of its top.
    - **W+D:** each reach swings about 0.3 m round for its 0.5 m up. Bigger swings overshot the side you steer to and swung back. Round a thin trunk, the sideways part let a hand step down, so W and W+D never step down steep wood (nor S up). Diagonals spiral and don't wander off onto limbs.
    - **S on a limb** with nothing that way (looking across it) goes down whatever goes down, else back along the limb toward where it grows from.
    - **Out at a limb's end,** W no longer takes you back up the trunk above.
  - **Right click at a trunk from the ground** now works:
    - the hop onto the face puts you against it (the ray met it up to 0.9 m off, and the cling lost the face on its first move);
    - crawling up from just off the ground no longer counts as landing, and a cling rides out 8 frames without touching the face (going up a trunk, the flared foot's collider gives way to the narrower one above, and the cling let go 0.3 m up);
    - left alone the cling holds dead still (it slid 0.2 m a second round a trunk).
  - **Tests:**
    - `climb_check` passes 0 fails in the world. Its look-up helper set the yaw instead of the pitch, so the "leap toward the look" test leapt sideways.
    - `play_fixes`: the trunk wall-jump test starts 2.2 m up (with the snappier fall it reached the trunk at the ground), and the fast-fall test holds jump (a tap is only a 0.3 m hop).
    - `play_fixes` is at 1 fail, the air shot at the deer, which is on its known-intermittent list. Now the shot is taken on the ground at full draw, with the crosshair 0.3 m from the deer, and it still missed on the last run. Not chased further.
    - `tech_check` 0 fails, `tree_check` 0 fails. tech_check crashed once on an engine thread error after the wake test; it didn't repeat.
  - **Renders (dev checks):**
    - (a) The winter row with anchor dots shows every anchor on a twig.
    - (b) Birch look-up and side views; a raccoon perches 9.2 m up.
    - (d) Autumn, days 150 / 158 / 166 / 175: the row goes red and orange, dulls, and by 175 has 58 % of its leaves, each tree on its own day. A paper birch alone on day 175 is yellow and nearly bare.
    - The species row re-rendered: the coconut palm has its arching frond crown back, and the oak and beech stand on big main limbs.
    - The HUD shot: the opening controls hint no longer covers the Elder's first line or the bow line.
  - **Waking after a death:** the ruin whose fire you wake at, and its camp, are built before you wake. They came in a ruin a frame, and you could wake with no fire yet (tech_check found it 7.5 km from where you fell).
- **§AI.1 revised: each tree turns on its own clock** (step 5 of the tree build):
  - The foliage shader now runs the `autumn_colour` clock per tree and per cluster. LeafSeason publishes where the year is (days since the spring and autumn transitions) and the stage table as globals.
  - Each deciduous tree is offset by its own seeded day (± `jitter_days`, seeded by its turn and lean, which the floating origin never changes). Its top and outer clusters run up to `cluster_lead_days` ahead, so a tree turns from the outside in.
  - Colour: green → yellow-green (hue drifting toward the autumn colour by `hue_toward_autumn`) → peak → dull (`sat` 0.6, `val` 0.8). Each cluster drops from the dull stage on (24 days at 6 %).
  - Spring: buds (darker and greyer, clusters small) → young pale leaves (brighter, hue shifted toward yellow) → full, over `spring_days`.
  - Gusts still strip on top (the material's `leaf_season`).
  - `litter_check` 23/0: a hillside of 30 trees turns over 4.5 weeks, each tree on its own day, spread over 13 days.
  - Reference still has: the rendered run of days 130–200 (queued) and dev check (d) through one autumn. Falling leaves and litter still follow the mean clock, not each tree's.
- **Jump and gravity (Mike, from play: "jumps way too high and floaty; gravity more consistent and snappier; can't jump as high"):**
  - Rising gravity went from 1.9 to 26 m/s² (falling stays 28), and take-off from 7.6 to 9.7 m/s.
  - A held jump now peaks about 1.8 m up with 0.73 s in the air (it was about 15 m); a sprint jump about 2.3 m; a tap about 0.3 m.
  - `play_fixes_check` now expects a tap hop under 0.6 m and a sprint bound about 7 m out, under 3 m up.
  - **Flag for the designer:** this replaces §J's "long lazy rise, shark-fin arc" (the asymmetry is now slight). §J and the `air` `_help` need the new numbers; I updated `_help`.
- **Legible text (Mike: "make sure the text is actually legible"):**
  - The HUD font is now VT323, a DEC terminal face under the SIL OFL (`assets/fonts/vt323.ttf`, with its license), drawn with no antialiasing or hinting.
  - Every size snaps to its pixel grid (`HudText.px()`: 20 px body, 40 headings; `hud.json text.crisp_px`), so no glyph falls between pixels at 480 lines.
  - The typewriter face at 9–11 px, antialiased and then upscaled, was mush.
  - Inventory rows went from 22 to 24 px, and the settings panel was rebuilt at the new size.
- **HUD you choose:** the settings panel (O / F10) now switches every HUD element: speedometer, clock, health bar, weapon, crosshair dot, names, damage numbers, prompts and subtitles. All are on by default.
- **Orchid names up the trees:** plants other than trees (epiphytes, orchids on limbs) are now named within reach of your body, height included. You read an orchid by climbing up to it, not from the ground under it. Trees keep the along-the-ground reach.
- `dev_view`: SETTINGS=1 opens the panel; LOOK_NAME="binomial|common name" puts a name under the crosshair.
- **Biomes change too fast (Mike): measured, proposal, not changed yet.** `tools/biome_scale.gd` (new) walks straight lines over the land of seeds 42, 7 and 1234.
  - **The dev postage stamp is the cause.** `data/dev.json` generates a 40 km planet (`postage_stamp`, every band squeezed in with `min_cells_per_band` 3), and the game opens in it.
    - There a straight walk leaves a biome after 0.2–0.5 km (2–5 minutes' walk).
    - The largest region of any band is 1–13 km², and no band has a 25 km² region on any seed.
  - **On the full 400 km planet**, a straight walk stays 1–6 km in a biome.
    - The largest regions are 16–40 km across (desert 30–41 km, rainforest 19–28 km, deciduous 17–32 km).
    - Every band has a region of 25 km² or more on seed 1234. On seeds 42 and 7, woodland/shrubland (Mediterranean scrub, sagebrush) is the one exception (largest 21 and 16 km²).
    - Temperate grassland is small everywhere (largest 85–164 km²).
  - The full planet generates in 8 s against the stamp's 4 s.
  - **Proposal (for Mike and the designer):**
    1. Play the full planet: `postage_stamp` false for play, the stamp kept for tests.
    2. For "a continent of every biome on every seed": a check after generation that grows the smallest bands (woodland/shrubland, grassland) toward a region of at least N km², by nudging the climate where the band already is.
  - Not done without a yes: the stamp is the designer's dev setting.
- **For the designer (data; Mike's requests from play, not built):**
  - **Fish and reptiles.** Already in the data: mahi-mahi (dolphinfish, *Coryphaena hippurus*), grouper (*Epinephelus marginatus*), red-bellied piranha (*Pygocentrus nattereri*), electric eel (*Electrophorus electricus*), Nile and saltwater crocodiles (*Crocodylus niloticus*, *C. porosus*). Missing:
    - redfish (red drum, *Sciaenops ocellatus*);
    - alewife (*Alosa pseudoharengus*);
    - a flounder (summer flounder, *Paralichthys dentatus*, or the European *Platichthys flesus*);
    - golden dorado (*Salminus brasiliensis*), the river "dorado", if Mike meant that one rather than mahi-mahi.
    - Fish don't spawn in the world until Phase 7, so these are data only for now.
  - **Sonoran Desert toad** (*Incilius alvarius*; it was *Bufo alvarius*). Mike wants to milk its parotoid glands and smoke the dried secretion, which holds 5-MeO-DMT and bufotenine. That needs a creature entry, an interact action on the toad, an item, and the effect under Phase 10's `player.haze`. Only the entry is data work now.
  - **Orchids: "every orchid, epiphytic and terrestrial, with its fungus".**
    - The live list has 5 (2 ground, 3 epiphyte) and the archive has 60. Kew accepts about 28,000 species, so "every orchid" can't be taken literally. I suggest a set per realm and biome, from the archive up.
    - Each needs a `habit` of epiphytic, lithophytic or terrestrial (the tier already says most of this).
    - Each needs a fungal partner. Correction for Mike: most orchids aren't bound to one unique fungus. They germinate with broad groups: *Tulasnella*, *Ceratobasidium* and *Serendipita* for most green orchids, and *Russula*, *Thelephora* or *Armillaria* for the leafless mycoheterotrophs. So the field is the partner genus or group, or a species where one is known (for example *Tulasnella calospora*).
    - Climbing up to an epiphyte already names it on the HUD (common and scientific); a partner line under it is one more field once the data has it.
  - **PvP ninjas** (Mike): an idea for later, not scheduled.

## 2026-09-29 — §AK trees grown from their architecture block
- **Skeleton** (`TreeArch`, new): 149 tree-tier woody species with an `architecture` block now grow their trunk and branches from it. Cacti, bamboo, lianas, mangroves, knee-roots and shrubs keep their own builders.
  - Model programs:
    - whorls for massart / attims (a spruce has 16);
    - a golden-angle spiral for rauh;
    - sympodial zig-zag with droop for koriba / troll;
    - forks for leeuwenberg / schoute (a baobab is a candelabra of 4–6 stems);
    - a single column with fronds for corner / tomlinson / holttum palms and tree ferns.
  - Leonardo thickness: each fork splits the parent's cross-section (r_parent² = Σ r_child²). Taper follows `taper_exponent`, the foot flares, and `sinuosity` bends the wood.
  - Also from the block: `fork_height_frac`, `branch_angle_deg`, `spacing_m`, `orders` and buttress fins.
  - Dead limbs are grey, bare, and lowest on the tree. Self-pruning species leave stubs below the crown.
- **Open- vs forest-grown:** each species has 6 layouts, 3 open-grown and 3 forest-grown. The placer picks forest-grown when 2 or more hosts stand within 9 m.
  - Forest-grown trees are narrower, taller, crowned higher (`live_crown_ratio`), and carry leaves only on their top and outer face.
  - An open-grown oak's crown starts at 0.26 of its height; in a stand it starts at 0.64.
- **Lean:** downhill (the slope over 60 m) plus the prevailing wind plus a little random, up to `lean_max_deg`.
- **Leaves on twigs:** every cluster anchor lies on an order-3+ twig or a palm frond, on the outer 60 % of it; the inside of the crown is bare branchwork. Clusters are sized so the crown seen from outside is about 1 − `canopy.gap` covered.
- **LOD:**
  - Twigs are 1–2 px dark lines.
  - The far mesh keeps the order-1/2 lines under fewer, bigger clusters, never a cone.
- **Handholds** come from the skeleton (an 18 m oak has 376) and never lie on twigs. Colliders follow the wood.
- **Check:** `tools/tree_check.gd` (new) passes 13/0: anchors on wood (60,061 checked), only on twigs, Leonardo, bare dead limbs, open crown lower than forest crown, pine stubs, spruce whorls, palm fronds, handholds.
- **Dev check (a):** winter, bare, side by side: oak, beech, spruce, Scots pine, coconut palm, baobab (`species_row BARE=1`). Each is recognisable. The bare palm is a column, because its fronds are its leaves.
- The global shader-parameter buffer was raised to 262,144 (per-instance lean and season data ran out).
- Reference still has: canopy cards that are not yet cut out to the gap share per card; ground shade that is still a disc; leaf collision and cover (§AM); the full §AI.1 staged gradient.

## 2026-09-29 — §AH per-species tiles; §AI leaf fall, piles and rot (4 steps)
- **§AH tiles:**
  - `SpeciesDB` reads `atlas_species.json`: all 1,031 species get their leaf / leaf_autumn / leaves / litter / bark / petiole files. 121 mosses, air plants and conks have no bark tile and keep the class bark.
  - `PlantMeshes.material_for(sp)` gives each species its own copy of the foliage material with its tiles. Tiles are read straight from the PNGs, lazily, so only the region's species are resident. The folder is `.gdignore`'d rather than 3,900 imported resources, so an exported build would need it added as raw files.
  - The shader draws them times white and a per-plant genes jitter (warm/cool ±6 %, value ±10 %). There is no genes code yet, so the jitter comes from the instance hash.
  - Bark tiles every 0.4 m. Crowns get the foliage mass over their own shade.
  - Near cards (25 m) show the leaf cutout at the leaf's real size, in leaf cells inside the ragged cluster outline. Clumps and far cards show the mass.
  - Tile values are read raw like every vertex colour here: decoding sRGB halved them.
  - Wind is now a global (`plant_wind`).
- **§AI 1 colour and fall** (`LeafSeason`, at the player's latitude):
  - Colour blends leaf → autumn over the summer → autumn transition, and the mass is recoloured by the same share.
  - Shedding starts at `start_at` and takes `per_day_share` per game-day over `deciduous_days`; crowns are bare in winter and leaf out green over the spring transition.
  - **Revised mid-build by the designer's §AI.1 (fbde19f).** An interim wiring now follows `seasons.autumn_colour`: the colour runs on the 42-day clock from 12 days before the transition, by each stage's `blend`, and the fall starts at the `dull` stage (day 19.5 of the transition, 24 days at 6 %).
  - Not wired yet: the dull stage's sat/val, `hue_toward_autumn`, the ±7-day per-tree jitter, the 8-day cluster lead, and the bud → young → full spring stages.
  - A gust over `gust_mps` drops `gust_share` at once.
  - Crowns thin in leaf-sized cells.
  - Falling leaves are the species' leaf card, spinning and flipping, from the trees within 45 m at the rate their crowns lose leaves. They are drawn at twice the leaf's size to read at 480 lines, and unshaded.
- **§AI 2 piles** (`LitterField`, 4 m cells fixed to the ground):
  - Mass from the crowns: deciduous 0.4 kg/m² of crown over the fall; evergreens 1.0 kg/m² × 0.3 a year.
  - It is laid within crown radius × spread, drifted downwind.
  - Depth → cm → a mound up to 0.25 m. Each cell is drawn with the dominant species' litter tile (a Texture2DArray): ragged edge, scattered when thin.
  - Rustle above 3 cm; sprinting in kicks 15 % of the top layer up as leaves.
- **§AI 3–4 rot:**
  - Stages flow first-order at `days_at_reference` × Q10 (freeze_rate below 0 °C) × moisture curve × leaf multiplier. Dry → wet-dark waits on rain.
  - The shader does the stage colour transform, the holes mask and the height, like the designer's preview.
  - Humus goes into `flora_litter_kg` (per cell `humus_at`). Nothing reads it yet (soil fertility is Phase 7).
  - Litter fungi (`substrate: litter`) fruit on stage 2–3 cells 2–5 days after rain, in season and temperature, for 5 days. They are drawn with their catalogue mesh (a rosette: there is no mushroom shape yet).
- **Checks:** `tools/litter_check.gd` (new) passes 21/0: the crown timeline, Q10/freeze/moisture, multipliers, first-order stages with mass kept, rain → wet-dark, humus. Durations (leaf shape gone / into soil):
  - tropical broadleaf 159 / 323 days;
  - temperate broadleaf 450 / 912 days;
  - boreal needles 3,590 / 7,287 days.
  - `tools/species_row.gd` (new) shows oak, maple, Scots pine and coconut palm side by side through the year. Options: RUN, DAYS, TOP, WIND, DIST, FRAMES, NO_TILES.
- **Play checks after these steps:** strike passes. tech_check crashed once with engine-internal `rb_set` errors right after its respawn teleport. It then passed 23/0 on this code, and 23/0 on the commit before §AH, so it's intermittent. It's not reproduced, so a race in the new per-species materials during a burst of new chunks isn't ruled out; watch for it.
- **Dev run** (`species_row RUN=145,330`, a temperate year, rain every 9 days):
  - green on day 150; turning on 160; 90 % shed by 170; bare by 180;
  - piles 1.4 cm deep at most (four trees 11 m apart), rotting through dry (stage 1.4 by day 212) to wet-dark (2.2 by day 330);
  - buds on day 330.
- **Flags for the designer:**
  - Tropical broadleaf loses its leaf shape in about 5 months with these `days_at_reference`; §AI 4 says weeks.
  - Morel is tagged `fruit_season: autumn`, but it fruits in spring.
  - Litter fungi are drawn with their catalogue shape (rosette).
- **Reference still has:** real mushroom forms, and litter that hides what's under it (snags, burrows: the kick doesn't expose anything yet).

---

## 2026-09-29 — §AG: the look tuned to the reference clips (steps 1–7; shadows A/B not locked)
- **1 Dither and bleed** (`post_grade`): a hard ordered dither at `retro.dither` 1.0 onto a true 5-bit grid per channel (`bits_per_channel`), bleed 0.2, grain 0.025, all at the 480-line internal frame. The header comment is fixed.
- **2 Fog** (`SkySystem`, `look.gdshaderinc`): day density `retro.fog.day_density` 0.0035, so far hills are ~65 % haze at 300 m and ~75 % at 400 m. The fog colour stays the horizon colour. Valley fog adds `height_density` below the local ground mean: `main` samples the eye and a 250 m ring every 0.5 s and sends `look_ground_m`. dev_view `VISTA=1` gives a far view.
- **3 Tiles:**
  - `Look.texture()` hands out the `assets/textures/retro` tiles (64 px, stone 128, leaves and leaf card 32). Weave and fur are still painted.
  - Terrain, foliage, ruin and model samplers are `filter_nearest_mipmap` with no anisotropy, read through `retro_tex()`, which caps the mip at `retro.max_mips` (2).
  - Repeats come from `retro.tile_m` (the `look_tile_m`/`look_tile_m2` globals).
  - The terrain's rotated second copy is gone and its far fade dropped from 0.55 to 0.2. The ground now sparkles with texels.
  - Leaf-cluster cards use the 32 px noisy cutout, mirrored and turned per cluster.
- **4 Colours:**
  - The sky is a three-stop gradient from `retro.colors` (#0810B8 / #3560D0 / #7A90E0, no white band).
  - Around sunset the whole sky takes `sunset_bands`. Night keeps §C's ultramarine.
  - The sun is an 8° soft disc (`sun_disc_deg`) with a radial falloff, #FBF486 low down. There's no bloom.
  - Water is #04087A.
  - Palette: grass darker (lit grass measures #3A6832 against the #3F6E2C target), a canopy target for crowns, olive path dirt; bark keeps the old brown.
  - The grade gets a shadow floor at `shadow_floor` #080C4A.
  - dev_view gains `SPAWN`, `SUNWARD` and `CLOUD`.
- **5 Clouds:**
  - `cloud_pano` 512×128 is drawn nearest, in two layers: far 2.2× smaller, low and hazier, 1 turn / 40 min; near 1 turn / 12 min.
  - The greyscale tile is tinted by the sky, taking the sunset bands at sunset. SkyPaint only bakes clouds when the tile is missing.
- **6 Shadows A/B (not locked):** `SkySystem.day_shadows()`: the "Sun shadows by day" setting, or DAY_SHADOWS=0/1 for tools. It defaults to look "light" shadows (on), so today's look stands until the designer picks.
  - B turns the sun's shadow map off, switches on blob shadows (`BlobShadow.set_enabled`) and darkens ground under canopy by `canopy_dark` 0.45. The top-down canopy mask in ground vertex alpha is now feathered over `canopy_feather_m` 3 m. The terrain grid is ~8 m, so vertex interpolation softens it further.
  - `perf_bench`, dev frame at 15:00, 480 lines, on llvmpipe (compare ratios): **A 2279 ms a frame** (the shadow pass ≈ 384 ms: 261 draws, 1.07M tris). **B 1833 ms, −20 %**; the shadow pass is gone and the blobs cost nothing measurable. On a GPU that's ~1.24× A's fps.
  - Forest camp mean luma: A 0.13, B 0.28 (reference 0.18–0.32).
- **7 Camera:** FOV `retro.fov_deg` 78 (aiming zooms to the same share, 67). First-person eye at `retro.eye_m` 1.4 m, crouched eye scaled to match.
- **Checks:**
  - `biome_species_check.py` HARD 0 (SOFT 131); `plant_schema_check.py` 0 errors.
  - daylight, soil, strike, super, inventory and tech pass; hits keeps its known failure.
  - play_fixes varied 10 → 3 fails across two runs on this code, and 0 with the step-7 player file reverted. That spread is its known intermittency: the eye and FOV only move the camera, and the 3-fail run hit only its usual slides and bound.
- **Reference still has:** sprawling bright meadows and paths flanked by trees (world-gen, §AG 7, Phase 9); its clouds are whiter and softer-edged than our lavender-tinted posterised tile; our camp clearings are sand, so the frame averages brighter (0.37–0.45 luma at the dev spot vs 0.18–0.32).

---

## 2026-09-28 — Step 6.5: realm gate and direct catalogue loading (design §AA)
- **Direct loading:** `SpeciesDB` reads `data/plants/*.json` after the biome files.
  - 427 catalogue species are new, giving 1031 in all.
  - A catalogue entry whose name is already a biome plant (72 old copies) only tags that plant with its realm. The copy's bands and needs stand until the designer removes the copies (§AA 1). Letting the catalogue widen them moved 31 existing plants, the camp's trees among them.
  - Catalogue `family_defaults.needs` apply to every entry in the file.
  - The catalogue README's "read directly from Phase 6" is now true.
- **The realm gate:**
  - Each biome file's association realms are read (`SpeciesDB.realms_of_biome`, `biome_hosts`).
  - A realm-tagged species grows only where the site's own realm is one of its realms **and** the site's biome has an association for that realm (or an `any` one). That is checked per site in `VegetationPlacer.weight`, with a chunk-level prefilter at the chunk's middle.
  - Catalogue entries with no `realm` yet (the 171 outside Amorphophallus, Cannabis and Trichocereus) don't grow until they're tagged. Their old biome copies keep growing as their biome files say, so nothing already in the world disappears.
- **Where the realms are (`RealmMap`; engine-side, for the designer to confirm):** the design gives no realm map for this noise-continent world, so I proposed one.
  - 9 continent-scale provinces, a warped Voronoi on the sphere. Each is one "world": New World ×2, Afro-Europe ×2, Asia ×3, Malesia–Australasia, Oceania, dealt in a seeded order.
  - Within its world, a place's realm follows its own climate and height:
    - **New World:** high (≥ 1500 m real) and tropical or southern is andes; warm or southern is neotropic; otherwise nearctic.
    - **Asia:** ≥ 2000 m is himalaya; ≥ 21 °C indomalaya; humid subtropics sino_subtropical; dry central_asia or west_asia; humid temperate east_asia_temperate; otherwise palearctic.
    - **Afro-Europe:** afrotropic (patches of madagascar in the south), west_asia, mediterranean, palearctic.
    - **Malesia–Australasia:** hot and wet is malesia, otherwise australasia.
  - Below 60° S everything is antarctic.
- **Needs:**
  - `dry_ground` is now enforced: never in a wetland biome (swamp, marshes, bog, fen, wet meadow, mangrove, estuary) nor within 8 m of water.
  - New `forest_floor`: only in a forest biome. Amorphophallus carries it through a one-line `family_defaults.needs` in `amorphophallus.json`, for the designer to confirm (§AA 4: "forest floor and gaps"). Without it, the 246 species' own bands let them into riverside desert, beach and hot-spring sites.
- **A local assemblage:** a chunk holds at most 4 species of one catalogue genus, the ones with the highest local dominance. One valley has its own handful of Amorphophallus and the next a different handful, and each site weighs a bounded list.
- **Cost:** plant placement (worker threads, 36 chunks averaged) +7 % in an Asian tropical forest (1319 → 1415 ms a chunk) and +15 % round the camp (1619 → 1862 ms), measured before the untagged entries were gated out. `tools/chunk_time.gd`; `NO_CATALOGUES=1` compares.
- **Verification** (`tools/realm_check.gd`, new): 775 chunks computed exactly as in play, stratified over 288 (biome, realm) groups; every catalogue plant tallied by its own spot. 0 violations.
  - **Amorphophallus:** 2516 placed, all on forest floors. By realm: indomalaya and malesia rainforest, jungle and dry forest, ground tier (plus 40 shrub-tier). None in the afrotropic sample.
  - **Cannabis:** 2506 placed, each landrace in its own realm on dry ground. Hindu Kush, Pamir and Chitral in Central Asian steppe and cold desert; Kashmir in Himalayan meadow; Acapulco Gold and Sinaloan in neotropic dry forest and savanna; Kerala in indomalayan jungle; the Russian hemps in palearctic taiga.
  - **Trichocereus:** 0. Its bands (8–21 °C, moisture 0.15–0.6, to 3400 m) fit no biome with an `andes` association: puna and páramo are −3–5 °C, cloud forest is wet, and cold desert and canyon (where §AA puts it) have only nearctic and central_asia associations. **Data to add: an `andes` association in cold desert, canyon or thorn scrub (Andean dry valleys).**
  - The tool prints the count of catalogue species placed per biome.
- **Checks:**
  - `biome_species_check.py` HARD 0 (SOFT 127, unchanged); `plant_schema_check.py` 0 errors; realm_check, super, strike, inventory, daylight and soil pass; hits keeps its known failure.
  - **tech_check:** its trunk picker now skips trunks that fork below 4 m or have anything in the approach or under the cling spot. A cling slides down onto a low fork and, rightly, ends there. That happened on a thin acacia once one extra shrub candidate reshuffled the camp's shrubs. It now passes.
  - **play_fixes:** varies run to run: 1 failure one run, 4 the next, from its known-intermittent list (slides, sprint jump, deer shot, bound in the open). The designer's new biome data alone gave 1 (the tree-patch walk). Its bound check now looks for a clear arc from the actual take-off point.

---

## 2026-09-28 — Step 5.5: performance pass (design §W)
- **Measured, not guessed:**
  - F2 (dev mode) shows a frame-time line: frame ms and fps, the root viewport's cpu and gpu render ms, and the shadow pass (`PerfReadout`). Godot 4.3 gives scripts no per-pass GPU timing, so the shadow pass's ms is sampled by switching the sun's shadows off for a few frames every 4 s; its draw calls and triangles come straight from the renderer.
  - `tools/perf_bench.gd` times the fixed dev frame with shadows on and off.
- **The numbers:** this container's GPU is a software rasterizer, so the ms are huge. Read them as ratios; the geometry counts don't depend on the GPU. Dev frame at 480 lines, 15:00:

  | step | frame ms | shadow pass | shadow draws / tris | visible draws / tris |
  |---|---|---|---|---|
  | baseline (after 5.4) | 3645 | 1203 ms | 633 / 2.67M | 723 / 2.34M |
  | (1) shadows | 2939 | 568 ms | 292 / 1.22M | 717 / 2.34M |
  | (2) plant ranges | 2520 | 417 ms | 288 / 1.22M | 700 / 2.13M |
  | final | 2551 | 474 ms | 292 / 1.22M | 699 / 2.12M |

  That's −30 % frame and −61 % shadow pass. At 1080 internal (what §Y replaced), 60 frames didn't finish in 15 minutes here, so the internal size was the biggest cost of all.
- **(1) Shadows** (`look.json` light):
  - 2 cascades instead of 4 (`shadow_splits`), `shadow_max_m` 90 → 50, shadow map 4096 → 2048.
  - Leaves can stop casting beyond `leaf_shadow_m` of the eye: in the shadow pass the foliage shader collapses them in the vertex stage, so they cost no raster.
  - Tried at the design's 15 m, it saved only another ~114 ms of 568 and visibly flattened the midground: crowns stopped shading each other and the trunks. It is left at 50 m, the whole shadow range, so the look is unchanged. The knob is there.
- **(2) Plants** (`look.json` "ranges", new):
  - Grasses, tussocks and reeds to 40 m; other ground cover and epiphytes to 80 m (was 300); shrubs to 150 m (had no limit, so they drew out to about 390 m).
  - A triangle census showed ground cover was 1.38M of the 3.3M triangles around the camp.
  - One undergrowth MultiMesh spans a 260 m chunk, so a node visibility range can't do this. Each plant is shrunk away by its own distance from the eye in the foliage shader (`draw_range_m` instance uniform, over the last tenth), and the node itself only culls once nothing in it can be in range.
  - Tree crowns and cards wait for Step 7 (leaf cards with the ragged impostor beyond).
- **(3) Creatures:** rigs animate only within `ranges.rig_m` (60 m); farther ones still travel but hold their pose. Posing the camp's 69 creatures dropped from 0.82 to 0.59 ms a frame. That is on top of the existing think-less-often stride for far animals.
- **(4) Render scale:** superseded by 5.4's fixed 480 lines.
- **HUD:**
  - The crosshair comes from `hud.json` reticle: arms of `size_px`/2 from `gap_px` out, `thickness_px` wide, in `color` with a dark ink edge. That is larger than before.
  - Plant and tree names (and so E samples) only show within `plant_name.reach_m` (1.2 m) of you, measured along the ground. Animals are still named to 40 m.
- **Checks:**
  - tech, super, strike, inventory (with a new name-reach line), daylight and soil pass; hits keeps its known folk-head failure.
  - play_fixes passes except the intermittent "E with nothing in reach lets go" (Step 8 retires E climbing). Its sprint-slide check is also intermittent: 0.79–1.93 m on runs of the same code, depending on where its open-ground search lands. It failed once here and passed on the re-run.
- **Not verified here:** the locked 60 fps target (design §W, updated during this step to be at the 480-line render). This container has no real GPU; the designer's F2 readout will tell.
- **Reference still has:** ragged leaf-card canopies against the sky (Step 7).

---

## 2026-09-28 — Step 5.4: 480p internal render (design §Y)
- **Fixed internal frame:**
  - The root window uses the "viewport" content scale (`scripts/core/display.gd`, from `data/look.json` "render"). The whole frame is drawn at 854×480 and upscaled to the window nearest-neighbour: the 3D, the post-grade with its grain and Bayer dither, and the HUD.
  - It replaces `scaling_3d/scale` 0.8, which has been removed from project.godot. Checked on screen: fractional upscales are hard-edged too, not filtered.
- **Integer scaling** (on by default) uses whole multiples when the window holds at least two. A 1080p screen shows exactly 2× (1708×960) with a thin black border; with it off, 2.25× fills the screen.
- **Settings** (O / F10): internal lines 480 or 720 (720 is the file's max), aspect 16:9 or 4:3 (640×480, letterboxed), and integer scaling on or off. They apply at once and are saved in `user://settings.cfg`.
- **HUD at the 480 reference:**
  - `hud.json` and combat `feedback` px are used as they are.
  - The default label size is `text.base_px` (9).
  - hud.gd and status_hud.gd constants were converted from the 720 base (×⅔, rounded).
  - The key hint was reflowed to fit 854 px.
  - The inventory screen keeps its layout numbers and is drawn through a ⅔ transform, with clicks mapped back.
  - The settings panel was redrawn at 480, and the map and collision legends were resized.
  - Window-height text scaling is gone: the upscale does it.
- **dev_view:** `SCREEN=1` also saves the window as shown on screen (the upscaled frame). `INTEGER=0` gives a fractional run. Under xvfb, fullscreen is taken as a 1920×1080 window at the screen origin, because there's no window manager to switch modes.
- **Reference still has:** ragged leaf-card canopies against the sky. At 480 lines the smooth blob crowns read even more as solid shapes (Step 7).

---

## 2026-09-28 — Session 3, Step 6: momentum and HUD (design §J, §K, §L, §R)
- **6a, HUD readouts** (`data/hud.json`; `scripts/ui/readouts.gd`):
  - A speedometer at the bottom right shows mph and km/h (m/s too in dev mode). It is faint below 6 m/s and brightens toward 33.3 m/s. Its glow goes from cold blue to warm gold as the super meter fills.
  - A watch-face clock at the top right has a 12-hour hand, a minute hand and a 24-hour outer ring. Two gold marks sit at today's dawn and dusk here (DayCycle, from latitude and season).
  - Both are on by default. O or F10 opens a small settings panel with a switch for each, saved to `user://settings.cfg`.
  - All text uses the typewriter font (`assets/fonts/typewriter.ttf`, Special Elite, Apache 2.0) and scales with the window height (project stretch mode, base 1280×720).
- **6b, asymmetric gravity** (`movement.air`):
  - The pull is 1.9 m/s² while rising and 28 m/s² while falling. The rising value was tuned from the design's 2.8 so a held sprint bound lands about 50 m out.
  - Measured: **50.2–50.7 m out, 19 m up, 5.7 s** in the air. A tap is cut by `jump_release_cut` to a hop of about 1.97 m, and the fall from it takes 0.37 s: a shark fin, not a float.
- **6c, no air steering; the body turns freely; redirect** (`movement.redirect`):
  - In the air your velocity is fixed. The body faces the look, so you can moonwalk.
  - Every contact sends the kept speed toward the look: landings, rolls, bounces, wall kicks and swing releases.
  - The share kept follows `keep_by_angle`, times `perfect_gain` for a perfect tech or `miss_scale` for a missed roll, capped at `sanity_mps`.
- **6d, branch bounce** (`movement.bounce`):
  - After a fall of at least 1 m onto anything you can stand on, press right click within 14 frames either side of touchdown. The fall speed turns into forward speed toward the look (carry 0.8, gain 1.05), and you bound again.
  - A bounce is a chain link, a super-meter perfect, and it plants the other foot.
  - Fall damage now counts only the drop below where you took off, so your own rise doesn't hurt. The bounce itself uses the whole fall.
  - A right click already spent on a wall jump, cling or catch no longer also counts as a bounce.
- **6e, alternating feet** (`movement.bounds`): every landing, bounce and wall kick plants the other foot. The torso and cloak hem lean with it (`PlayerBody.plant()`), and the camera never bobs.
- **6f, momentum in combat** (`combat.strike`, `overcharge.spear`):
  - Arrows and a thrown spear inherit your full velocity (this was already the case).
  - A spear thrust adds `(closing − 6) × 8` damage, and at 25 m/s closing it kills anything but a mythic (`Hits.strike_bonus`, `strike_kills`, `mythic`).
  - A thrust into a trunk, wall or rock at speed is an impact on you (`PlanetPlayer.thrust_impact`).
  - A super-thrown spear kills on impact (`impact_kill`) and pins what it's in: `Creature.pinned_t` holds it in place for as long as the shaft is in it.
- **Tags:** `[NOT WIRED YET]` is removed from `movement` air, redirect, bounce, bounds and super_meter, and from `combat` strike. The overcharge tag now covers only fishing; fishing is still unwired.
- **Checks:**
  - New `tools/strike_check.gd`: 6/6 pass.
  - tech_check passes. Its late-press case now waits in the air clear of the tree: on the light up-gravity you would otherwise still be rubbing the trunk, and on the ground the press is a legitimate bounce.
  - play_fixes_check has these changes:
    - new sprint-bound, bounce, foot and no-self-fall-damage checks;
    - the hop check updated to about 1.9 m;
    - "drawing slows you" became "drawing never slows you" (§N);
    - the deer shot now waits for you to land and stop, since the kick carries about 47 m.
  - super_check passes 12/12.
  - Last solo run of play_fixes_check: all pass except the intermittent "E with nothing in reach lets go". It leaves you on the tree, so the tree-patch walk after it covers 0 m. Step 8 takes E out of climbing anyway.
  - hits_check still has its known folk-head failure.
  - inventory_check's laden walk failed once (you were off the floor) and passed on the re-run.
  - daylight_check, soil_check and plant_schema_check pass.
- **Design §Y** (pushed during this step): a 480-line internal render, with HUD px sizes now given at 480. It isn't built yet, so the readouts draw at the new smaller px against the 720 base, about ⅔ size, until §Y lands.
- **Reference still has:** ragged leaf-card canopies against the sky; ours are still smooth blobs (Step 7).

---

## 2026-09-28 — Cloak colors for every other camp; the super meter and overcharge (design §S)
- **Cloaks:**
  - Every cloaked figure outside the opening camp rolls its cloak at random from `data/cloaks.json`: red, orange, yellow, green, blue, indigo, violet, magenta, pink, black, white, grey.
  - Its fringe (hem and trim) is another random color from the same list, never the cloak's own, and never the player's indigo-with-orange.
  - Seeded per camp, so a camp keeps its people.
  - The opening pair stays the designer's pick: the elder ochre yellow, the hunter madder red.
- **Super meter** (`scripts/player/super_meter.gd`; numbers in `data/movement.json` "super_meter"):
  - Perfect techs fill it: a tap wall jump in its window, a landing roll, letting go of a swing. Each perfect in the series adds more (0.04, then +0.01 per earlier link).
  - A missed or late tech ends the series; the meter keeps its fill. That covers a press after the window, a cling instead of the tap, a heavy landing without the roll, a snapped branch or an impact.
  - Landed hits on creatures add 0.06, a critical 0.12.
  - It never decays; dying empties it.
- **Overcharge** (`data/combat.json` "overcharge"):
  - With any meter, holding the bow or spear past full charge keeps charging for extra time (bow 1.2 s, spear 1.0 s).
  - Released then, it's a super shot, and the meter empties: a critical hit, ×3 damage, ×1.3 speed, falling ×1.5 less, and a red streak. The arrow also pierces the first body.
  - Released earlier, it's a normal full shot and the meter is kept.
  - The drawn arrow's tip glints red and the bow creaks when overcharged.
- **HUD:** a thin gold ring round the charge gauge shows the meter (only when it's above 2 %); the gauge fills again in red through the overcharge (`data/hud.json`).
- **Not yet:**
  - the spear's pin and impact-kill, and the fishing pole's overcharge (the pole isn't built);
  - the speedometer glow (no speedometer yet);
  - NPC shinobi meters;
  - the bounce and hop-landing perfects (those techs aren't built).
- **Checks:**
  - `tools/super_check.gd`: 12/12 pass (fill, chain bonus, cling break, early release keeps meter, super arrow with pierce/fall/red streak, no meter means no overcharge, super spear, hit and critical fill, death reset).
  - tech_check passes.
  - play_fixes_check and hits_check fail only their known, earlier failures.

---

## 2026-09-28 — Session 2, Step 5: soil as a hard spawn gate (addendum §G2)
- **Readable soil:**
  - Each point's soil class comes from the geology pass (granite, basalt, karst, sandstone, alluvium, sand, clay/peat, till: the schema's names).
  - Read it with `PlanetData.soil_at()`, which jitters the cell lookup by 0.6 of a cell (`data/soil.json`) so borders wander instead of following the grid.
  - `PlanetData.soil_name()` gives the name. The HUD shows it next to the biome, and F3 shows it too.
- **The gate:**
  - `PlantSpecies.suitability()` now checks temperature, moisture and soil class first, as co-equal gates. Outside any of them the species is 0 and never spawns. Then come the weights: the two climate bands, the soil preference within its classes, and altitude.
  - Placement reads the soil at each candidate point.
- **Species data:**
  - Existing entries name a soil preset; `data/soil.json` maps each preset to its allowed classes. For example, rich forest no longer grows on beach sand or peat bog, and sand plants grow only on sand and sandstone.
  - The schema's `"soil": {"classes": [...]}` form is read too, ready for the data fill.
  - All 640 species allow at least one class.
- **Measured** (`tools/soil_check.gd`):
  - The stamp's cells are 60 % basalt (the sea floor counts), 10 % sand, 8 % granite, 8 % alluvium, 7 % till, 5 % sandstone, 2 % karst, 0.4 % clay/peat.
  - Around the first camp, 2,369 trees are placed and none stands on a soil its species doesn't allow. Without the gate there were 2,447, so about 3 % are gone, mostly on granite.
- **No depth, fertility, drainage, pH or salinity yet** (as asked).
- **Tests:**
  - Two test fixtures relied on where trees stood, which the gate moved:
    - tech_check's catch test now picks a branch with a clear approach;
    - play_fixes_check's "E with nothing in reach lets go" now holds the look target empty (E rightly samples a plant in reach first).
  - tech_check, inventory_check and stamp_check pass.
  - play_fixes_check fails only the 2 checks from the other session's data commit (see Step 3).
- **Reference still has:** ground that shows its soil (sand, peat, scree, karst pavement read at a glance). Ours colors the ground by biome, not by soil class.

---

## 2026-09-28 — Session 2, Step 4: head-look (addendum §B)
- **One rig for everyone** (`PlayerBody`, numbers in `data/look.json` "head_look"):
  - Small turns of the look move the hood first, and the shoulders shift a fifth of that with it.
  - Past 45° the torso follows, up to 50° more.
  - Pitch tilts the hood alone within ±30°.
  - The hood catches up quickly (9/s) and the torso lags (4/s).
- **The player:** third person only. The hood follows where the camera looks, including while clinging or climbing, so a pinned figure reads as looking around. In first person it's flat (no body is drawn).
- **Folk:**
  - Every cloaked figure (camp folk, the opening pair, cloaked creatures) looks at your head when you're within 12 m (scaled by its size) and in front of it.
  - Otherwise it glances about now and then (up to 35°).
  - Seated folk turn the hood and half the torso.
- **Dev view:** `CLOSE=1` gives a close-up; `HEADLOOK=yaw,pitch` sets the wanderer's look (shot: 70° left and 10° up; the hood in profile, the torso following).
- **Checks:** tech_check passes; the wanderer's cloth numbers are unchanged.
- **Reference still has:** hand gestures and idle body language on folk. Ours only turn their heads.

---

## 2026-09-28 — Session 2, Step 3: seasons (addendum §F)
- **Calendar:**
  - Four seasons over the 365-day year: `scripts/sky/seasons.gd`, numbers in `data/seasons.json`.
  - Each season's middle sits `lag_days` (20) after its solstice or equinox.
  - A 20-day change straddles each boundary; the rest is settled. Measured at 45° N: 71 / 20 / 71 / 20 / 72 / 20 / 71 / 20 days.
  - The south runs half a year behind.
- **Temperature:**
  - `warmth` is −1 in winter, 0 in spring and autumn and +1 in summer, eased through the changes (plateaus, not a sine).
  - Times a latitude swing: about ±1.5 °C at the equator, ±15 °C at 45°, ±22 °C at the poles, damped to 45 % over open water.
- **Moisture:** a multiplier on evaporation (so on cloud and rain), by band:
  - tropics: wet summer ×1.45, dry winter ×0.55;
  - temperate: winter ×1.12, summer ×0.85;
  - polar: summer ×1.2.
- **Wired into the weather sim:**
  - Each cell relaxes toward its latitude norm plus the season's offset.
  - Evaporation is scaled by the season's moisture.
  - The day/night heating is now measured against that day's mean sunshine at that latitude, so the tilted sun doesn't double-count the season.
  - The spin-up that builds the climate maps runs season-free with the equinox sun: the maps stay annual means and world gen is unchanged (stamp_check passes).
- **For the climate code:**
  - `local_weather()` now also returns `season` (for example "Spring → Summer 40%"), `season_temp_c` and `season_moisture`.
  - F3 shows the season, the day of the season, the swing and the wetness.
- **No plant response yet.**
- **Checks:**
  - daylight_check (now with the seasons), p0_timelapse, stamp_check and tech_check pass.
  - play_fixes_check fails 2: "the shot on release hit the deer" and "drawing slows you on the ground". Both come from the other session's data commit 8d508a6 (`aim_mps` 0.75 → 8.8, arrows `inherit_velocity` 1.0, no air steering). The tests encode the old design.
- **Reference still has:** visible seasons (leaf turn, frost, thaw). Here the season exists only in the numbers until plants respond.

---

## 2026-09-28 — Session 2, Step 2: derived day/night (addendum §F)
- **Tilt:**
  - Axial tilt is 23.5° and the year is 365 game days; day of the year 0 is the northern spring equinox. Game day 0 is year day 0 (`year_start_day`); the world clock starts on day 13.6.
  - The sun's declination swings ±23.5°.
  - The moon follows the same geometry: its declination is the ecliptic's at its own place (plus its 5° inclination). At 45° N the winter full moon rides 65° high at midnight, the summer one 18°.
- **The warp is now astronomy:**
  - The sky turns at one of three speeds (night, twilight within ±10°, day), blended over 4° of sun elevation.
  - The speeds are calibrated once so the equator on an equinox gives exactly the reference 60/18/48/18.
  - Anywhere else the same speeds act on that place's sun, and the turn is scaled to still take 144 minutes.
  - Day, dusk, night and dawn therefore derive from latitude and declination.
- **Measured** (`tools/daylight_check.gd`; minutes day / dusk / night / dawn):

  | Place | Date | Daylight | Day / dusk / night / dawn (min) |
  |---|---|---|---|
  | Equator | Equinox | 14.1 h | 60 / 18 / 48 / 18 |
  | Equator | Solstice | 14.2 h | 58.5 / 19.3 / 46.8 / 19.3 |
  | 45° N | Equinox | 14.4 h | 53 / 24 / 43 / 24 |
  | 45° N | June | 16.7 h | 65 / 27 / 25 / 27 |
  | 45° N | December | 12.2 h | 32 / 29 / 55 / 29 |
  | 75° N | June | 24 h (midnight sun) | 107 / 37 / 0 / 0 |
  | 75° N | December | 0 h (polar night) | 0 / 0 / 102 / 42 |

  Twilight lingers at high latitude (48 min each at 75° on the equinox).
- **Where it's wired:**
  - `DayCycle` and `Astro` take a latitude everywhere (main, HUD, tools).
  - You still wake at the start of dusk: that hour now depends on your latitude and the date.
  - The weather heats by the tilted sun, so it has seasons on its own.
- **Dev readout (F3):** latitude, year day, the sun's declination, hours of daylight on the 24-hour clock, and today's minutes of each phase here.
- **Checks:**
  - daylight_check passes.
  - p0_timelapse passes: no jumps, the equator's phases at 59.9 / 18.1 / 47.9 / 18.1, the start-hour inverse exact at two latitudes.
  - tech_check and play_fixes_check each report 0 fails.
- **Note for photoperiod:** the reference split puts day plus twilight at 96 of 144 minutes, so the equator gets about 14 h of daylight on the game clock, not 12. Real short-day thresholds (for example cannabis at about 12 h) would never trigger in the tropics unless they are read against that.
- **Reference still has:** a deep cobalt sky with bold painted clouds by day and indigo with baked stars by night (checklist item 2). Our sky is still the old R1a gradient.

---

## 2026-09-28 — Design + data session (Claude, chat; the designer's late-night calls)
- **Design doc:** `docs/design/RECONCILIATION_2026-09-27.md` now runs Thesis + §0–V. New tonight: §I 1/10 planet with 1/10 biomes; §J momentum ceiling 120 km/h, asymmetric gravity, branch bounce, alternating feet; §K momentum in combat; §L HUD speedometer + watch-face clock; §M/§T three tools only, starting kit; §N hold-to-charge, charging never slows; §O master shinobi; §P opening/wake-up with fleeing shinobi; §Q enemy camp; §R committed air momentum + free body rotation + contact re-aim by angle; §S super meter and the super shot; §U controls/HUD text/loading screen/arrow fixes; §V folk catch arrows, diagonal movement, tree tops + perch, climb on right-click cling.
- **Data (additive, marked `[NOT WIRED YET]` where code doesn't read it):** `movement.json` air (gravity_up/down, no air steer), redirect, bounce, bounds, super_meter; `combat.json` fishing, overcharge, strike, quiver, trail_min_m, fletching_from_cloak, arrows inherit full velocity; `items.json` starting_kit, pole slot, no tool spares, stone tool gone; new `data/hud.json`.
- **Controls:** Tab (and I) inventory; mouse wheel reel_in / reel_out bound.
- **Reference maths:** `tools/reference/daylight_reference.py` + `daylight_table.csv` — tilt, sunrise by latitude, natural twilight, polar cases, the stylised 144-min clock (design §F2 explains why the warp stays), seasons, photoperiod. Claude Code's Step 2 should match it.
- **Plants:** `docs/design/PLANT_SCHEMA.md` locked; `tools/plant_schema_check.py` validates; pilot fill done by parallel agents on 7 files / 135 species (cypress, pine, acacia, trichocereus, rainforest, swamp, tallgrass prairie), all `--strict` clean.
- **Consistency audit:** a read-only agent swept README, DESIGN, spec, notes, data help and code headers against the design; fixes applied to precedence (spec now cites the design doc), scale/time, look, tools, phase numbering (design doc aligned to the spec's), Tab, climbing. Code-comment staleness (planet_const, world, planet_player, bow, camps headers) is left for Claude Code to fix as it touches those files.
- **`docs/WORKING_AGREEMENT.md`** — who owns what between the two agents, pull-before-push, additive data, docs describe the built game.
- **Open for Claude Code:** the five-step Session 2 prompt (steps 2–5) plus Step 6 (§J/§K/§L data), then §U/§V fixes: arrow trail at the apex, fletching colour, diagonal movement, tree-top handhold + perch, climb on cling, Tab, HUD scale/font, loading runner.

---

## 2026-09-28 — Session 2, Step 1: dark daylight (addendum §C, lighting model and grade only)
- **Light:**
  - The sun is the one directional light by day and casts real shadow maps (there were none before): hard-edged, with no blur and soft filtering off; 4 splits over 90 m.
  - Ambient is cut to a low, deep blue (#2448D0 at 0.42 by day), which is all a shadow gets, so shadows read deep blue: sand in shade is about (19, 19, 100) on screen.
  - Sky ambient and sky reflections are off.
  - The light's elevation is squeezed under 38° (`rake_max_deg`), so it rakes even at noon: the dev spot's 58.5° noon sun lights at 34.7°. The sun disc stays true.
  - The moon lights the night the same way.
- **Grade:** two presets, day and night, in `data/look.json`.
  - Each preset: mids down (a power curve), saturation ×1.35 day / ×1.3 night, greens toward teal, blue shadow tint, contrast and vignette.
  - The frame is graded by each preset in full and crossfaded by daylight, never one curve.
  - The environment's old saturation/contrast adjustment and the old haze veil are gone.
  - No SSAO, bloom, SSR or soft shadows.
- **Fixes along the way:**
  - Plant shaders are double-sided (for leaf cards), so trunks shadowed themselves in striped acne that no bias could fix. In the shadow pass, closed shapes (bark, crowns, culms) now cast from their far faces only.
  - Blob shadows are off (`look.light.blob_shadows`); real shadows replace them.
- **Dev viewpoint:** `tools/dev_view.gd` gives the same frame every time: seed 42 stamp, first camp, you on the fire's north side (`Encampment.fixed_side`), the camera 9 m south of the fire. It saves noon and midnight.
- **Checks:**
  - p0_timelapse passes; its light-energy limits are now a share of full strength.
  - tech_check passes.
  - play_fixes_check fails only the "wall jump out of a sprint jump" check, which failed before this change too.
- **Open:**
  - Striped shadows from leaf cards remain on some bush tops.
  - The shadow cost is unmeasured on real hardware. `look.light.shadows` false switches shadows off; `shadow_max_m` shortens them.
- **Reference still has:** ragged leaf-card canopies against the sky; ours are still smooth blobs, which the hard light now shows up.

---

## 2026-09-28 — Feel pass 2 (the designer's second play)
- **Jump:** gravity 19.6 → 28 m/s² and take-off 5.2 → 7.6 m/s: a hop is about 1.0–1.1 m high (was 0.7) with the same 0.53 s in the air, so it's higher and less floaty. Fast-fall 26 m/s. Swings keep their old rhythm (swing gravity_scale 0.7).
- **Wall jump:**
  - The window is 14 frames (was 7).
  - The kick is 11 m/s (was 7.5), about 1.5 m up even from a standstill.
  - Letting go of right click out of a cling now springs you off at 0.9 of a kick (it used to drop you). Shift drops off.
  - Only a perfect tap chains.
- **Body:**
  - The player is 0.92 scale, about 1.44 m to the hood (movement "body" player_scale). The capsule, eyes, camera, climbing reach and your corpse scale with it.
  - Arms are 0.06 m longer (shoulder to mid-hand 0.62 m), in proportion. Folk keep their own heights.
- **Ninja run arms:**
  - The arms trail back 76° from hanging, flared 14° out, elbows bent 14°, and bob 6° with each stride.
  - They trail through jumps and ease back over 0.22 s. All of it is in movement "run_pose".
- **Climbing:**
  - About twice as fast: 4.1 m up in 2 s (was 2.1). Reach speeds are doubled, beats cut to 0.05–0.08 s, and the minimum reach time is now in data (min_reach_s 0.12).
  - A and D were reversed round the trunk. D now always goes to the camera's right, whichever way the wood's angle runs, and the arms no longer cross.
- **Bow and spear:** no aim arc before release (combat "arc" show_aim_arc false). After release, a brighter, wider streak follows the shot, and it stays visible far off.
- **First person:** nothing of your body shows (no cloak edges, hands or boots); your shadow stays. Set movement "camera" first_person_body to true to bring the hands and boots back.
- **Checks:**
  - tech_check and inventory_check pass.
  - play_fixes_check passes except "wall jump out of a sprint jump", which fails the same way on the previous commit (it depends on where creatures wander).
  - hits_check's "folk head hit reads 2x critical" also fails on the previous commit.
  - The hop and aim-arc checks now test the new design.

---

## 2026-09-28 — Design reconciliation built into Phase 1 (from docs/design/RECONCILIATION_2026-09-27.md)
- **Merged:**
  - All the reconciliation commits.
  - `data/plant-catalogues` at edd25cd: bark and leaf tiles, appearance blocks, the fish catalogue. Nothing reads these yet.
- **Time:**
  - The game is locked at 60 fps with 60 Hz physics.
  - You wake at the start of dusk: 17:00 on the 144-minute clock.
  - `data/dev.json` now plays the real 144-minute day.
- **The tech button (right click in the air):**
  - On a wall, cliff, trunk or ruin face: a tap within 7 frames of touching it is a wall jump. Chained wall jumps gain ×1.03 each, up to 4, so a chain keeps or builds speed (was −28% each).
  - Holding is a cling that lasts 2.5 s. Space out of a cling kicks off weakly and starts the chain over.
  - Near a limb, bamboo or vine: hold to catch and swing. You can hang as long as you like; let go to fly on.
  - Handholds behave per species (`data/handholds.json`): break speed, flex, snapback, how much weight they bear.
    - Green bamboo launches you (breaks at 60 m/s, snapback 0.9).
    - Dead wood cracks at a third of that.
  - Vines hang from wet, warm-country trees; on the stamp's rainforest, 7–9 of 83 trees carry 170–220 vine handholds.
- **Roll, momentum, impact:**
  - Landing roll: crouch within 5 frames of touchdown. A 10 m drop costs 0 health instead of 28 and exits at 17.5 m/s.
  - Over sprint speed, momentum carries on the ground.
  - Hitting a trunk at 22 m/s without a tech: 60 damage. With a tap: none.
- **Look:**
  - The ninja run pose.
  - One crouch pose for the squat, kick, cling and roll.
  - The first-person view never tumbles.
- **Dead wood:** 3% of trees stand dead by default (taiga 12%, badlands 18%, swamps 10%) and 15% of bamboo culms. They are bare and grey, and brittle as handholds. There is one fixed decay stage until Phase 5.
- **Death:**
  - Your body stays where you fell with all your gear, and birds circle it after 45 s.
  - You wake by the nearest camp fire with nothing. Test: 1,459 m from the body, full health, no bow.
  - E by the body takes everything back.
  - Nothing hostile hurts you within 8 m of a lit fire.
- **Cloaked folk:**
  - Tribal, marsh and northern folk, the opening camp's elder and hunter, the small folk (the goblins, renamed, with their lanterns), the Forest troll and the Marsh witch all use the player's rig and cloak, scaled.
  - Each person wears a rolled dyed-cloth palette, mostly from their tribe's family; the player's indigo and rust is never rolled.
- **Checks (headless):** tech_check 23 of 23, play_fixes_check 35 of 35, inventory_check and hits_check all pass; every script compiles.
- **Open:**
  - Bamboo shoots (a forage item) wait for Phase 10.
  - Dead wood's decomposers, cavities and residents wait for Phases 5–8.
  - Northerners' fur trim and the big folk's heavier hood aren't done.
  - The restless dead at ruins keep their bones.
  - The era texture tweaks from the reconciliation doc (`filter_nearest_mipmap`, render scale) are still open.

## 2026-09-28 — Phase 1 play session 1: the designer's eleven items fixed, ready to re-test
- **Checks:** `tools/play_fixes_check.gd` (items 1–5 and 7–9, every check passes), `tools/inventory_check.gd` (all pass), `tools/hits_check.gd` (all pass); every script compiles.
- **Tables:** every movement and weapon number now lives in `data/movement.json` and `data/combat.json` (hits, feedback and healing included), each part explained at the top of the file. Items are in `data/items.json`.
- **1. Stuck:** shrubs collide only at their woody stem. You are unstuck when wedged between two things, held off the ground (under a root) or caught on a crease of the ground. Headless: 2 minutes through the densest patch, 748 m covered, never held for a second. The creases' cause is not found yet (they happen every few seconds in a forest; freed in 0.08 s).
- **2. Speeds:** walk 5.5 m/s, sprint 8.8, sneak 0.8.
- **3. View:** first person by default; you can look straight up and down (89.9 degrees) in both views.
- **4. Tracers:** a dotted blue-white arc while drawing or raising, and a trail behind the arrow or spear. It now also stops on ground beyond the collision; a shot at 109 m landed 0.7 m from the arc's end.
- **5. E in any state:** while climbing, one hand takes a stuck spear or arrow and the other keeps the wood.
- **6. Wanderer:** short, hooded, faceless, with an ultramarine cloak and a rust hem. The cloak is cloth (swings, trails, settles, lifts in wind, lies down when crouched). First-person eye height is lowered to 1.45 m.
- **7. Feel:**
  - Standing hop: 0.52 s, 0.74 m.
  - Stop slide: 0.3 m from a walk, 1 m from a sprint, about 1.6 m when wet.
  - Turn-around: a 0.2 s skid.
  - Jump length: 3.2 m from a walk, 5.9 m from a sprint.
  - A 3 m ledge drops in 0.55 s (0.78 s at Earth's pull).
  - Fast-fall: 20 m/s.
  - Landing squat: 50 ms, or 160 ms after a big drop. Bumps no longer count as landings.
  - Fall damage goes by height, so a fast-fall never hurts.
- **8. Wall jump (right click):** off a trunk, 4 m/s away and 6.4 m/s up; the next one in a chain keeps 72% of the height. It plays a scuff that creatures hear.
- **9. Chain:** drawing no longer ends a sprint or jump; it slows you to 0.75 m/s on the ground only. The aim wanders 0.3 degrees standing and about 0 at a jump's apex. Sprint, jump, wall jump, draw in the air, hold through the landing and release all work in one input run, and the arrow killed the deer with a torso hit. Input log: forward at 0.000 s, 0.033 s up and 0.067 s held (the sprint); jump 0.767 s; wall jump 0.950 s; draw 1.000 s; release 2.367 s.
- **10. Health and hits:** a slim blue bar with a number replaces the hearts; no regeneration; resting at a fire heals. Head 2x, eye 4x and blinds, limbs lame. Rising numbers, and the X on a critical or a kill. tools/hits_check.gd passes.
- **11. Inventory (I):**
  - Worn slots: ranged, melee, amulet, rings, each with spares. Ten carry slots.
  - E on a plant takes a sample carrying its binomial (6 species taken in the test).
  - G sets a thing down; E takes it back.
  - Past six things: 8% slower each, climbing 12% slower, 15% louder.
  - The world doesn't pause while it's open.
- **Open:**
  - The bow and spear are sized for the old taller body.
  - The ground-crease cause is not found.
  - Fish and mushrooms have no source yet (stone tools are cut: three tools only, design §T).

## 2026-09-27 — Plant world restructured: merged data/plant-catalogues at 1a88bfe (data + spec)
- **Hero genera:**
  - 3–5 archetypal species each; the full lists are archived in docs/plant_archive/ (66 files, not loaded).
  - Cannabis 64, Amorphophallus 246 and Trichocereus 18 stay complete; fungi 43.
  - New catalogues: fern 16, moss 14, bucephalandra 4, cypress 5, sequoia 3, araucaria 5.
  - 24 catalogues, 499 entries.
- **Biomes rebuilt:** 52 files, 911 entries (234 `from_catalogue`); hero_species lists; traits on every entry.
- **Conflicts:** my earlier trim conflicted in 29 files; the branch's version was taken throughout.
  - Macrogonus set back to `reported` (designer ruling).
  - `leaf_density` re-applied where the species survive: holm oak, both umbrella thorns, paloverde, savanna acacia. Beech, mesquite and the dry-season deciduous tree are gone.
- **Dry run:**
  - Biome files: 0 warnings, 640 names.
  - Catalogues: 24 parse OK, no warnings beyond the 24 expected "unknown biome key".
  - 1,031 species in all; 16 landmark, 4 rheophyte.
- **Open:** 18 fern and moss names (Bracken, Resurrection fern, Sphagnum moss, Reindeer lichen…) are plain biome entries, although these families are meant to be catalogue-only. The loader folds each catalogue copy into the biome one.

## 2026-09-27 — Catalogues trimmed to the genera the designer named (data only)
- **Designer:** "keep it simple … reduce the amount of actual variety". Biome files unchanged. Catalogue entries 807 → 623.
- **Trimmed:**
  - magnolia 18→16, giant_herbs 24→18, vine 30→3, bromeliad 30→14, cycad 24→5, palms 43→8, orchid 60→9, fungi 43→15.
  - The single-genus catalogues, baobab + ginkgo, acacia (all three acacia genera) and carnivore (all 13 genera were named) are unchanged.
- **My picks where nothing was named:**
  - Palms: one genus per crown form in the shape work (doum, coconut, date palms, Washingtonia).
  - Orchids: lady's slippers and Dendrobium.
  - Bromeliads: one tank bromeliad, so the frog-tank rule has a plant.
  - Fungi: the one dung and one carcass fungus, so those pools can decay.
- **References:** removed names stripped from 37 association `catalogue` entries and 138 `special` entries; no association lost a dominant.
- **Dry run:** 0 warnings beyond the 18 "unknown biome key"; 1,166 species. stamp_check PASS.

## 2026-09-27 — Plant associations (data + spec; nothing built)
- **Merged:** `data/plant-catalogues` at 859d296. 213 plant associations across the 42 land biome files (2–8 each, cover 0.1–0.95). Every member name resolves to a loaded plant. cc70585 gives every entry a species-level binomial, so the tepui "spp." entries are fixed.
- **Spec:**
  - Phase 6: two-step placement replaces per-species placement. Per patch, choose an association by its `where` cue; lay down its members together; outsiders stay at low density. It is the R6 pre-filter; succession reads it; three new done-when lines.
  - D4: the `associations` block. R6.10 updated.
  - ⚑ Proposed: a fixed cue vocabulary for `where`, parsed at load.
- **Species readout (HUD):**
  - Tree trunks are named correctly (Acer saccharinum, Populus deltoides).
  - Small plants: the plant index builds (16,769 instances at the tepui spot), but a lookup through a Stegolepis still returns nothing. Being traced.
  - The animal test froze the squirrel, so its hitboxes never switched on. A test flaw; to redo.

## 2026-09-27 — Carnivorous plants and the tepui (the 52nd biome); data + spec, one template added
- **Merged:** `data/plants/carnivore.json` (0881fb9, 43 species) and `data/biomes/51_tepui.json` (4398f90, 16 endemics).
- **`biome_templates.gd`:** TEPUI added last (id 51, group Mountain, small), so existing ids are unchanged. Nothing classifies as it until the Phase 2 landform. This resolves 51 vs 52.
- **Dry run:** load_all "bad scripts: 0". Biome files: 0 warnings (TEPUI is a known key now), 677 entries, 574 names. Catalogues: 18 files, 807 entries, parse OK; the only warnings are the 18 expected "unknown biome key" ones. 1,342 species loaded together.
  - Carnivore clashes: Sun pitcher and Round-leaved sundew, already biome plants.
  - Trap types: pitfall 23, flypaper 16, snap 2, bladder 1, corkscrew 1.
- **stamp_check:** PASS, 48 of 51 surface templates present (Puna, Maritime forest and Tepui absent; Tepui as designed).
- **Spec:**
  - Phase 2: the tepui landform; 52 biomes resolved.
  - Phase 3: quartzite caves in tepuis.
  - D4: the carnivore block and tank_dweller.
  - Phase 6: carnivorous plants. Phase 7: they read the insect ledger. Phase 9: savanna carnivores need burns.
  - Phase 11: the tepui is the oldest land.
  - Part F: one new line.
- **Open:**
  - Three tepui entries (Cyathea spp., Cladonia spp., Navia spp.) have no species name (binomial rule).
  - No tepui mythic exists yet.

## 2026-09-27 — Merged data/plant-catalogues at 5a4ad60 (data + spec only; nothing built)
- 17 plant catalogues, 764 entries, all with binomials (adds pine, magnolia, rhododendron, citrus, cycad, baobab + ginkgo, acacia, vine, orchid, bromeliad, giant_herbs), plus `data/creatures/catalogue_dragonflies_snakes.json` (33). No conflicts; leaf densities and macrogonus `reported` intact.
- **Plant dry run** (the real loader's `_load_file`, read-only):
  - Biome files: 0 warnings, 558 names.
  - Catalogues: 17 parse OK; the only warnings are the 17 expected "unknown biome key" ones. 727 new species, 1,285 in all.
  - 36 catalogue names match biome plants and fold into them (the loader merges by name and keeps only the biome entry's data). Rattan is in both palms and vine.
- **Creature dry run** (`CreatureSpecies._from` on both files): 0 warnings, 61 creatures, 61 unique names, all with binomials. The catalogue's 33 are `"spawn": "ambient"`, not disabled; harmless while the loader reads only creatures.json, and the Phase 7 card says the loader holds them back.
- **Spec:** D4 (catalogue list, landmark, climber, camp_follower, orchid, bromeliad, growth default, venom, sound, hibernate, lifecycle, data/creatures/*.json); Phase 6 (catalogue rules, shape work, 661 + 764 pre-filter); Phase 7 (pollinator specifics, creature catalogues, snakes, dragonflies); Phase 9 (fire-adapted pines); Phase 11 (landmark trees named).
- **Open:**
  - Pollinator specifics live only in `repro.note` text; a `pollinated_by` field is proposed.
  - The 36 name clashes: which copy should win?
  - The 26 older creatures.json entries have no `trophic`.

## 2026-09-27 — Phase 1 partly signed off; plant catalogues merged; Phase 1 fixes; spec for plant groups, foraging and fungi
- **Signed off (designer):** Phase 1 for hitboxes, 3D audio, ripples, Night Rider and Pond Crawler. **Held:** player feel, until the designer has played it on the stamp (docs/HOW_TO_RUN.md).
- **Merged `data/plant-catalogues` (4021760).** All 50 surface biomes researched: 661 entries, 537 binomials, 558 names. New catalogues: yucca (55), palms (43), fungi (43), making 469 catalogue entries. Each land biome has a computed `special` list.
  - **Dry run:** 0 warnings from the biome files. Six catalogues parse OK, with only the six expected "unknown biome key" warnings.
  - **Name clashes:** 8 catalogue names match biome plants (Soapweed yucca; 7 palms). The loader folds each into the biome entry.
  - **Fungi:** they load as ordinary plants today.
  - **stamp_check:** PASS, with 48 of 50 templates present.
  - Leaf densities re-applied to the six species.
- **Phase 1 fixes:**
  - Limb climbing at about 0.3 m/s. Estimated from the reach speed, not measured: after the merge the headless climb test finds only giant trees at its spot (below).
  - The bow aims from the crosshair (`PlanetPlayer.crosshair_point()`, shared with the spear); spear test 32/32.
  - The Night Rider, Pond Crawler and gibbon sounds are on the falloff table.
  - Macrogonus is `reported`.
- **Spec:**
  - A3: evidence is play, a screenshot or a headless number; no recordings unless asked; verification under 10% of build time.
  - Phase 1 sign-off status and Phase 1.5 (the R1a batch-2 look: a dusk river and a deep night).
  - The camp rule: only new camps stay out of landmarks.
  - Phase 6: plant groups, the species pre-filter (and R6.10), palm, yucca and aroid shapes, fungi data and look.
  - Phase 7: foraging, pollination and dispersal as side effects, insects as creatures, the decay loop replacing the snag and log timers.
  - D3/D4 fields; Part F ×3.
- **Phase 2 audit done (audit only),** reported to the designer; nothing built.
- **Open:**
  - Researched heights make giant trees (teak up to 50 m, trunks up to 2.6 m in radius at chest height; a 31 m strangler fig). Climbing fails on trunks that thick: shape proportions are Phase 6, and a climbable-girth rule is wanted.
  - Mycorrhizal fungi don't name their hosts.
  - The 8 name clashes.

## 2026-09-27 — See-through crowns (designer request; Phase 1 follow-up)
- Leaves on branchy trees are now clusters on the outer third of each limb and branch (crossed alpha-cutout leaf cards per R1, lumpy, twigs fanning from branch tips on leafy species) with open air between them, instead of solid crown lobes. From below you see limbs, sky and the gibbon.
- Count and size: new table field `leaf_density` (shape defaults; set on beech, holm oak, dry-season deciduous, acacia, mesquite, paloverde) sets clusters per tree (about 8 on cypress, 12-16 on sparse species, 17-27 on leafy broadleaves). Per tree, `PlantMeshes.leaf_amount(growth, moisture)` thins and shrinks them in the shader: down to about 40% in the driest bands. Growth is a stand-in (height within the species' range) until Phase 6; the shader's `leaf_season` is the Phase 5 winter hook (1 today, so no winter effect yet).
- Ground under crowns: dappled shade (patches of shadow broken by sun flecks, weighted by each tree's leafiness) in the terrain shader, since there are no shadow maps to cast real dapples.
- Verified: load_all "bad scripts: 0"; before/after stills from the ground under the same tree with the gibbon crossing (/tmp/shots/canopy/cmp_*.png). A hero tree is about 1,000 triangles, fewer than the old lobe crowns.
- Open: the far LOD keeps the solid single crown; winter thinning waits for Phase 5; `leaf_density` on the rest of the table is a data pass if wanted.

## 2026-09-27 — Phase 1 build: all builders merged (done-when clips deferred)
- Merged the spear (Q/Y swap; tap to thrust about 2 m, hold to raise and throw at 9–24 m/s on an aimed arc; it sticks in the part it hits and rides along; E takes it back; a carcass that fades drops it), plus noise creatures hear (`NoiseEvents`: arrow 8 m, spear 12 m, thrust 5 m; grazers flee, go wary or ignore it).
- Merged climbing on branch graphs (hand over hand up the trunk, onto limbs at forks, shimmy until too thin, reach across; about 0.5 m/s on a trunk, 0.36–0.46 m/s on limbs), the gibbon on the real trees (8 m leaps, climbs to regain height, rests out of range), and the F7 dev spawn (riders → crawler → gibbon, with the reason printed when it can't).
- At the merge: arrows and the spear now hit any rig with hurt(), so the gibbon is no longer treated as a camp person, and they stick to the exact collision shape only when one body carries several parts. Spear and climbing sounds moved onto the falloff table (new rows: spear, spear_impact, climb_hand, climb_breath).
- Verified: load_all "bad scripts: 0"; momentum; spear test 32/32; climb test (2,033 hand checks, worst 2.9 cm off the wood; the engine crashes on quit after the checks pass, as seen before the merge); F7/gibbon-arrow test; stamp_check PASS.
- Deferred at the designer's request: the done-when recordings (sprint, sneaking, arrow and spear sticking, howl, climbing under the gibbon, wading rings).
- Open: limb speed is above the brief's ~0.3 m/s (slow it?); the gibbon travels inside the crowns, so it's hard to see from the ground; the bow's aim ray still starts at the camera (0.55 m off the crosshair while drawing); the elf has no elbows; damage values and the spear and climb sounds are placeholders.

## 2026-09-27 — Phase 1 build: sound merged (climbing and spear still in their copies)
- Merged so far: tree limbs + branch graph (F6), ruin/prop colliders (F4), shared creature hitboxes, momentum movement, gibbon, Night Rider, Pond Crawler, ripples. Now also every world sound in 3D (D5): one falloff table (`data/audio.json`, `Audio3D`), rain ring, thunder placed at the strike, footsteps/hurt/meteors 3D, a camp murmur when folk speak, F8 dev_howl. A headless audit finds no 2D players left.
- Verified: load_all "bad scripts: 0", momentum test, stamp_check PASS. Howl clip: about −8 dBFS at 25 m, about −25 dBFS past 100 m; the left/right balance swings +34 dB → −25 dB as the camera turns (sent).
- Still in copies: climbing + gibbon on real trees + F7; spear + projectile noise events. After them: the Phase 1 done-when clips.
- Known gaps: the Night Rider and Pond Crawler sounds are outside the falloff table; the camp murmur plays only with subtitles; the howl clip barely shows the pack (steep den).

## 2026-09-27 — Spec: life from life, Trichocereus, the ceremony (docs only, nothing built)
- Merged `data/plant-catalogues` (28f31bf): adds `data/plants/trichocereus.json` (18 torch cacti). Its amorphophallus and cannabis files are byte-identical to ours, and the READMEs are combined. All three catalogues parse cleanly (no duplicate keys; genus/species on every entry). A read-only dry run through species_db's loader takes 328 entries; the only warning is the expected "unknown biome key", which the Phase 6 loader skips.
- A2 gains **Life comes only from life** (no proximity spawning, plants in patches from parents, bare ground until a seed arrives, local extinction sticks) and **Browsing** (`cannot_be_browsed`; browsing writes `flora.age_structure`). Phases 6 and 7 cross-reference it. R3 gains goats (cold–mild and mild–warm mountains).
- Phase 6 gains the Trichocereus catalogue. The check shows today's `cactus` shape is one fixed two-armed column, so Phase 6 must add arms, clumps and a trunked form. Phase 10 gains the Trichocereus ceremony: oracle, `ceremonial` tags, `player.vision`, the tocapu lattice in #E8B84A/#A01020 (now in R1a), a reading drawn from real records, and a done-when check. D3 gains culture `ceremony`, `oracle_standing`, `guest_until` and `player.vision`; D4 gains `cannot_be_browsed`, `synonym`, `display`, `ceremonial`.
- Open: the file tags five species documented (macrogonus too) vs four in the text; validus is 4–8 m; chalaensis grows low; six entries share Kew's *E. macrogona*. Existing cacti and thorn scrub don't carry `cannot_be_browsed` yet (a data pass, when wanted).

## 2026-09-27 — Spec: R1a second reference batch; pack order (docs only, nothing built)
- R1a changes:
  - day sky zenith #0A1AE0, hard-edged white clouds, grass #4CC03A in full sun;
  - a deep-night full-blue grade toward #1B2ED8, with the old night values as the dusk end;
  - purple-magenta storm and volcanic skies (#5A1AA0 → #C030C0);
  - a rare dread red #A01020;
  - warm light tiny (one or two points per scene); snow fully blue.
  The designer's text is quoted verbatim in R1a.
- Phase 10 gains new remnant kinds (stone stairways, hung bells, a stone giant/idol gate, hollow-tree dwellings, wells, candlelit chapels) and names herb bundles hanging from rafters as the reference for the drying state.
- Phase 8 gains (d) Pack order: family packs, ranks derived from age, sex, parentage and a dominance gene; leaders choose, eat first and howl first; splits found new packs; rank is visible; killing a leader breaks the pack. D3 gains `fauna.packs`. Done-when and Part F gain a check each.
- Open: the R1a batch changes the signed-off look; the renderer is unchanged until the designer says when. The designer then attached ten stills; they're in `docs/references/batch2/`, linked from R1a.

## 2026-09-27 — Spec: plant growth stages (docs only, nothing built)
- Phase 6 Lifecycle gains growth stages:
  - trees go sprout, sapling, mature, old; herbs and shrubs go sprout, young, mature;
  - growth runs 0–1, and plant_meshes changes the silhouette per stage;
  - only old trees carry the branch graph and are climbable;
  - growth rate follows fertility, suitability and dormancy;
  - browsing holds saplings back;
  - only mature plants yield;
  - crops use the same block.
- The ledger gains `flora.age_structure` (counts per stage); biomass becomes its weighted sum; the warm start yields a real age mix. D4 gains the `growth` block.
- Done-when gains: all four stages in a forest patch; a browsed sapling never becomes a tree; a camp plot grows each dev day. Part F gains: where deer are thick, no saplings.
- Open:
  - `lifespan_years` becomes the sum of the stages (derive it?);
  - browsing needs Phase 7's herbivore counts;
  - camp plots are Phase 10 (a dev test plot until then);
  - plants germinated in play are stored as cohorts.

## 2026-09-27 — Spec v4: caves, renumbering, plant life, catalogues, binomials (docs + data pass; nothing built)
- **New Phase 3 — Caves and underground**; the old Phases 3–11 are now 4–12 (Wind 4, Seasons 5, Soil & flora 6, Ecology 7, Living populations 8, Disturbance 9, Camp life 10, Memory 11, Persistence 12). Cross-references fixed in D1, D3, the cards, R4, R5 and this log. Snags and dead wood sit on Phases 6, 7, 9 and 10 exactly as re-sent.
- **Phase 6** gains plant reproduction, lifecycle, the flora ledger (per species, sparse per region), plant genetics, `eco_sim`'s flora half, the Amorphophallus catalogue and the cannabis rules. The ledger core therefore moves up from Phase 7, which now adds fauna and cave fauna. **Phase 10** gains camps formed around remnants (set pieces unpark there) and the cannabis loop with `player.haze`. Part F gains four checks.
- **D3/D4:** new fields `cave_density`, `flora.biomass` / `seedbank` / `genome_mean` per species, `society.landmark` / `salvage` / `standing`, culture `ritual_smoke`, `player.haze`, and `scent` events. D4 adds the `data/plants` catalogues, the `repro`, `genes`, `aroid` and `cannabis` blocks, the `aroid` shape, `underground`, and the binomial rule.
- **Data:** `data/plants/amorphophallus.json` and `cannabis.json` added. Both parse cleanly (Python strict and Godot JSON, no duplicate keys). A read-only dry run through species_db's real entry loader loads 310 entries (246 as umbrella, 64 as shrub) with no warnings other than the expected "unknown biome key", which the Phase 6 loader change skips. Every existing plant (111 entries, 107 species) and creature (25) now has genus and species: 77 real plants and 30 invented, 17 real creatures and 8 invented. Tables load with no warnings; tools/stamp_check.gd passes.
- **Parked work saved:** the local-only `hold/set-pieces` branch is now `docs/parked/set-pieces.patch` (applies cleanly).
- **Open:** do the inhabited-ruin camps move out ("never inside a landmark")? Hunger, a fear vignette, oracle tribes and a torch don't exist yet. GLACIAL_TILL caves: none? 15 aroids reach 12 °C, so the mild band too. Placed items, felled trees and salvage as stored deltas.

## 2026-09-26 — Phase 0 signed off; spec patched for Phase 1 (docs only, nothing built)
- **Phase 0 — Look & Light signed off** by the designer on the dusk river shot. Current phase: **Phase 1 — Player feel, hitboxes, audio**.
- Designer's answers: stamp stays 40 km; ruins and mythicals stay on the stamp (test bed for Phases 6–10); dusk clouds fine as shot; fire trial: #FFA050 for the light on folk and props, #FFB020 core and #FF4A00 coals kept. Trial shot sent (runtime override only; the code change waits for Go).
- Spec: D1 scale note (400 km through the last phase, now Phase 12; maybe 1/10–1/30 Earth later; two-tier storage). D3 rewritten against the code: where every field lives now, a proposed home and owner for each missing one, regions as 4×4 cell blocks (~8 MB ledger on the full planet). D4 gains tree lifespans. Phase 1 card gains the branch graph, climbing, gibbon brachiation, and the ripple / Night Rider / Pond Crawler text verbatim. Phase 2 gains the memory and current checks. Snags and dead wood run across Phases 6, 7, 9 and 10 (numbers since the caves renumbering), plus R3 (woodpeckers, owls) and Part F (two checks).
- Next: Phase 1 Prompt A (audit + minimal changes), then wait for Go. The ripple, Night Rider and Pond Crawler agents are still in their copies; they get audited against the patched card before any merge.
- Open: D3 flags (sky and eased weather not on World; new `flora.cavities`; sparse storage for a 10× planet; felled/burned trees as stored deltas). Band grouping (alpine incl. páramo/puna). Ruin hash differs from the old expected value (predates this session). Earlier entries were dated 2026-09-27 by mistake; corrected to 2026-09-26.

## 2026-09-26 — Spec update: R6, Phases 6–11 (docs only, nothing built)
- Added Appendix R6 (simulation tiers and living-world rules), replaced the old Phases 6–8 with Ecology core, Living populations, and Disturbance and living water (now Phases 7, 8, 9 since the caves renumbering); Camp life gained culture (now Phase 10), Memory and lore is new (now Phase 11), Persistence gained tick_region catch-up (now Phase 12). Part F gained four checks.
- D3 gained: world.events, fauna.genome_mean, fauna.sex_ratio, soil.carcass, flora.burn_scar, terrain.water_level (seasonal), society[camp].culture, creature.memory[] (NEAR only). Owners inferred from the phase cards — designer to confirm.
- Cross-references renumbered: R4 inventory built in Phase 10; R5 out of scope until Phase 12 (numbers since the caves renumbering).
- Still in Phase 0 (awaiting sign-off). Phase 1 ripple + Night Rider + Pond Crawler agents (started on the designer's "GO") are still working in their copies; not merged.

## 2026-09-26 — Phase 0 session 2 (commits 35fdd3a → a213f49) — awaiting sign-off
- Changed: spec R1 replaced + R1a palette added; DESIGN.md matches spec (45/20/35/20, 29.5-day moon). Merged: painted sky (ultramarine night, dense stars, big moon, day #1436FF→#4C7CFF, night fog #1E30C0), flat water (no reflections, no white net, seam line fixed, rivers now flow), R1a ground/stone/fire palette with firelight pool, 1/4 ordered dither, ultramarine haze. Postage-stamp planet (40 km, every band, 3.1 s) ON in data/dev.json; full planet via "postage_stamp": false.
- Verified: tools/p0_timelapse.gd PASS, tools/stamp_check.gd PASS, gl_compatibility no shader errors. Dusk river re-shoot on the full planet: /tmp/shots/p0final_river_{12.0,17.5,18.5,23.0}.png (sent to designer).
- Flagged too clean: day clouds (airbrushed banks), camp folk/fire props/mat (flat colour), far trunks and far hills (texture fades out), mid-distance grass (low-contrast grain), pyramid faces.
- Known misses: stone at night #000963 vs #3E4C8C (night contrast crushes it); folk by fire read red not orange; moonlit snow a little blue/dim; dusk clouds hot pink across upper sky; weak waterfall crests; foliage near-black at night in Compatibility renderer.
- Next: designer sign-off on the dusk river shot, or corrections. Then Phase 1.
- Open: stamp size 40 km? ruins/mythicals on the stamp? band grouping (alpine incl. páramo/puna)? pink dusk clouds OK? warmer #FFA050 fire so folk read orange? ruin hash differs from the old expected value (predates this session's work).

## 2026-09-26 — Phase 0 session 1 (commits a87aee8, 922916b)
- Changed: post grade (dither/black crush out; slight color bleed, cool haze, faint grain; night tint kept), all world textures linear + mipmaps, 3D render scale 0.8. Day split 45/20/35/20 (day/dusk/night/dawn) with smooth sky speed, eased weather-driven light, sun→moon cloud-light crossfade, 29.5-day moon with the mansion following it. Earlier (1993da5, merged before the spec): vertex-lit Lambert, flat ambient, no glow/SSAO/SSR/shadow maps, blob shadows.
- Dev: data/dev.json (20-min day, seed 42, first camp), F3 debug overlay, tools/p0_timelapse.gd (PASS: no frame-to-frame jumps).
- Verified: time-lapse sheet + curves; river-bank shots at 12:00/17:30/18:30/19:30/23:00. Dusk shot NOT yet GameCube-disc quality: water still reflects the sky (pink swirls) and glows neon at night; cloud layers look smeared, not painted.
- Held: set pieces on local branch hold/set-pieces (spec: no new ruins). Painted skybox + flat bright water exist in stopped agent copies (both matched R1 in audit) — designer to decide whether to finish them. Carved stone + old sky: discard.
- Next: fix water (no reflections, softer night glow) and sky/clouds (painted), then re-shoot dusk by the river for sign-off.
- Open: 45/20/35/20 order confirmed? dev day also speeds weather 6x; DESIGN.md still says 15/50/15/40 + 28-day moon; postage-stamp planet not built.

## 2026-09-26 — Spec v3 adopted (aligned to commit fe6ee3e)
- Current phase: **Phase 0 — Look & Light**
- Last sign-off: none yet
- Agents in copies: restyle, set-piece — audit against Appendix R1 before merging
- Next: send Phase 0 Prompt A (spec Part C), get the audit, then "Go."
- Open questions: 51 biomes in data vs 52 in design (resolve in Phase 2)
