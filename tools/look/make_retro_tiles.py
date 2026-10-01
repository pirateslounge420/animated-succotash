#!/usr/bin/env python3
"""Generate the §AG retro detail tiles (design RECONCILIATION §AG, data/look.json retro).

Writes assets/textures/retro/<name>.png — tiny, tileable, meant to be drawn
NEAREST-filtered and repeated every retro.tile_m metres:

  grass, dirt, sand, stone, bark (retro.tile_px: 64 each) and leaves (32),
  water 64, leaf_card 32 (RGBA cutout), and cloud_pano 512x128.

Every ground/bark/leaf tile follows the LookTextures convention: a greyscale
MODULATION centred on mid-grey (0.5 = no change), stored in RGB with alpha 255,
so the shaders can multiply it by the vertex colour exactly as they do with
the painted 256 px textures today. Since the look pass (1 Oct) the ground,
stone, bark and leaf tiles are drawn at ~16 texels a metre (tile_px /
tile_m) with their own hard darks and flecks (DARK..FLECK below); the shaders
push them apart further by retro.tile_contrast at run time. The water and
leaf_card tiles still take their fleck contrast from retro.tile_contrast.
Every run prints each tile's texels a metre and contrast numbers (stats()).

cloud_pano keeps sky.gdshader's channel layout: R = cloud bank density,
G = lit (1) vs shaded (0), B = streak density. Periodic in x (azimuth),
row 0 = horizon, last row = zenith.

Deterministic: every tile is seeded by its name, so re-running changes nothing
unless a parameter changes. Re-run with --seed N for a different roll.

Usage: python3 tools/look/make_retro_tiles.py [--seed N] [--preview] [--stats]
  --stats only prints the numbers for the tiles on disk.
  --preview also writes docs/references/batch3/retro_tiles_preview.png
  (each tile shown 4x nearest, tiled 3x3, next to its name).
"""
import argparse, json, os, sys, zlib
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "textures", "retro")
LOOK = json.load(open(os.path.join(ROOT, "data", "look.json")))["retro"]
CONTRAST = float(LOOK.get("tile_contrast", 0.3))


# ---------------------------------------------------------------- noise

def _fade(t):
    return t * t * t * (t * (t * 6 - 15) + 10)


def pnoise(w, h, fx, fy, rng):
    """Periodic gradient noise, tile w x h, fx x fy lattice cells. In [-1, 1]."""
    g = rng.normal(size=(fy, fx, 2))
    g /= np.linalg.norm(g, axis=2, keepdims=True) + 1e-9
    x = (np.arange(w) + 0.5) / w * fx
    y = (np.arange(h) + 0.5) / h * fy
    xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
    xf, yf = x - xi, y - yi
    X, Y = np.meshgrid(xf, yf)
    XI, YI = np.meshgrid(xi, yi)
    out = np.zeros((h, w))
    u, v = _fade(X), _fade(Y)
    acc = {}
    for dy in (0, 1):
        for dx in (0, 1):
            gg = g[(YI + dy) % fy, (XI + dx) % fx]
            acc[(dx, dy)] = gg[..., 0] * (X - dx) + gg[..., 1] * (Y - dy)
    nx0 = acc[(0, 0)] * (1 - u) + acc[(1, 0)] * u
    nx1 = acc[(0, 1)] * (1 - u) + acc[(1, 1)] * u
    out = nx0 * (1 - v) + nx1 * v
    return out * 1.4


def fbm(w, h, fx, fy, rng, octaves=3, gain=0.5):
    out, amp, tot = np.zeros((h, w)), 1.0, 0.0
    for o in range(octaves):
        out += amp * pnoise(w, h, fx << o, fy << o, rng)
        tot += amp
        amp *= gain
    return out / tot


def speckle(w, h, rng, dark=0.15, bright=0.10):
    r = rng.random((h, w))
    s = np.zeros((h, w))
    s[r < dark] = -1.0
    s[r > 1.0 - bright] = 1.0
    return s


