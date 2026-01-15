extends Node2D

@export var barrier_scene: PackedScene
@export var barrier_cost: int = 50

var is_placing: bool = false
var is_mouse_down: bool = false  # Track if mouse button is held down
var is_removing: bool = false  # Track if we're in removal mode
var last_modified_cell: Vector2 = Vector2(-1, -1)  # Track last cell where barrier was placed/removed
var grid_system = null
var main_scene = null
var barriers = []
var path_marker = null

func _ready():
	# Make sure this node can process during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	grid_system = get_node_or_null("/root/Node2D_main/GridSystem")
	main_scene = get_node_or_null("/root/Node2D_main")

	# Get the path marker specifically for path checking
	path_marker = get_node_or_null("/root/Node2D_main/Marker_path")
	
	if not path_marker:
		print("Barrier Manager: ERROR - Marker_path not found!")
	else:
		# Set the path marker position in the grid system
		if grid_system:
			grid_system.set_path_marker_position(grid_system.world_to_grid(path_marker.global_position))
			
			# Disable debug path visualization
			grid_system.toggle_debug_path(false)
			print("Barrier Manager: Set path marker position to " + str(grid_system.world_to_grid(path_marker.global_position)))
		else:
			print("Barrier Manager: ERROR - Grid system not found!")

# Process input for barrier placement/removal
func _input(event):
	if not is_placing:
		return

	# Handle barrier placement/removal with mouse button press
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Mouse button pressed down
				is_mouse_down = true
				var mouse_pos = get_global_mouse_position()
				if grid_system and is_instance_valid(grid_system):
					var grid_pos = grid_system.world_to_grid(mouse_pos)
					
					# Check if we clicked on an existing barrier
					if grid_system.grid_cells.get(str(grid_pos), 0) == 1:  # 1 = barrier
						is_removing = true
						remove_barrier_at(grid_pos)
						last_modified_cell = grid_pos  # Remember this cell
					else:
						is_removing = false
						place_barrier_at_position(grid_pos)
						last_modified_cell = grid_pos  # Remember this cell
			else:
				# Mouse button released
				is_mouse_down = false
				is_removing = false
				last_modified_cell = Vector2(-1, -1)  # Reset last modified cell
		
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Cancel placement mode with right click
			exit_placing_mode()

	# Handle mouse movement while button is held down
	if event is InputEventMouseMotion and is_mouse_down:
		var mouse_pos = get_global_mouse_position()
		if grid_system and is_instance_valid(grid_system):
			var grid_pos = grid_system.world_to_grid(mouse_pos)
			
			# Only process if this is a different cell than the last one we modified
			if grid_pos != last_modified_cell:
				if is_removing:
					# We're in removal mode - check if there's a barrier here
					if grid_system.grid_cells.get(str(grid_pos), 0) == 1:  # Is a barrier
						remove_barrier_at(grid_pos)
						last_modified_cell = grid_pos  # Update last modified cell
				else:
					# We're in placement mode - check if there's no barrier here
					if grid_system.grid_cells.get(str(grid_pos), 0) != 1:  # Not a barrier
						place_barrier_at_position(grid_pos)
						last_modified_cell = grid_pos  # Update last modified cell

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Cancel placement mode with Escape key
		exit_placing_mode()

func start_placing_barriers():
	if is_placing:
		return
		
	is_placing = true

	# Show grid when placing barriers
	if grid_system and is_instance_valid(grid_system):
		grid_system.set_placing_barrier(true)

func exit_placing_mode():
	if not is_placing:
		return
		
	is_placing = false
	is_mouse_down = false
	is_removing = false
	last_modified_cell = Vector2(-1, -1)

	# Hide grid when canceling barrier placement
	if grid_system and is_instance_valid(grid_system):
		grid_system.set_placing_barrier(false)
		grid_system.clear_invalid_placement()  # Clear any invalid placement visualization

	# Notify main scene that we've exited barrier mode
	if main_scene and is_instance_valid(main_scene) and main_scene.has_method("exit_barrier_mode"):
		# This will update the barrier button text
		main_scene.placing_barrier = false

