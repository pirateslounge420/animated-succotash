# Low-Poly Exploration Game — Design Notes

## Overview

An ambient open-world exploration game built in Summer Engine (Godot 4). No end goal: pure wandering at a tribal, pre-firearm tech level. Scope is stripped to terrain generation and ecology only; races, cultures, settlements, crafting and combat come later, built on top. The world is a walkable cube-sphere planet about 1/100th of Earth's size (\~400 km around). The day-night cycle runs 48 real minutes per in-game day, scaled down from 24 hours (two real minutes per in-game hour). As on Earth, twilight is counted as day, so at the equator the lit part runs slightly longer than the night (about 25 minutes against 23).

## Visual & Tone References

GameCube-era low-poly look: Phantasy Star Online episodes 1 and 2, F-Zero GX, Super Smash Bros Melee. Low texture resolution, flat or vertex lighting, leaving out enough detail that the player's brain fills the gaps. Long view distance unless fog, mountains or trees block it.

**Day: Frutiger Aero.** Bright, glossy, optimistic early-2000s look: clear aqua skies, clean saturated greens and blues, shiny water.

**Night: moonlit dark fairy tale.** Reference: ozavry\_ on Instagram. The world drowns in deep cobalt and violet moonlight under a huge moon, with fog, mist and reeds for depth. Warm light is rationed to one or two accents per scene (campfire, lit window, glowing doorway), and water glows as if lit from within. Surfaces read crunchy, over-sharpened and wet, like heavily graded PS2 or Oblivion-era 3D. Tone is cozy-eerie, quiet and a little melancholy: boardwalks over marsh, stilt shacks, mushroom villages, overgrown ruins, and folk like witches, goblins and trolls at rest rather than in combat. Night is the showpiece, not just the dark half.

**Glow: the third palette, for magical places.** At ruins, glow ponds and mythical creatures' territories, night turns bioluminescent: water, moss and some plant tips emit a saturated teal or cobalt light that actually lights the scene, and the surrounding moonlight falls away, so it reads like neon against black rather than ordinary moonlit night.

**Grading.** Deep, near-cartoonish ultramarine overhead (over the aqua horizon band), punchy greens and water, N64/PS1-era color: flat bands instead of smooth gradients in the sky and the distance fog, 15-bit dithered color, intentionally low-res textures, flat Lambert lighting with no PBR sheen.

**Ruins as set pieces.** Ivy-choked aqueducts, crumbling towers and lone castles on hills stand as distinct silhouettes that draw the wanderer toward them: moss and vines over the stone, walls partly collapsed into rubble.

**The cycle bridges them.** The 48-minute day-night cycle blends from the bright day palette to the blue night palette through gradual dawn and dusk gradients.

## Creatures

Creatures are ambient and unscripted, with no quest framing. Species have varied spawn logic, with certain animals more likely in particular biomes.

## Lighting & Day-Night Cycle

Real light sources drive the cycle, not glow shaders. The sun is a DirectionalLight3D by day; the moon is a dimmer, blue-tinted DirectionalLight3D by night. The moon behaves as it does on Earth: it orbits once per 28-day phase cycle on a slightly tilted orbit (about 5°), so each day it rises later than the day before. A full moon rises as the sun sets and stays up all night, a new moon travels with the sun and is lost in its glare, and a quarter moon is up for half the day and half the night. Both lights genuinely arc across the sky rather than snapping on and off.

**Elevation-based intensity**: each light's brightness and color temperature follow its angle above the horizon — dim and warm near the horizon, full strength near zenith, fading to nothing once below it. Around full moon there's a natural dawn/dusk window where sun and moon are briefly above the horizon together, each casting its own color from opposite sides of the sky; in other phases the moon can hang in the daytime sky.

**Ambient light and sky color** track the active light's color and elevation continuously (not discrete keyframes) — warming and lengthening shadows near sunset, cooling into blue as the moon takes over.

**Water** is reflective (fresnel-based) rather than emissive, picking up whichever light is dominant — warm glare by day, cool glint by night.

**Local light sources** — campfires, lit windows, doorways — are separate small Omni/SpotLights, independent of the sun/moon system and present day or night. These are the deliberate warm "pop" against the moody blue night, per the ozavry\_-style aesthetic reference.

