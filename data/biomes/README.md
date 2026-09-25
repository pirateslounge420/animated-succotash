# Biome plant data

One file per biome (51 files: the 50 surface biome templates from
DESIGN.md plus Karst/caves). This is where plant variety goes: add plants
to a biome's `plants` lists and they appear in the game the next time you
run it. No code changes needed.

## How plants spread (important)

Per DESIGN.md, **plants read climate, not biome names**. Listing a plant
under a biome does not lock it to that biome. It gives the plant that
biome's climate as its default tolerance range, and the plant then grows
anywhere on the planet with matching climate, fading out toward the edges
of its range. That is why neighboring biomes blend instead of snapping.

If you list the same plant name in several biome files, its range becomes
the union of those biomes' climates.

## The smallest possible entry

```json
"canopy": [
	{"name": "Kapok tree"}
]
```

That's enough. It uses the biome's `climate` block for temperature,
moisture and altitude, and default size, shape and color for its tier.

## All fields (all optional except `name`)

| Field | Example | Meaning |
|---|---|---|
| `name` | `"Bald cypress"` | Unique plant name. |
| `shape` | `"cypress"` | Placeholder silhouette (see list below). Defaults by tier. |
| `height_m` | `[18, 30]` | Height range in meters; each plant picks a size in it. |
| `temp_c` | `[12, 28]` | Mean annual temperature range, **°C**. Densest in the middle, fading to zero at the edges. |
| `moisture` | `[0.6, 1]` | Effective moisture, 0 = bone dry to 1 = waterlogged (~0.1 hyper-arid, ~0.3 semi-arid, ~0.5 subhumid, ~0.7 humid). |
| `altitude_m` | `[800, 3700]` | Elevation range in meters. |
| `density` | `0.3` | Peak abundance relative to other plants (1 = normal, 0.1 = rare hero plant). |
| `soil` | `"thin"` | `rich` (default), `thin` (rocky/karst/sandstone), `peat`, `sand` (coastal sand only), `wet` (alluvial/peat), `volcanic` (basalt only). |
| `needs` | `["standing_water"]` | Special conditions: `standing_water`, `river_bank`, `salt_water`, `hot_ground`. |
| `water_depth_m` | `[0.05, 2]` | With `standing_water`: how deep the water around its roots may be. |
| `color` | `"#59804c"` | Leaf/main color. |
| `accent` | `"#807a70"` | Trunk, stem or flower color. |
| `source` | `"..."` | Where the research came from. |

Tiers (the lists under `plants`): `emergent`, `canopy`, `shrub`, `ground`,
`epiphyte`. Epiphytes are never scattered on the ground; they attach to
canopy and emergent trees already placed.

Shapes: `conifer`, `broadleaf`, `gnarled`, `emergent`, `umbrella`, `palm`,
`cypress`, `mangrove`, `rosette`, `spike_rosette`, `shrub`, `tussock`,
`grass`, `reed`, `fern`, `tree_fern`, `cactus`, `cushion`, `moss`,
`hanging_moss`, `epiphyte_clump`, `liana`, `knees`, `thermophile_mat`,
`bamboo` (a clump of culms; works from dwarf 1 m bamboo to 30 m giants).
These are low-poly placeholders; real models replace them later.

## Biome file fields

`key` must match the biome template name in
`scripts/biomes/biome_templates.gd`; don't change it. `status` is
`researched`, `placeholder` (plausible plants, to be replaced) or
`empty`. `kind` is `land`, `water` (aquatic: no underwater plant tier
yet) or `underground` (caves: not built yet).

Invalid entries are skipped with a warning in the Godot output panel,
naming the file and plant.

## Exporting

When exporting the game, add `*.json` to the export's "Filters to export
non-resource files" so these files ship with it.
