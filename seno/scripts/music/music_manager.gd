extends Node

func _ready() -> void:
	# Switch to match music when the match starts
	MusicManager.play_match_music()

func _on_match_ended() -> void:
	# Switch back to game music when returning to menu
	MusicManager.play_game_music()
	get_tree().change_scene_to_file("res://interface/main_menu.tscn")
