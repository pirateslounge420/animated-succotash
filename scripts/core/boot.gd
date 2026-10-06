extends Node
## The project's first scene (design 6 Oct §ET.2): opens the game
## data/game.json names (GameMode): the dungeon crawler (Torchfire 1) or
## the open world (Torchfire 2, scenes/main.tscn).


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(GameMode.scene())
