# Creature data

`creatures.json` lists every creature species. Like plants, creatures check
habitat directly (climate, trees, ground cover, water), not biome names.
Edit or add entries; changes apply the next time you run the game.

| Field | Meaning |
|---|---|
| `name` | Unique name. |
| `role` | `canopy` (lives on a specific tree), `ground`, `water_edge` (shore or open water), `swarm` (fireflies etc.), `insect` (hidden until you inspect a log), `pack` (den-tethered pack hunters), `mythical`. |
| `body` | Placeholder model: `quadruped`, `rodent`, `deer`, `tortoise`, `bird`, `wader`, `duck`, `frog`, `swarm`, `beetle`. Mythical creatures use `shape` instead. |
| `spawn` | `ambient` (around you all the time, spaced by `one_per_radius_m`), `interaction` (only when you inspect something), `long_range` (mythical: dormant far away, aware at mid range, visible close). |
| `temp_c` | Mean annual temperature range, °C. |
| `moisture` | 0-1 effective moisture range. |
| `altitude_m` | Optional elevation range in real-world meters (scaled by `PlanetConst.HEIGHT_SCALE`, 1/10, at load). |
| `active` | `day`, `night`, `any`, or `full_moon` (night, and only when the moon is at least 85% lit: werewolves). |
| `one_per_radius_m` | Ambient density: about one creature per circle of this radius (20-40 m common, a few hundred rare). |
| `needs` | Optional: `ground_cover` (0-1 minimum undergrowth density), `water_within_m`, `shore` (wading depth), `open_water`, `salt` (brackish/salt water). |
| `size_m`, `color`, `accent`, `speed_mps` | Placeholder body size, colors, speed. |
| `shy_m` | Flees when you come this close (0 = never). |
| `sound` | `chirp`, `call`, `croak`, `howl`, `drone`, `whisper` or `none` (synthesized placeholders). |
| `pack` | For `role: pack`: `size` [min, max], `den` (`cave_mouth`: steep cold slopes, where the cave system will meet the surface), `territory_m`, `notice_m`. |
| `temperament` | For mythical creatures: `hostile` (stalks at a distance), `neutral` (watches you), `friendly` (comes over). None of them attack; there is no combat. |
| `territory_m` | Mythical territory size. |
| `shape` | Mythical silhouette: `stalker`, `wisp`, `troll`, `witch`, `goblin`, `unicorn` (glowing horn; leaves glowing hoofprints), `werewolf`. |
| `rarity` | Mythical: weight when a territory picks among the species whose climate fits (default 1; unicorns 0.3, werewolves 0.5). |
| `campfire` | Mythical folk "at rest": a campfire with a warm light at their camp. |
