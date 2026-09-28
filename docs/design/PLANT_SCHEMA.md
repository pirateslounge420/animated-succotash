# Plant schema — botanical vocabulary for procedural plants

Locked 27 Sept 2026. This is the **fixed vocabulary** every plant entry uses. Data-fill
agents choose only from the allowed values listed here; the card builder reads only these
fields. Do not add values without adding them here first.

Goal: real taxonomic description in, **stylised archetype** out. A species must be
recognisable by silhouette or low-res pattern at **64 px**. Detail is for close range only;
the ragged silhouette never smooths into a blob at any distance.

Existing fields (`name`, `genus`, `species`, `shape`, `temp_c`, `moisture`, `altitude_m`,
`height_m`, `density`, `soil`, `color`, `accent`, `source`, and the special blocks `aroid`,
`cannabis`, `repro`, `genes`, `growth`) are unchanged. The new block is `leaf`, plus
`canopy`, `photoperiod` and `tint` at the top level.

---

## 1. `leaf` block

```json
"leaf": {
  "type":       "simple",
  "outline":    "ovate",
  "aspect":     2.2,
  "base":       "cuneate",
  "apex":       "acute",
  "margin":     "serrate",
  "venation":   "pinnate",
  "arrangement":"alternate",
  "size_cm":    [6, 12],
  "compound":   null,
  "texture":    "matte"
}
```

### `type`
| value | meaning |
|---|---|
| `simple` | one blade per petiole |
| `compound` | blade divided into leaflets — fill `compound` |
| `needle` | terete or nearly so, stiff (pines, spruces, junipers) |
| `scale` | tiny overlapping scales pressed to the twig (cypress, cedar, tamarisk) |
| `strap` | long broad undivided blade from a sheath (banana, palm frond segments, agave, grasses at scale) |
| `frond` | fern / cycad / tree-fern frond; drawn as a compound with `pinnate` |
| `none` | leafless or effectively so (cacti, some brooms) — card builder skips |

### `outline` — the widest-point grid (flat blades only)
Where the blade is widest. Aspect ratio is **not** a separate outline: the builder
stretches the card non-uniformly by `aspect`, so *ovate* at aspect 4 **is** lanceolate.

| value | widest point | note |
|---|---|---|
| `ovate` | below the middle | egg-shaped; stretched → lanceolate → linear |
| `elliptic` | at the middle | tapers both ends; stretched → oblong-lanceolate |
| `oblong` | at the middle, sides parallel | box-like |
| `obovate` | above the middle | reverse egg; stretched → oblanceolate; blunt tip → spatulate |
| `orbicular` | round | aspect ≈ 1 |
| `cordate` | heart: notched base, widest low | base oddity — its own card |
| `sagittate` | arrowhead: basal lobes pointing back | own card |
| `hastate` | spearhead: basal lobes flared out | own card |
| `reniform` | kidney: wider than long | own card |
| `peltate` | stalk joins in the middle of the blade (lily pad, nasturtium) | own card |
| `deltoid` | triangle, widest at a flat base | own card |
| `palmate_lobed` | hand-shaped lobes from one point (maple, sycamore, fig) | own card; set `lobes` |
| `pinnate_lobed` | lobes along a midrib (oak) | own card; set `lobes` |
| `linear` | very long and narrow, parallel sides (grasses, iris) | aspect ≥ 8; may use `strap` type instead |

`lobes`: integer, for `*_lobed` outlines only (3, 5, 7…).

### `aspect`
Length ÷ width of the blade, float. Typical: orbicular 1, ovate 1.5–2.5, lanceolate 3–5,
linear 8+. Use the midpoint of the species' real range.

### `base`
`cuneate` (wedge) · `rounded` · `truncate` (flat) · `cordate` (notched) · `oblique`
(asymmetric — elms, begonias) · `attenuate` (drawn out into the stalk)

### `apex`
`acute` · `acuminate` (drawn to a fine drip tip — rainforest) · `obtuse` · `rounded` ·
`emarginate` (notched) · `mucronate` (small spine tip) · `truncate`

### `margin`
Teeth distort under stretch, so margin is a **card family**, not a post-process.

| value | look |
|---|---|
| `entire` | smooth edge |
| `serrate` | forward-pointing saw teeth |
| `dentate` | outward-pointing teeth |
| `crenate` | rounded scallops |
| `undulate` | wavy edge, no teeth |
| `spinose` | spine-tipped teeth (holly, thistle) |
| `ciliate` | hair-fringed |
| `lobed` | deep sinuses — use with a `*_lobed` outline |

### `venation` (drawn as dark lines on the card)
`pinnate` (one midrib, side veins) · `palmate` (several from the base) · `parallel`
(monocots: grasses, palms, lilies) · `arcuate` (curved to the tip — dogwood, plantain) ·
`dichotomous` (forking — ginkgo) · `none` (needles, scales)

### `arrangement` (how leaves sit on the twig — controls card placement)
`alternate` · `opposite` · `whorled` · `basal` (rosette from the ground) · `fascicled`
(bundles — pine needles in 2s/3s/5s: set `fascicle`) · `distichous` (two flat ranks) ·
`spiral` (dense spiral — cycads, yuccas, agaves)

`fascicle`: integer, needles per bundle, for `fascicled` only.

### `size_cm`
`[min, max]` blade length in cm. Drives card scale relative to the plant.

