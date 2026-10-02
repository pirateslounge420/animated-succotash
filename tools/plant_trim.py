#!/usr/bin/env python3
"""The trim to archetypes (design 1 Oct §CC, data/habitat.json trim).

    python3 tools/plant_trim.py table            # categorise every entry; print per biome; write
                                                 # docs/plant_archive/TRIM_2026-10-01.md
    python3 tools/plant_trim.py survivors        # after the trim: per biome and category the
                                                 # survivors, the over-four and the thin, totals
    python3 tools/plant_trim.py result           # docs/plant_archive/TRIM_RESULT_2026-10-01.md: each
                                                 # biome's species after the trim, by category
    python3 tools/plant_trim.py sync-tags        # every biome-file entry's `biomes` = the union of
                                                 # the biome files that list it (the §CA gate)
    python3 tools/plant_trim.py check-keep       # re-run the trim's choice (plan) on every biome file
                                                 # and assert it keeps every always_keep member
                                                 # (design 1 Oct §CE), the 21 restored ones by name

Categories (trim.categories): tree, shrub, grass, moss, orchid, aroid, fern, cacti,
fungi, vine (§CE: climbers and creepers, the tenth), or "none". The always_keep groups
(habitat.json trim.always_keep, matched as always_present.groups lists them: genus,
shape, name) are never trimmed, whatever the per-category cap (§CE). category_of(entry, file) maps an entry from its tier, shape, leaf
type, genus, family and name, following trim.category_of in habitat.json; the mapping
is deterministic and prints a reason, so the designer can see what went where. Entries
that fit no category (vines, kelp, cushion plants, herbs, bromeliads, carnivorous
plants, rosette succulents) are "none": archived unless they are a hero_species.
"""
import glob
import json
import os
import sys
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HAB = json.load(open(os.path.join(ROOT, "data", "habitat.json")))
TRIM = HAB.get("trim", {})
CATS = TRIM.get("categories", ["tree", "shrub", "grass", "moss", "orchid", "aroid", "fern", "cacti", "fungi"])
KEEP_WHOLE = set(TRIM.get("keep_whole", ["cannabis.json", "trichocereus.json", "amorphophallus.json"]))
PER = int(TRIM.get("per_biome_per_category", 4))
# The named plants (design 1 Oct §CE): never trimmed.
GROUPS = (HAB.get("always_present", {}) or {}).get("groups", {})
ALWAYS_KEEP = [g for g in TRIM.get("always_keep", []) if g in GROUPS]
# The 21 the §CC trim cut before §CE, restored in b8c1809.
RESTORED_21 = ["Fever tree", "Camel thorn", "Whitethorn acacia", "Coastal wattle",
               "Giant bamboo", "Bamboo thicket", "Moso bamboo", "Colihue", "Kuril bamboo",
               "Kuma bamboo grass", "Savanna bamboo", "Ivy", "Virginia creeper", "Riverbank grape",
               "Muscadine grape", "Passion vine", "Rattan vine", "Rattan palm", "Liana",
               "Beach morning glory", "Fire lily"]


def group_of(e, cat=None):
    """The always_present group an entry belongs to ("" for none), matched as the
    placer matches it (VegetationPlacer.presence_group): genus, shape, name, or the
    trim category a group names."""
    genus = str(e.get("genus", "") or "")
    shape = str(e.get("shape", "") or "").lower()
    name = str(e.get("name", "")).lower()
    for g, d in GROUPS.items():
        if genus in d.get("genera", []) or shape in d.get("shapes", []):
            return g
        if any(str(f) in name for f in d.get("names_contain", [])):
            return g
        if cat is not None and d.get("category") and cat == d.get("category"):
            return g
    return ""
TIERS = ("emergent", "canopy", "shrub", "ground", "epiphyte")

