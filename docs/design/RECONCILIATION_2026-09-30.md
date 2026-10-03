# Design reconciliation — 30 Sept 2026: the ambient cut

Decisions from the 30 Sept design session (chat and voice, after the designer's play on the
29th and a long look at the reference frames in `docs/references/`). Read
`RECONCILIATION_2026-09-27.md` first for everything not mentioned here; **where this doc
contradicts it, this doc wins.** Section letters continue from §AS so a "§BA" reference is
unambiguous across both files.

Data added with this doc (all additive — the game runs unchanged until the code reads them):
`data/movement.json → profile, profiles` · `data/torch.json` · `data/fuel.json` ·
`data/dread.json` · `data/look.json → ambient_floor` · `data/roads.json` · `data/rooms.json`
· `data/water/current.json` · `data/travellers.json` · `data/stand.json → dominance` ·
`data/hud.json → log` · `data/camps.json → wake_at_home` · `data/items.json → torch kind,
starting_kit_ambient` · `data/audio.json → new kinds`. Added 1 Oct with §BV–§BZ:
`data/camps.json → sim.opening, sim.jobs, sim.store.pieces` · `data/roads.json →
desire_lines, lost_and_found, opening_road` · `data/look.json → fire` · `data/audio.json →
fire`. Added 1 Oct afternoon with §CA–§CB: `data/habitat.json` · `data/dev.json → pin_in_play, spawn_choice -1` · `data/camps.json → first_camp`. With §CD: the resurrection fern's `desiccation` block. With §CE: `habitat.json → always_present, trim.always_keep, vine`, `data/vines.json`. With §CK–§CM (1 Oct, night): `data/landforms.json` (gate `tools/landforms_check.py`) · `data/uniques.json` · the sacred fig, two rhododendrons and two desert ferns in the biome files, two rhododendron associations, ferns in three associations · `habitat.json → always_present.rhododendron` · `items.json → mad_honey`.

---

## Thesis (30 Sept 2026) — revised

**This game is about a world, and moving through it slowly enough to see it.** Forgotten
things — roads, bridges, ruins — being rediscovered, overgrown and crumbling; a fire that
is the reason the group exists; a dark that is dangerous. The test for a feature is now:
*does it make the world feel older, quieter, more alive, or more worth walking? If not, it
does not go in.* The 27 Sept thesis ("movement that feels good") is not wrong — it is the
thesis of the **other** game (§AT).

Mike's words for it: Y2K-era discovery, the web before the index, when you got somewhere
because someone's dead page linked to it; backrooms; alive but forgotten; each place its own
room; a hearth like Virtual Villagers'; waking with nothing like Minecraft.

## AT. Two games — LOCKED

The project has grown three or four games. It is now two:

1. **This repo: the ambient open world.** Slow, first person, empty-handed. Everything in
   this doc.
2. **The ninja game (separate project, repo to be made).** The momentum kit and everything
   built on it: the 120 km/h chain and asymmetric gravity (§J), committed airborne momentum
   (§R), wall jump / bounce / swing / roll / sprint slide (§A, §Z), the super meter (§S),
   momentum combat (§K), the charge rule as a *combat* rule (§N), the bow and spear as a
   starting kit (§M, §T), the master shinobi (§O), the enemy shinobi camp (§Q), the opening
   flight of watchers (§P beats 2–3), the speedometer as a skill readout (§L), third person
   and its head-look/cloak rig (§B), PvP someday. Third or first person, its choice.

**Nothing is deleted.** Everything that leaves goes behind `movement.profile` (§AU) and
stays compiling and tested, so the ninja project can lift it whole. "Keep the code, set it
aside." The bow and spear remain as **items that can be found in ruins** (§AW) — a real
event, later — so `bow.gd`, `spear.gd`, `fists.gd`, `arrow.gd` and the §N charge rule stay
live code paths.

Planet, biomes, plants, ecology, weather, the water cycle, day/night and seasons, camps,
ruins, folk, tree climbing (slow), the look (§C, §AG, §Y), the pocket-watch clock (§AQ):
all stay here, unchanged unless a section below says otherwise.

## AU. Movement — the ambient profile — LOCKED

`data/movement.json` gains `"profile": "ambient"` and a `profiles` block. **The base table
is the shinobi table and is untouched**; `profiles.ambient` is a deep-merge of overrides
applied at load (`PlanetPlayer` reads `profile`, merges `profiles[profile]` over the base,
then everything else reads as before). `profiles.shinobi` is empty on purpose.

The ambient profile:
- **Walk 4.3 m/s, sprint 5.6** — Minecraft's numbers, the feel Mike keeps naming. Current
  5.5 / 8.8 is faster than Minecraft's *sprint*. Sneak 0.8 and swim 1.6 unchanged.
- **Symmetric gravity 20 m/s² up and down; jump 6.3 m/s (≈1.0 m).** A hop onto a rock or a
  fallen log — never a branch. No sprint-jump bonus, no fast fall. Air steering stays off.
- **Off (`enabled: false`, and `PlanetPlayer` must honour it):** wall jump, cling, branch
  bounce, swing, the redirect/momentum keep, the roll as a tech (Shift is sneak only), the
  sprint slide, the super meter. Space jumps; right click interacts and starts a tree
  climb; nothing else on those buttons.
- **Kept:** tree climbing (`climb`) — slow, two hands, the way up to a lookout; handholds;
  burden; footsteps; fall damage (a 1 m hop cannot hurt you; a cliff can).
- **Speedometer unpinned by default** in this profile (`hud.json` `pins`): walking never
  lights it. The clock stays. §L is superseded to that extent.

Why: the corridor/room structure (§BB) only works if you cannot hop the walls; a summit is
only a payoff if the climb cost something (Mike: "way too easy to get to the top of a
mountain"); and at walking pace the streaming has time, so the leaf cards and shadows stop
popping. The momentum chain in this world reads as the wrong game.

## AV. First person only — LOCKED

The third-person camera is off in the ambient profile (kept for the ninja game). §A's
clean-first-person rule stands: nothing in view but what is equipped — the torch (§AW), and
later a found spear or bow. The §B head-look rig and the landing/cloak animation now only
ever read on **other figures**: folk at camps and travellers on the road (§BF). That makes
the travellers the thing you study.

## AW. Start with nothing — the torch is the first tool — LOCKED

Supersedes §M and the 29 Sept "folk's gifts" for this profile: **you wake with nothing, and
nothing is laid beside you.** `items.json → starting_kit_ambient` is empty of tools;
`main._lay_gifts()` reads it when the profile is ambient (the shinobi kit stays for that
profile). Camps have what a camp would have: a lit fire, folk, **a bundle of unlit torches
by the fire** (`starting_kit_ambient.by_the_fire`), food. **No chests at camps** — random
loot at the spawn trains the player to check containers instead of reading the land
(considered and rejected today). Rare finds — a spear, a bow, whatever else — live in
**ruins**, found by going off the road (§BC). Not built yet; the item kinds stay.

**The torch** (`data/torch.json`; §T's "the torch is not a tool" paragraph stands and is now
the thing being built):
- Carried in **one hand**, drawn in first person like any equipped thing. Right click a
  torch bundle to take one (they are carried things, `burden` applies).
- **Unlit until you hold it to a flame** — a lit campfire, a planted torch, another
  carrier's torch. Right click the fire with the torch in hand: the lighting ritual. The
  fire is the source of everything.
- **Burns about one night** (`burn_min` 50 real minutes ≈ the 48-minute equatorial night)
  then gutters (`gutter_share` the last 12 %: dimmer, flickers harder) and goes out. Rain
  shortens it (`rain_burn_scale`), wind flickers it, **water douses it** (swim or wade past
  `douse_depth_m`). Sprinting doubles the flicker. A burnt-out torch is a stick (drop it).
- **Light:** a point light with Minecraft-style falloff — bright core, gradient out to
  `range_m`, warm colour, a slow flicker (`flicker_hz`, `flicker_amount`). The **only warm
  light in the world is fire** (§BB), so a torch reads from a long way off in the blue.
- **Plant it** (right click the ground with it lit): stands in the ground, burns at the
  same rate, lights the spot. Take it back with right click. A planted torch also counts as
  a light source for §BA (weaker than a fire, same as held).
- **Both hands to climb:** starting a tree climb or a cling with a lit torch plants it if
  the ground is there, otherwise puts it out (stowing puts it out; it must be relit at a
  flame). A dropped lit torch keeps burning on the ground.
- Creature response to torchlight already exists (`creature_species.gd` light response);
  the torch now actually emits it.

## AX. Fire is fuel — the hearth economy — LOCKED

Every campfire has a **fuel store that burns down** (`data/fuel.json → fire`): full → flames
→ low → **embers** → out. Embers relight from a torch or by adding dry fuel; a **dead fire
needs a lit torch** brought from another flame (no friction fire for now — keep scope).
Fuel comes from the world: **dead wood** (already generated: `dead_wood.gd`, the litter
field), gathered by hand (right click, carried, `burden` rules), **dropped onto the fire**
(right click the fire with fuel in hand). Kinds and yields per `fuel.json → kinds`:
hardwood logs burn long; softwood medium; scrub/brush fast and hot (a desert fire is fed
constantly); reeds and grass a flash; **dung** slow and smoky (the treeless places — prairie,
steppe, tundra, desert — from the herbivores that live there); peat (bog) slow. Wet fuel
(rain) burns badly. `fuel.json → biomes` says what each biome offers.

**Camp viability is emergent from where the camp sits**, not a difficulty setting. A camp
among old growth or on a river bank keeps its fire; a camp at a ruin in a place without fuel
**can die**. Doomed camps are a legitimate outcome — settlements grow around resources, as
in life. Folk tending the fire (gathering, feeding it) is §BJ, an open brainstorm; until it
exists, a camp's fire burns at a slow "tended" rate (`fire.tended_burn_scale`) while folk
are alive at it, and the player's own fires burn at full rate.

The fire is **the hearth** — safe zone (§0), rest-and-eat healing (§0), the torch's source
(§AW), the respawn (§AY), trade (§BI), the thing the group orbits.

## AY. Hearth respawn — set your home camp — LOCKED

On death you **wake at your hearth**. The first hearth is the opening camp. **Any camp you
discover** (a lit fire at an inhabited ruin, §AO) can be made your hearth: right click its
fire → "Make this your hearth". `camps.json → wake_at_home` true supersedes `wake_random`
for the ambient profile. Death costs nothing else: what you carried stays where you fell
(`player_corpse.gd` already does this) — go and get it if you want it. The walk is the
price; the fire is safe.

## AZ. The log — LOCKED

**Enter** opens a log panel, Minecraft-chat style, in the internal 480-line frame (§Y):
newest at the bottom, each line **stamped in game time** from the clock (`hud.json → log`).
Events: **deaths with the cause** ("Taken by the dark — 03:40", "Fell — 21:12", "Drowned",
"Killed by a werewolf"), torch lit / guttering / out, fire lit / embers / out, hearth set,
camp found, biome first entered, dawn and dusk. A text box at the bottom lets you **type a
note** (stamped like everything else). Esc closes. Persists per world. No other chat, no
commands.

## BA. Night is dangerous — the dark closes in — LOCKED

Between camps at night, **exposure accumulates**. `data/dread.json`: a hidden meter (no
HUD bar — you read it in the world). Light holds it off: inside a lit fire's radius it
drains; a held or planted torch **slows** it (a torch is a delay, the fire is safety);
full darkness fills it fastest, moonlight a little slower. Reaching a lit fire drains it
over about a minute; dawn empties it.

**Stages — each audible before it is visible, multiple warnings, but you have to be
listening and know what you're listening for** (`dread.json → stages`):
0. quiet;
1. **the bed thins** — birds, frogs, insects stop (§BG);
2. **a sound behind you that stops when you stop** — a footfall, a breath, a branch;
3. **a shape at the edge of torchlight**, gone when you look;
4. **it follows in the open**, visible, keeping its distance, faster than you;
5. **it closes** — if the torch has guttered or gone out, or you are still far from a
   fire, it takes you. Log: "Taken by the dark".
Never a health-bar fight: it is a chase you lose by being in the dark too long. If the
danger is a fight, it is the ninja game; if it is dread, it is this one.

**A creature per biome, each with its own approach** — the existing mythical roster
(`data/creatures/creatures.json`, `role: mythical`) becomes the hunters; `dread.json →
hunters` maps biome → creature → pattern and speed: `pacer` (parallel at a distance,
faster than you — you cannot outrun it, only out-light it), `circler` (circles before it
closes; heard from changing bearings), `stalker` (only moves when you move; stops when you
stop), `waiter` (sits still on the road ahead; you walk into it). Werewolf (temperate
forest; full moon makes it faster), forest troll, marsh witch and pond crawler (swamp,
bog), desert skinwalker, mountain yeti, night rider (taiga) — speeds and patterns in data.
**No bestiary, no UI:** folklore is learned by play — that silence in the bog means one
thing and the same silence in the pines another. Never inside a fire's radius (§0 safe
zone). Frogs going quiet is the tell.

**Build order:** the meter, the stages, the sound cues and **one hunter** (the werewolf as
a pacer) first; the rest is data.

## BB. Outdoor rooms — corridor, threshold, reveal — LOCKED

From the reference frames (30-odd ozavry_ / morgath0 stills, `docs/references/`), one recipe:
- **a path leads you in** — cobbles, a game trail, a stream, a boardwalk: the hallway;
- **walls at eye level** — understory, trunks, boulders, tombstones, willow curtains, ruin
  walls: they cut the view at 2 m, not 20;
- **a ceiling** — branches overhead; the sky shows through a gap, not as the whole dome;
- **one feature per room** — a cabin, a well, a waterfall, an old tree; never three;
- **a threshold** you pass through — a gate, an arch, a bridge, a gap between trunks,
  stairs — then the **reveal**: the ridge, the valley, the sunset (the wizard on the ledge:
  a green tunnel, then the ground drops away);
- **warm light is fire only**; the only orange in a blue world is a window or a torch;
- **water lights the room at night** — every night frame glows from the stream up;
- **one creature per scene**, figures rare.

Generator (`data/rooms.json`): lay the **road network first** (§BC); rooms hang off it
where it widens — a ford, a clearing, a spring, a ruin. The **understory at 1–2.5 m**
(shrubs, the regeneration cohort that already exists) is what makes walls: bias it hard
along room edges and corridor sides, keep room floors open. The **sky-share** measure
from §AJ / `tools/look/measure_look.py` doubles as the room test: low share in most
directions and high in one is a room with a door. Fog stays close (§AG 5).

