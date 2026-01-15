extends TextureButton

var pause_texture
var resume_texture
var is_game_paused = false

func _ready():
	# Make sure button is set to ignore camera zoom
	set_as_top_level(true)
	
	# Set position and size
	position = Vector2(get_viewport().size.x - 58, 10)
	size = Vector2(48, 48)
	
	# Load textures
	pause_texture = load("res://assets/ui/pause_button.png")
	resume_texture = load("res://assets/ui/play_button.png")
	
	# Set initial texture
	texture_normal = pause_texture
	
	# Set properties
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tooltip_text = "Pause Game"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Connect signals
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	print("PauseButton: Ready")

func _on_pressed():
	# Toggle pause state
	is_game_paused = !is_game_paused
	
	# Update button appearance
	if is_game_paused:
		if resume_texture:
			texture_normal = resume_texture
		tooltip_text = "Resume Game"
		print("PauseButton: Game paused")
	else:
		if pause_texture:
			texture_normal = pause_texture
		tooltip_text = "Pause Game"
		print("PauseButton: Game resumed")
	
	# Get main scene and call pause function
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and main_scene.has_method("_on_pause_button_toggled"):
		main_scene._on_pause_button_toggled(is_game_paused)
		print("PauseButton: Sent pause toggle signal to main scene: " + str(is_game_paused))
	else:
		print("PauseButton: WARNING - Could not find main scene or _on_pause_button_toggled method")

func _on_mouse_entered():
	# Scale up slightly on hover
	scale = Vector2(1.1, 1.1)

func _on_mouse_exited():
	# Return to normal scale
	scale = Vector2(1.0, 1.0)
