extends Control

func _ready() -> void:
	# Ensure we're playing game music in the main menu
	MusicManager.play_game_music()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://interface/map.tscn")

func _on_Settings_pressed() -> void:
	get_tree().change_scene_to_file("res://interface/settings.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
