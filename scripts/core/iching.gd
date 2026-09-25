class_name IChing
## I Ching coin-cast probability utility: a reusable way to roll rare
## events (meteors use it; anything else can).
##
## One line = three coins, heads 3, tails 2, summed:
##   6  old yin    (3 tails)            changing  1/8
##   7  young yang (2 tails, 1 head)    stable    3/8
##   8  young yin  (1 tail, 2 heads)    stable    3/8
##   9  old yang   (3 heads)            changing  1/8
## so a line is changing (6 or 9) with probability 1/4, and a hexagram
## (6 lines) is all-changing with probability (1/4)^6 = 1/4096.
##
## Lines are listed bottom to top, as cast.

const OLD_YIN := 6
const YOUNG_YANG := 7
const YOUNG_YIN := 8
const OLD_YANG := 9
const LINES := 6


## Toss three coins; returns 6, 7, 8 or 9.
static func cast_line(rng: RandomNumberGenerator) -> int:
	var sum := 0
	for i in 3:
		sum += 3 if rng.randi() & 1 else 2
	return sum


static func is_changing(line: int) -> bool:
	return line == OLD_YIN or line == OLD_YANG


## Cast a hexagram. Returns {"lines": [6-9 ...], "all_changing": bool,
## "lines_cast": int}. With `early_exit`, casting stops at the first
## stable line (the streak is broken, so it can't be all-changing):
## "lines" then holds only the lines cast so far.
static func cast_hexagram(rng: RandomNumberGenerator, early_exit := false) -> Dictionary:
	var lines: Array[int] = []
	var all_changing := true
	for i in LINES:
		var line := cast_line(rng)
		lines.append(line)
		if not is_changing(line):
			all_changing = false
			if early_exit:
				break
	return {"lines": lines, "all_changing": all_changing, "lines_cast": lines.size()}


## True with probability (1/4)^`lines` (1/4096 for a full hexagram): the
## first `lines` lines all come up changing. Stops at the first stable one.
static func all_changing(rng: RandomNumberGenerator, lines := LINES) -> bool:
	for i in lines:
		if not is_changing(cast_line(rng)):
			return false
	return true


## The binary figure of a hexagram (not its King Wen number, which needs a
## lookup table): yang lines = 1, bottom line = bit 0,
## 0-63, and the figure it changes into (changing lines flipped).
static func figure(lines: Array) -> Vector2i:
	var now := 0
	var then := 0
	for i in lines.size():
		var yang: bool = lines[i] == YOUNG_YANG or lines[i] == OLD_YANG
		if yang:
			now |= 1 << i
		if yang != is_changing(lines[i]):
			then |= 1 << i
	return Vector2i(now, then)
