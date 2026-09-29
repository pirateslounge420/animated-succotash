#!/usr/bin/env python3
"""Measure a screenshot against the §AG reference statistics (data/look.json retro.targets).

Usage: python3 tools/look/measure_look.py <image.png> [more images...]
Prints mean luma, mean saturation, the darkest-5 % colour and its blue/red ratio
(navy shadows, not black), the dominant sky / grass / ground colours, and PASS/CHECK
against retro.targets. Also the sky share of the whole frame (blue sky or white
cloud pixels): the §AJ 4 see-through test, on a frame looking straight up
through a crown (tools/species_row.gd UP=1), should read canopy.gap ± 0.1. Run it on the batch3 frames to see what the targets came from:
    python3 tools/look/measure_look.py docs/references/batch3/*.jpg
"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
T = json.load(open(os.path.join(ROOT, "data", "look.json")))["retro"]["targets"]


def dom(px, k=3):
    im = Image.fromarray(px.reshape(-1, 1, 3).astype("uint8"), "RGB").quantize(colors=k, method=Image.Quantize.MEDIANCUT)
    pal = np.array(im.getpalette()[:k * 3]).reshape(-1, 3)
    counts = np.bincount(np.array(im).ravel(), minlength=k)
    o = np.argsort(-counts)
    return " ".join("#%02X%02X%02X(%d%%)" % (tuple(pal[i]) + (100 * counts[i] // counts.sum(),)) for i in o)


def band(v, lo_hi):
    return "PASS" if lo_hi[0] <= v <= lo_hi[1] else "CHECK (target %s-%s)" % tuple(lo_hi)


for path in sys.argv[1:]:
    a = np.asarray(Image.open(path).convert("RGB")).astype(float)
    H, W, _ = a.shape
    y = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    sat = (a.max(-1) - a.min(-1)) / np.maximum(a.max(-1), 1)
    dark = a[y < np.percentile(y, 5)]
    br = dark[:, 2].mean() / max(dark[:, 0].mean(), 1)
    lower = a[H // 2:].reshape(-1, 3)
    green = (lower[:, 1] > lower[:, 0] + 15) & (lower[:, 1] > lower[:, 2] + 15)
    ml, ms, gs = y.mean() / 255, sat.mean(), green.mean()
    print(os.path.basename(path), "%dx%d" % (W, H))
    print("  mean luma        %.2f  %s" % (ml, band(ml, T["mean_luma"])))
    print("  mean saturation  %.2f  %s" % (ms, band(ms, T["mean_saturation"])))
    print("  darkest 5%%       #%02X%02X%02X  blue/red %.1f  %s" % (tuple(int(v) for v in dark.mean(0)) + (br, band(br, T["darkest_5pct_blue_over_red"]))))
    print("  grass share      %.2f  %s" % (gs, band(gs, T["grass_share_of_lower_half"])))
    skyish = ((a[..., 2] > 150) & (a[..., 2] > a[..., 1] + 30) & (a[..., 2] > a[..., 0] + 60)) | (a.min(-1) > 185)
    print("  sky share        %.2f  (of the whole frame)" % skyish.mean())
    print("  sky (top 18%%)    %s" % dom(a[:int(H * 0.18)]))
    print("  ground (low 38%%) %s" % dom(a[int(H * 0.62):]))
    if green.sum() > 500:
        print("  grass pixels     %s" % dom(lower[green]))
