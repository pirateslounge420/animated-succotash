#!/usr/bin/env python3
"""Per-species plant tiles from the taxonomic data (design RECONCILIATION §AH,
PLANT_SCHEMA §0-§3, §1b).

Reads every plant entry in data/plants/*.json and data/biomes/*.json and renders, from
its `leaf` / `bark` / `tint` / `aroid` blocks, into assets/textures/plants/species/:

  <key>_leaf.png         48x48 RGBA  one leaf unit as a hard cutout: the real outline
                                     (ovate / cordate / palmate-lobed ...), margin teeth,
                                     venation lines, surface texture, coloured
  <key>_leaf_autumn.png  48x48 RGBA  the same leaf in its autumn colour (deciduous only)
  <key>_leaves.png       32x32 RGBA  tileable foliage mass: a scatter of that leaf, for
                                     canopy cards and the far LOD
  <key>_bark.png         64x64 RGB   tileable stem tile from the `bark` block (a ~40 cm
                                     square of trunk; nearest-filtered, §AG)
  <key>_petiole.png      32x128 RGB  Amorphophallus only: the petiole pattern grammar

plus assets/textures/plants/species/atlas_species.json: species name -> files, tile_m,
and colours. Identical renders are shared (one file, many species), so a genus of
look-alikes costs one tile. Deterministic: seeded by species name.

Colour convention (§AH): these tiles carry the SPECIES colour (from the entry's `color`
shifted by `tint`, and `bark.color` / `color_2`); the shader multiplies them by white
plus the per-individual genes jitter, not by the species colour again. Shading is
baked as a brightness map so the autumn variant is the same structure recoloured.

Usage: python3 tools/look/make_plant_tiles.py [--only GENUS] [--preview] [--seed N]
"""
import argparse, colorsys, glob, hashlib, json, math, os, re, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "textures", "plants", "species")
SS = 4                      # supersample
LEAF_PX, MASS_PX, BARK_PX = 48, 32, 64
PET_W, PET_H = 32, 128
LEVELS = 16                 # colour posterisation per channel (the grade adds the 5-bit dither)
BARK_TILE_M = 0.4


# ---------------------------------------------------------------- colour helpers

def hex_rgb(h, default=(0.3, 0.5, 0.25)):
    try:
        h = h.lstrip("#")
        return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    except Exception:
        return default


def tint_rgb(base_hex, tint):
    r, g, b = hex_rgb(base_hex)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    t = tint or {}
    h = (h + float(t.get("hue_shift", 0)) / 360.0) % 1.0
    s = min(1.0, s * float(t.get("sat", 1.0)))
    v = min(1.0, v * float(t.get("val", 1.0)))
    return colorsys.hsv_to_rgb(h, s, v)


def posterise(arr):
    return np.round(np.clip(arr, 0, 1) * (LEVELS - 1)) / (LEVELS - 1)


def rng_for(name, seed):
    return np.random.default_rng(zlib.crc32(name.encode("utf-8")) + 7919 * seed)


def key_of(e):
    k = ("%s_%s" % (e.get("genus", ""), e.get("species", ""))).lower()
    k = re.sub(r"[^a-z0-9]+", "_", k).strip("_")
    return k or re.sub(r"[^a-z0-9]+", "_", e.get("name", "x").lower())


# ---------------------------------------------------------------- periodic noise (bark)

def _fade(t):
    return t * t * t * (t * (t * 6 - 15) + 10)


def pnoise(w, h, fx, fy, rng):
    fx, fy = max(1, int(fx)), max(1, int(fy))
    g = rng.normal(size=(fy, fx, 2))
    g /= np.linalg.norm(g, axis=2, keepdims=True) + 1e-9
    x = (np.arange(w) + 0.5) / w * fx
    y = (np.arange(h) + 0.5) / h * fy
    xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
    X, Y = np.meshgrid(x - xi, y - yi)
    XI, YI = np.meshgrid(xi, yi)
    u, v = _fade(X), _fade(Y)
    acc = {}
    for dy in (0, 1):
        for dx in (0, 1):
            gg = g[(YI + dy) % fy, (XI + dx) % fx]
            acc[(dx, dy)] = gg[..., 0] * (X - dx) + gg[..., 1] * (Y - dy)
    nx0 = acc[(0, 0)] * (1 - u) + acc[(1, 0)] * u
    nx1 = acc[(0, 1)] * (1 - u) + acc[(1, 1)] * u
    return (nx0 * (1 - v) + nx1 * v) * 1.4


def fbm(w, h, fx, fy, rng, octaves=3, gain=0.5):
    out, amp, tot = np.zeros((h, w)), 1.0, 0.0
    for o in range(octaves):
        out += amp * pnoise(w, h, fx << o, fy << o, rng)
        tot += amp
        amp *= gain
    return out / tot


def cellular(w, h, nx, ny, rng, jitter=0.6):
    """Periodic Voronoi: returns (F1, F2, cell id)."""
    px = (np.arange(nx)[None, :] + 0.5 + rng.uniform(-jitter, jitter, (ny, nx)) * 0.5) / nx
    py = (np.arange(ny)[:, None] + 0.5 + rng.uniform(-jitter, jitter, (ny, nx)) * 0.5) / ny
    X, Y = np.meshgrid((np.arange(w) + 0.5) / w, (np.arange(h) + 0.5) / h)
    f1 = np.full((h, w), 9.0); f2 = np.full((h, w), 9.0); cid = np.zeros((h, w), int)
    for j in range(ny):
        for i in range(nx):
            dx = np.abs(X - px[j, i]); dx = np.minimum(dx, 1 - dx)
            dy = np.abs(Y - py[j, i]); dy = np.minimum(dy, 1 - dy)
            d = np.sqrt((dx * nx) ** 2 + (dy * ny) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, j * nx + i, cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid


# ---------------------------------------------------------------- leaf outline

PROFILE = {  # (a, b): half-width ∝ t^a (1-t)^b, widest at a/(a+b)
    "ovate": (0.55, 1.1), "elliptic": (0.9, 0.9), "oblong": (0.35, 0.35), "obovate": (1.1, 0.55),
    "orbicular": (0.5, 0.5), "cordate": (0.35, 1.1), "sagittate": (0.4, 1.3), "hastate": (0.4, 1.2),
    "reniform": (0.4, 0.4), "peltate": (0.5, 0.5), "deltoid": (0.02, 1.0), "linear": (0.25, 0.25),
    "pinnate_lobed": (0.7, 0.9), "palmate_lobed": (0.6, 0.9),
}


def profile(outline, base, apex, t):
    a, b = PROFILE.get(outline, (0.9, 0.9))
    if outline in ("oblong", "linear"):
        w = np.minimum(1.0, np.minimum(t / (0.12 if outline == "oblong" else 0.06),
                                       (1 - t) / (0.12 if outline == "oblong" else 0.06)))
        w = np.clip(w, 0, 1) ** 0.6
    elif outline in ("orbicular", "peltate", "reniform"):
        w = np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1))
    elif outline == "deltoid":
        w = np.clip(1 - t, 0, 1) ** 0.9
    else:
        tt = np.clip(t, 1e-4, 1 - 1e-4)
        w = tt ** a * (1 - tt) ** b
        w = w / w.max()
    # base
    if base == "cuneate":
        w = w * np.clip(t / 0.22, 0, 1) ** 0.8
    elif base == "attenuate":
        w = w * np.clip(t / 0.4, 0, 1) ** 1.2
    elif base == "truncate":
        w = np.maximum(w, np.where(t < 0.08, 0.85 * w.max(), 0)) if outline != "deltoid" else w
        w = np.where(t < 0.05, 0.85, w) if outline in ("ovate", "elliptic", "oblong", "deltoid", "cordate") else w
    elif base in ("rounded", "cordate"):
        w = np.maximum(w, 0.55 * np.clip(1 - t / 0.25, 0, 1) * w.max() * (t > 0.01))
    # apex
    if apex in ("obtuse", "rounded", "emarginate"):
        w = np.maximum(w, 0.5 * np.clip((t - 0.7) / 0.3, 0, 1) ** 0.5 * np.sqrt(np.clip(1 - ((t - 0.7) / 0.3) ** 2, 0, 1)) * w.max())
    elif apex == "truncate":
        w = np.where(t > 0.9, w.max() * 0.7 * (t < 0.98), w)
    elif apex == "acuminate":
        w = np.where(t > 0.8, np.minimum(w, w.max() * (0.35 * (1 - (t - 0.8) / 0.2)) + 0.03), w)
    return np.clip(w, 0, 1)


