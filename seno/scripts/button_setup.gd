extends Node

# This script should be attached to your main scene to set up the PauseButton

func _ready():
	# Check if a PauseButton already exists
	var existing_buttons = get_tree().get_nodes_in_group("pause_button")
	if existing_buttons.size() > 0:
		print("PauseButtonSetup: PauseButton already exists, skipping creation")
		return
	
	# Create a CanvasLayer for the pause button
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "PauseButtonCanvas"
	canvas_layer.layer = 10  # High layer number to be on top
	add_child(canvas_layer)
	
	# Create a Control container
	var container = Control.new()
	container.name = "PauseButtonContainer"
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	canvas_layer.add_child(container)
	
	# Create the PauseButton
	var pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.add_to_group("pause_button")
	
	# Position at top right
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.offset_left = -100
	pause_button.offset_top = 10
	pause_button.offset_right = -10
	pause_button.offset_bottom = 50
	
	# Load and set the script
	var script = load("res://PauseButton.gd")
	if script:
		pause_button.set_script(script)
		print("PauseButtonSetup: Loaded PauseButton script")
	else:
		print("PauseButtonSetup: ERROR - Could not load PauseButton script")
		pause_button.text = "Pause"  # Fallback
	
	# Add to the container
	container.add_child(pause_button)
	
	# Connect to main scene
	var main_scene = get_node("/root/Node2D_main")
	if main_scene and pause_button.has_signal("pause_toggled"):
		if main_scene.has_method("_on_pause_button_toggled"):
			pause_button.pause_toggled.connect(main_scene._on_pause_button_toggled)
			print("PauseButtonSetup: Connected pause_toggled signal to main scene")
		else:
			print("PauseButtonSetup: WARNING - Main scene does not have _on_pause_button_toggled method")
	
	print("PauseButtonSetup: Created PauseButton")
