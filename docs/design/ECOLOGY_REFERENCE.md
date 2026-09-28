# Ecology reference — numbers for the per-region population sim

Research notes for RECONCILIATION §X (carcasses), §AC (creature guilds, thermals) and
WORLD_SYSTEMS_SPEC Phase 7/8. Every figure is cited; the game rules at the end say
how the figures were scaled down. Planet = 1/10 Earth, populations are per-region
numbers, entities spawn only near the player.

## 1. Trophic structure

- **Lindeman's 10 % rule.** Roughly 10 % of energy passes between trophic levels;
  Lindeman himself reported efficiencies from 0.1 % to 37.5 %, and 5–20 % is the
  honest working range (Lindeman 1942; Wikipedia "Ecological efficiency"). Four
  levels is the practical ceiling for a terrestrial food web: plants → herbivores →
  carnivores → (rarely) a second carnivore level, then scavengers/decomposers off
  every level.
- **Predator–prey power law (Hatton et al. 2015, *Science*).** Across 2,260
  communities, predator biomass ∝ prey biomass^0.75 (±0.1). Doubling prey does
  *not* double predators; the pyramid gets ~3× more bottom-heavy from the poorest
  to the richest African parks (Hatton 2015; EEB & Flow 2015; Nature 2015).
  A published form for African large mammals:
  **carnivore kg/km² = 0.094 × (herbivore kg/km²)^0.73**, and the exponent in
  wolf–prey systems is 0.72 (cited in Sci. Rep. 2025). Worked values:

  | herbivore biomass | predicted carnivore biomass | ratio |
  |---|---|---|
  | 100 kg/km² (poor boreal) | 2.7 kg/km² | 2.7 % |
  | 1,000 kg/km² (temperate forest / dry savanna) | 14.5 kg/km² | 1.4 % |
  | 10,000 kg/km² (rich savanna) | 78 kg/km² | 0.8 % |

- **Measured counts.** Yellowstone Northern Range 2005–12: 54 wolves/1,000 km²
  against 5.0 elk/km² (3.4–6.3), i.e. **~1 wolf per 90 elk**; the Fuller ungulate
  biomass index predicted 55/1,000 km² (Yellowstone wolf density paper, wolf.org).
  Isle Royale swings from 50 wolves : 750 moose (1980, 1:15) to 2 : 1,600 (2017)
  to ~30 : 840 (2024, 1:28) (Yellowstonian). Nelchina, Alaska: 0.4–0.6 cow
  moose/km², 9–15 wolves/1,000 km², 21 brown bears/1,000 km² (ADF&G). Lions run
  12/100 km² in Serengeti and Kruger, 26 in Nairobi NP, ~38 in Ngorongoro
  (ALERT); with ~1.5 M wildebeest, 250 k zebra and 400–500 k gazelle on ~25,000
  km² (Wikipedia Serengeti) that is on the order of **one lion per 500–800
  ungulates**. Prey above ~150 kg have few natural predators and are food-limited;
  small ungulates are hunted by many species at once (Sinclair et al. 2003).
- **Mesopredators.** Where wolves are present coyotes sit at 0.014–0.09/km²
  (Yukon); where absent 0.2–0.4/km², up to ~1/km² with ungulate subsidies and 2–3
  in cities (Ripple et al. 2013). Rule of thumb: mesopredators are 5–25× more
  numerous than the apex predator by count and are suppressed 5–25× when it is
  present.

## 2. How many species

Per-site vertebrate richness (whole protected areas):

| site (biome) | area km² | mammals | birds | reptiles | amphibians |
|---|---|---|---|---|---|
| Manu, Peru (lowland–montane rainforest) | ~17,000 | ~200+ | >1,000 | 132 | 155 |
| Kruger (savanna) | 19,633 | 147 | 507 | 114 | 34 |
| Serengeti (savanna) | 14,763 | — | >500 | — | — |
| Everglades (wetland) | 6,107 | 40 | 350 | 50 | 24 |
| Great Smokies (temperate deciduous) | ~2,100 | 70 | ~240 | ~40 | ~40 |
| Yellowstone (montane conifer/steppe) | ~8,990 | 67 | ~300 | 6 | 4 |
| Saguaro (Sonoran desert) | ~370 | ~70 | 200 | 50 | 8 |
| Denali (boreal/tundra) | ~24,000 | 39 | 169 | 0 | 1 |