AROID_GENERA = {"Alocasia", "Colocasia", "Philodendron", "Monstera", "Bucephalandra", "Epipremnum", "Anthurium",
                "Lysichiton", "Symplocarpus", "Xanthosoma", "Arum", "Zantedeschia", "Caladium", "Spathiphyllum",
                "Pistia", "Cryptocoryne", "Anubias", "Aglaonema", "Dieffenbachia", "Amorphophallus", "Arisaema",
                "Calla", "Rhaphidophora", "Scindapsus", "Syngonium", "Typhonium", "Orontium", "Peltandra"}
CACTI_GENERA = {"Carnegiea", "Pachycereus", "Opuntia", "Cylindropuntia", "Ferocactus", "Echinocactus", "Mammillaria",
                "Cereus", "Stenocereus", "Lophocereus", "Trichocereus", "Echinopsis", "Pereskia", "Rhipsalis",
                "Alluaudia", "Didierea", "Euphorbia", "Myrtillocactus", "Lophophora", "Browningia", "Oreocereus",
                "Cleistocactus", "Hylocereus", "Selenicereus", "Copiapoa", "Eulychnia", "Neoraimondia", "Armatocereus",
                "Melocactus", "Pilosocereus", "Cephalocereus", "Fouquieria"}
ORCHID_GENERA = {"Cypripedium", "Ophrys", "Phalaenopsis", "Dendrophylax", "Ansellia", "Dendrobium", "Vanda", "Cattleya",
                 "Orchis", "Dactylorhiza", "Epidendrum", "Oncidium", "Paphiopedilum", "Vanilla", "Bulbophyllum",
                 "Masdevallia", "Pleurothallis", "Eulophia", "Habenaria", "Platanthera", "Goodyera", "Calypso",
                 "Corallorhiza", "Spiranthes", "Cymbidium", "Coelogyne", "Laelia", "Encyclia", "Disa", "Satyrium",
                 "Thelymitra", "Caladenia", "Pterostylis", "Diuris", "Angraecum", "Aerangis", "Polystachya"}
CARNIVORE_GENERA = {"Sarracenia", "Nepenthes", "Darlingtonia", "Heliamphora", "Drosera", "Dionaea", "Pinguicula",
                    "Utricularia", "Cephalotus", "Byblis", "Roridula", "Genlisea", "Brocchinia"}
LICHEN_GENERA = {"Cladonia", "Rhizocarpon", "Umbilicaria", "Usnea", "Xanthoria", "Ramalina", "Parmelia", "Cetraria",
                 "Lecanora", "Stereocaulon", "Alectoria", "Bryoria", "Letharia", "Evernia", "Peltigera", "Lobaria"}
FUNGI_WORDS = ("mushroom", "bolete", "agaric", "bracket", "puffball", "conk", "chanterelle", "morel", "truffle", "inkcap",
               "polypore", "fungus", "fungi", "parachute", "bonnet", "blewit", "champignon", "roundhead", "cordyceps",
               "shank", "oyster", "shiitake", "reishi", "matsutake", "milkcap", "death cap", "lion's mane", "split gill",
               "jack-o", "tinder", "coral tooth", "turkey tail", "chicken of the woods", "dryad's saddle", "lichen",
               "rock tripe", "earthstar", "stinkhorn", "waxcap", "amanita", "russula", "lactarius", "boletus", "carcass cup")
MOSS_WORDS = ("moss", "liverwort", "sphagnum", "clubmoss", "club moss", "hornwort", "peat moss")
MOSS_NOT = ("spanish moss", "ball moss", "reindeer moss", "irish moss", "sea moss", "iceland moss")
FERN_WORDS = ("fern", "bracken", "selaginella", "spikemoss", "spike moss", "polypody", "maidenhair", "horsetail")
GRASS_WORDS = ("grass", "sedge", "rush", "reed", "cattail", "bulrush", "cordgrass", "spinifex", "oat", "fescue", "grama",
               "bluestem", "needlegrass", "feathergrass", "tussock", "cotton-grass", "cottongrass", "papyrus", "wild rice",
               "sawgrass", "bentgrass", "brome", "ryegrass", "wheatgrass", "buffalograss", "switchgrass", "cane", "bamboo",
               "miscanthus", "pampas", "phragmites", "cyperus", "carex", "juncus", "stipa", "festuca", "poa", "typha",
               "sorghum", "millet", "andropogon", "themeda", "hyparrhenia", "pennisetum", "elephant grass", "spear grass",
               "red grass", "savanna grass", "snow grass", "hair grass", "lyme grass", "marram", "eelgrass", "turtlegrass",
               "glasswort")
