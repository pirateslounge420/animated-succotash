class_name GameMode
## Which game this project is (design 6 Oct §ET.2, data/game.json):
## "torchfire1", the ambient dungeon crawler, or "torchfire2", the open
## world, shelved but kept (§AT's rule: set aside, compiling and tested,
## never deleted). The boot scene (scenes/boot.tscn) opens the one named;
## GAME in the environment overrides the file for one run.

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
	var g := str(Tuning.table("game").get("game", CRAWLER)).to_lower()
	return g if g in SCENES else CRAWLER


static func crawler() -> bool:
	return game() == CRAWLER


static func scene() -> String:
	return SCENES[game()]