### Moon phase and mansions

The moon cycles through a real 28-day phase cycle, modeled on the Chinese 28 lunar mansions (er shi ba xiu) rather than the 27-mansion Indian nakshatra system. The 28 mansions group into four sets of seven, each tied to a cardinal direction, season, and guardian beast:

- **Azure Dragon** (east, spring, wood): Jiao, Kang, Di, Fang, Xin, Wei, Ji
- **Black Tortoise** (north, winter, water): Dou, Niu, Nu, Xu, Wei, Shi, Bi
- **White Tiger** (west, autumn, metal): Kui, Lou, Wei, Mao, Bi, Zi, Shen
- **Vermilion Bird** (south, summer, fire): Jing, Gui, Liu, Xing, Zhang, Yi, Zhen

Each mansion corresponds to a real historical Chinese asterism (a small pattern of 2–10 stars). As the moon phase advances one mansion per in-game day, a small constellation glyph tracing that mansion's actual star pattern appears near the moon, tinted by its beast group's color — doubling as a phase indicator and a loose in-game calendar a player could learn to read.

Moon brightness and light intensity scale with phase — a full moon lights the night meaningfully more than a new moon or thin crescent.

## Vegetation

Plants read climate, not biome names. Each species has its own tolerance ranges and grows wherever conditions suit it, so biomes emerge and blend instead of snapping at borders. Biome names stay as labels for the map and hover readout only.

### Species data

Each species record holds:

- **Temperature band** (°C), **moisture band**, and an optional **altitude band** (m).
- **Density**: highest in the middle of each band, thinning toward the edges so ranges overlap and fade.
- **Tier**: emergent, canopy, sub-canopy/shrub, ground cover, or epiphyte.
- **Soil preference**: read from the planet's rock data (rich volcanic, thin dry limestone karst, and so on), checked alongside climate.
- **Special conditions** (optional, short list): e.g. needs standing water, needs river bank.

### Tiers

1. **Emergent**: rare giants poking above the canopy, mainly for silhouette.
2. **Canopy**: the main trees.
3. **Sub-canopy / shrub**: young trees and tall shrubs. In wet forests this is the densest layer.
4. **Ground cover**: grasses, ferns, low herbs, mosses. Often sparse under heavy shade.
5. **Epiphytes**: not scattered on terrain. They attach to trees already placed, on any host in range, with their own climate band (mostly moisture-driven). Examples: Spanish moss, mosses, orchids, bromeliads.

### Placement rules

- **Water gradient**: moisture rises near rivers, lakes and coasts using the blueprint's flow and coast-distance data. Trees crowd water and thin away from it, so dry grassland gets gallery-forest ribbons along rivers.
- **Clumping**: a noise mask multiplied by density, so plants grow in patches rather than an even sprinkle.
- **Spacing**: a minimum distance per tier so trunks never overlap.
- **Dominance**: a slow, large-scale noise field picks a local favourite species and boosts it. One valley is mostly pine with some birch; the next flips it.
- **Aspect**: sun-facing slopes run a few degrees warmer and drier, shaded slopes cooler and wetter, fed into the same tolerance check. Combined with the lapse rate, each altitude band gets a warm face and a cold face.
- **Size and lean jitter**: small random scale and tilt per plant so repeated models don't read as stamps.
- **Special objects**: cypress knees scatter around cypress standing in water.

### Real-world species by biome (researched so far)

Starting candidates per tier. Remaining biomes still to research.

