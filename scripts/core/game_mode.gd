class_name GameMode
## Which game this project is (design 6 Oct §ET.2, data/game.json):
## "torchfire2", the open world, the game again since 18 Oct (design
## §FX.1), or "torchfire1", the ambient dungeon crawler, kept whole (§AT's
## rule: compiling and tested, never deleted; §FY folds its ruins into the
## open world later). The boot scene (scenes/boot.tscn) opens the one
## named; GAME in the environment overrides the file for one run. With no
## readable name the open world boots (§FX.1).

const CRAWLER := "torchfire1"
const OPEN_WORLD := "torchfire2"
const SCENES := {CRAWLER: "res://scenes/crawler.tscn", OPEN_WORLD: "res://scenes/main.tscn"}

## True while the crawler's scene is the one running (set by CrawlerMain),
## so code both games share (the torch's snuff rules) knows which rules
## apply whatever the file says (the checks run the open world directly).
static var crawler_running := false


static func game() -> String:
	var env := OS.get_environment("GAME").strip_edges().to_lower()
	if env in SCENES:
		return env
	var g := str(Tuning.table("game").get("game", OPEN_WORLD)).to_lower()
	return g if g in SCENES else OPEN_WORLD


static func crawler() -> bool:
	return game() == CRAWLER


static func scene() -> String:
	return SCENES[game()]
