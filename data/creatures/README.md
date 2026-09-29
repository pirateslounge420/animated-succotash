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
| `body` | Placeholder model: `quadruped`, `wolf`, `rodent`, `deer`, `tortoise`, `bird`, `wader`, `duck`, `frog`, `swarm`, `beetle`, `shark` (afloat: body under the water, dorsal fin and tail cutting the surface). Mythical creatures use `shape` instead. `wolf`, `deer` and the `goblin` shape are sculpted single meshes (SculptedBodies); the rest are still assembled from primitives. |
| `spawn` | `ambient` (around you all the time, spaced by `one_per_radius_m`), `interaction` (only when you inspect something), `long_range` (mythical: dormant far away, aware at mid range, visible close), `disabled` (never appears in normal play: no spawner or territory picks it, and it doesn't change the odds for the others; only a debug spawn shows it. The Night Rider and the Pond Crawler are `disabled` until Phase 7, when creatures start spawning). |
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
| `temperament` | For mythical creatures: `hostile` (stalks at a distance, fights back if shot; werewolves close in and attack), `neutral` (watches you), `friendly` (comes over). Neutral and friendly ones vanish when shot. `aggressive` (spec D4): comes for you, and has a `bite` by default like `hostile`; the Night Rider's and the Pond Crawler's own code decides how (see below). D4's other values, `skittish` and `pack`, aren't used yet. |
| `hp` | Hit points (default by size: small game ~6-15, a deer ~40, mythical 30 + 30 × size_m). |
| `hit_parts` | Where a hit lands and what it does. The file's top-level `hit_parts` block is every species' default; an entry's own `hit_parts` overrides any of its keys (the tortoise: `{"body": 0.4}`, its shell). `body`, `head`, `eye`, `limb`: what a hit on that part multiplies the damage by (defaults 1, 2, 4, 1; head and eye hits are criticals, data/combat.json). `limb_slow`: the share of its speed an animal keeps after each limb hit (0.5), and it limps; `limb_slow_floor`: never slower than this share (0.25). `eye_blinds`: an eye hit blinds that side, so it notices you there late (true). Camp folk use the top-level block. |
| `charge_m` | Unprovoked: it comes for you within this many metres (0 = only when hurt; packs and mythicals have their own rules) — the territorial charge of crocodiles, hippos and buffalo. Scaled by how loud you are (0.55× silent … 1.45× at full noise) and by 0.7 when you've been still for 2 s; a lit fire still turns it back. A creature that lives in the water (`needs.open_water`) charges only while you're swimming, never beaches itself, and idles at the shallows when you get out. |
| `bite` | Damage per bite or blow to the player (default 6 + 5 × size_m for pack hunters, hostile and aggressive creatures, else 0: it never attacks). |
| `territory_m` | Mythical territory size. |
| `shape` | Mythical silhouette: `stalker`, `wisp`, `troll`, `witch`, `goblin`, `unicorn` (glowing horn; leaves glowing hoofprints), `werewolf`, `night_rider` and `pond_crawler` (their own sculpted bodies and rigs: see below). |
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
| `biome_lock` | Mythic only: the biomes it belongs to, as a list of biome keys (the names in data/biomes, e.g. `["TAIGA"]` for boreal / taiga, `["SWAMP", "BOG"]`). Read today by the biome cue (below) and by the Pond Crawler, which keeps to them as it moves; later, territories are placed by it. |
| `water_bound` | `true`: it lives in the water and never leaves it (the Pond Crawler). |
| `herd_min`, `herd_max` | Group size. `2`, `2`: always a pair. |
| `rig` | Tunables for a creature with its own movement rig (the Pond Crawler, below). |

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
`data/dev.json`, press **F7** in the game (it spawns the Phase 1 rigs in
turn: Night Riders, Pond Crawler, gibbon): a pair rides across your view
about 30 m ahead, then patrols (at night, stay back or they come for you).
Their next turn sends that pair away and brings a new one. From code:
`NightRiderPair.debug_spawn(mythics, from, facing)`. To record them: `tools/night_rider_demo.gd` (run
instructions in its header).

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
(hood, body, upper arm, forearm, hand) and stick in it (the shared
`Hitboxes`), and you can't walk through it. `"spawn": "disabled"`: nothing places it in normal play
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

**Seeing one before Phase 7:**

- **In the game (dev mode):** F7 spawns the Phase 1 rigs in turn; on the
  crawler's turn it goes in the nearest water it can wade within 120 m
  (or the console says there is none).

- **Recording or stills:** `tools/pond_crawler_demo.gd` starts the game,
  finds swamp or bog water, makes it night and places a Pond Crawler (run
  instructions at the top of the file; `-- --play` drops you on the bank
  next to it to play).
- **From code:** `PondCrawler.debug_spawn(main.creatures, dir)` places one
  at surface direction `dir` (wadeable water, chunks loaded;
  `PondCrawler.find_pool()` finds a spot). Any creature can be handed to
  `CreatureSpawner.adopt()` to be ticked and shot at like the rest.
## The gibbon

The Gibbon entry (*Hylobates lar*, R3's gibbon-type monkey of the warm–hot
wet band) is its own creature, not one the spawner builds: a sculpted body
(GibbonBody) that brachiates along the trees' branch graphs (Gibbon). Its
`temp_c` and `moisture` are the tropical rainforest's climate
(data/biomes/19_tropical_rainforest.json), the one warm, wet biome with
branchy trees. It reads:

| Field | What the gibbon does with it |
| `color` | Its coat (sRGB). |
| `accent` | The pale ring round its face, its hands and feet. |
| `speed_mps` | How big a swing it cruises at: faster means longer leaps (3 m/s: about 55 degrees either side). |
| `spawn` | `disabled`: only `Gibbon.debug_spawn()` places one (in dev mode F7, on its turn, hangs one in the nearest rainforest tree within 200 m). |

`size_m` (head and body, 0.5 m) matches the sculpted body, which is built
at that size; `active`, `one_per_radius_m` and `shy_m` wait for Phase 7,
when gibbons start to spawn and notice the player.
