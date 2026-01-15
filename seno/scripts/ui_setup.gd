extends Node

# This script should be attached to your main scene to set up all UI components

func _ready():
	# Set up WaveDisplayManager
	var wave_display_setup = Node.new()
	wave_display_setup.name = "WaveDisplayManagerSetup"
	var wave_display_script = load("res://WaveDisplayManagerSetup.gd")
	if wave_display_script:
		wave_display_setup.set_script(wave_display_script)
		add_child(wave_display_setup)
		print("UISetup: Added WaveDisplayManagerSetup")
	else:
		print("UISetup: ERROR - Could not load WaveDisplayManagerSetup script")
	
	# Set up PauseButton
	var pause_button_setup = Node.new()
	pause_button_setup.name = "PauseButtonSetup"
	var pause_button_script = load("res://PauseButtonSetup.gd")
	if pause_button_script:
		pause_button_setup.set_script(pause_button_script)
		add_child(pause_button_setup)
		print("UISetup: Added PauseButtonSetup")
	else:
		print("UISetup: ERROR - Could not load PauseButtonSetup script")
	
	print("UISetup: UI setup complete")
