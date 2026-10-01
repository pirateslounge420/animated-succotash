#!/usr/bin/env python3
"""Measure a screenshot against the reference statistics (data/look.json retro.targets).
Usage: python3 tools/look/measure_look.py [--day|--night] <image.png> [more images...]
The band is day or night (retro.targets.day / .night, design §BU: measured from the
reference frames); without a flag a name ending _HHh picks it (19:00-05:00 night), else day.
Black bars (a letterboxed window capture) are cropped away first, to the 480-line frame.
Prints mean luma, mean saturation, texel detail (the mean luma step between neighbouring
pixels, both axes, 0-1: the §AG tiles' crispness), the darkest-5 % luma and colour and its
blue/red ratio (navy shadows, not black), the dominant sky / grass / ground colours, and
PASS/CHECK against the band. Also the sky share of the whole frame (blue sky or white
cloud pixels): the §AJ 4 see-through test, on a frame looking straight up
through a crown (tools/species_row.gd UP=1), should read canopy.gap ± 0.1. Run it on the batch3 frames to see what the targets came from:
    python3 tools/look/measure_look.py --day docs/references/batch3/*.jpg
"""
import json, os, re, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TARGETS = json.load(open(os.path.join(ROOT, "data", "look.json")))["retro"]["targets"]


def band_for(path, forced):
    if forced:
        return forced
    m = re.search(r"_(\d{1,2})h", os.path.basename(path))
    if m:
        h = int(m.group(1))
        return "night" if (h >= 19 or h < 5) else "day"
    return "day"


def crop_bars(a):
    """Drop black letterbox / pillarbox rows and columns (a window capture with bars)."""
    y = a.mean(-1)
    rows = np.where(y.mean(1) > 4)[0]
    cols = np.where(y.mean(0) > 4)[0]
    if rows.size < 8 or cols.size < 8:
        return a
    return a[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def dom(px, k=3):
    im = Image.fromarray(px.reshape(-1, 1, 3).astype("uint8"), "RGB").quantize(colors=k, method=Image.Quantize.MEDIANCUT)
    pal = np.array(im.getpalette()[:k * 3]).reshape(-1, 3)
    counts = np.bincount(np.array(im).ravel(), minlength=k)
    o = np.argsort(-counts)
    return " ".join("#%02X%02X%02X(%d%%)" % (tuple(pal[i]) + (100 * counts[i] // counts.sum(),)) for i in o)


def band(v, lo_hi):
    return "PASS" if lo_hi[0] <= v <= lo_hi[1] else "CHECK (target %s-%s)" % tuple(lo_hi)


forced = None
args = []
for arg in sys.argv[1:]:
    if arg in ("--day", "--night"):
        forced = arg[2:]
    else:
        args.append(arg)
for path in args:
    a = crop_bars(np.asarray(Image.open(path).convert("RGB")).astype(float))
    H, W, _ = a.shape
    which = band_for(path, forced)
    T = TARGETS.get(which, TARGETS)
    y = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    sat = (a.max(-1) - a.min(-1)) / np.maximum(a.max(-1), 1)
    # The darkest 5 % by luma; when the frame is flat, the darkest pixels anyway.
    cut = np.percentile(y, 5)
    dark = a[y <= cut]
    if dark.shape[0] == 0:
        dark = a.reshape(-1, 3)[:1]
    dl = (0.299 * dark[:, 0] + 0.587 * dark[:, 1] + 0.114 * dark[:, 2]).mean() / 255
    br = dark[:, 2].mean() / max(dark[:, 0].mean(), 1)
    # Texel detail: the mean luma step to the right and down, 0-1.
    tex = (np.abs(np.diff(y, axis=1)).mean() + np.abs(np.diff(y, axis=0)).mean()) * 0.5 / 255
    lower = a[H // 2:].reshape(-1, 3)
    green = (lower[:, 1] > lower[:, 0] + 15) & (lower[:, 1] > lower[:, 2] + 15)
    ml, ms, gs = y.mean() / 255, sat.mean(), green.mean()
    print(os.path.basename(path), "%dx%d  band: %s" % (W, H, which))
    print("  mean luma        %.2f  %s" % (ml, band(ml, T["mean_luma"])))
    print("  mean saturation  %.2f  %s" % (ms, band(ms, T["mean_saturation"])))
    print("  texel detail     %.3f  %s" % (tex, band(tex, T.get("texel_detail", [0, 1]))))
    print("  darkest 5%%       %.3f luma #%02X%02X%02X  %s  blue/red %.1f  %s" % ((dl,) + tuple(int(v) for v in dark.mean(0)) + (band(dl, T.get("darkest_5pct_luma", [0, 1])), br, band(br, T["darkest_5pct_blue_over_red"]))))
    print("  grass share      %.2f  %s" % (gs, band(gs, T["grass_share_of_lower_half"])))
    skyish = ((a[..., 2] > 150) & (a[..., 2] > a[..., 1] + 30) & (a[..., 2] > a[..., 0] + 60)) | (a.min(-1) > 185)
    print("  sky share        %.2f  (of the whole frame)" % skyish.mean())
    print("  sky (top 18%%)    %s" % dom(a[:int(H * 0.18)]))
    print("  ground (low 38%%) %s" % dom(a[int(H * 0.62):]))
    if green.sum() > 500:
        print("  grass pixels     %s" % dom(lower[green]))
