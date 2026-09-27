# Creature data

`creatures.json` lists every creature species. Like plants, creatures check
habitat directly (climate, trees, ground cover, water), not biome names.
Edit or add entries; changes apply the next time you run the game.

| Field | Meaning |
|---|---|
| `name` | Unique name, the one shown in the game. |
| `genus`, `species` | The binomial (spec D4), e.g. `"Canis"`, `"lupus"`. Real animals use their real name; mythical and other invented creatures get an invented binomial in the same style plus `"invented": true`. No entry is valid without them. |
| `invented` | `true` marks an invented binomial. Leave it out for real animals. |
| `role` | `canopy` (lives on a specific tree), `ground`, `water_edge` (shore or open water), `swarm` (fireflies etc.), `insect` (hidden until you inspect a log), `pack` (den-tethered pack hunters), `mythical`. |
| `body` | Placeholder model: `quadruped`, `wolf`, `rodent`, `deer`, `tortoise`, `bird`, `wader`, `duck`, `frog`, `swarm`, `beetle`. Mythical creatures use `shape` instead. `wolf`, `deer` and the `goblin` shape are sculpted single meshes (SculptedBodies); the rest are still assembled from primitives. `gibbon` is a sculpted body with its own brachiation rig (Gibbon; see "The gibbon" below). |
| `spawn` | `ambient` (around you all the time, spaced by `one_per_radius_m`), `interaction` (only when you inspect something), `long_range` (mythical: dormant far away, aware at mid range, visible close), `disabled` (never appears in normal play: no spawner or territory picks it; only a debug spawn places one. The Phase 1 rigs, the gibbon among them, are `disabled` until creatures start spawning in Phase 7). |
| `temp_c` | Mean annual temperature range, °C. |
| `moisture` | 0-1 effective moisture range. |
| `altitude_m` | Optional elevation range in real-world meters (scaled by `PlanetConst.HEIGHT_SCALE`, 1/10, at load). |
| `active` | `day`, `night`, `any`, or `full_moon` (night, and only when the moon is at least 85% lit: werewolves). |
| `one_per_radius_m` | Ambient density: about one creature per circle of this radius (20-40 m common, a few hundred rare). |
| `needs` | Optional: `ground_cover` (0-1 minimum undergrowth density), `water_within_m`, `shore` (wading depth), `open_water`, `salt` (brackish/salt water). |
| `size_m`, `color`, `accent`, `speed_mps` | Placeholder body size, colors, speed. |
| `shy_m` | Flees when you come this close (0 = never). |
| `sound` | `chirp`, `call`, `croak`, `howl`, `drone`, `whisper` or `none` (synthesized placeholders); `hoot` is the gibbon's own calls (GibbonHoot). |
| `pack` | For `role: pack`: `size` [min, max], `den` (`cave_mouth`: steep cold slopes, where the cave system will meet the surface), `territory_m`, `notice_m`. |
| `temperament` | For mythical creatures: `hostile` (stalks at a distance, fights back if shot; werewolves close in and attack), `neutral` (watches you), `friendly` (comes over). Neutral and friendly ones vanish when shot. |
| `hp` | Hit points (default by size: small game ~6-15, a deer ~40, mythical 30 + 30 × size_m). |
| `bite` | Damage per bite or blow to the player (default 6 + 5 × size_m for pack hunters and hostile creatures, else 0: it never attacks). |
| `territory_m` | Mythical territory size. |
| `shape` | Mythical silhouette: `stalker`, `wisp`, `troll`, `witch`, `goblin`, `unicorn` (glowing horn; leaves glowing hoofprints), `werewolf`. |
| `rarity` | Mythical: weight when a territory picks among the species whose climate fits (default 1; unicorns 0.3, werewolves 0.5). |
| `campfire` | Mythical folk "at rest": a campfire with a warm light at their camp. |

## The gibbon

The Gibbon entry (*Hylobates lar*, R3's gibbon-type monkey of the warm–hot
wet band) is its own creature, not one the spawner builds: a sculpted body
(GibbonBody) that brachiates along the trees' branch graphs (Gibbon). Its
`temp_c` and `moisture` are the tropical rainforest's climate
(data/biomes/19_tropical_rainforest.json), the one warm, wet biome with
branchy trees. It reads:

| Field | What the gibbon does with it |
|---|---|
| `color` | Its coat (sRGB). |
| `accent` | The pale ring round its face, its hands and feet. |
| `speed_mps` | How big a swing it cruises at: faster means longer leaps (3 m/s: about 55 degrees either side). |
| `spawn` | `disabled`: only `Gibbon.debug_spawn()` places one. |

`size_m` (head and body, 0.5 m) matches the sculpted body, which is built
at that size; `active`, `one_per_radius_m` and `shy_m` wait for Phase 7,
when gibbons start to spawn and notice the player.
