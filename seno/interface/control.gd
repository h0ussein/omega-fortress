extends Control

@export var loading_bar: ProgressBar
@onready var percentage_label: Label = $percentage_label # Add a Label node for displaying text
var scene_path: String 
var progress : Array = []  # Initialize as empty array

var update : float = 0
var loading_complete : bool = false
var transition_timer : float = 0
var transition_delay : float = 0.5  # Short delay to ensure progress bar reaches 100%

# Direct reference to MusicManager
var music_manager

func _ready() -> void:
	print("Loading screen ready function executed")
	scene_path = "res://scenes/main.tscn"
	ResourceLoader.load_threaded_request(scene_path,"",true)
	
	# Get direct reference to MusicManager
	music_manager = get_node_or_null("/root/MusicManager")
	print("DEBUG: MusicManager found in loading screen: ", is_instance_valid(music_manager))
	
	# Optional: Play loading screen music or continue current music
	if music_manager and music_manager.has_method("play_game_music"):
		music_manager.play_game_music()

func _process(delta):
	if loading_complete:
		# Handle transition delay after loading is complete
		transition_timer += delta
		if transition_timer >= transition_delay:
			# Change to match music when loading is complete
			if music_manager and music_manager.has_method("play_match_music"):
				music_manager.play_match_music()
			
			get_tree().change_scene_to_packed(
				ResourceLoader.load_threaded_get(scene_path)
			)
		return
	
	var status = ResourceLoader.load_threaded_get_status(scene_path, progress)
	
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Update the target progress value
		if progress.size() > 0 and progress[0] > update:
			update = progress[0]
		
		# Make the progress bar move faster to catch up with actual loading
		if loading_bar.value < update:
			loading_bar.value += delta * 2.0  # Increased speed from 0.5 to 2.0
		
		percentage_label.text = str(int(loading_bar.value * 100.0)) + "%"
	
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		# Force progress to 100% when loading is complete
		update = 1.0
		loading_bar.value = 1.0
		percentage_label.text = "100%"
		loading_complete = true
		print("Loading complete, preparing to change scene...")
	
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		# Handle loading failure
		print("ERROR: Failed to load scene: " + scene_path)
		percentage_label.text = "Loading failed!"