CACTI_WORDS = ("cactus", "cacti", "saguaro", "cardon", "cardón", "prickly pear", "barrel", "cholla", "ocotillo",
               "candelabra", "euphorbia", "organ pipe", "senita", "peyote", "nopal", "cereus", "torch")
AROID_WORDS = ("taro", "skunk cabbage", "philodendron", "monstera", "pothos", "aroid", "alocasia", "colocasia",
               "bucephalandra", "elephant ear", "anthurium", "arum", "jack-in-the-pulpit", "cuckoo-pint")
ORCHID_WORDS = ("orchid", "lady's slipper", "ladies' tresses", "helleborine", "twayblade", "vanilla")


import re


def has_word(name, words):
    """Any of `words` in `name` as a whole word (so "brome" is not in "bromelia")."""
    for w in words:
        if re.search(r"(?<![a-z])" + re.escape(w) + r"(?![a-z])", name):
            return True
    return False


## Forbs and aquatic herbs whose entries borrow the grass or reed shape
## for drawing (found by the §CC group agents): botanically no category.
FORB_GENERA = {"Chamaenerion", "Epilobium", "Sphaeralcea", "Echinacea", "Silphium", "Balsamorhiza", "Tulipa",
               "Asphodelus", "Castilleja", "Erythranthe", "Mimulus", "Silene", "Ipomoea", "Cakile", "Solidago",
               "Impatiens", "Urtica", "Parnassia", "Iris", "Elodea", "Potamogeton", "Myriophyllum"}

_FUNGI_GENERA = None


def fungi_genera():
    """The genera of the fungi catalogue, wherever it lives (data/plants
    before the §CC archive, docs/plant_archive after): a mushroom copied
    into a biome file stays a fungus."""
    global _FUNGI_GENERA
    if _FUNGI_GENERA is None:
        _FUNGI_GENERA = set()
        for p in (os.path.join(ROOT, "data", "plants", "fungi.json"), os.path.join(ROOT, "docs", "plant_archive", "fungi.json")):
            if os.path.exists(p):
                d = json.load(open(p, encoding="utf-8"))
                for lst in (d.get("plants") or {}).values():
                    for x in lst:
                        if x.get("genus"):
                            _FUNGI_GENERA.add(x["genus"])
    return _FUNGI_GENERA


