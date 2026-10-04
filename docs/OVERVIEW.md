# Project Overview — an ambient open world of forgotten roads

*Working title: "animated-succotash". A solo project by Mike Flow, built in Godot 4 with two AI
collaborators. This overview is for sharing: what the game is, how its systems fit, and where
it stands. Feedback is welcome on anything. Updated 1 Oct 2026, after the ambient cut.*

---

## The one-sentence version

A slow, first-person walk across a planet one tenth the size of Earth, with real biomes, real
seasons and real plants. Old roads lead between ruins and living camps. Fire is something you
carry, never make. Every ruin goes down into the dark, and what lurks there is the only enemy.

## The thesis

**A world, and moving through it slowly enough to see it.** Roads, bridges and ruins that
someone once looked after are being rediscovered, overgrown and crumbling. A fire is the
reason the group exists, and the dark is dangerous. Every feature has to pass one test: does
it make the world feel older, quieter, more alive, or more worth walking? If not, it doesn't
go in.

The feeling Mike is after is the internet of 1997–2010, the web before the index: you got
somewhere because someone's dead page linked to it, and everything felt like discovery. Other
touchstones are the backrooms, places that are alive but forgotten, a hearth like Virtual
Villagers', and waking with nothing like Minecraft.

## Two games

The momentum movement has split off into a **separate ninja game**: wall jumps, chains, rolls,
120 km/h, bow-and-spear combat and the shinobi. Its code stays in this repo, switched off,
for that game to lift later. This is the ambient one. The bow and the spear only turn up here
as rare finds in ruins.

## The look

- **In one line (Mike):** "almost like Minecraft, except not in boxes, and everything flows
  better."
- **Era:** 1999–2004, from the Dreamcast to the GameCube, PS2 and Xbox. The touchstones are
  *Phantasy Star Online* Ep I & II, *F-Zero GX* and *Melee*, plus @ozavry_'s AI videos of
  imagined early-2000s games. Twenty favourite frames, measured, are the reference
  every render is judged against (`docs/design/LOOK_REFERENCE.md`).
- **Pixels:** the game draws a 480-line frame and scales it up with nearest-neighbour. Every
  surface has 16 texels a metre, silhouettes stay clean, and there are no normal maps and no
  sheen.
- **Colour:** dark but saturated, with blue owning the frame. The sun is the one light. Shade
  goes navy (olive in green scenes), never grey, and distance gets lighter and bluer. Water
  is the brightest thing in view and fire the one warm accent. Night is one moonlit blue
  world.
- **The shot:** a path or a river runs straight to a landmark against the sky, with walls of
  trees or slopes on both sides. Places read as outdoor rooms: a corridor, a threshold, then
  the reveal.
- **Figures:** every intelligent being is a cloaked figure on one shared rig, told apart by
  size, timing and colour. Goblins, orcs and fae are dressings on a way of life, and all of
  them are friendly.

## The world

- **Scale:** a walkable cube-sphere planet **4,000 km around (1/10 Earth)**, with heights at
  1/10 too (Everest would stand about 900 m). The continents are laid out on a 400 km map and
  built ten times wider. A biome region runs from tens to hundreds of kilometres across, and
  walking around the planet would take about 260 hours. *(Locked 3 Oct, not built yet: the planet
  moves to **1/100 Earth, 400 km around**, with everything you can stand next to at its real size,
  heights still 1/10, and climbs that take real time; walking round it takes about 26 hours.)*
- **Time:** a day lasts **144 real minutes**, one tenth of a real day, so a game hour is six
  real minutes. The 23.5° tilt gives real day lengths by latitude and season, with polar
  night and midnight sun. A 365-day year passes in 36.5 real days.
- **Biomes and plants:** real biomes come from temperature, rainfall, altitude, coasts and
  wetlands. A species grows only in the kind of place it belongs and on the soils it grows
  on. Each place keeps its few archetypal species, and Mike's named plants are always
  somewhere: bananas, *Amorphophallus*, the cannabis landraces, *Trichocereus*, acacias,
  bamboo and vines.
- **How plants behave:** vines climb trees and ruin walls, and plants grow at their real
  rates on the 10× clock. The resurrection fern is designed to curl up in drought and green
  after rain (§CD, not built yet).
- **Forests:** every stand is old growth, and most woods are one dominant species, as they
  are in life.
- **Weather and water:** a live global wind and water cycle moves storms, rain shadows and
  river stages. Rivers have current: downstream is free, and upstream on a fast reach is a
  wall. The land itself was shaped at world generation; the weather only dresses it.
- **The wind you can see** *(locked 3 Oct; not built yet)*: everything moves with one wind.
  Gusts cross the grass toward you and reach the trees, leaves skate down the old road, cloaks
  and water answer it, and every hearth's smoke leans with it, rising straight through the trees
  and bending above them. Look at the sun and it flares, the way it did in Phantasy Star
  Online's forests; shafts of light come through the leaves only when the air would really show
  them.
