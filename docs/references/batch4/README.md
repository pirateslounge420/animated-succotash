# Reference batch 4: Mike's twenty favourites (1 Oct 2026)

These are the twenty frames Mike picked as his favourites while honing the look. They're
the reference the look is judged against now. What they show, measured, is in
`docs/design/LOOK_REFERENCE.md`, along with the eye test, the composition rules and the
open calls.

They're third-party clips from social media (eighteen by @ozavry_, who tags them
#aivisuals, and #18 and #19 by @morgath0). They're here for internal art direction only and
are never shipped or redistributed. Each file is the whole video frame with the phone's
and Instagram's UI cut away. The overlays drawn on the video itself (the poster's name,
the side icons) are left on.

- `contact_sheet.jpg`: all twenty with their five dominant colours.
- `findings_card.png`: the 3× zooms (clean edges against the sky, big texels on
  surfaces) and the colours measured from the frames.
- `measurements.json`: every frame measured with `tools/look/measure_look.py`'s own
  formulas, plus the day and night ranges. `measure_look.py --fav` reads it.

Four of these are also in `batch3`, cropped tighter: #2 = batch3 #3, #3 = batch3 #2,
#4 = batch3 #4 and #8 = batch3 #5.

| # | File | Band | What it shows | What it teaches (LOOK_REFERENCE rule) |
|---|---|---|---|---|
| 1 | `1_chapel_wheat_path.jpg` | day | A dirt path through golden wheat runs dead straight to a small stone chapel on the skyline, under a pure cobalt sky with small painted clouds. | The path-to-landmark shot (R10). One warm accent against the blue (R7). The door is a black void. |
| 2 | `2_stone_gate_meadow_circle.jpg` | day | A stone trilithon gate on a valley floor, a ring of paving in front, an orange dirt path leading through it, snowy mountains on both sides fading to pale blue. | A tribal landmark with an apron in front (R10). Mountains as corridor walls. Distance lighter and bluer (R5): far mountains #4F98EF over grass #1F4C14. |
| 3 | `3_cottage_on_hill_path.jpg` | day | A path winding up a grassy ridge to stone houses on top. Streaky cobalt sky, pale cyan mountains, a dark cliff framing the left. | The landmark on a rise breaking the skyline. A dark foreground frame. High-contrast stone texture (R9). Green-scene shade goes dark olive, not navy (R3). |
| 4 | `4_graveyard_pond_valley.jpg` | day | A still navy pond among crosses and headstones in a pine valley, puffy clouds, misty blue mountains, grass blades close to the eye. | Calm water is dark navy, not electric (R6). Grass blades near, the tile far. Haze on the far slopes. |
| 5 | `5_castle_forest_path.jpg` | day | A forest path between tall pines to a castle gate. Red-brown trunks with chunky texels, small blue puddles. | Trees as the corridor's walls (R10). Big texels on trunks, clean edges against the sky (findings card). |
| 6 | `6_jungle_canal_bridge_troll.jpg` | day | A stone-walled canal through saturated jungle, a moss-green creature in blue water, a stone bridge arch. | Texel size: the creature's face is a handful of texels across (R9). Saturated greens with olive shade (R3). |
| 7 | `7_waterfall_grotto_pool.jpg` | day | A white-blue waterfall into an electric-blue pool in a mossy grotto under the canopy. | Water is the brightest thing even by day (R6). Fall streaks and foam. |
| 8 | `8_lizard_cook_campfire.jpg` | day | A lizard-folk cook in a green robe frying mushrooms over a fire on a stone hearth, a wooden cart behind. | The fire as the warm accent (R7). Chunky texels on cloth. Folk at work. |
| 9 | `9_moonlit_rotunda_on_hill.jpg` | night | A domed rotunda on a hill at the top of stone steps, under a pure cobalt starry sky. | Night as a darker, bluer day: the sky stays #0000DB with stars (R4). Sky through the arches. A landmark on a rise. |
| 10 | `10_river_to_stone_doorway.jpg` | night | A glowing river runs straight through a forest to a stone doorway with a waterfall inside. | Water as the path (R10). The doorway is a glowing void. Mottled cyan glints #74F9FD (R6). |
| 11 | `11_night_forest_river_corridor.jpg` | night | Gnarled trees arch over a glowing blue river. Cobalt sky and clouds through the canopy, blue haze far off. | The distance glows: the far gap is about 1.2× as bright as the trunks framing it (R5). A tree corridor. |
| 12 | `12_gnarled_forest_glowing_river.jpg` | night | A mossy path beside a glowing river under gnarled trees, blue haze between the trunks. | Same, about 1.5×. Moss keeps its local green under the blue light. |
| 13 | `13_giant_trees_lit_path_stream.jpg` | night | Giant moss-hung trees. A warm-lit cobble path on the left, a glowing stream and a small fall on the right, stars and glowing motes overhead. | Warm path against cold water, complementary (R7). Under a closed crown the darks go to black (R3). |
| 14 | `14_blue_falls_bridges_moon.jpg` | night | Ruined towers, stone arch bridges and three glowing falls into a crackling blue pool under a glowing blue moon. | Glowing water with white veins. The moon blooms (R8). Ruins as set pieces. |
| 15 | `15_frozen_falls_castle_bridge.jpg` | night | Violet-blue frozen falls in a canyon, a lamplit stone bridge to a dark castle against the stars. | Night's range reaches violet. Lamps as small warm points. |
| 16 | `16_gothic_church_candles.jpg` | night | A gothic stone church whose door is a glowing blue void, two candles flanking the stone path to it. | Door voids. Candles as the only warm light (R7). The path straight to the door (R10). |
| 17 | `17_blue_courtyard_glowing_flowers.jpg` | night | A cobbled courtyard with glowing blue flowers, pillars, stairs to an arched door, light shafts from above. | Glowing flora as night accents (R8). One blue world. |
| 18 | `18_desert_mission_star_sky.jpg` | night | A golden adobe mission on a dune with stone stairs, under a dense multicoloured star field. | A warm landmark against a deep navy sky (R7). Star-field density. |
| 19 | `19_goblin_blue_corridor.jpg` | character | A green goblin with glowing blue eyes holding a blue bowl in a blue stone corridor, one candle far behind. | Emissive eyes. One far warm light. Corridor depth. (Kept out of the bands.) |
| 20 | `20_pale_reader_blue_throne.jpg` | character | A pale figure with red eyes reading a gold book on a blue throne, candles and blue curtains. | Character readability: pale face, glowing eyes, a gold accent. (Kept out of the bands.) |