def category_of(e, tier, fname):
    """-> (category, reason)."""
    name = str(e.get("name", "")).lower()
    genus = str(e.get("genus", "") or "")
    family = str(e.get("family", "") or "")
    shape = str(e.get("shape", "") or "")
    leaf = e.get("leaf") if isinstance(e.get("leaf"), dict) else {}
    ltype = str(leaf.get("type", "") or "")
    if fname == "fungi.json" or isinstance(e.get("fungus"), dict) or genus in LICHEN_GENERA or genus in fungi_genera() or has_word(name, FUNGI_WORDS) or family in ("Cladoniaceae", "Parmeliaceae", "Umbilicariaceae"):
        return "fungi", "fungi.json / a mushroom, bracket, puffball or lichen"
    if genus == "Amorphophallus" or genus in AROID_GENERA or family == "Araceae" or has_word(name, AROID_WORDS):
        return "aroid", "an aroid (genus %s)" % (genus or "by name")
    if genus in ORCHID_GENERA or family == "Orchidaceae" or has_word(name, ORCHID_WORDS):
        return "orchid", "an orchid"
    vine_genera = set((GROUPS.get("vines", {}) or {}).get("genera", [])) - AROID_GENERA
    if shape == "liana" or genus in vine_genera:
        return "vine", "a climber or creeper (shape %s, genus %s): the tenth category (§CE)" % (shape, genus or "?")
    if genus in CARNIVORE_GENERA or family in ("Sarraceniaceae", "Nepenthaceae", "Droseraceae", "Lentibulariaceae") or has_word(name, ("pitcher", "sundew", "flytrap", "butterwort", "bladderwort")):
        return "none", "a carnivorous plant: no category"
    if genus in ("Lycopodium", "Diphasiastrum", "Huperzia", "Lycopodiella", "Spinulum", "Dendrolycopodium", "Phlegmariurus"):
        return "moss", "a club moss (habitat.json trim: club mosses are moss)"
    if shape in ("fern", "tree_fern") or has_word(name, FERN_WORDS) or family in ("Cyatheaceae", "Dicksoniaceae", "Polypodiaceae", "Aspleniaceae", "Dryopteridaceae", "Salviniaceae", "Psilotaceae"):
        return "fern", "a fern (shape %s)" % shape
    if (shape in ("moss", "hanging_moss") or has_word(name, MOSS_WORDS) or family in ("Sphagnaceae",)) and not any(w in name for w in MOSS_NOT) and genus not in ("Tillandsia",):
        return "moss", "a moss, liverwort or sphagnum (shape %s)" % shape
    if shape == "cactus" or genus in CACTI_GENERA or family == "Cactaceae" or has_word(name, CACTI_WORDS):
        return "cacti", "a cactus or stem succulent (shape %s, genus %s)" % (shape, genus)
    if genus in FORB_GENERA:
        return "none", "a forb or aquatic herb drawn with a grass/reed shape (genus %s)" % genus
    if shape in ("grass", "tussock", "reed") or (tier == "ground" and has_word(name, GRASS_WORDS)) or family in ("Poaceae", "Cyperaceae", "Juncaceae", "Typhaceae"):
        return "grass", "a graminoid (shape %s)" % shape
    if shape == "bamboo":
        if tier in ("canopy", "emergent"):
            return "tree", "a giant bamboo at the canopy tier (woody culms)"
        return ("shrub" if tier == "shrub" else "grass"), "bamboo (%s tier)" % tier
    if tier in ("canopy", "emergent"):
        if shape in ("liana", "cushion", "thermophile_mat", "knees", "epiphyte_clump"):
            return "none", "no category (shape %s at the %s tier)" % (shape, tier)
        if shape in ("rosette", "spike_rosette") and genus in ("Yucca", "Agave", "Aloe", "Dracaena", "Dasylirion", "Nolina", "Puya", "Espeletia"):
            return "none", "a rosette succulent / giant rosette, not a stem succulent (shape %s)" % shape
        return "tree", "the %s tier, shape %s" % (tier, shape)
    if tier == "shrub":
        if shape in ("shrub", "gnarled", "broadleaf", "conifer", "mangrove", "umbrella", "palm", "cypress", "emergent", "rosette"):
            if genus in ("Yucca", "Agave", "Aloe", "Dasylirion", "Nolina", "Puya", "Espeletia", "Furcraea", "Hesperaloe"):
                return "none", "a rosette succulent (not a stem succulent), shape %s" % shape
            if shape == "rosette" and genus not in ("Cycas", "Encephalartos", "Zamia", "Macrozamia", "Dioon", "Ceratozamia", "Dracaena", "Pandanus", "Cordyline"):
                return "none", "a rosette herb at the shrub tier (shape rosette, genus %s)" % (genus or "?")
            return "shrub", "the shrub tier, shape %s" % shape
        return "none", "no category (shape %s at the shrub tier)" % shape
    if tier == "epiphyte":
        return "none", "an epiphyte with no category (shape %s, genus %s)" % (shape, genus or "?")
    # ground
    return "none", "a ground plant with no category (shape %s, genus %s)" % (shape, genus or "?")