- **Roads:** an old network, laid down at world generation, links ruins, camps, springs and
  fords. Nobody keeps it: half the bridges are out, and the finds are just off the trail. The
  road gets you somewhere known. Designed but not built yet (§BY): trails that fade under fern
  and pick up again at cairns and notched trees, and desire lines worn by folk and the player.

## Waking, the fire and the dark

- **Waking:** you wake with nothing, in the afternoon, beside a road, at a camp. The road
  leads on to the next one.
- **Waking at dawn, in the fire circle** *(locked 3 Oct, §CY; not built yet)*: you come to at
  first light with the camp's folk sitting round the fire on seats the place provides (a log,
  a rock, driftwood, a cypress knee). One packs a pipe and lights it from the fire, one feeds
  the fire, one dozes. As the light comes up they rise one at a time and go out to gather.
  The road reaches the next hearth in about 40 minutes of walking, so you arrive before dusk,
  or at dusk at the latest, and watch that camp's circle form.
- **The fire breathes** *(locked 3 Oct, §CZ; not built yet)*: the coals at its foot pulse, and
  sparks and ash fly up at random, in time with its pops.
- **The torch is the first tool.** It lights at a fire, burns about one night, and can be
  planted in the ground. Its head glows like a coal.
- **Every torch is from somewhere** *(locked 3 Oct; not built yet)*: each camp leaves its own
  kind by the fire (fatwood among pines, birch bark by the lakes, fir candles in the marsh,
  ichu grass in the highlands, a plain brand elsewhere). Each trades how far its light reaches
  against how long it lasts, and a bigger light keeps the dark further back. A coal carried
  from a hearth can bring a torch that went out back to life.
- **Fire is never made, only carried.** Fires burn fuel gathered from the world: wood, brush,
  dung, peat, whatever the biome offers. Embers can be saved, but a dead fire needs a flame
  brought to it.
- **Death:** you wake at your hearth, and any camp can be made home. Without one, you wake at
  the nearest fire *(3 Oct)*: one to three days have passed, and folk found you and carried you
  in. What you carried stays where you fell.
- **The dark:** away from light at night, the dark closes in, in stages you hear before you
  see. It's never a health-bar fight. Each biome is to get its own creature with its own
  approach; the werewolf is the first one built (§BA), and now hunts only on the full moon's
  brightest nights, by scent *(3 Oct)*. Your light keeps the lurkers back but tells the night
  where you are, so putting it out is a real choice *(3 Oct)*.
- **The moon sets the night** *(3 Oct)*: a full moon is bright enough to wander by, a new moon
  dark but readable. The day count runs in years.
- **The log:** Enter opens a record of what happened, stamped in game time, with causes of
  death and your own notes.

## Night life *(locked 1 Oct; not built yet)*

- **A shift change at dusk:** the day animals bed down, and a different cast wakes and comes
  out.
- **Places that keep the clock:** an old cave or an old bridge is empty by day and has
  something denned up in it at night.
- **Bats:** they pour out of caves and from under bridges at dusk and hunt by echolocation.
- **Sound:** a soundscape by place and hour, with cicadas by day and crickets, frogs and owls
  by night. Owls take rodents in the dark.

## Dungeons: every ruin is a delve *(locked 1 Oct; not built yet)*

- **The shape is Skyrim's:** a ruin's door leads down through a chain of rooms to a heart at
  the bottom, where the rare finds lie where someone left them. A way out from the heart loops
  you back to the surface.
- **The aesthetic is Morrowind's**, in the favourites' high-contrast colour. The architecture
  is our own, following each ruin's kind and people: crypts under barrows and tombs,
  undercrofts under castles, waterworks under aqueducts, the old flint and salt workings of a
  craft. Natural caves go deep too.
- **The danger:** inside is full dark. The light you carry is the clock, and the danger is
  the dark and what dens there. No fights.
- **Ruins by day** *(locked 3 Oct; not built yet)*: their halls are dark at noon, so the torch
  is never useless. Each wears the moss, ferns and vines of its own place, sounds like what
  lives in it, and the graveyards and tombs are sometimes haunted: a pale figure turns a corner
  ahead, and the corner is empty when you get there.

## Off the road *(locked 3 Oct; not built yet)*

- **Hidden places:** a grove with homes dug under the turf, a shrine's door under a great old
  tree, a shrine whose torches still burn going down into the ground. A few strange small folk
  live in them and say something cryptic, a line in the log.
- **The sealed scroll:** taken from a shrine's altar, unreadable, sealed. Somewhere down the road
  someone can read it, asks where you found it, and gives you the pattern of torches that opens
  the way deeper. No quest log and no markers: the scroll in your hands and the log are the
  quest.
