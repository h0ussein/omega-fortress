extends Button

signal pause_toggled(is_paused)

var is_paused = false
var pause_texture = null
var play_texture = null

func _ready():
	# Try to load textures
	if ResourceLoader.exists("res://assets/ui/pause_button.png"):
		pause_texture = load("res://assets/ui/pause_button.png")
	
	if ResourceLoader.exists("res://assets/ui/play_button.png"):
		play_texture = load("res://assets/ui/play_button.png")
	
	if not pause_texture:
		print("PauseButton: Warning - pause_texture is null")
	
	if not play_texture:
		print("PauseButton: Warning - play_texture is null")
	
	# Set initial text/icon
	if pause_texture:
		icon = pause_texture
	else:
		text = "Pause"
	
	# Connect pressed signal
	pressed.connect(_on_pressed)
	
	print("PauseButton: Ready")

func _on_pressed():
	is_paused = !is_paused
	
	# Update button appearance
	if is_paused:
		if play_texture:
			icon = play_texture
		else:
			text = "Resume"
	else:
		if pause_texture:
			icon = pause_texture
		else:
			text = "Pause"
	
	# Emit signal
	emit_signal("pause_toggled", is_paused)
	print("PauseButton: Toggled pause state to ", is_paused)
