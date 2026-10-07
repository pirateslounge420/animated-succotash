class_name RuinStyle
## One ruin, one stone (design 6 Oct §EX.1, §EX.3; data/masonry.json
## styles, style_by_theme): each ruin type has one style, and every built
## surface in it (walls, floor, ceiling, door frames and thresholds, stairs,
## niches, fire-holders, coffins and rubble) is cut from that style's one
## stone: one tint, each stone straying from it lighter or darker by at most
## stone.spread, with the walls' own joint shade (the scene's shade, navy:
## Prelit.ao_tint, §ES.2). Nothing built of stone takes RuinBuilder's general
## palette or a hard-coded colour (rule.no_general_palette); the heart's
## ochre, soot, moss and drift lie on top of the stone (rule.on_top).
##
## stone.tint "theme" is the stage's own stone: crawler.json themes.<theme>
## stone (the tomb's is the mean its fitted walls showed before §EX, so the
## walls keep their tone). Pure and static: TombBuild, FittedStone and
## CrawlerFires read it by the tomb's theme.

static var M: Dictionary = Tuning.table("masonry")
## The tomb's theme for the stone everywhere at once (TombBuild sets it).
static var theme := "tomb"
## Each theme's stone, worked out once: theme -> [tint, spread].
static var _stone: Dictionary = {}


## The style's name for theme `th` (masonry.json style_by_theme; a theme not
## listed takes default).
static func style_name(th := "") -> String:
	var t := th if th != "" else theme
	var by: Dictionary = M.get("style_by_theme", {})
	return str(by.get(t, by.get("default", "andean_tomb")))


## The style for theme `th` (masonry.json styles), or {}.
static func of(th := "") -> Dictionary:
	return (M.get("styles", {}) as Dictionary).get(style_name(th), {})


## A value from the style by its dotted path ("doors.top_share"), or `def`.
static func val(path: String, def: Variant, th := "") -> Variant:
	var cur: Variant = of(th)
	for k in path.split("."):
		if not cur is Dictionary or not (cur as Dictionary).has(k):
			return def
		cur = cur[k]
	return cur


static func num(path: String, def: float, th := "") -> float:
	var v: Variant = val(path, def, th)
	return float(v) if v is float or v is int else def


## The stone's tint (stone.tint, sRGB hex, or "theme": crawler.json
## themes.<theme>.stone; a theme with none takes the first theme that has
## one).
static func tint(th := "") -> Color:
	return _of_stone(th)[0]


## The most any one stone strays from the tint, lighter or darker (stone.spread).
static func spread(th := "") -> float:
	return _of_stone(th)[1]


static func _of_stone(th: String) -> Array:
	var t := th if th != "" else theme
	if not _stone.has(t):
		_stone[t] = [_tint_of(t), clampf(num("stone.spread", 0.06, t), 0.0, 0.5)]
	return _stone[t]


static func _tint_of(t: String) -> Color:
	var s := str(val("stone.tint", "theme", t))
	if s.begins_with("#"):
		return Color(s)
	var themes: Dictionary = Tuning.table("crawler").get("themes", {})
	var own := str((themes.get(t, {}) as Dictionary).get("stone", ""))
	if own.begins_with("#"):
		return Color(own)
	for k in themes:
		var o := str((themes[k] as Dictionary).get("stone", ""))
		if o.begins_with("#"):
			return Color(o)
	push_warning("RuinStyle: no stone colour for theme %s (crawler.json themes.%s.stone)" % [t, t])
	return Color(0.5, 0.5, 0.5)


## One stone's colour: the tint, lighter or darker by up to the spread
## (each channel moved alike, so every stone stays within tint +- spread).
## Two draws from `rng` (the walls' stones keep their old sequence).
static func stone(rng: RandomNumberGenerator, th := "") -> Color:
	var st := _of_stone(th)
	rng.randi()
	return shifted(st[0], rng.randf_range(-1.0, 1.0) * float(st[1]))


## `c` lighter (d > 0) or darker by d, every channel alike, kept in 0-1.
static func shifted(c: Color, d: float) -> Color:
	return Color(clampf(c.r + d, 0.0, 1.0), clampf(c.g + d, 0.0, 1.0), clampf(c.b + d, 0.0, 1.0), c.a)


## Five tones across the spread: RuinBuilder.palette's place in a tomb, so
## anything that still reads it gets the style's own stone.
static func tones(th := "") -> Array:
	var t := tint(th)
	var s := spread(th)
	return [shifted(t, -s), shifted(t, -s * 0.5), t, shifted(t, s * 0.5), shifted(t, s)]


## Worn stone (floor wear): `c` taken toward the light end of the spread by
## `k` (0-1): lighter by a little, still the same stone.
static func worn(c: Color, k: float, th := "") -> Color:
	return c.lerp(shifted(tint(th), spread(th)), clampf(k, 0.0, 1.0))


## The joints' shade (the walls' joint occlusion, §ES.2): the stone darkened
## toward the scene's shade colour, `ao` (1 open, 0 shut in); `bare` (the
## checks) keeps the stone as cut.
static func joint(ao: float, bare := false, th := "") -> Color:
	var t := tint(th)
	return t if bare else Prelit.ao_tint(t.darkened(0.25), ao)


## The builders' unit (module_m, §EX.2).
static func module_m(th := "") -> float:
	return maxf(num("module_m", 2.0, th), 0.5)
