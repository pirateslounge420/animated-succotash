# Tree architecture — building leafless skeletons that read as a species

Companion to `PLANT_SCHEMA.md` §2 (`canopy` block). That block says what the **foliage**
looks like; this document says what the **wood** underneath looks like when there are
no leaves — winter, deadwood, LOD silhouette. The goal is "not a smooth stick with a
blob": a trunk with taper and sweep, a branch system with the right angles, orders and
spacing, and a crown outline that changes with growing conditions. Vocabulary comes
from Hallé–Oldeman–Tomlinson (H-O-T) architectural models and forest mensuration.

---

## 1. Hallé–Oldeman–Tomlinson models (the branching *program*)

H-O-T describe a tree by four switches: **monopodial** (one leader keeps growing)
vs **sympodial** (leader dies/flowers, a lateral takes over); **orthotropic** (vertical,
spiral leaves) vs **plagiotropic** (horizontal, flattened leaves) axes; **rhythmic**
(flushes → whorls/tiers) vs **continuous** growth; and where flowers sit (terminal
flowers end an axis). Ten models cover nearly every tree the engine will draw.

| Model | Program | Typical genera | Winter silhouette |
|---|---|---|---|
| **Rauh** | Monopodial, all axes orthotropic, rhythmic → pseudo-whorls of branches that themselves re-branch like the trunk | *Pinus, Quercus, Acer, Fraxinus, Populus, Juglans, Hevea, Malus* | Candelabra: branches leave at 45–60°, curve up, tips all point skyward; whorled in pines, forking-dome in oaks once apical control fades |
| **Massart** | Monopodial orthotropic trunk, rhythmic, **tiers of plagiotropic branches** | *Abies, Picea, Sequoia, Taxodium, Cedrus, Araucaria, Ceiba, Bombax* | Pagoda/spire: clear vertical stem, flat horizontal plates at regular intervals; tips stay horizontal |
| **Attims** | Like Massart but **continuous** growth, so tiers are irregular | *Cupressus, Thuja, Juniperus, Rhizophora, Casuarina* | Dense narrow cone, branches at every height, no clean whorls |
| **Roux** | Monopodial continuous trunk, long-lived plagiotropic branches in two ranks | *Coffea, Bertholletia, Ilex, many understory trees* | Feathered: fishbone of flat branches, branches don't re-branch upward |
| **Aubréville** | Massart tiers but branch growth "by apposition" → branches step upward in modules | *Terminalia* (pagoda tree) | Exaggerated pagoda: horizontal plates with zig-zag branch tips |
| **Scarrone** | Monopodial rhythmic trunk; **branches sympodial**, orthotropic, ended by terminal flowers | *Aesculus, Liriodendron, Mangifera, Magnolia* | Stout, blunt, forking twigs; tiered when young, rounded when old ("crown metamorphosis") |
| **Leeuwenberg** | Fully sympodial, every module ends in a flower and forks into 2–3 equal daughters | *Plumeria, Dracaena, Manihot, Ricinus, Adansonia* (approximate) | Blunt candelabra: thick, equal forks, few orders, sausage-like segments |
| **Koriba** | Sympodial trunk made of initially equal modules, one becomes the "trunk" | *Ailanthus, Catalpa, Hura, Adansonia* | Loses its leader early; big forks low, crown spreads |
| **Troll** | All axes **plagiotropic**, secondarily straightening; trunk built from the bases of successive branches | *Fagus, Ulmus, Tilia, Carpinus, Celtis, Prunus, Tsuga, Annona* | Layered, drooping-tipped, slightly zig-zag trunk; the "fine twiggery" look of beech and elm |
| **Champagnat** | Orthotropic axes that bend under their own weight, then a sub-apical bud takes over | *Bougainvillea, Salix* (weeping forms), *Rubus* | Arching, weeping, cascading |
| **Mangenot** | Axis starts orthotropic, becomes plagiotropic (mixed) | *Strychnos*, some shrubs | Rambling |
| **Corner / Holttum** | Single unbranched stem (Corner: lateral flowers; Holttum: dies after terminal flowering) | *Cocos, Phoenix, Carica, Cyathea* (Corner); *Corypha* (Holttum) | Pole with a terminal tuft; no branch skeleton at all |
| **Schoute / Tomlinson** | Dichotomous forking of the trunk (Schoute) or basal suckering into a clump (Tomlinson) | *Hyphaene* (Schoute); *Musa, Phoenix dactylifera*, bamboo (Tomlinson) | Y-forked palm / dense clump of poles |

