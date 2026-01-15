extends Node

# This script should be attached to your main scene to set up the WaveDisplayManager

func _ready():
	# Check if WaveDisplayManager already exists
	var existing_managers = get_tree().get_nodes_in_group("wave_display_manager")
	if existing_managers.size() > 0:
		print("WaveDisplayManagerSetup: WaveDisplayManager already exists, skipping creation")
		return
	
	# Create the WaveDisplayManager
	var wave_display_manager = Node.new()
	wave_display_manager.name = "WaveDisplayManager"
	
	# Load and set the script
	var script = load("res://WaveDisplayManager.gd")
	if script:
		wave_display_manager.set_script(script)
		print("WaveDisplayManagerSetup: Loaded WaveDisplayManager script")
	else:
		print("WaveDisplayManagerSetup: ERROR - Could not load WaveDisplayManager script")
		wave_display_manager.queue_free()
		return
	
	# Add to the scene
	add_child(wave_display_manager)
	print("WaveDisplayManagerSetup: Created WaveDisplayManager")
