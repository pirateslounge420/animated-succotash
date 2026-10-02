# The look, from Mike's twenty favourites (1 Oct 2026)

On 1 Oct, Mike picked twenty favourite frames while honing the look:
`docs/references/batch4/` (see `contact_sheet.jpg`). This doc is what they show, measured.
It's the reference the look is judged against. Status: **findings**. The look pass of
1 Oct (PROGRESS, top entry) already built most of the rules. What's left is listed under
"Built and still open", and the calls only Mike can make are under "Open calls". Where this
doc and a LOCKED section disagree, the locked section stands until Mike settles the call.

Measured with `tools/look/measure_look.py`'s own formulas
(`docs/references/batch4/measurements.json`). Compare any frame with
`python3 tools/look/measure_look.py --fav --day frame.png` (or `--night`).

---

## The eye test (for Mike, in the game)

Ten yes/no checks. Each one is a rule below; a "no" names what to tune.

1. **Sky (R4):** overhead, is the day sky nearly pure cobalt, lighter toward the horizon,
   with soft off-white painted clouds?
2. **Shade (R3):** out of the sun, does stuff go navy (blue scenes) or dark olive (green
   scenes)? Never grey?
3. **Distance (R5):** do far hills get lighter and bluer, not darker?
4. **Water (R6):** is water the brightest, most saturated thing in view (electric blue
   with cyan glints, still ponds a darker navy)?
5. **Warm (R7):** at night, is the fire (or a candle or torch) the only warm thing, and
   does it pop?
6. **Pixels (R9):** are surfaces chunky while the edges of trunks and stones against the
   sky stay clean?
7. **Night (R4, R5):** is night one blue world, with misty gaps between trees glowing
   brighter than the trunks?
8. **Vivid but dark (R1):** does it feel dark and moody *and* saturated at once, rather
   than bright, or dark and grey?
9. **The shot (R10):** walking a road toward a ruin or camp, does it frame like #1, #2,
   #5 or #16? Path straight in, walls of trees or slopes on both sides, the landmark
   against the sky.
10. **Doorways (R10):** do door and arch openings read as voids, glowing blue or pitch
    black?

**Before judging any of this on the Mac:** the look pass's log says nothing about the grey
leaves (step 0 of that prompt). If leaves or other surfaces still render flat grey in the
real game, fix that first, because no colour can be judged over it.

---

## What these frames are, and aren't

- **They're AI videos imitating early-2000s 3D** (@ozavry_ tags them #aivisuals). They're
  more saturated and bluer than any real console was. That's why the grade, the sky and the
  water carry most of the look, not the geometry.
- **Not PS1.** No vertex jitter, no affine texture warping (floors and cobbles are
  perspective-correct), and mid-poly shapes: round domes, gnarled leaning trunks. A
  "PS1 / King's Field" reading (an outside suggestion, 1 Oct) was set aside for this
  reason. It also contradicts the era lock (1999–2004) and Mike's note that N64-era
  shapes are too blocky.
- **Big texels, clean edges.** Zoomed 3× (`findings_card.png`), the silhouettes against
  the sky are smooth: the chapel roof, the castle towers, the dolmen, the rotunda's dome.
  The blockiness is on the surfaces: the canal creature's face is 6–8 texels across, and
  a trunk 15–20. That's roughly **10–27 texels a metre**. Minecraft is 16, which is almost
  literally Mike's "Minecraft, except not in boxes" (§BU). The look pass set 16 a metre
  (`retro.tile_px` 64 over `tile_m` 4; leaves 32 over 2).

---

## The rules

Each rule comes with the frames that show it (batch4 numbers) and the numbers measured
from them.

