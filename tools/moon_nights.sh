#!/bin/bash
# The moon nights (design 3 Oct §DD, data/look.json moon_nights), rendered:
# a walkabout frame on the open prairie at 02:00 under a full moon and a new
# one, and at 20:00 under the waxing first quarter (high in the evening; at
# 02:00 it has set), each measured with tools/look/measure_look.py. PASS when
# each frame's mean luma is within ±0.03 of its target and the darkest 5 %
# stays navy (blue/red > 2).
#   tools/moon_nights.sh            (SEED=7731 by default)
cd "$(dirname "$0")/.."
SEED=${SEED:-7731}
GODOT=${GODOT:-godot}
OUT=$(mktemp -d)
fails=0
for spec in full:2:full_mean_luma new:2:new_mean_luma first_quarter:20:first_quarter_mean_luma; do
	IFS=: read phase hour key <<< "$spec"
	SEED=$SEED QUICK=1 MOON=$phase HOURS=$hour SITES=random_biome BIOMES=TALLGRASS_PRAIRIE \
		xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-method forward_plus \
		--resolution 1280x720 -s tools/walkabout.gd > "$OUT/$phase.log" 2>&1
	f=$(ls -t tools/reference/walkabout/$SEED/*.png | head -1)
	cp "$f" "$OUT/$phase.png"
	python3 - "$OUT/$phase.png" "$key" "$phase" <<'PY' || fails=$((fails + 1))
import json, sys
import numpy as np
from PIL import Image
path, key, phase = sys.argv[1:4]
a = np.asarray(Image.open(path).convert("RGB")).astype(float)
# measure_look.py's crop_bars: the letterbox bars off.
m = a.mean(-1)
rows, cols = np.where(m.mean(1) > 4)[0], np.where(m.mean(0) > 4)[0]
if rows.size >= 8 and cols.size >= 8:
    a = a[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
y = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
dark = a[y <= np.percentile(y, 5)]
br = dark[:, 2].mean() / max(dark[:, 0].mean(), 1)
want = json.load(open("data/look.json"))["moon_nights"][key]
got = y.mean() / 255
ok = abs(got - want) <= 0.03 and br > 2
print("%s  %s: mean luma %.3f (target %.2f ±0.03), darkest 5%% blue/red %.1f" % ("PASS" if ok else "FAIL", phase, got, want, br))
sys.exit(0 if ok else 1)
PY
done
echo "RESULT fails: $fails"
exit $fails
