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

## 0. Build order — shape first, textures layered over it

Every species' leaf is built in this order. **Structure comes from the taxonomy; texture
is layered on top of whatever structure that gives.** No texture ever changes the outline.

1. **Structure (from the real description):** `type` → `outline` + `aspect` + `lobes` →
   `base` + `apex` → `margin` (cut into the edge) → `compound` layout if any →
   `arrangement` on the twig → `canopy` form and gap. This gives the silhouette card.
2. **Texture layers (drawn onto that card, in order):**
   a. base green + `tint` (hue/sat/val, per species);
   b. `venation` lines (dark, thin, follow the outline's midrib/lobes);
   c. `texture` surface: matte / glossy / velvety / glaucous bloom / tomentose hair /
      succulent — a shading and grain pass, never geometry;
   d. `underside` paler backface for wind flips;
   e. seasonal overlay (`autumn` colour, browning, drop) from the season system;
   f. wear: spots, holes, nibbles — optional, from age and herbivory (Phase 7+).
3. **LOD strips layers from the bottom up** (f → e → d → c → b), never the structure.

So two species with the same outline (say, ovate-serrate) differ by their textures;
two species with the same texture (glossy dark green) differ by their outlines. The
player learns both.

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

## 1b. `bark` block (trunk and stem surface — drives the per-species bark tile)

```json
"bark": {
  "pattern":     "furrowed",
  "orientation": "vertical",
  "depth":       0.6,
  "scale_cm":    4,
  "color":       "#5A4A3A",
  "color_2":     "#8A5A3A",
  "lenticels":   "none",
  "confidence":  "documented"
}
```

### `pattern` (the mature trunk, as a flora describes it)
| value | look | examples |
|---|---|---|
| `smooth` | unbroken, faint mottling | beech, fig, magnolia, young trees, baobab |
| `fissured` | shallow narrow cracks | ash, elm, young oak, hornbeam |
| `furrowed` | deep ridges and valleys | mature oak, black locust, cottonwood, chestnut |
| `plated` | jigsaw / rectangular plates with cracks between | ponderosa pine, alligator juniper (diamond), persimmon (blocky) |
| `scaly` | small thin flakes, roughly shingled | spruce, fir, old cherry, araucaria |
| `flaky` | patches peel to a paler or brighter under-colour | plane/sycamore, eucalyptus, arbutus, guava, crape myrtle |
| `papery` | thin horizontal sheets curl off | birch, river birch, paperbark *Melaleuca* |
| `stringy` | long shredding fibrous strips | redwood, cypress, juniper, cedar, stringybark eucalypts |
| `ringed` | leaf-scar rings or nodes around the stem | palms, bamboo culms, tree ferns, banana pseudostem, cycads |
| `spiny` | spines, thorns or areoles on the stem | cacti, *Ceiba*, honey locust, rose, *Pandanus* prop roots |
| `warty` | raised corky bumps or big lenticels | hackberry, elder, cork oak (deep corky = `furrowed` depth 1) |
| `green_stem` | photosynthetic herbaceous stem | herbs, aroid petioles, grasses, cannabis, reeds |
| `none` | no stem surface to draw | mosses, lichens, fungi, algae, submerged plants |

### `orientation` — for `fissured` / `furrowed` / `plated` / `flaky`; `none` otherwise
`vertical` (oak, cottonwood) · `diamond` (crossing ridges: ash, alligator juniper, some pines)
· `horizontal` (cherry, birch lenticel bands; horizontal plates) · `none`

### `depth`
0–1: relief and contrast of the pattern — the darkness of the fissures / the brightness of
the peel. Beech 0.1, ash 0.4, oak 0.7, cork oak 1.0.

### `scale_cm`
Spacing of ridges, plates, rings or flakes on the real trunk, in cm (ponderosa plates
~10, oak furrows ~3–5, birch bands ~1, palm rings ~10–25, bamboo nodes ~20–40).

### `color`, `color_2`
Hex. `color` is the outer bark on the mature trunk in flat daylight (grey-brown
`#6E6458`, red-brown `#7A4A2E`, white `#E6E2D6`, green stem `#5C8A3C`…). `color_2` is
the secondary colour the pattern reveals: the inner bark in fissures (usually darker or
redder), the peel underside (often brighter: plane tree cream, eucalyptus orange, arbutus
red), the lenticel bands, the ring scars. `green_stem` species set `color_2` to the node
/ mottle colour (aroid petiole blotches).

### `lenticels`
`none` · `dots` (scattered pale specks: elder, hackberry) · `horizontal_bands` (dark
dashes in rows: birch, cherry, alder).

The stem tile is generated from this block (`tools/look/make_plant_tiles.py`, design
§AH); species without one fall back to their `bark_type` class with a per-species roll.

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

## 4a. `origin` (HUD)

```json
"origin": "Eastern North America"
```
Where the species comes from on Earth, 2-6 plain words, under ~40 characters: the
country or region a field guide would give ("Louisiana and the Gulf coast", "Andes of
Peru and Bolivia", "Worldwide (cosmopolitan)"). The HUD prints it under the binomial with
the common name when you're within reach of the plant (data/hud.json plant_name). Filled
28 Sept 2026 for every entry; a missing `origin` falls back to the first clause of the
research note (PlantSpecies.origin_from_source), which reads worse — fill it.

## 4a2. `silhouette` (the modeller's target)

```json
"silhouette": "flat-topped disc on bare limbs"
```
What the plant looks like from ~60 m, in ten words or fewer — the one thing the model
must hit at 64 px. Every entry has one (top level, or `appearance.silhouette` in the
older catalogues) since the archetype pass of 29 Sept 2026, when every entry's leaf,
canopy, bark, architecture and tint were re-checked against the real species.

## 4a3. `cycle` (a researched life cycle) and sports

The Amorphophallus carry a `cycle` block — dormancy, shoot and bud, bloom, fruit, tuber,
ploidy, hybrids, sports — read by AroidLife / AroidGarden; its vocabulary is in
`docs/design/AROID_LIFE.md` §1 and checked here (`check_cycle`). Every plant can be a
rare sport (`data/sports.json`, PlantGenetics): the rates by shape, the kinds and what's
documented per genus live there, not in the plant entries (a species' own documented
sports go in `cycle.sports` when it has a cycle).

## 4a4. `growth` (real growth rates) and `fruiting` (flowers and fruit)

Researched per species (design §AR; twelve research passes over silvics manuals, FEIS,
floras, extension pages and growers' data; `confidence` documented or estimated per
block). Real-life values: the game plays them on its clock, one game day per real day's
growth, which runs 10x faster than ours (PlantGrowth). Replaces the older template
`growth` (stages + final_size); stages are derived from these numbers in code
(PlantGrowth.stage_of), not stored. Fungi keep their fruiting-body stages; every
Amorphophallus has a block derived from its `cycle` (first bloom).

```json
"growth": {
  "life": "perennial",            // annual | biennial | perennial | monocarpic
  "season": "spring",             // annuals and biennials: when seed comes up (spring | rains | autumn | any)
  "germination_days": [7, 21],    // sowing (or the rains) to the seedling showing
  "height_years": [35, 90],       // years to half and to ~90 % of full height (or size), open-grown
  "trunk_years": 6,               // optional: years before a stem shows (palms, tree ferns, cycads)
  "culm_days": 60,                // optional, bamboos: days for a new culm to reach full height
  "first_seed_years": 25,         // first flowers / cones / spores
  "lifespan_years": [300, 500],   // typical, exceptional (the stem you see; clones in the note)
  "shade": "tolerant",            // the young plant: very_intolerant .. very_tolerant
  "juvenile": "cone",             // whip | cone | multi_stem | grass_stage | establishment | rosette | tuft |
                                  // shoot | sporeling | globe | sprig | vine | protocorm | mat | none
  "juvenile_leaves": "same",      // different: heteroblasty (eucalypts, wattles, junipers, palms' eophylls)
  "juvenile_note": "...",         // what the young plant looks like, for the mesh builders
  "confidence": "documented", "source": "..."
}
"fruiting": {                     // trees, shrubs, palms, cacti, climbers
  "flower_months": [3, 4], "hemisphere": "north",   // or south / equatorial; months may wrap (11 -> 4)
  "flower_days": 4, "flower_size_cm": 3.5, "flower_colour": "#f6e8ee",
  "flower_form": "cup",           // cup | star | bell | tube | pea | brush | ball | catkin | spike | panicle | cone | tiny
  "flower_position": "twigs",     // twigs | trunk (cauliflory) | crown | stalk | stem_tips
  "flowers_per_cluster": [4, 6],
  "pollinators": ["bee", "fly"],  // bee | bumblebee | stingless_bee | wasp | fig_wasp | fly | beetle | moth |
                                  // butterfly | bird | bat | mammal | wind | water | self
  "fruit_set": 0.15,              // share of flowers that ripen a fruit
  "fruit_kind": "pome",           // berry | drupe | pome | citrus | pod | capsule | nut | samara | cone | fig | syncarp | achene | pepo
  "fruit_shape": "round",         // round | ovoid | elongated | pod | coiled | winged | star | cone
  "fruit_size_cm": [3, 6], "unripe_colour": "#8aa848", "ripe_colour": "#b83a2a",
  "ripen_days": [120, 160],       // pollination to ripe
  "hang_days": [10, 40],          // ripe on the plant before it drops
  "drop": "falls",                // falls | splits | persists | shatters
  "rot_days": [14, 40],           // on the ground until gone
  "crop_per_tree": [50, 400], "edible": "yes",      // yes | cooked | no | toxic
  "confidence": "documented", "source": "..."
}
```

## 4a5. `desiccation` (resurrection plants — optional)

Design 1 Oct §CD. For species that dry out and come back as they do in life
(poikilohydric: the resurrection fern now; mosses, some lichens and Selaginella
lepidophylla are the same kind of organism and may take the block later). Read
against the live weather at the plant's place (`WeatherSim.local_weather`, the same
rain the camps' wildfire clock counts), per chunk, hour by hour.

```json
"desiccation": {
  "tolerant": true,
  "wet_rain_mm_h": 0.2,          // local rain at or above this wets the plant
  "curl_starts_game_h": 24,      // dry this long before the fronds begin to roll
  "dry_after_game_days": 3.0,    // fully rolled and brown by then
  "unfurl_starts_game_h": 1.0,   // after rain, the opening begins within this
  "green_after_game_h": 24,      // flat and green by this
  "humidity_slows": true,        // fog and high humidity stretch the drying
  "dry_curl": 0.85,              // 0 flat .. 1 rolled tight (the frond rolls toward its underside)
  "dry_color": "#8C7B63",        // the scaly underside's grey-brown
  "dry_underside_shows": true,
  "dormant_when_dry": true,      // no growth while dry
  "confidence": "documented",
  "source": "..."
}
```

## 4b. `soil` (spawn gate — co-equal with temperature and moisture)

```json
"soil": { "classes": ["alluvium", "clay_peat"], "drainage": "poor", "ph": "acid",
          "fertility_min": 0.4, "salinity": "none" }
```
- `classes`: allowed substrates from the terrain's soil map — `basalt`, `sand`, `alluvium`,
  `clay_peat`, `till`, `karst`, `sandstone`, `granite` (extend only when the geology pass
  does). A species outside its classes **does not spawn**.
- `drainage`: `poor` (waterlogged ok) · `moderate` · `sharp` (must drain).
- `ph`: `acid` · `neutral` · `alkaline` · `any`.
- `fertility_min`: 0–1, minimum organic content; `salinity`: `none` · `tolerant` · `needs`.

## 4c. Colour and pattern are per species (never one green)

Every species carries its own colour: `tint` (hue shift, saturation, value, underside,
autumn) on top of the palette green, so a forest is dozens of greens, greys and
blue-greens because the plants are. Pattern grammars (the Amorphophallus petiole
grammar in `data/plants/amorphophallus.json`: base hue, two-layer blotches + dots,
confluence up the stalk, surface, and the **lichen** archetype — pale ragged-rimmed
islands on a dark ground) are the same idea for stems: real descriptions in, a
per-plant roll within the species' ranges out. Kin, not twins.

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
3. Never change `genus`/`species`/climate bands — only add the new blocks (`leaf`, `bark`,
   `canopy`, `tint`, `photoperiod` where a species has one).
4. Work by file (`data/plants/*.json`) or by biome (`data/biomes/*.json`); one agent per
   file; never two agents on one file.
5. Keep it archetypal: if a species has variable leaves, describe the **typical adult**
   leaf.

## 8. `architecture` block (woody species — the leafless skeleton)

Trees and shrubs carry an `architecture` block so the trunk and branches are built from
the species' real branching program, not a smooth stick: the Hallé–Oldeman model,
habit, branch orders and angles, taper, sinuosity, fork height, buttresses, lean, live
crown ratio, self-pruning, dead limbs, root flare, branch spacing. Vocabulary, numbers
and a 40-genus table: `docs/design/TREE_ARCHITECTURE.md` §5. Herbs, grasses, mosses,
aroids, epiphytes, fungi and algae carry none. Validated by `tools/plant_schema_check.py`.
