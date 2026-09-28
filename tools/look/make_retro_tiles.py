#!/usr/bin/env python3
"""Generate the §AG retro detail tiles (design RECONCILIATION §AG, data/look.json retro).

Writes assets/textures/retro/<name>.png — tiny, tileable, meant to be drawn
NEAREST-filtered and repeated every retro.tile_m metres:

  grass 64, dirt 64, sand 64, bark 64, water 64, stone 128, leaves 32,
  leaf_card 32 (RGBA cutout), and cloud_pano 512x128.

Every ground/bark/leaf tile follows the LookTextures convention: a greyscale
MODULATION centred on mid-grey (0.5 = no change), stored in RGB with alpha 255,
so the shaders can multiply it by the vertex colour exactly as they do with
the painted 256 px textures today. Fleck contrast = retro.tile_contrast.

cloud_pano keeps sky.gdshader's channel layout: R = cloud bank density,
G = lit (1) vs shaded (0), B = streak density. Periodic in x (azimuth),
row 0 = horizon, last row = zenith.

Deterministic: every tile is seeded by its name, so re-running changes nothing
unless a parameter changes. Re-run with --seed N for a different roll.

Usage: python3 tools/look/make_retro_tiles.py [--seed N] [--preview]
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


def stamp_disc(v, cx, cy, r, lit, shade):
    """A pebble/clod: lit top-left, dark bottom-right, wrapping at edges."""
    h, w = v.shape
    ys, xs = np.mgrid[-r - 1:r + 2, -r - 1:r + 2]
    d = np.sqrt(xs ** 2 + ys ** 2)
    inside = d <= r + 0.5
    tone = np.where((xs + ys) < 0, lit, shade)
    for oy, ox, t, ins in zip(ys.ravel(), xs.ravel(), tone.ravel(), inside.ravel()):
        if ins:
            v[(cy + oy) % h, (cx + ox) % w] = t
    return v


# ---------------------------------------------------------------- tiles

def grass(n, rng):
    c = CONTRAST
    v = 0.5 + 0.35 * c * fbm(n, n, 4, 4, rng, 3)
    v += 0.45 * c * speckle(n, n, rng, 0.14, 0.09)
    # short blades: dark base, lit tip
    for _ in range(n * n // 40):
        x, y0 = rng.integers(n), rng.integers(n)
        ln = rng.integers(3, 7)
        for k in range(ln):
            v[(y0 - k) % n, x] = 0.5 - 0.6 * c if k < ln // 2 else 0.5 + 0.7 * c
    return quantise(v, 8)


def dirt(n, rng):
    c = CONTRAST
    v = 0.5 + 0.25 * c * fbm(n, n, 4, 4, rng, 3)
    v += 0.2 * c * speckle(n, n, rng, 0.08, 0.04)
    for _ in range(n * n // 170):
        r = int(rng.integers(1, 4))
        stamp_disc(v, int(rng.integers(n)), int(rng.integers(n)), r, 0.5 + 0.55 * c, 0.5 - 0.6 * c)
    return quantise(v, 8)


def sand(n, rng):
    c = CONTRAST
    warp = fbm(n, n, 2, 2, rng, 2)
    y = np.arange(n)[:, None] / n
    ripple = np.sin(2 * np.pi * (4 * y + 0.45 * warp))
    v = 0.5 + 0.12 * c * ripple + 0.16 * c * fbm(n, n, 8, 8, rng, 2)
    v += 0.12 * c * speckle(n, n, rng, 0.06, 0.06)
    return quantise(v, 8)


def bark(n, rng):
    c = CONTRAST
    v = 0.5 + 0.7 * c * fbm(n, n, 10, 1, rng, 3, 0.6) + 0.15 * c * fbm(n, n, 4, 6, rng, 2)
    v += 0.2 * c * speckle(n, n, rng, 0.05, 0.03)
    # grooves: dark wobbling vertical lines at jittered spacing, a lit ridge beside each
    gxs = np.sort(rng.uniform(0, n, 6))
    for gx in gxs:
        wob = fbm(1, n, 1, 3, rng, 2)[:, 0] * 3.0
        for y in range(n):
            x = int(round(gx + wob[y])) % n
            v[y, x] = 0.5 - 0.85 * c
            v[y, (x - 1) % n] = 0.5 + 0.35 * c
    return quantise(v, 8)


def leaves(n, rng):
    c = CONTRAST
    v = 0.5 + 0.6 * c * fbm(n, n, 4, 4, rng, 3, 0.7)
    v += 0.7 * c * speckle(n, n, rng, 0.22, 0.16)
    return quantise(v, 6)


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
    c = CONTRAST
    v = 0.5 + 0.25 * c * fbm(n, n, 6, 6, rng, 3)
    rows, mortar = 4, 2
    bh = n // rows
    for r in range(rows):
        cols = 3 if r % 2 == 0 else 4
        bw = n / cols
        off = 0 if r % 2 == 0 else bw / 2
        y0 = r * bh
        v[y0:y0 + mortar, :] = 0.5 - 0.7 * c            # horizontal mortar
        tone = rng.uniform(-0.25, 0.25) * c
        for k in range(cols):
            x0 = int(round(off + k * bw)) % n
            for m in range(mortar):
                v[y0:y0 + bh, (x0 + m) % n] = 0.5 - 0.7 * c    # vertical mortar
            # block face: slight per-block tone, lit top edge, dark bottom edge
            xs = [(x0 + mortar + i) % n for i in range(int(bw) - mortar)]
            v[y0 + mortar:y0 + bh, xs] += rng.uniform(-0.45, 0.45) * c
            v[y0 + mortar, xs] += 0.35 * c
            v[y0 + bh - 1, xs] -= 0.35 * c
    # cracks: dark random walks
    for _ in range(3):
        x, y = int(rng.integers(n)), int(rng.integers(n))
        for _ in range(int(rng.integers(8, 20))):
            v[y % n, x % n] = 0.5 - 0.6 * c
            x += int(rng.integers(-1, 2)); y += int(rng.integers(0, 2))
    return quantise(v, 8)


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--preview", action="store_true")
    a = ap.parse_args()
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
