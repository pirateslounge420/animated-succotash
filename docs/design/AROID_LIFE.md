# Aroid life, genes, crosses and sports

Built 29 Sept 2026 (design §AP). The designer grows *Amorphophallus* and asked for each
species to live its real life: dormancy for the real reason and length, the shoot that
breaks the soil as a cataphyll-wrapped spike and then unfurls, the right bloom, the
right pollinators, cross-pollination with inheritance and variation, rare tetraploids,
and rare sports on every plant in the game.

## 1. The data

`data/plants/amorphophallus.json`, every one of the 246 accepted species, block `cycle`
(checked by `tools/plant_schema_check.py`):

| block | what | keys |
|---|---|---|
| `life` | what drives the rest and how long things last | `dormancy` dry / cold / cycle / evergreen; `leaf_days`, `rest_days`, `leaves_per_cycle` |
| `shoot` | the leaf shoot breaking the soil | `form` narrow / stout / blunt spike; `cataphylls` colour, markings, pattern; `rise_days` (soil to full petiole, blade still folded down); `unfurl_days` |
| `bud` | the inflorescence bud | `form` rounded / ovoid / conical / narrow spike; `cataphylls`; `bud_days` (soil to spathe opening); `peduncle_cm` |
| `bloom` | the flowering | `when` before / with / after / instead of the leaf; `then` leaf or rest; `opens` evening / night / morning / afternoon; `female_hours`, `male_after_hours` (protogyny); `open_days`; `thermogenic`; `scent` (carrion, gas, dung, cheese, fish, sweet, fruity, spicy, musky, none) and a note; `pollinators` (guilds: carrion, rove, dung, hister, sap and other beetles; blowflies, flesh flies, drosophilids, other flies; stingless, sweat and honey bees; thrips); `self_compatible`; `apomixis` |
| `fruit` | the berries | `unripe`, `ripe` colours; `ripen_days` |
| `tuber` | growth and spread | `kind`; `offsets`, `stolons`, `bulbils`; `first_bloom_years`; `bloom_every_years` |
| `ploidy` | chromosomes | `2n`, `cytotypes`, source |
| `hybrids` | documented crosses | `with`, `where`, `source` |
| `sports` | documented abnormal forms | `kind` (the sport vocabulary, §4), note |

Researched per species by six parallel passes (protologues on the Aroidpedia archive;
Hetterscheid & Ittenbach 1996; Kite & Hetterscheid's odour chemistry; Claudel 2021 and
Claudel et al. 2021 on pollinators and odours; Barthlott et al. 2009 on *A. titanum*;
Punekar & Kumaran 2010; Beath 1996 on *A. johnsonii*; the Borneo floral-biology work;
Flora of China; PROSEA; CCDB chromosome counts; botanic-garden bloom records and
growers' notes). Where nothing is published, values are reasoned from the species'
region and closest relatives and marked `estimated` (roughly half the life and bloom
blocks). `repro` is kept in step (dormant, pollinator, bloom season / days / interval,
clonal, apomixis); `aroid.bloom_with_leaf` and `appearance.fruit.colour` follow it.

Some cycles: *A. titanum* has no weather-driven rest — each leaf lives 12-18 months,
the tuber rests 2-6 months, and a mature tuber blooms instead of a leaf, opening in the
afternoon, the pollen 12-28 h later; *A. paeoniifolius* blooms from the bare tuber at
the end of the dry season and leafs through the monsoon; *A. konjac* rests through the
cold winter and blooms in spring before the leaf, heating in the morning, fly-pollinated;
*A. muelleri* (triploid porang) sets seed without pollination; *A. coaetaneus* keeps its
leaves; *A. hewittii* opens at 11:00 and is visited by stingless bees; *A. johnsonii*
opens at dusk with a fishy stench and traps carrion scarabs overnight.

## 2. The life, off the world clock (`scripts/ecology/aroid_life.gd`)

Nothing is stored: a plant's life is a pure function of its key (PlantGenetics.key_of:
where it grows), its species' cycle, its latitude and longitude, and the world day, so
the same plant is at the same point of its life on every visit. Two channels:

- **leaf:** dormant (nothing above ground) → shoot (the spike rises over `rise_days`) →
  unfurl (`unfurl_days`) → leaf → senesce (the last ~10%) → dormant.
- **flower:** bud (`bud_days`) → bloom (opens at the local `opens` hour; female for
  `female_hours`, pollen from `male_after_hours`; open `open_days`) → wilt, or fruit
  (the berries ripen over `ripen_days`) → nothing.

Seasonal species flush once a year at their season (the hemisphere's own: Seasons): a
dry-season species as the rains come (year fraction 0.125 after spring's middle),
cold-dormant ones as it warms (0.07), with a week's jitter per plant and per year. The
leaf lives `leaf_days`; the tuber rests the rest of the year. Everwet species walk their
own leaf / rest / bloom cycles from their birth, out of step with every other plant.
Blooming is the tuber-maturity gate of design §E: first at `first_bloom_years` old,
then every `bloom_every_years`; the bloom comes before the leaf, with it, after it or
instead of it, then a leaf the same season or a rest. Old growth: 85% of plants are
mature tubers, 15% young ones that only leaf.

Fruit set: the female phase comes first, so a bloom needs another plant's pollen.
Unseen blooms are rolled — seasonal species (which bloom in step) 45%, everwet ones
(lone bloomers) 12%, self-compatible ones +25% — times the plant's own fertility (a
triploid or crested sport sets little). Apomictic species always fruit.

Cost: ~30 µs a plant (a per-plant cache keeps each plant's draws, its bloom years and
where an everwet walk got to).

## 3. In the world (`scripts/ecology/aroid_garden.gd`)

For every Amorphophallus MultiMesh in the detail ring, the garden keeps the placed
buffer and writes a new one each pass (a few plants per frame, `BUDGET_US`): the
umbrella stand-in scaled away while the tuber rests, spreading as it unfurls, collapsing
as it dies back. Beside them, per species per chunk, one MultiMesh per passing part
(`AroidMeshes`, `shaders/aroid_part.gdshader`): the spike and the bud in their
cataphyll colours and pattern, the peduncle in the petiole's, the spathe (outside and
inside colours), the appendix (the spadix colour), the pollen once the male phase comes,
the berries from unripe to ripe; wilting spathes lean and darken; twin-flowered sports
show two inflorescences and colour-morph sports a shifted spathe.

