class_name TorchSnuff
extends RefCounted
## The torch is forgiving (design 6 Oct §ET.7, data/torch.json snuff): in
## the crawler, walking, turning and looking about never put it out. It
## goes out only in rare, dramatic moments, and each warns first with the
## coal guttering (`gutter`, 0-1, which Torch draws: dimmer, cooler, a
## harder flicker; and a sputter you hear):
##
##   sprint  a flat-out sprint held for sprint.gutter_after_s starts the
##           gutter; held to sprint.out_after_s it goes out. Stop sprinting
##           during the gutter and the coal recovers over sprint.recover_s.
##   draft   the builders' airways (§ET.6, Airways): an ordinary draft only
##           leans the flame and gutters it a little (`lean`, toward open
##           air); a strong draft at a marked airway mouth is heard and
##           seen coming draft.warn_s ahead and puts it out if the torch is
##           in its line and not behind cover when it blows.
##   water   deep water still douses it at torch.json douse_depth_m (§AW,
##           Torch); wading toward that depth gutters it first.
##
## Out means out: relight at a lit hearth, a relit fire-holder or a
## carried coal (§CQ). The open world (Torchfire 2) keeps its own rules:
## Torch steps this only while the crawler runs (GameMode.crawler_running).

static var S: Dictionary = Tuning.table("torch").get("snuff", {})
## The log's lines for a torch that went out this way (crawler.json
## snuff_log).
static var LOG: Dictionary = Tuning.table("crawler").get("snuff_log", {})
## How deep (m) under douse_depth_m the wading starts to gutter it.
const WADE_WARN_M := 0.25
## The gutter's rise toward a new warning (s): quick, so it reads at once.
const RISE_S := 0.15
## The gutter at which the sputter is heard.
const SPUTTER_AT := 0.3

## Something that blows: Airways (the crawler sets it), with
## draft_at(pos) -> {"lean": Vector3, "gutter": 0-1, "out": bool}.
static var drafts: Object = null

## 0-1: how hard the coal gutters now (Torch dims and flickers by it).
var gutter := 0.0
## The draft's push on the flame and its smoke (scene, m/s).
var lean := Vector3.ZERO
## Seconds of flat-out sprint banked (it drains when you stop).
var sprint_s := 0.0
## What is guttering it now: "", "sprint", "draft" or "water".
var cause := ""
var _sputtered := false


static func sprint_rule() -> Dictionary:
	return S.get("sprint", {})


func reset() -> void:
	gutter = 0.0
	sprint_s = 0.0
	lean = Vector3.ZERO
	cause = ""
	_sputtered = false


## One frame of a lit torch in hand: the gutter and the lean, and why it
## goes out now ("sprint", "draft"; "" while it holds). `depth`: the water
## at the player's feet (m; negative is dry).
func step(torch: Torch, delta: float, depth: float) -> String:
	var p := torch.player
	var sp := sprint_rule()
	var g_after := float(sp.get("gutter_after_s", 6.0))
	var out_after := maxf(float(sp.get("out_after_s", 9.0)), g_after + 0.1)
	var recover := maxf(float(sp.get("recover_s", 2.0)), 0.05)
	var flat := p.velocity - p.up * p.velocity.dot(p.up)
	if p.sprinting and flat.length() > PlanetPlayer.WALK_SPEED * 0.9 and not p.ui_open:
		sprint_s += delta
	else:
		# Back to nothing from the gutter's edge over recover_s.
		sprint_s = maxf(sprint_s - delta * g_after / recover, 0.0)
	var want := 0.0
	var why := ""
	if sprint_s > g_after:
		want = 0.35 + 0.65 * clampf((sprint_s - g_after) / (out_after - g_after), 0.0, 1.0)
		why = "sprint"
		if sprint_s >= out_after:
			return "sprint"
	lean = Vector3.ZERO
	if drafts != null and is_instance_valid(drafts):
		var d: Dictionary = drafts.call("draft_at", torch.flame_position())
		lean = d.get("lean", Vector3.ZERO)
		if bool(d.get("out", false)):
			return "draft"
		if float(d.get("gutter", 0.0)) > want:
			want = float(d.get("gutter", 0.0))
			why = "draft"
	var douse := float(Torch.D.get("douse_depth_m", 0.6))
	if depth > douse - WADE_WARN_M:
		var w := 0.35 + 0.65 * clampf((depth - (douse - WADE_WARN_M)) / WADE_WARN_M, 0.0, 1.0)
		if w > want:
			want = w
			why = "water"
	cause = why
	gutter = move_toward(gutter, want, delta / (RISE_S if want > gutter else recover))
	if gutter >= SPUTTER_AT and not _sputtered:
		_sputtered = true
		torch.sputter()
	elif gutter < SPUTTER_AT * 0.5:
		_sputtered = false
	return ""
