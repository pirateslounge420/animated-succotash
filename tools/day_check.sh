#!/bin/bash
# Day 1 and one clock (design 1 Oct §CG) on four seeds whose opening camps
# sit at spread longitudes (156°E, 74.5°E, 29.5°W, 169.3°W); every run also checks Mike's 23:11 spawn
# (12.7°N, 140.1°W) on its world's sky. Prints each camp's place and
# fails if any run does.
#   tools/day_check.sh                # the four seeds below
#   tools/day_check.sh 7731 90210     # others
# GODOT (default: godot), TIMEOUT (seconds per run, default 900).
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
SEEDS=("$@")
[ ${#SEEDS[@]} -eq 0 ] && SEEDS=(7731 1378252316 90210 31337)
BAD=0
for s in "${SEEDS[@]}"; do
	OUT=$(SEED=$s timeout "${TIMEOUT:-900}" "$GODOT" --headless --path . --fixed-fps 60 --script tools/day_check.gd 2>&1)
	echo "$OUT" | grep -E "^\[day\]|^PASS|^FAIL|^RESULT|^   "
	echo "$OUT" | grep -q "^RESULT fails: 0" || BAD=$((BAD + 1))
done
echo "[day_check] ${#SEEDS[@]} seeds, $BAD failed"
[ $BAD -eq 0 ]
