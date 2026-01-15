extends Button

signal pause_toggled(is_paused: bool)

@export var pause_text: String = "||"
@export var resume_text: String = "▶"

var is_game_paused: bool = false

func _ready():
	# Set this node to always process even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set initial text
	text = pause_text
	
	# Connect button press signal
	if pressed.is_connected(_on_pressed):
		pressed.disconnect(_on_pressed)
	pressed.connect(_on_pressed)

	# Set tooltip
	tooltip_text = "Pause Game"

	# Style the button
	custom_minimum_size = Vector2(48, 48)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Set font size
	add_theme_font_size_override("font_size", 24)

	# Add hover effect
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	mouse_entered.connect(_on_mouse_entered)
	
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)
	mouse_exited.connect(_on_mouse_exited)

	print("PauseButton: Ready with anchored position on right side")

func _on_pressed():
	print("PauseButton: Button pressed!")
	
	# Toggle pause state
	is_game_paused = !is_game_paused

	# Update button appearance
	if is_game_paused:
		text = resume_text
		tooltip_text = "Resume Game"
		print("PauseButton: Game paused")
	else:
		text = pause_text
		tooltip_text = "Pause Game"
		print("PauseButton: Game resumed")

	# Emit signal to notify other nodes
	emit_signal("pause_toggled", is_game_paused)

	# Get main scene and call pause function directly as a backup
	var main_scene = get_node_or_null("/root/Node2D_main")
	if main_scene and main_scene.has_method("_on_pause_button_toggled"):
		main_scene._on_pause_button_toggled(is_game_paused)
		print("PauseButton: Sent pause toggle signal to main scene: " + str(is_game_paused))
	else:
		# Direct control of game pause state as fallback
		get_tree().paused = is_game_paused
		print("PauseButton: WARNING - Could not find main scene or _on_pause_button_toggled method")
		print("PauseButton: Directly set game pause state: " + str(is_game_paused))

func _on_mouse_entered():
	# Scale up slightly on hover
	scale = Vector2(1.1, 1.1)

func _on_mouse_exited():
	# Return to normal scale
	scale = Vector2(1.0, 1.0)
