# Special genera — implementation spec for the engine

Three genera the designer cares about most. Each has its own data grammar and its own
look; none is a generic "tree" or "bush". Data is complete and `--strict` valid in
`data/plants/{amorphophallus,trichocereus,cannabis}.json` (leaf/canopy/tint/photoperiod/soil,
`realm`, `needs`, and each genus's own block). This file says how to render and simulate
them. Design references: RECONCILIATION §E, §G, §AA, PLANT_SCHEMA §0, §4c.

All three depend on **Step 6.5** (direct catalogue loading + realm gate): until
`species_db` reads `data/plants/*.json`, none of them exists in the world.

---

## 1. Amorphophallus (246 species) — the petiole is the plant

**What it is.** A tuber. Each season it puts up **one leaf**: a single tall stalk (the
*petiole*) that ends in a **three-way split of winged rachises** carrying small leaflets —
an umbrella from a distance. Separately, when the tuber is mature enough, it puts up a
**single inflorescence** (spathe + spadix), usually before the leaf, rarely with it.
Heights: dwarf 5–30 cm, typical 0.5–1.5 m, giants (titanum, gigas, decus-silvae, hewittii)
3–6 m. Forest floor and gaps only (ground/shrub tier), never canopy.

**Rendering (new `aroid` shape, replacing the `umbrella` placeholder):**
1. **Petiole** — a tapered cylinder (or 6–8-sided prism, era-correct) from the ground to
   the split, slightly leaning, base 10–20 % thicker. Its **texture is the whole show**
   and is **generated per plant**, not per species, from `genus_grammar.petiole` + the
   species' `aroid.petiole` block, seeded by (species, world position):
   - base colour from `aroid.petiole.base` (species) within `base_hues`;
   - `pattern` ∈ mottled / spotted / streaked / warty / plain / **lichen** (frequencies in
     the grammar; the species block may fix it);
   - **two layers**: large elongate blotches of the marking colour, then a fine scatter of
     tiny dots of the opposite value; blotches **confluent in the lowest 10–20 %** and
     breaking into islands up the stalk (`base_zone`); *lichen* = pale ragged-rimmed
     islands on a dark ground (`lichen_note`);
   - `texture`: smooth / warty (bumps in the normal-free era way: darker dimples in the
     texture) / hairy (fine streaks).
   Bake to one 64×256 (or 128×512 for giants) card texture per plant instance, nearest
   filtered; the same tuber keeps its pattern every visit (seeded).
2. **Leaf crown** — three winged rachises at ~120°, each carrying leaflets from the
   `leaf.compound` block: dissection level 1 (5–6 large obovate leaflets), 2 (dozens of
   lanceolate), or 3 (fern-like hundreds) — cards per PLANT_SCHEMA; `canopy` is umbrella,
   gap 0.45, tiered. Leaflet colour from `tint`; some species have a reddish or violet
   leaflet margin (`tint.margin_tint`).
3. **Inflorescence** — when blooming: a spathe (a flared, ruffled cone; outside/inside
   colours from `aroid.spathe`) around a spadix (a tall dark club); for giants, taller
   than a person. Use a simple lathe mesh + one card texture. It **self-heats and stinks**:
   emit a pheromone/scent source into the wind field (radius from `genes.scent`) that
   draws carrion flies and beetles (Phase 7 creatures; until then, a sound cue: flies).
4. **Dormant** — nothing above ground (a bare patch; the tuber persists in data).
5. **LOD** — far: petiole as a single card with the pattern baked at low res + a flat
   umbrella silhouette; the giants read from 200 m.

**Simulation:**
- **Bloom is a tuber-maturity gate** (design §E): each tuber has `mass`; each good leaf
  season adds mass by light × soil fertility × moisture; past the species threshold it
  *may* bloom (probability by surplus); blooming spends mass. Rich alluvium → yearly;
  poor soil → skips. Replaces `repro.bloom.interval_years`.
- **Seasons:** `repro.dormant` dry / cold / none decides when the leaf dies back (uses
  the season system, Phase 5); `photoperiod` neutral.
- **Per-instance genes** (`genes`): pattern intensity, scent radius, allocation
  seed↔offset, size — rolled from the species ranges, inherited by tuber offsets.
- **Realm gate:** `realm` ∈ indomalaya / malesia / afrotropic / sino_subtropical /
  madagascar / australasia; `needs: dry_ground`.

**Dev check:** spawn 10 random Amorphophallus at the dev spot with a dev key; screenshot
the petioles side by side — no two the same, the lichen ones obvious, the giants tall.

---

## 2. Trichocereus (18 species) — Andean torch cacti

**What it is.** Columnar cacti of high, dry, rocky Andean slopes (1,500–3,600 m):
San Pedro (*pachanoi*), Peruvian torch (*peruvianus*), *bridgesii*, *macrogonus*,
*terscheckii* (a tree cactus to 10 m), *chalaensis* (prostrate). Leafless; ribs and
spines; glaucous blue-green to dark green; white night flowers on some.

**Rendering (extend the `CACTUS` shape into a columnar family):**
1. Each column is a lathe mesh with **N ribs** (species: 6–14 in the catalogue's
   `appearance`), a rounded top, height from `height_m`; clumping species spawn 2–6
   columns from one base (canopy `columnar`, gap by clump openness; `chalaensis` is
   `mound`, lying down).
2. **Areoles** along the rib crests as small dark dots, **spines** as short 2–4-card
   fans at each areole (short on pachanoi, long on peruvianus/bridgesii); at LOD mid the
   spines drop, at far the ribs become a shaded stripe texture on a single card.
3. **Colour** from `tint`: glaucous species get the blue-grey hue shift and low
   saturation in the texture (no gloss).
4. **Flowers** (optional, Phase 6+): a white funnel card at night on mature columns.

**Simulation:** `cannot_be_browsed` (creatures don't eat it), sharp drainage, `realm:
andes`, slow growth (`growth` block). Handholds: a column is **not** a handhold (no
climbing cacti) — mark it so in the tree-contact code.

**Dev check:** spawn one of each at the dev spot in a row, sorted by height.

---

## 3. Cannabis (64 landraces) — one species, many populations

**What it is.** One species; every landrace interbreeds. Broad-leaf mountain types
(Hindu Kush, Himalaya: short, dense, wide dark leaflets, often purpling in cold) vs
narrow-leaf equatorial types (Thai, Colombian, African: tall, open, thin light-green
leaflets). Annual, dioecious, wind-pollinated, **short-day flowering**: it flowers when
daylight drops below its threshold (`photoperiod.threshold_h`, 12.5–14.5 h by landrace),
so it flowers in **autumn at temperate latitudes** and near the equator flowers on its own
clock. A camp follower: it grows on disturbed ground near people.

**Rendering:** the generic card builder does it — `leaf` is a palmate compound of 5–11
serrate ovate leaflets (broad types 5–7 wide, narrow types 7–11 thin); `canopy` mound
(broad) or conical (narrow); `tint` per landrace; purple types turn purple in the cold
(`tint.autumn` #7a4a8a). Flowering plants get a **bud cluster** at the tips (a fuzzy card,
sticky-glinting on resinous types); males a loose pollen spray. Seed heads at the end.

**Simulation:**
- **Annual life cycle on the game clock** (`repro.lifespan annual`, `dormant seed`):
  germinate in spring (soil temperature), grow through summer, **flower when day length
  crosses the threshold** (from the astronomy, §F), seed, die back in the winter
  transition; the seed bank re-sprouts next spring.
- **Genes** (`genes`): leaf width, resin, fibre, scent, size, flower_trigger, purple —
  rolled per plant, **inherited** by seed from both parents (dioecious), so a camp's
  patch drifts over generations; `cannabis.uses` (fibre / seed / smoke) feed Phase 10.
- **Realm gate:** each landrace only in its native realm; `needs: dry_ground`.
- **Camp follower:** biased to spawn near camps and ruins (disturbed ground), on any
  realm-matching association.

**Dev check:** a broad-leaf and a narrow-leaf landrace side by side at the dev spot; then
run the clock past the autumn threshold and confirm the broad one flowers first.

---

## Order of work

1. Step 6.5 (catalogue loading + realm gate) — nothing shows without it.
2. Cannabis via the generic card builder (Step 7) — cheapest proof that the schema works
   on a compound leaf.
3. Trichocereus columnar family — small, self-contained lathe + spine cards.
4. Amorphophallus `aroid` shape — the petiole texture generator is the real work; do the
   generator first with a dev viewer that shows 10 petioles, then the crown, then the
   inflorescence, then the bloom gate (needs seasons, Phase 5, which is built).
