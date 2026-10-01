#!/usr/bin/env python3
"""A contact sheet of one seed's walkabout frames (design §CA): every PNG in
tools/reference/walkabout/<seed>/, 12 a row, each 213x120 with its name
under it, to sheet_<seed>.png next to the folders.

    python3 tools/reference/walkabout/sheet.py 101 [202 ...]
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, COLS, PAD, CAP = 213, 120, 12, 2, 12

for seed in sys.argv[1:]:
    files = sorted(glob.glob(os.path.join(HERE, seed, "*.png")))
    if not files:
        print("no frames for", seed)
        continue
    rows = (len(files) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * (W + PAD), rows * (H + PAD + CAP)), (8, 10, 24))
    draw = ImageDraw.Draw(sheet)
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB").resize((W, H), Image.NEAREST)
        x, y = (i % COLS) * (W + PAD), (i // COLS) * (H + PAD + CAP)
        sheet.paste(im, (x, y))
        draw.text((x + 2, y + H), os.path.basename(f)[:-4][:36], fill=(220, 225, 240))
    out = os.path.join(HERE, "sheet_%s.png" % seed)
    sheet.save(out)
    print("wrote", out, len(files), "frames")
