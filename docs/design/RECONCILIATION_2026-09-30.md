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
fire`. Added 1 Oct afternoon with §CA–§CB: `data/habitat.json` · `data/dev.json → pin_in_play, spawn_choice -1` · `data/camps.json → first_camp`. With §CD: the resurrection fern's `desiccation` block. With §CE: `habitat.json → always_present, trim.always_keep, vine`, `data/vines.json`. With §CK–§CM (1 Oct, night): `data/landforms.json` (gate `tools/landforms_check.py`) · `data/uniques.json` · the sacred fig, two rhododendrons and two desert ferns in the biome files, two rhododendron associations, ferns in three associations · `habitat.json → always_present.rhododendron` · `items.json → mad_honey`. With §CY–§CZ (3 Oct, 15:45): `roads.json → opening_road.dawn_start` · `camps.json → sim.fire_circle` · `look.json → fire.coals, fire.specks, fire.light.breath` (gate `tools/fire_circle_check.py`). With §DA–§DL (3 Oct, the morning voice session, written up at 17:07): `data/wind.json` · `data/senses.json` · `data/shrines.json` · `data/tomes.json` · `data/day_accents.json` · `look.json → lens_flare, shafts, moon_nights` · `hud.json → calendar, log_more` · `camps.json → wake_found` · `dread.json → full_moon` · `sky/day_cycle.json → full_moon_illumination` · `ruins.json → overgrowth, haunt` · `audio.json → ruins` · `items.json → scroll, tome`; reference maths `tools/reference/beacon_reference.py`, `tools/reference/moon_reference.py`. With §DO–§DS (3 Oct, 21:24, the monuments and the sages): `ruins.json → styles` (nine new kinds and two styles, `kind` field) and `root_trees` · `uniques.json → uniques.wandering_fire, road_regulars` · `tomes.json → tao` · `smoke.json → outlets.by_ruin` rows · `delves.json → fire_holders.by_ruin` rows. With §DT–§DZ (3 Oct, 21:48): six more kinds in `ruins.json → styles` (hanging_gardens, abbey, colonnade, temple_park, pillar_shrines, hewn_temple), `haunt.kinds` gains the abbey, `landforms.json → landforms.columnar_basalt` (two variants; gate 0 errors), and their smoke and delve rows.

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

**3 Oct: outside the gather hours the folk sit in the fire circle (§CY). At the dawn spawn
they are at rest, and these jobs begin as the circle breaks.**

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

**3 Oct: §CY moves the spawn to dawn and the road to about 40 minutes, reached before dusk.
The clock and the length below are superseded; the rest of this section stands.**

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
- **Every new world opens on Day 1**, in §BX's afternoon (from 3 Oct, §CY's dawn). The day number counts your local
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

## CY. You wake at dawn in the fire circle; the next hearth before dusk — LOCKED (3 Oct, 15:20–15:27, Mike)

Mike: *"around the campfire when you spawn they could actually be sitting on the biome
appropriate seat like a rock or log. might see them packing a pipe and smoking. just chilling
out around the fire. perhaps we can actually have it to where the player spawns in at dawn."*
Then: *"move to dawn and you'll reach another landmark by dusk"*, and: *"or before dusk, but
hopefully dusk at the latest if spawning in at dawn."* Data: `roads.json →
opening_road.dawn_start` and `camps.json → sim.fire_circle`, neither wired. Gate:
`tools/fire_circle_check.py`.

**CY.1 The dawn start.** This supersedes §BX's afternoon clock and its half-hour road. The
rest of §BX stands: you wake beside the road, the first landmark is a camp outside a ruin,
its hearth glow is the beacon, and only the opening road is tuned.
- **You come to in the first minute of dawn** (`spawn.real_min_after_dawn_begins`), while the
  world is still blue and the fire is the one warm thing in view. It is still Day 1 (§CG), and
  the sky keeps its clock: `START_DAYS` taken to the dawn at the spawn, so the first night's
  moon is the same near-full one.
- **The road to the first landmark is about 40 minutes of straight walking**
  (`walk_real_min`), measured at the pace you really walk it (§CR.5's slope pace), not in
  flat kilometres. That is about half of the daylight you wake with. It is 10.3 km if the
  ground were dead flat (`length_km_hint`) and about 8.5 km on ordinary land, where the swells
  hold you to about 82 % of the flat speed (`pace_share_typical`).
- **Smoke marks both ends** (§CV). On a still dawn the camp's own column lies flat over the
  valley, so on a calm morning it is in your first frame. By day the next hearth's column is the far beacon
  (its top shows from about 3 km), and at dusk its glow takes over (§BX).
- **Dusk is the latest, not the target.** The opening day at the reference (equator,
  equinox; a game hour is 6 real minutes):

  | | game clock | real minutes after waking |
  |---|---|---|
  | you wake | 04:10 | 0 |
  | the circle breaks (CY.5) | 04:30–07:00 | 2 to 17 |
  | a straight walk arrives | 10:50 | 40 |
  | dusk begins | 17:00 | 77 |
  | a walk that spent as long looking as walking arrives | 17:30 | 80 |
  | full dark | 20:00 | 95 |

  A straight walk reaches a working camp late in the morning (§BV's jobs), and you are there
  when its circle forms at dusk. A walk that dawdles has all of dusk as its grace, with the
  glow ahead.
- **The day fits at every latitude.** On the world's first day (day 13.62 of the year),
  waking to dusk is between 76 and 98 real minutes everywhere from 66°S to 66°N
  (`fire_circle_check.py`, on the game's own clock), so a straight walk always has at least 36
  minutes in hand. The calendar does not move: §CG's moon and season stand. For any other
  start date the rule is in the data (`slack_before_dusk_min`): where the day is too short,
  the road is shortened to fit, never the clock moved.
- **After a death, §P stands:** you wake at "whatever hour it is". Outside the gather hours
  that is the circle; inside them it is a working camp.

**CY.2 The fire circle: what a camp does when it isn't working.**
- **Outside the gather hours** (`loop.gather_hours`, 07:00 to 17:00), every folk who isn't on a
  job sits in a ring round the fire. This is true of every camp, and it is what you wake into.
  It amends §BV: at the dawn spawn the four or five are at rest, and their jobs begin as the
  circle breaks.
- **An idle is a small task with one prop, never standing and breathing.** That is how the
  figures in Mike's reference sheets are drawn (`docs/references/project_sheets.md`): frame
  52 is a robed figure sitting on a stone ledge by a campfire, preparing food in its lap;
  frame 44 sits on a bench with a steaming mug; frame 41 leans over a stone bowl.
- **One seated pose for every cloaked figure**, with loops for the arms and the hood on top
  (`pose`). The cloak pools over the seat and hides the legs, so nothing below the waist has
  to be exact (27 Sept doc: the crouch rule). No new rig and no per-species animation (the
  Falcon/Ganondorf rule): small folk and big folk play the same loops at their own scale and
  timing. Children play the resting ones (watch, warm hands, poke, eat, doze) and never the
  pipe.
- **The loops** (`idles`, each weighted by the phase of the day):
  - `watch_fire`: sits still and looks into the fire. The resting state between the others.
  - `warm_hands`: hands out to the fire, turned, rubbed together.
  - `poke_fire`: stirs the fire with a stick, and the fire throws specks (§CZ).
  - `feed_fire`: stands, takes a real piece off the woodpile, lays it on, sits back down.
    This is §BV's job, done from the circle.
  - `pipe`: CY.4.
  - `eat_bowl`: a bowl lifted to the hood. Only when the food store isn't empty.
  - `sit_work`: §BV's hearth-worker, mending and shaping, by day and at dusk.
  - `doze`: the hood sinks and nods, starts, settles again.
- **They notice you** (`notice`): inside 7 m the hood, and only the hood, turns to follow
  you, holds for a couple of seconds, and goes back to the fire. These are the travellers'
  head-turn values (`travellers.json → head_look`). A dozer doesn't notice.
- **One seat is left empty** (`spare_seats`), so there is a place in the ring to step into.
- **Nothing here changes a sim tick.** It is the camp's rest made visible, as the jobs are
  its work made visible (§BV).

**CY.3 Seats are found things, and they belong to the place** (`seats`).
- Ten kinds, none of them built furniture: a log, a stump, a root (a cypress knee, a buttress
  flare, a mangrove prop root), a rock, a flat stone, driftwood, a hummock, a mat on bare
  ground, a fallen block at a ruin camp, and the canopy folk's own limb.
- `by_biome` lists what each of the 44 biomes with a people can offer, commonest first, and a
  fire has at most two kinds. Examples: taiga has logs and stumps; swamp has cypress knees
  and stumps; the steppe has mats and rocks; a beach has driftwood; a ruin camp adds fallen
  blocks.
- **No seat the place couldn't supply.** A wood seat needs wood in that biome and a
  driftwood seat needs driftwood (`fuel.json → biomes`); the check enforces it.
- **A wooden seat is the wood of the place:** it takes the bark tint of the stand's dominant
  species, as the woodpile does (§BW). Stone seats take the terrain's own stone.

**CY.4 The pipe.**
- Adults only, and one pipe at a fire (`max_at_once`).
- In order: pack the bowl, lean in and light it **with a brand from the fire**, puff three to
  six times with rests between, tap it out on the seat. The flame is borrowed like every
  other flame (§BP); nobody strikes a spark.
- **The smoke is a few square puffs** (the look of the steam over the mug in reference frame
  44) on one camera-facing card, rising and drifting with the weather's wind at the camp. It
  is the hearth smoke's family (§CV, `smoke.json → hearth.look`): the same pale blue-grey in
  flat bands with a dither cut-out, never a neutral grey, and never glowing. The bowl's ember
  is one glowing pixel on the draw, and it casts no light.
- **Open, for Mike:** what is in the bowl. It is not named anywhere yet.

**CY.5 The circle breaks at dawn and forms at dusk.** The same loops in opposite order
bracket the day.
- **Dawn** (`dawn_break`): over the last two and a half game hours before the gather hours
  begin (15 real minutes), the sitters rise one at a time, dozers last. Each stretches,
  stands, shoulders a basket or bundle and walks out. One stays to keep the hearth, and the
  children stay by the fire.
- **Dusk** (`dusk_form`): from the end of the gather hours, over an hour and a half of game
  time (9 real minutes), folk come in carrying, drop the load on the store (the day's last
  real piece, §BW), and sit. The bowls and the pipe come out.
- **Night** (`night`): one stays awake to feed the fire (§AX) and most of the rest doze where
  they sit. Shelters stay as they are; nobody is drawn asleep inside one yet.
- **Nothing speeds the clock** (§CW): the circle breaks and forms in real time, and you can
  walk away from it at any point.

**Touches:** §BX (clock and length superseded), §CV (pipe smoke takes the hearth smoke's
look), §CG ("§BX's afternoon" now reads "§CY's dawn"; Day 1 and the sky's clock stand), §BV
(rest at the spawn, then the jobs), and 27 Sept §P beat 1 (dawn was its first preference).
All numbers are first guesses; the designer owns them.

## CZ. The fire breathes: coals that pulse, specks thrown at random — LOCKED (3 Oct, 15:35, Mike)

Mike: *"the fire animations should be a bit more embery and pulsating kind of like in real
life — embers at the base oscillating and pulsating while the specks of ash fly out above
randomly."* Data: `look.json → fire.coals`, `fire.specks` and `fire.light.breath`, not wired.
Gate: `tools/fire_circle_check.py`.

**How this is read.** It adds to §BZ and does not replace it: the one camera-facing flame card
stays, and the fire gains a living bed beneath it and random specks above it. If Mike meant
the flame to go, as the torch's did (§CP), that is one line to change.

**What is there today** (built, §BZ): the coals are one flat orange shape that never changes,
and six embers each climb at one steady speed on a loop of their own.

- **The bed pulses** (`fire.coals`). The foot of every fire is a bed of coals on a coarse texel
  grid: char crust with hot patches in the flame's own colour bands.
  - The whole bed **breathes** slowly, about once every three seconds.
  - Each patch of coals **brightens and dims on its own clock**, out of step with its
    neighbours, while the hot cracks crawl.
  - **Air feeds it:** a gust of the weather's wind, a poke (§CY's `poke_fire`) or a fresh
    piece laid on makes the bed flare, then settle.
- **The light breathes with the bed** (`fire.light.breath`), on top of §BZ's noise flicker,
  so the pool of light on the ground pulses with the coals.
- **Specks fly out at random** (`fire.specks`). They replace the steady drift of
  `flame.embers`.
  - They leave on a **random clock**, never a loop the eye can learn: sometimes two close
    together, sometimes a long lull, mostly one to four at a time, and now and then a shower.
  - **Every pop and snap of the fire's sound throws its burst at the same instant**
    (`audio.json → fire.pops`), so the ear and the eye agree. Laying a piece on, or poking,
    throws a big one.
  - Each speck leaves at its own speed inside a cone, slows as it climbs, curls, and drifts
    with the wind.
  - **Seven in ten are sparks:** the flame's orange, cooling to red, then gone.
  - **Three in ten are ash:** pale flakes in the hearth smoke's blue-grey (§CV; never a
    neutral grey, LOOK_REFERENCE R3) that do not glow. They show by the fire's own light,
    last longer and flutter.
- **A low fire is its bed.** When the fire has burned down to embers there is no flame card
  (§BZ), so the bed is the whole fire, breathing slower and deeper, with a rare speck. A dead
  fire throws none.
- **The torch keeps its burnt end** (§CP). Lamps keep their flames.

All numbers are first guesses; the designer owns them.

---

# Voice session — 3 Oct 2026, morning: the air moves; the moon sets the night; the lurkers have eyes; a scroll to carry

Talked through by voice on the morning of 3 Oct and written up after Mike's 12:24 message
(*"please write it up claude"*) and his 17:07 one (one Claude Code prompt per idea). Mike, at the
end of the call: *"Yep, go ahead and lock it in … I'll prompt you to please lock it all in."*
Written up after the afternoon's sessions locked §CR–§CZ (the 1/100 planet, the communities, the
hearths, smoke from every hearth, no waiting, rain from a raincloud, the dawn wake-up, the fire
that breathes), so where this morning's ideas touch those, the section says how they fit. Where an
idea touched a locked rule in the call it was flagged there and settled; where Claude only saw a
clash while writing it up, the section says so and leaves it open. Builds on §AW–§BG, §BL, §BO,
§BQ, §CG, §CH, §CJ, §CN, §CQ and §CR–§CZ. The data is in and none of it is wired.

**Considered and dropped:** a fan to coax embers and feed a fire (Mike: *"let's forget about
the fan"*).

**Corrections to the voice call** (things Claude said there that the locked doc doesn't bear
out; the sections below follow the doc):
- the hidden folk would be "the only voices in the world": camp folk already have their line
  (§BF, §BO);
- "a warm shaft" of sunlight: fire is the one warm accent (LOOK_REFERENCE R7), so shafts are
  cool;
- secrets "hand-placed": on a generated planet they are hand-made set pieces placed by rule
  (§CJ.8);
- Minecraft's cave groans as a ruin's sound: §BG took untrackable noises out on 30 Sept, so
  they are not written (open, §DI);
- "the dark is your antagonist, not the clock": §CU has since reworded the pillar (what lurks
  in the dark is the antagonist), and who is in a ruin by day still keeps §CH's and §CN's clock;
- "death-to-hearth" as something new: it is §AY (30 Sept). This session adds where you wake
  without a home, the lost days and the folk who found you;
- "smoke signals" as a new idea: smoke from every hearth was locked that afternoon as §CV, so
  §DA only adds what the wind does to the column.

## DA. The wind you can see: one wind, gusts that travel, and what it does to the smoke — LOCKED (3 Oct, by voice, Mike)

Mike: *"whenever I step outside, I might feel a little breeze. I might see the leaves rustling.
I might hear them. I might hear some cicadas. I might see some like leaves being blown across
the yard … clouds blowing"*; *"we already have some type of wind weather type system thing, but
it doesn't necessarily feel too good"*; *"basically where the wind, the directional, you can
actually see … the wind moving the trees and the plants, blowing leaves across the ground, and
also like the smoke from the fire, and maybe make it to where … one of the ways you can actually
find camps far off is by looking for the smoke signals."* Asked whether the wind or the sound
first: *"Both, but let's focus on the wind first."* Builds on the live wind and water cycle (27
Sept §0: *"keep"*), §BD, §BG, §BS, §CL, §CV (the smoke column) and §CZ (the fire's specks drift
with the wind, built). Data: `data/wind.json` (new). Reference:
`tools/reference/beacon_reference.py`. Not built.

**One wind, and everything answers it.** The weather's wind (`WeatherSim.local_weather`,
live) is the only source, sampled where each thing stands, with gusts on top. Grass, crowns,
ground litter, cloaks, water, smoke, the fire's specks, rain, clouds and the rustle all read the
same wind and the same gusts, so they move together and the air reads as air. (A sphere has no
single direction for the whole planet: it is the weather's wind where you are.)

**What's wrong today** (found in the code, 3 Oct):
- Every plant sways on its own sine wave with its own phase (`foliage.gdshader`), so
  neighbours move out of step and nothing travels across a field or a wood.
- The weather's own gusts (`local_weather`) are swells about 1.2 and 0.5 game hours long:
  minutes of real time, a slow freshening, not a gust.
- Nothing on the ground moves with the wind but autumn's falling leaves. Water ignores it. No
  fire draws smoke yet (§CV is designed, not built).
- Plants sway as hard under a closed crown as in the open. Only the bed's wind sound closes
  under canopy (§BG).

**The fix:**
1. **Gusts travel.** A gust field in real seconds: patches of stronger and weaker air carried
   downwind at the wind's speed, which every reader samples at its own position. You see a gust
   coming: a paler, bowed patch runs over the grass toward you, then the crowns round you toss
   and their rustle rises, then it's past. Neighbours move together. The strongest gusts are 1.6
   times the mean, the lulls drop to 0.45, and the direction swings about 10° (`gusts`; real
   3-second gusts over open ground run 1.4–1.7 times the mean). The weather's slow swell stays
   underneath as the wind freshening and easing.
2. **The real thresholds.** Every reader is tuned against the Beaufort land signs
   (`beaufort`), at the open-ground wind 10 m up, which is what the weather gives: calm, smoke
   straight up; from 0.3 m/s smoke drifts and shows the way; 1.6 leaves rustle; 3.4 leaves and
   twigs always moving; 5.5 dust and loose leaves lifted, small branches moving; 8 small trees
   sway; 10.8 big branches; 13.9 whole trees. Nothing breaks (§BS), so the table stops at the
   gale.
3. **Height and shelter.** The wind falls off toward the ground: grass tops get about half the
   10 m wind, a treetop about 1.1 times it. Under a canopy everything below the crowns is
   sheltered by §BD's sky visibility, while the crowns take the full wind, so in a closed wood the
   tops toss and the air at your face is still. One number now does light, rooms and wind. Halls
   and caves have no wind except at their openings.
4. **Who answers:**
   - **grass and herbs** bow from 1.6 m/s, and a sheen runs over a meadow ahead of each gust;
   - **crowns** move by force (leaves, then twigs, small branches, small trees, big branches,
     whole trees), each trunk at its own sway period by height, from under a second for a
     sapling to four or five for a 40 m giant, so a stand of one species sways together;
   - **flutter:** leaves on long or flattened stalks tremble in any air, like the sacred fig
     (§CL: "this tree is the reason to add one") and the aspens and poplars;
   - **litter:** leaves on the ground lift and skate downwind in the gusts from 5.5 m/s,
     tumbling, then settle, in the colour of the trees they fell from (the per-species tint and
     the season), so a pine road skates brown needles and a maple road red leaves. Sand streams
     over dunes, spindrift over fresh snow, dust off dry roads. The shelter rule puts this on
     roads, clearings and edges, rarely deep in a closed wood;
   - **cloaks:** every cloaked figure takes the gust (the rig already takes the mean wind);
   - **water:** cat's paws, patches where the glints break up, sliding downwind with each gust;
     a mirror below 1 m/s; small crests on lakes from 8 m/s; still the brightest thing in view
     (R6);
   - **the fire:** its specks already drift with the wind and its coals already flare on a gust
     (§CZ, built 3 Oct); both should read the gust field at the fire, and the torch's sparks
     (§CP) drift the same way. The pipe's puffs at the circle (§CY.4) take the wind at the camp;
   - **cloud shadows** sail over the land on part-cloudy days at cloud speed (about twice the
     ground wind), between the clear and the overcast ends of §CX's one cover value. A cloud's
     shadow is shade: navy or olive (R3), never grey;
   - **sound:** the bed's wind loop follows the gust at you, and the crowns round you are
     sources (§BG) whose rustle rises when the gust reaches them: needles hush, broad leaves
     rustle, palm fronds clatter, dry autumn leaves rattle. The ear gets the gust when the eye
     does.
5. **The smoke column is §CV's; the wind adds two things and some maths.** §CV (locked that
   afternoon) already has which fires smoke and which never do, the column's height by the
   fire's state, its lean per m/s, the dawn pool, rain, the night rule and how far it is drawn
   (`smoke.json`). On top of it:
   - **shelter under the crowns:** a hearth under trees is sheltered like everything below the
     crowns (3), so its column rises straight up through the trees and takes the wind's lean
     only once it clears them;
   - **gusts shred it:** the cards break up over a gust near the fire, and the lean follows the
     gust field, not only the mean, so the column leans and recovers as the grass does;
   - **the numbers behind §CV's reach** (`beacon_reference.py`, on the 400 km planet of §CR):
     the horizon is 451 m from eye height, a full 60 m column's top shows from about 3.2 km at
     eye height (§CV's "about 3 km"; 6.3 km from a 100 m hill), so a column is seen from a rise
     or across a valley, and it rises over the curve as you walk toward it. The day haze leaves
     under 8 % of its contrast by 1 km, past which it reads as a pale mark against the darker
     sky horizon (R5), which is enough. A full column (about a quarter as wide as it is tall) is
     under two internal pixels wide past about 2.1 km, a low fire's 30 m column past 1.1 km and
     the embers' wisp past 0.3 km, so `smoke.json far.min_px` 2 is what carries it the rest of
     the way to its 3.2 km. By night the column isn't drawn and the fire's glow is the beacon
     (§CV), which is what keeps §DF fair: what can see your light, you can see in turn.
6. **Scale guard:** the wind dresses the world, never reshapes it (§BS). Nothing breaks or
   falls, and wildfire spreads by §BL's rules as before.

**Build order inside the pass** (`wind.json order`): the gust field in the plant and grass
shaders, with flutter (`foliage.gdshader` uses 8 of the house's 12 varying slots: keep the wind
in the vertex stage and re-run `tools/shader_varying_check.py`) → the litter → the gust on the
smoke column and the coals → the sound → the cloaks and the torch's sparks → the water → the
cloud shadows.

**Supersedes or amends:** the foliage shader's sway as built (one wind now, with travelling gusts
and shelter). `WORLD_SYSTEMS_SPEC`'s Phase 4 card ("wind into the world") is this section, and
§CL's per-species flutter is part of it. §CV's column gains the shelter and the gusts.

## DB. The sun flares when you look at it, the PSO way — LOCKED (3 Oct, by voice, Mike)

Mike: *"is there any way to implement like cheaply a lens flare type of thing? Kind of how in
Phantasy Star Online episode one or two … in Forest One and Two, if you look up at the sky with
the — at the sun, there's kind of like a lens flare"*; then: *"Yeah, we can lock it in."* Data:
`look.json → lens_flare`. Not built.

- **When the sun's disc is in view and nothing is in front of it** (one ray, or the depth at
  the sun's pixel, each frame): a bright core at the sun, a soft halo, and one or two faint rings
  on the line from the sun through the middle of the frame, sliding as you turn and fading as
  the sun nears the frame's edge.
- **Flat 2D sprites drawn into the 480-line frame,** nearest and dithered with everything else:
  part of the picture, not a sharp overlay (§Y, R9). It is the cheapest effect of its era, and it
  is in the reference.
- **Restraint:** PSO's soft flare, never a modern streak (no anamorphic bars, no lens dirt). It
  fades in and out over about 0.15 s so a twig flicking past doesn't strobe. Thin cloud dims it
  and overcast takes it away, by §CX's one cover value.
- **Cool, not warm:** white and pale cyan (R7 keeps the warm accent for fire). Near sunrise and
  sunset the core takes the sun disc's colour and the rings stay cool. The sun may bloom (R8).
- **The sun only:** the moon blooms (R8) but gets no rings, and nothing flares underground.

## DC. Light through the leaves only when the air would really show it; butterflies — LOCKED (3 Oct, by voice, Mike)

Mike: *"in particular areas, maybe in like a dense canopy, in the morning or something, if
there's like a little bit of mist or fog in the air, how you can see the beams of sunlight
shining down through the trees"*; *"maybe not all the time, just in the cases where you might
actually see it in real life … It's more like whenever you see like a certain cloud formation
or something like that"*; *"maybe we could have like butterflies."* Builds on §BD (sky
visibility), the 1 Oct mist, §CV, §CX and §DA. Data: `look.json → shafts`,
`data/day_accents.json` (new). Not built.

- **Shafts only when three real things meet:** direct sun on the place (not overcast, not under
  a cloud shadow); something in the air to catch it (fog, the damp after rain or at dawn, the
  mist, a hearth's smoke, dust in a ruin's hall); and a broken roof (gaps in a crown, holes in a
  vault, a window). A low sun makes them stronger and longer. A wet wood at dawn after a rainy
  night has shafts; the same wood at a dry noon has none.
- **Three kinds:** under broken crowns; a sunbeam into a dark ruin hall through its broken vault
  or a window, with dust drifting in it (the day's companion to §DI's dark halls); and
  crepuscular rays fanning from the sun across the open sky from gaps in broken cloud, which is
  Mike's "certain cloud formation".
- **The era's way:** long, flat, see-through shafts of geometry along the sun's direction, with
  hard pixel edges, never soft modern volumetric fog. They are brightest looking toward the sun
  and faint with it behind you, as real ones are, and they waver as the crowns above move in the
  wind (§DA). Never more than a handful in view.
- **Cool light** (a correction to the call, where Claude said "a warm shaft"): the sky's light,
  pale white to pale cyan, never warm (R7). It is lit air, so it never blooms (R8).
- **Butterflies by day:** a few small flapping pixel sprites dancing round flowers in warm sun,
  only where the sun reaches; when it blows (from 5.5 m/s, §DA) they sit in the grass. Each
  land's real species and colours are a later fill (one agent per biome family, as with the
  plants; each land its own, §CS); the first guesses are by biome family, mostly whites, yellows
  and blues. Nothing in the day's air glows (R8); the night's blue butterflies at the ruins
  (`night_accents.json`) stay as they are.

## DD. The moon sets how dark the night is; the year joins the day — LOCKED (3 Oct, by voice, Mike)

Mike: *"I really like your idea of having it to where, you know, like the full moon is brighter
out and with the new moon, it's almost dark. But something I want to note is that you should
always be able to see … but, you know, the difference between a new moon and a full moon should
be obviously different"*; and: *"instead of just having like day one, day two, we could have
like day one of year whatever. And then have it to where it kind of like maps to a lunar cycle.
Or some type of zodiac thing."* Builds on §BA, §BD, §BU, §CG, §CY.1 and what is built. Data:
`look.json → moon_nights`, `hud.json → calendar`, `dread.json → full_moon.moon_fill_by_light`.
Reference: `tools/reference/moon_reference.py`. Not built.

**Already built** (found 3 Oct): a real moon. It runs Earth's 29.5-day month in game days (1/10
time, like everything else), rises about 49 game minutes later each day, lights the night by its
phase (never below 5 % of full, `MOON_FLOOR`), and walks the 28 lunar mansions, drawn beside it
in their four beasts' tints. The HUD has a moon line (phase, how much is lit, moon up) and a
mansion line (the mansion and its beast), parts you can pin (Esc, then click). A new world's
first night is near full (§CG; §CY.1 keeps that calendar and only moves the hour to dawn).

1. **Full against new must be obvious, and you can always see.** Outdoors under open sky, a full
   moon high gives the favourites' night (mean luma about 0.20, §BU) and a new moon about half
   that: dark but readable, with the floor keeping the darkest 5 % navy, never black. The lever
   is the moon's share of the night's light, not the floor. Its light rises steeply toward full,
   as the real moon's does (a half moon gives about a tenth of a full one's light), so the
   full-moon nights stand out. A waxing moon lights the evening and a waning one the morning, as
   built. Under a closed crown at night and in tombs §BD stands (*"torch or nothing"*, Mike, 30
   Sept): "always" means under the open sky. Check it at 02:00 on a full and on a new moon with
   the measure tool.
2. **The moon sets how dangerous the night is.** The dread's moonlight rate follows the actual
   moonlight (the phase, and whether the moon is up) instead of switching on at one brightness
   as `dread.gd` does today. A bright night fills slower, and the full moon is the werewolf's
   (§DG).
3. **The year joins the day count.** The time line reads *Day N of Year Y*: the day runs 1–365
   within the year, years count from the world's first day (a new world opens on Day 1 of
   Year 1, §CG), the day still turns at local midnight as built, and the log's stamps carry the
   year too. The lunar side Mike asked for is the moon and mansion lines, already built.

**Reference maths for Mike** (`moon_reference.py`):
- A full moon comes round every **70.8 hours of play**, and "full" (the brightest three nights,
  §DG) lasts about **7.8 hours** of that: 11 % of nights. Within one sitting the phase barely
  moves (about 3 % in two hours).
- A year is **876 hours of play**, so most worlds stay in Year 1: the year is deep time more than
  a counter.
- A shorter month would bring the full moon round sooner (every 17.7 hours of play at a 7.4-day
  month) but would break the 1/10 time rule for the moon alone. It isn't proposed; it is noted
  so the choice is in view.

**Open (Mike):** what a year is called: numbers (as written), the twelve animals, the four
beasts of the mansions, or names of our own.

## DE. Waking: found by folk, days later, at your hearth or the nearest — LOCKED (3 Oct, by voice, Mike); one clash flagged

Mike: *"if you do end up dying, it should send you back to like your last interacted with
hearth, or maybe like you can set different hearths as your like home hearth, and if you don't,
maybe it just like respawns you at the nearest one"*; *"a random amount … between like one and
three days goes by between every time that like you die. And so whenever you wake up around a
hearth, there's like other villagers around that like find you and they're basically like, hey,
we found you passed out, we're glad you're finally awake and that you're okay"*; *"it still
ticks the days, the day counter."* Builds on §AY (30 Sept: you wake at your hearth), §AZ, §BL,
§CG and §CY. Data: `camps.json → wake_found`. Not built.

- **Where you wake:** at your hearth, if you made one (§AY: right click its fire) and it still
  burns with folk at it; **otherwise at the nearest lit fire with folk at it, measured from where
  you fell.** This amends §AY: the opening camp is no longer your hearth by default, and you wake
  there only if it is the nearest or you made it home. A home camp that has gone dark or been
  overrun is skipped.
- **One to three days pass** (uniform, in game days, so you wake at whatever hour that lands
  on: §CY.1's "after a death you wake at whatever hour it is", into the fire circle outside the
  gather hours or a working camp inside them, §CY.2). The world runs those days for real, the
  way it runs while you are away: the clock, the moon (3–10 % of its month), the season, the
  weather, every camp's ticks (§BL's catch-up), plantings, the fires you left burning down, your
  torch where you fell burning out. The day count moves on (§DD). Nothing is faked.
- **Found by folk:** you come to beside their fire, and after the cause line the log says so:
  *"Folk found you out cold and carried you to their fire. Two days have passed."* (§BO: folk are
  mute, plus a line in the log; this is that line.)
- **The death lines fit being found alive.** "Killed by a werewolf" reads wrong before "we found
  you", so the creature line becomes *"Struck down by a {creature}"* (first guesses in
  `wake_found.death_lines_found`); "Taken by the dark" stays as built (§AZ) unless Mike wants it
  to follow §CU's wording.
- **What you carried stays where you fell** (§AY stands): the walk back is still the price.

**Flagged for Mike:** §CW, locked that afternoon at 14:49, says the clock never skips and there is
no wait mechanic. The lost days are the one thing that moves the clock past you, and they are
this morning's ask, so both are written. The sim skips nothing (the catch-up runs every tick), but
a player could be taken on purpose to pass a bad night, waking one to three days on with their
gear left where they fell. Keep both (the lost gear and the lost days are the price), or shorten
the lost time to the rest of that one night.

## DF. Your light gives you away — LOCKED (3 Oct, by voice, Mike)

Mike: *"maybe lighting a torch at night or holding it at night actually gives away your
position by something that might be lurking out there. So, actually, snuffing your flame will
become a tactical thing."* Claude flagged that this turns "light keeps the dark back" around,
and offered the reading that keeps one antagonist: light holds the lurkers off but draws their
attention. Mike took it: *"It's the things that are lurking in the dark"* (the same words §CU
locked that afternoon as the pillar). Then: *"different creatures will see you at different
distances … creatures at night are going to have really good night vision … a torch in the night
might like give away your position to like some other type of NPC that might see you, and maybe
either come to help you, kind of like the mysterious stranger in Fallout, or maybe it's like a
group of goblins"*; *"there also might be other things out there that have senses in different
types of ways … a werewolf … or maybe because it smells you"*; *"having your torch on versus off
definitely becomes like a real choice."* Builds on §AW, §BA, §BP, §CH, §CN, §CQ, §CR and §CU.
Data: `data/senses.json` (new). Not built.

1. **Light holds them off and calls them in.** The lurkers keep out of your circle (§BA, §CQ)
   and see it from far beyond it. With your torch lit you are safe inside your circle and you
   have told the night where you are; with it out you are hidden from eyes and the dread fills
   faster (§BA). Neither is safe, and that is the choice.
2. **Every watcher has senses** (`senses.json`): sight by day; night vision as a share of that,
   with moonlight adding to it, so a full moon shows you even with your torch out; how far it
   sees a lit torch; hearing (your footsteps as built: a sprint is loud, sneaking quiet); and
   smell, which rides the wind like every scent (27 Sept §0: pheromones on the wind field), so a
   nose upwind of you smells nothing and the smoke shows which way your scent is going (§DA).
   **Line of sight counts for sight and light alike:** trunks, walls, ridges and the horizon
   (451 m from eye height on level ground, §CR) stop both. A torch on a dark night is seen by
   anything that can see the place it stands, long before its brightness runs out.
3. **They go to the light, not to you.** A planted torch is a light like a held one (§AW): plant
   it and walk into the dark, and what comes for the light finds the torch.
4. **Going dark costs.** Putting your torch away puts it out (§AW), and fire is never made
   (§BP): it comes back from a flame or from the coal you carry (§CQ.4, one coal at a time). So
   snuffing to hide spends your coal, or leaves you dark until the next fire. That cost is what
   makes it a choice.
5. **Who sees your light at night:** the lurkers (held off, and drawn in); the goblin band
   (§DH: it sees light from far and little else); sometimes **a stranger who comes to help**
   (Mike's Fallout stranger), whose help is open; and never the werewolf, which doesn't need it
   (§DG: it goes by scent).
6. **They sense each other too.** A hunter on your trail and a band crossing it can meet and
   tangle while you slip away. Nothing is staged for you (§CH).

**Open (Mike):** what the stranger does when they come: stands with you so the lurkers keep off,
walks you to a fire, leaves you a coal, or something stranger.

## DG. The full-moon werewolf — LOCKED (3 Oct, by voice, Mike)

Mike: *"maybe there's something lurking on you the whole time, which was like a werewolf or
something, and then those goblins end up like interrupting it … or maybe because it smells
you"*; then: *"I like that werewolf idea where they only come out on full moons, on the
brightest nights."* Amends §BA's hunter table. Data: `dread.json → full_moon`,
`sky/day_cycle.json → full_moon_illumination`, `senses.json → werewolf`. Not built.

- **Only on the brightest nights.** The werewolf hunts only while the moon is at least 97 % lit,
  about the three nights round full. That is one number (`full_moon_illumination`) for every
  reader: today the code gates `active: full_moon` at 85 % (about seven nights) and boosts the
  hunter above a moonlight of 0.9. It keeps §BA's biomes (the temperate deciduous, temperate
  rain, maritime and floodplain forests) and its pattern and speed: a pacer at 6.5 m/s, ×1.3
  on the full moon, which you can't outrun, only out-light.
- **On the other nights its forests fall back to the lurker with no species** (`dread.json`'s
  creature-null entry, §CU, which the grasslands meet every night). In effect this changes §BA's
  build order: the werewolf was the first hunter to build and the one you met there every night;
  now the fallback is what you meet there most nights.
- **It hunts by scent.** It doesn't need to see you: your torch doesn't give you away to it, and
  snuffing doesn't hide you from it. It smells you from downwind (§DF), so the wind decides
  which side it comes from. Light still holds it back like any beast (§BA, §CN: a torch slows
  them, a fire keeps them out).
- **The bright night is the dangerous one.** The full moon is the easiest night to see and
  wander by (§DD), and it is the night the werewolf is out. Mike's dilemma: snuff your torch to
  slip the goblins' eyes and you have dropped the one thing that kept the werewolf back.

**Open (Mike):** §CG opens every world near full (`World.START_DAYS` 13.62; §CY.1 keeps it), so
**nights 1, 2 and 3 of every new world are werewolf nights** wherever the werewolf lives (99.4 %,
99.9 % and 98.2 % lit at midnight). Keep that, or start a world two days earlier: nights 1 and 2
are still bright (92 % and 96.6 % lit) and the first full moon falls on nights 3 to 5
(`moon_reference.py`).

## DH. The goblin band — LOCKED in part; four calls open (3 Oct, by voice, Mike)

Mike: *"maybe it's like a group of goblins that move through the woods, and they're like
bandits, and they like ransack places, and like you might — they might pull up on you because
they saw your — they might not have the best night vision … but maybe they can like see your
torchlight from a long way away."* Claude flagged that a band you fight would cross §BA and the
no-fight line; Mike: *"Yeah, not combat in that sense. They'll definitely be something that you
try to avoid, like if they see you and you don't snuff your flame in time, they might lock on to
you, unless like, you know, you snuff your flame and like either like you said stand still or
climb a tree."* Data: `senses.json → goblin_band, lose_lock`. **Not built until the calls below
are made.**

**Locked:**
- A band moving through the woods at night, on the shared rig at small folk's scale (§0).
  **Never a fight:** something you avoid (§BA; the weapons stay shut, §CN).
- **They see light, not you:** poor night vision, but they see your torch from a long way off
  (§DF).
- **Seen in time, they lock on.** To lose them, snuff your flame and stand still, or climb a
  tree. §AU keeps tree climbing, and starting a climb plants a lit torch where there is ground
  (§AW), which leaves them a light to walk to.

**Open:** each of these touches a locked rule, and Claude only saw them in full while writing
this up.
1. **Who they are.** §BO names goblins as the friendly tribal folk (*"goblins (already the tribal
   folk in the repo) … all friendly"*), and §BL says every human light is on the player's side and
   what lurks in the dark is the only antagonist (§CU). Hostile folk break both. Either (a) they
   are folk turned bandit, which amends §BL and §BO and wants another name than goblin; or (b)
   they are lurkers (§CU) that carry no fire and come to yours like moths, which keeps §BL and
   §BO whole (they can still look small and hooded).
2. **What happens if they catch you.** In the call Claude suggested they rob you, or fell you and
   you wake days later (§DE). Not settled.
3. **"They ransack places."** §BL: camps only go backwards from resources or the dark, and raiding
   is the rung above exchange that this world doesn't build. Do they raid living camps (amending
   §BL), or only rummage ruins and empty places?
4. **Do they carry light?** If they do, you see them coming from far as they see you (§CV's night
   glow), and (b) above is off.

## DI. Ruins: dark by day, dressed by their place, alive with what lives there, haunted where the dead lie — LOCKED (3 Oct, by voice, Mike)

Mike: *"considering, you know, our game is based around the torchlight, we should be able to
have it to where you can use it during the day, too, like, in ruins wherever sunlight cannot
reach"*; *"different mosses and plants and vines and stuff, like, overgrowing them"*, and asked
whether as dressing or something you clear: *"just like dressing for now"*; *"since the ruins are
going to be such a hot spot … they need to feel alive, so definitely we need to have some ambient
sounds based off of what type of creatures are lurking there. And also maybe, like, graveyards,
mausoleums, it can be haunted. And so you might get glimpses of different ghosts which vanish"*;
*"if you follow it around the corner … you go around the corner expecting to see where it is, it
might just have vanished."* Builds on §BD, §BG, §BQ, §CA, §CE, §CH, §CJ, §CM, §CN, §CS, §CU and
§CV. Data: `ruins.json → overgrowth, haunt`, `audio.json → ruins`. Not built.

1. **The torch is a day tool too.** Wherever sunlight can't reach (a ruin's halls, a vault, a
   cave past its mouth, every delve) it is dark at noon (§BD: enclosed, sky visibility 0;
   *"torch or nothing"*). That was already the rule; this is why the torch is never useless by
   day. Who is inside keeps §CH's clock (an ordinary den is empty by day) and §CN's (an overrun
   delve is the lurkers' at any hour). A sunbeam through a broken roof (§DC) keeps the dark hall
   company.
2. **A ruin wears its place.** It is dressing only, with nothing to clear: moss on the stones,
   ferns in the cracks and at the foot, vines over the walls, grass and herbs along the wall
   tops, and lichen painted into the stone's own tile (R9), all from the community that grows
   there (§CS; the gate §CA, the vines §CE, a nest's plants §CM), by the place's moisture. A
   cloud-forest ruin is green to the cornice, a desert one has a creeper in a crack and lichen,
   and a cold one only lichen and moss. The side away from the sun is mossier, as real walls
   are, and old monuments carry more than a camp's remains. With §BQ's signatures and §CU's
   no-two-alike hearths, this is why two ruins of one kind are two places.
3. **A ruin sounds like what lives in it,** inside §BG. Its residents are sources, each calling
   from where it lives at its hours: birds nesting at a tower's top by day, swifts pouring into a
   cold stack at dusk (§CV.5), bats pouring out of the vault at dusk (§CH), an owl in a broken
   window at night, something small scrabbling below in the dark, frogs and drips in a cistern,
   lizards in warm dry stone. The place adds to the bed: wind moaning through gaps, doorways and
   window holes as the gust passes (§DA), drips, the hush of a closed hall. An overrun ruin's
   residents are silent by day (§CN's tell).
4. **Haunted where the dead lie.** Graveyards, barrows, and the tombs and mausoleums of the
   delves can be haunted (first guess: four in ten). Rarely, a pale figure stands at a corner, a
   doorway or the edge of your light, 8–20 m off: the shared rig (§0), a little see-through,
   with no light of its own (R8) and no sound. It steps out of sight, and it is gone the moment
   it is out of view, so the corner you hurry round is empty. It comes only where the light is
   low (dusk, night, a dark hall by day), at most once a visit and about once an hour spent in
   such places, and never twice at one spot. It never harms, never speaks and fills no meter.
   It is not a lurker (§CU): §BA's stage-3 shape comes with the dread and its warnings, and a
   ghost comes with none. It tells nothing (§BQ).

**Not written; Mike's call:** Minecraft's cave sounds, which Mike asked about in the call. Their
groans and swells are unplaceable noises, which is what §BG took out on 30 Sept (*"random noises
you cannot track down"*). The wind in the stones, the drips and the real residents do the job
inside §BG. If Mike wants the Minecraft ones in the delves, that is an exception to §BG.

## DJ. Off the road: hidden places, and the few who speak — LOCKED (3 Oct, by voice, Mike)

Mike: *"it'd also be interesting if we could reward players who went off the beaten path. While
it might be more dangerous, you could also find some like hidden groves with maybe like some
hobbit-style homes, or like, you know, entrances to a secret shrine, or something like that
underneath like a big oak gnarled tree"*; *"an abandoned shrine which has like torches that are
going underground, and you want to know how they're going, or like how they're burning, or maybe
you find like a weird elf creature or like a leprechaun or something and he says something
mysterious and vague, or maybe he gives you something or hints at something that you could fetch
for him"*; *"some type of like text-based system where … what the NPCs … might say to you kind of
like logs in your chat box."* Builds on §AZ, §BC, §BF, §BO, §CJ, §CU and §CV. Data: `shrines.json
→ hidden`, `hud.json → log_more`. Not built.

1. **Off the road is where the strange things are** (§BC already puts the finds off it). The
   danger off the road is the distance from a fire when the light goes (§BA) and what is out in
   the dark (§DF–§DH), never traps.
2. **Hidden places, hand-made and placed by rule.** Each is a set piece from a small hand-made
   kit that the generator puts where it fits (§CJ.8), never on a road, 150–900 m off one, about
   one to every 4 km of road. Mike's first three:
   - **a hidden grove with homes dug under the turf of a bank** (his "hobbit-style homes", built
     from the real turf-house, earth-lodge and pit-house ways: our own folklore, not Tolkien's,
     §BO), a small camp with its own hearth under §BL's rules, a hearth like any other for §CU's
     count and §CV's smoke;
   - **a shrine's door under a great gnarled old tree** on a rise, its roots gripping a stone
     doorway that goes down (an oak where oaks grow, §CA, §CS);
   - **an abandoned shrine whose torches still burn**, going down into the ground (§DK).
3. **The few who speak.** Some hidden places hold one of Mike's strange small folk ("a weird elf
   creature or a leprechaun"): the shared rig at small scale (§0), the fae of our own folklore
   (§BO). They say something cryptic, sometimes give you a thing, sometimes hint at a thing
   they'd like fetched, a line in the log each time. **Lines, not dialogue** (§BF cut dialogue
   systems): one line at a time, no choices, no trees. **No quest log and no markers:** the
   quest is what you carry and what the log holds (§DK).
4. **The log carries the words** (§AZ): spoken lines, what a stranger gave or asked for, waking
   (§DE), a scroll's deciphered text (§DK) and a tome found (§DL), stamped like everything else
   and kept per world. The road stays mute (§BF), camps say what they say (§BF, §BO), and the
   strangest words come from the hidden ones.

## DK. The sealed scroll: carried to someone who can read it, and back — LOCKED (3 Oct, by voice, Mike)

Mike: *"maybe sometimes these shrines have like a hallway which is ominous, and at the end of
the hallway there's like a scroll sitting on an altar, and if you get the scroll, there's some
like unknown transcription written on the scroll, and maybe there's a seal on it that you don't
even know how to get off, and so maybe only a certain person or being or group of people that you
might find further down the road, or maybe even in that same biome, might be able to decipher
what's on it"*; *"the thing I didn't like about Skyrim's quests is that it had … a lot of like
dialogue type stuff, like, oh, just go talk to this person … but I feel like if you fetch
something for somebody, or like get them, bring them like a scroll, and like get them to
transcribe it or something, we can like work in different philosophical elements"*; *"once you
bring it to somebody who can decipher it, it might give instructions on how to go deeper into
the shrine … if you light or blow out some of the torches in a particular pattern, another
secret passageway opens where the scroll was and leads deeper into this shrine … if you bring it
to someone far away and they're like, where'd you find this, you know, it would give you some
incentive to go back there"*; and on the pattern: *"It should probably be in the log that you
could like reference back to."* Builds on §AZ, §BQ, §CJ, §CN and §CV. Data: `data/shrines.json`
(new), `items.json → scroll`, `hud.json → log_more`. Not built.

1. **The shrine,** a new monument kind: an ominous hallway going down, wall torches burning along
   it in sconces, and an altar at its end with a sealed scroll on it. Its delve (§CJ) is shut
   behind the altar. Sconces never smoke (§CV), so a shrine shows no column.
2. **The scroll:** marks you can't read and a seal you can't break. You carry it like anything
   else, and it stays where you fall (§AY).
3. **Few can read it:** someone, some being or some group somewhere else, down the road or
   elsewhere in the same biome (5–60 km off, first guess), never at the shrine. Show it to anyone
   else and they hand it back (a line in the log).
4. **"Where did you find this?"** The reader asks, then reads it: a passage of old wisdom (Mike's
   philosophy, from public-domain texts like the tomes, §DL) and an instruction, which of the
   hall's torches to light and which to put out. Both go into the log whole, to read back
   whenever you like.
5. **Back at the shrine,** set the hall to the pattern. A sconce is a torch in a bracket: put it
   out by hand (right click smothers it) and light it with your torch's swing (§CN), with no
   kindling (laying is for fires). When the hall matches, the wall behind the altar gives way to
   steps going down, into the shrine's delve.
6. **Guessing is allowed, and costly.** Every sconce you put out is dark you made yourself (§BA),
   and with six to eight of them, walking to a reader is the better way.
7. **What you carry and what the log holds are the whole quest:** no quest log, no objective
   text, no marker. The reader's curiosity is the waypoint back.
8. **The text never names how the shrine's people ended** (§BQ).
9. This answers part of §CJ's open call: there are puzzle doors, of one kind so far, and its
   answer is always carried in from somewhere else.

**Open (Mike):** who the readers are (a people that kept writing, a lone hermit, a group); what
lies deeper; the sconces' light, whether ordinary fire someone tends unseen or a stranger light
that isn't fire (Mike: *"a mysterious type of light, or it could still be like the same light"*);
and whether a shrine is always one of the hidden places off the road (§DJ) or can also stand as a
monument on its own grid.

## DL. Tomes: the I Ching first — LOCKED (3 Oct, by voice, Mike)

Mike: *"I would like to add some philosophical texts that you might be able to find randomly.
For example, the I Ching should be one of the books, or scrolls, or tomes that you can find
randomly in this game"*; and: *"We might implement some systems based on it later, but we're
going to wait on that for now."* Builds on §AW, §AZ and §CJ. Data: `data/tomes.json` (new),
`items.json → tome`. Not built.

- **Real philosophical texts you find and read,** the I Ching first, as *The Book of Changes*.
  Rare finds live in ruins (§AW): a tome lies where someone left it, most often at a delve's
  heart (§CJ.3; first guess, about one heart in seven), never in a chest.
- **Read while you carry it,** opening like the log, in the internal frame and the HUD's font,
  one hexagram to a page. The log notes the find.
- **Public-domain text only:** James Legge's translation (*The Sacred Books of the East*,
  vol. 16, 1882), not Wilhelm's in Cary F. Baynes's English (1950, still in copyright). The text
  itself is a later data job, filled from a public-domain edition and checked against it. Other
  texts come later, Mike's choice, each from a public-domain translation.
- **No systems yet** (Mike). The I Ching coin cast already in the game (`iching.gd`, the
  rare-event RNG for the night sky) is a separate thing.

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

**Added 3 Oct, 15:45 (§CY, §CZ):** the data is in and none of it is wired: `roads.json →
opening_road.dawn_start`, `camps.json → sim.fire_circle`, and `look.json → fire.coals`,
`fire.specks` and `fire.light.breath` (`tools/fire_circle_check.py` checks them). The proposed
engine order:
1. **The dawn clock and the longer opening road** (§CY.1). It is small. `main.open_clock`, the
   first camp's road in `world.gd` (picked by walking minutes at the slope pace, not by flat
   length), and the checks that expect an afternoon and 7.2 km (`day_check.gd`,
   `walkabout.gd`, `road_reach_check.gd`) move together; the old `opening_road` keys are
   retired in the same commit.
2. **The coals and the specks** (§CZ). The most seen.
3. **Seats and the seated circle with its loops** (§CY.2–CY.3), built on whoever the camp has
   today.
4. **The pipe** (§CY.4). Its smoke shares §CV's look, so it follows the hearth column.
5. **The dawn break and the dusk forming** (§CY.5). These need §BV's gatherers and their loads,
   so they follow the working camp.

Where this sits against Mike's 14:34 play fixes and §CV's smoke is Mike's call.

**Added 3 Oct, evening (§DA–§DL, the morning voice session, written up after §CR–§CZ):** the
data is in and none of it is wired (the files are listed at the top of this doc). Mike's 17:07
ask: **one Claude Code prompt per idea, built and checked one at a time**, in this order, the wind
first as he asked: **§DA the wind** (its own order is in `wind.json`: the gust field in the plant
and grass shaders with flutter → the litter → the gust on the smoke column and the coals → the
sound → the cloaks and the torch's sparks → the water → the cloud shadows; §CV's column itself is
its own pass) → **§DB the flare** → **§DD the two nights and the year** → **§DE waking** →
**§DG the full-moon werewolf** → **§DC shafts and butterflies** → **§DI ruins** (the overgrowth,
the residents' sounds, the ghost) → **§DF the senses** → **§DJ–§DL** the hidden places, the
shrine and its scroll, the tomes. **§DH waits for Mike's calls.** Where §DA meets §CV (smoke) and
§CZ (the fire), the built thing stands and §DA adds to it.

**Added 3 Oct, 21:30 (§DO–§DS, the monuments and the sages, locked at 21:24):** the data is in
and none of it is wired. These are builder passes, one kind at a time, after the sixteen of
§DA–§DL and §DM–§DN: **§DO the crag fortress** → **§DR the temple city** (with `root_trees`) →
**§DP the wandering fire** → **§DQ the old man on his ox** (the first road regular; the ox is a
new creature body; the gate and the tome are first guesses) → **§DS** in its own order: the long
wall, the carved cliffs, the cliff dwelling, the brick city, the stone heads (after the oceania
realm, which is `RealmMap`, code), the terraced pueblo, the stone circle, the tower house and
the broch. Each new kind: a `Ruins.Kind` and `KIND_NAMES` entry, the builder, its delve (§CJ), its
smoke outlet (§CV), its overgrowth (§DI), a headless check, one walkabout.

**Added 3 Oct, 21:55 (§DT–§DZ, locked at 21:48):** six more monument kinds and one nest, data in and
none wired, in this order after the §DS list: **§DZ the hewn temple** (found from above: the
cheapest and the strangest) → **§DT the hanging gardens** → **§DU the abbey** → **§DW the temple
park** → **§DY the pillar shrines** (needs the karst towers nest and the bridges) → **§DV the
colonnade** → **§DX the columns** (a nest, with the landforms tier-2 set pieces). The same
every-new-kind rule as §DS.

## DM. The road is the stage: it never leads where you can't follow, it widens toward the ruin, and the things on it have lives — LOCKED (3 Oct, 18:30–19:20, Mike)

Mike, from play: *"when I was using the road before, it felt really thin, it got really thin,
and then like went up a hill, then I lost it, and I couldn't even go over the hill because it
was unclimbable, so that needs to be fixed"*; *"that's since where a lot of the players are going
to be doing some of their moving"*; *"I don't really like the way that the hyenas and stuff be
moving around the player. It just feels kind of broken right now, and I want them to be more
like doing their own thing. It gets kind of annoying whenever they're just following you and
they're just howling"*; *"I want everything to have more of a personality. So maybe instead of a
bunch of generic critters, we can start making some unique characters that you might see along
the path."* Also from this talk (Mike): the real clock runs while the game is closed; a camp you
leave with a thin woodpile can be embers, then fully cold, when you come back; fire lasts about
as long as a real log burns. Builds on §BC, §BF, §BY, §CY, §DF, §DI, §DJ. Supersedes §BY's
"thin and lost" only where a road would otherwise lead onto ground the player cannot climb.
Data: `roads.json → network.hard_max_grade`, `grades`, `holders`, `holloway`, `approach`;
`creatures.json` Spotted hyena `pack` (notice, fear of the torch); `uniques.json → road_regulars`
(cast open). Not built.

1. **The road can never lead you where you can't follow.** The route is a least-cost path
   (what `RoadNetwork._route` already is) but the grade cap becomes HARD: no step of a road may
   exceed `hard_max_grade` (0.30, well under the player's `walk_max_deg` 45° ≈ grade 1.0, and
   under the Tobler knee), and `max_grade` 0.18 stays the soft cost that makes it switchback.
   Where the lattice (120 m) hides a ravine between samples, the tread is checked on the fine
   terrain after routing and a failing stretch re-routed or cut into the hill (3). A road that
   cannot be routed under the hard cap is not built (the camp goes in `unreached`, as now).
2. **Thin is a signal, not a failure.** The road has three grades of surface and it WIDENS
   toward what it leads to, like a river toward its mouth: `trodden` (bare line worn through
   the grass, 0.8–1.4 m, far out), `track` (packed earth with ruts, 1.6–2.6 m, the middle),
   `kerbed` (edging stones set along both sides, 2.6–3.6 m, the last 400–800 m before a ruin or
   a people's camp; the Roman-road look). The grade is by distance along the link to its
   nearer end node; a link between two ruins is kerbed at both ends and trodden in the middle.
   §BY's vanishings keep happening, but only on `trodden` stretches, and the holders (4) mark
   every one.
3. **Where it climbs, it cuts in: holloways.** On any stretch steeper than `max_grade` the
   road is sunk `holloway.depth_m` (0.6–2.0, deeper the steeper and the older) into the slope,
   with earth banks either side, roots showing in the banks, and the bend trees (§AG 7) leaning
   in to meet overhead. A holloway is the corridor shot (LOOK_REFERENCE R-walls) given for free,
   and its banks are what make a hill road legible from below.
4. **The line is held by what outlasts the surface.** Even where the grass has eaten the
   tread, the road's line is readable: a cairn or standing stone at every bend and every
   pickup (§BY's tells, now guaranteed at each vanish end, not a share), a milestone every
   `holders.milestone_every_m` (a squat waist-high stone, one notch per mile from the node) on
   `track` and `kerbed`, and an AVENUE (a double row of one planted species, not the biome's
   own, `holders.avenue_within_m` of a node) on the kerbed approach. The avenue trees are
   taller and older than the wild around them.
5. **The approach to a ruin is the epic part.** The last `approach.straight_m` (300–600) of
   any road into a ruin or shrine runs STRAIGHT at it, kerbed, down an avenue, so the ruin is
   first seen as a pale blue silhouette (distance light, R-distance) at the far end of a
   corridor and grows for minutes. The router gets the end node's "front" (its apron side,
   §CJ) and must enter from it. Music drops out on the approach (§DI's residents' sounds take
   over).
6. **Hyenas, and every pack, have a life that isn't you.** The `close_in` state that rings the
   player in slots and follows is CUT for ambient. A pack: sleeps at the den by day; at dusk
   patrols its own range along its own paths (desire lines, §BY, so you can read where a clan
   walks); notices you from `notice_m` but a lit torch is a hard edge it will not cross
   (`pack.fear_of_fire_m`, 12 m): it hangs at the edge of your light, eyes glinting (the §DF
   glint), one member whoops once to the clan, then they go back to what they were doing. They
   follow only if you are UNLIT in the dark, and then as §DF–§DH's dark things do. Howls are a
   clan talking to itself and to the next clan, on their own clock, not a response to you: the
   howl timer no longer resets on noticing the player. You become something they notice, not
   something they orbit.
7. **Road regulars: a cast of one-offs, each with one habit, one stretch, one hour.** Instead
   of generic travellers alone (§BF stays as the background), a handful of named one-of-a-kind
   figures on the shared rig (§0, uniques.json rules), each with ONE habit tied to the real
   clock, so you learn them like neighbours: Mike liked, as starters, the pilgrim who walks the
   shrine road at dawn; the old one always sat on the same milestone; a dog that falls in beside
   you and turns back at the camp's edge. Mute (§BF) except as §DJ allows; the habit is the
   personality. **The cast itself is OPEN** — Mike and Claude build it together next; nothing
   beyond the three starters is locked.
8. **The woodpile is the hourglass (from this talk, restating the clock).** The real clock
   runs while the game is closed (§CW). Fuel burns at real-log rates (a hardwood log 1–2 real
   hours; a stacked pile of ~40 holds a hearth two real days alone; gatherers top it up by
   day). A camp left with a thin pile and no gatherers goes to embers, then fully cold, and
   can be relit by §CN's rule. Embers hold about a real night, like a fire banked under ash.
   §DE (waking at a hearth) is the guard: you never resume torchless in the woods.

**Engine order:** 1 and 2 first (the bug), then 3–5 on the road's build, then 6 (the packs),
then 4's milestones and avenues. 7 waits for the cast. 8 is a tuning pass on `fuel.json` against
the real clock. Mike plays and reports; no screenshots asked.

## DN. The lighthouse: a hearth you can see from the far end of the coast — LOCKED (3 Oct, 19:37–19:40, Mike)

Mike: *"another cool ruin idea i have is a lighthouse on the coast"*; the beam is *"prolly just a
steady fire."* Builds on §CN (overrun ruins cleared by light), §CU, §CV (hearth visible from afar),
§DI, §DM.5 (the straight approach). Data: `ruins.json → styles.lighthouse`. Not built.

1. **A coastal ruin type**: a tapered stone tower, 14–26 m, on a headland or cliff with a sea
   view, a keeper's hut at its foot, a spiral stair inside. Pre-glass: the model is the old
   fire towers (Pharos, the Tower of Hercules), not a lensed lamp.
2. **The lamp room is the hearth.** A coal-fire brazier in a lantern room with open sides, a
   STEADY fire (no sweeping beam), flickering only when the wind gusts through (§DA). Lit, it is
   one warm point on a dark headland seen from ~6 km along the coast and from the water, so
   at night it is a mark to steer by and it says somebody keeps it. Dark, it says the opposite.
3. **The stairwell is the den.** A dark lighthouse is overrun (§CN); the climb up the spiral
   with your torch is the clearing, and the fire you carry up is what relights the lamp.
4. **The coast road's approach** (§DM.5) runs straight along the cliff top at it, kerbed, the
   sea as one wall and the rise as the other.
5. **Relighting brings the headland back**: a camp forms at the keeper's hut (§BL's rules) once
   the lamp is lit.

## DO. The crag fortress: its own kind, in Tibet-like country — LOCKED (3 Oct, 20:53–21:24, Mike)

Mike: *"i have a new reference shot for a potential new ruins style"* (a hilltop fortress-monastery
of the Tibetan kind: whitewashed walls leaning inward as they rise, flat roofs, a dull red band
under every roofline, a long stair cut up the rock, lesser buildings at the foot). Asked whether
it is a castle style or its own kind, where it appears, whether the red band stays, the finial,
and prayer flags: *"its it own kind. it appears in biomes similar to where its found like tibet.
the red band is fine. and no prayer flags"*; then *"lock it in"* (21:24). The finial was not
answered, so it is kept as a first guess. Builds on §BB, §BQ, §CJ, §CK, §CV, §DI, §DM.5, §DN
(the pattern for a new monument entry). Data: `ruins.json → styles.crag_fortress` (`kind:
own`), `smoke.json → outlets.by_ruin.crag_fortress`, `delves.json → fire_holders.by_ruin`.
Real references in the notes only (Gyantse Dzong, the dzongs of Bhutan, Leh Palace): never a
real name in play (§BO). Not built.

1. **Its own kind** (`Ruins.Kind` gains one; "Crag fortress" in play): a fortress climbing a
   rock rise in tiers, 40–100 m from foot to top at walking scale (§CK: sizes read next to the
   player). Walls of rammed earth and stone, limewashed white, battered (leaning inward 5–8°),
   flat roofs, small dark windows in trapezoid frames, the dull red-brown band under every
   roofline (a matte material, never a light; R7 keeps the warm accent for fire, and this
   reads as stone), one gilt finial on the topmost chapel (first guess: kept; matte, one per
   fortress, never glowing: the "golden landmark under a navy sky" of the favourites), a single
   long stair cut up the rock from the foot, and a cluster of lesser buildings at the foot.
2. **Where:** Tibet-like country only: puna, cold desert, steppe, alpine meadow and krummholz, at
   altitude, on a crag (the kopje, volcanic neck, escarpment or mesa nests at their larger
   sizes, or a rock rise the builder raises for it); never on a flat, never in wet or warm
   biomes. Realms: central_asia, east_asia_temperate, andes, palearctic. Rare: at most a few
   per world, each seen from far across its valley (§DM.5's straight approach climbs to it).
3. **The delve goes up** (§CJ allows a tower's stair to climb): from the foot, the stair through
   the tiers, with stores and a cistern cut into the rock on the way, and the heart is the
   chapel at the top under the finial. The way out (§CJ.4) is the outside stair. Fire-holders:
   braziers (the castle's).
4. **Smoke (§CV):** flat roofs, so each delve hearth vents through a roof vent; the honest form
   is the rooftop burner these buildings really had. A living camp at the foot (§CK's camp at a
   monument) keeps an open fire like any camp.
5. **Overgrowth (§DI):** cold and dry, so lichen and a little moss on the shaded faces, nothing
   else. Soot above the roof vents. No cloth anywhere: no prayer flags, living or dead (Mike).
6. **Signature (§BQ):** lime kilns and dry-stone walls are already the mountain folk's heap, so
   this is the monument of a lime-and-stone people, the ladder run past the ceiling (§BL).

## DP. The wandering fire: thirteen in the desert — LOCKED (3 Oct, 21:04–21:24, Mike)

Mike: *"we also need Jesus to be wandering the desert somewhere chilling around a fire with the
apostles"*; locked with *"lock it in"* (21:24) after the reading below; the three calls Claude put
to him were not answered, so each is written at its default and marked open. Builds on §CL (the
first one-of-a-kind figure: unnamed in play, never speaks), §BA, §BL, §BO, §BP, §CK, §CQ.4, §CV,
§CY.2. Data: `uniques.json → uniques.wandering_fire`. Not built.

1. **The second one-of-a-kind, and the first that moves.** Thirteen cloaked figures on the
   shared rig (§0), folk scale, one of them set apart by his robe the way the fig's figure is by
   his ochre (first guess: undyed pale wool, hood down; the twelve in the desert folk's palette).
   They are never a settled camp and never a ruin. One group per world.
2. **They walk by day and sit by a fire at night.** Every camp in the world sits at a nest
   (§BL, §CK); this one doesn't. Fire is never made, only carried (§BP), so they carry their
   flame as a coal in an ember carrier and lay a new fire at dusk from what the desert gives
   (scrub, dung: `fuel.json`), and at dawn they walk on and leave the ring. **They leave a
   trail:** a line of cold fire rings across the sand a day's walk apart, and following the ash
   is how you find them. No column by day (they are walking; §CV draws none at night), so by
   night it is their glow across the desert, the one safe fire that isn't where it was
   yesterday.
3. **At the fire** they are at rest: §CY.2's circle loops (watch the fire, warm hands, eat, doze)
   and no pipe. Their fire is a safe circle like any (§BA): the lurkers keep off it. Mute like
   all folk, plus one line in the log the first time you come within reach (§CL's pattern). A
   coal from their fire is free to take (§CQ.4), and they lose nothing by it.
4. **Where:** the hot desert and its edges only (hot desert, thorn scrub; the wadi and oasis
   nests), walking on and off the roads, a few kilometres a day.

**Open (Mike), each written at its default:** naming (default, as the fig: play never names
him; the log says *"Thirteen sit round a fire in the sand"*); whether the dark keeps off their
circle even when the fire burns low (default: no special rule; the fire does what every fire
does); whether they give anything beyond a coal (default: nothing).

## DQ. The old man on his ox: the first road regular — LOCKED (3 Oct, 21:05–21:24, Mike)

Mike: *"also Laotzu in the mountains"*, *"with his bull"*, then: *"actually it was an ox not a
bull.."*; locked with *"lock it in"* (21:24). §DM.7 left the road regulars' cast open: this is
its first entry. Builds on §BF (travellers: mute, never stop, the hood tracks you, unharmed in the
dark), §CR.4 (every great range has a walkable route to its summit or pass), §DL (tomes), §DM.7.
Data: `uniques.json → road_regulars.ox_rider`, `tomes.json → tao`. Not built.

1. **The one traveller who rides.** A §BF traveller in every rule (mute, never stops for you,
   the hood turns and holds a beat, the dark ignores him), with two differences: he rides, and he
   keeps to the mountains, on the high roads of the great ranges (§CR.4), heading for the
   highest pass. Slowly: the ox's pace, under the walk. At dusk he stops where he is; the ox
   grazes; no fire (a traveller needs none); at dawn he rides on. On a planet you can walk
   around he never leaves, which is honest to the story: always on his way out, and always to be
   found on the pass roads. One per world.
2. **The ox** is the one new body: a domestic ox, not a buffalo (Mike): heavy, slow, horns
   curving forward and out, a dull black-brown coat, no load and no plough, just the rider. A
   creature body (beasts keep creature bodies, §0) at the walk; the rider is the shared rig
   seated on it, hood up, a plain dark robe (first guess).
3. **The gate at the pass, its keeper and the book** (first guess, open): the story's other half
   is the keeper of the gate who asked him to write his teaching down before he left. A
   gatehouse at the highest pass of his range, a small camp with its keeper (§BL's rules, one or
   two folk), and the book he left lying there: the *Tao Te Ching* as the second tome (§DL), in
   James Legge's 1891 translation (*The Sacred Books of the East*, vol. 39, public domain), one
   chapter a page. It is found at the gate, not at a delve's heart.

**Open (Mike):** naming (default, as the fig: play never names him; the log says *"An old man
rides an ox up the pass road, slowly"*); and whether the gate, the keeper and the book are in
(written in as a first guess; one line to strike).

## DR. The temple city: roots over stone — LOCKED (3 Oct, 21:20–21:24, Mike)

Mike: *"got some cool reference photos for ankor wat style ruins"* (eight frames of the temple the
forest took back: pale trees standing on gallery roofs with their roots poured over the
doorways, moss-green roofs, galleries of square columns, towers rising in diminishing tiers,
courtyards of tumbled blocks, two figures in ochre walking a gallery); locked with *"lock it in"*
(21:24). The three calls (size, where root-trees grow, the ochre camp) were not answered and are
written at the defaults Claude proposed. Builds on §BB, §BQ, §CA, §CJ, §CK, §CL, §CS, §DI, §DJ,
§DM.5. Data: `ruins.json → styles.temple_city` (`kind: own`), `ruins.json → root_trees`,
`smoke.json → outlets.by_ruin.temple_city`, `delves.json → fire_holders.by_ruin`. Real references
in the notes only (Angkor, Ta Prohm, Preah Khan): never a real name in play. Not built.

1. **Its own kind** ("Temple city" in play): concentric enclosures of long low galleries with
   square columns, carved doorways (gopuras) through each wall, courtyards, and towers that rise
   in diminishing tiers at the centre, with a moat outside. First guess: 150–300 m across, two or
   three enclosures, five towers (the real ones are a kilometre across and would eat an hour at
   the walk; §CR.2's true size bends here on purpose, as §CK's walking-scale rule allows).
2. **The root-tree is the signature.** Not dressing: a tree *standing on* the ruin, its trunk on
   a gallery roof or a gopura and its roots poured down over the lintel and the wall to the
   ground, bark pale against dark stone. The mechanism is already in the design twice (§CL: the
   fig's roots gripping old stone; §DJ: the oak door) and this is where it becomes the whole
   character of a place: one root-tree on about every third gopura and gallery. The species are
   the place's own (§CA, §CS): the banyan and the sacred fig are in the jungle data; the big pale
   silk-cotton with the cascading roots (*Tetrameles nudiflora*) is not yet, a one-line fill.
   **Root-trees are not only the temple city's** (default): any old monument in jungle or
   rainforest may carry one or two (`ruins.json → root_trees`); the temple city carries many.
3. **§BB in stone.** Galleries are corridors, gopuras thresholds, courtyards rooms with one
   feature, doorways voids (R8). The collapse is the obstacle (§CJ.6): courtyards knee-deep in
   tumbled blocks, galleries climbed over or gone round. The delve is the walk inward: enclosure,
   gallery, inner enclosure, the central tower as the heart, and the way out a collapsed gallery
   on the far side. No fights (§CJ).
4. **The look is already ours:** moss on every roof (§DI's wettest row), shade olive not navy
   (R3's green-scene rule), stone grey-green, roots pale, doorways black, sky cobalt. Carved
   figures on the walls stay as reliefs of dancers and guardians: nobody's gods by name (§BO).
5. **Where:** indomalaya, in jungle and monsoon (tropical dry) forest, on flat lowland near water
   (the moat), never on a crag. Rare: one or two per world where the realm exists.
6. **The ochre camp** (default: yes): a living camp at the monument (§CK) wears ochre robes, the
   colour the sacred fig's figure wears (§CL), so the sages and this place quietly share one
   colour. Its fire is open (§CV.2). The delve's hearths vent through the towers (`tower_vent`).
7. **The gate and the faces** (Mike's second batch, 21:27: the face towers, the causeway of
   guardian heads, the three-headed elephant at the gate's corners, the sun behind a face tower).
   The outer wall's gates are towers with a great serene face on each of their four sides,
   looking out over the four roads; the causeway over the moat is lined with rows of crouching
   guardians holding a serpent's body as a balustrade, half of them scowling and half serene;
   the gate's corners are carved as a three-headed elephant pulling lotus trunks from the wall.
   All of it ours (§BO): faces of nobody by name, guardians and elephants as reliefs. The faces
   are the temple city's far-off tell (R10): a pale face in the trees at the end of the avenue.

**Open (Mike):** the size, the root-trees elsewhere, and the ochre camp, each written at the
default above.

## DS. Monuments by realm: the set — LOCKED (3 Oct, 21:18–21:24, Mike)

Mike: *"some more types of ruins: scottish castles, ankor watt, anasazi, mayan, aztec, incan,
egyptian, pueblo pyramids, great wall of china, petra, stone hinge, easter island heads"*; locked
with *"lock it in"* (21:24) over the table Claude put to him, with its two calls (all of them, in
the order below; the stone heads wait for a tenth realm) written at the defaults. At 21:27, while
this was being written, a second batch of frames: the temple city's face towers and guardian
causeway (§DR.7), the cliff dwellings and the great kiva (4), and the brick city on its river (6),
folded in here. The rule for
every one: a realm and a biome gate (`ruins.json → styles`, the lighthouse's shape, §DN), a nest
where one applies (§CK), what stone leaves behind (§BQ), a delve (§CJ), a smoke outlet (§CV), and
never a real name in play (§BO). Not built.

**Already in the game** (nothing to add): the Maya temple pyramid, the Aztec platform pyramid, the
Inca terrace platform, the Egyptian true pyramid and the mastaba tomb. One addition: the terrace
platform gains the fitted polygonal stone wall as its §BQ signature.

**New styles of kinds we have:**
- **the tower house** (a castle style) and **the broch** (a tower style: a drystone round
  tower, double-walled, with a souterrain, an underground passage, as its delve): palearctic,
  on the cold wet coasts and moors (maritime forest, rocky shore, the bog and tundra edge);
  lichen and moss (§DI).

**New kinds** (`kind: own`), in build order:
1. **The long wall:** a wall running over the ridges for miles, with towers at intervals, broken
   in places, a road along its top (§DM: the wall is a road kind). east_asia_temperate and
   central_asia, on the steppe edge, mountains and cold desert. The gate towers' vaults are the
   delve; the towers vent through wall flues. The first linear monument besides the aqueduct.
2. **The carved cliffs:** facades cut into a sandstone canyon wall, entered through a slot
   canyon (§CK's slot canyon and canyon nests), the rock-cut tombs behind the facades as the
   delve. palearctic hot desert and canyon, sandstone only. Smoke: out the facade doors, soot
   above them.
3. **The stone heads:** a row of great stone heads on their platforms along a treeless coast,
   facing inland, and the quarry's cave as the delve. **Waits for a tenth realm, oceania**
   (`RealmMap` is code: Claude Code's), on coastal grassland. The restraint rule (§BL) as a
   landscape: heads, grass, no trees, and nothing says why (§BQ).
4. **The cliff dwelling** (Mike's second batch, 21:27: a town of stone rooms and round towers
   filling a sandstone alcove; a smaller one high in a cave mouth; the great kiva): its own kind,
   at the mesa alcove nest (§CK already names the alcoves): three or four storeys of fitted
   sandstone rooms under the overhang, round towers, ladders, and the kivas, round sunken rooms
   with a firebox and a vent, in the plaza in front. nearctic canyon, cold desert and sagebrush;
   the alcove is its roof, so the stone stays nearly whole (§BQ). The delve is the great kiva
   and the stores cut into the alcove's back; smoke out the kivas' vents and the roof hatches.
5. **The terraced pueblo** (Mike's "pueblo pyramids", read as the stepped adobe towns of many
   storeys on open ground): nearctic cold desert, sagebrush and canyon, near water; adobe melts,
   so an old one is a mound with walls standing in it; the kiva is the delve; smoke out roof
   hatches.
6. **The brick city** (Mike's second batch, 21:27: a city of mud brick on a desert river: a
   processional way between high buttressed walls to an arched gate, a maze of melted brick
   foundation walls, the palace mound above the palms): its own kind, on a desert river's
   floodplain (palearctic and central_asia; hot desert, oasis and steppe by a river, the levee
   nest); the existing ziggurat style stands at its centre. What remains is the tell: a mound of
   melted brick with the foundation walls standing in it as a maze, the gate still arched, its
   face glazed blue with animals in relief (a saturated blue material: blue owns the frame, and
   it never glows, R8). The delve is the vaulted stores under the palace mound and a well; smoke
   out the courtyards' roof hatches.
7. **The stone circle** (a henge): a ring of standing stones on grassland or moor, palearctic;
   standing stones are already waymarks (§BC), this is the great one. The delve is a souterrain,
   or none (the one allowed exception to §CJ's "every ruin has one", first guess). No smoke.
8. **The temple city** is §DR; **the crag fortress** is §DO.

**Order:** the long wall, the carved cliffs, the temple city (§DR), the crag fortress (§DO), the
cliff dwelling, the brick city, the stone heads (after the realm), the terraced pueblo, the stone
circle, the tower house and the broch.

## DT. The hanging gardens: a garden that outlived its gardeners — LOCKED (3 Oct, 21:32–21:48, Mike)

Mike: *"we also need the hanging gardens of babylon"*; asked whether part of the brick city or its
own kind, alive or dead, and what grows: *"its own kind. its overgrown with some plants"*; locked
with *"lock it all in"* (21:48). Builds on §BQ (the brick vaults are what the diggers found; the
gardens rotted), §BP (irrigation is a rule: a plot by water or a dug channel counts as watered),
§CS (a community is native to one land) and §CT (the human hand is the one way a plant lives
outside its home), §CJ, §CV, §DI, §DS.6 (the brick city, which may stand near it), §BE (water
stepping down). Data: `ruins.json → styles.hanging_gardens` (kind own, with `hand_carried`).
Real references in the notes only (Babylon's vaulted terraces; the account of a king planting
mountain trees for a queen who missed her hills). Not built.

1. **Its own kind** ("Hanging gardens" in play): a stepped mound of vaulted brick, 20–35 m high
   and 80–150 m across, on a desert river's floodplain, with or without a brick city near it; at
   most one a world. What stone leaves (§BQ): the vaults that held the terraces' soil, the
   terrace walls, and the old channel cut down the mound. Everything that was wood is gone.
2. **The garden outlived its gardeners.** A channel drawn from the river upstream still runs onto
   the top terrace, so the trees never died (§BP: a plot by a channel counts as watered). It is
   overgrown, not tended (Mike): the mountain trees the gardeners carried in, cedar, juniper and
   cypress, grown huge and gone wild, rooting into the vaults; the river's own date palms, figs,
   pomegranates and tamarisk on the lower terraces; seedlings in every crack; moss and ferns
   where the water runs. It is the one place in the world where a community grows outside its
   land before the player plants anything, and it is honest: the water never stopped. §CS and
   §CT's exception, placed by the generator, not the player.
3. **Water steps down the terraces** from the channel's mouth at the top, a small fall at each
   wall (§BE's falls; R6: the brightest thing), into the river at the foot. The sound is water
   and birds everywhere (§BG). On a flat desert river a green mound 30 m high is seen from far
   off (R10, §CR.7).
4. **The delve** is the vaults under the terraces, with the channel running through them: in at
   the foot, up through the vaulted galleries level by level, the cistern where the water-lift
   stood as the heart, the channel's mouth at the river as the way out. Hearth rings; the
   gallery hearths vent through the terraces' drains. A camp at the foot could tend it again
   (§BQ: restoration is the reveal), and until it does the garden stays wild.
5. **Where:** palearctic and central_asia, hot desert, oasis and steppe on a desert river
   (the levee and oasis nests), flat, water on one side; never a crag.

**Data note:** juniper, cypress, date palm, pomegranate and tamarisk are in the catalogue; the
cedar (*Cedrus libani*) and the common fig (*Ficus carica*) are not, a two-line fill for chat.

## DU. The abbey: a roofless church in cool wet country — LOCKED (3 Oct, 21:38–21:48, Mike)

Mike: *"more references"* (four frames: a great church ruined on a headland, its tower and
arcades against the sky; the inside of one with sun through the lancets onto a grass floor; one at
sunset over its foundations); locked with *"lock it all in"* (21:48). Builds on §BQ, §CJ, §CV,
§DC (the shafts: frame 3 is their shot), §DI (residents, the bed, the haunt), §DM.5, §DN (a
headland landmark). Data: `ruins.json → styles.abbey` (kind own), `ruins.json → haunt.kinds`
gains `abbey`. Real references in the notes only (Whitby, Rievaulx, Kirkstall, Fountains). Not
built.

1. **Its own kind** ("Ruined abbey" in play): a great church with its roof gone: the nave's walls
   and arcades standing, pointed arches and lancet windows framing the sky, one tower (whole or
   half), the floor turned to grass, the cloister and chapter house reduced to foundations in the
   turf, a warming house with its chimney stack still standing. 40–90 m long. At most two a
   world.
2. **Where:** palearctic, in cool wet country: temperate deciduous, maritime forest, the moor
   (tundra and bog edges), and on headlands over the sea (rocky shore), where it is a landmark
   seen from the coast road as §DN's lighthouse is. In a river valley it sits at the valley's
   floor by the water.
3. **Where three locked things meet:** §DC's shafts fall through the lancets onto the grass on a
   misty morning (the ruin kind of shaft, with the walls as the broken roof); §DI's residents
   (jackdaws in the tower by day, an owl in a window at night, the wind moaning in the arcades at
   6 m/s); and §DI's haunt, since an abbey has its graveyard and its tombs, so it can be haunted.
4. **The delve:** the crypt and the undercroft under the east end; the crypt's chapel is the
   heart; the night stair up into the cloister the way out. Braziers. Smoke: the castle's chimney
   stack at the warming house, the one room the monks kept a fire in.
5. **Overgrowth** at §DI's wet row: moss on every ledge, ferns in the window sills, ivy up the
   tower, grass over the foundations; lichen on the headland ones.

## DV. The colonnade: the columns of a house that burned — LOCKED (3 Oct, 21:38–21:48, Mike)

Mike's first frame of that batch: a ring of tall fluted columns with iron capitals standing in a
grassy clearing among old trees, the house they held long gone; locked with *"lock it all in"*
(21:48). The smallest monument in the set, and §BQ to the letter: the imperishable part of a thing,
and no word about what happened. Builds on §BQ, §CJ, §DI, §DM.4 (the avenue). Data: `ruins.json →
styles.colonnade` (kind own). Real reference in the notes only (the columns near Port Gibson,
Mississippi). Not built.

1. **Its own kind** ("Old colonnade" in play): 20–30 brick columns, plastered, 10–14 m tall, with
   iron capitals, standing in a ring on the footprint of a great house of wood that burned; a
   few fallen; the brick cellar open to the sky in the middle; a planted avenue of old oaks
   (§DM.4's avenue, taller and older than the wild around them) running to it from the road. At
   most three a world.
2. **Where:** nearctic, in the humid south: floodplain forest, maritime forest, the southern
   temperate deciduous woods, on a rise above a river. Never in dry country.
3. **The delve** is small: the brick cellar and the cistern under the house's footprint, half
   flooded (§BE: still water, wade), the cistern the heart, the cellar's outside stair the way
   out. Hearth rings. No stack (nothing above the cellar to smoke through).
4. **Overgrowth** at §DI's wet row: vines on the columns, ferns at their feet, the oaks' limbs
   over everything, resurrection fern on the limbs (§CD). The ending stays unnamed (§BQ).

## DW. The temple park: the open cousin of the temple city — LOCKED (3 Oct, 21:39–21:48, Mike)

Mike: *"sukothai ruins as well"* (five frames: stepped brick platforms, rows of roofless laterite
columns, bell and lotus-bud stupas, tall ribbed towers, seated figures in brick niches, lotus
ponds with the towers reflected in them, a great fig at a pond's edge); locked with *"lock it all
in"* (21:48). Kept separate from §DR on purpose: the temple city is closed, in jungle, taken by
the forest; this is open, in the monsoon dry forest, with the sky over everything. Builds on §BQ,
§CJ, §CS (the sacred lotus's niche: "the warm, still shallows of its land"), §DR, §DI, R6. Data:
`ruins.json → styles.temple_park` (kind own). Real references in the notes only (Sukhothai,
Ayutthaya). Not built.

1. **Its own kind** ("Temple park" in play): a flat precinct, 200–400 m across, of stepped brick
   platforms, rows of roofless laterite columns in a grid (the wooden roofs and tiles rotted a
   generation after the last monk, §BQ, and the columns stand like a dead orchard), bell-shaped
   and lotus-bud stupas, two or three tall ribbed corn-cob towers, seated figures in the brick
   niches with their hands in their laps and their faces worn smooth, nobody by name (§BO), and
   the ponds between the platforms. One great old fig at the edge, roots in a pond bank. At most
   two a world, and never within 5 km of a temple city.
2. **The ponds** are lotus and lily ponds with the towers reflected in them (R6): the sacred
   lotus's own niche (§CS.6), so this is one of the places the lotus community lives. Neither
   *Nelumbo* nor *Nymphaea* is in the catalogue yet: a two-line fill for chat.
3. **Where:** indomalaya, tropical dry forest and the jungle's open edges, flat lowland with still
   water; never a crag.
4. **The delve** is the great stupa's relic crypt: a chamber under the tower reached by a shaft,
   the stores around it, the crypt the heart, the shaft up the tower's side the way out. Hearth
   rings. Smoke: open fires only (a camp among the platforms); the stupas vent nothing.
5. **Overgrowth** at §DI's dry row: grass over every platform, a creeper on the columns, moss only
   at the ponds' edges.

**A note Mike will see without being told:** the colonnade (§DV), the abbey (§DU) and the temple
park are the same story in three climates: a roof that rotted and the columns that didn't.

## DX. The columns: columnar basalt as a nest — LOCKED (3 Oct, 21:42–21:48, Mike)

Mike: *"these hexagonal structures are a cool natural formation"* (three frames of the causeway,
then two of the columned sea cave); the inland cliffs taken too (Claude's call, unanswered);
locked with *"lock it all in"* (21:48). A landform, not a ruin: a thick lava flow that cooled
slowly and cracked into hexagonal columns, which is why it looks built when nothing built it.
Builds on §CK (the fire family: the caldera, the obsidian flow, the volcanic neck), §CY.3 (a
flat stone is a seat), §BC (a road that walks into the sea), §BQ, §BG. Data: `landforms.json →
landforms.columnar_basalt` with two variants (gate `tools/landforms_check.py`, 0 errors). Real
references in the notes (the Giant's Causeway, Staffa, Svartifoss, the Devils Postpile). Not built.

1. **The causeway** (the main form): where an old flow meets the sea on a volcanic coast, a flat
   stepped floor of hexagon tops running down into the water. What it gives a camp (§CK):
   a floor and a hundred ready-made seats, rain and tide pools in the cups with green weed in
   them (R6: bright water in every cup), a lookout from the top step, and a hearth spot on the
   highest dry step above the spray. The columns come loose, so the people here built with them:
   a hut of stacked hexagonal columns is the camp's remains, a signature nothing else has (a
   coast-folk signature to add with the next peoples fill).
2. **The organ pipes:** a cliff of columns where a river or a waterfall has cut the flow (the
   canyon and the waterfall nest, the fall pouring over the columns).
3. **The columned sea cave:** where the sea has hollowed the flow: the sea runs straight in, the
   roof is the underside of the columns, and the stumps of broken columns along the wall make a
   natural ledge above the water to the back: the way in is already there. The mouth is the only
   light (§BD), the water turquoise under a black roof (R6), and the cave booms with the swell, a
   §BG source heard from the clifftop before the way down is found. The night roster dens in it
   (§CH). No dry floor, so never a camp: a landmark and a passage, with the hearth spot on the
   clifftop above (§CK: the hearth is never in the hazard).
4. **Look:** dark grey-black with wet tops, so the shade rule is navy; a hexagon tile at 16
   texels a metre does the work. Any realm, wherever old lava meets water. Walking scale.
5. **The log line,** once: *"A road of stone steps goes down into the sea."* Nothing in the game
   says whether anyone made it (§BC: the player finishes the thought).

## DY. The pillar shrines: forks in three dimensions — LOCKED (3 Oct, 21:45–21:48, Mike)

Mike: *"karst mountains of china with bridges connecting different ruins on each pillar"* (a
valley of sandstone pillars rising out of mist); locked with *"lock it all in"* (21:48); the two
calls (the three bridge kinds; a few rope bridges still up) unanswered and written at the defaults.
Builds on §BC (forks legible before you commit; one-way gates), §BT (the canopy folk's vine and
living root bridges), §BQ, §BY (half the bridges are out), §CJ, §CK (the karst towers nest), §DA
(rope sways in the gust), §DI. Data: `ruins.json → styles.pillar_shrines` (kind own). Real
references in the notes only (the pillar forests of Zhangjiajie and the tower karst of Guilin, the
cut stairs and plank walks of the sacred mountains). Not built.

1. **Its own kind** ("Pillar shrines" in play): a valley of 6–15 stone pillars 50–150 m high at
   walking scale rising out of pooled mist, a small shrine or hermitage on the top of each,
   stairs cut into the rock faces to reach them, and bridges between the tops. At most two a
   world.
2. **The bridges, by span, are the design.** Stone arches between close pillars still stand.
   Rope-and-plank bridges over the long gaps are gone (§BQ), only their stone abutments and
   anchor posts left, so half the ways across are out (§BY's rule, in the air); first guess: one
   in six rope bridges still hangs, so a crossing can be a swaying one (§DA's rope rule). Where
   canopy folk lived (§BT), living root bridges of fig are still there and still growing: the one
   ruin that gets stronger after its makers are gone. So you climb a pillar, see the next shrine
   across the gap, and the bridge is a pair of posts and nothing between them: the fork is
   legible before you commit (§BC), and the way is another pillar's stair, or round through the
   valley floor in the mist. No wall climbing (§AU): the cut stairs are the only way up.
3. **Where:** east_asia_temperate and indomalaya, at the karst towers nest and a sandstone pillar
   variant of it, in cloud forest, temperate rainforest, jungle and monsoon forest, in a valley
   where the mist pools (look.json's mist does this; the pillars standing out of it is R5's shot
   made of rock).
4. **The delve** is inside a pillar: a cave at its foot (karst caves, §CJ) and a stair cut up
   through it to the summit shrine, which is the heart; the way out is a bridge, or the cliff
   stair. Hearth rings at the shrines. Smoke: open (a hermit's fire on a summit, if a camp).
5. **A camp here is canopy folk** (§BT): they are the ones who grow the root bridges back.

## DZ. The hewn temple: found from above — LOCKED (3 Oct, 21:48, Mike)

Mike: *"ellora caves"* (five frames: a whole temple cut out of a basalt hill from the top down,
standing free in a court of living rock; elephants carved round its base; columned halls dug into
the court's walls with ribbed vaults and a seated figure in the apse); locked with *"lock it all
in"* (21:48). Different from the carved cliffs (§DS.2): Petra's facades are cut into a cliff face;
this is a temple cut out of the hill, with a pit dug round it. Builds on §BB (the reveal, inverted),
§BQ, §CJ, §CK (the escarpment nest, the volcanic field), §DI. Data: `ruins.json →
styles.hewn_temple` (kind own). Real references in the notes only (Ellora's Kailasa and its
halls). Not built.

1. **Its own kind** ("Hewn temple" in play): a pit 60–120 m across cut into a basalt escarpment,
   and in the middle of it a temple left standing in the living rock, free on all sides: towers,
   courts, two free-standing pillars, a row of elephants carved round its base, reliefs on every
   face (nobody's gods by name, §BO). Halls dug into the court's walls on two or three levels,
   columned, with ribbed vaults cut to look like timber that was never there, and a seated figure
   in the apse of the deepest one, hands in the lap. At most two a world.
2. **You find it from above.** The road comes along the hilltop, the ground opens at your feet,
   and the whole temple is below you before you have found the way down (§BB's reveal with the
   ruin in the hole; §DM.5's approach runs along the rim). The way down is a stair cut in the
   court's wall.
3. **The halls are the delve as they stand** (§CJ): in through the court, up the cut stairs
   between levels, the deepest hall the heart, a stair to the hilltop the way out. Hearth rings.
   No smoke of its own.
4. **Where:** indomalaya, on a basalt escarpment in dry plateau country: tropical dry forest,
   thorn scrub and savanna. Dark grey-black basalt: navy shade, warm grey in the sun.
5. **Overgrowth** at §DI's dry row: grass on the hill above, a creeper down the court walls,
   lichen on the towers.