Rule of thumb for temperate scenes: conifers = Massart (spire) or Attims (cypress);
most broadleaves = Rauh (oak/maple/ash/poplar) or Troll (beech/elm/lime/hornbeam);
show-offs = Scarrone (horse chestnut, tulip tree), Koriba/Leeuwenberg (low forks, fat
segments). Tropics add Aubréville (Terminalia plates), Massart giants (Ceiba) and
Corner (palms, tree ferns).

---

## 2. Branching geometry (numbers to drive a generator)

**Leonardo's rule.** At each fork, parent cross-section ≈ sum of daughters:
`r_p^α = Σ r_d^α` with α = 2. Measured α in real trees runs **1.8–2.3** (Eloy's wind-load
derivation; ~10 species incl. maples and oaks), and the broader survey range across
species is 1.5–3.0 (ponderosa, piñon, balsa ≈ 2.0–2.5). Lower α → thin, wispy, many
twigs (cherry-blossom look); α = 3 (Murray) → fat, few, gradually tapering branches.
Use α as a species dial: **2.0 default, 1.8 for birch/willow, 2.3–2.5 for baobab,
Plumeria, Ceiba**. Note baobabs and most shrubs *don't* follow it — that's part of
their look.

**Branch angle (from vertical) by model.**
- Massart/Attims tiers: **80–100°** (fir, spruce, cedar plates; young sequoia), older
  spruce droop to 100–120° with up-turned tips.
- Rauh: **40–60°** at insertion (pine 50–70° in whorls; oak ~45°, then branches curve).
- Scarrone/Koriba/Leeuwenberg: **25–45°** stout forks.
- Troll: **60–80°**, tips drooping (beech), elm vase 20–35° at the main fork then arching.
- Champagnat/weeping: **30–50°** origin, tips reach 150–180°.
- Fastigiate cultivars (Lombardy poplar): 10–25°.
Real distributions are wide: ±15° scatter per branch and a downward drift with branch
age (old lower limbs sag) is what keeps a tree from looking combed.

**Orders.** Trees carry **4–9 visible branch orders** (trunk = order 0); mature shaded
crowns keep 3–5, young pioneers in full sun 7–15. For a skeleton mesh, **orders 1–3
carry the silhouette**; orders 4–6 are twig cards.

**Spacing.** Rhythmic growers put branches in **whorls/tiers one per year**: pine
0.3–1.0 m (site-dependent), fir/spruce 0.2–0.6 m, Araucaria/Ceiba 1–3 m. Continuous
growers (cypress, Roux) place branches every 5–20 cm with no pattern. Broadleaf
scaffold limbs on open-grown Rauh trees: 3–6 main limbs within 1–3 m of each other,
starting at the fork.

**Apical control → excurrent vs decurrent.** Strong apical control (Douglas-fir, most
conifers, Liriodendron when young) keeps one leader: **excurrent spire**. Weak control
(oak, hickory, maple, beech): laterals overtake the leader after a few seasons and the
cone becomes a **decurrent dome** — the leader is lost, the trunk "disappears" into
3–6 co-equal limbs.

**Self-pruning.** Shaded lower branches die and drop; forest-grown pines, poplars and
eucalypts shed cleanly (clear bole 50–70 % of height), oaks and beech hold dead stubs
for years. **Epicormic sprouts** — thin vertical shoots along the trunk and big limbs —
appear on stressed or suddenly-exposed oak, elm, lime, poplar, eucalypt, coast
redwood; draw 5–30 short verticals of 0.3–1.5 m on trunks with `dead_limbs` > 0.3 or
after fire.

---

## 3. Trunk realism

**Taper.** Metzger's "beam of uniform resistance" gives d ∝ h^1.5 (cubic paraboloid);
Gray's refinement d ∝ h^0.5 (quadratic paraboloid) fits plantation conifers with form
factors 0.6–0.8. Practical generator: butt is a **neiloid** (flare, first 1–2 m), the
bole a **paraboloid**, the top a **cone**. **Slenderness (height ÷ dbh)**: forest-grown
**70–100** (spindly; >80 is wind-risk, >100 means 60–100 % break in storms),
open-grown **30–50** (squat, heavy taper). Use `taper_exponent` = 1.5 forest,
2.0–2.5 open-grown, ~1.0 for palms (cylinder), 3+ for baobab/bottle trees.