**Scent:** an open bloom in its first night carries by kind (carrion 160 m, gas 140,
dung and fish 110, cheese 90 ... sweet 45), ×1.4 if it heats, × its scent gene; downwind
of it (or within 15 m) the player reads it once: "A stench of rotting meat hangs on the
wind." **Pollinators:** within 110 m, up to eight blooms draw their guilds as small
insect clouds round the spathe (14 species in `creatures.json`, `spawn: "bloom"`,
`body: "insects"`: *Diamesus osculans* carrion beetles, *Creophilus* rove beetles,
*Chrysomya* blowflies, *Tetragonula* stingless bees, *Carpophilus* sap beetles,
*Phaeochrous* carrion scarabs ...), gone when the scent phase ends.

**Crosses:** when a receptive bloom and another plant's pollen are out within 400 m
(same species or a documented hybrid partner; a clone's own pollen is rejected unless
the species is self-compatible), the cross is real: the bloom sets fruit and its seeds
are that cross. **Samples:** E on a fruiting plant takes its berries; the item carries the
cross ("diploid x diploid (seen)"), the seedling's ploidy, sport and genes. The HUD
names the plant's stage after its name ("in bloom, receptive", "in fruit, ripening",
"shoot coming up"); a resting tuber isn't named.

## 4. Genes, crosses and sports (`scripts/ecology/plant_genetics.gd`, `data/sports.json`)

**Genomes** (the aroids): each gene of the species' `genes` (size, pattern, scent,
allocation) plus vigour is the mean of two notional parents drawn round the plant's
deme (a 20 km value-noise field per species and gene), plus segregation noise; a clump
(offsets, stolons, bulbils) shares one genome. Ploidy from the chromosome count
(2n 39 → triploid), with a species' other recorded cytotypes now and then.

**Crosses:** each gene the parents' mean + noise, a rare mutation; 2x × 2x → 2x with the
rare unreduced gamete (0.5% triploid, a quarter of that tetraploid — the spontaneous
polyploid); 4x × 4x → 4x; 2x × 4x → 3x, nearly sterile; an apomictic mother's seed is her
clone. Sports pass by their rule: seed (half the seedlings), recessive (a quarter; all if
both parents carry it), clonal (variegation, crests: only cuttings and offsets, a few
seedlings).

**Sports, every plant:** rolled once per plant (per clump for clonal species) from where
it grows. Rates by shape (one in 3,000; aroids one in 1,500; cacti one in 2,000; grasses,
mosses, cushions, mats none); the kind weighted shape 1 : genus-documented 6 :
species-documented 12 (217 of 469 genera have documented sports: copper, weeping and
columnar beech; contorted hazel; golden oak; crested and monstrose *Trichocereus*;
ducksfoot and polyploid cannabis; witch's-broom spruces; albino-chimera redwoods ...).
The kinds: polyploid (tetraploid: bigger, deeper green), variegated (cream sectors),
aurea (golden), anthocyanin-free (the green form), melanic (dark/copper), glaucous
(blue), dwarf, cristate, monstrose, weeping, fastigiate, contorted, laciniate, fused
leaflets, twin inflorescence, colour-morph flower, prolific offsets. VegetationPlacer
scales the plant by the sport's size and packs its code into the instance data with the
moss (moss + 2 × code); the foliage shader draws the colour sports; the tree's record
keeps it for the HUD.

## 5. Not yet

- Seedlings: berries carry the cross, but a seed dropped or planted doesn't grow — the
  world keeps nothing between sessions (persistence, Phase 12) and wild recruitment
  waits for the flora ledger (Phase 6). Wild plants' genomes stand in for it: each is
  a cross from its local population.
- The aroid's own mesh (design: the `aroid` shape — the painted petiole and the
  three-way dissected blade) is still the umbrella stand-in; form sports (weeping,
  columnar, crested ...) are recorded, not yet drawn.
- Pollinators don't carry pollen round the map by themselves: crosses are seen only
  among the blooms in the detail ring; everything else is rolled.

## 6. Checks

- `tools/aroid_check.gd` (headless, no world): konjac rests all winter and leafs all
  summer at 27° N and blooms from the bare tuber; protogyny; titanum's plants out of step;
  muelleri fruits every bloom; coaetaneus always in leaf; a real donor makes a bloom
  fruit; sport rates and kinds; genomes, crosses, ploidy rules; the per-state cost.
- `tools/aroid_world_check.gd` (STAMP=1): finds aroids on the dev planet, steps two years
  (leaf, rest, spikes, buds, blooms, fruit drawn), goes to a bloom (spathe, appendix,
  pollen on day two, pollinators, the smell), a real cross, berries as a sample, sports
  among ~50,000 placed plants.
