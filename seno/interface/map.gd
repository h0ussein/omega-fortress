extends Control

# Direct reference to MusicManager
var music_manager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get direct reference to MusicManager
	music_manager = get_node_or_null("/root/MusicManager")
	print("DEBUG: MusicManager found in map: ", is_instance_valid(music_manager))
	
	# Explicitly play game music in map scene
	if music_manager:
		music_manager.play_game_music()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func start_game() -> void:
	print("button are pressed")
	
	# We'll let the main scene handle its own music
	get_tree().change_scene_to_packed(load("res://interface/control.tscn"))

func _on_back_from_map_pressed() -> void:
	get_tree().change_scene_to_file("res://interface/main_menu.tscn")