**Sweep and lean.** Phototropism on forest edges → bowed stem + one-sided crown; slope
→ basal sweep ("pistol butt") of 5–15°; persistent wind → lean 5–20° and **flag trees**
(windward branches killed; crown only on the lee side). Sinuosity: elm/beech/olive
0.3–0.6, pine 0.1–0.3, plantation spruce ≤ 0.1, bristlecone/juniper 0.6–1.0.

**Forks.** Codominant stems (V-fork, included bark) are a product of open growth;
forest trees keep one stem. Open-grown broadleaf fork height ≈ **10–30 %** of tree
height (oak, maple, elm at 2–5 m); forest-grown **50–70 %**. Koriba/Leeuwenberg fork
at 5–15 %. Excurrent conifers and palms: null.

**Buttresses.** Tropical shallow-rooted giants: `low` 1–3 m (Ficus, Terminalia,
Pterocarpus), `high` 3–9 m (Ceiba: buttresses 12–15 m up the trunk on record
specimens, spreading 20 m). Also *Rhizophora* stilt roots (1–3 m) and *Taxodium* knees.
**Fluting** (hornbeam, ironwood, cypress) is the same thing in miniature.

**Branch collars, stubs, deadwood.** Every branch base swells (collar ≈ 1.2× branch
diameter); dead limbs leave stubs 0.1–0.5 m. Retained dead limbs as fraction of the
skeleton: plantation conifer 0.1, open oak 0.2–0.4, old-growth pine/eucalypt 0.3–0.5,
baobab 0.05. **Burls** on old oak, redwood, walnut, birch. **Root flare** at ground on
all trees older than ~20 yr: radius ≈ 1.5–2× dbh over the bottom 0.5 m.

---

## 4. Crown shape by growing conditions

- **Open-grown**: low fork, wide dome, live-crown ratio (LCR) **60–90 %**, heavy taper,
  branches to the ground on conifers.
- **Forest-grown**: tall clear bole, LCR **30–50 %** (dominants ~50 %, suppressed
  <30 %), narrow crown, few big limbs, one stem.
- **Edge tree**: bowed stem, crown on the light side only.
- **Krummholz / flag**: at treeline or coasts; ≤ 2.5 m tall, mats and flags, all
  branches lee-side, leader killed repeatedly → multiple short leaders.
- **Coppice / multi-stem**: 3–15 equal stems from one stool (hazel, willow, lime, some
  oaks, eucalypt lignotubers after fire).
- **Weeping**: Champagnat habit or cultivar; tips droop to ≥ 150°.
- **Umbrella / flat-top**: stone pine, savanna *Vachellia*: crown a shallow disc on
  bare limbs, LCR 20–35 %.

---

## 5. `architecture` block proposal

```json
"architecture": {
  "model": "rauh",             // rauh|massart|attims|roux|aubreville|scarrone|leeuwenberg|koriba|troll|champagnat|mangenot|corner|holttum|schoute|tomlinson
  "habit": "decurrent",        // excurrent|decurrent|multi_stem|columnar|palm|tree_fern|weeping|umbrella|candelabra|shrub
  "orders": 5,                 // visible branch orders incl. twigs (3-8)
  "branch_angle_deg": [40, 65],// from vertical, order-1 insertion
  "taper_exponent": 1.5,       // d ∝ h^k of remaining height; 1 = cylinder
  "sinuosity": 0.3,            // 0 straight … 1 gnarled
  "fork_height_frac": [0.1, 0.3], // null if no fork
  "buttress": "none",          // none|low (1-3 m)|high (3-9 m)
  "lean_max_deg": 10,
  "live_crown_ratio": [0.8, 0.4], // [open-grown, forest-grown]
  "self_prune": true,
  "dead_limbs": 0.25,          // fraction of skeleton kept as deadwood
  "root_flare": true,
  "spacing_m": 1.5             // order-1 branch spacing along trunk (whorl pitch)
}
```

