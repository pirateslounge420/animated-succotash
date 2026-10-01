#!/bin/bash
# The walkabout over four seeds (design 1 Oct §CA; data/habitat.json walkabout):
#   tools/reference/walkabout/run.sh            # seeds 101 202 303 404 on the full planet
#   SEEDS="7 8" STAMP=1 tools/reference/walkabout/run.sh
# Writes <seed>/*.png and walkabout.txt here, then a contact sheet per seed
# (sheet_<seed>.png, tools/reference/walkabout/sheet.py).
cd "$(dirname "$0")/../../.." || exit 1
SEEDS=${SEEDS:-"101 202 303 404"}
first=1
for s in $SEEDS; do
	RESET=$first SEED=$s timeout 7200 xvfb-run -a -s "-screen 0 1280x720x24" "${GODOT:-godot}" --path . --rendering-method forward_plus --resolution 1280x720 -s tools/walkabout.gd 2>&1 | grep -E "PASS|FAIL|RESULT|SCRIPT ERROR"
	first=0
	python3 tools/reference/walkabout/sheet.py "$s"
done
grep -E "^(== |-- |RESULT)" tools/reference/walkabout/walkabout.txt