def teeth(margin, t, n, rng):
    """Multiplicative margin modulation along t (0 base .. 1 apex)."""
    if margin == "serrate":
        ph = (t * n) % 1.0
        return 1.0 - 0.14 * (1.0 - ph)          # forward-pointing saw teeth
    if margin == "dentate":
        return 1.0 - 0.13 * np.abs(((t * n) % 1.0) * 2 - 1)
    if margin == "crenate":
        return 1.0 - 0.09 * (1 - np.abs(np.sin(np.pi * t * n)))
    if margin == "undulate":
        return 1.0 - 0.08 * (0.5 + 0.5 * np.sin(2 * np.pi * t * 2.5 + rng.uniform(0, 6)))
    if margin == "spinose":
        ph = (t * (n * 0.6)) % 1.0
        return 1.0 - 0.22 * (1 - np.clip((0.12 - np.abs(ph - 0.5)) / 0.12, 0, 1)) * 0.9 - 0.02
    return np.ones_like(t)


def blade_points(L, W, outline, base, apex, margin, lobes, rng, n_pts=72):
    """Polygon (list of (x, y)) for one blade: base at (0,0), apex at (0, L), x = across."""
    t = np.linspace(0.0, 1.0, n_pts)
    w = profile(outline, base, apex, t)
    if outline == "pinnate_lobed":
        k = max(2, int(lobes or 5))
        w = w * (0.55 + 0.45 * np.abs(np.cos(np.pi * k * t * 0.5 + 0.3)))
    teeth_n = int(np.clip(L / (W + 1e-6) * 3.0 + 5, 6, 16))
    tl = teeth(margin, t, teeth_n, rng)
    tr = teeth(margin, t + (0.5 / teeth_n if margin in ("serrate", "dentate") else 0.0), teeth_n, rng)
    half = 0.5 * W
    xl, xr = -w * tl * half, w * tr * half
    if base == "oblique":
        xr = xr * 0.85; yl_shift = 0.08 * L
    else:
        yl_shift = 0.0
    y = t * L
    left = list(zip(xl, y + yl_shift * (1 - t)))
    right = list(zip(xr[::-1], y[::-1]))
    pts = left + right
    # basal oddities
    if outline == "cordate" or base == "cordate":
        pts = [p for p in pts if not (abs(p[0]) < 0.12 * W and p[1] < 0.06 * L)]
        pts.insert(0, (0.0, 0.14 * L))          # the notch
    if outline == "sagittate":
        pts = [(-0.12 * W, 0.0), (-0.42 * W, -0.28 * L), (-0.06 * W, 0.02 * L)] + [p for p in pts if p[1] > 0.02 * L] + \
              [(0.06 * W, 0.02 * L), (0.42 * W, -0.28 * L), (0.12 * W, 0.0)]
    if outline == "hastate":
        pts = [(-0.1 * W, 0.0), (-0.75 * W, -0.16 * L), (-0.15 * W, 0.12 * L)] + [p for p in pts if p[1] > 0.12 * L] + \
              [(0.15 * W, 0.12 * L), (0.75 * W, -0.16 * L), (0.1 * W, 0.0)]
    if apex == "emarginate":
        pts = [p for p in pts if not (abs(p[0]) < 0.1 * W and p[1] > 0.94 * L)]
        i = len(pts) // 2
        pts.insert(i, (0.0, 0.9 * L))
    if apex == "mucronate":
        i = len(pts) // 2
        pts.insert(i, (0.0, L * 1.06))
    return pts


# ---------------------------------------------------------------- leaf card renderer

class Canvas:
    """Supersampled shade map (float, 1.0 = base colour) + alpha + vein/rim masks."""

    def __init__(self, size):
        self.n = size * SS
        self.alpha = Image.new("L", (self.n, self.n), 0)
        self.shade = Image.new("L", (self.n, self.n), 128)   # 128 = 1.0
        self.vein = Image.new("L", (self.n, self.n), 0)
        self.da, self.ds, self.dv = ImageDraw.Draw(self.alpha), ImageDraw.Draw(self.shade), ImageDraw.Draw(self.vein)

    def poly(self, pts, shade=128):
        self.da.polygon(pts, fill=255)
        self.ds.polygon(pts, fill=int(shade))

    def line(self, a, b, width, shade=128, vein=False):
        self.da.line([a, b], fill=255, width=width)
        (self.dv if vein else self.ds).line([a, b], fill=255 if vein else int(shade), width=width)

    def to_card(self, size, rgb, rgb_under=None, rim=True):
        rim = rim and not getattr(self, "thin", False)
        a = np.asarray(self.alpha.resize((size, size), Image.BOX)).astype(float) / 255.0
        s = np.asarray(self.shade.resize((size, size), Image.BOX)).astype(float) / 128.0
        v = np.asarray(self.vein.resize((size, size), Image.BOX)).astype(float) / 255.0
        mask = a > 0.5
        # shade only counts where there is leaf (BOX mixes in background 128 = neutral)
        s = np.where(mask, s, 1.0)
        s = s * (1.0 - 0.28 * np.clip(v * 1.6, 0, 1))          # veins darker
        if rim:
            er = np.asarray(self.alpha.resize((size, size), Image.BOX).filter(ImageFilter.MinFilter(3))).astype(float) / 255.0
            s = np.where(mask & (er < 0.5), s * 0.78, s)      # 1 px darker rim
        col = np.array(rgb)[None, None, :] * s[..., None]
        col = posterise(col)
        out = np.dstack([(col * 255).astype(np.uint8), (mask * 255).astype(np.uint8)])
        return Image.fromarray(out, "RGBA"), mask, s