`habit` overrides `canopy.form` for the wood; `canopy` still dresses it. `orders` and
`spacing_m` scale with tree height in the generator (values here are for a mature
20–30 m tree; shrubs at face value).

### Genus table

| Genus | model | habit | ord | angle° | taper | sinu | fork | buttr | lean | LCR o/f | prune | dead | flare | sp_m |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Quercus | rauh | decurrent | 6 | 40–70 | 2.0 | 0.5 | 0.10–0.30 | none | 10 | 0.8/0.4 | n | 0.35 | y | 1.5 |
| Fagus | troll | decurrent | 7 | 55–80 | 1.5 | 0.3 | 0.15–0.35 | none | 8 | 0.7/0.35 | n | 0.2 | y | 1.0 |
| Betula | rauh | excurrent→decurrent | 6 | 45–65 | 1.5 | 0.25 | 0.30–0.50 | none | 15 | 0.6/0.4 | y | 0.15 | n | 0.6 |
| Acer | rauh | decurrent | 6 | 35–60 | 1.8 | 0.3 | 0.10–0.30 | none | 8 | 0.8/0.4 | n | 0.2 | y | 1.2 |
| Fraxinus | rauh | decurrent | 4 | 30–55 | 1.6 | 0.2 | 0.20–0.40 | none | 6 | 0.7/0.4 | y | 0.2 | y | 1.5 |
| Ulmus | troll | decurrent (vase) | 6 | 20–40 | 1.7 | 0.4 | 0.15–0.30 | none | 8 | 0.7/0.4 | n | 0.3 | y | 1.0 |
| Populus | rauh | excurrent | 5 | 30–50 | 1.4 | 0.15 | 0.40–0.60 | none | 10 | 0.6/0.35 | y | 0.2 | n | 0.8 |
| Salix | champagnat | weeping / multi_stem | 6 | 30–50→170 | 1.8 | 0.6 | 0.05–0.20 | none | 20 | 0.9/0.5 | n | 0.3 | y | 0.5 |
| Platanus | rauh | decurrent | 5 | 35–60 | 1.8 | 0.4 | 0.15–0.35 | none | 10 | 0.8/0.4 | y | 0.15 | y | 1.5 |
| Pinus | rauh | excurrent→umbrella | 5 | 50–75 | 1.4 | 0.3 | null | none | 15 | 0.5/0.3 | y | 0.35 | y | 0.6 |
| Picea | massart | excurrent | 5 | 85–115 | 1.3 | 0.05 | null | none | 5 | 0.9/0.4 | y | 0.2 | y | 0.35 |
| Abies | massart | excurrent | 5 | 85–100 | 1.3 | 0.05 | null | none | 5 | 0.9/0.45 | y | 0.15 | y | 0.35 |
| Larix | massart | excurrent | 5 | 80–100 | 1.4 | 0.15 | null | none | 10 | 0.7/0.4 | y | 0.25 | y | 0.4 |
| Sequoia | massart | excurrent (columnar) | 5 | 85–100 | 1.2 | 0.05 | null | low | 3 | 0.6/0.3 | y | 0.2 | y | 0.5 |
| Taxodium | massart | excurrent | 5 | 80–100 | 1.3 | 0.1 | null | low (knees) | 5 | 0.7/0.4 | y | 0.2 | y | 0.5 |
| Juniperus | attims | columnar / shrub | 6 | 20–60 | 1.5 | 0.7 | 0.05–0.20 | none | 25 | 0.9/0.6 | n | 0.4 | n | 0.15 |
| Cupressus | attims | columnar | 6 | 15–45 | 1.4 | 0.2 | 0.05–0.30 | none | 10 | 0.9/0.5 | n | 0.15 | n | 0.15 |
| Araucaria | massart | excurrent (tiered) | 3 | 85–105 | 1.2 | 0.05 | null | none | 5 | 0.8/0.4 | y | 0.1 | y | 1.5 |
| Eucalyptus | rauh | decurrent | 5 | 30–55 | 1.5 | 0.35 | 0.30–0.60 | none | 12 | 0.6/0.3 | y | 0.4 | y | 2.0 |
| Acacia/Vachellia | troll/rauh | umbrella | 5 | 40–70 | 1.8 | 0.5 | 0.15–0.35 | none | 15 | 0.4/0.3 | y | 0.3 | y | 1.0 |
| Adansonia | leeuwenberg | candelabra | 3 | 25–45 | 3.0 | 0.3 | 0.40–0.70 | none | 5 | 0.4/0.4 | n | 0.05 | y | 3.0 |
| Ficus | rauh | decurrent (spreading) | 6 | 45–80 | 1.8 | 0.5 | 0.10–0.30 | high | 10 | 0.8/0.5 | n | 0.15 | y | 1.5 |
| Ceiba | massart | excurrent→umbrella | 4 | 80–100 | 1.5 | 0.1 | 0.60–0.80 | high | 5 | 0.4/0.3 | y | 0.15 | y | 2.5 |
| Rhizophora | attims | multi_stem (stilt) | 5 | 40–70 | 1.2 | 0.3 | 0.05–0.20 | low (stilts) | 15 | 0.9/0.7 | n | 0.2 | n | 0.3 |
| Cocos / palms | corner | palm | 0 | — | 1.0 | 0.2 | null | none | 25 | 0.15/0.15 | y | 0 | y | — |
| Cyathea | corner | tree_fern | 0 | — | 1.0 | 0.1 | null | none | 10 | 0.2/0.2 | n | 0.3 (skirt) | n | — |
| Musa | tomlinson | multi_stem | 0 | — | 1.0 | 0.05 | null | none | 10 | 0.5/0.5 | n | 0 | n | — |
| Magnolia | scarrone | decurrent | 5 | 40–65 | 1.7 | 0.3 | 0.10–0.30 | none | 8 | 0.8/0.5 | n | 0.1 | y | 0.8 |
| Liriodendron | scarrone | excurrent→decurrent | 5 | 35–55 | 1.4 | 0.1 | 0.40–0.60 | none | 5 | 0.6/0.35 | y | 0.15 | y | 1.2 |
| Juglans | rauh | decurrent | 4 | 35–60 | 1.8 | 0.3 | 0.15–0.35 | none | 8 | 0.7/0.4 | y | 0.2 | y | 1.5 |
| Prunus | troll | decurrent (vase) | 6 | 35–60 | 1.8 | 0.5 | 0.10–0.25 | none | 12 | 0.8/0.5 | n | 0.3 | n | 0.6 |
| Malus | rauh | decurrent (low) | 6 | 45–75 | 2.0 | 0.5 | 0.05–0.20 | none | 12 | 0.9/0.6 | n | 0.3 | n | 0.5 |
| Olea | troll | multi_stem / gnarled | 6 | 40–70 | 2.5 | 0.8 | 0.05–0.20 | none | 15 | 0.8/0.6 | n | 0.3 | y | 0.5 |
| Cedrus | massart | excurrent→layered | 5 | 80–100 | 1.5 | 0.2 | 0.20–0.40 (old) | none | 8 | 0.8/0.4 | y | 0.2 | y | 0.5 |
| Tsuga | troll | excurrent (drooping tip) | 6 | 70–95 | 1.3 | 0.1 | null | none | 8 | 0.8/0.45 | y | 0.2 | y | 0.3 |
| Thuja | attims | columnar | 6 | 20–50 | 1.4 | 0.15 | 0.05–0.30 | none | 8 | 0.9/0.6 | n | 0.15 | y | 0.15 |
| Casuarina | attims | excurrent (wispy) | 5 | 30–60 | 1.3 | 0.2 | 0.30–0.50 | none | 15 | 0.6/0.4 | y | 0.2 | n | 0.3 |
| Terminalia | aubreville | umbrella (pagoda) | 4 | 85–100 | 1.5 | 0.15 | null | low | 8 | 0.7/0.4 | y | 0.15 | y | 2.0 |
| Bombax | massart | excurrent→umbrella | 4 | 80–100 | 1.6 | 0.1 | 0.50–0.70 | low | 5 | 0.5/0.35 | y | 0.15 | y | 2.0 |
| Tilia | troll | decurrent | 6 | 40–65 | 1.6 | 0.3 | 0.15–0.35 | none | 8 | 0.8/0.4 | n | 0.2 (epicormic) | y | 1.0 |

