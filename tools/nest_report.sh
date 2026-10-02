#!/bin/bash
# The nests on four seeds (design 1 Oct §CK, tools/nest_report.gd): nests by
# kind, the camp loop's stages, living camps by people, remains. Fails if a
# seed's run fails, or if shelter folk or karst folk have no camp on the
# four seeds together (§CK: tier 1 brings them back).
#   tools/nest_report.sh                 # 7731 467606063 1378252316 90210
#   tools/nest_report.sh 7731 31337      # others
# GODOT (default: godot), TIMEOUT (seconds per run, default 1200).
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
SEEDS=("$@")
[ ${#SEEDS[@]} -eq 0 ] && SEEDS=(7731 467606063 1378252316 90210)
BAD=0
SHELTER=0
KARST=0
for s in "${SEEDS[@]}"; do
	OUT=$(SEED=$s timeout "${TIMEOUT:-1200}" "$GODOT" --headless --path . --script tools/nest_report.gd 2>&1)
	echo "$OUT" | grep -E "^\[nests\]|^PASS|^FAIL|^RESULT|SCRIPT ERROR"
	echo "$OUT" | grep -q "^RESULT fails: 0" || BAD=$((BAD + 1))
	C=$(echo "$OUT" | grep "^\[nests\] COUNTS")
	SHELTER=$((SHELTER + $(echo "$C" | sed -n 's/.*shelter=\([0-9]*\).*/\1/p')))
	KARST=$((KARST + $(echo "$C" | sed -n 's/.*karst=\([0-9]*\).*/\1/p')))
done
echo "[nest_report] ${#SEEDS[@]} seeds, $BAD failed · shelter folk camps $SHELTER · karst folk camps $KARST"
[ $BAD -eq 0 ] && [ "$SHELTER" -gt 0 ] && [ "$KARST" -gt 0 ]
