# Ruin roster: cultures, stone, plant, compass (reference, not built)

9 Oct 2026. Written from Mike's voice session (design §FM.8). **Only the tomb is built.** This is
the reference for the ruins that come later, so each can be built with its own stone and its own
plant without a new round of research. Nothing here is a build task and nothing here is locked
except what §FM says is Mike's. Where a line is Claude's suggestion, it says so.

Use lines describe rites only, with no doses and no preparation. One ruin, one stone (§EX.1): each
ruin kind becomes one `masonry.json` style when it is built.

## The compass (Mike's reading of the globe; thematic, not an atlas)
```
                    Pueblo (Mesa Verde)
                           |
                    Peyote country (invented ruin)
                           |
  (west: nothing)       AZTEC  ------  Gulf South swamp (east)
                           |
                          Maya
                           |
                          Inca  ------  Great Zimbabwe (east)
                           |
                        Amazon (south of the Inca)

  Unplaced: the taiga "barbarian" ruin (fly agaric)
```
Fixed connections, the same every playthrough (§FM.8). The Maya and the Inca are not strictly
"south" of the Aztec and Great Zimbabwe is across the Atlantic from the Inca: Mike accepted the
map as thematic.

## The ruins

### Aztec (the tomb's world; §FM.3)
- **Stone:** volcanic. Basalt and andesite, and tezontle, a reddish, porous volcanic rock that
  gives the pitted red look. Real analogue: the Templo Mayor of Tenochtitlan.
- **Plant:** ololiuhqui (*Ipomoea corymbosa*), a woody vine with poisonous seeds. Aztec priests
  and Oaxacan healers used it for divination. Visionary. Entry in `data/sacred` (9 Oct), not drawn yet.
- **Set dressing:** cacao (*Theobroma cacao*), the frothy drink of feasts and offerings, beans as
  money; shared with the Maya. Not in the game.
- **Plant status:** Claude's suggestion that ololiuhqui is this ruin's brew plant; Mike took it in
  the lock-in and has not named another.
- **Amended 10 Oct (§FN):** Mike names the mushroom, teonanácatl, as the Aztec ruin's brew plant
  ("the Aztecs are more focused on the mushrooms"). Both are Aztec in the sacred-plants reference.
  Whether ololiuhqui stays as a second Aztec plant is open. The ruin is a temple, not a tomb, with
  a round blood-altar chamber, a calendar room (the tonalpohualli) and the feathered-serpent boss:
  `data/aztec_temple.json`. Its marks are pictographic day-sign glyphs (`data/visions.json`). The
  desert surface cannot grow either plant honestly (§FN.8 call 1).

### Maya (south of the Aztec)
- **Stone:** pale limestone, soft when quarried and hardening in the air, which is why the carving
  is so fine. Real analogues: Tikal, Palenque.