(Sources: ScienceDaily 2014; Harvard Davies Lab; Wikipedia; NPS; Friends of
Saguaro.) Tropical forests hold over half of all vertebrate species (Pillay et
al. 2022). Reptiles/amphibians collapse toward the poles; birds fall by ~5× from
rainforest to tundra; mammals by ~5×.

**Species–area law.** S = cA^z with z typically 0.15–0.39; ~0.25 is the canonical
island/regional value (Arrhenius; Preston; hws.edu species-area text; Storch et
al. 2006 PNAS). Halving area loses ~16 % of species; a 1/100 area keeps ~32 %;
a 1/1,000 area keeps ~18 %.

## 3. Density and home range

**Allometry.** Herbivore density ≈ 10^4.23 × M(g)^-0.75 individuals/km² (Damuth
1981): 20 g mouse ≈ 1,800/km², 1 kg squirrel ≈ 95/km², 100 kg deer ≈ 3/km²,
500 kg bison ≈ 0.9/km². Real values scatter within one order of magnitude.
Home range ∝ M^1.07 overall; carnivores 1.20, omnivores 1.12, herbivores 1.02
(Jetz et al. 2004); carnivores have ranges ~10× a herbivore of equal mass because
prey are 1/100 of plant biomass. Exclusive use falls as M^-0.25 — a 100 kg animal
holds only ~7 % of its range exclusively (Jetz 2004), so big animals overlap.

| guild archetype | density | home range / territory |
|---|---|---|
| white-tailed deer | 5–12/km² (thresholds), up to 20+ | 1–3 km² |
| elk | 3–6/km² (Yellowstone NR) | seasonal ranges tens of km² |
| moose | 0.4–0.6/km² (Alaska) | 20–50 km² |
| bison / caribou | ~1/km² locally; caribou herds 200,000 strong | Porcupine herd migrates ~1,350 km round trip |
| wolf | 8–15/1,000 km² (Alaska), 43–63/1,000 km² (Voyageurs, Yellowstone NR) | packs of ~4.7 (Voyageurs); territories 80–240 km² central Europe, 173–294 km² Białowieża, 415–500 km² N. Scandinavia (Jędrzejewski 1998, 2007) |
| brown bear | 5–40/1,000 km² interior, up to 175 coastal (allgrizzly.org) | ~2,000 km² (Harestad & Bunnell table) |
| black bear | ~0.8/km² Smokies (densest in N. America) | 10–100 km² |
| lion / leopard | 12–38 lions/100 km²; 5.4 leopards/100 km² Serengeti dry season | prides 20–400 km² |
| red fox | ~1–3/km² rural | 0.4–1 km² farmland, 2–13 km² moor/mountain, up to 50 km² desert (Wildlife Online) |
| coyote / jackal | 0.04–0.4/km² (see §1) | 10–30 km² |
| raccoon | 2–10/km² | ~1 km² |
| snowshoe hare | 0.5–2+/ha (50–200/km²) over the 10-year cycle (Kluane) | a few ha |
| tree squirrel | 50–200/km² | 1–10 ha |
| raptors (Kluane boreal) | red-tailed hawk 15–20 pairs, great horned owl 5–20 pairs, goshawk 1–5 territories per ~100 km²; raven 2 pairs/100 km² | 5–20 km² per pair |
| vultures / condors | colonial roosts; a few birds per 100 km² of open country | forage 50–100+ km from the roost |
| waders / herons | colonies at water; 1–10 pairs per km² of wetland | feed within a few km |

## 4. Behaviour patterns

