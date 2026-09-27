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
| `body` | Placeholder model: `quadruped`, `wolf`, `rodent`, `deer`, `tortoise`, `bird`, `wader`, `duck`, `frog`, `swarm`, `beetle`. Mythical creatures use `shape` instead. `wolf`, `deer` and the `goblin` shape are sculpted single meshes (SculptedBodies); the rest are still assembled from primitives. |
| `spawn` | `ambient` (around you all the time, spaced by `one_per_radius_m`), `interaction` (only when you inspect something), `long_range` (mythical: dormant far away, aware at mid range, visible close), `disabled` (never appears in normal play: no spawner or territory picks it, and it doesn't change the odds for the others; only a debug spawn shows it. The Night Rider is `disabled` until Phase 7, when creatures start spawning). |
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
| `temperament` | For mythical creatures: `hostile` (stalks at a distance, fights back if shot; werewolves close in and attack), `neutral` (watches you), `friendly` (comes over). Neutral and friendly ones vanish when shot. `aggressive` (spec D4): comes for you, and has a `bite` by default like `hostile`; the Night Rider's own code decides how (see below). D4's other values, `skittish` and `pack`, aren't used yet. |
| `hp` | Hit points (default by size: small game ~6-15, a deer ~40, mythical 30 + 30 × size_m). |
| `bite` | Damage per bite or blow to the player (default 6 + 5 × size_m for pack hunters, hostile and aggressive creatures, else 0: it never attacks). |
| `territory_m` | Mythical territory size. |
| `shape` | Mythical silhouette: `stalker`, `wisp`, `troll`, `witch`, `goblin`, `unicorn` (glowing horn; leaves glowing hoofprints), `werewolf`, `night_rider` (its own sculpted body and rig: see below). |
| `rarity` | Mythical: weight when a territory picks among the species whose climate fits (default 1; unicorns 0.3, werewolves 0.5). |
| `campfire` | Mythical folk "at rest": a campfire with a warm light at their camp. |

## Spec D4 fields

The world spec's creature schema (docs/WORLD_SYSTEMS_SPEC.md, D4) adds
these. Entries without them work as before. Most are read by later phases
(the ecology ledger); what reads each one today is noted.

| Field | Meaning |
|---|---|
| `trophic` | Place in the food web: `insect`, `herbivore`, `small_pred`, `apex`, `scavenger`, `fish`, or `mythic`. Not read yet (the ecology ledger). |
| `activity` | D4's name for when it's out: `day`, `night` or `dusk`. If an entry has `activity` and no `active`, `activity` sets `active` (so `night` works today; `dusk` isn't understood yet and counts as any time). |
| `temperament` | D4 values: `friendly`, `skittish`, `aggressive`, `pack` (see the table above for what's used). |
| `light_response` | How it reacts to light (a torch, a campfire): `none` ignores it. Nothing reads it yet; other values are to be decided. |
| `biome_lock` | Mythic only: the biomes it belongs to, as a list of biome keys (the names in data/biomes, e.g. `["TAIGA"]` for boreal / taiga). Read today by the biome cue (below); later, territories are placed by it. |
| `herd_min`, `herd_max` | Group size. `2`, `2`: always a pair. |

## Night rider

Two riders on dark horses, always a pair, in the boreal forest (taiga) at
night: *Nyctequus gemellus* (invented). `spawn: disabled` keeps them out of
normal play until Phase 7, when creatures start spawning: no spawner or
territory picks them, and the other mythicals' territories are exactly as
before (every territory on the dev stamp hashes the same with and without
the entry). Code: `scripts/creatures/mythics/`.

| Field | Meaning |
|---|---|
| `palette` | Body colors (sRGB): `coat` (horse), `mane` (mane, tail, the hair over the hooves), `hoof`, `cloak`, `hood` (the void where the rider's face would be), `glove` (gloves and boots). Deep ultramarine and indigo, each at or above the night sky's darkest, #0A14A0 (spec R1a: nothing pure black). `accent` is the eyes' glow (#FF2A2A), the only light on them. |
| `look` | How they read at night, "lit only by blue sheen": `night_shade` (0-1: how much of the world's night light reaches them; lower is darker, the palette itself is unchanged and by day they're lit like anything else), `sheen` (the color of the cold sheen on their edges and on what faces the sky, streaky like the textures), `sheen_amount` (its strength; 0 = none). |
| `speed_mps` | Walking speed. They only ever walk. |
| `pair` | `trail_body_lengths`: the follower rides this many horse lengths behind the leader (nose to nose; a horse is ~2.55 m); `phase_offset`: how far out of step its gait is (fraction of a stride), so the hoofbeats never fall together. |
| `gait` | The four-beat walk: `stride_m` (distance per stride at walking speed), `stance` (share of the stride a hoof is on the ground), `lift_m` (how high a hoof lifts), `turn_radius_m` (the tightest circle it can walk: heavy, slow to turn), `accel_mps2` (how fast it gets going or stops), `head_dip_deg` (the head's dip as each fore hoof lands), `bob_m` (the body's bob). |
| `hunt` | `notice_m` (at night it comes for you within this, more if you're loud), `give_up_m`, `reach_m` (strikes when you're this close to a horse), `strike_s` (seconds between blows; the damage is `bite`). |
| `cue` | The biome cue: `sound` (`hoofbeats_far`: a pair walking somewhere off in the forest), `when` (`enter_biome`: on walking into a `biome_lock` biome during its `activity` hours, or when those hours begin while you're there), `distance_m` [min, max] (how far off it's heard, in the direction the biome runs deepest; it moves across as they walk), `cooldown_s` (not again sooner). The cue plays in normal play now; the riders themselves don't. |

**Seeing them before Phase 7 (dev mode):** with `dev_mode` on in
`data/dev.json`, press **F7** in the game: a pair rides across your view
about 30 m ahead, then patrols (at night, stay back or they come for you).
F7 again sends that pair away and brings a new one. From code (tools, the
shared dev-spawn key once it lands): `NightRiderPair.debug_spawn(mythics,
from, facing)`. To record them: `tools/night_rider_demo.gd` (run
instructions in its header).