**R1. Dark but saturated: vivid comes from saturation, not brightness.**
Day frames: mean luma 0.18–0.37, median **0.21**, at saturation median **0.68**. Night:
luma median **0.17**, saturation **0.80**. A pure-blue sky (#0000C4) has less luminance
than plain mid-grey, so a frame can be dark and vivid at once.

**R2. Blue owns the frame.** These are the shares of saturated pixels by hue (medians).
By day: blue 35 %, green 37 %, warm 9 %. At night: **blue 84 %**, green 2 %, warm 0 %. Night
is one colour, with the warm accent as the exception.

**R3. Shade takes the scene's colour, never grey.**
- Blue scenes: deep shade **#020A39**, shade **#06186C** (#11, #16).
- Green scenes: dark olive, e.g. #0F130B and #0A1009 (#6, #3).
- By the fire: brown, #130E0C (#8).
- At night the darkest 5 % range from black under a closed crown (#13, luma 0.000) to a
  lifted navy under a lit sky (#9, #16, luma ~0.08). Median 0.019.

**R4. The sky.**
- Day: the top is nearly pure blue, **#0000C4** (#1, #2, #4). The horizon is **#2350F0**.
- Clouds are painted and cool off-white, **#A8B4E6**: puffy in #1 and #4, streaky in #2,
  #3 and #5.
- Night is a darker, bluer day: the rotunda's night sky (#9) measures #0000DB, the same
  cobalt as the day skies, just with stars added. Deep night is **#050938** (#18). The
  range reaches indigo and violet (#15 measures #15134B).
- Stars are dense and small, multicoloured in #18. Glowing motes show in #13, and the
  moon blooms in #14.

**R5. Distance gets lighter and bluer, never darker.**
- By day the far mountains are **#4F98EF**, against grass at **#1F4C14** in the same
  frame (#2). Pale cyan mountains show in #3 and #4.
- At night, the gap between the trees is brighter than the trunks framing it:
  **1.2× in #11, 1.5× in #12**. Mist glows a mid-blue, about **#153695**.

**R6. Water is the brightest thing.**
- Moving or magic water: a body of about **#0819F2** (#11) with mottled cyan glints of
  **#74F9FD** (#10).
- Calm ponds are dark navy, **#061462** (#4).
- Falls are white-blue streaks with a foam line, and they bloom (#7, #14).
- Water is often the path itself (#6, #10, #11, #12).

**R7. One warm accent, and when it's there it's alone.**
- Wheat **#C0722F** (#1). Fire **#E6552A** with a core of **#FEFC54** (#8). Candles (#16,
  #19, #20). A lit path, about #C39151 (#13). A golden landmark under a navy sky (#18).
- It's always the complement of the blue around it.

**R8. Glow only on what emits.** Water glints, falls, candles and fire, the moon,
doorway voids, glowing flowers (#17) and eyes (#19, #20). Lit surfaces never bloom.

**R9. Big texels, clean edges, detail in the albedo.**
- Textures are high-contrast inside: dark mortar and cracks, bright flecks (#3's stone,
  #5's bark).
- No normal maps, no specular sheen. Shading is simple; the texture carries the detail.
- A thin dark rim shows where stone meets sky (#1, #3, #5). That may be the clips' own
  sharpening; see open call 5.

**R10. The shot: a path to a landmark against the sky.**
- In 14 of the 18 landscapes, a path or water leads from the eye straight to a landmark.
  Three of the rest (#11–#13) are corridors into glowing distance; #8 is folk at work.
- The rules for building this into the world are in the next section.

---

## Composition: the rules for the landmark and road pass

These are for placing ruins, camps and stones along `RoadNetwork` (§BC, §BX, §BY), so that
walking in produces the favourites' shot. The numbers are first guesses; tune them by
walking.

1. **A straight final approach.** The last 60–100 m of a road into a landmark runs
   straight at it, aimed at its front (a door, an arch, the gap of a gate). The walker
   then sees it on the centre line. (#1, #2, #5, #16, #18)
2. **On a rise.** Put landmarks on local highs (a knoll, a ridge end, the head of a
   valley) so the top breaks the skyline from the approach. (#1, #3, #9, #18)
3. **Walls on both sides.** Thicken trees along that last stretch's edges, or let a
   cutting, a valley or a cliff do it. Keep the tread clear. (#5, #11, #2's mountains,
   #3's cliff)
4. **An apron in front.** A clearing, a ring of paving, steps or a field before the
   landmark. (#2's paving ring, #1's wheat, #9 and #18's steps)
5. **Openings are voids.** Doorways and arch openings are pitch black or glowing blue,
   never lit like the walls; arches show sky through them. (#1, #10, #16, #9) This fits
   the look pass's cavity darkening at jambs; the glowing version is new.
6. **Water as a path.** Where a river runs toward a landmark (a fall, a bridge, a
   doorway), the bank trail follows the river. (#6, #10)
7. **The distance beyond glows.** From the approach, what lies past the landmark should be
   lighter (haze, mist, sky), not darker. (R5)
8. **Eye and lens:** `retro.eye_m` 1.4 and `fov_deg` 78 suit these frames. The path fills
   the bottom third and the landmark sits in the upper middle.

---

## Measured against the current targets (`look.json retro.targets`)

The favourites are given as min / median / max. "Last game frame" is the tuned 14:00 and
02:00 frames from the dev spot, logged on 1 Oct *before* the look pass.

| | Current day band | Favourites, day (8) | Current night band | Favourites, night (10) |
|---|---|---|---|---|
| Mean luma | 0.26–0.36 | 0.18 / **0.21** / 0.37 | 0.15–0.25 | 0.13 / **0.17** / 0.29 |
| Mean saturation | 0.58–0.70 | 0.60 / **0.68** / 0.75 | 0.67–0.80 | 0.64 / **0.80** / 0.87 |
| Texel detail | 0.014+ | 0.014 / 0.017 / 0.023 | 0.011+ | 0.009 / 0.019 / 0.030 |
| Darkest 5 % luma | 0.05–0.10 | 0.036 / 0.054 / 0.079 | 0.015–0.035 | 0.000 / 0.019 / 0.081 |
| Darkest 5 % blue/red | ≥ 2 | 0.8 / 12 / 129 | ≥ 2 | 0.2 / 9.7 / 129 |
| Blue / green / warm share | — | 0.35 / 0.37 / 0.09 | — | 0.84 / 0.02 / 0.00 |
| Last game frame | 0.29 luma, 0.68 sat | | 0.16 luma, 0.87 sat | |

What the table says:
- **Day brightness.** The favourites are darker than the day band: 7 of 8 are under its
  0.26 floor. The last game day (0.29) is brighter than 7 of 8 favourites. This is open
  call 1.
- **Night saturation.** 5 of the 10 night favourites are above the band's 0.80, up to
  0.87. The game's night (0.87) sits at the favourites' top. The look pass left "grey the
  night palette a step" as Mike's call, and the favourites don't ask for it (open call 2).
- **Olive darks are right.** By day, 4 of 8 favourites (#3, #5, #6, #8) have olive or
  brown darkest pixels (blue/red under 2). That's R3, and the grade's `olive_color` does
  it. The ≥ 2 test should apply to blue scenes only (open call 4).
- **Night darks vary.** From black under a closed crown to a lifted navy. The current band
  is the median, not the floor.
- **Texel detail.** Phone captures of video read 0.009–0.030. The internal 480-line
  frame reads higher by design (the dither and nearest tiles), so it stays a floor.

`measure_look.py` without `--fav` still checks only the current bands. Nothing in
`retro.targets` has changed.

---

## Built and still open

**Built by the 1 Oct look pass** (`grade`, `day`/`night`, `retro.colors`, `water`, `mist`,
`retro.fog`, `retro.tile_*`, `cavity`, `fire`):
- the Linear tonemap
- navy and olive shade, with oranges and golds protected from the grade
- the sky stops, re-derived so they land on R4's on-screen colours
- far hills and mist that glow at night
- self-lit water with cyan glints, and falls with mist cards
- 16-texel-a-metre tiles with hard darks and flecks, no specular
- contact shade at tree feet and ruin bases and jambs
- glow on HDR only
- the fire as the one warm light
- 480 lines kept

**Still open from the favourites:**
- The composition rules above (the landmark and road pass). This is the biggest gap: the
  colours can be right and the world still won't frame like the favourites.
- Doorways as glowing voids (composition rule 5). Black already comes free from the
  cavity darkening.
- Star field density and the moon's bloom (#14, #18) against the current star pano.
- The thin dark rim against the sky (R9). `retro.sharpen` is in the data, but nothing
  reads it (`post_grade.gdshader`: "No sharpening").
- Emissive eyes and eyeshine for folk and animals at night (#19, #20), when the
  character work comes back.
- The look pass's own audit list (glossy spring pools, stray default-specular materials,
  `far_terrain.gdshader` without `retro_tex`).

---

## Open calls for Mike

1. **Day brightness.** The favourites' days sit at luma ~0.21; §BU locked "~0.31" from the
   earlier frames. Should the day come down toward ~0.22, keeping sunlit green vivid and
   making the shade deeper? If yes, `retro.targets.day.mean_luma` becomes about
   0.18–0.30.
2. **Night saturation.** Should the night band run to ~0.88 (the favourites) and the night
   palette stay as it is, not greyed?
3. **Screen pixels vs texels.** §BU keeps the 480-line screen pixels on top of the tiles.
   The favourites' edges are clean. Now that the tiles are 16 a metre, compare `default`
   (480) and `half_hd` (540) with F11 against #1, #2 and #5. If 540 reads closer, that's
   the switch; if 480 still feels right, nothing changes.
4. **Olive darks.** Should the day gate stop flagging olive or brown darkest pixels in
   green and firelit scenes, keeping the blue/red test for blue scenes only?
5. **The sky rim.** Try a one-pixel sharpen on the internal frame for the dark rim where
   stone meets sky, or leave the edges plain?

---

## How Claude Code uses this

- **When Mike sends a frame,** run `measure_look.py --fav` on it. Name the nearest
  favourite and look at the two side by side. Report the two or three biggest
  differences in this doc's terms ("R5: the distance darkens; far hills read #2A3A50
  against #4F98EF"), not as raw numbers alone.
- **Don't take screenshots during a pass** (Mike's standing rule). He sends frames from
  the Mac.
- **Don't edit `retro.targets` or the locked §BU numbers** until Mike settles the open
  calls. `--fav` is the comparison until then.
- **Bring new reference frames in as `batch5`** with the same README table, and measure
  them into the batch's `measurements.json` with the same code
  (`measure_look.hue_shares` and the formulas in the main loop).
