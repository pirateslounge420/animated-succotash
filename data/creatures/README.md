# Creature data

`creatures.json` lists every creature species. Like plants, creatures check
habitat directly (climate, trees, ground cover, water), not biome names.
Edit or add entries; changes apply the next time you run the game.

| Field | Meaning |
|---|---|
| `name` | Unique name. |
| `genus`, `species` | Its Linnaean binomial: the genus capitalized, the species epithet lower case (`"genus": "Limnoreptor", "species": "cucullatus"`). Every entry needs both. The game doesn't read them yet. |
| `invented` | `true` for an organism that doesn't exist (the mythics): its binomial is invented too, in proper Linnaean form. Leave it out for real animals. |
| `role` | `canopy` (lives on a specific tree), `ground`, `water_edge` (shore or open water), `swarm` (fireflies etc.), `insect` (hidden until you inspect a log), `pack` (den-tethered pack hunters), `mythical`. |
| `body` | Placeholder model: `quadruped`, `wolf`, `rodent`, `deer`, `tortoise`, `bird`, `wader`, `duck`, `frog`, `swarm`, `beetle`. Mythical creatures use `shape` instead. `wolf`, `deer` and the `goblin` shape are sculpted single meshes (SculptedBodies); the rest are still assembled from primitives. |
| `spawn` | `ambient` (around you all the time, spaced by `one_per_radius_m`), `interaction` (only when you inspect something), `long_range` (mythical: dormant far away, aware at mid range, visible close), `disabled` (never appears in normal play: no spawner or territory picks it, and it doesn't change the odds for the others; only a debug spawn shows it, see "Placing one by hand" below. The Pond Crawler is `disabled` until Phase 7). |
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
| `temperament` | For mythical creatures: `hostile` (stalks at a distance, fights back if shot; werewolves close in and attack), `neutral` (watches you), `friendly` (comes over). Neutral and friendly ones vanish when shot. The spec's values (D4) are also accepted: `aggressive` gets a bite like `hostile`; `skittish` and `pack` are read but not yet used. |
| `hp` | Hit points (default by size: small game ~6-15, a deer ~40, mythical 30 + 30 × size_m). |
| `bite` | Damage per bite or blow to the player (default 6 + 5 × size_m for pack hunters and hostile or aggressive creatures, else 0: it never attacks). |
| `territory_m` | Mythical territory size. |
| `shape` | Mythical silhouette: `stalker`, `wisp`, `troll`, `witch`, `goblin`, `unicorn` (glowing horn; leaves glowing hoofprints), `werewolf`, `pond_crawler` (its own body and movement, PondCrawler). |
| `rarity` | Mythical: weight when a territory picks among the species whose climate fits (default 1; unicorns 0.3, werewolves 0.5). |
| `campfire` | Mythical folk "at rest": a campfire with a warm light at their camp. |

## Spec D4 fields (Phase 1 schema extension)

The spec's creature schema (docs/WORLD_SYSTEMS_SPEC.md D4) adds these.
They load now; the ecology ledger will read most of them. Old entries
without them work as before.

| Field | Meaning |
|---|---|
| `trophic` | Place in the food web: `insect`, `herbivore`, `small_pred`, `apex`, `scavenger`, `fish`, or `mythic` (one per biome). |
| `activity` | The spec's name for `active` (`day`, `night`, `dusk`); if both are given, `active` wins. `dusk` counts as `any` for now. |
| `biome_lock` | Mythic only: the biomes it lives in, by their keys in `data/biomes/` (e.g. `["SWAMP", "BOG"]`), instead of a climate window. A creature that moves on its own (the Pond Crawler) keeps to them. |
| `water_bound` | `true`: it lives in the water and never leaves it. |
| `light_response` | How it answers light (fire, torches). The spec doesn't list values yet; it's read as text and nothing uses it. |
| `rig` | Tunables for a creature with its own movement (the Pond Crawler, below). |

## Pond Crawler

*Limnoreptor cucullatus* (invented: "hooded pond-creeper"). A mythic of
swamp and bog water, out at night: a rounded hooded lump with one large
blue slit eye (`accent` #2A6AFF, a real light) deep under the hood's
brim, wading on two long arms with splayed fingers. It waits motionless
in the water, now and then lifting and re-planting a hand; when you come
close it lurches at you, arm over arm, and strikes at close range. It
never leaves the water: where the water ends, it stops at the edge. Each
hand that breaks the water makes a ripple and a soft wet sound; the
body's drift leaves a wide wake. Arrows hit the part they visibly meet
(hood, body, upper arm, forearm, hand) and stick in it, and you can't
walk through it. `"spawn": "disabled"`: nothing places it in normal play
until Phase 7.

Its `rig` numbers:

| Rig field | Meaning |
|---|---|
| `notice_m` | Lurches when you come this close, scaled by your noise like wolf packs (still: about half; walking: 0.9x; sprinting: 1.55x). |
| `strike_m` | Strikes (a hand slams down where you stand, `bite` damage) within this reach. |
| `wait_step_s`, `stride_m`, `lift_m` | A slow step or re-plant: its time, stride and how high the hand clears the water. |
| `lurch_step_s`, `lurch_overlap`, `lurch_lift_m` | Lurching: one hand's swing time; the next hand lifts when the swing is this far along (0-1: lower means the plants, and their rings, overlap more); how high the hands come up. The stride follows from `speed_mps`. |
| `body_kg`, `hand_kg` | Masses the ripples are sized by (the body's wake, each hand's plant). |
| `wade_m` | [min, max] water depth it can wade in; it never goes where the water is shallower or deeper. |
| `eye_light_m`, `eye_light_energy` | The eye's light: range and strength. |
| `drift_every_s`, `replant_every_s` | [min, max] seconds between a slow move to another spot nearby, and between re-plants while it waits. |

## Placing one by hand (debug)

Species with `"spawn": "disabled"` never appear on their own. There is no
key for the Pond Crawler yet: dev mode's F7 (`dev_spawn`) will place it
once the Phase 1 rigs share that key. Until then:

- **Recording or stills:** `tools/pond_crawler_demo.gd` starts the game,
  finds swamp or bog water, makes it night and places a Pond Crawler (run
  instructions at the top of the file; `-- --play` drops you on the bank
  next to it to play).
- **From code:** `PondCrawler.debug_spawn(main.creatures, dir)` places one
  at surface direction `dir` (wadeable water, chunks loaded;
  `PondCrawler.find_pool()` finds a spot). Any creature can be handed to
  `CreatureSpawner.adopt()` to be ticked and shot at like the rest.
