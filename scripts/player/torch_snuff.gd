class_name TorchSnuff
extends RefCounted
## The torch stays lit (design 6 Oct §ET.7, amended by §EZ.1 and §EZ.5;
## data/torch.json snuff): in the crawler, walking, sprinting flat out for
## as long as you like, turning, looking about and the swing (§CN) never
## gutter it or put it out. Deep water is the one thing that does, and it
## warns first with the coal guttering (`gutter`, 0-1, which Torch draws:
## dimmer, redder, a harder flicker; and a sputter you hear):
##
##   water   wading toward torch.json douse_depth_m gutters it; past it
##           the water puts it out (§AW, Torch).
##   draft   the builders' airways (§ET.6, Airways) only move the flame:
##           an ordinary draft leans it toward open air (`lean`) and
##           quickens its flicker a little (`flicker`, as §EV.3's draft
##           does a vented fire's); a strong gust at a marked airway mouth
##           whips it hard away from the mouth, and it holds.
##
## Out means out: relight at a lit hearth, a relit fire-holder or a
## carried coal (§CQ). The torch still burns down (§FJ.4; Torch.burn_step).
## The open world (Torchfire 2) keeps its own rules: Torch steps this only
## while the crawler runs (GameMode.crawler_running).

## How deep (m) under douse_depth_m the wading starts to gutter it.
const WADE_WARN_M := 0.25
## The gutter's rise toward a new warning (s): quick, so it reads at once.
const RISE_S := 0.15
## How long the gutter takes to fall back to nothing (s).
const RECOVER_S := 2.0
## The gutter at which the sputter is heard.
const SPUTTER_AT := 0.3

## Something that blows: Airways (the crawler sets it), with
## draft_at(pos) -> {"lean": Vector3, "flicker": 0-1, "gust": bool}.
static var drafts: Object = null

## 0-1: how hard the coal gutters now (Torch dims and flickers by it).
var gutter := 0.0
## The draft's push on the flame and its smoke (scene, m/s).
var lean := Vector3.ZERO
## 0-1: how much the draft quickens the light's flicker (Torch).
var flicker := 0.0
## A strong airway gust has the flame now (it whips; it never puts it out).
var gust := false
## What is guttering it now: "" or "water".
var cause := ""
var _sputtered := false


func reset() -> void:
	gutter = 0.0
	lean = Vector3.ZERO
	flicker = 0.0
	gust = false
	cause = ""
	_sputtered = false


## One frame of a lit torch in hand: the draft's lean and flicker, and the
## water's gutter. `depth`: the water at the player's feet (m; negative is
## dry). Nothing here puts the torch out: the water does that past
## douse_depth_m (Torch.update_torch).
func step(torch: Torch, delta: float, depth: float) -> void:
	lean = Vector3.ZERO
	flicker = 0.0
	gust = false
	if drafts != null and is_instance_valid(drafts):
		var d: Dictionary = drafts.call("draft_at", torch.flame_position())
		lean = d.get("lean", Vector3.ZERO)
		flicker = float(d.get("flicker", 0.0))
		gust = bool(d.get("gust", false))
	var want := 0.0
	var why := ""
	var douse := float(Torch.D.get("douse_depth_m", 0.6))
	if depth > douse - WADE_WARN_M:
		want = 0.35 + 0.65 * clampf((depth - (douse - WADE_WARN_M)) / WADE_WARN_M, 0.0, 1.0)
		why = "water"
	cause = why
	gutter = move_toward(gutter, want, delta / (RISE_S if want > gutter else RECOVER_S))
	if gutter >= SPUTTER_AT and not _sputtered:
		_sputtered = true
		torch.sputter()
	elif gutter < SPUTTER_AT * 0.5:
		_sputtered = false