def load_all():
    """[(file, key or "", tier, entry)] for biome files then catalogues."""
    out = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "biomes", "*.json"))):
        d = json.load(open(f))
        for tier in TIERS:
            for e in (d.get("plants") or {}).get(tier, []) or []:
                if isinstance(e, dict):
                    out.append((os.path.basename(f), d.get("key", ""), tier, e, d))
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "plants", "*.json"))):
        d = json.load(open(f))
        for tier in TIERS:
            for e in (d.get("plants") or {}).get(tier, []) or []:
                if isinstance(e, dict):
                    out.append((os.path.basename(f), "", tier, e, d))
    return out


def table():
    rows = load_all()
    md = ["# The trim to archetypes — the category of every entry (design §CC, 1 Oct 2026)", "",
          "Made by `python3 tools/plant_trim.py table` before anything was trimmed: every entry of every biome file and catalogue, the category `category_of` gave it and why. Nine categories; `none` is archived unless the biome's hero. `tree`, `shrub`, `grass`, `moss`, `orchid`, `aroid`, `fern`, `cacti`, `fungi`.", ""]
    totals = {}
    by_file = OrderedDict()
    species = set()
    for fname, key, tier, e, d in rows:
        cat, why = category_of(e, tier, fname)
        totals[cat] = totals.get(cat, 0) + 1
        species.add("%s %s" % (e.get("genus", ""), e.get("species", "")) if e.get("genus") else e.get("name"))
        by_file.setdefault(fname, {"key": key, "hero": d.get("hero_species", []), "rows": []})["rows"].append((cat, tier, e.get("name", "?"), why))
    print("%d entries, %d species; by category: %s" % (len(rows), len(species), ", ".join("%s %d" % (c, totals.get(c, 0)) for c in CATS + ["none"])))
    md.append("**Before the trim:** %d entries, %d species. By category: %s." % (len(rows), len(species), ", ".join("%s %d" % (c, totals.get(c, 0)) for c in CATS + ["none"])))
    md.append("")
    for fname, info in by_file.items():
        cats = OrderedDict((c, []) for c in CATS + ["none"])
        for cat, tier, name, why in info["rows"]:
            cats[cat].append((tier, name, why))
        head = "%s (%s)" % (fname, info["key"]) if info["key"] else fname
        counts = ", ".join("%s %d" % (c, len(v)) for c, v in cats.items() if v)
        print("%-28s %s%s" % (head, counts, ("  hero: " + ", ".join(info["hero"])) if info["hero"] else ""))
        md.append("## %s" % head)
        if info["hero"]:
            md.append("Hero species (always survive): %s" % ", ".join("**%s**" % h for h in info["hero"]))
        md.append("")
        md.append("| category | count | entries (tier) |")
        md.append("|---|---|---|")
        for c, v in cats.items():
            if not v:
                continue
            md.append("| %s | %d | %s |" % (c, len(v), "; ".join("%s (%s)" % (n, t) for t, n, _ in v)))
        nones = cats["none"]
        if nones:
            md.append("")
            md.append("No category (archived unless a hero): " + "; ".join("%s — %s" % (n, w) for t, n, w in nones))
        md.append("")
    out = os.path.join(ROOT, "docs", "plant_archive", "TRIM_2026-10-01.md")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "w").write("\n".join(md) + "\n")
    print("wrote", os.path.relpath(out, ROOT))


