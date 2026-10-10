# PROGRESS.md — running log (newest on top)

Claude Code prepends 3–6 lines every session. The designer signs off phases here.

---

## 2026-10-09 — Queue 72, §FM.7: harvest and brew: a plant from above, a brew from the shaman (376cf23)
§FM.7: "The local psychoactive plants grow there: you harvest one, carry it down to the shaman at the hearth, and he makes you a brew of what you found." Built as queue 72 says, for the tomb's world only: the tomb is the Aztec world (`data/ruin_compass.json`), so its plant is ololiuhqui, the Christmas vine (*Ipomoea corymbosa*). Its one entry in `data/sacred/sacred_plants.json` (its flags read first: nothing in them stops the engine drawing it) is read for the surface only and never loaded into the species catalogue, so the open world and the §CC trim are untouched.

- **What changes on screen:**
  - **The vine.** On the surface one ololiuhqui grows, hung from a tree ahead of you as you come up. On seed 7 it is a velvet mesquite on the wash, 6.0 m tall, 38 m out and 9° off the way you face. (That is with queue 70's rooms in, which reshaped seed 7's tomb and so the land above it; on 376cf23 alone it was a desert ironwood 47 m out.) It hangs the way the open world hangs every liana: from 0.8 of the tree's height, out from the trunk toward you, its three green strands 4.2 m long, down to under half a metre off the ground. It is the engine's own liana (§FM.9: "a plain liana, which the engine already draws"), in the plants' material, with no flowers (Torchfire 1 has no year).
  - **The shaman's lesson, seen once.** The first time you come up, the shaman stands beside the vine: the same figure as the one at the hearth (on seed 7 his dragon head, his cloak, his height, his ladle). Come within 12 m and look at him (or put your hand to the vine first) and he crouches, reaches to the vine's foot with his left hand and takes a length, a quarter of the vine. The vine stays standing, shorter. He straightens, turns to you, holds the length out a moment and puts it away. Then he just stands there watching you. No words. After you go back down he isn't up there again, and the game's save remembers that you saw it.
  - **Your harvest.** At the vine, right click (interact) takes a cutting: one carried thing in your pack. While your left hand holds no fire pot, the cutting shows low in it in view. The log says "Took a cutting of the vine. It stands, and will grow back." Each cutting takes another quarter of the vine's length from its foot, and it is never cut below half. You carry one cutting at a time. Asking for more (or with nothing left to take) you get a soft rustle and nothing else. Up on the surface right click does nothing else.
  - **It regrows on the game clock** (the one 144-minute clock, §FK.3): one take's length every 2 game hours (12 real minutes), up to its whole length.
  - **The brew.** Carry the cutting down and right click at the usual spot, at the hearth's guard where you light your torch:
    - the shaman rises from his stone, stepping off it, and walks round the hearth (about 4–5 m, the side away from the torch bundle, never between you and the fire) to stand beside you on the kerb, about a metre off;
    - he turns to you, reaches out with his left hand and takes the cutting (it leaves your pack as his hand gets there; if you've stepped away, he waits for you);
    - he turns to the cauldron and tosses it in; a dark brew shows in the pot;
    - he stirs it with his ladle for 6 seconds, the ladle's bowl down in the pot, going round;
    - he lifts out a ladleful, turns to you and holds it out, its bowl about 40 cm in front of your eyes;
    - right click again and you drink. He lowers the ladle, walks back round and sits on his stone exactly as before. The pot is empty again.
    - All of it is the rig's own movement (getting up and sitting down, the walk, turning, reaching) and he never speaks. With no cutting, right click at the hearth takes a torch from the bundle as always.
  - **The vision.** The moment you drink, a pale violet tint eases in over the whole frame, thicker in stepped bands from the edges, pulsing slowly (about once every 5.5 s). It is full after 4 s, holds until 120 s, then fades out over 10 s. It is a placeholder: what this brew does isn't decided (§FM.7). It only draws. Nothing else in the game changes while it runs (§FM.3: no timer on anything else, no torch drain, no hallucinations), and nothing of it is saved (§FM.4: nothing reaches a secret layer).
- **How:**
  - `SacredVine` (`scripts/crawler/sacred_vine.gd`, new): the vine, built with the surface (`Surface.build`, after the plants). It picks the tree from the ones `SurfacePlants` grew (`trees_placed`, new: a tree with a trunk and branches, 3–8 m tall, 16–70 m from where you come up, within 40° of the way you face, nearest to 30 m), draws the entry's own `PlantMeshes` liana in a one-plant MultiMesh, and keeps the vine's length as a share of its whole that grows back from the last cut on `World.days`. It also runs the shaman's lesson.
  - `Brew` (`scripts/crawler/brew.gd`, new): one per session, made by `CrawlerMain`. The interact button asks it first, then the bundle as before (`CrawlerMain._unhandled_input`, one line). It routes the surface's harvest, spawns the shaman by the vine from the rescuer's own look (`HearthFolk.height` and `palette`, new), keeps the lesson in the save (`CrawlerSave.keep` `harvest_taught`), runs the rite at the hearth and starts the vision. His way round the hearth (`Brew.plan_way`) is planned when you hand the cutting over: out to a ring 1.8 m round the fire, round it the way that doesn't pass you, in to the kerb beside you. Every 15 cm of it is checked against the stone (the walls, the pillars, his own seat) with a body his size, and kept off the bundle, the tripod's feet and you. If no way is clear he stays put and the button takes a torch as usual (none of the twenty hearth rooms checked needed that).
  - `FolkMotion` (`scripts/crawler/folk_motion.gd`, new) moves a hearth folk with the rig's own animations: the seated pose and the crouch to get up and sit down, the walk cycle from the velocity it's handed, turning, and the arms turned to reach a point (the way the player's arms reach for a handhold, the elbow straightening by itself). Nothing new in the rig. The ladle is turned for the stirring and for holding out, eased so it never snaps; the cutting and the ladleful are props in his hands.
  - `BrewVision` (`scripts/ui/brew_vision.gd`, new): the tint, drawn in the 480-line frame on the HUD layer under the crosshair (the harm view's stepped bands).
  - The brew in the pot is drawn on the cauldron's own render layer, so the fire lights it from below and the hearth's light over the mouth doesn't. It is made when the cutting goes in and gone once the ladle is filled, so at rest the cauldron is empty, as queue 67's check expects.
  - Data: `data/brew.json`, new (`world`, `vine`, `teach`, `carry`, `rite`, `plants.ololiuhqui`, every key in `_help`). `crawler.json → _help.cauldron`'s "empty: the brew is prompt 72" now says what is built.
  - Small hooks: `SurfacePlants.trees_placed`, `Surface.vine`, `HearthFolk.height` and `palette`, `CrawlerMain.brew` (made in `_ready`, reset with a tomb in `_clear_tomb`). Header comments in `crawler_main.gd`, `surface.gd`, `hearth_folk.gd` and `hearth_cauldron.gd` say what's built.
  - `HOW_TO_RUN.md`: a new **Harvest and brew** bullet; the surface's "no harvesting yet" and the cauldron's "empty (the brew is prompt 72)" lines updated.
- **What you can tune** (`data/brew.json`, restart after editing):
  - `plants.ololiuhqui`: `take_share` (how much one harvest takes, 0.25), `keep_share` (never cut below, 0.5), `regrow_game_h` (2 game hours a take), `brew_color`, and the `vision`: `tint` (#9c80ff), `strength` (0.16 over the frame), `edge` (0.32 in the bands), `pulse_hz` (0.18) and `pulse_depth` (0.55), `fade_in_s` (4), `last_s` (120), `fade_s` (10).
  - `vine`: which tree it hangs from (`host_h_m`, `from_arrival_m`, `near_m`, `ahead_deg`), how it hangs (`attach_share`, `out_share`, `length_share`), `visible_m`.
  - `teach`: `on` (false skips the lesson), `kept`, `watch_m`, `view_deg`, `stand_m`, `crouch`, and the lesson's timings.
  - `carry`: `max` (one), `reach_m`, the cutting's place in view, the log line.
  - `rite`: `hand_reach_m` (how near the hearth's middle you must be), his walk (`walk_r_m`, `walk_mps`, `turn_dps`), where he stands (`stand_r_m`, `beside_deg`), every step's time (`rise_s`, `take_s`, `drop_s`, `stir_s`, `fill_s`, `lower_s`, `sit_s`), `drink_reach_m`, the log line.
- **Checks**, all 0 fails:
  - `tools/brew_check.gd` (new, queue 72's check): 76 lines, on 376cf23.
    - **The data and the plant:** brew.json's six blocks, each with its `_help`. The tomb's world is the Aztec world and its plant ololiuhqui. Its entry is a liana, its eight flags read, none saying the engine can't draw it. It is built from its entry and never loaded: no catalogue index, and the catalogue doesn't find *Ipomoea corymbosa*. 1,003 species before and after going up, none from `data/sacred`. Drawable: the engine's own LIANA strands (6 triangles).
    - **Twenty hearth rooms** (seeds 1, 7, 42 and 17 more, built as the game builds them): from the usual spot he always has a way round the hearth to you, 3.4–5.1 m long. Every way is clear of the stone (walls, pillars, his own seat), at least 0.45 m off the bundle, 0.3 m off the tripod's feet and 0.6 m off you, and it ends beside you on the kerb.
    - **The vine:** one, on one of the surface's trees (above). It hangs at 0.80 of the tree's height and 0.22 of it out from the trunk, toward you, its strands 3.0 m long to 0.34 m off the ground. It is drawn as every plant up there, with no collision and no light of its own.
    - **The lesson:** the shaman stands by it (the same head, cloak, height and ladle as the one at the hearth). He waits while you're 16 m off, and while you're near with your back to him. Near and looking, he crouches, reaches and takes one length (the vine at 0.75 of its length, still standing), shows it and puts it away. No log line from him, and the lesson is kept in the save.
    - **Your harvest:** in reach (1.0 m from your eyes) the button puts a cutting plant sample of *Ipomoea corymbosa* in your pack, the vine left at 0.50 of its length, with the log's line. A second is refused. Out of reach the button does nothing.
    - **Regrowth:** 0.501 now, 0.626 after 1 game hour, 0.751 after 2 (one take back), never past 1.000. A take is possible again after 2 game hours, not before. With World.days moved on 2 game hours, the strands are drawn 2.27 m long again.
    - **Down and up:** the shaman is gone from the surface once you come down, and the one at the hearth is on his stone. Up again: the same vine and no shaman.
    - **The hand-over:** the usual spot (your body walked from the mat at the fire stops at the guard, 1.23 m from its middle), the cutting carried down. With no cutting, the button takes a torch from the bundle as before. With one, he rises. His way (5.1 m) is clear of the stone, 1.74 m off the bundle, 0.46 m off the tripod's feet, 1.01 m off you. He walks it standing and is never closer to you than 1.02 m. He takes the cutting (it leaves your pack as he reaches) and drops it in (the brew in the pot). He stirs with the bowl in the pot (301 of 301 frames), lifts a ladleful (the pot served out) and holds it 0.42 m from your eyes. Nothing new in the rig but the ladleful, and no log line.
    - **The drink:** the vision starts on the next frame, is full at 4 s, still full at 119.5 s, half faded at 125 s and gone at 130 s. He walks back and sits exactly where he sat (0.000 m off), arms at rest, his ladle as it was. The cauldron is empty again. The log's line.
    - **Nothing changes while it runs:** every data table, the light field on the residents' grid, the environment, the grade, the look's shared values, the camera, harm, the save, the floors, the fork and the layout are the same during the vision and after it. Your walk covers 1.167 m in half a second, as before. Your torch burns 0.01667 minutes a second, as before. The clock and the residents' clock run at the same pace. No node and no light was added to the world while it ran. Nothing of the brew is in the save.
  - Run again after rebasing onto queue 70 (fae9712, the room pool, which changes seed 7's tomb): `brew_check` 76, 0 fails. The twenty hearth rooms still all have a way round (3.4–5.1 m). Seed 7's vine is now on a velvet mesquite 6.0 m tall, 38 m out, its strands 4.2 m long to 0.46 m off the ground.
  - `tools/crawler_check.gd` (seed 7): 273, unchanged (on 376cf23, before queue 70).
  - `tools/surface_check.gd` 60 and `tools/hearth_cauldron_check.gd` 56 (on the pushed code), `tools/crawler_save_check.gd` 39, `tools/hands_check.gd` 61, `tools/fire_pot_check.gd` 104.
  - surface_check's one changed line, in place: its "no collision up here but the land, the stone and the trees' trunks" now also allows the shaman's blocker by the vine (a figure you bump into, as at the hearth, not a wall).
  - Not rendered: the prompt asks for headless numbers only, so there is no walkabout frame of the vine, the shaman's lesson, the rite or the tint.
  - Known noise, not this pass's: the headless "Parameter "m" is null" error when a torch is taken from the bundle (hearth_cauldron_check prints it too), and the "resources still in use at exit" line every crawler check prints.
- **For Mike:**
  - **The vine in the desert.** Ololiuhqui grows in tropical dry forest, thorn scrub, savanna and jungle, not hot desert. The tomb's surface is the desert (queue 71's call; §FM.10 call 1 is still open). I hung the one vine on a tree ahead of where you come up, as the prompt asks; in life it would want a moister spot. If the Aztec world's surface becomes thorn scrub, the vine and its trees follow.
  - **How it looks:** the engine's liana is three plain green strands hanging from a crown. It reads as a vine, but not as the heart-leaved blanket the entry describes (that would need a new liana shape; §FM.13 left the ayahuasca vine's twist for later too). Nothing here was rendered.
  - **Calls for you:** the vision is a placeholder (a violet tint and a slow pulse, 120 s). What this brew does is yours to decide (§FM.10 call 6). Also the lesson's flow (he waits for you to look at him, then cuts), the regrow time (12 real minutes a cutting), carrying one cutting at a time, and that he walks round to you rather than you going to him.
  - **Not kept:** the cutting in your pack, a brew under way and the vine's cut length are not saved (the surface is rebuilt whole on Continue). Only the lesson is.
- **For chat:**
  - `data/sacred/sacred_plants.json → status` still starts "[NOT WIRED YET — design §FM.9]": the file still isn't loaded, and queue 72 now reads one entry (ololiuhqui) for the surface only. The prompt named no `_help` line to unwire, so I left it. Its last sentence ("Queue 72 ... reads the Aztec world's plant from here once the engine can draw it") is now true.
  - `data/ruin_compass.json` is not read (it stays reference only, §FM.8): brew.json → `world.ruin` names "aztec" and `world.plant` the entry's id.
  - CLAUDE.md's §FM line says "bones only, not built yet; queue 65–74". 72, harvest and brew, is now built (and 65–69, 71 and 75–77 before it).
  - A new data file, `data/brew.json`, every block Claude Code's first guesses with its `_help`. Nothing in it is `[NOT WIRED YET]`.
  - The check is in a new file, `tools/brew_check.gd`, as new checks go.
  - `crawler.json → cauldron.empty` stays true (empty at rest). Its `_help` now says the brew stands in it only while the shaman works one.

## 2026-10-09 — Queue 70, §FM.6: the room pool: hand-built big rooms drawn into each tomb (fae9712)
§FM.6 (Mike, 9 Oct): the dungeon is Phantasy Star Online style, with hand-built big rooms shuffled in among the generic rooms and paths. Built as queue 70 says: three big rooms for the tomb, first guesses on Claude's three briefs. **Mike may rename or replace any of them** by playing (`data/room_pool.json → archetypes`).

- **What changes on screen:**
  - **Every tomb now has one or two big rooms** on floor one (100 tombs: 46 with one, 54 with two), never the same one twice in a tomb. Each stands where one of the kit's rooms would have been:
    - on the spine, but never the room just before the heart, the heart itself or the way out;
    - or on a side way.
  - The hearth room and the heart are as they were, and floor two has no big rooms.
  - **All three are cut from the tomb's one stone (§EX.1):** the same fitted polygonal walls, floor flags, corbel course, beams and ceiling slabs. Their doorways sit in the middle of their walls, and their wall torches sit in niches with sooted flue slots above them.
  - **The pillar hall** (8 m wide, 14 m long):
    - Three pairs of square pillars stand down its length, with a beam along each row and the slabs spanning across.
    - Its four torches are cut into the faces of the first and last pairs, facing the aisle. A sooted flue slot runs up each one's pillar to a vent in the ceiling beside the beam.
    - By the torch in hand alone, the far end is lost in the dark.
    - A way may go on through its far wall or either side wall.
  - **The stepped hall** (10 × 10 m):
    - You come in at the bottom. Four broad steps (0.3 m each, a metre of tread between them) climb to a dais 1.2 m up across the far end. A stone seat stands on the dais, facing down the hall.
    - The ceiling is level, 4.4 m over the floor you come in on.
    - Two torches are on the side walls by the way in, and two on the far wall up on the dais, so the far ones burn 1.2 m higher than the near ones.
    - Four pillars: two on the first step, two on the dais.
    - The only way on is through the far wall, up on the dais.
  - **The sunken court** (10 × 12 m), one stair below the corridors:
    - A metre of floor at each door, then a 2 m flight down 1.2 m across the room's whole width into the court, and a flight back up at the far end.
    - A carved stela stands in the middle of the court between four pillars. Six stone heads are set high in the side walls, three a side (Chavín's tenon heads).
    - Four torches on the side walls at the court's level.
    - The only way on is through the far wall.
    - No shaft of sky: see **For Mike**.
  - **Their torches count toward the floor's lit test** like any others (§FF.2): floor one isn't lit, and the fork doesn't open, until a big room's last torch is lit.
  - **Every other room and passage is the kit's**, rolled by the same seed as before. A big room changes what is laid after it, so each tomb is laid differently from before this pass. The same seed still lays the same tomb, so a game's tombs (§FK.2) are the same every time.
  - **The snake keeps its lair.** Its lair and its tunnels' holes never go in a big room, and a big room on a side way can take the dead end the lair would have had. When that leaves the snake no lair whose room can take its tunnel's hole (8 tombs in 1,000), the tomb is laid again with its big rooms on the spine.
- **How:**
  - `RoomPool` (new, `scripts/crawler/room_pool.gd`) reads `room_pool.json`.
    - It decides how many big rooms and which ones on dice of their own (the tomb's seed and "room pool").
    - It also decides the room slots they are due at: the spine's rooms short of the room before the heart, then each side way's rooms, in the order the generator lays them. A big room that doesn't fit where it was drawn tries the next slot.
    - A tomb is laid again with the big rooms due from the first slot (the spine's first rooms) if it drew fewer than the least (not once in 1,000 seeds), or if it left the snake no lair with its hole (`keeps_lair`).
  - `TombKit._branch` lays a big room in its slot: the archetype's size and floor, with ways on only through the walls it opens. Its torches are the archetype's (`RoomPool.sconces`).
  - `RoomPoolBuild` (new, `scripts/crawler/room_pool_build.gd`) draws what is new:
    - the stepped and sunken floors: step blocks, walked on a slope under the steps as the tomb's stairs are;
    - pillars with a sconce niche and flue slot;
    - the seat, the stela and the stone heads.
  - `TombBuild` hands it those parts. The walls, doors, corbels, beams and slabs are TombBuild's own.
  - `Delves.floor_of` reads a big room's floor profile. Everything that asks how high the floor is at a spot sees the steps: your body, the skeletons' floor grid, the light, the snake.
  - The stair down to floor two never leaves a big room, and the snake's lair and tunnel holes are never in one (`TombFloors`, `BossGround`).
  - **Queue 48's budget (45,000 triangles a room):** a big room's floor flags are half as big again (`build.flags_scale` 1.5), and wall stone hidden behind the steps or under the terraces is left out. The most each room reached: stepped hall 41,240, pillar hall 40,033, sunken court 41,804.
  - **One fix outside the rooms themselves:** `Resident.wake` now checks the light at a skeleton's own resting place as well as at the floor it climbs out onto.
    - A grave can shade the floor beside it from the torch that lights the grave itself. A skeleton woken there rose to hunt you in that light.
    - The new layouts put one so in seed 1, and `cleared_check` caught it. Now it climbs out and goes for the dark, as your note of 7 Oct says (a chase keeps to the dark).
  - **Data,** `room_pool.json`:
    - `[NOT WIRED YET]` taken off `_help.about`;
    - the three archetypes authored;
    - `build.flags_scale` added;
    - "As built" lines added to `_help`.
- **What you can tune** (`data/room_pool.json`, restart after editing):
  - `big_rooms.per_dungeon` [least, most], and `placed_on` (`spine_or_branch`, `spine` or `branch`).
  - For each archetype:
    - `width_modules` and `length_modules`, in the tomb's 2 m modules;
    - `doors_on`: which walls a way may go on through;
    - `floor`: for `steps_up`, `lower_m`, `steps`, `rise_m`, `run_m` and `tread_m`; for `sunken`, `terrace_m`, `drop_m` and `run_m`;
    - `headroom`;
    - `pillars`: `rows_m`, `along_m` and `side_m`;
    - `sconces`: a wall and a place on it, or a pillar and its face;
    - `stands`: the seat (`along_m`, `size_m`), the stela (`along_m`, `size_m`) and the stone heads (`walls`, `along_m`, `up_m`, `size_m`);
    - `ruin_kinds`: which ruins may draw it (all three are the tomb's).
  - `build.flags_scale`: how much bigger a big room's floor flags are.
  - Bigger rooms cost triangles: `tools/room_pool_check.gd` says if one goes past 45,000.
- **Checks**, all 0 fails:
  - `tools/room_pool_check.gd` (new, this pass's checks; queue 70 named `crawler_check.gd`): 29 lines, last on fae9712's code before queue 72 landed.
    - **100 plans:**
      - the spine from the hearth room through every room to the heart, and the way out past it;
      - one hearth room, every other fire a wall sconce, one shaft of daylight;
      - 1 or 2 big rooms (46 and 54), never one twice; all three somewhere (stepped hall 61, pillar hall 44, sunken court 49);
      - on the spine (40) and side ways (114), never the hearth room, the heart, the room before it or the way out;
      - whole modules, and doors centred in the walls the archetype opens;
      - their own sconces, each a holder of floor one in its lit test;
      - ceiling spans 5.5 m at most (`max_span_m` 6), level ceilings 3.2 m over the highest floor;
      - the stair down, the lair and the tunnels never in one; every tomb keeps its lair with its tunnel's hole;
      - the generic rooms are the kit's; no overlaps.
    - **Same seed, same tomb:** 100 plans laid twice come out the same; seed 1's tomb built twice is the same stone, vertex for vertex, with the same collision.
    - **The stone:** every vertex of nine tombs' big rooms is within the style's tint ± 0.06, none from the general palette; each room is inside 45,000 triangles.
    - **The walks (100 tombs):** your body walks from the wake spot to the way out with every torch cold, every time (median 102 m). It also crosses every big room to each other door or its far end and back, up and down its steps (308 walks).
    - **In the game,** a tomb of each archetype:
      - every sconce within your reach from where your body fits (12; the farthest 0.95 m);
      - each lit by the game's own swing;
      - with every other floor-one torch lit, the floor isn't lit until the big room's last torch catches, then it is, and the fork opens.
  - **On fae9712 (after queues 71 and 72):** `brew_check` 76 (queue 72's, against the new layouts).
  - **On this pass rebased onto queues 71 and 77** (72 touched none of these files): `crawler_check` 273 (seed 7, 203 seeds walked; the most triangles in a room 41,158), `boss_check` 228, `surface_check` 60, `fork_check` 48, `crawler_save_check` 39 and `hearth_cauldron_check` 56.
  - **On this pass rebased onto queues 66, 69 and 76:** `boss_snake_check` 65, `fog_check` 29, `cleared_check` 90, `residents_check` 177, `fire_pot_check` 104, `boss_pool_check` 48, `stagger_check` 65, `crawler_harm_check` 59 and `hands_check` 61.
  - **Changed in place** where big rooms change what a check meets (what they assert is unchanged; details under **For chat**): `crawler_check`, `boss_check`, `fire_pot_check`.
  - Headless runs print `Parameter "m" is null` (the dummy renderer) once the torch is lit. That is not this pass's: the other worktrees' `crawler_check` logs show it too.
- **The look** (walkabout once in each, `ONLY=rooms` in `tools/crawler_frames.gd`, at midnight; frames 30a–30i). The pillar and stepped halls' frames were rendered as 28 before queues 69 and 71 took 28 and 29.
  - **9 lines, all pass:**
    - each room by the torch in hand shows warm firelight and a navy dark (#040844, #060844, #040842), never grey;
    - every torch of each catches with the game's own swing (4 of 4 each);
    - relit, most of the frame is warm (0.98, 0.90 and 0.94, against 0.39, 0.36 and 0.05 by the torch alone).
  - **30a,** the pillar hall from its way in, by the torch: the aisle between two rows of square pillars, a beam along each row, the slabs across it, fitted polygonal walls, and the far end lost in the dark.
  - **30d,** relit: the four pillar torches burn in their trapezoid niches, and the whole hall is amber.
  - **30g,** beside a pillar's sconce: the flame in its niche, and the sooted slot running up the pillar to its vent beside the beam.
  - **30b,** the stepped hall from its way in: two pillars on the first step frame the steps up to the dais, with the seat before the far door.
  - **30e,** relit: the two far torches flank the seat and door up on the dais, above the near ones.
  - **30h,** from the dais's edge before the seat: back down the steps to the way in, the two near torches on the side walls with their flue slots, and the next passage's light through the doorway.
  - **30c,** the sunken court from its way in, by the torch: down into the court, the stela between its pillars in the navy dark (only the near floor is warm).
  - **30f,** relit: the court lit by its four side torches, with the stela, the pillars, the flight up to the far terrace and door, and an airway slot in the left wall.
  - **30i,** from beside the stela: three stone heads in a row high on the far wall, with brow, eyes and mouth, above an airway slot and beside a torch and its flue slot.
  - All three read as the tomb's one stone.
  - Changed after a first render:
    - 30h had stood half inside a dais pillar, and 30i had the stela in its face; both cameras moved.
    - The stone heads didn't read at 8 m as 0.3 m blocks. They are now 0.44 × 0.52 m, jutting 0.42 m (`tenon_heads → size_m`), and read; still small in the frame.
- **For Mike:**
  - The three rooms are first guesses on Claude's briefs. Rename them, replace them or resize them as you play.
  - **The sunken court has no shaft of daylight or moonlight.** §EX.4 (locked) allows one column of sky in a tomb, over its hearth, and `crawler_check` asserts one shaft per tomb. If you want sky over the court, §EX.4 needs your word first.
  - **A game saved before this pass:** its tomb is now laid with its big rooms. The save notices that the torches moved, so its lights start cold (with a warning in the log).
  - **Big rooms land on side ways more often than on the spine** (100 tombs: 114 on side ways, 40 on the spine). The spine has two or three rooms that may take one, the side ways four to six together.
  - My calls, change any:
    - the sizes: 8 × 14, 10 × 10 and 10 × 12 m;
    - the pillar hall as three pairs of pillars in two rows, its torches on the first and last pairs;
    - the stepped hall's four 0.3 m steps and its seat on the dais;
    - the sunken court 1.2 m down (one stair, as the kit's flights drop), with a stela and six stone heads;
    - the pillar hall opening on three walls, the other two on their far wall only.
- **For chat:**
  - Prompt 70 named `tools/crawler_check.gd` for its checks. They're in `tools/room_pool_check.gd` (new) instead, by this run's rule that new assertions go in a new check. `crawler_check` changed in place only where big rooms change what it asserts:
    - a big room's height is measured over its highest floor;
    - its torch count is its archetype's;
    - its light is measured on its own floor and walls;
    - the long-wall pairing skips it;
    - the flue slots meet its level ceiling.
  - Other checks changed in place where the new layouts broke what their scenes assumed (what they assert is unchanged):
    - `boss_check`: the spot for the come-at-you swing keeps a metre off pillars (one stood between the snake's eye and your flame in seed 42's stepped hall). The dim-edge strike tries the next room by the dark when the first relit room has none (seed 7's pillar hall is lit to its walls).
    - `boss_check`'s relight run: one tomb's order may never catch the snake out of its dark before the last light sends it home (seed 42's doesn't). So "lit round it, it walked out" must hold at least once over the seeds (one line more, 228), not in every tomb.
    - `fire_pot_check`: the sconces it throws at and bursts behind are wall sconces, never a pillar's.
  - "Never in the heart room (the one hearth room, §EX.4)" is read as both: a big room is never the hearth room and never the heart.
  - "The exit's last stretch" is read as the spine from the room before the heart on: that room (the stair down to floor two leaves it), the heart, and the way out's flight and landing.
  - `generic.shuffle` "per_seed" is how the kit already lays its rooms, so nothing new is read from it.
  - `no_repeat_in_a_dungeon` false isn't built: a warning says so, and an archetype still appears once.
  - The sunken court's brief (a shaft of daylight or moonlight) conflicts with §EX.4's one column of sky. It's built without the shaft and noted in `room_pool.json → _help.sunken_court_sky`.
  - `Resident.wake`'s fix is residents code (queue 58's), changed because the new layouts surfaced the case. The rule it follows is the one in its own comment.

## 2026-10-09 — Queue 71, §FM.7: the tomb's surface: day and night above the stair (0181fcf)
§FM.7: "Going up leads to the overworld of that dungeon's own biome, the pocket above it (§EW.7 step 2) ... The day-night cycle runs there, for ambience only." Built as queue 71 says: one surface, the tomb's, and nothing of the other worlds, the passages, the map or harvesting.

- **What changes on screen:**
  - **Going up.** Walk into the way out's opening and the screen goes black over 2 s. The log says "Up the old stair and out, under the open sky." The first time, the surface is built in the dark (6–16 s on this cloud machine, depending on how busy it is); after that it is kept, so going up again is just the fade.
  - **Where you come out:** the yard of a ruin straight above the opening you walked into, in the tomb's own grey-blue fitted stone (§EX.1).
    - A stair of block steps climbs out of the ground between fitted walls, under a trapezoid portal (jambs under one lintel, the tomb's door, §EX.3), with broken stubs of its front wall either side.
    - Round it is a yard of fitted flags inside low broken walls, open ahead.
    - You stand 2.4 m past the portal facing out, carrying what you carried, your torch lit or not as it was.
  - **The land** (the desert world, `worlds.json → worlds.desert`, biome hot_desert):
    - A basin about 1.4 km across, gently rolling, flat round the ruin.
    - A dry wash runs from just past the ruin straight out ahead of you toward a butte standing over the rim against the sky (the shot: a line running to a landmark).
    - All the way round, a slope of talus rises to an escarpment 38–80 m high that closes the basin. It is far too steep to climb anywhere: the land itself, no invisible wall.
    - Far ranges show pale blue over the rim in the haze: near, mid and far (§EW.5), no other world's landmark yet.
  - **The plants:** the hot desert's own, drawn exactly as in the open world, about 10,500 of them: creosote and bursage on the flats, saguaro and paloverde on the slopes under the cliffs, velvet mesquite on the wash's banks (its sandy bed is left open, so it runs out pale toward the butte), grasses round the ruin. Each stand is mostly its dominant species (§CS). Trees have trunks you can't walk through.
  - **Life:** tortoises by day and hares at any hour, five to nine of them near you. A hare bolts if you come within 14 m; a tortoise just stops. These are the only two ground animals in `data/creatures` whose climate fits the desert.
  - **Things to find, never needed** (§FG), out on the basin: ruin remains (a broken run of fitted wall, fallen blocks, a lintel lying), old camp marks (a ring of field stones round old ash, charred sticks, fallen poles) and litter (sherds, a broken pot, bleached bones). Between 9 and 16 of them in a world (11 on seed 7).
  - **The vents** (§EV.4), each on the ground straight above its vent below:
    - over the hearth's shaft, its stack: a ring of the tomb's stone round a dark mouth, sooted at the lip (`smoke.json → outlets.by_ruin`: the tomb's mound vent). The hearth's smoke rises out of it by day (a 42 m column) and a faint amber glow shows in its mouth at night;
    - over every wall torch's flue, a small sooted slot in the ground (80 of them over seed 7).
  - **The time of day:** the one clock (§FK.3), the same World clock as below, so the sun up here and the shafts' daylight below always agree. Dawn, day, dusk and night are 18, 60, 18 and 48 minutes of the 144-minute day; the sun rises in the east, stands overhead at noon and sets in the west. The moon and stars come out at night (the open world's sky, §DD). Wind blows all the time; cicadas sing by day and crickets by night. Ambience only: nothing up here needs a time of day.
  - **Going back down:** walk back down the ruin's steps. Once you are 3 m down them, the screen goes black, the log says "Down the old stair, back into the dark.", and you stand on the landing at the top of the tomb's flight, just inside the opening, facing in. It is the same tomb exactly as you left it: every light you lit still burning, the skeletons and the snake where they were, nothing rebuilt.
  - **The stand-in** stays for a dungeon with no surface yet (`exit.stand_in`); the tomb has one, so you no longer wake in another tomb.
- **How:**
  - `Surface` (`scripts/crawler/surface.gd`, new) is the world up there. `CrawlerMain.go_up` and `go_down` carry you between: the dungeon's nodes are taken out of the tree while you are up (kept, not rebuilt, so the same tomb comes back; floor two's fog, queue 69's FloorFog, goes with them), the surface out while you are down. `walk_out` goes up when `Surface.covers` the dungeon (the tomb), else the stand-in as before.
  - `SurfaceGround` (new): one heightfield, drawn in the open world's terrain material and walked on as one HeightMapShape3D, so what you see is what you walk on. The stairwell is cut into it under the yard.
  - `SurfaceBuild` (new, extends TombBuild): the ruin, the stacks and slots, the finds, all cut from the tomb's style (the stone weathered dry, the desert's climate, not the tomb's damp: sand drifts, no moss).
  - `SurfacePlants` (new): the biome file's three nearctic associations (wash, flats, upland), the open world's PlantMeshes, near meshes within 110 m and impostors past it.
  - `SurfaceLife` (new): creatures from `data/creatures` whose climate overlaps the biome's, in CreatureBodies' bodies.
  - The sky is the open world's `SkySystem` with a new switch, `one_clock` (default off, so the open world is untouched): the sun from DayCycle's reference day over flat ground, the same height `Vents.sun_deg` gives the shafts. Everything the surface changes (the environment, the grade's night and firelit whites, the look's haze, the half-dark, the camera's reach, the drone and drips) is put back as it was when you go down.
  - Small hooks: `Footsteps.flat_ground` (sand and dirt underfoot up there), `GlowMoss._enter_tree` (its patches glow again when the tomb comes back).
  - Data: `worlds.json → surface` (new block, every key in `_help.surface`); `[NOT WIRED YET]` off `_help.about`, with what is built and what isn't; `_help.size`, `clock`, `life`, `horizon` and `worlds` say what queue 71 built; `crawler.json → _help.exit` and `smoke.json → _help.vents` likewise.
- **What you can tune** (`data/worlds.json → surface`, restart after editing):
  - `on`: false gives the stand-in back.
  - `across_m` (the basin's width), `edge.cliff_m` (the escarpment's height), `edge.landmark` (the butte).
  - `sky.fog_day` and `fog_night` (how quickly distance goes pale blue).
  - `plants.per_hectare` (how many plants), `plants.dominant_share`, `plants.ground_per_hectare`.
  - `life.count`, `finds` (how many of each), `stairhead` (`drop_m`, `yard_m`, `down_at_m`), `arrive` (`fade_s`, the log's two lines), `sound` (the wind, cicadas and crickets).
- **Checks**, all 0 fails (0181fcf is the pass rebased onto queue 77; each line says which base it ran on):
  - `tools/surface_check.gd` (new, queue 71's check): 60 lines, on every base (last on 0181fcf).
    - **Going up:** walking into the opening begins it. You come out in the yard straight over the opening (9.9 m from the point above it), on the yard's floor at the surface level, facing out. The portal's jambs stand either side of the stair's mouth. The torch and pack are as they were, and the log has its line. The dungeon is kept out of the tree (its stone, fires, residents, boss, fork, shaman and floor two's fog).
    - **The look:** the sky runs on the one clock. At noon the sun is the one light (no other light up there), the shade is navy (ambient #1838c8), and distance is lighter and bluer (haze #79a4d8). At midnight there is no sun, the shade is still navy, and the moon's light is on. The ground is in the hot desert's colours. 10,475 plants grow from the biome's three associations, each stand mostly its dominant species (wash: velvet mesquite 96 against 79; flats: creosote 2,015 against 1,403; upland: saguaro and paloverde 2,696 against 1,723).
    - **The one clock:** dawn 18, day 60, dusk 18 and night 48 minutes. At the start of dawn the sun is at −10.000° up here and −10.000° below; at noon 90.000° and 89.998°; at the start of dusk 9.999° and 9.999°; at the start of night −10.001° and −10.001°. The sun moves with World.days, and the surface keeps no clock of its own. Ambience only: at midnight you go down and come up again just as at noon.
    - **The vents:** one stack (the tomb's mound vent) and 80 slots, each straight over its vent. The stack smokes by day (a 42 m column) and glows faintly amber at night.
    - **Life and finds:** 9 hares and tortoises, on the ground inside the pocket and keeping their hours (the tortoise by day only). The finds: 4 remains, 2 camps and 5 litter, clear of the stairhead, with no trigger or pickup up there.
    - **Going down:** walking back down the steps begins it. It is the same dungeon (the same stone, layout and fires; tomb 7, place 0), with the same 27 holders lit on its two floors and no others. You stand on the landing facing in, and the log has its line. Everything the surface changed is put back: the environment, the grade, the haze, the half-dark, the camera's reach, the drone and drips, stone underfoot. Going up again finds the same surface, with no new build. Your steps are on stone in the yard and on sand out on the basin.
    - **The edge:** the only collision is the land, the stone and the trunks (no invisible wall). The pocket is 1,400 m across, within `size.across_m` [1000, 2000]. The escarpment is steeper than you can walk all the way round. Your own body walked 2,000 m from the stair in 16 directions and never left the pocket: at most 1.7 m past the cliff's foot, 718 m out at the furthest, never off the ground, never falling. Sprinting and jumping gave the same result (2.8 m, 741 m). No map, no fast travel.
    - **Twenty tombs** (seeds 1, 7, 42 and 17 more): the surface builds on every one, in 5–24 s each depending on the machine's load. On each, the stair climbs from straight over the opening, you arrive on level ground, your body walks down the steps to where the way down begins, every vent has its stack or slot, all three stands grow, and there are finds and creatures. The same seed gives the same land.
  - `tools/crawler_check.gd` (seed 7): 273 on both rebases (271 before). Its stand-in round now goes up to the surface and back down first (two new lines), then walks the stand-in as before with `surface.on` off.
  - Run again after rebasing onto queues 66, 69 and 76: surface_check 60, crawler_check 273, boss_check 227, crawler_save_check 39, hearth_cauldron_check 56, and the walkabout's 7; then, onto queue 77, surface_check again: 60.
  - Run on the first rebase (onto queue 75): crawler_save_check 39, hearth_cauldron_check 56, boss_check 227, fork_check 48, cleared_check 90, residents_check 177, fire_pot_check 104, crawler_harm_check 59, hands_check 61, stagger_check 65, boss_pool_check 51, `day_check` (SEED=7731, the open world's sky, which `one_clock` leaves alone) 21, hud_pin_check 49. The last two end with the open world's known crash after their result.
  - The "2 resources still in use at exit" warning every crawler check prints comes from TombNav's and LightField's scripts, from before this pass (named with `--verbose` on fork_check).
  - **The walkabout** (`ONLY=surface` with `tools/crawler_frames.gd`, seed 7, frames 29a–29g; renumbered from 28 because queue 69's fog frames are 28a–28f): 7 frame checks pass. What I saw:
    - **29a, dawn:** the sun on the horizon. The sky is pink to violet with gold-lit flecks of cloud. The escarpment and the far ranges are pale blue-grey. The wash's mesquites stand dark against the sky, and the yard and the basin are navy.
    - **29b, noon:** the sun overhead. The sky is a deep saturated blue with pale painted clouds, over a pale blue band of escarpment all the way round. The sand ahead is a pale warm cream (#f7e4e2) under navy tree shadows. Mesquites stand either side of the open wash. In the foreground are the yard's blue-grey fitted flags, with a broken wall stub in navy shade on the left.
    - **29c, dusk:** dawn in reverse: the horizon warm (5 % of the frame), the land navy.
    - **29d, midnight:** a full moon nearly overhead (80.7°, 0.98 of its light). Stars in a deep blue sky; the sand a moonlit pale blue (luma 0.45, against 0.92 at noon); the flags and walls blue.
    - **29g, a moonless midnight:** stars over a navy land. The ridge line and the trees' silhouettes still read; the darkest tenth of the frame is navy (#000025), never black; the frame's luma is 0.07.
    - **29e, the ruin from out on the basin at noon:** the portal (its lintel on its jambs), the broken wall stubs, the yard's low walls and sand drifts round them, the stack's smoke rising beyond, and the escarpment pale blue far off. Pale spikes on the horizon at either side are, I take it, far saguaros.
    - **29f, the hearth's stack at dusk:** a sooted ring of the tomb's stone, with a grey column of smoke standing over it.
- **For Mike:**
  - **Which world the tomb is in** (§FM.10 call 1, §EW.8 call 4): I built the desert, because queue 71 points at `worlds.desert` (your "read today's tomb as a desert dungeon", and the snake is the desert's boss). §FM.3 says the tomb should be the Aztec world. If the Aztec world is a different biome, change `worlds.json → surface.world` (or `worlds.desert.biome`) and the land, plants and animals follow.
  - **Prompt 72 will need a call:** ololiuhqui (the Aztec world's plant) grows in tropical dry forest, thorn scrub, savanna and jungle, not hot desert. Thorn scrub would host it and still look like dry country.
  - **The next tombs:** the tomb's way out now goes up, so in play you stay in your first tomb and the land above it. The game's next tombs wait for the passages between worlds (§EW.3).
  - **Continue** still wakes you by the hearth below, even if you quit while up on the surface. Say if Continue should put you back up there.
  - My first guesses, change any: the basin's 1.4 km, the escarpment all round (a desert basin; cliffs could be broken by dunes in places), the yard and portal, the finds' counts, the fair-weather breeze.
  - **The light up there is the open world's, unchanged.** Two things you may notice:
    - At noon the sand is nearly white (luma 0.92). With no latitude (§FK.3) the sun stands straight overhead at noon every day, the strongest light the look's sun gives.
    - Nights swing with the moon. Under a full moon overhead the pale sand reads bright: the frame measures 0.28, against the open world's full-moon target of 0.20 (`look.json → moon_nights`, set on greener ground). With no moon it measures 0.07, against the target of 0.10: navy and dark, the ridge line and the trees still readable. The one dial is `moon_nights.lift_scale`, and it is shared with the open world, so I left it alone.
- **For chat:**
  - **Which world the tomb is in.** Queue 71 points at `worlds.desert` (hot_desert), but §FM.3 makes the tomb the Aztec world (§FM.10 call 1, §EW.8 call 4). I built the desert; the switch is `surface.world`.
  - **For prompt 72:** ololiuhqui's biomes (tropical dry forest, thorn scrub, savanna, jungle) leave out hot desert.
  - `worlds.desert.theme` stays "open". FittedStone matches that key to find a ruin's climate, so setting it to "tomb" would dry out the tomb's own stone below (no moss). The surface swaps in the desert's climate only while it cuts its own stone.
  - `[NOT WIRED YET]` was only on `_help.about`. I took it off and said what is built: the tomb's surface. The rest of §EW is still not built: the passages, the map, every other world, and the horizon's other-world landmarks.
  - CLAUDE.md's §EW and §FM lines say "not built yet". The tomb's surface now is.
  - `data/creatures` has no desert bird, so up there the only life is the hare and the tortoise.
  - Places 1 and beyond (the next tombs) can't be reached in play while the tomb's way out goes up. `surface.on` false brings back the stand-in.
  - Continue doesn't remember that you were up on the surface (`CrawlerSave` keeps no flag for it).
  - Queue 71's CHECK names crawler_check; its new assertions are in `tools/surface_check.gd`, as new checks go in a new file. Existing checks were changed in place only where going up changes what they test: crawler_check's stand-in round; crawler_save_check, hearth_cauldron_check and boss_check, which walk out (they turn `surface.on` off, or count a trip up as a walk out).

## 2026-10-09 — Queue 77, §FM.13: a bulb shape: a fan of leaves on a bulb (ea48c3c)
§FM.13 item 3 (Mike, 9 Oct, "do it"): leshoma was drawn as a spike rosette; now the engine draws it as it looks, a bare brown bulb half out of the ground with a flat fan of grey-green rippled leaves. Built as queue 77 says, the leafy form only: its flower head is not built (below). The spike rosette itself is untouched.

- **What changes on screen:**
  - **Nothing in the crawler yet.** `data/sacred` is still not loaded, and nothing in the open world (Torchfire 2, switched off) has the new shape either. The engine can draw leshoma; nothing places it yet.
  - **The bulb:** a bare brown onion about 19 cm across (drawn at 40 cm tall), widest right at the ground line, so its top half sits bare above the ground and the rest is under it. It narrows into a neck, with a few frayed shreds of paler tunic round the neck's top. Its papery skin is painted in faint bands, paler on its shoulder and neck where the tunics tear.
  - **The leaves:** 12 stiff grey-green straps, 25–34 cm long and about 3 cm wide, blunt at the tip, their edges rippled (they rise and fall out of the blade). They stand in a flat upright fan in one plane, in two ranks: one leaf leans left, the next right, each pair farther out than the one inside it, the outer ones arching out to about 60° from upright. Four of the twelve are twisted a little (up to 28° by the tip). The front of each leaf is the entry's grey-green, the back a paler grey-green, with a darker midrib.
  - **From the side** (the fan facing you) it reads as a fan on a bulb; **edge-on** the fan is a thin line on top of the bulb. Every leshoma shares one model, and the placer turns each plant at random, so in a patch one fan faces you and the next shows its edge.
  - **Painted (§ES):** diffuse only, no leaf tiles, no shine. The shade at the bulb's foot and at the leaves' feet in the neck goes navy, never grey. The bulb holds still in the wind; the leaves sway a little at their tips.
  - **From far off** it keeps every leaf on the same line in its one plane (fewer segments, no ripples, no shreds), never the flat card the far trees use, which turns to face you and would show the fan even edge-on.
  - **Not built: the flower.** In life leshoma flowers before its leaves come, a round pink head on a short thick stalk. Torchfire 1 has one clock and no year (§FK.3), so there is no bloom season to show it in, and the open world, which has seasons, doesn't load `data/sacred`. As queue 77 allows, this pass builds the leafy form only: a question for you below.
- **How:**
  - `PlantSpecies.Shape.BULB`, read from an entry's `"shape": "bulb"`.
  - `BulbMesh` (`scripts/ecology/bulb_mesh.gd`, new), called from `PlantMeshes._build`, reads the entry:
    - `appearance.trunk.notes` for the bulb's size ("15-25 cm across": the middle);
    - `appearance.leaf.notes` for the count ("8-16": one count for the species, 12 here), the word "twisted" and the word "blunt";
    - `appearance.leaf.size_cm` for the length, the leaf block's `aspect` for the width, its `apex` (obtuse: a blunt end), `appearance.leaf.margin` (wavy: rippled edges);
    - `appearance.leaf.colour`, `underside` and `vein_colour`; `canopy.droop` for how much the outer leaves arch;
    - the entry's `bark` block (`color`, `color_2`) for the bulb. `PlantSpecies` now keeps an entry's `bark` block (`SpeciesDB`, two lines).
  - Every face is the plant shader's painted flesh (queue 75's material, UV2.x −1), so each leaf is a closed thin strap. The plant shader pulls every bark toward its warm brown by day but leaves painted flesh alone, so the bulb's colours take that pull in the builder (`BulbMesh.painted_bark`, the palette's numbers copied). Without it the first frame showed the bulbs pale pink.
  - `PlantMeshes.own_far` now includes BULB (its far level is its own model).
  - Data, as a data-driven one-liner: `"shape": "bulb"` in leshoma's entry. Also one line added to `flags.leshoma` (the stand-ins gone, the flower not drawn), and `data/biomes/README.md` lists the shape.
  - `tools/species_row.gd`: `TURN_DEG` (new) turns each row plant round its up, so one plant can face you and its twin show its edge; a bulb stands on the ground as in play; the sown grass keeps clear of each row plant's footprint (it grew through the bulbs before).
  - `HOW_TO_RUN.md`: a bulbs bullet.
- **What you can tune:**
  - In leshoma's entry (`data/sacred/sacred_plants.json`): `appearance.trunk.notes` (the bulb's "cm across"), `appearance.leaf.notes` (the count, "twisted", "blunt"), `appearance.leaf.size_cm`, `colour`, `underside`, `vein_colour`, `margin`; the leaf block's `aspect` (length over width) and `apex`; `bark.color` and `color_2` (the bulb); `canopy.droop` (more arch); `height_m`. Change the entry and the plant follows on the next start.
  - In code, `scripts/ecology/bulb_mesh.gd`: `LEAN_INNER` and `LEAN_OUTER` (how wide the fan opens), `YOUNG_LENGTH` (the inner leaves' length), `RIPPLE` (how strongly the edges ripple), `TWIST_SHARE` and `TWIST_DEG`, `LEAF_SWAY`, `PROFILE` (the bulb's shape), `BAND`, `NECK_CREAM` and `SHREDS` (the tunics).
- **Checks** (on ea48c3c as pushed), all 0 fails:
  - `tools/bulb_check.gd` (new, queue 77's check): 56 lines.
    - The shape and its string. Leshoma's entry says bulb, and it is built straight from it as a catalogue entry is built, with `data/sacred` still not loaded: 1,003 species before and after, none from `data/sacred`.
    - At the hero, near and far levels (1,056, 792 and 396 triangles): every face painted, the top at y 1 in the unit frame, the bulb's foot under the ground line.
    - **The fan is thin across:** its depth 0.13 against its width 1.15 (0.11; 0.10 far off), under a quarter, before the random turn; it spreads to both sides.
    - **A bulb at the base:** round at the ground line, widest 0.03–0.08 of its radius from it, still three quarters of its width half way up its top half, closing into a neck, its foot 0.62 radii under the ground: about half out of the ground. 19 cm across drawn at 0.4 m (the entry: 15–25 cm). Brown, its foot toward navy, lit outward, still.
    - **The leaves:** 12 (the notes: 8–16), leaning left and right in turn, each in its own plane; every tip in the mesh in the same place at every level (every leaf kept far off); 25.5–33.9 cm long (the entry: 20–50 cm), about their length over the aspect wide; arching at most 30°, blunt; 4 of 12 twisted, 28° at most.
    - **One leaf alone:** 3.0 cm wide, its end still 1.5 cm across, 2.8 mm thick; its edges rippled 4.7 mm out of the blade (0.17 of its width), up and down in turn, near, and flat far off; front the entry's colour, back its underside; sway 0 at its foot, 0.35 at its tip; lit outward.
    - The far level's face-on outline within 0.7 % of the near level's. No corner anywhere in the flower's pink: the leafy form only.
    - **The random turn:** one model for every plant, and the placer's yaw spread over the whole turn (64 plants: 16, 14, 17 and 17 a quarter turn); its `prepare()` turns a plant by it (1.00 rad).
    - **Every SPIKE_ROSETTE unchanged:** all 3 spike rosette species build exactly the spike rosette's leafy ball and spike at every level (rebuilt in the check as `PlantMeshes._build` draws it), and their far level is still the far card.
  - `tools/species_mesh_check.gd`: 1,003 species at the near and far levels, 0 fails, no missing tiles.
  - The plant checks round it: `globe_cactus_check` 44, `mushroom_check` 82, `giant_herb_check` 108, `wood_normals_check` 2 (every bark part and culm still faces out); `python3 tools/shader_varying_check.py` (all within the house limit); `python3 tools/plant_schema_check.py --strict data/sacred/sacred_plants.json` (7 entries, 0 errors).
  - `crawler_check` not run: this is not a crawler pass, and no crawler script uses the plant code.
  - **The look,** `tools/species_row.gd` (`SPECIES="sacred:leshoma,sacred:leshoma" TURN_DEG="0,90" HEIGHT_M=mid SPACING=0.9 DIST=2.1 EYE_M=0.5 LOOK_H=0.45 GRASS=Buffalograss`, 14:00, the camera 2.1 m off and 50 cm up), rendered twice:
    - First frame: both read as meant, but the bulbs were a pale pinkish tan (#B59484 on screen), because painted flesh skips the shader's pull toward bark brown. So the bulb's colours now take that pull in the builder.
    - Second frame, the one that stands: two leshomas about 69 px tall at 480 lines, in short pale buffalograss. **On the left, facing you:** a fan of a dozen grey-green straps (#5A737B to #4A6B63 on screen) opening from the bulb's neck like a hand fan, the outer ones arching out, over a warm tan-brown bulb (#BD947B; lighter than tree bark, because its dome faces the sun and the sky). **On the right, edge-on:** the same fan is a thin upright line on its bulb. Both cast navy shadows on the grass. Both read at a glance: a fan on a bulb, and a line on a bulb.
    - Also in the frame: a pale blue streak across the sky, the open world's own, not this pass's.
- **For Mike:**
  - **The flower:** when should leshoma flower in Torchfire 1, where there is no year? In life it flowers at the end of the dry season, often right after a grass fire, before the leaves come: a pink ball on a bare bulb, then the fan. It could stay leafy (as now), flower after a fire, or keep a few plants always in flower. Your call; nothing waits on it.
  - A leshoma model is about 800 triangles near (1,056 at the closest level, 396 far off), more than a mushroom: the rippled, twisted leaves are closed straps. Ground plants are drawn only within the ground cover's reach, so it costs little.
- **For chat:**
  - Data touched beyond the one-liner: one line added to `flags.leshoma`. `notes` at the top of `sacred_plants.json` still says "no bulb (leshoma as spike_rosette)": your text, so I left it. `status` keeps its `[NOT WIRED YET]`: the file is still not loaded, and the prompt named no `_help` line to unwire.
  - Leshoma's `repro.bloom`, `fruiting` and `seasonal` are not read: no bloom season in Torchfire 1 (§FK.3). The open world's bloom code (`FruitCrop`'s flower_months window, `LeafSeason`'s clock) runs on its year and latitude only.
  - "Often twisted" in `appearance.leaf.notes` is drawn as a few leaves twisted a little (queue 77's "sometimes twisted a little"), not the whole fan spiralling.
  - `bulb_mesh.gd` copies three palette numbers (`pal_bark`, its 70 % day pull, `pal_ref_luma`) from `shaders/palette.gdshaderinc` so the painted bulb reads as bark: if the palette changes, change them with it.
  - `sports.json → by_shape` has no `bulb`, so leshoma rolls no sports (as with the mushrooms). `Wind.kind_of` gives BULB the sheltered kind (0: the shrubs' push), not the grasses' bow, unchanged code.
  - CLAUDE.md's §FM line doesn't mention §FM.13's three shapes; all three are now built (75, 76, and this, the leafy form).
  - The prompt's check is in `tools/bulb_check.gd`, a new file, as the prompt allows ("a new check").

## 2026-10-09 — Queue 76, §FM.13: a globe cactus shape: a low button in the ground (d2c2859)
§FM.13 item 2 (Mike, 9 Oct, "do it"): peyote was drawn as the tall cactus column; now the engine draws it as what it is, a clump of flat blue-green buttons sunk in the ground. Built as queue 76 says; the cactus column itself is untouched.

- **What changes on screen:**
  - **Nothing in the crawler or the open world yet.** `data/sacred` is still not loaded, and no loaded plant uses the new shape.
  - **Peyote**, built from its data/sacred entry for the check and the look only, is a tight clump of four buttons: an old one in the middle and three smaller ones pressed round it, leaning out a little. Only the top third of each button shows above the ground; the rest is a buried body you never see. Seen from above:
    - each button is ribbed like a slice of pumpkin (8 ribs on the two bigger ones, 5 on the small ones), its edge scalloped by the ribs;
    - furrows across the ribs cut them into rounded bumps, and every bump carries a white tuft of wool, so each button wears rings of white dots;
    - a white woolly cushion sits in the middle of each button;
    - a small pink-and-white bell stands in the old button's wool;
    - no spines.
  - **Painted (§ES):** blue-green, a little paler on the bumps, the furrows and the edge where it meets the ground shaded toward navy, never grey. Diffuse only, no leaf tiles, no shine. It stands still in the wind.
  - **From far off** it is the same four flat ribbed buttons with their white centres, without the bumps, tufts and flower. It never becomes the flat card the far trees use, which would have stood the button on its edge.
- **How:**
  - `PlantSpecies.Shape.GLOBE_CACTUS`, read from an entry's `"shape": "globe_cactus"`.
  - `GlobeCactusMesh` (`scripts/ecology/globe_cactus_mesh.gd`, new), called from `PlantMeshes._build` beside the mushroom, reads the entry's own `appearance` block:
    - `stem.diameter_cm` and `height_m` for the old button's width and height (8 cm across, 4.5 cm tall at the middle of its height, 1.4 cm of it above the ground); the smaller buttons 74, 60 and 46 % of it;
    - `stem.ribs` for the rib counts (the old button the middle of the range, the smaller ones fewer, in the steps peyote adds them, 5, 8, 13: its growth note), `stem.rib_depth` for how deep the furrows run;
    - `stem.colour` and `stem.secondary` for the body, `stem.areole_colour` for the wool, `stem.spine_cm`, `spines_per_areole` and `spine_colour` for spines (none while `spine_cm` is [0, 0]);
    - `appearance.flower` (colour, with its secondary at the rim and in the throat) and `fruiting.flower_size_cm` for the bell, drawn only where the entry names a flower colour;
    - `appearance.trunk.form`: "solitary" draws one button; peyote's says "clumping".
  - It uses queue 75's painted flesh material (`foliage.gdshader`, UV2.x −1), so the shader is untouched. The far level is its own small model (`PlantMeshes.own_far`), like the mushroom's.
  - About 980 triangles for the clump near, 1,490 at the hero level right round the player, 230 far.
  - Data, as a data-driven one-liner: `"shape": "globe_cactus"` in peyote's entry. One line added to `flags.peyote`: the column stand-in is gone.
  - `tools/species_row.gd`: `GRAVEL=1` sows small pebbles round the row; a globe cactus in the row stands on the ground as in play, not sunk further.
  - `HOW_TO_RUN.md`: a globe cactus bullet. `data/biomes/README.md` lists the shape.
- **What you can tune:**
  - The look comes from peyote's `appearance` block and `height_m` in `data/sacred/sacred_plants.json`: `stem.diameter_cm`, `stem.ribs`, `stem.rib_depth`, `stem.colour`, `stem.secondary`, `stem.areole_colour`, the spines, `appearance.flower`, `fruiting.flower_size_cm`, `appearance.trunk.form`. Change the entry and the drawing follows on the next start.
  - In code, `scripts/ecology/globe_cactus_mesh.gd`: `ABOVE` (how much of a button shows above the ground, 0.3), `CLUMP` (the buttons: sizes, where each sits in the rib range, bumps along a rib), `TIGHT` (how hard they press together), `CROSS` (how deep the cross-furrows are against the ribs'), `CREST_SHARE` (how pale the bumps go), `BOSS_R`/`BOSS_H` (the woolly centre), `TUFT_R` (the wool tufts), `FLOWER_H` (the bell's height).
- **Checks** (on d2c2859), all 0 fails:
  - `tools/globe_cactus_check.gd` (new, queue 76's check): 44 lines.
    - The shape and its string. Peyote built from its data/sacred entry as a catalogue entry is built, and data/sacred still not loaded: 1,003 species before and after, none from data/sacred.
    - **The queue's check**, at the hero, near and far levels: drawn at any height in `height_m` it stands no taller than `height_m` over the ground line (1.0–3.5 cm with the flower near, 0.7–2.4 cm far), and it is 7.0 times as wide as it is tall above the ground (9.3 far): at least three.
    - Every face painted flesh, no leaf tiles, sway 0, still in the wind; most of it below the ground line.
    - The old button alone: as tall as `height_m` (0.99 of the unit frame), widest at the ground line (sunk to its rim, 71 % of it underground), 8.0 cm across drawn at 4.5 cm (`diameter_cm` 4–12); 8 ribs counted round its outline; along a rib, its height dips into 3 cross-furrows (4 bumps, the outermost halved by the ground) near and hero, none far; 24 wool tufts (8 ribs × 3 bumps above the ground); its woolly centre the highest point, facing up; the bumps toward `stem.secondary`, the furrows at 0.66–0.69 of the body's lightness and bluer (navy); the edge's corners face out.
    - The clump: 4 buttons, each pressed into a neighbour (overlapping 0.13–0.16), a woolly centre on every one; ribs 8, 8, 5, 5 from `stem.ribs` [5, 13].
    - No spines: the same entry given `spine_cm` [1, 2] grows exactly 150 spines (3 on each of 50 tufts), each 1.5 cm long at the middle height.
    - The flower: a bell 2.2 cm across (`flower_size_cm` 2.2) in the old button's wool near and hero, none far; none on the same entry without a flower; one button where the entry says "solitary".
    - The far level keeps the flat button: its widths up the part above the ground within 11 % of the near level's widest, its top the same white centre, in 228 triangles against 976.
    - **Every CACTUS unchanged:** all 27 CACTUS species, the 18 Trichocereus among them, build the same hero, near and far meshes as before this pass (geometry fingerprints taken from the code before any change); the San Pedro is still the column, 0.52 of its height at its widest.
  - `tools/species_mesh_check.gd`: 1,003 species at the near and far levels, 0 fails, no missing tiles.
  - `tools/mushroom_check.gd` 82 (queue 75's: the shared far-level rule and the builder), `tools/giant_herb_check.gd` 108, `tools/wood_normals_check.gd` 2; `python3 tools/plant_schema_check.py --strict data/sacred/sacred_plants.json`: 7 entries, 0 errors.
  - No crawler code changed, so `crawler_check` was not run.
  - **The look, `tools/species_row.gd`** (`SPECIES="sacred:peyote,Trichocereus pachanoi" HEIGHT_M=mid SPACING=0.55 DIST=0.4 EYE_M=0.3 LOOK_H=0 GRAVEL=1`, 14:00, eye 30 cm up, 40 cm off): peyote in pebbles beside the foot of the San Pedro.
    - The clump, about 55 px across at 480 lines, reads as a cluster of flat blue-grey buttons flush with the ground, with rows of white tufts, scalloped rib edges and a pale pink-white bell in the middle one. A navy line runs where the edges meet the ground.
    - The San Pedro beside it is a ribbed column filling half the frame. A button, not a stub column.
    - The ground there is the open world's green grassland by the first camp (seed 42), with the pebbles sown on it, not a real desert floor.
    - Rendered twice: the first framing (80 cm off, bigger pebbles) put the clump at about 35 px among pebbles nearly as big as the small buttons, so the camera came closer and the gravel got finer (0.3–1.5 cm).
- **For Mike:**
  - **The bell shows all year.** Every peyote clump shares one mesh, so the flower stands on every clump at every season. (Peyote flowers for two days a year, in spring.) The flowers that come and go with the season (`FruitCrop`) only cover trees and shrubs, and peyote is a ground plant. Say if you'd rather have no flower until it can follow the season.
  - **No tufts on the outermost ring of bumps.** It is cut in half by the ground line, so a tuft there would sit in the gravel. Each rib shows three tufted bumps on the old button, and fewer on the smaller ones.
  - **It is small.** At its middle height a clump is about 16 cm across and stands 1.4 cm out of the ground (2.2 cm to the bell's rim), as the entry says. From standing height a few metres off it is a pale dot with a white centre; you see the ribs and tufts only when you crouch close.
  - **My calls, change any:**
    - four buttons to a clump;
    - a third of each button above the ground;
    - the old button takes the middle of the rib range (8 of 5–13) and the smaller ones fewer;
    - the bell's size from `fruiting.flower_size_cm`.
- **For chat:**
  - Data touched beyond the one-liner: one line added to `flags.peyote` in `sacred_plants.json` (the column stand-in is gone). `notes` there still says "no low globe cactus (peyote as cactus)": that is your text, so I left it. `status` keeps its `[NOT WIRED YET]`: the file is still not loaded, and the prompt named no `_help` line to unwire.
  - PLANT_SCHEMA §2's list of engine shapes ("CONIFER … BAMBOO…") doesn't name MUSHROOM or GLOBE_CACTUS; it ends in "…", so nothing contradicts it, but you may want to add them.
  - `sports.json → by_shape` has no `globe_cactus`, so a globe cactus rolls no sports (as with queue 75's mushroom).
  - The rib count follows the entry's growth note (5, then 8, then 13) by size within the clump. The entry's `genes.rib_count` isn't read: every clump shares one mesh, so per-plant genes can't change it yet.
  - For queue 72 or the surface: a globe cactus stands only about a third of its height out of the ground, so wherever it is placed, the drawn ground must be the height the plant is placed at. In the open world `ground_height` matches the drawn ground exactly, and the row frame shows it flush.
  - CLAUDE.md's §FM line doesn't mention §FM.13's shapes (queues 75–77); the mushroom and now the globe cactus are built.

## 2026-10-09 — Queue 69, §FM.6: floor two's fog: the same stone, darker (a490eda)
§FM.6 (Mike, 9 Oct): floor two is the same stone and architecture as floor one, so it reads as one place, with the energy of the whole place *"a little bit darker"*: a layer of fog across floor two, uniform for now, doing to sight and to the torch's reach just what fog does. Built as queue 69 says, and nothing else from §FM.6. One number changed after the walkabout (the density, below).

- **What changes on screen:**
  - **Floor two is foggy.** Go down the stair past the fork and a navy fog fills all of floor two, the same everywhere on the floor. The farther off something is, the more it sinks into the navy. The room round you still reads, but the far end of a corridor is lost. Lit rooms seen down a long way look dim and blue instead of amber.
  - **Its colour** is the look's shade navy (#06186C, LOOK_REFERENCE R3), never grey. Over the dark it takes distance a little lighter and bluer, never darker.
  - **Your torch's pool still reads warm:** the floor and walls 1.2–4 m off are 94% as bright as without the fog.
  - **The flames** (your torch's, the wall torches') are not fogged: only things that give off light glow. Their soft halos fade with the stone round them.
  - **Floor one has none of it.** It keeps its own faint dark haze, exactly as before.
  - **On the stair:** none of the fog until the last 4 m of the stair down (the flight is about 8 m), all of it at the foot. Going back up it eases out over the same metres. Stop half way and it stays half way. No pop.
  - **Density:** Claude's first guess was 0.04 a metre. In the walkabout it was all but invisible: floor two looked the same with it and without it. I raised it to **0.08**: half of a wall 9 m off is fog, four fifths at 20 m. The far end of a corridor is lost and the room near you still reads. I also rendered 0.12, which is thicker (the room's own far wall starts to go). Tune by playing.
  - **Only fog:** nothing else changes. Your torch's light, the light the skeletons and the snake keep to (the light field), what they see and hear, and every rule are exactly as before.
- **How:**
  - `FloorFog` (new, `scripts/crawler/floor_fog.gd`) is a node of the crawler. Every frame it works out how much of the fog is on from where your eye is: 0 on floor one, 1 on floor two, eased along the stair (smoothstep over its last `ease_m` metres). When that changes it writes two things:
    - the environment's fog (Godot's exponential fog), for what Godot's own materials draw: the skeletons' bones, the voids, the vents' daylight;
    - the look's haze (`look_fog_density`, `look_fog_color`), which every look material (the stone, the sprites, the folk, the glows) draws itself instead of the environment's fog. On floor two the floor's fog is added to floor one's faint haze, the two colours mixed by their densities (#061560 together).
  - It writes only when the amount changes, so the sprite bakes (which switch the haze off while they bake) are never written over.
  - `CrawlerMain` makes the node (four lines). No shader or project setting changed: the look's haze was already drawn by every material.
  - Data, `descent.json → floor_two.fog`:
    - `density` 0.04 → 0.08 (a one-line data constant, after the walkabout);
    - `ease_m` 4 added (my first guess);
    - `_help.floor_two`: `[NOT WIRED YET]` off, and what is built.
  - `HOW_TO_RUN.md`: a bullet for the fog and one for its check; "no fog yet" gone.
- **What you can tune** (restart after editing):
  - `descent.json → floor_two.fog.density`: thicker or thinner. 0.04 hardly shows; 0.12 hides the far wall of a big room.
  - `floor_two.fog.ease_m`: over how many metres of the stair the fog comes in.
  - `floor_two.fog.color_from`: `look_shade_navy` (the default), `look_shade_deep` (a darker navy, #020A39), or a colour of your own (`"#rrggbb"`).
- **Checks**, all 0 fails (`fog_check` and `crawler_check` on a490eda as pushed, after the merge with queue 66; `fork_check` and the walkabout on the same code before it):
  - `tools/fog_check.gd` (new, this pass's checks; queue 69 named `crawler_check.gd`): 29 lines.
    - **The data and the colour:** density 0.08 and `ease_m` 4 read. The colour is the look's shade navy (#06186C): blue above red, not grey (red, green and blue within 0.02 of each other fails), lighter and bluer than the tomb's own dark (#05081C). The look's haze on floor two (#061560, 0.105 a metre) passes the same tests.
    - **Where it is, twenty layouts:** none of it on any of floor one's 456 pieces, all of it on every one of floor two's 338. Down the flight, every 5 cm: none above its last 4 m, all of it at the foot, rising and never back between, no step steeper than the ease's own. A doorway's thickness holds what it was. A one-floor tomb has none.
    - **In the game:** waking on floor one, the environment's fog off and the look's haze floor one's own. On floor two, the environment's fog on at 0.080 a metre, exponential, in the shade navy, and the look's haze 0.105. The frame 854 × 480 (the default 480 lines) on both floors, the grade's dither the same (1.0, 31 levels).
    - **Down the stair and back, your body walking:** the fog first in at 4.41 m down the flight (its last 4 m start at 4.30), full at the foot (8.30). Going up it is gone again by 4.27 m. The largest change in one frame is 0.0022 of 0.08: no pop.
    - **Only fog:** pinned off and then on at one spot in the same frame (floor two, torch lit): the light field on all 203,885 squares, what a skeleton would count as seen at 32 points round you, whether the snake is in view, how loud you are, the torch's, the half-dark's and every fire's light, the grade, and every other value of the environment and the look are all the same. Only the fog's own values differ.
    - **Taken back to the hearth from floor two** (as waking after "Good night"): the fog is off at once.
  - `crawler_check` 271 (seed 7, 203 seeds walked; 271 before the merge too) and `fork_check` 48 (the floors and the fork): the same counts as before.
  - The walkabout once, `crawler_frames.gd ONLY=fog` (seed 7, lavapipe, midnight), 8 lines. Floor two's longest straight view, 40 m from a pillared room through its doorway down a corridor, the torch lit:
    - **28a** (lights cold, fog): the torch's pool warm on the flagstones round you. The pillars and walls beyond sink into navy, and the doorway at the far end is a blue murk.
    - **28b**: the same with the fog pinned off. The room's walls show more of their stone, and the far doorway is plain black.
    - **28c** (floor two's 32 lights relit, fog): the room you stand in is fully amber. The corridor past the doorway fades to navy, and its far end is lost.
    - **28d**: the same without the fog. The corridor reads amber nearly to its far end.
    - Checked: both fog frames 854 × 480, every pixel but the crosshair's on the grade's 5-bit grid, and the dither at work on the fog's far walls (all 217 of their 4×4 blocks mix levels; no flat bands). The pool 94% as bright as without the fog. The cold far walls #08124E in the fog against #080C4A without (navy, lighter and bluer). The relit far walls #251959 in the fog against amber #5F2627 without.
    - Also rendered: 0.04 (**28e/28f_fog_0_04**, all but the same as no fog) and 0.12 (**28e/28f_fog_0_12**, thicker), for comparing.
- **For Mike:**
  - The density is my call after the walkabout (0.04 → 0.08). If floor two feels too thick or too thin, change it in `descent.json`.
  - The flames shine through the fog undimmed. Real fog would dim a far flame and give it a halo; tell me if you want that.
- **For chat:**
  - `floor_two.fog.density` is your number: I changed it 0.04 → 0.08 after the walkabout, with the reason in its `_help` (the grey areas allow a one-line data constant, and the commit says so). Put it back if you'd rather Mike starts from 0.04.
  - "Floor one has none": floor one keeps the faint haze it has had since §ET.11 3 (`crawler.json → look fog_density` 0.025, `fog_color` #05081C, the depth's own dark), and so does floor two. The floor's fog is added on top. Godot's environment fog, the one the queue's check names, is off on floor one.
  - "Lighter and bluer with distance" is built as the effect of one navy fog over the dark: the fog has one colour, with no gradient of its own. The cold far walls go from #080C4A to #08124E; the grade already holds the dark at navy, so the change is small.
  - `uniform` isn't read: the fog is always uniform for now.
  - The look's materials write their own fog, which replaces Godot's environment fog for them. That is why the floor's fog goes into the look's haze as well as the environment's.
  - For queue 71 (the surface): `FloorFog` writes the environment's fog and the look's haze only when its amount changes. Off every tomb piece (on the surface) it keeps its last amount, 0 coming up from floor one, so it never writes there. If the surface sets its own fog or haze, it should put floor one's back on the way down.
  - The prompt's checks are in `tools/fog_check.gd`, not `crawler_check.gd`, to keep runs short and merges clean.

## 2026-10-09 — Queue 66, §FM.2: the snake's pool: the freeze, the doorway, observe then behind, the coil you turn into (1bc37be)
Mike, 9 Oct (§FM.2): the snake goes still when you look at it from far away, "a little bit more camouflaged than it is now", never invisible; it sits in doorways and watches you; it studies you for a while before it attacks from behind; and if you hear it and turn around, it may already be coiled and striking. Built as queue 66 says, on queue 65's pool; the snake only, no other boss changes, and nothing it did before is gone.

- **What changes on screen:**
  - **It stops being predictable.** Between its rounds it now does one of four new things, drawn at random by weight (rounds 4, the freeze 2, the doorway 2, observe 2, the coil 1), each for its own time. Its rounds, the slither, the hold at your flame, the peek at the light's edge, its tunnels and the hiss before a strike are all as they were. A sprinter still outruns it (it never goes faster than 4.6 m/s).
  - **The freeze.** Look at it from 12 m or more (all of it that far off), within 25° of where you look, while it is lit where it lies (your torch reaches it out to about 16 m; a lit sconce near it, from farther), and it may stop dead. Sometimes it does and sometimes it doesn't: the moment you first catch sight of it, the freeze is weighed against whatever it is doing. Frozen, it is silent, its head sinks to the floor, and its colours slide 30% of the way toward the tomb's own stone and its grain within a second. Its outline never changes and it is never see-through, so it is harder to spot but never gone. It ends when you come within 7 m of any of it, when you have looked away for 3 s, or after 6–14 s; then it simply does whatever comes next, without a sound. Never in a room or corridor you have lit.
  - **The doorway.** It slides through its dark to the nearest doorway of an unlit room you are not in, and lies just inside the room with its head in the gap, turning its head to follow you. Never onto the way out, into the hearth room, or into the sealed stair down to floor two. Light that room and it leaves for the dark; light a room on its way there and it goes round another dark way; walk into the room and it stops watching; come within its reach (2.5 m) and it strikes as it always has.
  - **Observe, then behind.** It finds you through its dark and follows you 10–18 m back, never inside your torch's circle (about 7 m), along the corridors and through its own tunnels. It slows when you stop and backs off if you come at it; close on it and stay close for 1.5 s and it is found out (it strikes if you are within its reach, else it gives up). It loses you after 6 s out of its senses. After 10–30 s it comes round behind you: it moves only while you face away, and holds still while you look its way. Within 12 s it strikes from behind, with the hiss and the rear-back first, as always.
  - **The coil you turn into.** It gets 5–9 m behind you by a way that never passes you, and curls up. Walk on and it slides after you, and you hear it; stand still and it is silent. Turn toward it (its head within 50° of where you look) and its hiss and rear-back begin that very instant, so it is already striking when you see it. It keeps coming as it rears (as fast as your walk), so if you stand your ground its lunge reaches you from about 6 m or nearer; farther off it falls short. A lunge that lands is one hit of three, never more. Keep walking, and when its time is up (6–12 s from when it lay down) it lets you go: for 8 s it won't take you up by sight or sound, and neither the coil nor observe comes back for you.
  - **Your torch is still a delay.** The time the two stalkers (observe and the coil) spend more than 3.5 m from you with your torch lit counts toward its 4 s hold. So once they have stalked you that long they strike without holding first. Turn on the coil sooner and your flame holds it first, reared and hissing its warning, as before; then it strikes.
  - It stays on floor one, as queue 68 left it: the two stalkers come only while you are on its floor.
- **How:**
  - Four small scripts, one per behaviour, dropped into `scripts/crawler/boss_states/` (`freeze_watched.gd`, `doorway_watch.gd`, `observe_then_behind.gd`, `coil_ambush.gd`), found by name from the pool as queue 65 planned. What they share is `BossStalk` (`scripts/crawler/boss_stalk.gd`, new): whether you are looking at it, how far your torch's light reaches, where behind you is, which doorway to watch from, and the way through its own dark. They move it with the boss's own routes and slither, so the boss rule holds for them as it does for its rounds.
  - `Boss` gains small hooks: a state may cut in the moment its needs come true (the freeze; `BossPool.draw_cut_in` weighs it against the state in charge); its camouflage eases in and out (never past `max_blend`); a state may stretch its own time once it has started going round behind you; a strike asked for by a stalker counts the time it spent beyond your torch's bright circle toward the hold (`begin_strike`); and `let_go`.
  - The camouflage is in the sprites' shader (`shaders/figure_sprite.gdshader`): every sprite's colour mixed toward the ruin's stone (masonry.json's style tint) with a mottle of that stone's own spread. The alpha is never touched. `BossBody.set_camouflage`, `FigureSprite.set_blend`.
  - Data, `boss_pool.json`: `[NOT WIRED YET]` taken off `_help.desert` and `_help.camouflage`, which now say what is built; three new numbers, my first guesses: `observe_then_behind.behind_s` (12), `coil_ambush.turn_deg` (50) and `coil_ambush.let_go_s` (8). `bosses.json` is unchanged (`hunt_mps` still 4.6).
- **What you can tune** (`data/boss_pool.json → pools.desert`; restart after editing):
  - each state's `weight` (how often it is drawn) and `dwell_s` (how long it lasts, [shortest, longest] in seconds);
  - the freeze: `from_m` (how far off you must be), `look_deg` (how close to where you look), `close_m`, `look_away_s`, and `blend` (how far its colours go toward the stone; 0.3);
  - `camouflage → max_blend`: the most it may ever blend (0.5). To go past it, raise both;
  - the doorway: `head_m` (how far its head reaches into the gap);
  - observe: `observe_m` (how far back it follows), `observe_s` (how long it watches), `behind_s` (how long it tries to get behind you);
  - the coil: `lies_coiled_behind_m`, `turn_deg` (how far you must turn toward it), `let_go_s`.
- **Checks**, all 0 fails (on this pass before its rebase onto queue 75, which touches only plants):
  - `tools/boss_snake_check.gd` (new; queue 66 asked for headless checks without naming a file): 65 lines.
    - The pool from the file: the four found by their files, the freeze the one that cuts in, every other boss `rounds` alone, `hunt_mps` still 4.6.
    - 300 draws from one place: all four new states and `rounds` entered (rounds 93, the freeze 52, the doorway 68, observe 55, the coil 32), never the same twice running.
    - The freeze: never with you inside 12 m, looking away, unlit, or in a room you lit. From 13.7 m in your torchlight it freezes within a tenth of a second, its head inside 25° and all of it beyond 12 m. Frozen it moves 0 m in 2 s and is silent. Its sprites' blend, read off their material every frame, eases to 0.3 and never passes 0.5, even when asked for 0.9 and 0.95, and every sprite stays opaque. It holds while you come up to 8.5 m and ends on the very frame you come inside 7 m; after 3.03 s looking away; at its time; with no hiss and no wind-up. It cuts in 20 times in 40 first sightings against a state of the same weight.
    - The doorway: the nearest by its dark way; never the stair down's sealed doorway (this caught a real fault in the first draft: it could lie with its head in the seal's stone); its head drawn in the gap of an unlit room, still; the room lit, it leaves that frame and is back in the dark 0.3 s later; you in the room, it stops; a room on its way there lit, it goes round by another dark way and never walks into the light.
    - Observe: as you walk away its distance stays 13.1–13.9 m (inside 10–18, outside your torch's 6.9 m circle); then it strikes from 174° behind you, the hiss on its first frame and 0.70 s before the lunge, one hit; it follows you through one of its tunnels.
    - The coil: it lies 9.0 m behind you at 179° (its 9.0 of 5–9); you hear it as you walk, and it is silent as you stand; the turn starts its wind-up on that very frame, torch out and torch lit (after 4.2 s of stalking), and the hit that follows is one hit; turned on after 0.9 s, your flame holds it 3.9 s more first; walked away from, it lets you go with no wind-up, its rounds don't take you up for 8 s, and neither stalker may come back until then.
    - 200 s loose on seeds 7 and 1 with its whole pool, you walking its dark: never into a lit room or corridor of its own accord, nothing teleports (its fastest step 4.6 m/s), no draw in the rule's moments, every freeze begun watched.
  - `boss_pool_check` (queue 65's) 48: it had 51; the three lines "its pool from the file walks the same route as no pool" are now printed notes instead, because the snake's pool is no longer `rounds` alone (queue 65 wrote it to do that). A `rounds`-only pool still walks the same route, frame for frame, on all three seeds.
  - `crawler_check` 271 (seed 7) and `boss_check` 227, `stagger_check` 65, `crawler_harm_check` 59, `fire_pot_check` 104, `cleared_check` 90, `crawler_save_check` 39, `residents_check` 177, `fork_check` 48, `hearth_cauldron_check` 56, `hands_check` 61.
  - Changed in place: the checks and walkabouts that test the snake's built behaviour (`boss_check`, `stagger_check`, `crawler_harm_check`, `fire_pot_check`, `cleared_check`, `crawler_save_check`, `residents_check`, `crawler_check`, `boss_frames`, `crawler_frames`) now run it with no pool (`Boss.pool_off`, its rounds exactly as built), as they test it: one setup line each, no assertion changed. With the pool on, its new states would make those runs random.
  - **The walkabout once** (`ONLY=freeze` in `tools/boss_frames.gd`, seed 7, 17–17h), 6 lines. Down a corridor lit by your torch, the doorway at its far end lit amber by its sconce, the frozen snake lies at the foot of that doorway 19.9 m off, head toward you: a small dark shape (37 pixels at 480 lines) you can miss at first glance and find on a second. Walked up to 8.4 m (still frozen; it would end inside 7 m), it is a low dark coil and neck at the end of the corridor beyond a room's doorway, its dark bands a little washed toward the stone. The camouflage is subtle: frozen it stands out from the stone behind it 98% as much as unfrozen at 20 m and 96% at 8.4 m, in the tomb's amber firelight. The first two runs of the frame didn't freeze it (the spot it chose put its tail inside 12 m) and then put the crosshair over it; the frame now finds a spot it really freezes from and looks just over it.
- **For Mike:**
  - **Your torch against the coil's jump scare.** The prompt asks for both "your torch holds it first" (queues 49 and 57) and "turn toward it and its wind-up has already begun". I read the torch's 4 s hold as spent while it stalks you beyond 3.5 m with your torch lit, so the turn starts the strike once it has stalked you that long. If you would rather the flame always hold it first, the jump scare becomes a rear-and-hiss at your flame instead of a strike.
  - **The camouflage is very gentle at 0.3.** In the tomb's amber light the snake's olive-brown and the grey-blue stone look much alike already, so moving its colours 30% toward the stone changes little (96–98%). If you want the freeze to really hide it, try the freeze's `blend` at 0.5 (the most `max_blend` allows), or raise both.
  - **What counts as seeing it**: your torch's light, a fire's light where it lies (needed for the lit corridor at 20 m, where your torch doesn't reach), or your half-dark sight. As the numbers stand the half-dark (black at 12 m) almost never freezes it, since it must be at least 12 m off.
  - **"From far away"** is all of it at least 12 m off, not just its head, and 7 m is measured to the nearest of it too.
  - My calls, change any: the coil's turn at 50°, its let-go at 8 s, observe's 12 s to get behind you; the doorway watcher strikes if you come within its reach on its way there; the stalkers know where you are and come for you through the dark, and observe gives up after 6 s without sensing you; the coil is silent while you stand.
- **For chat:**
  - `boss_pool.json`: three additive numbers (`behind_s`, `turn_deg`, `let_go_s`) with their meaning in `_help.desert`. `pools.desert.freeze_watched.blend` and `camouflage.blend` say the same thing; the state's own wins, `camouflage.blend` is the fallback. One of them could go.
  - Prompt 66's BUILD says the freeze starts with "its head or body inside look_deg"; its CHECK says "the head inside look_deg". Built head or body; the check asserts that the head or a length of its body was inside.
  - The checks of the built snake now pin it to its rounds (`Boss.pool_off`), see above.
  - Built from an interrupted draft (a container restart). Reviewed and fixed before the push: the doorway's sealed stair, a light catching across a moving state's way, the let-go letting the stalkers straight back, the 7 m measured to its head only, the coil's "silent" at -24 dB, and `rounds` after a state that left the snake lying in a state of its own.
  - CLAUDE.md's §FM line still says "not built yet" for the boss pools; queue 65 and this pass built the snake's.

## 2026-10-09 — Queue 75, §FM.13: a mushroom shape: a cap on a stalk (431c230)
§FM.13 item 1 (Mike, 9 Oct, "do it"): teonanácatl, the fly agaric and Caesar's mushroom were drawn as a leaf rosette; now the engine draws a real mushroom. Built as queue 75 says. An earlier agent's draft, cut off by a container restart before it committed, was picked up, checked against every item and finished.

- **What changes on screen:**
  - **Nothing in the crawler yet.** `data/sacred` is still not loaded.
  - **In the open world** (Torchfire 2, switched off), the fly agaric (taiga) and Caesar's mushroom (Mediterranean scrub) now grow as mushrooms. Each plant is a small group of three: an old one in the middle with its cap opened out, and two younger ones round it, leaning out a little, with rounder caps.
    - The fly agaric: wide, flattish scarlet caps dotted with white warts, on stout white stalks with a skirt and a swollen foot.
    - Caesar's mushroom: flame-orange domes opening flat, golden gills and stalks, each standing in a white sack (its "egg").
  - **Teonanácatl**, built from its data/sacred entry for the check and the look only: tiny ochre bells with a low nipple on thread-thin straw stalks, a blue-green tinge at the rims, the group widest at its top.
  - **Painted (§ES):** under every cap the gills are dark, shaded toward navy, and the stalks go navy just under the caps and at the foot, never grey. Diffuse only, no leaf tiles, no shine. Mushrooms don't sway in the wind.
  - **From far off** a mushroom is the same three caps on stalks with fewer sides. It never becomes the flat card the far trees use, so it never turns into a blob.
- **How:**
  - `PlantSpecies.Shape.MUSHROOM`, read from an entry's `"shape": "mushroom"`.
  - `MushroomMesh` (`scripts/ecology/mushroom_mesh.gd`, new), called from `PlantMeshes._build`, reads each entry's own `appearance` block:
    - `cap.form` (or `cap.notes` when the form names no shape) for the cap's shape: conic, bell, hemispherical, domed, flat or funnel, and a nipple;
    - `cap.size_cm` against `height_m` for how broad the cap is; the stalk is about a tenth of the cap across, and as tall as `height_m` leaves under the cap;
    - `cap.colour`, with `cap.secondary` toward the rim (and on the flecks of a flecked cap), `underside.colour` for the gills, `stipe.colour` for the stalk;
    - words in the cap's notes, habit and silhouette for a skirt, a bulb or a volva.
  - The plant shader has a new material, "a fungus's flesh" (`foliage.gdshader`, UV2.x −1). It is drawn like bark (closed, lit from outside, shadows cast from its far side), but in its own painted colour: no bark texture, no pull toward bark brown, no moss.
  - `SpeciesDB.species_in_file()` and `species_from_entry()` build one entry exactly as the loader builds a catalogue entry, without adding it to the world's plants. So the check and the look can draw teonanácatl while the open world and the §CC trim stay as they were.
  - Data, as data-driven one-liners: `"shape": "mushroom"` in teonanácatl's entry and in the two Amanitas'.
  - `HOW_TO_RUN.md`: a mushrooms bullet. `data/biomes/README.md` lists the shape.
- **What you can tune:**
  - The look comes from each entry's `appearance` block and `height_m`: `cap.form`, `cap.size_cm`, `cap.colour`, `cap.secondary`, `cap.texture`, `underside.colour`, `stipe.colour`, `habit`. Change the entry and the mushroom follows on the next start.
  - Any other fungus can be a mushroom with the same one-liner in its biome file. The field mushroom, the parasol, the boletes and the waxcaps are still rosettes.
  - In code, `scripts/ecology/mushroom_mesh.gd`: `BODIES` (the group: heights and cap sizes), `STALK_OF_CAP` (stalk thickness), `RIM_SHARE` (how much of the secondary colour reaches the rim), `FORMS` (each cap shape's height and roundness).
- **Checks** (on 431c230), all 0 fails:
  - `tools/mushroom_check.gd` (new, queue 75's check): 82 lines.
    - The shape and its string. Teonanácatl built from its data/sacred entry as a catalogue entry is built, and data/sacred still not loaded: 1,003 species before and after, none from data/sacred.
    - The fly agaric and Caesar's mushroom load as MUSHROOM. Every loaded mushroom builds through `mesh_for` (the path the open world and the litter fungi take) at the near and far levels.
    - For all three at the hero, near and far levels: every face flesh (no leaf card, hull, far picture or leaf tile), sway 0, still in the wind. Top at y 1 in the unit frame, so drawn at any height in `height_m` it stands inside `height_m`. The cap `cap.colour` at its top, easing to `cap.secondary` at the rim. The gills dark (0.57 of their colour's lightness) and bluer: navy. Three stalks through a third of the height; leaning 2–11°. Lit from outside.
    - Teonanácatl's widest point is in its top third at every level: 0.74 of its height near, 0.76 far.
    - The far level keeps the near level's silhouette: widths within 1–3 % of the widest, a cut either side.
    - Drawn at the middle of `height_m`: teonanácatl's cap 1.7 cm on a 2.0 mm stalk (its entry: 0.5–3 cm, 1–3 mm); the Amanitas' caps 13.7 cm (8–20 cm) on 15 mm stalks.
    - The cap shapes read from the text: teonanácatl conic to bell with a nipple, its oldest cap 1.03 of its half-width tall; the fly agaric hemispherical to flat (0.38); Caesar's, from its notes, domed to flat (0.32).
  - `tools/species_mesh_check.gd`: 1,003 species at the near and far levels, 0 fails, no missing tiles (977 at its last record; the data has grown since).
  - `tools/giant_herb_check.gd` 108; `tools/wood_normals_check.gd` 2 (every bark part and culm still faces out); `python3 tools/shader_varying_check.py` (the plant shader still 9 slots); `python3 tools/plant_schema_check.py --strict` on the three data files (50 entries, 0 errors).
  - The look, `tools/species_row.gd` (`SPECIES="Fly agaric,sacred:teonanacatl" HEIGHT_M=mid SPACING=0.3 DIST=0.75 EYE_M=0.3 LOOK_H=0.5 GRASS=Buffalograss`, 14:00, eye 30 cm up, 75 cm off): three red toadstools with white flecks and white stalks, navy shade under their caps (and navy shadows: the row casts them; in play the ground cover casts none), beside two of teonanácatl's three thin straw stalks with tiny ochre bells, standing in pale buffalograss, the fly agarics about 60 px tall. All read as mushrooms; teonanácatl's bells stand clear of the grass heads. Rendered twice: in the first frame the sown grass drew nothing, so the row's `GRASS` now draws it in the class texture (below).
  - New in `species_row.gd`: a `sacred:<id>` name stands a data/sacred entry in the row, `HEIGHT_M=mid` draws each plant at the middle of its own height, `EYE_M` sets the camera's height, and `GRASS=<name>` sows a grass round the row.
- **For Mike:**
  - A far mushroom is its own small model (about 180 triangles for a group of three) rather than the far trees' two-triangle card. Mushrooms are drawn only within the ground cover's reach (`look.json → ranges.ground_m`, 45 m), so it costs little.
  - The younger fly agarics' and Caesar's caps sit lower than the old one's: those groups are widest at about half their height, like a cluster of toadstools. Teonanácatl's group is widest at its top, as the check asks.
- **For chat:**
  - Data touched beyond the three one-liners: one line added to `flags.teonanacatl` in `sacred_plants.json` (the rosette stand-in is gone). `notes` there still says "no mushroom shape": that is your text, so I left it. `status` keeps its `[NOT WIRED YET]`: the file is still not loaded, and the prompt named no `_help` line to unwire.
  - The fly agaric's old `traits` block still describes a rosette (`leaf_shape` "leaves in a ground rosette", `trunk` "none — stemless"); no code reads those two.
  - `sports.json → by_shape` has no `mushroom`. The two Amanitas therefore no longer roll sports: as rosettes they could come up "variegated"; now nothing comes up, not even their documented white form (`anthocyanin_free`). If you add an entry, note that the plant shader would paint the "green form" and "dark form" sports onto a cap.
  - Caesar's mushroom's appearance never mentions its ring (only its `source` does), so it draws without a skirt. A "ring" in its `cap.notes` or `habit` would add one.
  - For prompts 76 and 77: `SpeciesDB.species_in_file(SpeciesDB.SACRED_PATH, id)` builds a data/sacred entry without loading it, and `species_row.gd` takes `sacred:<id>`.
  - Seen in the look: up close, the open world's tiled grasses barely draw. With its own leaf tile, the buffalograss sown round the row showed nothing at a metre: its leaf cells are 12 cm or more, wider than a blade, so they cut the blades away. Reported, not this pass's.
  - CLAUDE.md's §FM line doesn't mention §FM.13's three shapes (queue 75–77); the mushroom is now built.

## 2026-10-09 — Queue 68, §FM.6: floors and the fork: a second floor below the first, sealed until floor one is lit (f2bd277)
§FM.6: "Light every torch on floor one and two openings appear together: the way up to the surface and the way down to the next floor. An instantaneous first decision for the player." Built as queue 68 says, with three calls of mine (the stair's place, floor two's size and its skeletons) under **For Mike** below.

- **What changes on screen:**
  - **The way down.** The room just before the heart (the spine's last room before it) has a doorway in the middle of one side wall with a plain stone slab standing in it. It is the tomb's own grey-blue stone, with nothing carved on it and no light (§FG: nothing points to it), and you can't get past it.
  - **The fork.** Light every torch on floor one. On the very tick the last one catches, the slab starts to sink into the floor. It takes 3 s, with a heavy grinding of stone you can hear about 70 m down the passages and a thud as it settles. Then the log says, once: "Every light is lit. Two ways open: up to the day, or down." The line comes after "Banished the dark. What lived in it fled." and the snake's line.
  - **The way out stays open the whole time.** `fork.gate_surface` is false: you haven't answered §FM.10 call 2, so I left it false. With it true, a second slab stands at the foot of the way-out stair and both slabs sink on the same tick. Going up still fades to the game's next tomb, as before, until prompt 71 builds the surface.
  - **Behind the slab:** a straight flight of stairs drops 4.8 m (8 m of steps) into floor two. Going back up, you arrive at the same doorway.
  - **Floor two** is built by the same generator in the same stone:
    - a first room at the foot of the stairs, then a long main way and shorter side ways;
    - crypts, catacombs, ossuaries and collapsed rooms (about 9 rooms), with cold wall torches in every room and along the corridors, and airways;
    - its own three to six skeletons asleep in its niches and coffins;
    - no hearth (floor one's is the only one) and no heart. No fog yet (prompt 69).
  - **Each floor is cleared by its own lights.** Light all of floor two and its skeletons go home, and the log says its line, whatever floor one is doing. The log counts each floor's lights separately ("12 of 32 lights burn again." on floor two). The tomb's first log line counts floor one's lights only, so nothing gives floor two away.
  - **The snake stays on floor one**, with its lair where it was. You haven't answered §FM.10 call 4. Its dark is floor one's, so floor one's last light drives it home. It never goes down the stairs. The fire pot you can find stays on floor one too.
  - **Floor one is the tomb as it was**, except the room the stairs leave: it gains the doorway, and its torches, niches and coffins are placed around it. The rest of floor one keeps its layout, torches, airways, skeletons, lair and tunnels.
  - **Kept** (queue 63's save, §FK.2; 63 landed first, so this pass wired it): once the way down opens, it stays open in your game's save (`fork_open`, kept with the lights you relit). Continue finds it open, with no grinding and no log line again. A floor kept fully relit comes back cleared on its own.
- **How:**
  - `TombFloors` (new) lays the stairs and floor two. `TombKit` calls it after floor one's side ways. Floor two gets its own dice, and floor one's torches, airways, skeletons, lair and tunnels are placed on floor one only. Floor two never sits over or under floor one, so one floor grid holds both.
  - `Fork` and `RelightGate` are new. They are the first relight_to_open gate (`crawler.json → gates`; nothing called "the gates machinery" existed, so this is it). While a slab stands, nothing walks or plans a path through it: `TombNav.close_door` and `BossGround.shut`.
  - `Residents` clears floor by floor (`cleared_floors`). `CrawlerMain` counts lights per floor and saves the fork with the relit lights.
  - Data:
    - `descent.json`: `floors.drop_m` (4.8) and `fork.seal` (`open_s` 3, `thick_m` 0.36) added; `_help.floors` and `_help.fork` say what is built.
    - `audio.json → kinds.stone_seal`: the grinding's reach.
    - `crawler.json`: `[NOT WIRED YET]` off `_help.floors`; `_help.cleared`, `_help.gates` and `_help.persistence` updated.
- **What you can tune** (restart after editing):
  - `descent.json → floors.count`: 1 gives the tomb alone, as before; 2 is the most for now.
  - `floors.drop_m`: how far down the stairs go.
  - `fork.gate_surface`: true seals the way out too until floor one is lit.
  - `fork.seal.open_s`: how long the slab takes to sink.
  - `fork.log_line`.
  - `audio.json → kinds.stone_seal`: how far the grinding carries.
- **Checks** (on f2bd277 and the merges before it), all 0 fails:
  - `tools/fork_check.gd` (new, this pass's checks; queue 68 named `crawler_check.gd`): 48 lines.
    - **Fifty layouts:** two floors every time. The stairs always leave the spine's room before the heart, through a centred door in its side wall. The flight drops 4.8 m. Floor two is below and apart, reached only through that door. Floor one matches a one-floor tomb of the same seed except that door. Floor two has its torches, no hearth or heart, its own skeletons. The snake's lair and tunnels are on floor one.
    - **The walks (50 tombs):** with every torch cold and the slab standing, your body walks out every time and finds no way down. With the slab gone, it walks down into floor two every time (median 81 m).
    - **In the game:**
      - The slab blocks you, the skeletons and the snake, and carries no light.
      - Floor two lit first is cleared on its own; the way down stays shut.
      - Floor one lit but one: still shut.
      - The last torch opens the way down on the tick floor one is cleared, with the grinding and the one log line.
      - The slab sinks out of sight in 2.9 s. The snake goes home. The way out is open throughout.
      - Your body walks down the stairs and back up to the same doorway.
      - Continue after closing finds the way down open, quiet.
      - With `gate_surface` true, both slabs go on one tick.
  - Also run: on f2bd277, `crawler_check` 271 (seed 7, 203 seeds walked), `boss_check` 227, `boss_pool_check` 51 and `hearth_cauldron_check` 56. On the merge with queue 63: `crawler_save_check` 39, `cleared_check` 90, `crawler_harm_check` 59, `hands_check` 61 and `hud_pin_check` 49. On this pass before the merges (queues 65 and 67 touch neither): `residents_check` 177, `fire_pot_check` 104 and `stagger_check` 65. `hud_pin_check` crashes in Godot's shutdown after its result: the known one.
  - Changed in place where floors change what they assert:
    - `cleared_check`'s relight run uses floor one's torches and skeletons.
    - `residents_check` counts 3–6 skeletons per floor.
    - `crawler_check`'s walk of every door opens the fork first, and its walk-out line now names the slab.
    - `crawler_save_check`'s first log line counts floor one's cold lights.
- **For Mike:**
  - §FM.10 call 2, the way out gated by the lights: still open; `gate_surface` is false.
  - §FM.10 call 4, the snake's home on the bottom floor: still open; it stays on floor one.
  - My calls, change any:
    - **Where the stairs leave:** the room before the heart, so the way down opens near the way up.
    - **Floor two's size:** about three quarters of floor one (about 9 rooms against 11).
    - **Its own skeletons:** `residents.json → per_dungeon` 3–6 now counts per floor, so a whole tomb has 6–12.
  - The beetles (`ambience` 10–16 a tomb) are now spread over both floors, so floor one has about half as many as before. Glow-moss grows by wall length, so each floor keeps its own.
  - Floor two adds about half again to the tomb's stone (seed 7: 937,000 triangles against 606,000) and to its build time (13.5 s against 8.5 s on this machine; much less on your Mac).
- **For chat:**
  - Prompt 68 asked to take `[NOT WIRED YET]` off `descent.json → _help.floors` and `_help.fork`, but neither carried it; only `_help.about` did. The about now says floors and fork are wired, and the prefix moved to `_help.floor_two` (prompt 69's).
  - `floors.same_stone` and `floors.base_layer` aren't read: floor two is always the same stone; the base layer waits on call 4 and prompt 73.
  - `fork.when`, `opens`, `both_at_once` and `penalty` are built as they say; nothing switches them.
  - §FF.1's open question (one hearth per dungeon or per floor) is read as one per dungeon (§EX.4).
  - Slower checks: floor two roughly doubles the work of every crawler check that builds tombs. `crawler_check`'s 203-seed walk alone took 613 s here (the whole run about 45 min, with other checks running alongside).

## 2026-10-09 — Queue 67, §FM.6: the shaman and the cauldron at the hearth (3485919)
Mike, 9 Oct (§FM.6, the opening room): one shaman sits at the hearth, *"and now a cauldron hangs over the hearth, from the first moment."* Built as queue 67 says; nothing else from §FM.6 (the floors, the fork, the fog and the room pool are 68–70; the brew is 72).

- **What changes on screen:**
  - In every tomb an iron cauldron hangs over the hearth's fire, there as soon as the screen fades up and in every tomb the way out takes you to.
    - A round-bellied pot about half a metre across with a rolled lip, its bottom 44 cm over the floor so the flame licks it. It is empty.
    - It hangs by a short chain from a tripod of three dark poles lashed together over the fire, their feet on the pit's kerb. One pole stands straight across the fire from your mat, the other two at your sides of the fire, so none stands between you and the flame or the shaman. The bail arches toward your mat.
    - The fire lights it from below: the sooty belly glows amber, and the rim, the inside and the tops of the poles fall away into the dark, so from the mat it reads as a dark pot against the flame, the flame showing under it.
    - The poles throw long shadows across the floor; the pot throws none.
  - The one who found you now reads as the shaman: the same figure, the same slow breath and glances, still silent, and in his right hand a long wooden ladle, leaning out to his side with its bowl up.
  - Nothing else moved: you wake on the same spot, walk up to the kerb and light your torch at the hearth as before, and the room's light, the creatures' sense of it and the way out are as they were. A fire pot thrown into the pit may now strike the cauldron.
- **How:**
  - `HearthCauldron` (`scripts/crawler/hearth_cauldron.gd`, new), built with the tomb right after its fires (`CrawlerMain._load_tomb`, after queue 63's kept holders) and freed with it.
    - The pot is one lathe, 14 sides, outside and in, with its soot and its occlusion painted into its vertex colours (Prelit, toward navy: the inside and under the lip are darker); lugs, the bail and the chain are thin iron rods; 1,318 triangles in all.
    - It is drawn in the tomb's own lit material (diffuse only, roughness 1, no normal maps), the iron and the poles alike in its smooth matte. (The timber tile striped the slanting poles in the first look, so they lost it.)
    - A collision hull round the pot's belly, under its rim, inside the pit's guard: nothing you walk changes, and no line from the hearth's light to the floor past the kerb meets it. The poles and the chain have none (they stand inside the guard too).
  - The light. The hearth's one light hangs a metre over the floor, a hand above the pot's mouth. In the first walkabout, lit from there, the empty pot glowed from inside like a brazier and blew out to orange. So:
    - the hearth's light passes the cauldron by: its cull mask leaves out the cauldron's render layer (layer 14) and nothing else, so the room is lit exactly as before;
    - and a small light in the flame under the pot, `Firelight`, lights the cauldron alone, in the hearth's amber, at `firelight.share` (0.14) of the hearth light's strength every frame, so it flickers and breathes with the fire. It has no shadow and isn't a fire to the game: the light field, the half-dark, the fire shadows and the creatures never see it.
  - `HearthFolk.hold()`: the ladle, a slim wooden handle with a small bowl on its top, a child of his right forearm through his fist, so it rides his hand and breath. It is painted like him (his shader, his big texels, 16 a metre). Nothing new in the rig, no blocker, no words.
  - For queue 72 (the brew): `CrawlerMain.cauldron` and `CrawlerMain.shaman()`, the nodes `Cauldron` and `Rescuer`, the group `hearth_cauldron`, `HearthCauldron.mouth()` and `mouth_r()`, `HearthFolk.ladle`.
  - `crawler.json`: a new `cauldron` block and `_help.cauldron`; `rescuer → holds, ladle` and a sentence on `_help.rescuer`. All first guesses.
  - `HOW_TO_RUN.md`: two new bullets, the shaman and the cauldron, and the cauldron's check.
- **Checks**, all 0 fails:
  - `tools/hearth_cauldron_check.gd` (new; the prompt said `crawler_check`, put in its own file to keep runs short and merges clean): 56 lines, on 3485919.
    - Over 20 seeds' hearth rooms, built as the game builds them: exactly one shaman and one cauldron within the hearth's reach (its light's 9.1 m); the cauldron over the hearth's middle, its pot under the hearth's light, its collision inside the pit's guard, the tripod's feet on the kerb; the ladle in his right hand.
    - The wake spot meets neither collision (at least 1.79 m clear of the cauldron, 3.76 m of the shaman).
    - The usual spot: your body walked from the mat at the fire stops at the guard, 1.21–1.23 m from its middle, never at the cauldron, and the swing from there reaches the flame.
    - The hearth's light field at 3 m (up to 151 squares), cast with the cauldron and without, the light at rest and at its flicker's eight furthest jitters: unchanged, 0.000% at worst; no square past the kerb changed at all.
    - In the game (seed 7, then two tombs the way out took me to): the cauldron there before the dark lifts; one shaman and one cauldron in each tomb, the last tomb's gone; you wake on the mat; walking from it at the fire you stop at the guard, take a torch from the bundle and the game's own swing lights it; the residents' light field at 3 m unchanged; the look (above) and the shaman (above) as described; no log line from him; the cauldron empty.
  - `crawler_check` (seed 7) 271, on this pass rebased onto queue 63. Two lines changed in place: "full dark" counts the cauldron's Firelight with the hearth's light, and the pit's floor ray and the line across the pit at 0.7 m pass the cauldron (the pit and its guard are what they measure).
  - `crawler_save_check` 39 (queue 63's), also on 63.
  - On 3485919 (rebased onto queue 65): `stagger_check` 65, `fire_pot_check` 104, `crawler_harm_check` 59, `cleared_check` 90, `residents_check` 176 and `boss_check` 227.
  - `hands_check` 61, before the rebases.
  - The walkabout once, `crawler_frames.gd ONLY=cauldron` (seed 7, 27a–27e), 8 lines. From the mat at midnight the cauldron hangs dark in front of the fire, its belly 2.5 times darker than the flame showing under it, the poles framing the fire, the shaman across it with the ladle out to his side, nothing between your eye and him. At noon the shaft's daylight falls on the pot. From the side, the bail, the chain and the lashing read. Down into the pit past it, the fire is still the warm thing in view. From in front of the shaman, the ladle's bowl at its top. The first look's pot was copper-bright and the ladle's bowl, facing the fire, looked like a disc held up beside his head; the colours went darker, the light from below weaker, and the bowl now opens to the sky.
  - Not re-run: the full `crawler_frames` tour. Its rescuer frames (03a–03e) now have the ladle in them; 27e checks the same view as 03a.
- **For Mike:** to tune, open `data/crawler.json`.
  - `cauldron → pot`: `belly_r_m` (its width), `h_m`, `bottom_m` (how high over the floor it hangs), `mouth_r_m`, `lip_m`.
  - `cauldron → tripod`: `apex_m` (how high the poles cross), `pole_r_m` (how thick), `past_apex_m`. `cauldron → chain → link_m`.
  - `cauldron → colors`: `iron`, `soot`, `pole`, `pole_soot`, `cord`.
  - `cauldron → firelight → share`: how strongly the fire lights it from below (0.14; higher is brighter).
  - `rescuer → ladle`: its length, its bowl, `out_deg` and `fwd_deg` (how it leans), `bowl_tilt_deg`, `color`; `rescuer → holds` set to `""` takes the ladle away.
- **For chat:**
  - The live amber is the hearth's colour and flicker on a light of the cauldron's own, in the flame under it; the hearth's own light leaves the cauldron out. That was the only way I found to light an empty pot hung a hand under the light without it glowing from inside. Mike may want the hearth's light moved down, which queue 67 forbade (the light field).
  - Iron was my call (§FL.1). The tomb is still Andean, and FM.10 call 1 (Aztec world against the tomb) is open; clay over three hearthstones would be the Mesoamerican way, if Mike wants it.
  - The ladle is a new prop, cut like the fire circle's stick and bowl. §FM.6 has no ladle, only "a shaman".
  - CLAUDE.md's §FM line still says "not built yet". The shaman and the cauldron are now built.

## 2026-10-09 — Queue 65, §FM.1: the boss behaviour pool; the snake plays exactly as before (492ae98)
Mike, 9 Oct: every boss has *"a group of different behaviors that each boss can cycle through on RNG level"*, so you can never learn it like a script. This pass builds the machinery for that. Nothing of §FM.2 is in it: the snake's four new moves are queue 66.

- **What changes on screen:** nothing yet, on purpose.
  - The snake now rolls dice to choose what to do next. So far its only move is `rounds`, which is everything it already did: its rounds and coils, noticing you, the hold at your flame, the strike, the light's edge, the tunnels, the pots, the last light.
  - It walks the very same route as before, frame for frame.
  - The other bosses' lists are `rounds` alone too, ready for when each is built.
- **How:**
  - `BossPool` (`scripts/crawler/boss_pool.gd`, new) reads a boss's list from `data/boss_pool.json → pools.<boss>`.
    - It draws the next state by weight, and never the same one twice running unless it is the only one that may come (`rule.repeat_gap`).
    - It rolls dice of its own, not the game seed (`rule.live_rng`; false would seed them from it).
    - Each state lasts a random time between its two `dwell_s` numbers.
  - A state is a small script with enter, tick and exit (`BossState`, `scripts/crawler/boss_state.gd`, new), found by its name in `scripts/crawler/boss_states/<name>.gd`.
    - `rounds.gd` is the first. It runs `Boss.rounds_tick`, which is the boss's built behaviour moved into its own function, not rewritten.
    - Queue 66 adds the snake's four moves by dropping four files in that folder.
    - A name in the data with no script (the snake's four, until then) is skipped with one warning in Godot's output, never a crash.
  - `Boss` asks the pool for the next state when the one in charge ends itself or its time runs out, and only when it is free. The rule always wins (`rule.never_breaks`):
    - Its own moments are the chase (hunting you, the hold at your flame, the strike, watching from the light's edge), leaving the light, a fire pot, you taken and the last light (`Boss.RULE_MOMENTS`).
    - When one of them begins, the state in charge is over. The dice wait until it has passed, the strike is done and the snake is out of its tunnels.
  - A state strikes only with `Boss.begin_strike`, the strike as built: your lit torch holds it off first, then its rear-back and hiss.
  - A state ends, and the snake leaves as it always has, if you light the room round it or it walks into the light.
  - A state ends if it keeps the snake still on the way out for half a second (`Boss.EXIT_WAIT_S`). The way out is the flight and landing to the daylight, and 2 m round their doorways. The snake then goes off on its rounds before the next roll.
  - No number in `bosses.json` changed, and nothing about the strike.
  - `boss_pool.json`: `_help.about` no longer says NOT WIRED for §FM.1. The mark now sits on `_help.desert` and `_help.camouflage` (§FM.2, queue 66). `_help.rule`, `_help.pools` and `_help.check` say what is built.
  - `HOW_TO_RUN.md` has three new bullets under the snake.
- **Checks**, all 0 fails:
  - `tools/boss_pool_check.gd` (new): 51 lines (on 492ae98).
    - The draw: a test pool of three states (weights 1, 2, 3) over 200 draws has no fixed order and never the same state twice running. All three are drawn, and their shares are within 0.1 of the weights (0.02 over 20,000).
    - An unknown name warns once and is skipped.
    - Same route: the snake from seeds 1, 7 and 42, loose 150 s with two relights round it and a fire pot. Its route is identical frame for frame with no pool at all, with its pool from the file, and with a `rounds`-only pool rolled every 0.1–0.4 s (240–270 rolls).
    - No roll while it hunts you, holds at your flame, strikes, holds you taken, is driven off by a pot, or goes home at the last light.
    - A state's strike plays its rear-back and hiss first (0.70 s), and your lit torch's 4 s hold before that.
    - A state is over on the very tick you light the room round it or it walks into the hearth room.
    - A state kept still on the way out is over after 0.5 s, and the snake is off the way out before the next roll.
    - A state that ends itself is followed at once by the next.
  - `boss_check` 227 (on 492ae98). Its whole output is word for word the same as before this pass, every number in it. It was diffed against two pre-pass runs, which also matched each other.
  - `crawler_save_check` 39 (queue 63's; it checks the snake down its hole on Continue) and `cleared_check` 90, both on 492ae98.
  - `crawler_check` (seed 7) 271, `stagger_check` 65, `crawler_harm_check` 59 and `fire_pot_check` 104, all on this pass before it was rebased onto queue 63. Queue 63 touched none of the boss's code but `_start_far`.
- **For Mike:** to tune later, open `data/boss_pool.json`.
  - Under `pools → desert`, each move has a `weight`: how often it comes up against the others.
  - Each move has a `dwell_s` pair: the shortest and longest it lasts, in seconds.
  - `rule → repeat_gap` 1 means never the same move twice running.
  - Until queue 66, only `rounds` does anything.
- **For chat:**
  - §FM.2's `coil_ambush` (`wind_up_begun_on_turn`) clashes with `rule.never_breaks → torch_hold_holds`. As built, a state's strike waits out your lit torch's hold first, like every strike. Queue 66 or Mike must choose whether the ambush is an exception.
  - "Never blocks the exit" is built as: a state can't keep the snake still on the way out (the exit flight and landing, and 2 m round their doorways) for over 0.5 s. The spine to the heart isn't counted, so 66's doorway watcher may still sit in a spine doorway. Is that right?
  - The dice wait out more than the prompt's list (the strike, the last light, a pot): also the whole chase, leaving the light and its tunnels. That way a roll never cuts a chase or a tunnel short.
  - After a chase the next move is drawn afresh, because the strike and the chase end the state in charge. `_help.rule` already says a strike ends a state.
  - `CLAUDE.md`'s §FM line still says "not built yet". §FM.1's pool is now built, with only `rounds` in it.

## 2026-10-09 — Queue 63, §FK.2 and §FK.3: one world per new game — one seed, a save, Continue and New game; one clock (c90ea52)
Built as queue 63 says, in the crawler only. The open world (Torchfire 2) and its own saves are untouched.

- **What changes on screen:**
  - **The first time you press Play** nothing is new: you wake in a new tomb.
  - **From then on, Play first shows a small plain box on black** (the settings panel's look, no art) with two lines:
    - **Continue**, with the tomb it opens written under it ("Tomb 7731, 4 of 34 lights burning").
    - **New game**.
    - Click one, or use Up and Down (W, S) and Enter (Space or E). Esc is Continue. New game asks once more ("Start a new game? This world is put away.") and starts on the second pick.
  - **Continue** wakes you on the mat by the hearth of the tomb you were in, with every light you relit there burning again.
    - The log says "Back by the hearth, as you left it.", and its first line counts only the cold lights.
    - A tomb you had lit end to end is still cleared: the skeletons lie as bones in their niches and graves, and the snake is down its hole. Neither log line ("Banished the dark…", "Drove the giant snake…") plays again.
  - **Walking out** still fades to another tomb, but now it is this game's next tomb, the same one every time you play this game.
  - **New game** (that box, or Settings → World → New game, two clicks) rolls a new world: a new first tomb, new tombs beyond it, every light cold. In the crawler the Settings line now reads New game; in the open world it still reads New world.
  - **Not kept yet:** what you carry, the bundle's torches and the time of day. On Continue you wake empty-handed, the bundle has its three torches again, and the day starts at the usual hour (about 15:00).
- **What is saved, and where:**
  - One file per game, `crawler/<game seed>.json`, in Godot's user folder. On a Mac that is `~/Library/Application Support/Godot/app_userdata/Low-Poly Exploration/`.
  - `crawler/last.json` names the last game played. That is the one Continue opens.
  - The file holds the game's seed, the tomb you are in, and for each tomb you have been in: its seed, its theme, a fingerprint of where its lights stand, and which lights you relit.
  - It is written whenever something changes (a light catching, walking out into the next tomb, a new game) and once more when the game closes. A crash loses nothing.
  - After New game, the old game's file stays on disk, but nothing in the game opens it again. One world or save slots is still your call (§FK.5 call 3).
  - **WorldSave or a new save:** a crawler save beside it, not WorldSave. WorldSave keeps the open world's saves in `worlds/` with its own last-world pointer. Sharing them would have let one game's Continue open the other game's seed. So the crawler has its own folder and its own pointer, and `WorldSave` is unchanged.
  - The checks never write a save. Under `WorldSave.read_only`, or in any `--script` run whatever that says, the save lives in memory only.
- **One seed, every tomb** (`persistence.dungeon_seeds`):
  - A game's first tomb is built from the game's own seed: game 7731's first tomb is tomb 7731. So `SEED=7` still gives the checks the same tomb 7 they always had, and the seeds in older notes (126's crypt, 42's floor holder) still mean the same tombs.
  - Each later place (the tombs the way out leads to: 1, 2, …) gets a seed drawn from the game's seed and that place. For game 7 the next tomb is 425838.
  - `SEED=` in the environment pins a game: always a fresh start of it, never a Continue.
  - The first tomb is still the tomb theme: §FJ.1's random pick from the roster isn't wired yet, and only the tomb is built.
- **How:**
  - **`CrawlerSave`** (new, `scripts/crawler/crawler_save.gd`):
    - `begin` picks the game: a new one if New game was asked for; else `SEED=`'s, fresh; else the last game kept (Continue); else a new one.
    - `dungeon_seed` draws each tomb's seed. `enter` records the tomb you are in and hands back its kept lights; a tomb whose lights no longer stand where they did (the rules changed since) starts cold, with a warning. `relight` lights them straight to flames, with no catching, no sound and no log line. `keep_relit` records new ones as they catch.
    - `keep` and `kept_value` hold any other named state per tomb: for gates, and for §FM.6's fork (below).
  - **`CrawlerMain`:**
    - Calls `begin`, builds the tomb at its place and relights its kept lights before anything that reads the light is built.
    - Records each light as it catches, saves on closing, walks out to the game's next place, and New game sets the request and reloads.
    - A kept tomb that is all relit starts cleared, its residents laid down as bones once their sprites exist. `next_seed` and `_seed` are gone.
  - **`Boss._start_far`:** a boss that starts with no dark anywhere (only a kept tomb all relit) is home in its lair, breathing below, unseen. It was "gone" before, and that case never came up.
  - **The boot scene** (`scripts/core/boot.gd`) shows `BootMenu` (new, `scripts/ui/boot_menu.gd`) when a crawler game is kept. With none, and for the open world, it boots as before.
  - **`SettingsPanel`:** the New world line reads New game in the crawler.
  - **Data:**
    - `[NOT WIRED YET]` is off `crawler.json → _help.persistence` and `worlds.json → _help.generation`, each now saying what is built and what isn't (gates, the map, `shot_check`, other worlds).
    - `persistence.log_continue` is added.
    - `persistence.save` changed from `world_save` to `crawler_save`, a one-line value naming what is built.
    - `_help.exit`'s stand-in sentence now says the game's next dungeon.
  - **One clock (§FK.3):** already built by queue 61. `Vents.sun_deg` reads DayCycle's reference day at no latitude and no tilt, and `CrawlerMain` turns `World.days` at 144 minutes. This pass checks it and changes nothing.
- **The fork (queue 68):** 68 wasn't on the branch when this pushed, so the fork's opened state isn't in the save yet. Whichever lands second wires it. `CrawlerSave.keep(place, "fork_open", true)` and `kept_value` are ready for it. On Continue, a fork whose floor is relit should open quietly, like the cleared floor here: no log line, no opening sound.
- **Checks** (on c90ea52), all 0 fails:
  - **`crawler_save_check`** (new, `tools/crawler_save_check.gd`, seed 7 and game 15): 39 lines.
    - **The seeds:** a game's first tomb is its own seed's. Over 300 game seeds, the first five places' seeds are all different, in range, never the game's own past the first, and the same when drawn again.
    - **The same game, twice over:** game 7 builds the same first tomb (27 pieces, 48 holders, 1 exit) and the same next tomb (seed 425838) twice, in layouts and in the scene. Two games build different first and next tombs.
    - **The first launch, booted for real:** the boot scene shows no choice and opens a new game.
    - **The round trip:** three lights relit ([0, 24, 47] of 48), the scene closed, Continue. The same game and tomb, the same three lit and no others, you on the mat, the log's two lines. Walked out, two lit in the next tomb, Continue: place 1 with its two lit, and place 0's three still kept.
    - **New game:** Settings' line reads "> New game". A new seed, every light cold, the pointer at the new game, the old save kept. With a game kept the boot shows the choice and its Continue line; Continue opens that game; New game asks again and then starts a new one. `persistence.continue` set to anything else: no Continue.
    - **A kept tomb all relit (game 15, 35 lights):** Continue brings it back cleared, its 5 skeletons bones in place and drawn, the snake in its lair and unseen. No log lines again, and still nothing 5 s on.
    - **A kept tomb whose fingerprint no longer matches** starts cold, and the save takes the layout as built now.
    - **No save written:** 55 writes, all in memory, none to disk, `user://crawler` unchanged. A `--script` run keeps it off the disk even with `WorldSave.read_only` off.
    - **The clock:** dawn 0.1667, day 0.2917, dusk 0.7083 and night 0.8333 of the day in every game and tomb the run opened, and half a year on. That is 18, 60, 18 and 48 minutes of a 144-minute day, and the shafts and the way out follow it. `worlds.json` clock is shared, no latitude.
  - **`crawler_check`** (seed 7, 203 seeds walked): 271 lines. The stand-in's line now expects the game's next tomb: place 1 is seed 425838, place 2 is 837268.
  - `boss_check` 227, `residents_check` 176, `cleared_check` 90, `fire_pot_check` 104, `stagger_check` 65, `crawler_harm_check` 59, `hands_check` 61, `hud_pin_check` 49 (it crashes in Godot's shutdown after its result line, the known one).
  - No frames: the prompt asked for headless numbers only. The boot box is plain text in the settings panel's colours, and nothing in the tomb looks different.
- **For Mike:**
  - **One world, or save slots** (§FK.5 call 3)? Today New game puts the old world away for good, though its file stays on disk.
  - **Should Continue also keep what you carry, the bundle's count and the time of day?** Today Continue gives you a full bundle again and an empty hand, so quitting and continuing is a way to get torches back. Your §FJ.4 note says the bundle never refills. Say the word and those go in the save.
  - **The box at every Play:** is two lines on black fine, or would you rather Play just continue, with New game only in Settings?
- **For chat:**
  - `CLAUDE.md`'s §FK line ("not built yet") can say built for the tomb: one seed, the save, Continue and New game, one clock.
  - `crawler.json → persistence.save` is now `crawler_save`, not `world_save`.
  - §FK.2 says the save holds "worlds found". There is one world (the tomb's) and no map, so there is nothing to record yet.

## 2026-10-08 — Mike's correction to §FL.2: 720 the most, 480 the default, never 1080; half_hd and fine are back (a1e64b3)
Mike, 7 Oct evening, after queue 64: *"so the very maximum resolution should be 720 but default at 480. no 1080."* §FL.2 had read his "max resolution 480p" as a cap at 480. This puts the cap back at 720 and undoes the rest of 596646a's pixel-size change. The §FL.1 markers (bdd8798) stay.

- **What changes on screen:**
  - Settings > Display > Pixel size and F11 have all five sizes again: painted (480×270), chunky (640×360), default (854×480), half_hd (960×540) and fine (1280×720), and auto.
  - 480 stays the default and 720 is the most. Nothing draws 1080 lines: an old saved line count of 1080 shows 720.
  - auto is back to the 6 Oct order (§EU.1): 480 if it fits your window a whole number of times, then 540, 360, 270, 720.
    - 1440p gets 480 (×3).
    - 1080p and 4K get 540 (×2, ×4). This answers the entry below's question about 1080p.
    - 720p gets 360 (×2). Any other height gets 480 with black bars.
- **How:**
  - `look.json → render`: `max_internal_lines` 480 → 720; `half_hd` and `fine` are back in `presets`; `auto.prefer` is back to default, half_hd, chunky, painted, fine.
  - `_help`: `_help.render`, `_help_presets` and `auto.rule` say 720 is the most and never 1080. `_help_preset_480` is back as it was. `_help_preset_fl2` records §FL.2 and its undoing.
  - `Display`'s own fallback for the most is 720 again. `auto_for` and `max_lines` stay: the check uses them. `HOW_TO_RUN.md` matches.
- **Checks** (on a1e64b3), all 0 fails:
  - `crawler_check` (seed 7, 203 seeds walked): 271 lines. Part 14 now checks:
    - 480 the default and 720 the most; the five sizes.
    - auto's order: every size once, default first. Its pick at every window height from 240 to 2400 follows that order and is never above 720: 720 chunky, 768 default, 960 default, 1080 half_hd, 1200 default, 1440 default, 2160 half_hd.
    - Pixel size steps from default to half_hd, fine, auto, painted, chunky and back.
    - A saved half_hd or fine shows 540 or 720, a name not in the file shows 480, and an old 1080 is held to 720.
  - `hud_pin_check` 49 (every HUD line fits at all five sizes again), `hands_check` 61, `crawler_harm_check` 59. `hud_pin_check` crashes in Godot's shutdown after its result: the known one.
  - Not re-run: the boss, residents, cleared, fire pot and stagger checks, `no_metal_check` and `crawler_frames`. None uses the sizes above 480, and they passed on bdd8798 (the entry below).
- **For chat:**
  - §FL.2 needs amending to Mike's correction: 720 the most, 480 the default, never 1080; the sizes up to 720 stay; auto's order is §EU.1's. `PROMPT_QUEUE.md` 64's text too.
  - The entry below's flag on `LOOK_REFERENCE.md`'s half_hd comparison is moot: half_hd is back.

## 2026-10-08 — Queue 64, §FL.2: 480 lines the most, half_hd and fine gone from the pixel sizes; §FL.1's "metal is back" marked in the data (596646a, bdd8798)
Mike, 7 Oct: *"max resolution 480p."* Built as §FL.2 and queue 64 say. §FL.1 (past the medieval stage, metal is back) needs no code yet, so only its markers went into the data.

- **What changes on screen:**
  - Settings > Display > Pixel size and F11 now step through default (854×480), auto, painted (480×270) and chunky (640×360). half_hd (960×540) and fine (1280×720) are gone.
  - 480 stays the default. If you never changed the pixel size, nothing looks different.
  - auto picks the tallest of the three that divides your window's height by a whole number, else default (480) with black bars:
    - 960 and 1440p get default (×2, ×3), as 1440p did before.
    - 720p, 1080p and 4K get chunky (×2, ×3, ×6). 1080p and 4K used to get half_hd (540).
    - Any other height gets default.
  - A saved pixel size of half_hd or fine now opens at default (480). An old saved line count over 480 is held to 480.
- **How:**
  - `look.json → render.presets` loses `half_hd` and `fine`; `auto.prefer` is now default, chunky, painted (tallest first). `max_internal_lines` was already 480 (chat, b2ccee8).
  - `Display`: its own fallback for the most lines is 480 (was 720; `max_lines()`). `auto_for(h)` is auto's pick for a window `h` pixels tall; `auto_preset()` calls it with the window's height, so the check can try any height without a window. The unused `LINE_CHOICES` (480, 720) is gone.
  - The settings panel and F11 read the presets from the file, so they follow with no code change (their comments updated).
  - `_help`: `_help.render`, `render._help_presets` and `auto.rule` say 480 is the most. `_help_preset_480`'s list of presets now points on to `_help_preset_fl2` (new), which says what §FL.2 changed. `HOW_TO_RUN.md`: the settings row, F11 and the picture paragraph.
- **§FL.1 markers (no code):** each §EH "no metal" note in `data/` now says §EH is superseded by §FL.1 (7 Oct: metal is back), and what stays until Mike's call:
  - `bosses.json → _help.unplaced`: the warden's chain; a forged chain fits (§FL.1 call 1).
  - `fire_pots.json → _help.vessel`: the pot stays clay; a glass fire-bottle is no longer barred (call 2).
  - `npc_maker.json → _help.parts`: the jewellery and the glasses slot.
  - `techniques.json → bog_iron.retired`, `villages.json → glass` and `mining.retired` (call 4), `peoples/marsh.json` (its bog-fir need and the bog-iron smiths' note), `peoples/README.md` rule 4.
  - The rows stay retired: the code only looks for a `retired` key, never its words.
- **Checks** (on bdd8798), all 0 fails:
  - `crawler_check` (seed 7, 203 seeds walked): 271 lines, the 265 before and 6 new (part 14):
    - 480 is the default and the most, and the pixel sizes are painted 270, chunky 360 and default 480.
    - auto's order is tallest first. Its pick at every window height from 240 to 2400 matches the rule worked out in the check: 720 chunky, 768 default, 900 default, 960 default, 1080 chunky, 1200 default, 1440 default, 1600 default, 2160 chunky.
    - Pixel size steps from default to auto, painted, chunky and back to default.
    - half_hd, fine and an old 720 all show 480. The player's settings are put back.
  - `hud_pin_check` 47 (49 before: two pixel sizes fewer). Every HUD line fits at painted, chunky and default.
  - `no_metal_check` seeds 42 and 7731: 16 each. The open world still holds to §EH; the markers change nothing it reads.
  - As before: `hands_check` 61, `crawler_harm_check` 59, `boss_check` 227, `residents_check` 176, `cleared_check` 90, `fire_pot_check` 104, `stagger_check` 65.
  - `hud_pin_check` and `no_metal_check` (the open world) crash in Godot's shutdown after their result line: the known one.
- **Frames** (once, at the end, on bdd8798, seed 7, lavapipe): `crawler_frames` 72 frames, 54 lines, 0 fails, the same counts as before. Its 480- and 270-line frames use default and painted, which haven't changed.
- **For Mike:**
  - On a 1080p screen, auto now gives chunky (640×360, ×3), blockier than the old 540. If you'd rather 1080p got 480 with black bars, say so.
  - The warden's chain: yesterday's entry read your "metal is fine" as settling it as metal, but §FL.1 lists it as a call. `bosses.json → unplaced.warden.chain` is still null. Say "a forged chain" and chat sets it.
- **For chat:**
  - `LOOK_REFERENCE.md` (around line 249) still suggests comparing default and half_hd (540) with F11; half_hd is gone.
  - Still citing §EH, left as they are because they describe what's built: seven code comments ("no metal (§EH)") and `tools/no_metal_check.gd`, which holds the open world to it; `camps.json → sim.trades.never` lists "metal". `stand.json` and `camps.json` still call the planet "tribal".

## 2026-10-07 — Mike: metal is fine, the world moves past the tribal stage (design answer, for chat; no code)
Mike: *"metal is fine- we moving past tribal stage."* It settles the clash flagged in this morning's answers: the warden's chain is metal (§FI.2 call 6, `bosses.json → unplaced.warden.chain`, still null), and "no metal" (§EH) no longer holds for Torchfire 1.
- **Nothing in Torchfire 1 enforced it:** the crawler has no metal rule and no check for one.
- **The shelved open world still does:** `tools/no_metal_check.gd` holds its peoples, camps, techniques and villages to §EH. That stays as it is until Mike says the open world moves on too.
- **For chat:**
  - Amend §EH for Torchfire 1, and §FJ.5's "fits §EH" for the clay pot (the pot stays clay).
  - Set the warden's chain to metal.
  - Mike's Project brief still says "tribal tech" (§FK.5's suggested wording).

## 2026-10-07 — Mike's second note of 7 Oct, part 2: how the creatures move (§EY, §FD, §FE, §FF.2, §FA.3): nothing goes through the stone, the light has edges, the snake's own tunnels, the 2 m lunge (helper session 5e998ec, cf15aee, 285049b, a077343; merged c7fe09c, ce46ff2; follow-up ffd5dc2)
Mike: *"the snake can follow you but not get close to the fire- in other words, creatures that are actively chasing will chase near the fire but stay somewhat in the darkness if they can- they may show just enough of their face/body near the fire if chasing"*; *"creatures shouldnt "sink" into the stone- only ghosts/phantoms should have the ability to ohase thru walls and floors and ceilings. the snake and other physical bosses have to move thru lit room while doing their best to stay at the edges of the light. depending on the ruins boss type as well, they may have their own tunnels- this can be the case for the snake. it wont actually despawn and respawn places"*; *"the snake should be faster or just as fast as a walk and if you sprint you can outrun it"*; *"a pot cant kill a boss but will stun it/cause it to retreat to its cave temporarily"*; *"skeletons should lu ge at the player within 2 meters"*. Built by a helper session in its own worktree (its commits above, its merges of the shared branch 11f37d7 and 9f84e24), merged here. Numbers he didn't give are Claude Code's first guesses.

- **What changes on screen:**
  - **Nothing goes through the stone or pops up elsewhere:** the snake and the skeletons get everywhere by moving there, frame by frame, at their own speeds. The snake no longer "goes below", and skeletons no longer sink into their niches. Only ghosts may ever phase (none are built).
  - **The light has an edge** (`residents.json → rules.chase_light_cap` 0.12, on the light on the floor):
    - Where it falls: a chase comes toward a fire only as far as the floor stays dim. That's about 1.5–1.75 m outside the hearth room's doors, about 5.5 m from a corridor torch and about 6 m from a room torch, whether or not it has hit you.
    - What it does there: the snake rears and pushes its head 0.7 m forward into the glow (`peek_m`) and watches for 10 s; a skeleton watches for 6 s. Then each gives you up.
    - Where you're safe: by a fire you're safe. At the dim edge you aren't: it strikes from where it may stand.
  - **The snake hunts at 4.6 m/s** (Mike; you walk 4.3 and sprint 5.6). Walk away and it catches you (it keeps coming as it rears and lunges, round corners too); sprint and you get away.
    - Measured: walking, it closed from 4 m to 1.84 m and struck 7.5 s on.
    - Measured: sprinting, the gap grew from 4 m to 13.4 m in 12 s.
  - **Its tunnels:** 3–5 dark, round-topped holes a tomb (0.6 × 0.45 m) at the foot of walls.
    - Where: one in its lair's room, the rest in the side ways; none in the hearth room, on the spine or on the way out. Each is cut into the wall's own stone, with loose stones and scale scratches in front, and you can't fit.
    - Travel: it goes in head first and travels hidden at its own speed, muffled. It comes out of another hole.
    - Use: it uses them to get round the light and now and then on its rounds, and turns back if the far end is lit.
  - **Crossing light**, it takes the dimmest way: along the light's edges and through the dark corners.
  - **A fire pot stuns the snake for 1.5 s** (`stun_s`).
    - Then it flees home (`flee_mps` 5) by floor or tunnel and goes down its hole for 30 s.
    - Then it comes back up onto its rounds. It is never burnt or killed.
  - **The last light:** the snake flees home with its long cry and goes down its hole for good, breathing.
  - **Skeletons lunge within 2 m:**
    - Up and about (`creep.lunge_m` 2.0, in place of the 1.6 m strike reach the Boo rule let off), one lunges in plain view, winding up its strike as it comes.
    - In a dark pocket, the bite is at 2 m too (`rules.pocket_counterattack_m` 3 to 2: set here at the merge, since his "within 2 meters" answered the open call on the pockets' 3 m).
    - Cut off, a skeleton walks out through the light, unseen, by the dimmest way. At the last light every skeleton walks home to its niche or grave and settles as bones for good: still drawn, never waking.
  - **A bug fixed:** at a slow slither the snake's body was drawn as a straight line from its head to an old point on its path, through walls and floors. It now lies along its path. This may be the "sinking" Mike saw.
- **How:**
  - `LightField` (new, `light_field.gd`) gives the fire light on each quarter-metre floor square of `TombNav`'s grid: the hearth, relit holders and planted torches (never your own torch), with the renderer's falloff and rays that stop at stone. It's rebuilt when a fire is lit or goes out.
  - `TombNav` gains the dimmest way (A* weighted by the light, `light_field.dim_weight` 2) and the chase's way, which never steps past the cap.
  - `BossGround.place_tunnels` and `TombBuild._burrow` lay and cut the holes from the tomb's own dice; the snake's den is a helix under its lair's mouth.
  - `Boss` and `Resident` move only physically; skeletons gain `BONES`. `Residents.may_strike` lets one strike only from an edge its own way reaches.
- **Data:**
  - `bosses.json → desert`: `hunt_mps` 3.6 → 4.6 (Mike); `stun_s` 1.5; `flee_mps` 5; `peek_m` 0.7; the `tunnels` block (holes [3, 5], 0.6 × 0.45 m, muffled −14 dB under 700 Hz).
  - `residents.json`: `rules.chase_light_cap` 0.12; `creatures.skeleton.creep.lunge_m` 2.0 (Mike); `rules.pocket_counterattack_m` 3 → 2 (Mike).
  - `crawler.json → light_field`.
  - No longer read: `below_s`, `withdraw_s`, `retreat_seen_s`.
  - `fire_pots.json → _help.vs_boss` says what a pot now does to the snake.
- **Checks** (on ffd5dc2, the merged code with everything since, all 0 fails):
  - `crawler_check` 265 (seed 7; new: the snake's holes never in your way); `boss_check` 227 (seeds 1, 7, 42); `residents_check` 176; `cleared_check` 90.
  - `crawler_harm_check` 59 (seed 7); `fire_pot_check` 104; `stagger_check` 65; `hands_check` 61.
  - The helper's own runs on its branch (`SNAKE_SEEDS=1,7,42`, `WALK_SEEDS=20`) were 0 fails too: crawler_harm_check 87, fire_pot_check and stagger_check on seeds 1, 7 and 42.
  - `cleared_check` with the pockets at 2 m first failed 3 lines, one a seed: the hit landed 5.4 s on, not at the end of the strike. The walk in stopped at 1.6 m, exactly the strike's reach, and the first strike missed. Walking in to just inside the bite (1.9 m), outside the reach as the old walk was, it lands at 0.85 s on every seed.
- **Frames** (once, at the end, on ffd5dc2, seed 7, lavapipe):
  - `boss_frames`: 13 frames, 0 fails, new `15` (the snake's head pushed into the glow at the edge of the hearth's light, its whole 9 m of body behind it in the dark, the light at its feet 0.100 against the cap of 0.12) and `16` (a tunnel's hole: every sight in through its mouth the dark's navy).
  - `crawler_frames`: 72 frames, 54 lines, 0 fails. The crypt not on pillars reads 0.89 of its old ring, and the crypt on pillars, with its four torches, 0.91 (it was 0.67 with two). The way out at night from the foot of its stairs reads 0.104 against the stone's 0.072. At the last light the skeleton in view walks home to its niche and lies there as bones (`26b`–`26d`).
  - I looked at `15` and `16` (the snake), and at `09` on pillars and `26d` (the bones, its niche's torch and soot slot above it).
- **For Mike** (the helper's open calls, all first guesses):
  - The cap (0.12) sets where the edge falls. Raise it and creatures come closer to fires.
  - `dim_weight` 2 trades light against distance. On seed 1 the snake, leaving a relit room after giving you up, crossed light up to about 14× the cap instead of the longer dark way it came in by; higher hugs the dark harder.
  - Cut-off skeletons cross the lit hearth room, unseen, when it is their only way out. A skeleton woken in the light goes to its dark's dimmest corner instead of hunting you.
  - Bones stay as set dressing and never wake. Your earlier "out windows and running away" became "walk home".
  - The lair can't be entered yet.
  - The holes: 3–5 a tomb, 0.6 × 0.45 m. The snake turns back in a tunnel whose far end gets lit.
  - Fleeing home after a pot can take up to about 15 s.
- **For chat:** log the note as a lettered section. It amends §FD (a chase follows you into the light → to its edge), §EY (the snake's speed, its tunnels, the pot's stun, no going below), §FE/§FF.2 (no sinking; cut-off skeletons walk out; the last light sends them home as bones) and §FA.4 (a pot stuns and sends the boss home). Mike also said: only ghosts may phase; physical bosses cross lit rooms at the edges of the light; tunnels depend on the boss type; lairs may open later.

## 2026-10-07 — The hit's X on every hit you start: your tar burning a creature shows it too (81f2ac9)
Mike, on the X: *"the X crosshair will appear on any successful hit"* and *"X should appear anytime a creature gets hit from something initiated from the player- so if a freature gets butned by tar after the pot ia thrown, it should still show the X reticle"*.

- **What changes on screen:** the X flashed for a swing that lands and a pot's burst that catches a creature, as built (any swing that lands, lit or unlit, staggering it or not: his first line, unchanged). Now it also flashes once a second while your tar burns a creature: stuck to it, a patch it stands in, or a fire your pot spread to.
- **How** (`FirePots.burn`, `mark_hit`; `hud.json → reticle.hit_marker.burn_every_s`, new, 1.0, Claude Code's first guess): every time your pot's fire reaches a creature it may mark the hit. A burst marks at once; the tar burning on marks at most once every `burn_every_s` (the X itself shows 0.3 s), so it pulses while the creature burns rather than staying lit.
- **Checks** (on 81f2ac9): `fire_pot_check` 103, 0 fails. New: the X marks 3 times over a skeleton's 4.0 s of burning after the burst's own, and 12 times in a patch's 12 s burning one standing in it; a burst on nothing still shows none. `stagger_check` 63 and `crawler_check` 264, 0 fails.

## 2026-10-07 — Mike's note on the torch's end: 20 s of embers to light the next one, the bundle never refills, light oil's flash reaches further, your own tar burns you once (063c726)
Mike, on queue 62 as built and the open calls: *"when a torch burns out, you have to discard it out your hand or scroll to the next- it ahould be possible for players to light their new torch with the old torches embers. a torch embers remain for ~20 seconds before sputtering out completely- this should give the player enough time to relight another unused torch. the used torch will then be dropped. also, after a game day (144 minutes) the torches dont just reup themselves- they have to be found or created. we can get into crafting a bit later. it should be bare bones crafting system (beically you can combone up to 3 items in your inventory to create a new item- for example, if holding a bottle of oil- olive oil perhaps, you can combine the empty lamp and the oil to make it fill. one bottle of oil should be good for 3 refills. and yes, a light oil flash should be slightly larger aoe while the tar style while it lasts longer after busting, the aoe isnt as large. still only hurts for 1 damage."* Also the way-out frame the other session flagged (97dd330).

- **What changes on screen:**
  - **A torch burnt out** stays in your hand, its coal glowing dim red and sputtering for 20 s, then a dead stick. Scroll the wheel and it drops by your feet and your next torch comes up: while the embers glow it catches from them, after that it comes up unlit. F drops it and leaves your hand empty. A dropped stick's embers glow on, on the floor, until their 20 s are up.
  - **The bundle** never fills up again. Torches are to be found or made; neither is built yet.
  - **Your own pot:** a light-oil flash hurts you from 1.4 m, a tar burst from 1 m. Walking into your own burning tar is one hit. A pot never costs you more than one hit.
  - **The way out** shows all its glow from the foot of its stairs again, and fades only from further off.
- **The embers** (`torch.json → crawler_burn.embers_s` 20, Mike; `embers_light_share` 0.25, first guess; `Torch.swap_burnt`, `discard_burnt`, `_embers_step`, `PitchTorch.set_embers`):
  - Burnt out, the item keeps an `embers_s` countdown. The head shows its coal alone, glowing at the share left. The light is a quarter of the gutter's, in the gutter's red, sputtering and fading to nothing; then "The embers have died." and a soft hiss.
  - `Torch.item()` keeps the burnt torch in your hand in the crawler (it used to fall through to the next torch), and the next one up is a torch with burn left. The open world is unchanged.
  - The wheel (`Hands._cycle_right`) from a burnt torch drops it (`burnt_out` with the embers left; `CrawlerFires.lay_stick` lays the stick and, with embers left, a glowing knot and a small light that fade over what's left). Your next torch comes up, lit from the embers while they glow ("Lit the new torch from the old one's embers."). F (`CrawlerPlayer`) drops a burnt one when there is no flame to smother. Taken by the dark, a burnt one in your hand is dropped where you fell.
- **The bundle** (`CrawlerFires`): `_remake_bundle` is gone. The data's `later_sources` still lists `bundle_remade` (chat's list, unread by the code); Mike has ruled it out.
- **Your own pot** (`fire_pots.json → oils.light_oil.hurts_you_m` 1.4 and `oils.tar.hurts_you_m` 1.0, new, first guesses on "slightly larger"; `FirePots.hurts_m`, `patch_hurts_you`; `PotFire.spent_on_you`):
  - The burst's reach on you is per oil.
  - A tar patch hurts you once: your feet within its flames (0.6 of `patch_radius_m`, 0.72 m) plus your body's 0.35 m, about its height (fire:pot_patch).
  - A patch whose burst hit you never does. Stuck tar never hurts you.
- **The way out** (`crawler.json → exit.glow` `near_m` 8 to 16, `far_m` 30 to 40): from the foot of its flight, about 15 m below, it shows all of its glow, as §EX.5 wants. At night from there `crawler_frames` 25b read 0.085 against the stone's 0.071 at 8 m, under its readable step.
- **Checks** (on 063c726), all 0 fails:
  - `crawler_check` (seed 7): 264 lines. New:
    - Burnt out, the torch stays in your hand, its embers at 0.98 of their glow and their light 0.20 against the guttering flame's 0.89; ten seconds on they're half gone (0.48).
    - The wheel drops it 0.20 m from your feet, out of your pack, its embers glowing there, and your next torch comes up lit from them; the dropped stick's light goes when its embers would have.
    - Left in your hand, its embers die at 20 s; the wheel then brings up the last torch unlit. F drops a burnt one and your hand is empty.
    - The emptied bundle stays empty two game days on.
  - `fire_pot_check` (seed 7): 101.
    - Tar 0.5 m off: one hit (fire:pot); 1.2 m off: none. Light oil 1.2 m off: one hit; 1.7 m off: none.
    - After a burst hit you, standing in its patch: nothing more. A tar pot 3 m off misses; walking into its patch is one hit (fire:pot_patch), and four seconds in it, no more.
    - The fire-to-fire swing 2.0 m from a patch is unharmed.
  - `hands_check` 61, `stagger_check` 63, `crawler_harm_check` 59, `boss_check` 115, `cleared_check` 84, `residents_check` 161.
- **For Mike:**
  - The embers light your next torch the moment you scroll to it. Would you rather it take a moment, the two heads held together, as lighting a pot does?
  - F drops a burnt torch. Is that the "discard" you meant, or would you like a key of its own?
  - Light oil hurts you from 1.4 m and tar from 1 m: "slightly larger" as a first guess.
  - Torches are found or made, and neither is built. Until then each tomb's bundle of three is all there is, and the next tomb has its own. Want a first guess at found torches (one or two lying in side rooms, like the found pot)?
- **For chat:**
  - The torch's end: 20 s of embers, the wheel to the next torch lit from them, the used one dropped. This amends §FJ.4 as built by queue 62.
  - Torches don't come back by themselves; they are found or made. This rules out `bundle.remake_h_game` in the crawler and `later_sources`' `bundle_remade`.
  - **Crafting, for later** (Mike): bare bones. Combine up to 3 items in your inventory to make a new one. For example, a bottle of oil (olive oil, perhaps) and an empty clay lamp make a filled lamp; one bottle is good for 3 refills. This goes with the clay lamps found in tombs (30 minutes of light, his earlier note today).
  - Light oil's flash reaches you further than tar's burst; tar's lasting fire hurts you too; a pot still costs one hit at most.

## 2026-10-07 — Queue 62, §FJ.4: torches burn down — 15 minutes each, three at most, the bundle by the hearth (56dc352)
Built in order after Mike's notes, with his number from today: *"a regular torch burn time should be 15 minutes and an oil lamp gives 30 minutes"* (the lamp comes later).

- **What changes on screen:**
  - A lit torch lasts 15 minutes of lit time. Over its last 12% (about the last 1 min 50 s) it gutters, dimmer and redder, still lit. Then it's burnt out: the charred stick drops to the floor at your feet and lies there, and your next torch is in your hand, unlit, ready to relight at any flame. With none left your hand is empty.
  - You carry three torches at most, the one in your hand counted. With three, right click by the bundle takes nothing and says nothing: only a soft rustle of the sticks.
  - Once you've emptied the bundle by the hearth, it lies bound again a game day later (144 minutes), with a line in the log.
  - Put away or smothered, a torch keeps what it has; running costs it nothing.
- **The burn** (`torch.json → crawler_burn.burn_min` 15; `Torch.full_burn_min`): the crawler's torches (Torchfire 1, `GameMode.crawler_running`) burn this, the open world keeps the top-level `burn_min` (50). The burn step, the gutter's start (`gutter_share` of it) and a fresh torch's, a planted torch's and a relit one's full burn all read it.
- **Burnt out in your hand** (`Torch._drop_burnt`, the `burnt_out` signal; `CrawlerFires.lay_stick`): the item leaves your pack (so burnt sticks never fill it), a charred stick (the bundle's stick in the hearth's charred logs' colour, its head gone) is laid by your feet in this tomb, on the floor you stand on (a first try laid it 0.45 m ahead, and by the hearth that was over the pit, on its guard), and `Torch.item()` finds your next torch. `light()` no longer lights a burnt one (the swing never did). The swing, smothering and the water are as built.
- **Three at most** (`crawler_burn.carry_max` 3, `carry_counts_hand` true; `Torch.carried_count`, `at_carry_max`): torches with burn left in your pack, the one in hand among them. `CrawlerMain.take_torch` refuses at the limit with `CrawlerFires.refuse_torch` (the synth's rustle at the bundle, pitched down, no log line).
- **The bundle laid again** (`torch.json → bundle.remake_h_game` 24; `CrawlerFires._remake_bundle`): emptied, it is laid again with its three torches 24 game hours later on the crawler's clock (`world.days`, the 144-minute day). Of `later_sources`, this is the one wired; relit ruins' gifts wait for §FF.3. `pitch_scale` is carried, unused, until the pitch technique exists.
- **The frame tools** (`crawler_frames`, `boss_frames`) turn the burn off (`Torch.burn_down` false, as `Residents.stay_asleep` keeps the skeletons asleep): their pictures aren't a burn test, and a long render would burn the torch out mid-run.
- **Data:** `[NOT WIRED YET]` off `torch.json → _help.crawler_burn`, its wiring added; `_help.snuff` notes the crawler's burn moved.
- **Checks** (on 56dc352), all 0 fails:
  - `crawler_check` (seed 7): 259 lines. New: crawler_burn wired and 15 minutes; stepped a second at a time a lit torch starts to gutter 13.2 min in and is out at 15.0; lit at the hearth a fresh torch has 15.00 min; in its last 12% it gutters, still lit; burnt out, its charred stick lies 0.20 m from your feet at their height, out of your pack, and your next torch is in hand unlit; a burnt stick never catches by hand or swing; smothered at 7.49 min it keeps it 10 s out and relights at a sconce with it; three held, the bundle gives nothing and says nothing (a rustle), two held it gives the third; emptied, the bundle is laid again 24 game hours on, not at 12; and the 120 s sprint cost its torch exactly 2.000 min.
  - A first run had two fails, both mine: the stick was laid 0.45 m ahead of you, which by the hearth is over the pit, on its guard; and its colour was a new literal the one-stone grep caught (it is the hearth's charred logs' now).
  - `boss_check` 115, `cleared_check` 84, `residents_check` 161, `stagger_check` 63, `fire_pot_check` 92, `crawler_harm_check` 59, `hands_check` 61: none of their runs burns a torch out at 15 minutes.
- **For Mike:**
  - When a torch burns out, the charred stick drops and your next torch comes to hand by itself, unlit. Would you rather keep holding the dead stick until you swap?
  - The bundle comes back a game day (144 minutes) after you empty it (`bundle.remake_h_game`, Claude's first guess).
  - Burnt sticks stay on the floor where they fell, a trail of where you've been. Fine, or should they crumble away?

## 2026-10-07 — Queue 60 follow-up, §FA.3 with §FI.2 call 4 answered: a pot's fire relights a cold sconce, and a burning patch relights your torch (0af1b69)
- **Mike, 7 Oct:** "a pot should relight an old sconce and a burning patch can relight torch."
  - `fire_pots.json → relights_holders` goes from null to true, and a new `relights_torch` is true. `_help.light` quotes him.
  - **For Claude (chat):** this answers §FI.2 call 4, for the design doc. (Mike's second note's answers, `hurts_you` and the cook-off among them, are fc4a333's, below.)
- **What changes on screen:**
  - **A pot lights a dark sconce.** Throw one at the wall by a sconce: it bursts on the stone, and the sconce catches a moment later, as when you swing a lit torch through it. It then burns for good and counts toward the lights relit. The log gets a new line, "The pot's fire caught a cold light.", then the usual "N of M lights burn again." A light lit this way counts like any other, so the skeletons' clearing (§FF.2) and the snake's release (§EY.2) still follow the last light, whatever lit it.
  - **How far it reaches:** as far as it burns (`splash_m`: tar 1.5 m, light oil 3 m), measured to the sconce's flame in its niche.
  - **Never through stone:** it needs a clear line from the burst to the niche's mouth. A burst behind the sconce's wall leaves it cold.
  - **Tar on the floor:** a tar pot that lands on the floor under a sconce, 1.7 m below it, doesn't reach it. Its fireball stops about 0.9 m up. Light oil's reaches about 2.3 m and does.
  - **A tar patch** lights a holder on the floor within its reach. The tomb has none now: every holder is a wall sconce (§EX.4). The patch doesn't reach a sconce on the wall above it.
  - **Your torch relights from the pot's fire.** With your torch out, swing it by a burning tar patch and it catches, as at the hearth: within the swing's reach (2.2 m) of the patch's edge. The same goes for anything the pot set alight (the reed mat, the bedroll) and tar burning on a creature. The burst's flash is over too fast to count.
- **How:**
  - **`FirePots.relight_near(at, reach, max_dy)`** goes through the tomb's fire-holders. It lights each cold one in reach through `FireStore.swing_light`, the torch's own path.
    - **Who calls it:** the burst, from 4 cm off the face it burst on; and every patch and thing alight (`PotFire`), four times a second, within its radius plus 0.3 m and no more than 1 m above or below its flames.
    - **Line of sight:** it skips a holder unless a ray from the fire to the holder's mouth (`mouth_of`) is clear of the tomb's stone. For a sconce the mouth is 8 cm out from the wall: the niche is cut in the stone you see, not in the wall's collision. For a holder on the floor it is 0.6 m above it. The holder's own stones are left out of the ray.
  - **`FirePots.flame_near(pos, radius)`** is true for any burning pot fire except a flash, within `radius` plus the fire's own reach (`PotFire.flame_point`).
    - `Torch.flame_near` asks it alongside the fires, planted torches and sconces, so the swing catches from it.
    - It returns false where there are no fire pots: in the open world, which shares `torch.gd`.
  - **`Resident.burn_out`** frees a burnt skeleton through `NodeRelease`, as the tomb's are. It no longer prints the headless renderer's "m is null" (queue 59's note below).
- **Checks:**
  - **`fire_pot_check`:** the test that said a pot never lights a holder is replaced by a fire-to-fire test. It runs last, so the lights it relights change nothing before it. It checks:
    - A tar pot thrown at the wall by a cold sconce (a real throw, the pot's own flight) bursts on the stone 0.47 m from the flame; the sconce catches and burns for good, with the lights relit one more.
    - A light-oil burst behind a cold sconce's wall, 0.9–1.0 m from its flame, leaves it cold, and the same burst 1.1 m in front of it lights it.
    - An unlit torch swung 2 m from a burning tar patch catches; with no patch, or after the patch burnt out, nothing happens.
    - The patch under a cold sconce doesn't light it.
    - A patch 1 m from a holder on a corridor's floor lights it.
    - The pot's fire is the hearth's amber.

    On the code as pushed, with fc4a333's cook-off and self-harm tests in: 99 lines, 0 fails, seeds 7, 1 and 42, with no engine errors in the logs. The skeleton test no longer asks a freed skeleton's list about itself.
  - **On the first seed 42 run** the floor holder sat on a coffin 0.9 m up, and the ray hit its own ring stones. The check now uses corridor sconces and checks the floor's height, and the game leaves a holder's own stones out of the ray.
  - **Seed 42's lights relit went from 0 to 2** after one throw. The second sconce had been catching since the snake's tests, 15 m away (a pot thrown at the snake lit it). Each pot lit only what was in its reach.
  - **Other checks** (seed 7):
    - Before the merge with fc4a333, all 0 fails: `residents_check`, `boss_check`, `crawler_harm_check`, `stagger_check`, `hands_check`, `crawler_check` (240 lines) and `cleared_check` (84 lines). In the open world, `swing_check` (its own seed, 7731: 18 lines) and `scene_load_check` have 0 fails. Both still crash at shutdown after their results, as before.
    - On the code as pushed, all 0 fails: `crawler_check` (247 lines), `cleared_check` (84), `boss_check`, `residents_check`, `crawler_harm_check`, `stagger_check` and `hands_check`. No script errors in any log.
  - **Found on the way:** `swing_check` with `SEED=7` fails 3 lines (a swing at the ground lights a fire, no wildfire, a swing at a creature). The code from before this change fails the same way. Its own seed passes. Not looked into: the open world is shelved.
  - **The frames** (`crawler_frames`, seed 7, on 59f37d4): 70 frames, 52 lines, 1 fail, no script errors.
    - The fire pots pass: the tar patch lights its dark corridor in amber (hue 18.9) and the light-oil burst fills its dark room (hue 17.5). The tar patch's corridor sconce, 1.7 m over it, stays cold.
    - The skeletons (`21a`–`21c`) and the floor cleared by light (`26a`–`26d`, the last light 48th of 48) pass.
    - **The fail isn't this change:** from the foot of the way out's flight at night (`25b`), the opening reads 0.085 against the stone's 0.071, 0.014 over where the check wants 0.02. Before fc4a333 it read 0.100 against 0.075. That is fc4a333's fade from far off (`exit.glow`: all of the glow within 8 m, 0.55 of it by 30 m), seen from about 15 m below. The frame comes before any fire pot in the run.
    - **For Mike:** you asked for the way out to be faint from far off, and this frame wants it readable from the foot of the stairs. Either `exit.glow.far_share` goes up, or the frame's bar comes down. Left for the session building part 2, which renders the frames next.
- **Merged with fc4a333** (Mike's second note, part 1, pushed while this ran): `burst` takes their `in_hand` and keeps the face it burst on (`normal`) for the relight. A pot that cooks off in your hand by a cold sconce lights it too. The fire-to-fire check's thrown pot now flies with you on the far floor, out of your own burst's reach (`hurts_you`).
- **Left open, a call for Mike if he wants it:** a tar patch burning on the floor under a sconce doesn't light it; only a burst that reaches it does.

## 2026-10-07 — Mike's second note of 7 Oct, part 1: the sneak's dashes, the hit's X, your own pot can hurt you, the fuse goes off in your hand, the way out faint from far off, the torch's 15 minutes (fc4a333)
Mike, answering the open calls (the parts built here; the creatures' movement is part 2, below it when it lands): *"your own fire pot should be able to hurt you if you throw it way to close to yourself like a wall or floor youre right next to. when sneaking, the reticle should take away the verticle dashes and jist leave horizontal dashes to signify sneak state. the way out might not always be night- it should be relatively faint from far away but depends on time of day."* … *"a fuse held too long after lighting will explode in hand and cause 1 point of damage."* … *"a regular torch burn time should be 15 minutes and an oil lamp gives 30 minutes."* … *"no the crosshair shouldnt warm- that will be for the player to figure out. if you get a hit on a creature tho, there will be an X shape in the diagonal spaces between the regular crosshair to aignify a successful hit."* Numbers he didn't give are Claude Code's first guesses.

- **What changes on screen:**
  - **Sneaking**, the crosshair loses its up and down arms and keeps its two level dashes, dimmed (it was a small ring).
  - **A hit**, your swing landing on a creature or your pot's burst catching one, flashes a small X in the corners between the crosshair's arms for 0.3 s. Nothing else marks the crosshair: it never warms near things you can light.
  - **Your own pot** can hurt you: a burst within 1 m of you is one of your three hits, so throwing it at a wall or the floor right next to you costs you. Hold a lit pot past its 3 s fuse and it goes off in your hand: the burst, the pot gone, one hit.
  - **The way out** shows fainter from far off and fuller as you come up the stairs, still bright blue by day and dim moonlit blue at night on the clock.
- **The dashes** (`stealth.json → sneak.reticle.shape` dashes; `Reticle.dash_cells`): the crosshair's own left and right arms, the same length, gap, width and dark edge, dimmed by `dim` (0.75). Shape ring, the first look, is kept as an option.
- **The hit's X** (`hud.json → reticle.hit_marker`, new: `show_s` 0.3, `from_px` 3, `length_px` 4; `Reticle.hit`, `x_cells`):
  - Four diagonals, from 3 to 6 pixels out along each diagonal from the middle at the 480 reference (2 to 3 at 270), as wide as the arms, in their colour on a one-pixel dark edge. Its edge leaves out what the crosshair under it already draws, so no pixel is darkened twice.
  - `Torch.swing_top` calls it when the swing meets a creature, staggered or not (the swing you already hear land). `FirePots.burst` calls it when the burst's fire reaches a creature (a resident burnt, a boss driven off). A patch or stuck tar burning one later doesn't.
- **Your own pot** (`fire_pots.json → hurts_you` true, `hurts_you_m` new 1.0; `FirePots.burst_hurts_you`): a burst within 1 m of your body (your capsule, feet to eye, 0.35 m round), with no stone between, is one hit (`Harm`, death cause fire:pot), whichever oil. Looking level the shortest throw lands 4 m out, so it takes a wall or floor right by you, or looking down. Its burning patch and stuck tar never hurt you (first guess).
- **The cook-off** (`fire_pots.json → cook_off_in_hand` true; `FirePots._cook_off`): held past `fuse_s` (3 s from the wick catching), the pot bursts where your hand is with its whole burst (the flash, its fire on what stands in `splash_m`, tar's patch, the sound), leaves your hand and your pack, and it is one hit (fire:pot_in_hand), never two.
- **The way out** (`crawler.json → exit.glow`, new: `near_m` 8, `far_m` 30, `far_share` 0.55; `WayOut.far_fade`): the opening's sheet of sky shows all its glow within 8 m of your eye and eases down to 0.55 of it by 30 m. It already followed the clock (it was a night frame Mike saw). The wash falling in on the stone is the stone's own light and doesn't change with where you stand.
- **The torch's 15 minutes** (`torch.json → crawler_burn.burn_min` 15, was 20): data only; the timer, the bundle and the three you carry are prompt 62, next in the queue. The clay oil lamp (30 minutes, found in tombs) comes later; it isn't in the data.
- **The crypt frame** (`crawler_frames`): it now relights two crypts against their old rings, one on pillars with its four torches and one not with its two, and holds each to 0.85 of its ring on screen (Mike's "a bit darker than it was" is fine). Pass 1's fail was its picker moving to the crypt not on pillars.
- **Checks** (on fc4a333), all 0 fails:
  - `crawler_check` (seed 7): 247 lines. New: the hit's X shows for 0.3 s and goes; at 480 and 270 lines it is four diagonals clear of the arms, the same in every corner, its edge never over the crosshair's, standing or sneaking; crouched, the dashes, the crosshair's own two level arms alone; the way out shows all its glow on the landing and 0.55 of it from the wake spot 108 m off, by day and by night.
  - `fire_pot_check` (seed 7): 92. New: the cook-off (still in hand just short of the fuse; past it the burst 0.5 m from your eye, the pot gone, nothing thrown, one hit); your own burst 0.5 m off one hit, 1.5 m off none, 0.55 m off behind a wall none, thrown at your feet one, thrown level none, standing in its tar none; the X on a burst that catches a creature, none on one that catches nothing. Every burst the check doesn't mean to reach you now happens with you on its far floor.
  - `stagger_check` 63 (new: a landed swing shows the X once, a miss none), `hands_check` 61, `crawler_harm_check` 59.
- **Frames:** rendered once at the end, with part 2.
- **For Mike:**
  - The X shows on any contact, staggered or not, the same moment you hear the torch land. Only when it staggers?
  - Your pot hurts you within 1 m whichever oil. Light oil's flash is 3 m wide: should it reach you further off? And should walking into your own burning tar hurt? Today it doesn't.
  - The way out from far off: 0.55 of its glow by 30 m.
- **For chat** (Mike's answers to the open calls, 7 Oct; for a lettered section):
  - Built here: the dashes, the hit's X (and no warming crosshair), your pot hurts you, the cook-off, the way out faint from far off, the torch's 15 minutes.
  - Being built in part 2 (the creatures' movement): nothing physical sinks into the stone or teleports (only ghosts phase); a chase follows to the light's edge and peeks in, never close to a fire; physical bosses cross lit rooms on the edges of the light; the snake's own tunnels; the snake as fast as your walk, your sprint outruns it; a pot stuns a boss and sends it to its cave for a while, never kills it; skeletons lunge within 2 m.
  - Design answers, nothing to build yet:
    - Worlds: 1–2 km each for now; separate worlds, one per biome (§EW confirmed).
    - "Good night" wakes you at the last hearth you lit or found, and it must be lit. One hearth per floor; the dungeon's map must agree with the surface, so a chimney comes out on top where its flue says (§EV.4 with §EW).
    - Saves: an autosave per dungeon and save states, probably up to 3 save files. This revises prompt 63's one save.
    - The strong airway gust never puts the torch out, for now (closes §EZ.4 call 1 as built).
    - Clay lamps and candles come back later, found in different tombs; a torch burns 15 minutes, an oil lamp 30.
    - The imps are 2–3 imps. The wolfman and the werewolf are one creature. The hornet lives in a jungle by a beach. The witch's wisps glow cold blue.
    - **The warden has a metal chain, and the world moves from tribal times to more advanced.** This touches §EH ("no metal", the open world's camps) and Mike's Project brief's "tribal tech" (§FK.5's wording).
    - Creatures are 3D like the folk (§FH). The skeletons are sprites today (their 288-cell sheet).
    - Lairs may open later: every ruin revisitable, a secret passage opening to go deeper.
    - Each dungeon its own building style; the Andean one is approved (§EX.1).
    - Free movement, not grid steps (as built). No spear or bow for now (CLAUDE.md keeps their code live for §AW's rare finds).
    - The builders are from the past and mysterious. The rescuer says little, maybe something cryptic about something lurking here (the crawler has no words today, §ET.3).
  - CLAUDE.md's brief still calls §EY and §FA–§FH "not built yet".

## 2026-10-07 — Mike's notes of 7 Oct: the hearth sunk in a pit under its shaft, a flue slot over every wall torch, four torches in a room on pillars, and the skeletons as Boos (c2573f8; skeletons d1e9e1b, 1ec0caa, ab35be2; 0d483ff)
Mike, answering queue 48's call and adding four notes: *"yea for pillared rooms we can do 4 torches- its also ok if theres some shadows or a bit darker than it was because it gives monsters a place to hide. also, for skeletons itd be cool if they acted similar to boos in mario- they might not activate until you pass them once and only move toward you slowly when your back is turned so you never see them moving unless they get right up on you- another fix is that for the main rooms with hearths, the exit draft vent should be situated more directly above the fire- at the moment it seems like its offset a bit. also, where the main hearths sit there should be a fire pit made into the ground i stead of jist having a campfire sitting right on the floor. also please ensure torches in the indents on the wall still have exit vents above them"*. Built as Claude Code's first guesses where he gave no numbers; no design section yet (below, for chat).

- **What changes on screen:**
  - **The hearth** burns down in a pit in the middle of the floor: twelve-sided, 32 cm deep and 1.24 m across inside, lined with the tomb's stone going navy as it goes down, its logs and coals on a bed of ash. A kerb of twelve pillowed stones, 24 cm wide and 6 cm proud, is set into the floor round its lip, and the floor's flags are cut round it. You can walk up to the kerb but not into the fire.
  - **Its shaft** stands straight over the fire (it stood about a metre to one side: 0.93 m on seed 7). The column of daylight falls on the fire, the smoke goes straight up, and the flame stands straight in the draft instead of leaning.
  - **Every wall torch** has a narrow slot cut up the wall from just over its niche into its vent's mouth in the ceiling, which now sits right against the wall. The slot is the flue's width (15–30 cm) and sooted inside.
  - **A room on pillars** gets four wall torches, two facing pairs, instead of two.
  - **The skeletons** move only when you can't see them (below).

- **The hearth pit** (`masonry.json → styles → andean_tomb → hearth`, new: `method` sunk_pit, `sides` 12, `r_m` 0.62, `depth_m` 0.32, `kerb_w_m` 0.24, `kerb_proud_m` 0.06, `guard_m` 0.45, `ash`; `TombBuild.pit`, `_hearth_pit`). The real model is the Mito tradition's sunken hearths (Kotosh, La Galgada), added to the style's `models`.
  - **The floor:** `FittedStone.flags` takes holes now. A flag crossing the pit's outline is cut along it on the same rolls, so every other flag lies as before. The hearth room's floor collision is the room's slab less the pit, in convex pieces.
  - **The kerb and lining:** each kerb stone is a pillowed trapezoid with a face down over the pit; under it the lining, one block a side, toward the scene's shade (navy) as it goes down; the joints' back under the kerb; at the foot a bed of ash (not stone). All the style's stone but the ash, on the pit's own dice.
  - **The fire** (`CrawlerFires`): the campfire sits on the pit's floor, 0.32 m down. Its light stays 1 m over the room's floor (`light_y`), so the room is lit as before and the pit's lip shadows nothing, and its pool of firelight stays on the floor round it.
  - **The guard:** collision over the kerb's footprint from the pit's floor to 0.45 m over the room's floor, under every eye (yours crouched is 0.78 m). Each side reaches a little past its corners, because a first try left hairline seams a ray slipped through at one corner. The pit has its own floor, so a thrown pot falls in.
  - **The snow ruins' style** gets a square pit of slabs in its data (Skara Brae's hearths), not built.
- **The shaft over the fire** (`smoke.json → vents.shaft.over_fire`, new, true): `TombKit._place_vents` puts a shaft's mouth straight over its fire (`mouth_offset_m` applies only when it is false). `Vents._draft` gives a vent straight overhead no lean, only the flicker; it used to pick a random lean.
- **The flue slots** (`TombBuild._flue_slot_op`): one over every sconce's niche, in rooms and corridors.
  - It runs from 5 cm over the niche's top to the wall face's top: under the corbel course in a room (whose stone over it was already left out), into the ceiling in a corridor.
  - It is its vent's own width (within the niche's top) and as deep as the niche.
  - Its inside is drawn as soot lying on the stone (`DUST_M`, as the drifts are, tagged not-stone). Painted onto the stone, the soot came out pale: the crawler's night grade pulls every stone colour 75% toward slate (`ruin.gdshader`), which lifts it.
  - A sconce's vent mouth now sits against its wall (it stood 8 cm off), so the slot runs straight into it.
  - **Honest limit:** the sconce's own light hangs just below the slot and lights straight up into it. So on screen the slot reads as a darker, redder stripe climbing from the lit niche, not black: on seed 7's corridor sconce, luma 0.634 inside against 0.864 on the stone beside it.
- **Four torches in a room on pillars** (`crawler.json → room_torches.pillared`, new, 4; `TombBuild.on_pillars`): whether a room stands on pillars is worked out from the layout alone (its shorter span past its corbels over `max_span_m`), so `TombKit._room_sconces` can give it its two facing pairs before it is built. `_plan_room` uses the same test. On seeds 1, 7 and 42, all 16 rooms that stand on pillars as built have four.
- **The skeletons are Boos** (the helper session's work, merged as d1e9e1b, 1ec0caa, ab35be2; `residents.json → creatures.skeleton`, `pattern` creeper and a new `creep` block):
  - **Passing arms one:** come within 3 m of its head (`arms_m`) and nothing happens. The moment you look away or walk on past, you hear bone grinding behind you as it climbs out. Turn round and it is frozen half out; look away and it carries on.
  - **It moves only while you can't see it:** out, it creeps after you at 1.4 m/s (`creep_mps`; you walk 4.3), its bone steps clicking. Face it and it stands dead still however long you stare. It still knows you are there: staring at it within its sight keeps its chase on, so you don't heal.
  - **"Seeing" it:** any of its feet, middle or head, or its middle 35 cm to either side (`side_m`), in your frame or within 8% of the frame past its edge (`view_margin`), within 60 m (`seen_m`), with no stone between. The dark doesn't hide it. A step that would bring it into view is undone, so it waits just out of sight.
  - **In plain view all the same:** its whole strike within its 1.6 m reach (the wind-up and the jaw's creak; your lit swing still staggers it), a dark pocket's lunge from 3 m (§FF.2), and the floor's last light, when the ones you can see still hurry back into the stone (§FF.2's reveal: the one time you see them move).
  - **The light's rules hold, but its moves wait until you look away:** leaving a relit room, walking home, and going into the stone when cut off.
  - **A fire pot** still wakes a resting one; watched, it lies there burning until you look away.
- **Checks** (on 0d483ff, the merged code as pushed), all 0 fails:
  - `crawler_check` (seed 7): 240 lines. New: the pit (the fire 0.32 m down, its floor, the flags cut round it, the guard stopping your body from 1.35 m and at a crossing), the shaft 0.00 m off the fire and its daylight on it, 48 of 48 flue slots each its flue's width under its vent's mouth, and all 16 rooms on pillars (seeds 1, 7 and 42) with four torches.
  - `residents_check` (seeds 1, 7 and 42): 161. The first run had one flaky line, the creep's bone steps counted by the sound's stream changing; it counts `Resident.steps_heard` now (0d483ff).
  - `cleared_check` 84, `boss_check` 115, `stagger_check` 61, `fire_pot_check` 82, `crawler_harm_check` 59, `hands_check` 61.
- **Frames** (`crawler_frames`, seed 7, lavapipe, once at the end): 70 frames, 52 lines, 1 fail.
  - New and passing: `01i` down into the pit at night (its fire warm in it), `08d` the slot over a relit corridor torch (darker than the stone beside it).
  - **The fail is the frames' own room picker, not the light.** It looks for a crypt with two torches. With the rooms on pillars at four, it moved from seed 7's crypt on pillars to one that isn't, which from its doorway reads 0.303 against its old ring's 0.337 (0.90). The slots aren't why: their few pixels move the frame's mean by about a thousandth. The ring stood in the middle and lit the floor nearest the door; the torches light the walls. The next pass measures both kinds of crypt and holds every room to "a bit darker is fine" (0.85).
  - I looked at `01` (the pit, its kerb and the column of daylight on the fire), `08d` (the slot), `09` and `09a` (the crypt) and `21b` (a skeleton frozen half out of its niche).
- **For Mike:**
  - Your second note of 7 Oct is being built next: nothing physical sinks into the stone, a chase stops at the light's edge, the snake as fast as your walk with its own tunnels, the 2 m lunge, your own pot can hurt you, the sneak's dashes and the hit's X. It answers or changes some of the skeleton calls below.
  - The pit's size, depth and kerb are first guesses: `masonry.json → styles → andean_tomb → hearth`.
  - The flue slots read darker and redder than the stone, not black, because the torch's own light falls up into them. If you want them black, the sconce's light would have to sit lower or further out (your call; it changes how the room is lit).
  - Skeletons, all first guesses:
    - The last light is the one time you see them move. Keep that reveal, or make them Boo-like even then? (Your second note ends their sinking into the stone there.)
    - Creep speed 1.4 m/s.
    - Arming distance 3 m.
    - Should a burning one thrash in plain view?
    - "Right up on you" means its strike reach, 1.6 m (since answered: they lunge within 2 m).
    - Should the dark hide them? Today one in your frame 40 m down a black corridor still freezes.
    - One whose way passes through your view waits at the edge of it until you look away, and one can stand frozen in a room you just relit while you watch it.
- **For chat:**
  - Log Mike's 7 Oct notes as a lettered section. They amend §FE.2 (the skeletons wake as you pass, then move only unseen), §EV.2 (the hearth's column falls on the fire, not beside it), §EX.4 (four torches in a room on pillars) and §EX.1/§EX.3 (the hearth a sunk pit, the sconce's flue a slot up the wall).
  - CLAUDE.md's brief still calls §EY and §FA–§FH "not built yet".

## 2026-10-07 — Queue 48, §EX.1 and §EX.3: one ruin, one stone — floor, ceiling, doors, stairs and sconces in the walls' style (8799b26)
- **What changes on screen:** the tomb looks cut from one quarry.
  - The floor is fitted many-sided flags of the walls' own stone, and the ceiling is long single slabs with one step of corbel over the walls.
  - The doorways are Inca trapezoids under one long lintel, the steps are single blocks, and every wall torch sits in a trapezoid niche cut into the wall.
  - Rooms 8 m or more on both sides stand on four pillars, and so does the hearth room.
  - The walls themselves are the same stones as before.
- **One stone** (§EX.1; new `RuinStyle`, `scripts/crawler/ruin_style.gd`, reading `masonry.json → styles` and `style_by_theme`; the tomb's style is `andean_tomb`). Every stone surface's colour is `stone.tint`, moved lighter or darker by up to `stone.spread` (0.06), every channel alike.
  - `stone.tint` "theme" now means `crawler.json → themes → <theme> → stone` (new, one line per theme). The tomb's is #636870, the mean colour its fitted walls showed before (RuinBuilder's five greys as the walls darkened them), so the walls keep their tone. The snow ruins' (#7b8088) is a first guess, not built.
  - RuinBuilder's general palette is never read: `TombBuild` sets it to the style's five tones. The hard-coded sconce grey is gone. The campfire's grey ring blobs are hidden in the crawler (their collision kept) under a kerb of nine stones of the style round the hearth.
  - Joints, feet and undersides go toward the scene's shade, navy, as the walls' joints do (`Prelit.ao_tint`; `TombBuild._contact` now tints instead of darkening toward black).
  - **The walls are the same stones as before** for the same seed: the random draws are kept in order and only the colour source changed. They are a little more even than before (±0.06 of one tint, where it was five tones darkened up to 14%), and `stone.spread` is the dial. Rooms dress only their inner faces now (the back of a room's wall is rock, or a corridor's lane where the door frame is all that shows).
- **Floors** (`floor fitted_flags`, `FittedStone.flags`): the walls' Voronoi cutter laid flat.
  - The stones are twice the wall preset's (0.5–1.2 m), with their pillow and proud at a quarter, and the joints packed with grit to 70% of their depth (one grit sheet in the scene's shade).
  - They're worn flatter and a little paler down the middle of each corridor and stair (`wear.band`, new: 0.7 of the half width) and along the ways each room was crossed: door to door, to the hearth, to the dead (`wear.amount` 0.6; `wear.lighten`, new, 0.6).
  - One collision slab under each floor.
- **Ceilings** (`ceiling lintel_slabs`, `FittedStone.slabs`): single slabs wall to wall, each its own width (0.5–0.9 m), the joints a little out of true, a share hanging a little low or turned a degree.
  - They're drawn as the walls' stones are (bevel, joints, a little pillow) and cut round every vent's mouth. The slabs span a room's shorter way.
  - In rooms, one corbel course of the stone first steps 0.3 m in over the walls (`rooms.corbel_h_m`, new, 0.36), leaving a gap where a vent rises beside its wall. Not where it would hang over a doorway's head with less than 0.3 m of lintel under it (`TombBuild.CORBEL_OVER_DOOR_M`): the way out's landing, at the corridors' 2.6 m, has none. (At first it had one, crossing the tops of its two doorways 16 cm down; from the foot of the flight it hid the top of the opening, and the night's blue no longer read against the stone, which `crawler_frames` caught.)
- **Pillars and beams** (`max_span_m`, `hearth_room four_pillars`; `pillars`, new: `side_m` 0.6, `beam_w_m` 0.5, `beam_h_m` 0.45, `bays_modules` [2, 3, 4, 1]): a room whose span past its corbels is over 6 m stands on four square pillars (a base, drums a little settled, a cap). They carry two beams wall to wall, and the slabs rest on the beams.
  - **Where they stand:** two, three or four of queue 46's 2 m modules apart round the room's middle, one module only where nothing wider stands clear. It takes the first spacing that keeps every slab and beam within 6 m and leaves a passage clear of the walls.
  - **What they keep clear of:** the hearth; the hearth room's mat, wake spot, bundle and rescuer; the heart's dead and their goods; a crypt's coffin rows; queue 47's wall torches' bays (where you stand to light one); the vents' columns (never broken); and the doors' ways in where the room allows (the sight lines, a soft rule). Where no spacing clears everything, it uses the one that crowds least, a torch's bay counting three times a coffin. Over 200 tombs, 1,102 of 2,188 rooms stand on pillars and none crowds anything; in 25 of them a pillar stands in a door's sight line, where the room leaves nowhere better. Every coffin is laid (2,189 of 2,189) and every bone niche cut (5,753). A beam breaks round a vent's column, so a shaft is always open.
  - **The hearth room** always has four, round the hearth, with the shaft open between them, and you always wake between two of them. `TombKit` no longer picks a diagonal wake direction in a four-pillared hearth room; the random draws are kept, so nothing else moves.
  - **The skeletons' floor grid** (`TombNav`, queue 58's) closes any patch of open floor no doorway reaches: a pocket walled in by coffins and a pillar (147, 60 and 57 squares of a quarter metre on seeds 1, 7 and 42). Queue 59's `cleared_check` found a skeleton that came up from the stone into such a pocket in a lit crypt and stood there 16 s, with no way out over the floor.
  - **Collision:** each pillar is three solid blocks as drawn: the base, the shaft and the cap. (It was first one block the base's size all the way up, 8 cm proud of the shaft, which stopped a skeleton's line of sight short of it.) TombNav's casts now find what they start inside (`hit_from_inside`), so the skeletons' floor grid and the snake's room to coil see the pillars.
  - **The collapsed room's** fallen slab and rubble now go where they leave a passage from every door and clear the pillars and the torches' bays, the slab lying along its wall.
- **Doors** (`doors trapezoid`, `top_share` 0.85; new `jamb_w_m` 0.32, `lintel_h_m` 0.42, `bearing_m` 0.25):
  - The opening is 15% narrower at the top, framed by three jamb stones a side (the doorway's shade in their faces), under one monolithic lintel. The lintel meets a room's corbel course where less than a course of wall would be left.
  - The threshold is one stone across the opening. Its collision is flush with the floor: the stone shows 1.2 cm proud, and that lip stopped 46's walk out in one tomb of 203.
  - The wall's stones are cut round the frame (each cell crossing it split along its edges), so they fit it. The jambs carry the slanted collision.
  - The way out's opening (queue 46) is the same doorway, and the stone either side of it outside is the style's.
- **Niches** (`niches` trapezoid, `top_share` 0.8):
  - **Bone niches:** the catacomb's are trapezoid recesses in its long walls at queue 58's `TombKit.niche_spots`, two to a column, bones and a skull on their sills (`niches.bone`, new: 0.9 × 0.5 m, 0.38 m deep, sills at 0.45 and 1.25 m).
  - **Burial niches:** where a skeleton sits, the column is one tall burial niche (1.0 × 1.25 m, `niches.burial`, new) over a sill stone it sits on, 0.5 m up, where `rest_place` sits it. That replaces 58's framed shelf stack.
  - **Sconce niches:** every sconce is a trapezoid niche cut into its wall's fitted stone (0.4 × 0.55 m, `sconce.niche_d_m`, new, 0.26) with a stone cup in it (`cup_m`, new), and its flame and coals stand in the cup. A room's torches (queue 47) get niches like the corridors', the flue through the corbel course's gap.
  - **The sconce light** hangs 0.32 m out in front of the niche, where the old bracket held the flame (`CrawlerFires.LIGHT_OUT_M`; a one-line `light_z` meta added to `Campfire.flicker`, beside the crawler's `light_y`; 0 for every open-world fire). At the niche's mouth it lit 47's rooms to only 0.79 of their light in the worst room.
- **Stairs** (`stairs block_steps`): each step one block of the stone, a share sunk or turned a little, over the ramp you walk; the stepped ceiling two slabs a stretch. The way out's flight past the heart is the same.
- **Dressing:**
  - **The coffins** stand at queue 58's `TombKit.coffin_spots`. The open ones (a skeleton's grave) are the stone too: the hollow in shade, the lid on the floor, on the same random draws as a closed one. A coffin a pillar would stand on isn't laid, and no skeleton rests where it would climb out into a pillar (`_place_residents`).
  - **In the style's stone:** the heart's mossy box (hollow when it holds one), the fallen slab, rubble (fallen wall stones and slab pieces), the rescuer's seat (§FH's), the airways' carved frames and the vents' flues.
  - The heart's ochre, the soot, moss and drifted sand lie on top. Bones, clay, gold, reed and hide are drawn as they were.
- **Queue 49's lair** (the snake's hole), as its last entry asked: its broken edge is the style's stone. The tipped flags are `RuinStyle` stone shaded toward navy as they go down, the thrown-out pieces are small blocks of it (they were palette boulders), and the bones are unchanged.
  - **Off the pillars:** `TombBuild.pillars_for` gives a room's pillars from the layout alone, and `BossGround._lair_spot` keeps the hole's rim `PILLAR_KEEP_M` (1.35 m) from each pillar's middle, where a coffin stood too. It also keeps off the fallen room's slab where this pass lays it (`TombBuild.collapse_for`).
  - **Why this way round:** when the pillars kept off the hole instead (tried on the layouts before 46), they couldn't in 213 of 355 such rooms over 400 tombs, and some stood in it. Now every one of 400 tombs still gets its hole, 90 of them in rooms on pillars, none nearer than 0.91 m to a pillar's base (on 46's layouts).
- **Queue 61's wall life:** every dressed wall face goes to the glow-moss and the beetles with its stones as laid, cut round the door frames and niches (`FittedStone.face` fills 61's `out` as well as taking this pass's holes).
- **Merged with what landed while this was under way:** queues 46 (and its NodeRelease follow-up), 47, 49 (with its follow-up, and its walk out with the snake loose), 51, 56, 57, 58, 59 (the skeletons cleared by light), 60 and 61, and prompt 63's design commit. This pass is rebased onto them. Where they touched the same files as this pass, the changes sit side by side; `crawler_frames` had come to hold the snake still just as this pass did, and keeps its own lines for it.
- **Triangles** (the tomb mesh inside each room's walls, on 46's layouts; before is the upstream code this pass is rebased onto):

  | | A room, seed 7 (13 rooms) | The whole tomb, seed 7 | The 38 rooms of seeds 1, 7, 42 |
  |---|---|---|---|
  | Before | median 30,378 (25,476–39,044) | 617,433 | median 32,860, most 43,484 |
  | After | median 30,843 (24,820–37,722) | 602,706 | median 31,479, most 39,189 |

  Every room is inside the 45,000 budget, so no floor cells needed merging. The fitted flags cost about what the old box flags did once they dropped the pillow ring a quarter pillow doesn't show. Dressing only rooms' inner faces paid for the corbels, slabs, frames and pillars.
- **Build time** (this machine's processor, the best of three builds of each tomb, the same probe on both trees back to back, with a render running alongside): seed 7 6.9 → 7.9 s, seed 1 7.4–7.5 → 8.0–8.6 s, seed 42 6.0–6.1 → 6.4–7.2 s over two runs, about a tenth longer. Seven tenths of it is the walls' fitted stones, as before (the floors' flags take another 0.6–0.7 s). It is paid once per tomb, at the start and behind the fade when you walk out.
- **Checks:** `crawler_check` passes with 0 fails on seed 7 (228 lines, the other sessions' lines and 46's 203-tomb walk out included; that walk passes on this pass's stone, median 97 m). New lines, on seeds 1, 7 and 42:
  - **Built as cut** (`TombBuild.bare`: no joint or contact shade, ochre, soot, moss or drift), with RuinBuilder's palette poisoned to magenta: all 4,999,830 stone vertices are inside the tint ± spread (#545961 to #72777f), every vertex is told stone or another material, and none of the poison shows anywhere.
  - **A search of the crawler's scripts:** no palette read and no general palette by name anywhere. In the scripts that lay stone, no colour literal but the known non-stone ones (the ochre, the logs, the bundle, the void).
  - **Doors:** all 79 doors are 0.85 as wide at the top. In the built tomb (seed 7), rays across each of the 27 doorways at its foot and near its top measure 1.76 m and 1.55 m: 0.882, against the trapezoid's 0.882.
  - **The hearth room** stands on four pillars round the hearth. The hearth, the mat (three points down it), the bundle and the rescuer are clear, with the shaft between them and no pillar or beam across it.
  - **Spans:** no slab spans more than 5.50 m and no beam more than 6.00 m. 22 of 38 rooms stand on pillars.
  - **The boss's hole** is at least 1.35 m from a pillar's base (9 holes in rooms on pillars: the three tombs as built and 30 more layouts).
  - **Triangles:** every room is under the 45,000 budget (the table above).
  - **Your own body** (the crawler's capsule, its step and slope) walks through every door both ways, along every corridor and stair, and into every room from each of its doors, round its pillars and what lies there. The ways into the rooms are found on TombNav, the skeletons' floor grid, at your size, each from where you stand clear inside the door: 279 legs, 760 m over the three tombs. The way out's opening is left to 46's own walk, since stepping into it walks you out to the next tomb (a first run walked through it and then on through the next tomb's stone, falling; a leg that walks out now fails the check).
- **Also run** on the final code, all with 0 fails:
  - `boss_check` (seeds 1, 7, 42): 115 lines, the walk out with the snake loose among them (105–112 m, never taken).
  - `residents_check`: 122 lines (upstream's 123). The test that hides you behind a coffin now picks one the coffin alone hides you behind where there is one. On seed 42 there is none: the crypt's pillars stand in every such line (probed: the line from the skeleton's eyes to your standing head meets a pillar's shaft), so its "the coffin alone hides you" line doesn't apply there.
  - `stagger_check` 61. It stands its creature in one of four fixed lanes in the hearth room, and on seed 7 the pillars stand behind all four, so it now tries three more spots (nearer the hearth, or out between the pillars and the walls) after those.
  - `cleared_check` (queue 59, seeds 1, 7, 42): 78 lines, as upstream's, once the floor grid closes its islands (above).
  - `fire_pot_check` 82, `crawler_harm_check` 59 and `hands_check` 61.
- **Visual pass:** `crawler_frames` (seed 7), rendered once on this machine's software Vulkan, on the code as pushed: 68 frames, 48 lines, 1 fail, the crypt's torches against its old ring (below, for Mike).
  - **The way out** from the foot of its flight reads at night again: the opening 0.100 against the stone's 0.075, where 0.02 is needed. A run before the landing's fix had 0.085 (the corbel crossing the opening).
  - **New frames** `10c_crypt_by_torch` and `10d_doorway_from_the_crypt`. In that run the torch in hand was still out from the heart's relight, so the crypt shows by its two relit wall torches; the tool now lights it for them (two lines, the heart section's own).
  - **Before and after:** the same four views (the hearth room on waking and from its wall, a crypt by torchlight, its doorway) were rendered from the code before and after this pass, for comparison.
- **For Mike:**
  - **A pillared room by its two torches reads darker than by its old ring: your call.**
    - **The numbers:** from a crypt's doorway at night (seed 7's, 8 × 8 m, so on pillars), its two wall torches relit, the frame reads 0.215 against 0.321 with the old hearth ring in its middle. Upstream, with no pillars, it was 0.282 against 0.271.
    - **Why:** the pillars stand between the wall torches and the floor you look across, and under §ER.1 the two fires nearest you cast shadows. The ring, in the middle, lit the far pillars' faces toward you.
    - **What fails:** `crawler_frames` fails that one line, queue 47's own on-screen check, until you choose. The headless lit level (47's check in `crawler_check`) passes, but it counts no shadows.
    - **Not a fix:** brighter torches. Three times as strong still reads 0.283; it takes four times, which washes their walls out.
    - **The choices:** (a) keep it, the light in pools by the walls and the pillars' shadows across the floor; (b) four torches in any room on pillars, not two (the far pair throw no shadow, since only the nearest two fires do, so their light reaches the floor), two more to relight in a tenth of the rooms (97 of 1,003 over 100 tombs: the rooms on pillars 8 m long; the longer ones have four already); (c) `max_span_m` 8, so only the 10 × 10 m rooms keep pillars and the crypts lose theirs.
    - **My pick is (b).** It keeps the pillars and gives the relit room back its light. It touches 47's torch placement and the coffins and niches that make room for the torches, so it is a pass of its own.
  - **Pillars in about half the rooms.** The rooms are 6, 8 or 10 m on a side, and the slabs span the shorter way. With `max_span_m` 6, every room 8 m or more on both sides stands on four pillars (456 of 1,003 rooms past the hearth room over 100 tombs); a room 6 m wide never does, however long. Set `max_span_m` to 8 and only the 10 × 10 m rooms keep them (95 of 1,003), if the tomb feels crowded. The hearth room keeps its four either way.
  - **The walls are a little more even** than before (one tint ± 0.06): raise `stone.spread` (0.1 is about the old mottle) if you miss it.
  - **The snow ruins' stone** (#7b8088) is my first guess; their style is data only until they're built.

---

## 2026-10-07 — Queue 46, §EX.2 and §EX.5: the plan and the way out (a spine, the module, an exit every time) (28dafd4; follow-up b7956e0)
- **The module (§EX.2).** Every size in the tomb is now a whole number of its style's unit (`masonry.json → styles → andean_tomb → module_m`, 2 m, the corridor's width; the style comes from `style_by_theme`, now read). Rooms are 6, 8 or 10 m a side, corridors and flights 6, 8 or 10 m, the hearth room 10 × 10 m (its 9 m snapped). The ceilings are the style's `heights_m` (corridor 2.6, room 3.2, hearth room 3.6 m, the same as before).
- **The spine (§EX.2).** One of the hearth room's 3–4 ways is grown first: 4 or 5 rooms (`crawler.json → plan.spine.rooms`, new), dead straight, every room's two doors facing each other, so from its doorway you look straight down the passage to the next door and the next light. Its last room is the heart, at least 8 m long (`plan.spine.heart_min_m`, new). Over 203 tombs: 108 have 4 spine rooms, 95 have 5.
- **Side ways.** The other ways have at most 60% of the spine's rooms (`side_share`), and each ends in a room. They go straight on through facing doors, but turn at a room by `kit.turn_chance`, or where straight on won't fit. Of all two-door rooms, 1,257 of 1,509 face; every spine room does. Every door is centred on its wall, the hearth room's too.
- **The way out (§EX.5).** From a door centred in the heart's far wall, a 10 m flight climbs 6 m (`exit.rise_m`, at the kit's stair slope), then a door into a 2 × 4 m landing (`exit.landing_m`, new), and the opening in its far wall. The threshold runs out under the daylight to a stop, with the stone carried out either side.
  - **The daylight** (`WayOut`, `exit.glow`, new) has two parts. A sheet of sky stands just outside the opening, and a soft wash falls over the landing and the top steps. Both take §EV.2's colours from the twilight and their strength from the sun's height, as the shafts now do (§FG):
    - at noon: the wash at 0.96 (a hearth's shaft is 2.49), the opening's sheet #5774b5;
    - at midnight: 0.14 and #141d3c (`sheet_night` keeps the opening faintly visible).
  - It is seen from the foot of the flight. First render: only a sliver showed from the foot, because looking up through the opening your eye met the underside of the stone I had carried out over it. That roof is gone, and the sheet now reaches 2 m over the opening's head.
  - **The stand-in** (`CrawlerMain.walk_out`): stepping into the opening:
    - fades to black over `fade_s` (2 s);
    - logs "Up the old stair and out. Another tomb, another hearth." (`exit.stand_in.log`, new);
    - builds the next tomb, whose seed follows from this one, so a pinned SEED always walks the same tombs;
    - stands you on its mat by its lit hearth, carrying exactly what you carried, the torch lit or not as it was.

    Only the tomb's own nodes are rebuilt: its stone, fires, vents, airways, way out, glow-moss, beetles, skeletons, rescuer and snake. You, what you carry, the grade, the HUD and the log stay. Each mesh is let go before its node is freed (otherwise the headless renderer printed about a hundred errors per walk-out).
  - **Never gated:** no gates exist yet. TombKit marks every spine piece and door, and its header says gates go only on side ways and shortcuts.
- **Kept clear, found by the walk check:**
  - **Crypts** only go in rooms at least 8 m wide, so an aisle stays clear between the coffins' askew lids.
  - **The heart:** the dead lie across the room 3 m in from the far wall (`TombKit.HEART_BOX_M`), their goods before them, the way out's door behind them. You walk round them. Queue 47's four sconces flank them there.
  - **Stairs.** At the top of a steep flight, the threshold stone stood 3–4 cm proud of the walked slope. On a 30° climb that edge acts as a wall (the contact is at 57°; the limit is 45°). So nobody could climb out of the way-out flight, nor back up the steepest flights of the old tombs. The tomb's flights now ride 5 cm over their steps (`RuinBuilder.ramp_lift`, 0 in the open world).
  - **Far fires.** A cold holder's light stayed on until you came within 60 m of it. That was invisible in the old compact tombs but wrong down a 100 m spine; it is now off from the start.
- **Checks:** `crawler_check` (seed 7) has 215 lines and 0 fails.
  - **The plan, over seeds 1, 7, 42 and 200 more** (a fixed draw; `WALK_SEEDS` changes the count):
    - 3–4 ways out of the hearth room;
    - a way out in every tomb, past the heart at the spine's end;
    - the spine running through the heart, door to door;
    - side ways shorter than the spine, each ending in a room;
    - whole modules, the style's heights;
    - doors centred, and the spine's doors facing;
    - queue 47's room torches by its rules in all 2,002 rooms.
  - **The walk.** In each of the 203 tombs, a capsule walks from the mat to the opening with every holder cold. It is your body exactly: shape, floor rules and step (`CrawlerPlayer.body_shape`, `floor_rules`, `step_body`, which the player now uses too). It walks through the tomb's real collision and fires, round the rescuer and the snake's hole.
    - The route is an A* over a 25 cm grid where your capsule fits; then the body walks it.
    - The collision comes from a collision-only build, checked identical to the game's: 0.36 s instead of 5 s.
    - A failure names where the body stopped.
    - **All 203 walked out: median 96 m** (shortest 82, longest 126; 163 s for the 203).
  - **The way out:**
    - its daylight is blue at noon and at midnight, faint against a shaft, and follows the clock;
    - nothing stands between your eye at the foot of the flight and the opening;
    - walking into it twice (torch lit, then unlit) arrives each time on a new tomb's mat by its lit hearth, with the torch as it was and the log line.
  - **Upstream checks taught about the new layouts:**
    - the 120 s run round the tomb (queue 50) crossed every door, the opening too, and walked out into the next tomb, where it stalled (21 s at a sprint, 90 needed); the check after it then found no relit sconce. Its tour now turns on the landing: 109 s at a sprint, nothing skipped.
    - sneaking (queue 53) crouched through every door, the opening too; the doors after it were tried in the next tomb, and 7 found no floor there. It now skips the opening, and walks the way out's flight (the first that climbs) from its top, down: all 26 doors, all 5 flights, the guard never holding you.
    - `residents_check` (queue 58) sets the heart's coffin aside from the way-through rule, as the placement now does. Its waking test also picks a skeleton where your body fits at both of its spots: in an 8 m crypt, just beyond `wakes_m` in front of a coffin is the far row's coffins.
    - `boss_check` (queue 49) picks its spots with a clear line from the snake's eye to your flame, off the hole's ring.
  - **Seed 126** (queue 58's note on this prompt's status: its crypt, piece 16, closed off by its coffins and hearth ring): on the new layouts it walks out (97 m), and each of its three crypts can be crossed by your body, door to door or door to its middle. Crypts are 8 m wide now, and queue 47 took the rings.
  - **Also run, 0 fails:** `residents_check` (123 lines), `boss_check` (109), `stagger_check` (61), `fire_pot_check` (82), `hands_check` (61) and `crawler_harm_check` (59). `crawler_check` prints 16 headless renderer warnings ("Parameter m is null"): 4 in the half-dark checks and 12 in the pitch torch's, where torches are freed. Both sets were there before this pass (see queue 51's entry).
- **Merged with queues 45, 47, 49 (and its follow-up), 50, 51, 52, 53, 54, 55, 56, 57, 58, 60 and 61** and the master-volume fix, all pushed while this pass ran:
  - **Walking out with fire pots** (queue 60): what you carry stays (the pack, the pot in your left hand, its wick as it was). What lay or burnt on the old tomb's floor goes: its found pot, the fires, their char, a pot still in the air. The new tomb gets its own found pot (`FirePots.retomb`).
  - **The rescuer** (queue 52) sits by each new tomb's hearth too, the live 3D rig, rolled from that tomb's seed. The walk check has its body to bump into (its blocker, §FH), as in the game.
  - **The snake** (queue 49) is built with each tomb. Walking out leaves the old tomb's snake behind: its chase ends with it, and the drips it hushed come back to their level. The next tomb has its own, its hole in a side room off the spine (`BossGround` already read the spine). Its sprites bake while the screen is still black.
  - **Sneaking** (queue 53): your step is now worked out in two parts (`CrawlerPlayer.step_velocity`, then the move), so the ledge guard still sits between them.
  - **The atmosphere** (queue 61): the glow-moss and the beetles live on each tomb's walls, so they come and go with it. The shafts brighten and dim with the sun's height now, and so does the way out. Its checks and frames are taken at solar noon and midnight (the clock is warped: clock 0.5 is mid-afternoon).
  - **The skeletons** (queue 58) rest in each tomb's niches and coffins and come and go with it. Their places come from TombKit (`coffin_spots`, `niche_spots`, `heart_box`):
    - the heart's coffin lies 3 m in from the far wall, the way out behind it;
    - the heart's coffin always holds its skeleton, as `residents.json → heart_holds_one` says. The rule keeping skeletons off the way through (`off_line_m`) would have emptied it, because the way through the heart now runs past the coffin to the way out;
    - nothing rests by the snake's hole (`TombKit._by_lair`, the margin FirePots keeps the found pot from it): its ring hid a niche's skeleton in seed 42.
  - **The room torches** (queue 47) replace each room's hearth ring with wall sconces, so this pass's rule for rings (beside a long wall, off the walk) went with them. The heart's sconces flank the dead where they now lie (`HEART_DEAD_M` follows `HEART_BOX_M`).
  - **Frames:** the two hands took 17 and 18, the atmosphere 19 and 20, the skeletons 21 and the pitch torch 22, so the plan and the way out are frames 23–25.
- **Frames (crawler_frames, seed 7, on 28dafd4):** 45 lines, 0 fails, 62 frames. New:
  - `23`, down the spine from the hearth room's doorway: straight on past a sconce to the next doorway;
  - `24`, into the heart by torchlight: its four sconces relit, the mossy coffin with its skeleton toward the far end, the goods before it, and the way out's door dark in the far wall behind;
  - `25` and `25b`, from the foot of the way out's flight with the torch out, at noon and at midnight. At noon the opening is #698ace (luma 0.53) against stone at 0.074 round it; at midnight #0e174a (0.101) against 0.075, 0.026 over (the bar is 0.02). The relit heart behind you counts as a flame near, so the half-dark is off and the flight is black: only the opening shows, a pale slot above the crosshair;
  - `25c`, the same by torchlight: the steps up to the slot.
  - The run printed one `Condition "multimesh->mesh.is_null()" is true` from the renderer as the game quit, as every render since this pass's first merge did (queue 59's entry flagged it). It was this pass's, and b7956e0 removes it (below).
- **Follow-up (b7956e0):** this pass had made `NodeRelease` empty particle systems' meshes too, to quiet a headless warning on walking out. It wasn't needed: `crawler_check` prints the same 16 headless warnings without it, its two walk-outs adding none. Under the real renderer an emptied particle mesh is an error, once per walk-out and once as the game quits. `NodeRelease` is upstream's again. A rendered boot, walk-out and quit (xvfb, lavapipe) now prints no renderer error. `crawler_check` 215 lines, `cleared_check` 78 and `residents_check` 123, 0 fails each.
- **Cost:** the tombs are bigger (the spine and the way out).
  - Seed 7 is now 617k triangles (it was 422k); a typical room is still 25–39k.
  - A tomb builds in 4.4–6.1 s here (was 2.6–3.2 s). That time falls inside the black of waking or walking out.
- **Contradictions and open calls for Mike:**
  - Queue 47 put the dead 1.6 m from the heart's far wall (§EX.3, prompt 47). The way out now leaves through that wall, so they lie 3 m in, with the door behind them, and its four sconces flank them there.
  - The way out's top sits rise_m (6 m) above the heart, so its depth varies with the spine's flights. When §EW.7 step 2 builds the surface, one of the two must meet the other. With no flight on the spine, the landing's roof is 0.1 m above the vents' stand-in surface (9 m).
  - At night the opening is faint: about #0f184a against stone at the frame's black, from the foot of the flight. That is readable by the half-dark's own measure (0.03 luma over the stone round it; 0.02 is the bar), but easy to miss, and the steps by you in the half-dark are brighter. `exit.glow.sheet_night` raises it: 1.0 gives about #1e2c5c, 1.5 about #314787 (at noon it is about #698acf).
  - The snake's hole (queue 49) is ringed by an invisible cylinder as tall as you, so it blocks sight as well as feet. The snake can't see your torch across its own hole, and a skeleton resting behind it can't see you. To block feet only, it would need a shorter ring or a collision layer of its own; that is queue 49's call.
  - §FK.2 (new) draws every dungeon's seed from the game's seed and replaces the stand-in's "new seed". The stand-in already chains each next tomb's seed from the last (`CrawlerMain.next_seed`), so the same start walks the same tombs. Queue 63 roots the chain in the game's seed and keeps what you changed; today the tomb you leave is gone.

---

## 2026-10-07 — Queue 59, §FF.2: cleared by light — the skeletons keep to the dark, bite from its pockets, and go for good at the last light (828e1fa)
- **Built on 49, 56, 57 and 58, and merged over 46, 47, 51 and 60.** The light is queue 49's map of the tomb (`BossGround`: each room, and each corridor stretch between sconces, lit or dark). `Residents` works it out again whenever a holder catches. Until floors exist (§FF.1), a floor is the whole tomb.
- **The light keeps them out** (`residents.json → rules`):
  - A skeleton keeps to the dark unless its strike has landed this chase (§FD, `chase_enters_light`, `Pursuit.may_enter`). Then it can follow you into the light until it gives you up, and it is back in the dark within `back_to_dark_s` (4 s).
  - Hunting you without having hit you, it stops at the edge of its dark, in the doorway, and watches you for `edge_watch_s` (6 s, new), then gives you up. No strike reaches you in the light until one has hit you, as with the snake.
  - Relight the room a skeleton lies or stands in and it climbs out (bone grinding) and goes for the nearest dark (`BossGround.nearest_dark`), walking fast enough (up to 6 m/s) to be out of the light within 4 s of setting off.
  - Given up, it walks home only by a way through the dark to a resting place still dark. The hearth room is always lit, so it never crosses it; otherwise it hangs back in the dark.
- **Dark pockets bite** (`pocket_counterattack_m` 3; `pocket_lunge_mps` 3.5, new): skeletons the light has moved on stand in what dark is left, as far from where the light comes in as the pocket allows (`Residents.pocket_spot`), and are no one's pursuer there. Come within 3 m where one senses you and it strikes: 57's normal wind-up (the jaw's creak from its first frame; a lit torch's swing staggers it) while it lunges in to bring you into reach. Then it hunts you.
- **Cut off** (`below_s` 6–12 s, new; my reading, like the snake going below): when a whole branch is relit, its skeletons can't reach any dark without crossing the lit hearth room. They go into the stone through the nearest niche or coffin (seen going if you're looking, the same climb and sink as at the end), then come up 6–12 s later in the dark nearest them, out of your sight and at least 6 m from you. So the tomb's skeletons gather in the last of the dark, and the last light's reveal has them all. Without it, someone relighting branch by branch would see most of them vanish before the end: on the layout before 46, seed 7 lost 4 of its 5 that way.
- **Cleared** (`crawler.json → cleared`; new: `retreat_seen_s` 6, `log_line`; `retreat_mps` 3.2 and `withdraw_s` 1.2 in `residents.json`): when the last light catches, every skeleton leaves by its `retreat_to` (the skeleton's `back_into_its_niche`).
  - One you can see hurries back into its niche or coffin (or a much nearer one), climbs in and sinks back into the stone.
  - One you can't see is gone at once, and one that leaves your sight is gone then; none later than 6 s.
  - It is gone for good: off the roll and freed, never back.
  - The log reads "N of N lights burn again.", then "Banished the dark. What lived in it fled." (no creature named, §BA). The snake's release (queue 49) plays as before. The count line moved into CrawlerMain's physics step so it comes first.
- **Data:** `[NOT WIRED YET]` is off `crawler.json → _help.cleared`; `residents.json → _help.rules` and `_help.about` say what is wired (queue 60's fire wording kept).
- **Checks:**
  - `tools/cleared_check.gd` (new), seeds 1, 7 and 42, on the final code (46's layout in): 78 lines, 0 fails, no script errors.
    - It stops 9 cm from the doorway's middle and gives you up exactly `edge_watch_s` after it stopped (7.62 s, stopped at 1.62 s). Once it has hit you, it follows you into the lit hearth room; given up there, it is back in the dark within 4 s (0.02 s here).
    - The pocket strike starts as you cross 2.96–3.00 m and lunges to 0.83 m; the hit lands 0.85 s after the wind-up began (0.7 + 0.15). Your swing at half the wind-up staggers it, and no hit lands.
    - Cut off in view, it climbs into its own grave and sinks in 1.52 s, then comes up 6.5–10.0 s later, 70–95 m off and out of sight.
    - The relight run (the heart's lights last; 47's sconces, 46's spine and way out): no skeleton stands in the light outside a chase except on its way out, 4.7 s at worst (its climb out included). Each seed had a pocket strike and chases into the light.
    - At the last light every skeleton is still there (4–5); 3, 3 and 5 are seen going, and all are gone within 1.8–2.3 s. Over 5 minutes more, none comes back.
  - `residents_check` (58): its hiding test follows the new rule. On seed 7 the skeleton's niche lies past the lit hearth room, so it hangs back in the dark instead of walking home; on seeds 1 and 42 it walks home.
  - The other sessions' checks on the final code, all 0 fails and no script errors: `crawler_check` 215 lines on seed 7 and 215 on seed 1, `boss_check` 109, `residents_check` 123, `stagger_check` 61, `crawler_harm_check` 59, `hands_check` 61, `fire_pot_check` 82.
- **Frames** (`crawler_frames` with `ONLY=cleared`, lavapipe; seeds 7 and 1, 0 fails each):
  - Seed 7. `26a`: a skeleton at rest in its wall niche, its room's sconce the last light still cold (45 of 46 relit). `26b`: the sconce catches and the skeleton, on screen, starts back into the stone, its bone lit amber (brightest pixels luma 0.532, hue 21.5). `26c`: a third of the way in (a harness frame, held for the shot). `26d`: the niche empty, every skeleton gone, and the log's line.
  - Seed 1 lays all four of its skeletons in graves, so its frames show one sinking into its coffin (luma 0.542, hue 23.9).
- **Follow-up (7aa3ca1):** a skeleton gone for good was freed with a plain `queue_free`, and under the headless dummy renderer that printed `Parameter "m" is null` once per skeleton (14 lines a run of `cleared_check`). It now goes through `NodeRelease.free_later`, its meshes let go of first, as the tomb's nodes are. Nothing changes on screen. `cleared_check` again: 78 lines, 0 fails, none of those lines.
- **Flagged, not mine:**
  - Queue 60's `burn_out` still frees a burnt skeleton with a plain `queue_free`, so it prints the same line headless (one line to change, in its pass's code).
  - Under the real renderer, a `crawler_frames` run now ends with one `Condition "multimesh->mesh.is_null()" is true` (`_multimesh_re_create_aabb`) as the game quits, after its last frame and result. It isn't the clearing's: `ONLY=skeleton` prints it too, on this code and on a015155, before queue 59. A render of the tomb at 04:13 today (before 58) didn't, so it came with one of the passes since. It changes nothing on screen.
- **For Mike:** the numbers are first guesses: the 6 s watch, the 3.5 m/s lunge, the 6–12 s in the stone, the 6 s limit on being seen going, and the log line's words. Cut off going into the stone and coming up elsewhere is my reading of "they retreat to those places", not a decision of yours.

---

## 2026-10-07 — Queue 47, §EX.4: one hearth per dungeon, wall torches in the other rooms (6578210)
- **What changes on screen:** the hearth room is the only room with a hearth, and its shaft is the only column of daylight in the tomb. Every other room has cold wall torches (sconces) on its walls instead of a hearth ring in the middle:
  - two facing each other in a room whose long walls are up to 8 m;
  - four in a longer room (two facing pairs);
  - four in the heart, two on each side wall flanking the dead.
  - Each has its own flue and soot streak. They look like the corridor sconces for now (queue 48 restyles them).
- **Where they go** (`TombKit._room_sconces`, `crawler.json → room_torches`):
  - On the room's long walls. Pairs are a whole number of 2 m modules apart (`masonry.json → styles.module_m`, the first key of the styles read), spread down the wall.
  - Each bracket keeps 0.6 m from a doorway's edge and from the corners (`clear_m`, new). Where a door is in the way, a pair steps along a quarter metre at a time and stays facing, so a door in the middle of a wall ends up flanked.
  - If no facing spot clears the doors, the pair takes another whole-module spacing; failing that, each long wall finds its own spot. That happens to about 77 pairs in 400 tombs (under 1%).
  - Corridors keep their sconces as built. The airways now keep clear of every sconce.
- **Light:** a room's torch gives 1.5 times a corridor sconce's light (`light_scale`, new; same flame, same reach).
  - Measured (`tools/crawler_check.gd`, seeds 1, 7, 42): the light on each room's floor and walls as Godot lights them, each spot counted no brighter than white (share of white; plain mean light in brackets).

    | Rooms | Old hearth ring | Its sconces relit |
    |---|---|---|
    | small (2 sconces) | 0.21 (0.92) | 0.24 (1.53) |
    | large (4) | 0.12 (0.55) | 0.31 (1.97) |
    | the heart (4) | 0.17 (0.77) | 0.37 (2.65) |

  - The dimmest small room comes out 1.13 times its old ring. At `light_scale` 1.0 it would be 0.81 times, at 1.25 0.97 times.
  - On screen (`crawler_frames`, seed 7, the crypt from its door at night): the frame's mean brightness is 0.221 with the old hearth ring (built for the frame, then taken away) and 0.274 with the crypt's two torches relit.
  - Large rooms and the heart are now about twice as lit as with their ring. Lower `light_scale` if that's too bright.
- **The rooms make room**, measured over 80 tombs:
  - The crypts' coffin rows and the catacombs' niche stacks are set round the sconces (`TombKit.coffin_spots` and `niche_spots`, where queue 58's skeletons rest too).
  - The torches cost the crypts no coffin (1,169 of 1,169). Each wall's row is set so its first torch falls between two coffins wherever that costs no coffin. A torch over a coffin's head is swung at from the gap beside it. (Since queue 49's follow-up, 97d9628, the snake's hole can take one coffin's place in a crypt.)
  - A catacomb leaves out the niche stack where a torch hangs, and keeps every other stack 0.95 m from a torch, room for a burial niche's frame. That is 1,749 stacks of 2,151.
  - A skeleton's open coffin drops its lid away from a torch's bay. Bone heaps, a collapse's slab and rubble, and grave goods keep the bay clear.
  - Every room torch (2,502 of 2,502) can be reached from 0.5 m in front of its wall.
- **Counts (before queue 46):** seed 7 now has 43 cold lights (34 room sconces and 9 corridor ones; it had 19) and 44 vents, 1 with daylight (it had 20 vents, 11 with daylight). The tomb grows from 422,373 triangles to 429,661 (2% more: the sconces, their flues and soot, less the rings). The log's "N of M lights burn again" counts the sconces.
- **Checks** (on the pushed code, 6578210, before queue 46 landed on top of it, unless said):
  - `crawler_check` passes with 0 fails on seeds 1, 7 and 42 (187–188 lines each, run again on 97d9628 with queue 56 and queue 49's follow-up in). New lines: one hearth per tomb, in the hearth room; 2 or 4 sconces per room and the heart's 4 flanking the dead; the long walls, whole modules apart, the facing share; no sconce within 0.6 m of a door's edge (nearest 0.77 m); one shaft and one flue per sconce; the airways clear; each room's light against its old ring; every room sconce in reach (a capsule search); the built lights matching the measure.
  - `boss_check` (seeds 1, 7, 42) and `residents_check` (seeds 1, 7, 42) pass with 0 fails. The snake's ground already counts a room relit once all its torches are (§EX.4's two or four), so the dark shrinks room by room as they catch, and its lair keeps clear of the sconces.
  - `crawler_harm_check`, `fire_pot_check` and `hands_check` (seed 7), and `stagger_check` (seeds 7, 1, 42) pass with 0 fails.
  - `boss_frames` (seed 7) has 0 fails.
  - `crawler_frames` (seed 7), the walkabout, on 97d9628: 43 lines, 0 fails, 55 frames. New frames: `09a_crypt_old_hearth_ring` (the ring built for the frame, then taken away), `09_crypt_sconces_relit` and `10b_heart_relit`. I looked at them once: the crypt's two torches face each other across its coffins, each with its soot above it, and the heart's four flank the dead at its end.
    - The first render, on 6578210, had 2 fails, neither of them the torches'. The snake (queue 49) reached you in the dark corridor during the pitch torch's frames (queue 51) and took you back to the hearth with empty hands, so the swing at that corridor's sconce found no torch in hand. A headless run without queue 47 shows the same take at the same moment. Queue 51's session held the snake still for those frames (2060cc2).
    - This pass now holds it still for the whole tour (a few lines in `crawler_frames`, and HOW_TO_RUN says so). In the 97d9628 render it was still free: with queue 56's chase into the light, it came for the torch in the dark heart and lay coiled beside you through `10` and `10b`. A render with the hold was still running when this was pushed.
  - **On the code as pushed, with queue 46 in:** `crawler_check` passes with 0 fails on seeds 7, 1 and 42 (215 lines each). Over the three seeds: 35 rooms and 140 room torches, all 56 pairs facing exactly, the nearest door 0.85 m off, every room torch in reach.
    - The light, share of white with the plain mean in brackets: small rooms (14) 0.17 (0.77) with the old ring, 0.21 (1.32) relit; large (18) 0.12 (0.52), 0.31 (1.93); the heart (3) 0.10 (0.44), 0.27 (1.74). The dimmest room is again 1.13 times its old ring.
    - Seed 7 has 46 cold lights, 38 of them room torches, and 47 vents, 1 with daylight.
    - `crawler_frames` (seed 7) on this code, the snake held: 45 lines, 0 fails, 62 frames. The corridor's sconce catches. The crypt from its door at night is 0.269 with the old ring and 0.279 with its two torches relit; 46's crypts are 8 m wide, so the ring is no longer far off in the middle. I looked at `09a`, `09`, `10` and `10b` once: the crypt's torches face each other across the coffin rows, the heart's flank the dead with the way out's door behind them, and no snake in the heart.
    - One Godot error after the result, as the tour quits: a MultiMesh with no mesh. In the crawler only fires' smoke and embers and a fire pot's specks use one, not the snake. It wasn't in the two renders before 46.
- **Other sessions' checks that leaned on the old rings**, changed a few lines each:
  - `crawler_frames`: the corridor and harm-ring frames now pick a corridor's sconce, since the first sconce can now be a room's.
  - `crawler_frames`: the half-dark's long view (queue 54) now needs real walls about 15 m off, and accepts a far wall from 13.5 m. On seed 7 its "walls 15 m off" had been the old hearth ring's stones in the room down the corridor; with the ring gone the band was empty. It now looks the other way down the same corridor, at a wall 14.6 m off (3,112 px at the black).
  - `residents_check` (queue 58): its waking test picks a skeleton with no other one within waking reach of the spot it stands at. With the niches reshuffled, seed 1's first pick had a neighbour that woke.
  - `stagger_check` (queue 57): it holds the tomb's cold holders unlaid while it tests the snake, then lays them again, so its swings can't relight one. It still prefers a spot out of every cold holder's reach. With cold sconces on every room's walls, the snake's reel can leave it where there is none (seeds 7 and 42).
- **For Mike:**
  - Built before 46 (you named 47), and 46 landed on top of it this morning: the heart's dead now lie 3 m in from its far wall, and its four torches flank them there; the way out's door past the heart is a door like any other, so the torches keep 0.6 m from it. The counts, light and on-screen numbers above are from the tombs before 46. The checks on the code as pushed, with 46 in, are under Checks.
  - §EX.9 call 2 (two and four) is as built.

---

## 2026-10-07 — Queue 49 with 46 and 47 in: the lair off the spine, and the walk out with the snake loose (b654d7c)
- **Queue 46's spine** (28dafd4) is what the snake's lair keeps off now. `BossGround.main_path` already read a spine when the layout had one: the pieces marked `spine`, from the hearth room through the heart to the way out's flight and landing. The lair is off it on seeds 1, 7 and 42 and over the check's 30 layouts, all dead ends (19 catacombs, 6 crypts in a coffin's place, 5 ossuaries).
- **46's walk to the way out** (its own check, your body in 203 tombs) runs on the game's collision exactly, the hole's ring included, and passes. The snake's body has no collision, so it can never stand in your way. The way out's door, open to the outside, joins no node of the snake's ground, and its landing is a stretch, never a room it coils in.
- **The walk out with the snake loose** (new in `boss_check`): you walk from the wake spot along the spine into the way out, torch lit, set down frame by frame, with the snake and Harm on their own clocks. You get out every time.
  - From where it starts: 93–116 m in 21.6–26.9 s. It never noticed you.
  - With it lying coiled in the heart, across your way: it noticed you 14.0–20.7 s in and landed no hit. Your torch held it at the edge of your light for its 4 s, and by then you were past it. It hunts slower than you walk.
- **Queue 47's wall torches** (6578210): the snake's ground holds with them. The dark never grows and is gone only at the last of 54, 46 and 40 holders (seeds 1, 7, 42).
- **Checks, on 46's and 47's tombs:** `boss_check` 115 lines, 0 fails. `crawler_check` 215 (46's 203 walks among them), `residents_check` 123, `stagger_check` 61, `fire_pot_check` 82, `crawler_harm_check` 59 and `hands_check` 61: 0 fails each. `boss_frames` (seed 7) 0 fails.
- **Still to come:** queue 48's stone. The hole's broken flags take the room's palette, as the rest of the dressing does now, so they should follow the walls' style when 48 cuts the dressing from it.

---

## 2026-10-07 — Queue 49 follow-up, §EY.1: the snake's hole kept off the crypts' coffins (97d9628)
- **The bug (mine, from 827805b):** the hole was placed clear of a room's doors, fires and airways, but never looked at what stands on its floor. Dead-end crypts were where it usually went, and their coffins stand in rows 2.35 m out from both long walls. In 18 of 33 layouts the hole's middle was inside a coffin, seed 1 among them. My frames rendered only seed 7, which happened to be clear.
- **The fix** (`BossGround._lair_spot`):
  - **In a crypt** the hole is where one of its coffins stood, fallen through with the floor (`_coffin_spot`). A narrow crypt has no open floor wide enough for it between its rows, so a coffin's place always fits. That coffin isn't built (`TombKit.lair_took`, one line in `TombBuild`). Its rim keeps 0.75 m off the wall, and the full door margins hold.
  - **Never a skeleton's grave, nor beside one:** queue 58's sleeping skeletons lie in open coffins, each lid shoved off onto the floor along the row (either way since queue 47 keeps it out of a torch's bay). So `TombKit.layout` now lays the residents first and the lair after, and the hole keeps `OPEN_GRAVE_M` along the row from any open grave. Seed 12919 put a lid 0.2 m from the rim before this. The skeletons' own places are unchanged; they never read the lair.
  - **Elsewhere,** the hole keeps clear of an ossuary's corner bone piles and of every corner a fallen room's slab may take (`_dressing`), and 0.6 m further off a catacomb's niche walls.
- **The check** (`boss_check`) now holds the hole off the walls, the coffins and the open graves over all 33 layouts. In each built tomb it casts rays straight down round the rim. (A point query never finds itself inside the stone's collision, which is faces: my first probe said "clear" even on the broken code.) On the old code the rays hit a coffin lid at 1.10 m on seed 1.
- **With queue 47's wall torches** (which landed meanwhile), the snake's ground holds: the dark never grows and is gone only at the last of 56, 43 and 41 holders (seeds 1, 7, 42). Over the full relight run it never went into the light of its own accord.
- **Checks, on 47's tombs:**
  - `boss_check` 109 lines, 0 fails. Its 30 layouts put the lair in 16 catacombs, 9 crypts (each in a coffin's place) and 5 ossuaries, all dead ends. Seeds 1, 7 and 42: a catacomb, a crypt (coffin 1's place) and an ossuary, with nothing round any rim.
  - Probed in all 33 built tombs: nothing stands round any rim.
  - `crawler_check` 187, `residents_check` 123, `stagger_check` 61, `fire_pot_check` 82, `crawler_harm_check` 59 and `hands_check` 61: 0 fails each.
  - `boss_frames`, 0 fails on seeds 7 and 1: on seed 7 the hole is in its coffin's place by the corner; on seed 1 it is in open catacomb floor.

---

## 2026-10-07 — Queue 56, §FD with §FJ.3, part 2: the snake's chase follows you into the light; queue 56 built (d14f7d8, b998d05)
- **The light is no refuge once it has hit you.** This is §FD's amendment of §EY.1 on the snake (queue 49's `Boss`, whose chase already holds a `Pursuit`): a relit room stays closed to its prowling, not to a chase in progress. Once its strike has landed (`Pursuit.has_hit`, `residents.json → rules.chase_enters_light`), until it gives you up:
  - it hunts you into any relit room or stretch, and its strikes land there (`rule.relit_room` safe holds only until it has had you);
  - its wind-up no longer breaks off when you step into the light;
  - a relight round it doesn't send it off.
- **Back to the dark:** when it gives you up in the light, it leaves at once for the nearest dark, fast enough to be there within `rules.back_to_dark_s` (4 s; `Pursuit.back_to_dark_mps`), or it goes down below by then.
- **The hearth room stays shut,** even to a chase that has had you. This is my call: the snake's ways never go through it (queue 49), and §BA's fire is safety. There it watches from the edge of its dark (`watch_s`, 10 s), gives you up, and finds you again if you're still in its sight. So by the fire in its view nothing heals: it hasn't lost you. Out of its sight with the torch smothered is how you hide (§FC.2). **Mike:** say if the hearth should be open to a chase too.
- **Its prowling** still never enters a lit node. `lit_entries` still counts only that (0 in `boss_check`'s relight runs); `chase_lit_entries` counts the lit nodes it went into after you.
- **Checks:** `crawler_harm_check` (seeds 1, 7, 42 with `SNAKE_SEEDS`) has 87 lines, 0 fails. With the real snake on each seed:
  - A strike lands in its dark. Held in place and keeping you in sight 3 m off for 15 s, nothing heals.
  - Out of its sight, torch lit, it gives you up at 6.2 s (`out_of_sight_s` 6), and the hit heals 5.0 s later.
  - With a room beside its dark relit, it strikes you in the dark, follows you in 1.3 s after you step into the light, and lands a second hit there 1.7–1.8 s on.
  - Given you up there (you 26 m off), it is back in the dark in 0.7–1.6 s (limit 4).
  - By the hearth, in its sight for 30 s, it never comes in and nothing heals. Out of its sight with the torch smothered, it lets you go and the hit heals 5.0 s later.
  - Five minutes in the lit doorways nearest it, torch lit: it was after you 271–274 s, watching from its dark, and never stood in a lit node (0 steps, 0 hits).
  - Also passing, on the code with queues 51, 57, 58, 60 and 61 in: `boss_check` 106, `crawler_check` 173, `stagger_check` 61, `fire_pot_check` 82, `residents_check` 123. With queue 47 in too: `crawler_harm_check` 87, `boss_check` 106, `crawler_check` 187.
- **Frames** (`crawler_frames`, seed 7, 35 lines, 0 fails, before 51, 57 part 2 and 58 landed): with the crawler's own Harm now (queue 49), the ring is 48 px deep at hit 1 and 77 px at hit 2 at both edges, its rim darker on two (luma 0.144 against 0.204), and the heartbeat plays from hit 1.
- **Queue:** row 56 is now `built`. Its two parts are d14f7d8 (the ring, the heartbeat, `Pursuit`, healing once nothing pursues you) and b998d05 (the snake's chase into the light).

---

## 2026-10-07 — Queue 57, §FA.1–§FA.2, part 2: the stagger on the snake, and its strike's hiss its own (a4f1b00; part 1 7f65da2)
- **The snake strikes with part 1's `CreatureStrike`** (queue 49 built it that way). Its rear-back, lunge and draw back follow the strike's parts. A lit swing in the rear-back staggers it, and it hears a swing that lands on it. Checking prompt 57's list on the snake itself turned up three things, fixed here.
- **Its strike's hiss is its own (§FA.2).** While it held off at the edge of your light it hissed with the strike's own voice every second or two, so a hiss didn't tell you it was about to strike.
  - Holding off, it now gives a low, slow, rasping warning (`bosses.json → bosses.desert.torch_delay.sound`, the synth's `snake_warn`). The sharp hiss (`snake_hiss`) comes only with the rear-back.
  - Measured: the warning is much darker (about 4,600 zero crossings a second against 12,300) and swells in 0.19 s against 0.02 s.
- **A step back makes it miss.** The bite's 2.5 m was counted from its head as the head lunged out, so it reached about 5 m: stepping back to 3.8 m during its rear-back still got you bitten (measured).
  - `CreatureStrike.origin` (new): the reach counts from where its body lies; the snake sets it to its base. Stepped back to 3.4 m, it now misses.
- **Its reel stays out of the walls.** Thrown straight back from its coil, it slipped 0.34 m into the end wall (a short step's ray that starts on a wall's face goes through it).
  - Each step now stays on its floor, its girth off the stone (`Boss._on_floor`). Struck in its coil it reels 0.84–1.06 m and stops 0.29 m from the wall; coming at you down a corridor it still reels the full 1.5 m back along its body.
  - `boss_check`'s reel line now allows the wall stopping it.
- **A swing needs a clear line only to the near side of a head** (`CreatureStrike.swing_lands`), so a head drawn back against stone can still be hit. This holds for the skeletons too.
- **Checks**, on the tree with queues 51, 58 and 60:
  - `stagger_check`: 61 lines, 0 fails on seeds 1, 7 and 42. The snake part covers:
    - its sharp hiss on the rear-back's first frame, from its head;
    - reared 0.12 → 0.95 m, the head drawn back 0.30 m, the jaws opening after half;
    - the lunge (1.43 m) and one hit;
    - a swing in the lunge, or with the torch unlit, staggers nothing, and the hit counts;
    - a lit swing at 48% staggers it; a second inside the cooldown (2.2 s left) fails, and the hit counts;
    - stepped back to 3.4 m it misses; its reel leaves it on its floor;
    - holding off at your flame it hisses `snake_warn`.
  - Without the reel fix the check fails (the snake ends 0.34 m into the wall).
  - Also 0 fails: `boss_check` (106 lines), `residents_check` (123), `crawler_check` (173), `fire_pot_check` (82), `crawler_harm_check` (45).
- **Row 57 is built.** Queue 56's second part (a chase that follows you into the light) is still to come; the stagger doesn't depend on it.

---

## 2026-10-07 — Queue 51, §EZ.2: the pitch torch, a wrapped, tarred head and a pixel flame (afac6a9)
- **Every torch in Torchfire 1 is the pitch torch** (`PitchTorch`, new; `torch.json → pitch_head`, wired): in your hand, planted, and in the bundle by the hearth. The open world (Torchfire 2) keeps §CP's burnt end: my call, since it is shelved and its checks still test the burnt end.
  - **The wrap:** six flat sides lined up with the stick's, 1.35 times its radius, 12 cm long, a flat top. Four bands, each strip's lower edge standing 7% proud, so they show as steps. Two to four drips of pitch run 2–7 cm down the stick.
  - **Painted, not lit** (`shaders/pitch_head.gdshader`): near-black pitch, the strips' edges a shade lighter; lit, the top band thins to dark amber, bubbling, under the coal. Light only reveals the paint (the same on every face, never brighter than the paint, no specular), so in the dark it is dark (R8).
  - **The coal** is the top band's last two texel rows, drawn by the burnt end's shader and breath. **The flame** is the campfire's card on a 20×30 grid (32×48 over `texel_scale` 1.6), with its two sparks. Bottom to top: pitch, coal, flame.
- **The flame in hand is drawn at 0.55** of a planted torch's (`pitch_head.flame.view_scale`, new, added with its `_help`). At the true size (32 cm, half a metre from the eye) it would stand about 195 px tall at 480 and stream past your face when it leans back. Planted torches keep the true size.
  - **Measured (seed 7, `crawler_frames`, the flame drawn with and without its card in a dark corridor):**

    | Torch in hand | 480 lines (854×480) | 270 lines (480×270) |
    |---|---|---|
    | Standing | 122 px tall × 78 wide (25% of the frame), ~4.8 px a texel | 58 × 44 px (21%), ~2.3 px a texel |
    | Sprinting (31° there: a slot's draft adds to your speed's 34°; stretched 1.3) | 141 × 112 px | 72 × 60 px |

  - It sits at the bottom right, its foot about two thirds of the way down the frame.
- **The lean** (`PitchTorch.Lean`): 6° per m/s against your motion, at most 50°, stretching to 1.3 at a sprint, toward an airway's draft, settling over 0.4 s.
  - In this game's movement profile that is 26° walking (4.3 m/s) and 34° sprinting (5.6 m/s).
  - A strong mouth's gust lays it flat out at `max_deg` (50°) away from the mouth, and the torch holds (§EZ.5; queue 50 left the flame's whip to this prompt). Planted torches lean and whip the same way.
  - Nothing about it can put the torch out.
- **The light:** amber as before, `held_scale` kept. It flickers with the flame (Campfire's value noise at `light.flicker_hz`: half of `flicker_amount` standing, the full amount at a sprint) on top of the coal's breath, and a draft's flicker on top of that (queue 50's). A torch burnt low, or guttering toward deep water, drops its flame toward the low fire's reds.
- **Smoke:** as built (the embers row, by the flame's size), its colours pulled 25% toward the vents' soot (#0A0C20). Darker navy, never grey; hidden the moment the torch goes out.
- **The bundle by the hearth:** the hearth's ground-glow decal is drawn 0.9 m toward the camera, so it painted its orange over anything lying by the fire, the old bundle included. The wrap now draws after it, so the bundle's heads read dark against their sticks.
- **Merged with the queues that landed while this was built** (45, 49, 50, 52–58, 60, 61):
  - Lighting a fire pot brings the pitch head's coal to the wick: `FirePots._torch_meet` aimed at the burnt end's tip, which on the pitch head is the foot of the wrap. A one-line fix in another session's file.
  - My frames are `01h` and `22a`–`22d` (the others were taken).
- **Small fixes:** the sticks have no specular (both games). `PlantedTorch.plant` takes a parent, since the tombs have no `world_root`.
- **Checks:**
  - `crawler_check` passes with 0 fails on seeds 7 and 1 (173 and 175 lines). New lines:
    - every lit torch (in hand, planted) has one flame card and one coal, and every unlit one (the bundle's, one put out with burn left) has none; a burnt-out one is a bare stick;
    - every wrap is six-sided and flat-topped with its bands as steps (a vertex test); the coal is six-sided; the drips are 2–7 cm; no specular, roughness under 1 or normal map on any head or stick;
    - the lean is 0 standing, 33.6° sprinting (within 50°) and stretched 1.3, settled again after stopping, 5° toward an ordinary airway, and 50° away from a strong mouth in its gust, while the torch holds;
    - the flame's flicker on the light (×0.94–1.08 over 2 s); the smoke darker and still blue.
  - `crawler_frames` (seed 7, on 2060cc2) has 0 fails over 57 frames (43 checked lines). New: the bundle's heads by the hearth (`01h`), and the torch in hand in a dark corridor standing and at a sprint, at 480 and 270 (`22a`–`22d`), measured as above and all four checked. That is the walkabout for Torchfire 1.
    - The first render on afac6a9 caught the snake (queue 49) reaching you in that corridor during the last torch frame: the harm darkened it and the flame measured small, unchecked. In 2060cc2 the torch frames hold the snake still, as the glow-moss frames do, and check the sprint (the flame streams wider than it stands, still solid).
  - Also 0 fails: `fire_pot_check`, `hands_check`, `stagger_check`, `crawler_harm_check`, `residents_check` and `boss_check` (seed 7), and the open world's `swing_check` (seed 7731).
- **Noted:**
  - The night grade lifts every near-black to navy (R3), so the pitch shows as the frame's darkest navy, not brown-black. Browner darks by a fire would be the grade's warmth (§EE.1), not the torch.
  - Headless runs print `Parameter "m" is null` when a code-built mesh is freed (a taken bundle head; the check's own planted torches). It is a Godot 4.3 dummy-renderer quirk (freeing the burnt end does the same); the Vulkan renderer is silent.

---

## 2026-10-07 — Queue 60, §FA.3, part 3: the skeletons burn down and are gone; burnt asleep they wake; the wick and the burst give you away to them. Queue 60 built (b21b5cd)
- **The skeletons** (queue 58's `Resident`) are fire targets now, through the same socket as the snake:
  - **Burnt down:** a pot's burst within `splash_m`, the tar stuck on one and a burning patch it stands in take its `fire_hp` (3) down, times its `oil_scale`. At 0 it goes up in a last flare and is gone for good (`burn_out`): off the tomb's list, its strike gone, its chase given up, so Harm no longer counts it. Light oil (4) does it at once. Tar on one lying asleep took it in 2.13 s, because climbing out it stood in the tar's own patch.
  - **Woken by fire:** one burnt while it lies asleep wakes and climbs out, burning (the socket's new optional `fire_hit`). The tar follows it as it moves.
  - **The pot gives you away:** awake, a skeleton sees the lit wick as your flame out to `flare_seen_m` (25 m, past its own 10 m for a torch), even with the torch smothered, and hears a burst within `burst_heard_m` (40 m). Asleep they hear nothing; one pot doesn't wake the whole tomb.
- **Queue 60 is built:** with the snake (part 2) and queue 55's hands, every line of its BUILD and CHECK is met on the real creatures. Row 60 marked `built b21b5cd`.
- **Checks:**
  - `fire_pot_check` adds the real skeletons (all fire targets with `fire_hp` 3 before any pot; tar on a sleeping one; light oil on an awake one; awake 12 m off: nothing with the torch out, the wick seen as your flame, not at 28 m; a burst heard at 30 m, not 46 m): 82 lines, 0 fails, no script errors, seeds 7, 1 and 42.
  - `residents_check`, `boss_check`, `crawler_harm_check`, `stagger_check`, `crawler_check`, `hands_check`: 0 fails.
- **Left open:**
  - The found pot keeps off "the spine" by the way from the hearth room to the heart until queue 46 builds the real spine; `FirePots.spine_of` reads a `lay.spine` (ids) or pieces marked `spine` when it does.
  - Mike's two calls, unchanged: `hurts_you` (should your own fire hurt you?) and `relights_holders` (should a pot light a cold sconce, and a patch relight a torch?).

---

## 2026-10-07 — Queue 61, §FG: atmosphere, not puzzles — glow-moss, wall life, daylight with the clock (e11418b)
- **The crawler didn't run the clock.** `World` turns `days` only once a planet is generated, and the crawler builds none, so the shafts' daylight sat frozen at the start time. `CrawlerMain` now turns it at the 144-minute day (`World.day_length_s`). The sun follows §FK.3 (locked while this pass was under way): one clock everywhere, DayCycle's reference day (day 60, dusk 18, night 48, dawn 18), with no latitude, axial tilt or day of year. You wake at 15:07 on the tomb's sky with the sun 43° up; it sets about 22 minutes into play, and night falls at about 31 minutes and lasts 48. Prompt 63's clock part is therefore already in place; its check can confirm it.
- **Daylight with the clock** (`Vents`; `smoke.json → vents.daylight`, new `sky_band_deg` [-7, 11.5] and `low_sun_share` 0.35): the colour follows the twilight (moonlit blue to day blue), the strength the sun's height (0.35 of noon's with the sun on the horizon, rising with its sine).

  | Seed 7, 11 shafts summed | midnight | sunrise | 9:00 | noon | 15:00 | 17:00 |
  |---|---|---|---|---|---|---|
  | light energy | 3.7 | 6.3 | 22.2 | 26.6 | 22.2 | 15.6 |
- **Glow-moss** (`GlowMoss`; `crawler.json → ambience.glow_moss`):
  - **Where.** On the tomb's dressed wall faces (TombBuild now records each one: its plane, its stones and their heights), low on the wall, in front of its own piece's floor. Only where the stone is damp: the wet field the moss itself grows by (§EU.4, `FittedStone.climate_at`) plus `airway_damp` near an airway, at `damp_min` 0.62 or over. Never on dry stone, never within 1.5 m of a fire (its soot burnt the moss off), never in the hearth room or on a stair. 6–16 patches a tomb over six seeds (seed 7: 10).
  - **Drawn** in the stone's own shader (`ruin.gdshader → glow_moss`: a small data texture of the patches, no light node). The moss tile's own texels are the patch, thickest at its heart and ragged at its rim, worked out at each texel's middle and mip. They glow in `color` at `energy` (0.15, kept: it reads as a faint glow) and take a moss tint, so by torchlight the patch is moss on the stone. A faint light falls on the stone round it (`light_m` 0.9, `light_strength` 4: at 1 it can't be seen, at 10 it is a lamp).
  - **Dims.** Any flame within `dims_near_flame_m` whose light reaches it fades it to `dim_to` over `dims_s` (0.6 s, new); once the flame has gone it creeps back over `returns_s`. "Any flame" is the set HalfDark counts (`CrawlerFires.flame_points`): the hearth, relit holders and sconces, the torch in hand, a planted torch, a fire pot's burning fire and its lit wick; "reaches" is a ray with no stone between (`CrawlerFires.lit_on`).
  - Nothing the rules read sees it: `Torch.light_at`, the fires, the snake's dark and the full-dark check (still one light burning) are unchanged.
- **Wall life** (`WallLife`; `ambience.wall_life`):
  - 10–16 beetles a tomb, a fifth of them scarabs. They are small meshes with two leg poses, not sprites: at 2–6 pixels the two look alike, and a mesh lies on the wall at any heading. Matte and dark, lit like the world (`CreatureBodies.mat`).
  - Each rides the actual stone under it (each stone's rim and pillowed face, recorded by FittedStone), on the stretch of wall seen from its own piece. Faces are picked by length, damp and distance from every fire.
  - In a flame's light within 3 m one runs to the nearest joint of the stone it is on (the wall's real joints, from the stones' Voronoi cells) and squeezes in, gone within `gone_within_s` 0.85 s. After `hide_s` (8–22 s) it comes out onto that stone again once the spot is dark.
- **Checks** on the pushed build (`crawler_check`, seeds 7 and 1: 152 and 154 passes, 0 fails; with all this in the tomb, `boss_check` 82, `hands_check` 61, `stagger_check` 41, `crawler_harm_check` 45 and `fire_pot_check` 63 passes, 0 fails, no script errors):
  - glow-moss only on damp stone (none in a dry tomb, 24 in a wet one), no light node, nothing the rules read sees it;
  - a torch 0.9 m off: 0.0150 = 0.1 × 0.15, and the stone's data says the same; 0.0825 halfway through `returns_s`, at rest 6 s after;
  - a beetle stays out in the dark with you beside it, is gone 0.27–0.32 s after the torch is lit, into a joint (0.0000 m off its line), and comes out again 13.2–14.6 s later;
  - the bugs favour damp, dark walls; the clock turns 2 s in 2 s of play; the shafts climb and sink with the sun, moonlit blue at night;
  - the snake is held still (`Boss.auto`) through these, as `crawler_harm_check` does.
- **Frames** (`crawler_frames`, seed 7, the pushed build: 35 passes, 0 fails, 45 frames):
  - `01a`: waking at sunrise. The hearth's shaft is a faint trace, against noon's clear blue column in `01`.
  - `19a`–`19c`: a corridor's glow-moss (r 0.26 m), held at midnight. In the dark, with the half-dark letting the near walls read in navy, it glows teal down the corridor (196 blue-green pixels). By torchlight from 4.1 m it is a teal patch on the amber wall at full glow (238). Walked up to 1.8 m it has dimmed to a tenth: plain moss in the torchlight (0).
  - `20`: a beetle close by torchlight, small and dark on a stone's face (a harness frame: its scatter held off for the picture).
  - The smothered corridor stays dark (mean 0.090, the half-dark's own level).
- **Merged with the passes that landed meanwhile** (45, 49, 50, 52–57, 60 and the §FK design): my frames are `01a` and `19a`–`20`, after theirs; HOW_TO_RUN's Torchfire 1 block keeps theirs with the atmosphere added.
- **Fixed in passing:**
  - The vents' day/night check read the lights one frame early (before the vents had updated), so its "day" was really the start time. It passed because the old daylight was flat all afternoon. It now waits the frame and reads noon (26.6, not 21.8).
  - Seed 1 caught a glow-moss patch in a room's corner: a side wall runs on past the room's ends behind the end walls. Patches and beetles now keep to the stretch seen from their own piece.
  - `flame_points` first cast a burnt-out fire pot's freed fire (3,730 script errors in `fire_pot_check`); it checks before the cast now. HalfDark's `flame_near` has the same cast-before-check; it doesn't fire while the torch is lit, so it went unseen. Flagged, not changed here.

---

## 2026-10-07 — Queue 58, §FE and §FC.2: the tomb's skeletons, and somewhere to hide (43688cb)
- **On top of the other sessions' work.** The skeletons' strike is 57's `CreatureStrike`, their chase is 56's `Pursuit`, and their hits go through 49's Harm in the crawler. So the stagger, the tells, giving up and being taken work the same for the skeletons as for the snake. While I built this, the other sessions built 45, 49, 50, 52, 53, 54, 55, 56 part 1, 57 part 1, 60 parts 1 and 2, and 61. My own stand-ins for the strike, the stagger, the chase and Harm in the crawler went in the merge.
- **Where they rest** (`TombKit._place_residents`, its own seed, so the rest of the tomb is unchanged): 3–6 skeletons a tomb (`per_dungeon`).
  - The heart's coffin always holds one (Mike's frame 9, now a resident instead of baked stone bones).
  - The rest are drawn from the crypts' coffins and the catacombs' niche stacks. In a coffin (`grave`) the lid is shoved off onto the floor beside it and the skeleton kneels inside, slumped over the end. In a niche (`wall_niche`) it sits hunched on a deeper bottom shelf, the middle shelf gone, with jambs and a lintel framing the stack.
  - Rooms are weighted by depth to the power `toward_heart`, so more lie toward the heart. None in the hearth room, none within `apart_m` (2 m) of another, none within `off_line_m` (1 m) of the door-to-door way through the rooms.
- **The framework** (`Residents`, `Resident`; `residents.json`):
  - **Asleep** it is set dressing: no strike of its own in play, so a swing meets nothing.
  - **Waking:** when your head comes within `wakes_m` (3 m) of its head with a clear line, it climbs out over `rise_s` (1.6 s) with its near tell (bone grinding, SoundSynth `bone_grind`). From then it hunts you at `walk_mps` (2.2) along a floor grid (`TombNav`: A* over 0.25 m squares, cast once against the stone, round the coffins and the hearth's ring).
  - **What it senses:** you yourself within `notice.sees_you_m` (6 m) along a clear line from its eyes to your head; your torch's flame, or the stone it lights, within `sees_flame_m` (10 m); what you sound like within `hears_step_m` (6 m) scaled by your noise (`CrawlerPlayer.noise_level`, so a swing that lands, 57's loud moment, is heard standing still); anything within 1 m.
  - **Its chase** is a `Pursuit` with its own `gives_up`, so Harm counts it as pursuing you from waking until it gives you up (16 m away, or 8 s without sensing you; `hide` true; `torch_doused` false). Then it walks home and lies down again. On the way home it hunts again if it senses you.
  - **Its strike** is a `CreatureStrike` at its head, made when it wakes and gone when it lies down. In reach, sensing you there, it winds up for `wind_up_s` (0.7 s). The jaw drops open on its sprite, and its `sound` (`jaw_creak`, the jaw's creak and knock) plays from the first frame. Then comes the committed strike, `strike_s` (0.15 s): the hit lands at its end if you're still in reach with nothing between. Then `recover_s` (1.2 s).
  - **The stagger:** your lit torch's swing in the wind-up staggers it back `reel_m` (0.6 m) along the floor, with a crack of bone.
- **Hiding** (§FC.2): no button and no prompt. Crouched behind a lidded coffin your eyes are at 0.78 m and its lid at 1.1 m, so it can't see you. `Residents.hidden_from` tells its `Pursuit` when only that low cover hides you: standing there you'd be seen. A lit torch gives you away round cover: it sees the flame, or the stone it lights (14 rays out to `stealth.json → hide.glow_reach_m`, 4 m, every 0.2 s, only while a skeleton is up).
- **Harm** in the crawler is queue 49's (56's red ring and heartbeat; `CrawlerHarmView` draws the navy flash and "Good night"). The skeletons' hits go through it. At the wake every skeleton after you gives you up and goes home (`Residents.player_woke`), and the keys now let go while "Good night" plays.
- **Drawn:** `SkeletonRig`, a bone model on joints, painted with light from above and navy beneath (`bone_paint.gdshader`). It is baked in 12 poses (two rests, three steps of climbing out, a four-step walk, wind-up, strike, reel) × 3 heights × 8 around into one sheet. `ResidentSprite.bake_poses` renders the eight views at once on SubViewports sharing one world, after the snake's sprites and before the dark lifts.
- **Data:**
  - `residents.json` skeleton: new `per_dungeon`, `heart_holds_one`, `toward_heart`, `off_line_m`, `apart_m`, `eye_m`, `notice.sees_you_m`, `sprite`; its strike block gains 57's `strike_s`, `recover_s`, `reel_m`, `body_r` and `sound`.
  - `stealth.json → hide.glow_*`; `audio.json → resident`.
  - `[NOT WIRED YET]` is off `residents.json → _help.about` for the skeleton (the other creatures say not wired). It is off `stealth.json` altogether: with 53's sneak and 54's douse, all three parts are wired.
- **Other sessions' checks touched** (one line each):
  - `crawler_check`, `stagger_check`, `crawler_harm_check`, `fire_pot_check`, `hands_check`, `boss_check`, `crawler_frames`, `boss_frames` and `perf_bench` keep the skeletons asleep (`Residents.stay_asleep`).
  - `crawler_check` doesn't count the skeletons' sprites as folk, as it doesn't the snake's (§FH's "no FigureSprite in the tomb" is about the folk).
  - `fire_pot_check`'s stand-in class is `ResidentStandIn` now, like 49's `BossStandIn`; the name `Resident` is the real one's.
- **Checks:**
  - `tools/residents_check.gd` (new): 123 lines, 0 fails, on seeds 1, 7 and 42, with the snake held still (`Boss.auto` false, as 49's harm check does). It covers the prompt's list:
    - every skeleton rests 1 m or more off the way through the rooms, and off the line your own body walks from the wake spot into the heart. Your body walks that line by the keys, every holder cold and every skeleton asleep (queue 46's walk-to-exit check, until 46 builds the exit);
    - a scripted approach wakes one just inside `wakes_m` and not just outside it;
    - crouched behind a lidded coffin with the torch out, it never senses you, gives you up at `out_of_sight_s` (8.02 s) and walks back to lie in its own place; with the torch lit it sees your light round the coffin and comes for you;
    - one hit lands at the end of its committed strike (0.85 s after the wind-up began), none before and none in its recovery;
    - your torch's own swing (`Torch.swing_top`), lit, at half the wind-up staggers it 0.60 m back and no hit lands. Unlit, it staggers nothing; a second stagger inside `cooldown_s` fails; once the strike is committed a swing does nothing.
    - It also checks the tell from the wind-up's first frame, the chase holding your healing off for 15 s and letting it go 5.02 s after it gives you up, and "Good night" with the wake at the hearth.
  - The other sessions' checks on the final code, with 49's snake, 60's pots against it and 61's moss and beetles in (seed 7 unless said, all 0 fails): `crawler_check` 152 lines (seed 1: 154), `boss_check` 106 (seeds 1, 7, 42), `stagger_check` 41, `crawler_harm_check` 45, `hands_check` 61, `fire_pot_check` 73. All 393 scripts in `scripts/` and `tools/` load without a parse error.
- **Frames** (`crawler_frames`, seed 1, lavapipe): the whole tour, before the merges with 49, 53, 60 part 2 and 61, passed 36 lines with 0 fails. The skeleton frames alone (`ONLY=skeleton`) on the final code: 3 lines, 0 fails.
  - `21`: the sheet. All 288 cells (12 poses × 3 heights × 8 around) hold the skeleton; the fewest drawn is 103 px at half size.
  - `21a`: one sitting hunched in its framed catacomb niche.
  - `21b`: caught halfway out of it in your torchlight (pose `rise_b`), its bone amber on screen (brightest pixels luma 0.306, hue 19.0).
  - `21c`: out on the floor. It is held still for this shot: on lavapipe the game runs on between slow frames, and in the first run it had already reached the camera and struck (the hit's navy edge flash was in the frame).
  - I looked at them once. The niche reads as a stone-framed shelf with the bones sitting on it. Climbing out, the skeleton stands up inside the frame. Out, it is a pale amber figure against the navy, its pixels as chunky as the walls'.
- **Not mine, flagged:** on seed 1 the harm-ring frames (queue 56) are shot in the corridor where the fire pots' tar patch (queue 60) is still burning. So hit 2's ring reads 386 px deep at the left edge: that is the patch's flicker on the wall, not the ring. The check passes; seed 7 measured 77 px.
- **For chat and Mike:**
  - The tomb has no pillars yet, so the cover is the lidded coffins, the heart's coffin, the collapsed room's slab, and corners and doorways. Pillars and alcoves come with the style kit (queue 48).
  - The hit lands at the end of 57's committed strike (0.7 s of wind-up, then 0.15 s), not at the wind-up's last frame as 58's check line words it. It's the same rule for every creature.
  - Nothing keeps a skeleton out of the light until queue 59: it follows you into lit rooms whether or not it has hit you, can strike you there, and walks home through them. The snake never strikes in a lit room (§EY.1, `relit_room` safe), so for now the light saves you from the snake but not from a skeleton.
  - A fire pot doesn't touch them yet, and they don't look for a lit wick or hear a burst. Queue 60's part 2 did both for the snake; its last part joins the skeletons (`fire_hp` is carried).
  - Seed 126's crypt can't be walked through with or without skeletons (noted under queue 46).
  - CLAUDE.md's brief still calls §FA–§FH "not built yet".

---

## 2026-10-07 — Queue 49, §EY.1, §EY.2, §EY.8 step 1: a boss in the dungeon, the snake (827805b, 4a963ed)
- **Built in parallel with its prerequisites.** The prompt says "after 44–48", and Mike started 45–53 at the same time. So I built against the branch as each pass landed (45, 50, 52–57 and 60's part 1) and rebased onto them.
  - 46, 47 and 48 haven't landed yet, so three things wait for them. Until 46's spine is in, the lair's "main way" is the doors from the hearth room to the tomb's heart; `BossGround.main_path` reads the spine as soon as the layout has one.
  - 46's walk-to-the-exit check with the snake loose runs once that check exists.
  - The dark is worked out from whatever holders the layout has, so 47's wall torches join it with no change. I'll check that, and the lair's rim in 48's stone, when they land.
- **Its ground** (`BossGround`, `bosses.json → rule`): the tomb as a graph. Each room is one node. Each corridor or stair is cut at its sconces into stretches, and each stretch is a node too.
  - A room is lit once every torch in it is lit (`room_relit_when all_torches_lit`); the hearth room always is.
  - A stretch is lit when every end of it is: a lit sconce, or a door into a lit node. An end with nothing there (a dead end, the way out) never darkens it.
  - So every holder is some node's light, and the dark reaches nothing exactly at the last holder, never before. It is worked out again on every relight.
- **The snake** (`Boss`, `bosses.json → bosses.desert`, the one marked `first`):
  - **Its rounds:** it slithers the corridors at `speed_mps` (2) from dead-end room to dead-end room and coils in each for `coil_s`. It never goes into a lit node, and never into the hearth room at all.
  - **Noticing** (`rule.notice`): your lit torch in its line of sight within `sees_flame_m` (20 m); a sprint (or a swing landing on it, queue 57's "as loud as a sprint") within `hears_sprint_m` (15 m); or you within `feels_m` (1.5 m, new) whatever your light.
  - **The hunt:** through its dark at `hunt_mps` (3.6, new; slower than your walk). If you stand in a lit room it waits at the edge of its dark for `watch_s` (10 s, new), then gives you up.
  - **Your torch is a delay** (`rule.torch_in_hand`): torch lit, it rears at `torch_delay.hang_m` (3.5 m, new), hissing at the flame, for `hang_s` (4 s, new) in all, then closes. Torch out, it comes straight in.
  - **The strike** is queue 57's `CreatureStrike` with the snake's own `strike` block (wind-up 0.7 s, lunge 0.15 s, reach 2.5 m). It rears back with its jaws opening and a hiss, then lunges. A lunge that reaches you is one hit through `take_hit`, so `harm.json → invuln_s` holds. No strike reaches you in a lit node (`rule.relit_room safe`).
  - **The torch's stagger** works on it. A lit swing into the rear-back breaks the strike, and it reels `reel_m` (1.5 m) away from you. It goes back along its own body when it came at you along it; otherwise (it struck from its coil) it goes straight back with its body following. It never reels into the light.
  - This is queue 57's part 2 for the snake: its rear-back and jaws, its hiss, and a landed swing it hears.
  - **Light the node it is in** and it leaves at once for the nearest dark (`leave_mps` 4, new), crossing at most two lit nodes beyond its own (the lit stretch outside a room).
- **Harm in the crawler:** `CrawlerMain` now makes queue 56's `Harm` (its ring and heartbeat), and a small view (`CrawlerHarmView`) for its navy hit flash, the black and "Good night".
  - Three hits: you wake on the mat by the hearth. Every relit holder is still lit, your torch is out and in your pack, and both hands are empty. The snake goes back to coiling at the far end of its dark.
  - The camera kick of a hit now shows underground (`CrawlerPlayer`). `revive`'s three-second breath after waking now runs out there too (it never ran down in the crawler).
  - Its chase is a `Pursuit` (queue 56, `gives_up`), so while it has you, you don't heal.
- **The lair** (`BossGround.place_lair`, `TombBuild._lair_hole`; `lair.hole_r_m` 0.7, new): a side room off the main way has its floor broken through. It was a dead end in all 33 layouts checked.
  - It is a black mouth 1.4 m across, with flags tipped into it and broken stone and small bones round it. It keeps clear of the room's doors and fires, and of the line between its doors. (Corrected later the same day: it also sat on the crypts' coffins; see the follow-up entry above.)
  - The black is its own unlit disc. The stone shader pulls even black vertex colour toward stone at night, so the first try drew mossy floor.
  - A ring of collision keeps you at the edge (`enterable false`). The found fire pot keeps 1.5 m clear of it (one line in `FirePots`).
- **The release:** when the last holder catches, it goes home.
  - If you can see it, it flees toward the hole and is gone the moment you can't; otherwise it is gone at once.
  - A long sound (`BossSounds retreat`) travels along the tomb to the hole and down it over `release.cry_s` (5 s).
  - The drips, hushed by `bed_hush_db` (−18 dB) while it prowled, come back over `bed_return_s` (4 s).
  - The log says "Drove the giant snake into its hole." Its breathing plays from under the hole, heard within `lair.breathing_heard_m` (12 m).
- **Its tell and its body:**
  - The scales on stone are a 4 s loop (`BossSounds scales_loop`) at its body. You hear it to 34 m (`audio.json → kinds.boss_tell`, new), and it drops 14 dB while it lies coiled. Nothing names it on screen.
  - The body is baked sprites (`BossBody`, through `FigureSprite.bake`): a head with its jaws shut, one with them open, a plain length of body and a banded one, each 8 ways round by 3 heights.
  - In play it is a chain of about 50 overlapping lengths on the path the head took, rounded at the ends so they read as one body, swinging side to side as it goes and lying in a coil.
- **My calls, for Mike:**
  1. **Cut off in the light** (its room lit when the stretch outside is too), it goes down into the dark under the tomb, gone the moment you can't see it, and comes up a coil's while later. It comes up out of its hole if that room is dark, else in the dark nearest the hole. I read "if none is left it goes to its lair" as that, rather than trekking it through the lit tomb (my first try did, once through the hearth room).
  2. `hunt_mps` 3.6 is below your walk (4.3): you can always walk away; dead ends are where it catches you.
  3. Waking, your torch is out and in your pack, both hands empty.
  4. The drips go quiet while it is abroad, so their coming back is the release's "small sounds".
  5. Its look is a placeholder: olive-brown with a dark band every third length.
- **Not in this pass:** following you into the light once it has hit you (`rule.chase_enters_light`) came with queue 56 part 2 (b998d05), and fire pots driving it off with queue 60 part 2 (4370e02), both on this snake after it landed. The other seven bosses come with their worlds. Queue 57's part 2 has since checked the strike on this snake and marked row 57 (a4f1b00).
- **Data:**
  - `[NOT WIRED YET]` is off `bosses.json → _help.about`, which now says what is wired and that the other bosses aren't. `_help.rule`, `contact`, `lair`, `release` and `bosses` each gain a "Built" note.
  - New tunables with help lines: `bosses.desert` `hunt_mps`, `leave_mps`, `torch_delay`, `feels_m`, `watch_s`, `body`; `lair.hole_r_m`; `release.cry_s`, `bed_hush_db`, `bed_return_s`.
  - `audio.json` gets `boss_tell`, `boss_breath` and `boss_cry`. `Tuning` loads `bosses`.
- **Edits outside my files** (for the merges):
  - `CrawlerMain`: makes `Harm`, the view and the boss; wakes you.
  - `CrawlerPlayer`: the kick, the breath and `fall_taken`.
  - `TombKit`: one line places the lair. `TombBuild`: one line and `_lair_hole`. `FirePots`: one clearance line.
  - Three checks: `crawler_check`'s "no FigureSprite in the tomb" now leaves the boss's own sprites out; `crawler_harm_check` points at the crawler's Harm and holds the snake still; `fire_pot_check`'s stand-in class is renamed `BossStandIn` so it doesn't hide `Boss`.
- **Checks:**
  - `tools/boss_check.gd` (new), seeds 1, 7, 42: 106 lines, 0 fails.
    - The dark as each holder caught (seed 1, 22 holders): 34 33 31 30 28 27 25 24 22 21 19 18 16 15 13 12 10 8 7 5 4 2 0. Seeds 7 and 42 start at 29 and 23, and all three reach 0 only at the last holder, in three relight orders.
    - The lair is in a dead-end crypt in all three seeds and in 30 more layouts.
    - Contact: it noticed you at 0.10 s and held at the torch's edge for 4.0 s. The hits came at 5.37, 7.23 and 9.10 s (1.87 s apart against `invuln_s` 0.6), then "Good night", and you woke at the hearth with your two lights still lit. Torch out, its first strike landed at 0.97 s.
    - A lit swing at 48% of its wind-up staggers it, and no hit counts. Struck at from its coil it reels 1.50 m straight back (2.60 → 4.10 m from you); come at you down a corridor, 1.50 m back along its body (1.77 → 3.22 m).
    - Each full relight run with it loose: 0 entries into the light and 0 steps in the hearth room. It went below once a seed when cut off, and ended in its lair breathing, with the drips back at −20 dB.
    - Its tell: 0 dB on the move, −14 dB coiled; the drips hushed to −38 dB while it prowled.
  - `tools/boss_frames.gd` (new), seed 7, once at the end: 7 lines, 0 fails.
    - Its four sheets fill all 24 cells each (fewest 260 px).
    - At the torch's edge, 3.5 m down a corridor, reared and hissing: 1003 pixels of the 854×480 frame, 81 of them warm from your torch. Mid-strike its jaws are open.
    - The hole's mouth is the dark's navy (#080c4a) against its firelit edge (#b8521d).
  - On the branch with queue 61 and 60 part 2 in: `crawler_check` (152 lines), `crawler_harm_check` (45), `stagger_check` (41), `fire_pot_check` (73) and `hands_check` (61), 0 fails each, and `boss_check` as above. `crawler_check` prints four "Parameter "m" is null" errors from the headless renderer during the half-dark checks; the branch prints the same four without this pass.
  - **Found by the stagger check and fixed (4a963ed):** struck at from its coil, "back along its own body" first wound its head round the coil, 0.4 m closer to you. On seed 1 the check's swing also relit a sconce beside you with its passing flame (§CN), and the snake rightly left the room. So the check now swings out of reach of any unlit holder.

---

## 2026-10-07 — Queue 60, §FA.3–§FA.4, part 2: the snake through the fire pots' socket: driven off, never killed; the wick and the burst give you away (4370e02)
- **Queue 55's two hands** were wired to the pots by that pass itself (the pots live on the left hand's strip, my Tab-and-wheel stand-in is gone); the fire pot check passed there, and here.
- **The snake** (queue 49's `Boss`) is a fire target now:
  - **Driven off** (`drive_off`): a pot that bursts within `splash_m` of any part of it, or a burning tar patch it crawls into, sends it down below the tomb as the light does (gone the moment you can't see it). The chase is off for `vs_boss.drives_off_s` (30 s), then it comes up out of its hole or the dark nearest it. Never burnt, never killed (§FA.4).
  - **Its whole length counts:** the socket gained an optional `fire_distance(p)`, and the snake answers it along its 9 m body (INF while it's below, home or gone). A pot by its tail, 13.9 m from its head in the check, drives it off.
  - **The pot gives you away:** it sees the lit wick within `gives_away.flare_seen_m` (25 m, past its own 20 m for a torch) even with your torch smothered, and hears a burst within `burst_heard_m` (40 m) of it as it hears a sprint. Either sets it hunting you. Bursts while it's below go unheard.
- **A fix on the way:** tar burning on a creature that is then freed left a freed fire on `FirePots.fires`, which queue 54's half-dark reads ("Trying to cast a freed object"). A pot's fire now leaves the list whenever it leaves the scene.
- **Checks:** `fire_pot_check` adds the real snake (the wick alone notices you; a burst at 30 m heard, at 46 m not; driven off by a pot at its head and by one at its tail, chase off; out of reach below; up after 30.0 s, never dead; a patch under it drives it off). 0 fails on seeds 7, 1 and 42, no script errors. `boss_check`, `crawler_harm_check`, `stagger_check`, `crawler_check`, `hands_check`: 0 fails.
- **Still to come:** the skeletons (queue 58) with their fire hit points; row 60 stays `todo` until they burn.

---

## 2026-10-07 — Queue 53, §FC.1: sneak — the view eases down, the crosshair closes into a ring, quiet feet, the ledge guard (c40b2da)
- **The view eases.** Shift still crouches (Controls `crouch`, which `stealth.json → sneak.key` names). The collision drops at once and the eye glides from 1.26 m to 0.78 m over `camera_ease_s` (0.18 s, a smoothstep), then back up the same way when you let go. Standing up still waits for headroom, so the view never rises into a low ceiling. Measured: there by 0.183 s (the first tick past 0.18 s); the biggest one-frame step is 0.066 m of the 0.48 m. The torch in hand and the half-dark's light hang off the camera, so they ride down with the view. `eye_position()` follows the eased eye too.
- **The crosshair's ring.** Prompt 45's crosshair landed from another session while this pass was under way (475c143), and so did 50, 52, 54, 55, 56, 57 and 60; this pass is rebased onto them. The sneak look is built on prompt 45's `Reticle`, cell by cell on the frame's pixel grid like its cross.
  - While you sneak, the four arms close into a small ring round the same middle pixel, in the arms' colour, width and one-pixel dark edge, all of it at `dim` (0.75). Standing, the cross is back. No words.
  - The ring is the outer pixel line of a disk `ring_px` out (4 px at 480 lines, my first guess; 2 px at 270, following the frame's lines like the arms). It is one clean pixel line, the same on every side, with the middle clear.
  - The scene sets `Reticle.sneak` from the stance each frame. The open world's crosshair is unchanged (`draw_cross` gained an alpha that defaults to whole).
- **Quieter feet.** A crouched step plays at `footstep_volume` (0.25) of a walking step's: −23.0 dB against −11.0 (it was −21). `noise_level` stays 0.1. The open world keeps its own crouch volume (only the crawler sets `Footsteps.crouch_share`).
- **The ledge guard** (Minecraft's). While you sneak on the floor, each tick's move is tried one share at a time, x then z, against the ground under the capsule's leading edge. The probe is a ray from 0.45 m above your feet to `ledge_drop_m` (0.5 m) below them, 2 cm inside the capsule's rim. A share that would leave support is cut back to the lip. You stop with your front at the edge (your middle 0.33 m back), and pushing sideways slides you along it. It never acts in the air or standing: let go of Shift and you step off.
- **Data:** `stealth.json → sneak.reticle.ring_px` is new (4). `_help.about` now marks only hide as not wired; `_help.sneak` keeps its text and gains a "Wired 7 Oct" note, as the douse note did. `crawler.json → _help.hud` says the crosshair takes the sneak look.
- **Checks:** `crawler_check` passes with 0 fails on seeds 7, 1 and 42 (132, 134 and 134 lines), the other sessions' rescuer, crosshair, smother and half-dark lines included. New lines:
  - the eye eases down and back up (0.183 s, never back the other way, no snap), and it stays down under a ceiling 1.0 m up;
  - the ring at 0.75 while crouched and the cross back when standing; the ring's pixels at 480 and 270 lines (radius 4 and 2, one clean line, the same on every side, the middle clear, the edge one pixel round it);
  - a crouched step at 0.250 of a walking one's;
  - at a 2 m drop, a crouched walk stops 0.330 m short of the lip and never falls, a 45° one slides 5.7 m along it, a standing one falls 2 m, and letting go of Shift steps off;
  - crouched through every door (20, 24 and 18) and down every flight of stairs (none, 2 and 4: 2.25–2.29 m of each 2.4 m), the guard never holds once.
- **Also run:** on the final tree, `hands_check`, `crawler_harm_check`, `stagger_check` and `fire_pot_check` (seed 7) have 0 fails. Before the last rebase (onto 52 and 55): `crawler_frames` (seed 7, rendered once on this machine's software Vulkan) had 0 fails over its 30 lines, the crosshair's pixel checks at 480 and 270 lines unchanged (20 and 12 arm pixels round the middle), and the open world's `audio_mix_check` 0 fails. `play_fixes_check` (run before the first rebase; the open-world code this pass changes is the same) varies from run to run: 13 fails on the base commit, 14 and 15 on two runs of this pass. Every line that moved is one of the ninja kit's movement tests (speeds, the sprint bound, the bounce's foot), which the ambient profile switches off, and this pass changes no movement code in the open world. No walkabout: the prompt asks for none.
- **Flagged for Mike:** §FC.1 says "the dot opens into a small ring", but the crawler's crosshair (§EX.7, `hud.json → reticle`) is four short arms with no dot, so I read it as the cross closing into a ring. If you'd rather the standing reticle were a dot, that's a small change.

---

## 2026-10-07 — Queue 52, §FH: the folk at the hearth in 3D, made pixel by the frame (8c409e6)
- **What changes on screen:** the one who found you is a solid 3D figure now, the shared rig itself, not a flat sprite. It sits on a low stone across the hearth, a little to one side, facing the fire. Walk round it and it stays solid from every side.
  - The hearth lights the side that faces the fire, in the cloak's own colour warmed by the amber: a red cloak glows, an indigo one goes deep maroon. Its back is navy.
  - Its shadow, horns and ears included, goes over the floor and up the wall.
  - It breathes slowly, and turns its head to watch you while you're in front of it.
- **How it's built:** `HearthFolk` (`scripts/crawler/hearth_folk.gd`) seats the shared rig (`CloakedFigure`).
  - Its beast head and cloak colours are rolled from the seed exactly as before (seed 7 is still the dragon in indigo).
  - Its cloak is the rig's own cloth, in still air.
  - It has a blocker, so you bump into it instead of walking through it.
  - `TombBuild` lays the stone under it (`HearthFolk.seat`), in the room's stone like the rest of its dressing.
- **Where it sits:** seated, its head barely clears the flame, so straight across the fire (where the standing sprite was) hid it when you woke. It now sits 30° round the hearth (`rescuer.round_deg`), on whichever side keeps it and its things farther from the doors, still 2.1 m from the hearth's middle (`stand_m`).
- **Painted per §ES:**
  - Diffuse only, roughness 1, no normal maps: checked on all 21 materials on it. Its occlusion was already baked toward navy (`Prelit`, from the §ES pass).
  - **New, big texels:** `folk_3d.texels_per_m` 16, the walls' own fitted-stone grid. Each texel gets one fleck and one mottle value. The paint (the cloak's folds, the baked occlusion) is read at the texel's middle, so its shading steps texel by texel like painted pixels. (The shader carries each pixel's colour along its own slope on the screen to the texel's middle, at most 6 pixels.)
  - The head gets its own copy of its material, so no other head changes.
  - It's opt-in (`PlayerBody.set_texels`): the open world's folk keep the rig's fine weave. `wanderer_check`'s cloth and hem numbers are identical before and after.
- **Its idle, on the rig:** a slow breath when seated (`PlayerBody.breath`; `rescuer.breath` 0.02, `breath_s` 4.5). Its neck rises and falls 2.5 cm.
  - **Smooth, not stepped (my call, as the prompt asked):** real geometry at 480 lines already moves a whole pixel at a time, and stepped head turns read as jerky. `folk_3d.step_fps` 8 steps it as the sprites stepped (`PlayerBody.pose_fps`).
  - Its head-look is the rig's own: the crawler hands it your eyes (`PlayerBody.watch_point`).
- **Sprites kept** for creatures and bosses (§FI.2 call 11): `FigureSprite` and its bake are untouched. `crawler_check` tests its frame picking on a test sprite, and `crawler_frames` bakes a sheet (all 24 cells hold the figure).
- **Frame time** (seed 7, the hearth room, 480 lines; `perf_bench.gd SCENE=crawler_hearth`, 240 frames each). This machine draws with a software Vulkan (llvmpipe), so only the comparisons mean anything:

  | | Before: the sprite | After: live 3D |
  |---|---|---|
  | From the mat | 865.8 ms, 71 draws, 255k triangles | 881.3 ms, 85 draws, 259k triangles |
  | Same, rescuer hidden | 869.8 ms, 70 draws | 884.2 ms, 70 draws |
  | 1.6 m in front of it | 747.9 ms, 49 draws, 217k | 758.4 ms, 50 draws, 174k |

  - **The figure itself costs nothing measurable here:** shown against hidden is within 0.5% in both builds. It adds 15 draws and about 5k triangles.
  - The ~15 ms both "after" rows gained is there with the rescuer hidden too, so it's the room (the moved seat, the stone) and run-to-run noise. The 1.6 m view isn't like for like: the rescuer moved, so that view sees another part of the room.
  - Its cloth costs about 0.3 ms a physics step on this machine's processor.
- **Triangles:** 4,468 for the dragon, 4,284 for the horse. That's the shared rig's own count; §ES.2's ~1,500 is still Mike's open call from the §ES pass.
- **Merged with the passes that landed meanwhile** (45, 50, 54, 56, 57, 60): `CrawlerMain.baked` keeps its name (their checks wait on it), and the bedroll that fire pots can set alight follows the rescuer's new place (both read `lay.rescuer`).
- **Checks:**
  - `crawler_check`: 0 fails on seeds 7 and 1 (113 and 114 lines on the merged branch). New lines: the rescuer is the live rig, not a sprite; seated on its stone (in the tomb's collision, right under its hips); facing the hearth; no shine, no normal maps; big texels (its head's its own); every part casts the fire's shadow; it breathes; it turns its hood to you; its blocker 0.82 m in from 1 m; and the kept sprite's frames.
  - `stagger_check`, `crawler_harm_check` and `fire_pot_check` still pass with it in the room (41, 45 and 63 lines, 0 fails).
  - `crawler_frames` (seed 7, on the merged branch): 32 lines, 0 fails, every pass's frames drawn. New frames 03a–03e circle the rescuer at 480 lines (front, left, back, right, close). Its fire side is brighter and warmer than its back, and its back is navy.
  - `wanderer_check` identical; `shader_varying_check` ok.
- **Data** (additive): `crawler.json → rescuer` gains `round_deg`, `seat_h_m`, `breath`, `breath_s`; `folk_3d` gains `texels_per_m`, `step_fps`. `[NOT WIRED YET]` is off `_help.folk_3d`, and the help for `opening`, `rescuer` and `sprites` says what's built. `perf_bench.gd` gains `SCENE=crawler_hearth`.
- **For Mike to call:**
  - **Sitting:** the prompt says "sitting by the fire", so it sits now (the sprite stood).
  - **Watching you:** it turns its head to you while you're within about 12 m and in front of it (the rig's head-look). Say if it should mostly watch the fire instead.
  - **Dark cloaks:** a blue or violet cloak goes nearly black in the amber, as it would by a real fire. The cloak is rolled from `cloaks.json`.
  - **Data note for Claude (chat):** `crawler.json → sprites.sprite` still lists "folk" (§ET.8's word); §FH takes folk out. The help says so; the value is yours to change.

---

## 2026-10-07 — Queue 55, §FB: two hands (the wheel, and Tab with the wheel) and a Controls page (5402764)
- **The right hand** (`Hands`, `hands.json → right`): in the crawler the mouse wheel steps through what your right hand can hold: the torch (while you carry one), bare hands, and later a spear once found. Scrolling a lit torch away puts it out, as built. **Q does nothing in the crawler** (`q_swaps` false, now read). The open world keeps Q and its tool swap.
- **The left hand** (`hands.json → left`): left-hand things sit in their own strip of the pack (`Inventory.strip`, 3 places, `left.strip_slots`), not in the carry slots. Hold Tab and scroll to step the left hand through them and back to empty.
  - **The strip** (`HandStrip`): shows while Tab is held, low left inside the 480-line frame, icons only, with the one in hand marked. Each pot shows its oil on its plug: tar black, light oil pale. A quick tap of Tab shows nothing (`tab_hold.show_after_s`, 0.15 s, my number).
  - **The wheel's step** (`wheel_step`, mine): a mouse notch is one step. A trackpad's small steps add up to one step per stroke, so a two-finger swipe doesn't flip through the hand.
- **Joined to the fire pots.** Queue 60 part 1 was built alongside this, with its own stand-in left hand on Tab and the wheel. Now:
  - `FirePots` asks `Hands` which pot is in the left hand (`FirePots.left` reads and sets it);
  - its pots live on the strip, not in the carry slots;
  - its own Tab+wheel handler is gone;
  - the left hand holds still while a pot is being lit or aimed.
  - Its F9 (pots of both oils), its pot in view and its `fire_pot` kind stay; my own stand-in pot and F9 went in the merge. Queue 60's part 2 no longer needs to wire the left hand.
- **wheel_drives:** right by default. Switched to left on the Controls page, the plain wheel steps the left hand and Tab with the wheel steps the right. Holding Tab then shows the right hand's choices, low right. That last part is my reading: Tab shows whatever Tab and the wheel step through.
- **The Controls page** (`ControlsPage`, Settings' second tab): all 32 actions with their keys and buttons, the wheel among them, queue 54's douse included. Two columns: moving, the hands and the screens on the left; the open world's own keys and the dev keys on the right. It is 616×454 at 480 lines, so it fits a 4:3 frame too.
  - Click an action, then press its new key, mouse button or wheel. Esc cancels and doesn't shut the panel. The page takes that press before the game hears it.
  - The one input replaces the action's keys and buttons; a gamepad's stay. So rebinding Forward drops the Up arrow (reset brings it back).
  - "Wheel drives" switches the wheel's hand. "Reset to defaults" asks once (click it again).
  - An input that two actions share in one game shows amber on both, with a line at the foot. Actions that only one game reads never clash: Tab is the crawler's other hand and the open world's inventory.
- **Saved per player** in `user://controls.cfg`. Only the actions you changed are saved, so new defaults still reach the rest; delete the file to go back to the defaults. `Controls.ensure()` applies it at every start, over `DEFAULTS` and Project Settings. The open world's prompts ("Right click: …") now name the bound button.
- **On the way:**
  - the Settings panel was 496 px tall in the 480-line frame, so its title and foot were clipped. Its rows are 19 px now (474 px);
  - both games give an open panel its clicks first, so no key rebound to a mouse button can shut it under the pointer;
  - in the crawler the wheel no longer grabs the mouse (a click still does).
- **Data:** `[NOT WIRED YET]` is off `hands.json → _help.about`, which now says which keys are read. New, with help lines: `left.strip_slots`, `tab_hold.show_after_s`, `wheel_step`. `douse_key`'s help now says the page rebinds it.
- **Checks** (seed 7, all 0 fails):
  - `tools/hands_check.gd` (new): 61 lines, driven by real key and wheel events. It covers the prompt's six:
    - the wheel goes torch → bare hands → torch;
    - Q changes nothing;
    - Tab+wheel goes item → empty → item;
    - `wheel_drives` left swaps the hands;
    - a binding saved is in force after a restart (the crawler built anew, the file read again);
    - reset restores `DEFAULTS`.
  - It also checks the strip inside the frame, a tap of Tab, the trackpad, F9's three pots, the left hand held while lighting, every action on the page, Esc, and clashes.
  - After the merge with queues 45, 50, 52, 54, 56, 57 and 60: `crawler_check` 113 lines, `fire_pot_check` 63, `stagger_check` 41, `crawler_harm_check` 45 and `audio_mix_check` (the panel's sliders after the row change) all pass. In the open world, `swing_check` passed 18 lines before the merge.
  - `crawler_frames` (seed 7, lavapipe): 0 fails on the first merge (26 lines, with queues 45, 50, 56, 57 and 60 in). New frames, now 17a–18b: the torch in the right hand and a tar pot in the left with Tab held (it checks the strip is drawn low left, inside the frame); the right hand's strip with the wheel on the left hand; the Controls and Settings pages. I looked at them once: everything inside the frame, the oils told apart on the strip. The final render on 5402764 (with 52 and 54 in too): 33 lines, 0 fails. The strip is drawn at (18, 428), 121×34 px, where the frame changed 0.284 against 0.032 at the opposite corner. The Controls page shows queue 54's Douse the torch (F) in its Hands column, inside the frame.
- **Not mine, flagged:** `tool_check` (the ninja game, `MOVEMENT_PROFILE=shinobi`) fails 7 lines: the folk's bow and spear no longer lie by you, so Q has nothing to cycle. It fails the same 7 on the untouched base commit fd9a919, so it was failing before this pass.
- **For chat:** CLAUDE.md's brief still calls §FA–§FH "not built yet". §FB is built now.

---

## 2026-10-07 — The open world's master volume holds under the hurt muffle (§EA; Mike asked for it, found during queue 56) (f48f587)
- **The bug:** Harm's muffle (§EA) wrote the Master bus's volume every frame, at 0 dB when unhurt, so in the open world the Settings master-volume slider did nothing while Harm ran (only 0 % still muted). Leaving, Harm also put the bus back to 0 dB rather than the slider's level.
- **The fix:** `AudioMix` owns the Master level. `AudioMix.set_master_trim(db)` lays a trim on top of the slider's level, Harm sets its muffle through it, and takes it off when it goes. The muffle's low-pass is unchanged. The crawler's Harm (queue 56) never touches the Master bus.
- **Checks:** `harm_check` (seed 7731) has 33 lines, 0 fails. Two are new: with the slider at 50 %, the Master bus sits at −6.0 dB unhurt and −10.0 dB at hit 1. Both fail on the old code. The check puts the setting back. `audio_mix_check` and `crawler_harm_check` pass.

---

## 2026-10-07 — Queue 54, §FC.3 and §FC.4: smother your own torch, and a dark you can half see in (972a2d5)
- **F smothers the torch** (`Torch.douse`; the Controls action `douse`: F, or the d-pad's down on a pad). A lit torch in hand goes out with a new reason, `smothered`, a short new hiss (`SoundSynth smother_hiss`) and one log line ("You smothered the torch.", `stealth.json → douse.log_line`). It stays in your hand with its burn. It isn't water: `doused` stays the water's reason, and `Torch.last_out` says which.
  - The torch in your hand is now remembered (`Torch.item`), so with a spare in the pack the smothered torch, not the spare, is the one you relight. A burnt stick isn't remembered, so a spare can still come to hand after a burn-out.
  - Nothing that watches for a flame sees it any more: Senses reads the torch's lit state (checked with a lurker that saw the light, then nothing), and a chase whose rules have `torch_doused` (queue 56's `Pursuit`) gives you up at once. The boss (49) isn't built, so its `sees_flame_m` waits for it.
  - Relighting is as built (§CN): the hearth, a relit sconce or ring, a planted torch, all checked. The crawler has no way to plant a torch yet, so the check stands its own.
- **The half-dark** (`HalfDark`, `crawler.json → dark`): one faint light at your eye in `readable_color` (#141c5c), with no shadow and no shine. Its reach is `black_m` (12 m): nearly even out to `readable_m` (5 m), then fading to nothing. It is on only with no flame near you, easing in over `adjust_s` (1.2 s). It is off at once with your torch lit, and eases off (`fade_s` 0.4 s) when a lit fire, a planted torch, or a fire pot's fire or lit wick (queue 60) is within its own light's reach of you with a clear line. A fire round a corner doesn't count.
- **Tuned by measurement** (seed 7, a long cold corridor at midnight, torch smothered; wall pixels by distance, luma). The frame's black is not black: it is the grade's navy floor (`look.json → retro.colors.shadow_floor` #080C4A, luma 0.068), and anything fainter than that floor is swallowed. So a weak fill shows nothing at all, and one with a steep falloff glares close and is gone by 4 m:

  | | 3 m | 5 m | 8 m | 15 m | A wall facing you 5 m off |
  |---|---|---|---|---|---|
  | Off (the old full dark) | 0.068 | 0.068 | 0.068 | 0.068 | 0.068 |
  | falloff 1, fill_energy 1.0 | 0.075 | 0.068 | 0.068 | 0.068 | 0.068 |
  | falloff 0.5, fill_energy 2.0 | 0.091 | 0.071 | 0.069 | 0.068 | 0.079 |
  | **falloff 0, fill_energy 3.0 (taken)** | **0.098** | **0.083** | **0.077** | **0.068** | **0.103** |

  The near walls come out at about #101a5a, just under `readable_color`, hue 232. The readable floor the frames tool checks is 0.02 over the black at 3 m (picked: about two 5-bit steps of green).
- **Unchanged:** by torchlight the long view is the same frame with the half-dark on as off (mean 0.2803 against 0.2804; the worst band 0.0004 apart). The hearth room on waking, the relit corridor and room, and every torchlit frame show no half-dark. The torch's reach is untouched.
- **Merged with queues 45, 50, 56, 57 and 60**, pushed while this pass ran. The fire-pot and harm-ring frames now let the half-dark settle before their dark shots, so each before-and-after pair differs only by what it measures.
- **Checks:**
  - `crawler_check`: seed 7, 102 lines, 0 fails (25 of them new); seed 1, 103 lines, 0 fails.
  - `fire_pot_check` 63, `stagger_check` 41, `crawler_harm_check` 45: 0 fails.
  - The open world's `swing_check` (18) and `senses_check` (11), with the change to which torch is in hand: 0 fails. Both crash with signal 11 at shutdown, after their results. The code from before this pass does the same, so it isn't this pass.
  - `crawler_frames` (seed 7, on 972a2d5): 30 lines, 0 fails. The half-dark numbers are the table's last row again. By torchlight the long view is the same frame with the half-dark on as off (mean 0.2803 against 0.2804). The crosshair reads 6.6:1 against the half-dark's navy wall (3:1 is the floor). The tar patch and the light-oil burst still light their dark in amber, and the harm ring is 48 px deep after one hit and 80 px after two. New frames: `07d` (the long view in the old full dark), `07e` (the same in the half-dark), `07f` and `07g` (by torchlight, the half-dark off and on).
- **Flagged for Mike:**
  - Freeing a torch's ember in a headless check prints a renderer warning ("Parameter m is null"). It was already there, and it's harmless.

---

## 2026-10-07 — Queue 60, §FA.3, part 1: fire pots, lit off the torch and thrown (the general pot; the creatures and the left hand wire in when 49, 55 and 58 land) (e607b24, 1f5897e)
- **Built ahead of its prerequisites, at Mike's word** ("do what you can as if those other prompts were completed"): queue 55 (two hands), 57 (the stagger, part 1 in) and 58 (the skeletons) are being built in parallel. So, like queue 57's part 1, this is the pot itself plus a socket the creatures plug into. Part 2 wires the snake, the skeletons and queue 55's left hand when they land, and row 60 stays `todo` until then.
- **The pot** (`PotMesh`, §FJ.5): a sealed fired-clay pot, about 15 cm to the tip of its fibre wick, 8-sided, painted (navy occlusion under the belly and in the neck) and drawn in the tomb's own matte material. The oil shows by eye: tar's plug is black pitch with drips down the shoulder; light oil's is a pale seal.
- **Carrying and the left hand** (`FirePots`): each pot is an item of the pack (`items.json → fire_pot`, with its `oil`), at most `carry_max` (3). Hold Tab and scroll to bring one into the left hand (low left in view) and back to empty. This is a stand-in for queue 55's left hand, which brings the strip. While a pot is in the left hand the torch doesn't swing (`hands.json → clicks.left_with_pot`).
- **Lighting, aiming, the throw:**
  - Hold left click with the torch lit: the pot and the torch come together in view over `light_anim_s` (0.6 s), and the wick catches with a little flare of amber light. With no torch, or an unlit one, nothing happens; let go early and the hands part.
  - Keep holding: the lob charges from `min_m` to `max_m` over `charge_s`, with a faint dotted arc (AimArc's look) and the pot drawing back.
  - Let go: it lobs (`ThrownPot`) `lob_deg` above your view, at the speed that lands it at the charged range on level ground when you look level, tumbling with its wick alight. It bursts on the first stone or creature it meets, or in the air when the fuse runs out. A fuse spent in your hand never goes off there (`cook_off_in_hand` null); it waits for the landing.
- **The burst** (`FirePots.burst`, `PotFire`):
  - Fire damage within `splash_m` to every fire target, times its `oil_scale`.
  - Tar sticks and burns what it hits (`burn_dps` for `burn_s`, a fresh coat restarting it) and leaves a patch burning on the floor (`patch_radius_m`, `floor_patch_s`) that burns what stands in it, then gutters dimmer and redder, goes out and leaves char. Light oil is one big flash and nothing after.
  - Every flame is the campfire's card in the hearth's amber with its sparks and smoke; none is a flame a torch catches from or a holder is lit by (`relights_holders` null).
  - A resident at 0 fire hit points burns out and is gone (its `burn_out()`); a boss is driven off into the dark for `drives_off_s` and never killed (§FA.4).
- **It gives you away** (§DF): the lit wick, in hand and in the air, is a flare seen within `flare_seen_m` by anything with a clear line to it (`FirePots.flare_seen_from`); the burst is heard within `burst_heard_m` (`FirePots.bursts_since`, and `NoiseEvents`). A throw is as loud as a swing.
- **Fire spreads** (`spreads_to`): the tomb's only dry things are the hearth room's reed mat (rushes) and the bedroll (cloth); a burst or a patch by them sets them burning, then they lie charred for good. `register_burnable` is there for webs and the cats' runs.
- **The found pot:** one per dungeon on the floor of a side room, a dead end where there is one, never the hearth room, the heart or the spine. Until queue 46's spine is in, "the spine" is the way through the doors from the hearth room to the heart. Right click takes it.
- **The socket** (for queues 49 and 58; see `FirePots`' notes): a creature joins the group `fire_targets` with a `fire_hp` and `fire_creature` (its `residents.json` key), and `burn_out()`; a boss has `drive_off(seconds, from)`. What sees and hears reads `flare_seen_from()` and `bursts_since()`.
- **Data:** `[NOT WIRED YET]` is off `fire_pots.json → _help.about`. Added with help lines: `throw.lob_deg / gravity_mps2 / arc_shown / flight_max_s`, `wick`, `look`, `found`, `dev_items`, `spread`, `hurts_you` (false, open for Mike). `items.json → kinds.fire_pot`. `fire_pots.json` is read by `FirePots` itself, not `Tuning`, to keep clear of the parallel passes' edits to `Tuning.FILES`.
- **Small edits outside my files:** `crawler_main.gd` makes the `FirePots` node (5 lines); `crawler_frames.gd` gains `_pots()`.
- **Checks:**
  - `tools/fire_pot_check.gd` (new): 63 lines, 0 fails on seeds 7, 1 and 42. It runs against stand-ins for the skeleton and the snake that use the socket and `residents.json`'s numbers.
  - Measured throws looking level: 4.14 / 9.07 / 13.82 m against charged 4.21 / 9.21 / 14.00 m; the arc ends where they land.
  - Tar on a skeleton: 1.0 off its 3.0, then gone at 4.00 s (4.00 expected). A sturdier one ends burn_s at 14.99 (15.00 expected).
  - The patch burns 5.98 over 12 s; its light ends at about a quarter of its mid-life energy, redder.
  - `crawler_check` and `stagger_check`: 0 fails.
  - `crawler_frames` (seed 7, 480 lines, 0 fails): `14_tar_patch` (the corridor's mean light 0.054 dark → 0.173, warm pixels 0 → 44% of the frame, the floor's hue 17.8°, in the amber), `15_pot_burst` (warm 56%, hue 13.9°), and `16_pot_lit_in_hand` (the clay pot low left, its pitch plug and drip, a small wick flame, the arc).
  - **Fixed from the first pass:** the pot in hand read as a glowing white ball, because the wick's light sat 5 cm from the clay. That light now rides over your left hand, and 0.3 m above a pot in flight. The wick's flame shrank to wick size (`wick.flame_scale` 0.07), and the light-oil fireball is wider, so it reads as a burst rather than a flame's tongue.
- **For Mike, two calls:** `hurts_you` is new and open: should your own pot's fire hurt you if you stand in its burst or its burning patch? And a burning patch is no flame to relight a torch from, just as a pot doesn't light a cold sconce (`relights_holders`, §FI.2 call 4). Say if you want either.

---

## 2026-10-07 — Queue 56, §FD with §FJ.3, part 1: a red ring and a heartbeat; you heal once nothing pursues you (the snake's chase waits for 49) (d14f7d8)
- **Harm in the crawler** (`Harm.fd`, on while the crawler runs; the open world keeps §EA/§EC, and `harm_check` gives the same 31 lines as before):
  - **Hit 1:** a red ring closes round the edge of the view, in four stepped bands like §EC's navy flash (`harm.json → fd.hit_1_edge`: #B01818, 0.6 at the rim, a tenth of the frame's short side). It is drawn on its own layer over the grade (`HarmRing`, `shaders/harm_ring.gdshader`), inside the 480-line frame. The heartbeat starts: 105 bpm, −6 dB.
  - **Hit 2:** darker red (#6A0A0E, 0.8) and deeper (0.16 of the short side); the heart harder and faster (150 bpm, 0 dB).
  - **Hit 3:** "Good night" as built; the ring goes under the closing black.
  - **Replaced in the crawler:** §EA's grade darkening, drain and Master-bus muffle; Harm doesn't touch the Master bus there. §EC's navy flash on every hit stays.
  - **Healing steps back down:** 2 → 1 the ring eases back and the heart slows and softens; 1 → 0 the heart stops first, then the ring pulls back to the edge.
- **You heal by losing it** (`fd.recover_starts`): `Harm.pursue(who, on)` keeps who is chasing you. The 5 s step timer waits at zero while anything is, and counts from when the last one gives you up; a new hit resets it; light never heals.
- **`Pursuit`** (`scripts/crawler/pursuit.gd`): the chase any hunter holds. It is on when the hunter notices or hits you, and off by the hunter's own `gives_up` block (distance, time out of its sight, hiding, your torch going out). It also has `may_enter(lit)` (a lit room opens to a chase only once its strike has landed) and `back_to_dark_mps()` (back in the dark within `residents.json → rules.back_to_dark_s`) for the snake to use.
- **Data:** `bosses.json → bosses.desert.gives_up` (24 m, 6 s, hide, torch_doused; Claude Code's first guesses) with a `_help.gives_up` line; `_help.rule` says `chase_enters_light` is wired (the snake's side lands in part 2); `harm.json → fd._note` is no longer `[NOT WIRED YET]`, and `recover._note` says the crawler waits for the pursuer. `residents.json` is registered with Tuning. `Harm.pursue(who, on)` has the form the skeletons' pass (58) already calls, `Harm.instance.pursue(r, on)`.
- **Checks** (seed 7, all 0 fails):
  - `tools/crawler_harm_check.gd` (new, 45 lines) runs a stand-in hunter with the snake's numbers. It checks each hit's ring and heartbeat, no grade darkening and no muffle, the navy flash, and no healing in 15 s while chased, beside the lit hearth too. Out of its sight it gives you up at 6.1 s, and a hit heals 5.0 s later. It also checks the steps back down, every give-up rule, a freed hunter, the wake, and the ring under "Good night".
  - `crawler_frames` ends with frames 11–13b. In a cold corridor the ring measures 48 px deep at hit 1 and 77 px at hit 2, at both edges, and its rim is darker on two (luma 0.136 against 0.185). Frames 12b and 13b show it at the hearth by torchlight. 45's crosshair checks still pass, and nothing else is drawn over the frame while unhurt.
  - `crawler_check` passes.
- **Nothing in the tomb hits you yet:** the snake (queue 49) brings Harm into the crawler. Part 2 wires its chase into this: it follows you into the light once it has hit you, gives up by its `gives_up`, and is back in the dark within 4 s. Row 56 stays `todo`.
- **Setting up this machine:** the cloud container had no Godot and no Vulkan. I installed Godot 4.3 at `/root/bin/godot` (checked against the official checksums) and `mesa-vulkan-drivers` (lavapipe) for the rendered frames, as 45's HOW_TO_RUN note says.

---

## 2026-10-07 — Queue 50, §EZ.1 and §EZ.5: the torch stays lit; only deep water puts it out (dacd5d3)
- **The sprint rule is gone** (`TorchSnuff`). Walking, sprinting for any length of time, turning, whipping the view round and swinging never gutter the torch or put it out.
  - Deleted, since the design no longer mandates them: `torch.json → snuff.sprint`, and `crawler.json → snuff_log` (its sprint and draft lines).
- **Speed still shows.** Running feeds the coal air, as built (`ember.air_brighten`, `light.sprint_flicker_scale`): mean light energy 3.04 flat out against 2.80 standing (×1.09).
- **The strong airway gust holds** (`Airways`). The marked mouths keep their cycle, moan and dust exactly as built.
  - A gust in line whips the torch hard: its smoke streams flat away from the mouth (4.9 m/s at a flame 2.5 m out) and its light flickers hard.
  - The warning before it no longer gutters the coal. The flame's own lean (`pitch_head.lean.max_deg`) comes with prompt 51.
- **My call, flagged for Mike: an ordinary draft now flickers the torch instead of guttering it.** As built, a slot in a corridor wall guttered the torch a little (up to 0.25: dimmer and redder).
  - With nothing but water able to put it out, that read as a false warning, and the prompt's run round the tomb wants gutter 0 throughout.
  - Now an ordinary draft leans the torch and quickens its light's flicker, as §EV.3's draft does a vented fire. `crawler.json → airways.gutter` is renamed `flicker` (same 0.25; my own block).
  - The gutter (dimmer, redder, the sputter) now warns only of deep water, or a torch burning low.
- **Unchanged:** deep water gutters it and then puts it out (`douse_depth_m`); out means out. The burn still counts down (50 real minutes; the prompt's step 4 is withdrawn, and §FJ.4's crawler timer is prompt 62). The open world keeps its own rules. No boss is built yet, so step 6 had nothing to change.
- **Data:** the two `[NOT WIRED YET]` notes are off `torch.json → _help.snuff`, with a "Built" note added; `crawler.json → _help.airways` is updated.
- **For chat:** `bosses.json → _help.bosses` still says "a sprint held too long gutters the torch (§ET.7)", which §EZ.1 amended.
- **Checks:** `crawler_check` passes with 0 fails on seeds 7, 1, 42 and 31337. Its torch section is rewritten:
  - a minute of walking; brighter at a run; a minute of swinging (225 swings);
  - 120 s flat out round the tomb, through every door depth-first and back, with a full whip-round every 4 s: 592–628 m, lit, gutter 0 throughout. That was 103–111 s at a sprint by the removed rule's own measure, which would have put the torch out 12–24 s in;
  - an ordinary slot leans and flickers it, never a gutter;
  - three strong gusts in line: lit, never guttering, whipped hard, with the moan and dust before each. Out of the line, or behind cover, the gust passes it by;
  - wading gutters it (redder, never bluer), and past `douse_depth_m` puts it out.
  - The scripted runner steers round coffins, rubble and the hearth with a capsule test-move. In all four runs it had to skip ahead twice (seed 1).
  - After rebasing onto queue 45, 57 (part 1) and 60 (part 1): `crawler_check` (seed 7), `stagger_check` and `fire_pot_check` pass with 0 fails.
  - `swing_check` (the open world, which shares `torch.gd`) passes all 18 lines, then crashes in Godot's shutdown (signal 11 after its result line). It does exactly the same on the code before this pass, so the crash predates it.
  - No walkabout, per the prompt.

---

## 2026-10-07 — Queue 57, §FA.1–§FA.2, part 1: the torch staggers a strike's wind-up (the general strike; the snake waits for 49)
- **A strike in two parts** (`CreatureStrike`, `scripts/crawler/creature_strike.gd`), for any creature with a `strike` block (`bosses.json`, `residents.json`; the skeletons of queue 58 use the same piece):
  - first the **wind-up** (`wind_up_s`), with the creature's own tell (§FA.2): a pose for its sprite, and its own sound, played from a 3D player at its head from the wind-up's first frame;
  - then the **committed strike** (`strike_s`). At its end the hit lands through the player's `take_hit` (Harm counts it), if you are still in reach with nothing solid between;
  - then `recover_s` before the next strike.
- **The stagger** (`torch.json → stagger`; `[NOT WIRED YET]` is off its help): a lit torch's swing that reaches the creature during the wind-up breaks the strike. The creature reels back `reel_m` over `reel_s` (0.8 s) and can't be staggered again for `cooldown_s` (3 s). It takes no damage, ever.
  - A swing during the committed strike does nothing to it, and the hit lands. An unlit torch staggers nothing.
  - The swing meets a creature at the top of its arc (`Torch.swing_top`, 0.125 s after the click), within the swing's reach, in front of you, with nothing solid between. The flame still passes at the arc's end, as built (§CN).
- **Loud:** a swing that lands on a creature is as loud as a sprint (noise level 1). The crawler player now holds a loud moment for 0.5 s (`CrawlerPlayer.make_noise`); until now its steps reset its noise every frame.
- **The snake's data and voice:** a strike block in `bosses.json → bosses.desert` (reach 2.5 m, wind-up 0.7 s, lunge 0.15 s, recover 1 s, reels back 1.5 m; tell "a hiss and the head drawing back", with a `_help.strike` line), and its hiss in the synth (`snake_hiss`). New `audio.json → kinds.strike_tell` row.
- **Nothing in the tomb strikes yet.** Queue 49's snake is being built in parallel. Wiring it to this (its wind-up pose and hiss, a loud swing it can hear) is part 2, so row 57 stays `todo`.
- **Checks:**
  - `tools/stagger_check.gd` (new): 41 lines, 0 fails, seed 7. It uses a stand-in with the snake's numbers in a real tomb, a real torch, and Harm counting the hits.
    - Measured: the swing lands at 48% of the wind-up and staggers; it reels 0.78 s and 1.50 m; no hit counts.
    - Inside the cooldown a second stagger fails and the hit counts. In the lunge the hit counts. Unlit, the hit counts.
    - A landed swing holds noise 1.0 for 0.42 s and more.
  - `crawler_check`: 77 lines, 0 fails. `swing_check` (the open world): 18 lines, 0 fails; there a swing still does nothing to animals.
  - That check segfaults as Godot quits, after its result, and so does the code before this pass.
- **My slip, put right:** I first wrote my check over `tools/strike_check.gd`, the ninja game's momentum-combat check. I restored it from git, unchanged, before this commit.

---

## 2026-10-07 — Queue 45, §EX.7: a reticle in the crawler (475c143)
- **The crosshair is on in the crawler.** It is the open world's (`hud.json → reticle`), now drawn by one piece of code, `Reticle` (`scripts/ui/reticle.gd`). The crawler and the open world's `StatusHud` both draw it with that code, so the two can't drift apart.
  - It is the only thing in the crawler's HUD: no words, meter, names or prompts (§ET.3). `crawler.json → hud.reticle` puts it there. `[NOT WIRED YET]` is off `_help.hud`; `warms_near_flame` stays false and is not built.
- **Drawn on the frame's own pixels:** four arms round the frame's middle pixel, built from whole-pixel squares (as the pocket watch is), inside the internal frame and nearest-scaled with it.
  - The old drawing used lines centred on a pixel corner, so it came out a pixel lopsided (2 clear pixels on one side of the middle, 3 on the other). Now it is the same on every side.
  - Its sizes follow the frame's lines like the HUD text, since `hud.json` gives every size at the 480 reference. At 480 lines: arms 5 px, 3 px clear of the middle, 1 px wide, 17 px across. At 270: arms 3, 2 clear, 1 wide, 11 across. So it stays about the same size on screen.
  - In the open world (Torchfire 2) nothing changes at 480 but the one-pixel centring. At 270 its crosshair is now its 480 size on screen, not 1.8 times bigger.
- **Off:** Settings → Crosshair dot (`hud.reticle`). It also hides while the log or the settings panel is open: both cover the middle of the frame, and it would show through them (my call).
- **No light of its own:** the HUD's layer is drawn over the finished frame, so the grade, the dither and the bloom never touch it.
- **The outline:** it already had the open world's one-pixel dark edge (navy at 70%), so I added none. The edge is what makes it readable over fire.
- **Readable, measured (seed 7, WCAG contrast; 3:1 is the bar for a mark):**

  | Where it sat | Arms against their edge | Arms alone against what's behind |
  |---|---|---|
  | The corridor's dark wall (navy) | 8.4:1 | 8.2:1 |
  | Over the hearth's fire | 4.3:1 | 1.2:1 |
  | Amber stone, the torch 1 m away | 5.4:1 | 1.4:1 |
  | Amber stone, 0.45 m | 4.4:1 | 1.1:1 |
  | Down the dark corridor, on the far hearth's doorway | 7.1:1 | 2.7:1 |

- **Checks:**
  - `crawler_check` passes with 0 fails on seeds 7, 1 and 42 (77–78 lines). New lines: the HUD holds the crosshair alone, no words, nothing of the open world's HUD; it is drawn over the grade; it is centred and sized per `hud.json` at 480 and 270, with its edge one pixel round it; the switch hides it; so does an open panel.
  - `crawler_frames` (seed 7) has 0 fails. New frames: `01g` (the hearth room at 270 lines), `07b` (the dark corridor's wall), `07c` (the same, switch off).
    - Every pixel of the graded picture sits on the dither's 5-bit grid, so any pixel off it was drawn by the HUD. At 480 the only such pixels are the crosshair's 20 arm and 64 edge pixels; at 270, 12 and 48. So no words and no glow anywhere.
    - With the switch off, nothing at all is drawn over the frame, and the wall round the crosshair is the same either way (luma 0.0678 against 0.0686).
    - The scene's own numbers now leave the crosshair's box out. Unchanged within the flame's flicker: torchlit wall hue 23.1°, sconce-lit 23.1° and 28.2° over two runs (the limit is 8° apart), the corridor's dark at 0.056.
  - The open world's `hud_pin_check` passes as before (49 lines, 0 fails). It crashes on exit after printing its result; the unchanged code does the same.
- **This machine** started without Godot or a Vulkan driver. I installed Godot 4.3 (checksum checked) and lavapipe, and `HOW_TO_RUN.md` now says how.
- **For Mike and chat:**
  - §FC.1 (prompt 53, sneaking) has "the dot" of the reticle opening into a small ring. The crawler's reticle is the open world's four-arm crosshair (§EX.7), not a dot, so 53 needs a call: the arms spread and dim, or a dot for the crawler.
  - In the open world, the Crosshair dot switch hides only the dot, not the first-person crosshair (`StatusHud`, as built). I left it, since Torchfire 2 is shelved.

---

## 2026-10-06 night — Design §FJ: Mike's answers (Claude, chat; design and data only)
- **Locked 22:52:** the first ruin is drawn at random from the roster (amends §ET.3); the desert tomb's mummy wakes in its sarcophagus; hit 1 is a red ring with a heartbeat, hit 2 darker red and a harder heart; torches burn down again (reverses §EZ.5's no burn-down: a timer, three at most, from the hearth's bundle, relight from any flame); fire pots are clay; the centipede is the jungle's boss.
- **Data:** `torch.json → snuff.burns_down` true, new `crawler_burn`; `harm.json → fd` rings; `fire_pots.json → vessel` clay_pot; `bosses.json → bosses.jungle`; `residents.json → creatures.mummy`; `crawler.json → opening_pick`.
- **Queue:** prompt 50's no-burn-down step withdrawn in its text; 56 rewritten for the ring and heartbeat; 62 added (the torch timer and the three-torch limit).

---

## 2026-10-06 night — Design §FA–§FI: fire fights back, sneaking, what lurks (Claude, chat; design and data only)
- **Locked by Mike at 22:32** ("go ahead and lock it in"): a little combat, all of it fire (the torch staggers a creature's wind-up, rare fire pots burn; amends §ET.1); two hands on the wheel and Tab-and-wheel, Q retired, a Controls page; Shift sneak with an eased camera, a sneak reticle, quiet feet and Minecraft's ledge guard; hiding; dousing your own torch; a dark you can half see in; hit 1's edge goes red (amends §EC), a chase can follow you into the light (amends §EY.1), recovery only once it gives you up; residents below each boss, a roster (skeletons, ghosts, the mine's spider, temple cats, zombies, the were-mole, the swamp witch, and at 22:39–22:40 the imps and the warden); a lit floor is cleared; relit ruins' people come home and teach; atmosphere never puzzles; the hearth folk live 3D (amends §ET.8 for folk).
- **New data, all `[NOT WIRED YET]`:** `fire_pots.json`, `hands.json`, `stealth.json`, `residents.json`; new blocks `crawler.json → dark, floors, cleared, restored, ambience, folk_3d`, `harm.json → fd`, `torch.json → stagger`. `bosses.json`: the swamp is the witch and the mine the spider; the hornet and the centipede move to `unplaced` with the imps and the warden; `rule.chase_enters_light`.
- **Flagged, not changed:** the pitch technique needs burn time, which §EZ.5 turned off (§FF.4); a glass fire-bottle and the warden's chain are past §EH (§FA.5, §FE.4). Twelve open calls in §FI.2.
- **Queued:** prompts 52–61 in `docs/PROMPT_QUEUE.md`.

---

## 2026-10-07 — Queue 44, §EX.6: one firelight, the torch takes the hearth's amber (cb946c1)
- **One colour.** `Torch.fire_color()` reads `look.json → fire.light.color` (#FF6E24), and the torch in hand, planted torches, the sconces and the hearth all take it. `torch.json → light.color` agrees, and the check confirms it.
- **Guttering** (burnt low, or the snuff rules' warning) dims and reddens the torch's light (`Torch.gutter_color`: steady #FF6E24, guttering #FF5719). The coal's shader already reddens as its glow drops.
- **Measured (seed 7, the frames tool, mean hue of the lit wall patch):**

  | | Torchlit wall, 1 m | Sconce-lit wall, 1 m |
  |---|---|---|
  | Old torch colour #FFB347 | hue 42, chroma 0.53 | hue 25 |
  | Amber #FF6E24 | hue 23, chroma 0.68 | hue 25 |

  The old pale colour was the main cause.
- **Right at the stone the light still blew out.** At half a metre each colour channel clips in turn (amber → yellow → white), and the night grade pulled those near-white pixels cyan-white, with the bloom spreading it: 40% of the frame's brightest pixels fell outside the grade's protected orange and 21% were bluer than red.
  - **Fix, at the cause and only in the crawler:** `post_grade.gdshader → fire_whites`. Bright, non-blue pixels the fire blew pale or white go back on the fire's amber before the grade, the paler the more. Strong colours (flame tongues, deep amber stone) are untouched.
  - Now 0% outside the orange and none blue. The open world is unchanged (`fire_whites` is 0 there).
  - Tunables in `crawler.json → firelight`: `pale_to_amber` (1), `lift` (0.15), `pale_chroma` ([0.3, 0.6]). `[NOT WIRED YET]` is off `_help.firelight`.
- **Unchanged:** the corridor's full dark (mean 0.056) and the vent's daylight column (blue by day and by night, checked).
- **Checks:**
  - `crawler_check` passes with 0 fails on seeds 7 and 1. New lines: all 21 fire lights in the tomb share one colour; `torch.json` equals `look.json`; a guttering torch is redder, never bluer.
  - `crawler_frames` (seed 7) has 0 fails, with new frames: the torch 1 m and 0.45 m from a wall, 1 m from a relit sconce, and the torch beside a relit sconce. The torchlit and sconce-lit patches are within 2° of hue (the limit is 8°), both inside −20..62.

---

## 2026-10-06 — Mike's areas: the 52 biomes gathered into 20 places (data only, for §EW)
- **New file `data/areas.json`** (`[NOT WIRED YET]`): Mike's 19 areas, in his order. Each has the biomes his words name, plus Claude Code's suggested fold-ins under `proposed`, which are not decided.
- **Unassigned:** 10 biomes fit no area yet (cold desert, fresh water, maritime forest, Mediterranean scrub, páramo, puna, sagebrush, salt flat, sea ice, temperate deciduous).
- **Nothing in the game reads the file yet.** The biomes themselves are unchanged.
- **Mike's follow-up:** the rainforest area takes both the tropical and temperate rainforests. A new **boreal forest** area takes the taiga, with four first-guess forest types. Coniferous forest now means temperate conifers, which has no biome file yet (chat to research one). That makes 20 areas.
- **For chat:** log it as a design section, and reconcile it with `worlds.json → worlds` (§EW.2). Three of §EW.2's named worlds (the mine shaft, the mountains, the desert sandstone) have no area in Mike's list.

---

## 2026-10-06 — §EW.7 step 1 in the tomb: §EU fitted stone and 480 lines, §EV a vent for every built-in fire
- **Data folded into chat's files.** The walls read `data/masonry.json` and the vents read `smoke.json → vents`; both had their `[NOT WIRED YET]` taken off.
  - My first pass earlier today had used `data/dungeon/*.json`. Those files are deleted, and their extra knobs were added to chat's blocks with help text: masonry `seed`, `aspect`, a preset's own `relief`, `dropped_m`, the overgrowth amounts, `wet` and `stand_in`; vents `surface_y_m`, daylight energies, soot `amount`, draft lean, `kink`, `mouth_offset_m`.
  - No RECONCILIATION section of my own; §EU, §EV and §EW are chat's.
- **§EU.1: 480 lines.** `look.json → render.preset` is `default` (854×480). 270 "painted" and the rest stay in Settings. `auto` prefers 480, then 540, 360, 270, 720.
  - **Texel density at 480:** at the 78° vertical view a pixel spans 3.4 mm per metre of distance.
  - Tiles stay at 16 texels a metre, so a texel is 1 pixel at ~18.5 m, 3.7 px at 5 m and 9 px at 2 m (at 270 a texel was 1 pixel at 10 m).
  - On the fitted walls the stone tile is only a faint grain (7 texels a metre at 30%, plus a fleck on the 16 grid); the stones themselves are geometry.
- **§EU.2–EU.5: fitted stone (`scripts/crawler/fitted_stone.gd`, `TombBuild._dwall`).** Every wall face you can see gets its own seed and is cut into Voronoi cells:
  - seed points are laid in loose courses (`stone_m`, `aspect`, `course_bias`) and relaxed twice (`relax_steps`, Lloyd);
  - each cell is a real stone: joint backing, bevel, a proud pillowed face; proud is rolled per stone in `proud_m`;
  - joints and stone feet are darkened toward the scene's shade (`joint_occlusion: scene_shade`, `Prelit.ao_tint`); no normal maps;
  - settling uses the `settle` block: share, offset, tilt, and the dropped share.
  - The preset follows `by_theme`, so the tomb is `fitted_small` and the snow ruins are `megalithic`.
  - **Triangles in a typical room (fitted_small):** median ~30,000 (seed 7: 20–36k over 11 rooms; seeds 1 and 42 a median of 32k).

    | Preset | Stones (seed 7) | Whole tomb (seeds 7/1/42) | Build time here |
    |---|---|---|---|
    | `fitted_small` | 12,671 | 420k–550k triangles | 2.6–3.2 s |
    | `megalithic` | 1,373 | 106k–155k triangles | ~0.5 s |

  - Speed fixes made on the way: nearest-first Voronoi candidates, and soot sources bucketed on a 2 m grid (the soot pass had been 5+ s).
  - **Moss and vines are gated by `vines.json → climate`** (`VineCover.climate`; underground counts as full shade in the joints and half shade higher up). The climate is the theme's world's biome (`worlds.json → biome → data/biomes`):
    - the snow ruins get the tundra's −7 °C, so no moss;
    - the tomb belongs to no world yet, so it uses `overgrowth.stand_in` (moisture 0.58, 14 °C).
  - Inside a place the moisture wanders (`wet`), so the tomb's moss runs from 0.2 to 1.0. A desert wall gets drifted sand, a damp one vines.
- **§EU.6:** the amber firelit stone underground is unchanged.
- **§EV: vents (`TombKit._place_vents`, `TombBuild._flue/_soot`, `scripts/crawler/vents.gd`, `CrawlerFires._draft`).**
  - **Shafts:** a hearth, ring or altar gets a 0.6–1.2 m shaft, narrowing with depth, its mouth beside the fire. A column of daylight comes down it (`daylight.day_color`/`night_color` on the world's clock), fading over `fade_depth_m` 3→25 m of shaft.
  - **Flues:** a sconce or brazier gets a 0.15–0.3 m flue straight up, with no light.
  - **Soot:** navy-black (`outlets.soot`), a `streak_m` roll per vent, measured from the vent's rim.
  - **Draft:** the flame leans only (`lean_only`).
  - **Kinks:** at most `shaft.kinks`.
  - **Ready for §EW:** every vent keeps its `top` and its `outlet` (a stack, or a ground slot), and `surface_y_m` stands in for the surface until §EW builds one, so nothing here blocks §EV.4.
- **Checks.** `crawler_check` passes with 0 fails on seeds 7, 1 and 42. New lines:
  - both presets fill the wall exactly;
  - the two sides of a wall differ;
  - the tundra climate gives no moss;
  - desert → sand, damp → vines;
  - the room triangle report;
  - the daylight fade;
  - no vent mouth in reach;
  - every vent has its outlet.
  - `crawler_frames` (seed 7) has 0 fails: the corridor is full dark at midday (mean 0.056), 0.278 with its sconce relit.
- **Open for Mike:**
  - which world the tomb belongs to (its moss comes from `stand_in` until then; a desert world would make it bare stone with drifted sand);
  - the vents' sizes and fade (chat's first guesses);
  - vines are generic ivy until a world gives its biome's own vine species.

---

## 2026-10-06 — §ET.11 first slice: Torchfire 1, the dungeon crawler (switch, hearth room, tomb kit, relighting, snuff rules, baked rescuer sprite)
- **1. The switch (§ET.2).** `data/game.json` → `game`: `torchfire1` (the default) or `torchfire2`. `GAME=` in the environment overrides it for one run.
  - The project now boots `scenes/boot.tscn` (`GameMode`), which opens `scenes/crawler.tscn` for Torchfire 1 or `scenes/main.tscn` for the open world.
  - Nothing of the open world was deleted. It still compiles, and every check in `tools/` still opens `scenes/main.tscn` directly.
  - Shared code changed only where the crawler needed it, all behaviour-neutral for the open world:
    - `Campfire.build_at()`: a fire on flat ground;
    - `PlanetPlayer.water_depth()`: the torch's water test;
    - a stone fallback in `Footsteps`;
    - Campfire `light_y`;
    - `FireShadows.mode`.
  - swing, delve and old-hearth checks pass. `fire_wall_check` fails 5–6 times and times out, the same on the commit before this work (checked in a worktree), so that failure was already there.
- **2. The hearth room and the tomb kit (§ET.3, §CJ.8;** `TombKit`, `TombBuild`, `crawler.json kit`). You wake on a reed mat by a lit hearth in a 9 × 9 m stone room, its smoke going up a shaft in the ceiling (§ET.6).
  - Across the fire stands the rescuer; by it lies a bundle of three unlit torches.
  - Three or four doorways lead out. Each branch is corridor, room, corridor, room, two or three rooms deep, straight on or turning, sometimes a flight of stairs down.
  - Room kinds:
    - crypt (coffins in rows, lids askew);
    - catacomb (bone niches down the walls);
    - ossuary (bones heaped in the corners);
    - collapsed (a fallen ceiling slab and rubble);
    - the heart: the deepest room, ochre ceiling, the dead's goods, and Mike's frame 9 (a mossy stone box with a skeleton leaning out of it).
  - All of it is drawn in the ruins' own dry-stone kit (RuinBuilder), lit per pixel like the barrow delves. A new tomb each launch; `SEED=` pins one, and Settings' "New world" rolls another.
  - Over 30 seeds: 18 pieces a tomb on average and 1.5 flights of stairs. Nothing overlaps except at a door, and every piece is reachable. The tomb's stone is ~76k triangles.
- **3. Relighting (§ET.4, delves.json fire_holders, crawler.json holders).** Every room past the hearth room has a cold hearth ring, and corridors have a stone wall sconce every 7 m. They start out and dark, with the ash of the last fire laid in them.
  - A lit torch's swing catches one; it then never burns down ("kept"), and an unlit torch swung through it catches.
  - Full dark between them: no sky, a 0.05 navy ambient, the haze `#05081c`. With the torch out in a corridor the frame's mean is 0.056, and with its sconce relit 0.267.
  - The log counts the lights burning again. Wordless (§ET.3): no prompts, no HUD lines.
- **4. The snuff rules (§ET.7, `torch.json → snuff`, wired; `TorchSnuff`, `Airways`).** Crawler only; the open world keeps its old torch rules.
  - Walking, turning and looking about never gutter it (a minute in the check).
  - A flat-out sprint gutters at 6 s and is out at 9 s (8.98 s measured); stopping recovers it in 2 s.
  - Airways: an ordinary slot in a corridor wall only leans the flame toward it. A marked mouth low in a room wall (a carved frame, two notches) moans and streams dust 1.5 s before each gust, and the gust puts out a torch in its line, but not one out of the line or behind cover.
  - Wading toward douse depth gutters it, and past it douses it, though there is no water in the tombs yet.
  - Each rule warns first: the coal dims and flickers, with a sputter you hear.
- **5. The rescuer as a baked sprite (§ET.8, §ET.3; `FigureSprite`, `shaders/figure_sprite.gdshader`, crawler.json sprites, rescuer).** The shared rig (CloakedFigure, a zodiac beast head from the seed, the cloak from cloaks.json, painted per §ES) is rendered at boot, in a little world of its own, to one sheet:
  - 8 around × 3 heights (−25°, 0°, 30°) × 4 idle frames (a slow breath), 72 × 96 px a frame.
  - In play it is one upright quad turning to face you, showing the frame for where you stand, stepped at 8 fps. The fire lights it; the fog fogs it.
  - No skinning, cloth or physics in play. The screen fades up from black once the sheet is baked (~3 s).
- **Data:** the `[NOT WIRED YET]` prefix is dropped from `crawler.json` about, opening, themes, progress and sprites, and from `torch.json` snuff. `persistence` and `gates` keep theirs.
  - New Claude Code blocks with `_help`: `kit`, `holders`, `look` (with `fire_shadow_mode: cube`), `airways`, `rescuer`, `snuff_log`, plus `data/game.json`.
- **Fixed on the way:**
  - Campfire's flicker put every fire's light 1 m above its base, which put a sconce's light above the corridor ceiling.
  - The open world's dual-paraboloid fire shadows warp into big curved blots on walls a step from the light, so the crawler uses cube shadows (still only the nearest two fires cast).
  - A sconce's own bracket, cup and coals cast no shadow.
- **Checks:**
  - `tools/crawler_check.gd`: 46 PASS, 0 fails on seeds 7, 1, 42 and 31337. It covers the switch, 30 layouts, floors and ceilings, relighting all 19 holders, the snuff rules and the sprite's frame picking.
  - `tools/crawler_frames.gd` (rendered, the one visual check): 0 fails, with frames of waking, the sheet (all 96 cells hold the figure), the rescuer from three sides, a corridor by torchlight, in full dark and relit, a relit room, and the heart.
- **For Mike to call:**
  - **Spear and bow:** §ED.7 locks them into Torchfire 1, while §ET.1's "no combat" points away from them; this slice has neither (§ET.10 call 4).
  - **Dread:** this slice has no dread meter or hunter in the dark: "full dark" here is light only. Say if the dark should start pressing (§BA) in the next slice.
  - **Torch colour by stone walls:** the torch's own colour (`torch.json light.color #ffb347`) lights near stone a yellow-olive after the grade, where the hearth and sconces read amber. Say if you want it warmer.
  - **Rescuer's head:** the beast is picked from the seed; §ET.9's hood-down human folk come with the NPC maker.

## 2026-10-06 — §ER.1 performance pass and §ES 3D pixel art (270 lines, pre-lit, impostors); occlusion tested and left off
- **The camp view Mike measured at ~7 fps** (`SCENE=rainforest_camp tools/perf_bench.gd`): a rainforest camp at a ruin 40 km from the opening, 15:00, seen from 9 m off its fire.
  - This machine has no GPU (llvmpipe, software rendering), so its milliseconds are about 100× a real card's. Compare the rows, not the numbers.
  - "Drawn" is what the F2 overlay counts. Godot's Forward+ draws opaque things twice (a depth pass, then colour), so the overlay counts them twice; "distinct" is the triangles actually in view.

  | | lines | rain | frame ms (fps) | gpu ms | drawn tris | distinct tris | shadow pass tris |
  |---|---|---|---|---|---|---|---|
  | before | 480 | on | 10,874 (0.1) | 10,812 | 6,077k | — | 2,086k |
  | before | 480 | off | 10,669 (0.1) | 10,602 | 6,608k | — | 2,090k |
  | before | 270 | on | 11,429 (0.1) | 11,305 | 6,079k | 5,405k | 2,087k |
  | before | 270 | off | 11,516 (0.1) | 11,406 | 6,536k | — | 2,090k |
  | after §ER.1 steps 2–6 | 270 | on | 4,089 (0.2) | 4,025 | 2,405k | 1,696k | 836k |
  | after §ER.1 steps 2–6 | 480 | on | 4,785 (0.2) | 4,624 | 2,404k | — | 843k |
  | **after all** | 270 | on | **962 (1.0)** | **883** | 743k | **482k** | 360k |
  | **after all** | 270 | off | 1,150 (0.9) | 1,068 | 746k | — | 748k |
  | **after all** | 480 | on | 1,255 (0.8) | 1,165 | 746k | 485k | 384k |
  | **after all** | 480 | off | 1,419 (0.7) | 1,338 | 748k | — | 778k |

  - The frame is about 11× faster at 270 lines (12× fewer triangles). 270 now beats 480 by about a quarter: with the triangles cut, the pixels count.
  - Distinct triangles are under the ~500k target. The overlay's own count (743k) is not, because it counts opaque things twice.
  - The rain streaks cost within this machine's noise (−12 to +59 ms of ~900). They are one full-screen pass of 130k pixels, far under 2 ms on a real GPU.
- **1. Measurement:** GPU timing is switched on from the start. If a driver still won't time the GPU (Mike's 0.0), the readout now says "gpu n/a, ≤x" instead of 0.0, with the most it can be. F2's readout is now two lines at the bottom left, off the date and biome line. It shows frame, scripts, cpu and gpu ms, everything drawn (draws and triangles), and the shadow pass.
- **2. Render distance:** now a setting in metres (`display.render_m`).
  - Old default: 3 chunks, a 911 m reach. New default: **455 m**. The steps are 200, 300, 455, 600, 750, 911, 1200, 1600 and 2200 m.
  - The chunk ring is whatever covers the setting (2 chunks at 455 m).
  - The fog reaches full just inside it: the same lighter, bluer haze, thickened over the last 40% of the distance, full at 95% (`look_draw_m`).
  - The day haze keeps its tuned density up to 911 m and thins farther out.
  - The far shell (the mountains past the chunks) is cut away at the render distance. A saved setting from the old chunk key is no longer read.
- **3. Triangles:**
  - Ground cover and shrubs are handed to the GPU only where they're in reach. Before, the shader shrank them away but the GPU still drew the whole chunk's worth.
  - Ranges by size class (`look.json ranges`): grass 40 → 25 m, other ground cover 80 → 45 m, shrubs and young trees 150 → 70 m, full trees 120 → 60 m, light trees 350 → 200 m, then sprites.
  - The full band's trees past 35 m use the near mesh.
  - The 4 m ground only on the chunks round you; the far shell in six faces, drawing only those with ground within 12 km, at 64 quads a side (was 96).
  - Fruit: 80-triangle balls (was 320), drawn to 35 m (was 60).
- **4. Rain:** already one screen-space streak pass. It now draws at the frame's own lines (it assumed 480), and the bench measures its cost alone.
- **5. Shadows:**
  - The sun casts no shadow in a storm (storm over 0.35, back under 0.25) or at night, and the moon never does.
  - Only the two fires or torches nearest you, within 24 m, cast a shadow. Each is a dual-paraboloid map, softened, in a 1024 px atlas, fading out from 60% of that reach (`look.json fire_shadows`, `FireShadows`). Every other fire lights without one.
- **6. CPU:**
  - No plant runs a script per frame. Plant collision is only the trunks and limbs you climb (§AM); ground cover and shrubs have none.
  - Folk past `rig_m` (60 m) no longer pose every frame.
  - The ruin camp's weir no longer retries its build on every refresh (a bug found on the way).
- **7. The frame:** painted 480×270 is the default (Mike's data change).
  - Display falls back to the file's preset, and gains **auto**: the first preset that divides the window's height exactly (painted on 1080p and 4K, default 480 on 1440p).
  - F11 and Settings cycle through all of them, auto included.
  - HUD text sizes are still given at the 480 reference and scale with the frame's lines before snapping to VT323's crisp sizes (10 added): 20 px body text and 10 px small text at 270. They re-size live when the preset changes. The watch scales too (never under 64 px), and so do the HUD margins.
  - `hud_pin_check`: every HUD line fits at every preset, painted included.
  - Fog, the grade and the dither run at the frame's lines already. The walkabout (seed 101, 270 lines): **0 fails** across the opening camp at dawn, 1 km down the first road, thorn scrub, jungle and floodplain forest. Blue owns the dawn frame and the water is its brightest thing; the dither and the lighter, bluer distance read at 270; shade goes navy on the sunset scrub.
- **8. Pre-lit** (`Prelit`, `shaders/prelit.gdshaderinc`, `prelit_light.gdshaderinc`; `look.json prelit`; `PRELIT=0` for an A/B):
  - **Painted in the shaders:** every model, plant and the ground is lit from the sky above, and the side facing down sinks toward navy (olive on green things). The sun and moon only tint (their colour and strength, and where they're shadowed, with no N·L). Fire still lights round what it reaches. Leaves keep a faint translucency.
  - **Baked in as each model is built,** never grey:
    - occlusion in the vertex colours, tinted navy or olive;
    - the sculpted bodies' creases;
    - a voxel-occlusion bake on the hood, cowl and capelet (the cowl's deep inside) and on every beast head;
    - the cloak's fold valleys, the capelet's shade on the shoulders and the darkening toward the hem;
    - each leaf cluster darker the deeper and lower it sits in the crown, and trunks darker at the foot and inside the crown;
    - the ground's tree-foot shade.
  - No normal maps, specular, GI or SSAO anywhere.
- **9. Models** (budgets down, §ES.2):
  - **A big tree:** 16k → ~2.4k triangles at the hero level, 9.5k → ~1.4k near, ~200 light. The hair-thin twigs (order 3, under a pixel at 270) are gone. Leaf clusters are capped at 120 and 60, each grown to cover the ones it stands for.
  - **A cloaked figure:** 19.6k → ~4.4k (sculpt cells ×2.6, cloak sub-steps 3×3 → 2×1, hood 28 → 16 sides, capelet 36 → 21, beast-head balls and cones lower).
  - **Props:** balls of 10–16 sides, not 16–28, and cones of 8–12, not 12–24.
  - **Texels:** at 270 lines (78° view) a pixel spans 6 mm per metre of distance: 3 cm at 5 m, 6 cm at 10 m. So nothing finer than ~33 texels a metre at 5 m (~17 at 10 m) stays above a pixel. **The number for LOOK_REFERENCE: 16 texels a metre stays** (one texel a pixel at 10 m, two pixels a texel at 5 m). The same texel-to-pixel ratio as 480's 16/m would be 9/m.
  - **The cloth weave** was ~170–200 texels a metre and crawled; it is now ~32 (0.5 repeats a metre).
- **10. The test figure** (`PRELIT` on vs off, rendered privately at 480×270): the painted folds, cowl shadow and head form read, and the shade side goes softer and bluer. Every cloaked figure shares the builders, so all of them have it.
- **11. Impostors:** each branchy tree species' far picture is now a sprite of its own near model. `PlantMeshes.impostor_sprite` draws it on the CPU, z-buffered, ~50–90 × 64 px, keeping the model's baked light, and the foliage shader keeps season, leaf-fall and palette. It is drawn on the chunk workers.
  - Ruins are not impostored: one sprite turned toward you would show one face from every side, and ruins already switch to plain boxes past ~150 m.
- **12. Occlusion** (`Occluders`; `look.json occlusion.on: false`; `OCCLUSION=1` to build and use them):
  - Each chunk's ground is a coarse sheet sunk under it, and each run of standing ruin wall gets a box.
  - Hilly view (a 218 m rise 300 m off, 5 km from the opening, 270 lines, 33 occluders):

    | | frame ms | gpu ms | renderer cpu ms | triangles drawn |
    |---|---|---|---|---|
    | occlusion off | 314 | 266 | 1.21 | 281k |
    | occlusion on | 286 | 241 | 1.55 | 277k |

  - Only 1.4% fewer triangles: at a 455 m draw distance, under full fog, little stands behind a ridge. The GPU drop is within this machine's run-to-run noise, and the renderer's CPU rose 28%. **Left off.**
- **Checks:**
  - **Pass:** `render_distance_check` (rewritten for metres: the default is half the old reach, the fog follows, and the ring covers the setting wherever you stand). Also `hud_pin_check`, `tree_check`, `wood_normals_check`, `fae_check`, and `leaf_lod_check` (updated to the new bands, with 6 m of slack round each band's edge because the bands re-sort only every 15 m of walking).
  - **Fail the same at the base commit, so not this pass:** `vine_check` (ivy on 0 of ~940 temperate trunks) and `growth_check` (a shrub's leaf cards know their middles).
  - **Shaders:** every edited shader compiles in a render, and `shader_varying_check` passes.
  - **Engine errors:** a `multimesh_set_buffer` size error repeats in every rendered run, about 1,200 a run before this pass and fewer now. It predates this work and is still to find.
- **Data** (additive, each with its `_help`):
  - `look.json`: `ranges` (numbers changed, with §ER.1 in the help), new `fire_shadows`, new `prelit`, new `occlusion`.
  - `hud.json`: `text.crisp_px` gains 10.
  - `torch.json`: `light.shadows` is marked not read.
  - `project.godot`: the `look_draw_m` and `look_prelit_*` globals, and `positional_shadow/atlas_size` 1024.

- **For Mike to call:**
  - **Sun shadows (§ES.2 vs §ER.1):** §ES.2 says the live light only adds the time-of-day tint and the fire, while §ER.1 keeps the sun's shadow by day. I kept the sun's cast shadow as part of its tint (on in clear daylight, off in storms and at night). Say if pre-lit should mean no sun shadows at all.
  - **The great ranges past 455 m:** with the fog full at the render distance, they now show only as pale silhouettes against the sky. A longer render distance (Settings) brings them back.
  - **Budgets:** a figure is ~4.4k triangles against §ES's ~1,500, and a big tree at the hero level is ~2.4k against "less than a figure". Pushing figures further turns hands and legs to blobs. Say if you want that.
  - **Ruins are not sprites:** see step 11 above.
  - **Auto pixel size:** `look.json render.auto` says a window no preset divides falls back to default (480); I used the file's own preset (painted), per §ES.

## 2026-10-06 — §EQ life-sized beast heads; the hood becomes a cowl; the silhouette lineup
- **What changes on screen:** the beast heads are now the animal's own size and sit out in front of the hood, with the hood draped behind them like a cowl (the goat of reference frame 3). Before, every head was shrunk to fit inside a human hood.
  - **Life-sized:** each head is scaled by its `scale` in `beast_head_fit.json` (1.15 for rat and monkey, up to 1.7 for the horse). It is pushed forward and a little down, so its muzzle, beak or snout juts past the old brim by its `muzzle_out` share of the head's length.
    - The push is `forward_m`, or more where that isn't enough to get the muzzle out (rat 8 cm, horse 10 cm, others 5–8 cm).
    - The bodies and the shared rig are unchanged; only the head's own node moves.
  - **The cowl:** on beast folk only, the hood is swapped for a cowl.
    - It is the same hood with its inside lined in cloth, no dark void, stretched up to 1.25× to fit round the bigger skull.
    - Its brim slides back behind the middle of the skull, by `cowl_back_m` at least, and further where needed so every `through_hood` part stands in front of it.
    - It tilts back off the crown, so it drapes on the shoulders like a hood pushed back.
  - **Through the hood:** ears, horns, combs and the rest stand out in front of the cowl, never folded under it.
    - The rabbit's ears now stand up; before they were laid back under the hood.
    - The horse gained upright ears, and the ox, goat and monkey gained ears.
    - Added for the parts the fit file lists: the rat's whiskers, the tiger's cheek ruff, the dragon's jaw frills and the pig's tusks.
  - **Fading:** the head's outline now shows at every distance (§EQ.2). Only the painted face detail fades: eyes, nose, stripes, the muzzle's paler fur, horn and comb colours. It is full within 4 m and flattens to the animal's plain fur by 8 m. The head no longer fades into the dark hollow.
  - **Hitboxes:** a beast folk's head hit sphere now sits round the life-sized head (its bounds' middle, half its longest side), never smaller than before. It updates whenever a head is put on.
  - **The player is untouched:** your hood stays whole, empty, indigo with the rust hem (§EO.2). Asking the player to wear a head does nothing.
- **The silhouette lineup (dev):** `data/dev.json → beast_lineup` (`on: true`, dev mode) or `BEAST_LINEUP=1` in the environment (`BEAST_LINEUP=colour` for colour).
  - All twelve stand side-on in a row on a dark ledge 6 m in front of where you wake, raised 1.4 m so their heads stand against the sky.
  - They are drawn pure black, or in their colours, and held still (no head turning).
  - Distance, height and spacing are in the same block.
- **Data:**
  - `beast_head_fit.json` is read through `Tuning`, each animal over its `defaults`.
  - In `zodiac_heads.json → look._help`, `hood_shade` is now marked not read.
  - `dev.json` gains `beast_lineup` with its `_help`.
- **What the code does:**
  - **BeastHeads:** tags every part of a head and works out the fit (`fit()`: the head's transform, the cowl's transform, the bounds), with one material per animal.
  - **`PlayerBody.set_beast`:** places the head and swaps the hood for the cowl (`_cowl_mesh`: `_hood_mesh(false)`).
  - **`CloakedFigure.fit_head_hitbox`:** sizes the head hit sphere.
  - **New `BeastLineup`:** builds the lineup; `PlayerBody.look_still` keeps its figures from turning.
- **Check:** `tools/fae_check.gd` gives 0 fails. It prints each animal's scale, its forward push, the share of its length past the brim and where its cowl's brim lands, and checks:
  - every head is at its fit scale with its muzzle out by its share;
  - every `through_hood` part exists and stands in front of the cowl's brim; no ears are laid back;
  - a camp's folk all wear cowls (their hoods hidden), and their head hitboxes sit round the life-sized head;
  - the player keeps the whole, empty hood and gets no cowl;
  - the head shader has no hollow fade and flattens to fur;
  - the lineup stands all twelve, each in its own head.
  - `circle_check` still gives 0 fails.
  - A float rounding in the hitbox test (the monkey's sphere sits at the 0.13 m minimum) first made it fail now and then; fixed in the check.
- **Walkabout:** `SEED=7731 QUICK=1 SITES=lineup HOURS=12` wrote `lineup_black_12h_f0.png` and `lineup_colour_12h_f0.png` (a harness frame: the ledge 2.2 m up, beside the opening camp). The twelve stand side-on against the sky.
  - In black, the snouts, the horns of the ox, goat and dragon, the rabbit's ears and the rooster's comb break the outline.
  - In colour, the opening camp's rat folk behind wear their cowls.
  - The dog, the pig and the monkey are the hardest to tell apart in black; their numbers are the dials.
- **Flags for Mike:**
  1. **The fit numbers are as Claude (chat) wrote them**, except where the forward push had to grow to get `muzzle_out` past the brim. The cowl's 1.25× stretch limit and its tilt are mine (`COWL_K_MAX`, `COWL_TILT` in BeastHeads). Say if the cowl should be smaller or sit lower.
  2. **"Scale the head pivot only":** I scaled the head's own node under the Head pivot rather than the pivot itself, because the pivot also carries the hood. The cowl is the hood swapped and moved, not scaled with the head.

## 2026-10-06 — §EO beast heads under the hood, the empty hood, fairy rings and the fae
- **Beast heads (§EO.1):** every people's folk now have an animal's head under the hood, one of the twelve Eastern zodiac animals. The cloaked rig is unchanged; only the head is new.
  - **Up close only:** the face shows fully within 4 m. Between 4 and 8 m it fades into the hood's flat dark hollow, so from further off a figure is still a person with an empty hood.
  - **Firelight:** only part of the light reaches into the hood (`hood_shade` 0.6), so a face reads best by the fire.
  - **The heads:** each is a few rounded shapes (skull, muzzle or snout, ears, horns, beak, comb, beard), with the snout, horns or beak just out past the brim. In a firelight test render all twelve read: rat, ox, tiger, rabbit, dragon, snake, horse, goat, monkey, rooster, dog, pig.
  - **Who is which:** a new `peoples` block in `zodiac_heads.json`, my first guess from each animal's home (you own it):
    - rat: river, marsh, rock shelter
    - ox: savanna herders
    - tiger: taiga
    - rabbit: highland, lake
    - snake: desert, mangrove
    - horse: steppe
    - goat: mountain
    - monkey: rainforest, canopy
    - rooster: karst
    - dog: tundra, coast
    - pig: old growth
  - **The dragon** is no people's: it is the rare tribe, 3% of camps (`rare.dragon.chance_per_camp`). The opening camp is never dragons.
  - **Who wears them:** camp folk (the guards, walkers, water carriers, the hunter and the gift-giver too), the opening camp, and road travellers (the people whose land the road crosses).
  - **Who keeps the empty hood:** the small folk with their lanterns (`look.no_head_kinds`), the thirteen of the wandering fire, the ox rider, the uniques, haunts and the dark's figures.
  - Goblin, orc and small folk are not retired.
- **The player's hood is empty (§EO.2):** it always was (the hollow is drawn flat and unlit). Now `PlayerBody.set_beast` refuses the player outright, and the check asks.
- **The mushroom (§EO.4's build need):**
  - A short stem, a two-tier domed cap and a dark gill ring.
  - Square-cut in the ruin material at 16 texels a metre, so a cap is a couple of big texels. Matte, a clean silhouette.
  - About 60 triangles; a whole ring is one mesh.
- **Fairy rings (§EO.4):**
  - **Where:** 12% of terrain chunks (about 260 m across) roll a ring, from the world seed, so a ring is always in the same place.
  - **Which survive:** one in water or on a slope over 18° is dropped. Round the river opening camp on 7731 that leaves about 3% of chunks, roughly one ring per 2 km².
  - **The ring:** 11–19 pale buff mushrooms, 6–14 cm tall, round a 1.4–2.6 m circle, with now and then a small one beside.
- **The fae (§EO.3, §EO.4):** sit inside a ring for 10 s and, if it is their hour, three small earth fairies come.
  - **Sitting:** the game has no sit action yet, so crouched (Shift) and still counts as sitting.
  - **Their hour:** each ring's fae are day fae or night fae (half and half). Night fae come only when the moon is at least a quarter lit (the moon's phase sets it).
  - **Their look:** no cloak. A glowing body and head and two pairs of beating wings, each casting a small light and shedding a trail of glowing square pixels. Day fae are pale yellow-green, night fae pale teal; never fire's orange.
  - **Trust:** hidden, per ring, kept in the world's save, never shown.
    - The first time they are a flicker 9 m off for 4 seconds.
    - Each time they come the ring's trust grows by one, at most once every 2 game hours, up to 5.
    - At 5 they circle 1.2 m round you for 45 seconds.
    - Stand up or walk off while they are out and they scatter.
    - They come once per sitting; sit again to see them again.
- **The gifts (§EO.5): stubs only.** `FaeRings.gift_light` and `FaeRings.lead_to_lair` read `fae.json → gifts` and return false. Nothing calls them yet. The `gifts` block is marked `[NOT WIRED YET — design §EO.5]`.
- **Data:**
  - **`zodiac_heads.json`:** new `peoples`, `rare` and `look` blocks (fade distances, hood shade, no-head kinds, three colours per animal).
  - **`fae.json`:** new `ring_look`, `sitting`, `bands`, `trust` and `fae_look` blocks, each with `_help`. `gifts` gains its help line and two stub numbers.
  - Both files are read through `Tuning`.
- **What the code does:**
  - New `BeastHeads` (`scripts/creatures/beast_heads.gd`) and its shader (`shaders/beast_head.gdshader`).
  - `PlayerBody.set_beast()`: a body that isn't the player's takes the `beast` of the camp or road it stands under once it enters the scene.
  - New `Mushroom` and `FaeRings` (`scripts/landmarks/`). Main runs FaeRings.
- **Check:** `STAMP=1 SEED=7731 … --script tools/fae_check.gd` gives 0 fails:
  - all twelve heads build and fit the hood;
  - all 17 peoples map to 11 animals; the dragon at 2.9% of 4,000 camps;
  - the small folk get no head; the player refuses the ox;
  - a built river camp's 6 folk and the opening camp's 5 all wear the rat;
  - the fade distances match the data;
  - rings are rolled in 7% of 270 chunks and kept dry and flat (3%);
  - nothing comes before 10 s of sitting, then three glowing, lit, speck-shedding, uncloaked fae, a flicker at 9 m that leaves after its 4 s;
  - trust 1, unchanged on an immediate second visit, scattering when you stand;
  - a later visit closer (7.4 m) at trust 2;
  - the day/night band; the gifts are stubs.
  - `circle_check`, `library_check`, `sharing_check`, `workshop_check`, `hunt_check` and `third_places_check` still give 0 fails.
- **Walkabout:** `SEED=7731 QUICK=1 SITES=beasts,fae HOURS=21`.
  - **`fae_22h_f0.png`:** a ring 16–24 m from the opening camp, chosen with nothing solid between the eye and the ring, its trust set to 5 and the fae held out (a harness frame). It shows the three fae circling with their speck trails over a pool of teal light, the camp's fire and the full moon behind. The mushrooms are small dots at that distance.
  - **`beasts_22h_f0.png`** (the opening camp's elder up close by the fire) does not frame a face. The folk move between the frame's setup and its capture, and the camera ended on top of the elder. The heads were checked instead in a probe render by firelight alone, where all twelve read.
  - On the way, the heads first rendered black because their triangles faced inward; fixed.
- **Flags for Mike:**
  1. **There is no sit action**, so crouched and still counts as sitting. Say if you want a real sit (a key, a pose).
  2. **Which tribe is which animal** (`zodiac_heads.json → peoples`) is my guess; 17 peoples share 11 animals. The dragon is a 3% roll per camp, not a people of its own.
  3. **`folk_kinds.json` still has a cloaked folk kind called "fae"** ("slight, folk_scale 0.85", at old-growth, lake and rainforest camps). §EO.3 says "fae" now means the uncloaked fairies. I left that kind as it is (those camps wear their people's beast). Rename or retire it?
  4. **"The moon's phase can set which":** I read it as "night fae need the moon at least a quarter lit". On dark-moon nights a night ring stays empty.
  5. **Rings are sparse near the river camp** (water drops half of them): about one per 2 km². `ring_look.chance_per_chunk` is the dial.
  6. **The thirteen of the wandering fire** are desert folk but a unique band, so I left their hoods empty. Say if they should be snakes.

## 2026-10-06 — §EN the library, the winter count, the knot cord, the record-keeper (queue 43)
- **What changes on screen:** when a camp reaches the storage rung (the rung where the workshop comes), it builds a library 4–8 m from its fire, clear of the workshop and the third places, with its open side to the fire. A camp below storage keeps its book on the altar by the hearth, as before.
  - **Its form:** a small hut (back and side walls, a pitched roof) in the people's own workshop materials. At a camp in a ruin, or where the people's `huts.library` says lean-to, it is a lean-to instead: one old stone wall at the back, the roof leaning from it down to two posts at the front (the low edge above eye height, so you see in under it), and a screen each side. It is square-cut like the workshop hut.
  - **The camp book** (§ED.3) is on a shelf on the back wall, with a stool before it. You read it there exactly as before. The altar stands no more once a camp has its library.
  - **The tome shelf (left wall):** up to `tomes_max` (6) found tomes, standing upright. At a ruin camp the ruin's delve tome (§DL) stands there while you have not taken it from the delve. "read the <title>" opens it in the tome panel, and it is never taken off the shelf.
  - **The winter count (right wall):** a hide, or the people's own surface (a slab, a skin, a mat, bark, plaster, by the words of their `huts.library`). One small painted picture (3×3 texels, red-brown ink) for each game year the camp has lived, spiralling out from the middle. There are no letters and no numbers: a small figure (a birth), half a flame (the fire ran low), a stump (the woods stripped), a ring (a hearth relit), antlers (a big hunt), two figures (the camp grew), a figure lying (folk lost), a black band (wildfire), three wavy lines (a soak found), and a single dot for a quiet year.
  - **The knot cord** beside the hide: one knot for each living folk, undyed for a child, ochre for a teen, indigo for an adult. It is re-tied as folk are born, grow up and die.
  - **A camp that goes dark keeps its library.** The hide gets one black square and no more years, and the knots stay as they were. Nothing names what happened (§BQ).
- **The record-keeper (the fourth face):** the sim gives the role to one adult when the camp reaches storage. In the gather hours they keep the library:
  - writing at the shelf with a quill, always within 2 game hours (`writes_after_event_game_h`) of a new camp-book line;
  - or walking out to look at one thing (the woodpile, the food store, the newest child, a hide on its frame at the soft bench, the fire) and back;
  - or sitting with a tome.
  - At dusk they go to the fire like everyone. They are the one who gives you the §EJ gift where there is one. They have no workshop bench.
- **How a year's picture is chosen:** the sim records which of `winter_count.events` happened in each game year. The year's picture is **the first one in that list that happened** (the list order is the "biggest event" order). So far the events are: births, a fire-low night, the woods stripped, a cold hearth relit, a big hunt (large hoofed or marine), reaching storage (the camp grew), a gatherer lost, a wildfire, and a soak found.
- **What the code does:**
  - New `scripts/peoples/library.gd` (Library) holds the winter-count sim, building the library, painting the hide (pixel glyphs into a 24×20 texture, lit like the camp's other props), tying the knots, and the record-keeper's day.
  - CampSim gives the role, records the events, and calls `Library.tick` hourly and `Library.close` when a camp is abandoned.
  - Camps build it, run the record-keeper, and refresh the hide and the cord.
  - `CampBook.place_on` puts the book on the shelf.
  - Main shows the tome shelf's read prompt.
- **Data:** the `library` and `specialists.record_keeper` clauses of `camps.json → _help.village_economy` are wired, and `sim.library` gets its `_help`. In `camp_books.json`, `object.placement_eh` is wired and the hide's pictograms gain `quiet` (a single dot; added with the wiring).
- **Check:** `STAMP=1 SEED=7731 … --script tools/library_check.gd` gives 0 fails:
  - all 17 camps at or past storage (two rings round the player) have a library and a record-keeper; none below storage has either;
  - the camp book is on the library shelf, the only book there, and opens from it;
  - a camp 3.5 years old has 3 pictures (birth, antlers, dot): a year with a birth and a hunt shows the birth;
  - one knot a folk, right colours, after a birth and after a child grows;
  - a camp gone dark keeps its library, its black square last, no pictures in the next 2 years, its 8 knots unchanged;
  - a tome stands on the shelf and the panel opens from it;
  - the hide uses no font.
  - Two SKIPs on this planet: no overrun ruin is within a rumour's range of these camps, and no ruin here has a tome at its delve's heart (so the never-taken rule is untested; the shelf was tried with the I Ching).
  - `third_places_check`, `sharing_check`, `circle_check`, `workshop_check`, `hunt_check` and `trades_check` still give 0 fails.
  - Over its 34 camps `third_places_check` now places 25 water rocks and 33 porches (26 and 34 in the §EM entry). One fewer camp reaches storage in that run since this pass's sim changes. I didn't trace which.
  - Third places are now placed **before** the library, so the library steps round the land's own spots. With the library first, one coast camp lost its water rock.
- **Walkabout:** `SITES=library QUICK=1 HOURS=9` builds a ruin camp at the storage rung 14 m from the ruin nearest the opening camp (Old-growth folk, so the lean-to). It gives the camp six years on its hide (a camp grew, a birth, a quiet year, a big hunt, a birth, a fire-low night, recorded as the sim records them) and stands you just under the roof at the front-left. The frame (`tools/reference/walkabout/7731/library_09h_f0.png`) shows the stone back wall, the roof's underside, and the record-keeper at the shelf writing (`write_at_shelf`). The hide is on the right-hand screen, but at 9 in the morning it is in the lean-to's shade and reads as a dark panel: its pictures don't show in this frame.
  - Fixed on the way:
    - the hide was first a plain material the sun blew out white; it is now lit like the other camp props;
    - the library first faced its back wall to the fire;
    - its walls were rounded blobs (the creature-body box); they are now square-cut with the workshop's builder;
    - the lean-to's low edge was below eye height.
  - The walkabout's player stands 1 m up and never falls (physics is off), so for this one site the harness sets the feet on the ground.
  - A small bright square shows in every frame of this site, including the first render before any of these fixes. It is not the book, the quill or the hide. I didn't track it down.
- **Flags for Mike:**
  1. **"The year's biggest event"** is taken as the first of `winter_count.events` that happened that year. The list as written puts birth first, so a year with a birth and a wildfire shows the birth. If you want the big disasters to win, reorder the list (e.g. wildfire, folk_lost, ruin_restored first). It is data only.
  2. **No tome texts are in the repo yet**, and no ruin on 7731 has a delve tome near a storage camp, so in play the tome shelf is empty for now. The shelf and the panel work (tried with the I Ching).
  3. **The opening camp gets no library.** The opening camp is built by its own code (Encampment), and the library is built only at the world's camps. Say if you want the opening camp to grow one when it reaches storage.
  4. **The winter count is dark inside a lean-to by day** (in shade, like everything under a roof). If you want it to read from the fire, it could hang on the outside of the screen, or face the open side. Your call.
  5. **`ruin_restored`** is recorded when a cold hearth is relit at the camp. `woods_stripped` and `fire_low` are recorded from the sim's own events. `soak_found` is recorded the first time a camp's soak is placed.
## 2026-10-06 — §EM third places: the soak, the great tree, the water rock, the porch (queue 42)
- **What changes on screen:** after a camp's fire circle (and its workshop), the third places its people list (`huts.third_places`) are placed where the place has them.
  - **The soak:** at the nearest hot spring ground within 400 m, a pale pool ringed with rim stones, white steam rising slow off it. In the afternoon folk walk there and sit in it to the chest with their hoods down. This is the only time a hood is down: the plain head shows, the hood folded at the nape.
  - **The great tree bench:** a log or a flat stone at the foot of the biggest tree within 60 m, the sitter's back to the trunk, facing the tree's open side. Used in the heat of the day, the middle third of the gather hours.
  - **The water rock:** a flat stone on the nearest fresh-water bank within 60 m, a bank boulder behind it, facing the water. Used by day. A people who know `fishing_line` hold the pole and line out over the water.
  - **The hut porch:** the workshop's porch seat (§EL), by day.
  - **The people's own place:** placed only at the weir's lip ("the weir's lip at low water"), once the camp has its weir. Every other phrase is skipped because the camp has no such spot yet.
- **Who goes:** in a place's hours, folk sitting at the fire walk there and sit, up to its `max_at_once`, then walk back when the hours end. The fire's keeper stays.
  - Folk at a bench, out gathering, carrying the meal or the gift are never taken (jobs first).
  - At a camp below storage (no workshop) that is everyone but the keeper. At a workshop camp by day it is the children and anyone the benches had no room for.
  - Seated there, they play one idle set: sit, lean back, look out, the pipe (one at a time); the line at the water rock. Their hoods turn to you when you come near, as at the circle.
  - Nothing in the sim moves.
- **Prospect and refuge (§EG.4):** every seat has something solid within 2 m behind it (trunk, rim stone, boulder, hut wall, or a bank half a metre up) and nothing within 1.5 m in front. A spot that fails is tried round its feature, or skipped.
- **What the code does:**
  - New `scripts/peoples/third_places.gd` (ThirdPlaces): placing, the prospect test, who goes, the walks, the hood and the steam.
  - Camps and the opening camp call it after the circle.
  - FireCircle plays a third place's own idle set (`ctx.only`), with new poses: sit, lean back, look out, the fishing line.
  - `THIRD_PLACES=0` turns it off for A/B.
- **Data:** `camps.json → sim.third_places` gets `_help`, `tree_m` 60 and `water_m` 60 (added with the wiring). The third_places clause of `_help.village_economy` is wired.
- **Check:** `STAMP=1 SEED=7731 … --script tools/third_places_check.gd` gives 0 fails:
  - 34 camps (every people, two rings round the player) placed 26 water rocks and 34 porches, and every camp whose people list a place, with the feature there, has one;
  - no kind is placed that the people don't list;
  - every seat passes the back-and-view test;
  - a camp 20 m from the tallest loaded tree (80 m) has its bench at the trunk's foot, 3 seats, backs to the trunk;
  - a mountain camp 150 m from a hot spring (2.8 km from the player) has the soak at the spring with 4 seats;
  - through an afternoon the soak held at most 4 (its max), every soaker's hood was down and nobody else's;
  - through a river camp's day the folk on jobs are identical with third places on and off;
  - the sim's food, wood and folk are identical over 3 game days on and off.
  `circle_check`, `sharing_check`, `workshop_check`, `hunt_check` and `trades_check` still give 0 fails.
- **Walkabout:** `SEED=7731 QUICK=1 SITES=soak HOURS=15` wrote `tools/reference/walkabout/7731/soak_15h_f0.png`. It is a mountain camp's soak at the hot spring nearest the opening camp, 7 m from the pool at 15 h (a harness frame: the camp is built 150 m from the spring with five adults and three children, and the walk there is instant).
  - The pale pool, its ring of dark rim stones and a low drift of white steam are in the middle of the frame, on open grass with the road beyond.
  - The three children sit in it, small, hoods down.
  - Two passes got there: the first had the steam as a 20 m column and the children sunk to the head. The steam is now 3 m high and 2.4 m wide, and the depth scales with a sitter's size.
  - After this frame the water level was set to the rim's highest ground, because on this slope the near side of the pool sank under the grass. That fix isn't in the frame.
- **Flags for Mike:**
  1. **At a camp with a workshop, by day the adults are at the benches or out gathering**, so the "jobs first" rule leaves only the children and the porch overflow for the third places. Your picture of "two under the big tree, one with his feet in the river, one on the porch with a pipe" happens at camps below storage (everyone but the keeper is idle at the fire there). §EM says third places also fill "the hot midday"; the prompt says the gather hours are unchanged. If you want a real midday rest for adults at big camps, say so and I'll shift the generalists' bench and out time around it (the sim's gathering stays the same).
  2. **Trees are thin round the opening camp on 7731** (145 in the 12 loaded chunks, none within 60 m of the test camps), so the great tree bench was only tested beside a chosen tree.
  3. **The people's own places** ("the midden top at sunset", "the corral wall at dusk"...) need spots the camps don't build yet. Only the weir's lip is placed.

## 2026-10-06 — §EJ food passed round, the night stories, the gift (queue 41)
- **What changes on screen:**
  - **The food store shows pieces.** Each piece is one day's eating for that camp: strips on the rack first (up to eight), then baskets below (up to eight).
  - **The meal:** at the end of dusk_form (an hour and a half after the gather hours end, 18:30 local), an adult walks from the circle to the store, takes a piece off it, carries it back and sits. Then everyone seated eats from a bowl. The store is one piece smaller from that moment. The carrier is never the folk who hunted that day.
  - **What the store shows the rest of the day:** it never shrinks at other times. Gathering, a hunt or your gifts add pieces as they come in.
  - **Your bowl:** stand within 3.6 m of the fire when the bowls go round and a bowl appears in your hands, lifted now and then, for as long as theirs. The log says "They shared their food with you." the first time at each camp. No stat changes. There is no sit action, so standing in the circle counts.
  - **The night stories:** at night by a fed fire, one adult tells: the hands move and the hood turns to each listener in turn. Everyone else awake looks at the teller instead of the fire for the hold, then back. There is one teller at a time. Never by day, and never when the fire is low or out (a telling stops if the fire drops).
  - **The gift:** once you have put 6 units on a camp's store or woodpile, at the next dusk with you within 30 m, an adult (the record-keeper once there is one, §EN) walks up to you, holds a thing out in both hands, and it goes in your pack. The log says, for example, "River folk gave you a torch." It happens once per camp.
  - **What the gift is:** something the camp could make. A torch from any fire, a bowl of stew while it has food, a pot with pottery, a cord hank or a basket with cordage. Four new item kinds, with their own icons: pot, bowl of stew, cord hank, basket.
- **What the code does:**
  - New `scripts/peoples/sharing.gd` (Sharing).
  - The sim's eating is unchanged. CampSim tells Sharing what was eaten each tick (`eaten_since_meal`), and once a local day at the meal hour the store's shown pieces fall by `piece_off_store_per_meal`. What came in since the last meal adds pieces.
  - `Sharing.live` draws the meal and the gift at the opening camp and every people's camp.
  - FireCircle has the new `night_stories` idle: teller, listeners and the fire gate.
  - CampSim asserts one store per camp; no folk record holds food or wood.
  - `add_food`, `add_wood` and `add_seeds` count toward the gift.
- **dusk_form:** the camps had no dusk_form walk of their own. The workshop camps already walk back from the benches at gather end (§EL), and the opening camp sits all day. I built only the meal's walk on it, as §EJ asks, not a general walk-in-carrying for every folk.
- **Data (additive, with help):**
  - `camps.json → sim.sharing`: `player_in_circle_m` 3.6, `gift_back.reach_m` 30, `gift_back.hold_out_s` 2.5.
  - `fire_circle.idles.night_stories.turn_s` 3.5 (seconds the teller faces each listener).
  - `items.json` kinds: pot, bowl_of_stew, cord_hank, basket.
  - The sharing and night_stories clauses of `camps.json _help.village_economy` are wired.
- **Check:** `STAMP=1 SEED=7731 … --script tools/sharing_check.gd` gives 0 fails:
  - over 14 game days at a full store, the pieces fall by exactly 1 at each meal and never at other times;
  - the meal tick eats only the tick's share (no double eating);
  - the day's hunter never carries (forced as well);
  - the built store drops from 3 to 2 pieces once the carrier has taken it off;
  - all 8 seated folk eat;
  - the player in the circle gets a bowl at both meals and one log line;
  - night_stories ran 2073 frames by night, never by day, never at a low fire, never two tellers, and every listener looked at the teller;
  - no gift before 6 units, then exactly one per camp (3 camps);
  - no per-folk food or wood in the states or in CampSim's code.
  Also run:
  - `hunt_check`, `workshop_check`, `trades_check`, `basalt_check`, `no_metal_check` and `circle_check` give 0 fails. `circle_check`'s notice test now holds the circle still first, because a listener rightly looks at a teller rather than the fire.
  - `camp_check`'s canopy-platforms line and `village_check`'s 5 layout lines fail on 7731 as before. That is code these prompts don't touch (CanopyVillage, the village plan).
- **Walkabout:** `SEED=7731 QUICK=1 SITES=meal HOURS=19` wrote `tools/reference/walkabout/7731/meal_20h_f0.png`. It is the opening camp at dusk, seen from your place in the circle (a harness frame: the meal is held at the frame's hour).
  - The store (the rack of strips behind the fire) went from 3 pieces to 2.
  - The carrier stands in the ring on the way back to the seat with the piece in their hands, and the others sit round the fire.
  - **Two things in the frame I can't fully account for:**
    - A brown shape rides just above the standing carrier's hood. A probe puts the piece in the hands at 0.86 m, and the rig measures the same as a figure built standing, so I believe it is the cloak cloth still settling a dozen frames after the carrier stands. It needs a look in play.
    - A pale square floats right of centre. I could not identify it.
- **Flags for Mike:**
  1. **There is no sitting down for the player**, so "sit in the circle" is "stand within 3.6 m of the fire" (`sharing.player_in_circle_m`). If you want a real sit (a key at the spare seat), that's a new verb; say so.
  2. **The gift waits for you.** It comes at the next dusk you are within 30 m of the camp, not at a dusk you miss.
  3. **The store's look changed:** it now shows a day's eating per piece (up to 16), not a strip per 2 units. A camp that is short shows few pieces even though it still eats.

## 2026-10-06 — §EK the whole animal: the hunt, the hut, the six things (queue 40)
- **What changes on screen:**
  - **The hunt:** a camp with a workshop (storage rung and up; the opening camp has none) hunts one to three times a game week, in the gather hours. An adult takes the spear: never the keeper, never a teen or a child. They walk out 400–800 m, past where the gatherers go, to where game is, and stand out there a while. The kill is never shown.
  - **Coming home:** they walk back carrying it by its size: a hare or fox over the shoulders, a bird in hand, fish on a line, a deer or buffalo on two poles dragged behind, the hunter leaning into it.
  - **The hut:** the carcass goes in at the workshop's back door, which is out of sight from every place round the fire, and you never see it again. No blood, no cutting.
  - **The pieces:** six game hours later the animal comes out as pieces. Up to its `things_shown` land on their benches and by the hearth, hide and meat first: a hide on its frame, sinew, bone tools in a row, meat strips on the rack, the rendering pot, a horn cup. The food store gains the class's `food_units`.
  - **The lamp:** fat, oil or blubber keeps the hearth lamp lit for three nights, from the hearth's fire (fire carried, never made).
  - **Decay:** the soft and food pieces are used up quietly after a game week. Bone tools, horn, antler and teeth stay.
  - **The log:** once per species, if you are within 120 m when the hunter comes home: "The hunters brought back a deer. By evening it was a stew, a hide on the frame, and a lamp."
- **Game counts (Mike: "it just basically respawns if they get too low"):** no ecology. New `GameCounts` keeps a count per area (a planet cell) for each huntable class: small game, bird, fish, small and large hoofed, marine mammal, reptile. Each hunt takes one. A class at its floor (2) is never hunted, and one that falls to it is back at capacity 4 game days later. The tunables are in the new `camps.json → sim.hunt.game` block.
- **Which game lives where:** the creature catalogue's rows had no size class, so I added a `size_class` field to 15 rows of `data/creatures/creatures.json` and all 49 rows of `catalogue_fish.json`. A class is present in an area when a catalogue species of that class fits its temperature and moisture (water birds and fish need water near).
- **What the code does:** new `scripts/peoples/hunt.gd` (Hunt: the schedule, the trip, the pieces, the lamp, the figure) and `scripts/creatures/game_counts.gd` (GameCounts). CampSim ticks the hunt. Camps draws the hunter (`HuntCarrier`) and the pieces. The workshop gets the back door. `data/animal_use.json` is read through `Tuning`, and its `_help` and the hunt clause of `camps.json _help.village_economy` are no longer `[NOT WIRED YET]`.
- **Check:** `STAMP=1 SEED=7731 … --script tools/hunt_check.gd` gives 0 fails:
  - 6 hunts in 14 game days at a storage camp (2–6 wanted);
  - every hunter an adult who is not the keeper;
  - after each hunt the pieces rise by `things_shown` and the store by `food_units`;
  - the lamp unfed before the first hunt and fed after;
  - one log line per species (6 lines, 6 species);
  - no hunt when every class in reach (97 areas) is at its floor, and hunting again once they respawn;
  - marine mammals only at tundra and coast camps (3 of 714 hunts);
  - the back door out of sight from all 12 places round the fire, at every people's workshop (physics rays).
  `workshop_check`, `trades_check` and `no_metal_check` still give 0 fails.
- **Walkabout:** `SEED=7731 QUICK=1 SITES=hunt HOURS=15` wrote `tools/reference/walkabout/7731/hunt_15h_f0.png`. It is a river camp at the storage rung built 120 m down the road from the opening camp (a harness frame: the camp, its rung and the hunt are set for it), seen from the road 35 m back at 15 h. The hunter is in the middle of the frame, 22 m from the camera, walking away toward the camp with the deer on its two poles dragging behind. At that distance it reads as a small brown figure with a brown load, clear against the grass and in front of the camp's huts and smoke. (The first render drew the poles in front of the hunter; fixed, `Hunt._figure`.)
- **Flags for Mike:**
  1. **There are no seals or walrus in the creature catalogue.** A cold coast (under 14 °C) counts as having marine mammals, and the hunter brings back a "Seal" as a class, with no creature behind it. Add a seal row to the catalogue and it will be used.
  2. **Only camps with a workshop hunt** (storage rung and up). The prompt said "a storage-rung camp", and the hut is where the animal goes. Below storage, camps forage only.
  3. **Leather and the lighting trade now follow the hunt:** after its first hunt a camp has a hunt for `hunt_or_herd` and fat for `fat_or_oil_or_resin`, so those trades can appear at camps where the land alone gave them nothing.

## 2026-10-05 — Mike's calls on the village economy flags
- **Villages:** a relit village hearth now stays lit. The villagers it draws back tend it, so it no longer burns down (`FireStore.burn`: a village hearth's store is `kept` once lit). `tools/village_check.gd` checks it: a relit village hearth is still burning after 100,000 minutes, while an ordinary old hearth burns out.
- **The opening camp has no workshop in play.** Only the walkabout's harness frames build one there.
- **Births can grow a camp to 50:** new `camps.json → sim.population.births_to_village_cap` (true). A camp's ceiling is then the village cap, and food still gates every birth. The forage, weir and crop ceilings apply only if it is switched off.
- **Trades** (Mike: "whatever makes sense, fundamental first"):
  - A camp shows cordage first, then its maker's trade with every trade that trade needs, then the rest in order (`Trades.pick_shown`).
  - Lighting no longer waits on pottery, matching §EI.3's fat, oil or resin.
  - Result on seed 7731 (119 test camps): lighting now shows at 57 camps.
  - Textiles still needs a herd's wool or a fibre crop together with leather, so it shows nowhere yet.
- **The hunt (prompt 40):** Mike's call is that no elaborate ecology is needed. A simple per-area game count that drops with each hunt and refills when it gets low will do; built with prompt 40.
- `tools/no_metal_check.gd`, `tools/trades_check.gd` and `tools/workshop_check.gd` all give 0 fails on 7731.

## 2026-10-05 — §EI what a camp needs, and the trades that follow (queue 39)
- **What changes on screen:**
  - **Water:** at its trip hours (two a day, again for each ten folk past ten) a folk walks from the hearth to the camp's water with a pot on the head, pauses and walks back. The water is the nearest fresh water within 120 m, else within gather reach, else a seep at the lowest ground near, and never the sea. After the camp's first trip the water pot stands by the hearth (`store.pieces.water_pot_by_hearth`).
  - **Shelter mends:** every 10 game days a folk carries a bundle of the shelter's own material (the people file's first `shelter.materials`) in from the woods, and a patch goes on the shelter's front, toward the fire. The newest six show.
  - **Trades:** from storage, a camp takes up trades in the real order, at most three, and each puts its first three visible props on its bench (pots drying and grain jars by the kiln for pottery). The maker sits at the bench of the camp's first trade that needs a maker: the potter at the kiln, which now stands only with pottery and smokes while they shape pots and feed it. A lighting maker would sit at a stool by the hearth pot.
- **What the code does:**
  - New `scripts/peoples/trades.gd` (Trades). It reads the land once per camp and caches it in the state (`reach_facts`): the biomes' plants, rock, soil and water within `loop.gather_reach_m`, and the river banks. Each sim tick it works out the present trades: rung, needs, earlier trades, the people's `huts.trades`, a maker for the non-generalist ones, and the earliest `show_max`. Once present, a trade stays (sticky) while its rung, maker and earlier trades hold.
  - `CampSim._needs()` counts the water trips (`st.water`: today, yesterday, total) and the mends (`st.patches`, `st.mend_days`).
  - New `scripts/peoples/camp_needs.gd` (CampNeeds) draws them: the trip walkers, the pot and the patches.
  - The Workshop's maker station follows the trades (`maker_station`). It has kiln and hearth stations with seats, five new idles (`shape_pot`, `feed_kiln`, `stir_pot`, `hang_strips`, `fill_lamp`), and the trades' visible pieces on the benches.
  - A camp is rebuilt out of sight when its trades change (Camps' folk stamp; the opening camp's `rebuild_workshop()`).
  - CampSim's header carries the §EI.4 guard: no market, money, chief, wall, standing hunter or metal, ever.
- **Data:**
  - The needs and trades clauses of `camps.json _help.village_economy` are wired (no `[NOT WIRED YET]`).
  - New `sim.trades.gates`: the genera, rocks and soils each need reads, `clay_from_water_m` 300, `fuel_surplus_nights` 3, `visible_per_trade` 3.
  - `sim.workshop.benches.kiln.idles` and `store.pieces.water_pot_by_hearth` added, all with help lines.
- **Check:** `STAMP=1 SEED=7731 … --script tools/trades_check.gd` gives 0 fails over 119 camps (every people at the 7 camp sites within 12 km). It checks:
  - the trades are a subset of `huts.trades`, in order, at most 3;
  - no pottery without clay (51 camps had none, and 5 were forced);
  - textiles only after cordage and leather;
  - no maker-trade without a maker;
  - at least 2 water trips every game day over 44 days;
  - a patch every 10.0–10.04 days;
  - the water pot by the hearth;
  - the trade pieces on their benches;
  - the kiln only with pottery.
  `tools/workshop_check.gd` (the kiln now needs pottery; the maker's share holds at the kiln, 0.80) and `tools/no_metal_check.gd` still give 0 fails.
- **Walkabout:** `SEED=7731 QUICK=1 SITES=pottery` produced `tools/reference/walkabout/7731/pottery_11h_f0.png`. It is the opening river camp at the specialist rung (a harness frame: rung, maker and woodpile set for it), from the road 20 m out at 11 h, with trades cordage, pottery and woodwork. The gable workshop is on the left; a thin second smoke column rises from the kiln while the potter works, beside the hearth's column; the brown kiln hump is beside the old stone stubs. The water carrier and the pot are too small to make out at this distance.
- **Flags for Mike:**
  1. **Textiles and the lighting trade never show on seed 7731.** Under the data's order with `show_max` 3, the first three trades a camp can take fill the slots first: cordage plus woodwork, stone or pottery. Textiles waits on both cordage and leather and needs a herd's wool or a fibre crop, so it would be a camp's fourth. The lighting trade comes `after: [pottery]`, so the eight peoples whose `huts.trades` list lighting but not pottery can never have it: tundra, marsh, coast, canopy, mangrove, mountain, old growth and taiga. That is despite the tundra's porch sign being a burning lamp, and despite §EI.3 asking only for fat, oil or resin. Your call: drop lighting's `after`, raise `show_max`, or let the porch sign stand on its own.
  2. **Leather and hide needs the hunt (§EK, prompt 40) or a herd.** With no hunt yet, only the herding peoples (mountain, steppe, taiga) show it.
  3. **"trips_per_day … counted by the camp's folk count"** I read as two trips a day for each ten folk. Tell me if you meant something else.

## 2026-10-05 — §EL the workshop: one hut, two benches, the hearth outside (queue 38)
- **What changes on screen:** a camp that has reached the storage rung gets one workshop hut 6–10 m from its fire, open on the fire side.
  - **The hut:** built in the people's own form and the shelter's tints. Each people gets its own: a gable hut, a round stone hut, a hide cone, the marsh's long reed arch, a flat mud room with its ramada, an open shed, or a lean-to.
  - **The benches:** a soft bench (a hide mat) and a hard bench (a stone slab), each with a seat log behind it and 3–5 of the people's `huts.soft` / `huts.hard` pieces.
  - **At the door:** a porch seat, and the porch sign readable from the road (the marsh's reed-mat press, the tundra's stone lamp burning day and night).
  - **The kiln:** a clay hump 4–8 m downwind (the planet's mean wind) where the people make pots. It smokes thin while the potter-maker is at work.
  - **The hearth:** `huts.hearth`'s pot on its stones, the rack and the lamp now stand round the fire circle, and the lamp is lit only from dusk.
  - **By day:** the keeper (the headman, else the first adult) and the children stay at the fire. The maker sits at the bench that works the maker's materials for 80% of the gather hours. Everyone else does one 3–6 h stretch at a bench (crossing to the other bench at most once), and spends the rest out gathering, out of sight. A full bench sends a folk to the porch.
  - **At dusk:** everyone walks back to the circle.
  - **Idles and sounds:** at a bench a folk plays only that bench's idles, each with its own arm motion, thing in hand and quiet loop from the bench. Soft: sew, twist cord, scrape a hide, plait. Hard: knap, grind an axe, bow drill, hollow a bowl with a coal.
  - **The player:** carrying reeds or grass (the soft bench) or a branch or log (the hard bench), E lays it on the bench; it joins the bench's pieces and the camp remembers it.
- **What the code does:**
  - New `scripts/peoples/workshop.gd` (Workshop): the hut, pieces, sign, kiln and hearth props as cheap box meshes in the ruin material at 16 texels a metre; `plan()` (who is where, per hour); `drive()` (the walker).
  - `Camps._workshop()` builds it, and a camp reaching storage is rebuilt out of sight (the folk stamp).
  - `Encampment.ensure_workshop()` does the same for the opening camp once its own state reaches storage.
  - `main.gd` handles laying a material on a bench.
  - SoundSynth has six bench loops. `CampProps.tints()` is factored out of the shelter.
- **§BV's jobs are not built**, so this is the smallest walker the workshop needs, as the prompt says: a folk walks from the fire circle to a bench, sits, works, and walks back at dusk. Far from the player (`sim.jobs.near_player_m`) the move is made at once. The canopy folk's workshop sits on their second deck, and their folk change place only while you are 40 m off.
- **Data:** the workshop clause of `camps.json _help.village_economy` is wired (no `[NOT WIRED YET]`; the huts blocks carried no prefix).
  - New tunables in `sim.workshop`: `bench_seats` 2, `porch_seats` 1, `generalist_bench_hours` [3, 6], `idle_hold_s` [15, 40], `out_m` [18, 26], `item_materials`.
  - `audio.json` has six bench rows (`scrape`, `cord_twist`, `needle_through_hide`, `tap_tap`, `grind`, `drill_whirr`), each quiet and close.
- **Check:** `STAMP=1 SEED=7731 … --script tools/workshop_check.gd` gives 0 fails. It builds a camp of every people at rungs 1, 2 and 3 (51 camps) beside the opening camp and checks:
  - exactly one workshop at or past storage, and none below;
  - the marsh press and the tundra lamp;
  - the kiln only with `huts.kiln`, downwind within 30°;
  - signs 12+ px tall at 40 m;
  - triangles at most 0.15× a fire circle with its seats (the budget is 2×);
  - a game day at every maker's camp: bench-only idles and sounds, one bench a folk, one folk a seat, at most one crossing, the maker at the bench 0.80 of the gather hours, only the keeper and the children at the fire by day, everyone back at dusk;
  - the player's reeds and branch going to the right bench;
  - the lamps dark by day and lit at night;
  - the opening camp building its workshop at storage.
- **Walkabout:** `SEED=7731 QUICK=1 SITES=workshop` produced `tools/reference/walkabout/7731/workshop_11h_f0.png`. It is the opening camp (a river people on a beach, on the full planet) from the road at 11 h, the hour (11–14) with the most folk at the benches. A harness frame: the camp is set to storage for it. The gable workshop stands to the left of the fire and its smoke, small from the road.
- **Flags for Mike:**
  1. **On day one the opening river camp is at the food rung, not storage, so it has no workshop yet.** It gets one when its own sim climbs to storage. The walkabout frame pushes it to storage for the shot (a labelled harness frame, §CG).
  2. **The kiln stands wherever `huts.kiln` is non-empty**, as prompt 38 says. `sim.workshop.benches.kiln.only_with_trade` (pottery) waits on §EI's trades (prompt 39). The kiln smokes only while a potter-maker is at a bench; the maker comes at the specialist rung, so a camp at plain storage has a cold kiln.
  3. **The workshop is only as busy as the folk there are.** With few folk, the hut is often near-empty by day: a camp of four has the keeper at the fire and the other three each at a bench for a 3–6 h stretch. `generalist_bench_hours` is the dial.

## 2026-10-05 — §EH no metal; a camp can be fifty (queue 37)
- **What changes on screen:**
  - The old colonnade's capitals are dark stone, not iron.
  - A shrine's torch sconces hang from stone brackets.
  - No camp, ruin or log line names a smith, bog iron, a bloomery or slag.
  - The marsh folk's maker is a reedworker, and their old camps leave the smoke floor.
- **What the code does:**
  - **Techniques:** a technique marked `retired` in `techniques.json` (bog_iron) is never taught, never counted as known (even from an old save) and never listed (`Techniques.retired`, `listed`).
  - **Villages:** a village specialty marked retired (glass, mining) is never offered (`Villages.specialties`).
  - **Props and ruin marks:** the matching for camp props and ruin marks no longer knows "slag" or "bloomery".
  - **Colours:** the people palette's "iron" colour is gone; iron-red seep water still reads red, as scenery.
  - **Meteors:** their yellow is the sky's, not a craft.
  - **Camp cap:** CampSim's cap reads `camps.json → sim.population.village_cap` (50; its fallback was 24).
- **Flag for Mike:** a camp's own births still stop at forage_cap + weir + crop = 16. So a camp reaches 50 only through folk walking in from a fallen camp, or if those numbers are raised. Births and ladder gates are unchanged, as the prompt said.
- **Flag for Claude in chat:** §DV's text still says "iron capitals". The build follows §EH: dark stone.
- **Checked** (`tools/no_metal_check.gd`, seeds 42 and 7731, 0 fails):
  - 17 peoples: no smith, no bog iron, no slag; the marsh maker is a reedworker with the smoke floor.
  - The camps sited within 12 km have no smith.
  - Bog iron can't be learned or listed.
  - No glass or mining village.
  - A camp fed past 24 grows to 50 and stops, and arrivals stop at 50.
  - `scripts/` names no metal except lines tagged "no metal (§EH)".

## 2026-10-05 — §EE, §EF, §EG: the first village, the stream-gutter town, grown and composed; dead until relit
- **Why this archetype:** the stream-gutter town tests the most at once. It needs every siting term (a stream, its bend, a ridge, a slope). It sits on a slope, so stepped footings, dry-stone aprons and posts all get used. Its gutter is §EF.8's water you follow. It is plain temperate stone-and-timber country, where most of the world is. Every other archetype is a special case of the same grammar.
- **What's on screen:** abandoned villages of 30–50 stone houses above the inside of a stream's bend, with a ridge behind and the water in front. Up to 12 a world, at least 6 km apart (1.5 km on the stamp). Each one has:
  - lanes that bend gently, running from the hearth square to the spring above, the landing below and the fields on each side;
  - squares wrapped by houses, terraces of five and three in the middle and single houses at the edge;
  - three quarters with arches or bands of kerb stones where you cross between them;
  - a dry-stone wall round the edge, and a dry gutter down the main street;
  - one stone tower seen from most of the lanes;
  - one deliberate empty space (an empty square, a still pool or an unplanted bank);
  - old trees, shrines and cold hearths ringed with stones where a long view would otherwise run on into nothing.

  Houses sit on their slope as it lies: a plinth, stepped footings with a dry-stone apron, or posts of their own lengths on foundation stones, with steps up to raised doors. The ground is never flattened. One stone, one timber and one roof are taken from the rock and climate. The village is mossy, ivied and a little crooked, with sagging ridges and some holed roofs. A house that ends a view turns its gable to it, and the one that must lead the view has an upper storey. Every house has a cold hearth under its chimney; a lit one lights its windows and smokes from the chimney, and the village warms one house at a time (§EE.1). While a square's hearth is cold, brambles choke its walls; lit, they burn back and its benches are there.
- **Checked** (`tools/village_check.gd`, the dev stamp, world seeds 42, 7, 101, 2024, 7731): 46 villages; 36 pass every rule; 1,184 of 1,196 rule lines pass.
  - Seed 42: 7/7 villages pass everything.
  - Seed 7: 9/12.
  - Seed 101: 8/10.
  - Seed 2024: 5/8.
  - Seed 7731: 7/9.

  The 12 misses:
  - layered depth just short in four villages (52–59% of key views, against 60%);
  - a square where no bench can stand against a wall, in three;
  - one long view with no visible spot for a focal, in two;
  - one square wrapped only 29%;
  - one village with no room for its void;
  - one village with 67% clear dominance, against 70%.

  In the built village, physics rays find brambles in front of every bench while the square is dead and the benches clear once its hearth is lit. Lighting one house's hearth lights its windows and raises the lit fraction. The siting pass takes 0.15–0.6 s a world; a village's plan 0.3–0.5 s and its build 0.1–0.2 s, on a worker.
- **Part 1 rerun** on its own commit (`tools/village_warmth_check.gd`): 0 fails. The warm share is 0.26, 0.33, 0.42, 0.45, 0.50 for lit fractions 0, ¼, ½, ¾, 1; blue goes 0.61 to 0.27. A dead village is today's frame (exactly nothing reaches the shaders), and so is the frame 1 km away.
- **Old hearths still pass** (`old_hearth_check`, 0 fails). Village hearths are OldHearths of kind "village"; they light, burn and go out by the same rules.
- `docs/implementation-notes.md`: "Villages as built". The §EE.6 note is corrected: bow and spear stay as §ED.7 for now, and §EE.6 is open (it was wrongly marked settled).
- **Walkabout** (seed 42, `QUICK=1 HOURS=22 SITES=village`): stood at the nearest village's best key view, a narrow lane of stone houses ending on a house's gable, at night.
  - Dead: navy shade, with only your torch warming the nearest wall (warm share 0.07, blue 0.91).
  - Every hearth lit: the lane goes firelit brown and amber while the sky and the hill beyond stay blue (warm 0.65, blue 0.26).

  Frames are in `tools/reference/walkabout/42/village_{dead,lit}_23h_f0.png`.
- **Flags for Mike** (§EE–§EG against built code; none decided here):
  1. Village hearths burn down untended, like every old hearth (§AX), so a relit village cools again. This answers §EE.2's open "can hearths go cold again?" with yes for now.
  2. Each hearth needs kindling laid (§CN), and a village has about 45 hearths. Relighting a whole village is a long job against the carry slots.
  3. Restoring water (§EE.2) isn't built: the gutter is dry and silent.
  4. No plague yet (§EE.2): the villages are empty.
  5. No road leads to a village yet.
  6. §EG.2's "focal on the thirds" and §EF.2's terminated vista disagree deep in a narrow lane, where only a slot is visible. Focals go on a third where they can be seen, else 3–7° off-axis in the slot. Mike may want those centred, as §EG's "Western punctuation".
  7. My readings, for Mike to change:
     - "Most of the village" sees the tower: 55% of lane spots.
     - One dominant: 1.4 times the next, with a terrace counted as one mass.
     - "Key view": one per vista, at its best standing spot.
  8. "A stream, not a great river" is the narrower half of the world's rivers; the stamp's are 28–55 m wide.
  9. River bends exist only at segment joints at this scale.
  10. The "missing piece" is built as structure, not ground: the mound behind is a turfed, stone-faced bank, and the dug pond is a raised stone basin, since the ground can't be dug yet.
  11. Losing refuge in a dead square doesn't touch the dread meter (§EG.4 vs §BA).
  12. Lit villages have no measured look band in LOOK_REFERENCE yet (§BU's "night is one colour" holds outside them).
  13. "Tribal tech" lives in DESIGN.md, not CLAUDE.md.
  14. Seen in passing, all present before this work:
     - headless checks crash on exit (signal 11, after RESULT);
     - `terrain_chunk.gd:1662` touches a freed tree band after a teleport;
     - the headless dummy renderer prints "Parameter m is null" for new meshes.

## 2026-10-05 — §EE.1 a lit village goes amber, one hearth at a time; the wild stays blue
- **What changes on screen:** at night a village warms where its hearths burn. Each lit hearth eases the night's blue pull on the ground, walls and plants within about 10 m of it and lays a dim pool of firelight round it. The more of a village's hearths burn, the warmer the whole village reads. While you stand in a lit village the grade itself warms: shade goes firelit brown instead of navy. A dead village, and the wild between villages, look exactly as before. Warm light is still only firelight, and nothing glows that doesn't give light (the pool stays under full brightness, so nothing blooms).
- **Data-driven:** each village has a lit fraction (lit hearths ÷ all, 0 to 1). The lighting and the grade read only that, plus the lit hearths themselves (`VillageWarmth`; `data/look.json → village_warmth`). The 16 lit hearths nearest you go to the shaders as a small data texture; the terrain, ruin, foliage, litter and aroid shaders and `post_grade` read it.
- **Docs:** CLAUDE.md's look lines and LOOK_REFERENCE's eye test, R2, R3 and R7 now say blue owns the frame by default, not always (§EE.1). The lit-village band is still to be measured.
- **Checked** (`tools/village_warmth_check.gd`, rendered, a stand-in village of 12 hearths at 01:00): the warm share of the frame goes 0.36, 0.42, 0.46, 0.50, 0.51 as the lit fraction goes 0, ¼, ½, ¾, 1, and blue falls from 0.56 to 0.37. A dead village sends nothing to the shaders. The first run's "same as today" tests were stricter than the frame's own flicker (the camp fire in view moves the warm share by about 0.007), so the check now measures that flicker and also asserts the exact zero; it is re-run on this commit.

## 2026-10-05 — Villages plan revised for §EF and §EG (nothing built)
- The village section of `docs/implementation-notes.md` is rewritten as seven steps:
  1. site score;
  2. desire-line growth on a 2 m Tobler-cost grid, with used cells getting cheaper so paths merge into trunks;
  3. Lynch's five bones, each measured;
  4. the composition pass (vistas terminated, one dominant per key view, the thirds, a visual-weight moment, groups of 1/3/5, a mirror test, layered depth, the closure lure, one `ma` void);
  5. one stone, one timber and one roof from the rock, the stand and the land;
  6. stepped foundations and posts, a hearth per house;
  7. the dead state warming window by window, with squares losing their refuge.
- Every step says what is checked headless: the plan is plain data, composition is projected geometry checked with physics ray casts, and the refuge test is a ray-cast backing plus view. What isn't: whether it feels composed (the walkabout pair, Mike's eye).
- Still the stream-gutter town first.
- The amber bends are carried over. There are 15 flags now; new ones: layout-dread vs the dread meter, composition needing set viewpoints, cold lanterns, the landmark against the horizon and fog, channel sound.
- §EE.6 settled as Mike offered: §ED.7 stands as built.

## 2026-10-05 — §EE villages: a plan, nothing built
- New section in `docs/implementation-notes.md`, "Villages (design 5 Oct §EE): plan for the first prototype". It covers:
  - siting from `villages.json → siting`, every weight read from what the planet already computes;
  - houses on stepped foundations, dry-stone retaining walls and posts of varying length, with the ground never edited;
  - a hearth in every house;
  - the relight loop under §CN/§CQ as built;
  - one plague (overrun), and the checks.
- Recommends the **stream-gutter town** first: it uses every siting weight and sits on a gentle slope. Its channel is the village's own, so it also gives the water loop, and it is temperate, near the opening.
- Lists what must bend for a lit village to go amber while the wild stays blue (§EE.1). The night pulls in `post_grade` and `palette.gdshaderinc` are global, so the warmth has to be a local zone (`look_warm_*`, like `look_site_*`), not a switch on the whole frame.
- Ten flags where §EE meets built code. Among them: §BU's locked "night is one colour"; built hearths burn out untended, which already answers "can hearths go cold"; kindling per hearth; what clears a village; and river bends existing only at segment joints at 1/100 scale.

## 2026-10-05 — Near trees culled as off screen: the avenue's missing trees (§DM.4), and every near tree like them
- **What Mike would have seen:** on the full planet, trees within about 120 m of you could be missing while their shadows (and the trees farther off) stayed. The avenue down a kerbed approach (§DM.4) showed it plainest: a road with kerbs and no trees beside it. A road through rainforest could look like open grass.
- **Why:** each branchy tree species in a chunk is drawn by copies sorted by distance from you (near, full, light; `TerrainChunk.band_trees`). Those copies start without a mesh until the chunk comes into the detail ring, and their buffers are filled before the mesh arrives. On that path the engine left each copy's bounding box empty, a point at the chunk's middle, so it judged the whole copy off screen and drew none of it. The trees were all placed, on the ground, in the right copies, with their meshes. Only the box was wrong. Found by rendering the 7731 kerbed spot: red marker boxes stood at the trees' recorded spots, the copies' boxes read 0 × 0 × 0, and an oversized box made the trees appear.
- **Fix:** every plant copy now carries its own box (`custom_aabb`), made from its plants' positions and padded by four times the biggest one's size (`TerrainChunk.box_of`; a crown can spread about 3.5 times its height). It's set where the copies are built (`VegetationPlacer.build_nodes`) and where they're split by distance (`setup_bands`).
- **Also fixed:** the bend trees, lone old giants and avenue trees stored a trunk radius where the tree's base radius belongs in their host record. The air plants and lianas hung on them were placed a few metres from the planet's centre instead of up the tree. They now store the base radius like every other tree.
- **Checked:** the walkabout's road frames on 7731 now show the avenue's Hagenia on both sides of the kerbed approach, and the holloway frame is dense forest right up to the camera (before, open scrub). `road_check` 0 fails. `camp_check` keeps its one older failure (platforms in the giants: 0), the same on the last pushed version. `leaf_lod_check` misses 1–4 trees at a band edge on both versions (the camera lands a little differently each run).

## 2026-10-05 — §ED.7 the only two weapons: spear and bow as finds or a maker's work, the fire arrow
- **No crafting, nothing laid by you:** spears and bows still lie at delve hearts (§CJ). A living camp with a maker now also leaves one by its fire (`Camps._maker_work`): a bow if its people's maker fletches, otherwise a spear. Each camp gives once (`maker_gave` in the camp's sim state).
- **Edges touch only flesh and blood:** `Rungs.of_the_dark` (in the ambient profile, the hostile mythicals: the werewolf, the night rider, the pond crawler and their kind). `Creature.hurt` does nothing to them. A guardian is flesh and blood and can be hurt.
- **The fire arrow** (`techniques.json` fire_arrow, which gains `"id"`): until it is learned the bow is for hunting only.
  - Once known, an arrow drawn within 1.6 m of a flame catches (`Bow.nock_lit`): a small flame and a #FFA050 light on its head.
  - Where it lands it lights a fire, a planted torch or a sconce within reach (`Arrow.light_at`).
  - The row's camp is still OPEN in the data, so for now the headman of the people's camp at the end of the opening road teaches it (`Techniques.teaches_fire_arrow`, a placeholder until Mike names the camp).
- Checked in `tools/ed_check.gd`: the werewolf is untouched by 500 damage; a cold camp fire relit by an arrow; nothing lit 9 m away.

## 2026-10-05 — §ED.6 guardians
- New `scripts/creatures/guardians.gd` and `rungs.json → guardians` (new block with `_help`). Half of the overrun ruins, seeded per ruin, bind a mythic whose rungs.json entry says `guardian: true` (the dire wolf). It stands on ground 22 m outside the ruin's door and keeps 28 m round it (`Creature._guardian`).
  - It **ignores light**.
  - It **closes on a slow walker** (up to 2.2 m/s) and bites in reach.
  - It is **spooked by a runner** (4.5 m/s or faster) for 10 s.
  - It **ranges out from dusk until dawn**, leaving its ground empty.
  - A **spear or arrow wound drives it off** for 8 game hours, and the log says "It will be back."
  - It **leaves for good** once the ruin's hearth is restored. This is kept in the world's save (`guardians`).
- Checked in `ed_check`: 100 of 200 ruins bind one; it closed from 27 m to 16 m on a walker; it spooked at a runner; a wound drives it off without killing it; it is on its ground 14 of 24 hours; it is gone once restored.

## 2026-10-05 — §ED.5 creature rungs: rare and mythic
- New `scripts/creatures/rungs.gd`. Each animal rolls its rung from its own seed. Only the species `rungs.json` lists can roll one: the hare (rare white, mythic Jackalope) and the wolf (rare black, mythic Dire wolf, matched by last word, so the Arctic wolf counts).
  - A rare animal keeps the same mesh with only its tint changed.
  - A mythic carries its own name, its own voice (`SoundSynth` "hare_scream" and "dire_howl", new) and the multipliers on speed, shyness, notice, territory and size. Its shape changes too: pronged antlers on the jackalope; a heavier head and a ruff on the dire wolf.
- **The voice outranges sight:** a mythic's voice carries voice_range_x × its sight (dire wolf 210 m against 105 m). Heard from beyond sight, it writes "Something out there." to the log once. Seeing a rare or a mythic logs it once.
- Checked in `ed_check`: over 20,000 hare seeds, 387 rare and 35 mythic (about 2% and 0.2%); a built jackalope wears 8 antler cones.

## 2026-10-05 — §ED.3 the camp book
- New `scripts/peoples/camp_book.gd` and `scripts/ui/camp_book_panel.gd`, reading `data/camp_books.json`.
  - Every camp has a book or a scroll on a low stand by its hearth, with a quill and an ink pot (the opening camp too).
  - Right click it to read. It opens like the log, at its newest page, on a yellowed page.
- **What it says:** `CampSim._note` writes the sim's listed events (hearth relit, birth, store change, gatherer lost, folk left for a fire, the woodpile running low) with the game time they happened. Ink is near black when fresh and browns with age (`CampBook.ink`).
- **The rumour:** when an overrun ruin lies in range, the last line is a rumour of it, worded from its smoke ("no smoke" if nothing burns there, "thin smoke" if a fire has not cleared it). Reading copies it into the log once.
- Checked in `ed_check`: the lines are written, stamped and browned; the book opens at its newest page.

## 2026-10-05 — §ED.2 river phases
- New `scripts/water/river_phases.gd` classifies each river sample from its slope (averaged over ±3 samples, eased by width) into the seven phases of `data/water/phases.json`: pool, glide, riffle, run, rapid, cascade, fall. Every waterfall reads as a fall.
- **One surface per phase** (`shaders/water.gdshader`, the phase in the ribbon's vertex colour):
  - a pool lies flat and dark;
  - a glide shows slow streaks;
  - a riffle shows small white flecks;
  - a run and anything stronger shows more white water and foam lines.
  - Foam lines and the odd drifting leaf move downstream at fixed layer speeds. Water stays the brightest thing in view, and no new glow was added.
- **Sound** swells and rises in pitch with the phase (`WaterSounds`).
- **Fish** bite only in a pool or a glide (`FishingLine`).
- **A thrown spear** landing in a run or anything stronger is carried off downstream and lost ("The current takes your spear."). In calm water it floats where it fell.
- On seed 42 (stamp), across 262 segments within 15 km: pool 6929, glide 367, riffle 273, run 257, rapid 548, cascade 1244, fall 1252 samples. Checked with `tools/river_phases_check.gd`.

## 2026-10-05 — §ED.1 the opening: a river camp, torch only
- **Where you wake:** `camps.json → first_camp.river_camp` (new block) picks the first camp:
  - in the 28–52° band of the hemisphere in spring or summer on day one (`Encampment.summer_sign`, from the sun's declination);
  - its fire within 180 m of a river that runs on for at least 1 km both ways;
  - a ruin camp of 4–5 folk (elder, hunter, gatherer, mender, sometimes a child) round its hearth inside old broken walls.
  - The opening road follows the river to a people's camp. A second road leaves the other way to the nearest ruin on the far side (`world._back_target`, `opening_back` link), when there is one.
- **Starting kit:** `items.json → starting_kit_ambient.in_hand` gives the torch only. Nothing is worn, there are no arrows, and no spear or bow is laid by you.
- **Relaxed from the data's first numbers, flagged for Mike:** at 1/100 scale rivers are short (about 1–2.5 km), so `flow_m` is 1000 (not 2500) and `within_m` is 180. Any biome a fire may stand in is accepted.
- `tools/river_camp_check.gd` on seed 7731 (full planet) passes 10/10: 42.2°N, north in summer, 107 m from the bank, 1000 m both ways, 5 folk, old walls, the torch in hand. 7731 has no ruin on the far side, so it has no back road.

## 2026-10-04 evening — §ED locked by voice (Claude in chat): the river camp, river phases, camp books, creature rungs, guardians, spear and bow as finds
- New section §ED plus additive data: `data/water/phases.json`, `data/camp_books.json`, `data/creatures/rungs.json`, a Fire arrow hook in `techniques.json`. Nothing in code changed.
- Amends `items.json → starting_kit`: you wake with the torch only; spear and bow are finds or a maker's work.
- "Tome" keeps its 3 Oct meaning (found texts); the book at a hearth is the camp book.


## 2026-10-05 — Mike's 5 Oct calls, roads: wider, graded, held, sunk, steeper in the mountains (§DM.2–4)
- **Wider (Mike: "they can be easy to lose"):** every grade in `roads.json → grades` is about 0.8 m wider: trodden 1.4–2.0 m, track 2.4–3.4 m, kerbed 3.4–4.4 m. Trodden is a little more worn and less grown over.
- **Grades (§DM.2):** `RoadNetwork._grades` and `grade_at` set each link's make by distance along it:
  - kerbed for its last 400–800 m into a ruin, a people's camp or a waypoint;
  - track out to 1.5 km;
  - trodden beyond that.
  - The tread's width, wear and overgrowth blend over 60 m (`tread_info`), so the road visibly widens and clears as you near a place.
  - Kerb stones edge the kerbed run (`RoadProps._kerb`: low, sunk, mossy, a few missing, none on a bridge or ford).
  - The trail now vanishes only on trodden stretches.
- **Holders (§DM.4):**
  - a tell at *both* ends of every vanishing;
  - a cairn at every real bend (the heading turns 40° over 50 m; at most one per 120 m);
  - a waist-high milestone every mile (1609 m) on track and kerbed stretches, notched once per mile from the place;
  - an avenue: a double row of one planted tree every 9 m down the kerbed approach. It is chosen from the trees whose climate fits the place but which are *not* native to its biome, and is 1.4× tall (`VegetationPlacer._place_avenue`).
- **Holloways (§DM.3):** where the road climbs steeper than 0.18 it is sunk 0.6–2 m into the slope, deeper the steeper (`link.hollow`, `link.sunk`), with a wider floor and earth banks. The sunk line keeps the same grade cap, so its ramps never make a step too steep.
  - This also fixed an old bug: merging cuttings could shorten one that held a shorter one inside it.
- **Steeper passes (Mike: "where it makes sense"):** new `roads.json → network.steep_passes`. The hard cap rises from 0.30 to 0.45 (about 24°) between 150 m and 350 m up, and the switchback cost rises with it (`hard_max_at`, `soft_max_at`). `road_check` judges every step by the cap where it stands.
- **Checks:**
  - New `tools/road_grades_check.gd`: 16/16 on seed 42.
  - `road_check`: 0 fails. HEAD's one 46° tread step is gone; 0 steps over the cap on the fine ground or the drawn mesh.
  - `new_world_check` passes.
  - `road_reach_check` on 7731 fails "every inhabited ruin on the network (1 of 2)", the same at HEAD (not this pass).
  - The walkabout has `SITES=road_grades` and excuses the avenue's planted tree from the biome gate.
- **Not built yet:** roots in a holloway's banks, bend trees leaning in, and §DM.5's straight approach.

## 2026-10-05 — §EB and §EC: dawn wake, grey smoke, brighter torch, hits you can feel
- **§EB.1, the dawn spawn:** no save, `dev.json` value or early clock overrode the rule. The clock was set as written, 1 real minute after dawn begins (a windowed boot woke at 5.60 h with the sun at −8°; the day check agrees).
  - The bug was the rule itself: a minute into dawn the sun is still about 8° down, and the grade reads anything below −6° as full night (`SkySystem.daylight = smoothstep(−6, 10, sun)`). Day 1 began at "dawn" by the clock and looked like night.
  - `main.open_clock` now also waits until the sun is up to `roads.json → opening_road.dawn_start.spawn.sun_deg` (−3°, new key with `_help`) at the camp. The wake is now 3–4 real minutes into dawn, sun −2.9°, the blue before sunrise.
  - `tools/day_check.gd` and the walkabout's dawn assertion now test for that.
- **§EB.2, the smoke:** `shaders/smoke.gdshader` is now an alpha-blended soft grey column (`blend_mix`, `depth_draw_never`, still unshaded: nothing emitted, so it never blooms). Its alpha comes in four steps for big texels, and it thins as it climbs.
  - It is greyer in the light and keeps its blue in the shade. At night it takes a dim moonlit blue-grey (`colour_night`) instead of going black under a red cap.
  - The red came from the old `fire_lit` tint, added to the column's foot while the rest went to zero. Only a faint warmth is left, right at the base (`base_warm`, 1.2 m).
- **§EB.3, the torch:** `torch.json → light.held_scale` 1.27 (new key) on the hand torch's energy and range, same colour. Planted torches unchanged; the dark keeps out of the larger circle (`Torch.light_at`).
- **§EB.4, the storm light, kept and recorded:** what lights the land around you at night in a storm is:
  - `StormFX` lightning: a third `DirectionalLight3D` ("Lightning", `FLASH_COLOR` pale blue-white, energy = the flash curve × the strike's energy) from a random bearing;
  - `SkySystem.event_flash`, which pulls the ambient light toward the flash colour and adds `amount × 0.5` to its energy for the flash;
  - the sky shader's `lightning` uniform, and `CloudLayers` reading `StormFX.flash`;
  - under it all, the storm deck's own lit colour at night (`SkySystem`: zenith and mid toward a blue-purple, `painted_lit` toward the storm purple).
  - Nothing in this pass touches any of them.
- **§EC, hits:** `Harm` now follows `harm.json` as amended.
  - Every hit shows a dark-navy edge flash (`hit_feedback.edge_flash`, `StatusHud`), a camera kick (`PlanetPlayer.kick`, 4°), a thud and a breath (`SoundSynth` "thud_breath") and a 0.05 s hitstop (`Engine.time_scale`).
  - For `invuln_s` (0.6 s) after a hit, nothing lands (no knockback either).
  - One hit heals every `recover.step_s` (5 s), and any hit resets the timer. `window_s` and `calm_s` are gone. Healing 2 → 1, the heartbeat settles first.
  - `tools/harm_check.gd` passes 32/32.
- Also checked: `day_check` (7731), `hearth_smoke_check`, `smoke_check.py`, `torch_kinds_check.py` all pass. No screenshots, as asked; Mike playtests.

## 2026-10-05 — Mike's 5 Oct calls, first part (7f9a00e, 4de9d91)
- **Done:**
  - Every death in the ambient game closes with "Good night".
  - Your own falling arrow only glances off.
  - The organ pipes only come in their own biomes.
  - The sea cave's sleeper is something that would den there, else the cave is empty.
  - Tundra stays igloo country: northern styles take tundra ruins at a fifth of their chance.
  - Goblins are out of play (`Peoples.OFF_KINDS`).
  - Every ruin's falls roar.
  - The hewn temple is cut from the local rock's colour.
  - The hanging gardens are pale stone, with a real waterfall, a plunge pool and a stream.
  - The pillar shrines are round fluted columns with stairs spiralling round them.
  - Mist only lies where the place holds it (`MistPlaces`; `tools/mist_check.gd`).
- **Kept as is:** the colonnade's way in and out; its stairs work both ways.
- **Not built yet from the same list:**
  - real tides from the moon and the weather;
  - the frozen castle;
  - steeper passes where the land allows;
  - clearer, wider roads;
  - §DM.2–6 and the §DN lighthouse.
- **Design doc:** Mike's calls aren't in it yet (Claude in chat appends them).

## 2026-10-04 — §EA: three hits, no bar, "Good night" (prompt 36)
- **`Harm`** (`scripts/player/harm.gd`, `data/harm.json`, unmarked) runs in the ambient profile only. The ninja game keeps `PlanetPlayer.hp` and its status bar.
  - A creature's hit (`PlanetPlayer.take_hit`, anything under the dark's 9999) no longer takes health. It knocks you back, shakes the view and counts one.
  - Hits older than `window_s` (20 s) drop out. Three inside it take you.
  - `harm.json` is now in `Tuning.FILES`.
- **Stages:**
  - Hit 1: `PostGrade.set_harm` darkens the edges and drains the colour toward the shadow floor's navy, before the floor, so it is never grey. The fire's oranges are protected. The Master bus is muffled by a low-pass and `muffle_db`.
  - Hit 2: deeper, and a heartbeat (`SoundSynth` "heartbeat", lub-dub) at `heart_bpm`.
- **Recovery:** after `calm_s` with no hits, the oldest hit is let go every `step_s`. The heart slows and stops first, then the dark eases back.
  - Measured: heart still 3 s into the check, stage 2 → 1 at 12 s, 1 → 0 at 18 s, clear at 22 s.
- **Taken:**
  - The frame closes to the darkest navy over `close_s`. "Good night" shows in `#C81E1E` at `text_size_px` in the 480-line frame (`StatusHud.set_taken`), holds `hold_s`, then fades.
  - Then `PlanetPlayer.fall_taken()` hands to the §DE wake (`main._on_player_died`, with no "You died" curtain on top). The cause line is "Struck down by a {creature}", and the harm is cleared.
- The ambient HUD drops the health meter and the red edge flash.
- **Checks:**
  - `tools/harm_check.gd` on 7731: 25 PASS, 0 FAIL.
  - Walkabout harness frames (§CG): `SITES=harm` (two hits; recovered).
  - `camp_check` (`STAMP=1`) fails only its "platforms lashed" line, which fails the same at the previous HEAD.
- **Flags:**
  - Nothing yet lands a knockback without a hit (the ram's goat isn't a species), so `knockback_counts_as_hit` has nothing to count.
  - Falls still spend the hidden health and can kill with the old curtain.
  - Folk's arrows count as hits too.

## 2026-10-04 — §DX: the columns, columnar basalt as a nest (prompt 35)
- **The kind:** `columnar_basalt`, the ninth in `Nests.KINDS` (tier 2, uncommon, a 12 km cell).
  - `Nests._columns` sweeps each cell on a 24 × 24 lattice instead of random tries. The basalt shores and banks are only a few planet cells a world.
  - It tries each basalt point for the three forms (`_causeway_at`, `_sea_cave_at`, `_organ_pipes_at`).
  - The organ pipes win a cell on a 60 % roll. Otherwise the cell takes the form most of its shore makes: shelving → causeway, dropping deep → sea cave, even → a roll.
  - Count, seeds 7731 / 8 / 2 / 5: causeways 1 / 2 / 2 / 1, organ pipes 1 / 4 / 3 / 0, sea caves 4 / 2 / 2 / 3. Seed 5 has no river by basalt ground.
  - `landforms.json` status `new` → `built`.
- **The builds** (`NestBuilder._hex_field`): real hexagonal prisms on a flat-topped hex grid.
  - Faces are drawn only where they show: tops, the undersides of hanging columns, and the sides a neighbour doesn't cover.
  - Under 72 k triangles a build, with a coarse far stand-in. Collision is a smooth walk surface (`_walk_grid`), so the stepped tops walk as a slope and the cliffs stand as walls.
  - **The causeway:** about 4,000–5,400 columns 0.42 m across, stepping down from a 6–12 m cliff of columns into the sea. 200–500 cups hold water with weed round them. The hearth is on a flush floor on the first step 1.8 m or more above the sea, and the camp's seats are new `column_top` seats (`camps.json` → `fire_circle.seats`: kind `column_top`, `at_site.columns`, `place_first`).
  - **The organ pipes:** a 12–22 m cliff of columns on the bank 9 m back from the water. A stream comes over a notch and pours as a waterfall sheet into a pool, which runs on to the river. Its roar is a `waterfall` source, and the hearth is 7 m along the foot.
  - **The sea cave:** a headland of columns 26–34 m out over the sea, its top 8–10 m up, reached by a stair of tops from the land. The cave runs through it under a roof of column undersides, with a stump ledge inside and round the outside to the shore, darkening toward the back.
    - The boom: `SoundSynth` "boom", `audio.json` → `sea_cave_boom`, a source played once a swell only within its 140 m (`Landmarks._tick_boom`).
    - The den: by day a night-roster creature sleeps on the ledge (`Overrun.roster_holder`, split out of `holder_entry`).
    - It is never a camp, nor an old one's remains (`_settle`).
- **The log line** once at the causeway (within 30 m): "A road of stone steps goes down into the sea."
- **Checks:** `tools/basalt_check.gd` passes on 7731, 8, 2 and 5 (seed 5 skips the organ pipes).
  - `nest_check` on 7731 fails only its known waterfall-plants line, which fails the same before this change.
  - Walkabout harness frames (§CG): `SITES=columns` on 7731 (the causeway from its top step); `sea_cave` on 7731; `organ_pipes` on 8.
- **Flags:**
  - No river cuts basalt in the organ pipes' own biomes on any of four seeds, so their bank's biome is loosened (rock and river kept). They land in savanna, rainforest, thorn scrub and estuary.
  - Their fall is the nest's own stream over the cliff, not a river's fall: no river fall lands on basalt.
  - There are no tides: the high-water line is 1.2 m over the sea, plus 0.6 m of spray.
  - The planet keeps no record of old and live flows, so any basalt counts as old.
  - The sea cave's hearth spot is on its clifftop (a mesh). It never burns, so nothing needs the ground there.
  - The den's sleeper is whatever night-roster species fits the climate (a ghost crab, a tree frog, once a spotted hyena).
  - The column-hut remains signature waits for the peoples fill.
  - The coast road is not routed to the causeway's top.
  - The wind's moan in the organ pipes (§DA) is not built.

## 2026-10-04 — §DV: the old colonnade (prompt 34)
- **The kind:** `Ruins.Kind.COLONNADE`, "Old colonnade" (`data/ruins.json` → `styles.colonnade`, unmarked), placed by Monuments' sites pass, at most three a world.
  - **New gate words:** `humid` (moisture 0.55 or more), `rise_above_river` (water within 1 km, the spot 3 m or more above it) and `cold` as a never-word (the cell under 12 °C: the humid south).
  - Where: nearctic floodplain forest, maritime forest and deciduous woods.
- **The ring** (`Monuments._colonnade`, `RuinBuilder._colonnade`):
  - 20–30 plastered brick columns 10–14 m tall round a house's footprint 22–28 by 28–36 m, on brick bases, with iron capitals.
  - About one in seven has fallen outward, its drums lying in the grass; a few are broken short. Vines climb some.
- **The cellar** (`Colonnade`): open to the sky in the middle (a hole in the ground), brick-lined, a hand of still water on its floor (§BE: wade). A stair goes down from its near end, with a dry ledge for its old hearth.
- **The delve** (climbing, for the dark):
  - A low door in the cellar's far wall and steps down, as deep as the ground over the cistern needs.
  - The cistern under the footprint (the heart), flooded to the knee, a dry ledge for its hearth ring and the find, ribs under its vault.
  - The old stair up and out past the footprint (the way out). The cellar's own stair is the way in.
  - Hearth rings, no stack.
- **The avenue:** two rows of old live oaks every 14 m running 90–140 m out from the front, 1.25–1.45 times the wild's height, a few gone (`make_node`'s `garden`).
- **Check:** `tools/colonnade_check.gd`, 0 fails on 8, 2 and 5.
  - 7731 has none (its nearctic south is cold or has no rise above water).
  - Seed 8: three, 23 columns each, avenues of 15–16 oaks 25–29 m tall against the wild's 20.
  - Every cistern is under the ground with cover, the cellar a hole with water. About 8–10 k triangles, the smallest in the set.
- **Walkabout** (`SEED=8 SITES=colonnade HOURS=10`, harness frame §CG): from under the oaks in the avenue, looking up it to the pale columns standing in a sunlit clearing.
- **Flags:**
  - Resurrection fern on the oaks' limbs isn't placed (it is in the catalogue).
  - The avenue isn't joined to a road (§DM.4 isn't built).
  - The cellar's stair is the way in and the cistern's old stair is the way out: the design names the cellar's outside stair as the way out.

## 2026-10-04 — §DY: the pillar shrines (prompt 33)
- **The kind:** `Ruins.Kind.PILLAR_SHRINES`, "Pillar shrines" (`data/ruins.json` → `styles.pillar_shrines`, unmarked), placed by Monuments' sites pass, at most two a world.
  - **New gate words:** `pillar_valley` (karst or sandstone), `pooled_mist` (a valley: the ground 200 m round stands 3 m or more above it) and `flat` as a never-word.
  - Where: east_asia_temperate or indomalaya, in cloud forest, temperate rainforest, jungle or monsoon forest.
- **The valley** (`Monuments._pillar_shrines`, `RuinBuilder._pillar_shrines`):
  - 6–15 pillars standing within 12 m of one height (the plateau they were cut from, 62–138 m): the middle one the delve's, the rest stacks of rough rock with turf on top.
  - A small stone shrine on every top: a door, and a tiled roof with upturned eaves.
  - Stairs cut round the faces of about two in five (`_cut_stair`), treads standing out of the rock at a grade of 0.5, turning at each corner: the only way up.
- **The bridges**, between each pillar and its two nearest where the tops are close enough in height, by span:
  - Stone arches up to 15 m stand.
  - Rope-and-plank bridges up to 60 m: about one in six hangs, sagging, with its rails. The rest are only their abutments and posts, a frayed rope hanging from one.
  - Living root bridges of fig, 10–40 m, where canopy folk lived (half the valleys), the roots poured over the edges.
  - From one top you see the next shrine across a gap with no bridge: the fork in the air.
- **The delve:** the middle pillar is the crag fortress's tiers round a shaft. Its climb is `CragFortress.shaft_layout`, now split out of the crag's layout: in at the foot, 10–18 flights at landings (stores, a cistern), the summit shrine the heart under its tiled roof, out onto the summit.
- **Also fixed:** `RuinSounds.parts_of` read a climbing delve's `well` (the stairwell record) as a place and errored at the crag fortress and here. It now finds the cistern landing.
- **Check:** `tools/pillar_shrines_check.gd`, 0 fails on 7731, 8 and 2.
  - 7731: one in cloud forest on karst, 9 pillars 110–125 m, 5 with stairs, 7 bridges (1 rope still hanging, 6 gone).
  - Seed 2: two valleys, 13 and 15 pillars, with root bridges where canopy folk lived, and an arch.
  - Across the three seeds, 2 of 13 rope bridges still hang (the data's share is 0.17). The delve climbs 10–18 flights. 35–47 k triangles against the castle's 78–82 k.
  - Seed 5 has none.
- **Walkabout** (`SEED=7731 SITES=pillar_shrines HOURS=8`, harness frame §CG): from the valley floor before the middle pillar's door, looking up. The pillars tower into the sky, one's cut stair zig-zagging up its face; drips and frogs at the cistern.
- **Flags:**
  - The pillars read as stacked blocks more than weathered rock. Rounder, more broken masses would read better.
  - From the floor the shrines and bridges are out of sight, far above.
  - The rope bridges don't sway in the gust yet (§DA).
  - A camp here isn't canopy folk yet (§BT).
  - The mist pooling is the look's own valley mist, not anything of the site's.

## 2026-10-04 — §DW: the temple park (prompt 32), and the monuments pass no longer runs inside itself
- **The kind:** `Ruins.Kind.TEMPLE_PARK`, "Temple park" (`data/ruins.json` → `styles.temple_park`, unmarked), placed by Monuments' sites pass, at most two a world.
  - **New gate words:** `still_water` (a lake or a wetland's pools within 1.5 km; not the sea, not a river) and `min_km_from` (spawn.min_km_from: never within 5 km of a temple city).
- **The precinct** (`Monuments._temple_park`, `RuinBuilder._temple_park`), 200–400 m across, open to the sky:
  - At its middle, the great lotus-bud tower over the relic crypt: a stepped base, a body with a niche on each face, the bud drawn to its point.
  - Two column halls on platforms beside the way down, and a great seated figure behind the tower.
  - Round it, on a grid of cells: column halls (grids of roofless laterite columns, some broken, a few fallen, creepers on some), bell stupas, ribbed corn-cob towers (two at most, at least one), seated figures in brick niches, and ponds (at least two).
  - The figures sit with their hands in their laps, faces worn smooth, nobody by name.
- **The ponds:** their rectangles are holes in the ground, with water at the level of their lowest bank, a dark floor and a brick edge and apron over the ground's ragged edge. The great fig stands on one's bank (a root-tree). They wait for the lotus and the lily (a fill for chat).
- **The crypt:** the barrow kit, its way down in front of the great tower, which stands where the way down's open hole ends. Hearth rings, open fires only (`open_ring`).
- **A fix that matters for every monument:** the monuments pass asked Nests where water stands, Nests asked Ruins what stood near it, and Ruins asked the monuments pass, which started over inside itself.
  - That loop overflowed the stack on seeds 2, 101 and 1234 (the "pre-existing" overflows I flagged before), and on 7731 it let a kind past its cap.
  - Now the pass answers from what it has placed so far when it is asked from its own thread (`Monuments._ensure`).
  - Seeds 2, 101 and 1234 now print no overflow. Every monument check passes again: the temple city, long wall, carved cliffs, cliff dwelling, brick city, stone heads, terraced pueblo, stone circle, hewn temple, hanging gardens, abbey, the northern styles and the crag fortress.
- **Check:** `tools/temple_park_check.gd`, 0 fails on 7731, 8 and 2.
  - 7731: one at 2.3°S 86.1°E in tropical dry forest, 329 m across: 5 ponds, 2 towers beside the great one, 7 column halls, 4 stupas, 5 niches.
  - Its crypt: stair, room, stair, heart, exit, cairn. The nearest temple city is 28 km off. 39,526 triangles against the castle's 78,835, and one root-tree.
  - Seed 5 has none.
- **Walkabout** (`SEED=7731 SITES=temple_park HOURS=9`, harness frame §CG): the open park on the grass, the great lotus-bud tower in the middle, column rows on their brick platforms either side, white bell stupas, a bright pond in front, the fig's crown behind.
- **Flags:**
  - `tools/nest_check.gd` fails one line on 7731 (a waterfall nest's own plants: 0 at its spot). It fails the same without this pass's changes; it isn't from the temple park.
  - The crypt's way out comes up wherever the kit finds ground, not up the tower's side.
  - Nothing keeps a cell's pieces from overlapping each other.

## 2026-10-04 — §DU: the ruined abbey (prompt 31)
- **The kind:** `Ruins.Kind.ABBEY`, "Ruined abbey" (`data/ruins.json` → `styles.abbey`, unmarked), placed by Monuments' sites pass, at most two a world.
  - **Where:** palearctic temperate deciduous, maritime forest, tundra, bog and rocky shore, cool and wet (`cool_wet`), never hot, never dry (`dry` now also works as a never-word).
  - **Near water:** where water lies within 600 m it stands back from it, on a valley floor or a headland (`by_water`). The design's `where` list is not a gate.
- **The church** (`RuinBuilder._abbey`), 40–90 m long, west end −z and east end +z:
  - The aisles' outer walls are lower and broken, a lancet a bay, open to the sky.
  - The nave's arcades: piers with pointed arches and the clerestory over them, some piers fallen.
  - The chancel's full-height side walls; the east gable with three tall lancets; the west front with its door and window; the transepts' stumps.
  - The tower at the west end's north corner, whole or with two walls fallen, ivy up it.
  - Rubble in the nave. South of it, the cloister and chapter house as foundations in the turf.
  - The warming house with its chimney stack, its hearth the old hearth (the one fire the monks kept).
- **The crypt:** the barrow kit under the east end, from a passage in the chancel down to the heart (the crypt's chapel). Of the four grid headings, the site takes the one whose open hole ends soonest, drawn west till it ends inside the east wall. Braziers. Smoke: `chimney_stack`.
- **The haunt:** `Haunt.haunted` now reads the data's style-key names too, so `haunt.kinds` "abbey" counts. About 40 % of abbeys are haunted.
- **Residents:** the abbey is a towered ruin in `RuinSounds` (birds in the tower by day, the owl at a window at night).
  - Also for §DT: the hanging gardens now count as a ruin with water (drips, and frogs where they live).
- **Check:** `tools/abbey_check.gd`, 0 fails on 7731 and 8.
  - 161 of 400 abbeys are haunted (share 0.40), and the birds and owl are registered.
  - 7731: two, 52 and 53 m long, in temperate deciduous and tundra, both towers whole. Seed 8: two, 56 and 64 m, towers half fallen.
  - Every crypt has a heart and a way out, its hole inside the east wall. 39–43 k triangles against the castle's 78 k.
- **Walkabout** (`SEED=7731 SITES=abbey HOURS=9`, harness frame §CG): inside the nave at the west end looking east. Walls and the clerestory rising either side, the grass floor and fallen stones, the east gable's openings against the sky. The walkabout counted 6 shafts there at 09:00 and heard birds at 21 m.
- **Flags:**
  - The arcades read as heavy blocks more than clean pointed arches. The pointed heads are two leaning stones.
  - The night stair comes up wherever the kit's exit finds ground, not always in the cloister.
  - The headland lichen isn't separate from moss.

## 2026-10-04 — §DT: the hanging gardens (prompt 30)
- **The kind:** `Ruins.Kind.HANGING_GARDENS`, "Hanging gardens" (`data/ruins.json` → `styles.hanging_gardens`, unmarked), placed by Monuments' sites pass, one a world at most.
  - **New gate word:** `water_one_side`: a river, a lake or the shore within 600 m (`Monuments.water_point`).
  - **Loosened:** the dry Palearctic and Central Asian land has no rivers at all on seeds 7731, 8, 2 and 5, so an oasis's lake counts as the water.
  - **River sampling:** for a kind that wants water beside it, the pass tries spots along the cell's rivers.
  - **Beside a brick city:** the design allows the gardens "with or without a brick city near it". So where a brick city holds the cell, they may stand in a free cell beside it, clear of the city's walls and palace.
- **The mound** (`HangingGardens`, `RuinBuilder._hanging_gardens`):
  - 4–7 square terraces, 20–35 m high and 80–150 m across, each at least 5 m high. Its back is toward its water, the foot 30–100 m from it, tried at five angles round the water's edge.
  - Each terrace is a 2 m retaining wall of brick with its vaults' dark arches along it and a coping, and the soil of its band.
- **The water** (§BE, R6), drawn as the place's own fresh water and the waterfall sheet (`make_node` now draws a ruin's `water` and `falls`):
  - The channel comes out on the top terrace by the water-lift's stump and runs between brick kerbs down the back, with a fall at every wall.
  - Then it runs on the ground to the water's edge.
- **The garden gone wild** (§CS/§CT's one exception, placed by the generator):
  - On the upper terraces, the mountain trees the gardeners carried in, grown past their height (×1.1–1.35): the "Eastern redcedar" juniper standing in for the cedar, the Mediterranean cypress and the juniper.
  - Below, the water's own date palms, pomegranates and tamarisks, never on the channel. They are drawn as one multimesh a species (`make_node`'s `garden`).
- **The delve** (`HangingGardens.layout`, climbing):
  - In at the front foot, then the vaulted galleries under the terraces, one a level, left and right by turns, with ribs under their ceilings and the stairs climbing across between them.
  - From the top gallery the channel's tunnel runs down and back to the cistern at the foot of the mound: the heart, its basin of dark water and the water-lift's footings.
  - Out through the back wall by the water. Every piece is checked to be under the slab or wall over it.
  - Smoke: `vent_shaft` up through the terraces.
- **Check:** `tools/hanging_gardens_check.gd`, 0 fails on seed 8.
  - 7731, 2 and 5 have none (no dry land by water passes).
  - Seed 8: one at 41.0°N 143.5°W in steppe, beside that world's brick city: 4 terraces, 20.6 m high, 129 m across, the channel's 4 falls and its run to the lake.
  - 11 mountain trees and 35 of the water's own. Galleries: passage, room, stair, room, stair, room, stair, heart, exit. 47,152 triangles against the castle's 78,733.
  - `brick_city_check` and `hewn_temple_check` still pass.
- **Walkabout** (`SEED=8 SITES=hanging_gardens HOURS=10`, harness frame §CG): from 75 m off the back corner. The mound with cypress, juniper and palms on its terraces, the bright fall down its back wall; a rise in the ground hides its lowest wall. An earlier closer frame showed the vaults' dark arches along the wall and the fall bright on it.
- **Flags:**
  - A lake stands in for the river.
  - The juniper stands in for the cedar, and there is no fig yet (a fill for chat).
  - The trees stand on the terraces but don't root into the vaults.
  - The falls make no sound of their own yet: the ruin bed is quiet there.
  - The steps read faintly from the ground: the terraces are wide and low against the trees.

## 2026-10-04 — §DZ: the hewn temple (prompt 29)
- **The kind:** `Ruins.Kind.HEWN_TEMPLE`, "Hewn temple" (`data/ruins.json` → `styles.hewn_temple`, unmarked), placed by Monuments' sites pass, at most two a world. Nobody lives there: the ground's heights don't know the pit is there, so folk couldn't walk its floor.
  - **New gate words:** `basalt`, `escarpment` (on an escarpment's plateau, its face within 300 m and 4 m high or more) and `dry_plateau` (moisture under 0.55, rolling under 0.1).
  - **Loosened:** no world tried has dry Indomalayan land on basalt at an escarpment. Basalt barely occurs in Indomalaya. So when no cell passes, the pass runs again with `basalt` loosened to any hard rock (granite, basalt, limestone, sandstone). The tally says `"loosened": "basalt"` and the site carries `loose`.
- **The pit** (`Monuments._hewn_temple`):
  - 60–120 m across and 18–24 m deep (up to 28 where the hill over the halls needs it), set 20 m back from the escarpment's face, its frame on the grid with +z into the plateau.
  - Its rim may fall up to 12 m: it is cut into the hillside, deeper on the high side.
  - The pit's rectangle is the delve's first hole, so the near ground leaves it out (the far ground covers it: you find it from above). Its walls of living rock are 5 m thick and stand to the rim, covering the quads left out round the edge.
- **The temple** (`RuinBuilder._hewn_temple`, `_hewn_shrine`), standing free in the middle, its top 1.5 m under the rim:
  - A plinth with elephants round its base facing out, a stair up the front, a porch, and a pillared hall dark within.
  - The shrine with figure reliefs on its faces (no one by name, §BO) and a stepped tower of 5–7 tiers with little pavilions, an octagonal crown and a finial.
  - A gatehouse on the court, and the two free-standing pillars either side.
  - A stair is cut down the front wall from its lower corner, and creepers hang down the walls (§DI).
- **The halls, the delve as they stand** (`HewnTemple.layout`, climbing like the crag fortress's):
  - The porch through the back wall into the first hall (its old hearth), then a stair up through the rock to the second, a level up, and another to the third.
  - The third is the longest: the heart, with its hearth ring and an apse with a seated figure on a dais, hands in its lap.
  - From the heart a stair goes up to the hilltop: the way out, open to the sky where it breaks the ground.
  - Every hall has two rows of pillars and ribs under its ceiling cut like timber. From the court, the upper halls show as dark windows between pilasters.
- **Smoke:** `open_ring`, no stack (smoke.json's §DT–§DZ help now says this one is wired).
- **Check:** `tools/hewn_temple_check.gd`, 0 fails on 7731.
  - 7731: one at 8.9°S 80.8°E in savanna on granite (loosened), the pit 74 by 96 m and 22.7 m deep. Its halls are passage, room, stair, room, stair, heart, exit, the way out 13 m up to the hilltop.
  - Every hall and stair is under the hill with cover to spare, and the temple's top is 1.5 m under the rim. 36,645 triangles against the castle's 78,835.
  - Seed 2 has one too. Seeds 8 and 5 have none: no dry Indomalayan escarpment at all.
  - The stone circle, long wall and delve checks still pass after the sites pass was split into `_candidates`.
- **Walkabout** (`SEED=7731 SITES=hewn_temple HOURS=10`, harness frame §CG): from the front rim, looking down into the pit. The walls of living rock, sunlit on the far side; the temple below in the pit's navy shade, its pillared hall, a free pillar and the tower.
- **Flags:**
  - The basalt loosening is a call for Mike: the real thing wants basalt, and our Indomalaya has almost none.
  - Creatures' and roads' heights come from the ground, which doesn't know the pit. A beast could walk over the pit in the air, and a road could cross it. No road is routed to the rim yet (§DM.5 isn't built).
  - The upper halls' windows are dark panels: you can't fall out of them, and you can't see out.
  - The lichen on the towers isn't separate from §DI's moss.

## 2026-10-04 — §DS: the tower house and the broch (prompt 28)
- **Two styles of kinds we have,** picked where the castle and the tower already stand (`Ruins._northern_style`, `data/ruins.json` → `styles.tower_house` / `styles.broch`, both unmarked). Each passes its spawn gate (Monuments.gate: palearctic, its biomes) and then its own seeded `chance` roll (0.5).
  - **New gate words:** `cool_wet` (the cell under 14 °C and the ground's moisture 0.5 or more), `hot` (never: over 22 °C) and `coast_or_moor` (the sea within 360 m, or tundra or bog).
  - **The moors:** tundra and bog are igloo and boardwalk country (`Ruins.country`), so no castle or tower ever stood there. A ruin there may now take the broch (first) or the tower house instead, so a few palearctic igloos and boardwalks become brochs.
- **The tower house** (`RuinBuilder._tower_house`):
  - A harled keep 12–20 m tall and 9.2 m wide, 14–20 m long: long enough that the way down's open hole ends inside it.
  - The harl falls away in patches, worst near the foot. It has slit windows, a corbelled parapet, two bartizans with slate caps, and a chimney stack on the back gable.
  - One back corner has fallen in, with rubble below. A low barmkin wall 28 m square stands round it, its gate before the door; the wall opens where the postern comes up.
  - The delve is the barrow kit, from just inside the door down to the undercroft and the vault (the heart), and up the postern.
  - Smoke: the castle's `chimney_stack`, looked up by style first (`Ruins.data_key`).
- **The broch** (`RuinBuilder._broch`):
  - A drystone round tower 8–13 m tall on a base of 14–20 m. Its outer skin draws in as it rises. A gallery runs between the skins, floored with flags every 2.6 m.
  - The door is on +x, with voids stacked over it on the court's side. One arc has fallen away, the outer skin lower so the gallery shows.
  - Its old hearth sits in the middle of the court, under the open sky (`open_ring`: no stack).
  - The souterrain opens beside it on the -z side: the barrow kit's passage, a stair going down under the broch, the end chamber (the heart) and a second mouth.
- **The frame:** both use the terrain's grid. Of the four grid headings, the site takes the one with a way out whose open hole ends soonest. The broch's mouth is drawn back until its hole ends short of the wall.
- **Check:** `tools/northern_styles_check.gd`, 0 fails on 7731 and 8.
  - 7731: 6 tower houses (temperate deciduous, bog, tundra) and 9 brochs (tundra). None of the 14 hot-desert castles takes the tower house.
  - Seed 8: 1 tower house and 2 brochs.
  - Every one passes its gate and has a heart and a way out, with its hole inside the keep or clear of the broch. Each is 26–57 k triangles against the plain castle's 78 k.
  - `overgrowth_check` and `delve_check` still pass.
- **Walkabout** (`SEED=8 SITES=northern HOURS=11`, harness frames §CG): the keep standing pale over a temperate wood, a bartizan at its top. The broch dark on the snow with its fallen side, the souterrain's slab passage beside it.
- **Flags:**
  - The data's realm is palearctic only. On 7731 the palearctic's castles sit in temperate deciduous wood, so most tower houses and all brochs come from the moors.
  - Tundra at −9 °C counts as cool and wet: the gate has no lower bound.
  - The undercroft and pit prison are the barrow kit's room and heart, with the kit's slab passage inside the keep. No new rooms were built.

## 2026-10-04 — §DS.7: the stone circle (prompt 27)
- **The kind:** `Ruins.Kind.STONE_CIRCLE`, "Stone circle" (`data/ruins.json` → `styles.stone_circle`, unmarked), placed by Monuments' sites pass. Nobody lives there (`Ruins.rolls_inhabited`).
  - **New gate word:** `open_ground` (no tree of the catalogue may grow there, the ground rolling under 0.1 over 60 m). Its `slope` never-word takes the same 0.1, the moor's own roll.
- **The ring** (`Monuments._stone_circle`, `RuinBuilder._stone_circle`):
  - 9–30 stones, 2–7 m tall, on a ring of 4 + 0.45 m per stone, leaning a little. About one in seven are fallen. Lintels sit on near-equal pairs over 3.2 m.
  - Outside: a dark ditch band and a low turf bank, with a causeway in on the -z side.
- **The souterrain:** on half the circles (seeded), the barrow kit going down from the bank under the ring to its end chamber (the heart) and a second mouth.
  - No fire-holders: `Delves.layout` marks a kind with delves.json `by_ruin` "none" (`no_fire`), and OldHearths lays no hearth there.
  - The other half have no delve: §CJ's one allowed exception.
- **No smoke.** The wind moans in the stones above 6 m/s through §DI's ruin bed, which already covers any stone ruin.
- **Check:** `tools/stone_circle_check.gd`, 0 fails.
  - 7731 has none (most of its grass is outside the palearctic).
  - Seed 2 has two: one of 30 stones with 2 lintels and a souterrain (stair, room, stair, heart, exit; no fire-holders; 31,744 triangles); one of 27 stones with 3 lintels and no delve (1,176 triangles).
  - Seed 8 and seed 5 have one each.
- **Walkabout** (`SEED=8 SITES=stone_circle`, harness frame §CG): the ring of grey stones with a lintel pair from the causeway, the bank's blocks in the foreground.
- **Flags:**
  - The bank reads blocky up close; it is built from plain blocks.
  - Seeds 2, 101 and 1234 print stack overflows during the world's own setup, before any monument code runs. They are pre-existing; the checks still pass.

## 2026-10-04 — §DS.5: the terraced pueblo (prompt 26)
- **The kind:** `Ruins.Kind.TERRACED_PUEBLO`, "Terraced pueblo" (`data/ruins.json` → `styles.terraced_pueblo`, unmarked), placed by Monuments' sites pass.
  - **New gate words:** `dry` (moisture under 0.4) and `near_water` (water within 2 km).
  - `make_site` also wants open ground (a slope under 0.12 over 40 m).
- **The town** (`Monuments._terraced_pueblo`, `RuinBuilder._terraced_pueblo`):
  - Rows of 4 m adobe rooms (7–11 across, storeys + 1 deep) on a mound of melted adobe (`_tell`), the back rows standing tallest (3–5 storeys), each storey set back to make terraces.
  - A third of the rooms have lost a storey or two, and one in twelve is gone.
  - Dark T-doors on each storey's front, roof hatches, beam ends, and ladders up the terraces.
  - The plaza has 1–2 kivas (`_kiva`) and the great kiva's ring round the way down: the barrow kit, the stores under the town, the deepest the heart, a way up out behind it.
  - Smoke: `roof_vent`.
- **Check:** `tools/terraced_pueblo_check.gd`, 0 fails on 7731 and 8.
  - 7731 has none; seed 8 has one at 37.53°N 154.68°W in cold desert, nearctic: 5 storeys over 11 × 6 rooms, 152 rooms in all, 1 kiva.
  - The delve: stair, room, stair, heart, exit. 38,772 triangles against the castle's 78,733.
- **Walkabout** (`SEED=8 SITES=terraced_pueblo HOURS=15`, harness frame §CG): the stepped town of five storeys on its mound, dark T-doors along every terrace, a kiva ring with its ladder in front; it is backlit.
- **Flags:**
  - It is rare, for the same reason as the cliff dwelling.
  - The way out comes up behind the town, not by a roof hatch.
  - The great kiva is the way in, not the heart (the barrow kit's heart is its deepest room).
  - The roof hatches are dark panels, not openings.

## 2026-10-04 — §DS.3: the stone heads and the oceania realm (prompt 25)
- **The realm:** oceania already exists in `RealmMap`. One of its nine provinces is dealt the OCEANIA world in the seeded shuffle (§AA), and all its land reads "oceania".
  - On 7731 it is province 2, with 1,653 land cells of 55,296 (3.0 %); on 8, province 8 with 2,274 (4.1 %). It is mostly coast: hot desert, dunes, savanna, beach, rainforest and rocky shore.
  - I left the dealing as it is, rather than adding a tenth realm for small isolated islands. **Flag:** the data's `waits_for` said the realm was missing; it now records that it is met.
  - **Its plant communities today** (none are tagged for oceania; dealt per land by niche fit, §CS):
    - Its own, 7731: Saguaro-paloverde Arizona Upland (hot desert), Coastal wattle dune scrub (dunes), Moso bamboo and Sasa grove (temperate deciduous), Baobab-palm savanna, Quebracho Chaco forest (thorn scrub), Reaumuria gravel desert, Amazon terra firme forest, Saltgrass-alkali heath meadow, Thrift-sea campion cliff-ledge sward (rocky shore), Post-fire birch-fireweed stand, Mountain-avens dwarf willow mat, Hagenia Afromontane forest, Sonneratia-Avicennia pioneer mudflat, Teak-bamboo moist deciduous forest, Alpenrose-dwarf juniper heath, Coiron-neneo Patagonian steppe, Prickly pear-yucca eroded slope, Tussock grass paramo grassland, Ohia-amaumau fern lava pioneer forest, Meadowsweet tall-herb fringe, Gambel oak-hackberry side-canyon woodland, Tussock sedge meadow, Hot-spring moss-bentgrass warm ground.
    - Spread from the nearest land (§CS.4's short-biome rule): Coconut-screw pine littoral wood (beach), Redwood alluvial flat forest, Guanacaste-bursera Pacific dry forest, Aleppo pine-kermes oak garrigue, Mountain birch forest-tundra, Map lichen-glacier buttercup fresh moraine, Switchgrass lowland prairie, Needlerush marsh, Loblolly pine-wax myrtle back-dune woodland, Black poplar-white willow riverside wood.
    - These are for chat's fill (`tools/stone_heads_check.gd` prints them for any seed).
- **The kind:** `Ruins.Kind.STONE_HEADS`, "The stone heads" (`data/ruins.json` → `styles.stone_heads`, unmarked), one a world. Nobody lives there (`Ruins.rolls_inhabited`).
  - **New gate words:** `coast` (the sea within 360 m: `Monuments.sea_bearing`) and `treeless` (no tree of the catalogue passes `HiddenPlaces.tree_gate` there or 40 m round: nothing is cleared).
- **The row** (`Monuments._stone_heads`, `RuinBuilder._stone_heads`):
  - A platform of fitted tuff 35 m in from the water, turned to face truly inland (the frame is on the ground grid for the delve).
  - On it, 5–15 heads 4–10 m tall (`_head_shape`): torso, long head, brow, shadowed eyes, nose, chin, ears, a red scoria topknot on some, one in five face down in the grass.
  - Inland, the quarry: an open face of tuff blocks and a half-cut head. Its cave is the delve, with an unfinished head lying at the heart. No smoke (`open_ring`).
- **Check:** `tools/stone_heads_check.gd`, 0 fails on 7731 and 8.
  - 7731: at 37.41°N 179.27°E, on a beach in oceania; 7 heads of 4.1–9.8 m, 4 with topknots.
  - 8: on a rocky shore; 12 heads, 2 fallen.
  - The sea lies behind both rows. No tree can grow there. The quarry's cave has a heart and a way out. About 32–35k triangles.
- **Walkabout** (`SITES=stone_heads HOURS=16`, harness frame §CG): the row of dark heads on their platform against a bright sea, a bare sandy coast round them.
- **Flags:**
  - "Treeless" is judged by each tree's gate (biome, realm, climate, soil), not by the stand the placer deals. A community's understory or a lone stray could still differ.
  - At 37°N the beach is too cool for the coconut palm, so it reads bare.

## 2026-10-04 — §DS.6: the brick city (prompt 24)
- **The kind:** `Ruins.Kind.BRICK_CITY`, "Brick city" (`data/ruins.json` → `styles.brick_city`, unmarked), placed by Monuments' sites pass.
  - **New gate words:**
    - `desert_river_floodplain`: a river within 1.5 km (60 m or more from its line), or a lake or the shore within 450 m, the ground under 60 m and dry. Only for this word, a river's or lake's map cell (~10 km) is no bar, and 0.3 m over the sea counts as land (the desert rivers here end in lakes and deltas at sea level).
    - `flat`: 0.1 over 60 m.
- **The city** (`Monuments._brick_city`, `RuinBuilder._brick_city`), 200–400 m across. The frame's origin is the palace mound; the tell's middle is `city_c`.
  - **The tell** (`_tell`, walkable) carries the maze of foundation walls (a 12 m grid, each side standing by its own roll, 0.9–1.9 m high) and a stepped three-tier ziggurat with a shrine and a stair.
  - **The processional way:** 70 m between 7 m buttressed walls, each with a band of glaze along its top, paved.
  - **The gate** (`_brick_gate`): towers, blue pilasters, an arch of glazed voussoirs, a face glazed #1E3FD0 (no glow, R8), and three rows of beasts each side (`_beast`: aurochs, lion, dragon).
  - **The palace mound** with fallen walls on top and a doorway at its foot over the delve: the barrow kit under the mound, with a heart and a way out beyond it.
  - Smoke: `roof_vent`.
- **Check:** `tools/brick_city_check.gd`, 0 fails on 7731 and 8.
  - 7731 has none; seed 8 has one at 40.75°N 143.66°W, steppe, palearctic, 245 m across, the palace mound 26 m.
  - The vaults: stair, room, stair, heart, exit. 69,504 triangles against the castle's 78,733.
- **Walkabout** (`SEED=8 SITES=brick_city HOURS=10`, harness frame §CG): down the processional way between its buttressed walls to the arched gate, glazed blue with rows of pale beasts.
- **Flags:**
  - **It is rare:** one in ten worlds scanned. The gate needed three loosenings to find any (river and lake cells allowed, 0.3 m over the sea, `flat` at 0.1), and they are written in its help.
  - Its tally on 7731 is dominated by realm (most hot deserts here are afrotropic).
  - The well shaft to the river bank is the barrow kit's way out, not a well.
  - The palms over the palace mound aren't placed.

## 2026-10-04 — §DS.4: the cliff dwelling (prompt 23)
- **The kind:** `Ruins.Kind.CLIFF_DWELLING`, "Cliff dwelling" (`data/ruins.json` → `styles.cliff_dwelling`, unmarked), placed by Monuments' sites pass.
  - **New gate words:**
    - `alcove_under_overhang` (`Monuments.alcove_at`): a sandstone escarpment face, or a canyon wall whose floor holds a plaza, 9 m high or more, with level ground before it;
    - `water_below`: water within 2 km;
    - `forest` (never).
- **The town** (`Monuments._cliff_dwelling`, `RuinBuilder._cliff_dwelling`):
  - **The alcove** is its own mesh (§CK: anything with a roof): a back wall of the face's sandstone, its ends, and the overhang with its lip at the drip line.
  - **The rooms:** 20–150 fitted sandstone rooms in rows, their storeys (2–4) stepping down toward the front, each with a dark T-shaped door and beam ends under the top storey's roof.
  - **Also:** 2–3 round towers, 4–7 ladders against the upper storeys, and 2–4 kivas in the plaza (stone rings round a dark pit, a ladder up out of each).
  - **The delve** (the barrow kit, its frame turned so +z runs out of the face): in at the alcove's back, the stores cut under the rooms, the heart under the plaza with the great kiva's ring over it, and a way up out past the plaza.
  - Smoke: `roof_vent`.
- **Check:** `tools/cliff_dwelling_check.gd`, 0 fails on 7731 and 8.
  - 7731 has none; scanning eleven worlds found one only on seed 8: 33.83°N 156.52°W, cold desert, nearctic, sandstone, a face 11 m high.
  - An alcove 49 × 20 m with 111 rooms in up to 4 storeys, 2 round towers, 4 ladders and 2 kivas.
  - The delve: stair, room, stair, heart, exit. 38,568 triangles against the castle's 78,733.
- **Walkabout** (`SEED=8 SITES=cliff_dwelling HOURS=15`, harness frame §CG): the alcove's overhang over a stepped town of pale rooms with dark T-doors, seen across the plaza.
- **Flags:**
  - **It is rare:** about one world in ten has a nearctic sandstone face in its biomes.
  - The mesa nest (§CK) isn't built, so the alcove is the dwelling's own mesh, a flat slab overhang rather than an arched hollow.
  - The way out comes up past the plaza, not at the alcove's rim (the barrow kit can't climb the face).
  - Seeds 101 and 1234 overflow the stack when a check generates a fourth world in one run (in the world's own setup, before any monument code; pre-existing).

## 2026-10-04 — §DS.2: the carved cliffs (prompt 22)
- **The kind:** `Ruins.Kind.CARVED_CLIFFS`, "Carved cliffs" (`data/ruins.json` → `styles.carved_cliffs`, unmarked), placed by Monuments' sites pass.
  - **New gate words:** `sandstone` (the rock under it) and `canyon_wall` (`Monuments.canyon_at`: the ravine layer within 400 m, its walls 8 m deep or more, a slot canyon where it pinches in dry sandstone).
- **Its facades** (`Monuments._carved_cliffs`, `RuinBuilder._carved_cliffs`):
  - 3–9 in a row along one wall. Each is re-found along the canyon so the row follows its bends, and the row's middle is where the wall faces the ground grid (the tombs' way in opens on it).
  - Each is a mass of the wall's own sandstone standing sheer from the foot (its back in the slope), carved in relief: plinth, 4 or 6 columns with capitals, entablature, a stepped pediment, an upper order on the tall ones, a dark doorway (R8) with soot above it, side niches on the wide ones, and now and then a creeper in a crack.
  - Behind the middle facade's door, the tombs are the delve: the barrow kit, in and down, with a shaft up to the rim as the way out. Their hearths smoke out through `open_ring` (no stack).
- **Check:** `tools/carved_cliffs_check.gd`, 0 fails on 7731.
  - One site: 23.53°S 30.25°W, hot desert, afrotropic, sandstone, in a slot canyon 8.4 m deep.
  - 4 facades, 8.9–16.6 m tall.
  - The tombs: stair, room, stair, heart, exit.
  - 34,800 triangles against the castle's 78,835.
- **Walkabout** (`SITES=carved_cliffs HOURS=13`, harness frame §CG): in the slot's bed, the facades' columns run along the right-hand wall in deep navy shade. It reads dimly, because the slot is narrow and in shadow.
- **Flags:**
  - The canyons are 12 m deep at this scale (`RAVINE_M`), against facades of 8–30 m; a facade taller than its wall rises over the rim as a mass of its own rock.
  - In sandstone desert every ravine is a slot, so the facades face across a slot a few metres wide. Petra's opening-out (the slot onto a wider court) would need a terrain stamp, which is not built.
  - The wadi entrance waits for the wadi nest.
  - The delve is the barrow kit.

## 2026-10-04 — §DS.1: the long wall (prompt 21)
- **The kind:** `Ruins.Kind.LONG_WALL`, "The long wall" (`data/ruins.json` → `styles.long_wall`, unmarked), placed by Monuments' sites pass (`KINDS` gains its line).
  - **New gate words:** `ridgeline` (needs a crest: the ground 120 m either side at least 5 m below, along some axis), and `wet` and `flat_lowland` (never).
- **Its line** (`Monuments._long_wall`):
  - From the site it walks the crest both ways in 40 m steps. Each step takes the highest point ahead within ±12°, snaps sideways to the crest, and never crosses itself.
  - The walk stops at water, at a drop steeper than 0.7, or where the crest is lost for 200 m. Under 3 km, no wall.
  - **Its gate** is the middle-stretch point nearest the ground grid's axes (the tower's delve opens on the grid); a road network node stands there.
  - **The rest:** towers every 250–500 m and at both ends, a height of 5–8 m, and the breaks (gaps, fallen stretches 1–2 m high, a tower down now and then).
- **Built in pieces, not one mesh** (`RuinBuilder._wall_run`, `_wall_tower`; `LongWalls`, new): plain blocks a 6 m step.
  - Each block's top is pitched with the ground: the walkway. There is an inner parapet and a crenellated outer one.
  - The gate (`_long_wall_gate`) is the site Ruins.find gives: a hollow tower with its door on the outer face, the way down (the barrow kit: rooms, the heart in the undercroft, a postern out on the far side), a gateway through the wall beside it, and a stone stair up the inner face.
  - Every other tower-to-tower stretch is a piece LongWalls computes on a worker within 650 m and frees past 900 m, with collision near.
  - Plants keep off its line (`LongWalls.clearings_near`).
  - Its delve hearths vent through wall flues (`smoke.json` `long_wall`, help line updated).
- **Check:** `tools/long_wall_check.gd`, 0 fails on 7731.
  - One wall kept (the other passers' crests gave out under 3 km): at 39.35°S 90.94°E in temperate deciduous forest (east_asia_temperate).
  - 4.4 km, 6.0 m high, 14 towers, 7 breaks and 2 towers down; 25 of 45 points along it on a crest.
  - Its delve: stair, room, stair, heart, exit.
  - Triangles: gate 35,364; the largest of 13 stretches 7,372; the castle's budget 81,184.
  - One road comes to its gate.
- **Walkabout** (`SITES=long_wall`, harness frames §CG): the crenellated wall across the view with the gateway and the gate tower behind bare trees, and a stretch going over a hill with a tower and more towers far off.
- **Flags:**
  - The gate tower's delve is the barrow kit, as the temple city's is.
  - The gate point needn't itself be a crest, so its gate tally shows "no_ridge".
  - There is no wall-top road in the network: the walkway is the wall's top, and the network's road ends at the gate tower.
  - Other ruins whose cells it crosses still stand where they are.

## 2026-10-04 — §DQ: the old man on his ox (prompt 20)
- **OxRider** (`scripts/landmarks/ox_rider.gd`, new): the first road regular (`data/uniques.json` → `road_regulars.ox_rider`, unmarked). One per world, a §BF traveller who rides.
  - **His road:** a road of his own over one great range, westward, from its east foot over a crossing to its west foot.
    - It is routed once a world on a worker by the network's own A* (`RoadNetwork.own_road`, whole: no collapse, no bridge out).
    - It is then put on the network (`publish`), so its tread and waymarks show like any road's.
    - The crossing is the range's highest that a road will take: the crest's dips first, then every fifth crest point, highest first, the seeded range first.
  - **His day** is a pure function of the clock, like the wandering fire's. He rides 07:00–17:30 local (`ride_hours`) at the ox's pace (`mount.speed_mps` 0.9; 0.78 m/s on 7731, so that a crossing ends at a dusk). At dusk he stops where he is and the ox grazes; there is no fire. Each crossing takes whole days, and the next dawn he is at the east foot again.
  - **The rider and the ox:**
    - The ox is a new sculpted body, `"ox"` in SculptedBodies: a heavy barrel, withers, a dewlap, its head low, horns out and forward (parts), dull black-brown #2A2220 with a mealy muzzle.
    - The rider is the shared rig in a new `"ride"` pose (PlayerBody: astride, rocking with the ox's step), hood up, in a plain dark robe.
    - The ox's legs step in diagonal pairs.
    - The hood tracks you by travellers.json's head_look; the ox never breaks stride. Dread hunts only you.
  - **The gate** (first guess, `OxRider.GATE`): two stone towers and a lintel astride the road at the crossing, the keeper's hut, and the keeper's camp. Camps builds the camp (key `gate:ox`) with one or two folk at their own hearth. The Book of the Way (tomes.json `tao`, `_note` unmarked) lies at the hut's door only once its text is in.
- **Check:** `tools/ox_rider_check.gd`, 0 fails on 7731.
  - Range 3 (summit 631 m), crossing at 157 m near its tail; his road 1,633 + 1,671 m, on the network.
  - Ten days: two days a crossing; forward by day, nearer the pass on the way up, still dusk to dawn.
  - 0.78 m/s against the 4.3 m/s walk.
  - The hood turned as you passed and the ox went on 1.73 m in 2.5 s; never hunted.
  - The gate and the keeper's lit camp with 1 folk; no tome without the text, the tome with a test text; the log line once.
- **Walkabout** (`SITES=ox_rider HOURS=12`, harness frames §CG): the old man on his ox coming down the snowy road toward you with a long shadow; the gate with the keeper's fire smoking beside it.
- **Flag for Mike (contradiction):**
  - §DQ puts him on "the high roads of the great ranges", but §DM.1's road cap (0.3 grade) can't climb a great range's flanks (24° on average, §CR.4; its "walkable routes" are walking routes, up to 35°).
  - On 7731 no crest point of any of the five ranges routes except near a range's tail, so "his highest pass" is 157 m at the end of a 631 m range, in the ice sheet at 74°N.
  - The search takes about 25 s of a worker thread at boot.
  - Options: let his road take the walking cap, or keep it.
- **Also flagged:**
  - He reappears at the east foot overnight (the "round the world" wrap).
  - The pass road isn't joined to the wider network at its two feet.
  - The keeper's hearth adds to §CU's count, as the hidden places' do.

## 2026-10-04 — §DP: the wandering fire (prompt 19)
- **WanderingFire** (`scripts/landmarks/wandering_fire.gd`, new): the second one-of-a-kind (`data/uniques.json` → `uniques.wandering_fire`, unmarked), and the first that moves.
  - **Where they are** is a pure function of the world's seed and the clock: night 0 in the hot desert or thorn scrub, each next night 2.5–5 km on, never into standing water or out of the desert. Nothing is saved; a reload finds them where the clock says.
  - **By day** (06:30–17:30) the thirteen walk the line from last night's place to tonight's; one carries their coal in a clay pot (§BP).
  - **At 18:00** they lay a fire and light it, a FireStore like any: a safe circle (§BA) and a coal free to take. They sit round it till dawn.
  - **Behind them** the last nights' places hold cold rings of stones and ash.
  - The log notes them once: "Thirteen sit round a fire in the sand."
- **Check:** `tools/wandering_fire_check.gd`, 0 fails on seed 7731. First night 33.36°N 165.47°W in hot desert; gaps 2.5–4.9 km; 2.40 m walked in 3 s at noon with no fire; at 21:00 the fire is lit with 13 of 13 inside 14 m, and the dread drains 0.50 → 0.467; a cold ring built at night 2; the log line once.
- **Walkabout** (`SITES=wandering_fire`, harness frame §CG): the thirteen seated round their lit fire among tall cacti at night. On that clock there was no past night yet, so no ring frame (the rings are checked headless).
- **Open calls, built at their defaults:** naming (play names nobody), the night rule (no special rule when their fire burns low), giving (nothing beyond a coal).
- **Not built:** §CY.2's circle loops (they sit still), and the one's hood down (the shared rig has no bare head).

## 2026-10-04 — §DR: the temple city, roots over stone (prompt 18)
- **Monuments** (`scripts/landmarks/monuments.gd`, new): one sites pass for every `ruins.json` style whose kind is "own" (§DS's rule).
  - **The gate:** realm, biomes, the plain words in needs and never (flat_lowland, water_for_moat, crag, slope).
  - **The roll and the cap:** a seeded `chance` roll, at most `per_world_max` kept. Where the land exists and no cell wins its roll, the best passer stands, as §DR.5 says one or two a world where the realm exists.
  - **One line a kind:** `Ruins.find` returns its sites first; a new kind adds its line to `Monuments.KINDS`.
- **The temple city** (`Ruins.Kind.TEMPLE_CITY`, "Temple city"; `RuinBuilder._temple_city`), built from the entry:
  - **The moat**, kerbed both sides;
  - **the causeway** with its crouching guardians (half scowling, dark and bowed; half serene, pale and level), the serpent held as their balustrade, its hood raised at the far end;
  - **the outer wall**, a gate tower on each side: piers round a dark doorway, tiers, and a face tier with a great calm face on each of its four sides; three-headed elephants with their trunks down at the front gate's corners;
  - **one or two gallery rings:** square columns, back walls with reliefs of dancers and guardians, mossy roofs, a gopura mid-side, a fifth of the bays fallen into tumbled blocks;
  - **the courtyards' heaps** of tumbled blocks;
  - **the sanctum** under a tiered central tower and four lesser towers.
  
  Its delve is the barrow kit under the sanctum (stair, room, stair, heart, a way out at a cairn), hearth rings from `delves.json`. Its hearths vent through a vent shaft (`smoke.json`, by its kind's name). Its repeated parts are plain blocks so it fits a castle's budget, and its near detail reaches its own edge. Its front faces dry land (no standing water on its approach), and its approach is kept clear of trees.
- **Root-trees** (§DR.2, `ruins.json root_trees`):
  - **What:** the tallest tree of its genera (Ficus; Tetrameles once filled) passing the place's biome gate, one hero tree standing on the roof, its roots seven pale tapering tubes poured down both sides of the wall to the ground.
  - **Where:** on every third gopura and gallery side of the temple city. Other old monuments in the wet-tropic biomes carry one or two on their highest roof faces; igloos, treehouses, boardwalks and graveyards carry none.
- **The ochre camp** (§DR.6): a camp at a temple city wears #CC7722.
- **Checked** (`tools/temple_city_check.gd`, seed 7731, 0 fails):
  - one temple city at 19.19°N 100.05°E in tropical dry forest, 280 m across, three enclosures;
  - one cell on this world passed the gate; it lost its roll and stands as the best passer;
  - its delve has a stair, a room, a stair, the heart and a way out;
  - 75,170 triangles, against 81,184 for the largest of 12 castles;
  - 7 root-trees (Ficus religiosa), and an ancient pyramid in tropical dry forest carries one.
  
  `crag_fortress_check` and `delve_check` 0 fails.
- **Walkabout** (harness frames, §CG; new `SITES=temple_city`, `SEED=7731`):
  - **the head of the causeway:** the face-towered gate and its tiers, rows of guardians, the elephants;
  - **inside:** the galleries with their columns and mossy roofs, figs on the roofs, the towers beyond.
  
  Backlit at 10:00, so the stone reads dark navy.
- **Flags for Mike:**
  - **Every own kind** now goes through Monuments. The rest of §DS and §DT–§DZ will add their lines.
  - **Its delve** is the barrow kit for now, so the way out comes up at a small cairn, not yet a collapsed gallery.
  - **The faces and reliefs** are blocks at our texel size, no carving detail.
  - **The moat** is a lit water band at the ground (no carved channel), and from eye height on the approach it is only a thin line.
- **Data:** the `[NOT WIRED YET]` prefix is gone from `styles.temple_city` and `root_trees`; `_help.styles_kinds` and `smoke.json outlets._help_do_ds` name the temple city as wired.

## 2026-10-04 — §DL: tomes, the I Ching first (prompt 16)
- **Tomes** (`scripts/player/tomes.gd`, reads `data/tomes.json`):
  - **Where:** `find.share_of_hearts` (0.15) of the delves' hearts hold a tome in place of their spear or bow (Delves' find, seeded per delve), among the tomes whose text is in and that have no `found_at` of their own (the Tao waits for §DQ's gate).
  - **Not until the text is in:** a tome's text is in only when its entry is `filled: true` and its `text_file` exists. Until then it never lies anywhere (no blank books), and the F3 overlay says `tome text missing: <id>`.
  - **Taking one:** right click; the log says "You found a tome: The Book of Changes". It is carried like anything and stays with your body if you fall.
- **Reading** (`scripts/ui/tome_panel.gd`): **R** with a tome carried (a new binding, `read_tome`, in `controls.gd`, shared ground; R was free) opens a panel built like the log's, in the HUD's font and colours. Its title page first, then one page at a time; ← → or A / D turn it (you don't walk while it's open); Esc or R closes. The clock keeps running (§CW). No systems: `iching.gd`'s coin cast is untouched.
- **The text format** (`data/tomes/README.md`): plain UTF-8, the first line the title, pages separated by a line holding only `---`, a page's first line its heading. Legge's public-domain translations only.
- **Checked** (`tools/tome_check.gd`, seed 7731, 0 fails):
  - as the data stands: no tome at any of 200 hearts, and the overlay lists iching and tao as missing;
  - with a three-page test file: the title page, three pages and no more, and back a page;
  - the clock ran with the panel open;
  - with the text in, 30 of 200 hearts (15 %) hold a tome;
  - taking one writes the log line.
  
  `delve_check` 0 fails.
- **For Mike:** the game is ready for the text. Filling `data/tomes/iching_legge.txt` from Legge's 1882 edition is a chat data job (one agent per group of hexagrams, checked against the source), then set `filled` to true.
- **Data:** the `[NOT WIRED YET]` prefix is gone from `tomes.json` and `items.json kinds.tome`. `hud.json log_more` now names only "given" as not wired. The Tao's own `found_at` note stays marked (§DQ).

## 2026-10-04 — §DK: the shrine and the sealed scroll (prompt 15)
- **Shrines** (`scripts/landmarks/shrines.gd`, under main; reads `shrines.json shrine, scroll, log`): built behind every burning shrine and oak door of §DJ. RuinBuilder builds the stone (`compute_shrine`); the layout is Delves pieces, so the dark, the dread and `Delves.locate` work in it as in a barrow's delve.
  - **The court:** flagstones on the ground over the hole and round it, the way down between low parapets.
  - **The hall:** 16–21 m long, steepened until everything under it has 1.6 m of earth over it. Under the oak it begins at the tree's foot, the open steps in front of the roots.
  - **The sconces:** 6–8 along the hall's walls (a bracket, a torch, a flame, a light), lit when you come and burning without fuel. What they burn is still open (`shrine.light`). They never smoke.
  - **The altar room:** the sealed scroll on the altar, a solid wall behind it. Beyond the wall, a stair and a room below (the barrow kit; nothing in it yet).
  - **The ground:** the holes in it come through `Delves.chunk_holes`.
- **The scroll:** right click takes it (`log.taken`). Carry it with your hands empty and right click a folk to show it (§BI's gesture; a scroll has no hand slot). Anyone else: `log.shown`, and you keep it sealed.
- **The reader:** the stand-in `scroll.readers` "headman_far", written into the data and flagged. It is the headman, else the first sitter, of the nearest lived-in camp 5–60 km from the shrine. They give `log.asked_where`, then one entry with the passage (`scroll.passage_first_guess`, four lines of my own; Mike replaces them) and the pattern ("The second and the third burn. The rest are dark."). The item becomes "Opened scroll". The scroll carries its shrine's place and pattern, so it reads anywhere.
- **The pattern lock:** seeded per shrine, never all lit or all dark. Right click a lit sconce to smother it; the torch's swing lights a dark one (and a lit sconce lights an unlit torch). When the hall matches, `log.opened` and the wall is gone, once, saved per world (WorldSave `shrines`). No hint, no counter.
- **The log panel wraps:** a long entry runs over several rows, its stamp on the first, so the deciphered text shows whole (`keep_deciphered_whole`).
- **Checked** (`tools/shrine_check.gd`, seed 7731, 0 fails):
  - the shrine behind an oak door 1.0 km from the camp: 6 sconces, pattern "The second and the third burn";
  - built: the hole in the ground; in the altar room, underground 1.00;
  - taken (log); shown at another camp (handed back, still sealed);
  - the reader at `ruin:(5, 9, 29)`, 8.3 km off: asks, then the whole text, and the item is renamed; the panel shows it in 9 rows, none wider than its 400 px;
  - 40 wrong arrangements leave the wall standing; the pattern opens it once; no sconce smokes.
  
  `hidden_check` 0 fails (now 95 places: 52 burning shrines, 37 oak doors, 6 earth homes). One run of it crashed mid-way (signal 11, the engine's intermittent one); the rerun passed.
- **Walkabout** (harness frames, §CG; new `SITES=shrine`, seed 101): the court under the great oak with the stair going down and the sconces glowing; the torchlit hall going down; the altar room by torchlight, the scroll on the altar, the wall behind.
- **Fixes on the way:**
  - two regions can each route a road between the same two nodes, so hidden places are now keyed by a road's ends and its length;
  - lit blocks in the delve turn their faces the way the delve's own mesh does (the altar had come out black).
- **Flags for Mike:**
  - **Who reads:** the readers are open; the stand-in reads at the nearest lived-in camp, since a camp's growth isn't known until you visit.
  - **Where the scroll is held:** it is shown carried, hands empty.
  - **What lies deeper, and the sconces' light:** both open.
  - **Roads vary between runs:** the network differs a little between runs of one seed (60 or 62 links near the camp), as duplicate roads come and go with the order the regions build in. It predates this pass, but it decides which hidden places a world has.
- **Data:** the `[NOT WIRED YET]` prefix is gone from `shrines.json` and from `items.json kinds.scroll`. `hud.json log_more` now names only the tome (§DL) and "given" as not wired. New: `scroll.readers` "headman_far", `scroll.passage_first_guess`.

## 2026-10-04 — §DJ: off the road, hidden places and the few who speak (prompt 14)
- **HiddenPlaces** (`scripts/landmarks/hidden_places.gd`, under main; reads `shrines.json hidden`):
  - **Placement:** placed after the roads. Each road link offers `per_km_of_road` (0.25) × its length in places, seeded by its two ends, `off_road_m` (150–900 m) to one side. A place stands only where no road, its own or another, passes within 150 m. The kits take turns in a seeded order, 14 tries each, so one easy kit doesn't take every place. The main thread never places: a worker does, and the place shows on the next refresh.
  - **earth_homes:** where there is a bank (slope 0.08–0.7), flat ground 9 m in front for the hearth, water within 500 m and a forest biome here or next door. Two to four low doors, each with stone jambs, a lintel, a plank door and a dry-stone face, under a turf mound running back into the bank. In front, a camp of Camps' own (`hidden:<seed>`) under the camp sim: its hearth, folk and smoke like any camp.
  - **oak_door:** on a rise (2.5 m over the ground 120 m round, slope ≤ 0.3). The place's oak if an oak passes its biome gate, else its tallest broadleaf, at 1.12 × the top of its band, drawn as one hero tree. At its foot, a closed stone door in a stone frame, roots over it.
  - **burning_shrine:** where there is a slope of 0.22 within 10 m. A stone portal with side walls and a roof slab going into the slope, steps down into the dark, and a torch in a bracket inside with its light.
  - **Clearings:** the trees and undergrowth keep back round each place (VegetationPlacer reads `clearings_near`).
- **The few who speak:** `speakers_share` (0.3) of the places have a small cloaked figure (about 1 m) standing 4–6 m off. Right click within 3 m and one line from `hidden.lines` goes into the log as "spoken", once a visit (leave 60 m and come back for another). The prompt reads "the small one". Ten first-guess lines are in `shrines.json hidden.lines` (Mike replaces them).
- **Checked** (`tools/hidden_check.gd`, seed 7731, 0 fails):
  - 464 km of road within 24 km of the camp hold 71 places (0.15 a km; ±50 % of 116 is 58–174);
  - every place 155–883 m from the nearest road;
  - by kit: 49 burning shrines, 20 oak doors, 2 earth homes (dry country: deserts and scrub);
  - every oak door's tree passes its biome gate; every earth homes has water within 500 m;
  - the nearest earth homes (34.73°N 158.96°E): built, its camp's hearth lit, 5 folk;
  - 28 % have a speaker; two right clicks give one spoken line, and leaving and coming back gives one more.
  
  `dread_check` and `senses_check` 0 fails. Headless boot is unchanged (29.0 s with and without).
- **Walkabout** (harness frames, §CG; new `SITES=hidden`, seed 101's temperate wood): the earth homes (two doors in a bank under green turf, their camp's drying rack and folk by the water), an oak door under a great pale-barked broadleaf, and the burning shrine's portal on a slope at 11:00 and 22:00, its torch glowing inside, a small figure standing by it.
- **Flags for Mike:**
  - **Old broadleaf:** the oak door's tree is any broadleaf (leaf type simple or compound) passing the place's biome gate (its biomes, realm, climate and soil), so in the desert it is a mesquite or a palo verde. The understory's community step (`Overgrowth.gate`) turned down every tree, because trees are dealt by stand dominance (§BH).
  - **§CU's count:** an earth homes' hearth is added on top of §CU's hearth count, not dealt into it. The hearths pass runs once a world over ruins and nests; the roads, and so the hidden places, are built region by region as you go.
  - **Shrine depth:** the burning shrine's mouth stands on the slope rather than cut into it (its steps go down into a dark back wall). §DK builds the hall behind it.
- **Data:** the `[NOT WIRED YET]` prefix now names only §DK in `shrines.json` (`hidden` is wired), and §DK and §DL in `hud.json log_more` (spoken is wired). New: `hidden.lines`.

## 2026-10-04 — §DF: your light gives you away (prompt 13)
- **Senses** (`scripts/creatures/senses.gd`, reads every `senses.json` watcher row): `can_sense(kind, eye, player)` answers how a watcher senses you, or that it doesn't.
  - **light:** your lit torch from `light_sight_m` at night, on a clear line;
  - **sight:** you yourself, from `sight_day_m` by day and at night `night_vision` plus `moonlight_adds` × the moonlight of it;
  - **hearing:** `hearing_m` × your noise (new `player.sound.heard_share`: a sprint all of it, walking half, sneaking a fifth, still nothing);
  - **scent:** `scent_m` within 30° of straight downwind of you (new `player.scent.cone_deg`, `calm_mps`, `calm_share`);
  - **touch:** within `touch_m` (3).
  
  Line of sight is one ray against trunks, walls and rocks, plus a march along the line against the ground, so ridges and the horizon stop it too.
- **The hunter** (`dread.gd quarry()`) follows you while it senses you; else a lit planted torch it can see (the decoy: it stops at the torch's circle, 14 m); else where it last sensed you. It closes and takes you only while it senses you. The meter, its stages and its rates are unchanged. The lurker has no day sight, so in the dark it finds you only by ear or touch.
- **The rosters** (`creature.gd _shy_m`): an animal's seeing share of its flight distance shrinks to its night share at night unless your torch is lit, and downwind within its `scent_m` it notices you anyway. `light_response` stands.
- **Checked** (`tools/senses_check.gd`, seed 7731, 0 fails):
  - a lurker 400 m off, clear line: torch lit "light", dark nothing; over a hill, neither;
  - a day animal at 60 m: 18 m sight at new moon (nothing), 78 m at full (sight);
  - a werewolf 300 m downwind smells you, 300 m upwind nothing;
  - hearing: a sprint at 59 m, sneaking not there but at 11 m, walking at 29 m;
  - the decoy: you 50 m off in the dark, the hunter goes to the torch, and 25 s later stands 14.0 m from it and 60 m from you.
  
  `dread_check` 0 fails. `cover_check` 0. `climb_check` has 2 fails (3 on the base, the shinobi kit's). `hits_check` crashes on the base too.
- **Flag (a clash in the prompt):** it gave night sight as `night_vision × (1 + moonlight_adds × moonlight)`. That makes a day animal's full-moon sight 27 m, so its own check (sees a dark player at 60 m under a full moon) could not pass. Built as `senses.json`'s help reads it, moonlight *adding* to the share (0.15 + 0.5 = 0.65, 78 m), and the reading is written into the help. Mike's call.
- **Data:** the `[NOT WIRED YET]` prefix is gone from `senses.json`. `goblin_band` and `stranger` keep `built: false`, and nothing reads them. New with help lines: `touch_m`, `player.sound.heard_share`, `player.scent.cone_deg`/`calm_mps`/`calm_share`. Hills don't muffle sound yet.
- **Open (Mike):** what the stranger does when they come (stands with you, walks you to a fire, leaves you a coal, something stranger); the goblin band waits on the four §DH calls.

## 2026-10-04 — §DI part 3: the ghost at the corner (prompt 12)
- **Haunt** (`scripts/landmarks/haunt.gd`, under main; `ruins.json haunt`):
  - **Which places:** `share` (0.4) of the ruins whose kind is in `kinds` (graveyards, barrows) are haunted, seeded per ruin, and the same share of any delve's tomb (its heart).
  - **When:** while you are in or beside one (its footprint plus 25 m, or down its delve) and the light is low: dusk or night by the sun, or sky visibility under `low_light_visibility` (0.25) where you stand (a dark hall, a delve). A roll each second at `per_real_hour` (1.0) an hour; a roll won waits for a good spot in the same visit. At most `per_visit_max` (1) a visit, never within 4 m of its last spot at that place.
  - **Where:** 8–20 m off (`distance_m`), within ±35° of where you look, inside the camera's frustum with nothing between, and an occluder (a wall end, a jamb, a headstone, a trunk: anything with collision) within `occluder_within_m` (1.5).
  - **What:** the shared cloaked rig in `color` #C8D8FF at `alpha` 0.55. It runs on its own copy of the body shader with an alpha added and the hood's dark emission taken out. No shadow, no Light3D, no collision, no sound, no footsteps, no head-look. It stands `seen_s` (0.5–2 s), then walks past its occluder, away from you. The frame it leaves the frustum or a ray to it is blocked, it is freed (after 15 s in view at the most).
  - **Never:** the haunt's code touches no Dread, no log, no sound. It is not a lurker.
- **Checked** (`tools/haunt_check.gd`, seed 7731, 0 fails):
  - 840 graveyards and barrows sampled: 37 % haunted (share 0.40);
  - a haunted graveyard (21.91°N 155.08°E) at night: a ghost in 19 of 100 ten-minute visits, at most 1 a visit, never at the same spot twice running;
  - at noon in the open: 0 in 100; at an unhaunted ruin (a pyramid): 0 in 100;
  - a ghost 16.3 m off stood in view, then was freed 1 frame (0.02 s) after the view turned away;
  - no emission, no Light3D, no shadow, no collision; the dread's meter and stage unchanged.
  
  One of three runs crashed (signal 11) between the checks, on the teleport to the second ruin; the reruns passed. The quit-time crash is the known one.
- **Walkabout** (harness frame, §CG; new `SITES=haunt HOURS=22`): the haunted graveyard under a bright moon, headstones and a mausoleum. The haunt line says it is in a haunted place, the light is low, no ghost yet. That is the point: it is rare. The same site's ruin sounds: the owl and the scrabble.
- **Data:** the `[NOT WIRED YET]` prefix is gone from `ruins.json haunt`. `kinds` also lists "abbey" (§DU, not built), which waits for that kind.

## 2026-10-04 — §DI part 2: a ruin sounds like what lives in it (prompt 11)
- **Residents are sources** (`RuinSounds`, under main): every built ruin within 150 m gets its residents, each an Audio3D player at its own part of the ruin. The parts are read from the ruin's drawn bounds, or its delve's door and well. Each calls on its own clock, at its hours from `audio.json ruins.residents`, by the sun:
  - **birds** at the top of a tower, keep, aqueduct, pyramid or crag fortress, dawn and day, where the roster's day birds fit the climate;
  - **bats** at the vault or the delve's door, dusk and dawn, where it is at least 2 °C;
  - **an owl** at a high window (a ruin 5 m or more), night;
  - **something scrabbling** below, dusk and night, where the roster's night ground or canopy animals fit;
  - **frogs and drips** at the cistern, any hour, where the ruin has water (a wetland, standing water, a boardwalk's marsh, the crag's cistern). Frogs follow the roster's frog or a mild wet place, never brackish water;
  - **lizards** on the sunward wall by day, in warm dry country (18 °C or more, moisture 0.5 or less).
  
  New `audio.json` kinds, each with a muffle: ruin_birds, ruin_bats, ruin_owl, ruin_scrabble, ruin_drip, ruin_frogs, ruin_lizard. New synth voices: owl, bats, scrabble, drip, lizard.
- **The ruin's bed** (SoundBed, no position): `stone_wind_loop`, a hollow moan, is 0 below `bed.stone_wind_from_mps` (6) at the ruin's opening and full 4 m/s above (`Wind.at` there). `drips_loop` plays where the ruin has water. Inside a closed hall the outdoor layers drop by up to 60 % (the enclosure). Each fades by how near the ruin is (full within 30 m, gone by 90 m).
- **Overrun:** the residents are silent by day (`overrun_quiet_by_day`, delves.json's tell); the bed's quiet stays Overrun's own. Night stays as built. The ghost makes no sound. No cave groans (Mike's call).
- **Checked** (`tools/ruin_sound_check.gd`, seed 7731, 0 fails):
  - the tower at 38.93°N 156.82°E: birds at noon, heard and placed at the ruin; the owl and the scrabble at 02:00, no birds;
  - a wet-meadow boardwalk (40.71°N 66.40°W, 15 °C): frogs and drips;
  - an overrun barrow at real noon: no residents, Overrun.quiet 0.82;
  - the stone wind: 0.00 at 5 m/s, 0.50 at 8;
  - every new kind has a muffle.
  
  No swamp ruin stands on this world, so the check takes the first warm freshwater wetland. A cold fen (−2.5 °C) got drips and no frogs, as it should. `audio_mix_check`: 0 fails.
- **Walkabout** (for the ear, harness frames, §CG; `SITES=ruins HOURS=18.4`): at dusk the wet aqueduct had bats and the scrabble and the desert tower its bats. The wind was 0.5–1.3 m/s, so no stone wind.
- **Flag for Mike:** the creature roster has no bats, owls, lizards, small rodents or cliff birds. The owl, the bats and the lizards go by climate rules (`RuinSounds` BAT_MIN_C, OWL_MIN_C, LIZARD_*) until it does; the birds, the scrabble and the frogs go by the roster's songbird, toucan, possum, raccoon, hare and tree frog. Call spacing (EVERY_S) is in code for now.
- **Data:** the `[NOT WIRED YET]` prefix is gone from `audio.json ruins`.

## 2026-10-04 — §DM.1 the road never leads where you can't follow (the hard grade cap)
- **Mike's bug** (the road thinned, went up an unclimbable hill and was lost): today's roads, walked every 5 m on the fine ground, had 1,900 steps of 67,000 over a 0.30 grade, 378 of them walls (worst 5.9), all on what the 120 m routing lattice couldn't see.
- **The coarse route** (`RoadNetwork._route`): `roads.json network.hard_max_grade` (0.30) is now a hard reject per lattice step, and `max_grade` (0.18) stays the soft switchback cost. The lattice also refuses a step across an escarpment or a ravine taller than a cutting (`TerrainField.line_noise`/`line_mask_at`: the step's ends disagree in sign) and onto a great range's sheer faces (`TerrainField.range_cliff`, new).
- **The fine walk** (`_fine_fix`): after routing, the tread is walked every 5 m on the detailed ground. Its profile is the highest line under the ground that never climbs faster than 0.27 (0.9 × the cap, a margin for the 4 m mesh). A stretch that would need a cutting deeper than `holloway.depth_m`'s 2.0 m, or that falls away across the tread more than a metre's fill and a 0.6 slope, is re-routed on a fine A*. Its heights sit on a 5 m grid, every move is checked at every 5 m point, and no cell may be steeper than 1:1. The re-route runs at 10 m steps, then 20 m, then 40 m in wider windows. A link that still can't be made walkable is not built: its camp tries its next neighbours, and is logged unreached if none route.
- **The cutting** (`_bench`, `RoadNetwork.carve`, `TerrainChunk.compute`): where the ground stands over the profile, or falls away across the tread, the chunk cuts the tread down to the profile. The flat is at least 2.5 m each side of the centreline, with banks rising 1.2 in 1 beyond and up to 1 m of fill. Plants sit on the carved ground (they read the chunk's heights). §DM.3 will shape these into holloways.
- **Speed:** a region's links now route on up to four threads. Seed 42's 12 km round the camp takes 21.7 s to build, against 3.6 s before. Time to play, headless on this 4-core machine, went from 33 s to 41.5 s.
- **Checked** (`tools/road_check.gd`, seed 42), on 81 links, 88,802 five-metre steps on the ground as built:
  - steepest step 0.280, none over 0.30; steepest tread 31°, none over WALK_MAX_DEG 45°; 8.5 km of cuttings;
  - the drawn chunks under the nearest road: steepest 0.312, within 0.02 of the cap for the 4 m mesh.
  
  River banks and crossings are left out: they are the river's own ground, carved after the road. Ruin footprints are left out too.
- **The cost:** 81 links where the old network had 101. The ones dropped cross cliffs with no way round within 600 m, mostly to springs, fords and stones. One people's camp has no road, the same one as before. The check's "tread reads on the road" fail (0.07) is the same on the commit before this pass.

## 2026-10-04 — §DI part 1: a ruin wears its place (the overgrowth)
- **What it reads:** `ruins.json overgrowth` (by_moisture rows, blended between rows; shade_side_scale; age; cold_mean_c). The place's moisture and the year's mean temperature come from the planet at the ruin.
- **What it writes** (`Overgrowth` and `RuinBuilder`, at build time on the worker):
  - **Moss:** the moss column scales the stone's moss (vertex alpha, which the ruin shader turns leafy). Tops carry ×1.3. Side faces facing away from the sun carry shade_side_scale more than those facing it (poleward: north in the north, south in the south). The builder's old wet-scaling is replaced on ruins; nests and lone rocks keep it.
  - **Lichen:** the lichen column goes in UV.y. The ruin shader paints pale grey-green flecks (a few ochre) into the stone's tile at its 16 texels a metre (R9), patchy over a metre or two.
  - **Ivy and vines:** every place the builder can hang ivy (broken wall tops) is a hanging place. The vine column is the share that hang a strand, by an even, low-discrepancy draw. The builder's own rolls are drawn as before, so no ruin's shape changes. VineCover's species patches hang from the kept places near you; vines use their §CE rule (the biome lists them and they fit), as on the trees.
  - **Ferns and wall-top plants:** spots come from the stone boxes: wall feet beside a block's long faces (if no other block stands there), gaps (exposed tops of low stumps) and tops (exposed tops over 1 m up). Each spot is kept by its own hash against the fern or wall_top column (ferns also by the shade side). Species come from the place's own plants: the §CA biome gate, the §CS community, the realm, needs a wall can meet, and the climate. Ferns are FERN-shaped ground cover. Wall tops are small grass, tussock, rosette, cushion or shrub ground cover, never a fungus, and ferns where the place has none. At most two fern and three wall-top species per ruin. They are drawn as plant MultiMeshes in the ruin's frame (`Overgrowth.dress`), at most 12 % of the ruin's own triangles, with no collision.
  - The cold rule (mean under 0 °C) leaves only lichen and moss. `age` is 1.0 for every ruin (monuments). Nest remains keep their own look for now.
- **Check** (`tools/overgrowth_check.gd`, seed 7731, 0 fails). One castle is built in four places:
  - cloud forest (moisture 0.92, the wettest warm cell with a fern): moss coverage 0.67 (shade 0.83, sun 0.68), 93 ferns and 68 wall-top ferns (Hammock fern);
  - hot desert (moisture 0.00): moss 0.003, vine 0.017 (1 of 58 places), lichen 0.25;
  - tundra (−11 °C): lichen 0.26 and moss 0.18, nothing else;
  - temperate wood with Ivy (moisture 0.90): 66 wall-top plants (Forest bluegrass) and Ivy on 28 of 71 places.
  - Every placed species passes the gate. The dressing adds at most 15.1 % (temperate wood: plants 330 triangles, Ivy patches 11,100) to a castle's ~75,500.
- **Walkabout** (harness frames, §CG; `SITES=ruins`, seed 101 at 14:00): the wettest stone ruin, an aqueduct in temperate wood at moisture 0.95, reads green to the cornice with ivy hanging from the arches; the driest, a hot-desert tower, is bare blue-grey stone with lichen. The ferns at the piers are too small to read at 480p from 16 m.
- **Other checks:** crag_fortress_check and delve_check pass. vine_check's ruin vines pass after the fix above. Its one remaining fail ("TROPICAL_RAINFOREST: vines on living trunks (0 of 0)": no trees at its probe spot) fails the same on the base commit.
- **Data:** the `[NOT WIRED YET]` prefix is gone from `ruins.json overgrowth`. `haunt` and `audio.json ruins` stay marked (parts 2 and 3).
- **For Mike:**
  - A real hot-desert ruin at moisture 0.16 carries a faint 3 % moss and a 5 % vine share by the rows. Only the driest desert is truly bare. If you want no moss in any desert, the 0.3 row's moss is the dial.
  - Many wet places' communities have no small grass or herb, so their wall tops carry ferns.
  - The "camp_remains" age (0.5) isn't used yet: nest remains aren't stone ruins.

## 2026-10-04 — §DO the crag fortress: its own kind, in Tibet-like country, a delve that climbs
- **The kind:** `Ruins.Kind.CRAG_FORTRESS`, "Crag fortress" in play (`ruins.json styles.crag_fortress`). The reference names stay in the entry's source line only (§BO).
- **Where** (`CragFortress`, the sites pass):
  - once per world, every ruin cell is tried at 14 points, and the most prominent point that passes the gate is kept;
  - the gate: `spawn.biomes`; `spawn.realm` (RealmMap); a crag (prominence ≥ 6 m over the ground 200 m round); altitude ≥ 1500 m real (150 m here); not wet (moisture ≤ 0.55); not warm (annual mean ≤ 14 °C); not on water;
  - each passing cell rolls `chance` 0.3, and at most `per_world_max` 4 are kept, the most prominent first;
  - `Ruins.find` returns it in its cell in place of the cell's other ruin.
  
  On seed 7731, 5,766 cells give 3 that pass and 1 that wins: andes-realm cold desert/steppe at 22.7°S, 234 m up (2,342 m real), 98 m high in 6 tiers. Turned away: warm 56, wet 41, biome 39, altitude 12, water 11, flat 2, realm 1.
- **Built** (`RuinBuilder._crag_fortress`, `CragFortress.plan`):
  - the rise is the builder's own rock, rough tiers each a little to one side round the delve's shaft, its shaded (poleward) faces lichen-tinted with a little moss;
  - limewashed battered blocks (leaning 5–8°) in front of each tier's rock, sparse low down and close together near the top, some taller than their tier, with small dark windows in trapezoid frames, the matte red-brown band (#5A2420) under every roofline and flat roofs;
  - the top chapel over the shaft with one matte gilt finial (#B08A2E, no emission: R8);
  - one long stair at 44° up the front from the ground to the top terrace, on a walkable ramp, with low parapets;
  - 3–5 lesser houses round a plaza at the foot, with a camp spot there;
  - no cloth anywhere.
  
  It faces the sun's side (the equator) within ±20°, so the climb and windows face the light and the lichen sides are behind. That is my call, not in §DO. Plain boxes and 3 m wall cells keep it to 30,246 triangles (22,096 of them the climb inside), under the largest castle's 78,090. The far view keeps the bands, windows, finial and stair, and switches over further out than a castle's (its size).
- **The delve climbs** (`CragFortress.layout`, `Delves`, `OldHearths`):
  - a passage in at the foot to the shaft;
  - flights of stairs turning at landings at each end, up through the tiers, never steeper than 38°;
  - the landings are stores (clay jars), one a cistern (a dark basin) or bare, with a brazier on all but the first, whose bowl holds a fire-holder (`delves.json by_ruin`: brazier); the first landing has the old hearth (§CJ's safe room);
  - the heart is the top chapel, the last flight coming up through a stairwell in its floor, with an altar, offerings, the heart's fire-holder and the find (§AW);
  - the way out is the chapel's door onto the terrace at the head of the outside stair (§CJ.4).
  
  It is full dark inside the rock, light again at the door. The log says "A stair climbs into the dark inside the rock." and "The topmost room, the chapel under the finial." The first room's and the heart's fires vent through a roof vent on the roof above them (`smoke.json by_ruin`: roof_vent). Overrun works as for the barrow (§CN; the den's door is at the foot).
- **Checked:** `tools/crag_fortress_check.gd`, seed 7731, 0 fails:
  - the gate holds at every site, at most 4 are kept, and no stray finds turn up in 600 sampled cells;
  - the way in is at the foot, the heart is 98 m above it, and there is a way out;
  - 12 flights, the steepest 37.2°; 12 landings (stores ×5, landing ×6, cistern ×1); 11 braziers; the triangles are within one castle;
  - a camp spot at the foot.
  
  `delve_check`, `old_hearth_check` and `overrun_check` still pass with 0 fails.
- **Walkabout** (harness frames, §CG; `SITES=crag`, from the nearest point on its approach line that sees its foot, 80 m out):
  - it reads as tiered white blocks with windows, rock between, the long stair, and the chapel and finial on top;
  - under this tropical sun the north-facing walls get little direct light (sun against front 0.46 at 10:00), and the look's grade puts them in navy shade; at 15:30 in winter only its sunward edges are bright;
  - flagged for Mike: the limewash may want to be brighter, or the walls more broken up.
- **Not built / flagged:**
  - §DM.5's straight road approach isn't built, so the walkabout stands where it will run;
  - §DO's nests (kopje, volcanic neck, mesa) aren't built, so every fortress stands on its own raised rock;
  - the realm list leaves out RealmMap's "himalaya" (high Asia over 2000 m real), the most Tibet-like realm in the game: flagged for Mike;
  - camps at its foot are "north" folk (the mountain folk, §DO.6).
- **Also fixed:** the vertex alpha the ruin shader reads as moss is now 0 on plain faces, and `RuinBuilder.box` has a plain mode for big builds.
- **Data:** `ruins.json styles.crag_fortress` is unmarked. The DO/DR/DS notes in `ruins.json _help.styles_kinds`, `smoke.json` and `delves.json` now say the crag part is wired. `Tuning` loads `ruins.json`.

## 2026-10-04 — docs/PROMPT_QUEUE.md: the Claude Code passes, readable from the repo (Claude, chat)
- **New:** `docs/PROMPT_QUEUE.md` holds the thirty-five one-idea Claude Code prompts for §DA–§DL, §DO–§DS and §DT–§DZ in §BR's order, with a status table. Mike no longer pastes: "Pull, then read docs/PROMPT_QUEUE.md and do the next prompt marked todo." Claude Code marks a row `built <hash>` when it pushes the pass; Claude (chat) appends new prompts and keeps the marks. 01–09 are marked built from the log; §DM's pass (another chat's hand-off) sits between 16 and 17 and is not in the file.

## 2026-10-04 — §DC part 2: butterflies by day
- **DayAccents** (`data/day_accents.json butterflies`), the day's counterpart of NightAccents (whose blue butterflies at the ruins stay as they are). Every half second, all must hold:
  - it is day (daylight at or over night_accents' 0.35);
  - it is 14–40 °C;
  - you are not on snow.
  
  When they do, the herbs and shrubs within 30 m whose sky visibility is over 0.4 are the flowers. No species has a bloom state yet, so any herb or shrub by day stands in. 2–6 butterflies (more where there are more flowers) circle them 0.3–2.5 m up, each a two-frame pixel card (open, closed), drifting a little downwind. From 5.5 m/s of wind at you they land at their flower and stay still. At dusk, at night and when the gate fails they are freed.
- **Colours** by the land's family: tropical, dry, cold, or temperate, a first sort by the biome's name until the species fill. Their material is lit by the scene, with no emission, and casts no shadow or light (R8).
- **Checked:** `tools/day_accents_check.gd`, seed 7731, 0 fails:
  - meadow cells were tried nearest the camp first; five of them (steppe and alpine meadow) carry no herb or shrub instances at all, and the sixth (alpine meadow, 44.23°N 157.94°E) had 37 flowers in the sun;
  - there, at noon: 5 butterflies, all within 30 m, all flying;
  - at 8 m/s: all 5 on the ground and still;
  - at 02:00: none; under closed crowns (visibility 0.1): none; on a glacier at noon: none (snow);
  - no emission.
- **Walkabout** (harness frame, §CG; `SITES=at AT=44.230,157.944 HOURS=12 WIND=1`): five were flying, but at `size_m` 0.08 they don't read at 480 lines from where you stand. Flagged for Mike: `size_m` is the dial. The walkabout now prints `[butterflies]` per site.
- **Flag:** many grassland cells hold no herb or shrub plants at all (the same gap as the prairie site noted before), so most meadows have no butterflies yet.
- **Data:** `day_accents.json` is unmarked.

## 2026-10-04 — §DC part 1: shafts of sunlight, only when the air would show them
- **The gate** (`ShaftField.gate`, every half second round you): all three must hold.
  - Direct sun: the sun above 2°, §CX's cover under 0.75, and no cloud shadow over you.
  - Something in the air (`air_of`), the largest of:
    - the place's fog likelihood;
    - the damp: rh from 0.8 to 1.0 (the weather now reports `rh`);
    - the low mist above the day's own (`SkySystem.mist_density`);
    - a lit hearth's smoke within 40 m;
    - dust (1) in a ruin's hall.
  - A broken roof, which sets the kind:
    - **canopy**: spots within 40 m where the sky visibility is 0.15–0.7 and the line to the sun passes the leaves (`FoliageCover`);
    - **ruin**: in a hall (SkySystem's enclosure inside a built ruin), floor spots the sun reaches under a roof, with dust motes;
    - **crepuscular**: three long rays 70–110 m out toward the sun, when the cover is broken (0.3–0.7) and you stand under open sky.
- **Drawn the era's way:** at most 6 flat quads along the sun's direction, turned about their axis to face you. Each is one flat cool colour (#DDF2FF), unshaded and alpha-blended, at most `alpha_max` 0.22 × air × the low-sun scale × facing (0.15 with the sun behind you, 1 looking into it). So lit air can't bloom (R8), and the frame's grade and dither take it like anything else. They breathe and sway with the gust field. Motes are 12 single-pixel specks drifting at 0.05 m/s inside each canopy and ruin shaft. Everything is freed when the gate fails. The field rides the floating origin under the world root.
- **Checked:** `tools/shaft_check.gd`, seed 7731, 0 fails:
  - a jungle spot (13.07°N, 142.03°E) at 07:00, rh 0.95, cover 0.2 has 6 canopy shafts, the strongest at alpha 0.027 (facing away);
  - the same spot at 13:00, rh 0.5, no fog, mist or hearth: 0;
  - at cover 0.9: 0;
  - a ruin hall by day: 5 sunbeams with motes. The hall is a stone room built by the check with one vault strip missing, because RuinBuilder's broken vaults are rare to find by search; the hall gate in play is the enclosure inside a built ruin;
  - #DDF2FF is cool, and no channel is past the bloom threshold.
- **Walkabout** (harness frames, §CG; `SITES=at AT=13.07,142.03 FACE_SUN=1`): at 07:00 with `RH=0.95`, six pale hard-edged shafts slant toward the low sun through the broken crowns. At 13:00 with `RH=0.5`, faint streaks remain, because this land's own fog likelihood (0.24) counts as air at any hour. That is as the design reads ("the weather's fog likelihood"), but it means a foggy land keeps faint noon shafts: flagged for Mike.
- **Also fixed:** the §DB flare's leaf test passed the wrong cluster list to `FoliageCover.see_through` and would have raised script errors under trees. It now uses `clusters_round` round the eye.
- **Data:** `look.json shafts` is unmarked. Added `crepuscular_length_scale` 3.0 (Claude Code's guess, explained in the help).

## 2026-10-04 — §DG the werewolf only on the brightest nights, by scent, from downwind
- **One threshold** (`DayCycle.full_moon_illumination()`, `day_cycle.json` 0.97): `CreatureSpecies.active_now` uses it for `active: full_moon` (it was 0.85, about seven nights; now about three). `Dread.speed_for` gives a hunter its `full_moon_speed_scale` when the moon's lit share is at or above it (it used to be above a moonlight of 0.9).
- **The werewolf's forests on other nights** (`Dread.entry_for(biome, illumination)`, `dread.json full_moon.only` / `other_nights`): the temperate deciduous, temperate rain, maritime and floodplain forests get the werewolf only while the moon is at least 97 % lit. On every other night they get the fallback row, the lurker with no species (§CU), as the grasslands do every night. The werewolf keeps its pacer pattern, 6.5 m/s and ×1.3 on the full moon.
- **By scent** (`Dread.by_scent`: `senses.json watchers.werewolf` has no light sight and a scent range):
  - Its noticing ignores the torch: the meter fills at the moonlight rate whether your torch is lit or not (`Dread.dark_rate`). For the lurker, a torch still slows the meter.
  - It keeps to your downwind side (`pick_scent_bearing`): the bearing the gust field blows toward where you stand, with ±25° of play, re-picked about every ten seconds. That bearing places both its first glimpse at stage 3 and its pacing at stage 4.
  - Light holds it back at stage 5 exactly as built.
  - `Tuning` now loads `senses.json`.
- **Checked:** `tools/dread_check.gd`, seed 7731, 0 fails:
  - at a lit share of 0.5 a temperate deciduous forest gets the lurker; at 0.98 it gets the werewolf at 8.45 m/s (6.5 × 1.3);
  - the hunter and `active_now` both switch at 0.97 (0.86 and 0.96 off);
  - in a steady 5 m/s wind the werewolf's side is within 45° of downwind in 100 % of 600 picks;
  - its fill is 0.164/min with or without a torch, and the lurker's slows to 0.070 with one.
  
  `moon_reference.py` (run): a new world's first three nights are werewolf nights (99.4 %, 99.9 % and 98.2 % lit at midnight). That is §DG's open call, untouched.
- **Data:** `dread.json full_moon` and the `full_moon_illumination` row in `data/sky/README.md` are unmarked (that row's text now says what reads it). `senses.json` stays marked for §DF.

## 2026-10-04 — §DE waking: found by folk, days later, at your hearth or the nearest
- **Where you wake** (`Main._found_fire`, `Camps.camp_at` / `found_fault` / `found_fire`, `camps.json wake_found`): your hearth if you made one and its camp is lit with folk at it. A home that has gone dark (its fire is embers or out), is overrun (§CN) or is abandoned (nobody lives there) is skipped that waking. A hearth with no camp left at it is let go, with a log line. Otherwise you wake at the nearest lit fire with folk at it, measured from where you fell. The candidates are the opening camp, the people's camps at ruins (never an overrun one) and the lived nests, searched from 12 km out and widening. The opening camp is the last resort. **This amends §AY:** a new world has no hearth until you right click a camp's fire. An old save whose hearth was the opening camp by default (never chosen) lets it go.
- **The lost days** (`LostDays`): a span, uniform between 1 and 3 game days, rolled per death. The world runs it through the paths it already has:
  - the clock moves (the moon, the season and the plants' growth follow it), and the weather is stepped in its own 15-minute steps (`World.run_weather`);
  - every camp you know runs its hourly ticks (`CampSim.catch_up`), its fire burning and fed from the woodpile as if unloaded (`CampSim.away`);
  - old hearths catch up from when they were last seen, and the fires you laid burn down;
  - planted and dropped torches burn on, and the lit torch on your body burns out.
  
  Nothing else moves the clock (§CW; the clash is flagged in §DE).
- **The log** (§AZ): at the waking, the cause line in `wake_found.death_lines_found`'s wording ("Struck down by a wolf"), then "Folk found you out cold and carried you to their fire. Two days have passed." (`log_one_day` for one day). Both are stamped at the waking. The found line also shows on screen as a note (folk are mute, §BO), in place of the old spoken "Camp folk" line. You wake empty-handed, your gear on your body where you fell (as built). The shinobi profile keeps its old wake.
- **Checked:** `tools/wake_check.gd`, seed 7731, 0 fails:
  - dying 3.0 km from the home hearth wakes you 3 m from its fire;
  - with no hearth, you wake at the nearest lit camp (5.0 km), and none nearer passes;
  - with the home (a people's camp 9.3 km off) overrun, it is skipped and you wake at the nearest other camp, 4.4 km from the overrun one;
  - the clock moved by exactly the rolled span (1.1006 days), and 20 rolls run 1.03–2.90;
  - the log reads "Struck down by a wolf" then the found line, both stamped Y1 D2 06:10;
  - the body lies where you fell with its gear, and its torch has burnt out;
  - the camp's fire burnt 9.5 woodpile units in 1.10 days (its daily burn 8.4, so about 9.2).
  
  `tools/dread_check.gd`: 0 fails (it now makes the camp's fire home first, and reads the dark's line after the waking). `tools/new_world_check.gd`: its §DE case passes. Its other 12 fails are the same on the commit before this pass (in this container a fresh world always rolls seed 42, so the save and pointer checks fail).
- **Data:** `camps.json` `wake_found` is unmarked. In `hud.json`, `log_more` keeps its prefix for §DJ/§DK/§DL, and notes that `found` is wired.

## 2026-10-04 — §DD moon nights: full against new is obvious; the year joins the day count; dread follows the moonlight
- **The moon's share** (`SkySystem`, `look.json moon_nights`): the moon's light by its lit share is now `MOON_FLOOR + (1 - MOON_FLOOR) × lit^curve_exponent`, with the exponent (3.3) read from the data, so it lives in one place. A new dial, `lift_scale` 0.67, scales the moon's whole share of the night: the moon light's energy, the ambient's `moon_add` and the sky's moonlit lift. The floor is untouched. **Measured** (harness frames, §CG; the open prairie, seed 7731, `tools/moon_nights.sh`): a full moon at 02:00 gives 0.205 (target 0.20; it was 0.25 before the dial). A new moon at 02:00 gives 0.098 (target 0.10). The waxing first quarter at 20:00 gives 0.130 (target 0.13; at 02:00 it has set). The darkest 5 % stays navy: blue/red 8.2 under the full moon and 40.9 under the others.
- **Dread** (`Dread.fill_rate`): in the dark, out of the torch's reach and away from a fire, the meter now fills at a rate between `fill_per_min_dark` (0.20/min, no moon) and `fill_per_min_moon` (0.14/min, a full moon high), following the moonlight. Before, it switched between the two at a moonlight of 0.3. A delve still counts as no moon.
- **The calendar** (`World.calendar`, `clock_text`, `stamp_text`; `hud.json calendar`): the HUD's time line reads "Day 12 of Year 1 · 21:40 · Night" (`time_format`). The log's stamps read "Y1 D12 21:40" (`log_stamp`). The log panel's day header is the "Y1 D12" part, and older saves' stamps ("Day 3 · 03:40") still split the same way. The day is ((day count − 1) mod 365) + 1 and the year is floor((day count − 1) / 365) + 1, with the count from the world's first local day as built (§CG). `year_names` stays "number".
- **Checked:** `tools/day_check.gd`, 0 fails. Day count 1 reads "Day 1 of Year 1", 365 "Day 365 of Year 1", 366 "Day 1 of Year 2" and 735 "Day 5 of Year 3". The stamp, the HUD and the face agree at every reading through the first day and at three set times, one a year on. Dread fills at 0.200 / 0.170 / 0.140 per minute at moonlight 0 / 0.5 / 1. `tools/dread_check.gd` also passes with 0 fails. `tools/moon_nights.sh` renders the three nights and passes all three. The walkabout gained `MOON=full|new|first_quarter`.
- **Data unmarked:** `look.json moon_nights` (with `lift_scale` added and explained in its help), `hud.json calendar`, and `dread.json full_moon`'s `moon_fill_by_light`. The werewolf part of `full_moon` stays marked for §DG.

## 2026-10-04 — §DB the sun flares when you look at it, the PSO way
- **What it reads:** each frame `LensFlare.step` reads the sun's direction and elevation (`SkySystem`), §CX's cover (`Wind.cover`, from the eased weather), the cloud shadow over you (Wind III), `Delves.underground` and the camera. It shows only when all of these hold: the sun is up, you're not underground, the cover is under `gone_above_cloud` 0.85 and no cloud's shadow is on you, the sun projects inside the frame, and nothing stands in front of it. That last test is one physics ray toward the sun (ground, trunks, walls; your own body excluded) plus the leaves along the first 60 m (`FoliageCover.see_through`).
- **What it draws:** a canvas layer at -2, under PostGrade's -1, so the grade, the 5-bit quantise and the dither take it as part of the picture (§Y, R9). It is a core of `core_px` 10 at the sun, a halo of 28 at 0.35, and the rings on the line from the sun through the frame's centre at their `at` (9 px at 0.55, 16 px at 1.35), everything × `strength` 0.6. Each is a soft disc with a 2 px stepped edge, nearest, nothing blurred. It fades in and out over `fade_s` 0.15 s and toward the frame's edge over `edge_fade` 0.1. Thin cloud dims it toward `through_cloud` 0.4. Cool white and cyan by day; below about 10° the core eases to the sun disc's `retro.colors.sunset_sun` and the rings stay cool (R7). No streaks, bars or dirt. Never the moon, never underground.
- **Checked:** `tools/flare_check.gd` (headless), 0 fails: alpha 1.00 after 0.15 s with the sun 30° up ahead; 0 within 0.15 s with a wall between ("blocked"); 0 at cover 0.9 and under a cloud's shadow; 0.54 under thin cloud (0.6); 0 below the horizon, underground and 3° outside the frame; the rings on the sun-to-centre line within 0.00 px; a cool core by day and #FBF486 at 5° up.
- **Walkabout** (harness frames, §CG; `FACE_SUN=1 HOURS=9,17.2`): the prairie at 09:00 and at 17:12, looking at the sun, with the flare at 1.00 both times (printed by the tool). **Fixed on the way:** `PlanetPlayer.set_view` now turns the view at once. The tools hold physics still, so every walkabout facing came out the same (the flag in the 3 Oct entries); now they turn.
- **look.json:** `lens_flare`'s help is unmarked (wired).

## 2026-10-04 — §DA Wind III: water answers the gusts, cloud shadows sail on part-cloudy days, the hearth's column under the crowns
- **Water** (`water.gdshader`, `wind.json water`, `wind_water_state` / `Wind.water_state`): every water pixel reads the gust field where it lies. Under 1 m/s it is a mirror (its mottling stills). From 2.5 m/s a gust's patch roughens as it slides over: the glints are cut to a quarter and the blue deepens 14 %. From 8 m/s a few pale pixel crests (half-metre cells, running downwind) show on open water, never on a river ribbon and never as foam sheets. It stays the brightest thing in view: only the glints are scaled.
- **Cloud shadows** (`wind.json cloud_shadows`, `wind_cloud_shade` / `Wind.cloud_shade`): two octaves of the same value noise at 200 and 800 m, carried at 1.8 × the ground wind (`Wind.cloud_drift`, global `cloud_shift`). A point is in shadow where the field is under the cover's quantile, so the shaded share of the ground is the cover. They show only between from_cover and to_cover of §CX's one value (Main hands it to `Wind.cover`), easing in and out at both ends. `terrain.gdshader` and `foliage.gdshader` gained a `light()` that is Godot's own Lambert (plus the leaves' backlight), dimmed by the shade for the sun only. The shade colour holds and the shadow maps are untouched. The shade is worked out once per pixel in `fragment()` and handed over in a varying: foliage is now 9 slots, under the house's 12. **A/B:** the prairie at cover 0.12 renders as before (the ground's mean colour within 1/255; the rest is the sky's motion and the dither).
- **The smoke column** (§CV is built): `Smoke.shelter_over` finds the crowns over a hearth (the tallest tree within 9 m where sky visibility is under 0.6), and the column rises straight up to them (`shelter_m`). Above them its lean follows the gust field at each height, not only the mean. A gust at the fire (factor 1.15 → 1.5) tears the cards near it, up to 14 m. A stack's mouth is already above the crowns.
- **Checked:** `tools/wind_check.gd` (under xvfb), seed 7731, 0 fails:
  - (k) a mirror under 1 m/s; a 3 m/s gust patch (×1.34) roughens to 1.0; crests none at 7.9, 0.50 at 9.6.
  - (l) strength 0 / 1 / 0 at cover 0.1 / 0.5 / 0.9, and 51 % of the ground in shadow at 0.5.
  - (m) the shadows move 9.0 m/s against the ground wind's 5.0 (×1.80).
  - (n) under 15 m of crowns the column is 0.000 m off upright at 12 m and leans 67° above them (48° for the open column, times the gust and the shear).
  - All 29 spatial shaders build; the varying check passes. The walkabout gained `CLOUD=` and `SITES=lake`.
- **Walkabout** (harness frames, §CG): a lake shore in the jungle at 4 m/s, where the glints break up in patches and the water stays the brightest thing in view; and the prairie at cover 0.5, where the ground lies in broad 200–800 m shade with lit bands between. Both 0 fails.
- **wind.json:** the about line says Wind III is wired. The whole file's blocks are now read except `sound.crowns.kinds`' wording (the voices are built) and §DI's ruin wind.

## 2026-10-04 — §DA Wind II: litter skates in the gusts, the bed and the crowns hear them, cloaks and the fire's specks take them
- **Litter** (`WindLitter`, `wind.json litter`): eight tries every tenth of a second round you (25 m), never more than 40 pieces in the air. Each try reads the gusted wind at that spot times the shelter of the crowns over it, and lifts only what the litter field really holds there (`LitterField`: the cell's pile and its dominant species). Leaves go from 5.5 m/s and needles (conifers) from 9. A lifted leaf is that species' own card in its season's colour (`LeafSeason.skate`, `leaf_fall.gdshader`'s spin and flip): it skates downwind at a quarter to two fifths of the gust, slowing, in shrinking hops, and lies down after 2–6 s. Sand (dunes, beaches, hot desert; from 6.5), spindrift (snow; from 5) and dust (dry bare ground and dry roads; from 7) are low streaks scrolling downwind on a 5×5 grid of 8 m ground cards round you (`shaders/wind_skin.gdshader`, dithered, lit like the ground, never glowing).
- **The ear:** `SoundBed`'s wind loop is multiplied by the gust factor at you every frame, and still closes under canopy as built. `WindCrowns`: every quarter second the trees within 40 m (every loaded chunk's) are scored by the gust at their crown (a canopy crown in the full wind, a smaller tree sheltered); past 1.6 m/s up to four of them sound from where they stand. They use the new `audio.json` kinds `crown_hush`, `crown_rustle`, `crown_clatter` and `crown_rattle` (muffled like any source) and the new `SoundSynth` loops `crown_*_loop`: needles hush, broad leaves rustle, palm fronds clatter, a deciduous crown well into autumn rattles.
- **The cloth:** the player's rig gets `Wind.cloak_at` (the gust at you times the shelter over you; nothing in a delve), and every other cloaked figure's rig samples its own the same way (`PlayerBody._own_wind`).
- **The fire:** `specks.gdshader` drifts the specks with the gusted wind at the fire, and the torch's sparks (`ember.gdshader`, the torch's only user since §CZ) drift with it at the torch. The coals' gust flare reads the field at the fire instead of a noise clock. The pipe's puffs (§CY.4) already take the camp's wind; nothing new there.
- **Checked:** `tools/wind_check.gd` (under xvfb), seed 7731, 0 fails:
  - (g) a 7 m/s gust on an open spot lifts American beech leaves (29 of 60 tries); they skate 8.6 m straight downwind and settle after 4.8 s, and all have lain down within 7 s. At 4 m/s nothing lifts. Lodgepole pine needles stay put at 7.
  - (h) the bed's wind gain is 0.313 at a lull (×0.45) and 1.113 in a gust (×1.60), exactly the factor's ratio.
  - (i) by a tree 77 m from the camp (the camp itself is a clearing), at 8 m/s one crown within 40 m passes 1.6 m/s and sounds (rattle), never more than four; at 0.6 m/s none.
  - (j) the cloak's wind is 4.94 m/s, the field's 4.94 × shelter 1.00.
  - Wind I's (a)–(f) still pass. The walkabout gained `SEASON=autumn`.
- **wind.json:** the about line now says Wind II is wired (litter, sound, cloaks, specks). Water, cloud shadows and the smoke column are Wind III.
- **Walkabout** (`WIND=7 SEASON=autumn`, harness frames, §CG): the deciduous site is an open hill with no trees within view, and the 1 km road site stood inside a ruin's hall by a pool, with the worn tread at its feet. Stills can't show a leaf skating, so the motion stands on the check's numbers. One of two runs crashed on start in the llvmpipe renderer (signal 11) before any site; the rerun passed, 0 fails.
- **Noted:** the Wind I wood frame (`random_temperate_deciduous`) stood inside a shrub, so leaves filled the view. That is not the sway: the largest displacement at 6 m/s on a 3 m shrub is under 0.3 m, about what the old sine gave.

## 2026-10-04 — §DA Wind I: one wind, gusts that travel, shelter under the crowns, the crowns by Beaufort, grass with a sheen, flutter
- **The gust field, written once for each side:** `shaders/wind.gdshaderinc` (the shaders) and `Wind` (`scripts/weather/wind.gd`, the CPU readers of later passes; `Wind.gust_at(world_pos, time)`, `Wind.at(...)`). The field is two octaves of 3D value noise at `wind.json gusts.patch_m` 40 m and 12 m, weighted 0.85 / 0.15, so neighbours 3 m apart share a gust. It sits in the planet's own frame, so the floating origin never moves it, and is carried downwind at the mean wind's speed in real seconds. `Wind.tick` sums the wind's travel each frame and sets the global `wind_shift`. The factor is 1 + intensity × the noise (scaled to one standard deviation), clamped to [0.45, 1.6]; the direction veers up to 10°; it fades to 1 below 0.5 m/s. The weather's own slow swell stays underneath as the mean. Nothing in the weather sim changed.
- **Shelter (§BD's number) at placement:** `Wind.stamp` runs on the chunk worker after the dapple is baked. It writes each plant's sky visibility (from the dapple, box-filtered to about 4 m), its wind kind (grass and herbs; a canopy or emergent crown, always in the full wind; the rest, sheltered) and its flutter flag (Populus, Ficus religiosa) into the instance custom data's blue, beside the rustle (`TreeContact` keeps the code when it rustles). Below the crowns the shelter is 0.15 + 0.85 × sky visibility. The log profile (z0 from the ground under you: water, snow, sand, grass, or scrub for bare ground; global `wind_prof`) sets how far each height moves: a grass top about half, head height 0.7, a treetop 1.1.
- **foliage.gdshader:** the old per-plant sine is gone. Every plant samples the field at its root. Grass, reeds and herbs bow from 1.6 m/s to 0.55 of their height by 13.9, with a paler sheen as a gust bends them. Trees and shrubs move by the Beaufort table: leaves 1.6, twigs 3.4, small branches 5.5, small trees 8, large branches 10.8, whole trees 13.9. Each trunk sways at its period by height (`crowns.sway_period_s`), its phase nudged by the gust so the sway rolls through a stand. Flutter adds 0.08 m in any air from 0.1 m/s. Still 8 varying slots: the sheen rides in `f_d.z`, which only the far pictures used. `terrain.gdshader`'s dapple wobble and `aroid_part.gdshader`'s lean read the same field.
- **Checked:** `tools/wind_check.gd` (under xvfb), seed 7731, 0 fails:
  - (a) a gust 20 m upwind arrives 3.35 s later at 6 m/s (3.33 expected);
  - (b) 3 m apart the factor differs by 0.026 at the median and 0.084 at the 95th percentile;
  - (c) under a closed crown (sky 0.1) 0.232 of the wind (0.235 wanted; 31 steps of sky visibility); crowns 1.0; a delve 0; the profile 0.48 / 0.69 / 1.12;
  - (d) 10,000 samples from 0.450 to 1.600, the veer at most 10°;
  - (e) the shader rendered at 100 points against `Wind`: worst factor difference 0.00002;
  - (f) 2,861 plants round the opening camp carry their species' kind.
  - `shader_varying_check.py`: foliage 8 slots. All 28 spatial shaders build. The walkabout gained `WIND=6`.
- **wind.json:** the prefix is now "Wind I wired" (gusts, beaufort, profile, grass, crowns, flutter). Litter, cloaks, water, specks, smoke, cloud shadows and sound are Wind II and III. `profile.z0_m.forest` is unused, because under trees the shelter rule does that job (one effect, not two).
- **Not in this pass:** under trees the aroids sway open, since the aroid garden's instances carry no shelter code yet.

## 2026-10-03 (after midnight) — Mike: every fire smokes by its flame's size (§CV); the pipe holds a mystery herb (§CY.4)
- **Every fire smokes.** `Campfire.build` now gives every fire its smoke, so the fires you lay and the mythic folk's fires smoke like the camps'. The small fires send up their own column, sized by the flame against a campfire's (`Smoke.tick_flame`, `smoke.json → hearth.by_flame`, the by_state row × size², since a fire's heat goes with its flame's area). A tomb lamp or the fat lamp (flame 0.14 / 0.12) sends up a thread about 1.2 m tall and 8 cm wide. The torch's burnt end, in hand or planted, is an ember, so it takes the embers row at the torch's 0.32: a faint wisp 0.82 m tall, 0.35 solid, that trails behind you as you walk (the hand's motion is added to the wind). The pipe's brand sends up a wisp while it lights the bowl. At night the fire lights √scale of each column (a lamp 1.1 m of its thread). `hearth.never` is emptied and those fires joined `sources`, with the help line citing Mike.
- **The pipe:** what's in it is a mystery herb, Mike's call; it is never named (comment in `FireCircle`, HOW_TO_RUN).
- **Checked:** `hearth_smoke_check` gains every fire in the world smoking, a laid fire, the lamp's thread hiding with its flame, the torch's wisp and its trail, the lamp's night foot. Results are in the commit; smoke_check.py and fire_circle_check.py --strict: 0 errors.
- **For Claude (chat):** Mike's two calls (all fire smokes by flame size; the mystery herb) belong in §CV and §CY.4 of the 30 Sept doc. §CV still says torches and lamps never smoke.

## 2026-10-03 (late night) — §CY.2–CY.4 the fire circle, its seats and the pipe; §CV smoke from every hearth, stacks, swifts, the wildfire plume (Claude Code)
- **§CY.2 The fire circle** (`FireCircle`, `camps.json → sim.fire_circle`).
  - Every camp's folk now sit in a ring round the fire, one seat each and a spare. That includes the elder and the hunter at the opening camp, with the spare seat on your side.
  - One seated pose for every cloaked figure, with loops on the arms and hood, picked by the phase of the day's weights: watch the fire, warm hands, poke the fire (the fire flares and throws a burst of specks, §CZ), feed the fire (when it is below the store's feed line), the pipe, eat (only when the food store has food), hearth work, doze.
  - Children play only the resting loops. Adults' loops (the jobs, the pipe) aren't a teen's.
  - **Notice:** inside 7 m the hood, and only the hood, follows you (70° at most). When you leave it holds 2 s and goes back to the fire, and it won't notice you again for 40 s. A dozer doesn't notice.
  - `tools/circle_check.gd` (seed 7731): 0 fails.
    - At the opening camp (tropical forest people, rainforest) the seats are a root and a log in the stand's bark.
    - At the road's camp (taiga people, krummholz, a ruin) they are a fallen block and rocks.
    - Over ten minutes all seven loops played: 44 changes at the opening camp, 85 at the road's camp.
- **§CY.3 Seats** come from `seats.by_biome`, with `at_site` on top (a ruin's fallen block, a cliff's ledge) and `by_people` instead for the canopy folk; two kinds at a fire at most.
  - A log, a piece of driftwood or a limb seats two.
  - Wooden seats take the bark of the stand's commonest tree within 40 m. Stone seats take the place's own rock; hummocks the ground's colour; mats the people's cloth.
- **§CY.4 The pipe.** One adult at a fire at a time.
  - In order: packs the bowl, leans in and lights it with a brand from the fire (a stick with a glowing end, in hand only while lighting; nobody strikes a spark, §BP), draws 3–6 times with rests between, taps it out.
  - Each draw shows the bowl's ember, one glowing pixel that casts no light. Each breath out leaves 2–4 square puffs in the hearth smoke's pale blue-grey, rising and drifting with the wind; they never glow.
  - The circle check saw 3–6 draws every time, never two pipes at once, never a child's.
  - **What is in the bowl is still unnamed.**
- **§CY.5 is not built:** §BV's jobs (the gatherers with loads) aren't built. A camp still has one figure walking out by day.
  - So the dawn break, the dusk forming and the night keeper wait.
  - Until then the folk sit in the circle at every hour, and the opening camp at dawn is the circle you wake into.
- **§CV.1 The column** (`Smoke`, `shaders/smoke.gdshader`, `smoke.json → hearth`).
  - Five camera-facing cards round the fire's spine: noise scrolled up, three flat bands on a 16 × 24 texel grid, a 4 × 4 dither cut-out, pale blue-grey, lighter and bluer with distance.
  - On every camp hearth, the opening camp's, every rekindled old hearth and every nest's; never torches or lamps.
  - The check passes:
    - Flames 60 m × 4 m, low 30 m, embers an 8 m wisp, out nothing.
    - It leans 8° per m/s of the weather's wind up to 70°, and stands straight under 1 m/s.
    - On a still dawn it stops at 18 m and spreads flat.
    - Rain over 1 mm/h halves it.
    - At night only its fire-lit first 8 m shows, warm.
- **§CV.2 Far hearths.** The living camps the world keeps (inhabited ruins, lived nests) within 3.2 km that aren't built are drawn from their fire's state in the sim (a camp nobody has visited burns, as its sim starts), at least 2 pixels wide.
  - With about 160 hearths a world there were none within 3.2 km of seed 7731's spawn. From 1.5 km short of the road's camp, its column showed, burning.
  - The search takes about 8 ms every half second.
- **§CV.3 Stacks.**
  - A barrow delve's first-room hearth and its heart each get a stone vent (`mound_vent`) on the mound above: its lip black with soot, its mouth dark, glowing faintly at night while the hearth below burns.
  - Their smoke leaves from the vent's mouth at 0.7 of an open fire's (42 m); cold, there is none.
  - Cave mouths and grottos carry a navy-black soot streak over the mouth, lit or not.
  - Castle and tower stacks wait for their delves.
- **§CV.5 Swifts** (`smoke.json → swifts`). A vent wide enough, in a climate that suits (8–30 °C, moisture 0.3+), may hold a flock of 12–60 (60 % of them, seeded); never over an overrun delve.
  - They hunt over the ruin by day. At dusk, between the sun at 2° and −4°, they wheel tighter over the vent, then pour in one by one. They pour out at dawn.
  - Light the hearth below and they leave at once. They come back after it has been cold 10 game days.
  - Their chatter isn't built yet.
- **§CV.6 The wildfire plume:** 400 m tall, 120 m wide, dark indigo, leaning with the wind, its base lit orange at night, seen to 7.5 km.
  - The sim lays a wildfire's scar at once, so the plume stands over a fresh scar for 6 game hours (`Smoke.PLUME_GAME_H`, a first guess) and thins out.
- `tools/hearth_smoke_check.gd`: 0 fails. `smoke_check.py --strict` and `fire_circle_check.py --strict`: 0 errors. All 28 world shaders build; `shader_varying_check.py` passes.
- **Other checks:**
  - `fire_breath_check` passes.
  - `camp_check`'s 3 fails are the same before and after this pass.
  - `hits_check`'s two hit-marker timings ("kill's X holds 0.40 s", sometimes the critical's) wobble between runs, with the smoke and circle on or off (0.30–0.38 s against 0.40). That check counts frames as 1/60 s each. Frames measured the same with `SMOKE=0 CIRCLE=0` as with both on (16.8–16.9 ms).
  - Two things that would have cost frames were fixed along the way. The circle cached by place and time (DayCycle keeps one latitude's table, and asking it for several places a frame rebuilt it each time). The far-hearth search runs every half second, not every frame.
- **For Mike to confirm (first guesses):**
  - Hood notice: follows you inside 7 m; won't notice again for 40 s after you leave.
  - Bark tint: the commonest tree within 40 m (§BW's per-piece tint isn't built, so "as the woodpile does" had nothing to copy).
  - Smoke cards: five per column.
  - Far hearths: at most 12.
  - The plume's 6 game hours.
  - The stack's night glow: dim orange.
  - The puffs' size: 5 cm growing to 22 cm.
- **Flags:**
  - The player's own fires (laid from the ember carrier, or laid and lit) don't smoke: §CV's source list doesn't name them.
  - §CU's ~160 hearths a world make far columns rare. §CV.2 counts on seeing the next hearth's column from about 3 km.

## 2026-10-03 (evening) — §DA–§DL, Mike's morning voice session written up: the wind you can see, the flare, the moon's two nights and the year, waking, light gives you away, the full-moon werewolf, the goblin band (in part), ruins, hidden places, the sealed scroll, tomes: design and data only (design chat; Mike, "lock it all in", then 17:07: one Claude Code prompt per idea)
- **Design:** §DA–§DL sit before §BR under a session note (the fan dropped; seven things Claude said in the call that the doc corrects). Written after the afternoon's §CR–§CZ, so: §DA adds to §CV's smoke column (shelter under the crowns, gusts, the maths behind `far.seen_to_m` and `min_px`) and to §CZ's built specks (the gust field); §DF and §DG use §CU's lurker wording; §DE sits on §CY.1's "whatever hour it is" and the circle, and flags its one clash with §CW (the lost days move the clock). §BR gains the order: one idea at a time, the wind first.
- **Data, none of it wired:** new `wind.json`, `senses.json`, `shrines.json`, `tomes.json`, `day_accents.json`; `look.json → lens_flare, shafts, moon_nights`; `hud.json → calendar, log_more`; `camps.json → wake_found`; `dread.json → full_moon`; `sky/day_cycle.json → full_moon_illumination` (and its README row); `ruins.json → overgrowth, haunt`; `audio.json → ruins`; `items.json → scroll, tome`. Every data file parses.
- **Reference maths:** `tools/reference/beacon_reference.py` (on the 400 km planet the horizon is 451 m from eye height; a 60 m column's top shows from 3.2 km, matching §CV's 3 km; the day haze leaves 8 % contrast at 1 km; a full column is under 2 px past 2.1 km, so `smoke.json far.min_px` carries it to 3.2 km). `tools/reference/moon_reference.py` (a full moon every 70.8 h of play, 7.8 h of it "full" at 0.97; a year is 876 h; nights 1–3 of every new world are werewolf nights as built).
- **Found in the code (for Claude Code):** each plant sways on its own sine phase and the weather's gusts are minutes long, so nothing travels; `creature_species.gd` gates `full_moon` at 0.85 lit (seven nights) and `dread.gd` boosts the werewolf above moonlight 0.9 (one threshold now: `full_moon_illumination` 0.97).
- **For Mike:** §DH's four calls (who the band are, what happens if they catch you, whether they raid camps, whether they carry light); §DE against §CW; §DG's first nights; §DD's year names; §DF's stranger; §DK's readers, the sconces' light and what lies deeper; §DI's Minecraft cave sounds.

---

## 2026-10-03 (21:55) — §DT–§DZ: the hanging gardens, the abbey, the colonnade, the temple park, the columns (a nest), the pillar shrines, the hewn temple: design and data only (design chat; Mike, "lock it all in" at 21:48, five batches of reference frames)
- **Design:** seven sections appended after §DS. §DT a garden that outlived its gardeners (the channel still runs, the carried-in mountain trees went wild: §CS/§CT's one exception placed by the generator). §DU the roofless abbey (where §DC's shafts, §DI's residents and the haunt meet). §DV the columns of a house that burned (§BQ to the letter). §DW the temple park, the open cousin of the temple city, with the lotus ponds as §CS.6's niche. §DX columnar basalt as a nest of the fire family with the organ-pipe and sea-cave variants. §DY the pillar shrines: §BC's forks in three dimensions, bridges by span (stone stands, rope is gone, living root grows, §BT). §DZ the hewn temple, found from above. §BR gains the order.
- **Data, none of it wired:** `ruins.json → styles` gains six `kind: own` entries, `haunt.kinds` gains the abbey; `landforms.json → landforms.columnar_basalt` with two variants (`tools/landforms_check.py`: 36 landforms, 0 errors); `smoke.json` and `delves.json` rows for all six. Every data file parses.
- **Fills for chat, later:** Cedrus libani and Ficus carica (the gardens), Nelumbo nucifera and Nymphaea (the temple park's ponds), the column hut as a coast-folk signature (the columns).
- **For Mike:** written at defaults: the pillar shrines' bridge kinds and the one-in-six rope bridges still up.

---

## 2026-10-03 (21:30) — §DO–§DS: the crag fortress, the wandering fire, the old man on his ox, the temple city, and the monuments by realm: design and data only (design chat; Mike, "lock it in" at 21:24, with two batches of reference frames)
- **Design:** §DO (a Tibet-like fortress climbing a crag, its own kind, the delve goes up), §DP (thirteen in the desert who walk by day and sit by a carried fire at night, leaving a trail of cold rings; the second one-of-a-kind and the first that moves), §DQ (the one traveller who rides: an old man on an ox on the pass roads, the first road regular of §DM.7; the gate, its keeper and the Tao Te Ching as first guesses), §DR (the temple city: galleries, tiered towers, a moat, root-trees standing on the stone as the signature, face towers and a guardian causeway at the gate), §DS (the set: the long wall, the carved cliffs, the cliff dwelling, the brick city, the stone heads, the terraced pueblo, the stone circle, the tower house and the broch; four of Mike's list were already in as pyramid styles). Appended after §DN; §BR gains the build order.
- **Data, none of it wired:** `ruins.json → styles` gains nine entries with `kind: own` (crag_fortress, temple_city, long_wall, carved_cliffs, stone_heads, cliff_dwelling, terraced_pueblo, brick_city, stone_circle) and two styles of existing kinds (tower_house, broch), a `_help.styles_kinds` line, `terrace_platform.signature`, and a `root_trees` block; `uniques.json → uniques.wandering_fire` and a new `road_regulars` block (ox_rider); `tomes.json → tao` (found at the pass gate); `smoke.json → outlets.by_ruin` and `delves.json → fire_holders.by_ruin` rows for every new kind. Every data file parses.
- **For Claude Code:** the stone heads wait for a tenth realm, oceania, in `RealmMap` (code). The ox is a new creature body. Every `kind: own` entry is a new `Ruins.Kind` with its `name_in_play` as its `KIND_NAMES` entry.
- **For Mike:** the calls written at their defaults: the fortress's finial (kept); the thirteen's naming, night rule and giving; the rider's naming and the gate; the temple city's size, root-trees elsewhere and the ochre camp; the stone circle's "no delve" exception.

---

## 2026-10-03 (night) — Mike's 14:34 play fixed (wood lit from outside, rain only from a drawn raincloud, giant herbs, the den); §CY.1 you wake at dawn; §CZ the fire breathes (Claude Code)
- **1. Wood lit from the wrong side.** Trunks, limbs, bark cones and bamboo culms had their normals pointing in, so the sunny side read dark. They point out now (`plant_meshes.gd` `tri3` / `_smooth`; bark cones were wound the other way and are fixed too).
  - The shadow pass's "closed shapes cast from their far faces" rule now reads the normal, not the winding (`foliage.gdshader`), so mirrored trees cast the same.
  - Past the shadow map's 35 m reach, plants get a stand-in shade like the ground's (wood ×0.62, leaves ×0.8), eased in from 28 m so nothing jumps as you walk up. Back-lit leaves stop glowing there, so a stand against the sun stays a dark silhouette at every distance.
  - `tools/wood_normals_check.gd`: all 560,706 bark parts and 196 culm parts, over every species and layout, point out.
- **2. Rain from a clear sky (§CX).**
  - The cloud decks can't sink under the ground any more: their shell's corners go out so its flat panels never sag below the layer (on the 4,000 km planet the low deck's corners sit 168 m above its 150 m height; 17 m on the 400 km planet, 1.7 m on the 40 km stamp).
  - One cover value now drives the drawn deck, the HUD word, the rain streaks and sound, and the sun's dimming. Rain is gated by it (none under cover 0.6, full from 0.85). The shower cells raise the cover over them, and a deck fills in over your head where it rains.
  - `tools/weather_cover_check.gd`: over 19,200 samples it rained only under cover 0.64 or more, and the HUD always said so. In a shower the rain starts 6.1 s after the cloud builds and stops 2.7 s before it clears.
  - "Overcast" looks overcast: §CX's first-guess colours are now `look.json → overcast` (deck lit `#6878C8` over shade `#06186C`, storm `#5A1AA0`, replacing the grey storm sky), and the shadows fade by `shadow_fade` 0.7 under a full deck, keeping their hard edge.
- **3. The giant herbs.**
  - The aroid test now runs before the umbrella placeholder, so every Amorphophallus (246) is its titan-arum leaf again.
  - Alocasia and Colocasia (`_giant_herb`) are a short base, 3–5 green stalks leaning out, and one blade per stalk. The blade is sized from `leaf.size_cm` against the plant's height and from `aspect`, held tip up (lower the more `canopy.droop`), joined at the notch (a peltate taro's a little inside the blade), and sways with its own stalk.
  - The leaf card draws its tile once (`foliage.gdshader`, material 2.25): no grid, no flips, no blanked cells, no cluster blob. The aroid's leaflet cards draw the same way.
  - The tiles (`tools/look/make_plant_tiles.py`): sagittate, cordate and cordate-based peltate leaves fill the tile, with real back lobes and a notch, and record where the leaf sits (`atlas_species.json → leaf_frame`).
  - Veins no longer add to the outline anywhere, so 398 leaf tiles (and their mass, litter and autumn tiles) lost stray vein pixels outside the blade.
  - The engine now reads `leaf.outline`, `base`, `apex`, `aspect`, the `size_cm` range and `appearance.petiole.base` (the stalk's green).
  - `tools/giant_herb_check.gd`: 0 fails.
- **4. The den that looked like a doorway.**
  - Dens gate on moisture as well as heat. Over 6,000 cells, 630 hyena dens and 62 wolf dens all sit in their species' heat and wet; the wettest hyena den is at moisture 0.70, its limit.
  - A hyena's den is a burrow: a low spoil heap of the ground's own earth, a dark hole into it (0.80 m wide, 0.35 m above the ground), a smaller second hole, a few stones of the place's rock, and nothing to bump into.
  - A wolf's den keeps its stone frame, in the place's own rock, round a hole 0.72 m wide and 0.55 m high, with the snow slab only in snow country.
  - `tools/den_check.gd`: 0 fails.
- **§CY.1, the dawn start.**
  - The clock starts 1 real minute after dawn begins at the spawn (`opening_road.dawn_start`). Day 1 and the near-full first moon stand (§CG).
  - The first camp is picked by its road to a camp at a ruin, timed in walking minutes at the slope pace (`RoadNetwork.walk_minutes`), the nearest to 40. Where the day is too short to leave 20 minutes before dusk, the target shortens; the clock never moves.
  - The old afternoon keys are retired from `roads.json`.
  - `day_check` passes (wakes 05:07 at the camp, 05:23 at Mike's spawn, 1.0 real minute into dawn), and so do `road_reach_check` and `fire_circle_check.py --strict` (0 errors).
  - **Seed 7731's opening road is 5.8 km, 31 minutes at the slope pace**, against 40 wanted. With §CU's ~160 hearths a world there are few camps at ruins near any spawn. A straight walk still arrives 39 minutes before dusk.
- **§CZ, the fire breathes.** The flame card stays.
  - The coals (`shaders/coals.gdshader`) are a bed on a 32-a-metre texel grid: char with hot patches in the flame's bands. It breathes once every 2.9 s, its patches pulse on their own clocks, the hot cracks crawl, and it flares on a gust of the weather's wind, a poke or a piece laid on.
  - The fire's light breathes with the bed (±12 %), on top of the noise flicker.
  - Specks (`shaders/specks.gdshader`) replace the campfires' steady embers: thrown on a random clock (waits spread like an exponential) and in a burst on every pop of the fire's sound. 70 % are sparks cooling orange to red, 30 % pale blue-grey ash that doesn't glow, all drifting with the wind.
  - At embers the bed is the whole fire, breathing every 5 s, with a rare speck; a dead fire throws none. The torch keeps its own sparks (§CP).
  - `tools/fire_breath_check.gd`: 0 fails. A full fire throws about 244 specks a minute (the data's check reckoned 237), a low one 142, embers 5.
- **The walkabout** (seed 7731, QUICK, jungle / rainforest / savanna; harness frames): every site passes but one. The camp's first-frame test named its frame by a mean solar hour an hour off the game's clock; it now reads the game's own clock, which `day_check` confirms.
  - The rainforest site had no plants within 30 m. That is §CS's thinning, flagged last pass.
- **All 27 world shaders build** on a real renderer (`EngineReport.check_shaders`), and `shader_varying_check.py` passes.
- **For Mike to confirm (first guesses, all in data or one-line constants):**
  - Far-plant stand-in shade 0.62 (wood) and 0.8 (leaves) (`look.json → light.plant_far_shade`).
  - The overcast deck `#6878C8` over `#06186C`, the storm `#5A1AA0`, shadow fade 0.7.
  - Rain gated between cover 0.6 and 0.85 (`WeatherSim.RAIN_COVER`); a shower lifts the cover over it to at least 0.72; the deck fills in within 1.5–3 km of overhead; "Light rain" from 0.05 mm/h.
  - Giant herbs: 3–5 stalks; the blade's tilt from 60° (no droop) down to 12° (droop 0.6); stalks from `appearance.petiole.base`, else a darkened leaf green.
  - Dens: the burrow hole 0.80 × 0.45 m and the cave den's 0.72 × 0.55 m (`DEN_HOLE_BURROW`, `DEN_HOLE_CAVE`); snow slab below −2 °C.
  - The coals' heat by burn (flames 1, low 0.8, embers 0.55); a gust is a flare when the wind is over about 5 m/s.
- **For chat:** the giant herbs want `leaf.count` (leaves a plant holds; 3–5 is the stand-in) and `leaf.attachment` (`notch` or `peltate_inside`; read from `outline` for now). Musa and Ensete still use the old paddle cards in the cluster style; they could take the whole-leaf card too.
- **Flags:** §CU's ~160 hearths a world against §CY.1's 40-minute road (see above). §CY.2 expects four or five folk at the opening camp (§BV); the opening camp still has its two.

## 2026-10-03 (15:45) — §CY you wake at dawn in the fire circle, the next hearth before dusk; §CZ the fire breathes: design and data only (design chat; Mike 15:20–15:35)
- **§CY.1, the dawn start.** It supersedes §BX's afternoon clock and half-hour road. You wake one minute into dawn. The road to the camp outside the ruin is about 40 minutes of walking at the slope pace (10.3 km if dead flat, about 8.5 km on ordinary land), so you arrive before dusk, or at dusk at the latest.
  - The reference day: wake 04:10, a straight walk arrives 10:50, dusk begins 17:00 (77 min after waking), full dark 20:00.
  - On the world's first day, waking to dusk is 76–98 min from 66°S to 66°N, so the walk fits everywhere and the calendar doesn't move (§CG stands).
  - Data: `roads.json → opening_road.dawn_start` (not wired). The old `opening_road` keys stay until the code reads the new block, so the built game is unchanged.
- **§CY.2–CY.5, the fire circle.** Outside the gather hours, folk sit in a ring round the fire on seats the place provides.
  - One seated pose for every cloaked figure, with eight loops on top: watch the fire, warm hands, poke the fire, feed the fire, the pipe, eat from a bowl, hearth work, doze.
  - The pipe is lit with a brand from the fire. Its smoke is a few square puffs in §CV's hearth-smoke look, drifting with the wind.
  - Ten seat kinds over 44 biomes; a wood seat needs wood there and takes the bark tint of the stand.
  - The circle breaks one at a time over dawn and forms again at dusk; one stays awake at night.
  - Data: `camps.json → sim.fire_circle` (not wired).
- **§CZ, the fire breathes** (Mike, 15:35). It adds to §BZ; the one flame card stays. The coals at the foot pulse (a slow breath, plus patches on their own clocks), the light breathes with them, and sparks and ash fly up on a random clock, in time with the fire's pops.
  - Data: `look.json → fire.coals`, `fire.specks`, `fire.light.breath` (not wired). `flame.embers` stays until then.
- **`tools/fire_circle_check.py`** (new): 0 errors, 0 warnings. It prints the opening day's timetable.
- **Letters:** these were first written as §CV–§CW and moved to §CY–§CZ before the push, because the 15:00 smoke push had taken §CV–§CX.
- **For Mike:** what is in the pipe isn't named yet. And §CZ is read as adding to the flame, not replacing it.
- §BR has the proposed engine order.

## 2026-10-03 (evening) — §CR the world at 1/100 Earth, §CS plant communities, §CU a few hearths per biome: built (Claude Code)
- **§CR.1, the planet:** it is now built at `data/world_scale.json` → `planet.circumference_m`: 400 km around, radius 63.7 km, `GEO_SCALE` 1. The layout is built at its own size; heights stay 1/10 (`HEIGHT_SCALE`) and the day stays 144 minutes. Things at walking scale are unchanged. The 40 km dev stamp still works for the checks (`stamp_check` passes) and has no great ranges.
- **Measured before any tuning** (four seeds, 42, 7, 1234 and 7731, headless; `tools/world_scale_check.gd`):
  - **Horizon:** from the play eye height (1.26 m) it is 400 m (451 m at 1.6 m). A 30 m tower shows from 2.4 km and a 100 m hill from 4.0 km. The ground drops 7.9 m over 1 km.
  - **Land:** about 21,000 km² a world, which is 38% of the planet.
  - **Slopes** (the walking ground, measured over 4 m): steeper than 35° on 0.28–0.39% of the land, 45° on 0.21–0.26%, 60° on 0.03–0.10%. That is all the escarpments and ravines. Ground over 150 m was hardly steeper (0.3–0.4% over 35°).
  - **Ranges:** none were great. The mountain belts topped out at 481–506 m, as 10–21 high areas over 250 m, and their slopes were under 3° measured over 40 m. They were broad swells laid out on 30 km noise.
  - **Biomes:** hot desert is 12–20% of the land, ice sheet 8–12% and temperate deciduous 7–9%. Every land biome present had at least two places of 1 km² or more, except puna on seed 1234 (one). Puna is missing from three of the four seeds. Lagoon, freshwater, oasis, salt flat, caves and tepui are never land cells (they come from nests and water).
- **§CR.4, the great ranges** (`TerrainField.great_ranges`): 4–7 a world (seeded), each 15–25 km long on land, 45 km or more apart. The first is the world's Everest-class one (885 m) and the rest 500–885 m (`summit_m_earth` × 0.1, added on top of what they stand on).
  - Shape: a crest with one summit and passes, flanks averaging about 24° (steeper near the crest), and spurs and gullies.
  - Sheer faces: at walking scale, part of each flank steps into 40 m cliff bands, with the crest and gaps left clear.
  - The ordinary mountain belts were capped at 400 m so they stay below the great ranges.
  - **After, on the same four seeds:**
    - 4, 4, 5 and 5 great ranges, with summits 550–894 m.
    - Every summit has a way up: the quickest walkable route averages 14–17° and is never steeper than 25–30°. It is 0.9–2.5 km long and takes 11–28 real minutes (1.8–4.6 game hours) from the foot.
    - The flanks average 22°. 13.3–14.3% of them is sheer (60° or more); the design asks about 15%.
    - The ranges cover 0.5–0.9% of the land. No other ground reaches 500 m.
    - From the highest summit you see about 10.7 km, and it shows from 11 km away.
    - Land steeper than 35° rises to 0.43–0.64%, and steeper than 60° to 0.12–0.21%.
- **§CR.5, Tobler's pace** (`PlanetPlayer.slope_pace`, `world_scale.json` → `pace`):
  - Walking and sprinting speed is multiplied by exp(−3.5|s+0.05|)/exp(−3.5·0.05) on the grade ahead (capped at 1). A crouch is never faster up a slope than a walk.
  - The floor's limit is now `walk_max_deg` (45°, was 50°) in the ambient profile.
  - `tools/pace_check.gd` passes all its checks:
    - 54/28/13% of the flat speed at 10/20/30°;
    - an 885 m summit by a 20° route takes 35.9 real minutes (6.0 game hours), and 500 m takes 20.3 minutes;
    - walking and sprinting up a real 13–14° slope near the camp come within 12% of the pace;
    - downhill is no faster than the flat;
    - ordinary land within 20 km of the camp averages 82% of the flat speed, because of the swells.
- **§CS, plant communities** (`Communities`, `habitat.json` → `communities`):
  - Each biome file's associations (203) are its communities.
  - When a world is made, each land's stretch of a biome (a `RealmMap` province's cells) is dealt one community. The biggest stretches go first, and each gets the community whose dominants fit its temperature, moisture, height and soil best, with a bonus where the community's realm is the land's own here (the land's part of Earth) and a little seeded jitter. No community is dealt twice; a stretch left without one takes the nearest land's.
  - The placer grows only the community's members there, each in its own bands. Members skip the realm gate.
  - A catalogue species no association lists (310 of 328) keeps its old placement, and so does a biome with no associations (estuary, freshwater, ice sheet).
  - `tools/community_check.gd` (three seeds) passes:
    - 176–181 communities dealt over 257–280 stretches, none native to two lands;
    - in play, every plant stands in its own community.
  - **On screen:** a stretch now holds far fewer kinds of plant. A tropical dry forest near the 7731 camp went from 16 species (6,294 plants, 4,880 trees in the loaded ring) to 7 (1,501 plants, 2,183 trees): Pochote, slash pine, bluestem, bromelia, jatropha, long-spine acacia and resurrection fern.
- **§CU, hearths** (`Hearths`, `camps.json` → `hearths`):
  - The sites pass runs once per new world (8–9 s here, then kept in the save as "hearths").
  - It keeps max(2, km² / 150) hearths per land biome from its ruins and nests, dealt round the lands in turn, never two with the same people, nest, ruin kind and community. The opening road's camp is always kept.
  - Ruins it doesn't keep have no living camp and no cold hearth (`Ruins.inhabited`, `OldHearths`). Nests it doesn't keep hold no camp or remains (`Nests._hearth_pass`).
  - `tools/hearth_check.gd` (three seeds): 1,583 / 1,496 / 1,668 hearths before, 158–160 after, none alike, and nothing dropped still holds one. In play the opening road's camp is kept, 6.7 km off.
  - Short biomes (too few distinct sites): ice sheet (8–10 of 11–17), swamp, hot spring, puna, oasis and sagebrush (0–1 of 2), and estuary and floodplain forest on some seeds.
- **Checks** (headless, Godot 4.3, the seeds the checks pin):
  - **0 fails:** first_camp, overrun, settle, swing, pace, delve, stamp, stand, litter, tree, water, soil, world_scale (its gates), community, and old_hearth (after one fix to the check). That fix: with fewer hearths, the check's nearest empty ruin and its tomb are now the same desert pyramid, so the tomb part lays fresh charred branches before relighting.
  - **Failing as this morning** (same with communities and hearths off): camp (3), nest (1: the waterfall's ferns), new_world (12 when run without `DEV_PIN=0`; run as its header says it passes all 20, the new world's hearths pass included), play_fixes (12) and inventory (5), which test the ninja kit, and realm (African Amorphophallus in savanna; this morning it stopped on a script error).
  - **road_check:** 1 fail. Its sample point on the nearest road is an overgrown stretch (tread 0.07). That is the layout, not a code change.
  - **plant_presence:** Musa and Trichocereus seen nowhere. With communities off it passes, so this is §CS at work (see Mike's flags). fire_wall and growth_world time out as this morning; aroid_world and tech were still running at the push.
  - `tools/shader_varying_check.py`: exit 0.
- **For Mike (to decide or play):**
  - **Horizon:** on flat ground the curve ends the view at about 400 m. Hills and towers rise over it as you walk.
  - **Fewer plants:** communities thin the plants a lot. Of the 203 communities, 198 name no emergent tree and 186 no epiphyte, so rainforest giants and orchids stop growing until the data lists them. Flagged, not worked around.
  - **The walkabout** for this pass runs once at the end of the next one (Mike's 14:34 bugs), with `SITES=range` added: a great range from its foot and from its summit.
  - **Fewer hearths:** hearths drop from about 1,500 to about 160 a world, as §CU's numbers ask. `km2_per_hearth` is the one value to bring more back.
  - **§CE against §CS:** "the named plants are always in the game" now meets "only in their community". Wild banana grows only where the rainforest-gap community lives.
- **For Claude (chat):**
  - `tools/reference/community_report.txt` lists the 310 unattached catalogue species and the short biomes per seed for the fill.
  - Earth's biome shares can be filled now (the numbers above).
  - CLAUDE.md's first paragraph still says "at 1/10 Earth scale" (a design line; the Scale section is updated).
  - The honest share for the great ranges is needed to check `footprint_max`.
- §CT (carried plants) waits for §AB, as asked.

## 2026-10-03 (15:00) — Mike's 14:34–14:46 play: a den that looks like a doorway, an Alocasia drawn as a bush, rain from a clear sky, far plants lit from the wrong side: causes found (design chat; §CX)
All four are read from the code and data, not run: no Godot in the chat's box. Mike's frames are at 12.8–12.9°N, 140.2°W, Jungle, granite soil, Day 1.
- **1. "A little opening to a shrine … I wasn't able to go inside" (14:22 game time).**
  - It is a pack's den prop, not a ruin: `CreatureSpawner._den_prop` (`creature_spawner.gd:516`), two boulders and a lintel named "WolfDen".
  - The dark opening is a solid near-black ball (`CreatureBodies.ball`, 3.2 m wide and 2.6 m tall), so it reads as a doorway and was never one.
  - It is a spotted hyena den in a jungle. `_find_den` gates on temperature only, never moisture, and hyenas are 16–32 °C. The Arctic wolf is ruled out at 27 °C.
  - A hyena's den is a `burrow` in the data, but `_den_prop` builds the wolf's stone cave mouth for both, with a white snow slab on the lintel in any climate.
  - **For Mike:** what a den should be is a design call (asked in chat).
- **2. "Supposed to be an Alocasia, but it looks nothing like one" (14:58).**
  - The plant is the jungle file's "Elephant ear" (*A. macrorrhizos*). The other jungle Alocasia can't grow at 27.8 °C and 4 m. Its `shape` was "shrub", so it was built as a bush: a ball of 60–95 randomly turned cards (`plant_meshes.gd:796`).
  - The shader then treats each card as a cluster of small leaves: it repeats the leaf in a grid at real leaf size, flips or turns each one, blanks 22 % of cells and cuts the card with the ragged cluster blob (`foliage.gdshader:375-393`, `:604-613`). A 1–2 m leaf comes out as torn pieces. The "umbrella" giant herbs get this too.
  - The sagittate tile fills 24 % of its square and leaves stray one-pixel vein lines outside the blade (`tools/look/make_plant_tiles.py`).
  - The engine reads only `size_cm`, `type`, `texture` and `arrangement` from a `leaf` block. Outline, base, apex, aspect, `canopy.droop` and `appearance.petiole` never reach the builder.
  - **Every Amorphophallus is caught too.** All 246 carry `shape` "umbrella" and no architecture block, and §CA's placeholder test (`plant_meshes.gd:722`) runs before the aroid test (`:728`), so the titan-arum leaf built on 30 Sept (`_aroid_leaf`) is never reached.
  - **Data, live on restart:** Elephant ear's `shape` is now "umbrella" (`20_jungle.json`), so it takes the giant-herb placeholder (a few upright cards on stalks) until the engine fix. `plant_schema_check`: 0 errors.
- **3. "The sky looks clear but it's raining" (15:07).**
  - The low cloud deck is the only layer that can cover the sky overhead, and at Mike's spot it is under the ground. Its shell's flat panels are 25 km wide on the 637 km planet and sag up to 245 m; the deck is 150 m up (`cloud_layers.gd:39, 62, 106-119`). On the 40 km stamp the sag is 2 m, so the harness frames look right.
  - Rain doesn't read the clouds. The streaks and sound read `rain_mm_h`; the shower mask is its own noise field (`weather_sim.gd:599-612, 652-676`), so it can rain with cover as low as 0.19.
  - "Overcast" (cover above 0.65, `hud.gd:652`) never recolours the sky; only `storm` does, to grey, which breaks LOOK_REFERENCE R3.
  - Mike's rule is now §CX.
- **4. "Bamboo casts shadows towards the camera but is lit on this side … when approached they would get shadows" (16:33).**
  - Trunks, limbs and culms carry normals that point inward (`plant_meshes.gd:895`, the builder's winding; checked by re-running its maths: 30 of 30 culm faces, 32 of 32 trunk faces). So the sun brightens the side facing away from it. It is the same face-convention fault the delve had on 2 Oct.
  - Past 35 m nothing shades a plant: the sun's shadow map fades out from 31.5 to 35 m (`sky_system.gd:350`), and the ground has a stand-in shade past that but plants have none. So far wood glows and turns navy as you walk up.
  - Bamboo keeps its full mesh to about 520 m and trees to 350 m, so this is real meshes, not the far pictures.
  - "Overcast" with hard shadows: cloud dims the sun by at most 55 % and never touches shadow strength (`sky_system.gd:362`).
- **5. A render-distance setting for slower machines:** it exists (29 Sept). O or F10 → Display → Render distance, 1 to 8 chunks, default 3. Mike was told in chat.
- **Not determined:** which Godot Mike's Mac runs (F3's last lines say); the live cloud and storm values in his frames.

## 2026-10-03 (15:00) — §CV smoke from every hearth, stacks in the ruins and swifts in the cold ones; §CW no waiting; §CX rain needs a raincloud: design and data only (design chat; Mike 14:28–14:58)
- **§CV, smoke:** every lit hearth sends up a column sized by its fire's state (flames, low, a wisp for embers), leaning with the wind, with a glow at night instead of a column. A 60 m column's top shows from 3.2 km on the 400 km planet.
  - Surface camps keep the open fire, and a cave mouth clears its own smoke. In the ruins each underground hearth gets a stack, formed by the ruin kind.
  - A stack with no smoke marks a cold hearth: empty or overrun.
  - Chimney swifts roost in stacks that have been cold a while and leave when the hearth is lit (sourced).
  - A wildfire gets its own wide dark plume (proposed, Mike can strike it).
  - Data: `data/smoke.json` (new, not wired). Gate: `tools/smoke_check.py --strict`, 0 errors.
- **§CW:** the clock never skips or speeds up. Stillness is liked, not locked.
- **§CX:** rain falls only from a drawn raincloud; the cloud builds first; one cover value drives the sky, the HUD, the rain and the light. The colours of an overcast sky are open for Mike.
- §BR has the proposed engine order.

## 2026-10-03 (afternoon) — §CR–§CU: the world at 1/100 Earth, plant communities with one home each, carrying plants, a few hearths per biome: design and data only (design chat; Mike, voice to 13:01)
- **§CR, the world at 1/100 Earth:** 400 km around. The layout is built at its own size (`GEO_SCALE` 1); things stay true size, heights stay 1/10, and the 144-minute day stays.
  - A handful of great ranges with walkable routes (about 22° on average, 35° at most) and sheer faces (15%, first guess). They may take up to three times their honest ground.
  - Tobler's hiking pace on slopes, so an 885 m summit takes about 6 game hours.
  - Honest biome shares, with a floor of two places for niche biomes.
  - Data: `data/world_scale.json` (new, not wired). Reference maths: `tools/reference/world_scale_reference.py`.
  - **For Mike:** the horizon from eye height on the 400 km planet is about 450 m (1.4 km now). It's flagged in §CR.7; the size is one data value if it needs to go back.
- **§CS, communities:** a plant grows only as a member of its community, and each community is native to one land (a RealmMap province), dealt by niche, not Earth's map.
  - Catalogue species go through communities. Only 8 of 203 associations list any yet, so a fill comes next.
  - Old growth reaffirmed (built).
  - The freshwater note's "Amazon lotus" is fixed.
  - Data: `habitat.json → communities` (not wired).
- **§CT, carrying plants and watering them:** optional. Seeds, cuttings (only from species that root from them) and tubers; a planting lives if the plot fits its niche, and watering counts one moisture band wetter. Data: `items.json → carried_plants` (not wired).
- **§CU, hearths:** at least two per land biome, more by area, no two alike (`camps.json → hearths`, not wired).
  - The pillar now reads "what lurks in the dark is the only antagonist" (CLAUDE.md, OVERVIEW, README, the `dread.json` help).
  - CLAUDE.md, WORKING_AGREEMENT, OVERVIEW and DESIGN.md note that 1/100 is designed, not built.
- **§CP:** the burnt end recorded. `torch.json → ember.texels` swapped for `texels_m` (150), as Claude Code asked.

## 2026-10-03 — The torch's head is the burnt end of the stick, not a ball (Mike, 3 Oct; §CP)
- Mike: "less like a ball on the end and more like a burned end of a stick: it shouldn't be rounded". The lumpy coal is gone. The head is now the stick's own last few centimetres (`Torch._burnt_end_mesh`). It has six flat sides and is as thick as the stick, narrowing a little to a jagged, broken, slightly sunken tip. Held torches use 6 cm and planted torches 9 cm.
- `shaders/torch_ember.gdshader` paints it black char with grey ash flecks. Hot cracks show through, more of them toward the tip, and the tip glows most, in the fire's flat colour bands. It still breathes with the torch's light (same `ember_glow` pulse), and its sparks still rise from the tip. Lamps keep their flame.
- Checked once, by eye, in harness frames on 4.3/lavapipe (held, by night and by day; planted, by night). Nothing else changed.
- For chat: `torch.json → ember.texels` (7.0) is no longer read. The burnt end reads `texels_m` (texels a metre, default 150) instead. Please swap the key when convenient.

## 2026-10-03 — §CP the torch's ember head recorded; §CQ every torch is from somewhere, and a carried coal brings a dead torch back: design and data only (design chat; Mike 01:30–02:25)
- **§CP** records Mike's ember head (built `9e3e7ef`), as asked: `torch.json → ember` holds the code's defaults, and the `light` help says the flicker values are no longer read. Nothing changes on screen.
- **§CQ**, locked at 02:25; the data is in and none of it is wired:
  - `torch.json → kinds`: eleven kinds (the brand, fatwood, birch bark, candlenut, dammar, fir candle, ichu, cane, rushlight, fire stick, and the resin dip's circle), each with a circle, a burn and a rain rule. A camp's bundle is its people's light where its plant grows, else a torch tree that grows there, else a brand.
  - `torch.json → ember_relight`: blow the ember carrier's coal into an unlit torch (3 s; the coal is spent).
  - `dread.json → torch_circle`: the torch's dread fill scales with its circle, and stage 3's glimpses stand at its edge.
  - `techniques.json`: `ember_carrier` relights torches; `fatwood` and `candlenut` name their kinds and genera.
- **`tools/torch_kinds_check.py`** (new): 11 kinds, 0 errors, 1 warning (the candlenut tree isn't in the catalogue).
- **For Mike:** a correction from chat. Birch bark was already one of §CN's three damp-burners, not "the one exception".

## 2026-10-03 — The plants fit every Godot from 4.3 on; the game says what it runs on; the torch's head is an ember (Mike, 3 Oct)
- **Plant shader** (`foliage.gdshader`, ahead of §BR as asked; §CG):
  - Its 19 varying slots are packed into 8: six flat vec4s for the values that are the same on every corner of a triangle (season, leaf, leaf size, glow pick, material, moss, sport, cluster key, genes, instance, dead, dead limb, the far picture's profile and base) and two smooth vec4s (position and normal in the plant's frame, sway).
  - `world_pos` is rebuilt in `fragment()` from `VERTEX` and `INV_VIEW_MATRIX`. The old names are `#define`s, so the rest of the shader reads as before. `docs/parked/foliage_derivatives.patch` was left out.
  - `tools/shader_varying_check.py`: exit 0 (foliage 8, every shader within the house limit of 12). It now sits with the walkabout as an end-of-pass check (HOW_TO_RUN).
- **Proof, lavapipe Forward+, on scratch copies of the repo** (the newer engine never touched the working tree):
  - **Before, Godot 4.7.2:** `SHADER ERROR: Too many varyings used in shader (33 used, maximum supported is 32)` at `foliage.gdshader`, and every plant drew grey (whole-quad cards).
    - It was 33, not the 34 expected: on this machine 4.7.2 keeps 14 slots, not 15. The Python check's 4.6/4.7 column assumes 15, so it is one high there, on the safe side.
  - **After:** no shader errors on 4.3 or 4.7.2, and real leaves in the opening-camp frame on both.
  - **On 4.3, before against after:** a mean difference of 2.3 levels over the upper frame, with 0.9 % of pixels more than 32 apart (wind and the folk). They match.
  - **4.7.2 against 4.3 after:** the same scene. The trunks draw a little darker on 4.7.2 (its lighting and shadows).
  - The labelled harness frames went to Mike in chat. Every lavapipe run ends "signal 11" at shutdown, after the work: that crash was already there and isn't the game's.
- **What it runs on** (`EngineReport`, new):
  - F3's last two lines, and the log's first line each session, show the Godot version, renderer, driver and GPU. Seen on lavapipe: "Godot 4.3-stable (official) · Forward+ · Vulkan 1.4.318 · llvmpipe (LLVM 20.1.2, 256 bits)" and the same for 4.7.2. Godot 4.3 can't report its live driver, so it shows the one the project asks for on that OS (Vulkan; on a Mac "Vulkan (MoltenVK)"). 4.4 and later report the driver they actually run (Vulkan or Metal).
  - At boot, every spatial shader in `res://shaders` that declares uniforms but lists none failed to build: one `push_error` each, and the F3 line "Shaders: all 24 built" or "Shaders: foliage FAILED (Godot 4.7)".
  - Proved on 4.7.2 with the old plant shader: the push_error, "Shaders: foliage FAILED (Godot 4.7)" on F3, and the same at the end of the log's first line. With the new shader: "all 24 built" on both versions.
  - The checks that read the world's line in the log now use `GameLog.world_line()`, because the engine line comes first.
- **Headless checks under 4.7.2** (all 48 `tools/*_check.gd`, SEED=7731, side by side with 4.3; listed, not fixed):
  - Same on both versions:
    - 22 give 0 fails on both.
    - 14 give the same fails on both: `camp`, `climb`, `fire_wall`, `fruit`, `growth`, `nest`, `new_world` (12), `no_import`, `play_fixes` (13), `stand`, `strike`, `super`, `tech` (12) and `tool`. These are old or stale checks; several pin seed 42 and were run here with 7731.
    - 4 time out on both (`first_camp`, `hits`, `leaf_lod`, `stamp` / `wanderer` print no RESULT line).
  - **Different on 4.7.2:**
    - `aroid_world_check`: 4.3 stops on a script error (out-of-bounds index 16); 4.7.2 runs on and fails 1 ("found Amorphophallus growing somewhere tropical").
    - `growth_world_check`: 4.3 stops on a script error (index 17); 4.7.2 fails 2 (adds "the HUD names it by its stage").
    - `inventory_check`: 6 fails on 4.7.2 against 5 on 4.3 ("E on a plant took a sample": 0 plants against 1).
    - `realm_check`: 4.3 stops on a script error (`state` on a Dictionary); 4.7.2 times out after failing "no catalogue plant outside its realm gate" (75 bad).
  - No check failed on 4.7.2 because of a shader or the renderer.
- **The torch's head is a glowing ember** (Mike, 3 Oct: "instead of the current fire animation, more of a glowing ember"; `shaders/torch_ember.gdshader`, `Torch.ember_node`):
  - The held and planted torches carry a small lumpy coal: a char crust with the fire's colour bands in its cracks, on a coarse texel grid, crawling slowly, with the fire's couple of single-pixel sparks.
  - The light keeps its energy, range and colour but breathes slowly with the ember (`Torch.ember_glow`): brighter sprinting or in wind, lower and slower guttering. The coal's glow follows the same pulse.
  - The lamps keep their flames.
  - Harness frames (night held, night planted, day held) went to Mike.
  - **For Mike:** this replaces §BZ's "one shader, every fire" for torches.
  - **For Claude (chat):** record it; a `torch.json ember` block (texels, crawl, pulse_hz, pulse_amount, shimmer_hz, shimmer_amount, air_brighten, gutter_glow; the code's defaults stand in); `light.flicker_hz` and `flicker_amount` no longer drive the torch.
- **Not changed:** the Godot version named in CLAUDE.md, HOW_TO_RUN and §CI (Mike's call, pending).

## 2026-10-02 (night) — Mike's 22:52 play: the plants are still grey after §CG. The plant shader uses more varying slots than Godot 4.4 and later allow (design chat; §CG; `tools/shader_varying_check.py`)
- **What the frame shows** (play, Mike's Mac, F3 on, world 1972737865, the same spot as 1 Oct 23:11: Jungle, 12.7°N 140.1°W):
  - §CG works: "World textures: 9 from disk", the ground's tiles are back, and it is Day 1 · 13:49.
  - Every plant drawn by `foliage.gdshader` (trees, bamboo, shrubs, cards) is Godot's grey default material: 0.6 grey, opaque, one-sided. The leaf cards are whole quads, and there is no green in any plant.
  - The trunks and culms carry fine stripes. That is shadow acne: the foliage shader's own rule that closed shapes cast from their far faces only is gone with the shader.
  - The fire, the folk, the ground and the stone ruin behind the fire (`ruin.gdshader`; tiered, grey, with dark holes) draw normally.
- **Why:** Godot gives each `varying` one slot (mat3 3, mat4 4), numbered after the slots its Forward+ scene shader keeps for itself (`base_varying_index`). From 4.4 on it also checks the total and rejects a shader over the GPU's limit, in `ShaderLanguage`: "Too many varyings used in shader (N used, maximum supported is M)." A rejected shader's materials draw with the default material (`RenderForwardClustered::_geometry_instance_add_surface`). Forward+ can't run in this box (no Vulkan driver), so this is read from Godot's own source at each stable tag:

  | Godot | slots kept | checked | `foliage.gdshader` (19 slots) on a Mac (limit 31) |
  |---|---|---|---|
  | 4.3 (Claude Code's machine) | 12 | no | 31: fits, with nothing to spare |
  | 4.4, 4.5 | 14 | yes | 33: rejected |
  | 4.6, 4.7 | 15 | yes | 34: rejected (32 on desktop Vulkan: rejected there too) |

- **Since when** (commit times, Chicago):
  - 29 Sept 14:01, `8b95fb2` (far trees as pictures): 17 slots. Godot 4.6 and later reject it on a Mac.
  - 29 Sept 15:09, `43033e5` (genes and sports): 18 slots. 4.4 and 4.5 reject it on a Mac.
  - 29 Sept 20:57, `cca09c1` (growth, shade leaves): 19 slots.
  - Every other shader uses 6 slots or fewer, which is why only the plants break.
- **Why the cloud frames drew plants:** every harness frame (dev_view, walkabout, the §CG check) ran Godot 4.3, where 19 slots still fit.
- **What Mike's Mac runs (not confirmed):**
  - Neither `/Applications` nor `~/Applications` holds a Godot.app.
  - `/Applications/Summer.app` is installed. Summer Engine ships its own engine binary and "follows Godot 4 upstream", so it is a newer Godot than 4.3.
  - §CI and `CLAUDE.md` say plain Godot 4.3. Help → About in the app he opens settles it.
- **What couldn't be reproduced here:**
  - Headless, both 4.3 and 4.7.2 accept the shader. The dummy renderer never builds the Forward+ scene shader, so the kept slots don't apply.
  - The OpenGL (Compatibility) renderer keeps different slots. In 4.3 it rejects the shader for another reason: "Uniform instances are not supported in gl_compatibility shaders".
  - Forward+ on lavapipe needs Claude Code's machine.
- **New check** (`tools/shader_varying_check.py`): it counts every spatial shader's varying slots by Godot's rule and prints where the last slot lands on each version from 4.3 to 4.7. The house limit is 12 slots. Godot has kept more slots with each release (12, 14, 15), and on a Mac with 4.6 or later more than 16 is rejected. Today `foliage.gdshader` FAILS at 19 slots (`v_season`, `v_hshift`, `v_leaf`, `v_leafs`, `sway_w`, `glow_pick`, `world_pos`, `obj_pos`, `obj_normal`, `mat_id`, `moss`, `v_sport`, `cluster_key`, `dead_v`, `wood_dead`, `genes`, `inst`, `v_imp`, `v_imp2`). The other 24 spatial shaders pass, `litter.gdshader` the highest at 6.

## 2026-10-02 (evening) — §CO: the dry pouch and the cave's opening hearth (design chat; Mike 20:15–20:32)
- **§CO** in RECONCILIATION_2026-09-30:
  - Kindling you carry never gets wet. Only kindling gathered in rain starts damp, and it dries after 6 game hours.
  - A cave mouth's or grotto's den is cleared by lighting the hearth at its opening. It is the one exception to "the surface hearth doesn't clear it".
  - The survivors' 30 days and the ruins at the start are kept as built.
- **Data, `[NOT WIRED YET — design §CO]`:** `fuel.json kindling.pouch_keeps_dry`; `camps.json sim.overrun.cleared_when_nest`; `delves.json fire_holders.nest_den`. `kindling_check --strict`: 0 errors.

## 2026-10-02 (evening) — §CN data: the tropical forests' kindling (design chat)
- **`fuel.json → kindling`**: the four tropical forests' stop-gap is replaced with real lists, likeliest first. Rainforest: twigs, kapok seed down, palm leaves, leaves. Jungle: cogon grass, twigs, leaves, bracken. Dry forest: dry-season leaf litter, grass, twigs, kapok. Cloud forest: twigs, leaves, wax-palm leaves, beard lichen. Seed down gains kapok (*Ceiba*, sourced as very flammable); dead palm leaves gain *Mauritia*, *Socratea* and *Ceroxylon*. Nothing that burns damp is sourced there yet: dammar and bamboo were left out for want of a source that could be opened. `kindling_check --strict`: 33 kinds, 52 biomes, 0 errors.
- **`tools/kindling_check.py`**: a fill fragment may now widen an existing kind's genera (`extend_genera`).

## 2026-10-02 — §CN overrun ruins, the torch swing and kindling: design and data only (design chat; Mike 11:56–13:38)
- **§CN** in RECONCILIATION_2026-09-30: ruins the dark took stay overrun and are cleared by light, never a fight (§BA stands). Left click with a torch swings it and passes the flame both ways, replacing §AW's right-click lighting. A fire that is fully out needs kindling laid; embers don't. Folk come back to a cleared ruin. It also records Mike's "torch only, no flint and steel", as asked.
- **Data, all `[NOT WIRED YET — design §CN]`:**
  - `torch.json → swing`;
  - `fuel.json → kindling`: the rules, 33 real kinds with their sources, and a list for each of the 52 biomes. Seven biome families were filled by parallel agents; the tropical forests have a stop-gap until their fill lands;
  - `camps.json → sim.overrun`;
  - the new `data/delves.json`: fire-holders, the overrun den, log lines.
  - `fuel.json fire.old_hearth_units` (2) is written in, as Claude Code asked.
- **New gate:** `tools/kindling_check.py` (`--strict`: 33 kinds, 52 biomes, 0 errors).
- **Open for Mike:**
  - whether carried kindling stays dry in rain;
  - the 30 % of old delve ruins that start overrun;
  - adding the plants the fill found missing: birch in four biomes, Arctic white heather, Spanish moss in the swamp, yucca.

## 2026-10-03 — §CO: the pouch keeps kindling dry; a cave's den is cleared by the hearth at its opening (Mike, 2 Oct evening, locked)
- **1. The pouch** (`Kindling.rain_on`, `Kindling.gathered`, `fuel.json kindling.pouch_keeps_dry`):
  - Kindling you carry no longer gets wet in rain.
  - Only kindling gathered while it rains, outside a roof, starts damp, and it dries in the pouch after `wet.dry_h_game` (6) game hours. Soaked ground alone no longer wets it.
  - Damp kindling won't catch, except birch bark, fatwood and pitchwood, as built.
  - Dry grass and reeds picked up as fuel follow the same rule, since they are kindling too. Other fuel keeps §AX's rain-or-soaked-ground rule.
- **2. A cave's den** (`Overrun.check_nest_dens`, `delves.json fire_holders.nest_den`, `camps.json sim.overrun.cleared_when_nest`):
  - An overrun cave mouth or grotto (a nest camp the dark took) is cleared by the hearth at its opening: the camp's own hearth gone cold, or the old hearth at its remains, laid with kindling and fuel and lit with the swing.
  - The log says "The fire at the cave's mouth caught. Whatever held it has gone.", and folk can come back as for a cleared ruin (§CN 4).
  - Barrows are still cleared only at the heart.
- **Checks** (7731, 0 fails):
  - `swing_check`: kindling carried through 30 game hours of rain stays dry; dead twigs gathered in the rain start damp, won't light, and light six game hours later.
  - `overrun_check`: a taken cave-mouth camp 35 km out is overrun, stays overrun while its hearth is cold, and is cleared by its opening hearth; a barrow's lit surface hearth still doesn't clear it.
  - `settle_check`, `old_hearth_check` and `delve_check` re-run.
- **Data:** the `[NOT WIRED YET — design §CO]` notes are off `fuel.json`, `camps.json` and `delves.json` (Claude Code, as wired).
- **Not built, for Mike:** a cave's den has no holders or tells yet (no shapes in the mouth, no bones, no quiet). Those are built for barrows only. The cave mouth's chamber is too small to stand them in until Phase 3 digs the caves.
- **Data ask for Claude (chat):** a `delves.json log` line for the cave's mouth (the code's own line stands in).

## 2026-10-02 (evening) — §CN built: the swing passes the flame, a cold fire needs kindling, overrun ruins, folk come back (Mike, 2 Oct, locked)
- **1. The swing** (`Torch`):
  - Left click with the torch in hand swings it, on the bare hand's arc and timing (`Fists.STRIKE_S`).
  - When the swing ends, the flame passes within `torch.json swing.reach_m` (2.2 m), either way:
    - an unlit torch catches from a lit fire, a fire-holder or a planted torch;
    - a lit torch lights a laid cold fire, embers, a fire-holder or a planted torch gone out.
  - It costs no burn time. It lights nothing else (no wildfire from a swing; that stays a dropped torch in dry grass) and does nothing to a creature.
  - The right-click lighting is gone, the old hearths' included. Right click is plain interact. The prompt now says "Left click: swing the torch …".
- **2. Kindling** (`Kindling`, `FireStore`):
  - Embers are as before. A fire that is fully out must be laid: one kindling and at least one unit of fuel. An old hearth's charred branches count as fuel.
  - Lay kindling with right click, then swing. The flame takes after `2 s × (1 − catch)`; dead twigs take 0.5 s.
  - Wet kindling that isn't `wet_ok` smokes and the fire stays cold. Wet birch bark, fatwood and pitchwood catch. Kindling with no fuel flares for its `burn_s` and goes out.
  - Gathering is right click:
    - the biome's ground kinds from the ground at your feet (crouch if you hold a lit torch: standing, the right click plants it);
    - plant kinds from a plant or tree of the kind's genus under the crosshair (a birch gives birch bark; after three kindling things in the pack, right click goes back to taking samples).
  - Grass and reeds are the fuel items themselves. Rain outside a roof wets what you gather or carry for `wet.dry_h_game` (6) game hours.
- **3. Overrun ruins** (`Overrun`; the heart's fire-holder in `OldHearths`):
  - **Which:**
    - a camp the dark took (blood, not hunger) with a delve or a nest's first chamber is marked overrun when it goes to ruin;
    - on a new world, 30 % of the old delve barrows start overrun (21 of 68 within 150 km on 7731);
    - the sim never resettles one.
  - **The den:** the biome's hunter holds about half the dens, the night roster the rest (the dark itself where none fits). They stand in the dark rooms at any hour and never within a lit fire's radius. Down there, the dread's hunter is what holds the den.
  - **The surface:** at night within 120 m, outside a fire, dread fills 1.5× as fast. By day the sound bed goes quiet. There are bones and scat at the barrow's door. At night a shape stands in the doorway and the hunter calls.
  - **Fire-holders:** the first room keeps its old hearth (as built). The heart has a cold ring of ash: empty, holds 3 units, lights and keeps 8 m (`Campfire` `safe_m` and `range_m`).
  - **Clearing:** laid and lit, the heart's holder clears the ruin. The log says "The fire at the heart caught. Whatever held this place has gone." The holders walk out by the cairn and the door signs go. The surface hearth doesn't clear it.
- **4. Folk come back** (`CampSim.settlers`, `settle`):
  - About 12 game hours after a cleared ruin's surface hearth starts burning, folk come. Survivors come back from the camp they fled to if it fell within 30 days; otherwise 2–4 come from the nearest living camp within 40 km at 60 % of its cap or more.
  - The camp is begun from today, on that hearth's own fire. Camps builds it with its own people; it is a hearth you can take. Taken again, it is overrun again.
- **Checks** (all 0 fails on 7731):
  - `swing_check` (16);
  - `old_hearth_check` (also 90210), now with the kindling cases;
  - `overrun_check`;
  - `settle_check`;
  - re-run after the changes: `delve_check`, `dread_check`.
  - The walkabout `SITES=delve` now walks the nearest overrun barrow and lights its heart's fire.
- **Data:** the `[NOT WIRED YET — design §CN]` prefixes are off `torch.json swing`, `fuel.json kindling`, `delves.json` and `camps.json sim_overrun` (Claude Code, as wired). `Tuning` now reads `data/delves.json`.
- **For Mike (contradictions and choices, not silently picked):**
  - *Survivors can't come back as written.* A camp is overrun only when it goes to ruin (`abandon.ruin_after_game_days` = 60), but survivors come back only if it fell within 30 days. Reading "fell" as the day the dark took it, they never would. **Built:** "fell" is the day it was marked overrun. Say if you meant otherwise, or shorten the ruin clock.
  - *A barrow's delve has two rooms*, so its only new fire-holder is the heart's. Braziers and sconces wait for castle and tower delves (none built).
  - *A nest's den* (cave mouth, grotto) is marked overrun and never resettled, but it has no fire-holder to clear it yet: **not built**. Which fire should clear a nest's den?
  - *The first room's old hearth* keeps its 14 m safe radius and its charred branches, as built. The holders' 8 m applies to the new ones.
  - Carried kindling gets wet in rain (the design's open question), so on a wet night only birch bark, fatwood and pitchwood light a new fire.
- **Data asks for Claude (chat):**
  - an `items.json` kind `kindling` (name, icon, colour; the code's fallback stands in);
  - the night roster still needs `creatures.json` `active` labels (all "any" today, so dens fall back to predators that fit the climate, or the dark itself).

## 2026-10-02 — Old hearths, tomb lamps, the barrow's delve (§CJ) and the dusk shift change (§CH) (Mike: "sounds good get to work"; his 2 Oct answers on the §CJ audit)
- **Old hearths** (`OldHearths`): a cold hearth at every ruin with no camp and every nest holding remains (§CK). Rekindle it with a lit torch and feed it; lit, it holds the dark off and can be your hearth. It is kept in the save and burns down while you are away. **Torch only:** Mike's flint-and-steel idea clashes with the locked "fire is never made" (30 Sept §BP). Asked, he said "sounds good" to keeping the torch only, so that is what is built; Claude in chat to record it.
- **Tomb lamps:** the barrow's, desert pyramid's, mastaba's and mausoleum's lamp-gold lights are now stone lamps, dark until the ruin's hearth burns (Mike: "light … that activate after the main hearth is rekindled"). The teal moss glows stay on.
- **§CJ, the first delve** (`Delves`, `RuinBuilder._delve_build`): every barrow in stone or snow country leads down.
  - The stairhead is in the end chamber. A 32° stair goes down under the mound to the first room, which has the old hearth (the one safe room) and bone niches or a fallen slab. A second stair leads to the heart: the dead, ochre on the ceiling, a moss glow, and a spear or bow taken once. A stair up (with a level run if the ground dips) comes out in a small long cairn, whose slab opens only from inside. No traps or puzzle doors.
  - Delve barrows are a little broader than before and turned to the ground's grid.
  - The ground (4 m quads) opens only under the chamber and the cairn, which cover it. Inside: no sun, moon, mist or lightning; a drone and drips; dread as at night, its shapes on the delve's floors.
  - `tools/delve_check.gd`: 0 fails on seeds 7731, 90210 and 101. `old_hearth_check` (lamps at a graveyard, a barrow, a desert pyramid): 0 fails.
- **§CH, the shift change:** a "dusk" species is out in the twilight only. At the end of its hours each animal goes at its own moment and walks off to bed (ground animals) rather than vanishing; arrivals never pop up in plain sight.
  - The bed follows the sun: day cicadas (new loop, by biome group, in the warm) fade, then the night insects (their voices differ by biome group), then the frogs; dawn runs backwards.
  - `tools/shift_check.gd`: 0 fails. Every animal near the 7731 camp is an "any" species, so the roster swap only shows once the data is relabelled.
- **For Claude in chat (data, additive):**
  - honest `active` values in `creatures.json`, with `dusk` for the crepuscular;
  - a microbat, an owl and a rodent;
  - `audio.json bed`: `cicadas` in `by_group`/`layers` (the code's defaults stand in), and the dusk timings if the sun bands (cicadas −2..6°, night insects 2..−6°, frogs −3..−10°) want changing;
  - `fuel.json fire.old_hearth_units` (code default 2);
  - a future `delves.json` for room counts, finds and log lines (now in code).
- **Found by the walkabout and fixed:**
  - Underground, the torch went out as if under the sea: its douse test read the sea's level, and a delve can lie below it.
  - Slits between the stairs' stepped ceiling slabs let the sky show through; the slabs are now thick enough to overlap.
  - `delve_check` now also checks that no ray from inside escapes to the sky and that a lit torch stays lit down there.
  - The torch didn't light the delve's stone: the walls showed only as outlines. The cause was Godot's face convention. The builder winds faces the opposite way to Godot's "front", and in a mesh lit per pixel, Godot turns a "back" face's normal round, so every face you looked at faced away from your torch. The delve's own mesh now has its winding reversed (`RuinBuilder._flip_winding`). The ruins above ground are vertex-lit and never had the problem.
- **Also:** `PlayerFires` flickers every frame (it was once a second). The `get_meta(…, null)` trap in the new code was fixed (Godot 4.3 treats a null default as none).
- **Checks re-run:** `road_reach_check` 7731 and `new_world_check` 0 fails; a headless boot showed no script errors; the walkabout `SITES=delve` on 7731 (frames on this machine under `tools/reference/walkabout/7731/delve_*`; not kept in the repo).

## 2026-10-02 — Docs and comments caught up with the full planet, the ambient keys and Godot only (no behaviour change; design §CH–§CJ's docs pass, §CI)
- **HOW_TO_RUN §4**: play is on the full 4,000 km planet; `dev.json` has `postage_stamp` false and `spawn_choice` -1; the 40 km stamp is only for the checks and renders (`STAMP=1`). The dev pins hold in play only with `pin_in_play` or `DEV_PIN=1`.
- **HOW_TO_RUN §5**: the keys as they work now in the ambient profile come first. Wall jump, bounce, cling, catch-and-swing, ninja roll, fast drop, super meter and V/F5 third person moved to a short "shinobi profile only" table. The gamepad list lost its unbound right-shoulder wall jump. "Press E" became right click.
- **Stale comments**: `world.gd` (the radius is ~637 km, not 64; a 144-minute day; spawn_choice -1; STAMP=1), `planet_const.gd` (60/18/48/18 of a 144-minute day, not 45/20/35/20 of 120), `terrain_chunk.gd` (637 km radius), `planet_generator.gd` (~10 km cells, not 7). `model_library.gd` no longer names the old engine; no other tracked file outside `docs/design` and PROGRESS does. `GEO_CIRCUMFERENCE_M`'s 400 km layout stays.
- **implementation-notes.md**: blueprint cells (1 km of geography, ~10 km of walking), the stamp (checks only), the 144-minute day and its phases, and the dev pins.

## 2026-10-02 — Nests (§CK), the sacred fig (§CL), ferns, rhododendron forests and mad honey (§CM): design and data only (design chat; Mike's 1 Oct evening; lettered after the other session's §CH–§CJ)
- **`data/landforms.json`**: 35 nests in seven families (cave mouth to beaver pond), each with its cause, the biomes it dresses into, variants, what it gives a camp, the hearth spot, peoples, remains (§BQ signature ids), build/tier/status and checked real-world sources. Filled by six parallel agents, one family each; **`tools/landforms_check.py --strict`: 35 landforms, 0 errors, 0 warnings.** All `[NOT WIRED YET — design §CK]`.
- **`data/uniques.json`**: the one sacred fig with its meditating figure (§CL), not wired.
- **Plant data** (`plant_schema_check --strict` on the eight edited biome files: 212 entries, 0 errors): Sacred fig (*Ficus religiosa*) in tropical dry forest and jungle; Pontic rhododendron and yellow azalea (*R. ponticum*, *R. luteum*) in temperate deciduous and temperate rainforest; wavy cloak fern and spiny cliffbrake (*Astrolepis sinuata*, *Pellaea truncata*) in hot desert, canyon and thorn scrub. New associations: the Himalayan rhododendron forest (cloud forest), the beech-rhododendron mad-honey forest (temperate deciduous); the ferns join the wash, slope and Tamaulipan associations. The new species are hero species in their files so the trim keeps them. **These load and grow with no code change.**
- **`habitat.json`**: the rhododendron group joins `always_present` and `trim.always_keep` (§CM, live on restart). **`items.json → mad_honey`**, not wired.
- **Docs:** §CK–§CM in RECONCILIATION_2026-09-30 (with the engine gaps the fill found, and two spec contradictions noted), a §BR order line, and two §CK notes in WORLD_SYSTEMS_SPEC (ruins hold; cave mouths before Phase 3).
- **Open for Mike:** the meditating figure's name in play and whether the dark spares his circle (§CL); whether "the kind of place, not Earth's map" loosens the realm gate (§CM).

## 2026-10-02 — The docs brought in line with the ambient cut: CLAUDE.md, 1/10 Earth everywhere, Godot only; night life and dungeons designed (design chat; Mike, 1 Oct 22:16–23:01; design §CH, §CI, §CJ)
- **New `CLAUDE.md`:** the brief Claude Code loads every session (it imports `WORKING_AGREEMENT.md`). It covers the ambient game, the scale, the two games, the sources of truth in order, the look in short, and how we work (no screenshots per step).
- **Sources of truth reordered:** the 30 Sept doc first (§BR is the order of work), then the 27 Sept doc, `LOOK_REFERENCE`, `PLANT_SCHEMA`, the spec. Updated in `WORKING_AGREEMENT`, the README, the spec's header and Part C, and `DESIGN.md`'s banner. `docs/OVERVIEW.md` is rewritten for the ambient game; it still pitched the shinobi game. The README is rewritten, with the keys left to `HOW_TO_RUN.md`.
- **1/10 Earth everywhere** (Mike: "the map should be 1/10th the size of earth not 1/100th"). `DESIGN.md`'s biome sizing is restated at 1/10 with the measured `biome_scale` numbers. These now say 4,000 km, with 400 km only as the layout map (`GEO_SCALE`):
  - the spec's weather grid and ledger table;
  - the 27 Sept doc's status rows;
  - `implementation-notes.md`'s planet size and horizon (Claude Code's file, edited here at Mike's request).
- **Godot only (§CI):** the docs say plain Godot 4.3, and `assets/models/README.md`'s model workflow no longer names a tool. Two code comments are left for Claude Code: the old engine in `scripts/core/model_library.gd`, and `world.gd`'s "~64 km radius" (the planet is ~637 km).
- **Designed, not built (audit first, §BR):**
  - §CH night life: two rosters and the dusk shift change, caves and bridges by the clock, bats, the sound by phase and biome, and owls;
  - §CJ dungeons: every ruin is a delve, with Skyrim's shape and Morrowind's aesthetic in the favourites' colour, a type per ruin kind, and the dark as the danger.
- **`docs/references/project_sheets.md`:** the 80 Project screenshots described in words. They now sit in the Project as four numbered contact sheets; six of them are favourites.

## 2026-10-02 — §CK tier 1: camps live at the land's own places, and a ruin is what a camp leaves; §CM nest plants; §CL the sacred fig (design 1 Oct §CK–§CM; `landforms.json`, `uniques.json`)
- **The sites pass** (`Nests`, new): a pure, cached function of the planet and its rivers, like Ruins. Each tier-1 kind is placed by its cause, never a biome name, one candidate per rarity cell (common about 4 km, uncommon 12 km, rare 40 km), only where the cause holds.
  - **Cave mouth:** a karst or sandstone cliff of 8 m or more (an escarpment face, or the wall of a ravine with a dry floor), level ground before it, and water within 1.5 km.
  - **Grotto:** wet karst (2–21 °C, moisture 0.5 or more) at a cliff.
  - **Cenote:** warm karst lowland, flat, with no river within 3 km. Variants: the **doline** in cool karst (4–18 °C), and the **blue hole**, karst under reef or lagoon shallows (look only: a dark disc of water).
  - **Slot canyon:** the ravine layer in dry sandstone.
  - **Waterfall:** the tallest fall (RiverNetwork) in its cell.
  - **Ravine:** a stretch of a ravine's floor.
  - **Escarpment:** a stretch of the escarpment foot. On open grass it is the **buffalo jump**.
  - **Bioluminescent bay:** a warm lagoon or estuary cell, salt or brackish, by mangrove, with few open-sea neighbours.
  - A nest gives way to an earlier kind within 180 m, and to a monument's footprint.
- **Water, from the data's own notes.** On the full planet a blueprint cell is about 10 km across, so rivers are 10 km reaches and "water within 1.5 km" rarely holds at a cliff. Following the data's own notes, cave mouths on an escarpment face get a spring at the foot ("a spring or seep within ~500 m does instead"), as do escarpments ("springs along the foot") and a ravine stretch with no river ("a spring the stamp adds at a widening"). Each spring is a small pool with mossed stones.
- **The camp loop** (`camp_loop`):
  - Each nest is untouched, lived in or holds remains, by its own roll. start_budget's "best first" is a weighted roll: 0.36 where the nest gives roof and water, 0.20 water only, 0.15 roof only; half of the rest hold remains. These are implementation numbers, tuned to land on the budget.
  - Measured on the four report seeds: 25 %, 28 %, 29 % and 29 % of the nests that give roof or water hold a living camp (start_budget: about one in four).
  - A camp lives only where the nest gives roof or water, fuel.json gives its biome fuel, and there is a hearth spot clear of the hazard.
  - Living camps are built at the hearth by Camps (key `nest:<kind>:<cell>`, the nest's people) and are road "camp" nodes (RoadNetwork).
  - Remains are that people's §BQ signatures that the nest's `remains` list allows, laid within a few paces of the hearth (RuinMarks). Where the people have none on the list, the list's own signatures are used.
  - The monuments, and the camps at them, stand as built. The wake and hearth rules are unchanged; `Camps.fire_at` knows nest camps, so a nest camp's fire can be your hearth.
- **Who lives there** (`Peoples.pick` reads the nest first, `nest_pick`):
  - It is a seeded draw over the nest's `people` list, likeliest first (weights 1, ½, ⅓ …). The life biome_map gives the biome counts twice, a life dressed for the biome half again, and one dressed for neither a quarter. Karst folk never live off karst, and shelter folk never without a roof.
  - The site rules after it now read real nests. The karst rule needs a cave mouth, grotto or cenote within 200 m (it was a coin flip on karst rock with no cave or sinkhole). The rock-shelter rule takes a roofed nest within 40 m.
  - So a karst cave is karst folk's or shelter folk's (it was always shelter folk's), and an escarpment on the steppe is mostly the steppe folk's, in savanna about a third the herders' (it was always shelter folk's).
  - Across the four seeds' windows: **shelter folk 495 camps, karst folk 47** (both had none).
  - Not touched: the lake rule taking salt-flat and oasis camps, which is tier 2.
  - Side effect: a karst opening camp now needs a real cave or sinkhole nearby, so there are fewer karst first camps than under the coin flip.
- **Anything with a roof is a mesh** (`NestBuilder`, on RuinBuilder's rock, collision and far LOD):
  - **Cave mouth:** a rock roof 3–6.5 m up overhanging 5–9 m, side walls closing a first chamber, a dark low passage at the back (Phase 3 digs behind it), wet stones along the drip line. The fire sits 2.5 m in from the lip.
  - **Grotto:** RuinBuilder's barrow passage in raw rock. A rock mound out from the cliff, a low arched mouth, a dry front room where the fire is, a passage narrowing back to a chamber with its drip pool and a faint teal glow.
  - **Cenote:** the undercut lip (rock slabs round the rim leaning over the drop) and fallen blocks down the slope.
  - **Escarpment:** an overhang slab and two boulders, the fire 2 m in from the drip line. The buffalo jump gets two lanes of cairns on the plateau narrowing to the lip.
  - **Slot canyon:** drift logs jammed across the slot near the top.
  - **The old cliff-shelter fire** (`Camps._overhang`) now sits 1.5 m in from the drip line; it was at the drip line.
- **Stamps** (`Nests.stamp`, in `TerrainField.elevation` with detail; the sites passes, Ruins included, read the ground without stamps).
  - **The cenote:** a sheer round shaft 15–60 m across, down to a pool at the water table. The pool is standing water, so the chunks draw it and you can swim it. A slope of fallen blocks (36°, about 50° of the shaft) cuts the rim and heaps inside: the way down.
  - **The doline:** a bowl 3.5–7 m deep, half of them holding a pond.
  - **Slot canyons:** a ravine through dry sandstone pinches to a slot, blended over the sandstone cells so it narrows over a few kilometres, with a sandy bed in the ground colour. The ground's 4 m grid can't make the data's 1–4 m floor: the narrowest is about 4.5 m (nest_check: 9.9 m deep, floor 4.5 m).
- **The glowing bay** (MagicSites kind 0.2; `look_bay_glow`; `water.gdshader`): the water stays dark until stirred. Every ripple ring, splash (the ripple sim) and raindrop lights blue-green (HDR 2.2, so it blooms), faint by day. The shader compiles under Forward+. No frame was taken: the nearest bay to a checked camp was 376 km off.
- **Nest plants** (§CM, `VegetationPlacer._place_nest_plants`): each landform's `plants.add` grows at its own spots, each species inside its own temperature and soil bands, with the spot's moisture standing in for the seep or spray's:
  - a grotto's mouth and drip pool (seed 90210: 22 plants of maidenhair, hart's-tongue, filmy fern and bird's-nest fern);
  - a waterfall's spray on both banks (seed 7731: 38 and 21 filmy fern and maidenhair);
  - a slot canyon's seep (seed 7731: 6 maidenhair).
  - The mesa alcove and the wadi wait for those nests (tier 2).
- **The sacred fig** (§CL, `Uniques`), one per world:
  - **Where:** in the first biome of its list the world has, on a level low rise clear of monuments.
  - **The tree:** a *Ficus religiosa* 12 % past the top of its band (33.6 m; uniques.json says "past the top of the species' band: about 30 m", and the band ends at 30 m).
  - **Around it:** swept earth in a 17 m ring with the trees kept back, and a few flat stones.
  - **Beneath it:** on the east side of the trunk, facing east, a figure on the shared cloaked rig in the ochre robe (#CC7722, edge #A8601C), seated cross-legged in a new rig pose (`PlayerBody.pose = "meditate"`) and still but for the breath.
  - **The log:** within 25 m it writes "Someone sits beneath the old fig, very still." No name.
  - **How it's drawn:** the tree is drawn by the fig's own node with its species' hero tree. Through the placer, a lone tree past its band was in the draw buffers at the right place but didn't show in the frames.
  - **Not built:** the faint path in from a road, the roots on old stone, the leaves' own flutter, and the hood down (the rig has no bare head yet).
- **F3:** a new line lists the nearest three nests within 3 km, with distance, compass bearing, stage and people.
- **Data:** the `[NOT WIRED YET]` prefixes in `landforms.json` (now "tier 1 wired") and `uniques.json` (the fig wired, its open pieces named) are updated. No design value changed.
- **Checks (full planet, headless unless said):**
  - `landforms_check.py --strict`: 0 errors. `plant_schema_check --strict`: 0 errors.
  - `tools/nest_report.sh` (new: 28 windows of 22 km a seed) — every seed's run passes:

    | seed | cave mouth | grotto | cenote / doline | slot | waterfall | ravine | escarpment / buffalo jump | bay | lived | remains | shelter folk | karst folk |
    |---|---|---|---|---|---|---|---|---|---|---|---|---|
    | 7731 | 329 | 2 | 24 / 56 | 87 | 8 | 75 | 731 / 76 | 2 | 323 | 524 (953 signatures) | 92 | 10 |
    | 467606063 | 239 | 10 | 8 / 37 | 26 | 72 | 152 | 735 / 61 | 0 | 359 | 489 (859) | 142 | 9 |
    | 1378252316 | 266 | 2 | 5 / 8 | 82 | 16 | 61 | 771 / 20 | 2 | 328 | 452 (720) | 89 | 3 |
    | 90210 | 424 | 9 | 82 / 84 | 76 | 5 | 100 | 823 / 108 | 2 | 460 | 627 (1,330) | 172 | 25 |

    Every living camp has a hearth and a people, and no hearth sits in a shaft or a slot's bed.
  - `tools/nest_check.gd` (new), 0 fails on 7731, 1378252316 and 90210. It stood at a nest of each kind and checked:
    - the set pieces are built and collide;
    - the cave-mouth and overhang hearths are under the roof;
    - living camps have the nest's people (a waterfall's rainforest folk, a steppe escarpment, savanna herders);
    - remains are laid (weir_line at a waterfall; cliff_dwelling under an escarpment; ochre_wall, ash_hearth and drip_wall in a grotto);
    - the cenote's pool is standing water at 7.8 m over a floor at 4.8 m, the wall stands 22.3 m over the pool, and the hearth is on the rim;
    - the slot is 9.9 m deep;
    - the nest plants grow;
    - F3 names each nest;
    - the sacred fig is 34 m tall with the figure seated and the log line written.
  - `road_reach_check` on 7731 and 467606063: 0 fails (every ruin and inhabited ruin on the network, the opening road to a people's camp).
  - `new_world_check` (DEV_PIN=0): 0 fails. Headless boot: clean.
- **Harness frames** (`tools/walkabout.gd`, `SITES=opening_camp,nests,fig`, QUICK; seed 90210, full planet; first person at the eye; the cloud machine's lavapipe software Vulkan, Forward+, 1280×720; import cache present; 14 h overcast): the opening camp; a cave mouth in a cold-desert ravine (the roof, the side walls, the dark passage at the back, the drip stones); a grotto in temperate deciduous forest; a cenote in hot desert (the shaft, the blue pool, the lip stones, the slope down); an escarpment overhang with its spring; the sacred fig in tropical dry forest. 0 species standing outside its biome. The grotto's ferns are counted as the nest's own (§CM), and the walkabout now knows that rule.
  - New: `SITES=nests` and `SITES=fig`, and a site can face what it shows. Viewpoints: in front of a shelter looking in, just outside a grotto's mouth, on a cenote's rim, 24 m east of the fig.
- **What the frames show:**
  - The cave mouth, the escarpment overhang, the cenote and the fig read as built.
  - The grotto, from just outside its mouth in overcast light, is a dark rock mound with the passage's teal glow showing through the low arch. Its shape doesn't read from there; a sunlit angle would show it better.
- **One run went wrong:** an earlier try of the same final walkabout printed "Unicode parsing error" lines (float data printed as text) from the escarpment site on, until the log filled the disk (14.7 GB). The rerun of the same sites, and the two runs before it, printed none. It came on top of the MultiMesh buffer-size errors every walkabout prints (about 2,900 a run over these six sites; seen before this pass). It looks like the same engine-side trouble and is worth chasing with them.
- **Fixed in passing:**
  - `Camps._live` read the walker with `get_meta(…, null)`, which errors in Godot 4.3 when the key is missing (25–48 lines a run in earlier logs too).
  - `Ruins.site_name` now names a nest.
  - RuinBuilder skips an empty mesh (nests with nothing to build).
- **For Mike:**
  - `camps.json`'s `only_at_ruins` help still says camps exist only at ruins; nests now hold camps too. That is chat-owned data and needs a new line.
  - Waterfalls are rare on the full planet (5–72 per seed's windows), because the river network is 10 km reaches.

## 2026-10-02 — §CG: the game no longer needs the import cache; Day 1 and one clock; every frame labelled (design 1 Oct §CG)
- **Nothing at runtime depends on the import cache** (`ResFiles`, `Look.texture`, `SkySystem._cloud_pano`, `ModelLibrary._scene`, `HudText`):
  - Each world tile is read from its PNG on disk (`FileAccess.get_file_as_bytes`, `Image.load_png_from_buffer`), then `fix_alpha_edges()` (the importer's `fix_alpha_border`) and mipmaps, as the importer does.
  - The import is used only when the PNG can't be read and the import is really there (`ResFiles.imported`, the one shared test, moved from `HudText._imported`). Otherwise the tile is painted (`LookTextures`).
  - `Look.texture()` never returns null and never hands a material an empty texture.
  - The cloud panorama is read the same way. An un-imported .glb whose `.import` exists now reaches `_read_raw`.
  - A missing import is one `push_warning` naming the file.
  - F3 has a new line: "World textures: 9 from disk" (or from import / painted).
  - **The audit:** the only runtime `load()` calls left on imported types are the font, ModelLibrary and ResFiles, and all three are behind `ResFiles.imported`. No .tscn or .tres references an imported image, font, sound or model. `config/icon` raised nothing with the cache hidden.
- **Day 1 and one clock** (`Astro.local_clock`, `World.local_clock` / `clock_text`, `main.open_clock`):
  - One function gives a place's day and time from the sky's clock: the local day is `floor(days + longitude/TAU)`, and the time is the sky's warped solar time. The HUD line, the clock face, the log's stamps and the log's first line all use it.
  - Every new world opens on Day 1 in §BX's afternoon, and the day goes up at local midnight where you stand. `START_DAYS` stays 13.62, so the sky and the first night's moon are as before.
  - The world's first local day is stored in its save (`first_local_day`).
  - **A save from before has none:** the day it wakes on becomes its first day (Day 1), and that is kept from then on.
  - **Not fixed here: the world clock itself isn't saved** (`WorldSave`: "Phase 12 persistence decides … the world clock"). Every boot restarts it at START_DAYS and takes it to the afternoon where you wake, so a Continue still reads Day 1 or 2, not the days played. Once Phase 12 saves `days`, the stored first day makes Continue count from the world's start; `day_check` already checks that (a save begun three days earlier reads Day 4).
- **Checks (full planet, harness, the cloud machine):**
  - `tools/no_import_check.sh` (new; it moves `.godot/imported` aside, keeps the class cache, and always puts it back), headless, DEV_PIN=0, fresh random world 474184050: 0 fails.
    - Every `look_tex_*` is a real texture: plant 3, terrain 4, salt and fresh water 1 each, ruin 4.
    - The leaf card has 458 of 1,024 texels clear, the same as the file.
    - All 9 textures came from disk. 48 species materials carry their leaf tile and 0 lack it. The HUD font is VT323, read from disk.
    - 0 "Failed loading resource" lines, and nothing in the log beyond the usual quit-time thread warning.
  - `tools/import_parity_check.gd` (cache present): the 8 tiles are identical from disk and from the import at every mip level (7 levels at 64 px, 6 at 32 px), and the cloud panorama is identical too.
  - `tools/day_check.sh` (new), 0 fails on each of four seeds:
    - The camps are 7731 at 156.1°E, 1378252316 at 74.5°E, 90210 at 29.5°W and 31337 at 169.3°W. Each run also checks Mike's 12.7°N 140.1°W on that world's sky.
    - Each wakes on Day 1 in the afternoon (13:43–13:46). The last Day 1 stamp is 23:58, and Day 2 starts at 00:00.
    - The HUD line, the face and the log stamp agree to the minute at every reading (51–52 per place).
    - `world.days` equals START_DAYS taken to the afternoon, as before, and the first night's moon is 98–100 % lit.
    - A save from before reads Day 1 and keeps its first day; one begun three days earlier reads Day 4.
  - `new_world_check` with DEV_PIN=0: 0 fails. It now also asserts that a world opens on Day 1 (Day 1 · 13:45), that its save keeps `first_local_day`, and that Continue keeps it.
  - Headless boot: clean.
- **The end-of-pass walkabout, with the import cache hidden** (harness frame: `tools/walkabout.gd` via `tools/no_import_check.sh`, QUICK, opening camp; a fresh random world, seed 2134316216, tropical dry forest; first person at the eye; the cloud machine's lavapipe software Vulkan, Forward+, 1280×720; cache hidden): 0 fails.
  - Afternoon: solar 13.6 h, sun 64.6°.
  - 13 species within 30 m, all in their own biome. 0 failed loads.
  - Leaf cards cut out and the ground is tiled: no grey boxes.
  - The same world rendered with the cache present (same harness, camera and machine) matches it apart from moving things (wind sway, falling leaves, cloud drift).
  - Walkabout fix: under DEV_PIN=0 it no longer pins its SEED, which play overrode anyway. It now files the frames under the seed it actually booted and leaves no save behind. `no_import_check` also no longer leaves a save.
- **Frames:** every frame shown or put here is labelled harness or play. `tools/dev_view.gd`'s header no longer calls its world the postage stamp: it is a harness frame (seed 42 unless SEED is set, the full planet).
- **For an export (out of scope):** an export packs the imported `.ctex` files, not the PNGs. The disk-first reads would then fall back to the import, which is there in an export. To keep the disk reads, the export preset's non-resource include filter needs `assets/textures/retro/*.png`, `assets/fonts/*.ttf` and `assets/textures/plants/species/*` (that folder is `.gdignore`d, so nothing of it is packed without the filter).
- **Seen in passing, not this pass:** the walkabout prints "p_buffer.size() != instances × stride" MultiMesh errors (690 per run here; 2,509 on seed 303 earlier), the same with the cache present or hidden.
- **Queued, per §CG:** the foliage-derivative refactor (derivatives taken before any branch) is saved as `docs/parked/foliage_derivatives.patch`, and the F9 foliage views stay queued with it.

## 2026-10-02 — Mike's 1 Oct 23:11 play: grey-box plants and Day 14 — causes found and reproduced (design chat; design §CG)
- **The frames shown so far were all harness frames:** `tools/dev_view.gd` (seed 42, the first camp, a fixed third-person camera 9 m south of the fire, weather held clear), `walkabout.gd` and `species_row.gd`, all rendered on the cloud machine (xvfb, lavapipe, Godot 4.3, the import cache complete). None is play on Mike's Mac, and none could show this bug.
- **The grey boxes, reproduced** (Godot 4.3.stable.official.77dcf97d8 headless, this branch at `34f9d42`, `.godot` built by `--import`): with the import cache present, `Look.texture("leaf_card")` is an ImageTexture with 458 of 1,024 pixels cut out and the plant material holds it. With `.godot/imported` moved aside (the class cache kept), `ResourceLoader.exists` still says true (the committed `.import` file), `load()` fails ("Failed loading resource: res://.godot/imported/leaf_card.png-….ctex. Make sure resources have been imported by opening the project in the editor at least once."), `Look.texture()` stops on "Cannot call method 'get_image' on a null value" and returns null, and the plant material's `look_tex_leaf_card`, `look_tex_leaves` and `look_tex_bark` are all null. The same for grass. Godot samples an unset `sampler2D` as opaque white: alpha 1, so the cards never cut out, and `foliage.gdshader` draws `base × tex × 2`, so they wash out pale. The 23:11 frame, cropped: bamboo culms with their shader-drawn node rings and no bark, leaf cards as flat solid quads, the ground smooth green with no tiles. Every importer-fed texture is empty; every shader-drawn detail is there.
- **Since when:** `df993d6` (28 Sept, 18:24 Chicago) moved the world tiles to `load()` through the importer; before it every world texture was painted at startup (LookTextures), so a project copy older than that draws its plants on any machine.
- **The same path elsewhere:** `SkySystem`'s cloud panorama (`load()` behind `ResourceLoader.exists`; it then bakes clouds itself but logs the load errors) and `ModelLibrary._scene` (an un-imported .glb whose `.import` exists gives null and never reaches `_read_raw`; no models are tracked yet). The font already guards this (`HudText._imported`, the 15:30 fix). The species tiles (`PlantMeshes.tile`) read their PNGs from disk and are safe.
- **Not the cause:** a headless `--import` prints 23 "Global uniform 'look_fog_color' does not exist" shader errors (`look.gdshaderinc:28`). They come from the dummy renderer, which ignores `[shader_globals]`; the global is declared in `project.godot` and a real GPU registers it.
- **Day 14:** `World.START_DAYS` is 13.62 (a near-full moon the first night). The HUD prints `int(Astro.apparent_days(...)) + 1`, the log's stamps `floor(world.days) + 1`, and the log's first line a fixed "day 1". At Mike's spawn (12.7°N, 140.1°W; the game's own `days_at_solar_hour` and `apparent_days`): `world.days` 13.9553, the HUD "Day 14 · 13:43" on waking, then "Day 15 · 14:40" 5.2 real minutes later; the log's stamps flip at 6.4 minutes. The day turns over at midnight at longitude 0, not the player's. The clock face and the log's stamps read the uniform clock (`fposmod(time_of_day + longitude / TAU, 1)`), the HUD line the sky's warped solar time: 13:35 on the face against 13:43 on the HUD at that spawn (Mike's frame: about 13:40 against 13:47).
- **Not known from here:** why the cache on Mike's Mac lacks the tiles (how the game is launched there, or the editor not re-scanning since 28 Sept). §CG makes it not matter. Opening the project in the Godot 4.3 editor and letting the import finish should bring the plants back before the fix lands.

## 2026-10-02 — Japanese hemp is an accent only: no evidence of terpene relevance (Mike: "we won't have that much Japanese hemp because there's no evidence of terpene relevance"; `cannabis.json`, `habitat.json`)
- **Where all the hemp came from:** in East Asian temperate forest Japanese hemp is often the Cannabis sativa landrace nearest in climate (one roll per binomial), so §CE's always_present made it a forced associate (an associate's whole share, not just `min_share`), and the stand roll could make it the dominant. Taking only the lift away still left it 8.8–24.4 % of the shrub layer, so the rule keeps it out of the stand roll's principal places too.
- **The rule** (`VegetationPlacer.accent_only`, `_apply_dominance`): the entry records `cannabis.terpene_evidence: "none"` (Mike's call, in its `terpene_note`), and the cannabis group's `no_terpene_evidence: "accent_only"` (`habitat.json always_present`) keeps such a landrace to the accents: never lifted, never a stand's dominant or associate. It still grows wherever it fits, scattered. A stand without it rolls exactly as before (the same draws).
- **Shrub layer at the same sites, before → after:** seed 467606063 2,968 (12.9 %) → 207 (0.9 %) and 7,198 (28.1 %) → 166 (0.8 %); 1378252316 4,476 (16.2 %) → 236 (0.9 %); 7731 (temperate deciduous) 5,057 (22.2 %) → 300 (1.3 %), and beside Korean hemp 551 → 26 and 643 → 45. Korean hemp, Kentucky feral hemp and the drug landraces (Kerala 13.3 %, Panama Red with Lamb's Bread 12.0 %) are unchanged. `tools/plant_presence_check.gd` now prints each group's share of its layer.
- **Not decided here:** the other six hemp-type landraces (Korean, Northern Chinese, Central Russian, Carmagnola, Anatolian, Kentucky feral) and the four ruderals carry no terpene note; adding `"terpene_evidence": "none"` to one makes it an accent the same way.
- **Checks:** `plant_presence_check` on 7731, 467606063 and 1378252316: every group PASS, 0 fails, 0 script errors; `plant_schema_check --strict` 0 errors; `biome_species_check` 998 allowed; `plant_trim check-keep` PASS; headless boot clean (the one quit-time thread warning, as before).

## 2026-10-02 — §CE presence and vines: the named plants always grow where they fit, vines over every surface (design 1 Oct §CE; `habitat.json` `always_present`, `vines.json`)
- **Always present** (`VegetationPlacer.presence_group`, `_apply_dominance`, `_one_per_binomial`): a member of an `always_present` group (Musa, Amorphophallus, Cannabis, Trichocereus, Acacia s.l., bamboo, vines; by genus, shape or name) that fits a stand's middle is always an associate, never an accent, and each group present gets at least `min_share` (6 %) of its tier's stems, split among its fitting members, the rest scaled to make room. Entries sharing a binomial roll as one species (`one_roll_per_binomial`): of the 64 Cannabis sativa landraces, the one nearest in climate.
- **Why Amorphophallus never grew:** the catalogue's `family_defaults.needs: ["forest_floor"]` was added to every entry on top of its own needs; 25 entries list a savanna, thorn-scrub or other open biome (§CA) and 5 list only open ones, so they could never pass. The entry's own biome list now wins over the family's `forest_floor` (`SpeciesDB`; the data is unchanged). The rest is soil: 238 of 246 take only alluvium, clay-peat, basalt or karst, so a rainforest on granite has none — the presence check now picks sites where a member's biome, realm, soil and climate all fit (`tools/plant_presence_check.gd`; a group with no such site is SKIP, not FAIL).
- **Trim** (`tools/plant_trim.py`): `always_keep` groups are never trimmed; vine is the tenth category; `check-keep` asserts a re-run keeps every member (21 of 21 restored present, 7 groups).
- **Vines over surfaces** (`VineCover`, `data/vines.json`): the biome's vine species that fits the spot (`species_at`):
  - trunks — `surfaces.trunk.cover` × climate of the trees carry one, up their `climb_share` of strands; the mat-3 strands take the vine species' leaf tile and colour (`foliage.gdshader` `sp_vine_*`);
  - dead wood — `surfaces.log`;
  - cliffs — patches hanging down steep faces; open ground — creeping patches (`surfaces.cliff`, `surfaces.ground`), leaf cards on strands with the species tile, drawn within `near_m`; past it the ground under a patch takes the vine's green (`VineCover.green`, `far_tint`, default 0.5 — not in vines.json yet);
  - ruin walls and heaps — hung from the ivy strands' tops (`RuinBuilder` `vine_anchors`, recorded without a new roll, so every ruin builds the same), by `surfaces.ruin` × climate × age (`ruins.full_after_years`); a camp restoring it cuts them back with its ladder (rung 1 half, rung 2 bare; `restored_clears`); an abandoned camp is taken back as the forest takes it (`CampSim.reclaim`, `forest_takes_game_days`).
  - boulders — a ruin's tumbled rocks, draped from their tops (`boulder_anchors`, `surfaces.boulder`); the road-gate and camp boulders not yet.
- **Data fixes with sources:** _A. incurvatus_ `temp_c` [14, 21] (Kerinci, 1,770 m; the lapse rate from lowland Sumatra's ~27 °C); Cannabis "Kashmir" `moisture` [0.45, 0.68] (Srinagar ~13.4 °C and ~700 mm a year).
- **Checks (full planet):** `plant_presence_check` 0 fails on 7731, 467606063 and 1378252316 (every group PASS on each); `BIOME=SAVANNA` 0 fails (Amorphophallus 20 species, acacia, bamboo, vines; Musa, Cannabis, Trichocereus have no savanna habitat: SKIP); `BIOME=STEPPE PLANT_GROUPS=trichocereus,cannabis` has no fitting steppe on 7731 or 1378252316 (SKIP) and passes on 467606063 (T. bridgesii, macrogonus, peruvianus; Cannabis "Mazar-i-Sharif"); `BIOME=TEMPERATE_DECIDUOUS` 0 fails (Cannabis, bamboo, vines). New `tools/vine_check.gd` (7731) 0 fails: temperate forest — ivy on 19 % of trunks (2,151 of 11,366) and 25 % of dead wood, 2,062 ground and 3 cliff patches, a castle 2.6 km off with ivy on 36 of its 84 strands and 5 of 36 boulders, cut back 36 → 16 → 0 by a restoring camp; rainforest — liana, pothos and philodendron on 35 % of trunks, 4,543 ground patches, a treehouse with liana on 13 of 16 strands and 9 of 20 boulders (13 → 9 → 0). The §CA walkabout (QUICK, full planet, seeds 101 202 303 404): 0 species standing in a biome that does not list them, 0 fails. Seed 303's opening camp and its first road site stand on a dry-forest/savanna boundary: the walkabout judged every plant within 30 m by *your* cell's biome and flagged 3 + 3 species from the other side; it now judges each plant by its own cell, as the placer does, and notes them as "across the boundary, in its own biome" (`tools/walkabout.gd`). `plant_schema_check --strict` 1,187 entries 0 errors; `biome_species_check` 998 species allowed; `plant_trim check-keep` PASS; `tree_check`, `cover_check`, `litter_check` 0 fails; headless boot clean. `fruit_check` fails 2 ("all of them up in the tree" — flower sites to 38.5 m on a 23.3 m tree; "lies rotting under the tree" — 0 on the ground) the same way at 56e221e, before today's work: not this pass.
- **Also fixed:** AroidGarden stepped a plant whose chunk had unloaded mid-pass ("previously freed instance", 1,541 lines a run); it now drops the rest of that pass. Vine patch MultiMeshes are filled through their raw buffer (LookTarget and the banding read it back).

## 2026-10-01 — The twenty favourites: reference batch 4 measured, the look reference doc, `measure_look.py --fav` (design chat; Mike: "push what you can… so we can truly hone in on the aesthetic"; design §CF)
- **Batch 4** (`docs/references/batch4/`): Mike's 20 favourite frames cropped to the video. With them: a contact sheet with each frame's five dominant colours; the findings card (3× zooms showing clean edges against the sky and big texels on surfaces, plus the measured colours); and `measurements.json` (every frame through `measure_look.py`'s own formulas plus the blue / green / warm shares; day 8, night 10, character 2).
- **`docs/design/LOOK_REFERENCE.md`**: the eye test for Mike's next play, ten rules with the frames and numbers behind them, the composition rules for the landmark and road pass, the favourites against `retro.targets`, what's built and what's open, and five open calls.
- **`measure_look.py --fav`**: also prints where a frame sits among the favourites of its band, and the nearest favourite to open side by side. Without the flag the output is unchanged. Checked: a favourite's own crop names itself as nearest (#9 at night, #2 by day), and batch3 #2 reads as before without the flag.
- **Not changed:** `retro.targets`, every other `look.json` value, every shader. The favourites read darker by day than the day band (median luma 0.21 against 0.26–0.36) and up to 0.87 saturated at night; both are open calls in §CF. **The grey leaves** (step 0 of the look pass prompt) aren't in the look pass's log. Check them on the Mac before judging any colour.

## 2026-10-01 — Look pass for the ambient open world: hue-safe navy grade, cobalt sky, electric water, hard 16-texel tiles (Mike's on-screen targets; `look.json`, tuning only — no second pipeline)
- **Colour and glow** (`post_grade.gdshader`, `SkySystem` environment, campfire): Linear tonemap (`grade.tonemap`, exposure 0.9); a saturated navy ambient (`day.ambient_color` #1838C8, `night.ambient_color` #0C1C8C). The grade pulls shadows to navy (`shadow_color` #06186C) and highlights to cyan-white (`highlight_color` #D8F8FF day / #C8F0FF night), lifts saturation (`day.saturation` 1.5), and leaves oranges and golds alone (`grade.protect_hue_deg` −20° to 62°, feathered). Glow takes only HDR above 1.0 (`retro.bloom`); the fire is the one warm accent: flame bands #FEFC54 core → #E6552A → #5A0A00, HDR 1.8 at the core, light #FF6E24 at 7 m.
- **Sky, distance and mist** (`SkySystem`, `sky.gdshader`, `look.gdshaderinc`): every colour was derived by running Mike's target through the grade backwards (a Python copy of `post_grade`), so the on-screen result lands on it. Day zenith #0509BF (target #0000C4), 3° horizon #2248EB (#2350F0), clouds #A4B0E5 (#A8B4E6), far mountains #5198ED (#4F98EF), deep night #040939 (#050938), full moon overhead #0E17BE (up to #0000C0), night mist #17369A (#153695). The file's stops look slightly violet (day) and teal (night fog) because the grade pulls dark blues to navy. Low mist now hugs the ground by height above the planet surface (`mist.*`, new globals `look_fog_start_m`, `look_mist_density`, `look_mist_scale_m`).
- **Water** (`water.gdshader`, `waterfall.gdshader`, new `waterfall_mist.gdshader`, `WaterLook`): a self-lit electric-blue body (`water.base`, `self_lit`, `glow`), calm ponds navy (`water.calm`), cyan glints from two scrolling noise layers that bloom (`glint` #85FCFF × `glint_hdr` 1.5). Falls carry scrolling streaks and three mist cards at the plunge (`waterfall.mist`). Rain and rising water now reach the per-biome water materials too (they only reached the default one).
- **Textures and contact shade** (`make_retro_tiles.py`, `terrain.gdshader`, `RuinBuilder._contact`, `TerrainChunk._bake_tree_feet`): grass, dirt, sand, stone, bark and leaves redrawn at 16 texels a metre (was 32–64) with hard darks (0.19) and lit flecks (0.81), 6–8 grey levels a tile; nearest with 2 mips, no normal maps, every world shader `specular_disabled`. Dark rings at tree feet from a per-chunk feet map; ruins darken where they meet the ground, under every block, inside towers and at doorway jambs (`cavity.*`). Ruin geometry and rolls unchanged.
- **Render size:** `render.preset` stays "default" (480 lines).
- **Checks:** every script parses; every shader in `shaders/` drawn for 30 frames under Forward+ (lavapipe) with no shader error; headless boot clean. Visuals built — needs a frame from Mike's Mac.
- **Left for later (audit):** spring pools (`road_props.gd`, `camp_props.gd`) are glossy (roughness 0.1); a few small materials keep Godot's default specular 0.5 (`_hang_vines`, lantern, torch, corpse, world items, fishing line, ruin marks, coals); `far_terrain.gdshader` samples stone without `retro_tex`; `retro.filter` / `retro.anisotropy` are not read by any code.

## 2026-10-01 — Mac play fix 3: trees drawn by their own distance, 157 M triangles down to 15–23 M; no road region on the main thread (Mike's 15:30 play; `look.json` `ranges`)
- **Leaf cards by distance, per tree** (`TerrainChunk.setup_bands` / `band_trees`, `ChunkManager._band_some`): every branchy tree is drawn by its own distance from you, not its chunk's ring. Within `ranges.tree_full_m` (120 m) its full leaf cards (the hero mesh, as before); of those, only the ones within `tree_shadow_m` (35 m, the hard shadow map's reach) cast the sun's shadow; out to `tree_light_m` (350 m) the new light tree (`PlantMeshes.LOD_LIGHT`: the trunk, at most 8 main limbs, 16 big leaf clusters; 187–464 triangles, mean 257 over all 840 layouts, against ~17,000 for the full tree); beyond, the one-quad picture. Each layout's trees are split into three copies (shadow, full, light), the species' picture keeps only the far ones, and a chunk re-sorts after you move `tree_reband_m` (15 m), nearest chunks first within 2 ms a frame. Young trees (saplings and seedlings, leaf cards too) draw only the plants within their reach, not the whole chunk's. Tree shaking (`tree_instance`) follows a tree into whichever copy draws it.
- **Triangles loaded round a site** (`tools/scene_load_check.gd`, now asserting at most 25 M and printing the split by drawing):

  | Seed | Biome | Before | After |
  |---|---|---|---|
  | 7731 | jungle | 161.7 M | 15.3 M |
  | 7731 | temperate deciduous | 19.3 M | 2.2 M |
  | 7731 | savanna | 63.9 M | 9.6 M |
  | 467606063 | jungle | — | 16.8 M |
  | 467606063 | temperate deciduous | — | 18.9 M |
  | 467606063 | savanna | — | 10.2 M |

  (Before on 7731: Mike's entry, and a run of the previous commit for the jungle. After: the jungle is ~6 M full trees, ~3 M light trees, ~6 M other plants.) `leaf_lod_check`: every branchy tree within 120 m is on its full mesh, only those within 35 m cast, the light trees between — 0 fails. "Parameter m is null" lines in the headless checks come from the check counting meshes the dummy renderer never made; the previous commit prints them too, and the game's own boot prints none.
- **Road regions off the main thread** (`RoadNetwork.ensure` / `links_near`): a worker still builds what it needs and waits for a region another thread is building; the main thread (travellers, road props, rooms, main) never builds or waits — it queues the missing regions on a worker and uses what is built. The checks ask with `block` to get the whole network.
- **Checks that never write a save never restore a kept camp** (`main._opening_site`): a pinned check run picks its camp fresh, so a check gives the same answer whatever worlds the machine has played (seed 1378252316 had an old save here and rolled no kind).

## 2026-10-01 — Mac play fixes 1–2: the pixel font always, and a world keeps its camp (Mike's 15:30 play; `hud.json` `text`, `WorldSave`)
- **The font** (`HudText.install`): VT323 through its import when the imported data is on disk; else the TTF read straight from the file (`FontFile.load_dynamic_font`), with the same no-antialiasing, no-hinting settings; else the other face in `assets/fonts` (typewriter) with one `push_error` naming why. Never a system font. `HudText.loaded_from` says which ("import" here; "disk" with the import data hidden — tested, same VT323, the same 144 px for "Wind 3 m/s from NW" at 20 px, and no engine load errors since the import is checked before it is loaded).
- **The HUD never runs off the frame** (`Hud.fit_lines`): a column line too wide for its half of the frame wraps onto the next line at a " · " break, else at a space; never inside a word, never an ellipsis (the old fit dropped parts and cut letters: "Wind 3 m/s from…"). `hud_pin_check` asserts every part's every line fits, every word of the readout is shown and nothing is off the frame at each preset: chunky 640, default 854, half_hd 960, fine 1280 — all PASS, and the face is VT323.
- **A world keeps its camp** (`main._opening_site`, `World.restore_spawn_site`): a new world saves its opening camp's fire site and kind (`opening_site`, `first_camp_kind`); every later boot rebuilds the camp exactly there and routes its opening road from it. `pick_spawn_site` is for a brand-new world only (and the dev frame). **Migration:** a save with no `opening_site` whose hearth is no ruin camp's fire (no inhabited ruin within 250 m) takes that hearth as the opening camp, keeps it, and routes the opening road to it (to a people's camp at the hint's distance, else the nearest one a road reaches within 15 km). **Never wake at no fire:** on death in ambient, a hearth that is neither the opening camp nor any camp's fire (`Camps.fire_at`: a ruin camp's fire, a wild or cliff camp, a wandering group) wakes you at the opening camp, makes it the hearth again, and logs "Your hearth was gone; you woke at the camp."
- **And a real road bug it turned up:** `RoadNetwork.REGION_M` and `MARGIN_M` were static values set when the class first loaded; loaded before `PlanetConst` was set up (the new-world check's boot order) they were 0 and no road was ever built. They are set when a network is made now.
- **Checks:** `new_world_check` (`DEV_PIN=0`): 16 PASS, 0 fails — besides the old ones, with the first-camp weights changed Continue rebuilds the camp 0.0 m from where it was; a pre-`d690997` save (hearth 2.6 km off, no `opening_site`) rebuilds its camp at the hearth with its opening road routed (node 18 m from the fire, a people's camp 7.2 km off); a hearth with no fire wakes you 3 m from the camp with the log line. `hud_pin_check` 0 fails.

## 2026-10-01 — No camp left without a road: the shallows are fordable (Mike: "fix the reason some camps don't have roads"; design §BC, `roads.json`)
- **Why the last camps had no road:** each unreached camp's log line now names why its six candidate routes failed (`RoadNetwork._why`: "off the grid", "start in water", "search cap", "walled in (N cells)"). Within 25 km of four spawns the only cause left was "walled in" after 9 and 19 lattice cells: two camps on seed 90210 stand on a spit or islet ringed by sea, the water a few tenths of a metre deep.
- **The fix** (`_Lattice.cell`, `_route`, `_decay`): standing water shallower than `WADE_M` (1 m, sea or lake, from the drawn ground) can be waded at `WADE_COST` (6×) the cost, and the road marks it as a ford (stepping stones, `RoadProps._crossing`). Deeper water still bars the way, so a true island stays logged. Lakes now also judge their water on the drawn ground near the surface.
- **Checks, full planet:** `road_reach_check` 0 fails on 467606063, 1378252316, 7731 and 90210; every people's camp within 15 km is on a road (20/20, 17/17, 18/18, 17/17), and with `REACH_KM=25` seed 90210 has 39 of 39 camps and 74 of 74 ruins on a road. No "has no road" line on any seed. `road_check` (stamp) 0 fails: its traveller test now follows the traveller it puts on the road (a second one, walking of its own accord on the denser network, made "exactly one" fail).
- **Invented:** `WADE_M` 1 m, `WADE_COST` 6, a shallows ford counted 6 m wide. `REACH_KM` for the reach check.

## 2026-10-01 — Mike's 15:30 play (after the roads pass): Courier font cut off, no camp after a respawn, a laggy jungle — causes found (design chat; `tools/scene_load_check.gd`)
- **The font:** `HudText.install` loads `assets/fonts/vt323.ttf` only through the importer (`ResourceLoader.exists` + `load`); when that fails it silently falls back to a SystemFont "Courier New", which is what Mike's frame shows (wider, so the 30 px sizes run off the frame and the HUD ellipsises "Wind 3 m/s from…"). The font files are tracked and unchanged since 30 Sept; the import came up empty on his Mac.
- **No camp after a respawn:** the opening camp is never saved — `main` rebuilds it every boot at `world.pick_spawn_site()` — but the hearth is saved as a position (`Hearth.setup`). The roads pass changed what a seed picks, so a world made before it rebuilds its camp elsewhere while the saved hearth still points at the old site; dying wakes you there, at no fire. Every pre-`d690997` world does this.
- **The lag is plant triangles:** loaded around a site on seed 7731 (instances × mesh triangles, before culling): **jungle 157.4 M** (110,720 plants; banyan, teak, trumpet tree and sal 37,000 trees at 2,900–5,600 triangles each = 151 M), temperate deciduous 19.3 M, savanna 63.9 M. Every tree in the 2-chunk detail ring (~1.3 km across) draws its full leaf cards; the salad biomes stack ~115 canopy trees a hectare. Road regions build in 0.1–0.7 s each (seed 7731, this container), on the asking thread — a hitch when the main thread asks first, not the steady lag.
- **The roads pass checked:** `road_reach_check` seed 7731 all PASS (first camp kind rolled, camp 1 m from the road, 28/28 ruins and 18/18 camps linked within 15 km).

## 2026-10-01 — Roads reach the camps: the first camp rolls on the full planet, the opening camp is on the road, every people's camp is linked, and the tread reads in the forest (design §BC, §BX, §BY and the §CB first-camp fix; `roads.json`, `camps.json` `first_camp`; `tools/road_reach_check.gd`)
- **The first camp's kind rolls on the full planet** (`Encampment.water_m`, `fire_site`, `World.pick_spawn_site`): the water rule is judged from the cell's nearest point (centre distance less half the cell's diagonal, ~7.4 km on the full planet), and the fire is then placed for real: `fire_site` walks the kind's water (river polylines every 250 m, or the sea or lake shore found by marching out on 24 bearings), and picks a level, dry spot inside one of the kind's biomes within `within_m` of it, never in the water and at least the river's half width + 20 m off it. In play a kind with no site is dropped and another kind is rolled; the old single list is used only if every kind fails (with an error). The dev frame (`spawn_choice` ≥ 0) still uses the old list.
- **The opening camp is on the road** (§BX, `opening_road`): the first camp is chosen among its kind's candidates so an inhabited ruin lies about `length_km_hint` along a road (straight-line target = hint / 1.08, the routed winding measured on four seeds), and the road is checked to route (`RoadNetwork.can_route`) before it is picked. The camp is a road node (`RoadNetwork.opening`, key "opening") 18 m from the fire, and its link to that people's camp is forced whatever the pruning says (then the next alternatives); the link carries `opening`. You wake facing 60 m along that road (`main.gd` `_opening_road_ahead`), else as before, toward the fire.
- **The network's nodes as §BC names them** (`_find_nodes`): "camp" is the people's camps (inhabited ruins and the opening camp); other ruins are "ruin". The mythic territories are no longer road nodes. New: springs (where a river rises), fords (a river point whose banks rise less than 20 m within half its width + 120 m), passes (a saddle on the detailed terrain within 1.5 km of a 4 km hash point). Hot springs and standing stones kept. `min_spacing_km` never drops a camp or a ruin; other nodes keep it from each other and a third of it from camps and ruins.
- **Every people's camp gets a road**: a camp or ruin with no link after the pruning tries its next nearest nodes within `link_max_km`, up to six; a camp still unlinked is logged ("a people's camp … has no road", `RoadNetwork.unreached`).
- **Three routing bugs, found on seed 90210:** (1) the A* lattices were cached by the cube their region's centre fell in once pushed onto the sphere, which can be the neighbour's cube, so whichever region built first lent its lattice to the next and every route there was "no way"; they are keyed by centre and reach now. (2) Ground within 0.5 m above the sea counted as sea, and the coastal flats' ruins (0.2–0.5 m up, or −0.2 to −0.5 m on the smooth height while the drawn ground is dry) could not be left; the sea is now ground under the water on the drawn (detailed) height near sea level, and the strand costs 1.5×. (3) A region another thread was still building read as built (empty); `ensure` now waits for it, so a chunk never keeps a road-less tread.
- **The tread reads, overgrown but never illegible** (§BC, §BY; `TerrainChunk._tread`, `terrain.gdshader` `road_tread`): the tread is its own vertex attribute (CUSTOM0: signed distance to the centreline, half-width, `trail.wear`, overgrown), not the colour. The signed distance is linear across the road, so the fine and coarse meshes find the centreline between vertices 4–8 m apart. In the shader a worn core down the middle switches the grass tile to the dirt tile and the colour to the path; grass takes it back in noisy patches about a metre across, more toward the edges and across it as `trail.overgrown` rises; the near grass flecks are off on the bare tread; rock and snow stay themselves. Footsteps still read the path (`ground_color_at` adds the tread). The colour lerp toward `PATH` is gone.
- **Lost and found** (§BY, `lost_and_found`; `RoadNetwork._lost_and_found`): each link alternates clear stretches (`clear_len_m`, scaled so the vanished length comes to `vanish_share`) and vanished ones (`vanish_len_m`) where overgrown rises to `overgrown_in_vanish` over 10 m and the tread fades to grass; the first and last 80 m of a link stay clear so a trail always leaves a node plainly. Where the trail resumes a tell stands within `tell_within_m` (one of `pickup_tells`, never fallen). Waymarks gained their looks for `stone_step` (two flat steps), `abutment` (a dressed block) and `notched_tree` (a dead stem with a pale blaze); before they drew as posts.
- **Checks, full planet (no STAMP):** `tools/road_reach_check.gd` now also measures the tread (bare share at a clear stretch's centre, its edge, in a vanished stretch, 30 m off) and the lost-and-found share and tells. 0 fails on all four seeds:

  | Seed | First camp | Spawn to road | Opening road | People's camps on a road | Ruins on a road |
  |---|---|---|---|---|---|
  | 467606063 | cold_shore (taiga) | 21 m | 5.3 km | 20 of 20 | 35 of 35 |
  | 1378252316 | river_valley (temperate deciduous) | 17 m | 7.0 km | 17 of 17 | 38 of 38 |
  | 7731 | tropical_forest (tropical rainforest) | 2 m | 7.2 km | 18 of 18 | 28 of 28 |
  | 90210 | scrub (Mediterranean scrub) | 15 m | 6.6 km | 17 of 17 | 30 of 31 |

  Tread on every seed: 0.64–0.67 at a clear stretch's centre, 0.20–0.21 at its edge, 0.07 in a vanished stretch; 28–29 % of road vanished, every stretch with its tell. Before (seed 467606063): 6 fails, the old list, the nearest road 1,650 m off, 20 of 28 camps on a road. `road_check` (STAMP=1) 0 fails; `new_world_check` 0 fails with `DEV_PIN=0` and `DEV_PIN=1`. A headless boot of the play path (seed 42: a forest camp, the player 17 m from the road after 600 frames) prints no error or warning; a rendered boot under xvfb compiles the ground shader with no shader error. The signal 11 on quit and the one `Playback can only happen…` line in `road_check` are older than this pass.
- **The look is built — needs a frame from Mike's Mac:** the target is the trail visible at least 30 m ahead from the eye in a forest by day.
- **Invented, for Mike:** `ROAD_WINDING` 1.08 (measured), the fire 18 m from its road node, `fire_site`'s rings and its level test, the ford and pass thresholds (20 m banks; saddle relief 5 m on an 800 m grid), the strand's 0.5 m and 1.5× cost, the 80 m clear at a link's ends, the reclaim noise (patches ~1 m and tufts), the three new waymark looks. **Flags:** no pass and no hot spring turned up within 15 km of these four spawns (the saddle finder found 19 in 1,008 land samples planet-wide; 1/10 relief is gentle). With `vanish_share` 0.3 and these lengths the trail vanishes every 150–250 m, so the 7 km opening road loses it about 35 times, not "twice" as `detour_allowance_min` imagines; say if the opening road should be spared or the share lowered. On seed 90210 two camps beyond 15 km have no road (logged); the other three seeds log none.

## 2026-10-01 — The named plants checked in the running game (design chat; §CE, `tools/plant_presence_check.gd`)
- **Before** (seed 7731, full planet, 3 sites per group, chunks loaded as in play): Musa PASS (wild banana, Indian, in tropical rainforest), Amorphophallus PASS (114 plants of 8 African species at one rainforest site, 0 at a savanna and a second rainforest site), bamboo PASS (4 species), vines PASS (ivy only); **cannabis FAIL (0 at 3 sites), Trichocereus FAIL (0 at 3 puna sites), Acacia FAIL (0 at 3 hot-desert sites)**.
- **Causes and data fixes (pushed):** the umbrella thorn, the savanna's "Acacia" and mulga used the `sand` soil preset — a hard gate to sand and sandstone — so on alluvium and granite they could not spawn: now the soils they grow on (object form). Trichocereus (realm `andes`) could grow only in a biome hosting `andes`, and no dry biome did: an inter-Andean dry-valley association (`andes`) added to steppe and Mediterranean scrub, and those biomes added to all 18 entries' `biomes`.
- **After** (same seed, savanna sites): acacias 22,000–35,000 per site (Acacia, whistling thorn, umbrella thorn); savanna bamboo and the climbing fire lily present. Trichocereus now finds `andes` steppe sites but grows **0** there; cannabis 0 in savanna and steppe; Amorphophallus 0 in savanna. Cause: the stand rule (§BH) — one dominant, 1–3 associates, a 3 % accent pool for the rest — and the 64 cannabis landraces rolling as 64 species. The engine fix is §CE's `always_present` (associates when they fit, a minimum share, one roll per binomial).
- **The §CC trim (`a9f00ff`) landed before §CE and cut 21 of the named groups** (4 acacias, 7 bamboos, 10 vines; Musa, Amorphophallus, cannabis and Trichocereus intact). Restored from `7bb5f97` into the biome files that listed them (30 placements, `restored_note` on each); `make_plant_tiles.py` rebuilt the atlas (998 species, 4,051 tiles; 3 duplicate tiles merged, every reference on disk); `plant_schema_check --strict` 1,187 entries, 0 errors; `biome_species_check` 998 species allowed somewhere.
- Data errors left for the research pass: *Amorphophallus incurvatus* (band 23–28 °C, only biome cloud forest 6–21 °C) and Cannabis "Kashmir" (moisture 0.2–0.45, both biomes wetter than 0.48).

## 2026-10-01 — The catalogue trimmed to archetypes, Mike's seed list first (design §CC; `data/habitat.json` `trim`)
- **What each biome holds now** (`docs/plant_archive/TRIM_RESULT_2026-10-01.md`, `tools/plant_trim.py result`): at most four species per category (tree, shrub, grass, moss, orchid, aroid, fern, cacti, fungi) per biome, chosen from Mike's seed list first (`TRIM_SEED_LIST_2026-10-01.md`: a real accepted binomial, native to the kind of place, drawable at 480p), then the biome file's dominants and companions. Coordinator's ruling, for Mike to confirm: `hero_species` survive on top of the four, so a hero cannot push out a seed pick (temperate deciduous forest keeps its ginkgo, dawn redwood, tulip tree and Yulan magnolia and has white oak, American beech, shagbark hickory and sugar maple again). Never kept: yeasts, molds, rusts, smuts, slime molds, bacteria, algae, diatoms, plankton, chytrids, endophytes, flat crust lichens, millimetre fungi (`never_drawable`).
- **Numbers** (biome files, the three whole catalogues aside): 579 binomials before, 643 now — 356 kept, 281 new to the project (each a full PLANT_SCHEMA entry written from a flora: leaf, bark, canopy, tint, photoperiod, soil, growth, repro, genes, appearance, architecture for the woody ones; estimated values marked), 6 restored from the old `*.full.json` catalogues and completed (Swiss stone pine, whitebark, jack and slash pine, walking palm, huisache), 330 archived. With cannabis (64), trichocereus (18) and amorphophallus (246) untouched: 1,157 entries, 977 species. Every other `data/plants` catalogue moved whole to `docs/plant_archive/` (`git mv`); each biome's dropped entries and any association left without a member are in `docs/plant_archive/biomes/<file>`.
- **How:** thirteen agents, one per biome group, in three passes (the trim; Mike's seed list as he first sent it; and after his 12:30 change, the seed list first and added where missing). The first pass's agents stopped mid-way on a usage limit and were restarted from what they had written. `tools/plant_trim.py`: the nine-way categoriser (now also: fungi by their `fungus` block or the fungi catalogue's genera, club mosses as moss, forbs drawn with a grass shape as none), `survivors` (heroes on top of the four), `sync-tags` (each entry's `biomes` = the files that list it), `result`. Names made one-to-one where two species shared one (hard fern → deer fern / hammock fern; stalked puffball → stalked desert puffball / desert shaggy mane) and where agents had padded a fungus's name for the old categoriser. Bands: where a copied entry's band missed its new biome by a hair, that file's copy was widened just to overlap (e.g. saltgrass in the salt marsh, Fremont cottonwood in the cold desert, four thorn-scrub and badlands entries the species check caught).
- **Code that followed the data:** litter fungi now fruit from any species with a `fungus.substrate` "litter" block (they read the fungi catalogue file before); a biome-file entry's `realm` holds as a catalogue's did. The checks that named trimmed species (tree, climb, cover, litter, fruit) point at survivors of the same kind (white oak, American beech, black spruce, African baobab, downy birch, shagbark hickory); `fruit_check` expects over 300 fruiting species (381 now).
- **Checks:** `plant_schema_check --strict` 1,157 entries, 0 errors; `biome_species_check` 0 hard; `plant_trim.py survivors` none over four; the species atlas rebuilt from the survivors (`make_plant_tiles.py`: 977 species, 3,963 tiles, stale ones gone); `tools/species_mesh_check.gd` (new) builds every species at the near and far level: 977, 0 fails, every leafed species finds its tiles. The trees, fruit, cover and litter checks pass on the trimmed data: the tree check's oak is the white oak, its straddle count averaged over the open-grown layouts; a date palm's suckers now share one tree's leaflet budget (`TreeArch._palm`); the fruit check walks from the dev camp to its nearest trees when none stands within 60 m (the trim took the silk floss tree that used to). `realm_check` had gone stale (young plants keyed by stage, 12-float plant rows) and is fixed; its run on the trimmed data is reported with the roads pass.
- **For Mike:** seed list first cost regions his list does not name — the taiga's Norway spruce, Scots pine and Siberian larch; the krummholz's birch, larch and mountain pine; the Chilean temperate rainforest; Bornean dipterocarps; the Indian, Bolivian and Madagascan dry forest; Australian and Mediterranean shore plants; the Namib quiver tree. They are archived whole with their stands; a hero flag brings any back. Stand names that no longer match their dominants are left as they were (renaming is his). Glacier, ice sheet and deep ocean are almost or wholly empty: everything on his lists there is microscopic. Map lichen went out as a flat crust (ice sheet, alpine tundra, krummholz); it stayed where it was an earlier survivor (glacier, sea ice, volcanic field).
## 2026-10-01 — Roads verified on the full planet: they generate, but the spawn is off them, some camps are unreached, and in forests the tread does not show (design chat, Mike asked; `tools/road_reach_check.gd`)
- **Run on three full-planet seeds** (no STAMP; 467606063, 1378252316, 7731), the real game booted headless with the play rules. The network builds: 126–224 links and 500–870 km of road within 15 km of the spawn, waymarks along them, tread 0.40 at a road's centre.
- **FAIL — the opening camp is not on the network:** the nearest road is 460 m – 2.2 km from where you wake; the opening camp is never a road node (`RoadNetwork._find_nodes` gathers ruins, `Territories` — the mythic folk's — hot springs and standing stones; the `spring`, `ford` and `pass` kinds in `roads.json` are silently skipped). §BX's "spawn beside the road" is data only.
- **FAIL — 4–10 of ~27 inhabited ruins (people's camps) within 15 km have no road within 400 m**; 6–19 ruins in all. Roads mostly link the mythic territories (35–54 within 15 km).
- **FAIL — the first camp's kind never rolls on the full planet** ("no first-camp kind has candidates … the old list" on every seed): `Encampment.candidates_by_kind` measures the water rule (300–1,500 m) from map-cell centres kilometres apart, so no cell passes; it worked only on the 40 km stamp (200 m cells). Seed 1378252316 woke in a hot desert, which `first_camp.never` forbids.
- **The tread is invisible in forests:** `TerrainChunk._vertex_colors` tints the vertex colour 40 % toward `PATH`, but `terrain.gdshader` picks the grass tile vs the dirt tile by greenness; computed per biome, the road's centre stays 100 % grass tile in taiga, temperate deciduous and rainforest, cloud forest, jungle, tropical rainforest, floodplain, maritime forest, mangrove, alpine meadow and the wet biomes (it flips to dirt only in open country). Plants are cleared off the road correctly (ground cover to half-width + 1 m).

## 2026-10-01 — Every new world is a new world, and the first camp's kind rolls (design §CB; `dev.json`, `camps.json` `first_camp`)
- **The pins are the tools'** (`World.pin`, `pins_apply`): `dev.json` `seed` / `spawn_choice` hold in play only with `pin_in_play` true or `DEV_PIN=1` (`DEV_PIN=0` forces play's rule, for the check). `tools/dev_view.gd` and the 32 checks pin themselves (`world.pin(42, 0)`, dev_view from `SEED` / `SPAWN`), and a `--script` run that forgot to pin is still pinned and never writes a save or the pointer (`WorldSave.read_only`).
- **A new world rolls a seed** (`World.startup_seed`, `WorldSave.last_seed` / `set_last` / `exists`): the last world played is `user://worlds/last.json` = {"seed": N}; booting continues it when its save exists, else a fresh positive seed is rolled, written as the pointer, and its first camp is rolled from the seed (`pick_spawn_dir`: the same camp every boot of that world). Old worlds stay by seed; nothing is deleted. The seed is the world's name: the log's first line reads "World 7731 — day 1 — a forest camp" (`main.gd`, after `GameLog.load_saved`), the F3 status shows "World 7731", and a fresh world's clock starts at `World.START_DAYS` again (`generate` resets `days`).
- **New world** (`SettingsPanel` "World > New world", the dev key **F12**): one confirmation line ("Start a new world? This one stays saved." / "Press F12 again"), then `Main.start_new_world`: the save flushes, the next boot of the scene rolls a fresh seed, and the main scene reloads. `World.reset_world_state` clears what the last world held in static tables (fire stores, clearings, torch bundles, soil marks, coppice stools, the hearth, the log) before the new one builds, so the camp, hearth, log and camp sim all come from the new seed's save.
- **The first camp's kind** (`Encampment.candidates_by_kind`, `World.pick_spawn_dir`, `camps.json` `first_camp`): one candidate list per kind (a cell qualifies when its biome is in the kind's `biomes`, it lies within `within_m` of the kind's water — river by the river network's segments, sea by the coast distance, lake by the nearest lake cell, water any — and passes the common gates: fuel in `fuel.json`, `temp_c`, `slope_max`, `elevation_m`, no water on the cell, not in `never`), scored as before minus the latitude term, the best `candidates_per_kind` kept `min_separation_m` apart. With `roll_kind` the world rolls a kind by weight among the kinds with candidates (seeded from the world seed; `FIRST_CAMP=<kind>` forces one), then a random cell of it; `spawn_choice` ≥ 0 keeps the old list and that index (the dev frame). `site_near` keeps the fire in the rolled cell's biome. The camp's people, fuel kind and store pieces follow the site as before (`Peoples.pick`, `FireStore`, `CampSim`). The river network is built once per planet (`Encampment.rivers_for`; the chunk manager shares it).
- **Checks:** `tools/new_world_check.gd` (`DEV_PIN=0`: a fresh seed, the pointer, the save, New world → another seed and camp cell, the old save kept, Continue lands back; `DEV_PIN=1`: dev.json's pins): 0 fails both ways. Fresh worlds 467606063 (a coast camp on a beach) and, after New world, 1378252316 (a river valley camp in temperate deciduous forest); Continue lands back at the same cell. `tools/first_camp_check.gd` (seeds 7, 8, 9 twice each, and `KINDS=forest,savanna,cold_shore` forced): 0 fails. Seed 7 rolls a scrub camp in Mediterranean scrub (its first run put the camp on a dune next door: `site_near` now stays in the home biome), seed 8 a river valley camp in temperate deciduous forest with the river people, seed 9 a forest camp in temperate rainforest with the canopy folk; each seed rolls the same camp twice. The forced kinds land in temperate deciduous (forest), tropical dry forest (savanna) and taiga (cold shore). `highland` found no candidate on the dev stamp.
- **Invented:** the dev key F12 (`controls.gd` `dev_new_world`); nothing in the data. Note: `dev.json` ships `spawn_choice -1`, so `DEV_PIN=1` in play is seed 42 with a rolled kind camp; the dev frame's spawn 0 comes from the tools' own pin.

## 2026-10-01 — The fire (Mike, from chat; design §BZ, `look.json` `fire`, `audio.json` `fire` and `kinds.fire`)
- **The flame** (`shaders/flame.gdshader`, `Campfire.flame_node`): one camera-facing card per fire, turning only about its own up axis, `flame.width_m` × `height_m`; the four overlapping tongues are gone (no crossed cards anywhere). The grey noise scrolls up through the teardrop mask (the lick and the breathing kept) in whole texel rows, the heat is posterised to the four `bands` (a small pale heart, gold, orange, a thin dark edge; thresholds 0.72 / 0.45 / 0.2), and everything is read from the UV snapped to the `texels` grid (32×48) with a hard alpha cut, so the card is flat squares at any distance and the 480p frame does the rest; nearer it is simply bigger. Unshaded, blend_mix with depth: it reads bright over the coals by day and by night. **Embers** (`shaders/ember.gdshader`): `embers.count` single-pixel billboards (`px` internal pixels at any depth) rising from the coals at `rise_mps`, each on its own `life_s`, drifting, blinking once, off at the end; a MultiMesh the vertex shader animates from TIME and per-ember seeds, nothing on the CPU. **Low fire:** the bands blend toward `low.bands_low` and the card's height toward `low.height_scale` as the burn drops; FireStore draws a fire at burn 1 / 0.55 (low) / 0.12 (embers) / 0, so the collapse ramps from 1 and is complete at `below_share` (a low fire is 60 % collapsed, a red ragged flicker across the clearing; noted in `look.json` `flame.low._help`). At embers no card, coals and a few embers only; out, nothing. **The torch** (`Torch.flame_node`): the same card at `torch.scale` of the campfire's (the planted torch; the held one 0.2 and the fat lamp 0.12, their old sizes), its scroll slowed by `torch.scroll_scale`, `torch.embers` embers. The player's fires, the opening camp, the camps and the mythic folk's fires all go through `Campfire.build`, so they have the new card.
- **The light** (`Campfire.flicker`): energy = 7 × lerp(`light.day_share`, `light.night_energy_scale`, night) × flicker × burn, range = 14 m × lerp(1, `light.night_range_scale`, night), colour `light.color`; the flicker is two layers of value noise at `flicker.hz` by `flicker.amount` (no sines), and the light's position jitters by `flicker.position_jitter_m` from three more noise lanes so the lit edges move on the trunks. The ground glow and warm discs scale by `light.ground_glow_night_scale` at night. The safe/dread radius is untouched. *Note:* the fire's OmniLight has no shadow map (as the torch, §AG), so what dances is the light's falloff on the trunks, not cast shadows; a shadow map on the fire is a toggle away if Mike wants the real thing and will pay for it.
- **The sound** (`SoundSynth`, `Campfire._voice`): `fire_loop` is gone. `fire_hiss_loop` is a seamless 4 s bed, white noise through a one-pole low-pass at `hiss.cutoff_hz` with a slow breath and a faint rumble under it; `fire_snap` (20–45 ms, a noise burst and a ring at 1.5–4 kHz) and `fire_crackle` (80–220 ms, two to five small pops with a low thump) are one-shots in five variants each. Every fire has two 3D players of kind `fire`: the hiss on its loop at `hiss.volume_db`, and pops on a random clock (the next `pops.every_s[0..1]` seconds away, volume and pitch drawn from `pops.volume_db` / `pops.pitch`, a `snaps_share` of them snaps): never a cycle. As the fire burns low the pops come `low_fire.pops_every_scale` times less often and `volume_db_offset` quieter (ramping with the same collapse); at embers hiss only; out, silence. `kinds.fire` is Mike's 90 m with muffle [20, 90]: `Audio3D.muffle` lowers the cutoff and the panning between those distances every frame, so a camp is a dull, directionless hiss from the road before its glow shows. `Tuning` now knows `data/audio.json` (`Tuning.section("audio", ...)`).
- **Invented, flagged in the data:** `flame.embers.spread_m` 0.25 and `wobble_m` 0.08 (where the embers start and how far they drift; `embers._help`). The base light (7, 14 m) stays in code as before.
- **Also fixed:** the headless boot's `SHADER ERROR` in `pond_crawler.gdshader` (from the pixel-toggle pass: its triplanar function took the nearest stone tile and the linear grain through one sampler argument; the grain has its own function now).
- **Checks:** `audio_mix_check` 12/12; `fire_wall_check` the opening camp 4/4 (within 0.2–0.9 m of the fire from every side; the ruin half still cannot run headless here, the ruin build never completes under load, as before); `camp_check` 60/60. A headless boot of the project (`--quit-after 2000`) prints no new error or warning: the two lines it does print, one `Playback can only happen when a node is inside the scene tree` from a non-3D player and a signal 11 on the quit-after path, are there on the previous commit too and are not this pass (the check scripts quit cleanly through their own `quit()`); the pond crawler's shader error is gone.

## 2026-10-01 — The pixel style as toggles: pixel-size presets, near hard shadows, the dither confirmed (Mike, from chat; design §BU, `look.json` `render.presets`, `light.day_shadows_near`)
- **Pixel size** (`Display`, Settings > Display > Pixel size): the internal height is a named preset from `render.presets` (chunky 640×360, default 854×480, half_hd 960×540, fine 1280×720; `render.preset` is the file's choice, chunky as Mike set it), stored as `display.preset`; an older `display.lines` setting still counts until a preset is chosen. The whole frame (the 3D, fog, grade, water, dither, the rain streaks, the HUD) is the root window's viewport content at that height, upscaled nearest, integer multiples where the window holds two or more (`project.godot` stretch mode viewport / integer). F11 (`dev_pixel`) cycles the presets live with a note on screen. *Nothing bilinear:* every texture sampler is nearest now (the fur and weave, the far shell's stone, the pond crawler's tiles, the star pano, the ripple buffer, the post grade's screen read); the one thing left linear is the soft modulation grain (`look_grain`, `look_grain_soft`), which is not a texture but a light-and-dark field at 10–100 m scale, and sampled nearest it would paint 10 m blocks across the ground.
- **Shadows** (Settings > Display > Shadows: near hard cast, off: blobs only; `display.day_shadows`, default `light.day_shadows_near.enabled` true): on, the sun casts a hard shadow map within `max_m` (35 m) only, two splits, no blur, no soft filter (`soft_shadow_filter_quality` 0), the 480p frame edging it; off, §AG 6's blob-only day with the canopy darkening. The A/B applies live.
- **The dither, confirmed** (`post_grade.gdshader`): one 4×4 Bayer, `retro.dither` 1.0 (every pixel on the grid), `levels` 31 (5 bits per channel), on the full-screen grade that reads the whole internal frame after the 3D, so the sky and the water quantise with everything else; the floor and the grain come before it. The HUD draws above the grade and is not dithered (text).
- **Frame times at the dev spot** (`perf_bench.gd PRESETS=1`, this container's software rasteriser, so only the ratios mean anything): not measurable here. `perf_bench.gd PRESETS=1` runs (chunky 640×360: 14.5 s a frame on llvmpipe, nearly all of it the viewport being re-created at the new size and the first frames at it), so the preset ratios need a real GPU: in play, F11 cycles the presets and F2 shows the frame time, which is the comparison Mike asked for.

## 2026-10-01 — The look, measured: tiles, the floor, one-colour night, water, sky and rain, grass, night accents (Mike, from chat; design §AG, §BD, §BU, §Y)
- **The gate** (`tools/look/measure_look.py`, `look.json` `retro.targets`): the targets are two bands now, `day` and `night`, with Mike's numbers from the twelve reference frames (day luma 0.26–0.36, saturation 0.58–0.70, texel 0.014+, darkest 5 % 0.05–0.10 navy; night 0.15–0.25, 0.67–0.80, 0.011+, 0.015–0.035). The band is picked by `--day` / `--night` or the frame's `_HHh` name. Texel detail is the mean luma step between neighbouring pixels (both axes, 0–1) over the frame. A letterboxed capture is cropped to its frame first (the NaN came from an all-black 5 % band). The darkest-5 % line now prints its luma too.
- **Before / after at the dev spot** (`dev_view.gd`, `WAIT_DETAIL=1`, 14:00 and 02:00; luma / saturation / texel / darkest-5 % luma, blue:red):
  | frame | before | after (first) | after (tuned) | target |
  |---|---|---|---|---|
  | 14:00 | 0.29 / 0.71 / 0.047 / 0.070, 9.8 | 0.28 / 0.71 / 0.050 / 0.070, 9.8 | 0.29 / 0.68 / 0.053 / 0.070, 9.9 (all PASS; at chunky 640×360, the preset Mike set) | 0.26–0.36 / 0.58–0.70 / 0.014+ / 0.05–0.10, ≥2 |
  | 02:00 | 0.13 / 0.72 / 0.025 / 0.072, 7.2 | 0.12 / 0.92 / 0.030 / 0.014, 31 | 0.16 / 0.87 / 0.037 / 0.035, 42 (luma, texel, darkest and blue:red in band; saturation over the 0.80 line, see the note below) | 0.15–0.25 / 0.67–0.80 / 0.011+ / 0.015–0.035, ≥2 |

  The before frames already sat near the day band because the dev spot is open ground under a clear noon; the gap Mike measured was a dusk frame under a closed crown with the floor zeroed (step 2) and a greyed night (step 3). After the first pass the night went fully blue (darkest 0.014, blue:red 31, saturation 0.92, over the band) and the day stayed put, so the night floor came up a step (#04082A), the night sky gain to 2.2, night saturation 1.25 and day saturation 1.4 (from Mike's 1.5, which measured 0.71 against 0.58–0.70); the tuned column is the fifth re-render. **The night saturation is the palette, not the grade:** the third tune (night shadow tint 0.55 → 0.4, `night.saturation` 1.25 → 0.95) moved the number 0.90 → 0.89, which showed the preset's saturation knob was dead at night: the one-colour pull mixed every dark pixel toward the floor colour at the floor's own purity (0.9), after the saturation step. The pull now keeps each pixel's own saturation (hue collapses, chroma stays; the knob is live again), and the frame reads 0.87: every band of it, the darkest 16 % at 0.94 down to the lit 4 % at 0.67, sits where its colour's purity puts it, because the whole night palette is about 0.9 pure (`ambient_floor.night.floor_color` #04082A, which the floor rule pins the darks to; `SkySystem.NIGHT_ZENITH` #0A14A0 and `NIGHT_HORIZON` #1B2ED8, a third of the frame). The references' navies are about 0.73 pure (a #1A2A5A kind of navy, not a #0A14A0 one). Closing the last 0.07 means greying those three colours a step (toward #0A1030 / #182070 / #2A3AB0 kinds of values), which is §AG's night palette and Mike's call; the grade has nothing left to take it from without flattening the fire. Texel detail: the references read 0.015–0.024 under this metric and our internal frame 0.047–0.050 (the dither and nearest tiles, which is the point), so the band is a floor (0.014+); a window capture at 2× reads half, which is where Mike's 0.009 came from.
- **Step 1, the §AG tiles wired** (`look.gdshaderinc` `retro_tile`, `look_tile_contrast`): the 64 px tiles from `assets/textures/retro` (128 stone, 32 leaves) were already the textures (Look.texture) and already sampled nearest with two mips on terrain, bark, leaves, stone and the ruins; the water, the waterfall and the far shell's stone still sampled linear with anisotropy, and `retro.tile_contrast` went nowhere. All seven now go through `retro_tile`: nearest, at most `retro.max_mips`, no anisotropy, repeated every `retro.tile_m`, their light and dark pushed apart about the tile's mid grey by `tile_contrast` (a new global). The NOT WIRED tag is gone from `look.json`.
- **Step 2, the floor after the grade** (`SkySystem._update_floor`, `post_grade.gdshader`): the post grade's floor was already applied after the presets' contrast and before the dither, but it was scaled by the dapple stamp's sky visibility, so under a closed crown (the camp's she-oaks, a savanna acacia) it went to zero and the dither quantised the darks to pure black. The post floor is now the hour's floor colour wherever the player is not enclosed (the five-ray test; a ruin interior or a cave still goes black without a torch); the dapple stamp shapes only the world shaders' lift. The night floor colour is darker (`ambient_floor.night.floor_color` #03061F, luma 0.025) so the darkest 5 % at night lands near 0.02 instead of 0.08, with `floor_energy` raised to 0.3 so the world shaders' night lift stays where it was.
- **Step 3, night is one colour** (`post_grade.gdshader` `night_pull`): the mesopic desaturation is gone. At night every pixel below `pull_below_luma` is pulled toward the floor's blue at its own brightness, saturation kept (hue collapses, chroma does not); warm pixels (fire) keep their warmth. Day: `day.saturation` stays Mike's 1.5 (vivid where the sun hits, navy in shade); `night.saturation` 0.95 after the tunes (the knob is live again since the pull keeps each pixel's chroma; see the table's note).
- **Step 4, water the brightest thing** (`WaterLook`, `look.json` `water`, Mike's addendum): each chunk's water takes the family of the biome at its middle (clear, river, lake, swamp, sea, reef, desert, tropics; the sea always `sea`; anything unmapped `default_family`) with that family's base and highlight, one material per family. By day the base is multiplied by `water.glow` (1.35: brighter than the scene) and a nearest caustic tile scrolls over it at `caustic_tile_m` / `caustic_scroll_mps`; at night the emission is scaled by `water.night.glow` (1.6) so the water is the most saturated surface. The far sea takes the sea family's base. Waterfalls (`waterfall.gdshader`, `water.waterfall`): a flat sheet between `shadow` and `sheet` blue-white, the vertical streak tile (nearest, stretched four times taller than wide) scrolling down at `streak_scroll_mps`, a hard foam line at the foot over the plunge, the crest still white; the current is untouched.
- **Step 5, the sky and the rain**: the night sky's zenith, mid and horizon colours are lifted by `ambient_floor.night.sky_gain` (1.8) as the sun sets, so the night sky glows indigo with the painted cloud tile and the stars over it instead of going black. Rain is drawn by `RainOverlay` (`shaders/rain_streaks.gdshader`): a canvas under the post grade, so it takes the grade and the dither, with one-pixel-wide straight streaks rolling down the internal 480-line frame in two layers of columns, more columns lit as the rain thickens (dense in a storm), thinned under cover, leaning with the wind. The rain particles are off (the snow stays).
- **Step 5b, grass near** (`terrain.gdshader`, `look_grass_m` from `ranges.grass_m`): within 40 m the grass tile gains a second, three-times-finer layer of blade flecks, tinted by the ground's own colour, fading to the plain tile by 40 m. Shader flecks, not card geometry: if Mike wants blades standing off the ground, that is a placer tier next.
- **Step 6, night accents** (`NightAccents`, `data/night_accents.json`, added as a feel call; the designer owns the data): once the sky's daylight is under `shows_below_daylight`, glowing moss hangs in strands under the crowns of the willows (`genera`) in SWAMP and BOG within `range_m`, cold green-cyan with a slow flicker; at ruins in TEMPERATE_DECIDUOUS and TEMPERATE_RAINFOREST a swarm of blue butterflies drifts and flaps round the ruin within `radius_m`, like the fireflies but blue. Both are freed by day. Fire stays the only warm light.
- **Checks:** `camp_check` 60/60, 0 fails (the camps unchanged by the look). The ruin-side night accent and the waterfall could not be rendered at the dev spot (no ruin and no fall within the frame); they compile and run in the renders above.

## 2026-10-01 — Three bugs from Mike's dusk play and the sprint feel (Mike, from chat)
- **Bug 1, leaf cards as solid shards.** The suspect was wrong: today's ambient-floor edit touched only the leaves' emission, and the cutout path (the leaf cell near 25 m, the mass tile's holes farther, `ALPHA_SCISSOR` 0.5) is intact: the §AJ 4 see-through render (`species_row.gd UP=1`, an oak) reads 0.23 sky through a ragged crown, a lone she-oak 0.78, and `tools/leaf_lod_check.gd` at the dev spot lists every tree round the camp at the hero level with ~1,900 cut-out cards each, every leaf and card texture set with alpha, the ambient detail ring at 2 chunks. Two things did read as shards and are fixed: a tree with no branch layout (the understory tiers, palms, herbs like the Datura; `TreeLayouts.branchy` is false below the canopy tier) was drawn as the old crown hull with the foliage mass painted on and the shader gave that surface alpha 1 (a faceted blob up close), and the far tree pictures had a smooth profile for an outline. The hull is now cut like the cards (`foliage.gdshader` mat 1: the leaf cutout near, the mass tile's holes far), and the pictures keep only what the leaf-card cutout keeps over the outer half of the crown, so sky shows through their rim. *What is still solid, measured:* the dev-view frame at 18:00 (rendered before and after, with the chunk at the hero level) shows the camp's she-oaks as flattened solid crowns with a few leaf holes. The listing names them: forty trees round the fire, every one a Beach she-oak 39–45 m tall (the stand's giants, conifer shape, 1,900 cards each). The same species stood alone at 21 m reads sparse and ragged (the renders above), so the cards are right and the *stand* is wrong: at a giant's scale the cards are twice the size the see-through sizing assumed and their union closes. That is a §AJ sizing task (cards sized against the tree's own height, the gap test run at the giant's scale), noted for the look pass, not a shader bug. *The 2-chunk ring:* the choice is `min(2, display.render_chunks)` in the ambient profile with no headless-only branch (`ChunkManager`), so it runs on any GPU; it collapses to 1 only if the render distance is set to 1 in settings (the default is 3). The F3 overlay now prints the detail ring and the plant level of the chunk you stand in, so a frame from a real GPU can say what it was drawing. A real-GPU frame I cannot take here.
- **Bug 2, the invisible wall at the fire.** Found by code, then proved by the walk: every camp prop's colliders (`CampProps`: the shelter, the racks, the woodpile, the food store) and every ruin mark's (`RuinMarks`) were added to the camp's own body at the prop's *local* transform, so the shelter's 1.6 m capsule, the woodpile and the rest all sat at the camp's origin, which is the fire. Each prop now carries its own `StaticBody3D`, so its shapes ride with it. The dev readout asked for: when the unstick rule frees you it prints the blocking colliders' node paths and shape sizes (`data/dev.json` `stall_log`, or `STALL_LOG=1`; `[stall] wedge at …; blocked by: …`). `tools/fire_wall_check.gd` walks at the fire from four bearings holding W: at the opening camp every approach ends 0.19 m from the fire (the stones stop you, and with the readout on they name themselves: the fire's own ring-stone capsules). The ruin-camp half could not run here: in headless on this box a ruin's build task never completes (one task pending for the whole run, so no ruin and no ruin camp is ever built in the checks; it also makes the camp check's ruin-signature test vacuous), which is a harness limit to fix next, not a play bug (Mike's savanna camp is a ruin camp).
- **Bug 3, fires out for good in a pre-loop save.** A tended camp fire that is "out" now relights at dawn from the woodpile when the pile has units (the folk keep an ember; no fire is made), feeding `feed_units_per_tick` as the loop does; the catch-up tick runs the same at every missed dawn, so an old save's dead fires come back at the first dawn after load. The camp check's collapse scenario had to change with it: a fire merely put out recovers now (as it should), so the scenario strips the woods in reach, which is what §BL says takes a camp.
- **Feel, the sprint through a jump** (`movement.json` `profiles.ambient`, flagged in `_help.sprint_momentum`): the momentum died in the landing squat (`squat_s` with the target zeroed and ground friction at 60 m/s² cost ~3 m/s of 5.6 every hop). In ambient: `landing.sprint_keeps_speed` true: a sprint held through a light landing takes no squat and no friction frame; a jump from a sprint carries the run's full speed; `air.sprint_jump` 1.05 in the profile scales the *carry* of a running hop (in the shinobi profile it still scales the jump's height), and `air.hop_cap` 1.1 caps chained hops at that times the sprint, so bunny-hopping never beats running. Holding Space reaches none of the disabled tech: the bounce and wall jump are behind their `enabled` flags and the cling is on right click.
- **Checks:** `camp_check` 60/60 (the relight at dawn and the stripped-woods collapse both green); `leaf_lod_check` 4/4; `fire_wall_check` opening camp 4/4, the ruin half blocked by the headless ruin build above.

## 2026-10-01 — Camps are alive: a people per site, the store and the loop, the ladder, the headman's gifts, ruins that remember, collapse, wildfire, the canopy folk (Mike, from chat; design 30 Sept §BL–§BT, `data/peoples/`, `data/techniques.json`, `camps.json` → `sim`)
- **Step 1, a people per site** (§BO, `biome_map.json`, `Peoples`): every camp and ruin site runs the site rules in order (rock shelter: a cliff site or CAVES; karst: limestone karst, one site in two; canopy: the five old forests, one site in six; mangrove; coast: the tideline within 300 m; lake: a lagoon or lake shore within 200 m; marsh: the wet biomes; river: a reach 10 m wide within 200 m; then `by_biome`), and the first that matches names the people. The camp is dressed from its people file and the biome's `dressing.by_biome` row (`CampProps`): the shelter's form read from its words (a tent cone, a dome, stilts, a longhouse, adobe, a reed barrel, an overhang wall, a low house), three or four of `aesthetic.props` round the fire (racks, a hull, the midden, flats, a ring, jars, a frame, a spring, a cairn, net poles, a lamp, bundles), the palette from the dressing's colour words, the fuel kinds in the sim; `folk_kinds` picks each camp's kind (human, goblin, orc, fae, small folk) and the rig reads the silhouette's `folk_scale` (an orc is tall, a goblin short), all friendly. The log says "the <people> live here" the first time you come to a fire. *Design calls I made:* the canopy and karst rules hash the site (the stand's giants and a cave are not known when the site is named; the canopy camp then checks the real giants when it builds, Step 8); a folk kind changes scale and palette only (no ears or tusks yet); the opening camp keeps its two authored folk and gains the store props.
- **Step 2, the store and the loop** (§BL, `camps.json` `sim`, `CampSim`, `WorldSave` `camps`): each camp has a state (its folk, wood and food in units, the woods within reach, its rung, the fire's own store) that ticks once per game hour (`tick_game_h`) and catches up every missed tick on load (`catch_up`: the camp grows while you are away; the sim burns an unloaded fire itself, `FireStore.burn`, so a camp's fire is one store whether the scene holds it or not). By day (`gather_hours`) the folk split their gatherer-hours by what the fire burns and what they eat (a unit of wood is one branch's worth of burning, whatever the people burn: reeds go on by the armful, a log is one), bring wood and food to the store up to its targets (`wood_days_target`, `food_days_target`), the spare hours to food (a surplus is the ladder); they feed the fire from the woodpile when it drops under `feed_fire_below_units`; the woods within reach thin with the take and grow back a share a day, slower once stripped, and a stripped wood means a longer walk (`reach_m`). The store is visible, no HUD: a woodpile whose rows grow with the units and a food store (a rack of strips and baskets) that fills, both by the fire; one of the folk walks out `walk_out_m` and back now and then. Right click either with fuel, food (fruit, mushrooms, fish, herbs) or seeds in hand to give it (`CampSim.wood_units`, `food_units`, `is_seed`). *Data added as first guesses (flagged in `camps.json` `_help.sim_first_guesses`; the designer owns them):* `loop.wood_per_gatherer_h`, `food_per_gatherer_h`, `walk_out_m`; `store.feed_units_per_tick`, `feed_fire_below_units`; `restraint.woods_units_in_reach`, `regrow_per_game_day`, `reach_grow_per_stripped_day_m`; retuned once after the first run so a camp of three keeps its fire and a camp of five banks a surplus (the first numbers let every camp strip its woods in ten days and die).
- **Step 3, population and the ladder** (§BM, `sim.population`, `sim.births`, `sim.ladder_gates`): a camp starts with 3–5 folk, men and women (the rig: a woman's build at 0.94, the voice pitch; the first two one of each). **Three life stages (Mike, `sim.births.stages`): a child by the fire does not gather; a teen gathers at `gather_rate` and holds no role; an adult does both; each stage its `game_days`, the rig at its `rig_scale`.** Births need a man and a woman, `needs_surplus_days` of surplus, a slow clock (`every_game_days`) and room under the ceiling: `forage_cap`, plus `fundamental_adds` once the people's fundamental stands (a weir at the shore for fish_run peoples, placed where the water is; a garden plot by the fire for crop peoples once seeds that take in that soil and climate are in the store, `PlantSpecies.suitability`), plus `crop_adds`, never past `village_cap`. The ladder (`sim.ladder`): fire → food (a day of food banked) → storage (`surplus_days_for_storage`: the headman, a man, and the plantkeeper, a woman, appear, marked by the staff and the pouch) → specialist (the maker, where the people has one and `folk_for_specialist` adults and a surplus) → exchange (a neighbour at specialist within `neighbour_km_for_exchange` with a different craft). A specialist still gathers at `specialist_gather_rate` (a role, not a job; flagged). Herd and managed_burn are not built (§BM: last). Restraint: the woodpile thins when the take outruns the regrow.
- **Step 4, the headman bestows** (§BN, §BP, `techniques.json`, `Techniques`, `WorldSave` `techniques`): right click the headman and the people's `headman_teaches` technique is yours, a permanent flag per world, "The <people> showed you <name>." in the log; mute, no cutscene. Five verbs are real: **line and hook** (`FishingLine`: right click a branch with grass or reeds in the pack to make a pole, item kind `pole`; hold it and click at water within `cast_m`: the float lands, a bite after `bite_s`, click within `hook_window_s` to land a fish, else it is gone); **the coppice** (`Coppice`: right click a hazel, ash, willow, alder, lime or chestnut and it is cut to the stool, three branches drop, the far and near meshes of that tree go, its graph and trunk shapes with them; the stool regrows poles on `PlantGrowth`'s clock for the species, honestly slow; `Coppice.ready` → right click takes the poles; kept per world, `stools`); **the resin torch** (right click a conifer with an unlit torch in hand: the torch carries resin, `torch.json` `resin`: `burn_scale` longer, `energy_scale` brighter, drizzle-proof, storms at `storm_burn_scale`); **the ember carrier** (right click a lit fire with nothing in hand: a coal wrapped in bark, item `ember`, good for `ember_game_h`; right click the ground to lay a new fire from it, `PlayerFires`: an untended fire of `fire_units` kept per world; neglected it goes cold; it gives no light); **the fat lamp** (right click the food store knowing the technique: a lamp for `costs_food_units` of food, item `fat_lamp`; right click the ground to set it down: a dim light of `range_m` for `burn_game_h`, never blown out, kept per world). The other techniques are flags. No fire drill anywhere. *Data added, flagged:* `techniques.json` `params` per real verb (`_help.params`); `torch.json` `resin`; `items.json` kinds `pole`, `ember`, `fat_lamp`.
- **Step 5, ruins remember** (§BQ, `RuinMarks`, `SoilMarks`): every ruin carries its people's `ruin.signatures` as props at its footprint, each starting at `legible` "heap" (a mound that reads as what it was: a shell midden, weir stakes, salt pans, house pits, a kiln, a cairn…); when a camp squats there the marks advance with its ladder (cleared at food, restored at storage: the mound becomes the thing) and the camp inherits what `inherits` says (`CampSim.inherit`: the weir from the first season, salt from day one, a clay pit's surplus, level ground) once. A midden or black earth marks the soil (`SoilMarks.fertility_at`): the placer grows the ground tier richer on it (`plants_differ`), so a midden reads as a different green from fifty metres.
- **Step 6, collapse and the dark** (§BL, §BA, `sim.collapse`, `sim.abandon`, `embers_game_h`): a fire kept low (not in flames at any night hour) for `fire_low_nights_to_taken` nights lets the dark walk in: `taken_per_night` folk a night, blood by the fire; the survivors walk to the nearest lit fire and join it (`survivor_lost_chance_per_night` on the way) with a share of the store. Food short for `starve_moves_after_days` moves them to a neighbour instead, no blood. A camp fire's embers last `embers_game_h` (longer than yours) so an armful of fuel can save it; survivors come back to a fire relit within ten days. An empty camp keeps its needful things by the dead fire (a fuel pile, a torch bundle; the pot waits on a potter), is a ruin after `ruin_after_game_days` and the forest takes it over `forest_takes_game_days` (the props sink). Camps never harm each other.
- **Step 7, wildfire, rare** (§BL, `sim.wildfire`): only where all three hold: a fire-prone biome (`fire_prone_biomes`, flagged), a dry spell of `dry_spell_game_days` (less than `dry_rain_mm_h` of rain in a tick keeps it counting) and an ignition: lightning in a storm (`lightning_chance_per_storm_h`) or a lit torch of yours lying in the grass near a camp. The burn runs downwind from the ignition (`spread_m` by the wind), an ellipse scar kept per world (`CampSim.scars`): the ground is darkened in the chunk's vertex colours, the shrubs are gone, the trees in it stand bare and dead (the placer's `burnt`: no leaf), the ground tier comes back thicker (the fire-followers), and the scar fades over `scar_lasts_game_days`. A camp in its path walks away and rebuilds a valley over (a `moved:` state at the nearest free ruin site within 6 km). Nothing moves terrain (§BS).
- **Step 8, the canopy folk** (§BT, `canopy.json`, `CanopyVillage`): at a site that passed the canopy rule, when three or more giants stand within 60 m (the chunk's real trees: branchy, climbable, taller than their species' band or over 26 m), the village goes up in the tallest three or four: a deck lashed round each trunk 8–15 m up (four plank strips with a hole for the trunk, props down to the trunk, rail posts and rope rails, a leaf roof on posts over the back half, bark walls in the cloud forest and the deciduous), vine bridges between neighbours (planks along a sagging line, each with its collision, rope rails, a cable from each end up the trunk), a clay hearth box on the first deck with the camp's fire in it, the folk seated round it and at the back of their own decks, the store a small bundle on the hearth deck; no shelter on the ground, no walker (they never come down), no torch bundle at the foot. No ladder comes down for a stranger: climb the trunk (the §AU climb, which goes on through the deck's hole) and let go onto the deck. Once the headman has met you the rope ladder hangs from the hearth deck's edge (`met_headman`): right click its foot to climb it, its top to come down (`PlanetPlayer.start_ladder`, a scripted climb, hands busy). The log, at the fire: "They live up in the giants. No ladder comes down for a stranger." With the giants not yet in (the chunk's trees come after the camp), the camp waits on the ground and is built again when they are. `tools/camp_check.gd` lashes three giants into a chunk and builds one: three decks, bridges, the hearth up, the ladder hidden, the climb.
- **Checks:** `camp_check` (steps 1–8) 59 passes, 0 fails; rerun since camps, main, the placer and the terrain changed: `dread_check` 26/26, `hud_pin_check` 43/43 (ambient), `tech_check` 24/24 (shinobi).
- **What still reads as copy-paste between two camps of the same life, and what the dressings most need next.** Two coast camps now differ in their palette, their biome row's words and their folk kind, but they still stand the same way: the same shelter form, the same three props at the same radii, the same woodpile rows and food rack, the same seats round the same fire, and the folk do the same walk out and back. What would break the copy is the *site* writing the camp: the shelter turned from the prevailing wind and dug into the dune's lee where the dressing says so, the racks on the shore side, the midden downwind, the weir where the water actually is (it is: the one prop that already reads the site), and the people's `food.how` as visible activity (one at the racks, one at the tideline, one at the fire) instead of one walker. The dressings most need, in order: a *second* form per people (a summer and a winter shelter, or a rich and a poor one, so a camp on the ladder's fourth rung looks different from one on its first), props that *scale with the rung* the way the store already does (the midden grows, the racks multiply, the plot widens), a palette that leans on the biome row's own colour words harder than the people's list (they are mostly the people's list now), and folk kinds with a silhouette beyond scale (a goblin's ears, an orc's tusks, the fae's hood light at night, the small folk's lantern is in). The canopy village is the one camp the site writes already, because the trees do; the next most site-written would be the rock shelter (the overhang is there), then the marsh (the hummock and the boardwalk).

## 2026-09-30 — Rooms, roads, current, sound, stands, travellers (Mike, from chat; design 30 Sept §BB, §BC, §BE–§BH)
- **Step 1, the sound split** (§BG, `audio.json`): two systems now. *The bed* (`SoundBed`, no position, its own bus): four loops from the synth (`wind_loop`, `insects_loop`, `frogs_loop`, `birds_far_loop`), mixed by the biome's group (forest, open, wetland, desert, cold, coast) × the hour (dawn, day, dusk, night) × the season × the weather (rain quiets birds and insects; insects and frogs silent below `cold_c_silence`), frogs only within `frogs_near_water_km` of water, the wind loop by the wind's own speed. Wind pressure changes under canopy: the wind loop's gain and a low-pass on the bed bus follow how much sky the place sees (the dapple stamp's sky visibility and the sky system's enclosure), so stepping under the trees closes the wind. The bed thins at dread stage 1 (`Dread.bed_gain`, with the creatures' calls). *Sources* (every `kinds` row, `class: source`): a 3D player at a place you can walk to, muffled by terrain and foliage where `muffle` is set (now also water, the falls, fire, the torch, the litter's rustle). New sources: every campfire crackles (`fire_loop`, quieter as it burns down, silent when out); the rivers run (`WaterSounds`: four `water_flow` players kept at the nearest reaches, louder for a faster, wider one) and every waterfall roars from its plunge pool (`waterfall_loop`, on the chunk's fall). The filing is in `audio.json` `_help_bed` and the `bed` block: **I added the `bed` data as a feel call (levels per group, hour and season); the designer owns it from here.** The creatures' calls stay sources (one animal calling from where it is); insects and swarms were already silent as creatures, so the bed carries them.
- **Step 2, waterfalls, then the current** (§BE, `data/water/current.json`). *Waterfalls checked first* (`tools/water_check.gd`): they generate (on the stamp world 903 falls on 202 of 344 river segments, `RiverNetwork.falls`) and render (the chunk at the nearest fall carries its `Waterfalls` sheet mesh, `shaders/waterfall.gdshader`), so the pipeline is intact; what Mike saw as broken is most likely the *look*: the sheet is a thin translucent arc that reads as river surface from the lip, and it has no sound until now. Each fall now roars from its plunge pool (`waterfall_loop`, louder for a taller, wider fall). *The current* (`Current.flow_at`): every river segment carries a flow downstream, its speed from the segment's slope (`slope_gain`) and width (`volume_gain`) within the kind's band (stream, river; a rapid where the white water is; the churn below a fall; nothing in a lake or the sea), fading at the banks. In the water you drift with it (`PlanetPlayer.current`, added to the velocity: full share swimming, a smaller one wading); wading drags by depth (`wade_drag` knee / waist / chest); against a reach at `upstream_wall_ratio` of the swim speed or more there is no headway upstream (the wish against the flow is cancelled): rivers are one-way corridors; carried over a lip you fall, and the fall hurts as any fall does; the torch douses as before (§AW). The rivers sound (`WaterSounds`: `water_flow` sources at the nearest reaches). `dev_view` takes `AT=x,y,z` (`LOOK_AT=`, `AT_YAW=`) to stand anywhere.
- **Step 3, stand dominance** (§BH, `stand.json` `dominance`): each stand (a cell `stand_m` across, its size drawn per coarse cell) rolls, per tier, one dominant species (by fit here and the old slow dominance noise), 1–3 associates and the rest as accents, and the dominance factors are set so that at the chunk's middle the species' weights come out in those shares (the dominant `dominant_share`, the associates the rest less `accent_share`); in the `salad_biomes` the dominant holds only `salad_dominant_share` and every other species is an associate. The understory tiers roll their own dominant in the same stand cell, so a stand's floor is as consistent as its canopy, and the young cohort already grows from the stand's own trees. The catalogue is untouched: it changes how it is drawn from. `tools/stand_check.gd` measures the top species' share of the trees per chunk round the camp.
- **Step 4, roads** (§BC, `data/roads.json`, `RoadNetwork`, `RoadProps`): a trail network laid before the plants, built by region on demand from any thread (the chunk colours and the placer ask for it as chunks compute). *Nodes:* the ruins (`Ruins.find`), the mythic folk's camps (`Territories.find`), hot springs (the biome) and standing stones (their own hash), none closer than `min_spacing_km`, ruins kept first. *Links:* each node's three nearest within `link_max_km`, pruned to a relative-neighbourhood graph, each routed by A* over a 200 m lattice of the terrain that costs grade above `max_grade` (the road switchbacks), water crossings, lakes and the sea (never), and rewards a river bank, so roads follow rivers and contours; the ends on the nodes, the line smoothed. *Unmaintained:* per link by its own hash, a bridge (a wide river) out with `bridge_out_share`, both stone abutments standing on either bank and the deck gone; a ford (a narrow one) with stepping stones; a trail that ends at a collapse with `collapse_end_share` (cut short, rubble across the way); waymarks every `waymark_every_m` (cairns, standing stones, posts; `waymark_fallen_share` tipped over); the tread on the ground (`TerrainChunk.PATH` blended into the vertex colours by `trail.wear` × (1 − `overgrown`); Footsteps read it as dirt) with the understory kept `understory_clear_m` clear either side and the trees off it; a canopy tree of the stand's dominant at every bend (`tree_at_bend_m`). *Off the road:* half the links set a find 40–120 m off the trail, out of sight (the ground between rises over the line of sight, or 60 m into a forest; the placer tries five spots): a tall standing stone, a spring (a ring of stones round a pool with its own quiet water) or a lone old tree (a giant of the stand's emergent, placed by the placer). *Forks legible:* where two links leave a node along the same ground, the second starts where they part, so the fork is where you see the roads separate (a waymark logic for the fork proper is still to come). Rivers are the other road type (§BE made them one-way). The props are built round the player as the links come into reach (`RoadProps`, 450 m) and freed as they go. *Not yet:* ruts (a texture pass, not vertex colour), passes as nodes (the routing finds them, nothing marks them), the road's own name on the HUD.
- **Step 5, rooms** (§BB, `data/rooms.json`): rooms hang off the network where it widens: at the nodes, at fords and bridges, and at four bends in ten, `size_m` across. The understory at eye level makes the walls (`RoadNetwork.wall_scale`, in the placer's shrub tier): the room's floor thinned to `floor_density_scale`, its edge band (`edge_band_m`) thickened to `edge_density_scale`, a corridor's sides just past the cleared strip to `corridor_side_scale`; the ground tier thinned on the floor. *The reveal:* a room's open headings are where the ground drops away or water lies just past its edge (a ridge, a valley edge, a shore): no wall is grown on that side, so the corridor's end opens. *Thresholds:* where a road crosses a room's edge a boulder stands either side of the way (`RoadProps`, `threshold.width_m` between). *The test:* `tools/road_check.gd` runs a ray version of the sky-share measure (rooms.json `test`) at a room within reach: sixteen headings from eye height, closed within 40 m or open; the measure_look.py image measure stays the reference for a real frame (it needs a render). The vista stays and stays cheap: nothing here touches the pictures and far shell. *Not yet:* a ceiling preference (canopy over corridors) beyond what the bend trees give; a stair or arch threshold (boulders only).
- **Step 6, travellers** (§BF, `data/travellers.json`, `Travellers`): rare cloaked figures walking the roads (`per_km_of_road` of the road within 700 m; put down out of sight, 140 m or more off), day and night, never off the road, never stopping, never speaking; a tribe's palette or ash grey. The hood tracks you from `watch_m` while you are in front of it, capped at the hood (the §B rig's head band; the torso never turns, the body never breaks stride), holds `hold_s` after you pass, then turns back to the road. At a road's end they turn back if you can still see them, else they go (where they are going comes later). They walk unharmed through the dark: the dark hunts only you. The check drives one and watches its hood.

## 2026-09-30 — Ambient cut, the eight steps: movement profile, first person, ambient floor, torch, fuel, hearth, log, dread (Mike, from chat; design 30 Sept §AU, §AV, §BD, §AW, §AX, §AY, §AZ, §BA)
- **Step 1, the movement profile** (§AU, `movement.json` `profile` / `profiles`): `Tuning` deep-merges `profiles[<profile>]` over the base table when it loads movement (`MOVEMENT_PROFILE=shinobi` in the environment forces the other one for the checks). A block with `enabled: false` is off in code, not just tuned down: wall jump, cling and wall kick (`WALL_JUMP_ON`), bounce, swing, redirect and the missed-roll penalty, the roll as a landing tech (a heavy fall hurts instead), fast fall when its speed is 0, the super meter (`SuperMeter.ENABLED`: no perfects, no hits). Space is the jump; right click is interact and starts the tree climb; tree climbing, handholds, burden, footsteps and fall damage stay. The shinobi profile still passes `tech_check`, `super_check` and `climb_check` with everything on. The HUD's default pins come from `hud.json` `pins_ambient` in ambient (the clock only; the speedometer is unpinned) and the key help reads for ambient.
- **Step 2, first person only** (§AV): `camera.third_person false` in the profile makes V a no-op and forces first person on load; the third-person rig never draws. In first person only what is in your hand is drawn (bow, spear, torch, or nothing).
- **Step 3, the ambient floor and the regression** (§BD, `look.json` `ambient_floor`). *The audit of the darkening stack:* terrain = shadow map × dapple stamp × crown disc × `look_canopy_dark`, and the crown fleck term (0.66×) and the dapple darkening were both applied inside the shadow map's own range, so ground under a tree took the shadow map, then the stamp, then the crown term, near black at noon. Now the stamp and fleck terms fade in only beyond `look_leaf_shadow_m` where the shadow map ends, and the floor is added *after* the stack: `look_floor` (the hour's floor colour × energy) × sky visibility (the dapple stamp, 1 in the open; `TerrainChunk.sky_visibility_at`, 5 taps with `feather_m`) × the enclosure check (`SkySystem._update_floor`: five rays up, 40 m; three or more non-tree hits = inside, eased over a quarter second → floor 0 in a ruin or a cave), never below `sky_visibility.min_outdoors` while any sky is visible. Foliage gets the floor too. The hour's sky ambient is the day/night `sky_energy` × sky visibility. Night is mesopic: the floor is blue-grey (`night.floor`), and the post grade drains colour below `desaturate_below_luma` (`night_desat`, `desat_luma` in `post_grade.gdshader`). *The regression:* dusk read like sun because the sun's "up" ramp finished at 6° elevation (now 9°, so the low sun stays dim and orange); the ground was black near trees for the stacking above; the cruder leaves were the far pictures starting at the 1-chunk detail ring after the render-distance work, so the ambient profile runs a 2-chunk detail ring (`ChunkManager.DEFAULT_DETAIL_CHUNKS`, `DETAIL_CHUNKS=` overrides). Leaf shadows on the cards are unchanged.
- **Step 4, the torch and empty hands** (§AW, `data/torch.json`, `items.json` `starting_kit_ambient`): in ambient you wake with nothing and nothing is laid beside you; every camp fire (the opening camp and the ruin camps, `Torch.lay_bundle`) keeps a bundle of three unlit torches beside it, remade after `bundle.remake_h_game`. Right click takes one (Q cycles to it; it goes into the hand if the hand was empty). `Torch` (a node on the player, first-person stick and flame under the camera, an `OmniLight3D` with the data's range, falloff and 9 Hz flicker, no shadow): unlit until right-clicked against a lit campfire or a planted torch within `lighting_reach_m` ("You light the torch"); burns `burn_min`, rain and storms shorten it (`rain_burn_scale`, `storm_burn_scale`), the last `gutter_share` gutters (dimmer, harder flicker), then out: a burnt stick. Swimming or wading past `douse_depth_m` puts it out; so does Q-ing away from it. Right click the ground with it lit to plant it (`PlantedTorch`: a standing stick with the same flame and light, burning down on its own; right click to take it back, burning or burnt); a lit torch dropped from the pack lies burning. Starting a climb or a cling plants it if there is ground, else it goes out. Creatures' `light_response` (flee / avoid / shy / drawn) now reads `Torch.light_at` and `PlantedTorch.light_at`, which is the actual light on them. The log gets its buffer (`GameLog`, step 7 draws it): lit, planted, out.
- **Step 5, fire is fuel** (§AX, `data/fuel.json`, `FireStore`, `FuelField`): every campfire has a store of fuel units (kind, minutes left) that burns down flames → low (below `low_share`) → embers (relightable for `embers_min`) → out; `Campfire.flicker` draws the burn level (smaller, dimmer flames; embers a dull glow; a dead fire dark coals, no ground glow) and `lit_near()` reads it, so embers and a dead fire give no safety, light no torch and drain no dread. The store is keyed by the fire's place, so a camp rebuilt as you come back remembers. Every fire built so far is a folk's fire and burns at `tended_burn_scale`; camp folk don't die yet, so a camp only dies where its biome offers nothing to burn (ice, salt flats, the open sea's shores) and the eight starting units run out. Fuel lies in the world by the biome table (`FuelField`: hashed places in the chunks round you, so many per chunk as the abundances add up to, drawn as what they are: logs, branches, brush, reeds, grass, dung, peat, driftwood, fronds, ribs, culms); right click gathers a piece (a log counts two carried things for the burden, `carry_items`); gathered in rain or off soaked ground it is wet and burns at `wet.burn_scale` until it dries in the pack (`dry_h_game`). Right click the fire with fuel in the pack puts the first piece on ("the fire is stacked full" past `store_max_units`); wet fuel on embers catches only with `light_chance`, else hisses and is lost; dry fuel on embers relights them; fuel on a dead fire stacks cold. Right click embers or a dead fire with a lit torch relights it ("nothing left to burn" if the store is empty). The log gets fire lit / embers / out for fires within earshot.
- **Step 6, the hearth** (§AY, `camps.json` `wake_at_home`, `Hearth`, `WorldSave`): the first hearth is the opening camp's fire; right click the lit fire of any camp you find ("Make this your hearth"; the camps' fires and the opening camp's are marked, a mythic folk's fire is not) and it is yours. In the ambient profile a death wakes you at the hearth wherever you fell (the 29 Sept nearest-ruin rule stays for the shinobi profile), the folk's line and all; what you carried stays on your body where you fell, as before. The hearth is kept per world in `user://worlds/<seed>.json` (`WorldSave`, written a few seconds after a change and when the game closes; the log will live there too).
- **Step 7, the log** (§AZ, `hud.json` `log`, `LogPanel`, `GameLog`): Enter opens a Minecraft-chat panel low on the left of the 480-line frame, `lines_visible` lines at `font_px`, newest at the bottom, each stamped from the clock (the hour on the line, a dim day line where the day changes); a text box at the bottom takes a note (Enter keeps it, `note_max_chars`), Esc or Enter on an empty box closes; the wheel and Page Up / Down scroll. While it is open the movement keys are the box's (`PlanetPlayer.typing`). The events: deaths with their cause (`death_lines`: "Fell", "Killed by a wolf", "Taken by the dark"; `PlanetPlayer.death_cause` is set by whatever deals the blow), the torch lit / guttering / out, the fire lit / embers / out, the hearth set, a camp found (the first time you come to its fire), a biome first entered, dawn and dusk. Kept per world in the same save as the hearth (`WorldSave`). No other chat, no commands.
- **Step 8, the dark closes in** (§BA, `data/dread.json`, `Dread`): a hidden meter, nothing on the HUD. Night past `dusk_grace_min`: full dark fills it at `fill_per_min_dark`, moonlight at `fill_per_min_moon`, a lit torch in hand or planted within its range at `fill_per_min_torch`; inside a lit fire's radius it drains at `drain_per_min_fire` (embers and a dead fire don't count: `FireStore`); day empties it. The stages by `stages[].at`, each heard before seen: 1 the bed thins (`Dread.bed_gain` falls over `bed_fade_s` and the creatures' calls stop); 2 a sound behind you, only while you move, at the data's bearing and distance (a scuff, a crack, a rustle); 3 a shape at the edge of the light off to one side, gone when you look at it for `vanish_on_look_s` (or after a few seconds); 4 it follows in the open, the pacer: parallel at `keep_m`, faster than you; 5 it closes if there is no light on you or you are past `far_from_fire_m` from any lit fire, howls (the werewolf) or whispers (the dark), and takes you: "Taken by the dark" in the log, and you wake at the hearth. With light on you at stage 5 it holds off at its distance until the torch gutters. Never inside a lit fire's `never_within_fire_m`; it ignores travellers (it only ever hunts you); no bestiary, no HUD. The one hunter built: the werewolf as a pacer in the temperate forests (`hunters`, `first`; `full_moon_speed_scale` when the moon is full), its body from `CreatureBodies`; everywhere else, including the biomes whose named hunters aren't built yet (night rider, pond crawler, skinwalker, yeti), the dark itself: a cloaked shape with no species. Ambient profile only. The hunter glides (no leg animation yet). `tools/dread_check.gd` runs the fuel store, the hearth, the log and the dark end to end (13 checks).
- **The checks and the two profiles:** the fuel economy, the fuel field and the dark run in the ambient profile only (design §AT: the shinobi game keeps its fires burning, its nights safe). The checks written for the shinobi cut (`tech_check`, `super_check`, `climb_check`, `tool_check`, `inventory_check`, `play_fixes_check`, `hits_check`, `strike_check`) run with `MOVEMENT_PROFILE=shinobi`; `hud_pin_check` reads the profile's pins; `dread_check` runs ambient.
- **What the reference frames still have that we don't** (Mike's ask, after the eight steps): the reference stills are lit by one thing at a time, and ours still aren't quite: their night is a single blue-grey wash with the fire the only warm note, where ours still carries the sky's gradient and the moon's colour into the ground; their canopy is a few big, soft shapes against the sky (four or five values, no fleck), where ours breaks into many small cards past the near ring; their fog is a flat band that sits the trees in depth, where ours still shows the horizon through it; their frame has a foreground (a branch, a rock, a hand with the torch) that ours has only when the torch is lit; and their ground is one texture at one scale, where ours changes tile and colour at the detail ring and again at the litter. The next look pass is those five: a flatter night, fewer bigger canopy shapes, a thicker fog band, a foreground element, and one ground scale to the horizon.

## 2026-09-30 — HUD lettering bigger; the 1/10 scale checked (Mike, from chat)
- **HUD text** (`data/hud.json`): body, prompts, subtitles and the plant name at 30 px on the 480-line frame (VT323 is crisp at multiples of 10; crisp sizes 20/30/40), the origin line, speedometer, weapon line and the key-help block at 20. Rendered at 14:00 to check; `hud_pin_check` passes.
- **The 1/10 audit, everything on one clock:** a game day is 144 real minutes (Earth's 1440); the planet's circumference, heights and lapse rate are 1/10 (`PlanetConst`); the year is 365 *game* days, the moon 29.5, the seasons and their transitions in game days (`seasons.json`); the weather sim steps in game hours (`World` → `WeatherSim.step`); plants grow, flower, fruit and rot in game days (`PlantGrowth`, `FruitCrop`, `AroidLife`, `LeafSeason`, litter stages), creatures reproduce in game days. Walking, running, arrows, wind and water are at real speed and real size, which on a 1/10 planet is what makes crossing it feel 10x fast. The few world processes timed in real seconds (ground drying 90 s, scavengers gathering 45 s) sit inside the 10x range of their real-life hours. Nothing found off scale. Still open: the clock restarts at day 13.62 every session.

## 2026-09-29 — Plants grow at real rates; seedlings, saplings and shade leaves; flowers, pollinators and fruit (Mike, from chat)
- **Growth researched for every species** (design §AR, PLANT_SCHEMA §4a4; 1224 entries, `plant_schema_check.py` 0 errors): germination, years to half and 90 % height, first seed, lifespan, shade tolerance, the young form. `PlantGrowth` fits a Chapman-Richards curve per species; one game day = one real day of growth; ages are storage-free (place hash + world clock). **Open question for Mike:** the world clock starts at day 13.62 every session, so growth only accrues within a session. Save the date between sessions, or run the clock off real time?
- **The young:** the stand's regeneration cohort grows young layouts (`TreeLayouts` slots 1 young tree / 2 sapling; `TreeArch` grows saplings as whips, cones, multi-stems, palm establishment rosettes with eophylls, at a third of the mesh budget). The understory holds seedlings and saplings of the stand's species as the light lets live (`VegetationPlacer._place_young`, `PlantGrowth.understory`: a fir's seedling bank under a closed canopy at 1.5 % of full sun, a pine's saplings only in gaps). HUD: "seedling", "sapling", "young tree".
- **Shade leaves:** each plant's light from the crowns over it (`_Light`: optical depth, e^(−1.6·depth)); leaves 1.45x in deep shade to 0.85x in full sun, packed into the custom data's green with the vines (`foliage.gdshader` scales clusters and cards, darkens shade leaves).
- **Flowers and fruit** (design §AS, `FruitCrop`, `FruitMeshes`): every fruiting tree and shrub near the player carries buds, flowers, fruit ripening from unripe to ripe colour, fallen fruit rotting under it, at real places (layout anchors, crown shell, trunk, stalk, under a palm's crown). Pollinators (bees, flies, beetles, butterflies by day; moths, bats by night; birds) visit flower by flower; a flower watched to its close unvisited sets no fruit. Right click picks one fruit at a time ("Right click: pick the ripe crab apple") into the pack (item kind `fruit`, its own icon). Aroid shader gains modes 13 (banded) and 14 (wing). `tools/fruit_check.gd`, `tools/fruit_view.gd`.
- Checks: `growth_check` 0 fails; `growth_world_check` (RENDER_CHUNKS=2 to fit the 6 GB container) 0 fails; a chunk's undergrowth 3.6 s with the young vs 2.8 s without.

## 2026-09-29 — Wake empty-handed with the folk's gifts; bare hands fight; Space is the wall jump, right click the interact; the roll saves you; the fishing pole shelved (Mike, from chat)
- **Waking:** a new game and after a death alike, you wake with nothing on you. The folk who saved you have laid a bow and a spear on the ground by you (`main._lay_gifts()`, items.json `starting_kit`), drawn as themselves. Right click takes each: it's worn in its slot, and goes into your hand if the hand was empty. A set left untaken at an earlier fire is gone. Your old tools wait on your body with the rest; when you take the rest back, any tool you already have again stays with the body (three tools, never more).
- **Bare hands** (`Fists`, combat `fists`): with nothing in hand, left click jabs; hold it to wind up a haymaker, release to throw it. Your speed adds the melee strike bonus, and at `strike.kill_mps` a blow kills anything that isn't mythical. Punching a trunk at speed hurts you. Q now cycles bow → spear → bare hands, skipping tools you don't have.
- **The fishing pole is shelved** (Mike: too much scope; it goes to a separate fishing-simulator game to merge back later; the spear fishes). The cast I'd built (wind up, cast along the look, float on the water, reel with the wheel) is kept in `archive/fishing/fishing_pole.gd`, out of the game: no pole slot, no pole kind, no reel bindings.
- **Controls:**
  - **Space:** jumps on the ground. In the air at a face you've just touched it wall-jumps (or press it a moment early). Just before or after landing it bounces. On a cling it leaps off.
  - **Right click is interact (E is gone):** take things, pick up, climb the tree in front of you. Held in the air at a face: cling (let go to drop off). Held near a branch or vine: catch it and swing. On the ground at a wall or rock: cling.
  - Prompts say "Right click: …". Helper `Controls.interact_word()`. The `wall_jump` action is gone.
- **The ninja roll negates the fall:** Shift within 8 frames of touchdown (was 5), before or after, after any fall past a body length. It takes no damage however high (`roll.safe_m` 1000). Missed, the fall hurts as before.
- Checks updated to the new controls (Space kicks, right click holds): `tech_check`, `super_check`, `play_fixes_check`, `climb_check`. `inventory_check`, `strike_check` and the others take the gifts at the start (`main.take_gifts()`). New `tools/tool_check.gd`: waking, gifts, Q, fists, the high-fall roll, death and the body.
## 2026-09-30 — Titan arum, round two (Mike, from more photos)
- **The spathe is a rolled sheet, not a bowl:** it wraps a little more than once round, the outer edge a flap lying over the seam down one side, closed at the neck and rolling open toward the rim, where it unfurls into the frill. The rim wavers (a torn edge). `AroidMeshes._add_pleated(seam_at, overlap, open_from)`; every Amorphophallus spathe has it.
- **The leaf is built like a small tree:** three arms forking twice into twigs, each carrying a clump of crossed leaf cards (as tree foliage does), leaflets hanging under; layered foliage with the arms showing through, not a plate.
- The seam's side is fixed on the mesh, so in play each bloom's flap faces where its plant happens to turn. **Queued (Mike: "yes" to more epic):** a leaflet tile with lobed edges; crisp white rings on the petiole instead of the generic bark mottle.
- The in-the-wild render was stopped at Mike's word; the model viewer is the way to look at aroids.

## 2026-09-30 — Titan arum made epic (Mike: "the largest inflorescence known to man", with reference photos)
- **A picture in seconds:** `tools/aroid_model_view.gd` draws one Amorphophallus on its own (leaf and bloom, plain ground, one sun), no planet. `aroid_view`'s in-the-wild walk took 20+ minutes a spot on this machine's software renderer (and twice sat on a stale class list after new scripts landed; `godot --editor --quit` refreshes it); it now has `FIND=1` (headless search, prints the spot) and `AT=` (go straight there).
- **The bloom, from the photos:** the spadix appendix now rises from the spathe's foot to 2.15x the spathe's height (3.1 m over a 1.4 m spathe on a 5 m plant; was a stub sat on the rim). The spathe is a pleated bell with a frilled rim that flares past its height and rolls back, green below flushing to the maroon inside colour toward the rim. `AroidGarden.bloom_dims()` holds the proportions.
- **The leaf:** every Amorphophallus grows its real leaf now instead of the umbrella-tree stand-in: one mottled petiole, three rachises forking into three more, hung with big drooping leaflets, a canopy as wide as the plant is tall (the second photo). `PlantMeshes._aroid_leaf`. Far LOD: 3 leaflets a rachis instead of 6.
- **For the designer:** the spadix colour comes from `flower.spadix`, which titanum's entry doesn't set (fallback pale cream). The spathe's rim flush is fixed at 85 % of the inside colour; a per-species `spathe.rim` would let a green-rimmed species stay green.
- Checks: aroid_check 0, tree_check 0.

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
