# `data/peoples/` — ways of life

Design 30 Sept 2026 §BO–§BQ. **A people is a way of life, not a nation.** Seventeen lives; the
site decides which one a camp lives (`biome_map.json`), and the biome dresses it (fuel, food,
shelter materials, palette) so two camps living the same life in different biomes look
nothing alike. *The way of life is the verb; the biome is the noun.* Nothing is hand-authored
twice.

One file per life: `<id>.json`. `coast.json` is the worked example — match its shape and its
level of detail. `tools/peoples_check.py` is the gate (0 errors before commit).

## Rules

1. **Our own folklore.** In-game names are generic and ours ("Coast folk", "Marsh folk");
   never a real nation's name in play. The fantastical folk (goblins, orcs, fae, small folk)
   are dressings on a way of life, and **all of them are friendly** — the dark is the only
   antagonist (§BA). `folk_kinds` is a suggestion of which kinds tend to live this life.
2. **Real peoples are analogues, in `real_world`.** They are what we learn from, cited, and
   what the plantkeeper's and log's educational lines can draw on. Write them with respect
   and accuracy; these are living cultures and their ancestors. Three to eight sources per
   file (Wikipedia is fine as a starting point; museum, university and archaeology pages
   are better).
3. **Techniques are verbs, learned, permanent, weightless.** The headman bestows the site's
   technique on contact (a quest gate — "their woodpile is low, bring wood" — comes later).
   A technique's `id` is either one from `techniques.json` (preferred) or new and unique
   across all files. `player_can` says whether the player performs it in the world, or it
   is a camp thing that raises the camp's ceilings.
4. **Materials are for makers.** A material is useless in the player's pack; a people's
   `maker` works what its land supports, and what the player brings. **No metal at all** (§EH, 5 Oct, supersedes §BO's bog-iron exception): the craft ceiling
   is fired clay, bone/antler/horn, knapped and ground stone, worked wood and fibre. No tool
   tiers, no ladder from copper to steel. No periodic table.
5. **The four fundamentals** (§BM): `crop` (river, valley), `fish_run` (coast, lake, river),
   `herd` (steppe, savanna, taiga, highland — built last), `managed_burn` (grassland,
   savanna, scrub). `forage` is the floor everyone starts on. A life names one.
6. **The ladder** (§BM): fire → food → storage → specialist → exchange. Hierarchy, walls,
   tribute and war are the rung *not* built; the ruins ran past it.
7. **The ruin is the part of the craft that does not rot** (§BQ). Wood, rope, hide and
   thatch are gone in a generation; waste and stone remain. Every signature says what it
   is, when it becomes legible (`heap` → `cleared` → `restored`, as a camp restores it), and
   what a camp squatting there inherits.
8. **Restraint is a rule, not a lecture** (§BL): a camp may take less than the land
   regrows. `growth.restraint` says how this life does that (coppice, weir, swidden left to
   close, the burn in season).
9. **Fuel kinds** must exist in `data/fuel.json → kinds`. **Biome keys** must be
   `BiomeTemplates` names (`data/biomes/*.json → key`). Light ids must be technique ids.
10. Keep a file to roughly 300–370 lines of JSON as formatted (coast.json is 311). Compact facts, no essays; the essay is
    the `real_world` note and the technique `teaches` line.

## Field guide (see `coast.json`)

`id`, `name`, `one_line` · `where` (`site_rule`, `biomes`, `needs`) · `fundamental` ·
`food` (`staples`, `how`, `preserve`) · `fuel` (`kinds`, `note`) · `shelter` (`materials`,
`form`) · `light` (technique ids) · `dressing.by_biome` (what changes per biome) ·
`specialists` (`headman_teaches`, `plantkeeper`, `maker`) · `techniques[]` (`id`, `name`,
`verb`, `teaches`, `unlocks`, `player_can`, `category`) · `materials` (`gives`, `wants`) ·
`growth` (`ladder`, `restraint`, `ceiling_hint`) · `ruin` (`signatures[]`, `plants_differ`) ·
`aesthetic` (`silhouette`, `palette`, `sounds`, `props`) · `huts` (§EL, 5 Oct: `soft`, `hard`, `hearth`,
`kiln`, `porch_sign`, `library`, each a list of props; `rung` says when the hut appears) · `folk_kinds` · `real_world[]`
(`analogue`, `region`, `note`, `source`) · `sources[]`.