| Biome | Canopy / hero | Shrub | Ground cover | Epiphyte | Notes |
| --- | --- | --- | --- | --- | --- |
| Tropical rainforest | Emergents over 40 m, palms, buttressed broadleaf trees | Saplings, tree ferns | Sparse herbs, ferns | Orchids, bromeliads, lianas | Shrub layer densest; floor dark and fairly bare ([source](https://www.nature.com/scitable/knowledge/library/terrestrial-biomes-13236757/)) |
| Cloud forest | Short, gnarled broadleaf trees | Tree ferns | Mosses, filmy ferns | Mosses, liverworts, bromeliads, orchids | Epiphytes can outweigh a tree's own leaves ([source](https://en.wikipedia.org/wiki/Cloud_forest)) |
| Bayou / cypress swamp | Bald cypress, water tupelo | Buttonbush, Virginia willow, water elm, black willow | Sparse (low light, long flooding) | Spanish moss | Cypress knees in water ([source](https://www.wlf.louisiana.gov/assets/Conservation/Protecting_Wildlife_Diversity/Files/natural_communities_of_louisiana.pdf)) |
| Páramo | Frailejón (Espeletia), silvery rosette up to 10 m | Dwarf shrubs | Tussock grasses (Festuca, Calamagrostis), cushion plants | None | Wet, above treeline ([source](https://www.sciencedirect.com/topics/earth-and-planetary-sciences/paramo)) |
| Puna | Queen of the Andes (Puya raimondii), rare | Low daisy-family shrubs | Bunch and tussock grasses, ground rosettes | None | Drier cousin of páramo ([source](https://php.radford.edu/~swoodwar/biomes/?page_id=2500)) |
| Krummholz / alpine dwarf shrub | Wind-stunted conifers | Heath, dwarf willows (wetter spots) | Avens (Dryas) on dry ridges | None | Mostly under 0.5 m ([source](https://fieldguide.mt.gov/displayEG_Detail.aspx?EG=EVAV0G316)) |
| Temperate deciduous | Oak, ash, beech, maple, elm | Rich understory shrubs | Spring herbs | None | ([source](http://www.sbs.utexas.edu/levin/bio213/biomes/biomes.html)) |
| Savanna | Scattered acacias | None listed | Grasses | None |  |
| Tundra | None | None listed | Sphagnum moss, lichens, grasses, annuals | None | ([source](<https://bio.libretexts.org/Bookshelves/Introductory_and_General_Biology/Biology_(Kimball)/17:_Ecology/17.01:_Energy_Flow_through_the_Biosphere/17.1C:_Biomes>)) |

Pattern so far: the odd biomes are defined by one or two hero silhouettes standing in a mat of low growth.

## Biome Templates

The full real-world biome list (about 59 types) stays largely intact rather than consolidated into broad shared templates — each biome is distinct enough visually (see Biome Sizing below, and per the goal of every biome feeling special) to earn its own template. Only genuinely near-identical biomes are merged; caves are pulled out into their own system entirely rather than folded into surface-barren terrain.

**Polar/cold**

- Ice sheet + Polar desert — merged, near-identical near-zero-life template
- Tundra — own template, latitude-driven
- Alpine tundra — own template, altitude-driven, same vegetation profile as tundra but distinct placement
- Forest-tundra + Krummholz — merged, stunted tree-line template, arctic vs mountain variant

**Forest**

- Taiga + Coniferous forest — merged, shared conifer species pool
- Temperate deciduous + Mixed forest — merged, shared broadleaf/conifer pool
- Temperate rainforest — own template, dense moss/epiphyte look
- Montane forest + Cloud forest — merged, cloud forest raises moisture and epiphyte density

**Grass & scrub**

- Tallgrass prairie — own template, tall dense grass, no shrub
- Shortgrass prairie — own template, shorter grass, no shrub
- Steppe — own template, dry grass with scattered shrubs
- Sagebrush shrubland — own template, treeless shrub
- Mediterranean scrub — own template, rocky terrain with a sparse small-tree layer
- Thorn scrub — own template, dry thorny shrub, tropical-adjacent

**High-altitude grass/shrub**

- Páramo — own template, frailejón rosettes, wet
- Puna — own template, drier cousin of páramo
- Alpine meadow — own template, wildflower grass, seasonal

**Desert**

- Cold desert — own template, sparse shrub, cold nights
- Hot desert — own template, cacti-heavy, hot

**Tropical**

- Tropical rainforest — own template
- Jungle — own template, denser understory than rainforest canopy
- Tropical dry forest — own template, deciduous in dry season
- Savanna — own template, scattered acacia over grass

**Wetlands**

- Swamp — own template, standing water plus trees
- Bayou — merged with swamp, same cypress-tupelo look
- Floodplain forest — own template, seasonal flooding
- Freshwater marsh — own template, flat grassy open water
- Wet meadow — own template, grassy, less standing water than marsh
- Salt marsh — own template, salt-tolerant grass species
- Bog — own template, peat, closed rain-fed basin
- Fen — own template, groundwater-fed, less acidic than bog

**Coastal**

- Beach — own template
- Dunes — own template, distinct dune-grass silhouette
- Rocky shore — own template
- Maritime forest — own template, wind-shaped coastal trees
- Mangrove — own template
- Estuary/delta — own template, brackish channel network
- Lagoon — own template, calm brackish pool

**Freshwater**

- Rivers, lakes, ponds, oxbow lakes — folded into the moisture-gradient placement system rather than separate templates
- Oasis — own template, distinct desert-water combination

**Ocean**

- Shelf sea, coral reef, kelp forest, open/deep ocean, sea ice — each its own template, mostly visual dressing
- Atlantis-style underwater cave temple entrances — hand-placed special locations, not procedurally generated

**Special/barren terrain**

- Volcanic fields — own template
- Badlands — own template
- Canyons — own template
- Salt flats — own template, gypsum-tolerant species
- Hot springs — own template, thermophile flourish

**Glaciers**

- Glaciers — own template, distinct from ice sheet

**Caves**

- Karst/caves — pulled out entirely into its own underground system (see Cave System), sharing surface species-table logic but fed depth/moisture/mineral inputs instead of surface temperature/moisture

This brings the \~59 real-world biomes down to about 52 actual proc-gen content templates, plus a small number of hand-authored special locations.

## Biome Sizing

The planet is 1/100th of Earth's circumference (about 400 kilometers around), so linear distances scale by 1/100th — meaning area scales by 1/10,000, the square of the linear factor. Each biome's typical real-world area is scaled down by that factor and treated as a rough circle to get a walk-across time at a normal 4.5 kilometers per hour walking pace. This makes biome size and rarity fall out of real geography for free: biomes that are vast on Earth stay vast and common, and biomes that are naturally rare and small on Earth become rare, small landmarks in-game.

Vast biomes, five and a half to nine hours to walk across: taiga, hot desert, tropical rainforest, tundra, and savanna.

Mid-size biomes, roughly three to four hours: temperate deciduous and mixed forest, ice sheet and polar desert, cold desert, and prairie and steppe.

Small specialty pockets, under forty minutes and many under five: sagebrush shrubland, Mediterranean scrub, cloud and montane forest, krummholz, alpine meadow, swamp and bayou, páramo and puna, mangrove, freshwater marsh, bog and fen, badlands, salt marsh, salt flats, karst and cave regions, volcanic fields, dune fields, beaches, oases, and hot springs.

For scale, circling the entire planet on foot nonstop comes out to roughly 89 hours, or about 11 days at a realistic 8-hour walking day.

## Creature Spawning

Three generation passes stack in order: terrain generates first, vegetation reads the terrain and places itself, then creatures read both terrain and vegetation to decide what spawns where. Creatures check habitat conditions directly rather than just a biome label, the same way vegetation reads climate rather than biome names.

**Habitat roles**

- **Canopy dwellers** (squirrels, possums, tree-dwelling birds): require canopy- or emergent-tier vegetation within range, and attach to a specific tree instance rather than a patch of ground — similar to how epiphytes attach to host trees.
- **Ground dwellers** (raccoons, ground mammals): key off ground-cover density and proximity to water.
- **Water's edge / aerial** (wading birds, waterfowl): key off marsh/shoreline presence and open water; split by species sub-type since needs vary widely within birds.

Each creature species profile combines a habitat role, required tier/water/ground-cover conditions, and a broad biome-level climate filter — mirroring the vegetation species record structure.

**Spawn trigger tiers**

1. **Interaction-triggered** (insects, small hidden detail): nothing spawns until the player is within roughly one to two meters and actively interacting with or closely examining a qualifying object, such as turning over a fallen log flagged as harboring insects. Keeps hidden detail effectively infinite without simulation cost.
2. **Ambient proximity** (common wildlife): always active in the world, roughly one creature per 20 to 40 meter radius for common species, sparse enough that finding one feels like a small discovery and supports sound-sourced exploration. Rarer, larger creatures use a much wider radius, roughly one per couple hundred meters.
3. **Long-range aware** (mythical/apex creatures): not a spawn-radius question but an AI behavior state — dormant and unspawned at long range, aware and pacing at medium range, visible and stalking at close range.

**Pack hunters** (for example Arctic wolves in snowy biomes): tethered to a den or lair anchor point, ideally a cave mouth where terrain intersects the cave system, and patrol or hunt within a radius of that home point before retreating back. Supports long-range howling call-and-response between pack members, then coordinated closing-in behavior once the player is located.

**Mythical creatures** (one archetype per biome, for example desert skinwalkers): an extension of the same spawn-table system with much lower spawn weight and a temperament flag, hostile, neutral, or friendly, so they coexist with ambient wildlife rather than replacing it. The bigger cost is per-creature content, unique model, behavior, and sound, rather than the spawning logic itself. Long-range audio cue is deliberately low-fidelity and poorly-directional at distance, sharpening in fidelity and stereo positioning as the player approaches its territory.

*Checks-and-balances between creatures, such as predator and prey reactions, are a noted future layer — creatures are independent of each other for now.*

## Weather System

Weather is a real, causal simulation with its own internal rules — not scripted per biome, and not literal real-world atmospheric physics. It is simplified enough to run cheaply, but genuinely drives the world: biome classification itself is an output of long-term simulated weather rather than a fixed input, mirroring how real-world Köppen climate zones are defined by long-term temperature and precipitation averages rather than assigned directly.

**Generation order changes**

1. Terrain generates first (shapes that steer wind and pressure: mountains, oceans, elevation).
2. The coarse weather simulation runs across that terrain for a long stretch of simulated time to reach stable long-term averages per region.
3. Biomes are classified from those averaged temperature and moisture results, Köppen-style, rather than from a fixed latitude/altitude formula alone.
4. Vegetation and creatures generate exactly as already designed, reading the now weather-derived climate data.
5. Once the player is in the world, the same simulation keeps running, so live weather is that ongoing simulation, not a separate effects layer.

**The weather grid**

A second, much coarser grid sits on top of the terrain grid — on the order of a few hundred cells for the whole cube-sphere planet, not one cell per terrain tile. Each cell stores three values: pressure, temperature, and moisture.

**The core rule set** (the planet's own physics, not Earth's):

- Wind direction and speed in a cell are derived purely from the pressure difference between that cell and its neighbors: air moves from high pressure toward low pressure. This one rule is the entire wind system.
- Each simulation tick, a cell's temperature and moisture are advected along its wind vector into neighboring cells, so warm, wet air visibly drifts across the planet over in-game hours, the way fronts move on Earth.
- A broad prevailing-wind bias by latitude (winds trending one general direction near the equator, another near the poles) is layered in cheaply for a jet-stream feel, without simulating real Coriolis physics.
- Storms are not a separate scripted system — a cell is flagged as stormy purely as an emergent label whenever its pressure drops and its moisture rises past a set threshold together. Storms dissipate naturally as they drift into drier or higher-pressure neighboring cells.
- Clear skies emerge the same way, automatically, wherever a cell sits at high pressure with low moisture.

**Precipitation type** is temperature-gated off the same cell data: moisture crossing the storm threshold produces rain above freezing and snow below it, so snowy biomes naturally get snow instead of rain with no separate rule needed.

**Physical expression**

- Every terrain cell inherits wind direction and speed from its parent coarse weather cell.
- That wind value drives foliage animation directly: leaves, grass, and any cloth-like elements sway and rustle in response to local wind speed and direction.
- Rain and snow render as particle systems whose intensity reads the local cell's moisture/storm state; wind strength also drives the particles' drift angle, so rain visibly blows sideways during a storm rather than falling straight down.

**Seeded randomness**

Each new world seeds the weather grid's starting pressure, temperature, and moisture values (plus initial wind vectors) from the world seed, the same way terrain generation is seeded. The rules themselves never change between worlds — air always flows high to low pressure, storms always need the same pressure/moisture threshold — but because the system is causally chaotic, small differences in starting conditions cascade into completely different storm timing and placement over the following in-game days. This gives genuine, non-scripted unpredictability (no world always storms on day two at three o'clock) as a natural consequence of simulating a sensitive system from a random starting state, rather than randomness bolted on top of fixed events.

*This is a working summary — expect it to grow and get edited as more of the design gets locked in.*
