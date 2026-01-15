extends Control

# Direct reference to MusicManager
var music_manager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	 # Get direct reference to MusicManager
	music_manager = get_node_or_null("/root/MusicManager")
	print("DEBUG: MusicManager found in main menu: ", is_instance_valid(music_manager))
	# Explicitly play game music in main menu
	if music_manager:
		music_manager.play_game_music()

# Rest of your main menu code...

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	# Change to game music when starting the game
	if music_manager and music_manager.has_method("play_match_music"):
		music_manager.play_match_music()
	
	get_tree().change_scene_to_file("res://interface/map.tscn")

func _on_Settings_pressed() -> void:
	print("start game pressed")
	get_tree().change_scene_to_file("res://interface/settings.tscn")
	print("start excuted")

func _on_exit_pressed() -> void:
	get_tree().quit()