Values are literature-anchored where numbers exist (α, LCR, slenderness, tier pitch,
buttress heights, fork behaviour) and judgement-filled elsewhere; treat every cell as
a **range centre** to jitter ±20 % per instance.

---

## Sources

- Architectural Models of Tropical Trees — Illustrated Key (LibreTexts) — https://bio.libretexts.org/Bookshelves/Evolutionary_Developmental_Biology/Key_to_the_Diversity_and_History_of_Life_(Shipunov)/04:_Geography_of_Life/4.02:_Architectural_Models_of_Tropical_Trees-_Illustrated_Key
- Pfisterer, Modern models in tree architecture as a tool for natural pruning (temperate genera → H-O-T models) — https://www.arboritecture.org/pdf/pfisterer/modern-models-in-tree-architecture-as-a-helpful-tool-for-natural-pruning-pfisterer-2000.pdf
- Hallé, Oldeman & Tomlinson, Tropical Trees and Forests: An Architectural Analysis — https://books.google.com/books/about/Tropical_Trees_and_Forests.html?id=xHTwAAAAMAAJ
- Characterization of architectural tree models using L-systems and Petri nets — https://algorithmicbotany.org/papers/catm.tree2000.pdf
- Leonardo's formula explains why trees don't splinter (Eloy, Science news) — https://www.science.org/content/article/leonardos-formula-explains-why-trees-dont-splinter
- Leonardo da Vinci's tree rule may be explained by wind (phys.org) — https://phys.org/news/2012-01-leonardo-da-vinci-tree.html
- Scaling in branch thickness and the fractal aesthetic of trees (PNAS Nexus, α 1.5–3) — https://pmc.ncbi.nlm.nih.gov/articles/PMC11812039/
- Tree branching: Leonardo da Vinci's rule versus biomechanical models (PLOS One) — https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0093535
- Stem form and taper (Brack & Wood, ANU — Metzger, form factors) — https://fennerschool-associated.anu.edu.au/mensuration/BrackandWood1998/SHAPE.HTM
- Tree taper (Wikipedia) — https://en.wikipedia.org/wiki/Tree_taper
- Radiata pine slenderness and wind damage thresholds (Frontiers) — https://www.frontiersin.org/journals/forests-and-global-change/articles/10.3389/ffgc.2023.1188094/full
- Modeling height-to-diameter ratio for Norway spruce and European beech (Trees) — https://link.springer.com/article/10.1007/s00468-016-1425-2
- Live Crown Ratio (Forest Measurements, Open Oregon) — https://openoregon.pressbooks.pub/forestmeasurements/chapter/5-4-live-crown-ratio/
- How tree growth affects tree failure (Alabama Extension — open vs forest vs edge form) — https://www.aces.edu/blog/topics/forestry/how-tree-growth-affects-tree-failure/
- Codominant stems and reducing tree failures (Bartlett) — https://www.bartlett.com/blog/codominant-stems-and-reducing-tree-failures/
- Apical dominance and apical control in multiple flushing of temperate woody species (Cline & Harrington, USFS) — https://www.fs.usda.gov/pnw/pubs/journals/pnw_2007_cline001.pdf
- Decurrent (Wikipedia) — https://en.wikipedia.org/wiki/Decurrent
- Tree anatomy: stems and branches (Coder, Bugwood — branch orders, self-pruning, epicormics) — https://bugwoodcloud.org/resource/files/15278.pdf
- Epicormic sprouting after pruning in coast redwood (Annals of Forest Science) — https://link.springer.com/article/10.1051/forest/2009015
- Predicting branch angle and branch diameter of Scots pine (Can. J. For. Res.) — https://cdnsciencepub.com/doi/10.1139/x98-141
- Evaluating branch angle measurements of European beech using TLS — https://www.sciopen.com/article/10.1016/j.fecs.2024.100279
- Buttress root (Wikipedia) — https://en.wikipedia.org/wiki/Buttress_root
- Ceiba pentandra (Wikipedia — buttress and crown dimensions) — https://en.wikipedia.org/wiki/Ceiba_pentandra
- Krummholz (Wikipedia — flag trees) — https://en.wikipedia.org/wiki/Krummholz
- Krummholz: The High Life of Crooked Wood (Northern Woodlands) — https://northernwoodlands.org/outside_story/article/krummholz-wood