- **Activity cycle.** Of terrestrial mammals 69 % are nocturnal, 20 % diurnal,
  8.5 % cathemeral, 2.5 % crepuscular; nocturnality peaks in deserts, diurnality
  at high altitude (cold nights), crepuscular/cathemeral in the Arctic (Bennie et
  al. 2014, PNAS). Ungulates are mostly crepuscular; canids and felids crepuscular
  to nocturnal; bears cathemeral; squirrels and most birds diurnal; owls, bats,
  raccoons, opossums, gliders nocturnal; wolves howl most at dusk and dawn and in
  winter (NPS).
- **Social structure.** Wolves: family packs led by a breeding pair, offspring
  disperse at 1–2 years, up to 800 km (NPS). Lions: prides; leopards, bears, foxes,
  lynx, most mustelids: solitary. Deer: small matriarchal groups; elk, bison,
  caribou, wildebeest: herds of tens to hundreds of thousands. Vultures roost and
  feed communally.
- **Migration.** Caribou 1,250–1,350 km/yr; wolves following them >1,000 km; mule
  deer up to 772 km; wildebeest 600–700 km; pronghorn 300–435 km (Science News
  2019). Elk in Yellowstone move down-valley in winter and up in summer;
  migrations follow green-up (spring north/up, autumn south/down) (Discover
  Wildlife).
- **Hibernation.** Bears den roughly Nov–Apr in the north (cubs born in the den,
  2–3 per litter); ground squirrels, marmots and bats 5–8 months; snakes in cold
  bands den in rock; reptiles and amphibians are absent above the boreal line.
- **Breeding and litters (N. America, Farm and Dairy).** White-tailed deer rut
  Oct–Dec, 200 d, twins; black bear mates Jun–Jul, 2–3 cubs; raccoon Jan–Feb, 3–6;
  squirrel Jan (and summer), 4–5; skunk 4–6; bobcat 2–4; porcupine 1; opossum up
  to 13. Wolves mate in late winter, pups in early spring, typically 4–6.
- **Scavenging succession.** Blowflies find a carcass within minutes and beetles
  follow as the second wave (Nature Scitable). In the Mara, marabou and *Gyps*
  vultures dominate days 1–7 and peak by day 7–14; hooded vultures, ibis and
  mammals (hyena, mongoose) take over after day 14 on soft tissue and maggots.
  Carcasses on land are usually stripped in **under a day**; in water they last
  weeks (Handler et al. 2021). Vertebrates take most of the mass; insects and
  microbes finish it, faster with temperature; small carcasses in summer are gone
  in days, a whale skeleton takes 16 years.
- **Landscape of fear / flight distance.** Measured flight initiation distances:
  pronghorn 235 m, mule deer 149–250 m, elk 85–201 m, bison 101 m; N. American
  birds 18–390 m (Wikipedia FID, citing Taylor & Knight 2003). Distances rise in
  open habitat, for females with young, in hunted populations and for a human on
  foot vs a vehicle (Stankowich 2008); wolves and human disturbance both push elk
  into cover and cut feeding time (Ciuti et al. 2012); prey responses track the
  predator's diel schedule (Kohl et al. 2018).

## 5. Soaring

Griffon vultures climb thermals at 1.6 m/s (adults) vs 1.26 m/s (juveniles) on a
circle of radius ~32–36 m, flapping only 2–5 % of the time (Harel et al. 2016,
*Sci. Rep.*). Migrating raptors: median climb 1.84 m/s (0.1–5.1), peaking around
noon–early afternoon with insolation; inter-thermal glides average 1,740 m
(165–8,265 m) at 13.5–17 m/s airspeed; large soarers fly 6–9 h a day inside the
thermal window and flap only around sunrise and sunset (Spaar, Int. Ornith.
Congr.). Griffons top out ~1,400 m ASL in thermals (Int. J. Env. Res. 2018). A
glide ratio of ~10–15:1 (sink ≈ 1 m/s at 13–15 m/s) reproduces those glide
lengths from a 100–200 m climb.

## 6. GAME RULES DERIVED FROM THIS