def draw_blade(cv, cx, cy, L, W, ang, spec, rng, shade=128):
    """A blade with its base at (cx, cy), pointing along `ang` (radians; -pi/2 = up)."""
    pts = blade_points(L, W, spec["outline"], spec["base"], spec["apex"], spec["margin"], spec.get("lobes"), rng)
    ca, sa = math.cos(ang), math.sin(ang)
    P = [(cx + x * -sa + y * ca, cy + x * ca + y * sa) for x, y in pts]
    cv.poly(P, shade)
    # venation
    ven = spec.get("venation", "pinnate")
    tip = (cx + L * ca, cy + L * sa)
    wv = max(1, int(SS * 0.9))
    if ven in ("pinnate", "arcuate") and L > 10 * SS:
        cv.line((cx, cy), tip, wv, vein=True)
        n = int(np.clip(L / (7 * SS), 2, 7))
        for i in range(1, n + 1):
            t = i / (n + 1)
            bx, by = cx + L * t * ca, cy + L * t * sa
            reach = 0.42 * W * profile(spec["outline"], spec["base"], spec["apex"], np.array([t]))[0]
            for sgn in (-1, 1):
                if ven == "pinnate":
                    a2 = ang + sgn * math.radians(52)
                    ex, ey = bx + reach * math.cos(a2), by + reach * math.sin(a2)
                    cv.line((bx, by), (ex, ey), wv, vein=True)
                else:
                    a2 = ang + sgn * math.radians(35)
                    mx, my = cx + 0.45 * L * math.cos(a2) * 0.9 + 0.2 * L * ca, cy + 0.45 * L * math.sin(a2) * 0.9 + 0.2 * L * sa
                    cv.line((cx, cy), (mx, my), wv, vein=True); cv.line((mx, my), tip, wv, vein=True)
            if ven == "arcuate":
                break
    elif ven == "palmate":
        k = int(spec.get("lobes") or 5)
        for i in range(k):
            a2 = ang + math.radians(-70 + 140 * i / max(1, k - 1))
            ln = L * (0.95 if abs(a2 - ang) < 0.2 else 0.62)
            cv.line((cx, cy), (cx + ln * math.cos(a2), cy + ln * math.sin(a2)), wv, vein=True)
    elif ven == "parallel":
        k = int(np.clip(W / (3 * SS), 1, 5))
        for i in range(k):
            off = (i - (k - 1) / 2) * W * 0.28
            ox, oy = -sa * off, ca * off
            cv.line((cx + ox, cy + oy), (tip[0] + ox, tip[1] + oy), wv, vein=True)
    elif ven == "dichotomous":
        for i in range(-3, 4):
            a2 = ang + math.radians(22 * i)
            mx, my = cx + 0.5 * L * math.cos(a2), cy + 0.5 * L * math.sin(a2)
            cv.line((cx, cy), (mx, my), wv, vein=True)
            for s2 in (-1, 1):
                a3 = a2 + s2 * math.radians(9)
                cv.line((mx, my), (mx + 0.45 * L * math.cos(a3), my + 0.45 * L * math.sin(a3)), wv, vein=True)
    if spec["margin"] == "ciliate":
        for i in range(int(L / (2.5 * SS))):
            t = (i + 0.5) / (L / (2.5 * SS))
            reach = 0.5 * W * profile(spec["outline"], spec["base"], spec["apex"], np.array([t]))[0]
            for sgn in (-1, 1):
                bx, by = cx + L * t * ca + sgn * reach * -sa, cy + L * t * sa + sgn * reach * ca
                cv.line((bx, by), (bx + sgn * 1.2 * SS * -sa, by + sgn * 1.2 * SS * ca), max(1, SS // 2), shade=150)


def leaflet_spec(comp, parent):
    return {"outline": comp.get("leaflet_outline", "elliptic"), "base": "cuneate", "apex": "acute",
            "margin": comp.get("leaflet_margin", "entire"), "venation": "pinnate" if parent.get("venation") != "none" else "none",
            "lobes": None}


def draw_pinnate(cv, cx, cy, L, ang, n, lspec, laspect, rng, sub=None, shade=128):
    """A rachis from (cx,cy) of length L with n alternate leaflets (or sub-pinnae)."""
    ca, sa = math.cos(ang), math.sin(ang)
    cv.line((cx, cy), (cx + L * ca, cy + L * sa), max(1, int(SS * 0.8)), shade=100)
    n = max(3, int(n))
    step = L / (n / 2 + 0.5)
    lf_len = min(step * 1.7, L * 0.42)
    lf_w = lf_len / max(1.2, laspect)
    for i in range(n):
        t = (i // 2 + 0.6) * step / L
        if t > 0.98:
            break
        side = -1 if i % 2 == 0 else 1
        bx, by = cx + L * t * ca, cy + L * t * sa
        a2 = ang + side * math.radians(48)
        if sub == "pinnate":       # bipinnate: each pinna is itself pinnate with tiny leaflets
            draw_pinnate(cv, bx, by, lf_len * 1.15, a2, 7, lspec, 2.2, rng, sub=None, shade=shade)
        else:
            draw_blade(cv, bx, by, lf_len, lf_w, a2, lspec, rng, shade)
    # terminal leaflet
    if sub != "pinnate":
        draw_blade(cv, cx + L * 0.86 * ca, cy + L * 0.86 * sa, lf_len * 0.9, lf_w, ang, lspec, rng, shade)


def render_leaf(e, rng, size=LEAF_PX):
    """Returns Canvas or None (no leaf card)."""
    leaf = e.get("leaf") or {}
    t = leaf.get("type", "simple")
    if t == "none":
        return None
    cv = Canvas(size)
    n = cv.n
    cx, cy = n / 2, n * 0.95
    up = -math.pi / 2
    tex = leaf.get("texture", "matte")
    if t in ("simple", "strap"):
        outline = leaf.get("outline", "ovate")
        asp = float(leaf.get("aspect", 2.0))
        asp = max(0.6, min(asp, 30.0))
        L = n * 0.86
        W = L / asp
        if W > n * 0.9:
            W = n * 0.9; L = W * asp
        if W < 3.5 * SS:
            cv.thin = True
        spec = {"outline": outline, "base": leaf.get("base", "cuneate"), "apex": leaf.get("apex", "acute"),
                "margin": leaf.get("margin", "entire"), "venation": leaf.get("venation", "pinnate"), "lobes": leaf.get("lobes")}
        if outline == "palmate_lobed":
            k = int(leaf.get("lobes") or 5)
            lobe = dict(spec, outline="ovate", margin=("serrate" if spec["margin"] in ("serrate", "dentate") else "entire"), venation="none")
            for i in range(k):
                a2 = up + math.radians(-75 + 150 * i / max(1, k - 1))
                ln = L * (1.0 if abs(a2 - up) < 0.25 else (0.8 if abs(a2 - up) < 0.9 else 0.6))
                draw_blade(cv, cx, cy - 0.06 * n, ln * 0.92, W * 0.42, a2, lobe, rng)
            # palm veins
            for i in range(k):
                a2 = up + math.radians(-75 + 150 * i / max(1, k - 1))
                ln = L * (1.0 if abs(a2 - up) < 0.25 else (0.8 if abs(a2 - up) < 0.9 else 0.6)) * 0.85
                cv.line((cx, cy - 0.06 * n), (cx + ln * math.cos(a2), cy - 0.06 * n + ln * math.sin(a2)), SS, vein=True)
        else:
            base_y = cy if outline not in ("sagittate", "hastate") else cy - 0.25 * L
            if outline in ("peltate", "reniform", "orbicular"):
                base_y = cy - 0.02 * n
            draw_blade(cv, cx, base_y, L * (0.75 if outline in ("sagittate", "hastate") else 1.0), W, up, spec, rng)
            if outline == "peltate":
                cv.da.ellipse([cx - SS, base_y - 0.5 * L - SS, cx + SS, base_y - 0.5 * L + SS], fill=255)
                cv.dv.ellipse([cx - 1.5 * SS, base_y - 0.5 * L - 1.5 * SS, cx + 1.5 * SS, base_y - 0.5 * L + 1.5 * SS], fill=255)
    elif t in ("compound", "frond"):
        comp = leaf.get("compound") or {"form": "pinnate", "leaflets": [7, 11], "leaflet_outline": "elliptic", "leaflet_aspect": 3.0, "leaflet_margin": "entire"}
        form = comp.get("form", "pinnate")
        lf = comp.get("leaflets", [7, 11])
        nl = int(round((lf[0] + lf[1]) / 2)) if isinstance(lf, list) else int(lf)
        lspec = leaflet_spec(comp, leaf)
        lasp = float(comp.get("leaflet_aspect", 3.0))
        L = n * 0.86
        if form in ("pinnate",):
            draw_pinnate(cv, cx, cy, L, up, min(nl, 15), lspec, lasp, rng)
        elif form in ("bipinnate", "tripinnate", "dissected"):
            lspec2 = dict(lspec, margin="entire")
            draw_pinnate(cv, cx, cy, L, up, min(max(nl // 3, 5), 9), lspec2, 4.0 if form == "bipinnate" else 6.0, rng, sub="pinnate")
        elif form in ("palmate", "pedate"):
            k = int(np.clip(nl, 3, 11))
            lw = L * 0.9 / lasp
            for i in range(k):
                a2 = up + math.radians(-80 + 160 * i / max(1, k - 1))
                ln = L * 0.9 * (1.0 - 0.45 * abs(a2 - up) / 1.4)
                draw_blade(cv, cx, cy, ln, min(lw, ln / 1.8), a2, lspec, rng)
        elif form == "trifoliate":
            lw = L * 0.6 / max(1.2, lasp)
            for i, a2 in enumerate((up - math.radians(50), up, up + math.radians(50))):
                draw_blade(cv, cx, cy - (0.28 * L if i == 1 else 0.15 * L), L * (0.66 if i == 1 else 0.55), lw, a2, lspec, rng)
            cv.line((cx, cy), (cx, cy - 0.28 * L), max(1, int(SS * 0.8)), shade=100)
        else:
            draw_pinnate(cv, cx, cy, L, up, min(nl, 15), lspec, lasp, rng)
    elif t == "needle":
        cv.thin = True
        k = int(leaf.get("fascicle") or 0)
        arr = leaf.get("arrangement", "fascicled")
        L = n * 0.9
        wpx = max(SS, int(SS * 1.9))
        if arr == "fascicled" and k >= 1:
            k = max(1, min(k, 8))
            for i in range(k):
                a2 = up + math.radians(-14 + 28 * (i / max(1, k - 1)) if k > 1 else 0) + rng.uniform(-0.03, 0.03)
                cv.line((cx, cy), (cx + L * math.cos(a2), cy + L * math.sin(a2)), wpx, shade=128 + int(rng.uniform(-14, 14)))
            cv.da.ellipse([cx - 2.2 * SS, cy - 2 * SS, cx + 2.2 * SS, cy + 1.5 * SS], fill=255)
            cv.ds.ellipse([cx - 2.2 * SS, cy - 2 * SS, cx + 2.2 * SS, cy + 1.5 * SS], fill=80)
        else:   # spiral / whorled / distichous: a twig with needles both sides (spruce, fir, yew, casuarina)
            cv.line((cx, cy), (cx, cy - L), max(SS, int(SS * 1.2)), shade=85)
            nl = 16
            nlen = L * 0.36
            for i in range(nl):
                yy = cy - L * (i + 0.5) / nl
                for side in (-1, 1):
                    a2 = up + side * math.radians(62 if arr != "distichous" else 80)
                    cv.line((cx, yy), (cx + nlen * math.cos(a2), yy + nlen * math.sin(a2)), wpx, shade=128 + int(rng.uniform(-14, 14)))
    elif t == "scale":
        cv.thin = True
        L = n * 0.9
        cv.line((cx, cy), (cx, cy - L), max(SS, int(SS * 1.4)), shade=95)
        for br in range(5):
            yy = cy - L * (br + 1) / 6.0
            for side in (-1, 1):
                a2 = up + side * math.radians(55)
                bl = L * 0.32
                cv.line((cx, yy), (cx + bl * math.cos(a2), yy + bl * math.sin(a2)), max(SS, int(SS * 1.2)), shade=100)
                for j in range(4):
                    tt = (j + 0.5) / 4
                    px, py = cx + bl * tt * math.cos(a2), yy + bl * tt * math.sin(a2)
                    r = SS * 1.3
                    cv.da.ellipse([px - r, py - r, px + r, py + r], fill=255)
                    cv.ds.ellipse([px - r, py - r, px + r, py + r], fill=118 + (j % 2) * 22)
        for j in range(6):
            py = cy - L * (j + 0.5) / 6
            r = SS * 1.4
            cv.da.ellipse([cx - r, py - r, cx + r, py + r], fill=255); cv.ds.ellipse([cx - r, py - r, cx + r, py + r], fill=118 + (j % 2) * 22)
    else:
        return None
    # surface texture (shade-map pass)
    s = np.asarray(cv.shade).astype(float)
    a = np.asarray(cv.alpha) > 0
    h, w = s.shape
    ys, xs = np.mgrid[0:h, 0:w]
    if tex == "glossy":
        band = np.clip(1 - np.abs((xs - w * 0.42) / (w * 0.16)), 0, 1) * np.clip(1 - np.abs((ys - h * 0.45) / (h * 0.35)), 0, 1)
        s = s * (1 + 0.22 * band)
    elif tex == "velvety":
        s = s * 0.92 * (1 - 0.12 * (rng.random((h, w)) < 0.10))
    elif tex == "waxy_glaucous":
        s = s * (1 + 0.10 * (rng.random((h, w)) < 0.12))
    elif tex == "hairy_tomentose":
        s = s * (1 + 0.16 * (rng.random((h, w)) < 0.14))
    elif tex == "succulent":
        rad = 1 - np.sqrt(((xs - w / 2) / (w / 2)) ** 2 + ((ys - h / 2) / (h / 2)) ** 2)
        s = s * (1 + 0.16 * np.clip(rad, 0, 1))
    else:
        s = s * (1 + 0.05 * (rng.random((h, w)) < 0.10) - 0.05 * (rng.random((h, w)) < 0.10))
    cv.shade = Image.fromarray(np.clip(np.where(a, s, 128), 0, 255).astype(np.uint8))
    return cv


PALETTE_GREEN = "#3E8232"   # the schema's palette green (albedo); tint is relative to this


def leaf_colour(e):
    """PLANT_SCHEMA §3: tint is relative to the palette green. Entries whose own `color` is not
    a green (straw grasses, red sphagnum, brown kelp, red sundew) keep that colour and take only
    the tint's sat/val."""
    tint = dict(e.get("tint") or {})
    r, g, b = hex_rgb(e.get("color", PALETTE_GREEN))
    h = colorsys.rgb_to_hsv(r, g, b)[0] * 360
    if 70 <= h <= 175:
        rgb = tint_rgb(PALETTE_GREEN, tint)
    else:
        tint["hue_shift"] = 0
        rgb = tint_rgb(e.get("color", PALETTE_GREEN), tint)
    if tint.get("texture") == "waxy_glaucous" or (e.get("leaf") or {}).get("texture") == "waxy_glaucous":
        rgb = tuple(0.68 * c + 0.32 * g for c, g in zip(rgb, (0.62, 0.72, 0.78)))
    return rgb


# ---------------------------------------------------------------- foliage mass tile

def render_mass(e, card, rng, size=MASS_PX):
    """Tileable scatter of the species' leaf card. card: RGBA PIL at LEAF_PX (or None)."""
    leaf = e.get("leaf") or {}
    t = leaf.get("type", "simple")
    n4 = size * SS
    base = Image.new("RGBA", (n4, n4), (0, 0, 0, 0))
    if card is None:
        return None
    sz = leaf.get("size_cm", [5, 10])
    mean_cm = (sz[0] + sz[1]) / 2 if isinstance(sz, list) else float(sz)
    # leaf pixel size in the mass: small leaves many, big leaves few
    if t in ("needle", "scale"):
        px, count = int(n4 * 0.55), 14
    elif t == "strap":
        px, count = int(n4 * 0.9), 10
    else:
        px = int(np.clip(n4 * (0.28 + 0.22 * math.log10(max(mean_cm, 0.5) + 1)), n4 * 0.28, n4 * 0.62))
        count = int(np.clip(26 - px / n4 * 26, 8, 18))
    card4 = card.resize((px, px), Image.NEAREST)
    under = float((e.get("tint") or {}).get("underside", 0.15))
    for i in range(count):
        ang = rng.uniform(0, 360) if t not in ("strap",) else rng.uniform(-35, 35)
        rot = card4.rotate(ang, expand=True, resample=Image.NEAREST)
        arr = np.asarray(rot).astype(float)
        jitter = 1 + rng.uniform(-0.14, 0.14) + (under * 0.5 if rng.random() < 0.25 else 0.0)
        arr[..., :3] = np.clip(arr[..., :3] * jitter, 0, 255)
        rot = Image.fromarray(arr.astype(np.uint8), "RGBA")
        x, y = int(rng.integers(0, n4)), int(rng.integers(0, n4))
        for dx in (-n4, 0, n4):
            for dy in (-n4, 0, n4):
                base.paste(rot, (x + dx - rot.width // 2, y + dy - rot.height // 2), rot)
    a = np.asarray(base.resize((size, size), Image.BOX)).astype(float)
    mask = a[..., 3] > 110
    rgb = posterise(a[..., :3] / 255.0)
    return Image.fromarray(np.dstack([(rgb * 255).astype(np.uint8), (mask * 255).astype(np.uint8)]), "RGBA")


# ---------------------------------------------------------------- litter tile (design §AI)

def render_litter(e, cv, mask, shade, rng, size=MASS_PX):
    """Tileable flat scatter of the species' fallen leaves in the autumn (or dried) colour:
    stage 0 of data/litter.json; later stages are the shared colour transform in the shader."""
    tint = e.get("tint") or {}
    col = hex_rgb(tint["autumn"]) if tint.get("autumn") else tuple(0.55 * c + 0.45 * b for c, b in zip(leaf_colour(e), (0.55, 0.42, 0.22)))
    card = Image.fromarray(np.dstack([(posterise(np.array(col)[None, None, :] * shade[..., None]) * 255).astype(np.uint8),
                                      (mask * 255).astype(np.uint8)]), "RGBA")
    n4 = size * SS
    base = Image.new("RGBA", (n4, n4), (0, 0, 0, 0))
    leaf = e.get("leaf") or {}
    t = leaf.get("type", "simple")
    px = int(n4 * (0.5 if t in ("needle", "scale") else 0.42))
    c4 = card.resize((px, px), Image.NEAREST)
    for i in range(22):
        rot = c4.rotate(rng.uniform(0, 360), expand=True, resample=Image.NEAREST)
        arr = np.asarray(rot).astype(float)
        arr[..., :3] = np.clip(arr[..., :3] * (1 + rng.uniform(-0.22, 0.12)), 0, 255)     # some already browning
        if rng.random() < 0.3:
            arr[..., :3] = arr[..., :3] * 0.8 + np.array([90, 60, 30]) * 0.2
        rot = Image.fromarray(arr.astype(np.uint8), "RGBA")
        x, y = int(rng.integers(0, n4)), int(rng.integers(0, n4))
        for dx in (-n4, 0, n4):
            for dy in (-n4, 0, n4):
                base.paste(rot, (x + dx - rot.width // 2, y + dy - rot.height // 2), rot)
    a = np.asarray(base.resize((size, size), Image.BOX)).astype(float)
    rgb = posterise(a[..., :3] / 255.0)
    alpha = a[..., 3] > 90
    # ground shows through the gaps as dark soil
    soil = np.array([0.16, 0.12, 0.08])
    rgb = np.where(alpha[..., None], rgb, soil[None, None, :])
    return Image.fromarray((rgb * 255).astype(np.uint8), "RGB")


def skeleton_mask(rng, size=MASS_PX):
    """Shared holes mask for the skeleton stage: 1 = hole."""
    f = fbm(size, size, 6, 6, rng, 2)
    return (f > 0.28).astype(np.uint8) * 255


def litter_stage(img, stage, holes_mask):
    """Preview of data/litter.json stage transform (what the shader does)."""
    a = np.asarray(img).astype(float) / 255.0
    to = np.array(hex_rgb(stage["color_lerp"]["to"]))
    a = a * (1 - stage["color_lerp"]["amount"]) + to[None, None, :] * stage["color_lerp"]["amount"]
    h, w, _ = a.shape
    out = np.zeros_like(a)
    for y in range(h):
        for x in range(w):
            hh, ss, vv = colorsys.rgb_to_hsv(*a[y, x])
            out[y, x] = colorsys.hsv_to_rgb(hh, min(1, ss * stage["sat"]), min(1, vv * stage["val"]))
    hole = (np.asarray(holes_mask) > 0) & (np.random.default_rng(1).random((h, w)) < stage["holes"] * 2)
    soil = np.array([0.16, 0.12, 0.08])
    out = np.where(hole[..., None], soil[None, None, :], out)
    return Image.fromarray((posterise(out) * 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- bark tile

def stamp_disc(v, cx, cy, r, lit, shade):
    h, w = v.shape
    ys, xs = np.mgrid[-r - 1:r + 2, -r - 1:r + 2]
    d = np.sqrt(xs ** 2 + ys ** 2)
    for oy, ox, dd in zip(ys.ravel(), xs.ravel(), d.ravel()):
        if dd <= r + 0.5:
            v[(cy + oy) % h, (cx + ox) % w] = lit if (ox + oy) < 0 else shade


def render_bark(bark, rng, size=BARK_PX):
    pat = bark.get("pattern", "smooth")
    if pat == "none":
        return None
    n = size
    depth = float(bark.get("depth", 0.4))
    sc = float(bark.get("scale_cm", 4))
    c1 = np.array(hex_rgb(bark.get("color", "#6E6458")))
    c2 = np.array(hex_rgb(bark.get("color_2", "#4A3F36")))
    orient = bark.get("orientation", "none")
    count = int(np.clip(round(32.0 / max(sc, 0.2)), 2, 12))       # features across a ~40 cm tile
    shade = np.ones((n, n))                                          # brightness map
    mix = np.zeros((n, n))                                           # 0 = colour, 1 = colour_2
    base_noise = fbm(n, n, 4, 4, rng, 3)
    shade += 0.06 * base_noise
    if pat == "smooth":
        shade += 0.05 * depth * fbm(n, n, 2, 2, rng, 2)
        mix += 0.15 * depth * (fbm(n, n, 3, 3, rng, 2) > 0.25)
    elif pat in ("fissured", "furrowed"):
        deep = 0.35 + 0.6 * depth if pat == "furrowed" else 0.2 + 0.4 * depth
        wid = 3 if pat == "furrowed" else 1
        fams = {"vertical": [(0.0,)], "horizontal": [(math.pi / 2,)], "diamond": [(0.5,), (-0.5,)], "none": [(0.0,)]}[orient if orient != "none" else "vertical"]
        for (ang,) in fams:
            ys, xs = np.mgrid[0:n, 0:n]
            u = xs * math.cos(ang) + ys * math.sin(ang)
            wob = fbm(n, n, 2, 6, rng, 2) * (2.5 + 2 * depth)
            ph = ((u + wob) * count / n) % 1.0
            crack = (ph < wid / (n / count)).astype(float)
            crack = np.maximum(crack, np.roll(crack, 1, 1) * 0.5)
            shade -= deep * crack
            mix = np.maximum(mix, crack)
            if pat == "furrowed":                                    # lit ridge beside the valley
                ridge = np.roll(crack, -wid - 1, 1)
                shade += 0.3 * depth * ridge
                shade -= 0.12 * depth * np.roll(crack, 2, 1)
    elif pat == "plated":
        nx = max(2, count // 2); ny = nx * (2 if orient == "vertical" else 1)
        f1, f2, cid = cellular(n, n, nx, ny, rng)
        crack = np.clip(1 - (f2 - f1) / (0.09 + 0.04 * (1 - depth)), 0, 1)
        tone = (rng.random(nx * ny + 1) - 0.5) * 0.28 * depth
        shade += tone[cid] - (0.3 + 0.5 * depth) * crack
        mix = np.maximum(mix, crack)
        shade += 0.06 * fbm(n, n, 8, 8, rng, 2)
    elif pat == "scaly":
        rows = max(4, count)
        bh = n / rows
        for r in range(rows):
            y0 = int(r * bh)
            off = (r % 2) * bh * 0.6
            cols = max(4, int(count * 1.2))
            bw = n / cols
            for k in range(cols):
                x0 = int((off + k * bw) % n)
                xs_ = [(x0 + i) % n for i in range(max(2, int(bw) - 1))]
                tone = 1 + rng.uniform(-0.12, 0.12) * (0.5 + depth)
                shade[y0:int(y0 + bh), xs_] *= tone
                shade[y0, xs_] *= 1 + 0.18 * depth                  # lit top edge
                shade[int(y0 + bh) - 1 if int(y0 + bh) - 1 < n else n - 1, xs_] *= 1 - 0.35 * depth
                shade[y0:int(y0 + bh), x0] *= 1 - 0.3 * depth
        mix += 0.2 * (fbm(n, n, 6, 6, rng, 2) > 0.3)
    elif pat == "flaky":
        f = fbm(n, n, 3, 5 if orient == "vertical" else 3, rng, 3)
        patch = (f > 0.08).astype(float)
        edge = patch - np.roll(patch, 1, 0)
        mix = np.maximum(mix, patch)
        shade += 0.22 * depth * (edge > 0) - 0.18 * depth * (edge < 0)
        shade += 0.05 * fbm(n, n, 10, 10, rng, 2)
    elif pat == "papery":
        ys = np.arange(n)[:, None]
        lines = ((ys + fbm(n, n, 3, 1, rng, 2) * 3) % max(3, int(n / count)) < 1).astype(float)
        shade -= (0.25 + 0.3 * depth) * lines
        mix = np.maximum(mix, lines * 0.8)
        curl = (fbm(n, n, 6, 1, rng, 2) > 0.35).astype(float) * (rng.random((n, n)) < 0.5)
        shade += 0.15 * curl
    elif pat == "stringy":
        f = fbm(n, n, 14, 1, rng, 3, 0.6)
        shade += (0.25 + 0.3 * depth) * f
        mix = np.clip(0.5 + 0.8 * f, 0, 1)
        strands = (fbm(n, n, 8, 1, rng, 2) > 0.45).astype(float)
        shade -= 0.25 * depth * strands
    elif pat == "ringed":
        rings = max(2, min(count, 8))
        ys = np.arange(n)[:, None]
        wob = fbm(n, n, 2, 1, rng, 2) * 1.5
        ph = ((ys + wob) * rings / n) % 1.0
        ring = (ph < 1.5 * rings / n).astype(float)
        above = np.roll(ring, -1, 0)
        shade -= (0.3 + 0.4 * depth) * ring
        shade += 0.15 * depth * above
        mix = np.maximum(mix, ring)
        shade += 0.08 * fbm(n, n, 10, 2, rng, 2)                     # fibre between rings
    elif pat == "spiny":
        ribs = int(np.clip(round(30.0 / max(sc, 0.5)), 3, 14))
        xs = np.arange(n)[None, :]
        rib = np.cos(2 * np.pi * (xs * ribs / n))
        shade += 0.4 * depth * rib
        crest = ((xs * ribs / n) % 1.0) < (1.0 / (n / ribs))
        for x in np.where(crest[0])[0]:
            for y in range(int(rng.integers(0, 8)), n, 8):
                stamp_disc(shade, int(x), int(y), 1, 1.1, 0.7)
                for k in range(3):
                    a = rng.uniform(0, 2 * np.pi); ln = 2 + int(rng.integers(0, 3))
                    for s_ in range(1, ln + 1):
                        px, py = int(x + s_ * np.cos(a)) % n, int(y + s_ * np.sin(a)) % n
                        mix[py, px] = 1.0; shade[py, px] = max(shade[py, px], 1.05)
    elif pat == "warty":
        for _ in range(int(20 + 40 * depth)):
            stamp_disc(shade, int(rng.integers(n)), int(rng.integers(n)), int(rng.integers(1, 3)), 1.15, 0.75)
        mix += 0.1 * (fbm(n, n, 4, 4, rng, 2) > 0.3)
    elif pat == "green_stem":
        shade += 0.10 * fbm(n, n, 6, 1, rng, 2)                      # faint striations
        blotch = fbm(n, n, 3, 6, rng, 3)
        cover = np.clip(depth, 0, 1)
        mix = np.maximum(mix, (blotch > (0.5 - 0.6 * cover)).astype(float))
        node = (np.arange(n)[:, None] % 24 < 2).astype(float) * np.ones((1, n))
        shade -= 0.15 * node
    # lenticels
    lent = bark.get("lenticels", "none")
    if lent == "dots":
        for _ in range(int(25 + 30 * depth)):
            x, y = int(rng.integers(n)), int(rng.integers(n))
            mix[y, x] = 1.0; shade[y, x] *= 1.12
    elif lent == "horizontal_bands":
        for _ in range(int(14 + 12 * depth)):
            x, y = int(rng.integers(n)), int(rng.integers(n)); ln = int(rng.integers(3, 7))
            for i in range(ln):
                mix[y, (x + i) % n] = 1.0; shade[y, (x + i) % n] *= 0.8
    col = c1[None, None, :] * (1 - mix[..., None]) + c2[None, None, :] * mix[..., None]
    col = col * np.clip(shade, 0.25, 1.6)[..., None]
    col = posterise(col)
    return Image.fromarray((col * 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- Amorphophallus petiole

def render_petiole(e, rng, w=PET_W, h=PET_H):
    pet = ((e.get("aroid") or {}).get("petiole")) or {}
    pattern = pet.get("pattern", "mottled")
    base = np.array(hex_rgb(pet.get("base") or e.get("accent") or "#6F8F5A"))
    spot = np.array(hex_rgb(pet.get("spots") or "#D8DFC4"))
    ys = np.arange(h)[:, None] / h              # 0 top .. 1 bottom
    big = fbm(w, h, 2, 6, rng, 3)                # large elongate blotches
    fine = fbm(w, h, 6, 18, rng, 2)
    confl = np.clip((ys - 0.82) / 0.18, 0, 1)   # confluent at the base (lowest 10-20 %)
    if pattern == "plain":
        mix = 0.15 * (big > 0.4)
    elif pattern == "spotted":
        mix = (fine > 0.32).astype(float) * 0.9
    elif pattern == "streaked":
        mix = (fbm(w, h, 1, 10, rng, 3) > 0.12).astype(float)
    elif pattern == "lichen":
        isl = (big + 0.3 * fine) > 0.18
        rim = isl & ~(np.roll(isl, 1, 0) & np.roll(isl, -1, 0) & np.roll(isl, 1, 1) & np.roll(isl, -1, 1))
        mix = isl.astype(float) * 0.85 + rim * 0.15
        base, spot = base * 0.55, spot            # pale islands on a dark ground
    else:  # mottled / warty
        mix = np.clip((big + 0.25 * fine + 0.45 * confl) > 0.12, 0, 1).astype(float)
    dots = (rng.random((h, w)) < 0.05).astype(float)                 # fine scatter, opposite value
    col = base[None, None, :] * (1 - mix[..., None]) + spot[None, None, :] * mix[..., None]
    col = col * (1 - 0.35 * dots[..., None] * (mix[..., None] > 0.5)) * (1 + 0.35 * dots[..., None] * (mix[..., None] <= 0.5))
    xs = np.arange(w)[None, :] / w
    col = col * (0.82 + 0.28 * np.sin(np.pi * xs))[..., None]      # cylinder shading
    if pattern == "warty":
        for _ in range(60):
            stamp_disc(col[..., 1], int(rng.integers(w)), int(rng.integers(h)), 1, col[..., 1].mean() * 1.2, col[..., 1].mean() * 0.7)
    col = posterise(col)
    return Image.fromarray((col * 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- driver

def load_entries():
    seen = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "plants", "*.json")) + sorted(glob.glob(os.path.join(ROOT, "data", "biomes", "*.json")))):
        d = json.load(open(f, encoding="utf-8"))
        p = d.get("plants", [])
        es = [e for l in p.values() for e in (l or [])] if isinstance(p, dict) else list(p or [])
        for e in es:
            if not isinstance(e, dict) or "name" not in e:
                continue
            nm = e["name"]
            if nm not in seen or (not isinstance(seen[nm].get("leaf"), dict) and isinstance(e.get("leaf"), dict)):
                seen[nm] = e
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None, help="genus (or name substring) filter")
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    if not a.only:                                   # a full run replaces the set (no stale tiles)
        for fn in os.listdir(OUT):
            if fn.endswith(".png"):
                os.remove(os.path.join(OUT, fn))
    entries = load_entries()
    atlas = {"_help": {"about": "Per-species tiles rendered from the taxonomic data (tools/look/make_plant_tiles.py, design §AH). "
                                "Files are shared where two species render identically. Tiles carry the species colour: the shader "
                                "multiplies by white x genes jitter, not by the species colour again.",
                       "sizes": {"leaf": LEAF_PX, "leaves": MASS_PX, "litter": MASS_PX, "bark": BARK_PX, "petiole": [PET_W, PET_H]},
                       "litter": "<key>_litter.png is the fallen-leaf scatter at stage 0 of data/litter.json; later stages apply that file's colour transform + litter_holes.png",
                       "bark_tile_m": BARK_TILE_M, "filter": "nearest, no mipmaps beyond 2"},
             "species": {}}
    hashes = {}
    made = 0
    previews = []

    def save(img, key, kind):
        nonlocal made
        if img is None:
            return None
        raw = img.tobytes()
        hsh = hashlib.md5(raw).hexdigest()
        if hsh in hashes:
            return hashes[hsh]
        fn = "%s_%s.png" % (key, kind)
        img.save(os.path.join(OUT, fn), optimize=True)
        hashes[hsh] = fn
        made += 1
        return fn

    for name, e in sorted(entries.items()):
        if a.only and a.only.lower() not in name.lower() and a.only.lower() != str(e.get("genus", "")).lower():
            continue
        key = key_of(e)
        rng = rng_for(name, a.seed)
        rec = {"key": key, "genus": e.get("genus"), "leaf_type": (e.get("leaf") or {}).get("type"),
               "bark_pattern": (e.get("bark") or {}).get("pattern")}
        cv = render_leaf(e, rng)
        card = None
        if cv is not None:
            rgb = leaf_colour(e)
            card, mask, s = cv.to_card(LEAF_PX, rgb)
            rec["leaf"] = save(card, key, "leaf")
            rec["leaf_color"] = "#%02X%02X%02X" % tuple(int(c * 255) for c in rgb)
            tint = e.get("tint") or {}
            if tint.get("autumn") and tint.get("drop", True):
                ac = hex_rgb(tint["autumn"])
                col = posterise(np.array(ac)[None, None, :] * s[..., None])
                aut = Image.fromarray(np.dstack([(col * 255).astype(np.uint8), (mask * 255).astype(np.uint8)]), "RGBA")
                rec["leaf_autumn"] = save(aut, key, "leaf_autumn")
            mass = render_mass(e, card, rng_for(name + "/mass", a.seed))
            rec["leaves"] = save(mass, key, "leaves")
            rec["litter"] = save(render_litter(e, cv, mask, s, rng_for(name + "/litter", a.seed)), key, "litter")
        bark = e.get("bark") or {}
        bimg = render_bark(bark, rng_for(name + "/bark", a.seed))
        rec["bark"] = save(bimg, key, "bark")
        if bimg is not None:
            rec["bark_tile_m"] = BARK_TILE_M
        if e.get("aroid"):
            rec["petiole"] = save(render_petiole(e, rng_for(name + "/petiole", a.seed)), key, "petiole")
        atlas["species"][name] = rec
        if a.preview:
            previews.append((name, rec))
    holes = Image.fromarray(skeleton_mask(rng_for("holes", a.seed)), "L")
    holes.save(os.path.join(OUT, "litter_holes.png"))
    json.dump(atlas, open(os.path.join(OUT, "atlas_species.json"), "w"), indent=1)
    if a.preview:
        stages = json.load(open(os.path.join(ROOT, "data", "litter.json")))["stages"]
        rows = [n for n in ("Bur oak", "Maple", "Bog birch", "Ginkgo", "Black spruce", "African baobab") if n in atlas["species"] and atlas["species"][n].get("litter")]
        S = 96
        sheet = Image.new("RGB", (230 + (S + 4) * len(stages), 20 + (S + 6) * len(rows)), (16, 16, 24))
        d = ImageDraw.Draw(sheet)
        for j, st in enumerate(stages):
            d.text((200 + j * (S + 4), 4), "%d %s (%dd@15C)" % (j, st["name"], st["days_at_reference"]), fill=(220, 220, 220))
        for i, n in enumerate(rows):
            y = 20 + i * (S + 6); d.text((4, y + 40), n, fill=(230, 230, 230))
            im = Image.open(os.path.join(OUT, atlas["species"][n]["litter"])).convert("RGB")
            for j, st in enumerate(stages):
                st_img = litter_stage(im, st, holes)
                t2 = Image.new("RGB", (im.width * 2, im.height * 2))
                for ty in range(2):
                    for tx in range(2):
                        t2.paste(st_img, (tx * im.width, ty * im.height))
                sheet.paste(t2.resize((S, S), Image.NEAREST), (200 + j * (S + 4), y))
        sheet.save(os.path.join(ROOT, "docs", "references", "batch3", "litter_stages_preview.png"))
    print("%d species -> %d unique tiles in %s" % (len(atlas["species"]), made, os.path.relpath(OUT, ROOT)))

    if a.preview:
        # contact sheet: one row per species (leaf, autumn, leaves x3 tiled, bark x2 tiled, petiole)
        want = [n for n, r in previews]
        if not a.only:
            picks = ["Amorphophallus titanum", "Amorphophallus konjac", "Cannabis", "Trichocereus pachanoi", "Quercus", "Betula", "Acer",
                     "Pinus ponderosa", "Picea", "Sequoia", "Cocos", "Adansonia", "Rhizophora", "Eucalyptus", "Cyathea", "Ginkgo",
                     "Musa", "Salix", "Ilex", "Platanus", "Ficus", "Nepenthes", "Agave", "Typha", "Sphagnum", "Fagus", "Larix", "Juniperus"]
            want = []
            for p in picks:
                for n in sorted(atlas["species"]):
                    if n.lower().startswith(p.lower()) or (atlas["species"][n].get("genus") or "").lower() == p.lower():
                        want.append(n); break
        want = want[:36]
        S = 96
        sheet = Image.new("RGB", (S * 7 + 260, (S + 6) * len(want) + 10), (16, 16, 24))
        d = ImageDraw.Draw(sheet)
        for i, n in enumerate(want):
            r = atlas["species"][n]; y = 5 + i * (S + 6)
            d.text((4, y + 4), n[:34], fill=(230, 230, 230)); d.text((4, y + 18), "%s / %s" % (r.get("leaf_type"), r.get("bark_pattern")), fill=(150, 150, 170))
            x = 260
            for kind, tile in (("leaf", 1), ("leaf_autumn", 1), ("leaves", 3), ("bark", 2), ("petiole", 1)):
                fn = r.get(kind)
                if fn:
                    im = Image.open(os.path.join(OUT, fn)).convert("RGBA")
                    if tile > 1:
                        t2 = Image.new("RGBA", (im.width * tile, im.height * tile))
                        for ty in range(tile):
                            for tx in range(tile):
                                t2.paste(im, (tx * im.width, ty * im.height))
                        im = t2
                    if kind == "petiole":
                        im = im.resize((S // 4, S), Image.NEAREST)
                    else:
                        im = im.resize((S, S), Image.NEAREST)
                    bg = Image.new("RGB", im.size, (34, 30, 44)); bg.paste(im, (0, 0), im)
                    sheet.paste(bg, (x, y))
                x += S + 4 if kind != "petiole" else S // 4 + 4
        p = os.path.join(ROOT, "docs", "references", "batch3", "species_tiles_preview.png")
        sheet.save(p); print("preview:", os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