def quantise(v, levels):
    return np.round(v * (levels - 1)) / (levels - 1)


def to_png(v, path, alpha=None):
    v = np.clip(v, 0.0, 1.0)
    rgb = np.repeat((v * 255 + 0.5).astype(np.uint8)[..., None], 3, axis=2)
    if alpha is None:
        a = np.full(v.shape, 255, np.uint8)
    else:
        a = (np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(np.dstack([rgb, a]), "RGBA").save(path)


def rng_for(name, seed):
    return np.random.default_rng(zlib.crc32(name.encode()) + seed * 7919)


# ---------------------------------------------------------------- tiles
#
# Look pass, 1 Oct (Mike: early-2000s, chunky low-res textures, big texels,
# high contrast inside: dark cracks and mortar, bright flecks). The ground,
# stone, bark and leaf tiles are drawn at about 16 texels a metre
# (retro.tile_px / retro.tile_m), so a texel is ~6 cm and every feature is
# a few whole texels: a blade 2-4, a pebble 3-7, a crack 1 with a lit lip
# below it and a shaded one above. Tones sit on a 1/16 grid (LEVELS) and
# each tile is centred on mid grey (0.5 = no change). The shaders push the
# tones apart again by retro.tile_contrast (look_tile_contrast, live: no
# regenerating), so at 0.3 DARK ends near 0.19x of the vertex colour and
# FLECK near 1.8x. leaf_card, water and cloud_pano are as they were.
DARK = 0.1875    # cracks, mortar, grooves, the gaps between blades and leaves
SHADE = 0.3125   # the shaded side of a pebble, plate, slab or leaf
LIT = 0.6875     # lit lips, ridges and blade tips
FLECK = 0.8125   # bright flecks: grit, mica, lichen, sunlit tips
LEVELS = 17


def centre(v, keep):
    """Shift the free tones (not `keep`, the drawn darks and flecks) so the
    tile averages mid grey."""
    free = ~keep
    if free.any():
        v[free] += (0.5 - v.mean()) * v.size / free.sum()
    return v


def finish(v, keep):
    return quantise(np.clip(centre(v, keep), 0.0, 1.0), LEVELS)


def flecks(v, keep, rng, share, tone):
    """Single-texel flecks of `tone` on a `share` of the free texels."""
    m = (rng.random(v.shape) < share) & ~keep
    v[m] = tone
    keep |= m


def walk(v, keep, rng, x, y, steps, tone, dx=(-1, 2), dy=(0, 2)):
    """A crack: a random walk of `steps` texels set to `tone` (wrapping)."""
    h, w = v.shape
    for _ in range(steps):
        v[y % h, x % w] = tone
        keep[y % h, x % w] = True
        x += int(rng.integers(*dx))
        y += int(rng.integers(*dy))


def pebble(v, keep, cx, cy, r, body):
    """A pebble or clod of radius `r` texels: lit rim top-left, shaded rim
    bottom-right, a one-texel shadow cast down-right (wrapping)."""
    h, w = v.shape
    rr = (r + 0.35) ** 2
    for oy in range(-r - 1, r + 3):
        for ox in range(-r - 1, r + 3):
            y, x = (cy + oy) % h, (cx + ox) % w
            if ox * ox + oy * oy <= rr:
                t = body
                if ox * ox + oy * oy > (r - 0.65) ** 2:
                    t = LIT if ox + oy < 0 else (SHADE if ox + oy > 0 else body)
                v[y, x] = t
                keep[y, x] = True
            elif (ox - 1) ** 2 + (oy - 1) ** 2 <= rr:
                v[y, x] = min(v[y, x], SHADE)
                keep[y, x] = True


def grass(n, rng):
    """Blades and tufts: short strokes with a shaded root and a lit tip over
    clumps about a metre across, soil showing dark between them."""
    v = 0.5 + 0.06 * fbm(n, n, 4, 4, rng, 3) + 0.04 * fbm(n, n, 16, 16, rng, 1)
    keep = np.zeros((n, n), bool)
    for _ in range(n * n // 12):
        x, y = int(rng.integers(n)), int(rng.integers(n))
        ln = int(rng.integers(2, 5))
        lean = int(rng.integers(-1, 2))
        for k in range(ln):
            yy, xx = (y - k) % n, (x + (lean * k) // 2) % n
            v[yy, xx] = SHADE if k == 0 else (LIT if k == ln - 1 else 0.5625)
            keep[yy, xx] = True
    flecks(v, keep, rng, 0.07, DARK)
    flecks(v, keep, rng, 0.03, FLECK)
    return finish(v, keep)


def dirt(n, rng):
    """Packed soil: pebbles and clods with lit tops and cast shadows, a few
    dry cracks, dark pits and bright grit."""
    v = 0.5 + 0.06 * fbm(n, n, 4, 4, rng, 3)
    keep = np.zeros((n, n), bool)
    for _ in range(4):
        walk(v, keep, rng, int(rng.integers(n)), int(rng.integers(n)), int(rng.integers(6, 15)), DARK, (-1, 2), (-1, 2))
    for _ in range(n * n // 85):
        r = int(rng.choice([1, 1, 1, 2, 2, 3]))
        body = 0.5 + float(rng.choice([-1, 0, 1, 1])) * 0.0625
        pebble(v, keep, int(rng.integers(n)), int(rng.integers(n)), r, body)
    flecks(v, keep, rng, 0.05, DARK)
    flecks(v, keep, rng, 0.03, FLECK)
    return finish(v, keep)


def sand(n, rng):
    """Wind ripples about a metre apart (a lit crest, a shaded lee under it)
    and coarse grains, light and dark: quieter than dirt, never flat."""
    warp = fbm(n, n, 2, 2, rng, 2)
    y = (np.arange(n)[:, None] + 0.5) / n
    saw = np.mod(4 * y + 0.45 * warp, 1.0)
    v = 0.5 + 0.04 * fbm(n, n, 8, 8, rng, 2)
    keep = np.zeros((n, n), bool)
    crest = saw < 0.07
    lee = (saw >= 0.07) & (saw < 0.2)
    v[crest] = LIT - 0.0625
    v[lee] = SHADE + 0.0625
    keep |= crest | lee
    flecks(v, keep, rng, 0.05, SHADE)
    flecks(v, keep, rng, 0.05, LIT)
    return finish(v, keep)


def bark(n, rng):
    """Bark plates between deep grooves: each groove a dark texel line that
    wobbles down the tile with a lit ridge on its left and a shaded edge on
    its right, broken now and then by a plate bridging it; short cross
    cracks, pits and pale lichen flecks."""
    v = 0.5 + 0.07 * fbm(n, n, 8, 2, rng, 3, 0.6)
    keep = np.zeros((n, n), bool)
    count = max(4, n // 7)
    gxs = (np.arange(count) + rng.uniform(-0.4, 0.4, count)) * n / count
    for gx in gxs:
        wob = fbm(1, n, 1, 2, rng, 3, 0.6)[:, 0] * 4.0
        gap = fbm(1, n, 1, 4, rng, 2)[:, 0]
        for y in range(n):
            if gap[y] > 0.28:
                continue  # a plate bridges the groove here
            x = int(round(gx + wob[y])) % n
            v[y, x] = DARK
            v[y, (x - 1) % n] = LIT
            if not keep[y, (x + 1) % n]:
                v[y, (x + 1) % n] = SHADE
            keep[y, x] = keep[y, (x - 1) % n] = keep[y, (x + 1) % n] = True
    for _ in range(n // 4):
        x, y = int(rng.integers(n)), int(rng.integers(n))
        for k in range(int(rng.integers(2, 4))):
            if not keep[y, (x + k) % n]:
                v[y, (x + k) % n] = DARK + 0.0625
                keep[y, (x + k) % n] = True
    flecks(v, keep, rng, 0.03, DARK)
    flecks(v, keep, rng, 0.025, FLECK)
    return finish(v, keep)


def leaves(n, rng):
    """A leafy surface: small leaves (2-3 texels, lit top-left, shaded
    bottom-right) packed over deep gaps, with a few sunlit tips."""
    v = SHADE + 0.06 * fbm(n, n, 4, 4, rng, 2)
    keep = np.zeros((n, n), bool)
    flecks(v, keep, rng, 0.3, DARK)
    for _ in range(n * n // 6):
        x, y = int(rng.integers(n)), int(rng.integers(n))
        body = 0.5 + float(rng.choice([-1, 0, 0, 1])) * 0.0625
        shape = [(0, 0), (1, 0), (0, 1), (1, 1)] if rng.random() < 0.6 else [(0, 0), (1, 0), (2, 0), (1, 1)]
        for (ox, oy) in shape:
            yy, xx = (y + oy) % n, (x + ox) % n
            v[yy, xx] = LIT if (ox, oy) == (0, 0) else (SHADE if (ox, oy) == shape[-1] else body)
            keep[yy, xx] = True
    flecks(v, keep, rng, 0.03, FLECK)
    return finish(v, keep)


def leaf_card(n, rng):
    c = CONTRAST
    v = 0.5 + 0.4 * c * fbm(n, n, 4, 4, rng, 3, 0.6) + 0.45 * c * speckle(n, n, rng, 0.14, 0.12)
    ys, xs = np.mgrid[0:n, 0:n]
    d = np.sqrt((xs - n / 2 + 0.5) ** 2 + (ys - n / 2 + 0.5) ** 2) / (n / 2)
    rag = fbm(n, n, 5, 5, rng, 2)
    alpha = ((d + 0.5 * rag) < 0.92).astype(float)  # ragged cluster, 1-bit cutout
    # a few bites so the silhouette is leafy, not a blob
    for _ in range(7):
        bx, by = rng.integers(n), rng.integers(n)
        r = rng.integers(2, 5)
        dd = np.sqrt((xs - bx) ** 2 + (ys - by) ** 2)
        alpha[(dd < r) & (d > 0.55)] = 0.0
    return quantise(v, 6), alpha


def stone(n, rng):
    """Cracked stone: slabs about a metre and a half wide and one high
    (periodic Voronoi cells, squashed so they lie like courses or strata),
    each its own tone, parted by one-texel dark cracks with a lit lip below
    and right of them and a shaded one above and left; hairline cracks in
    the slabs, dark pits and bright mica flecks. Serves the ruins' blocks
    (their geometry makes the courses; this is the stone's face) and the
    ground's rock faces."""
    cells = max(6, (n * n) // 420)
    pts = rng.random((cells, 2)) * n
    tones = rng.choice([-2, -1, -1, 0, 0, 1, 1, 2], cells) * 0.03125
    ys, xs = np.mgrid[0:n, 0:n] + 0.5
    d1 = np.full((n, n), 1e9)
    d2 = np.full((n, n), 1e9)
    idx = np.zeros((n, n), int)
    for k, (px, py) in enumerate(pts):
        for oy in (-n, 0, n):
            for ox in (-n, 0, n):
                d = np.hypot(xs - px - ox, (ys - py - oy) * 1.6)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                idx = np.where(closer, k, idx)
                d1 = np.where(closer, d, d1)
    v = 0.5 + tones[idx] + 0.05 * fbm(n, n, 8, 8, rng, 2)
    crack = (d2 - d1) < 1.1
    lit = (np.roll(crack, 1, axis=0) | np.roll(crack, 1, axis=1)) & ~crack
    shade = (np.roll(crack, -1, axis=0) | np.roll(crack, -1, axis=1)) & ~crack & ~lit
    v[lit] = LIT - 0.0625
    v[shade] = SHADE
    v[crack] = DARK
    keep = crack | lit | shade
    for _ in range(max(2, n // 20)):
        walk(v, keep, rng, int(rng.integers(n)), int(rng.integers(n)), int(rng.integers(4, 9)), SHADE, (-1, 2), (0, 2))
    flecks(v, keep, rng, 0.03, DARK)
    flecks(v, keep, rng, 0.03, FLECK)
    return finish(v, keep)


def water(n, rng):
    c = CONTRAST
    v = 0.5 + 0.12 * c * fbm(n, n, 3, 3, rng, 2)
    y = np.arange(n)[:, None] / n
    warp = fbm(n, n, 2, 2, rng, 2)
    v += 0.05 * c * np.sin(2 * np.pi * (6 * y + 0.5 * warp))
    return quantise(v, 8)


def cloud_pano(w, h, rng):
    """R bank density (hard-edged, painted), G lit-vs-shade, B streaks. x periodic."""
    ys = np.arange(h)[:, None] / h              # 0 horizon .. 1 zenith
    # cumulus banks: fBm pushed through a steep curve for painted edges;
    # more compressed toward the horizon (perspective), sparser at the zenith.
    base = fbm(w, h, 6, 2, rng, 4, 0.55)
    base = base + 0.25 * fbm(w, h, 24, 6, rng, 2) * (1.0 - ys)
    edge = 1.0 / (1.0 + np.exp(-(base - 0.12) * 9.0))
    bank = np.clip(edge * (1.05 - 0.35 * ys), 0, 1)
    bank = quantise(bank, 6)
    # lit from above: brighter where the bank thins upward (top edges)
    up = np.roll(bank, -2, axis=0)
    lit = np.clip(0.5 + 1.2 * (bank - up) + 0.25 * fbm(w, h, 12, 3, rng, 2), 0, 1)
    lit = np.where(bank > 0.05, lit, 0.5)
    lit = quantise(lit, 6)
    # high streaks: long thin cirrus, stretched along azimuth
    streak = fbm(w, h, 32, 3, rng, 2)
    streak = np.clip((streak - 0.15) * 3.0, 0, 1) * np.clip(ys * 2.0, 0, 1)
    streak = quantise(streak, 4)
    rgb = np.dstack([bank, lit, streak])
    Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(
        os.path.join(OUT, "cloud_pano.png"))
    return bank


def stats():
    """Per-tile numbers to tune by (no pictures): texels a metre (tile_px /
    tile_m), the tones (5th / 50th / 95th percentile, spread), the share of
    dark (<= SHADE) and bright (>= LIT) texels, the mean step between
    neighbouring texels, the grey levels used, and what the shaders make of
    it: the factor on the vertex colour, 2 * (0.5 + (v - 0.5) * (1 +
    tile_contrast)), at the 5th and 95th percentile, and the spread left at
    the first mip (2x2 average, from ~25 m on the ground)."""
    tm = LOOK.get("tile_m", {})
    k = 1.0 + CONTRAST
    print("tile      px  tile_m texel/m |  p5   p50  p95   std  dark% brite% step lvls | x p5  x p95 | mip1 std")
    for name in ["grass", "dirt", "sand", "stone", "bark", "leaves", "water"]:
        v = np.asarray(Image.open(os.path.join(OUT, name + ".png")).convert("L"), float) / 255.0
        n = v.shape[0]
        m = float(tm.get(name, 0.0))
        step = 0.5 * (np.abs(np.diff(v, axis=0)).mean() + np.abs(np.diff(v, axis=1)).mean())
        f = np.clip(2.0 * (0.5 + (v - 0.5) * k), 0.0, 2.0)
        mip = v.reshape(n // 2, 2, n // 2, 2).mean(axis=(1, 3))
        print("%-7s %4d  %6s %7s | %.2f %.2f %.2f %.3f %5.1f %5.1f %.3f %3d | %.2f  %.2f | %.3f" % (
            name, n, ("%.1f" % m) if m else "-", ("%.1f" % (n / m)) if m else "-",
            np.percentile(v, 5), np.percentile(v, 50), np.percentile(v, 95), v.std(),
            100.0 * (v <= SHADE + 0.01).mean(), 100.0 * (v >= LIT - 0.01).mean(), step, len(np.unique(v)),
            np.percentile(f, 5), np.percentile(f, 95), mip.std()))
    print("(tile_contrast %.2f; x = factor on the vertex colour after the shader's push)" % CONTRAST)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--stats", action="store_true", help="only print the stats of the tiles on disk")
    a = ap.parse_args()
    if a.stats:
        stats()
        return
    os.makedirs(OUT, exist_ok=True)
    px = LOOK["tile_px"]
    made = {}
    for name, fn in [("grass", grass), ("dirt", dirt), ("sand", sand), ("bark", bark),
                     ("leaves", leaves), ("stone", stone), ("water", water)]:
        n = int(px.get(name, 64))
        v = fn(n, rng_for(name, a.seed))
        to_png(v, os.path.join(OUT, name + ".png"))
        made[name] = (v, None)
    n = int(px.get("leaves", 32))
    v, al = leaf_card(n, rng_for("leaf_card", a.seed))
    to_png(v, os.path.join(OUT, "leaf_card.png"), al)
    made["leaf_card"] = (v, al)
    pano = cloud_pano(*LOOK["clouds"]["pano_px"], rng_for("cloud_pano", a.seed))
    print("wrote %d tiles + cloud_pano to %s" % (len(made), os.path.relpath(OUT, ROOT)))
    stats()

    if a.preview:
        cell, gap = 3 * 64 * 2, 24   # 3x3 tiles at 2x (64 px tiles) -> 384
        names = list(made)
        sheet = Image.new("RGB", (gap + (cell + gap) * 4, 2 * (cell + gap + 20) + 140 + gap), (16, 16, 24))
        d = ImageDraw.Draw(sheet)
        for i, name in enumerate(names):
            v, al = made[name]
            n = v.shape[0]
            img = Image.fromarray(np.dstack([np.repeat((np.clip(v, 0, 1) * 255).astype(np.uint8)[..., None], 3, 2),
                                             (np.full(v.shape, 255) if al is None else al * 255).astype(np.uint8)]), "RGBA")
            tiled = Image.new("RGBA", (n * 3, n * 3))
            for ty in range(3):
                for tx in range(3):
                    tiled.paste(img, (tx * n, ty * n))
            scale = cell // (n * 3)
            big = tiled.resize((n * 3 * scale, n * 3 * scale), Image.NEAREST)
            bg = Image.new("RGB", big.size, (40, 70, 30) if name == "leaf_card" else (0, 0, 0))
            bg.paste(big, (0, 0), big)
            x = gap + (i % 4) * (cell + gap)
            y = gap + (i // 4) * (cell + gap + 20)
            sheet.paste(bg, (x, y))
            d.text((x, y + cell + 4), "%s %dpx x3 (nearest)" % (name, n), fill=(220, 220, 220))
        pano_img = Image.open(os.path.join(OUT, "cloud_pano.png")).getchannel("R").resize((sheet.width - 2 * gap, 128), Image.NEAREST)
        sheet.paste(pano_img, (gap, sheet.height - 140))
        d.text((gap, sheet.height - 154), "cloud_pano 512x128, R channel = bank density (G lit, B streak)", fill=(220, 220, 220))
        p = os.path.join(ROOT, "docs", "references", "batch3", "retro_tiles_preview.png")
        sheet.save(p)
        print("preview:", os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
