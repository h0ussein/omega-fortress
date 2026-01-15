extends Node2D

# Signals
signal barrier_count_changed(count)

# References
@onready var grid_system = get_parent()
@onready var game_map = grid_system.get_parent()

# Barrier scene
var barrier_scene = preload("res://scenes/barrier.tscn")  # Adjust path as needed

# State
var barriers = {}  # Dictionary mapping grid positions to barrier nodes
var barrier_count = 20  # Start with 20 barriers

func _ready():
	print("BarrierSystem ready with ", barrier_count, " barriers")
	emit_signal("barrier_count_changed", barrier_count)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if game_map.build_mode:
				var mouse_pos = get_global_mouse_position()
				var grid_pos = grid_system.world_to_grid(mouse_pos)
				
				# Check if there's already a barrier at this position
				if barriers.has(grid_pos):
					# Remove existing barrier
					remove_barrier(grid_pos)
					print("Barrier removed at grid position: ", grid_pos)
				else:
					# Place new barrier if we have enough
					if barrier_count > 0:
						place_barrier(grid_pos)
						print("Barrier placed at grid position: ", grid_pos)
					else:
						print("No barriers left to place")

func place_barrier(grid_pos):
	# Check if position is valid
	if not grid_system.is_valid_placement_cell(grid_pos):
		print("Cannot place barrier at invalid position: ", grid_pos)
		return false
	
	# Create barrier instance
	var barrier = barrier_scene.instantiate()
	
	# Set the world position
	var world_pos = grid_system.grid_to_world(grid_pos)
	barrier.position = world_pos
	print("Placing barrier at world position: ", world_pos)
	
	# Set the grid position property if the barrier has it
	if "grid_position" in barrier:
		barrier.grid_position = grid_pos
	
	# Make sure the barrier is visible
	barrier.visible = true
	
	# IMPORTANT: Add barrier to GameMap instead of BarrierSystem
	# This ensures it's not affected by grid visibility
	game_map.add_child(barrier)
	barriers[grid_pos] = barrier
	
	# Register with grid system
	grid_system.register_barrier(barrier, grid_pos)
	
	# Decrease barrier count
	barrier_count -= 1
	emit_signal("barrier_count_changed", barrier_count)
	
	# Debug - print all barriers
	print("Current barriers: ", barriers.size())
	for pos in barriers:
		print("  Barrier at ", pos, " world pos: ", barriers[pos].position)
	
	return true

func remove_barrier(grid_pos):
	# Check if there's a barrier at this position
	if not barriers.has(grid_pos):
		return false
	
	# Get the barrier
	var barrier = barriers[grid_pos]
	
	# Remove from grid system
	grid_system.remove_barrier(grid_pos)
	
	# Remove from scene
	barriers.erase(grid_pos)
	barrier.queue_free()
	
	# Increase barrier count
	barrier_count += 1
	emit_signal("barrier_count_changed", barrier_count)
	
	return true

func add_barriers(count):
	# Add more barriers to the count
	barrier_count += count
	emit_signal("barrier_count_changed", barrier_count)
	print("Added ", count, " barriers, new total: ", barrier_count)
