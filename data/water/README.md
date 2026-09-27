# Water ripple data

`ripples.json` tunes the ripples on the water near the camera: how far
they reach, how fast rings spread and fade, how big a splash or a wake
is for a given mass and speed, how rain rings the water, and how the
rings are painted. Edit it; changes apply the next time you run the
game. Anything missing falls back to the defaults in
`scripts/water/ripple_sim.gd`.

| Field | Meaning |
|---|---|
| `enabled` | `false` turns the ripples off (the water keeps its static look). |
| `buffer_texels` | Size of the ripple buffer, texels a side (256). Its cost grows with the square. |
| `texel_m` | Meters per texel (0.25): the buffer covers `buffer_texels` × `texel_m` (64 m) of water round the camera. Coarser texels reach farther but make wider, blurrier rings. |
| `lead_m` | The buffer is centered this far ahead of the camera, where you're looking. |
| `wave_speed_mps` | How fast rings spread, m/s. |
| `damping_per_s` | How fast ripples die down (higher: they fade sooner). |
| `flatten_per_s2` | How firmly the surface settles back to flat (so nothing leaves a lasting dent). |
| `smoothing_per_s` | A little blur each second against grid noise; too much eats small rings. |
| `edge_texels` | Width of the soft border where rings leave the buffer instead of bouncing back. |
| `view_fade_m` | Ripples fade out between these two distances from the camera, into the static water. |
| `look.height_m` | The ripple height (m) the buffer is scaled to; the size thresholds below are in meters too. |
| `look.slope` | Ripple slope that counts as steep (for the lighter side facing the moon or sun). |
| `look.band_wavelength_m` | The rings' usual wavelength (m), which the painting is tuned to: every ring shows one light band (its crest) and one dark band (its trough). |
| `look.band_edge` | Where in a ring's swing the light band gives way to the dark one: 0 splits it evenly; above 0 leaves a thin strip of plain water between them. |
| `look.band_softness` | How soft the bands' edges are (0.1 crisp, 0.5 very soft). |
| `look.light_band`, `look.dark_band` | How far a light band moves toward the highlight blue (day highlight, night #7FB0FF), and how much a dark band deepens the blue (never to black). |
| `look.light_side` | How much lighter the side of each ring facing the key light (moon at night, sun by day) is painted. |
| `look.show_from_m`, `look.full_at_m` | Ripples smaller than `show_from_m` (m) aren't painted; from there the bands grow stronger until `full_at_m`. Lower both to make faint ripples (rain, a distant footstep) show more. |
| `look.calm` | How much the water's own mottling and sparkle calm under painted rings (0-1), so the bands read as bands. |
| `look.brush`, `look.brush_m` | Brushwork in the bands: how strongly the water texture's fine grain streaks each band lighter and darker (0 = flat bands; 1.2 = a crunchy painted grain, the ring's shape intact), and how many meters the grain repeats over (smaller is finer). |
| `look.foam`, `look.foam_from_m` | How pale a hard splash churns for a moment (0 = never), and how big (m) the ripples must be to churn. |
| `splash` | A single touch (foot, hand, arrow, anything dropped): its footprint radius is `radius_m_per_cuberoot_kg` × the cube root of its mass, between `radius_min_m` and `radius_max_m`; its push is `push_scale` × mass to the power `mass_exponent` × speed to the power `speed_exponent`, at most `push_max_mps` (speed counts for more than mass: an arrow at full draw, 55 m/s, rings the water about as clearly as a wading step, a falling leaf barely). |
| `wake` | A body moving through water: the same footprint rule with its own numbers; the push is `push_per_mps` × its speed × the cube root of (mass / 65 kg), at most `push_max_mps`, drawn as one continuous furrow along its path. |
| `rain.full_at_mm_h` | Rain rate (mm/h) that counts as full rain on the water. |
| `rain.drops_per_m2_s` | Drops ringing the water per square meter per second in full rain. Keep it low (~0.05): denser, the rings overlap into a blotchy pattern instead of reading as rings. |
| `rain.push_mps`, `rain.radius_m` | Each drop's push and footprint. |
| `rain.cell_m` | Drops land at random spots, at most one per cell this size a step (keeps them apart). |
| `contacts` | Masses (kg) of the things that touch water: `player_kg` (whole body: going in, swimming, the legs' wakes), `player_foot_kg` (each wading step), `player_hand_kg` (each swimming stroke, every `player_stroke_s` seconds), `arrow_kg`, `spear_kg` (the thrown spear; it floats where it lands in water); coming down faster than `player_drop_mps` (m/s, a jump or a fall) splashes with the whole body, slower (wading in from the bank) is just a step; creatures weigh `creature_kg_per_size_m3` × their size cubed (a 1.4 m deer: ~70 kg). Dropped items and falling leaves don't exist yet: when they do, each gets its mass here and calls `Ripples.splash()` where it meets the water. |
| `readers` | For other systems reading the ripples (fish, later): how many recent splashes they remember (`max_sources`) and for how long (`source_life_s`); `ring_gain` and `ring_speed` match their estimate to the simulation. |