def survivors():
    rows = load_all()
    per = {}
    heroes = {}
    nspecies = set()
    n = 0
    keep_names = set()
    for fname, key, tier, e, d in rows:
        if key and group_of(e, category_of(e, tier, fname)[0]) in ALWAYS_KEEP:
            keep_names.add(e.get("name"))
    for fname, key, tier, e, d in rows:
        if not key:
            continue
        n += 1
        nspecies.add(e.get("name"))
        cat, _ = category_of(e, tier, fname)
        per.setdefault(key, {}).setdefault(cat, []).append(e.get("name"))
        if e.get("name") in (d.get("hero_species") or []):
            heroes.setdefault(key, set()).add(e.get("name"))
    over = []
    none_tree = []
    none_grass = []
    print("Survivors per biome and category:")
    for key in per:
        line = ", ".join("%s %d" % (c, len(per[key].get(c, []))) for c in CATS + ["none"] if per[key].get(c))
        print("  %-22s %s" % (key, line))
        for c in CATS:
            # Heroes always survive and sit on top of the four (§CC: the
            # seed list takes the four first).
            n_slot = len([x for x in per[key].get(c, []) if x not in heroes.get(key, set()) and x not in keep_names])
            if n_slot > PER:
                over.append("%s %s %d (+%d heroes)" % (key, c, n_slot, len(per[key][c]) - n_slot))
        if not per[key].get("tree"):
            none_tree.append(key)
        if not per[key].get("grass"):
            none_grass.append(key)
    cat_n = 0
    cat_sp = set()
    for fname, key, tier, e, d in rows:
        if key:
            continue
        cat_n += 1
        cat_sp.add(e.get("name"))
    print("Biome entries %d (%d species); catalogue entries %d (%d species); grand total %d entries, %d species" % (n, len(nspecies), cat_n, len(cat_sp), n + cat_n, len(nspecies | cat_sp)))
    print("Over %d in a category (heroes not counted): %s" % (PER, over if over else "none"))
    print("Biomes with no tree: %s" % ", ".join(none_tree))
    print("Biomes with no grass: %s" % ", ".join(none_grass))
    return 1 if over else 0


def plan(d, fname):
    """The trim's choice for one biome file, re-run: per category the heroes and every
    always_keep member (§CE), then the first `PER` others in the file's order (the seed
    list's picks were written first). -> (kept names, cut names)."""
    heroes = set(d.get("hero_species") or [])
    kept, cut = [], []
    slots = {}
    for tier in TIERS:
        for e in (d.get("plants") or {}).get(tier, []) or []:
            if not isinstance(e, dict):
                continue
            cat, _ = category_of(e, tier, fname)
            name = e.get("name")
            if name in heroes or group_of(e, cat) in ALWAYS_KEEP:
                kept.append(name)
                continue
            if cat == "none":
                cut.append(name)
                continue
            slots[cat] = slots.get(cat, 0) + 1
            (kept if slots[cat] <= PER else cut).append(name)
    return kept, cut


def check_keep():
    """Re-run the trim's choice on every biome file and assert it keeps every
    always_keep member, the 21 restored ones by name. Exit 1 on a miss."""
    fails = 0
    members = {}
    seen21 = set()
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "biomes", "*.json"))):
        d = json.load(open(f))
        fname = os.path.basename(f)
        kept, cut = plan(d, fname)
        kept_set = set(kept)
        for tier in TIERS:
            for e in (d.get("plants") or {}).get(tier, []) or []:
                if not isinstance(e, dict):
                    continue
                g = group_of(e, category_of(e, tier, fname)[0])
                if g not in ALWAYS_KEEP:
                    continue
                members.setdefault(g, set()).add(e.get("name"))
                if e.get("name") in RESTORED_21:
                    seen21.add(e.get("name"))
                if e.get("name") not in kept_set:
                    print("FAIL  %s: %s (%s) would be trimmed" % (fname, e.get("name"), g))
                    fails += 1
    for g in ALWAYS_KEEP:
        print("  %-14s %3d species in the biome files: %s" % (g, len(members.get(g, ())), ", ".join(sorted(members.get(g, ())))[:200]))
    missing = [n for n in RESTORED_21 if n not in seen21]
    print(("PASS  " if not missing else "FAIL  ") + "the 21 restored species are in the biome files (%d of 21%s)" % (21 - len(missing), "; missing " + ", ".join(missing) if missing else ""))
    fails += len(missing)
    print(("PASS  " if fails == 0 else "FAIL  ") + "a re-run of the trim keeps every always_keep member (%d groups)" % len(ALWAYS_KEEP))
    print("RESULT fails: %d" % fails)
    return 1 if fails else 0


