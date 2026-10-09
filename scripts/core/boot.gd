extends Node
## The project's first scene (design 6 Oct §ET.2): opens the game
## data/game.json names (GameMode): the dungeon crawler (Torchfire 1) or
## the open world (Torchfire 2, scenes/main.tscn).
##
## The crawler with a game kept (design 7 Oct §FK.2, CrawlerSave): first a
## plain choice (BootMenu), Continue or New game, and then the crawler,
## which opens the last game where you left it or rolls a new one. With no
## game kept it opens straight onto a new one, as before. The open world
## boots as it always has (its own Continue is just booting, WorldSave).


func _ready() -> void:
	if GameMode.crawler() and CrawlerSave.can_continue():
		Display.install(get_window())
		HudText.install()
		var layer := CanvasLayer.new()
		layer.name = "UI"
		add_child(layer)
		var menu := BootMenu.new()
		menu.name = "BootMenu"
		menu.note = CrawlerSave.summary()
		layer.add_child(menu)
		menu.picked.connect(go)
		return
	get_tree().change_scene_to_file.call_deferred(GameMode.scene())


## Into the game: `which` is "continue" or "new" (the crawler's choice).
func go(which: String) -> void:
	CrawlerSave.new_game_requested = which == "new"
	get_tree().change_scene_to_file.call_deferred(GameMode.scene())