- **Tomes:** real philosophical texts to find and read, the I Ching first.
- **Three sages** *(locked 3 Oct; not built yet)*: one who sits beneath the sacred fig; thirteen
  who walk the desert by day and sit round a carried fire at night, leaving a trail of cold
  rings; one old man who rides an ox up the pass roads, always on his way out. None of them is
  named in play.

## Monuments by realm *(locked 3 Oct; not built yet)*

A world grows only the monuments that belong to its lands: a whitewashed fortress climbing a
crag in Tibet-like country; a temple city in the monsoon forest with trees standing on its
galleries and faces on its gate towers; a wall running over the ridges for miles; facades cut
into a sandstone canyon; a town of stone rooms filling a sandstone alcove; a city of melted
brick on a desert river with its blue gate still standing; a row of stone heads on a treeless
coast; stepped adobe towns; stone circles; tower houses and brochs on the cold wet coasts. The
pyramids were already in, by region. Nothing is named after the real place. Later the same
night: a garden on a desert river that outlived its gardeners, a roofless abbey in cool wet
country, the columns of a house that burned, an open temple precinct with lotus ponds, shrines on
the tops of stone pillars joined by bridges, and a temple cut out of a hill that you find from
above; and the columns of an old lava flow, which look built and aren't, as a nest.

## Camps and peoples

- **Camps are alive.** Each has a woodpile and a food store you can see, and folk who gather
  by day, feed the fire and raise children. A camp grows while you're away, up to about 24
  people.
- **The ladder:** fire → food → storage → specialist → exchange. It stops there on purpose:
  no chiefs, walls or war. The four ways to stay put are crop, fish run, herd and the managed
  burn, and the land decides which a camp can take.
- **Three faces:** at a grown camp, the headman teaches you the site's technique. Camps give
  verbs, not tools: a fishing line, coppicing, the resin torch, the ember carrier, the fat
  lamp. **You never craft.** The plantkeeper (who knows the local plants) and the maker (who
  works materials you bring) are designed but not built yet (§BN).
- **Peoples are ways of life drawn from the site.** There are seventeen of them, including
  the canopy folk who live in the giant trees and never come down. They're our own folklore,
  mute but for a line in the log, and real peoples are cited as sources.
- **Endings:** camps die only from the dark or hunger. Their ruins are the part of a craft
  that doesn't rot, and a new camp that moves in restores them until you can read them.
- **Travellers:** cloaked figures walk the roads. They never speak, and their hoods follow
  you as you pass.
- **Wildfire:** rare. It needs lightning or a dropped torch in a dry spell, and wildflowers
  bloom in the scar.

## Interface

First person only, with nothing in view but what's in your hand. Text is set in a pixel font
inside the low-res frame. Readouts are few and pinnable: a railway pocket watch for the time,
a map on M, the log on Enter, and settings on O.

## Where it stands (1 Oct 2026)

**Built and playable** (`docs/PROGRESS.md` has the detail):
- the full 4,000 km planet, where every new world gets its own seed and its own kind of first
  camp, and opens on Day 1;
- the same picture on every machine, with no dependence on the editor's import cache;
- the slow first-person walk, the torch, fuel and the hearth, the dark, and the log;
- roads to every camp, including the opening road;
- camps that are alive, with their peoples and techniques, collapse, wildfire and the canopy
  folk;
- the one-card pixel fire;
- plants held to their habitats, with the catalogue trimmed and the named plants and vines
  always present;
- the look pass (navy grade, cobalt sky, electric water, 16-texel tiles), with the twenty
  favourites measured.

**Next and open:**
- the working camp: four or five folk at their jobs, each trip adding a piece to the store
  (§BV–§BW);
- the roads' desire lines and lost-and-found stretches (§BY);
- the landmark-and-road composition pass, so the world frames like the favourites;
- the epiphyte pass;
- the night-life pass;
- dungeons, and caves (Phase 3);
- the herd and the managed burn;
- wordless trade.

## How it's being built

The game is built in Godot 4 with GDScript, and Mike opens it straight in the Godot editor.
One designer directs two AI agents on one repository:
- **Claude Code** works in the engine: code, shaders, feel and checks.
- **Claude in chat** works on design, data and reference maths: the design docs, plant and
  people data filled by parallel research agents, and validators.

The locked design lives in dated documents with lettered sections, and a working agreement
says who owns what. Everything is procedural and rule-based on purpose. The goal is a world
that surprises its own creator.

## Open calls

1. **Day brightness.** Mike's favourites are darker by day than today's target. Should the
   day come down?
2. **Dungeon puzzles and traps.** Should there be puzzle doors and traps in the Skyrim way, or
   only the ruin falling apart? (One kind is now locked: the shrine's torch pattern, §DK.)
3. **Music.** Room tone carries the game for now. Is there ever a score?