def result():
    """Markdown: what each biome holds after the trim, by category, with the
    binomials (docs/plant_archive/TRIM_RESULT_<date>.md)."""
    rows = load_all()
    per = OrderedDict()
    for fname, key, tier, e, d in rows:
        if not key:
            continue
        cat, _ = category_of(e, tier, fname)
        hero = e.get("name") in (d.get("hero_species") or [])
        b = ("%s %s" % (e.get("genus", "") or "", e.get("species", "") or "")).strip()
        per.setdefault((key, d.get("name", key)), OrderedDict()).setdefault(cat, []).append(
            "%s (*%s*)%s" % (e.get("name"), b, " — hero" if hero else ""))
    out = ["# The trim's result, 1 Oct 2026 (design §CC)", "",
           "What each biome file lists after the trim: at most four species per category, chosen from Mike's seed",
           "list first, then the biome's dominants and companions; heroes (`hero_species`) on top of the four.",
           "The three whole catalogues (cannabis, trichocereus, amorphophallus) still reach the biomes their own",
           "`biomes` lists name and are not listed here. Generated by `python3 tools/plant_trim.py result`.", ""]
    for (key, name), cats in per.items():
        out.append("## %s (`%s`)" % (name, key))
        for c in CATS + ["none"]:
            if cats.get(c):
                out.append("- **%s:** %s" % (c, "; ".join(cats[c])))
        out.append("")
    return "\n".join(out) + "\n"


def sync_tags():
    files = sorted(glob.glob(os.path.join(ROOT, "data", "biomes", "*.json")))
    listed = {}
    docs = {}
    for f in files:
        d = json.load(open(f))
        docs[f] = d
        for tier in TIERS:
            for e in (d.get("plants") or {}).get(tier, []) or []:
                if isinstance(e, dict) and e.get("name"):
                    listed.setdefault(e["name"], set()).add(d.get("key", ""))
    changed = 0
    for f, d in docs.items():
        dirty = False
        for tier in TIERS:
            lst = (d.get("plants") or {}).get(tier, []) or []
            for i, e in enumerate(lst):
                if not isinstance(e, dict) or not e.get("name"):
                    continue
                want = sorted(listed.get(e["name"], set()))
                if e.get("biomes") != want:
                    new = OrderedDict()
                    placed = False
                    for k, v in e.items():
                        if k == "biomes":
                            continue
                        new[k] = v
                        if k == "altitude_m" and not placed:
                            new["biomes"] = want
                            placed = True
                    if not placed:
                        new["biomes"] = want
                    lst[i] = dict(new)
                    dirty = True
                    changed += 1
        if dirty:
            with open(f, "w") as fh:
                json.dump(d, fh, indent=1, ensure_ascii=False)
                fh.write("\n")
    print("biomes tags synced on %d entries" % changed)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "table"
    if cmd == "table":
        table()
    elif cmd == "survivors":
        sys.exit(survivors())
    elif cmd == "sync-tags":
        sync_tags()
    elif cmd == "check-keep":
        sys.exit(check_keep())
    elif cmd == "result":
        path = os.path.join(ROOT, TRIM.get("archive_dir", "docs/plant_archive"), "TRIM_RESULT_2026-10-01.md")
        open(path, "w", encoding="utf-8").write(result())
        print("wrote", os.path.relpath(path, ROOT))
    else:
        print(__doc__)
