#!/bin/bash
# Run the game as Mike's Mac had it (design 1 Oct §CG): with the editor's
# import cache (.godot/imported) moved aside. The class cache and the rest of
# .godot stay. The cache is put back whatever happens (a crash, Ctrl-C).
# Any "Failed loading resource" line in the output is a failure.
#
#   tools/no_import_check.sh                 # tools/no_import_check.gd, headless
#   tools/no_import_check.sh -- <command>    # any run, e.g. the walkabout:
#   tools/no_import_check.sh -- xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
#       --rendering-method forward_plus --resolution 1280x720 -s tools/walkabout.gd
#
# GODOT (default: godot) and TIMEOUT (seconds, default 1800) for the default run.
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-godot}
if [ ! -d .godot/imported ]; then
	echo "no .godot/imported to hide: run '$GODOT --headless --path . --import' once first"
	exit 2
fi
ASIDE=".godot/imported.aside.$$"
mv .godot/imported "$ASIDE" || exit 1
restore() {
	if [ -d "$ASIDE" ]; then
		rm -rf .godot/imported
		mv "$ASIDE" .godot/imported
		echo "[no_import] the import cache is back"
	fi
}
trap restore EXIT
trap 'exit 130' INT TERM
LOG=$(mktemp)
if [ "$1" = "--" ]; then
	shift
	DEV_PIN=${DEV_PIN:-0} "$@" 2>&1 | tee "$LOG"
else
	DEV_PIN=0 timeout "${TIMEOUT:-1800}" "$GODOT" --headless --path . --fixed-fps 60 --script tools/no_import_check.gd 2>&1 | tee "$LOG"
fi
FAILED=$(grep -c "Failed loading resource" "$LOG")
FAILS=$(grep -c "^FAIL" "$LOG")
RESULT=$(grep -c "^RESULT" "$LOG")
echo "[no_import] 'Failed loading resource' lines: $FAILED"
grep "Failed loading resource" "$LOG" | sort -u | head -20
rm -f "$LOG"
if [ "$FAILED" -gt 0 ] || [ "$FAILS" -gt 0 ] || [ "$RESULT" -eq 0 ]; then
	echo "[no_import] FAIL (failed loads $FAILED, FAIL lines $FAILS, result lines $RESULT)"
	exit 1
fi
echo "[no_import] PASS"
exit 0
