extends Node

# This script helps integrate the new UI system with the existing main scene

func _ready():
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Find main scene
	var main_scene = get_node_or_null("/root/Node2D_main")
	if not main_scene:
		print("UIIntegrator: ERROR - Main scene not found")
		return
	
	# Check if old UI exists
	var old_ui = main_scene.get_node_or_null("UI")
	if old_ui:
		print("UIIntegrator: Found old UI, will replace with new UI")
		
		# Create new UI container
		var ui_container_scene = load("res://scenes/ui/fixed_ui_container.tscn")
		if not ui_container_scene:
			print("UIIntegrator: ERROR - Could not load fixed_ui_container scene")
			return
			
		var ui_container = ui_container_scene.instantiate()
		ui_container.name = "FixedUIContainer"
		
		# Add new UI container to main scene
		main_scene.add_child(ui_container)
		
		# Update main scene's UI reference
		if "ui" in main_scene:
			main_scene.ui = ui_container
		
		print("UIIntegrator: Added new UI container")
		
		# Connect signals from old UI to new UI
		if old_ui.has_signal("hero_purchase_requested") and ui_container.has_signal("hero_purchase_requested"):
			var connections = old_ui.hero_purchase_requested.get_connections()
			for conn in connections:
				ui_container.hero_purchase_requested.connect(conn["callable"])
				print("UIIntegrator: Connected hero_purchase_requested signal")
		
		if old_ui.has_signal("move_button_pressed") and ui_container.has_signal("move_button_pressed"):
			var connections = old_ui.move_button_pressed.get_connections()
			for conn in connections:
				ui_container.move_button_pressed.connect(conn["callable"])
				print("UIIntegrator: Connected move_button_pressed signal")
		
		if old_ui.has_signal("sell_button_pressed") and ui_container.has_signal("sell_button_pressed"):
			var connections = old_ui.sell_button_pressed.get_connections()
			for conn in connections:
				ui_container.sell_button_pressed.connect(conn["callable"])
				print("UIIntegrator: Connected sell_button_pressed signal")
		
		if old_ui.has_signal("barrier_button_pressed") and ui_container.has_signal("barrier_button_pressed"):
			var connections = old_ui.barrier_button_pressed.get_connections()
			for conn in connections:
				ui_container.barrier_button_pressed.connect(conn["callable"])
				print("UIIntegrator: Connected barrier_button_pressed signal")
		
		# Remove old UI
		old_ui.queue_free()
		print("UIIntegrator: Removed old UI")
	else:
		print("UIIntegrator: No old UI found, creating new UI")
		
		# Create new UI container
		var ui_container_scene = load("res://scenes/ui/fixed_ui_container.tscn")
		if not ui_container_scene:
			print("UIIntegrator: ERROR - Could not load fixed_ui_container scene")
			return
			
		var ui_container = ui_container_scene.instantiate()
		ui_container.name = "FixedUIContainer"
		
		# Add new UI container to main scene
		main_scene.add_child(ui_container)
		
		# Update main scene's UI reference
		if "ui" in main_scene:
			main_scene.ui = ui_container
		
		print("UIIntegrator: Added new UI container")
	
	# Add hero panel positioner
	var hero_panel_positioner_scene = load("res://scenes/ui/hero_panel_positioner.tscn")
	if hero_panel_positioner_scene:
		var hero_panel_positioner = hero_panel_positioner_scene.instantiate()
		main_scene.add_child(hero_panel_positioner)
		print("UIIntegrator: Added hero panel positioner")
	else:
		print("UIIntegrator: ERROR - Could not load hero_panel_positioner scene")
	
	print("UIIntegrator: Integration complete")