Scaling honesty: the planet is 1/10 Earth in radius, so regions are small. The
budget below is ~1/20 of a real site's vertebrate list (z = 0.25 applied to a
1/1,000 area gives 18 %; the further cut to ~5 % is a build budget, not ecology).
Ratios and densities are kept real; only the species count is compressed.

1. **Species budget per biome group** (build target, 10 % of the biggest real
   lists, floor of 6). Share bodies across neighbours per §AC's archetype rule.

   | biome group | mammals | birds | reptiles+amphibians | total | Earth site |
   |---|---|---|---|---|---|
   | tropical rainforest | 12 | 20 | 12 | 44 | Manu |
   | savanna / tropical grassland | 10 | 16 | 6 | 32 | Kruger |
   | wetland / swamp / mangrove | 5 | 14 | 6 | 25 | Everglades |
   | temperate forest | 7 | 12 | 5 | 24 | Smokies |
   | temperate grassland / steppe / montane | 7 | 10 | 2 | 19 | Yellowstone |
   | desert | 5 | 8 | 5 | 18 | Saguaro |
   | boreal | 4 | 8 | 0–1 | 12 | Denali |
   | tundra / polar / high alpine | 3 | 5 | 0 | 8 | Denali north |

   §AC's flat 8–12 per biome is wrong in shape: it gives the tundra as many species
   as the rainforest. Richness must fall ~5× from rainforest to tundra and reptiles
   must vanish above the boreal line. The 150–200 total still works.

2. **Guild ratios by species count** (from the real lists): mammals ~25 %, birds
   ~45–55 %, herps 10–30 % (tropics high, north zero). Inside mammals: small
   mammals (rodents, bats, lagomorphs) ~60 %, mesopredators ~15 %, large herbivores
   ~15 %, apex predators ~5–10 %. So a 7-mammal temperate forest is 3–4 small, 1
   mesopredator, 1–2 large herbivores, 1 apex — close to §AC, but birds must be
   the largest guild, not "2–3".

3. **Carrying capacity per region (individuals/km² at K, before predation).**
   Compute from Damuth: K_herb = 10^4.23 × M_g^-0.75 × biome_productivity, where
   productivity = 1.5 rainforest/wet savanna, 1.0 temperate forest and wetland,
   0.6 steppe, 0.3 boreal, 0.15 desert, 0.1 tundra. Check values: deer 3–8/km²,
   moose 0.5, bison 1, hare 50–200, squirrel 100.

4. **Predator law to enforce.** Per region and per trophic step:
   `carnivore_kg = 0.094 × herbivore_kg^0.73` (Hatton). Divide by carnivore body
   mass for numbers; split ~60 % apex / 40 % mesopredator by biomass when both are
   present; when the apex is absent, mesopredator count ×5. Sanity: 1 wolf per
   50–100 deer-equivalents, 1 lion per 500 ungulates, 1 fox per km² of farmland.
   Never let the predator:prey biomass ratio exceed 3 % or predator count exceed
   prey count / 10.

5. **Prey size shield.** Prey over 150 kg are only taken by pack hunters or big
   cats; solitary mesopredators take prey under ~20 kg (Sinclair 2003).

6. **Home range / territory per entry:** `range_km2 = a × M_kg^b`, b = 1.0
   herbivores, 1.2 carnivores; anchor a so a 100 kg deer gets 2 km², a 40 kg wolf
   pack 150 km², a 5 kg fox 2 km², a 0.5 kg squirrel 0.02 km². Territories of
   large animals overlap (exclusive share ≈ M^-0.25).

7. **Fields each creature entry carries:** `activity` (diurnal, nocturnal,
   crepuscular, cathemeral — defaults: ungulates crepuscular, canid/felid
   crepuscular-nocturnal, bears cathemeral, squirrels/most birds diurnal,
   owls/bats/raccoon/glider nocturnal), `social` (solitary, pair, family_pack,
   herd:size), `migration` (none, altitudinal, latitudinal:km), `hibernation`
   (none, months), `breeding_season` (months), `litter` (n), `mass_kg`,
   `flight_distance_m` (deer 150, elk 100–200, bison 100, pronghorn 235, small
   birds 20–50), plus §AC's archetype/palette/scale.