# This function is called when clicking on the grid
func place_barrier_at_mouse():
	if not grid_system or not main_scene or not is_instance_valid(grid_system) or not is_instance_valid(main_scene):
		return

	var mouse_pos = get_global_mouse_position()
	var grid_pos = grid_system.world_to_grid(mouse_pos)
	
	place_barrier_at_position(grid_pos)

# This function places a barrier at a specific grid position
func place_barrier_at_position(grid_pos: Vector2):
	if not grid_system or not main_scene or not is_instance_valid(grid_system) or not is_instance_valid(main_scene):
		return

	# Check if we have enough gold
	if main_scene.gold < barrier_cost:
		return

	# Check if position is in green zone
	if not grid_system.is_in_green_zone(grid_pos):
		return

	# Get cell content
	var cell_content = grid_system.grid_cells.get(str(grid_pos), 0)

	# Check if cell is empty (0)
	if cell_content != 0:
		return

	# IMPORTANT: Check if placing here would block all paths to the base
	# This is the critical check that ensures at least one path remains open
	if grid_system.would_block_all_paths(grid_pos):
		grid_system.set_invalid_placement(grid_pos)
		print("Barrier Manager: Cannot place barrier at " + str(grid_pos) + " - would block all paths to base")
		# Add visual feedback and maybe a sound effect to indicate invalid placement
		if main_scene.has_method("show_message"):
			main_scene.show_message("Cannot block all paths to the base!")
		return

	# Clear any invalid placement visualization
	grid_system.clear_invalid_placement()

	# Place barrier in the grid system
	grid_system.grid_cells[str(grid_pos)] = 1  # 1 = barrier

	# Mark grid as changed and clear path cache completely
	grid_system.grid_changed = true
	grid_system.path_cache.clear()

	# Deduct gold
	main_scene.gold -= barrier_cost
	main_scene.update_gold_display()

	# Create visual barrier
	var barrier = barrier_scene.instantiate()
	barrier.global_position = grid_system.grid_to_world(grid_pos)
	barrier.grid_position = grid_pos  # Set the grid position property
	
	# Connect to barrier destroyed signal
	if barrier.has_signal("barrier_destroyed"):
		barrier.barrier_destroyed.connect(_on_barrier_destroyed)
	
	add_child(barrier)
	barriers.append({"node": barrier, "grid_pos": grid_pos})

	# Notify grid system that a barrier was placed
	grid_system.emit_signal("grid_updated")
	grid_system.queue_redraw()
	print("Barrier Manager: Placed barrier at " + str(grid_pos))

func remove_barrier_at(grid_pos: Vector2):
	if not grid_system or not is_instance_valid(grid_system):
		return

	# Check if there's a barrier at this position
	if grid_system.grid_cells.get(str(grid_pos), 0) == 1:
		# Remove barrier from grid system
		grid_system.grid_cells[str(grid_pos)] = 0  # 0 = empty
		
		# Mark grid as changed and clear path cache completely
		grid_system.grid_changed = true
		grid_system.path_cache.clear()
		
		# Find and remove the visual barrier
		for i in range(barriers.size()):
			if barriers[i]["grid_pos"] == grid_pos:
				if is_instance_valid(barriers[i]["node"]):
					barriers[i]["node"].queue_free()
				barriers.remove_at(i)
				
				# Refund some gold
				if main_scene and is_instance_valid(main_scene):
					var refund = int(barrier_cost * 0.5)
					main_scene.gold += refund
					main_scene.update_gold_display()
				
				break
		
		# Notify grid system that a barrier was removed
		grid_system.emit_signal("grid_updated")
		grid_system.queue_redraw()
		print("Barrier Manager: Removed barrier at " + str(grid_pos))

# Get a barrier at a specific grid position (for enemy targeting)
func get_barrier_at_position(grid_pos: Vector2) -> Node2D:
	for barrier_data in barriers:
		if barrier_data.grid_pos == grid_pos and is_instance_valid(barrier_data.node):
			return barrier_data.node
	return null

# Signal handler for barrier destroyed
func _on_barrier_destroyed(barrier, grid_pos):
	print("Barrier Manager: Received barrier_destroyed signal for position ", grid_pos)
	
	# Find and remove the barrier from our list
	for i in range(barriers.size()):
		if barriers[i]["grid_pos"] == grid_pos:
			barriers.remove_at(i)
			break
	
	# Grid system update is handled by the barrier itself