- **Plant:** teonanácatl (*Psilocybe mexicana*), the "divine mushroom" (the old gloss "flesh of
  the gods" is disputed). Aztec feasts and Mazatec healing vigils are documented; the Maya
  evidence is indirect and debated (mushroom stones of the Guatemalan highlands). Visionary.
  Entry in `data/sacred` (9 Oct), not drawn yet.
- **Amended 10 Oct (§FN.5):** Mike gives the mushroom to the Aztec ruin, so the Maya have no plant
  of their own for now (open, §FN.8 call 2). Their marks are a full logosyllabic script.
- **Overlap to know about:** the same mushroom serves the Aztec rites, so the two worlds share it.
  Claude's suggestion, not locked: the Maya water lily (*Nymphaea ampla*) as a motif. It is white,
  and its sedative effect is inferred from art only.
- **Locked 10 Oct (§FQ):** the Maya lowland heartland (Yucatan and Peten): a limestone temple, once
  red-painted stucco and now bare grey, swallowed by jungle, with the Maya calendar as its motif and
  a cenote (the underworld door) as a way down (the cenote's role is open). **Boss: Camazotz,** the
  death bat of the Popol Vuh: he roosts overhead where he predicts you will pass, swoops once and
  keeps swooping where there is room, and crawls where there is not (`data/maya_ruin.json`, unplaced
  in `bosses.json`). A ruin kind inside a biome world, not a world of its own (§FN.0.2).

### Inca (south of the Maya)
- **Stone:** precision-cut andesite and granite, fitted without mortar. Real analogues: Machu
  Picchu, Ollantaytambo.
- **Plants:** San Pedro (*Echinopsis pachanoi*, the *Trichocereus* of the data), for the brew.
  Northern Peruvian healers' mesa rites, going back to Chavín, so older than the Inca. In the
  game. And coca (*Erythroxylum coca*), a mild stimulant whose leaves are offered to the apus and
  Pachamama; chewed in life, nothing like refined cocaine. Entry in `data/sacred` (9 Oct), not
  drawn yet. No effect chosen for coca (§FM.7). Var. *coca* is known only in cultivation.

### Amazon (south of the Inca)
- **Stone:** none. Earthworks: the ditched geoglyph enclosures of Acre, the mounds and causeways of
  the Llanos de Mojos, dark earth. Packed earth and ditch, not carved stone.
- **Plant:** the ayahuasca vine (*Banisteriopsis caapi*), central to visionary and healing rites of
  many Amazonian peoples. Visionary. Entry in `data/sacred` (9 Oct), not drawn yet.

### Great Zimbabwe (east of the Inca)
- **Stone:** dry-stone granite walls laid without mortar, the conical tower, the great enclosure.
  The Shona city, about the 11th to 15th century.
- **Plant:** leshoma (*Boophone disticha*), a poisonous bulb. Zulu, Xhosa, Shona and San healers
  use it in divination and initiation. Visionary, dangerous. Entry in `data/sacred` (9 Oct), not
  drawn yet: the engine has no bulb shape.
- **Left off:** iboga, which is Central and West African (Bwiti, Gabon), not Shona country.

### Peyote country (north of the Aztec; an invented ruin)
- **Stone:** Claude's suggestion, Mike asked for the local rock: adobe and sandstone. There is no
  monumental stone tradition here, so this ruin is our own. A real adobe city to borrow from:
  Paquimé (Casas Grandes), Chihuahua.
- **Plant:** peyote (*Lophophora williamsii*), visionary (mescaline). The Wixárika pilgrimage to
  Wirikuta, and Native American Church all-night meetings. **IUCN Vulnerable.** Mike's call: keep
  it, with the shaman teaching the proper, respectful harvest (§FM.7). Entry in `data/sacred`
  (9 Oct), not drawn yet: the engine has no shape for a low globe cactus.

### Pueblo / Mesa Verde (north of peyote country)
- **Stone:** sandstone blocks set in mud mortar and plaster, built into cliff alcoves.
- **Plant:** sacred datura (*Datura wrightii*), a deliriant. Documented for Southwest peoples such
  as the Zuni (divination) and the Havasupai and Navajo, not for Mesa Verde's builders in
  particular. Native to Mexico, the US Southwest and California. Its flowers are white,
  night-opening trumpets and do not glow. Mike's call: a different, unique experience, "not going
  to be more dangerous." Trimmed from the game on 1 Oct; a fresh entry is in `data/sacred` (9 Oct),
  not drawn yet. No source ties it to Mesa Verde's builders: only seeds at Ancestral Pueblo and
  Mogollon sites; the documented rites are Zuni and southern Californian.

### Gulf South swamp (east of the Aztec)
- **Stone:** none to speak of. Claude's suggestion: earth and timber. Real analogues: the mounds of
  Poverty Point (Louisiana, over 3,000 years old) and Moundville (Alabama).
- **Plant:** not chosen. Claude's candidate: yaupon (*Ilex vomitoria*), the holly whose leaves
  made the Southeast's ceremonial "black drink" of purification and council. A mild stimulant, so
  not a visionary brew. `Ilex` appears in the floodplain and maritime forest biome files; check
  for *vomitoria* before relying on it.
- **Boss:** the witch (§EY, §FE) is the swamp's, already specified.

### Egypt (unplaced; §FO.1, §FP)
- **Stone:** big sandstone blocks (`masonry.json → egyptian_pyramid`, queue 88). One floor, like every ruin (§FO).
- **Plants:** blue lotus (*Nymphaea caerulea*) and mandrake (*Mandragora officinarum*), locked by Mike
  10 Oct (§FP.4); both in `data/sacred/sacred_plants.json`. Neither draws yet (no water-lily shape,
  no trunkless rosette). **Honest habitat (§FP.5):** mandrake is not native to Egypt (it came in with
  the New Kingdom, likely from Canaan) and blue lotus needs standing fresh water, so the biome world
  that holds the ruin (§FO.9 call 2) also decides where these two grow.
- **Boss:** a mummy pharaoh whose own sarcophagus is its lair (`bosses.json → unplaced.pharaoh`);
  plague states join its pool, the locust swarm first (§FP.2). Ordinary mummies are residents.
- **Life and marks:** ambient scarabs (§FP.1); real hieroglyphs on the walls, readable only under the brew (§FP.3).
- **Position:** Mike has not placed it on the compass (`ruin_compass.json → ruins.egypt`, unplaced).

### Taiga "barbarian" ruin (unplaced)
- **Stone:** none. Dark weathered timber and log-and-earth pit dwellings, bone and antler detail;
  permafrost and forest make stone rare this far north.
- **Plant:** fly agaric (*Amanita muscaria*), a deliriant. Siberian trance rites of the Koryak,
  Chukchi and Khanty. In the game (taiga only; it belongs in temperate deciduous woods and
  temperate rainforest too).
- **Position:** Mike has not placed it on the compass.

## What each ruin needs before it can be built
1. Its place on the compass (the taiga and Egypt lack one).
2. A `masonry.json` style for its stone (§EX.1).
3. Its plant drawn by the engine. All nine entries are written (seven on 9 Oct, blue lotus and mandrake on 10 Oct) in
   `data/sacred/sacred_plants.json`, with their habitat, look, rite and sources; it is not loaded
   yet. Four need an engine shape first (the mushroom, peyote's globe, leshoma's bulb, the
   ayahuasca vine's twist, and Egypt's water-lily and rosette); see the file's `flags`.
4. Mike's answer to §FM.10 call 1: how a culture ruin sits with the eight biome worlds.