8. **Carcass timeline (§X).** Blowflies within minutes; vultures within 30–120
   min by day in open country; in forest, corvids first; mammals (fox, hyena,
   bear, boar) after dark. Soft tissue of a deer-sized carcass gone in 1 day with
   vultures, 2–5 days without; bones persist for a season; scale decay by
   temperature. Water carcasses last weeks. Vultures do not fly at night or in
   rain: a night death is found at mid-morning.

9. **Thermal rule (§AC).** Thermals from ~2 h after sunrise to ~1 h before
   sunset, peaking 12:00–15:00; strength 1–2 m/s (up to 4 over bare rock), zero at
   night, in rain and over water; climb radius ~35 m; top ~1,000–1,500 m AGL; glide
   between thermals at 13–17 m/s with a 10–15:1 ratio, typically 1–2 km per glide.
   Soarers roost from dusk to mid-morning.

10. **Mesopredator release** is the emergent test: kill the region's apex predator
    and foxes/coyotes/raccoons climb toward 5× within a few in-game years.

### What §AC got wrong

- Flat 8–12 species for every biome; real richness varies ~5× and herps vanish
  in the north.
- Birds are the largest vertebrate guild everywhere (45–55 % of species), not
  "2–3".
- "1 apex predator per biome" is fine, but the sim must derive its *count* from
  prey biomass^0.73, never a fixed ratio; the ratio falls as prey get richer.
- Small mammals should outnumber the rest of the mammal list combined.
- No activity, social, migration or seasonal fields are listed; they are the
  behaviours the player actually sees.

## Sources

