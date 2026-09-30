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
starting_kit_ambient` · `data/audio.json → new kinds`.

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
  camp, a food surplus, and a slow clock** (`sim.births`); an isolated camp can grow. A
  child is a small figure by the fire who does not gather and grows up in ~40 game days
  (Mike to confirm vs "an adult after a delay"). Folk are men and women; the rig reads it
  at silhouette distance (build, height, voice).
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

## BR. Order of work — prompt C (after A and B are played; §BR sits after §BT on purpose — it is the to-do)

Data first: the seventeen people files (parallel research agents against `coast.json`,
`peoples_check --strict` 0 errors), `techniques.json`, `camps.json → sim`. Then the engine:
§BL store and loop and ticks (catch-up on load) → §BM population and the ladder with
`crop` and `fish_run` only → §BN the three faces (headman bestows: the log line, the
technique flag) → §BP the fishing line, coppice, resin torch, ember carrier, fat lamp → §BQ
signature heaps at ruins, restoration as legibility, inheritance → §BL collapse (the dark
takes a camp, survivors walk), wildfire. Herd and managed burn last.