### `compound` (only when `type` is `compound` or `frond`)
```json
"compound": { "form": "pinnate", "leaflets": [9, 17], "leaflet_outline": "elliptic",
              "leaflet_aspect": 3.0, "leaflet_margin": "entire" }
```
`form`: `pinnate` (leaflets along a rachis — ash, walnut, acacia) · `bipinnate` (twice —
mimosa, jacaranda) · `tripinnate` · `palmate` (leaflets from one point — horse chestnut,
lupin, cannabis) · `trifoliate` (three — clover, poison ivy) · `pedate` · `dissected`
(fern-like, many mm-scale segments — Amorphophallus fern-type).
Leaflet fields reuse the simple-leaf vocabulary above.

### `texture` (surface — shading hint, not geometry)
`matte` · `glossy` · `velvety` · `waxy_glaucous` (blue-grey bloom — eucalyptus, cabbage) ·
`hairy_tomentose` (felted underside) · `succulent`

---

## 2. `canopy` block (whole-plant form; forestry vocabulary)

```json
"canopy": { "form": "rounded", "gap": 0.35, "layering": "clumped", "droop": 0.1 }
```

### `form`
`columnar` · `conical` (spruce, young firs) · `pyramidal` · `rounded` · `spreading`
(oak, acacia flat-top) · `vase` (elm, zelkova) · `weeping` (willow) · `umbrella` (stone
pine, Amorphophallus crown) · `irregular` (gnarled, wind-shaped) · `fastigiate` (narrow
upright) · `layered` (pagoda dogwood, cedar plates) · `palmate_crown` (palms: fronds
from one point) · `rosette` · `tussock` · `mat` · `climbing` · `mound` (shrubs)

### `gap`
0–1: fraction of the canopy that is **see-through**. This is the anti-blob number.
Dense broadleaf 0.2; open acacia 0.5; birch 0.4; pine 0.35; palm 0.6. Never 0.

### `layering`
`clumped` (foliage in distinct clumps — most broadleaves), `even` (uniform — conifers),
`tiered` (visible horizontal layers), `sparse`.

### `droop`
0–1: how much leaf clusters hang. Willow 0.9, birch 0.4, oak 0.1, palm 0.5.

Existing `shape` (the engine enum: CONIFER, BROADLEAF, GNARLED, EMERGENT, UMBRELLA,
PALM, CYPRESS, MANGROVE, ROSETTE, SHRUB, TUSSOCK, GRASS, REED, FERN, TREE_FERN, CACTUS,
CUSHION, MOSS, LIANA, KNEES, BAMBOO…) **stays** as the structural class; `canopy.form`
refines how that class's foliage is built. Where they disagree, `shape` decides the
trunk/structure and `canopy` decides the foliage.

---

## 3. `tint`

```json
"tint": { "hue_shift": -6, "sat": 0.9, "val": 0.95, "underside": 0.15, "autumn": "#c9772b" }
```
- `hue_shift` degrees around the base green (−20 blue-green … +20 yellow-green).
- `sat`, `val` multipliers on the palette green.
- `underside` 0–1: how much paler the back of the card is (flips in wind).
- `autumn`: optional hex — the colour deciduous leaves turn in the autumn transition;
  omit for evergreens. `"drop": true` marks deciduous species (leaves fall in the
  winter transition; snags/logs and `flora.litter` receive them).

---

## 4. `photoperiod`

```json
"photoperiod": { "mode": "short_day", "threshold_h": 12.5, "response": "flower" }
```
- `mode`: `short_day` (triggers when daylight falls **below** threshold — cannabis,
  chrysanthemum, poinsettia, rice, soybean) · `long_day` (triggers when daylight rises
  **above** it — lettuce, spinach, wheat, many temperate grasses and herbs) · `neutral`
  (no day-length trigger — tomato, most tropicals, Amorphophallus).
- `threshold_h`: daylight hours (game-clock hours, 24 per day) at the trigger.
- `response`: `flower` · `bolt` · `bud_set` · `leaf_drop` · `dormancy`.
- Daylight hours come from the astronomy (tilt 23.5°, latitude, day-of-year), so latitude
  now shapes what a plant does and when. Elevation shortens the growing season via
  temperature (lapse rate) and `frost_days`.

---

## 5. LOD contract (for the card builder)

| range | what is drawn |
|---|---|
| near (< ~40 m) | full cards: outline, margin teeth, venation lines, underside flip, tint |
| mid | cards without venation; margin kept |
| far | fewer, larger cards **with the same ragged outline**; no interior detail |
| horizon | impostor billboard **baked from the far card cluster**, not a sphere |

The silhouette gap (`canopy.gap`) is preserved at every range.

---

## 6. Card budget

Outline × margin families give roughly **15–16 archetype cards**, generated
procedurally at load time from the parameters above and baked into one atlas:

- 3 stretchable outlines (ovate, elliptic/oblong, obovate) × 3 margin families
  (entire, toothed, lobed) = 9
- base/oddity outlines that stretching can't fake: cordate, sagittate/hastate, reniform,
  peltate, deltoid = 5
- needle, scale, strap = 3

Every species maps to one card + parameters. No hand-drawn leaves.

---

## 7. Data-fill rules (for the agents)

1. Fill **only** from the vocabularies above. Unknown → choose the closest and add
   `"leaf_confidence": "estimated"`; documented → `"documented"`.
2. Source is real taxonomy (floras, Kew POWO, regional botanical descriptions). Record the
   source phrase in `source` as the files already do.
3. Never change `genus`/`species`/climate bands — only add the new blocks.
4. Work by file (`data/plants/*.json`) or by biome (`data/biomes/*.json`); one agent per
   file; never two agents on one file.
5. Keep it archetypal: if a species has variable leaves, describe the **typical adult**
   leaf.