**The vista is kept** — it is the payoff of every corridor — but it is **earned** (no
hopping up, §AU) and **cheap** (terrain + impostors at range, 29 Sept "far trees as
pictures"). Rooms cut the view distance most of the time, which is the real frame-time win.

**Dark days do not mean dark skies.** Under the trees by day the shade is deep green and
readable — the §AG navy floor `#080C4A` applies by day too; the sky can blaze (the sunset
frame) while the ground stays moody. Black only where no sky is visible (§BD).

## BC. Roads — built by whoever left the ruins — LOCKED

A **trail/road network is a first-class world-gen layer**, laid before plants
(`data/roads.json`). Roads link ruins, camps, springs, fords and passes; they follow rivers
and contours; **rivers are the other road type**. Built by the people who left the ruins;
**nobody maintains them**: overgrown, rutted, a bridge out with **both stone abutments
standing** on either bank (decay is only haunting if you can still read what it was — the
player finishes the thought), a trail that just ends at a collapse, fallen waymarks, cairns,
standing stones. Overgrown, never illegible.

- **Landmarks at the ends.** The road gets you somewhere known; **off the road is where the
  finds are** — ruins, a hot spring, a standing stone, a lone old tree — set **just far
  enough off the trail that you have to choose to lose sight of it**. Risk buys discovery;
  night is what makes the choice cost something.
- **Forks are legible before you commit:** you can see the other road across the gorge,
  not find out an hour later.
- **One-way gates:** a ravine, a cliff, a river (downstream free, upstream a wall — §BE).
  Choose a path and the other may be unreachable without going round.
- Roads are the corridors of §BB. Travellers walk them (§BF). The §AG 7 "path/trail placer,
  Phase 9" is this.
- The "alive but forgotten" feeling in one line: the road is the world remembering
  someone.

## BD. The ambient floor follows the sky — LOCKED

Supersedes §C's hard ambient cut in one respect. **Ambient light at a point = the hour's
sky ambient × that point's sky visibility (0–1), never below a floor while any sky is
visible** (`look.json → ambient_floor`). Sky visibility comes from the canopy shade map
that already exists (the §AJ dapple stamp) plus enclosure (ruin interiors, caves: 0).

- **Night, outdoors:** mesopic — eyes adapted; a dim blue-grey lift, shapes readable,
  **colour gone** (desaturate toward `night_desaturate` at low luma), moon adds. Under a
  dense canopy at night: near black. **Inside a tomb: black — torch or nothing.** Mike:
  "if you go into a structure where literally no light penetrates, it should be pitch
  black unless you have a torch."
- **Day:** shade is deep green / navy (`#080C4A` floor), never black. The darkening stack
  — shadow map × dapple map × `canopy_dark` × ambient — **multiplies**; audit it. The
  floor is applied last.
- The sky-visibility number is the same one §BB uses for rooms. One calculation, two jobs.

**Regression to find** (Mike's play on the 29th vs the build before the leaf cards and
the ambient cut): at dusk the light read like sun; approaching any tree, the ground went
**black**; leaves looked **cruder** than the leaf-card build had. Suspects, in order: the
darkening stack above; the LOD split after the 29 Sept impostor and render-distance work
(cards swapped for pictures too near, or the near ring's card count cut); the leaf shadow
map on cards. Standing still it was worse than before, so it is not speed. Fix, then
compare against the moonlit-water build Mike liked.

## BE. Water has weight — current — LOCKED

Rivers and streams carry a **flow vector** from the hydrology pass (direction downstream,
speed from slope and volume; `data/water/current.json`). In water the player **drifts with
it**; against a fast reach, swimming upstream is **a wall**; downstream is free travel;
wading in shallows drags; a waterfall's pool churns; going over a fall is a fall. Rivers
become one-way corridors (§BC gates) — the world routes you without a fence. A torch in
water goes out (§AW). **Waterfalls:** Mike reports they may be broken — check they generate
and render before anything else here. Priority today: **water systems over more species
variety** (§BH).

## BF. Travellers on the road — mute, watching — LOCKED

Rare cloaked figures **walking the roads**, day and night (`data/travellers.json`). They
**never speak and never stop.** The hood tracks you (the §B head-look rig, **capped at the
hood**: eyes follow, the body never breaks stride), **holds a beat past comfortable**
(`hold_s` after you pass), then turns back to the road. Acknowledged, not engaged — that is
the uncanny part. Never off-road; wild figures stay rare (one creature per scene). They
walk unharmed through the dark (§BA ignores them) — eerier. Where they are going comes
later (camp to camp). Travellers who talk are a dialogue system: that is a fourth game, cut.

**The road is mute; the camp is not.** Folk at camps talk (the existing chatter), trade
(§BI), live (§BJ). If nothing ever responds the world reads as empty, not eerie; the camps
are where it proves it is alive.

## BG. Sound — a bed and sources — LOCKED

Two systems; the current build mixes them (random noises you cannot track down).
1. **The ambient bed** — never resolves to a source: wind, and **wind pressure that changes
   when you step under canopy**; insects; distant birds; frogs near water; per biome, per
   hour, per season. It is what goes quiet at §BA stage 1.
2. **Point sources you can walk to:** running water (louder as you approach; a waterfall
   audible from far), one bird in one tree, a creature, a fire's crackle, a torch. Terrain
   and foliage **muffle** them (`audio.json → muffle_far` exists) so tracking works.
Every existing sound is filed as one or the other: a bed sound has no position; a source
has a position you can reach. No score by default — room tone carries it (Mike to confirm
when music comes up).

## BH. Stands — dominance — LOCKED

Most real forests are one or two species deep with a handful of associates; the species
salad is basically tropical rainforest. **The generator picks a dominant species per stand
and weights it hard** (`stand.json → dominance`): dominant 60–85 % of stems, 1–3
associates, a rare accent; salad only in tropical rainforest / jungle / cloud forest, where
it is true. A pine wood is pine and reads as a place; a stand size on the room scale
(100–400 m); the understory follows the dominant's own regeneration and associates. Fewer
unique meshes in view is a performance win too. **This does not cut the catalogue** (1,224
entries, 524 woody with architecture) — it changes how the catalogue is drawn from.

## BI. Trade — wordless — LOCKED as intent, built later

At camps only: hold an item out (right click a folk with something in hand) → they hold
something back, or shake their head; accept or withdraw. No shop menu, no currency, no
words. Needs things worth trading (torches, food, dead wood, later arrows), so it lands
after §AW–§AX.

## BJ. Camp folk live — SUPERSEDED by §BL (afternoon session)

## BK. What this supersedes, by section

§J, §K, §O, §P (beats 2–3), §Q, §R, §S, §Z: ninja game. §M, §T (the kit): §AW. §L: the
speedometer unpinned (§AU). §B: figures only (§AV). §C: ambient cut softened by §BD. §AO's
`wake_random`: §AY for the ambient profile. §A "cling keeps momentum": dormant. Everything
else stands.

---

# Afternoon session — 30 Sept 2026: camps are alive; the peoples

Decided by voice and chat after the morning push. Confirmed. Where this contradicts §AX or
§BI–§BJ above, this wins. The line the whole thing stands on (Mike): **the wild you are
walking through was somebody's garden.** The game is ambient and, quietly, educational: real
techniques from before modern culture, simplified, discovered by walking.

## BL. Camps are alive — the camp simulation — LOCKED

- **Every camp banks two things you can see: a woodpile and a food store.** No HUD. A thin
  pile means trouble tonight. (`camps.json → sim.store`.)
- **Folk run a safe daytime loop:** gather wood and food within a reach, bring it back, feed
  the fire, eat, sleep. **The player's gathering goes into the same store** — helping is
  doing what they do. (Supersedes §BJ.)
- **The fire is the link** (§AX, §BA). Fed, they are safe. Woods stripped → longer walks →
  less wood a day → one night it burns low → **the dark walks in.** Some are taken;
  **survivors walk to the nearest fire and join it** (some are got on the way). A camp that
  suddenly grows means one nearby went out. Camp folk **never turn on each other**: every
  human light is on the player's side; the dark is the only antagonist.
- **Starvation moves them, it does not kill them:** food short → they abandon and walk to
  a neighbour. Two readable kinds of empty camp: no woodpile and blood; or just left.
- **Embers linger** at a camp fire (`sim.embers_game_h`, longer than the player's own
  `fuel.json embers_min`) so a camp can be **saved** with an armful of fuel if you reach it
  in time; survivors may come back to a relit fire. Not a distress signal: no cry for help,
  no marker — you might hear something across a valley if you are close; mostly you walk up
  on the aftermath.
- **Growth happens without you, and while unloaded.** The sim is a store plus a timestamp;
  on load it resolves the ticks it missed (`sim.tick_game_h`, `catch_up_on_load`). The whole
  planet grows at once for nothing. **Plantings the player makes persist the same way**
  (§BP digging stick; PlantGrowth already runs at real rates ×10 time).
- **Population is gated by food.** A camp starts at 3–5 folk. Foraging feeds a handful;
  a fundamental (§BM) or a crop that takes in that soil raises the ceiling; the tribal
  ceiling is a number in data (`sim.population`). **Births need a man and a woman at the
  camp, a food surplus, and a slow clock** (`sim.births`); an isolated camp can grow. **Folk
  have three life stages — child, teen, adult** (Mike, locked): a child is a small figure
  by the fire who does not gather; a teen gathers at half rate and cannot be a specialist;
  an adult does both (`sim.births.stages`, ~40 game days a stage). Folk are men and women;
  the rig reads it at silhouette distance (build, height, voice). **Ceiling ~24 for now**
  (Mike, `sim.population.village_cap`).
- **The player nudges, never manages:** gather for them; **bring seeds, tubers, cuttings**
  (a species the wild spawner would allow on that soil and climate gets planted by a folk
  within days — wrong soil, the seeds just sit in the store); bring a material the maker
  works; bring a pot. The store is a pot of stuff the sim checks each tick: **the site
  decides what sticks.** No trade UI, no inspiration mechanic. If a feature needs the
  player to stand at a camp for an hour, it is the wrong game.
- **Camps only go backwards from resources or the dark.** An empty camp half-persists as
  a ruin and is half taken back by the forest (`sim.abandon`); **the ruins you spawn near
  are this same process run for centuries** — the ladder (§BM) run once before, all the
  way past exchange to the rung we do not build. A fresh ruin holds a few needful things
  (a pot, a half-burnt fuel pile, a torch bundle), never treasure, never collect-them-all.
- **Restraint is a rule, not a lecture:** a camp may grow into a village **as long as it
  takes less than the land regrows** (`sim.restraint`). The moment it outruns its woods,
  the fire dims and the dark walks in — the survival mechanic already built does the
  moralising. The techniques of living in balance (§BP: coppice, weir, swidden left to
  close, the burn in season, terra preta) are how a village stays under that line.
- **Ceiling: exchange, not hierarchy.** Camps climb fire → food → storage → specialist →
  exchange (§BM) and stop there on purpose. Chiefs, walls, tribute and war are the next
  rung in real history and a different game with a different antagonist; this world sits
  at the moment just before.
- **Camps are derived from the site, never authored as types** (§BO). What they burn, eat,
  build with, and which specialists they can have all come from the land within reach.
- **Wildfire is rare** and needs three things at once: a fire-prone biome, a dry spell from
  the weather sim, and an ignition — lightning, or the player's torch dropped in dry grass
  (anywhere else it just goes out). A burn strips fuel woods, leaves standing dead wood,
  and **fire-followers** bloom after (seeds dormant for decades, `seasons`/flora). **Camps
  walk away from fire rather than die** — early on there is nothing to carry; later they
  carry what they can and rebuild a valley over. An abandoned camp in a burn scar reads
  differently from one the dark took. Because nobody can *make* fire (§BP), lightning is
  the only new fire that ever enters the world.

## BM. The four fundamentals, and the ladder — LOCKED

**Fire made us human; storing food made us civilised.** The spawn is the floor of being
human (a lit hearth, the folk who found you); the granary is what lets a camp grow.

- **The fundamental is not "learn to farm"; it is "find the one thing your land gives
  reliably and stay put for it."** Four routes, each raising the food ceiling its own way,
  the land deciding which a camp can take:
  1. **crop** — river and valley folk (the flood drops fresh silt; seeds dropped by the
     water come back); the digging stick, the terrace, the flood crop;
  2. **fish run** — coast and lake folk (the weir: a V of stakes in the tideline, the tide
     goes out and the fish are left behind the fence; towns without a single seed);
  3. **herd** — steppe, savanna, taiga, highland folk (dung fuel, milk, moving with the
     grass). **Build last** — it needs animals that move and breed;
  4. **managed burn** — grassland, savanna and scrub folk (burn the old grass in season,
     the new growth comes back sweet and the game follows; a grassland never burned goes
     to thorn — the fire *is* the farming; piggybacks on the wildfire rules).
  `forage` is the floor everyone starts on; rock-shelter folk stay there, honestly.
- **The ladder every camp climbs:** **fire → food → storage → specialist → exchange.**
  Storage is the hinge: a surplus you cannot keep is rot, so pits, racks, smoke, salt and
  the clay pot come before any craft; the first person who does not gather is the
  specialist, and specialists are the surplus wearing a job. Exchange is the last rung: two
  camps with different specialists, the pot travels to the fishing village and the salt
  comes back — **the mute travellers (§BF) get a reason to be walking, and a busy path is
  a road kept clear.** Stop there (§BL).
- **Which rung a camp can reach, and how fast, comes from the land and from what the
  player brings.** Procedural without being random.

## BN. Three faces at any grown camp — LOCKED

- **The headman** — bestows the site's technique (§BP) on contact. (A quest gate comes
  later: their woodpile is low, you turn up with an armful, now they will teach you. Same
  contact, gated by helping.)
- **The plantkeeper** — the cook-shaman; historically one person: the one who knows which
  plant feeds you knows which heals you and which kills you. Her knowledge is **the local
  plant list** (the catalogue's species in this biome: what to eat raw, what to dry, what
  cures, what kills — practical *and* flavour). She is why the 1,224 plant entries pay
  rent. Later she sends you into the biome for a plant, a fungus, a fish, a wood, a resin
  — never an ore, feather or beetle — makes something with it, and shares the knowledge:
  quests that teach the world.
- **The maker** — the craft the land supports: netmaker, potter, smith, weaver, knapper.
  **The player never crafts; makers do.** A material is useless in your pack; carrying
  clay across three biomes to the one potter who can throw it is what makes the world
  feel connected rather than looted. That is the collectible loop Mike wants (Minecraft's
  gathering without its crafting grid), and the whole no-tool-tiers rule survives as long
  as **the smith is a place, not a tech level.**
- Headman and plantkeeper appear at the storage rung; the maker only where the site
  allows one and there is surplus.

## BO. Peoples — ways of life derived from the site — LOCKED

- **A people is a way of life, not a nation.** Seventeen lives (`data/peoples/`, one file
  each; `biome_map.json` says which life a site lives; the README is the schema, `coast.json`
  the worked example, `tools/peoples_check.py` the gate). **The way of life is the verb; the
  biome is the noun:** two coast camps both build weirs and pile middens, but one burns
  driftwood and dries cod on a cold rock shore and the other burns palm frond and smokes reef
  fish. Seventeen lives, fifty-two dressings, nothing hand-authored twice — and not one people
  per biome (that is copy-paste with extra steps).
- **Our own folklore.** Never a real nation's name in play. The fantastical folk — goblins
  (already the tribal folk in the repo), orcs, fae, small folk — are dressings on a way of
  life, **all friendly** (a friendly orc is the stronger beat: the player braces and nothing
  happens). They read at silhouette distance. **Mute, plus a line in the log** (§AZ): "The
  coast folk showed you the weir." No speech, no dialogue system.
- **Real peoples are what we learn from**, cited in each file's `real_world` (the Pacific
  Northwest and the Jōmon for the coast; the Marsh Arabs and the Viking bog-iron smiths for
  the marsh; Egypt for the flood crop; the Sámi for the taiga; the Inuit qulliq for the
  tundra; the Andes for chuño; the Uros and the chinampas for the lake; the Sundarbans for
  the mangrove; the Maasai for the savanna; the Hohokam canals and the qanat for the
  desert; California's acorn-and-burn peoples for the scrub). Written with respect and
  accuracy — these are living cultures and their ancestors.
- **Materials, not elements.** Flint, obsidian, clay, ochre, salt, resin, pitch, cordage,
  hide, shell, bone, charcoal, peat, lime — and **bog iron, worked only by the marsh
  smith** (iron seeps into a marsh, bacteria precipitate it as lumps you rake from the
  muck, roasted in a clay bloomery with charcoal from the old-growth folk: no mine, no
  pickaxe, and a bog regrows its deposit over decades). Metallurgy, forges, smelting, the
  periodic table, tool tiers (pickaxe, shovel) stay cut (27 Sept §0, §T). The fishing pole
  returns **only as a technique** (§BP) — the spear is still the fast way, and still a
  wild find (§AW).

## BP. Techniques — verbs learned, permanent, weightless — LOCKED

- **Camps give you verbs, not tools.** Teaching beats giving: a technique weighs nothing,
  cannot be lost in a river, and means the reward for finding people is being permanently
  better at living out there. `data/techniques.json` is the list (73 after the peoples fill), each with
  `taught_by` peoples; the headman bestows the site's one; `player_can` says whether the
  player performs it or it raises the camp's ceilings.
- **First to build: the fishing line** (coast folk): twist a line, carve a hook of bone or
  shell, cut a pole. Skill-based like the spear (§AW): click to lunge, hold to throw
  remains the spear's; the pole is the patient way.
- **Fire is never made, only carried — no fire drill.** Mike's call, and the right one: if
  you can make fire anywhere, hearths stop mattering and the dark stops mattering. The
  progression is in **what you carry the flame in and what you feed it**, all gathered,
  all from somewhere specific: the **resin torch** (cattail head dipped in pine pitch —
  longer, brighter, shrugs off drizzle), **fatwood** (resin-soaked pine heartwood, found
  not made), the **ember carrier** (tinder fungus or punk wood wrapped in bark: no light,
  but holds a live coal a day or more so you can lay a new fire from it — it still starts
  from a hearth and still goes cold if neglected; designer to confirm it counts), the
  **fat lamp** (a stone bowl, rendered fat, a moss wick: dim, hours, will not blow out,
  sets down inside a shelter), **candlenuts** (oil-rich nuts strung on a stick, tropical).
  Hearth fuels as `fuel.json`: hardwood for the long night, dung and peat where there are
  no trees.
- **Techniques the player can carry elsewhere are the harmony techniques:** coppicing
  (cut hazel to the stump and it throws straight poles every seven years — a fuel crop
  with no clearing; **first**, since it keeps fires lit), the weir, the clam garden, the
  Three Sisters plot, the chinampa, terra preta, the small swidden left to close, the burn
  in season, peat cut and dried, the qanat. Each is a specialist's knowledge, and each is
  what keeps a village under the restraint line (§BL).
- **Irrigation is a rule, not fluid physics:** a plot near water or a dug channel counts as
  watered, and the ditch visibly carries water. The digging stick digs it.

## BQ. Ruins — the part of the craft that does not rot — LOCKED

- **Generator rule:** wood, rope, hide and thatch are gone in a generation; **waste and
  stone remain.** Every craft has one signature heap (each people file's `ruin.signatures`):
  slag mounds and a bloomery pit in the marsh, peat cuttings gone to pool; **shell
  middens** on the coast (a mound a different colour from the shore, lime-rich, so
  different plants grow on it), weir stakes in the tideline, salt pans in the rock; the
  kiln hump and the clay pit turned pond on the river, terraces stepping the bank; charcoal
  platforms (flat black circles where nothing grows) and coppice stools grown out into
  many-trunked trees in old growth; a knapping floor glittering with flakes, a lime kiln,
  dry-stone walls in the mountains; a stone ring, a lined spring and a scorched line in
  the grassland (it forgets fastest); ochre on the ceiling and a metre of ash under the
  hearth in the rock shelter; black earth that still grows better in the tropical forest.
- **Ruins per biome make sense from the industries the environment produced** (Mike):
  the people file's signatures are dressed by biome like everything else.
- **Legibility grows with restoration.** At first a ruin is an ambiguous heap in the
  bramble. When a camp moves in it clears it and the shape comes back — kiln, weir line,
  terrace — and now the player can read it. **Restoring is the reveal**, and it is just the
  camp's normal growth pointed at the old stones instead of new ones. Consistent with
  legible decay (§BC): the abutments were always there under the ivy.
- **A camp squatting in a ruin inherits a head start** (`ruin.signatures[].inherits`): the
  clay pit is already dug, the coppice stools still throw poles, the weir works from the
  first season, the black earth grows better. Ruin-dwellers become the potter faster.
- **The ending stays unnamed.** Whether they outran the woods, the dark took them, or they
  turned on each other, the player only ever sees what was left standing. Nothing in the
  game says.

## BS. The land is finished; the weather only dresses it — LOCKED

Mike: the world has been shaped by weather over the millions of years it has been forming,
so live weather should not change the environment much — **the weather has already shaped
the environment.** Same rule as plate tectonics (27 Sept §0): **erosion is baked at world
generation** — valleys, canyons, dunes, glacial troughs, karst, river terraces, badlands are
the record of ages of weather, laid down once. The live water cycle and wind (§0, §AB)
change what the land *wears* — moisture, the season's leaf, snow cover, river stage and
current, fire risk, a dry spell, a burn scar and its fire-followers — never the landform
itself. No live erosion, no terrain deformation from rain, no rivers cutting new beds.
(Scope guard as much as realism.)

## BU. The look in one line — LOCKED (30 Sept, late, Mike)

**"Almost like Minecraft, except not in boxes, and everything flows better."** Minecraft's
texture logic — a tiny nearest-filtered tile on every surface, crisp at any distance, the
brain filling in the rest — on real shapes: curved ground, trunks that lean, leaf cards
with holes, water that moves. Mike likes the pixelation; it does the work in the distance
and it is cheaper. Measured against the reference frames (day luma 0.31 / sat 0.64 / texel
0.016 / darkest-5 % navy 0.078; night 0.20 / 0.73 / 0.014 / 0.022): ours (dusk) was 0.15 /
0.53 / 0.009 / 0.000. The gap is texture, the floor and saturation — not darkness. Night is
one colour (collapse toward the floor's blue, never grey); water is the brightest thing.

Four calls Mike made on the frames (30 Sept, 21:00):
- **Days are vivid, not dark.** Where the sun hits, the ground is bright saturated green
  under a blazing cobalt sky; shade stays deep navy. This softens §C's "dark day" to:
  *dark where the sun doesn't reach, vivid where it does.* Target day luma ~0.31 at
  saturation ~0.64 (the frames), not mids pulled down everywhere.
- **The pixels come from the 480p screen AND the textures.** §Y stands; the §AG tiles go on
  top. More PS1 than GameCube at the edges, and cheapest.
- **Water: glowier, but biome-matched.** Every water is brighter and more saturated than
  its surroundings (a scrolling caustic tile, white-blue waterfall sheets), but its base hue
  follows the biome: electric blue for clear mountain and karst water, tea-brown glow for a
  floodplain river, green-blue for a lake, black-green with a blue highlight in a swamp,
  turquoise on a reef. `look.json → water.by_family` (first guesses).
- **Grass cards near, the tile far.** Blades/flecks within `ranges.grass_m`, denser than
  now, fading to the ground tile; the texel noise carries the distance.

## BT. Canopy folk — the seventeenth life — LOCKED

Mike: a village that lives in the trees in really old growth, never comes down, harvests
everything up there, with **vine bridges** connecting the houses. `data/peoples/canopy.json`
(site rule `canopy`: an old-growth stand with three or more giant trees, rare). Platforms
lashed in the crotches of giants; vine and rope bridges between trees; rope ladders they
lower only once the headman has met you — **the player reaches them by climbing** (the
tree-climb system kept in §AU finally has a destination). A lined **hearth box** keeps fire
on wood — a canopy camp that lets its hearth spill burns the village (restraint again).
Harvest: fruit, nuts, honeycomb, eggs, resin (the dammar torch is their light). **The
living root bridge** — figs' roots trained across a gap over fifteen to thirty years,
stronger every year — is their harmony technique and the one ruin that *grows* after its
makers are gone. On the ground a canopy village leaves almost nothing: lashing scars and
worn footholds on the giants, a fallen cable, a midden at the foot of the biggest tree.
The fae people of our folklore, if any is. Real analogues in the file: the Korowai and
Kombai tree houses, the Khasi–Jaintia root bridges, the Iya Valley kazurabashi,
Q'eswachaka, the honey-climbers of the Congo basin.

---

# Night session — 30 Sept 2026: the camp works; the first road; the fire

Decided by voice late on the 30th (22:00–23:00), written up and pushed on 1 Oct. Confirmed
by Mike. Builds on §BL (the camp sim), §BC (roads) and §AX (the hearth); where it
contradicts §P beat 1 (27 Sept), `main.gd`'s start-of-dusk clock or `campfire.gd`'s four
tongues, this wins. Every number in the data is a first guess; the designer tunes by play.

## BV. The spawn camp is a working camp — LOCKED (30 Sept, night, Mike)

Mike: more than two people at the spawn, and they should be doing tasks. **The opening camp
starts with four or five folk** (`camps.json → sim.opening.start_folk`; supersedes the
elder-and-hunter pair in `encampment.gd` — those two stay, as two of the four or five), and
**every one of them is in a job loop you can watch complete** (`sim.jobs`):
- **the fire-feeder** — walks to the woodpile, takes a piece, drops it on the fire when the
  store runs low: the §AX feed, now a body doing it;
- **the gatherer** — walks out of the clearing to a **real source** (a tree with deadfall,
  a food plant the plantkeeper would name, the water) and **comes back carrying something
  you can see**, which lands on the store (§BW);
- **the hearth-worker** — sits by the fire mending, shaping, scraping: a potter's lump, a
  net, a hide — the §BN maker's job at silhouette distance, before there is a maker;
- **the children** — orbit the whole thing: follow a gatherer to the clearing's edge, sit by
  the plantkeeper, run between the huts; never gather (§BL);
- **at a ruin camp, the restorer** — hauls stone off the heap and sets it: the §BQ reveal
  done by a visible pair of hands, one stone a trip.

The sim already does the accounting (`CampSim`); **the jobs are the accounting made
visible.** The walker in `camps.gd` becomes the gatherer, with a real destination and a
load; **several folk work at once** (`sim.jobs.max_at_once`), not one walker per camp. The
loop still runs only by day (`loop.gather_hours`) and only within sight of the player;
unloaded camps keep ticking as numbers (§BL) and nothing here changes a tick.

## BW. Every trip is a piece — LOCKED (30 Sept, night, Mike)

- **Each gatherer's trip adds one visible piece to the store** (`camps.json →
  sim.store.pieces`): a log onto the woodpile, a fish onto the rack, a tuber into the pit.
  The pile grows one armful at a time while you watch, and the fire-feeder takes pieces off
  it. **No scaling blob:** `refresh_woodpile` stops redrawing the pile from a number and
  adds or removes pieces instead. The number stays the sim's truth; the pieces are its
  ledger, and what you see is what there is.
- **The wood on the pile is the wood of the place** (Mike): a piece takes the **bark and
  wood tint of the species it was gathered from** (the catalogue's per-species tint, §AI /
  `PLANT_SCHEMA.md`). A birch camp stacks pale wood, a pine camp dark resinous wood, a scrub
  camp a grey heap of brush, a treeless camp a stack of dung cakes (§AX). The pile is a
  portrait of the stand the camp sits in (§BH), and the gatherer's walk is the proof.
- **The food store reads as what the camp eats** (§BO: the way of life is the verb): fish on
  a drying rack for coast, lake, marsh, mangrove, taiga and tundra folk; meat strips on the
  rack for the herders, the burners, the rock shelter and the desert; tubers in a lined pit
  for the highland and the tropical forest; maize hung by the husk in the karst and the old
  growth; grain in lidded jars on the river; nuts in bark boxes in the canopy. Each life's
  `food.preserve` already says so; `sim.store.pieces.food_by_life` maps it to a piece.
- Pieces are capped for draw (`max_pieces_shown`, 24 today); past the cap the pile reads
  as full and rich — that is the ceiling showing, not a bug.

## BX. The first road — afternoon spawn, the hearth at dusk — LOCKED (30 Sept, night, Mike)

- **You spawn in the afternoon, beside the road, never in trackless woods** (`roads.json →
  opening_road`). Supersedes §P beat 1's "early dawn or dusk light is preferred" and the
  start-of-dusk clock in `main.gd`. The opening camp (§BV) sits on the road; the first thing
  you see past the fire is the way. Mike: right now it feels like spawning in the middle of
  the woods with no beaten path.
- **The first landmark is a camp outside a ruin, restoring it** (§BQ) — so the end of the
  first road is always a **hearth glow through the trees**, with the dark shape of the ruin
  behind it to be curious about by morning. Never a dark ruin alone: you do not have to have
  understood the torch (§AW) to survive night one — but you will have walked into a dusk.
- **You reach it around dusk, right before it goes dark** (Mike). The opening road is tuned
  to **about half an hour's walk** at the ambient walk (§AU: 4.3 m/s, so ≈7 km), and the
  clock is set so that a clean walk arrives early in dusk and a walk that lost the trail
  twice still arrives before full dark (`opening_road.walk_real_min`,
  `spawn.real_min_before_dusk`, `detour_allowance_min`; dusk is 18 real minutes, §0). The
  first session in one line: golden afternoon → the trail → cobalt → the glow.
- Only the opening road is tuned; every road after it is §BC and §BY.

## BY. Roads are old and long — two layers, lost and found — LOCKED (30 Sept, night, Mike)

- **Two layers.** The **old layer is baked at world-gen** (§BC): a least-cost path between
  neighbouring landmarks (camps, ruins, springs, fords, passes, the giants of §BT) that
  hugs contours, follows riverbanks and threads passes, so it bends the way a real trail
  does; trees and understory **thickened along both edges** so it reads as a hallway (the
  §BB walls), opening into a clearing — the room — at each landmark. The **live layer is
  desire lines** (`roads.json → desire_lines`): every folk trip (§BV) and every pass of the
  player stamps a little wear on the ground; grass thins, dirt shows, and the line fades
  when the walking stops. Paths appear where people actually walk. A camp's gather trails
  are the first thing that says it is alive from a distance.
- **Half-forgotten, overgrown, and long** (Mike). The old roads run for kilometres with a
  rhythm: stretches where the trail **nearly vanishes under fern** and you have to find
  where it picks up again, then a **tell** — a mossy cairn, a notched tree, a worn stone
  step, the two abutments of a bridge that is out — then the next room. `roads.json →
  lost_and_found`: how often a stretch vanishes, how long, and what marks the pickup.
  **Losing and refinding the path is the ambient game**; the slow walk (§AU) is for exactly
  this. Overgrown, never illegible (§BC stands). Waymarks gain `notched_tree` and
  `stone_step` (`decay.waymarks`).

## BZ. The fire — light that swells, a crackle you can walk to, one pixel flame — LOCKED (30 Sept, night, Mike)

- **Light.** A fire does not get brighter at night; the world gets darker around it. By day
  the light stays modest (the sun drowns it, `Campfire.DAY_SHARE`); as the sky goes cobalt
  **both the radius and the energy swell** (`look.json → fire.light`: `night_range_scale`,
  `night_energy_scale`) in a warm orange that fights the blue moonlight (§BB: the only warm
  light is fire), with **noise on the brightness and a small jitter on the light's
  position** (`flicker`) so the shadows dance on the trunks — not the sine stack in
  `Campfire.flicker()`. The §AX burn-down still scales it all: low is smaller and dimmer,
  embers a red glow, out is nothing. The safe radius (§BA, `fuel.json light_radius_m`) is a
  separate number and does not swell.
- **Sound.** Two layers, both point sources (§BG): a **steady soft hiss bed** and **random
  pops and snaps at uneven intervals**, never on a loop the ear can learn (`audio.json →
  fire`: the pops are one-shots on a random clock, not the 4 s `fire_loop`). Spatialised,
  muffled by terrain and foliage, and heard from **farther than the glow is seen**
  (`kinds.fire.max_distance` raised): on the first road you hear the camp before you see it
  (§BX).
- **Flame.** **One camera-facing card per fire** that turns only about its own up axis
  (supersedes the four overlapping tongues in `campfire.gd`; Mike does not want crossed
  cards — from straight above it thins to a line, which reads fine). The animation is
  **generated from noise and crunched to pixels**: scroll a noise field upward through a
  teardrop mask, **posterise to three or four flat bands** (pale yellow core, orange, red
  fringe, dark edge), drawn to a tiny card — **about 32 × 48 texels**, nearest-filtered
  (`look.json → fire.flame`) — so it stays crunchy at any distance; the 480p frame (§Y)
  does the rest. Nearer it is simply bigger: the same card, like Ocarina's. **Embers are
  single-pixel billboards** drifting up, the same material.
- **One shader, every fire:** shrink the mask and slow the scroll for the held and planted
  torch (§AW); let it **collapse to a red flicker when a camp's woodpile runs low** so a
  dying hearth reads from across the clearing (§BL: a thin pile means trouble tonight — now
  the flame says it too).

## CA. A species grows only where it belongs — the biome gate — LOCKED (1 Oct, Mike)

Mike, after playing the 1 Oct build: *Magnolia grandiflora should not be in a savanna.
A species belongs in its natural environment; a savanna is acacias, grass and shrubs.*
And: *every time I get a screenshot from the code it looks good, but when I load in it
looks broken.*

**What was wrong.** `vegetation_placer.gd` places by climate bands alone ("climate, never
biome names"): a biome file was a list of species to load, never a gate. So the Southern
magnolia of `24_floodplain_forest.json` (15–22 °C, rich soil, moist ≥ 0.5) grew on a
savanna riverbank at 18.9 °C on alluvium, and an *Alocasia* from `giant_herbs.json` stood
beside it drawn as a smooth hull. The dev frame (`tools/dev_view.gd`: seed 42, the first
camp, a third-person camera 9 m south of the fire, clear weather, noon and midnight) never
looks at any of this, so it never fails.

**The rule.** `data/habitat.json`:
- **A species grows only in a biome whose file lists it** — in `plants`, or in an
  association's `dominant` / `companion` / `ground` / `catalogue`. The climate, soil,
  altitude and needs gates still apply **inside** those biomes; the biome is a gate on top,
  co-equal with soil (§4b of `PLANT_SCHEMA.md`). A riverbank inside a savanna is still a
  savanna: it grows the savanna file's waterside species (fever tree, doum palm, reeds —
  add them there), not another biome's.
- **A catalogue species (`data/plants/`) grows only in the biomes its `biomes` list names**
  (its native habitats, filled from `origin` / `native_range` by parallel agents, one per
  file, with `plant_schema_check --strict` requiring the list). Until it is tagged it does
  not grow — the same rule the realm gate already applies to an untagged `realm`. The
  realm gate (§AA) stays as the second filter: the biome says *could it live here*, the
  realm says *does it live on this continent*.
- **Borders.** `ecotone_m` lets a neighbouring biome's species cross the line that far
  when their own bands fit; **0 for now** (hard borders are honest; a gallery forest is a
  floodplain-forest cell, not a bleed). The designer can open it later.
- **The planet is procedural, not Earth** (Mike): a species may well grow on a continent
  it never saw on Earth — the realm map hands continents out by seed. What it may not do
  is grow in the wrong *kind of place*. That is what the biome gate holds.

**No blobs, any plant.** §AJ's see-through test was written for trees; it applies to every
plant. The `umbrella` placeholder for aroids and giant herbs, and any `lobe` hull on a
shrub or herb, is replaced by leaf cards on a stalk: a flat card with the species' tile,
margin and venation drawn, back-lit from behind, no smooth hull, no untextured face.

**What "done" means from now on — the walkabout** (`tools/walkabout.gd`): the end of
every visual pass, once, not per step (Mike: screenshots per step burn usage). Four seeds;
in each, the opening camp at the spawn hour, the first road 1 km out, and three random
sites in three different biomes; **first person at the player's eye** (1.6 m), facing four
ways; at 14:00 overcast, 17:30 and 22:00 clear; at the play preset (`render.preset`). It
lists every species within 30 m and **fails if any grows in a biome that does not list
it** (0 allowed); the frames go in the report in place of the dev frame. The dev frame
stays for grade measurements only.

**Two 1 Oct fixes that ride with this:** the held torch's flame is anchored to the stick's
head, computed from the stick's transform, not a hand-tuned offset (the §BZ card is
base-anchored and floated above the stick); and the §BX afternoon spawn is built
(`main.gd` still starts the clock at dusk — data was in, code was not).

## CB. Every new world is a new world — LOCKED (1 Oct, Mike)

Mike: *the last couple of patches I always spawn in at this broken savanna.* Because
`data/dev.json` is committed with `dev_mode: true`, `seed: 42`, `spawn_choice: 0`: every
world is seed 42 and the single best-scored camp cell, and since saves are per seed
(`user://worlds/42.json`), every patch reloads the same world at the same day. The random
spawn (§P, §AO: "a different one each game") was built and never allowed to run.

- **A new world rolls a fresh seed and a random first camp** among
  `Encampment.candidates` (the 12 best cells, 20 km apart). The seed is the world's name:
  the log's first line (§AZ) reads "World 7731 — day 1", so a world can be revisited or
  shared by number.
- **Continue loads the last world; New world rolls another.** The game boots into the
  last world played (a `user://worlds/last` pointer); "New world" is an entry in the
  settings panel and a dev key, and asks once ("start a new world? the old one stays").
  Old worlds stay in `user://worlds/` by seed; nothing is deleted.
- **The dev pins are for the dev tools.** `dev.json` `seed` / `spawn_choice` apply in play
  only with `pin_in_play` true or `DEV_PIN=1`; `tools/dev_view.gd` and the checks set them
  themselves. `dev_mode` and its keys stay on for the designer.
- **The first camp's kind rolls too** (Mike, 1 Oct, 11:39). `Encampment.candidates`
  scored every cell on one taste (mild, green, 2 km from a coast, ~20° latitude), so the
  twelve best were the same kind of place every time. Now `camps.json → first_camp`: a
  new world **rolls a kind by weight** — forest, river valley, coast, cold shore,
  grassland, savanna, tropical forest, scrub, highland — then a random cell among that
  kind's best few, 20 km apart. A kind is a set of biomes plus a water rule (a camp needs
  water within reach); every candidate must sit in a biome that offers fuel
  (`fuel.json`), inside a non-lethal mean temperature, on level ground, never in a
  wetland, desert, ice or the special biomes. The kind decides the opening camp's people
  and so what it burns, eats and stacks (§BO, §BW). A cold-shore or taiga first camp is a
  harder night one on purpose. Weights are first guesses; the designer owns them.

## CC. The catalogue is trimmed to archetypes — LOCKED (1 Oct, 12:01, Mike)

1,224 entries, 951 species, 470 genera is too many to make right (§CA found the wrong
ones growing, and every one of them needs a card, a tile and a biome). Mike's trim
(`data/habitat.json → trim`):
- **Nine categories: tree, shrub, grass, moss, orchid, aroid, fern, cacti, fungi** (cacti
  added 12:04). Fungi is its own category because it is not a plant.
- **Four species per category per biome, where applicable** — a biome that has no moss or
  no orchid simply has none; nothing is invented to fill a slot. The four are the most
  archetypal species of that kind of place. **Mike's seed list comes first**
  (`docs/plant_archive/TRIM_SEED_LIST_2026-10-01.md`, 12:08: four each of tree, shrub,
  grass, moss and fungi per biome): a name on it that is a real accepted binomial (Kew
  POWO), native to that kind of place and drawable at the player's eye is kept, **and is
  added with the full schema if the catalogue lacks it** (sugar maple, marula, sausage
  tree, hen of the woods…). After the seed list: the biome file's dominants and
  companions, then the species a flora of that place names first. The seed list is
  sorted into the nine categories as it goes in (its ferns, cacti, lichens and kelp
  leave the rows they were written in); orchid, aroid, fern and cacti are filled from the
  biome files and the agents' knowledge. Not drawable, so never kept: yeasts, molds,
  rusts, smuts, slime molds, bacteria, algae, diatoms, plankton. A biome's
  `hero_species` always survives.
- **Three catalogues stay whole, untouched:** `cannabis.json` (64 landraces of one
  species), `trichocereus.json` (the 18 ceremonially active, psychoactive species), and
  `amorphophallus.json` (all 246 — Mike's own plants). Their `biomes` lists (§CA) still
  gate where they grow.
- Everything else in `data/plants/` is folded into the biome lists it serves or archived
  to `docs/plant_archive/` (the archive already exists: nothing is lost, it is just not
  loaded). Vines, kelp, cushion plants and lichens have no category and are
  archived unless they are a hero.
- Fewer species, each one right: every survivor gets its `biomes` tag, its leaf card
  checked at the player's eye in the walkabout (§CA), and its place in a stand (§BH). The
  §BH dominance rule now has an easy job — four trees is a stand.

## CD. The resurrection fern behaves as it does in life — LOCKED (1 Oct, 13:08, Mike)

Mike found a resurrection fern (*Pleopeltis polypodioides*) on the ground in a jungle,
drawn as a flower. Where it grows is fixed in the data (an epiphyte everywhere, its
native kinds of place; commits `b8a20a0`, `afe30cc`); epiphytes on real branches with a
shape per kind is the epiphyte pass. And it earns its name: **it behaves as it does in
real life** (`desiccation` block, `PLANT_SCHEMA.md` §4a5):
- **In a dry spell it dies back without dying:** after about a day without rain the
  fronds begin to roll inward; over a few dry days they are rolled tight and grey-brown
  — the densely scaled underside is what shows — and it looks dead. (In life it can lose
  most of its water, up to ~97 %, and survive.)
- **Rain brings it back:** it starts to open within an hour or so of rain and is flat and
  green within about a day. Fog and humidity slow the drying. No growth while dry.
- Driven by the **live weather at that place** (`WeatherSim.local_weather`, the same rain
  the camps' wildfire clock counts), per chunk, hour by hour; a whole oak's mat turns
  together, and the next valley over, still under the storm, stays green. Quietly
  educational, like everything else here: a player who sees a grey oak limb go green
  after a shower has learned something true.
- The block is generic on purpose: mosses (many dry brown and green again within
  minutes of wetting), some lichens and *Selaginella lepidophylla* behave the same way
  in life and can take it later.

## CE. The named plants are always in the game; vines climb and cover — LOCKED (1 Oct, 14:04, Mike)

Mike: *make sure the following plants are in the game: Musa, Amorphophallus, Cannabis,
Trichocereus, Acacia, bamboo, vines* — and *vines should also grow over surfaces.*

**Checked in the running game first** (`tools/plant_presence_check.gd`, full planet, seed
7731, three sites per group): bananas, *Amorphophallus*, bamboo and vines (ivy) grew;
**cannabis, *Trichocereus* and the acacias did not** — each in the data and legal under the
§CA gate, kept out by something else:
- **Acacias:** the umbrella thorn, the savanna's "Acacia" and mulga used the `sand` soil
  preset, a hard gate to sand and sandstone only — on alluvium or granite they could not
  spawn at all (Mike's savanna, alluvium soil, had magnolias and no acacias). Fixed in the
  data: the soils they really grow on.
- ***Trichocereus*:** tagged to the `andes` realm, which the realm gate only allows in a
  biome hosting it, and no dry biome did (only cold puna and páramo, outside its 8–20 °C):
  it could not grow on any planet. Fixed in the data: an inter-Andean dry-valley community
  (`andes`) in steppe and Mediterranean scrub, the biomes that match San Pedro country.
- **Cannabis — and the deeper rule:** the stand rule (§BH) gives a stand one dominant, 1–3
  associates and a 3 % accent pool shared by everything else, and the 64 landraces each
  roll as their own species: none ever wins. Only the salad biomes (rainforest, jungle,
  cloud forest) let everything in, which is why bananas and *Amorphophallus* showed there.

**The rule** (`habitat.json → always_present`, `trim.always_keep`):
- These groups are **never trimmed** (§CC), whole, whatever the per-category cap.
- **Wherever a member fits the site** (climate, soil, biome gate, realm gate) it is an
  **associate in the stand roll, never an accent**, and the group gets at least a small
  share (`min_share`) of its tier there. A walk through the right country meets them.
- **Entries sharing a binomial roll as one species**: the 64 landraces are one plant,
  *Cannabis sativa*; the landrace you meet is the one nearest in climate and realm.
- **Vine is the tenth trim category** (climbers and creepers).
- **The §CC trim ran (`a9f00ff`) before this rule** and cut 21 of these: four acacias
  (fever tree, camel thorn, whitethorn, coastal wattle), seven bamboos (giant, thicket,
  moso, colihue, Kuril, kuma, savanna) and ten vines (ivy, Virginia creeper, both wild
  grapes, passion vine, both rattans, the liana, beach morning glory, fire lily). All
  restored to the biomes that listed them that morning, leaf tiles rebuilt (998 species).

**Vines climb and cover** (`data/vines.json`): the biome's vine species grow over the
world's surfaces, not only as plants of their own — up trunks, over **ruin walls and
heaps**, draped over boulders and cliff faces, as mats on fallen logs, creeping over open
ground. Cover follows moisture, warmth and shade; **ruins wear vines by age**, and a camp
restoring a ruin (§BQ) **cuts them back** as it clears the heap — bare stone and
legibility return together, and an abandoned camp is taken back the same way. Drawn as
leaf cards on strands with the species' own tile (no blobs, §CA), following the surface,
never floating; at distance the surface's own texture greens by its cover.

## CF. The twenty favourites are the look's reference — FINDINGS (1 Oct, evening; five calls open for Mike)

Mike picked twenty favourite frames while honing the look. They're
`docs/references/batch4/`. What they show, measured, is in `docs/design/LOOK_REFERENCE.md`:
the eye test for his next play, ten rules with the frames and numbers behind them, the
composition rules for the landmark and road pass, the favourites against
`retro.targets`, what the 1 Oct look pass built and what's still open. **Not locked:** the
look pass already built most of it, and where the favourites and §BU disagree, §BU stands
until Mike answers.

What the favourites add to §BU and the look pass:
- **The shot is the biggest gap.** In 14 of the 18 landscapes, a path or water runs
  straight to a landmark on the skyline, between walls of trees or slopes. The rules for
  placing ruins, camps and stones along the roads are under "Composition" in
  LOOK_REFERENCE.
- **Darker by day than §BU's target.** Day luma median 0.21 (7 of 8 frames under 0.26) at
  saturation 0.68. Night luma 0.17 at saturation 0.80, up to 0.87, so the game's night
  saturation (0.87) is inside them.
- **Clean edges, big texels.** Silhouettes against the sky are smooth. The blockiness is on
  the surfaces, at roughly 10–27 texels a metre (the look pass set 16).
- **Shade takes the scene's colour.** Olive in the green day frames (4 of 8), navy in the
  blue ones, black only under a closed crown at night.

The open calls (listed in LOOK_REFERENCE):
1. Day brightness: ~0.22 vs §BU's ~0.31.
2. The night band to ~0.88, with the night palette kept rather than greyed.
3. 480 vs 540 lines, now that the tiles are 16 a metre.
4. Olive darks taken out of the day gate's blue/red test.
5. A one-pixel sharpen for the dark rim against the sky.

The tool: `tools/look/measure_look.py --fav` places a frame among the favourites and names
the nearest one. `retro.targets` is unchanged.

## CG. Day 1, and the game draws the same on every machine — LOCKED (1 Oct, 23:14, Mike)

Mike, from his 23:11 play (a jungle, first person): *we need to fix the gray box for plants
and their leaves … we also need to be spawning on day 1 instead of 14*, and: *can you
verify if your screenshots were from actual gameplay or just a harness?* Causes found and
reproduced the same night (evidence: PROGRESS, 2 Oct, "Mike's 1 Oct 23:11 play").

What was wrong:
- **The grey boxes are empty textures.** Since `df993d6` (28 Sept) the world's tiles (leaf
  card, leaves, bark, grass, dirt, sand, stone, water) load through Godot's import cache
  (`.godot/imported`), which only the editor writes and git never carries. Where the cache
  lacks them, `Look.texture()` errors and hands every world material nothing. Godot reads
  an empty texture as plain opaque white: the leaf cutout never cuts (solid cards), the
  plants' tile-times-two colour washes out pale, the ground loses its 16-texel tiles. What
  the shaders draw themselves survives (the bamboo's node rings), which is exactly the
  23:11 frame. Same cause as the Courier font of the 15:30 play; the font was fixed by
  reading its file from disk, the tiles never were.
- **No frame shown so far was play.** Every in-game frame came from a harness
  (`tools/dev_view.gd`, `walkabout.gd`, `species_row.gd`) on Claude Code's cloud machine:
  Linux, a software GPU, a fixed seed and camera (the dev frame: seed 42, the first camp,
  third person, weather held clear), and a complete import cache. That machine could not
  show this bug.
- **Day 14.** The world clock starts at `World.START_DAYS` 13.62, picked so the first night
  has a near-full moon, and the HUD prints that count; the log's first line says "day 1".
  The HUD's day also turns over at midnight at longitude 0, not where you stand: at the
  23:11 spawn (12.7°N, 140.1°W) it read "Day 14 · 13:43" on waking and "Day 15 · 14:40"
  five real minutes later, the log's stamps a minute after.

The rules:
- **Every new world opens on Day 1**, in §BX's afternoon. The day number counts your local
  days since the world began and goes up by one at local midnight where you stand (the
  clock face's 00:00). The HUD's time line, every log stamp and the log's first line show
  the same number, and the HUD line, the log stamps and the clock face show the same time:
  the sky's clock, where noon is when the sun peaks (today the face and the stamps run on
  the plain uniform clock: 13:35 against the HUD's 13:43 at that spawn). **The sky keeps
  its clock:** the first night stays near full moon
  (§BU's moonlit night) and the season stays where it is (spring, about day 40 of it).
  Day 1 is the count, not the calendar; starting the year over would put a new moon on
  the first night. A world saved before this counts from its own first day.
- **The game looks the same whether or not the editor has imported anything.** Nothing
  drawn or printed at runtime depends on the import cache: the world tiles, the cloud
  panorama, the fonts and any model are read from their own files on disk when the
  import isn't there, as the species tiles and the font already are, and painted only if
  the file is unreadable. No material is ever handed an empty texture. A missing import
  is one warning line naming the file, never a silent white.
- **Every frame says where it came from.** An in-game frame shown to the designer says
  whether it is a harness frame (which tool, seed and camera, the cloud GPU, the import
  cache present or hidden) or his own play. The end-of-pass look check also runs as the
  designer's machine had it: import cache hidden, first person, a fresh random world at
  the afternoon spawn. A pass isn't judged done on frames his machine wouldn't draw.

## CH. Night life — a shift change at dusk; places that keep the clock — LOCKED (1 Oct, night, Mike)

Decided by voice on the evening of 1 Oct; written up and pushed that night. Mike: things you
**stumble upon** — *"there might be an old bridge or something, or an old cave"* — and
*"different types of creatures and beings which might only come out at night… you have day
creatures which sleep at night and night creatures which sleep during the day… it really
feels like a switch kind of flips."* Builds on 27 Sept §AF (bats), §BA (the dark), §BG (the
sound bed) and Phase 3 (caves). Not built.

- **Two rosters and a shift change.** Every creature keeps its real hours: `active` in
  `creatures.json` is `day`, `night` or `dusk` (crepuscular: out at dawn and dusk), and `any`
  stays only where it is true. By day the night roster sleeps — dens, roosts, burrows, hollow
  snags, under bridges; by night the day roster does. **Dusk is the handover**, not just a
  lighting change: the day animals bed down, and as the light goes blue a different cast
  wakes and comes out (dawn runs it backwards). The world doesn't just get darker; it gets
  repopulated. The mythical hunters (§BA) are the far end of the night roster, so the magic
  and the danger arrive together, and the night has things you only see by being out in it.
- **Places keep the clock** (Mike: "let's go ahead and lock that in"). An old cave is
  something you stumble upon off the road (§BC's finds); an old bridge is one you come to on
  it (half the bridges still stand, `roads.json bridge_out_share`). **By day it is empty and still; at night something
  has denned up inside or under it** — whatever the biome's night roster sends, an ordinary
  night animal most often, the hunter rarely. Same place, a different feeling depending on
  when you come.
- **Bats breathe the cave** (Mike; extends §AF): microbats roost in caves and **under
  bridges** (`roost` gains `bridge`); at dusk the swarm pours out all at once, at dawn it
  streams back. Between, they **hunt by echolocation** — fast, erratic flight snapping up the
  night insects, so they gather where the insects are thick: over water, a meadow, a torch.
  Where the bats pour out at sunset is how you find a cave.
- **The sound keeps the clock and the place** (Mike; extends §BG's bed): **cicadas by day** in
  the places they live; **night insects that differ by biome**; a **frog chorus** where frogs
  are found (the bed's `frogs` layer becomes a night chorus); **owls** as point sources you
  can walk toward. The handover is audible: the cicadas stop, the first cricket, a frog, then
  the chorus. Silence is still the §BA tell.
- **The food web seen running:** an owl **swooping on a rodent** at night; bats over a pond.
  Rare, never staged for the player.
- **Proposed order (designer to confirm):** audit what exists (`creatures.json` `active` on
  1 Oct: 33 `any`, 12 `night`, 9 `day`, 1 `full_moon`, and the night rider and pond crawler
  have none; the proximity spawner against the
  Phase 7 ledger; `SoundBed`; §AF is designed, not built) → the roster swap and the sound by
  phase (cheapest, most felt) → bats under the standing bridges (caves wait for Phase 3) →
  places by the clock → the owl.

## CI. Godot only — Summer Engine is gone — LOCKED (1 Oct, 22:16, Mike)

Mike: *"it's not built in Summer Engine anymore… I'm opening straight in Godot."* The project
is plain **Godot 4.3** (the standard build, GDScript only, no plugins; `addons/` is empty):
open `project.godot` in the Godot editor (`docs/HOW_TO_RUN.md`). Every mention of Summer
Engine comes out — the docs with this section; code comments are Claude Code's
(`scripts/core/model_library.gd`). Models come from any tool that exports `.glb`
(`assets/models/README.md`).

## CJ. Dungeons — every ruin is a delve: Skyrim's shape, Morrowind's look — LOCKED (1 Oct, 22:34–23:00, Mike)

Mike: *"there should also be dungeons in the game"*; asked whether they are the underground of
the ruins or natural caves, and whether the danger inside is the dark rather than fights:
*"yea the dungeons ideas you mentioned sounds good — different types of dungeons indeed"*;
then *"each ruin should feel almost like a Skyrim dungeon"*, and *"with more of a Morrowind
style, however higher contrast colors like the screenshots"* — *"Morrowind style aesthetic"* —
*"not necessarily the architecture for the dungeons, but I'm sure they would serve good
inspiration."* Not built.

**Locked:** dungeons exist; **both kinds** — the underground of the ruins (crypts, cisterns,
old workings, entered by torchlight) and natural caves that go deep; **many types**; **every
ruin has one**; and **the danger inside is the dark** and what lives in it, held back by your
light, never a health-bar fight (§BA: if the danger is a fight, it is the ninja game).

**The look: Morrowind, in the favourites' colour.** Skyrim gives the shape (below); the aesthetic
is Morrowind's, which sits inside the era lock (2002, §0): the mood, the strangeness that makes a
place feel foreign, detail painted into big-texel textures, a hand-built feel. **The
architecture is our own**, from each ruin's kind and people (the types below). Morrowind's
dungeons are inspiration, not a template.
The colour is not Morrowind's brown-green murk but the screenshots': high contrast, dark but
saturated, blue owning the frame, the torch the one warm light, water and fungi the only
glow, doorways as voids (LOOK_REFERENCE R1–R10).

**What "almost like a Skyrim dungeon" means here** (first pass, designer to correct):
1. **The entrance is the shot** (LOOK_REFERENCE R10, §BX): the ruin on its rise at the end of a
   path, its door a void. Often a camp sits outside, restoring the surface (§BX, §BQ): the
   hearth before the delve. The folk keep to the surface.
2. **A descent through a chain of rooms** — §BB's recipe indoors: a corridor, a threshold, a
   room with one feature, the next threshold. Older and stranger the deeper it goes.
3. **The heart at the bottom:** the deepest room holds the reason the place was built (the
   tomb, the spring, the seam) and the find — the rare things of §AW (a spear, a bow, rarer
   things later) lying where someone left them. No chests, no random loot.
4. **A way out from the heart** — Skyrim's loop: a passage, a shaft to daylight, a door that
   opens only from inside, or a collapse you can climb brings you out near the entrance or on
   the far side of the hill. You never walk the whole thing back.
5. **Full dark, and the light you carry is the clock** (§BD: inside, torch or nothing). Dread
   accumulates as at night (§BA); things den there (§CH; bats roost in ruin vaults, §AF). A
   torch burns about a night (§AW), so a small delve fits in one torch and a deep one wants
   spares or the fat lamp (§BP). First guess: an old hearth inside that you can relight with
   your torch is the delve's one safe room.
6. **The ruin falling apart is the obstacle:** collapses, flooded stretches with current
   (§BE), drops, rot.
7. **It tells its story without words** (§BQ): its people's signature, what they left (bones
   laid out, ochre on the ceiling, the ash of the last fire); a log line when you reach the
   heart; the ending stays unnamed.
8. **Generated, never hand-placed** (spec A2): assembled from the seed out of a kit of rooms
   per type, sized by the ruin.

**Types — the delve follows the ruin** (first list; `Ruins.Kind` and §BQ):
- **barrow, graveyard mausoleum, tomb** → the crypt: burial passages, niches, the chamber (the
  purest Skyrim type);
- **pyramid** → passages to the burial chamber, by regional style (§AE); the desert pyramid's
  chamber can already be walked into;
- **castle** → the undercroft: cellars, cells, a cistern, the well shaft;
- **tower** → the stair: down to a vault, or up a broken stair to the top;
- **aqueduct** → the waterworks: channels, a cistern, a qanat run; water is the path (§BE);
- **a people's ruin** (§BQ) → the old workings of its craft: flint galleries under a knapping
  floor, salt workings, an ochre cave, clay pits and peat cuttings gone to pools;
- **natural caves** (Phase 3) → the wild kind: karst systems with underground rivers, lava
  tubes, sea caves, ice caves; they keep the clock (§CH);
- **igloo, treehouse, boardwalk** (ice and wood, which do not last, §BQ) → designer to choose:
  an ice cave below, the canopy above, a sunken causeway out in the marsh.

**Open for Mike:** puzzle doors and traps the Skyrim way (claw doors, pillar puzzles,
pressure plates), or only the ruin's own decay.

## CK. Nests: camps live at the land's features, and a ruin is what a camp leaves — LOCKED (1 Oct, evening, Mike)

Mike (19:13–19:40): a list of landforms for the world terrain builder, *so the generator
has more landmark places to build environments and camps around, as you would really find
in human history — tribal peoples using the openings of cave mouths, waterfalls, ravines
etc. to make "nests"*; the same formations *could show up in different biomes, where it
makes sense from a real-life historical standpoint*; *when I said "ruins" I really meant
the remains of a camp, which could technically be built at any of the geographical
features' locations*; and every addition Claude suggested.

**The rules** (`data/landforms.json`; gate `tools/landforms_check.py`, 0 errors):
- **A landform follows its cause, not the biome.** Rock, water, ice, fire, wind, relief and
  climate place it; the biome only dresses it. A limestone cave mouth shows up in
  rainforest, oak wood, maquis and desert alike, because people lived in it in all of them.
  The same cause in another climate makes another landform, a `variant`: karst is a cenote
  in warm lowland, a doline in cool country, a blue hole drowned in a reef.
- **Thirty-five nests in seven families.** Rock and caves: cave mouth, grotto, cenote, karst
  towers, slot canyon, lava tube, kopje, natural arch. Running water: waterfall, ravine,
  escarpment, oxbow lake, wadi. Coast and sea: cove, tide pools, shell mound, bioluminescent
  bay, fjord, atoll, sea cave. Ice: cirque, moraine, esker, pingo, floe edge. Fire:
  caldera, obsidian flow, volcanic neck. Dry country: mesa, dunes, salt flat, oasis. Wet
  ground: bog and fen, levee and chenier, beaver pond. Each entry says what the nest gives a
  camp (roof, water, food, lookout, crossing …), exactly where the hearth sits, which
  peoples it suits, which of their §BQ signatures its remains show, and the real places it
  is drawn from (sources checked by the fill agents, one family each).
- **The camp loop.** Untouched → a camp settles at the hearth spot → it empties (fuel, food
  or the dark, §BL) → **its remains are the ruin**: the §BQ signatures of the people who
  lived there (ash and ochre under the overhang, cenote steps on the rim, a bone bed under
  the buffalo jump) → a new camp moves in and restores them. Any nest may be found at any
  stage. A camp lives only where the nest gives roof or water and fuel is in reach; a nest
  that gives neither (a slot canyon's bed, a dune field, the middle of a salt flat) is a
  passage or a landmark, with its hearth spot at the edge. **The hearth is never in the
  hazard.**
- **The stone architecture stays — LOCKED (Mike, 20:23: *I like the idea of abandoned
  castle ruins, aqueducts and crenellated towers — and headstones*).** Ruins keeps placing
  its castles, aqueducts, crenellated towers, headstone graveyards, pyramids and barrows on
  its own grid. They are the monuments of whoever built the roads (§BC), the ladder run past
  the ceiling (§BL), not camps. A monument is a nest too (a roof under its vaults, water at
  its well or aqueduct), and a camp may live at one as today, as people really did: the
  Arles amphitheatre held a walled town through the Middle Ages.
- **Density, first guess:** the camps at monuments stay as built (the hearth before the
  delve, §BX, §CJ), and the nests add their own: about one nest in four that gives roof or
  water holds a living camp, the best first (roof and water both), and about half of the
  rest hold an old camp's remains. Tune by play.
- **Anything with a roof is a mesh.** The ground is a heightfield and cannot overhang, so
  overhangs, cave mouths, grottos, lava tubes, a cenote's lip, sea caves and arches are set
  pieces on the terrain, like the cliff slab and the barrow passage: the mouth and a first
  chamber now. Phase 3 adds the caves behind them and retires the wolf-den props.
- **It fits night life and the delves.** A nest's cave mouth keeps the clock (§CH: empty by
  day, something denned up in it at night) and is the door of a natural-cave delve once
  Phase 3 digs behind it (§CJ); a camp's remains are §CJ's "people's ruin", whose delve is
  the old workings of its craft. Every monument stays a delve (§CJ).
- **Sizes are walking-scale.** Small landforms (towers, necks, pingos, moraines, eskers,
  arches, kopjes) would vanish at 1/10 height, so they are built at sizes that read next to
  the player, as the 14 m escarpments and 12 m ravines already are; only geography
  (mountains, plateaus, calderas, fjord depths) takes HEIGHT_SCALE.
- **Build order:** tier 1 is half-built already (cave mouth and grotto as meshes, cenote,
  slot canyon from the ravines, waterfall, ravine, escarpment, the bioluminescent bay on the
  glow ponds) and brings back the two peoples who have no home today; tier 2 is the walkable
  stamps and set pieces; tier 3 the region reshapes (fjords, tower karst, calderas, atolls).

**What the fill found in the engine** (each is also in its entry's notes):
- **Two peoples can't appear.** Shelter folk need a cliff camp or the CAVES biome: cliff
  camps are off while camps live only at ruins, and nothing is classified CAVES. Karst folk
  come on a coin flip on karst rock with no cave or sinkhole there. `Peoples.pick` should
  read the nest's `people` first: today shelter folk win every karst cave, the lake rule
  takes salt-flat and oasis camps, and every cliff site goes to shelter folk, though Mesa
  Verde's alcoves were farmers' homes.
- **Waterfalls generate** (§BE's check: 903 falls on 202 of 344 river reaches on the stamp,
  PROGRESS 30 Sept).
- Rivers are straight reaches between cells, so an oxbow draws its own old loop, a wadi is a
  new stamp down the dry drainage lines, and a beaver pond wants the narrowest headwaters.
- Salt lakes need a basin mean over 8 °C, so the puna's salars can't form; salt flats draw
  as open water, not a white crust.
- Sandstone exists only below moisture 0.3 and sand only on the coast: a kopje lays its own
  granite in dry country, desert dunes are a stamp on sandstone, and the DUNES biome is
  coast-only today.
- A volcano's crater never holds water and is about one blueprint cell wide (the caldera
  widens it and notches the rim, or the lake fill floods it). An atoll needs the geology and
  biome passes overridden and its reef ring raised: the cones don't reach the surface from
  deep water.
- Tarns and kettle ponds are smaller than the blueprint's lakes, so their stamp carries its
  own water level. SEA_ICE draws and swims as open sea (the floe edge needs walkable ice);
  seal fat has no fuel kind.
- New pieces: a booming-dune sound, a rock-arch mesh (every threshold is two boulders today),
  and the cliff-shelter hearth moved a pace or two in from the drip line, where it sits now.

**Contradictions noted:** `WORLD_SYSTEMS_SPEC` says ruins "stay as they are": the monuments
do; camps move onto nests (§CK wins for camps). Phase 3 says the only cave mouths are
wolf-den props until then: §CK builds mouths and first chambers first, as set pieces.

## CL. One sacred fig, and someone sitting beneath it — LOCKED (1 Oct, 20:55, Mike)

Mike: *it would also be cool to have one ficus religiosa with Buddha meditating underneath,
wearing an ochre-coloured robe.*

- **Exactly one per world** (`data/uniques.json`, the first one-of-a-kind place): an ancient
  sacred fig (*Ficus religiosa*) in tropical dry forest (else monsoon jungle, else savanna
  woodland), off a road like a §BC landmark, on a low rise, built to the composition rules
  (LOOK_REFERENCE). The oldest tree for kilometres, its crown 35–45 m across, roots gripping
  old stone if there is any. The species is in the plant data now (`21_tropical_dry_forest`,
  `20_jungle`: rare wild sacred figs too, as in life); this one is past the top of its band.
- **Beneath it, a figure in meditation:** the shared cloaked rig (§0), seated cross-legged
  on the east side of the trunk facing east, hands together in the lap, eyes closed, hood
  down, in an ochre robe (#CC7722). Never moves but to breathe, never speaks, and nothing
  the player does changes that. Swept earth in a ring under the crown; no fire, no store,
  never a camp.
- **What makes the tree read:** heart-shaped leaves with a long drip-tip tail on long
  stalks, so they tremble in still air. The wind shader has no per-species flutter yet;
  this tree is the reason to add one.
- **Real world:** the Jaya Sri Maha Bodhi at Anuradhapura, Sri Lanka, said to be grown from
  a cutting of the fig at Bodh Gaya and planted in 288 BC, is the oldest planted tree with
  a known date.
- **Open (Mike):** whether play names him (§BO keeps real names out of play, so the default
  is no name; the log says only *Someone sits beneath the old fig, very still*), and whether
  the dark keeps away from this one circle without a fire.

## CM. Ferns in the wet places, rhododendron forests and mad honey; the kind of place, not Earth's map — LOCKED (1 Oct, 20:55, Mike)

Mike: *grottos should have ferns, washes as well. It's fine for biomes to have various
species which might not be found there on Earth as long as the ecosystem makes sense — there
shouldn't be a magnolia in a savanna. There should also be rhododendron forests, where mad
honey comes from.*

- **A nest is its own small habitat** (`landforms.json → plants`): it grows its own plants,
  each still inside its own temperature, moisture and soil bands. A seep grows maidenhair;
  spray grows filmy fern; a shaded wash bank grows rock ferns. **Grottos:** maidenhair,
  hart's-tongue, filmy fern, bird's-nest fern. **Washes (wadis):** wavy cloak fern and spiny
  cliffbrake in the shaded cracks of the banks, curled in drought and green after rain,
  never in the sandy bed; maidenhair only at a seep or a tinaja. The same seep rule holds at
  a waterfall's spray, a slot canyon's seep and a mesa alcove's hanging garden. New in the
  plant data: *Astrolepis sinuata* and *Pellaea truncata* (hot desert, canyon, thorn scrub;
  in the wash and slope associations too).
- **Rhododendron forests** (the genus joins §CE's always-present groups): the **Himalayan
  rhododendron forest** in cloud forest (tree rhododendron, red in the spring bloom, mossed
  to the twigs) and the **beech-rhododendron forest** in temperate deciduous country (a dense
  evergreen *Rhododendron ponticum* understory with yellow azalea, *R. luteum*, at the
  edges: the Black Sea's mad-honey forest). *R. ponticum* and *R. luteum* are new in the
  plant data (temperate deciduous and temperate rainforest). The beech stand uses the file's
  American beech until a fill adds oriental beech.
- **Mad honey** (`items.json → mad_honey`, not wired): honey from rhododendron nectar
  carries grayanotoxin. Real: the Black Sea's *deli bal* from those two rhododendrons; the
  cliff honey of the Himalayan giant honey bee, which Gurung honey hunters in Nepal take
  from rope ladders; Xenophon's soldiers fell sick from it near Trabzon in 401 BC. Found in
  wild combs in a rhododendron forest in the spring bloom, and at the **honey cliff** (an
  escarpment variant: combs under the overhangs above a rhododendron forest). First-guess
  effect: a little and the world swims and the heart slows for a few game hours; more and
  you sit down where you are, which at night is the dark's chance. The designer tunes it.
- **The kind of place, not Earth's map** (§CA restated): a biome may grow species that
  aren't found in it on Earth, as long as the ecosystem makes sense; a magnolia still never
  grows in a savanna. Fills tag a species' `biomes` by the kind of place it fits, not only
  by its Earth range. **Open (Mike):** whether this loosens the realm gate (§AA: one
  region's flora per landmass) too. Plant entries carry no realm of their own today (only
  associations do), so the new species grow wherever their biome and bands fit.

## CN. Overrun ruins — cleared means lit; the swing passes the flame; a cold fire needs kindling — LOCKED (2 Oct, 11:56–13:38, Mike)

Mike (11:56): *"maybe some ruins can be 'overrun' with beasts at night and then to restore the camp
you have to go clear it out before restoring the hearth."* Asked whether "clear it out" meant a
fight (it would cross §BA) or light: *"we can keep the light as a way to fend off evil beasts for
now instead of opening back up the weapons thing — it would be cool kind of like in Minecraft how
having an item in hand while clicking basically 'slings' the item like a fist — this interaction
when holding a torch could be the way to light things"* (12:56); then *"also should have to gather
dry grass or some kind of kindling in order to light the out hearth"* (13:16); the four parts
below locked together: *"yes indeed!"* (13:38). Builds on §AW, §AX, §BA, §BL, §CH, §CJ, §CK and
what Claude Code built on 2 Oct (old hearths, the barrow's delve). Not built.

**No fight.** §BA stands: the dark is the only antagonist and light is the answer. The weapons
stay shut (Mike); a found spear still only fishes.

**1. The swing passes the flame** (`torch.json → swing`). Left click with the torch in hand
swings it: Minecraft's hand swing with a torch in it (the bare-hand swing's arc, `fists.gd`). At
the end of the arc the flame passes between whatever it touches, lit to unlit, either way: a lit
torch lights a laid fire, embers, a laid fire-holder or a planted torch; an unlit torch swung
through a lit fire catches. One verb for every flame.
- **Sharing costs the torch nothing**, as in life. Its own burn is still the clock (§CJ.5).
- **It never lights the land, a camp, folk or creatures.** Wildfire's ignition stays a torch
  dropped in dry grass (§BL). Later, the burn in season (§BP) could be the technique that lets the
  swing light old grass; not locked.
- **A swing at a beast does nothing.** They answer to fire, not to the swing: a torch slows them,
  a fire keeps them out (§BA).
- **Supersedes §AW's lighting ritual** (right click the fire with the torch in hand) and the old
  hearths' right click. Right click goes back to plain interact: feed a fire, lay kindling, make
  it your hearth (§AY), plant or take a torch, gather, climb. Right click on a fire had three jobs;
  flame now has its own button.

**2. A cold fire needs kindling** (`fuel.json → kindling`; adds a step to §AX).
- **Embers stay as §AX has them:** an armful of dry fuel brings them back. Reaching a dying camp
  in time stays the easy save.
- **A fire that is fully out** (a campfire, an old hearth, a delve's fire-holder) must be **laid**
  before the swing lights it: kindling, then at least one unit of fuel. An old hearth's charred
  branches (`fire.old_hearth_units`) count as its fuel. Lay it with right click, the way fuel is
  fed. Arriving late costs a trip to gather.
- **Kindling is whatever is fine and dry where you are**, real for each biome. It is gathered by
  hand and carried (burden applies): litter from the ground, or a part of a plant of the right
  genus (a birch gives birch bark), and only where that plant grows (§CA). The existing dry grass
  and reeds are the same items. Kindling with no fuel flares and goes out.
- **Rain makes it a skill.** Kindling gathered or carried in rain is wet until it has dried
  (`fuel.json wet.dry_h_game`; under a roof it stays dry). Dry kindling always catches. Wet kindling
  catches only if it is one of the few that burn damp (`wet_ok`: birch bark, fatwood, Douglas-fir
  pitchwood); otherwise it smokes and the fire stays cold. No dice roll, nothing to mash. How fast
  the flame takes follows the material.
- **Torch only.** No flint and steel: a cold fire takes a borrowed flame or nothing (§BP). Mike
  said so to Claude Code on 2 Oct, and it is recorded here as PROGRESS asked.

**3. Overrun ruins: cleared means lit** (`camps.json → sim.overrun`, new `data/delves.json`).
- **Which ruins.** The camps the dark took. §BL already leaves two readable kinds of empty camp,
  "no woodpile and blood" or "just left". A taken camp that has a den (a delve, §CJ, or a nest's
  first chamber, §CK) stays **overrun**: the dark moved in where it won. A camp left for hunger is
  resettled by the sim as now. **On a new world** nothing has been taken yet, so a seeded share of
  the old ruins with a delve start overrun. That names nothing about how their people ended
  (§BQ): the dark moved into an empty place.
- **Where they den: the delve.** Below, it is always night: whatever holds an overrun delve is
  there at any hour. In about half it is the biome's hunter (at an ordinary den the hunter is rare,
  §CH); in the rest, its night roster. At night they also come up and own the surface: near an
  overrun ruin, outside a fire's radius, dread fills faster. By day the surface is quiet. An
  ordinary den (§CH) is a night animal's bed, empty by day; an overrun delve is the dark's.
- **Tells, no UI:** by day the sound bed goes quiet near it (§BG), with bones and scat at the door;
  at night, shapes in the doorway and the hunter's call.
- **Clearing.** You go down with your borrowed flame, kindling and fuel, and light the delve's old
  **fire-holders** room by room. The first room's is its old hearth (as built); each room after has
  a hearth ring, a brazier or a wall sconce as suits the ruin; the heart holds **the ash of the
  last fire** (§CJ.7). Each one you light is a fire's radius nothing enters (§BA) for as long as
  its fuel lasts, and you carry what you can (burden), so you choose which rooms to hold.
  **Lighting the heart's fire clears the ruin.** Whatever held it leaves by the delve's way out
  (§CJ.4), and the log says so. Lose your light below and you are taken by the dark and wake at
  your hearth (§AY). It is like lighting up a cave in Minecraft, except that here a lit fire keeps
  them out entirely. This amends §CJ.5's first guess of one safe room: in an overrun delve, every
  lit fire-holder holds its room.
- **The surface hearth** can be lit any time. By day that is the smart play, a safe base (§CJ.1,
  the hearth before the delve). But folk won't settle over a den, so it does not clear the ruin.

**4. Then folk come back.** Once a ruin is cleared and its surface hearth burns, folk arrive.
Survivors come back if it fell recently (§BL); otherwise a few walk over from the nearest camp
near its ceiling. The camp sim takes over (§BL), restoring the ruin reveals it (§BQ), and it can
be made your hearth (§AY): a foothold far out. If that camp later goes dark, it is overrun again.

**First guesses** (in the data; Mike tunes by play): 30 % of old ruins with a delve start overrun;
the hunter holds half the overrun delves; at night, within 120 m of one, dread fills 1.5 times as
fast; a fire-holder holds 3 units and lights 8 m; folk arrive after 12 game hours, survivors if it
fell within 30 game days, otherwise 2–4 from a camp within 40 km at 60 % or more of its cap; a laid
fire is 1 kindling and 1 unit of fuel; the flame takes in at most 2 s.

**Open for Mike:** whether kindling you carry stays dry in rain, as in a tinder pouch. As written,
carried kindling gets wet, so a wet night is only beaten by the damp-burning kinds.

**What the kindling fill found** (2 Oct; seven biome families by parallel agents, one each, every
kind with its sources; merged into one block, `tools/kindling_check.py --strict`: 33 kinds, 52
biomes, 0 errors; the tropical forests were filled by hand that evening from sources that
could be checked quickly: kapok down, palm leaves, grass and dry-season litter):
- **Rain-day kindling is rare, as in life.** Only birch bark, fatwood and Douglas-fir pitchwood
  burn damp. In 25 of the 42 biomes that offer fuel none of their trees grows in the game, so
  there a wet night means no new fire: the tundra, alpine tundra, páramo, puna and tepui; the
  temperate deciduous and floodplain forests; the prairies, steppe, savanna and thorn scrub; the
  hot desert and oasis; the swamp, marsh and fen; the beach, mangrove, estuary and lagoon; and
  every tropical forest (dammar resin or bamboo shavings may change that once a source is found).
- **The real local tinder comes from plants the game lacks there:**
  - birch: the taiga has only the shrub resin birch; birch is missing altogether from the
    temperate deciduous and floodplain forests, krummholz and the bog;
  - Arctic white heather (*Cassiope*, which burns wet): tundra and alpine tundra;
  - Spanish moss (*Tillandsia*): swamp and maritime forest;
  - cattail and common reed: estuary;
  - cottonwood: canyon and oasis;
  - yucca: missing everywhere;
  - tinder fungus (*Fomes*): taiga and temperate deciduous forest;
  - also slippery elm, basswood, goldenrod and milkweed.
  Adding them would give those places their real kindling, and a few their rain-day one. That is
  a plant-data job, Mike's call.
- **Weakest-sourced kinds** (kept, and their notes say so): rockrose twigs, dead palm leaves (the
  sources show fronds burned as fuel, not named as tinder), tola twigs, tulip-tree bark.
- **Merged where families met:** one shredded cedar or juniper bark, one seed down, one dry moss,
  one puffball. Where values differed, the cautious one was kept.

**Supersedes or amends:**
- §AW's right-click lighting ritual: lighting is now the swing.
- §AX's "a dead fire needs a lit torch": it now needs a laid fire, kindling and fuel, lit by the
  swing.
- §CJ.5's one safe room: in an overrun delve, every lit fire-holder holds its room.
- The camp loop of §BL and §CK: the sim skips overrun ruins until they are cleared.
- §CH's "the hunter rarely": in an overrun delve, the hunter is common.
- The built old hearths gain the kindling step and lose their right click.

**Proposed order (designer to confirm):** the swing → the laid fire and kindling (the core kinds
first, then the biome lists) → overrun ruins on the built barrow delve (fire-holders, the den,
clearing) → folk coming back. The tropical fill is data only.

## CO. The pouch keeps kindling dry; a cave's den is cleared by the hearth at its opening — LOCKED (2 Oct, 20:15–20:32, Mike)

Mike, answering §CN's open question and the notes Claude Code left when it built §CN: *"no — I
don't want kindling to get wet — if it's in your inventory, it's kind of implied it's in your
pouch"* (20:15); *"no damp litter should burn — we're overthinking it — it should dry out after a
certain period of time if collected in rain"* (20:31); and on the nest's den, once it was
explained: *"even cave mouths should have a hearth at the opening — same as grotto"* (20:32). On
ruins at the start: *"some camps could spawn in already in ruins because that's the ambience and
feel of the game — something long lost and now a potential to be found"* (20:15).

- **The pouch keeps kindling dry** (`fuel.json → kindling.pouch_keeps_dry`). Kindling you carry
  never gets wet. Kindling gathered while it is raining, outside a roof, starts damp. It dries in
  the pouch after `wet.dry_h_game` (6 game hours, about 36 real minutes). Damp kindling doesn't
  catch, except the three damp-burners (birch bark, fatwood, Douglas-fir pitchwood; §CN). There is
  no other rain rule: anything can be gathered in any weather. This supersedes §CN's "gathered or
  carried in rain is wet" and settles its open question.
- **A cave's den is cleared by the hearth at its opening** (`camps.json →
  sim.overrun.cleared_when_nest`, `delves.json → fire_holders.nest_den`). A cave mouth or grotto
  camp that the dark takes is overrun (§CN). Until Phase 3 digs the caves beyond, its den is the
  small chamber behind the mouth. Its fire is the hearth at the opening, where the camp kept it
  (§CK's hearth spot, a pace in from the drip line). Laid and lit with the swing, that hearth
  clears the den, and whatever held it leaves.
  - This is the one exception to §CN's "the surface hearth does not clear it". That rule still
    holds for delves, where the den is deep and the clearing fire is at the heart.
  - When Phase 3 digs real caves, a deep cave is cleared at its heart, like a barrow.
  - It fills the gap Claude Code found: a taken cave-mouth camp was marked overrun with no fire
    that could clear it.
- **Ruins at the start, kept as built.** The world already opens with places long lost: an old
  hearth at every ruin with no camp and at every nest holding a camp's remains (§CK), and 30 % of
  old delve ruins overrun (21 of the 68 barrows within 150 km on seed 7731). Mike's line above is
  the reason for it. Raise the numbers if the world should open emptier.
- **Survivors, kept as built.** A camp turns to ruin only after 60 game days, so the survivors'
  30 days count from the day the ruin is marked overrun. That is Claude Code's reading of §CN.

## CP. The torch's head is a glowing ember — RECORDED (3 Oct, Mike to Claude Code; built `9e3e7ef`)

Mike to Claude Code (3 Oct): *"instead of the current fire animation, more of a glowing
ember."* Claude Code built it that night and asked for it to be recorded here.

- **The held and planted torches carry a coal, not a flame** (`shaders/torch_ember.gdshader`,
  `Torch.ember_node`): a small lumpy coal with a char crust and the fire's colour bands in its
  cracks, on a coarse texel grid, crawling slowly, with the fire's couple of single-pixel
  sparks.
- **The light keeps its energy, range and colour, but breathes with the coal**
  (`Torch.ember_glow`): a slow pulse, brighter when you sprint or the wind blows, lower and
  slower while guttering.
- **The lamps and every fire keep their flames.** This amends §BZ's one shader for the
  campfire and the torch: the torch has its own now.
- **Data:** `torch.json → ember` holds the code's own defaults, so nothing changes on screen.
  `light.flicker_hz`, `flicker_amount` and `wind_flicker_scale` are no longer read;
  `sprint_flicker_scale` still is (sprinting feeds the coal air).
- **Amended the same afternoon (built `b7ebed5`).** Mike: *"less like a ball on the end and more
  like a burned end of a stick: it shouldn't be rounded."* The coal is gone. The head is now the
  stick's own last few centimetres: six flat sides, black char with grey ash flecks, and hot
  cracks that thicken toward the tip, which glows most. It still breathes with the light. In the
  data, `ember.texels_m` (texels a metre) replaces `ember.texels`.

## CQ. Every torch is from somewhere; a carried coal brings a dead torch back — LOCKED (3 Oct, 01:30–02:25, Mike)

Mike (01:30): *"maybe we should make consumable ways to respark it?"* Anything that makes a
spark would break §BP, so what fits is a consumable that carries fire. Then (01:34): *"maybe
different types of wood torches and techniques to make them burn longer with sap? also, yea
we can have some sort of limited ember holder."* Put to him: each torch belongs to its place
(pine country gives fatwood and pitch, long and bright; the Pacific tropics give candlenut
strings, slow but small; birch country gives bark torches that burn fast but catch in rain);
the circle against the burn is the trade, and a bigger circle keeps the dark further back; a
pine camp teaches the pitch dip; the ember holder is one coal that slowly burns down. *"lock
it in"* (02:25). Builds on §AW, §BA, §BO, §BP, §CA, §CN, §CO and §CP. Not built, except where
marked.

**No spark, ever.** Flint and steel, a fire drill, or anything else that makes a spark stays
out (§BP, §CN). The consumable that brings a flame back is a coal carried from a hearth.

**1. Every torch is from somewhere** (`torch.json → kinds`). What you carry depends on where
you are, because the folk make each camp's bundle (§AW) from what they use and what grows
there:
- **First, the camp's own light.** Each people already has one, from the peoples fill
  (`data/peoples/*.json → light`, §BO): fatwood splints for the taiga and old-growth folk,
  candlenut strings for the tropical-forest and mangrove folk, the lake folk's birch-bark
  torch (their fishing torch's bark, a reed twist where no birch grows), dammar for the
  canopy folk, fir-candle splints in the marsh, ichu grass in the highlands, cane in the
  karst, rushlights in the mountains, and the herders' fire stick. It is made only where its
  plant grows (§CA).
- **Else a torch tree that grows there:** fatwood among pines (Douglas-fir pitchwood in the
  temperate rainforest, §CN), or birch bark among birches. If both grow, the commonest within
  the camp's gathering reach (`camps.json sim.loop.gather_reach_m`) wins.
- **Else a plain brand**, the torch as built. That covers the folk whose light is a lamp or
  nothing (coast, river, tundra, desert, steppe, rock shelter) where no torch tree grows.

You never craft (§BN): the bundles are the folk's work, and the light techniques (§BP) are
your own hand at the same kinds. As built, the **pitch dip** (`resin_torch`, taught by the
taiga and old-growth folk, done at any conifer) turns a brand or a birch-bark torch into a
resin torch. That is Mike's "a pine camp teaches you to tip a torch in pitch". The other
light techniques make their kinds once they are built.

**2. The trade is the circle against the burn.** Each kind sets how far its light reaches
and how long it lasts. First guesses, against the brand's 14 m and 50 minutes (Mike tunes by
play):

| kind | whose | circle | burn | in rain |
|---|---|---|---|---|
| plain brand | anyone's | 14 m | 50 min | shorter, as now |
| fatwood splints | taiga, old growth; any camp among pines | 16 m | 75 min | unchanged |
| birch bark | lake; any camp among birches | 17 m | 30 min | unchanged |
| candlenut string | tropical forest, mangrove | 8 m | 80 min | shorter |
| dammar | canopy | 15 m | 75 min | shorter |
| fir candle | marsh | 15 m | 40 min | unchanged |
| ichu grass | highland | 15 m | 18 min | shorter; a storm eats it |
| cane | karst; the lake folk where no birch grows | 15 m | 25 min | shorter |
| rushlight | mountain | 6 m | 60 min | shorter |
| fire stick | savanna herders | 14 m | 15 min | shorter |
| resin (the dip, built) | taught by the taiga and old-growth folk | 16 m (new) | 90 min | unchanged |

**The circle is how far the dark keeps back** (`dread.json → torch_circle`). The bigger your
circle, the slower the dread meter fills (§BA): `fill_per_min_torch` × 14 m ÷ your circle,
never faster than moonlight. A rushlight barely beats the moon; birch bark buys the most.
Stage 3's glimpses ("at the edge of the light") stand at the edge of your own circle instead
of a fixed 10–16 m. A planted torch counts with its own circle.

**3. Rain follows §CN's damp-burners.** The kinds made of them shrug off rain: birch bark,
fatwood and the marsh's fir candle (bog pine root is fatwood), like the resin torch as built.
Every other kind burns shorter in rain, as the torch does now. A storm shortens every kind,
and deep water puts every kind out.
- **A correction.** At 01:34 Claude called birch "the one exception to the damp-kindling
  rule". It isn't: §CN and §CO already let three kinds burn damp (birch bark, fatwood and
  Douglas-fir pitchwood). Nothing there changes, and the torch kinds follow the same three.

**4. A carried coal brings a dead torch back** (`torch.json → ember_relight`,
`techniques.json → ember_carrier`). Mike's "yes" settles §BP's "designer to confirm it
counts". As built, the ember carrier holds **one coal at a time**: you take it from a lit fire
with empty hands, it lasts `ember_game_h` (26 game hours), and a new fire can be laid from it.
- **New: blow it into a torch.** Hold an unlit torch while carrying a live coal: one press, a
  breath of about 3 s, and the torch catches. The coal is spent.
- It works on any torch with burn left: one that went out in water or when you put it away,
  or a spare from a bundle. A burnt-out torch is a stick and can't be brought back.
- This is the consumable respark Mike asked for, and it still starts at a hearth.
- **The key is Claude Code's call**, within §CN's scheme (right click is interact). Planting
  needs a lit torch, so this doesn't collide with it, and a fire in reach keeps its own
  interact.

**What the check found** (`tools/torch_kinds_check.py`: 11 kinds, 0 errors, 1 warning). The
gaps are plant-data jobs and Mike's call, as §CN's were:
- **Most camps leave something of their own:** fatwood across the taiga, the dry pine west
  and the pine coasts; fir candles in the marsh; ichu in the highlands; rushlights in the
  mountains; fire sticks with the herders; birch bark where the lake folk live among birches.
  Brands are left in the deciduous woods, on the prairies, in the hot desert, on open
  beaches, by the rivers and in caves.
- **The candlenut tree (*Aleurites moluccanus*) isn't in the catalogue** (the warning), so
  the tropical-forest and mangrove folk leave brands until it is added.
- **Birch grows in 8 biomes, but in the tundra, taiga and fen it is only a shrub birch**, as
  §CN found for kindling. The tundra's camps would leave bark torches of dwarf birch. A tree
  birch added to the north, or shrubs left out, would change that.
- **Dammar's tree (*Shorea*) grows only in the jungle**, so canopy camps in the other forests
  fall back to a torch tree or a brand.

**Supersedes or amends:**
- §AW's one torch: every torch now has a kind, and the brand is the torch as built.
- §BA's single torch rate: the dread meter's torch fill scales with the circle, and stage 3
  stands at its edge.
- §BP's ember carrier is confirmed, and it can now relight a torch. §BP's candlenuts are a
  small, slow light (the techniques list said "short").

**Proposed order (designer to confirm):** torch kinds and the camps' bundles → the circle in
the dread meter → the coal relights a torch. Candlenut strings wait for their tree.

## CR. The world at 1/100 Earth: shrink the gaps, not the things — LOCKED (3 Oct, voice to 13:01, Mike)

Mike (voice): *"At one one-hundredth of the size, we could potentially have it be ambitious
enough for us to actually fill the whole planet, while one tenth, I feel like that might be for
another game."* *"Just because it's [smaller] doesn't mean everything else should get scaled
down... while everything will get closer together, the actual size of things should not
change."* On mountains: *"it shouldn't change... the actual angles that you have to take to get
to the top. And some mountains might be above the clouds, as in real life."* On biomes:
*"everything in each biome should still essentially cover its same amount of ground relative to
how much it does in real life, with maybe the super small niche ones given a little bit more
extra room."* On time: *"I want it to feel like it takes about one tenth of the time instead of
one hundredth... I don't want you to just be able to climb a mountain in a snap,"* and *"some are
sheer walls, but a lot are also climbable."* Locked in text: *"Lock it in, my boy"* (13:01).
Data: `data/world_scale.json` (new), not wired. Numbers: `tools/reference/world_scale_reference.py`.

**1. The planet is 1/100 Earth: 400 km around** (radius about 63.7 km).
- 400 km is the size the geography is laid out on (`PlanetConst.GEO_CIRCUMFERENCE_M`). Its
  continents, mountain belts and climate were tuned at 400 km, and the 1/10 planet stretched
  them ten times sideways. At 1/100 the layout is built at its own size (`GEO_SCALE` 1).
- The size is a data value (`world_scale.json → planet.circumference_m`), so the two sizes can
  be compared in play.

**2. Things stay true size.** Everything you can stand next to keeps its real size: you, the
folk, creatures, plants, ruins and camps. Only the gaps between things shrink. Walking scale
already works this way.

**3. Heights stay at 1/10, and the sky with them.** An Everest-class summit is about 885 m.
Altitude bands, the lapse rate and the cloud layers keep following `HEIGHT_SCALE` as now. The
low cloud deck sits at 50–200 m (`CloudLayers`), so a great summit stands well above it, and
mountain weather can still wrap the flanks.

**4. Mountains keep real angles where you climb them, and some faces are sheer.**
- **The great ranges:** a handful per world (first guess 4–7), with summits of 500–885 m
  (5,000–8,850 m Earth-equivalent). Each one is an expedition.
- **A way up:** every great summit, or its high pass, has a walkable route (ridge, valley or
  switchbacks) averaging about 22° and never steeper than 35°.
- **Sheer faces:** cliffs of 60° and steeper on part of the flanks (first guess 15%). This game
  has no wall climbing (§AT), so a cliff is a barrier: it blocks and channels you, which makes
  the corridor shot (§BB). Ground steeper than 45° can't be walked up.
- **The one exception to honest shares:** at 1/10 heights on a 1/100 map, real angles need
  room, so the great ranges may take up to about three times their honest share of ground.
  Everything else keeps its honest footprint.

**5. Climbing takes time: Tobler's hiking function.** Walking up and down slopes slows the way
real walkers slow, scaled to the flat walk: factor = exp(−3.5 × |s + 0.05|) / exp(−3.5 × 0.05),
where s is rise over run, with no downhill boost. Sprinting slows the same way. At the ambient
walk of 4.3 m/s:

| grade | share of flat speed |
|---|---|
| 10° | 54% |
| 20° | 28% |
| 30° | 13% |

- An 885 m summit by a 20° route takes about 36 real minutes, which is 6 game hours: leave at
  first light and you top out around midday. By a 25° route it takes about 7 game hours.
- A 500 m summit takes about 3.5 game hours.
- So climbs cost Earth-like game time, a tenth of Earth's real time, as Mike asked. Open flat
  ground is where the compression lives: 10 km takes about 39 real minutes (6.5 game hours),
  and walking all the way round the planet takes about 26 real hours.

**6. Biomes keep their honest share of the ground.**
- Each land biome covers its Earth share of land.
- A biome that would get fewer than two places gets two, each at least about 1 km² (big enough
  to walk around in), so the small niche biomes can be found.
- Order: the engine first reports what the generator makes at 1/100. Then Claude (chat) fills
  Earth's reference shares, with sources, into `biome_shares.earth_reference`, and the
  generator is tuned to them.

**7. What it costs: the horizon (flagged for Mike).** On a 400 km planet the ground curves away
quickly. In the voice session the horizon was described as "a few kilometres". That is only
true from high ground.

| | 1/100 (this) | 1/10 (built now) | Earth |
|---|---|---|---|
| horizon from eye height | 450 m | 1.4 km | 4.5 km |
| a 30 m tower shows from | 2.4 km | 7.6 km | 24 km |
| a 100 m hill shows from | 4.0 km | 12.7 km | 40 km |
| an 885 m summit shows from | 11 km | 35 km | 111 km |
| the view from that summit | 10.7 km | 33.6 km | 106 km |
| the ground drops over 1 km | 8 m | 0.8 m | 8 cm |

- Long views still come from heights and toward tall landmarks, and things rise over the curve
  as you walk toward them.
- On flat ground, the curve ends the view at a few hundred metres, not fog. That tightens the
  locked look line "long view distance" on open ground.
- Mike judges it in play. The size is one data value if it needs to go back.

**Unchanged:**
- the 144-minute day and the year;
- everything at walking scale;
- old growth (§CS);
- the dev postage stamp (Claude Code's call whether it's still needed).

**Supersedes or amends:**
- **§I and the 29 Sept lock of 1/10 Earth:** distance goes to 1/100; heights and time stay 1/10.
- **27 Sept's "biome patch size stays about 10 km":** the patches follow the layout.
- **The Project brief's "a walkable sphere at 1/10 Earth (4,000 km around)":** Mike edits that
  line himself.
- **The look line "long view distance":** see point 7.

## CS. Plants live in communities, and every community has one home — LOCKED (3 Oct, 12:30 and voice, Mike)

Mike (12:30): *"it could be on other parts of our world but only if it mimics the specific micro
niche of the biome of which it's found."* By voice: *"just because a species could spawn
anywhere, it doesn't mean it should be scattered all throughout the planet... we should also take
into consideration their companion plants... so different biomes can be reminiscent of real-life
biomes, with the same types of plants that grow with each other,"* and *"each of those plants
before human intervention had their own communities and their own niches, and they weren't found
anywhere else on the planet."* Data: `habitat.json → communities`, not wired.

**1. Communities, not climate matches.**
- A plant grows only as a member of a community: an association, with its dominant, companion,
  ground and catalogue lists. The community places as a group.
- Each member still sits where its own bands, soil, light, water and nest fit. That is the
  micro-niche, and it is why a lotus would stand only in the warm, still shallows of its land.
- Nothing places on its climate numbers alone.
- **The leak Mike described is real.** Catalogue species (Amorphophallus, Trichocereus,
  Cannabis and the 1 Oct additions) place today by their own bands, the biome gate and the
  realm, and only 8 of the 203 associations list catalogue species.
  - A data fill attaches each one to the communities it really belongs to.
  - Until the fill lands, an unattached catalogue species keeps its current placement, and the
    check lists it.

**2. One home per community.**
- Before the player plants anything (§CT), each community is native to one land of the planet
  (a `RealmMap` province) and grows nowhere else.
- Each land's stretch of a biome gets its own community, and no community repeats in two lands.
  A far land always shows a different forest, desert or pond from the one you came from, and a
  pine forest isn't sprinkled across the world.
- The 1/100 planet (§CR) helps, because each biome has only a few stretches ("a couple to a few
  per biome").

**3. Dealt by niche, not Earth's map.**
- A community's home is a land where its niche exists: biome, temperature and frost, rain and
  its season, altitude, soil, sun or shade, water depth and flow for water plants, and its nest.
  The seed deals the homes.
- Communities from the same part of Earth are dealt together where they fit, so a land keeps one
  character (an Andean puna beside Andean cloud forest). Even so, any community can be native to
  any land whose niche matches.
- This answers §CM's open question: niche over map.
- *Keeping lands coherent is Claude's call; Mike may prefer a free mix.*

**4. Short biomes.**
- When a biome appears in more lands than it has communities, the extra stretch takes the
  community of the nearest land that has one (it spread across the border) until a fill adds
  more.
- The check lists the short biomes, and parallel agents add real Earth communities for them.
  Earth has plenty: the taiga alone has larch, spruce, pine and stone-birch forests.

**5. Old growth, reaffirmed.** It was locked 28 Sept and is built: `stand.json` mode
`old_growth` puts 82% of canopy trees in the top 30% of their size band, makes a quarter of
emergents giants, and keeps a thin young cohort in the gaps. Mike (voice): *"there shouldn't
necessarily be very very small things all the time... on Earth a lot of these trees are pretty
new, because all the old growth got cut down."* If small plants still read as too many in play,
the young share comes down.

**6. The freshwater note** (`37_freshwater.json`) put lotus on "tropical lakes (Amazon, African
Rift)". That was wrong: the sacred lotus is Asian and northern Australian, and the Amazon's
pond giant is the Victoria water lily. The note now describes the niche instead.

**Supersedes or amends:**
- **§AA's realm gate:** the provinces stay; communities are now endemic to one land.
- **§CA:** the biome gate stays, and the community decides what grows.
- **§CM's open question:** answered by point 3.
- **The Project brief's "every species grows only where it really grows":** now "every
  community lives where its niche is, in one land". Mike edits that line himself.

## CT. The human hand: carry plants and water them — LOCKED as an optional side layer (3 Oct, voice, Mike)

Mike (voice): *"it would be cool... to be able to start molding the world... by being able to
collect cuttings from the proper plants, which can actually grow from cuttings, and then seeds,
fruits, vegetables... or a tuber, like an amorphophallus... and potentially try to mimic the
habitat... maybe you could irrigate some stuff,"* and *"I would like to have the cultivation type
thing living within it, as a side thing that you can do if you wanted to. Not necessary."*

It builds on 30 Sept (seeds, cuttings and tubers are collected and planted where soil and water
allow, and plantings persist and grow while you're away) and on §BP's irrigation rule. Data:
`items.json → carried_plants`, not wired.

- **Optional.** No other system needs it. The player is the human hand of §CS, and planting is
  the one way a plant lives outside its home.
- **What you carry:**
  - seeds, from plants in seed, fruits and vegetables;
  - cuttings, only from species that really root from cuttings;
  - tubers and bulbs, such as an Amorphophallus corm or taro.

  A plant-data fill gives each species a `propagation` list (seed, cutting, tuber, bulb,
  division). Taking a sample is built; planting isn't yet.
- **A planting lives if the plot fits its niche** (§CS's list) and fails otherwise. The log says
  why: too cold, frost, too dry, too wet, the soil, or too shady.
- **Water is the one thing you can change.** Watering counts a plot one moisture band wetter
  (first guess). It uses §AB's soil water once that's built; until then, §BP's rule applies,
  and a plot by water or a dug channel counts as watered. Temperature, frost and altitude can't
  be changed; you choose them by where you plant, such as higher up a slope or in a sheltered
  hollow.
- **Open for Mike:** whether a planting spreads on its own (goes wild) from your plot. First
  guess: no.
- **Order:** after §AB's soil water, and after §CS.

## CU. A few hearths in every biome, no two alike; the danger is what lurks in the dark — LOCKED (3 Oct, voice, Mike)

**Hearths.** Mike: *"each community should also feel different too. So each hearth should be
unique... a couple to a few per biome."* Data: `camps.json → hearths`, not wired.
- Every land biome holds at least two hearths (living camps and the old hearths of ruins
  together). Big biomes get more, in proportion to their ground (first guess one per 150 km²).
- The sites pass never gives two hearths the same people, nest, ruin kind and plant community.
  With §CS, hearths in different lands always differ in their plants.

**The wording of the pillar.** Mike: *"dark necessarily isn't the antagonist. It's the things
which lurk in the dark."*
- The pillar now reads: what lurks in the dark is the only antagonist. The dark is where it
  lives, and light keeps it back.
- Nothing changes in play. §BA's dread and §CN's overrun ruins stand, and the cloaked shape with
  no species is a lurker, not the dark itself.
- Reworded: `CLAUDE.md`, `docs/OVERVIEW.md`, `README.md` and the `dread.json` help. Mike edits
  the Project brief's line himself.

**Untouched:** "no health-bar fight". Health pips, wounds and the blood trail are still being
talked through (2–3 Oct) and are not locked.

## CV. Smoke from every hearth; in the ruins a stack above each hearth; swifts in the cold ones — LOCKED (3 Oct, 14:28–14:54, Mike)

Mike: *"i like … the hearth smoke"*; then *"smoke from hearths should be locked — which likely
means that anywhere a hearth is, shouldn't it have a chimney? this way, you can tell from a
distance which ones are active and which ones may be overran"*; then *"there are some more
primitive camps on the surface but also the hearths in the various ruins which you have to
access from an underground tunnel usually — unless the particular hearth is in like a cave
mouth or something, then it's fine because the smoke has a way to clear out. in ruins, we can
make a chimney for smoke to escape above each hearth. it could also be a place for chimney
sweeps to nest in if the hearth is inactive."* (The bird he means is the chimney swift.)
Not built. Data: `data/smoke.json` (new, not wired); gate `tools/smoke_check.py`.

**Why.** A lit hearth is the one thing in this world worth walking to (§AW, §AX, §BA), and until
now you could only see it from its own clearing. On the 400 km planet (§CR) the ground curves
away 450 m from your eye. The top of a 60 m column of smoke still shows from about 3 km.

**1. Every lit hearth sends up smoke.**
- **Which fires:** a camp's hearth, an old hearth you rekindled (OldHearths), a nest's hearth
  (§CK) and a delve's hearths through their stacks (3). Torches, planted torches, lamps,
  braziers and sconces never smoke.
- **Size follows the fire** (`FireStore`'s own states, §AX): flames give the full column, low
  about half, embers a thin wisp, out nothing. The wisp is the tell that a fire can still be
  saved (§BL: embers linger).
- **It leans with the live wind** at that place (the weather sim's). In still air it stands
  straight. On a still dawn it stops rising and lies flat over the valley. Rain beats it down.
- **At night the column isn't drawn.** Smoke gives off no light. The fire lights the first few
  metres of its own smoke and the canopy above, so a camp shows as a warm glow (§BZ: fire is
  the one warm accent).
- **The look** is the flame's family (§BZ): a few camera-facing cards, noise scrolled upward
  and posterised to two or three flat bands on a coarse texel grid, cut out by dither with no
  soft alpha. It is pale blue-grey, never a neutral grey (LOOK_REFERENCE R3), and it gets
  lighter and bluer with distance like everything else.
- **Far hearths.** A camp that isn't loaded still has a fire state in the sim (§BL: unloaded
  camps tick as numbers), so its column is drawn from that number. First guess: out to 3.2 km.
- Under the trees you mostly can't see it, because the sky is a gap (§BB). It pays at the
  reveal: a ridge, a shore, a clearing.

**2. Surface camps and nests need no chimney.**
- Camps are tribal and their fire is open: you sit round it and borrow from it, and its light
  is the safe circle (§AW, §BZ, §BA). The smoke rises free. `peoples/mountain.json` already says
  "no chimney, the fire in the middle".
- A cave mouth, grotto or other hearth under rock (§CK, §CO) clears its smoke through the mouth
  and up the cliff. The soot above the mouth stays when the fire is out.

**3. In the ruins, a stack above each hearth** (Mike).
- A delve's hearths are underground (§CJ, §CN). Each has a flue up to the surface that ends in
  a stack. First guess: the first room's old hearth and the heart each get their own; braziers,
  sconces and the other rooms' rings vent through the nearest one.
- **The form follows the ruin** (first guesses; `outlets.by_ruin`, the same kinds as
  `delves.json → fire_holders.by_ruin`):

  | Ruin | Stack |
  |---|---|
  | castle | a masonry chimney stack |
  | tower | a flue in the wall, smoking from the top |
  | barrow, tomb, a people's ruin | a stone-lined vent on the mound |
  | mausoleum | a roof vent |
  | pyramid | a shaft high on the face |
  | aqueduct | a vent shaft, like a qanat's |
  | igloo, treehouse, boardwalk | none: an open fire (ice and wood don't last, §BQ) |

- **A ruin's surface old hearth:** in a castle or tower it is a fireplace under a standing
  stack, open at the front so the swing (§CN), the light and the safe radius work as built.
  Elsewhere it stays the open ring. First guess.
- The stack is stone, so it is part of what doesn't rot (§BQ) and is often the last thing
  standing. Its lip is black with soot, so it reads as a chimney and not a pillar.
- A flue is never a way in or out (§CJ.4's way out is unchanged).
- At night a lit hearth below shows as a faint glow and a few sparks at the stack's mouth.

**4. The read from a distance** (no UI):

| What you see | What it tells you |
|---|---|
| a column of smoke | lit: a living camp, or a hearth you lit yourself |
| two columns over one ruin | the heart is lit, so the delve is cleared (§CN) |
| a thin wisp | embers: get there soon |
| a stack or a sooted cave mouth, no smoke | a hearth is here and it is cold: empty or overrun. You learn which up close, from §CN's tells, which are unchanged |
| swifts pouring into the stack at dusk | cold for a while, and nothing burning below (5) |

**5. Swifts take the cold stacks** (Mike).
- **The real bird.** The chimney swift (*Chaetura pelagica*) nests and roosts in chimneys, old
  wells and cisterns; before there were chimneys it used caves and the hollow trees of
  old-growth forest. Its nest is a half-saucer of twigs glued to the wall with saliva. It can't
  perch: it clings to the wall. At dusk the flock funnels in together, thousands on migration.
  Vaux's swift does the same in the west. Sources: All About Birds, *Chimney Swift: Life
  History*; Wikipedia, *Vaux's swift*.
- **In the game.** A stack whose hearth has been cold a while may hold a flock (first guess:
  after 10 game days, in 60 % of the stacks wide enough, where the climate suits). By day they
  hunt insects over the ruin. At dusk they circle and pour down the stack, which makes them
  part of §CH's handover and the day's mirror of the bats. At dawn they pour back out. Their
  chatter is a point source at the stack (§BG).
- **Light the hearth below and they leave at once.** They stay away while it smokes and come
  back after it has been cold again. A stack shows smoke or birds, never both.
- **First guess, for Mike to confirm:** no swifts over an overrun delve, because the place
  goes quiet (§CN). Then a cold stack with no birds at dusk, where the others have them, is
  the far-off hint that something holds it. It is only a hint: not every empty stack has swifts.
- **Later:** the same birds in hollow snags (§AF; every stand is old growth), and each land's
  own swift by realm (§AA, §CS).

**6. A wildfire has its own plume.** Proposed in chat and not objected to; Mike can strike it.
It is wide, tall and dark, it leans with the wind, and its base is lit orange at night. A
hearth's column is narrow and pale, so the two are never mistaken. §BL's wildfire rules are
unchanged.

**Untouched:** fire is still only carried (§BP); the fire's light, sound and safe radius (§BZ,
§BA); how a delve is cleared (§CN, §CO).

**Open for Mike:** one stack per hearth or one per delve; whether swifts avoid overrun ruins;
the wildfire plume.

## CW. No waiting, no speed-up — LOCKED (3 Oct, 14:49, Mike)

Asked whether sitting at a lit hearth should let the night pass faster, Mike: *"there should
be no wait mechanic or speed up."*
- The clock never skips and never runs faster. There is no sleeping until dawn, no waiting and
  no time-lapse at a hearth. A night lasts as long as the 144-minute day gives it (48 real
  minutes at the equinox reference).
- "Rewarding stillness" (animals coming closer and far sounds carrying when you stop) is liked
  and still being talked through. It is not locked and has no data.

## CX. Rain falls only from a raincloud you can see — LOCKED as a rule (3 Oct, 14:58, Mike); the colours are open

From Mike's 3 Oct play: the HUD read "Rain" and rain fell from a clear cobalt sky, and
"Overcast" showed a blue sky with hard shadows. Mike: *"the sky looks clear but it's raining.
need rainclouds to form for rain to happen."* The causes are in PROGRESS (3 Oct, the play
entry). Not built.

**The rule.**
- Rain falls only where a raincloud is overhead and drawn. No visible cloud, no rain.
- The cloud comes first. It builds, the light under it drops, then the rain starts. The rain
  stops before the cloud clears.
- One value drives everything: the drawn cloud, the HUD's word, the rain streaks, the rain
  sound and how much the sun dims all read the same cover overhead. Today the rain reads a
  separate field from the clouds.
- "Overcast" on the HUD means the sky looks overcast.

**Open for Mike (no locked section covers these):**
- **The colour of an overcast or rain sky.** The look rules still bind it: never grey
  (LOOK_REFERENCE R3), blue owns the frame, and §BB's "dark days do not mean dark skies".
  First guess: deep indigo decks with a lighter lit edge (on screen about `#6878C8` lit over
  `#06186C` shade), and for storms the purple of the spec's R1a (`#5A1AA0`), in two or three
  flat bands. The code's storm sky is grey today, which breaks R3.
- **Shadows under cloud.** Today cloud only dims the sun by up to 55 % and the shadows stay at
  full strength. First guess: under a full deck the shadows fade but keep their hard edge (§C).

## BR. Order of work — prompt C (after A and B are played; §BR sits after §CE on purpose — it is the to-do)

Data first: the seventeen people files (parallel research agents against `coast.json`,
`peoples_check --strict` 0 errors), `techniques.json`, `camps.json → sim`. Then the engine:
§BL store and loop and ticks (catch-up on load) → §BM population and the ladder with
`crop` and `fish_run` only → §BN the three faces (headman bestows: the log line, the
technique flag) → §BP the fishing line, coppice, resin torch, ember carrier, fat lamp → §BQ
signature heaps at ruins, restoration as legibility, inheritance → §BL collapse (the dark
takes a camp, survivors walk), wildfire. Herd and managed burn last.

**Added 1 Oct (§BV–§BZ, the 30 Sept night session), in this order:** the fire first (§BZ:
the one-card posterised flame, the night swell, the two-layer crackle — one shader for the
campfire and the torch; the cheapest change and the most seen) → the opening camp at four
or five with the jobs (§BV) and a piece per trip in the wood of the place (§BW): the walker
in `camps.gd` grows a destination and a load, `refresh_woodpile` becomes add/remove → the
opening road and the afternoon clock (§BX; the start-of-dusk spawn in `main.gd` goes; the
first landmark is a camp at a ruin) → desire lines and the lost-and-found stretches (§BY).
Data is in; all first guesses.

**Added 1 Oct, afternoon (§CA), and it goes BEFORE the rest of the above:** the biome gate
and the walkabout check, the `biomes` fill of the catalogues (parallel agents), the aroid
and giant-herb hulls to leaf cards, the torch flame on the stick, the afternoon spawn. A
world where the wrong plants grow is not a world yet; nothing visual is "done" until the
walkabout passes. **§CC (the trim) runs with the §CA gate — tag only what survives — and §CB (a new world is a new world) goes first of all** — it is small and it changes what the designer sees on the next boot.

**Status 1 Oct, 12:30 (Chicago):** §BZ the fire — built (`1286ac6`, `affbfbf`). §CB a new
world, the first camp's kind, and §BX's afternoon clock — built (`466e2c8`). Next: §CC
the trim (with the seed list), then §CA the gate, no blobs, the torch flame on the stick,
and the walkabout. Then §BV–§BW the working camp, §BX the opening road, §BY the roads.

**Status 1 Oct, 13:10:** §CA's gate, the catalogue tags, no lobe hulls and the torch flame — built (`9dd1c23`; its walkabout waits for §CC). Queue: the Mac-GPU pass (Day 1, the F9 foliage views, derivative and null-texture fixes) → §CC the trim → the epiphyte pass (real branches, a shape per kind, §CD the resurrection).

**Status 1 Oct, 23:40:** §CG goes first of all: the tiles off the import cache, Day 1 and the
local midnight, frames labelled, and the end-of-pass check run as the designer's machine
has it. It takes over the Mac-GPU pass's Day 1 and null-texture items; the F9 foliage views
and the derivative item stay queued (not the cause of the grey boxes).

**Added 1 Oct, night (§CH, §CJ):** audit before building — both lean on systems that do not
exist yet (the Phase 7 ledger, Phase 3 caves). Proposed: §CH's roster swap and the sound by
phase first; then the first delve type on a ruin that can already be walked into (the barrow
or the desert pyramid), with its loop back out; the cave types after Phase 3.

**Status 2 Oct, 01:45 (from PROGRESS):** built since 13:10:
- §CG, the game without the import cache, Day 1 and one clock, every frame labelled;
- §CC, the trim;
- §CE, the named plants and vines;
- the §CA walkabout;
- §BC and §BX, roads to every camp and the opening road;
- §BL–§BT, the camps alive (the store and the loop, the ladder, the headman's techniques,
  collapse, wildfire, the canopy folk);
- the 1 Oct look pass and the Mac fixes;
- §CF, the favourites measured.

Still queued, with Mike's prompts setting the order:
- §BV–§BW, the working camp (no code reads `sim.opening`, `sim.jobs` or `store.pieces` yet);
- §BY, the desire lines and the lost-and-found stretches;
- the epiphyte pass (§CD);
- the herd and the managed burn;
- §BI, trade.

§CH and §CJ are to be audited first, as above.

**Added 2 Oct (§CK–§CM):** the data is in (`landforms.json`, `uniques.json`, the
new species and associations, `items.json → mad_honey`). The rhododendron forests, the new
ferns and the sacred fig's wild trees need no code: they grow when the data loads. The
engine order: **tier-1 nests and the camp move** (a sites pass reading `landforms.json`;
camps and their remains at nests, monuments kept; `Peoples.pick` reading the nest first;
the cliff-shelter hearth off the drip line; cave mouth and grotto as meshes; the cenote;
slot canyons from the ravines; the glowing bay on the glow ponds) → nest plants (§CM) → the
sacred fig and its figure (§CL) → tier 2 → tier 3. Mad honey waits for the item and food
systems. Where this sits against §CH and §CJ's audits is Mike's call.

**Added 2 Oct, afternoon (§CN):** the data is in (`torch.json → swing`, `fuel.json → kindling` with
33 kinds over 52 biomes, `camps.json → sim.overrun`, the new `delves.json`), none of it wired. The
engine order: **the swing** (left click passes the flame; right click stops lighting) → **the laid
fire and kindling** → **overrun ruins on the built barrow delve** (fire-holders, the den,
clearing) → **folk coming back**. Mike's Claude Code prompt of 2 Oct, 14:25 carries the same spec.

**Added 2 Oct, evening (§CO):** two small follow-ups to §CN, with the data in and not wired. First
**the pouch keeps kindling dry**: only kindling gathered in rain starts damp, and it dries. Then
**a cave's or grotto's den is cleared by the hearth at its opening**.

**Added 3 Oct (§CP, §CQ):** §CP records the torch's ember head, already built. §CQ's data is in and
not wired: `torch.json → kinds` and `ember_relight`, `dread.json → torch_circle`, and the
`techniques.json` params (`tools/torch_kinds_check.py` checks them). The engine order: **torch
kinds and the camps' bundles** → **the circle in the dread meter** → **the coal relights a
torch**. Candlenut strings wait for their tree.

**Added 3 Oct, afternoon (§CR–§CU):** the data is in and none of it is wired: `world_scale.json`
(new), `habitat.json → communities`, `camps.json → hearths` and `items.json → carried_plants`.
The proposed engine order:
1. **The planet to 1/100**, with `circumference_m` read from data and `GEO_SCALE` 1. Measure
   before tuning anything: slope shares, the great ranges and their routes, biome shares and
   the horizon.
2. **Tobler's pace on slopes.**
3. **The great ranges:** routes, cliffs and the footprint exception.
4. **Communities:** the placer draws from the stretch's community, homes are dealt per land,
   and catalogue species go through communities. This waits on Claude's attach fill, so it is
   built with the fallback.
5. **Hearths per biome.**
6. **Carried plants**, after §AB.

Biome-share tuning waits on Claude's Earth reference fill.

**Added 3 Oct, 15:00 (§CV–§CX):** the smoke data is in and not wired (`data/smoke.json`, gate
`tools/smoke_check.py`). §CW is a rule with nothing to build. §CX is a rule; its fix is in the
play-test prompt of 3 Oct, with the other bugs from that play. The proposed engine order for §CV:
1. **The column over a lit hearth**, from `FireStore`'s state, leaning with the weather sim's
   wind; the night glow instead of a column.
2. **Far hearths:** the column drawn from the camp sim's fire state for camps that aren't loaded.
3. **Stacks and vents** on the built barrow delve (a vent over the first room and one over the
   heart) and the sooted mouth at the cave-mouth and grotto nests; castle and tower stacks when
   their delves exist.
4. **Swifts in the cold stacks**, after §CH's dusk handover.
5. **The wildfire plume**, if Mike keeps it.