- Hatton et al. 2015, *Science* 349:aac6284 — https://www.science.org/doi/10.1126/science.aac6284
- Nature research highlight 2015 — https://www.nature.com/articles/525161a
- EEB & Flow blog on Hatton 2015 — https://evol-eco.blogspot.com/2015/09/predictable-predator-prey-scaling.html
- Sci. Rep. 2025, trophic biomass with livestock (cites Hatton equation) — https://www.nature.com/articles/s41598-025-85469-2
- Lindeman 1942 / Ecological efficiency — https://en.wikipedia.org/wiki/Ecological_efficiency
- Yellowstone wolf density predicted by elk (wolf.org PDF) — https://wolf.org/wp-content/uploads/2013/08/347-Yellowstone-wolf-Canis-lupus-density...pdf
- Yellowstonian, Isle Royale — https://yellowstonian.org/on-this-island-theres-no-battle-royale-between-wolves-and-moose-but-why-didnt-the-prey-perish/
- Voyageurs Wolf Project 2022 — https://www.voyageurswolfproject.org/2022-wolf-population-summary
- ADF&G Nelchina moose–predator report — https://www.adfg.alaska.gov/static/home/library/pdfs/wildlife/research_pdfs/f01moo_pred13.pdf
- ALERT lion ecology — https://lionalert.org/lion-ecology/
- Wikipedia, Serengeti NP — https://en.wikipedia.org/wiki/Serengeti_National_Park
- Sinclair, Mduma & Brashares 2003, *Nature* — https://www.nature.com/articles/nature01934
- Ripple et al. 2013, mesopredator effects — https://trophiccascades.forestry.oregonstate.edu/sites/default/files/Ripple_2013_BC.pdf
- ScienceDaily 2014, Manu — https://www.sciencedaily.com/releases/2014/02/140220095005.htm
- Harvard Davies Lab, Kruger — https://davieslab.oeb.harvard.edu/kruger-national-park-south-africa
- Wikipedia, Everglades NP — https://en.wikipedia.org/wiki/Everglades_National_Park
- NPS Great Smokies mammals — https://www.nps.gov/grsm/learn/nature/mammals.htm
- NPS Yellowstone mammals — https://www.nps.gov/yell/learn/nature/mammals.htm
- NPS Denali wildlife — https://www.nps.gov/dena/learn/nature/wildlife.htm
- Friends of Saguaro — https://friendsofsaguaro.org/wildlifehabitat
- Pillay et al. 2022, *Front. Ecol. Environ.* — https://esajournals.onlinelibrary.wiley.com/doi/10.1002/fee.2420
- Species–area relation text (hws.edu) — https://math.hws.edu/~mitchell/SpeciesArea/speciesAreaText.html
- Storch et al. 2006 PNAS species–area — https://www.pnas.org/doi/10.1073/pnas.0510605103
- Damuth 1981, *Nature* — https://complexityexplorer.s3.amazonaws.com/supplemental_materials/6.8+Scaling/damuth1981a.pdf
- Jetz, Carbone, Fulford & Brown 2004, *Science* — https://jetzlab.yale.edu/sites/default/files/files/Jetz%20et%20al%20Science%2004.pdf
- Kelt & Van Vuren 2001, *Am. Nat.* — https://doi.org/10.1086/320621
- Montana State Bio491 home-range notes (Harestad & Bunnell table) — https://www.montana.edu/hansenlab/documents/bio491/Week5.pdf
- Hanberry 2021, deer density (USFS) — https://www.fs.usda.gov/rm/pubs_journals/2021/rmrs_2021_hanberry_b004.pdf
- Jędrzejewski et al. 1998, *J. Mammal.* — https://academic.oup.com/jmammal/article/79/3/842/859243
- Jędrzejewski et al. 2007, *Ecography* — https://nsojournals.onlinelibrary.wiley.com/doi/abs/10.1111/j.0906-7590.2007.04826.x
- Wildlife Online, red fox home range — https://www.wildlifeonline.me.uk/animals/article/red-fox-territory-home-range
- allgrizzly.org bear density — https://www.allgrizzly.org/bear-density
- Kluane project ch.16, raptors and scavengers — https://www.zoology.ubc.ca/~krebs/downloads/Kluane%20Book%20-%20Ch16%20-%20Raptors%20and%20Scavengers.pdf
- Bennie et al. 2014 PNAS, time partitioning — https://kevingaston.com/wp-content/uploads/2017/05/Bennie-et-al-14-Biogeography-of-time-partitioning-in-mammals.pdf
- NPS Wolf ecology basics — https://www.nps.gov/articles/life-of-a-wolf.htm
- Science News 2019, longest migrations — https://www.sciencenews.org/article/caribou-migrate-farther-than-any-other-known-land-animal
- Discover Wildlife, caribou migration — https://www.discoverwildlife.com/animal-facts/caribou-migration
- Farm and Dairy, mating seasons — https://www.farmanddairy.com/columns/its-mating-season-for-mammals-in-north-america/47713.html
- Nature Scitable, carrion decomposition — https://www.nature.com/scitable/knowledge/library/the-ecology-of-carrion-decomposition-84118259/
- Handler et al. 2021 *Ecosphere*, wildebeest carcasses — https://www.subaluskylab.com/uploads/1/2/9/7/129766656/handler_et_al_2021_temporal_resource_partitioning_in_scavengers_after_wildebeest_mass_drownings_ecosphere.pdf
- Wikipedia, Flight initiation distance — https://en.wikipedia.org/wiki/Flight_initiation_distance
- Stankowich 2008, *Biol. Conserv.* — https://www.sciencedirect.com/science/article/abs/pii/S0006320708002334
- Ciuti et al. 2012 *PLOS One* — https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0050611
- Kohl et al. 2018, diel landscape of fear — https://qanr.usu.edu/wild/labs/macnulty-lab/files/kohl-et-al-2018.pdf
- Harel et al. 2016 *Sci. Rep.*, vulture soaring — https://www.nature.com/articles/srep27865
- Spaar, raptor flight behaviour (Int. Ornith. Congr.) — https://www.internationalornithology.org/PROCEEDINGS_Durban/Symposium/S31/S31.4.htm
- Griffon flight types 2018 — https://link.springer.com/article/10.1007/s41742-018-0093-z
